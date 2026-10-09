extends Node3D
## The Floating Head up close and in scripted runs, for visual review (GDD §10, task E1; not part of
## the game). It builds the fight the way the game does (its arena on the City's truck roofs, in its
## arena's City look, at the City boss step's speed: 21 m/s, GDD §3) with the runner in god mode. The fight itself: ./play.sh --boss=city_boss (debug
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
##             (--phase=1 or 2: a later run's salvos, the runner weaving through their spots)
##   reveal    a short run, then it drops in front of the runner and its face powers on
##   faceoff   straight to the face-off (no bombing run), through the run camera, with a runner who
##             answers every attack by its warning (FloatingHeadBot), baits each marked tower and takes
##             the stomp window's way onto its head (the phase's: --phase=0 the ramp, 1 a wall jump, 2
##             the ceiling)
##   fallback  the same, with a runner who keeps away from the towers, so the laser clips one on its own
##   missed    the same, with a runner who stays down on the trucks: the window closes and it shakes
##             free
##   pinned    a marked tower topples onto it and pins it, seen from the runner's spot (standing still),
##             and the stomp window opens (--phase picks its way up)
##   window    the same pin, the camera circling the pinned ship: the open weak points, the crown, and
##             the way up (--phase=0 the ramp, 2 the pads and the ceiling)
##   mouth     its face from the runner's eye height at the drop station, the jaw opening and closing
##             and its eyes charging in turn (the warnings, up close)
##   slogans   its face from the runner's eye height with each propaganda slogan on its caption band in
##             turn (the placeholder slogans), the last one breaking up in the defeat's glitch
##   defeat    the last phase through the run camera (--phase=2 by default): a runner who reads the
##             fight baits the first marked tower, rides the ceiling and stomps the last weak point; the
##             defeat plays out (the face glitches, the propaganda cuts out, it lurches up, loses power
##             and crashes into the street ahead) and the runner runs over its fallen face and through
##             the wreck
##   wreck     the defeat on its own: in the last phase, it's beaten as soon as it drops in front of the
##             runner (as by weapons), then glitches, falls and crashes; the runner runs through the
##             wreck
## Options: --lanes=N (3, 5 or 6; 3 by default), --seconds=S (the first run's length in `reveal`),
## --pattern=low,drag,high,drop (the face-off's attacks), --towers=off (no marked towers),
## --towers-after=N (the attacks it shows before it takes aim at a tower; 0 baits the first tower at
## once, about 11 s in), --phase=N (start at phase N, as a checkpoint would: 1 or 2 drop two cyborgs;
## with no bombing run first in faceoff, fallback and missed), --wall=left|right (the wall the wall
## jump takes; the nearer one by default), --board-late[=S] (task E1e: in the first window the runner
## waits beside the ramp and switches onto it once a share S of it is behind it, 0.4 by default, the way
## the owner's playtest met it), --e1c (E1c's ramp, one straight slab whose sides block from a step
## high, and its smaller stomp boxes: the before of E1e's reviews), --speed=N (the run speed in m/s;
## the campaign's City boss step's by default, 18 for the reference speed the fight was first built at).
## Frames worth a look (at --fixed-fps 10): faceoff at 3 lanes, a low sweep 78-95, a drag 106-128 (its
## aiming spot, then the lane warning and the burning line), a high sweep 138-160; faceoff with
## --towers-after=0, the bait and the pin about 85-125, then the stomp window: the ramp (phase 0),
## the wall jump (1) or the ceiling (2) about 105-140; faceoff with --pattern=drop,low, the drop
## about 78-100; pinned and window, the next marked tower falling about 105-118 (with the ceiling's
## pads and the ceiling lowering in at --phase=2) and the window open from about 120; slogans, one
## slogan every 25 frames from about 10 (the glitch from 125); defeat, the ceiling and the stomp about
## 115-140, the glitch 145-165, the fall 165-175, the crash, its face and the run through the wreck
## about 175-200; wreck, the glitch from about 50, the fall 65-75, the crash, its face and the run
## through the wreck about 75-100.

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
	var wall: int = 0
	var board_late: float = -1.0
	var e1c: bool = false
	var speed: float = 0.0
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--scenario="):
			scenario = arg.get_slice("=", 1)
	if scenario in ["defeat", "wreck"]:
		# The last phase (a checkpoint's start), its first marked tower baited at once.
		phase = 2
		towers_after = 0
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
		elif arg.begins_with("--wall="):
			wall = -1 if v == "left" else 1
		elif arg == "--board-late":
			board_late = 0.4
		elif arg.begins_with("--board-late="):
			board_late = float(v)
		elif arg == "--e1c":
			e1c = true
		elif arg.begins_with("--speed="):
			speed = float(v)
	var def: BossDef = (load(BOSS_PATH) as BossDef).duplicate() as BossDef
	var t: FloatingHeadTuning = (def.tuning as FloatingHeadTuning).duplicate() as FloatingHeadTuning
	if scenario == "reveal":
		# A short run, so the reveal comes soon.
		t.first_run_seconds = reveal_seconds
	elif scenario in ["faceoff", "fallback", "missed", "pinned", "window", "defeat", "wreck"]:
		# Straight to the face-off.
		t.first_run_seconds = 0.0
		t.later_runs = 0
	if pattern != "":
		t.faceoff_patterns = PackedStringArray([pattern])
	if not towers:
		t.tower_first = 100000.0
	if towers_after >= 0:
		t.towers_after = towers_after
	if e1c:
		t.ramp_board_share = 0.0
		t.stomp_covers_outer_lanes = false
		t.stomp_depth = 3.0
		t.stomp_top = 0.55
	def.tuning = t
	var tuning: MovementTuning = _tuning_at(load("res://data/tuning/movement.tres") as MovementTuning, speed)
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
	if scenario in ["faceoff", "fallback", "missed", "defeat", "wreck"]:
		bot = FloatingHeadBot.new(head, scenario != "fallback")
		bot.wrong_route = scenario == "missed"
		bot.wall_side = wall
		bot.ramp_board_at = board_late

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
		"stern", "pinned", "mouth", "window", "slogans":
			_cam = Camera3D.new()
			_cam.fov = 55.0
			_cam.far = 600.0
			add_child(_cam)
			_cam.make_current()
	world.start()
	if scenario in ["model", "below", "stern", "mouth", "slogans"]:
		# The runner stands still: nothing moves but the ship's own parts.
		world.player.running = false


