extends Node3D
## The Sleep Taker up close and in scripted runs, for visual review (GDD §10, task E5c; not part of the
## game). It builds the fight the way the game does (its arena on the Dead Zone's street, in its arena's
## look and darker light) with the runner in god mode. The fight itself: ./play.sh --boss=dead_zone_boss
## (debug builds). Render frames on both renderers, e.g.:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot4 --path . --resolution 960x540 --fixed-fps 10 \
##     --write-movie build/st/f.png --quit-after 60 res://tools/showcase/sleep_taker_showcase.tscn \
##     -- --scenario=model --lanes=5
## (add --rendering-method gl_compatibility before the scene for the web / low-end renderer).
## Scenarios:
##   model       (default) a camera circling the nightmare looming over the street, its maws
##               breathing (--pose=shriek|inhale|raise|slash holds a pose)
##   front       the nightmare from the runner's eye height, still, its pose cycling (rest, the
##               shriek with its arms raised, the inhale)
##   entrance    the fight from its start through the run camera: it rises out of the street ahead
##   slash       through the run camera, a runner who answers the slash by its warning (--escape=pad
##               the refuge's pad, lanes another lane, none stays put); the first refuge comes about
##               5 s after the entrance; nothing else attacks
##   hands       through the run camera, hands only (no refuges), the runner switching lanes at each
##               mist (--escape=none: it stays and is grasped)
##   lights_out  through the run camera: the inhale, the dark with hands coming, the light back
##   fight       the fight as it comes, with a runner who reads it (pad escapes)
##   measure     readability in numbers (GDD §10: hazards keep glowing; the arena never pitch black):
##               a fence, a slash's lane marks, a hand's mist, a refuge's pad, its bridge's end band,
##               a gap's edge, a fence generator and the street in view, through the run camera in
##               the arena's light and at the darkest point of lights out; prints each one's brightness
##               on screen (the mean of its brightest pixels, 0-255) in both lights
## Options: --lanes=N (3, 5 or 6; 5 by default), --phase=N (start at phase N, as a checkpoint would),
## --pose=..., --escape=pad|lanes|none, --reduced-flashing.
## Frames worth a look (at --fixed-fps 10): entrance 0-50; slash, the warning about 95-115 and the
## strike about 112-118; hands, a mist and its hand about 70-90 and every 3 s after; lights_out, the
## inhale about 60-80, the dark 80-160, the light back about 160-175; measure, the arena's light
## about frame 20 and the darkest point about frame 60.

const BOSS_PATH: String = "res://data/bosses/dead_zone_boss.tres"

var scenario: String = "model"
var world: RunWorld
var boss: SleepTaker
var bot: SleepTakerBot
var _cam: Camera3D
var _run_cam: RunCamera
var _t: float = 0.0
var _pose: String = ""
var _measured: Dictionary = {}
var _probes: Dictionary = {}
var _frame: int = 0


func _ready() -> void:
	var lanes: int = 5
	var phase: int = 0
	var escape: StringName = &"pad"
	for arg: String in OS.get_cmdline_user_args():
		var v: String = arg.get_slice("=", 1)
		if arg.begins_with("--scenario="):
			scenario = v
		elif arg.begins_with("--lanes="):
			lanes = int(v)
		elif arg.begins_with("--phase="):
			phase = int(v)
		elif arg.begins_with("--pose="):
			_pose = v
		elif arg.begins_with("--escape="):
			escape = StringName(v)
		elif arg == "--reduced-flashing":
			RenderingServer.global_shader_parameter_set(&"reduced_flashing", 1.0)
			Settings.flashing_reduced = true
	var slot: BossDef = load(BOSS_PATH) as BossDef
	var def: BossDef = (slot.preview() if slot.preview() != null else slot).duplicate() as BossDef
	var t: SleepTakerTuning = (def.tuning as SleepTakerTuning).duplicate() as SleepTakerTuning
	match scenario:
		"slash":
			# The first refuge soon after the entrance; nothing else attacks.
			t.refuge_first = 165.0
			t.attack_gap = 1000.0
		"hands":
			t.refuge_first = 100000.0
			t.attack_patterns = PackedStringArray(["hands", "hands", "hands"])
		"lights_out":
			t.refuge_first = 100000.0
			t.attack_patterns = PackedStringArray(["lights_out,hands,hands,hands,hands"])
		"measure":
			# A short refuge just ahead of the spot, the nightmare further off so it hides nothing.
			t.refuge_first = 116.0
			t.refuge_seconds = 1.0
			t.refuge_spacing = 1000.0
			t.attack_gap = 1000.0
			t.hover_ahead = 60.0
	def.tuning = t
	var tuning := load("res://data/tuning/movement.tres") as MovementTuning
	var ctx := RunContext.new()
	ctx.mode = RunContext.Mode.QUICK
	ctx.boss = def
	ctx.config = BossArena.base_config(def)
	ctx.config.lane_count = lanes
	ctx.tuning = tuning
	if phase > 0:
		ctx.boss_resume = {"phase": phase}
	boss = BossEncounter.create(def) as SleepTaker
	var arena: BossArena = boss.plan_arena(ctx)
	if scenario == "measure":
		_stage_measure(arena, tuning)
	world = RunWorld.new()
	world.name = "World"
	add_child(world)
	world.build(ctx.config, arena.layout, tuning, load("res://data/tuning/game_rules.tres") as GameRules,
		load("res://data/tuning/powerups.tres") as PowerupTuning, null, load("res://data/audio/sfx_library.tres") as SfxLibrary)
	world.player.god_mode = true
	world.player.grapples = 1_000_000
	boss.setup(world, ctx, arena)
	if scenario in ["slash", "hands", "lights_out", "fight"]:
		bot = SleepTakerBot.new(boss, escape)
		if scenario == "hands" and escape == &"none":
			bot.dodges_hands = false

	var env := WorldEnvironment.new()
	# The arena's look with its darker light, as the run builds it (LevelRun).
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
		# The runner stands still: nothing moves but the nightmare.
		world.player.running = false


