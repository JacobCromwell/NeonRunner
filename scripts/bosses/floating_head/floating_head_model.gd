class_name FloatingHeadModel
extends RefCounted
## The Floating Head's ship and face, built in code from the mesh kit (MeshLayer, the kit's solid and
## glow shaders), low-poly and merged: one draw call per material and moving part. GDD §10: a giant
## ship whose back is a giant cybernetic propaganda face watching over the city.
## DESIGN-TBD (docs/OPEN_QUESTIONS.md §D, item 83): the look beyond that brief. Placeholder:
## - the hull is a long armoured head lying face-back, as wide as the street it flies down (a giant
##   ship in a street canyon; its height grows a little with the street's width), gunmetal like the
##   City's ceiling ships: rib bands, a strake along each cheekbone, lit gallery windows down its sides,
##   dorsal fins, and a dim cold trim outlining the head;
## - its stern (toward the player) is the face, a ship's stern until it lights up: a big screen (the
##   eyes and brows; dark until GDD §10's reveal) under a heavy brow with a cold light line, a slatted
##   mechanical jaw over a muzzle (the mouth: it opens for the cyborg drop, task E1b) whose lip line
##   lights up with the face, slatted engine vents at the jaw's corners and a ring of exhaust ports
##   around the head (it flies forward, so its engines face the player), loudspeaker grilles beside
##   the screen where the street is wide enough and loudspeaker "ears" on its sides (it shouts its
##   propaganda);
## - its belly: the searchlight under its chin, a bomb bay with two doors, lift pads, running lights;
## - on its crown: a row of sockets under armoured covers, one over each of the lanes it spans near its
##   middle (FloatingHeadTuning.weak_point_reach), where the red weak points come out while it's pinned
##   (the stomp windows), and antenna masts.
## Colour rule (GDD §5, CLAUDE.md): nothing on it glows in a hazard colour but its attacks and weak
## points (red): its lights are cold white and periwinkle blue (the City's engine colour), clear of
## the pads' cyan.
##
## Ship space: metres, origin on the centre line at the belly under the face, +y up, +z toward the
## player (the stern, where the face is), -z toward the bow (it flies toward -z). Meshes and shapes
## are cached per street width.

## One ship's measurements (ship space). Parts and hitboxes are placed from these.
class Shape:
	var width: float = 0.0
	var height: float = 0.0
	var length: float = 0.0
	## The screen's centre (its front) and size.
	var screen_center := Vector3.ZERO
	var screen_size := Vector2.ZERO
	## The heavy brow over the screen: half its width, its bottom and its top.
	var brow_half: float = 0.0
	var brow_bottom: float = 0.0
	var brow_top: float = 0.0
	## The mouth: a muzzle standing out of the face (x from -half to +half, y from bottom to top, its
	## front at mouth_front), closed by the jaw, which hinges at its top front edge.
	var mouth_half: float = 0.0
	var mouth_bottom: float = 0.0
	var mouth_top: float = 0.0
	var mouth_front: float = 0.0
	var jaw_hinge := Vector3.ZERO
	## The engine vents at the jaw's corners (their centres' x, y) and half their width.
	var nozzle := Vector2.ZERO
	var nozzle_radius: float = 0.0
	## The searchlight's gimbal under the chin, and the bomb bay (centre, half width, length).
	var lamp_pivot := Vector3.ZERO
	var bay_center := Vector3.ZERO
	var bay_half: float = 0.0
	var bay_length: float = 0.0
	## Where the weak points come out on the crown (their sockets' tops), one over each lane near the
	## middle, left to right.
	var weak_points: Array[Vector3] = []
	## The crown's centre line over the weak points: it banks about this point (a pinned roll keeps the
	## weak points over their lanes).
	var roll_pivot := Vector3.ZERO


## Colours (sRGB). Hull tones stay desaturated; lights keep off every hazard hue.
const HULL := Color(0.2, 0.2, 0.26)
const HULL_DARK := Color(0.1, 0.1, 0.13)
const HULL_LIGHT := Color(0.3, 0.31, 0.38)
const PLATE := Color(0.15, 0.15, 0.2)
const BEZEL := Color(0.05, 0.05, 0.07)
const GLASS := Color(0.07, 0.08, 0.12)
const LIGHT := Color(0.75, 0.85, 1.0)
const ENGINE := Color(0.45, 0.6, 1.0)
const WINDOW := Color(0.62, 0.72, 1.0)
## Weak points and the bombs' tips: enemy-attack red, the hover truck's weak point colour.
const WEAK := Color(1.0, 0.08, 0.1)
const MOUTH := Color(0.03, 0.03, 0.04)
## How far a weak point's socket stands proud of the crown.
const SOCKET_RISE: float = 0.1
## The weak points' row along the crown (ship space z): a little behind the face.
const WEAK_Z: float = -3.4
## The crown's walkable top (deck_faces): the hull's skin from the face back to this ring, across the
## outline's segments from DECK_FIRST to DECK_LAST (the crown down to its shoulders).
const DECK_RINGS: int = 3
const DECK_FIRST: int = 7
const DECK_LAST: int = 14
## The screen's frame.
const BEZEL_WIDTH: float = 0.3
## The face panel sits inside a rim this share of the head's outline.
const RIM_INSET: float = 0.84
## How far the loudspeaker "ears" stand out of the hull's sides (into the street's margin).
const EAR_OUT: float = 0.45

