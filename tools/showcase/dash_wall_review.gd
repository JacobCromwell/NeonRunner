extends Node3D
## Gameplay review for dash walls (task H7a; GDD §9.14, owner, October 8, 2026: a building across the street
## that the runner dashes through; it crumbles into rubble): a real RunWorld on a hand-built track in a zone's
## look, driven like the tests' RunSim, seen through the game's camera (RunCamera) or a close one. Task H7b's
## per-zone looks are reviewed here too (--take=look holds the camera on a standing wall).
## The runner keeps to the middle lane and meets three walls, each a take of its own (--take):
##   smash  the dash started just before each wall smashes it (the default);
##   crash  no dash: the armor absorbs the first crash, the shield the second, and the third kills (with
##          --god it doesn't);
##   pass   from the outer lane the runner steps onto the side wall and passes each one on it;
##   look   the camera holds still in front of the first wall, the runner standing (no run).
##
##   Render:  godot --path . --write-movie build/review/f.png --fixed-fps 10 --quit-after 120
##            res://tools/showcase/dash_wall_review.tscn -- [options]
##   Options (after --):
##     --take=<smash|crash|pass|look>   what the runner does (above; default smash)
##     --skin=<zone id>       the zone's look (data/skins/<id>_skin.tres; default corporate), at its zone's run
##                            speed (data/zones/<id>.tres) where it has one
##     --lanes=N              lane count (default 5)
##     --close                a close camera low behind the runner
##     --hitboxes             show the walls' hitboxes (the hitbox view)
##     --reduced-flashing     the Reduced flashing setting on
##     --god                  god mode (a crash shrugged off)
##     --first=M              the first wall's face (metres, default 70)
##     --seed=N               the first wall's look seed (the next walls' follow it: N + 1, N + 2); the seed picks
##                            a zone's layout (N % 4) and tone ((N / 4) % 3), so --take=look --seed=0..3 shows
##                            each layout in turn (default 0)
## Each scripted action, movement event and crumble is printed with its time and distance, to find the frames
## (frame = time × render fps).

const TUNING_PATH: String = "res://data/tuning/movement.tres"
const RULES_PATH: String = "res://data/tuning/game_rules.tres"
## Metres between the walls' faces: past the dash's longest cooldown at the review's speed.
const WALL_SPACING: float = 190.0

var tuning: MovementTuning
var world: RunWorld
var camera: Camera3D
var lanes: int = 5
var close: bool = false
var take: String = "smash"
var _pending: Array = []
var _first: float = 70.0
var _seed: int = 0


