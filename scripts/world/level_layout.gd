class_name LevelLayout
extends RefCounted
## Pure-data description of one generated level, built from abstract gameplay pieces only.
## Positions along the track are distances in metres from the start (forward is positive).
## Lanes are indices 0..lane_count-1, left to right. Wall sides are -1 (left) and +1 (right).

## A doodad's size classes, smallest first (LevelLayout.doodads `size`; MovementTuning.doodad_size).
const DOODAD_SIZES: Array[StringName] = [&"small", &"medium", &"large"]

var lane_count: int = 3
var length: float = 0.0
## {lane, start, end}: a hole in the floor segment of one lane.
var gaps: Array[Dictionary] = []
## {lane, at, variant ("full" | "gapped"), pulsing, pulse_on, pulse_off, phase}
var fences: Array[Dictionary] = []
## {side, start, end, bottom, top}: blocks wall entry along its length and hurts on contact.
var signs: Array[Dictionary] = []
## {start, end}: a ceiling section over every lane, or {start, end, first_lane, last_lane} over a
## contiguous range of lanes only (a narrow ceiling, GDD §3: "ceilings don't have to cover every
## lane"). Read the range with hull_lanes(); a range over every lane is stored without the keys, so
## full-width ceilings stay exactly as they were.
var hulls: Array[Dictionary] = []
## {lane, at}: anti-grav pad in a floor lane.
var pads: Array[Dictionary] = []
## {side, at}: ramp in the outermost lane on that side, launching onto the wall.
var ramps: Array[Dictionary] = []
## {lane, at}: speed pad in a floor lane (DESIGN-TBD: GDD §6 only names them).
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


## Every list of pieces, by name. A level without doodads has no "doodads" key, one without floor
## cuts no "cuts" key and one without wall fences no "wall_fences" key, so its dictionary (and every
## hash or dump of it) is the same as before those existed.
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
	return out


## Appends every list of `other`'s pieces to this layout's (doodads, floor cuts and wall fences
## included, whether or not this layout has any yet), and moves its end to other's if that's further.
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
	return out


func outer_lane(side: int) -> int:
	return 0 if side < 0 else lane_count - 1


## Total value of every credit: the best possible credit score, used for stars.
func total_credit_value() -> int:
	var total: int = 0
	for c: Dictionary in credits:
		total += int(c["value"])
	return total


## True if `lane` has a hole anywhere in [from, to].
func gapped_between(lane: int, from: float, to: float) -> bool:
	for g: Dictionary in gaps:
		if g["lane"] == lane and g["start"] <= to and g["end"] >= from:
			return true
	return false


## True if a doodad stands anywhere in [from, to]: in `lane`, or in any lane with -1. The enemies'
## fairness checks ask it (an attack is never timed onto a doodad, which narrows the player's moves:
## CyborgGun.path_clear, Octodog.window_clear, Resonator.pulse_clear, the drone's barrage and the
## hover truck's cannon).
func doodad_between(from: float, to: float, lane: int = -1) -> bool:
	for d: Dictionary in doodads:
		if float(d["start"]) <= to and float(d["end"]) >= from and (lane < 0 or int(d["lane"]) == lane):
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
