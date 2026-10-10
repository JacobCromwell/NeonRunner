class_name VolleyballMatch
extends MiniGame
## The Beach's second level, a beach volleyball match (the owner, October 10, 2026; MiniGame; its numbers are
## VolleyballTuning's, data/minigames/volleyball_tuning.tres):
## - It starts like a normal level: the runner runs the Beach's street for a couple of seconds (run_in_seconds),
##   collecting a trail of credits, then slows to a walk and walks up to a volleyball court laid across the street
##   (VolleyballCourt), stopping on its line. The side walls open before the court, so it stands on the open beach.
## - Across the net a man in swim trunks (VolleyballRival) serves. A ring on the sand marks where the ball comes down
##   in a lane on the runner's line, from the moment it's hit, and a second ring closes in on it, meeting it when it's
##   time to jump. The runner gets under it (lanes, as always) and jumps to hit it back: the hit counts when the ball
##   reaches them in the air, over their lane (hit_half_size around their head and hands). One standing in its way
##   without jumping takes it on the head; one in the wrong lane lets it drop. Either way the rival wins the point.
## - Each return goes back over the net; he runs to it and hits it back, each ball a little quicker and further from
##   the runner than the last (flight_for, lanes_away), never quicker than the runner can reach and jump (the fairness
##   floor: fair_flight). The runner's returns_to_win_point-th return in a rally lands out of his reach: he dives and
##   misses, and the runner wins the point.
## - First to points_to_win. The runner is paid payout_per_point credits for each point they won (RunResult: the
##   level's completion bonus, payout()), shown as the match ends; then the net sinks into the sand, the rival steps
##   aside and waves, and the runner runs on across the finish line, where the level ends like any other.
## The runner can't die here: nothing on the track hurts and it has no gaps. Every random choice (where each ball
## goes) comes from `rng`, seeded by the level, so every attempt plays the same match against the same moves.
## DESIGN-TBD (docs/questions/d10e.md): everything the owner's request leaves open: the run-in, the court and how the
## runner leaves it (the net sinks), the hit's box and timing, the rival's aim and pace, the stars and the score.

enum Phase { APPROACH, INTRO, PLAY, POINT, PAYOUT, EXIT, DONE }
enum BallState { TOSS, TO_RUNNER, TO_RIVAL, WINNER, DEAD }

const MARKER_SHADER: Shader = preload("res://scripts/minigames/volleyball/volleyball_marker.gdshader")
## The marker's quad (half size), its ring's radius and where the closing ring starts (metres).
const MARKER_HALF: float = 1.5
const MARKER_RADIUS: float = 0.5
const MARKER_START: float = 1.4
## How long the runner's arms stay up after a hit (the follow-through), and how close (seconds) the ball must be for
## an airborne runner to reach for it.
const REACH_AFTER: float = 0.3
const REACH_BEFORE: float = 0.45
## The rival reacts to the winning return this late, and dives this long before it lands.
const WINNER_REACT: float = 0.35
const WINNER_DIVE: float = 0.42
## Where the ball goes when it bounces off a runner's head: up and back toward the camera.
const BONK_VELOCITY := Vector3(0.0, 3.2, 2.2)
## Calls' colours: the point's in the HUD's gain colour, a miss's in the plain text colour (never the danger red:
## nothing hurt the runner).
const WIN_COLOR := Color(0.55, 1.0, 0.75)

signal point_scored(by_runner: bool)
signal match_over(points_won: int, points_lost: int)

var tuning: VolleyballTuning
var phase: Phase = Phase.APPROACH
var ball_state: BallState = BallState.DEAD
var points_won: int = 0
var points_lost: int = 0
## Returns the runner has made in this rally, and in the whole match.
var returns: int = 0
var total_returns: int = 0
## Which ball of the rally is coming to the runner (0: the serve).
var rally_ball: int = 0
## The lane the ball now flying to the runner comes down in (-1: none).
var target_lane: int = -1
## Seconds in the current phase.
var phase_time: float = 0.0
## What happened, in order, for the tests and the review tool: "serve", "to_runner:<lane>:<runner's lane>:<seconds>",
## "hit", "bonk", "drop", "winner", "point:runner", "point:rival", "match:<won>-<lost>", "exit".
var events: PackedStringArray = []
## The lowest any ball in play has passed over the net's top (metres; the tests check every arc clears it).
var lowest_over_net: float = INF

