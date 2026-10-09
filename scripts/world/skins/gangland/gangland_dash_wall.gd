class_name GanglandDashWall
extends RefCounted
## Gangland's dash wall (GanglandSkin.dash_wall; task H7b, GDD §9.14: "the same assets as the side walls, but
## facing towards the player, looking like a building in the middle of the street"): a bombed-out building
## standing across the street, built from GanglandRuins' own kit: the ruin faces of facade.gdshader's ruin mode
## (shuttered storefronts and boarded windows tagged with graffiti at the foot, gutted windows above, the shader's
## own grime and soot), sandstone cladding and bare concrete slabs, rusty sheet metal and scrap steel, a top blown
## out in bites. Four looks by the wall's seed:
## - 0 a ruined block: the face to a broken top, rebar bent out of the breaks;
## - 1 a balcony block: the same face with a makeshift balcony of scrap sheet and posts standing out of it;
## - 2 a patched shop: rusty sheets of corrugated metal nailed over the shopfront;
## - 3 a collapsed corner: a big bite out of the top with the floor slabs left sticking out of it.
## Every look is a block with depth (the facade set back from the box's face, the balcony, the sheets and the slabs
## standing out to it), its sides in sandstone, cracks across its face and a patch where the render has come away:
## solid, and breakable. Nothing glows (no lamps, no fires, no TV: the shader's lit share is 0), nothing in a hazard
## colour, no laundry or ad (a sign), no crate wall (a barricade is a hazard's). Meshes are cached by size and look and
## shared by every wall.

## How far the facade plane sits back from the box's face.
const FACE_BACK: float = 0.5
## The broken top never goes lower than this.
const TOP_MIN: float = 6.2
## The facade styles the ruins use (facade.gdshader: 1 punched, 3 tall slots, 2 ribbon) and their storey heights.
const STYLES: Array[int] = [1, 3, 1, 2]
const STOREYS: Array[float] = [3.3, 3.0, 3.3, 3.3]

## Weak: the skin owns this builder, so a strong reference back would keep both alive forever.
var skin: GanglandSkin:
	get:
		return _skin.get_ref() as GanglandSkin
var _skin: WeakRef
var _meshes: Dictionary = {}


func _init(p_skin: GanglandSkin) -> void:
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
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["gangland_dash_wall", look, tone])
	match look:
		0:
			_block(facade, solid, size, tone, rng, 2, false)
		1:
			_block(facade, solid, size, tone, rng, 2, true)
		2:
			_patched(facade, solid, size, tone, rng)
		_:
			_collapsed(facade, solid, size, tone, rng)
	var mesh: ArrayMesh = DashWallKit.finish(batch)
	_meshes[key] = mesh
	return mesh


## A ruined block: the ruin face up to a broken top, bare slab edges and rebar at the breaks; with `balcony` a
## makeshift balcony on the first floor.
func _block(facade: MeshLayer, solid: MeshLayer, size: Vector3, tone: int, rng: RandomNumberGenerator, bites: int,
		balcony: bool) -> void:
	var hx: float = size.x * 0.5
	var wall_z: float = size.z * 0.5 - FACE_BACK
	var style: int = STYLES[(tone + (1 if balcony else 0)) % STYLES.size()]
	var seed: float = float(MeshKit.hash_i(tone, 1, 101) % 997)
	var wall: Color = _wall(tone)
	var tops: PackedFloat32Array = DashWallKit.broken_profile(size, rng, bites, TOP_MIN)
	_body(solid, size, wall_z, TOP_MIN - 0.3, wall)
	DashWallKit.face_profile(facade, size, tops, 0.0, wall_z, wall, style, seed, size.x * 0.5, 0.0)
	_slabs(solid, size, wall_z, tops, wall, style)
	_posts(solid, size, wall_z)
	if balcony:
		_balcony(solid, size, wall_z, rng, STOREYS[style])
	_damage(solid, size, wall_z, tone, Vector4(-hx + 1.0, hx - 1.0, 3.6, TOP_MIN - 0.5), wall)


