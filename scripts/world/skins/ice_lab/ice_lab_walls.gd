class_name IceLabWalls
extends RefCounted
## The walls of the Ice Lab (IceLabSkin, GDD §5: "the walls are lab machinery, consoles, jar racks and ice"; the reference image's
## pipes and girders, consoles and racks, ice and brain jars). A wall side is laid out in bays of SLOT metres from the wall's own
## distance (the bay k covers k * SLOT to (k + 1) * SLOT), each bay one kind picked by hashing (side, k) against the skin's weights
## (the lean: lab_share): a run of PIPES, a LATTICE pillar, a pressure TANK, a wall of ICE, a bank of CONSOLES, a row of server
## RACKS, clean-room TILE, a service DOOR, an alcove of specimen JARS (a brain in each) or one whose middle jar holds a curled-up
## OCTODOG (task Q2's Octodog jars on the walls: scenery only, whatever they hold). Every bay is built once in wall space
## (IceLabParts) and set on the wall by a transform, left or right, so a chunk costs a handful of appends; a stretch a wall gap's cut
## leaves short of a whole bay, and a bay beside a window cyborg (note_wall_enemies), is a plain stretch of plating. Chunks' edges are
## always bay edges (40 m is eight bays), so bays are never cut but by a wall gap's ends.
## A runner can touch the wall (wall running) up to the skin's calm_top, so below it nothing stands out of the face more than
## IceLabParts.PROUD (pipes half-sunk, frames and bezels, screens) and the jars' depth is recessed behind the face, in an alcove; the
## machinery's real depth is above the band (the cornice at band_top, the trunk pipes, ice crust, icicles, the gantry rail along the top).
## Nothing in the band is a window (a window cyborg's must be the only one): the alcoves are filled with jars, their frames and lids and
## tubes reading as a rack of specimens, and none opens beside a window cyborg. The machine lamps stand above the band (lamp_min_height).
## The wall below the street is the dark shade of the holes (PAT_IL_UNDER), so a hole beside the wall is as dark as any.
## A bay is a few hundred vertices (a chunk's walls are sixteen of them, and a phone draws every one every frame): faces nobody sees are
## left out, curves have few sides and the detail is the shader's (PAT_IL_PANEL's vents and lights, PAT_IL_STEEL's rivets and frost).
## Chunk space: x across, y up (the street at y = 0), z = -distance.

## One bay's length along the wall. 40 m (a chunk) is eight of them.
const SLOT: float = 5.0
const VARIANTS: int = 3
## The bays, in the order of the skin's weights (bay_weights_frost, bay_weights_lab).
const BAY_PIPES: int = 0
const BAY_LATTICE: int = 1
const BAY_TANK: int = 2
const BAY_ICE: int = 3
const BAY_CONSOLES: int = 4
const BAY_RACKS: int = 5
const BAY_TILE: int = 6
const BAY_DOOR: int = 7
const BAY_JARS: int = 8
const BAY_OCTODOG: int = 9
const BAY_COUNT: int = 10
## A blank stretch of plating (where a window cyborg's window is): never picked by the weights.
const BAY_PLAIN: int = 10
## How close a window cyborg's track keeps an alcove, past the bay's own half length.
const CYBORG_MARGIN: float = 2.2
## A recessed alcove's depth behind the wall face.
const ALCOVE_DEPTH: float = 0.8
## How tall a wall gap's cut-away ends stand behind the wall line (the recess).
const RECESS_TOP: float = 22.0
## The faces of a box above the band, seen from below as well as the front.
const FACES_BELOW: int = IceLabParts.FRONT_FACES | MeshKit.FACE_NY

## Weak: the skin owns this builder, so a strong reference back would keep both alive forever.
var skin: IceLabSkin:
	get:
		return _skin.get_ref() as IceLabSkin
var _skin: WeakRef
var _parts: IceLabParts
var _bays: Dictionary = {}


func _init(p_skin: IceLabSkin) -> void:
	_skin = weakref(p_skin)
	_parts = IceLabParts.new(p_skin)


## Which bay is bay `k` of wall `side`: by hash against the skin's weights (and a share of the jar bays folded into Octodog ones, by the lean:
## octodog_in_jar_share scaled by lab_share).
func bay_kind(side: int, k: int) -> int:
	var total: float = 0.0
	for kind: int in BAY_COUNT:
		total += skin.bay_weight(kind)
	var picked: int = BAY_PIPES
	if total > 0.0:
		var r: float = MeshKit.hash01(side, k, 301) * total
		for kind: int in BAY_COUNT:
			r -= skin.bay_weight(kind)
			if r < 0.0:
				picked = kind
				break
	if picked == BAY_JARS and MeshKit.hash01(side, k, 303) < skin.octodog_in_jar_share * skin.lab_share:
		picked = BAY_OCTODOG
	return picked


