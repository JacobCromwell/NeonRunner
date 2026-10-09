extends Node3D
## The Golden Convergence up close and in scripted runs, for visual review (GDD §10, task E5d; not part of
## the game). It builds the fight the way the game does (its arena, the Grand Court, in its look), with a
## runner who plays it by its warnings (GoldenConvergenceBot) or stands still. The fight itself:
## ./play.sh --boss=golden_boss (debug builds; a preview until E5d-d). Render frames on both renderers, e.g.:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot4 --path . --resolution 960x540 --fixed-fps 10 \
##     --write-movie build/gc/f.png --quit-after 80 res://tools/showcase/golden_convergence_showcase.tscn \
##     -- --scenario=model --lanes=5
## (add --rendering-method gl_compatibility before the scene for the web / low-end renderer).
## Scenarios:
##   model     (default) a camera swinging around the suit floating over the causeway, its cape billowing,
##             cycling its handles: the pipes' hatches open and shut, an arm reaching out on its telescoping
##             segments, a shoulder's pipes blown out, the chest plates parting (later steps' states)
##   front     the suit from the runner's eye height, still, as the runner sees it at the far end
##   face      a close-up of the calm golden face and its dull red tear
##   entrance  the fight's start through the run camera: it rises at the far end, the cape unfurls, the chime
##   strafe    through the run camera, the first strafe (V, V, H) with the bot dodging and taking cover
##             (--still: the runner stands in the middle lane, god mode)
##   buttress  a horizontal pass: the gate, the live line, the lines for show (--cam=side: from beside the track)
##   wall      a wall opened beside the runner's outer lane (court.open_wall, a plain stand-in slab for the toppled
##             tower E5d-b brings) and a vertical pass over it, the fire climbing the wall's foot (--cam=side)
##   fight     the fight as it comes, with the bot
##   slams     (E5d-b) the phase's Fist Slam sequence alone, through the run camera, the bot dodging the fists ON
##             it and jumping the holes AHEAD, never baiting (--phase=2 for the later script; --still: the
##             runner stands in the middle lane, god mode, its falls saved)
##   bait      (E5d-b) the slams then the barrage, the bot baiting the first chance's fist into its Flying
##             Buttress: the gate smashed, the tower toppling beside the causeway, the runner onto its wall as
##             the missiles' marks fill in, on it through the fire
##   tower     (E5d-b) the bait from across the track, the camera on the side away from the tower: its fall,
##             its side lying flush as the wall, the runner on it, the tower sinking away behind
##   barrage   (E5d-b) the Missile Barrage alone with no wall (god mode, the runner in the middle lane): the
##             hatches, the salvo climbing and hanging, the dive, the marks spreading and filling in, the fire
## Options: --lanes=N (3, 5 or 6; 5 by default), --speed=N (18 by default; the campaign's 25), --phase=N,
## --script=VVHvVHv (the strafe's passes), --cam=run/side/high, --still, --reduced-flashing, --events
## (prints each of the boss's events with its frame, for picking frames), --burst (front and face: the chest's
## plates burst open, both shoulders' pipes blown out: the later steps' damage states).
## Frames worth a look (at --fixed-fps 10): entrance 0-55 (the chime at 16); strafe (after the phase's intro):
## the squadron out of the cape from about frame 63, the first pass's warning at 79 and its rake 91-99, the
## buttress rising at 110, the second pass's warning at 114 and its rake 126-134, the horizontal pass's warning
## at 150 and its sweep 161-175, the squadron back into the cape by 198; buttress and wall: the warning at 79,
## the fire 91-105.
## E5d-b, at 5 lanes and 18 m/s: slams: the first fist out from frame 63, its warning (the red square, the
## shadow) at 96, the lock at 104, the impact and the square hole at 114; the second slam 116-134, the third
## (AHEAD) 136-154. bait and tower: the bait's lock at 124, the gate smashed and the tower toppling at 134
## (tower: the wide shot of the whole fall to 149), down as the wall at 149; the barrage's launch at 139, the
## missiles hanging about 145-153, the dive and the marks filling in 154-163, the fire 164-179 with the runner
## on the wall; the tower sinks behind from about 238. barrage: the hatches at 63, the launch at 68, the hang
## 78-83, the dive 83-93, the fire 93-108.

const BOSS_PATH: String = "res://data/bosses/golden_boss.tres"

var scenario: String = "model"
var world: RunWorld
var boss: GoldenConvergence
var bot: GoldenConvergenceBot
var _cam: Camera3D
var _run_cam: RunCamera
var _t: float = 0.0
var _print_events: bool = false
var _events_seen: int = 0
var _still: bool = false
var _burst: bool = false
var _view: String = "run"


