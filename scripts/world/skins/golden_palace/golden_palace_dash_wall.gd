class_name GoldenPalaceDashWall
extends RefCounted
## The Golden Palace's dash wall (GoldenPalaceSkin.dash_wall; task H7b, GDD §9.14: "the same assets as the side
## walls, but facing towards the player, looking like a building in the middle of the street"): a marble pavilion
## standing across the hall, built from GoldenPalaceWalls' own kit: the colonnade's flush marble panel
## (MeshKit.PAT_PALACE_PANEL, the same marble as the floor, the gold wall-run marks inlaid in it), gilded marble
## pilasters (an octagonal shaft on a granite plinth under a gold capital), gold-framed galleries, a gold cornice.
## Four looks by the wall's seed:
## - 0 a pilastered block: bays of moulded marble panels between the gilded pilasters;
## - 1 a gallery: a row of gold-framed galleries (dark rooms) high over a plain marble base;
## - 2 an arcade of windows: gold-framed arched windows over the base;
## - 3 a hall block: a heavy base, bands of gold along the panel, a coffered frieze under the cornice.
## Every look is a block with depth (the panel set back from the box's face, the pilasters, the frames and the
## cornice standing out to it), its sides in marble, hairline cracks across its face (no fallen patch: the hall
## keeps its marble clean): solid, and breakable. The galleries stay high over the base (never an opening at the runners' height), and nothing
## in them glows or plays the cult's feed or shows its emblem (a screen is a sign), nothing is red (no tapestry:
## a banner is a sign), nothing is an alcove with a statue (a statue reads as a Gilded Sentinel). Nothing in a
## hazard colour, nothing glows. Meshes are cached by size and look and shared by every wall.
## DESIGN-TBD (docs/questions/h7b.md): which four buildings the wall is, and its cracks as the only cue; the GDD says only
## "the same building faces".

## How far the panel plane sits back from the box's face.
const FACE_BACK: float = 0.6
const CORNICE: float = 0.55
const PILASTER: float = 0.3
## The galleries' and windows' sills above the floor, and their height.
const SILL: float = 4.3
const OPENING: float = 3.0

## Weak: the skin owns this builder, so a strong reference back would keep both alive forever.
var skin: GoldenPalaceSkin:
	get:
		return _skin.get_ref() as GoldenPalaceSkin
var _skin: WeakRef
var _meshes: Dictionary = {}


func _init(p_skin: GoldenPalaceSkin) -> void:
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
	var solid: MeshLayer = batch.layer(skin.solid_material())
	match look:
		0:
			_pilastered(solid, size, tone)
		1:
			_galleries(solid, size, tone)
		2:
			_windows(solid, size, tone)
		_:
			_hall(solid, size, tone)
	var mesh: ArrayMesh = DashWallKit.finish(batch)
	_meshes[key] = mesh
	return mesh


## A pilastered block: bays of moulded marble panels between the gilded pilasters.
func _pilastered(s: MeshLayer, size: Vector3, tone: int) -> void:
	var hx: float = size.x * 0.5
	var wall_z: float = size.z * 0.5 - FACE_BACK
	var stone: Color = _stone(tone)
	_shell(s, size, wall_z, stone)
	var bays: int = maxi(2, roundi((size.x - 1.2) / 3.2))
	var xs: Array[float] = _bay_edges(size, bays)
	for b: int in bays:
		var x0: float = xs[b] + PILASTER + 0.35
		var x1: float = xs[b + 1] - PILASTER - 0.35
		# A moulded panel in each bay: a gold-bordered recess, an upper and a lower one.
		_panel(s, size, x0, x1, 0.9, 3.9, wall_z, stone)
		_panel(s, size, x0, x1, 4.4, DashWallKit.roof_of(size) - CORNICE - 0.4, wall_z, stone)
	_pilasters(s, size, xs, wall_z, stone)
	_finish(s, size, wall_z, stone, tone, Vector4(-hx + 1.0, hx - 1.0, 1.0, DashWallKit.roof_of(size) - 1.2))


