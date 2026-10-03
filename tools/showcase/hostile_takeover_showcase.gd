extends Node3D
## Hostile Takeover in scripted runs and close-ups, for visual review (GDD §10, task E5b; not part of the
## game). It builds the fight the way the game does (its train arena, in its arena's look), with a runner who
## plays it by what it shows (HostileTakeoverBot). The fight itself: ./play.sh --level=corporate/boss (debug
## builds). Render frames on both renderers, e.g.:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot4 --path . --resolution 960x540 --fixed-fps 10 \
##     --write-movie build/takeover/f.png --quit-after 80 res://tools/showcase/hostile_takeover_showcase.tscn \
##     -- --scenario=train --lanes=5
## (add --rendering-method gl_compatibility before the scene for the web / low-end renderer).
## Scenarios:
##   run         (default) through the run camera: the entrance, then phase 1 with the bot
##   train       a camera high beside the runner looking ahead along the train: the carriages and their
##               gaps, the couplings, the sound barriers, the city streaming past, the gunship, the locomotive
##   gunship     a camera low on the roofs behind the gunship, looking up at it
##   locomotive  a camera behind the locomotive at a runner's eye height: its rear window and the Chairman
##   coupling    the first coupling lit early (no dark gaps first) and the bot stomping it: --cam=back (the
##               default) watches from ahead of the gap, looking back at the runner, the stomp and the
##               carriages breaking away; --cam=run through the run camera
##   contract    phase 2 from its start (The Contract) with the bot: the strafes, the drop and its cut, the
##               pads and the ride over the armored carriage, the drop bay stomped; --cam=run (the default)
##               through the run camera, --cam=side from high beside the train ahead of the runner, looking
##               back at them and the gunship, --cam=ride from low beside the runner, looking back at them
##   merger      phase 3 from its start (The Merger) with the bot: the docking, MERGER COMPLETE on the screens,
##               the strafes and the drop, the pass and the three docking clamps stomped; --cam=run (the
##               default), --cam=dock from out over the street beside the line, a little ahead of where the war
##               engine docks, looking back across at it, --cam=belly from low at the roofs' edge, looking on ahead
##               under its belly, --cam=side and --cam=ride as in contract
##   defeat      phase 3 from its start, its three clamps torn loose one after another (a review's shortcut:
##               no pass) once the war engine has docked and --defeat-after seconds (1 by default) have passed,
##               then the defeat: --cam=chase (the default) from high behind the runner, looking ahead at the
##               gunship spinning away and the locomotive ploughing into the lobby; --cam=run
## Options: --lanes=N (3, 5 or 6; 5 by default), --speed=N (18 by default; the Corporate zone's 23.4),
## --phase=N (start at phase N, as a checkpoint would), --reduced-flashing, --still (the runner stands:
## nothing moves but the scenery), --events (prints each of the boss's events with its frame, for picking
## frames).
## Frames worth a look (at --fixed-fps 10): run: the entrance 0-30, the first live coupling about 40-60, the
## stomp about 185; coupling: the stomp about frame 57, the breakaway 57-80; contract at --speed=23.4: the
## strafes from frame 20 (warning) and 32 (rake), the drop's spot marked at 79, the tank let go at 89 and
## landed at 96 (its rev and charge 100-120), the armored carriage and its runway in sight from 95, the
## gunship coming down from 161, the runner on its belly from 179, the bay stomped at 213; merger (either
## speed): the docking 0-30 (the clamps lock at 21), MERGER COMPLETE from 30 (flashing to 80), a strafe
## 45-65, the drop 78-95, the pass's war engine coming down from 143, the runner on its belly from 169, the
## clamps stomped at 185, 204 and 224; defeat: the clamps torn at 40-46, the gunship exploding at 62, the
## crash at 72, the sculpture down by 83, the results due at 101.

const BOSS_PATH: String = "res://data/bosses/corporate_boss.tres"

