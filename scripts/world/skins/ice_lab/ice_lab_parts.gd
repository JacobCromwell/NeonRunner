class_name IceLabParts
extends RefCounted
## The Ice Lab's building blocks (IceLabSkin): primitives in **wall space** and the props built from them: pipes, spikes (ice
## crystals, icicles), snow caps, machine lamps, screens, specimen jars with a brain in them or a curled-up Octodog, a gantry
## rail with its railing. Wall space is the frame of the left wall: the wall face is the plane x = 0 and the street lies at +x,
## `s` runs along the face to the viewer's right (z = -s), y is up. A bay is built once in it and set on either wall by a
## transform (a half turn about y for the right wall: the left wall's frame seen from the other side), so nothing on a wall is
## drawn twice, and the same bay reads the same way from both sides. Where a runner can touch the wall (below the skin's calm_top)
## nothing stands out of it more than PROUD (4.5 cm, every wall-running zone's rule: ZoneSkin.WALL_RUN_LINE_PROUD), nothing is
## recessed into it and nothing glows; the machinery's depth, its lit screens and its specimen jars are above the band.
## Every vertex is a cost: a chunk of wall is sixteen bays, drawn every frame on a phone, so a part leaves out every face nobody
## sees (a box on a wall has no back and no bottom), keeps its curves to a few sides (a pipe six, an icicle three), and leaves
## the detail to the shader (the panels' vents, rivets, lights and frost are PAT_IL_*).
## Everything is cached by whoever builds it (IceLabWalls keeps its bays, this class holds no state but the skin).

## The most anything on a wall stands out of its face below the band (metres, as the Terminal's and every wall-running zone's): a pipe's
## half, a pilaster, a frame, a screen's bezel.
const PROUD: float = 0.045
## The faces of a box on the wall that anyone sees from the street: the front, the top and the two ends (not the back, nor the bottom).
const FRONT_FACES: int = MeshKit.FACE_PX | MeshKit.FACE_PY | MeshKit.FACE_PZ | MeshKit.FACE_NZ

## Weak: the skin owns this builder, so a strong reference back would keep both alive forever.
var skin: IceLabSkin:
	get:
		return _skin.get_ref() as IceLabSkin
var _skin: WeakRef


func _init(p_skin: IceLabSkin) -> void:
	_skin = weakref(p_skin)


# --- Primitives in wall space ------------------------------------------------------------------

## A diagonal brace in the plane x from (s0, y0) to (s1, y1), `t` thick, standing out from x_back to x_front.
func wdiag(l: MeshLayer, s0: float, y0: float, s1: float, y1: float, t: float, x_back: float, x_front: float, color: Color,
		pattern: int = MeshKit.PAT_IL_STEEL, param: float = 0.0) -> void:
	var ds: float = s1 - s0
	var dy: float = y1 - y0
	var length: float = sqrt(ds * ds + dy * dy)
	# A box's long axis is z (z = -s): turned about x by atan2(-dy, -ds) it lies along the brace.
	var turn := Basis.from_euler(Vector3(atan2(-dy, -ds), 0.0, 0.0)).scaled_local(Vector3(x_front - x_back, t, length))
	l.box_xform(Transform3D(turn, Vector3((x_back + x_front) * 0.5, (y0 + y1) * 0.5, -(s0 + s1) * 0.5)), color, 0.0, pattern,
		MeshKit.FACE_PX | MeshKit.FACE_PY | MeshKit.FACE_NY, param)


## A fringe of snow along the foot of the wall from s0 to s1, never more than 0.2 m high or PROUD out of the wall (it is in the wall-run
## band: the deep drifts are the floor's, in the gutter by the wall): lumps by a seed, over `share` of the stretch.
func foot_snow(l: MeshLayer, s0: float, s1: float, share: float, seed: int) -> void:
	var count: int = maxi(int((s1 - s0) / 1.2), 1)
	for i: int in count:
		if MeshKit.hash01(seed, i, 51) > share:
			continue
		var a: float = lerpf(s0, s1, float(i) / float(count))
		var b: float = lerpf(s0, s1, float(i + 1) / float(count))
		var h: float = 0.08 + 0.12 * MeshKit.hash01(seed, i, 52)
		var d: float = PROUD * (0.7 + 0.3 * MeshKit.hash01(seed, i, 53))
		var inside := Vector3(d * 0.3, h * 0.3, -(a + b) * 0.5)
		quad_out(l, Vector3(0.0, h, -a), Vector3(0.0, h, -b), Vector3(d, 0.0, -b), Vector3(d, 0.0, -a), inside, skin.snow_color, 0.0,
			MeshKit.PAT_IL_SNOW, 0.0)


