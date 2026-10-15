class_name CaptainCogsModel
extends RefCounted
## Captain Cogs' ship (GDD §10: "a floating ship flying above the track"; "a pirate mixed with a futuristic look"; task
## E5e-b2), built once in code per skin and shared, low-poly and flat-shaded through the mesh kit (the skin's solid and
## glow materials). Its local space: the origin at the middle of its keel, +y up, -z its bow (it flies the runner's
## way, ahead of them, its stern toward them), x across.
## - hull: a pirate galleon's: a tapering wooden hull in dark planks with brass bands, a deck, the raised stern castle
##   at the back (where the captain stands, CAPTAIN_SPOT) with its rail and two stern lanterns, gun ports and iron
##   cannons along its sides, a bowsprit; the mast with its yard, a patched sail bearing a skull with cog teeth and the
##   flag at its top; a neon trim along its gunwales in the Beach's violet, and under the hull four hover pods glowing
##   the Beach's engine colour (a pale violet-blue): the futuristic side. Nothing glows in a hazard colour.
## - wheel: one of the two brass cog wheels on its flanks (CaptainCogsShip turns them), a unit about its axle (x).
## The hull is built in two halves (task E5e-c: the defeat, Mecha Guppy biting the ship in two): `bow` (everything ahead
## of SPLIT_Z: the bow, the mast, its sail and flag, the bowsprit, a broken bulkhead across the cut, hidden inside the
## hull while it's whole) and `stern` (the rest: the stern castle where the captain stands, its rail and lanterns, the
## transom). Whole, the two meshes sit together and read as one ship.
## Hidden from the climb's physics entirely: it has no collision, so a pad never flips a runner to it
## (Player._ceiling_over_pad looks only for the hull layer).
## DESIGN-TBD (docs/OPEN_QUESTIONS.md item 787): its look and size.

## Its length, beam and the deck's height over the keel; the stern castle's deck and where it starts.
const LENGTH: float = 16.0
const BEAM: float = 6.0
const DECK: float = 3.2
const CASTLE: float = 4.7
const CASTLE_FROM: float = 3.6
## Where the hull splits into its bow and stern halves (task E5e-c, the gulp), along z.
const SPLIT_Z: float = 1.0
## Where the captain stands (on the stern castle, near its rail), and the cog wheels' axle and radius.
const CAPTAIN_SPOT := Vector3(0.0, CASTLE, 6.9)
const WHEEL_AT := Vector3(BEAM * 0.5 + 0.35, 1.9, -0.5)
const WHEEL_RADIUS: float = 2.1
## The cannons along each side (bow to stern), and how far a cannon's muzzle stands out of its port.
const CANNONS: int = 3
const CANNON_OUT: float = 0.45

const WOOD := Color(0.31, 0.2, 0.12)
const WOOD_DARK := Color(0.2, 0.13, 0.08)
const DECK_WOOD := Color(0.44, 0.33, 0.22)
const BRASS := Color(0.78, 0.6, 0.3)
const IRON := Color(0.1, 0.1, 0.11)
const CANVAS := Color(0.8, 0.75, 0.64)
const CANVAS_PATCH := Color(0.68, 0.62, 0.5)
const EMBLEM := Color(0.12, 0.1, 0.09)
const BONE := Color(0.9, 0.88, 0.82)
const FLAG := Color(0.06, 0.06, 0.07)

static var _cache: Dictionary = {}


## The meshes in `skin`'s materials: {bow, stern (the hull's two halves, SPLIT_Z), wheel}. Cached per skin.
static func meshes(skin: BeachSkin) -> Dictionary:
	var key: int = skin.get_instance_id()
	if _cache.has(key):
		return _cache[key]
	var bow := MeshBatch.new()
	var stern := MeshBatch.new()
	var halves := Halves.new(bow.layer(skin.solid_material()), bow.layer(skin.glow_material()),
		stern.layer(skin.solid_material()), stern.layer(skin.glow_material()))
	_hull(halves, skin)
	var wheel := MeshBatch.new()
	_wheel(wheel.layer(skin.solid_material()))
	var out: Dictionary = {"bow": bow.to_mesh(), "stern": stern.to_mesh(), "wheel": wheel.to_mesh()}
	_cache[key] = out
	return out


