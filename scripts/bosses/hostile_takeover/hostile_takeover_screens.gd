class_name HostileTakeoverScreens
extends BossPart
## Phase 3's screens (GDD §10: "'MERGER COMPLETE' flashes on every screen"; the player gets a glimpse of the
## Chairman "as the face on the 'MERGER COMPLETE' screens"): the locomotive's rear window turned screen,
## and two of the city's ad screens on pylons beyond the sound barriers, pacing the train ahead of the
## runner on either side. Each shows the Chairman's face as a corporate broadcast
## (hostile_takeover_screen.gdshader) over a band carrying HostileTakeoverTuning.merger_text (a TextMesh in
## the UI's display face, translated like the UI's text). They're dark and the pylons down until the
## war engine has docked (set_on): then the words flash for merger_flash_seconds (a steady glow with
## Reduced flashing) and stay; beaten, the screens glitch and go dark (set_glitch, set_on(false)).
## The words run along a screen's top (the barriers hide the ad screens' lower edge from the runner). Built
## once with the fight (one text mesh for all of them, a face material each for its shape), hidden until
## then.
## A part of the boss that's no target, no hazard and no kill.

## The words' font (the UI's display face), its weight, and the size its glyphs are made at.
const FONT_PATH: String = "res://assets/fonts/orbitron/Orbitron[wght].ttf"
const FONT_WEIGHT: int = 800
const FONT_SIZE: int = 64
## The words' glow, over the bloom threshold, and how fast they flash (a steady glow with Reduced flashing).
const TEXT_GLOW: float = 2.4
const FLASH_HZ: float = 2.6
const TEXT_COLOR := Color(0.86, 0.92, 1.0)
## The pylons' screens: their size, how far beyond the barriers they stand, how high their middle is, how far
## ahead of the runner (close enough for the words to read from the run camera), and how long they take to
## rise.
const PYLON_SCREEN := Vector2(12.0, 6.75)
const PYLON_OUT: float = 7.0
const PYLON_Y: float = 11.5
const PYLON_AHEAD: float = 30.0
const RISE_SECONDS: float = 1.0
## The words' band, as the face shader's `band`: a share of a screen's height.
const BAND: float = 0.28

var tuning: HostileTakeoverTuning
## The screens: {root (Node3D), face (MeshInstance3D), text (MeshInstance3D), size (Vector2)}.
var screens: Array[Dictionary] = []
var text_material: StandardMaterial3D
var text_mesh: TextMesh
var on: bool = false
## Seconds since they came on.
var on_time: float = 0.0
var glitch: float = 0.0
var _pylons: Node3D
var _rise: float = 0.0
var _power: float = 0.0


func _build() -> void:
	var params: Dictionary = spawn.get("params", {})
	tuning = params.get("tuning") as HostileTakeoverTuning
	if tuning == null:
		tuning = HostileTakeoverTuning.new()
	display_name = "the merger's screens"
	is_obstacle = true
	immune_to_weapons = true
	text_material = StandardMaterial3D.new()
	text_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	text_material.albedo_color = TEXT_COLOR
	text_material.emission_enabled = true
	text_material.emission = TEXT_COLOR
	text_material.emission_energy_multiplier = TEXT_GLOW
	text_mesh = TextMesh.new()
	var variation := FontVariation.new()
	variation.base_font = load(FONT_PATH) as Font
	variation.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): FONT_WEIGHT}
	variation.spacing_glyph = 2
	text_mesh.font = variation
	text_mesh.font_size = FONT_SIZE
	text_mesh.depth = 0.0
	text_mesh.pixel_size = 0.01
	text_mesh.curve_step = 1.0
	text_mesh.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_mesh.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text_mesh.text = tr(tuning.merger_text)
	# The locomotive's rear window, turned screen (it moves with the locomotive).
	var loco := params.get("locomotive") as Node3D
	var window: Vector2 = HostileTakeoverModel.LOCO_WINDOW
	var wx: float = minf(maxf(world.geo.wall_x() - 0.2, 2.5) * 0.55, 4.2)
	var loco_size := Vector2(wx * 2.0, window.y - window.x)
	var loco_screen: Node3D = _make_screen(loco_size)
	loco_screen.position = Vector3(0.0, (window.x + window.y) * 0.5, 0.3)
	if loco != null:
		loco.add_child(loco_screen)
	else:
		add_child(loco_screen)
	# The pylons beyond the barriers, top level (placed each frame ahead of the runner).
	_pylons = Node3D.new()
	_pylons.name = "Pylons"
	_pylons.top_level = true
	add_child(_pylons)
	for side: float in [-1.0, 1.0]:
		var pylon := Node3D.new()
		pylon.name = "Pylon%s" % ("L" if side < 0.0 else "R")
		pylon.position = Vector3(side * (world.geo.wall_x() + PYLON_OUT), 0.0, 0.0)
		_pylons.add_child(pylon)
		MeshBatch.add_instance(pylon, HostileTakeoverModel.screen_pylon(PYLON_SCREEN, PYLON_Y, world.skin), "Frame")
		var screen: Node3D = _make_screen(PYLON_SCREEN)
		screen.position = Vector3(0.0, PYLON_Y, 0.16)
		# Turned a little toward the track, so it reads from the roofs.
		screen.rotation = Vector3(0.0, -side * 0.35, 0.0)
		pylon.get_node(^"Frame").rotation = screen.rotation
		pylon.add_child(screen)
	set_on(false)


