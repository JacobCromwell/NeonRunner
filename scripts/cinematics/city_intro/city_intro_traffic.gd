class_name CityIntroTraffic
extends Node3D
## The City intro's traffic (CityIntro; the owner's October 16, 2026 beats: "lots of people, cars, buses and trucks moving on
## the streets below"): hover cars, buses and trucks driving the street's two outer lanes, one each way, in the City's
## look. Visual only. The hover trucks are the skin's own (CityTrucks: the cab, trailers and rear of the convoys the
## runner crosses in a level, in a copy of the skin whose marker lights are the headlights' white and whose paints
## leave out red, since a street truck's orange edge lights would read as a gap's); the cars and the bus are built here
## in the same kit, by code (GDD §11: low-poly, glowing). Colour rules: paint in muted tones, headlights cold white,
## tail lights the City's violet (never red: red is an enemy's attack), nothing in a hazard's hue.
##
## Each vehicle's place is worked out from the clock (`update(time)`), so stepping or skipping shows the same: its lane,
## and a start along a loop of `loop_length` metres it drives round (pops happen beyond the fog or behind the camera),
## one speed to a lane so none ever catches up with another. A MultiMesh to each look (about 18 draw calls for the lot).
##
## World space (see CityIntroStreet): y = 0 the road, x = 0 the street's middle, track distance z is world z = -z; a
## model faces +z (toward the start of the track) and drives that way, turned round for the lane the other way.

const PAINTS: Array[Color] = [Color(0.62, 0.64, 0.72), Color(0.14, 0.16, 0.34), Color(0.27, 0.14, 0.36),
	Color(0.82, 0.84, 0.9), Color(0.1, 0.1, 0.13), Color(0.2, 0.32, 0.42)]
const GLASS := Color(0.03, 0.04, 0.08)
const WINDOW_LIGHT := Color(1.0, 0.86, 0.66)
const SIGN_LIGHT := Color(0.62, 0.8, 1.0)
## How high the hovering vehicles ride (their undersides), metres.
const HOVER: float = 0.3
## Truck variants: where along the (virtual) road its paints are picked, and its length.
const TRUCK_SEEDS: Array[float] = [0.0, 80.0, 190.0]
const TRUCK_LENGTH: float = 16.0
const CAR_LENGTH: float = 4.4
const BUS_LENGTH: float = 11.6
const MIN_GAP: float = 5.0

## One look: its MultiMesh, its length and how many it holds.
class Look:
	var multi: MultiMesh
	var node: MultiMeshInstance3D
	var length: float = 0.0
	var count: int = 0

## One vehicle: its look, lane x, direction (+1 drives toward the end of the track), speed (m/s), and where it starts on
## the loop (metres from loop_start).
class Vehicle:
	var look: int = 0
	var lane_x: float = 0.0
	var dir: float = 1.0
	var speed: float = 0.0
	var start: float = 0.0
	var slot: int = 0

var skin: CitySkin
var looks: Array[Look] = []
var vehicles: Array[Vehicle] = []
var loop_start: float = 0.0
var loop_length: float = 0.0
## The lanes' x (negative: the lane toward the camera's start).
var lane_xs := PackedFloat32Array()

var _truck_skin: CitySkin


## Builds the traffic for a street whose kerbs are `road_half` apart (CityIntroStreet), driving a loop from track
## distance `z_lo` to `z_hi`, `per_lane` vehicles to each of its two lanes. `clear`: a stretch of road both lanes keep empty
## (x its middle's track distance, y the time it is there, z its length): where the cinematic looks through at that time.
func build(p_skin: CitySkin, road_half: float, z_lo: float, z_hi: float, per_lane: int, speeds: Vector2,
		clear: Vector3 = Vector3.ZERO) -> void:
	skin = p_skin
	loop_start = z_lo
	loop_length = z_hi - z_lo
	lane_xs = PackedFloat32Array([-road_half * 0.75, road_half * 0.75])
	_truck_skin = _street_truck_skin()
	for paint: int in PAINTS.size():
		_add_look(_car(PAINTS[paint], 0), CAR_LENGTH)
	for paint: int in PAINTS.size():
		_add_look(_car(PAINTS[paint], 1), CAR_LENGTH + 0.3)
	var bus_paints: Array[Color] = [Color(0.2, 0.16, 0.44), Color(0.16, 0.24, 0.42)]
	for paint: Color in bus_paints:
		_add_look(_bus(paint), BUS_LENGTH)
	for k: int in TRUCK_SEEDS.size():
		_add_look(_truck(TRUCK_SEEDS[k]), TRUCK_LENGTH)
	_plan(per_lane, speeds, clear)
	for look: Look in looks:
		look.multi.instance_count = look.count
		look.multi.visible_instance_count = look.count
	update(0.0)


