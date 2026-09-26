extends RefCounted
## The cyborgs' poses for the shared HumanoidRig, in HumanoidPose's conventions (degrees; limbs: +x
## swings forward, +z out to the side, +y turns inward; centre joints: +x tilts back, +y turns left,
## +z tilts left). Walking and the panic sprint reuse HumanoidPoses.run() with the cyborgs' own
## animation tunings; standing reuses HumanoidPoses.idle(). CyborgBody blends these and aims the
## cannon arm on top.

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

## A window cyborg once defeated: slumped over the sill, arms hanging out.
const SLUMP := {
	CHEST: Vector3(-55, 0, 6), NECK: Vector3(-12, 0, 0), HEAD: Vector3(-20, 16, 0),
	UPPER_ARM_R: Vector3(-8, 0, 6), FOREARM_R: Vector3(10, 0, 0),
	UPPER_ARM_L: Vector3(-4, 0, 10), FOREARM_L: Vector3(14, 0, 0),
}


static func idle(p: HumanoidPose, time: float, t: HumanoidAnimTuning, hunch: float) -> void:
	HumanoidPoses.idle(p, time, t)
	_hunch(p, hunch)


## Walking: the shared run cycle at a walk's stride (the cyborgs' walk tuning).
static func walk(p: HumanoidPose, phase: float, amount: float, t: HumanoidAnimTuning, hunch: float) -> void:
	HumanoidPoses.run(p, phase, amount, t)
	_hunch(p, hunch)


static func aim(p: HumanoidPose, time: float, t: HumanoidAnimTuning, hunch: float) -> void:
	HumanoidPoses.idle(p, time, t)
	for joint: int in [THIGH_L, SHIN_L, FOOT_L, THIGH_R, SHIN_R, FOOT_R, UPPER_ARM_L, FOREARM_L]:
		p.rot[joint] = Vector3.ZERO
	p.add_table(AIM, 1.0)
	_hunch(p, hunch)


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


static func slump(p: HumanoidPose) -> void:
	p.reset()
	p.add_table(SLUMP, 1.0)
	p.ground = 0.0


## The scavenger's hunch: the chest forward, the head raised back to look ahead.
static func _hunch(p: HumanoidPose, hunch: float) -> void:
	if hunch > 0.0:
		p.add_deg(CHEST, Vector3(-hunch, 0.0, 0.0))
		p.add_deg(HEAD, Vector3(hunch * 0.7, 0.0, 0.0))
