class_name HostileTakeoverSkin
extends CorporateSkin
## Hostile Takeover's arena (GDD §10): the Corporate zone's look (CorporateSkin: its sky, fences, signs,
## ceilings, pads and colour rules) on the Chairman's armored maglev train, run from its rear roof toward
## the locomotive. data/bosses/corporate_boss_skin.tres.
## - The floor is one wide train: every lane's floor piece is a stretch of the same carriage roof (the
##   corporate express's pale steel with the brand's pinstripes along its shoulders and a spine down its
##   middle: kit_corporate's PAT_CORP_ROOF laid across the whole train), with faint seams between the
##   lanes. The gaps between carriages are the track's gaps (HostileTakeover._plan_lap): the roof ends in
##   the usual orange edge glow right on the collision edge, over the carriage's end dropping into the
##   dark. The train has its own material (hostile_takeover_train.gdshader), whose breakaway the encounter
##   drives: the carriages behind a stomped coupling tumble away (set_breakaway).
## - The walls are the track's sound barriers: flush gunmetal panels between flush posts, faint marks at
##   the wall-run heights (wall_height_marks), a pale coping on top with lamps above the calm band, and
##   nothing glowing, lit or sticking out below band_top (the wall fences, B5, sit there). DESIGN-TBD
##   (docs/questions/e5b.md): they're the run's walls, so they stay put beside the runner like any level's
##   (they don't rush past with the scenery), plain enough not to show it.
## - The sense of speed (GDD §10: "the scenery streaming past", the City's moving road turned onto the
##   scenery): beyond the barriers the city's towers rush back toward the runner at scenery_speed (the
##   train's speed over the ground; hostile_takeover_towers.gdshader moves them, so nothing is made while
##   the train runs), and far below the gaps the street streams past the same way (the City's road
##   shader, road.gdshader, in the zone's cold colours), with the guideway's beam down the middle.
## - Nothing hangs over the street: the gunship paces the train there (GDD §10).
## Visuals only: TrackBuilder owns every collision shape and gameplay node.

## The roof's orange edge at a gap (CorporateTrains' numbers): a lip on the roof and a strip along the
## top of the carriage's end below it.
const EDGE_LIP: float = 0.18
const LIP_GLOW: float = 0.4
const STRIP_TOP: float = 0.02
const STRIP_HEIGHT: float = 0.1
const STRIP_GLOW: float = 0.6
## How far below the roofs the barriers reach (hiding the guideway's sides).
const BARRIER_FOOT: float = 6.0
## The towers' slices: the chunks' length (TrackBuilder.CHUNK_LENGTH); a longer piece is drawn in slices.
const SLICE: float = 40.0