## The track: the run-in's end (the runner starts slowing), where the walk begins, the runner's line, the net, the
## rival's line, and the finish (track distances).
var run_in_end: float = 0.0
var walk_from: float = 0.0
var stand: float = 0.0
var net_at: float = 0.0
var rival_at: float = 0.0
var finish: float = 0.0
## The level's run speed (the runner's again once they set off).
var run_speed: float = 18.0

var court: VolleyballCourt
var ball: VolleyballBall
var rival: VolleyballRival
var hud: VolleyballHud
var marker: MeshInstance3D

var _marker_mat: ShaderMaterial
var _avatar: PlayerAvatar
var _payout: int = 0
var _flight: float = 0.0
var _reach_left: float = 0.0
var _landed: bool = false
var _half_x: float = 4.0
var _winner_dir: float = 1.0
var _dived: bool = false


func plan_layout(p_context: RunContext) -> LevelLayout:
	_ensure_tuning()
	var t: MovementTuning = p_context.config.movement_for(p_context.tuning)
	_plan_track(t.run_speed)
	var out := LevelLayout.new()
	out.lane_count = p_context.config.lane_count
	out.length = finish
	# The run-in's credits: a trail down the runner's start lane, and one beside it further on to switch to.
	var start_lane: int = out.lane_count / 2
	var trail_end: float = run_in_end - 4.0
	_trail(out, start_lane, tuning.credits_from, trail_end * 0.6)
	_trail(out, mini(start_lane + 1, out.lane_count - 1) if out.lane_count > 1 else start_lane, trail_end * 0.55, trail_end)
	# Both side walls open before the court, to the end of the track: the court stands on the open beach.
	var open_from: float = maxf(stand - tuning.open_walls_before, 0.0)
	var open_to: float = finish + TrackBuilder.RUN_OUT + TrackBuilder.CHUNK_LENGTH
	for side: int in [-1, 1]:
		out.wall_gaps.append({"side": side, "start": open_from, "end": open_to})
	return out


## The match's distances along the track at run speed `speed` (plan_layout; the tests too).
func _plan_track(speed: float) -> void:
	run_speed = speed
	run_in_end = speed * tuning.run_in_seconds
	walk_from = run_in_end + (speed + tuning.walk_speed) * 0.5 * tuning.brake_seconds
	stand = walk_from + tuning.walk_speed * tuning.walk_seconds + tuning.stop_distance
	net_at = stand + tuning.court_depth
	rival_at = net_at + tuning.rival_depth
	finish = maxf(stand + speed * tuning.exit_seconds, rival_at + tuning.end_margin + 10.0)


## The runner's speed at track distance `d` on the way to the court: the run, slowing evenly to a walk, the walk,
## then slowing to a stop on the line.
func approach_speed(d: float) -> float:
	var walk: float = tuning.walk_speed
	if d < run_in_end:
		return run_speed
	if d < walk_from:
		var decel: float = (run_speed * run_speed - walk * walk) / maxf(2.0 * (walk_from - run_in_end), 0.001)
		return sqrt(maxf(run_speed * run_speed - 2.0 * decel * (d - run_in_end), walk * walk))
	var stop_from: float = stand - tuning.stop_distance
	if d < stop_from:
		return walk
	if d < stand - 0.005:
		return maxf(walk * sqrt((stand - d) / tuning.stop_distance), 0.35)
	return 0.0


func _trail(out: LevelLayout, lane: int, from: float, to: float) -> void:
	var d: float = from
	var first: bool = true
	while d <= to:
		var value: int = 5 if first or d + tuning.credit_spacing > to else 1
		out.credits.append({"at": d, "surface": "floor", "lane": lane, "side": 0, "height": 0.7, "value": value,
			"risky": false})
		first = false
		d += tuning.credit_spacing


