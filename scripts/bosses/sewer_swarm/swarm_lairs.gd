class_name SwarmLairs
extends Node3D
## The arena's manholes and wall vents (GDD §10, the Rising: "manholes and wall vents shake all along both
## sides, and screeches pour out and merge into clusters at the roadside"; GDD §9.5: in Gangland a manhole
## or a vent is a screech's lair, so these are the only ones). Scenery: nothing here touches the runner.
## A lair every `spacing` metres, sides in turn, a manhole at the street's edge (clear of the outer lane's
## runner) or a vent at the wall's foot, each side alternating; none over a hole or by a fence. All the
## manholes in sight are one MultiMesh and all the vents another (two draws, whatever their number), each
## instance reused as the runner passes its lair, drawn like the screech's lair (ScreechLair) and animated in
## swarm_lair.gdshader from its instance's custom data (rattle, open). A lair rattles, its slots glowing
## brighter, as the runner nears it, then bursts open and its screeches pour out (`burst`, for SwarmHorde's
## spill). At the fight's start every lair in sight bursts over its first seconds, and every lair seen
## during the Rising (`rising_seconds`) bursts as the runner nears; after that only `share` of them do.
## Only the look: driven from _process, never from the fight's clock or its rules.

## A lair burst open at world position `at`, on `side` (-1 left, +1 right): its screeches pour out.
signal burst(at: Vector3, side: int)

enum Kind { MANHOLE, VENT }

const SHADER: Shader = preload("res://scripts/bosses/sewer_swarm/swarm_lair.gdshader")
## The rattle before a timed burst (the fight's start), and how long a lid takes to fly.
const RATTLE_SECONDS: float = 0.7
const OPEN_SECONDS: float = 0.6
## A manhole's middle stands this far out from the wall (its cover is MANHOLE_RADIUS across).
const MANHOLE_OUT: float = 0.5
const MANHOLE_RADIUS: float = 0.44

static var _meshes: Dictionary = {}

var spacing: float = 9.0
var ahead: float = 150.0
var behind: float = 15.0
var rattle_ahead: float = 95.0
var burst_ahead: float = 75.0
var share: float = 0.4
var rising_seconds: float = 5.0
## Metres the runner covers while a lid flies (its speed times OPEN_SECONDS).
var open_metres: float = 11.0
var wall_x: float = 4.0
## Seconds since the fight's start (the look's own clock).
var clock: float = 0.0
## Where the runner was when the lairs were set up (the lairs in sight then burst on a timer).
var start_d: float = 0.0
## Asked before a lair goes at a spot: true if its side's street edge (a manhole's floor) is whole there.
var floor_ok: Callable = Callable()
var manholes: MultiMeshInstance3D
var vents: MultiMeshInstance3D

var _per_kind: int = 12
var _seed: int = 0
## Per kind, the lair each instance shows (-1 none), whether that lair was left out (a manhole over a hole
## or by a fence: the instance is hidden), and its custom data as last sent.
var _shown: Array[PackedInt32Array] = [PackedInt32Array(), PackedInt32Array()]
var _left_out: Array[PackedByteArray] = [PackedByteArray(), PackedByteArray()]
var _sent: Array[PackedColorArray] = [PackedColorArray(), PackedColorArray()]
## Lairs seen so far: index -> {bursts, timed (clock of its burst, or -1), spilled}.
var _seen: Dictionary = {}


## Builds the two MultiMeshes for a street whose walls stand `p_wall_x` from its middle.
func setup(p_wall_x: float, t: SewerSwarmTuning, run_speed: float, p_start_d: float, seed_value: int) -> void:
	wall_x = p_wall_x
	spacing = t.lair_spacing
	rattle_ahead = t.rattle_ahead
	burst_ahead = t.burst_ahead
	share = t.lair_burst_share
	rising_seconds = t.horde_fill_seconds
	ahead = maxf(rattle_ahead + 20.0, t.horde_ahead + 20.0)
	open_metres = run_speed * OPEN_SECONDS
	start_d = p_start_d
	_seed = seed_value
	_per_kind = int(ceil((ahead + behind) / (spacing * 2.0))) + 3
	manholes = _make(Kind.MANHOLE)
	vents = _make(Kind.VENT)


func _make(kind: Kind) -> MultiMeshInstance3D:
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Manholes" if kind == Kind.MANHOLE else "Vents"
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter(&"kind", int(kind))
	mmi.material_override = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh(kind)
	mm.instance_count = _per_kind
	var hidden := Transform3D(Basis.IDENTITY, Vector3(0.0, -100.0, 0.0))
	var shown := PackedInt32Array()
	var left_out := PackedByteArray()
	var sent := PackedColorArray()
	for i: int in _per_kind:
		mm.set_instance_transform(i, hidden)
		mm.set_instance_custom_data(i, Color(0.0, 0.0, 0.0, float(i) * 0.37))
		shown.append(-1)
		left_out.append(0)
		sent.append(Color(0.0, 0.0, 0.0, float(i) * 0.37))
	mmi.multimesh = mm
	# The lids fly a metre or two from their places.
	mmi.extra_cull_margin = 2.5
	add_child(mmi)
	_shown[kind] = shown
	_left_out[kind] = left_out
	_sent[kind] = sent
	return mmi


