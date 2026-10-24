class_name CorporateMilitary
extends RefCounted
## The Corporate backdrop's first layer, closest to the player (CorporateTowers' buildings stand on it; the owner's
## reference image, docs/art/reference/corporate_backdrop.webp: "street level: military walls, bunkers, barricades"):
## every building's wall through the wall-run band is the military's, as paint on one flat face (corp_facade.gdshader,
## so nothing sticks out of the wall-run band and a face costs a quad):
## - PLATE: olive armour plate in framed panels over a precast skirt, cable runs and stencilled unit codes;
## - GATE: the same with heavy steel gates in it;
## - CAMO: stacked precast blocks under camouflage, chamfered like a bunker's;
## - BLOCK: the same blocks bare, a jersey-barrier wall;
## - BLAST: the prefab T-walls of a military compound (CorporateTowers' compounds keep their own look).
## Above the band the military building goes on to a roof of its own, between skin.mil_min_height and mil_max_height: its
## upper storeys (slit windows and pipes, or more blocks), a sandbag or precast parapet with wire on some, and on the
## roof deck behind it dishes, masts, water tanks, supply containers, a radar dome and a watchtower with a searchlight
## aimed at the sky. The corporate towers rise from behind that roof (CorporateTowers: they are set back by
## skin.deck_setbacks), so the street shows the military first. Everything above the band starts at decor height or
## stays flat on the face; the roof deck's props sit behind the wall plane and are never over the lanes.
## All variety comes from hashing the building's side and id, so a chunk cut never changes a building.

enum Look { PLATE, GATE, CAMO, BLOCK, BLAST }

## What a prop's slots are spaced at along a roof, and the parapet's height and depth.
const SLOT: float = 5.0
const PARAPET_HEIGHT: float = 0.9
const PARAPET_DEPTH: float = 1.0
## Half the footprint across the roof deck of each prop kind (roof(): dish, mast, tank, containers, radar dome).
const HALF_WIDTH: Array[float] = [0.6, 0.2, 1.4, 1.3, 1.9]

## Weak: the skin owns this builder, so a strong reference back would keep both alive forever.
var skin: CorporateSkin:
	get:
		return _skin.get_ref() as CorporateSkin
var towers: CorporateTowers:
	get:
		return _towers.get_ref() as CorporateTowers
var _skin: WeakRef
var _towers: WeakRef
var _templates: Dictionary = {}


func _init(p_skin: CorporateSkin, p_towers: CorporateTowers) -> void:
	_skin = weakref(p_skin)
	_towers = weakref(p_towers)


## The look of a building's street-level wall: a compound's blast walls or camouflaged blocks, else by the skin's weights.
func look_of(side: int, id: int, kind: int) -> int:
	if kind == CorporateTowers.Kind.COMPOUND:
		return Look.BLAST if MeshKit.hash01(side, id, 61) < 0.5 else Look.CAMO
	var w: Vector4 = skin.mil_weights
	var pick: float = MeshKit.hash01(side, id, 60) * (w.x + w.y + w.z + w.w)
	if pick < w.x:
		return Look.PLATE
	pick -= w.x
	if pick < w.y:
		return Look.GATE
	pick -= w.y
	return Look.CAMO if pick < w.z else Look.BLOCK


## The height of the military building's roof (a tower's roof deck, a low building's roof).
func roof_height(side: int, id: int) -> float:
	return lerpf(skin.mil_min_height, skin.mil_max_height, MeshKit.hash01(side, id, 62))


## The facade style of a look's wall below the band's top (corp_facade.gdshader).
func style_of(look: int) -> int:
	match look:
		Look.PLATE:
			return CorporateTowers.STYLE_MIL_PLATE
		Look.GATE:
			return CorporateTowers.STYLE_MIL_GATE
		Look.BLAST:
			return CorporateTowers.STYLE_BLAST
	return CorporateTowers.STYLE_MIL_CAMO


## The wall's face colour: the plate's olive (a pick of skin.plate_colors), the blocks' precast, the blast walls' olive.
func color_of(look: int, side: int, id: int) -> Color:
	match look:
		Look.PLATE, Look.GATE:
			return skin.plate_colors[MeshKit.hash_i(side, id, 66) % skin.plate_colors.size()]
		Look.BLAST:
			return skin.blast_colors[0]
	return skin.concrete_block_color


## The face's vertex alpha: how much of a block wall is camouflaged (1) or bare (0), else 0.
func lit_of(look: int) -> float:
	return 1.0 if look == Look.CAMO else 0.0


## The cornice's colour along the band's top: a concrete string course.
func trim_color(b: CorporateTowers.Building) -> Color:
	if b.kind == CorporateTowers.Kind.COMPOUND:
		return skin.gunmetal_color
	return skin.olive_color.lerp(skin.gunmetal_color, 0.5).lightened(0.1)


