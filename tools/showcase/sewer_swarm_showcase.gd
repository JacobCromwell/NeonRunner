extends Node3D
## The Sewer Swarm up close and in scripted runs, for visual review (GDD §10, task E4; not part of the game).
## It builds the fight the way the game does (its arena on Gangland's street, in its arena's look), with a
## runner who plays it by its warnings (SewerSwarmBot). The fight itself: ./play.sh --boss=gangland_boss
## (debug builds). Render frames on both renderers, e.g.:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot4 --path . --resolution 960x540 --fixed-fps 10 \
##     --write-movie build/swarm/f.png --quit-after 95 res://tools/showcase/sewer_swarm_showcase.tscn \
##     -- --scenario=fence --lanes=5
## (add --rendering-method gl_compatibility before the scene for the web / low-end renderer).
## Scenarios:
##   rising  (default) the fight's start through the run camera: the lairs rattling and bursting along both
##           sides, screeches pouring out, the gutters filling and the clusters rising at the roadside
##   surge   a surge nobody baits: the warning (the red line following the runner, the cluster rearing),
##           the lock, the charge; the runner dodges and it passes beside them
##   fence   a surge baited into a live fence: the runner holds the fence's lane through the warning, gets
##           out of it at the lock, and the cluster runs into the fence
##   hole    the same into a hole
##   fight   the fight as it comes, the runner baiting every surge
##   model   a close-up beside the street: a cluster heaped at the wall's foot, rearing, then pouring into
##           the lane and charging past
##   behind  phase 2 from its start, the runner baiting: a strike from behind first (the wave rising behind
##           the runner and curling over their lane, its crash, its surge on into the fence), then the climbs
##   host    phase 3 from its start: the pipe across the street ahead, the Host bursting out of it, then its
##           fight (the runner baits its lunges into fences and takes the ramps onto its implants)
##   stomp   phase 3, the runner only stomping (its lunges dodged, never baited)
##   defeat  phase 3 with one hit left: the first hit frees the Host
##   hostmodel  a close-up of the Host beside the street (phase 3), from the side
## Options: --lanes=N (3, 5 or 6; 5 by default), --speed=N (18 by default; the campaign's 21.8), --crowd=N
## (screeches a cluster), --low-end (the tuning's low-end crowds), --reduced-flashing, --events (prints each of
## the boss's events with its frame, for picking frames), --stay (the runner stands in the surge: it hits),
## --phase=N (start at phase N: 1 Surrounded, 2 The Host).
## Frames worth a look (at --fixed-fps 10, 18 m/s): rising 0-50; the first surge's warning from about frame
## 67, its lock about 80 and its bait or pass about 87; at 21.8 m/s about the same (its times are seconds).

const BOSS_PATH: String = "res://data/bosses/gangland_boss.tres"

var scenario: String = "rising"
var world: RunWorld
var boss: SewerSwarm
var bot: SewerSwarmBot
var _cam: Camera3D
var _run_cam: RunCamera
var _t: float = 0.0
var _print_events: bool = false
var _events_seen: int = 0
var _frame: int = 0


