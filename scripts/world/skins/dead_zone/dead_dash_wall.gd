class_name DeadDashWall
extends RefCounted
## The Dead Zone's dash wall (DeadZoneSkin.dash_wall; task H7b, GDD §9.14: "the same assets as the side walls,
## but facing towards the player, looking like a building in the middle of the street"): the stump of one of the
## dead city's burnt-out towers standing across the rubble street, built from DeadTowers' own kit: the scorched
## cladding of the calm band at its foot, the gutted window grids above it (MeshKit.PAT_DZ_TOWER, the shader the
## walls draw their faces with), charred concrete (PAT_DZ_CONCRETE) and heat-dulled steel (PAT_DZ_STEEL), its top
## broken off in bites. Four looks by the wall's seed:
## - 0 a burnt tower's foot: cladding up to a broken ledge, gutted windows over it to a jagged top;
## - 1 a skeleton: cladding at the foot, over it a gutted shell of blackened floor slabs between the steel columns
##   of the frame, standing against the dark of the rooms behind;
## - 2 a blast: the gutted face torn open higher up, a heap of rubble piled against its foot;
## - 3 a bunker block: charred precast concrete with slit windows, rebar standing out of its broken top.
## Every look is a block with depth (the facade set back from the box's face, ledges, columns and rubble standing
## out to it), its sides in concrete, cracks across it and a patch where its cladding has fallen: solid, and
## breakable. Nothing glows (no embers: the Dead Zone's only glows are the towers' high embers, and a dash wall
## stands at the runner's height), nothing in a hazard colour, and no billboard or neon (a sign reads as a
## hazard's). Meshes are cached by size and look and shared by every wall.
## DESIGN-TBD (docs/OPEN_QUESTIONS.md items 660 and 662): which four buildings the wall is, and its cracks as the only cue; the GDD says only
## "the same building faces".

## How far the facade plane sits back from the box's face.
const FACE_BACK: float = 0.55
## The calm band's height at the foot of the face (the scorched cladding, closed), and the ledge over it.
const FOOT: float = 3.0
const LEDGE: float = 0.3
## The broken top's profile has a point every STEP metres across, and never goes lower than TOP_MIN.
const STEP: float = 1.0
const TOP_MIN: float = 6.3
## The storey heights of PAT_DZ_TOWER's window grids by style (kit_dead_zone.gdshaderinc).
const STOREYS: Array[float] = [3.3, 3.0, 3.3, 3.3]

## Weak: the skin owns this builder, so a strong reference back would keep both alive forever.
var skin: DeadZoneSkin:
	get:
		return _skin.get_ref() as DeadZoneSkin
var _skin: WeakRef
var _meshes: Dictionary = {}


func _init(p_skin: DeadZoneSkin) -> void:
	_skin = weakref(p_skin)


## The wall's look for a box of `size` and a seed, built once.
func mesh_for(size: Vector3, look_seed: int) -> ArrayMesh:
	var look: int = DashWallKit.look_of(look_seed)
	var tone: int = DashWallKit.tone_of(look_seed)
	var key: String = "%s_%d_%d" % [size, look, tone]
	var found: ArrayMesh = _meshes.get(key)
	if found != null:
		return found
	var batch := MeshBatch.new()
	var solid: MeshLayer = batch.layer(skin.solid_material())
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["dead_dash_wall", look, tone])
	match look:
		0:
			_tower_foot(solid, size, tone, rng)
		1:
			_skeleton(solid, size, tone, rng)
		2:
			_blast(solid, size, tone, rng)
		_:
			_bunker(solid, size, tone, rng)
	var mesh: ArrayMesh = DashWallKit.finish(batch)
	_meshes[key] = mesh
	return mesh


## A burnt tower's foot: scorched cladding up to a broken ledge, the gutted windows over it up to a jagged top.
func _tower_foot(s: MeshLayer, size: Vector3, tone: int, rng: RandomNumberGenerator) -> void:
	var hx: float = size.x * 0.5
	var hz: float = size.z * 0.5
	var wall_z: float = hz - FACE_BACK
	var style: int = [0, 3, 1][tone % 3]
	var seed: int = MeshKit.hash_i(tone, 1, 81) % 997
	var param: float = MeshKit.dz_tower_param(style, seed)
	var wall: Color = _wall(tone)
	var tops: PackedFloat32Array = _profile(size, rng, 2 + tone % 2)
	_body(s, size, wall_z, TOP_MIN - 0.4, wall)
	# The cladding of the calm band, then (over the ledge) the windows' storeys to the broken top.
	DashWallKit.face(s, size, -hx, hx, 0.0, FOOT, wall_z, wall, MeshKit.PAT_DZ_TOWER, param, hx, 0.0)
	_windows(s, size, wall_z, tops, wall, style, param)
	_ledge(s, size, wall_z, wall, rng)
	_posts(s, size, wall_z, tops)
	_foot_rubble(s, size, wall_z, rng, 9)
	_damage(s, size, wall_z, tone, Vector4(-hx + 0.9, hx - 0.9, 0.9, TOP_MIN - 0.5), wall)


