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
## The global shader uniform the scenery's shaders multiply their lit colour by, channel by channel,
## after `scenery_light`: the street's light under a level's own sky (LevelSky.scenery_tint; white =
## the zone's own).
const SCENERY_TINT: StringName = &"scenery_tint"
## The scenery tint set last (set_scenery_tint), for tests and tools.
static var scenery_tint_now: Color = Color.WHITE

## Whether a side wall gap closes its opening with the recess (wall_gap_recess; task L4). A cinematic's stage turns it
## off on its own copy of the skin (CineStage.build): its openings are where the set looks out of the street (a side
## street, the skyline), and the recess would wall them off. Not exported: a skin's data never turns it off.
var wall_gap_recess_on: bool = true

## The default doodad look's base plinth, body and top (doodad()) take this much of its height.
const DOODAD_BASE_HEIGHT: float = 0.3
const DOODAD_TOP_HEIGHT: float = 0.24
## The default look's body is inset this much from its plinth and top, so the three read apart.
const DOODAD_INSET: float = 0.07
## How far back the default look's front slants toward the side it pushes to, at most (metres).
const DOODAD_SLANT: float = 0.55
## The metadata a doodad look's mesh carries its main lit colours in (tag_debris_colors), which its
## pieces fly off in when the dash smashes it (doodad_debris_colors, task H5).
const DEBRIS_COLORS_META: StringName = &"debris_colors"
## How many of a look's colours its pieces take, at most (MeshBatch.palette).
const DEBRIS_COLORS_MAX: int = 4

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
## A side wall gap's standard look (standard_wall_gap; metres, glow): its edge marks run from the floor
## (never below it: under the floor stays the skins' own shade) to WALL_GAP_EDGE_HEIGHT (above the wall-run band and a ramp's launch), each
## WALL_GAP_EDGE_WIDTH wide, the leading one brighter; the cut wall's ends go WALL_GAP_DEPTH back from
## its face; the floor's edge across the gap has a WALL_GAP_LIP wide orange lip.
const WALL_GAP_EDGE_HEIGHT: float = 7.0
const WALL_GAP_EDGE_WIDTH: float = 0.45
const WALL_GAP_EDGE_INSET: float = 0.03
const WALL_GAP_DEPTH: float = 6.0
const WALL_GAP_LIP: float = 0.3
const WALL_GAP_LEADING_GLOW: float = 0.9
const WALL_GAP_TRAILING_GLOW: float = 0.5
## What a side wall gap shows behind it (wall_gap_recess; task L4, the owner, October 17, 2026: "these holes leave
## an ugly unrendered section in the background"): a recess WALL_GAP_RECESS_DEPTH deep behind the wall line, the two
## cut buildings' end faces and the face across it rising WALL_GAP_RECESS_TOP, on a ground WALL_GAP_RECESS_FLOOR
## below the street. A skin draws its own (its facades' materials and heights); this is the plain default.
const WALL_GAP_RECESS_DEPTH: float = 18.0
const WALL_GAP_RECESS_TOP: float = 24.0
const WALL_GAP_RECESS_FLOOR: float = -8.0
## The default recess's faces, as a share of the way from the skin's gap_inside_color to a dim grey (CUT_RECESS_GREY).
const WALL_GAP_RECESS_LIFT: float = 0.35
const CUT_RECESS_GREY := Color(0.34, 0.34, 0.38)
## The default broken stump of a side wall's section (wall_stump; task O1, the Terminal's arches): its top for a skin
## with no `wall_height` (half the grey box's 9 m walls), how far back from the wall line it reaches and how far below
## the street it goes (metres; the grey box's walls go as far down).
const WALL_STUMP_HEIGHT: float = 4.5
const WALL_STUMP_DEPTH: float = 1.0
const WALL_STUMP_BOTTOM: float = -6.0
## The default open space between a boundary wall's sections (wall_opening; task O1): a plain wall this far behind the
## wall line, this tall, over a ground this far below the street (metres).
const WALL_OPENING_DEPTH: float = 5.0
const WALL_OPENING_TOP: float = 14.0
const WALL_OPENING_FLOOR: float = -1.0
## A wall-run gap's lit wall's standard look (standard_wall_run_guide, task J2; metres, glow), the ramps' green
## chevrons as the Floating Head's wall marks show a wall run (FloatingHeadWallMarks): the stretch to step on is a tall
## panel (WALL_RUN_STEP_LOW to _HIGH), the wall over the gap a strip at running height (WALL_RUN_STRIP_LOW to _HIGH,
## where a wall runner's body passes), each chevron WALL_RUN_PANEL / 3 long, standing WALL_RUN_PROUD off the wall line
## (clear of the facades' faces), framed with lines; its colour when the skin has no ramp_color.
const WALL_RUN_STEP_LOW: float = 0.3
const WALL_RUN_STEP_HIGH: float = 3.6
const WALL_RUN_STRIP_LOW: float = 1.0
const WALL_RUN_STRIP_HIGH: float = 2.5
const WALL_RUN_PANEL: float = 2.4
const WALL_RUN_PROUD: float = 0.04
## Its frame lines stand off the wall line to here, just past the panel's face (the skins' suites let nothing stand
## more than 5 cm off a wall in the wall-run band).
const WALL_RUN_LINE_PROUD: float = 0.045
const WALL_RUN_STEP_GLOW: float = 1.3
const WALL_RUN_STRIP_GLOW: float = 0.8
const WALL_RUN_EDGE_GLOW: float = 1.0
const WALL_RUN_COLOR := Color(0.3, 1.0, 0.35)

## The default doodad meshes, by size, push side and palette (built once each).
static var _doodad_meshes: Dictionary = {}
## The default dash wall meshes (dash_wall()), by size, look, palette and material (built once each).
static var _dash_wall_meshes: Dictionary = {}

## The default dash wall look (dash_wall(), task H7a): how many looks it varies between (by the wall's seed),
## a storey's height, the plinth along its foot, the cornice along its top, the pilasters at its sides, how
## far the walls between them sit back from its face, a window bay's width and its window's size (metres).
const DASH_WALL_LOOKS: int = 4
const DASH_WALL_STOREY: float = 3.0
const DASH_WALL_PLINTH: float = 0.8
const DASH_WALL_CORNICE: float = 0.7
const DASH_WALL_PILASTER: float = 0.45
const DASH_WALL_RECESS: float = 0.14
const DASH_WALL_BAY: float = 2.4
const DASH_WALL_WINDOW := Vector2(1.2, 1.45)
## The standard wall fence look's emitter meshes (wall_fence_mounts), built once each.
static var _wall_fence_meshes: Dictionary = {}
## The standard ceiling fence look's emitter meshes (ceiling_fence_mounts, task I4), built once each.
static var _ceiling_fence_meshes: Dictionary = {}

## The wall fence pink of a skin without a fence_color of its own (the grey box's, the City's).
const WALL_FENCE_COLOR := Color(1.0, 0.18, 0.62)
## How thick a wall fence's emitter arm is (standard_wall_fence).
const WALL_EMITTER_THICKNESS: float = 0.1

## Which zone variant enemies dress in: the cyborgs' zone look (GDD §9.2, CyborgSuit.look_for) and the
## other enemies' weathering (&"scavenger" weathered, anything else clean). Each zone's value is listed
## in docs/ARCHITECTURE.md (Zone skins). Their hazard colours and shapes stay the same everywhere.
@export var enemy_variant: StringName = &"city"
## How much bigger this zone draws its cyborgs: the floor cyborgs (panic variant and hosts too) and the window
## cyborgs (CyborgSuit.draw_scale), a factor on the model only, from the feet (a window cyborg: from its waist).
## Their hitboxes, bolts and everything gameplay reads stay as they are, so a bigger one is easier to see, not
## harder to dodge. Owner, October 14, 2026 (GDD §9.2): the cyborgs were hard to see in the first zone, so
## the Neon City draws them 1.2 times bigger (task I2, data/skins/city_skin.tres); the owner then asked for every
## zone after it too (task J1): 1.2 in every zone skin and every boss-arena skin (data/bosses/*_skin.tres, so the
## Floating Head's dropped cyborgs and the Board's guards match their zone). Only this class default stays 1.0.
## DESIGN-TBD (docs/OPEN_QUESTIONS_DEFERRED.md item 829): the factor per zone; it is this one number in each skin.
@export_range(0.5, 2.0, 0.01) var cyborg_draw_scale: float = 1.0

