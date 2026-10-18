class_name VolleyballBot
extends RefCounted
## Plays the volleyball match (VolleyballMatch) for the tests and the review tool, through the runner's own actions
## (Player.press, as the input layer does). Call step() once per physics frame. Its skill decides how it plays:
## - "perfect": switches to the ball's lane as soon as it's hit and jumps as the closing ring meets the ball
##   (VolleyballTuning.jump_lead_seconds before it reaches the runner's line), so it returns every ball;
## - "idle": never moves or jumps (every ball drops or lands on its head);
## - "stand": gets under every ball but never jumps (it bounces off its head);
## - "wrong": switches to a lane beside the ball's and jumps (every ball drops beside it);
## - "points:N": plays perfectly until it has won N points, then stands still.

var match_game: VolleyballMatch
var player: Player
var skill: String = "perfect"
## Seconds before the ball reaches the runner's line to jump (below 0: the ring's own cue).
var jump_lead: float = -1.0

var _jumped_for: int = -1
var _balls: int = 0
var _last_state: int = -1


func _init(p_match: VolleyballMatch, p_skill: String = "perfect") -> void:
	match_game = p_match
	player = p_match.world.player
	skill = p_skill


func step() -> void:
	if match_game == null or not is_instance_valid(match_game) or player == null or not is_instance_valid(player):
		return
	var state: int = match_game.ball_state
	if state == VolleyballMatch.BallState.TO_RUNNER and _last_state != state:
		_balls += 1
	_last_state = state
	if state != VolleyballMatch.BallState.TO_RUNNER or match_game.target_lane < 0:
		return
	var mode: String = skill
	if skill.begins_with("points:"):
		mode = "perfect" if match_game.points_won < int(skill.get_slice(":", 1)) else "idle"
	if mode == "idle":
		return
	var target: int = match_game.target_lane
	if mode == "wrong":
		target = target + 1 if target + 1 < player.geo.lane_count else target - 1
	if player.lane < target:
		player.press(&"move_right")
	elif player.lane > target:
		player.press(&"move_left")
	if mode == "stand":
		return
	var lead: float = jump_lead if jump_lead > -0.5 else match_game.tuning.jump_lead_seconds
	if _jumped_for != _balls and player.grounded and match_game.ball.time_left() <= lead:
		player.press(&"jump")
		_jumped_for = _balls
