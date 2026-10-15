class_name GoldenConvergenceMagnate
extends BossPart
## The Magnate (GDD §10, Second stage: "the man pulls himself out of its wreckage, screeching an animal roar of
## rage. He's a twisted abomination, burnt blackish grey by the suit's destruction, two to three times the
## runner's size"; "fast and feral", he "hunts the runner from behind on all fours"), the fight's body in stage 2:
## he shares the fight's health (weapons chip him while his phases' patterns run; untargetable before his
## transition, BossPart's rules after) and carries everything of his that can touch the runner, each switched by
## the stage's attacks (GoldenConvergencePounce, GoldenConvergenceLash) and never live otherwise:
## - the Pounce's crash: an enemy attack box over its square (set_crash);
## - the Cable Lash's cables: enemy attack boxes across the track at their heights (set_lash_band);
## - the Claw Slash's swipe: an enemy attack box over its claw marks (set_slash; E5d-e);
## - stunned in a gate's rubble, a weak point over his back in each of his two lanes (set_weak_box: generous
##   stomp boxes, BossPart.add_weak_point, the framework's stomp) and his solid but safe sides (set_blocker: a
##   lane blocker, LAYER_LANE_BLOCKER, no hurt: a lane switch into him bumps).
## His body itself never touches the runner: no hitbox of its own.
## His look (GoldenConvergenceMagnateModel's meshes on a rig, his body shader and his cables'): the encounter's
## parts place his root (set_pose: the ground under his middle, facing -z) and pick what he does (`anim`: run,
## stand, crouch, leap, roar, rear, whip, slump, collapse, claw, stagger (also his pain when a screen hits him),
## hurl, slash (E5d-e: reared, a front claw raised and swept down), hidden); his legs find the
## ground (a two-bone reach for each, `_ik`) at a gallop or standing, his spine flexes, his jaw drops to roar,
## his tatters sway and trail smoke (grey, never glowing), his cables droop and trail behind him (tear_cable
## throws one off, his defeat's), and the red ports on his spine glow (ports_glow; they pulse, steady with Reduced
## flashing). Behind the runner he shows by his shadow on the floor of his lane (set_shadow) and the marker at
## the screen's bottom edge (marker: GoldenConvergenceMagnateMarker, red for a Pounce's warning), and he breathes
## and growls where he is (breathe()). crack_glow (0-1) is the warm white in his cracks; `shudder` his
## convulsions. draw_stats() counts what he draws.

## A hitbox moved out of play.
const AWAY := Vector3(0.0, -300.0, 0.0)
## The lane blocker's height (over a jump, over his slumped body).
const BLOCKER_HEIGHT: float = 3.4
## How fast his joints follow what he's doing (1/s).
const BLEND_RATE: float = 16.0
## The ports' glow: dim while he hunts, bright and pulsing while stunned (steady with Reduced flashing).
const PORT_DIM: float = 1.6
const PORT_BRIGHT: float = 4.2
## His shadow's darkness on the marble, and on the Compatibility renderer (which blends in sRGB space: the
## same alpha comes out much darker there).
const SHADOW_ALPHA: float = 0.62
const SHADOW_ALPHA_COMPAT: float = 0.36
## The gallop's stride as his feet sweep under him (metres) and its rate per metre run.
const STRIDE: float = 1.25
const STRIDES_PER_METRE: float = 0.14

var tuning: GoldenConvergenceTuning
## What he's doing (see the header), and seconds into it.
var anim: StringName = &"hidden"
var anim_time: float = 0.0
## His world speed along the track (m/s; the gallop's rate) and his vertical speed (a leap's pitch).
var speed: float = 0.0
var rise: float = 0.0
## The jaw's opening (0-1) over what his anim gives; the head's turn (radians, + to his left).
var jaw_open: float = 0.0
var head_turn: float = 0.0
## The light in his cracks (times the tuning's crack_glow: 1 his own, up to 3 burning from the burst), his
## convulsions (0-1), the ports' glow (0-1).
var crack_light: float = 1.0
var shudder: float = 0.0
var ports_glow: float = 0.0
## 0 alive to 1 dead: the ports' red going out with the light in his cracks (his defeat).
var ports_dead: float = 0.0
## Cables still on his back (tear_cable throws one off).
var cables_on: int = 0
var marker: GoldenConvergenceMagnateMarker
## What of his touched the runner (the crash, a cable): {kind, band, outcome, runner, lane, h, sliding}.
var touches: Array[Dictionary] = []

var _root: Node3D
var _body: Node3D
var _chest: Node3D
var _hips: Node3D
var _neck: Node3D
var _jaw: Node3D
## Legs: {top: Node3D, knee: Node3D, front: bool, side: int, phase: float}
var _legs: Array[Dictionary] = []
var _body_material: ShaderMaterial
var _port_material: StandardMaterial3D
## Cables: {node, mesh, material, on, velocity, spin, age}
var _cables: Array[Dictionary] = []
var _smoke: CPUParticles3D
var _shadow: MeshInstance3D
var _shadow_material: StandardMaterial3D
var _shadow_alpha: float = SHADOW_ALPHA
var _canvas: CanvasLayer
var _voice: AudioStreamPlayer3D
var _crash_rig: Node3D
var _crash: Hazard
var _lash_rig: Node3D
var _lash: Array[Hazard] = []
var _slash_rig: Node3D
var _slash: Hazard
var _stun_rig: Node3D
var _weak: Array[Hazard] = []
var _blocker: Area3D
var _blocker_shape: BoxShape3D
var _gait: float = 0.0
var _time: float = 0.0
## The joints' angles now (`_now`, blended toward each frame's target, `_goal`): two poses made once and reused
## every drawn frame (E5d polish: no Dictionary or formatted key a frame). `_posed`: `_now` has had a goal.
var _now := JointPose.new()
var _goal := JointPose.new()
var _posed: bool = false


