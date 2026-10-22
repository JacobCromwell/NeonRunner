class_name GantrywayKit
extends RefCounted
## The default look of a falling gantryway (task Q3; GDD §5, Zone 9: "an upper walkway over one lane only, looking like a
## ceiling section", held up by "pillars [that] stand in the floor lanes"; the Ice Lab's reference image: "steel catwalks
## and grated walkways, girders ... snow drifts and ice crystals"): a frosted steel catwalk, an icy steel pillar and the
## catwalk crushed flat once it has fallen, built in code from the mesh kit (MeshBatch), for any zone skin that has no
## look of its own (ZoneSkin.gantryway, gantry_pillar, gantryway_wreck; the Ice Lab's skin may draw its own).
##
## Every look keeps to these (test_gantryways):
## - inside its box, but for the walkway's railings, which stand up to RAIL_HEIGHT above its deck, and its icicles, which
##   hang down to ICICLE_MAX below it: what falls is what the runner sees;
## - solid, lit and never glowing (every vertex's COLOR.a is 0): steel, frost, snow and ice in the zone's cold colours,
##   nothing in a hazard colour. The warning while it falls (its shadow, the red line on its lane) is the gantryway's
##   own (Gantryway), the same in every zone;
## - the pillar reads as something a dash breaks: frost-cracked welds at its foot (as a dash wall's cracks do), in the
##   steel's own darker tone, never a hazard's;
## - drawn with material(): the kit's lit look, dissolving near the camera (gantryway.gdshader: the chase camera passes
##   through a pillar's column when the runner is in the lane beside it, and under a walkway as it falls);
## - one mesh each, cached by size and look, drawing on the Compatibility renderer.
## Each is built in its box's own space: x across the lane, y up (the walkway's underside at -size.y / 2, the pillar's
## and the wreck's floor at -size.y / 2), z along the track with the end toward the oncoming runner at +size.z / 2.

## The default colours (sRGB): frost-crusted black steel, its lighter edges, frost, snow, ice.
const STEEL := Color(0.15, 0.17, 0.2)
const STEEL_LIGHT := Color(0.29, 0.33, 0.38)
const FROST := Color(0.66, 0.76, 0.84)
const SNOW := Color(0.9, 0.93, 0.96)
const ICE := Color(0.6, 0.76, 0.88)
## How many looks the seeds pick from (the snow lumps and icicles move about).
const LOOKS: int = 4
## The walkway: its side girders' width, its deck plate's depth, a cross beam every CROSS_STEP metres, the railing's
## height above the deck and its posts' spacing, the icicles' longest (short of where the chase camera rides at the top
## of a jump under one, about a metre below it: MovementTuning's camera height and a jump's share of it).
const GIRDER: float = 0.16
const DECK: float = 0.07
const CROSS_STEP: float = 2.4
const RAIL_HEIGHT: float = 1.0
const POST_STEP: float = 2.4
const ICICLE_MAX: float = 0.35
## The pillar: its column's width and its base plate's and cap's heights.
const COLUMN: float = 0.56
const PLATE: float = 0.12
## The wreck: its plates' depth, and how far its buckled plates lean (radians).
const WRECK_PLATE: float = 0.05
const BUCKLE: float = 0.06
## Metres from the camera within which the looks are gone, and beyond which they're whole (material(): the shader's
## near_fade_begin and near_fade_end). The chase camera rides 1.8 m under a standing walkway, where the top of its view
## starts about 3.6 m ahead: what dissolves is out of sight there, and only a falling walkway or a pillar's column it
## passes comes near enough.
const NEAR_FADE := Vector2(1.0, 2.6)

static var _walkways: Dictionary = {}
static var _pillars: Dictionary = {}
static var _wrecks: Dictionary = {}


## The material every default look draws with: the kit's lit surfaces, dissolving near the camera (gantryway.gdshader).
static func material() -> ShaderMaterial:
	return MeshKit.material("gantryway.gdshader", {"near_fade_begin": NEAR_FADE.x, "near_fade_end": NEAR_FADE.y})


## `body` dressed with `mesh` drawn in `mat` (one shadowless instance, "Look").
static func dress(body: Node3D, mesh: Mesh, mat: Material) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	inst.name = "Look"
	inst.mesh = mesh
	inst.material_override = mat
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(inst)
	return inst