func _physics_process(delta: float) -> void:
	_t += delta
	match scenario:
		"model", "front":
			_hold_still()
		_:
			if bot != null:
				bot.step()
	if scenario == "measure":
		_measure_tick()


## The nightmare where it looms, out of the fight's hands: in front of the still runner, the camera
## circling it (model) or at the runner's eye height (front).
func _hold_still() -> void:
	if boss.state != BossEncounter.State.FIGHT:
		boss.state = BossEncounter.State.FIGHT
	boss.step = SleepTaker.Step.HOVER
	boss.pose = boss.hover_pose()
	var body: SleepTakerBody = boss.body
	body.fade = 0.0
	var pose: String = _pose
	if scenario == "front" and pose == "":
		pose = ["rest", "shriek", "inhale"][int(_t / 3.0) % 3]
	body.shriek = 1.0 if pose == "shriek" else 0.0
	body.raise = 1.0 if pose in ["shriek", "raise"] else 0.0
	body.attack = 1.0 if pose in ["shriek", "slash"] else 0.0
	body.slash = 1.0 if pose == "slash" else 0.0
	body.inhale = 1.0 if pose == "inhale" else 0.0
	boss._place()
	var center: Vector3 = body.global_position + Vector3(0.0, body.height() * 0.5, 0.0)
	if scenario == "model":
		var a: float = _t * 0.25
		var r: float = 36.0
		_cam.global_position = center + Vector3(sin(a) * r, 2.0, cos(a) * r)
		_cam.look_at(center, Vector3.UP)
	else:
		_cam.global_position = world.player.global_position + Vector3(0.0, 1.7, 4.0)
		_cam.look_at(center + Vector3(0.0, -1.0, 0.0), Vector3.UP)


# --- measure -------------------------------------------------------------------------------------
# --- measure -------------------------------------------------------------------------------------

## Where the runner stops to measure (in the middle lane, so the slash it holds lights the middle three)
## and the staged pieces ahead of it, outside those lanes (track distances).
const MEASURE_STOP: float = 96.0
const MEASURE_MIST: float = 105.0
const MEASURE_GENERATOR: float = 108.0
const MEASURE_GAP: float = 110.0
const MEASURE_FENCE: float = 112.0
## The plain street the warnings are compared with, in the outer lane on the right.
const MEASURE_STREET: float = 101.0

var _sampling: bool = false


## The measure scenario's track: in the left outer lane a hand's mist (held) and a gap, in the right
## one a fence generator, a fence and plain street, the refuge's pads in the middle; the refuge's
## clearing has already left the stretch empty.
func _stage_measure(arena: BossArena, _tuning: MovementTuning) -> void:
	var lap: LevelLayout = arena.layout
	var n: int = lap.lane_count
	lap.fences.append(RunSim.fence(n - 1, MEASURE_FENCE, "full"))
	lap.gaps.append({"lane": 0, "start": MEASURE_GAP, "end": MEASURE_GAP + 3.0})
	lap.enemies.append({"type": "generator", "at": MEASURE_GENERATOR, "lane": n - 1, "side": 0, "seed": 7, "params": {}})


## Runs to the spot and stops; shows a slash's warning and a hand's mist and holds them; measures the
## screen in the arena's light, then sets off lights out (ticking it here: the fight's pattern holds
## while the runner stands) and measures again at its darkest.
func _measure_tick() -> void:
	var p: Player = world.player
	_frame += 1
	if p.running and p.distance >= MEASURE_STOP:
		p.running = false
	if p.running or boss.state != BossEncounter.State.FIGHT:
		return
	if _probes.is_empty():
		boss.slash.start(-1.0)
		boss.hands.start({"lane": 0, "at": MEASURE_MIST})
		_probes = {"stopped": _frame}
	# Hold the warnings where they are: the slash's lanes mid-warning, the mist pooled.
	boss.slash.step_time = 0.5
	boss.slash.tick(0.0)
	for h: Dictionary in boss.hands.active:
		h["t"] = 0.6
	boss.hands.tick(0.0)
	boss.dark.tick(get_physics_process_delta_time())
	if _sampling or _frame < int(_probes["stopped"]) + 8:
		return
	if not _measured.has("normal"):
		_take("normal")
	elif not _measured.has("dark") and boss.dark.stage == SleepTakerLightsOut.Stage.DARK \
			and boss.light_level() <= boss.tuning.dark_level + 0.001:
		_take("dark")


