class_name HostileTakeoverGunship
extends BossPart
## Hostile Takeover's body (GDD §10: "a military gunship paces the train overhead"): the boss's health is
## the fight's (BossPart), so weapon hits on it chip the boss up to BossDef.weapon_share_cap ("weapons chip;
## stomps do the real damage": in phase 1 the stomps are the couplings', HostileTakeoverCouplings; in
## phase 2 its drop bay's). Its model (HostileTakeoverModel.gunship) is built to the lanes' width, its
## belly as wide as the lanes, so it fits between the sound barriers when it comes down.
## The encounter flies it (set_pose: relative to the runner, so nothing depends on how long the fight has
## lasted; phase 2's moves are HostileTakeoverContract's). In phase 1 it flies far over the roofs. Phase 2
## (The Contract):
## - its belly is a ceiling (add_surface(..., true): the hull layer, flush from BELLY_STERN to BELLY_FRONT),
##   which the runner rides over the armored carriage when it comes down to the ceiling's height;
## - it carries a Buzz Overdrive under its drop bay (the C2 tank's own model, built once: set_saw) and
##   drops it (the contract lets the model fall and brings the real one into play where it lands);
## - its drop bay opens during the ride (set_bay): the bay glowing the weak points' red, the green
##   chevrons before it on the belly, and its weak point (bay_point: a stomp from the ceiling, its hitbox
##   hanging below the belly, upside_down) live while the runner rides under it (the contract switches it);
## - its chin turret's muzzle flashes while a strafe rakes (set_firing; steady with Reduced flashing).
## Phase 3 (task E5b-c) docks it onto the locomotive.
## Declared, never special-cased (CLAUDE.md principle 8): a boss's part, claw-immune, the dash passes it.

## Its chin turret's muzzle (own space): where its strafes' tracers start.
const MUZZLE := Vector3(0.0, 0.15, -14.6)

var tuning: HostileTakeoverTuning
var model: MeshInstance3D
var belly_width: float = 8.0
var belly: StaticBody3D
var bay_point: Hazard
var bay_mesh: MeshInstance3D
var cue_mesh: MeshInstance3D
var saw_model: BuzzOverdriveModel
## The Buzz Overdrive it lets fall (a model of its own, top level: it falls straight down on its spot
## while the gunship flies on), shown only while it falls.
var fall_model: BuzzOverdriveModel
var muzzle: MeshInstance3D
var bay_open: bool = false
var saw_loaded: bool = false
var firing: bool = false
var _t: float = 0.0


func _build() -> void:
	var params: Dictionary = spawn.get("params", {})
	tuning = params.get("tuning") as HostileTakeoverTuning
	if tuning == null:
		tuning = HostileTakeoverTuning.new()
	belly_width = world.geo.half_width() * 2.0
	model = MeshBatch.add_instance(self, HostileTakeoverModel.gunship(belly_width, world.skin), "Model")
	var belly_length: float = HostileTakeoverModel.BELLY_STERN + HostileTakeoverModel.BELLY_FRONT
	belly = add_surface(Vector3(belly_width, 0.3, belly_length),
		Vector3(0.0, 0.15, (HostileTakeoverModel.BELLY_STERN - HostileTakeoverModel.BELLY_FRONT) * 0.5), true)
	bay_point = add_weak_point(Vector3(belly_width - 0.4, tuning.bay_depth, tuning.bay_length),
		Vector3(0.0, -tuning.bay_depth * 0.5, -HostileTakeoverModel.BAY_AHEAD))
	bay_point.upside_down = true
	bay_point.hazard_name = "the gunship's drop bay"
	set_weak_points_enabled(false)
	bay_mesh = MeshInstance3D.new()
	bay_mesh.name = "Bay"
	bay_mesh.mesh = HostileTakeoverModel.bay_open(belly_width, tuning.bay_depth)
	bay_mesh.material_override = _bay_material()
	bay_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bay_mesh)
	var skin: ZoneSkin = world.skin
	var cue_color: Color = skin.get("ramp_color") if skin != null and skin.get("ramp_color") is Color else Color(0.3, 1.0, 0.35)
	var bay_stern: float = -HostileTakeoverModel.BAY_AHEAD + HostileTakeoverModel.BAY_HALF
	cue_mesh = MeshInstance3D.new()
	cue_mesh.name = "BayCue"
	cue_mesh.mesh = HostileTakeoverModel.belly_cue(belly_width - 1.2, bay_stern + 0.2, bay_stern + 0.2 + cue_length(), cue_color, skin)
	cue_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(cue_mesh)
	var saw_tuning := EnemyDirector.tuning_for("buzz_overdrive") as BuzzOverdriveTuning
	if saw_tuning == null:
		saw_tuning = BuzzOverdriveTuning.new()
	saw_model = BuzzOverdriveModel.new()
	saw_model.name = "Saw"
	add_child(saw_model)
	saw_model.build(skin.enemy_variant if skin != null else &"city", saw_tuning.body_size, saw_tuning.blade_radius)
	saw_model.position = Vector3(0.0, -HostileTakeoverModel.SAW_HANG, -HostileTakeoverModel.BAY_AHEAD)
	fall_model = BuzzOverdriveModel.new()
	fall_model.name = "FallingSaw"
	fall_model.top_level = true
	add_child(fall_model)
	fall_model.build(skin.enemy_variant if skin != null else &"city", saw_tuning.body_size, saw_tuning.blade_radius)
	fall_model.visible = false
	muzzle = MeshInstance3D.new()
	muzzle.name = "Muzzle"
	muzzle.mesh = GreyboxMaterials.unit_box()
	muzzle.material_override = GreyboxMaterials.glow(HostileTakeoverStrafes.TRACER_COLOR, 4.0, 0.9)
	muzzle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	muzzle.position = MUZZLE
	add_child(muzzle)
	set_bay(false)
	set_saw(false)
	set_firing(false)


