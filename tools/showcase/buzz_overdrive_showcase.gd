extends Node3D
## Visual review of the Buzz Overdrive (GDD §9.9; task C2): its model up close, or a scripted run through
## one encounter in a real RunWorld on any zone's skin, seen through the game's camera (RunCamera), a
## camera high over its lane, or one low beside it.
## The run: the runner starts in its lane, sees it parked in the distance; it rolls ahead, revs (the red
## line over its lane, the spin-up, its eyes flaring) and charges; the runner leaves the lane half a
## second into the warning and runs on beside the gap it cuts.
##
##   Render:  godot --path . --write-movie build/buzz/f.png --fixed-fps 10 --quit-after 150
##            res://tools/showcase/buzz_overdrive_showcase.tscn -- [options]
##   Options (after --):
##     --scenario=run|model  the scripted run (default), or the model turning on a plinth, revving
##     --skin=<zone id>      the zone's look (data/skins/<id>_skin.tres; default corporate)
##     --lanes=N             lane count (default 3)
##     --lane=N              its lane (default the middle one)
##     --speed=N             the run speed (default the zone's: Corporate 23.4, the Dead Zone 24.2, the Golden
##                           Zone 25; the encounter keeps its timing in seconds)
##     --scaling=X           the level's enemy scaling, which sets its rev (default Corporate 1's, 0.57)
##     --high                a camera high behind the runner, looking down its lane
##     --side                a camera low beside its lane, level with the runner
##     --stay                the runner stays in its lane: the armor blocks the saw, the floor holds for a
##                           second, then the runner switches out
##     --kill=D              it's killed when the runner reaches distance D (before its charge: the floor
##                           is saved; during it: the cut stops there)
##     --pass                another type's big attack (a stand-in that only reports itself, never seen:
##                           tests/helpers/turn_dummy.gd) begun before its claim is still on as its rev
##                           would start, so it lets the runner pass (task FIX2): no rev, no line, it speeds
##                           off ahead out of view; the runner stays in its lane on the whole floor
##     --reduced-flashing    Reduced flashing on (its line holds still, no sparks)
## The run prints its timeline (where it sets off, warns, charges, meets the runner, ends), each scripted
## action and movement event, and each of its states, to find the frames (frame = time × render fps).

const TUNING_PATH: String = "res://data/tuning/movement.tres"
const RULES_PATH: String = "res://data/tuning/game_rules.tres"
const Rules = preload("res://scripts/enemies/buzz_overdrive_rules.gd")
const TankScript = preload("res://scripts/enemies/buzz_overdrive.gd")
const ZONE_SPEEDS: Dictionary = {"corporate": 23.4, "corporate_plaza": 23.4, "dead_zone": 24.2, "golden": 25.0,
	"golden_palace": 25.0}

var tuning: MovementTuning
var world: RunWorld
var camera: Camera3D
var mode: String = "game"
var cut: Dictionary = {}
var _pending: Array = []
var _kill_at: float = INF
var _model: BuzzOverdriveModel
var _t: float = 0.0
## The tank's state last printed.
var _tank_state: String = ""