func _ensure_tuning() -> void:
	if tuning == null:
		tuning = def_tuning() as VolleyballTuning
		if tuning == null:
			tuning = VolleyballTuning.new()


func _start() -> void:
	_ensure_tuning()
	if is_zero_approx(stand):
		_plan_track(world.tuning.run_speed)
	run_speed = world.tuning.run_speed
	_half_x = world.geo.half_width() + tuning.side_margin
	court = VolleyballCourt.new()
	add_child(court)
	court.build(_half_x, TrackGeometry.world_z(stand), TrackGeometry.world_z(net_at), TrackGeometry.world_z(rival_at),
		tuning, world.skin)
	rival = VolleyballRival.new()
	add_child(rival)
	rival.position = Vector3(0.0, 0.0, TrackGeometry.world_z(rival_at))
	rival.setup(tuning.rival_height, tuning.rival_speed, tuning.rival_jump)
	ball = VolleyballBall.new()
	add_child(ball)
	ball.setup(tuning.ball_radius, tuning.ball_gravity)
	ball.landed.connect(func(_at: Vector3) -> void: _landed = true)
	ball.hold(rival.hold_point())
	marker = MeshInstance3D.new()
	marker.name = "Marker"
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * MARKER_HALF * 2.0
	marker.mesh = quad
	_marker_mat = ShaderMaterial.new()
	_marker_mat.shader = MARKER_SHADER
	_marker_mat.set_shader_parameter(&"quad_half", MARKER_HALF)
	_marker_mat.set_shader_parameter(&"radius", MARKER_RADIUS)
	marker.material_override = _marker_mat
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marker.rotation.x = -PI * 0.5
	# Drawn under the street until the first ball, so its shader compiles during the load (as ShaderWarmup does for
	# the level's other looks), not in the frame of the first serve.
	marker.position = Vector3(0.0, -3.0, TrackGeometry.world_z(stand))
	add_child(marker)
	hud = VolleyballHud.new()
	add_child(hud)
	_avatar = world.player.find_child("Avatar", true, false) as PlayerAvatar
	phase = Phase.APPROACH


func _physics_process(delta: float) -> void:
	if world == null or tuning == null:
		return
	var p: Player = world.player
	if not p.running:
		_animate(delta)
		return
	phase_time += delta
	match phase:
		Phase.APPROACH:
			# The run-in is the run's own (a dash still works); from its end the match walks the runner up.
			p.speed_override = -1.0 if p.distance < run_in_end else approach_speed(p.distance)
			if p.distance >= run_in_end and p.speed_override <= 0.0:
				_set_phase(Phase.INTRO)
				hud.visible = true
				_show_score()
				hud.call_out("FIRST TO %d!" % tuning.points_to_win, Color.WHITE, maxf(tuning.intro_seconds - 0.4, 0.2))
		Phase.INTRO:
			p.speed_override = 0.0
			if phase_time >= tuning.intro_seconds:
				_serve()
		Phase.PLAY:
			p.speed_override = 0.0
			_play(delta)
		Phase.POINT:
			p.speed_override = 0.0
			ball.advance(delta)
			if phase_time >= tuning.point_pause_seconds:
				if points_won >= tuning.points_to_win or points_lost >= tuning.points_to_win:
					_end_match()
				else:
					_serve()
		Phase.PAYOUT:
			p.speed_override = 0.0
			ball.advance(delta)
			if phase_time >= tuning.payout_seconds:
				_set_phase(Phase.EXIT)
				events.append("exit")
				# DESIGN-TBD (docs/questions/d10e.md): the net sinks into the sand so the runner runs on over it.
				court.sink(tuning.net_sink_seconds)
				hud.visible = false
				ball.visible = false
				marker.visible = false
				var side: float = -signf(p.position.x) if not is_zero_approx(p.position.x) else 1.0
				rival.run_to(side * (world.geo.half_width() + 0.15))
		Phase.EXIT:
			var k: float = clampf(phase_time / tuning.exit_accel_seconds, 0.0, 1.0)
			p.speed_override = maxf(run_speed * k, 0.5)
			if rival.mode == VolleyballRival.Mode.READY and rival.mode_time > 0.1:
				rival.wave()
			if k >= 1.0:
				p.speed_override = -1.0
				_set_phase(Phase.DONE)
		Phase.DONE:
			pass
	_animate(delta)


