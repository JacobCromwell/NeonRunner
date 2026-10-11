class_name MechaGuppyShark
extends Node3D
## Mecha Guppy (GDD §10: "a giant mechanical shark, gigantic, the size of a building ... Its maw comes up through the
## floor and eats a huge chunk of the level. It can be seen ahead of the runner and behind them ... the player will
## mostly only ever see its giant jaws and its eyes"; task E5e-b2). Its look is MechaGuppySharkModel's, scaled up
## (SCALE); it has no hitbox at all: it hurts nobody (a wrong drop dies of its fall, as before), and nothing on it glows.
## It lurks far down the chasm, out of sight, and comes up when MechaGuppy's pattern asks it (MechaGuppyPattern), always
## side-on to the runner, so they see it in profile: its jaws, its teeth and an eye:
## - bite(): it eats the floor the runner should have left. The warning first: the rumble (guppy_rumble), and the shark
##   surging up out of the chasm beside the roof's end (bite_warning: the runner sees it as they near the roof's pads);
##   it waits there until nobody can be on that roof any more (may_break: the runner up on the hut). Then it rises
##   beside the roof's end and leans over it, its chin dropping wide across the roof (bite_rise), stays open
##   (bite_hold), and snaps shut, scooping the roof's end into its jaws (bite_snap, guppy_bite): at the snap it's gone
##   (on_snap: MechaGuppyStairs.eat_roof, collision and look together, rubble flying). Then it sinks (bite_sink). Only
##   when it's free: a bite asked for while it's busy isn't made.
## - lurk() then breach(): it waits deep under the middle of the chasm in front of the higher roof (lurk: far below
##   anything that would tell a rider which lanes lead up); when Captain Cogs throws there, it surges up beside the lanes
##   that don't lead up (its head kept LANE_CLEAR from the lanes that do, and from a pier's stilts), its snout and an eye
##   toward the runner, and opens its jaws outward as the bomb comes down into them (open by open_at, held
##   breach_hold): a bomb landing in its open jaws hits it (mouth_contains; MechaGuppyBombs calls hit()): a clang,
##   sparks and smoke, a shudder. Then it snaps shut and sinks.
## Its pose (hinge, pitch, roll, yaw, jaw) is always eased from the one before, so it never pops while it can be seen.
## advance() is driven by the boss's ticks (time from the physics step; it waits while the runner is down). Nothing
## flickers (Reduced flashing has nothing to calm; the hit's fireball and sparks are RunEffects', which honour it).
## DESIGN-TBD (docs/questions/e5e.md): its size, poses and timings (MechaGuppyTuning, "Mecha Guppy's bites").

enum Kind { BITE, BREACH }
enum Stage { IDLE, LURKING, RISING, WAITING, BREAKING, OPEN, SNAPPING, SINKING }

## How big it is (MechaGuppySharkModel's metres times this): its jaws 12 m long, its head 12.6 m across.
const SCALE: float = 1.5
## How far below the floor it sinks between bites, out of sight (metres, its hinge), and how far under the floor it lurks
## before a breach (under the middle of the chasm: it gives nothing away), gliding there for LURK_SECONDS.
const DEEP: float = 55.0
const LURK_DEPTH: float = 26.0
const LURK_SECONDS: float = 1.0
## A breach's surge from the lurk is never quicker than this (seconds).
const MIN_RISE: float = 0.12
## Rising toward the floor (the warning), its jaws' tips this far under the floor's level (metres).
const BELOW_TIPS: float = 2.5
## A bite: its hinge this far out from the track's side (beside the tower: its chin clears it), this far under the roof's
## top, leaning in over the roof this far (degrees), and at the snap leaning further and coming in (metres).
const BITE_OUT: float = 5.3
const BITE_SINK: float = 4.5
const BITE_LEAN: float = 12.0
const SNAP_LEAN: float = 26.0
const SNAP_IN: float = 1.5
## A breach: its hinge this far under the floor's level (its eyes just over it), and the bomb falls in this far out from
## its hinge's line (metres: between its palate and its dropped chin).
const BREACH_SINK: float = 2.0
const MOUTH_OUT: float = 1.0
## Its head stays this far clear of the lanes that lead up (metres; MechaGuppyPattern.hit_spot places the bomb so).
const LANE_CLEAR: float = 0.5
## The hit: its shudder (degrees, seconds), the fireball's radius in its mouth, the sparks' and smoke's colours.
const SHUDDER_DEGREES: float = 7.0
const SHUDDER_SECONDS: float = 0.6
const HIT_FIRE: float = 1.8
const SPARK_COLOR := Color(1.0, 0.78, 0.35)
const SMOKE_COLOR := Color(0.32, 0.31, 0.3)
## A bomb counts as in its jaws while they're at least this open (0-1).
const OPEN_ENOUGH: float = 0.55

