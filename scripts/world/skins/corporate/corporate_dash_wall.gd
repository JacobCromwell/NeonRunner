class_name CorporateDashWall
extends RefCounted
## Corporate's dash wall (CorporateSkin.dash_wall; task H7b, GDD §9.14: "the same assets as the side walls, but
## facing towards the player, looking like a building in the middle of the street"): the end of one of the
## zone's towers standing across the street, built from CorporateTowers' own kit: the calm band's sterile
## cladding between brushed steel pilasters (corp_facade.gdshader's PODIUM, with its smoked-glass lobby on some),
## the towers' glass curtain walls and fins above a steel canopy, the military's prefab blast walls and armour
## plating, steel cornices, all in the zone's own colours. Four looks by the wall's seed:
## - 0 a tower's foot: the podium's cladding under a steel canopy, a curtain wall of dark glass in light steel
##   mullions over it, steel fins standing out of the glass;
## - 1 a lobby: the podium's smoked-glass lobby under the canopy, precast concrete over it with ribbon windows
##   in deep steel frames;
## - 2 a military compound's front: blast walls with an armoured block set back over them, a row of slit windows;
## - 3 a podium building: the calm band's cladding the whole way up to a plant floor under the cornice.
## Every look is a block with depth (the face set back from the box's face by FACE_BACK, the pilasters, the
## canopy and the cornice standing out to it), its sides in the cladding, cracks across its face and a patch
## where the cladding has come away: it reads as solid, and as something that breaks. Nothing glows (no lit
## offices: the wall is a dead block between the lit towers, its glass catching the sky), nothing in a hazard
## colour, nothing that reads as a sign (the brand's paint appears only as a plain dark band).
## DESIGN-TBD (docs/questions/h7b.md): which four buildings the wall is, and its cracks as the only cue; the GDD says only
## "the same building faces".
## Meshes are cached by size and look and shared by every wall.

## How far the facade plane sits back from the box's face (the relief the pilasters, canopy and cornice have).
const FACE_BACK: float = 0.5
## The cornice's height and the canopy's thickness and height above the floor (the curtain wall begins there).
const CORNICE: float = 0.7
const CANOPY_AT: float = 3.6
const CANOPY_THICK: float = 0.5
## The corner pilasters' width and the fins' spacing and width.
const PILASTER: float = 0.55
const FIN_SPACING: float = 3.0
const FIN_WIDTH: float = 0.16
## The seeds the PODIUM style is drawn with, by tone: corp_facade.gdshader gives a podium its smoked-glass lobby where
## hash11(seed * 1.7 + 0.3) < 0.45, so the looks that want a solid podium (a tower's foot, a podium building) and the one
## that wants the lobby each use seeds whose hash is well clear of that (test_dash_walls checks them by
## DashWallKit.hash11, which replicates the shader's).
const SEEDS_SOLID: Array[int] = [13, 111, 212]
const SEEDS_LOBBY: Array[int] = [43, 137, 248]
const SEEDS_PODIUM: Array[int] = [63, 163, 264]

## Weak: the skin owns this builder, so a strong reference back would keep both alive forever.
var skin: CorporateSkin:
	get:
		return _skin.get_ref() as CorporateSkin
var _skin: WeakRef
var _meshes: Dictionary = {}


func _init(p_skin: CorporateSkin) -> void:
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
			_glass_tower(facade, solid, size, tone)
		1:
			_lobby(facade, solid, size, tone)
		2:
			_compound(facade, solid, size, tone)
		_:
			_podium(facade, solid, size, tone)
	var mesh: ArrayMesh = DashWallKit.finish(batch)
	_meshes[key] = mesh
	return mesh


