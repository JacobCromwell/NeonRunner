class_name MeshKit
extends RefCounted
## Shared building blocks for zone skins: deterministic hashing, cached unit templates, the kit
## shaders and their materials, the night environment, and the parts every zone must draw the same
## way: hazards (pink crackling energy field = electric fence, yellow/black striped frame = sign),
## triggers (cyan anti-grav pad, green ramp and speed pad) and the finish line.
## Build geometry into a MeshBatch (one surface per material) and commit it as one node.
## New props follow the same recipe: frame() for windows, hatches and vents (PAT_GRILLE for slats),
## prism() for discs and pipes, shared parts here when every zone must draw them alike.

## Box sides for MeshLayer.box(faces = ...). Skip sides nobody can see.
const FACE_PX: int = 1
const FACE_NX: int = 2
const FACE_PY: int = 4
const FACE_NY: int = 8
const FACE_PZ: int = 16
const FACE_NZ: int = 32
const ALL_FACES: int = 63
## Every side but the bottom: things standing on a floor.
const NO_BOTTOM: int = ALL_FACES & ~FACE_NY

## Surface patterns of the solid kit shader (UV2.x). Patterns use world position, so they line up
## across meshes and chunk cuts; GLYPHS uses UV (metres on the panel).
const PAT_PLAIN: int = 0
const PAT_ROOF: int = 1      ## Transverse panel seams (param: seam offset in metres).
const PAT_RIBS: int = 2      ## Vertical corrugation along the track.
const PAT_STRIPES: int = 3   ## Hazard stripes: colour and black diagonals; the colour glows.
const PAT_GLASS: int = 4     ## Dark glass that catches the sky.
const PAT_HULL: int = 5      ## Hull plating: panel lines and tone variation.
const PAT_CHECKER: int = 6   ## Finish-line checkers; the light squares glow.
const PAT_GRILLE: int = 7    ## Horizontal slats.
const PAT_GLYPHS: int = 8    ## Neon glyph rows on a dark panel (param: scroll speed in m/s).
const PAT_CHEVRON: int = 9   ## Scrolling arrows along UV.x (0–1 over the face), param ±1 = direction.
## Worn street: repair patches, cracks, scraps. UV.x runs -1 to 1 across the lane; param flags worn
## dashed lane lines on its left (1) and right (2) edge.
const PAT_ASPHALT: int = 10
## The cut through a broken road (crater walls): layers by world height, darkening into the depths.
## COLOR is the earth.
const PAT_STRATA: int = 11
## Salvaged plating: mismatched plates, seams, rust (param > 0: corrugation period in metres).
const PAT_RUST: int = 12
## Salvaged billboard content: faded, torn posters and graffiti (UV in metres, param a whole-number seed).
const PAT_POSTER: int = 13
## Cast concrete (decks, slabs, fascias): form-board lines, joints, stains and streaks; param > 0 paints
## graffiti over it (the share of slots painted, with the material's graffiti_pieces colours).
const PAT_CONCRETE: int = 14
## Painted crates and container doors with a stencilled marking (UV in metres, centred on the face);
## param = stencil_param(kind, size, seed).
const PAT_STENCIL: int = 15
## PAT_STENCIL kinds: a military supply code, the corporate logo (kit_logo.gdshaderinc), and both on
## corrugated container doors.
const STENCIL_CODE: int = 0
const STENCIL_LOGO: int = 1
const STENCIL_CODE_CORRUGATED: int = 2
const STENCIL_LOGO_CORRUGATED: int = 3

## Shapes of the additive glow shader (UV2.x); UV runs 0–1 over the card.
const SHAPE_FLAT: int = 0    ## Even glow with soft edges.
const SHAPE_RADIAL: int = 1  ## Round halo.
const SHAPE_BEAM: int = 2    ## Bright at v = 0, fading to v = 1, soft sides.
const SHAPE_RISE: int = 3    ## Light column: bright at the base, bands rising.
const SHAPE_STREAK: int = 4  ## Soft horizontal streak.

## Kinds of drifting particles (drift.gdshader, UV2.x).
const DRIFT_ASH: int = 0
const DRIFT_SCRAP: int = 1
const DRIFT_STREAK: int = 2
## A soft puff of smoke drifting low over the street (the Dead Zone's): big, faint and slow.
const DRIFT_SMOKE: int = 3

## Marketplace surface patterns of the solid kit shader (kit_market.gdshaderinc), ids 20-29.
## Canvas roofs and awnings: UV 0-1 across the panel and along the stall; param = stripes (0 plain,
## 1 along the track, 2 across it) + 4 * the stall's length in decimetres (0: no hem along its start).
const PAT_CANVAS: int = 20
## Corrugated tin: UV as for canvas; param = ribs (0 along the track, 1 across it) + 4 * the stall's
## length in decimetres.
const PAT_TIN: int = 21
## Everything under the stall roofs, seen only through gaps, in deep shade (darkens COLOR): param 0
## a face across the lane, 1 a face along it, 2 the market floor.
const PAT_UNDER: int = 22
## Stone flags (param 0, an overpass's walkway) or coffered soffit panels (param 1).
const PAT_TILES: int = 23
## A painted shop sign (UV in metres; param = seed 0-99 + 100 * the panel's height in decimetres).
const PAT_SHOPSIGN: int = 24
## An ad screen, glowing (UV.y 0-1 up the screen, UV.x in the same units; param a whole-number seed).
const PAT_AD: int = 25
## Rows of light bulbs on a dark panel, glowing (UV in metres).
const PAT_BULBS: int = 26
## Sun-bleached plaster.
const PAT_STUCCO: int = 27
## A whole row of market-stall roofs along one lane, laid out by the shader from world position
## (UV.x 0-1 across the lane; param the lane's key, see MarketStalls).
const PAT_STALLS: int = 28
## Building machinery (UV in metres): param 0 a solar panel, 1 an air-conditioning unit's front,
## 2 brushed metal with seams.
const PAT_TECH: int = 29

