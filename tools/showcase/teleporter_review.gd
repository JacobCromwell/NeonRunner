extends Node3D
## Gameplay review for teleporters (task Q4; GDD §5, Zone 9, owner, October 21, 2026: "a square pad with a look all its
## own, with a green, slightly space-age antenna on it. Touching it teleports the runner to an output pad further down the
## track"; "a light on the antenna, on its left or its right side, shows which one the runner lands on"; "others blink left
## and right"): a real RunWorld on a hand-built track in a zone's look, driven like the tests' RunSim, seen through the
## game's camera (RunCamera) with the teleport's flash (TeleportFlash), or a camera holding still. One teleporter in lane
## --lane, the way around on --side, its output pads (one straight ahead, or a left and a right one, --outputs) on as its
## rules make them, and the runner coming at the pad in that lane (--take):
##   take    the runner runs onto the pad and lands on the output pad its light shows (the default);
##   around  the runner switches into the lane beside it as its approach begins and runs past it;
##   look    the camera holds still behind the pad, looking down the track at it and its output pads, no run (the light
##           still blinks with --blink).
##
##   Render:  godot --path . --write-movie build/review/f.png --fixed-fps 10 --quit-after 80
##            res://tools/showcase/teleporter_review.tscn -- [options]
##   Options (after --):
##     --take=<take|around|look>   what the runner does (above; default take)
##     --zone=<zone id>       the zone's run speed and look (data/zones/<id>.tres; default ice_lab)
##     --skin=<skin id>       another look (data/skins/<id>_skin.tres)
##     --lanes=N              lane count (default 5)
##     --lane=L               the pad's lane (an inner one; default the middle)
##     --side=<-1|1>          the way around it (default 1)
##     --outputs=<1|2>        one output pad, or a left and a right one (default 2)
##     --light=<-1|1>         the antenna's lit side (two output pads; default -1, the left)
##     --blink                a blinking antenna (from --light's side at --phase, 0-1 of a cycle)
##     --phase=P              the blinking light's phase (default 0)
##     --hazard               a fence across the output pads' lanes right past their landings (a later output pad's
##                            "right in front of a gap or an enemy")
##     --close                a close camera low behind the runner
##     --reduced-flashing     the Reduced flashing setting on (the flash a soft tint, the light's slower fade)
##     --first=M              the pad's front (metres, default 90)
##     --seed=N               the look's seed (default 0)
## Each scripted action, movement event and teleport is printed with its time and distance, to find the frames
## (frame = time × render fps).

const TUNING_PATH: String = "res://data/tuning/movement.tres"
const RULES_PATH: String = "res://data/tuning/game_rules.tres"
const TeleporterRules = preload("res://scripts/enemies/teleporter_rules.gd")

var tuning: MovementTuning
var world: RunWorld
var camera: Camera3D
var take: String = "take"
var close: bool = false
var _pending: Array = []
var _first: float = 90.0
var _entry: Dictionary = {}


