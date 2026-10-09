class_name GoldenDashWall
extends RefCounted
## The Golden Zone's dash wall (GoldenSkin.dash_wall; task H7b, GDD §9.14: "the same assets as the side walls, but
## facing towards the player, looking like a building in the middle of the street"): the front of one of the elite
## city's palaces standing across the walkways, built from GoldenFacades' own kit: polished granite under a gold
## kick line, the calm band's rusticated stone, ashlar or blind arcade, the cream entablature round its gold frieze,
## tall rounded windows in gold frames, champagne mirror glass on gold mullions (golden_facade.gdshader, the shader
## the walls draw their faces with), marble pilasters with gold capitals, a marble cornice with its gold rail
## (the solid kit's PAT_MARBLE and PAT_GOLD). Four looks by the wall's seed:
## - 0 a rusticated palace: the calm band's rusticated stone the whole way up to the entablature, half columns
##   between its bays;
## - 1 a rusticated palace: rusticated stone to a gold slab band, a storey of tall windows in their gold frames above;
## - 2 a tower's foot: stone below, a curtain wall of champagne mirror glass on gold mullions above it;
## - 3 a gatehouse: polished ashlar in long courses under the entablature, gold pilasters and a heavy cornice.
## Every look is a block with depth (the facade set back from the box's face, the pilasters, the plinth, the slab
## bands and the cornice standing out to it), its sides in marble, hairline cracks across its face and a chipped
## patch where the cladding has come away: solid, and breakable. Nothing glows (no lamp-lit rooms and no drapes
## in the windows: the shader's lit share is 0, and its windows are dark glass or gold mirror), nothing in a hazard
## colour, and no statue, banner or screen (a statue reads as a Gilded Sentinel, a banner or a screen as a sign).
## Meshes are cached by size and look and shared by every wall.
## DESIGN-TBD (docs/questions/h7b.md): which four buildings the wall is, and its cracks as the only cue; the GDD says only
## "the same building faces".

## How far the facade plane sits back from the box's face.
const FACE_BACK: float = 0.6
## The cornice's height, and the half columns' and pilasters' radius.
const CORNICE: float = 0.4
const COLUMN: float = 0.3
## The entablature's frieze is drawn this much lower than the walls' (8.6 m): the whole of its gold fluting then shows
## under the cornice of a roof at size.y - ROOF.
const FRIEZE_DROP: float = 0.6

## Weak: the skin owns this builder, so a strong reference back would keep both alive forever.
var skin: GoldenSkin:
	get:
		return _skin.get_ref() as GoldenSkin
var _skin: WeakRef
var _meshes: Dictionary = {}


func _init(p_skin: GoldenSkin) -> void:
	_skin = weakref(p_skin)


## The wall's look for a box of `size` and a seed, built once.
func mesh_for(size: Vector3, look_seed: int) -> ArrayMesh:
	var look: int = DashWallKit.look_of(look_seed)
	var tone: int = DashWallKit.tone_of(look_seed)
	var key: String = "%s_%d_%d" % [size, look, tone]
	var found: ArrayMesh = _meshes.get(key)
	if found != null:
		return found
	var batch := MeshBatch.new()
	var facade: MeshLayer = batch.layer(skin.facade_material())
	var solid: MeshLayer = batch.layer(skin.solid_material())
	match look:
		0:
			_rustic(facade, solid, size, tone)
		1:
			_windows(facade, solid, size, tone)
		2:
			_tower(facade, solid, size, tone)
		_:
			_gatehouse(facade, solid, size, tone)
	var mesh: ArrayMesh = DashWallKit.finish(batch)
	_meshes[key] = mesh
	return mesh


