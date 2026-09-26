class_name MeshKit
extends RefCounted
## Shared building blocks for zone skins: deterministic hashing, cached unit templates, the kit
## shaders and their materials, and the hazard parts every zone must draw the same way
## (pink crackling energy field = electric fence, yellow/black striped frame = sign).
## Build geometry into a MeshBatch (one surface per material) and commit it as one node.

## Box sides for MeshLayer.box(faces = ...). Skip sides nobody can see.
const FACE_PX: int = 1
const FACE_NX: int = 2
const FACE_PY: int = 4
const FACE_NY: int = 8
const FACE_PZ: int = 16
const FACE_NZ: int = 32
const ALL_FACES: int = 63
## Every side but the bottom: things standing on a floor.
const NO_BOTTOM: int = ALL_FACES & ~FACE_NY

## Surface patterns of the solid kit shader (UV2.x). Patterns use world position, so they line up
## across meshes and chunk cuts; GLYPHS uses UV (metres on the panel).
const PAT_PLAIN: int = 0
const PAT_ROOF: int = 1      ## Transverse panel seams (param: seam offset in metres).
const PAT_RIBS: int = 2      ## Vertical corrugation along the track.
const PAT_STRIPES: int = 3   ## Hazard stripes: colour and black diagonals; the colour glows.
const PAT_GLASS: int = 4     ## Dark glass that catches the sky.
const PAT_HULL: int = 5      ## Hull plating: panel lines and tone variation.
const PAT_CHECKER: int = 6   ## Finish-line checkers; the light squares glow.
const PAT_GRILLE: int = 7    ## Horizontal slats.
const PAT_GLYPHS: int = 8    ## Neon glyph rows on a dark panel (param: scroll speed in m/s).
const PAT_CHEVRON: int = 9   ## Scrolling arrows along UV.x (0–1 over the face), param ±1 = direction.

## Shapes of the additive glow shader (UV2.x); UV runs 0–1 over the card.
const SHAPE_FLAT: int = 0    ## Even glow with soft edges.
const SHAPE_RADIAL: int = 1  ## Round halo.
const SHAPE_BEAM: int = 2    ## Bright at v = 0, fading to v = 1, soft sides.
const SHAPE_RISE: int = 3    ## Light column: bright at the base, bands rising.
const SHAPE_STREAK: int = 4  ## Soft horizontal streak.

const SHADER_DIR: String = "res://scripts/world/meshes/shaders/"

static var _templates: Dictionary = {}
static var _shaders: Dictionary = {}
static var _materials: Dictionary = {}


# --- Deterministic hashing ---------------------------------------------------
# Variety comes from hashing track positions, never from a global RNG, so every chunk looks the
# same however and whenever it is built. 32-bit integer mixing (no overflow in 64-bit ints).

static func hash_i(a: int, b: int = 0, c: int = 0) -> int:
	var h: int = (a * 0x27d4eb2d) & 0xFFFFFFFF
	h ^= (b * 0x165667b1 + 0x3c6ef372) & 0xFFFFFFFF
	h ^= (c * 0x1b873593 + 0x68e31da4) & 0xFFFFFFFF
	h = ((h ^ (h >> 15)) * 0x2c1b3c6d) & 0xFFFFFFFF
	h = ((h ^ (h >> 12)) * 0x297a2d39) & 0xFFFFFFFF
	return h ^ (h >> 15)


## A deterministic value in [0, 1).
static func hash01(a: int, b: int = 0, c: int = 0) -> float:
	return float(hash_i(a, b, c) & 0xFFFFFF) / 16777216.0


## Picks one entry of `values` by hash.
static func pick(values: Array, a: int, b: int = 0, c: int = 0) -> Variant:
	return values[hash_i(a, b, c) % values.size()]


## A stable integer key for a track distance or a position (to hash on), at centimetre precision.
static func key(value: float) -> int:
	return roundi(value * 100.0)


# --- Unit templates ------------------------------------------------------------