## A gallery: a row of gold-framed galleries (dark rooms behind a gold frame) high over a plain marble base.
func _galleries(s: MeshLayer, size: Vector3, tone: int) -> void:
	var hx: float = size.x * 0.5
	var wall_z: float = size.z * 0.5 - FACE_BACK
	var stone: Color = _stone(tone + 1)
	_shell(s, size, wall_z, stone)
	var bays: int = maxi(2, roundi((size.x - 1.2) / 3.6))
	var xs: Array[float] = _bay_edges(size, bays)
	for b: int in bays:
		var x0: float = xs[b] + PILASTER + 0.55
		var x1: float = xs[b + 1] - PILASTER - 0.55
		_gallery(s, size, x0, x1, SILL, SILL + OPENING, wall_z, false)
	_pilasters(s, size, xs, wall_z, stone)
	# A gold string course under the galleries' sills, standing out of the panel.
	DashWallKit.box(s, size, -hx, hx, SILL - 0.5, SILL - 0.3, wall_z - 0.02, wall_z + 0.18, skin.gold_color, MeshKit.PAT_GOLD,
		MeshKit.ALL_FACES, 0.9)
	_finish(s, size, wall_z, stone, tone + 1, Vector4(-hx + 1.0, hx - 1.0, 1.0, SILL - 0.8))


## An arcade of windows: gold-framed arched windows over a marble base.
func _windows(s: MeshLayer, size: Vector3, tone: int) -> void:
	var hx: float = size.x * 0.5
	var wall_z: float = size.z * 0.5 - FACE_BACK
	var stone: Color = _stone(tone + 2)
	_shell(s, size, wall_z, stone)
	var bays: int = maxi(2, roundi((size.x - 1.2) / 3.0))
	var xs: Array[float] = _bay_edges(size, bays)
	for b: int in bays:
		var x0: float = xs[b] + PILASTER + 0.5
		var x1: float = xs[b + 1] - PILASTER - 0.5
		_gallery(s, size, x0, x1, SILL - 0.3, SILL + OPENING - 0.3, wall_z, true)
	_pilasters(s, size, xs, wall_z, stone)
	_finish(s, size, wall_z, stone, tone + 2, Vector4(-hx + 1.0, hx - 1.0, 1.0, SILL - 1.0))


## A hall block: a heavy granite base, bands of gold along the panel, a coffered frieze under the cornice, bigger
## pilasters.
func _hall(s: MeshLayer, size: Vector3, tone: int) -> void:
	var hx: float = size.x * 0.5
	var wall_z: float = size.z * 0.5 - FACE_BACK
	var stone: Color = _stone(tone + 3)
	_shell(s, size, wall_z, stone)
	var bays: int = maxi(2, roundi((size.x - 1.2) / 4.5))
	var xs: Array[float] = _bay_edges(size, bays)
	DashWallKit.box(s, size, -hx, hx, 0.0, 1.6, wall_z - 0.05, wall_z + 0.25, skin.granite_color, MeshKit.PAT_MARBLE,
		MeshKit.ALL_FACES, 1.0)
	for h: float in [1.6, 4.9, DashWallKit.roof_of(size) - CORNICE - 0.8]:
		DashWallKit.box(s, size, -hx, hx, h, h + 0.14, wall_z - 0.02, wall_z + 0.22, skin.gold_color, MeshKit.PAT_GOLD,
			MeshKit.ALL_FACES, 0.9)
	# The coffered frieze: a row of gold-bordered square coffers under the cornice.
	var coffers: int = maxi(3, roundi((size.x - 1.2) / 1.1))
	var cw: float = (size.x - 1.2) / float(coffers)
	for k: int in coffers:
		var cx: float = -hx + 0.6 + cw * (float(k) + 0.5)
		DashWallKit.frame_rect(s, size, cx - cw * 0.5 + 0.18, cx + cw * 0.5 - 0.18, DashWallKit.roof_of(size) - CORNICE - 0.7, DashWallKit.roof_of(size) - CORNICE - 0.18,
			wall_z + 0.04, 0.06, 0.06, skin.gold_color, MeshKit.PAT_GOLD, 0.9)
	_pilasters(s, size, xs, wall_z, stone)
	_finish(s, size, wall_z, stone, tone + 3, Vector4(-hx + 1.0, hx - 1.0, 1.8, 4.5))