@export_group("Train arena")
## The Chairman's express (GDD §10: "a long luxury corporate express"): pale steel roofs, the brand's
## livery painted on them (CorporateSkin.livery_color), faint seams between the lanes.
@export var train_roof_color: Color = Color(0.6, 0.62, 0.66)
@export var lane_seam_color: Color = Color(0.4, 0.42, 0.46)
## The sound barriers (the walls): their height over the roofs (above every wall run and wall fence:
## MovementTuning.wall_max_height and the body, wall_fence_top), their steel panels over a concrete
## plinth, flush posts, the coping and the lamps on it (cold white, steady).
@export_range(6.0, 12.0, 0.1, "suffix:m") var barrier_height: float = 6.6
@export var barrier_color: Color = Color(0.27, 0.285, 0.31)
@export var barrier_plinth_color: Color = Color(0.36, 0.36, 0.35)
@export_range(0.0, 2.0, 0.05, "suffix:m") var barrier_plinth_height: float = 0.8
@export var barrier_post_color: Color = Color(0.22, 0.23, 0.25)
@export var barrier_cap_color: Color = Color(0.46, 0.47, 0.48)
@export_range(2.0, 12.0, 0.5, "suffix:m") var barrier_post_spacing: float = 4.0
@export_range(4.0, 40.0, 1.0, "suffix:m") var barrier_lamp_spacing: float = 16.0
## DESIGN-TBD (GDD §10: "the sense of speed comes from the scenery streaming past"): the train's speed
## over the ground, at which the towers and the street below stream back past the runner (on top of the
## runner's own pace along the train).
@export_range(0.0, 120.0, 1.0, "suffix:m/s") var scenery_speed: float = 45.0
## The towers beyond the barriers: their pattern repeats every tower_period metres; near ones stand
## near_towers_from-to beyond the barrier, far ones far_towers_from-to, with these heights.
@export_range(80.0, 480.0, 40.0, "suffix:m") var tower_period: float = 240.0
@export_range(0, 24) var near_towers: int = 8
@export_range(0, 24) var far_towers: int = 9
@export var near_towers_from_to: Vector2 = Vector2(14.0, 30.0)
@export var far_towers_from_to: Vector2 = Vector2(42.0, 95.0)
@export var near_tower_heights: Vector2 = Vector2(24.0, 62.0)
@export var far_tower_heights: Vector2 = Vector2(55.0, 150.0)
@export var tower_colors: PackedColorArray = PackedColorArray([
	Color(0.16, 0.17, 0.2), Color(0.2, 0.21, 0.24), Color(0.13, 0.14, 0.17), Color(0.22, 0.22, 0.21)])
## The towers' windows: how brightly the lit ones glow, the share lit, and of those the share in the
## brand's blue (the rest cold white).
@export_range(0.0, 3.0, 0.05) var tower_window_glow: float = 0.85
@export_range(0.0, 1.0, 0.01) var tower_lit_share: float = 0.3
@export_range(0.0, 1.0, 0.01) var tower_brand_share: float = 0.07
## The street far below the gaps, and the guideway the train rides on.
@export_range(8.0, 40.0, 0.5, "suffix:m") var street_depth: float = 18.0
@export var street_color: Color = Color(0.03, 0.032, 0.04)
@export var street_marking_color: Color = Color(0.3, 0.32, 0.36)
@export var street_head_color: Color = Color(0.82, 0.88, 1.0)
@export var street_tail_color: Color = Color(0.2, 0.3, 0.95)
@export_range(0.0, 4.0, 0.1) var street_streak_glow: float = 1.6
@export_range(1.0, 6.0, 0.1, "suffix:m") var guideway_width: float = 3.2

## The train's half width (wall to wall), from the floor pieces seen (outer lanes reach the walls).
var _train_half: float = 4.0
## Each side's tower pattern (towers_for()).
var _tower_patterns: Dictionary = {}


# --- The train -------------------------------------------------------------------------------------

func floor_segment(parent: Node3D, center: Vector3, size: Vector3, lane_x: float,
		edge_start: bool, edge_end: bool) -> void:
	if size.z < 0.01:
		return
	var x0: float = center.x - size.x * 0.5
	var x1: float = center.x + size.x * 0.5
	var half_lane: float = minf(x1 - lane_x, lane_x - x0)
	var left_outer: bool = x0 < lane_x - half_lane - 0.01
	var right_outer: bool = x1 > lane_x + half_lane + 0.01
	if left_outer or right_outer:
		var half: float = -x0 if left_outer else x1
		if absf(half - _train_half) > 0.001:
			# The lanes are tunable live (F6): the livery is laid out in metres across the train.
			_train_half = half
			train_material().set_shader_parameter(&"corp_roof_half_width", half)
			train_material().set_shader_parameter(&"break_half_width", half)
	var near_d: float = -(center.z + size.z * 0.5)
	var far_d: float = -(center.z - size.z * 0.5)
	var lip_n: float = minf(EDGE_LIP, size.z * 0.4) if edge_start else 0.0
	var lip_f: float = minf(EDGE_LIP, size.z * 0.4) if edge_end else 0.0
	var a: float = near_d + lip_n
	var b: float = far_d - lip_f
	var batch := MeshBatch.new()
	var t: MeshLayer = batch.layer(train_material())
	if b > a:
		# The roof across this lane: UV.x runs -1 to 1 across the whole train, UV.y metres along it.
		var w: float = maxf(_train_half, 0.5)
		t.rect(Vector3(x0, 0.0, -a), Vector3(x1 - x0, 0.0, 0.0), Vector3(0.0, 0.0, -(b - a)), train_roof_color, 0.0,
			MeshKit.PAT_CORP_ROOF, Vector2(x0 / w, a), Vector2(x1 / w, b), roof_param())
		if not left_outer:
			# A faint seam where this lane meets the one on its left.
			t.rect(Vector3(x0, 0.003, -a), Vector3(0.05, 0.0, 0.0), Vector3(0.0, 0.0, -(b - a)), lane_seam_color)
	if edge_start:
		_end(t, x0, x1, near_d, lip_n, 1.0)
	if edge_end:
		_end(t, x0, x1, far_d, lip_f, -1.0)
	batch.commit(parent)


