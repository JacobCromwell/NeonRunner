class_name TrackBuilder
extends Node3D
## Builds a LevelLayout in chunks around the player and frees chunks behind them.
## This creates every gameplay node (floor and hull collision, hazards, triggers) from abstract
## pieces only. How they look is up to the ZoneSkin, which never affects collision.

const CHUNK_LENGTH: float = 40.0
const BUILD_AHEAD: float = 180.0
const KEEP_BEHIND: float = 30.0
## Floor is built this far past the finish line so the level end doesn't drop into the void.
const RUN_OUT: float = 80.0
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
## A doodad's body in the hitbox view (debug_toggle_hitboxes): see-through blue, apart from the
## hazards' red.
const DOODAD_DEBUG := Color(0.2, 0.55, 1.0, 0.3)

var layout: LevelLayout
var tuning: MovementTuning
var geo: TrackGeometry
var skin: ZoneSkin
## Optional: hazard warning sounds. Tests leave it empty.
var sfx: SfxLibrary
var show_hitboxes: bool = false

var _lane_gaps: Array = []
var _buckets: Dictionary = {}
var _chunks: Dictionary = {}
var _next_chunk: int = 0
var _last_chunk: int = 0
var _level_time: float = 0.0
## Built fence hazards by their index in layout.fences, so an EMP can switch them off.
var _fence_nodes: Dictionary = {}


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
	_next_chunk = 0
	_lane_gaps.clear()
	for lane: int in layout.lane_count:
		_lane_gaps.append([])
	_add_pieces(layout, 0)


## Lengthens the track while it runs (a boss arena's next lap, BossArena): appends every list of
## `extra` to the layout and moves its end to extra.length. The pieces must lie past built_until():
## chunks already built don't change. Credits and enemies only join the layout's lists; the credit
## field and the enemy director don't pick them up.
func extend_layout(extra: LevelLayout) -> void:
	var first_fence: int = layout.fences.size()
	var lists: Dictionary = layout.to_dict()
	var more: Dictionary = extra.to_dict()
	for key: String in more:
		if more[key] is Array and lists.get(key) is Array:
			(lists[key] as Array).append_array(more[key])
	# A level without doodads leaves them out of to_dict(): its list joins here.
	if not lists.has("doodads"):
		layout.doodads.append_array(extra.doodads)
	layout.length = maxf(layout.length, extra.length)
	_add_pieces(extra, first_fence)


## Track distance up to which chunks are built.
func built_until() -> float:
	return _next_chunk * CHUNK_LENGTH


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


## Switches off, for the rest of the level, every fence within `radius` of `center` (world space),
## including fences not built yet (GDD §9.1: a destroyed generator's EMP). Returns how many.
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
	return count


## Built fence hazards (for tests and effects).
func fence_hazards() -> Array[Hazard]:
	var out: Array[Hazard] = []
	for h: Variant in _fence_nodes.values():
		if is_instance_valid(h):
			out.append(h)
	return out


func set_hitboxes_visible(on: bool) -> void:
	show_hitboxes = on
	for node: Node in get_tree().get_nodes_in_group(&"debug_hitbox"):
		if is_ancestor_of(node):
			(node as Node3D).visible = on


## Sorts the track pieces of `pieces` (the whole layout, or an extension of it) into the chunks that
## build them. `first_fence` is the layout index of its first fence.
func _add_pieces(pieces: LevelLayout, first_fence: int) -> void:
	_last_chunk = int(ceil((layout.length + RUN_OUT) / CHUNK_LENGTH))
	for g: Dictionary in pieces.gaps:
		_lane_gaps[g["lane"]].append(g)
	for list: Array in _lane_gaps:
		list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["start"] < b["start"])
	for i: int in pieces.fences.size():
		pieces.fences[i]["index"] = first_fence + i
	_bucket("fences", pieces.fences, "at", tuning.fence_depth)
	_bucket("signs", pieces.signs, "start", 0.0, "end")
	_bucket("hulls", pieces.hulls, "start", 0.0, "end")
	_bucket("pads", pieces.pads, "at", tuning.pad_length)
	_bucket("ramps", pieces.ramps, "at", tuning.ramp_length)
	_bucket("speed_pads", pieces.speed_pads, "at", tuning.speed_pad_length)
	_bucket("doodads", pieces.doodads, "start", 0.0, "end")


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
		c0 = -KEEP_BEHIND - 10.0
	var bucket: Dictionary = _buckets.get(index, {})
	_chunks[index] = {"node": root, "max_end": maxf(c1, float(bucket.get("max_end", 0.0)))}

	for lane: int in layout.lane_count:
		for piece: Vector2 in _floor_pieces(lane, c0, c1):
			_build_floor_piece(root, lane, piece, piece.x > c0, piece.y < c1)
	var wall_enemies: Array[Dictionary] = _enemies_between(c0, c1)
	for side: int in [-1, 1]:
		skin.note_wall_enemies(side, c0, c1, wall_enemies)
		skin.wall_section(root, side, side * geo.wall_x(), c0, c1)
	if layout.length >= c0 and layout.length < c1:
		skin.finish_line(root, geo.half_width() * 2.0, layout.length)

	for f: Dictionary in bucket.get("fences", []):
		_build_fence(root, f)
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