## A tower's foot: the podium's cladding up to a steel canopy, a curtain wall over it up to the cornice with steel
## fins standing out of the glass, steel pilasters at its ends.
func _glass_tower(facade: MeshLayer, solid: MeshLayer, size: Vector3, tone: int) -> void:
	var hx: float = size.x * 0.5
	var hz: float = size.z * 0.5
	var wall_z: float = hz - FACE_BACK
	var upper_top: float = DashWallKit.roof_of(size) - CORNICE
	var podium: Color = _cladding(tone)
	var tower: Color = skin.facade_colors[(2 + tone) % skin.facade_colors.size()].lightened(0.15)
	var steel: Color = skin.pilaster_color
	# A seed whose podium has no lobby: the cladding stays solid.
	var seed: float = float(SEEDS_SOLID[tone % SEEDS_SOLID.size()])
	_body(solid, size, wall_z, upper_top, podium)
	DashWallKit.face(facade, size, -hx, hx, 0.0, CANOPY_AT, wall_z, podium, CorporateTowers.STYLE_PODIUM, seed, hx, 0.0)
	DashWallKit.face(facade, size, -hx + PILASTER, hx - PILASTER, CANOPY_AT + CANOPY_THICK, upper_top, wall_z, tower,
		CorporateTowers.STYLE_CURTAIN, seed, hx, skin.band_top - CANOPY_AT)
	_fins(solid, size, wall_z, upper_top, steel)
	_canopy(solid, size, wall_z, steel, tone)
	_pilasters(solid, size, wall_z, upper_top, steel)
	_cornice(solid, size, steel)
	DashWallKit.roof_plant(solid, size, skin.gunmetal_color.lightened(0.12), steel, MeshKit.PAT_CORP_PLATE, 2.0, tone)
	_damage(solid, size, wall_z, tone, Vector4(-hx + 0.9, hx - 0.9, 0.9, upper_top - 0.6), podium, 1.4)


## A lobby: smoked glass in steel frames at the foot under the canopy, precast concrete over it with two ribbons of
## dark windows in deep steel frames, steel pilasters, the cornice.
func _lobby(facade: MeshLayer, solid: MeshLayer, size: Vector3, tone: int) -> void:
	var hx: float = size.x * 0.5
	var hz: float = size.z * 0.5
	var wall_z: float = hz - FACE_BACK
	var upper_top: float = DashWallKit.roof_of(size) - CORNICE
	var podium: Color = _cladding(tone + 1)
	var concrete: Color = skin.concrete_color.darkened(0.12 * float(tone))
	var steel: Color = skin.pilaster_color
	# A seed whose podium has the lobby of smoked glass.
	var seed: float = float(SEEDS_LOBBY[tone % SEEDS_LOBBY.size()])
	_body(solid, size, wall_z, upper_top, podium)
	DashWallKit.face(facade, size, -hx, hx, 0.0, CANOPY_AT, wall_z, podium, CorporateTowers.STYLE_PODIUM, seed, hx, 0.0)
	# The upper floors: precast concrete between the pilasters, ribbons of windows set into it.
	DashWallKit.box(solid, size, -hx + PILASTER, hx - PILASTER, CANOPY_AT + CANOPY_THICK, upper_top, -hz, wall_z, concrete,
		MeshKit.PAT_CORP_PLATE, MeshKit.FACE_PZ, 3.0)
	var dark := Color(0.04, 0.05, 0.06)
	var bay: float = (size.x - 2.0 * PILASTER) / float(maxi(2, roundi((size.x - 2.0 * PILASTER) / 3.2)))
	var bays: int = roundi((size.x - 2.0 * PILASTER) / bay)
	# One ribbon of windows or two, spread evenly over the storeys' height.
	var from: float = CANOPY_AT + CANOPY_THICK
	var available: float = upper_top - from
	var rows: int = 2 if available > 3.9 else 1
	var gap: float = (available - float(rows) * 1.2) / float(rows + 1)
	for row: int in rows:
		var h0: float = from + gap + (1.2 + gap) * float(row)
		for b: int in bays:
			var x0: float = -hx + PILASTER + bay * float(b) + 0.3
			var x1: float = -hx + PILASTER + bay * float(b + 1) - 0.3
			DashWallKit.box(solid, size, x0, x1, h0, h0 + 1.2, wall_z - 0.12, wall_z + 0.02, dark, MeshKit.PAT_GLASS,
				MeshKit.FACE_PZ, float(roundi(1.2 * 10.0)))
			MeshKit.frame(solid, Vector3((x0 + x1) * 0.5, h0 + 0.6 - size.y * 0.5, wall_z + 0.05), x1 - x0 + 0.24, 1.44, 0.14, 0.12,
				steel.darkened(0.15))
	_canopy(solid, size, wall_z, steel, tone)
	_pilasters(solid, size, wall_z, upper_top, steel)
	_cornice(solid, size, steel)
	DashWallKit.roof_plant(solid, size, skin.gunmetal_color.lightened(0.12), steel, MeshKit.PAT_CORP_PLATE, 2.0, tone + 2)
	_damage(solid, size, wall_z, tone + 2, Vector4(-hx + 0.9, hx - 0.9, 0.9, upper_top - 0.6), concrete, 1.5)


