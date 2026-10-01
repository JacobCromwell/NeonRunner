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

## A floor cut's standard look (floor_cut, standard_floor_cut; task B4): the orange lip on the floor
## right at the cut's edge (metres, and its glow), the strip along the top of the far end's face, the
## soft halo along it, how far down the hole's inside goes and how far its walls sit inside the lane's
## edges (so they never fight with a neighbour's side), and how far above the floor the lips are
## drawn (they lie over floor the track draws whole, and must win over it at a distance on every
## renderer).
const CUT_LIP: float = 0.18
const CUT_LIP_GLOW: float = 0.4
const CUT_STRIP_TOP: float = 0.02
const CUT_STRIP_HEIGHT: float = 0.1
const CUT_STRIP_GLOW: float = 0.6
const CUT_HALO: float = 0.35
const CUT_DEPTH: float = 8.0
const CUT_WALL_INSET: float = 0.03
const CUT_LIP_LIFT: float = 0.02
## The default look's inside and edge when the skin names neither (gap_inside_color, gap_edge_color).
const CUT_INSIDE_COLOR := Color(0.035, 0.035, 0.042)
const CUT_EDGE_COLOR := Color(1.0, 0.25, 0.04)

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
## edge_start/edge_end say whether a gap borders the segment at that end. A floor cut's lane (task B4)
## is drawn with this too, in short slices with no edges (FloorCut hides and shortens them as the cut
## runs), so a skin's floor needs nothing for cuts: its slices must simply join seamlessly, as pieces
## cut at chunk boundaries already do.
func floor_segment(_parent: Node3D, _center: Vector3, _size: Vector3, _lane_x: float,
		_edge_start: bool, _edge_end: bool) -> void:
	pass


## A floor cut's hole (task B4; GDD §9.9: the floor the Buzz Overdrive's saw cuts "becomes a gap ... The
## cut edges glow the usual gap-edge orange"): the stretch of one lane's floor from cut.start to
## cut.end that turns into a gap during play, as the cut runs from its end back to its start. The track
## draws the floor itself (floor_segment, in slices it hides as the cut passes), so this draws only
## the hole: its dark inside, and the orange edges right on the collision edge (the lips on the
## neighbouring lanes' floor along the cut, on the floor's far end where the cut has got to, and on the
## floor beyond the cut's end, with a strip and a halo there), registered on `cut` as parts the cut
## moves as it runs (FloorCutSection: static, span, front, far). It must read as a hole at a glance,
## like any gap, in every zone; nothing in it glows but the orange edges, and nothing flickers.
## Build every part with an identity transform, in `parent`'s (world) space, where the section says.
## The default (standard_floor_cut) is a plain dark hole with the skin's gap_edge_color and
## gap_inside_color if it has them. The zones where the Buzz Overdrive appears give it their own floor's
## look (a train roof sliced open, rubble split, a gold walkway cut) by passing their own style and
## adding parts of their own.
func floor_cut(parent: Node3D, cut: FloorCutSection) -> void:
	var edge: Variant = get("gap_edge_color")
	var inside: Variant = get("gap_inside_color")
	standard_floor_cut(parent, cut, MeshKit.solid(), MeshKit.glow(), {
		"edge": edge if edge is Color else CUT_EDGE_COLOR,
		"inside": inside if inside is Color else CUT_INSIDE_COLOR,
	})