## The hull's two halves' layers (solid and glow): s(z) and g(z) give the half a piece at `z` belongs to.
class Halves:
	var bow_s: MeshLayer
	var bow_g: MeshLayer
	var stern_s: MeshLayer
	var stern_g: MeshLayer

	func _init(p_bow_s: MeshLayer, p_bow_g: MeshLayer, p_stern_s: MeshLayer, p_stern_g: MeshLayer) -> void:
		bow_s = p_bow_s
		bow_g = p_bow_g
		stern_s = p_stern_s
		stern_g = p_stern_g

	func s(z: float) -> MeshLayer:
		return bow_s if z < CaptainCogsModel.SPLIT_Z else stern_s

	func g(z: float) -> MeshLayer:
		return bow_g if z < CaptainCogsModel.SPLIT_Z else stern_g


## The hull's half width at height `y` over the keel and `z` along it (-z the bow): narrow at the keel, full at the deck,
## tapering to the bow's point, square at the stern.
static func half_beam(y: float, z: float) -> float:
	var k: float = clampf(y / DECK, 0.0, 1.0)
	var section: float = lerpf(0.32, 1.0, sqrt(k))
	var bow: float = clampf((z + LENGTH * 0.5) / (LENGTH * 0.42), 0.0, 1.0)
	return BEAM * 0.5 * section * lerpf(0.12, 1.0, sqrt(bow))


