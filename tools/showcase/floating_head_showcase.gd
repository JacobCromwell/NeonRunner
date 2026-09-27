extends Node3D
## The Floating Head up close and in scripted runs, for visual review (GDD §10, task E1; not part of
## the game). It builds the fight the way the game does (its arena on the City's truck roofs, in its
## arena's City look) with the runner in god mode. The fight itself: ./play.sh --boss=city_boss (debug
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
##   faceoff   straight to the face-off (no bombing run), through the run camera, with a runner who
##             answers every attack by its warning (FloatingHeadBot) and baits each marked tower
##   fallback  the same, with a runner who keeps away from the towers, so the laser clips one on its own
##   pinned    a marked tower topples onto it and pins it, seen from the runner's spot (standing still)
##   mouth     its face from the runner's eye height at the drop station, the jaw opening and closing
##             and its eyes charging in turn (the warnings, up close)
## Options: --lanes=N (3, 5 or 6; 3 by default), --seconds=S (the first run's length in `reveal`),
## --pattern=low,drag,high,drop (the face-off's attacks), --towers=off (no marked towers),
## --towers-after=N (the attacks it shows before it takes aim at a tower; 0 baits the first tower at
## once, about 11 s in), --phase=N (start at phase N, as a checkpoint would: 1 or 2 drop two cyborgs;
## with no bombing run first in faceoff and fallback).
## Frames worth a look (at --fixed-fps 10): faceoff at 3 lanes, a low sweep 78-95, a drag 106-128 (its
## aiming spot, then the lane warning and the burning line), a high sweep 138-160; faceoff with
## --towers-after=0, the bait and the pin about 85-125; faceoff with --pattern=drop,low, the drop
## about 78-100; pinned, the tower falling 72-84.

const BOSS_PATH: String = "res://data/bosses/city_boss.tres"

var scenario: String = "model"
var world: RunWorld
var head: FloatingHead
var bot: FloatingHeadBot
var _cam: Camera3D
var _run_cam: RunCamera
var _t: float = 0.0
var _dodged: Dictionary = {}
var _pinned: bool = false


func _ready() -> void:
	var lanes: int = 3
	var reveal_seconds: float = 3.0
	var pattern: String = ""
	var towers: bool = true
	var towers_after: int = -1
	var phase: int = 0
	for arg: String in OS.get_cmdline_user_args():
		var v: String = arg.get_slice("=", 1)
		if arg.begins_with("--scenario="):
			scenario = v
		elif arg.begins_with("--lanes="):
			lanes = int(v)
		elif arg.begins_with("--seconds="):
			reveal_seconds = float(v)
		elif arg.begins_with("--pattern="):
			pattern = v
		elif arg == "--towers=off":
			towers = false
		elif arg.begins_with("--towers-after="):
			towers_after = int(v)
		elif arg.begins_with("--phase="):
			phase = int(v)
	var def: BossDef = (load(BOSS_PATH) as BossDef).preview()
	var t: FloatingHeadTuning = (def.tuning as FloatingHeadTuning).duplicate() as FloatingHeadTuning
	if scenario == "reveal":
		# A short run, so the reveal comes soon.
		t.first_run_seconds = reveal_seconds
	elif scenario in ["faceoff", "fallback", "pinned"]:
		# Straight to the face-off.
		t.first_run_seconds = 0.0
		t.later_runs = 0
	if pattern != "":
		t.faceoff_patterns = PackedStringArray([pattern])
	if not towers:
		t.tower_first = 100000.0
	if towers_after >= 0:
		t.towers_after = towers_after
	def.tuning = t
	var tuning := load("res://data/tuning/movement.tres") as MovementTuning
	var ctx := RunContext.new()
	ctx.mode = RunContext.Mode.QUICK
	ctx.boss = def
	ctx.config = BossArena.base_config(def)
	ctx.config.lane_count = lanes
	if ctx.config.skin == null:
		ctx.config.skin = load("res://data/skins/city_skin.tres") as ZoneSkin
	ctx.tuning = tuning
	if phase > 0:
		ctx.boss_resume = {"phase": phase}
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
	if scenario == "faceoff" or scenario == "fallback":
		bot = FloatingHeadBot.new(head, scenario == "faceoff")

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
		"stern", "pinned", "mouth":
			_cam = Camera3D.new()
			_cam.fov = 55.0
			_cam.far = 600.0
			add_child(_cam)
			_cam.make_current()
	world.start()
	if scenario in ["model", "below", "stern", "mouth"]:
		# The runner stands still: nothing moves but the ship's own parts.
		world.player.running = false


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
		"mouth":
			# The drop's warning (the jaw), then the lasers' (the eyes), over and over.
			_pose_still(Vector3(0.0, head.tuning.drop_height, 18.0), 1.0)
			var k: float = fmod(_t, 4.0)
			head.body.jaw_open = clampf(k / 0.8, 0.0, 1.0) * clampf((2.0 - k) / 0.4, 0.0, 1.0)
			head.body.eye_charge = clampf((k - 2.2) / 1.0, 0.0, 1.0) * (1.0 if k < 3.8 else 0.0)
		"bombing":
			_dodge()
		"faceoff", "fallback":
			bot.step()
		"pinned":
			_pin_now()


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
		"stern", "mouth":
			_cam.global_position = Vector3(0.0, 2.0, world.player.global_position.z + 4.0)
			_cam.look_at(head.body.screen_world() + Vector3(0.0, -2.0, 0.0), Vector3.UP)
		"pinned":
			# From the runner's spot, a little up: the tower falling onto it and the pinned head.
			_cam.global_position = Vector3(0.0, 3.2, world.player.global_position.z + 6.0)
			_cam.look_at(Vector3(0.0, 2.5, TrackGeometry.world_z(world.player.distance + 40.0)), Vector3.UP)


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


## Once the face-off begins, the ship takes aim from its tower station and a marked tower beside it is
## clipped: it falls and pins the ship. The runner stops once it's pinned, so it stays pinned (the
## runner never comes close enough for it to shake free).
func _pin_now() -> void:
	if _pinned:
		if head.step == FloatingHead.Step.PINNED and world.player.running:
			world.player.running = false
		return
	if head.step != FloatingHead.Step.FACE_OFF:
		return
	_pinned = true
	head.faceoff.stop()
	head.pose = head.faceoff.station(&"tower")
	var tower := {"at": world.player.distance + head.pose.z + 1.0, "side": -1, "key": "review"}
	var node: FloatingHeadTower = head.tower_node(tower)
	node.clip()
	head.sound(&"tower_crack", node.strike_point())
	head.begin_pin(node)