## The roof pattern's parameter (PAT_CORP_ROOF): a corporate express, no painted mark (the carriages are
## laid out by the encounter, not on the skin's grid), a fixed seed.
func roof_param() -> float:
	return float(CorporateTrains.EXPRESS + 8 * 5 + 512 * 500)


## Where a carriage ends at distance d (facing the runner when facing = 1, away when -1): the orange
## lip on the roof right at the collision edge, the strip along the top of the carriage's end below it,
## and the end itself dropping into the dark.
func _end(t: MeshLayer, x0: float, x1: float, d: float, lip: float, facing: float) -> void:
	var z: float = -d
	var depth: float = train_depth
	var strip_y: float = -STRIP_TOP - STRIP_HEIGHT
	var w: float = x1 - x0
	if facing > 0.0:
		t.rect(Vector3(x0, 0.0, z), Vector3(w, 0.0, 0.0), Vector3(0.0, 0.0, -lip), gap_edge_color, LIP_GLOW)
		t.rect(Vector3(x0, -depth, z), Vector3(w, 0.0, 0.0), Vector3(0.0, depth, 0.0), gap_inside_color, 0.0,
			MeshKit.PAT_CORP_UNDER)
		t.rect(Vector3(x0, strip_y, z + 0.004), Vector3(w, 0.0, 0.0), Vector3(0.0, STRIP_HEIGHT, 0.0), gap_edge_color, STRIP_GLOW)
	else:
		t.rect(Vector3(x0, 0.0, z + lip), Vector3(w, 0.0, 0.0), Vector3(0.0, 0.0, -lip), gap_edge_color, LIP_GLOW)
		t.rect(Vector3(x1, -depth, z), Vector3(-w, 0.0, 0.0), Vector3(0.0, depth, 0.0), gap_inside_color, 0.0,
			MeshKit.PAT_CORP_UNDER)
		t.rect(Vector3(x1, strip_y, z - 0.004), Vector3(-w, 0.0, 0.0), Vector3(0.0, STRIP_HEIGHT, 0.0), gap_edge_color, STRIP_GLOW)


## A floor cut through the train (task B4; GDD §10, phase 2: the gunship drops a Buzz Overdrive onto the
## roof ahead, which cuts a carriage lane): the roof sliced open down the lane, the shade inside, the
## orange edges, as the zone's trains cut (CorporateTrains.cut) but across the wide train's lane.
func floor_cut(parent: Node3D, section: FloorCutSection) -> void:
	ZoneSkin.standard_floor_cut(parent, section, solid_material(), glow_material(), {
		"edge": gap_edge_color, "inside": gap_inside_color, "pattern": MeshKit.PAT_CORP_UNDER,
		"params": [0.0, 1.0, 2.0], "depth": train_depth, "bottom": false,
		"lip": EDGE_LIP, "lip_glow": LIP_GLOW, "strip_glow": STRIP_GLOW, "halo": 0.0,
		"wall_x": [section.lane_x - section.lane_width * 0.5 + 0.03, section.lane_x + section.lane_width * 0.5 - 0.03],
		"ribs": 4.0, "rib_param": 3.0,
	})