## A rusticated palace: the plinth, the calm band's rusticated stone and the entablature over it (the shader's own
## bays, laid out in whole bays), half columns standing out between the bays, the cornice.
func _rustic(facade: MeshLayer, solid: MeshLayer, size: Vector3, tone: int) -> void:
	var hx: float = size.x * 0.5
	var hz: float = size.z * 0.5
	var wall_z: float = hz - FACE_BACK
	var stone: Color = _stone(tone)
	var seed: float = float(3 * (7 + tone))
	_body(solid, size, wall_z, DashWallKit.roof_of(size) - CORNICE, stone)
	var x0: float = -hx + COLUMN * 2.0
	var x1: float = hx - COLUMN * 2.0
	_foot(facade, size, wall_z, seed)
	_frieze(facade, size, wall_z, stone, seed)
	var bays: int = DashWallKit.bay_faces(facade, size, x0, x1, 3.6, skin.plinth_top, skin.band_top - FRIEZE_DROP, wall_z, stone,
		GoldenFacades.STYLE_BAND, seed, 0.0, 2)
	var w: float = (x1 - x0) / float(bays)
	for k: int in bays + 1:
		_column(solid, size, x0 + w * float(k), wall_z + COLUMN * 0.4, skin.plinth_top, skin.band_top - FRIEZE_DROP - 0.2, stone)
	_string_courses(solid, size, wall_z, skin.band_top - FRIEZE_DROP)
	_cornice(solid, size, stone, wall_z)
	_end_piers(solid, size, wall_z, stone)
	_finials(solid, size, stone)
	_damage(solid, size, wall_z, tone, Vector4(-hx + 1.0, hx - 1.0, 1.2, skin.band_top - FRIEZE_DROP - 0.8), stone)


## A rusticated palace: stone to a gold slab band, a storey of tall windows in their gold frames above it.
func _windows(facade: MeshLayer, solid: MeshLayer, size: Vector3, tone: int) -> void:
	var hx: float = size.x * 0.5
	var hz: float = size.z * 0.5
	var wall_z: float = hz - FACE_BACK
	var stone: Color = _stone(tone + 1)
	var seed: float = float(3 * (11 + tone) + 0)
	var base_top: float = 4.1
	var top: float = DashWallKit.roof_of(size) - CORNICE
	_body(solid, size, wall_z, top, stone)
	_foot(facade, size, wall_z, seed)
	DashWallKit.bay_faces(facade, size, -hx + COLUMN * 2.0, hx - COLUMN * 2.0, 3.6, skin.plinth_top, base_top, wall_z, stone,
		GoldenFacades.STYLE_BAND, seed, 0.0, 2)
	# The windows' storey: its floor line (the slab band) at base_top, so a storey's cells start there; the cell
	# width by seed (golden_facade.gdshader's, GoldenFacades._cell_width).
	var cell: float = GoldenFacades._cell_width(int(seed))
	DashWallKit.bay_faces(facade, size, -hx + COLUMN * 2.0, hx - COLUMN * 2.0, cell, base_top, top, wall_z, stone,
		GoldenFacades.STYLE_UPPER, seed, skin.frieze_top - base_top, 2)
	# A gold slab band across the foot of the windows' storey, standing out of the face.
	DashWallKit.box(solid, size, -hx, hx, base_top - 0.12, base_top + 0.16, wall_z - 0.05, hz - 0.05, skin.gold_color,
		MeshKit.PAT_GOLD, MeshKit.ALL_FACES & ~MeshKit.FACE_NZ, 0.9)
	_string_courses(solid, size, wall_z, base_top)
	_cornice(solid, size, stone, wall_z)
	_end_piers(solid, size, wall_z, stone)
	_finials(solid, size, stone)
	_damage(solid, size, wall_z, tone + 2, Vector4(-hx + 1.0, hx - 1.0, 1.0, base_top - 0.6), stone)