## The right half of the head's outline seen from behind (the stern), from the belly's edge up to
## the crown: x across (0..0.5 of the width), y up (0..1 of the height). A chin narrower than the
## cheekbones and a broad, rounded crown. Points 5-6 bound the gallery band.
const RIGHT: Array[Vector2] = [
	Vector2(0.2, 0.0), Vector2(0.33, 0.07), Vector2(0.43, 0.2), Vector2(0.49, 0.36), Vector2(0.5, 0.5),
	Vector2(0.5, 0.56), Vector2(0.495, 0.6), Vector2(0.475, 0.72), Vector2(0.44, 0.84), Vector2(0.36, 0.93),
	Vector2(0.2, 0.985),
]
## The whole outline, counter-clockwise seen from behind: the right half, the crown's top, the left
## half mirrored; the last segment is the flat belly.
static var PROFILE: Array[Vector2] = _mirror(RIGHT)
## Segments (from point i to i + 1) that carry the lit galleries: the right one and its mirror.
const GALLERY_SEGMENTS: Array[int] = [5, 16]
## The cheekbone point on each side, where the strakes run.
const STRAKE_POINTS: Array[int] = [4, 18]
## The hull's rings from the stern to the bow: [z (a share of the length, toward -z), width scale,
## height scale, lift of the belly (a share of the height)].
const RINGS: Array[Vector4] = [
	Vector4(0.0, 1.0, 1.0, 0.0), Vector4(-0.042, 1.0, 1.0, 0.0), Vector4(-0.3, 1.0, 1.02, 0.0),
	Vector4(-0.58, 0.93, 0.96, 0.02), Vector4(-0.8, 0.74, 0.8, 0.07), Vector4(-0.93, 0.45, 0.52, 0.18),
	Vector4(-1.0, 0.18, 0.22, 0.34),
]
## The rings (by index) between which the galleries glow.
const GALLERY_RINGS := Vector2i(1, 3)

static var _shapes: Dictionary = {}
static var _meshes: Dictionary = {}
static var _bomb: ArrayMesh


## The ship for a street `street_width` metres wide between its walls with `lane_count` lanes
## `lane_width` wide.
static func shape_for(street_width: float, lane_count: int, t: FloatingHeadTuning, lane_width: float) -> Shape:
	var id: String = "%.3f|%d|%.3f|%s" % [street_width, lane_count, lane_width, [t.street_margin, t.hull_length,
		t.head_height_narrow, t.head_height_wide, t.weak_point_reach]]
	if _shapes.has(id):
		return _shapes[id]
	var s := Shape.new()
	s.width = maxf(street_width - 2.0 * t.street_margin, 4.0)
	s.height = lerpf(t.head_height_narrow, t.head_height_wide, clampf((lane_count - 3) / 3.0, 0.0, 1.0))
	s.length = t.hull_length
	var w: float = s.width
	var h: float = s.height
	# The screen and the brow over it fill the upper face, within the head's outline.
	var sh: float = 0.42 * h
	var sy0: float = 0.39 * h
	var brow_h: float = 0.6
	var brow_bottom: float = sy0 + sh + BEZEL_WIDTH - 0.05
	var brow_limit: float = outline_half(s, brow_bottom + brow_h) - 0.1
	var sw: float = minf(minf(0.66 * w, 1.5 * sh), 2.0 * brow_limit - 0.7)
	s.screen_size = Vector2(sw, sh)
	s.screen_center = Vector3(0.0, sy0 + sh * 0.5, 0.42)
	s.brow_bottom = brow_bottom
	s.brow_top = brow_bottom + brow_h
	s.brow_half = minf(sw * 0.5 + 0.5, brow_limit)
	# The mouth under it, the engine vents at its corners.
	s.mouth_bottom = 0.09 * h
	s.mouth_top = 0.34 * h
	s.mouth_half = minf(0.4 * w, 0.85 * sw) * 0.5
	s.mouth_front = 0.9
	s.jaw_hinge = Vector3(0.0, s.mouth_top + 0.02, s.mouth_front)
	s.nozzle_radius = clampf(0.065 * w, 0.4, 0.8)
	var ny: float = 0.22 * h
	s.nozzle = Vector2(outline_half(s, ny) * RIM_INSET - s.nozzle_radius - 0.05, ny)
	s.lamp_pivot = Vector3(0.0, -0.6, -1.8)
	s.bay_center = Vector3(0.0, 0.0, -6.5)
	s.bay_half = 0.14 * w
	s.bay_length = 4.0
	# The weak points: one over each lane whose centre lies within weak_point_reach of the middle (the
	# runner comes down on them in a lane), the nearest one if none does.
	var nearest: float = INF
	for l: int in lane_count:
		var x: float = (float(l) - (lane_count - 1) * 0.5) * lane_width
		nearest = minf(nearest, absf(x))
		if absf(x) <= t.weak_point_reach * w + 0.001:
			s.weak_points.append(Vector3(x, crown_height(s, x / w, WEAK_Z) + SOCKET_RISE, WEAK_Z))
	if s.weak_points.is_empty():
		s.weak_points.append(Vector3(nearest, crown_height(s, nearest / w, WEAK_Z) + SOCKET_RISE, WEAK_Z))
	s.roll_pivot = Vector3(0.0, crown_height(s, 0.0, WEAK_Z), 0.0)
	_shapes[id] = s
	return s


## The head outline's half width (ship space) at height `y` on the stern.
static func outline_half(s: Shape, y: float) -> float:
	var v: float = clampf(y / s.height, 0.0, 1.0)
	for i: int in RIGHT.size() - 1:
		var a: Vector2 = RIGHT[i]
		var b: Vector2 = RIGHT[i + 1]
		if v <= b.y:
			return lerpf(a.x, b.x, (v - a.y) / maxf(b.y - a.y, 0.0001)) * s.width
	var last: Vector2 = RIGHT[-1]
	return lerpf(last.x, 0.0, (v - last.y) / maxf(1.0 - last.y, 0.0001)) * s.width