func _ready() -> void:
	var lanes: int = 5
	var phase: int = 0
	var speed: float = 18.0
	var script_arg: String = ""
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
		elif arg.begins_with("--script="):
			script_arg = v
		elif arg.begins_with("--cam="):
			_view = v
		elif arg == "--reduced-flashing":
			RenderingServer.global_shader_parameter_set(&"reduced_flashing", 1.0)
			Settings.flashing_reduced = true
		elif arg == "--events":
			_print_events = true
		elif arg == "--still":
			_still = true
		elif arg == "--burst":
			_burst = true
	var slot: BossDef = load(BOSS_PATH) as BossDef
	var def: BossDef = slot.preview() if slot.preview() != null else slot.duplicate() as BossDef
	var t: GoldenConvergenceTuning = (def.tuning as GoldenConvergenceTuning).duplicate() as GoldenConvergenceTuning
	if script_arg != "":
		var beats := PackedStringArray()
		for i: int in t.phase_beats.size():
			beats.append("strafe:%s" % script_arg)
		t.phase_beats = beats
	if scenario in ["buttress", "wall"]:
		# Straight to the passes it shows.
		var beats := PackedStringArray()
		for i: int in t.phase_beats.size():
			beats.append("strafe:%s" % ("H" if scenario == "buttress" else "V"))
		t.phase_beats = beats
	_slam_beats(t)
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
	elif scenario in ["strafe", "buttress", "wall", "fight"]:
		# Past the entrance: straight to the pattern.
		ctx.boss_resume = {"phase": 0, "time": 0.0}
	if phase <= 0 and scenario in SLAM_SCENARIOS:
		ctx.boss_resume = {"phase": 0, "time": 0.0}
	boss = BossEncounter.create(def) as GoldenConvergence
	var arena: BossArena = boss.plan_arena(ctx)
	world = RunWorld.new()
	world.name = "World"
	add_child(world)
	world.build(ctx.config, arena.layout, tuning, load("res://data/tuning/game_rules.tres") as GameRules,
		load("res://data/tuning/powerups.tres") as PowerupTuning, null, load("res://data/audio/sfx_library.tres") as SfxLibrary)
	boss.setup(world, ctx, arena)
	if scenario in ["strafe", "fight", "buttress"] and not _still:
		bot = GoldenConvergenceBot.new(boss)
	else:
		world.player.god_mode = true
	if scenario == "wall":
		world.player.god_mode = true
		bot = null
	_slam_runner()
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
	if scenario in ["model", "front", "face"] or _view != "run":
		_cam = Camera3D.new()
		_cam.fov = 60.0
		_cam.far = 900.0
		add_child(_cam)
		_cam.make_current()
	world.start()
	if scenario in ["model", "front", "face"]:
		# The runner stands still: nothing moves but the suit.
		world.player.running = false
	if scenario == "wall":
		# The runner by the right wall; the wall there open for the passes.
		for i: int in lanes:
			world.player.press(&"move_right")
		var from: float = world.player.distance + 20.0
		var to: float = world.player.distance + 2000.0
		boss.court.open_wall(1, from, to)
		# A plain stand-in for the wall E5d-b's toppled tower brings (the court itself has none).
		var slab := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(1.0, 12.0, to - from)
		slab.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.82, 0.78, 0.7)
		slab.material_override = mat
		world.add_child(slab)
		slab.global_position = Vector3(world.geo.wall_x() + 0.5, 6.0, TrackGeometry.world_z((from + to) * 0.5))


func _physics_process(delta: float) -> void:
	_t += delta
	match scenario:
		"model", "front", "face":
			_hold_still()
		_:
			if bot != null:
				bot.step()
			if scenario == "wall" and world.player.surface == Player.Surface.FLOOR and world.player.lane == world.geo.lane_count - 1 \
					and fmod(_t, 2.4) < 0.05:
				# Onto the open wall now and then, so the fire meets a runner low on it and high up.
				world.player.press(&"move_right")
	if _cam != null and scenario not in ["model", "front", "face"]:
		_follow_cam()


func _process(_delta: float) -> void:
	if not _print_events or boss == null:
		return
	while _events_seen < boss.events.size():
		var e: Dictionary = boss.events[_events_seen]
		_events_seen += 1
		if e["event"] != &"sound":
			print("frame %d: %s" % [Engine.get_process_frames(), e])


