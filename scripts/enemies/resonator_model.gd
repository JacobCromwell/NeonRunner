class_name ResonatorModel
extends Node3D
## The Resonator's look (GDD §9.10, proposed: "a floating, slender golden spire ringed by 2–3 slowly
## turning halos around a red glowing core"). It leans on sci-fi and reads as the cult's broadcast
## technology, never as anything from a church: an antenna or probe in elegant luxury tech, with no
## bell, chain, cross, candle or steeple shape. DESIGN-TBD (docs/questions/c3.md): the look.
## - The spire: a faceted, double-ended mast of polished gold (the Golden Zone's gold, CultEmblem's:
##   reflective metal, never a glow) with ivory enamel collars (the zone's white and cream) and three
##   fins at each end (the Convergent Triad's three-fold symmetry): a transmitter tip pointing up, an
##   emitter pointing down at the floor with a collar that glows red while it warns. Its middle opens
##   into a cage of three gold ribs around the core.
## - The core: a red crystal, the one part that always glows (red is enemy fire, GDD §5).
## - Three broken halos (three arcs each, with ivory nodes at the breaks), gold with a red inner ring
##   that glows while it warns. At rest they tumble slowly; in the warning each spins up and swings into
##   line facing the runner (+Z) on a note of the chime, so the runner sees three red rings lock into a
##   target, one per note.
## Four draw calls (the spire with its core, one per halo) and about 1,600 triangles, in one shader
## (resonator.gdshader) that works on every renderer; the meshes are built once and shared. Its origin
## is the core. The Resonator sets the animation inputs every frame; wave_mesh() builds its waves.

## The spire's tips above and below the core (at model scale 1).
const TOP_Y: float = 2.45
const BOTTOM_Y: float = -2.25
## The halos: radii (to the band's middle), with arcs starting at these angles (degrees).
const HALO_RADII: Array[float] = [1.0, 1.32, 1.64]
const HALO_OFFSETS: Array[float] = [0.0, 40.0, 80.0]
const HALO_WIDTH: float = 0.13
const HALO_THICKNESS: float = 0.05
## The red inner ring on each halo's faces.
const HALO_TRIM: float = 0.04
const ARC_DEGREES: float = 100.0
const ARC_SEGMENTS: int = 9
## At rest each halo leans this way (Euler degrees) and turns about the spire's axis at this speed.
const HALO_TILTS: Array[Vector3] = [Vector3(24.0, 0.0, 12.0), Vector3(-38.0, 30.0, -20.0), Vector3(58.0, -50.0, 34.0)]
const HALO_PRECESSION: Array[float] = [0.35, -0.27, 0.22]
## Spin about their own axes (rad/s): at rest, and fully spun up.
const SPIN_REST: float = 0.5
const SPIN_WARNING: float = 7.0
const FACETS: int = 6

## The Golden Zone's gold (CultEmblem.GOLD_COLOR, the cult's gold everywhere in the zone: pale and only
## half saturated, so it never reads as sign yellow or gap-edge orange), a darker gold for the inner
## parts, ivory enamel, and the core's red (enemy fire).
const GOLD: Color = CultEmblem.GOLD_COLOR
const GOLD_DEEP := Color(0.50, 0.41, 0.25)
const IVORY := Color(0.89, 0.86, 0.79)
const RED := Color(1.0, 0.15, 0.1)
## What a surface is (vertex alpha, resonator.gdshader): lit, a trim that glows while it warns, the core.
const LIT: float = 0.0
const TRIM: float = 0.5
const CORE: float = 1.0

static var _spire_mesh: ArrayMesh
static var _halo_meshes: Array[ArrayMesh] = []
static var _wave_meshes: Dictionary = {}
static var _shader: Shader
static var _wave_shader: Shader

## Animation inputs, set by the Resonator every frame.
## How far each halo has swung into line (0 at rest, 1 facing the runner).
var align: Array[float] = [0.0, 0.0, 0.0]
## How brightly each halo's inner ring glows (0 at rest).
var halo_glow: Array[float] = [0.0, 0.0, 0.0]
## 0 at rest, 1 fully spun up.
var spin: float = 0.0
var core_glow: float = 1.0
var emitter_glow: float = 0.0
var flash: float = 0.0
var dim: float = 0.0
## Seconds since it was shot down (-1 while whole): it breaks apart.
var broken: float = -1.0

