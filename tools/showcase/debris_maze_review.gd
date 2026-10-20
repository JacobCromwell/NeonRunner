extends Node3D
## Debris maze review, for visual review only (not part of the game; task O2, GDD §5 Zone 8: the Terminal's debris
## stands so thickly that the open space between it forms a maze, and its doodads are lower "so the player can see the
## maze's open paths over them"): a campaign level's own build (default the Terminal's first level) in its zone's look
## or another, around one of its maze blocks, seen from where a runner sees it on the way in, standing at its first
## wall and inside it, and from high behind, so the maze's readability (its openings and cells seen over the debris,
## how far ahead) can be judged. The track is built as in a run (TrackBuilder, the level's own doodad height). Every shot is
## saved as a PNG (the viewport's own image, so either renderer works):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot4 --path . --resolution 960x540 \
##     res://tools/showcase/debris_maze_review.tscn -- --out=build/maze
## (add --rendering-method gl_compatibility before the scene path for the web / low-end renderer).
## Options (after --):
##   --level=id      a campaign step (default terminal/1)
##   --skin=name     a skin in data/skins/ (name_skin.tres), `greybox`, or a res:// path (default: the level's own)
##   --lanes=N       lane count (default 5)
##   --block=N       around the level's Nth maze block (default 0, the first)
##   --out=DIR       where the PNGs go, under the project (default build/maze), named <skin>_<n>_<shot>.png
##   --shot=a,b      only the shots whose short name is listed (default all: see _shot_list())
##   --doodad_height=M, --camera_height=M, --camera_distance=M   what-ifs for review: the level's debris at another
##                   height, the game camera higher or further back (MovementTuning's camera_height, camera_distance)
## Each shot's number, file and label are printed, and the block's walls and rooms.

const TUNING_PATH: String = "res://data/tuning/movement.tres"
const CAMPAIGN_PATH: String = "res://data/campaign/campaign.tres"
## Frames to let a shot settle (chunk building, the first draw, shaders) before the image is taken.
const SETTLE: int = 4

var tuning: MovementTuning
var skin: ZoneSkin
var lanes: int = 5
var track: TrackBuilder
var camera: Camera3D
var layout: LevelLayout
var geo: TrackGeometry
var _shots: Array = []
var _index: int = 0
var _frame: int = 0
var _prefix: String = ""


func _ready() -> void:
	tuning = load(TUNING_PATH) as MovementTuning
	lanes = int(_opt("lanes", "5"))
	var campaign := load(CAMPAIGN_PATH) as Campaign
	var step: CampaignStep = campaign.step(_opt("level", "terminal/1"))
	if step == null or not step.is_level():
		push_error("debris_maze_review: no campaign level %s" % _opt("level", "terminal/1"))
		get_tree().quit(1)
		return
	var config: LevelConfig = campaign.configure(step, lanes)
	# What-ifs for review only (the data is not touched): another debris height, another camera.
	if _opt("doodad_height", "") != "":
		config.doodad_height = float(_opt("doodad_height", "0"))
	tuning = (config.movement_for(tuning) as MovementTuning).duplicate() as MovementTuning
	if _opt("camera_height", "") != "":
		tuning.camera_height = float(_opt("camera_height", "0"))
	if _opt("camera_distance", "") != "":
		tuning.camera_distance = float(_opt("camera_distance", "0"))
	layout = LevelGenerator.new().generate(config, load(TUNING_PATH) as MovementTuning, LevelGenerator.load_for(config))
	if layout.maze.is_empty():
		push_error("debris_maze_review: %s has no debris maze" % step.id)
		get_tree().quit(1)
		return
	var skin_name: String = _opt("skin", "")
	if skin_name == "greybox":
		skin = GreyboxSkin.new()
	elif skin_name != "":
		skin = load(skin_name if skin_name.begins_with("res://") else "res://data/skins/%s_skin.tres" % skin_name) as ZoneSkin
	else:
		skin = config.skin if config.skin != null else GreyboxSkin.new()
		skin_name = skin.resource_path.get_file().get_basename().trim_suffix("_skin") if skin.resource_path != "" else "greybox"
	var out_dir: String = _opt("out", "build/maze")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + out_dir))
	_prefix = "res://%s/%s_" % [out_dir, skin_name.get_file().get_basename().trim_suffix("_skin")]
	var env := WorldEnvironment.new()
	env.environment = skin.level_environment(config.darkness, config.sky)
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, 25.0, 0.0)
	sun.light_energy = 0.7
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(sun)
	geo = TrackGeometry.new(lanes, tuning)
	track = TrackBuilder.new()
	add_child(track)
	camera = Camera3D.new()
	camera.far = 600.0
	camera.fov = tuning.camera_fov
	add_child(camera)
	camera.make_current()
	_shots = _shot_list()
	var only: String = _opt("shot", "")
	if only != "":
		var names: PackedStringArray = only.split(",")
		_shots = _shots.filter(func(s: Array) -> bool: return names.has(String(s[3])))
	if _shots.is_empty():
		get_tree().quit()
		return
	_show(0)


