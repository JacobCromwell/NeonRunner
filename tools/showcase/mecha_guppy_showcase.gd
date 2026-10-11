extends Node3D
## Mecha Guppy and Captain Cogs' climb in scripted runs, for visual review (GDD §10, task E5e-b1; not part of the
## game). It builds the fight the way the game does (its arena in the Beach's look, under Sunset Strip's sky as the
## campaign plays it) with a runner who climbs by the hut and the roofs (MechaGuppyBot). The fight itself:
## ./play.sh --boss=beach_boss (debug builds; quick play keeps the Beach's own daylight sky until the campaign plays
## the fight, E5e-c). Render frames on both renderers, e.g.:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot4 --path . --resolution 960x540 --fixed-fps 10 \
##     --write-movie build/mg/f.png --quit-after 120 res://tools/showcase/mecha_guppy_showcase.tscn \
##     -- --scenario=climb --lanes=5
## (add --rendering-method gl_compatibility before the scene for the web / low-end renderer).
## Scenarios:
##   climb      (default) the fight through the run camera: the runner climbs step after step, reading the lanes
##              that lead up
##   wrong      the runner drops off the first hut in a lane that doesn't lead up: the fall into the chasm
##   grapple    the same with a grapple: the save onto the higher roof, into a lane that leads up
##   side       a camera alongside the climb, looking across at the stairs of roofs and huts and the waterfall
##   hut        the runner standing under the first hut, or step S's with --start=S (the run camera's view from under
##              it): reading the cue
##   top        phase 3's stub (--phase=3 implied): the climb's last steps, then the flat top, the waterfall gone
##   shark      (E5e-b2) a camera beside Mecha Guppy whenever it's up: its catch beside a roof's notch, its bite, its
##              breaches beside the lanes that lead up (with --no-bait), a bomb falling into its jaws (the climb goes on
##              as in climb)
##   ship       a camera ahead of and above Captain Cogs' ship, looking back past the captain at the climb as it throws
##   bombs      the run camera, as climb (the volleys' circles, the bombs coming down, the blasts; with --phase=2 the
##              landing spots and the spots with more bombs)
##   bait       (E5e-b3) the run camera, as climb: the notch at each roof's end (from roof 2) with the shark waiting
##              beside it, the bait's aim following the runner into the notch's lane, the lock and the throw, the switch
##              out before the edge, the bomb falling into the jaws
##   hits       the same as bait
## Options: --lanes=N (3, 5 or 6; 5 by default), --speed=M (the run's speed, m/s; the Beach's 23.8 by default),
## --phase=N, --daylight (the Beach's own sky instead of Sunset Strip's), --reduced-flashing, --events (prints the
## boss's events with their frames, for picking frames), --no-attacks (the climb alone: no bombs, no bites),
## --no-bait (the runner doesn't bait: Captain Cogs' fallback misses into the chasm bring the hits), --start=S (move
## the runner on to step S's roof first: a view from higher up; with --phase=2 the steps it plans are phase 2's).
## Frames worth a look (at --fixed-fps 10, 23.8 m/s, 5 lanes): climb, the first pads about frame 36, on the first hut
## 41-78, its lane's end and the drop about 78, the first roof 84-117, the second hut 122-146; wrong, the drop and the
## fall about 65-75; grapple, the save about 71-79; side, any frame. bait: the shark rising beside roof 2's notch (its
## rumble) about frame 168, its jaws open and the bait's aim following the runner 174-180, the lock and the throw about
## 180, the switch out about 184, the bomb into the jaws about 190 (3 lanes: 156, 162-168, 168, 172, 179; 6 lanes: 173,
## 179-185, 185, 189, 196); with --start=1, 83, 89-95, 95, 99, 106 (--events prints the exact frames: bait_seek,
## bait_lock, shark_hit).

const BOSS_PATH: String = "res://data/bosses/beach_boss.tres"
const SKY_PATH: String = "res://data/skies/beach_sunset.tres"

var scenario: String = "climb"
var world: RunWorld
var boss: MechaGuppy
var bot: MechaGuppyBot
var _cam: Camera3D
var _run_cam: RunCamera
var _t: float = 0.0
var _print_events: bool = false
var _events_seen: int = 0
var _start_step: int = 0
var _cam_set: bool = false


