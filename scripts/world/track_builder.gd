class_name TrackBuilder
extends Node3D
## Builds a LevelLayout in chunks around the player and frees chunks behind them.
## This creates every gameplay node (floor and hull collision, hazards, triggers) from abstract
## pieces only. How they look is up to the ZoneSkin, which never affects collision.

## A falling gantryway's pillar broke and it begins to fall (task Q3; Gantryway.fell).
signal gantryway_fell(gantryway: Gantryway)
## A falling gantryway came down another tick (Gantryway.swept): what's in its path is crushed (RunWorld).
signal gantryway_swept(gantryway: Gantryway)
## A falling gantryway landed (Gantryway.landed).
signal gantryway_landed(gantryway: Gantryway)
## A teleporter (task Q4; Teleporter) was built, its looks queued for the skin; its antenna's light ticks from update().
signal teleporter_built(teleporter: Teleporter)

const CHUNK_LENGTH: float = 40.0
const BUILD_AHEAD: float = 180.0
const KEEP_BEHIND: float = 30.0
## Floor is built this far past the finish line so the level end doesn't drop into the void.
const RUN_OUT: float = 80.0
## Where the first chunk starts: KEEP_BEHIND and a little more behind the start line, so the run begins on built track.
const TRACK_START: float = -KEEP_BEHIND - 10.0
const FLOOR_THICKNESS: float = 1.0
const HULL_THICKNESS: float = 0.8

const LAYER_FLOOR: int = 1
const LAYER_HULL: int = 2
const LAYER_HAZARD: int = 4
const LAYER_WALL_BLOCKER: int = 8
const LAYER_TRIGGER: int = 16
## Solid sides the player can't switch lanes into (GDD §9.3: the hover truck's sides; a zone doodad's).
const LAYER_LANE_BLOCKER: int = 64
## Zone doodads' bodies (GDD §3, owner's playtest September 30, 2026): running into one's front
## pushes the player into a neighbouring lane (Player). Never a hazard: no hit, and shots and
## weapons never see it.
const LAYER_DOODAD: int = 128
## Dash walls' boxes (task H7a; GDD §9.14): the box a wall's look fills, which the Player's approach check
## finds (Player._check_dash_walls: the dash smashing it a frame before contact, a wall runner passing beside
## it). Its hitbox is a Hazard on the hazard layer, a little smaller (dash_wall_hitbox). Never a hazard or a
## lane blocker itself.
const LAYER_DASH_WALL: int = 256
## A doodad's body in the hitbox view (debug_toggle_hitboxes): see-through blue, apart from the
## hazards' red.
const DOODAD_DEBUG := Color(0.2, 0.55, 1.0, 0.3)
## A dash wall's hitbox starts this far above the floor: a slide (its body from the floor up) still meets
## it, and the floor's own top never counts as touching it.
const DASH_WALL_FLOOR_LIFT: float = 0.05
## A floor cut's lane is drawn in slices this long (and cut at chunk cuts), which it hides as its front
## passes them and shortens the one its front is in (FloorCut): short enough that one shortened slice
## barely shows, long enough to keep a chunk's build cheap.
const CUT_SLICE: float = 4.0
## With a dressing budget (dress_budget_usec), a chunk's look is finished whatever the budget once the
## player is this close to its start: built BUILD_AHEAD ahead, it has the time of BUILD_AHEAD - DRESS_BY
## metres of running to be dressed a little at a time.
const DRESS_BY: float = 120.0
## Two wall piece ends closer than this are the same point (metres; _build_boundary_wall).
const WALL_PIECE_EPSILON: float = 0.001

var layout: LevelLayout
var tuning: MovementTuning
var geo: TrackGeometry
var skin: ZoneSkin
## Optional: hazard warning sounds. Tests leave it empty.
var sfx: SfxLibrary
var show_hitboxes: bool = false
## Spreads each chunk's dressing over frames (task PERF1: the skin's walls, floor and hazard looks for
## one chunk took most of a chunk's build, 1.5 to 4 ms in one frame on a desktop CPU, several times
## that on a phone, every 1.6 to 1.9 s of play). Above 0, a chunk's gameplay nodes (collision, hazards,
## triggers, doodads' bodies) are still all built in the frame it's built, exactly as before, but the
## skin's calls for it wait in a queue that update() works through in order, for about this many
## microseconds a frame (at least one call a frame), finishing a chunk's whatever the time once the
## player is DRESS_BY from it. 0 (tests, review tools) dresses every chunk as it's built. A run sets it
## (LevelRun, from PerformanceTuning.chunk_dress_budget_ms).
var dress_budget_usec: int = 0

var _lane_gaps: Array = []
## The layout's floor cuts by lane, in track order (LevelLayout.cuts).
var _lane_cuts: Array = []
## Built floor cuts (FloorCut nodes) by FloorCut.key_for(lane, end).
var _cut_nodes: Dictionary = {}
var _buckets: Dictionary = {}
var _chunks: Dictionary = {}
var _next_chunk: int = 0
var _last_chunk: int = 0
var _level_time: float = 0.0
## Built fence hazards by their index in layout.fences, so an EMP can switch them off.
var _fence_nodes: Dictionary = {}
## Built wall fence hazards by their index in layout.wall_fences (task B5), likewise.
var _wall_fence_nodes: Dictionary = {}
## Built ceiling fence hazards by their index in layout.ceiling_fences (task I4), likewise.
var _ceiling_fence_nodes: Dictionary = {}
## Built dash walls (task H7a), in the order they were built (dash_wall_for, dash_wall_nodes).
var _dash_wall_nodes: Array[DashBreakable] = []
## Built falling gantryways (task Q3), in the order they were built (gantryway_for, gantryway_nodes).
var _gantryway_nodes: Array[Gantryway] = []
## Built teleporters (task Q4), in the order they were built (teleporter_for, teleporter_nodes).
var _teleporter_nodes: Array[Teleporter] = []
## The skin's calls still to make (dress_budget_usec), in order: [chunk start, chunk root, Callable].
var _dressing: Array[Array] = []
## The chunk being built (_build_chunk): its start and root, for the calls it queues.
var _dress_start: float = 0.0
var _dress_root: Node3D


func set_layout(p_layout: LevelLayout, p_tuning: MovementTuning, p_skin: ZoneSkin = null) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	layout = p_layout
	tuning = p_tuning
	skin = p_skin if p_skin != null else GreyboxSkin.new()
	geo = TrackGeometry.new(layout.lane_count, tuning)
	_chunks.clear()
	_buckets.clear()
	_fence_nodes.clear()
	_wall_fence_nodes.clear()
	_ceiling_fence_nodes.clear()
	_dash_wall_nodes.clear()
	_gantryway_nodes.clear()
	_teleporter_nodes.clear()
	_cut_nodes.clear()
	_dressing.clear()
	_next_chunk = 0
	_lane_gaps.clear()
	_lane_cuts.clear()
	for lane: int in layout.lane_count:
		_lane_gaps.append([])
		_lane_cuts.append([])
	_add_pieces(layout, 0, 0, 0)


