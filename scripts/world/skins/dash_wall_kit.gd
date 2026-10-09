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


## A facade shader's piece facing the runner over x0 to x1 that lays out a grid of cells `period` metres wide
## (windows, bays, arches), cut into whole bays: the span is divided into the nearest whole number of equal bays
## and each bay is a quad of its own whose UV puts a cell's middle at the bay's middle, so a window or an arch
## is never cut by the building's edge. `lit` is 0 on every wall (nothing glows).
static func bay_faces(layer: MeshLayer, size: Vector3, x0: float, x1: float, period: float, h0: float, h1: float, z: float,
		color: Color, style: int, seed: float, uv_h: float = 0.0, min_bays: int = 1) -> int:
	var bays: int = maxi(min_bays, roundi((x1 - x0) / period))
	var w: float = (x1 - x0) / float(bays)
	for b: int in bays:
		var bx0: float = x0 + w * float(b)
		# UV.x = x + uv_x puts the bay's left edge at (period - w) / 2 into a cell, so the cell's middle is the bay's.
		face(layer, size, bx0, bx0 + w, h0, h1, z, color, style, seed, (period - w) * 0.5 - bx0, uv_h)
	return bays


## A facade shader's piece facing the runner whose top edge follows a broken profile: `tops` holds the height of the
## top at each of its points, evenly spread across the whole width (n + 1 points make n strips), the strips drawn
## from height `h0` up between them over the span x0 to x1 of the face (the profile is sampled over the same span).
## UV as for face(): (x + uv_x, height + uv_h).
static func face_profile(layer: MeshLayer, size: Vector3, tops: PackedFloat32Array, h0: float, z: float, color: Color,
		style: int, seed: float, uv_x: float = 0.0, uv_h: float = 0.0) -> void:
	var n: int = tops.size() - 1
	if n < 1:
		return
	var hx: float = size.x * 0.5
	var step: float = size.x / float(n)
	var y0: float = h0 - size.y * 0.5
	for i: int in n:
		var x0: float = -hx + step * float(i)
		var x1: float = x0 + step
		var t0: float = maxf(tops[i], h0 + 0.01)
		var t1: float = maxf(tops[i + 1], h0 + 0.01)
		layer.quad_uv(Vector3(x0, y0, z), Vector3(x0, t0 - size.y * 0.5, z), Vector3(x1, t1 - size.y * 0.5, z), Vector3(x1, y0, z),
			Vector2(x0 + uv_x, h0 + uv_h), Vector2(x0 + uv_x, t0 + uv_h), Vector2(x1 + uv_x, t1 + uv_h),
			Vector2(x1 + uv_x, h0 + uv_h), color, 0.0, style, seed)


## A broken top's profile for the Dead Zone's and Gangland's ruins: heights across the width, one per `step` metres
## (n + 1 points), the corners standing to the box's top, `bites` bites blown out of it between them (centre,
## half-width and depth from `rng`), and no point lower than `floor_h` above the floor.
static func broken_profile(size: Vector3, rng: RandomNumberGenerator, bites: int, floor_h: float, step: float = 1.0) -> PackedFloat32Array:
	var n: int = maxi(4, roundi(size.x / step))
	var out := PackedFloat32Array()
	var holes: Array[Vector3] = []
	for b: int in bites:
		holes.append(Vector3(rng.randf_range(0.18, 0.82) * size.x, rng.randf_range(1.2, 2.6), rng.randf_range(0.8, 2.2)))
	for i: int in n + 1:
		var x: float = size.x * float(i) / float(n)
		var h: float = size.y - 0.5 * rng.randf()
		for hole: Vector3 in holes:
			h -= hole.z * maxf(0.0, 1.0 - absf(x - hole.x) / hole.y)
		out.append(size.y if i == 0 or i == n else clampf(h, floor_h, size.y))
	return out


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


