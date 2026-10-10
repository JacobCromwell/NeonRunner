class_name PlayerAvatar
extends Node3D
## The player's runner model: Razor Echo (GDD §11, look in PlayerSuit) on the shared HumanoidRig,
## animated procedurally from the Player's movement state; the rig also swings the coat's skirt
## panels. Visual only: it never affects movement or collision. Put it under the Player's pivot
## (which rolls onto walls and the ceiling); its feet are at the origin and it faces -z.
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
##       Armor switched off while running (it broke) shatters: its plates burst off in shards.
##   get_equipment() -> Dictionary
##   set_flash(on: bool)
##       The invulnerability flicker: the Player toggles it; while on, the whole body is tinted a
##       bright pale copper.
##   set_dark_glow(amount: float)
##       0–1: how far the runner glows by its own light in the dark (a boss's lights out: the Sleep
##       Taker's). Its pale rim light grows from the outline to the whole silhouette (DARK_RIM_STRENGTH,
##       DARK_RIM_POWER), so a runner on an unlit street still sees where they are; the copper trim keeps
##       its glow. 0 (the default, and after reset()) is the normal look.
##   fit_to(size: Vector3)
##       Scales the model to a visual size (MovementTuning.visual_size): width, height (feet to the
##       tips of the hair in the run pose), depth. Cheap to call every frame.
##   reset()
##       Back to the start-of-run look: no death, no flash; the next animate() snaps to its pose.
##   weapon_muzzle() -> Vector3
##       World position of the shoulder weapon's muzzle (shots start here): over the gold left arm.
##   rig: the HumanoidRig (joint(&"hand_r") etc. for attaching effects), anim_tuning: its tuning.

const ANIM_TUNING_PATH: String = "res://data/tuning/avatar_animation.tres"
# The invulnerability flash is a bright tint over the body (not a blink on and off), in
# a pale copper white so it belongs to the player's glow (FB 36).
const FLASH_COLOR := Color(1.0, 0.88, 0.77)
const FLASH_STRENGTH: float = 0.55
# Death feedback: a red flash (as the grey box turned red) that fades while the copper
# conduits and the implant power down and go dark (FB 37).
const DEATH_COLOR := Color(1.0, 0.15, 0.1)
const DEATH_FLASH_TIME: float = 0.6
const DEAD_GLOW: float = 0.06
## While dashing the copper brightens, but stays soft (no gap-edge orange under bloom).
const DASH_GLOW: float = 1.35
const GLOW_SPEED: float = 10.0
## At full dark glow (set_dark_glow(1)): the rim light's strength and falloff (PlayerSuit.RIM_STRENGTH
## and RIM_POWER normally). Broad and strong enough to show the whole silhouette on a black street, in
## the rim's pale steel blue (clear of every hazard colour), and still below the bloom threshold
## (DESIGN-TBD, docs/questions/h11.md).
const DARK_RIM_STRENGTH: float = 1.1
const DARK_RIM_POWER: float = 1.4
## Shield bubble radii and centre height, per metre of visual height; standing and sliding.
const SHIELD_RADII := Vector3(0.4, 0.53, 0.4)
const SHIELD_RADII_SLIDE := Vector3(0.48, 0.34, 0.62)
const SHIELD_CENTER: float = 0.51
const SHIELD_CENTER_SLIDE: float = 0.27
## The armor's shards (metres, seconds): how many, how long they fly, where they burst from (per
## metre of visual height: the shoulders and chest).
const SHARD_COUNT: int = 18
const SHARD_LIFETIME: float = 0.75
const SHARD_ORIGIN: float = 0.74

## Where the shoulder weapon's emitter sits, in the chest joint's space (see PlayerSuit._weapon).
const WEAPON_MUZZLE := PlayerSuit.WEAPON_MUZZLE

var rig: HumanoidRig
var anim_tuning: HumanoidAnimTuning

var _material: ShaderMaterial
var _shield: MeshInstance3D
var _shards: CPUParticles3D
var _equipment: Dictionary = {"claws": false, "armor": false, "shield": false, "weapon_tier": 0, "magnet": false}
var _size := Vector3.ZERO
var _last_state: Dictionary = {}
var _unfed_ticks: int = 0
var _flash: bool = false
var _glow: float = 1.0
var _dark_glow: float = 0.0
var _death_flash: float = 0.0
var _was_alive: bool = true
## True from reset() until the next animate(): equipment set then is the run's loadout, not a break.
var _fresh: bool = true


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
	_build_shards()
	fit_to(PlayerSuit.parts().design_size)
	rig.animate({}, 0.0)  # Stand idle until driven, never in the raw rest pose.
	reset()


func animate(state: Dictionary, delta: float) -> void:
	_unfed_ticks = 0
	_last_state = state
	_fresh = false
	_step(state, delta)


func set_equipment(eq: Dictionary) -> void:
	var had_armor: bool = _equipment["armor"]
	for key: String in eq:
		if _equipment.has(key):
			_equipment[key] = int(eq[key]) if key == "weapon_tier" else bool(eq[key])
	if had_armor and not _equipment["armor"] and not _fresh:
		_shatter()
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


