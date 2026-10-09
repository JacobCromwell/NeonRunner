extends RefCounted
## The cyborgs' poses for the shared HumanoidRig, in HumanoidPose's conventions (degrees; limbs: +x
## swings forward, +z out to the side, +y turns inward; centre joints: +x tilts back, +y turns left,
## +z tilts left). Walking and the panic sprint reuse HumanoidPoses.run() with the cyborgs' own
## animation tunings; standing reuses HumanoidPoses.idle(). CyborgBody blends these and aims the
## cannon arm on top.
##
## The posture (GDD §9.2: a ragged, strung-out gangster, "gaunt, hunched and twitchy"): the chest
## hunched forward with the screen head raised back to look ahead and the arms hanging slack, and a
## shambling walk that drags the left leg (posture()). On top of the blended pose CyborgBody adds the
## twitches (a jerk of the head now and then, like a glitch in the feed) and a fine tremor in the free
## hand (jitter()), so they stay sharp. None of it changes a pose's timing or the cannon arm's reach.

const PELVIS: int = HumanoidPose.PELVIS
const CHEST: int = HumanoidPose.CHEST
const NECK: int = HumanoidPose.NECK
const HEAD: int = HumanoidPose.HEAD
const UPPER_ARM_L: int = HumanoidPose.UPPER_ARM_L
const FOREARM_L: int = HumanoidPose.FOREARM_L
const UPPER_ARM_R: int = HumanoidPose.UPPER_ARM_R
const FOREARM_R: int = HumanoidPose.FOREARM_R
const THIGH_L: int = HumanoidPose.THIGH_L
const SHIN_L: int = HumanoidPose.SHIN_L
const FOOT_L: int = HumanoidPose.FOOT_L
const THIGH_R: int = HumanoidPose.THIGH_R
const SHIN_R: int = HumanoidPose.SHIN_R
const FOOT_R: int = HumanoidPose.FOOT_R

## The hunch (degrees the chest leans forward); the neck and head take it back so the screen faces
## ahead. The arms hang ARM_SLACK degrees forward of straight down.
## DESIGN-TBD (docs/questions/p2.md 5): how strung out it moves (the hunch, limp, twitches, tremor).
const HUNCH: float = 11.0
const ARM_SLACK: float = 5.0
## The shamble: the left knee lifts only LIMP of its full bend as it swings through, the body dips
## LIMP_DIP degrees toward the left leg as it takes the weight, and the heavy cannon arm swings only
## CANNON_SWING of the free arm's swing.
const LIMP: float = 0.5
const LIMP_DIP: float = 4.0
const CANNON_SWING: float = 0.45
## Twitches: time is cut into slots of TWITCH_SLOT seconds, and in TWITCH_SHARE of them the head jerks
## by up to TWITCH_HEAD (pitch, yaw, roll, degrees), getting there in TWITCH_SNAP seconds and settling
## back over TWITCH_SETTLE, with the chest hitching by TWITCH_HITCH.
const TWITCH_SLOT: float = 1.9
const TWITCH_SHARE: float = 0.55
const TWITCH_SNAP: float = 0.05
const TWITCH_SETTLE: float = 0.3
const TWITCH_HEAD := Vector3(8.0, 13.0, 11.0)
const TWITCH_HITCH: float = 3.0
## The free hand's fine tremor (degrees at the elbow, Hz), and a faint one in the head.
const TREMOR: float = 1.6
const TREMOR_RATE: float = 9.0
const HEAD_TREMOR: float = 0.4

## Aiming: a braced stance, the free arm cocked against the chest.
const AIM := {
	THIGH_R: Vector3(14, 0, 5), SHIN_R: Vector3(-16, 0, 0), FOOT_R: Vector3(2, 0, 0),
	THIGH_L: Vector3(-10, 0, 7), SHIN_L: Vector3(-10, 0, 0), FOOT_L: Vector3(10, 0, 0),
	UPPER_ARM_L: Vector3(40, 18, 12), FOREARM_L: Vector3(80, 0, 0),
	CHEST: Vector3(-3, 0, 0),
}