## The block's shell: the panel across the face from the floor to the cornice (PAT_PALACE_PANEL), the body's
## sides and top in marble, the gold-trimmed granite plinth at its foot.
func _shell(s: MeshLayer, size: Vector3, wall_z: float, stone: Color) -> void:
	var hx: float = size.x * 0.5
	var hz: float = size.z * 0.5
	var top: float = DashWallKit.roof_of(size) - CORNICE
	DashWallKit.box(s, size, -hx, hx, 0.0, top, -hz, wall_z, stone, MeshKit.PAT_PALACE_PANEL,
		MeshKit.FACE_PZ | MeshKit.FACE_PX | MeshKit.FACE_NX | MeshKit.FACE_PY, 0.0)
	DashWallKit.box(s, size, -hx, hx, 0.0, 0.7, wall_z - 0.05, wall_z + 0.18, skin.granite_color, MeshKit.PAT_MARBLE,
		MeshKit.ALL_FACES, 1.0)
	DashWallKit.box(s, size, -hx, hx, 0.7, 0.8, wall_z - 0.02, wall_z + 0.2, skin.gold_color, MeshKit.PAT_GOLD,
		MeshKit.ALL_FACES, 0.9)


## The x of the pilasters across the face: `bays` equal bays between the end pilasters.
func _bay_edges(size: Vector3, bays: int) -> Array[float]:
	var hx: float = size.x * 0.5
	var out: Array[float] = []
	for k: int in bays + 1:
		out.append(lerpf(-hx + PILASTER * 1.5, hx - PILASTER * 1.5, float(k) / float(bays)))
	return out


## Gilded marble pilasters at the bay edges, from the plinth to the cornice (an octagonal shaft on a granite plinth
## under a gold capital: GoldenPalaceWalls._pilaster's), and a square pier at each end.
func _pilasters(s: MeshLayer, size: Vector3, xs: Array[float], wall_z: float, stone: Color) -> void:
	var hx: float = size.x * 0.5
	var hz: float = size.z * 0.5
	for k: int in xs.size():
		var end: bool = k == 0 or k == xs.size() - 1
		DashWallKit.column(s, size, xs[k], wall_z + PILASTER * 0.5, 0.8, DashWallKit.roof_of(size) - CORNICE - 0.05, PILASTER * (1.15 if end else 1.0),
			skin.granite_color, stone.lightened(0.04), skin.gold_color, MeshKit.PAT_MARBLE, MeshKit.PAT_MARBLE, MeshKit.PAT_GOLD, 0.9)
	for side: float in [-1.0, 1.0]:
		DashWallKit.box(s, size, minf(side * hx, side * (hx - PILASTER)), maxf(side * hx, side * (hx - PILASTER)), 0.0,
			DashWallKit.roof_of(size) - CORNICE, wall_z - 0.1, hz, stone.lightened(0.02), MeshKit.PAT_MARBLE,
			MeshKit.ALL_FACES, 1.0)


## A moulded panel: a recess of the marble a shade darker, a gold border standing out of the panel.
func _panel(s: MeshLayer, size: Vector3, x0: float, x1: float, h0: float, h1: float, wall_z: float, stone: Color) -> void:
	if x1 - x0 < 0.6 or h1 - h0 < 0.6:
		return
	DashWallKit.box(s, size, x0, x1, h0, h1, wall_z - 0.1, wall_z + 0.02, stone.darkened(0.06), MeshKit.PAT_MARBLE, MeshKit.FACE_PZ, 1.0)
	DashWallKit.frame_rect(s, size, x0, x1, h0, h1, wall_z + 0.1, 0.08, 0.12, skin.gold_color, MeshKit.PAT_GOLD, 0.9)


