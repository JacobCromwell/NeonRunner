class_name BossProps
extends Node3D
## What a boss puts in the arena within sight during its fight (GDD §10), built with the track's
## collision layers and the zone skin's looks, and freed once the player is past it. (Pieces planned
## further ahead go on the track itself: BossArena.add_pieces.) Every call takes track coordinates
## (lane, distance, wall side) and returns the node, which a boss script may move (a fence rolled
## across the lanes), switch (Hazard.set_enabled) or remove early (remove()):
## - fence(lane, at, variant, warning_seconds): a pink electric fence with the normal fence rules
##   (armor, the shield and the dash get through; claws don't); it can come in flickering first;
## - block(lane, at, size): a solid obstacle slammed into a lane (The House's gold blocks): deadly to
##   run into, solid to switch lanes into; the boss script adds its look;
## - pad(lane, at) and ceiling(start, end, lanes): an anti-grav pad and a ceiling section, over every
##   lane or a range of them (the zone's looks); ceiling_lanes(start, ends): a ceiling whose lanes end at
##   different distances (GDD §10, the Beach's climb: the lanes that lead up run further), one section
##   per run of lanes ending together;
## - roof(lanes, start, end, height): a raised floor's top over a range of lanes (the Beach's climb: a
##   tiki bar's roof the runner drops onto and runs along), on the floor layer like the street; the boss
##   script adds its look;
## - block_wall(side, from, to): a stretch of wall the player can't enter (the Sewer Swarm climbs one
##   wall at a time); the boss script draws what took it;
## - lane_warning(lane, from, to) and circle_warning(at, lane, radius): the red floor warnings of an
##   attack (a lane about to be struck, a bomb's target circle), pulsing, or glowing steadily with
##   Reduced flashing (Settings); warned() says where they are (pickups keep off them);
## - floor_warning(node, lane, from, to): a boss's own floor warning, drawn its own way (Sleep Taker's
##   purple mist), counted by warned() like the red ones;
## - keep(node, until): anything else, freed once the player is past `until`.
## Every call that places something on the floor (fences, blocks, pads, ceilings and the floor warnings)
## takes an optional `height`, the floor it stands on: 0, the street, as always, or a raised floor's top
## (a roof), the prop placed as on the street that much higher (a ceiling hangs ceiling_height over it).
## The node sits at the world origin whatever its parent does (top_level).

## A prop is freed once the player is this far past its end.
const KEEP_BEHIND: float = 30.0
## The warnings' colour: enemy-attack red, in every zone (CLAUDE.md readability rules).
const WARNING_COLOR := Color(1.0, 0.12, 0.08)
## Every lane, at any lane count (ceiling(), roof(): a lane range's last lane below 0 is the last lane).
const ALL_LANES := Vector2i(0, -1)
## warned() asked at a height counts the floor warnings within this of it (metres): those on that floor.
const WARNED_HEIGHT: float = 1.0
## A roof's grey box (roof(..., grey_box)): a plain, unlit-looking grey, nothing a hazard would wear.
const ROOF_COLOR := Color(0.3, 0.31, 0.36)

var world: RunWorld
## Placed props: {node, until}.
var _placed: Array[Dictionary] = []
## Warnings that pulse: {node, base: Transform3D, t}.
var _pulsing: Array[Dictionary] = []
## Floor warnings, for warned(): {node, from, to, x0, x1, y} (track distances, world x, the floor's height).
var _warned: Array[Dictionary] = []
## Target circles' rings by radius (circle_warning): one mesh for every circle of a size (task PERF1).
## (A boss's first row of fences built the skin kit's fence look in its frame, 3.8 ms on the dev machine
## for The House's first lightning row: when the game renders, ShaderWarmup's fence samples build it with
## the fight's load.)
static var _rings: Dictionary = {}


func setup(p_world: RunWorld) -> void:
	world = p_world
	top_level = true
	transform = Transform3D.IDENTITY