@export_group("Doodads")
## The colours of the default doodad look (doodad()), sRGB: its body, its top and its base plinth. The
## zone's own non-hazard colours, never glowing: a doodad is solid, safe scenery (GDD §5's colour rule:
## only hazards glow in hazard colours). Set from each zone's own export (task G5); every zone but the
## grey box and the Golden Palace (which keep this plain default) now overrides doodad() with its own
## look (task G6), so this array is otherwise unused there but stays as a fallback and a record of the
## zone's doodad palette.
@export var doodad_palette: PackedColorArray = PackedColorArray([Color(0.3, 0.31, 0.35), Color(0.43, 0.44, 0.48),
	Color(0.17, 0.17, 0.2)])

@export_group("Wall fences")
## The default wall fence look's emitter housings (wall_fence(), task B5): the arms and plates on the
## facade that hold the field, in a dark, unlit metal (sRGB) so only the pink glows. A zone may set its
## own, or draw its own emitters by overriding wall_fence().
@export var wall_fence_mount_color: Color = Color(0.2, 0.21, 0.24)

@export_group("Dash walls")
## The colours of the default dash wall look (dash_wall(), task H7a), sRGB: its walls, its trim (pilasters,
## floor slabs, plinth and cornice), its windows' glass and its cracks. Lit, never glowing (GDD §5's colour
## rule: only hazards glow in hazard colours; a dash wall is solid and safe to dash through). A zone returns
## its own side walls' colours from dash_wall_colors() instead; this is the fallback.
@export var dash_wall_palette: PackedColorArray = PackedColorArray([Color(0.35, 0.36, 0.39), Color(0.25, 0.26, 0.29),
	Color(0.07, 0.08, 0.1), Color(0.035, 0.035, 0.045)])

@export_group("Gantryways")
## The colours of the default falling gantryway look (gantryway(), gantry_pillar(), gantryway_wreck(), task Q3;
## GantrywayKit), sRGB: its steel, its steel's lighter edges, frost, snow and ice. Lit, never glowing. Empty: the kit's
## frosted steel (GantrywayKit.STEEL ...), the Ice Lab's own look; a zone may set its own, or draw its own look by
## overriding the three.
@export var gantryway_palette: PackedColorArray = PackedColorArray()

@export_group("Wall-run gaps")
## Whether this zone lights a wall-run gap's way across with the green chevrons (wall_run_guide, task L5; the owner,
## October 17, 2026: the lit wall is fine where the mechanic is introduced, the Marketplace, but too easy after it, so
## every later zone's skin sets this to false and the hole itself is the cue). Keep it true where a zone's gap needs a
## speed boost to cross (none does: the gap is sized for a standard wall run at the zone's own run speed). True here,
## so the grey box and the earlier zones' skins (quick play, review tools) still show it. DESIGN-TBD
## (items 929-932 in docs/OPEN_QUESTIONS*.md): which zones keep it.
@export var show_wall_run_guide: bool = true


func make_environment() -> Environment:
	return Environment.new()


## The environment for a level of this zone with the level's own `sky` over the zone's, if it has one
## (LevelConfig.sky, LevelSky.apply), the street's light under it (set_scenery_tint: the sky's
## scenery_tint, or the zone's own light), and its `darkness` (LevelConfig.darkness, 0–1):
## make_environment() with all three, the darkness last (apply_darkness()). The run (LevelRun) builds its
## environment this way.
func level_environment(darkness: float, sky: LevelSky = null) -> Environment:
	var env: Environment = make_environment()
	if sky != null:
		sky.apply(env)
	set_scenery_tint(sky.scenery_tint if sky != null else Color.WHITE)
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


## Sets the `scenery_tint` shader uniform (white = the zone's own light): a factor per channel for linear
## space, passed to the Compatibility renderer as its sRGB equivalent (energy_factor(), here rather than
## in every scenery pixel). The run sets it for its level and back to white when it ends.
static func set_scenery_tint(tint: Color) -> void:
	scenery_tint_now = tint
	RenderingServer.global_shader_parameter_set(SCENERY_TINT,
		Vector3(energy_factor(tint.r), energy_factor(tint.g), energy_factor(tint.b)))


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
## The default (standard_floor_cut) is a plain dark box with the skin's gap_edge_color and
## gap_inside_color if it has them, which only the grey box (no zone scenery below it) keeps. Every zone
## gives the cut its own floor's look (a train roof sliced open, rubble split, a gold walkway, the
## palace's marble or the City's hover truck, Gangland's street and the Marketplace's stall roofs cut)
## by passing its own style and adding parts of its own. Task H3 (GDD §9.9: inside the cut the player
## sees the zone's own scenery below the street, the same as through an ordinary gap): the hole has no
## bottom of its own where the zone draws its plane below the street (every zone does, once per chunk
## with the left wall), and leaves the sides to the neighbouring lanes' floors where they draw them.
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
##   walls (bool, true): draw the long side walls (task H3). false where the neighbours' floors draw their
##     own sides under the street (every zone's floor_segment does, down to its gap's depth), which then
##     show through the cut as through any gap, in the zone's own gap look, instead of a copy of them. The
##     side with no neighbour (the lane's floor runs on to the wall) keeps its wall, unless `outer_walls`
##     is false too (the City: no wall at the facade, as at any gap there);
##   outer_walls (bool, true): with walls false, whether the side with no neighbour keeps its wall;
##   end_depth (float, depth): how far down the cut's two end faces go, when the floor ends above the
##     below plane as it does at any gap (the City's hover trucks end 2.6 m down, with the road far below);
##   lip, lip_glow, strip_glow, halo (floats; halo 0: none);
##   side_from (Array[float], [left, right]): where the neighbouring lanes' visible floor ends on each
##     side, if short of the cut's edge (a train roof's shoulder: the side lips run from there to the
##     edge);
##   wall_x (Array[float], [left, right]): where the inside's side walls stand (by default just inside
##     the lane's edges; a carriage's sides, inside its lane);
##   ribs (float, 0: none), rib_param (float): ribs on the side walls every so many metres, in the
##     inside's pattern with this param (a carriage's frame);
##   dark_line (Color), dark (float): a dark line on the floor just outside each lip, this wide (the
##     Golden Zone's edges, so the orange pops against its gold).
## Returns the four MeshInstance3Ds it adds ({static, span, front, far}), for a skin that adds to them.
static func standard_floor_cut(parent: Node3D, cut: FloorCutSection, solid: Material, glow: Material,
		style: Dictionary) -> Dictionary:
	var edge: Color = style.get("edge", CUT_EDGE_COLOR)
	var inside: Color = style.get("inside", CUT_INSIDE_COLOR)
	var pattern: int = int(style.get("pattern", MeshKit.PAT_PLAIN))
	var params: Array = style.get("params", [0.0, 0.0, 0.0])
	var depth: float = float(style.get("depth", CUT_DEPTH))
	var end_depth: float = float(style.get("end_depth", depth))
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
	var walls: Array = style.get("wall_x", [x0 + inset, x1 - inset])
	var w0: float = float(walls[0])
	var w1: float = float(walls[1])
	var has_dark: bool = style.has("dark_line")
	var dark_color: Color = style.get("dark_line", Color.BLACK)
	var dark: float = float(style.get("dark", 0.0)) if has_dark else 0.0
	var out: Dictionary = {}

	# The inside, below the floor over the whole stretch: hidden under the floor until it goes.
	var inner := MeshBatch.new()
	var s: MeshLayer = inner.layer(solid)
	var wall: float = depth + top
	var end_wall: float = end_depth + top
	var side_walls: bool = bool(style.get("walls", true))
	var outer_walls: bool = bool(style.get("outer_walls", true))
	var left_wall: bool = side_walls or (outer_walls and not cut.has_neighbour(-1))
	var right_wall: bool = side_walls or (outer_walls and not cut.has_neighbour(1))
	if left_wall:
		s.rect(Vector3(w0, -depth, z0), Vector3(0, 0, -length), Vector3(0, wall, 0), inside, 0.0, pattern,
			Vector2.ZERO, Vector2.ONE, float(params[1]))
	if right_wall:
		s.rect(Vector3(w1, -depth, z1), Vector3(0, 0, length), Vector3(0, wall, 0), inside, 0.0, pattern,
			Vector2.ZERO, Vector2.ONE, float(params[1]))
	s.rect(Vector3(x0 + inset, -end_depth, z1 + inset), Vector3(w - 2.0 * inset, 0, 0), Vector3(0, end_wall, 0), inside, 0.0,
		pattern, Vector2.ZERO, Vector2.ONE, float(params[0]))
	s.rect(Vector3(x1 - inset, -end_depth, z0 - inset), Vector3(-(w - 2.0 * inset), 0, 0), Vector3(0, end_wall, 0), inside, 0.0,
		pattern, Vector2.ZERO, Vector2.ONE, float(params[0]))
	if bool(style.get("bottom", true)):
		s.rect(Vector3(x0, -depth, z0), Vector3(w, 0, 0), Vector3(0, 0, -length), inside, 0.0, pattern,
			Vector2.ZERO, Vector2.ONE, float(params[2]))
	var ribs: float = float(style.get("ribs", 0.0))
	if ribs > 0.0:
		var rib_param: float = float(style.get("rib_param", params[1]))
		var d: float = cut.start + ribs * 0.5
		while d < cut.end - 0.3:
			for x: float in [w0 + 0.06, w1 - 0.06]:
				s.box(Vector3(x, (top - depth) * 0.5, -d), Vector3(0.12, depth + top, 0.16), inside, 0.0, pattern,
					MeshKit.FACE_PX | MeshKit.FACE_NX | MeshKit.FACE_PZ, rib_param)
			d += ribs
	out["static"] = _commit_part(inner, parent, "CutInside")
	cut.add_static(out["static"])

	# Along the cut, built over the whole stretch and shown over [front, end]: the lips on the
	# neighbouring lanes' floor right at the cut's edges (a dark line outside them if the style has
	# one), and a strip along the top of each wall.
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
		if has_dark:
			var dx: float = lx - dark if side < 0 else ex + reach
			a.rect(Vector3(dx, y, z0), Vector3(dark, 0, 0), Vector3(0, 0, -length), dark_color)
		# Just in front of the inside's wall, facing into the hole.
		var sx: float = (w0 + 0.004) if side < 0 else (w1 - 0.004)
		if side < 0:
			a.rect(Vector3(sx, top - CUT_STRIP_HEIGHT, z0), Vector3(0, 0, -length), Vector3(0, CUT_STRIP_HEIGHT, 0), edge, strip_glow)
		else:
			a.rect(Vector3(sx, top - CUT_STRIP_HEIGHT, z1), Vector3(0, 0, length), Vector3(0, CUT_STRIP_HEIGHT, 0), edge, strip_glow)
	out["span"] = _commit_part(along, parent, "CutEdges")
	if out["span"] != null:
		cut.add_span(out["span"])

	# The floor's far end where the cut has got to (built at the cut's end, moved to its front): its lip.
	var near_edge := MeshBatch.new()
	var n: MeshLayer = near_edge.layer(solid)
	n.rect(Vector3(x0, y, z1 + lip), Vector3(w, 0, 0), Vector3(0, 0, -lip), edge, lip_glow)
	if has_dark:
		n.rect(Vector3(x0, y, z1 + lip + dark), Vector3(w, 0, 0), Vector3(0, 0, -dark), dark_color)
	out["front"] = _commit_part(near_edge, parent, "CutFront")
	cut.add_front(out["front"])

	# The far side of the hole, facing the player: the lip on the floor beyond it, the strip along the top
	# of its face, and the halo that carries it from afar.
	var far := MeshBatch.new()
	var f: MeshLayer = far.layer(solid)
	f.rect(Vector3(x0, y, z1), Vector3(w, 0, 0), Vector3(0, 0, -lip), edge, lip_glow)
	if has_dark:
		f.rect(Vector3(x0, y, z1 - lip), Vector3(w, 0, 0), Vector3(0, 0, -dark), dark_color)
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