## The court, the rival and the runner's reach move on every frame, the ball while it's out of play.
func _animate(delta: float) -> void:
	court.advance(delta)
	rival.advance(delta)
	if ball.mode == VolleyballBall.Mode.HELD:
		ball.hold(rival.hold_point())
	_pose_runner(delta)


func _set_phase(next: Phase) -> void:
	phase = next
	phase_time = 0.0


# --- The rally --------------------------------------------------------------------------------------------------

## A new rally: the rival serves (the toss, then the hit).
func _serve() -> void:
	_set_phase(Phase.PLAY)
	returns = 0
	rally_ball = 0
	_landed = false
	_dived = false
	ball.visible = true
	_show_score()
	rival.run_to(rival.position.x)
	rival.swing_in(tuning.serve_toss_seconds, true)
	ball.throw_to(rival.hold_point(), _rival_strike(rival.position.x), tuning.serve_toss_seconds)
	ball_state = BallState.TOSS
	events.append("serve")


func _play(delta: float) -> void:
	_landed = false
	ball.advance(delta)
	match ball_state:
		BallState.TOSS:
			if ball.time_left() <= 0.0:
				_send_to_runner()
		BallState.TO_RUNNER:
			_update_marker()
			var contact: String = _runner_contact()
			if contact == "hit":
				_runner_hit()
			elif contact == "bonk":
				events.append("bonk")
				ball.knock(BONK_VELOCITY + Vector3(rng.randf_range(-0.8, 0.8), 0.0, 0.0))
				world.play_sfx_at(&"volley_bounce", ball.global_position)
				_point(false, "JUMP TO HIT IT!")
			elif _landed or ball.mode != VolleyballBall.Mode.FLYING:
				events.append("drop")
				world.play_sfx_at(&"volley_bounce", ball.global_position)
				_point(false, "MISSED!")
		BallState.TO_RIVAL:
			if ball.time_left() <= 0.0:
				rally_ball += 1
				_send_to_runner()
		BallState.WINNER:
			var left: float = ball.time_left()
			if not _dived and left <= WINNER_DIVE:
				_dived = true
				rival.dive(_winner_dir)
			if ball.duration - left >= WINNER_REACT and rival.mode == VolleyballRival.Mode.READY and not _dived:
				rival.run_to(clampf(rival.position.x + _winner_dir * 1.2, -_half_x, _half_x))
			if _landed or ball.mode != VolleyballBall.Mode.FLYING:
				world.play_sfx_at(&"volley_bounce", ball.global_position)
				_point(true, "POINT!")


## The rival hits the ball (the serve's or a return's) to a lane on the runner's line: where (_aim) and how fast
## (VolleyballTuning.flight_for, never under the fairness floor).
func _send_to_runner() -> void:
	var lane_now: int = world.player.lane
	target_lane = _aim(rally_ball, lane_now)
	_flight = tuning.flight_for(rally_ball, absi(target_lane - lane_now), world.tuning.lane_switch_time)
	var to := Vector3(world.geo.lane_x(target_lane), tuning.strike_height, TrackGeometry.world_z(world.player.distance))
	ball.throw_to(ball.global_position, to, _flight)
	_note_net_clearance()
	ball_state = BallState.TO_RUNNER
	world.play_sfx_at(&"volley_hit", ball.global_position)
	events.append("to_runner:%d:%d:%.2f" % [target_lane, lane_now, _flight])
	marker.position = Vector3(to.x, 0.03, to.z)
	marker.visible = true
	_update_marker()


