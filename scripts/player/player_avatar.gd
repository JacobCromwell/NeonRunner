class_name PlayerAvatar
extends Node3D
## The player's runner model: a human in a cyber suit (GDD §11, look in PlayerSuit) on the shared
## HumanoidRig, animated procedurally from the Player's movement state. Visual only: it never affects
## movement or collision. Put it under the Player's pivot (which rolls onto walls and the ceiling);
## its feet are at the origin and it faces -z.
##
## API
##   animate(state: Dictionary, delta: float)
##       Call once per physics frame. State keys (all optional; missing = standing on the floor):
##         surface      "floor" | "ceiling" | "wall"; the pivot is already rolled for walls/ceiling
##         grounded     bool: on the floor or ceiling (false on a wall and in the air)
##         vh           float: velocity away from the surface, m/s (> 0 rising, < 0 falling)
##         sliding      bool
##         distance     float: metres run; drives the stride, so the legs keep pace with the ground
##         speed        float: m/s; below the animation tuning's idle_speed the runner stands idle
##         wall_side    int: -1 left wall, 1 right wall
##         switch_dir   int: -1 / 0 / 1 while a lane switch is in progress (world x direction)
##         alive        bool: false plays the collapse
##         dashing      bool: juggernaut-dash charge pose, brighter trim
##         just_landed  bool: touchdown this frame (landing squash)
##         stomping     bool: a slam down onto what is below (the air-slide fast fall uses it now)
##       If animate() stops being called (death, level complete, a menu), the avatar keeps animating
##       on its own from the last state with speed 0: the collapse finishes and a stopped runner
##       settles into idle.
##   set_equipment(eq: Dictionary)
##       claws: bool, armor: bool, shield: bool, weapon_tier: int 0–4, magnet: bool.
##       Missing keys keep their current value. The looks are DESIGN-TBD placeholders (PlayerSuit).
##   get_equipment() -> Dictionary
##   set_flash(on: bool)
##       The invulnerability flicker: the Player toggles it; while on, the whole suit is tinted bright.
##   fit_to(size: Vector3)
##       Scales the model to a visual size (MovementTuning.visual_size): width, height (feet to the
##       top of the helmet in the run pose), depth. Cheap to call every frame.
##   reset()
##       Back to the start-of-run look: no death, no flash; the next animate() snaps to its pose.
##   weapon_muzzle() -> Vector3
##       World position of the shoulder weapon's muzzle (shots start here).
##   rig: the HumanoidRig (joint(&"hand_r") etc. for attaching effects), anim_tuning: its tuning.

const ANIM_TUNING_PATH: String = "res://data/tuning/avatar_animation.tres"
# DESIGN-TBD: the invulnerability flash is a bright tint over the suit (not a blink on and off).
const FLASH_COLOR := Color(0.8, 0.97, 1.0)
const FLASH_STRENGTH: float = 0.55
# DESIGN-TBD: death feedback: a red flash (as the grey box turned red) that fades while the suit's
# glow powers down.
const DEATH_COLOR := Color(1.0, 0.15, 0.1)
const DEATH_FLASH_TIME: float = 0.6
const DEAD_GLOW: float = 0.2
const DASH_GLOW: float = 1.8
const GLOW_SPEED: float = 10.0
## Shield bubble radii and centre height, per metre of visual height; standing and sliding.
const SHIELD_RADII := Vector3(0.4, 0.53, 0.4)
const SHIELD_RADII_SLIDE := Vector3(0.48, 0.34, 0.62)
const SHIELD_CENTER: float = 0.51
const SHIELD_CENTER_SLIDE: float = 0.27

## Where the shoulder weapon's emitter sits, in the chest joint's space (see PlayerSuit._weapon).
const WEAPON_MUZZLE := Vector3(0.2, 0.33, -0.18)

var rig: HumanoidRig
var anim_tuning: HumanoidAnimTuning

var _material: ShaderMaterial
var _shield: MeshInstance3D
var _equipment: Dictionary = {"claws": false, "armor": false, "shield": false, "weapon_tier": 0, "magnet": false}
var _size := Vector3.ZERO
var _last_state: Dictionary = {}
var _unfed_ticks: int = 0
var _flash: bool = false
var _glow: float = 1.0
var _death_flash: float = 0.0
var _was_alive: bool = true


