class_name MechaGuppyShark
extends Node3D
## Mecha Guppy (GDD §10: "a giant mechanical shark, gigantic, the size of a building ... Its maw comes up through the
## floor and eats a huge chunk of the level. It can be seen ahead of the runner and behind them ... the player will
## mostly only ever see its giant jaws and its eyes"; task E5e-b2). Its look is MechaGuppySharkModel's, scaled up
## (SCALE); it has no hitbox at all: it hurts nobody (a wrong drop dies of its fall, as before), and nothing on it glows.
## It lurks far down the chasm, out of sight, and comes up when MechaGuppy's pattern asks it (MechaGuppyPattern), always
## side-on to the runner, so they see it in profile: its jaws, its teeth and an eye. Wherever a rider could be (under a
## hut, in a lane that leads up), its jaws keep well clear of them: nothing on it ever looks like it reaches a rider.
## - bite(): it eats the floor the runner should have left. The warning first: the rumble (guppy_rumble), and the shark
##   surging up out of the chasm beside the roof's end it will eat, upright, its jaws shut and an eye just over the
##   roof's top (bite_warning: the runner sees it ahead as they near the roof's pads). It waits there until nobody can
##   be on that roof any more (may_break: the runner up on the hut). Then it dives under the roof's top, leaning in
##   with its jaws open (bite_dive), and lunges up beside the roof's end with its chin low across the roof (bite_rise:
##   its chin never higher than BITE_CLEAR under a rider on the hut), stays open (bite_hold), and snaps shut, dropping
##   away with the roof's end in its jaws (bite_snap, guppy_bite; it drops SNAP_DROP first and closes late, so its
##   closing chin stays as low): at the
##   snap the roof's end is gone (on_snap: MechaGuppyStairs.eat_roof, collision and look together, rubble flying).
##   Then it sinks (bite_sink). A bite starts only once it has sunk out of sight from the last (MechaGuppyPattern waits
##   for it), from deep under its own spot.
## - a bite with a catch (task E5e-b3, the bait; GDD §10: a bomb dodged where the runner's lane runs out falls past the
##   edge into Mecha Guppy's jaws): instead of its upright watch, it surges up (the rumble) into its catch beside the
##   roof's notch (MechaGuppyClimb.Roof.notch_lane) as the bait begins, and waits there with its jaws wide: its head out
##   beside the track, leaning in CATCH_LEAN so its lower jaw lies flat under the notch's lane, a little under the roof's
##   top, its tip CATCH_CLEAR short of the next lane (never under or over a lane a runner may use, nor where the notch's
##   lane still has floor), its snout raised outside the track, an eye toward the runner: the bait's bomb, coming down
##   in the notch's lane, falls into its open mouth as it passes the roof's top (a hit: hit(), which snaps its jaws shut
##   on it with a shudder). Once the bomb is down (catch_until) or the runner falls, it shuts its jaws and waits, then
##   bites the roof's end as above once the runner is up on the hut.
## - lurk() then breach() (the fallback, MechaGuppyPattern: Captain Cogs missing into the chasm): it glides deep under
##   the middle of the chasm in front of the higher roof, out of sight (lurk: nothing of it shows, so nothing tells a
##   rider which lanes lead up); when Captain Cogs throws there, it surges up beside the lanes that don't lead up (its
##   head kept lane_clear from the lanes that do), side-on, its snout and an eye toward the runner, and opens its jaws
##   outward breach_early before the bomb comes down into them (held breach_hold): a bomb that falls into its open jaws
##   hits it (mouth_contains; MechaGuppyBombs calls hit()): a clang, a fireball, sparks and smoke where it went in, a
##   shudder, and it recoils, snapping shut and sinking at once.
## - the leap (task E5e-c, the defeat; MechaGuppyLeap drives it): hold() takes it out of its stages, and pose_free() sets
##   its head's transform and jaws directly, frame by frame (it bursts up under Captain Cogs' ship, gulps, falls back and
##   swims away). Nothing of it has a hitbox then either.
## - floor_bite() (task E5e-f; GDD §10, the owner, October 11, 2026: "The floor bite"; MechaGuppyPattern times it,
##   MechaGuppyFloorBite shows its warning and makes its snap): it bites a crescent out of the roof the runner is still
##   running on. Its warning: the rumble, and the shark surging up into its watch beside the roof's side at the bite
##   (floor_rise), upright, its snout towering over the deck and an eye just over it (its snout and teeth at the roof's
##   side). Once the runner reaches the bite's lunge point it dives under the deck leaning in with its jaws opening
##   (bite_dive) and bursts up through the floor over the crescent (bite_rise), its lower jaw flat across it with its teeth
##   through the deck, its tip FLOOR_CLEAR short of the lane the bite leaves (no part of its jaws ever over that lane),
##   its snout raised over the bitten lanes; it holds (at least bite_hold, until the runner reaches the bite's snap point)
##   and snaps shut (bite_snap, guppy_bite), dropping FLOOR_DROP with the chunk (on_snap: the floor goes), its jaws under
##   the deck from then on, then sinks. It has no hitbox of its own (the snap's is MechaGuppyFloorBite's) and no bomb
##   counts in its jaws then (mouth_contains). It may start from a sink already all under the floor, as a breach may.
## Its pose (hinge, pitch, yaw, roll, jaw) is always eased from the one before, so it never pops while it can be seen.
## advance() is driven by the boss's ticks (time from the physics step; it waits while the runner is down). Nothing
## flickers (Reduced flashing has nothing to calm; the hit's fireball and sparks are RunEffects', which honour it).
## DESIGN-TBD (docs/questions/e5e.md): its size, poses and timings (MechaGuppyTuning, "Mecha Guppy's bites").

