extends Node3D
## Gameplay review for zone doodads (GDD §3, owner's playtest September 30, 2026; task G5): a real
## RunWorld on a hand-built track, driven with press() like the tests' RunSim, seen through the game's
## camera (RunCamera) or a close one.
## The runner keeps to the middle lane: head-on into a small doodad that pushes it right (with the
## thud), back to the middle, into a medium one that pushes it left, back again, and into a large one
## pushing right, alongside which a lane switch into its side clanks and bumps. With five lanes or more,
## others stand in the other inner lanes, seen coming alongside.
## With --dash (task H5; GDD §3, owner, October 8, 2026: the dash smashes a doodad) the runner carries the
## dash and smashes them instead: the small one head-on, the medium one head-on, the large one from the
## side (a switch into it while dashing), and a fourth, small one with a dash that ends just short of it,
## which pushes as usual.
##
##   Render:  godot --path . --write-movie build/review/f.png --fixed-fps 30 --quit-after 150
##            res://tools/showcase/doodad_review.tscn -- [options]
##   Options (after --):
##     --skin=<zone id>      the zone's look (data/skins/<id>_skin.tres; default city)
##     --lanes=N             lane count (default 3)
##     --close               a close camera low behind the runner, over its lane
##     --hitboxes            show the doodads' bodies (the hitbox view)
##     --dash                the runner smashes them with the dash (above)
##     --reduced-flashing    with --dash: the Reduced flashing setting on
## Each scripted action and movement event is printed with its time and distance, to find the frames
## (frame = time × render fps).

const TUNING_PATH: String = "res://data/tuning/movement.tres"
const RULES_PATH: String = "res://data/tuning/game_rules.tres"

var tuning: MovementTuning
var world: RunWorld
var camera: Camera3D
var lanes: int = 3
var close: bool = false
var dash: bool = false
var _pending: Array = []


func _ready() -> void:
	tuning = load(TUNING_PATH) as MovementTuning
	var skin_id: String = "city"
	var hitboxes: bool = false
	var reduced_flashing: bool = false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--skin="):
			skin_id = arg.get_slice("=", 1)
		elif arg.begins_with("--lanes="):
			lanes = clampi(int(arg.get_slice("=", 1)), 3, 8)
		elif arg == "--close":
			close = true
		elif arg == "--hitboxes":
			hitboxes = true
		elif arg == "--dash":
			dash = true
		elif arg == "--reduced-flashing":
			reduced_flashing = true
	var skin: ZoneSkin = GreyboxSkin.new()
	var skin_path: String = "res://data/skins/%s_skin.tres" % skin_id
	if ResourceLoader.exists(skin_path):
		skin = load(skin_path) as ZoneSkin
	else:
		push_warning("doodad_review: no skin at %s; using the grey box" % skin_path)

	var layout := LevelLayout.new()
	layout.lane_count = lanes
	var mid: int = lanes / 2
	var at: float = 60.0
	if dash:
		at = _plan_dash(layout, mid)
	else:
		# Head-on into a small one that pushes right, back to the middle, into a medium one that pushes
		# left, back again, then into a large one pushing right: alongside it, a move into its side.
		var plan: Array[Array] = [[&"small", 1], [&"medium", -1], [&"large", 1]]
		for i: int in plan.size():
			var d: Dictionary = _add(layout, mid, at, plan[i][0], plan[i][1])
			var back: StringName = &"move_left" if int(plan[i][1]) > 0 else &"move_right"
			if i < plan.size() - 1:
				_pending.append([float(d["end"]) + 8.0, back])
			else:
				_pending.append([float(d["end"]) - 3.0, back])
			# Others in the other inner lanes, seen coming alongside (five lanes or more).
			for lane: int in range(1, lanes - 1):
				if lane != mid:
					_add(layout, lane, at + 18.0 + 6.0 * lane, LevelLayout.DOODAD_SIZES[(i + lane) % 3], 1 if lane < mid else -1)
			at = float(d["end"]) + 45.0
	layout.length = at + 80.0

	var config := LevelConfig.new()
	config.lane_count = lanes
	config.skin = skin
	var sfx := load("res://data/audio/sfx_library.tres") as SfxLibrary
	var loadout := Loadout.new()
	if dash:
		loadout.tiers[&"dash"] = 4
	world = RunWorld.new()
	add_child(world)
	world.build(config, layout, tuning, load(RULES_PATH) as GameRules, null, loadout, sfx)
	world.player.setup(tuning, world.geo, mid)
	world.player.steady_flash = reduced_flashing
	world.track.set_hitboxes_visible(hitboxes)
	world.player.smashed.connect(func(b: DashBreakable) -> void:
		print("%5.2f s  %6.1f m  smashed %s in lane %d (pieces in %s)" % [world.player.elapsed, world.player.distance,
			b.entry["size"], b.entry["lane"], b.debris_colors]))
	world.player.movement_event.connect(func(kind: StringName) -> void:
		print("%5.2f s  %6.1f m  %s" % [world.player.elapsed, world.player.distance, kind]))
	for d: Dictionary in layout.doodads:
		print("doodad %-6s lane %d  %5.1f–%5.1f m  pushes %s" % [d["size"], d["lane"], d["start"], d["end"],
			"right" if int(d["side"]) > 0 else "left"])

	var env := WorldEnvironment.new()
	env.environment = skin.make_environment()
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, 25.0, 0.0)
	sun.light_energy = 0.7
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(sun)
	if close:
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
	world.start()


