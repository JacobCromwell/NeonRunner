class_name HostileTakeoverTrain
extends RefCounted
## The Chairman's train as the arena's track (GDD §10: "carriage roofs are the floor and the gaps between
## carriages are the gaps, so it plays like a level"): a gap across every lane at the end of each
## carriage, the same length everywhere. The carriages come in a repeating consist
## (HostileTakeoverTuning.consist): the express's corporate carriages and, now and then, a long military
## flatcar (phase 2, The Contract: the gunship drops its Buzz Overdrive onto one, whose whole encounter
## needs a long stretch of whole roof in its lane; GDD §9.9). Carriage 0 is the rear roof the runner lands
## on (the entrance's), ending at gap 0; carriage k (k >= 1) ends at gap k and is of kind
## consist[(k - 1) % size]. Every lap of the arena holds whole consists, so the laps join without a seam
## and the train runs on for as long as the fight lasts (BossArena).
## Its numbers follow the run's pace (HostileTakeoverTuning: a carriage is metres at 18 m/s times the pace;
## a gap is a share of a jump at the run speed), so a carriage takes as long to run at every zone's speed.

enum Kind { CORPORATE, FLATCAR }

var lap_length: float = 0.0
## A gap's length (all lanes).
var gap: float = 6.0
## Where gap 0 starts (the end of the rear roof).
var offset: float = 46.0
## The consist: each carriage's kind in turn, and its roof's length (metres along the track).
var kinds: PackedInt32Array = PackedInt32Array([Kind.CORPORATE])
var roofs: PackedFloat32Array = PackedFloat32Array([50.0])
## A consist's length (its roofs and gaps), and the consists and gaps in a lap.
var period: float = 56.0
var consists_per_lap: int = 1
var per_lap: int = 1
## The run speed and full jump the train was planned for.
var speed: float = 18.0
var jump: float = 12.0

## _prefix[j]: from the start of a consist's first roof to the start of its slot j's roof.
var _prefix: PackedFloat32Array = PackedFloat32Array([0.0, 56.0])


## The train for an arena whose laps are `p_lap_length` long, at `movement`'s run speed, with `t`'s numbers.
static func plan(movement: MovementTuning, p_lap_length: float, t: HostileTakeoverTuning) -> HostileTakeoverTrain:
	var out := HostileTakeoverTrain.new()
	var pace: float = movement.pace()
	out.speed = movement.run_speed
	out.jump = movement.jump_distance(movement.run_speed)
	out.lap_length = p_lap_length
	out.gap = t.gap_jump_fraction * out.jump
	out.kinds = t.consist_kinds()
	var wanted := PackedFloat32Array()
	var roofs_wanted: float = 0.0
	for kind: int in out.kinds:
		var length: float = (t.flatcar_length if kind == Kind.FLATCAR else t.carriage_length) * pace
		wanted.append(length)
		roofs_wanted += length
	var n: int = out.kinds.size()
	out.consists_per_lap = maxi(roundi(p_lap_length / (roofs_wanted + n * out.gap)), 1)
	out.period = p_lap_length / out.consists_per_lap
	out.per_lap = out.consists_per_lap * n
	# The roofs stretch (or shrink) a little so a lap holds whole consists; the gaps keep their length.
	var scale: float = maxf(out.period - n * out.gap, 1.0) / maxf(roofs_wanted, 0.001)
	out.roofs = PackedFloat32Array()
	out._prefix = PackedFloat32Array([0.0])
	for j: int in n:
		out.roofs.append(wanted[j] * scale)
		out._prefix.append(out._prefix[j] + out.roofs[j] + out.gap)
	# Carriage 0 is the rear part of a carriage of the consist's last kind, so its roof is shorter.
	out.offset = clampf(t.first_gap * pace, 1.0, out.roofs[n - 1] - 1.0)
	return out


## Where gap `k` starts (track distance).
func gap_start(k: int) -> float:
	if k <= 0:
		return offset + k * period / maxf(kinds.size(), 1.0)
	var n: int = kinds.size()
	@warning_ignore("integer_division")
	var c: int = (k - 1) / n
	var j: int = (k - 1) % n
	return offset + c * period + _prefix[j] + gap + roofs[j]


func gap_end(k: int) -> float:
	return gap_start(k) + gap


## The gap the runner at track distance `d` comes to next: the first whose end is ahead of `d`.
func next_gap(d: float) -> int:
	if d < offset + gap:
		return 0
	var n: int = kinds.size()
	var k: int = maxi(floori((d - offset) / period) * n, 0)
	while gap_end(k) <= d:
		k += 1
	return k


## The gap whose stretch holds track distance `d`, or -1 (on a roof).
func gap_at(d: float) -> int:
	var k: int = next_gap(d)
	return k if d >= gap_start(k) else -1


## Carriage `k`'s roof: from the end of gap k - 1 (the track's start for the rear carriage, k = 0) to the
## start of gap k.
func roof(k: int) -> Vector2:
	return Vector2(gap_end(k - 1) if k > 0 else -INF, gap_start(k))


## Carriage `k`'s kind (the rear roof counts as the consist's last kind).
func kind(k: int) -> int:
	if k <= 0:
		return kinds[kinds.size() - 1]
	return kinds[(k - 1) % kinds.size()]


## The carriage whose roof holds track distance `d` (the one after a gap, for a distance in it).
func carriage_at(d: float) -> int:
	var k: int = gap_at(d)
	return k + 1 if k >= 0 else next_gap(d)


## The first flatcar at or after carriage `k`.
func next_flatcar(k: int) -> int:
	var i: int = maxi(k, 1)
	for step: int in kinds.size() + 1:
		if kind(i + step) == Kind.FLATCAR:
			return i + step
	return -1


## The gaps of one lap of the arena in its own coordinates (from 0 to lap_length), across `lanes` lanes:
## the pieces _plan_lap gives the lap (LevelLayout.gaps entries).
func lap_gaps(lanes: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for k: int in per_lap:
		var s: float = gap_start(k)
		for lane: int in lanes:
			out.append({"lane": lane, "start": s, "end": s + gap})
	return out


## The distances behind gap `k`'s start where the carriages behind it end (their rear ends, the
## nearest first: carriage k, k - 1, ...), `count` of them: the train's breakaway draws each one
## tumbling about its own rear end (HostileTakeoverSkin.set_breakaway).
func ends_behind(k: int, count: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var start: float = gap_start(k)
	for i: int in count:
		var car: int = k - i
		var rear: float = gap_end(car - 1) if car > 0 else roof(car).y - roofs[roofs.size() - 1]
		out.append(start - rear)
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
