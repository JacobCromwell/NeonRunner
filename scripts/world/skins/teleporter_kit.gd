class_name TeleporterKit
extends RefCounted
## The default look of a teleporter (task Q4; GDD §5, Zone 9, the owner, October 21, 2026: "a square pad with a look all
## its own, with a green, slightly space-age antenna on it"; its green is the owner's choice, which the later zones' looser
## colour rule covers; proposed: "the output pads stand within sight ahead, in the teleporter's look without the
## antenna"), built in code from the mesh kit (MeshBatch), for any zone skin that has no look of its own
## (ZoneSkin.teleporter_pad, teleporter_antenna; the Ice Lab's skin draws its plate in the hall's steel). DESIGN-TBD
## (docs/questions/q4.md 9): the look.
##
## - The pad: a square steel plate, flush with the floor, a raised rim, a glowing green square frame inset in it, a grid of
##   thin green lines over its middle (four by four cells) around a glowing hexagonal emitter, a light at each corner, and
##   a soft green halo on the floor around it that the distance never fogs out before 220 m (kit_glow fades by itself).
##   Square, green and gridded, nothing like the anti-grav pad (cyan rings and a light column) or a speed pad (arrows).
## - An output pad: the same pad, without the antenna, and a marker floating over it at the antenna's lamps' height (the
##   pad's hexagonal emitter again, standing up as a glowing ring facing the runner, and its halo), so it reads from the
##   start of its teleporter's approach, where a flat pad down the track is a sliver.
## - The antenna, at the input pad's far edge, the side away from the runner (who's teleported as their feet touch the
##   pad's near edge, so they never reach it): a slim dark mast on a round foot, ringed with green bands, a green halo ring
##   two thirds up (the "space-age" look), a crossbar near the top with a lamp housing at each end (dark glass when out),
##   and a green tip. Its lamps' lit looks (lamp_mesh: a bright green-white lamp and its halo) are nodes of their own the
##   teleporter shows, left and right, and a one-output teleporter's beacon over the tip.
## - Everything glows green or green-white where it glows: never a hazard's red, pink, orange or yellow, never the
##   anti-grav pads' cyan. Solid surfaces draw in the kit's solid material (MeshKit.solid), halos in its glow material
##   (MeshKit.glow); both work on the Compatibility renderer. One mesh each, cached by size and colours.
## Each is built in its pad's box's own space: x across the lane, y up (the floor at -size.y / 2), z along the track with
## the pad's near edge, toward the oncoming runner, at +size.z / 2.

## The default colours (sRGB): the plate's dark steel, its rim's lighter steel, the green, a lit lamp, a lamp out.
const PLATE := Color(0.12, 0.14, 0.16)
const RIM := Color(0.3, 0.34, 0.38)
const GREEN := Color(0.3, 1.0, 0.45)
const LAMP := Color(0.78, 1.0, 0.72)
const LAMP_OFF := Color(0.08, 0.13, 0.1)
## The antenna: its mast's height over the floor, its crossbar's height and half width, where its halo ring is.
const MAST_HEIGHT: float = 2.25
const BAR_HEIGHT: float = 2.0
const BAR_HALF: float = 0.62
const RING_HEIGHT: float = 1.45
## How far in from the pad's far edge the antenna's mast stands (metres): its halo ring stays over the pad.
const ANTENNA_INSET: float = 0.32
## The marker over an output pad (marker_mesh): its middle's height over the floor (over a runner's head, level with the
## antenna's lamps) and its ring's radius (metres).
const MARKER_HEIGHT: float = 2.15
const MARKER_RADIUS: float = 0.3
## Its glow material's fade (metres from the camera): whole to fade_begin, gone by fade_end.
const GLOW_FADE := Vector2(40.0, 220.0)

static var _pads: Dictionary = {}
static var _antennas: Dictionary = {}
static var _lamps: Dictionary = {}


## The solid material the default look draws with (the mesh kit's: lit surfaces, emissive where COLOR.a > 0).
static func solid_material() -> ShaderMaterial:
	return MeshKit.solid()


## The glow material its halos draw with (additive cards, fading by distance: GLOW_FADE).
static func glow_material() -> ShaderMaterial:
	return MeshKit.glow({"fade_begin": GLOW_FADE.x, "fade_end": GLOW_FADE.y})


