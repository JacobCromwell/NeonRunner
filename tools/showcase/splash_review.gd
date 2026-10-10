extends Node3D
## Visual review for the Beach's splash (task D10; the owner, October 9, 2026: "a fall makes a splash"): a real
## RunWorld with the Beach's skin (its own game rules: falls on, no god mode), a pool in the runner's lane, and
## the runner running into it without jumping, seen through the game's camera (RunCamera). Prints the time of
## the entry, the splash and the death; the scene then does what the game does (the run waits
## game_rules.death_screen_delay, a second, then the death screen pauses it), so the splash reads before and
## through it. Render:
##   godot --path . --resolution 960x540 --fixed-fps 30 --write-movie build/review/f.png --quit-after 120 \
##     res://tools/showcase/splash_review.tscn -- [options]    (add --rendering-method gl_compatibility for the web renderer)
## Options (after --):
##   --skin=<id>     the zone's look (data/skins/<id>_skin.tres, default beach)
##   --sky=<name>    a level's own sky over it (data/skies/<name>.tres), such as beach_sunset
##   --lanes=N       lane count (default 5)
##   --grapple       the runner carries a grapple hook: it fires at the pit's depth, above the water, and the
##                   runner is saved, so no splash (a short pool, so the pull-up clears it)
##   --side          a camera beside the pool, close to the water, looking at the entry point

const TUNING_PATH: String = "res://data/tuning/movement.tres"
const RULES_PATH: String = "res://data/tuning/game_rules.tres"
const POOL: Vector2 = Vector2(70.0, 76.0)

var world: RunWorld
var _splash_seen: bool = false


func _ready() -> void:
	var tuning := load(TUNING_PATH) as MovementTuning
	var skin_id: String = "beach"
	var sky_name: String = ""
	var lanes: int = 5
	var grapple: bool = false
	var side: bool = false
	for arg: String in OS.get_cmdline_user_args():
		var v: String = arg.get_slice("=", 1)
		if arg.begins_with("--skin="):
			skin_id = v
		elif arg.begins_with("--sky="):
			sky_name = v
		elif arg.begins_with("--lanes="):
			lanes = clampi(int(v), 3, 8)
		elif arg == "--grapple":
			grapple = true
		elif arg == "--side":
			side = true
	var skin := load("res://data/skins/%s_skin.tres" % skin_id) as ZoneSkin
	var layout := LevelLayout.new()
	layout.lane_count = lanes
	layout.length = 300.0
	var pool: Vector2 = POOL if not grapple else Vector2(70.0, 73.0)
	layout.gaps.append({"lane": lanes / 2, "start": pool.x, "end": pool.y})
	var config := LevelConfig.new()
	config.lane_count = lanes
	config.skin = skin
	var sfx := load("res://data/audio/sfx_library.tres") as SfxLibrary
	world = RunWorld.new()
	add_child(world)
	world.build(config, layout, tuning, load(RULES_PATH) as GameRules, null, Loadout.new(), sfx)
	world.player.setup(tuning, world.geo, lanes / 2)
	if grapple:
		world.player.grapples = 1
	world.player.movement_event.connect(func(kind: StringName) -> void:
		print("%5.2f s  %6.1f m  h %5.2f  %s" % [world.player.elapsed, world.player.distance, world.player.h, kind]))
	world.player.died.connect(func(cause: String) -> void:
		print("%5.2f s  %6.1f m  died: %s" % [world.player.elapsed, world.player.distance, cause]))
	var sky: LevelSky = null
	if sky_name != "":
		sky = load("res://data/skies/%s.tres" % sky_name) as LevelSky
	var env := WorldEnvironment.new()
	env.environment = skin.level_environment(0.0, sky)
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, 25.0, 0.0)
	sun.light_energy = 0.7
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(sun)
	if side:
		var camera := Camera3D.new()
		camera.fov = 60.0
		add_child(camera)
		var x: float = world.geo.lane_x(lanes / 2)
		camera.position = Vector3(x + 3.2, 1.3, TrackGeometry.world_z(pool.x - 3.0))
		camera.look_at(Vector3(x, -0.3, TrackGeometry.world_z(pool.x + 2.0)))
		camera.make_current()
	else:
		var run_camera := RunCamera.new()
		add_child(run_camera)
		run_camera.follow(world)
		run_camera.make_current()
	world.start()


func _process(_delta: float) -> void:
	if world == null or _splash_seen:
		return
	var splashes: Array[Node] = world.find_children("BeachSplash", "", true, false)
	if not splashes.is_empty():
		_splash_seen = true
		print("%5.2f s  %6.1f m  a splash at %s" % [world.player.elapsed, world.player.distance, (splashes[0] as Node3D).global_position])