## A patched shop: the ruin face over a stretch of rusty corrugated sheets nailed across the shopfront, each its own
## height and tone, the way the barricades are mended.
func _patched(facade: MeshLayer, solid: MeshLayer, size: Vector3, tone: int, rng: RandomNumberGenerator) -> void:
	var hx: float = size.x * 0.5
	var wall_z: float = size.z * 0.5 - FACE_BACK
	var style: int = STYLES[(tone + 2) % STYLES.size()]
	var seed: float = float(MeshKit.hash_i(tone, 2, 102) % 997)
	var wall: Color = _wall(tone + 1)
	var tops: PackedFloat32Array = DashWallKit.broken_profile(size, rng, 1, TOP_MIN + 0.8)
	_body(solid, size, wall_z, TOP_MIN - 0.3, wall)
	DashWallKit.face_profile(facade, size, tops, 0.0, wall_z, wall, style, seed, size.x * 0.5, 0.0)
	_slabs(solid, size, wall_z, tops, wall, style)
	# The sheets: 1.6 m wide, from the floor to a ragged top at about the first storey, overlapping a little and
	# standing out of the face on their battens.
	var sheet: float = 1.6
	var n: int = maxi(3, roundi((size.x - 1.0) / sheet))
	var w: float = (size.x - 1.0) / float(n)
	for k: int in n:
		var x0: float = -hx + 0.5 + w * float(k)
		var h: float = 2.8 + 1.7 * rng.randf()
		var tone_k: float = rng.randf_range(0.8, 1.15)
		var z: float = wall_z + 0.1 + 0.06 * float(k % 2)
		DashWallKit.box(solid, size, x0, x0 + w + 0.04, 0.0, h, z - 0.1, z, skin.barricade_color * Color(tone_k, tone_k, tone_k),
			MeshKit.PAT_RUST, MeshKit.ALL_FACES, 0.22)
	_posts(solid, size, wall_z)
	_damage(solid, size, wall_z, tone + 3, Vector4(-hx + 1.0, hx - 1.0, 4.0, TOP_MIN - 0.4), wall)


## A collapsed corner: a big bite out of the top toward one end, the floor slabs left sticking out of it with rebar
## at their ends.
func _collapsed(facade: MeshLayer, solid: MeshLayer, size: Vector3, tone: int, rng: RandomNumberGenerator) -> void:
	var hx: float = size.x * 0.5
	var wall_z: float = size.z * 0.5 - FACE_BACK
	var style: int = STYLES[(tone + 3) % STYLES.size()]
	var seed: float = float(MeshKit.hash_i(tone, 3, 103) % 997)
	var wall: Color = _wall(tone + 2)
	var tops: PackedFloat32Array = DashWallKit.broken_profile(size, rng, 1, TOP_MIN - 0.6)
	# The big bite: from about a third of the way along, down toward the floor storey.
	var n: int = tops.size() - 1
	var centre: int = roundi(float(n) * (0.3 if tone % 2 == 0 else 0.7))
	for i: int in n + 1:
		var d: float = absf(float(i - centre)) / 2.6
		if d < 1.0 and i > 0 and i < n:
			tops[i] = minf(tops[i], lerpf(TOP_MIN - 1.6, tops[i], d * d))
	_body(solid, size, wall_z, TOP_MIN - 1.8, wall)
	DashWallKit.face_profile(facade, size, tops, 0.0, wall_z, wall, style, seed, size.x * 0.5, 0.0)
	_slabs(solid, size, wall_z, tops, wall, style)
	_posts(solid, size, wall_z)
	# Floor slabs standing out of the bite's edges, and the rubble at the foot of it.
	var bite_x: float = -hx + size.x * float(centre) / float(n)
	for dir: float in [-1.0, 1.0]:
		var x: float = clampf(bite_x + dir * 1.9, -hx + 0.5, hx - 0.5)
		var x_out: float = clampf(x + dir * 1.2, -hx + 0.5, hx - 0.5)
		for h: float in [4.6, 7.6]:
			if h < tops[clampi(centre + int(dir * 2.0), 0, n)] + 0.3 and absf(x_out - x) > 0.2:
				DashWallKit.box(solid, size, minf(x, x_out), maxf(x, x_out), h, h + 0.28, wall_z - 0.5, wall_z + 0.25,
					skin.ceiling_slab_color, MeshKit.PAT_CONCRETE, MeshKit.ALL_FACES, 0.0)
	for i: int in 16:
		var cx: float = bite_x + rng.randf_range(-2.4, 2.4)
		var dim := Vector3(rng.randf_range(0.4, 1.1), rng.randf_range(0.3, 0.7), rng.randf_range(0.4, 0.9))
		var ch: float = rng.randf_range(0.0, 1.0) * (1.0 - absf(cx - bite_x) / 2.6) * 1.1
		DashWallKit.box(solid, size, clampf(cx - dim.x * 0.5, -hx + 0.6, hx - 0.6 - dim.x), clampf(cx + dim.x * 0.5, -hx + 0.6 + dim.x,
			hx - 0.6), ch, ch + dim.y, wall_z + 0.0, minf(wall_z + dim.z, size.z * 0.5), wall.darkened(rng.randf_range(0.0, 0.3)),
			MeshKit.PAT_CONCRETE, MeshKit.ALL_FACES & ~MeshKit.FACE_NY, 0.0)
	_damage(solid, size, wall_z, tone + 5, Vector4(-hx + 1.0, hx - 1.0, 3.6, TOP_MIN - 1.2), wall)


