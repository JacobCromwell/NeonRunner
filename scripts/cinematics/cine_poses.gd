class_name CinePoses
extends RefCounted
## The runner's poses for cinematics that play itself never needs, on the shared humanoid rig: lying on its
## back (`lie`), getting up from there to standing with its arms reaching up (`get_up`), climbing out
## over an edge (`climb`, its hands holding on to the key's position until it gets a foot under it), and
## getting into a low car from beside its open door (`get_in`: the near leg over the sill, ducking in,
## sitting, the other leg in). They play out over a progress (CineActorKey.progress, 0-1) instead of
## following movement: each is a few key poses (tables in HumanoidPose's conventions, degrees; "root_rot"
## tips the whole body) blended smoothly by it, so stepping the clock any way gives the same pose; moved
## along meanwhile, its legs step (add_steps; not while getting in, whose legs are its key poses).
## And `walk`: a walk at walking pace, which play never needs either (the run cycle at a walk's speed takes
## short, quick, shuffling steps): heel strike, a bent knee through the swing, the foot rolling off its toe,
## the hips turning with the leg that swings and the shoulders against them, the arms swinging opposite
## the legs, the head steady. Its planted foot stays put: while it's down it goes back under the hip at
## exactly the body's pace (the thigh worked out from where the foot must be and the knee's bend, and turned back
## against the hips' turn and drop), and it swings forward to land moving at that pace too. The stride follows the ground covered (walk_phase), shorter when
## slow (walk_stride); turning on the spot it steps in place; slowing to a stop it settles into standing at
## ease, breathing, its weight shifting (walk at amount 0, the same stance `get_in` starts from, so one leads
## into the other). CineActorNode poses the runner's rig with them
## (HumanoidRig.apply_pose, put on the ground) in place of PlayerAvatar's own animation.
## DESIGN-TBD (docs/questions/f2c.md, f2d.md): the key poses are hand-set placeholders.

const POSES: Array[StringName] = [&"lie", &"get_up", &"climb", &"walk", &"get_in"]
## The walk: metres covered by one gait cycle in its full stride (two steps), the share of the cycle a foot is
## down (from its heel strike), the shortest stride (a share of the full one, walking slowly), and (degrees) the
## knee's bend as it takes the weight and through the swing, the arms' swing, the hips' turn and drop and the
## shoulders' turn against them, and the lean into it.
const WALK_CYCLE: float = 1.0
const STANCE: float = 0.62
const MIN_STRIDE: float = 0.45
const WALK_KNEE_LOAD: float = 12.0
const WALK_KNEE_SWING: float = 58.0
const WALK_ARM: float = 20.0
const WALK_HIP_TURN: float = 5.0
const WALK_HIP_DROP: float = 3.0
const WALK_SHOULDER_TURN: float = 8.0
const WALK_LEAN: float = 4.0
## Walking slower than WALK_SPEED.x (m/s) it stands; by WALK_SPEED.y it's in its full stride.
const WALK_SPEED := Vector2(0.05, 0.55)
## Turning on the spot, it steps as if it had walked this far for each radian it turns.
const TURN_STEP: float = 0.3
## Standing: its breath (degrees, Hz) and its weight shifting from foot to foot (degrees, Hz).
const BREATH: float = 1.4
const BREATH_RATE: float = 0.28
const SHIFT: float = 1.2
const SHIFT_RATE: float = 0.11
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

## Standing at ease: the walk at a standstill, and where getting in starts.
const AT_EASE := {
	CHEST: Vector3(0, 0, 0), NECK: Vector3(0, 0, 0), HEAD: Vector3(0, 0, 0),
	UPPER_ARM_R: Vector3(4, 0, 7), FOREARM_R: Vector3(14, 0, 0), HAND_R: Vector3(-4, 0, 0),
	UPPER_ARM_L: Vector3(4, 0, 7), FOREARM_L: Vector3(14, 0, 0), HAND_L: Vector3(-4, 0, 0),
	THIGH_R: Vector3(2, 0, 3), SHIN_R: Vector3(-4, 0, 0), FOOT_R: Vector3(2, 0, -3),
	THIGH_L: Vector3(2, 0, 3), SHIN_L: Vector3(-4, 0, 0), FOOT_L: Vector3(2, 0, -3),
}

## Getting in, the car on its right: the right leg lifted out over the sill, ducking, a hand reaching in.
const STEP_IN := {
	CHEST: Vector3(-16, -8, -10), NECK: Vector3(-8, 0, 0), HEAD: Vector3(-14, 6, 0),
	UPPER_ARM_R: Vector3(38, 0, 32), FOREARM_R: Vector3(28, 0, 0),
	UPPER_ARM_L: Vector3(18, 0, 18), FOREARM_L: Vector3(16, 0, 0),
	THIGH_R: Vector3(58, 0, 32), SHIN_R: Vector3(-72, 0, 0), FOOT_R: Vector3(12, 0, 0),
	THIGH_L: Vector3(8, 0, 3), SHIN_L: Vector3(-14, 0, 0), FOOT_L: Vector3(6, 0, 0),
}