## One side wall between two track distances. face_x is the wall face's signed world x. In a level without wall
## running (task O1; LevelLayout.wall_running off: the Terminal, whose walls are a row of narrow arches, GDD §5 Zone 8)
## each call is one whole standing piece of wall, an arch, about a doodad's length (WallGapTuning.arch_length), drawn
## once in the chunk where it starts (TrackBuilder._build_boundary_wall); in every other level the wall comes in pieces
## cut at the chunks' edges and the gaps' ends, which must join seamlessly.
func wall_section(_parent: Node3D, _side: int, _face_x: float, _start: float, _end: float) -> void:
	pass


## A broken stump of a side wall's section, from track distance `start` to `end` on wall `side` (`face_x` the wall
## face's signed world x), in `parent`'s (world) space: task O1, GDD §5 Zone 8, the Terminal's arches, "where one side's
## section is missing, that side shows a section cut off about halfway up, as if it had deteriorated over time or fallen
## in an earthquake, a crumbled ruin". TrackBuilder calls it once for each stump (LevelLayout.wall_stumps), whole, in the
## chunk where it starts, after the opening it stands in (wall_opening), opposite the other wall's arch. Visual only,
## like every hook: no collision (the walls are a boundary there, and the runner never reaches them). It stands at the
## wall line and back from it (never toward the lanes), and nothing on it glows or reads as a hazard. The default is a
## plain box half the walls' height (half the skin's `wall_height` where it has one, else WALL_STUMP_HEIGHT), in the
## zone's side-wall colour and lit material (dash_wall_colors()[0], dash_wall_material(), as the default dash wall
## takes them), from below the street; a zone draws its own ruin (task O4, the Terminal's skin).
func wall_stump(parent: Node3D, side: int, face_x: float, start: float, end: float) -> void:
	var colors: PackedColorArray = dash_wall_colors()
	var color: Color = colors[0] if not colors.is_empty() else CUT_RECESS_GREY
	var height: Variant = get("wall_height")
	var top: float = float(height) * 0.5 if height is float and float(height) > 0.0 else WALL_STUMP_HEIGHT
	var batch := MeshBatch.new()
	batch.layer(dash_wall_material()).box(
		Vector3(face_x + side * WALL_STUMP_DEPTH * 0.5, (top + WALL_STUMP_BOTTOM) * 0.5, -(start + end) * 0.5),
		Vector3(WALL_STUMP_DEPTH, top - WALL_STUMP_BOTTOM, end - start), color)
	batch.commit(parent, "WallStump")


## A side wall gap's part between two track distances (LevelLayout.wall_gaps; the whole gap is
## `gap`, Vector2(start, end)): TrackBuilder draws no wall_section there. Visual only. It must read at
## a glance, at speed, in every zone, that the wall-running surface stops: the default
## (wall_gap_marks, standard_wall_gap) marks the cut wall's two ends with the floor cut's orange (the
## skin's gap_edge_color if it has one) from the floor to above the wall-run band, the leading edge
## brightest, with an orange lip along the floor's edge across the gap; and what lies behind the wall
## line is wall_gap_recess()'s (task L4: the opening is closed with an alley between the two cut
## buildings, so no background is left unrendered). Nothing flickers, so it needs nothing for reduced
## flashing. It is one batch, one mesh: the marks, the recess and wall_gap_extras(), a skin's own additions (the
## street below, things across the street, built with the left wall: they don't hang off the wall).
func wall_gap(parent: Node3D, side: int, face_x: float, start: float, end: float, gap: Vector2) -> void:
	var batch := MeshBatch.new()
	wall_gap_marks(batch, side, face_x, start, end, gap)
	if wall_gap_recess_on:
		wall_gap_recess(batch, side, face_x, start, end, gap)
	wall_gap_extras(batch, side, face_x, start, end)
	batch.commit(parent)


## The open space between two standing pieces of a side wall in a level without wall running (task O1;
## LevelLayout.wall_running off: the Terminal, GDD §5 Zone 8: "the arches and the tunnel wall behind them are a
## boundary"), its part between two track distances; the whole opening (a wall gap of the layout) is `gap`,
## Vector2(start, end). TrackBuilder draws it instead of wall_gap() there (TrackBuilder._build_boundary_wall), once per
## chunk it reaches, like any wall gap's part: no wall-running surface stops anywhere in such a level, so it has none of
## wall_gap()'s orange marks. Visual only. What it shows is what lies behind the wall line (a tunnel wall, in the
## Terminal), and with the left wall what a skin draws chunk by chunk below the street (the plane the walls carry).
## A wall gap's recess (wall_gap_recess: an alley between two cut buildings, their end faces at the gap's ends) would
## stand a building's end at every arch, so the default draws a plain wall instead, WALL_OPENING_DEPTH behind the wall
## line all along the opening and WALL_OPENING_TOP tall, with no ends (the arches stand in front of it), over a ground
## a little below the street (standard_wall_gap_recess, in the skin's gap_inside_color lifted toward grey as the
## default recess is), and the skin's extras (wall_gap_extras), in one batch. A broken stump may stand in it
## (wall_stump, drawn after it). The Terminal's skin draws its own (task O4).
func wall_opening(parent: Node3D, side: int, face_x: float, start: float, end: float, gap: Vector2) -> void:
	var batch := MeshBatch.new()
	if wall_gap_recess_on:
		var inside: Variant = get("gap_inside_color")
		var base: Color = inside if inside is Color else CUT_INSIDE_COLOR
		# The gap given past both ends of the part: no end faces.
		standard_wall_gap_recess(batch.layer(MeshKit.solid()), side, face_x, start, end, Vector2(gap.x - 1.0, gap.y + 1.0),
			base.lerp(CUT_RECESS_GREY, WALL_GAP_RECESS_LIFT), base, WALL_OPENING_TOP, WALL_OPENING_FLOOR, WALL_OPENING_DEPTH)
	wall_gap_extras(batch, side, face_x, start, end)
	batch.commit(parent)