## Ice shards lying along the wall's face (nearly flat to it, so they stand out of it no more than a few centimetres): `count`
## crystals fanning up from (s, y) from 0.4 to `max_length` long.
func shards(l: MeshLayer, s: float, y: float, count: int, max_length: float, seed: int) -> void:
	for i: int in count:
		var a: float = (float(i) - float(count - 1) * 0.5) * 0.3 + 0.12 * (MeshKit.hash01(seed, i, 61) - 0.5)
		var dir := Vector3(0.012, cos(a), -sin(a))
		var length: float = max_length * (0.4 + 0.6 * MeshKit.hash01(seed, i, 62))
		spike(l, Vector3(-0.075, y, -s - 0.05 * float(i)), dir, length, 0.05 + 0.03 * MeshKit.hash01(seed, i, 63), 4,
			skin.crystal_color.lerp(skin.ice_color, 0.3 * MeshKit.hash01(seed, i, 64)), MeshKit.PAT_IL_ICE, 1.0, 0.7)


## A rectangle in the plane x, facing the street, from s0 to s1 along the wall and y0 to y1 up it. UV is (s, y) in metres by
## default (so patterns line up across a bay), or `uv0` to `uv1` where given (a screen's own).
func wrect(l: MeshLayer, s0: float, s1: float, y0: float, y1: float, x: float, color: Color, glow: float = 0.0, pattern: int = 0,
		param: float = 0.0, uv0: Vector2 = Vector2(-INF, 0.0), uv1: Vector2 = Vector2.ZERO) -> void:
	var a: Vector2 = Vector2(s0, y0) if uv0.x == -INF else uv0
	var b: Vector2 = Vector2(s1, y1) if uv0.x == -INF else uv1
	l.rect(Vector3(x, y0, -s0), Vector3(0.0, 0.0, -(s1 - s0)), Vector3(0.0, y1 - y0, 0.0), color, glow, pattern, a, b, param)


## A box from s0 to s1, y0 to y1 and x0 to x1 (by default its front, top and two ends: the back and the bottom nobody sees below eye level;
## pass FACE_NY for a box seen from below).
func wbox(l: MeshLayer, s0: float, s1: float, y0: float, y1: float, x0: float, x1: float, color: Color, glow: float = 0.0,
		pattern: int = 0, param: float = 0.0, faces: int = FRONT_FACES) -> void:
	l.box(Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5, -(s0 + s1) * 0.5), Vector3(x1 - x0, y1 - y0, s1 - s0), color, glow, pattern,
		faces, param)


## A pipe along the wall at height y from s0 to s1, radius r, standing out no more than `proud` (half sunk into the wall if it is
## thick): a prism of `sides` faces.
func wpipe(l: MeshLayer, y: float, r: float, s0: float, s1: float, color: Color, sides: int = 6, proud: float = PROUD,
		param: float = 2.0) -> void:
	var xform := Transform3D(Basis.from_euler(Vector3(-PI * 0.5, 0.0, 0.0)).scaled_local(Vector3(r, s1 - s0, r)),
		Vector3(proud - r, y, -s0))
	l.prism_xform(xform, sides, color, 0.0, MeshKit.PAT_IL_STEEL, false, param)


## An upright pipe at s from y0 to y1.
func wriser(l: MeshLayer, s: float, r: float, y0: float, y1: float, color: Color, sides: int = 6, proud: float = PROUD) -> void:
	var xform := Transform3D(Basis.from_scale(Vector3(r, y1 - y0, r)), Vector3(proud - r, y0, -s))
	l.prism_xform(xform, sides, color, 0.0, MeshKit.PAT_IL_STEEL, false, 2.0)