func _ready() -> void:
	tuning = load(TUNING_PATH) as MovementTuning
	var skin_id: String = "corporate"
	var hitboxes: bool = false
	var reduced_flashing: bool = false
	var god: bool = false
	for arg: String in OS.get_cmdline_user_args():
		var v: String = arg.get_slice("=", 1)
		if arg.begins_with("--take="):
			take = v
		elif arg.begins_with("--skin="):
			skin_id = v
		elif arg.begins_with("--lanes="):
			lanes = clampi(int(v), 3, 8)
		elif arg == "--close":
			close = true
		elif arg == "--hitboxes":
			hitboxes = true
		elif arg == "--reduced-flashing":
			reduced_flashing = true
		elif arg == "--god":
			god = true
		elif arg.begins_with("--first="):
			_first = maxf(float(v), 30.0)
		elif arg.begins_with("--seed="):
			_seed = int(v)
	var skin: ZoneSkin = GreyboxSkin.new()
	var skin_path: String = "res://data/skins/%s_skin.tres" % skin_id
	if ResourceLoader.exists(skin_path):
		skin = load(skin_path) as ZoneSkin
	else:
		push_warning("dash_wall_review: no skin at %s; using the grey box" % skin_path)

	var config := LevelConfig.new()
	config.lane_count = lanes
	config.skin = skin
	var zone_path: String = "res://data/zones/%s.tres" % skin_id
	if ResourceLoader.exists(zone_path):
		var zone := load(zone_path) as ZoneDef
		if zone != null:
			config.run_speed = zone.run_speed
	var t: MovementTuning = config.movement_for(tuning)
	var layout := LevelLayout.new()
	layout.lane_count = lanes
	var mid: int = lanes / 2
	var start_lane: int = lanes - 1 if take == "pass" else mid
	var pt := load("res://data/tuning/powerups.tres") as PowerupTuning
	var dash_length: float = pt.dash_duration * (t.run_speed + pt.dash_speed_bonus)
	for k: int in 3:
		var face: float = _first + k * WALL_SPACING
		layout.dash_walls.append({"start": face, "end": face + t.dash_wall_depth, "seed": _seed + k})
		match take:
			"smash":
				_pending.append([face - 0.6 * dash_length, &"dash"])
			"pass":
				_pending.append([face - 18.0, &"move_right"])
	layout.length = _first + 3.0 * WALL_SPACING + 80.0

	var sfx := load("res://data/audio/sfx_library.tres") as SfxLibrary
	var loadout := Loadout.new()
	loadout.tiers[&"dash"] = 4
	world = RunWorld.new()
	add_child(world)
	world.build(config, layout, tuning, load(RULES_PATH) as GameRules, null, loadout, sfx)
	world.player.setup(world.tuning, world.geo, start_lane)
	world.player.steady_flash = reduced_flashing
	world.player.god_mode = god
	if take == "crash":
		world.player.armor = 1
		world.player.shield = 1
	world.track.set_hitboxes_visible(hitboxes)
	world.effects.crumbled.connect(func(b: DashBreakable) -> void:
		print("%5.2f s  %6.1f m  crumbled the wall at %.1f m, broken by %s (pieces in %s)" % [world.player.elapsed,
			world.player.distance, float(b.entry["start"]), b.broken_by(), b.debris_colors]))
	world.player.movement_event.connect(func(kind: StringName) -> void:
		print("%5.2f s  %6.1f m  %s" % [world.player.elapsed, world.player.distance, kind]))
	world.player.died.connect(func(cause: String) -> void:
		print("%5.2f s  %6.1f m  died (%s)" % [world.player.elapsed, world.player.distance, cause]))
	for w: Dictionary in layout.dash_walls:
		print("dash wall %5.1f–%5.1f m" % [w["start"], w["end"]])

	var env := WorldEnvironment.new()
	env.environment = skin.make_environment()
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, 25.0, 0.0)
	sun.light_energy = 0.7
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(sun)
	if close or take == "look":
		camera = Camera3D.new()
		camera.fov = 60.0
		add_child(camera)
		_update_close_camera()
	else:
		var run_camera := RunCamera.new()
		add_child(run_camera)
		run_camera.follow(world)
		camera = run_camera
	camera.make_current()
	if take != "look":
		world.start()


func _physics_process(_delta: float) -> void:
	var player: Player = world.player
	while not _pending.is_empty() and player.distance >= float(_pending[0][0]):
		var action: StringName = _pending.pop_front()[1]
		print("%5.2f s  %6.1f m  > %s" % [player.elapsed, player.distance, action])
		if action == &"dash":
			world.powerups.call(&"try_dash")
		else:
			player.press(action)


func _process(_delta: float) -> void:
	if close or take == "look":
		_update_close_camera()


## Low behind the runner over the middle of the track (or, for --take=look, still in front of the first wall,
## where the runner would come at it).
func _update_close_camera() -> void:
	if take == "look":
		camera.position = Vector3(0.0, 4.0, TrackGeometry.world_z(_first - 26.0))
		camera.look_at(Vector3(0.0, 3.6, TrackGeometry.world_z(_first)))
		return
	var p: Player = world.player
	camera.position = Vector3(0.0, 3.4, p.position.z + 6.5)
	camera.look_at(Vector3(0.0, 1.2, p.position.z - 8.0))
