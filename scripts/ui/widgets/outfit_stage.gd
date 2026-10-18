class_name OutfitStage
extends SubViewport
## The little stage the shop's outfit previews are drawn on (GDD §8, "Cosmetics"; OutfitPreview shows it, OutfitStills
## takes the pictures of it): a PlayerAvatar built for one outfit, with no power-ups on, on a pedestal in a world of
## its own (the lights, the backdrop and the pedestal are the stage's, not any zone's), seen from the front by a narrow
## lens. It never touches the game: the avatar is a separate instance (it never changes `PlayerOutfits.worn`) and the
## lights cast no shadows. It reads the same on the Compatibility renderer: plain spatial shading, the filmic tone
## mapping and a soft bloom the game's own environments use, and a backdrop that is a picture on a plane, because the
## environment's background colour is not shown the same by the two renderers.
##
## Two ways to use it:
##   a still: `dress(id)`, `pose_still()`, `draw_once()`, then read the picture (OutfitStills does, once per outfit and
##     size for the whole session): the runner in a run pose turned three-quarters to the camera, drawn once;
##   live: `set_live(true)` makes the runner run in place and turn slowly, the stage drawn every frame, until
##     `set_live(false)`.
## The size is the picture's, in pixels (`OutfitPreview.pixel_size_for`).

## The camera: a narrow lens from the front, aimed at the middle of the runner (metres, the avatar's design size, 1.33 m
## to the hair tips). The distance fits a figure and its swinging arms in a frame about 0.7 as wide as it is tall, with
## the pedestal under the feet.
const CAMERA_FOV: float = 30.0
const CAMERA_POSITION := Vector3(0.0, 0.8, -3.25)
const CAMERA_TARGET := Vector3(0.0, 0.64, 0.0)
## The still's yaw (radians): turned from the camera to show the front and the left (the gold, cyber) arm.
const STILL_YAW: float = -0.65
## The stride phase of the still, as the avatar_showcase's run sheet (a long stride, both arms clear of the body).
const STILL_PHASE: float = 0.35
## Live: the run's speed (metres a second: it sets the stride, as the avatar_showcase's turntable) and the turn
## (radians a second; a full turn in about nine seconds).
const RUN_SPEED: float = 6.0
const TURN_SPEED: float = 0.7

## A dark navy backdrop that brightens behind the runner, cool ambient light, a key light from the front and above, a
## cool light from behind for the outline, and a pedestal in the interface's azure (never a hazard colour).
const BACKDROP_CENTER := Color(0.1, 0.17, 0.32)
const BACKDROP_EDGE := Color(0.02, 0.03, 0.075)
## The backdrop plane's size and distance behind the runner (metres): it covers the view with room to spare.
const BACKDROP_SIZE: float = 5.0
const BACKDROP_DEPTH: float = 1.5
const AMBIENT := Color(0.62, 0.68, 0.88)
const AMBIENT_ENERGY: float = 0.8
const KEY_LIGHT := Color(1.0, 0.97, 0.92)
const KEY_ENERGY: float = 1.15
const KEY_ROTATION := Vector3(-38.0, 145.0, 0.0)
const BACK_LIGHT := Color(0.5, 0.65, 1.0)
const BACK_ENERGY: float = 0.7
const BACK_ROTATION := Vector3(-25.0, -20.0, 0.0)
const PEDESTAL := Color(0.22, 0.62, 1.0)
const PEDESTAL_RADIUS: float = 0.44
## What the stage draws besides the runner: the pedestal's disc and ring and the backdrop (draw calls).
const SCENERY_DRAW_CALLS: int = 3

## The runner: null until `dress` is called.
var avatar: PlayerAvatar

static var _environment: Environment

var _pivot: Node3D
var _live: bool = false
var _turn: float = 0.0
var _distance: float = 0.0


func _init() -> void:
	name = "OutfitStage"
	own_world_3d = true
	var world := World3D.new()
	world.environment = OutfitStage._stage_environment()
	world_3d = world
	size = Vector2i(OutfitPreview.MIN_PIXELS, OutfitPreview.MIN_PIXELS)
	transparent_bg = false
	gui_disable_input = true
	handle_input_locally = false
	audio_listener_enable_3d = false
	physics_object_picking = false
	# No shadows anywhere: skip the positional shadow atlas every viewport would otherwise allocate.
	positional_shadow_atlas_size = 0
	msaa_3d = Viewport.MSAA_DISABLED if DeviceProfile.is_low_end() else Viewport.MSAA_2X
	render_target_update_mode = SubViewport.UPDATE_DISABLED
	_build_stage()
	set_physics_process(false)


## Dresses the runner in `id` (an id from data/shop/catalog.json, or PlayerOutfits.ECHO; any other id is Echo's own look).
## The first call builds the avatar for the outfit, so nothing is built twice.
func dress(id: StringName) -> void:
	id = PlayerOutfits.resolve(id)
	if avatar == null:
		# PlayerAvatar dresses itself from PlayerOutfits.worn when it is built.
		var worn: StringName = PlayerOutfits.worn
		PlayerOutfits.worn = id
		avatar = PlayerAvatar.new()
		PlayerOutfits.worn = worn
		avatar.process_mode = Node.PROCESS_MODE_DISABLED
		_pivot.add_child(avatar)
	else:
		avatar.set_outfit(id)
	pose_still()


## The outfit worn (PlayerOutfits.ECHO before `dress`).
func outfit() -> StringName:
	return avatar.outfit() if avatar != null else PlayerOutfits.ECHO


func is_live() -> bool:
	return _live


