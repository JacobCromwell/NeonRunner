extends Node3D
## Gameplay review for the Octodog jars that break open (task Q5; GDD §5, Zone 9, the owner, October 21, 2026: "sometimes
## smashing an Octodog jar doodad releases its Octodog into the world, and the runner has to fight it"): a real RunWorld on
## a hand-built track in a zone's look, driven like the tests' RunSim, seen through the game's camera (RunCamera), a close
## one or one standing beside the track. One jar in lane --lane (pushing to --side) holding an Octodog, its charges planned
## from the release as the generator plans them (OctodogJarRules.release_distance, a cycle apart), and the runner coming
## at the jar in that lane (--take):
##   release  the dash smashes the jar; the dog bursts out, tumbles ahead, runs on to its usual distance and winds up at
##            its planned charges, and the runner sidesteps each wind-up (the default);
##   stay     the dash smashes the jar and the runner stays in line: the armor absorbs the first lunge (with --god nothing
##            does; with --bare, no armor: it kills);
##   pass     no dash: the jar pushes the runner aside like any doodad, and its dog never comes out;
##   look     the camera holds still beside the track looking at the jar, no run.
##
##   Render:  godot --path . --resolution 960x540 --write-movie build/review/f.png --fixed-fps 10 --quit-after 120
##            res://tools/showcase/octodog_jar_review.tscn -- [options]
##   Options (after --):
##     --take=<release|stay|pass|look>   what the runner does (above; default release)
##     --zone=<zone id>       the zone's run speed and look (data/zones/<id>.tres; default ice_lab)
##     --skin=<skin id>       another look (data/skins/<id>_skin.tres)
##     --lanes=N              lane count (default 5)
##     --lane=L               the jar's lane (default the middle one, the left of the two middle ones at an even count)
##     --side=<-1|1>          the side its push goes to (default -1; inward from an outermost lane)
##     --charges=N            the dog's planned charges (default 2)
##     --close                a close camera low behind the runner
##     --beside               a camera standing beside the track, level with the jar
##     --hitboxes             show the hitboxes (the hitbox view)
##     --reduced-flashing     the Reduced flashing setting on
##     --god                  god mode
##     --bare                 no armor (--take=stay: the lunge kills)
##     --first=M              the jar's front (metres, default 60)
## Each scripted action, the dog's phases, movement event and kill is printed with its time and distance, to find the
## frames (frame = time × render fps).

const TUNING_PATH: String = "res://data/tuning/movement.tres"
const RULES_PATH: String = "res://data/tuning/game_rules.tres"
const OctodogJarRules = preload("res://scripts/enemies/octodog_jar_rules.gd")
## Seconds after a wind-up starts that the runner sidesteps (--take=release).
const REACTION: float = 0.3

var tuning: MovementTuning
var world: RunWorld
var camera: Camera3D
var take: String = "release"
var close: bool = false
var beside: bool = false
var _pending: Array = []
var _first: float = 60.0
var _jar: Dictionary = {}
var _dog_id: int = 0
var _last_phase: int = -1
var _dodge_at: float = INF