## What a skin adds to a wall gap's part besides the marks and the recess (task L4: its own, into the gap's batch, so
## they share its layers): in most skins, with the left wall, the plane far below the street (`below()`), which the
## walls draw whole and a gap must not lose, and what the wall's own pieces hold up (no cables across from a missing
## wall). The default adds nothing.
func wall_gap_extras(_batch: MeshBatch, _side: int, _face_x: float, _start: float, _end: float) -> void:
	pass


## The default wall_gap()'s marks (standard_wall_gap in the skin's gap colours: the lip and the edges), into the gap's
## batch. The cut ends' faces are wall_gap_recess()'s, so it draws the old dark slabs there only when the recess is
## off (wall_gap_recess_on).
func wall_gap_marks(batch: MeshBatch, side: int, face_x: float, start: float, end: float, gap: Vector2) -> void:
	var edge: Variant = get("gap_edge_color")
	var inside: Variant = get("gap_inside_color")
	standard_wall_gap(batch.layer(MeshKit.solid()), side, face_x, start, end, gap,
		edge if edge is Color else CUT_EDGE_COLOR, inside if inside is Color else CUT_INSIDE_COLOR, not wall_gap_recess_on)


## What a side wall gap shows behind the wall line (task L4; the owner: "there is a hole in the wall, and one of the
## buildings in the background doesn't have any other sides to it"): the gap's part [start, end] of an alley between
## the two buildings the gap cuts, so nothing is left unrendered: the two cut ends' faces, the face across, and the
## ground. Visual only, and no collision, like every hook. A runner sees it from the street (the camera looks down the
## track, so the face at the gap's far end is the one in view: it must look like the next building starting, not
## like a hole in the world), from the outer lane and from a wall run, through an opening 13-25 m long (or a Beach
## stretch of 100 m and more), so it is built only where a gap is, never per chunk. It must stay in the zone's palette
## and dimmer than the street's walls (it is a background: nothing of it is a glow or reads as a hazard; the
## buildings' own lit windows and a zone's own street lights stay), and add no shader or material of its own: it goes
## into `batch` (the gap's), in the layers the skin's walls draw with (a skin with a facade shader puts the faces in
## the facade layer), so it costs a gap part at most the facade and solid surfaces (one or two draw calls) and a few
## quads. The default (standard_wall_gap_recess) is plain, in the skin's gap_inside_color lifted toward grey; a skin
## with a look of its own overrides this (the Marketplace's draws its buildings' own colours and window grids).
## DESIGN-TBD (items 926-928 in docs/OPEN_QUESTIONS*.md): that a gap shows an alley, its depth and where its ground lies.
func wall_gap_recess(batch: MeshBatch, side: int, face_x: float, start: float, end: float, gap: Vector2) -> void:
	var inside: Variant = get("gap_inside_color")
	var base: Color = inside if inside is Color else CUT_INSIDE_COLOR
	standard_wall_gap_recess(batch.layer(MeshKit.solid()), side, face_x, start, end, gap,
		base.lerp(CUT_RECESS_GREY, WALL_GAP_RECESS_LIFT), base)


## The standard wall gap look (wall_gap), into `s` (the kit's solid shader): for the part [start, end]
## of the gap `gap` on wall `side`, its ends where they fall in that part.
static func standard_wall_gap(s: MeshLayer, side: int, face_x: float, start: float, end: float, gap: Vector2,
		edge: Color, inside: Color, slabs: bool = true) -> void:
	var out: float = float(side)
	var inward: float = -out * WALL_GAP_EDGE_INSET
	var top: float = WALL_GAP_EDGE_HEIGHT
	var bottom: float = 0.0
	# The lip along the floor's edge, across the part of the gap here.
	s.box(Vector3(face_x - out * WALL_GAP_LIP * 0.5, CUT_LIP_LIFT, -(start + end) * 0.5),
		Vector3(WALL_GAP_LIP, 0.02, end - start), edge, CUT_LIP_GLOW)
	for at: float in [gap.x, gap.y]:
		if at < start - 0.001 or at > end + 0.001:
			continue
		var leading: bool = is_equal_approx(at, gap.x)
		# Toward the solid wall: before the gap's start, past its end.
		var dir: float = -1.0 if leading else 1.0
		# The cut wall's end, dark, from its face back into the block (a skin that draws the gap's recess has the real
		# end face instead: `slabs` false).
		if slabs:
			s.box(Vector3(face_x + out * WALL_GAP_DEPTH * 0.5, (top + bottom) * 0.5, -(at + dir * 0.05)),
				Vector3(WALL_GAP_DEPTH, top - bottom, 0.1), inside)
		# The orange edge on the wall's face, and up the end's corner.
		var glow: float = WALL_GAP_LEADING_GLOW if leading else WALL_GAP_TRAILING_GLOW
		s.box(Vector3(face_x + inward, (top + bottom) * 0.5, -(at + dir * WALL_GAP_EDGE_WIDTH * 0.5)),
			Vector3(0.06, top - bottom, WALL_GAP_EDGE_WIDTH), edge, glow)
		s.box(Vector3(face_x + out * WALL_GAP_EDGE_WIDTH * 0.5, (top + bottom) * 0.5, -(at - dir * 0.02)),
			Vector3(WALL_GAP_EDGE_WIDTH, top - bottom, 0.04), edge, glow)


## The default wall_gap_recess() (task L4), into `s` (the kit's solid shader): for the part [start, end] of the gap
## `gap` on wall `side` (face at world x `face_x`), the ground `ground` WALL_GAP_RECESS_FLOOR below the street, the
## face across it `wall` WALL_GAP_RECESS_DEPTH back, and the two cut ends' faces (each where it falls in the part;
## the far end's faces the runner coming up) from the ground to WALL_GAP_RECESS_TOP, all out of the same plain
## pattern: four quads for the whole gap. `top` and `floor_y` are for a skin whose buildings are lower or taller or
## whose ground lies deeper.
static func standard_wall_gap_recess(s: MeshLayer, side: int, face_x: float, start: float, end: float, gap: Vector2,
		wall: Color, ground: Color, top: float = WALL_GAP_RECESS_TOP, floor_y: float = WALL_GAP_RECESS_FLOOR,
		depth: float = WALL_GAP_RECESS_DEPTH) -> void:
	var out: float = float(side)
	var x_back: float = face_x + out * depth
	var x_min: float = minf(face_x, x_back)
	# The ground (faces up), then the face across (faces the street).
	s.rect(Vector3(x_min, floor_y, -start), Vector3(depth, 0.0, 0.0), Vector3(0.0, 0.0, -(end - start)), ground)
	if side < 0:
		s.rect(Vector3(x_back, floor_y, -start), Vector3(0.0, 0.0, -(end - start)), Vector3(0.0, top - floor_y, 0.0), wall)
	else:
		s.rect(Vector3(x_back, floor_y, -end), Vector3(0.0, 0.0, end - start), Vector3(0.0, top - floor_y, 0.0), wall)
	for at: float in [gap.x, gap.y]:
		if at < start - 0.001 or at > end + 0.001:
			continue
		MeshKit.end_quad(s, x_min, x_min + depth, at, floor_y, top, is_equal_approx(at, gap.x), wall.darkened(0.12), 0.0,
			MeshKit.PAT_PLAIN, 0.0)


