class_name GanglandIntroSet
extends Node3D
## The props of Gangland's intro (GanglandIntro), built on its stage (so they hide with it) and moved by the
## cinematic's clock: everything is worked out from the time, so stepping or skipping it shows the same. Visual
## only: no hitboxes.
## - The fork: a street off each side of the main street at the junction (the zone's own street pieces and building
##   fronts, ZoneSkin.floor_segment and wall_section, as the City outro's side street), each closed far down by a
##   building across it, and a building across the main street just past the junction, so the road forks.
## - The left gang's Octodog (OctodogModel, as in play, larger): it stands its ground, rears up (its wind-up, as in
##   play), lunges and mauls.
## - The right gang's hover truck (the enemy's own model at rest, HoverTruck.add_model), parked side on behind them,
##   bobbing on its hover glow.
## - The shots: bolts in enemy-fire red (ProjectilePool's enemy_bolt look), each lighting a small burst where it lands.

const HoverTruckScript := preload("res://scripts/enemies/hover_truck.gd")
const TRUCK_TUNING_PATH: String = "res://data/enemies/hover_truck.tres"
const BOLT_LOOK: StringName = &"enemy_bolt"
## A bolt's burst where it lands: how long it lasts, how big it grows (metres), and with Reduced flashing.
const BURST_SECONDS: float = 0.3
const BURST_SIZE: float = 0.55
const SOFT_BURST_SECONDS: float = 0.6
const SOFT_BURST_SIZE: float = 0.35
## The hover truck bobs this fast (rad/s).
const BOB_RATE: float = 2.1
## The junction's corners (corners_mesh). A pier reaches this far into the street and out past the wall's line (x,
## y), this far into the side street's mouth and back along the wall (x, y), and this high: over the wall-gap marks
## (ZoneSkin.WALL_GAP_EDGE_WIDTH 0.45 m on the wall's face and across the cut end, WALL_GAP_EDGE_HEIGHT 7 m up).
## The kerb across a side street's mouth (over the gap's 0.3 m lip), and its colour when the skin names no asphalt
## colour.
const PIER_IN := Vector2(0.2, 0.55)
const PIER_ALONG := Vector2(0.08, 0.75)
const PIER_HEIGHT: float = 7.4
const PIER_COLOR := Color(0.33, 0.29, 0.25)
const KERB_SIZE := Vector3(0.46, 0.035, 0.0)
const KERB := Color(0.17, 0.155, 0.135)

var intro: GanglandIntro
var n: GanglandIntroTuning
## The two side streets' frames: in each, -z leads out of the main street and x runs along it (the left one's +x
## ahead, the right one's +x back), so (u, v) is local (±v, y, -u).
var left_street: Node3D
var right_street: Node3D
var dog: OctodogModel
var truck: Node3D
var truck_tuning: HoverTruckTuning
## The bolts and their paths [from, to, launch, seconds] (world space), and each one's burst.
var bolts: Array[MeshInstance3D] = []
var bursts: Array[MeshInstance3D] = []
var _bolt_paths: Array = []
var _truck_base := Vector3.ZERO


## DESIGN-TBD (docs/questions/f2f.md, 1): the fork is a T junction, a building across the road ahead.
func setup(p_intro: GanglandIntro) -> void:
	intro = p_intro
	n = intro.n
	name = "Fork"
	var stage: CineStage = intro.stage
	left_street = _side_street(stage, -1, n.left_depth)
	right_street = _side_street(stage, 1, n.right_depth)
	# The building across the main street just past the junction: the road forks.
	var across := Node3D.new()
	across.name = "Across"
	across.position = stage.point(Vector3(0.0, 0.0, n.junction_at + intro.side_half()))
	across.position.x = 0.0
	add_child(across)
	_facade(across, stage.skin, Vector3.ZERO, stage.geo.wall_x() + 0.6)
	MeshBatch.add_instance(self, corners_mesh(stage, n.junction_at, intro.side_half()), "Corners")
	_build_dog(stage)
	_build_truck(stage)