func _ready() -> void:
	tuning = load(TUNING_PATH) as MovementTuning
	var zone_id: String = "ice_lab"
	var skin_id: String = ""
	var lanes: int = 5
	var lane: int = -1
	var side: int = -1
	var charges: int = 2
	var hitboxes: bool = false
	var reduced_flashing: bool = false
	var god: bool = false
	var bare: bool = false
	for arg: String in OS.get_cmdline_user_args():
		var v: String = arg.get_slice("=", 1)
		if arg.begins_with("--take="):
			take = v
		elif arg.begins_with("--zone="):
			zone_id = v
		elif arg.begins_with("--skin="):
			skin_id = v
		elif arg.begins_with("--lanes="):
			lanes = clampi(int(v), 3, 8)
		elif arg.begins_with("--lane="):
			lane = int(v)
		elif arg.begins_with("--side="):
			side = -1 if int(v) < 0 else 1
		elif arg.begins_with("--charges="):
			charges = clampi(int(v), 1, 4)
		elif arg == "--close":
			close = true
		elif arg == "--beside":
			beside = true
		elif arg == "--hitboxes":
			hitboxes = true
		elif arg == "--reduced-flashing":
			reduced_flashing = true
		elif arg == "--god":
			god = true
		elif arg == "--bare":
			bare = true
		elif arg.begins_with("--first="):
			_first = maxf(float(v), 40.0)
	if lane < 0 or lane >= lanes:
		lane = (lanes - 1) / 2
	if lane == 0:
		side = 1
	elif lane == lanes - 1:
		side = -1
	var config := LevelConfig.new()
	config.lane_count = lanes
	var skin: ZoneSkin = GreyboxSkin.new()
	var zone_path: String = "res://data/zones/%s.tres" % zone_id
	if ResourceLoader.exists(zone_path):
		var zone := load(zone_path) as ZoneDef
		if zone != null:
			config.run_speed = zone.run_speed
			if ResourceLoader.exists(zone.skin_path):
				skin = load(zone.skin_path) as ZoneSkin
	if skin_id != "":
		var skin_path: String = "res://data/skins/%s_skin.tres" % skin_id
		if ResourceLoader.exists(skin_path):
			skin = load(skin_path) as ZoneSkin
		else:
			push_warning("octodog_jar_review: no skin at %s; keeping the zone's" % skin_path)
	config.skin = skin
	config.features = PackedStringArray(["octodog", OctodogJarRules.FEATURE])
	var t: MovementTuning = config.movement_for(tuning)
	var ot := EnemyDirector.tuning_for("octodog") as OctodogTuning
	var pt := load("res://data/tuning/powerups.tres") as PowerupTuning
	var layout := LevelLayout.new()
	layout.lane_count = lanes
	layout.length = 1200.0
	# The jar and the dog it holds, as the jar rules make them.
	var gen: LevelGenerator = LevelGenerator.for_layout(config, tuning, layout)
	var a0: float = _first + OctodogJarRules.release_distance(gen, ot, pt)
	var cycle: float = ot.cycle_distance(gen.speed, config.enemy_scaling, gen.pace)
	var window: float = ot.window_length(gen.speed, config.enemy_scaling, gen.pace)
	var anchors: Array[float] = []
	for k: int in charges:
		anchors.append(a0 + k * cycle)
	_jar = {"lane": lane, "start": _first, "end": _first + t.doodad_size(OctodogJarRules.JAR_SIZE).z,
		"size": OctodogJarRules.JAR_SIZE, "side": side, "seed": 7, LevelLayout.HOLDS: OctodogJarRules.TYPE}
	layout.doodads.append(_jar)
	layout.enemies.append({"type": OctodogJarRules.TYPE, "at": _first, "lane": lane, "side": 0, "seed": 11,
		"params": {LevelLayout.HELD: true, "doghouse": false, "charges": anchors.size(), "charge_at": anchors,
			"floor_span": Vector2(anchors[0] - 20.0, anchors[-1] + window)}})
	layout.length = anchors[-1] + window + 200.0
	var dash_length: float = pt.dash_duration * (t.run_speed + pt.dash_speed_bonus)
	if take == "release" or take == "stay":
		_pending.append([_first - 0.5 * dash_length, &"dash"])

	var sfx := load("res://data/audio/sfx_library.tres") as SfxLibrary
	var loadout := Loadout.new()
	loadout.tiers[&"dash"] = 4
	world = RunWorld.new()
	add_child(world)
	world.build(config, layout, tuning, load(RULES_PATH) as GameRules, null, loadout, sfx)
	world.player.setup(world.tuning, world.geo, lane)
	world.player.steady_flash = reduced_flashing
	Settings.flashing_reduced = reduced_flashing
	world.player.god_mode = god
	# The armor, carried and whole, unless --bare.
	world.player.armor_state.carried = not bare
	world.player.armor_state.hits = 0 if bare else world.player.armor_state.max_hits
	world.track.set_hitboxes_visible(hitboxes)
	world.director.enemy_defeated.connect(func(e: Enemy, cause: StringName) -> void:
		print("%5.2f s  %6.1f m  %s defeated (%s)" % [world.player.elapsed, world.player.distance, e.type_id, cause]))
	world.player.movement_event.connect(func(kind: StringName) -> void:
		print("%5.2f s  %6.1f m  %s" % [world.player.elapsed, world.player.distance, kind]))
	world.player.died.connect(func(cause: String) -> void:
		print("%5.2f s  %6.1f m  died (%s)" % [world.player.elapsed, world.player.distance, cause]))
	print("a jar in lane %d at %.1f m pushing %s, its dog's wind-ups planned at %s m" % [lane, _first,
		"left" if side < 0 else "right", anchors])

	var env := WorldEnvironment.new()
	env.environment = skin.make_environment()
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, 25.0, 0.0)
	sun.light_energy = 0.7
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(sun)
	if close or beside or take == "look":
		camera = Camera3D.new()
		camera.fov = 60.0
		add_child(camera)
		_update_fixed_camera()
	else:
		var run_camera := RunCamera.new()
		add_child(run_camera)
		run_camera.follow(world)
		camera = run_camera
	camera.make_current()
	if take != "look":
		world.start()