var _spire: MeshInstance3D
var _halos: Array[MeshInstance3D] = []
var _spire_mat: ShaderMaterial
var _halo_mats: Array[ShaderMaterial] = []
var _spin_angle: Array[float] = [0.0, 0.0, 0.0]
var _precess: Array[float] = [0.0, 0.0, 0.0]
var _fall: Array[Vector3] = []
var _fall_v: Array[Vector3] = []


func build(model_scale: float = 1.0) -> void:
	scale = Vector3.ONE * model_scale
	_spire_mat = ShaderMaterial.new()
	_spire_mat.shader = shader()
	_spire = MeshInstance3D.new()
	_spire.name = "Spire"
	_spire.mesh = spire_mesh()
	_spire.material_override = _spire_mat
	_spire.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_spire)
	for k: int in HALO_RADII.size():
		var mat := ShaderMaterial.new()
		mat.shader = shader()
		mat.set_shader_parameter(&"core", 0.0)
		_halo_mats.append(mat)
		var halo := MeshInstance3D.new()
		halo.name = "Halo%d" % k
		halo.mesh = halo_mesh(k)
		halo.material_override = mat
		halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(halo)
		_halos.append(halo)
		_spin_angle[k] = k * 1.3
		_precess[k] = k * 2.1
	_update_halos(0.0)


## Draw calls: one per mesh surface in the model.
func draw_call_count() -> int:
	var n: int = 0
	for m: MeshInstance3D in [_spire] + _halos:
		n += m.mesh.get_surface_count()
	return n


