extends TestSuite
## D7: CultEmblem builds valid geometry, meshes and textures for every option (A-D), the same way
## every time, and its neon (glowing) colours keep clear of the hazard and UI hues (GDD §5), the way
## test_ui_kit.gd checks the UI palette.

const SIZES: Array[float] = [0.4, 1.0, 3.2]
const PIXEL_SIZES: Array[int] = [16, 63, 128]


func run() -> void:
	_test_geometry()
	_test_mesh()
	_test_mesh_determinism()
	_test_texture()
	_test_texture_determinism()
	_test_default_scheme()
	_test_palette()
	_test_labels()


func _test_geometry() -> void:
	for option: int in CultEmblem.OPTION_COUNT:
		var parts: Array[Dictionary] = CultEmblem.geometry(option)
		check(not parts.is_empty(), "option %s has geometry" % CultEmblem.option_letter(option))
		var has_accent: bool = false
		for part: Dictionary in parts:
			var kind: String = part.get("kind", "")
			check(kind == "stroke" or kind == "poly", "option %s: part kind '%s' is valid" % [CultEmblem.option_letter(option), kind])
			var points: PackedVector2Array = part.get("points", PackedVector2Array())
			if kind == "stroke":
				check(points.size() >= 1, "option %s: a stroke has at least one point" % CultEmblem.option_letter(option))
				check(part.get("width", 0.0) > 0.0, "option %s: a stroke has positive width" % CultEmblem.option_letter(option))
			else:
				check(points.size() >= 3, "option %s: a poly has at least three points" % CultEmblem.option_letter(option))
			for p: Vector2 in points:
				check(absf(p.x) <= 0.55 and absf(p.y) <= 0.55, "option %s: point %s stays near the unit square" % [CultEmblem.option_letter(option), p])
			has_accent = has_accent or bool(part.get("accent", false))
		check(has_accent, "option %s has a small accent detail" % CultEmblem.option_letter(option))
		check(CultEmblem.geometry(option) == parts, "option %s's geometry is the same every call" % CultEmblem.option_letter(option))


func _test_mesh() -> void:
	var material := MeshKit.solid()
	for option: int in CultEmblem.OPTION_COUNT:
		var prev_extent: float = 0.0
		for size: float in SIZES:
			var mesh: ArrayMesh = CultEmblem.build_mesh(option, size, Color.WHITE, Color(1.0, 0.4, 0.4), 1.0, material)
			check(mesh != null and mesh.get_surface_count() == 1, "option %s at %.1fm builds one surface" % [CultEmblem.option_letter(option), size])
			var arrays: Array = mesh.surface_get_arrays(0)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			check(verts.size() > 0 and verts.size() % 3 == 0, "option %s at %.1fm is whole triangles (%d verts)" % [CultEmblem.option_letter(option), size, verts.size()])
			var extent: float = 0.0
			for v: Vector3 in verts:
				check(is_equal_approx(v.z, 0.0), "option %s stays flat (z = %.4f)" % [CultEmblem.option_letter(option), v.z])
				extent = maxf(extent, maxf(absf(v.x), absf(v.y)))
			check(extent > 0.0 and extent <= size * 0.6, "option %s at %.1fm fits its size (extent %.2f)" % [CultEmblem.option_letter(option), size, extent])
			check(extent > prev_extent, "option %s grows with size" % CultEmblem.option_letter(option))
			prev_extent = extent
		check(CultEmblem.build_mesh(option, 1.0, Color.WHITE, Color(1.0, 0.4, 0.4), 1.0, material)
			== CultEmblem.build_mesh(option, 1.0, Color.WHITE, Color(1.0, 0.4, 0.4), 1.0, material),
			"option %s's mesh is cached (same call, same mesh)" % CultEmblem.option_letter(option))
	# Following the mesh kit's convention: glow > 0 is emissive (COLOR.a), glow 0 a lit surface.
	var lit: ArrayMesh = CultEmblem.build_mesh(CultEmblem.Option.A, 1.0, Color(0.5, 0.5, 0.5), Color(0.5, 0.5, 0.5), 0.0, material)
	var glowing: ArrayMesh = CultEmblem.build_mesh(CultEmblem.Option.A, 1.0, Color(0.5, 0.5, 0.5), Color(0.5, 0.5, 0.5), 1.0, material)
	var lit_colors: PackedColorArray = lit.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var glow_colors: PackedColorArray = glowing.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	check(is_equal_approx(lit_colors[0].a, 0.0) and is_equal_approx(glow_colors[0].a, 1.0),
		"glow amount lands in the vertex colour's alpha (mesh kit convention)")


