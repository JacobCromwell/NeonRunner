class_name FireballPool
extends Node3D
## The one explosion every explosion in the game uses (GDD §11, the owner, October 8, 2026: "a yellow and
## red fireball"), owned by RunEffects (`RunEffects.fireball`): a bright yellow core that blooms into
## orange and red, rolling outward and up, with embers thrown out of it and darker smoke after. A call says
## where and how big (`size` is the fireball's radius in metres, from a bomb's 1.5 to a boss's 14), and
## everything scales with it: how far the fire rolls, how big its puffs are, how fast it plays.
##
## Made for the Compatibility renderer and for phones (CLAUDE.md): four CPUParticles3D per slot (a core
## flash, the fire, the smoke, the embers), all billboards of one soft, lumpy blob drawn unshaded, the fire
## and embers additive and the smoke see-through, with no lights, no GPUParticles and no custom shader.
## Everything is pooled and fixed when the level loads: a fixed number of slots (SpeedFxTuning.fireball_pool;
## one more than that cuts the oldest short), fixed particle counts, shared textures, ramps and curves, so
## an explosion allocates nothing, and ShaderWarmup draws the materials during the load (`materials`) so the
## first one never hitches. An explosion is bounded: at most the slot's counts, drawn for about a second
## (a few for a boss).
##
## Fireballs are looks and nothing else: no collision, no damage, no light, and they fade to nothing (the
## smoke is dark, never a glow), so none can read as a lingering hazard. With Reduced flashing (Settings)
## the fireball plays slower, swells from nothing instead of popping, never goes white-hot and draws at a
## share of its usual brightness (SpeedFxTuning.fireball_reduced_*), so nothing in it flashes. Screen shake
## is the caller's own (`RunEffects.shake`), and so is the sound.

## One fireball in the pool: its four particle systems and how long it has left.
class Slot:
	var core: CPUParticles3D
	var fire: CPUParticles3D
	var smoke: CPUParticles3D
	var embers: CPUParticles3D
	## Seconds of the explosion still to play (real time); 0 = free.
	var left: float = 0.0
	## When it was started (the pool's clock), to cut the oldest short.
	var began: float = 0.0

## How long the core flash lasts (a flash, not a body; the fire and the smoke set their own).
const CORE_SECONDS: float = 0.45
## How long the embers burn.
const EMBER_SECONDS: float = 1.1
## Pixels across the blob and ember textures.
const PUFF_PIXELS: int = 64
const EMBER_PIXELS: int = 32
## Within the first of these distances (metres) from the camera a puff is invisible, and from the second it is
## fully drawn: the fire's and the smoke's.
const FADE_FIRE := Vector2(0.6, 3.0)
const FADE_SMOKE := Vector2(1.5, 6.0)
## The smallest and biggest fireball (metres), whatever a caller asks for.
const MIN_SIZE: float = 0.25
const MAX_SIZE: float = 40.0

## Shared by every pool in the process (the textures cost a few milliseconds, once).
static var _quad: QuadMesh
static var _puff_texture: ImageTexture
static var _ember_texture: ImageTexture
static var _ramps: Dictionary = {}
static var _curves: Dictionary = {}

var tuning: SpeedFxTuning
var slots: Array[Slot] = []
## Fireballs started since the level began, and how many of them cut an earlier one short (every slot busy).
var plays: int = 0
var recycled: int = 0
## The latest one's size, whether it played softened (Reduced flashing), and its slot, for tests.
var last_size: float = 0.0
var last_reduced: bool = false
var latest: Slot

var _fire_material: StandardMaterial3D
var _ember_material: StandardMaterial3D
var _smoke_material: StandardMaterial3D
var _clock: float = 0.0
var _next: int = 0


