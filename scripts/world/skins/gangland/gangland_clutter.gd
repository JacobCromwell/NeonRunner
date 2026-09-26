class_name GanglandClutter
extends RefCounted
## Small props for Gangland's signs of life and its hints of corporate and military funding
## (GanglandSkin, GDD §5): crates and container doors with stencilled markings (PAT_STENCIL),
## sandbags, laundry, water tanks, antennas and dishes, car wrecks. Static builders into MeshLayers of
## the skin's solid material; the caller passes colours from the skin. None of them glows.
## Positions are world (chunk) space unless a builder says otherwise; `foot` is the centre of a
## prop's base.


## A crate standing on `foot`, `size` big, its stencilled front facing `front` (±x or +z; other sides
## plain). `stencil` is a MeshKit.stencil_param(). Faces nobody sees (the bottom) are skipped.
static func crate(s: MeshLayer, foot: Vector3, size: Vector3, color: Color, front: Vector3, stencil: float) -> void:
	var c: Vector3 = foot + Vector3(0, size.y * 0.5, 0)
	var front_face: int = MeshKit.FACE_PZ if front.z > 0.5 else (MeshKit.FACE_PX if front.x > 0.5 else MeshKit.FACE_NX)
	s.box(c, size, color.darkened(0.12), 0.0, MeshKit.PAT_PLAIN, MeshKit.NO_BOTTOM & ~front_face)
	var h: float = size.y
	var uv0 := Vector2(-0.5, -0.5)
	var uv1 := Vector2(0.5, 0.5)
	if front.z > 0.5:
		uv0 *= Vector2(size.x, h)
		uv1 *= Vector2(size.x, h)
		s.rect(c + Vector3(-size.x * 0.5, -h * 0.5, size.z * 0.5), Vector3(size.x, 0, 0), Vector3(0, h, 0), color, 0.0,
			MeshKit.PAT_STENCIL, uv0, uv1, stencil)
	elif front.x > 0.5:
		uv0 *= Vector2(size.z, h)
		uv1 *= Vector2(size.z, h)
		s.rect(c + Vector3(size.x * 0.5, -h * 0.5, size.z * 0.5), Vector3(0, 0, -size.z), Vector3(0, h, 0), color, 0.0,
			MeshKit.PAT_STENCIL, uv0, uv1, stencil)
	else:
		uv0 *= Vector2(size.z, h)
		uv1 *= Vector2(size.z, h)
		s.rect(c + Vector3(-size.x * 0.5, -h * 0.5, -size.z * 0.5), Vector3(0, 0, size.z), Vector3(0, h, 0), color, 0.0,
			MeshKit.PAT_STENCIL, uv0, uv1, stencil)


## A little stack of crates (1-3) on `foot`, fronts facing `front`, picked by hashing `k`. Up to
## `emblem_share` of the wider crates carry the cult's emblem beside their marking.
static func crate_stack(s: MeshLayer, foot: Vector3, front: Vector3, colors: PackedColorArray, k: int,
		emblem_share: float = 0.0) -> void:
	var count: int = 1 + MeshKit.hash_i(k, 1) % 3
	var y: float = 0.0
	for i: int in count:
		var w: float = 0.9 + 0.5 * MeshKit.hash01(k, i, 2)
		var h: float = 0.55 + 0.35 * MeshKit.hash01(k, i, 3)
		var d: float = 0.7 + 0.3 * MeshKit.hash01(k, i, 4)
		var size := Vector3(d, h, w) if absf(front.x) > 0.5 else Vector3(w, h, d)
		var shift := Vector3(0.12, 0, 0.1) * (MeshKit.hash01(k, i, 5) - 0.5)
		var kind: int = MeshKit.STENCIL_LOGO if MeshKit.hash01(k, i, 6) < 0.3 else MeshKit.STENCIL_CODE
		var color: Color = colors[MeshKit.hash_i(k, i, 7) % colors.size()]
		var cult: bool = w > 1.1 and MeshKit.hash01(k, i, 9) < emblem_share
		crate(s, foot + shift + Vector3(0, y, 0), size, color, front,
			MeshKit.stencil_param(kind, 0, MeshKit.hash_i(k, i, 8), cult))
		y += h


