extends Node3D
## The House up close and in scripted runs, for visual review (GDD §10, task E5a; not part of the game).
## It builds the fight the way the game does (its arena on the Marketplace's stall roofs, in its arena's
## look), with a runner who plays it by its warnings (TheHouseBot) or stands still. The fight itself:
## ./play.sh --boss=marketplace_boss (debug builds). Render frames on both renderers, e.g.:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot4 --path . --resolution 960x540 --fixed-fps 10 \
##     --write-movie build/house/f.png --quit-after 60 res://tools/showcase/the_house_showcase.tscn \
##     -- --scenario=model --lanes=5
## (add --rendering-method gl_compatibility before the scene for the web / low-end renderer).
## Scenarios:
##   model     (default) a camera circling the machine standing on the street, its reels turning and
##             stopping on each symbol in turn, its lever pulled every few seconds
##   front     the machine from the runner's eye height, still: the reels on 7, cherry, BAR, lightning
##   entrance  the fight's start through the run camera: it rolls in and brakes ahead of the runner
##   spin      through the run camera, a spin (--symbols=cherry,bar,lightning by default) and its attacks,
##             with the bot dodging (--still: the runner stands in the middle lane, god mode)
##   buttons   through the run camera, a spin with buttons, the bot running over them
##   jackpot   through the run camera, a spin with buttons, the jackpot, the fountain and the stomp
##   wall      phase 2 through the run camera: wall fences along the walls, a set with a wall button, the
##             bot running along the wall over it
##   ceiling   phase 3 through the run camera: the machine squats, the billboard comes down with its pad
##             and turrets, the bot takes the pad and runs over the ceiling button, dodging bolts
##   defeat    phase 3 to its end: the last jackpot and stomp, then the wild spin, the jam and TILT, the
##             collapse in coins
##   fight     the fight as it comes, with the bot
## Options: --lanes=N (3, 5 or 6; 5 by default), --speed=N (18 by default; the campaign's 22.6),
## --symbols=a,b,c (the spin's three symbols: cherry, bar, lightning), --phase=N, --reduced-flashing,
## --still, --events (prints each of the boss's events with its frame, for picking frames).
## Frames worth a look (at --fixed-fps 10): entrance 0-45; spin: the lever about frame 53, the reels
## stopping 61-72, the attacks' warnings from about 75 and their strikes to about 110; buttons: the buttons
## lighting up from about frame 53 and pressed about 66-79; jackpot: the jackpot about frame 80, the
## fountain and the sag 83-92, the stomp about 102; wall, ceiling, defeat: print --events and pick.

const BOSS_PATH: String = "res://data/bosses/marketplace_boss.tres"

var scenario: String = "model"
var world: RunWorld
var boss: TheHouse
var bot: TheHouseBot
var _cam: Camera3D
var _run_cam: RunCamera
var _t: float = 0.0
var _print_events: bool = false
var _events_seen: int = 0
var _still: bool = false


