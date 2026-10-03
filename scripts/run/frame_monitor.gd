class_name FrameMonitor
extends Node
## Times every frame of a run and notes what happened in it (task PERF1, the owner's "lag spikes are
## more common", October 2, 2026). The in-game frame-time graph (FrameGraph, F7 in debug builds)
## shows its last seconds; tools/measure/frame_times.gd and test_frame_times record whole runs.
##
## A frame runs from its start (its first physics step, or its process step when it has none) to the
## next frame's start: `total` is what the player sees as one frame, vsync and all. `logic` is the part
## before the renderer starts drawing (RenderingServer.frame_pre_draw): the game's own CPU work
## (physics steps, scripts, building and freeing nodes). A headless run never draws and never waits, so
## there `logic` is the whole frame and `total` its CPU time. `physics` is the part spent in physics
## steps (the track's chunks, the director's spawns, the player, enemies, shots).
##
## Tags name what happened in a frame. They come from the run's own signals and from a look at its
## state once a frame, so nothing in the game reports to the monitor or pays for it:
##   chunk+N, chunk-N    track chunks built, freed (TrackBuilder)
##   spawn:<type>        an enemy spawned (EnemyDirector.enemy_spawned)
##   kill:<type>         an enemy defeated (EnemyDirector.enemy_defeated)
##   hit-stop            a freeze began (RunEffects.freeze_left: a kill's or a stomp's); `frozen` marks
##                       every frame the camera holds still for one
##   fx                  a spark or debris burst started (RunEffects)
##   credit, pickup      a credit, an armor/shield/grapple pickup taken
##   fire                the weapon fired
##   sound:<name>        a non-positional sound asked for (PlayerSfx.requested)
##   boss:phase          a boss fight's phase began
##   nodes+N, nodes-N    the scene tree grew or shrank by at least NODE_JUMP nodes
##   obj+N               at least OBJECT_JUMP objects other than nodes made (meshes, materials, shapes)
##   compile:N           render pipelines compiled (Forward+ and Mobile only: a shader stutter)
##   physics:N           N physics steps in one frame (the game catching up after a slow frame)

## Frames kept for the graph (FrameGraph) unless keep_all: ten seconds at 60 frames a second.
const HISTORY: int = 600
## The scene tree growing or shrinking by this many nodes in a frame is tagged.
const NODE_JUMP: int = 40
## This many objects other than nodes made in one frame is tagged.
const OBJECT_JUMP: int = 40
## RenderingServer's pipeline compilation counters (Godot 4.4+, RD renderers; zero elsewhere).
const COMPILE_INFOS: Array[int] = [RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_CANVAS,
	RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_MESH, RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SURFACE,
	RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW]

## Keep every frame (the measuring tool, the tests) instead of the last HISTORY.
var keep_all: bool = false
## The run watched (a RunWorld; any node with the same parts works, so the tool can watch older builds).
var world: Node

## Frames so far, oldest first: each one's start (Time.get_ticks_usec), whole time, logic and physics
## parts (microseconds), the camera held by a hit-stop, and its tags.
var starts := PackedInt64Array()
var totals := PackedInt32Array()
var logics := PackedInt32Array()
var physics := PackedInt32Array()
var frozen := PackedByteArray()
var tags: Array[PackedStringArray] = []
## Frames dropped from the front of the lists so far (keep_all off): a frame's number is its index
## plus this.
var dropped: int = 0

var _open: bool = false
var _processed: bool = false
var _start: int = 0
var _physics_end: int = 0
var _pre_draw: int = 0
var _steps: int = 0
var _discount: int = 0
var _tags := PackedStringArray()
var _built: int = 0
var _alive_chunks: int = 0
var _freeze: float = 0.0
var _bursts: int = 0
var _debris: int = 0
var _nodes: int = 0
var _objects: int = 0
var _compiles: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().physics_frame.connect(_on_physics_frame)
	get_tree().process_frame.connect(_on_process_frame)
	RenderingServer.frame_pre_draw.connect(_on_pre_draw)
	_nodes = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	_objects = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	_compiles = _compile_count()