## A 1 m box centred on the origin with the sides in `faces`, UVs 0–1 per side.
static func unit_box(faces: int = ALL_FACES) -> MeshLayer:
	var id: String = "box_%d" % faces
	if _templates.has(id):
		return _templates[id]
	var t := MeshLayer.new()
	var h: float = 0.5
	if faces & FACE_PX:
		t.rect(Vector3(h, -h, h), Vector3(0, 0, -1), Vector3(0, 1, 0), Color.WHITE)
	if faces & FACE_NX:
		t.rect(Vector3(-h, -h, -h), Vector3(0, 0, 1), Vector3(0, 1, 0), Color.WHITE)
	if faces & FACE_PY:
		t.rect(Vector3(-h, h, h), Vector3(1, 0, 0), Vector3(0, 0, -1), Color.WHITE)
	if faces & FACE_NY:
		t.rect(Vector3(-h, -h, -h), Vector3(1, 0, 0), Vector3(0, 0, 1), Color.WHITE)
	if faces & FACE_PZ:
		t.rect(Vector3(-h, -h, h), Vector3(1, 0, 0), Vector3(0, 1, 0), Color.WHITE)
	if faces & FACE_NZ:
		t.rect(Vector3(h, -h, -h), Vector3(-1, 0, 0), Vector3(0, 1, 0), Color.WHITE)
	_templates[id] = t
	return t


## An upright prism with corner radius 1 from y = 0 to y = 1, flat-shaded sides.
static func unit_prism(sides: int, caps: bool = true) -> MeshLayer:
	var id: String = "prism_%d_%s" % [sides, caps]
	if _templates.has(id):
		return _templates[id]
	var t := MeshLayer.new()
	var ring: Array[Vector3] = []
	for i: int in sides:
		var a: float = TAU * (float(i) + 0.5) / float(sides)
		ring.append(Vector3(cos(a), 0.0, sin(a)))
	for i: int in sides:
		var p0: Vector3 = ring[i]
		var p1: Vector3 = ring[(i + 1) % sides]
		t.rect(p1, p0 - p1, Vector3.UP, Color.WHITE, 0.0, 0, Vector2(float(i) / sides, 0.0), Vector2(float(i + 1) / sides, 1.0))
	if caps:
		for i: int in sides:
			var p0: Vector3 = ring[i]
			var p1: Vector3 = ring[(i + 1) % sides]
			_triangle(t, Vector3.UP, p0 + Vector3.UP, p1 + Vector3.UP)
			_triangle(t, Vector3.ZERO, p1, p0)
	_templates[id] = t
	return t


static func _triangle(t: MeshLayer, a: Vector3, b: Vector3, c: Vector3) -> void:
	t.verts.append_array(PackedVector3Array([a, b, c]))
	t.colors.append_array(PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE]))
	t.uvs.append_array(PackedVector2Array([Vector2(0.5, 0.5), Vector2(0, 0), Vector2(1, 0)]))
	t.uv2s.append_array(PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]))


## `count` copies of one colour.
static func filled_colors(color: Color, count: int) -> PackedColorArray:
	var out := PackedColorArray()
	out.resize(count)
	out.fill(color)
	return out


