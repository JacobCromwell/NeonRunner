class_name VolleyballRival
extends Node3D
## The volleyball match's opponent (VolleyballMatch; his look is VolleyballRivalSuit's): a man in swim trunks on the
## far side of the net, on the shared HumanoidRig, animated in code like the runner. The rig's own activities give
## him his ready stance, his run across the court and his jump (HumanoidRig.animate); his arms are posed on top for
## what a volleyball player does with them: the toss and the overhand hit of a serve, a hit back over the net, a
## dive for a ball out of reach, a fist pump for a point, hands on his head for a point lost, and a wave goodbye.
## He faces the runner (+z) whenever he isn't running across, and moves only when the match calls advance().

enum Mode { READY, RUN, SWING, DIVE, CHEER, SULK, WAVE }

## The jump of a hit: rising for this long before he meets the ball (his hand at its top as it arrives).
const RISE_SECONDS: float = 0.28
## How long a dive takes to go down, stay down, and get back up.
const DIVE_SECONDS: Vector3 = Vector3(0.3, 0.6, 0.5)
## Where the ball sits in his hand when he holds it for a serve, and where his hitting hand meets it (his own space,
## facing +z; scaled with him).
const HOLD_POINT := Vector3(-0.22, 0.95, 0.25)
const REACH_HEIGHT: float = 1.62

var rig: HumanoidRig
var mode: Mode = Mode.READY
## His height (feet to the top of his hair), the tuning's.
var height: float = 1.36
## Where he runs to across his court (world x), and how fast.
var target_x: float = 0.0
var speed: float = 6.5
var jump_height: float = 0.5
## Seconds since the current mode began.
var mode_time: float = 0.0

var _scale: float = 1.0
var _stride: float = 0.0
var _y: float = 0.0
var _vy: float = 0.0
var _gravity: float = 12.0
var _yaw: float = PI
var _swing_in: float = -1.0
var _serving: bool = false
var _dive_dir: float = 1.0
var _turned: float = 0.0


func setup(p_height: float, p_speed: float, p_jump: float) -> void:
	name = "Rival"
	height = p_height
	speed = p_speed
	jump_height = p_jump
	rig = HumanoidRig.new()
	rig.name = "Rig"
	add_child(rig)
	var anim := load(PlayerAvatar.ANIM_TUNING_PATH) as HumanoidAnimTuning
	rig.build(VolleyballRivalSuit.parts(), VolleyballRivalSuit.material(), anim if anim != null else HumanoidAnimTuning.new())
	_scale = height / VolleyballRivalSuit.DESIGN_HEIGHT
	rig.scale = Vector3.ONE * _scale
	# The jump's gravity, so that it rises RISE_SECONDS to its top.
	_gravity = 2.0 * maxf(jump_height, 0.05) / (RISE_SECONDS * RISE_SECONDS)
	target_x = position.x
	rig.rotation.y = _yaw
	rig.animate({}, 0.0)


## Runs across his court to world x `x` (and turns back to the net once there).
func run_to(x: float) -> void:
	target_x = x
	if mode != Mode.SWING and mode != Mode.DIVE:
		_set_mode(Mode.RUN if absf(x - position.x) > 0.05 else Mode.READY)


## Seconds he needs to run to world x `x` from where he is.
func time_to(x: float) -> float:
	return absf(x - position.x) / maxf(speed, 0.1)


## Hits the ball `seconds` from now: he jumps so his hand is at its top then, his arm swinging through it. `serve`:
## the serve's toss first (the ball in his left hand goes up; the match throws it).
func swing_in(seconds: float, serve: bool = false) -> void:
	_swing_in = maxf(seconds, 0.0)
	_serving = serve
	_set_mode(Mode.SWING)


## A ball out of his reach on side `dir` (-1 left, 1 right, world x): he dives for it, and misses.
func dive(dir: float) -> void:
	_dive_dir = signf(dir) if not is_zero_approx(dir) else 1.0
	_set_mode(Mode.DIVE)


## The point is over: a fist pump (`won`) or his hands on his head.
func react(won: bool) -> void:
	_set_mode(Mode.CHEER if won else Mode.SULK)


## The match is over: he waves the runner on from the side of the court.
func wave() -> void:
	_set_mode(Mode.WAVE)


func ready_stance() -> void:
	_set_mode(Mode.READY)


## Where his hitting hand meets the ball at the top of a hit, in world space.
func strike_point() -> Vector3:
	return global_position + Vector3(0.0, REACH_HEIGHT * _scale + jump_height, 0.25 * _scale)


