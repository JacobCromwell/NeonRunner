class_name TerminalIntroHeap
extends RefCounted
## The rubble heap that blocks the station's entrance (TerminalIntroStation; the owner's beat: "the terminal's entrance,
## which is blocked by rubble, with a crack of light at the top"). A heightfield in the station's frame (x along the front,
## y up, z out from it): a plateau across the doorway rising to just under the lintel, so only a crack is left, spilling
## out onto the forecourt in a slope the runner can climb, and down a little on the inside. Drawn as flat-shaded
## quads in the Dead Zone's rubble (PAT_DZ_CONCRETE, a heap), with broken slabs and rebar sticking out of it at its
## sides (never along the runner's way up, which is smoothed: `height()` is what their feet follow).
## Visual only: no hitboxes. DESIGN-TBD (docs/questions/f2k.md): its shape.

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

var height_top: float
var length: float
var foot_width: float
var door_half: float
var seed_value: int = 2101


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
			var ha: float = height(xa, za)
			var hb: float = height(xa, zb)
			var hc: float = height(xb, zb)
			var hd: float = height(xb, za)
			if maxf(maxf(ha, hb), maxf(hc, hd)) < 0.02:
				continue
			var shade: float = 0.82 + 0.3 * MeshKit.hash01(i, j, seed_value)
			var c: Color = RUBBLE * shade
			# Seen from above (+y): the corners a (x low, z low), d (x high, z low), c, b clockwise from above.
			layer.quad(Vector3(xa, ha, za), Vector3(xb, hd, za), Vector3(xb, hc, zb), Vector3(xa, hb, zb), Color(c, 1.0), 0.0,
				MeshKit.PAT_DZ_CONCRETE, 2.0)


## Broken slabs, chunks and rebar on the heap's flanks (not on the way up or the crest).
func build_chunks(layer: MeshLayer) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var placed: int = 0
	var tries: int = 0
	while placed < 90 and tries < 700:
		tries += 1
		var z: float = rng.randf_range(-0.8, length - 0.5)
		var half: float = lerpf(door_half, foot_width * 0.5, clampf(z / length, 0.0, 1.0))
		var x: float = rng.randf_range(-half - 0.8, half + 0.8)
		if absf(x - way_x(z)) < WAY_HALF + 0.5 or (z < 1.0 and absf(x) < door_half - 0.3 and z > -1.0):
			continue
		var h: float = height(x, z)
		var size := Vector3(rng.randf_range(0.18, 0.7), rng.randf_range(0.1, 0.4), rng.randf_range(0.18, 0.65))
		var basis := Basis.from_euler(Vector3(rng.randf_range(-0.5, 0.5), rng.randf_range(-PI, PI), rng.randf_range(-0.5, 0.5)))
		var shade: float = rng.randf_range(0.7, 1.2)
		layer.box_xform(Transform3D(basis * Basis.from_scale(size), Vector3(x, h + size.y * 0.15, z)),
			(RUBBLE if rng.randf() < 0.65 else RUBBLE_DARK) * shade, 0.0, MeshKit.PAT_DZ_CONCRETE, MeshKit.ALL_FACES, 0.0)
		placed += 1
	# Rebar bristling from the heap's sides, bent.
	for k: int in 14:
		var z: float = rng.randf_range(0.5, length * 0.7)
		var side: float = -1.0 if rng.randf() < 0.5 else 1.0
		var half: float = lerpf(door_half, foot_width * 0.5, clampf(z / length, 0.0, 1.0))
		var x: float = side * (half - rng.randf_range(0.6, 2.0))
		var h: float = height(x, z)
		var rod: float = rng.randf_range(0.9, 2.0)
		var lean := Basis.from_euler(Vector3(rng.randf_range(-0.7, 0.7), rng.randf_range(-PI, PI), rng.randf_range(-0.7, 0.7)))
		layer.prism_xform(Transform3D(lean * Basis.from_scale(Vector3(0.03, rod, 0.03)), Vector3(x, h - 0.1, z)), 4, REBAR, 0.0,
			MeshKit.PAT_DZ_STEEL, false, 0.0)