## Builds the slots (once, when the level loads). `p_tuning` is SpeedFxTuning's.
func setup(p_tuning: SpeedFxTuning) -> void:
	tuning = p_tuning
	_make_shared()
	_fire_material = _make_material(_puff_texture, true, tuning.fireball_glow, FADE_FIRE.x, FADE_FIRE.y)
	_ember_material = _make_material(_ember_texture, true, tuning.fireball_glow, FADE_FIRE.x, FADE_FIRE.y)
	_smoke_material = _make_material(_puff_texture, false, 1.0, FADE_SMOKE.x, FADE_SMOKE.y)
	# A low-end phone draws fewer of everything (the counts are fixed here, never changed mid-run).
	var low_end: bool = DeviceProfile.is_low_end()
	var share: float = tuning.fireball_low_end_share if low_end else 1.0
	for i: int in (maxi(tuning.fireball_pool / 2, 2) if low_end else tuning.fireball_pool):
		var slot := Slot.new()
		slot.smoke = _make_emitter(roundi(tuning.fireball_smoke_puffs * share), tuning.fireball_smoke_seconds, _smoke_material, "Smoke")
		slot.fire = _make_emitter(roundi(tuning.fireball_puffs * share), tuning.fireball_seconds, _fire_material, "Fire")
		slot.embers = _make_emitter(roundi(tuning.fireball_embers * share), EMBER_SECONDS, _ember_material, "Embers")
		slot.core = _make_emitter(1, CORE_SECONDS, _fire_material, "Core")
		slot.smoke.draw_order = CPUParticles3D.DRAW_ORDER_VIEW_DEPTH
		slot.fire.scale_amount_curve = _curves["fire"]
		slot.smoke.scale_amount_curve = _curves["smoke"]
		slot.embers.scale_amount_curve = _curves["ember"]
		slot.core.scale_amount_curve = _curves["core"]
		slot.embers.color_ramp = _ramps["ember"]
		slot.smoke.color_ramp = _ramps["smoke"]
		slots.append(slot)


## The materials a fireball draws with, for the shader warm-up (ShaderWarmup draws each once during the load).
func materials() -> Array[Material]:
	return [_fire_material, _ember_material, _smoke_material]


## The mesh every particle is (a unit quad).
static func quad() -> QuadMesh:
	_make_shared()
	return _quad


## A fireball at `pos`, `size` metres in radius. `smoke` leaves dark smoke behind it (off for a quick,
## small one that must clear at once, a bomb's); `pace` plays it faster (above 1) or slower than its size
## and the Reduced flashing setting make it. Takes a free slot, or cuts the oldest short.
func play(pos: Vector3, size: float, smoke: bool = true, pace: float = 1.0) -> void:
	if slots.is_empty():
		return
	plays += 1
	size = clampf(size * tuning.fireball_scale, MIN_SIZE, MAX_SIZE)
	var reduced: bool = Settings.flashing_reduced
	last_size = size
	last_reduced = reduced
	# Never sunk into the floor: a blast on the street still rises out of it.
	pos.y = maxf(pos.y, size * 0.45)
	var slot: Slot = _take()
	var speed: float = clampf(pace, 0.25, 4.0) * _size_pace(size)
	var soft: float = 1.0
	if reduced:
		speed /= tuning.fireball_reduced_slowdown
		soft = tuning.fireball_reduced_brightness
	var tint := Color(1.0, 1.0, 1.0, soft)

	# The fire: puffs thrown out of a small ball, slowed by drag, lifted by the heat.
	var fire: CPUParticles3D = slot.fire
	fire.color_ramp = _ramps["fire_soft"] if reduced else _ramps["fire"]
	fire.color = tint
	fire.emission_sphere_radius = size * 0.3
	fire.initial_velocity_min = 0.0
	fire.initial_velocity_max = size * 2.6
	fire.damping_min = size * 2.2
	fire.damping_max = size * 3.0
	fire.gravity = Vector3(0.0, size * 3.8, 0.0)
	fire.scale_amount_min = size * 1.0
	fire.scale_amount_max = size * 1.8
	_start(fire, pos, speed)

	# The core: one big blob that pops (softly swells with Reduced flashing) and cools.
	var core: CPUParticles3D = slot.core
	core.color_ramp = _ramps["core_soft"] if reduced else _ramps["core"]
	core.color = tint
	core.scale_amount_min = size * 2.0
	core.scale_amount_max = size * 2.0
	_start(core, pos, speed)

	# The embers: small, hot and fast, falling back.
	var embers: CPUParticles3D = slot.embers
	embers.color = tint
	embers.emission_sphere_radius = size * 0.15
	embers.initial_velocity_min = size * 1.0
	embers.initial_velocity_max = size * 3.6
	embers.damping_min = size * 0.5
	embers.damping_max = size * 1.1
	embers.gravity = Vector3(0.0, -maxf(size * 1.8, 5.0), 0.0)
	var ember_size: float = 0.25 + 0.06 * size
	embers.scale_amount_min = ember_size
	embers.scale_amount_max = ember_size * 2.0
	_start(embers, pos, speed)

	# The smoke: dark, slower, rising, a little after the fire.
	var smoke_span: float = 0.0
	if smoke and tuning.fireball_smoke_puffs > 0:
		var puffs: CPUParticles3D = slot.smoke
		puffs.color = Color.WHITE
		puffs.emission_sphere_radius = size * 0.35
		puffs.initial_velocity_min = size * 0.1
		puffs.initial_velocity_max = size * 0.6
		puffs.damping_min = size * 0.4
		puffs.damping_max = size * 0.8
		puffs.gravity = Vector3(0.0, size * 1.6, 0.0)
		puffs.scale_amount_min = size * 1.1
		puffs.scale_amount_max = size * 1.9
		_start(puffs, pos + Vector3(0.0, size * 0.15, 0.0), speed * 0.8)
		smoke_span = tuning.fireball_smoke_seconds / (speed * 0.8)
	else:
		# Clears a smoke still drifting from the explosion this slot played before.
		slot.smoke.restart()
		slot.smoke.emitting = false
	slot.left = maxf(maxf(tuning.fireball_seconds, EMBER_SECONDS) / speed, smoke_span)
	slot.began = _clock
	latest = slot