## The military building's wall between u0 and u1: the band's wall, the upper storeys up to the roof (tower and low
## buildings; a compound's wall stops at the band and its block stands behind it), the parapet on the roof's edge.
func wall(facade: MeshLayer, solid: MeshLayer, b: CorporateTowers.Building, face_x: float, u0: float, u1: float) -> void:
	var side: int = b.side
	var band: float = skin.band_top
	var color: Color = color_of(b.look, side, b.id)
	towers.face(facade, side, face_x, u0, u1, 0.0, band, color, lit_of(b.look), style_of(b.look), b.seed)
	if b.kind == CorporateTowers.Kind.COMPOUND or b.mil_top <= band + 0.05:
		return
	var plated: bool = b.look == Look.PLATE or b.look == Look.GATE
	var up_style: int = CorporateTowers.STYLE_MIL_UPPER if plated else CorporateTowers.STYLE_MIL_CAMO
	var up_lit: float = 0.12 + 0.28 * MeshKit.hash01(side, b.id, 67) if plated else lit_of(b.look)
	towers.face(facade, side, face_x, u0, u1, band, b.mil_top, color, up_lit, up_style, b.seed + 1)
	# The roof's edge: a sandbag parapet, a precast cap or bare, with a coil of wire along some.
	var zc: float = -(u0 + u1) * 0.5
	var r: float = MeshKit.hash01(side, b.id, 63)
	var h: float = 0.0
	if r < 0.5:
		h = PARAPET_HEIGHT
		solid.box(Vector3(face_x + side * PARAPET_DEPTH * 0.5, b.mil_top + h * 0.5, zc), Vector3(PARAPET_DEPTH, h, u1 - u0),
			skin.sandbag_color, 0.0, MeshKit.PAT_CORP_PLATE, MeshKit.NO_BOTTOM, 4.0)
	elif r < 0.8:
		h = 0.4
		solid.box(Vector3(face_x + side * 0.4, b.mil_top + h * 0.5, zc), Vector3(0.8, h, u1 - u0), skin.concrete_block_color,
			0.0, MeshKit.PAT_CORP_PLATE, MeshKit.NO_BOTTOM, 3.0)
	if MeshKit.hash01(side, b.id, 68) < 0.4:
		for i: int in 2:
			var wx: float = face_x + side * (0.3 + 0.35 * i)
			solid.prism_xform(Transform3D(Basis(Vector3(0.22, 0, 0), Vector3(0, 0, -(u1 - u0)), Vector3(0, 0.22, 0)),
				Vector3(wx, b.mil_top + h + 0.2, -u0)), 6, Color(0.1, 0.1, 0.11), 0.0, MeshKit.PAT_RIBS, false)


## The face of a military building's roof where it steps up over its lower neighbour at its near end (the wall at
## distance b0 reaches back MIL_DEPTH from the street, facing the runner): so a taller roof never shows through to the
## tower behind it. `lower` is the neighbour's roof height.
func step_face(facade: MeshLayer, b: CorporateTowers.Building, face_x: float, lower: float) -> void:
	var top: float = b.mil_top
	if b.kind == CorporateTowers.Kind.COMPOUND or top <= lower + 0.05:
		return
	var depth: float = b.setback if b.kind == CorporateTowers.Kind.TOWER else 8.0
	var x0: float = minf(face_x, face_x + b.side * depth)
	MeshKit.end_quad(facade, x0, x0 + depth, b.b0, lower, top, false, color_of(b.look, b.side, b.id), 0.2,
		CorporateTowers.STYLE_MIL_UPPER, float(b.seed + 2))