## Called with the action as a bite's jaws snap shut (MechaGuppyPattern.on_snap eats the roof).
var on_snap: Callable
var tuning: MechaGuppyTuning
var world: RunWorld
var boss: MechaGuppy
## The action under way: {kind, side (-1 it comes up on the left, +1 the right), top (the floor's level it comes up to),
## a bite's edge, roof, cut and may_break, a breach's x (the bomb's world x), at (its track distance) and open_at (bomb
## clock)}; empty while idle.
var action: Dictionary = {}
var stage: Stage = Stage.IDLE
var stage_time: float = 0.0
## Bites and breaches made, hits taken, bites it was too busy for (tests).
var bites: int = 0
var breaches: int = 0
var hits: int = 0
var skipped: int = 0
## How open its jaws are (0 shut, 1 wide), and its pose: the hinge's world position, then (applied in this order) pitch
## (radians about its own x), yaw (about the vertical: which way its chin faces) and roll (about the track: its snout
## toward -x when positive).
var jaw: float = 0.0
var hinge := Vector3(0.0, -DEEP, 0.0)
var pitch: float = 0.0
var roll: float = 0.0
var yaw: float = 0.0

var _from: Dictionary = {}
var _to: Dictionary = {}
var _stage_seconds: float = 1.0
var _shudder: float = 0.0
var _head: Node3D
var _upper: MeshInstance3D
var _lower: MeshInstance3D
var _body: MeshInstance3D


func setup(p_boss: MechaGuppy) -> void:
	boss = p_boss
	world = boss.world
	tuning = boss.tuning
	top_level = true
	transform = Transform3D.IDENTITY
	_head = Node3D.new()
	_head.name = "Head"
	add_child(_head)
	var beach := world.skin as BeachSkin
	var meshes: Dictionary = MechaGuppySharkModel.meshes(beach if beach != null else BeachSkin.new())
	_upper = MeshBatch.add_instance(_head, meshes["upper_jaw"], "UpperJaw")
	_lower = MeshBatch.add_instance(_head, meshes["lower_jaw"], "LowerJaw")
	_body = MeshBatch.add_instance(_head, meshes["body"], "Body")
	_head.visible = false


## The jaws' length at this size (metres).
static func jaw_length() -> float:
	return MechaGuppySharkModel.JAW_LENGTH * SCALE


## True while it's doing nothing (or only lurking).
func idle() -> bool:
	return stage == Stage.IDLE


## True while a bite or breach is under way and hasn't snapped yet.
func busy() -> bool:
	return stage != Stage.IDLE and stage != Stage.SINKING and stage != Stage.LURKING


## True while it can be seen (up out of the deep, or lurking).
func shown() -> bool:
	return _head.visible


## A bite (see the header): `spot` {side (-1 it comes up left of the track, +1 right), edge (the roof's eaten edge: track
## distance), top (the roof's top), roof (its index), cut (where it eats the roof back to), may_break (Callable: true once
## nobody can be on that roof)}. Its warning starts now. False (nothing done) while it's busy.
func bite(spot: Dictionary) -> bool:
	if busy():
		skipped += 1
		boss.log_event(&"bite_skipped", {"roof": int(spot.get("roof", -1))})
		return false
	var next: Dictionary = spot.duplicate()
	next["kind"] = Kind.BITE
	_begin(next)
	return true