func _ready() -> void:
	var lanes: int = 5
	var phase: int = 0
	var speed: float = 23.8
	var daylight: bool = false
	var attacks: bool = true
	var baits: bool = true
	for arg: String in OS.get_cmdline_user_args():
		var v: String = arg.get_slice("=", 1)
		if arg.begins_with("--scenario="):
			scenario = v
		elif arg == "--no-attacks":
			attacks = false
		elif arg == "--no-bait":
			baits = false
		elif arg.begins_with("--start="):
			_start_step = int(v)
		elif arg.begins_with("--lanes="):
			lanes = int(v)
		elif arg.begins_with("--phase="):
			phase = int(v)
		elif arg.begins_with("--speed="):
			speed = float(v)
		elif arg == "--daylight":
			daylight = true
		elif arg == "--reduced-flashing":
			RenderingServer.global_shader_parameter_set(&"reduced_flashing", 1.0)
			Settings.flashing_reduced = true
		elif arg == "--events":
			_print_events = true
	if scenario == "top" and phase == 0:
		phase = 3
	var slot: BossDef = load(BOSS_PATH) as BossDef
	var def: BossDef = slot.preview() if slot.preview() != null else slot
	var base := load("res://data/tuning/movement.tres") as MovementTuning
	var tuning: MovementTuning = base.duplicate() as MovementTuning
	tuning.run_speed = speed
	var ctx := RunContext.new()
	ctx.mode = RunContext.Mode.QUICK
	ctx.boss = def
	ctx.config = BossArena.base_config(def)
	ctx.config.lane_count = lanes
	ctx.tuning = tuning
	if not daylight:
		ctx.config.sky = load(SKY_PATH) as LevelSky
	if phase > 1:
		ctx.boss_resume = {"phase": phase - 1}
	boss = BossEncounter.create(def) as MechaGuppy
	var arena: BossArena = boss.plan_arena(ctx)
	world = RunWorld.new()
	world.name = "World"
	add_child(world)
	world.build(ctx.config, arena.layout, tuning, load("res://data/tuning/game_rules.tres") as GameRules,
		load("res://data/tuning/powerups.tres") as PowerupTuning, null, load("res://data/audio/sfx_library.tres") as SfxLibrary)
	boss.setup(world, ctx, arena)
	boss.attacks_enabled = attacks
	bot = MechaGuppyBot.new(boss)
	bot.baits = baits
	match scenario:
		"wrong":
			bot.wrong = true
		"grapple":
			bot.wrong = true
			world.player.grapples = 1
		_:
			world.player.grapples = 1_000_000

	var env := WorldEnvironment.new()
	env.environment = world.skin.level_environment(ctx.config.darkness, ctx.config.sky)
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35.0, 15.0, 0.0)
	sun.light_energy = 0.8
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(sun)
	_run_cam = RunCamera.new()
	add_child(_run_cam)
	_run_cam.follow(world)
	_run_cam.make_current()
	if scenario in ["side", "shark", "ship"]:
		_cam = Camera3D.new()
		_cam.fov = 60.0
		_cam.far = 900.0
		add_child(_cam)
		_cam.make_current()
	if _start_step > 0:
		_move_on(_start_step)
	world.start()
	if scenario == "hut":
		world.player.running = false


func _physics_process(delta: float) -> void:
	_t += delta
	match scenario:
		"hut":
			_stand_under_hut()
		_:
			bot.step()
	if scenario == "grapple" and world.player.grapples == 0:
		bot.wrong = false
	if _cam != null:
		var p: Vector3 = world.player.position
		match scenario:
			"shark":
				_shark_cam(p)
			"ship":
				var ship: CaptainCogsShip = boss.ship
				var at: Vector3 = ship.global_position
				_cam.global_position = at + Vector3(9.0, 9.0, -14.0)
				_cam.look_at(at + Vector3(0.0, 3.0, 30.0), Vector3.UP)
			_:
				_cam.global_position = Vector3(p.x + 34.0, p.y + 14.0, p.z + 10.0)
				_cam.look_at(Vector3(p.x - 4.0, p.y + 2.0, p.z - 40.0), Vector3.UP)


func _process(_delta: float) -> void:
	if not _print_events or boss == null:
		return
	while _events_seen < boss.events.size():
		var e: Dictionary = boss.events[_events_seen]
		_events_seen += 1
		print("frame %d: %s" % [Engine.get_process_frames(), e])


## Beside Mecha Guppy while it's up (looking across at its jaws from outside the climb), else alongside the runner.
func _shark_cam(p: Vector3) -> void:
	var shark: MechaGuppyShark = boss.shark
	if shark.shown() and shark.hinge.y > p.y - 40.0:
		var h: Vector3 = shark.hinge
		var side: float = -1.0 if h.x > 0.0 else 1.0
		var target := Vector3(h.x, maxf(h.y + 8.0, p.y - 2.0), h.z)
		var want := Vector3(h.x + side * 26.0, target.y + 9.0, h.z + 22.0)
		_cam.global_position = _cam.global_position.lerp(want, 0.15) if _cam_set else want
		_cam_set = true
		_cam.look_at(target, Vector3.UP)
		return
	var w := Vector3(p.x - 26.0, p.y + 10.0, p.z + 14.0)
	_cam.global_position = _cam.global_position.lerp(w, 0.1) if _cam_set else w
	_cam_set = true
	_cam.look_at(Vector3(p.x, p.y - 2.0, p.z - 30.0), Vector3.UP)


## Moves the runner on to step `k`'s roof, past its landing, before the frames are written (a view from higher up).
func _move_on(k: int) -> void:
	var climb: MechaGuppyClimb = boss.climb
	while climb.steps.size() <= k and not climb.top_planned():
		climb.plan_next(boss.phase_index)
	if k >= climb.steps.size():
		return
	var into: MechaGuppyClimb.Step = climb.steps[k - 1]
	var p: Player = world.player
	p.distance = into.land + 2.0
	p.floor_y = into.top_y
	p.h = into.top_y
	p.lane = into.up.x
	p.set(&"_x", world.geo.lane_x(into.up.x))
	p.floor_base = into.top_y
	boss.stairs.update(p.distance)
	_run_cam.snap()


## The runner on the first hut (step --start=S's with it), standing still under it halfway along (the pads already
## behind them): what a rider sees of the hut's lanes and the roof ahead. A runner who isn't running doesn't move, so
## the runner and the camera are put there by hand.
func _stand_under_hut() -> void:
	var p: Player = world.player
	var step: MechaGuppyClimb.Step = boss.climb.steps[mini(_start_step, boss.climb.steps.size() - 1)]
	if p.surface != Player.Surface.CEILING:
		p.distance = step.pad_end + 6.0
		p.ceiling_y = step.hut_y
		p.surface = Player.Surface.CEILING
		p.h = 0.0
		p.grounded = true
		p.floor_y = step.floor_y
		p.floor_base = step.floor_y
		p.call(&"_apply_transform", 1.0)
		_run_cam.snap()
	p.running = false