## A round plate facing the street (a hand wheel, a gauge, a lid) at (s, y), radius r, `thick` deep from x0: a prism of `sides` faces,
## its front cap only.
func wdisc(l: MeshLayer, s: float, y: float, r: float, x0: float, thick: float, color: Color, sides: int = 6, pattern: int = 0,
		param: float = 0.0, glow: float = 0.0) -> void:
	var xform := Transform3D(Basis.from_euler(Vector3(0.0, 0.0, -PI * 0.5)).scaled_local(Vector3(r, thick, r)), Vector3(x0, y, -s))
	l.prism_xform(xform, sides, color, glow, pattern, true, param)


## A triangle given in any winding, turned so its front faces away from `inside` (a point inside the shape it closes).
func tri(l: MeshLayer, a: Vector3, b: Vector3, c: Vector3, inside: Vector3, color: Color, glow: float = 0.0, pattern: int = 0,
		param: float = 0.0) -> void:
	var front: Vector3 = -(b - a).cross(c - a)
	var first: Vector3 = b
	var second: Vector3 = c
	if front.dot(a - inside) < 0.0:
		first = c
		second = b
	l.verts.append_array(PackedVector3Array([a, first, second]))
	var col := Color(color, glow)
	l.colors.append_array(PackedColorArray([col, col, col]))
	l.uvs.append_array(PackedVector2Array([Vector2(0, 0), Vector2(0, 1), Vector2(1, 1)]))
	var p := Vector2(pattern, param)
	l.uv2s.append_array(PackedVector2Array([p, p, p]))


## A quadrilateral in any winding, turned outward from `inside` (two triangles).
func quad_out(l: MeshLayer, a: Vector3, b: Vector3, c: Vector3, d: Vector3, inside: Vector3, color: Color, glow: float = 0.0,
		pattern: int = 0, param: float = 0.0) -> void:
	tri(l, a, b, c, inside, color, glow, pattern, param)
	tri(l, a, c, d, inside, color, glow, pattern, param)


## A spike (an ice crystal or an icicle): a prism of `sides` faces of radius `width` from `base` along `dir` for `length`, its last part
## tapering to a point (`shaft` the share of the length that is prism: 0 a plain cone, which is all an icicle needs: nine vertices on
## three sides).
func spike(l: MeshLayer, base: Vector3, dir: Vector3, length: float, width: float, sides: int, color: Color, pattern: int = 0,
		param: float = 0.0, shaft: float = 0.7, twist: float = 0.0) -> void:
	var up: Vector3 = dir.normalized()
	var across: Vector3 = up.cross(Vector3.RIGHT if absf(up.x) < 0.9 else Vector3.UP).normalized()
	var along: Vector3 = up.cross(across)
	var ring0: Array[Vector3] = []
	var ring1: Array[Vector3] = []
	for i: int in sides:
		var a: float = TAU * float(i) / float(sides) + twist
		var off: Vector3 = (across * cos(a) + along * sin(a)) * width
		ring0.append(base + off)
		ring1.append(base + up * length * shaft + off * 0.9)
	var tip: Vector3 = base + up * length
	var inside: Vector3 = base + up * length * 0.4
	for i: int in sides:
		var k: int = (i + 1) % sides
		if shaft <= 0.01:
			tri(l, ring0[i], ring0[k], tip, inside, color, 0.0, pattern, param)
			continue
		quad_out(l, ring0[i], ring0[k], ring1[k], ring1[i], inside, color, 0.0, pattern, param)
		tri(l, ring1[i], ring1[k], tip, inside, color, 0.0, pattern, param)