## Where the antenna's lamp on `side` (-1 left, 1 right; 0 the beacon over the tip) is in a pad's box of `size`.
static func lamp_position(size: Vector3, side: int) -> Vector3:
	var y0: float = -size.y * 0.5
	var z: float = -size.z * 0.5 + ANTENNA_INSET
	if side == 0:
		return Vector3(0.0, y0 + MAST_HEIGHT + 0.12, z)
	return Vector3(side * BAR_HALF, y0 + BAR_HEIGHT, z)


## `body` dressed with a pad's look (pad_mesh) in `colors`.
static func dress_pad(body: Node3D, size: Vector3, look_seed: int, colors: PackedColorArray = PackedColorArray()) -> MeshInstance3D:
	return MeshBatch.add_instance(body, pad_mesh(size, look_seed, colors), "Look")


## `body` dressed with the antenna (antenna_mesh) and its lamps' lit looks (lamp_mesh, each a node of its own: "LampLeft",
## "LampRight", "Beacon", hidden until the teleporter lights them). Returns them as {-1: left, 1: right, 0: beacon}.
static func dress_antenna(body: Node3D, size: Vector3, look_seed: int, colors: PackedColorArray = PackedColorArray()) -> Dictionary:
	MeshBatch.add_instance(body, antenna_mesh(size, look_seed, colors), "Antenna")
	var out: Dictionary = {}
	for side: int in [-1, 1, 0]:
		var lamp: MeshInstance3D = MeshBatch.add_instance(body, lamp_mesh(colors, side == 0),
			"Beacon" if side == 0 else ("LampLeft" if side < 0 else "LampRight"), lamp_position(size, side))
		lamp.visible = false
		out[side] = lamp
	return out


## A pad's mesh for a box of `size`, in `colors` (plate, rim, green, lamp, lamp out; the defaults where they're missing).
## Cached.
static func pad_mesh(size: Vector3, look_seed: int, colors: PackedColorArray = PackedColorArray()) -> ArrayMesh:
	var key: String = var_to_str([size, posmod(look_seed, 2), colors])
	if _pads.has(key):
		return _pads[key]
	var plate: Color = _color(colors, 0, PLATE)
	var rim: Color = _color(colors, 1, RIM)
	var green: Color = _color(colors, 2, GREEN)
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(solid_material())
	var g: MeshLayer = batch.layer(glow_material())
	var y0: float = -size.y * 0.5
	var hx: float = size.x * 0.5
	var hz: float = size.z * 0.5
	# The plate, flush with the floor, and its rim.
	s.box(Vector3(0.0, y0 + 0.02, 0.0), Vector3(size.x, 0.04, size.z), plate, 0.0, MeshKit.PAT_HULL, MeshKit.NO_BOTTOM)
	var rim_w: float = 0.08
	for side: float in [-1.0, 1.0]:
		s.box(Vector3(side * (hx - rim_w * 0.5), y0 + 0.035, 0.0), Vector3(rim_w, 0.07, size.z), rim, 0.0, MeshKit.PAT_PLAIN,
			MeshKit.NO_BOTTOM)
		s.box(Vector3(0.0, y0 + 0.035, side * (hz - rim_w * 0.5)), Vector3(size.x - rim_w * 2.0, 0.07, rim_w), rim, 0.0,
			MeshKit.PAT_PLAIN, MeshKit.NO_BOTTOM)
	# The green frame inset in it.
	var inset: float = 0.2
	var frame_w: float = 0.07
	var fx: float = hx - inset
	var fz: float = hz - inset
	var fy: float = y0 + 0.045
	for side: float in [-1.0, 1.0]:
		s.box(Vector3(side * fx, fy, 0.0), Vector3(frame_w, 0.012, fz * 2.0 + frame_w), green, 1.0, MeshKit.PAT_PLAIN,
			MeshKit.FACE_PY)
		s.box(Vector3(0.0, fy, side * fz), Vector3(fx * 2.0 - frame_w, 0.012, frame_w), green, 1.0, MeshKit.PAT_PLAIN,
			MeshKit.FACE_PY)
	# A grid of thin lines over its middle, four by four cells.
	var cells: int = 4
	for k: int in range(1, cells):
		var u: float = -fx + 2.0 * fx * float(k) / float(cells)
		var w: float = -fz + 2.0 * fz * float(k) / float(cells)
		s.box(Vector3(u, fy - 0.002, 0.0), Vector3(0.025, 0.01, fz * 2.0), green, 0.45, MeshKit.PAT_PLAIN, MeshKit.FACE_PY)
		s.box(Vector3(0.0, fy - 0.002, w), Vector3(fx * 2.0, 0.01, 0.025), green, 0.45, MeshKit.PAT_PLAIN, MeshKit.FACE_PY)
	# The hexagonal emitter in its middle, and a light at each corner.
	s.prism(Vector3(0.0, y0 + 0.04, 0.0), minf(size.x, size.z) * 0.16, 0.025, 6, green.lerp(_color(colors, 3, LAMP), 0.3), 0.9)
	for cx: float in [-1.0, 1.0]:
		for cz: float in [-1.0, 1.0]:
			s.box(Vector3(cx * (hx - 0.11), y0 + 0.06, cz * (hz - 0.11)), Vector3(0.1, 0.05, 0.1), green, 1.2)
	# Its halo on the floor.
	g.rect(Vector3(-hx * 1.45, y0 + 0.06, hz * 1.45), Vector3(hx * 2.9, 0.0, 0.0), Vector3(0.0, 0.0, -hz * 2.9), green, 0.5,
		MeshKit.SHAPE_RADIAL)
	var mesh: ArrayMesh = batch.to_mesh()
	_pads[key] = mesh
	return mesh