## A pink electric fence across `lane` at track distance `at`, on the floor `height` up (0: the street):
## "full" (jump it or switch lanes) or "gapped" (slide under it). With `warning_seconds`, it flickers
## harmlessly (and crackles) that long before it switches on, the fence's own warning.
func fence(lane: int, at: float, variant: String = "full", warning_seconds: float = 0.0, height: float = 0.0) -> Hazard:
	var t: MovementTuning = world.tuning
	var gapped: bool = variant == "gapped"
	var bottom: float = t.fence_gapped_bottom if gapped else 0.0
	var top: float = t.fence_gapped_top if gapped else t.fence_full_top
	var size := Vector3(world.geo.lane_width - 0.2, top - bottom, t.fence_depth)
	var hazard: Hazard = _hazard(Vector3(world.geo.lane_x(lane), height + (bottom + top) * 0.5, TrackGeometry.world_z(at)),
		size, TrackBuilder.LAYER_HAZARD)
	hazard.hazard_name = "fence (%s)" % variant
	hazard.is_electrical = true
	world.skin.fence(hazard, size, -(bottom + top) * 0.5, gapped)
	if warning_seconds > 0.0:
		_add_warning_sound(hazard)
		_warn_then_arm(hazard, warning_seconds)
	keep(hazard, at + t.fence_depth)
	return hazard


## A solid obstacle filling `lane` from `at` on (size: width, height and depth in metres), standing on
## the floor `height` up (0: the street): deadly to run into, and the player can't switch lanes into it
## (a truck's side). Armor doesn't stop it; the shield and the dash do (the shared rules for solid
## collisions).
func block(lane: int, at: float, size: Vector3, block_name: String = "block", height: float = 0.0) -> Hazard:
	var center := Vector3(world.geo.lane_x(lane), height + size.y * 0.5, TrackGeometry.world_z(at + size.z * 0.5))
	var hazard: Hazard = _hazard(center, size, TrackBuilder.LAYER_HAZARD)
	hazard.hazard_name = block_name
	hazard.is_solid = true
	var blocker := Area3D.new()
	blocker.collision_layer = TrackBuilder.LAYER_LANE_BLOCKER
	blocker.collision_mask = 0
	blocker.monitoring = false
	hazard.add_child(blocker)
	_add_shape(blocker, size)
	keep(hazard, at + size.z)
	return hazard


## An anti-grav pad in `lane` at `at`, on the floor `height` up (0: the street), with the zone's pad look.
## Give it a ceiling above (ceiling()), or the player flips up into nothing and drops straight back. It
## flips the player to the first ceiling over it, at whatever height that is (Player.ceiling_y).
func pad(lane: int, at: float, height: float = 0.0) -> Area3D:
	var size := Vector3(world.geo.lane_width * 0.7, 0.5, world.tuning.pad_length)
	var area := Area3D.new()
	area.collision_layer = TrackBuilder.LAYER_TRIGGER
	area.collision_mask = 0
	area.monitoring = false
	area.set_meta(&"kind", &"pad")
	area.position = Vector3(world.geo.lane_x(lane), height + size.y * 0.5, TrackGeometry.world_z(at) - size.z * 0.5)
	add_child(area)
	_add_shape(area, size)
	world.skin.pad(area, size)
	keep(area, at + size.z)
	return area


## A ceiling section from `start` to `end` with the zone's ceiling look, over every lane or the lanes
## `lanes` (Vector2i(first, last): a narrow ceiling, GDD §3, which the player switches lanes within), its
## underside MovementTuning.ceiling_height above the floor `height` up (0: the street, as every level's
## ceilings). The player rides it at its own height (Player.ceiling_y).
func ceiling(start: float, end: float, lanes: Vector2i = ALL_LANES, height: float = 0.0) -> Node3D:
	var root := Node3D.new()
	root.name = "Ceiling"
	add_child(root)
	var section := CeilingSection.make(world.geo, height + world.tuning.ceiling_height, TrackBuilder.HULL_THICKNESS,
		start, end, _lane_range(lanes))
	var body := StaticBody3D.new()
	body.collision_layer = TrackBuilder.LAYER_HULL
	body.collision_mask = 0
	body.position = section.center
	root.add_child(body)
	_add_shape(body, section.size)
	world.skin.ceiling_section(root, section)
	keep(root, end)
	return root