## The lane ball `index` of a rally comes down in, for a runner in `lane`: at least one lane away and at most
## VolleyballTuning.lanes_away(index), or now and then (same_lane_chance) their own lane.
func _aim(index: int, lane: int) -> int:
	var n: int = world.geo.lane_count
	if rng.randf() < tuning.same_lane_chance:
		return lane
	var reach: int = mini(tuning.lanes_away(index), n - 1)
	var options: Array[int] = []
	for l: int in n:
		var d: int = absi(l - lane)
		if d >= 1 and d <= reach:
			options.append(l)
	if options.is_empty():
		return lane
	return options[rng.randi() % options.size()]


## What the ball does to the runner this frame: "hit" (they're in the air and it reaches their hands), "bonk" (they
## stand in its way), or "".
func _runner_contact() -> String:
	var p: Player = world.player
	if not p.alive or p.surface != Player.Surface.FLOOR:
		return ""
	var b: Vector3 = ball.global_position
	var r := Vector3.ONE * ball.radius
	var feet: Vector3 = p.position
	var d: Vector3 = (b - (feet + Vector3(0.0, tuning.hit_center_height, 0.0))).abs()
	var hs: Vector3 = tuning.hit_half_size + r
	if not p.grounded and d.x <= hs.x and d.y <= hs.y and d.z <= hs.z:
		return "hit"
	var db: Vector3 = (b - (feet + Vector3(0.0, tuning.bonk_half_size.y, 0.0))).abs()
	var bs: Vector3 = tuning.bonk_half_size + r
	if p.grounded and db.x <= bs.x and db.y <= bs.y and db.z <= bs.z:
		return "bonk"
	return ""


## The runner hit it back: over the net to the rival, or, as the rally's winning return, out of his reach.
func _runner_hit() -> void:
	returns += 1
	total_returns += 1
	events.append("hit")
	marker.visible = false
	target_lane = -1
	_reach_left = REACH_AFTER
	world.play_sfx_at(&"volley_hit", ball.global_position)
	world.effects.burst(ball.global_position, Color(0.95, 0.92, 0.8), 14, 0.6)
	world.score.add_bonus(&"volley_return", tuning.return_score, "Return")
	_show_score()
	var from: Vector3 = ball.global_position
	if returns >= tuning.returns_to_win_point:
		# The winning return lands on the side of his court away from him.
		_winner_dir = -signf(rival.position.x) if absf(rival.position.x) > 0.3 else (1.0 if rng.randf() < 0.5 else -1.0)
		var land_x: float = _winner_dir * (_half_x - 0.6)
		var land := Vector3(land_x, ball.radius, TrackGeometry.world_z(net_at + tuning.winner_depth))
		ball.throw_to(from, land, tuning.return_flight)
		_note_net_clearance()
		ball_state = BallState.WINNER
		events.append("winner")
		return
	# Back to the rival, where he can reach it in time.
	var reach: float = rival.speed * maxf(tuning.return_flight - VolleyballRival.RISE_SECONDS - 0.1, 0.1)
	var x: float = lerpf(rival.position.x, from.x * 0.6, 0.6)
	x = clampf(x, rival.position.x - reach, rival.position.x + reach)
	x = clampf(x, -_half_x + 0.6, _half_x - 0.6)
	rival.run_to(x)
	rival.swing_in(tuning.return_flight)
	ball.throw_to(from, _rival_strike(x), tuning.return_flight)
	_note_net_clearance()
	ball_state = BallState.TO_RIVAL


## How high the arc just thrown passes over the net's top (lowest_over_net keeps the lowest).
func _note_net_clearance() -> void:
	var net_z: float = TrackGeometry.world_z(net_at)
	var vz: float = ball.start_velocity.z
	if is_zero_approx(vz):
		return
	var t: float = (net_z - ball.start.z) / vz
	if t > 0.0:
		lowest_over_net = minf(lowest_over_net, ball.point_at(t).y - ball.radius - tuning.net_height)


## Where the rival meets the ball at world x `x`: his hand at the top of his jump, a little in front of him.
func _rival_strike(x: float) -> Vector3:
	var p: Vector3 = rival.strike_point()
	return Vector3(x, p.y, p.z)


