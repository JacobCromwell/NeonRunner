extends RefCounted
## The Neon City's loading card (Zone 1; the owner's brief, October 11, 2026): "our player character running with
## an explosion behind him with cyborgs on the sides, an enforcer truck in the background, and the heli drone
## flying overhead. The background should be the zone in question, aka the cyberpunk zone." Staged like a movie
## poster, with the game's own pieces and nothing else (loading_card_gen.gd renders it):
## - the street is the City's own (CitySkin through CineStage and the track builder: truck-roof floor, tower
##   facades, neon, the moon and skyline of its sky and fog), seen down its length;
## - the runner (PlayerAvatar, Razor Echo) is the hero in the middle, caught mid-stride (a high kick, the gold arm
##   pumping), running at the camera and a little across it, so the stride shows from three-quarters;
## - a cyborg (CyborgBody, the City's Static TV Head look) on each side near the camera, arm cannons trained on
##   the runner (the cannons' charge glow, which is the cyborgs' own look), and a second pair further back;
## - the Enforcer Truck (EnforcerTruckModel) in the background, nose to the camera, its light bar lit and three
##   cyborg gunners riding its roof;
## - the heli drone (Drone.add_model) hovering over the runner, turned and tipped down at them, its rotors spinning;
## - the shared fireball (FireballPool, the explosion of every blast in the game) going up in the street behind
##   them all, caught as its fire turns from yellow to orange and red, with its smoke over the City's moon.
## The scene faces down the street as the run's camera does (towards -z), so the skin's skyline and moon sit
## where the City always shows them; the runner is turned round to run toward the camera.
##
## The fire lights the picture: the lit models (the people, the truck) take a warm kicker light and a point light,
## and the City's own scenery, which is unlit (kit shaders with a fake city light), takes additive washes in the fire's
## colours on the floor and the tower faces, the way the Enforcer Truck lights the floor with its headlights.
##
## Everything is posed by explicit steps (no engine clock), so the card is the same on every run. All the
## numbers that stage it are LOOK's (metres and degrees, in the card's frame: x right of the runner, y up,
## "behind" metres further from the camera than them); the generator's --tune=key:value,... overrides them for
## an experiment.

const TUNING_PATH: String = "res://data/tuning/movement.tres"
const SKIN_PATH: String = "res://data/skins/city_skin.tres"
const SPEED_FX_PATH: String = "res://data/tuning/speed_fx.tres"
const DRONE_TUNING_PATH: String = "res://data/enemies/drone.tres"
const TRUCK_TUNING_PATH: String = "res://data/enemies/enforcer_truck.tres"
const DroneScript := preload("res://scripts/enemies/drone.gd")
const Kit = preload("res://scripts/enemies/cyborg_kit.gd")

## The share of a fireball's radius where the body of its fire burns (its puffs and embers thin out past it): what the
## safe-zone check takes as the fire.
const FIRE_BULK: float = 0.6
## The fireball's random seed (the shape of its billows): another number, another burst.
const FIRE_SEED: int = 7
## The fire's colour on lit things (the kicker and the point light) and in the washes on the unlit street.
const FIRE_LIGHT := Color(1.0, 0.55, 0.2)
const FIRE_WASH := Color(1.0, 0.5, 0.14)

