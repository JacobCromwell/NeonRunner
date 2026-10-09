class_name MarketDashWall
extends RefCounted
## The Marketplace's dash wall (MarketplaceSkin.dash_wall; task H7b, GDD §9.14: "the same assets as the side
## walls, but facing towards the player, looking like a building in the middle of the street"): a shopfront
## standing across the market, built from MarketFacades' own kit: the tiled plinth, shop windows with their
## displays of goods behind the glass (the very window templates the walls place), metal-clad piers, sun-bleached
## stucco storeys over them with rounded aluminium-framed windows, their roller shutters down, a stucco cornice
## (shopfront.gdshader and the solid kit's PAT_STUCCO). Four looks by the wall's seed:
## - 0 a shop row: three or four shop windows under two storeys of shuttered windows;
## - 1 a market hall: the hall's large smooth panels under its glass vault, a plinth of skirting panels;
## - 2 wide shop windows: fewer, wider displays between heavy piers, a plain stucco storey over them;
## - 3 an arcade: the shop row under a lean-to of corrugated tin on posts, standing out to the face.
## Every look is a block with depth (the facade set back from the box's face, the piers, the cornice and the
## lean-to standing out to it), its sides in stucco, cracks across its upper storeys and a patch where the plaster
## has come off: solid, and breakable. Nothing glows (no lit rooms, no bulbs: the shader's lit share is 0), nothing in
## a hazard colour, and no sign, no awning of stripes (stripes are a barrier's), no citizen in a window (the
## windows show goods alone), no casino (its bulbs would be a sign). Meshes are cached by size and look and shared
## by every wall.
## DESIGN-TBD (docs/questions/h7b.md): which four buildings the wall is, and its cracks as the only cue; the GDD says only
## "the same building faces".

## How far the facade plane sits back from the box's face.
const FACE_BACK: float = 0.55
## The cornice's height.
const CORNICE: float = 0.5
## A pier's width between shop windows, and the end pier.
const PIER: float = 0.55
const END_PIER: float = 0.85

## Weak: the skin owns this builder, so a strong reference back would keep both alive forever.
var skin: MarketplaceSkin:
	get:
		return _skin.get_ref() as MarketplaceSkin
var _skin: WeakRef
var _meshes: Dictionary = {}


func _init(p_skin: MarketplaceSkin) -> void:
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
			_shop_row(batch, facade, solid, size, tone, 0, false)
		1:
			_hall(facade, solid, size, tone)
		2:
			_shop_row(batch, facade, solid, size, tone, 1, false)
		_:
			_shop_row(batch, facade, solid, size, tone, 2, true)
	var mesh: ArrayMesh = DashWallKit.finish(batch)
	_meshes[key] = mesh
	return mesh


## A shop row: the plinth, shop windows with their displays between piers, shuttered storeys over them. `windows`
## picks how wide the windows are (0 narrow, 1 wide, 2 middling), `lean_to` adds the arcade's tin roof.
func _shop_row(batch: MeshBatch, facade: MeshLayer, solid: MeshLayer, size: Vector3, tone: int, windows: int,
		lean_to: bool) -> void:
	var hx: float = size.x * 0.5
	var hz: float = size.z * 0.5
	var wall_z: float = hz - FACE_BACK
	var stucco: Color = _stucco(tone + windows)
	var seed: float = float(MeshKit.hash_i(tone, windows, 91) % 997)
	var g0: float = skin.gallery_bottom
	var g1: float = skin.gallery_top
	var top: float = DashWallKit.roof_of(size) - CORNICE
	_body(solid, size, wall_z, top, stucco)
	DashWallKit.face(facade, size, -hx, hx, 0.0, g0, wall_z, stucco, MarketFacades.STYLE_LOWER, seed, hx, 0.0)
	# The shop windows: evenly spaced between piers, the displays the walls' own window templates.
	var bay: float = [3.3, 4.6, 3.9][windows]
	var usable: float = size.x - END_PIER * 2.0 + PIER
	var n: int = maxi(2, floori(usable / bay))
	var actual: float = usable / float(n)
	var shop_w: float = actual - PIER
	var variant: int = MeshKit.hash_i(tone, windows, 92) % MarketFacades.WINDOW_VARIANTS
	for k: int in n:
		var x0: float = -hx + END_PIER + float(k) * actual
		_shop_window(batch, size, x0, shop_w, variant + k, wall_z)
		# The pier to the window's right: metal-clad composite standing out of the face.
		var px: float = x0 + shop_w
		_pier(solid, size, px, px + PIER, g0, g1, wall_z, stucco)
	_pier(solid, size, -hx, -hx + END_PIER - PIER * 0.0, g0, g1, wall_z, stucco)
	_pier(solid, size, hx - END_PIER + PIER, hx, g0, g1, wall_z, stucco)
	# The storeys over them: stucco, rounded windows in aluminium frames, shutters down; cells in whole bays.
	var cell: float = MarketFacades.CELL_WIDTHS[int(seed) % 4]
	DashWallKit.bay_faces(facade, size, -hx + 0.5, hx - 0.5, cell, g1, top, wall_z, stucco, MarketFacades.STYLE_UPPER, seed,
		0.0, 2)
	# The strip at each end the bays don't reach: stucco piers up the full height.
	_end_piers(solid, size, wall_z, top, stucco)
	_cornice(solid, size, wall_z, stucco)
	DashWallKit.roof_plant(solid, size, skin.window_metal_color, skin.window_metal_color.darkened(0.3), MeshKit.PAT_TECH, 1.0, tone + windows)
	if lean_to:
		_lean_to(solid, size, wall_z, g1)
	_damage(solid, size, wall_z, tone + windows, Vector4(-hx + 1.0, hx - 1.0, g1 + 0.8, top - 0.6), stucco)


