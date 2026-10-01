class_name BarnacleTurretModel
extends GunModel
## The Barnacle Turret's model (GDD §9.8): a round dome that hangs from a ceiling's underside with a
## cannon in its chest, built in code from low-poly parts (CLAUDE.md Assets). Two looks share the dome,
## the cannon and the size, so it reads as the same enemy in every zone:
## - mechanical (most zones): armour plates, a band with rivets, vents and a small cold-white sensor;
## - a creature (Gangland and the Marketplace, is_creature()): the same dome covered in low-poly fur
##   tufts (not a fur shader: phones and the web), big googly eyes and floppy ears, cute and a bit silly.
## Local space: y = 0 is the ceiling's underside and the dome hangs toward -y; its front, the cannon's
## side, is +z (toward the player). A hatch ring (the collar) stays on the underside; the dome pops out
## of it (set_emerged) and turns to watch the player (watch, aim_at).
## Colours: the only hazard colour it ever shows is enemy-fire red at its muzzle during a burst's
## charge-up and the burst (set_charge, like the cyborgs' arm cannon): a steady swell, no strobe. The
## mechanical sensor is the cyborgs' cold white; nothing else glows. A hit's white flash is softer and
## held longer with Settings > Reduced flashing (flash()); a blink is a slow squint, not a flash.
## Visual only: it never touches collision or gameplay, and its randomness never uses the enemy's
## gameplay stream. 6–8 draw calls; the meshes are shared by every turret of the same look.

signal death_finished

const Kit = preload("res://scripts/enemies/cyborg_kit.gd")

## The looks: `creature` in Gangland and the Marketplace (their skins' enemy_variant), `mechanical`
## everywhere else. The showcase also takes the looks' own names.
const CREATURE_VARIANTS: Array[StringName] = [&"scavenger", &"casino", &"creature", &"creature_scavenger"]
## The hatch ring on the underside.
const COLLAR_RADIUS: float = 0.66
const COLLAR_DEPTH: float = 0.07
## The dome: a half-ellipsoid hanging from DOME_TOP, DOME_RADIUS wide and DOME_DEPTH deep, so its crown
## is at DOME_TOP - DOME_DEPTH.
const DOME_TOP: float = -0.03
const DOME_RADIUS: float = 0.6
const DOME_DEPTH: float = 0.8
## The chest cannon: its axis height, and the barrel's tip (the muzzle) along +z.
const CANNON_Y: float = -0.4
const MUZZLE := Vector3(0.0, CANNON_Y, 0.88)
## Enemy fire's red (ProjectilePool's enemy looks, the cyborgs' charge-up).
const CHARGE_COLOR: Color = Kit.CHARGE_COLOR
## A hit's white flash (the cyborgs' timings).
const FLASH_TIME: float = 0.08
const SOFT_FLASH_TIME: float = 0.3
## How far it turns toward what it watches (radians) and how fast.
const MAX_YAW: float = 0.75
const MAX_PITCH: float = 0.45
const TURN_RATE: float = 7.0
const LAZY_TURN_RATE: float = 2.2

const CHARGE_SHADER: String = """
shader_type spatial;
render_mode cull_back;
#include "res://scripts/characters/humanoid_color.gdshaderinc"
// The muzzle ring and the charge orb: dark steel at rest, swelling to enemy-fire red as `charge`
// rises (the attack's telegraph). A steady swell: nothing strobes, with or without Reduced flashing.
uniform vec4 charge_color : source_color = vec4(1.0, 0.15, 0.1, 1.0);
uniform vec4 rest_color : source_color = vec4(0.1, 0.1, 0.11, 1.0);
uniform float charge = 0.0;
uniform float energy = 2.6;
uniform float orb = 0.0;
void fragment() {
	float c = clamp(charge, 0.0, 1.0);
	ALBEDO = mix(rest_color.rgb, charge_color.rgb, max(c, orb));
	ROUGHNESS = 0.35;
	METALLIC = mix(0.5, 0.0, max(c, orb));
	EMISSION = humanoid_glow(charge_color.rgb, energy * max(c * c, orb));
}
"""

