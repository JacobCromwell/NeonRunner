extends Node3D
## D7: comparison sheet for the cult emblem options (CultEmblem, docs/questions/d7.md), for visual
## review only (not part of the game). One row per option (A-D), one column per context: the
## emblem large, small-size silhouettes, inside a neon city ad, worked into a corporate logo, and as
## a gold relief on the Golden Zone's white and cream. A static orthogonal camera frames the whole
## sheet in one shot, so a single rendered frame is the comparison sheet.
##
##   Render:  SCENE=res://tools/showcase/cult_emblem_sheet.tscn render.sh . build/cult_emblem_sheet 4
##   Options (after --): --shot=N holds one shot (0 the whole sheet, 1-4 a close-up of option A-D).

const COLUMN_TITLES: PackedStringArray = ["The emblem", "At small sizes", "In a neon city ad",
	"In a corporate logo", "Gold relief, Golden Zone"]
const CELL_W: float = 4.4
const CELL_H: float = 4.0
const SILHOUETTE_BG := Color(0.85, 0.86, 0.88)
const AD_BG := Color(0.02, 0.02, 0.035)
const LOGO_BG := Color(0.12, 0.13, 0.15)
const GOLD_BG := Color(0.90, 0.87, 0.80)

var _camera: Camera3D
var _row_y: PackedFloat32Array = PackedFloat32Array()
var _col_x: PackedFloat32Array = PackedFloat32Array()


func _ready() -> void:
	var skin := GreyboxSkin.new()
	var env := WorldEnvironment.new()
	env.environment = skin.make_environment()
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60.0, 20.0, 0.0)
	sun.light_energy = 0.8
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(sun)

	for c: int in COLUMN_TITLES.size():
		_col_x.append(-((COLUMN_TITLES.size() - 1) * 0.5) * CELL_W + c * CELL_W)
	for r: int in CultEmblem.OPTION_COUNT:
		_row_y.append(((CultEmblem.OPTION_COUNT - 1) * 0.5) * CELL_H - r * CELL_H)

	_label(Vector3(0.0, _row_y[0] + CELL_H * 0.5 + 1.7, 0.05), "D7 -- CULT EMBLEM OPTIONS", 64, Color(0.9, 0.93, 1.0))
	for c: int in COLUMN_TITLES.size():
		_label(Vector3(_col_x[c], _row_y[0] + CELL_H * 0.5 + 0.65, 0.05), COLUMN_TITLES[c].to_upper(), 30, Color(0.75, 0.8, 0.9))
	for r: int in CultEmblem.OPTION_COUNT:
		_label(Vector3(_col_x[0] - CELL_W * 0.5 - 1.55, _row_y[r], 0.05),
			"%s\n%s" % [CultEmblem.option_letter(r), CultEmblem.option_title(r)], 40, Color(0.9, 0.93, 1.0))
		_build_row(r)

	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	add_child(_camera)
	_camera.make_current()
	var hold_shot: int = 0
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			hold_shot = int(arg.get_slice("=", 1))
	_apply_shot(hold_shot)


func _apply_shot(shot: int) -> void:
	if shot <= 0:
		var top: float = _row_y[0] + CELL_H * 0.5 + 2.2
		var bottom: float = _row_y[CultEmblem.OPTION_COUNT - 1] - CELL_H * 0.5 - 0.4
		var left: float = _col_x[0] - CELL_W * 0.5 - 3.1
		var right: float = _col_x[_col_x.size() - 1] + CELL_W * 0.5 + 0.4
		_frame(Vector2((left + right) * 0.5, (top + bottom) * 0.5), maxf(top - bottom, (right - left) / _aspect()))
	else:
		var r: int = clampi(shot - 1, 0, CultEmblem.OPTION_COUNT - 1)
		var left: float = _col_x[0] - CELL_W * 0.5 - 3.1
		var right: float = _col_x[_col_x.size() - 1] + CELL_W * 0.5 + 0.4
		_frame(Vector2((left + right) * 0.5, _row_y[r]), maxf(CELL_H + 0.6, (right - left) / _aspect()))


func _aspect() -> float:
	var vp: Vector2 = get_viewport().size
	return (vp.x / vp.y) if vp.y > 0.0 else 16.0 / 9.0


func _frame(center: Vector2, height: float) -> void:
	_camera.size = height
	_camera.position = Vector3(center.x, center.y, 20.0)
	_camera.look_at(Vector3(center.x, center.y, 0.0), Vector3.UP)