## The variant (0 to VARIANTS - 1) of bay `k`.
func bay_variant(side: int, k: int) -> int:
	return MeshKit.hash_i(side, k, 302) % VARIANTS


## Whether bay `k` of `side` is one of jars with an Octodog among them.
func is_octodog_bay(side: int, k: int) -> bool:
	return bay_kind(side, k) == BAY_OCTODOG


## Adds the wall of one side between two track distances (the part of it a section covers), face at signed world x `face_x`.
func build(batch: MeshBatch, side: int, face_x: float, start: float, end: float) -> void:
	var first: int = floori(start / SLOT + 0.0001)
	var last: int = ceili(end / SLOT - 0.0001) - 1
	for k: int in range(first, last + 1):
		var u0: float = float(k) * SLOT
		var u1: float = u0 + SLOT
		var a: float = maxf(start, u0)
		var b: float = minf(end, u1)
		if b - a < 0.001:
			continue
		var kind: int = bay_kind(side, k)
		if skin.reserved_near(side, (u0 + u1) * 0.5, SLOT * 0.5 + CYBORG_MARGIN):
			kind = BAY_PLAIN
		if a > u0 + 0.001 or b < u1 - 0.001:
			_plain(batch, side, face_x, a, b, kind)
			continue
		var tpl: MeshBatch = bay(kind, bay_variant(side, k))
		if side < 0:
			batch.append(tpl, Transform3D(Basis.IDENTITY, Vector3(face_x, 0.0, -u0)))
		else:
			batch.append(tpl, Transform3D(Basis(Vector3.UP, PI), Vector3(face_x, 0.0, -u1)))


## A stretch of wall `a` to `b` where a whole bay would not fit (cut by a wall gap): the face, the cornice and the gantry's deck, in world
## space (nothing that needs the bay's length).
func _plain(batch: MeshBatch, side: int, face_x: float, a: float, b: float, kind: int) -> void:
	var s: MeshLayer = batch.layer(skin.solid_material())
	var top: float = skin.wall_height
	var ice: bool = kind == BAY_ICE
	var color: Color = skin.ice_color if ice else skin.steel_color
	_face(s, side, face_x, a, b, 0.0, top, color, MeshKit.PAT_IL_ICE if ice else MeshKit.PAT_IL_STEEL, 0.0)
	_face(s, side, face_x, a, b, -skin.pit_depth, 0.0, skin.gap_inside_color, MeshKit.PAT_IL_UNDER, 1.0)
	var band: float = skin.band_top
	_box(s, side, face_x, a, b, band, band + 0.55, 0.0, 0.4, skin.frame_color)
	_box(s, side, face_x, a, b, top - 0.3, top, 0.0, 1.4, skin.steel_color, MeshKit.PAT_IL_STEEL, 4.0)
	_box(s, side, face_x, a, b, top - 0.12, top + 0.14, 1.34, 1.4, skin.frame_color)
	_box(s, side, face_x, a, b, top + 1.07, top + 1.17, 1.28, 1.34, skin.frame_color)


## A rectangle on the wall's plane, in world space, between track distances a and b (UV: distance, height), facing the street.
func _face(l: MeshLayer, side: int, face_x: float, a: float, b: float, y0: float, y1: float, color: Color, pattern: int,
		param: float) -> void:
	if side < 0:
		l.rect(Vector3(face_x, y0, -a), Vector3(0.0, 0.0, -(b - a)), Vector3(0.0, y1 - y0, 0.0), color, 0.0, pattern,
			Vector2(a, y0), Vector2(b, y1), param)
	else:
		l.rect(Vector3(face_x, y0, -b), Vector3(0.0, 0.0, b - a), Vector3(0.0, y1 - y0, 0.0), color, 0.0, pattern,
			Vector2(a, y0), Vector2(b, y1), param)


## A box proud of the wall (x0 to x1 out of the face toward the street) between track distances a and b, in world space.
func _box(l: MeshLayer, side: int, face_x: float, a: float, b: float, y0: float, y1: float, x0: float, x1: float, color: Color,
		pattern: int = MeshKit.PAT_IL_STEEL, param: float = 0.0) -> void:
	var out: float = -float(side)
	l.box(Vector3(face_x + out * (x0 + x1) * 0.5, (y0 + y1) * 0.5, -(a + b) * 0.5), Vector3(x1 - x0, y1 - y0, b - a), color, 0.0, pattern,
		MeshKit.ALL_FACES & ~MeshKit.FACE_NX, param)


# --- The bays -------------------------------------------------------------------------------------

