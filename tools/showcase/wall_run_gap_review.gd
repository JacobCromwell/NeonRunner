extends Node3D
## Gameplay review for wall-run gaps (task J2; the owner, October 15, 2026: "a gap over the ENTIRE floor (every lane),
## and the only way to cross is a wall run"; WallRunGapPlacement): a real RunWorld on a hand-built track in a zone's
## look, at its zone's run speed, driven like the tests' RunSim, seen through the game's camera (RunCamera) or a close
## one. The track has two wall-run gaps shaped as the generator shapes them (the right wall lit, then the left), each a
## hole in every lane with its lit wall (ZoneSkin.wall_run_guide), and a few plain pieces before them for scale.
##   cross    the runner moves to the lit wall's outer lane in the run-in and steps onto the wall midway along the lit
##            stretch: the wall run carries them across (the default);
##   grapple  the runner stays in the middle lane with a grapple: it falls in and the grapple saves it onto the lit wall;
##   fall     the runner stays in the middle lane with nothing: it falls in (with --god it doesn't die);
##   look     the camera holds still before the first one, looking down the street at the lit wall (no run).
##
##   Render:  godot --path . --write-movie build/review/f.png --fixed-fps 10 --quit-after 120
##            res://tools/showcase/wall_run_gap_review.tscn -- [options]
##   Options (after --):
##     --take=<cross|grapple|fall|look>   what the runner does (above; default cross)
##     --skin=<zone id>       the zone's look (data/skins/<id>_skin.tres; default marketplace), at its zone's run
##                            speed (data/zones/<id>.tres) where it has one
##     --guide=<on|off>       the lit wall (ZoneSkin.show_wall_run_guide, task L5: only the Marketplace's skin shows
##                            it) on or off whatever the skin says, to compare the two
##     --lanes=N              lane count (default 5)
##     --close                a close camera low behind the runner
##     --god                  god mode
##     --first=M              where the first one's clear run-in starts (metres, default 90)
##     --runs=N               extended wall runs (task O1: 2 a double, 3 a triple; LevelConfig.extended_wall_runs) with a
##                            platform between two holes; with one lit wall the other is open over the crossing. With
##                            --take=cross the runner lands on each platform and steps back on from its last stretch
##     --both                 with --runs, both walls lit, platforms on both sides
## Each scripted action and movement event is printed with its time and distance, to find the frames
## (frame = time x render fps).

const TUNING_PATH: String = "res://data/tuning/movement.tres"
const RULES_PATH: String = "res://data/tuning/game_rules.tres"
## Metres between the two wall-run gaps' clear run-ins.
const SPACING: float = 260.0

var tuning: MovementTuning
var world: RunWorld
var camera: Camera3D
var lanes: int = 5
var close: bool = false
var take: String = "cross"
var _pending: Array = []
var _first: float = 90.0
var _runs: int = 1
var _both: bool = false