## A pose of his rig's joints: the body's height and turn, the spine's flex, the neck's nod and turn, the jaw, the
## legs' splay, and each leg's two angles (upper about its top, lower about its knee; legs 0-1 the front, 2-3 the
## hind, left first).
class JointPose:
	extends RefCounted
	var body_y: float = 0.0
	var body_rot: Vector3 = Vector3.ZERO
	var chest: float = 0.0
	var hips: float = 0.0
	var neck: float = 0.0
	var neck_turn: float = 0.0
	var jaw: float = 0.0
	var splay: float = 0.0
	var legs: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
	## The legs a goal has set this frame (bits); the others stand.
	var legs_set: int = 0

	## Back to a neutral goal: everything at rest, no leg set.
	func reset() -> void:
		body_y = 0.0
		body_rot = Vector3.ZERO
		chest = 0.0
		hips = 0.0
		neck = 0.0
		neck_turn = 0.0
		jaw = 0.0
		splay = 0.0
		legs_set = 0

	func set_leg(i: int, angles: Vector2) -> void:
		legs[i] = angles
		legs_set |= 1 << i

	## Takes `other`'s joints at once (the first frame he's shown).
	func copy(other: JointPose) -> void:
		body_y = other.body_y
		body_rot = other.body_rot
		chest = other.chest
		hips = other.hips
		neck = other.neck
		neck_turn = other.neck_turn
		jaw = other.jaw
		splay = other.splay
		for i: int in legs.size():
			legs[i] = other.legs[i]

	## Eases every joint `k` of the way toward `goal`'s.
	func ease_to(goal: JointPose, k: float) -> void:
		body_y = lerpf(body_y, goal.body_y, k)
		body_rot = body_rot.lerp(goal.body_rot, k)
		chest = lerpf(chest, goal.chest, k)
		hips = lerpf(hips, goal.hips, k)
		neck = lerpf(neck, goal.neck, k)
		neck_turn = lerpf(neck_turn, goal.neck_turn, k)
		jaw = lerpf(jaw, goal.jaw, k)
		splay = lerpf(splay, goal.splay, k)
		for i: int in legs.size():
			legs[i] = legs[i].lerp(goal.legs[i], k)


func _build() -> void:
	var params: Dictionary = spawn.get("params", {})
	tuning = params.get("tuning") as GoldenConvergenceTuning
	if tuning == null:
		tuning = GoldenConvergenceTuning.new()
	display_name = "The Magnate"
	# Untargetable until his transition (the encounter lets weapons at him once he's out of the suit).
	immune_to_weapons = true
	_build_rig()
	_build_hitboxes()
	_build_shadow()
	_canvas = CanvasLayer.new()
	_canvas.name = "MagnateMarkerLayer"
	# Under the HUD (layer 5), as the Enforcer Truck's marker.
	_canvas.layer = 4
	add_child(_canvas)
	marker = GoldenConvergenceMagnateMarker.new()
	_canvas.add_child(marker)
	_voice = AudioStreamPlayer3D.new()
	_voice.name = "Voice"
	if AudioServer.get_bus_index(SfxLibrary.BUS) >= 0:
		_voice.bus = SfxLibrary.BUS
	if world.sfx_library != null:
		_voice.unit_size = world.sfx_library.warning_full_volume_distance
		_voice.max_distance = world.sfx_library.warning_max_distance
	add_child(_voice)
	hide_all()