func triangle_count() -> int:
	var n: int = 0
	for m: MeshInstance3D in [_spire] + _halos:
		for s: int in m.mesh.get_surface_count():
			n += (m.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return n


## The halos' world-space normals (where each faces), for tests and the showcase.
func halo_normals() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for h: MeshInstance3D in _halos:
		out.append(h.global_basis.y.normalized())
	return out


## World position of the emitter's tip, where a pulse leaves for the floor.
func emitter_point() -> Vector3:
	return to_global(Vector3(0.0, BOTTOM_Y, 0.0))


func animate(delta: float) -> void:
	_spire_mat.set_shader_parameter(&"core", core_glow)
	_spire_mat.set_shader_parameter(&"glow", emitter_glow)
	_spire_mat.set_shader_parameter(&"flash", flash)
	_spire_mat.set_shader_parameter(&"dim", dim)
	for k: int in _halo_mats.size():
		_halo_mats[k].set_shader_parameter(&"glow", halo_glow[k])
		_halo_mats[k].set_shader_parameter(&"flash", flash * align[k])
		_halo_mats[k].set_shader_parameter(&"dim", dim)
	if broken >= 0.0:
		_break_apart(delta)
		return
	_update_halos(delta)


func _update_halos(delta: float) -> void:
	var spin_speed: float = lerpf(SPIN_REST, SPIN_WARNING, spin * spin)
	for k: int in _halos.size():
		var dir: float = 1.0 if k % 2 == 0 else -1.0
		_spin_angle[k] = fmod(_spin_angle[k] + dir * spin_speed * (1.0 + 0.25 * k) * delta, TAU)
		_precess[k] = fmod(_precess[k] + HALO_PRECESSION[k] * delta, TAU)
		var t: Vector3 = HALO_TILTS[k] * (PI / 180.0)
		var rest := Quaternion(Basis(Vector3.UP, _precess[k]) * Basis.from_euler(t))
		# In line: the ring's own axis (+Y in its mesh) turned to face the runner (+Z).
		var lined := Quaternion(Basis(Vector3.RIGHT, PI * 0.5))
		var a: float = clampf(align[k], 0.0, 1.0)
		var turn := rest.slerp(lined, a * a * (3.0 - 2.0 * a))
		_halos[k].basis = Basis(turn) * Basis(Vector3.UP, _spin_angle[k])
		_halos[k].position = Vector3.ZERO


## Shot down: the halos fly apart and fall, the spire tips over and drops (visual only).
func _break_apart(delta: float) -> void:
	if _fall.is_empty():
		for k: int in _halos.size():
			var out: float = (TAU / 3.0) * k + 0.6
			_fall.append(Vector3.ZERO)
			_fall_v.append(Vector3(cos(out) * 2.5, 2.0 + k * 0.6, sin(out) * 1.5))
		_fall.append(Vector3.ZERO)
		_fall_v.append(Vector3(0.0, 0.5, 0.0))
	for k: int in _halos.size():
		_fall_v[k].y -= 12.0 * delta
		_fall[k] += _fall_v[k] * delta
		_halos[k].position = _fall[k]
		_halos[k].rotate_object_local(Vector3(1.0, 0.3, 0.2).normalized(), (6.0 + k * 3.0) * delta)
	var s: int = _halos.size()
	_fall_v[s].y -= 9.0 * delta
	_fall[s] += _fall_v[s] * delta
	_spire.position = _fall[s]
	_spire.rotation.z = minf(_spire.rotation.z + 1.8 * delta, 1.4)


# --- Meshes ---------------------------------------------------------------------------------------

static func shader() -> Shader:
	if _shader == null:
		_shader = load("res://scripts/enemies/resonator.gdshader") as Shader
	return _shader


static func wave_shader() -> Shader:
	if _wave_shader == null:
		_wave_shader = load("res://scripts/enemies/resonator_wave.gdshader") as Shader
	return _wave_shader


## The spire, its cage and fins, and the core, in one surface.
static func spire_mesh() -> ArrayMesh:
	if _spire_mesh != null:
		return _spire_mesh
	var b := _Builder.new()
	# The upper mast, from the cage's top rim to the transmitter tip: [radius, height, kind of the
	# stretch from this point to the next].
	b.lathe([[0.0, 0.5, &"deep"], [0.3, 0.56, &"ivory"], [0.3, 0.62, &"gold"], [0.22, 0.74, &"gold"],
		[0.13, 0.95, &"gold"], [0.13, 1.28, &"ivory"], [0.24, 1.4, &"ivory"], [0.24, 1.48, &"gold"],
		[0.12, 1.6, &"gold"], [0.07, 2.05, &"gold"], [0.0, TOP_Y, &"gold"]])
	# The lower mast down to the emitter's tip, with the collar that glows while it warns.
	b.lathe([[0.0, -0.5, &"deep"], [0.3, -0.56, &"ivory"], [0.3, -0.62, &"gold"], [0.22, -0.74, &"gold"],
		[0.12, -0.95, &"gold"], [0.12, -1.22, &"gold"], [0.26, -1.34, &"trim"], [0.26, -1.44, &"gold"],
		[0.14, -1.56, &"gold"], [0.08, -1.95, &"gold"], [0.0, BOTTOM_Y, &"gold"]])
	# The cage: three ribs bowing out around the core, on the sides and at the back (the core faces
	# the runner).
	for deg: float in [30.0, 150.0, 270.0]:
		var dir := Vector3(cos(deg_to_rad(deg)), 0.0, sin(deg_to_rad(deg)))
		var mid: Vector3 = dir * 0.42
		b.bar(dir * 0.28 + Vector3(0.0, -0.58, 0.0), mid, dir, 0.07, 0.05, &"gold")
		b.bar(mid, dir * 0.28 + Vector3(0.0, 0.58, 0.0), dir, 0.07, 0.05, &"gold")
	# Three slim vanes at each end, like an antenna's or a probe's.
	for deg: float in [30.0, 150.0, 270.0]:
		var dir := Vector3(cos(deg_to_rad(deg)), 0.0, sin(deg_to_rad(deg)))
		b.fin(dir, 0.08, 0.24, 1.62, 2.28, 0.03, &"gold")
		b.fin(dir, 0.1, 0.3, -1.5, -2.02, 0.035, &"gold")
	# The core: a red crystal (a six-sided bipyramid).
	b.bipyramid(0.24, 0.38, &"core")
	_spire_mesh = b.commit()
	return _spire_mesh


## Halo `k`: three gold arcs with a red inner ring on both faces and ivory nodes at the breaks, flat in
## the XZ plane (its axis +Y).
static func halo_mesh(k: int) -> ArrayMesh:
	while _halo_meshes.size() <= k:
		_halo_meshes.append(null)
	if _halo_meshes[k] != null:
		return _halo_meshes[k]
	var b := _Builder.new()
	var r: float = HALO_RADII[k]
	for arc: int in 3:
		var a0: float = deg_to_rad(HALO_OFFSETS[k] + arc * 120.0)
		var a1: float = a0 + deg_to_rad(ARC_DEGREES)
		b.ring_arc(r - HALO_WIDTH * 0.5, r + HALO_WIDTH * 0.5, HALO_THICKNESS * 0.5, a0, a1, ARC_SEGMENTS, HALO_TRIM)
		for a: float in [a0, a1]:
			var dir := Vector3(cos(a), 0.0, sin(a))
			b.box(dir * r, Vector3(0.09, HALO_THICKNESS + 0.04, HALO_WIDTH + 0.05), dir, &"ivory")
	_halo_meshes[k] = b.commit()
	return _halo_meshes[k]


## A wave's mesh for a band `half_width` either side of the track's middle (its hitbox's), `height`
## tall and `depth` deep (the crest, a little over the hitbox), whose ends taper to nothing over
## `taper` metres past the band, with a wake `wake` metres long behind it. UV and UV2 as
## resonator_wave.gdshader reads them. Cached per size.
static func wave_mesh(half_width: float, height: float, depth: float, taper: float, wake: float) -> ArrayMesh:
	var key: String = "%.3f/%.3f/%.3f/%.3f/%.3f" % [half_width, height, depth, taper, wake]
	if _wave_meshes.has(key):
		return _wave_meshes[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var span: float = half_width + taper
	var xs: Array[float] = [-span, -half_width, half_width, span]
	var profile: int = 8
	var rows: Array = []
	for x: float in xs:
		var s: float = 1.0 if absf(x) <= half_width + 0.0001 else 0.0
		var row: Array[Vector3] = []
		for i: int in profile + 1:
			var phi: float = PI * float(i) / profile
			row.append(Vector3(x, height * sin(phi) * s, depth * 0.5 * cos(phi) * s))
		rows.append(row)
	for c: int in xs.size() - 1:
		var r0: Array[Vector3] = rows[c]
		var r1: Array[Vector3] = rows[c + 1]
		for i: int in profile:
			var quad: Array[Vector3] = [r0[i], r1[i], r1[i + 1], r0[i + 1]]
			for idx: int in [0, 1, 2, 0, 2, 3]:
				var v: Vector3 = quad[idx]
				# Corners 0 and 1 lie on the profile's point i, 2 and 3 on point i + 1.
				st.set_uv(Vector2((v.x + span) / (2.0 * span), float(i + (1 if idx >= 2 else 0)) / profile))
				st.set_uv2(Vector2(0.0, 0.0))
				st.add_vertex(v)
	# The wake: a strip on the floor behind the crest (toward -Z, away from the runner).
	var z0: float = -depth * 0.5
	var z1: float = z0 - wake
	var corners: Array[Vector3] = [Vector3(-half_width, 0.015, z0), Vector3(half_width, 0.015, z0),
		Vector3(half_width, 0.015, z1), Vector3(-half_width, 0.015, z1)]
	var uvs: Array[Vector2] = [Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0)]
	for idx: int in [0, 1, 2, 0, 2, 3]:
		st.set_uv(uvs[idx])
		st.set_uv2(Vector2(1.0, 0.0))
		st.add_vertex(corners[idx])
	var mesh: ArrayMesh = st.commit()
	_wave_meshes[key] = mesh
	return mesh


## Builds low-poly, flat-shaded triangles with the vertex data resonator.gdshader reads: the colour in
## COLOR.rgb, what it is in COLOR.a, metallic and roughness in UV. Each triangle is given the way it
## should face and wound for Godot's clockwise front faces.
class _Builder:
	extends RefCounted
	var st := SurfaceTool.new()

	func _init() -> void:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)

	func commit() -> ArrayMesh:
		return st.commit()

	## [colour, kind, metallic, roughness] for a named surface. The gold is polished but keeps some
	## diffuse colour, so it still reads as gold (not dark bronze) where there's little to reflect.
	static func look(kind: StringName) -> Array:
		match kind:
			&"ivory":
				return [IVORY, LIT, 0.0, 0.35]
			&"deep":
				return [GOLD_DEEP, LIT, 0.5, 0.45]
			&"trim":
				return [GOLD, TRIM, 0.5, 0.32]
			&"core":
				return [RED, CORE, 0.0, 0.3]
		return [GOLD, LIT, 0.5, 0.32]

	## A triangle facing `out`.
	func tri(a: Vector3, b: Vector3, c: Vector3, out: Vector3, kind: StringName) -> void:
		var n: Vector3 = (b - a).cross(c - a)
		if n.length_squared() < 1e-12:
			return
		if n.dot(out) > 0.0:
			var tmp: Vector3 = b
			b = c
			c = tmp
			n = -n
		var normal: Vector3 = -n.normalized()
		var l: Array = look(kind)
		for v: Vector3 in [a, b, c]:
			st.set_normal(normal)
			st.set_color(Color(l[0] as Color, float(l[1])))
			st.set_uv(Vector2(float(l[2]), float(l[3])))
			st.add_vertex(v)

	func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, out: Vector3, kind: StringName) -> void:
		tri(a, b, c, out, kind)
		tri(a, c, d, out, kind)

	## A faceted surface of revolution about +Y through [radius, height, kind] points.
	func lathe(points: Array) -> void:
		for i: int in points.size() - 1:
			var p0: Array = points[i]
			var p1: Array = points[i + 1]
			var r0: float = p0[0]
			var r1: float = p1[0]
			var y0: float = p0[1]
			var y1: float = p1[1]
			for f: int in FACETS:
				var a0: float = TAU * f / FACETS
				var a1: float = TAU * (f + 1) / FACETS
				var d0 := Vector3(cos(a0), 0.0, sin(a0))
				var d1 := Vector3(cos(a1), 0.0, sin(a1))
				var mid: Vector3 = (d0 + d1).normalized()
				# Outward: away from the axis, tipped up or down with the slope.
				var out: Vector3 = mid * absf(y1 - y0) + Vector3(0.0, (r0 - r1) * signf(y1 - y0), 0.0)
				if out.length_squared() < 1e-8:
					out = Vector3(0.0, signf(y0), 0.0)
				quad(d0 * r0 + Vector3(0.0, y0, 0.0), d1 * r0 + Vector3(0.0, y0, 0.0),
					d1 * r1 + Vector3(0.0, y1, 0.0), d0 * r1 + Vector3(0.0, y1, 0.0), out, p0[2])

	## A slim bar from `a` to `b`, `width` across and `depth` deep along `dir` (outward).
	func bar(a: Vector3, b: Vector3, dir: Vector3, width: float, depth: float, kind: StringName) -> void:
		var along: Vector3 = (b - a).normalized()
		var side: Vector3 = along.cross(dir).normalized() * width * 0.5
		var outv: Vector3 = side.cross(along).normalized()
		if outv.dot(dir) < 0.0:
			outv = -outv
		var o: Vector3 = outv * depth * 0.5
		var corners: Array[Vector3] = [side + o, -side + o, -side - o, side - o]
		for i: int in 4:
			var c0: Vector3 = corners[i]
			var c1: Vector3 = corners[(i + 1) % 4]
			var face_out: Vector3 = (c0 + c1).normalized()
			quad(a + c0, a + c1, b + c1, b + c0, face_out, kind)

	## A thin triangular fin along `dir`: from radius `r0` out to `r1`, between heights `y_root`
	## (its widest) and `y_tip`, `thickness` thick.
	func fin(dir: Vector3, r0: float, r1: float, y_root: float, y_tip: float, thickness: float, kind: StringName) -> void:
		var side: Vector3 = Vector3.UP.cross(dir).normalized() * thickness * 0.5
		var a: Vector3 = dir * r0 + Vector3(0.0, y_root, 0.0)
		var b: Vector3 = dir * r1 + Vector3(0.0, y_root + (y_tip - y_root) * 0.12, 0.0)
		var c: Vector3 = dir * r0 + Vector3(0.0, y_tip, 0.0)
		tri(a + side, b + side, c + side, side, kind)
		tri(a - side, b - side, c - side, -side, kind)
		var up: Vector3 = Vector3(0.0, signf(y_tip - y_root), 0.0)
		quad(a + side, a - side, b - side, b + side, dir - up * 0.5, kind)
		quad(b + side, b - side, c - side, c + side, dir + up, kind)

	## A six-sided bipyramid: `radius` round, `half_height` up and down from the middle.
	func bipyramid(radius: float, half_height: float, kind: StringName) -> void:
		var top := Vector3(0.0, half_height, 0.0)
		var bottom := Vector3(0.0, -half_height, 0.0)
		for f: int in FACETS:
			var a0: float = TAU * (f + 0.5) / FACETS
			var a1: float = TAU * (f + 1.5) / FACETS
			var p0 := Vector3(cos(a0), 0.0, sin(a0)) * radius
			var p1 := Vector3(cos(a1), 0.0, sin(a1)) * radius
			var mid: Vector3 = (p0 + p1) * 0.5
			tri(p0, p1, top, mid + Vector3(0.0, radius * 0.6, 0.0), kind)
			tri(p0, p1, bottom, mid - Vector3(0.0, radius * 0.6, 0.0), kind)

	## A box at `center`, `size` = (across, up, along `dir`), turned to face along `dir`.
	func box(center: Vector3, size: Vector3, dir: Vector3, kind: StringName) -> void:
		var z: Vector3 = dir.normalized()
		var x: Vector3 = Vector3.UP.cross(z).normalized()
		var basis := Basis(x * size.x * 0.5, Vector3.UP * size.y * 0.5, z * size.z * 0.5)
		var faces: Array[Vector3] = [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD]
		for n: Vector3 in faces:
			var u: Vector3 = Vector3(n.y, n.z, n.x)
			var v: Vector3 = n.cross(u)
			var c: Vector3 = center + basis * n
			quad(c + basis * (u + v), c + basis * (u - v), c + basis * (-u - v), c + basis * (-u + v), basis * n, kind)

	## An arc of a flat band in the XZ plane (axis +Y), from `r_in` to `r_out`, `half` thick, from
	## angle `a0` to `a1` in `segments`; the band's inner `trim` metres on both faces is the trim.
	func ring_arc(r_in: float, r_out: float, half: float, a0: float, a1: float, segments: int, trim: float) -> void:
		var r_mid: float = r_in + trim
		for s: int in segments:
			var t0: float = lerpf(a0, a1, float(s) / segments)
			var t1: float = lerpf(a0, a1, float(s + 1) / segments)
			var d0 := Vector3(cos(t0), 0.0, sin(t0))
			var d1 := Vector3(cos(t1), 0.0, sin(t1))
			for face: float in [1.0, -1.0]:
				var y := Vector3(0.0, half * face, 0.0)
				quad(d0 * r_in + y, d1 * r_in + y, d1 * r_mid + y, d0 * r_mid + y, y, &"trim")
				quad(d0 * r_mid + y, d1 * r_mid + y, d1 * r_out + y, d0 * r_out + y, y, &"gold")
			var up := Vector3(0.0, half, 0.0)
			var mid: Vector3 = (d0 + d1).normalized()
			quad(d0 * r_out + up, d1 * r_out + up, d1 * r_out - up, d0 * r_out - up, mid, &"gold")
			quad(d0 * r_in + up, d1 * r_in + up, d1 * r_in - up, d0 * r_in - up, -mid, &"deep")