## A tower's foot: stone below, a curtain wall of champagne mirror glass on gold mullions above it, gold fins
## standing out of the glass.
func _tower(facade: MeshLayer, solid: MeshLayer, size: Vector3, tone: int) -> void:
	var hx: float = size.x * 0.5
	var hz: float = size.z * 0.5
	var wall_z: float = hz - FACE_BACK
	var stone: Color = _stone(tone + 2)
	var seed: float = float(3 * (5 + tone) + 1)
	var base_top: float = 3.4
	var top: float = DashWallKit.roof_of(size) - CORNICE
	_body(solid, size, wall_z, top, stone)
	_foot(facade, size, wall_z, seed)
	DashWallKit.face(facade, size, -hx, hx, skin.plinth_top, base_top, wall_z, stone, GoldenFacades.STYLE_BAND, seed, hx, 0.0)
	DashWallKit.face(facade, size, -hx + COLUMN * 2.0, hx - COLUMN * 2.0, base_top + 0.2, top, wall_z, stone, GoldenFacades.STYLE_TOWER,
		seed, hx, skin.frieze_top - base_top - 0.2)
	DashWallKit.box(solid, size, -hx, hx, base_top - 0.1, base_top + 0.3, wall_z - 0.05, hz - 0.05, stone.lightened(0.05),
		MeshKit.PAT_MARBLE, MeshKit.ALL_FACES & ~MeshKit.FACE_NZ, 0.0)
	DashWallKit.box(solid, size, -hx, hx, base_top + 0.3, base_top + 0.38, wall_z - 0.02, hz - 0.1, skin.gold_color, MeshKit.PAT_GOLD,
		MeshKit.FACE_PZ | MeshKit.FACE_PY, 0.9)
	var fins: int = maxi(2, roundi(size.x / 4.5))
	for k: int in fins + 1:
		var x: float = lerpf(-hx + COLUMN * 2.0 + 0.3, hx - COLUMN * 2.0 - 0.3, float(k) / float(fins))
		DashWallKit.box(solid, size, x - 0.07, x + 0.07, base_top + 0.38, top, wall_z - 0.02, wall_z + 0.3, skin.gold_color,
			MeshKit.PAT_GOLD, MeshKit.ALL_FACES & ~MeshKit.FACE_NZ, 0.9)
	_string_courses(solid, size, wall_z, base_top)
	_cornice(solid, size, stone, wall_z)
	_end_piers(solid, size, wall_z, stone)
	_finials(solid, size, stone)
	_damage(solid, size, wall_z, tone + 4, Vector4(-hx + 1.0, hx - 1.0, 0.9, base_top - 0.5), stone)


## A gatehouse: polished ashlar in long courses under the entablature, gold pilasters between wide bays, a heavy
## cornice.
func _gatehouse(facade: MeshLayer, solid: MeshLayer, size: Vector3, tone: int) -> void:
	var hx: float = size.x * 0.5
	var hz: float = size.z * 0.5
	var wall_z: float = hz - FACE_BACK
	var stone: Color = _stone(tone + 3)
	var seed: float = float(3 * (13 + tone) + 1)
	_body(solid, size, wall_z, DashWallKit.roof_of(size) - CORNICE, stone)
	_foot(facade, size, wall_z, seed)
	DashWallKit.face(facade, size, -hx, hx, skin.plinth_top, skin.band_top - FRIEZE_DROP, wall_z, stone, GoldenFacades.STYLE_BAND, seed, hx, 0.0)
	_frieze(facade, size, wall_z, stone, seed)
	var bays: int = maxi(2, roundi(size.x / 4.5))
	for k: int in bays + 1:
		var x: float = lerpf(-hx + COLUMN * 2.0, hx - COLUMN * 2.0, float(k) / float(bays))
		DashWallKit.box(solid, size, x - 0.2, x + 0.2, skin.plinth_top, DashWallKit.roof_of(size) - CORNICE, wall_z - 0.02, wall_z + 0.25, stone.lightened(0.04),
			MeshKit.PAT_MARBLE, MeshKit.ALL_FACES & ~MeshKit.FACE_NZ, 0.0)
		DashWallKit.box(solid, size, x - 0.26, x + 0.26, DashWallKit.roof_of(size) - CORNICE - 0.3, DashWallKit.roof_of(size) - CORNICE, wall_z - 0.02, wall_z + 0.3,
			skin.gold_color, MeshKit.PAT_GOLD, MeshKit.ALL_FACES & ~MeshKit.FACE_NZ, 0.9)
		DashWallKit.box(solid, size, x - 0.26, x + 0.26, skin.plinth_top, skin.plinth_top + 0.3, wall_z - 0.02, wall_z + 0.3,
			skin.granite_color, MeshKit.PAT_MARBLE, MeshKit.ALL_FACES & ~MeshKit.FACE_NZ, 1.0)
	_string_courses(solid, size, wall_z, skin.band_top - FRIEZE_DROP)
	_cornice(solid, size, stone, wall_z)
	_end_piers(solid, size, wall_z, stone)
	_finials(solid, size, stone)
	_damage(solid, size, wall_z, tone + 6, Vector4(-hx + 1.0, hx - 1.0, 1.2, skin.band_top - FRIEZE_DROP - 0.8), stone)