## A tapered tube through `points` (radii `radii`), `sides` faces round, coloured from `colors` (one a point).
func tube(l: MeshLayer, points: PackedVector3Array, radii: PackedFloat32Array, sides: int, colors: PackedColorArray,
		pattern: int = 0) -> void:
	var rings: Array[PackedVector3Array] = []
	var side := Vector3.ZERO
	var n: int = points.size()
	for i: int in n:
		var tangent: Vector3 = (points[mini(i + 1, n - 1)] - points[maxi(i - 1, 0)]).normalized()
		side = side - tangent * side.dot(tangent)
		if side.length() < 0.01:
			side = tangent.cross(Vector3.UP if absf(tangent.y) < 0.9 else Vector3.RIGHT)
		side = side.normalized()
		var up: Vector3 = tangent.cross(side).normalized()
		var ring := PackedVector3Array()
		for k: int in sides:
			var a: float = TAU * float(k) / float(sides)
			ring.append(points[i] + (side * cos(a) + up * sin(a)) * radii[i])
		rings.append(ring)
	for i: int in n - 1:
		var mid: Vector3 = (points[i] + points[i + 1]) * 0.5
		for k: int in sides:
			var k1: int = (k + 1) % sides
			quad_out(l, rings[i][k], rings[i + 1][k], rings[i + 1][k1], rings[i][k1], mid, colors[i], 0.0, pattern, 0.0)
	var tip: Vector3 = points[n - 1] + (points[n - 1] - points[n - 2]).normalized() * radii[n - 1] * 2.0
	for k: int in sides:
		tri(l, rings[n - 1][k], rings[n - 1][(k + 1) % sides], tip, points[n - 1], colors[n - 1], 0.0, pattern, 0.0)


## A squashed sphere (lat-long, flat-shaded) centred at `c` with radii `r`.
func ellipsoid(l: MeshLayer, c: Vector3, r: Vector3, segments: int, rings: int, color: Color, pattern: int = 0,
		param: float = 0.0) -> void:
	var grid: Array[PackedVector3Array] = []
	for i: int in rings + 1:
		var lat: float = PI * float(i) / float(rings) - PI * 0.5
		var row := PackedVector3Array()
		for k: int in segments:
			var lon: float = TAU * float(k) / float(segments)
			row.append(c + Vector3(cos(lat) * sin(lon) * r.x, sin(lat) * r.y, cos(lat) * cos(lon) * r.z))
		grid.append(row)
	for i: int in rings:
		for k: int in segments:
			var k1: int = (k + 1) % segments
			var a: Vector3 = grid[i][k]
			var b: Vector3 = grid[i][k1]
			var d: Vector3 = grid[i + 1][k]
			var e: Vector3 = grid[i + 1][k1]
			if i == 0:
				tri(l, a, e, d, c, color, 0.0, pattern, param)
			elif i == rings - 1:
				tri(l, a, b, d, c, color, 0.0, pattern, param)
			else:
				quad_out(l, a, b, e, d, c, color, 0.0, pattern, param)


# --- Small things ------------------------------------------------------------------------------

## A machine lamp (GDD §5: small amber machine lamps): a short bar light in a cage on the wall at (s, y), `proud` out of the face, glowing
## dimly (never a hazard's glow: IceLabSkin.lamp_glow), with a faint halo card so it carries from afar. Only from the skin's lamp_min_height
## up: above the wall-run band and never at floor level, where a gap edge's orange is.
func lamp(l: MeshLayer, g: MeshLayer, s: float, y: float, seed: int, proud: float = 0.08) -> void:
	var y_at: float = maxf(y, skin.lamp_min_height)
	wbox(l, s - 0.3, s + 0.3, y_at - 0.1, y_at + 0.1, 0.0, proud + 0.02, skin.steel_color, 0.0, MeshKit.PAT_IL_STEEL, 2.0)
	wbox(l, s - 0.24, s + 0.24, y_at - 0.06, y_at + 0.06, 0.02, proud + 0.035, skin.lamp_color, skin.lamp_tube_glow(),
		MeshKit.PAT_IL_LAMP, float(seed % 1000), MeshKit.FACE_PX)
	g.rect(Vector3(proud + 0.04, y_at - 0.55, -(s - 0.55)), Vector3(0.0, 0.0, -1.1), Vector3(0.0, 1.1, 0.0), skin.lamp_color, 0.1,
		MeshKit.SHAPE_RADIAL, Vector2.ZERO, Vector2.ONE, MeshKit.near_fade(10.0))