## Lengthens the track while it runs (a boss arena's next lap, BossArena; endless mode's next stretch):
## appends every list of `extra` to the layout (LevelLayout.append_pieces: floor cuts and wall fences
## too, so either can be added during a run) and moves its end to extra.length. The pieces must lie past
## built_until(): chunks already built don't change. Credits and enemies only join the layout's lists;
## the credit field and the enemy director don't pick them up.
func extend_layout(extra: LevelLayout) -> void:
	var first_fence: int = layout.fences.size()
	var first_wall_fence: int = layout.wall_fences.size()
	var first_ceiling_fence: int = layout.ceiling_fences.size()
	layout.append_pieces(extra)
	_add_pieces(extra, first_fence, first_wall_fence, first_ceiling_fence)


## Track distance up to which chunks are built.
func built_until() -> float:
	return _next_chunk * CHUNK_LENGTH


## The stretch of track [start, end] whose walls the builder draws for a layout `length` metres long: from the first
## chunk's start (TRACK_START) to the end of the last chunk it builds, past the run-out (RUN_OUT). A wall layout meant
## to cover every wall the track shows spans it (task O1: the Terminal's arches, WallGapPlacement._arches).
static func wall_span(length: float) -> Vector2:
	var last: int = int(ceil((length + RUN_OUT) / CHUNK_LENGTH))
	return Vector2(TRACK_START, (last + 1) * CHUNK_LENGTH)


## The skin's calls still waiting to dress built chunks (dress_budget_usec; 0 without a budget).
func dressing_left() -> int:
	return _dressing.size()


## Dresses every built chunk now (tests and tools that look at a chunk right after it's built).
func dress_all() -> void:
	while not _dressing.is_empty():
		_dress_next()


## Builds chunks ahead of `player_distance` and frees chunks that are fully behind it.
## `level_time` is the level clock, which keeps pulsing hazards in sync with it.
func update(player_distance: float, level_time: float) -> void:
	_level_time = level_time
	while _next_chunk <= _last_chunk and _next_chunk * CHUNK_LENGTH < player_distance + BUILD_AHEAD:
		_build_chunk(_next_chunk)
		_next_chunk += 1
	for index: int in _chunks.keys():
		var chunk: Dictionary = _chunks[index]
		if chunk["max_end"] < player_distance - KEEP_BEHIND:
			(chunk["node"] as Node3D).queue_free()
			_chunks.erase(index)
	_dress_some(player_distance)
	light_teleporters(level_time)
	# Floor cuts: a hold after a block that's over lets go (FloorCut.tick), before the player moves.
	for key: String in _cut_nodes.keys():
		var cut: Variant = _cut_nodes[key]
		if not is_instance_valid(cut) or (cut as Node).is_queued_for_deletion():
			_cut_nodes.erase(key)
		else:
			(cut as FloorCut).tick(level_time)


## The floor cut built for the layout's cut in `lane` whose cause waits at `end` (LevelLayout.cuts), or
## null until the chunk where its stretch starts is built (and once it's freed behind the player).
## Its cause runs it (FloorCut.advance_to, stop, hold_under).
func floor_cut(lane: int, end: float) -> FloorCut:
	var cut: Variant = _cut_nodes.get(FloorCut.key_for(lane, end))
	if cut == null or not is_instance_valid(cut) or (cut as Node).is_queued_for_deletion():
		return null
	return cut as FloorCut


## Every floor cut built and still on the track (tests and review tools).
func floor_cuts() -> Array[FloorCut]:
	var out: Array[FloorCut] = []
	for cut: Variant in _cut_nodes.values():
		if is_instance_valid(cut) and not (cut as Node).is_queued_for_deletion():
			out.append(cut as FloorCut)
	return out


## Switches off, for the rest of the level, every fence within `radius` of `center` (world space),
## including fences not built yet (GDD §9.1: a destroyed generator's EMP): floor fences, wall fences
## (task B5; GDD §9.1: "a generator's EMP switches them off") and ceiling fences (task I4: the same rules as a
## floor fence's), each measured from where its field meets the track (a floor or ceiling fence's lane, a wall
## fence's wall face) at the EMP's height. Returns how many.
func disable_fences_near(center: Vector3, radius: float) -> int:
	var count: int = 0
	for f: Dictionary in layout.fences:
		if f.get("disabled", false):
			continue
		var pos := Vector3(geo.lane_x(f["lane"]), center.y, TrackGeometry.world_z(f["at"]))
		if pos.distance_to(center) > radius:
			continue
		f["disabled"] = true
		count += 1
		var node: Variant = _fence_nodes.get(f["index"])
		if node != null and is_instance_valid(node):
			(node as Hazard).set_enabled(false)
	for w: Dictionary in layout.wall_fences:
		if w.get("disabled", false):
			continue
		var at := Vector3(int(w["side"]) * geo.wall_x(), center.y, TrackGeometry.world_z(w["at"]))
		if at.distance_to(center) > radius:
			continue
		w["disabled"] = true
		count += 1
		var wall_node: Variant = _wall_fence_nodes.get(w.get("index", -1))
		if wall_node != null and is_instance_valid(wall_node):
			(wall_node as Hazard).set_enabled(false)
	for f: Dictionary in layout.ceiling_fences:
		if f.get("disabled", false):
			continue
		if Vector3(geo.lane_x(int(f["lane"])), center.y, TrackGeometry.world_z(float(f["at"]))).distance_to(center) > radius:
			continue
		f["disabled"] = true
		count += 1
		var ceiling_node: Variant = _ceiling_fence_nodes.get(f.get("index", -1))
		if ceiling_node != null and is_instance_valid(ceiling_node):
			(ceiling_node as Hazard).set_enabled(false)
	return count


## Built fence hazards (for tests and effects).
func fence_hazards() -> Array[Hazard]:
	var out: Array[Hazard] = []
	for h: Variant in _fence_nodes.values():
		if is_instance_valid(h):
			out.append(h)
	return out


## Built wall fence hazards (task B5; for tests, review tools and effects), in layout order.
func wall_fence_hazards() -> Array[Hazard]:
	var out: Array[Hazard] = []
	var keys: Array = _wall_fence_nodes.keys()
	keys.sort()
	for k: Variant in keys:
		var h: Variant = _wall_fence_nodes[k]
		if is_instance_valid(h) and not (h as Node).is_queued_for_deletion():
			out.append(h)
	return out


## Built ceiling fence hazards (task I4; for tests, review tools and effects), in layout order.
func ceiling_fence_hazards() -> Array[Hazard]:
	var out: Array[Hazard] = []
	var keys: Array = _ceiling_fence_nodes.keys()
	keys.sort()
	for k: Variant in keys:
		var h: Variant = _ceiling_fence_nodes[k]
		if is_instance_valid(h) and not (h as Node).is_queued_for_deletion():
			out.append(h)
	return out


## The built dash wall for layout entry `w` (LevelLayout.dash_walls; task H7a), or null until the chunk where it
## stands is built (and once it's freed behind the player, or if it was broken before it was built).
func dash_wall_for(w: Dictionary) -> DashBreakable:
	for node: DashBreakable in _dash_wall_nodes:
		if is_instance_valid(node) and not node.is_queued_for_deletion() and is_same(node.entry, w):
			return node
	return null


