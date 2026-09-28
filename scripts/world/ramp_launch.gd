class_name RampLaunch
extends RefCounted
## Where a ramp launches the player and how fast (GDD §3): a ramp in the outer lane carries a player
## who runs onto it up onto the wall, higher than a free entry, and adds a speed boost that fades away
## the same way a speed pad's does. This predicts that wall run from MovementTuning, following the
## Player's own movement (Player._try_enter_wall, _update_wall): up onto the wall over wall_entry_time,
## then down it along the wall-run curve over wall_slide_time, at run speed plus the fading boost
## (MovementTuning.boost_left). Everything that predicts a ramp's wall run uses it: the generator's
## credits along it (LevelGenerator.wall_run_credits) and rules that keep a wall hazard out of a
## ramp's launch (task B5's wall fences, through `gen.ramp_launch(ramp)`). test_movement holds it to
## the real Player.
##
##   var launch: RampLaunch = gen.ramp_launch(ramp)       # or RampLaunch.of(ramp, tuning, speed)
##   launch.distance_at(t), launch.height_at(t)           # where the player is t s after the launch
##   launch.speed_at(t), launch.body_at(t)                # how fast; the heights their body spans
##   launch.time_at(d), launch.height_at_distance(d)      # when (and how high) they pass distance d
##   launch.start, launch.wall_reached(), launch.end()    # the launch, the wall face, the drop
##
## Time 0 is the launch: the physics frame in which the player's feet reach the ramp. `start` is where
## that happens at the earliest; the Player checks triggers once a physics frame, so the real launch
## comes up to a frame's motion later (0.3 m at 18 m/s), and the player then runs that much ahead of
## the prediction. Heights depend only on the time since the launch, so they match exactly. It
## assumes the player runs onto the ramp at run speed with no boost left from before (`boost_before`
## adds one, say from a speed pad just before it) and without claws (`wall_time_multiplier` 1; claws
## lengthen wall runs). At end() the player drops off the wall into the ramp's lane.

## Which wall the ramp launches onto: -1 left, 1 right.
var side: int = 1
## Track distance of the launch (the earliest; see the header).
var start: float = 0.0
## Run speed, and the boost on top of it right after the launch (the ramp's, plus any from before).
var run_speed: float = 0.0
var boost: float = 0.0
## Height on the wall the ramp carries the player to (ramp_entry_height, at most wall_max_height).
var peak: float = 0.0
var tuning: MovementTuning

var _slide_time: float = 0.0


## The wall run that `ramp` (a LevelLayout.ramps entry: {side, at}) launches a player into who runs
## onto it at `speed`.
static func of(ramp: Dictionary, p_tuning: MovementTuning, speed: float, boost_before: float = 0.0,
		wall_time_multiplier: float = 1.0) -> RampLaunch:
	var out := RampLaunch.new()
	out.tuning = p_tuning
	out.side = int(ramp["side"])
	# The feet's trigger sensor reaches this far ahead of the player (Player._check_triggers).
	out.start = float(ramp["at"]) - Player.SENSOR_SIZE.z * 0.5
	out.run_speed = maxf(speed, 0.001)
	out.boost = maxf(boost_before, 0.0) + p_tuning.ramp_speed_boost
	out.peak = minf(p_tuning.ramp_entry_height, p_tuning.wall_max_height)
	out._slide_time = p_tuning.wall_slide_time * wall_time_multiplier
	return out


## Seconds from the launch until the player drops off the wall.
func duration() -> float:
	return tuning.wall_entry_time + _slide_time


## The player's speed t seconds after the launch: run speed plus what's left of the boost.
func speed_at(t: float) -> float:
	return run_speed + tuning.boost_left(boost, t)


## Track distance t seconds after the launch.
func distance_at(t: float) -> float:
	var tt: float = maxf(t, 0.0)
	return start + run_speed * tt + tuning.boost_distance(boost, tt)


## Height on the wall t seconds after the launch (the middle of the body, Player.h): up from the floor
## to `peak` over wall_entry_time, easing out, then down along the wall-run curve to wall_exit_height
## at duration().
func height_at(t: float) -> float:
	var entry: float = tuning.wall_entry_time
	if t < entry:
		var k: float = 1.0 - pow(1.0 - maxf(t, 0.0) / entry, 2.0)
		return peak * k
	var s: float = clampf((t - entry) / _slide_time, 0.0, 1.0)
	return tuning.wall_exit_height + (peak - tuning.wall_exit_height) * (1.0 - pow(s, tuning.wall_descent_exponent))


## The heights (world y, bottom and top) the wall runner's body spans t seconds after the launch,
## once on the wall (from wall_reached()): the hitbox lies along the wall there, as wide as the
## hurtbox (Player.hurtbox_aabb). Its body also reaches out from the wall face by the hurtbox's height.
func body_at(t: float) -> Vector2:
	var half: float = tuning.hurtbox_size.x * 0.5
	var h: float = height_at(t)
	return Vector2(h - half, h + half)


## Seconds after the launch at which the player passes track distance d (0 at or before `start`).
func time_at(d: float) -> float:
	var x: float = d - start
	if x <= 0.0:
		return 0.0
	var decay: float = tuning.boost_decay_per_second
	var fade: float = boost / decay  # seconds until the boost is gone
	var boosted: float = run_speed * fade + 0.5 * boost * fade  # distance covered meanwhile
	if x <= boosted:
		var v: float = run_speed + boost
		return (v - sqrt(maxf(v * v - 2.0 * decay * x, 0.0))) / decay
	return fade + (x - boosted) / run_speed


## Height on the wall where the player passes track distance d.
func height_at_distance(d: float) -> float:
	return height_at(time_at(d))


## Track distance where the entry is over: the player is at the wall face, at `peak`.
func wall_reached() -> float:
	return distance_at(tuning.wall_entry_time)


## Track distance where the wall run ends and the player drops back into the ramp's lane.
func end() -> float:
	return distance_at(duration())