enum Kind { BITE, BREACH, FLOOR }
enum Stage { IDLE, LURKING, RISING, CATCHING, SHUTTING, WAITING, DIVING, BREAKING, OPEN, SNAPPING, SINKING }

## How big it is (MechaGuppySharkModel's metres times this): its jaws 12 m long, its head 12.6 m across.
const SCALE: float = 1.5
## How far below the floor it sinks between bites and lurks before a breach, out of sight (metres, its hinge).
const DEEP: float = 55.0
## A breach's surge from the lurk is never quicker than this (seconds).
const MIN_RISE: float = 0.12
## A breach rising toward the floor: its jaws' tips this far under the floor's level (metres).
const BELOW_TIPS: float = 2.5
## A bite's sink has taken its jaws BELOW_TIPS under the floor (a breach may come up) by about a fifth of its way down;
## this share of it, with room to spare, counts toward how long a bite keeps it busy (bite_seconds).
const SINK_CLEAR: float = 0.35
## A bite: its head's inner side this far out past the track's edge (clear of the roofs' eaves and the huts'), its hinge
## this far under the roof's top as it watches (its eye just over it), dives (out of sight of the track) and bites, and
## its lean in over the roof as it dives and bites (degrees); at the snap it drops this far, dragging the roof's end
## down (metres). Its jaws never come within BITE_CLEAR under a rider hanging from the hut, even mid-jump (their head
## down to the hut's underside less MovementTuning.jump_height and visual_size.y; the climb puts the hut hut_height
## over the roof).
const BITE_GAP: float = 2.2
const WATCH_SINK: float = 2.0
const DIVE_SINK: float = 12.0
const BITE_SINK: float = 4.0
const BITE_LEAN: float = 12.0
const SNAP_DROP: float = 7.0
const BITE_CLEAR: float = 2.5
## A breach: its hinge this far under the floor's level (its eyes just over it); the bomb falls in this far out from its
## hinge's line (metres: between its palate and its dropped chin); hit, it recoils down this far as it snaps shut
## (metres). (Its head's clearance from the lanes that lead up and how early its jaws open: MechaGuppyTuning.lane_clear,
## breach_early.)
const BREACH_SINK: float = 2.0
const MOUTH_OUT: float = 1.0
const RECOIL: float = 2.5
## A catch (the bait): its lean in toward the track (degrees: its lower jaw, opened LOWER_OPEN, lies flat), its lower
## jaw's tip this far short of the lane beside the notch's (metres), the top of its open mouth over the notch's lane this
## far above where the bomb comes down (metres: the bomb goes in as it passes the roof's top), and how long its jaws stay
## open after the bomb is down (seconds).
const CATCH_LEAN: float = 90.0 - MechaGuppySharkModel.LOWER_OPEN
const CATCH_CLEAR: float = 0.4
const CATCH_ABOVE: float = 1.0
const CATCH_AFTER: float = 0.15
## Its jaws shut, it settles this far lower to wait for its bite (metres: its closed head, still leaning in, keeps well
## under the hut ahead).
const CATCH_SETTLE: float = 4.0
## A bomb comes down this far over the floor's top (MechaGuppyBombs' lob ends there).
const LAND_ABOVE: float = 0.35
## Where a bomb counts as in its mouth: up to this share of its jaws' length from the hinge (mouth_contains).
const MOUTH_REACH: float = 1.05
## A bite after a catch dives from its catch to its bite no faster than this along the track (m/s).
const DIVE_SPEED: float = 40.0
## The hit: its shudder (degrees, seconds), the fireball's radius where the bomb went in, the sparks' and smoke's colours.
const SHUDDER_DEGREES: float = 7.0
const SHUDDER_SECONDS: float = 0.6
const HIT_FIRE: float = 2.2
const SPARK_COLOR := Color(1.0, 0.78, 0.35)
const SMOKE_COLOR := Color(0.32, 0.31, 0.3)
## A bomb counts as in its jaws while they're at least this open (0-1).
const OPEN_ENOUGH: float = 0.55
## A floor bite (task E5e-f): its lower jaw's tip this far short of the lane the bite leaves (metres; the far wall on a
## full-width bite), the mouth's floor this far under the deck as its jaws burst up (its teeth stand through the deck),
## leaning in so its lower jaw lies flat across the crescent, and at the snap it drops this far with the chunk (metres:
## its shut jaws, still leaning in, end under the deck).
const FLOOR_CLEAR: float = 0.4
const FLOOR_SINK: float = 0.4
const FLOOR_LEAN: float = 90.0 - MechaGuppySharkModel.LOWER_OPEN
const FLOOR_DROP: float = 10.5