## The track distance of lair `j`.
func lair_at(j: int) -> float:
	return (float(j) + 0.5 + (_hash(j, 1) - 0.5) * 0.5) * spacing


## Lair `j`'s side and kind: sides in turn, each side alternating manholes and vents.
static func side_of(j: int) -> int:
	return -1 if posmod(j, 2) == 0 else 1


static func kind_of(j: int) -> Kind:
	return Kind.MANHOLE if posmod(floori(j / 2.0), 2) == 0 else Kind.VENT


## Where lair `j` stands in the world: a manhole's middle on the street, a vent's foot at its wall.
func place_of(j: int) -> Vector3:
	var side: int = side_of(j)
	var x: float = side * (wall_x - MANHOLE_OUT) if kind_of(j) == Kind.MANHOLE else side * wall_x
	return Vector3(x, 0.0, TrackGeometry.world_z(lair_at(j)))


## Where its screeches come out: over a manhole, or out of a vent's opening.
func spill_point(j: int) -> Vector3:
	var p: Vector3 = place_of(j)
	if kind_of(j) == Kind.VENT:
		p += Vector3(-side_of(j) * 0.12, 0.12, 0.0)
	return p


## Moves the lairs on with the runner (at track distance `runner_d`) and steps their look `delta` on.
func update(runner_d: float, delta: float) -> void:
	clock += delta
	var j0: int = floori((runner_d - behind) / spacing) - 1
	var j1: int = ceili((runner_d + ahead) / spacing) + 1
	var wanted: Array[Dictionary] = [{}, {}]
	for j: int in range(j0, j1 + 1):
		var d: float = lair_at(j)
		if d < runner_d - behind or d > runner_d + ahead or d < 0.0:
			continue
		var kind: Kind = kind_of(j)
		wanted[kind][_instance(j)] = j
	for kind: int in 2:
		var mm: MultiMesh = (manholes if kind == Kind.MANHOLE else vents).multimesh
		for i: int in _per_kind:
			var j: int = int(wanted[kind].get(i, -1))
			if j != _shown[kind][i]:
				_shown[kind][i] = j
				_left_out[kind][i] = 0 if _assign(mm, kind, i, j) else 1
			if j >= 0 and _left_out[kind][i] == 0:
				_animate(mm, kind, i, j, runner_d)
	# Forget lairs long passed.
	if _seen.size() > _per_kind * 6:
		for key: Variant in _seen.keys():
			if int(key) < j0 - 2:
				_seen.erase(key)


## Lairs shown now (tests).
func shown_count() -> int:
	var n: int = 0
	for kind: int in 2:
		for i: int in _per_kind:
			n += 1 if _shown[kind][i] >= 0 and _left_out[kind][i] == 0 else 0
	return n


func _instance(j: int) -> int:
	# The kind's own count of lairs before this one (each pair of lairs, one a side, alternates kinds).
	var pair: int = floori(j / 2.0)
	return posmod(floori(pair / 2.0) * 2 + posmod(j, 2), _per_kind)


## Puts instance `i` at lair `j` (none: hidden). False if the lair is left out (a manhole whose street edge
## isn't whole there).
func _assign(mm: MultiMesh, kind: int, i: int, j: int) -> bool:
	if j < 0 or (floor_ok.is_valid() and kind == Kind.MANHOLE and not bool(floor_ok.call(side_of(j), lair_at(j)))):
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(0.0, -100.0, 0.0)))
		return j < 0
	var basis := Basis(Vector3.UP, (_hash(j, 2) - 0.5) * 1.2) if kind == Kind.MANHOLE \
		else (Basis.IDENTITY if side_of(j) > 0 else Basis(Vector3.UP, PI))
	mm.set_instance_transform(i, Transform3D(basis, place_of(j)))
	return true