## Every dash wall built and still on the track (tests, review tools), in track order.
func dash_wall_nodes() -> Array[DashBreakable]:
	var out: Array[DashBreakable] = []
	for node: DashBreakable in _dash_wall_nodes:
		if is_instance_valid(node) and not node.is_queued_for_deletion():
			out.append(node)
	return out


## The built falling gantryway for layout entry `g` (LevelLayout.gantryways; task Q3), or null until the chunk where its
## walkway starts is built (and once it's freed behind the player).
func gantryway_for(g: Dictionary) -> Gantryway:
	for node: Gantryway in gantryway_nodes():
		if is_same(node.entry, g):
			return node
	return null


## Every falling gantryway built and still on the track (tests, review tools, RunWorld), in track order.
func gantryway_nodes() -> Array[Gantryway]:
	var out: Array[Gantryway] = []
	for node: Gantryway in _gantryway_nodes:
		if is_instance_valid(node) and not node.is_queued_for_deletion():
			out.append(node)
	return out


## The built teleporter for layout entry `tp` (LevelLayout.teleporters; task Q4), or null until the chunk where its pad
## stands is built (and once it's freed behind the player).
func teleporter_for(tp: Dictionary) -> Teleporter:
	for node: Teleporter in teleporter_nodes():
		if is_same(node.entry, tp):
			return node
	return null


## Draws every built teleporter's antenna light for level time `level_time` (task Q4; Teleporter.tick): from update(),
## and from RunWorld once the runner's step has moved the level clock on (RunWorld._process), so a frame shows the light
## a touch at that moment decides by.
func light_teleporters(level_time: float) -> void:
	for i: int in range(_teleporter_nodes.size() - 1, -1, -1):
		var tp: Teleporter = _teleporter_nodes[i]
		if not is_instance_valid(tp) or tp.is_queued_for_deletion():
			_teleporter_nodes.remove_at(i)
		else:
			tp.tick(level_time)


## Every teleporter built and still on the track (tests, review tools), in track order.
func teleporter_nodes() -> Array[Teleporter]:
	var out: Array[Teleporter] = []
	for node: Teleporter in _teleporter_nodes:
		if is_instance_valid(node) and not node.is_queued_for_deletion():
			out.append(node)
	return out


## A dash wall's look's box (task H7a; GDD §9.14), `depth` long along the track: as wide as the floor less
## MovementTuning.dash_wall_wall_room beside each side wall (the strip a wall runner passes it in), and
## dash_wall_height tall. Vector3(width, height, depth), centred across the track.
static func dash_wall_size(p_geo: TrackGeometry, t: MovementTuning, depth: float) -> Vector3:
	return Vector3(2.0 * (p_geo.wall_x() - t.dash_wall_wall_room), t.dash_wall_height, depth)


## A dash wall's hitbox inside its look's box `size` (dash_wall_size), centred on the box's middle: the box
## less MovementTuning.dash_wall_inset at its sides and its face (forgiving, CLAUDE.md principle 4), from
## DASH_WALL_FLOOR_LIFT above the floor to its top. AABB in the box's own space (its face toward the runner at
## +z, its floor at -y).
static func dash_wall_hitbox(size: Vector3, t: MovementTuning) -> AABB:
	var inset: float = clampf(t.dash_wall_inset, 0.0, size.z * 0.5)
	var half := size * 0.5
	var from := Vector3(-half.x + inset, -half.y + DASH_WALL_FLOOR_LIFT, -half.z)
	var to := Vector3(half.x - inset, half.y, half.z - inset)
	return AABB(from, to - from)


func set_hitboxes_visible(on: bool) -> void:
	show_hitboxes = on
	for node: Node in get_tree().get_nodes_in_group(&"debug_hitbox"):
		if is_ancestor_of(node):
			(node as Node3D).visible = on


## Sorts the track pieces of `pieces` (the whole layout, or an extension of it) into the chunks that
## build them. `first_fence`, `first_wall_fence` and `first_ceiling_fence` are the layout indices of its first
## fence, wall fence and ceiling fence.
func _add_pieces(pieces: LevelLayout, first_fence: int, first_wall_fence: int, first_ceiling_fence: int) -> void:
	_last_chunk = int(ceil((layout.length + RUN_OUT) / CHUNK_LENGTH))
	for g: Dictionary in pieces.gaps:
		_lane_gaps[g["lane"]].append(g)
	for list: Array in _lane_gaps:
		list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["start"] < b["start"])
	for i: int in pieces.fences.size():
		pieces.fences[i]["index"] = first_fence + i
	_bucket("fences", pieces.fences, "at", tuning.fence_depth)
	for i: int in pieces.wall_fences.size():
		pieces.wall_fences[i]["index"] = first_wall_fence + i
	_bucket("wall_fences", pieces.wall_fences, "at", tuning.fence_depth)
	_bucket("signs", pieces.signs, "start", 0.0, "end")
	_bucket("hulls", pieces.hulls, "start", 0.0, "end")
	_bucket("pads", pieces.pads, "at", tuning.pad_length)
	_bucket("ramps", pieces.ramps, "at", tuning.ramp_length)
	_bucket("speed_pads", pieces.speed_pads, "at", tuning.speed_pad_length)
	_bucket("doodads", pieces.doodads, "start", 0.0, "end")
	_bucket("dash_walls", pieces.dash_walls, "start", 0.0, "end")
	_bucket("gantryways", pieces.gantryways, "start", 0.0, "end")
	# A teleporter (task Q4) is built in the chunk where its pad stands, which stays until its output pads (its own nodes)
	# are behind the player.
	for tp: Dictionary in pieces.teleporters:
		var reach: float = float(tp["end"])
		for o: Dictionary in tp.get("outputs", []):
			reach = maxf(reach, float(o["end"]))
		var index: int = maxi(0, int(floor(float(tp["at"]) / CHUNK_LENGTH)))
		if not _buckets.has(index):
			_buckets[index] = {"max_end": 0.0}
		var bucket: Dictionary = _buckets[index]
		if not bucket.has("teleporters"):
			bucket["teleporters"] = []
		bucket["teleporters"].append(tp)
		bucket["max_end"] = maxf(bucket["max_end"], reach)
	for i: int in pieces.ceiling_fences.size():
		pieces.ceiling_fences[i]["index"] = first_ceiling_fence + i
	_bucket("ceiling_fences", pieces.ceiling_fences, "at", tuning.fence_depth)
	_bucket("return_pads", pieces.return_pads, "at", tuning.pad_length)
	# A floor cut is built in the chunk where its stretch starts, which stays until the player is past
	# its cause's spot; each chunk draws the slices of its lane's floor within it.
	for c: Dictionary in pieces.cuts:
		_lane_cuts[int(c["lane"])].append(c)
		var index: int = maxi(0, int(floor(float(c["start"]) / CHUNK_LENGTH)))
		if not _buckets.has(index):
			_buckets[index] = {"max_end": 0.0}
		var bucket: Dictionary = _buckets[index]
		if not bucket.has("cuts"):
			bucket["cuts"] = []
		bucket["cuts"].append(c)
		bucket["max_end"] = maxf(bucket["max_end"], FloorCutPlan.lane_window(c).y)
	for list: Array in _lane_cuts:
		list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["start"] < b["start"])


