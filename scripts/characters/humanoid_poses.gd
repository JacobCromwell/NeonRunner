class_name HumanoidPoses
extends RefCounted
## The procedural poses of HumanoidRig: one function per activity, each filling a HumanoidPose from
## a phase or a time plus the tuning (HumanoidAnimTuning). HumanoidRig blends them and then puts the
## body on the ground, so no pose has to place the feet itself.
##
## Static poses are tables of joint angles in degrees, in the limb convention of HumanoidPose
## (+x swings forward, +z out to the side, +y turns inward; centre joints: +x tilts back, +y turns
## left, +z tilts left). Asymmetric tables are authored with the right side leading.

const PELVIS: int = HumanoidPose.PELVIS
const CHEST: int = HumanoidPose.CHEST
const NECK: int = HumanoidPose.NECK
const HEAD: int = HumanoidPose.HEAD
const UPPER_ARM_L: int = HumanoidPose.UPPER_ARM_L
const FOREARM_L: int = HumanoidPose.FOREARM_L
const HAND_L: int = HumanoidPose.HAND_L
const UPPER_ARM_R: int = HumanoidPose.UPPER_ARM_R
const FOREARM_R: int = HumanoidPose.FOREARM_R
const HAND_R: int = HumanoidPose.HAND_R
const THIGH_L: int = HumanoidPose.THIGH_L
const SHIN_L: int = HumanoidPose.SHIN_L
const FOOT_L: int = HumanoidPose.FOOT_L
const THIGH_R: int = HumanoidPose.THIGH_R
const SHIN_R: int = HumanoidPose.SHIN_R
const FOOT_R: int = HumanoidPose.FOOT_R
const DEG: float = HumanoidPose.DEG

## Run gait keys for one leg over its cycle (phase 0–1): knee drive, reach, contact, mid-stance,
## toe-off, heel kick, swing-through. The shape of the stride; its size comes from the tuning.
const GAIT_PHASE := [0.12, 0.28, 0.40, 0.52, 0.64, 0.76, 0.92]
## Thigh as a fraction of thigh_swing around thigh_forward_bias (+ = forward).
const GAIT_THIGH := [0.95, 0.65, 0.4, -0.1, -0.75, -0.9, -0.05]
## Knee bend as fractions of knee_stance (loaded, foot planted) and knee_lift (swinging through).
const GAIT_KNEE_STANCE := [0.0, 0.66, 0.47, 1.0, 0.58, 0.0, 0.0]
const GAIT_KNEE_LIFT := [0.65, 0.0, 0.0, 0.0, 0.0, 0.83, 1.0]
## Foot angle in degrees (+ = toe up): relative to the shin while swinging, to the ground while planted.
const GAIT_FOOT := [-5.0, 5.0, 8.0, 0.0, -22.0, -30.0, -25.0]
const GAIT_CONTACT: float = 0.40
const GAIT_MID_STANCE: float = 0.52
const GAIT_TOE_OFF: float = 0.64

const IDLE := {
	CHEST: Vector3(1, 0, 0), HEAD: Vector3(-3, 0, 0),
	UPPER_ARM_L: Vector3(4, 6, 9), FOREARM_L: Vector3(16, 0, 0), HAND_L: Vector3(-4, 0, 0),
	UPPER_ARM_R: Vector3(4, 6, 9), FOREARM_R: Vector3(16, 0, 0), HAND_R: Vector3(-4, 0, 0),
	THIGH_L: Vector3(2, 3, 4), SHIN_L: Vector3(-5, 0, 0), FOOT_L: Vector3(3, 0, -4),
	THIGH_R: Vector3(2, 3, 4), SHIN_R: Vector3(-5, 0, 0), FOOT_R: Vector3(3, 0, -4),
}

## Jump, rising: the right knee drives up, the left leg trails, arms swing against the legs.
const RISE := {
	PELVIS: Vector3(-6, 8, 0), CHEST: Vector3(-12, -14, 0), NECK: Vector3(6, 3, 0), HEAD: Vector3(10, 3, 0),
	THIGH_R: Vector3(78, 0, 3), SHIN_R: Vector3(-95, 0, 0), FOOT_R: Vector3(-12, 0, 0),
	THIGH_L: Vector3(-28, 0, 5), SHIN_L: Vector3(-55, 0, 0), FOOT_L: Vector3(-38, 0, 0),
	UPPER_ARM_R: Vector3(-45, 10, 18), FOREARM_R: Vector3(55, 0, 0),
	UPPER_ARM_L: Vector3(75, 12, 14), FOREARM_L: Vector3(65, 0, 0),
}

