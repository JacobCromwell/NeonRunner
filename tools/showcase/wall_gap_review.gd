extends Node3D
## Side wall gap review, for visual review only (not part of the game; task L4: "there is a hole in the wall, and one
## of the buildings in the background doesn't have any other sides to it"): a hand-built open street in a zone's
## look with side wall gaps of the lengths the generator places (about 0.6-1.1 s of run, 13-25 m; the Beach's open
## stretches are much longer), seen from where a runner sees them: the game's camera on the approach, in the gap, from
## the outer lane and on the wall, then looking out through the opening at floor, mid-wall (wall-run) and ceiling
## heights, and back at it from across the street. Every shot is saved as a PNG (the viewport's own image, so a
## window size and either renderer work):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot4 --path . --resolution 960x540 \
##     res://tools/showcase/wall_gap_review.tscn -- --skin=marketplace --out=build/wallgap/before
## (add --rendering-method gl_compatibility before the scene path for the web / low-end renderer).
## Options (after --):
##   --skin=name     a skin in data/skins/ (name_skin.tres) or a res:// path (default: marketplace)
##   --lanes=N       lane count (default 5)
##   --out=DIR       where the PNGs go, under the project (default build/wallgap), named <skin>_<n>_<shot>_g<gap>.png
##   --gap=N         only gap N of GAPS (0 left, 1 right, 2 both walls, 3 a second left; default all)
##   --shot=a,b      only the shots whose short name is listed (default all: see _shot_list())
##   --long          also the long open stretches (right wall, left wall, both) of the Beach's levels
##   --darkness=X    a level's darker lighting (0-1)
## Each shot's number, file and label are printed.

const TUNING_PATH: String = "res://data/tuning/movement.tres"
const LENGTH: float = 1400.0
## The wall gaps as Vector3(side, start, end); side 0 is both walls over the same stretch.
const GAPS: Array[Vector3] = [Vector3(-1, 150.0, 170.0), Vector3(1, 270.0, 290.0), Vector3(0, 400.0, 425.0),
	Vector3(-1, 540.0, 560.0)]
## --long: the Beach's open stretches (right, left, both).
const LONG_GAPS: Array[Vector3] = [Vector3(1, 700.0, 860.0), Vector3(-1, 940.0, 1100.0), Vector3(0, 1160.0, 1300.0)]
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
var _gaps: Array[Vector3] = []


func _ready() -> void:
	tuning = load(TUNING_PATH) as MovementTuning
	lanes = int(_opt("lanes", "5"))
	var skin_name: String = _opt("skin", "marketplace")
	var path: String = skin_name if skin_name.begins_with("res://") else "res://data/skins/%s_skin.tres" % skin_name
	skin = load(path) as ZoneSkin
	var out_dir: String = _opt("out", "build/wallgap")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + out_dir))
	_prefix = "res://%s/%s_" % [out_dir, skin_name.get_file().get_basename().trim_suffix("_skin")]
	var env := WorldEnvironment.new()
	env.environment = skin.level_environment(float(_opt("darkness", "0")), null)
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, 25.0, 0.0)
	sun.light_energy = 0.7
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(sun)
	geo = TrackGeometry.new(lanes, tuning)
	_gaps.assign(GAPS)
	if _flag("long"):
		_gaps.append_array(LONG_GAPS)
	layout = _layout()
	track = TrackBuilder.new()
	add_child(track)
	track.set_layout(layout, tuning, skin)
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
	var gap_only: String = _opt("gap", "")
	if gap_only != "":
		var keep: int = int(gap_only)
		_shots = _shots.filter(func(s: Array) -> bool: return int(s[4]) == keep)
	_show(0)


static func _opt(opt_name: String, default: String) -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--%s=" % opt_name):
			return arg.get_slice("=", 1)
	return default


static func _flag(opt_name: String) -> bool:
	return OS.get_cmdline_user_args().has("--%s" % opt_name)


func _layout() -> LevelLayout:
	var out := LevelLayout.new()
	out.lane_count = lanes
	out.length = LENGTH
	for g: Vector3 in _gaps:
		for side: int in ([-1, 1] if int(g.x) == 0 else [int(g.x)]):
			out.wall_gaps.append({"side": side, "start": g.y, "end": g.z})
	return out


