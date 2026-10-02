class_name HostileTakeoverTrain
extends RefCounted
## The Chairman's train as the arena's track (GDD §10: "carriage roofs are the floor and the gaps between
## carriages are the gaps, so it plays like a level"): a gap across every lane at the end of each
## carriage, the same length everywhere, at a steady pitch. Gap k (k = 0, 1, 2, ... over the whole fight)
## starts at `offset + k * pitch`; every lap of the arena holds `per_lap` of them, so the laps join without
## a seam and the train runs on for as long as the fight lasts (BossArena). The rear carriage's roof, from
## the track's start to the first gap, is the entrance's.
## Its numbers follow the run's pace (HostileTakeoverTuning: a carriage is metres at 18 m/s times the pace;
## a gap is a share of a jump at the run speed), so a carriage takes as long to run at every zone's speed.

var lap_length: float = 0.0
## Gap start to gap start, and a gap's length (all lanes).
var pitch: float = 56.0
var gap: float = 6.0
## Where the first gap starts in every lap (less than the pitch).
var offset: float = 46.0
var per_lap: int = 1
## The run speed and full jump the train was planned for.
var speed: float = 18.0
var jump: float = 12.0


## The train for an arena whose laps are `p_lap_length` long, at `movement`'s run speed, with `t`'s numbers.
static func plan(movement: MovementTuning, p_lap_length: float, t: HostileTakeoverTuning) -> HostileTakeoverTrain:
	var out := HostileTakeoverTrain.new()
	var pace: float = movement.pace()
	out.speed = movement.run_speed
	out.jump = movement.jump_distance(movement.run_speed)
	out.lap_length = p_lap_length
	out.gap = t.gap_jump_fraction * out.jump
	var wanted: float = t.carriage_length * pace + out.gap
	out.per_lap = maxi(roundi(p_lap_length / wanted), 1)
	out.pitch = p_lap_length / out.per_lap
	out.offset = clampf(t.first_gap * pace, 1.0, out.pitch - out.gap - 1.0)
	return out


## Where gap `k` starts (track distance).
func gap_start(k: int) -> float:
	return offset + k * pitch


func gap_end(k: int) -> float:
	return gap_start(k) + gap


## The gap the runner at track distance `d` comes to next: the first whose end is ahead of `d`.
func next_gap(d: float) -> int:
	return maxi(floori((d - offset - gap) / pitch) + 1, 0)


## The gap whose stretch holds track distance `d`, or -1 (on a roof).
func gap_at(d: float) -> int:
	var k: int = floori((d - offset) / pitch)
	if k < 0:
		return -1
	return k if d <= gap_end(k) else -1


## Carriage `k`'s roof: from the end of gap k - 1 (the track's start for the rear carriage, k = 0) to the
## start of gap k.
func roof(k: int) -> Vector2:
	return Vector2(gap_end(k - 1) if k > 0 else -INF, gap_start(k))


## The carriage whose roof holds track distance `d` (the one after a gap, for a distance in it).
func carriage_at(d: float) -> int:
	var k: int = gap_at(d)
	return k + 1 if k >= 0 else next_gap(d)


## The gaps of one lap of the arena in its own coordinates (from 0 to lap_length), across `lanes` lanes:
## the pieces _plan_lap gives the lap (LevelLayout.gaps entries).
func lap_gaps(lanes: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i: int in per_lap:
		var s: float = offset + i * pitch
		for lane: int in lanes:
			out.append({"lane": lane, "start": s, "end": s + gap})
	return out


## True if a stomp's bounce (GameRules.stomp_bounce_velocity, at the run speed) from height `top` at
## `before` metres short of a gap clears the rest of it with `margin` to spare: the stomp box's near end
## never leaves a runner short of the far roof.
func bounce_clears(movement: MovementTuning, rules: GameRules, top: float, before: float, margin: float = 1.0) -> bool:
	return bounce_length(movement, rules, top) >= before + gap + margin


## How far a stomp's bounce from height `top` carries along the track before the runner is back on the
## roofs (y = 0), at the run speed.
static func bounce_length(movement: MovementTuning, rules: GameRules, top: float) -> float:
	var g_up: float = movement.gravity()
	var g_down: float = g_up * movement.fall_gravity_multiplier
	var v: float = rules.stomp_bounce_velocity
	var t_up: float = v / g_up
	var peak: float = top + v * v / (2.0 * g_up)
	var t_down: float = sqrt(2.0 * maxf(peak, 0.0) / g_down)
	return (t_up + t_down) * movement.run_speed