## The movement tuning at `speed` m/s, or (0) at the City boss step's speed as the campaign plays it
## (Campaign.configure_boss: its zone's).
func _tuning_at(base: MovementTuning, speed: float) -> MovementTuning:
	if speed <= 0.0:
		var campaign := load("res://data/campaign/campaign.tres") as Campaign
		var step: CampaignStep = campaign.step("city/boss") if campaign != null else null
		speed = campaign.configure_boss(step, 3).movement_for(base).run_speed if step != null else base.run_speed
	if is_equal_approx(speed, base.run_speed):
		return base
	var out: MovementTuning = base.duplicate() as MovementTuning
	out.run_speed = speed
	return out


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
		"slogans":
			# Each slogan in turn, 2.5 s apiece; after the last, the defeat's glitch breaks it up.
			_pose_still(Vector3(0.0, head.tuning.face_height, head.tuning.face_ahead - 6.0), 1.0)
			var slogans: PackedStringArray = head.tuning.slogans
			var i: int = int(_t / 2.5)
			head.body.show_slogan(slogans[mini(i, slogans.size() - 1)] if not slogans.is_empty() else "")
			head.body.caption = clampf(fmod(_t, 2.5) / 0.25, 0.0, 1.0) if i < slogans.size() else 1.0
			head.body.glitch = 1.0 if i >= slogans.size() else 0.0
		"bombing":
			_dodge()
		"faceoff", "fallback", "missed", "defeat":
			bot.step()
		"wreck":
			# Beaten as soon as it's in front of the runner, as weapons would do it.
			if head.step == FloatingHead.Step.FACE_OFF and head.state == BossEncounter.State.FIGHT:
				head.damage(head.health, &"stomp")
			bot.step()
		"pinned", "window":
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
		"stern", "mouth", "slogans":
			_cam.global_position = Vector3(0.0, 2.0, world.player.global_position.z + 4.0)
			_cam.look_at(head.body.screen_world() + Vector3(0.0, -2.0, 0.0), Vector3.UP)
		"pinned":
			# From the runner's spot, a little up: the tower falling onto it and the pinned head.
			_cam.global_position = Vector3(0.0, 3.2, world.player.global_position.z + 6.0)
			_cam.look_at(Vector3(0.0, 2.5, TrackGeometry.world_z(world.player.distance + 40.0)), Vector3.UP)
		"window":
			# Circling the pinned ship's face a little above its crown: the open weak points, its crown
			# and the way up; before the pin, from the runner's spot.
			if head.step != FloatingHead.Step.PINNED:
				_cam.global_position = Vector3(0.0, 3.2, world.player.global_position.z + 6.0)
				_cam.look_at(Vector3(0.0, 2.5, TrackGeometry.world_z(world.player.distance + 40.0)), Vector3.UP)
			else:
				# Swinging from side to side over the street behind its face, looking down at its crown (under
				# the ceiling, further back, when the way up is the ceiling).
				var focus := Vector3(0.0, 1.8, TrackGeometry.world_z(head.pin_stern + 1.0))
				var a: float = 0.55 * sin(_t * 0.35)
				var gap: float = world.geo.wall_x() - 1.0
				var low: bool = head.route == &"ceiling"
				var r: float = 20.0 if low else 13.0
				_cam.global_position = focus + Vector3(clampf(sin(a) * r, -gap, gap), 2.2 if low else 7.0, cos(a) * r)
				_cam.look_at(focus, Vector3.UP)


