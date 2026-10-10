class_name VolleyballTuning
extends Resource
## The volleyball match's numbers (VolleyballMatch; data/minigames/volleyball_tuning.tres, F6 in the level). The
## owner's design (October 10, 2026): the level starts like a normal one for a couple of seconds, the runner walks up
## to a volleyball court where a man in swim trunks hits the ball over; the runner gets under it and jumps to hit it
## back; a miss gives him a point, returning it "three or four times" wins the runner a point; first to four points;
## the runner is paid by the points won (one point 100 credits, four 400), then leaves and crosses the finish line.
## Everything else here is DESIGN-TBD (docs/questions/d10e.md). Metres are plain metres (the match stands still,
## so nothing here follows the run's pace), seconds plain seconds.

@export_group("Arrival")
## The normal run before the runner slows for the court ("the first couple seconds"), at the level's speed.
@export_range(0.5, 10.0, 0.1, "suffix:s") var run_in_seconds: float = 2.5
## From the run speed down to a walk, slowing evenly.
@export_range(0.2, 4.0, 0.05, "suffix:s") var brake_seconds: float = 1.0
## "Our character walks up to a volleyball court."
@export_range(0.5, 6.0, 0.1, "suffix:m/s") var walk_speed: float = 2.6
@export_range(0.0, 5.0, 0.1, "suffix:s") var walk_seconds: float = 1.3
## The last stretch of the walk, slowing to a stop on the runner's line.
@export_range(0.1, 3.0, 0.05, "suffix:m") var stop_distance: float = 0.6
## Both side walls open this far before the runner's line, to the end of the level: the court stands on the open
## beach (the Beach's open stretches, BeachOpen).
@export_range(0.0, 200.0, 1.0, "suffix:m") var open_walls_before: float = 45.0
## The run-in's credits: trails of 1-credit coins (a 5 at each end) from this far into the level, this far apart.
@export_range(0.0, 60.0, 1.0, "suffix:m") var credits_from: float = 12.0
@export_range(1.0, 10.0, 0.25, "suffix:m") var credit_spacing: float = 3.0

@export_group("Court")
## From the runner's line to the net, and from the net to the rival's line.
@export_range(2.0, 12.0, 0.1, "suffix:m") var court_depth: float = 4.6
@export_range(2.0, 12.0, 0.1, "suffix:m") var rival_depth: float = 4.0
## The net's top, and how deep the mesh hangs below it (the runner is 1.28 m tall: a man's 2.43 m net scaled with him).
@export_range(0.8, 4.0, 0.05, "suffix:m") var net_height: float = 1.75
@export_range(0.2, 2.0, 0.05, "suffix:m") var net_band: float = 0.7
## The side lines stand this far outside the outer lanes (on the kerb: the promenade ends wall_margin out, above
## the open beach); the end lines this far behind each player's line.
@export_range(0.0, 3.0, 0.05, "suffix:m") var side_margin: float = 0.15
@export_range(0.0, 6.0, 0.1, "suffix:m") var end_margin: float = 2.2

@export_group("Match")
## "This happens until one person has scored four points."
@export_range(1, 15) var points_to_win: int = 4
## "If we hit it back over the net enough times, say three or four times, then we get a point": the runner's returns
## in one rally that win it (the last one lands out of the rival's reach).
@export_range(1, 10) var returns_to_win_point: int = 3
## From the runner stopping on the line to the first serve (the scoreboard comes up, the rival gets ready).
@export_range(0.0, 5.0, 0.1, "suffix:s") var intro_seconds: float = 1.4
## After a point (the ball settles, the score changes, the rival reacts), before the next serve.
@export_range(0.5, 5.0, 0.1, "suffix:s") var point_pause_seconds: float = 1.8
## The serve: the rival tosses the ball up and hits it this long after.
@export_range(0.2, 2.0, 0.05, "suffix:s") var serve_toss_seconds: float = 0.7

@export_group("Ball")
@export_range(0.08, 0.4, 0.01, "suffix:m") var ball_radius: float = 0.17
## The ball's own gravity (a floatier arc than the runner's jump, so it reads from the chase camera).
@export_range(3.0, 20.0, 0.1, "suffix:m/s²") var ball_gravity: float = 9.0
## Where a ball to the runner crosses their line: the height of a jump's reach, over the middle of its lane.
@export_range(1.0, 4.0, 0.05, "suffix:m") var strike_height: float = 2.6
## The serve's flight; each later ball of the rally flies flight_step faster, down to min_flight (before the
## fairness floor, below).
@export_range(0.5, 4.0, 0.05, "suffix:s") var serve_flight: float = 1.8
@export_range(0.0, 1.0, 0.01, "suffix:s") var flight_step: float = 0.15
@export_range(0.5, 4.0, 0.05, "suffix:s") var min_flight: float = 1.2
## The runner's return to the rival (he meets it with his hand at the top of his jump, VolleyballRival).
@export_range(0.5, 4.0, 0.05, "suffix:s") var return_flight: float = 1.3
## The winning return: it lands this far into the rival's court, on the side away from him.
@export_range(0.5, 10.0, 0.1, "suffix:m") var winner_depth: float = 2.6