## Cowering: crouched low, arms up in front of the face.
const COWER := {
	PELVIS: Vector3(-6, 0, 0), CHEST: Vector3(-24, 0, 0), NECK: Vector3(-8, 0, 0), HEAD: Vector3(-10, 0, 0),
	THIGH_R: Vector3(92, 0, 12), SHIN_R: Vector3(-138, 0, 0), FOOT_R: Vector3(46, 0, 0),
	THIGH_L: Vector3(88, 0, 12), SHIN_L: Vector3(-134, 0, 0), FOOT_L: Vector3(46, 0, 0),
	UPPER_ARM_R: Vector3(118, 24, -6), FOREARM_R: Vector3(104, 0, 0),
	UPPER_ARM_L: Vector3(126, 24, -6), FOREARM_L: Vector3(100, 0, 0),
}

## In a window: forearms resting on the sill.
const WINDOW := {
	UPPER_ARM_R: Vector3(46, 8, 14), FOREARM_R: Vector3(52, 0, 0),
	UPPER_ARM_L: Vector3(46, 8, 14), FOREARM_L: Vector3(52, 0, 0),
}

## Lying still on its front (cinematics, CyborgBody.Pose.LIE): sprawled, one arm flung out ahead, its
## screen turned to one side. DESIGN-TBD (docs/questions/f2c.md): this and CROUCH are placeholder poses.
const LIE := {
	"root_rot": Vector3(-86, 0, 6),
	CHEST: Vector3(-4, 0, 8), NECK: Vector3(8, 0, 0), HEAD: Vector3(14, 40, 0),
	UPPER_ARM_R: Vector3(150, 0, 30), FOREARM_R: Vector3(20, 0, 0),
	UPPER_ARM_L: Vector3(8, 0, 22), FOREARM_L: Vector3(30, 0, 0),
	THIGH_R: Vector3(-4, 0, 16), SHIN_R: Vector3(-14, 0, 0), FOOT_R: Vector3(-50, 0, 0),
	THIGH_L: Vector3(2, 0, 6), SHIN_L: Vector3(-30, 0, 0), FOOT_L: Vector3(-45, 0, 0),
}

## Crouched low over something in front of it (cinematics, CyborgBody.Pose.CROUCH), its hands down on it
## and its screen bowed over it.
const CROUCH := {
	PELVIS: Vector3(-12, 0, 0), CHEST: Vector3(-40, 0, 0), NECK: Vector3(-12, 0, 0), HEAD: Vector3(-24, 0, 0),
	THIGH_R: Vector3(108, 0, 18), SHIN_R: Vector3(-142, 0, 0), FOOT_R: Vector3(38, 0, 0),
	THIGH_L: Vector3(70, 0, 22), SHIN_L: Vector3(-138, 0, 0), FOOT_L: Vector3(-10, 0, 0),
	UPPER_ARM_R: Vector3(66, 12, 10), FOREARM_R: Vector3(40, 0, 0),
	UPPER_ARM_L: Vector3(74, 16, 8), FOREARM_L: Vector3(30, 0, 0),
}
## Crouched, it works at what's in front of it: each arm in turn tugs back this often (seconds), the chest
## and screen dipping into it.
const CROUCH_TUG_PERIOD: float = 1.4

## A window cyborg once defeated: slumped over the sill, arms hanging out.
const SLUMP := {
	CHEST: Vector3(-55, 0, 6), NECK: Vector3(-12, 0, 0), HEAD: Vector3(-20, 16, 0),
	UPPER_ARM_R: Vector3(-8, 0, 6), FOREARM_R: Vector3(10, 0, 0),
	UPPER_ARM_L: Vector3(-4, 0, 10), FOREARM_L: Vector3(14, 0, 0),
}


static func idle(p: HumanoidPose, time: float, t: HumanoidAnimTuning, hunch: float) -> void:
	HumanoidPoses.idle(p, time, t)
	posture(p, hunch)