func _build_row(option: int) -> void:
	var scheme: Dictionary = CultEmblem.default_scheme(option)
	var y: float = _row_y[option]
	_panel_large(Vector2(_col_x[0], y), option, scheme)
	_panel_small(Vector2(_col_x[1], y), option)
	_panel_ad(Vector2(_col_x[2], y), option, scheme)
	_panel_logo(Vector2(_col_x[3], y), option, scheme)
	_panel_gold(Vector2(_col_x[4], y), option)


func _panel_large(at: Vector2, option: int, scheme: Dictionary) -> void:
	_backdrop(at, Color(0.03, 0.03, 0.045))
	_emblem(at, 0.4, option, 2.6, Color(0.95, 0.96, 0.98), Color(1.0, 0.55, 0.42), 1.0)


func _panel_small(at: Vector2, option: int) -> void:
	_backdrop(at, SILHOUETTE_BG)
	var dark := Color(0.06, 0.06, 0.08)
	var offsets: Array[float] = [-1.35, 0.15, 1.35]
	var sizes: Array[float] = [1.05, 0.55, 0.26]
	for i: int in sizes.size():
		_emblem(at + Vector2(offsets[i], -0.1), 0.4, option, sizes[i], dark, dark, 0.0)


func _panel_ad(at: Vector2, option: int, scheme: Dictionary) -> void:
	_backdrop(at, AD_BG)
	var glow_mat: ShaderMaterial = MeshKit.glow()
	var g: MeshInstance3D = MeshBatch.add_instance(self, _halo_mesh(1.9, scheme["neon"], glow_mat), "", Vector3(at.x, at.y, 0.35))
	var strip_mat: ShaderMaterial = MeshKit.solid({"glow_scale": 3.0})
	for dy: float in [1.35, -1.35]:
		var batch := MeshBatch.new()
		batch.layer(strip_mat).rect(Vector3(-1.55, dy - 0.16, 0.15), Vector3(3.1, 0.0, 0.0), Vector3(0.0, 0.32, 0.0),
			Color(0.55, 0.6, 0.68), 0.6, MeshKit.PAT_GLYPHS, Vector2.ZERO, Vector2.ONE, 0.0)
		MeshBatch.add_instance(self, batch.to_mesh(), "", Vector3(at.x, at.y, 0.0))
	_emblem(at, 0.42, option, 1.55, scheme["neon"], scheme["neon_accent"], 1.0)


func _panel_logo(at: Vector2, option: int, scheme: Dictionary) -> void:
	_backdrop(at, LOGO_BG)
	var bar: MeshInstance3D = MeshBatch.add_instance(self, _plate_mesh(2.6, 0.4, scheme["metal"], MeshKit.solid()), "",
		Vector3(at.x, at.y - 1.55, 0.05))
	bar.name = "wordmark_bar"
	_emblem(at, 0.44, option, 1.35, scheme["metal"], scheme["metal_accent"], 0.0)


func _panel_gold(at: Vector2, option: int) -> void:
	_backdrop(at, GOLD_BG)
	_emblem(at, 0.4, option, 2.75, CultEmblem.GOLD_COLOR, CultEmblem.GOLD_ACCENT_COLOR, 0.0)


func _backdrop(at: Vector2, color: Color) -> void:
	GreyboxMaterials.add_box(self, Vector3(at.x, at.y, -0.15), Vector3(CELL_W - 0.24, CELL_H - 0.24, 0.1),
		GreyboxMaterials.flat(color))


func _emblem(at: Vector2, z: float, option: int, size: float, color: Color, accent: Color, glow_amount: float) -> void:
	var mesh: ArrayMesh = CultEmblem.build_mesh(option, size, color, accent, glow_amount, MeshKit.solid())
	MeshBatch.add_instance(self, mesh, "", Vector3(at.x, at.y, z))


func _halo_mesh(size: float, color: Color, material: ShaderMaterial) -> ArrayMesh:
	var batch := MeshBatch.new()
	var h: float = size * 0.5
	batch.layer(material).rect(Vector3(-h, -h, 0.0), Vector3(size, 0.0, 0.0), Vector3(0.0, size, 0.0), color, 0.55, MeshKit.SHAPE_RADIAL)
	return batch.to_mesh()


func _plate_mesh(w: float, h: float, color: Color, material: ShaderMaterial) -> ArrayMesh:
	var batch := MeshBatch.new()
	batch.layer(material).rect(Vector3(-w * 0.5, -h * 0.5, 0.0), Vector3(w, 0.0, 0.0), Vector3(0.0, h, 0.0), color, 0.0)
	return batch.to_mesh()


func _label(at: Vector3, text: String, size: int, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = size
	label.pixel_size = 0.0075
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = color
	label.outline_size = 10
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = at
	add_child(label)