## A skeleton: cladding at the foot and the steel frame over it, its floors blackened slabs between the columns,
## the gutted rooms dark behind them.
func _skeleton(s: MeshLayer, size: Vector3, tone: int, rng: RandomNumberGenerator) -> void:
	var hx: float = size.x * 0.5
	var hz: float = size.z * 0.5
	var wall_z: float = hz - FACE_BACK
	var style: int = [3, 1, 0][tone % 3]
	var seed: int = MeshKit.hash_i(tone, 2, 82) % 997
	var wall: Color = _wall(tone + 1)
	var steel: Color = skin.steel_color.lightened(0.25)
	var concrete: Color = skin.slab_color.lerp(skin.ash_color, 0.3)
	var back_z: float = wall_z - 0.7
	_body(s, size, back_z, size.y - 1.0, wall.darkened(0.3))
	DashWallKit.face(s, size, -hx, hx, 0.0, FOOT, wall_z, wall, MeshKit.PAT_DZ_TOWER, MeshKit.dz_tower_param(style, seed), hx, 0.0)
	_ledge(s, size, wall_z, wall, rng)
	# The gutted rooms behind the frame: a charred, soot-black back wall with its own floor slabs.
	DashWallKit.box(s, size, -hx, hx, FOOT + LEDGE, size.y, -hz, back_z, wall.darkened(0.55), MeshKit.PAT_DZ_CONCRETE,
		MeshKit.FACE_PZ | MeshKit.FACE_PY | MeshKit.FACE_PX | MeshKit.FACE_NX, 0.0)
	# Floor slabs across the frame (the gutted storeys), some broken short.
	var slab_hs: Array[float] = [FOOT + LEDGE + 1.7, FOOT + LEDGE + 3.5]
	for h: float in slab_hs:
		var x0: float = -hx
		var x1: float = hx
		if rng.randf() < 0.5:
			if rng.randf() < 0.5:
				x0 += rng.randf_range(1.2, 3.0)
			else:
				x1 -= rng.randf_range(1.2, 3.0)
		DashWallKit.box(s, size, x0, x1, h, h + 0.3, back_z, wall_z + 0.18, concrete, MeshKit.PAT_DZ_CONCRETE,
			MeshKit.ALL_FACES & ~MeshKit.FACE_NZ, 0.0)
	# The steel columns: every bay, each broken off at its own height (the corners reach the top), with beams
	# between neighbours.
	var bay: float = (size.x - 0.8) / float(maxi(2, roundi((size.x - 0.8) / 3.0)))
	var columns: int = roundi((size.x - 0.8) / bay)
	var tops: Array[float] = []
	for k: int in columns + 1:
		var top: float = size.y if k == 0 or k == columns else rng.randf_range(TOP_MIN, size.y - 0.2)
		tops.append(top)
		var x: float = -hx + 0.4 + bay * float(k)
		DashWallKit.box(s, size, x - 0.2, x + 0.2, 0.0, top, wall_z - 0.1, wall_z + 0.3, steel, MeshKit.PAT_DZ_STEEL,
			MeshKit.ALL_FACES, 0.0)
	for k: int in columns:
		var x0: float = -hx + 0.4 + bay * float(k) + 0.2
		var x1: float = -hx + 0.4 + bay * float(k + 1) - 0.2
		for h: float in [FOOT + LEDGE + 1.75, FOOT + LEDGE + 3.55]:
			if h < minf(tops[k], tops[k + 1]) - 0.3 and rng.randf() < 0.85:
				DashWallKit.box(s, size, x0, x1, h - 0.1, h + 0.28, wall_z - 0.05, wall_z + 0.2, steel, MeshKit.PAT_DZ_STEEL,
					MeshKit.ALL_FACES, 0.0)
	_posts(s, size, wall_z, PackedFloat32Array())
	_foot_rubble(s, size, wall_z, rng, 9)
	_damage(s, size, wall_z, tone + 2, Vector4(-hx + 0.9, hx - 0.9, 0.9, FOOT - 0.4), wall)