static func _hull(h: Halves, skin: BeachSkin) -> void:
	var zs: Array[float] = [-LENGTH * 0.5, -LENGTH * 0.38, -LENGTH * 0.22, -LENGTH * 0.05, SPLIT_Z, LENGTH * 0.15, LENGTH * 0.35,
		LENGTH * 0.5]
	var ys: Array[float] = [0.0, DECK * 0.35, DECK * 0.7, DECK]
	# The sides, plank by plank (alternating tones), and the bottom.
	for i: int in zs.size() - 1:
		var s: MeshLayer = h.s((zs[i] + zs[i + 1]) * 0.5)
		for j: int in ys.size() - 1:
			var tone: Color = WOOD if (i + j) % 2 == 0 else WOOD_DARK
			for side: float in [-1.0, 1.0]:
				var a := Vector3(side * half_beam(ys[j], zs[i]), ys[j], zs[i])
				var b := Vector3(side * half_beam(ys[j], zs[i + 1]), ys[j], zs[i + 1])
				var c := Vector3(side * half_beam(ys[j + 1], zs[i + 1]), ys[j + 1], zs[i + 1])
				var d := Vector3(side * half_beam(ys[j + 1], zs[i]), ys[j + 1], zs[i])
				_face(s, a, b, c, d, Vector3(side, -0.2, 0.0), tone)
		var w0: float = half_beam(0.0, zs[i])
		var w1: float = half_beam(0.0, zs[i + 1])
		_face(s, Vector3(-w0, 0.0, zs[i]), Vector3(w0, 0.0, zs[i]), Vector3(w1, 0.0, zs[i + 1]), Vector3(-w1, 0.0, zs[i + 1]),
			Vector3.DOWN, WOOD_DARK)
	# The broken bulkhead across the cut, on the bow half (inside the whole hull, it shows only once the halves part): dark
	# splintered timber over the hull's cross-section, facing the stern.
	var bow_s: MeshLayer = h.s(SPLIT_Z - 0.01)
	var cut: float = SPLIT_Z - 0.02
	for j: int in ys.size() - 1:
		var wa: float = half_beam(ys[j], cut) - 0.02
		var wb2: float = half_beam(ys[j + 1], cut) - 0.02
		_face(bow_s, Vector3(-wa, ys[j], cut), Vector3(wa, ys[j], cut), Vector3(wb2, ys[j + 1], cut), Vector3(-wb2, ys[j + 1], cut),
			Vector3(0.0, 0.0, 1.0), WOOD_DARK * 0.55)
	for k: int in 5:
		var x: float = lerpf(-2.2, 2.2, float(k) / 4.0)
		bow_s.box(Vector3(x, DECK - 0.1 + 0.18 * float(k % 2), cut + 0.15), Vector3(0.22, 0.5 + 0.3 * float(k % 3), 0.3),
			WOOD_DARK * 0.7)
	# Brass bands round the hull.
	for z: float in [-LENGTH * 0.3, 0.0, LENGTH * 0.3]:
		var s: MeshLayer = h.s(z)
		for j: int in ys.size() - 1:
			for side: float in [-1.0, 1.0]:
				var a := Vector3(side * (half_beam(ys[j], z) + 0.03), ys[j], z - 0.12)
				var b := Vector3(side * (half_beam(ys[j], z) + 0.03), ys[j], z + 0.12)
				var c := Vector3(side * (half_beam(ys[j + 1], z) + 0.03), ys[j + 1], z + 0.12)
				var d := Vector3(side * (half_beam(ys[j + 1], z) + 0.03), ys[j + 1], z - 0.12)
				_face(s, a, b, c, d, Vector3(side, 0.0, 0.0), BRASS)
	# The stern's transom and the deck.
	var back: float = LENGTH * 0.5
	var wb: float = half_beam(DECK, back)
	h.s(back).rect(Vector3(-wb, 0.0, back), Vector3(wb * 2.0, 0.0, 0.0), Vector3(0.0, DECK, 0.0), WOOD_DARK)
	for i: int in zs.size() - 1:
		var w0: float = half_beam(DECK, zs[i]) - 0.05
		var w1: float = half_beam(DECK, zs[i + 1]) - 0.05
		_face(h.s((zs[i] + zs[i + 1]) * 0.5), Vector3(-w0, DECK, zs[i]), Vector3(w0, DECK, zs[i]), Vector3(w1, DECK, zs[i + 1]),
			Vector3(-w1, DECK, zs[i + 1]), Vector3.UP, DECK_WOOD)
	# The gunwales, with the neon trim (the Beach's violet) along them, and gun ports with cannons.
	for side: float in [-1.0, 1.0]:
		for i: int in zs.size() - 1:
			var s: MeshLayer = h.s((zs[i] + zs[i + 1]) * 0.5)
			var a := Vector3(side * half_beam(DECK, zs[i]), DECK, zs[i])
			var b := Vector3(side * half_beam(DECK, zs[i + 1]), DECK, zs[i + 1])
			_face(s, a, b, b + Vector3(0, 0.55, 0), a + Vector3(0, 0.55, 0), Vector3(side, 0.0, 0.0), WOOD)
			_face(s, a + Vector3(side * 0.02, 0.36, 0), b + Vector3(side * 0.02, 0.36, 0), b + Vector3(side * 0.02, 0.44, 0),
				a + Vector3(side * 0.02, 0.44, 0), Vector3(side, 0.0, 0.0), skin.neon_violet, skin.neon_glow * 1.4)
		for k: int in CANNONS:
			var at: Vector3 = cannon_at(int(side), k)
			var s: MeshLayer = h.s(at.z)
			s.box(Vector3(at.x - side * CANNON_OUT + side * 0.02, at.y, at.z), Vector3(0.06, 0.5, 0.6), IRON)
			s.prism_xform(Transform3D(Basis(Vector3.BACK, -side * PI * 0.5).scaled(Vector3(0.16, 0.9, 0.16)),
				Vector3(at.x - side * CANNON_OUT, at.y, at.z)), 8, IRON)
	# The stern castle: its deck, its front face, the rail at its back and sides, the stern lanterns.
	var st: MeshLayer = h.s(back)
	var c0: float = CASTLE_FROM
	var cw0: float = half_beam(DECK, c0) - 0.05
	st.box(Vector3(0.0, (DECK + CASTLE) * 0.5, (c0 + back) * 0.5), Vector3(cw0 * 2.0, CASTLE - DECK, back - c0), WOOD,
		0.0, MeshKit.PAT_PLAIN, MeshKit.ALL_FACES & ~MeshKit.FACE_NY)
	st.rect(Vector3(-cw0, CASTLE + 0.005, back), Vector3(cw0 * 2.0, 0.0, 0.0), Vector3(0.0, 0.0, -(back - c0)), DECK_WOOD)
	for side: float in [-1.0, 1.0]:
		st.box(Vector3(side * (cw0 - 0.08), CASTLE + 0.45, (c0 + back) * 0.5), Vector3(0.1, 0.9, back - c0), WOOD_DARK)
	st.box(Vector3(0.0, CASTLE + 0.45, back - 0.08), Vector3(cw0 * 2.0, 0.9, 0.1), WOOD_DARK)
	for side: float in [-1.0, 1.0]:
		var lamp := Vector3(side * (cw0 - 0.1), CASTLE + 1.3, back - 0.1)
		st.box(lamp + Vector3(0.0, -0.35, 0.0), Vector3(0.08, 0.7, 0.08), BRASS)
		st.box(lamp, Vector3(0.3, 0.4, 0.3), skin.lamp_color, skin.lamp_glow)
		h.g(back).rect(lamp + Vector3(-0.8, -0.8, 0.12), Vector3(1.6, 0.0, 0.0), Vector3(0.0, 1.6, 0.0), skin.lamp_color, 0.22,
			MeshKit.SHAPE_RADIAL)
	# The bowsprit.
	var bw: MeshLayer = h.s(-LENGTH * 0.5)
	var tip := Vector3(0.0, DECK + 1.6, -LENGTH * 0.5 - 3.2)
	_beam(bw, Vector3(0.0, DECK + 0.4, -LENGTH * 0.45), tip, 0.16, WOOD_DARK)
	# The mast, its yard and the patched sail with the skull and cogs; the flag at its top.
	var mast_z: float = -1.2
	bw.prism(Vector3(0.0, DECK, mast_z), 0.2, 11.5, 8, WOOD_DARK)
	bw.box(Vector3(0.0, DECK + 9.2, mast_z), Vector3(7.4, 0.22, 0.22), WOOD_DARK)
	bw.box(Vector3(0.0, DECK + 4.2, mast_z), Vector3(5.4, 0.18, 0.18), WOOD_DARK)
	var sail_top: float = DECK + 9.0
	var sail_bottom: float = DECK + 4.4
	_face(bw, Vector3(-3.5, sail_top, mast_z + 0.2), Vector3(3.5, sail_top, mast_z + 0.2), Vector3(2.6, sail_bottom, mast_z + 0.6),
		Vector3(-2.6, sail_bottom, mast_z + 0.6), Vector3(0.0, 0.0, 1.0), CANVAS)
	_face(bw, Vector3(-3.5, sail_top, mast_z + 0.18), Vector3(3.5, sail_top, mast_z + 0.18), Vector3(2.6, sail_bottom, mast_z + 0.58),
		Vector3(-2.6, sail_bottom, mast_z + 0.58), Vector3(0.0, 0.0, -1.0), CANVAS_PATCH)
	_skull(bw, Vector3(0.0, (sail_top + sail_bottom) * 0.5, mast_z + 0.45))
	bw.box(Vector3(0.7, DECK + 11.0, mast_z), Vector3(1.4, 0.8, 0.04), FLAG)
	bw.box(Vector3(0.75, DECK + 11.05, mast_z + 0.03), Vector3(0.36, 0.34, 0.02), BONE)
	# The hover pods under the hull, glowing the Beach's engine colour.
	for side: float in [-1.0, 1.0]:
		for z: float in [-LENGTH * 0.28, LENGTH * 0.28]:
			var pod := Vector3(side * BEAM * 0.28, -0.35, z)
			h.s(z).box(pod, Vector3(1.0, 0.7, 1.6), IRON)
			h.s(z).box(pod + Vector3(0.0, -0.37, 0.0), Vector3(0.75, 0.05, 1.3), skin.engine_color, 0.9)
			h.g(z).rect(pod + Vector3(-1.1, -0.45, 1.3), Vector3(2.2, 0.0, 0.0), Vector3(0.0, 0.0, -2.6), skin.engine_color, 0.35,
				MeshKit.SHAPE_RADIAL)