## The truck kit's skin: a copy whose gap-edge and marker lights are headlight white and whose cab and container paints
## are the City's muted ones.
func _street_truck_skin() -> CitySkin:
	var copy := skin.duplicate() as CitySkin
	copy.gap_edge_color = skin.headlight_color
	copy.cab_colors = PackedColorArray([Color(0.78, 0.79, 0.83), Color(0.1, 0.18, 0.5), Color(0.1, 0.1, 0.12),
		Color(0.33, 0.13, 0.46)])
	copy.container_colors = PackedColorArray([Color(0.13, 0.21, 0.36), Color(0.22, 0.23, 0.27), Color(0.44, 0.45, 0.49),
		Color(0.27, 0.14, 0.32), Color(0.1, 0.24, 0.27)])
	return copy


func _add_look(batch: MeshBatch, length: float) -> void:
	var look := Look.new()
	look.length = length
	look.multi = MultiMesh.new()
	look.multi.transform_format = MultiMesh.TRANSFORM_3D
	look.multi.mesh = batch.to_mesh()
	look.node = MultiMeshInstance3D.new()
	look.node.name = "Look%d" % looks.size()
	look.node.multimesh = look.multi
	look.node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(look.node)
	looks.append(look)


## Picks each lane's vehicles (about 60 % cars, a bus now and then, trucks) and spreads them round the loop with gaps
## of at least MIN_GAP, the lane's one speed, and the `clear` stretch (z: its length, empty at time y around distance x).
func _plan(per_lane: int, speeds: Vector2, clear: Vector3) -> void:
	for lane: int in lane_xs.size():
		var picks: Array[int] = []
		var used: float = 0.0
		var weights := PackedFloat32Array()
		var weight_sum: float = 0.0
		for i: int in per_lane:
			var r: float = MeshKit.hash01(lane + 5, i, 81)
			var look: int = 0
			if r < 0.58:
				look = int(MeshKit.hash01(lane + 5, i, 82) * 2.0 * PAINTS.size()) % (PAINTS.size() * 2)
			elif r < 0.7:
				look = PAINTS.size() * 2 + int(MeshKit.hash01(lane + 5, i, 83) * 2.0) % 2
			else:
				look = PAINTS.size() * 2 + 2 + int(MeshKit.hash01(lane + 5, i, 84) * 3.0) % 3
			picks.append(look)
			used += looks[look].length
			var w: float = 0.25 + 1.5 * MeshKit.hash01(lane + 5, i, 86)
			weights.append(w)
			weight_sum += w
		# The empty stretch first (before the first vehicle), then the others spread over what is left, the last vehicle
		# ending where the loop does.
		var clear_len: float = clamp(clear.z, 0.0, maxf(loop_length - used - MIN_GAP * per_lane, 0.0))
		var spare: float = maxf(loop_length - used - clear_len - MIN_GAP * maxi(per_lane - 1, 0), 0.0)
		var speed: float = lerpf(speeds.x, speeds.y, float(lane))
		var dir: float = -1.0 if lane == 0 else 1.0
		# Where the empty stretch's middle lies in the layout, and the shift that puts it at clear.x at time clear.y.
		var shift: float = 0.0
		if clear_len > 0.0:
			shift = (clear.x - loop_start) - (clear_len * 0.5 + dir * speed * clear.y)
		var cursor: float = clear_len
		for i: int in per_lane:
			var v := Vehicle.new()
			v.look = picks[i]
			v.lane_x = lane_xs[lane]
			v.dir = dir
			v.speed = speed
			v.start = fposmod(cursor + looks[v.look].length * 0.5 + shift, loop_length)
			v.slot = looks[v.look].count
			looks[v.look].count += 1
			vehicles.append(v)
			cursor += looks[v.look].length
			if i < per_lane - 1:
				cursor += MIN_GAP + spare * weights[i] / weight_sum