## The crown's height (ship space) at a share `fx` of the width across (-0.5..0.5) and at `z`,
## following the hull's rings.
static func crown_height(s: Shape, fx: float, z: float) -> float:
	var section: Vector3 = _section(s, z)
	return (section.z + _profile_top(absf(fx) / maxf(section.x, 0.01)) * section.y) * s.height


## The belly's height (ship space) at `z`: flat under the face, rising toward the bow.
static func belly_height(s: Shape, z: float) -> float:
	return _section(s, z).z * s.height


## The ship's transform in its body's space (FloatingHeadBody.set_pose): nose up by `pitch`, banked by
## `roll` about its crown over the weak points (s.roll_pivot), so a pinned roll keeps them over their
## lanes.
static func ship_transform(s: Shape, pitch: float, roll: float) -> Transform3D:
	var bank := Basis(Vector3(0.0, 0.0, 1.0), roll)
	var banked := Transform3D(bank, s.roll_pivot - bank * s.roll_pivot)
	return Transform3D(Basis(Vector3(1.0, 0.0, 0.0), pitch), Vector3.ZERO) * banked


## The crown's walkable top (ship space): the hull skin's triangles from the face back to ring
## DECK_RINGS, over the crown down to its shoulders (outline segments DECK_FIRST to DECK_LAST), for a
## concave collision shape: the deck FloatingHeadBody switches on while the ship is pinned, exactly
## where the hull is drawn.
static func deck_faces(s: Shape) -> PackedVector3Array:
	var out := PackedVector3Array()
	var rings: Array[PackedVector3Array] = []
	for i: int in DECK_RINGS + 1:
		rings.append(_ring(s, RINGS[i]))
	for i: int in DECK_RINGS:
		var a: PackedVector3Array = rings[i]
		var b: PackedVector3Array = rings[i + 1]
		for j: int in range(DECK_FIRST, DECK_LAST + 1):
			var k: int = j + 1
			out.append_array(PackedVector3Array([a[j], a[k], b[k], a[j], b[k], b[j]]))
	return out


## The meshes for a ship `s`: {hull, screen, jaw, lip, lamp, lens, door, cover, weak}. Parts are in
## their own spaces: the jaw and its lip hang from the hinge, the lamp head points along -z from its
## gimbal, a bay door reaches along +x from its hinge, a cover and a weak point sit on their socket.
static func meshes(s: Shape) -> Dictionary:
	var id: String = "%.3f|%.3f|%.3f" % [s.width, s.height, s.length]
	if _meshes.has(id):
		return _meshes[id]
	var out := {
		"hull": _hull(s),
		"screen": _screen(s),
		"jaw": _jaw(s),
		"lip": _lip(s),
		"lamp": _lamp(),
		"lens": _lens(),
		"door": _door(s),
		"cover": _cover(),
		"weak": _weak_dome(),
	}
	_meshes[id] = out
	return out


## The kit's solid material for the ship: lit with the City's fake light, emissive where COLOR.a > 0.
static func solid_material() -> ShaderMaterial:
	return MeshKit.solid({"glow_scale": 4.0, "sheen_color": Color(0.4, 0.28, 0.7), "sheen_strength": 0.2})


## The kit's additive glow material for the ship's halos (fading far away, not in the fog).
static func glow_material() -> ShaderMaterial:
	return MeshKit.glow({"fade_begin": 90.0, "fade_end": 320.0})


## A falling bomb, nose along -z: a dark finned body with an enemy-red tip (its attack colour).
static func bomb_mesh() -> ArrayMesh:
	if _bomb != null:
		return _bomb
	var batch := MeshBatch.new()
	var m: MeshLayer = batch.layer(solid_material())
	var body := Color(0.16, 0.16, 0.19)
	_prism_along_z(m, Vector3(0.0, 0.0, 0.45), 0.22, 0.9, 8, body, 0.0)
	_frustum(m, Transform3D(Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)), Vector3(0.0, 0.0, -0.45)),
		0.22, 0.07, 0.32, 8, body, 0.0)
	_prism_along_z(m, Vector3(0.0, 0.0, -0.76), 0.075, 0.08, 8, WEAK, 1.3)
	for i: int in 4:
		var a: float = TAU * i / 4.0 + PI * 0.25
		var dir := Vector3(cos(a), sin(a), 0.0)
		m.box_xform(Transform3D(Basis(dir * 0.34, Vector3(0, 0, 1).cross(dir) * 0.03, Vector3(0, 0, 0.36)),
			dir * 0.2 + Vector3(0.0, 0.0, 0.72)), Color(0.24, 0.24, 0.28))
	_bomb = batch.to_mesh()
	return _bomb


# --- The hull ------------------------------------------------------------------------------

static func _hull(s: Shape) -> ArrayMesh:
	var batch := MeshBatch.new()
	var m: MeshLayer = batch.layer(solid_material())
	var g: MeshLayer = batch.layer(glow_material())
	var rings: Array[PackedVector3Array] = []
	for r: Vector4 in RINGS:
		rings.append(_ring(s, r))
	_skin(m, rings)
	_ribs(m, rings, s)
	_galleries(m, rings)
	_bow_cap(m, rings[-1], s)
	_stern(m, g, s, rings[0])
	_ears(m, s)
	_belly(m, g, s)
	_crown(m, s)
	return batch.to_mesh()


static func _mirror(right: Array[Vector2]) -> Array[Vector2]:
	var out: Array[Vector2] = right.duplicate()
	out.append(Vector2(0.0, 1.0))
	for i: int in range(right.size() - 1, -1, -1):
		out.append(Vector2(-right[i].x, right[i].y))
	return out


static func _ring_z(r: Vector4, length: float) -> float:
	return r.x * length


