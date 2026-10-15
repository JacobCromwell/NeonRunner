class_name BeachOutroPalace
extends Node3D
## The Golden Palace in the Beach's outro (the owner, October 15, 2026: "Cut away to the Golden Palace, where we see
## the face of the Golden Convergence. It is in a dark, shadowy room with lots of screens all around. The Golden
## Convergence raises his hand and points a finger forward"). A set of its own, built once and shown only for its
## shot (BeachOutro hides the beach's street and switches its fog off meanwhile, and dims the scenery's light,
## ZoneSkin.set_scenery_light, so the gold is lit only as by the screens): a closed room of dark panelled walls whose
## walls are hung with rows of the feed's screens (the Grand Court's own feed, golden_court_feed.gdshader: the calm
## golden face and the cult's emblem, glowing in the feed's cold white and warm gold), and in its middle the Golden
## Convergence (GoldenConvergenceModel's meshes in the Golden Zone's gold: its torso, chest plates, face, halo, cape and
## trailing pipes, at the tuning's suit_scale), its right arm rising from its side to point straight ahead at the
## camera, its hand a fist with the index finger out (pointing_finger(): the model's gold). Moved by the cinematic's
## clock (update). Visual only.
## Its space: the suit's (its waist at the origin, +y up, +z its front, where the camera is).
## DESIGN-TBD (docs/questions/f2e.md): the room's look, the screens' number and the pointing hand.

const BOSS_SKIN_PATH: String = "res://data/bosses/golden_boss_skin.tres"
const FEED_SHADER: String = "res://scripts/bosses/golden_convergence/golden_court_feed.gdshader"
## The room's panels: a near-black bronze, a little lighter on the floor, and the screens' gilded frames.
const WALL := Color(0.05, 0.042, 0.035)
const FLOOR := Color(0.07, 0.058, 0.045)
## The screens' brightness (the feed's COLOR.a), their frames' width.
const SCREEN_BRIGHTNESS: float = 0.85
const FRAME: float = 0.12
## The arm at rest (as the suit hangs it: a little out and forward, the elbow bent) and its elbow's bend.
const ARM_REST_OUT: float = 0.32
const ARM_REST_FORWARD: float = 0.2
const ELBOW_REST: float = 0.35
## The halo turns this fast (rad/s), as the fight's does.
const HALO_SPIN: float = 0.12
## The head looks down a little at the camera.
const HEAD_LOOK_DOWN: float = 0.06

var tuning: BeachOutroTuning
var skin: GoldenSkin
var suit: Node3D
var head: Node3D
var halo: Node3D
var shoulder: Node3D
var elbow: Node3D
var hand: MeshInstance3D
var fist: MeshInstance3D
var cape_material: ShaderMaterial
var feed_material: ShaderMaterial
## How far its arm has come up to point (0-1).
var pointing: float = 0.0
## Where its arm points (the room's space): straight ahead at the camera's place when it points.
var point_target := Vector3(0.0, 6.0, 12.0)

static var _fingers: Dictionary = {}


func setup(p_tuning: BeachOutroTuning) -> void:
	name = "Palace"
	tuning = p_tuning
	skin = load(BOSS_SKIN_PATH) as GoldenSkin
	if skin == null:
		skin = GoldenSkin.new()
	var material: ShaderMaterial = skin.solid_material()
	feed_material = ShaderMaterial.new()
	feed_material.shader = load(FEED_SHADER) as Shader
	feed_material.set_shader_parameter(&"feed_emblem", CultFeed.emblem_texture())
	_build_room(material)
	_build_suit(material)
	visible = false
	update(0.0)