## A market hall: the plinth under large smooth panels and the glass vault over them, piers at the ends.
func _hall(facade: MeshLayer, solid: MeshLayer, size: Vector3, tone: int) -> void:
	var hx: float = size.x * 0.5
	var hz: float = size.z * 0.5
	var wall_z: float = hz - FACE_BACK
	var stucco: Color = _stucco(tone + 4)
	var seed: float = float(MeshKit.hash_i(tone, 7, 93) % 997)
	var top: float = DashWallKit.roof_of(size) - CORNICE
	_body(solid, size, wall_z, top, stucco)
	DashWallKit.face(facade, size, -hx, hx, 0.0, skin.gallery_bottom, wall_z, stucco, MarketFacades.STYLE_LOWER, seed, hx, 0.0)
	# The hall's own style from the plinth to the cornice: smooth panels through the band, the vault over them,
	# cut into whole 4.2 m bays so its arches are never cut by the building's edge.
	# The shader's grime tide starts at storey_base, so the face is lifted to start there at the plinth's top: the panels
	# (to calm_top - 0.6) and the vault over them then sit about 2 m lower than on the walls, and show whole.
	DashWallKit.bay_faces(facade, size, -hx + 0.5, hx - 0.5, 4.2, skin.gallery_bottom, top, wall_z, stucco, MarketFacades.STYLE_HALL,
		seed, skin.gallery_top + 0.2 - skin.gallery_bottom, 2)
	_end_piers(solid, size, wall_z, top, stucco)
	# A stucco band across the hall where the panels end and the vault begins.
	var vault: float = skin.decor_min_height - 1.0 - 0.6 - (skin.gallery_top + 0.2 - skin.gallery_bottom)
	DashWallKit.box(solid, size, -hx, hx, vault - 0.12, vault + 0.1, wall_z - 0.02, wall_z + 0.14, skin.trim_color, MeshKit.PAT_STUCCO,
		MeshKit.ALL_FACES, 0.0)
	_cornice(solid, size, wall_z, stucco)
	DashWallKit.roof_plant(solid, size, skin.window_metal_color, skin.window_metal_color.darkened(0.3), MeshKit.PAT_TECH, 1.0, tone + 9)
	_damage(solid, size, wall_z, tone + 5, Vector4(-hx + 1.0, hx - 1.0, 1.0, vault - 0.5), stucco)


## A shop window `width` wide with its left edge at x: the display template of the walls (a left wall's, face at
## x = 0 and z from 0 to -width) turned to face the runner.
func _shop_window(batch: MeshBatch, size: Vector3, x: float, width: float, variant: int, wall_z: float) -> void:
	var template: MeshBatch = skin.facades()._window_template(0, width, variant % MarketFacades.WINDOW_VARIANTS, -1, false)
	# (x, y, z) -> (-z, y, x): the window's face (the plane x = 0, facing +x) becomes the plane z = wall_z facing the
	# runner, its width (along -z) runs along +x, its display goes back into the building.
	var turn := Basis(Vector3.UP, -PI * 0.5)
	batch.append(template, Transform3D(turn, Vector3(x, -size.y * 0.5, wall_z)))


## A pier between shop windows (x0 to x1, from height h0 to h1): composite cladding in the stucco, aluminium jambs
## either side, standing a little out of the face.
func _pier(solid: MeshLayer, size: Vector3, x0: float, x1: float, h0: float, h1: float, wall_z: float, stucco: Color) -> void:
	if x1 - x0 < 0.1:
		return
	DashWallKit.box(solid, size, x0, x1, h0, h1, wall_z - 0.08, wall_z + 0.14, stucco.darkened(0.04), MeshKit.PAT_STUCCO,
		MeshKit.ALL_FACES, 0.0)
	DashWallKit.box(solid, size, x0, x1, h0, h0 + 0.06, wall_z + 0.1, wall_z + 0.15, skin.window_metal_color, MeshKit.PAT_PLAIN,
		MeshKit.FACE_PZ | MeshKit.FACE_PY)