func _ready() -> void:
	tuning = load(TUNING_PATH) as MovementTuning
	var scenario: String = "run"
	var skin_id: String = "corporate"
	var lanes: int = 3
	var lane: int = -1
	var speed: float = -1.0
	var scaling: float = 8.0 / 14.0
	var stay: bool = false
	var lets_pass: bool = false
	for arg: String in OS.get_cmdline_user_args():
		var v: String = arg.get_slice("=", 1)
		if arg.begins_with("--scenario="):
			scenario = v
		elif arg.begins_with("--skin="):
			skin_id = v
		elif arg.begins_with("--lanes="):
			lanes = clampi(int(v), 3, 8)
		elif arg.begins_with("--lane="):
			lane = int(v)
		elif arg.begins_with("--speed="):
			speed = maxf(float(v), 5.0)
		elif arg.begins_with("--scaling="):
			scaling = clampf(float(v), 0.0, 1.0)
		elif arg == "--high":
			mode = "high"
		elif arg == "--side":
			mode = "side"
		elif arg == "--stay":
			stay = true
		elif arg.begins_with("--kill="):
			_kill_at = float(v)
		elif arg == "--pass":
			lets_pass = true
		elif arg == "--reduced-flashing":
			Settings.flashing_reduced = true
			RenderingServer.global_shader_parameter_set(&"reduced_flashing", 1.0)
	var skin: ZoneSkin = GreyboxSkin.new()
	var skin_path: String = "res://data/skins/%s_skin.tres" % skin_id
	if ResourceLoader.exists(skin_path):
		skin = load(skin_path) as ZoneSkin
	else:
		push_warning("buzz_overdrive_showcase: no skin at %s; using the grey box" % skin_path)
	if speed < 0.0:
		speed = float(ZONE_SPEEDS.get(skin_id, tuning.run_speed))
	tuning = tuning.duplicate() as MovementTuning
	tuning.run_speed = speed
	_light(skin)
	if scenario == "model":
		_build_model(skin)
		return
	if lane < 0 or lane >= lanes:
		lane = lanes / 2
	var side: int = 1 if lane < lanes / 2 else -1
	if lane + side < 0 or lane + side >= lanes:
		side = -side
	var t: BuzzOverdriveTuning = Rules.tuning()
	var anchor: float = 200.0
	cut = Rules.plan_for(t, lane, anchor, speed, tuning.pace(), scaling)
	var end: float = float(cut["end"])
	var layout := LevelLayout.new()
	layout.lane_count = lanes
	layout.cuts.append(cut)
	layout.enemies.append({"type": "buzz_overdrive", "at": end, "lane": lane, "side": 0, "seed": 1, "params": {}})
	layout.length = end + 240.0
	var v: float = speed
	var start: float = anchor - 50.0
	var meet: float = FloorCutPlan.meet(cut, v)
	print("Buzz Overdrive in lane %d at %.1f m/s, rev %.2f s: sets off at %.1f m (%.2f s), warns at %.1f m (%.2f s), charges at %.1f m (%.2f s), meets the runner at %.1f m (%.2f s), cuts %.1f-%.1f m, done at %.1f m (%.2f s)" % [
		lane, v, t.rev_at(scaling), FloorCutPlan.lead_at(cut), (FloorCutPlan.lead_at(cut) - start) / v,
		FloorCutPlan.warn_at(cut), (FloorCutPlan.warn_at(cut) - start) / v, FloorCutPlan.charge_at(cut),
		(FloorCutPlan.charge_at(cut) - start) / v, meet, (meet - start) / v, cut["start"], end,
		FloorCutPlan.done_at(cut, v), (FloorCutPlan.done_at(cut, v) - start) / v])
	var config := LevelConfig.new()
	config.lane_count = lanes
	config.skin = skin
	config.enemy_scaling = scaling
	world = RunWorld.new()
	add_child(world)
	world.build(config, layout, tuning, load(RULES_PATH) as GameRules, null, Loadout.new(),
		load("res://data/audio/sfx_library.tres") as SfxLibrary)
	world.player.setup(tuning, world.geo, lane)
	world.player.distance = start
	if lets_pass:
		# Begun 0.3 s before its claim, on until 1 s after its rev would start.
		var rev_s: float = (FloorCutPlan.warn_at(cut) - start) / v
		world.director.spawn({"type": "stand_in_attack", "script": "res://tests/helpers/turn_dummy.gd", "at": 0.0,
			"lane": 0, "side": 0, "seed": 1, "params": {"first": rev_s - t.claim_seconds - 0.3, "interval": 600.0,
			"warning": 0.5, "attack": t.claim_seconds + 0.8}})
		print("another type's big attack from %.2f s to %.2f s; its claim from %.2f s, its rev due at %.2f s" % [
			rev_s - t.claim_seconds - 0.3, rev_s + 1.0, rev_s - t.claim_seconds, rev_s])
	elif stay:
		world.player.armor = 1
		_pending.append([meet + tuning.run_speed * 0.5, &"move_left" if side < 0 else &"move_right"])
	else:
		_pending.append([FloorCutPlan.warn_at(cut) + 0.5 * v, &"move_left" if side < 0 else &"move_right"])
	world.player.movement_event.connect(func(kind: StringName) -> void:
		print("%5.2f s  %6.1f m  %s" % [world.player.elapsed, world.player.distance, kind]))
	var env := WorldEnvironment.new()
	env.environment = skin.make_environment()
	add_child(env)
	if mode == "game":
		var run_camera := RunCamera.new()
		add_child(run_camera)
		run_camera.follow(world)
		camera = run_camera
	else:
		camera = Camera3D.new()
		camera.fov = 62.0 if mode == "high" else 55.0
		add_child(camera)
		_update_camera()
	camera.make_current()
	world.start()