## The look's palette: {base, tip, belly, dark, trim, accent}. Colours are sRGB like any material colour.
const PALETTES: Dictionary = {
	# The Marketplace's creature: warm sand fur with cream tips and a pale belly.
	&"creature": {"base": Color(0.78, 0.63, 0.42), "tip": Color(0.95, 0.86, 0.66), "belly": Color(0.97, 0.93, 0.84),
		"dark": Color(0.1, 0.07, 0.05), "trim": Color(0.3, 0.31, 0.34), "accent": Color(0.55, 0.4, 0.28)},
	# Gangland's: scruffier, dusty brown fur with grey tips.
	&"creature_scavenger": {"base": Color(0.42, 0.33, 0.24), "tip": Color(0.62, 0.56, 0.47), "belly": Color(0.7, 0.62, 0.5),
		"dark": Color(0.07, 0.05, 0.04), "trim": Color(0.27, 0.26, 0.25), "accent": Color(0.3, 0.22, 0.16)},
	# Mechanical, the Neon City's and the default: gunmetal plates.
	&"mechanical": {"base": Color(0.33, 0.35, 0.39), "tip": Color(0.24, 0.25, 0.28), "belly": Color(0.46, 0.48, 0.52),
		"dark": Color(0.06, 0.06, 0.07), "trim": Color(0.15, 0.16, 0.18), "accent": Color(0.52, 0.54, 0.58)},
	# The Corporate zone's: cold steel with a military olive band.
	&"vr_runner": {"base": Color(0.45, 0.47, 0.5), "tip": Color(0.33, 0.35, 0.37), "belly": Color(0.58, 0.6, 0.62),
		"dark": Color(0.06, 0.06, 0.07), "trim": Color(0.33, 0.35, 0.26), "accent": Color(0.66, 0.68, 0.7)},
	# The Dead Zone's: sooty, scorched metal with rust.
	&"burned": {"base": Color(0.2, 0.19, 0.18), "tip": Color(0.14, 0.13, 0.12), "belly": Color(0.3, 0.27, 0.24),
		"dark": Color(0.04, 0.04, 0.04), "trim": Color(0.33, 0.2, 0.12), "accent": Color(0.38, 0.33, 0.29)},
	# The Golden Zone's: creamy white plates with unlit gold trim.
	&"golden": {"base": Color(0.88, 0.86, 0.8), "tip": Color(0.76, 0.73, 0.66), "belly": Color(0.95, 0.93, 0.88),
		"dark": Color(0.08, 0.07, 0.06), "trim": Color(0.72, 0.55, 0.24), "accent": Color(0.8, 0.62, 0.3)},
}

var variant: StringName = &"city"
var creature: bool = false
## The muzzle's charge (0–1), as set_charge last set it.
var charge: float = 0.0
## How far out of the hatch it is (0 retracted, 1 out), as set_emerged last set it.
var emerged: float = 1.0

var _root: Node3D
var _head: Node3D
var _barrel: Node3D
var _body: MeshInstance3D
var _barrel_mesh: MeshInstance3D
var _eyes: MeshInstance3D
var _pupils: Node3D
var _orb: MeshInstance3D
var _charge_mat: ShaderMaterial
var _watch := Vector3.ZERO
var _watching: bool = false
var _aim := Vector3.ZERO
var _aiming: bool = false
var _yaw: float = 0.0
var _pitch: float = 0.0
var _t: float = 0.0
var _flash_left: float = 0.0
var _blink_in: float = 2.0
var _blink_t: float = -1.0
var _dying: float = -1.0
var _dead: bool = false
var _death_cause: StringName = &""
var _rng := RandomNumberGenerator.new()


## True if `v` (a skin's enemy_variant, or a look's own name) wears the creature look.
static func is_creature(v: StringName) -> bool:
	return CREATURE_VARIANTS.has(v)


## The palette key a variant wears.
static func palette_key(v: StringName) -> StringName:
	if v == &"scavenger" or v == &"creature_scavenger":
		return &"creature_scavenger"
	if is_creature(v):
		return &"creature"
	return v if PALETTES.has(v) else &"mechanical"


