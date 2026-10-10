class_name CinePoses
extends RefCounted
## The runner's poses for cinematics that play itself never needs, on the shared humanoid rig: lying on its
## back (`lie`), getting up from there to standing with its arms reaching up (`get_up`), and climbing out
## over an edge (`climb`, its hands holding on to the key's position until it gets a foot under it). They
## play out over a progress (CineActorKey.progress, 0-1) instead of following movement: each is a few key
## poses (tables in HumanoidPose's conventions, degrees; "root_rot" tips the whole body) blended smoothly
## by it, so stepping the clock any way gives the same pose; moved along meanwhile, its legs step
## (add_steps). CineActorNode poses the runner's rig with them (HumanoidRig.apply_pose, put on the ground)
## in place of PlayerAvatar's own animation.
## DESIGN-TBD (docs/questions/f2c.md): the key poses are hand-set placeholders.

const POSES: Array[StringName] = [&"lie", &"get_up", &"climb"]
## The climb: the hands hold on to the key's position until this far through it, then let go as a
## foot takes the weight, by this far.
const LET_GO := Vector2(0.8, 0.95)
## Moving along faster than STEP_SPEED.x (m/s) the legs start to step, fully by STEP_SPEED.y (add_steps).
const STEP_SPEED := Vector2(0.25, 0.7)
const LEGS: Array[int] = [HumanoidPose.THIGH_L, HumanoidPose.SHIN_L, HumanoidPose.FOOT_L, HumanoidPose.THIGH_R,
	HumanoidPose.SHIN_R, HumanoidPose.FOOT_R]
## Lying winded: the chest rises and falls this much (degrees), this often (Hz).
const PANT: float = 2.5
const PANT_RATE: float = 0.55

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

## On its back, out cold: the head lolled to one side, one arm flung out, one knee fallen open.
const LIE := {
	"root_rot": Vector3(88, 0, -4),
	CHEST: Vector3(3, -6, 0), NECK: Vector3(-4, 0, 0), HEAD: Vector3(-6, 38, 0),
	UPPER_ARM_R: Vector3(-4, 0, 70), FOREARM_R: Vector3(12, 0, 0), HAND_R: Vector3(-10, 0, 0),
	UPPER_ARM_L: Vector3(0, 0, 24), FOREARM_L: Vector3(14, 0, 0),
	THIGH_R: Vector3(2, 0, 12), SHIN_R: Vector3(-4, 0, 0), FOOT_R: Vector3(-25, 0, 0),
	THIGH_L: Vector3(26, 0, 30), SHIN_L: Vector3(-50, 0, 0), FOOT_L: Vector3(10, 0, 0),
}

## Coming to: the head lifts off the ground, the arms draw in.
const STIR := {
	"root_rot": Vector3(84, 0, -2),
	CHEST: Vector3(-6, 0, 0), NECK: Vector3(-24, 0, 0), HEAD: Vector3(-10, 6, 0),
	UPPER_ARM_R: Vector3(-10, 0, 36), FOREARM_R: Vector3(30, 0, 0),
	UPPER_ARM_L: Vector3(-10, 0, 28), FOREARM_L: Vector3(30, 0, 0),
	THIGH_R: Vector3(6, 0, 10), SHIN_R: Vector3(-10, 0, 0), FOOT_R: Vector3(-20, 0, 0),
	THIGH_L: Vector3(40, 0, 18), SHIN_L: Vector3(-70, 0, 0), FOOT_L: Vector3(14, 0, 0),
}

## Propped up on its elbows.
const PROPPED := {
	"root_rot": Vector3(55, 0, 0),
	CHEST: Vector3(-10, 0, 0), NECK: Vector3(-14, 0, 0), HEAD: Vector3(-6, 0, 0),
	UPPER_ARM_R: Vector3(-55, 0, 14), FOREARM_R: Vector3(80, 0, 0),
	UPPER_ARM_L: Vector3(-55, 0, 14), FOREARM_L: Vector3(80, 0, 0),
	THIGH_R: Vector3(34, 0, 8), SHIN_R: Vector3(-14, 0, 0), FOOT_R: Vector3(-10, 0, 0),
	THIGH_L: Vector3(58, 0, 12), SHIN_L: Vector3(-80, 0, 0), FOOT_L: Vector3(20, 0, 0),
}