## Its right foot in, crouching low under the door's edge, its weight going onto that leg.
const DUCK_IN := {
	CHEST: Vector3(-26, -6, -8), NECK: Vector3(-6, 0, 0), HEAD: Vector3(-18, 8, 0),
	UPPER_ARM_R: Vector3(30, 0, 20), FOREARM_R: Vector3(36, 0, 0),
	UPPER_ARM_L: Vector3(26, 0, 22), FOREARM_L: Vector3(24, 0, 0),
	THIGH_R: Vector3(66, 0, 18), SHIN_R: Vector3(-84, 0, 0), FOOT_R: Vector3(16, 0, 0),
	THIGH_L: Vector3(40, 0, 14), SHIN_L: Vector3(-66, 0, 0), FOOT_L: Vector3(20, 0, 0),
}

## Down onto the seat, the left leg still out of the door, coming in.
const SIT_DOWN := {
	CHEST: Vector3(6, 0, -4), NECK: Vector3(-4, 0, 0), HEAD: Vector3(-6, 10, 0),
	UPPER_ARM_R: Vector3(20, 0, 14), FOREARM_R: Vector3(30, 0, 0),
	UPPER_ARM_L: Vector3(30, 0, 24), FOREARM_L: Vector3(20, 0, 0),
	THIGH_R: Vector3(82, 0, 6), SHIN_R: Vector3(-40, 0, 0), FOOT_R: Vector3(10, 0, 0),
	THIGH_L: Vector3(72, 0, 26), SHIN_L: Vector3(-80, 0, 0), FOOT_L: Vector3(16, 0, 0),
}

## Sat low in the seat, leaning back, its legs out in front of it and its hands in its lap.
const SEATED := {
	CHEST: Vector3(24, 0, 0), NECK: Vector3(-10, 0, 0), HEAD: Vector3(-8, 0, 0),
	UPPER_ARM_R: Vector3(14, 0, 10), FOREARM_R: Vector3(58, 0, 0), HAND_R: Vector3(-6, 0, 0),
	UPPER_ARM_L: Vector3(14, 0, 10), FOREARM_L: Vector3(58, 0, 0), HAND_L: Vector3(-6, 0, 0),
	THIGH_R: Vector3(84, 0, 5), SHIN_R: Vector3(-28, 0, 0), FOOT_R: Vector3(12, 0, 0),
	THIGH_L: Vector3(84, 0, 5), SHIN_L: Vector3(-28, 0, 0), FOOT_L: Vector3(12, 0, 0),
}

## Each pose's key poses: [progress, table], in order.
const LIE_KEYS: Array = [[0.0, LIE]]
const GET_UP_KEYS: Array = [[0.0, LIE], [0.2, STIR], [0.38, PROPPED], [0.55, SIT], [0.75, KNEEL], [0.9, STAND],
	[1.0, REACH]]
const CLIMB_KEYS: Array = [[0.0, HANG], [0.35, PULL], [0.52, MANTLE], [0.66, PRESS], [0.8, KNEE_UP], [0.9, RISE],
	[1.0, UP]]
const GET_IN_KEYS: Array = [[0.0, AT_EASE], [0.28, STEP_IN], [0.52, DUCK_IN], [0.78, SIT_DOWN], [1.0, SEATED]]


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


## How much a pose's legs step while it's moved along (add_steps): not while walking (the walk is its own
## steps) or getting in (its legs are its key poses).
static func steps_while_moving(pose_name: StringName) -> float:
	return 0.0 if pose_name == &"walk" or pose_name == &"get_in" else 1.0


## The walk's phase advanced by `moved` metres, its stride `stride` of its full one (walk_stride).
static func walk_phase(phase: float, moved: float, stride: float = 1.0) -> float:
	return fposmod(phase + moved / (WALK_CYCLE * maxf(stride, 0.01)), 1.0)


## How long the walk's stride is at `gait` m/s, a share of its full one: shorter steps, walking slowly.
static func walk_stride(gait: float) -> float:
	return lerpf(MIN_STRIDE, 1.0, walk_amount(gait))


## How far into its stride a walk at `speed` m/s is (0 standing, 1 walking).
static func walk_amount(speed: float) -> float:
	return smoothstep(WALK_SPEED.x, WALK_SPEED.y, speed)