var scenario: String = "run"
var cam_mode: String = "back"
var world: RunWorld
var boss: HostileTakeover
var bot: HostileTakeoverBot
var _cam: Camera3D
var _run_cam: RunCamera
var _still: bool = false
var _print_events: bool = false
var _events_seen: int = 0
var _back_at: float = -1.0
var _phase: int = 0
var _defeat_after: float = 1.0
var _docked_for: float = 0.0
var _torn: int = 0


func _ready() -> void:
	var lanes: int = 5
	var speed: float = 18.0
	for arg: String in OS.get_cmdline_user_args():
		var v: String = arg.get_slice("=", 1)
		if arg.begins_with("--scenario="):
			scenario = v
		elif arg.begins_with("--lanes="):
			lanes = int(v)
		elif arg.begins_with("--speed="):
			speed = float(v)
		elif arg.begins_with("--cam="):
			cam_mode = v
		elif arg == "--reduced-flashing":
			RenderingServer.global_shader_parameter_set(&"reduced_flashing", 1.0)
			Settings.flashing_reduced = true
		elif arg == "--still":
			_still = true
		elif arg == "--events":
			_print_events = true
		elif arg.begins_with("--phase="):
			_phase = maxi(int(v) - 1, 0)
		elif arg.begins_with("--defeat-after="):
			_defeat_after = maxf(float(v), 0.0)
	if scenario == "contract":
		_phase = maxi(_phase, 1)
		if cam_mode == "back":
			cam_mode = "run"
	elif scenario == "merger":
		_phase = 2
		if cam_mode == "back":
			cam_mode = "run"
	elif scenario == "defeat":
		_phase = 2
		if cam_mode == "back":
			cam_mode = "chase"
	var slot: BossDef = load(BOSS_PATH) as BossDef
	var def: BossDef = slot.duplicate() as BossDef
	if scenario == "coupling":
		var t: HostileTakeoverTuning = (def.tuning as HostileTakeoverTuning).duplicate() as HostileTakeoverTuning
		t.opening_gaps = PackedInt32Array([0])
		def.tuning = t
	var tuning := (load("res://data/tuning/movement.tres") as MovementTuning).duplicate() as MovementTuning
	tuning.run_speed = speed
	var ctx := RunContext.new()
	ctx.mode = RunContext.Mode.QUICK
	ctx.boss = def
	ctx.config = BossArena.base_config(def)
	ctx.config.lane_count = lanes
	ctx.tuning = tuning
	ctx.boss_resume = {"phase": _phase} if _phase > 0 else {}
	boss = BossEncounter.create(def) as HostileTakeover
	var arena: BossArena = boss.plan_arena(ctx)
	world = RunWorld.new()
	world.name = "World"
	add_child(world)
	world.build(ctx.config, arena.layout, tuning, load("res://data/tuning/game_rules.tres") as GameRules,
		load("res://data/tuning/powerups.tres") as PowerupTuning, null, load("res://data/audio/sfx_library.tres") as SfxLibrary)
	boss.setup(world, ctx, arena)
	world.player.god_mode = true
	world.player.grapples = 1_000_000
	if not _still:
		bot = HostileTakeoverBot.new(boss)
	var env := WorldEnvironment.new()
	env.environment = world.skin.level_environment(ctx.config.darkness)
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, 25.0, 0.0)
	sun.light_energy = 0.7
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(sun)
	_run_cam = RunCamera.new()
	add_child(_run_cam)
	_run_cam.follow(world)
	_run_cam.make_current()
	if scenario in ["train", "gunship", "locomotive"] or (scenario == "coupling" and cam_mode == "back") \
			or (scenario in ["contract", "merger", "defeat"] and cam_mode != "run"):
		_cam = Camera3D.new()
		_cam.fov = 62.0
		_cam.far = 900.0
		add_child(_cam)
		_cam.make_current()
	world.start()
	if _still:
		world.player.running = false


func _physics_process(delta: float) -> void:
	if bot != null:
		bot.step()
	if scenario == "defeat" and boss != null and boss.docked and not boss.is_defeated():
		# The review's shortcut: the clamps torn loose one after another, 0.3 s apart.
		_docked_for += delta
		var due: int = int(floor((_docked_for - _defeat_after) / 0.3)) + 1 if _docked_for >= _defeat_after else 0
		while _torn < mini(due, boss.gunship.clamps.size()) and boss.is_vulnerable():
			boss.stomp_weak_point(boss.gunship, boss.gunship.clamps[_torn]["point"])
			_torn += 1


