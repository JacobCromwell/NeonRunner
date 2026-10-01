class_name GoldenPalaceSkin
extends GoldenSkin
## Golden 3, "the Golden Palace" (GDD §5, Zone 6 the Golden Zone: "Final level: the Golden Palace"):
## the player runs inside the palace, so huge and grand that its interior is basically the size of a
## city. It plays like any other level; only the skin is an interior: floors, walls and ceilings are
## the palace's own halls, galleries and arches. The final boss follows it.
## Reuses D6a's materials and statue kit wholesale (extends GoldenSkin): the same white, cream, red
## and gold palette (gold reflective metal, never glowing neon), the same cult emblem and feed
## (CultEmblem, CultFeed), the same statue kit (GoldenStatue) and the same hazards, triggers and
## finish line (fence(), wall_sign(), pad(), ramp(), speed_pad(), finish_line(), all inherited
## unchanged). It keeps GoldenSkin's sky and lighting too (make_environment(), apply_darkness()),
## tuned in data for an enormous vaulted interior rather than a dusk skyline (GDD §5: "an enormous
## vaulted space, perhaps with distant halls and light shafts"): data/skins/golden_palace_skin.tres
## sets moon_radius to 0 (no moon indoors) and make_environment() below turns the stars off too (the
## one export make_environment() doesn't expose); the far "skyline" and its warm haze carry over
## unchanged, read as distant halls glimpsed through the haze.
## Only floor_segment(), wall_section() and ceiling_section()/hull() are overridden, replacing the
## Golden Zone's walkways-over-water, opulent facades and bridges with the palace's own floor
## (GoldenPalaceFloor), colonnade (GoldenPalaceWalls) and ceilings (GoldenPalaceCeilings). Every
## other export carries over unchanged (GDScript can't redeclare an exported property in a
## subclass, CLAUDE.md principle 7: tunable numbers live in data, not code), so the palace's own
## data file (data/skins/golden_palace_skin.tres) sets fresh values for the ones its colonnade and
## ceilings reuse for a new purpose: lot_length (the colonnade's bay spacing, denser than the Golden
## Zone's city lots), gallery_share/statue_share/banner_share/relief_share (which of a bay's four
## kinds of content it holds), banner_width/banner_length (a tapestry's size) and
## bridge_weight/archway_weight/yacht_weight (the ceiling pieces' weights: a chandelier takes the
## yacht's role, hanging over any width). The Golden Zone's walkway, exterior-building and overhead
## exports (the Walkways group, most of the Buildings group, the Overhead group) stay at their
## defaults, unused -- an exterior city's shapes, not an interior's -- while its Gold and red,
## Statues, Hazards, Pads/ramps/finish and Environment groups carry over meaningfully as they are.
## Visuals only: TrackBuilder owns every collision shape and gameplay node, and all variety comes
## from hashing track positions (MeshKit.hash_i), so a chunk looks the same whenever it is built.

@export_group("Floor")
## DESIGN-TBD (docs/questions/d6b.md): the palace floor's gold inlay runner down each lane's centre
## (GDD §5: "a palace floor (marble, inlay, gold runners)"); half its width.
@export_range(0.05, 0.6, 0.01, "suffix:m") var runner_half_width: float = 0.2

@export_group("Colonnade")
## DESIGN-TBD (docs/questions/d6b.md): how high the colonnade's pilasters and bays rise above
## frieze_top, comfortably clear of every bay's content (an alcove's statue, GoldenStatue.STATURE +
## PEDESTAL_HEIGHT above statue_min_height; a tapestry, the data file's banner_length tall).
@export_range(10.0, 26.0, 0.5, "suffix:m") var pilaster_height: float = 15.0

@export_group("Palace ceilings")
## DESIGN-TBD (docs/questions/d6b.md): how far above its underside a ceiling piece's structure may
## rise (GDD §5: "the vast hall's ceiling stays far above"); there is no wall decoration to duck
## under here, unlike the Golden Zone's walls.
@export_range(2.0, 12.0, 0.1, "suffix:m") var hall_clear_height: float = 7.5