## The bay `kind`, `variant`, built once in wall space (cached).
func bay(kind: int, variant: int) -> MeshBatch:
	var id: int = kind * 16 + variant
	if _bays.has(id):
		return _bays[id]
	var b := MeshBatch.new()
	var s: MeshLayer = b.layer(skin.solid_material())
	var g: MeshLayer = b.layer(skin.glow_material())
	var k: int = kind * 31 + variant * 7 + 1
	_frame(s, kind, k)
	match kind:
		BAY_PIPES:
			_pipes(s, g, variant, k)
		BAY_LATTICE:
			_lattice(s, g, variant, k)
		BAY_TANK:
			_tank(s, g, variant, k)
		BAY_ICE:
			_ice(s, g, variant, k)
		BAY_CONSOLES:
			_consoles(s, g, variant, k)
		BAY_RACKS:
			_racks(s, g, variant, k)
		BAY_TILE:
			_tile(s, g, variant, k)
		BAY_DOOR:
			_door(s, g, variant, k)
		BAY_JARS, BAY_OCTODOG:
			_jars(s, g, variant, k, kind == BAY_OCTODOG)
		_:
			_blank(s, g, variant, k)
	_upper(s, kind, k)
	_parts.gantry(s, 0.0, SLOT, skin.wall_height, k)
	_bays[id] = b
	return b


## What every bay has: the body's face (plating, or ice for an ice wall; the jars' alcove opens its own), the dark shade below the street,
## a pilaster at its left edge, a kick plate at its foot and the cornice at the top of the band with snow on it.
func _frame(s: MeshLayer, kind: int, k: int) -> void:
	var p: IceLabParts = _parts
	var top: float = skin.wall_height
	var band: float = skin.band_top
	if kind == BAY_JARS or kind == BAY_OCTODOG:
		pass
	elif kind == BAY_ICE:
		p.wrect(s, 0.0, SLOT, 0.0, top, 0.0, skin.ice_color, 0.0, MeshKit.PAT_IL_ICE, 0.0)
	else:
		p.wrect(s, 0.0, SLOT, 0.0, top, 0.0, skin.steel_color, 0.0, MeshKit.PAT_IL_STEEL, 0.0)
	p.wrect(s, 0.0, SLOT, -skin.pit_depth, 0.0, 0.0, skin.gap_inside_color, 0.0, MeshKit.PAT_IL_UNDER, 1.0)
	if kind != BAY_ICE:
		p.wbox(s, 0.0, 0.14, 0.3, skin.calm_top, 0.0, IceLabParts.PROUD, skin.frame_color, 0.0, MeshKit.PAT_IL_STEEL, 0.0)
		p.wbox(s, 0.0, SLOT, 0.0, 0.3, 0.0, 0.06, skin.steel_color.darkened(0.1), 0.0, MeshKit.PAT_IL_STEEL, 0.0)
	# The cornice: a girder along the top of the band, standing out over the street (above the band's reach), snow on it.
	p.wbox(s, 0.0, SLOT, band, band + 0.55, 0.0, 0.4, skin.frame_color, 0.0, MeshKit.PAT_IL_STEEL, 0.0, FACES_BELOW)
	p.snow_cap(s, 0.0, SLOT, band + 0.55, 0.02, 0.38, k + 3, 0.1, 1.25)


## The wall above the band (the machinery's depth, where nothing touches it): trunk pipes and brackets for the industrial bays, a duct and
## cable trays for the laboratory's, a crust of ice and icicles for an ice wall.
func _upper(s: MeshLayer, kind: int, k: int) -> void:
	var p: IceLabParts = _parts
	var band: float = skin.band_top
	var top: float = skin.wall_height
	var y0: float = band + 0.6
	var cold: Color = skin.frame_color
	if kind == BAY_ICE:
		# Blocks of ice crust, standing out over the street by different amounts, and icicles hanging from the cornice.
		for i: int in 3:
			var a: float = float(i) * SLOT / 3.0 + 0.1
			var depth: float = 0.3 + 0.5 * MeshKit.hash01(k, i, 71)
			var lo: float = y0 + 0.2 + 0.5 * MeshKit.hash01(k, i, 72)
			p.wbox(s, a, a + SLOT / 3.0 - 0.15, lo, top - 0.4 - 0.4 * MeshKit.hash01(k, i, 73), 0.0, depth, skin.ice_color.lightened(0.08), 0.0,
				MeshKit.PAT_IL_ICE, 0.0, FACES_BELOW)
		p.icicles(s, 0.3, SLOT - 0.3, band, 0.4, 6, 1.7, k)
		return
	if kind == BAY_PIPES or kind == BAY_LATTICE or kind == BAY_TANK:
		p.wpipe(s, y0 + 0.65, 0.42, 0.0, SLOT, cold.darkened(0.15), 6, 0.9)
		p.wpipe(s, y0 + 1.75, 0.2, 0.0, SLOT, cold.darkened(0.25), 6, 0.5)
		for bs: float in [0.8, SLOT - 0.8]:
			p.wbox(s, bs - 0.1, bs + 0.1, y0, y0 + 1.5, 0.0, 0.4, cold.darkened(0.3), 0.0, MeshKit.PAT_IL_STEEL, 0.0)
		p.snow_cap(s, 0.0, SLOT, y0 + 1.07, 0.1, 0.75, k + 5, 0.14, 1.25)
		return
	# The laboratory's upper wall: a long duct and a cable tray, hanging cables.
	p.wbox(s, 0.0, SLOT, y0 + 0.2, y0 + 1.0, 0.0, 0.7, cold.darkened(0.1), 0.0, MeshKit.PAT_IL_STEEL, 0.0, FACES_BELOW)
	p.snow_cap(s, 0.0, SLOT, y0 + 1.0, 0.1, 0.62, k + 9, 0.08, 1.25)
	p.wbox(s, 0.0, SLOT, y0 + 1.5, y0 + 1.7, 0.0, 0.5, cold.darkened(0.2), 0.0, MeshKit.PAT_IL_STEEL, 0.0, IceLabParts.FRONT_FACES)
	for i: int in 3:
		var cs: float = (float(i) + 0.5) * SLOT / 3.0
		p.wbox(s, cs - 0.02, cs + 0.02, y0 + 1.7, top - 0.3, 0.2, 0.26, Color(0.06, 0.08, 0.1), 0.0, MeshKit.PAT_IL_STEEL, 2.0,
			MeshKit.FACE_PX)