func _process(_delta: float) -> void:
	_place_camera()
	if not _print_events or boss == null:
		return
	while _events_seen < boss.events.size():
		var e: Dictionary = boss.events[_events_seen]
		_events_seen += 1
		if e["event"] != &"carriage_planned":
			print("frame %d: %s" % [Engine.get_process_frames(), e])


func _place_camera() -> void:
	if _cam == null or world == null or world.player == null:
		return
	var p: Vector3 = world.player.global_position
	match scenario:
		"train":
			var eye := Vector3(world.geo.wall_x() - 1.2, 9.5, p.z + 14.0)
			_cam.look_at_from_position(eye, Vector3(-1.0, 1.0, p.z - 60.0))
		"gunship":
			var target: Vector3 = boss.gunship.global_position + Vector3(0.0, 1.5, 0.0)
			_cam.look_at_from_position(Vector3(-2.0, 2.2, p.z + 2.0), target)
		"locomotive":
			var face: Vector3 = boss.locomotive.global_position
			_cam.look_at_from_position(face + Vector3(1.5, 3.0, 22.0), face + Vector3(0.0, 2.0, 0.0))
		"coupling":
			# Ahead of the first live coupling's gap, looking back at the runner coming.
			if _back_at < 0.0:
				var k: int = boss.next_live_coupling()
				if k < 0:
					_cam.look_at_from_position(p + Vector3(3.0, 6.0, -30.0), p + Vector3(0.0, 1.0, 0.0))
					return
				_back_at = boss.train.gap_start(k)
			var gap_z: float = TrackGeometry.world_z(_back_at)
			_cam.look_at_from_position(Vector3(world.geo.wall_x() - 1.0, 6.5, gap_z - 26.0), Vector3(-1.0, 0.0, gap_z + 6.0))
		"merger", "defeat":
			match cam_mode:
				"dock":
					# Out over the street beside the line, a little ahead of where the war engine docks, looking
					# back across at it.
					_cam.look_at_from_position(Vector3(world.geo.wall_x() + 12.0, 10.0, p.z - 72.0), Vector3(0.0, 5.5, p.z - 54.0))
				"belly":
					# Low at the roofs' edge ahead of the runner, looking on ahead under the war engine's belly.
					_cam.look_at_from_position(Vector3(-world.geo.wall_x() + 0.6, 4.5, p.z - 36.0), Vector3(1.0, 6.5, p.z - 62.0))
				"chase":
					# High behind the runner, looking ahead and over to the derailing side.
					var side: float = float(boss.tuning.derail_side if boss.tuning.derail_side != 0 else 1)
					_cam.look_at_from_position(Vector3(-side * 1.5, 9.5, p.z + 8.0), Vector3(side * world.geo.wall_x() * 0.9, 5.5, p.z - 50.0))
				"ride":
					_cam.look_at_from_position(Vector3(world.geo.wall_x() - 0.5, 3.4, p.z - 9.0), Vector3(-0.5, 3.6, p.z + 6.0))
				_:
					_cam.look_at_from_position(Vector3(world.geo.wall_x() - 0.8, 11.0, p.z - 38.0), Vector3(-0.5, 2.5, p.z + 4.0))
		"contract":
			if cam_mode == "ride":
				# Low beside the runner and a little ahead of them, looking back: the runway, the gunship coming
				# down over them, the ride on its belly with the armored carriage below.
				_cam.look_at_from_position(Vector3(world.geo.wall_x() - 0.5, 3.4, p.z - 9.0), Vector3(-0.5, 3.6, p.z + 6.0))
			else:
				# High beside the train ahead of the runner, looking back at them and the gunship.
				_cam.look_at_from_position(Vector3(world.geo.wall_x() - 0.8, 11.0, p.z - 38.0), Vector3(-0.5, 2.5, p.z + 4.0))
