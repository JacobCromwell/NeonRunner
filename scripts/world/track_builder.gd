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
	_next_chunk = 0
	_last_chunk = int(ceil((layout.length + RUN_OUT) / CHUNK_LENGTH))

	_lane_gaps.clear()
	for lane: int in layout.lane_count:
		_lane_gaps.append([])
	for g: Dictionary in layout.gaps:
		_lane_gaps[g["lane"]].append(g)
	for list: Array in _lane_gaps:
		list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["start"] < b["start"])

	_bucket("fences", layout.fences, "at", tuning.fence_depth)
	_bucket("signs", layout.signs, "start", 0.0, "end")
	_bucket("hulls", layout.hulls, "start", 0.0, "end")
	_bucket("pads", layout.pads, "at", tuning.pad_length)
	_bucket("ramps", layout.ramps, "at", tuning.ramp_length)


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


func set_hitboxes_visible(on: bool) -> void:
	show_hitboxes = on
	for node: Node in get_tree().get_nodes_in_group(&"debug_hitbox"):
		if is_ancestor_of(node):
			(node as Node3D).visible = on


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
	for side: int in [-1, 1]:
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


func _build_sign(root: Node3D, s: Dictionary) -> void:
	var side: int = s["side"]
	var size := Vector3(tuning.sign_depth, s["top"] - s["bottom"], s["end"] - s["start"])
	var hazard := _hazard(root,
		Vector3(side * (geo.wall_x() - tuning.sign_depth * 0.5), (s["bottom"] + s["top"]) * 0.5, -(s["start"] + s["end"]) * 0.5),
		size, LAYER_HAZARD | LAYER_WALL_BLOCKER)
	hazard.hazard_name = "sign"
	hazard.is_solid = true
	skin.wall_sign(hazard, size)


func _build_hull(root: Node3D, h: Dictionary) -> void:
	var center := Vector3(0.0, tuning.ceiling_height + HULL_THICKNESS * 0.5, -(h["start"] + h["end"]) * 0.5)
	var size := Vector3(geo.half_width() * 2.0, HULL_THICKNESS, h["end"] - h["start"])
	_static_box(root, center, size, LAYER_HULL)
	var seams: Array[float] = []
	for lane: int in range(1, layout.lane_count):
		seams.append(geo.lane_x(lane) - geo.lane_width * 0.5)
	skin.hull(root, center, size, seams)


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


func _hazard(root: Node3D, center: Vector3, size: Vector3, layers: int) -> Hazard:
	var hazard := Hazard.new()
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