# --- The pipes and the machinery -------------------------------------------------------------------

func _pipes(s: MeshLayer, g: MeshLayer, variant: int, k: int) -> void:
	var p: IceLabParts = _parts
	var pipe: Color = skin.frame_color
	var heights: Array[float] = [0.95, 1.4, 1.85, 5.6]
	var radii: Array[float] = [0.08, 0.08, 0.06, 0.1]
	for i: int in heights.size():
		var y: float = heights[i] + (0.0 if variant != 1 or i > 2 else 0.5)
		p.wpipe(s, y, radii[i], 0.14, SLOT, pipe.lerp(skin.steel_color, 0.3 * MeshKit.hash01(k, i, 81)), 6)
	# Flanges on two of the pipes.
	for fs: float in [1.5 + 1.0 * MeshKit.hash01(k, 0, 82), 3.4 + 1.0 * MeshKit.hash01(k, 1, 82)]:
		p.wpipe(s, heights[0], radii[0] + 0.025, fs - 0.06, fs + 0.06, pipe.lightened(0.05), 6)
		p.wpipe(s, heights[3], radii[3] + 0.025, fs - 0.06, fs + 0.06, pipe.lightened(0.05), 6)
	p.wriser(s, 0.55, 0.09, 0.3, skin.calm_top, pipe.darkened(0.1))
	# A hand wheel on a valve, a gauge, a lamp.
	var vs: float = 2.0 + 1.2 * MeshKit.hash01(k, 3, 83)
	p.wdisc(s, vs, heights[1] + 0.3, 0.2, 0.01, 0.05, pipe.lightened(0.12), 6, MeshKit.PAT_IL_STEEL, 2.0)
	p.wdisc(s, SLOT - 1.2, 3.3, 0.16, 0.01, 0.04, skin.door_color.lightened(0.15), 6, MeshKit.PAT_IL_STEEL, 2.0)
	if MeshKit.hash01(k, 5, 84) < skin.lamp_share + 0.3:
		p.lamp(s, g, 3.5, 6.9 + 1.2 * MeshKit.hash01(k, 6, 84), k)


func _lattice(s: MeshLayer, g: MeshLayer, variant: int, k: int) -> void:
	var p: IceLabParts = _parts
	var top: float = skin.calm_top
	var col: Color = skin.frame_color
	for cs: float in [0.5, SLOT - 0.5]:
		p.wbox(s, cs - 0.17, cs + 0.17, 0.3, top, 0.0, IceLabParts.PROUD, col, 0.0, MeshKit.PAT_IL_STEEL, 0.0)
	var rungs: int = 4
	var step: float = (top - 0.3) / float(rungs)
	for i: int in rungs:
		var y0: float = 0.3 + step * float(i)
		var y1: float = y0 + step
		var flip: bool = (i + variant) % 2 == 0
		p.wdiag(s, 0.67 if flip else SLOT - 0.67, y0, SLOT - 0.67 if flip else 0.67, y1, 0.07, 0.0, 0.1, col.darkened(0.1))
	for i: int in 3:
		var y: float = 0.3 + step * float(i + 1)
		p.wbox(s, 0.67, SLOT - 0.67, y - 0.035, y + 0.035, 0.0, 0.1, col.darkened(0.1), 0.0, MeshKit.PAT_IL_STEEL, 0.0)
	# A hoist chain hanging from the gantry rail over the lattice, a hook block at its end (above the band: it hangs in the open).
	if variant != 1:
		var wall_top: float = skin.wall_height
		var band: float = skin.band_top
		var chain_x: float = 1.2
		var tx := Transform3D(Basis.from_scale(Vector3(0.05, wall_top - 0.3 - (band + 1.1), 0.05)), Vector3(chain_x, band + 1.1, -SLOT * 0.5))
		s.prism_xform(tx, 4, skin.steel_color.lightened(0.15), 0.0, MeshKit.PAT_IL_STEEL, false, 3.0)
		p.wbox(s, SLOT * 0.5 - 0.18, SLOT * 0.5 + 0.18, band + 0.75, band + 1.1, chain_x - 0.18, chain_x + 0.18, skin.frame_color, 0.0,
			MeshKit.PAT_IL_STEEL, 0.0, FACES_BELOW)
	if MeshKit.hash01(k, 2, 85) < skin.lamp_share + 0.2:
		p.lamp(s, g, SLOT * 0.5, 7.0 + 1.0 * MeshKit.hash01(k, 3, 85), k)