## A military compound's front: prefab blast walls (olive and grey T-walls) across the foot, an armoured block
## set back over them with a row of dark slit windows, a gunmetal cornice.
func _compound(facade: MeshLayer, solid: MeshLayer, size: Vector3, tone: int) -> void:
	var hx: float = size.x * 0.5
	var hz: float = size.z * 0.5
	var h_top: float = DashWallKit.roof_of(size)
	var wall_z: float = hz - 0.12
	var block_z: float = hz - 1.15
	var wall_top: float = 3.3
	var olive: Color = skin.blast_colors[tone % skin.blast_colors.size()]
	var armour: Color = skin.olive_color.lerp(skin.gunmetal_color, 0.25 * float(tone))
	var gun: Color = skin.gunmetal_color
	var seed: float = float(MeshKit.hash_i(tone, 2, 72) % 997)
	# The blast walls' ledge and the armoured block behind and over them.
	_body(solid, size, block_z, h_top - CORNICE, armour)
	DashWallKit.box(solid, size, -hx, hx, 0.0, wall_top, -hz, wall_z, olive.darkened(0.2), MeshKit.PAT_PLAIN,
		MeshKit.FACE_PX | MeshKit.FACE_NX | MeshKit.FACE_PY)
	DashWallKit.face(facade, size, -hx, hx, 0.0, wall_top, wall_z, olive, CorporateTowers.STYLE_BLAST, seed, hx, 0.0)
	# The capping course on the walls' top: a darker lip, the ledge's edge.
	DashWallKit.box(solid, size, -hx, hx, wall_top, wall_top + 0.14, block_z + 0.1, hz - 0.02, gun, MeshKit.PAT_CORP_PLATE,
		MeshKit.FACE_PZ | MeshKit.FACE_PY | MeshKit.FACE_PX | MeshKit.FACE_NX, 3.0)
	# The armoured block: heavy plates, and a row of slit windows (dark, unlit) in two rows.
	var top: float = h_top - CORNICE
	solid.box_between(Vector3(-hx, wall_top + 0.14 - size.y * 0.5, block_z - 0.01), Vector3(hx, top - size.y * 0.5, block_z),
		armour, 0.0, MeshKit.PAT_CORP_PLATE, MeshKit.FACE_PZ, 1.0)
	var dark := Color(0.03, 0.035, 0.04)
	for row: int in 2:
		var h: float = 5.1 + 2.0 * float(row)
		var x: float = -hx + 1.2
		while x + 1.6 < hx - 0.8:
			if MeshKit.hash01(tone, row, int(roundf(x * 3.0))) < 0.82:
				DashWallKit.box(solid, size, x, x + 1.6, h, h + 0.34, block_z - 0.03, block_z + 0.03, dark, MeshKit.PAT_PLAIN,
					MeshKit.FACE_PZ)
				DashWallKit.box(solid, size, x - 0.06, x + 1.66, h + 0.34, h + 0.4, block_z - 0.02, block_z + 0.06,
					gun.lightened(0.1), MeshKit.PAT_PLAIN, MeshKit.FACE_PZ | MeshKit.FACE_PY)
			x += 3.0
	_pilasters(solid, size, block_z, top, gun)
	# The corner posts of the blast walls' course, standing out to the face.
	for side: float in [-1.0, 1.0]:
		DashWallKit.box(solid, size, minf(side * hx, side * (hx - 0.4)), maxf(side * hx, side * (hx - 0.4)), 0.0,
			wall_top + 0.14, wall_z - 0.1, hz, gun, MeshKit.PAT_CORP_PLATE, MeshKit.ALL_FACES & ~MeshKit.FACE_NZ, 1.0)
	_cornice(solid, size, gun)
	DashWallKit.roof_plant(solid, size, gun.lightened(0.1), gun.lightened(0.25), MeshKit.PAT_CORP_PLATE, 1.0, tone + 3)
	_damage(solid, size, wall_z, tone + 3, Vector4(-hx + 0.8, hx - 0.8, 0.5, wall_top - 0.3), olive, 0.9, 1)
	_damage(solid, size, block_z, tone + 5, Vector4(-hx + 0.8, hx - 0.8, wall_top + 0.5, top - 0.5), armour, 1.0, 2)