func _ready() -> void:
	tuning = load(TUNING_PATH) as MovementTuning
	var zone_id: String = "ice_lab"
	var skin_id: String = ""
	var lanes: int = 5
	var lane: int = -1
	var side: int = 1
	var outputs: int = 2
	var light: int = -1
	var blink: bool = false
	var phase: float = 0.0
	var hazard: bool = false
	var reduced_flashing: bool = false
	var look_seed: int = 0
	for arg: String in OS.get_cmdline_user_args():
		var v: String = arg.get_slice("=", 1)
		if arg.begins_with("--take="):
			take = v
		elif arg.begins_with("--zone="):
			zone_id = v
		elif arg.begins_with("--skin="):
			skin_id = v
		elif arg.begins_with("--lanes="):
			lanes = clampi(int(v), 3, 8)
		elif arg.begins_with("--lane="):
			lane = int(v)
		elif arg.begins_with("--side="):
			side = -1 if int(v) < 0 else 1
		elif arg.begins_with("--outputs="):
			outputs = clampi(int(v), 1, 2)
		elif arg.begins_with("--light="):
			light = -1 if int(v) < 0 else 1
		elif arg == "--blink":
			blink = true
		elif arg.begins_with("--phase="):
			phase = float(v)
		elif arg == "--hazard":
			hazard = true
		elif arg == "--close":
			close = true
		elif arg == "--reduced-flashing":
			reduced_flashing = true
		elif arg.begins_with("--first="):
			_first = maxf(float(v), 40.0)
		elif arg.begins_with("--seed="):
			look_seed = int(v)
	if lane < 1 or lane > lanes - 2:
		lane = maxi(lanes / 2, 1)
	if lane + side < 0 or lane + side >= lanes:
		side = -side
	Settings.flashing_reduced = reduced_flashing
	var config := LevelConfig.new()
	config.lane_count = lanes
	var skin: ZoneSkin = GreyboxSkin.new()
	var zone_path: String = "res://data/zones/%s.tres" % zone_id
	if ResourceLoader.exists(zone_path):
		var zone := load(zone_path) as ZoneDef
		if zone != null:
			config.run_speed = zone.run_speed
			if ResourceLoader.exists(zone.skin_path):
				skin = load(zone.skin_path) as ZoneSkin
	if skin_id != "":
		var skin_path: String = "res://data/skins/%s_skin.tres" % skin_id
		if ResourceLoader.exists(skin_path):
			skin = load(skin_path) as ZoneSkin
		else:
			push_warning("teleporter_review: no skin at %s; keeping the zone's" % skin_path)
	config.skin = skin
	config.features = PackedStringArray([TeleporterRules.FEATURE])
	var t: MovementTuning = config.movement_for(tuning)
	var tt: TeleporterTuning = TeleporterTuning.load_default()
	var pt := load("res://data/tuning/powerups.tres") as PowerupTuning
	var layout := LevelLayout.new()
	layout.lane_count = lanes
	layout.length = _first + 400.0
	# The teleporter as its rules make one (TeleporterRules._place: its pad, its output pads at the middle hop, its calm
	# stretches and span).
	var gen: LevelGenerator = LevelGenerator.for_layout(config, tuning, layout)
	var pad: float = TeleporterRules.pad_size(gen, tt)
	var approach: float = tt.approach_seconds * TeleporterRules.fastest(gen, pt)
	var landing: float = TeleporterRules.landing_length(gen, tt, pt)
	var hops: PackedFloat32Array = tt.hops()
	var land: float = _first + hops[hops.size() / 2] * t.run_speed
	var lanes_out: Array[int] = []
	if outputs == 1:
		lanes_out.append(lane)
	else:
		lanes_out.append_array([0, lanes - 1])
	var outs: Array[Dictionary] = []
	var calm: Array = [[lane, _first - approach, _first + pad]]
	for o: int in lanes_out:
		outs.append({"lane": o, "at": land, "end": land + pad})
		calm.append([o, land - TeleporterRules.LANDING_BACK, land + landing])
	_entry = {"id": 0, "lane": lane, "at": _first, "end": _first + pad, "side": side, "outputs": outs,
		"light": light if outputs == 2 else 0, "blink": tt.blink_seconds if blink and outputs == 2 else 0.0,
		"phase": phase, "calm": calm, "span": [_first - approach, land + landing], "seed": look_seed}
	layout.teleporters.append(_entry)
	if hazard:
		for o: int in lanes_out:
			layout.fences.append({"lane": o, "at": land + landing + 2.0, "variant": "full", "pulsing": false,
				"pulse_on": 1.0, "pulse_off": 1.0, "phase": 0.0})
	if take == "around":
		_pending.append([_first - approach, &"move_right" if side > 0 else &"move_left"])

	var sfx := load("res://data/audio/sfx_library.tres") as SfxLibrary
	world = RunWorld.new()
	add_child(world)
	world.build(config, layout, tuning, load(RULES_PATH) as GameRules, null, null, sfx)
	world.player.setup(world.tuning, world.geo, lane)
	world.player.god_mode = true
	world.teleported.connect(func(from: float, to: float, _e: Dictionary, o: Dictionary) -> void:
		print("%5.2f s  %6.1f m  teleported from %.1f m to %.1f m, onto the output pad in lane %d" % [world.player.elapsed,
			world.player.distance, from, to, int(o["lane"])]))
	world.player.movement_event.connect(func(kind: StringName) -> void:
		print("%5.2f s  %6.1f m  %s" % [world.player.elapsed, world.player.distance, kind]))
	world.player.died.connect(func(cause: String) -> void:
		print("%5.2f s  %6.1f m  died (%s)" % [world.player.elapsed, world.player.distance, cause]))
	print("teleporter in lane %d, its pad %.1f-%.1f m, its output pads in lanes %s at %.1f m; light %s%s" % [lane, _first,
		_first + pad, lanes_out, land, ["left", "none", "right"][int(_entry["light"]) + 1], ", blinking" if blink else ""])

	var env := WorldEnvironment.new()
	env.environment = skin.make_environment()
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, 25.0, 0.0)
	sun.light_energy = 0.7
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(sun)
	var flash := TeleportFlash.new()
	add_child(flash)
	flash.setup(world, tt)
	if close or take == "look":
		camera = Camera3D.new()
		camera.fov = 60.0
		add_child(camera)
		_update_fixed_camera()
	else:
		var run_camera := RunCamera.new()
		add_child(run_camera)
		run_camera.follow(world)
		camera = run_camera
	camera.make_current()
	if take != "look":
		world.start()


func _physics_process(_delta: float) -> void:
	if world == null or world.player == null:
		return
	var player: Player = world.player
	while not _pending.is_empty() and player.distance >= float(_pending[0][0]):
		var action: StringName = _pending.pop_front()[1]
		print("%5.2f s  %6.1f m  > %s" % [player.elapsed, player.distance, action])
		player.press(action)
	if take == "look":
		# No run: the level clock still drives the light.
		player.elapsed += _delta
		world.track.light_teleporters(player.elapsed)


func _process(_delta: float) -> void:
	if world != null and (close or take == "look"):
		_update_fixed_camera()


## Low behind the runner (--close); or (--take=look) behind the pad, a little above the floor, looking down the track at
## it and its output pads.
func _update_fixed_camera() -> void:
	if close:
		var p: Player = world.player
		camera.position = Vector3(p.position.x * 0.5, 3.4, p.position.z + 6.5)
		camera.look_at(Vector3(p.position.x * 0.5, 1.6, p.position.z - 8.0))
		return
	var at: float = float(_entry["at"])
	var x: float = world.geo.lane_x(int(_entry["lane"]))
	camera.position = Vector3(x * 0.6, 3.0, TrackGeometry.world_z(at - 8.0))
	camera.look_at(Vector3(x * 0.6, 1.2, TrackGeometry.world_z(at + 20.0)))