## The layout's enemy entries whose track distance falls in [c0, c1) (ZoneSkin.note_wall_enemies()).
func _enemies_between(c0: float, c1: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in layout.enemies:
		var at: float = float(e.get("at", 0.0))
		if at >= c0 and at < c1:
			out.append(e)
	return out


## Returns the [start, end] distance ranges of solid floor for one lane within [c0, c1).
func _floor_pieces(lane: int, c0: float, c1: float) -> Array[Vector2]:
	var pieces: Array[Vector2] = []
	var cursor: float = c0
	for g: Dictionary in _lane_gaps[lane]:
		var gs: float = g["start"]
		var ge: float = g["end"]
		if ge <= cursor:
			continue
		if gs >= c1:
			break
		if gs > cursor:
			pieces.append(Vector2(cursor, gs))
		cursor = maxf(cursor, ge)
	if cursor < c1:
		pieces.append(Vector2(cursor, c1))
	return pieces


func _build_floor_piece(root: Node3D, lane: int, piece: Vector2, edge_start: bool, edge_end: bool) -> void:
	var span: Vector2 = geo.lane_floor_span(lane)
	var center := Vector3((span.x + span.y) * 0.5, -FLOOR_THICKNESS * 0.5, -(piece.x + piece.y) * 0.5)
	var size := Vector3(span.y - span.x, FLOOR_THICKNESS, piece.y - piece.x)
	_static_box(root, center, size, LAYER_FLOOR)
	skin.floor_segment(root, center, size, geo.lane_x(lane), edge_start, edge_end)


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
	skin.fence(hazard, size, -(bottom + top) * 0.5, gapped)
	_fence_nodes[f["index"]] = hazard
	if f.get("disabled", false):
		hazard.set_enabled(false)


func _build_sign(root: Node3D, s: Dictionary) -> void:
	var side: int = s["side"]
	var size := Vector3(tuning.sign_depth, s["top"] - s["bottom"], s["end"] - s["start"])
	var hazard := _hazard(root,
		Vector3(side * (geo.wall_x() - tuning.sign_depth * 0.5), (s["bottom"] + s["top"]) * 0.5, -(s["start"] + s["end"]) * 0.5),
		size, LAYER_HAZARD | LAYER_WALL_BLOCKER)
	hazard.hazard_name = "sign"
	hazard.is_solid = true
	skin.wall_sign(hazard, size)


## A ceiling section: its collision box over the lanes it covers (all of them, or a narrow ceiling's
## range, GDD §3), which the player hangs from and switches lanes within, dressed by the skin.
func _build_hull(root: Node3D, h: Dictionary) -> void:
	var section := CeilingSection.make(geo, tuning.ceiling_height, HULL_THICKNESS, float(h["start"]), float(h["end"]),
		layout.hull_lanes(h))
	_static_box(root, section.center, section.size, LAYER_HULL)
	skin.ceiling_section(root, section)


func _build_pad(root: Node3D, p: Dictionary) -> void:
	var size := Vector3(geo.lane_width * 0.7, 0.5, tuning.pad_length)
	var area := _trigger(root, &"pad", Vector3(geo.lane_x(p["lane"]), size.y * 0.5, -float(p["at"]) - size.z * 0.5), size)
	skin.pad(area, size)


func _build_ramp(root: Node3D, r: Dictionary) -> void:
	var side: int = r["side"]
	var size := Vector3(geo.lane_width * 0.8, 1.0, tuning.ramp_length)
	var area := _trigger(root, &"ramp", Vector3(geo.lane_x(layout.outer_lane(side)), size.y * 0.5, -float(r["at"]) - size.z * 0.5), size)
	area.set_meta(&"side", side)
	skin.ramp(area, size, side)


func _build_speed_pad(root: Node3D, p: Dictionary) -> void:
	var size := Vector3(geo.lane_width * 0.7, 0.5, tuning.speed_pad_length)
	var area := _trigger(root, &"speed_pad", Vector3(geo.lane_x(p["lane"]), size.y * 0.5, -float(p["at"]) - size.z * 0.5), size)
	skin.speed_pad(area, size)


## A zone doodad (GDD §3, owner's playtest September 30, 2026): a solid scenery piece standing in its
## lane that never hurts. Its box (the size class's width and height, MovementTuning.doodad_size, over
## the layout's start to end) is two things in the physics world: a body on the doodad and
## lane-blocker layers, which the player's push contact meets at its front (Player) and a lane switch
## meets at its sides (blocked, with the bump and the clank); and a top on the floor layer, so a
## player who comes down on it from above (off a wall jump) lands and runs along it, like a hover
## truck's roof. It's no hazard: nothing hurts there, and shots and weapons never see it. The node
## carries its layout entry (meta "doodad"); the skin dresses it (ZoneSkin.doodad).
func _build_doodad(root: Node3D, d: Dictionary) -> void:
	var start: float = float(d["start"])
	var end: float = float(d["end"])
	var box: Vector3 = tuning.doodad_size(StringName(d["size"]))
	var size := Vector3(box.x, box.y, end - start)
	var area := Area3D.new()
	area.name = "Doodad"
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
	skin.doodad(area, size, StringName(d["size"]), int(d["side"]), int(d.get("seed", 0)))


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