## A row of `count` tiny pale status lights along a console at height y from s0 to s1 (the screens' colour): flush with the face and unlit,
## they are in the wall-run band, where nothing glows.
func status_lights(l: MeshLayer, s0: float, s1: float, y: float, count: int, seed: int) -> void:
	for i: int in count:
		if MeshKit.hash01(seed, i, 5) < 0.3:
			continue
		var s: float = lerpf(s0, s1, (float(i) + 0.5) / float(count))
		wrect(l, s - 0.025, s + 0.025, y - 0.025, y + 0.025, 0.02, skin.screen_color.darkened(0.15))


## A wall screen at (s0, y0), `w` by `h` metres, the pale readout (PAT_IL_SCREEN) of a console. In the wall-run band (`lit` false) it is a
## dull dark monitor flush with the face: a painted frame and the readout, no bezel and no glow. Above it (`lit`) it has a bezel standing
## out of the face and glows dimly.
func screen(l: MeshLayer, s0: float, y0: float, w: float, h: float, seed: int, lit: bool = false) -> void:
	if lit:
		wbox(l, s0 - 0.07, s0 + w + 0.07, y0 - 0.07, y0 + h + 0.07, 0.0, 0.1, skin.steel_color, 0.0, MeshKit.PAT_IL_STEEL, 2.0,
			MeshKit.FACE_PX | MeshKit.FACE_PY)
		wrect(l, s0, s0 + w, y0, y0 + h, 0.104, skin.screen_color, skin.screen_tube_glow(), MeshKit.PAT_IL_SCREEN,
			screen_param(seed, w, h), Vector2.ZERO, Vector2(w, h))
		return
	wrect(l, s0 - 0.06, s0 + w + 0.06, y0 - 0.06, y0 + h + 0.06, 0.012, skin.steel_color.darkened(0.2), 0.0, MeshKit.PAT_IL_STEEL, 0.0)
	wrect(l, s0, s0 + w, y0, y0 + h, 0.02, skin.screen_color.darkened(0.4), 0.0, MeshKit.PAT_IL_SCREEN, screen_param(seed, w, h),
		Vector2.ZERO, Vector2(w, h))


## PAT_IL_SCREEN's parameter: a seed 0-99, the width and height in decimetres.
static func screen_param(seed: int, w: float, h: float) -> float:
	return float(posmod(seed, 100) + 100 * clampi(roundi(w * 10.0), 1, 99) + 10000 * clampi(roundi(h * 10.0), 1, 99))


## Snow lying on a ledge: a low lumpy drift (PAT_IL_SNOW) on top of a box from s0 to s1 at height y, x0 to x1 deep: a ridge in lumps of about
## `lump` metres, each two sloping quads (12 vertices), the ends left open.
func snow_cap(l: MeshLayer, s0: float, s1: float, y: float, x0: float, x1: float, seed: int, height: float = 0.07, lump: float = 1.1) -> void:
	var count: int = maxi(roundi((s1 - s0) / lump), 1)
	var inside := Vector3(lerpf(x0, x1, 0.5), y - 0.02, -(s0 + s1) * 0.5)
	var xm: float = lerpf(x0, x1, 0.5)
	var prev: float = height * (0.5 + 0.9 * MeshKit.hash01(seed, 0, 9))
	for i: int in count:
		var a: float = lerpf(s0, s1, float(i) / float(count))
		var b: float = lerpf(s0, s1, float(i + 1) / float(count))
		var next: float = height * (0.5 + 0.9 * MeshKit.hash01(seed, i + 1, 9))
		var peak_a := Vector3(xm, y + prev, -a)
		var peak_b := Vector3(xm, y + next, -b)
		quad_out(l, Vector3(x0, y, -a), Vector3(x0, y, -b), peak_b, peak_a, inside, skin.snow_color, 0.0, MeshKit.PAT_IL_SNOW, 0.0)
		quad_out(l, Vector3(x1, y, -a), Vector3(x1, y, -b), peak_b, peak_a, inside, skin.snow_color, 0.0, MeshKit.PAT_IL_SNOW, 0.0)
		prev = next


