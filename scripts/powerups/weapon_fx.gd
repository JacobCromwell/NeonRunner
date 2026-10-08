class_name WeaponFx
extends Node3D
## The weapon's own visuals on top of the pooled shots (the pool already draws the shots and a hit
## burst): a muzzle flash at the shoulder, a tapered streak behind each shot (a beam for the lasers,
## a trail for the missiles, so shots flying away from the camera still read), and the heavy
## missile's blast, a thin shockwave ring facing the camera that grows to the splash radius, so the
## player sees what it reaches without it hiding the track. Player fire stays cool
## (cyan/white/violet) so it never reads like red enemy fire. Everything is pooled, unshaded and
## CPU-driven, so it works on the Compatibility renderer.

const FLASH_POOL: int = 3
const BLAST_POOL: int = 3
const TRAIL_POOL: int = 12
const FLASH_TIME: float = 0.07
const BLAST_TIME: float = 0.26
## Per tier: streak length (m) and radius at the shot's end. The enhanced laser is thicker.
const TRAIL_LENGTH: Array[float] = [3.2, 3.6, 1.8, 2.6]
const TRAIL_RADIUS: Array[float] = [0.035, 0.06, 0.06, 0.09]
const MISSILE_TRAIL_COLOR := Color(0.55, 0.9, 1.0)
## The fireballs of the missiles' hits (RunEffects.fireball, radius in metres; GDD §11: missiles explode in
## yellow and red fire, though the rest of the player's fire stays cool): the heavy missile's inside the
## cyan ring that marks its splash, and the plain missile's a small pop.
const HEAVY_FIRE_SIZE: float = 2.2
const MISSILE_FIRE_SIZE: float = 0.9

const BLAST_SHADER: String = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 color : source_color = vec4(0.6, 0.95, 1.0, 1.0);
uniform float fade = 1.0;
// Ring width as a share of the radius.
uniform float thickness = 0.09;
void fragment() {
	float r = length(UV * 2.0 - 1.0);
	float ring = smoothstep(1.0, 1.0 - thickness, r) * smoothstep(1.0 - thickness * 3.0, 1.0 - thickness, r);
	float glow = (1.0 - smoothstep(0.0, 1.0, r)) * 0.06;
	ALBEDO = color.rgb * 1.5;
	ALPHA = clamp((ring + glow) * fade, 0.0, 1.0);
}
"""
const TRAIL_SHADER: String = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 color : source_color = vec4(0.55, 0.9, 1.0, 1.0);
varying float along;
void vertex() {
	along = clamp(VERTEX.y + 0.5, 0.0, 1.0);
}
void fragment() {
	ALBEDO = color.rgb * 1.5;
	ALPHA = along * along * 0.85;
}
"""

var world: RunWorld
var weapon: WeaponPowerup

var _flashes: Array[MeshInstance3D] = []
var _flash_life: PackedFloat32Array = PackedFloat32Array()
var _flash_dir: Array[Vector3] = []
var _next_flash: int = 0
var _blasts: Array[MeshInstance3D] = []
var _blast_life: PackedFloat32Array = PackedFloat32Array()
var _blast_radius: PackedFloat32Array = PackedFloat32Array()
var _blast_pos: Array[Vector3] = []
var _next_blast: int = 0
var _trails: Array[MeshInstance3D] = []


func setup(p_world: RunWorld, p_weapon: WeaponPowerup) -> void:
	world = p_world
	weapon = p_weapon
	var color: Color = _look_color()
	var flash_mesh := SphereMesh.new()
	flash_mesh.radius = 0.5
	flash_mesh.height = 1.0
	flash_mesh.radial_segments = 8
	flash_mesh.rings = 4
	for i: int in FLASH_POOL:
		_flashes.append(_mesh_instance(flash_mesh, GreyboxMaterials.glow(color.lerp(Color.WHITE, 0.5), 5.0)))
		_flash_life.append(0.0)
		_flash_dir.append(Vector3.FORWARD)
	if weapon.is_heavy():
		var quad := QuadMesh.new()
		quad.size = Vector2(2.0, 2.0)  # UV edge = radius 1
		for i: int in BLAST_POOL:
			var mat := PowerupModule.shader_material(BLAST_SHADER)
			mat.set_shader_parameter(&"color", color.lerp(Color.WHITE, 0.3))
			_blasts.append(_mesh_instance(quad, mat))
			_blast_life.append(0.0)
			_blast_radius.append(1.0)
			_blast_pos.append(Vector3.ZERO)
	var cone := CylinderMesh.new()
	cone.height = 1.0
	cone.top_radius = TRAIL_RADIUS[weapon.tier - 1]
	cone.bottom_radius = 0.005
	cone.radial_segments = 6
	cone.rings = 1
	var trail_mat := PowerupModule.shader_material(TRAIL_SHADER)
	trail_mat.set_shader_parameter(&"color", MISSILE_TRAIL_COLOR if weapon.is_missile() else color)
	for i: int in TRAIL_POOL:
		_trails.append(_mesh_instance(cone, trail_mat))