const LOOK: Dictionary = {
	# The street: lanes (the PC count) and the track distance the runner stands at (the stage's chunks are built
	# around it; the street's towers and signs change with it).
	"lanes": 5, "runner_at": 130.0,
	# The camera: where it stands (x, height, metres in front of the runner), what it looks at (x, height, metres
	# behind the runner), its field of view (vertical, degrees) and its roll (degrees).
	"cam_x": 0.0, "cam_y": 0.65, "cam_back": 4.4, "look_x": 0.0, "look_y": 0.7, "look_behind": 4.0, "fov": 36.0,
	"cam_roll": 0.0,
	# The runner: how many 60 Hz steps of its run the pose is caught at (at the run's speed a stride cycle takes
	# about 18: the step sets where in it the picture falls) and its turn from the camera (degrees).
	"run_steps": 88, "runner_yaw": -42.0,
	# The cyborgs, near and far on each side: x, how far behind the runner, and the arm cannon's charge glow.
	"cy0_x": -2.1, "cy0_behind": 2.2, "cy0_charge": 0.55, "cy1_x": 2.3, "cy1_behind": 2.9, "cy1_charge": 0.7,
	"cy2_x": -2.6, "cy2_behind": 7.0, "cy2_charge": 0.3, "cy3_x": 3.7, "cy3_behind": 10.0, "cy3_charge": 0.3,
	"cy_turn": 0.6,
	# The truck: x, how far behind the runner, its turn (degrees).
	"truck_x": 2.5, "truck_behind": 14.0, "truck_yaw": 0.0,
	# The drone: x, height, how far behind the runner, its tip toward the runner, its turn and its bank (degrees).
	"drone_x": -1.9, "drone_y": 3.1, "drone_behind": 9.0, "drone_tip": 20.0, "drone_yaw": 32.0, "drone_bank": 10.0,
	# The fireball: x, height, how far behind the runner, its radius, how far into its burn the picture catches it
	# (seconds of the game's fire), the glow of its fire and how many puffs of fire, embers and smoke it has (the
	# game's data/tuning/speed_fx.tres has 1.2, 22, 20 and 8).
	"fire_x": 0.0, "fire_y": 3.6, "fire_behind": 23.0, "fire_radius": 5.5, "fire_age": 0.32, "fire_glow": 0.8,
	"fire_puffs": 48, "fire_embers": 20, "fire_smoke": 8,
	# Lights: the street's sun (the stage's own is 0.7); the fire's kicker (energy, and its pitch above the
	# horizontal, degrees) and point light (energy, and how far in toward the camera from the fire it hangs); and the
	# washes on the unlit street: their strength, how far they reach along the street and up the towers, and how
	# much of that reach lies toward the camera from the fire.
	"sun": 0.8, "kicker": 1.4, "kicker_pitch": 25.0, "fire_light": 6.0, "fire_light_in": 4.0,
	"wash": 0.5, "wash_reach": 10.0, "wash_height": 22.0, "wash_toward": 0.6,
}

var _o: Dictionary = LOOK.duplicate()
var _stage: CineStage
var _tuning: MovementTuning
var _skin: ZoneSkin
var _root: Node3D
var _camera: Camera3D
## The runner's world position: the card's frame.
var _runner_at := Vector3.ZERO
## What the picture is about, for the safe-zone check: name -> Node3D, or a fireball's [center, radius] pair.
var _subjects: Dictionary = {}


func settle_frames() -> int:
	return 4


func camera() -> Camera3D:
	return _camera


## What the picture is about: name -> a Node3D (its meshes' bounds), or [world centre, radius] for the fireball.
func subjects() -> Dictionary:
	return _subjects


func compose(host: Node3D, ctx: Dictionary) -> void:
	_root = host
	var tune: Dictionary = ctx.get("tune", {})
	for key: String in tune:
		if _o.has(key):
			_o[key] = tune[key]
		else:
			push_error("city_card: no number called '%s' (known: %s)" % [key, ", ".join(_o.keys())])
	_tuning = load(TUNING_PATH) as MovementTuning
	_skin = load(SKIN_PATH) as ZoneSkin
	_build_street()
	_runner_at = _stage.point(Vector3(0.0, 0.0, n("runner_at")))
	_add_runner()
	for i: int in 4:
		_add_cyborg(i)
	_add_truck()
	_add_drone()
	_add_fire()
	_add_camera()


func n(key: String) -> float:
	return float(_o[key])


## Where a point of the card's frame is in the world.
func at(x: float, y: float, behind: float) -> Vector3:
	return _runner_at + Vector3(x, y, -behind)


func _build_street() -> void:
	var def := CineStageDef.new()
	def.lanes = int(n("lanes"))
	def.length = 600.0
	_stage = CineStage.new()
	_stage.name = "Stage"
	_root.add_child(_stage)
	_stage.build(def, _skin, _tuning, def.lanes)
	_stage.update(n("runner_at") - 20.0, 0.0)
	_stage.track.dress_all()
	(_stage.get_node("Sun") as DirectionalLight3D).light_energy = n("sun")


# --- The runner ---------------------------------------------------------------------------------

