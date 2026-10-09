class_name CasinoVault
extends RefCounted
## The Casino's glass roof (CasinoSkin; task K1; the owner's reference image: a covered street under a
## vaulted roof of glass and iron, with ribs, ceiling fans and hanging banners). It springs from the
## facades' top (`eave_height`) and arches over the street; its crown is higher over a wider street. It is
## background: far above anything the player can reach, and never a ceiling (a ceiling is a gameplay
## piece at the usual height, CasinoCeilings), so nothing about it is meant to read as a surface to use.
## Built in bays (`bay_length`, three panes each) that repeat down the street from cached templates
## (a few variants, so the missing panes don't repeat every bay): iron ribs along the arch, purlins
## running along the street, and the panes themselves, quads of the solid kit shader's PAT_CASINO_VAULT:
## dark glass in thin iron frames, opaque and faked (no transparency, GDD §5 and the phone rules), with
## the night sky showing only through the panes the template leaves out. Hung from it, per bay by hash:
## iron girders across the street carrying banners of heavy cloth, lanterns on chains and ceiling fans
## (a girder under the eave runs from wall to wall; the arena hangs nothing, `hangings`: The House's
## billboard drops through that space). Nothing hangs below `bunting_height` over the lanes (the arrival
## flyover's and The House's limits: the machine is 13.5 m tall, TheHouseTuning.height, and the camera flies
## under 10 m), and everything is drawn with the one solid and glow materials of the chunk's batch, so the
## roof adds no mesh surface of its own.
## Space: chunk space (x across, y up, z = -distance); bay k covers distances [k * bay_length,
## (k + 1) * bay_length) and belongs to the call whose range holds its start.

## Segments of the arch, and panes along a bay.
const ARC_SEGMENTS: int = 8
const PANES_PER_BAY: int = 3
## Template variants of a bay (which panes are missing, by hash).
const VARIANTS: int = 4
## An arch rib's depth along the street and thickness across it.
const RIB_DEPTH: float = 0.5
const RIB_THICK: float = 0.42
## Added to the least a hanging thing may reach above `bunting_height`, so nothing touches the limit.
const HANG_MARGIN: float = 0.05
## How far a girder runs into the wall it ends in.
const GIRDER_EMBED: float = 0.1
## How far a girder's banners keep from the walls (a balcony stands 0.95 m out of a face).
const BANNER_MARGIN: float = 1.0
## A ceiling fan hangs FAN_DROP under the roof; its blades reach FAN_RADIUS from the hub and must stay
## FAN_CLEARANCE inside the roof.
const FAN_DROP: float = 1.4
const FAN_RADIUS: float = 2.6
const FAN_CLEARANCE: float = 0.3

## Weak: the skin owns this builder, so a strong reference back would keep both alive forever.
var skin: CasinoSkin:
	get:
		return _skin.get_ref() as CasinoSkin
var _skin: WeakRef
var _arches: Dictionary = {}
var _bays: Dictionary = {}


func _init(p_skin: CasinoSkin) -> void:
	_skin = weakref(p_skin)


## Adds the roof over the street between two track distances (half_width: the wall faces' distance).
func build(batch: MeshBatch, half_width: float, start: float, end: float) -> void:
	var solid: MeshLayer = batch.layer(skin.solid_material())
	var glow: MeshLayer = batch.layer(skin.glow_material())
	var arch: Dictionary = arch_of(half_width)
	var length: float = skin.bay_length
	var k: int = ceili(start / length - 0.0001)
	while float(k) * length < end - 0.0001:
		var z: float = -float(k) * length
		solid.append(_bay(arch, MeshKit.hash_i(k, 5, 17) % VARIANTS), Transform3D(Basis.IDENTITY, Vector3(0, 0, z)))
		_hangings(solid, glow, arch, k, z)
		k += 1
	# The springer beams along the tops of both walls, where the roof meets them (built here, not with
	# the buildings, so they run on where a wall gap cuts a building away).
	var zc: float = -(start + end) * 0.5
	for side: float in [-1.0, 1.0]:
		solid.box(Vector3(side * (half_width - 0.12), skin.eave_height - 0.18, zc), Vector3(0.62, 0.5, end - start),
			skin.iron_color, 0.0, MeshKit.PAT_CASINO_IRON, MeshKit.ALL_FACES & ~(MeshKit.FACE_PX if side > 0.0 else MeshKit.FACE_NX), 2.0)


