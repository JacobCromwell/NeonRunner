class_name CaptainCogsShip
extends Node3D
## Captain Cogs in the floating ship (GDD §10: "a new enemy, only in this fight ... a pirate mixed with a futuristic
## look, in a floating ship flying above the track, throwing bombs down at the runner"; task E5e-b2): the ship
## (CaptainCogsModel) keeps its station ahead of the runner and above the roof they climb to (MechaGuppyTuning, "Captain
## Cogs' ship": ship_ahead, ship_height over Player.floor_base, eased as the runner climbs, swaying a little across the
## lanes and bobbing), its stern toward them, its cog wheels turning; the captain (CaptainCogsSuit on the HumanoidRig)
## stands on its stern castle facing the runner and throws each bomb (throw(): the arm whips over; MechaGuppyBombs
## starts the bomb at hand_world()). It has no collision at all (never on the hull layer, so a pad never flips a runner
## up to it: Player._ceiling_over_pad), and it stays high above every hut ahead (its keel ship_height over the roof the
## runner climbs to, over the next hut's tiki huts). Phase 3 (E5e-c) brings it level with the runner.
## DESIGN-TBD (docs/questions/e5e.md): its station and the captain's look and size.

## How fast its height follows the floor it keeps above (1/s: an ease, never a snap).
const FOLLOW: float = 1.6
## Its sway across the lanes and its bob (seconds a cycle, metres up and down), its gentle roll (degrees).
const SWAY_PERIOD: float = 9.0
const BOB_PERIOD: float = 2.6
const BOB: float = 0.35
const ROLL_DEGREES: float = 3.0
## The captain's height (metres: big, to read from far below), and where the throwing hand lets go of a bomb, from where
## the captain stands (the ship's space: over the right shoulder, toward the runner).
const CAPTAIN_HEIGHT: float = 2.4
const HAND := Vector3(-0.6, 2.7, 0.5)
## A throw: how long the arm takes to whip over and come back (seconds).
const THROW_SECONDS: float = 0.45
## The cog wheels turn this fast (radians a second).
const WHEEL_SPIN: float = 1.4

var boss: MechaGuppy
var world: RunWorld
var tuning: MechaGuppyTuning
var rig: HumanoidRig
## Throws made (tests).
var throws: int = 0

var _hull: MeshInstance3D
var _wheels: Array[MeshInstance3D] = []
var _y: float = NAN
var _t: float = 0.0
var _throw_t: float = -1.0
var _scale: float = 1.0


func setup(p_boss: MechaGuppy) -> void:
	boss = p_boss
	world = boss.world
	tuning = boss.tuning
	top_level = true
	var beach := world.skin as BeachSkin
	var meshes: Dictionary = CaptainCogsModel.meshes(beach if beach != null else BeachSkin.new())
	_hull = MeshBatch.add_instance(self, meshes["hull"], "Hull")
	for side: float in [-1.0, 1.0]:
		var wheel: MeshInstance3D = MeshBatch.add_instance(self, meshes["wheel"], "Wheel")
		wheel.position = Vector3(side * CaptainCogsModel.WHEEL_AT.x, CaptainCogsModel.WHEEL_AT.y, CaptainCogsModel.WHEEL_AT.z)
		wheel.scale = Vector3(side, 1.0, 1.0) * CaptainCogsModel.WHEEL_RADIUS
		_wheels.append(wheel)
	rig = HumanoidRig.new()
	rig.name = "Captain"
	add_child(rig)
	var anim := load(PlayerAvatar.ANIM_TUNING_PATH) as HumanoidAnimTuning
	rig.build(CaptainCogsSuit.parts(beach.neon_blue if beach != null else BeachSkin.new().neon_blue), CaptainCogsSuit.material(),
		anim if anim != null else HumanoidAnimTuning.new())
	_scale = CAPTAIN_HEIGHT / CaptainCogsSuit.DESIGN_HEIGHT
	rig.scale = Vector3.ONE * _scale
	rig.position = CaptainCogsModel.CAPTAIN_SPOT
	# The rig faces -z; the captain faces the runner (+z).
	rig.rotation.y = PI
	rig.animate({}, 0.0)
	advance(0.0)


## One physics step (the boss's ticks drive it; it waits while the runner is down).
func advance(delta: float) -> void:
	_t += delta
	var p: Player = world.player
	var base: float = p.floor_base + tuning.ship_height
	if is_nan(_y):
		_y = base
	_y = lerpf(_y, base, 1.0 - exp(-FOLLOW * delta))
	var x: float = sin(_t * TAU / SWAY_PERIOD) * tuning.ship_sway
	var bob: float = sin(_t * TAU / BOB_PERIOD) * BOB
	var roll: float = deg_to_rad(ROLL_DEGREES) * sin(_t * TAU / SWAY_PERIOD + 1.0)
	global_transform = Transform3D(Basis(Vector3.BACK, roll),
		Vector3(x, _y + bob, TrackGeometry.world_z(p.distance + tuning.ship_ahead)))
	for i: int in _wheels.size():
		_wheels[i].rotation.x = _t * WHEEL_SPIN * (1.0 if i == 0 else -1.0)
	_pose(delta)


## The captain throws a bomb now (MechaGuppyBombs, as it leaves the hand).
func throw() -> void:
	throws += 1
	_throw_t = 0.0


## Where the captain's throwing hand is as it lets go (world space): where a bomb starts.
func hand_world() -> Vector3:
	return global_transform * (CaptainCogsModel.CAPTAIN_SPOT + HAND)


## The captain's stance, and a throw's whip over and back: the right arm cocked high behind the head, swung over and down
## toward the runner; the clockwork arm at the side; a lean into the throw.
func _pose(delta: float) -> void:
	if rig == null:
		return
	rig.animate({}, delta)
	var u: float = -1.0
	if _throw_t >= 0.0:
		_throw_t += delta
		u = _throw_t / THROW_SECONDS
		if u >= 1.0:
			_throw_t = -1.0
			u = -1.0
	var upper := Vector3(40.0, 0.0, 22.0)
	var fore := Vector3(60.0, 0.0, 0.0)
	var lean: float = 0.0
	if u >= 0.0:
		# A quick whip over (the first third) and an easy follow-through back.
		var whip: float = clampf(u * 3.0, 0.0, 1.0)
		var back: float = clampf((u - 0.33) / 0.67, 0.0, 1.0)
		upper = Vector3(lerpf(170.0, 60.0, whip), 0.0, lerpf(30.0, 15.0, whip)).lerp(Vector3(40.0, 0.0, 22.0), back)
		fore = Vector3(lerpf(100.0, 10.0, whip), 0.0, 0.0).lerp(Vector3(60.0, 0.0, 0.0), back)
		lean = deg_to_rad(12.0) * sin(clampf(u, 0.0, 1.0) * PI)
	_arm(1, upper, fore)
	_arm(-1, Vector3(15.0, 0.0, 12.0), Vector3(55.0, 0.0, 0.0))
	rig.rotation.x = lean


## Poses one arm (degrees, HumanoidPose's limb convention: +x swings the arm forward and up, +z out to the side).
func _arm(side: int, upper: Vector3, fore: Vector3) -> void:
	var pre: String = "_l" if side < 0 else "_r"
	rig.joint(StringName("upper_arm" + pre)).rotation = _limb(side, upper)
	rig.joint(StringName("forearm" + pre)).rotation = _limb(side, fore)


static func _limb(side: int, degrees: Vector3) -> Vector3:
	var d: Vector3 = degrees if side > 0 else Vector3(degrees.x, -degrees.y, -degrees.z)
	return d * (PI / 180.0)
