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
##   hut        the runner standing under the first hut (the run camera's view from under it): reading the cue
##   top        phase 3's stub (--phase=3 implied): the climb's last steps, then the flat top, the waterfall gone
## Options: --lanes=N (3, 5 or 6; 5 by default), --speed=M (the run's speed, m/s; the Beach's 23.8 by default),
## --phase=N, --daylight (the Beach's own sky instead of Sunset Strip's), --reduced-flashing, --events (prints the
## boss's events with their frames, for picking frames).
## Frames worth a look (at --fixed-fps 10, 23.8 m/s): climb, the first pads about frame 35, on the first hut 40-63,
## its end and the drop about 63, the first roof 66-90, the second hut 95-125; wrong, the drop and the fall about
## 60-72; grapple, the save about 68-78; side, any frame. To look from higher up, move the runner onto a later
## step's roof before the frames are written (as a review script can: plan the steps, set Player.distance, floor_y
## and h, then RunCamera.snap()).

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


func _ready() -> void:
	var lanes: int = 5
	var phase: int = 0
	var speed: float = 23.8
	var daylight: bool = false
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
	bot = MechaGuppyBot.new(boss)
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
	if scenario == "side":
		_cam = Camera3D.new()
		_cam.fov = 60.0
		_cam.far = 900.0
		add_child(_cam)
		_cam.make_current()
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
		_cam.global_position = Vector3(p.x + 34.0, p.y + 14.0, p.z + 10.0)
		_cam.look_at(Vector3(p.x - 4.0, p.y + 2.0, p.z - 40.0), Vector3.UP)


func _process(_delta: float) -> void:
	if not _print_events or boss == null:
		return
	while _events_seen < boss.events.size():
		var e: Dictionary = boss.events[_events_seen]
		_events_seen += 1
		print("frame %d: %s" % [Engine.get_process_frames(), e])


## The runner on the first hut, standing still under it halfway along (the pads already behind them): what a rider
## sees of the hut's lanes and the roof ahead.
func _stand_under_hut() -> void:
	var p: Player = world.player
	var step: MechaGuppyClimb.Step = boss.climb.steps[0]
	if p.surface != Player.Surface.CEILING:
		p.distance = step.pad_end + 6.0
		p.ceiling_y = step.hut_y
		p.surface = Player.Surface.CEILING
		p.h = 0.0
		p.grounded = true
		p.floor_y = step.floor_y
	p.running = false