## The hull's section at `z`: (width scale, height scale, belly lift), between its rings.
static func _section(s: Shape, z: float) -> Vector3:
	for i: int in RINGS.size() - 1:
		var a: Vector4 = RINGS[i]
		var b: Vector4 = RINGS[i + 1]
		var za: float = _ring_z(a, s.length)
		var zb: float = _ring_z(b, s.length)
		if z <= za and z >= zb:
			var k: float = (za - z) / maxf(za - zb, 0.001)
			return Vector3(lerpf(a.y, b.y, k), lerpf(a.z, b.z, k), lerpf(a.w, b.w, k))
	var last: Vector4 = RINGS[-1] if z < 0.0 else RINGS[0]
	return Vector3(last.y, last.z, last.w)


static func _ring(s: Shape, r: Vector4) -> PackedVector3Array:
	var out := PackedVector3Array()
	var z: float = _ring_z(r, s.length)
	for p: Vector2 in PROFILE:
		out.append(Vector3(p.x * s.width * r.y, (r.w + p.y * r.z) * s.height, z))
	return out


## The height (share) of the outline's top edge at |x| (share of the width).
static func _profile_top(ax: float) -> float:
	var last: Vector2 = RIGHT[-1]
	if ax <= last.x:
		return lerpf(1.0, last.y, ax / maxf(last.x, 0.0001))
	for i: int in range(RIGHT.size() - 1, 4, -1):
		var a: Vector2 = RIGHT[i]
		var b: Vector2 = RIGHT[i - 1]
		if ax <= b.x:
			if b.x - a.x < 0.0001:
				return maxf(a.y, b.y)
			return lerpf(a.y, b.y, clampf((ax - a.x) / (b.x - a.x), 0.0, 1.0))
	return RIGHT[4].y


## The hull's skin between consecutive rings, facing out: plated in slightly different tones, the
## belly darker, the gallery band dark glass (its windows are lit, _galleries).
static func _skin(m: MeshLayer, rings: Array[PackedVector3Array]) -> void:
	var n: int = PROFILE.size()
	for i: int in rings.size() - 1:
		var a: PackedVector3Array = rings[i]
		var b: PackedVector3Array = rings[i + 1]
		for j: int in n:
			var k: int = (j + 1) % n
			var color: Color = HULL
			if j == n - 1:
				color = HULL_DARK
			elif GALLERY_SEGMENTS.has(j):
				color = GLASS
			elif j >= 8 and j <= 14:
				color = HULL.lightened(0.06)
			color = color.darkened(0.1 * MeshKit.hash01(i, j, 7))
			m.quad(a[j], a[k], b[k], b[j], color)


## Dark rib bands around the hull at its inner rings, and a strake along each cheekbone.
static func _ribs(m: MeshLayer, rings: Array[PackedVector3Array], s: Shape) -> void:
	var n: int = PROFILE.size()
	var center := Vector3(0.0, 0.5 * s.height, 0.0)
	for i: int in [1, 2, 3]:
		var ring: PackedVector3Array = rings[i]
		center.z = ring[0].z
		for j: int in n:
			var a: Vector3 = ring[j]
			var b: Vector3 = ring[(j + 1) % n]
			var out: Vector3 = (((a + b) * 0.5) - center).normalized() * 0.06
			_bar(m, a + out, b + out, 0.16, HULL_DARK, 0.0, Vector3.BACK)
	for p: int in STRAKE_POINTS:
		for i: int in range(1, 4):
			var a: Vector3 = rings[i][p]
			var b: Vector3 = rings[i + 1][p]
			var side: float = signf(a.x)
			_bar(m, a + Vector3(side * 0.1, 0, 0), b + Vector3(side * 0.1, 0, 0), 0.26, HULL_LIGHT, 0.0, Vector3.UP)


## Lit windows along the gallery bands, between the gallery rings.
static func _galleries(m: MeshLayer, rings: Array[PackedVector3Array]) -> void:
	for j: int in GALLERY_SEGMENTS:
		for i: int in range(GALLERY_RINGS.x, GALLERY_RINGS.y):
			var a: Vector3 = (rings[i][j] + rings[i][j + 1]) * 0.5
			var b: Vector3 = (rings[i + 1][j] + rings[i + 1][j + 1]) * 0.5
			var along: Vector3 = b - a
			var count: int = maxi(int(along.length() / 1.3), 1)
			var side: float = signf(a.x)
			for w: int in count:
				var p: Vector3 = a.lerp(b, (float(w) + 0.5) / count) + Vector3(side * 0.03, 0, 0)
				var lit: bool = MeshKit.hash01(i, w, j) < 0.72
				m.box_xform(Transform3D(Basis(Vector3(0.05, 0, 0), Vector3(0, 0.3, 0), along.normalized() * 0.75), p),
					WINDOW if lit else GLASS.lightened(0.1), 0.45 if lit else 0.0)


static func _bow_cap(m: MeshLayer, ring: PackedVector3Array, s: Shape) -> void:
	var c := Vector3(0.0, (RINGS[-1].w + 0.5 * RINGS[-1].z) * s.height, ring[0].z - 0.8)
	for j: int in ring.size():
		_tri(m, c, ring[j], ring[(j + 1) % ring.size()], HULL_DARK, 0.0)


# --- The face (the stern) ---------------------------------------------------------------------