## Sitting up, hunched over its knees, dazed, its hands on the ground behind it.
const SIT := {
	"root_rot": Vector3(18, 0, 0),
	CHEST: Vector3(-18, 0, 0), NECK: Vector3(-6, 0, 0), HEAD: Vector3(-14, 0, 0),
	UPPER_ARM_R: Vector3(-40, 0, 22), FOREARM_R: Vector3(8, 0, 0),
	UPPER_ARM_L: Vector3(-40, 0, 22), FOREARM_L: Vector3(8, 0, 0),
	THIGH_R: Vector3(72, 0, 8), SHIN_R: Vector3(-70, 0, 0), FOOT_R: Vector3(10, 0, 0),
	THIGH_L: Vector3(60, 0, 12), SHIN_L: Vector3(-40, 0, 0), FOOT_L: Vector3(0, 0, 0),
}

## On one knee, a hand on the other.
const KNEEL := {
	CHEST: Vector3(-22, 0, 0), NECK: Vector3(0, 0, 0), HEAD: Vector3(-6, 0, 0),
	UPPER_ARM_R: Vector3(48, 0, 8), FOREARM_R: Vector3(30, 0, 0),
	UPPER_ARM_L: Vector3(20, 0, 10), FOREARM_L: Vector3(10, 0, 0),
	THIGH_R: Vector3(85, 0, 6), SHIN_R: Vector3(-95, 0, 0), FOOT_R: Vector3(10, 0, 0),
	THIGH_L: Vector3(-15, 0, 6), SHIN_L: Vector3(-95, 0, 0), FOOT_L: Vector3(-40, 0, 0),
}

## On its feet, looking up.
const STAND := {
	CHEST: Vector3(-8, 0, 0), NECK: Vector3(6, 0, 0), HEAD: Vector3(10, 0, 0),
	UPPER_ARM_R: Vector3(6, 6, 10), FOREARM_R: Vector3(18, 0, 0),
	UPPER_ARM_L: Vector3(6, 6, 10), FOREARM_L: Vector3(18, 0, 0),
	THIGH_R: Vector3(12, 0, 4), SHIN_R: Vector3(-22, 0, 0), FOOT_R: Vector3(10, 0, 0),
	THIGH_L: Vector3(12, 0, 4), SHIN_L: Vector3(-22, 0, 0), FOOT_L: Vector3(10, 0, 0),
}

## Reaching up for the edge above it, crouching to spring.
const REACH := {
	CHEST: Vector3(6, 0, 0), NECK: Vector3(8, 0, 0), HEAD: Vector3(14, 0, 0),
	UPPER_ARM_R: Vector3(160, 0, 16), FOREARM_R: Vector3(12, 0, 0),
	UPPER_ARM_L: Vector3(160, 0, 16), FOREARM_L: Vector3(12, 0, 0),
	THIGH_R: Vector3(22, 0, 4), SHIN_R: Vector3(-42, 0, 0), FOOT_R: Vector3(18, 0, 0),
	THIGH_L: Vector3(22, 0, 4), SHIN_L: Vector3(-42, 0, 0), FOOT_L: Vector3(18, 0, 0),
}

## Hanging from the edge by its hands, looking up over it.
const HANG := {
	"root_rot": Vector3(-4, 0, 0),
	CHEST: Vector3(4, 0, 0), NECK: Vector3(10, 0, 0), HEAD: Vector3(12, 0, 0),
	UPPER_ARM_R: Vector3(158, 0, 18), FOREARM_R: Vector3(8, 0, 0),
	UPPER_ARM_L: Vector3(158, 0, 18), FOREARM_L: Vector3(8, 0, 0),
	THIGH_R: Vector3(4, 0, 4), SHIN_R: Vector3(-10, 0, 0), FOOT_R: Vector3(-20, 0, 0),
	THIGH_L: Vector3(4, 0, 4), SHIN_L: Vector3(-10, 0, 0), FOOT_L: Vector3(-20, 0, 0),
}

