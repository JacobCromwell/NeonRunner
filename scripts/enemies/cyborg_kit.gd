extends RefCounted
## Shared art kit for the cyborg family and fence generators (procedural low-poly with emissive trim,
## CLAUDE.md Assets): flat-shaded tapered boxes and prisms with vertex colours merged into one surface
## (the generator, the window frame), the part, energy and cable shaders, the cyborgs' colours, and the
## pixel faces of their screen heads (drawn by cyborg_body.gdshader on the shared humanoid rig, see
## CyborgSuit). Meshes, materials and textures are cached, so every instance shares them. Visual only:
## nothing here touches collision or gameplay.
##
## Vertex colour alpha is the glow strength (0 = plain surface, 1 = full emissive trim).

## The screen faces (GDD §9.2: the screen is the face). DEAD is the "ERR" a defeated cyborg's screen
## shows before it goes dark; the two CORRUPT faces are the hosts' glitches (GDD §9.7).
enum Face { NEUTRAL, AIMING, SHOCKED, DEAD, CORRUPT_GRIN, CORRUPT_BROKEN }

## Enemy fire and the arm-cannon charge are hot red in every zone, like ProjectilePool's enemy looks.
const CHARGE_COLOR := Color(1.0, 0.15, 0.1)
## The screen faces glow cold white (GDD §9.2, changed from amber), so the enemies never share the
## player's copper glow (GDD §11). It is the cult feed's own cold white (CultFeed): the cyborgs'
## screens show the same broadcast's face (GDD §5, Cyborg Viewing Devices).
const LED_COLOR: Color = CultFeed.FEED_COLOR
## Hosts glitch with purple static and glowing veins (GDD §9.7), the Bad Dream's colour. On a cyborg,
## purple always and only means "host".
const GLITCH_COLOR := Color(0.72, 0.25, 1.0)
## Electric-fence pink (GDD §9.1: pink crackle = fence); a skin's own fence_color wins when it has one.
const FENCE_PINK := Color(1.0, 0.18, 0.62)

## The faces' pixel grid: square cells on the screen head's 0.33 × 0.23 m screen. The features are big
## and bold (eyes three LEDs across, the "O" two thick, the brows running in from the corners) so each
## face keeps its own shape when the screen is only about 7 × 5 pixels, as it is 14 m ahead of the
## player at 720p: two eyes and a bar, a V and a long bar, two eyes over a ring.
## DESIGN-TBD (docs/questions/p2.md 2): the faces' pixel art.
const FACE_GRID := Vector2i(13, 9)
const FACES: Dictionary = {
	# Calm, like the cult feed's face (CultFeed): two eyes and a flat mouth.
	Face.NEUTRAL: [
		".............",
		"..###...###..",
		"..###...###..",
		"..###...###..",
		".............",
		".............",
		"...#######...",
		".............",
		".............",
	],
	# Charging the cannon: brows slanted down from the corners into narrowed eyes, the mouth a long,
	# hard line.
	Face.AIMING: [
		"##.........##",
		".###.....###.",
		"..###...###..",
		".............",
		".............",
		".............",
		".###########.",
		".............",
		".............",
	],
	# The panic variant's shocked "O" (GDD §9.2): wide, staring eyes over a big round mouth.
	Face.SHOCKED: [
		".###.....###.",
		".#.#.....#.#.",
		".###.....###.",
		"....#####....",
		"...##...##...",
		"..##.....##..",
		"..##.....##..",
		"...##...##...",
		"....#####....",
	],
	# Defeated: ERR, then the screen goes dark (CyborgBody.die).
	Face.DEAD: [
		".............",
		".............",
		".###.###.###.",
		".#...#.#.#.#.",
		".###.##..##..",
		".#...#.#.#.#.",
		".###.#.#.#.#.",
		".............",
		".............",
	],
	Face.CORRUPT_GRIN: [
		".............",
		"..###...###..",
		"..###...###..",
		".............",
		"#...........#",
		"##.........##",
		".###########.",
		".............",
		".............",
	],
	Face.CORRUPT_BROKEN: [
		".............",
		".####...#....",
		".#..#..###...",
		".####...#....",
		".............",
		".#.#.#.#.#.#.",
		"#.#.#.#.#.#.#",
		".............",
		".............",
	],
}

