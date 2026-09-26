class_name EnemyHealthBars
extends Node3D
## Health bars over damaged enemies (GDD §8: with the weapon, enemies show health bars). One look in
## every zone, like the hazard language: a light frame, a dark back, a white "recent damage" segment
## that drains after each hit, and the health fill (amber, turning red as it runs low).
##
## Cheap and Compatibility-safe: every bar is four unshaded quads in one MultiMesh (one draw call),
## turned to face the camera on the CPU and drawn over the scene so they stay readable. A bar shows
## only while its enemy is alive, in play and damaged; never on hosts or weapon-immune enemies,
## which the weapon can't target (GDD §9.7).

const MAX_BARS: int = 16
const QUADS_PER_BAR: int = 4
const FRAME_COLOR := Color(0.92, 0.95, 1.0, 0.9)
const BACK_COLOR := Color(0.03, 0.03, 0.07, 0.9)
const DRAIN_COLOR := Color(1.0, 1.0, 1.0, 0.95)
const FULL_COLOR := Color(1.0, 0.78, 0.18)
const LOW_COLOR := Color(1.0, 0.16, 0.12)
## Bar width grows with distance so far bars stay readable: metres per metre of camera distance,
## clamped to [MIN_WIDTH, MAX_WIDTH].
const WIDTH_PER_METRE: float = 0.03
const MIN_WIDTH: float = 0.8
const MAX_WIDTH: float = 2.6
const HEIGHT_RATIO: float = 0.14
## Seconds the recent-damage segment waits before draining, and its drain speed (share per second).
const DRAIN_DELAY: float = 0.25
const DRAIN_SPEED: float = 1.4

var world: RunWorld

var _mm: MultiMesh
var _instance: MultiMeshInstance3D
var _shown: Array[Enemy] = []
## Enemy instance id -> {drain: float (shown share of the recent-damage segment), hold: float, last: float}.
var _state: Dictionary = {}


func setup(p_world: RunWorld) -> void:
	world = p_world
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = true
	_mm.mesh = quad
	_mm.instance_count = MAX_BARS * QUADS_PER_BAR
	_mm.visible_instance_count = 0
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.render_priority = 20
	_instance = MultiMeshInstance3D.new()
	_instance.multimesh = _mm
	_instance.material_override = mat
	_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_instance)


## Enemies showing a bar right now.
func shown() -> Array[Enemy]:
	return _shown.duplicate()


func is_shown(enemy: Enemy) -> bool:
	return _shown.has(enemy)


## Whether `enemy` should show a bar: alive, in play, damaged, and something the weapon can hit.
static func wants_bar(enemy: Enemy) -> bool:
	return is_instance_valid(enemy) and enemy.alive and enemy.is_inside_tree() and not enemy.is_host \
		and not enemy.immune_to_weapons and enemy.health < enemy.max_health - 0.0001


## Rebuilds the bars for this frame (the weapon calls it every rendered frame).
func update_bars(delta: float) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	var eye: Vector3 = camera.global_position if camera != null else world.player.global_position
	_shown.clear()
	# The director drops freed enemies on its next physics update; until then the list may hold some.
	for e: Enemy in world.director.active:
		if is_instance_valid(e) and wants_bar(e):
			_shown.append(e)
	if _shown.size() > MAX_BARS:
		_shown.sort_custom(func(a: Enemy, b: Enemy) -> bool:
			return a.aim_point().distance_squared_to(eye) < b.aim_point().distance_squared_to(eye))
		_shown.resize(MAX_BARS)
	var right: Vector3 = camera.global_basis.x if camera != null else Vector3.RIGHT
	var up: Vector3 = camera.global_basis.y if camera != null else Vector3.UP
	var facing: Vector3 = camera.global_basis.z if camera != null else Vector3.BACK
	var live: Dictionary = {}
	for i: int in _shown.size():
		var e: Enemy = _shown[i]
		var ratio: float = e.health_ratio()
		var drain: float = _drain_share(e.get_instance_id(), ratio, delta)
		live[e.get_instance_id()] = true
		var top: Vector3 = e.aim_point() + Vector3.UP * (e.hit_radius() + 0.35)
		var width: float = clampf(eye.distance_to(top) * WIDTH_PER_METRE, MIN_WIDTH, MAX_WIDTH)
		var height: float = width * HEIGHT_RATIO
		var center: Vector3 = top + Vector3.UP * height
		var pad: float = height * 0.2
		var base: int = i * QUADS_PER_BAR
		_set_quad(base, center, right, up, facing, width + pad * 2.0, height + pad * 2.0, FRAME_COLOR)
		_set_quad(base + 1, center, right, up, facing, width, height, BACK_COLOR)
		_set_quad(base + 2, center - right * (width * (1.0 - drain) * 0.5), right, up, facing,
			width * drain, height, DRAIN_COLOR)
		_set_quad(base + 3, center - right * (width * (1.0 - ratio) * 0.5), right, up, facing,
			width * ratio, height, LOW_COLOR.lerp(FULL_COLOR, ratio))
	_mm.visible_instance_count = _shown.size() * QUADS_PER_BAR
	if _state.size() != live.size():
		for key: Variant in _state.keys():
			if not live.has(key):
				_state.erase(key)


## The recent-damage segment: jumps to the old health on a hit, holds briefly, then drains down to
## the current health.
func _drain_share(key: int, ratio: float, delta: float) -> float:
	var s: Dictionary = _state.get(key, {"drain": 1.0, "hold": DRAIN_DELAY, "last": 1.0})
	if ratio < float(s["last"]) - 0.0001:
		s["hold"] = DRAIN_DELAY
	s["last"] = ratio
	if float(s["hold"]) > 0.0:
		s["hold"] = float(s["hold"]) - delta
	else:
		s["drain"] = move_toward(float(s["drain"]), ratio, DRAIN_SPEED * delta)
	s["drain"] = maxf(float(s["drain"]), ratio)
	_state[key] = s
	return float(s["drain"])


func _set_quad(index: int, center: Vector3, right: Vector3, up: Vector3, facing: Vector3, width: float,
		height: float, color: Color) -> void:
	_mm.set_instance_transform(index, Transform3D(Basis(right * maxf(width, 0.0001), up * height, facing), center))
	_mm.set_instance_color(index, color)