## Icicles hanging at height y from s0 to s1 out to depth x: `count` of them, 0.3 to `max_length` long (from a seed), plain cones of three
## sides.
func icicles(l: MeshLayer, s0: float, s1: float, y: float, x: float, count: int, max_length: float, seed: int) -> void:
	for i: int in count:
		var s: float = lerpf(s0, s1, (float(i) + 0.3 + 0.4 * MeshKit.hash01(seed, i, 11)) / float(count))
		var length: float = 0.3 + (max_length - 0.3) * pow(MeshKit.hash01(seed, i, 12), 1.5)
		spike(l, Vector3(x + 0.1 * (MeshKit.hash01(seed, i, 13) - 0.5), y, -s), Vector3(0.0, -1.0, 0.0), length,
			0.045 + 0.05 * MeshKit.hash01(seed, i, 14), 3, skin.crystal_color, MeshKit.PAT_IL_ICE, 1.0, 0.0)


## A cluster of ice crystals growing out of the surface at `at` (any frame whose `up` is the way they fan around): `count` crystals of
## `sides` sides from 0.35 to `max_length` long fanning around `up` by up to `fan` radians. Used on far walls and standing, in a cluster,
## at a fence post's foot.
func crystals(l: MeshLayer, at: Vector3, up: Vector3, count: int, max_length: float, fan: float, seed: int, sides: int = 5,
		width: float = 0.12) -> void:
	var u: Vector3 = up.normalized()
	var across: Vector3 = u.cross(Vector3.RIGHT if absf(u.x) < 0.9 else Vector3.UP).normalized()
	var along: Vector3 = u.cross(across)
	for i: int in count:
		var a: float = TAU * (float(i) + MeshKit.hash01(seed, i, 21)) / float(count)
		var tilt: float = fan * (0.3 + 0.7 * MeshKit.hash01(seed, i, 22)) * (0.4 if i == 0 else 1.0)
		var dir: Vector3 = (u * cos(tilt) + (across * cos(a) + along * sin(a)) * sin(tilt)).normalized()
		var length: float = max_length * (0.35 + 0.65 * MeshKit.hash01(seed, i, 23)) * (1.0 if i == 0 else 0.8)
		spike(l, at + (across * cos(a) + along * sin(a)) * 0.08 * float(i > 0), dir, length, width * (0.6 + 0.8 * MeshKit.hash01(seed, i, 24)),
			sides, skin.crystal_color.lerp(skin.ice_color, 0.35 * MeshKit.hash01(seed, i, 25)), MeshKit.PAT_IL_ICE, 1.0, 0.72)


# --- Specimen jars ------------------------------------------------------------------------------

## A brain in a jar's liquid, at `c`, hanging in it: a squashed pink-grey blob (the lobes and folds are the shader's) with a cable rising
## from it up to the lid (`cable_top`, the height of the lid's underside).
func brain(l: MeshLayer, c: Vector3, scale: float, seed: int, cable_top: float = INF) -> void:
	ellipsoid(l, c, Vector3(0.2, 0.15, 0.2) * scale, 6, 4, skin.brain_color, MeshKit.PAT_IL_BRAIN, 0.0)
	var from: Vector3 = c + Vector3(0.0, 0.12 * scale, 0.0)
	var to := Vector3(c.x, minf(c.y + 1.4, cable_top), c.z + 0.04 * (MeshKit.hash01(seed, 1, 31) - 0.5))
	var cable: Color = skin.steel_color.darkened(0.2)
	tube(l, PackedVector3Array([from, to]), PackedFloat32Array([0.02, 0.015]), 3, PackedColorArray([cable, cable]))


