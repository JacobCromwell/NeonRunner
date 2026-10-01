class_name SleepTakerDefeat
extends Node3D
## The Sleep Taker's defeat (GDD §10: "the last EMP bursts it into hundreds of wisps, each a faint face
## or figure that drifts upward and fades as the dreams are released. Then silence, and the first grey
## dawn light breaks over the Dead Zone, setting up the Golden Zone"):
## - the burst: the nightmare dissolves as wisp_count wisps burst out of it, each a faint face or figure
##   (a procedural atlas: faces with open mouths, sleeping faces, figures), pale and drifting upward,
##   fading over wisp_seconds; with the release's sound (sleep_taker_wisps);
## - the silence: the music fades out over silence_fade, and the win plays no riff
##   (SleepTaker.victory_riff);
## - the dawn: dawn_delay after the burst, over dawn_seconds, the smoke-choked night sky turns to a
##   grey dawn (its zenith, horizon and haze colours, the moon fading, the smoke thinning, the fog
##   lighter) and the light rises past the zone's own (dawn_light: the ambient light, the sun, the sky
##   and the scenery's light). The run's environment is its own, made for each run, and the framework
##   puts the lights and the scenery's light back when the fight ends.
## over() is true once the wisps have risen and the dawn has broken: the results follow.

## Wisps live this long, at most (they rise and fade within wisp_seconds; the burst lasts a moment).
const BURST_SECONDS: float = 0.8
## The atlas of faint faces and figures: FRAMES x FRAMES frames of FRAME pixels.
const FRAMES: int = 2
const FRAME: int = 64

static var _atlas: ImageTexture

var boss: SleepTaker
var time: float = -1.0
var wisps: CPUParticles3D

## The environment as it was at the defeat (the light back to the arena's own), and its sky's colours.
var _env: Environment
var _sky: ShaderMaterial
var _from: Dictionary = {}
var _sun: Array = []
var _scenery_from: float = 1.0


func setup(p_boss: SleepTaker) -> void:
	boss = p_boss
	name = "Defeat"
	# It follows the nightmare (which keeps pace with the runner), its wisps rising from it.
	top_level = true
	wisps = CPUParticles3D.new()
	wisps.name = "Wisps"
	wisps.local_coords = true
	wisps.emitting = false
	wisps.one_shot = true
	wisps.explosiveness = 0.55
	wisps.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	wisps.gravity = Vector3(0.0, 1.6, 0.0)
	wisps.direction = Vector3(0.0, 1.0, 0.35)
	wisps.spread = 70.0
	wisps.initial_velocity_min = 0.8
	wisps.initial_velocity_max = 3.2
	wisps.damping_min = 0.3
	wisps.damping_max = 0.8
	wisps.angular_velocity_min = -12.0
	wisps.angular_velocity_max = 12.0
	wisps.scale_amount_min = 0.7
	wisps.scale_amount_max = 1.5
	wisps.anim_offset_min = 0.0
	wisps.anim_offset_max = 1.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 1.0, 1.0, 0.0))
	ramp.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	ramp.add_point(0.12, Color(1.0, 1.0, 1.0, 1.0))
	ramp.add_point(0.6, Color(1.0, 1.0, 1.0, 0.6))
	wisps.color_ramp = ramp
	var quad := QuadMesh.new()
	quad.size = Vector2(0.9, 0.9)
	wisps.mesh = quad
	wisps.material_override = wisp_material()
	wisps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Drawn only once it bursts.
	wisps.visible = false
	add_child(wisps)


## The nightmare bursts: the wisps fly out of it, the music fades to silence, and the dawn is on its way.
func start() -> void:
	var t: SleepTakerTuning = boss.tuning
	time = 0.0
	var body: SleepTakerBody = boss.body
	var size: float = body.size if body != null else 1.0
	wisps.amount = t.wisp_count
	wisps.lifetime = t.wisp_seconds
	wisps.emission_box_extents = Vector3(5.5, 7.0, 2.0) * size
	wisps.position = Vector3(0.0, 11.0, 0.5) * size
	if body != null:
		global_position = body.global_position
	wisps.visible = true
	wisps.restart()
	boss.sound(&"sleep_taker_wisps", body.mouth_world() if body != null else global_position)
	var music: MusicDirector = MusicDirector.instance()
	if music != null:
		music.stop(t.silence_fade)
	boss.log_event(&"silence")


