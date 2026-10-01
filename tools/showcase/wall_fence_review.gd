extends Node3D
## Visual review for wall fences (task B5; GDD §9.1: "the same pink crackle, strung across the wall-run
## path between emitters on the facade"): a real RunWorld on a hand-built track lined with wall fences in
## a zone's look, seen through the game's camera (RunCamera) as a runner passes them, or from a fixed
## camera beside the track.
## The right wall carries full-height ones held off (40 m), in their warning (70 m) and on (100 m), then a
## low one (130 m) and a high one (160 m); the left wall a low one (145 m) and a high one (175 m), all on.
##
##   Render:  godot --path . --resolution 960x540 --write-movie build/review/f.png --fixed-fps 10 --quit-after 100
##            res://tools/showcase/wall_fence_review.tscn -- [options]
##   Options (after --):
##     --skin=<zone id>      the zone's look (data/skins/<id>_skin.tres; default marketplace)
##     --lanes=N             lane count (default 3)
##     --wall                the runner runs along the right wall (in god mode, so the live ones let them
##                           through), stepping back onto it after each wall run; else in the right outer lane
##     --cycle               the wall fences pulse on the level clock instead of being held
##     --camera=chase|side   chase: the game's camera (default); side: fixed beside the track, looking at
##                           the right wall from a little before --at
##     --at=D                the side camera's spot along the track (default 100: the full one held on)
##     --reduced-flashing    Reduced flashing on (warnings hold a steady glow)
## Each movement event is printed with its time and distance, to find the frames (frame = time × fps).

const TUNING_PATH: String = "res://data/tuning/movement.tres"
const RULES_PATH: String = "res://data/tuning/game_rules.tres"
## [side, at, band, held state] for each wall fence of the track.
const FENCES: Array = [
	[1, 40.0, "full", Hazard.State.OFF], [1, 70.0, "full", Hazard.State.WARNING], [1, 100.0, "full", Hazard.State.ON],
	[1, 130.0, "low", Hazard.State.ON], [1, 160.0, "high", Hazard.State.ON],
	[-1, 145.0, "low", Hazard.State.ON], [-1, 175.0, "high", Hazard.State.ON],
]

var tuning: MovementTuning
var world: RunWorld
var camera: Camera3D
var side_camera: bool = false
var cycle: bool = false
var wall: bool = false
var look_at_d: float = 100.0
var _held: Dictionary = {}
var _next_entry: float = 20.0


func _ready() -> void:
	tuning = load(TUNING_PATH) as MovementTuning
	var skin_id: String = "marketplace"
	var lanes: int = 3
	for arg: String in OS.get_cmdline_user_args():
		var v: String = arg.get_slice("=", 1)
		if arg.begins_with("--skin="):
			skin_id = v
		elif arg.begins_with("--lanes="):
			lanes = clampi(int(v), 3, 8)
		elif arg == "--wall":
			wall = true
		elif arg == "--cycle":
			cycle = true
		elif arg.begins_with("--camera="):
			side_camera = v == "side"
		elif arg.begins_with("--at="):
			look_at_d = float(v)
		elif arg == "--reduced-flashing":
			Settings.flashing_reduced = true
			RenderingServer.global_shader_parameter_set(&"reduced_flashing", 1.0)
	var skin: ZoneSkin = GreyboxSkin.new()
	var skin_path: String = "res://data/skins/%s_skin.tres" % skin_id
	if ResourceLoader.exists(skin_path):
		skin = load(skin_path) as ZoneSkin
	else:
		push_warning("wall_fence_review: no skin at %s; using the grey box" % skin_path)
	var layout := LevelLayout.new()
	layout.lane_count = lanes
	layout.length = 320.0
	for f: Array in FENCES:
		layout.wall_fences.append(WallFencePlan.make(int(f[0]), float(f[1]), String(f[2]), 1.1, 1.3, 0.37 * float(f[1]) / 40.0))
	var config := LevelConfig.new()
	config.lane_count = lanes
	config.skin = skin
	var sfx := load("res://data/audio/sfx_library.tres") as SfxLibrary
	world = RunWorld.new()
	add_child(world)
	world.build(config, layout, tuning, load(RULES_PATH) as GameRules, null, Loadout.new(), sfx)
	world.player.setup(tuning, world.geo, lanes - 1)
	world.player.god_mode = wall
	world.player.movement_event.connect(func(kind: StringName) -> void:
		print("%5.2f s  %6.1f m  %s" % [world.player.elapsed, world.player.distance, kind]))
	if not cycle:
		for i: int in FENCES.size():
			_held[i] = FENCES[i][3]
	var env := WorldEnvironment.new()
	env.environment = skin.make_environment()
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, 25.0, 0.0)
	sun.light_energy = 0.7
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(sun)
	if side_camera:
		camera = Camera3D.new()
		camera.fov = 60.0
		add_child(camera)
		var wall_x: float = world.geo.wall_x()
		camera.position = Vector3(wall_x - 5.5, 2.6, TrackGeometry.world_z(look_at_d - 9.0))
		camera.look_at(Vector3(wall_x, 2.2, TrackGeometry.world_z(look_at_d + 1.0)))
	else:
		var run_camera := RunCamera.new()
		add_child(run_camera)
		run_camera.follow(world)
		camera = run_camera
	camera.make_current()
	world.start()


func _physics_process(_delta: float) -> void:
	var player: Player = world.player
	# Held states: each wall fence shows the one it's listed with, whatever the level clock says.
	for h: Hazard in world.track.wall_fence_hazards():
		var index: int = _index_of(h)
		if _held.has(index) and h.state != _held[index]:
			h.set_physics_process(false)
			h.state = _held[index]
			h.state_changed.emit(h.state)
	if wall and player.surface == Player.Surface.FLOOR and player.grounded and player.distance >= _next_entry:
		_next_entry = player.distance + 6.0
		player.press(&"move_right")


## The FENCES entry a built wall fence comes from (by its wall and spot), or -1.
func _index_of(h: Hazard) -> int:
	var side: int = 1 if h.global_position.x > 0.0 else -1
	for i: int in FENCES.size():
		if int(FENCES[i][0]) == side and absf(float(FENCES[i][1]) + h.global_position.z) < 0.5:
			return i
	return -1
