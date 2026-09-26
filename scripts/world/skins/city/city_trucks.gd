class_name CityTrucks
extends RefCounted
## Hover-truck convoys for the city floor (CitySkin). A solid stretch of one lane between two gaps
## is one road train driving toward the player: a cab at its near end (headlights, grille, amber
## marker lights facing the player), trailers coupled behind it, and a rear at its far end.
## Floor pieces arrive clipped to track chunks, so everything is placed by track distance:
## couplings sit on a per-lane grid and each trailer's paint comes from hashing its grid cell,
## which makes a trailer cut by a chunk boundary continue seamlessly in the next chunk.
## Local truck space: x across (centred on the lane), y down from the roof (y = 0), z = -distance.

const CAB_DEPTH: float = 2.6
const REAR_DEPTH: float = 0.9
const SEAM_HALF: float = 0.2
const CHAMFER: float = 0.07
const SKIRT: float = 0.32
const EDGE_LIP: float = 0.18

## Weak: the skin owns this builder, so a strong reference back would keep both alive forever.
var skin: CitySkin:
	get:
		return _skin.get_ref() as CitySkin
var _skin: WeakRef
## Templates by Vector4(kind, width, paint, roof offset): cheap keys, looked up for every trailer.
var _templates: Dictionary = {}


func _init(p_skin: CitySkin) -> void:
	_skin = weakref(p_skin)


## Adds the trucks for one floor piece [near_d, far_d] of the lane at lane_x.
func build(batch: MeshBatch, lane_x: float, width: float, near_d: float, far_d: float,
		edge_start: bool, edge_end: bool) -> void:
	var length: float = far_d - near_d
	if length < 0.02 or width <= 0.1:
		return
	var lane_key: int = MeshKit.key(lane_x)
	var unit_len: float = skin.trailer_length * (0.85 + 0.3 * MeshKit.hash01(lane_key, 11))
	var offset: float = MeshKit.hash01(lane_key, 12) * unit_len
	var roof_param: float = MeshKit.hash01(lane_key, 13) * 1.6

	var cab_d: float = 0.0
	var rear_d: float = 0.0
	if edge_start:
		cab_d = minf(CAB_DEPTH, length * (0.7 if edge_end else 1.0))
	if edge_end:
		rear_d = minf(REAR_DEPTH, length - cab_d)
	if cab_d > 0.0:
		var paint: int = MeshKit.hash_i(lane_key, MeshKit.key(near_d), 3) % skin.cab_colors.size()
		batch.append(_cab(width, paint, roof_param), Transform3D(Basis.from_scale(Vector3(1, 1, cab_d / CAB_DEPTH)),
			Vector3(lane_x, 0, -near_d)))
	if rear_d > 0.0:
		batch.append(_rear(width, roof_param), Transform3D(Basis.from_scale(Vector3(1, 1, rear_d / REAR_DEPTH)),
			Vector3(lane_x, 0, -far_d)))
	var body0: float = near_d + cab_d
	var body1: float = far_d - rear_d
	if body1 - body0 < 0.01:
		return

	# Couplings on the lane's grid. The piece owns grid lines inside it; a line within SEAM_HALF of
	# a chunk cut is skipped by both neighbours. No coupling right behind a cab or before a rear.
	var lo: float = body0 + SEAM_HALF + (1.2 if edge_start else 0.0)
	var hi: float = body1 - SEAM_HALF - (1.2 if edge_end else 0.0)
	var cursor: float = body0
	var k: int = ceili((lo - offset) / unit_len)
	var g: float = offset + k * unit_len
	while g <= hi:
		_body(batch, lane_x, width, cursor, g - SEAM_HALF, unit_len, offset, lane_key, roof_param)
		batch.append(_seam(width), Transform3D(Basis.IDENTITY, Vector3(lane_x, 0, -g)))
		cursor = g + SEAM_HALF
		k += 1
		g = offset + k * unit_len
	_body(batch, lane_x, width, cursor, body1, unit_len, offset, lane_key, roof_param)