## Groups items by the chunk they start in. An item spanning several chunks keeps its
## chunk alive until the item's far end (`end_key`, or start + extent) is behind the player.
func _bucket(kind: String, items: Array[Dictionary], start_key: String, extent: float, end_key: String = "") -> void:
	for item: Dictionary in items:
		var start: float = item[start_key]
		var end: float = float(item[end_key]) if end_key != "" else start + extent
		var index: int = maxi(0, int(floor(start / CHUNK_LENGTH)))
		if not _buckets.has(index):
			_buckets[index] = {"max_end": 0.0}
		var bucket: Dictionary = _buckets[index]
		if not bucket.has(kind):
			bucket[kind] = []
		bucket[kind].append(item)
		bucket["max_end"] = maxf(bucket["max_end"], end)


func _build_chunk(index: int) -> void:
	var root := Node3D.new()
	root.name = "Chunk%d" % index
	add_child(root)
	var c0: float = index * CHUNK_LENGTH
	var c1: float = c0 + CHUNK_LENGTH
	if index == 0:
		c0 = TRACK_START
	var bucket: Dictionary = _buckets.get(index, {})
	_chunks[index] = {"node": root, "max_end": maxf(c1, float(bucket.get("max_end", 0.0)))}
	_dress_start = c0
	_dress_root = root

	# Floor cuts whose stretch starts here, before the floor slices that register with them.
	for c: Dictionary in bucket.get("cuts", []):
		_build_cut(root, c)
	for lane: int in layout.lane_count:
		for piece: Vector4 in _floor_pieces(lane, c0, c1):
			_build_floor_piece(root, lane, Vector2(piece.x, piece.y), piece.z > 0.5, piece.w > 0.5)
		for c: Dictionary in _lane_cuts[lane]:
			if float(c["start"]) < c1 and float(c["end"]) > c0:
				_build_cut_slices(root, c, c0, c1)
	var wall_enemies: Array[Dictionary] = _enemies_between(c0, c1)
	for side: int in [-1, 1]:
		# Task O1: a level whose walls are a boundary (the Terminal's arches) draws them as standing pieces with open
		# space between them.
		if not layout.wall_running:
			_build_boundary_wall(root, index, side, c0, c1, wall_enemies)
			continue
		# The skin notes a side's wall enemies just before it draws that side (one call, so nothing comes
		# between them in the queue). A wall gap (LevelLayout.wall_gaps) leaves the wall out: the skin
		# draws the solid stretches only, and the gap's look (its edges) where it is.
		var solid: Array[Vector2] = layout.wall_solid_pieces(side, c0, c1)
		var gaps: Array[Vector2] = layout.wall_gap_spans(side, c0, c1)
		var near_gaps: Array[Vector2] = layout.wall_gap_spans(side, c0 - CHUNK_LENGTH, c1 + CHUNK_LENGTH)
		# Task J2: a wall-run gap's lit wall, the way across it (drawn over the wall, after it).
		var guides: Array[Vector3] = layout.wall_run_guides(side, c0, c1)
		_dress(func() -> void:
			skin.note_wall_gaps(side, near_gaps)
			skin.note_wall_enemies(side, c0, c1, wall_enemies)
			for piece: Vector2 in solid:
				skin.wall_section(root, side, side * geo.wall_x(), piece.x, piece.y)
			for gap: Vector2 in gaps:
				skin.wall_gap(root, side, side * geo.wall_x(), maxf(gap.x, c0), minf(gap.y, c1), gap)
			for lit: Vector3 in guides:
				skin.wall_run_guide(root, side, side * geo.wall_x(), maxf(lit.x, c0), minf(lit.z, c1), lit))
	if layout.length >= c0 and layout.length < c1:
		_dress(skin.finish_line.bind(root, geo.half_width() * 2.0, layout.length))

	for f: Dictionary in bucket.get("fences", []):
		_build_fence(root, f)
	for w: Dictionary in bucket.get("wall_fences", []):
		_build_wall_fence(root, w)
	for s: Dictionary in bucket.get("signs", []):
		_build_sign(root, s)
	for h: Dictionary in bucket.get("hulls", []):
		_build_hull(root, h)
	for p: Dictionary in bucket.get("pads", []):
		_build_pad(root, p)
	for r: Dictionary in bucket.get("ramps", []):
		_build_ramp(root, r)
	for sp: Dictionary in bucket.get("speed_pads", []):
		_build_speed_pad(root, sp)
	for d: Dictionary in bucket.get("doodads", []):
		_build_doodad(root, d)
	for w: Dictionary in bucket.get("dash_walls", []):
		_build_dash_wall(root, w)
	for g: Dictionary in bucket.get("gantryways", []):
		_build_gantryway(root, g)
	for tp: Dictionary in bucket.get("teleporters", []):
		_build_teleporter(root, tp)
	for f: Dictionary in bucket.get("ceiling_fences", []):
		_build_ceiling_fence(root, f)
	for p: Dictionary in bucket.get("return_pads", []):
		_build_return_pad(root, p)


## A skin call for the chunk being built: made now, or queued with a dressing budget (dress_budget_usec).
func _dress(work: Callable) -> void:
	if dress_budget_usec <= 0:
		work.call()
	else:
		_dressing.append([_dress_start, _dress_root, work])


## Makes queued skin calls for about dress_budget_usec (at least one), and every call for a chunk the
## player is within DRESS_BY of.
func _dress_some(player_distance: float) -> void:
	var t0: int = Time.get_ticks_usec()
	var made: int = 0
	while not _dressing.is_empty():
		var urgent: bool = float(_dressing[0][0]) < player_distance + DRESS_BY
		if made > 0 and not urgent and Time.get_ticks_usec() - t0 >= dress_budget_usec:
			return
		_dress_next()
		made += 1


func _dress_next() -> void:
	var item: Array = _dressing.pop_front()
	# A chunk freed before it was dressed (a test that jumps ahead) needs no look.
	if is_instance_valid(item[1]) and not (item[1] as Node).is_queued_for_deletion():
		(item[2] as Callable).call()