## A flash at the shoulder as a shot leaves, aimed along `dir`.
func muzzle_flash(dir: Vector3) -> void:
	var i: int = _next_flash
	_next_flash = (_next_flash + 1) % _flashes.size()
	_flash_life[i] = FLASH_TIME
	_flash_dir[i] = dir
	_flashes[i].visible = true
	_place_flash(i)
	var missile: bool = weapon.is_missile()
	world.effects.burst(weapon.muzzle_point() + dir * 0.25, _look_color(), 8 if missile else 4, 0.3 if missile else 0.12)


## A brighter burst in the weapon's own colour where a shot kills an enemy (GDD §3, the owner's
## playtest, September 30, 2026: "sparks and debris on kills"). RunEffects already plays the shared,
## cause-neutral kill spark and shake for every defeat (EnemyDirector.enemy_defeated); this is the
## weapon's own flourish on top, so a weapon kill reads in its own cool colour rather than plain white.
func kill_flash(pos: Vector3) -> void:
	world.effects.burst(pos, _look_color().lerp(Color.WHITE, 0.5), 14, 0.55)


## The plain missile's hit at `pos`: a small fireball (quick, no smoke).
func missile_pop(pos: Vector3) -> void:
	world.effects.fireball(pos, MISSILE_FIRE_SIZE, false, 1.4)


## The heavy missile's blast at `pos`: a fireball, and the ring growing to `radius` (the splash reach).
func blast(pos: Vector3, radius: float) -> void:
	world.effects.fireball(pos, HEAVY_FIRE_SIZE, true, 1.2)
	if _blasts.is_empty():
		return
	var i: int = _next_blast
	_next_blast = (_next_blast + 1) % _blasts.size()
	_blast_life[i] = BLAST_TIME
	_blast_radius[i] = radius
	_blast_pos[i] = pos
	_place_blast(i, 0.0)
	_blasts[i].visible = true
	world.effects.shake(0.14, 0.18)


func update(delta: float) -> void:
	for i: int in _flashes.size():
		if _flash_life[i] <= 0.0:
			continue
		_flash_life[i] -= delta
		if _flash_life[i] <= 0.0:
			_flashes[i].visible = false
		else:
			_place_flash(i)
	for i: int in _blasts.size():
		if _blast_life[i] <= 0.0:
			continue
		_blast_life[i] -= delta
		if _blast_life[i] <= 0.0:
			_blasts[i].visible = false
			continue
		_place_blast(i, 1.0 - _blast_life[i] / BLAST_TIME)
	if not _trails.is_empty():
		_update_trails()


## Sizes blast `i` for progress `k` (0–1): it grows fast to the splash radius and fades, always
## facing the camera.
func _place_blast(i: int, k: float) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	var cam_basis: Basis = camera.global_basis if camera != null else Basis.IDENTITY
	var size: float = lerpf(0.3, _blast_radius[i], 1.0 - pow(1.0 - k, 3.0))
	_blasts[i].global_transform = Transform3D(
		Basis(cam_basis.x * size, cam_basis.y * size, cam_basis.z), _blast_pos[i])
	(_blasts[i].material_override as ShaderMaterial).set_shader_parameter(&"fade", 1.0 - k * k)


func _place_flash(i: int) -> void:
	var k: float = clampf(_flash_life[i] / FLASH_TIME, 0.0, 1.0)
	var size: float = (0.34 if weapon.is_missile() else 0.24) * (0.5 + 0.5 * k)
	var look_basis := Basis.looking_at(_flash_dir[i], _up_for(_flash_dir[i]))
	_flashes[i].global_transform = Transform3D(look_basis * Basis.from_scale(Vector3(size, size, size * 1.8)),
		weapon.muzzle_point() + _flash_dir[i] * 0.2)


## A streak behind each of the weapon's shots in flight, pointing back along its path.
func _update_trails() -> void:
	var full_length: float = TRAIL_LENGTH[weapon.tier - 1]
	var look: StringName = weapon.look()
	var muzzle: Vector3 = weapon.muzzle_point()
	var used: int = 0
	for p: Projectile in world.projectiles.live_shots():
		if used >= _trails.size():
			break
		if not p.friendly or p.look != look:
			continue
		var speed: float = p.velocity.length()
		# Never reach back past the shoulder the shot left from.
		var length: float = minf(full_length, p.global_position.distance_to(muzzle))
		if speed < 0.01 or length < 0.05:
			continue
		var dir: Vector3 = p.velocity / speed
		var trail: MeshInstance3D = _trails[used]
		used += 1
		trail.visible = true
		trail.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, dir)) * Basis.from_scale(Vector3(1.0, length, 1.0)),
			p.global_position - dir * length * 0.5)
	for i: int in range(used, _trails.size()):
		_trails[i].visible = false


func _look_color() -> Color:
	var style: Dictionary = ProjectilePool.LOOKS.get(weapon.look(), ProjectilePool.LOOKS[&"laser"])
	return style["color"]


func _mesh_instance(mesh: Mesh, material: Material) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = material
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	inst.visible = false
	add_child(inst)
	return inst


static func _up_for(dir: Vector3) -> Vector3:
	return Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