## Sandbags around `foot` in a ring of `radius`: `layers` rows of bags, each row turned half a bag.
static func sandbag_ring(s: MeshLayer, foot: Vector3, radius: float, layers: int, bags: int, color: Color) -> void:
	for layer: int in layers:
		for i: int in bags:
			var a: float = TAU * (float(i) + 0.5 * float(layer % 2)) / float(bags)
			var at: Vector3 = foot + Vector3(cos(a) * radius, 0.07 + 0.13 * layer, sin(a) * radius)
			var turn := Basis(Vector3.UP, -a + PI * 0.5).scaled_local(Vector3(0.36, 0.14, 0.2))
			var tone: float = 0.9 + 0.2 * MeshKit.hash01(layer, i, 31)
			s.box_xform(Transform3D(turn, at), color * Color(tone, tone, tone), 0.0, MeshKit.PAT_PLAIN, MeshKit.NO_BOTTOM)


## A straight wall of sandbags along x from `a` (its left end, on the ground) `length` metres long.
static func sandbag_wall(s: MeshLayer, a: Vector3, length: float, layers: int, color: Color) -> void:
	var per_row: int = maxi(1, floori(length / 0.4))
	for layer: int in layers:
		for i: int in per_row:
			var x: float = (float(i) + 0.5 + 0.5 * float(layer % 2)) * length / float(per_row)
			if x > length - 0.1:
				continue
			var tone: float = 0.9 + 0.2 * MeshKit.hash01(layer, i, 37)
			s.box(a + Vector3(x, 0.07 + 0.13 * layer, 0), Vector3(0.38, 0.14, 0.24), color * Color(tone, tone, tone), 0.0,
				MeshKit.PAT_PLAIN, MeshKit.NO_BOTTOM)


## A cloth hanging from a line at `top` (its top edge centre), facing ±z: two back-to-back quads.
static func cloth(s: MeshLayer, top: Vector3, width: float, height: float, color: Color, along_x: bool) -> void:
	if along_x:
		var o: Vector3 = top + Vector3(-width * 0.5, -height, 0)
		s.rect(o, Vector3(width, 0, 0), Vector3(0, height, 0), color)
		s.rect(o + Vector3(width, 0, 0), Vector3(-width, 0, 0), Vector3(0, height, 0), color.darkened(0.15))
	else:
		var o: Vector3 = top + Vector3(0, -height, width * 0.5)
		s.rect(o, Vector3(0, 0, -width), Vector3(0, height, 0), color)
		s.rect(o + Vector3(0, 0, -width), Vector3(0, 0, width), Vector3(0, height, 0), color.darkened(0.15))


## A washing line from a to b sagging `sag` metres in the middle (a thin dark box per half), hung
## with laundry in `colors` picked by hashing `k` (none if `colors` is empty).
static func laundry_line(s: MeshLayer, a: Vector3, b: Vector3, sag: float, colors: PackedColorArray, k: int,
		line_color: Color) -> void:
	var mid: Vector3 = (a + b) * 0.5 - Vector3(0, sag, 0)
	for pair: Array in [[a, mid], [mid, b]]:
		var p: Vector3 = pair[0]
		var q: Vector3 = pair[1]
		var d: Vector3 = q - p
		var basis := Basis.looking_at(d.normalized(), Vector3.UP if absf(d.normalized().y) < 0.99 else Vector3.RIGHT)
		s.box_xform(Transform3D(basis.scaled_local(Vector3(0.03, 0.03, d.length())), (p + q) * 0.5), line_color)
	if colors.is_empty():
		return
	var along_x: bool = absf(b.x - a.x) > absf(b.z - a.z)
	var length: float = a.distance_to(b)
	var count: int = clampi(floori(length / 1.1), 1, 12)
	for i: int in count:
		if MeshKit.hash01(k, i, 41) < 0.2:
			continue
		var t: float = (float(i) + 0.3 + 0.4 * MeshKit.hash01(k, i, 45)) / float(count)
		var at: Vector3 = a.lerp(b, t) - Vector3(0, sag * (1.0 - pow(2.0 * t - 1.0, 2.0)), 0)
		var color: Color = colors[MeshKit.hash_i(k, i, 44) % colors.size()]
		var kind: float = MeshKit.hash01(k, i, 46)
		if kind < 0.35:
			# A shirt: body and sleeves.
			var w: float = 0.32 + 0.12 * MeshKit.hash01(k, i, 42)
			cloth(s, at, w * 1.9, 0.2, color, along_x)
			cloth(s, at - Vector3(0, 0.18, 0), w, 0.4 + 0.15 * MeshKit.hash01(k, i, 43), color, along_x)
		elif kind < 0.7:
			# A towel or a sheet.
			cloth(s, at, 0.5 + 0.35 * MeshKit.hash01(k, i, 42), 0.35 + 0.6 * MeshKit.hash01(k, i, 43), color, along_x)
		else:
			# Rags and socks.
			cloth(s, at, 0.12 + 0.12 * MeshKit.hash01(k, i, 42), 0.25 + 0.2 * MeshKit.hash01(k, i, 43), color, along_x)