## Corporate surface patterns of the solid kit shader (kit_corporate.gdshaderinc), ids 30-39.
## A maglev carriage's roof: UV.x -1 to 1 across it, UV.y metres from the carriage's start; param =
## style (0 corporate express, 1 military freight) + 4 * painted brand mark + 8 * seed (0-63) + 512 * the
## carriage's length in decimetres.
const PAT_CORP_ROOF: int = 30
## Everything below the running surface, in deep shade darkening with depth (darkens COLOR): param 0 a
## face across the lane, 1 a face along it, 2 the trench's floor, 3 a guideway beam or pier.
const PAT_CORP_UNDER: int = 31
## A plaza's paving (world xz; UV.x -1 to 1 across the lane, param flags a steel edge strip on its left
## (1) and right (2) edge).
const PAT_CORP_PAVING: int = 32
## Plating (world position): param 0 a soffit, 1 military armour, 2 brushed steel, 3 precast concrete.
const PAT_CORP_PLATE: int = 33
## A corporate screen, glowing (UV.y 0-1 up the screen, UV.x in the same units; param a whole-number
## seed picks the ad).
const PAT_CORP_AD: int = 34
## The brand's mark (kit_logo.gdshaderinc) on a panel, UV in logo space (the mark spans about -0.78 to
## 0.78): param 0 the mark in COLOR on a dark panel, 1 cold white on a COLOR ground, 2 COLOR painted on
## steel, 3 pale paint on a COLOR ground.
const PAT_CORP_LOGO: int = 35
## A banner hanging down a tower (UV in metres, x across from its left edge, y down from its top;
## param = seed + 100 * its width in decimetres).
const PAT_CORP_BANNER: int = 36
## A glass wall with a lit corridor behind it (UV in metres, y up from the corridor's floor; param =
## the corridor's height in decimetres).
const PAT_CORP_GLASS: int = 37

## Dead Zone surface patterns of the solid kit shader (kit_dead_zone.gdshaderinc), ids 40-49. Nothing
## glows but PAT_DZ_TOWER's rare embers: give the other patterns' vertices COLOR.a = 0.
## The rubble street: road plates under pale ash, scattered rubble, worn lane lines (UV.x -1 to 1
## across the lane; param flags a lane line on its left (1) and right (2) edge, and a gutter (4)).
const PAT_DZ_STREET: int = 40
## Everything below the street, seen only through holes: deep shade darkening with depth (darkens
## COLOR): param 0 a face across the lane, 1 a face along it, 2 the void's floor.
const PAT_DZ_UNDER: int = 41
## A burnt-out tower's face (UV: metres along it, world height): param = dz_tower_param(); COLOR.a
## above 0 lets the rare ember high up glow (at most that much).
const PAT_DZ_TOWER: int = 42
## Charred concrete: param 0 a wall or deck, 1 an underside ridden upside down, 2 a heap of rubble.
const PAT_DZ_CONCRETE: int = 43
## Scorched steel: param 0 plain, 1 corrugated.
const PAT_DZ_STEEL: int = 44
## A dead billboard or screen, never glowing (UV in metres, as seen from the street): param = seed
## (0-99) + 100 * kind (DZ_BOARD_POSTER, DZ_BOARD_SCREEN).
const PAT_DZ_BOARD: int = 45
## The cult's emblem scorched and half-gone, unlit (the material's cult_emblem texture): UV in emblem
## space as for PAT_CULT_MARK, COLOR the mark's paint, param a seed for the burn.
const PAT_DZ_MARK: int = 46
## PAT_DZ_BOARD's kinds.
const DZ_BOARD_POSTER: int = 0
const DZ_BOARD_SCREEN: int = 1

## Golden Zone surface patterns of the solid kit shader (kit_golden.gdshaderinc), ids 50-59. None of
## them glows (gold is reflective metal, never neon, GDD §5): give their vertices COLOR.a = 0.
## Reflective gold, lit as polished metal (param: polish, 0 satin to 1 a mirror finish).
const PAT_GOLD: int = 50
## A golden walkway along one lane: UV.x metres across from its left edge (UV.y metres along); param =
## walkway_param(): joints to the neighbouring walkways, a medallion, the lane's width.
const PAT_WALKWAY: int = 51
## Polished white and cream marble (param 1: smaller blocks).
const PAT_MARBLE: int = 52
## Everything under the walkways, seen only through gaps: deep shade darkening with depth.
const PAT_UNDERDECK: int = 53
## The canal far below the walkways: dark water flowing toward the player.
const PAT_CANAL: int = 54
## Falling water (scenery): UV.x metres across the sheet, UV.y 0 at the lip to 1 at the foot; param 1
## a thin jet without foam.
const PAT_WATER: int = 55
## The cult's emblem shown openly, polished gold meeting at its red stone, embossed (the material's
## cult_emblem texture): UV in emblem space as for PAT_CULT_MARK; param 0 on red cloth, 1 on stone.
const PAT_EMBLEM: int = 56
## A gilded coffered underside (bridges, archways): param = the coffers' length along the track (m).
const PAT_COFFER: int = 57
## Red cloth with gold trims and a fringed hem: UV.x 0-1 across, UV.y metres up from the hem; param =
## the cloth's width in centimetres.
const PAT_CLOTH: int = 58
## A boutique's board, a hazard sign's content: UV in metres; param = seed (0-99) + 100 * the board's
## height in decimetres.
const PAT_BOUTIQUE: int = 59
## PAT_WALKWAY's flags.
const WALKWAY_JOINT_LEFT: int = 1
const WALKWAY_JOINT_RIGHT: int = 2
const WALKWAY_MEDALLION: int = 4

## The cult's patterns of the solid kit shader (kit_cult.gdshaderinc), ids 60-69.
## The cult's emblem (the material's cult_emblem texture) on a dark panel, for logos and ads: UV is
## emblem space (the mark's square spans -1 to 1; a wider range leaves a clear margin), the mark in
## COLOR.rgb, glowing at COLOR.a (warm-white neon) or unlit at 0. It fades out below about 24 pixels.
const PAT_CULT_MARK: int = 60

const SHADER_DIR: String = "res://scripts/world/meshes/shaders/"
## How far the glow under a ceiling's end band (ceiling_end) reaches back from the band, under the
## ceiling. It never reaches past the far end.
const CEILING_END_GLOW: float = 1.5
## The ceiling end glow fades out this close to the camera (near_fade): it marks the drop from further
## off, and never washes the screen as the camera passes under it after the player drops.
const CEILING_END_NEAR: float = 4.0
## A ship's engine glows at its stern (stern_halo, beams) fade out this close to the camera: it passes
## right under them after the player drops off the ship's end.
const STERN_NEAR: float = 8.0