## Called with the action as a bite's jaws snap shut (MechaGuppyPattern.on_snap eats the roof).
var on_snap: Callable
var tuning: MechaGuppyTuning
var world: RunWorld
var boss: MechaGuppy
## The action under way: {kind, side (-1 it comes up on the left, +1 the right), top (the floor's level it comes up to),
## a bite's edge, roof, cut, may_break, may_bite and catch ({inner, lane_x, at, top, until, step}: catch_pose; or empty), a
## breach's x (the bomb's world x), at (its track distance), open_at (bomb clock) and step (the climb's step it's for)};
## empty while idle.
var action: Dictionary = {}
var stage: Stage = Stage.IDLE
var stage_time: float = 0.0
## Bites and breaches made, catches waited in, hits taken, bites asked for while it was busy, bites that gave way to a
## fallback (tests).
var bites: int = 0
var breaches: int = 0
var catches: int = 0
var hits: int = 0
var skipped: int = 0
var yielded: int = 0
## Floor bites made (task E5e-f; tests).
var floors: int = 0
## How open its jaws are (0 shut, 1 wide), and its pose: the hinge's world position, then (applied in this order) pitch
## (radians about its own x: +PI/2 lays its jaws flat toward +z, its snout up), yaw (about the vertical: which way its
## jaws or chin face) and roll (about the track: its jaws toward -x when positive).
var jaw: float = 0.0
var hinge := Vector3(0.0, -DEEP, 0.0)
var pitch: float = 0.0
var roll: float = 0.0
var yaw: float = 0.0
## Held out of its stages (the leap, MechaGuppyLeap: pose_free sets its pose).
var held: bool = false

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


## True while it's doing nothing.
func idle() -> bool:
	return stage == Stage.IDLE


## True while a bite or breach is under way, until it has sunk back out of sight (a new one starts from deep under its
## own spot, so it never sweeps across the track on its way there).
func busy() -> bool:
	return stage != Stage.IDLE and stage != Stage.LURKING


## True while it can be seen (up out of the deep, or lurking).
func shown() -> bool:
	return _head.visible


## A bite (see the header): `spot` {side (-1 it comes up left of the track, +1 right), edge (the roof's eaten edge: track
## distance), top (the roof's top), roof (its index), cut (where it eats the roof back to), may_break (Callable: true once
## nobody can be on that roof), may_bite (optional Callable(seconds: float) -> bool: false makes the bite give way, the
## shark sinking off uneaten), catch (optional: the bait's catch first, {inner (world x of the notch's inner edge),
## lane_x (the notch's lane's middle), at (where the bait's bomb comes down: track distance), top (that roof's top), until
## (bomb clock: its jaws open until then; INF until the bomb is thrown), step}; `side` is then the notch's)}. Its warning
## starts now. False (nothing done, logged as skipped) while it's busy.
func bite(spot: Dictionary) -> bool:
	if busy():
		skipped += 1
		boss.log_event(&"bite_skipped", {"roof": int(spot.get("roof", -1))})
		return false
	var next: Dictionary = spot.duplicate()
	next["kind"] = Kind.BITE
	_begin(next)
	return true


## The bait's bomb is thrown (MechaGuppyPattern): a catch keeps its jaws open until bomb clock `until` (the bomb's
## landing and CATCH_AFTER).
func catch_until(until: float) -> void:
	if _has_catch():
		(action["catch"] as Dictionary)["until"] = until


## Glides deep under where a breach will come (`spot` as breach()'s), out of sight (nothing of it shows: it gives nothing
## away); only while it's free.
func lurk(spot: Dictionary) -> void:
	if busy():
		return
	action = spot.duplicate()
	action["kind"] = Kind.BREACH
	if stage == Stage.IDLE:
		_appear(_lurk_pose())
	_head.visible = false
	_go(Stage.LURKING, _lurk_pose(), tuning.lurk_seconds)