func _ready() -> void:
	var lanes: int = 5
	var phase: int = 0
	var speed: float = 18.0
	var symbols: String = "cherry,bar,lightning"
	for arg: String in OS.get_cmdline_user_args():
		var v: String = arg.get_slice("=", 1)
		if arg.begins_with("--scenario="):
			scenario = v
		elif arg.begins_with("--lanes="):
			lanes = int(v)
		elif arg.begins_with("--phase="):
			phase = int(v)
		elif arg.begins_with("--speed="):
			speed = float(v)
		elif arg.begins_with("--symbols="):
			symbols = v
		elif arg == "--reduced-flashing":
			RenderingServer.global_shader_parameter_set(&"reduced_flashing", 1.0)
			Settings.flashing_reduced = true
		elif arg == "--events":
			_print_events = true
		elif arg == "--still":
			_still = true
	var slot: BossDef = load(BOSS_PATH) as BossDef
	var def: BossDef = slot.preview() if slot.preview() != null else slot.duplicate() as BossDef
	var t: TheHouseTuning = (def.tuning as TheHouseTuning).duplicate() as TheHouseTuning
	match scenario:
		"spin":
			t.spin_patterns = PackedStringArray([symbols.replace(",", ",")])
			t.opening_spins = PackedInt32Array([100])
		"buttons", "jackpot", "wall", "ceiling", "defeat":
			# The wall's set after one spin, once the phase's wall fences are near.
			var opening: int = 1 if scenario == "wall" else 0
			t.opening_spins = PackedInt32Array([opening, opening, opening])
			if phase == 0:
				phase = 2 if scenario == "wall" else (3 if scenario in ["ceiling", "defeat"] else 0)
	def.tuning = t
	var tuning := (load("res://data/tuning/movement.tres") as MovementTuning).duplicate() as MovementTuning
	tuning.run_speed = speed
	var ctx := RunContext.new()
	ctx.mode = RunContext.Mode.QUICK
	ctx.boss = def
	ctx.config = BossArena.base_config(def)
	ctx.config.lane_count = lanes
	ctx.tuning = tuning
	if phase > 0:
		ctx.boss_resume = {"phase": phase - 1}
	boss = BossEncounter.create(def) as TheHouse
	var arena: BossArena = boss.plan_arena(ctx)
	world = RunWorld.new()
	world.name = "World"
	add_child(world)
	world.build(ctx.config, arena.layout, tuning, load("res://data/tuning/game_rules.tres") as GameRules,
		load("res://data/tuning/powerups.tres") as PowerupTuning, null, load("res://data/audio/sfx_library.tres") as SfxLibrary)
	boss.setup(world, ctx, arena)
	if scenario in ["spin", "buttons", "jackpot", "wall", "ceiling", "defeat", "fight"] and not _still:
		bot = TheHouseBot.new(boss)
	else:
		world.player.god_mode = true
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
	if scenario in ["model", "front"]:
		_cam = Camera3D.new()
		_cam.fov = 60.0
		_cam.far = 600.0
		add_child(_cam)
		_cam.make_current()
	world.start()
	if scenario in ["model", "front"]:
		# The runner stands still: nothing moves but the machine.
		world.player.running = false


func _physics_process(delta: float) -> void:
	_t += delta
	match scenario:
		"model", "front":
			_hold_still()
		_:
			if bot != null:
				bot.step()


func _process(_delta: float) -> void:
	if not _print_events or boss == null:
		return
	while _events_seen < boss.events.size():
		var e: Dictionary = boss.events[_events_seen]
		_events_seen += 1
		if e["event"] != &"sound":
			print("frame %d: %s" % [Engine.get_process_frames(), e])


## The machine where it paces, out of the fight's hands: the camera circling it (model) or at the
## runner's eye height (front); its reels turning through the symbols.
func _hold_still() -> void:
	if boss.state != BossEncounter.State.FIGHT:
		boss.state = BossEncounter.State.FIGHT
	boss.front_at = world.player.distance + boss.stand_distance()
	boss._place()
	var body: TheHouseBody = boss.body
	var reels: TheHouseReels = body.reels
	if scenario == "front":
		for i: int in 3:
			if reels.state[i] == TheHouseReels.State.IDLE and reels.shown[i] != [0, 1, 2][i]:
				reels.stop(i, [0, 1, 2][i])
		body.lever = 0.0
	else:
		# Every 4 s: the lever, the reels spin, then stop one by one on the next symbols.
		var cycle: float = fmod(_t, 4.0)
		body.lever = 1.0 if cycle < 0.4 else 0.0
		var round_i: int = int(_t / 4.0)
		for i: int in 3:
			if cycle >= 0.45 and cycle < 0.5 and reels.state[i] == TheHouseReels.State.IDLE:
				reels.spin(i)
			var stop_at: float = 1.3 + 0.5 * i
			if cycle >= stop_at and reels.spinning(i):
				reels.stop(i, (round_i + i) % 4)
	var center: Vector3 = body.reels_world()
	if scenario == "model":
		# Swinging across the street in front of it (the street is too narrow to circle it), low and high.
		var a: float = _t * 0.45
		var half: float = world.geo.wall_x() * 0.8
		_cam.global_position = center + Vector3(sin(a) * half, -3.0 + 4.0 * (0.5 + 0.5 * sin(a * 0.7)), 17.0 + 5.0 * cos(a * 0.6))
		_cam.look_at(center + Vector3(0.0, -1.5, 0.0), Vector3.UP)
	else:
		_cam.global_position = world.player.global_position + Vector3(0.0, 1.7, 4.0)
		_cam.look_at(center, Vector3.UP)