## A blast: the gutted face under a broken top, a heap of rubble piled against its foot (a mound of broken
## chunks and slabs, highest in the middle, never tall enough to read as a lane's obstacle of its own).
func _blast(s: MeshLayer, size: Vector3, tone: int, rng: RandomNumberGenerator) -> void:
	var hx: float = size.x * 0.5
	var hz: float = size.z * 0.5
	var wall_z: float = hz - FACE_BACK
	var style: int = [1, 0, 3][tone % 3]
	var seed: int = MeshKit.hash_i(tone, 3, 83) % 997
	var param: float = MeshKit.dz_tower_param(style, seed)
	var wall: Color = _wall(tone + 2)
	var tops: PackedFloat32Array = _profile(size, rng, 3)
	_body(s, size, wall_z, TOP_MIN - 0.4, wall)
	DashWallKit.face(s, size, -hx, hx, 0.0, FOOT, wall_z, wall, MeshKit.PAT_DZ_TOWER, param, hx, 0.0)
	_windows(s, size, wall_z, tops, wall, style, param)
	_ledge(s, size, wall_z, wall, rng)
	_posts(s, size, wall_z, tops)
	# The heap against the foot: chunks of concrete of every size, a mound across the middle of the face.
	var count: int = 34
	for i: int in count:
		var u: float = rng.randf_range(-1.0, 1.0)
		var mound: float = 1.0 - u * u
		var cx: float = u * (hx - 0.9)
		var ch: float = rng.randf_range(0.0, 1.0) * (0.4 + 1.5 * mound)
		var dim := Vector3(rng.randf_range(0.5, 1.5), rng.randf_range(0.4, 0.9), rng.randf_range(0.5, 1.1))
		var cz: float = rng.randf_range(wall_z - 0.1, hz - dim.z * 0.5)
		_chunk(s, size, Vector3(cx, ch + dim.y * 0.5, cz), dim, rng, wall.lightened(rng.randf_range(0.0, 0.25)))
	_damage(s, size, wall_z, tone + 4, Vector4(-hx + 0.9, hx - 0.9, 3.0, TOP_MIN - 0.5), wall)


## A bunker block: charred precast concrete with form-board lines, rows of slit windows, a broken top with rebar
## standing out of it, a steel capping on one side.
func _bunker(s: MeshLayer, size: Vector3, tone: int, rng: RandomNumberGenerator) -> void:
	var hx: float = size.x * 0.5
	var hz: float = size.z * 0.5
	var wall_z: float = hz - FACE_BACK
	var concrete: Color = skin.slab_color.lerp(skin.ash_color, 0.45).lightened(0.04 * float(tone))
	var steel: Color = skin.steel_color.lightened(0.25)
	var dark: Color = skin.soot_color
	var top: float = size.y - 0.9
	_body(s, size, wall_z, top, concrete.darkened(0.1))
	DashWallKit.box(s, size, -hx, hx, 0.0, top, -hz, wall_z, concrete, MeshKit.PAT_DZ_CONCRETE, MeshKit.FACE_PZ, 0.0)
	# Slit windows in two rows, deep and black, each under a pale broken lintel.
	for row: int in 2:
		var h: float = 4.6 + 2.0 * float(row)
		var x: float = -hx + 1.3
		while x + 1.8 < hx - 0.9:
			if rng.randf() < 0.85:
				DashWallKit.box(s, size, x, x + 1.8, h, h + 0.5, wall_z - 0.2, wall_z + 0.02, dark, MeshKit.PAT_PLAIN, MeshKit.FACE_PZ)
				DashWallKit.box(s, size, x - 0.12, x + 1.92, h + 0.5, h + 0.68, wall_z - 0.05, wall_z + 0.18, concrete.lightened(0.15),
					MeshKit.PAT_DZ_CONCRETE, MeshKit.ALL_FACES & ~MeshKit.FACE_NZ, 0.0)
			x += 3.0
	# A heavy plinth and a broken parapet on top: the parapet is gone in places, rebar bent out of the breaks.
	DashWallKit.box(s, size, -hx, hx, 0.0, 0.9, wall_z - 0.1, hz, concrete.darkened(0.2), MeshKit.PAT_DZ_CONCRETE,
		MeshKit.ALL_FACES & ~MeshKit.FACE_NZ, 0.0)
	var x: float = -hx
	while x < hx - 0.01:
		var w: float = minf(rng.randf_range(1.0, 2.4), hx - x)
		var corner: bool = x <= -hx + 0.01 or x + w >= hx - 0.01
		if corner or rng.randf() < 0.65:
			var up: float = size.y if corner else top + rng.randf_range(0.25, 0.85)
			DashWallKit.box(s, size, x, x + w, top, up, wall_z - 0.5, hz, concrete.darkened(0.05), MeshKit.PAT_DZ_CONCRETE,
				MeshKit.ALL_FACES & ~MeshKit.FACE_NY, 0.0)
		else:
			for r: int in 2:
				var rx: float = x + w * (0.3 + 0.4 * float(r))
				var bend := Basis.from_euler(Vector3(rng.randf_range(-0.5, 0.3), 0.0, rng.randf_range(-0.4, 0.4))).scaled_local(
					Vector3(0.05, 0.9, 0.05))
				s.box_xform(Transform3D(bend, Vector3(rx, top - size.y * 0.5 + 0.4, wall_z - 0.3)), steel, 0.0, MeshKit.PAT_DZ_STEEL)
		x += w
	_posts(s, size, wall_z, PackedFloat32Array())
	_foot_rubble(s, size, wall_z, rng, 10)
	_damage(s, size, wall_z, tone + 6, Vector4(-hx + 0.9, hx - 0.9, 1.2, top - 0.4), concrete)