func _build_rig() -> void:
	var m: Dictionary = GoldenConvergenceMagnateModel.meshes()
	_body_material = GoldenConvergenceMagnateModel.body_material()
	_body_material.set_shader_parameter(&"crack_glow", tuning.crack_glow)
	_port_material = GoldenConvergenceMagnateModel.port_material()
	_root = Node3D.new()
	_root.name = "Magnate"
	_root.scale = Vector3.ONE * tuning.magnate_scale
	add_child(_root)
	_body = Node3D.new()
	_body.name = "Body"
	_root.add_child(_body)
	_chest = _joint(_body, "Chest", GoldenConvergenceMagnateModel.CHEST_PIVOT)
	_hips = _joint(_body, "Hips", GoldenConvergenceMagnateModel.HIPS_PIVOT)
	_part(_chest, m["chest"], "Ribs")
	_part(_hips, m["hips"], "Haunches")
	_neck = _joint(_chest, "Neck", GoldenConvergenceMagnateModel.NECK_AT)
	_part(_neck, m["head"], "Head")
	_jaw = _joint(_neck, "Jaw", GoldenConvergenceMagnateModel.JAW_AT)
	_part(_jaw, m["jaw"], "LowerJaw")
	var tatters: MeshInstance3D = _part(_chest, m["tatters"], "Tatters")
	tatters.extra_cull_margin = 1.0
	var ports_chest: MeshInstance3D = MeshBatch.add_instance(_chest, m["ports_chest"], "Ports")
	ports_chest.material_override = _port_material
	var ports_hips: MeshInstance3D = MeshBatch.add_instance(_hips, m["ports_hips"], "Ports")
	ports_hips.material_override = _port_material
	var f: Vector3 = GoldenConvergenceMagnateModel.FRONT_LEG
	var h: Vector3 = GoldenConvergenceMagnateModel.HIND_LEG
	for side: int in [-1, 1]:
		_legs.append(_leg(_chest, Vector3(side * f.x, f.y, f.z), m["upper_front"], m["lower_front"],
			GoldenConvergenceMagnateModel.UPPER_FRONT, true, side, 0.0 if side < 0 else 0.12))
	for side: int in [-1, 1]:
		_legs.append(_leg(_hips, Vector3(side * h.x, h.y, h.z), m["upper_hind"], m["lower_hind"],
			GoldenConvergenceMagnateModel.UPPER_HIND, false, side, 0.5 if side < 0 else 0.62))
	var sockets: Array[Vector3] = GoldenConvergenceMagnateModel.CABLE_SOCKETS
	for i: int in sockets.size():
		var node := Node3D.new()
		node.name = "Cable%d" % i
		node.position = sockets[i]
		# Trailing back and a little out to its side.
		node.rotation = Vector3(0.0, signf(sockets[i].x) * 0.18, 0.0)
		_chest.add_child(node)
		var mat: ShaderMaterial = GoldenConvergenceMagnateModel.cable_material(float(i) * 1.37)
		var mesh: MeshInstance3D = MeshBatch.add_instance(node, m["cable"], "Wire")
		mesh.material_override = mat
		# The shader droops and sways it well outside its straight rest shape.
		mesh.extra_cull_margin = 3.0
		_cables.append({"node": node, "mesh": mesh, "material": mat, "on": true, "velocity": Vector3.ZERO,
			"spin": Vector3.ZERO, "age": 0.0, "socket": sockets[i]})
	cables_on = _cables.size()
	_smoke = CPUParticles3D.new()
	_smoke.name = "Smoke"
	_smoke.amount = 16
	_smoke.lifetime = 1.1
	_smoke.local_coords = false
	_smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_smoke.emission_box_extents = Vector3(0.45, 0.15, 0.4)
	_smoke.direction = Vector3(0.0, 1.0, 0.4)
	_smoke.spread = 25.0
	_smoke.initial_velocity_min = 0.4
	_smoke.initial_velocity_max = 1.0
	_smoke.gravity = Vector3(0.0, 0.6, 0.0)
	_smoke.scale_amount_min = 0.5
	_smoke.scale_amount_max = 1.0
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.4))
	curve.add_point(Vector2(1.0, 1.6))
	_smoke.scale_amount_curve = curve
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.22, 0.2, 0.19, 0.5))
	ramp.set_color(1, Color(0.3, 0.28, 0.27, 0.0))
	_smoke.color_ramp = ramp
	var quad := QuadMesh.new()
	quad.size = Vector2(0.55, 0.55)
	var smoke_mat := StandardMaterial3D.new()
	smoke_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke_mat.vertex_color_use_as_albedo = true
	smoke_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	smoke_mat.albedo_texture = _soft_texture()
	quad.material = smoke_mat
	_smoke.mesh = quad
	_smoke.position = Vector3(0.0, 0.2, 0.3)
	_chest.add_child(_smoke)


func _joint(parent: Node3D, node_name: String, at: Vector3) -> Node3D:
	var node := Node3D.new()
	node.name = node_name
	node.position = at
	parent.add_child(node)
	return node


func _part(parent: Node3D, mesh: Mesh, node_name: String) -> MeshInstance3D:
	var inst: MeshInstance3D = MeshBatch.add_instance(parent, mesh, node_name)
	inst.material_override = _body_material
	return inst


func _leg(parent: Node3D, at: Vector3, upper: Mesh, lower: Mesh, upper_length: float, front: bool, side: int,
		phase: float) -> Dictionary:
	var top: Node3D = _joint(parent, "Leg%s%s" % ["F" if front else "H", "L" if side < 0 else "R"], at)
	_part(top, upper, "Upper")
	var knee: Node3D = _joint(top, "Knee", Vector3(0.0, -upper_length, 0.0))
	_part(knee, lower, "Lower")
	return {"top": top, "knee": knee, "front": front, "side": side, "phase": phase}