## Pulling itself up, elbows out, a knee against the wall.
const PULL := {
	CHEST: Vector3(-6, 0, 0), NECK: Vector3(8, 0, 0), HEAD: Vector3(12, 0, 0),
	UPPER_ARM_R: Vector3(36, 0, 35), FOREARM_R: Vector3(145, 0, 0),
	UPPER_ARM_L: Vector3(36, 0, 35), FOREARM_L: Vector3(145, 0, 0),
	THIGH_R: Vector3(40, 0, 6), SHIN_R: Vector3(-90, 0, 0), FOOT_R: Vector3(0, 0, 0),
	THIGH_L: Vector3(5, 0, 4), SHIN_L: Vector3(-20, 0, 0), FOOT_L: Vector3(-20, 0, 0),
}

## Over the edge: elbows up behind it, its chest out over its hands, its weight onto them.
const MANTLE := {
	"root_rot": Vector3(-35, 0, 0),
	CHEST: Vector3(-25, 0, 0), NECK: Vector3(25, 0, 0), HEAD: Vector3(30, 0, 0),
	UPPER_ARM_R: Vector3(-40, 0, 24), FOREARM_R: Vector3(100, 0, 0),
	UPPER_ARM_L: Vector3(-40, 0, 24), FOREARM_L: Vector3(100, 0, 0),
	THIGH_R: Vector3(45, 0, 6), SHIN_R: Vector3(-90, 0, 0), FOOT_R: Vector3(0, 0, 0),
	THIGH_L: Vector3(30, 0, 4), SHIN_L: Vector3(-40, 0, 0), FOOT_L: Vector3(-20, 0, 0),
}

## Pressing up on straight arms, a knee coming up onto the edge.
const PRESS := {
	"root_rot": Vector3(-25, 0, 0),
	CHEST: Vector3(-20, 0, 0), NECK: Vector3(20, 0, 0), HEAD: Vector3(22, 0, 0),
	UPPER_ARM_R: Vector3(35, 0, 12), FOREARM_R: Vector3(5, 0, 0),
	UPPER_ARM_L: Vector3(35, 0, 12), FOREARM_L: Vector3(5, 0, 0),
	THIGH_R: Vector3(102, 0, 6), SHIN_R: Vector3(-150, 0, 0), FOOT_R: Vector3(20, 0, 0),
	THIGH_L: Vector3(15, 0, 4), SHIN_L: Vector3(-30, 0, 0), FOOT_L: Vector3(-20, 0, 0),
}

## A knee up on the edge, its hands still on the ground.
const KNEE_UP := {
	"root_rot": Vector3(-30, 0, 0),
	CHEST: Vector3(-20, 0, 0), NECK: Vector3(22, 0, 0), HEAD: Vector3(26, 0, 0),
	UPPER_ARM_R: Vector3(25, 0, 10), FOREARM_R: Vector3(4, 0, 0),
	UPPER_ARM_L: Vector3(25, 0, 10), FOREARM_L: Vector3(4, 0, 0),
	THIGH_R: Vector3(103, 0, 6), SHIN_R: Vector3(-150, 0, 0), FOOT_R: Vector3(30, 0, 0),
	THIGH_L: Vector3(10, 0, 4), SHIN_L: Vector3(-60, 0, 0), FOOT_L: Vector3(-20, 0, 0),
}

## Getting a foot under it and rising, its hands leaving the ground.
const RISE := {
	"root_rot": Vector3(-10, 0, 0),
	CHEST: Vector3(-15, 0, 0), NECK: Vector3(10, 0, 0), HEAD: Vector3(12, 0, 0),
	UPPER_ARM_R: Vector3(55, 0, 14), FOREARM_R: Vector3(30, 0, 0),
	UPPER_ARM_L: Vector3(55, 0, 14), FOREARM_L: Vector3(30, 0, 0),
	THIGH_R: Vector3(90, 0, 6), SHIN_R: Vector3(-110, 0, 0), FOOT_R: Vector3(20, 0, 0),
	THIGH_L: Vector3(0, 0, 4), SHIN_L: Vector3(-90, 0, 0), FOOT_L: Vector3(-40, 0, 0),
}

## Up, in a wary half-crouch.
const UP := {
	CHEST: Vector3(-6, 0, 0), NECK: Vector3(4, 0, 0), HEAD: Vector3(4, 0, 0),
	UPPER_ARM_R: Vector3(8, 6, 12), FOREARM_R: Vector3(22, 0, 0),
	UPPER_ARM_L: Vector3(8, 6, 12), FOREARM_L: Vector3(22, 0, 0),
	THIGH_R: Vector3(10, 0, 5), SHIN_R: Vector3(-18, 0, 0), FOOT_R: Vector3(8, 0, 0),
	THIGH_L: Vector3(10, 0, 5), SHIN_L: Vector3(-18, 0, 0), FOOT_L: Vector3(8, 0, 0),
}