## A side street off wall `side` at the junction, `depth` long: its lanes of the zone's street (the edge lanes run on
## to the building fronts), the zone's building fronts along both edges, and a building across its far end.
func _side_street(stage: CineStage, side: int, depth: float) -> Node3D:
	var street := Node3D.new()
	street.name = "LeftStreet" if side < 0 else "RightStreet"
	street.position = stage.point(Vector3(stage.wall_x(side), 0.0, n.junction_at))
	street.rotation.y = -side * PI * 0.5
	add_child(street)
	var lane_w: float = stage.geo.lane_width
	for i: int in n.side_lanes:
		var lx: float = (float(i) - (n.side_lanes - 1) * 0.5) * lane_w
		var x0: float = lx - lane_w * 0.5 - (n.side_margin if i == 0 else 0.0)
		var x1: float = lx + lane_w * 0.5 + (n.side_margin if i == n.side_lanes - 1 else 0.0)
		var floor_parent := Node3D.new()
		floor_parent.name = "Floor%d" % i
		street.add_child(floor_parent)
		stage.skin.floor_segment(floor_parent, Vector3((x0 + x1) * 0.5, -TrackBuilder.FLOOR_THICKNESS * 0.5, -depth * 0.5),
			Vector3(x1 - x0, TrackBuilder.FLOOR_THICKNESS, depth), lx, false, false)
	CityOutroSet._fronts(street, stage.skin, intro.side_half() - 0.03, depth)
	_facade(street, stage.skin, Vector3(0.0, 0.0, -depth), intro.side_half() + 0.5)
	return street


## The junction's four street corners (world space), over the marks a level's wall gap carries (ZoneSkin's
## standard_wall_gap: the glowing orange edge up the wall's face, and its lip along the floor's edge), which tell a
## runner in play that the wall stops; here they are only street corners: a concrete pier up each corner and a kerb
## of the street's asphalt across each side street's mouth. DESIGN-TBD (docs/questions/f2f.md, 11).
static func corners_mesh(stage: CineStage, middle: float, half: float) -> ArrayMesh:
	var batch := MeshBatch.new()
	# The skin's own solid material where it has one (its light and tint, as its street's), else the kit's.
	var material: Variant = stage.skin.call(&"solid_material") if stage.skin.has_method(&"solid_material") else null
	var s: MeshLayer = batch.layer(material as ShaderMaterial if material is ShaderMaterial else MeshKit.solid())
	var asphalt: Variant = stage.skin.get(&"asphalt_color")
	var kerb: Color = (asphalt as Color).darkened(0.15) if asphalt is Color else KERB
	for side: int in [-1, 1]:
		var face: float = side * stage.geo.wall_x()
		for end: int in [-1, 1]:
			var at: float = middle + end * half
			# From inside the street out past the wall's line (over the cut wall's end), and from just inside the
			# side street's mouth back along the wall (over the edge on its face).
			var x0: float = face - side * PIER_IN.x
			var x1: float = face + side * PIER_IN.y
			var z0: float = at - end * PIER_ALONG.x
			var z1: float = at + end * PIER_ALONG.y
			s.box(Vector3((x0 + x1) * 0.5, PIER_HEIGHT * 0.5, -(z0 + z1) * 0.5),
				Vector3(absf(x1 - x0), PIER_HEIGHT, absf(z1 - z0)), PIER_COLOR, 0.0, MeshKit.PAT_CONCRETE)
		s.box(Vector3(face - side * KERB_SIZE.x * 0.5, KERB_SIZE.y * 0.5, -middle),
			Vector3(KERB_SIZE.x, KERB_SIZE.y, half * 2.0), kerb, 0.0, MeshKit.PAT_PLAIN)
	return batch.to_mesh()


## The zone's building front (ZoneSkin.wall_section) across `parent`'s x from -half to half at `at`, facing
## `parent`'s +z, the building behind it.
static func _facade(parent: Node3D, skin: ZoneSkin, at: Vector3, half: float) -> void:
	var holder := Node3D.new()
	holder.name = "Facade"
	holder.position = at
	holder.rotation.y = PI * 0.5  # Its wall's -x face (a right wall's) toward the parent's +z, its length along x.
	parent.add_child(holder)
	var none: Array[Vector2] = []
	skin.note_wall_gaps(1, none)
	skin.wall_section(holder, 1, 0.02, -half, half)


func _build_dog(stage: CineStage) -> void:
	dog = OctodogModel.new()
	dog.name = "Octodog"
	add_child(dog)
	dog.build(stage.skin.enemy_variant, 3.0)
	dog.scale = Vector3.ONE * n.dog_scale