## One tile of phase 2's runway of anti-grav pads (HostileTakeoverArmored), `size` like a pad's trigger:
## the zone's lift pad, its light rising `beam` high (lower than a lone pad's, so a runway of them leaves
## the armored carriage in plain view).
func pad_tile(size: Vector3, beam: float) -> Mesh:
	return MeshKit.lift_pad(size, pad_color, metal_color, beam, solid_material(), glow_material())


## The train's material (hostile_takeover_train.gdshader): the solid kit's look with the zone's
## patterns, and the breakaway.
func train_material() -> ShaderMaterial:
	if not _materials.has(&"train"):
		var m := ShaderMaterial.new()
		m.shader = load("res://scripts/bosses/hostile_takeover/hostile_takeover_train.gdshader") as Shader
		var params: Dictionary = {"glow_scale": emissive_scale, "sheen_color": sheen_color, "sheen_strength": sheen_strength,
			"corp_brand": livery_color, "corp_brand_glow": brand_color, "corp_marking": marking_color,
			"corp_text": screen_text_color, "corp_roof_half_width": _train_half, "break_half_width": _train_half}
		for p: String in params:
			m.set_shader_parameter(p, params[p])
		_materials[&"train"] = m
	return _materials[&"train"]


## The breakaway (GDD §10: "the carriages behind break away and tumble off the track"): everything of
## the train behind track distance `from` tumbles away, `age` seconds after the break (below 0: none),
## carriage by carriage, each about its own rear end (`ends`: how far behind `from` the carriages behind
## end, the nearest first: HostileTakeoverTrain.ends_behind; the last one stands for any further back),
## as `t` says.
func set_breakaway(from: float, age: float, ends: PackedFloat32Array, t: HostileTakeoverTuning) -> void:
	var m: ShaderMaterial = train_material()
	m.set_shader_parameter(&"break_z", TrackGeometry.world_z(from) if age >= 0.0 else 1.0e9)
	m.set_shader_parameter(&"break_age", age)
	var e: Array[float] = []
	for i: int in 8:
		e.append(ends[mini(i, ends.size() - 1)] if not ends.is_empty() else 50.0 + i * 56.0)
	m.set_shader_parameter(&"break_ends_a", Vector4(e[0], e[1], e[2], e[3]))
	m.set_shader_parameter(&"break_ends_b", Vector4(e[4], e[5], e[6], e[7]))
	if t != null:
		m.set_shader_parameter(&"break_recede", t.break_recede)
		m.set_shader_parameter(&"break_drop", t.break_drop)
		m.set_shader_parameter(&"break_roll", t.break_roll)


## No breakaway (a new fight, or the fight's end).
func clear_breakaway() -> void:
	var m: ShaderMaterial = train_material()
	m.set_shader_parameter(&"break_z", 1.0e9)
	m.set_shader_parameter(&"break_age", -1.0)


# --- The barriers, the street below and the streaming city -----------------------------------------

func wall_section(parent: Node3D, side: int, face_x: float, start: float, end: float) -> void:
	_wall_x = absf(face_x)
	var batch := MeshBatch.new()
	_barrier(batch.layer(solid_material()), batch.layer(glow_material()), side, absf(face_x), start, end)
	if side < 0:
		_below(batch, absf(face_x), start, end)
	batch.commit(parent)
	var s: float = start
	while s < end - 0.01:
		_towers_slice(parent, side, absf(face_x), s)
		s += SLICE


