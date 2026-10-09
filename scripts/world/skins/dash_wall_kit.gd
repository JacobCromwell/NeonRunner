class_name DashWallKit
extends RefCounted
## Shared pieces of the zones' dash wall looks (task H7b; GDD §9.14, owner, October 8, 2026: "visually they
## should use the same assets as the side walls, but they should be facing towards the player, looking like a
## building in the middle of the street"). Every zone builds its wall from its own side-wall kit (the facade
## shader and the solid material its walls draw with, its colours and its motifs: CorporateDashWall,
## DeadDashWall, ...); what they share is here: the box a look fills and how its pieces are laid in it, the
## cracks that say "this breaks", and putting a cached mesh on the wall's node.
##
## A look is built in the wall's own space (ZoneSkin.dash_wall): x across the track, y up with the floor at
## -size.y / 2, z along it with the face toward the oncoming runner at +size.z / 2. The helpers here take
## heights above the floor (`h`), so a look reads in metres from the ground like the side walls' own kit does,
## and a facade's UV.y (world height) is the same height.
##
## Every wall's look is one mesh from cached templates (a few surfaces: its facade shader and the solid kit),
## built once per size and look; the look's own surfaces carry their materials, never glow (COLOR.a is 0 on
## every vertex: no lit windows, no embers) and stay inside the box (test_dash_walls' _test_skins).

## The cracks' crawl: how thick a crack is at its start, how it thins, and how far it stands out of the face
## it lies on (metres).
const CRACK_WIDTH: float = 0.07
const CRACK_THIN: float = 0.82
const CRACK_OUT: float = 0.04


## The wall's node dressed with a cached look (ZoneSkin.dash_wall): one shadowless mesh instance, its surfaces
## drawing with the materials the builder gave its layers.
static func dress(body: Node3D, mesh: Mesh) -> void:
	var inst := MeshInstance3D.new()
	inst.name = "Look"
	inst.mesh = mesh
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(inst)


## The look's mesh from `batch`, tagged with its main lit colours (ZoneSkin.dash_wall_debris_colors).
static func finish(batch: MeshBatch) -> ArrayMesh:
	return ZoneSkin.tag_debris_colors(batch.to_mesh(), batch)


## Which of the zone's layouts a wall's seed picks (0 to ZoneSkin.DASH_WALL_LOOKS - 1).
static func look_of(look_seed: int) -> int:
	return posmod(look_seed, ZoneSkin.DASH_WALL_LOOKS)


## Which of three tones of the zone's palette a wall's seed picks (the same layout in another stone, another
## paint).
static func tone_of(look_seed: int) -> int:
	return posmod(floori(float(look_seed) / float(ZoneSkin.DASH_WALL_LOOKS)), 3)


## A box between heights `h0` and `h1` above the floor, x from `x0` to `x1` and z from `z0` to `z1`.
static func box(layer: MeshLayer, size: Vector3, x0: float, x1: float, h0: float, h1: float, z0: float, z1: float,
		color: Color, pattern: int = MeshKit.PAT_PLAIN, faces: int = MeshKit.ALL_FACES, param: float = 0.0) -> void:
	var y0: float = h0 - size.y * 0.5
	var y1: float = h1 - size.y * 0.5
	layer.box_between(Vector3(x0, y0, z0), Vector3(x1, y1, z1), color, 0.0, pattern, faces, param)


## A facade shader's piece facing the runner at depth `z`, x from `x0` to `x1`, from height `h0` to `h1`: UV
## runs in metres (x + uv_x, height + uv_h), so the zone's window grids and panel joints line up between pieces
## (the same convention as MeshKit.facade_quad's along-the-wall UV). `lit` is the share of lit windows (0: none
## of the wall glows) and `style` and `seed` what the shader reads of UV2.
static func face(layer: MeshLayer, size: Vector3, x0: float, x1: float, h0: float, h1: float, z: float,
		color: Color, style: int, seed: float, uv_x: float = 0.0, uv_h: float = 0.0, lit: float = 0.0) -> void:
	if x1 <= x0 + 0.0005 or h1 <= h0 + 0.0005:
		return
	var y0: float = h0 - size.y * 0.5
	var y1: float = h1 - size.y * 0.5
	layer.quad_uv(Vector3(x0, y0, z), Vector3(x0, y1, z), Vector3(x1, y1, z), Vector3(x1, y0, z),
		Vector2(x0 + uv_x, h0 + uv_h), Vector2(x0 + uv_x, h1 + uv_h), Vector2(x1 + uv_x, h1 + uv_h),
		Vector2(x1 + uv_x, h0 + uv_h), color, lit, style, seed)


## A facade shader's piece on one of the building's sides (x = +/- half the width), seen from the street at an
## angle on the approach: from depth `z0` (back) to `z1` (front), height `h0` to `h1`, facing out along x
## (`side` -1 faces -x, +1 faces +x). UV runs (distance from the front, height + uv_h).
static func side_face(layer: MeshLayer, size: Vector3, side: int, z0: float, z1: float, h0: float, h1: float,
		color: Color, style: int, seed: float, uv_h: float = 0.0, lit: float = 0.0) -> void:
	var x: float = float(side) * size.x * 0.5
	var y0: float = h0 - size.y * 0.5
	var y1: float = h1 - size.y * 0.5
	# Clockwise seen from outside: for +x, looking back toward -x, +z is on the left.
	if side > 0:
		layer.quad_uv(Vector3(x, y0, z1), Vector3(x, y1, z1), Vector3(x, y1, z0), Vector3(x, y0, z0),
			Vector2(0.0, h0 + uv_h), Vector2(0.0, h1 + uv_h), Vector2(z1 - z0, h1 + uv_h), Vector2(z1 - z0, h0 + uv_h),
			color, lit, style, seed)
	else:
		layer.quad_uv(Vector3(x, y0, z0), Vector3(x, y1, z0), Vector3(x, y1, z1), Vector3(x, y0, z1),
			Vector2(z1 - z0, h0 + uv_h), Vector2(z1 - z0, h1 + uv_h), Vector2(0.0, h1 + uv_h), Vector2(0.0, h0 + uv_h),
			color, lit, style, seed)


