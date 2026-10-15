class_name LevelLayout
extends RefCounted
## Pure-data description of one generated level, built from abstract gameplay pieces only.
## Positions along the track are distances in metres from the start (forward is positive).
## Lanes are indices 0..lane_count-1, left to right. Wall sides are -1 (left) and +1 (right).

## A doodad's size classes, smallest first (LevelLayout.doodads `size`; MovementTuning.doodad_size).
const DOODAD_SIZES: Array[StringName] = [&"small", &"medium", &"large"]
## The key that marks a hole of a wall-run gap (gaps; wall_run_gaps): it isn't one to jump, so the checks on
## jumpable holes and rows of holes leave it out (is_wall_run_hole).
const WALL_RUN_HOLE: String = "wall_run"

var lane_count: int = 3
var length: float = 0.0
## {lane, start, end}: a hole in the floor segment of one lane. A wall-run gap's holes (wall_run_gaps) also carry
## WALL_RUN_HOLE: true.
var gaps: Array[Dictionary] = []
## {lane, at, variant ("full" | "gapped"), pulsing, pulse_on, pulse_off, phase}
var fences: Array[Dictionary] = []
## {side, start, end, bottom, top}: blocks wall entry along its length and hurts on contact.
var signs: Array[Dictionary] = []
## {start, end}: a ceiling section over every lane, or {start, end, first_lane, last_lane} over a
## contiguous range of lanes only (a narrow ceiling, GDD §3: "ceilings don't have to cover every
## lane"). Read the range with hull_lanes(); a range over every lane is stored without the keys, so
## full-width ceilings stay exactly as they were. A ceiling scenario (task I4) marks its ceiling with
## "scenario" (CeilingScenarios.KEY), and a fenced ceiling records its pick as "pick": [from, to], from
## its first pad's run-up to its last safe pad (fenced_pick_between).
var hulls: Array[Dictionary] = []
## {lane, at}: anti-grav pad in a floor lane.
var pads: Array[Dictionary] = []
## {side, at}: ramp in the outermost lane on that side, launching onto the wall.
var ramps: Array[Dictionary] = []
## {lane, at}: speed pad in a floor lane (GDD §6 only names them; FB 21).
var speed_pads: Array[Dictionary] = []
## {at, surface ("floor" | "wall" | "ceiling"), lane (floor/ceiling), side (wall), height, value}.
## `height` is the distance from the surface (floor/ceiling) or the height on the wall.
var credits: Array[Dictionary] = []
## {type, at, lane, side, seed, params}: an enemy (or destructible) for EnemyDirector.
var enemies: Array[Dictionary] = []
## {lane, start, end, size, side, seed}: a zone doodad (GDD §3, owner's playtest September 30, 2026):
## a scenery piece standing in `lane` from `start` to `end` that never hurts. Running into its front
## pushes the player into the neighbouring lane on `side` (-1 left, +1 right); its sides block a lane
## switch like a solid side. `size` is its size class (DOODAD_SIZES: the skin picks the look, the
## movement tuning its width and height), `seed` varies the look. The generator plans them
## (LevelGenerator: doodads), the track builder builds them (TrackBuilder, ZoneSkin.doodad).
var doodads: Array[Dictionary] = []
## {lane, start, end, warn, charge, keep, speed}: a floor cut planned in advance (task B4; GDD §9.9,
## the Buzz Overdrive's): the floor of `lane` from `start` to `end` turns into a gap during play, run
## from `end` back toward and past the player by its cause, keyed to the player's distance. Its fields
## and geometry: FloorCutPlan. The generator plans them (LevelGenerator.add_cut, only where GDD
## §9.9's limits allow), the track builder builds them as pieces of their own (FloorCut), and a cause
## runs each (FloorCut.advance_to).
var cuts: Array[Dictionary] = []
## {side, at, band ("full" | "low" | "high"), pulse_on, pulse_off, phase}: a wall fence (task B5; GDD
## §9.1): an electric fence across the wall-run path on wall `side` at track distance `at`, between
## emitters on the facade, that switches off and on on the level clock (pulse_on seconds on, pulse_off
## off, the floor fences' flicker and crackle before it switches on; `phase` 0–1 offsets it within its
## cycle). `band` is how much of the wall it covers: all of it ("full", passed by timing), or only the
## low or the high part (passed by entering the wall high or low). Its field reaches out from the
## facade over the wall runner's path only, never as far as a floor runner in the outer lane. Its
## fields and geometry: WallFencePlan. The generator places them (WallFencePlacement, only where
## they're fair), the track builder builds them as hazards (TrackBuilder), and the skin draws them
## (ZoneSkin.wall_fence).
var wall_fences: Array[Dictionary] = []
## {side, start, end}: a side wall gap (the `wall_gaps` feature, Zone 2 on; WallGapPlacement): wall
## `side` (-1 left, 1 right) has no wall-running surface from track distance `start` to `end`. The
## track builder leaves the wall out there and marks its edges (ZoneSkin.wall_gap), a runner can't
## get onto the wall there, and one on it drops off at the gap (Player.wall_supported). Sorted by
## start; both walls may have one over the same stretch.
var wall_gaps: Array[Dictionary] = []
## {start, end, seed}: a dash wall (task H7a; GDD §9.14, owner, October 8, 2026): a building standing
## across every floor lane from track distance `start` (its face, toward the runner) to `end`, leaving the
## side walls open. The runner dashes through it, crashes through it without the dash (one hit: the armor
## or the shield takes it, else it kills) or passes it on a side wall; it crumbles whichever they do and
## stays broken for the rest of the attempt (its entry marked "smashed", with "broken_by"). `seed` varies
## its look. The generator places them (scripts/enemies/dash_wall_rules.gd, only where they're fair), the
## track builder builds each as a DashBreakable (TrackBuilder) and the skin dresses it (ZoneSkin.dash_wall).
var dash_walls: Array[Dictionary] = []
## {lane, at}: an electric fence hanging from a ceiling across `lane` at track distance `at` (task I4; GDD §3,
## "Ceiling scenarios": pick the right pad), always on. A fenced ceiling (fenced_ceiling_rules.gd) hangs rows of
## them across every lane it covers after its unsafe pads' arrival. The track builder builds each as an
## electrical hazard below the ceiling's underside (TrackBuilder, MovementTuning.ceiling_fence_depth), the skin
## draws it (ZoneSkin.ceiling_fence).
var ceiling_fences: Array[Dictionary] = []
## {lane, at}: a return pad on a ceiling's underside in `lane`, from track distance `at` to a pad's length on
## (task I4; GDD §3, "Ceiling scenarios": the treasure stash). A rider who steps on it drops back to the floor
## the way a ceiling's end drops them (Player). The generator places one over each treasure stash
## (treasure_stash_rules.gd); the track builder builds it as a trigger, the skin dresses it (ZoneSkin.return_pad).
var return_pads: Array[Dictionary] = []
## {lane, start, end, walls_from, pad, hull_start}: a treasure stash (task I4; GDD §3, "Ceiling scenarios"): a
## stretch of floor in `lane`, walled off by zone doodads, that only a ceiling's return pad (at `pad`, over the
## ceiling starting at `hull_start`) drops a player into. A doodad stands in its lane from `start`; doodads stand
## in both neighbouring lanes from `walls_from` to `end`, where it opens onto the track; inside lie its credits.
## The pieces are ordinary entries of `doodads` (marked "stash"), `return_pads` and `credits` (marked "stash");
## this is the record that ties them together (treasure_stash_rules.gd, the checks and the credit pass).
var stashes: Array[Dictionary] = []
## {side, start, end, entry, approach, landing, wall_to}: a wall-run gap (task J2; the owner, October 15, 2026: "a gap
## over the ENTIRE floor (every lane), and the only way to cross is a wall run"): every floor lane is a hole from
## `start` to `end` (entries of `gaps` marked WALL_RUN_HOLE), and wall `side` (-1 left, 1 right) is the way across: lit
## from `entry` (the earliest a step onto it carries a standard wall run past `end`) to `end`, whole and clear of
## signs, wall enemies, wall fences and wall gaps until `wall_to`. Nothing stands in any lane from `approach` (where
## the clear run-in starts) to `landing` (where the safe landing floor ends). The generator places them
## (WallRunGapPlacement), the track builder builds the holes like any and the skin lights the wall
## (ZoneSkin.wall_run_guide). Sorted by start.
var wall_run_gaps: Array[Dictionary] = []