func _add_runner() -> void:
	var avatar := PlayerAvatar.new()
	avatar.fit_to(_tuning.visual_size)
	avatar.position = at(0.0, 0.0, 0.0)
	avatar.rotation.y = PI + deg_to_rad(n("runner_yaw"))  # The rig faces -z; the runner runs at the camera.
	_root.add_child(avatar)
	avatar.set_physics_process(false)
	# Stepped up to the pose in small strides, as a run would reach it, so every blended joint has settled.
	var speed: float = _tuning.run_speed
	var step: float = speed / 60.0
	var run: float = 0.0
	for i: int in int(n("run_steps")):
		run += step
		avatar.animate({"surface": "floor", "grounded": true, "speed": speed, "distance": run, "vh": 0.0}, 1.0 / 60.0)
	avatar.rig.update_panels(0.0)
	_subjects["runner"] = avatar


# --- The cyborgs --------------------------------------------------------------------------------

func _add_cyborg(index: int) -> void:
	var body := CyborgBody.new()
	body.name = "Cyborg%d" % index
	body.position = at(n("cy%d_x" % index), 0.0, n("cy%d_behind" % index))
	_root.add_child(body)
	body.set_process(false)
	body.build(_skin.enemy_variant, false, false, index + 3)
	body.twitches = false
	body.set_pose(CyborgBody.Pose.AIM)
	body.set_expression(Kit.Face.AIMING)
	body.set_charge(n("cy%d_charge" % index))
	# Turned in toward the runner (the body faces +z, the camera's way), arm cannon on them.
	var toward: Vector3 = at(0.0, 0.9, 0.0) - body.position
	body.rotation.y = atan2(toward.x, toward.z) * n("cy_turn")
	body.aim_at(at(0.0, 0.9, 0.0))
	body.snap()
	for i: int in 30:
		body.advance(1.0 / 30.0)
	_subjects["cyborg%d" % index] = body


# --- The Enforcer Truck -------------------------------------------------------------------------

func _add_truck() -> void:
	var tune := load(TRUCK_TUNING_PATH) as EnforcerTruckTuning
	var truck := EnforcerTruckModel.new()
	truck.name = "Truck"
	truck.position = at(n("truck_x"), 0.0, n("truck_behind"))
	truck.rotation.y = PI + deg_to_rad(n("truck_yaw"))  # Its front toward the camera: it chases the runner.
	_root.add_child(truck)
	truck.build(_skin.enemy_variant, tune.body_size if tune != null else Vector3(2.2, 2.4, 6.4))
	truck.set_riders(3)
	truck.set_flash(-1, true)
	_subjects["truck"] = truck


# --- The heli drone -----------------------------------------------------------------------------

func _add_drone() -> void:
	var tune := load(DRONE_TUNING_PATH) as DroneTuning
	var drone := Node3D.new()
	drone.name = "Drone"
	drone.position = at(n("drone_x"), n("drone_y"), n("drone_behind"))
	# It faces +z (toward what it hovers ahead of): the camera's way, tipped forward at the runner and banked.
	drone.rotation = Vector3(deg_to_rad(n("drone_tip")), deg_to_rad(n("drone_yaw")), deg_to_rad(n("drone_bank")))
	_root.add_child(drone)
	var parts: Dictionary = DroneScript.add_model(drone, _skin.enemy_variant, tune.model_scale if tune != null else 1.35)
	var rotors: Array = parts["rotors"]
	for i: int in rotors.size():
		(rotors[i] as MeshInstance3D).rotation.y = 0.5 + 0.9 * i
	_subjects["drone"] = drone


# --- The explosion ------------------------------------------------------------------------------

func _add_fire() -> void:
	var fx: SpeedFxTuning = load(SPEED_FX_PATH) as SpeedFxTuning
	var own: SpeedFxTuning = fx.duplicate() as SpeedFxTuning if fx != null else SpeedFxTuning.new()
	own.fireball_pool = 1
	own.fireball_glow = n("fire_glow")
	own.fireball_puffs = int(n("fire_puffs"))
	own.fireball_embers = int(n("fire_embers"))
	own.fireball_smoke_puffs = int(n("fire_smoke"))
	var pool := FireballPool.new()
	pool.name = "Fireball"
	_root.add_child(pool)
	pool.setup(own)
	# Seeded, so the same burst every time; aged by hand to the moment the picture wants (the engine's clock is
	# stopped, so nothing else would age it): each emitter simulates that many seconds at once on the first frame.
	for slot: FireballPool.Slot in pool.slots:
		for p: CPUParticles3D in [slot.fire, slot.core, slot.embers, slot.smoke]:
			p.use_fixed_seed = true
			p.seed = FIRE_SEED
	var center: Vector3 = at(n("fire_x"), n("fire_y"), n("fire_behind"))
	pool.play(center, n("fire_radius"), true)
	for p: CPUParticles3D in [pool.latest.fire, pool.latest.core, pool.latest.embers, pool.latest.smoke]:
		p.request_particles_process(n("fire_age"))
	_subjects["fire"] = [center, pool.latest.size * FIRE_BULK]
	_add_fire_light(center)