## The antenna's mesh on a pad's box of `size`, in `colors` (as pad_mesh's), its lamps out. Cached.
static func antenna_mesh(size: Vector3, look_seed: int, colors: PackedColorArray = PackedColorArray()) -> ArrayMesh:
	var key: String = var_to_str([size, posmod(look_seed, 2), colors])
	if _antennas.has(key):
		return _antennas[key]
	var plate: Color = _color(colors, 0, PLATE)
	var rim: Color = _color(colors, 1, RIM)
	var green: Color = _color(colors, 2, GREEN)
	var off: Color = _color(colors, 4, LAMP_OFF)
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(solid_material())
	var g: MeshLayer = batch.layer(glow_material())
	var y0: float = -size.y * 0.5
	var z: float = -size.z * 0.5 + ANTENNA_INSET
	# Its round foot and the mast, ringed with green bands.
	s.prism(Vector3(0.0, y0 + 0.04, z), 0.17, 0.1, 8, rim)
	s.prism(Vector3(0.0, y0 + 0.14, z), 0.07, MAST_HEIGHT - 0.14, 8, plate)
	for k: int in 4:
		s.prism(Vector3(0.0, y0 + 0.45 + 0.32 * k, z), 0.078, 0.05, 8, green, 0.9)
	# The halo ring two thirds up: a thin octagonal hoop on four spokes.
	var ring_r: float = 0.3
	var ring_y: float = y0 + RING_HEIGHT
	for k: int in 8:
		var a0: float = TAU * float(k) / 8.0
		var a1: float = TAU * float(k + 1) / 8.0
		var p0 := Vector3(cos(a0) * ring_r, ring_y, z + sin(a0) * ring_r)
		var p1 := Vector3(cos(a1) * ring_r, ring_y, z + sin(a1) * ring_r)
		s.box_xform(_bar(p0, p1, 0.035), green, 0.8)
	for k: int in 4:
		var a: float = TAU * (float(k) + 0.5) / 4.0
		s.box_xform(_bar(Vector3(0.0, ring_y, z), Vector3(cos(a) * ring_r, ring_y, z + sin(a) * ring_r), 0.025), rim)
	# The crossbar near the top, a lamp housing at each end (dark glass while out), and the green tip.
	var bar_y: float = y0 + BAR_HEIGHT
	s.box(Vector3(0.0, bar_y - 0.1, z), Vector3(BAR_HALF * 2.0, 0.05, 0.06), rim)
	for side: float in [-1.0, 1.0]:
		s.box(Vector3(side * BAR_HALF, bar_y - 0.1, z), Vector3(0.08, 0.1, 0.08), rim)
		s.box(Vector3(side * BAR_HALF, bar_y, z), Vector3(0.17, 0.17, 0.17), off)
	s.prism(Vector3(0.0, y0 + MAST_HEIGHT, z), 0.06, 0.08, 6, green, 1.0)
	# A faint glow down its mast's bands, toward the runner.
	g.rect(Vector3(-0.17, y0 + 0.35, z + 0.08), Vector3(0.34, 0.0, 0.0), Vector3(0.0, 1.4, 0.0), green, 0.1, MeshKit.SHAPE_FLAT)
	var mesh: ArrayMesh = batch.to_mesh()
	_antennas[key] = mesh
	return mesh