func _tank(s: MeshLayer, g: MeshLayer, variant: int, k: int) -> void:
	var p: IceLabParts = _parts
	var body: Color = skin.frame_color.lerp(skin.steel_color, 0.4)
	p.wbox(s, 0.4, SLOT - 0.4, 0.35, 6.2, 0.0, 0.07, body, 0.0, MeshKit.PAT_IL_STEEL, 0.0)
	for y: float in [1.6, 3.5, 5.4]:
		p.wbox(s, 0.3, SLOT - 0.3, y - 0.07, y + 0.07, 0.0, IceLabParts.PROUD, skin.frame_color.lightened(0.05), 0.0, MeshKit.PAT_IL_STEEL, 0.0,
			MeshKit.FACE_PX | MeshKit.FACE_PY)
	p.wdisc(s, SLOT * 0.32, 4.4, 0.18, 0.06, 0.05, skin.door_color.lightened(0.2), 6, MeshKit.PAT_IL_STEEL, 2.0)
	p.wdisc(s, SLOT * 0.58, 2.5, 0.13, 0.06, 0.05, skin.door_color.lightened(0.2), 6, MeshKit.PAT_IL_STEEL, 2.0)
	# A ladder up the tank's side: two rails and a few rungs.
	for rs: float in [SLOT - 0.95, SLOT - 0.7]:
		p.wbox(s, rs - 0.015, rs + 0.015, 0.35, skin.calm_top, 0.0, IceLabParts.PROUD - 0.02, skin.steel_color.lightened(0.08), 0.0,
			MeshKit.PAT_IL_STEEL, 2.0, MeshKit.FACE_PX)
	var y: float = 0.8
	while y < skin.calm_top:
		p.wbox(s, SLOT - 0.95, SLOT - 0.7, y - 0.012, y + 0.012, 0.0, IceLabParts.PROUD - 0.04, skin.steel_color.lightened(0.08), 0.0,
			MeshKit.PAT_IL_STEEL, 2.0, MeshKit.FACE_PX)
		y += 1.0
	# A neck up from the tank into the pipes over the band.
	p.wriser(s, SLOT * 0.45, 0.2, 6.2, skin.band_top, skin.frame_color.darkened(0.1), 6)
	if variant == 1 and MeshKit.hash01(k, 1, 86) < skin.lamp_share + 0.3:
		p.lamp(s, g, SLOT * 0.5, 7.4, k)
	p.foot_snow(s, 0.0, SLOT, skin.snow_amount(), k)


# --- Ice ------------------------------------------------------------------------------------------

func _ice(s: MeshLayer, g: MeshLayer, variant: int, k: int) -> void:
	var p: IceLabParts = _parts
	# Facets of ice standing a little out of the wall, and shards lying along it.
	for i: int in 3:
		var a: float = 0.3 + (SLOT - 1.6) * MeshKit.hash01(k, i, 91)
		var y: float = 0.6 + (skin.calm_top - 3.0) * MeshKit.hash01(k, i, 92)
		p.wbox(s, a, a + 0.8 + 0.8 * MeshKit.hash01(k, i, 93), y, y + 0.7 + 1.0 * MeshKit.hash01(k, i, 94), 0.0, 0.07 + 0.04 * MeshKit.hash01(k, i, 95),
			skin.ice_color.lightened(0.1 * MeshKit.hash01(k, i, 96)), 0.0, MeshKit.PAT_IL_ICE, 0.0)
	var clusters: int = 2
	for i: int in clusters:
		var cs: float = 0.9 + (SLOT - 1.8) * (float(i) + MeshKit.hash01(k, i, 97)) / float(clusters)
		var cy: float = 0.4 + 4.6 * MeshKit.hash01(k, i, 98)
		p.shards(s, cs, cy, 3 + (variant % 2), 0.7 + 0.9 * MeshKit.hash01(k, i, 99), k + i)
	p.foot_snow(s, 0.0, SLOT, minf(skin.snow_amount() + 0.25, 1.0), k)
	if MeshKit.hash01(k, 4, 100) < skin.lamp_share:
		p.lamp(s, g, SLOT * 0.5, 7.4, k)


# --- The laboratory -----------------------------------------------------------------------------