## The layout's enemy entries whose track distance falls in [c0, c1) (ZoneSkin.note_wall_enemies()).
func _enemies_between(c0: float, c1: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in layout.enemies:
		var at: float = float(e.get("at", 0.0))
		if at >= c0 and at < c1:
			out.append(e)
	return out


## Wall `side` of a level without wall running (task O1; LevelLayout.wall_running off: the Terminal, whose walls are a
## row of narrow arches and a boundary everywhere, GDD §5 Zone 8) for chunk `index`, [c0, c1), under `root`. No
## wall-running surface stops anywhere there, so the open space between its standing pieces (its wall gaps) has none of
## a wall gap's orange marks: the skin draws each opening's part in the chunk with ZoneSkin.wall_opening (the whole
## opening as `gap`). Each standing piece of wall (a solid piece: an arch) and each broken stump (LevelLayout
## .wall_stumps) is drawn whole, with ZoneSkin.wall_section and ZoneSkin.wall_stump, in the chunk where it starts (its
## far end keeps the chunk built), so a skin draws an arch's look once and never cut in two at a chunk's edge; a piece
## longer than a chunk (none in the Terminal) is drawn chunk by chunk, as every level's walls are. Before drawing, the
## skin notes the side's openings near the chunk and its wall enemies, as it does for any wall. The order: the
## sections, the openings, then the stumps standing in them.
func _build_boundary_wall(root: Node3D, index: int, side: int, c0: float, c1: float, wall_enemies: Array[Dictionary]) -> void:
	var reach: float = CHUNK_LENGTH
	var near_gaps: Array[Vector2] = layout.wall_gap_spans(side, c0 - reach, c1 + reach)
	var openings: Array[Vector2] = layout.wall_gap_spans(side, c0, c1)
	var sections: Array[Vector2] = []
	for piece: Vector2 in layout.wall_solid_pieces(side, c0 - reach, c1 + reach):
		if piece.x > c0 - reach + WALL_PIECE_EPSILON and piece.y < c1 + reach - WALL_PIECE_EPSILON:
			# Whole within the stretch looked at: drawn by the chunk it starts in.
			if piece.x >= c0 and piece.x < c1:
				sections.append(piece)
		else:
			var part := Vector2(maxf(piece.x, c0), minf(piece.y, c1))
			if part.y > part.x + WALL_PIECE_EPSILON:
				sections.append(part)
	var stumps: Array[Vector2] = []
	for s: Vector2 in layout.wall_stump_spans(side, c0, c1 + reach):
		if s.x >= c0 and s.x < c1:
			stumps.append(s)
	var far: float = float(_chunks[index]["max_end"])
	for piece: Vector2 in sections:
		far = maxf(far, piece.y)
	for stump: Vector2 in stumps:
		far = maxf(far, stump.y)
	_chunks[index]["max_end"] = far
	var face_x: float = side * geo.wall_x()
	_dress(func() -> void:
		skin.note_wall_gaps(side, near_gaps)
		skin.note_wall_enemies(side, c0, c1, wall_enemies)
		for piece: Vector2 in sections:
			skin.wall_section(root, side, face_x, piece.x, piece.y)
		for gap: Vector2 in openings:
			skin.wall_opening(root, side, face_x, maxf(gap.x, c0), minf(gap.y, c1), gap)
		for stump: Vector2 in stumps:
			skin.wall_stump(root, side, face_x, stump.x, stump.y))


## The ranges of one lane's floor within [c0, c1) the chunk builds as pieces: Vector4(start, end,
## edge_start, edge_end), the edges 1 where a gap borders the piece there (0 elsewhere). A floor cut's
## stretch (LevelLayout.cuts) is left out like a gap, but borders the pieces beside it with no edge:
## its own slices carry the floor on (_build_cut_slices).
func _floor_pieces(lane: int, c0: float, c1: float) -> Array[Vector4]:
	# [start, end, a gap (or a cut)], in track order.
	var holes: Array[Array] = []
	for g: Dictionary in _lane_gaps[lane]:
		if float(g["end"]) > c0 and float(g["start"]) < c1:
			holes.append([float(g["start"]), float(g["end"]), true])
	if not _lane_cuts[lane].is_empty():
		for c: Dictionary in _lane_cuts[lane]:
			if float(c["end"]) > c0 and float(c["start"]) < c1:
				holes.append([float(c["start"]), float(c["end"]), false])
		holes.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var pieces: Array[Vector4] = []
	var cursor: float = c0
	var edge_start: bool = false
	for h: Array in holes:
		var hs: float = h[0]
		var he: float = h[1]
		if he <= cursor:
			continue
		if hs > cursor:
			pieces.append(Vector4(cursor, hs, 1.0 if edge_start else 0.0, 1.0 if h[2] else 0.0))
		if he > cursor:
			cursor = he
			edge_start = h[2]
	if cursor < c1:
		pieces.append(Vector4(cursor, c1, 1.0 if edge_start else 0.0, 0.0))
	return pieces


## Floor cut `c` (LevelLayout.cuts), in the chunk `root` where its stretch starts: its collision and
## the skin's look of the hole (FloorCut).
func _build_cut(root: Node3D, c: Dictionary) -> void:
	var cut := FloorCut.new()
	root.add_child(cut)
	cut.setup(geo, c, FLOOR_THICKNESS, skin)
	_cut_nodes[FloorCut.key_for(int(c["lane"]), float(c["end"]))] = cut


## The lane's floor over floor cut `c`'s stretch within [c0, c1), as the skin draws any floor
## (floor_segment, with no gap edges: the floor runs on), in slices of CUT_SLICE metres from the cut's
## start, each under a node of its own the cut hides or shortens as it runs (FloorCut.add_slice).
## No collision: the cut holds the stretch's.
func _build_cut_slices(root: Node3D, c: Dictionary, c0: float, c1: float) -> void:
	var lane: int = int(c["lane"])
	var start: float = float(c["start"])
	var lo: float = maxf(start, c0)
	var hi: float = minf(float(c["end"]), c1)
	var cut: FloorCut = floor_cut(lane, float(c["end"]))
	var span: Vector2 = geo.lane_floor_span(lane)
	var k: int = maxi(0, floori((lo - start) / CUT_SLICE))
	var a: float = lo
	while a < hi - 0.0005:
		var b: float = minf(start + (k + 1) * CUT_SLICE, hi)
		k += 1
		if b <= a + 0.0005:
			continue
		var slice := Node3D.new()
		slice.name = "CutSlice"
		root.add_child(slice)
		var center := Vector3((span.x + span.y) * 0.5, -FLOOR_THICKNESS * 0.5, -(a + b) * 0.5)
		_dress(skin.floor_segment.bind(slice, center, Vector3(span.y - span.x, FLOOR_THICKNESS, b - a), geo.lane_x(lane),
			false, false))
		if cut != null:
			cut.add_slice(slice, a, b)
		a = b


func _build_floor_piece(root: Node3D, lane: int, piece: Vector2, edge_start: bool, edge_end: bool) -> void:
	var span: Vector2 = geo.lane_floor_span(lane)
	var center := Vector3((span.x + span.y) * 0.5, -FLOOR_THICKNESS * 0.5, -(piece.x + piece.y) * 0.5)
	var size := Vector3(span.y - span.x, FLOOR_THICKNESS, piece.y - piece.x)
	_static_box(root, center, size, LAYER_FLOOR)
	_dress(skin.floor_segment.bind(root, center, size, geo.lane_x(lane), edge_start, edge_end))


func _build_fence(root: Node3D, f: Dictionary) -> void:
	var gapped: bool = f["variant"] == "gapped"
	var bottom: float = tuning.fence_gapped_bottom if gapped else 0.0
	var top: float = tuning.fence_gapped_top if gapped else tuning.fence_full_top
	var size := Vector3(geo.lane_width - 0.2, top - bottom, tuning.fence_depth)
	var hazard := _hazard(root, Vector3(geo.lane_x(f["lane"]), (bottom + top) * 0.5, -float(f["at"])), size, LAYER_HAZARD)
	hazard.hazard_name = "fence (%s%s)" % [f["variant"], ", pulsing" if f["pulsing"] else ""]
	hazard.is_electrical = true
	if f["pulsing"]:
		hazard.setup_pulsing(f["pulse_on"], f["pulse_off"], tuning.fence_pulse_warning, f["phase"], _level_time)
		if sfx != null and sfx.stream(&"fence_warning") != null:
			var telegraph := HazardTelegraph.new()
			hazard.add_child(telegraph)
			telegraph.bind(hazard, sfx.stream(&"fence_warning"), sfx.volume(&"fence_warning"),
				sfx.warning_full_volume_distance, sfx.warning_max_distance)
	_dress(skin.fence.bind(hazard, size, -(bottom + top) * 0.5, gapped))
	_fence_nodes[f["index"]] = hazard
	if f.get("disabled", false):
		hazard.set_enabled(false)


## A wall fence (task B5; GDD §9.1; LevelLayout.wall_fences, WallFencePlan): an electric field across the
## wall-run path on its wall, from the wall face out toward the lanes (WallFencePlan.reach: over a wall
## runner's body, short of a floor runner in the outer lane), over its band's heights, a fence deep. It's
## a hazard like a floor fence (electrical: DamageRules lets armor, the shield and the dash through,
## never claws), never a wall blocker (the wall is open to enter; a live field just hurts), pulsing on
## the level clock with a floor fence's warning (its flicker, and the crackle from HazardTelegraph), and
## switched off for good by an EMP (disable_fences_near). The skin draws its emitters and field
## (ZoneSkin.wall_fence).
func _build_wall_fence(root: Node3D, w: Dictionary) -> void:
	var side: int = int(w["side"])
	var band_name: String = String(w["band"])
	var box: AABB = WallFencePlan.hitbox(w, tuning, geo)
	var center: Vector3 = box.get_center()
	var hazard := _hazard(root, center, box.size, LAYER_HAZARD)
	hazard.hazard_name = "wall fence (%s)" % band_name
	hazard.is_electrical = true
	if float(w["pulse_on"]) > 0.0 and float(w["pulse_off"]) > 0.0:
		hazard.setup_pulsing(float(w["pulse_on"]), float(w["pulse_off"]), tuning.fence_pulse_warning, float(w["phase"]),
			_level_time)
		if sfx != null and sfx.stream(&"fence_warning") != null:
			var telegraph := HazardTelegraph.new()
			hazard.add_child(telegraph)
			telegraph.bind(hazard, sfx.stream(&"fence_warning"), sfx.volume(&"fence_warning"),
				sfx.warning_full_volume_distance, sfx.warning_max_distance)
	_dress(skin.wall_fence.bind(hazard, box.size, side, StringName(band_name), -center.y))
	_wall_fence_nodes[int(w.get("index", _wall_fence_nodes.size()))] = hazard
	if w.get("disabled", false):
		hazard.set_enabled(false)


## A sign (GDD §3: it blocks wall entry, and colliding with one causes damage): a box standing out of its wall
## by sign_depth over the layout entry's heights and stretch, on the hazard layer and the wall blocker layer
## (a wall entry beside it clanks and bumps, Player._try_enter_wall). A wall runner who runs into it takes a
## hit: solid, but one that armor absorbs all the same (Hazard.armor_blocks_solid; task K3, the owner's request:
## a sign no longer kills a runner whose armor is up), then the shield, else it kills ("sign"). Once the armor
## or the shield took its hit, the runner goes on through the rest of it (Hazard.passes_after_block), so a sign
## longer than the invulnerability window never kills them inside it. The skin dresses it (ZoneSkin.wall_sign).
func _build_sign(root: Node3D, s: Dictionary) -> void:
	var side: int = s["side"]
	var size := Vector3(tuning.sign_depth, s["top"] - s["bottom"], s["end"] - s["start"])
	var hazard := _hazard(root,
		Vector3(side * (geo.wall_x() - tuning.sign_depth * 0.5), (s["bottom"] + s["top"]) * 0.5, -(s["start"] + s["end"]) * 0.5),
		size, LAYER_HAZARD | LAYER_WALL_BLOCKER)
	hazard.hazard_name = "sign"
	hazard.is_solid = true
	hazard.armor_blocks_solid = true
	# DESIGN-TBD (docs/questions/k3.md 1): after an absorbed hit the wall runner runs on along the wall through
	# the sign (as the shield always let them), rather than being knocked off the wall or the sign giving way.
	hazard.passes_after_block = true
	_dress(skin.wall_sign.bind(hazard, size))


## A ceiling section: its collision box over the lanes it covers (all of them, or a narrow ceiling's
## range, GDD §3), which the player hangs from and switches lanes within, dressed by the skin.
func _build_hull(root: Node3D, h: Dictionary) -> void:
	var section := CeilingSection.make(geo, tuning.ceiling_height, HULL_THICKNESS, float(h["start"]), float(h["end"]),
		layout.hull_lanes(h))
	_static_box(root, section.center, section.size, LAYER_HULL)
	_dress(skin.ceiling_section.bind(root, section))


func _build_pad(root: Node3D, p: Dictionary) -> void:
	var size := Vector3(geo.lane_width * 0.7, 0.5, tuning.pad_length)
	var area := _trigger(root, &"pad", Vector3(geo.lane_x(p["lane"]), size.y * 0.5, -float(p["at"]) - size.z * 0.5), size)
	_dress(skin.pad.bind(area, size))


func _build_ramp(root: Node3D, r: Dictionary) -> void:
	var side: int = r["side"]
	var size := Vector3(geo.lane_width * 0.8, 1.0, tuning.ramp_length)
	var area := _trigger(root, &"ramp", Vector3(geo.lane_x(layout.outer_lane(side)), size.y * 0.5, -float(r["at"]) - size.z * 0.5), size)
	area.set_meta(&"side", side)
	_dress(skin.ramp.bind(area, size, side))


func _build_speed_pad(root: Node3D, p: Dictionary) -> void:
	var size := Vector3(geo.lane_width * 0.7, 0.5, tuning.speed_pad_length)
	var area := _trigger(root, &"speed_pad", Vector3(geo.lane_x(p["lane"]), size.y * 0.5, -float(p["at"]) - size.z * 0.5), size)
	_dress(skin.speed_pad.bind(area, size))


## A zone doodad (GDD §3, owner's playtest September 30, 2026): a solid scenery piece standing in its
## lane that never hurts. Its box (the size class's width and height, MovementTuning.doodad_size, over
## the layout's start to end) is two things in the physics world: a body on the doodad and
## lane-blocker layers, which the player's push contact meets at its front (Player) and a lane switch
## meets at its sides (blocked, with the bump and the clank); and a top on the floor layer, so a
## player who comes down on it from above (off a wall jump) lands and runs along it, like a hover
## truck's roof (DESIGN-TBD, docs/questions/g5.md 2: a solid top). It's no hazard: nothing hurts
## there, and shots and weapons never see it. The node carries its layout entry (meta "doodad"); the
## skin dresses it (ZoneSkin.doodad) and names the colours its pieces fly off in when the dash smashes it
## (ZoneSkin.doodad_debris_colors, task H5). The node is a DashBreakable (GDD §3, owner, October 8, 2026:
## the dash smashes a doodad): one smashed on this attempt (its entry marked "smashed") is never built
## again. A falling gantryway's pillar (task Q3; LevelLayout.is_gantry_pillar) is built with its gantryway
## (_build_gantryway), not here.
func _build_doodad(root: Node3D, d: Dictionary) -> void:
	if bool(d.get("smashed", false)) or LevelLayout.is_gantry_pillar(d):
		return
	var size_class := StringName(d["size"])
	var area: DashBreakable = _doodad_body(root, d, &"doodad", "Doodad")
	var size: Vector3 = area.size
	var side: int = int(d["side"])
	# A row's doodads share one look (task L3: LevelLayout.doodads `look`, its first one's seed): one kind along it.
	# DESIGN-TBD (item 945 in docs/OPEN_QUESTIONS*.md): whether neighbours of one kind should vary.
	var look_seed: int = int(d.get("look", d.get("seed", 0)))
	_dress(func() -> void:
		skin.doodad(area, size, size_class, side, look_seed)
		area.debris_colors = skin.doodad_debris_colors(area, size_class, side, look_seed))


## A zone doodad's body (_build_doodad) or one that pushes like it (a gantryway's pillar, _build_gantryway): a
## DashBreakable of `kind` named `node_name` over doodad entry `d`'s box, on the doodad and lane-blocker layers, with
## its standable top on the floor layer and its box in the hitbox view, carrying its entry (meta "doodad").
func _doodad_body(root: Node3D, d: Dictionary, kind: StringName, node_name: String) -> DashBreakable:
	var start: float = float(d["start"])
	var end: float = float(d["end"])
	var box: Vector3 = tuning.doodad_size(StringName(d["size"]))
	var size := Vector3(box.x, box.y, end - start)
	var area := DashBreakable.new()
	area.name = node_name
	area.kind = kind
	area.entry = d
	area.size = size
	area.collision_layer = LAYER_DOODAD | LAYER_LANE_BLOCKER
	area.collision_mask = 0
	area.monitoring = false
	area.position = Vector3(geo.lane_x(int(d["lane"])), size.y * 0.5, -(start + end) * 0.5)
	area.set_meta(&"doodad", d)
	root.add_child(area)
	_add_shape(area, size)
	var top := StaticBody3D.new()
	top.collision_layer = LAYER_FLOOR
	top.collision_mask = 0
	area.add_child(top)
	_add_shape(top, size)
	# In the hitbox view a doodad's body shows in a safe blue, never a hazard's red.
	var debug := GreyboxMaterials.add_box(area, Vector3.ZERO, size * 1.01, GreyboxMaterials.overlay(DOODAD_DEBUG, true))
	debug.add_to_group(&"debug_hitbox")
	debug.visible = show_hitboxes
	return area


## A falling gantryway (task Q3; GDD §5, Zone 9, owner, October 21, 2026; LevelLayout.gantryways): a Gantryway over its
## layout entry, its walkway hanging over its lane at the ceilings' height, and its pillar (LevelLayout.pillar_of), a
## DashBreakable of kind &"gantry_pillar" with a zone doodad's body (_doodad_body: it pushes, blocks a lane switch at
## its side and is smashed by the dash exactly as a doodad is, Player._check_doodads; the dash's smash plays
## `gantry_pillar_smash`). Its pillar breaking makes it fall (Gantryway.fall), and its signals are this builder's
## (gantryway_fell, gantryway_swept, gantryway_landed). Its sounds come from the run's library (sfx: the creak, the crash).
## The skin dresses its walkway, its pillar (whose look rises from its doodad box to the walkway's underside: the box
## stays a doodad's, so the chase camera rides over it as over any doodad, RunCamera.doodad_floor) and its wreck
## (ZoneSkin.gantryway, gantry_pillar, gantryway_wreck), and names the colours their pieces fly in. DESIGN-TBD
## (docs/questions/q3.md 3): the pillar, a doodad's body under the walkway's near end, its smash the doodads' crunch.
func _build_gantryway(root: Node3D, g: Dictionary) -> void:
	var node := Gantryway.new()
	node.setup(g, GantrywayTuning.load_default(), geo, tuning, show_hitboxes)
	root.add_child(node)
	_gantryway_nodes.append(node)
	node.fell.connect(func(n: Gantryway) -> void: gantryway_fell.emit(n))
	node.swept.connect(func(n: Gantryway) -> void: gantryway_swept.emit(n))
	node.landed.connect(func(n: Gantryway) -> void: gantryway_landed.emit(n))
	if sfx != null:
		node.set_sounds(sfx.stream(Gantryway.CREAK_SOUND), sfx.volume(Gantryway.CREAK_SOUND), sfx.stream(Gantryway.LAND_SOUND),
			sfx.volume(Gantryway.LAND_SOUND), sfx.warning_full_volume_distance, sfx.warning_max_distance)
	var d: Dictionary = layout.pillar_of(g)
	var pillar: DashBreakable = null
	var side: int = int(g.get("side", 1))
	var look_seed: int = int(g.get("seed", 0))
	if not d.is_empty() and not bool(d.get("smashed", false)):
		pillar = _doodad_body(root, d, &"gantry_pillar", "GantryPillar")
		node.pillar = pillar
		pillar.smashed.connect(node.fall)
	var size: Vector3 = node.size
	var pillar_box: Vector3 = pillar.size if pillar != null else Vector3.ZERO
	var look_size := Vector3(pillar_box.x, tuning.ceiling_height, pillar_box.z)
	_dress(func() -> void:
		skin.gantryway(node.look_node(), size, look_seed)
		skin.gantryway_wreck(node.wreck_node(), node.wreck_size(), look_seed)
		node.debris_colors = skin.gantryway_debris_colors(node.look_node(), look_seed)
		node.snow_colors = skin.gantryway_snow_colors()
		if pillar != null and is_instance_valid(pillar):
			skin.gantry_pillar(pillar, look_size, -pillar_box.y * 0.5, side, look_seed)
			pillar.debris_colors = skin.gantry_pillar_debris_colors(pillar, side, look_seed))


## A teleporter (task Q4; GDD §5, Zone 9, the owner, October 21, 2026: "a square pad with a look all its own, with a
## green, slightly space-age antenna on it. Touching it teleports the runner to an output pad further down the track";
## LevelLayout.teleporters): a Teleporter over its layout entry, its input pad's trigger (LAYER_TRIGGER, kind &"teleporter",
## its entry as Teleporter.META: the Player teleports a runner whose feet touch it, Player._teleport) and its output pads'
## nodes further down the track, all in the chunk where its pad stands (which stays built until its output pads are behind
## the player: _add_pieces). The skin dresses its pad and its antenna on the trigger, and each output pad
## (ZoneSkin.teleporter_pad, teleporter_antenna, teleporter_output: the lamps' lit looks it returns are the teleporter's to
## light, on the level clock, light_teleporters()). No hitbox and no collision but its trigger: nothing about it hurts.
func _build_teleporter(root: Node3D, tp: Dictionary) -> void:
	var node := Teleporter.new()
	node.setup(tp, geo, tuning, TeleporterTuning.load_default())
	root.add_child(node)
	node.tick(_level_time)
	_teleporter_nodes.append(node)
	var size: Vector3 = node.size
	var look_seed: int = int(tp.get("seed", 0))
	_dress(func() -> void:
		skin.teleporter_pad(node.pad, size, look_seed)
		node.set_lamps(skin.teleporter_antenna(node.pad, size, look_seed))
		for out: Node3D in node.outputs:
			skin.teleporter_output(out, size, look_seed))
	teleporter_built.emit(node)


## A dash wall (task H7a; GDD §9.14, owner, October 8, 2026: a building across the street "facing towards the
## player", which the runner dashes through): a DashBreakable of kind &"dash_wall" over its layout entry's
## stretch (start, its face toward the runner, to end), as wide as the floor less the strip beside each side
## wall a wall runner passes it in, and taller than any jump (dash_wall_size). Two things in the physics world:
## the DashBreakable itself on the dash wall layer, the box its look fills, which the Player's approach check
## finds (the dash smashes it a frame before contact; a wall runner passing beside it breaks it as they reach
## its face, so it never stands between the camera and them); and its hitbox, a Hazard child on the hazard
## layer a little smaller than the look (dash_wall_hitbox: forgiving), solid, which armor absorbs all the same
## (Hazard.armor_blocks_solid) and which breaks the wall at any contact (Hazard.breakable): without the dash
## it's one hit (DamageRules), and the runner goes on through it. It's no lane blocker and no wall blocker:
## it stands across every lane, and the side walls stay open. The skin dresses it (ZoneSkin.dash_wall) and
## names the colours its pieces fly off in (ZoneSkin.dash_wall_debris_colors). One broken on this attempt (its
## entry marked "smashed") is never built again.
func _build_dash_wall(root: Node3D, w: Dictionary) -> void:
	if bool(w.get("smashed", false)):
		return
	var start: float = float(w["start"])
	var end: float = float(w["end"])
	var size: Vector3 = dash_wall_size(geo, tuning, end - start)
	var wall := DashBreakable.new()
	wall.name = "DashWall"
	wall.kind = &"dash_wall"
	wall.entry = w
	wall.size = size
	wall.collision_layer = LAYER_DASH_WALL
	wall.collision_mask = 0
	wall.monitoring = false
	wall.position = Vector3(0.0, size.y * 0.5, -(start + end) * 0.5)
	root.add_child(wall)
	_add_shape(wall, size)
	var box: AABB = dash_wall_hitbox(size, tuning)
	var hazard := Hazard.new()
	hazard.name = "Hitbox"
	hazard.hazard_name = "dash wall"
	hazard.is_solid = true
	hazard.armor_blocks_solid = true
	hazard.breakable = wall
	hazard.size = box.size
	hazard.collision_layer = LAYER_HAZARD
	hazard.collision_mask = 0
	hazard.monitoring = false
	hazard.position = box.get_center()
	wall.add_child(hazard)
	_add_shape(hazard, box.size)
	var debug := GreyboxMaterials.add_box(hazard, Vector3.ZERO, box.size * 1.01, GreyboxMaterials.debug_hitbox())
	debug.add_to_group(&"debug_hitbox")
	debug.visible = show_hitboxes
	_dash_wall_nodes.append(wall)
	var look_seed: int = int(w.get("seed", 0))
	_dress(func() -> void:
		skin.dash_wall(wall, size, look_seed)
		wall.debris_colors = skin.dash_wall_debris_colors(wall, look_seed))


## A ceiling fence (task I4; GDD §3, "Ceiling scenarios": a fenced ceiling's rows; LevelLayout.ceiling_fences): an
## electric field hanging from the ceiling's underside across its lane, as wide as a floor fence (a lane less a
## margin), MovementTuning.ceiling_fence_depth below the underside and a fence deep along the track. A hazard like a
## floor fence (electrical: DamageRules lets armor, the shield and the dash through, never claws), always on, switched
## off for good by an EMP (disable_fences_near). It hangs above anything a floor runner reaches (a jump's) and the
## chase camera's highest under a ceiling (RunCamera.ceiling_limit), and short of a wall runner's body (the wall run's
## top). The skin draws it (ZoneSkin.ceiling_fence).
func _build_ceiling_fence(root: Node3D, f: Dictionary) -> void:
	var depth: float = tuning.ceiling_fence_depth
	var size := Vector3(geo.lane_width - 0.2, depth, tuning.fence_depth)
	var hazard := _hazard(root, Vector3(geo.lane_x(int(f["lane"])), tuning.ceiling_height - depth * 0.5, -float(f["at"])),
		size, LAYER_HAZARD)
	hazard.hazard_name = "ceiling fence"
	hazard.is_electrical = true
	_dress(skin.ceiling_fence.bind(hazard, size))
	_ceiling_fence_nodes[int(f.get("index", _ceiling_fence_nodes.size()))] = hazard
	if f.get("disabled", false):
		hazard.set_enabled(false)


## A return pad (task I4; GDD §3, "Ceiling scenarios": the treasure stash's; LevelLayout.return_pads): a trigger on
## the ceiling's underside in its lane, a pad's size, which drops a rider who steps on it back to the floor (Player).
## The node is turned upside down (about the track's axis), so the skin's look for it, by default the anti-grav
## pad's (ZoneSkin.return_pad), points back down at the floor; its trigger box is the same either way up.
func _build_return_pad(root: Node3D, p: Dictionary) -> void:
	var size := Vector3(geo.lane_width * 0.7, 0.5, tuning.pad_length)
	var area := _trigger(root, &"return_pad", Vector3(geo.lane_x(int(p["lane"])), tuning.ceiling_height - size.y * 0.5,
		-float(p["at"]) - size.z * 0.5), size)
	area.rotation.z = PI
	_dress(skin.return_pad.bind(area, size))


func _hazard(root: Node3D, center: Vector3, size: Vector3, layers: int) -> Hazard:
	var hazard := Hazard.new()
	hazard.size = size
	hazard.collision_layer = layers
	hazard.collision_mask = 0
	hazard.monitoring = false
	hazard.position = center
	root.add_child(hazard)
	_add_shape(hazard, size)
	var debug := GreyboxMaterials.add_box(hazard, Vector3.ZERO, size * 1.01, GreyboxMaterials.debug_hitbox())
	debug.add_to_group(&"debug_hitbox")
	debug.visible = show_hitboxes
	return hazard


func _trigger(root: Node3D, kind: StringName, center: Vector3, size: Vector3) -> Area3D:
	var area := Area3D.new()
	area.collision_layer = LAYER_TRIGGER
	area.collision_mask = 0
	area.monitoring = false
	area.position = center
	area.set_meta(&"kind", kind)
	root.add_child(area)
	_add_shape(area, size)
	return area


func _static_box(root: Node3D, center: Vector3, size: Vector3, layer: int) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	body.position = center
	root.add_child(body)
	_add_shape(body, size)


func _add_shape(owner_node: CollisionObject3D, size: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	owner_node.add_child(shape)