func _exit_tree() -> void:
	if RenderingServer.frame_pre_draw.is_connected(_on_pre_draw):
		RenderingServer.frame_pre_draw.disconnect(_on_pre_draw)


## Watches `p_world` (a RunWorld) from now on: its signals tag the frames they come in. Call it again
## for a rebuilt world (a restart).
func watch(p_world: Node) -> void:
	world = p_world
	_connect(world.get(&"director"), &"enemy_spawned", _on_spawned)
	_connect(world.get(&"director"), &"enemy_defeated", _on_defeated)
	_connect(world.get(&"credits"), &"collected", _on_credit)
	_connect(world.get(&"pickups"), &"collected", _on_pickup)
	_connect(world.get(&"sounds"), &"requested", _on_sound)
	_connect(world.get(&"powerups"), &"fired", _on_fired)
	var track: Object = world.get(&"track")
	_built = _int_of(track, &"_next_chunk") if track != null else 0
	var chunks: Variant = track.get(&"_chunks") if track != null else null
	_alive_chunks = (chunks as Dictionary).size() if chunks is Dictionary else 0


## Tags a boss fight's phases too (BossEncounter.phase_started).
func watch_boss(encounter: Node) -> void:
	_connect(encounter, &"phase_started", func(_i: int) -> void: tag("boss:phase"))


## Adds a tag to the frame under way.
func tag(what: String) -> void:
	_tags.append(what)


## Leaves `usec` microseconds out of the frame under way: a measuring tool's own work in it.
func discount(usec: int) -> void:
	_discount += usec


## Forgets every frame so far (the tool starts each level afresh).
func clear() -> void:
	starts.clear()
	totals.clear()
	logics.clear()
	physics.clear()
	frozen.clear()
	tags.clear()
	dropped = 0


func frame_count() -> int:
	return totals.size()


## Every frame's whole time in milliseconds, oldest first.
func totals_ms() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(totals.size())
	for i: int in totals.size():
		out[i] = totals[i] / 1000.0
	return out


## The usual numbers for a list of frame times (ms): median, 95th and 99th percentiles, the worst
## frame, and the frames over 8 ms and over 16 ms (half a 60 fps frame, and a whole one).
static func summarize(times_ms: PackedFloat32Array) -> Dictionary:
	var sorted: PackedFloat32Array = times_ms.duplicate()
	sorted.sort()
	var n: int = sorted.size()
	var over8: int = 0
	var over16: int = 0
	for t: float in sorted:
		if t > 8.0:
			over8 += 1
		if t > 16.0:
			over16 += 1
	return {"frames": n, "median": percentile(sorted, 0.5), "p95": percentile(sorted, 0.95),
		"p99": percentile(sorted, 0.99), "worst": sorted[n - 1] if n > 0 else 0.0, "over8": over8, "over16": over16}


## The `q` quantile (0 to 1) of an already sorted list, the nearest rank.
static func percentile(sorted: PackedFloat32Array, q: float) -> float:
	if sorted.is_empty():
		return 0.0
	return sorted[clampi(ceili(q * sorted.size()) - 1, 0, sorted.size() - 1)]


func _connect(source: Object, sig: StringName, handler: Callable) -> void:
	if source != null and source.has_signal(sig) and not source.is_connected(sig, handler):
		source.connect(sig, handler)


func _on_physics_frame() -> void:
	var now: int = Time.get_ticks_usec()
	if not _open or _processed:
		_close(now)
		_begin(now)
	_steps += 1


func _on_process_frame() -> void:
	var now: int = Time.get_ticks_usec()
	if not _open or _processed:
		_close(now)
		_begin(now)
	_processed = true
	_physics_end = now if _steps > 0 else _start


func _on_pre_draw() -> void:
	_pre_draw = Time.get_ticks_usec()


func _begin(now: int) -> void:
	_open = true
	_processed = false
	_start = now
	_physics_end = now
	_pre_draw = 0
	_steps = 0
	_discount = 0