func _consoles(s: MeshLayer, g: MeshLayer, variant: int, k: int) -> void:
	var p: IceLabParts = _parts
	var seed: int = k * 3
	# The cabinet under the desk and the cabinets over the screens, painted flush; the desk and its status lights.
	p.wrect(s, 0.1, SLOT - 0.1, 0.3, 1.05, 0.012, skin.enamel_color, 0.0, MeshKit.PAT_IL_PANEL, float(MeshKit.IL_PANEL_CABINET + 4 * (seed % 100)))
	p.wbox(s, 0.0, SLOT, 1.05, 1.17, 0.0, IceLabParts.PROUD, skin.frame_color, 0.0, MeshKit.PAT_IL_STEEL, 0.0)
	p.status_lights(s, 0.3, SLOT - 0.3, 1.0, 9, seed)
	var sw: float = 1.15
	var sx: float = 0.3
	for i: int in 3:
		p.screen(s, sx + float(i) * (sw + 0.2), 1.45, sw, 0.8, seed + i * 17)
	p.wrect(s, 0.1, SLOT - 0.1, 2.55, 4.2, 0.012, skin.enamel_color, 0.0, MeshKit.PAT_IL_PANEL, float(MeshKit.IL_PANEL_CABINET + 4 * ((seed + 3) % 100)))
	p.wbox(s, 0.0, SLOT, 4.5, 4.75, 0.0, IceLabParts.PROUD, skin.steel_color.lightened(0.05), 0.0, MeshKit.PAT_IL_STEEL, 0.0)
	for i: int in 3:
		var cs: float = 0.5 + 4.0 * MeshKit.hash01(k, i, 101)
		p.wbox(s, cs - 0.025, cs + 0.025, 3.7 + 0.5 * MeshKit.hash01(k, i, 102), 4.5, 0.0, 0.05, Color(0.05, 0.06, 0.08), 0.0, MeshKit.PAT_IL_STEEL, 2.0,
			MeshKit.FACE_PX)
	if variant != 2:
		p.status_lights(s, 0.3, SLOT - 0.3, 2.4, 6, seed + 5)
	if MeshKit.hash01(k, 6, 103) < skin.lamp_share + 0.2:
		p.lamp(s, g, SLOT * 0.5, 7.0 + 1.0 * MeshKit.hash01(k, 7, 103), k)


func _racks(s: MeshLayer, g: MeshLayer, variant: int, k: int) -> void:
	var p: IceLabParts = _parts
	var seed: int = k * 5
	var tiers: Array[Vector2] = [Vector2(0.3, 3.0), Vector2(3.15, 5.85)]
	var xs: Array[float] = [0.12, 1.8, 3.48]
	for ti: int in tiers.size():
		for i: int in xs.size():
			var y0: float = tiers[ti].x
			var y1: float = tiers[ti].y
			p.wrect(s, xs[i], xs[i] + 1.4, y0, y1, 0.012, skin.rack_color, 0.0, MeshKit.PAT_IL_PANEL,
				float(MeshKit.IL_PANEL_RACK + 4 * ((seed + ti * 3 + i) % 100)), Vector2.ZERO, Vector2(1.4, y1 - y0))
	# Frames between the racks, a cable run between the tiers and cables going up to the pipes over the band.
	for fs: float in [1.52, 3.2, 4.88]:
		p.wbox(s, fs, fs + 0.28, 0.3, 5.85, 0.0, IceLabParts.PROUD * 0.8, skin.steel_color.lightened(0.04), 0.0, MeshKit.PAT_IL_STEEL, 0.0,
			MeshKit.FACE_PX)
	p.wpipe(s, 3.075, 0.045, 0.0, SLOT, Color(0.05, 0.06, 0.08), 4, 0.1)
	for i: int in 3:
		var cs: float = 0.5 + 1.7 * float(i) + 0.3 * MeshKit.hash01(k, i, 111)
		p.wriser(s, cs, 0.03, 5.85, skin.calm_top, Color(0.05, 0.06, 0.08), 4, 0.08)
	if variant == 1:
		p.foot_snow(s, 0.0, SLOT, skin.snow_amount() * 0.5, k)
	if MeshKit.hash01(k, 7, 112) < skin.lamp_share:
		p.lamp(s, g, SLOT * 0.5, 7.2, k)