func _physics_process(_delta: float) -> void:
	var player: Player = world.player
	while not _pending.is_empty() and player.distance >= float(_pending[0][0]):
		var action: StringName = _pending.pop_front()[1]
		print("%5.2f s  %6.1f m  > %s" % [player.elapsed, player.distance, action])
		if action == &"dash":
			world.powerups.call(&"try_dash")
		else:
			player.press(action)
	if player.elapsed >= _dodge_at:
		_dodge_at = INF
		var dir: StringName = &"move_left" if player.lane > 0 else &"move_right"
		print("%5.2f s  %6.1f m  > %s" % [player.elapsed, player.distance, dir])
		player.press(dir)
	var dog: Octodog = _dog()
	if dog != null and dog.phase != _last_phase:
		_last_phase = dog.phase
		print("%5.2f s  %6.1f m  the dog: %s" % [player.elapsed, player.distance, Octodog.PHASE_NAMES[dog.phase]])
		if dog.phase == Octodog.Phase.WINDUP and take == "release":
			_dodge_at = player.elapsed + REACTION


## The jar's dog, once the director has spawned it (null after it's gone).
func _dog() -> Octodog:
	if _dog_id != 0:
		var o: Object = instance_from_id(_dog_id)
		return o as Octodog if is_instance_valid(o) else null
	for e: Enemy in world.director.active:
		if is_instance_valid(e) and e is Octodog:
			_dog_id = e.get_instance_id()
			return e as Octodog
	return null


func _process(_delta: float) -> void:
	if close or beside or take == "look":
		_update_fixed_camera()


## Low behind the runner (--close); or standing beside the track level with the jar, looking across and on at it
## (--beside, and --take=look).
func _update_fixed_camera() -> void:
	if close:
		var p: Player = world.player
		camera.position = Vector3(p.position.x * 0.5, 3.0, p.position.z + 6.0)
		camera.look_at(Vector3(p.position.x * 0.5, 1.2, p.position.z - 10.0))
		return
	var x: float = world.geo.lane_x(int(_jar["lane"]))
	var across: float = -1.0 if x > 0.0 else 1.0
	camera.position = Vector3(across * (world.geo.wall_x() - 0.6), 2.0, TrackGeometry.world_z(_first - 7.0))
	camera.look_at(Vector3(x, 0.8, TrackGeometry.world_z(_first + 6.0)))
