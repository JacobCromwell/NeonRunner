extends Node3D
## Review scene for the Casino's boss intro people (CasinoPeople's eight looks on CasinoPerson), for visual review only
## (not part of the game): a line-up on a plain floor under a warm light, like the owner's reference sheet
## (docs/art/reference/casino_patrons.webp), the faces toward the camera, left to right in CasinoPeople.Look order. Render
## it (a wide frame for the line-up; add --rendering-method gl_compatibility before the scene path for the web / low-end
## renderer):
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot4 --path . --resolution 1600x600 --fixed-fps 10 \
##     --write-movie build/casino_people/f.png --quit-after 8 res://tools/showcase/casino_people_showcase.tscn -- --pose=walk
## Options (after --):
##   --pose=NAME     stand (default), walk (each walking in place at a steady 1.2 m/s), cheer, clap, drink (each look's right
##                   hand, her left with the glass), lean (leaning back on both elbows), flick (the right hand's flick)
##   --look=NAME     one look (a close-up) or several (--look=GRIMY,DEALER, a group) instead of all eight: LADY_IN_RED,
##                   ESCORT_BLACK, ESCORT_BLONDE, LADY_LUCK, GRIMY, HIGH_ROLLER, DEALER, CHAIRMAN (case ignored)
##   --bust          with one look: just the head and shoulders
##   --look-at       everyone turns head and eyes toward a point to their right (look_at_point)
##   --turn=DEG      turns everyone about their vertical axis (0 faces the camera, 180 shows the back, 90 the left side)
##   --t=S           starts the clock S seconds in (a different moment of a pose's cycle)
##   --stats         print every look's triangle count, draw calls and height as modelled
## Frame N is at N / 10 s of the clock.

const HEIGHTS: Dictionary = {
	CasinoPeople.Look.LADY_IN_RED: 1.7, CasinoPeople.Look.ESCORT_BLACK: 1.7, CasinoPeople.Look.ESCORT_BLONDE: 1.7,
	CasinoPeople.Look.LADY_LUCK: 1.64, CasinoPeople.Look.GRIMY: 1.76, CasinoPeople.Look.HIGH_ROLLER: 1.84,
	CasinoPeople.Look.DEALER: 1.76, CasinoPeople.Look.CHAIRMAN: 1.92,
}
const SPACING: float = 1.0
const WALK_SPEED: float = 1.2

var _pose: String = "stand"
var _people: Array[CasinoPerson] = []
var _t: float = 0.0
var _walked: float = 0.0


func _ready() -> void:
	_pose = _opt("pose", "stand")
	_t = float(_opt("t", "0"))
	var looks: Array = CasinoPeople.Look.values()
	if _opt("look", "") != "":
		looks = []
		for look_name: String in _opt("look", "").split(",", false):
			var index: int = CasinoPeople.Look.keys().find(look_name.strip_edges().to_upper())
			if index < 0:
				push_error("casino_people_showcase: no look %s" % look_name)
			else:
				looks.append(index)
	_build_environment()
	for i: int in looks.size():
		var person := CasinoPerson.new()
		person.position = Vector3((i - (looks.size() - 1) * 0.5) * SPACING, 0.0, 0.0)
		person.rotation.y = PI + deg_to_rad(float(_opt("turn", "0")))
		add_child(person)
		person.setup(looks[i], HEIGHTS[looks[i]])
		_people.append(person)
	if _has("stats"):
		for person: CasinoPerson in _people:
			print("%-14s %4d triangles, %d draw calls, %.3f m as modelled, %s" % [CasinoPeople.look_name(person.look),
				CasinoPeople.triangle_count(person.look), person.rig.draw_call_count(),
				CasinoPeople.design_height(person.look), "panels" if CasinoPeople.has_panels(person.look) else "-"])
	var camera := Camera3D.new()
	add_child(camera)
	camera.fov = 28.0
	if looks.size() == 1 and _has("bust"):
		var at := Vector3(0.0, HEIGHTS[looks[0]] * 0.83, 0.0)
		camera.look_at_from_position(Vector3(0.0, at.y + 0.04, 2.2), at)
	else:
		# Far enough back for the whole group (and tall enough for the tallest) to fit the frame.
		var distance: float = maxf(4.6, (looks.size() * SPACING + 0.8) / 0.88)
		camera.look_at_from_position(Vector3(0.0, 1.0, distance), Vector3(0.0, 0.93, 0.0))
	camera.make_current()
	_apply(0.0, 0.0)


func _process(delta: float) -> void:
	_t += delta
	_apply(_t, delta)


func _apply(t: float, delta: float) -> void:
	for person: CasinoPerson in _people:
		if _pose == "walk":
			person.walk(WALK_SPEED * delta, WALK_SPEED, t, delta)
		else:
			person.stand(t, delta)
		match _pose:
			"cheer":
				person.cheer(1.0, t)
			"clap":
				person.clap(1.0, t)
			"drink":
				person.drink(1.0, -1 if CasinoPeople.has_glass(person.look) else 1)
			"lean":
				person.lean_back_elbows(1.0)
			"flick":
				person.gesture_flick(1.0, t)
		if _has("look-at"):
			person.look_at_point(Vector3(3.0, 1.6, 3.0), 1.0)


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.13, 0.1, 0.09)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.45, 0.4)
	env.ambient_light_energy = 0.8
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35.0, -20.0, 0.0)
	key.light_color = Color(1.0, 0.86, 0.68)
	key.light_energy = 1.1
	add_child(key)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(-3.0, 2.6, 3.0)
	lamp.light_color = Color(1.0, 0.8, 0.55)
	lamp.light_energy = 1.4
	lamp.omni_range = 14.0
	add_child(lamp)
	var floor_mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(24.0, 0.1, 10.0)
	floor_mesh.mesh = box
	floor_mesh.position = Vector3(0.0, -0.05, 0.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.12, 0.14)
	mat.roughness = 0.9
	floor_mesh.material_override = mat
	add_child(floor_mesh)


static func _opt(opt_name: String, default: String) -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--%s=" % opt_name):
			return arg.get_slice("=", 1)
	return default


static func _has(flag: String) -> bool:
	return OS.get_cmdline_user_args().has("--" + flag)