## The standard floor cut look (floor_cut), drawn with `solid` (the kit's solid shader: vertex colour,
## glow in its alpha, patterns) and `glow` (the kit's additive glow, for the halo), in a skin's `style`
## (every key optional):
##   edge (Color): the orange edges, the skin's gap_edge_color;
##   inside (Color), pattern (int, a MeshKit.PAT_* that only darkens), params ([across, along, bottom]:
##     its param on a face across the lane, along it and the bottom): the hole's inside;
##   depth (float): how far down its inside goes; bottom (bool, true): draw its bottom (false where the
##     skin draws a void below the whole street already);
##   lip, lip_glow, strip_glow, halo (floats; halo 0: none);
##   side_from (Array[float], [left, right]): where the neighbouring lanes' visible floor ends on each
##     side, if short of the cut's edge (a train roof's shoulder: the side lips run from there to the
##     edge).
## Returns the four MeshInstance3Ds it adds ({static, span, front, far}), for a skin that adds to them.
static func standard_floor_cut(parent: Node3D, cut: FloorCutSection, solid: Material, glow: Material,
		style: Dictionary) -> Dictionary:
	var edge: Color = style.get("edge", CUT_EDGE_COLOR)
	var inside: Color = style.get("inside", CUT_INSIDE_COLOR)
	var pattern: int = int(style.get("pattern", MeshKit.PAT_PLAIN))
	var params: Array = style.get("params", [0.0, 0.0, 0.0])
	var depth: float = float(style.get("depth", CUT_DEPTH))
	var lip: float = float(style.get("lip", CUT_LIP))
	var lip_glow: float = float(style.get("lip_glow", CUT_LIP_GLOW))
	var strip_glow: float = float(style.get("strip_glow", CUT_STRIP_GLOW))
	var halo: float = float(style.get("halo", CUT_HALO))
	var side_from: Array = style.get("side_from", [cut.x0, cut.x1])
	var x0: float = cut.x0
	var x1: float = cut.x1
	var w: float = x1 - x0
	var z0: float = -cut.start
	var z1: float = -cut.end
	var length: float = cut.length()
	var top: float = -CUT_STRIP_TOP
	var y: float = CUT_LIP_LIFT
	var inset: float = CUT_WALL_INSET
	var out: Dictionary = {}

	# The inside, below the floor over the whole stretch: hidden under the floor until it goes.
	var inner := MeshBatch.new()
	var s: MeshLayer = inner.layer(solid)
	var wall: float = depth + top
	s.rect(Vector3(x0 + inset, -depth, z0), Vector3(0, 0, -length), Vector3(0, wall, 0), inside, 0.0, pattern,
		Vector2.ZERO, Vector2.ONE, float(params[1]))
	s.rect(Vector3(x1 - inset, -depth, z1), Vector3(0, 0, length), Vector3(0, wall, 0), inside, 0.0, pattern,
		Vector2.ZERO, Vector2.ONE, float(params[1]))
	s.rect(Vector3(x0 + inset, -depth, z1 + inset), Vector3(w - 2.0 * inset, 0, 0), Vector3(0, wall, 0), inside, 0.0,
		pattern, Vector2.ZERO, Vector2.ONE, float(params[0]))
	s.rect(Vector3(x1 - inset, -depth, z0 - inset), Vector3(-(w - 2.0 * inset), 0, 0), Vector3(0, wall, 0), inside, 0.0,
		pattern, Vector2.ZERO, Vector2.ONE, float(params[0]))
	if bool(style.get("bottom", true)):
		s.rect(Vector3(x0, -depth, z0), Vector3(w, 0, 0), Vector3(0, 0, -length), inside, 0.0, pattern,
			Vector2.ZERO, Vector2.ONE, float(params[2]))
	out["static"] = _commit_part(inner, parent, "CutInside")
	cut.add_static(out["static"])

	# Along the cut, built over the whole stretch and shown over [front, end]: the lips on the
	# neighbouring lanes' floor right at the cut's edges, and a strip along the top of each wall.
	var along := MeshBatch.new()
	var a: MeshLayer = along.layer(solid)
	for side: int in [-1, 1]:
		if not cut.has_neighbour(side):
			continue
		var ex: float = cut.edge_x(side)
		var from: float = float(side_from[0 if side < 0 else 1])
		var reach: float = maxf(absf(ex - from), 0.0) + lip
		var lx: float = ex - reach if side < 0 else ex
		a.rect(Vector3(lx, y, z0), Vector3(reach, 0, 0), Vector3(0, 0, -length), edge, lip_glow)
		# Just in front of the inside's wall, facing into the hole.
		var sx: float = ex - side * (inset + 0.004)
		if side < 0:
			a.rect(Vector3(sx, top - CUT_STRIP_HEIGHT, z0), Vector3(0, 0, -length), Vector3(0, CUT_STRIP_HEIGHT, 0), edge, strip_glow)
		else:
			a.rect(Vector3(sx, top - CUT_STRIP_HEIGHT, z1), Vector3(0, 0, length), Vector3(0, CUT_STRIP_HEIGHT, 0), edge, strip_glow)
	out["span"] = _commit_part(along, parent, "CutEdges")
	if out["span"] != null:
		cut.add_span(out["span"])

	# The floor's far end where the cut has got to (built at the cut's end, moved to its front): its lip.
	var near_edge := MeshBatch.new()
	near_edge.layer(solid).rect(Vector3(x0, y, z1 + lip), Vector3(w, 0, 0), Vector3(0, 0, -lip), edge, lip_glow)
	out["front"] = _commit_part(near_edge, parent, "CutFront")
	cut.add_front(out["front"])

	# The far side of the hole, facing the player: the lip on the floor beyond it, the strip along the top
	# of its face, and the halo that carries it from afar.
	var far := MeshBatch.new()
	var f: MeshLayer = far.layer(solid)
	f.rect(Vector3(x0, y, z1), Vector3(w, 0, 0), Vector3(0, 0, -lip), edge, lip_glow)
	f.rect(Vector3(x0, top - CUT_STRIP_HEIGHT, z1 + inset + 0.004), Vector3(w, 0, 0), Vector3(0, CUT_STRIP_HEIGHT, 0), edge,
		strip_glow)
	if halo > 0.0:
		far.layer(glow).rect(Vector3(x0 - 0.15, top - CUT_STRIP_HEIGHT - 0.25, z1 + 0.05), Vector3(w + 0.3, 0, 0),
			Vector3(0, CUT_STRIP_HEIGHT + 0.5, 0), edge, halo, MeshKit.SHAPE_STREAK)
	out["far"] = _commit_part(far, parent, "CutFar")
	cut.add_far(out["far"])
	return out


## Commits one part of a floor cut's look under `parent` (null if it's empty).
static func _commit_part(batch: MeshBatch, parent: Node3D, node_name: String) -> MeshInstance3D:
	return batch.commit(parent, node_name)


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