## A breach (see the header): `spot` {x (where the bomb falls in: world x), at (track distance), top (the floor's level
## beside it), side (-1 left of the lanes that lead up, +1 right), open_at (bomb clock: its jaws wide open by then)}.
## From its lurk it surges up just in time; from anywhere else, as fast as it must. False while it's busy.
## hinge_x() gives where its hinge must be for the bomb to fall into its jaws at `x`.
func breach(spot: Dictionary) -> bool:
	if not can_breach(float(spot["top"])):
		boss.log_event(&"breach_skipped", {"at": float(spot.get("at", 0.0))})
		return false
	var next: Dictionary = spot.duplicate()
	next["kind"] = Kind.BREACH
	_begin(next)
	return true


## True if a breach beside a floor at `top` may start now: it's free (idle or lurking), or sinking and already all under
## that floor (_sunk_under).
func can_breach(top: float) -> bool:
	return not busy() or (stage == Stage.SINKING and _sunk_under(top))


## A floor bite (see the header): `spot` {side (the side it bites from), top (the roof's top), roof (its index), at (the
## bite's middle: track distance), bite (MechaGuppyCrescent), lunge_at (where the runner is as it lunges), snap_at (where
## they are as its jaws have shut)}. Its warning (the rumble, the rise into its watch) starts now. False (nothing done)
## unless it may start (can_breach's rule: free, or sinking already all under the floor).
func floor_bite(spot: Dictionary) -> bool:
	if not can_breach(float(spot["top"])):
		return false
	var next: Dictionary = spot.duplicate()
	next["kind"] = Kind.FLOOR
	_begin(next)
	return true


## True while a floor bite is under way and hasn't snapped yet.
func floor_pending() -> bool:
	return not action.is_empty() and int(action["kind"]) == Kind.FLOOR \
		and stage in [Stage.RISING, Stage.WAITING, Stage.DIVING, Stage.BREAKING, Stage.OPEN]


## A floor bite called off before its snap (the attacks stopped): it sinks away, nothing bitten.
func abort_floor() -> void:
	if floor_pending():
		_go(Stage.SINKING, _deep_pose(), tuning.bite_sink)


## How long a bite takes from now, once its runner is up on the hut, until a breach may come up again (can_breach):
## the dive (from a catch no faster than DIVE_SPEED along the track), the lunge, the hold, the snap and SINK_CLEAR of
## the sink.
func bite_seconds() -> float:
	return _dive_seconds() + tuning.bite_rise + tuning.bite_hold + tuning.bite_snap + tuning.bite_sink * SINK_CLEAR


## True while all of it is far enough under the floor at `top` and under the one it sank from (BELOW_TIPS): a breach may
## come up from there while it's still sinking, its way up all under the floor's level.
func _sunk_under(top: float) -> bool:
	var floor_y: float = minf(top, float(action.get("top", top)))
	return jaws_over(-INF, INF) < floor_y - BELOW_TIPS


## True while a bomb at world point `p` is inside its open jaws: they're at least OPEN_ENOUGH open, and `p` (in its head's
## own space) between them: up its jaws, inside their width there, in front of the snout's palate and over the chin's.
func mouth_contains(p: Vector3) -> bool:
	if action.is_empty() or jaw < OPEN_ENOUGH or (stage != Stage.BREAKING and stage != Stage.OPEN and stage != Stage.SNAPPING
			and stage != Stage.CATCHING):
		return false
	# A floor bite's jaws aren't a target (task E5e-f: only a bomb baited or missed into the chasm hurts it).
	if int(action["kind"]) == Kind.FLOOR:
		return false
	var local: Vector3 = _head.global_transform.affine_inverse() * p
	var u: float = local.y / MechaGuppySharkModel.JAW_LENGTH
	if u < 0.12 or u > MOUTH_REACH:
		return false
	var half: float = MechaGuppySharkModel.jaw_size(u).x * 0.95 + 0.15
	if absf(local.x) > half:
		return false
	var z_lo: float = -local.y * tan(deg_to_rad(MechaGuppySharkModel.UPPER_OPEN) * jaw) - 0.25
	var z_hi: float = local.y * tan(deg_to_rad(MechaGuppySharkModel.LOWER_OPEN) * jaw) + 0.25
	return local.z >= z_lo and local.z <= z_hi


## A bomb went into its jaws at world point `p` (MechaGuppyBombs): the clang, a fireball, sparks and smoke there, a
## shudder, a shake; a breach recoils, snapping shut and sinking at once; a catch snaps its jaws shut on it.
func hit(p: Vector3) -> void:
	hits += 1
	_shudder = SHUDDER_SECONDS
	world.effects.fireball(p, HIT_FIRE, true, 1.2, 0.6)
	world.effects.burst(p + Vector3(0.0, 0.6, 0.0), SPARK_COLOR, 32, 1.0)
	world.effects.debris(p + Vector3(0.0, 0.4, 0.0), SMOKE_COLOR, 10, 1.0)
	var near: float = clampf(1.0 - absf(-p.z - world.player.distance) / 40.0, 0.25, 1.0)
	world.effects.shake(0.35 * near, 0.35)
	boss.sound(&"guppy_clang", p)
	if not action.is_empty() and int(action["kind"]) == Kind.BREACH and (stage == Stage.BREAKING or stage == Stage.OPEN):
		_go(Stage.SNAPPING, _snap_pose(), tuning.bite_snap)
	elif stage == Stage.CATCHING:
		_go(Stage.SHUTTING, catch_pose(0.0, true), tuning.bite_snap)