static func _stern(m: MeshLayer, g: MeshLayer, s: Shape, outline: PackedVector3Array) -> void:
	var h: float = s.height
	var n: int = outline.size()
	var center := Vector3(0.0, 0.5 * h, 0.0)
	# The rim, and the face panel inside it.
	var inner := PackedVector3Array()
	for p: Vector3 in outline:
		inner.append(center + (p - center) * RIM_INSET)
	for j: int in n:
		var k: int = (j + 1) % n
		m.quad(inner[j], inner[k], outline[k], outline[j], HULL.darkened(0.08 + 0.08 * MeshKit.hash01(j, 3)))
		_tri(m, center + Vector3(0, 0, 0.02), inner[k] + Vector3(0, 0, 0.02), inner[j] + Vector3(0, 0, 0.02), PLATE, 0.0)
	# A dim cold trim outlining the head, so its shape reads against the night sky.
	for j: int in n:
		_bar(m, outline[j] + Vector3(0, 0, 0.04), outline[(j + 1) % n] + Vector3(0, 0, 0.04), 0.07, LIGHT, 0.22, Vector3.BACK)
	# Exhaust ports in the rim, glowing blue, their halos toward the player (none behind the brow).
	for j: int in n:
		var p: Vector3 = outline[j]
		if p.y < 0.3 * h:
			continue
		var at: Vector3 = (p + inner[j]) * 0.5
		var size: float = clampf((p - inner[j]).length() * 0.55, 0.26, 0.6)
		if absf(at.x) < s.brow_half + size and at.y > s.brow_bottom - size and at.y < s.brow_top + size:
			continue
		m.box(at + Vector3(0, 0, 0.08), Vector3(size, size, 0.16), HULL_DARK, 0.0, MeshKit.PAT_PLAIN, MeshKit.NO_BOTTOM)
		m.box(at + Vector3(0, 0, 0.17), Vector3(size * 0.62, size * 0.62, 0.02), ENGINE, 1.0, MeshKit.PAT_PLAIN, MeshKit.FACE_PZ)
		g.rect(at + Vector3(-size * 1.6, -size * 1.6, 0.3), Vector3(size * 3.2, 0, 0), Vector3(0, size * 3.2, 0), ENGINE, 0.4,
			MeshKit.SHAPE_RADIAL)
	_screen_frame(m, s)
	_muzzle(m, s)
	_nozzles(m, g, s)
	# Loudspeaker grilles beside the screen, where the street is wide enough (it shouts its propaganda).
	var gx0: float = s.screen_size.x * 0.5 + BEZEL_WIDTH + 0.15
	var gy0: float = s.screen_center.y - s.screen_size.y * 0.45
	var gy1: float = s.screen_center.y + s.screen_size.y * 0.3
	var gx1: float = outline_half(s, gy1) * RIM_INSET - 0.15
	if gx1 - gx0 > 0.45:
		for side: float in [-1.0, 1.0]:
			var cx: float = side * (gx0 + gx1) * 0.5
			m.box(Vector3(cx, (gy0 + gy1) * 0.5, 0.12), Vector3(gx1 - gx0, gy1 - gy0, 0.2), HULL, 0.0, MeshKit.PAT_PLAIN,
				MeshKit.ALL_FACES & ~MeshKit.FACE_NZ)
			var y: float = gy0 + 0.22
			while y < gy1 - 0.15:
				m.box(Vector3(cx, y, 0.24), Vector3(gx1 - gx0 - 0.2, 0.1, 0.05), HULL_DARK, 0.0, MeshKit.PAT_PLAIN,
					MeshKit.ALL_FACES & ~MeshKit.FACE_NZ)
				y += 0.28


## The screen's frame and the heavy brow over it, with a cold light line under the brow.
static func _screen_frame(m: MeshLayer, s: Shape) -> void:
	var c: Vector3 = s.screen_center
	var sw: float = s.screen_size.x
	var sh: float = s.screen_size.y
	var b: float = BEZEL_WIDTH
	var depth: float = 0.5
	var zc: float = depth * 0.5
	m.box(Vector3(0.0, c.y + sh * 0.5 + b * 0.5, zc), Vector3(sw + b * 2.0, b, depth), BEZEL)
	m.box(Vector3(0.0, c.y - sh * 0.5 - b * 0.5, zc), Vector3(sw + b * 2.0, b, depth), BEZEL)
	for side: float in [-1.0, 1.0]:
		m.box(Vector3(side * (sw + b) * 0.5, c.y, zc), Vector3(b, sh, depth), BEZEL)
	# A dark well behind the screen's glass, so the frame's inside reads as depth.
	m.rect(Vector3(-sw * 0.5, c.y - sh * 0.5, 0.05), Vector3(sw, 0, 0), Vector3(0, sh, 0), BEZEL)
	var brow_h: float = s.brow_top - s.brow_bottom
	m.box(Vector3(0.0, s.brow_bottom + brow_h * 0.5, 0.5), Vector3(s.brow_half * 2.0, brow_h, 1.0), HULL_LIGHT, 0.0,
		MeshKit.PAT_PLAIN, MeshKit.ALL_FACES & ~MeshKit.FACE_NZ)
	m.box(Vector3(0.0, s.brow_bottom + 0.04, 1.01), Vector3(s.brow_half * 2.0 - 0.3, 0.07, 0.04), LIGHT, 0.9,
		MeshKit.PAT_PLAIN, MeshKit.FACE_PZ | MeshKit.FACE_NY)


## The mouth: a muzzle standing out of the face, hollow and dark inside, faintly lit deep in (the jaw
## closes its front).
static func _muzzle(m: MeshLayer, s: Shape) -> void:
	var x: float = s.mouth_half
	var y0: float = s.mouth_bottom
	var y1: float = s.mouth_top
	var z0: float = 0.02
	var z1: float = s.mouth_front
	var t: float = 0.14
	var zc: float = (z0 + z1) * 0.5
	var d: float = z1 - z0
	m.box(Vector3(0.0, y1 + t * 0.5, zc), Vector3(x * 2.0 + t * 2.0, t, d), PLATE)
	m.box(Vector3(0.0, y0 - t * 0.5, zc), Vector3(x * 2.0 + t * 2.0, t, d), PLATE)
	for side: float in [-1.0, 1.0]:
		m.box(Vector3(side * (x + t * 0.5), (y0 + y1) * 0.5, zc), Vector3(t, y1 - y0, d), PLATE)
	m.rect(Vector3(-x, y0, z0 + 0.02), Vector3(x * 2.0, 0, 0), Vector3(0, y1 - y0, 0), Color(0.3, 0.34, 0.45), 0.1)
	m.box(Vector3(0.0, y0 - t - 0.2, z1 * 0.5), Vector3(x * 1.6, 0.4, z1), HULL_LIGHT, 0.0, MeshKit.PAT_PLAIN,
		MeshKit.ALL_FACES & ~MeshKit.FACE_NZ)


