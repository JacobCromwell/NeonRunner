class_name TerminalIntroHeap
extends RefCounted
## The rubble heap that blocks the station's entrance (TerminalIntroStation; the owner's beat: "the terminal's entrance,
## which is blocked by rubble, with a crack of light at the top"). A heightfield in the station's frame (x along the front,
## y up, z out from it): a plateau across the doorway rising to just under the lintel, so only a crack is left, spilling
## out onto the forecourt in a slope the runner can climb, and down a little on the inside. Drawn as flat-shaded
## quads in the Dead Zone's rubble (PAT_DZ_CONCRETE, a heap), with broken slabs and rebar sticking out of it at its
## sides (never along the runner's way up, which is smoothed: `height()` is what their feet follow).
## Visual only: no hitboxes. DESIGN-TBD (docs/OPEN_QUESTIONS_DEFERRED.md items 1102-1115): its shape.

const CELL: float = 0.5
const RUBBLE: Color = Color(0.34, 0.33, 0.32)
const RUBBLE_DARK: Color = Color(0.2, 0.195, 0.19)
const REBAR: Color = Color(0.22, 0.14, 0.1)
## The runner's way up: x at the foot and at the top, the slope's half width kept smooth (lumps fade in beyond it).
const WAY_FOOT_X: float = 1.5
const WAY_TOP_X: float = 0.3
const WAY_HALF: float = 1.3
## How far inside the doorway the heap's crest holds, and where it has dropped to the foyer's floor.
const CREST_BACK: float = -1.4
const INSIDE_END: float = -5.5
## How far a piece's footprint stays from a path kept clear (metres, on top of the runner's own width).
const CLEAR_WIDTH: float = 0.6

var height_top: float
var length: float
var foot_width: float
var door_half: float
var seed_value: int = 2101
## Paths on foot (x, z of this frame) kept clear of the slabs and chunks: a piece whose footprint comes within CLEAR_WIDTH of one is left
## out, so a runner never walks through a block of the heap (set before `build_chunks`).
var keep_clear: Array[PackedVector2Array] = []
## Every slab and chunk placed by `build_chunks`: its place and turn (the box's transform without its size) and its half size, for tests.
var pieces: Array[Dictionary] = []


func _init(p_height: float, p_length: float, p_foot_width: float, p_door_width: float) -> void:
	height_top = p_height
	length = p_length
	foot_width = p_foot_width
	door_half = p_door_width * 0.5


## The way up's centre line at distance `z` out from the front (x).
func way_x(z: float) -> float:
	return lerpf(WAY_TOP_X, WAY_FOOT_X, clampf(z / length, 0.0, 1.0))


## The heap's height at (x, z): 0 off it.
func height(x: float, z: float) -> float:
	if z > length or z < INSIDE_END:
		return 0.0
	# Along it: the crest across the doorway and a bit inside, then down the outside slope (a ramp eased at its ends) and
	# down the inside to the foyer's floor.
	var along: float
	if z >= 0.0:
		var u: float = clampf(z / length, 0.0, 1.0)
		along = 1.0 - lerpf(u, smoothstep(0.0, 1.0, u), 0.5)
	elif z >= CREST_BACK:
		along = 1.0
	else:
		along = 1.0 - smoothstep(CREST_BACK, INSIDE_END, z)
	# Across it: full across the doorway and its jambs (so only the crack is left), then spilling out wider to its foot.
	var u: float = clampf(z / length, 0.0, 1.0) if z >= 0.0 else 0.0
	var half: float = door_half + 0.15 + (foot_width * 0.5 - door_half - 0.15) * pow(u, 0.8)
	var fall: float = 0.3 + 2.4 * u
	var across: float = 1.0 - smoothstep(half - fall, half, absf(x))
	var h: float = height_top * along * across
	# Lumps, gone at the foot and the crest and smoothed along the runner's way up.
	var near_way: float = smoothstep(WAY_HALF, WAY_HALF + 1.4, absf(x - way_x(z)))
	var lump: float = 0.28 * sin(x * 1.7 + z * 0.9) + 0.18 * sin(x * 3.1 - z * 2.3 + 1.0)
	h += near_way * across * 4.0 * along * (1.0 - along) * lump
	return maxf(h, 0.0)


