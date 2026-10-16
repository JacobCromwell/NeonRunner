extends RefCounted
## Generator rules for the `wall_run_gaps` feature (task J2; the owner, October 15, 2026: "sections, especially in later
## zones and levels, where there is a gap over the ENTIRE floor (every lane), and the only way to cross is a wall run").
## Not an enemy: a set piece of the track, placed with the rules (as the dash walls and the ceiling scenarios are) so the
## level makes room for it before it fills up. WallRunGapPlacement (scripts/world/wall_run_gap_placement.gd) has the
## rules of where one goes and its shape; this script is the generator's hook:
## - apply(), last of the rules (RUN_AFTER every other feature's), after every enemy and ceiling the rules plan and before
##   the danger density pass, the cyborgs in charge paths, the wider gaps, the fill pass, the zone doodads and the rest of
##   the dash walls: it places the level's wall-run gaps where nothing the rules planned is in the way (plain pieces of
##   the patterns go), into LevelGenerator.wall_run_gap_result;
## - every pass after it keeps off each one's clear stretch, from its clear run-in to the end of its landing floor, in
##   every lane: doodad_keep_outs (the passes that read the rules' keep-outs: the danger density pass's enemies and rows,
##   the cyborgs in charge paths, the wider gaps, the zone doodads, the dash walls, the wall fences' drop windows) and
##   fill_keep_outs (the fill pass); a cyborg keeps its obstacle margin from it, its walk and panic run stop short of it
##   (CyborgRules.obstacle_spans), and a wall enemy the danger density pass adds keeps off its lit wall
##   (on_wall_section). The wall fences and the side wall gaps keep off its lit wall (WallFencePlacement.keep_outs,
##   WallGapPlacement.keep_outs).
## - positions(): where each one's holes start (LevelGenerator.feature_positions: the every-feature check).

const FEATURE: String = "wall_run_gaps"
## Every feature whose rules plan something on the track: a wall-run gap goes where none of it is.
const RUN_AFTER: Array[String] = ["ramps", "ceilings", "pulsing", "speed_pads", "cyborg", "window_cyborg", "host",
	"hover_truck", "octodog", "screech", "screech_vents", "drone", "generator", "wall_fences", "wall_fences_partial",
	"buzz_overdrive", "barnacle_turret", "tithe_collector", "resonator", "gilded_sentinel", "enforcer_truck",
	"floor_cutter", "treasure_stash", "fenced_ceiling", "dash_wall"]


static func apply(gen: LevelGenerator) -> void:
	gen.wall_run_gap_result = WallRunGapPlacement.place(gen)


## Every wall-run gap in `layout`: where its holes start (LevelGenerator.feature_positions).
static func positions(layout: LevelLayout) -> Array[float]:
	var out: Array[float] = []
	for w: Dictionary in layout.wall_run_gaps:
		out.append(float(w["start"]))
	return out


## What the passes after the rules keep off in every lane (LevelGenerator.rules_doodad_keep_outs): each wall-run gap's
## clear stretch, from its clear run-in to the end of its landing floor (WallRunGapPlacement.keep_out: KEEP_MARGIN more
## at both ends), {from, to, type}. Not a calm stretch: nothing a later pass adds stands or attacks in it. The danger
## density pass keeps its clearance from it as from any fixed stretch (DangerDensity); the fill pass (fill_keep_outs,
## without its margin) and the zone doodads keep off it as it stands, the wider gaps, the planted cyborgs and the dash
## walls with their own zones' margins, so what they add may stand close past its ends, as the patterns placed before
## it may (the landing floor's landing_slack_seconds is the room after the latest step onto the wall).
static func doodad_keep_outs(gen: LevelGenerator) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for w: Dictionary in gen.layout.wall_run_gaps:
		var k: Vector2 = WallRunGapPlacement.keep_out(w)
		out.append({"from": k.x, "to": k.y, "type": FEATURE})
	return out


## What the fill pass keeps off (LevelGenerator.rules_fill_keep_outs): each wall-run gap's clear stretch
## (WallRunGapPlacement.keep_out).
static func fill_keep_outs(gen: LevelGenerator) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for w: Dictionary in gen.layout.wall_run_gaps:
		out.append(WallRunGapPlacement.keep_out(w))
	return out


## True if a wall enemy of `type` at track distance `at` on wall `side` (one the danger density pass would add: a window
## cyborg, a wall vent's Screech) would stand where a wall-run gap's lit wall keeps whole and clear (WallRunGapPlacement
## .wall_path), within WallGapTuning.wall_enemy_seconds, as the placement keeps the wall enemies already there
## (WallRunGapPlacement.wall_keep_outs).
static func on_wall_section(gen: LevelGenerator, _type: String, side: int, at: float, _params: Dictionary = {}) -> bool:
	if side != -1 and side != 1 or gen.layout.wall_run_gaps.is_empty():
		return false
	var reach: float = WallGapPlacement.tuning().wall_enemy_seconds * gen.speed
	for w: Dictionary in gen.layout.wall_run_gaps:
		if int(w["side"]) != side:
			continue
		var path: Vector2 = WallRunGapPlacement.wall_path(w, gen.speed)
		if at + reach > path.x and at - reach < path.y:
			return true
	return false