# --- The arch -----------------------------------------------------------------------------------

## The arch over a street whose wall faces stand `half_width` from its centre: {rise, rho (the radius of
## its circle), cy (the circle's centre height), points (Array[Vector2], left springing to right),
## crown (the highest height)}.
func arch_of(half_width: float) -> Dictionary:
	var key: int = roundi(half_width * 100.0)
	var found: Variant = _arches.get(key)
	if found != null:
		return found
	var eave: float = skin.eave_height
	var rise: float = minf(clampf(half_width * 0.9, 3.0, skin.vault_rise_max), half_width * 0.95)
	var rho: float = (half_width * half_width + rise * rise) / (2.0 * rise)
	var cy: float = eave + rise - rho
	var theta_max: float = asin(clampf(half_width / rho, 0.0, 1.0))
	var points: Array[Vector2] = []
	for i: int in ARC_SEGMENTS + 1:
		var theta: float = lerpf(-theta_max, theta_max, float(i) / ARC_SEGMENTS)
		points.append(Vector2(rho * sin(theta), cy + rho * cos(theta)))
	# Pin the springings and the crown exactly on the street's width and height.
	points[0] = Vector2(-half_width, eave)
	points[ARC_SEGMENTS] = Vector2(half_width, eave)
	var out := {"rise": rise, "rho": rho, "cy": cy, "points": points, "crown": eave + rise, "half_width": half_width}
	_arches[key] = out
	return out


## The roof's height at sideways position x over the street whose arch is `arch` (the inside of the
## glass).
static func height_at(arch: Dictionary, x: float) -> float:
	var rho: float = arch["rho"]
	var half_width: float = arch["half_width"]
	var dx: float = minf(absf(x), half_width)
	return float(arch["cy"]) + sqrt(maxf(rho * rho - dx * dx, 0.0))


## The height of the glass itself at sideways position x: the panes are flat chords between the arch's
## corners, so a little under the circle between them (0.13 m at most, on the widest street).
static func glass_at(arch: Dictionary, x: float) -> float:
	var points: Array[Vector2] = arch["points"]
	var dx: float = clampf(x, points[0].x, points[points.size() - 1].x)
	for i: int in points.size() - 1:
		var b: Vector2 = points[i + 1]
		if dx <= b.x + 0.0001:
			var a: Vector2 = points[i]
			return lerpf(a.y, b.y, clampf((dx - a.x) / maxf(b.x - a.x, 0.0001), 0.0, 1.0))
	return points[points.size() - 1].y


## How far from the street's middle the arch is at height y (the circle's two sides), or -1 if y is above
## the crown.
static func half_span_at(arch: Dictionary, y: float) -> float:
	var rho: float = arch["rho"]
	var dy: float = y - float(arch["cy"])
	if absf(dy) >= rho:
		return -1.0
	return minf(sqrt(rho * rho - dy * dy), float(arch["half_width"]))


# --- A bay --------------------------------------------------------------------------------------