static func filled_uv2(value: Vector2, count: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(count)
	out.fill(value)
	return out


# --- Shaders and materials -----------------------------------------------------

static func shader(file_name: String) -> Shader:
	if not _shaders.has(file_name):
		_shaders[file_name] = load(SHADER_DIR + file_name) as Shader
	return _shaders[file_name]


## A shared ShaderMaterial for `file_name` with these uniform values, cached by value.
static func material(file_name: String, params: Dictionary = {}) -> ShaderMaterial:
	var id: String = file_name + var_to_str(params)
	if not _materials.has(id):
		var m := ShaderMaterial.new()
		m.shader = shader(file_name)
		for p: String in params:
			m.set_shader_parameter(p, params[p])
		_materials[id] = m
	return _materials[id]


## The solid kit material: lit surfaces with fake city lighting, emissive where COLOR.a > 0.
static func solid(params: Dictionary = {}) -> ShaderMaterial:
	return material("kit_solid.gdshader", params)


## The additive glow material for halos, beams and light columns. It fades with distance itself
## (fade_begin/fade_end), since fog would brighten additive cards instead of hiding them.
static func glow(params: Dictionary = {}) -> ShaderMaterial:
	return material("kit_glow.gdshader", params)


## Three materials for a hazard's ON, WARNING and OFF states from one shader. `on` holds the shared
## uniforms; `warning` and `off` override what changes (e.g. {"state_glow": 0.1}).
static func state_materials(file_name: String, on: Dictionary, warning: Dictionary, off: Dictionary) -> Array[Material]:
	var w: Dictionary = on.duplicate()
	w.merge(warning, true)
	var o: Dictionary = on.duplicate()
	o.merge(off, true)
	return [material(file_name, on), material(file_name, w), material(file_name, o)]


# --- Shared hazard parts ---------------------------------------------------------
# Hazards keep one colour and shape language in every zone (GDD §5). These builders are the
# common part; zones add their own mounts (exhaust stacks, rubble, ...) around them.

## The energy field of an electric fence: three cards through the depth of `size` (hazard-local,
## centred), each with its own crackle. Use it with an energy_field.gdshader material (one per state,
## see HazardStateVisual); UV.x runs across, UV.y up.
static func energy_field_mesh(size: Vector3) -> ArrayMesh:
	var id: String = "field_%s" % size
	if _templates.has(id):
		return _templates[id]
	var t := MeshLayer.new()
	var half: Vector3 = size * 0.5
	var zs: Array[float] = [half.z, 0.0, -half.z]
	for i: int in zs.size():
		t.rect(Vector3(-half.x, -half.y, zs[i]), Vector3(size.x, 0, 0), Vector3(0, size.y, 0), Color.WHITE,
			0.0, 0, Vector2.ZERO, Vector2.ONE, float(i))
	var batch := MeshBatch.new()
	batch.layer(null).append(t)
	var mesh: ArrayMesh = batch.to_mesh()
	_templates[id] = mesh
	return mesh


## A hazard frame around a box of `size` centred on `center`: striped top and bottom rails along z
## and striped end caps, leaving both x faces open for the zone's content panel. Rails are `rail` thick.
## DESIGN-TBD: the yellow/black striped frame is the proposed cross-zone sign language.
static func hazard_frame(layer: MeshLayer, center: Vector3, size: Vector3, rail: float, color: Color,
		glow_amount: float) -> void:
	var h: Vector3 = size * 0.5
	# Top and bottom rails run the full length; end caps close the box.
	layer.box(center + Vector3(0, h.y - rail * 0.5, 0), Vector3(size.x, rail, size.z), color, glow_amount, PAT_STRIPES)
	layer.box(center - Vector3(0, h.y - rail * 0.5, 0), Vector3(size.x, rail, size.z), color, glow_amount, PAT_STRIPES)
	var inner_h: float = size.y - rail * 2.0
	if inner_h > 0.0:
		layer.box(center + Vector3(0, 0, h.z - rail * 0.5), Vector3(size.x, inner_h, rail), color, glow_amount, PAT_STRIPES,
			ALL_FACES & ~(FACE_PY | FACE_NY))
		layer.box(center - Vector3(0, 0, h.z - rail * 0.5), Vector3(size.x, inner_h, rail), color, glow_amount, PAT_STRIPES,
			ALL_FACES & ~(FACE_PY | FACE_NY))


## A rectangular frame in the plane facing `normal_axis` (0 = x, 2 = z): windows, hatches, vents.
static func frame(layer: MeshLayer, center: Vector3, width: float, height: float, depth: float,
		bar: float, color: Color, glow_amount: float = 0.0, normal_axis: int = 2) -> void:
	var across := Vector3(width, 0, 0) if normal_axis == 2 else Vector3(0, 0, width)
	var d := Vector3(0, 0, depth) if normal_axis == 2 else Vector3(depth, 0, 0)
	var dir: Vector3 = across.normalized()
	layer.box(center + Vector3(0, (height - bar) * 0.5, 0), across + Vector3(0, bar, 0) + d, color, glow_amount)
	layer.box(center - Vector3(0, (height - bar) * 0.5, 0), across + Vector3(0, bar, 0) + d, color, glow_amount)
	var side: Vector3 = dir * bar + Vector3(0, height - bar * 2.0, 0) + d
	layer.box(center + dir * (width - bar) * 0.5, side, color, glow_amount)
	layer.box(center - dir * (width - bar) * 0.5, side, color, glow_amount)
