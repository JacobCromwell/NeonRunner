extends TestSuite
## The cult's feed (CultFeed, GDD §5 "Cyborg Viewing Devices"), the shared piece every skin puts on
## its screens: one material per brightness, shared, carrying the owner's chosen emblem; it glows
## only in cold white and the emblem's warm white (far from every hazard hue, the pads' cyan, the
## ramps' green, the player's copper, and the hosts' purple); its shader honours Reduced flashing;
## and a screen is one rectangle with its aspect for the picture.

const INCLUDE_PATH: String = "res://scripts/world/meshes/shaders/cult_feed.gdshaderinc"
## GDD §11: the player's soft copper glow (task P1 builds it; an approximation, for the hue).
const PLAYER_COPPER := Color(0.78, 0.47, 0.28)
## The hosts' glitch purple (GDD §9.2): purple on a screen means "host".
const HOST_PURPLE := Color(0.62, 0.3, 0.95)


func run() -> void:
	_material()
	_colours()
	_screen()
	_shader_rules()


func _material() -> void:
	var m: ShaderMaterial = CultFeed.material()
	check(m != null and m.shader != null and m.shader.resource_path.ends_with("cult_feed.gdshader"),
		"the feed is its own shader material")
	check(CultFeed.material() == m, "every screen shares one feed material")
	var choice := load(CultFeed.CHOICE_PATH) as CultEmblemChoice
	check(choice != null and CultFeed.emblem_option() == choice.option, "the feed shows the owner's chosen emblem")
	check(CultFeed.emblem_color() == CultEmblem.default_scheme(choice.option)["neon"],
		"in its own warm-white neon (CultEmblem.default_scheme)")
	var tex := m.get_shader_parameter("feed_emblem") as ImageTexture
	check(tex != null and tex == CultFeed.emblem_texture(), "the material carries the emblem texture")
	if tex == null:
		return
	var img: Image = tex.get_image()
	var n: int = CultFeed.EMBLEM_PIXELS
	check(img.get_width() == n and img.has_mipmaps(), "the emblem is rasterised at %d px with mipmaps" % n)
	var covered: int = 0
	for y: int in range(0, n, 4):
		for x: int in range(0, n, 4):
			if img.get_pixel(x, y).a > 0.5:
				covered += 1
	check(img.get_pixel(0, 0).a == 0.0 and covered > 20, "the emblem is drawn in alpha on a clear square (%d samples)" % covered)


func _colours() -> void:
	var skin := GreyboxSkin.new()
	var avoid: Dictionary = {"fence pink": skin.fence_color, "gap orange": skin.gap_edge_color,
		"sign yellow": skin.sign_color, "pad cyan": skin.pad_color, "ramp green": skin.ramp_color,
		"the player's copper": PLAYER_COPPER, "host purple": HOST_PURPLE}
	var m: ShaderMaterial = CultFeed.material()
	var colours: Dictionary = {"cold white": CultFeed.FEED_COLOR, "the emblem's warm white": CultFeed.emblem_color(),
		"the dim screen": m.get_shader_parameter("feed_dark")}
	check(colours["the dim screen"] != Color.BLACK, "the dim screen's colour is read from the shader")
	for name: String in colours:
		var c: Color = colours[name]
		check(c.s < 0.25, "the feed's %s is nearly white (saturation %.2f)" % [name, c.s])
		for other: String in avoid:
			check(c.s < 0.2 or _hue_distance(c, avoid[other]) >= 0.08, "the feed's %s stays clear of %s" % [name, other])


func _screen() -> void:
	var layer := MeshLayer.new()
	CultFeed.screen(layer, Vector3(1, 2, 3), Vector3(0, 0, -6), Vector3(0, 2, 0), 0.5, 42)
	check(layer.verts.size() == 6, "a screen is one rectangle")
	var ok: bool = true
	for i: int in 6:
		ok = ok and is_equal_approx(layer.uv2s[i].y, 3.0) and is_equal_approx(layer.colors[i].a, 0.5)
		ok = ok and layer.uvs[i].x >= 0.0 and layer.uvs[i].x <= 1.0 and layer.uvs[i].y >= 0.0 and layer.uvs[i].y <= 1.0
	check(ok, "it carries its aspect (width / height) and brightness, with UV 0-1 over it")
	var normal: Vector3 = (layer.verts[1] - layer.verts[0]).cross(layer.verts[2] - layer.verts[0]).normalized()
	check(normal.is_equal_approx(Vector3(0, 0, -6).cross(Vector3(0, 2, 0)).normalized()) or
		normal.is_equal_approx(-Vector3(0, 0, -6).cross(Vector3(0, 2, 0)).normalized()), "it lies in the plane given")


## The picture's rules, read from its source: Reduced flashing stills the static and the rolling bar,
## the phases fade (no cuts), and there is no glitch or purple in it (hosts only).
func _shader_rules() -> void:
	var code: String = FileAccess.get_file_as_string(INCLUDE_PATH)
	check(code.count("reduced_flashing") >= 2, "the static and the rolling bar hold still with Reduced flashing")
	check(code.contains("cf_window") and code.contains("smoothstep(a, a + f, k)"), "the broadcast's phases fade in and out")
	var lower: String = code.to_lower()
	check(not lower.contains("glitch(") and not lower.contains("purple ="), "no glitching and no purple in the feed")
	var shader_code: String = CultFeed.material().shader.code
	check(shader_code.contains("kit_flash.gdshaderinc"), "the feed shader reads the Reduced flashing setting")


static func _hue_distance(a: Color, b: Color) -> float:
	var d: float = absf(a.h - b.h)
	return minf(d, 1.0 - d)