static var _boxes: Dictionary = {}
static var _prisms: Dictionary = {}
static var _templates: Dictionary = {}
static var _shaders: Dictionary = {}
static var _materials: Dictionary = {}


# --- Deterministic hashing ---------------------------------------------------
# Variety comes from hashing track positions, never from a global RNG, so every chunk looks the
# same however and whenever it is built. 32-bit integer mixing (no overflow in 64-bit ints).

static func hash_i(a: int, b: int = 0, c: int = 0) -> int:
	var h: int = (a * 0x27d4eb2d) & 0xFFFFFFFF
	h ^= (b * 0x165667b1 + 0x3c6ef372) & 0xFFFFFFFF
	h ^= (c * 0x1b873593 + 0x68e31da4) & 0xFFFFFFFF
	h = ((h ^ (h >> 15)) * 0x2c1b3c6d) & 0xFFFFFFFF
	h = ((h ^ (h >> 12)) * 0x297a2d39) & 0xFFFFFFFF
	return h ^ (h >> 15)


## A deterministic value in [0, 1).
static func hash01(a: int, b: int = 0, c: int = 0) -> float:
	return float(hash_i(a, b, c) & 0xFFFFFF) / 16777216.0


## Picks one entry of `values` by hash.
static func pick(values: Array, a: int, b: int = 0, c: int = 0) -> Variant:
	return values[hash_i(a, b, c) % values.size()]


## A stable integer key for a track distance or a position (to hash on), at centimetre precision.
static func key(value: float) -> int:
	return roundi(value * 100.0)


## The PAT_STENCIL parameter: `kind` (STENCIL_*), a marking 0.3 m tall per `size` step (0-3, 0.3 to
## 1.2 m), a `seed` (0-15) that picks the code's glyphs, and `emblem`: the cult's emblem, small and
## unlit, beside the code or the logo (only where the material has the kit shader's cult_emblem
## texture).
static func stencil_param(kind: int, size: int, seed: int, emblem: bool = false) -> float:
	return float(kind + 4 * clampi(size, 0, 3) + 16 * posmod(seed, 16) + (256 if emblem else 0))


## The PAT_DZ_TOWER parameter: a window `style` (0-3, the City's: office glass, punched windows,
## ribbon windows, tall slots) and a whole-number `seed` (0-999).
static func dz_tower_param(style: int, seed: int) -> float:
	return float(posmod(style, 4) + 4 * posmod(seed, 1000))


## The PAT_WALKWAY parameter: `flags` (WALKWAY_*) and the lane's width in metres (to the centimetre).
static func walkway_param(flags: int, width: float) -> float:
	return float((flags & 7) + 8 * roundi(width * 100.0))


# --- Unit templates ------------------------------------------------------------

## A 1 m box centred on the origin with the sides in `faces`, UVs 0–1 per side.
static func unit_box(faces: int = ALL_FACES) -> MeshLayer:
	var cached: MeshLayer = _boxes.get(faces)
	if cached != null:
		return cached
	var t := MeshLayer.new()
	var h: float = 0.5
	if faces & FACE_PX:
		t.rect(Vector3(h, -h, h), Vector3(0, 0, -1), Vector3(0, 1, 0), Color.WHITE)
	if faces & FACE_NX:
		t.rect(Vector3(-h, -h, -h), Vector3(0, 0, 1), Vector3(0, 1, 0), Color.WHITE)
	if faces & FACE_PY:
		t.rect(Vector3(-h, h, h), Vector3(1, 0, 0), Vector3(0, 0, -1), Color.WHITE)
	if faces & FACE_NY:
		t.rect(Vector3(-h, -h, -h), Vector3(1, 0, 0), Vector3(0, 0, 1), Color.WHITE)
	if faces & FACE_PZ:
		t.rect(Vector3(-h, -h, h), Vector3(1, 0, 0), Vector3(0, 1, 0), Color.WHITE)
	if faces & FACE_NZ:
		t.rect(Vector3(h, -h, -h), Vector3(-1, 0, 0), Vector3(0, 1, 0), Color.WHITE)
	_boxes[faces] = t
	return t


## An upright prism with corner radius 1 from y = 0 to y = 1, flat-shaded sides.
static func unit_prism(sides: int, caps: bool = true) -> MeshLayer:
	var id: int = sides * 2 + int(caps)
	var cached: MeshLayer = _prisms.get(id)
	if cached != null:
		return cached
	var t := MeshLayer.new()
	var ring: Array[Vector3] = []
	for i: int in sides:
		var a: float = TAU * (float(i) + 0.5) / float(sides)
		ring.append(Vector3(cos(a), 0.0, sin(a)))
	for i: int in sides:
		var p0: Vector3 = ring[i]
		var p1: Vector3 = ring[(i + 1) % sides]
		t.rect(p1, p0 - p1, Vector3.UP, Color.WHITE, 0.0, 0, Vector2(float(i) / sides, 0.0), Vector2(float(i + 1) / sides, 1.0))
	if caps:
		for i: int in sides:
			var p0: Vector3 = ring[i]
			var p1: Vector3 = ring[(i + 1) % sides]
			_triangle(t, Vector3.UP, p0 + Vector3.UP, p1 + Vector3.UP)
			_triangle(t, Vector3.ZERO, p1, p0)
	_prisms[id] = t
	return t


static func _triangle(t: MeshLayer, a: Vector3, b: Vector3, c: Vector3) -> void:
	t.verts.append_array(PackedVector3Array([a, b, c]))
	t.colors.append_array(PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE]))
	t.uvs.append_array(PackedVector2Array([Vector2(0.5, 0.5), Vector2(0, 0), Vector2(1, 0)]))
	t.uv2s.append_array(PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]))


## `count` copies of one colour.
static func filled_colors(color: Color, count: int) -> PackedColorArray:
	var out := PackedColorArray()
	out.resize(count)
	out.fill(color)
	return out