static func _opt(opt_name: String, default: String) -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--%s=" % opt_name):
			return arg.get_slice("=", 1)
	return default


## A game camera as the runner has it (a copy of scripts/run/run_camera.gd's follow, without shake, settled): the
## runner at world x `x`, height `y` and track distance `d`.
func _follow(d: float, x: float, y: float) -> Array:
	var cam_y: float = tuning.camera_height + y * tuning.camera_follow_y
	var look_y: float = y * tuning.camera_follow_y + 1.0
	var cx: float = x * tuning.camera_follow_x
	return [Vector3(cx, cam_y, -(d - tuning.camera_distance)), Vector3(cx, look_y, -(d + tuning.camera_look_ahead))]


## Shots around the chosen block: [distance of the track to build from, camera position, look-at point, short name,
## label]. The runner's lane is the middle one on the way in, and an open lane of the first room inside.
func _shot_list() -> Array:
	var k: int = clampi(int(_opt("block", "0")), 0, layout.maze.size() - 1)
	var b: Dictionary = layout.maze[k]
	var start: float = float(b["start"])
	var walls: Array = b["walls"]
	var rooms: Array = b["rooms"]
	print("block %d: run-in %.1f, walls %s, rooms %s, breather to %.1f, %d breaks" % [k, float(b["entry"]),
		walls.map(func(w: Dictionary) -> String: return "%.0f-%.0f open %s" % [w["start"], w["end"], w["open"]]),
		rooms.map(func(r: Dictionary) -> String: return "%.0f-%.0f dividers %s" % [r["start"], r["end"], r["dividers"]]),
		float(b["exit"]), int(b["breaks"])])
	var mid: int = lanes / 2
	var half: float = tuning.visual_size.z * 0.5
	var out: Array = []
	for before: float in [60.0, 35.0, 15.0]:
		var ride: Array = _follow(start - before, geo.lane_x(mid), 0.0)
		out.append([start - before - 20.0, ride[0], ride[1], "in_%d" % int(before),
			"the game camera %.0f m before the block's first wall, middle lane" % before])
	var at_wall: Array = _follow(start - half - 0.02, geo.lane_x(mid), 0.0)
	out.append([start - 40.0, at_wall[0], at_wall[1], "stopped", "the game camera stopped at the first wall, middle lane"])
	var room: Dictionary = rooms[0]
	var cells: Array[Vector2i] = DebrisMaze.cells_of(room["dividers"], lanes)
	var lane: int = cells[0].x if not cells.is_empty() else mid
	for c: Vector2i in cells:
		if mid >= c.x and mid <= c.y:
			lane = mid
	var inside: Array = _follow(float(room["start"]) + half + 2.0, geo.lane_x(lane), 0.0)
	out.append([start - 30.0, inside[0], inside[1], "inside", "the game camera just inside the first room, lane %d" % lane])
	# High over the middle of the track, under a tunnel's vault (the Terminal's is about 8 m up), looking down the block.
	out.append([start - 40.0, Vector3(0.0, 6.5, -(start - 14.0)), Vector3(0.0, 0.0, -(start + 30.0)), "high",
		"high and behind: the first walls, rooms and openings"])
	return out


func _process(_delta: float) -> void:
	if _shots.is_empty():
		return
	_frame += 1
	if _frame < SETTLE:
		return
	var shot: Array = _shots[_index]
	var file: String = "%s%02d_%s.png" % [_prefix, _index, shot[3]]
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(file))
	print("shot %d (%s): %s" % [_index, file.get_file(), String(shot[4])])
	_index += 1
	if _index >= _shots.size():
		get_tree().quit()
		return
	_show(_index)


func _show(index: int) -> void:
	var shot: Array = _shots[index]
	# The track only builds forward: start it over for every shot, from a little before the spot.
	track.set_layout(layout, tuning, skin)
	track.update(maxf(float(shot[0]), 0.0), maxf(float(shot[0]), 0.0) / tuning.run_speed)
	camera.position = shot[1]
	camera.look_at(shot[2])
	_frame = 0