## A ceiling from `start` whose lanes end at distances of their own (GDD §10, the Beach's climb: "the
## ceiling lanes that lead up run further"): lane i's at ends[i], none in a lane whose end is at or before
## `start` (or past the end of `ends`). One ceiling section (ceiling(), each with its own far end's band)
## for each run of neighbouring lanes that end together, its underside ceiling_height above the floor
## `height` up. A rider switches lanes only within the lanes still covered where they are
## (Player._ceiling_over), and drops at their own lane's end. Returns the sections, left to right.
func ceiling_lanes(start: float, ends: PackedFloat32Array, height: float = 0.0) -> Array[Node3D]:
	var out: Array[Node3D] = []
	var n: int = mini(ends.size(), world.geo.lane_count)
	var first: int = 0
	while first < n:
		var last: int = first
		while last + 1 < n and is_equal_approx(ends[last + 1], ends[first]):
			last += 1
		if ends[first] > start:
			out.append(ceiling(start, ends[first], Vector2i(first, last), height))
		first = last + 1
	return out


## A raised floor's top (GDD §10, the Beach's climb: a tiki bar's roof the runner drops onto and runs
## along) over the lanes `lanes` (Vector2i(first, last); the outer lanes reach the walls, as the street
## does) from `start` to `end`, its top `height` up: a box on the floor layer, like the street, reaching
## `depth` down from its top (by default down to the street: a block standing on it, not a slab anything
## passes under). The player lands on it from any height (Player._support_top, _crossed_top) and runs
## along it. Nothing else: no hazard, no lane blocker and, unless `grey_box`, no look (reviews and tests);
## the boss script adds its look and whatever its sides and front must do.
func roof(lanes: Vector2i, start: float, end: float, height: float, depth: float = -1.0,
		grey_box: bool = false) -> StaticBody3D:
	var span: Vector2i = _lane_range(lanes)
	var x0: float = world.geo.lane_floor_span(span.x).x
	var x1: float = world.geo.lane_floor_span(span.y).y
	var thick: float = maxf(depth if depth > 0.0 else height, 0.1)
	var size := Vector3(x1 - x0, thick, maxf(end - start, 0.1))
	var body := StaticBody3D.new()
	body.name = "Roof"
	body.collision_layer = TrackBuilder.LAYER_FLOOR
	body.collision_mask = 0
	body.position = Vector3((x0 + x1) * 0.5, height - thick * 0.5, TrackGeometry.world_z((start + end) * 0.5))
	add_child(body)
	_add_shape(body, size)
	if grey_box:
		GreyboxMaterials.add_box(body, Vector3.ZERO, size, GreyboxMaterials.scenery(ROOF_COLOR))
	keep(body, end)
	return body


## Takes the wall on `side` (-1 left, +1 right) away between two track distances: the player can't
## enter it there (like a sign, without the hurt). The boss script shows what took it, and removes it
## (remove()) to give the wall back.
func block_wall(side: int, from: float, to: float) -> Area3D:
	var area := Area3D.new()
	area.collision_layer = TrackBuilder.LAYER_WALL_BLOCKER
	area.collision_mask = 0
	area.monitoring = false
	area.position = Vector3(side * (world.geo.wall_x() - 0.3), 5.0, -(from + to) * 0.5)
	add_child(area)
	_add_shape(area, Vector3(0.6, 12.0, maxf(to - from, 0.1)))
	keep(area, to)
	return area