## One sound barrier: its face toward the track from below the roofs to barrier_height (steel panels with
## hairline joints, kit_corporate's plating, over a concrete plinth), flush posts, faint marks at the
## wall-run heights, the coping and its lamps. Nothing on its face glows, lights up or sticks out
## (CorporateSkin's calm band: the wall fences sit there).
func _barrier(s: MeshLayer, g: MeshLayer, side: int, x: float, start: float, end: float) -> void:
	var length: float = end - start
	var h: float = barrier_height
	var fx: float = side * x
	var plinth: float = barrier_plinth_height
	# The face toward the track (+x on the left wall, -x on the right): the panels, and the plinth under them.
	_face(s, side, fx, -BARRIER_FOOT, plinth, start, end, barrier_plinth_color, MeshKit.PAT_CORP_PLATE, 3.0)
	_face(s, side, fx, plinth, h, start, end, barrier_color, MeshKit.PAT_CORP_PLATE, 0.0)
	var inward: float = -side * 0.01
	# Posts, flush (a hair proud so they draw over the face), on a grid along the track.
	var p: float = ceilf(start / barrier_post_spacing) * barrier_post_spacing
	while p < end:
		var z: float = -p
		if side < 0:
			s.rect(Vector3(fx + inward, plinth, z + 0.18), Vector3(0.0, 0.0, -0.36), Vector3(0.0, h - plinth, 0.0), barrier_post_color)
		else:
			s.rect(Vector3(fx + inward, plinth, z - 0.18), Vector3(0.0, 0.0, 0.36), Vector3(0.0, h - plinth, 0.0), barrier_post_color)
		p += barrier_post_spacing
	# The wall-run heights (CorporateSkin.wall_height_marks), as on the zone's facades.
	for mark: float in wall_height_marks:
		if side < 0:
			s.rect(Vector3(fx + inward * 2.0, mark - 0.03, -start), Vector3(0.0, 0.0, -length), Vector3(0.0, 0.06, 0.0), wall_mark_color)
		else:
			s.rect(Vector3(fx + inward * 2.0, mark - 0.03, -end), Vector3(0.0, 0.0, length), Vector3(0.0, 0.06, 0.0), wall_mark_color)
	# The coping, and lamps on it every barrier_lamp_spacing: cold white and steady.
	s.box(Vector3(side * (x + 0.2), h + 0.15, -(start + end) * 0.5), Vector3(0.6, 0.3, length), barrier_cap_color, 0.0,
		MeshKit.PAT_PLAIN, MeshKit.ALL_FACES & ~MeshKit.FACE_NY)
	var l: float = ceilf(start / barrier_lamp_spacing) * barrier_lamp_spacing
	while l < end:
		var lamp := Vector3(side * (x + 0.25), h + 0.4, -l)
		s.box(lamp, Vector3(0.16, 0.24, 0.16), barrier_post_color)
		s.box(lamp + Vector3(0.0, 0.17, 0.0), Vector3(0.2, 0.1, 0.2), flood_color, 0.6)
		g.rect(lamp + Vector3(-0.5, -0.33, 0.0), Vector3(1.0, 0.0, 0.0), Vector3(0.0, 1.0, 0.0), flood_color, 0.16, MeshKit.SHAPE_RADIAL)
		l += barrier_lamp_spacing


## A band of a barrier's face toward the track, from y0 to y1 between two track distances.
func _face(s: MeshLayer, side: int, fx: float, y0: float, y1: float, start: float, end: float, color: Color, pattern: int,
		param: float) -> void:
	var length: float = end - start
	if side < 0:
		s.rect(Vector3(fx, y0, -start), Vector3(0.0, 0.0, -length), Vector3(0.0, y1 - y0, 0.0), color, 0.0, pattern, Vector2.ZERO,
			Vector2.ONE, param)
	else:
		s.rect(Vector3(fx, y0, -end), Vector3(0.0, 0.0, length), Vector3(0.0, y1 - y0, 0.0), color, 0.0, pattern, Vector2.ZERO,
			Vector2.ONE, param)


