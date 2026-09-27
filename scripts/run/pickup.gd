class_name Pickup
extends Node3D
## One pickup on the track (PickupField, GDD §10): a breakable item the player takes by running
## through it. It looks like what it gives and like nothing else on the track: the HUD's badge for
## that item standing upright at chest height and facing the runner, with the item's icon (the one the
## HUD and the shop show) white-hot on a dark disc inside a bright ring, a soft halo behind it and a
## faint glow on the floor under it. It bobs and sways gently but never spins (credits spin), it has
## no plate on the floor or column of light (pads), no stripes or crackle (hazards), and its whites
## carry no hazard hue (CLAUDE.md readability rules). The badge is about twice the size of the biggest
## credit. It looks the same in every zone: like credits and hazards, it's part of the game's language.
## DESIGN-TBD (docs/questions/b7.md): the look is a placeholder; the GDD doesn't describe pickups.
## Visual only: PickupField decides where it goes, when it's taken and when it's missed, and pools it.

## Emitted when a taken or missed pickup has shrunk away (PickupField pools it again).
signal vanished(pickup: Pickup)

## APPEAR: growing in. IDLE: waiting on the track. TAKEN / MISSED: shrinking away. FREE: in the pool.
enum State { APPEAR, IDLE, TAKEN, MISSED, FREE }

## The ring, halo and floor glow: near-white with a cool tint, no hazard hue (tests check it).
const RING_COLOR := Color(0.84, 0.91, 1.0)
const ICON_COLOR := Color(1.0, 1.0, 1.0)
## The disc behind the icon: dark glass, like the HUD badge's, so the icon reads over bright scenery.
const DISC_COLOR := Color(0.012, 0.018, 0.045)
const SHADER: Shader = preload("res://scripts/run/pickup.gdshader")
## The icon texture's size in pixels (mipmapped, so it stays clean in the distance).
const ICON_PIXELS: float = 128.0
## Sizes on a badge of radius 1 (the node is scaled by PickupTuning.badge_radius).
const RING_INNER: float = 0.93
const RING_OUTER: float = 1.13
const ICON_SIZE: float = 1.55
const HALO_SIZE: float = 3.6
## The floor glow's size in metres (it doesn't scale with the badge).
const FLOOR_GLOW_SIZE: float = 2.0

var item: StringName = &""
var lane: int = 0
## Track distance of its spot.
var at: float = 0.0
var state: State = State.FREE
var tuning: PickupTuning

var _pivot: Node3D
var _badge: Node3D
var _icon: MeshInstance3D
var _floor_glow: MeshInstance3D
## Seconds in the current state, and since it appeared (the bob's phase).
var _t: float = 0.0
var _age: float = 0.0
## Where a taken pickup flies as it shrinks (the player's chest, world space).
var _toward: Vector3 = Vector3.ZERO
var _from: Vector3 = Vector3.ZERO

static var _materials: Dictionary = {}
static var _meshes: Dictionary = {}


func _init() -> void:
	name = "Pickup"
	visible = false
	set_process(false)
	_pivot = Node3D.new()
	_pivot.name = "Pivot"
	add_child(_pivot)
	_badge = Node3D.new()
	_badge.name = "Badge"
	_pivot.add_child(_badge)
	var facing := Basis(Vector3.RIGHT, PI * 0.5)
	# Behind the disc: the halo. Then the disc, its ring, and the icon in front.
	_add(_badge, _mesh(&"halo"), _material(&"halo"), Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, -0.12)))
	_add(_badge, _mesh(&"disc"), _material(&"disc"), Transform3D(facing, Vector3.ZERO))
	_add(_badge, _mesh(&"ring"), _material(&"ring"), Transform3D(facing, Vector3.ZERO))
	_icon = _add(_badge, _mesh(&"icon"), null, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 0.07)))
	_floor_glow = _add(self, _mesh(&"floor_glow"), _material(&"floor_glow"),
		Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0.0, 0.03, 0.0)))


## Puts the pickup on the track: `item` at track distance `p_at` in `p_lane`, at world `origin` (the
## floor under it). It grows in.
func show_item(p_item: StringName, p_lane: int, p_at: float, origin: Vector3, p_tuning: PickupTuning) -> void:
	item = p_item
	lane = p_lane
	at = p_at
	tuning = p_tuning
	position = origin
	_icon.material_override = icon_material(item)
	_apply_tuning()
	state = State.APPEAR
	_t = 0.0
	_age = 0.0
	_pivot.position = Vector3(0.0, tuning.float_height, 0.0)
	_pivot.scale = Vector3.ONE * 0.001
	_floor_glow.scale = Vector3.ONE * 0.001
	visible = true
	set_process(true)


## On the track and takeable (growing in or waiting).
func is_live() -> bool:
	return state == State.APPEAR or state == State.IDLE


## The player took it: it flies into `toward` (world space) as it shrinks away.
func take(toward: Vector3) -> void:
	if not is_live():
		return
	_toward = toward
	_from = _pivot.global_position
	_begin_vanish(State.TAKEN)


## The player ran past it: it shrinks away where it is.
func miss() -> void:
	if is_live():
		_begin_vanish(State.MISSED)


## Back to the pool: hidden and still.
func release() -> void:
	state = State.FREE
	visible = false
	set_process(false)


## Where its badge is now (world space; effects start there).
func badge_position() -> Vector3:
	return _pivot.global_position