## A wall-run gap's lit wall (task J2; LevelLayout.wall_run_gaps: every floor lane is a hole and this wall is the
## way across), its part between two track distances [start, end] on wall `side` (`face_x` the wall face's signed
## world x); `lit` is the whole of it, Vector3(where the stretch to step on starts, where the gap starts, where it
## ends). TrackBuilder draws it after wall_section() for the same chunk, over the wall. Visual only, no collision. It
## must read at a glance, at speed, in every zone, that the wall is the way: the default (standard_wall_run_guide)
## lights the stretch to step on with a tall, bright, framed panel of the ramps' green chevrons streaming ahead, and
## the wall over the gap with a strip of them at running height, in the skin's ramp_color (the colour of the ramps
## that launch wall runs; never a hazard colour: safe things look safe). The chevrons only scroll, like the ramps',
## so Reduced flashing leaves it as it is. DESIGN-TBD (docs/questions/j2.md): the look.
func wall_run_guide(parent: Node3D, side: int, face_x: float, start: float, end: float, lit: Vector3) -> void:
	# Task L5: only a skin with show_wall_run_guide lights it (the Marketplace's); the others leave the hole as the cue.
	if not show_wall_run_guide:
		return
	var color: Variant = get("ramp_color")
	var batch := MeshBatch.new()
	standard_wall_run_guide(batch.layer(MeshKit.solid()), side, face_x, start, end, lit,
		color if color is Color else WALL_RUN_COLOR)
	batch.commit(parent, "WallRunGuide")


## The standard lit wall look (wall_run_guide), into `s` (the kit's solid shader), in `color`: its part [start, end]
## of the whole `lit`. The chevrons run on along the whole of it (UV.x in WALL_RUN_PANEL lengths from lit.x), so the
## parts of one in two chunks meet seamlessly.
static func standard_wall_run_guide(s: MeshLayer, side: int, face_x: float, start: float, end: float, lit: Vector3,
		color: Color) -> void:
	var x: float = face_x - float(side) * WALL_RUN_PROUD
	var bright: Color = color.lerp(Color.WHITE, 0.25)
	# The stretch to step on [lit.x, lit.y], tall and bright, then the strip over the gap [lit.y, lit.z].
	for step: bool in [true, false]:
		var from: float = lit.x if step else lit.y
		var to: float = lit.y if step else lit.z
		var a: float = maxf(from, start)
		var b: float = minf(to, end)
		if b <= a + 0.001:
			continue
		var low: float = WALL_RUN_STEP_LOW if step else WALL_RUN_STRIP_LOW
		var high: float = WALL_RUN_STEP_HIGH if step else WALL_RUN_STRIP_HIGH
		var uv0 := Vector2((a - lit.x) / WALL_RUN_PANEL, 0.0)
		var uv1 := Vector2((b - lit.x) / WALL_RUN_PANEL, 1.0)
		# UV.x runs down the track (u = -z), so the arrows point and stream ahead; the face looks into the street.
		var u := Vector3(0.0, 0.0, -(b - a))
		if side < 0:
			s.rect(Vector3(x, low, TrackGeometry.world_z(a)), u, Vector3(0.0, high - low, 0.0),
				bright if step else color, WALL_RUN_STEP_GLOW if step else WALL_RUN_STRIP_GLOW, MeshKit.PAT_CHEVRON,
				uv0, uv1, 1.0)
		else:
			s.rect(Vector3(x, high, TrackGeometry.world_z(a)), u, Vector3(0.0, low - high, 0.0),
				bright if step else color, WALL_RUN_STEP_GLOW if step else WALL_RUN_STRIP_GLOW, MeshKit.PAT_CHEVRON,
				uv0, uv1, 1.0)
		# Lines along its top and bottom, and up its ends where they fall in this part: from the wall line to just past
		# the panel's face (WALL_RUN_LINE_PROUD), never further off the wall than the skins let anything stand.
		var line_x: float = face_x - float(side) * WALL_RUN_LINE_PROUD * 0.5
		var z_mid: float = TrackGeometry.world_z((a + b) * 0.5)
		for y: float in [low, high]:
			s.box(Vector3(line_x, y, z_mid), Vector3(WALL_RUN_LINE_PROUD, 0.07, b - a), color, WALL_RUN_EDGE_GLOW)
		for at: float in [from, to]:
			if step and at >= start - 0.001 and at <= end + 0.001:
				s.box(Vector3(line_x, (low + high) * 0.5, TrackGeometry.world_z(at)),
					Vector3(WALL_RUN_LINE_PROUD, high - low, 0.09), color, WALL_RUN_EDGE_GLOW)


## The wall gaps (LevelLayout.wall_gaps, whole, as Vector2(start, end)) on `side` near the chunk
## TrackBuilder is about to draw [start, end) (within a chunk's length of it), noted just before its
## wall_section() and wall_gap() calls, so a skin that draws a wall element whole by its centre (a
## shop window) can leave out one that would reach into a gap. Visual only; the default needs nothing.
func note_wall_gaps(_side: int, _gaps: Array[Vector2]) -> void:
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


## A wall fence (task B5; GDD §9.1: "the same pink crackle, strung across the wall-run path between
## emitters on the facade, the way a floor fence crosses a lane"): its energy field and the emitters
## that hold it, in hazard-local space, centred on its hitbox `size`: x from the wall face (on `side`,
## -1 left, 1 right: the face is at x = side * size.x / 2) out toward the lanes, y up its band (`band`:
## &"full", or a partial one's &"low" or &"high"; `floor_y` is the floor's height), z along the track.
## It pulses (ON, WARNING, OFF): follow the hazard's state as a floor fence does (HazardStateVisual,
## through MeshKit.dress_wall_fence), and honour Reduced flashing (the fence shaders do). It must read as
## the floor fence's pink crackle turned onto the wall, in every zone: the same field, an emitter at
## each end of its band on the facade, the band's edges marked by the glowing emitters (the line a
## partial one is passed above or below), and nothing else glowing; the emitters stay within the
## field's reach from the facade, never out into the outer lane. Visual only, like every hook.
## The default (standard_wall_fence) works for every zone: the zone's own fence materials when it has
## them (fence_field_materials(), fence_part_materials(), solid_material(): the pink field, the glowing
## parts and its lit metal), else the kit's with its fence_color, and emitter housings in
## wall_fence_mount_color. A zone may override this to draw its own emitters around the same field.
func wall_fence(hazard: Hazard, size: Vector3, side: int, band: StringName, floor_y: float) -> void:
	var look: Dictionary = wall_fence_look()
	standard_wall_fence(hazard, size, side, band, floor_y, look["field"], look["parts"], look["solid"],
		wall_fence_mount_color, look["color"])


## The materials and colour the default wall fence look (wall_fence()) draws with: {field (ON, WARNING
## and OFF materials for the energy field), parts (the same for the glowing emitters), solid (the lit
## material of the housings), color (the fence pink)}: the zone's own fence materials when it has them
## (fence_field_materials(), fence_part_materials(), solid_material(), fence_color), the kit's otherwise.
func wall_fence_look() -> Dictionary:
	var c: Variant = get("fence_color")
	var color: Color = c if c is Color else WALL_FENCE_COLOR
	var field: Array[Material] = []
	if has_method("fence_field_materials"):
		field.assign(call("fence_field_materials"))
	else:
		field = MeshKit.fence_field_materials(color, 70.0, 210.0)
	var parts: Array[Material] = []
	if has_method("fence_part_materials"):
		parts.assign(call("fence_part_materials"))
	else:
		parts = MeshKit.hazard_part_materials({})
	var solid: Material = call("solid_material") if has_method("solid_material") else MeshKit.solid()
	return {"field": field, "parts": parts, "solid": solid, "color": color}


## The standard wall fence look (wall_fence()): the field (MeshKit.dress_wall_fence) and an emitter at
## each end of its band, mounted on the facade: a plate on the wall, an arm reaching out over the field
## (in `mount_color`, lit by `solid`) with a glowing strip along the side facing the field and a glowing
## cap at its tip (in `color`, with part_materials[0], so they follow the hazard's state). The emitter
## at the floor (a full or a low band) lies along the foot of the wall as a sill.
static func standard_wall_fence(hazard: Hazard, size: Vector3, side: int, band: StringName, floor_y: float,
		field_materials: Array[Material], part_materials: Array[Material], solid: Material, mount_color: Color,
		color: Color) -> void:
	MeshKit.dress_wall_fence(hazard, size, side,
		wall_fence_mounts(size, side, floor_y, part_materials[0], solid, mount_color, color), field_materials, part_materials)