## Two independent builds (different material instances, so neither can hit the mesh cache) of the
## same option and arguments produce identical vertex data: build_mesh() has no hidden randomness.
func _test_mesh_determinism() -> void:
	for option: int in CultEmblem.OPTION_COUNT:
		var a: ArrayMesh = CultEmblem.build_mesh(option, 2.0, Color(0.2, 0.8, 0.6), Color(0.9, 0.2, 0.2), 0.5, StandardMaterial3D.new())
		var b: ArrayMesh = CultEmblem.build_mesh(option, 2.0, Color(0.2, 0.8, 0.6), Color(0.9, 0.2, 0.2), 0.5, StandardMaterial3D.new())
		var av: PackedVector3Array = a.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var bv: PackedVector3Array = b.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		check(av == bv, "option %s builds the same vertices from two fresh materials" % CultEmblem.option_letter(option))


func _test_texture() -> void:
	var bg := Color(0.02, 0.02, 0.03, 0.0)
	for option: int in CultEmblem.OPTION_COUNT:
		for glow: bool in [false, true]:
			for pixels: int in PIXEL_SIZES:
				var scheme: Dictionary = CultEmblem.default_scheme(option)
				var img: Image = CultEmblem.build_image(option, pixels, scheme["neon"], scheme["neon_accent"], bg, glow)
				var tag: String = "glowing" if glow else "flat"
				check(img != null and img.get_width() == pixels and img.get_height() == pixels,
					"option %s %s at %dpx is the right size" % [CultEmblem.option_letter(option), tag, pixels])
				# Alpha, not exact colour, is the "ink vs background" signal: FORMAT_RGBA8 quantises
				# an untouched pixel's RGB away from the exact bg float, even though its alpha stays 0.
				var coverage: float = _coverage(img)
				check(coverage > 0.0, "option %s %s at %dpx draws something (%.0f%% covered)" % [CultEmblem.option_letter(option), tag, pixels, coverage * 100.0])
				if not glow:
					# A flat mark has a fixed ~1 px antialiasing band, so it never washes out, however
					# small the canvas; a glowing one's soft halo can legitimately fill a tiny canvas.
					check(coverage < 0.85, "option %s flat at %dpx doesn't fill the canvas (%.0f%%)" % [CultEmblem.option_letter(option), pixels, coverage * 100.0])
					check(_has_transparent_pixel(img), "option %s flat at %dpx keeps a transparent decal background" % [CultEmblem.option_letter(option), pixels])
				if pixels >= 63:
					# Below this, an option's thinnest accent detail can be sub-pixel; only require it
					# to actually resolve once the canvas is big enough to hold it.
					check(_has_pixel_near(img, scheme["neon_accent"], 0.08), "option %s %s at %dpx paints its accent colour somewhere" % [CultEmblem.option_letter(option), tag, pixels])
		var texture: ImageTexture = CultEmblem.build_texture(option, 64, Color.WHITE, Color.WHITE, bg)
		check(texture != null and texture.get_width() == 64 and texture.get_height() == 64, "option %s builds an ImageTexture" % CultEmblem.option_letter(option))


func _test_texture_determinism() -> void:
	var bg := Color(0.0, 0.0, 0.0, 0.0)
	for option: int in CultEmblem.OPTION_COUNT:
		for pixels: int in [17, 64]:
			var a: Image = CultEmblem.build_image(option, pixels, Color(0.8, 0.5, 0.9), Color(0.9, 0.9, 0.2), bg, true)
			var b: Image = CultEmblem.build_image(option, pixels, Color(0.8, 0.5, 0.9), Color(0.9, 0.9, 0.2), bg, true)
			check(a.get_data() == b.get_data(), "option %s rasterises %dpx identically every time" % [CultEmblem.option_letter(option), pixels])


