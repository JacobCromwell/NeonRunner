class_name WindowDisplay
extends RefCounted
## The shop windows' ad screens and posters (task L10; GDD §5 "Cyborg Viewing Devices", the owner's October 17, 2026
## decision: no feed TVs in the shop windows): the Marketplace's and the Casino's own small material
## (window_display.gdshader, the pictures in window_display.gdshaderinc) and the helper that adds a panel's face to a
## mesh layer, as CultFeed does for the feed. A material of its own rather than a pattern of the solid kit shader: that
## shader is compiled by every zone, and the displays' code cost every one of them (the City-only web demo too) seconds
## of compile time. One rectangle a display, so a chunk with displays draws one more surface, as the feed's TVs did; the
## skin's warm-up (MarketplaceSkin.warm_samples) draws one of each kind while a level loads.
##
## Using it (the panel's front faces the viewer, u to their right, v up; never in a mirrored template):
##   var layer: MeshLayer = batch.layer(skin.display_material())
##   WindowDisplay.add(layer, origin, u, v, WindowDisplay.AD, seed, Color(blue), 0.28)
## A panel needs a frame of its own (the material draws only the picture).
## DESIGN-TBD (docs/questions/l10.md): what the ads and posters show, how often the emblem flashes, and for how long.

const SHADER_FILE: String = "window_display.gdshader"
## The kinds of panel (the face's UV2.x): an ad screen, then the posters: a shop's own sign, a sale, a menu, a product.
const AD: int = 0
const SIGN: int = 1
const SALE: int = 2
const MENU: int = 3
const PRODUCT: int = 4
const POSTER_KINDS: int = 4


## The display material for the uniforms `params` (MarketplaceSkin.window_display_params(): the ads' palette, the
## Casino's set, the timings) with the emblem's coverage (the owner's choice, CultFeed.emblem_texture()) and the glow scale
## of the skin's emissive surfaces. Shared by every mesh of a skin (MeshKit.material caches by what it is made of).
static func material(params: Dictionary, glow_scale: float) -> ShaderMaterial:
	var all: Dictionary = params.duplicate()
	all["glow_scale"] = glow_scale
	var m: ShaderMaterial = MeshKit.material(SHADER_FILE, all)
	m.set_shader_parameter(&"wd_emblem_tex", CultFeed.emblem_texture())
	return m


## The face's parameter (UV2.y): a `seed` (0-999: it picks an ad screen's scenes, order, timing and flash moment, or a
## poster's drawing) and the panel's `aspect` (width over height, a whole tenth, up to 5). Kept small: the GPU
## interpolates a vertex value across a face with a float's precision, so a parameter of millions would wander by whole
## numbers over an oblique face and the seed with it (the Beach's sand_param() reads the same rule).
static func param(seed: int, aspect: float) -> float:
	return float(posmod(seed, 1000) + 1000 * clampi(roundi(aspect * 10.0), 1, 50))


## Adds a panel's face to `layer` (the display material's): a rectangle from `origin` spanning `u` (its width, to the
## viewer's right) and `v` (its height, up), facing u × v, of `kind` (AD, or a poster's), `seed` (see param()) and the
## poster's paint `color` (an ad screen's is unused); `glow` is an ad screen's brightness (0 for a poster).
static func add(layer: MeshLayer, origin: Vector3, u: Vector3, v: Vector3, kind: int, seed: int, color: Color,
		glow: float) -> void:
	var aspect: float = snappedf(u.length() / maxf(v.length(), 0.001), 0.1)
	layer.rect(origin, u, v, color, glow, kind, Vector2.ZERO, Vector2(aspect, 1.0), param(seed, aspect))


## The panel's aspect (a whole tenth) the shader is told for a face `width` wide and `height` tall.
static func aspect_of(width: float, height: float) -> float:
	return snappedf(width / maxf(height, 0.001), 0.1)
