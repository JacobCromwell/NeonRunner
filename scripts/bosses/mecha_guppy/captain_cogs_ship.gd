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
## runner climbs to, over the next hut's tiki huts).
## Phase 3 (task E5e-c; GDD §10: "the captain's ship comes level with the player"): come_level() eases it down over
## MechaGuppyTuning.level_seconds to its station alongside the top, on the left (LEVEL_SIDE), level_ahead ahead of the
## runner, its keel level_keel over their deck (its gun deck at their height, the captain on its stern castle just above
## them), its near side level_out past the roof's eaves, swaying no more across the lanes, only bobbing. There it fires
## phase 3's rounds from its starboard cannons, the ones facing the top (fire(): a flash and smoke at each muzzle, the
## hull's recoil, the captain's arm swung over as the order; cannon_world()).
## The defeat (MechaGuppyLeap): swallow() is the gulp: the stern half and the captain vanish into Mecha Guppy's jaws, and
## the bow half (the hull's other mesh, CaptainCogsModel.SPLIT_Z) breaks away, tumbling down into the sea with the cog
## wheels, rubble flying from the break.
## DESIGN-TBD (docs/OPEN_QUESTIONS.md items 787 and 800): its stations and the captain's look and size.

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
## Phase 3: the side of the top the ship comes level on (-1 the left; the waves rise on the other side), how far its
## sway across the lanes shrinks there (it holds its broadside steady), and a cannon's recoil (metres, seconds).
const LEVEL_SIDE: int = -1
const LEVEL_SWAY: float = 0.0
const RECOIL: float = 0.35
const RECOIL_SECONDS: float = 0.5
## A cannon's muzzle flash (a warm white: no hazard colour) and its smoke.
const FLASH_COLOR := Color(1.0, 0.93, 0.8)
const SMOKE_COLOR := Color(0.55, 0.54, 0.52)
## The bow half's fall after the gulp: its spin (radians a second), its drift away from the top (m/s), the pull
## (m/s²), and how long it's shown.
const WRECK_SPIN := Vector3(1.6, 0.4, 2.2)
const WRECK_DRIFT: float = 9.0
const WRECK_PULL: float = 26.0
const WRECK_SECONDS: float = 3.0

var boss: MechaGuppy
var world: RunWorld
var tuning: MechaGuppyTuning
var rig: HumanoidRig
## Throws made, broadsides fired (tests).
var throws: int = 0
var broadsides: int = 0
## Phase 3: how far it has come down to its level station (0 its station above, 1 level; come_level eases it), and
## whether it has been eaten (swallow).
var level: float = 0.0
var swallowed: bool = false

var _bow: MeshInstance3D
var _stern: MeshInstance3D
var _wheels: Array[MeshInstance3D] = []
var _y: float = NAN
var _t: float = 0.0
var _throw_t: float = -1.0
var _scale: float = 1.0
## Phase 3's descent: its speed (share a second; 0 until come_level), and the recoil left (seconds).
var _level_speed: float = 0.0
var _recoil: float = 0.0
## The bow half's fall after the gulp (swallow): its node, its velocity, its time.
var _wreck: Node3D
var _wreck_v := Vector3.ZERO
var _wreck_t: float = 0.0


func setup(p_boss: MechaGuppy) -> void:
	boss = p_boss
	world = boss.world
	tuning = boss.tuning
	top_level = true
	var beach := world.skin as BeachSkin
	var meshes: Dictionary = CaptainCogsModel.meshes(beach if beach != null else BeachSkin.new())
	_bow = MeshBatch.add_instance(self, meshes["bow"], "Bow")
	_stern = MeshBatch.add_instance(self, meshes["stern"], "Stern")
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
	_advance_wreck(delta)
	if swallowed:
		return
	var p: Player = world.player
	if _level_speed > 0.0:
		level = minf(level + _level_speed * delta, 1.0)
	var k: float = level * level * (3.0 - 2.0 * level)
	var base: float = p.floor_base + lerpf(tuning.ship_height, tuning.level_keel, k)
	if is_nan(_y):
		_y = base
	# Above, its height eases after the roof it keeps over; coming level, it follows its descent exactly.
	_y = lerpf(_y, base, 1.0 - exp(-FOLLOW * delta)) if level <= 0.0 else base
	var sway: float = sin(_t * TAU / SWAY_PERIOD) * tuning.ship_sway * lerpf(1.0, LEVEL_SWAY, k)
	var x: float = lerpf(0.0, level_x(), k) + sway
	var bob: float = sin(_t * TAU / BOB_PERIOD) * BOB
	var roll: float = deg_to_rad(ROLL_DEGREES) * sin(_t * TAU / SWAY_PERIOD + 1.0) * lerpf(1.0, 0.5, k)
	_recoil = maxf(_recoil - delta, 0.0)
	var kick: float = RECOIL * sin(clampf(_recoil / RECOIL_SECONDS, 0.0, 1.0) * PI) * float(LEVEL_SIDE)
	global_transform = Transform3D(Basis(Vector3.BACK, roll),
		Vector3(x + kick, _y + bob, TrackGeometry.world_z(p.distance + lerpf(tuning.ship_ahead, tuning.level_ahead, k))))
	for i: int in _wheels.size():
		_wheels[i].rotation.x = _t * WHEEL_SPIN * (1.0 if i == 0 else -1.0)
	_pose(delta)