## Where vehicle `v` is at time `t`: its track distance (its middle).
func distance_of(v: Vehicle, t: float) -> float:
	return loop_start + fposmod(v.start + v.dir * v.speed * t, loop_length)


## Puts every vehicle where it is at time `t`: a faint bob as it hovers.
func update(t: float) -> void:
	for v: Vehicle in vehicles:
		var z: float = distance_of(v, t)
		var bob: float = 0.025 * sin(t * 2.1 + v.start * 0.37)
		var facing: float = 0.0 if v.dir < 0.0 else PI
		var xf := Transform3D(Basis(Vector3.UP, facing), Vector3(v.lane_x, bob, -z))
		looks[v.look].multi.set_instance_transform(v.slot, xf)


# --- The models (local space: the front +z, the road y = 0, the middle x = 0, z = 0) -------------------------------

## A hover car: a lower body, a glass cabin set back under a painted roof, headlights, a violet tail light bar, the
## thrusters' glow along its underside and a pool of it on the road. `kind` 0 a saloon, 1 a taller wagon.
func _car(paint: Color, kind: int) -> MeshBatch:
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(skin.solid_material())
	var g: MeshLayer = batch.layer(skin.glow_material())
	var length: float = CAR_LENGTH + 0.3 * float(kind)
	var hw: float = 0.95
	var h0: float = HOVER
	s.box(Vector3(0.0, h0 + 0.27, 0.0), Vector3(hw * 2.0, 0.54, length), paint, 0.0, MeshKit.PAT_PLAIN, MeshKit.ALL_FACES & ~MeshKit.FACE_NY)
	# The bonnet and boot sloping down: darker wedges on the body's top.
	s.box(Vector3(0.0, h0 + 0.58, length * 0.3), Vector3(hw * 2.0 - 0.1, 0.1, length * 0.36), paint.darkened(0.15))
	var cab_len: float = (2.3 if kind == 0 else 3.0)
	var cab_z: float = -0.25 if kind == 0 else -0.5
	var cab_h: float = 0.5 if kind == 0 else 0.62
	s.box(Vector3(0.0, h0 + 0.54 + cab_h * 0.5, cab_z), Vector3(hw * 2.0 - 0.3, cab_h, cab_len), GLASS, 0.0, MeshKit.PAT_GLASS,
		MeshKit.ALL_FACES & ~MeshKit.FACE_NY & ~MeshKit.FACE_PY)
	s.box(Vector3(0.0, h0 + 0.54 + cab_h + 0.04, cab_z - 0.05), Vector3(hw * 2.0 - 0.4, 0.09, cab_len - 0.2), paint.lightened(0.04))
	# Head and tail lights.
	for side: float in [-1.0, 1.0]:
		s.box(Vector3(side * 0.62, h0 + 0.38, length * 0.5 + 0.005), Vector3(0.4, 0.12, 0.04), skin.headlight_color, 1.0)
		g.rect(Vector3(side * 0.62 - 0.45, h0 + 0.38 - 0.4, length * 0.5 + 0.05), Vector3(0.9, 0.0, 0.0), Vector3(0.0, 0.8, 0.0),
			skin.headlight_color, 0.3, MeshKit.SHAPE_RADIAL)
		g.quad(Vector3(side * 0.62 - 0.15, 0.36 + h0 * 0.5, length * 0.5 + 0.05), Vector3(side * 0.62 - 0.9, 0.04, length * 0.5 + 6.0),
			Vector3(side * 0.62 + 0.9, 0.04, length * 0.5 + 6.0), Vector3(side * 0.62 + 0.15, 0.36 + h0 * 0.5, length * 0.5 + 0.05),
			skin.headlight_color, 0.06, MeshKit.SHAPE_BEAM)
	s.box(Vector3(0.0, h0 + 0.4, -length * 0.5 - 0.005), Vector3(hw * 2.0 - 0.3, 0.1, 0.04), skin.traffic_tail_color, 0.9)
	g.rect(Vector3(-0.9, h0 + 0.05, -length * 0.5 - 0.06), Vector3(1.8, 0.0, 0.0), Vector3(0.0, 0.7, 0.0), skin.traffic_tail_color,
		0.22, MeshKit.SHAPE_RADIAL)
	# The thrusters: a lit strip under each side and their glow on the road.
	for side: float in [-1.0, 1.0]:
		s.box(Vector3(side * (hw - 0.04), h0 + 0.03, 0.0), Vector3(0.06, 0.05, length - 0.4), skin.thruster_color, 0.8)
	g.rect(Vector3(-hw - 0.4, 0.04, length * 0.5 + 0.4), Vector3(hw * 2.0 + 0.8, 0.0, 0.0), Vector3(0.0, 0.0, -(length + 0.8)),
		skin.thruster_color, 0.16, MeshKit.SHAPE_FLAT)
	return batch