## Swims deep under where a breach will come (`spot` as breach()'s, without open_at), out of sight; only while it's free.
func lurk(spot: Dictionary) -> void:
	if busy():
		return
	action = spot.duplicate()
	action["kind"] = Kind.BREACH
	if stage == Stage.IDLE:
		_appear(_lurk_pose())
	_go(Stage.LURKING, _lurk_pose(), LURK_SECONDS)


## A breach (see the header): `spot` {x (where the bomb falls in: world x), at (track distance), top (the floor's level
## beside it), side (-1 left of the lanes that lead up, +1 right), open_at (bomb clock: its jaws wide open by then)}.
## From its lurk it surges up just in time; from anywhere else, as fast as it must. False while it's busy.
## hinge_x() gives where its hinge must be for the bomb to fall into its jaws at `x`.
func breach(spot: Dictionary) -> bool:
	if busy():
		boss.log_event(&"breach_skipped", {"at": float(spot.get("at", 0.0))})
		return false
	var next: Dictionary = spot.duplicate()
	next["kind"] = Kind.BREACH
	_begin(next)
	return true


## True while a bomb at world point `p` (as it reaches the floor's level) falls into its open jaws: its jaws at least
## OPEN_ENOUGH open, and `p` (in its head's own space) between them: up its jaws, inside their width there, in front of
## the snout's palate and over the chin's.
func mouth_contains(p: Vector3) -> bool:
	if action.is_empty() or jaw < OPEN_ENOUGH or (stage != Stage.BREAKING and stage != Stage.OPEN and stage != Stage.SNAPPING):
		return false
	var local: Vector3 = _head.global_transform.affine_inverse() * p
	var u: float = local.y / MechaGuppySharkModel.JAW_LENGTH
	if u < 0.12 or u > 1.05:
		return false
	var half: float = MechaGuppySharkModel.jaw_size(u).x * 0.95 + 0.15
	if absf(local.x) > half:
		return false
	var z_lo: float = -local.y * tan(deg_to_rad(MechaGuppySharkModel.UPPER_OPEN) * jaw) - 0.25
	var z_hi: float = local.y * tan(deg_to_rad(MechaGuppySharkModel.LOWER_OPEN) * jaw) + 0.25
	return local.z >= z_lo and local.z <= z_hi


## A bomb fell into its jaws (MechaGuppyBombs): the clang, a fireball and sparks in its mouth, smoke, a shudder, a shake.
func hit(p: Vector3) -> void:
	hits += 1
	_shudder = SHUDDER_SECONDS
	var mouth := Vector3(p.x, p.y - 1.0, p.z)
	world.effects.fireball(mouth, HIT_FIRE, true, 1.2, 0.6)
	world.effects.burst(mouth + Vector3(0.0, 1.0, 0.0), SPARK_COLOR, 28, 0.9)
	world.effects.debris(mouth + Vector3(0.0, 0.6, 0.0), SMOKE_COLOR, 8, 0.9)
	var near: float = clampf(1.0 - absf(-p.z - world.player.distance) / 40.0, 0.25, 1.0)
	world.effects.shake(0.35 * near, 0.35)
	boss.sound(&"guppy_clang", mouth)