## Builds the look for `p_variant` (a skin's enemy_variant). `visual_seed` varies its idle motion.
func build(p_variant: StringName, visual_seed: int) -> void:
	variant = p_variant
	creature = is_creature(p_variant)
	_rng.seed = hash([visual_seed, "barnacle_look"])
	_blink_in = _rng.randf_range(1.0, 3.0)
	var key: StringName = palette_key(p_variant)
	var pal: Dictionary = PALETTES[key]
	var collar := MeshInstance3D.new()
	collar.name = "Collar"
	collar.mesh = Kit.mesh("barnacle/collar/%s/%s" % [key, creature], _collar_mesh.bind(pal, creature))
	collar.material_override = Kit.part_material(&"normal")
	add_child(collar)
	_root = Node3D.new()
	_root.name = "Dome"
	add_child(_root)
	_head = Node3D.new()
	_head.name = "Head"
	_root.add_child(_head)
	_body = MeshInstance3D.new()
	_body.name = "Body"
	_body.mesh = Kit.mesh("barnacle/body/%s" % key, _creature_mesh.bind(pal, key == &"creature_scavenger") if creature
		else _mechanical_mesh.bind(pal))
	_body.material_override = Kit.part_material(&"normal")
	_head.add_child(_body)
	if creature:
		_eyes = MeshInstance3D.new()
		_eyes.name = "Eyes"
		_eyes.mesh = Kit.mesh("barnacle/eyes", _eyes_mesh)
		_eyes.material_override = _matte_material()
		_head.add_child(_eyes)
		_pupils = Node3D.new()
		_pupils.name = "PupilPivot"
		_pupils.position = Vector3(0.0, EYE_Y, EYE_Z - 0.35)
		_head.add_child(_pupils)
		var pupils := MeshInstance3D.new()
		pupils.mesh = Kit.mesh("barnacle/pupils", _pupils_mesh)
		pupils.material_override = _matte_material()
		pupils.position = -_pupils.position
		_pupils.add_child(pupils)
	_barrel = Node3D.new()
	_barrel.name = "Barrel"
	_barrel.position = Vector3(0.0, CANNON_Y, 0.42)
	_head.add_child(_barrel)
	_barrel_mesh = MeshInstance3D.new()
	_barrel_mesh.mesh = Kit.mesh("barnacle/barrel/%s" % key, _barrel_mesh_for.bind(pal))
	_barrel_mesh.material_override = Kit.part_material(&"normal")
	_barrel_mesh.position = -_barrel.position
	_barrel.add_child(_barrel_mesh)
	_charge_mat = ShaderMaterial.new()
	_charge_mat.shader = _charge_shader()
	_charge_mat.set_shader_parameter(&"charge_color", CHARGE_COLOR)
	_charge_mat.set_shader_parameter(&"rest_color", Color(0.09, 0.09, 0.1))
	var ring := MeshInstance3D.new()
	ring.name = "Muzzle"
	ring.mesh = Kit.mesh("barnacle/muzzle", _muzzle_mesh)
	ring.material_override = _charge_mat
	ring.position = -_barrel.position
	_barrel.add_child(ring)
	_orb = MeshInstance3D.new()
	_orb.name = "ChargeOrb"
	_orb.mesh = Kit.mesh("barnacle/orb", _orb_mesh)
	var orb_mat := _charge_mat.duplicate() as ShaderMaterial
	orb_mat.set_shader_parameter(&"orb", 1.0)
	_orb.material_override = orb_mat
	_orb.position = MUZZLE + Vector3(0.0, 0.0, 0.08) - _barrel.position
	_orb.visible = false
	_barrel.add_child(_orb)
	for mi: MeshInstance3D in [collar, _body, _barrel_mesh, ring, _orb]:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	set_emerged(emerged)
	set_charge(0.0)


## The pop out of the hatch: 0 retracted inside it, 1 out (with a little overshoot on the way).
func set_emerged(amount: float) -> void:
	emerged = clampf(amount, 0.0, 1.0)
	if _root == null:
		return
	var e: float = emerged
	# An elastic pop: it overshoots a little, then settles.
	var s: float = 0.0 if e <= 0.0 else 1.0 - pow(1.0 - e, 3.0) + 0.14 * sin(e * PI) * (1.0 - e * 0.5)
	_root.visible = e > 0.0
	_root.scale = Vector3.ONE * maxf(s, 0.001)
	_root.position = Vector3(0.0, 0.12 * (1.0 - minf(s, 1.0)), 0.0)


func set_charge(amount: float) -> void:
	charge = clampf(amount, 0.0, 1.0)
	if _charge_mat == null:
		return
	_charge_mat.set_shader_parameter(&"charge", charge)
	_orb.visible = charge > 0.02
	_orb.scale = Vector3.ONE * lerpf(0.3, 1.2, charge)


## The muzzle's red glow now (0 at rest): what the telegraph shows.
func glow_amount() -> float:
	return charge * charge


func aim_at(world_point: Vector3) -> void:
	_aim = world_point
	_aiming = true


func clear_aim() -> void:
	_aiming = false


## Turns lazily toward a point it watches while not aiming (the player), the creature's eyes first.
func watch(world_point: Vector3) -> void:
	_watch = world_point
	_watching = true


## A short white flash when hit by a weapon (softer and held longer with Reduced flashing).
func flash() -> void:
	if _dying >= 0.0 or _body == null:
		return
	var soft: bool = Settings.flashing_reduced
	_flash_left = SOFT_FLASH_TIME if soft else FLASH_TIME
	_body.material_override = Kit.part_material(&"flash_soft" if soft else &"flash")


## The death animation (a stomp squashes it flat first), then `death_finished`.
func die(cause: StringName) -> void:
	if _dying >= 0.0:
		return
	_dying = 0.0
	_death_cause = cause
	set_charge(0.0)
	if _body != null:
		_body.material_override = Kit.part_material(&"dead")


## Draw calls of the visible model (one per visible mesh; each has one surface).
func draw_call_count() -> int:
	var n: int = 0
	for mi: Node in find_children("*", "MeshInstance3D", true, false):
		var shown: bool = true
		var node: Node = mi
		while node != self and node != null:
			shown = shown and (node as Node3D).visible
			node = node.get_parent()
		if shown:
			n += 1
	return n


