extends Node3D
## The Golden Convergence's second stage, The Magnate, up close and in scripted runs, for visual review (GDD §10,
## task E5d-d; not part of the game). It builds the fight the way the game does (the Grand Court, from the
## checkpoint), with a runner who plays it by what it shows (GoldenConvergenceBot) or stands in its way. The
## fight itself: ./play.sh --boss=golden_boss --phase=4. Render frames on both renderers, e.g.:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot4 --path . --resolution 960x540 --fixed-fps 10 \
##     --write-movie build/magnate/f.png --quit-after 80 res://tools/showcase/golden_convergence_magnate_showcase.tscn \
##     -- --scenario=magnate --lanes=5
## (add --rendering-method gl_compatibility before the scene for the web / low-end renderer).
## Scenarios:
##   magnate     (default) him up close beside the runner, the camera swinging round him, cycling what he does:
##               run, roar, leap, rear, whip, slump (stunned, the ports bright), collapse
##   face        a close-up of his face: the mask's half with its tear, his roaring half
##   feed        a tower's screen square on, showing his roaring face (the feed in stage 2)
##   transition  phase 4's intro through the run camera: the suit bursts, its plates fly off, he claws out and
##               roars (the feed switches to his face), the suit topples off the causeway, he leaps over the runner
##   chase       behind the runner (his shadow, the marker at the bottom edge), then an overtake along the
##               balustrades
##   pounce      a Pounce: the roar and the red marker, the leap over the runner, the lock and its red square, the
##               crash beside the runner who dodged (--still: the runner stays in the square, god mode)
##   bait        a Pounce with the bait: the buttress, the runner in its lane at the lock, the crash into the gate,
##               the stun across two lanes (the red ports), the stomp onto his back (--miss: the runner runs on,
##               and he shakes free)
##   lash        a Cable Lash (--kind=low or high): the run-up along the balustrade, the rearing, the red line and
##               aim lines, the whip across every lane, the runner jumping or sliding through
##   defeat      phase 6's bait and stomp, then the defeat: the cables tearing out, the screens dying outward, the
##               collapse ahead, the runner running past
##   fight       stage 2 as it comes, with the bot
## The owner's playtest (task E5d-e), from phase 5's hurl unless --phase says otherwise:
##   slash       a Claw Slash (--kind=double: two in a row): him closing in, the marker flashing red, the red claw
##               marks in the runner's lane, the lunge into view and the swipe, the runner switching out (--still:
##               the runner stays, god mode)
##   screens     a Screen Storm: him up on the balustrade beside the runner, the screens coming down on their gold
##               tentacles over red squares, crashing around the runner and onto him, yanked back up (--still: the
##               runner stays, god mode)
##   dark        stage 2 darker: phase 4's transition from the checkpoint (the arena fading to 0.7 of its light),
##               then a Pounce with the bait: the stun and the green chevrons where to take off, the stomp
## Options: --lanes=N (5 by default), --speed=N (18 by default; the campaign's 25), --cam=run/side/high,
## --reduced-flashing, --events (prints each of the boss's events with its frame, for picking frames), --still,
## --miss, --kind=low|high (lash) or double (slash), --phase=N (4-6: the phase it starts at), --dark (the close-ups
## in stage 2's light: the fight's own scenarios fade to it through the transition).
## Frames worth a look (at --fixed-fps 10, 18 m/s, 5 lanes; --events prints the rest; E5d-e's scenarios start at
## phase 5, the hurl, and their first beat comes at about frame 32): transition: the burst at 0-6,
## the plates off from 4, his roar at 18, the suit toppling 23-45, the leap over the runner 28-42; chase: his
## shadow and marker 45-57; pounce: the roar (the marker red) at 58, the leap 65, the square 72, the crash 83;
## bait: the buttress at 58, the roar 80, the lock 94, the stun 105, the stomp 120, the hurl 121-127; lash: the
## run-up 58-80, the warning 81, the whip 94; defeat: the stomp at 93, the cables 99-114, the screens dying from
## 102, the collapse 117, the runner past about 130.

