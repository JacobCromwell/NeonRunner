class_name WallHopPath
extends RefCounted
## Where a wall hopper is on a side wall and how high (task N1; GDD §3, "Wall hop", owner, October 9, 2026:
## "jumping off a wall and straight back onto it starts a fresh wall run", and §7, "Wall-hop credits"): the reference
## runner the wall-hop credits are laid out for (WallHopPlacement), following the Player's own movement and never
## changing it (Player._try_enter_wall, _update_wall, _leave_wall):
## - it steps onto the wall from the floor of the outer lane at `entry` (time 0): up from the floor to
##   MovementTuning.wall_entry_height over wall_entry_time, then down the wall-run curve over wall_slide_time;
## - each time its wall run has come down to `hop_height` it wall hops: jump (Player._leave_wall: off the wall at
##   wall_jump_velocity) and back toward the wall HOP_FRAMES physics frames later, which starts a fresh wall run from
##   where it is (the air entry: wall_entry_height plus wall_air_entry_factor of its height, at most wall_max_height),
##   so every fresh run after the first starts higher than one from the floor.
## At run speed, with no boost and no claws (`wall_time_multiplier` 1). test_wall_hops holds it to the real Player.
##
##   var path := WallHopPath.of(entry, tuning, speed, hop_height)
##   path.height_at(t), path.distance_at(t), path.time_at(d)   # t seconds after the entry
##   path.runs[k]                                               # each fresh wall run: start, from, peak, hop
##   path.run_end(k, multiplier)                                # where run k would end with no hop after it

## Physics frames from the hop's jump to the press back toward the wall (a hop as quick as a runner presses it: the
## jump's frame takes them off the wall, the next moves them a little out and up, the press brings them back on).
const HOP_FRAMES: int = 2
## How many fresh wall runs the path follows.
const RUNS: int = 8

## Track distance of the step onto the wall (time 0).
var entry: float = 0.0
var speed: float = 0.0
var hop_height: float = 0.0
var tuning: MovementTuning
## Each fresh wall run, in order: {start (seconds after the entry), from (the height it starts at: 0 from the floor,
## where the hop left the wall after a hop), peak (where the entry carries it), hop (seconds after the entry when it
## hops; INF if it never comes down to hop_height)}.
var runs: Array[Dictionary] = []


## The reference hopper stepping onto a wall at track distance `entry` at run speed `p_speed`, hopping at `p_hop_height`.
static func of(p_entry: float, p_tuning: MovementTuning, p_speed: float, p_hop_height: float) -> WallHopPath:
	var out := WallHopPath.new()
	out.entry = p_entry
	out.tuning = p_tuning
	out.speed = maxf(p_speed, 0.001)
	out.hop_height = p_hop_height
	var start: float = 0.0
	var from: float = 0.0
	for k: int in RUNS:
		var peak: float = minf(p_tuning.wall_entry_height + from * p_tuning.wall_air_entry_factor, p_tuning.wall_max_height)
		var run := {"start": start, "from": from, "peak": peak, "hop": INF}
		out.runs.append(run)
		var s: float = out._hop_share(peak)
		if s >= 1.0:
			break
		var hop: float = start + p_tuning.wall_entry_time + s * p_tuning.wall_slide_time
		run["hop"] = hop
		from = out._run_height(run, hop) + air_rise(p_tuning)
		start = hop + HOP_FRAMES * frame_seconds()
	return out


## One physics frame (seconds).
static func frame_seconds() -> float:
	return 1.0 / float(maxi(Engine.physics_ticks_per_second, 1))


## How much higher a hopper is when it comes back onto the wall than where it jumped off: its HOP_FRAMES - 1 frames in
## the air, rising at wall_jump_velocity less the gravity (Player._update_vertical).
static func air_rise(t: MovementTuning) -> float:
	var dt: float = frame_seconds()
	var v: float = t.wall_jump_velocity
	var rise: float = 0.0
	for i: int in maxi(HOP_FRAMES - 1, 0):
		v -= t.gravity() * dt
		rise += v * dt
	return rise


## How far from its middle a wall runner's body takes a credit on the wall, up or down (metres): the hitbox's half
## width (it lies along the wall, Player.hurtbox_aabb) and the pickup's margin (CreditField.PICKUP_MARGIN).
static func pickup_reach(t: MovementTuning) -> float:
	return t.hurtbox_size.x * 0.5 + CreditField.PICKUP_MARGIN.y


## The highest a fresh wall run carries a runner who never hops (metres): a step onto the wall from the floor
## (MovementTuning.wall_entry_height), or straight back onto it as a wall run drops them off, from where it ends
## (wall_exit_height, an air entry: wall_air_entry_factor of it more), at most wall_max_height. Only a hop (or a jump
## onto the wall) starts one higher.
static func fresh_top(t: MovementTuning) -> float:
	return minf(t.wall_entry_height + t.wall_air_entry_factor * t.wall_exit_height, t.wall_max_height)


## Track distance t seconds after the entry.
func distance_at(t: float) -> float:
	return entry + speed * maxf(t, 0.0)


## Seconds after the entry at which the hopper passes track distance d (0 at or before the entry).
func time_at(d: float) -> float:
	return maxf(d - entry, 0.0) / speed


## The index of the fresh wall run the hopper is on (or hopping off) t seconds after the entry.
func run_at(t: float) -> int:
	for k: int in range(runs.size() - 1, -1, -1):
		if t >= float(runs[k]["start"]):
			return k
	return 0


## The hopper's height on the wall t seconds after the entry (the middle of the body, Player.h); between a hop and
## the press back onto the wall, the height it jumped off at.
func height_at(t: float) -> float:
	var run: Dictionary = runs[run_at(t)]
	return _run_height(run, minf(t, float(run["hop"])))


## Seconds after the entry when fresh wall run `k` would end with no hop after it, its slide `multiplier` times as
## long (claws: PowerupTuning.claws_wall_time_multiplier).
func run_end(k: int, multiplier: float = 1.0) -> float:
	return float(runs[k]["start"]) + tuning.wall_entry_time + tuning.wall_slide_time * maxf(multiplier, 0.0)


## Run `run`'s height t seconds after the entry (Player._update_wall): up from where it starts to its peak over
## wall_entry_time, easing out, then down the wall-run curve to wall_exit_height.
func _run_height(run: Dictionary, t: float) -> float:
	var tw: float = maxf(t - float(run["start"]), 0.0)
	var peak: float = run["peak"]
	if tw < tuning.wall_entry_time:
		var k: float = 1.0 - pow(1.0 - tw / tuning.wall_entry_time, 2.0)
		return lerpf(float(run["from"]), peak, k)
	var s: float = clampf((tw - tuning.wall_entry_time) / tuning.wall_slide_time, 0.0, 1.0)
	return tuning.wall_exit_height + (peak - tuning.wall_exit_height) * (1.0 - pow(s, tuning.wall_descent_exponent))


## The share of a wall run's slide from `peak` at which it has come down to hop_height (1: it never does, or never
## gets above it).
func _hop_share(peak: float) -> float:
	var span: float = peak - tuning.wall_exit_height
	if span <= 0.0 or hop_height <= tuning.wall_exit_height or hop_height >= peak:
		return 1.0
	return pow(1.0 - (hop_height - tuning.wall_exit_height) / span, 1.0 / tuning.wall_descent_exponent)