## Takes it out of its stages (on: the leap drives it with pose_free, whatever it was doing; off: idle, out of sight).
func hold(on: bool) -> void:
	held = on
	stage = Stage.IDLE
	action = {}
	if not on:
		_head.visible = false


## The leap's pose (held): its hinge at world point `p_hinge`, its head turned by `basis` (unscaled: SCALE is applied),
## its jaws `open` (0 shut, 1 wide), shown or not.
func pose_free(p_hinge: Vector3, basis: Basis, open: float, shown_now: bool = true) -> void:
	hinge = p_hinge
	jaw = open
	_head.visible = shown_now
	var wobble: float = 0.0
	if _shudder > 0.0:
		wobble = deg_to_rad(SHUDDER_DEGREES) * (_shudder / SHUDDER_SECONDS) * sin((SHUDDER_SECONDS - _shudder) * 38.0)
	_head.global_transform = Transform3D((Basis(Vector3.BACK, wobble) * basis).scaled_local(Vector3.ONE * SCALE), hinge)
	_upper.transform = Transform3D(Basis(Vector3.RIGHT, -deg_to_rad(MechaGuppySharkModel.UPPER_OPEN) * jaw), Vector3.ZERO)
	_lower.transform = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(MechaGuppySharkModel.LOWER_OPEN) * jaw), Vector3.ZERO)


## Its head's transform in the world (its model's space, scaled: the leap finds its snout and tail by it).
func head_transform() -> Transform3D:
	return _head.global_transform


## Points down its whole length in the world while it shows (tests: where its body reaches): the snout's tip, the hinge,
## along the body and the tail's end; none while it's out of sight.
func body_points() -> PackedVector3Array:
	var out := PackedVector3Array()
	if not _head.visible:
		return out
	var xf: Transform3D = _head.global_transform
	var end: float = MechaGuppySharkModel.BODY_LENGTH + MechaGuppySharkModel.TAIL_STALK + MechaGuppySharkModel.TAIL_FIN
	for y: float in [MechaGuppySharkModel.JAW_LENGTH, 0.0, -10.0, -20.0, -30.0, -MechaGuppySharkModel.BODY_LENGTH, -end]:
		out.append(xf * Vector3(0.0, y, 0.0))
	return out


## A shudder (the gulp's: the leap).
func shudder() -> void:
	_shudder = SHUDDER_SECONDS