## Every list of pieces, by name. A level without doodads has no "doodads" key, one without floor
## cuts no "cuts" key, one without wall fences no "wall_fences" key, one without wall gaps no
## "wall_gaps" key, one without dash walls no "dash_walls" key, one without ceiling scenarios (task I4)
## no "ceiling_fences", "return_pads" or "stashes" key, and one without wall-run gaps (task J2) no
## "wall_run_gaps" key, so its dictionary (and every hash or dump of it) is the same as before those existed.
func to_dict() -> Dictionary:
	var out := {
		"lane_count": lane_count,
		"length": length,
		"gaps": gaps,
		"fences": fences,
		"signs": signs,
		"hulls": hulls,
		"pads": pads,
		"ramps": ramps,
		"speed_pads": speed_pads,
		"credits": credits,
		"enemies": enemies,
	}
	if not doodads.is_empty():
		out["doodads"] = doodads
	if not cuts.is_empty():
		out["cuts"] = cuts
	if not wall_fences.is_empty():
		out["wall_fences"] = wall_fences
	if not wall_gaps.is_empty():
		out["wall_gaps"] = wall_gaps
	if not dash_walls.is_empty():
		out["dash_walls"] = dash_walls
	if not ceiling_fences.is_empty():
		out["ceiling_fences"] = ceiling_fences
	if not return_pads.is_empty():
		out["return_pads"] = return_pads
	if not stashes.is_empty():
		out["stashes"] = stashes
	if not wall_run_gaps.is_empty():
		out["wall_run_gaps"] = wall_run_gaps
	return out