## Jump, apex: knees tucked up, body curled.
const TUCK := {
	PELVIS: Vector3(-8, 0, 0), CHEST: Vector3(-16, 0, 0), NECK: Vector3(5, 0, 0), HEAD: Vector3(14, 0, 0),
	THIGH_R: Vector3(88, 0, 8), SHIN_R: Vector3(-118, 0, 0), FOOT_R: Vector3(-18, 0, 0),
	THIGH_L: Vector3(70, 0, 8), SHIN_L: Vector3(-122, 0, 0), FOOT_L: Vector3(-22, 0, 0),
	UPPER_ARM_R: Vector3(30, 10, 28), FOREARM_R: Vector3(72, 0, 0),
	UPPER_ARM_L: Vector3(40, 10, 28), FOREARM_L: Vector3(72, 0, 0),
}

## Jump, falling: legs reach down for the landing, arms out for balance.
const FALL := {
	PELVIS: Vector3(-2, 0, 0), CHEST: Vector3(-3, 0, 0), NECK: Vector3(-3, 0, 0), HEAD: Vector3(-6, 0, 0),
	THIGH_R: Vector3(30, 0, 6), SHIN_R: Vector3(-42, 0, 0), FOOT_R: Vector3(6, 0, 0),
	THIGH_L: Vector3(10, 0, 8), SHIN_L: Vector3(-30, 0, 0), FOOT_L: Vector3(-4, 0, 0),
	UPPER_ARM_R: Vector3(18, 0, 58), FOREARM_R: Vector3(32, 0, 0),
	UPPER_ARM_L: Vector3(6, 0, 52), FOREARM_L: Vector3(30, 0, 0),
}

## Slide, feet first: both legs forward along the ground (the left one splayed and a little bent),
## the left hand trailing on the ground, the right arm forward for balance. The lean back comes from
## the tuning; the body rests on the hips and heels, well under a gapped fence.
const SLIDE := {
	CHEST: Vector3(-4, 0, 0), NECK: Vector3(-8, 0, 0),
	THIGH_R: Vector3(22, 0, 4), SHIN_R: Vector3(-4, 0, 0), FOOT_R: Vector3(16, 0, 0),
	THIGH_L: Vector3(24, 0, 16), SHIN_L: Vector3(-8, 0, 0), FOOT_L: Vector3(10, 0, 0),
	UPPER_ARM_L: Vector3(-125, 0, 16), FOREARM_L: Vector3(25, 0, 0), HAND_L: Vector3(20, 0, 0),
	UPPER_ARM_R: Vector3(40, 14, 18), FOREARM_R: Vector3(20, 0, 0),
}

## Juggernaut dash, upper body: a shoulder charge with the right shoulder leading, the right
## forearm across the chest like a ram, the left arm driving back.
const DASH_UPPER := {
	CHEST: Vector3(0, 26, 0), NECK: Vector3(8, -12, 0), HEAD: Vector3(16, -12, 0),
	UPPER_ARM_R: Vector3(58, 28, 14), FOREARM_R: Vector3(112, 0, 0),
	UPPER_ARM_L: Vector3(-48, 0, 22), FOREARM_L: Vector3(72, 0, 0),
}

## Stomp (a slam down onto whatever is below): legs together and braced, fists raised overhead.
const STOMP := {
	CHEST: Vector3(-10, 0, 0), NECK: Vector3(-6, 0, 0), HEAD: Vector3(-18, 0, 0),
	THIGH_R: Vector3(16, 0, 3), SHIN_R: Vector3(-26, 0, 0), FOOT_R: Vector3(-10, 0, 0),
	THIGH_L: Vector3(10, 0, 3), SHIN_L: Vector3(-18, 0, 0), FOOT_L: Vector3(-6, 0, 0),
	UPPER_ARM_R: Vector3(160, 0, 28), FOREARM_R: Vector3(40, 0, 0),
	UPPER_ARM_L: Vector3(160, 0, 28), FOREARM_L: Vector3(40, 0, 0),
}