## The --dash plan: in the middle lane a small doodad and a medium one, each smashed head-on by a dash
## started `lead` metres before it; a large one the runner comes alongside from the lane to its right and
## smashes with a switch into its side while dashing; and a small one a dash ends just short of, which
## pushes. The dashes are spaced past the dash's shortest cooldown (tier 4). Returns where the last ends.
func _plan_dash(layout: LevelLayout, mid: int) -> float:
	var pt := load("res://data/tuning/powerups.tres") as PowerupTuning
	var dash_length: float = pt.dash_duration * (tuning.run_speed + pt.dash_speed_bonus)
	var recover: float = dash_length + (pt.dash_cooldown_at(4) - pt.dash_duration) * tuning.run_speed + 6.0
	var lead: float = 8.0
	var at: float = 60.0
	var small: Dictionary = _add(layout, mid, at, &"small", 1)
	_pending.append([float(small["start"]) - lead, &"dash"])
	at = float(small["start"]) - lead + recover + lead
	var medium: Dictionary = _add(layout, mid, at, &"medium", -1)
	_pending.append([float(medium["start"]) - lead, &"dash"])
	at = float(medium["start"]) - lead + recover
	var large: Dictionary = _add(layout, mid, at, &"large", 1)
	_pending.append([float(large["start"]) - 20.0, &"move_right"])
	_pending.append([float(large["start"]) + 0.5, &"dash"])
	_pending.append([float(large["start"]) + 1.0, &"move_left"])
	at = float(large["start"]) + 0.5 + recover + dash_length + 4.0
	var short: Dictionary = _add(layout, mid, at, &"small", -1)
	_pending.append([float(short["start"]) - dash_length - 4.0, &"dash"])
	return float(short["end"]) + 30.0


func _add(layout: LevelLayout, lane: int, start: float, size: StringName, side: int) -> Dictionary:
	var d := {"lane": lane, "start": start, "end": start + tuning.doodad_size(size).z, "size": size, "side": side,
		"seed": layout.doodads.size()}
	layout.doodads.append(d)
	return d


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
	if close:
		_update_close_camera()


## Low behind the runner (above the doodads) and over the middle of the track, so a push moves the
## runner across the frame.
func _update_close_camera() -> void:
	var p: Player = world.player
	camera.position = Vector3(0.0, 3.4, p.position.z + 6.5)
	camera.look_at(Vector3(0.0, 1.2, p.position.z - 8.0))
