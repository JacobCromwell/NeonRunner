class_name FloorCutPlan
extends RefCounted
## The geometry of a floor cut planned in advance (task B4; GDD §9.9, the Buzz Overdrive: "the
## generator plans each cut in advance (lane, start and end), so levels stay fair and identical on
## every attempt; the saw is just the visible cause"). A cut is a LevelLayout.cuts entry:
##   {lane, start, end, warn, charge, keep, speed}
## - `lane`: the floor lane it cuts.
## - `start`, `end`: track distances, start < end. Its cause waits at `end`, then the cut runs from
##   `end` back toward the player, past them, to `start`, where it ends (the cause has gone off the
##   screen behind the player): the floor of [start, end] in its lane becomes a gap during play.
## - `warn`, `charge`: metres before `end` where the player is when the cause's warning starts (its
##   rev, the red line over the lane) and when the cut starts running (warn > charge > 0).
## - `keep`: metres past `end` its lane keeps clear for the cause (its body, waiting at `end`).
## - `speed`: how fast the cut runs back toward the player (m/s) while the player runs at the level's
##   run speed.
## Distances are relative to `end`, so a copy moved along the track (BossArena.shifted) only moves
## `start` and `end`.
##
## A cut is keyed to the player's distance (front_at): when the player is at distance p, its front
## (where the cut has got to) is at end - (p - charge_at) * speed / run_speed. So where it starts,
## runs and ends is the same on every attempt and at every frame rate, a speed boost or a dash
## included, and the generator and the tests know exactly where it meets the player (meet). A cause
## that moves its own way (task C2's saw) advances the cut to wherever it is (FloorCut.advance_to).


## A cut whose cause waits at `end` in `lane`: its warning starts `warn` metres before `end`, the cut
## runs from `charge` metres before it at `speed` (at a player's `run_speed`) and on `run_past` metres
## past where it meets the player (its start), its lane kept clear `keep` metres past `end`.
static func make(lane: int, end: float, warn: float, charge: float, speed: float, run_speed: float,
		run_past: float, keep: float) -> Dictionary:
	var cut := {"lane": lane, "start": end, "end": end, "warn": warn, "charge": charge, "keep": keep, "speed": speed}
	cut["start"] = meet(cut, run_speed) - run_past
	return cut


## Where the player is when the cause's warning starts.
static func warn_at(cut: Dictionary) -> float:
	return float(cut["end"]) - float(cut["warn"])


## Where the player is when the cut starts running from `end`.
static func charge_at(cut: Dictionary) -> float:
	return float(cut["end"]) - float(cut["charge"])


## How many metres the cut runs for each metre the player runs.
static func ratio(cut: Dictionary, run_speed: float) -> float:
	return float(cut["speed"]) / maxf(run_speed, 0.01)


## Where the cut's front is when the player is at `player_distance`: `end` until the cut starts, then
## running back toward the player, down to `start`. The floor of [start, front] is still whole.
static func front_at(cut: Dictionary, player_distance: float, run_speed: float) -> float:
	var front: float = float(cut["end"]) - maxf(player_distance - charge_at(cut), 0.0) * ratio(cut, run_speed)
	return clampf(front, float(cut["start"]), float(cut["end"]))


## Where the cut meets a player running at `run_speed` (its front reaches them there).
static func meet(cut: Dictionary, run_speed: float) -> float:
	var r: float = ratio(cut, run_speed)
	return (float(cut["end"]) + r * charge_at(cut)) / (1.0 + r)


## Where the player is when the cut reaches `start` and ends.
static func done_at(cut: Dictionary, run_speed: float) -> float:
	return charge_at(cut) + (float(cut["end"]) - float(cut["start"])) / maxf(ratio(cut, run_speed), 0.0001)


## The track its lane keeps clear: from where the warning starts to `keep` past `end`.
static func lane_window(cut: Dictionary) -> Vector2:
	return Vector2(warn_at(cut), float(cut["end"]) + float(cut["keep"]))


## The track the player runs while the cut is on, from its warning to its end (or past its cause's
## spot, whichever is later): only one cut at a time (GDD §9.9).
static func window(cut: Dictionary, run_speed: float) -> Vector2:
	var lane_span: Vector2 = lane_window(cut)
	return Vector2(lane_span.x, maxf(lane_span.y, done_at(cut, run_speed)))


## True if `cut`'s lane window reaches into [from, to], in `lane` (any lane with -1).
static func lane_window_in(cut: Dictionary, from: float, to: float, lane: int = -1) -> bool:
	var span: Vector2 = lane_window(cut)
	return (lane < 0 or int(cut["lane"]) == lane) and span.x <= to and span.y >= from