## Appends every list of `other`'s pieces to this layout's (doodads, floor cuts, wall fences, wall gaps,
## dash walls, the ceiling scenarios' pieces and wall-run gaps included, whether or not this layout has any yet),
## and moves its end to other's if that's further.
func append_pieces(other: LevelLayout) -> void:
	var lists: Dictionary = to_dict()
	var more: Dictionary = other.to_dict()
	for key: String in more:
		if more[key] is Array and lists.get(key) is Array:
			(lists[key] as Array).append_array(more[key])
	# Lists to_dict() leaves out while they're empty join here.
	if not lists.has("doodads"):
		doodads.append_array(other.doodads)
	if not lists.has("cuts"):
		cuts.append_array(other.cuts)
	if not lists.has("wall_fences"):
		wall_fences.append_array(other.wall_fences)
	if not lists.has("wall_gaps"):
		wall_gaps.append_array(other.wall_gaps)
	if not lists.has("dash_walls"):
		dash_walls.append_array(other.dash_walls)
	if not lists.has("ceiling_fences"):
		ceiling_fences.append_array(other.ceiling_fences)
	if not lists.has("return_pads"):
		return_pads.append_array(other.return_pads)
	if not lists.has("stashes"):
		stashes.append_array(other.stashes)
	if not lists.has("wall_run_gaps"):
		wall_run_gaps.append_array(other.wall_run_gaps)
	length = maxf(length, other.length)


func copy() -> LevelLayout:
	var out := LevelLayout.new()
	out.lane_count = lane_count
	out.length = length
	out.gaps = gaps.duplicate(true)
	out.fences = fences.duplicate(true)
	out.signs = signs.duplicate(true)
	out.hulls = hulls.duplicate(true)
	out.pads = pads.duplicate(true)
	out.ramps = ramps.duplicate(true)
	out.speed_pads = speed_pads.duplicate(true)
	out.credits = credits.duplicate(true)
	out.enemies = enemies.duplicate(true)
	out.doodads = doodads.duplicate(true)
	out.cuts = cuts.duplicate(true)
	out.wall_fences = wall_fences.duplicate(true)
	out.wall_gaps = wall_gaps.duplicate(true)
	out.dash_walls = dash_walls.duplicate(true)
	out.ceiling_fences = ceiling_fences.duplicate(true)
	out.return_pads = return_pads.duplicate(true)
	out.stashes = stashes.duplicate(true)
	out.wall_run_gaps = wall_run_gaps.duplicate(true)
	return out


func outer_lane(side: int) -> int:
	return 0 if side < 0 else lane_count - 1


## True if hole `g` (an entry of `gaps`) is a wall-run gap's (WALL_RUN_HOLE; wall_run_gaps): a stretch the runner
## crosses on a wall, never a jump.
static func is_wall_run_hole(g: Dictionary) -> bool:
	return bool(g.get(WALL_RUN_HOLE, false))


## The wall-run gap (wall_run_gaps) whose holes reach track distance `d` within `margin` metres either side of its
## [start, end], or {} if none does.
func wall_run_gap_at(d: float, margin: float = 0.0) -> Dictionary:
	for w: Dictionary in wall_run_gaps:
		if d >= float(w["start"]) - margin and d <= float(w["end"]) + margin:
			return w
	return {}