## One physics step (the boss's ticks drive it).
func advance(delta: float) -> void:
	_shudder = maxf(_shudder - delta, 0.0)
	if stage == Stage.IDLE:
		return
	stage_time += delta
	var kind: int = int(action.get("kind", Kind.BITE))
	match stage:
		Stage.LURKING:
			_ease(stage_time / _stage_seconds)
		Stage.RISING:
			_ease(stage_time / _stage_seconds)
			if stage_time >= _stage_seconds:
				_go(Stage.WAITING, _below_pose(), 1.0)
		Stage.WAITING:
			_ease(1.0)
			if _may_break():
				_go(Stage.BREAKING, _open_pose(), tuning.bite_rise if kind == Kind.BITE else tuning.breach_rise)
		Stage.BREAKING:
			_ease(stage_time / _stage_seconds)
			if stage_time >= _stage_seconds:
				_go(Stage.OPEN, _open_pose(), 1.0)
		Stage.OPEN:
			_ease(1.0)
			if stage_time >= (tuning.bite_hold if kind == Kind.BITE else tuning.breach_hold):
				_go(Stage.SNAPPING, _snap_pose(), tuning.bite_snap)
				boss.sound(&"guppy_bite", hinge + Vector3(0.0, jaw_length() * 0.6, 0.0))
		Stage.SNAPPING:
			_ease(stage_time / _stage_seconds)
			if stage_time >= _stage_seconds:
				if kind == Kind.BITE and on_snap.is_valid():
					on_snap.call(action)
				boss.log_event(&"bite" if kind == Kind.BITE else &"breach_snap",
					{"roof": int(action.get("roof", -1)), "at": float(action.get("at", action.get("edge", 0.0)))})
				_go(Stage.SINKING, _deep_pose(), tuning.bite_sink)
		Stage.SINKING:
			_ease(stage_time / _stage_seconds)
			if stage_time >= _stage_seconds:
				stage = Stage.IDLE
				action = {}
				_head.visible = false
	_apply()


func _begin(spot: Dictionary) -> void:
	var kind: int = int(spot["kind"])
	var was_idle: bool = stage == Stage.IDLE
	action = spot
	var below: Dictionary = _below_pose()
	if was_idle:
		# Out of sight far below its spot, to come up from.
		var start: Dictionary = below.duplicate()
		var b: Vector3 = below["hinge"]
		start["hinge"] = Vector3(b.x, float(action["top"]) - DEEP, b.z)
		_appear(start)
	var rise: float = tuning.bite_warning
	if kind == Kind.BREACH:
		rise = maxf(float(action["open_at"]) - boss.bombs.clock - tuning.breach_rise - 0.02, MIN_RISE)
		breaches += 1
		boss.log_event(&"breach_warning", {"at": float(action["at"]), "x": float(action["x"])})
	else:
		bites += 1
		boss.log_event(&"bite_warning", {"roof": int(action.get("roof", -1)), "edge": float(action.get("edge", 0.0))})
	boss.sound(&"guppy_rumble", below["hinge"] as Vector3 + Vector3(0.0, jaw_length(), 0.0))
	_go(Stage.RISING, below, rise)


## Shows it at `pose` (from out of sight).
func _appear(pose: Dictionary) -> void:
	hinge = pose["hinge"]
	pitch = float(pose["pitch"])
	roll = float(pose["roll"])
	yaw = float(pose["yaw"])
	jaw = float(pose["jaw"])
	_head.visible = true
	_apply()


## The world z its hinge comes up at: a bite's in the middle of the roof's end it eats, a breach's at the bomb.
func _z() -> float:
	if int(action["kind"]) == Kind.BITE:
		return TrackGeometry.world_z((float(action["edge"]) + float(action.get("cut", action["edge"]))) * 0.5)
	return TrackGeometry.world_z(float(action["at"]))


## Where a breach's hinge must be (world x) for a bomb at world x `x` to fall into its jaws, the shark beside the lanes on
## `side`: MOUTH_OUT further in than the bomb.
static func hinge_x(x: float, side: int) -> float:
	return x - side * MOUTH_OUT


## Its open pose for this action. A bite: beside the track's side on its side, its chin toward the track (dropping wide
## across the roof's end as it opens), leaning in over it, its open chin's tip above the roof. A breach: beside the lanes
## that don't lead up, its chin outward (its snout and an eye toward the runner), its eyes just over the floor's level,
## the bomb's point between its jaws.
func _open_pose() -> Dictionary:
	var top: float = float(action["top"])
	var side: float = float(action.get("side", -1))
	if int(action["kind"]) == Kind.BITE:
		var x: float = side * (world.geo.wall_x() + BITE_OUT)
		return {"hinge": Vector3(x, top - BITE_SINK, _z()), "pitch": 0.0, "yaw": -side * PI * 0.5,
			"roll": side * deg_to_rad(BITE_LEAN), "jaw": 1.0}
	return {"hinge": Vector3(hinge_x(float(action["x"]), int(side)), top - BREACH_SINK, _z()), "pitch": 0.0,
		"yaw": side * PI * 0.5, "roll": 0.0, "jaw": 1.0}