## One trailer body between two distances, painted by the grid cell it belongs to.
func _body(batch: MeshBatch, lane_x: float, width: float, d0: float, d1: float, unit_len: float,
		offset: float, lane_key: int, roof_param: float) -> void:
	if d1 - d0 < 0.005:
		return
	var cell: int = floori(((d0 + d1) * 0.5 - offset) / unit_len)
	var paint: int = MeshKit.hash_i(lane_key, cell, 5) % skin.container_colors.size()
	batch.append(_unit(width, paint, roof_param), Transform3D(Basis.from_scale(Vector3(1, 1, d1 - d0)),
		Vector3(lane_x, 0, -d0)))


# --- Templates (built once per width and paint, then instanced with bulk transforms) --------

## A trailer body 1 m long (z from 0 to -1): roof, chamfered edges, ribbed sides, light strips,
## a dark skirt with the hover thrusters' glow along its foot.
func _unit(width: float, paint: int, roof_param: float) -> MeshBatch:
	var id := Vector4(0, width, paint, roof_param)
	if _templates.has(id):
		return _templates[id]
	var b := MeshBatch.new()
	var s: MeshLayer = b.layer(skin.solid_material())
	var color: Color = skin.container_colors[paint]
	var hw: float = width * 0.5
	var h: float = skin.truck_height
	_roof(s, hw, 0.0, -1.0, skin.roof_color.lerp(color, 0.14), roof_param)
	for side: float in [-1.0, 1.0]:
		_side(s, side, hw, 0.0, -1.0, color)
	_templates[id] = b
	return b


## A coupling between trailers, centred on z = 0: a recessed dark band crossed by a flush plate.
func _seam(width: float) -> MeshBatch:
	var id := Vector4(1, width, 0, 0)
	if _templates.has(id):
		return _templates[id]
	var b := MeshBatch.new()
	var s: MeshLayer = b.layer(skin.solid_material())
	var hw: float = width * 0.5
	var dark := Color(0.05, 0.05, 0.07)
	var plate := Color(0.25, 0.26, 0.3)
	s.rect(Vector3(-hw, -0.05, SEAM_HALF), Vector3(width, 0, 0), Vector3(0, 0, -SEAM_HALF * 2.0), dark)
	# The far trailer's front lip, facing the player: a crisp light edge across the roof.
	s.rect(Vector3(-hw + CHAMFER, -0.05, -SEAM_HALF), Vector3(width - CHAMFER * 2.0, 0, 0), Vector3(0, 0.05, 0), plate)
	s.box(Vector3(0, -0.025, 0), Vector3(0.9, 0.05, SEAM_HALF * 2.0), plate, 0.0, MeshKit.PAT_PLAIN,
		MeshKit.FACE_PY | MeshKit.FACE_PZ)
	for side: float in [-1.0, 1.0]:
		s.box(Vector3(side * (hw - 0.09), -skin.truck_height * 0.5, 0),
			Vector3(0.02, skin.truck_height - 0.1, SEAM_HALF * 2.0), dark, 0.0, MeshKit.PAT_PLAIN,
			MeshKit.FACE_PX if side > 0.0 else MeshKit.FACE_NX)
	_templates[id] = b
	return b