## The emitter housings of the standard wall fence look (standard_wall_fence), cached by their sizes,
## side, materials and colours. `hot` is the glowing parts' material, `solid` the housings'.
static func wall_fence_mounts(size: Vector3, side: int, floor_y: float, hot_material: Material, solid: Material,
		mount_color: Color, color: Color) -> ArrayMesh:
	var key: String = "wall_mounts_%s_%d_%s_%d_%d_%s_%s" % [size, side, floor_y, hot_material.get_instance_id(),
		solid.get_instance_id(), mount_color, color]
	var mesh: ArrayMesh = _wall_fence_meshes.get(key)
	if mesh != null:
		return mesh
	var batch := MeshBatch.new()
	var metal: MeshLayer = batch.layer(solid)
	var hot: MeshLayer = batch.layer(hot_material)
	var half: Vector3 = size * 0.5
	var face: float = side * half.x
	var reach: float = size.x + MeshKit.WALL_FIELD_GROW
	var out: float = -side
	for end: int in [-1, 1]:
		# -1: the emitter at the bottom of the band, 1: at its top. Each lies just outside the field, with
		# its glowing strip along the side facing it.
		var on_floor: bool = end < 0 and absf(-half.y - floor_y) < 0.01
		var y: float = floor_y + WALL_EMITTER_THICKNESS * 0.5 if on_floor else end * (half.y + WALL_EMITTER_THICKNESS * 0.5)
		var toward: float = -end
		# The plate on the facade (not for the sill at the foot of the wall).
		if not on_floor:
			metal.box(Vector3(face + out * 0.025, y, 0.0), Vector3(0.05, 0.42, 0.52), mount_color.darkened(0.25))
		# The arm, from the facade out over the field.
		metal.box(Vector3(face + out * reach * 0.5, y, 0.0), Vector3(reach, WALL_EMITTER_THICKNESS, 0.18), mount_color)
		# Its glowing strip, along the side facing the field, and the cap at its tip.
		hot.box(Vector3(face + out * reach * 0.5, y + toward * (WALL_EMITTER_THICKNESS * 0.5 + 0.012), 0.0),
			Vector3(reach - 0.04, 0.024, 0.08), color, 0.9)
		hot.box(Vector3(face + out * (reach + 0.04), y, 0.0), Vector3(0.08, WALL_EMITTER_THICKNESS + 0.06, 0.22), color, 1.0)
	mesh = batch.to_mesh()
	_wall_fence_meshes[key] = mesh
	return mesh


## A ceiling fence (task I4; GDD §3, "Ceiling scenarios": a fenced ceiling's rows; TrackBuilder._build_ceiling_fence):
## an electric fence hanging from the ceiling's underside across a lane, in hazard-local space, centred on its
## hitbox `size` (x across the lane, y down from the underside at +size.y / 2, z along the track). It's always on;
## follow the hazard's state all the same (an EMP switches it off: HazardStateVisual, through MeshKit.dress_fence)
## and honour Reduced flashing (the fence shaders do). It must read as the floor fence's pink crackle hung from
## the ceiling, in every zone, from the floor before the pad that lifts a rider into it: the same field, held
## by an emitter along the underside, nothing else glowing; and nothing below the field (the chase camera passes
## just below it, RunCamera.ceiling_limit), nothing out past its lane. The default (standard_ceiling_fence) works
## for every zone, with the zone's own fence materials (wall_fence_look()) and its wall_fence_mount_color for the
## emitter's housing. A zone may override this to draw its own emitter around the same field.
func ceiling_fence(hazard: Hazard, size: Vector3) -> void:
	var look: Dictionary = wall_fence_look()
	standard_ceiling_fence(hazard, size, look["field"], look["parts"], look["solid"], wall_fence_mount_color, look["color"])


## The standard ceiling fence look (ceiling_fence()): the field (MeshKit.dress_fence: a little wider than the
## hitbox, and a little deeper, which still leaves it above the chase camera) and its emitter along the underside
## (ceiling_fence_mounts).
static func standard_ceiling_fence(hazard: Hazard, size: Vector3, field_materials: Array[Material],
		part_materials: Array[Material], solid: Material, mount_color: Color, color: Color) -> void:
	MeshKit.dress_fence(hazard, size, ceiling_fence_mounts(size, part_materials[0], solid, mount_color, color),
		field_materials, part_materials)


## The emitter of the standard ceiling fence look: a housing flush with the underside across the field's width (in
## `mount_color`, lit by `solid`), a glowing strip along its face toward the field and a glowing cap at each end
## (in `color`, with `hot_material`, so they follow the hazard's state). Hazard-local, the underside at
## +size.y / 2. Cached by its size and materials.
static func ceiling_fence_mounts(size: Vector3, hot_material: Material, solid: Material, mount_color: Color,
		color: Color) -> ArrayMesh:
	var key: String = "ceiling_mounts_%s_%d_%d_%s_%s" % [size, hot_material.get_instance_id(), solid.get_instance_id(),
		mount_color, color]
	var mesh: ArrayMesh = _ceiling_fence_meshes.get(key)
	if mesh != null:
		return mesh
	var batch := MeshBatch.new()
	var metal: MeshLayer = batch.layer(solid)
	var hot: MeshLayer = batch.layer(hot_material)
	var top: float = size.y * 0.5
	var y: float = top - WALL_EMITTER_THICKNESS * 0.5
	metal.box(Vector3(0.0, y, 0.0), Vector3(size.x + 0.12, WALL_EMITTER_THICKNESS, 0.24), mount_color)
	hot.box(Vector3(0.0, top - WALL_EMITTER_THICKNESS - 0.012, 0.0), Vector3(size.x, 0.024, 0.08), color, 0.9)
	for side: float in [-1.0, 1.0]:
		hot.box(Vector3(side * (size.x * 0.5 + 0.04), y, 0.0), Vector3(0.08, WALL_EMITTER_THICKNESS + 0.04, 0.26), color, 1.0)
	mesh = batch.to_mesh()
	_ceiling_fence_meshes[key] = mesh
	return mesh


## A return pad (task I4; GDD §3, "Ceiling scenarios": the treasure stash's; TrackBuilder._build_return_pad): a
## trigger on a ceiling's underside that drops a rider who steps on it back to the floor. `trigger` is turned upside
## down, so this draws in its space as pad() does for a pad on the floor (the underside at -size.y / 2 in it): the
## default is the anti-grav pad's own look, pointing back down at the floor (GDD §3 asks it to look safe, with no new
## hazard colour). A zone may override it with a look of its own.
func return_pad(trigger: Area3D, size: Vector3) -> void:
	pad(trigger, size)


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


## The colours a zone doodad's pieces fly off in when the dash smashes it (GDD §3, owner, October 8,
## 2026; task H5; RunEffects.rubble), for `body` as doodad() dressed it (TrackBuilder asks right after).
## By default its look's own: the main lit colours its meshes were built from, which the look's builder
## tagged them with (tag_debris_colors; every zone's own look and the default do), or doodad_palette for
## a look that tagged none. A skin may override it, say to leave out part of a look; every skin works
## without doing so. Lit colours only: the pieces are solid scenery and never glow.
func doodad_debris_colors(body: Node3D, _size_class: StringName, _side: int, _look_seed: int) -> PackedColorArray:
	var out := PackedColorArray()
	for node: Node in body.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (node as MeshInstance3D).mesh
		if mesh != null and mesh.has_meta(DEBRIS_COLORS_META):
			out.append_array(mesh.get_meta(DEBRIS_COLORS_META) as PackedColorArray)
	if out.is_empty():
		out = doodad_palette.duplicate()
	return out


## Tags `mesh`, built from `batch`, with the batch's main lit colours (MeshBatch.palette, at most
## DEBRIS_COLORS_MAX) for doodad_debris_colors, and returns it. A doodad look's builder calls it once per
## mesh it caches, while the batch's vertices are still on the CPU.
static func tag_debris_colors(mesh: ArrayMesh, batch: MeshBatch) -> ArrayMesh:
	if mesh != null:
		mesh.set_meta(DEBRIS_COLORS_META, batch.palette(DEBRIS_COLORS_MAX))
	return mesh


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
	return tag_debris_colors(batch.to_mesh(), batch)


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