const BOSS_PATH: String = "res://data/bosses/golden_boss.tres"

var scenario: String = "magnate"
var world: RunWorld
var boss: GoldenConvergence
var bot: GoldenConvergenceBot
var _cam: Camera3D
var _run_cam: RunCamera
var _t: float = 0.0
var _print_events: bool = false
var _events_seen: int = 0
var _still: bool = false
var _view: String = "run"
var _anims: Array[StringName] = [&"run", &"roar", &"leap", &"rear", &"whip", &"slump", &"collapse"]


func _ready() -> void:
	var lanes: int = 5
	var speed: float = 18.0
	var kind: String = "low"
	var miss: bool = false
	var start_phase: int = -1
	var dark: bool = false
	for arg: String in OS.get_cmdline_user_args():
		var v: String = arg.get_slice("=", 1)
		if arg.begins_with("--scenario="):
			scenario = v
		elif arg.begins_with("--lanes="):
			lanes = int(v)
		elif arg.begins_with("--speed="):
			speed = float(v)
		elif arg.begins_with("--cam="):
			_view = v
		elif arg.begins_with("--kind="):
			kind = v
		elif arg == "--reduced-flashing":
			RenderingServer.global_shader_parameter_set(&"reduced_flashing", 1.0)
			Settings.flashing_reduced = true
		elif arg == "--events":
			_print_events = true
		elif arg == "--still":
			_still = true
		elif arg == "--miss":
			miss = true
		elif arg.begins_with("--phase="):
			start_phase = clampi(int(v), 4, 6) - 1
		elif arg == "--dark":
			dark = true
	var slot: BossDef = load(BOSS_PATH) as BossDef
	var def: BossDef = slot.preview() if slot.preview() != null else slot.duplicate() as BossDef
	var t: GoldenConvergenceTuning = (def.tuning as GoldenConvergenceTuning).duplicate() as GoldenConvergenceTuning
	var beat: String = ""
	match scenario:
		"chase":
			beat = "overtake"
		"pounce":
			beat = "pounce"
		"bait", "defeat", "dark":
			beat = "pounce:bait"
		"lash":
			beat = "lash:%s" % kind
		"slash":
			beat = "slash:double" if kind == "double" else "slash"
		"screens":
			beat = "screens"
		"magnate", "face", "feed", "transition":
			beat = "none"
	if beat != "":
		var beats := PackedStringArray(t.phase_beats)
		for i: int in range(3, beats.size()):
			beats[i] = beat
		t.phase_beats = beats
	def.tuning = t
	var tuning := (load("res://data/tuning/movement.tres") as MovementTuning).duplicate() as MovementTuning
	tuning.run_speed = speed
	var ctx := RunContext.new()
	ctx.mode = RunContext.Mode.QUICK
	ctx.boss = def
	ctx.config = BossArena.base_config(def)
	ctx.config.lane_count = lanes
	ctx.tuning = tuning
	# From the checkpoint (phase 4, the transition), or phase 6 for the defeat; E5d-e's attacks from phase 5 (its
	# intro is his hurl), unless --phase says otherwise.
	var phase: int = 5 if scenario == "defeat" else (4 if scenario in ["slash", "screens"] else 3)
	ctx.boss_resume = {"phase": start_phase if start_phase >= 0 else phase}
	boss = BossEncounter.create(def) as GoldenConvergence
	var arena: BossArena = boss.plan_arena(ctx)
	world = RunWorld.new()
	world.name = "World"
	add_child(world)
	world.build(ctx.config, arena.layout, tuning, load("res://data/tuning/game_rules.tres") as GameRules,
		load("res://data/tuning/powerups.tres") as PowerupTuning, null, load("res://data/audio/sfx_library.tres") as SfxLibrary)
	boss.setup(world, ctx, arena)
	if scenario in ["pounce", "bait", "lash", "defeat", "fight", "chase", "slash", "screens", "dark"] and not _still:
		bot = GoldenConvergenceBot.new(boss)
		bot.stomps = not miss
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
	if scenario in ["magnate", "face", "feed"] or _view != "run":
		_cam = Camera3D.new()
		_cam.fov = 55.0
		_cam.far = 900.0
		add_child(_cam)
		_cam.make_current()
	world.start()
	if scenario in ["magnate", "face", "feed"]:
		# The runner stands still: nothing moves but him.
		world.player.running = false
	if dark:
		# Stage 2's light at once (the close-ups never run the fight's clock, so its fade never comes).
		boss.set_light_level(boss.tuning.stage_two_light, 0.0)