static func filled_uv2(value: Vector2, count: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(count)
	out.fill(value)
	return out


# --- Shaders and materials -----------------------------------------------------

static func shader(file_name: String) -> Shader:
	if not _shaders.has(file_name):
		_shaders[file_name] = load(SHADER_DIR + file_name) as Shader
	return _shaders[file_name]


## A night Environment for a zone: the night sky shader with `sky_params` (night_sky.gdshader
## uniforms), flat ambient light, filmic tonemapping (it keeps neon hues: ACES pushed violets toward
## fence pink and AgX washed them out), glow for emissive parts, depth fog, and height fog below the
## track when low_fog_density > 0.
static func night_environment(sky_params: Dictionary, ambient: Color, fog_color: Color, fog_begin: float,
		fog_end: float, fog_max: float, low_fog_density: float, glow_intensity: float, glow_threshold: float) -> Environment:
	var sky_material := ShaderMaterial.new()
	sky_material.shader = shader("night_sky.gdshader")
	for p: String in sky_params:
		sky_material.set_shader_parameter(p, sky_params[p])
	var sky := Sky.new()
	sky.sky_material = sky_material
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ambient
	env.ambient_light_energy = 0.8
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = glow_intensity
	env.glow_strength = 1.0
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = glow_threshold
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = fog_color
	env.fog_light_energy = 1.0
	env.fog_depth_begin = fog_begin
	env.fog_depth_end = fog_end
	env.fog_depth_curve = 1.3
	env.fog_density = fog_max
	env.fog_sky_affect = 0.0
	env.fog_height = -3.0
	env.fog_height_density = low_fog_density
	return env


## A shared ShaderMaterial for `file_name` with these uniform values, cached by value.
static func material(file_name: String, params: Dictionary = {}) -> ShaderMaterial:
	var id: String = file_name + var_to_str(params)
	if not _materials.has(id):
		var m := ShaderMaterial.new()
		m.shader = shader(file_name)
		for p: String in params:
			m.set_shader_parameter(p, params[p])
		_materials[id] = m
	return _materials[id]


## The solid kit material: lit surfaces with fake city lighting, emissive where COLOR.a > 0.
static func solid(params: Dictionary = {}) -> ShaderMaterial:
	return material("kit_solid.gdshader", params)


## The additive glow material for halos, beams and light columns. It fades with distance itself
## (fade_begin/fade_end), since fog would brighten additive cards instead of hiding them.
static func glow(params: Dictionary = {}) -> ShaderMaterial:
	return material("kit_glow.gdshader", params)


## Three materials for a hazard's ON, WARNING and OFF states from one shader. `on` holds the shared
## uniforms; `warning` and `off` override what changes (e.g. {"state_glow": 0.1}).
static func state_materials(file_name: String, on: Dictionary, warning: Dictionary, off: Dictionary) -> Array[Material]:
	var w: Dictionary = on.duplicate()
	w.merge(warning, true)
	var o: Dictionary = on.duplicate()
	o.merge(off, true)
	return [material(file_name, on), material(file_name, w), material(file_name, o)]


## ON, WARNING and OFF materials for a fence's energy field: it crackles, sputters (while
## HazardTelegraph plays the warning), or shows nothing.
static func fence_field_materials(color: Color, fade_begin: float, fade_end: float) -> Array[Material]:
	var on := {"color": color, "intensity": 1.0, "fade_begin": fade_begin, "fade_end": fade_end}
	return state_materials("energy_field.gdshader", on, {"flicker_hz": 16.0, "intensity": 0.75}, {"intensity": 0.0})


## ON, WARNING and OFF materials for a hazard's glowing solid parts (a fence's bars and emitters):
## the solid kit shader with `solid_params`, flickering in WARNING and dim when OFF. The ON material
## is its own instance (not the zone's plain solid one), so these parts stay a separate surface.
static func hazard_part_materials(solid_params: Dictionary) -> Array[Material]:
	var on: Dictionary = solid_params.duplicate()
	on["state_glow"] = 1.0
	return state_materials("kit_solid.gdshader", on, {"flicker_hz": 12.0}, {"state_glow": 0.12})


# --- Shared hazard parts ---------------------------------------------------------
# Hazards keep one colour and shape language in every zone (GDD §5). These builders are the
# common part; zones add their own mounts (exhaust stacks, rubble, ...) around them.

## Dresses an electric fence: the energy field, a little larger than the hitbox (GDD §3: hitboxes err
## in the player's favour), and the zone's `mounts` mesh, whose glowing parts use part_materials[0].
## Field and glowing parts follow the hazard's state (HazardStateVisual).
static func dress_fence(hazard: Hazard, size: Vector3, mounts: ArrayMesh, field_materials: Array[Material],
		part_materials: Array[Material]) -> void:
	var field: MeshInstance3D = MeshBatch.add_instance(hazard, energy_field_mesh(size + Vector3(0.06, 0.08, 0.0)))
	var parts: MeshInstance3D = MeshBatch.add_instance(hazard, mounts)
	var visual := HazardStateVisual.new()
	hazard.add_child(visual)
	visual.add_target(field, -1, field_materials)
	for s: int in mounts.get_surface_count():
		if mounts.surface_get_material(s) == part_materials[0]:
			visual.add_target(parts, s, part_materials)
	visual.bind(hazard)


## The glowing parts every electric fence shares, on the `hot` layer (hazard-local, ground_y = the
## floor): the bar you jump over (full) or slide under (gapped, with a thinner bar along its top),
## and emitters where the field meets its posts at x = ±post_x.
static func fence_bars(hot: MeshLayer, size: Vector3, ground_y: float, gapped: bool, post_x: float, color: Color) -> void:
	var top: float = size.y * 0.5
	var bottom: float = -size.y * 0.5
	for side: float in [-1.0, 1.0]:
		for y: float in [top, bottom]:
			if y > ground_y + 0.05:
				hot.box(Vector3(side * (post_x - 0.02), y, 0), Vector3(0.12, 0.06, 0.12), color, 1.0)
	hot.box(Vector3(0, bottom if gapped else top, 0), Vector3(size.x + 0.1, 0.045, 0.045), color, 0.9)
	if gapped:
		hot.box(Vector3(0, top, 0), Vector3(size.x + 0.1, 0.035, 0.035), color, 0.7)


## A sign jutting out of the wall on `side`, the size of its hitbox (hazard-local): the yellow/black
## hazard frame around a content panel facing the track, drawn with `content_pattern` (PAT_GLYPHS
## neon, PAT_POSTER billboards, ...). `halo` > 0 adds a soft glow card in front of the panel.
## DESIGN-TBD: the yellow/black hazard frame is the proposed sign language for every zone.
static func hazard_sign(size: Vector3, side: int, frame_color: Color, content_color: Color, content_glow: float,
		content_pattern: int, content_param: float, halo: float, solid_material: Material, glow_material: Material) -> ArrayMesh:
	var id: String = "sign_%s_%d_%s_%s_%s_%d_%s_%s_%d_%d" % [size, side, frame_color, content_color, content_glow,
		content_pattern, content_param, halo, solid_material.get_instance_id(), glow_material.get_instance_id()]
	if _templates.has(id):
		return _templates[id]
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(solid_material)
	var g: MeshLayer = batch.layer(glow_material)
	# Grow toward the track and along its length, never into the wall.
	var grow := Vector3(0.08, 0.1, 0.12)
	var vis: Vector3 = size + grow
	var center := Vector3(-side * grow.x * 0.5, 0, 0)
	var rail: float = clampf(vis.y * 0.14, 0.12, 0.26)
	hazard_frame(s, center, vis, rail, frame_color, 0.35)
	var inner := Vector3(vis.x - 0.12, vis.y - rail * 2.0, vis.z - rail * 2.0)
	if inner.y > 0.05 and inner.z > 0.05:
		s.box(center + Vector3(side * 0.06, 0, 0), inner, Color(0.03, 0.03, 0.05), 0.0, PAT_PLAIN,
			FACE_PX if side < 0 else FACE_NX)
		var face_x: float = center.x - side * (vis.x * 0.5 - 0.06)
		var y0: float = -inner.y * 0.5
		var zh: float = inner.z * 0.5
		# The panel faces the track; its content reads (and scrolls) left to right as seen from the lanes.
		if side > 0:
			s.rect(Vector3(face_x, y0, -zh), Vector3(0, 0, inner.z), Vector3(0, inner.y, 0), content_color, content_glow,
				content_pattern, Vector2(0, 0), Vector2(inner.z, inner.y), content_param)
		else:
			s.rect(Vector3(face_x, y0, zh), Vector3(0, 0, -inner.z), Vector3(0, inner.y, 0), content_color, content_glow,
				content_pattern, Vector2(0, 0), Vector2(inner.z, inner.y), content_param)
		if halo > 0.0:
			g.rect(Vector3(face_x - side * 0.25, y0 - 0.3, -zh - 0.3), Vector3(0, 0, inner.z + 0.6),
				Vector3(0, inner.y + 0.6, 0), content_color, halo, SHAPE_FLAT)
	var mesh: ArrayMesh = batch.to_mesh()
	_templates[id] = mesh
	return mesh


## The energy field of an electric fence: three cards through the depth of `size` (hazard-local,
## centred), each with its own crackle. Use it with an energy_field.gdshader material (one per state,
## see HazardStateVisual); UV.x runs across, UV.y up.
static func energy_field_mesh(size: Vector3) -> ArrayMesh:
	var id: String = "field_%s" % size
	if _templates.has(id):
		return _templates[id]
	var t := MeshLayer.new()
	var half: Vector3 = size * 0.5
	var zs: Array[float] = [half.z, 0.0, -half.z]
	for i: int in zs.size():
		t.rect(Vector3(-half.x, -half.y, zs[i]), Vector3(size.x, 0, 0), Vector3(0, size.y, 0), Color.WHITE,
			0.0, 0, Vector2.ZERO, Vector2.ONE, float(i))
	var batch := MeshBatch.new()
	batch.layer(null).append(t)
	var mesh: ArrayMesh = batch.to_mesh()
	_templates[id] = mesh
	return mesh


## A hazard frame around a box of `size` centred on `center`: striped top and bottom rails along z
## and striped end caps, leaving both x faces open for the zone's content panel. Rails are `rail` thick.
## DESIGN-TBD: the yellow/black striped frame is the proposed cross-zone sign language.
static func hazard_frame(layer: MeshLayer, center: Vector3, size: Vector3, rail: float, color: Color,
		glow_amount: float) -> void:
	var h: Vector3 = size * 0.5
	# Top and bottom rails run the full length; end caps close the box.
	layer.box(center + Vector3(0, h.y - rail * 0.5, 0), Vector3(size.x, rail, size.z), color, glow_amount, PAT_STRIPES)
	layer.box(center - Vector3(0, h.y - rail * 0.5, 0), Vector3(size.x, rail, size.z), color, glow_amount, PAT_STRIPES)
	var inner_h: float = size.y - rail * 2.0
	if inner_h > 0.0:
		layer.box(center + Vector3(0, 0, h.z - rail * 0.5), Vector3(size.x, inner_h, rail), color, glow_amount, PAT_STRIPES,
			ALL_FACES & ~(FACE_PY | FACE_NY))
		layer.box(center - Vector3(0, 0, h.z - rail * 0.5), Vector3(size.x, inner_h, rail), color, glow_amount, PAT_STRIPES,
			ALL_FACES & ~(FACE_PY | FACE_NY))


## A rectangular frame in the plane facing `normal_axis` (0 = x, 2 = z): windows, hatches, vents.
static func frame(layer: MeshLayer, center: Vector3, width: float, height: float, depth: float,
		bar: float, color: Color, glow_amount: float = 0.0, normal_axis: int = 2) -> void:
	var across := Vector3(width, 0, 0) if normal_axis == 2 else Vector3(0, 0, width)
	var d := Vector3(0, 0, depth) if normal_axis == 2 else Vector3(depth, 0, 0)
	var dir: Vector3 = across.normalized()
	layer.box(center + Vector3(0, (height - bar) * 0.5, 0), across + Vector3(0, bar, 0) + d, color, glow_amount)
	layer.box(center - Vector3(0, (height - bar) * 0.5, 0), across + Vector3(0, bar, 0) + d, color, glow_amount)
	var side: Vector3 = dir * bar + Vector3(0, height - bar * 2.0, 0) + d
	layer.box(center + dir * (width - bar) * 0.5, side, color, glow_amount)
	layer.box(center - dir * (width - bar) * 0.5, side, color, glow_amount)


# --- Shared trigger and marker looks ---------------------------------------------------------
# Triggers look the same in every zone, like hazards: a cyan anti-grav pad with a light column, green
# arrows for ramps and speed pads, the checkered finish. Zones only pick the metal around them.
# Meshes are cached by their arguments and shared by every instance.

## An anti-grav pad, the size of its trigger volume and centred on it (the floor at -size.y / 2):
## a flush lift plate of glowing rings with a light column rising toward the ceiling.
static func lift_pad(size: Vector3, color: Color, plate_color: Color, beam_height: float, solid_material: Material,
		glow_material: Material) -> ArrayMesh:
	var id: String = "pad_%s_%s_%s_%s_%d_%d" % [size, color, plate_color, beam_height, solid_material.get_instance_id(),
		glow_material.get_instance_id()]
	if _templates.has(id):
		return _templates[id]
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(solid_material)
	var g: MeshLayer = batch.layer(glow_material)
	var y0: float = -size.y * 0.5
	s.box(Vector3(0, y0 + 0.02, 0), Vector3(size.x + 0.2, 0.04, size.z + 0.2), plate_color, 0.0, PAT_PLAIN, NO_BOTTOM)
	for inset: float in [0.0, 0.28, 0.52]:
		_ring(s, Vector3(0, y0 + 0.045, 0), size.x - inset * 2.0, size.z - inset * 2.0, 0.07, color, 0.9 - inset)
	s.box(Vector3(0, y0 + 0.05, 0), Vector3(0.3, 0.02, 0.3), color, 1.0)
	g.rect(Vector3(-size.x * 0.9, y0 + 0.06, size.z * 0.9), Vector3(size.x * 1.8, 0, 0), Vector3(0, 0, -size.z * 1.8),
		color, 0.5, SHAPE_RADIAL)
	var bx: float = size.x * 0.5
	var bz: float = size.z * 0.5
	# Two crossed cards through the pad's centre: a soft column from any angle.
	g.rect(Vector3(-bx, y0, 0), Vector3(bx * 2.0, 0, 0), Vector3(0, beam_height, 0), color, 0.5, SHAPE_RISE)
	g.rect(Vector3(0, y0, bz), Vector3(0, 0, -bz * 2.0), Vector3(0, beam_height, 0), color, 0.5, SHAPE_RISE)
	var mesh: ArrayMesh = batch.to_mesh()
	_templates[id] = mesh
	return mesh


## A ramp onto the wall on `side`, the size of its trigger volume and centred on it: a kicker plate
## banked up toward the wall, with arrows streaming toward the wall.
static func kicker_ramp(size: Vector3, side: int, color: Color, metal: Color, solid_material: Material,
		glow_material: Material) -> ArrayMesh:
	var id: String = "ramp_%s_%d_%s_%s_%d_%d" % [size, side, color, metal, solid_material.get_instance_id(),
		glow_material.get_instance_id()]
	if _templates.has(id):
		return _templates[id]
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(solid_material)
	var g: MeshLayer = batch.layer(glow_material)
	var y0: float = -size.y * 0.5
	var hx: float = size.x * 0.5
	var hz: float = size.z * 0.5
	var low: float = y0 + 0.05
	var high: float = y0 + 0.45
	var sd: float = float(side)
	# Corners: inner edge low, wall-side edge high.
	var in_n := Vector3(-sd * hx, low, hz)
	var in_f := Vector3(-sd * hx, low, -hz)
	var out_n := Vector3(sd * hx, high, hz)
	var out_f := Vector3(sd * hx, high, -hz)
	var base_n := Vector3(sd * hx, y0, hz)
	var base_f := Vector3(sd * hx, y0, -hz)
	var in_bn := Vector3(-sd * hx, y0, hz)
	var in_bf := Vector3(-sd * hx, y0, -hz)
	# The top's UV.x runs from its first corner across; the chevron direction (param) points at the wall.
	if side > 0:
		s.quad(in_n, in_f, out_f, out_n, color, 0.8, PAT_CHEVRON, 1.0)
		s.quad(in_bn, in_n, out_n, base_n, metal)
		s.quad(base_n, out_n, out_f, base_f, metal)
		s.quad(in_bf, in_f, in_n, in_bn, metal)
	else:
		s.quad(out_n, out_f, in_f, in_n, color, 0.8, PAT_CHEVRON, -1.0)
		s.quad(base_n, out_n, in_n, in_bn, metal)
		s.quad(base_f, out_f, out_n, base_n, metal)
		s.quad(in_bn, in_n, in_f, in_bf, metal)
	# Glowing rails along the high edge and the sloped front edge.
	s.box((out_n + out_f) * 0.5 + Vector3(0, 0.02, 0), Vector3(0.06, 0.05, size.z), color, 1.0)
	var rise: float = high - low
	var front := Basis(Vector3.BACK, sd * atan2(rise, size.x)).scaled_local(
		Vector3(sqrt(size.x * size.x + rise * rise), 0.05, 0.05))
	s.box_xform(Transform3D(front, (in_n + out_n) * 0.5 + Vector3(0, 0.02, 0.02)), color, 0.8)
	g.rect(Vector3(-hx * 1.4, y0 + 0.08, hz * 1.3), Vector3(hx * 2.8, 0, 0), Vector3(0, 0, -hz * 2.6), color, 0.35,
		SHAPE_RADIAL)
	var mesh: ArrayMesh = batch.to_mesh()
	_templates[id] = mesh
	return mesh


## A speed pad, the size of its trigger volume and centred on it (the floor at -size.y / 2): a flush
## plate of arrows streaming down the track between two glowing rails.
## DESIGN-TBD: the GDD doesn't describe speed pads; green arrows put them in the ramps' "safe boost"
## family (like the grey box).
static func speed_strip(size: Vector3, color: Color, plate_color: Color, solid_material: Material,
		glow_material: Material) -> ArrayMesh:
	var id: String = "speed_%s_%s_%s_%d_%d" % [size, color, plate_color, solid_material.get_instance_id(),
		glow_material.get_instance_id()]
	if _templates.has(id):
		return _templates[id]
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(solid_material)
	var g: MeshLayer = batch.layer(glow_material)
	var y0: float = -size.y * 0.5
	var hx: float = size.x * 0.5
	var hz: float = size.z * 0.5
	s.box(Vector3(0, y0 + 0.02, 0), Vector3(size.x + 0.16, 0.04, size.z + 0.16), plate_color, 0.0, PAT_PLAIN, NO_BOTTOM)
	# UV.x runs down the track (u = -z), so the arrows point and stream forward.
	s.rect(Vector3(hx - 0.1, y0 + 0.042, hz), Vector3(0, 0, -size.z), Vector3(-(size.x - 0.2), 0, 0), color, 0.8,
		PAT_CHEVRON, Vector2.ZERO, Vector2.ONE, 1.0)
	for side: float in [-1.0, 1.0]:
		s.box(Vector3(side * (hx - 0.03), y0 + 0.055, 0), Vector3(0.06, 0.03, size.z + 0.1), color, 1.0, PAT_PLAIN, NO_BOTTOM)
	g.rect(Vector3(-hx * 1.4, y0 + 0.07, hz * 1.2), Vector3(hx * 2.8, 0, 0), Vector3(0, 0, -hz * 2.4), color, 0.3,
		SHAPE_RADIAL)
	var mesh: ArrayMesh = batch.to_mesh()
	_templates[id] = mesh
	return mesh


## The finish line across the track (`width`) at `distance`: a glowing checkered strip and a gantry
## with a checkered banner.
static func finish_gate(batch: MeshBatch, solid_material: Material, glow_material: Material, width: float,
		distance: float, color: Color, metal: Color) -> void:
	var s: MeshLayer = batch.layer(solid_material)
	var g: MeshLayer = batch.layer(glow_material)
	var z: float = -distance
	s.box(Vector3(0, 0.03, z), Vector3(width, 0.04, 1.2), color, 0.6, PAT_CHECKER, NO_BOTTOM)
	var px: float = width * 0.5 + 0.2
	for side: float in [-1.0, 1.0]:
		s.box(Vector3(side * px, 4.5, z), Vector3(0.5, 13.0, 0.5), metal)
		s.box(Vector3(side * (px - 0.26), 4.5, z + 0.1), Vector3(0.04, 12.5, 0.08), color, 0.7)
	s.box(Vector3(0, 10.4, z), Vector3(width + 0.9, 1.3, 0.6), metal)
	s.box(Vector3(0, 10.4, z + 0.32), Vector3(width, 0.9, 0.04), color, 0.8, PAT_CHECKER)
	g.rect(Vector3(-width * 0.6, 8.8, z + 0.4), Vector3(width * 1.2, 0, 0), Vector3(0, 3.2, 0), color, 0.18, SHAPE_FLAT)
	g.rect(Vector3(-width * 0.5, 0.06, z + 1.5), Vector3(width, 0, 0), Vector3(0, 0, -3.0), color, 0.2, SHAPE_STREAK)


## The far end of a ceiling (hull-local: underside at y = 0, the end at z = zf, `band` deep): a band
## of the orange edge glow with amber lights along it and a glow below, so the drop back to the floor
## reads like a gap edge in every zone. The band spans half_width to each side of center_x (a narrow
## ceiling's band spans its own lanes).
## Nothing of it reaches past the far end: the chase camera passes the end just below the underside as
## the player drops (RunCamera keeps it camera_ceiling_clearance below a ceiling over it, and no lower
## past the end), and a glow there filled the screen with orange for a frame. The same goes for every
## skin's far end: past it, glows and bright faces stay above the underside.
static func ceiling_end(s: MeshLayer, g: MeshLayer, half_width: float, zf: float, band: float, color: Color,
		center_x: float = 0.0) -> void:
	var x0: float = center_x - half_width
	s.rect(Vector3(x0, 0, zf), Vector3(half_width * 2.0, 0, 0), Vector3(0, 0, band), color, 0.33)
	var lx: float = x0 + 0.6
	while lx < center_x + half_width - 0.3:
		s.box(Vector3(lx, -0.025, zf + 0.25), Vector3(0.35, 0.05, 0.2), color, 0.6, PAT_PLAIN, ALL_FACES & ~FACE_PY)
		lx += 1.2
	g.rect(Vector3(x0, -0.05, zf + band + CEILING_END_GLOW), Vector3(half_width * 2.0, 0, 0),
		Vector3(0, 0, -(band + CEILING_END_GLOW)), color, 0.35, SHAPE_RADIAL, Vector2.ZERO, Vector2.ONE,
		near_fade(CEILING_END_NEAR))


## A glow card's parameter (UV2.y, the `param` of MeshLayer.rect) for a card that fades out near the
## camera: from `metres` away, gone within 40% of that (kit_glow.gdshader), so a card the chase camera
## passes close to never fills the screen. Any shape takes it.
static func near_fade(metres: float) -> float:
	return -absf(metres)


## A round halo facing along the track around `center` (hull-local: the ceiling's underside at y = 0),
## `radius` across, cut off at the underside: a ship's engine glowing at its stern. Past a ceiling's far
## end nothing glows below the underside, where the chase camera passes as the player drops (see
## ceiling_end); the halo keeps its shape above it, and fades out as the camera comes close
## (near_fade(STERN_NEAR)).
static func stern_halo(g: MeshLayer, center: Vector3, radius: float, color: Color, strength: float) -> void:
	var bottom: float = maxf(center.y - radius, 0.0)
	var top: float = center.y + radius
	if top <= bottom:
		return
	g.rect(Vector3(center.x - radius, bottom, center.z), Vector3(radius * 2.0, 0, 0), Vector3(0, top - bottom, 0), color,
		strength, SHAPE_RADIAL, Vector2(0.0, (bottom - (center.y - radius)) / (radius * 2.0)), Vector2.ONE,
		near_fade(STERN_NEAR))


static func _ring(s: MeshLayer, center: Vector3, w: float, d: float, t: float, color: Color, glow_amount: float) -> void:
	s.box(center + Vector3(0, 0, d * 0.5 - t * 0.5), Vector3(w, 0.02, t), color, glow_amount, PAT_PLAIN, FACE_PY)
	s.box(center - Vector3(0, 0, d * 0.5 - t * 0.5), Vector3(w, 0.02, t), color, glow_amount, PAT_PLAIN, FACE_PY)
	s.box(center + Vector3(w * 0.5 - t * 0.5, 0, 0), Vector3(t, 0.02, d - t * 2.0), color, glow_amount, PAT_PLAIN, FACE_PY)
	s.box(center - Vector3(w * 0.5 - t * 0.5, 0, 0), Vector3(t, 0.02, d - t * 2.0), color, glow_amount, PAT_PLAIN, FACE_PY)


# --- Walls -------------------------------------------------------------------------------

## Splits a wall side into runs of lots (one building each): the first and last lot of the run
## covering `lot_index`. A run starts at every `period`-th lot and, by hash, at a `share` of the
## others, so finding one never looks back more than period - 1 lots.
static func lot_run(side: int, lot_index: int, share: float, period: int = 3, salt: int = 1) -> Vector2i:
	var first: int = lot_index
	while not _starts_run(side, first, share, period, salt):
		first -= 1
	var last: int = lot_index
	while not _starts_run(side, last + 1, share, period, salt):
		last += 1
	return Vector2i(first, last)


static func _starts_run(side: int, lot_index: int, share: float, period: int, salt: int) -> bool:
	return posmod(lot_index, period) == 0 or hash01(side, lot_index, salt) < share


## A facade piece (facade.gdshader) in the wall plane at x, facing the track (side -1 = the left
## wall), from track distance u0 to u1 and from height y0 up to a top edge running from top0 (at u0)
## to top1 (at u1). UV is (distance, height) in metres, so windows line up across pieces.
static func facade_quad(layer: MeshLayer, side: int, x: float, u0: float, u1: float, y0: float, top0: float,
		top1: float, color: Color, lit: float, style: int, seed: float) -> void:
	if side < 0:
		layer.quad_uv(Vector3(x, y0, -u0), Vector3(x, top0, -u0), Vector3(x, top1, -u1), Vector3(x, y0, -u1),
			Vector2(u0, y0), Vector2(u0, top0), Vector2(u1, top1), Vector2(u1, y0), color, lit, style, seed)
	else:
		layer.quad_uv(Vector3(x, y0, -u1), Vector3(x, top1, -u1), Vector3(x, top0, -u0), Vector3(x, y0, -u0),
			Vector2(u1, y0), Vector2(u1, top1), Vector2(u0, top0), Vector2(u0, y0), color, lit, style, seed)


## A run of facade pieces in the wall plane at x (see facade_quad): piece k spans track distances
## us[k] to us[k + 1], from y0 up to a top edge running from tops[k] to tops[k + 1]. Built in bulk,
## for broken silhouettes made of many pieces.
static func facade_strip(layer: MeshLayer, side: int, x: float, us: PackedFloat32Array, tops: PackedFloat32Array,
		y0: float, color: Color, lit: float, style: int, seed: float) -> void:
	var n: int = us.size() - 1
	if n <= 0:
		return
	var at: int = layer.verts.size()
	layer.verts.resize(at + n * 6)
	layer.uvs.resize(at + n * 6)
	layer.colors.append_array(filled_colors(Color(color, lit), n * 6))
	layer.uv2s.append_array(filled_uv2(Vector2(style, seed), n * 6))
	for k: int in n:
		# Corners a, b, c, d as in facade_quad: bottom and top at the piece's first edge, then its second.
		var near: int = k if side < 0 else k + 1
		var far: int = k + 1 if side < 0 else k
		var a := Vector3(x, y0, -us[near])
		var b := Vector3(x, tops[near], -us[near])
		var c := Vector3(x, tops[far], -us[far])
		var d := Vector3(x, y0, -us[far])
		var ua := Vector2(us[near], y0)
		var uc := Vector2(us[far], tops[far])
		var i: int = at + k * 6
		layer.verts[i] = a
		layer.verts[i + 1] = b
		layer.verts[i + 2] = c
		layer.verts[i + 3] = a
		layer.verts[i + 4] = c
		layer.verts[i + 5] = d
		layer.uvs[i] = ua
		layer.uvs[i + 1] = Vector2(us[near], tops[near])
		layer.uvs[i + 2] = uc
		layer.uvs[i + 3] = ua
		layer.uvs[i + 4] = uc
		layer.uvs[i + 5] = Vector2(us[far], y0)


# --- Drifting particles ------------------------------------------------------------------------

## Drifting ash, paper scraps and speed streaks over the track between two distances, for a
## drift.gdshader material whose slice_length is `slice`. Every slice of the track gets the same
## cached set (it can't be seen repeating: particles fade out long before the next slice), so a
## chunk costs a few bulk appends. Particles stay within ±half_width, from 0.4 m up to top_y (streaks
## and smoke no higher than 4.5 m). `colors` holds the ash, scrap and streak colours (alpha =
## opacity), and a fourth for `smoke` puffs of smoke (none unless it's given).
static func drift_particles(layer: MeshLayer, start: float, end: float, slice: float, half_width: float, top_y: float,
		ash: int, scraps: int, streaks: int, colors: PackedColorArray, smoke: int = 0) -> void:
	var id: String = "drift_%s_%s_%s_%d_%d_%d_%s_%d" % [slice, half_width, top_y, ash, scraps, streaks, colors, smoke]
	var template: MeshLayer = _templates.get(id)
	if template == null:
		template = MeshLayer.new()
		var counts: Array[int] = [ash, scraps, streaks, smoke if colors.size() > DRIFT_SMOKE else 0]
		var n: int = 0
		for kind: int in [DRIFT_ASH, DRIFT_SCRAP, DRIFT_STREAK, DRIFT_SMOKE]:
			var y_max: float = top_y if kind == DRIFT_ASH or kind == DRIFT_SCRAP else minf(top_y, 4.5)
			for i: int in counts[kind]:
				var at := Vector3(lerpf(-half_width, half_width, hash01(n, kind, 71)), lerpf(0.4, y_max, hash01(n, kind, 72)), 0)
				_billboard(template, at, colors[kind], kind, hash01(n, kind, 73))
				n += 1
		_templates[id] = template
	var index: int = ceili(start / slice - 0.001)
	while (index + 1) * slice <= end + 0.001:
		layer.append(template, Transform3D(Basis.IDENTITY, Vector3(0, 0, -(index + 1) * slice)))
		index += 1


static func _billboard(layer: MeshLayer, anchor: Vector3, color: Color, kind: int, phase: float) -> void:
	layer.verts.append_array(PackedVector3Array([anchor, anchor, anchor, anchor, anchor, anchor]))
	layer.colors.append_array(PackedColorArray([color, color, color, color, color, color]))
	layer.uvs.append_array(PackedVector2Array([Vector2(-1, -1), Vector2(-1, 1), Vector2(1, 1), Vector2(-1, -1),
		Vector2(1, 1), Vector2(1, -1)]))
	var k := Vector2(kind, phase)
	layer.uv2s.append_array(PackedVector2Array([k, k, k, k, k, k]))
