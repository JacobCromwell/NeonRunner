class_name CityDashWall
extends RefCounted
## The Neon City's dash wall (CitySkin.dash_wall; task H7b, GDD §9.14: "the same assets as the side walls, but
## facing towards the player, looking like a building in the middle of the street"): a dark apartment or office block
## standing across the street, built from CityTowers' own kit: the four window grids of facade.gdshader (office glass,
## punched windows, ribbon windows, tall slots) in the towers' own slate colours, concrete slab bands between the
## storeys, corner piers and a cornice with a pale trim of dead neon tube (the zone's neon colours, painted and
## unlit). One layout per look, by the wall's seed:
## - 0 offices: the office glass grid;
## - 1 apartments: punched windows;
## - 2 a ribbon block: ribbon windows;
## - 3 a slot block: tall slots.
## Every look is a block with depth (the facade set back from the box's face, the slab bands, piers and cornice standing
## out to it), its sides in concrete, a mechanical box on the roof, cracks across its face and a patch where the
## cladding has come away: solid, and breakable. It is the one dark thing among the lit towers: nothing in it glows
## (the shader's lit share is 0, and the neon trims are paint), nothing in a hazard colour (the violet and blue
## of the City's neon, never pink or cyan), no billboard or banner (a sign). Meshes are cached by size and look and
## shared by every wall.

## How far the facade plane sits back from the box's face.
const FACE_BACK: float = 0.5
const CORNICE: float = 0.55
const PIER: float = 0.5
## The facade styles' storey heights (facade.gdshader: 0 office glass, 1 punched, 2 ribbon, 3 tall slots) and cell
## widths.
const STOREYS: Array[float] = [3.3, 3.0, 3.3, 3.3]
const CELLS: Array[float] = [1.3, 2.2, 4.0, 1.6]

## Weak: the skin owns this builder, so a strong reference back would keep both alive forever.
var skin: CitySkin:
	get:
		return _skin.get_ref() as CitySkin
var _skin: WeakRef
var _meshes: Dictionary = {}


func _init(p_skin: CitySkin) -> void:
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
	_block(facade, solid, size, look, tone)
	var mesh: ArrayMesh = DashWallKit.finish(batch)
	_meshes[key] = mesh
	return mesh


## A block in window grid `style`: the grid from the floor to the cornice, in whole cells, with a slab band at each
## storey's floor, piers at the ends, a pale unlit trim under the cornice and a mechanical box on the roof.
func _block(facade: MeshLayer, solid: MeshLayer, size: Vector3, style: int, tone: int) -> void:
	var hx: float = size.x * 0.5
	var hz: float = size.z * 0.5
	var wall_z: float = hz - FACE_BACK
	var wall: Color = _wall(tone + style)
	var seed: float = float(MeshKit.hash_i(style, tone, 111) % 997)
	var top: float = size.y - CORNICE
	var storey: float = STOREYS[style]
	DashWallKit.box(solid, size, -hx, hx, 0.0, top, -hz, wall_z, wall.darkened(0.05), MeshKit.PAT_CONCRETE,
		MeshKit.FACE_PX | MeshKit.FACE_NX | MeshKit.FACE_PY, 0.0)
	# The window grid across the face, cut into whole cells (a window is never cut by the building's edge).
	DashWallKit.bay_faces(facade, size, -hx + PIER, hx - PIER, CELLS[style], 0.0, top, wall_z, wall, style, seed, 0.0, 2)
	# Slab bands at each storey's floor, standing out of the face: concrete, a shade lighter than the wall.
	var h: float = storey
	while h < top - 0.4:
		DashWallKit.box(solid, size, -hx, hx, h - 0.1, h + 0.12, wall_z - 0.05, wall_z + 0.16, wall.lightened(0.08), MeshKit.PAT_CONCRETE,
			MeshKit.ALL_FACES & ~MeshKit.FACE_NZ, 0.0)
		h += storey
	# Piers at both ends, from the floor to the cornice, standing out to the box's face.
	for side: float in [-1.0, 1.0]:
		DashWallKit.box(solid, size, minf(side * hx, side * (hx - PIER)), maxf(side * hx, side * (hx - PIER)), 0.0, top, wall_z - 0.1, hz,
			wall.lightened(0.05), MeshKit.PAT_CONCRETE, MeshKit.ALL_FACES & ~MeshKit.FACE_NZ, 0.0)
	# The cornice, and a trim of dead neon tube along it (paint, never lit).
	DashWallKit.box(solid, size, -hx, hx, size.y - CORNICE, size.y, -hz, hz, wall.lightened(0.1), MeshKit.PAT_CONCRETE,
		MeshKit.ALL_FACES & ~MeshKit.FACE_NY, 0.0)
	var tube: Color = skin.neon_colors[(tone + style) % skin.neon_colors.size()].darkened(0.45)
	DashWallKit.box(solid, size, -hx + 0.06, hx - 0.06, size.y - CORNICE + 0.1, size.y - CORNICE + 0.22, hz - 0.05, hz, tube,
		MeshKit.PAT_PLAIN, MeshKit.FACE_PZ)
	DashWallKit.box(solid, size, -hx + 0.03, hx - 0.03, size.y - CORNICE - 0.1, size.y - CORNICE, wall_z + 0.05, hz - 0.03,
		Color(0.02, 0.022, 0.04), MeshKit.PAT_PLAIN, MeshKit.FACE_PZ | MeshKit.FACE_NY)
	_damage(solid, size, wall_z, tone + style, Vector4(-hx + 0.9, hx - 0.9, 0.9, top - 0.6), wall)


## A slate wall colour for a tone: the City's own very dark facades, lifted so the block reads against the black
## towers and the night around it (it isn't a wall to run on).
func _wall(tone: int) -> Color:
	return skin.facade_colors[tone % skin.facade_colors.size()].lightened(0.2)


## What says "this breaks": cracks across the face from a few points, and a patch where the cladding has come away
## down to the bare concrete. `at` bounds both (x0, x1, h0, h1).
func _damage(solid: MeshLayer, size: Vector3, z: float, seed: int, at: Vector4, wall: Color) -> void:
	DashWallKit.cracks(solid, size, z + 0.01, at, 2 + seed % 2, Color(0.015, 0.015, 0.025), seed, 0.9)
	var px: float = lerpf(at.x + 0.9, at.y - 0.9, MeshKit.hash01(seed, 5, 69))
	var py: float = lerpf(at.z + 0.1, maxf(at.z + 0.2, at.w - 1.0), MeshKit.hash01(seed, 6, 69))
	DashWallKit.spall(solid, size, px - 0.6, px + 0.6, py, py + 0.8, z + 0.01, 0.1, wall.darkened(0.5), wall.darkened(0.25),
		MeshKit.PAT_CONCRETE, 0.0)