func _physics_process(delta: float) -> void:
	_t += delta
	match scenario:
		"magnate", "face", "feed":
			_hold_still()
		_:
			if bot != null:
				bot.step()
	if _cam != null and scenario not in ["magnate", "face", "feed"]:
		_follow_cam()


func _process(_delta: float) -> void:
	if not _print_events or boss == null:
		return
	while _events_seen < boss.events.size():
		var e: Dictionary = boss.events[_events_seen]
		_events_seen += 1
		if e["event"] != &"sound":
			print("frame %d: %s" % [Engine.get_process_frames(), e])


## Him up close beside the still runner, out of the fight's hands: the camera swinging round him (magnate) or on
## his face (face), what he does cycling.
func _hold_still() -> void:
	var m: GoldenConvergenceMagnate = boss.magnate
	boss.transition.clear()
	boss.chase.stop()
	boss.suit.visible = false
	var p: Vector3 = world.player.global_position
	var at := Vector3(world.geo.lane_x(maxi(world.player.lane - 1, 0)) - 0.4, 0.0, p.z - 5.0)
	var anim: StringName = _anims[int(_t / 2.4) % _anims.size()] if scenario == "magnate" else &"roar"
	var y: float = 0.0
	if anim == &"leap":
		y = 1.2 + 0.6 * sin(fmod(_t, 2.4) * 2.6)
	m.set_pose(Transform3D(Basis(Vector3.UP, 0.0), at + Vector3(0.0, y, 0.0)))
	m.play(anim)
	m.speed = 18.0 if anim == &"run" else 0.0
	m.ports_glow = 1.0 if anim == &"slump" else 0.2
	if scenario == "magnate":
		var a: float = 0.6 + sin(_t * 0.25) * 1.4
		var center: Vector3 = at + Vector3(0.0, 1.0, 0.0)
		_cam.global_position = center + Vector3(sin(a) * 7.5, 2.2 + 1.2 * sin(_t * 0.31), cos(a) * 7.5)
		_cam.look_at(center, Vector3.UP)
	elif scenario == "feed":
		# A tower's screen ahead, square on: his face on the feed (its glitch from --phase... none: steady).
		var skin := world.skin as GoldenCourtSkin
		skin.set_feed(1, 1.0, 0.0)
		var towers: Array[Dictionary] = skin.towers(-1, -world.geo.wall_x(), world.player.distance + 20.0,
			world.player.distance + 400.0)
		if not towers.is_empty():
			var screen: Vector3 = towers[0]["screen_center"]
			var face: Vector3 = towers[0]["screen_face"]
			_cam.global_position = screen + face * 24.0
			_cam.look_at(screen, Vector3.UP)
	else:
		var head: Vector3 = m.head_point()
		_cam.global_position = head + Vector3(0.6 * sin(_t * 0.5), 0.15, -2.0)
		_cam.look_at(head, Vector3.UP)


## A camera beside the track (side) or high over it (high), following the runner.
func _follow_cam() -> void:
	var p: Vector3 = world.player.global_position
	if _view == "side":
		_cam.global_position = p + Vector3(world.geo.wall_x() + 12.0, 5.0, -10.0)
		_cam.look_at(p + Vector3(0.0, 1.5, -16.0), Vector3.UP)
	else:
		_cam.global_position = p + Vector3(0.0, 20.0, 16.0)
		_cam.look_at(p + Vector3(0.0, 0.0, -24.0), Vector3.UP)
