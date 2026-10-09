class_name GoldenConvergenceBlast
extends Node3D
## The Refill Ship's chain reaction's fire and smoke (GDD §10: "the ship goes spinning off to the side and
## explodes, and the missiles it carries all explode"; E5d polish, the review's frames: added light read as a
## washed-out peach against the bright court). A part of the ship (GoldenConvergenceShip), made once with the
## fight: pooled puffs drawn as two MultiMeshes (golden_convergence_blast.gdshader), whatever how many burn at once,
## two draws while any does and none otherwise:
## - fire(at, radius, life, drift): a fireball laid over what's behind it, so it reads on any background on every
##   renderer: it swells fast, a hot yellow heart in a saturated orange (FIRE), reddening (EMBER) and darkening
##   to soot as it fades; dark smoke (SMOKE) rolls up out of it, swelling and rising, and lingers after it;
## - smoke(at, radius, life, drift, delay): a puff of that smoke on its own;
## - Reduced flashing (Settings.flashing_reduced): no flash, the fire comes up over a moment and its heart stays
##   soft; nothing in it flickers either way;
## - pooled: the oldest puff gives way when every one burns; nothing is made after the fight's load, and its state
##   is in packed arrays (no allocation a frame).
## Visual only: it never touches the runner.

## Puffs at once: fireballs, smoke.
const FIRE_MAX: int = 32
const SMOKE_MAX: int = 40
const SHADER: String = "res://scripts/bosses/golden_convergence/golden_convergence_blast.gdshader"
## The fire's colours (sRGB, an explosion's: never on anything that stays, never a hazard's look): its orange, its
## red as it cools, the soot it ends in; the smoke's grey and how dark it is at its thickest.
const FIRE := Color(1.0, 0.36, 0.06)
const EMBER := Color(0.82, 0.12, 0.03)
const SOOT := Color(0.24, 0.07, 0.03)
const SMOKE := Color(0.13, 0.115, 0.11)
const SMOKE_THIN := Color(0.24, 0.22, 0.21)
const FIRE_ALPHA: float = 0.96
const SMOKE_ALPHA: float = 0.82
## A fireball swells to its size in this long; its heart is hot this long; with Reduced flashing it comes up over
## SOFT_IN and its heart is only this hot.
const SWELL: float = 0.14
const HEAT_SECONDS: float = 0.2
const SOFT_IN: float = 0.12
const SOFT_HEAT: float = 0.35
## The fire's lift into the glow where the renderer has it, and how much darker and redder its rim is.
const FIRE_ENERGY: float = 1.35
const FIRE_RIM := Vector3(0.78, 0.36, 0.4)

## Fireballs and smoke puffs shown so far (tests).
var fires_shown: int = 0
var smokes_shown: int = 0

var _fire: MultiMeshInstance3D
var _smoke: MultiMeshInstance3D
## Per fireball: burning, its age and life (seconds), its size (radius at its fullest), where it started and its
## drift (m/s).
var _f_on := PackedByteArray()
var _f_age := PackedFloat32Array()
var _f_life := PackedFloat32Array()
var _f_size := PackedFloat32Array()
var _f_at := PackedVector3Array()
var _f_drift := PackedVector3Array()
## Per smoke puff: the same, and how long before it shows.
var _s_on := PackedByteArray()
var _s_age := PackedFloat32Array()
var _s_life := PackedFloat32Array()
var _s_size := PackedFloat32Array()
var _s_delay := PackedFloat32Array()
var _s_at := PackedVector3Array()
var _s_drift := PackedVector3Array()
## What each MultiMesh shows now, in its instances' order (tests read it: a headless run's renderer keeps none of
## it): how many, where, how big, its colour and its heart's heat.
var _fire_n: int = 0
var _fire_shown_at := PackedVector3Array()
var _fire_shown_radius := PackedFloat32Array()
var _fire_shown_color := PackedColorArray()
var _fire_shown_heat := PackedFloat32Array()
var _smoke_n: int = 0
var _smoke_shown_at := PackedVector3Array()
var _smoke_shown_radius := PackedFloat32Array()
var _smoke_shown_color := PackedColorArray()
## Fireballs and smoke puffs on (shown or still to come): with none on and nothing left shown, tick() has nothing to
## do (the ship ticks it every frame of the fight).
var _live: int = 0


