class_name ZoneSkin
extends Resource
## The visual layer for one zone (CLAUDE.md, architecture principle 2). TrackBuilder creates
## every collision shape and gameplay node, then calls these hooks to decorate each abstract
## piece. Skins add meshes (later: lights, sounds, props) and never collision or gameplay.
## Hazards must keep the same colour and shape language in every skin (pink crackle = fence).
##
## `parent`-based hooks use the chunk's space, which is world space: x = sideways,
## y = up, z = -distance. Hooks that receive a gameplay node work in that node's local space.
##
## A level's darkness (LevelConfig.darkness; GDD §5, The Hush's darker lighting) reaches every skin
## through level_environment(): only the scenery darkens. apply_darkness() dims the sky and the
## distance fog, and sets the global shader uniform `scenery_light` (project.godot), which the mesh
## kit's scenery shaders (kit_solid's lit surfaces, facade, shopfront, road, drift) and the grey
## box's scenery material multiply their lit colour by. Glowing things keep their glow (hazards,
## triggers, neon, screens), and the ambient light and the sun that light the player and the enemies
## stay as they are, so hazards and enemies read as well as anywhere. A skin with scenery of its own
## drawn another way reads `scenery_light` too, or overrides apply_darkness() (calling it first).

## The dimmest the scenery gets, at darkness 1: darker, but never pitch black (the rule GDD §10 gives
## the Sleep Taker's arena, BossEncounter.MIN_LIGHT_LEVEL).
const MIN_SCENERY_LIGHT: float = 0.3
## The global shader uniform the scenery's shaders multiply their lit colour by (1 = the zone's own
## light).
const SCENERY_LIGHT: StringName = &"scenery_light"

## The scenery light set last (set_scenery_light), for tests and tools: the global uniform itself
## can't be read back in a headless run.
static var scenery_light_now: float = 1.0

## The default doodad look's base plinth, body and top (doodad()) take this much of its height.
const DOODAD_BASE_HEIGHT: float = 0.3
const DOODAD_TOP_HEIGHT: float = 0.24
## The default look's body is inset this much from its plinth and top, so the three read apart.
const DOODAD_INSET: float = 0.07
## How far back the default look's front slants toward the side it pushes to, at most (metres).
const DOODAD_SLANT: float = 0.55

## The default doodad meshes, by size, push side and palette (built once each).
static var _doodad_meshes: Dictionary = {}

## Which zone variant enemies dress in: the cyborgs' zone look (GDD §9.2, CyborgSuit.look_for) and the
## other enemies' weathering (&"scavenger" weathered, anything else clean). Each zone's value is listed
## in docs/ARCHITECTURE.md (Zone skins). Their hazard colours and shapes stay the same everywhere.
@export var enemy_variant: StringName = &"city"

@export_group("Doodads")
## The colours of the default doodad look (doodad()), sRGB: its body, its top and its base plinth. The
## zone's own non-hazard colours, never glowing: a doodad is solid, safe scenery (GDD §5's colour rule:
## only hazards glow in hazard colours). Each zone's skin file sets its own until task G6 gives the zone
## its doodads' real looks.
@export var doodad_palette: PackedColorArray = PackedColorArray([Color(0.3, 0.31, 0.35), Color(0.43, 0.44, 0.48),
	Color(0.17, 0.17, 0.2)])


func make_environment() -> Environment:
	return Environment.new()


## The environment for a level of this zone with the level's `darkness` (LevelConfig.darkness, 0–1):
## make_environment() with apply_darkness(). The run (LevelRun) builds its environment this way.
func level_environment(darkness: float) -> Environment:
	var env: Environment = make_environment()
	apply_darkness(env, darkness)
	return env


## Dims the scenery for a level's `darkness` (0 = the zone's own light, which it sets back): the sky
## (background energy) and the distance fog by scenery_light_for(darkness) (energy_factor), and the
## skin's lit surfaces through the `scenery_light` uniform. Glows, the ambient light and the sun are
## left alone (see the header). It dims the scene by as much on the Compatibility renderer.
func apply_darkness(env: Environment, darkness: float) -> void:
	var light: float = scenery_light_for(darkness)
	env.background_energy_multiplier *= energy_factor(light)
	env.fog_light_energy *= energy_factor(light)
	set_scenery_light(light)


## How lit the scenery is at `darkness` (0–1): 1 at 0, down to MIN_SCENERY_LIGHT at 1. A factor for
## linear space.
static func scenery_light_for(darkness: float) -> float:
	return lerpf(1.0, MIN_SCENERY_LIGHT, clampf(darkness, 0.0, 1.0))