## Where the ball sits in his hand before a serve's toss, in world space (his left hand, in front of him).
func hold_point() -> Vector3:
	return global_position + Vector3(HOLD_POINT.x, HOLD_POINT.y, HOLD_POINT.z) * _scale


## True while he is off the ground.
func airborne() -> bool:
	return _y > 0.001 or _vy > 0.0


func advance(delta: float) -> void:
	mode_time += delta
	var state: Dictionary = {"speed": 0.0}
	match mode:
		Mode.RUN:
			var dx: float = target_x - position.x
			var step: float = minf(absf(dx), speed * delta)
			position.x += signf(dx) * step
			_stride += step
			state = {"speed": speed, "distance": _stride}
			if absf(target_x - position.x) < 0.01:
				position.x = target_x
				_set_mode(Mode.READY)
		Mode.SWING:
			# Keep running to the ball until it's time to rise, then jump.
			var dx2: float = target_x - position.x
			var step2: float = minf(absf(dx2), speed * delta)
			position.x += signf(dx2) * step2
			_stride += step2
			_swing_in -= delta
			if _swing_in <= RISE_SECONDS and _y <= 0.0 and _vy <= 0.0 and mode_time > 0.0 and _swing_in > -0.5:
				_vy = _gravity * minf(RISE_SECONDS, maxf(_swing_in, 0.05))
			if step2 > 0.0005 and _y <= 0.0:
				state = {"speed": speed, "distance": _stride}
			if _swing_in < -0.6 and _y <= 0.0:
				_set_mode(Mode.READY)
		Mode.DIVE:
			var k: float = clampf(mode_time / DIVE_SECONDS.x, 0.0, 1.0)
			position.x += _dive_dir * speed * 0.6 * delta * (1.0 - k)
			if mode_time > DIVE_SECONDS.x + DIVE_SECONDS.y + DIVE_SECONDS.z:
				_set_mode(Mode.READY)
		Mode.CHEER:
			if mode_time < 0.05 and _y <= 0.0:
				_vy = _gravity * RISE_SECONDS * 0.8
	# The jump.
	if _vy > 0.0 or _y > 0.0:
		_vy -= _gravity * delta
		_y += _vy * delta
		if _y <= 0.0:
			_y = 0.0
			_vy = 0.0
			state["just_landed"] = true
		else:
			state["grounded"] = false
			state["vh"] = _vy * 2.0
	rig.position.y = _y
	# Facing: across the court while running, at the net otherwise.
	var run_dir: float = signf(target_x - position.x)
	var want: float = PI
	if (mode == Mode.RUN or (mode == Mode.SWING and _y <= 0.0)) and absf(target_x - position.x) > 0.25:
		want = PI + run_dir * PI * 0.5 * 0.85
	_yaw = lerp_angle(_yaw, want, 1.0 - exp(-14.0 * delta))
	rig.rotation.y = _yaw
	rig.animate(state, delta)
	_pose_arms()
	_pose_body()


func _set_mode(m: Mode) -> void:
	if m == mode and m != Mode.SWING:
		return
	mode = m
	mode_time = 0.0