## One physics step (the boss's ticks drive it).
func advance(delta: float) -> void:
	_shudder = maxf(_shudder - delta, 0.0)
	if held or stage == Stage.IDLE:
		return
	stage_time += delta
	var kind: int = int(action.get("kind", Kind.BITE))
	match stage:
		Stage.LURKING:
			_ease(stage_time / _stage_seconds)
		Stage.RISING:
			_ease(stage_time / _stage_seconds)
			if stage_time >= _stage_seconds:
				if _has_catch():
					catches += 1
					boss.log_event(&"catch_open", {"roof": int(action.get("roof", -1)),
						"at": float((action["catch"] as Dictionary)["at"])})
					_go(Stage.CATCHING, catch_pose(1.0), 1.0)
				else:
					_go(Stage.WAITING, _rise_pose(), 1.0)
		Stage.CATCHING:
			_ease(1.0)
			var c: Dictionary = action["catch"]
			var fell: bool = boss.pattern != null and not boss.pattern.catch_ok()
			if boss.bombs.clock >= float(c["until"]) or _may_break() or fell:
				_go(Stage.SHUTTING, catch_pose(0.0, true), tuning.bite_snap * (1.0 if fell else 2.0))
		Stage.SHUTTING:
			_ease(stage_time / _stage_seconds)
			if stage_time >= _stage_seconds:
				_go(Stage.WAITING, catch_pose(0.0, true), 1.0)
		Stage.WAITING:
			_ease(1.0)
			if _may_break():
				if kind == Kind.BITE and _yields():
					# A fallback is due that its bite would leave no time for (MechaGuppyPattern._bite_fits): it sinks away
					# uneaten, so it's free to rise for the fallback.
					yielded += 1
					boss.log_event(&"bite_yielded", {"roof": int(action.get("roof", -1))})
					_go(Stage.SINKING, _deep_pose(), tuning.bite_sink)
				elif kind == Kind.BITE or kind == Kind.FLOOR:
					_go(Stage.DIVING, _dive_pose(), _dive_seconds())
				else:
					_go(Stage.BREAKING, _open_pose(), tuning.breach_rise)
		Stage.DIVING:
			_ease(stage_time / _stage_seconds, true)
			if stage_time >= _stage_seconds:
				_go(Stage.BREAKING, _open_pose(), tuning.bite_rise)
		Stage.BREAKING:
			_ease(stage_time / _stage_seconds)
			if stage_time >= _stage_seconds:
				_go(Stage.OPEN, _open_pose(), 1.0)
		Stage.OPEN:
			_ease(1.0)
			# A breach shuts at once on a step the runner fell (no hit then: MechaGuppyPattern.catch_ok).
			var no_catch: bool = kind == Kind.BREACH and boss.pattern != null and not boss.pattern.catch_ok()
			var shut: bool = stage_time >= (tuning.breach_hold if kind == Kind.BREACH else tuning.bite_hold) or no_catch
			# A floor bite holds until its jaws, shutting, have shut as the runner reaches its snap point.
			if kind == Kind.FLOOR:
				shut = shut and world.player.distance >= float(action["snap_at"]) - tuning.bite_snap * maxf(world.player.speed, 1.0)
			if shut:
				_go(Stage.SNAPPING, _snap_pose(), tuning.bite_snap)
				boss.sound(&"guppy_bite", _mouth_point())
		Stage.SNAPPING:
			# A bite's snap drops away first and closes late, so its closing chin never comes up toward a rider on the hut.
			_ease(stage_time / _stage_seconds, kind == Kind.BITE)
			if stage_time >= _stage_seconds:
				if kind != Kind.BREACH and on_snap.is_valid():
					on_snap.call(action)
				if kind != Kind.FLOOR:
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
	var rise_to: Dictionary = _rise_pose()
	if was_idle:
		# Out of sight far below its spot, to come up from.
		var start: Dictionary = rise_to.duplicate()
		var b: Vector3 = rise_to["hinge"]
		start["hinge"] = Vector3(b.x, float(action["top"]) - DEEP, b.z)
		_appear(start)
	_head.visible = true
	var rise: float = tuning.bite_warning
	if kind == Kind.BREACH:
		rise = maxf(float(action["open_at"]) - boss.bombs.clock - tuning.breach_rise - 0.02, MIN_RISE)
		breaches += 1
		boss.log_event(&"breach_warning", {"at": float(action["at"]), "x": float(action["x"])})
	elif kind == Kind.FLOOR:
		rise = tuning.floor_rise
		floors += 1
		boss.log_event(&"floor_bite_rise", {"roof": int(action.get("roof", -1)), "side": int(action.get("side", -1))})
	else:
		bites += 1
		boss.log_event(&"bite_warning", {"roof": int(action.get("roof", -1)), "edge": float(action.get("edge", 0.0))})
	boss.sound(&"guppy_rumble", rise_to["hinge"] as Vector3 + Vector3(0.0, jaw_length() * 0.5, 0.0))
	_go(Stage.RISING, rise_to, rise)


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


## A bite's hinge (world x): beside the track on its side, its head's inner side BITE_GAP out past the track's edge.
func _bite_x() -> float:
	var side: float = float(action.get("side", -1))
	return side * (world.geo.wall_x() + BITE_GAP + MechaGuppySharkModel.HALF_DEPTH * SCALE)


## The pose it comes up to first: a bite's watch (upright beside the roof's end, its chin toward the track, jaws shut, an
## eye just over the roof's top), or with a catch its catch (catch_pose, its jaws opening as it comes); a breach's
## (under the floor's level, jaws all but shut, where it will break through).
func _rise_pose() -> Dictionary:
	var top: float = float(action["top"])
	if _has_catch():
		return catch_pose(1.0)
	if int(action["kind"]) == Kind.BITE or int(action["kind"]) == Kind.FLOOR:
		var side: float = float(action.get("side", -1))
		return {"hinge": Vector3(_bite_x(), top - WATCH_SINK, _z()), "pitch": 0.0, "yaw": -side * PI * 0.5, "roll": 0.0,
			"jaw": 0.12}
	var open: Dictionary = _open_pose()
	var h: Vector3 = open["hinge"]
	var drop: float = (h.y + jaw_length()) - (top - BELOW_TIPS)
	var out: Dictionary = open.duplicate()
	out["hinge"] = h - Vector3(0.0, maxf(drop, 0.0), 0.0)
	out["jaw"] = 0.12
	return out


## A bite's dive: under the roof's top beside it, leaning in, its jaws open, ready to lunge (nothing over the track); a floor
## bite's under the deck where its jaws will burst up.
func _dive_pose() -> Dictionary:
	var open: Dictionary = _open_pose()
	var out: Dictionary = open.duplicate()
	var x: float = (open["hinge"] as Vector3).x if int(action["kind"]) == Kind.FLOOR else _bite_x()
	out["hinge"] = Vector3(x, float(action["top"]) - DIVE_SINK, _z())
	return out