## Under the train, for one chunk (both walls' worth, built with the left one): the guideway's beam down
## the middle in deep shade, and the street far below streaming past (the City's road shader).
func _below(batch: MeshBatch, half_width: float, start: float, end: float) -> void:
	var s: MeshLayer = batch.layer(solid_material())
	var mid: float = (start + end) * 0.5
	var top: float = -guideway_depth
	s.box(Vector3(0.0, top - 0.8, -mid), Vector3(guideway_width, 1.6, end - start), guideway_color, 0.0,
		MeshKit.PAT_CORP_UNDER, MeshKit.FACE_PY | MeshKit.FACE_PX | MeshKit.FACE_NX, 3.0)
	var r: MeshLayer = batch.layer(street_material())
	r.rect(Vector3(-half_width - 2.0, -street_depth, -start), Vector3(half_width * 2.0 + 4.0, 0.0, 0.0),
		Vector3(0.0, 0.0, -(end - start)), street_color)


## The street below: the City's moving-road shader (road.gdshader) in the zone's cold colours, streaming
## at the train's speed.
func street_material() -> ShaderMaterial:
	if not _materials.has(&"street"):
		_materials[&"street"] = MeshKit.material("road.gdshader", {
			"scroll_speed": scenery_speed, "asphalt": street_color, "marking": street_marking_color,
			"head_color": street_head_color, "tail_color": street_tail_color, "streak_glow": street_streak_glow})
	return _materials[&"street"]


## The towers' material (hostile_takeover_towers.gdshader).
func towers_material() -> ShaderMaterial:
	if not _materials.has(&"towers"):
		var m := ShaderMaterial.new()
		m.shader = load("res://scripts/bosses/hostile_takeover/hostile_takeover_towers.gdshader") as Shader
		var params: Dictionary = {"speed": scenery_speed, "period": tower_period, "slice_length": SLICE,
			"window_cold": window_color, "window_brand": brand_color, "window_glow": tower_window_glow,
			"lit_share": tower_lit_share, "brand_share": tower_brand_share}
		for p: String in params:
			m.set_shader_parameter(p, params[p])
		_materials[&"towers"] = m
	return _materials[&"towers"]


## Keeps the towers on `side` (-1 left, 1 right) clear of the stretch `span` beside the line (track
## distances): the defeat's lobby stands there (HostileTakeoverLobby).
func set_clearing(span: Vector2, side: int) -> void:
	var m: ShaderMaterial = towers_material()
	m.set_shader_parameter(&"clear_span", span)
	m.set_shader_parameter(&"clear_side", float(signi(side)))


## The towers stand everywhere again.
func clear_clearing() -> void:
	towers_material().set_shader_parameter(&"clear_side", 0.0)


## One slice of the streaming city on `side`, from track distance `start` (SLICE long): every tower of the
## side's pattern, which the shader shows in this slice while its near end is in it.
func _towers_slice(parent: Node3D, side: int, face_x: float, start: float) -> void:
	var template: Dictionary = towers_for(side, face_x)
	var verts: PackedVector3Array = template["verts"]
	if verts.is_empty():
		return
	var uv2s: PackedVector2Array = (template["uv2s"] as PackedVector2Array).duplicate()
	for i: int in uv2s.size():
		uv2s[i] = Vector2(uv2s[i].x, start)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = template["colors"]
	arrays[Mesh.ARRAY_TEX_UV] = template["uvs"]
	arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, towers_material())
	var inst: MeshInstance3D = MeshBatch.add_instance(parent, mesh, "Towers")
	# The shader moves the towers along the slice: cull by where they can be.
	var reach: float = float(template["reach"])
	var x0: float = face_x if side > 0 else -face_x - reach
	inst.custom_aabb = AABB(Vector3(x0, -street_depth, -(start + SLICE + float(template["longest"]))),
		Vector3(reach, float(template["tallest"]) + street_depth, SLICE + float(template["longest"])))