func set_dark_glow(amount: float) -> void:
	amount = clampf(amount, 0.0, 1.0)
	if is_equal_approx(amount, _dark_glow):
		return
	_dark_glow = amount
	_update_material()


func get_dark_glow() -> float:
	return _dark_glow


func fit_to(size: Vector3) -> void:
	if size == _size or size.x <= 0.0 or size.y <= 0.0 or size.z <= 0.0:
		return
	_size = size
	var design: Vector3 = rig.parts.design_size
	rig.scale = Vector3(size.x / design.x, size.y / design.y, size.z / design.z)
	_update_shield()
	_shards.position = Vector3(0.0, SHARD_ORIGIN * size.y, 0.0)
	_shards.emission_box_extents = Vector3(0.27, 0.07, 0.07) * size.y
	(_shards.mesh as BoxMesh).size = Vector3(0.085, 0.06, 0.012) * size.y


## World position of the shoulder weapon's muzzle, following the pose, the size fit and the roll
## onto walls and the ceiling. The weapon power-up fires from here.
func weapon_muzzle() -> Vector3:
	return rig.joint(&"chest").global_transform * WEAPON_MUZZLE


func reset() -> void:
	rig.reset_pose()
	_flash = false
	_glow = 1.0
	_dark_glow = 0.0
	_death_flash = 0.0
	_was_alive = true
	_last_state = {}
	_unfed_ticks = 0
	_fresh = true
	_shards.visible = false
	_shards.emitting = false
	_update_material()


## Triangles currently drawn (body, coat panels, equipment, the shield bubble, flying shards).
func triangle_count() -> int:
	var n: int = rig.triangle_count()
	if _shield.visible:
		n += int(_shield.mesh.get_meta(&"triangles", 0))
	if shattering():
		n += 12 * SHARD_COUNT
	return n


func draw_call_count() -> int:
	return rig.draw_call_count() + (1 if _shield.visible else 0) + (1 if shattering() else 0)


## True while the broken armor's shards are flying.
func shattering() -> bool:
	return _shards.visible and _shards.emitting


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
	# The dark glow powers down with the trim on death (DEAD_GLOW), and doesn't brighten with the dash.
	var dark: float = _dark_glow * minf(_glow, 1.0)
	_material.set_shader_parameter(&"rim_strength", lerpf(PlayerSuit.RIM_STRENGTH, DARK_RIM_STRENGTH, dark))
	_material.set_shader_parameter(&"rim_power", lerpf(PlayerSuit.RIM_POWER, DARK_RIM_POWER, dark))
	var tint := Color(1.0, 1.0, 1.0, 0.0)
	if _death_flash > 0.0:
		tint = Color(DEATH_COLOR, 0.7 * _death_flash)
	elif _flash:
		tint = Color(FLASH_COLOR, FLASH_STRENGTH)
	_material.set_shader_parameter(&"tint", tint)


## The broken armor bursts off the shoulders and chest in steel shards that tumble away and fade.
## Nothing flashes, so Reduced flashing has nothing to calm here.
func _shatter() -> void:
	_shards.visible = true
	_shards.restart()


func _build_shards() -> void:
	var shard := BoxMesh.new()
	shard.size = Vector3(0.085, 0.06, 0.012)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.35
	material.metallic = 0.4
	material.emission_enabled = true
	material.emission = PlayerSuit.ARMOR_EDGE * 0.35
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.7, 1.0])
	fade.colors = PackedColorArray([Color(1.0, 1.0, 1.0, 1.0), Color(1.0, 1.0, 1.0, 0.9), Color(1.0, 1.0, 1.0, 0.0)])
	_shards = CPUParticles3D.new()
	_shards.name = "ArmorShards"
	_shards.mesh = shard
	_shards.material_override = material
	_shards.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shards.amount = SHARD_COUNT
	_shards.lifetime = SHARD_LIFETIME
	_shards.one_shot = true
	_shards.explosiveness = 1.0
	_shards.local_coords = true
	_shards.emitting = false
	_shards.visible = false
	_shards.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	# Up and out, drifting back in the wind of the run, then falling toward the feet.
	_shards.direction = Vector3(0.0, 1.0, 0.45)
	_shards.spread = 70.0
	_shards.initial_velocity_min = 2.2
	_shards.initial_velocity_max = 4.0
	_shards.gravity = Vector3(0.0, -9.8, 0.0)
	_shards.particle_flag_rotate_y = true
	_shards.angle_min = -180.0
	_shards.angle_max = 180.0
	_shards.angular_velocity_min = -540.0
	_shards.angular_velocity_max = 540.0
	_shards.scale_amount_min = 0.6
	_shards.scale_amount_max = 1.2
	_shards.color = PlayerSuit.ARMOR
	_shards.color_ramp = fade
	add_child(_shards)


## The bubble hugs the body: tall while running, low and long while sliding.
func _update_shield() -> void:
	if _size == Vector3.ZERO:
		return
	var slide: float = rig.weight(HumanoidRig.Activity.SLIDE)
	var radii: Vector3 = SHIELD_RADII.lerp(SHIELD_RADII_SLIDE, slide) * _size.y
	_shield.scale = radii
	_shield.position = Vector3(0.0, lerpf(SHIELD_CENTER, SHIELD_CENTER_SLIDE, slide) * _size.y, 0.0)