## True if a wall-run gap's clear stretch (wall_run_gaps: from its `approach` to its `landing`, in every lane)
## reaches anywhere into [from, to].
func wall_run_zone_between(from: float, to: float) -> bool:
	for w: Dictionary in wall_run_gaps:
		if float(w["approach"]) <= to and float(w["landing"]) >= from:
			return true
	return false


## True if a wall-run gap's crossing (wall_run_gaps: from its clear run-in's start, where the runner heads for its lit
## wall, to its gap's far end, `approach` to `end`) reaches anywhere into [from, to]: no move but the wall run there.
## An attack that could only be dodged another way holds off while one lies in its reach (a heli drone's barrage, a Bad
## Dream's slash).
func wall_run_between(from: float, to: float) -> bool:
	for w: Dictionary in wall_run_gaps:
		if float(w["approach"]) <= to and float(w["end"]) >= from:
			return true
	return false


## Total value of every credit, a treasure stash's too: what a run can collect (the economy's tools and tests). The
## stars count star_credit_value().
func total_credit_value() -> int:
	var total: int = 0
	for c: Dictionary in credits:
		total += int(c["value"])
	return total


## The best credit score the stars count (ScoreKeeper.max_credit_score, GameRules.stars_for): every credit but a
## treasure stash's (task I4). A stash is an optional reward a floor runner can't reach (and there's none on 3 or 4
## lanes), so the three-star line never asks for it; collected, its credits still count in the run's credits (the
## wallet) and its level score. DESIGN-TBD (item 844).
func star_credit_value() -> int:
	var total: int = 0
	for c: Dictionary in credits:
		if not c.has("stash"):
			total += int(c["value"])
	return total


## True if `lane` has a hole anywhere in [from, to].
func gapped_between(lane: int, from: float, to: float) -> bool:
	for g: Dictionary in gaps:
		if g["lane"] == lane and g["start"] <= to and g["end"] >= from:
			return true
	return false


## True if a doodad stands anywhere in [from, to]: in `lane`, or in any lane with -1. A dash wall (task
## H7a) counts in every lane, since it stands across all of them (dash_wall_between). The enemies'
## fairness checks ask it (an attack is never timed onto a doodad or a dash wall, which narrow the
## player's moves: CyborgGun.path_clear, Octodog.window_clear, Resonator.pulse_clear, the drone's barrage,
## the hover truck's cannon and the Enforcer Truck's escape), and so do the generator's (a floor cut's
## lane, a floor credit, a Gilded Sentinel's stretch, a cyborg planted in a charge's path). A smashed one
## still counts, so an attack waits by it the same on every attempt.
func doodad_between(from: float, to: float, lane: int = -1) -> bool:
	for d: Dictionary in doodads:
		if float(d["start"]) <= to and float(d["end"]) >= from and (lane < 0 or int(d["lane"]) == lane):
			return true
	return dash_wall_between(from, to)


## True if a fenced ceiling's pick (task I4: its hull's "pick", from its first pad's run-up to its last safe pad,
## where the player reads which pad is the trap) overlaps [from, to]. A heli drone never starts a barrage that would
## play out there (Drone._pick_in_reach).
func fenced_pick_between(from: float, to: float) -> bool:
	for h: Dictionary in hulls:
		var pick: Variant = h.get("pick")
		if pick is Array and (pick as Array).size() == 2 and float(pick[0]) <= to and float(pick[1]) >= from:
			return true
	return false


## True if a dash wall (dash_walls, from its face to its back) stands anywhere in [from, to], broken or not.
func dash_wall_between(from: float, to: float) -> bool:
	for w: Dictionary in dash_walls:
		if float(w["start"]) <= to and float(w["end"]) >= from:
			return true
	return false


## True if a floor cut keeps its lane clear anywhere in [from, to] (FloorCutPlan.lane_window: from
## where its warning starts to past its cause's spot): in `lane`, or in any lane with -1.
func cut_between(from: float, to: float, lane: int = -1) -> bool:
	for c: Dictionary in cuts:
		if FloorCutPlan.lane_window_in(c, from, to, lane):
			return true
	return false


## True if a wall fence stands within [from, to] (its `at`): on wall `side` (-1 left, 1 right), or on
## either wall with 0. A wall enemy's rules (task C4's Gilded Sentinels) and a boss's wall pieces ask it.
func wall_fence_between(from: float, to: float, side: int = 0) -> bool:
	for w: Dictionary in wall_fences:
		if float(w["at"]) >= from and float(w["at"]) <= to and (side == 0 or int(w["side"]) == side):
			return true
	return false