## One screen `size` big (width, height), facing +z: the face quad and the words over its band.
func _make_screen(size: Vector2) -> Node3D:
	var root := Node3D.new()
	root.name = "Screen"
	var face := MeshInstance3D.new()
	face.name = "Face"
	var quad := QuadMesh.new()
	quad.size = size
	face.mesh = quad
	var material := ShaderMaterial.new()
	material.shader = load("res://scripts/bosses/hostile_takeover/hostile_takeover_screen.gdshader") as Shader
	material.set_shader_parameter(&"band", BAND)
	material.set_shader_parameter(&"band_top", 1.0)
	material.set_shader_parameter(&"aspect", size.x / maxf(size.y, 0.01))
	face.material_override = material
	face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(face)
	var text := MeshInstance3D.new()
	text.name = "Words"
	text.mesh = text_mesh
	text.material_override = text_material
	text.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Fitted to the band: the words' mesh scaled so its width is 86% of the screen's, its height at most
	# 60% of the band's.
	var aabb: AABB = text_mesh.get_aabb()
	var k: float = minf(size.x * 0.86 / maxf(aabb.size.x, 0.01), size.y * BAND * 0.6 / maxf(aabb.size.y, 0.01))
	text.scale = Vector3.ONE * k
	text.position = Vector3(0.0, size.y * (0.5 - BAND * 0.5), 0.02)
	root.add_child(text)
	screens.append({"root": root, "face": face, "text": text, "size": size, "material": material})
	return root


## Switches the screens on (the words flashing from now) or off (fading dark, the pylons going down).
func set_on(p_on: bool) -> void:
	on = p_on
	on_time = 0.0
	if on:
		glitch = 0.0
	_apply()


## The defeat's glitch (0-1): the faces torn in bands, still with Reduced flashing (they only dim).
func set_glitch(amount: float) -> void:
	glitch = clampf(amount, 0.0, 1.0)


## Keeps the pylons beside the train `ahead` metres past track distance `d`.
func pace(d: float) -> void:
	_pylons.global_position = Vector3(0.0, -(1.0 - smoothstep(0.0, 1.0, _rise)) * (PYLON_Y + PYLON_SCREEN.y),
		TrackGeometry.world_z(d + PYLON_AHEAD))


## True while the words show now (between flashes, and with Reduced flashing, they stay on).
func words_shown() -> bool:
	return on and _power > 0.5 and _text_on()


func _text_on() -> bool:
	if Settings.flashing_reduced or on_time >= tuning.merger_flash_seconds:
		return true
	return fmod(on_time * FLASH_HZ, 1.0) < 0.55


func _tick(delta: float) -> void:
	step(delta)


## Runs the screens' clock (the words' flashing, the faces powering up or down, the pylons rising or going
## down): every frame from the part's own tick, and through the defeat (when a part no longer ticks) from
## the encounter's.
func step(delta: float) -> void:
	if on:
		on_time += delta
	_rise = move_toward(_rise, 1.0 if on else 0.0, delta / RISE_SECONDS)
	_power = move_toward(_power, 1.0 if on else 0.0, delta / 0.4)
	_apply()


func _apply() -> void:
	for screen: Dictionary in screens:
		var material: ShaderMaterial = screen["material"]
		material.set_shader_parameter(&"power", _power)
		material.set_shader_parameter(&"glitch", glitch)
	var words: bool = on and _text_on() and _power > 0.05
	text_material.emission_energy_multiplier = TEXT_GLOW * _power if words else 0.0
	text_material.albedo_color = TEXT_COLOR * (_power if words else 0.0)
	for screen: Dictionary in screens:
		(screen["root"] as Node3D).visible = on or _power > 0.0
	_pylons.visible = on or _rise > 0.0


## Never a target.
func targetable() -> bool:
	return false


## The fight is won: the encounter plays the defeat (the screens glitch and go dark).
func _on_defeated(_cause: StringName) -> void:
	pass