## A red warning line on the floor of `lane` from track distance `from` to `to`, on the floor `height` up
## (0: the street): where an attack will strike. It pulses as long as it's shown (a steady glow with
## Reduced flashing).
func lane_warning(lane: int, from: float, to: float, height: float = 0.0) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.mesh = GreyboxMaterials.unit_box()
	mesh.material_override = GreyboxMaterials.glow(WARNING_COLOR, 2.6, 0.75)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var base := Transform3D(Basis.from_scale(Vector3(world.geo.lane_width * 0.34, 0.04, absf(to - from))),
		Vector3(world.geo.lane_x(lane), height + 0.03, -(from + to) * 0.5))
	mesh.transform = base
	add_child(mesh)
	_pulsing.append({"node": mesh, "base": base, "t": 0.0})
	floor_warning(mesh, lane, from, to, height)
	return mesh


## Marks `node`, a boss's own floor warning drawn its own way (Sleep Taker's mist pooling in a lane),
## as a floor warning over `lane` between track distances `from` and `to`, on the floor `height` up (0:
## the street), like lane_warning: warned() counts it while it's shown (pickups keep off it), and it's
## freed once the player is past `to`.
func floor_warning(node: Node3D, lane: int, from: float, to: float, height: float = 0.0) -> Node3D:
	var half: float = world.geo.lane_width * 0.5
	_warned.append({"node": node, "from": minf(from, to), "to": maxf(from, to),
		"x0": world.geo.lane_x(lane) - half, "x1": world.geo.lane_x(lane) + half, "y": height})
	return keep(node, maxf(from, to))


## A red target circle on the floor at track distance `at` over `lane` (x offset `x` from the lane's
## centre), on the floor `height` up (0: the street): where a bomb or a blow will land.
func circle_warning(at: float, lane: int, radius: float = 1.0, x: float = 0.0, height: float = 0.0) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.mesh = _ring(radius)
	mesh.material_override = GreyboxMaterials.glow(WARNING_COLOR, 2.6, 0.85)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var base := Transform3D(Basis.from_scale(Vector3(1.0, 0.25, 1.0)),
		Vector3(world.geo.lane_x(lane) + x, height + 0.05, TrackGeometry.world_z(at)))
	mesh.transform = base
	add_child(mesh)
	_pulsing.append({"node": mesh, "base": base, "t": 0.0})
	var cx: float = world.geo.lane_x(lane) + x
	_warned.append({"node": mesh, "from": at - radius, "to": at + radius, "x0": cx - radius, "x1": cx + radius,
		"y": height})
	keep(mesh, at + radius)
	return mesh


## A target circle's ring of `radius`, shared by every circle that size.
static func _ring(radius: float) -> TorusMesh:
	var key: float = snappedf(radius, 0.001)
	if not _rings.has(key):
		var ring := TorusMesh.new()
		ring.inner_radius = key * 0.78
		ring.outer_radius = key
		ring.rings = 24
		ring.ring_segments = 6
		_rings[key] = ring
	return _rings[key]


## Keeps `node` (added here if it has no parent) until the player is KEEP_BEHIND past `until`.
func keep(node: Node3D, until: float) -> Node3D:
	if node.get_parent() == null:
		add_child(node)
	_placed.append({"node": node, "until": until})
	return node


## Removes a prop now (a warning after its attack, a wall given back).
func remove(node: Node) -> void:
	if node != null and is_instance_valid(node) and not node.is_queued_for_deletion():
		if node is Hazard:
			(node as Hazard).set_enabled(false)
		node.queue_free()


## True while a floor warning (lane_warning, circle_warning) still shown reaches the middle of `lane`
## (where a runner in that lane is: a circle that only grazes the lane's edge doesn't count) somewhere
## between track distances `from` and `to`: an attack is telegraphed there. Asked at a `height` (a raised
## floor's top), only the warnings on that floor (within WARNED_HEIGHT of it) count; by default, a warning
## on any floor does.
func warned(lane: int, from: float, to: float, height: float = NAN) -> bool:
	var x0: float = world.geo.lane_x(lane) - world.geo.lane_width * 0.25
	var x1: float = world.geo.lane_x(lane) + world.geo.lane_width * 0.25
	for i: int in range(_warned.size() - 1, -1, -1):
		var w: Dictionary = _warned[i]
		if not is_instance_valid(w["node"]) or (w["node"] as Node).is_queued_for_deletion():
			_warned.remove_at(i)
			continue
		if not is_nan(height) and absf(float(w["y"]) - height) > WARNED_HEIGHT:
			continue
		if float(w["from"]) <= to and float(w["to"]) >= from and float(w["x0"]) < x1 and float(w["x1"]) > x0:
			return true
	return false