## Engine vents at the jaw's corners: slatted grilles glowing blue toward the player (slots, not
## rounds, so they never read as a second pair of eyes).
static func _nozzles(m: MeshLayer, g: MeshLayer, s: Shape) -> void:
	var r: float = s.nozzle_radius
	for side: float in [-1.0, 1.0]:
		var c := Vector3(side * s.nozzle.x, s.nozzle.y, 0.0)
		m.box(c + Vector3(0, 0, 0.25), Vector3(r * 2.0, r * 1.5, 0.5), HULL_DARK, 0.0, MeshKit.PAT_PLAIN,
			MeshKit.ALL_FACES & ~MeshKit.FACE_NZ)
		for k: int in 3:
			var y: float = c.y + (float(k) - 1.0) * r * 0.42
			m.box(Vector3(c.x, y, 0.51), Vector3(r * 1.6, r * 0.16, 0.02), ENGINE, 0.8, MeshKit.PAT_PLAIN, MeshKit.FACE_PZ)
		g.rect(c + Vector3(-r * 1.8, -r * 1.4, 0.7), Vector3(r * 3.6, 0, 0), Vector3(0, r * 2.8, 0), ENGINE, 0.25,
			MeshKit.SHAPE_RADIAL)


## Loudspeaker "ears" on the head's sides, just behind the face (it shouts its propaganda): big drums
## standing out into the street's margin, so the head reads as a head from behind, their grilles
## facing out.
static func _ears(m: MeshLayer, s: Shape) -> void:
	var r: float = 0.14 * s.height
	var y: float = 0.55 * s.height
	var z: float = -0.12 * s.length
	var x0: float = 0.5 * s.width * _section(s, z).x
	for side: float in [-1.0, 1.0]:
		var drum := func(radius: float, from: float, length: float, color: Color, glow: float) -> void:
			m.prism_xform(Transform3D(Basis(Vector3(0, 0, radius), Vector3(side * length, 0, 0), Vector3(0, radius, 0)),
				Vector3(side * (x0 + from), y, z)), 10, color, glow)
		drum.call(r, -0.2, EAR_OUT + 0.2, HULL_DARK, 0.0)
		drum.call(r * 1.07, EAR_OUT - 0.14, 0.1, LIGHT, 0.25)
		drum.call(r * 0.34, EAR_OUT, 0.06, LIGHT, 0.3)
		var gy: float = -r * 0.62
		while gy < r * 0.64:
			var half: float = sqrt(maxf(r * r * 0.72 - gy * gy, 0.0))
			if half > 0.2 and absf(gy) > r * 0.3:
				m.box(Vector3(side * (x0 + EAR_OUT + 0.01), y + gy, z), Vector3(0.04, 0.09, half * 2.0), HULL, 0.0)
			gy += 0.26


# --- The belly and the crown -------------------------------------------------------------------

static func _belly(m: MeshLayer, g: MeshLayer, s: Shape) -> void:
	var w: float = s.width
	var l: float = s.length
	var down: int = MeshKit.ALL_FACES & ~MeshKit.FACE_PY
	# The searchlight's gimbal mount under the chin.
	var lp: Vector3 = s.lamp_pivot
	m.prism(Vector3(lp.x, lp.y + 0.25, lp.z), 0.34, -lp.y - 0.25 + 0.02, 8, HULL_DARK, 0.0, MeshKit.PAT_PLAIN, true)
	m.box(Vector3(lp.x, -0.08, lp.z), Vector3(1.4, 0.16, 1.4), HULL, 0.0, MeshKit.PAT_PLAIN, down)
	# The bomb bay: a dark opening in a raised frame (its doors are separate parts).
	var bc: Vector3 = s.bay_center
	var bh: float = s.bay_half
	var bl: float = s.bay_length
	m.rect(Vector3(-bh, -0.02, bc.z - bl * 0.5), Vector3(bh * 2.0, 0, 0), Vector3(0, 0, bl), MOUTH)
	for side: float in [-1.0, 1.0]:
		m.box(Vector3(side * (bh + 0.12), -0.07, bc.z), Vector3(0.24, 0.14, bl + 0.48), HULL_LIGHT, 0.0, MeshKit.PAT_PLAIN, down)
		m.box(Vector3(0.0, -0.07, bc.z + side * (bl * 0.5 + 0.12)), Vector3(bh * 2.0, 0.14, 0.24), HULL_LIGHT, 0.0,
			MeshKit.PAT_PLAIN, down)
	# The keel, from behind the bay along the flat of the belly.
	var k0: float = bc.z - bl * 0.5 - 0.6
	var k1: float = -0.5 * l
	if k0 - k1 > 0.5:
		m.box(Vector3(0.0, belly_height(s, (k0 + k1) * 0.5), (k0 + k1) * 0.5), Vector3(0.5, 0.44, k0 - k1), HULL_DARK, 0.0,
			MeshKit.PAT_PLAIN, down)
	# Lift pads: glowing discs holding it up, with a soft wash below.
	for z: float in [-0.46 * l, -0.66 * l]:
		for side: float in [-1.0, 1.0]:
			var at := Vector3(side * 0.12 * w * _section(s, z).x, belly_height(s, z) - 0.02, z)
			m.prism(at + Vector3(0, -0.06, 0), 0.62, 0.06, 10, HULL_DARK)
			m.prism(at + Vector3(0, -0.08, 0), 0.46, 0.02, 10, ENGINE, 1.0)
			g.rect(at + Vector3(-1.4, -0.12, -1.4), Vector3(2.8, 0, 0), Vector3(0, 0, 2.8), ENGINE, 0.5, MeshKit.SHAPE_RADIAL)
	# Running lights down both edges of the belly.
	var z0: float = -2.2
	while z0 > -0.56 * l:
		for side: float in [-1.0, 1.0]:
			m.box(Vector3(side * 0.18 * w * _section(s, z0).x, belly_height(s, z0) - 0.03, z0), Vector3(0.12, 0.06, 0.34), LIGHT,
				0.8, MeshKit.PAT_PLAIN, down)
		z0 -= 2.6