func _process(delta: float) -> void:
	_clock += delta
	for slot: Slot in slots:
		if slot.left > 0.0:
			slot.left = maxf(slot.left - delta, 0.0)


## Fireballs still playing.
func active() -> int:
	var n: int = 0
	for slot: Slot in slots:
		if slot.left > 0.0:
			n += 1
	return n


## How much slower a fireball of `size` plays than a small one: a bigger blast takes its time.
func _size_pace(size: float) -> float:
	var over: float = clampf((size - tuning.fireball_big_size) / maxf(tuning.fireball_big_size * 2.0, 0.1), 0.0, 1.0)
	return lerpf(1.0, tuning.fireball_big_pace, over)


## A free slot (round-robin), or the one that has played the longest.
func _take() -> Slot:
	for i: int in slots.size():
		var slot: Slot = slots[(_next + i) % slots.size()]
		if slot.left <= 0.0:
			_next = (_next + i + 1) % slots.size()
			return slot
	recycled += 1
	var oldest: Slot = slots[0]
	for slot: Slot in slots:
		if slot.began < oldest.began:
			oldest = slot
	return oldest


## Puts `p` (its numbers set) at `pos`, playing `speed` times as fast, and (re)starts it, clearing what it threw before.
func _start(p: CPUParticles3D, pos: Vector3, speed: float) -> void:
	p.global_position = pos
	p.speed_scale = speed
	p.restart()
	p.emitting = true


func _make_emitter(amount: int, lifetime: float, material: Material, node_name: String) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = node_name
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = maxi(amount, 1)
	p.lifetime = lifetime
	p.lifetime_randomness = 0.25
	p.local_coords = false
	p.mesh = _quad
	p.material_override = material
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.1
	p.direction = Vector3.UP
	p.spread = 180.0
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.angular_velocity_min = -80.0
	p.angular_velocity_max = 80.0
	p.color_ramp = _ramps["fire"]
	add_child(p)
	return p


# --- Shared looks ---------------------------------------------------------------------------------