## Death, first beat: knees buckle, the body slumps.
const DEAD_SLUMP := {
	PELVIS: Vector3(-8, 0, 0), CHEST: Vector3(-30, 0, 6), NECK: Vector3(-12, 0, 0), HEAD: Vector3(-18, 8, 6),
	UPPER_ARM_R: Vector3(8, 0, 14), FOREARM_R: Vector3(20, 0, 0),
	UPPER_ARM_L: Vector3(8, 0, 14), FOREARM_L: Vector3(20, 0, 0),
	THIGH_R: Vector3(40, 0, 8), SHIN_R: Vector3(-75, 0, 0), FOOT_R: Vector3(-5, 0, 0),
	THIGH_L: Vector3(30, 0, 6), SHIN_L: Vector3(-65, 0, 0),
}

## Death, on the ground (the body is also tipped forward by dead()): face down, limbs loose.
const DEAD_DOWN := {
	CHEST: Vector3(-4, 0, 8), NECK: Vector3(10, 0, 0), HEAD: Vector3(22, 38, 0),
	UPPER_ARM_R: Vector3(35, 0, 40), FOREARM_R: Vector3(25, 0, 0),
	UPPER_ARM_L: Vector3(20, 0, 30), FOREARM_L: Vector3(40, 0, 0),
	THIGH_R: Vector3(4, 0, 10), SHIN_R: Vector3(-12, 0, 0), FOOT_R: Vector3(-45, 0, 0),
	THIGH_L: Vector3(8, 0, 6), SHIN_L: Vector3(-28, 0, 0), FOOT_L: Vector3(-40, 0, 0),
}


static func idle(p: HumanoidPose, time: float, t: HumanoidAnimTuning) -> void:
	p.reset()
	p.add_table(IDLE, 1.0)
	var breath: float = sin(TAU * t.breathe_rate * time)
	p.add_deg(CHEST, Vector3(t.breathe_amount * breath * 0.6, 0.0, 0.0))
	p.add_deg(HEAD, Vector3(-t.breathe_amount * breath * 0.4, 6.0 * sin(TAU * 0.07 * time), 0.0))
	p.add_deg(PELVIS, Vector3(0.0, 0.0, 1.2 * sin(TAU * 0.13 * time)))
	for side: int in [-1, 1]:
		p.add_limb(UPPER_ARM_R, side, Vector3(0.0, 0.0, t.breathe_amount * 0.5 * breath))


## The run cycle. `phase` 0–1 is the leg cycle driven by the distance run (the left leg uses it as
## is, the right leg half a cycle later); `amount` 0–1 scales the stride from standing to a full run.
## The legs follow the GAIT keyframes. While a foot is planted it stays flat and the knee flexes, so
## the hips keep an even height through the stance (as a real runner's do) and the rig's grounding
## gives a small, smooth bob instead of a bounce.
static func run(p: HumanoidPose, phase: float, amount: float, t: HumanoidAnimTuning, stride_scale: float = 1.0) -> void:
	p.reset()
	var a: float = amount
	var pelvis_pitch: float = -t.forward_lean * 0.3 * a
	for side: int in [-1, 1]:
		var ph: float = fposmod(phase + (0.0 if side < 0 else 0.5), 1.0)
		var thigh: float = (t.thigh_forward_bias + t.thigh_swing * stride_scale * _gait(GAIT_THIGH, ph)) * a
		var knee: float = maxf(0.0, t.knee_stance * _gait(GAIT_KNEE_STANCE, ph) \
			+ t.knee_lift * stride_scale * _gait(GAIT_KNEE_LIFT, ph)) * a
		# A planted foot lies flat (compensating the shin's angle) plus the keyed heel-to-toe roll. A
		# swinging foot follows the keys in a full stride, and stays nearly level in a short one so its
		# toe never dips below the planted sole.
		var level: float = -(thigh + pelvis_pitch - knee)
		var foot: float = _gait(GAIT_FOOT, ph) * a * a + level * maxf(stance_weight(ph), 1.0 - a)
		p.set_limb(THIGH_R, side, Vector3(thigh, 0.0, 3.0 * a))
		p.set_limb(SHIN_R, side, Vector3(-knee, 0.0, 0.0))
		p.set_limb(FOOT_R, side, Vector3(foot, 0.0, -2.0 * a))
		# Each arm swings against the leg on its side (fully back while that knee drives forward);
		# the elbow closes as the arm comes forward.
		var s: float = sin(TAU * (ph - 0.51))
		var elbow: float = t.elbow_bend * (0.3 + 0.7 * a) + 14.0 * s * a
		p.set_limb(UPPER_ARM_R, side, Vector3(t.arm_swing * s * a + 4.0 * a, 14.0 * a, t.arm_out * (0.6 + 0.4 * a)))
		p.set_limb(FOREARM_R, side, Vector3(elbow, 0.0, 0.0))
		p.set_limb(HAND_R, side, Vector3(-6.0 * a, 0.0, 0.0))
	# The hips turn with the forward leg and the shoulders against them; the head stays level.
	var swing: float = _gait(GAIT_THIGH, phase) - _gait(GAIT_THIGH, fposmod(phase + 0.5, 1.0))
	var hip_yaw: float = -t.hip_twist * 0.5 * swing * a
	var chest_yaw: float = t.shoulder_twist * 0.5 * swing * a
	p.set_deg(PELVIS, Vector3(pelvis_pitch, hip_yaw, 1.5 * sin(TAU * (phase - 0.27)) * a))
	p.set_deg(CHEST, Vector3(-t.forward_lean * 0.7 * a, chest_yaw - hip_yaw, 0.0))
	p.set_deg(NECK, Vector3(t.forward_lean * 0.4 * a, -chest_yaw * 0.4, 0.0))
	p.set_deg(HEAD, Vector3(t.forward_lean * 0.5 * a, -chest_yaw * 0.4, 0.0))
	# Highest in the middle of each flight phase, lowest mid-stance.
	p.lift = t.bob_height * a * 0.5 * (1.0 - cos(2.0 * TAU * (phase - GAIT_MID_STANCE)))