static func _crown(m: MeshLayer, s: Shape) -> void:
	var w: float = s.width
	var l: float = s.length
	# The weak points' sockets, standing proud of the crown (the covers and the red domes are parts of
	# their own).
	for p: Vector3 in s.weak_points:
		m.prism(p + Vector3(0, -0.6, 0), 0.95, 0.6, 10, HULL_DARK)
	# Dorsal fins along the crown toward the bow, and antenna masts.
	for z: float in [-0.4 * l, -0.52 * l, -0.64 * l]:
		var top: float = crown_height(s, 0.0, z)
		m.box_xform(Transform3D(Basis.from_euler(Vector3(0.45, 0.0, 0.0)) * Basis.from_scale(Vector3(0.14, 1.3, 2.4)),
			Vector3(0.0, top + 0.45, z)), HULL_DARK)
	for mast: Vector2 in [Vector2(-0.14, -0.6), Vector2(0.14, -0.7)]:
		var z: float = mast.y * l
		var base := Vector3(mast.x * w, crown_height(s, mast.x, z) - 0.1, z)
		m.prism(base, 0.07, 3.0, 5, HULL_LIGHT)
		m.prism(base + Vector3(0, 3.0, 0), 0.12, 0.14, 6, LIGHT, 1.0)


# --- Moving parts -----------------------------------------------------------------------------

## The face screen: a quad the size of the screen, its UV 0-1 across and up as the viewer sees it,
## UV2.y its aspect (FloatingHeadBody sets the material on the instance).
static func _screen(s: Shape) -> ArrayMesh:
	var batch := MeshBatch.new()
	var l: MeshLayer = batch.layer(null)
	var sw: float = s.screen_size.x
	var sh: float = s.screen_size.y
	l.rect(Vector3(-sw * 0.5, -sh * 0.5, 0.0), Vector3(sw, 0, 0), Vector3(0, sh, 0), Color.WHITE, 1.0, 0,
		Vector2.ZERO, Vector2.ONE, sw / sh)
	return batch.to_mesh()


## The jaw, hanging from its hinge (hinge space: it closes the muzzle's front, from y = 0 down to
## the mouth's height, and faces +z): a heavy trapezoid plate, narrower at the chin, with dark teeth
## slots and a thick lower lip.
static func _jaw(s: Shape) -> ArrayMesh:
	var batch := MeshBatch.new()
	var m: MeshLayer = batch.layer(solid_material())
	var jh: float = s.mouth_top - s.mouth_bottom + 0.16
	var top: float = s.mouth_half + 0.2
	var bottom: float = top * 0.74
	var d: float = 0.5
	var a := Vector3(-top, 0.0, 0.0)
	var b := Vector3(top, 0.0, 0.0)
	var c := Vector3(bottom, -jh, 0.0)
	var e := Vector3(-bottom, -jh, 0.0)
	var f := Vector3(0, 0, d)
	m.quad(e + f, a + f, b + f, c + f, PLATE)
	m.quad(a, a + f, e + f, e, HULL)
	m.quad(c, c + f, b + f, b, HULL)
	m.quad(a, b, b + f, a + f, HULL_LIGHT)
	m.quad(e, e + f, c + f, c, HULL_DARK)
	var slots: int = maxi(int(bottom * 2.0 / 0.4), 3)
	for i: int in slots:
		var x: float = -bottom + (float(i) + 0.5) * bottom * 2.0 / slots
		m.box(Vector3(x, -0.22 - jh * 0.28, d + 0.02), Vector3(0.12, jh * 0.46, 0.05), HULL_DARK, 0.0, MeshKit.PAT_PLAIN,
			MeshKit.ALL_FACES & ~MeshKit.FACE_NZ)
	m.box(Vector3(0.0, -jh + 0.18, d * 0.5 + 0.08), Vector3(bottom * 2.0 + 0.1, 0.36, d + 0.16), HULL_LIGHT)
	return batch.to_mesh()


## The lip line along the jaw's top edge (hinge space): it lights up with the face (FloatingHeadBody),
## the mouth in the face's cold white.
static func _lip(s: Shape) -> ArrayMesh:
	var batch := MeshBatch.new()
	var l: MeshLayer = batch.layer(null)
	var w: float = (s.mouth_half + 0.2) * 2.0 - 0.3
	l.box(Vector3(0.0, -0.1, 0.52), Vector3(w, 0.1, 0.04), Color.WHITE, 1.0, MeshKit.PAT_PLAIN, MeshKit.FACE_PZ)
	return batch.to_mesh()