## A hover bus: a long body in the City's violet-blue with a pale stripe, a band of warm-lit windows down both sides, a
## destination board over a dark windscreen, headlights, violet tail lights, and its thrusters' glow.
func _bus(paint: Color) -> MeshBatch:
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(skin.solid_material())
	var g: MeshLayer = batch.layer(skin.glow_material())
	var hw: float = 1.28
	var length: float = BUS_LENGTH
	var h0: float = HOVER
	var top: float = h0 + 3.05
	s.box(Vector3(0.0, (h0 + top) * 0.5, 0.0), Vector3(hw * 2.0, top - h0, length), paint, 0.0, MeshKit.PAT_PLAIN,
		MeshKit.ALL_FACES & ~MeshKit.FACE_NY)
	s.box(Vector3(0.0, top + 0.05, 0.0), Vector3(hw * 2.0 - 0.3, 0.12, length - 0.6), paint.darkened(0.35))
	# The roof's air units.
	for k: int in 3:
		s.box(Vector3(0.0, top + 0.2, -3.2 + 3.0 * k), Vector3(1.2, 0.18, 1.5), paint.darkened(0.5))
	for side: float in [-1.0, 1.0]:
		var x: float = side * (hw + 0.012)
		# The window band: dark glass with the cabin's warm light shining through it.
		var z0: float = -length * 0.5 + 0.8
		var z1: float = length * 0.5 - 2.0
		var y0: float = h0 + 1.25
		var y1: float = h0 + 2.45
		_side_rect(s, side, x, z0, z1, y0, y1, GLASS, 0.0, MeshKit.PAT_GLASS)
		_side_rect(g, side, x + side * 0.01, z0, z1, y0 + 0.1, y1 - 0.1, WINDOW_LIGHT, 0.34, MeshKit.SHAPE_FLAT)
		# The pillars between the windows.
		var z: float = z0 + 1.7
		while z < z1 - 0.5:
			_side_rect(s, side, x + side * 0.02, z, z + 0.14, y0, y1, paint.darkened(0.1))
			z += 1.7
		# The pale stripe under the windows.
		_side_rect(s, side, x + side * 0.014, -length * 0.5 + 0.1, length * 0.5 - 0.1, h0 + 0.8, h0 + 1.0, paint.lightened(0.5), 0.12)
		# The door, a lit panel behind the front wheels' place.
		_side_rect(s, side, x + side * 0.016, length * 0.5 - 1.9, length * 0.5 - 0.7, h0 + 0.2, h0 + 2.3, paint.darkened(0.3))
		_side_rect(g, side, x + side * 0.02, length * 0.5 - 1.8, length * 0.5 - 0.8, h0 + 0.5, h0 + 2.15, WINDOW_LIGHT, 0.22,
			MeshKit.SHAPE_FLAT)
		s.box(Vector3(side * (hw - 0.04), h0 + 0.03, 0.0), Vector3(0.06, 0.05, length - 0.6), skin.thruster_color, 0.8)
	# The front: a dark windscreen under a cold-lit destination board, headlights.
	var fz: float = length * 0.5 + 0.012
	s.rect(Vector3(-hw + 0.2, h0 + 1.0, fz), Vector3(hw * 2.0 - 0.4, 0.0, 0.0), Vector3(0.0, 1.45, 0.0), GLASS, 0.0, MeshKit.PAT_GLASS)
	s.box(Vector3(0.0, h0 + 2.72, fz), Vector3(hw * 2.0 - 0.6, 0.26, 0.03), SIGN_LIGHT, 0.7, MeshKit.PAT_GLYPHS)
	for side: float in [-1.0, 1.0]:
		s.box(Vector3(side * (hw - 0.3), h0 + 0.6, fz + 0.01), Vector3(0.5, 0.16, 0.04), skin.headlight_color, 1.0)
		g.rect(Vector3(side * (hw - 0.3) - 0.5, h0 + 0.2, fz + 0.05), Vector3(1.0, 0.0, 0.0), Vector3(0.0, 0.9, 0.0),
			skin.headlight_color, 0.3, MeshKit.SHAPE_RADIAL)
		g.quad(Vector3(side * (hw - 0.3) - 0.2, h0 + 0.5, fz + 0.05), Vector3(side * (hw - 0.3) - 1.1, 0.04, fz + 7.0),
			Vector3(side * (hw - 0.3) + 1.1, 0.04, fz + 7.0), Vector3(side * (hw - 0.3) + 0.2, h0 + 0.5, fz + 0.05),
			skin.headlight_color, 0.06, MeshKit.SHAPE_BEAM)
	s.box(Vector3(0.0, h0 + 0.6, -length * 0.5 - 0.012), Vector3(hw * 2.0 - 0.4, 0.14, 0.03), skin.traffic_tail_color, 0.9)
	g.rect(Vector3(-hw, h0 + 0.1, -length * 0.5 - 0.06), Vector3(hw * 2.0, 0.0, 0.0), Vector3(0.0, 0.9, 0.0), skin.traffic_tail_color,
		0.2, MeshKit.SHAPE_RADIAL)
	g.rect(Vector3(-hw - 0.5, 0.04, length * 0.5 + 0.5), Vector3(hw * 2.0 + 1.0, 0.0, 0.0), Vector3(0.0, 0.0, -(length + 1.0)),
		skin.thruster_color, 0.14, MeshKit.SHAPE_FLAT)
	return batch