func _animate(mm: MultiMesh, kind: int, i: int, j: int, runner_d: float) -> void:
	var st: Dictionary = _seen.get(j, {})
	if st.is_empty():
		var rel0: float = lair_at(j) - runner_d
		var rising: bool = clock < rising_seconds
		st = {"bursts": rising or _hash(j, 3) < share, "timed": -1.0, "spilled": false}
		if clock < 0.5 and rel0 <= burst_ahead:
			# In sight at the fight's start: it bursts on a timer over the first seconds.
			st["timed"] = 0.4 + _hash(j, 4) * minf(rising_seconds * 0.6, 3.0)
		_seen[j] = st
	var rattle: float = 0.0
	var open: float = 0.0
	if float(st["timed"]) >= 0.0:
		var at: float = float(st["timed"])
		rattle = 1.0 if clock >= at - RATTLE_SECONDS and clock < at else 0.0
		open = clampf((clock - at) / OPEN_SECONDS, 0.0, 1.0)
	elif bool(st["bursts"]):
		var rel: float = lair_at(j) - runner_d
		rattle = 1.0 if rel > burst_ahead and rel <= rattle_ahead else 0.0
		open = clampf((burst_ahead - rel) / maxf(open_metres, 0.1), 0.0, 1.0)
	if open > 0.0 and not bool(st["spilled"]):
		st["spilled"] = true
		burst.emit(spill_point(j), side_of(j))
	var custom := Color(rattle, snappedf(open, 0.01), 0.0, _sent[kind][i].a)
	if custom != _sent[kind][i]:
		_sent[kind][i] = custom
		mm.set_instance_custom_data(i, custom)


func _hash(j: int, k: int) -> float:
	return float(posmod(hash([_seed, j, k]), 10007)) / 10007.0


# --- The meshes ----------------------------------------------------------------------------------

## A lair's mesh (built once): UV.x its part (0 still, 1 the lid), vertex colours albedo and glow (alpha).
static func mesh(kind: Kind) -> ArrayMesh:
	var key: int = int(kind)
	if _meshes.has(key):
		return _meshes[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rust := Color(0.3, 0.2, 0.13, 0.0)
	var dark := Color(0.006, 0.006, 0.005, 0.0)
	var rim := Color(0.06, 0.055, 0.05, 0.0)
	var eye := Color(ScreechLair.EYE_GLOW, 1.0)
	if kind == Kind.MANHOLE:
		_add(st, _disc(MANHOLE_RADIUS + 0.06, 0.01), Transform3D(Basis.IDENTITY, Vector3(0.0, 0.005, 0.0)), rim, 0)
		_add(st, _disc(MANHOLE_RADIUS - 0.02, 0.006), Transform3D(Basis.IDENTITY, Vector3(0.0, 0.012, 0.0)), dark, 0)
		# The cover with its raised cross, and four slots glowing with the eyes behind them.
		_add(st, _disc(MANHOLE_RADIUS - 0.03, 0.04), Transform3D(Basis.IDENTITY, Vector3(0.0, 0.035, 0.0)), rust, 1)
		_add(st, _box(), Transform3D(Basis.from_scale(Vector3(0.72, 0.012, 0.05)), Vector3(0.0, 0.061, 0.0)), rust, 1)
		_add(st, _box(), Transform3D(Basis.from_scale(Vector3(0.05, 0.012, 0.72)), Vector3(0.0, 0.061, 0.0)), rust, 1)
		for s: int in 4:
			var a: float = TAU * (float(s) + 0.5) / 4.0
			_add(st, _box(), Transform3D(Basis(Vector3.UP, a) * Basis.from_scale(Vector3(0.16, 0.006, 0.045)),
				Vector3(sin(a) * 0.22, 0.058, cos(a) * 0.22)), eye, 1)
	else:
		# Built for the right wall: its face at x = 0, the street toward -x.
		_add(st, _box(), Transform3D(Basis.from_scale(Vector3(0.06, 0.68, 1.16)), Vector3(-0.03, 0.35, 0.0)), rust, 0)
		_add(st, _box(), Transform3D(Basis.from_scale(Vector3(0.012, 0.54, 1.0)), Vector3(-0.064, 0.35, 0.0)), dark, 0)
		for z: float in [-0.13, 0.13]:
			_add(st, _box(), Transform3D(Basis.from_scale(Vector3(0.006, 0.05, 0.09)), Vector3(-0.072, 0.3, z)), eye, 0)
		for b: int in 5:
			_add(st, _box(), Transform3D(Basis.from_scale(Vector3(0.025, 0.045, 1.0)), Vector3(-0.09, 0.15 + b * 0.1, 0.0)), rust, 1)
		for z: float in [-0.35, 0.0, 0.35]:
			_add(st, _box(), Transform3D(Basis.from_scale(Vector3(0.02, 0.5, 0.035)), Vector3(-0.078, 0.35, z)), rust, 1)
	st.generate_normals()
	var out: ArrayMesh = st.commit()
	_meshes[key] = out
	return out


static func _add(st: SurfaceTool, prim: PrimitiveMesh, xform: Transform3D, color: Color, part: int) -> void:
	var arrays: Array = prim.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for idx: int in indices:
		st.set_color(color)
		st.set_uv(Vector2(float(part), 0.0))
		st.add_vertex(xform * verts[idx])


static func _disc(radius: float, height: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius
	m.height = height
	m.radial_segments = 14
	m.rings = 1
	return m


static func _box() -> BoxMesh:
	return BoxMesh.new()