## The searchlight's head, pointing along -z from its gimbal: a dark drum with cooling fins and a yoke
## (its lens is a part of its own, lit by state).
static func _lamp() -> ArrayMesh:
	var batch := MeshBatch.new()
	var m: MeshLayer = batch.layer(solid_material())
	_prism_along_z(m, Vector3(0.0, 0.0, 0.1), 0.5, 1.0, 10, HULL_DARK, 0.0)
	_prism_along_z(m, Vector3(0.0, 0.0, -0.44), 0.56, 0.12, 10, HULL, 0.0)
	for i: int in 3:
		_prism_along_z(m, Vector3(0.0, 0.0, 0.2 + i * 0.16), 0.56, 0.05, 10, HULL, 0.0)
	for side: float in [-1.0, 1.0]:
		m.box(Vector3(side * 0.58, 0.0, 0.0), Vector3(0.1, 0.32, 0.32), HULL_LIGHT)
	return batch.to_mesh()


## The searchlight's lens (lamp-head space), lit per state by its material.
static func _lens() -> ArrayMesh:
	var batch := MeshBatch.new()
	var l: MeshLayer = batch.layer(null)
	_prism_along_z(l, Vector3(0.0, 0.0, -0.51), 0.46, 0.03, 10, Color.WHITE, 1.0)
	return batch.to_mesh()


## One bomb-bay door (hinge space: it reaches along +x from the hinge, under the belly).
static func _door(s: Shape) -> ArrayMesh:
	var batch := MeshBatch.new()
	var m: MeshLayer = batch.layer(solid_material())
	m.box(Vector3(s.bay_half * 0.5, -0.05, 0.0), Vector3(s.bay_half, 0.1, s.bay_length), HULL)
	m.box(Vector3(s.bay_half * 0.5, -0.11, 0.0), Vector3(s.bay_half * 0.6, 0.03, s.bay_length * 0.7), HULL_DARK, 0.0,
		MeshKit.PAT_PLAIN, MeshKit.ALL_FACES & ~MeshKit.FACE_PY)
	return batch.to_mesh()


## A weak point's armoured cover, closed over its socket until a stomp window opens (FloatingHeadBody
## swings it open about its back edge).
static func _cover() -> ArrayMesh:
	var batch := MeshBatch.new()
	var m: MeshLayer = batch.layer(solid_material())
	_frustum(m, Transform3D.IDENTITY, 0.85, 0.5, 0.34, 8, HULL_LIGHT, 0.0)
	return batch.to_mesh()


## A weak point: a glowing red dome on a dark ring, the hover truck's language (GDD §10).
static func _weak_dome() -> ArrayMesh:
	var batch := MeshBatch.new()
	var m: MeshLayer = batch.layer(solid_material())
	m.prism(Vector3.ZERO, 0.85, 0.08, 10, HULL_DARK)
	_frustum(m, Transform3D(Basis.IDENTITY, Vector3(0, 0.08, 0)), 0.62, 0.42, 0.22, 10, WEAK, 1.1)
	_frustum(m, Transform3D(Basis.IDENTITY, Vector3(0, 0.3, 0)), 0.42, 0.12, 0.16, 10, WEAK, 1.3)
	return batch.to_mesh()


# --- Helpers ------------------------------------------------------------------------------------

## A thin square bar from a to b (a trim line, a rib), its thickness across `face` (the side it faces).
static func _bar(m: MeshLayer, a: Vector3, b: Vector3, thickness: float, color: Color, glow: float,
		face: Vector3) -> void:
	var d: Vector3 = b - a
	var length: float = d.length()
	if length < 0.01:
		return
	var along: Vector3 = d / length
	var side: Vector3 = along.cross(face)
	if side.length() < 0.01:
		side = along.cross(Vector3.UP if absf(along.y) < 0.9 else Vector3.RIGHT)
	side = side.normalized()
	var up: Vector3 = side.cross(along).normalized()
	m.box_xform(Transform3D(Basis(side * thickness, along * length, up * thickness), (a + b) * 0.5), color, glow)


## A prism along -z: its centre at `center`, `radius` to its corners, `length` long.
static func _prism_along_z(m: MeshLayer, center: Vector3, radius: float, length: float, sides: int, color: Color,
		glow: float) -> void:
	m.prism_xform(Transform3D(Basis(Vector3(radius, 0, 0), Vector3(0, 0, -length), Vector3(0, radius, 0)),
		center + Vector3(0, 0, length * 0.5)), sides, color, glow)


## A tapered prism (radius r0 at its base, r1 at its top, `height` tall along +y), placed by `xform`.
static func _frustum(m: MeshLayer, xform: Transform3D, r0: float, r1: float, height: float, sides: int, color: Color,
		glow: float) -> void:
	var bottom: Array[Vector3] = []
	var top: Array[Vector3] = []
	for i: int in sides:
		var a: float = TAU * (float(i) + 0.5) / float(sides)
		bottom.append(xform * Vector3(cos(a) * r0, 0.0, sin(a) * r0))
		top.append(xform * Vector3(cos(a) * r1, height, sin(a) * r1))
	var c0: Vector3 = xform * Vector3.ZERO
	var c1: Vector3 = xform * Vector3(0.0, height, 0.0)
	for i: int in sides:
		var j: int = (i + 1) % sides
		m.quad(bottom[j], top[j], top[i], bottom[i], color, glow)
		_tri(m, c1, top[i], top[j], color, glow)
		_tri(m, c0, bottom[j], bottom[i], color, glow)


## One triangle (clockwise seen from its front).
static func _tri(m: MeshLayer, a: Vector3, b: Vector3, c: Vector3, color: Color, glow: float) -> void:
	m.verts.append_array(PackedVector3Array([a, b, c]))
	var col := Color(color, glow)
	m.colors.append_array(PackedColorArray([col, col, col]))
	m.uvs.append_array(PackedVector2Array([Vector2(0.5, 0.5), Vector2(0, 0), Vector2(1, 0)]))
	m.uv2s.append_array(PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]))