## The arms (and head) over the rig's pose, for what he's doing with them. Limb rotations in HumanoidPose's limb
## convention: +x swings the arm forward (and up, past 90°) and bends the elbow, +z out to the side.
func _pose_arms() -> void:
	match mode:
		Mode.READY:
			# Ready: forearms up in front, elbows bent, bouncing a little on his toes.
			var bob: float = sin(mode_time * TAU * 1.6)
			_arm(1, Vector3(30.0, 0.0, 14.0), Vector3(70.0, 0.0, 0.0))
			_arm(-1, Vector3(30.0, 0.0, 14.0), Vector3(70.0, 0.0, 0.0))
			rig.position.y += 0.012 * maxf(bob, 0.0)
		Mode.SWING:
			var t: float = _swing_in
			if _serving and t > RISE_SECONDS:
				# The toss: the left arm lifts the ball high, the right arm cocks back.
				var u: float = clampf(1.0 - (t - RISE_SECONDS) / 0.5, 0.0, 1.0)
				_arm(-1, Vector3(lerpf(40.0, 165.0, u), 0.0, 10.0), Vector3(10.0, 0.0, 0.0))
				_arm(1, Vector3(lerpf(20.0, 150.0, u), 0.0, 35.0), Vector3(lerpf(20.0, 110.0, u), 0.0, 0.0))
			elif t > 0.0:
				# Rising: the hitting arm cocked high behind the head, the other reaching up at the ball.
				var u2: float = clampf(1.0 - t / RISE_SECONDS, 0.0, 1.0)
				_arm(1, Vector3(lerpf(150.0, 175.0, u2), 0.0, 30.0), Vector3(lerpf(110.0, 60.0, u2), 0.0, 0.0))
				_arm(-1, Vector3(lerpf(120.0, 150.0, u2), 0.0, 15.0), Vector3(15.0, 0.0, 0.0))
			else:
				# The hit and the follow-through: the arm whips down and forward.
				var u3: float = clampf(-t / 0.3, 0.0, 1.0)
				_arm(1, Vector3(lerpf(175.0, 60.0, u3), 0.0, lerpf(30.0, 10.0, u3)), Vector3(10.0, 0.0, 0.0))
				_arm(-1, Vector3(lerpf(150.0, 40.0, u3), 0.0, 15.0), Vector3(25.0, 0.0, 0.0))
		Mode.DIVE:
			# Both arms flung out toward the ball.
			_arm(1, Vector3(150.0, 0.0, 40.0 if _dive_dir > 0.0 else 0.0), Vector3(5.0, 0.0, 0.0))
			_arm(-1, Vector3(150.0, 0.0, 40.0 if _dive_dir < 0.0 else 0.0), Vector3(5.0, 0.0, 0.0))
		Mode.CHEER:
			# A fist pump with both arms.
			var pump: float = 0.5 + 0.5 * sin(mode_time * TAU * 2.5)
			_arm(1, Vector3(160.0, 0.0, lerpf(15.0, 35.0, pump)), Vector3(lerpf(20.0, 70.0, pump), 0.0, 0.0))
			_arm(-1, Vector3(160.0, 0.0, lerpf(15.0, 35.0, pump)), Vector3(lerpf(20.0, 70.0, pump), 0.0, 0.0))
		Mode.SULK:
			# Hands on his head, looking down at the sand.
			_arm(1, Vector3(150.0, 0.0, 55.0), Vector3(140.0, 0.0, 0.0))
			_arm(-1, Vector3(150.0, 0.0, 55.0), Vector3(140.0, 0.0, 0.0))
			var head: Node3D = rig.joint(&"head")
			head.rotation.x -= deg_to_rad(28.0) * clampf(mode_time / 0.3, 0.0, 1.0)
		Mode.WAVE:
			var w: float = sin(mode_time * TAU * 2.0)
			_arm(1, Vector3(150.0, 0.0, 40.0), Vector3(30.0, 0.0, 25.0 * w))
			_arm(-1, Vector3(10.0, 0.0, 10.0), Vector3(20.0, 0.0, 0.0))


## A dive leans his whole body over toward the ball and down to the sand, and back up.
func _pose_body() -> void:
	var roll: float = 0.0
	var drop: float = 0.0
	if mode == Mode.DIVE:
		var t: float = mode_time
		var k: float
		if t < DIVE_SECONDS.x:
			k = t / DIVE_SECONDS.x
		elif t < DIVE_SECONDS.x + DIVE_SECONDS.y:
			k = 1.0
		else:
			k = clampf(1.0 - (t - DIVE_SECONDS.x - DIVE_SECONDS.y) / DIVE_SECONDS.z, 0.0, 1.0)
		k = k * k * (3.0 - 2.0 * k)
		# He faces +z (yaw PI), so a dive to world +x is a roll to his left.
		roll = _dive_dir * deg_to_rad(68.0) * k
		drop = 0.25 * k * _scale
	_turned = lerpf(_turned, roll, 0.5)
	rig.rotation.z = _turned
	rig.position.y -= drop


## Poses one arm: the upper arm and the forearm, in degrees (limb convention), the hand following the forearm.
func _arm(side: int, upper: Vector3, fore: Vector3) -> void:
	var pre: String = "_l" if side < 0 else "_r"
	rig.joint(StringName("upper_arm" + pre)).rotation = _limb(side, upper)
	rig.joint(StringName("forearm" + pre)).rotation = _limb(side, fore)


static func _limb(side: int, degrees: Vector3) -> Vector3:
	var d: Vector3 = degrees if side > 0 else Vector3(degrees.x, -degrees.y, -degrees.z)
	return d * (PI / 180.0)