func _physics_process(_delta: float) -> void:
	if world == null:
		return
	var player: Player = world.player
	while not _pending.is_empty() and player.distance >= float(_pending[0][0]):
		var action: StringName = _pending.pop_front()[1]
		print("%5.2f s  %6.1f m  > %s" % [player.elapsed, player.distance, action])
		player.press(action)
	if player.distance >= _kill_at:
		_kill_at = INF
		for e: Enemy in world.director.active:
			if is_instance_valid(e) and e.alive and e.type_id == &"buzz_overdrive":
				print("%5.2f s  %6.1f m  > the Buzz Overdrive is killed" % [player.elapsed, player.distance])
				e.take_damage(1000.0, &"weapon")
	for e: Enemy in world.director.active:
		if is_instance_valid(e) and e.alive and e.type_id == &"buzz_overdrive":
			var state: String = String(TankScript.State.find_key(int(e.get(&"state"))))
			if state != _tank_state:
				_tank_state = state
				print("%5.2f s  %6.1f m  the Buzz Overdrive: %s (%.1f m ahead)" % [player.elapsed, player.distance, state,
					float(e.get(&"front")) - player.distance])


func _process(delta: float) -> void:
	_t += delta
	if _model != null:
		_animate_model(delta)
	elif world != null and mode != "game":
		_update_camera()


## High behind the runner over its lane, or low beside its lane level with the runner.
func _update_camera() -> void:
	var p: Player = world.player
	var x: float = world.geo.lane_x(int(cut["lane"]))
	if mode == "high":
		camera.position = Vector3(x * 0.6, 9.0, p.position.z + 9.0)
		camera.look_at(Vector3(x, 0.0, p.position.z - 24.0))
	else:
		var side_x: float = x + (world.geo.lane_width * 2.2 if x <= 0.0 else -world.geo.lane_width * 2.2)
		camera.position = Vector3(side_x, 1.6, p.position.z + 2.0)
		camera.look_at(Vector3(x, 1.0, p.position.z - 30.0))


func _light(_skin: ZoneSkin) -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, 25.0, 0.0)
	sun.light_energy = 0.7
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(sun)


## The model turning on a dark plinth, revving up and down so the blade's spin and the eyes show.
func _build_model(skin: ZoneSkin) -> void:
	var t: BuzzOverdriveTuning = Rules.tuning()
	var env := WorldEnvironment.new()
	env.environment = skin.make_environment()
	add_child(env)
	_model = BuzzOverdriveModel.new()
	add_child(_model)
	_model.build(skin.enemy_variant if skin != null else &"city", t.body_size, t.blade_radius)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(14.0, 14.0)
	floor_mesh.mesh = plane
	floor_mesh.material_override = GreyboxMaterials.flat(Color(0.12, 0.12, 0.14))
	add_child(floor_mesh)
	camera = Camera3D.new()
	camera.fov = 45.0
	add_child(camera)
	camera.make_current()


func _animate_model(delta: float) -> void:
	var a: float = _t * 0.45
	var r: float = 10.5
	camera.position = Vector3(sin(a) * r, 3.2, cos(a) * r - 2.6)
	camera.look_at(Vector3(0.0, 1.1, -2.6))
	# Revs up for 3 s, holds, winds down.
	var k: float = clampf(fmod(_t, 6.0) / 3.0, 0.0, 1.0)
	_model.set_flare(fmod(_t, 6.0) < 4.5)
	_model.spin(lerpf(2.5, 34.0, k * k) * delta)