## His hitboxes, each on a node of its own placed in world space (top_level), off until an attack sets it.
func _build_hitboxes() -> void:
	_crash_rig = _rig("Crash")
	_crash = add_hitbox(&"attack", Vector3.ONE, Vector3.ZERO, true, _crash_rig)
	_crash.hazard_name = "The Magnate's pounce"
	_crash.contacted.connect(_on_contacted.bind(&"crash", 0))
	_lash_rig = _rig("Lash")
	for i: int in 2:
		var band: Hazard = add_hitbox(&"attack", Vector3.ONE, Vector3.ZERO, true, _lash_rig)
		band.hazard_name = "The Magnate's cable"
		band.contacted.connect(_on_contacted.bind(&"lash", i))
		_lash.append(band)
	_slash_rig = _rig("Slash")
	_slash = add_hitbox(&"attack", Vector3.ONE, Vector3.ZERO, true, _slash_rig)
	_slash.hazard_name = "The Magnate's claws"
	_slash.contacted.connect(_on_contacted.bind(&"slash", 0))
	_stun_rig = _rig("Stun")
	for i: int in 2:
		var weak: Hazard = add_weak_point(Vector3.ONE, Vector3.ZERO, _stun_rig)
		weak.hazard_name = "The Magnate's spine"
		_weak.append(weak)
	set_weak_points_enabled(false)
	# His solid but safe sides while stunned: a lane blocker of its own (no hurt), outside the hitboxes a defeat
	# switches off, so the encounter decides when it goes.
	_blocker = Area3D.new()
	_blocker.name = "Sides"
	_blocker.collision_layer = 0
	_blocker.collision_mask = 0
	_blocker.monitoring = false
	_blocker.top_level = true
	add_child(_blocker)
	var shape := CollisionShape3D.new()
	_blocker_shape = BoxShape3D.new()
	shape.shape = _blocker_shape
	_blocker.add_child(shape)
	set_crash(false)
	set_slash(false)
	for i: int in 2:
		set_lash_band(i, false)
		set_weak_box(i, false)
	set_blocker(false)


func _rig(node_name: String) -> Node3D:
	var node := Node3D.new()
	node.name = node_name
	node.top_level = true
	add_child(node)
	node.global_position = AWAY
	return node


func _build_shadow() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	_shadow_material = StandardMaterial3D.new()
	_shadow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_shadow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var compat: bool = RenderingServer.get_current_rendering_method() == "gl_compatibility"
	_shadow_alpha = SHADOW_ALPHA_COMPAT if compat else SHADOW_ALPHA
	_shadow_material.albedo_color = Color(0.02, 0.018, 0.016, _shadow_alpha)
	_shadow_material.albedo_texture = _shadow_texture()
	_shadow_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	plane.material = _shadow_material
	_shadow = MeshInstance3D.new()
	_shadow.name = "Shadow"
	_shadow.mesh = plane
	_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shadow.top_level = true
	add_child(_shadow)