func _process(delta: float) -> void:
	if _root == null:
		return
	_t += delta
	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0 and _dying < 0.0:
			_body.material_override = Kit.part_material(&"normal")
	if _dying >= 0.0:
		if not _dead:
			_animate_death(delta)
		return
	_turn(delta)
	if creature:
		_animate_creature(delta)


func _turn(delta: float) -> void:
	var target_yaw: float = 0.0
	var target_pitch: float = 0.0
	var point: Vector3 = _aim if _aiming else _watch
	if _aiming or _watching:
		# In the dome's own frame (it turns about its axis; the root never does).
		var local: Vector3 = _root.global_transform.affine_inverse() * point if _root.is_inside_tree() else point
		target_yaw = clampf(atan2(local.x, local.z), -MAX_YAW, MAX_YAW)
		var flat: float = Vector2(local.x, local.z).length()
		target_pitch = clampf(atan2(-(local.y - CANNON_Y), maxf(flat, 0.5)), -MAX_PITCH, MAX_PITCH)
	var rate: float = TURN_RATE if _aiming else LAZY_TURN_RATE
	var k: float = 1.0 - exp(-rate * delta)
	_yaw = lerpf(_yaw, target_yaw, k)
	_pitch = lerpf(_pitch, target_pitch, k)
	_head.rotation = Vector3(0.0, _yaw, 0.0)
	_barrel.rotation = Vector3(_pitch, 0.0, 0.0)
	if _pupils != null:
		_pupils.rotation = Vector3(_pitch * 0.8, (target_yaw - _yaw) * 1.5, 0.0)


## The creature breathes, puffs up while it charges, and blinks now and then (a slow squint).
func _animate_creature(delta: float) -> void:
	var breathe: float = 0.022 * sin(_t * TAU * 0.9) + 0.05 * charge
	_head.scale = Vector3(1.0 + breathe, 1.0 - breathe * 0.5, 1.0 + breathe)
	_blink_in -= delta
	if _blink_in <= 0.0 and _blink_t < 0.0:
		_blink_t = 0.0
		_blink_in = _rng.randf_range(2.0, 4.5)
	var lid: float = 1.0
	if _blink_t >= 0.0:
		_blink_t += delta
		lid = 1.0 - 0.9 * sin(clampf(_blink_t / 0.22, 0.0, 1.0) * PI)
		if _blink_t >= 0.22:
			_blink_t = -1.0
	var eye_scale := Vector3(1.0, lid, 1.0)
	_eyes.scale = eye_scale
	_eyes.position = Vector3(0.0, EYE_Y * (1.0 - lid), 0.0)
	(_pupils.get_child(0) as Node3D).scale = eye_scale
	(_pupils.get_child(0) as Node3D).position = -_pupils.position + Vector3(0.0, EYE_Y * (1.0 - lid), 0.0)


## A stomp squashes it flat, anything else makes it shudder; then it shrinks back into its hatch.
func _animate_death(delta: float) -> void:
	_dying += delta
	var squash: bool = _death_cause == &"stomp"
	var u: float = clampf(_dying / 0.45, 0.0, 1.0)
	var s: float = 1.0 - u * u
	if squash:
		_root.scale = Vector3(1.0 + 0.4 * (1.0 - s), maxf(s * 0.45, 0.001), 1.0 + 0.4 * (1.0 - s))
	else:
		var shake: float = 0.0 if Settings.flashing_reduced else 0.06 * sin(_dying * 70.0) * (1.0 - u)
		_head.rotation = Vector3(0.0, _yaw + shake, 0.0)
		_root.scale = Vector3.ONE * maxf(s, 0.001)
	if u >= 1.0:
		_root.visible = false
		_dead = true
		death_finished.emit()


static var _shader: Shader = null
static var _matte: ShaderMaterial = null


## The creature's eyes: the kit's part material made matte, so the eyes never mirror the charge orb's
## red (a red glint there would read as glowing red eyes).
static func _matte_material() -> ShaderMaterial:
	if _matte == null:
		_matte = Kit.part_material(&"normal").duplicate() as ShaderMaterial
		_matte.set_shader_parameter(&"roughness", 1.0)
		_matte.set_shader_parameter(&"metallic", 0.0)
	return _matte


## The muzzle's charge shader, shared by every turret (each has its own material for its own charge).
static func _charge_shader() -> Shader:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = CHARGE_SHADER
	return _shader


# --- Meshes -----------------------------------------------------------------------------------------

## Where the creature's eyes sit (their centres) on the dome's upper front.
const EYE_Y: float = -0.19
const EYE_Z: float = 0.49
const EYE_X: float = 0.2
const EYE_RADIUS: float = 0.15
const PUPIL_RADIUS: float = 0.07