## The same faces redrawn for the wide VR visor of the Corporate zone's variant (the "Wide-Aspect VR"
## Runner, CyborgSuit's &"vr_runner" look): square cells on its 0.38 × 0.14 m visor. Each keeps its
## face's features and where they sit, spread across the wide shape: the eyes far apart, the shocked
## "O" between them, ERR in the middle. At gameplay distance (14 m ahead at 720p) the visor is about
## 8 × 3 pixels, where the three faces still differ: two blocks over a short bar, two slants over a
## long bar, a bright middle between two rings.
## DESIGN-TBD (docs/questions/p3.md 4): the visor faces' pixel art.
const VISOR_GRID := Vector2i(19, 7)
const VISOR_FACES: Dictionary = {
	Face.NEUTRAL: [
		"...................",
		"...####.....####...",
		"...####.....####...",
		"...####.....####...",
		"...................",
		"......#######......",
		"...................",
	],
	Face.AIMING: [
		".##.............##.",
		"..###.........###..",
		"...####.....####...",
		"...................",
		"...................",
		"..###############..",
		"...................",
	],
	Face.SHOCKED: [
		"........###........",
		".###...##.##...###.",
		".#.#..##...##..#.#.",
		".###..##...##..###.",
		"......##...##......",
		".......##.##.......",
		"........###........",
	],
	Face.DEAD: [
		"...................",
		"....###.###.###....",
		"....#...#.#.#.#....",
		"....###.##..##.....",
		"....#...#.#.#.#....",
		"....###.#.#.#.#....",
		"...................",
	],
	Face.CORRUPT_GRIN: [
		"...................",
		"...####.....####...",
		"...####.....####...",
		"...................",
		"#.................#",
		"##...............##",
		".#################.",
	],
	Face.CORRUPT_BROKEN: [
		"...................",
		".####.....#........",
		".#..#....###.......",
		".####.....#........",
		"...................",
		".#.#.#.#.#.#.#.#.#.",
		"#.#.#.#.#.#.#.#.#.#",
	],
}

## The builder stores vertex colours in linear space (Builder._color), which Forward+ and Mobile light
## in; on the Compatibility renderer (web, low-end Android) humanoid_color.gdshaderinc turns them back
## to sRGB, as for the humanoid rig. Without it the generator and the window frame show far too dark
## and saturated on the web.
const PART_SHADER: String = """
shader_type spatial;
render_mode cull_back;
#include "res://scripts/characters/humanoid_color.gdshaderinc"
uniform float roughness : hint_range(0.0, 1.0) = 0.42;
uniform float metallic : hint_range(0.0, 1.0) = 0.12;
uniform float glow_energy = 2.6;
// Hit flash (white) and death (dark) reuse the same meshes with another material.
uniform vec4 tint : source_color = vec4(1.0);
uniform float tint_amount : hint_range(0.0, 1.0) = 0.0;
uniform float tint_glow = 0.0;
void fragment() {
	vec3 base = humanoid_base_color(COLOR.rgb);
	ALBEDO = mix(base, tint.rgb, tint_amount);
	ROUGHNESS = roughness;
	METALLIC = metallic;
	EMISSION = base * COLOR.a * glow_energy * (1.0 - tint_amount) + tint.rgb * tint_glow;
}
"""

## Pulsing hazard energy (the fence generator's coils and exhaust glow).
const ENERGY_SHADER: String = """
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
uniform vec4 color : source_color = vec4(1.0, 0.18, 0.62, 1.0);
uniform float energy = 3.0;
uniform float pulse_speed = 5.0;
void fragment() {
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float p = 0.62 + 0.38 * sin(TIME * pulse_speed - wp.y * 9.0);
	ALBEDO = color.rgb * energy * p;
}
"""

