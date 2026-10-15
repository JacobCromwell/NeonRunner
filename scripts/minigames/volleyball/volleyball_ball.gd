class_name VolleyballBall
extends Node3D
## The volleyball (VolleyballMatch): a striped ball (volleyball_ball.gdshader) with a soft shadow on the sand under it.
## In play it flies along exact arcs (throw_to: from one point to another in a given time under the tuning's
## gravity), so where and when it arrives is known the moment it's hit, and the match checks the runner's hit against
## it every physics frame. Out of play (dead()) it bounces on the sand and rolls to a stop. A rival's hand can hold
## it (hold()). It moves only when the match calls advance(), so it never runs ahead of or behind the match.

const SHADER: Shader = preload("res://scripts/minigames/volleyball/volleyball_ball.gdshader")
## How much of its speed a dead ball keeps on each bounce (up, and along the sand), and when it stops bouncing.
const RESTITUTION: float = 0.42
const FRICTION: float = 0.6
const REST_SPEED: float = 0.9
const MAX_BOUNCES: int = 4

enum Mode { HELD, FLYING, DEAD, RESTING }

signal landed(at: Vector3)

var radius: float = 0.17
var gravity: float = 9.0
var mode: Mode = Mode.RESTING
## The current arc: its start, its start velocity, the time along it, and its planned length (FLYING).
var start := Vector3.ZERO
var start_velocity := Vector3.ZERO
var time: float = 0.0
var duration: float = 1.0
var velocity := Vector3.ZERO
var bounces: int = 0

var _mesh: MeshInstance3D
var _shadow: MeshInstance3D
var _spin_axis := Vector3.RIGHT
var _spin_speed: float = 0.0


func setup(p_radius: float, p_gravity: float) -> void:
	radius = p_radius
	gravity = p_gravity
	name = "Ball"
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 16
	sphere.rings = 8
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	_mesh = MeshInstance3D.new()
	_mesh.name = "Mesh"
	_mesh.mesh = sphere
	_mesh.material_override = mat
	add_child(_mesh)
	var disc := CylinderMesh.new()
	disc.top_radius = radius * 1.3
	disc.bottom_radius = radius * 1.3
	disc.height = 0.01
	disc.radial_segments = 12
	disc.rings = 1
	_shadow = MeshInstance3D.new()
	_shadow.name = "Shadow"
	_shadow.mesh = disc
	_shadow.material_override = GreyboxMaterials.overlay(GreyboxMaterials.SHADOW, false)
	_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shadow.top_level = true
	add_child(_shadow)
	_update_shadow()


## The ball in a hand: it follows `at` (world) until thrown.
func hold(at: Vector3) -> void:
	mode = Mode.HELD
	global_position = at
	velocity = Vector3.ZERO
	_update_shadow()


## Sends the ball from `from` to arrive at `to` in `seconds` (world space), on an arc under `gravity`. It flies on
## past `to` along the same arc until something hits it or it comes down (landed, then dead).
func throw_to(from: Vector3, to: Vector3, seconds: float) -> void:
	mode = Mode.FLYING
	start = from
	duration = maxf(seconds, 0.05)
	start_velocity = (to - from) / duration + Vector3(0.0, 0.5 * gravity * duration, 0.0)
	time = 0.0
	velocity = start_velocity
	bounces = 0
	global_position = from
	var flat := Vector3(start_velocity.x, 0.0, start_velocity.z)
	_spin_axis = flat.cross(Vector3.UP).normalized() if flat.length() > 0.01 else Vector3.RIGHT
	_spin_speed = -flat.length() / maxf(radius, 0.01) * 0.35
	_update_shadow()


## Where the current arc has the ball `t` seconds after it was thrown.
func point_at(t: float) -> Vector3:
	return start + start_velocity * t + Vector3(0.0, -0.5 * gravity * t * t, 0.0)


## The arc's highest point (FLYING).
func apex() -> Vector3:
	var t: float = clampf(start_velocity.y / gravity, 0.0, duration)
	return point_at(t)


## Seconds until the ball reaches the end of its planned arc (`to` of throw_to).
func time_left() -> float:
	return duration - time


## The ball is out of play: it bounces on from where it is, with the velocity it has.
func dead() -> void:
	if mode == Mode.FLYING:
		mode = Mode.DEAD


## Bounces the ball off something (the runner's head): a new velocity, out of play.
func knock(new_velocity: Vector3) -> void:
	velocity = new_velocity
	mode = Mode.DEAD


func advance(delta: float) -> void:
	match mode:
		Mode.FLYING:
			time += delta
			var p: Vector3 = point_at(time)
			velocity = start_velocity + Vector3(0.0, -gravity * time, 0.0)
			if p.y <= radius and velocity.y < 0.0:
				p.y = radius
				global_position = p
				mode = Mode.DEAD
				_bounce()
				landed.emit(p)
			else:
				global_position = p
		Mode.DEAD:
			velocity.y -= gravity * delta
			var p: Vector3 = global_position + velocity * delta
			if p.y <= radius and velocity.y < 0.0:
				p.y = radius
				global_position = p
				_bounce()
			else:
				global_position = p
		Mode.RESTING:
			velocity = velocity.move_toward(Vector3.ZERO, 3.0 * delta)
			global_position += Vector3(velocity.x, 0.0, velocity.z) * delta
	if mode != Mode.HELD:
		var flat := Vector3(velocity.x, 0.0, velocity.z)
		if flat.length() > 0.05:
			_spin_axis = flat.cross(Vector3.UP).normalized()
			_spin_speed = -flat.length() / maxf(radius, 0.01)
		else:
			_spin_speed = move_toward(_spin_speed, 0.0, 8.0 * delta)
		_mesh.rotate(_spin_axis, _spin_speed * delta)
	_update_shadow()


func _bounce() -> void:
	bounces += 1
	velocity = Vector3(velocity.x * FRICTION, -velocity.y * RESTITUTION, velocity.z * FRICTION)
	if bounces >= MAX_BOUNCES or absf(velocity.y) < REST_SPEED:
		velocity.y = 0.0
		mode = Mode.RESTING


func _update_shadow() -> void:
	if _shadow == null or not is_inside_tree():
		return
	var p: Vector3 = global_position
	var height: float = maxf(p.y - radius, 0.0)
	var s: float = clampf(1.0 - height / 7.0, 0.35, 1.0)
	_shadow.global_position = Vector3(p.x, 0.02, p.z)
	_shadow.scale = Vector3(s, 1.0, s)
	_shadow.visible = visible