## Floor slabs sticking out of the broken top: a slab edge a little proud of the face where a storey's floor
## reaches the top, and rebar bent out of the break.
func _slabs(solid: MeshLayer, size: Vector3, z: float, tops: PackedFloat32Array, wall: Color, style: int) -> void:
	var hx: float = size.x * 0.5
	var n: int = tops.size() - 1
	var step: float = size.x / float(n)
	var storey: float = STOREYS[style]
	for k: int in [1, 2]:
		var h: float = storey * float(k)
		for i: int in n:
			if tops[i] > h + 0.4 and tops[i + 1] > h + 0.4:
				continue
			if tops[i] < h - 0.1 or tops[i + 1] < h - 0.1:
				continue
			# A strip of the storey's floor slab where the top has just dropped below the next floor.
			var x0: float = -hx + step * float(i)
			DashWallKit.box(solid, size, x0, x0 + step, h - 0.15, h + 0.12, z - 0.1, z + 0.12, wall.lightened(0.12), MeshKit.PAT_CONCRETE,
				MeshKit.ALL_FACES, 0.0)
	for i: int in range(1, n, 3):
		# Rebar bent out of the break, kept short enough to stay inside the box's top.
		var length: float = clampf(size.y - tops[i] - 0.45, 0.0, 0.9)
		if length > 0.25:
			var bend := Basis.from_euler(Vector3(0.3, 0.0, 0.5)).scaled_local(Vector3(0.05, length, 0.05))
			solid.box_xform(Transform3D(bend, Vector3(-hx + step * float(i), tops[i] - size.y * 0.5 + length * 0.5, z - 0.05)),
				skin.rust_color, 0.0, MeshKit.PAT_RUST, MeshKit.ALL_FACES, 0.22)


## A makeshift balcony on the first floor: a slab of scrap sheet on scrap steel brackets, a rail of posts and a bar,
## standing out to the box's face.
func _balcony(solid: MeshLayer, size: Vector3, z: float, rng: RandomNumberGenerator, storey: float) -> void:
	var hx: float = size.x * 0.5
	var hz: float = size.z * 0.5
	var w: float = rng.randf_range(2.4, 3.6)
	var x0: float = rng.randf_range(-hx + 1.5, hx - 1.5 - w)
	var h: float = storey + 0.1
	DashWallKit.box(solid, size, x0, x0 + w, h, h + 0.12, z - 0.1, hz, skin.scrap_metal_color.lightened(0.15), MeshKit.PAT_RUST,
		MeshKit.ALL_FACES, 0.22)
	for k: int in 4:
		var x: float = lerpf(x0 + 0.1, x0 + w - 0.1, float(k) / 3.0)
		DashWallKit.box(solid, size, x - 0.03, x + 0.03, h + 0.12, h + 1.0, hz - 0.12, hz - 0.06, skin.scrap_metal_color, MeshKit.PAT_PLAIN)
	DashWallKit.box(solid, size, x0, x0 + w, h + 1.0, h + 1.06, hz - 0.14, hz - 0.04, skin.scrap_metal_color, MeshKit.PAT_PLAIN)


## Scrap steel posts at both ends of the face, from the floor to the box's top, reaching the box's face: the
## frame's last columns standing against the broken wall.
func _posts(solid: MeshLayer, size: Vector3, z: float) -> void:
	var hx: float = size.x * 0.5
	var hz: float = size.z * 0.5
	for side: float in [-1.0, 1.0]:
		DashWallKit.box(solid, size, minf(side * hx, side * (hx - 0.45)), maxf(side * hx, side * (hx - 0.45)), 0.0, size.y, z - 0.25, hz,
			skin.scrap_metal_color.lightened(0.2), MeshKit.PAT_RUST, MeshKit.ALL_FACES & ~MeshKit.FACE_NY, 0.22)


## The block's body behind its face: its sides and top, from the floor up to `top`, z from the back to `z`.
func _body(solid: MeshLayer, size: Vector3, z: float, top: float, color: Color) -> void:
	var hx: float = size.x * 0.5
	var hz: float = size.z * 0.5
	DashWallKit.box(solid, size, -hx, hx, 0.0, top, -hz, z, color, MeshKit.PAT_CONCRETE,
		MeshKit.FACE_PX | MeshKit.FACE_NX | MeshKit.FACE_PY, 0.0)


## A sandstone for a tone: the zone's own sandy and umber walls, a little lighter so the block reads out of the
## street's brown.
func _wall(tone: int) -> Color:
	return skin.facade_colors[tone % skin.facade_colors.size()].lightened(0.06)


## What says "this breaks": cracks spreading across the face from a few points, and a patch where the render has come
## away down to the bare breeze block. `at` bounds both (x0, x1, h0, h1).
func _damage(solid: MeshLayer, size: Vector3, z: float, seed: int, at: Vector4, wall: Color) -> void:
	DashWallKit.cracks(solid, size, z + 0.01, at, 2 + seed % 2, skin.soot_color, seed, 0.8)
	var px: float = lerpf(at.x + 0.9, at.y - 0.9, MeshKit.hash01(seed, 5, 59))
	var py: float = lerpf(at.z + 0.1, maxf(at.z + 0.2, at.w - 1.0), MeshKit.hash01(seed, 6, 59))
	DashWallKit.spall(solid, size, px - 0.6, px + 0.6, py, py + 0.8, z + 0.01, 0.1, wall.darkened(0.45), wall.darkened(0.2),
		MeshKit.PAT_CONCRETE, 0.0)