## A point to the runner or to the rival: the call, the score, the rival's reaction.
func _point(by_runner: bool, call: String) -> void:
	_set_phase(Phase.POINT)
	ball_state = BallState.DEAD
	ball.dead()
	marker.visible = false
	target_lane = -1
	if by_runner:
		points_won += 1
		world.score.add_bonus(&"volley_point", tuning.point_score, "Point")
	else:
		points_lost += 1
	events.append("point:%s" % ("runner" if by_runner else "rival"))
	rival.react(not by_runner)
	world.play_sfx(&"volley_whistle")
	hud.call_out(call, WIN_COLOR if by_runner else Color.WHITE, tuning.point_pause_seconds - 0.5)
	_show_score()
	point_scored.emit(by_runner)


## First to points_to_win: the payout (points won × payout_per_point), shown, and the rival's goodbye.
## DESIGN-TBD (docs/questions/d10e.md): the payout is the level's completion bonus (payout()), instead of the usual one.
func _end_match() -> void:
	_set_phase(Phase.PAYOUT)
	_payout = points_won * tuning.payout_per_point
	events.append("match:%d-%d" % [points_won, points_lost])
	var won: bool = points_won >= tuning.points_to_win
	hud.call_out("%s  %d – %d" % ["YOU WIN!" if won else "MATCH OVER", points_won, points_lost],
		WIN_COLOR if won else Color.WHITE, tuning.payout_seconds)
	hud.show_payout(_payout)
	if _payout > 0:
		world.play_sfx(&"jackpot")
	rival.react(not won)
	match_over.emit(points_won, points_lost)


func _show_score() -> void:
	hud.show_score(points_won, points_lost, tuning.points_to_win, returns, tuning.returns_to_win_point)


## The closing ring: from MARKER_START down to the ring as the ball nears, meeting it jump_lead_seconds before the
## ball reaches the runner's line (time to jump), then held on the ring.
func _update_marker() -> void:
	if not marker.visible:
		return
	var left: float = ball.time_left() - tuning.jump_lead_seconds
	var k: float = clampf(left / maxf(_flight - tuning.jump_lead_seconds, 0.01), 0.0, 1.0)
	_marker_mat.set_shader_parameter(&"closing", lerpf(MARKER_RADIUS, MARKER_START, k))
	if ball.time_left() < -0.4:
		marker.visible = false


## The runner reaches up for the ball while they're in the air with it close, and follows through after a hit: both
## arms raised over the jump's pose (PlayerAvatar's rig, posed after the avatar's own animation each frame).
func _pose_runner(delta: float) -> void:
	_reach_left = maxf(_reach_left - delta, 0.0)
	if _avatar == null or not is_instance_valid(_avatar):
		return
	var p: Player = world.player
	var near: bool = ball_state == BallState.TO_RUNNER and ball.time_left() < REACH_BEFORE and ball.time_left() > -0.3
	var weight: float = 1.0 if _reach_left > 0.0 else (0.85 if near else 0.0)
	if p.grounded or weight <= 0.0:
		return
	for side: int in [-1, 1]:
		var pre: String = "_l" if side < 0 else "_r"
		var upper: Node3D = _avatar.rig.joint(StringName("upper_arm" + pre))
		var fore: Node3D = _avatar.rig.joint(StringName("forearm" + pre))
		upper.rotation = upper.rotation.lerp(VolleyballRival._limb(side, Vector3(165.0, 0.0, 12.0)), weight)
		fore.rotation = fore.rotation.lerp(VolleyballRival._limb(side, Vector3(15.0, 0.0, 0.0)), weight)


# --- What the level reports ---------------------------------------------------------------------------------------

func payout() -> int:
	return _payout


func stars(completed: bool) -> int:
	return tuning.stars_for(points_won) if completed and tuning != null else 0


func stats() -> Dictionary:
	var out: Dictionary = super.stats()
	out["points_won"] = points_won
	out["points_lost"] = points_lost
	out["returns"] = total_returns
	out["match_payout"] = _payout
	return out


## True once the match is over (the payout decided).
func match_finished() -> bool:
	return phase == Phase.PAYOUT or phase == Phase.EXIT or phase == Phase.DONE