## A podium building: the calm band's cladding in steel pilasters up to the steel fascia, a plant floor under
## the cornice, the lobby's smoked glass at the foot on some.
func _podium(facade: MeshLayer, solid: MeshLayer, size: Vector3, tone: int) -> void:
	var hx: float = size.x * 0.5
	var hz: float = size.z * 0.5
	var h_top: float = DashWallKit.roof_of(size)
	var wall_z: float = hz - FACE_BACK * 0.6
	var podium: Color = _cladding(tone + 2)
	var steel: Color = skin.pilaster_color
	var seed: float = float(SEEDS_PODIUM[tone % SEEDS_PODIUM.size()])
	var band: float = skin.band_top
	var plant_top: float = h_top - CORNICE
	_body(solid, size, wall_z, plant_top, podium)
	# The calm band exactly as the side walls draw it (its seed picks a lobby), over the full width.
	DashWallKit.face(facade, size, -hx, hx, 0.0, band, wall_z, podium, CorporateTowers.STYLE_PODIUM, seed, hx, 0.0)
	# The plant floor over it, set back a little, in the service style's louvres (far above the foot of the wall).
	var plant_z: float = wall_z - 0.35
	DashWallKit.box(solid, size, -hx, hx, band, plant_top, -hz, plant_z, podium.darkened(0.15), MeshKit.PAT_PLAIN,
		MeshKit.FACE_PX | MeshKit.FACE_NX | MeshKit.FACE_PY)
	DashWallKit.face(facade, size, -hx + PILASTER, hx - PILASTER, band, plant_top, plant_z, podium.lightened(0.1),
		CorporateTowers.STYLE_SERVICE, seed, hx, 0.0)
	# The slab between the two: a steel band standing out to the face with a brand-paint edge.
	DashWallKit.box(solid, size, -hx, hx, band - 0.1, band + 0.28, wall_z - 0.05, hz, steel, MeshKit.PAT_CORP_PLATE,
		MeshKit.ALL_FACES & ~MeshKit.FACE_NZ, 2.0)
	_pilasters(solid, size, wall_z, plant_top, steel)
	# Pilasters up the band, every bay, standing a little out of the cladding.
	var k: int = 1
	while -hx + float(k) * FIN_SPACING < hx - PILASTER - 0.4:
		var x: float = -hx + float(k) * FIN_SPACING
		DashWallKit.box(solid, size, x, x + 0.34, 0.6, band - 0.1, wall_z - 0.02, wall_z + 0.14, steel, MeshKit.PAT_CORP_PLATE,
			MeshKit.ALL_FACES & ~MeshKit.FACE_NZ, 2.0)
		k += 1
	_cornice(solid, size, steel)
	DashWallKit.roof_plant(solid, size, skin.gunmetal_color.lightened(0.12), steel, MeshKit.PAT_CORP_PLATE, 2.0, tone + 7)
	_damage(solid, size, wall_z, tone + 7, Vector4(-hx + 0.9, hx - 0.9, 0.9, band - 0.6), podium, 1.6)


## The podium's cladding for a tone: the zone's dark granite and graphite, lightened so the block reads against the
## dark street (it isn't a wall to run on).
func _cladding(tone: int) -> Color:
	return skin.podium_colors[tone % skin.podium_colors.size()].lightened(0.2)


## The canopy over the lobby: a brushed steel slab standing out to the box's face, a dark brand-paint edge on it.
func _canopy(solid: MeshLayer, size: Vector3, wall_z: float, steel: Color, tone: int) -> void:
	var hx: float = size.x * 0.5
	var hz: float = size.z * 0.5
	DashWallKit.box(solid, size, -hx, hx, CANOPY_AT, CANOPY_AT + CANOPY_THICK, wall_z - 0.05, hz, steel, MeshKit.PAT_CORP_PLATE,
		MeshKit.ALL_FACES & ~MeshKit.FACE_NZ, 2.0)
	DashWallKit.box(solid, size, -hx + 0.02, hx - 0.02, CANOPY_AT + 0.08, CANOPY_AT + 0.24, hz - 0.01, hz,
		skin.brand_paint_color if tone != 1 else steel.darkened(0.3), MeshKit.PAT_PLAIN, MeshKit.FACE_PZ)


