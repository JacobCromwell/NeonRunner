class_name WallFencePlan
extends RefCounted
## The geometry and timing of a wall fence (task B5; GDD §9.1, wall fences: "electric fences that span a
## side wall and turn off and on from time to time, to make the walls less safe"). A wall fence is a
## LevelLayout.wall_fences entry:
##   {side, at, band, pulse_on, pulse_off, phase}
## - `side`: the wall, -1 left or 1 right.
## - `at`: the track distance of its field, the middle of its depth (MovementTuning.fence_depth).
## - `band`: how much of the wall it covers (band_heights): "full" (the whole wall-run path, passed by
##   timing; from Marketplace 2), or from the Corporate zone "low" (the floor up to
##   MovementTuning.wall_fence_low_top: passed above by entering the wall high) or "high"
##   (wall_fence_high_bottom up to wall_fence_top: passed below by entering low).
## - `pulse_on`, `pulse_off`: seconds on and off, on the level clock like a pulsing floor fence; the
##   last MovementTuning.fence_pulse_warning seconds of each off time are its warning (the same flicker
##   and crackle as a floor fence's), so it never switches on unannounced.
## - `phase`: 0–1, where in its cycle it is when the level starts.
## Its field is an Area3D on the hazard layer (TrackBuilder), electrical like a floor fence's, so
## DamageRules treats it as one: armor, the shield and the dash get through, claws don't, weapons can't
## touch it, and a fence generator's EMP switches it off (TrackBuilder.disable_fences_near).
##
## Where it is (hazard), in world space: from the wall face (TrackGeometry.wall_x) out toward the lanes
## by reach(), over its band's heights, fence_depth deep around `at`. A wall runner's body lies along
## the wall reaching out from the face (Player.hurtbox_aabb), so any wall runner within its band touches
## it, and a floor runner in the middle of the outer lane never does (reach() stops short of them).

## Its bands, the full one first.
const BANDS: PackedStringArray = ["full", "low", "high"]
## The least room left between a field's outer edge and the body of a floor runner in the middle of the
## outer lane (metres; reach()), so running past a wall fence in the outer lane never touches it.
const FLOOR_CLEARANCE: float = 0.15


## A wall fence on wall `side` at `at` over `band`, `pulse_on` seconds on and `pulse_off` off, starting
## at `phase` (0–1) of its cycle.
static func make(side: int, at: float, band: String, pulse_on: float, pulse_off: float, phase: float) -> Dictionary:
	return {"side": side, "at": at, "band": band, "pulse_on": pulse_on, "pulse_off": pulse_off, "phase": phase}


## True for a partial one (the low or the high band; GDD §9.1: from the Corporate zone).
static func is_partial(entry: Dictionary) -> bool:
	return String(entry.get("band", "full")) != "full"


## The heights its field covers: Vector2(bottom, top), in metres above the floor.
static func band_heights(band: String, tuning: MovementTuning) -> Vector2:
	match band:
		"low":
			return Vector2(0.0, tuning.wall_fence_low_top)
		"high":
			return Vector2(tuning.wall_fence_high_bottom, tuning.wall_fence_top)
	return Vector2(0.0, tuning.wall_fence_top)


## How far its field reaches out from the facade toward the lanes: MovementTuning.wall_fence_reach, but
## never so far that a floor runner in the middle of the outer lane touches it (the wall margin and
## half a lane, less half the hurtbox's width and FLOOR_CLEARANCE). Lanes are as wide at any count, so
## it's the same at 3, 5 and 6 lanes.
static func reach(tuning: MovementTuning) -> float:
	var room: float = tuning.wall_margin + tuning.lane_width * 0.5 - tuning.hurtbox_size.x * 0.5 - FLOOR_CLEARANCE
	return clampf(tuning.wall_fence_reach, 0.1, maxf(room, 0.1))


## Its hitbox in world space, with `geo`'s walls: from the wall face out by reach(), over its band, its
## depth around `at`.
static func hitbox(entry: Dictionary, tuning: MovementTuning, geo: TrackGeometry) -> AABB:
	var side: int = int(entry["side"])
	var band: Vector2 = band_heights(String(entry["band"]), tuning)
	var r: float = reach(tuning)
	var wall: float = side * geo.wall_x()
	var x0: float = wall - r if side > 0 else wall
	var z: float = TrackGeometry.world_z(float(entry["at"]))
	return AABB(Vector3(x0, band.x, z - tuning.fence_depth * 0.5), Vector3(r, band.y - band.x, tuning.fence_depth))


## Seconds one on-off cycle takes.
static func cycle(entry: Dictionary) -> float:
	return float(entry["pulse_on"]) + float(entry["pulse_off"])


## Its state at level time `time` (seconds since the run started, the level clock): exactly what its
## Hazard shows then (Hazard.setup_pulsing, _update_pulse): ON for the first pulse_on seconds of each
## cycle, then OFF, the last `warning` seconds of the off time WARNING (never more than the off time).
static func state_at(entry: Dictionary, time: float, warning: float) -> Hazard.State:
	var on: float = float(entry["pulse_on"])
	var off: float = float(entry["pulse_off"])
	var c: float = on + off
	if c <= 0.0:
		return Hazard.State.ON
	var t: float = fmod(float(entry["phase"]) * c + time, c)
	if t < on:
		return Hazard.State.ON
	return Hazard.State.WARNING if c - t <= minf(warning, off) else Hazard.State.OFF


## The level time of its next switch on at or after `time`: when its warning ends.
static func next_on(entry: Dictionary, time: float) -> float:
	var c: float = cycle(entry)
	if c <= 0.0:
		return time
	var t: float = fmod(float(entry["phase"]) * c + time, c)
	return time if is_zero_approx(t) else time + (c - t)


## True if a wall runner's body, spanning the heights `body` (Vector2(bottom, top), RampLaunch.body_at's
## kind), reaches into its band: what decides whether a partial one is passed above or below.
static func blocks(entry: Dictionary, body: Vector2, tuning: MovementTuning) -> bool:
	var band: Vector2 = band_heights(String(entry["band"]), tuning)
	return body.y > band.x and body.x < band.y