## The cab module, z from 0 (front face, at the gap edge) to -CAB_DEPTH. Faces the player.
func _cab(width: float, paint: int, roof_param: float) -> MeshBatch:
	var id := Vector4(2, width, paint, roof_param)
	if _templates.has(id):
		return _templates[id]
	var b := MeshBatch.new()
	var s: MeshLayer = b.layer(skin.solid_material())
	var g: MeshLayer = b.layer(skin.glow_material())
	var hw: float = width * 0.5
	var h: float = skin.truck_height
	var d: float = CAB_DEPTH
	var color: Color = skin.cab_colors[paint]
	var trim: Color = color.darkened(0.45)
	var dark := Color(0.05, 0.05, 0.07)
	var edge: Color = skin.gap_edge_color
	var light: Color = skin.headlight_color
	var sides: int = MeshKit.FACE_PX | MeshKit.FACE_NX

	# Roof: the amber lip at the gap edge, then plates.
	s.rect(Vector3(-hw, 0, 0), Vector3(width, 0, 0), Vector3(0, 0, -EDGE_LIP), edge, 0.33)
	_roof(s, hw, -EDGE_LIP, -d, skin.roof_color, roof_param)
	# Upper band with the amber marker lights.
	s.box(Vector3(0, -0.16, -d * 0.5), Vector3(width, 0.32, d), color, 0.0, MeshKit.PAT_PLAIN, sides | MeshKit.FACE_PZ)
	for i: int in 5:
		var mx: float = (float(i) - 2.0) * minf(0.34, width * 0.15)
		s.box(Vector3(mx, -0.15, 0.012), Vector3(0.13, 0.07, 0.03), edge, 0.6)
		g.rect(Vector3(mx - 0.22, -0.37, 0.03), Vector3(0.44, 0, 0), Vector3(0, 0.44, 0), edge, 0.3, MeshKit.SHAPE_RADIAL)
	# Windscreen between two pillars, set back under the band.
	for side: float in [-1.0, 1.0]:
		s.box(Vector3(side * (hw - 0.07), -0.72, -d * 0.5), Vector3(0.14, 0.8, d), color, 0.0, MeshKit.PAT_PLAIN,
			sides | MeshKit.FACE_PZ)
		s.box(Vector3(side * (hw + 0.004), -0.7, -0.95), Vector3(0.012, 0.52, 1.1), Color(0.03, 0.04, 0.08), 0.0,
			MeshKit.PAT_GLASS, MeshKit.FACE_PX if side > 0.0 else MeshKit.FACE_NX)
	s.rect(Vector3(-hw + 0.14, -1.12, -0.16), Vector3(width - 0.28, 0, 0), Vector3(0, 0.8, 0), Color(0.03, 0.04, 0.08),
		0.0, MeshKit.PAT_GLASS)
	s.box(Vector3(0, -0.72, -0.13), Vector3(0.05, 0.8, 0.06), trim, 0.0, MeshKit.PAT_PLAIN, MeshKit.FACE_PZ)
	# Lower fascia: DRL strip, headlights, grille, bumper.
	s.box(Vector3(0, -1.71, -d * 0.5), Vector3(width, 1.18, d), color.darkened(0.25), 0.0, MeshKit.PAT_PLAIN,
		sides | MeshKit.FACE_PZ | MeshKit.FACE_PY)
	s.box(Vector3(0, -1.19, 0.008), Vector3(width - 0.3, 0.035, 0.02), light, 0.55)
	for side: float in [-1.0, 1.0]:
		var hx: float = side * (hw - 0.36)
		s.box(Vector3(hx, -1.42, 0.012), Vector3(0.46, 0.2, 0.03), light, 1.0)
		s.box(Vector3(side * (hw - 0.2), -2.0, 0.01), Vector3(0.18, 0.08, 0.02), light, 0.6)
		g.rect(Vector3(hx - 0.8, -1.95, 0.05), Vector3(1.6, 0, 0), Vector3(0, 1.06, 0), light, 0.32, MeshKit.SHAPE_RADIAL)
		# A beam spilling toward the player over the gap.
		g.quad(Vector3(hx - 0.2, -1.42, 0.05), Vector3(hx - 1.1, -1.9, 7.0), Vector3(hx + 1.1, -1.9, 7.0),
			Vector3(hx + 0.2, -1.42, 0.05), light, 0.07, MeshKit.SHAPE_BEAM)
	s.box(Vector3(0, -1.5, 0.006), Vector3(minf(0.8, width - 1.3), 0.34, 0.02), dark, 0.0, MeshKit.PAT_GRILLE)
	s.box(Vector3(0, -2.12, 0.012), Vector3(width, 0.22, 0.03), trim)
	# Skirt with the thruster glow.
	s.box(Vector3(0, -(h + 2.3) * 0.5, -d * 0.5 - 0.08), Vector3(width - 0.16, h - 2.3, d - 0.16), dark, 0.0,
		MeshKit.PAT_PLAIN, sides | MeshKit.FACE_PZ)
	s.box(Vector3(0, -h + 0.05, -0.07), Vector3(width - 0.3, 0.06, 0.02), skin.thruster_color, 0.7)
	_templates[id] = b
	return b