var _floor: GoldenPalaceFloor
var _walls: GoldenPalaceWalls
var _palace_ceilings: GoldenPalaceCeilings

# No _init() override: GoldenSkin._init() runs unchanged and sets enemy_variant = &"golden" (the
# Golden Palace's cyborgs wear the same ceremonial enforcer, GDD §9.2).


## The Golden Zone's sky and fog, with the stars turned off (its one sky field make_environment()
## doesn't expose as an export): a vast interior has none. data/skins/golden_palace_skin.tres turns
## the moon off too (moon_radius = 0), the field that is exported.
func make_environment() -> Environment:
	var env: Environment = super.make_environment()
	var sky_material: ShaderMaterial = env.sky.sky_material as ShaderMaterial
	if sky_material != null:
		sky_material.set_shader_parameter(&"star_amount", 0.0)
	return env


func floor_segment(parent: Node3D, center: Vector3, size: Vector3, lane_x: float, edge_start: bool,
		edge_end: bool) -> void:
	var batch := MeshBatch.new()
	palace_floor().build(batch, center, size, lane_x, edge_start, edge_end)
	batch.commit(parent)


func wall_section(parent: Node3D, side: int, face_x: float, start: float, end: float) -> void:
	_wall_x = absf(face_x)
	var batch := MeshBatch.new()
	walls().build(batch, side, face_x, start, end)
	if side < 0:
		palace_floor().below(batch, absf(face_x), start, end)
	batch.commit(parent)


## A ceiling over its lanes, reaching to the wall faces where the section says they are (GDD §3,
## "narrow ceilings build from their lanes": GoldenPalaceCeilings builds a kind across every lane
## only where the section is full width; over fewer lanes it builds narrower).
func ceiling_section(parent: Node3D, section: CeilingSection) -> void:
	palace_ceilings().build(parent, section.center, section.size, section.lane_edges_x, section.wall_x)


## A ceiling given as its box alone (the wall face from the chunk's walls, as wall_section() saw it
## last, like the Golden Zone's).
func hull(parent: Node3D, center: Vector3, size: Vector3, lane_edges_x: Array[float]) -> void:
	palace_ceilings().build(parent, center, size, lane_edges_x, _wall_x if _wall_x > 0.0 else size.x * 0.5 + 0.3)


# --- The statue kit, the cult's emblem and feed (reused from the colonnade's bays, not the Golden
# Zone's exterior ledges and towers) -----------------------------------------------------------

func statue_spots(side: int, face_x: float, start: float, end: float) -> Array[Dictionary]:
	return walls().statue_spots(side, face_x, start, end)


func feed_boards(side: int, face_x: float, start: float, end: float) -> Array[Dictionary]:
	return walls().feed_boards(side, face_x, start, end)


func cult_emblems(side: int, face_x: float, start: float, end: float) -> Array[Dictionary]:
	return walls().cult_emblems(side, face_x, start, end)


func palace_floor() -> GoldenPalaceFloor:
	if _floor == null:
		_floor = GoldenPalaceFloor.new(self)
	return _floor


func walls() -> GoldenPalaceWalls:
	if _walls == null:
		_walls = GoldenPalaceWalls.new(self)
	return _walls


func palace_ceilings() -> GoldenPalaceCeilings:
	if _palace_ceilings == null:
		_palace_ceilings = GoldenPalaceCeilings.new(self)
	return _palace_ceilings


func _solid_params() -> Dictionary:
	var p: Dictionary = super._solid_params()
	var marks: PackedFloat32Array = wall_height_marks
	p["gp_runner"] = srgb(gold_color)
	p["gp_runner_half"] = runner_half_width
	p["gp_mark_a"] = marks[0] if marks.size() > 0 else -10.0
	p["gp_mark_b"] = marks[1] if marks.size() > 1 else -10.0
	p["gp_mark_color"] = srgb(wall_mark_color)
	return p