## Steel fins standing out of the curtain wall, every FIN_SPACING metres from the canopy up to the cornice.
func _fins(solid: MeshLayer, size: Vector3, wall_z: float, top: float, steel: Color) -> void:
	var hx: float = size.x * 0.5
	var k: int = 1
	while -hx + float(k) * FIN_SPACING < hx - PILASTER - 0.4:
		var x: float = -hx + float(k) * FIN_SPACING
		DashWallKit.box(solid, size, x - FIN_WIDTH * 0.5, x + FIN_WIDTH * 0.5, CANOPY_AT + CANOPY_THICK, top, wall_z - 0.02,
			wall_z + 0.22, steel.darkened(0.12), MeshKit.PAT_CORP_PLATE, MeshKit.ALL_FACES, 2.0)
		k += 1


## The block's body behind its face: its sides and top only (the face is the facade's), from the floor up to
## `top`, z from the back to the face plane `z`.
func _body(solid: MeshLayer, size: Vector3, z: float, top: float, color: Color) -> void:
	var hx: float = size.x * 0.5
	var hz: float = size.z * 0.5
	DashWallKit.box(solid, size, -hx, hx, 0.0, top, -hz, z, color, MeshKit.PAT_CORP_PLATE,
		MeshKit.FACE_PX | MeshKit.FACE_NX | MeshKit.FACE_PY, 3.0)


## Brushed steel pilasters at both ends of the face, from the floor to `top`, standing out to the box's face.
func _pilasters(solid: MeshLayer, size: Vector3, wall_z: float, top: float, color: Color) -> void:
	var hx: float = size.x * 0.5
	var hz: float = size.z * 0.5
	for side: float in [-1.0, 1.0]:
		DashWallKit.box(solid, size, minf(side * hx, side * (hx - PILASTER)), maxf(side * hx, side * (hx - PILASTER)), 0.0,
			top, wall_z - 0.1, hz, color, MeshKit.PAT_CORP_PLATE, MeshKit.ALL_FACES & ~MeshKit.FACE_NZ, 2.0)


## The steel cornice along the top, the full depth, with a dark shadow line under its lip.
func _cornice(solid: MeshLayer, size: Vector3, color: Color) -> void:
	var hx: float = size.x * 0.5
	var hz: float = size.z * 0.5
	var h_top: float = DashWallKit.roof_of(size)
	DashWallKit.box(solid, size, -hx, hx, h_top - CORNICE, h_top, -hz, hz, color, MeshKit.PAT_CORP_PLATE,
		MeshKit.ALL_FACES & ~MeshKit.FACE_NY, 2.0)
	DashWallKit.box(solid, size, -hx + 0.04, hx - 0.04, h_top - CORNICE - 0.1, h_top - CORNICE, hz - FACE_BACK, hz - 0.05,
		color.darkened(0.5), MeshKit.PAT_PLAIN, MeshKit.FACE_PZ)


## What says "this breaks": cracks spreading across the face from a few points, and a patch (or two) where the
## cladding has come away, showing the dark concrete behind. `at` bounds both (x0, x1, h0, h1).
func _damage(solid: MeshLayer, size: Vector3, z: float, seed: int, at: Vector4, wall: Color, patch: float, hits: int = 2) -> void:
	var crack: Color = Color(0.03, 0.034, 0.04)
	DashWallKit.cracks(solid, size, z, at, hits, crack, seed)
	var px: float = lerpf(at.x + patch, at.y - patch, MeshKit.hash01(seed, 5, 9))
	var py: float = lerpf(at.z + 0.2, at.w - patch, MeshKit.hash01(seed, 6, 9))
	DashWallKit.spall(solid, size, px - patch * 0.4, px + patch * 0.4, py, py + patch * 0.7, z, 0.12, wall.darkened(0.32),
		skin.gunmetal_color.lightened(0.2), MeshKit.PAT_CORP_PLATE, 3.0)