## A gallery (a gold-framed opening onto a dark hall, its sides in shadow) or, `arched`, a window with a round
## head: the frame stands out of the panel, the dark behind it is unlit.
func _gallery(s: MeshLayer, size: Vector3, x0: float, x1: float, h0: float, h1: float, wall_z: float, arched: bool) -> void:
	var dark := Color(0.13, 0.1, 0.085)
	var far := Color(0.24, 0.19, 0.145)
	var rect_top: float = h1 - (x1 - x0) * 0.5 if arched else h1
	# The hall behind: a warm dark, the far floor a shade lighter at the foot of the opening, so it reads as a room
	# and never as a screen.
	DashWallKit.box(s, size, x0, x1, h0, rect_top, wall_z - 0.3, wall_z + 0.02, dark, MeshKit.PAT_PLAIN, MeshKit.FACE_PZ)
	DashWallKit.box(s, size, x0, x1, h0, h0 + (rect_top - h0) * 0.28, wall_z - 0.3, wall_z + 0.025, far, MeshKit.PAT_PLAIN, MeshKit.FACE_PZ)
	if arched:
		var r: float = (x1 - x0) * 0.5
		var cx: float = (x0 + x1) * 0.5
		DashWallKit.arch_head(s, size, cx, rect_top, r, 0.0, wall_z + 0.02, dark)
		# The frame: two jambs, the sill and a round head of gold.
		for jamb: Vector2 in [Vector2(x0 - 0.1, x0), Vector2(x1, x1 + 0.1)]:
			DashWallKit.box(s, size, jamb.x, jamb.y, h0, rect_top, wall_z - 0.1, wall_z + 0.14, skin.gold_color, MeshKit.PAT_GOLD,
				MeshKit.ALL_FACES, 0.9)
		DashWallKit.box(s, size, x0 - 0.1, x1 + 0.1, h0 - 0.12, h0, wall_z - 0.1, wall_z + 0.2, skin.gold_color, MeshKit.PAT_GOLD,
			MeshKit.ALL_FACES, 0.9)
		DashWallKit.arch_head(s, size, cx, rect_top, r, 0.1, wall_z + 0.14, skin.gold_color, MeshKit.PAT_GOLD, 0.9)
		return
	DashWallKit.frame_rect(s, size, x0, x1, h0, h1, wall_z + 0.14, 0.14, 0.16, skin.gold_color, MeshKit.PAT_GOLD, 0.95)


## The cornice (gold line, marble, a dark shadow line under it), the urn finials, and what says "this breaks": hairline
## cracks.
func _finish(s: MeshLayer, size: Vector3, wall_z: float, stone: Color, seed: int, at: Vector4) -> void:
	var hx: float = size.x * 0.5
	var hz: float = size.z * 0.5
	var top: float = DashWallKit.roof_of(size)
	DashWallKit.box(s, size, -hx, hx, top - CORNICE, top, -hz, hz, stone.lightened(0.04), MeshKit.PAT_MARBLE,
		MeshKit.ALL_FACES & ~MeshKit.FACE_NY, 0.0)
	DashWallKit.box(s, size, -hx + 0.03, hx - 0.03, top - CORNICE - 0.14, top - CORNICE, wall_z + 0.05, hz - 0.03, stone.darkened(0.25),
		MeshKit.PAT_MARBLE, MeshKit.FACE_PZ | MeshKit.FACE_NY, 0.0)
	DashWallKit.box(s, size, -hx + 0.02, hx - 0.02, top - CORNICE + 0.1, top - CORNICE + 0.24, hz - 0.01, hz, skin.gold_color,
		MeshKit.PAT_GOLD, MeshKit.FACE_PZ, 0.9)
	DashWallKit.finials(s, size, stone.lightened(0.04), skin.gold_color, MeshKit.PAT_MARBLE, MeshKit.PAT_GOLD)
	DashWallKit.cracks(s, size, wall_z + 0.03, at, 3, skin.vein_color.darkened(0.55), seed, 0.75)


## A marble tone: the palace's white and cream marbles (the floor's), a shade warmer than the walls.
func _stone(tone: int) -> Color:
	var picks: Array[int] = [3, 1, 2]
	return skin.stone_colors[picks[tone % picks.size()] % skin.stone_colors.size()].lerp(skin.gold_color, 0.3).darkened(0.12)