## Props placed so far and still in the arena.
func count() -> int:
	var n: int = 0
	for p: Dictionary in _placed:
		if is_instance_valid(p["node"]) and not (p["node"] as Node).is_queued_for_deletion():
			n += 1
	return n


func _physics_process(_delta: float) -> void:
	if world == null or world.player == null:
		return
	var d: float = world.player.distance
	for i: int in range(_placed.size() - 1, -1, -1):
		var p: Dictionary = _placed[i]
		if not is_instance_valid(p["node"]):
			_placed.remove_at(i)
		elif float(p["until"]) < d - KEEP_BEHIND:
			remove(p["node"])
			_placed.remove_at(i)


func _process(delta: float) -> void:
	for i: int in range(_pulsing.size() - 1, -1, -1):
		var w: Dictionary = _pulsing[i]
		if not is_instance_valid(w["node"]):
			_pulsing.remove_at(i)
			continue
		var node: MeshInstance3D = w["node"]
		w["t"] = float(w["t"]) + delta
		# Widens as it's shown; the beat stops with Reduced flashing.
		var grow: float = 0.85 + 0.25 * clampf(float(w["t"]) / 0.8, 0.0, 1.0)
		var beat: float = 1.0 if Settings.flashing_reduced else 1.0 + 0.12 * sin(float(w["t"]) * 24.0)
		var base: Transform3D = w["base"]
		node.transform = Transform3D(base.basis * Basis.from_scale(Vector3(grow * beat, 1.0, 1.0 if node.mesh is BoxMesh else grow * beat)),
			base.origin)


func _hazard(center: Vector3, size: Vector3, layers: int) -> Hazard:
	var hazard := Hazard.new()
	hazard.size = size
	hazard.collision_layer = layers
	hazard.collision_mask = 0
	hazard.monitoring = false
	hazard.position = center
	add_child(hazard)
	_add_shape(hazard, size)
	return hazard


## The fence's warning sound (the track's pulsing fences crackle the same way).
func _add_warning_sound(hazard: Hazard) -> void:
	var sfx: SfxLibrary = world.sfx_library
	if sfx == null or sfx.stream(&"fence_warning") == null:
		return
	var telegraph := HazardTelegraph.new()
	hazard.add_child(telegraph)
	telegraph.bind(hazard, sfx.stream(&"fence_warning"), sfx.volume(&"fence_warning"),
		sfx.warning_full_volume_distance, sfx.warning_max_distance)


## Shows the hazard's WARNING state (harmless) for `seconds`, then switches it on.
func _warn_then_arm(hazard: Hazard, seconds: float) -> void:
	hazard.state = Hazard.State.WARNING
	hazard.state_changed.emit(Hazard.State.WARNING)
	# By id: a boss may remove the fence while it's still flickering in.
	var id: int = hazard.get_instance_id()
	get_tree().create_timer(seconds, false, true).timeout.connect(func() -> void:
		var h := instance_from_id(id) as Hazard
		if h != null and h.state == Hazard.State.WARNING:
			h.set_enabled(true))


## A lane range (Vector2i(first, last)) within the track's lanes; a last lane below 0 is the last lane
## (ALL_LANES).
func _lane_range(lanes: Vector2i) -> Vector2i:
	var last_lane: int = world.geo.lane_count - 1
	var first: int = clampi(lanes.x, 0, last_lane)
	return Vector2i(first, last_lane if lanes.y < 0 else clampi(lanes.y, first, last_lane))


static func _add_shape(owner_node: CollisionObject3D, size: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	owner_node.add_child(shape)