func _init() -> void:
	name = "Blast"
	# Its puffs are placed in world space.
	top_level = true
	var mesh: ArrayMesh = ball()
	_fire = _multimesh("Fire", mesh, FIRE_MAX, _material(FIRE_ENERGY, 0.55, FIRE_RIM))
	_smoke = _multimesh("Smoke", mesh, SMOKE_MAX, _material(1.0, 0.85, Vector3.ONE))
	for i: int in FIRE_MAX:
		_f_on.append(0)
	_f_age.resize(FIRE_MAX)
	_f_life.resize(FIRE_MAX)
	_f_size.resize(FIRE_MAX)
	_f_at.resize(FIRE_MAX)
	_f_drift.resize(FIRE_MAX)
	for i: int in SMOKE_MAX:
		_s_on.append(0)
	_s_age.resize(SMOKE_MAX)
	_s_life.resize(SMOKE_MAX)
	_s_size.resize(SMOKE_MAX)
	_s_delay.resize(SMOKE_MAX)
	_s_at.resize(SMOKE_MAX)
	_s_drift.resize(SMOKE_MAX)
	_fire_shown_at.resize(FIRE_MAX)
	_fire_shown_radius.resize(FIRE_MAX)
	_fire_shown_color.resize(FIRE_MAX)
	_fire_shown_heat.resize(FIRE_MAX)
	_smoke_shown_at.resize(SMOKE_MAX)
	_smoke_shown_radius.resize(SMOKE_MAX)
	_smoke_shown_color.resize(SMOKE_MAX)


func _ready() -> void:
	global_transform = Transform3D.IDENTITY


func _multimesh(node_name: String, mesh: Mesh, count: int, material: Material) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = count
	mm.visible_instance_count = 0
	var inst := MultiMeshInstance3D.new()
	inst.name = node_name
	inst.multimesh = mm
	inst.material_override = material
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Its puffs reach far from its own (empty) box: never culled while one shows.
	inst.extra_cull_margin = 400.0
	inst.visible = false
	add_child(inst)
	return inst


func _material(energy: float, softness: float, rim: Vector3) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(SHADER) as Shader
	m.set_shader_parameter(&"energy", energy)
	m.set_shader_parameter(&"softness", softness)
	m.set_shader_parameter(&"rim_tint", rim)
	return m