## A power cable's glowing core, pulses travelling away from `origin` (the generator) toward the
## fences it feeds: along the track first, then sideways.
const CABLE_SHADER: String = """
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
uniform vec4 color : source_color = vec4(1.0, 0.18, 0.62, 1.0);
uniform vec3 origin = vec3(0.0);
uniform float energy = 2.2;
uniform float speed = 2.2;
void fragment() {
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float along = (origin.z - wp.z) + abs(wp.x - origin.x);
	float pulse = smoothstep(0.55, 1.0, fract(along * 0.45 - TIME * speed));
	ALBEDO = color.rgb * energy * (0.35 + 1.4 * pulse);
}
"""

static var _meshes: Dictionary = {}
static var _materials: Dictionary = {}
static var _shaders: Dictionary = {}
static var _faces: Dictionary = {}


## Builds one flat-shaded mesh from boxes and prisms. Colours are given in sRGB like any material
## colour; `glow` (0–1) makes a piece emissive trim.
class Builder:
	var st := SurfaceTool.new()

	func _init() -> void:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)

	## A box centred at `center` with `size`; `taper` scales the top face's x and z (1 = straight).
	func box(center: Vector3, size: Vector3, color: Color, glow: float = 0.0,
			taper: Vector2 = Vector2.ONE, rot: Basis = Basis.IDENTITY) -> Builder:
		var hx: float = size.x * 0.5
		var hy: float = size.y * 0.5
		var hz: float = size.z * 0.5
		var tx: float = hx * taper.x
		var tz: float = hz * taper.y
		var p: Array[Vector3] = [
			Vector3(-hx, -hy, -hz), Vector3(hx, -hy, -hz), Vector3(hx, -hy, hz), Vector3(-hx, -hy, hz),
			Vector3(-tx, hy, -tz), Vector3(tx, hy, -tz), Vector3(tx, hy, tz), Vector3(-tx, hy, tz)]
		for i: int in p.size():
			p[i] = center + rot * p[i]
		var c := _color(color, glow)
		for q: Array in [[0, 1, 2, 3], [4, 5, 6, 7], [0, 1, 5, 4], [3, 2, 6, 7], [0, 3, 7, 4], [1, 2, 6, 5]]:
			_quad(p[q[0]], p[q[1]], p[q[2]], p[q[3]], center, c)
		return self

	## An upright prism with `sides` faces (a low-poly cylinder), centred at `center`.
	func prism(center: Vector3, radius: float, height: float, sides: int, color: Color,
			glow: float = 0.0, top_scale: float = 1.0, rot: Basis = Basis.IDENTITY) -> Builder:
		var c := _color(color, glow)
		var bottom: Array[Vector3] = []
		var top: Array[Vector3] = []
		for i: int in sides:
			var a: float = TAU * (i + 0.5) / sides
			var d := Vector3(cos(a), 0.0, sin(a)) * radius
			bottom.append(center + rot * (d + Vector3(0.0, -height * 0.5, 0.0)))
			top.append(center + rot * (d * top_scale + Vector3(0.0, height * 0.5, 0.0)))
		for i: int in sides:
			var j: int = (i + 1) % sides
			_quad(bottom[i], bottom[j], top[j], top[i], center, c)
		var cb: Vector3 = center + rot * Vector3(0.0, -height * 0.5, 0.0)
		var ct: Vector3 = center + rot * Vector3(0.0, height * 0.5, 0.0)
		for i: int in sides:
			var j: int = (i + 1) % sides
			_tri(cb, bottom[i], bottom[j], center, c)
			_tri(ct, top[i], top[j], center, c)
		return self

	func commit() -> ArrayMesh:
		return st.commit()

	func _color(color: Color, glow: float) -> Color:
		var lin: Color = color.srgb_to_linear()
		return Color(lin.r, lin.g, lin.b, clampf(glow, 0.0, 1.0))

	func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, inside: Vector3, col: Color) -> void:
		_tri(a, b, c, inside, col)
		_tri(a, c, d, inside, col)

	## One flat-shaded triangle facing away from `inside`. Godot's front faces wind clockwise.
	func _tri(a: Vector3, b: Vector3, c: Vector3, inside: Vector3, col: Color) -> void:
		var n: Vector3 = (b - a).cross(c - a)
		if n.length_squared() < 1e-12:
			return
		n = n.normalized()
		var outward: Vector3 = (a + b + c) / 3.0 - inside
		if n.dot(outward) < 0.0:
			n = -n
		if (b - a).cross(c - a).dot(n) > 0.0:
			var tmp: Vector3 = b
			b = c
			c = tmp
		for v: Vector3 in [a, b, c]:
			st.set_normal(n)
			st.set_color(col)
			st.add_vertex(v)