func _init() -> void:
	name = "Avatar"
	anim_tuning = load(ANIM_TUNING_PATH) as HumanoidAnimTuning
	if anim_tuning == null:
		anim_tuning = HumanoidAnimTuning.new()
	_material = PlayerSuit.body_material().duplicate() as ShaderMaterial
	rig = HumanoidRig.new()
	rig.name = "Rig"
	add_child(rig)
	rig.build(PlayerSuit.parts(), _material, anim_tuning)
	_shield = MeshInstance3D.new()
	_shield.name = "Shield"
	_shield.mesh = PlayerSuit.shield_mesh()
	_shield.material_override = PlayerSuit.shield_material()
	_shield.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shield.visible = false
	add_child(_shield)
	fit_to(PlayerSuit.parts().design_size)
	rig.animate({}, 0.0)  # Stand idle until driven, never in the raw rest pose.
	reset()


func animate(state: Dictionary, delta: float) -> void:
	_unfed_ticks = 0
	_last_state = state
	_step(state, delta)


func set_equipment(eq: Dictionary) -> void:
	for key: String in eq:
		if _equipment.has(key):
			_equipment[key] = int(eq[key]) if key == "weapon_tier" else bool(eq[key])
	var names: Array[StringName] = []
	if _equipment["claws"]:
		names.append(&"claws")
	if _equipment["armor"]:
		names.append(&"armor")
	var tier: int = clampi(int(_equipment["weapon_tier"]), 0, 4)
	if tier > 0:
		names.append(StringName("weapon_%d" % tier))
	if _equipment["magnet"]:
		names.append(&"magnet")
	rig.set_attachments(names)
	_shield.visible = bool(_equipment["shield"])
	_update_shield()


func get_equipment() -> Dictionary:
	return _equipment.duplicate()


func set_flash(on: bool) -> void:
	if on == _flash:
		return
	_flash = on
	_update_material()


func fit_to(size: Vector3) -> void:
	if size == _size or size.x <= 0.0 or size.y <= 0.0 or size.z <= 0.0:
		return
	_size = size
	var design: Vector3 = rig.parts.design_size
	rig.scale = Vector3(size.x / design.x, size.y / design.y, size.z / design.z)
	_update_shield()


## World position of the shoulder weapon's muzzle, following the pose, the size fit and the roll
## onto walls and the ceiling. The weapon power-up fires from here.
func weapon_muzzle() -> Vector3:
	return rig.joint(&"chest").global_transform * WEAPON_MUZZLE


func reset() -> void:
	rig.reset_pose()
	_flash = false
	_glow = 1.0
	_death_flash = 0.0
	_was_alive = true
	_last_state = {}
	_unfed_ticks = 0
	_update_material()


## Triangles currently drawn (body, equipment and the shield bubble).
func triangle_count() -> int:
	var n: int = rig.triangle_count()
	if _shield.visible:
		n += int(_shield.mesh.get_meta(&"triangles", 0))
	return n


func draw_call_count() -> int:
	return rig.draw_call_count() + (1 if _shield.visible else 0)


func _physics_process(delta: float) -> void:
	_unfed_ticks += 1
	if _unfed_ticks < 2:
		return
	# Nobody is driving the avatar (death, level complete, menu): carry on from the last state.
	var state: Dictionary = _last_state.duplicate()
	state["speed"] = 0.0
	state["switch_dir"] = 0
	state["dashing"] = false
	state["stomping"] = false
	state["just_landed"] = false
	_step(state, delta)


func _step(state: Dictionary, delta: float) -> void:
	rig.animate(state, delta)
	var alive: bool = bool(state.get("alive", true))
	if _was_alive and not alive:
		_death_flash = 1.0
	_was_alive = alive
	_death_flash = maxf(0.0, _death_flash - delta / DEATH_FLASH_TIME)
	var target: float = DEAD_GLOW if not alive else (DASH_GLOW if bool(state.get("dashing", false)) else 1.0)
	_glow = lerpf(_glow, target, 1.0 - exp(-GLOW_SPEED * delta))
	_update_material()
	if _shield.visible:
		_update_shield()


func _update_material() -> void:
	_material.set_shader_parameter(&"glow_boost", _glow)
	var tint := Color(1.0, 1.0, 1.0, 0.0)
	if _death_flash > 0.0:
		tint = Color(DEATH_COLOR, 0.7 * _death_flash)
	elif _flash:
		tint = Color(FLASH_COLOR, FLASH_STRENGTH)
	_material.set_shader_parameter(&"tint", tint)


## The bubble hugs the body: tall while running, low and long while sliding.
func _update_shield() -> void:
	if _size == Vector3.ZERO:
		return
	var slide: float = rig.weight(HumanoidRig.Activity.SLIDE)
	var radii: Vector3 = SHIELD_RADII.lerp(SHIELD_RADII_SLIDE, slide) * _size.y
	_shield.scale = radii
	_shield.position = Vector3(0.0, lerpf(SHIELD_CENTER, SHIELD_CENTER_SLIDE, slide) * _size.y, 0.0)
