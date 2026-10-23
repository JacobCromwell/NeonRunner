extends Node3D
## Review scene for the runner's cinematic poses (CinePoses), for visual review only (not part of the game): a row of the
## runner in one pose, seen from the side (facing the viewer's right), each at the next step of the pose's leg phase and every
## one standing on the same slope, so a crawl or a climb can be judged over a whole cycle. Render it:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot4 --path . --resolution 1280x400 --fixed-fps 10 \
##     --write-movie build/pose/f.png --quit-after 3 res://tools/showcase/cine_pose_review.tscn -- --pose=crawl --slope=30
## Options (after --):
##   --pose=crawl      the pose (CinePoses.POSES: crawl, squeeze, walk, wipe, ...)
##   --slope=0         the ground's slope in degrees, rising toward the way the runner faces
##   --progress=-1     the pose's progress, 0-1 (below 0: from the slope, as the Terminal intro keys the crawl: slope / 45 degrees)
##   --count=8         runners in the row, spread over one cycle of the leg phase
##   --phase=0         the leg phase the first one is at (0-1)
##   --size=0          the view's height in metres (0: to fit the row)
##   --spacing=1.6     metres between them along the slope
##   --front           seen from in front and a little above instead of the side
##   --bounds          prints the pose's bounds (how high and how far forward) at steps of its progress and phase instead, and quits
## Prints, for each, where its joints lie (along the slope from its key, and off the slope's surface).

const TUNING_PATH: String = "res://data/tuning/movement.tres"


func _ready() -> void:
	var tuning := load(TUNING_PATH) as MovementTuning
	var pose_name: StringName = StringName(_opt("pose", "crawl"))
	var slope: float = float(_opt("slope", "0"))
	var count: int = int(_opt("count", "8"))
	var spacing: float = float(_opt("spacing", "1.6"))
	var progress: float = float(_opt("progress", "-1"))
	if progress < 0.0:
		progress = CinePoses.crawl_progress(slope)
	if _has("bounds"):
		_print_bounds(tuning, pose_name)
		get_tree().quit()
		return
	var env := WorldEnvironment.new()
	env.environment = GreyboxSkin.new().make_environment()
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40.0, 40.0, 0.0)
	sun.light_energy = 0.9
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(sun)
	# The ground: a slab tilted so that it rises toward -z (the way the runner faces), its surface through the origin.
	var length: float = spacing * float(count) + 6.0
	var ground := Node3D.new()
	ground.rotation_degrees = Vector3(slope, 0.0, 0.0)
	add_child(ground)
	GreyboxMaterials.add_box(ground, Vector3(0.0, -0.1, -length * 0.5 + 2.0), Vector3(6.0, 0.2, length), GreyboxMaterials.flat(Color(0.3, 0.3, 0.34)))
	for k: int in int(length / 0.5):
		GreyboxMaterials.add_box(ground, Vector3(0.0, 0.005, 2.0 - float(k) * 0.5), Vector3(6.0, 0.012, 0.03), GreyboxMaterials.flat(Color(0.18, 0.18, 0.2)))
	var cos_s: float = cos(deg_to_rad(slope))
	for i: int in count:
		var phase: float = fposmod(float(i) / float(count) + float(_opt("phase", "0")), 1.0)
		var along: float = spacing * float(i)
		var avatar := PlayerAvatar.new()
		avatar.fit_to(tuning.visual_size)
		add_child(avatar)
		avatar.set_process(false)
		avatar.set_physics_process(false)
		# Its key's place: on the slope at `along` metres up it.
		avatar.position = Vector3(0.0, along * sin(deg_to_rad(slope)), -along * cos_s)
		var rig: HumanoidRig = avatar.rig
		var pose := HumanoidPose.new()
		CinePoses.runner(pose, pose_name, progress, 0.0, rig.parts.pelvis_height(), phase)
		rig.apply_pose(pose)
		# How far its joints are along the slope from its key (toward the way it faces) and off its surface (perpendicular, metres).
		var report: PackedStringArray = []
		for joint: StringName in [&"pelvis", &"chest", &"neck", &"head", &"upper_arm_r", &"hand_r", &"hand_l", &"thigh_r", &"shin_r", &"shin_l", &"foot_r", &"foot_l"]:
			var p: Vector3 = rig.joint(joint).global_position
			var rel: Vector3 = p - avatar.position
			report.append("%s %+.2f,%+.2f" % [joint, -rel.z * cos_s + rel.y * sin(deg_to_rad(slope)), _off_surface(p, slope)])
		print("phase %.2f  %s" % [phase, "  ".join(report)])
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	var mid: float = spacing * float(count - 1) * 0.5
	var mid_y: float = mid * sin(deg_to_rad(slope))
	if _has("front"):
		cam.size = 4.0
		cam.look_at_from_position(Vector3(0.0, mid_y + 4.0, -mid * cos_s + 9.0), Vector3(0.0, mid_y + 0.5, -mid * cos_s))
	else:
		cam.size = float(_opt("size", "0")) if float(_opt("size", "0")) > 0.0 else maxf(spacing * float(count) * 0.5, 2.6)
		cam.look_at_from_position(Vector3(12.0, mid_y + 0.9, -mid * cos_s), Vector3(0.0, mid_y + 0.9, -mid * cos_s))
	add_child(cam)
	cam.make_current()


## How far a world point is off the slope's surface (perpendicular, + above it).
static func _off_surface(p: Vector3, slope: float) -> float:
	var s: float = sin(deg_to_rad(slope))
	var c: float = cos(deg_to_rad(slope))
	# The surface normal is (0, c, s) (it rises toward -z).
	return p.y * c + p.z * s


static func _opt(opt_name: String, default: String) -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--%s=" % opt_name):
			return arg.get_slice("=", 1)
	return default


static func _has(flag: String) -> bool:
	return OS.get_cmdline_user_args().has("--" + flag)


## The pose's bounds over its progress and phase: how high above the ground its body reaches, and how far ahead and behind of its key.
func _print_bounds(tuning: MovementTuning, pose_name: StringName) -> void:
	var avatar := PlayerAvatar.new()
	avatar.fit_to(tuning.visual_size)
	add_child(avatar)
	var rig: HumanoidRig = avatar.rig
	var pose := HumanoidPose.new()
	for k: int in 11:
		var worst_up: float = 0.0
		var ahead: float = -INF
		var behind: float = INF
		for ph: int in 8:
			CinePoses.runner(pose, pose_name, float(k) / 10.0, 0.0, rig.parts.pelvis_height(), float(ph) / 8.0)
			rig.apply_pose(pose)
			var b: AABB = rig.bounds()
			worst_up = maxf(worst_up, b.end.y)
			ahead = maxf(ahead, -b.position.z)
			behind = minf(behind, -b.end.z)
		print("progress %.1f: up to %.2f m, from %.2f m behind to %.2f m ahead" % [float(k) / 10.0, worst_up, behind, ahead])