## A water tank on four legs standing on `foot` (radius r, tank height h).
static func water_tank(s: MeshLayer, foot: Vector3, r: float, h: float, color: Color) -> void:
	var legs: float = 1.2
	for dx: float in [-1.0, 1.0]:
		for dz: float in [-1.0, 1.0]:
			s.box(foot + Vector3(dx * r * 0.6, legs * 0.5, dz * r * 0.6), Vector3(0.1, legs, 0.1), color.darkened(0.3))
	s.prism(foot + Vector3(0, legs, 0), r, h, 8, color, 0.0, MeshKit.PAT_RUST)
	s.prism(foot + Vector3(0, legs + h, 0), r * 1.04, 0.12, 8, color.darkened(0.25))


## An antenna mast with cross bars, `height` tall, standing on `foot`.
static func antenna(s: MeshLayer, foot: Vector3, height: float, color: Color, k: int) -> void:
	s.box(foot + Vector3(0, height * 0.5, 0), Vector3(0.07, height, 0.07), color)
	var bars: int = 2 + MeshKit.hash_i(k, 3) % 3
	for i: int in bars:
		var y: float = height * (0.55 + 0.4 * float(i) / float(bars))
		var w: float = 0.6 + 0.9 * MeshKit.hash01(k, i, 4)
		s.box(foot + Vector3(0, y, 0), Vector3(w, 0.04, 0.04) if i % 2 == 0 else Vector3(0.04, 0.04, w), color)


## A satellite dish on a short stem at `foot`, tilted up toward `face` (a horizontal direction).
static func dish(s: MeshLayer, foot: Vector3, r: float, face: Vector3, color: Color) -> void:
	s.box(foot + Vector3(0, 0.35, 0), Vector3(0.08, 0.7, 0.08), color.darkened(0.3))
	var fwd: Vector3 = (face.normalized() + Vector3(0, 0.8, 0)).normalized()
	var basis := Basis.looking_at(-fwd, Vector3.UP)
	# The unit prism's axis is y: turn it onto the dish's facing, flattened to a shallow disc.
	var disc := Basis(basis.x * r, -basis.z * 0.12, basis.y * r)
	s.prism_xform(Transform3D(disc, foot + Vector3(0, 0.75, 0)), 8, color)


## A burnt-out car wreck on `foot`, facing along x or z (`along_x`), in rusty `color`.
static func wreck(s: MeshLayer, foot: Vector3, along_x: bool, color: Color, k: int) -> void:
	var length: float = 3.8 + 0.6 * MeshKit.hash01(k, 51)
	var body := Vector3(length, 0.75, 1.75) if along_x else Vector3(1.75, 0.75, length)
	s.box(foot + Vector3(0, 0.25 + body.y * 0.5, 0), body, color, 0.0, MeshKit.PAT_RUST, MeshKit.NO_BOTTOM)
	var cab := Vector3(length * 0.45, 0.55, 1.5) if along_x else Vector3(1.5, 0.55, length * 0.45)
	var shift: float = (MeshKit.hash01(k, 52) - 0.5) * length * 0.2
	var at: Vector3 = foot + Vector3(shift if along_x else 0.0, 0.25 + body.y + cab.y * 0.5, 0.0 if along_x else shift)
	s.box(at, cab, color.darkened(0.35), 0.0, MeshKit.PAT_RUST, MeshKit.NO_BOTTOM)