## One bay of the roof (variant 0..VARIANTS-1) in bay space: z from 0 (its near end, where its rib stands)
## to -bay_length. Cached per arch and variant.
func _bay(arch: Dictionary, variant: int) -> MeshLayer:
	var id: String = "%d_%d_%s_%s_%s" % [roundi(float(arch["half_width"]) * 100.0), variant, skin.pane_open_share,
		skin.bay_length, skin.eave_height]
	var found: MeshLayer = _bays.get(id)
	if found != null:
		return found
	if _bays.size() > 64:
		_bays.clear()
	var t := MeshLayer.new()
	var points: Array[Vector2] = arch["points"]
	var length: float = skin.bay_length
	var pane_len: float = length / PANES_PER_BAY
	var iron: Color = skin.iron_color
	# The panes: dark glass in thin iron frames; some are missing (the sky shows through).
	for i: int in ARC_SEGMENTS:
		var p0: Vector2 = points[i]
		var p1: Vector2 = points[i + 1]
		var wcm: int = roundi(p0.distance_to(p1) * 100.0)
		for m: int in PANES_PER_BAY:
			# More are missing high on the arch than low on it.
			var share: float = skin.pane_open_share * (0.5 + 1.0 - float(absi(2 * i + 1 - ARC_SEGMENTS)) / ARC_SEGMENTS)
			if MeshKit.hash01(variant, i, m + 31) < share:
				continue
			var z0: float = -float(m) * pane_len
			var z1: float = -float(m + 1) * pane_len
			# Corners clockwise seen from below (inside the roof): UV.x across the pane, UV.y along it.
			t.quad(Vector3(p0.x, p0.y, z1), Vector3(p0.x, p0.y, z0), Vector3(p1.x, p1.y, z0), Vector3(p1.x, p1.y, z1), iron,
				0.0, MeshKit.PAT_CASINO_VAULT, float(wcm + 1000 * i))
	# The rib across the street at the bay's near end: a box along each segment, its inside, and its two
	# faces along the street, showing under the glass.
	for i: int in ARC_SEGMENTS:
		var p0: Vector2 = points[i]
		var p1: Vector2 = points[i + 1]
		var d: Vector2 = p1 - p0
		var chord: float = d.length()
		var along := Vector3(d.x, d.y, 0.0) / chord
		var outward := Vector3(-along.y, along.x, 0.0)
		var mid := Vector3((p0.x + p1.x) * 0.5, (p0.y + p1.y) * 0.5, 0.0) - outward * (RIB_THICK * 0.5 - 0.12)
		var basis := Basis(along * (chord + 0.06), outward * RIB_THICK, Vector3(0.0, 0.0, RIB_DEPTH))
		t.box_xform(Transform3D(basis, mid), iron, 0.0, MeshKit.PAT_CASINO_IRON,
			MeshKit.FACE_NY | MeshKit.FACE_PZ | MeshKit.FACE_NZ, 2.0)
	# Purlins running along the street at every other vertex of the arch, a brass one at the crown.
	for i: int in range(0, ARC_SEGMENTS + 1, 2):
		var p: Vector2 = points[i]
		var brass: bool = i == ARC_SEGMENTS / 2
		t.box(Vector3(p.x, p.y - 0.02, -length * 0.5), Vector3(0.2, 0.2, length), skin.brass_dim_color if brass else iron, 0.0,
			MeshKit.PAT_CASINO_BRASS if brass else MeshKit.PAT_CASINO_IRON, MeshKit.FACE_NY | MeshKit.FACE_PX | MeshKit.FACE_NX,
			0.4 if brass else 2.0)
	_bays[id] = t
	return t


# --- What hangs from it ------------------------------------------------------------------------