## A curled-up Octodog (GDD §9.4, §5 Zone 9: some jars hold one instead of a brain), asleep at `c`, in the Octodog's own palette
## (OctodogModel's tentacle greens, its dim metal): a squashed mass with tentacles curling round it, its robot chassis folded under, its
## three eyes shut. Scenery only: dim, lit, never the glowing green and red of the live one (the owner's colour rule: only hazards glow in
## hazard colours), so it is never mistaken for an attack.
func octodog(l: MeshLayer, c: Vector3, scale: float, seed: int) -> void:
	var base_green: Color = OctodogModel.TENTACLE_GREEN_BASE.darkened(0.25)
	var tip_green: Color = OctodogModel.TENTACLE_GREEN_TIP.darkened(0.4)
	var metal := Color(0.34, 0.38, 0.45)
	ellipsoid(l, c, Vector3(0.3, 0.2, 0.34) * scale, 6, 3, base_green)
	# The folded robot chassis under the mass and its four legs tucked up beside it (hip, foot out and down: a dog asleep).
	l.box(c + Vector3(0.0, -0.2 * scale, 0.0), Vector3(0.34, 0.06, 0.5) * scale, metal.darkened(0.2), 0.0, 0, FRONT_FACES)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var hip: Vector3 = c + Vector3(sx * 0.15, -0.2, sz * 0.2) * scale
			var foot: Vector3 = hip + Vector3(sx * 0.16, -0.16, sz * 0.2) * scale
			tube(l, PackedVector3Array([hip, foot]), PackedFloat32Array([0.045 * scale, 0.03 * scale]), 3,
				PackedColorArray([metal, metal.lightened(0.15)]))
	# Tentacles spiralling round the mass, thinning to a tip curled inward.
	var count: int = 4
	for i: int in count:
		var a0: float = TAU * float(i) / float(count) + 0.4 * MeshKit.hash01(seed, i, 41)
		var points := PackedVector3Array()
		var radii := PackedFloat32Array()
		var colors := PackedColorArray()
		var steps: int = 2
		for k: int in steps + 1:
			var t: float = float(k) / float(steps)
			var ang: float = a0 + t * PI * 1.5 * (1.0 if i % 2 == 0 else -1.0)
			var rad: float = (0.3 + 0.12 * sin(t * PI)) * (1.0 - 0.45 * t * t)
			var h: float = lerpf(0.04, 0.3, t) - 0.12 * float(i % 3) * 0.3
			points.append(c + Vector3(sin(ang) * rad, h - 0.04, cos(ang) * rad * 1.15) * scale)
			radii.append(lerpf(0.08, 0.02, t) * scale)
			colors.append(base_green.lerp(tip_green, t * t))
		tube(l, points, radii, 3, colors)
	# Three eyes, shut: dark red-brown slits on the front (the street's side, +x here).
	for e: int in 3:
		l.box(Vector3(c.x + 0.27 * scale, c.y + 0.05 * scale, c.z + (float(e) - 1.0) * 0.1 * scale), Vector3(0.03, 0.025, 0.05) * scale,
			Color(0.28, 0.08, 0.06), 0.0, 0, MeshKit.FACE_PX)


## A specimen jar standing in an alcove: the liquid's pale, dim backdrop (PAT_IL_JAR), the brain (or the curled Octodog) hanging in front of
## it, a lid with a tube up into the alcove's roof, a pedestal, and a pale glass glint down its front. Its middle is at `s`, standing on
## y0, `width` wide and `height` tall (the liquid), its backdrop at x = back (the alcove's back wall is further behind), the alcove's roof
## at `roof` (the tube from the lid reaches it); nothing reaches past x = 0 (the wall face).
func jar(l: MeshLayer, s: float, y0: float, width: float, height: float, back: float, holds_octodog: bool, seed: int,
		roof: float = INF) -> void:
	var glow: float = skin.liquid_tube_glow()
	var kind: float = 1.0 if holds_octodog else 0.0
	var hw: float = width * 0.5
	# The liquid: one panel, shaded across like a cylinder and brightest in the middle, with a glint down it.
	wrect(l, s - hw, s + hw, y0, y0 + height, back, skin.liquid_color, glow, MeshKit.PAT_IL_JAR, kind, Vector2(-1.0, 0.0), Vector2(1.0, 1.0))
	wrect(l, s - hw * 0.72, s - hw * 0.62, y0 + 0.2, y0 + height - 0.3, back + 0.12, skin.screen_color, glow * 0.7, MeshKit.PAT_IL_SCREEN,
		screen_param(3, 0.1, 3.0), Vector2.ZERO, Vector2(0.1, 3.0))
	# The lid and the pedestal, and one tube from the lid up into the alcove's roof.
	wbox(l, s - hw - 0.1, s + hw + 0.1, y0 + height, y0 + height + 0.2, back, back + 0.2, skin.frame_color, 0.0, MeshKit.PAT_IL_STEEL, 2.0,
		FRONT_FACES | MeshKit.FACE_NY)
	wbox(l, s - hw - 0.14, s + hw + 0.14, y0 - 0.4, y0, back, back + 0.24, skin.frame_color.darkened(0.2), 0.0, MeshKit.PAT_IL_STEEL, 2.0)
	var tube_length: float = clampf(roof - (y0 + height + 0.2), 0.05, 0.9)
	l.prism_xform(Transform3D(Basis.from_scale(Vector3(0.04, tube_length, 0.04)), Vector3(back + 0.1, y0 + height + 0.2, -(s + 0.2 * width))), 4,
		skin.steel_color.lightened(0.05), 0.0, MeshKit.PAT_IL_STEEL, false, 2.0)
	# What it holds, hanging in the liquid a little in front of the backdrop.
	if holds_octodog:
		octodog(l, Vector3(back + 0.25, y0 + height * 0.5, -s), minf(width * 0.95, 1.0), seed)
	else:
		brain(l, Vector3(back + 0.28, y0 + height * 0.5 + 0.12, -s), width * 1.3, seed, y0 + height)