## A point on the dome's surface at angle `phi` down from its top ring (0) to the crown (PI/2) and
## `theta` around (0 = the front, +z), and the surface's outward normal there.
static func dome_point(phi: float, theta: float, grow: float = 0.0) -> Vector3:
	var r: float = DOME_RADIUS * cos(phi) + grow
	return Vector3(r * sin(theta), DOME_TOP - (DOME_DEPTH + grow) * sin(phi), r * cos(theta))


static func dome_normal(phi: float, theta: float) -> Vector3:
	var n := Vector3(cos(phi) * sin(theta) / DOME_RADIUS, -sin(phi) / DOME_DEPTH, cos(phi) * cos(theta) / DOME_RADIUS)
	return n.normalized()


## The dome as rings of flat-shaded quads, each coloured by `paint(phi, theta)` (sRGB, alpha = glow).
static func _add_dome(st: SurfaceTool, rings: int, sides: int, paint: Callable) -> void:
	var center := Vector3(0.0, DOME_TOP, 0.0)
	for i: int in rings:
		var p0: float = PI * 0.5 * float(i) / rings
		var p1: float = PI * 0.5 * float(i + 1) / rings
		for j: int in sides:
			var t0: float = TAU * (float(j) - 0.5) / sides
			var t1: float = TAU * (float(j) + 0.5) / sides
			var col: Color = paint.call((p0 + p1) * 0.5, (t0 + t1) * 0.5)
			var a: Vector3 = dome_point(p0, t0)
			var b: Vector3 = dome_point(p0, t1)
			var c: Vector3 = dome_point(p1, t1)
			var d: Vector3 = dome_point(p1, t0)
			_tri(st, a, b, c, center, col)
			if i < rings - 1:
				_tri(st, a, c, d, center, col)
	# The top: a disc closing the dome inside the collar.
	for j: int in sides:
		var t0: float = TAU * (float(j) - 0.5) / sides
		var t1: float = TAU * (float(j) + 0.5) / sides
		_tri(st, dome_point(0.0, t0), dome_point(0.0, t1), center, center + Vector3(0.0, -1.0, 0.0),
			paint.call(0.0, (t0 + t1) * 0.5))


## A cone (a fur tuft, a spike) from a base centred at `base` along `dir`: `length` long, `radius` wide,
## `sides` sides, base colour `c0` fading to `c1` at its tip.
static func _add_cone(st: SurfaceTool, base: Vector3, dir: Vector3, length: float, radius: float, sides: int,
		c0: Color, c1: Color, twist: float = 0.0) -> void:
	var d: Vector3 = dir.normalized()
	var side: Vector3 = d.cross(Vector3.UP if absf(d.y) < 0.9 else Vector3.RIGHT).normalized()
	var up: Vector3 = side.cross(d).normalized()
	var tip: Vector3 = base + d * length
	var ring: Array[Vector3] = []
	for k: int in sides:
		var a: float = TAU * float(k) / sides + twist
		ring.append(base + (side * cos(a) + up * sin(a)) * radius)
	for k: int in sides:
		var p: Vector3 = ring[k]
		var q: Vector3 = ring[(k + 1) % sides]
		_tri_colors(st, p, q, tip, base - d * 0.1, [c0, c0, c1])


## One flat-shaded triangle facing away from `inside`, in one colour.
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, inside: Vector3, col: Color) -> void:
	_tri_colors(st, a, b, c, inside, [col, col, col])


## One flat-shaded triangle facing away from `inside`, a colour per corner (sRGB in, stored linear like
## the cyborg kit's Builder, with the alpha as glow).
static func _tri_colors(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, inside: Vector3, cols: Array) -> void:
	var n: Vector3 = (b - a).cross(c - a)
	if n.length_squared() < 1e-12:
		return
	n = n.normalized()
	var outward: Vector3 = (a + b + c) / 3.0 - inside
	var verts: Array[Vector3] = [a, b, c]
	var colors: Array = cols.duplicate()
	if n.dot(outward) < 0.0:
		n = -n
	# Godot's front faces wind clockwise seen from outside.
	if (b - a).cross(c - a).dot(n) > 0.0:
		verts = [a, c, b]
		colors = [cols[0], cols[2], cols[1]]
	for k: int in 3:
		var col: Color = colors[k]
		var lin: Color = col.srgb_to_linear()
		st.set_normal(n)
		st.set_color(Color(lin.r, lin.g, lin.b, clampf(col.a if col.a < 1.0 else 0.0, 0.0, 1.0)))
		st.add_vertex(verts[k])


## Colour with a glow strength (0–1) in its alpha, for _tri_colors (alpha 1 means no glow).
static func _glow(col: Color, glow: float) -> Color:
	return Color(col.r, col.g, col.b, clampf(glow, 0.0, 0.99))


static func _begin() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