func _tile(s: MeshLayer, g: MeshLayer, variant: int, k: int) -> void:
	var p: IceLabParts = _parts
	var seed: int = k
	# Clean-room tile up to 4.5 m with a band of paint, a conduit, a screen or two hand wheels.
	p.wrect(s, 0.0, SLOT, 0.3, 4.5, 0.012, skin.tile_color, 0.0, MeshKit.PAT_IL_PANEL, float(MeshKit.IL_PANEL_TILE + 4 * (seed % 100)))
	p.wbox(s, 0.0, SLOT, 1.75, 1.9, 0.0, 0.03, skin.ice_color.darkened(0.1), 0.0, MeshKit.PAT_IL_STEEL, 0.0, MeshKit.FACE_PX)
	p.wbox(s, 0.0, SLOT, 4.5, 4.62, 0.0, IceLabParts.PROUD, skin.frame_color, 0.0, MeshKit.PAT_IL_STEEL, 0.0)
	p.wpipe(s, 4.9, 0.07, 0.0, SLOT, skin.frame_color.darkened(0.1), 6)
	if variant == 0:
		p.screen(s, SLOT * 0.5 - 0.6, 2.2, 1.2, 0.8, seed * 7)
	elif variant == 1:
		for i: int in 2:
			p.wdisc(s, 1.3 + 2.4 * float(i), 2.6, 0.2, 0.01, 0.04, skin.frame_color.lightened(0.1), 6, MeshKit.PAT_IL_STEEL, 2.0)
	p.lamp(s, g, SLOT * 0.5, 7.2, k)


func _door(s: MeshLayer, g: MeshLayer, variant: int, k: int) -> void:
	var p: IceLabParts = _parts
	var seed: int = k * 11
	var ds: float = 1.9 + 0.3 * float(variant - 1)
	# The door flush in its frame, a lamp over it, a conduit and a console beside it.
	p.wbox(s, ds - 0.12, ds, 0.3, 2.85, 0.0, 0.09, skin.frame_color, 0.0, MeshKit.PAT_IL_STEEL, 0.0)
	p.wbox(s, ds + 1.2, ds + 1.32, 0.3, 2.85, 0.0, 0.09, skin.frame_color, 0.0, MeshKit.PAT_IL_STEEL, 0.0)
	p.wbox(s, ds - 0.12, ds + 1.32, 2.7, 2.85, 0.0, 0.09, skin.frame_color, 0.0, MeshKit.PAT_IL_STEEL, 0.0, MeshKit.FACE_PX)
	p.wrect(s, ds, ds + 1.2, 0.3, 2.7, 0.012, skin.door_color, 0.0, MeshKit.PAT_IL_PANEL, float(MeshKit.IL_PANEL_DOOR + 4 * (seed % 100)),
		Vector2(0.0, 0.0), Vector2(1.2, 2.4))
	p.wpipe(s, 3.3, 0.06, 0.0, SLOT, skin.frame_color.darkened(0.1), 6)
	p.wrect(s, 0.2, 1.3, 1.1, 2.0, 0.012, skin.enamel_color, 0.0, MeshKit.PAT_IL_PANEL, float(MeshKit.IL_PANEL_CABINET + 4 * ((seed + 2) % 100)))
	p.status_lights(s, 0.35, 1.15, 1.9, 4, seed)
	p.lamp(s, g, ds + 0.6, 7.0, k)
	p.foot_snow(s, 0.0, SLOT, skin.snow_amount() * 0.6, k)