## The room: a closed box of dark panels (its walls facing in), the feed's screens in rows round three walls.
func _build_room(material: ShaderMaterial) -> void:
	var size: Vector3 = tuning.room_size
	var hx: float = size.x * 0.5
	var y0: float = -size.y * 0.3
	var y1: float = y0 + size.y
	var z0: float = -size.z * 0.62
	var z1: float = z0 + size.z
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(material)
	var f: MeshLayer = batch.layer(feed_material)
	# Floor, ceiling and walls, each facing into the room.
	s.rect(Vector3(-hx, y0, z1), Vector3(size.x, 0, 0), Vector3(0, 0, -size.z), FLOOR)
	s.rect(Vector3(-hx, y1, z0), Vector3(size.x, 0, 0), Vector3(0, 0, size.z), WALL)
	s.rect(Vector3(-hx, y0, z0), Vector3(size.x, 0, 0), Vector3(0, size.y, 0), WALL)
	s.rect(Vector3(hx, y0, z1), Vector3(-size.x, 0, 0), Vector3(0, size.y, 0), WALL)
	s.rect(Vector3(-hx, y0, z1), Vector3(0, 0, -size.z), Vector3(0, size.y, 0), WALL)
	s.rect(Vector3(hx, y0, z0), Vector3(0, 0, size.z), Vector3(0, size.y, 0), WALL)
	# Dark pilasters between the screens, a little lighter, so the walls read as walls in the screens' glow.
	var sw: Vector2 = tuning.screen_size
	var rows: int = tuning.screen_rows
	var per: int = tuning.screens_per_row
	var gap: float = 0.5
	for wall: int in 3:
		# 0 the back wall (facing +z), 1 the left (facing +x), 2 the right (facing -x).
		var face: Vector3 = Vector3(0, 0, 1) if wall == 0 else (Vector3(1, 0, 0) if wall == 1 else Vector3(-1, 0, 0))
		var across: Vector3 = Vector3(1, 0, 0) if wall == 0 else (Vector3(0, 0, -1) if wall == 1 else Vector3(0, 0, 1))
		var plane: Vector3 = Vector3(0, 0, z0) if wall == 0 else Vector3(-hx if wall == 1 else hx, 0, 0)
		var span: float = size.x if wall == 0 else size.z
		var mid: Vector3 = plane + (Vector3(0, 0, (z0 + z1) * 0.5) if wall != 0 else Vector3.ZERO)
		var row_count: int = rows
		var count: int = per
		var width: float = minf(sw.x, (span - gap) / float(count) - gap)
		var height: float = sw.y * width / sw.x
		for r: int in row_count:
			var y: float = y0 + 2.4 + float(r) * (height + 0.9) + height * 0.5
			for k: int in count:
				var off: float = (float(k) - float(count - 1) * 0.5) * (width + gap)
				var c: Vector3 = mid + across * off + Vector3(0, y, 0) + face * 0.06
				var u: Vector3 = across * width
				var v := Vector3(0, height, 0)
				# A thin gilded frame, its dark back, then the picture.
				var basis := Basis(across, Vector3.UP, face)
				s.box_xform(Transform3D(basis * Basis.from_scale(Vector3(width + FRAME * 2.0, height + FRAME * 2.0, 0.1)),
					c - face * 0.03), skin.gold_color.darkened(0.35), 0.0, MeshKit.PAT_GOLD, MeshKit.ALL_FACES, 0.7)
				f.rect(c - u * 0.5 - v * 0.5 + face * 0.03, u, v, Color.WHITE, SCREEN_BRIGHTNESS * (0.75 + 0.25 * float((k + r) % 2)),
					0, Vector2.ZERO, Vector2.ONE, width / maxf(height, 0.01))
	var room: MeshInstance3D = batch.commit(self, "Room")
	room.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_suit(material: ShaderMaterial) -> void:
	var m: Dictionary = GoldenConvergenceModel.meshes(material, RenderingServer.get_current_rendering_method() == "gl_compatibility")
	suit = Node3D.new()
	suit.name = "GoldenConvergence"
	suit.scale = Vector3.ONE * tuning.suit_scale
	add_child(suit)
	MeshBatch.add_instance(suit, m["torso"], "Torso")
	MeshBatch.add_instance(suit, m["plates_left"], "PlateR")
	MeshBatch.add_instance(suit, m["plates_right"], "PlateL")
	head = Node3D.new()
	head.name = "Head"
	head.position = Vector3(0.0, 16.0, 0.0)
	suit.add_child(head)
	MeshBatch.add_instance(head, m["head"], "Face", Vector3(0.0, -16.0, 0.0))
	halo = Node3D.new()
	halo.name = "Halo"
	halo.position = GoldenConvergenceSuit.HALO_AT
	suit.add_child(halo)
	MeshBatch.add_instance(halo, m["halo"], "Rings")
	MeshBatch.add_instance(suit, m["tentacles"], "Pipes")
	cape_material = GoldenConvergenceModel.cape_material()
	var cape: MeshInstance3D = MeshBatch.add_instance(suit, m["cape"], "Cape")
	cape.material_override = cape_material
	cape.extra_cull_margin = 16.0
	for side: int in [-1, 1]:
		var p: Vector3 = GoldenConvergenceModel.PIPES_AT
		var pipes := Node3D.new()
		pipes.position = Vector3(side * p.x, p.y, p.z)
		suit.add_child(pipes)
		MeshBatch.add_instance(pipes, m["pipes"], "Cluster")
		var hatch := Node3D.new()
		hatch.transform = GoldenConvergenceModel.hatch_hinge()
		pipes.add_child(hatch)
		MeshBatch.add_instance(hatch, m["pipe_cap"], "Lid")
	# Its arms: the left hangs at its side; the right (as the camera sees it, on the left) comes up to point.
	for side: int in [-1, 1]:
		var s: Vector3 = GoldenConvergenceModel.SHOULDER
		var sh := Node3D.new()
		sh.name = "Shoulder%s" % ("R" if side < 0 else "L")
		sh.position = Vector3(side * s.x, s.y, s.z)
		sh.basis = _rest(side)
		suit.add_child(sh)
		MeshBatch.add_instance(sh, m["upper_arm"], "UpperArm")
		var el := Node3D.new()
		el.name = "Elbow"
		el.position = Vector3(0.0, -GoldenConvergenceModel.UPPER_ARM, 0.0)
		el.rotation = Vector3(ELBOW_REST, 0.0, 0.0)
		sh.add_child(el)
		MeshBatch.add_instance(el, m["forearm"], "Forearm")
		var wrist := Node3D.new()
		wrist.name = "Wrist"
		wrist.position = Vector3(0.0, -GoldenConvergenceModel.FOREARM, 0.0)
		el.add_child(wrist)
		var open: MeshInstance3D = MeshBatch.add_instance(wrist, m["hand"], "Hand")
		if side < 0:
			shoulder = sh
			elbow = el
			hand = open
			fist = MeshBatch.add_instance(wrist, m["fist"], "Fist")
			MeshBatch.add_instance(fist, pointing_finger(material), "Finger")
			fist.visible = false
	update(0.0)


