class_name TerminalIntroSign
extends Node3D
## The route board by the station's entrance (TerminalIntro; the owner's beats, October 21, 2026): a grimy enamel board of the
## stops of a line, which the runner wipes with their hand, and, cleaned, a list of stops with one clearly in gold, "THE PALACE"
## (the Golden Palace, the game's final destination), the others faded and dull. Built in the station's frame on its front
## (x along it, y up, z out), at human height for a runner 1.28 m tall: a dark enamel panel in a rusted frame, a header, the
## route down it (a line and a dot at each stop) and the stops' names (TerminalIntroText, flat lines), the Palace last and bigger,
## in gold with a glow and a halo. Over it all a film of grime (terminal_intro_grime.gdshader) that the wipe clears along the
## hand's own trail (`set_trail()`), and a few puffs of dust where the hand passes (`update_dust()`).
## Visual only. DESIGN-TBD (docs/questions/f2k.md): the stops' names, the board's design.

const PANEL := Color(0.085, 0.16, 0.17)
const PANEL_LINE := Color(0.36, 0.34, 0.29)
const FADED := Color(0.4, 0.38, 0.33)
const FADED_DARK := Color(0.28, 0.27, 0.24)
const FRAME := Color(0.2, 0.125, 0.085)
const GOLD := Color(1.0, 0.74, 0.2)
const GOLD_DEEP := Color(0.9, 0.58, 0.1)
## The board's size (metres), how far its panel stands out of the front, and its frame's width.
const BOARD := Vector2(1.5, 1.15)
const PANEL_OUT: float = 0.1
## The face the hand wipes: the grime's, in front of the panel (station frame z).
const FACE_OUT: float = 0.16
const FRAME_WIDTH: float = 0.07
## Rows: the first stop's height up from the board's middle, the pitch between stops, and the Palace's height, and the
## route line's and the names' x from the middle.
const FIRST_ROW: float = 0.27
const ROW_PITCH: float = 0.115
const PALACE_ROW: float = -0.33
const LINE_X: float = -0.52
const NAME_X: float = -0.4
const TEXT_CAP: float = 0.058
const PALACE_CAP: float = 0.095
const TRAIL_POINTS: int = 48
const DUST_PUFFS: int = 28

var n: TerminalIntroTuning
var station: TerminalIntroStation
## The board's middle in the station's frame (z the panel's face).
var middle := Vector3.ZERO
var grime_material: ShaderMaterial
var gold_halo: ShaderMaterial
## DESIGN-TBD (docs/questions/f2k.md, 8): the other stops' names are my choice (plausible and neutral); THE PALACE is the owner's.
var stops: PackedStringArray = PackedStringArray(["GRAND TERMINAL", "CANAL STREET", "OLD MARKET", "CINDER ROW", "HARBOUR GATE"])
var palace: String = "THE PALACE"
var dust: MultiMesh
var dust_node: MultiMeshInstance3D
## The hand's path over the board (metres from its middle) and when it passes each point (s): from TerminalIntro.
var path := PackedVector2Array()
var path_times := PackedFloat32Array()


## A point on the panel's face, `u` along it and `v` up from its middle (the station's frame).
func board_point(u: float, v: float, out: float = 0.0) -> Vector3:
	return middle + Vector3(u, v, out)


func setup(p_station: TerminalIntroStation, p_numbers: TerminalIntroTuning, at_x: float, at_y: float) -> void:
	name = "Board"
	station = p_station
	n = p_numbers
	middle = Vector3(at_x, at_y, PANEL_OUT)
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(station.solid)
	_panel(s)
	_route(s)
	var m: MeshInstance3D = batch.commit(station, "RouteBoard")
	if m != null:
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_gold()
	_grime()
	_dust()