## What shakes loose from a walkway as it shudders, in `colors` (as walkway_mesh's): snow, frost and ice.
static func snow_colors(colors: PackedColorArray = PackedColorArray()) -> PackedColorArray:
	return PackedColorArray([_color(colors, 3, SNOW), _color(colors, 2, FROST), _color(colors, 4, ICE)])


## The walkway's mesh for a box of `size` (width, depth, length), look `look_seed`, in `colors` (steel, its lighter
## edges, frost, snow, ice; the defaults where they're missing): two I-beam girders along its edges, a grated deck
## between them (the kit's transverse seams), cross beams under it, railings on it, snow along its girders and in lumps
## on its deck, frost on its rails, icicles hanging under it. Cached.
static func walkway_mesh(size: Vector3, look_seed: int, colors: PackedColorArray = PackedColorArray()) -> ArrayMesh:
	var look: int = posmod(look_seed, LOOKS)
	var key: String = var_to_str([size, look, colors])
	if _walkways.has(key):
		return _walkways[key]
	var steel: Color = _color(colors, 0, STEEL)
	var light: Color = _color(colors, 1, STEEL_LIGHT)
	var frost: Color = _color(colors, 2, FROST)
	var snow: Color = _color(colors, 3, SNOW)
	var ice: Color = _color(colors, 4, ICE)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["gantryway", look])
	var hx: float = size.x * 0.5
	var y0: float = -size.y * 0.5
	var y1: float = size.y * 0.5
	var hz: float = size.z * 0.5
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(null)
	# The girders: a web the walkway's depth, and flanges top and bottom (an I-beam), along each edge, the bottom ones
	# crusted with frost: from the street below, where the runner sees it, the walkway reads pale against the dark.
	for side: float in [-1.0, 1.0]:
		var x: float = side * (hx - GIRDER * 0.5)
		s.box(Vector3(x, 0.0, 0.0), Vector3(GIRDER * 0.45, size.y, size.z), steel, 0.0, MeshKit.PAT_HULL)
		s.box(Vector3(x, y0 + 0.035, 0.0), Vector3(GIRDER, 0.07, size.z), frost)
		s.box(Vector3(x, y1 - 0.035, 0.0), Vector3(GIRDER, 0.07, size.z), light)
	# The grated deck at the top, its underside frosted, and cross beams under it.
	var inner: float = size.x - GIRDER * 2.0
	s.box(Vector3(0.0, y1 - DECK * 0.5, 0.0), Vector3(inner, DECK, size.z), light, 0.0, MeshKit.PAT_ROOF,
		MeshKit.ALL_FACES & ~MeshKit.FACE_NY)
	s.box(Vector3(0.0, y1 - DECK, 0.0), Vector3(inner, 0.01, size.z), frost.lerp(light, 0.35), 0.0, MeshKit.PAT_ROOF,
		MeshKit.FACE_NY)
	var beams: int = maxi(1, floori(size.z / CROSS_STEP))
	for k: int in beams + 1:
		var z: float = clampf(-hz + size.z * float(k) / float(beams), -hz + 0.08, hz - 0.08)
		s.box(Vector3(0.0, y1 - DECK - 0.1, z), Vector3(inner, 0.2, 0.16), steel)
	# End girders across both ends, frost along their lower edge.
	for end: float in [-1.0, 1.0]:
		var ez: float = end * (hz - 0.1)
		s.box(Vector3(0.0, 0.0, ez), Vector3(size.x, size.y, 0.2), steel, 0.0, MeshKit.PAT_HULL)
		s.box(Vector3(0.0, y0 + 0.05, ez), Vector3(size.x + 0.01, 0.1, 0.21), frost)
	# Railings: posts, a top rail and a mid rail on each edge, frost along the top rail.
	var posts: int = maxi(1, floori(size.z / POST_STEP))
	for side: float in [-1.0, 1.0]:
		var x: float = side * (hx - 0.05)
		for k: int in posts + 1:
			var z: float = clampf(-hz + size.z * float(k) / float(posts), -hz + 0.05, hz - 0.05)
			s.box(Vector3(x, y1 + RAIL_HEIGHT * 0.5, z), Vector3(0.06, RAIL_HEIGHT, 0.06), light)
		s.box(Vector3(x, y1 + RAIL_HEIGHT - 0.035, 0.0), Vector3(0.07, 0.07, size.z), light)
		s.box(Vector3(x, y1 + RAIL_HEIGHT + 0.012, 0.0), Vector3(0.08, 0.025, size.z), frost)
		s.box(Vector3(x, y1 + RAIL_HEIGHT * 0.5, 0.0), Vector3(0.05, 0.05, size.z), light)
		# Snow banked along the deck by the girder, in drifts with gaps between them.
		var z: float = -hz + rng.randf_range(0.2, 1.5)
		while z < hz - 1.0:
			var drift: float = minf(rng.randf_range(1.5, 5.0), hz - 0.2 - z)
			s.box(Vector3(side * (hx - GIRDER - 0.11), y1 + 0.035, z + drift * 0.5), Vector3(0.22, 0.07, drift),
				snow.lerp(frost, 0.4))
			z += drift + rng.randf_range(0.8, 3.0)
	# Snow lumps on the deck.
	var lumps: int = int(size.z / 6.0) + look
	for k: int in lumps:
		var z: float = rng.randf_range(-hz + 1.0, hz - 1.0)
		var w: float = rng.randf_range(0.4, 1.1)
		s.box(Vector3(rng.randf_range(-inner * 0.3, inner * 0.3), y1 + 0.05, z), Vector3(w, 0.1, rng.randf_range(0.6, 1.8)),
			snow.lerp(frost, 0.25))
	# Icicles under the girders' bottom flanges, and frost on their faces.
	for side: float in [-1.0, 1.0]:
		var x: float = side * (hx - GIRDER * 0.5)
		var z: float = -hz + rng.randf_range(0.3, 1.2)
		while z < hz - 0.3:
			var length: float = rng.randf_range(0.12, ICICLE_MAX)
			s.box(Vector3(x, y0 - length * 0.5, z), Vector3(0.05, length, 0.05), ice)
			z += rng.randf_range(0.7, 1.9)
		s.box(Vector3(side * (hx + 0.002), y0 + size.y * 0.3, 0.0), Vector3(0.004, size.y * 0.4, size.z), frost,
			0.0, MeshKit.PAT_PLAIN, MeshKit.FACE_PX if side > 0.0 else MeshKit.FACE_NX)
	var mesh: ArrayMesh = ZoneSkin.tag_debris_colors(batch.to_mesh(), batch)
	_walkways[key] = mesh
	return mesh