## How planted a leg is at its cycle phase `ph`: 1 from contact to toe-off, easing in and out.
static func stance_weight(ph: float) -> float:
	var d: float = fposmod(ph - GAIT_CONTACT + 0.5, 1.0) - 0.5
	var span: float = GAIT_TOE_OFF - GAIT_CONTACT
	return smoothstep(-0.05, 0.02, d) * (1.0 - smoothstep(span - 0.02, span + 0.05, d))


## The leg that is further forward at this cycle phase: -1 left, 1 right (drives a jump).
static func leading_leg(phase: float) -> int:
	return -1 if _gait(GAIT_THIGH, phase) > _gait(GAIT_THIGH, fposmod(phase + 0.5, 1.0)) else 1


## A gait curve at leg phase `ph` (0–1): Catmull-Rom through the keys, wrapping round the cycle.
static func _gait(values: Array, ph: float) -> float:
	var n: int = GAIT_PHASE.size()
	var x: float = ph if ph >= GAIT_PHASE[0] else ph + 1.0
	var k: int = n - 1
	for i: int in n - 1:
		if x < GAIT_PHASE[i + 1]:
			k = i
			break
	var start: float = GAIT_PHASE[k]
	var end: float = GAIT_PHASE[k + 1] if k + 1 < n else GAIT_PHASE[0] + 1.0
	var u: float = (x - start) / (end - start)
	var p0: float = values[(k + n - 1) % n]
	var p1: float = values[k]
	var p2: float = values[(k + 1) % n]
	var p3: float = values[(k + 2) % n]
	var u2: float = u * u
	return 0.5 * (2.0 * p1 + (p2 - p0) * u + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * u2 \
		+ (3.0 * p1 - p0 - 3.0 * p2 + p3) * u2 * u)


## Running on a side wall. The Player rolls its pivot onto the wall, so in the rig's frame the wall
## is the ground and real gravity points along -wall_side × x. The body tilts away from the ground
## side, and the arm on the ground side reaches out for balance.
static func wall(p: HumanoidPose, phase: float, amount: float, t: HumanoidAnimTuning, wall_side: int) -> void:
	run(p, phase, amount, t)
	var side: int = wall_side if wall_side != 0 else 1
	p.root_rot.z += -side * t.wall_lean * DEG
	var low: int = -side
	p.set_limb(UPPER_ARM_R, low, Vector3(20.0 - 20.0 * sin(TAU * phase) * amount, 10.0, t.wall_arm_reach))
	p.set_limb(FOREARM_R, low, Vector3(30.0, 0.0, 0.0))
	p.add_deg(HEAD, Vector3(0.0, 0.0, side * t.wall_lean * 0.6))