## Runs in place and turns, the stage drawn every frame (on); or stands in the still's pose, held (off).
func set_live(on: bool) -> void:
	if on == _live or avatar == null:
		return
	_live = on
	set_physics_process(on)
	if on:
		avatar.process_mode = Node.PROCESS_MODE_INHERIT
		render_target_update_mode = SubViewport.UPDATE_ALWAYS
	else:
		avatar.process_mode = Node.PROCESS_MODE_DISABLED
		pose_still()
		render_target_update_mode = SubViewport.UPDATE_DISABLED


## True while the stage is drawn every frame.
func is_drawing() -> bool:
	return render_target_update_mode == SubViewport.UPDATE_ALWAYS


## The still's pose: the run at STILL_PHASE, turned three-quarters.
func pose_still() -> void:
	if avatar == null:
		return
	_turn = 0.0
	_pivot.rotation.y = STILL_YAW
	var tuning: HumanoidAnimTuning = avatar.anim_tuning
	_distance = STILL_PHASE * maxf(tuning.stride_length, RUN_SPEED / tuning.max_cadence)
	avatar.reset()
	# The first step snaps to the pose; a few short ones let the rig's blends settle into the run.
	for i: int in 3:
		avatar.animate(_run_state(_distance), 1.0 / 30.0)


## Draws the stage once, at the next frame (it then holds that picture): the still, or the live stage's frame.
func draw_once() -> void:
	if not _live:
		render_target_update_mode = SubViewport.UPDATE_ONCE


## Draw calls one frame of the stage costs: the runner (no power-ups) and the scenery.
func draw_call_count() -> int:
	return (avatar.draw_call_count() if avatar != null else 0) + SCENERY_DRAW_CALLS


func _physics_process(delta: float) -> void:
	_turn += TURN_SPEED * delta
	_distance += RUN_SPEED * delta
	_pivot.rotation.y = STILL_YAW + _turn
	avatar.animate(_run_state(_distance), delta)


func _run_state(distance: float) -> Dictionary:
	return {"surface": "floor", "grounded": true, "vh": 0.0, "sliding": false, "distance": distance,
		"speed": RUN_SPEED, "wall_side": 1, "switch_dir": 0, "alive": true, "dashing": false, "just_landed": false}


func _build_stage() -> void:
	_pivot = Node3D.new()
	_pivot.name = "Turntable"
	add_child(_pivot)
	_pivot.rotation.y = STILL_YAW
	var camera := Camera3D.new()
	camera.name = "Camera"
	camera.fov = CAMERA_FOV
	camera.transform = Transform3D(Basis.looking_at(CAMERA_TARGET - CAMERA_POSITION, Vector3.UP), CAMERA_POSITION)
	add_child(camera)
	var key := DirectionalLight3D.new()
	key.name = "Key"
	key.light_color = KEY_LIGHT
	key.light_energy = KEY_ENERGY
	key.rotation_degrees = KEY_ROTATION
	add_child(key)
	var back := DirectionalLight3D.new()
	back.name = "Back"
	back.light_color = BACK_LIGHT
	back.light_energy = BACK_ENERGY
	back.rotation_degrees = BACK_ROTATION
	add_child(back)
	add_child(_make_pedestal())
	add_child(_make_backdrop())


## A low dark disc under the feet with a thin azure ring round it: where the runner stands.
func _make_pedestal() -> Node3D:
	var root := Node3D.new()
	root.name = "Pedestal"
	var disc := CylinderMesh.new()
	disc.top_radius = PEDESTAL_RADIUS
	disc.bottom_radius = PEDESTAL_RADIUS
	disc.height = 0.02
	disc.radial_segments = 28
	disc.rings = 1
	var disc_node := _scenery(disc, Color(0.06, 0.1, 0.19))
	disc_node.position = Vector3(0.0, -0.01, 0.0)
	root.add_child(disc_node)
	var ring := TorusMesh.new()
	ring.inner_radius = PEDESTAL_RADIUS - 0.012
	ring.outer_radius = PEDESTAL_RADIUS + 0.012
	ring.rings = 28
	ring.ring_segments = 4
	root.add_child(_scenery(ring, PEDESTAL.darkened(0.15)))
	return root


## A plane behind the runner with a radial gradient: lit from the middle, dark at the edges, unshaded so it shows the
## same on every renderer.
func _make_backdrop() -> MeshInstance3D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 1.0])
	gradient.colors = PackedColorArray([BACKDROP_CENTER, BACKDROP_EDGE])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.45)
	texture.fill_to = Vector2(0.5, 0.0)
	texture.width = 64
	texture.height = 64
	var plane := QuadMesh.new()
	plane.size = Vector2(BACKDROP_SIZE, BACKDROP_SIZE)
	var node := _scenery(plane, Color.WHITE, texture)
	node.name = "Backdrop"
	node.position = Vector3(0.0, CAMERA_TARGET.y, BACKDROP_DEPTH)
	return node


## An unshaded, shadowless mesh in a flat colour (or a texture) for the stage's scenery.
func _scenery(mesh: Mesh, color: Color, texture: Texture2D = null) -> MeshInstance3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = color
	material.albedo_texture = texture
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


static func _stage_environment() -> Environment:
	if _environment == null:
		var env := Environment.new()
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color.BLACK
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = AMBIENT
		env.ambient_light_energy = AMBIENT_ENERGY
		env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
		env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		env.glow_enabled = true
		env.glow_intensity = 0.6
		env.glow_bloom = 0.05
		env.glow_hdr_threshold = 0.9
		_environment = env
	return _environment