## The pillar's mesh for a box of `size` (width, height up to the walkway's underside, length along the track), pushing
## to `side`, look `look_seed`, in `colors` (as walkway_mesh's): a steel column on a base plate in a drift of snow, frost
## creeping up its foot, knee braces up to a cap plate under the walkway, and frost-cracked welds at its foot. Cached.
static func pillar_mesh(size: Vector3, side: int, look_seed: int, colors: PackedColorArray = PackedColorArray()) -> ArrayMesh:
	var look: int = posmod(look_seed, LOOKS)
	var key: String = var_to_str([size, side, look, colors])
	if _pillars.has(key):
		return _pillars[key]
	var steel: Color = _color(colors, 0, STEEL)
	var light: Color = _color(colors, 1, STEEL_LIGHT)
	var frost: Color = _color(colors, 2, FROST)
	var snow: Color = _color(colors, 3, SNOW)
	var ice: Color = _color(colors, 4, ICE)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["gantry_pillar", look])
	var hx: float = size.x * 0.5
	var hz: float = size.z * 0.5
	var y0: float = -size.y * 0.5
	var y1: float = size.y * 0.5
	var col: float = minf(COLUMN, minf(size.x, size.z) * 0.6)
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(null)
	# The base plate, and the snow drifted round it.
	s.box(Vector3(0.0, y0 + PLATE * 0.5, 0.0), Vector3(size.x, PLATE, size.z), light)
	s.box(Vector3(0.0, y0 + PLATE + 0.09, 0.0), Vector3(size.x * 0.85, 0.18, size.z * 0.85), snow)
	# The column: a web and two flanges (an H across the track), plated, frost creeping up its foot.
	var shaft := Vector2(y0 + PLATE, y1 - PLATE)
	var mid: float = (shaft.x + shaft.y) * 0.5
	var tall: float = shaft.y - shaft.x
	s.box(Vector3(0.0, mid, 0.0), Vector3(col * 0.3, tall, col), steel, 0.0, MeshKit.PAT_HULL)
	for f: float in [-1.0, 1.0]:
		s.box(Vector3(f * col * 0.45, mid, 0.0), Vector3(col * 0.1, tall, col), light, 0.0, MeshKit.PAT_HULL)
	var frost_top: float = shaft.x + rng.randf_range(0.8, 1.4)
	s.box(Vector3(0.0, (shaft.x + frost_top) * 0.5, 0.0), Vector3(col + 0.02, frost_top - shaft.x, col + 0.02), frost)
	# Knee braces from the column up to the cap, toward both ends, and the cap plate under the walkway.
	var brace_from: float = y1 - minf(1.6, size.y * 0.3)
	for e: float in [-1.0, 1.0]:
		var a := Vector3(0.0, brace_from, e * col * 0.5)
		var b := Vector3(0.0, y1 - PLATE, e * (hz - 0.08))
		var along: Vector3 = b - a
		var basis := Basis(Vector3.RIGHT * col * 0.6, along, along.cross(Vector3.RIGHT).normalized() * 0.1)
		s.box_xform(Transform3D(basis, (a + b) * 0.5), light)
	s.box(Vector3(0.0, y1 - PLATE * 0.5, 0.0), Vector3(size.x, PLATE, size.z), light)
	s.box(Vector3(0.0, y1 - PLATE - 0.03, 0.0), Vector3(size.x * 0.9, 0.06, size.z * 0.9), frost)
	# Icicles from the cap's edges.
	for k: int in 4 + look:
		var length: float = rng.randf_range(0.1, 0.35)
		var x: float = rng.randf_range(-hx + 0.08, hx - 0.08)
		var z: float = (hz - 0.06) * (1.0 if k % 2 == 0 else -1.0)
		s.box(Vector3(x, y1 - PLATE - length * 0.5, z), Vector3(0.05, length, 0.05), ice)
	# Frost-cracked welds at its foot, on the faces the runner sees (toward them, and toward the side it pushes to).
	var crack: Color = steel.darkened(0.55)
	for k: int in 3:
		var y: float = shaft.x + rng.randf_range(0.2, 1.1)
		var w: float = rng.randf_range(0.18, col * 0.8)
		s.box(Vector3(rng.randf_range(-col * 0.15, col * 0.15), y, col * 0.5 + 0.012), Vector3(w, 0.035, 0.012), crack, 0.0,
			MeshKit.PAT_PLAIN, MeshKit.FACE_PZ)
	var sx: float = 1.0 if side > 0 else -1.0
	s.box(Vector3(sx * (col * 0.5 + 0.012), shaft.x + 0.6, 0.0), Vector3(0.012, 0.03, col * 0.7), crack, 0.0, MeshKit.PAT_PLAIN,
		MeshKit.FACE_PX if side > 0 else MeshKit.FACE_NX)
	var mesh: ArrayMesh = ZoneSkin.tag_debris_colors(batch.to_mesh(), batch)
	_pillars[key] = mesh
	return mesh