## Fills `p` with the runner walking: `phase` 0-1 through the gait cycle (the right heel strikes at 0, the
## left at 0.5), `amount` 0 (standing at ease) to 1 (stepping out), `time` the cinematic's, for its breath and
## its weight shifting as it stands. `sweep` is how far a planted foot goes back under the hip, a share of the
## full stride: walk_stride's share when it walks straight on, less as it turns, 0 stepping in place, so the
## foot stays put on the ground. `stride` is the full stride's length (a cycle) in the rig's own units, its legs'
## `thigh` and `shin` long (HumanoidParts; a rig fitted to a size scales them).
static func walk(p: HumanoidPose, phase: float, amount: float, time: float, sweep: float = 0.0,
		stride: float = WALK_CYCLE, thigh: float = 0.3, shin: float = 0.3) -> void:
	p.reset()
	p.add_table(AT_EASE, 1.0)
	var a: float = clampf(amount, 0.0, 1.0)
	var c: float = cos(TAU * phase)
	var s: float = sin(TAU * phase)
	var still: float = 1.0 - a
	# The hips turn with the leg swinging forward and drop toward the swinging side; the shoulders turn
	# against them; the head keeps to the way ahead.
	var hip_turn: float = WALK_HIP_TURN * c * a
	var shoulder_turn: float = -WALK_SHOULDER_TURN * c * a
	var shift: float = SHIFT * sin(TAU * SHIFT_RATE * time) * still
	p.add_deg(PELVIS, Vector3(0.0, hip_turn, WALK_HIP_DROP * s * a + shift))
	p.add_deg(CHEST, Vector3(-WALK_LEAN * a + BREATH * sin(TAU * BREATH_RATE * time), shoulder_turn, -shift * 0.6))
	p.add_deg(HEAD, Vector3(1.5 * a * cos(2.0 * TAU * phase), -(hip_turn + shoulder_turn), 0.0))
	for side: int in [1, -1]:
		var leg: float = fposmod(phase + (0.0 if side > 0 else 0.5), 1.0)
		# The knee: a little bend as it takes the weight, a big one to clear the ground through the swing.
		var knee: float = (WALK_KNEE_LOAD * _bump(leg, 0.1, 0.09) + WALK_KNEE_SWING * _bump(leg, 0.72, 0.13)) * a
		# The thigh: where it puts the foot, with the knee bent so (exact while the foot is down).
		var ahead: float = foot_ahead(leg, stride) * sweep
		var thigh_deg: float = rad_to_deg(_thigh_for(ahead, deg_to_rad(knee), thigh, shin))
		# The sole stays level through the stance; the heel strikes toe up, the foot rolls off its toe.
		var foot: float = -(thigh_deg - knee) + (10.0 * _bump(leg, 0.0, 0.07) - 20.0 * _bump(leg, STANCE, 0.07)) * a
		# The thigh hangs from the pelvis, which turns and drops: it's turned back against that, so the leg
		# swings straight ahead and the planted foot doesn't sway.
		var hip: int = HumanoidPose.limb(HumanoidPose.THIGH_R, side)
		var swung: Vector3 = p.rot[hip] + Vector3(deg_to_rad(thigh_deg), 0.0, 0.0)
		p.rot[hip] = (Basis.from_euler(p.rot[PELVIS]).inverse() * Basis.from_euler(swung)).get_euler()
		p.add_limb(HumanoidPose.SHIN_R, side, Vector3(-knee, 0.0, 0.0))
		p.add_limb(HumanoidPose.FOOT_R, side, Vector3(foot, 0.0, 0.0))
		# Each arm swings with the other side's leg (back as its own leg comes forward), the elbow bending a
		# little more as it comes forward.
		var arm: float = -WALK_ARM * a * foot_ahead(leg, 1.0) / (STANCE * 0.5)
		p.add_limb(HumanoidPose.UPPER_ARM_R, side, Vector3(arm, 0.0, 0.0))
		p.add_limb(HumanoidPose.FOREARM_R, side, Vector3(maxf(arm, 0.0) * 0.6, 0.0, 0.0))
	p.ground = 1.0


## How far ahead of its hip a walking foot is (in `stride`'s units) at leg phase `q` (its heel strikes at 0), in
## a stride `stride` long: down from 0 to STANCE, going back at the body's pace (so it stays put on the ground),
## as far behind the hip as it was ahead; then swinging forward (a Hermite curve, leaving and landing at that
## pace, so it lifts off and touches down without a skid) to strike again.
static func foot_ahead(q: float, stride: float) -> float:
	var front: float = STANCE * stride * 0.5
	if q < STANCE:
		return front - q * stride
	var u: float = (q - STANCE) / (1.0 - STANCE)
	var pace: float = -stride * (1.0 - STANCE)
	var u2: float = u * u
	var u3: float = u2 * u
	return (2.0 * u3 - 3.0 * u2 + 1.0) * -front + (u3 - 2.0 * u2 + u) * pace + (-2.0 * u3 + 3.0 * u2) * front \
		+ (u3 - u2) * pace


## The thigh's swing forward (radians) that puts the ankle `ahead` in front of the hip, the knee bent `knee`
## (radians), the thigh and shin that long: ahead = thigh sin a + shin sin(a - knee).
static func _thigh_for(ahead: float, knee: float, thigh: float, shin: float) -> float:
	var along: float = thigh + shin * cos(knee)
	var back: float = shin * sin(knee)
	var reach: float = sqrt(along * along + back * back)
	return atan2(back, along) + asin(clampf(ahead / maxf(reach, 0.001), -1.0, 1.0))


## A smooth bump of height 1 at `center` (phase, wrapping round), `width` wide.
static func _bump(phase: float, center: float, width: float) -> float:
	var d: float = fposmod(phase - center + 0.5, 1.0) - 0.5
	return exp(-(d * d) / (width * width))


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
		&"get_in":
			keys = GET_IN_KEYS
		&"walk":
			walk(p, 0.0, 0.0, time)
			return
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