## The hatch ring on the underside: a bolted steel ring round a dark opening (mechanical), or a dark
## hole ringed with fur (the creature's burrow).
static func _collar_mesh(pal: Dictionary, is_furry: bool) -> ArrayMesh:
	var st := _begin()
	var ring_col: Color = pal["trim"] if not is_furry else pal["accent"]
	_add_prism_y(st, Vector3(0.0, -COLLAR_DEPTH * 0.5 + 0.005, 0.0), COLLAR_RADIUS, COLLAR_DEPTH, 14, ring_col)
	_add_prism_y(st, Vector3(0.0, -COLLAR_DEPTH - 0.004, 0.0), COLLAR_RADIUS * 0.84, 0.012, 14, pal["dark"])
	if is_furry:
		# Tufts round the rim, drooping down from the underside: the creature's burrow.
		var rng := RandomNumberGenerator.new()
		rng.seed = 4411
		for k: int in 16:
			var a: float = TAU * (k + rng.randf_range(-0.3, 0.3)) / 16.0
			var base := Vector3(sin(a) * COLLAR_RADIUS * 0.95, -COLLAR_DEPTH * 0.6, cos(a) * COLLAR_RADIUS * 0.95)
			var dir := Vector3(sin(a) * 0.55, -1.0, cos(a) * 0.55)
			_add_cone(st, base, dir, rng.randf_range(0.1, 0.17), 0.07, 4, pal["base"], pal["tip"], rng.randf() * TAU)
	else:
		# Bolts round the hatch ring.
		for k: int in 8:
			var a: float = TAU * (k + 0.5) / 8.0
			_add_box(st, Vector3(sin(a) * COLLAR_RADIUS * 0.93, -COLLAR_DEPTH - 0.01, cos(a) * COLLAR_RADIUS * 0.93),
				Vector3(0.06, 0.03, 0.06), pal["accent"])
	return st.commit()


## The mechanical dome: armour plates in two tones, a trim band with rivets, side vents, a darker cap
## on the crown, the cannon's housing, and a small cold-white sensor above it.
static func _mechanical_mesh(pal: Dictionary) -> ArrayMesh:
	var st := _begin()
	var base: Color = pal["base"]
	var alt: Color = pal["tip"]
	var trim: Color = pal["trim"]
	_add_dome(st, 6, 14, func(phi: float, theta: float) -> Color:
		var ring: int = int(phi / (PI * 0.5) * 6.0)
		var seg: int = int(round(theta / (TAU / 14.0)))
		if ring == 1:
			return trim
		if ring >= 5:
			return pal["dark"].lerp(base, 0.35)
		return base if (seg + ring) % 2 == 0 else base.lerp(alt, 0.45))
	# Rivets along the band.
	for k: int in 14:
		var th: float = TAU * (k + 0.5) / 14.0
		var p: Vector3 = dome_point(PI * 0.5 * 1.5 / 6.0, th, 0.012)
		_add_box(st, p, Vector3(0.045, 0.045, 0.045), pal["accent"])
	# Vents on either side: dark slits.
	for side: float in [-1.0, 1.0]:
		for k: int in 3:
			var th: float = side * (PI * 0.5 + 0.12 * (k - 1))
			var p: Vector3 = dome_point(0.62, th, 0.01)
			_add_box(st, p, Vector3(0.05, 0.16, 0.05), pal["dark"])
	# The cannon's housing: a thick collar on the chest.
	_add_prism_z(st, Vector3(0.0, CANNON_Y, 0.5), 0.19, 0.16, 10, trim)
	# The sensor: a small lens in the cyborgs' cold white (their screens' LED colour), dim.
	var lens_p: Vector3 = dome_point(0.27, 0.0, 0.0)
	_add_prism_z(st, lens_p + Vector3(0.0, 0.0, 0.005), 0.085, 0.05, 8, pal["dark"])
	_add_prism_z(st, lens_p + Vector3(0.0, 0.0, 0.03), 0.05, 0.03, 8, _glow(Kit.LED_COLOR, 0.55))
	return st.commit()


