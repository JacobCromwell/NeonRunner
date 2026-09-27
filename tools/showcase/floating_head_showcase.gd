extends Node3D
## The Floating Head up close and in scripted runs, for visual review (GDD §10, task E1; not part of
## the game). It builds the fight the way the game does (its arena on the City's truck roofs, the
## City's look) with the runner in god mode. The fight itself: ./play.sh --boss=city_boss (debug
## builds). Render frames on both renderers, e.g.:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot4 --path . --resolution 960x540 --fixed-fps 10 \
##     --write-movie build/fh/f.png --quit-after 60 res://tools/showcase/floating_head_showcase.tscn \
##     -- --scenario=stern --lanes=3
## (add --rendering-method gl_compatibility before the scene for the web / low-end renderer).
## Scenarios:
##   model     (default) a camera circling the ship hovering over the street, its face on, its
##             searchlight lit and its bomb bay open
##   stern     its face from behind at the runner's eye height, powering on (the reveal), then watching
##   below     its belly from under it: the searchlight, the bomb bay, the lift pads
##   entrance  the fight from its start, through the run camera: it roars in overhead, the run begins
##   bombing   the run with a runner who dodges every lock (to its free side), through the run camera
##   reveal    a short run, then it drops in front of the runner and its face powers on
## Options: --lanes=N (3, 5 or 6; 3 by default), --seconds=S (the first run's length in `reveal`).

const BOSS_PATH: String = "res://data/bosses/city_boss.tres"

var scenario: String = "model"
var world: RunWorld
var head: FloatingHead
var _cam: Camera3D
var _run_cam: RunCamera
var _t: float = 0.0
var _dodged: Dictionary = {}


func _ready() -> void:
	var lanes: int = 3
	var reveal_seconds: float = 3.0
	for arg: String in OS.get_cmdline_user_args():
		var v: String = arg.get_slice("=", 1)
		if arg.begins_with("--scenario="):
			scenario = v
		elif arg.begins_with("--lanes="):
			lanes = int(v)
		elif arg.begins_with("--seconds="):
			reveal_seconds = float(v)
	var def: BossDef = (load(BOSS_PATH) as BossDef).preview()
	if scenario == "reveal":
		# A short run, so the reveal comes soon.
		var t: FloatingHeadTuning = (def.tuning as FloatingHeadTuning).duplicate() as FloatingHeadTuning
		t.first_run_seconds = reveal_seconds
		def.tuning = t
	var tuning := load("res://data/tuning/movement.tres") as MovementTuning
	var ctx := RunContext.new()
	ctx.mode = RunContext.Mode.QUICK
	ctx.boss = def
	ctx.config = BossArena.base_config(def)
	ctx.config.lane_count = lanes
	ctx.config.skin = load("res://data/skins/city_skin.tres") as ZoneSkin
	ctx.tuning = tuning
	head = BossEncounter.create(def) as FloatingHead
	var arena: BossArena = head.plan_arena(ctx)
	world = RunWorld.new()
	world.name = "World"
	add_child(world)
	world.build(ctx.config, arena.layout, tuning, load("res://data/tuning/game_rules.tres") as GameRules,
		load("res://data/tuning/powerups.tres") as PowerupTuning, null, load("res://data/audio/sfx_library.tres") as SfxLibrary)
	world.player.god_mode = true
	world.player.grapples = 1_000_000
	head.setup(world, ctx, arena)

	var env := WorldEnvironment.new()
	env.environment = world.skin.make_environment()
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
	match scenario:
		"model", "below":
			# Still: the runner stands, the ship hovers over the street ahead, everything on.
			_cam = Camera3D.new()
			_cam.fov = 60.0
			_cam.far = 600.0
			add_child(_cam)
			_cam.make_current()
		"stern":
			_cam = Camera3D.new()
			_cam.fov = 55.0
			_cam.far = 600.0
			add_child(_cam)
			_cam.make_current()
	if scenario == "model" or scenario == "below" or scenario == "stern":
		world.start()
		# The runner stands still: nothing moves but the ship's own parts.
		world.player.running = false
	else:
		world.start()


func _physics_process(delta: float) -> void:
	_t += delta
	match scenario:
		"model", "below":
			_pose_still(Vector3(0.0, 6.0 if scenario == "model" else 7.0, 30.0), 1.0)
			head.body.lamp = FloatingHeadBody.Lamp.SWEEP
			head.body.lamp_target = world.lane_point(world.geo.lane_count / 2, world.player.distance + 18.0)
			head.body.bay_open = true
		"stern":
			# The reveal from the runner's eyes: the screen stays dark a moment, then powers on.
			_pose_still(Vector3(0.0, head.tuning.face_height, head.tuning.face_ahead), clampf((_t - 1.0) / head.tuning.boot_seconds, 0.0, 1.0))
		"bombing":
			_dodge()


func _process(_delta: float) -> void:
	if _cam == null or head == null or not is_instance_valid(head.body):
		return
	var s: FloatingHeadModel.Shape = head.body.shape
	var c: Vector3 = head.body.global_position + Vector3(0.0, s.height * 0.5, -s.length * 0.45)
	match scenario:
		"model":
			# Circling the ship, a little above its middle.
			var a: float = 0.6 + _t * 0.35
			var r: float = s.length * 1.35
			_cam.global_position = c + Vector3(sin(a) * r, s.height * 0.35, cos(a) * r)
			_cam.look_at(c, Vector3.UP)
		"below":
			_cam.global_position = head.body.global_position + Vector3(s.width * 0.9, -5.5, 10.0)
			_cam.look_at(head.body.global_position + Vector3(0.0, 0.0, -s.length * 0.4), Vector3.UP)
		"stern":
			_cam.global_position = Vector3(0.0, 2.0, world.player.global_position.z + 4.0)
			_cam.look_at(head.body.screen_world() + Vector3(0.0, -2.0, 0.0), Vector3.UP)


## Holds the ship `pose` from the runner (sideways, belly height, stern ahead) with its face at `power`.
func _pose_still(pose: Vector3, power: float) -> void:
	head.body.set_pose(Vector3(pose.x, pose.y, TrackGeometry.world_z(world.player.distance + pose.z)))
	head.body.screen_power = power


## The dodging runner: when a lock strikes its lane, it switches to the free lane the rules left it.
func _dodge() -> void:
	var b: FloatingHeadBombing = head.bombing
	if b.target.is_empty() or _dodged.has(b.target["lock"]):
		return
	var lanes: Array = b.target["lanes"]
	var pl: int = head.player_lane()
	if not lanes.has(pl):
		return
	var typed: Array[int] = []
	for l: int in lanes:
		typed.append(l)
	var e: int = b.escape_lane(typed, pl, world.player.distance, float(b.target["at"]))
	_dodged[b.target["lock"]] = true
	if e < 0:
		return
	for i: int in absi(e - pl):
		world.player.press(&"move_right" if e > pl else &"move_left")