## Its open pose for this action. A bite: beside the track, its chin toward it and low across the roof's end, leaning
## in. A breach: beside the lanes that don't lead up, its chin outward (its snout and an eye toward the runner), its eyes
## just over the floor's level, the bomb's point between its jaws.
func _open_pose() -> Dictionary:
	var top: float = float(action["top"])
	var side: float = float(action.get("side", -1))
	if int(action["kind"]) == Kind.BITE:
		return {"hinge": Vector3(_bite_x(), top - BITE_SINK, _z()), "pitch": 0.0, "yaw": -side * PI * 0.5,
			"roll": side * deg_to_rad(BITE_LEAN), "jaw": 1.0}
	if int(action["kind"]) == Kind.FLOOR:
		return {"hinge": Vector3(floor_hinge_x(action["bite"] as MechaGuppyCrescent), top - FLOOR_SINK, _z()), "pitch": 0.0,
			"yaw": -side * PI * 0.5, "roll": side * deg_to_rad(FLOOR_LEAN), "jaw": 1.0}
	return {"hinge": Vector3(hinge_x(float(action["x"]), int(side)), top - BREACH_SINK, _z()), "pitch": 0.0,
		"yaw": side * PI * 0.5, "roll": 0.0, "jaw": 1.0}


## Deep under the middle of the chasm where a breach will come, facing the runner (out of sight: lurk() hides it).
func _lurk_pose() -> Dictionary:
	return {"hinge": Vector3(0.0, float(action["top"]) - DEEP, _z()), "pitch": 0.0, "yaw": 0.0, "roll": 0.0, "jaw": 0.0}


## True while the action is a bite with a catch first (the bait).
func _has_catch() -> bool:
	return not action.is_empty() and int(action["kind"]) == Kind.BITE and not (action.get("catch", {}) as Dictionary).is_empty()


## Its catch beside the bait's notch, its jaws `open` (0 shut, 1 wide): its head out beside the track on the notch's side,
## leaning in CATCH_LEAN so its lower jaw, wide open, lies flat toward the track with its tip CATCH_CLEAR short of the
## lane beside the notch's; the top of its open mouth over the notch's lane CATCH_ABOVE over where the bomb comes down
## (its hinge a few metres under the roof's top: nothing of its jaws over the roof), its snout raised outside the track.
## `settled`: CATCH_SETTLE lower (shut, waiting for its bite).
func catch_pose(open: float, settled: bool = false) -> Dictionary:
	var c: Dictionary = action["catch"]
	var side: float = float(action.get("side", -1))
	var reach: float = (MechaGuppySharkModel.JAW_LENGTH + MechaGuppySharkModel.TIP_CAP) * SCALE
	var tip_x: float = float(c["inner"]) + side * CATCH_CLEAR
	var hinge_x: float = tip_x + side * reach
	var lean: float = deg_to_rad(CATCH_LEAN)
	# Where the bomb's column meets the top of its mouth (mouth_contains: up to MOUTH_REACH of its jaws' length).
	var h: float = absf(float(c["lane_x"]) - hinge_x)
	var v_top: float = (MOUTH_REACH * MechaGuppySharkModel.JAW_LENGTH * SCALE - h * sin(lean)) / cos(lean)
	var hinge_y: float = float(c["top"]) + LAND_ABOVE + CATCH_ABOVE - v_top - (CATCH_SETTLE if settled else 0.0)
	return {"hinge": Vector3(hinge_x, hinge_y, TrackGeometry.world_z(float(c["at"]))), "pitch": 0.0, "yaw": -side * PI * 0.5,
		"roll": side * lean, "jaw": open}


## A bite's dive after a catch: no faster along the track than DIVE_SPEED (from the catch to the bite).
func _dive_seconds() -> float:
	if not _has_catch():
		return tuning.bite_dive
	var dz: float = absf(hinge.z - _z())
	return maxf(tuning.bite_dive, dz / DIVE_SPEED)


## Its jaws shut: a bite drops away upright with the roof's end (its closing chin kept low), a breach recoils down.
func _snap_pose() -> Dictionary:
	var open: Dictionary = _open_pose()
	var out: Dictionary = open.duplicate()
	out["jaw"] = 0.0
	if int(action["kind"]) == Kind.BITE:
		out["hinge"] = (open["hinge"] as Vector3) - Vector3(0.0, SNAP_DROP, 0.0)
		out["roll"] = 0.0
	elif int(action["kind"]) == Kind.FLOOR:
		# Still leaning in, shut, dropped with the chunk until its jaws are under the deck.
		out["hinge"] = (open["hinge"] as Vector3) - Vector3(0.0, FLOOR_DROP, 0.0)
	else:
		out["hinge"] = (open["hinge"] as Vector3) - Vector3(0.0, RECOIL, 0.0)
	return out