## His shadow's blob: solid most of the way out (it has to read on the court's bright marble), its edge soft.
static func _shadow_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.7, 1.0])
	g.colors = PackedColorArray([Color(1.0, 1.0, 1.0, 1.0), Color(1.0, 1.0, 1.0, 0.95), Color(1.0, 1.0, 1.0, 0.0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 64
	t.height = 64
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	return t


## A soft round blob (white, its alpha fading to the edge): the smoke's puffs.
static func _soft_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	g.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	g.add_point(0.55, Color(1.0, 1.0, 1.0, 0.75))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 64
	t.height = 64
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	return t


# --- Where he is, what he does ---------------------------------------------------------------------------

## Places his root (the ground under his middle; his front -z) in world space, and shows him.
func set_pose(xform: Transform3D) -> void:
	global_transform = xform
	_root.visible = true


## Starts `next` (see the header) unless he's doing it already.
func play(next: StringName) -> void:
	if anim != next:
		anim = next
		anim_time = 0.0
	_root.visible = anim != &"hidden"


## Hidden, his hitboxes, shadow and marker off (before the transition, a test's reset).
func hide_all() -> void:
	play(&"hidden")
	_root.visible = false
	_shadow.visible = false
	marker.shown = 0.0
	set_crash(false)
	set_slash(false)
	for i: int in 2:
		set_lash_band(i, false)
		set_weak_box(i, false)
	set_blocker(false)


## True while his model shows.
func shown() -> bool:
	return _root.visible


## Where weapons aim: his chest.
func aim_point() -> Vector3:
	return _chest.global_position if _chest != null else global_position + Vector3(0.0, 1.2, 0.0)


func hit_radius() -> float:
	return 1.4 * tuning.magnate_scale


## Where his head and his back are (world space: sounds, effects, the cables' sockets).
func head_point() -> Vector3:
	return _neck.global_transform * Vector3(0.0, 0.12, -0.6)


func back_point() -> Vector3:
	return _chest.global_transform * Vector3(0.0, 0.6, -0.1)


## Socket `i`'s point on his back (world space).
func socket_point(i: int) -> Vector3:
	return _chest.global_transform * GoldenConvergenceMagnateModel.CABLE_SOCKETS[i % GoldenConvergenceMagnateModel.CABLE_SOCKETS.size()]


## His body's box in world space (his meshes but the cables and tatters): what a runner could run into.
func body_aabb() -> AABB:
	var out := AABB()
	var first: bool = true
	for node: Node in _root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.name == "Wire" or mi.name == "Tatters" or not mi.is_visible_in_tree():
			continue
		var box: AABB = mi.global_transform * mi.get_aabb()
		out = box if first else out.merge(box)
		first = false
	return out


# --- His hitboxes ------------------------------------------------------------------------------------

## The Pounce's crash: an enemy attack box at `center` (world) of `size`, or off.
func set_crash(on: bool, center: Vector3 = Vector3.ZERO, size: Vector3 = Vector3.ONE) -> void:
	_set_box(_crash, _crash_rig, on, center, size)


## The Claw Slash's swipe (E5d-e): an enemy attack box at `center` (world) of `size`, or off.
func set_slash(on: bool, center: Vector3 = Vector3.ZERO, size: Vector3 = Vector3.ONE) -> void:
	_set_box(_slash, _slash_rig, on, center, size)


func slash_box() -> Hazard:
	return _slash


## Cable `i` of a Lash (0 the lower, 1 the upper): an enemy attack box at `center` (world) of `size`, or off.
func set_lash_band(i: int, on: bool, center: Vector3 = Vector3.ZERO, size: Vector3 = Vector3.ONE) -> void:
	var box: Hazard = _lash[i]
	box.set_enabled(on)
	if on:
		_resize(box, size)
		box.global_position = center
	else:
		box.global_position = AWAY


## Weak point `i` (a stomp box over his back in one of his two lanes) at `center` (world) of `size`, or off.
func set_weak_box(i: int, on: bool, center: Vector3 = Vector3.ZERO, size: Vector3 = Vector3.ONE) -> void:
	var box: Hazard = _weak[i]
	box.set_enabled(on)
	if on:
		_resize(box, size)
		box.global_position = center
	else:
		box.global_position = AWAY


## His solid but safe sides (a lane blocker: a switch into him bumps) at `center` (world) of `size`, or off.
func set_blocker(on: bool, center: Vector3 = Vector3.ZERO, size: Vector3 = Vector3.ONE) -> void:
	_blocker.collision_layer = TrackBuilder.LAYER_LANE_BLOCKER if on else 0
	if on:
		_blocker_shape.size = size
		_blocker.global_position = center
	else:
		_blocker.global_position = AWAY


## True while his sides block (tests).
func blocking() -> bool:
	return _blocker.collision_layer != 0


## The crash's box, the Lash's cables, the weak points (tests: what's live, where).
func crash_box() -> Hazard:
	return _crash


func lash_boxes() -> Array[Hazard]:
	return _lash


func weak_boxes() -> Array[Hazard]:
	return _weak


func _set_box(box: Hazard, rig: Node3D, on: bool, center: Vector3, size: Vector3) -> void:
	box.set_enabled(on)
	if on:
		_resize(box, size)
		rig.global_position = center
	else:
		rig.global_position = AWAY


static func _resize(hazard: Hazard, size: Vector3) -> void:
	hazard.size = size
	var shape := hazard.get_child(0) as CollisionShape3D
	if shape != null and shape.shape is BoxShape3D:
		(shape.shape as BoxShape3D).size = size


func _on_contacted(outcome: int, kind: StringName, index: int) -> void:
	if outcome == DamageRules.Outcome.IGNORE:
		return
	touches.append({"kind": kind, "band": index, "outcome": outcome, "runner": world.player.distance,
		"lane": world.player.lane, "h": world.player.h, "sliding": world.player.is_sliding()})
	if encounter != null and is_instance_valid(encounter):
		encounter.log_event(&"magnate_hit", {"kind": kind, "band": index, "outcome": outcome,
			"lane": world.player.lane, "runner": world.player.distance})


# --- Shadow, marker, voice ----------------------------------------------------------------------------

## His shadow on the floor: a soft dark blob centred at world (x, z) `at`, `length` along the track and
## `width` across, its darkness `alpha` (0: none).
func set_shadow(at: Vector3, length: float, width: float, alpha: float) -> void:
	_shadow.visible = alpha > 0.01
	if not _shadow.visible:
		return
	_shadow.global_transform = Transform3D(Basis.from_scale(Vector3(width, 1.0, length)), Vector3(at.x, 0.025, at.z))
	_shadow_material.albedo_color = Color(0.02, 0.018, 0.016, _shadow_alpha * clampf(alpha, 0.0, 1.0))


## Where his shadow lies (tests): its middle and size, or null while there's none.
func shadow_box() -> Variant:
	if not _shadow.visible:
		return null
	var b: Basis = _shadow.global_transform.basis
	return AABB(_shadow.global_position - Vector3(b.x.length(), 0.0, b.z.length()) * 0.5,
		Vector3(b.x.length(), 0.05, b.z.length()))


## The marker under his lane: `x` his world x, `shown` 0-1, `alarm` 0-1 (red: a Pounce's warning).
func set_marker(x: float, show_amount: float, alarm_amount: float) -> void:
	marker.lane_x = x
	marker.runner_z = world.player.position.z
	marker.shown = clampf(show_amount, 0.0, 1.0)
	marker.alarm = clampf(alarm_amount, 0.0, 1.0)


## A breath or a growl where he is (cosmetic: not logged, only heard in a real game).
func breathe(sound: StringName) -> void:
	if not SfxLibrary.audible() or world.sfx_library == null:
		return
	var stream: AudioStream = world.sfx_library.stream(sound)
	if stream == null:
		return
	_voice.stream = stream
	_voice.volume_db = world.sfx_library.volume(sound)
	_voice.play()


# --- The cables -------------------------------------------------------------------------------------

## Cable `i` tears out of his back (his defeat): it's flung off, spinning, and falls away. False if it was
## already gone.
func tear_cable(i: int) -> bool:
	if i < 0 or i >= _cables.size() or not bool(_cables[i]["on"]):
		return false
	var c: Dictionary = _cables[i]
	var node: Node3D = c["node"]
	var xform: Transform3D = node.global_transform
	node.top_level = true
	node.global_transform = xform
	c["on"] = false
	c["age"] = 0.0
	var out: Vector3 = (xform.origin - _chest.global_position)
	out.y = 0.0
	out = out.normalized() if out.length_squared() > 0.001 else Vector3.RIGHT
	c["velocity"] = out * 4.0 + Vector3(0.0, 5.5, 2.0)
	c["spin"] = Vector3(rng.randf_range(-6.0, 6.0), rng.randf_range(-4.0, 4.0), rng.randf_range(-6.0, 6.0))
	cables_on -= 1
	return true


## Every cable back on his back (a fresh fight; a showcase's loop).
func restore_cables() -> void:
	for c: Dictionary in _cables:
		var node: Node3D = c["node"]
		node.top_level = false
		node.position = c["socket"]
		node.rotation = Vector3(0.0, signf((c["socket"] as Vector3).x) * 0.18, 0.0)
		node.visible = true
		c["on"] = true
	cables_on = _cables.size()


func cable_count() -> int:
	return _cables.size()


# --- Every frame -------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	# His look follows what he's doing every drawn frame (also while the fight holds for a death).
	_time += delta
	anim_time += delta
	if not _root.visible:
		return
	_animate(delta)
	_body_material.set_shader_parameter(&"crack_glow", tuning.crack_glow * clampf(crack_light, 0.0, 3.0))
	_body_material.set_shader_parameter(&"shudder", clampf(shudder, 0.0, 1.0))
	var steady: bool = Settings.flashing_reduced
	var pulse: float = 1.0 if steady else 0.85 + 0.15 * sin(_time * 7.0)
	var life: float = 1.0 - clampf(ports_dead, 0.0, 1.0)
	_port_material.emission_energy_multiplier = lerpf(PORT_DIM, PORT_BRIGHT, clampf(ports_glow, 0.0, 1.0)) * pulse * life
	_port_material.albedo_color = GoldenConvergenceMagnateModel.PORT_DEAD.lerp(GoldenConvergenceMagnateModel.PORT_RED,
		life)
	# The sockets' height over the ground (his back's, as he crouches, leaps or slumps).
	var ground: float = maxf(_chest.global_position.y - global_position.y + 0.6 * tuning.magnate_scale, 0.2)
	for c: Dictionary in _cables:
		var mat: ShaderMaterial = c["material"]
		if bool(c["on"]):
			mat.set_shader_parameter(&"ground", ground / maxf(tuning.magnate_scale, 0.1))
			mat.set_shader_parameter(&"trail", clampf(absf(rise) / 6.0, 0.0, 1.0) if anim == &"leap" or anim == &"hurl" else 0.0)
		else:
			_fly_cable(c, delta)
	_smoke.emitting = anim != &"collapse" or anim_time < 0.5


func _fly_cable(c: Dictionary, delta: float) -> void:
	var node: Node3D = c["node"]
	if not node.visible:
		return
	c["age"] = float(c["age"]) + delta
	var v: Vector3 = c["velocity"]
	v.y -= 14.0 * delta
	c["velocity"] = v
	node.global_position += v * delta
	var spin: Vector3 = c["spin"]
	node.rotation += spin * delta
	(c["material"] as ShaderMaterial).set_shader_parameter(&"ground", 0.0)
	if float(c["age"]) > 1.4:
		node.visible = false


## His pose this frame: each joint toward what `anim` wants (blended), his legs reaching the ground.
func _animate(delta: float) -> void:
	_gait = fmod(_gait + delta * clampf(absf(speed) * STRIDES_PER_METRE, 1.2, 3.6), 1.0)
	_target_pose()
	if _posed:
		_now.ease_to(_goal, 1.0 - exp(-BLEND_RATE * delta))
	else:
		_now.copy(_goal)
		_posed = true
	_body.position = Vector3(0.0, _now.body_y, 0.0)
	_body.rotation = _now.body_rot
	_chest.rotation = Vector3(_now.chest, 0.0, 0.0)
	_hips.rotation = Vector3(_now.hips, 0.0, 0.0)
	_neck.rotation = Vector3(_now.neck, _now.neck_turn + head_turn, 0.0)
	_jaw.rotation = Vector3(-maxf(_now.jaw, jaw_open) * 0.85, 0.0, 0.0)
	for i: int in _legs.size():
		var leg: Dictionary = _legs[i]
		var a: Vector2 = _now.legs[i]
		(leg["top"] as Node3D).rotation = Vector3(a.x, 0.0, _now.splay * float(leg["side"]))
		(leg["knee"] as Node3D).rotation = Vector3(a.y, 0.0, 0.0)
	_body_material.set_shader_parameter(&"sway", clampf(0.6 + absf(speed) * 0.03, 0.5, 1.4))


## Sets `_goal` to the joints' targets for what he's doing now (any leg it leaves stands).
func _target_pose() -> void:
	var p: JointPose = _goal
	p.reset()
	var tau: float = TAU * _gait
	match anim:
		&"run", &"stagger":
			p.body_y = 0.07 * sin(tau * 2.0) - 0.04
			p.chest = 0.1 * sin(tau)
			p.hips = -0.1 * sin(tau)
			p.neck = -0.08 * sin(tau) - (0.35 if anim == &"stagger" else 0.05)
			p.body_rot = Vector3(clampf(rise * 0.03, -0.3, 0.3), 0.0, 0.0)
			if anim == &"stagger":
				p.body_rot = Vector3(-0.1, 0.0, 0.18 * sin(anim_time * 9.0))
				p.jaw = 0.5
			for i: int in _legs.size():
				p.set_leg(i, _gallop_leg(i, p.body_y))
		&"stand", &"crouch":
			var low: float = -0.32 if anim == &"crouch" else 0.0
			p.body_y = low + 0.015 * sin(_time * 2.4)
			p.neck = -0.25 if anim == &"crouch" else 0.05
			for i: int in _legs.size():
				p.set_leg(i, _stand_leg(i, low))
		&"leap", &"hurl":
			var pitch: float = clampf(-rise * 0.05, -0.5, 0.5)
			p.body_rot = Vector3(pitch, 0.0, 0.25 * sin(anim_time * 5.0) if anim == &"hurl" else 0.0)
			p.neck = 0.25 if anim == &"hurl" else 0.1
			p.jaw = 0.9 if anim == &"hurl" else 0.15
			p.chest = -0.08
			p.hips = 0.08
			p.set_leg(0, Vector2(1.15, -0.25))
			p.set_leg(1, Vector2(1.05, -0.3))
			p.set_leg(2, Vector2(-1.05, 0.35))
			p.set_leg(3, Vector2(-0.95, 0.3))
		&"roar":
			p.body_y = 0.05
			p.body_rot = Vector3(0.28, 0.0, 0.0)
			p.chest = 0.08
			p.neck = 0.55 + 0.05 * sin(anim_time * 14.0)
			p.jaw = 1.0
			p.set_leg(0, Vector2(0.55, -0.85))
			p.set_leg(1, Vector2(0.45, -0.75))
			p.set_leg(2, _stand_leg(2, 0.0))
			p.set_leg(3, _stand_leg(3, 0.0))
		&"rear":
			# Reared back on his hind legs, the cable raised behind him, his front claws up.
			p.body_y = -0.15
			p.body_rot = Vector3(0.75, 0.0, 0.0)
			p.chest = 0.15
			p.neck = -0.45
			p.jaw = 0.45
			p.set_leg(0, Vector2(1.5 + 0.1 * sin(anim_time * 8.0), -1.3))
			p.set_leg(1, Vector2(1.35 + 0.1 * sin(anim_time * 8.0 + 1.0), -1.2))
			p.set_leg(2, Vector2(0.35, -0.6))
			p.set_leg(3, Vector2(0.45, -0.7))
		&"whip":
			# The whip: lunging forward and twisting toward the track.
			p.body_y = -0.1
			p.body_rot = Vector3(-0.15, 0.45, 0.0)
			p.neck = 0.15
			p.jaw = 0.8
			for i: int in _legs.size():
				p.set_leg(i, _stand_leg(i, -0.1))
		&"slump", &"collapse":
			# Down on his belly in the rubble, legs splayed, head down; breathing hard (stunned) or still.
			var breath: float = 0.04 * sin(_time * 3.2) if anim == &"slump" else 0.0
			p.body_y = -0.62 + breath
			p.body_rot = Vector3(-0.05, 0.0, 0.22 if anim == &"slump" else 0.42)
			p.neck = -0.5 if anim == &"slump" else -0.7
			p.neck_turn = 0.35
			p.jaw = 0.3 if anim == &"slump" else 0.45
			p.splay = 0.55
			p.set_leg(0, Vector2(1.25, -0.35))
			p.set_leg(1, Vector2(1.2, -0.3))
			p.set_leg(2, Vector2(-1.25, 0.25))
			p.set_leg(3, Vector2(-1.2, 0.2))
		&"slash":
			# The Claw Slash (E5d-e): reared up, his right claw raised high, then swept down and across the lane
			# as it lands (GoldenConvergenceSlash.SWIPE_LEAD before the hit), his jaw wide.
			var k: float = clampf((anim_time - 0.15) / 0.14, 0.0, 1.0)
			k = k * k * (3.0 - 2.0 * k)
			p.body_y = 0.1 - 0.12 * k
			p.body_rot = Vector3(0.38 - 0.4 * k, 0.12 * k, -0.08 + 0.3 * k)
			p.chest = 0.14
			p.neck = 0.4 - 0.55 * k
			p.jaw = 0.95
			p.set_leg(0, Vector2(1.25 - 0.3 * k, -0.9 + 0.3 * k))
			p.set_leg(1, Vector2(2.3 - 1.7 * k, -0.35 - 0.9 * k))
			p.set_leg(2, _stand_leg(2, -0.05))
			p.set_leg(3, _stand_leg(3, -0.05))
		&"claw":
			# Clawing his way out: head down, his front legs reaching and pulling in turn.
			p.body_rot = Vector3(-0.45, 0.0, 0.0)
			p.neck = 0.2
			p.jaw = 0.4
			p.set_leg(0, Vector2(1.5 + 0.45 * sin(anim_time * 6.0), -0.6))
			p.set_leg(1, Vector2(1.5 + 0.45 * sin(anim_time * 6.0 + PI), -0.6))
			p.set_leg(2, Vector2(0.4, -0.9))
			p.set_leg(3, Vector2(0.5, -0.9))
		_:
			for i: int in _legs.size():
				p.set_leg(i, _stand_leg(i, 0.0))
	for i: int in _legs.size():
		if (p.legs_set & (1 << i)) == 0:
			p.set_leg(i, _stand_leg(i, p.body_y))


## Leg `i` at a gallop: its foot sweeping back along the ground under him (the stance), then lifted forward
## (the swing), by its own phase.
func _gallop_leg(i: int, body_y: float) -> Vector2:
	var leg: Dictionary = _legs[i]
	var ph: float = fmod(_gait + float(leg["phase"]), 1.0)
	var top: Vector3 = _leg_top(i, body_y)
	var reach: float = STRIDE * 0.5
	var foot_z: float
	var foot_y: float = 0.0
	if ph < 0.55:
		var u: float = ph / 0.55
		foot_z = lerpf(-reach, reach, u)
	else:
		var u: float = (ph - 0.55) / 0.45
		foot_z = lerpf(reach, -reach, u)
		foot_y = 0.38 * sin(PI * u)
	var base_z: float = -0.12 if bool(leg["front"]) else 0.06
	return _ik(i, top, Vector3(0.0, foot_y, top.z + base_z + foot_z))


## Leg `i` standing, its foot under its top on the ground, with the body `low` metres down.
func _stand_leg(i: int, low: float) -> Vector2:
	var top: Vector3 = _leg_top(i, low)
	var leg: Dictionary = _legs[i]
	return _ik(i, top, Vector3(0.0, 0.0, top.z + (-0.18 if bool(leg["front"]) else 0.1)))


## Where leg `i`'s top is in his root's space with the body `body_y` up (the spine's flex aside).
func _leg_top(i: int, body_y: float) -> Vector3:
	var leg: Dictionary = _legs[i]
	var pivot: Vector3 = GoldenConvergenceMagnateModel.CHEST_PIVOT if bool(leg["front"]) else GoldenConvergenceMagnateModel.HIPS_PIVOT
	var at: Vector3 = GoldenConvergenceMagnateModel.FRONT_LEG if bool(leg["front"]) else GoldenConvergenceMagnateModel.HIND_LEG
	return Vector3(0.0, pivot.y + at.y + body_y, pivot.z + at.z)


## The two angles (upper about its top, lower about its knee; + swings forward, toward -z) that put leg `i`'s
## foot at `foot` (his root's space, y the ground's 0): a two-bone reach in the leg's plane, the front legs'
## elbows behind the line to the foot, the hind legs' knees in front of it.
func _ik(i: int, top: Vector3, foot: Vector3) -> Vector2:
	var leg: Dictionary = _legs[i]
	var front: bool = leg["front"]
	var a: float = GoldenConvergenceMagnateModel.UPPER_FRONT if front else GoldenConvergenceMagnateModel.UPPER_HIND
	var b: float = (GoldenConvergenceMagnateModel.LOWER_FRONT if front else GoldenConvergenceMagnateModel.LOWER_HIND) + 0.06
	var dz: float = foot.z - top.z
	var dy: float = foot.y - top.y
	var d: float = clampf(sqrt(dz * dz + dy * dy), absf(a - b) + 0.02, a + b - 0.01)
	# The direction to the foot as an angle from straight down (+ toward -z).
	var phi: float = atan2(-dz, -dy)
	var alpha: float = acos(clampf((a * a + d * d - b * b) / (2.0 * a * d), -1.0, 1.0))
	var upper: float = phi - alpha if front else phi + alpha
	var knee := Vector2(-sin(upper) * a, -cos(upper) * a)
	var to_foot := Vector2(dz, dy) - knee
	var lower_abs: float = atan2(-to_foot.x, -to_foot.y)
	return Vector2(upper, lower_abs - upper)


# --- Stats, defeat ------------------------------------------------------------------------------------

## What he draws: {instances, surfaces, vertices}.
func draw_stats() -> Dictionary:
	var instances: int = 0
	var surfaces: int = 0
	var vertices: int = 0
	for node: Node in _root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		instances += 1
		for s: int in mi.mesh.get_surface_count():
			surfaces += 1
			vertices += (mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	return {"instances": instances, "surfaces": surfaces, "vertices": vertices}


## His meshes (tests: the colour rule).
func meshes() -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for node: Node in _root.find_children("*", "MeshInstance3D", true, false):
		out.append(node as MeshInstance3D)
	return out


## His body's shader material (tests: the crack glow, the shudder).
func body_material() -> ShaderMaterial:
	return _body_material


func port_material() -> StandardMaterial3D:
	return _port_material


## Never a target before his transition (immune_to_weapons), BossPart's rules after.
func targetable() -> bool:
	return shown() and super.targetable()


## Beaten, he stays where the encounter's defeat lays him (GoldenConvergenceDefeat).
func _on_defeated(_cause: StringName) -> void:
	set_crash(false)
	set_slash(false)
	for i: int in 2:
		set_lash_band(i, false)
	set_weak_points_enabled(false)