## Walking: the shared run cycle at a walk's stride (the cyborgs' walk tuning), shambling: the left
## leg drags (its cycle is `phase` itself) and the body dips toward it as it lands.
static func walk(p: HumanoidPose, phase: float, amount: float, t: HumanoidAnimTuning, hunch: float) -> void:
	HumanoidPoses.run(p, phase, amount, t)
	var stance: float = HumanoidPoses.stance_weight(phase)
	p.rot[SHIN_L] *= 1.0 - (1.0 - LIMP) * (1.0 - stance)
	var dip: float = LIMP_DIP * stance * amount
	p.add_deg(PELVIS, Vector3(0.0, 0.0, dip))
	p.add_deg(CHEST, Vector3(0.0, 0.0, -dip * 0.6))
	p.rot[UPPER_ARM_R].x *= CANNON_SWING
	posture(p, hunch)


static func aim(p: HumanoidPose, time: float, t: HumanoidAnimTuning, hunch: float) -> void:
	HumanoidPoses.idle(p, time, t)
	for joint: int in [THIGH_L, SHIN_L, FOOT_L, THIGH_R, SHIN_R, FOOT_R, UPPER_ARM_L, FOREARM_L]:
		p.rot[joint] = Vector3.ZERO
	p.add_table(AIM, 1.0)
	posture(p, hunch)


## The panic variant's flight: a flat-out sprint leaning forward, the free arm flailing overhead and
## the head twisted right round to watch the player (so its shocked face stays in view).
static func run_away(p: HumanoidPose, phase: float, time: float, t: HumanoidAnimTuning) -> void:
	HumanoidPoses.run(p, phase, 1.0, t)
	p.add_deg(CHEST, Vector3(-12.0, 0.0, 0.0))
	p.set_deg(NECK, Vector3(8.0, -60.0, 0.0))
	p.set_deg(HEAD, Vector3(12.0, -95.0 + 7.0 * sin(time * 9.0), 0.0))
	p.set_limb(UPPER_ARM_R, -1, Vector3(150.0 + 25.0 * sin(time * 17.0), 0.0, 22.0 + 12.0 * sin(time * 11.0)))
	p.set_limb(FOREARM_R, -1, Vector3(30.0 + 25.0 * sin(time * 13.0), 0.0, 0.0))
	p.set_limb(UPPER_ARM_R, 1, Vector3(-60.0, 0.0, 20.0))
	p.set_limb(FOREARM_R, 1, Vector3(10.0, 0.0, 0.0))


static func cower(p: HumanoidPose, time: float) -> void:
	p.reset()
	p.add_table(COWER, 1.0)
	p.add_deg(HEAD, Vector3(0.0, 5.0 * sin(time * 23.0), 0.0))  # trembling


## In a window (upper body only, not put on the ground): leaning out over the sill by `lean` degrees.
static func window(p: HumanoidPose, time: float, t: HumanoidAnimTuning, lean: float) -> void:
	HumanoidPoses.idle(p, time, t)
	for joint: int in [UPPER_ARM_L, FOREARM_L, UPPER_ARM_R, FOREARM_R]:
		p.rot[joint] = Vector3.ZERO
	p.add_table(WINDOW, 1.0)
	p.add_deg(CHEST, Vector3(-lean, 0.0, 0.0))
	p.ground = 0.0


## Lying still (`mirrored`: the other way round, so two bodies don't lie alike).
static func lie(p: HumanoidPose, mirrored: bool) -> void:
	p.reset()
	p.add_table(LIE, 1.0, mirrored)