func _ready() -> void:
	var lanes: int = 5
	var speed: float = 18.0
	var crowd: int = -1
	var low_end: bool = false
	var stay: bool = false
	var phase: int = -1
	for arg: String in OS.get_cmdline_user_args():
		var v: String = arg.get_slice("=", 1)
		if arg.begins_with("--scenario="):
			scenario = v
		elif arg.begins_with("--lanes="):
			lanes = int(v)
		elif arg.begins_with("--speed="):
			speed = float(v)
		elif arg.begins_with("--crowd="):
			crowd = int(v)
		elif arg == "--low-end":
			low_end = true
		elif arg == "--reduced-flashing":
			RenderingServer.global_shader_parameter_set(&"reduced_flashing", 1.0)
			Settings.flashing_reduced = true
		elif arg == "--events":
			_print_events = true
		elif arg == "--stay":
			stay = true
		elif arg.begins_with("--phase="):
			phase = int(v)
	var slot: BossDef = load(BOSS_PATH) as BossDef
	var def: BossDef = slot.preview() if slot.preview() != null else slot.duplicate() as BossDef
	var t: SewerSwarmTuning = (def.tuning as SewerSwarmTuning).duplicate() as SewerSwarmTuning
	match scenario:
		"fence":
			t.bait_kinds = PackedStringArray(["fence"])
		"hole":
			t.bait_kinds = PackedStringArray(["hole"])
	if crowd > 0:
		t.cluster_creatures = crowd
		t.cluster_creatures_low_end = crowd
	def.tuning = t
	var tuning := (load("res://data/tuning/movement.tres") as MovementTuning).duplicate() as MovementTuning
	tuning.run_speed = speed
	var ctx := RunContext.new()
	ctx.mode = RunContext.Mode.QUICK
	ctx.boss = def
	ctx.config = BossArena.base_config(def)
	ctx.config.lane_count = lanes
	ctx.tuning = tuning
	if phase < 0:
		phase = 1 if scenario == "behind" else (2 if scenario in ["host", "stomp", "defeat", "hostmodel"] else 0)
	if phase > 0:
		ctx.boss_resume = {"phase": phase}
	boss = BossEncounter.create(def) as SewerSwarm
	boss.low_end = low_end
	var arena: BossArena = boss.plan_arena(ctx)
	world = RunWorld.new()
	world.name = "World"
	add_child(world)
	world.build(ctx.config, arena.layout, tuning, load("res://data/tuning/game_rules.tres") as GameRules,
		load("res://data/tuning/powerups.tres") as PowerupTuning, null, load("res://data/audio/sfx_library.tres") as SfxLibrary)
	boss.setup(world, ctx, arena)
	world.player.god_mode = true
	if scenario == "defeat":
		boss.health = boss.hit_damage() * 1.001
	if scenario not in ["model", "hostmodel"]:
		bot = SewerSwarmBot.new(boss)
		bot.baits = scenario in ["fence", "hole", "fight", "behind", "host", "defeat"]
		bot.dodges = not stay
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
	if scenario in ["model", "hostmodel"]:
		_cam = Camera3D.new()
		_cam.fov = 55.0
		_cam.far = 400.0
		add_child(_cam)
		_cam.make_current()
	world.start()


func _physics_process(delta: float) -> void:
	_t += delta
	_frame += 1
	if bot != null:
		bot.step()
	if scenario == "model":
		_model_camera()
	elif scenario == "hostmodel":
		_host_camera()
	if _print_events:
		while _events_seen < boss.events.size():
			var e: Dictionary = boss.events[_events_seen]
			if e["event"] != &"sound":
				print("frame %d (%.2f s): %s" % [_frame, _t, str(e)])
			_events_seen += 1


## The close-up: a camera at the side of the street, low, looking at where the first cluster gathers.
func _model_camera() -> void:
	var c: SwarmCluster = null
	for cl: SwarmCluster in boss.clusters:
		if is_instance_valid(cl) and cl.alive:
			c = cl
			break
	if c == null:
		return
	var target := Vector3(c.side * (world.geo.wall_x() - 1.5), 0.6, TrackGeometry.world_z(c.at))
	_cam.global_position = target + Vector3(-c.side * 6.5, 2.4, 6.0)
	_cam.look_at(target, Vector3.UP)


## The Host's close-up: a camera at the far side of the street, between it and the runner, looking at it.
func _host_camera() -> void:
	var h: SwarmHost = boss.host
	if h == null or not h.visible:
		_cam.global_position = _run_cam.global_position
		_cam.global_rotation = _run_cam.global_rotation
		return
	var target := Vector3(h.x, h.lift + 1.8, TrackGeometry.world_z(h.at))
	var side: float = -1.0 if h.x >= 0.0 else 1.0
	_cam.global_position = Vector3(side * (world.geo.wall_x() - 0.4), 2.4, target.z + 8.5)
	_cam.look_at(target, Vector3.UP)