## Gold string courses where the band's inlay lines run (the wall-run marks, 2 m and 4 m: the shader draws them on
## every face of the band), standing a little out of the face up to `up_to`: the lines read as the building's own.
func _string_courses(solid: MeshLayer, size: Vector3, wall_z: float, up_to: float) -> void:
	var hx: float = size.x * 0.5
	for mark: float in skin.wall_height_marks:
		if mark < up_to - 0.1:
			DashWallKit.box(solid, size, -hx + COLUMN * 2.0, hx - COLUMN * 2.0, mark - 0.045, mark + 0.045, wall_z - 0.01, wall_z + 0.05,
				skin.gold_color, MeshKit.PAT_GOLD, MeshKit.FACE_PZ | MeshKit.FACE_PY | MeshKit.FACE_NY, 0.9)


## The granite plinth at the foot of every look, polished slabs under a gold kick line, standing a little out
## of the face.
func _foot(facade: MeshLayer, size: Vector3, wall_z: float, seed: float) -> void:
	var hx: float = size.x * 0.5
	DashWallKit.face(facade, size, -hx, hx, 0.0, skin.plinth_top, wall_z + 0.08, skin.granite_color, GoldenFacades.STYLE_PLINTH, seed,
		hx, 0.0)


## The entablature's frieze across the whole width, from just under the band's top up to the roof line (its gold
## fluting runs under the cornice).
func _frieze(facade: MeshLayer, size: Vector3, wall_z: float, stone: Color, seed: float) -> void:
	var hx: float = size.x * 0.5
	DashWallKit.face(facade, size, -hx, hx, skin.band_top - FRIEZE_DROP, DashWallKit.roof_of(size), wall_z, stone,
		GoldenFacades.STYLE_FRIEZE, seed, hx, FRIEZE_DROP)


## The marble cornice standing out to the face, with its gold line and a gold rail's cap on top.
func _cornice(solid: MeshLayer, size: Vector3, stone: Color, wall_z: float) -> void:
	var hx: float = size.x * 0.5
	var hz: float = size.z * 0.5
	var top: float = DashWallKit.roof_of(size)
	DashWallKit.box(solid, size, -hx, hx, top - CORNICE, top, -hz, hz, stone.lightened(0.04), MeshKit.PAT_MARBLE,
		MeshKit.ALL_FACES & ~MeshKit.FACE_NY, 0.0)
	DashWallKit.box(solid, size, -hx + 0.03, hx - 0.03, top - CORNICE - 0.12, top - CORNICE, wall_z + 0.05, hz - 0.03, stone.darkened(0.2),
		MeshKit.PAT_MARBLE, MeshKit.FACE_PZ | MeshKit.FACE_NY, 0.0)
	DashWallKit.box(solid, size, -hx + 0.02, hx - 0.02, top - CORNICE + 0.08, top - CORNICE + 0.2, hz - 0.01, hz, skin.gold_color,
		MeshKit.PAT_GOLD, MeshKit.FACE_PZ, 0.9)