## A grid point of the drawn surface: the heap's height there, the point jittered (so the facets are broken and uneven, not a
## regular grid: the kit's rubble pattern alone reads as paving) everywhere but along the runner's way up, whose surface is what
## their feet follow (`height()`), and never far above it (the camera keeps over `height()`).
func _surface_point(i: int, j: int, x: float, z: float) -> Vector3:
	var h: float = height(x, z)
	if h < 0.02:
		return Vector3(x, h, z)
	var rough: float = smoothstep(WAY_HALF, WAY_HALF + 1.2, absf(x - way_x(z))) * smoothstep(0.1, 0.6, h)
	var jx: float = (MeshKit.hash01(i, j, seed_value + 1) - 0.5) * CELL * 0.55 * rough
	var jz: float = (MeshKit.hash01(i, j, seed_value + 2) - 0.5) * CELL * 0.55 * rough
	var jy: float = (MeshKit.hash01(i, j, seed_value + 3) * 0.2 - 0.12) * rough * (0.6 + 0.8 * MeshKit.hash01(i / 3, j / 3, seed_value + 4))
	return Vector3(x + jx, h + jy, z + jz)


## The heap as quads on `layer` (the kit's solid material), plus the slabs and rebar in `chunks`.
func build(layer: MeshLayer) -> void:
	var x0: float = -foot_width * 0.5 - 2.0
	var x1: float = foot_width * 0.5 + 2.0
	var nx: int = ceili((x1 - x0) / CELL)
	var nz: int = ceili((length - INSIDE_END) / CELL)
	for i: int in nx:
		for j: int in nz:
			var xa: float = x0 + float(i) * CELL
			var xb: float = xa + CELL
			var za: float = INSIDE_END + float(j) * CELL
			var zb: float = za + CELL
			var pa: Vector3 = _surface_point(i, j, xa, za)
			var pb: Vector3 = _surface_point(i, j + 1, xa, zb)
			var pc: Vector3 = _surface_point(i + 1, j + 1, xb, zb)
			var pd: Vector3 = _surface_point(i + 1, j, xb, za)
			if maxf(maxf(pa.y, pb.y), maxf(pc.y, pd.y)) < 0.02:
				continue
			# Patches of darker and paler rubble, not a tone per quad alone.
			var patch: float = 0.8 + 0.5 * MeshKit.hash01(i / 2, j / 2, seed_value + 9)
			var shade: float = patch * (0.75 + 0.45 * MeshKit.hash01(i, j, seed_value))
			var c: Color = RUBBLE * shade
			# Seen from above (+y): the corners a (x low, z low), d (x high, z low), c, b clockwise from above.
			layer.quad(pa, pd, pc, pb, Color(c, 1.0), 0.0, MeshKit.PAT_DZ_CONCRETE, 2.0)