## The girder across the street, banners, lantern and fan of bay k (z is the bay's near end), by hash.
## Everything stays above bunting_height; a thing that would reach below it isn't built.
func _hangings(solid: MeshLayer, glow: MeshLayer, arch: Dictionary, k: int, z: float) -> void:
	if not skin.hangings:
		return
	var length: float = skin.bay_length
	var limit: float = skin.bunting_height + HANG_MARGIN
	var half_width: float = arch["half_width"]
	# A girder across the street every crossbeam_spacing metres or so, under the roof, carrying banners.
	var girder: Dictionary = girder_of(arch, k)
	if not girder.is_empty():
		var beam_y: float = girder["y"]
		var span: float = girder["span"]
		var bz: float = z - length * 0.5
		solid.box(Vector3(0, beam_y, bz), Vector3(span * 2.0, 0.42, 0.34), skin.iron_color, 0.0, MeshKit.PAT_CASINO_IRON,
			MeshKit.ALL_FACES, 2.0)
		solid.box(Vector3(0, beam_y - 0.24, bz + 0.17), Vector3(span * 2.0, 0.07, 0.04), skin.brass_dim_color, 0.0,
			MeshKit.PAT_CASINO_BRASS, MeshKit.FACE_PZ, 0.4)
		_banners(solid, k, bz, beam_y, span - BANNER_MARGIN, limit)
	# A lantern on a chain from the roof, warm and dim (no real light: an emissive box and a halo).
	if MeshKit.hash01(k, 51) < skin.lantern_share:
		var lx: float = (MeshKit.hash01(k, 52) - 0.5) * half_width * 1.1
		var ly_top: float = glass_at(arch, lx) - 0.1
		var chain: float = 2.5 + 2.0 * MeshKit.hash01(k, 53)
		var ly: float = ly_top - chain - 0.3
		if ly - 0.3 >= limit:
			var lz: float = z - length * (0.25 + 0.5 * MeshKit.hash01(k, 54))
			solid.box(Vector3(lx, ly_top - chain * 0.5, lz), Vector3(0.04, chain, 0.04), skin.iron_color)
			solid.box(Vector3(lx, ly + 0.3, lz), Vector3(0.3, 0.12, 0.3), skin.brass_dim_color, 0.0, MeshKit.PAT_CASINO_BRASS,
				MeshKit.NO_BOTTOM, 0.4)
			solid.box(Vector3(lx, ly, lz), Vector3(0.28, 0.46, 0.28), skin.lamp_color, 0.8)
			solid.box(Vector3(lx, ly - 0.3, lz), Vector3(0.3, 0.1, 0.3), skin.brass_dim_color, 0.0, MeshKit.PAT_CASINO_BRASS,
				MeshKit.ALL_FACES & ~MeshKit.FACE_PY, 0.4)
			glow.rect(Vector3(lx - 1.4, ly - 1.4, lz + 0.3), Vector3(2.8, 0, 0), Vector3(0, 2.8, 0), skin.lamp_color, 0.2,
				MeshKit.SHAPE_RADIAL)
	# A ceiling fan high under the crown (its blades static: a silhouette, like the reference's).
	var fan: Dictionary = fan_of(arch, k)
	if not fan.is_empty():
		var at: Vector3 = fan["at"]
		_fan(solid, Vector3(at.x, at.y, z - length * 0.5), k)


## The girder of bay k, or {} if it has none: {y (its centre's height), span (half its length)}. Under
## the eave the street is as wide as its walls, so the girder runs from one wall face into the other
## (GIRDER_EMBED, hidden in the buildings); only a girder hung in the roof itself ends where the glass does.
func girder_of(arch: Dictionary, k: int) -> Dictionary:
	if not skin.hangings:
		return {}
	var spacing_bays: int = maxi(1, roundi(skin.crossbeam_spacing / skin.bay_length))
	if posmod(k + MeshKit.hash_i(k / spacing_bays, 3, 5) % spacing_bays, spacing_bays) != 0:
		return {}
	var beam_y: float = skin.bunting_height + HANG_MARGIN + 0.6 + 2.0 * MeshKit.hash01(k, 41)
	var span: float
	if beam_y + 0.3 <= skin.eave_height:
		span = float(arch["half_width"]) + GIRDER_EMBED
	else:
		span = half_span_at(arch, beam_y + 0.3)
	if span <= 1.0:
		return {}
	return {"y": beam_y, "span": span}