## An alcove of specimen jars (GDD §5: brain jars on the walls): a recess ALCOVE_DEPTH deep behind the wall's face, framed, its back and
## sides dark steel, with two or three jars standing in it, each a pale dim liquid with a brain hanging in it. The middle jar of an
## Octodog bay holds a curled-up Octodog. Nothing stands out of the face but the frame (PROUD); the jars are behind it.
func _jars(s: MeshLayer, g: MeshLayer, variant: int, k: int, octodog: bool) -> void:
	var p: IceLabParts = _parts
	var top: float = skin.wall_height
	var y0: float = 0.55
	var y1: float = 5.35
	var a0: float = 0.45
	var a1: float = SLOT - 0.45
	var steel: Color = skin.steel_color
	# The wall's face around the opening: below it, above it, and either side.
	p.wrect(s, 0.0, SLOT, 0.0, y0, 0.0, steel, 0.0, MeshKit.PAT_IL_STEEL, 0.0)
	p.wrect(s, 0.0, SLOT, y1, top, 0.0, steel, 0.0, MeshKit.PAT_IL_STEEL, 0.0)
	p.wrect(s, 0.0, a0, y0, y1, 0.0, steel, 0.0, MeshKit.PAT_IL_STEEL, 0.0)
	p.wrect(s, a1, SLOT, y0, y1, 0.0, steel, 0.0, MeshKit.PAT_IL_STEEL, 0.0)
	# The alcove inside, in darker steel: back, floor, roof and the two sides.
	var d: float = -ALCOVE_DEPTH
	var dark: Color = steel.darkened(0.45)
	p.wrect(s, a0, a1, y0, y1, d, dark, 0.0, MeshKit.PAT_IL_STEEL, 0.0)
	s.rect(Vector3(d, y0, -a0), Vector3(-d, 0.0, 0.0), Vector3(0.0, 0.0, -(a1 - a0)), dark.lightened(0.05), 0.0, MeshKit.PAT_IL_STEEL, Vector2.ZERO,
		Vector2.ONE, 0.0)
	s.rect(Vector3(0.0, y1, -a0), Vector3(d, 0.0, 0.0), Vector3(0.0, 0.0, -(a1 - a0)), dark.darkened(0.1), 0.0, MeshKit.PAT_IL_STEEL, Vector2.ZERO,
		Vector2.ONE, 0.0)
	s.rect(Vector3(0.0, y0, -a0), Vector3(d, 0.0, 0.0), Vector3(0.0, y1 - y0, 0.0), dark, 0.0, MeshKit.PAT_IL_STEEL)
	s.rect(Vector3(d, y0, -a1), Vector3(-d, 0.0, 0.0), Vector3(0.0, y1 - y0, 0.0), dark, 0.0, MeshKit.PAT_IL_STEEL)
	# The frame round the opening, proud of the face by the bezel's depth.
	var fw: float = 0.16
	p.wbox(s, a0 - fw, a1 + fw, y0 - fw, y0, 0.0, IceLabParts.PROUD, skin.frame_color, 0.0, MeshKit.PAT_IL_STEEL, 0.0, MeshKit.FACE_PX | MeshKit.FACE_PY)
	p.wbox(s, a0 - fw, a1 + fw, y1, y1 + fw, 0.0, IceLabParts.PROUD, skin.frame_color, 0.0, MeshKit.PAT_IL_STEEL, 0.0, MeshKit.FACE_PX)
	p.wbox(s, a0 - fw, a0, y0, y1, 0.0, IceLabParts.PROUD, skin.frame_color, 0.0, MeshKit.PAT_IL_STEEL, 0.0, MeshKit.FACE_PX)
	p.wbox(s, a1, a1 + fw, y0, y1, 0.0, IceLabParts.PROUD, skin.frame_color, 0.0, MeshKit.PAT_IL_STEEL, 0.0, MeshKit.FACE_PX)
	# The jars: two or three, in a row, the middle one an Octodog's in an Octodog bay.
	var count: int = 2 if variant == 0 else 3
	var width: float = 1.15 if count == 3 else 1.5
	var gap: float = ((a1 - a0) - width * float(count)) / float(count + 1)
	for i: int in count:
		var s_mid: float = a0 + gap * float(i + 1) + width * (float(i) + 0.5)
		var holds_octodog: bool = octodog and i == count / 2
		p.jar(s, s_mid, y0 + 0.55, width, y1 - y0 - 1.2, d + 0.12, holds_octodog, k + i)
	p.foot_snow(s, 0.0, a0, skin.snow_amount() * 0.5, k)
	p.foot_snow(s, a1, SLOT, skin.snow_amount() * 0.5, k + 3)
	if MeshKit.hash01(k, 8, 113) < skin.lamp_share + 0.3:
		p.lamp(s, g, SLOT * 0.5, 7.2, k)


func _blank(s: MeshLayer, _g: MeshLayer, _variant: int, k: int) -> void:
	var p: IceLabParts = _parts
	p.wpipe(s, 1.2, 0.07, 0.14, SLOT, skin.frame_color.darkened(0.1), 6)
	p.wpipe(s, 6.2, 0.1, 0.14, SLOT, skin.frame_color, 6)
	p.foot_snow(s, 0.0, SLOT, skin.snow_amount() * 0.6, k)


# --- A gap in the wall -----------------------------------------------------------------------------

## What a wall gap shows behind the wall line (ZoneSkin.wall_gap_recess, task L4): the gap's part [start, end] of an opening in the wall
## onto the hall: the two cut ends' faces (each where it falls in the part: steel girder ends, the runner coming up sees the far one),
## the ground, a frozen floor far below the street, and the hall's far ice wall across, which the hall draws with the left wall
## (IceLabHall), so the opening never shows the sky or an unrendered gap. Nothing in it glows, nothing in it is a hazard's colour.
func recess(batch: MeshBatch, side: int, face_x: float, start: float, end: float, gap: Vector2) -> void:
	var s: MeshLayer = batch.layer(skin.solid_material())
	var out: float = float(side)
	var depth: float = skin.hall_extra
	var floor_y: float = -skin.pit_depth
	var x_back: float = face_x + out * depth
	var x_min: float = minf(face_x, x_back)
	# The ground (faces up): the frozen floor.
	s.rect(Vector3(x_min, floor_y, -start), Vector3(depth, 0.0, 0.0), Vector3(0.0, 0.0, -(end - start)), skin.pit_floor_color, 0.0,
		MeshKit.PAT_IL_UNDER, Vector2.ZERO, Vector2.ONE, 2.0)
	for at: float in [gap.x, gap.y]:
		if at < start - 0.001 or at > end + 0.001:
			continue
		MeshKit.end_quad(s, x_min, x_min + depth, at, floor_y, RECESS_TOP, is_equal_approx(at, gap.x), skin.steel_color.darkened(0.1), 0.0,
			MeshKit.PAT_IL_STEEL, 0.0)