## Stucco piers up the full height at both ends of the face, standing out to the box's face, a darker plinth
## at their foot.
func _end_piers(solid: MeshLayer, size: Vector3, wall_z: float, top: float, stucco: Color) -> void:
	var hx: float = size.x * 0.5
	var hz: float = size.z * 0.5
	for side: float in [-1.0, 1.0]:
		var a: float = minf(side * hx, side * (hx - 0.5))
		var b: float = maxf(side * hx, side * (hx - 0.5))
		DashWallKit.box(solid, size, a, b, 0.0, top, wall_z - 0.1, hz, stucco.lightened(0.04), MeshKit.PAT_STUCCO,
			MeshKit.ALL_FACES, 0.0)
		DashWallKit.box(solid, size, a, b, 0.0, 0.85, wall_z - 0.1, hz + 0.0, skin.plinth_color, MeshKit.PAT_PLAIN,
			MeshKit.FACE_PZ | MeshKit.FACE_PX | MeshKit.FACE_NX)


## The cornice: a stucco band standing out to the face with a pale cap, and a shadow line under it.
func _cornice(solid: MeshLayer, size: Vector3, wall_z: float, stucco: Color) -> void:
	var hx: float = size.x * 0.5
	var hz: float = size.z * 0.5
	var top: float = DashWallKit.roof_of(size)
	DashWallKit.box(solid, size, -hx, hx, top - CORNICE, top, -hz, hz, skin.trim_color, MeshKit.PAT_STUCCO,
		MeshKit.ALL_FACES & ~MeshKit.FACE_NY, 0.0)
	DashWallKit.box(solid, size, -hx + 0.03, hx - 0.03, top - CORNICE - 0.1, top - CORNICE, wall_z + 0.05, hz - 0.03,
		stucco.darkened(0.4), MeshKit.PAT_PLAIN, MeshKit.FACE_PZ | MeshKit.FACE_NY)


## An arcade's lean-to: a slab of corrugated tin on posts, standing out to the box's face over the shop windows.
func _lean_to(solid: MeshLayer, size: Vector3, wall_z: float, h: float) -> void:
	var hx: float = size.x * 0.5
	var hz: float = size.z * 0.5
	DashWallKit.box(solid, size, -hx + 0.3, hx - 0.3, h + 0.15, h + 0.35, wall_z - 0.05, hz, skin.stucco_colors[4].darkened(0.1),
		MeshKit.PAT_TIN, MeshKit.ALL_FACES & ~MeshKit.FACE_NZ, 1.0)
	var posts: int = maxi(2, roundi(size.x / 4.0))
	for k: int in posts + 1:
		var x: float = lerpf(-hx + 0.6, hx - 0.6, float(k) / float(posts))
		DashWallKit.box(solid, size, x - 0.07, x + 0.07, 0.0, h + 0.15, hz - 0.2, hz - 0.06, skin.window_metal_color.darkened(0.2),
			MeshKit.PAT_PLAIN, MeshKit.ALL_FACES & ~MeshKit.FACE_NY)


## The block's body behind its face: its sides and top only, from the floor up to `top`, z from the back to `z`.
func _body(solid: MeshLayer, size: Vector3, z: float, top: float, color: Color) -> void:
	var hx: float = size.x * 0.5
	var hz: float = size.z * 0.5
	DashWallKit.box(solid, size, -hx, hx, 0.0, top, -hz, z, color, MeshKit.PAT_STUCCO,
		MeshKit.FACE_PX | MeshKit.FACE_NX | MeshKit.FACE_PY, 0.0)


## A stucco colour for a tone: sand, cream, ochre and terracotta, never the pale blue-grey.
func _stucco(tone: int) -> Color:
	var picks: Array[int] = [0, 1, 3, 5, 2]
	return skin.stucco_colors[picks[posmod(tone, picks.size())] % skin.stucco_colors.size()]


## What says "this breaks": cracks across the upper storeys from a few points, and a patch where the plaster has come
## off down to the bare brick. `at` bounds both (x0, x1, h0, h1).
func _damage(solid: MeshLayer, size: Vector3, z: float, seed: int, at: Vector4, stucco: Color) -> void:
	DashWallKit.cracks(solid, size, z + 0.01, at, 2 + seed % 2, Color(0.2, 0.16, 0.12), seed)
	var px: float = lerpf(at.x + 0.9, at.y - 0.9, MeshKit.hash01(seed, 5, 49))
	var py: float = lerpf(at.z + 0.1, maxf(at.z + 0.2, at.w - 1.0), MeshKit.hash01(seed, 6, 49))
	DashWallKit.spall(solid, size, px - 0.6, px + 0.6, py, py + 0.8, z + 0.01, 0.1, stucco.darkened(0.3), Color(0.3, 0.28, 0.26),
		MeshKit.PAT_PLAIN, 0.0)