func _test_default_scheme() -> void:
	for option: int in CultEmblem.OPTION_COUNT:
		var scheme: Dictionary = CultEmblem.default_scheme(option)
		for key: String in ["neon", "neon_accent", "metal", "metal_accent"]:
			check(scheme.has(key) and scheme[key] is Color, "option %s's scheme has %s" % [CultEmblem.option_letter(option), key])
	check(CultEmblem.GOLD_COLOR.v > CultEmblem.GOLD_ACCENT_COLOR.v, "the Golden Zone's gold reads brighter than its red accent")


## The neon (glowing) colours must not be mistaken for a hazard or the UI's accents (GDD §5;
## test_ui_kit.gd checks the UI palette the same way). Non-glowing metal/gold may sit close to a
## hazard hue (GDD's own colour rule for Golden Zone red and gold), so only neon colours are checked.
func _test_palette() -> void:
	var skin := GreyboxSkin.new()
	var style: UiStyle = UiTheme.style()
	var reserved: Dictionary = {"fence pink": skin.fence_color, "gap orange": skin.gap_edge_color, "sign yellow": skin.sign_color}
	var gameplay: Dictionary = {"pad cyan": skin.pad_color, "ramp green": skin.ramp_color,
		"UI accent": style.accent, "UI accent_2": style.accent_2}
	for option: int in CultEmblem.OPTION_COUNT:
		var scheme: Dictionary = CultEmblem.default_scheme(option)
		for key: String in ["neon", "neon_accent"]:
			var color: Color = scheme[key]
			for hazard: String in reserved:
				var far: bool = color.s < 0.2 or _hue_distance(color, reserved[hazard]) >= 0.08
				check(far, "option %s's %s stays clear of the %s" % [CultEmblem.option_letter(option), key, hazard])
			for piece: String in gameplay:
				check(color.s < 0.2 or _hue_distance(color, gameplay[piece]) >= 0.05,
					"option %s's %s is distinct from %s" % [CultEmblem.option_letter(option), key, piece])


func _test_labels() -> void:
	var letters: Dictionary = {}
	var titles: Dictionary = {}
	for option: int in CultEmblem.OPTION_COUNT:
		letters[CultEmblem.option_letter(option)] = true
		titles[CultEmblem.option_title(option)] = true
	check(letters.size() == CultEmblem.OPTION_COUNT, "every option has its own letter")
	check(titles.size() == CultEmblem.OPTION_COUNT, "every option has its own title")
	check(CultEmblem.option_letter(-3) == CultEmblem.option_letter(0), "an out-of-range option clamps low")
	check(CultEmblem.option_letter(99) == CultEmblem.option_letter(CultEmblem.OPTION_COUNT - 1), "and clamps high")


# --- Helpers -------------------------------------------------------------------

func _hue_distance(a: Color, b: Color) -> float:
	var d: float = absf(a.h - b.h)
	return minf(d, 1.0 - d)


## Share of pixels with any paint on them. Alpha, not exact colour, is the signal: FORMAT_RGBA8
## quantises every pixel's RGB to 8 bits, so even an untouched pixel's RGB drifts from the exact
## background float it was cleared to.
func _coverage(image: Image) -> float:
	var painted: int = 0
	for y: int in image.get_height():
		for x: int in image.get_width():
			if image.get_pixel(x, y).a > 0.05:
				painted += 1
	return float(painted) / (image.get_width() * image.get_height())


func _has_transparent_pixel(image: Image) -> bool:
	for y: int in image.get_height():
		for x: int in image.get_width():
			if image.get_pixel(x, y).a < 0.05:
				return true
	return false


func _has_pixel_near(image: Image, target: Color, tol: float) -> bool:
	for y: int in image.get_height():
		for x: int in image.get_width():
			var c: Color = image.get_pixel(x, y)
			if absf(c.r - target.r) < tol and absf(c.g - target.g) < tol and absf(c.b - target.b) < tol and c.a > 0.5:
				return true
	return false