func _panel(s: MeshLayer) -> void:
	var w: float = BOARD.x
	var h: float = BOARD.y
	# The frame: four rusted bars standing out of the panel, and bolts in its corners; the post it hangs from.
	s.box(Vector3(middle.x, middle.y + h * 0.5 + FRAME_WIDTH * 0.5, 0.07), Vector3(w + FRAME_WIDTH * 2.0, FRAME_WIDTH, 0.14), FRAME, 0.0,
		MeshKit.PAT_DZ_STEEL)
	s.box(Vector3(middle.x, middle.y - h * 0.5 - FRAME_WIDTH * 0.5, 0.07), Vector3(w + FRAME_WIDTH * 2.0, FRAME_WIDTH, 0.14), FRAME, 0.0,
		MeshKit.PAT_DZ_STEEL)
	for side: float in [-1.0, 1.0]:
		s.box(Vector3(middle.x + side * (w * 0.5 + FRAME_WIDTH * 0.5), middle.y, 0.07), Vector3(FRAME_WIDTH, h, 0.14), FRAME, 0.0,
			MeshKit.PAT_DZ_STEEL)
	# The panel itself, slightly dished: a plain enamel, and its inner border line.
	s.rect(board_point(-w * 0.5, -h * 0.5, 0.0), Vector3(w, 0.0, 0.0), Vector3(0.0, h, 0.0), PANEL, 0.0, MeshKit.PAT_PLAIN)
	var b: float = 0.035
	var line_w: float = 0.012
	for edge: Array in [[-w * 0.5 + b, -h * 0.5 + b, w - 2.0 * b, line_w], [-w * 0.5 + b, h * 0.5 - b - line_w, w - 2.0 * b, line_w]]:
		s.rect(board_point(float(edge[0]), float(edge[1]), 0.004), Vector3(float(edge[2]), 0.0, 0.0), Vector3(0.0, float(edge[3]), 0.0),
			PANEL_LINE, 0.0, MeshKit.PAT_PLAIN)
	for edge_x: float in [-w * 0.5 + b, w * 0.5 - b - line_w]:
		s.rect(board_point(edge_x, -h * 0.5 + b, 0.004), Vector3(line_w, 0.0, 0.0), Vector3(0.0, h - 2.0 * b, 0.0), PANEL_LINE, 0.0,
			MeshKit.PAT_PLAIN)
	for cx: float in [-1.0, 1.0]:
		for cy: float in [-1.0, 1.0]:
			s.box(Vector3(middle.x + cx * (w * 0.5 - 0.075), middle.y + cy * (h * 0.5 - 0.075), 0.115), Vector3(0.03, 0.03, 0.03), FRAME, 0.0,
				MeshKit.PAT_DZ_STEEL)
	# It hangs from two brackets on the front.
	for cx: float in [-0.5, 0.5]:
		s.box(Vector3(middle.x + cx, middle.y + h * 0.5 + 0.12, 0.05), Vector3(0.05, 0.22, 0.08), FRAME, 0.0, MeshKit.PAT_DZ_STEEL)


## The header, the route down the board, the stops' names and the Palace's.
func _route(s: MeshLayer) -> void:
	var z: float = 0.006
	_text(s, "ROUTES", -0.6, 0.43, 0.046, FADED_DARK, 0.0, z)
	# The line and its dots: faded down to the last stop, then the gold to the Palace.
	var last_y: float = FIRST_ROW - ROW_PITCH * float(stops.size() - 1)
	s.rect(board_point(LINE_X - 0.01, last_y, z), Vector3(0.02, 0.0, 0.0), Vector3(0.0, FIRST_ROW - last_y, 0.0), FADED_DARK, 0.0, MeshKit.PAT_PLAIN)
	# The gold stretch: dashes down to the Palace.
	var dash_top: float = last_y - 0.03
	var dashes: int = 5
	for i: int in dashes:
		var y1: float = dash_top - float(i) * ((dash_top - (PALACE_ROW + 0.07)) / float(dashes))
		s.rect(board_point(LINE_X - 0.01, y1 - 0.03, z + 0.002), Vector3(0.02, 0.0, 0.0), Vector3(0.0, 0.03, 0.0), GOLD_DEEP, 0.12, MeshKit.PAT_PLAIN)
	for i: int in stops.size():
		var y: float = FIRST_ROW - ROW_PITCH * float(i)
		s.prism(board_point(LINE_X, y, z), 0.026, 0.01, 8, FADED_DARK, 0.0, MeshKit.PAT_PLAIN, true)
		_text(s, stops[i], NAME_X, y - TEXT_CAP * 0.5, TEXT_CAP, FADED, 0.0, z)
	# The Palace: a gold ring, its name large in gold.
	s.prism(board_point(LINE_X, PALACE_ROW, z), 0.05, 0.012, 12, GOLD, 0.25, MeshKit.PAT_PLAIN, true)
	s.prism(board_point(LINE_X, PALACE_ROW, z + 0.004), 0.03, 0.012, 12, PANEL, 0.0, MeshKit.PAT_PLAIN, true)
	s.prism(board_point(LINE_X, PALACE_ROW, z + 0.006), 0.017, 0.012, 12, GOLD, 0.4, MeshKit.PAT_PLAIN, true)
	_text(s, palace, NAME_X, PALACE_ROW - PALACE_CAP * 0.5, PALACE_CAP, GOLD, 0.32, z)
	# Underlined, in gold.
	var width: float = float(TerminalIntroText.line(palace, PALACE_CAP, GOLD)["width"])
	s.rect(board_point(NAME_X, PALACE_ROW - PALACE_CAP * 0.5 - 0.03, z), Vector3(width, 0.0, 0.0), Vector3(0.0, 0.012, 0.0), GOLD_DEEP, 0.2, MeshKit.PAT_PLAIN)


## A line of text with its left end at `u` and its baseline at `v` on the board.
func _text(s: MeshLayer, text: String, u: float, v: float, cap: float, color: Color, glow_amount: float, z: float) -> void:
	var line: Dictionary = TerminalIntroText.line(text, cap, color, glow_amount)
	s.append(line["layer"], Transform3D(Basis.IDENTITY, board_point(u, v, z + 0.003)))