func _build_truck(stage: CineStage) -> void:
	truck_tuning = load(TRUCK_TUNING_PATH) as HoverTruckTuning
	if truck_tuning == null:
		truck_tuning = HoverTruckTuning.new()
	var holder := Node3D.new()
	holder.name = "Truck"
	left_street.add_child(holder)
	_truck_base = Vector3(n.truck_at.y, 0.0, -n.truck_at.x)
	holder.position = _truck_base
	holder.rotation.y = -PI * 0.5 if n.truck_faces_ahead else PI * 0.5  # Side on, its nose along the street's x.
	truck = HoverTruckScript.add_model(holder, stage.skin.enemy_variant, truck_tuning)


## The Octodog at `at` (world space) heading `yaw` (radians, 0 down the track, + left), moving at `speed` (m/s) and
## in its wind-up (`crouch`, `flare`), lunge (`reach`, `leap`) by these; then animated on by `delta`.
func pose_dog(at: Vector3, yaw: float, speed: float, crouch: float, flare: float, reach: float, leap: float,
		delta: float) -> void:
	dog.position = at
	dog.rotation.y = yaw
	dog.ground_speed = speed
	dog.crouch = crouch
	dog.flare = flare
	dog.reach = reach
	dog.leap = leap
	dog.animate(delta)


## The truck hovering at time `t`, a slow bob on its hover glow.
func update(t: float) -> void:
	if truck != null:
		truck.get_parent().position = _truck_base + Vector3(0.0, truck_tuning.bob_height * sin(t * BOB_RATE), 0.0)
	update_bolts(t)


## Fires a bolt (enemy-fire red) from `from` to `to` (world space), launched at `launch` and landing `seconds` later,
## where it bursts.
func add_bolt(from: Vector3, to: Vector3, launch: float, seconds: float) -> void:
	var look: Dictionary = ProjectilePool.LOOKS[BOLT_LOOK]
	var bolt := MeshInstance3D.new()
	bolt.name = "Bolt%d" % bolts.size()
	bolt.mesh = GreyboxMaterials.unit_box()
	bolt.material_override = GreyboxMaterials.glow(look["color"], look["energy"])
	bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bolt.visible = false
	add_child(bolt)
	bolts.append(bolt)
	var burst := MeshInstance3D.new()
	burst.name = "Burst%d" % bursts.size()
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 8
	sphere.rings = 4
	burst.mesh = sphere
	burst.material_override = GreyboxMaterials.glow(look["color"], look["energy"] * 0.6, 0.85)
	burst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	burst.visible = false
	add_child(burst)
	bursts.append(burst)
	_bolt_paths.append([from, to, launch, maxf(seconds, 0.05)])


## The bolts at time `t`: each in flight between its launch and its landing, a streak along its way, then its burst
## swelling and dying away where it landed (smaller and slower with Reduced flashing).
func update_bolts(t: float) -> void:
	var soft: bool = Settings.flashing_reduced
	var burst_time: float = SOFT_BURST_SECONDS if soft else BURST_SECONDS
	var burst_size: float = SOFT_BURST_SIZE if soft else BURST_SIZE
	var size: Vector3 = ProjectilePool.LOOKS[BOLT_LOOK]["size"]
	for i: int in bolts.size():
		var path: Array = _bolt_paths[i]
		var from: Vector3 = path[0]
		var to: Vector3 = path[1]
		var u: float = (t - float(path[2])) / float(path[3])
		var bolt: MeshInstance3D = bolts[i]
		bolt.visible = u >= 0.0 and u < 1.0
		if bolt.visible:
			var dir: Vector3 = (to - from).normalized()
			var up: Vector3 = Vector3.UP if absf(dir.y) < 0.98 else Vector3.BACK
			bolt.global_transform = Transform3D(Basis.looking_at(dir, up).scaled_local(size), from.lerp(to, u))
		var b: float = (t - float(path[2]) - float(path[3])) / burst_time
		var burst: MeshInstance3D = bursts[i]
		burst.visible = b >= 0.0 and b < 1.0
		if burst.visible:
			burst.global_position = to
			# Swelling fast and dying away (the material is the shared glow: its size alone fades it).
			burst.scale = Vector3.ONE * maxf(burst_size * sin(PI * sqrt(b)), 0.01)


## Bolts in flight or bursting at time `t` (tests).
func bolts_shown() -> int:
	var count: int = 0
	for bolt: MeshInstance3D in bolts:
		count += 1 if bolt.visible else 0
	return count