## A low-poly ball one metre in radius, white vertex colours (the instances colour it).
static func ball() -> ArrayMesh:
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 14
	sphere.rings = 7
	var arrays: Array = sphere.get_mesh_arrays()
	var colors := PackedColorArray()
	colors.resize((arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())
	colors.fill(Color.WHITE)
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## A fireball at `at` (world space), `radius` across at its fullest, gone after `life` seconds, drifting `drift`
## m/s, with its smoke rolling up out of it.
func fire(at: Vector3, radius: float, life: float, drift: Vector3 = Vector3.ZERO) -> void:
	var i: int = _slot(_f_on, _f_age, _f_life)
	if _f_on[i] == 0:
		_live += 1
	_f_on[i] = 1
	_f_age[i] = 0.0
	_f_life[i] = maxf(life, 0.1)
	_f_size[i] = radius
	_f_at[i] = at
	_f_drift[i] = drift
	fires_shown += 1
	smoke(at + Vector3(0.0, radius * 0.35, 0.0), radius * 1.3, life * 2.0 + 0.7, drift * 0.5 + Vector3(0.0, 1.4, 0.0),
		life * 0.3)


## A puff of dark smoke at `at` (world space), `radius` across at its fullest, showing after `delay` and gone
## `life` seconds later, rising and drifting `drift` m/s.
func smoke(at: Vector3, radius: float, life: float, drift: Vector3 = Vector3(0.0, 1.4, 0.0), delay: float = 0.0) -> void:
	var i: int = _slot(_s_on, _s_age, _s_life)
	if _s_on[i] == 0:
		_live += 1
	_s_on[i] = 1
	_s_age[i] = 0.0
	_s_life[i] = maxf(life, 0.1)
	_s_size[i] = radius
	_s_delay[i] = maxf(delay, 0.0)
	_s_at[i] = at
	_s_drift[i] = drift
	smokes_shown += 1


## A free slot, or the one furthest through its life.
static func _slot(on: PackedByteArray, age: PackedFloat32Array, life: PackedFloat32Array) -> int:
	var best: int = 0
	var best_k: float = -1.0
	for i: int in on.size():
		if on[i] == 0:
			return i
		var k: float = age[i] / maxf(life[i], 0.01)
		if k > best_k:
			best_k = k
			best = i
	return best


## Fireballs burning now (tests).
func fires_on() -> int:
	return _count(_f_on)


## Smoke puffs out now, shown or still to come (tests).
func smokes_on() -> int:
	return _count(_s_on)


static func _count(on: PackedByteArray) -> int:
	var n: int = 0
	for v: int in on:
		n += v
	return n


## The fireballs (`fire`) or the smoke puffs shown now: {at (world), radius, color (sRGB and alpha), heat} (tests).
func shown(fire: bool = true) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if fire:
		for i: int in _fire_n:
			out.append({"at": _fire_shown_at[i], "radius": _fire_shown_radius[i], "color": _fire_shown_color[i],
				"heat": _fire_shown_heat[i]})
	else:
		for i: int in _smoke_n:
			out.append({"at": _smoke_shown_at[i], "radius": _smoke_shown_radius[i], "color": _smoke_shown_color[i],
				"heat": 0.0})
	return out


## Its two MultiMeshes (tests: two draws whatever burns).
func drawers() -> Array[MultiMeshInstance3D]:
	return [_fire, _smoke]


## Everything out at once (a fresh fight, a test).
func clear() -> void:
	_f_on.fill(0)
	_s_on.fill(0)
	_live = 0
	_fire.multimesh.visible_instance_count = 0
	_smoke.multimesh.visible_instance_count = 0
	_fire_n = 0
	_smoke_n = 0
	_fire.visible = false
	_smoke.visible = false


## The puffs on by `delta` seconds: each fireball swells, reddens, darkens and fades; each smoke puff comes up,
## swells, rises and thins out.
func tick(delta: float) -> void:
	if _live == 0 and _fire_n == 0 and _smoke_n == 0:
		return
	var reduced: bool = Settings.flashing_reduced
	var fm: MultiMesh = _fire.multimesh
	var n: int = 0
	for i: int in FIRE_MAX:
		if _f_on[i] == 0:
			continue
		var age: float = _f_age[i] + delta
		_f_age[i] = age
		var life: float = _f_life[i]
		if age >= life:
			_f_on[i] = 0
			_live -= 1
			continue
		var u: float = age / life
		var swell: float = minf(age / SWELL, 1.0)
		var r: float = _f_size[i] * (0.3 + 0.7 * (1.0 - pow(1.0 - swell, 3.0))) * (1.0 + 0.15 * u)
		# Orange, reddening, then dark soot before it thins out (never a see-through red: over the bright court that
		# reads pink).
		var color: Color
		if u < 0.25:
			color = FIRE
		elif u < 0.55:
			color = FIRE.lerp(EMBER, (u - 0.25) / 0.3)
		else:
			color = EMBER.lerp(SOOT, minf((u - 0.55) / 0.3, 1.0))
		var a: float = FIRE_ALPHA * (1.0 - smoothstep(0.75, 1.0, u))
		var heat: float = 1.0 - minf(age / HEAT_SECONDS, 1.0)
		if reduced:
			# No flash: it comes up over a moment, its heart never white-hot.
			a *= minf(age / SOFT_IN, 1.0)
			heat *= SOFT_HEAT
		color.a = a
		var at: Vector3 = _f_at[i] + _f_drift[i] * age
		fm.set_instance_transform(n, Transform3D(Basis.from_scale(Vector3(r, r * 1.08, r)), at))
		fm.set_instance_color(n, color)
		fm.set_instance_custom_data(n, Color(heat, 0.0, 0.0, 0.0))
		_fire_shown_at[n] = at
		_fire_shown_radius[n] = r
		_fire_shown_color[n] = color
		_fire_shown_heat[n] = heat
		n += 1
	fm.visible_instance_count = n
	_fire_n = n
	_fire.visible = n > 0
	var sm: MultiMesh = _smoke.multimesh
	n = 0
	for i: int in SMOKE_MAX:
		if _s_on[i] == 0:
			continue
		if _s_delay[i] > 0.0:
			_s_delay[i] = _s_delay[i] - delta
			continue
		var age: float = _s_age[i] + delta
		_s_age[i] = age
		var life: float = _s_life[i]
		if age >= life:
			_s_on[i] = 0
			_live -= 1
			continue
		var u: float = age / life
		var r: float = _s_size[i] * (0.45 + 0.55 * smoothstep(0.0, 0.6, u))
		var color: Color = SMOKE.lerp(SMOKE_THIN, u)
		color.a = SMOKE_ALPHA * smoothstep(0.0, 0.12, u) * (1.0 - smoothstep(0.45, 1.0, u))
		var at: Vector3 = _s_at[i] + _s_drift[i] * age
		sm.set_instance_transform(n, Transform3D(Basis.from_scale(Vector3(r, r * 0.9, r)), at))
		sm.set_instance_color(n, color)
		sm.set_instance_custom_data(n, Color(0.0, 0.0, 0.0, 0.0))
		_smoke_shown_at[n] = at
		_smoke_shown_radius[n] = r
		_smoke_shown_color[n] = color
		n += 1
	sm.visible_instance_count = n
	_smoke_n = n
	_smoke.visible = n > 0
