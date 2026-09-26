class_name CultFeed
extends RefCounted
## The cult's feed (GDD §5, "Cyborg Viewing Devices", decided September 26, 2026): the cult's
## philosophy reaches people through their screens, and its order to attack the runner reaches the
## screen-head cyborgs the same way. Every zone tells it without words: the same broadcast plays on
## billboards, ads and TVs in shop windows, alongside the ordinary ads. One shared piece for every
## skin: a shader-driven material (cult_feed.gdshader, the picture in cult_feed.gdshaderinc) that is
## cheap and works on the Compatibility renderer, and a helper that adds a screen to a mesh layer.
## Every screen shows the same moment of the same loop (the shader runs on TIME), so the broadcast
## plays in sync everywhere.
## DESIGN-TBD (docs/questions/d2.md): what the feed shows. Placeholder: a CRT picture in cold white
## echoing the cyborgs' screen heads (task P2), with scanlines, soft static and a slow rolling bar,
## looping through a screen-head face, the cult's emblem (CultEmblem, the owner's choice, read from
## data/world/cult_emblem_choice.tres) and rings converging on one point.
## Rules it keeps: it glows only in cold white and the emblem's warm white (no hazard hue, not the
## player's copper), nothing strobes (slow cross-fades; Reduced flashing stills the static and the
## rolling bar), and it never glitches purple (that is the hosts' sign).
##
## Using it in a skin (the screen's front faces the viewer, u to their right, v up):
##   var feed: MeshLayer = batch.layer(CultFeed.material())
##   CultFeed.screen(feed, lower_left, Vector3(width, 0, 0), Vector3(0, height, 0))
## A screen needs a frame or a bezel of its own (the material draws only the picture), and the
## material adds one mesh surface wherever a chunk has screens. Nothing about it is zone-specific:
## keep it the same broadcast everywhere, and vary how many screens show it and where.

const SHADER_FILE: String = "cult_feed.gdshader"
const CHOICE_PATH: String = "res://data/world/cult_emblem_choice.tres"
## The emblem is rasterised once at this size (with mipmaps) for every screen.
const EMBLEM_PIXELS: int = 128
## The feed's colours: cold white on a dim cold screen, and the emblem in its own warm white
## (CultEmblem.default_scheme).
const FEED_COLOR := Color(0.86, 0.91, 1.0)
const DARK_COLOR := Color(0.16, 0.18, 0.21)

static var _emblem_texture: ImageTexture
static var _materials: Dictionary = {}


## The feed's material, shared by every skin asking for the same brightness: how far above the bloom
## threshold its brightest parts glow.
static func material(brightness: float = 2.2) -> ShaderMaterial:
	var m: ShaderMaterial = _materials.get(brightness)
	if m == null:
		m = MeshKit.material(SHADER_FILE, {"feed_brightness": brightness, "feed_color": FEED_COLOR,
			"feed_dark": DARK_COLOR, "feed_emblem_color": emblem_color()})
		m.set_shader_parameter("feed_emblem", emblem_texture())
		_materials[brightness] = m
	return m


## Adds a screen showing the feed: a rectangle from `origin` spanning `u` (its width, to the viewer's
## right) and `v` (its height, up), facing u × v. `brightness` (0-1) dims a screen (say, a small TV
## in a shop window next to a billboard); `seed` varies its static.
static func screen(layer: MeshLayer, origin: Vector3, u: Vector3, v: Vector3, brightness: float = 1.0,
		seed: int = 0) -> void:
	var aspect: float = u.length() / maxf(v.length(), 0.001)
	layer.rect(origin, u, v, Color.WHITE, clampf(brightness, 0.0, 1.0), posmod(seed, 997), Vector2.ZERO, Vector2.ONE, aspect)


## The warm white the emblem glows in on the feed: the chosen option's own neon.
static func emblem_color() -> Color:
	return CultEmblem.default_scheme(emblem_option())["neon"]


## The owner's choice of emblem (data/world/cult_emblem_choice.tres), never hardcoded.
static func emblem_option() -> int:
	var choice := load(CHOICE_PATH) as CultEmblemChoice
	return choice.option if choice != null else CultEmblem.Option.B


## The chosen emblem's coverage (white, alpha = coverage), with mipmaps, built once.
static func emblem_texture() -> ImageTexture:
	if _emblem_texture == null:
		var img: Image = CultEmblem.build_image(emblem_option(), EMBLEM_PIXELS, Color.WHITE, Color.WHITE,
			Color(1.0, 1.0, 1.0, 0.0))
		img.generate_mipmaps()
		_emblem_texture = ImageTexture.create_from_image(img)
	return _emblem_texture