## Holds the ship `pose` from the runner (sideways, belly height, stern ahead) with its face at `power`.
func _pose_still(pose: Vector3, power: float) -> void:
	head.body.set_pose(Vector3(pose.x, pose.y, TrackGeometry.world_z(world.player.distance + pose.z)))
	head.body.screen_power = power


## The dodging runner: when a lock strikes its lane, it switches to the free lane the rules left it; in
## a salvo it weaves along a way through the spots still ahead (FloatingHeadBombing.dodge_lane).
func _dodge() -> void:
	var b: FloatingHeadBombing = head.bombing
	if b.target.has("spots"):
		var pl: int = head.player_lane()
		var to: int = b.dodge_lane(pl, world.player.distance)
		if to >= 0 and to != pl:
			world.player.press(&"move_right" if to > pl else &"move_left")
		return
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


## Once the face-off begins, the ship waits at its tower station (no attacks) and the next marked
## tower is clipped as it passes the ship's face: it falls and pins the ship (on the track cleared
## around the tower, as in the fight). The runner stops once it's pinned, so the window stays open (the
## runner never comes close enough for it to close).
func _pin_now() -> void:
	if _pinned:
		if head.step == FloatingHead.Step.PINNED and world.player.running:
			world.player.running = false
		return
	if head.step != FloatingHead.Step.FACE_OFF:
		return
	if head.faceoff.running:
		head.faceoff.stop()
		head.pose = head.faceoff.station(&"tower")
	var face: float = world.player.distance + head.pose.z
	for tower: Dictionary in head.towers_between(face - 5.0, face + 400.0):
		if float(tower["at"]) > face + 1.0:
			return
		_pinned = true
		var node: FloatingHeadTower = head.tower_node(tower)
		node.clip()
		head.sound(&"tower_crack", node.strike_point())
		head.begin_pin(node)
		return