## `body` (an output pad's node, in a pad's box of `size`) dressed with the marker floating over it (marker_mesh), so the
## output pad reads from its teleporter's approach: a flat pad far down the track is a sliver.
static func dress_marker(body: Node3D, size: Vector3, look_seed: int, colors: PackedColorArray = PackedColorArray()) -> MeshInstance3D:
	return MeshBatch.add_instance(body, marker_mesh(size, look_seed, colors), "Marker")


## The marker floating over an output pad (MARKER_HEIGHT over the floor, over its middle), in `colors` (as pad_mesh's): the
## pad's hexagonal emitter again, standing up as a glowing ring facing the runner, a smaller hexagon lit in it, and its
## halo; never a column of light (the anti-grav pads') nor anything across the lane (a fence's). Cached.
static func marker_mesh(size: Vector3, look_seed: int, colors: PackedColorArray = PackedColorArray()) -> ArrayMesh:
	var key: String = var_to_str(["marker", size, posmod(look_seed, 2), colors])
	if _antennas.has(key):
		return _antennas[key]
	var green: Color = _color(colors, 2, GREEN)
	var lamp: Color = _color(colors, 3, LAMP)
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(solid_material())
	var g: MeshLayer = batch.layer(glow_material())
	var c := Vector3(0.0, -size.y * 0.5 + MARKER_HEIGHT, 0.0)
	var r: float = MARKER_RADIUS
	for k: int in 6:
		var a0: float = TAU * (float(k) + 0.5) / 6.0
		var a1: float = TAU * (float(k) + 1.5) / 6.0
		s.box_xform(_bar(c + Vector3(cos(a0), sin(a0), 0.0) * r, c + Vector3(cos(a1), sin(a1), 0.0) * r, 0.05), green, 1.1)
	# The small hexagon lit in it, standing up: the unit prism's axis along the track, its faces toward the runner.
	var hr: float = r * 0.42
	s.prism_xform(Transform3D(Basis(Vector3(hr, 0.0, 0.0), Vector3(0.0, 0.0, 0.04), Vector3(0.0, -hr, 0.0)),
		c + Vector3(0.0, 0.0, -0.02)), 6, green.lerp(lamp, 0.4), 1.3)
	g.rect(c + Vector3(-r * 2.0, -r * 2.0, 0.05), Vector3(r * 4.0, 0.0, 0.0), Vector3(0.0, r * 4.0, 0.0), green, 0.55,
		MeshKit.SHAPE_RADIAL)
	var mesh: ArrayMesh = batch.to_mesh()
	_antennas[key] = mesh
	return mesh


## A lamp's lit look, centred on the lamp, in `colors` (as pad_mesh's): a bright green-white lamp in its housing and its
## halo, facing the runner; with `beacon` the green beacon over the tip, smaller. Cached.
static func lamp_mesh(colors: PackedColorArray = PackedColorArray(), beacon: bool = false) -> ArrayMesh:
	var key: String = var_to_str([colors, beacon])
	if _lamps.has(key):
		return _lamps[key]
	var lamp: Color = _color(colors, 2, GREEN) if beacon else _color(colors, 3, LAMP)
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(solid_material())
	var g: MeshLayer = batch.layer(glow_material())
	var r: float = 0.07 if beacon else 0.095
	s.box(Vector3.ZERO, Vector3(r * 2.0, r * 2.0, r * 2.0), lamp, 1.8)
	var halo: float = 0.42 if beacon else 0.52
	g.rect(Vector3(-halo, -halo, r + 0.01), Vector3(halo * 2.0, 0.0, 0.0), Vector3(0.0, halo * 2.0, 0.0), lamp, 0.9,
		MeshKit.SHAPE_RADIAL)
	var mesh: ArrayMesh = batch.to_mesh()
	_lamps[key] = mesh
	return mesh


## A unit box stretched into a bar from `a` to `b`, `width` thick (box_xform's transform).
static func _bar(a: Vector3, b: Vector3, width: float) -> Transform3D:
	var along: Vector3 = b - a
	var length: float = maxf(along.length(), 0.001)
	var x: Vector3 = along / length
	var up := Vector3.UP if absf(x.dot(Vector3.UP)) < 0.95 else Vector3.FORWARD
	var z: Vector3 = x.cross(up).normalized()
	var y: Vector3 = z.cross(x).normalized()
	return Transform3D(Basis(x * length, y * width, z * width), (a + b) * 0.5)


static func _color(colors: PackedColorArray, i: int, fallback: Color) -> Color:
	return colors[i] if i < colors.size() else fallback