## Broken slabs, chunks and rebar on the heap's flanks (not on the way up or the crest).
func build_chunks(layer: MeshLayer) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var placed: int = 0
	var tries: int = 0
	while placed < 230 and tries < 1800:
		tries += 1
		var z: float = rng.randf_range(-0.8, length - 0.5)
		var half: float = lerpf(door_half, foot_width * 0.5, clampf(z / length, 0.0, 1.0))
		var x: float = rng.randf_range(-half - 0.8, half + 0.8)
		if absf(x - way_x(z)) < WAY_HALF + 0.5 or (z < 1.0 and absf(x) < door_half - 0.3 and z > -1.0):
			continue
		var h: float = height(x, z)
		# Small chunks, and a quarter of them big broken slabs, many tipped up out of the heap (a ragged outline).
		var slab: bool = rng.randf() < 0.25
		var size := Vector3(rng.randf_range(0.18, 0.7), rng.randf_range(0.1, 0.4), rng.randf_range(0.18, 0.65))
		var tilt: float = 0.5
		if slab:
			size = Vector3(rng.randf_range(0.7, 1.7), rng.randf_range(0.12, 0.3), rng.randf_range(0.5, 1.2))
			tilt = 0.95
		var basis := Basis.from_euler(Vector3(rng.randf_range(-tilt, tilt), rng.randf_range(-PI, PI), rng.randf_range(-tilt, tilt)))
		var shade: float = rng.randf_range(0.6, 1.3)
		var pale: bool = rng.randf() < 0.6
		placed += 1
		# Every draw above is made whether the piece stays or not, so the rest of the heap is the same as it was.
		if _blocks_path(x, z, size.length() * 0.5):
			continue
		var at := Vector3(x, h + size.y * (0.1 if not slab else 0.35), z)
		pieces.append({"xform": Transform3D(basis, at), "half": size * 0.5})
		layer.box_xform(Transform3D(basis * Basis.from_scale(size), at), (RUBBLE if pale else RUBBLE_DARK) * shade, 0.0,
			MeshKit.PAT_DZ_CONCRETE, MeshKit.ALL_FACES, 0.0)
	# Small stones strewn over the way up too (flat and low, a few centimetres: their feet follow `height()`, not them), so that the
	# runner's smooth path does not read as paving.
	for k: int in 70:
		var z: float = rng.randf_range(0.2, length - 0.2)
		var x: float = way_x(z) + rng.randf_range(-1.5, 1.5)
		var h: float = height(x, z)
		if h < 0.05:
			continue
		var size := Vector3(rng.randf_range(0.12, 0.4), rng.randf_range(0.05, 0.1), rng.randf_range(0.12, 0.35))
		var basis := Basis.from_euler(Vector3(rng.randf_range(-0.25, 0.25), rng.randf_range(-PI, PI), rng.randf_range(-0.25, 0.25)))
		layer.box_xform(Transform3D(basis * Basis.from_scale(size), Vector3(x, h + 0.01, z)),
			(RUBBLE if rng.randf() < 0.5 else RUBBLE_DARK) * rng.randf_range(0.7, 1.3), 0.0, MeshKit.PAT_DZ_CONCRETE, MeshKit.ALL_FACES, 0.0)
	# Rebar bristling from the heap's sides, bent.
	for k: int in 28:
		var z: float = rng.randf_range(0.3, length * 0.8)
		var side: float = -1.0 if rng.randf() < 0.5 else 1.0
		var half: float = lerpf(door_half, foot_width * 0.5, clampf(z / length, 0.0, 1.0))
		var x: float = side * (half - rng.randf_range(0.6, 2.0))
		var h: float = height(x, z)
		var rod: float = rng.randf_range(0.9, 2.8)
		var lean := Basis.from_euler(Vector3(rng.randf_range(-0.7, 0.7), rng.randf_range(-PI, PI), rng.randf_range(-0.7, 0.7)))
		layer.prism_xform(Transform3D(lean * Basis.from_scale(Vector3(0.03, rod, 0.03)), Vector3(x, h - 0.1, z)), 4, REBAR, 0.0,
			MeshKit.PAT_DZ_STEEL, false, 0.0)


## True if a piece of rubble whose footprint reaches `radius` from (x, z) comes within CLEAR_WIDTH of a path kept clear.
func _blocks_path(x: float, z: float, radius: float) -> bool:
	for path: PackedVector2Array in keep_clear:
		for i: int in range(path.size() - 1):
			if _segment_distance(Vector2(x, z), path[i], path[i + 1]) < radius + CLEAR_WIDTH:
				return true
	return false


static func _segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var t: float = clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


## How far the point `p` (this frame) is from the nearest slab or chunk of the heap (0 inside one): the pieces as boxes, so a runner's
## body can be held against them (after `build_chunks`).
func clearance(p: Vector3) -> float:
	var nearest: float = INF
	for piece: Dictionary in pieces:
		var local: Vector3 = (piece["xform"] as Transform3D).affine_inverse() * p
		var half: Vector3 = piece["half"]
		var out := Vector3(maxf(absf(local.x) - half.x, 0.0), maxf(absf(local.y) - half.y, 0.0), maxf(absf(local.z) - half.z, 0.0))
		nearest = minf(nearest, out.length())
	return nearest