## Ends the frame under way at `now`: its times, and what changed in the run during it.
func _close(now: int) -> void:
	if not _open:
		return
	var total: int = maxi(now - _start - _discount, 0)
	var logic: int = clampi(_pre_draw - _start - _discount, 0, total) if _pre_draw > 0 else total
	if _steps > 1:
		_tags.append("physics:%d" % _steps)
	var held: bool = _look_at_world()
	_look_at_engine()
	starts.append(_start)
	totals.append(total)
	logics.append(logic)
	physics.append(maxi(_physics_end - _start, 0))
	frozen.append(1 if held else 0)
	tags.append(_tags)
	_tags = PackedStringArray()
	if not keep_all and totals.size() >= HISTORY * 2:
		starts = starts.slice(HISTORY)
		totals = totals.slice(HISTORY)
		logics = logics.slice(HISTORY)
		physics = physics.slice(HISTORY)
		frozen = frozen.slice(HISTORY)
		tags = tags.slice(HISTORY)
		dropped += HISTORY


## Tags what changed in the run during the frame (chunks, a hit-stop, bursts); true if the camera was
## held by a hit-stop.
func _look_at_world() -> bool:
	if world == null or not is_instance_valid(world):
		return false
	var track: Object = world.get(&"track")
	var chunks: Variant = track.get(&"_chunks") if track != null and is_instance_valid(track) else null
	if chunks is Dictionary:
		var built: int = _int_of(track, &"_next_chunk")
		var alive: int = (chunks as Dictionary).size()
		var made: int = built - _built
		var freed: int = _alive_chunks + made - alive
		if made > 0:
			_tags.append("chunk+%d" % made)
		if freed > 0:
			_tags.append("chunk-%d" % freed)
		_built = built
		_alive_chunks = alive
	var held: bool = false
	var effects: Object = world.get(&"effects")
	if effects != null and is_instance_valid(effects):
		var freeze: Variant = effects.get(&"freeze_left")
		if freeze != null:
			held = float(freeze) > 0.0
			if float(freeze) > _freeze + 0.0001:
				_tags.append("hit-stop")
			_freeze = float(freeze)
		var bursts: int = _int_of(effects, &"_next_burst")
		var debris: int = _int_of(effects, &"_next_debris")
		if bursts != _bursts or debris != _debris:
			_tags.append("fx")
		_bursts = bursts
		_debris = debris
	return held


## An int property of `source`, or 0 if it has none (an older build's).
static func _int_of(source: Object, prop: StringName) -> int:
	var value: Variant = source.get(prop)
	return int(value) if value != null else 0


## Tags big changes in the scene tree, objects made, and pipelines compiled during the frame.
func _look_at_engine() -> void:
	var nodes: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var objects: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var node_change: int = nodes - _nodes
	if absi(node_change) >= NODE_JUMP:
		_tags.append("nodes%+d" % node_change)
	if objects - _objects - node_change >= OBJECT_JUMP:
		_tags.append("obj+%d" % (objects - _objects - node_change))
	_nodes = nodes
	_objects = objects
	var compiles: int = _compile_count()
	if compiles > _compiles:
		_tags.append("compile:%d" % (compiles - _compiles))
	_compiles = compiles


static func _compile_count() -> int:
	var n: int = 0
	for info: int in COMPILE_INFOS:
		n += RenderingServer.get_rendering_info(info)
	return n


func _on_spawned(enemy: Node) -> void:
	_tags.append("spawn:%s" % enemy.get(&"type_id"))


func _on_defeated(enemy: Node, _cause: StringName) -> void:
	_tags.append("kill:%s" % (enemy.get(&"type_id") if is_instance_valid(enemy) else "?"))


func _on_credit(_value: int, _at: Vector3) -> void:
	_tags.append("credit")


func _on_pickup(_pickup: Node, _gained: bool) -> void:
	_tags.append("pickup")


func _on_sound(sound: StringName) -> void:
	_tags.append("sound:%s" % sound)


func _on_fired(_tier: int) -> void:
	_tags.append("fire")