func is_playing() -> bool:
	return time >= 0.0


## Once the wisps have risen and faded and the dawn has broken.
func over() -> bool:
	var t: SleepTakerTuning = boss.tuning
	return time >= maxf(t.wisp_seconds, t.dawn_delay + t.dawn_seconds)


## How far the dawn has broken (0-1).
func dawn() -> float:
	var t: SleepTakerTuning = boss.tuning
	if time < t.dawn_delay:
		return 0.0
	return clampf((time - t.dawn_delay) / maxf(t.dawn_seconds, 0.01), 0.0, 1.0)


func tick(delta: float) -> void:
	if time < 0.0:
		return
	var t: SleepTakerTuning = boss.tuning
	var before: float = dawn()
	time += delta
	var body: SleepTakerBody = boss.body
	if body != null and is_instance_valid(body):
		# It comes apart as the wisps burst out of it; they rise from where it is.
		body.fade = clampf(time / 1.4, 0.0, 1.0)
		global_position = body.global_position
	var k: float = dawn()
	if k <= 0.0:
		return
	if before <= 0.0:
		_capture()
		boss.log_event(&"dawn")
	_apply(smoothstep(0.0, 1.0, k))


## The environment as it is when the dawn begins.
func _capture() -> void:
	_env = get_world_3d().environment if is_inside_tree() else null
	_sky = null
	if _env != null and _env.sky != null:
		_sky = _env.sky.sky_material as ShaderMaterial
	_from = {}
	if _env != null:
		_from = {"ambient": _env.ambient_light_energy, "sky": _env.background_energy_multiplier,
			"fog": _env.fog_light_energy, "fog_color": _env.fog_light_color}
	if _sky != null:
		for key: StringName in [&"zenith_color", &"horizon_color", &"haze_color", &"moon_clarity", &"smoke_amount"]:
			_from[key] = _sky.get_shader_parameter(key)
	_sun.clear()
	var holder: Node = boss.world.get_parent() if boss.world != null and boss.world.get_parent() != null else boss.world
	if holder != null:
		for node: Node in holder.find_children("*", "DirectionalLight3D", true, false):
			_sun.append([node, (node as DirectionalLight3D).light_energy])
	_scenery_from = ZoneSkin.scenery_light_now


## The dawn at `k` (0-1, eased): the sky's colours toward the dawn's, the moon and the smoke fading,
## the fog lighter, and every light up to dawn_light times the zone's own.
func _apply(k: float) -> void:
	var t: SleepTakerTuning = boss.tuning
	var lift: float = lerpf(1.0, t.dawn_light, k)
	if _env != null:
		_env.ambient_light_energy = float(_from["ambient"]) * lift
		_env.background_energy_multiplier = lerpf(float(_from["sky"]), maxf(float(_from["sky"]), 1.0) * t.dawn_light, k)
		_env.fog_light_energy = lerpf(float(_from["fog"]), maxf(float(_from["fog"]), 1.0), k)
		_env.fog_light_color = (_from["fog_color"] as Color).lerp(t.dawn_fog, k)
	if _sky != null:
		_lerp_sky(&"zenith_color", t.dawn_zenith, k)
		_lerp_sky(&"horizon_color", t.dawn_horizon, k)
		_lerp_sky(&"haze_color", t.dawn_haze, k)
		if _from.get(&"moon_clarity") != null:
			_sky.set_shader_parameter(&"moon_clarity", lerpf(float(_from[&"moon_clarity"]), 0.0, k))
		if _from.get(&"smoke_amount") != null:
			_sky.set_shader_parameter(&"smoke_amount", lerpf(float(_from[&"smoke_amount"]), float(_from[&"smoke_amount"]) * 0.5, k))
	for entry: Array in _sun:
		if is_instance_valid(entry[0]):
			(entry[0] as DirectionalLight3D).light_energy = float(entry[1]) * lift
	boss.set_scenery_light(lerpf(_scenery_from, maxf(_scenery_from, 1.0) * t.dawn_light, k))


func _lerp_sky(key: StringName, to: Color, k: float) -> void:
	var from: Variant = _from.get(key)
	if from is Vector3:
		_sky.set_shader_parameter(key, (from as Vector3).lerp(Vector3(to.r, to.g, to.b), k))
	elif from is Color:
		_sky.set_shader_parameter(key, (from as Color).lerp(to, k))