## The windows' storeys over the ledge, in strips to the broken top profile `tops` (one height per STEP across),
## the shader's window grid lined up so a storey starts at the ledge.
func _windows(s: MeshLayer, size: Vector3, z: float, tops: PackedFloat32Array, wall: Color, style: int, param: float) -> void:
	var from: float = FOOT + LEDGE
	DashWallKit.face_profile(s, size, tops, from, z, wall, MeshKit.PAT_DZ_TOWER, param, size.x * 0.5, STOREYS[style] * 3.0 - from)


## The broken ledge along the top of the cladding: concrete slabs standing out to the face, missing in places,
## rebar bent out of the breaks.
func _ledge(s: MeshLayer, size: Vector3, z: float, wall: Color, rng: RandomNumberGenerator) -> void:
	var hx: float = size.x * 0.5
	var hz: float = size.z * 0.5
	var concrete: Color = skin.slab_color.lerp(skin.ash_color, 0.3)
	var x: float = -hx
	while x < hx - 0.01:
		var w: float = minf(rng.randf_range(1.2, 2.6), hx - x)
		var corner: bool = x <= -hx + 0.01 or x + w >= hx - 0.01
		if corner or rng.randf() < 0.75:
			DashWallKit.box(s, size, x, x + w, FOOT, FOOT + LEDGE - rng.randf_range(0.0, 0.1), z - 0.05, hz - 0.02, concrete,
				MeshKit.PAT_DZ_CONCRETE, MeshKit.ALL_FACES, 0.0)
		else:
			var bend := Basis.from_euler(Vector3(rng.randf_range(-0.6, 0.2), 0.0, rng.randf_range(-0.4, 0.4))).scaled_local(
				Vector3(0.04, 0.8, 0.04))
			s.box_xform(Transform3D(bend, Vector3(x + w * 0.5, FOOT + 0.25 - size.y * 0.5, z + 0.1)), skin.steel_color.lightened(0.25), 0.0,
				MeshKit.PAT_DZ_STEEL)
		x += w


## Steel posts at both ends of the face, from the floor to the box's top: the frame's last columns standing
## against the broken wall (reach the face).
func _posts(s: MeshLayer, size: Vector3, z: float, _tops: PackedFloat32Array) -> void:
	var hx: float = size.x * 0.5
	var hz: float = size.z * 0.5
	for side: float in [-1.0, 1.0]:
		DashWallKit.box(s, size, minf(side * hx, side * (hx - 0.5)), maxf(side * hx, side * (hx - 0.5)), 0.0, size.y, z - 0.3, hz,
			skin.steel_color.lightened(0.3), MeshKit.PAT_DZ_STEEL, MeshKit.ALL_FACES & ~MeshKit.FACE_NY, 0.0)