@export_group("Fairness")
## Every ball to the runner flies at least: reaction + lanes to cross × lane_switch_time × lane_margin + jump_lead.
@export_range(0.0, 2.0, 0.05, "suffix:s") var reaction_seconds: float = 0.5
@export_range(1.0, 4.0, 0.05) var lane_margin: float = 1.6
@export_range(0.0, 1.0, 0.05, "suffix:s") var jump_lead_seconds: float = 0.35

@export_group("Aim")
## How many lanes from the runner the rival aims each ball of a rally (the serve first; the last entry for the rest):
## at least one lane away, at most this many.
@export var max_lanes_away: PackedInt32Array = PackedInt32Array([1, 2, 8])
## Now and then a ball comes straight down on the runner's own lane (a jump on the spot).
@export_range(0.0, 1.0, 0.05) var same_lane_chance: float = 0.15

@export_group("Hit")
## The runner hits the ball when they're off the ground (a jump) and the ball reaches this box above their feet
## (half its size each way, centred hit_center_height up): over their own lane only, around their head and hands.
@export_range(0.5, 3.0, 0.05, "suffix:m") var hit_center_height: float = 1.45
@export var hit_half_size: Vector3 = Vector3(0.85, 0.7, 0.7)
## A runner standing in the ball's way (not jumping) takes it on the head: it bounces off and drops (a miss).
@export var bonk_half_size: Vector3 = Vector3(0.45, 0.8, 0.45)

@export_group("Rival")
@export_range(0.8, 2.5, 0.01, "suffix:m") var rival_height: float = 1.4
## How fast he runs across his court to meet the ball.
@export_range(1.0, 15.0, 0.1, "suffix:m/s") var rival_speed: float = 6.5
@export_range(0.0, 1.5, 0.05, "suffix:m") var rival_jump: float = 0.5

@export_group("Exit")
## After the match: the payout shows this long, then the runner sets off, reaching the run speed over exit_accel.
@export_range(0.0, 5.0, 0.1, "suffix:s") var payout_seconds: float = 1.6
@export_range(0.1, 3.0, 0.05, "suffix:s") var exit_accel_seconds: float = 0.9
## The run from the runner's line to the finish line, in seconds at the run speed (past the net and the rival's line).
@export_range(1.0, 10.0, 0.1, "suffix:s") var exit_seconds: float = 2.6
## The net and its posts sink into the sand as the runner sets off, so they run over where it stood.
@export_range(0.1, 3.0, 0.05, "suffix:s") var net_sink_seconds: float = 0.8

@export_group("Scoring")
## "If they only won one round, they'll get a hundred, whereas if they got all four points, they get 400 credits."
@export_range(0, 1000, 5) var payout_per_point: int = 100
## Level score (leaderboards; never spent) for each return, and for each point won.
@export_range(0, 1000, 5) var return_score: int = 25
@export_range(0, 5000, 5) var point_score: int = 150
## The level's stars by the points won (1 star for finishing).
@export_range(0, 15) var two_star_points: int = 2
@export_range(0, 15) var three_star_points: int = 4


## Seconds a ball to the runner flies when it's ball `index` of its rally (0: the serve) and leaves the runner
## `lanes` lanes to cross (lane_switch_time from the run's movement tuning): the rally's pace, never under the
## fairness floor.
func flight_for(index: int, lanes: int, lane_switch_time: float) -> float:
	var paced: float = maxf(serve_flight - flight_step * index, min_flight)
	return maxf(paced, fair_flight(lanes, lane_switch_time))


## The least a ball may fly that leaves `lanes` lanes to cross.
func fair_flight(lanes: int, lane_switch_time: float) -> float:
	return reaction_seconds + absi(lanes) * lane_switch_time * lane_margin + jump_lead_seconds


## The most lanes from the runner the rival aims ball `index` of a rally.
func lanes_away(index: int) -> int:
	if max_lanes_away.is_empty():
		return 1
	return maxi(max_lanes_away[clampi(index, 0, max_lanes_away.size() - 1)], 1)


## The level's stars for `points` won (finished: at least 1).
func stars_for(points: int) -> int:
	if points >= three_star_points:
		return 3
	if points >= two_star_points:
		return 2
	return 1