## Urn finials on the roof line over the end piers and the middle: a stone plinth, an urn, a gold cap, reaching up to
## the box's top.
func _finials(solid: MeshLayer, size: Vector3, stone: Color) -> void:
	DashWallKit.finials(solid, size, stone.lightened(0.04), skin.gold_color, MeshKit.PAT_MARBLE, MeshKit.PAT_GOLD)


## Square piers at both ends of the face, from the floor to the cornice, standing out to the box's face: the
## building's corners (and the open strip beside each side wall).
func _end_piers(solid: MeshLayer, size: Vector3, wall_z: float, stone: Color) -> void:
	var hx: float = size.x * 0.5
	var hz: float = size.z * 0.5
	for side: float in [-1.0, 1.0]:
		DashWallKit.box(solid, size, minf(side * hx, side * (hx - COLUMN * 2.0)), maxf(side * hx, side * (hx - COLUMN * 2.0)), 0.0,
			DashWallKit.roof_of(size) - CORNICE, wall_z - 0.1, hz, stone.lightened(0.03), MeshKit.PAT_MARBLE, MeshKit.ALL_FACES & ~MeshKit.FACE_NZ, 1.0)
		DashWallKit.box(solid, size, minf(side * hx, side * (hx - COLUMN * 2.0 - 0.04)),
			maxf(side * hx, side * (hx - COLUMN * 2.0 - 0.04)), 0.0, 0.3, wall_z - 0.1, hz, skin.granite_color,
			MeshKit.PAT_MARBLE, MeshKit.FACE_PZ | MeshKit.FACE_PX | MeshKit.FACE_NX, 1.0)


## A half column of marble (an octagonal shaft on a granite base under a gold capital) at x, standing out of the
## facade plane.
func _column(solid: MeshLayer, size: Vector3, x: float, z: float, h0: float, h1: float, stone: Color) -> void:
	DashWallKit.column(solid, size, x, z, h0, h1, COLUMN, skin.granite_color, stone.lightened(0.04), skin.gold_color, MeshKit.PAT_MARBLE,
		MeshKit.PAT_MARBLE, MeshKit.PAT_GOLD, 0.9)


## The block's body behind its face: its sides and top only, from the floor up to `top`, z from the back to `z`.
func _body(solid: MeshLayer, size: Vector3, z: float, top: float, color: Color) -> void:
	var hx: float = size.x * 0.5
	var hz: float = size.z * 0.5
	DashWallKit.box(solid, size, -hx, hx, 0.0, top, -hz, z, color, MeshKit.PAT_MARBLE,
		MeshKit.FACE_PX | MeshKit.FACE_NX | MeshKit.FACE_PY, 0.0)


## A stone colour for a tone: the zone's champagne, cream and ivory cladding, warmed toward the gold and a shade
## deeper than the walls beside it, so the building stands out of them at a distance (their own white would lose it).
func _stone(tone: int) -> Color:
	var picks: Array[int] = [3, 1, 2]
	return skin.stone_colors[picks[tone % picks.size()] % skin.stone_colors.size()].lerp(skin.gold_color, 0.3).darkened(0.12)


## What says "this breaks": hairline cracks (a darker shade of the marble's veins) spreading across the face from a
## few points (the elite's city keeps its stone clean: no fallen patches). `at` bounds them (x0, x1, h0, h1).
func _damage(solid: MeshLayer, size: Vector3, z: float, seed: int, at: Vector4, _stone: Color) -> void:
	DashWallKit.cracks(solid, size, z + 0.01, at, 3, skin.vein_color.darkened(0.55), seed, 0.75)