## The factor on the environment's energies for a scenery `light`: the Compatibility renderer works in
## sRGB space, so it takes the light's sRGB equivalent (as the kit shaders' light_factor() does).
static func energy_factor(light: float) -> float:
	if RenderingServer.get_current_rendering_method() == "gl_compatibility":
		return pow(maxf(light, 0.0), 1.0 / 2.2)
	return light


## Sets the `scenery_light` shader uniform (1 = the zone's own light). The run sets it for its level
## and back to 1 when it ends.
static func set_scenery_light(light: float) -> void:
	scenery_light_now = light
	RenderingServer.global_shader_parameter_set(SCENERY_LIGHT, light)


## One lane's solid floor. center/size describe the collision box, whose top is at y = 0.
## edge_start/edge_end say whether a gap borders the segment at that end.
func floor_segment(_parent: Node3D, _center: Vector3, _size: Vector3, _lane_x: float,
		_edge_start: bool, _edge_end: bool) -> void:
	pass


## One side wall between two track distances. face_x is the wall face's signed world x.
func wall_section(_parent: Node3D, _side: int, _face_x: float, _start: float, _end: float) -> void:
	pass


## The wall enemies TrackBuilder is about to build on `side` in [start, end) (GDD §9.2: window
## cyborgs and the like), as layout entries exactly like LevelLayout.enemies holds them (type, at,
## side, ...). Called just before wall_section() for the same span, so a skin whose own scenery
## would otherwise double up with one (the Marketplace's citizens, task D3: never in a window a
## window cyborg stands in) can skip the overlap. Read-only and visual only, never collision or
## gameplay; the default skin needs nothing here.
func note_wall_enemies(_side: int, _start: float, _end: float, _enemies: Array[Dictionary]) -> void:
	pass


## An electric fence's energy field, the size of its hitbox and centred on the hazard.
## ground_y is the floor height in hazard-local space; gapped fences are open underneath.
func fence(_hazard: Hazard, _size: Vector3, _ground_y: float, _gapped: bool) -> void:
	pass


## A sign on a wall, the size of its hitbox and centred on the hazard.
func wall_sign(_hazard: Hazard, _size: Vector3) -> void:
	pass


## A ceiling section (TrackBuilder, and a boss's BossProps.ceiling). `section` covers a contiguous
## range of lanes: every lane, or fewer for a narrow ceiling (GDD §3: "ceilings don't have to cover
## every lane"), at any lane count. It carries the collision box over exactly those lanes (its
## underside is the surface), the seams between them, the wall faces' distance and which of its sides
## reach the street's edge (CeilingSection.reaches_wall). The far end (section.end) is where the player
## drops back to the floor: mark it across the section's width with the orange band
## (MeshKit.ceiling_end, as in every zone), and keep glows and anything bright off the far side of it,
## which the chase camera passes through as the player drops (see MeshKit.ceiling_end).
## The default dresses the collision box through hull(), so a skin that builds from the box alone
## follows the range for free; a skin whose look depends on the range (a structure that runs into a
## building face, a free edge in mid-street, a smaller craft) overrides this instead.
func ceiling_section(parent: Node3D, section: CeilingSection) -> void:
	hull(parent, section.center, section.size, section.lane_edges_x)


## A ceiling section as its collision box alone (ceiling_section() calls it by default). center/size
## describe the box; its underside is the surface. lane_edges_x are the world x positions of the seams
## between its lanes. Call ceiling_section() to dress a ceiling, never this: a skin may override
## ceiling_section() alone.
func hull(_parent: Node3D, _center: Vector3, _size: Vector3, _lane_edges_x: Array[float]) -> void:
	pass


## An anti-grav pad, the size of its trigger volume and centred on it. The floor is at -size.y / 2.
func pad(_trigger: Area3D, _size: Vector3) -> void:
	pass


## A ramp onto the wall on `side`, the size of its trigger volume and centred on it.
func ramp(_trigger: Area3D, _size: Vector3, _side: int) -> void:
	pass


## A speed pad, the size of its trigger volume and centred on it. The floor is at -size.y / 2.
func speed_pad(_trigger: Area3D, _size: Vector3) -> void:
	pass