## Phase 3 (GDD §10: "the captain's ship comes level"): it comes down to its station alongside the top over
## MechaGuppyTuning.level_seconds (DESIGN-TBD).
func come_level() -> void:
	_level_speed = 1.0 / maxf(tuning.level_seconds, 0.05)


## True once it's at its level station.
func is_level() -> bool:
	return level >= 1.0


## Its middle's world x at its level station: alongside the top on LEVEL_SIDE, its near side level_out past the roof's
## eaves (MechaGuppyLooks.EAVE_REACH out past its edge).
func level_x() -> float:
	return float(LEVEL_SIDE) * (world.geo.wall_x() + MechaGuppyLooks.EAVE_REACH + tuning.level_out + CaptainCogsModel.BEAM * 0.5)


## Cannon `k`'s muzzle (world space) on the side facing the top (its starboard side when it's level on the left).
func cannon_world(k: int) -> Vector3:
	return global_transform * CaptainCogsModel.cannon_at(-LEVEL_SIDE, k)


## Fires a broadside of `count` cannons (phase 3's rounds; MechaGuppyRounds starts each ball at cannon_world): a flash and
## smoke at each muzzle, the hull's recoil, the captain swinging an arm over as the order (as a throw).
func fire(count: int) -> void:
	broadsides += 1
	_recoil = RECOIL_SECONDS
	_throw_t = 0.0
	var out := Vector3(float(-LEVEL_SIDE), 0.0, 0.0)
	for k: int in mini(count, CaptainCogsModel.CANNONS):
		var at: Vector3 = cannon_world(k)
		world.effects.burst(at + out * 0.4, FLASH_COLOR, 10, 0.45)
		world.effects.debris(at + out * 0.8, SMOKE_COLOR, 5, 0.8)


## The gulp (the defeat: Mecha Guppy's jaws shut on the stern half): the stern half and the captain gone, the bow half
## breaking away (tumbling down and away from the top with the cog wheels), rubble flying from the break. `away`: the
## world direction it falls away to (out from the top); `carry`: the velocity it keeps (the runner's, so it falls in view).
func swallow(away: Vector3, carry: Vector3 = Vector3.ZERO) -> void:
	if swallowed:
		return
	swallowed = true
	_stern.visible = false
	rig.visible = false
	var at: Transform3D = global_transform
	_wreck = Node3D.new()
	_wreck.name = "BowWreck"
	_wreck.top_level = true
	add_child(_wreck)
	_wreck.global_transform = at
	for node: Node3D in [_bow, _wheels[0], _wheels[1]]:
		var keep: Transform3D = node.global_transform
		node.reparent(_wreck)
		node.global_transform = keep
	_wreck_v = Vector3(away.x, 0.0, away.z).normalized() * WRECK_DRIFT + Vector3(0.0, 2.0, 0.0) + carry
	_wreck_t = 0.0
	var beach := world.skin as BeachSkin
	var colors := PackedColorArray([CaptainCogsModel.WOOD, CaptainCogsModel.DECK_WOOD, CaptainCogsModel.BRASS,
		CaptainCogsModel.CANVAS])
	if beach != null:
		colors.append(beach.timber_color)
	var cut: Vector3 = at * Vector3(0.0, CaptainCogsModel.DECK * 0.5, CaptainCogsModel.SPLIT_Z)
	world.effects.rubble(AABB(cut - Vector3(3.0, 2.0, 1.0), Vector3(6.0, 4.0, 2.0)), colors, _wreck_v * 0.5, 7)


## The bow half's tumble down into the sea after the gulp, then gone.
func _advance_wreck(delta: float) -> void:
	if _wreck == null or not is_instance_valid(_wreck) or not _wreck.visible:
		return
	_wreck_t += delta
	_wreck_v.y -= WRECK_PULL * delta
	var xf: Transform3D = _wreck.global_transform
	var spin := Basis.from_euler(WRECK_SPIN * delta)
	_wreck.global_transform = Transform3D(spin * xf.basis, xf.origin + _wreck_v * delta)
	if _wreck_t >= WRECK_SECONDS:
		_wreck.visible = false


## The bow half's fall (tests: where it is), or null before the gulp.
func wreck() -> Node3D:
	return _wreck if _wreck != null and is_instance_valid(_wreck) else null


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