## The ceiling fan of bay k, or {} if it has none: {at (the hub: x across the street, y up)}. It hangs
## FAN_DROP under the roof and a little off the middle; its blades (FAN_RADIUS) must stay inside the glass
## (a narrow street's roof falls away quickly), so a fan that would poke out of it is moved to the middle,
## and dropped if even that is too wide.
func fan_of(arch: Dictionary, k: int) -> Dictionary:
	if not skin.hangings or MeshKit.hash01(k, 61) >= skin.fan_share:
		return {}
	var limit: float = skin.bunting_height + HANG_MARGIN
	var x: float = (MeshKit.hash01(k, 62) - 0.5) * float(arch["half_width"]) * 0.4
	for attempt: int in 2:
		var fan_y: float = glass_at(arch, x) - FAN_DROP
		var tips: float = glass_at(arch, absf(x) + FAN_RADIUS)
		if fan_y - 0.2 >= limit and tips >= fan_y - 0.2 + FAN_CLEARANCE:
			return {"at": Vector3(x, fan_y, 0.0)}
		x = 0.0
	return {}


## Banners hung from a girder at height `beam_y` across a street whose arch is `span` wide there: two to
## four of heavy cloth, as long as the room under it allows above `limit`.
func _banners(solid: MeshLayer, k: int, bz: float, beam_y: float, span: float, limit: float) -> void:
	var bw: float = skin.banner_width
	var count: int = mini(2 + MeshKit.hash_i(k, 71) % 3, maxi(floori(span * 2.0 / (bw + 0.6)), 1))
	var top: float = beam_y - 0.22
	for i: int in count:
		if MeshKit.hash01(k, 72 + i) >= skin.banner_share:
			continue
		var length: float = minf(top - limit, 3.0 + 3.0 * MeshKit.hash01(k, 76 + i))
		if length < 1.8:
			continue
		var x: float = lerpf(-span + bw, span - bw, (float(i) + 0.5 + 0.3 * (MeshKit.hash01(k, 80 + i) - 0.5)) / count)
		var seed: int = MeshKit.hash_i(k, i, 85) % 40
		var color: Color = skin.banner_colors[seed % skin.banner_colors.size()]
		solid.rect(Vector3(x - bw * 0.5, top - length, bz + 0.2), Vector3(bw, 0, 0), Vector3(0, length, 0), color, 0.0,
			MeshKit.PAT_CASINO_BANNER, Vector2(0.0, length), Vector2(1.0, 0.0), float(roundi(length * 10.0) + 1000 * seed))
		solid.box(Vector3(x, top + 0.02, bz + 0.2), Vector3(bw + 0.2, 0.06, 0.06), skin.brass_dim_color, 0.0,
			MeshKit.PAT_CASINO_BRASS, MeshKit.ALL_FACES, 0.4)


## A ceiling fan hung with its hub at `at`: a brass hub on a rod, four iron blades.
func _fan(solid: MeshLayer, at: Vector3, k: int) -> void:
	solid.box(at + Vector3(0, FAN_DROP * 0.5 - 0.02, 0), Vector3(0.05, FAN_DROP - 0.04, 0.05), skin.iron_color)
	solid.prism(at + Vector3(0, -0.12, 0), 0.34, 0.26, 8, skin.brass_dim_color, 0.0, MeshKit.PAT_CASINO_BRASS, true, 0.5)
	var turn: float = TAU * MeshKit.hash01(k, 66)
	for i: int in 4:
		var angle: float = turn + float(i) * PI * 0.5
		var dir := Vector3(cos(angle), 0.0, sin(angle))
		var basis := Basis(dir * 2.3, Vector3(0, 0.04, 0), dir.cross(Vector3.UP) * 0.5)
		solid.box_xform(Transform3D(basis, at + dir * 1.4 + Vector3(0, -0.2, 0)), skin.iron_color, 0.0,
			MeshKit.PAT_CASINO_IRON, MeshKit.ALL_FACES, 2.0)