## An octagonal half column standing out of the facade plane `z` (its axis at x, z), from height `h0` to `h1`:
## a base of `base` colour, the shaft of `shaft`, a capital of `cap` (the zone's gold, its pattern and param).
static func column(layer: MeshLayer, size: Vector3, x: float, z: float, h0: float, h1: float, radius: float, base: Color,
		shaft: Color, cap: Color, base_pattern: int, shaft_pattern: int, cap_pattern: int, cap_param: float = 0.0) -> void:
	var y0: float = h0 - size.y * 0.5
	var foot: float = minf(0.3, (h1 - h0) * 0.2)
	var head: float = minf(0.28, (h1 - h0) * 0.2)
	layer.prism(Vector3(x, y0, z), radius * 1.3, foot, 8, base, 0.0, base_pattern, true, 1.0)
	layer.prism(Vector3(x, y0 + foot, z), radius, h1 - h0 - foot - head, 8, shaft, 0.0, shaft_pattern, false, 0.0)
	layer.prism(Vector3(x, y0 + h1 - h0 - head, z), radius * 1.3, head, 8, cap, 0.0, cap_pattern, true, cap_param)


## A rectangular frame of bars `bar` wide and `depth` deep around the opening x0 to x1, h0 to h1, its front at
## depth `z` (the bars stand out of the plane, and cover the opening's edge).
static func frame_rect(layer: MeshLayer, size: Vector3, x0: float, x1: float, h0: float, h1: float, z: float, bar: float,
		depth: float, color: Color, pattern: int = MeshKit.PAT_PLAIN, param: float = 0.0) -> void:
	box(layer, size, x0 - bar, x1 + bar, h1, h1 + bar, z - depth, z, color, pattern, MeshKit.ALL_FACES, param)
	box(layer, size, x0 - bar, x1 + bar, h0 - bar, h0, z - depth, z, color, pattern, MeshKit.ALL_FACES, param)
	box(layer, size, x0 - bar, x0, h0, h1, z - depth, z, color, pattern, MeshKit.ALL_FACES, param)
	box(layer, size, x1, x1 + bar, h0, h1, z - depth, z, color, pattern, MeshKit.ALL_FACES, param)


## A round head over an opening, flat on the plane at depth `z`: the half disc of `radius` over the spring line at
## height `h`, centred on x `cx`, as a fan of `steps` triangles; with `bar` > 0 the ring of that width round it
## instead. Facing the runner.
static func arch_head(layer: MeshLayer, size: Vector3, cx: float, h: float, radius: float, bar: float, z: float, color: Color,
		pattern: int = MeshKit.PAT_PLAIN, param: float = 0.0, steps: int = 12) -> void:
	var y: float = h - size.y * 0.5
	var centre := Vector3(cx, y, z)
	for i: int in steps:
		var a0: float = PI * (1.0 - float(i) / float(steps))
		var a1: float = PI * (1.0 - float(i + 1) / float(steps))
		var d0 := Vector3(cos(a0), sin(a0), 0.0)
		var d1 := Vector3(cos(a1), sin(a1), 0.0)
		if bar <= 0.0:
			layer.quad(centre, centre + d0 * radius, centre + d1 * radius, centre, color, 0.0, pattern, param)
		else:
			layer.quad(centre + d0 * radius, centre + d0 * (radius + bar), centre + d1 * (radius + bar), centre + d1 * radius, color,
				0.0, pattern, param)


## A mesh of cracks (dark, unlit, standing CRACK_OUT proud of a face at depth `z`) spreading from `hits` points
## within the x and height bounds `at` (x0, x1, h0, h1): a breakable face. The cracks' own random numbers come
## from `seed`, so a look's cracks never change.
static func cracks(layer: MeshLayer, size: Vector3, z: float, at: Vector4, hits: int, color: Color, seed: int,
		thickness: float = 1.0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["dash_wall_cracks", seed])
	for k: int in hits:
		var from := Vector2(lerpf(at.x, at.y, (float(k) + rng.randf_range(0.2, 0.8)) / float(hits)),
			rng.randf_range(at.z, at.w))
		var arms: int = rng.randi_range(4, 6)
		for a: int in arms:
			var angle: float = TAU * (float(a) + rng.randf_range(-0.3, 0.3)) / float(arms)
			_crack(layer, size, from, angle, rng.randi_range(3, 5), rng, at, z, color, thickness)


## One crack: a zigzag of thin segments from `from` (x, height on the face) heading at `angle`, kept inside
## the bounds `at`, a little thinner each segment.
static func _crack(layer: MeshLayer, size: Vector3, from: Vector2, angle: float, segments: int,
		rng: RandomNumberGenerator, at: Vector4, z: float, color: Color, thickness: float) -> void:
	var p: Vector2 = from
	var heading: float = angle
	var width: float = CRACK_WIDTH * thickness
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