## The suit where it floats, out of the fight's hands: the camera swinging around it (model), at the
## runner's eye height (front) or on its face (face); its handles cycling (model).
func _hold_still() -> void:
	if boss.state != BossEncounter.State.FIGHT:
		boss.state = BossEncounter.State.FIGHT
	boss._set_step(GoldenConvergence.Step.FLOAT)
	boss._place_suit()
	var suit: GoldenConvergenceSuit = boss.suit
	suit.unfurl = 1.0
	var center: Vector3 = suit.global_position + Vector3(0.0, 10.0, 0.0)
	if scenario == "model":
		var cycle: float = fmod(_t, 12.0)
		suit.pipes_open[1] = clampf(sin(_t * 0.9) * 1.5, 0.0, 1.0)
		suit.set_pipes_broken(-1, cycle > 8.0)
		var reach: float = clampf((cycle - 2.0) / 2.0, 0.0, 1.0) * clampf((7.0 - cycle) / 1.5, 0.0, 1.0)
		suit.set_arm(1, world.player.global_position + Vector3(2.4, 0.0, -20.0), reach, reach, reach > 0.2)
		suit.burst = clampf((cycle - 9.5) / 1.5, 0.0, 1.0) * 0.6
		# Swinging around its front half, from the causeway's level to above it.
		var a: float = sin(_t * 0.22) * 1.3
		_cam.global_position = center + Vector3(sin(a) * 85.0, -4.0 + 8.0 * sin(_t * 0.3), cos(a) * 85.0)
		_cam.look_at(center, Vector3.UP)
		return
	suit.burst = 1.0 if _burst else 0.0
	suit.set_pipes_broken(-1, _burst)
	suit.set_pipes_broken(1, _burst)
	if scenario == "front":
		# Just ahead of the runner, at their eye height, looking up the causeway at it.
		_cam.global_position = world.player.global_position + Vector3(0.0, 1.7, -1.5)
		_cam.look_at(center + Vector3(0.0, 2.0, 0.0), Vector3.UP)
	else:
		var head: Vector3 = suit.head_point()
		_cam.global_position = head + Vector3(3.0, -1.0, 16.0)
		_cam.look_at(head, Vector3.UP)


## A camera beside the track (side) or high over it (high), following the runner.
func _follow_cam() -> void:
	var p: Vector3 = world.player.global_position
	if _view == "tower":
		_tower_cam(p)
		return
	if _view == "side":
		_cam.global_position = p + Vector3(world.geo.wall_x() + 14.0, 6.0, -14.0)
		_cam.look_at(p + Vector3(0.0, 2.0, -22.0), Vector3.UP)
	else:
		_cam.global_position = p + Vector3(0.0, 22.0, 18.0)
		_cam.look_at(p + Vector3(0.0, 0.0, -30.0), Vector3.UP)


# --- E5d-b: the Fist Slam, the toppled tower and the Missile Barrage ------------------------------------------

const SLAM_SCENARIOS: Array[String] = ["slams", "bait", "tower", "barrage"]


## The scenario's beats, every phase: the slams alone, the slams then the barrage, the barrage alone.
func _slam_beats(t: GoldenConvergenceTuning) -> void:
	if scenario not in SLAM_SCENARIOS:
		return
	var line: String = {"slams": "slams", "bait": "slams,barrage", "tower": "slams,barrage", "barrage": "barrage"}[scenario]
	var beats := PackedStringArray()
	var loops := PackedInt32Array()
	for i: int in t.phase_beats.size():
		beats.append(line)
		loops.append(0)
	t.phase_beats = beats
	# Round again from the first beat (phase 1 loops from its second in the fight).
	t.loop_from = loops
	if scenario == "tower" and _view == "run":
		_view = "tower"


## Who runs it: the bot (never baiting in slams), or a runner standing in the middle lane in god mode whose
## falls are saved (barrage, slams --still).
func _slam_runner() -> void:
	if scenario not in SLAM_SCENARIOS:
		return
	if scenario == "barrage" or _still:
		bot = null
		world.player.god_mode = true
		world.player.grapples = 1_000_000
		return
	bot = GoldenConvergenceBot.new(boss)
	bot.baits = scenario != "slams"
	world.player.god_mode = false


## Across the track from the tower (the side away from the first chance's gate lean, or from the tower down),
## high enough to see its side lie flush along the causeway, the runner in view; while a tower falls, a wide
## shot from far across the track takes in the whole fall (it starts off screen behind the runner).
func _tower_cam(p: Vector3) -> void:
	for tower: GoldenConvergenceTower in boss.slams.towers:
		if tower.state == GoldenConvergenceTower.State.FALLING:
			var mid: float = tower.foot + tower.length * 0.5
			var face: float = tower.side * (world.geo.wall_x() + boss.tuning.tower_width * 0.5)
			_cam.fov = 75.0
			_cam.global_position = Vector3(face - tower.side * 160.0, tower.length * 0.5, TrackGeometry.world_z(mid))
			_cam.look_at(Vector3(face, tower.length * 0.45, TrackGeometry.world_z(mid)), Vector3.UP)
			return
	_cam.fov = 60.0
	var side: int = 1
	var down: Array[GoldenConvergenceTower] = boss.slams.towers_down()
	if not down.is_empty():
		side = down[0].side
	else:
		for s: Dictionary in boss.slams.slams:
			if bool(s["chance"]):
				side = int(s["lean"])
				break
	var wall_x: float = world.geo.wall_x()
	_cam.global_position = p + Vector3(-side * (wall_x + 9.0), 10.0, 8.0)
	_cam.look_at(Vector3(side * wall_x * 0.6, 2.0, p.z - 34.0), Vector3.UP)