func _take(key: String) -> void:
	_sampling = true
	await RenderingServer.frame_post_draw
	_measured[key] = _sample()
	_sampling = false
	if key == "normal":
		boss.dark.start()
	else:
		_report()


## Each staged thing's colour on screen now (the mean of a 5 × 5 window on it), and the plain street's
## and the wall's.
func _sample() -> Dictionary:
	var img: Image = get_viewport().get_texture().get_image()
	var cam: Camera3D = get_viewport().get_camera_3d()
	var geo: TrackGeometry = world.geo
	var n: int = geo.lane_count
	var d: float = world.player.distance
	var pad: float = boss.tuning.refuge_first
	var end: float = pad + boss.tuning.refuge_seconds * world.tuning.run_speed
	var mark_lane: int = int(boss.slash.attack.get("first", 0))
	var spots: Dictionary = {
		"slash's lanes (red)": Vector3(geo.lane_x(mark_lane), 0.04, TrackGeometry.world_z(d + 4.0)),
		"hand's mist (purple)": Vector3(geo.lane_x(0), 0.05, TrackGeometry.world_z(MEASURE_MIST)),
		"fence (pink)": Vector3(geo.lane_x(n - 1), 0.55, TrackGeometry.world_z(MEASURE_FENCE)),
		"generator (pink)": Vector3(geo.lane_x(n - 1), 0.5, TrackGeometry.world_z(MEASURE_GENERATOR)),
		"gap's edge (orange)": Vector3(geo.lane_x(0), 0.02, TrackGeometry.world_z(MEASURE_GAP)),
		"refuge's pad (cyan)": Vector3(geo.lane_x(n / 2), 0.05, TrackGeometry.world_z(pad + 1.0)),
		"bridge's end (orange)": Vector3(geo.lane_x(n / 2), world.tuning.ceiling_height - 0.1, TrackGeometry.world_z(end)),
		"bridge's underside": Vector3(geo.lane_x(n - 1), world.tuning.ceiling_height, TrackGeometry.world_z(pad + 4.0)),
		"street": Vector3(geo.lane_x(n - 1), 0.0, TrackGeometry.world_z(MEASURE_STREET)),
		"wall": Vector3(geo.wall_x() - 0.02, 3.0, TrackGeometry.world_z(d + 10.0)),
		"nightmare (its maws)": boss.body.mouth_world(),
	}
	var out: Dictionary = {}
	var marked: Image = img.duplicate() as Image
	var scale := Vector2(img.get_width(), img.get_height()) / get_viewport().get_visible_rect().size
	for key: String in spots:
		var at: Vector2 = cam.unproject_position(spots[key]) * scale
		out[key] = _colour(img, at)
		for k: int in range(-6, 7):
			for p: Vector2i in [Vector2i(int(at.x) + k, int(at.y)), Vector2i(int(at.x), int(at.y) + k)]:
				if p.x >= 0 and p.y >= 0 and p.x < marked.get_width() and p.y < marked.get_height():
					marked.set_pixelv(p, Color(0.0, 1.0, 0.0))
	# The sampled frame with each probe marked, for checking the probes land on their things.
	marked.save_png("res://build/st_measure/probes_%d.png" % _measured.size())
	return out


## The mean colour of a 5 × 5 window around `at`.
static func _colour(img: Image, at: Vector2) -> Color:
	var sum := Color(0.0, 0.0, 0.0, 0.0)
	for dy: int in range(-2, 3):
		for dx: int in range(-2, 3):
			var c: Color = img.get_pixel(clampi(int(at.x) + dx, 0, img.get_width() - 1), clampi(int(at.y) + dy, 0, img.get_height() - 1))
			sum += Color(c.r, c.g, c.b, 1.0)
	return Color(sum.r / 25.0, sum.g / 25.0, sum.b / 25.0)


static func _grey(c: Color) -> float:
	return (0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b) * 255.0


## How far a colour stands out from another (the distance between them in RGB, 0-441).
static func _contrast(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length() * 255.0


func _report() -> void:
	var normal: Dictionary = _measured["normal"]
	var dark: Dictionary = _measured["dark"]
	print("Sleep Taker readability (%s, %d lanes), on screen, the arena's light -> lights out's darkest (light %.2f):" % [
		RenderingServer.get_current_rendering_method(), world.geo.lane_count, boss.light_level()])
	print("  %-24s %-15s %-15s %s" % ["", "brightness 0-255", "colour (RGB)", "stands out from the street (0-441)"])
	for key: String in normal:
		var a: Color = normal[key]
		var b: Color = dark[key]
		print("  %-24s %5.0f -> %-5.0f  %s -> %s  %5.0f -> %-5.0f" % [key, _grey(a), _grey(b), a.to_html(false), b.to_html(false),
			_contrast(a, normal["street"]), _contrast(b, dark["street"])])