## Builds the shared mesh, textures, colour ramps and size curves, once a process.
static func _make_shared() -> void:
	if _quad != null:
		return
	_quad = QuadMesh.new()
	_quad.size = Vector2.ONE
	_puff_texture = _blob_texture(PUFF_PIXELS, true)
	_ember_texture = _blob_texture(EMBER_PIXELS, false)
	# The fire, hot to dead: white-yellow, yellow, orange, red, dark red.
	_ramps["fire"] = _ramp([0.0, 0.12, 0.32, 0.55, 0.8, 1.0], [
		Color(1.0, 0.82, 0.25, 0.3), Color(1.0, 0.7, 0.14, 0.55), Color(1.0, 0.46, 0.06, 0.7),
		Color(0.9, 0.2, 0.04, 0.65), Color(0.45, 0.07, 0.03, 0.3), Color(0.15, 0.02, 0.02, 0.0)])
	# With Reduced flashing: from nothing, up over almost half of its (stretched) life, never white.
	_ramps["fire_soft"] = _ramp([0.0, 0.45, 0.65, 0.82, 0.93, 1.0], [
		Color(1.0, 0.68, 0.18, 0.0), Color(1.0, 0.62, 0.14, 0.8), Color(0.98, 0.42, 0.07, 1.0),
		Color(0.8, 0.2, 0.04, 0.65), Color(0.4, 0.07, 0.03, 0.25), Color(0.15, 0.02, 0.02, 0.0)])
	_ramps["core"] = _ramp([0.0, 0.06, 0.3, 1.0], [
		Color(1.0, 0.8, 0.3, 0.0), Color(1.0, 0.8, 0.3, 0.3), Color(1.0, 0.62, 0.2, 0.2), Color(1.0, 0.45, 0.1, 0.0)])
	_ramps["core_soft"] = _ramp([0.0, 0.5, 1.0], [
		Color(1.0, 0.66, 0.2, 0.0), Color(1.0, 0.6, 0.15, 0.5), Color(0.9, 0.3, 0.06, 0.0)])
	_ramps["ember"] = _ramp([0.0, 0.35, 0.7, 1.0], [
		Color(1.0, 0.95, 0.6, 1.0), Color(1.0, 0.62, 0.16, 1.0), Color(0.95, 0.25, 0.05, 0.8), Color(0.4, 0.06, 0.02, 0.0)])
	# The smoke is lit red-brown by the fire at first, then a dull dark grey, and thins out.
	_ramps["smoke"] = _ramp([0.0, 0.25, 0.5, 0.8, 1.0], [
		Color(0.5, 0.16, 0.05, 0.0), Color(0.4, 0.14, 0.06, 0.2), Color(0.2, 0.15, 0.13, 0.32),
		Color(0.13, 0.12, 0.12, 0.2), Color(0.1, 0.1, 0.1, 0.0)])
	_curves["fire"] = _curve([Vector2(0.0, 0.45), Vector2(0.25, 0.95), Vector2(0.6, 1.15), Vector2(1.0, 1.0)])
	_curves["core"] = _curve([Vector2(0.0, 0.5), Vector2(0.2, 1.0), Vector2(1.0, 1.25)])
	_curves["smoke"] = _curve([Vector2(0.0, 0.5), Vector2(0.5, 1.0), Vector2(1.0, 1.3)])
	_curves["ember"] = _curve([Vector2(0.0, 1.0), Vector2(1.0, 0.4)])


static func _ramp(offsets: Array, colors: Array) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offsets)
	g.colors = PackedColorArray(colors)
	return g


static func _curve(points: Array) -> Curve:
	var c := Curve.new()
	for point: Vector2 in points:
		c.add_point(point)
	c.bake()
	return c


## A soft white blob whose alpha is the shape: `lumpy` breaks its edge up with noise into a billowing puff,
## otherwise it's a smooth hot dot. Drawn once, by the CPU, when the first level loads.
static func _blob_texture(pixels: int, lumpy: bool) -> ImageTexture:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 3
	noise.frequency = 0.055 * 64.0 / float(pixels)
	noise.seed = 7
	var detail := FastNoiseLite.new()
	detail.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	detail.fractal_octaves = 2
	detail.frequency = 0.12 * 64.0 / float(pixels)
	detail.seed = 21
	var image := Image.create(pixels, pixels, false, Image.FORMAT_RGBA8)
	var half: float = float(pixels) * 0.5
	for y: int in pixels:
		for x: int in pixels:
			var u: float = (float(x) + 0.5 - half) / half
			var v: float = (float(y) + 0.5 - half) / half
			var r: float = sqrt(u * u + v * v)
			var d: float = r
			if lumpy:
				d += noise.get_noise_2d(float(x), float(y)) * 0.55
			var a: float = clampf(1.0 - d, 0.0, 1.0)
			a = a * a * (3.0 - 2.0 * a)
			if lumpy:
				a *= clampf(0.8 + detail.get_noise_2d(float(x), float(y)) * 0.9, 0.25, 1.0)
			a *= 1.0 - smoothstep(0.78, 1.0, r)
			if not lumpy:
				a = pow(a, 1.6)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	return ImageTexture.create_from_image(image)


## A billboard particle material: unshaded, lit by nothing, coloured by each particle, additive for fire
## and embers and see-through for smoke, behind nothing's depth (it never hides what is behind it), and
## unfogged (a fire far away still glows). `glow` multiplies the colour (above 1 it blooms on Forward+).
static func _make_material(texture: Texture2D, additive: bool, glow: float, near_min: float, near_max: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.vertex_color_use_as_albedo = true
	# The ramps' colours are authored as inspector colours (sRGB), as the Compatibility renderer shows them.
	m.vertex_color_is_srgb = true
	m.albedo_texture = texture
	m.albedo_color = Color(glow, glow, glow, 1.0)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.disable_fog = true
	m.disable_receive_shadows = true
	# Puffs close to the camera fade out (the runner running through a fireball, or past its smoke, never
	# gets a screen full of glare or a brown haze).
	m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	m.distance_fade_min_distance = near_min
	m.distance_fade_max_distance = near_max
	return m