## A cached mesh: `build` (a Callable returning an ArrayMesh) runs once per key.
static func mesh(key: String, build: Callable) -> ArrayMesh:
	if not _meshes.has(key):
		_meshes[key] = build.call()
	return _meshes[key]


static func shader(code_key: String) -> Shader:
	if not _shaders.has(code_key):
		var s := Shader.new()
		match code_key:
			"part":
				s.code = PART_SHADER
			"energy":
				s.code = ENERGY_SHADER
			"cable":
				s.code = CABLE_SHADER
		_shaders[code_key] = s
	return _shaders[code_key]


## The body material: vertex colours with glowing trim. `state`: &"normal", &"flash" (hit),
## &"flash_soft" (hit, with Settings > Reduced flashing), &"dead".
static func part_material(state: StringName = &"normal") -> ShaderMaterial:
	var key: String = "part_" + String(state)
	if not _materials.has(key):
		var m := ShaderMaterial.new()
		m.shader = shader("part")
		match state:
			&"flash":
				m.set_shader_parameter(&"tint", Color(1.0, 0.95, 0.9))
				m.set_shader_parameter(&"tint_amount", 0.75)
				m.set_shader_parameter(&"tint_glow", 1.2)
			&"flash_soft":
				m.set_shader_parameter(&"tint", Color(1.0, 0.95, 0.9))
				m.set_shader_parameter(&"tint_amount", 0.3)
				m.set_shader_parameter(&"tint_glow", 0.4)
			&"dead":
				m.set_shader_parameter(&"tint", Color(0.03, 0.03, 0.035))
				m.set_shader_parameter(&"tint_amount", 0.55)
		_materials[key] = m
	return _materials[key]


## The pulsing energy material in `color` (shared by every generator of that colour).
static func energy_material(color: Color) -> ShaderMaterial:
	var key: String = "energy_" + color.to_html()
	if not _materials.has(key):
		var m := ShaderMaterial.new()
		m.shader = shader("energy")
		m.set_shader_parameter(&"color", color)
		_materials[key] = m
	return _materials[key]


## The pixel image of a face (white = LED on), cached. Its mipmaps let the shader average the face far
## away, where an LED is smaller than a pixel. `visor`: the wide VR visor's version (VISOR_FACES).
static func face_texture(face: Face, visor: bool = false) -> ImageTexture:
	var key: int = int(face) + (100 if visor else 0)
	if not _faces.has(key):
		var rows: Array = face_rows(face, visor)
		var grid: Vector2i = VISOR_GRID if visor else FACE_GRID
		var img := Image.create(grid.x, grid.y, false, Image.FORMAT_L8)
		for y: int in grid.y:
			var row: String = rows[y]
			for x: int in grid.x:
				img.set_pixel(x, y, Color.WHITE if row[x] == "#" else Color.BLACK)
		img.generate_mipmaps()
		_faces[key] = ImageTexture.create_from_image(img)
	return _faces[key]


## A face's pixel rows ("#" = LED on) on the TV screen's grid, or on the visor's.
static func face_rows(face: Face, visor: bool = false) -> Array:
	return VISOR_FACES[face] if visor else FACES[face]
