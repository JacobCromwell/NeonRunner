class_name LevelLayout
extends RefCounted
## Pure-data description of one generated level, built from abstract gameplay pieces only.
## Positions along the track are distances in metres from the start (forward is positive).
## Lanes are indices 0..lane_count-1, left to right. Wall sides are -1 (left) and +1 (right).

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


func to_dict() -> Dictionary:
	return {
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