## A game camera as the runner has it (a copy of scripts/run/run_camera.gd's follow, without shake, settled): the
## runner at world x `x`, height `y` and track distance `d`.
func _follow(d: float, x: float, y: float) -> Array:
	var cam_y: float = tuning.camera_height + y * tuning.camera_follow_y
	var look_y: float = y * tuning.camera_follow_y + 1.0
	var cx: float = x * tuning.camera_follow_x
	return [Vector3(cx, cam_y, -(d - tuning.camera_distance)), Vector3(cx, look_y, -(d + tuning.camera_look_ahead))]


## Shots: [distance of the track to build around, camera position, look-at point, short name, gap index, label].
func _shot_list() -> Array:
	var w: float = geo.wall_x()
	var out: Array = []
	for i: int in _gaps.size():
		var g: Vector3 = _gaps[i]
		var s: float = g.x if g.x != 0.0 else 1.0
		var a: float = g.y
		var b: float = g.z
		var m: float = (a + b) * 0.5
		var tag: String = "%s wall's gap %d" % [("both walls'" if g.x == 0.0 else ("left" if g.x < 0.0 else "right")), i]
		var ride: Array = _follow(a - 30.0, 0.0, 0.0)
		out.append([a - 30.0, ride[0], ride[1], "approach", i, "%s, the game camera 30 m before it, middle lane" % tag])
		ride = _follow(a - 10.0, 0.0, 0.0)
		out.append([a - 10.0, ride[0], ride[1], "close", i, "%s, the game camera 10 m before it, middle lane" % tag])
		ride = _follow(a + (b - a) * 0.4, 0.0, 0.0)
		out.append([a, ride[0], ride[1], "inside", i, "%s, the game camera in it, middle lane" % tag])
		var outer: float = s * (geo.half_width() - geo.lane_width * 0.5)
		ride = _follow(a - 6.0, outer, 0.0)
		out.append([a, ride[0], ride[1], "outer", i, "%s, the game camera in the outer lane beside it" % tag])
		ride = _follow(a - 6.0, s * (w - 0.6), 2.0)
		out.append([a, ride[0], ride[1], "wallrun", i, "%s, the game camera on the wall (a wall run) coming up to it" % tag])
		# Out through the opening, at floor, wall-run and ceiling heights, from just inside the wall.
		for k: Array in [["low", 1.1, 1.1], ["mid", 2.5, 2.2], ["high", 5.4, 3.0]]:
			out.append([a, Vector3(s * (w - 1.2), float(k[1]), -(a + (b - a) * 0.3)),
				Vector3(s * 60.0, float(k[2]), -(a + (b - a) * 0.3 + 14.0)),
				"out_" + String(k[0]), i, "%s, out through it at %s height" % [tag, k[0]]])
		# And out through it from the middle of the street, across it (the gap's whole span in view).
		out.append([a, Vector3(0.0, 2.2, -(m - 2.0)), Vector3(s * 60.0, 2.0, -(m + 0.5)), "out_street", i,
			"%s, out through it from the middle of the street at running height" % tag])
		# Back at it from across the street.
		out.append([a, Vector3(-s * (w - 1.2), 2.2, -(a - 6.0)), Vector3(s * w, 2.4, -(m + 4.0)), "across", i,
			"%s, from across the street" % tag])
		# From well above and behind: the whole cut in the block.
		out.append([a, Vector3(-s * 2.0, 30.0, -(a - 36.0)), Vector3(s * w, 0.0, -(m + 6.0)), "above", i,
			"%s, from above the street" % tag])
	return out


func _process(_delta: float) -> void:
	_frame += 1
	if _frame < SETTLE:
		return
	var shot: Array = _shots[_index]
	var file: String = "%s%02d_%s_g%d.png" % [_prefix, _index, shot[3], int(shot[4])]
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(file))
	print("shot %d (%s): %s" % [_index, file.get_file(), String(shot[5])])
	_index += 1
	if _index >= _shots.size():
		get_tree().quit()
		return
	_show(_index)


func _show(index: int) -> void:
	var shot: Array = _shots[index]
	# The track only builds forward: start it over for every shot.
	track.set_layout(layout, tuning, skin)
	track.update(float(shot[0]), float(shot[0]) / tuning.run_speed)
	camera.position = shot[1]
	camera.look_at(shot[2])
	_frame = 0