## A zone doodad (GDD §3, owner's playtest September 30, 2026: the Neon City's pillars, small buildings
## and tiny market stalls, Gangland's burned-out cars and broken-down shops, the Marketplace's plants
## and casino machines, the other zones' in their look): a solid scenery piece standing in a lane that
## never hurts. Running into its front pushes the player into the neighbouring lane on `side` (-1 left,
## +1 right); its sides block a lane switch. `body` is its node (TrackBuilder), centred on its collision
## box `size` (width, height, length): the floor is at -size.y / 2 and its front, where the player
## meets it, at +size.z / 2. `size_class` is one of LevelLayout.DOODAD_SIZES (small, medium, large:
## which of the zone's doodads to show) and `look_seed` a number to vary the look by. Every look keeps
## to these (task G6):
## - inside the box, filling most of it: what looks like contact is contact (GDD §3), and it reads as
##   too tall to jump (it is) and as wide as it blocks;
## - solid and safe: the zone's non-hazard colours, nothing glowing in a hazard colour, nothing that
##   reads as a sign, a fence, a barrier's stripes or an enemy;
## - it may show the side it pushes to (the default's front slants back toward it);
## - cheap: one mesh per doodad, from cached templates (the kit's MeshBatch), working on the
##   Compatibility renderer.
## The default is a plain low-poly block in doodad_palette: a base plinth, an inset body and a top, its
## front slanting back toward the side it pushes to (default_doodad_mesh).
func doodad(body: Node3D, size: Vector3, _size_class: StringName, side: int, _look_seed: int) -> void:
	var key: String = var_to_str([size, side, doodad_palette])
	var mesh: ArrayMesh = _doodad_meshes.get(key)
	if mesh == null:
		mesh = default_doodad_mesh(size, side, doodad_palette)
		_doodad_meshes[key] = mesh
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = MeshKit.solid()
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(inst)


## The default doodad look (doodad()) for a box of `size` pushing to `side`, in `palette` (body, top,
## base; sRGB): a base plinth, a body inset from it and a top, the three sharing a footprint whose
## front slants back toward `side` (up to DOODAD_SLANT), so the block reads as glancing the runner off
## that way. Lit, never glowing, inside the box. One surface for the kit's solid material.
static func default_doodad_mesh(size: Vector3, side: int, palette: PackedColorArray) -> ArrayMesh:
	var body_color: Color = palette[0] if palette.size() > 0 else Color(0.3, 0.31, 0.35)
	var top_color: Color = palette[1] if palette.size() > 1 else body_color.lightened(0.2)
	var base_color: Color = palette[2] if palette.size() > 2 else body_color.darkened(0.4)
	var half: float = size.y * 0.5
	var slant: float = minf(DOODAD_SLANT, size.z * 0.3)
	var base_top: float = -half + minf(DOODAD_BASE_HEIGHT, size.y * 0.2)
	var body_top: float = half - minf(DOODAD_TOP_HEIGHT, size.y * 0.15)
	var batch := MeshBatch.new()
	var layer: MeshLayer = batch.layer(null)
	_doodad_prism(layer, size, side, slant, 0.0, -half, base_top, base_color)
	_doodad_prism(layer, size, side, slant, DOODAD_INSET, base_top, body_top, body_color)
	_doodad_prism(layer, size, side, slant, 0.0, body_top, half, top_color)
	return batch.to_mesh()


## One upright slab of the default doodad look, from height `y0` to `y1`: its footprint is the box's
## (`size`, inset by `inset`) with the front corner on `side` moved back by `slant`. Its sides and top.
static func _doodad_prism(layer: MeshLayer, size: Vector3, side: int, slant: float, inset: float, y0: float,
		y1: float, color: Color) -> void:
	var s: float = -1.0 if side < 0 else 1.0
	var a: float = size.x * 0.5 - inset
	var b: float = size.z * 0.5 - inset
	# (x, z) corners around the footprint: the far front corner, the slanted one, then the back.
	var corners: Array[Vector2] = [Vector2(-s * a, b), Vector2(s * a, b - slant), Vector2(s * a, -b), Vector2(-s * a, -b)]
	var centre := Vector3.ZERO
	for c: Vector2 in corners:
		centre += Vector3(c.x, 0.0, c.y) * 0.25
	for i: int in corners.size():
		var p: Vector2 = corners[i]
		var q: Vector2 = corners[(i + 1) % corners.size()]
		var out := Vector3(q.y - p.y, 0.0, p.x - q.x)
		if out.dot(Vector3((p.x + q.x) * 0.5, 0.0, (p.y + q.y) * 0.5) - centre) < 0.0:
			out = -out
		_doodad_face(layer, Vector3(p.x, y0, p.y), Vector3(p.x, y1, p.y), Vector3(q.x, y1, q.y), Vector3(q.x, y0, q.y),
			out, color)
	var top: Array[Vector3] = []
	for c: Vector2 in corners:
		top.append(Vector3(c.x, y1, c.y))
	_doodad_face(layer, top[0], top[1], top[2], top[3], Vector3.UP, color)


## A four-cornered face facing `outward` (Godot's front faces wind clockwise; MeshLayer.quad).
static func _doodad_face(layer: MeshLayer, a: Vector3, b: Vector3, c: Vector3, d: Vector3, outward: Vector3,
		color: Color) -> void:
	if (b - a).cross(c - a).dot(outward) > 0.0:
		layer.quad(a, d, c, b, color)
	else:
		layer.quad(a, b, c, d, color)


func finish_line(_parent: Node3D, _width: float, _distance: float) -> void:
	pass