## How far before its bay along the belly the take-off cue runs (metres): a jump from the belly comes back
## up this far further on, at the ride's relative speed (HostileTakeoverContract), so the cue ends where
## a jump lands on the bay's near edge. DESIGN-TBD (docs/questions/e5b.md): fixed for the placeholder ride.
func cue_length() -> float:
	return 2.6


## Flies it with its belly's middle at `pos` (world space), banked by `roll` and pitched by `pitch`
## (radians; its nose ahead, -z).
func set_pose(pos: Vector3, roll: float, pitch: float) -> void:
	global_transform = Transform3D(Basis.from_euler(Vector3(pitch, 0.0, roll)), pos)


## Opens or shuts its drop bay (the open bay glowing red and the cue before it; the weak point is the
## contract's to switch).
func set_bay(open: bool) -> void:
	bay_open = open
	bay_mesh.visible = open
	cue_mesh.visible = open
	if not open:
		set_weak_points_enabled(false)


## Shows the Buzz Overdrive it carries under its bay, or not.
func set_saw(loaded: bool) -> void:
	saw_loaded = loaded
	saw_model.visible = loaded


## Where the Buzz Overdrive it carries hangs (its blade's foot), in world space.
func saw_world() -> Vector3:
	return global_transform * saw_model.position


## The Buzz Overdrive it let go, falling: its blade's foot at `at` (world space).
func set_fall(at: Vector3) -> void:
	fall_model.visible = true
	fall_model.global_transform = Transform3D(Basis.IDENTITY, at)


## It has landed (the real one takes its place).
func end_fall() -> void:
	fall_model.visible = false


## Where its strafes' tracers leave its guns, in world space.
func gun_point() -> Vector3:
	return global_transform * MUZZLE


func set_firing(on: bool) -> void:
	firing = on
	muzzle.visible = on


## The track stretch its bay's weak point covers now (Vector2(near, far) track distances).
func bay_span() -> Vector2:
	var mid: float = track_distance() + HostileTakeoverModel.BAY_AHEAD
	return Vector2(mid - tuning.bay_length * 0.5, mid + tuning.bay_length * 0.5)


## Weapons aim at its hull's middle.
func aim_point() -> Vector3:
	return global_transform * Vector3(0.0, 0.9 + HostileTakeoverModel.GUNSHIP_HULL_HEIGHT * 0.5, 2.0)


## Its hull is big: a shot within this of its middle hits it.
func hit_radius() -> float:
	return 4.5


## Where it is along the track (its middle).
func track_distance() -> float:
	return -global_position.z


func _tick(delta: float) -> void:
	_t += delta
	if firing:
		# The muzzle flash: flickering, steady with Reduced flashing.
		var k: float = 1.0 if Settings.flashing_reduced else 0.6 + 0.6 * absf(sin(_t * 53.0))
		muzzle.scale = Vector3(0.7, 0.7, 1.4) * k
	if bay_open:
		var beat: float = 1.0 if Settings.flashing_reduced else 1.0 + 0.25 * sin(_t * TAU * 1.4)
		(bay_mesh.material_override as ShaderMaterial).set_shader_parameter(&"state_glow", beat)


## The bay's glow material: the kit's, with its pulse (the weak points' language).
func _bay_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = MeshKit.shader("kit_solid.gdshader")
	m.set_shader_parameter(&"glow_scale", 4.0)
	m.set_shader_parameter(&"state_glow", 1.0)
	return m


## The fight is won: the encounter plays the defeat (a placeholder until task E5b-c: it climbs away), so
## it stays.
func _on_defeated(_cause: StringName) -> void:
	pass