## Crouched over something, working at it (`busy` 0-1: it stops, its hands still, as it looks up from it): each
## arm tugs back in turn, sharply, and eases forward again, the chest and screen dipping with it.
static func crouch(p: HumanoidPose, time: float, busy: float = 1.0) -> void:
	p.reset()
	p.add_table(CROUCH, 1.0)
	var u: float = fposmod(time / CROUCH_TUG_PERIOD, 1.0)
	for side: int in [-1, 1]:
		var k: float = fposmod(u + (0.0 if side > 0 else 0.5), 1.0)
		# A quick pull back over the first fifth of its turn, easing forward over the rest.
		var tug: float = smoothstep(0.0, 0.2, k) * (1.0 - smoothstep(0.2, 1.0, k)) * busy
		p.add_limb(UPPER_ARM_R, side, Vector3(-22.0 * tug, 0.0, 4.0 * tug))
		p.add_limb(FOREARM_R, side, Vector3(30.0 * tug, 0.0, 0.0))
		p.add_deg(CHEST, Vector3(4.0 * tug, 0.0, side * 3.0 * tug))
		p.add_deg(HEAD, Vector3(-6.0 * tug, side * 5.0 * tug, 0.0))


static func slump(p: HumanoidPose) -> void:
	p.reset()
	p.add_table(SLUMP, 1.0)
	p.ground = 0.0


## The hunch: the chest forward, the neck and head raised back so the screen looks ahead, the arms
## hanging slack.
static func posture(p: HumanoidPose, hunch: float) -> void:
	if hunch <= 0.0:
		return
	p.add_deg(CHEST, Vector3(-hunch, 0.0, 0.0))
	p.add_deg(NECK, Vector3(hunch * 0.5, 0.0, 0.0))
	p.add_deg(HEAD, Vector3(hunch * 0.5, 0.0, 0.0))
	for side: int in [-1, 1]:
		p.add_limb(UPPER_ARM_R, side, Vector3(ARM_SLACK - hunch, 0.0, 0.0))


## A twitch at `time` for the cyborg whose schedule is offset by `phase` (slots): x, y, z the jerk's
## direction per axis (-1..1) and w how far into it (0 still, 1 at the jerk's peak).
static func twitch(time: float, phase: float) -> Vector4:
	var k: float = time / TWITCH_SLOT + phase
	var slot: float = floorf(k)
	if _hash(slot, 1.0) > TWITCH_SHARE:
		return Vector4.ZERO
	var start: float = _hash(slot, 2.0) * (TWITCH_SLOT - TWITCH_SNAP - TWITCH_SETTLE)
	var dt: float = (k - slot) * TWITCH_SLOT - start
	var e: float = smoothstep(0.0, TWITCH_SNAP, dt) * (1.0 - smoothstep(TWITCH_SNAP, TWITCH_SNAP + TWITCH_SETTLE, dt))
	return Vector4(_hash(slot, 3.0) * 2.0 - 1.0, _hash(slot, 4.0) * 2.0 - 1.0, _hash(slot, 5.0) * 2.0 - 1.0, e)


## The twitches and the tremor, in radians per joint (HumanoidPose joint index → Euler angles) for
## CyborgBody to add to the posed rig: the head's jerk and the chest's hitch (`twitching` false
## leaves them out), the free hand's tremor and a faint one in the head.
static func jitter(time: float, phase: float, twitching: bool) -> Dictionary:
	var out: Dictionary = {}
	var s: float = sin(time * TAU * TREMOR_RATE) + 0.5 * sin(time * TAU * TREMOR_RATE * 1.73 + 1.3)
	var head := Vector3(0.0, 0.0, HEAD_TREMOR * s)
	var chest := Vector3.ZERO
	if twitching:
		var tw: Vector4 = twitch(time, phase)
		head += Vector3(tw.x * TWITCH_HEAD.x, tw.y * TWITCH_HEAD.y, tw.z * TWITCH_HEAD.z) * tw.w
		chest = Vector3(-TWITCH_HITCH, 0.0, tw.z * TWITCH_HITCH) * tw.w
	out[HEAD] = head * HumanoidPose.DEG
	out[CHEST] = chest * HumanoidPose.DEG
	out[FOREARM_L] = Vector3(TREMOR * s, 0.0, 0.0) * HumanoidPose.DEG
	return out


## A repeatable pseudo-random number in [0, 1) from two numbers.
static func _hash(a: float, b: float) -> float:
	var h: float = sin(a * 127.1 + b * 311.7) * 43758.5453
	return h - floorf(h)