func _ready() -> void:
	tuning = load(TUNING_PATH) as MovementTuning
	var skin_id: String = "marketplace"
	var god: bool = false
	var guide: String = ""
	for arg: String in OS.get_cmdline_user_args():
		var v: String = arg.get_slice("=", 1)
		if arg.begins_with("--take="):
			take = v
		elif arg.begins_with("--skin="):
			skin_id = v
		elif arg.begins_with("--guide="):
			guide = v
		elif arg.begins_with("--lanes="):
			lanes = clampi(int(v), 3, 8)
		elif arg == "--close":
			close = true
		elif arg == "--god":
			god = true
		elif arg.begins_with("--first="):
			_first = maxf(float(v), 40.0)
		elif arg.begins_with("--runs="):
			_runs = clampi(int(v), 1, WallRunGapPlacement.MAX_RUNS)
		elif arg == "--both":
			_both = true
	var skin: ZoneSkin = GreyboxSkin.new()
	var skin_path: String = "res://data/skins/%s_skin.tres" % skin_id
	if ResourceLoader.exists(skin_path):
		skin = load(skin_path) as ZoneSkin
	else:
		push_warning("wall_run_gap_review: no skin at %s; using the grey box" % skin_path)
	if guide == "on" or guide == "off":
		skin = skin.duplicate() as ZoneSkin
		skin.show_wall_run_guide = guide == "on"

	var config := LevelConfig.new()
	config.lane_count = lanes
	config.skin = skin
	var zone_path: String = "res://data/zones/%s.tres" % skin_id
	if ResourceLoader.exists(zone_path):
		var zone := load(zone_path) as ZoneDef
		if zone != null:
			config.run_speed = zone.run_speed
	var t: MovementTuning = config.movement_for(tuning)
	var shape: WallRunGapPlacement.Shape = WallRunGapPlacement.shape_for(t, t.run_speed, null, null, _runs)
	var layout := LevelLayout.new()
	layout.lane_count = lanes
	var mid: int = lanes / 2
	# A few plain pieces before the first one, for scale: a hole and a fence in the lanes beside the middle.
	layout.gaps.append({"lane": maxi(mid - 1, 0), "start": _first - 45.0, "end": _first - 40.0})
	layout.fences.append({"lane": mini(mid + 1, lanes - 1), "at": _first - 30.0, "variant": "full", "pulsing": false,
		"pulse_on": 1.0, "pulse_off": 1.0, "phase": 0.0})
	for k: int in 2:
		var side: int = 1 if k == 0 else -1
		var w: Dictionary = WallRunGapPlacement.make(shape, _first + k * SPACING, side, _both and _runs > 1)
		for lane: int in lanes:
			for h: Vector2 in WallRunGapPlacement.lane_holes(layout, w, lane):
				layout.gaps.append({"lane": lane, "start": h.x, "end": h.y, LevelLayout.WALL_RUN_HOLE: true})
		layout.wall_run_gaps.append(w)
		layout.wall_gaps.append_array(WallRunGapPlacement.openings_of(w, t.run_speed))
		if take == "cross":
			# Across to the lit wall's outer lane in the run-in, one lane a beat, then onto the wall midway along the lit
			# stretch.
			var toward: StringName = &"move_right" if side > 0 else &"move_left"
			var lane_now: int = mid if k == 0 else lanes - 1
			var target: int = lanes - 1 if side > 0 else 0
			for n: int in absi(target - lane_now):
				_pending.append([float(w["approach"]) + 1.0 + n * 3.0, toward])
			for c: Vector3 in WallRunGapPlacement.crossings_of(w):
				_pending.append([(c.x + c.y) * 0.5, toward])
		print("wall-run gap %s wall: run-in from %.1f m, lit from %.1f m, gap %.1f-%.1f m, landing floor to %.1f m" % [
			"right" if side > 0 else "left", float(w["approach"]), float(w["entry"]), float(w["start"]), float(w["end"]),
			float(w["landing"])])
	_pending.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	layout.length = _first + 2.0 * SPACING + 60.0 + shape.span()
	layout.wall_gaps.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["start"]) < float(b["start"]))

	var sfx := load("res://data/audio/sfx_library.tres") as SfxLibrary
	var loadout := Loadout.new()
	if take == "grapple":
		loadout.charges[&"grapple"] = 1
	world = RunWorld.new()
	add_child(world)
	world.build(config, layout, tuning, load(RULES_PATH) as GameRules, null, loadout, sfx)
	world.player.god_mode = god
	world.player.movement_event.connect(func(kind: StringName) -> void:
		print("%5.2f s  %6.1f m  %s" % [world.player.elapsed, world.player.distance, kind]))
	world.player.died.connect(func(cause: String) -> void:
		print("%5.2f s  %6.1f m  died (%s)" % [world.player.elapsed, world.player.distance, cause]))

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
		player.press(action)


func _process(_delta: float) -> void:
	if close or take == "look":
		_update_close_camera()


## Low behind the runner over the middle of the track (or, for --take=look, still before the first wall-run gap's
## run-in, looking down the street at its lit wall).
func _update_close_camera() -> void:
	if take == "look":
		var w: Dictionary = world.layout.wall_run_gaps[0]
		camera.position = Vector3(-1.0, 3.2, TrackGeometry.world_z(float(w["approach"]) + 2.0))
		camera.look_at(Vector3(world.geo.wall_x() * 0.7, 1.4, TrackGeometry.world_z(float(w["start"]) + 4.0)))
		return
	var p: Player = world.player
	camera.position = Vector3(0.0, 3.4, p.position.z + 6.5)
	camera.look_at(Vector3(0.0, 1.2, p.position.z - 8.0))