# --- The gantry rail on top of the wall -------------------------------------------------------------

## The hall's gantry rail along the top of the wall from s0 to s1 at height y (the wall's top), built once for a whole wall piece (not per
## bay: a rail is one long thing): a grated deck standing out over the street, its edge, a bracket down to the wall every 10 m, a railing
## on posts (every 2.5 m) with two rails, snow on the deck in a lump every 3.3 m and an icicle hanging from its edge every 3.6 m. All of
## it above the band (the deck's underside at y - 0.3).
func gantry(l: MeshLayer, s0: float, s1: float, y: float, seed: int) -> void:
	var reach: float = 1.4
	wbox(l, s0, s1, y - 0.3, y, 0.0, reach, skin.steel_color, 0.0, MeshKit.PAT_IL_STEEL, 4.0,
		MeshKit.FACE_PX | MeshKit.FACE_NY | MeshKit.FACE_PZ | MeshKit.FACE_NZ)
	wbox(l, s0, s1, y - 0.12, y + 0.14, reach - 0.06, reach, skin.frame_color, 0.0, MeshKit.PAT_IL_STEEL, 0.0, MeshKit.FACE_PX | MeshKit.FACE_PY)
	snow_cap(l, s0, s1, y, 0.1, reach - 0.1, seed, 0.1, 3.3)
	# A bracket: a diagonal strut from the wall up to the deck every 10 m, and a railing post every 2.5 m.
	var strut := Basis.from_euler(Vector3(0.0, 0.0, -0.9)).scaled_local(Vector3(0.1, 1.8, 0.1))
	var bs: float = s0 + 2.5
	while bs < s1:
		l.box_xform(Transform3D(strut, Vector3(0.7, y - 1.2, -bs)), skin.steel_color.lightened(0.04), 0.0, MeshKit.PAT_IL_STEEL,
			MeshKit.FACE_PX | MeshKit.FACE_PZ | MeshKit.FACE_NZ, 0.0)
		bs += 10.0
	var s: float = s0 + 0.1
	while s < s1:
		wbox(l, s - 0.03, s + 0.03, y, y + 1.15, reach - 0.12, reach - 0.06, skin.frame_color, 0.0, MeshKit.PAT_IL_STEEL, 2.0,
			MeshKit.FACE_PX | MeshKit.FACE_PZ)
		s += 2.5
	for ry: float in [y + 0.55, y + 1.12]:
		wbox(l, s0, s1, ry - 0.025, ry + 0.025, reach - 0.12, reach - 0.06, skin.frame_color, 0.0, MeshKit.PAT_IL_STEEL, 2.0,
			MeshKit.FACE_PX | MeshKit.FACE_PY)
	icicles(l, s0 + 0.3, s1 - 0.3, y - 0.3, reach - 0.05, maxi(int((s1 - s0) / 3.6), 1), 1.1, seed + 3)