## In the air. `rise` is the vertical speed over jump_pose_speed: +1 rising, 0 apex (tuck),
## -1 falling. `lead_side` is the leg that drives up (-1 left, 1 right).
static func air(p: HumanoidPose, rise: float, lead_side: int, t: HumanoidAnimTuning) -> void:
	p.reset()
	var r: float = clampf(rise, -1.0, 1.0)
	var mirrored: bool = lead_side < 0
	if r >= 0.0:
		p.add_table(TUCK, 1.0 - r, mirrored)
		p.add_table(RISE, r, mirrored)
	else:
		p.add_table(TUCK, 1.0 + r, mirrored)
		p.add_table(FALL, -r, mirrored)
	p.add_deg(CHEST, Vector3(-t.forward_lean * 0.3, 0.0, 0.0))


static func slide(p: HumanoidPose, t: HumanoidAnimTuning) -> void:
	p.reset()
	p.add_table(SLIDE, 1.0)
	p.set_deg(PELVIS, Vector3(t.slide_lean_back, 0.0, 0.0))
	# The visor looks down the track, chin tucked, whatever the lean.
	p.set_deg(HEAD, Vector3(-(t.slide_lean_back - 12.0) * 0.75, 0.0, 0.0))


## The juggernaut dash: a harder, longer run under a shoulder-charge upper body.
static func dash(p: HumanoidPose, phase: float, t: HumanoidAnimTuning) -> void:
	run(p, phase, 1.0, t, t.dash_stride_scale)
	for joint: int in [CHEST, NECK, HEAD, UPPER_ARM_L, FOREARM_L, HAND_L, UPPER_ARM_R, FOREARM_R, HAND_R]:
		p.rot[joint] = Vector3.ZERO
	p.add_table(DASH_UPPER, 1.0)
	p.add_deg(PELVIS, Vector3(-t.dash_lean * 0.3, 0.0, 0.0))
	p.add_deg(CHEST, Vector3(-t.dash_lean * 0.7, 0.0, 0.0))
	p.add_deg(HEAD, Vector3(t.dash_lean * 0.5, 0.0, 0.0))


static func stomp(p: HumanoidPose, _t: HumanoidAnimTuning) -> void:
	p.reset()
	p.add_table(STOMP, 1.0)


## Death: `progress` runs 0–1 over death_time; the body buckles, then tips forward onto the ground.
static func dead(p: HumanoidPose, progress: float, _t: HumanoidAnimTuning) -> void:
	p.reset()
	var u: float = clampf(progress, 0.0, 1.0)
	var down: float = smoothstep(0.15, 1.0, u)
	p.add_table(DEAD_SLUMP, 1.0 - down)
	p.add_table(DEAD_DOWN, down)
	var tip: float = clampf((u - 0.1) / 0.9, 0.0, 1.0)
	p.root_rot.x += -88.0 * DEG * tip * tip


## Additive landing absorption: `k` is 1 at touchdown and falls to 0.
static func add_landing(p: HumanoidPose, k: float, t: HumanoidAnimTuning) -> void:
	if k <= 0.0:
		return
	var s: float = t.land_squash * k
	p.root_scale *= Vector3(1.0 + s * 0.5, 1.0 - s, 1.0 + s * 0.5)
	for side: int in [-1, 1]:
		p.add_limb(THIGH_R, side, Vector3(t.land_crouch * 0.5 * k, 0.0, 0.0))
		p.add_limb(SHIN_R, side, Vector3(-t.land_crouch * k, 0.0, 0.0))
		p.add_limb(FOOT_R, side, Vector3(t.land_crouch * 0.4 * k, 0.0, 0.0))
		p.add_limb(UPPER_ARM_R, side, Vector3(0.0, 0.0, 12.0 * k))
	p.add_deg(CHEST, Vector3(-t.land_crouch * 0.3 * k, 0.0, 0.0))


## Additive lean into a lane switch: `lean` -1..1 is the (smoothed) direction along the rig's x.
static func add_lean(p: HumanoidPose, lean: float, t: HumanoidAnimTuning) -> void:
	if absf(lean) < 0.001:
		return
	p.root_rot.z += -lean * t.switch_lean * DEG
	p.add_deg(HEAD, Vector3(0.0, 0.0, lean * t.switch_lean * 0.5))
	# Push off with the outside leg, reach with the inside one.
	var outside: int = -1 if lean > 0.0 else 1
	p.add_limb(THIGH_R, outside, Vector3(0.0, 0.0, 10.0 * absf(lean)))
	p.add_limb(THIGH_R, -outside, Vector3(0.0, 0.0, -4.0 * absf(lean)))