## True if wall `side` (-1 left, 1 right; 0 either) has a gap anywhere in [from, to] (wall_gaps).
func wall_gap_between(from: float, to: float, side: int = 0) -> bool:
	for g: Dictionary in wall_gaps:
		if float(g["start"]) <= to and float(g["end"]) >= from and (side == 0 or int(g["side"]) == side):
			return true
	return false


## True if wall `side` has its wall-running surface at track distance `d`: no wall gap holds it
## (a gap's [start, end)).
func wall_supported(side: int, d: float) -> bool:
	return wall_supported_in(wall_gaps, side, d)


## wall_supported() over a list of wall gap entries (the player keeps the layout's list).
static func wall_supported_in(gaps: Array[Dictionary], side: int, d: float) -> bool:
	for g: Dictionary in gaps:
		if int(g["side"]) == side and d >= float(g["start"]) and d < float(g["end"]):
			return false
	return true


## The solid stretches of wall `side` within [from, to): that range with its wall gaps taken out, in
## order (Vector2(start, end)). The track builder draws the wall over exactly these.
func wall_solid_pieces(side: int, from: float, to: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var cursor: float = from
	for g: Vector2 in wall_gap_pieces(side, from, to):
		if g.x > cursor:
			out.append(Vector2(cursor, g.x))
		cursor = maxf(cursor, g.y)
	if cursor < to:
		out.append(Vector2(cursor, to))
	return out


## The parts of wall `side`'s gaps within [from, to), in order: Vector2(start, end) clipped to the
## range (the full gap's ends in wall_gap_spans).
func wall_gap_pieces(side: int, from: float, to: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for g: Vector2 in wall_gap_spans(side, from, to):
		out.append(Vector2(maxf(g.x, from), minf(g.y, to)))
	return out


## The whole wall gaps on wall `side` that overlap [from, to), in order, as Vector2(start, end).
func wall_gap_spans(side: int, from: float, to: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for g: Dictionary in wall_gaps:
		var s: float = float(g["start"])
		var e: float = float(g["end"])
		if int(g["side"]) == side and s < to and e > from:
			out.append(Vector2(s, e))
	out.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	return out


## True if a ceiling section covers the track distance `d`: in `lane`, or in any lane with -1.
func under_hull(d: float, lane: int = -1) -> bool:
	for h: Dictionary in hulls:
		if d >= h["start"] and d <= h["end"] and (lane < 0 or hull_covers(h, lane)):
			return true
	return false


## The lanes ceiling section `h` covers: Vector2i(first, last), a contiguous range (every lane for a
## full-width ceiling).
func hull_lanes(h: Dictionary) -> Vector2i:
	return hull_lanes_of(h, lane_count)


## hull_lanes() for a layout of `lanes` lanes.
static func hull_lanes_of(h: Dictionary, lanes: int) -> Vector2i:
	if not h.has("first_lane"):
		return Vector2i(0, lanes - 1)
	return Vector2i(clampi(int(h["first_lane"]), 0, lanes - 1), clampi(int(h["last_lane"]), 0, lanes - 1))


## How many lanes ceiling section `h` covers.
func hull_width(h: Dictionary) -> int:
	var lanes: Vector2i = hull_lanes(h)
	return lanes.y - lanes.x + 1


## True if ceiling section `h` covers `lane`.
func hull_covers(h: Dictionary, lane: int) -> bool:
	var lanes: Vector2i = hull_lanes(h)
	return lane >= lanes.x and lane <= lanes.y


## A ceiling section from `start` to `end` over lanes `lanes` (Vector2i(first, last)) of a layout of
## `lane_count` lanes: without a range when it covers every lane (see hulls).
static func make_hull(start: float, end: float, lanes: Vector2i, lane_count: int) -> Dictionary:
	if lanes.x <= 0 and lanes.y >= lane_count - 1:
		return {"start": start, "end": end}
	return {"start": start, "end": end, "first_lane": lanes.x, "last_lane": lanes.y}


## The ceiling section over track distance `d` (in `lane`, or any lane with -1); {} if there's none.
func hull_at(d: float, lane: int = -1) -> Dictionary:
	for h: Dictionary in hulls:
		if d >= h["start"] and d <= h["end"] and (lane < 0 or hull_covers(h, lane)):
			return h
	return {}