## A rectangle on a vehicle's side (side -1 left, +1 right as seen from behind it driving toward +z... its front faces +z), between
## z0 and z1 and heights y0 and y1.
func _side_rect(layer: MeshLayer, side: float, x: float, z0: float, z1: float, y0: float, y1: float, color: Color,
		glow: float = 0.0, pattern: int = 0) -> void:
	if side > 0.0:
		# Facing +x: u runs toward -z.
		layer.rect(Vector3(x, y0, z1), Vector3(0.0, 0.0, -(z1 - z0)), Vector3(0.0, y1 - y0, 0.0), color, glow, pattern)
	else:
		layer.rect(Vector3(x, y0, z0), Vector3(0.0, 0.0, z1 - z0), Vector3(0.0, y1 - y0, 0.0), color, glow, pattern)


## A hover truck, the skin's own: its cab, a trailer and its rear (CityTrucks, in the street truck skin), lifted off the
## road on its thrusters. `seed_at` varies its paints.
func _truck(seed_at: float) -> MeshBatch:
	var batch := MeshBatch.new()
	var trucks: CityTrucks = _truck_skin.trucks()
	var width: float = 2.4
	var inner := MeshBatch.new()
	trucks.build(inner, 0.0, width, seed_at, seed_at + TRUCK_LENGTH, true, true)
	# Truck space has the roof at y = 0 and the cab at the lowest distance, facing +z; the middle of its length at
	# z = -(seed_at + TRUCK_LENGTH / 2).
	var lift: float = _truck_skin.truck_height + HOVER
	batch.append(inner, Transform3D(Basis.IDENTITY, Vector3(0.0, lift, seed_at + TRUCK_LENGTH * 0.5)))
	return batch