## The space that takes it (PickupTuning: take_width, take_height, take_depth), in world space: from
## the floor up, around its spot.
func take_box() -> AABB:
	var size := Vector3(tuning.take_width, tuning.take_height, tuning.take_depth)
	return AABB(position + Vector3(-size.x * 0.5, 0.0, -size.z * 0.5), size)


func _process(delta: float) -> void:
	_t += delta
	_age += delta
	var bob: float = tuning.bob_height * sin(TAU * tuning.bob_speed * _age)
	_badge.rotation.y = deg_to_rad(tuning.sway_degrees) * sin(TAU * tuning.bob_speed * 0.5 * _age)
	match state:
		State.APPEAR:
			var k: float = clampf(_t / maxf(tuning.appear_seconds, 0.01), 0.0, 1.0)
			# Grows in with a small overshoot.
			var s: float = 1.0 + 2.2 * pow(k - 1.0, 3.0) + 1.2 * pow(k - 1.0, 2.0)
			_pivot.scale = Vector3.ONE * maxf(s, 0.001)
			_floor_glow.scale = Vector3.ONE * maxf(k, 0.001)
			_pivot.position = Vector3(0.0, tuning.float_height + bob, 0.0)
			if k >= 1.0:
				state = State.IDLE
				_t = 0.0
		State.IDLE:
			_pivot.scale = Vector3.ONE
			_floor_glow.scale = Vector3.ONE
			_pivot.position = Vector3(0.0, tuning.float_height + bob, 0.0)
		State.TAKEN, State.MISSED:
			var k: float = clampf(_t / maxf(tuning.vanish_seconds, 0.01), 0.0, 1.0)
			_pivot.scale = Vector3.ONE * maxf(1.0 - k, 0.001)
			_floor_glow.scale = Vector3.ONE * maxf(1.0 - k, 0.001)
			if state == State.TAKEN:
				_pivot.global_position = _from.lerp(_toward, k * k)
			if k >= 1.0:
				release()
				vanished.emit(self)


func _begin_vanish(next: State) -> void:
	state = next
	_t = 0.0


## The shared materials follow the tuning (F6 changes show on the next pickup).
func _apply_tuning() -> void:
	_badge.scale = Vector3.ONE * tuning.badge_radius
	(_material(&"ring") as ShaderMaterial).set_shader_parameter(&"energy", tuning.ring_energy)
	(_material(&"halo") as ShaderMaterial).set_shader_parameter(&"energy", tuning.halo_energy)
	(_material(&"floor_glow") as ShaderMaterial).set_shader_parameter(&"energy", tuning.halo_energy * 0.5)
	(icon_material(item) as ShaderMaterial).set_shader_parameter(&"energy", tuning.icon_energy)


static func _add(parent: Node3D, mesh: Mesh, material: Material, xform: Transform3D) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = material
	m.transform = xform
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	return m


## The icon of `p_item` (the HUD's and the shop's), white-hot on its card.
static func icon_material(p_item: StringName) -> Material:
	var key := StringName("icon_%s" % p_item)
	if not _materials.has(key):
		var m := _glow_material(0, ICON_COLOR, 2.4)
		m.set_shader_parameter(&"icon", icon_texture(p_item))
		_materials[key] = m
	return _materials[key]


## The item's icon as a mipmapped texture (white on transparent), from IconFactory's drawing.
static func icon_texture(p_item: StringName) -> Texture2D:
	var key := StringName("texture_%s" % p_item)
	if not _materials.has(key):
		var image := Image.new()
		var icon_name: StringName = p_item if IconFactory.has_icon(p_item) else &"info"
		image.load_svg_from_string(IconFactory.svg(icon_name, ICON_PIXELS, Color.WHITE))
		image.generate_mipmaps()
		_materials[key] = ImageTexture.create_from_image(image)
	return _materials[key]


static func _material(part: StringName) -> Material:
	if _materials.has(part):
		return _materials[part]
	var m: Material
	match part:
		&"disc":
			var disc := StandardMaterial3D.new()
			disc.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			disc.albedo_color = DISC_COLOR
			m = disc
		&"ring":
			m = _glow_material(2, RING_COLOR, 2.6)
		&"halo":
			m = _glow_material(1, RING_COLOR, 0.8)
		_:
			m = _glow_material(1, RING_COLOR, 0.4)
	_materials[part] = m
	return m


static func _glow_material(shape: int, color: Color, energy: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter(&"shape", shape)
	m.set_shader_parameter(&"color", color)
	m.set_shader_parameter(&"energy", energy)
	return m


static func _mesh(part: StringName) -> Mesh:
	if _meshes.has(part):
		return _meshes[part]
	var mesh: Mesh
	match part:
		&"disc":
			var disc := CylinderMesh.new()
			disc.top_radius = 1.0
			disc.bottom_radius = 1.0
			disc.height = 0.12
			disc.radial_segments = 32
			disc.rings = 1
			mesh = disc
		&"ring":
			var ring := TorusMesh.new()
			ring.inner_radius = RING_INNER
			ring.outer_radius = RING_OUTER
			ring.rings = 40
			ring.ring_segments = 8
			mesh = ring
		&"icon":
			var quad := QuadMesh.new()
			quad.size = Vector2(ICON_SIZE, ICON_SIZE)
			mesh = quad
		&"halo":
			var halo := QuadMesh.new()
			halo.size = Vector2(HALO_SIZE, HALO_SIZE)
			mesh = halo
		_:
			var glow := QuadMesh.new()
			glow.size = Vector2(FLOOR_GLOW_SIZE, FLOOR_GLOW_SIZE)
			mesh = glow
	_meshes[part] = mesh
	return mesh