## The roof deck's props between track distances start and end: along the roof at one slot every SLOT metres, by hash a
## dish, a mast, a water tank, a stack of supply containers, a radar dome or nothing; and on some a watchtower at the
## near end. `depth` is how far back the roof deck reaches from the wall face (a tower's setback), so props keep clear
## of the tower's face; `skip` is a stretch of the roof left to something else (a low building's roof board).
func roof(solid: MeshLayer, glow: MeshLayer, b: CorporateTowers.Building, face_x: float, start: float, end: float,
		depth: float, skip: Vector2) -> void:
	var side: int = b.side
	var id: int = b.id
	var y: float = b.mil_top
	var slots: int = int(floorf((b.b1 - b.b0 - 3.0) / SLOT))
	for j: int in slots:
		var at: float = b.b0 + 2.5 + SLOT * float(j)
		if at < start or at >= end or (at > skip.x and at < skip.y):
			continue
		if MeshKit.hash01(side, id, 70 + j) >= skin.roof_props_share:
			continue
		var kind: int = MeshKit.hash_i(side, id, 90 + j) % 5
		# Half a prop's footprint across the deck: bulky ones that don't fit it become a dish.
		var half: float = HALF_WIDTH[kind]
		if half * 2.0 + 0.6 > depth:
			kind = 0
			half = HALF_WIDTH[0]
		var back: float = half + 0.3 + (depth - 0.6 - half * 2.0) * MeshKit.hash01(side, id, 110 + j)
		var base := Vector3(face_x + side * back, y, -at)
		match kind:
			0:
				solid.append(_dish(side, 2.4 + 1.4 * MeshKit.hash01(side, id, 130 + j)), Transform3D(Basis.IDENTITY, base))
			1:
				var mh: float = 6.0 + 6.0 * MeshKit.hash01(side, id, 150 + j)
				solid.box(base + Vector3(0, mh * 0.5, 0), Vector3(0.28, mh, 0.28), skin.gunmetal_color)
				solid.box(base + Vector3(0, mh * 0.5 - 1.5, 0), Vector3(0.9, 0.12, 0.12), skin.gunmetal_color)
				solid.box(base + Vector3(0, mh + 0.2, 0), Vector3(0.4, 0.4, 0.4), skin.flood_color, 0.9)
				glow.rect(base + Vector3(-1.6, mh - 1.4, 0.0), Vector3(3.2, 0, 0), Vector3(0, 3.2, 0), skin.flood_color, 0.3,
					MeshKit.SHAPE_RADIAL)
			2:
				solid.append(_tank(), Transform3D(Basis.IDENTITY, base))
			3:
				towers.containers(solid, side, face_x + side * (back - 1.3), at, y, MeshKit.hash_i(side, id, 170 + j))
			_:
				solid.prism(base, 1.6, 1.4, 10, skin.gunmetal_color)
				solid.prism_xform(Transform3D(Basis.from_scale(Vector3(1.9, 1.7, 1.9)), base + Vector3(0, 1.4, 0)), 10,
					Color(0.5, 0.52, 0.54))
	# A watchtower at the near end, its searchlight aimed at the sky ahead and leaning away from the street.
	var wd: float = b.b0 + 1.6
	if MeshKit.hash01(side, id, 69) < 0.3 and wd >= start and wd < end and depth >= 4.0:
		solid.append(towers.watchtower(side), Transform3D(Basis.IDENTITY, Vector3(face_x + side * 1.8, y, -wd)))
		towers.beam(glow, Vector3(face_x + side * 1.8, y + 9.4, -wd), Vector3(side * 0.3, 1.0, -0.55).normalized(), 34.0, 1.4)


## A satellite dish on a stand, its foot at the origin: a pole and a flat disc tilted up and toward the street, its
## feed on an arm. Cached per side.
func _dish(side: int, height: float) -> MeshLayer:
	var key := Vector3i(1, side, roundi(height * 10.0))
	var found: MeshLayer = _templates.get(key)
	if found != null:
		return found
	var t := MeshLayer.new()
	var gun: Color = skin.gunmetal_color
	t.box(Vector3(0, height * 0.5, 0), Vector3(0.14, height, 0.14), gun)
	t.box(Vector3(0, height, 0), Vector3(0.5, 0.3, 0.5), gun.lightened(0.1))
	var tilt := Basis(Vector3.BACK, side * 0.9)
	var r: float = 0.9 + 0.1 * height
	var c := Vector3(0, height + 0.4, 0)
	t.prism_xform(Transform3D(tilt * Basis.from_scale(Vector3(r, 0.12, r)), c), 12, Color(0.5, 0.52, 0.54))
	t.prism_xform(Transform3D(tilt * Basis.from_scale(Vector3(r * 0.86, 0.04, r * 0.86)), c + tilt * Vector3(0, 0.1, 0)), 12,
		Color(0.32, 0.34, 0.37))
	t.box_xform(Transform3D(tilt.scaled_local(Vector3(0.05, r * 0.95, 0.05)), c + tilt * Vector3(0, r * 0.5, 0)), gun)
	t.box_xform(Transform3D(tilt.scaled_local(Vector3(0.22, 0.22, 0.22)), c + tilt * Vector3(0, r * 0.98, 0)), gun.darkened(0.2))
	_templates[key] = t
	return t


## A water tank on four legs, its foot at the origin (the kind of rooftop clutter a fortified building has).
func _tank() -> MeshLayer:
	var key := Vector3i(2, 0, 0)
	var found: MeshLayer = _templates.get(key)
	if found != null:
		return found
	var t := MeshLayer.new()
	var gun: Color = skin.gunmetal_color
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			t.box(Vector3(sx * 0.9, 1.3, sz * 0.9), Vector3(0.14, 2.6, 0.14), gun)
	t.box(Vector3(0, 1.4, 0), Vector3(2.0, 0.1, 2.0), gun)
	t.prism(Vector3(0, 2.6, 0), 1.35, 2.0, 8, skin.olive_color.lightened(0.05), 0.0, MeshKit.PAT_RIBS)
	t.prism(Vector3(0, 4.6, 0), 0.9, 0.3, 8, skin.olive_color.darkened(0.1))
	_templates[key] = t
	return t