## Each pose's key poses: [progress, table], in order.
const LIE_KEYS: Array = [[0.0, LIE]]
const GET_UP_KEYS: Array = [[0.0, LIE], [0.2, STIR], [0.38, PROPPED], [0.55, SIT], [0.75, KNEEL], [0.9, STAND],
	[1.0, REACH]]
const CLIMB_KEYS: Array = [[0.0, HANG], [0.35, PULL], [0.52, MANTLE], [0.66, PRESS], [0.8, KNEE_UP], [0.9, RISE],
	[1.0, UP]]


## Stepping legs over a pose that plays out over time, while the actor moves along (`weight` 0-1): the run
## cycle's legs at `speed` (m/s; a walk's short stride when slow, HumanoidPoses.run) at leg phase `phase`,
## worked out in `scratch`, so a runner getting up can stagger forward as it rises.
static func add_steps(p: HumanoidPose, scratch: HumanoidPose, phase: float, speed: float, t: HumanoidAnimTuning,
		weight: float) -> void:
	if weight <= 0.0:
		return
	HumanoidPoses.run(scratch, phase, clampf(speed / t.full_stride_speed, 0.0, 1.0), t)
	for joint: int in LEGS:
		p.rot[joint] = p.rot[joint].lerp(scratch.rot[joint], weight)


## The leg phase advanced by `moved` metres at `speed` (m/s), as the rig's stride does (HumanoidRig.animate).
static func step_phase(phase: float, moved: float, speed: float, t: HumanoidAnimTuning) -> float:
	var amount: float = clampf(speed / t.full_stride_speed, 0.0, 1.0)
	var stride: float = maxf(t.stride_length * maxf(amount, 0.2), speed / t.max_cadence)
	return fposmod(phase + moved / maxf(stride, 0.01), 1.0)


static func is_cine_pose(pose_name: StringName) -> bool:
	return POSES.has(pose_name)


## Fills `p` with the runner's `pose_name` at `progress` (0-1); `time` is the cinematic's, for its breath.
## The body tips about its hips (`pelvis_height`, the rig's HumanoidParts.pelvis_height()), so they stay
## over the key's position as it lies down or sits up; the rig then puts it on the ground.
static func runner(p: HumanoidPose, pose_name: StringName, progress: float, time: float, pelvis_height: float) -> void:
	p.reset()
	var keys: Array = LIE_KEYS
	match pose_name:
		&"get_up":
			keys = GET_UP_KEYS
		&"climb":
			keys = CLIMB_KEYS
	_blend(p, keys, clampf(progress, 0.0, 1.0))
	# Winded: lying, it pants (fading as it gets up).
	var lying: float = 1.0 if pose_name == &"lie" else (1.0 - smoothstep(0.1, 0.4, progress) if pose_name == &"get_up" else 0.0)
	if lying > 0.0:
		p.add_deg(CHEST, Vector3(PANT * lying * sin(TAU * PANT_RATE * time), 0.0, 0.0))
	p.root_offset.z -= pelvis_height * sin(p.root_rot.x)


## How firmly the hands hold on to the key's position (1: the body hangs from them; 0: it stands on its
## feet), for `pose_name` at `progress`.
static func hand_hold(pose_name: StringName, progress: float) -> float:
	if pose_name != &"climb":
		return 0.0
	return 1.0 - smoothstep(LET_GO.x, LET_GO.y, progress)


## Blends the two key poses either side of `progress`, easing from one to the next.
static func _blend(p: HumanoidPose, keys: Array, progress: float) -> void:
	var next: int = keys.size() - 1
	for i: int in keys.size():
		if float(keys[i][0]) >= progress:
			next = i
			break
	if next == 0 or float(keys[next][0]) <= progress:
		p.add_table(keys[next][1], 1.0)
		return
	var a: Array = keys[next - 1]
	var b: Array = keys[next]
	var u: float = smoothstep(float(a[0]), float(b[0]), progress)
	p.add_table(a[1], 1.0 - u)
	p.add_table(b[1], u)