## A dash wall (task H7a; GDD §9.14, owner, October 8, 2026: "use the same assets as the side walls, but ...
## facing towards the player, looking like a building in the middle of the street"): a building standing
## across every floor lane, which the runner dashes through and which crumbles into rubble. `body` is its node
## (TrackBuilder._build_dash_wall, a DashBreakable), centred on the box its look fills, `size` (width across
## the track, height, depth along it): the floor is at -size.y / 2, its face toward the oncoming runner at
## +size.z / 2, and its sides stop short of the side walls by the strip a wall runner passes it in
## (MovementTuning.dash_wall_wall_room). `look_seed` varies the look (the same seed, the same look).
## Every look keeps to these (and task H7b's per-zone looks, built from each zone's side-wall kit, must too):
## - inside the box, filling its face: its hitbox is the box a little smaller (forgiving), so what looks like
##   contact is contact, and the open strip beside each side wall shows that a wall runner passes it;
## - a building's face, solid: it reads as something to dash through, with nothing in a hazard colour that
##   glows (GDD §5) and nothing that reads as a sign, a fence, a barrier's stripes or an enemy; cracks or a
##   breakable look are welcome; a cue, if any, in the dash's own language (PlayerSuit.GLOW_PALE), never a
##   hazard's;
## - everything under `body` (no top-level nodes): the break hides `body` whole (DashBreakable.smash);
## - cheap: one mesh per wall from cached templates (the kit's MeshBatch), drawn on the Compatibility renderer;
##   nothing that flickers (or it must honour Reduced flashing).
## The pieces it crumbles into take its colours (dash_wall_debris_colors). The default is a plain three-storey
## facade in dash_wall_colors(): pilasters, floor slabs, a plinth and a cornice, rows of dark windows and
## cracks across its face (default_dash_wall_mesh), lit by dash_wall_material(): the grey box's, and a skin's that
## has no look of its own. Every zone has one (task H7b): a block built from its own side walls' facade shader,
## patterns and colours (scripts/world/skins/<zone>/<zone>_dash_wall.gd, with the helpers they share in
## DashWallKit), drawing with the materials the skin names in dash_wall_materials().
func dash_wall(body: Node3D, size: Vector3, look_seed: int) -> void:
	var colors: PackedColorArray = dash_wall_colors()
	var material: Material = dash_wall_material()
	var look: int = posmod(look_seed, DASH_WALL_LOOKS)
	var key: String = var_to_str([size, look, colors, material.get_instance_id()])
	var mesh: ArrayMesh = _dash_wall_meshes.get(key)
	if mesh == null:
		mesh = default_dash_wall_mesh(size, look, colors)
		_dash_wall_meshes[key] = mesh
	var inst := MeshInstance3D.new()
	inst.name = "Look"
	inst.mesh = mesh
	inst.material_override = material
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(inst)


## The default dash wall look's colours (dash_wall()), sRGB: walls, trim, window glass and cracks. A zone
## returns its own side walls' (task H7a); dash_wall_palette otherwise.
func dash_wall_colors() -> PackedColorArray:
	return dash_wall_palette


## The material the default dash wall look draws with: the zone's own lit kit material where it has one
## (solid_material(), so the wall is lit and dimmed like its side walls), else the kit's (MeshKit.solid()).
func dash_wall_material() -> Material:
	if has_method("solid_material"):
		var m: Variant = call("solid_material")
		if m is Material:
			return m
	return MeshKit.solid()


## The materials a dash wall's look may draw with (task H7b): the surfaces of its meshes (or their instance's
## override) are all among these, and every one is lit, never glowing (test_dash_walls). The default look
## draws with dash_wall_material(); a zone whose wall is built from its facade shader lists that too.
func dash_wall_materials() -> Array[Material]:
	return [MeshKit.solid(), dash_wall_material()]


## The colours a dash wall's pieces fly off in when it crumbles (task H7a; RunEffects), for `body` as
## dash_wall() dressed it (TrackBuilder asks right after): its look's own main lit colours, which the look's
## builder tagged its meshes with (tag_debris_colors; the default does), else its walls' and trim's
## (dash_wall_colors()). A skin may override it. Lit colours only: the pieces never glow.
func dash_wall_debris_colors(body: Node3D, _look_seed: int) -> PackedColorArray:
	var out := PackedColorArray()
	for node: Node in body.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (node as MeshInstance3D).mesh
		if mesh != null and mesh.has_meta(DEBRIS_COLORS_META):
			out.append_array(mesh.get_meta(DEBRIS_COLORS_META) as PackedColorArray)
	if out.is_empty():
		var colors: PackedColorArray = dash_wall_colors()
		for i: int in mini(colors.size(), 2):
			out.append(colors[i])
	return out


## The default dash wall look (dash_wall()) for a box of `size`, look `look` (0 to DASH_WALL_LOOKS - 1), in
## `colors` (walls, trim, glass, cracks; sRGB): a facade of DASH_WALL_STOREY storeys on a plinth under a
## cornice, between pilasters at its sides, its walls set back DASH_WALL_RECESS from its face, with a row of
## dark windows in each storey (a bay of DASH_WALL_BAY each) and cracks spreading across its lower storeys
## from where a runner hits it. Its face, sides and top only (nobody sees its back or its underside before it
## breaks). Lit, never glowing, inside the box. One surface for a lit kit material.
static func default_dash_wall_mesh(size: Vector3, look: int, colors: PackedColorArray) -> ArrayMesh:
	var wall: Color = colors[0] if colors.size() > 0 else Color(0.35, 0.36, 0.39)
	var trim: Color = colors[1] if colors.size() > 1 else wall.darkened(0.3)
	var glass: Color = colors[2] if colors.size() > 2 else Color(0.07, 0.08, 0.1)
	var crack: Color = colors[3] if colors.size() > 3 else glass.darkened(0.5)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["dash_wall", look])
	var hx: float = size.x * 0.5
	var y0: float = -size.y * 0.5
	var top: float = size.y * 0.5
	var back: float = -size.z * 0.5
	var face: float = size.z * 0.5
	var wall_face: float = face - minf(DASH_WALL_RECESS, size.z * 0.25)
	var pil: float = minf(DASH_WALL_PILASTER, size.x * 0.1)
	var plinth_top: float = y0 + minf(DASH_WALL_PLINTH, size.y * 0.15)
	var cornice_bottom: float = top - minf(DASH_WALL_CORNICE, size.y * 0.12)
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(null)
	var shown: int = MeshKit.FACE_PZ | MeshKit.FACE_PX | MeshKit.FACE_NX | MeshKit.FACE_PY
	# The walls between the pilasters, set back from the face; a tone per look.
	var tone: float = [0.0, 0.05, -0.04, 0.09][look % 4]
	s.box_between(Vector3(-hx + pil, plinth_top, back), Vector3(hx - pil, cornice_bottom, wall_face),
		wall.lightened(tone) if tone > 0.0 else wall.darkened(-tone), 0.0, MeshKit.PAT_PLAIN, shown)
	# The pilasters at its sides, the plinth along its foot and the cornice along its top, out to the face.
	for side: float in [-1.0, 1.0]:
		s.box_between(Vector3(side * hx, y0, back), Vector3(side * (hx - pil), cornice_bottom, face), trim, 0.0,
			MeshKit.PAT_PLAIN, shown)
	s.box_between(Vector3(-hx + pil, y0, back), Vector3(hx - pil, plinth_top, face - 0.04), trim.darkened(0.2), 0.0,
		MeshKit.PAT_PLAIN, shown)
	s.box_between(Vector3(-hx, cornice_bottom, back), Vector3(hx, top, face), trim, 0.0, MeshKit.PAT_PLAIN, shown)
	# Storeys: a floor slab at each, and a row of windows in each bay.
	var inner: float = size.x - 2.0 * pil
	var bays: int = maxi(1, floori(inner / DASH_WALL_BAY))
	var bay: float = inner / float(bays)
	var storey: float = DASH_WALL_STOREY
	var y: float = plinth_top
	var level: int = 0
	while y + storey * 0.6 <= cornice_bottom:
		var y1: float = minf(y + storey, cornice_bottom)
		if level > 0:
			s.box_between(Vector3(-hx + pil, y - 0.11, back), Vector3(hx - pil, y + 0.11, face - 0.03), trim, 0.0,
				MeshKit.PAT_PLAIN, shown)
		var win := Vector2(minf(DASH_WALL_WINDOW.x, bay * 0.6), minf(DASH_WALL_WINDOW.y, (y1 - y) * 0.6))
		var cy: float = (y + y1) * 0.5 + (0.0 if level > 0 else -0.1)
		for b: int in bays:
			var cx: float = -hx + pil + bay * (b + 0.5)
			# The ground storey's are shuttered on some looks (a shop front), the rest dark glass in a frame.
			var shuttered: bool = level == 0 and (look + b) % 3 == 0
			var pane: Color = trim.darkened(0.35) if shuttered else glass
			s.box(Vector3(cx, cy, wall_face + 0.015), Vector3(win.x, win.y, 0.03), pane, 0.0,
				MeshKit.PAT_GRILLE if shuttered else MeshKit.PAT_GLASS, MeshKit.FACE_PZ)
			MeshKit.frame(s, Vector3(cx, cy, wall_face + 0.04), win.x + 0.16, win.y + 0.16, 0.08, 0.08, trim)
		y = y1
		level += 1
	# Cracks spreading from where a runner hits it, across the lower storeys: a breakable face.
	var hits: int = 2 + look % 2
	for k: int in hits:
		var at := Vector2(lerpf(-hx + pil + 0.6, hx - pil - 0.6, (k + rng.randf_range(0.25, 0.75)) / float(hits)),
			y0 + rng.randf_range(1.1, 1.9))
		var arms: int = rng.randi_range(4, 6)
		for a: int in arms:
			var angle: float = TAU * (a + rng.randf_range(-0.3, 0.3)) / float(arms)
			_dash_wall_crack(s, at, angle, rng.randi_range(3, 5), rng, Vector4(-hx + 0.05, hx - 0.05, y0 + 0.05,
				top - 0.05), face, crack)
	return tag_debris_colors(batch.to_mesh(), batch)