# --- The wisps' look ---------------------------------------------------------------------------------

## A wisp: one of the atlas's faint faces or figures (a random frame each), billboarded, unshaded, pale
## violet-white and faint, fading with the particle's colour.
static func wisp_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.particles_anim_h_frames = FRAMES
	m.particles_anim_v_frames = FRAMES
	m.particles_anim_loop = false
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(0.84, 0.8, 1.0, 0.42)
	m.albedo_texture = atlas()
	return m


## The faint faces and figures, drawn once in code: an open-mouthed face, a sleeping face, a head and
## shoulders, and a whole figure, white on clear with soft edges.
static func atlas() -> ImageTexture:
	if _atlas != null:
		return _atlas
	var size: int = FRAMES * FRAME
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for frame: int in FRAMES * FRAMES:
		var ox: int = (frame % FRAMES) * FRAME
		var oy: int = (frame / FRAMES) * FRAME
		for y: int in FRAME:
			for x: int in FRAME:
				var p := Vector2((x + 0.5) / FRAME * 2.0 - 1.0, (y + 0.5) / FRAME * 2.0 - 1.0)
				var a: float = _wisp_alpha(frame, p)
				img.set_pixel(ox + x, oy + y, Color(1.0, 1.0, 1.0, clampf(a, 0.0, 1.0)))
	_atlas = ImageTexture.create_from_image(img)
	return _atlas


## A frame's opacity at `p` (-1..1 across, y down): soft shapes from distances.
static func _wisp_alpha(frame: int, p: Vector2) -> float:
	match frame:
		0, 1:
			# A face: a soft oval, two eye hollows, a mouth (open, or a sleeping face's closed eyes).
			var head: float = _soft(Vector2(p.x / 0.62, (p.y + 0.02) / 0.8).length(), 1.0, 0.25)
			var eyes: float = 0.0
			var mouth: float = 0.0
			if frame == 0:
				eyes = _soft(Vector2((absf(p.x) - 0.24) / 0.13, (p.y + 0.12) / 0.16).length(), 1.0, 0.5)
				mouth = _soft(Vector2(p.x / 0.14, (p.y - 0.36) / 0.2).length(), 1.0, 0.5)
			else:
				eyes = _soft(Vector2((absf(p.x) - 0.24) / 0.15, (p.y + 0.1) / 0.05).length(), 1.0, 0.6)
				mouth = _soft(Vector2(p.x / 0.16, (p.y - 0.38) / 0.05).length(), 1.0, 0.6)
			return head * (1.0 - 0.85 * eyes) * (1.0 - 0.8 * mouth)
		2:
			# A head and shoulders.
			var head: float = _soft(Vector2(p.x / 0.32, (p.y + 0.38) / 0.38).length(), 1.0, 0.3)
			var body: float = _soft(Vector2(p.x / 0.78, (p.y - 0.62) / 0.5).length(), 1.0, 0.3) * (1.0 if p.y > 0.12 else 0.0)
			return maxf(head, body)
		_:
			# A whole figure rising, arms raised over its head, its body trailing away like vapour.
			var head: float = _soft(Vector2(p.x / 0.17, (p.y + 0.42) / 0.19).length(), 1.0, 0.35)
			var torso: float = _soft(Vector2(p.x / 0.26, (p.y - 0.12) / 0.42).length(), 1.0, 0.35)
			var arm_l: float = _segment(p, Vector2(-0.18, -0.2), Vector2(-0.5, -0.82), 0.08)
			var arm_r: float = _segment(p, Vector2(0.18, -0.2), Vector2(0.5, -0.82), 0.08)
			var trail: float = _soft(Vector2(p.x / (0.2 - 0.12 * clampf(p.y, 0.0, 1.0)), (p.y - 0.62) / 0.36).length(), 1.0, 0.5)
			return maxf(maxf(head, torso), maxf(maxf(arm_l, arm_r) * 0.85, trail * 0.6))


## 1 inside `r`, fading out to 0 over `soft` of it.
static func _soft(d: float, r: float, soft: float) -> float:
	return 1.0 - smoothstep(r * (1.0 - soft), r, d)


## A soft stroke from `a` to `b`, `r` thick.
static func _segment(p: Vector2, a: Vector2, b: Vector2, r: float) -> float:
	var ab: Vector2 = b - a
	var k: float = clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return _soft(p.distance_to(a + ab * k), r, 0.6)