## The arm at rest on `side` (-1 its right): hanging a little out and forward.
static func _rest(side: int) -> Basis:
	return Basis(Vector3.BACK, side * ARM_REST_OUT) * Basis(Vector3.RIGHT, ARM_REST_FORWARD)


## The index finger out of the fist (its knuckle by the thumb), along -y like the fist's hand: a gold finger in
## three joints, the model's own gold (cached per material).
static func pointing_finger(material: Material) -> ArrayMesh:
	var key: int = material.get_instance_id()
	if _fingers.has(key):
		return _fingers[key]
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(material)
	var knuckle := Vector3(1.5, -3.5, 1.0)
	var joints: Array[Vector3] = [knuckle, knuckle + Vector3(0.0, -1.6, -0.15), knuckle + Vector3(0.0, -2.9, -0.25),
		knuckle + Vector3(0.0, -3.9, -0.3)]
	var radii: Array[float] = [0.6, 0.55, 0.5, 0.42]
	for k: int in 3:
		var a: Vector3 = joints[k]
		var b: Vector3 = joints[k + 1]
		var d: Vector3 = b - a
		var up: Vector3 = d.normalized()
		var side: Vector3 = up.cross(Vector3.FORWARD).normalized()
		s.prism_xform(Transform3D(Basis(side * radii[k], d, up.cross(side) * radii[k]), a), 8,
			GoldenConvergenceModel.GOLD_PALE if k % 2 == 0 else GoldenConvergenceModel.GOLD, 0.0, MeshKit.PAT_GOLD, true, 0.85)
	var mesh: ArrayMesh = batch.to_mesh()
	_fingers[key] = mesh
	return mesh


## Poses it at time `t` (the cinematic's clock): its halo turning, its cape billowing, its right arm rising from its
## side to point straight ahead (its hand closing to a fist with the finger out as it comes up).
func update(t: float) -> void:
	if suit == null:
		return
	halo.rotation = Vector3(0.0, 0.0, t * HALO_SPIN)
	head.rotation = Vector3(HEAD_LOOK_DOWN, 0.0, 0.0)
	cape_material.set_shader_parameter(&"unfurl", tuning.cape_unfurl)
	var raise: float = smoothstep(tuning.point_at, tuning.point_at + tuning.point_seconds, t)
	pointing = raise
	var rest: Basis = _rest(-1)
	var basis: Basis = rest
	if raise > 0.0:
		var local: Vector3 = point_target / tuning.suit_scale - shoulder.position
		var aim := Basis(Quaternion(Vector3.DOWN, local.normalized()))
		basis = Basis(rest.get_rotation_quaternion().slerp(aim.get_rotation_quaternion(), raise))
	shoulder.basis = basis
	elbow.rotation = Vector3(ELBOW_REST * (1.0 - raise), 0.0, 0.0)
	# The hand closes to point once the arm is halfway up.
	var pointed: bool = raise > 0.45
	hand.visible = not pointed
	fist.visible = pointed


## Its face's middle (the room's space): the camera looks at it.
func face_point() -> Vector3:
	return GoldenConvergenceModel.HEAD * tuning.suit_scale


## The tip of its pointing finger (world space).
func finger_tip() -> Vector3:
	return fist.global_transform * Vector3(1.5, -7.4, 0.7)