## Where a floor bite's hinge goes (world x) as its jaws burst up: its lower jaw, flat across the crescent, reaching from
## outside the bitten side to FLOOR_CLEAR short of the deepest the bite goes (the lane it leaves; the far wall on a
## full-width one).
static func floor_hinge_x(bite: MechaGuppyCrescent) -> float:
	var reach: float = (MechaGuppySharkModel.JAW_LENGTH + MechaGuppySharkModel.TIP_CAP) * SCALE
	var tip: float = bite.x_of(minf(bite.deepest(), bite.width()) - FLOOR_CLEAR)
	return tip + float(bite.side) * reach


func _deep_pose() -> Dictionary:
	return {"hinge": Vector3(hinge.x, float(action.get("top", hinge.y + DEEP)) - DEEP, hinge.z), "pitch": 0.0, "roll": 0.0,
		"yaw": yaw, "jaw": 0.0}


## Halfway up its jaws, where a snap is heard from.
func _mouth_point() -> Vector3:
	return _head.global_transform * Vector3(0.0, MechaGuppySharkModel.JAW_LENGTH * 0.6, 0.0)


func _go(next: Stage, to: Dictionary, seconds: float) -> void:
	stage = next
	stage_time = 0.0
	_stage_seconds = maxf(seconds, 0.02)
	_from = {"hinge": hinge, "pitch": pitch, "roll": roll, "yaw": yaw, "jaw": jaw}
	_to = to


## True if its bite gives way to a fallback due (its pattern's may_bite, asked how long the bite would take: see
## MechaGuppyPattern._bite_fits).
func _yields() -> bool:
	var may: Callable = action.get("may_bite", Callable())
	return may.is_valid() and not bool(may.call(bite_seconds()))


## True once the jaws may come up: a bite waits for nobody to be on its roof (may_break); a breach comes up just in time
## to be open when it should (open_at, less the rise).
func _may_break() -> bool:
	if int(action["kind"]) == Kind.BITE:
		var check: Callable = action.get("may_break", Callable())
		return not check.is_valid() or bool(check.call())
	if int(action["kind"]) == Kind.FLOOR:
		return world.player.distance >= float(action["lunge_at"])
	return boss.bombs.clock >= float(action["open_at"]) - tuning.breach_rise - 0.02


## Eases its pose from the stage's start to its target, `k` of the way (0-1). `drop_first`: its hinge gets there early
## and its lean and jaws late (a bite's dive: under the roof's top before its chin swings in).
func _ease(k: float, drop_first: bool = false) -> void:
	var raw: float = clampf(k, 0.0, 1.0)
	var t: float = raw * raw * (3.0 - 2.0 * raw)
	var th: float = t
	if drop_first:
		th = 1.0 - (1.0 - raw) * (1.0 - raw)
		t = raw * raw
	hinge = (_from["hinge"] as Vector3).lerp(_to["hinge"], th)
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
	# The snout (z < 0) tips back a little, the chin (z > 0) drops wide.
	_upper.transform = Transform3D(Basis(Vector3.RIGHT, -deg_to_rad(MechaGuppySharkModel.UPPER_OPEN) * jaw), Vector3.ZERO)
	_lower.transform = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(MechaGuppySharkModel.LOWER_OPEN) * jaw), Vector3.ZERO)


## The highest its jaws reach (world y) over `x0`..`x1` (world x) in its pose now, sampled round their outline and teeth
## (tests: a bite's never within BITE_CLEAR of a rider under the hut, a breach's never over a lane that leads up). -INF
## while no part of them is over that span, or it's out of sight.
func jaws_over(x0: float, x1: float) -> float:
	var best: float = -INF
	for p: Vector3 in jaws_points():
		if p.x >= x0 and p.x <= x1:
			best = maxf(best, p.y)
	return best


## Points round its jaws' outline in its pose now (world space; each jaw's shell, widened by its teeth, from the hinge to
## the tip's cap): none while it's out of sight (tests: where its jaws reach).
func jaws_points() -> PackedVector3Array:
	var out := PackedVector3Array()
	if not _head.visible:
		return out
	var teeth: float = MechaGuppySharkModel.TOOTH_HEIGHT
	for part: MeshInstance3D in [_upper, _lower]:
		var xf: Transform3D = _head.global_transform * part.transform
		var sign_z: float = -1.0 if part == _upper else 1.0
		for i: int in 11:
			var u: float = float(i) / 10.0
			var size: Vector2 = MechaGuppySharkModel.jaw_size(u) + Vector2(teeth, teeth)
			for j: int in 9:
				var a: float = PI * float(j) / 8.0
				out.append(xf * Vector3(size.x * cos(a), u * MechaGuppySharkModel.JAW_LENGTH, sign_z * size.y * sin(a)))
		out.append(xf * Vector3(0.0, MechaGuppySharkModel.JAW_LENGTH + MechaGuppySharkModel.TIP_CAP, 0.0))
	return out