## The tower pattern on `side` (seeded, the same in every chunk): each tower a box from the street up
## (its face toward the track, its end toward the runner and its roof), its vertices relative to its
## near end along the track, with its place in the pattern in UV2.x. Built once per side and wall.
func towers_for(side: int, face_x: float) -> Dictionary:
	var key: String = "%d_%.2f" % [side, face_x]
	if _tower_patterns.has(key):
		return _tower_patterns[key]
	var layer := MeshLayer.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["hostile_takeover_towers", side])
	var tallest: float = 0.0
	var longest: float = 0.0
	var reach: float = 0.0
	for group: int in 2:
		var count: int = near_towers if group == 0 else far_towers
		var lateral: Vector2 = near_towers_from_to if group == 0 else far_towers_from_to
		var heights: Vector2 = near_tower_heights if group == 0 else far_tower_heights
		for i: int in count:
			var at: float = (float(i) + rng.randf_range(0.0, 0.6)) * tower_period / maxf(count, 1)
			var off: float = rng.randf_range(lateral.x, lateral.y)
			var depth: float = rng.randf_range(10.0, 24.0)
			var length: float = rng.randf_range(12.0, 28.0)
			var height: float = rng.randf_range(heights.x, heights.y)
			var color: Color = tower_colors[rng.randi() % tower_colors.size()] if not tower_colors.is_empty() else Color(0.2, 0.2, 0.22)
			_tower(layer, side, face_x + off, depth, length, height, at, color, rng.randf())
			tallest = maxf(tallest, height)
			longest = maxf(longest, length)
			reach = maxf(reach, off + depth)
	var out := {"verts": layer.verts, "colors": layer.colors, "uvs": layer.uvs, "uv2s": layer.uv2s,
		"tallest": tallest, "longest": longest, "reach": reach + 1.0}
	_tower_patterns[key] = out
	return out


## One tower (see towers_for): `inner` is its face's distance from the track's middle, `depth` how far
## it reaches away from the track, `length` along it; `at` its near end's place in the pattern. UV is
## metres on each face (the windows' grid); COLOR.a carries its `seed` (0-1).
func _tower(m: MeshLayer, side: int, inner: float, depth: float, length: float, height: float, at: float,
		color: Color, seed: float) -> void:
	var y0: float = -street_depth
	var y1: float = height
	var xi: float = side * inner
	var xo: float = side * (inner + depth)
	var start: int = m.verts.size()
	# The face toward the track.
	if side < 0:
		m.quad_uv(Vector3(xi, y0, 0.0), Vector3(xi, y1, 0.0), Vector3(xi, y1, -length), Vector3(xi, y0, -length),
			Vector2(0.0, y0), Vector2(0.0, y1), Vector2(length, y1), Vector2(length, y0), color, seed)
	else:
		m.quad_uv(Vector3(xi, y0, -length), Vector3(xi, y1, -length), Vector3(xi, y1, 0.0), Vector3(xi, y0, 0.0),
			Vector2(0.0, y0), Vector2(0.0, y1), Vector2(length, y1), Vector2(length, y0), color, seed)
	# The end toward the runner (+z).
	var xa: float = minf(xi, xo)
	var xb: float = maxf(xi, xo)
	m.quad_uv(Vector3(xa, y0, 0.0), Vector3(xa, y1, 0.0), Vector3(xb, y1, 0.0), Vector3(xb, y0, 0.0),
		Vector2(0.0, y0), Vector2(0.0, y1), Vector2(xb - xa, y1), Vector2(xb - xa, y0), color, seed)
	# The roof.
	m.quad_uv(Vector3(xa, y1, 0.0), Vector3(xa, y1, -length), Vector3(xb, y1, -length), Vector3(xb, y1, 0.0),
		Vector2.ZERO, Vector2(0.0, length), Vector2(xb - xa, length), Vector2(xb - xa, 0.0), color, seed)
	for i: int in range(start, m.verts.size()):
		m.uv2s[i] = Vector2(at, 0.0)
