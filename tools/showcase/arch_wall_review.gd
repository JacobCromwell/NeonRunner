extends Node3D
## Arch wall review, for visual review only (not part of the game; task O1, GDD §5 Zone 8: the Terminal's side walls
## are narrow arches, one space long with about six lengths of open space before the next, mostly in pairs, a missing
## one a stump cut off about halfway up): a campaign level's own build (default the Terminal's first level) in its
## zone's look or another, around its first broken stump, seen from where a runner sees it and from the side, so the
## arches can be judged as spaced pillars and the stumps as ruins. TrackBuilder draws the level's walls as it does in a
## run (TrackBuilder._build_boundary_wall: ZoneSkin.wall_section over each arch, wall_opening over the open space,
## wall_stump over each stump). Every shot is saved as a PNG (the viewport's own image, so either renderer works):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot4 --path . --resolution 960x540 \
##     res://tools/showcase/arch_wall_review.tscn -- --skin=greybox --out=build/arches
## (add --rendering-method gl_compatibility before the scene path for the web / low-end renderer).
## Options (after --):
##   --level=id      a campaign step (default terminal/1)
##   --skin=name     a skin in data/skins/ (name_skin.tres), `greybox`, or a res:// path (default: the level's own)
##   --lanes=N       lane count (default 5)
##   --stump=N       around the level's Nth broken stump (default 0, the first)
##   --out=DIR       where the PNGs go, under the project (default build/arches), named <skin>_<n>_<shot>.png
##   --shot=a,b      only the shots whose short name is listed (default all: see _shot_list())
## Each shot's number, file and label are printed, and the walls' layout around the stump.

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
		push_error("arch_wall_review: no campaign level %s" % _opt("level", "terminal/1"))
		get_tree().quit(1)
		return
	var config: LevelConfig = campaign.configure(step, lanes)
	tuning = config.movement_for(tuning)
	layout = LevelGenerator.new().generate(config, load(TUNING_PATH) as MovementTuning, LevelGenerator.load_for(config))
	var skin_name: String = _opt("skin", "")
	if skin_name == "greybox":
		skin = GreyboxSkin.new()
	elif skin_name != "":
		skin = load(skin_name if skin_name.begins_with("res://") else "res://data/skins/%s_skin.tres" % skin_name) as ZoneSkin
	else:
		skin = config.skin if config.skin != null else GreyboxSkin.new()
		skin_name = skin.resource_path.get_file().get_basename().trim_suffix("_skin") if skin.resource_path != "" else "greybox"
	var out_dir: String = _opt("out", "build/arches")
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


## Shots around the level's chosen broken stump (or, without one, its first arch past the run-up): [distance of the
## track to build around, camera position, look-at point, short name, label].
func _shot_list() -> Array:
	var w: float = geo.wall_x()
	var at: float = 200.0
	var s: float = -1.0
	var stumps: Array[Dictionary] = layout.wall_stumps
	var k: int = clampi(int(_opt("stump", "0")), 0, maxi(stumps.size() - 1, 0))
	if not stumps.is_empty():
		at = float(stumps[k]["start"])
		s = float(stumps[k]["side"])
	print("walls around %.0f m: left arches %s, right arches %s, stumps %s" % [at,
		layout.wall_solid_pieces(-1, at - 60.0, at + 60.0), layout.wall_solid_pieces(1, at - 60.0, at + 60.0),
		layout.wall_stump_spans(int(s), at - 60.0, at + 60.0)])
	var out: Array = []
	var ride: Array = _follow(at - 45.0, 0.0, 0.0)
	out.append([at - 45.0, ride[0], ride[1], "approach", "the game camera 45 m before the stump, middle lane"])
	ride = _follow(at - 15.0, s * (geo.half_width() - geo.lane_width * 0.5), 0.0)
	out.append([at - 15.0, ride[0], ride[1], "outer", "the game camera 15 m before it, in the outer lane on its side"])
	out.append([at - 30.0, Vector3(-s * (w - 1.5), 2.2, -(at - 20.0)), Vector3(s * w, 2.4, -(at + 6.0)), "across",
		"its wall from across the street, at running height"])
	out.append([at - 40.0, Vector3(0.0, 2.2, -(at - 2.0)), Vector3(s * 60.0, 2.4, -(at + 1.8)), "side",
		"straight out at the stump from the middle of the street"])
	out.append([at - 60.0, Vector3(-s * 2.0, 30.0, -(at - 50.0)), Vector3(s * w * 0.6, 0.0, -(at + 20.0)), "above",
		"from above and behind: both walls' arches and the stump"])
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