## A halo behind the Palace's name: a soft gold glow (its own material, so it can breathe).
func _gold() -> void:
	gold_halo = station.glow.duplicate() as ShaderMaterial
	var batch := MeshBatch.new()
	var g: MeshLayer = batch.layer(gold_halo)
	var width: float = float(TerminalIntroText.line(palace, PALACE_CAP, GOLD)["width"])
	g.rect(board_point(NAME_X - 0.14, PALACE_ROW - 0.16, 0.012), Vector3(width + 0.28, 0.0, 0.0), Vector3(0.0, 0.32, 0.0), GOLD, 0.22,
		MeshKit.SHAPE_RADIAL, Vector2.ZERO, Vector2.ONE, -0.25)
	g.rect(board_point(LINE_X - 0.14, PALACE_ROW - 0.14, 0.012), Vector3(0.28, 0.0, 0.0), Vector3(0.0, 0.28, 0.0), GOLD, 0.2, MeshKit.SHAPE_RADIAL, Vector2.ZERO, Vector2.ONE, -0.25)
	var m: MeshInstance3D = batch.commit(station, "PalaceGlow")
	if m != null:
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## The film of grime over the whole board and its frame.
func _grime() -> void:
	grime_material = ShaderMaterial.new()
	grime_material.shader = load("res://scripts/cinematics/terminal_intro/terminal_intro_grime.gdshader") as Shader
	var w: float = BOARD.x + FRAME_WIDTH * 2.0
	var h: float = BOARD.y + FRAME_WIDTH * 2.0
	grime_material.set_shader_parameter(&"board_size", Vector2(w, h))
	set_trail(PackedVector2Array(), 0)
	var q := QuadMesh.new()
	q.size = Vector2(w, h)
	q.material = grime_material
	var mi := MeshInstance3D.new()
	mi.name = "Grime"
	mi.mesh = q
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# A quad faces +z, in front of the panel and the frame.
	mi.position = Vector3(middle.x, middle.y, FACE_OUT)
	station.add_child(mi)


## The wiped trail so far: `points` (metres from the board's middle), the first `count` of them.
func set_trail(points: PackedVector2Array, count: int) -> void:
	var arr := PackedVector2Array()
	arr.resize(TRAIL_POINTS)
	for i: int in mini(points.size(), TRAIL_POINTS):
		arr[i] = points[i]
	grime_material.set_shader_parameter(&"trail", arr)
	grime_material.set_shader_parameter(&"trail_count", mini(count, TRAIL_POINTS))


## The dust the hand raises: soft puffs (the Casino boss intro's dust shader) drifting off the board.
func _dust() -> void:
	dust = MultiMesh.new()
	dust.transform_format = MultiMesh.TRANSFORM_3D
	dust.use_custom_data = true
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/cinematics/casino_boss_intro/casino_dust.gdshader") as Shader
	mat.set_shader_parameter(&"dust", Color(0.5, 0.44, 0.36))
	mat.set_shader_parameter(&"dust_shade", Color(0.3, 0.26, 0.21))
	q.material = mat
	dust.mesh = q
	dust.instance_count = DUST_PUFFS
	dust_node = MultiMeshInstance3D.new()
	dust_node.name = "Dust"
	dust_node.multimesh = dust
	dust_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dust_node.custom_aabb = AABB(middle - Vector3(3.0, 3.0, 1.0), Vector3(6.0, 6.0, 4.0))
	station.add_child(dust_node)
	update_dust(-1.0)


## The wipe at `t` (s on the cinematic's clock): the trail the hand has made by then, and the dust it raised.
func update_wipe(t: float) -> void:
	var count: int = 0
	for i: int in path_times.size():
		if path_times[i] <= t:
			count = i + 1
	set_trail(path, count)
	update_dust(t)


func update_dust(t: float) -> void:
	var used: int = 0
	if t >= 0.0 and not path.is_empty():
		for i: int in path_times.size():
			if i % 2 != 0 or used >= DUST_PUFFS:
				continue
			var age: float = t - path_times[i]
			if age < 0.0 or age > 1.7:
				continue
			var u: float = age / 1.7
			var at: Vector3 = board_point(path[i].x, path[i].y, 0.22 + 0.5 * u) + Vector3(0.1 * sin(float(i)) * u, 0.12 * u, 0.0)
			var size: float = 0.22 + 0.35 * u
			dust.set_instance_transform(used, Transform3D(Basis.from_scale(Vector3.ONE * size), at))
			dust.set_instance_custom_data(used, Color(0.55 * sin(PI * pow(u, 0.6)) * (1.0 - u * 0.5), MeshKit.hash01(i, 3, 61), 0.0, 0.0))
			used += 1
	for i: int in range(used, DUST_PUFFS):
		dust.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))


## The gold's glow breathing slowly: `k` about 1 (steady with Reduced flashing, set by the caller).
func set_gold(k: float) -> void:
	if gold_halo != null:
		gold_halo.set_shader_parameter(&"state_glow", k)