## Where cannon `k` (0 to CANNONS - 1, bow to stern) on side `side` (-1 left, +1 right) has its muzzle, in the ship's
## space: just out of its gun port (CaptainCogsShip fires phase 3's rounds from there, task E5e-c).
static func cannon_at(side: int, k: int) -> Vector3:
	var z: float = lerpf(-LENGTH * 0.18, LENGTH * 0.22, float(k) / float(maxi(CANNONS - 1, 1)))
	return Vector3(float(side) * (half_beam(DECK * 0.62, z) + CANNON_OUT), DECK * 0.62, z)


## The sail's emblem: a skull with cog teeth round it, painted dark, facing the runner (+z).
static func _skull(s: MeshLayer, c: Vector3) -> void:
	var teeth: int = 10
	for i: int in teeth:
		var a: float = TAU * float(i) / float(teeth)
		s.box(c + Vector3(cos(a) * 1.25, sin(a) * 1.25, 0.0), Vector3(0.36, 0.36, 0.04), EMBLEM)
	s.box(c, Vector3(2.0, 2.0, 0.03), EMBLEM)
	s.box(c + Vector3(0.0, 0.15, 0.02), Vector3(1.0, 0.85, 0.03), BONE)
	s.box(c + Vector3(0.0, -0.4, 0.02), Vector3(0.6, 0.35, 0.03), BONE)
	for x: float in [-0.24, 0.24]:
		s.box(c + Vector3(x, 0.2, 0.04), Vector3(0.26, 0.26, 0.03), EMBLEM)