## One crack of the default dash wall look: a zigzag of thin segments from `from` (x, y on the face) heading
## at `angle`, `segments` long, kept within `bounds` (x min, x max, y min, y max), standing proud of the walls,
## the plinth and the floor slabs to just short of the face (z `face`), so it shows on them and stays inside
## the wall's box.
static func _dash_wall_crack(s: MeshLayer, from: Vector2, angle: float, segments: int, rng: RandomNumberGenerator,
		bounds: Vector4, face: float, color: Color) -> void:
	var p: Vector2 = from
	var heading: float = angle
	var width: float = 0.07
	for i: int in segments:
		heading += rng.randf_range(-0.6, 0.6)
		var length: float = rng.randf_range(0.45, 1.0) * (1.0 - 0.12 * i)
		var q: Vector2 = p + Vector2(cos(heading), sin(heading)) * length
		q = Vector2(clampf(q.x, bounds.x, bounds.y), clampf(q.y, bounds.z, bounds.w))
		var d: Vector2 = q - p
		if d.length() < 0.05:
			break
		var mid: Vector2 = (p + q) * 0.5
		var depth: float = DASH_WALL_RECESS + 0.02
		var xform := Transform3D(Basis(Vector3.BACK, d.angle()) * Basis.from_scale(Vector3(d.length() + width, width, depth)),
			Vector3(mid.x, mid.y, face - depth * 0.5 - 0.002))
		s.box_xform(xform, color, 0.0, MeshKit.PAT_PLAIN, MeshKit.FACE_PZ | MeshKit.FACE_PY | MeshKit.FACE_NY)
		p = q
		width *= 0.82


## A falling gantryway's walkway (task Q3; GDD §5, Zone 9, owner, October 21, 2026: "an upper walkway over one lane
## only, looking like a ceiling section"; Gantryway): `body` is the node that falls, centred on the walkway's box `size`
## (width across its lane, its deck's depth, its length along the track): its underside at -size.y / 2, its near end,
## toward the oncoming runner, at +size.z / 2. It hangs at the ceilings' height until the dash breaks its pillar. Every
## look keeps to these (and a zone's own look must too: test_gantryways):
## - inside its box, but for railings standing up to GantrywayKit.RAIL_HEIGHT above it and icicles hanging down to
##   GantrywayKit.ICICLE_MAX below it: what falls is what the runner sees;
## - solid, lit and never glowing, nothing in a hazard colour and nothing that reads as a sign or a fence: its warning as
##   it falls (its shadow, the red line on its lane, the creak) is the Gantryway's own, the same in every zone;
## - drawn with materials that dissolve near the camera (gantryway_material()): the chase camera passes under it as it
##   falls, and through its pillar's column when the runner is in the lane beside it;
## - everything under `body`; cheap: one mesh from cached templates, drawn on the Compatibility renderer.
## The default is a frosted steel catwalk (GantrywayKit.walkway_mesh) in gantryway_palette.
func gantryway(body: Node3D, size: Vector3, look_seed: int) -> void:
	GantrywayKit.dress(body, GantrywayKit.walkway_mesh(size, look_seed, gantryway_palette), gantryway_material())


## A falling gantryway's pillar (task Q3; GDD §5: "pillars stand in the floor lanes holding them up. Dashing through a
## pillar knocks down its long section of gantryway"): `body` is its DashBreakable (TrackBuilder: a small zone doodad's
## box, centred on it, which it pushes and blocks like one, its floor at `floor_y`), `size` the box its look fills
## (width and length the doodad's, its height from that floor up to the walkway's underside), pushing to `side` (-1
## left, +1 right). As gantryway()'s looks, and: it reads as something a dash breaks (cracks, welds), never as a hazard;
## everything under `body` (the dash's break hides it whole); its colours tagged for the pieces it breaks into
## (gantry_pillar_debris_colors). The default is an icy steel column (GantrywayKit.pillar_mesh).
func gantry_pillar(body: Node3D, size: Vector3, floor_y: float, side: int, look_seed: int) -> void:
	var look: MeshInstance3D = GantrywayKit.dress(body, GantrywayKit.pillar_mesh(size, side, look_seed, gantryway_palette),
		gantryway_material())
	look.position = Vector3(0.0, floor_y + size.y * 0.5, 0.0)


## A fallen gantryway (task Q3; GDD §5, proposed: "once down, it lies flat and the runner runs over it harmlessly"):
## `body` is centred on its box `size` (the walkway's width and length, a little height), on the floor of its lane.
## Low and flat: the runner runs through it (it has no collision), so nothing stands above its box. As gantryway()'s
## looks otherwise. The default is the catwalk crushed flat (GantrywayKit.wreck_mesh).
func gantryway_wreck(body: Node3D, size: Vector3, look_seed: int) -> void:
	GantrywayKit.dress(body, GantrywayKit.wreck_mesh(size, look_seed, gantryway_palette), gantryway_material())


## The material the default gantryway looks draw with (GantrywayKit.material(): the kit's lit look, dissolving near
## the camera). A zone drawing its own looks draws them in materials that do the same.
func gantryway_material() -> Material:
	return GantrywayKit.material()


## The colours a gantryway's pillar breaks into (RunEffects' rubble as the dash smashes it, and its column's pieces as
## its walkway goes: Gantryway), for `body` as gantry_pillar() dressed it: its look's own main lit colours (the builder
## tagged them: tag_debris_colors), else the kit's steel and frost.
func gantry_pillar_debris_colors(body: Node3D, _side: int, _look_seed: int) -> PackedColorArray:
	return _tagged_colors(body, PackedColorArray([GantrywayKit.STEEL_LIGHT, GantrywayKit.FROST]))


## The colours a gantryway's pieces fly in as it lands (Gantryway), for `body` as gantryway() dressed it: its look's
## own (tagged), else the kit's steel and frost.
func gantryway_debris_colors(body: Node3D, _look_seed: int) -> PackedColorArray:
	return _tagged_colors(body, PackedColorArray([GantrywayKit.STEEL, GantrywayKit.STEEL_LIGHT]))


## The snow and ice that shake loose from a gantryway as it shudders, and fly as it lands (Gantryway): lit, never
## glowing. The default: snow, frost and ice in gantryway_palette (GantrywayKit.snow_colors).
func gantryway_snow_colors() -> PackedColorArray:
	return GantrywayKit.snow_colors(gantryway_palette)


## The main lit colours tagged on the meshes under `body` (tag_debris_colors), or `fallback` where none is.
static func _tagged_colors(body: Node3D, fallback: PackedColorArray) -> PackedColorArray:
	var out := PackedColorArray()
	for node: Node in body.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (node as MeshInstance3D).mesh
		if mesh != null and mesh.has_meta(DEBRIS_COLORS_META):
			out.append_array(mesh.get_meta(DEBRIS_COLORS_META) as PackedColorArray)
	return out if not out.is_empty() else fallback


func finish_line(_parent: Node3D, _width: float, _distance: float) -> void:
	pass