## The creature: the dome in its fur colours (a paler belly round the chest), covered in tufts that
## droop a little, a cowlick of longer tufts on the crown, floppy ears, the cannon's housing, and a
## little nose between the eyes and the cannon. The eyes are their own meshes (they blink).
static func _creature_mesh(pal: Dictionary, scruffy: bool) -> ArrayMesh:
	var st := _begin()
	var fur: Color = pal["base"]
	var belly: Color = pal["belly"]
	_add_dome(st, 6, 14, func(phi: float, theta: float) -> Color:
		var front: float = cos(theta)
		return belly if front > 0.75 and phi > 0.35 and phi < 1.25 else fur)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7729
	# Tufts all over, leaving the face (eyes, nose, cannon) clear.
	for i: int in 10:
		var phi: float = lerpf(0.08, 1.45, (float(i) + 0.5) / 10.0)
		var count: int = maxi(5, int(round(24.0 * cos(phi) + 4.0)))
		for j: int in count:
			var theta: float = TAU * (float(j) + rng.randf_range(-0.35, 0.35)) / count + i * 0.37
			var p: Vector3 = dome_point(phi, theta, -0.015)
			if _in_face(p):
				continue
			var n: Vector3 = dome_normal(phi, theta)
			var dir: Vector3 = (n + Vector3(0.0, -0.75, 0.0) + Vector3(rng.randf_range(-0.25, 0.25), 0.0,
				rng.randf_range(-0.25, 0.25))).normalized()
			# Shorter toward the crown, so the fur never hangs much below it (BarnacleTurret.REACH_BELOW).
			var length: float = rng.randf_range(0.08, 0.13) * (1.3 if scruffy else 1.0) * (1.0 - 0.45 * smoothstep(0.9, 1.4, phi))
			var tip_col: Color = fur.lerp(pal["tip"], rng.randf_range(0.25, 0.6))
			var base_col: Color = belly if cos(theta) > 0.75 and phi > 0.35 and phi < 1.25 else fur
			_add_cone(st, p, dir, length, rng.randf_range(0.075, 0.105), 5, base_col.darkened(rng.randf_range(0.0, 0.12)),
				tip_col, rng.randf() * TAU)
	# The cowlick: a few tufts on the crown, curling forward and out.
	for k: int in 5:
		var a: float = TAU * k / 5.0
		var p := Vector3(sin(a) * 0.1, DOME_TOP - DOME_DEPTH + 0.03, cos(a) * 0.1)
		_add_cone(st, p, Vector3(sin(a) * 0.9, -0.8, cos(a) * 0.9 + 0.5), 0.17, 0.07, 4, fur, pal["tip"], a)
	# Floppy ears on the sides, near the top.
	for side: float in [-1.0, 1.0]:
		var p: Vector3 = dome_point(0.22, side * PI * 0.5, -0.02)
		_add_cone(st, p, Vector3(side * 1.0, -0.75, 0.15), 0.27, 0.13, 5, fur, pal["accent"], 0.4)
		_add_cone(st, p + Vector3(0.0, -0.02, 0.03), Vector3(side * 1.0, -0.8, 0.25), 0.19, 0.07, 5, pal["belly"],
			pal["belly"], 0.4)
	# The nose: a small dark nub between the eyes and the cannon.
	_add_prism_z(st, Vector3(0.0, -0.3, 0.55), 0.045, 0.06, 6, pal["dark"])
	# The cannon's housing, half sunk in the fur.
	_add_prism_z(st, Vector3(0.0, CANNON_Y, 0.49), 0.18, 0.14, 10, pal["trim"])
	return st.commit()


## True if a dome point is on the creature's face (the eyes, the nose and the cannon), which the fur
## leaves clear.
static func _in_face(p: Vector3) -> bool:
	return p.z > 0.28 and absf(p.x) < 0.42 and p.y < -0.06 and p.y > -0.6


## The creature's googly eyes: two white balls on the upper front.
static func _eyes_mesh() -> ArrayMesh:
	var st := _begin()
	for side: float in [-1.0, 1.0]:
		_add_ball(st, Vector3(side * EYE_X, EYE_Y, EYE_Z), EYE_RADIUS * (1.0 if side < 0.0 else 1.12), 10, 6,
			Color(0.97, 0.97, 0.95))
	return st.commit()


## The pupils: black, a little off-centre (one looks a bit further out: silly), with a white glint.
static func _pupils_mesh() -> ArrayMesh:
	var st := _begin()
	for side: float in [-1.0, 1.0]:
		var r: float = EYE_RADIUS * (1.0 if side < 0.0 else 1.12)
		var c := Vector3(side * EYE_X + side * 0.025, EYE_Y - 0.01, EYE_Z + r - PUPIL_RADIUS * 0.45)
		_add_ball(st, c, PUPIL_RADIUS, 8, 5, Color(0.03, 0.03, 0.035))
		_add_ball(st, c + Vector3(-0.025, 0.028, PUPIL_RADIUS * 0.75), 0.018, 5, 3, Color(1.0, 1.0, 1.0))
	return st.commit()


## The barrel: a dark steel tube from the housing to the muzzle ring, with a sight on top.
static func _barrel_mesh_for(pal: Dictionary) -> ArrayMesh:
	var st := _begin()
	_add_prism_z(st, Vector3(0.0, CANNON_Y, 0.66), 0.095, 0.4, 10, pal["dark"].lerp(pal["trim"], 0.5))
	_add_prism_z(st, Vector3(0.0, CANNON_Y, 0.6), 0.115, 0.08, 10, pal["trim"])
	_add_box(st, Vector3(0.0, CANNON_Y + 0.1, 0.62), Vector3(0.035, 0.05, 0.2), pal["trim"])
	return st.commit()