## Under the floor's level, jaws all but shut (the warning), where it will break through.
func _below_pose() -> Dictionary:
	var open: Dictionary = _open_pose()
	var h: Vector3 = open["hinge"]
	var drop: float = (h.y + jaw_length()) - (float(action["top"]) - BELOW_TIPS)
	var out: Dictionary = open.duplicate()
	out["hinge"] = h - Vector3(0.0, maxf(drop, 0.0), 0.0)
	out["jaw"] = 0.12
	return out


## Deep under the middle of the chasm where a breach will come, turned as it will come up.
func _lurk_pose() -> Dictionary:
	var below: Dictionary = _below_pose()
	var b: Vector3 = below["hinge"]
	below["hinge"] = Vector3(0.0, float(action["top"]) - LURK_DEPTH, b.z)
	below["jaw"] = 0.0
	return below


func _snap_pose() -> Dictionary:
	var open: Dictionary = _open_pose()
	var out: Dictionary = open.duplicate()
	out["jaw"] = 0.0
	if int(action["kind"]) == Kind.BITE:
		var side: float = float(action.get("side", -1))
		out["hinge"] = (open["hinge"] as Vector3) - Vector3(side * SNAP_IN, 0.6, 0.0)
		out["roll"] = side * deg_to_rad(SNAP_LEAN)
	else:
		out["hinge"] = (open["hinge"] as Vector3) + Vector3(0.0, 0.6, 0.0)
	return out


func _deep_pose() -> Dictionary:
	return {"hinge": Vector3(hinge.x, float(action.get("top", hinge.y + DEEP)) - DEEP, hinge.z), "pitch": 0.0, "roll": 0.0,
		"yaw": yaw, "jaw": 0.0}


func _go(next: Stage, to: Dictionary, seconds: float) -> void:
	stage = next
	stage_time = 0.0
	_stage_seconds = maxf(seconds, 0.02)
	_from = {"hinge": hinge, "pitch": pitch, "roll": roll, "yaw": yaw, "jaw": jaw}
	_to = to


## True once the jaws may come up: a bite waits for nobody to be on its roof (may_break); a breach comes up just in time
## to be open when the bomb lands (open_at, less the rise).
func _may_break() -> bool:
	if int(action["kind"]) == Kind.BITE:
		var check: Callable = action.get("may_break", Callable())
		return not check.is_valid() or bool(check.call())
	return boss.bombs.clock >= float(action["open_at"]) - tuning.breach_rise - 0.02


## Eases its pose from the stage's start to its target, `k` of the way (0-1).
func _ease(k: float) -> void:
	var t: float = clampf(k, 0.0, 1.0)
	t = t * t * (3.0 - 2.0 * t)
	hinge = (_from["hinge"] as Vector3).lerp(_to["hinge"], t)
	pitch = lerpf(float(_from["pitch"]), float(_to["pitch"]), t)
	roll = lerpf(float(_from["roll"]), float(_to["roll"]), t)
	yaw = lerp_angle(float(_from["yaw"]), float(_to["yaw"]), t)
	jaw = lerpf(float(_from["jaw"]), float(_to["jaw"]), t)


func _apply() -> void:
	var wobble: float = 0.0
	if _shudder > 0.0:
		wobble = deg_to_rad(SHUDDER_DEGREES) * (_shudder / SHUDDER_SECONDS) * sin((SHUDDER_SECONDS - _shudder) * 38.0)
	var basis := (Basis(Vector3.BACK, roll + wobble) * Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)).scaled_local(
		Vector3.ONE * SCALE)
	_head.global_transform = Transform3D(basis, hinge)
	# The snout (z < 0) tips back a little, the chin (z > 0) drops wide toward the runner.
	_upper.transform = Transform3D(Basis(Vector3.RIGHT, -deg_to_rad(MechaGuppySharkModel.UPPER_OPEN) * jaw), Vector3.ZERO)
	_lower.transform = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(MechaGuppySharkModel.LOWER_OPEN) * jaw), Vector3.ZERO)