## The fireball's glow. The people and the truck are lit (the humanoid body shader, the truck's materials), so the
## fire lights them for real: a warm kicker from behind and above them, which rims their outlines, and a point light
## over the street. The City's scenery is not (its kit shaders are unshaded, with a fake city light), so there the
## glow is what the game does for the Enforcer Truck's headlights and light bar (EnforcerTruckModel.floor_lights):
## additive washes laid on the floor and on the two tower faces, soft ovals of the fire's own colours.
func _add_fire_light(center: Vector3) -> void:
	var kicker := DirectionalLight3D.new()
	kicker.name = "FireKicker"
	kicker.rotation_degrees = Vector3(-n("kicker_pitch"), 180.0, 0.0)  # Shining toward the camera (+z), from above.
	kicker.light_color = FIRE_LIGHT
	kicker.light_energy = n("kicker")
	kicker.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	_root.add_child(kicker)
	var point := OmniLight3D.new()
	point.name = "FireLight"
	point.position = center + Vector3(0.0, -n("fire_y") * 0.4, n("fire_light_in"))
	point.light_color = FIRE_LIGHT
	point.light_energy = n("fire_light")
	point.omni_range = 60.0
	_root.add_child(point)
	var mat := _wash_material()
	var half: float = _tuning.lane_width * n("lanes") * 0.5 + _tuning.wall_margin
	var floor_wash := MeshInstance3D.new()
	floor_wash.name = "FloorWash"
	var oval := QuadMesh.new()
	oval.size = Vector2(half * 2.6, n("wash_reach") * 2.0)
	floor_wash.mesh = oval
	floor_wash.material_override = mat
	floor_wash.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	floor_wash.position = Vector3(_runner_at.x, 0.06, center.z + n("wash_reach") * n("wash_toward"))
	floor_wash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_root.add_child(floor_wash)
	for side: float in [-1.0, 1.0]:
		var wall_wash := MeshInstance3D.new()
		wall_wash.name = "WallWash%s" % ("Left" if side < 0.0 else "Right")
		var face := QuadMesh.new()
		face.size = Vector2(n("wash_reach") * 2.0, n("wash_height") * 2.0)
		wall_wash.mesh = face
		wall_wash.material_override = mat
		wall_wash.rotation_degrees = Vector3(0.0, -side * 90.0, 0.0)  # Facing into the street.
		wall_wash.position = Vector3(_runner_at.x + side * (half - 0.12), n("wash_height") * 0.45, center.z)
		wall_wash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_root.add_child(wall_wash)


## A soft oval of the fire's colour, added to what is behind it (the Enforcer Truck's floor lights' kind of material:
## additive, unshaded, no depth write, never fogged away), its strength set by wash.
func _wash_material() -> StandardMaterial3D:
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	ramp.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	ramp.add_point(0.4, Color(1.0, 1.0, 1.0, 0.45))
	var tex := GradientTexture2D.new()
	tex.gradient = ramp
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 128
	tex.height = 128
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_fog = true
	m.albedo_texture = tex
	m.albedo_color = Color(FIRE_WASH, n("wash"))
	return m


# --- The camera ---------------------------------------------------------------------------------

func _add_camera() -> void:
	_camera = Camera3D.new()
	_camera.name = "Camera"
	_camera.fov = n("fov")
	_camera.near = 0.05
	_camera.far = 600.0
	_root.add_child(_camera)
	_camera.look_at_from_position(at(n("cam_x"), n("cam_y"), -n("cam_back")),
		at(n("look_x"), n("look_y"), n("look_behind")))
	_camera.rotation.z += deg_to_rad(n("cam_roll"))
	_camera.make_current()