## The fallen walkway's mesh for a box of `size` (width, its low height, length), look `look_seed`, in `colors` (as
## walkway_mesh's): the catwalk crushed flat on the floor (GDD §5, proposed: "once down, it lies flat and the runner runs
## over it harmlessly"): its girders squashed along its edges, its grated deck between them with a few plates buckled up,
## its railings lying flat across it, and snow and broken ice thrown over it. Nothing stands above its box (the runner
## runs through it: it has no collision). Cached.
static func wreck_mesh(size: Vector3, look_seed: int, colors: PackedColorArray = PackedColorArray()) -> ArrayMesh:
	var look: int = posmod(look_seed, LOOKS)
	var key: String = var_to_str([size, look, colors])
	if _wrecks.has(key):
		return _wrecks[key]
	var steel: Color = _color(colors, 0, STEEL)
	var light: Color = _color(colors, 1, STEEL_LIGHT)
	var frost: Color = _color(colors, 2, FROST)
	var snow: Color = _color(colors, 3, SNOW)
	var ice: Color = _color(colors, 4, ICE)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["gantryway_wreck", look])
	var hx: float = size.x * 0.5
	var y0: float = -size.y * 0.5
	var hz: float = size.z * 0.5
	var top: float = y0 + size.y
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(null)
	# The girders, squashed flat along its edges.
	for side: float in [-1.0, 1.0]:
		var x: float = side * (hx - GIRDER * 0.6)
		s.box(Vector3(x, y0 + size.y * 0.45, 0.0), Vector3(GIRDER * 1.2, size.y * 0.9, size.z), steel, 0.0, MeshKit.PAT_HULL,
			MeshKit.NO_BOTTOM)
	# The deck between them, flat on the floor.
	var inner: float = size.x - GIRDER * 2.4
	s.box(Vector3(0.0, y0 + WRECK_PLATE * 0.5, 0.0), Vector3(inner, WRECK_PLATE, size.z), light, 0.0, MeshKit.PAT_ROOF,
		MeshKit.NO_BOTTOM)
	# A few plates buckled up, leaning across the deck (their highest corner within the box).
	var plates: int = int(size.z / 9.0) + 1 + look
	for k: int in plates:
		var z: float = rng.randf_range(-hz + 1.5, hz - 1.5)
		var length: float = rng.randf_range(1.2, 2.4)
		var width: float = inner * rng.randf_range(0.5, 0.9)
		# Leaning no further than keeps both its edges inside the box's height.
		var most: float = asin(clampf(((size.y - 0.01) * 0.5 - WRECK_PLATE * 0.5) / (width * 0.5), 0.0, 1.0))
		var lean: float = minf(BUCKLE, most) * (1.0 if k % 2 == 0 else -1.0)
		var rise: float = absf(sin(lean)) * width * 0.5 + WRECK_PLATE * 0.5
		var basis := Basis(Vector3.FORWARD, lean) * Basis.from_scale(Vector3(width, WRECK_PLATE, length))
		s.box_xform(Transform3D(basis, Vector3(rng.randf_range(-0.15, 0.15), top - rise - 0.005, z)), steel)
	# Its railings lying flat across the girders every few metres, and its top rails along its edges.
	var posts: int = maxi(1, floori(size.z / POST_STEP))
	for k: int in posts + 1:
		var z: float = clampf(-hz + size.z * float(k) / float(posts) + rng.randf_range(-0.4, 0.4), -hz + 0.1, hz - 0.1)
		s.box(Vector3(0.0, top - 0.025, z), Vector3(size.x * rng.randf_range(0.55, 0.95), 0.05, 0.06), light)
	for side: float in [-1.0, 1.0]:
		s.box(Vector3(side * (hx - 0.06), top - 0.03, 0.0), Vector3(0.07, 0.06, size.z), light)
		s.box(Vector3(side * (hx - 0.06), top - 0.004, 0.0), Vector3(0.08, 0.008, size.z), frost, 0.0, MeshKit.PAT_PLAIN,
			MeshKit.FACE_PY)
	# Snow thrown over it, and broken ice.
	for k: int in int(size.z / 3.0) + look:
		var z: float = rng.randf_range(-hz + 0.6, hz - 0.6)
		s.box(Vector3(rng.randf_range(-inner * 0.35, inner * 0.35), y0 + WRECK_PLATE + 0.02, z),
			Vector3(rng.randf_range(0.3, 0.9), 0.04, rng.randf_range(0.4, 1.4)), snow, 0.0, MeshKit.PAT_PLAIN, MeshKit.NO_BOTTOM)
	for k: int in int(size.z / 5.0):
		var z: float = rng.randf_range(-hz + 0.4, hz - 0.4)
		s.box(Vector3(rng.randf_range(-hx * 0.7, hx * 0.7), y0 + WRECK_PLATE + 0.03, z), Vector3(0.12, 0.05, 0.18), ice, 0.0,
			MeshKit.PAT_PLAIN, MeshKit.NO_BOTTOM)
	var mesh: ArrayMesh = ZoneSkin.tag_debris_colors(batch.to_mesh(), batch)
	_wrecks[key] = mesh
	return mesh


static func _color(colors: PackedColorArray, i: int, fallback: Color) -> Color:
	return colors[i] if colors.size() > i else fallback