## The block's body behind its face: its sides and top only, from the floor up to `top`, z from the back to `z`.
func _body(s: MeshLayer, size: Vector3, z: float, top: float, color: Color) -> void:
	var hx: float = size.x * 0.5
	var hz: float = size.z * 0.5
	DashWallKit.box(s, size, -hx, hx, 0.0, top, -hz, z, color, MeshKit.PAT_DZ_CONCRETE,
		MeshKit.FACE_PX | MeshKit.FACE_NX | MeshKit.FACE_PY, 0.0)


## A charred wall colour for a tone: the zone's cladding blacks and ash grey, dusted with the ash that lies on
## everything so it reads against the smoke and the dark walls beside it (it isn't a wall to run on).
func _wall(tone: int) -> Color:
	return skin.facade_colors[(tone * 2 + 2) % skin.facade_colors.size()].lerp(skin.ash_color, 0.85)


## The broken top's heights, one per STEP across (n + 1 points): the corners stand to the box's top, bites are
## blown out between them, and no point goes lower than TOP_MIN.
func _profile(size: Vector3, rng: RandomNumberGenerator, bites: int) -> PackedFloat32Array:
	return DashWallKit.broken_profile(size, rng, bites, TOP_MIN, STEP)


## Rubble lying along the foot of the face: `count` chunks of broken concrete, none over 0.6 m high, in front of the
## cladding (a ruin's own litter; the runner dashes through the wall, never over it).
func _foot_rubble(s: MeshLayer, size: Vector3, z: float, rng: RandomNumberGenerator, count: int) -> void:
	var hx: float = size.x * 0.5
	var hz: float = size.z * 0.5
	for i: int in count:
		var dim := Vector3(rng.randf_range(0.35, 0.9), rng.randf_range(0.25, 0.5), rng.randf_range(0.35, 0.8))
		var cx: float = rng.randf_range(-hx + 0.9 + dim.x * 0.5, hx - 0.9 - dim.x * 0.5)
		var cz: float = rng.randf_range(z + dim.z * 0.3, hz - dim.z * 0.5)
		_chunk(s, size, Vector3(cx, dim.y * 0.5, cz), dim, rng, _wall(i).darkened(rng.randf_range(0.0, 0.3)))


## A chunk of broken concrete at `at` (its centre, in the wall's space... y measured from the box's middle), `dim`
## across, turned at random.
func _chunk(s: MeshLayer, size: Vector3, at: Vector3, dim: Vector3, rng: RandomNumberGenerator, color: Color) -> void:
	var basis := Basis.from_euler(Vector3(rng.randf_range(-0.4, 0.4), rng.randf_range(-0.6, 0.6), rng.randf_range(-0.4, 0.4)))
	var xf := Transform3D(basis.scaled_local(dim), Vector3(at.x, at.y - size.y * 0.5, at.z))
	var inside: AABB = xf * AABB(Vector3(-0.5, -0.5, -0.5), Vector3.ONE)
	if inside.end.z > size.z * 0.5 or inside.position.y < -size.y * 0.5 or absf(at.x) + dim.x * 0.5 > size.x * 0.5:
		xf = Transform3D(Basis.from_scale(dim), Vector3(clampf(at.x, -size.x * 0.5 + dim.x * 0.5, size.x * 0.5 - dim.x * 0.5),
			maxf(at.y - size.y * 0.5, -size.y * 0.5 + dim.y * 0.5), minf(at.z, size.z * 0.5 - dim.z * 0.5)))
	s.box_xform(xf, color, 0.0, MeshKit.PAT_DZ_CONCRETE, MeshKit.ALL_FACES & ~MeshKit.FACE_NY, 2.0)


## What says "this breaks": cracks across the face from a few points, and a patch where the cladding has come away
## down to the bare concrete. `at` bounds both (x0, x1, h0, h1).
func _damage(s: MeshLayer, size: Vector3, z: float, seed: int, at: Vector4, wall: Color) -> void:
	DashWallKit.cracks(s, size, z, at, 2 + seed % 2, skin.soot_color, seed)
	var patch: float = 1.3
	var px: float = lerpf(at.x + patch, at.y - patch, MeshKit.hash01(seed, 5, 19))
	var py: float = lerpf(at.z + 0.1, maxf(at.z + 0.2, at.w - patch), MeshKit.hash01(seed, 6, 19))
	DashWallKit.spall(s, size, px - patch * 0.5, px + patch * 0.5, py, py + patch * 0.8, z, 0.12, skin.soot_color.lightened(0.12),
		skin.steel_color.lightened(0.35), MeshKit.PAT_DZ_CONCRETE, 0.0)