## The muzzle ring (the charge material).
static func _muzzle_mesh() -> ArrayMesh:
	var st := _begin()
	_add_prism_z(st, MUZZLE + Vector3(0.0, 0.0, -0.02), 0.125, 0.07, 12, Color(1.0, 1.0, 1.0))
	return st.commit()


## The charge orb at the muzzle (grown by set_charge).
static func _orb_mesh() -> ArrayMesh:
	var st := _begin()
	_add_ball(st, Vector3.ZERO, 0.065, 8, 5, Color(1.0, 1.0, 1.0))
	return st.commit()


## A box (flat-shaded) centred at `c`.
static func _add_box(st: SurfaceTool, c: Vector3, size: Vector3, col: Color) -> void:
	var h: Vector3 = size * 0.5
	var p: Array[Vector3] = []
	for k: int in 8:
		p.append(c + Vector3(h.x * (1 if k & 1 else -1), h.y * (1 if k & 2 else -1), h.z * (1 if k & 4 else -1)))
	for q: Array in [[0, 1, 3, 2], [4, 5, 7, 6], [0, 1, 5, 4], [2, 3, 7, 6], [0, 2, 6, 4], [1, 3, 7, 5]]:
		_tri(st, p[q[0]], p[q[1]], p[q[2]], c, col)
		_tri(st, p[q[0]], p[q[2]], p[q[3]], c, col)


## A prism along z (a low-poly tube section): `radius`, `length`, `sides` sides, centred at `c`.
static func _add_prism_z(st: SurfaceTool, c: Vector3, radius: float, length: float, sides: int, col: Color) -> void:
	var back: Array[Vector3] = []
	var front: Array[Vector3] = []
	for k: int in sides:
		var a: float = TAU * (k + 0.5) / sides
		var o := Vector3(cos(a) * radius, sin(a) * radius, 0.0)
		back.append(c + o - Vector3(0.0, 0.0, length * 0.5))
		front.append(c + o + Vector3(0.0, 0.0, length * 0.5))
	for k: int in sides:
		var n: int = (k + 1) % sides
		_tri(st, back[k], back[n], front[n], c, col)
		_tri(st, back[k], front[n], front[k], c, col)
		_tri(st, c - Vector3(0.0, 0.0, length * 0.5), back[k], back[n], c + Vector3(0.0, 0.0, 1.0), col)
		_tri(st, c + Vector3(0.0, 0.0, length * 0.5), front[k], front[n], c - Vector3(0.0, 0.0, 1.0), col)


## A prism along y (a flat disc or ring): `radius`, `height`, `sides` sides, centred at `c`.
static func _add_prism_y(st: SurfaceTool, c: Vector3, radius: float, height: float, sides: int, col: Color) -> void:
	var top: Array[Vector3] = []
	var bottom: Array[Vector3] = []
	for k: int in sides:
		var a: float = TAU * (k + 0.5) / sides
		var o := Vector3(sin(a) * radius, 0.0, cos(a) * radius)
		top.append(c + o + Vector3(0.0, height * 0.5, 0.0))
		bottom.append(c + o - Vector3(0.0, height * 0.5, 0.0))
	for k: int in sides:
		var n: int = (k + 1) % sides
		_tri(st, top[k], top[n], bottom[n], c, col)
		_tri(st, top[k], bottom[n], bottom[k], c, col)
		_tri(st, c + Vector3(0.0, height * 0.5, 0.0), top[k], top[n], c - Vector3(0.0, 1.0, 0.0), col)
		_tri(st, c - Vector3(0.0, height * 0.5, 0.0), bottom[k], bottom[n], c + Vector3(0.0, 1.0, 0.0), col)


## A low-poly ball (a UV sphere of `sides` × `rings`).
static func _add_ball(st: SurfaceTool, c: Vector3, radius: float, sides: int, rings: int, col: Color) -> void:
	for i: int in rings:
		var p0: float = PI * float(i) / rings - PI * 0.5
		var p1: float = PI * float(i + 1) / rings - PI * 0.5
		for j: int in sides:
			var t0: float = TAU * float(j) / sides
			var t1: float = TAU * float(j + 1) / sides
			var a: Vector3 = c + _sphere(p0, t0) * radius
			var b: Vector3 = c + _sphere(p0, t1) * radius
			var d: Vector3 = c + _sphere(p1, t0) * radius
			var e: Vector3 = c + _sphere(p1, t1) * radius
			_tri(st, a, b, e, c, col)
			_tri(st, a, e, d, c, col)


static func _sphere(phi: float, theta: float) -> Vector3:
	return Vector3(cos(phi) * sin(theta), sin(phi), cos(phi) * cos(theta))