## The rear module, z from 0 (rear face, at the gap edge) to +REAR_DEPTH toward the player.
func _rear(width: float, roof_param: float) -> MeshBatch:
	var id := Vector4(3, width, 0, roof_param)
	if _templates.has(id):
		return _templates[id]
	var b := MeshBatch.new()
	var s: MeshLayer = b.layer(skin.solid_material())
	var hw: float = width * 0.5
	var h: float = skin.truck_height
	var d: float = REAR_DEPTH
	var doors := Color(0.14, 0.14, 0.17)
	s.rect(Vector3(-hw, 0, EDGE_LIP), Vector3(width, 0, 0), Vector3(0, 0, -EDGE_LIP), skin.gap_edge_color, 0.33)
	_roof(s, hw, d, EDGE_LIP, skin.roof_color, roof_param)
	for side: float in [-1.0, 1.0]:
		_side(s, side, hw, d, 0.0, doors)
	s.box(Vector3(0, -(h - SKIRT) * 0.5 - 0.03, 0.01), Vector3(width, h - SKIRT - 0.06, 0.02), doors, 0.0,
		MeshKit.PAT_RIBS, MeshKit.FACE_NZ)
	for side: float in [-1.0, 1.0]:
		s.box(Vector3(side * (hw - 0.1), -1.2, -0.005), Vector3(0.1, 1.6, 0.02), skin.traffic_tail_color, 0.8,
			MeshKit.PAT_PLAIN, MeshKit.FACE_NZ)
	_templates[id] = b
	return b


## Roof plates from z0 to z1 (z0 > z1) with chamfered long edges.
func _roof(s: MeshLayer, hw: float, z0: float, z1: float, color: Color, roof_param: float) -> void:
	var len: float = z1 - z0
	s.rect(Vector3(-hw + CHAMFER, 0, z0), Vector3((hw - CHAMFER) * 2.0, 0, 0), Vector3(0, 0, len), color, 0.0,
		MeshKit.PAT_ROOF, Vector2.ZERO, Vector2.ONE, roof_param)
	var rim: Color = color.lightened(0.18)
	s.rect(Vector3(hw - CHAMFER, 0, z0), Vector3(CHAMFER, -CHAMFER, 0), Vector3(0, 0, len), rim)
	s.rect(Vector3(-hw, -CHAMFER, z0), Vector3(CHAMFER, CHAMFER, 0), Vector3(0, 0, len), rim)


## One long side from z0 to z1 (z0 > z1): ribbed paint, a light strip, the skirt and thruster glow.
func _side(s: MeshLayer, side: float, hw: float, z0: float, z1: float, color: Color) -> void:
	var h: float = skin.truck_height
	var len: float = z1 - z0
	var x: float = side * hw
	var top: float = -CHAMFER
	var skirt_top: float = -(h - SKIRT)
	# Faces point outward: +x on the right (u runs toward -z), -x on the left (u runs toward +z).
	var z_start: float = z0 if side > 0.0 else z1
	var u := Vector3(0, 0, len if side > 0.0 else -len)
	s.rect(Vector3(x, skirt_top, z_start), u, Vector3(0, top - skirt_top, 0), color, 0.0, MeshKit.PAT_RIBS)
	s.rect(Vector3(x + side * 0.01, -0.34, z_start), u, Vector3(0, 0.05, 0), skin.truck_light_color, 0.22)
	var sx: float = side * (hw - 0.08)
	s.rect(Vector3(sx, -h, z_start), u, Vector3(0, SKIRT, 0), Color(0.05, 0.05, 0.07))
	s.rect(Vector3(sx + side * 0.01, -h + 0.02, z_start), u, Vector3(0, 0.08, 0), skin.thruster_color, 0.6)