## A brass cog wheel about its axle (x), radius 1: rim, spokes, hub and teeth.
static func _wheel(s: MeshLayer) -> void:
	var teeth: int = 14
	s.prism_xform(Transform3D(Basis(Vector3.BACK, PI * 0.5).scaled(Vector3(0.84, 0.18, 0.84)), Vector3(0.09, 0.0, 0.0)), 14, BRASS)
	for i: int in teeth:
		var a: float = TAU * float(i) / float(teeth)
		s.box_xform(Transform3D(Basis(Vector3.RIGHT, a).scaled(Vector3(0.16, 0.28, 0.2)), Vector3(0.0, cos(a) * 0.96, sin(a) * 0.96)),
			BRASS)
	for i: int in 4:
		var a: float = TAU * float(i) / 4.0
		s.box_xform(Transform3D(Basis(Vector3.RIGHT, a).scaled(Vector3(0.12, 1.6, 0.12)), Vector3(0.1, 0.0, 0.0)), IRON)
	s.prism_xform(Transform3D(Basis(Vector3.BACK, PI * 0.5).scaled(Vector3(0.22, 0.3, 0.22)), Vector3(0.15, 0.0, 0.0)), 8, IRON)


## A square beam from `a` to `b`, `w` thick.
static func _beam(s: MeshLayer, a: Vector3, b: Vector3, w: float, color: Color) -> void:
	var length: float = a.distance_to(b)
	if length < 0.05:
		return
	var dir: Vector3 = (b - a) / length
	var up: Vector3 = Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	var beam := MeshLayer.new()
	beam.box(Vector3.ZERO, Vector3(w, w, length), color)
	s.append(beam, Transform3D(Basis.looking_at(dir, up), (a + b) * 0.5))


## A patch a, b, c, d wound to face `outward` (MechaGuppySharkModel's).
static func _face(s: MeshLayer, a: Vector3, b: Vector3, c: Vector3, d: Vector3, outward: Vector3, color: Color,
		glow: float = 0.0) -> void:
	if (b - a).cross(c - a).dot(outward) > 0.0:
		s.quad(a, d, c, b, color, glow, MeshKit.PAT_PLAIN)
	else:
		s.quad(a, b, c, d, color, glow, MeshKit.PAT_PLAIN)