## A mesh of cracks (dark, unlit, standing CRACK_OUT proud of a face at depth `z`) spreading from `hits` points
## within the x and height bounds `at` (x0, x1, h0, h1): a breakable face. The cracks' own random numbers come
## from `seed`, so a look's cracks never change.
static func cracks(layer: MeshLayer, size: Vector3, z: float, at: Vector4, hits: int, color: Color, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["dash_wall_cracks", seed])
	for k: int in hits:
		var from := Vector2(lerpf(at.x, at.y, (float(k) + rng.randf_range(0.2, 0.8)) / float(hits)),
			rng.randf_range(at.z, at.w))
		var arms: int = rng.randi_range(4, 6)
		for a: int in arms:
			var angle: float = TAU * (float(a) + rng.randf_range(-0.3, 0.3)) / float(arms)
			_crack(layer, size, from, angle, rng.randi_range(3, 5), rng, at, z, color)


## One crack: a zigzag of thin segments from `from` (x, height on the face) heading at `angle`, kept inside
## the bounds `at`, a little thinner each segment.
static func _crack(layer: MeshLayer, size: Vector3, from: Vector2, angle: float, segments: int,
		rng: RandomNumberGenerator, at: Vector4, z: float, color: Color) -> void:
	var p: Vector2 = from
	var heading: float = angle
	var width: float = CRACK_WIDTH
	for i: int in segments:
		heading += rng.randf_range(-0.6, 0.6)
		var length: float = rng.randf_range(0.45, 1.0) * (1.0 - 0.12 * float(i))
		var q: Vector2 = p + Vector2(cos(heading), sin(heading)) * length
		q = Vector2(clampf(q.x, at.x, at.y), clampf(q.y, at.z, at.w))
		var d: Vector2 = q - p
		if d.length() < 0.05:
			break
		var mid: Vector2 = (p + q) * 0.5
		var xform := Transform3D(Basis(Vector3.BACK, d.angle()) * Basis.from_scale(Vector3(d.length() + width, width, CRACK_OUT)),
			Vector3(mid.x, mid.y - size.y * 0.5, z + CRACK_OUT * 0.5 - 0.002))
		layer.box_xform(xform, color, 0.0, MeshKit.PAT_PLAIN, MeshKit.FACE_PZ | MeshKit.FACE_PY | MeshKit.FACE_NY)
		p = q
		width *= CRACK_THIN


## A patch where the cladding has fallen away: a dark recess `depth` deep into the wall at depth `z`, x0 to x1
## and height h0 to h1, with its rim of broken edge, for a wall that has been standing too long. `bare` is the
## colour of what shows behind (concrete, brick, a dark void).
static func spall(layer: MeshLayer, size: Vector3, x0: float, x1: float, h0: float, h1: float, z: float, depth: float,
		bare: Color, edge: Color, pattern: int = MeshKit.PAT_PLAIN, param: float = 0.0) -> void:
	box(layer, size, x0, x1, h0, h1, z - depth, z + 0.03, bare, pattern, MeshKit.FACE_PZ, param)
	var rim: float = 0.1
	box(layer, size, x0 - rim, x1 + rim, h1, h1 + rim, z - depth, z + 0.05, edge, MeshKit.PAT_PLAIN, MeshKit.FACE_PZ | MeshKit.FACE_PY)
	box(layer, size, x0 - rim, x1 + rim, h0 - rim, h0, z - depth, z + 0.05, edge, MeshKit.PAT_PLAIN, MeshKit.FACE_PZ)
	box(layer, size, x0 - rim, x0, h0, h1, z - depth, z + 0.05, edge, MeshKit.PAT_PLAIN, MeshKit.FACE_PZ | MeshKit.FACE_NX)
	box(layer, size, x1, x1 + rim, h0, h1, z - depth, z + 0.05, edge, MeshKit.PAT_PLAIN, MeshKit.FACE_PZ | MeshKit.FACE_PX)


## The facade shaders' hash11 (kit_common.gdshaderinc), so a look can know what a shader will draw for a seed
## (which wall of cladding gets a lobby, say) and pick one that suits it. Doubles, not floats: a seed is
## trusted only where its hash is well clear of the threshold (see seed_where).
static func hash11(p: float) -> float:
	var q: float = fposmod(p * 0.1031, 1.0)
	q *= q + 33.33
	q *= q + q
	return fposmod(q, 1.0)


## The first whole-number seed from `from` on whose hash11(seed * scale + shift) is below (`below`) or above
## `threshold`, clear of it by `margin`: a seed that makes a shader's `hash11(seed * scale + shift) < threshold`
## test come out the way the look wants.
static func seed_where(from: int, scale: float, shift: float, threshold: float, below: bool, margin: float = 0.04) -> float:
	for k: int in 400:
		var s: float = float(from + k)
		var h: float = hash11(s * scale + shift)
		if (below and h < threshold - margin) or (not below and h > threshold + margin):
			return s
	return float(from)
