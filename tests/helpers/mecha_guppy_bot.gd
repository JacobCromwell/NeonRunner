class_name MechaGuppyBot
extends RefCounted
## A runner who climbs Mecha Guppy and Captain Cogs' climb (GDD §10; task E5e-b1) like a good player, for tests and
## the showcase. Call step() every physics frame. It presses only the player's named actions, and it reads which
## lanes lead up from what the climb shows, the hut and the roofs themselves (physics rays on their collision, never
## the plan): `reaction` seconds after settling on a hut, it follows each lane of the hut to its end and looks
## where a drop from there comes down; a lane leads up if the higher roof is under it there. Then it switches,
## one lane at a time at the lane-switch time, to the nearest lane that leads up (or, with `wrong`, to the nearest
## that doesn't, to show a wrong drop falls), and records how much time it had to spare (`min_slack`: from its last
## switch's press, when the lane is committed (Player._start_switch), to the lane's end, the plan's deadline). It's a
## slow player: it waits a frame past each switch's end before the next.
## With `worst_case` (the fairness suites), before each step's pads it first moves to the lane farthest from that
## step's lanes that lead up (the one place it uses the plan: to pick the worst case on purpose) and jumps right
## before the pads (with `dash_flip`, dashing as it jumps: the run's dash power-up), so it flips up as late as any
## runner can and reads as late as the plan allows. `wrong_at` limits `wrong` to one step; `wrong_far` drops in the
## lane farthest from the lanes that lead up; `dash_drop` dashes as its lane ends, so the dash carries the whole fall.
## Captain Cogs' bombs (task E5e-b2): on a roof, or in the air over one after a drop off a hut, it follows a way through
## the circles of every spot still ahead (MechaGuppyBombs.dodge_lane: the circles it can see, read off the volley as the
## Floating Head's bot reads its salvos), `dodge_reaction` after a volley's circles show (the planner's own reaction:
## MechaGuppyTuning.dodge_reaction), switching only where the roof is under every lane it crosses (never off a pier's
## side into the chasm; never on a hut, where the narrow ceiling holds it); `dodges` off, it ignores them.
## The bait (task E5e-b3, MechaGuppyPattern): with `baits`, once the volley's spots are behind it on a roof with the
## bait's notch ahead, it heads for the notch's lane (`dodge_reaction` after the last spot, or after landing) and stays
## there while the bait's circle follows it, then `dodge_reaction` after the lock (the throw) it switches out, before
## the notch's edge: the bomb falls past the edge into the jaws. Without `baits` it dodges the bait like any spot (the
## fallback brings its hits). Either way it never runs off the end of a lane that ends ahead (it switches to a lane with
## floor in time, as a player would).
## Mecha Guppy's floor bite (task E5e-f, MechaGuppyFloorBite): it reads the bite off its warning (the crescent's outline:
## the bite it shows), `dodge_reaction` after it shows, once it's on the floor (or in the air over it): into the lane the
## bite leaves, a lane at a time where the floor is under the lane it moves into, or over a full-width bite a jump timed so
## it's in the air over the whole stretch where the gap reaches into its lane (centred on it); its bait and its worst case
## wait until it's past the bite. `bite_slack` is the least time it had to spare before a bite that leaves a lane: from its
## last switch's press (or its reading, with none to make) to its hurtbox's front reaching the bite, less the switch;
## `jump_margin` the least its jumps cleared a full-width bite's stretch by, either end (seconds); `bites` what it met.
## Phase 3 (task E5e-c, MechaGuppyTop), on the top: it reads Captain Cogs' rounds by their red lines and the waves by
## their swells, `dodge_reaction` late (the planner's own reaction): once a round's lines show, it switches to the nearest
## lane they leave clear (the one toward the middle on a tie), and once a wave's swell is rising, it jumps as the surge
## rushes in, JUMP_LEAD before it reaches it (mid-way through the time a jump clears its band); `top_jumps` and
## `top_switches` count them. With `top_dodges` off it does neither (the tests' runner who stays put).

var boss: MechaGuppy
## Seconds after settling on a hut before it reads the lanes that lead up.
var reaction: float = 0.2
## Drops in the nearest lane that doesn't lead up (and stays there) instead.
var wrong: bool = false
## Worst case: the farthest lane before each step's pads, and a jump right before them.
var worst_case: bool = false
## What it did: {t (fight time), action, why}.
var log: Array[Dictionary] = []
## Roofs it landed on higher than the one before.
var steps_climbed: int = 0
## The least time it had to spare, over every step it read: seconds between pressing its last switch (or reading,
## with none to make) and its lane's end on the hut (its step's deadline). INF before it reads one.
var min_slack: float = INF
## Lanes it read as leading up, step by step: {step, lanes: Array[int]}.
var reads: Array[Dictionary] = []
## Dashes with the late jump before the pads (worst_case).
var dash_flip: bool = false
## `wrong` only at this step (-1: every step).
var wrong_at: int = -1
## A wrong drop in the lane farthest from the lanes that lead up (else the nearest that doesn't).
var wrong_far: bool = false
## Dashes as a wrong lane ends.
var dash_drop: bool = false
## Dashes it started.
var dashes: int = 0
## Dodges Captain Cogs' spots (a way through their circles).
var dodges: bool = true
## Switches it made to dodge a spot.
var dodge_moves: int = 0
## Seconds after a volley's circles show (or the bait locks) before it moves to dodge; the tuning's dodge_reaction by
## default (MechaGuppyTuning).
var dodge_reaction: float = -1.0
## Baits Captain Cogs' bombs into the notch's jaws (off: it only dodges them).
var baits: bool = true
## Baits it lured into a notch (in its lane as the bait locked).
var baited: int = 0
## Tests: at this step it lures the bait, then stays in the notch's lane and runs off its edge (a fall) (-1: never).
var stay_in_notch_at: int = -1
## Phase 3: dodges the rounds and jumps the waves; the switches and jumps it made for them.
var top_dodges: bool = true
var top_switches: int = 0
var top_jumps: int = 0
## Phase 3: the jump comes this long before a surge reaches the runner (seconds).
const JUMP_LEAD: float = 0.3
## The floor bites: the least time to spare before one that leaves a lane, the least a jump cleared a full-width one by
## (seconds), and each one met: {roof, full, from (its lane as it read it), keep, slack, margin, lane (as it passed)}.
var bite_slack: float = INF
var jump_margin: float = INF
var bites: Array[Dictionary] = []
## Reads Mecha Guppy's floor bites (off: it runs on in its lane, into a bite's gap: the tests' fall).
var floor_bites: bool = true

var _read_step: int = -1
var _settled_at: float = -1.0
var _target: int = -1
var _next_press: float = 0.0
var _prepared: int = -1
var _jumped: int = -1
var _measured: int = -1
var _floor: float = 0.0
var _drop_dashed: int = -1
## The bait: the step it's luring, the bomb clock it may head for the notch from (after its reaction), the bait locked.
var _lure_step: int = -1
var _lure_from: float = INF
var _lured: int = -1
## When the volley's spots were last ahead of it (bomb clock).
var _spots_seen: float = -INF
## Phase 3: when each round's lines and each wave's swell were first seen (their clocks), and the waves jumped.
var _rounds_seen: Dictionary = {}
var _waves_seen: Dictionary = {}
var _waves_jumped: Dictionary = {}
## The floor bite being read (its record in `bites`), and when the runner last got past one (bomb clock).
var _bite: Dictionary = {}
var _bite_passed: float = -INF


func _init(p_boss: MechaGuppy) -> void:
	boss = p_boss
	dodge_reaction = boss.tuning.dodge_reaction if boss.tuning != null else 0.35


func step() -> void:
	var world: RunWorld = boss.world
	var p: Player = world.player
	if not p.alive or not p.running:
		return
	var now: float = p.elapsed
	if p.surface == Player.Surface.FLOOR and p.grounded:
		if p.floor_y > _floor + 0.5:
			steps_climbed += 1
			log.append({"t": boss.fight_time(), "action": &"landed", "why": "on the roof %.1f m up, lane %d" % [p.floor_y, p.lane]})
		_floor = p.floor_y
	if dodges and p.surface == Player.Surface.FLOOR:
		if floor_bites:
			_floor_bite(p, now)
		_dodge(p, now)
		_bait(p, now)
	if p.surface == Player.Surface.FLOOR:
		_lane_end(p, now)
		if top_dodges:
			_top(p, now)
	var next: MechaGuppyClimb.Step = _next_step(p)
	if next == null or next.top:
		_walk(p, next, now)
		return
	if p.surface == Player.Surface.FLOOR:
		_settled_at = -1.0
		if worst_case and not _dodging(p) and not _bite_ahead(p):
			_prepare(p, next, now)
	elif p.surface == Player.Surface.CEILING:
		if p.grounded and _settled_at < 0.0:
			_settled_at = now
		if _settled_at >= 0.0 and _read_step != next.index and now - _settled_at >= reaction:
			_read(p, next, now)
		if dash_drop and _goes_wrong(next) and _drop_dashed != next.index and p.lane >= 0 and p.lane < next.ends.size() \
				and p.distance >= next.ends[p.lane] - p.speed * 0.05:
			_drop_dashed = next.index
			_dash("as its lane ends: the dash carries the whole fall")
	_walk(p, next, now)


## True if it drops wrong at step `next`.
func _goes_wrong(next: MechaGuppyClimb.Step) -> bool:
	return wrong and (wrong_at < 0 or wrong_at == next.index)


func _dash(why: String) -> void:
	var controller := boss.world.powerups as PowerupController
	if controller != null and controller.try_dash():
		dashes += 1
		log.append({"t": boss.fight_time(), "action": &"dash", "why": why})


## The step whose pads are ahead of a runner on the floor, or whose hut a rider is on.
func _next_step(p: Player) -> MechaGuppyClimb.Step:
	var climb: MechaGuppyClimb = boss.climb
	if p.surface == Player.Surface.CEILING:
		return climb.step_at(p.distance)
	for k: int in range(maxi(climb.step_index_at(p.distance), 0), climb.steps.size()):
		var s: MechaGuppyClimb.Step = climb.steps[k]
		if s.top or s.pad_end > p.distance:
			return s
	return null


## Worst case: into the lane farthest from the step's lanes that lead up while there's room on the roof, then a jump
## right before its pads.
func _prepare(p: Player, next: MechaGuppyClimb.Step, now: float) -> void:
	var lanes: int = boss.lane_count()
	# Only where the roof is full width: beside its lanes that reach back there's the gap (a fall).
	var roof: MechaGuppyClimb.Roof = boss.climb.roofs[next.index]
	if _prepared != next.index and p.distance > roof.full_from() + 1.0 and next.pad - p.distance > p.speed * 0.9:
		# The farthest lane with pads (the bait's notch has eaten an outer lane's).
		var far: int = -1
		for lane: int in lanes:
			if roof.covers(lane, next.pad) and (far < 0 or next.switches_from(lane) > next.switches_from(far)):
				far = lane
		_prepared = next.index
		_set_target(far, "the worst case: the lane farthest from the lanes that lead up", now)
	# The last frame before the pads: its hurtbox's front (where the pad strip catches it) short of them by at most a
	# frame and a half's run.
	var gap: float = next.pad - p.distance - boss.world.tuning.hurtbox_size.z * 0.5
	if _jumped != next.index and p.grounded and gap > 0.0 and gap <= p.speed / Engine.physics_ticks_per_second * 1.5:
		_jumped = next.index
		p.press(&"jump")
		log.append({"t": boss.fight_time(), "action": &"jump", "why": "right before the pads (the latest flip)"})
		if dash_flip:
			_dash("with the jump: the longest jump before the flip")


## Reads the lanes that lead up from the hut and the roofs (read_up_lanes) and heads for the nearest (or, `wrong`,
## the nearest that doesn't).
func _read(p: Player, next: MechaGuppyClimb.Step, now: float) -> void:
	_read_step = next.index
	var up: Array[int] = read_up_lanes(boss.world, boss.climb, p)
	reads.append({"step": next.index, "lanes": up})
	var go_wrong: bool = _goes_wrong(next)
	var pick: int = -1
	for lane: int in boss.lane_count():
		var leads: bool = up.has(lane)
		if leads == go_wrong:
			continue
		var better: bool = pick < 0 or absi(lane - p.lane) < absi(pick - p.lane)
		if go_wrong and wrong_far and not up.is_empty():
			# The farthest from the lanes that lead up.
			better = pick < 0 or _gap(lane, up) > _gap(pick, up)
		if better:
			pick = lane
	if pick < 0:
		pick = p.lane
	_set_target(pick, "reads lanes %s leading up; %s" % [up, "drops in another" if go_wrong else "heads for the nearest"], now)
	_measured = -1


## How many lanes `lane` is from the nearest of `up`.
static func _gap(lane: int, up: Array[int]) -> int:
	var out: int = 1 << 20
	for u: int in up:
		out = mini(out, absi(lane - u))
	return out


## A switch a lane at a time toward the target, each a frame after the last has finished. On a hut, the time it had
## to spare is measured at its last switch's press (or at its reading, with none to make), when its lane is
## committed, to the lane's end (its step's deadline).
func _walk(p: Player, next: MechaGuppyClimb.Step, now: float) -> void:
	if _target < 0:
		return
	var on_hut: bool = next != null and p.surface == Player.Surface.CEILING and _read_step == next.index \
		and _measured != next.index
	if p.lane == _target:
		if on_hut:
			_slack(p, next, 0.0)
		_target = -1
		return
	if now < _next_press:
		return
	var dir: int = signi(_target - p.lane)
	# On a roof (or over one in the air), only where the roof is under the lane it moves into: never off a pier's side.
	if p.surface == Player.Surface.FLOOR and not _floor_beside(p, p.lane + dir):
		return
	if on_hut and absi(_target - p.lane) == 1:
		_slack(p, next, 0.0)
	# A floor bite's last switch into the lane it leaves: the time to spare after it, measured at its press.
	if not _bite.is_empty() and not bool(_bite["full"]) and _target == int(_bite["keep"]) and absi(_target - p.lane) == 1 \
			and boss.floor_bite != null and boss.floor_bite.bite != null:
		_bite_slack(p, boss.floor_bite.bite, boss.world.tuning.lane_switch_time)
	p.press(&"move_right" if dir > 0 else &"move_left")
	_next_press = now + boss.world.tuning.lane_switch_time + 1.0 / Engine.physics_ticks_per_second


## Records the time to spare at step `next`'s deadline for a rider in their lane `switching` seconds from now.
func _slack(p: Player, next: MechaGuppyClimb.Step, switching: float) -> void:
	_measured = next.index
	var slack: float = (next.deadline - p.distance) / maxf(p.speed, 0.001) - switching
	min_slack = minf(min_slack, slack)
	log.append({"t": boss.fight_time(), "action": &"in_lane", "why": "lane %d, %.2f s to spare" % [_target, slack]})


func _set_target(lane: int, why: String, now: float) -> void:
	_target = lane
	_next_press = minf(_next_press, now)
	log.append({"t": boss.fight_time(), "action": &"target", "why": "lane %d: %s" % [lane, why]})


## Captain Cogs' spots: the lane a way through the circles still ahead wants it in (MechaGuppyBombs.dodge_lane),
## dodge_reaction after the newest volley's circles showed.
func _dodge(p: Player, now: float) -> void:
	var bombs: MechaGuppyBombs = boss.bombs
	if bombs == null:
		return
	if not bombs.spots_ahead(p.distance).is_empty():
		_spots_seen = bombs.clock
	for v: Dictionary in bombs.volleys:
		if bombs.clock - float(v["lock"]) < dodge_reaction - 0.0001:
			return
	var lane: int = bombs.dodge_lane(p.lane, p.distance)
	if lane < 0 or lane == _target or (_target < 0 and lane == p.lane):
		return
	dodge_moves += absi(lane - p.lane)
	_set_target(lane, "Captain Cogs' bombs: a way through their circles", now)


## The bait (see the header): into the notch's lane while the bait's circle follows it, out again dodge_reaction after it
## locks; without `baits`, out of the notch's lane (if it's there) before the bait can lock in it.
func _bait(p: Player, now: float) -> void:
	var bombs: MechaGuppyBombs = boss.bombs
	if bombs == null or not boss.attacks_live():
		return
	var bait: Dictionary = bombs.bait
	var k: int = boss.climb.step_index_at(p.distance)
	if k < 0 or k + 1 >= boss.climb.roofs.size():
		return
	var roof: MechaGuppyClimb.Roof = boss.climb.roofs[k + 1]
	if not roof.notched() or p.distance >= roof.notch_from or absf(p.floor_y - roof.top) > 0.05:
		return
	# Its floor bite first (task E5e-f): nothing for the bait until it's past it.
	if _bite_ahead(p):
		return
	var notch: int = roof.notch_lane
	var plan: Dictionary = boss.pattern.bait_plan(boss.climb.steps[k], p.speed) if boss.pattern != null else {}
	# No bait to lure (none planned, or the step already hit: its fallback came first).
	if plan.is_empty() or boss.pattern.hit_on(k):
		return
	if not baits:
		if p.lane == notch and p.distance < float(plan["lock_at"]) and bombs.spots_ahead(p.distance).is_empty() \
				and _target != _inner(notch):
			_set_target(_inner(notch), "not baiting: out of the notch's lane before the bait can lock there", now)
		return
	if not bait.is_empty() and int(bait["step"]) == k and bool(bait["locked"]):
		# Locked: out of the notch's lane once it has reacted to the throw.
		if _lured != k:
			_lured = k
			if int(bait["lane"]) == notch:
				baited += 1
				log.append({"t": boss.fight_time(), "action": &"baited", "why": "the bait locked in the notch's lane %d" % notch})
		if p.lane == notch and k != stay_in_notch_at \
				and bombs.clock - float((bait["drop"] as Dictionary).get("release", bombs.clock)) >= dodge_reaction - 0.0001:
			_set_target(_inner(notch), "the bait is thrown: out of the notch's lane before its edge", now)
		return
	# Not yet locked: once this roof's volley is thrown and its spots are behind it (and it has reacted), into the notch's
	# lane, while the bait can still lock there.
	if not bombs.spots_ahead(p.distance).is_empty() or p.distance >= float(plan["lock_at"]) or _lured == k:
		return
	var volley_at: float = boss.pattern.volley_lock(boss.climb.steps[k], p.speed)
	if volley_at < MechaGuppyClimb.FAR * 0.5 and p.distance < volley_at + 0.5:
		return
	if _lure_step != k:
		_lure_step = k
		_lure_from = maxf(maxf(_spots_seen, _bite_passed), bombs.clock) + dodge_reaction
	if bombs.clock >= _lure_from - 0.0001 and p.lane != notch and _target != notch:
		_set_target(notch, "the bait: into the notch's lane %d to lure the bomb past its edge" % notch, now)


## Mecha Guppy's floor bite (see the header): once its warning has shown dodge_reaction, into the lane it leaves, or a jump
## over a full-width one in the air over the whole stretch where its gap reaches into the runner's lane, centred on it.
func _floor_bite(p: Player, now: float) -> void:
	var fb: MechaGuppyFloorBite = boss.floor_bite
	if fb == null:
		return
	var h: float = boss.world.tuning.hurtbox_size.z * 0.5
	# Past the one it was reading: noted.
	if not _bite.is_empty() and p.distance > float(_bite["to"]) + h:
		_bite["lane"] = p.lane
		_bite = {}
		_bite_passed = boss.bombs.clock if boss.bombs != null else 0.0
	var bite: MechaGuppyCrescent = fb.bite
	if bite == null or fb.warned_at < 0.0 or p.distance > bite.to + h:
		return
	if fb.clock - fb.warned_at < dodge_reaction - 0.0001:
		return
	if _bite.is_empty() or int(_bite["roof"]) != bite.roof:
		_bite = {"roof": bite.roof, "full": bite.full, "from": p.lane, "keep": bite.keep, "slack": INF, "margin": INF,
			"to": bite.to, "jumped": false, "lane": -1}
		bites.append(_bite)
		if not bite.full and p.lane == bite.keep:
			_bite_slack(p, bite, 0.0)
	if not bite.full:
		if p.lane != bite.keep and _target != bite.keep:
			_set_target(bite.keep, "Mecha Guppy's floor bite: into the lane it leaves (%d)" % bite.keep, now)
		return
	if bool(_bite["jumped"]):
		return
	var gap: Vector2 = bite.stretch(bite.near_w(p.lane))
	if gap.x > gap.y:
		return
	var speed: float = maxf(p.speed, 1.0)
	var air: float = boss.climb.jump_seconds() * speed
	if p.distance >= (gap.x + gap.y - air) * 0.5 and p.grounded:
		_bite["jumped"] = true
		p.press(&"jump")
		var margin: float = minf(gap.x - p.distance, p.distance + air - gap.y) / speed
		_bite["margin"] = margin
		jump_margin = minf(jump_margin, margin)
		log.append({"t": boss.fight_time(), "action": &"jump",
			"why": "over Mecha Guppy's full-width floor bite (%.2f s to spare either end)" % margin})


## Records the time to spare before floor bite `bite` for a runner in its lane `switching` seconds from now: until their
## hurtbox's front reaches the bite, less the switch.
func _bite_slack(p: Player, bite: MechaGuppyCrescent, switching: float) -> void:
	var slack: float = (bite.from - p.distance - boss.world.tuning.hurtbox_size.z * 0.5) / maxf(p.speed, 0.001) - switching
	_bite["slack"] = minf(float(_bite["slack"]), slack)
	bite_slack = minf(bite_slack, slack)


## True while the roof the runner is on (or dropping onto) has a floor bite still ahead of them (task E5e-f).
func _bite_ahead(p: Player) -> bool:
	var k: int = boss.climb.step_index_at(p.distance)
	if k < 0 or k + 1 >= boss.climb.roofs.size():
		return false
	var bite: MechaGuppyCrescent = boss.climb.roofs[k + 1].bite
	return bite != null and not bite.skipped and p.distance < bite.to + boss.world.tuning.hurtbox_size.z * 0.5


## The lane beside the notch's lane `notch`, toward the track's middle.
func _inner(notch: int) -> int:
	return notch + 1 if notch == 0 else notch - 1


## A lane that ends ahead on the roof under it (the bait's notch): it switches out in time (a reaction, a switch and a
## margin before the edge), unless it's holding there for the bait until the lock.
func _lane_end(p: Player, now: float) -> void:
	var k: int = boss.climb.step_index_at(p.distance)
	if k < 0 or k + 1 >= boss.climb.roofs.size():
		return
	var roof: MechaGuppyClimb.Roof = boss.climb.roofs[k + 1]
	if not roof.notched() or p.lane != roof.notch_lane or p.distance >= roof.notch_from or absf(p.floor_y - roof.top) > 0.05:
		return
	var bait: Dictionary = boss.bombs.bait if boss.bombs != null else {}
	var holding: bool = (baits and not bait.is_empty() and int(bait["step"]) == k and not bool(bait["locked"])) or k == stay_in_notch_at
	var need: float = (dodge_reaction + boss.world.tuning.lane_switch_time + 0.2) * maxf(p.speed, 1.0)
	if not holding and roof.notch_from - p.distance <= need and _target != _inner(roof.notch_lane):
		_set_target(_inner(roof.notch_lane), "its lane ends ahead (the notch): out in time", now)


## Phase 3 (see the header): out of a round's struck lanes, over a wave's surge, each a reaction after its warning shows.
func _top(p: Player, now: float) -> void:
	var top: MechaGuppyTop = boss.top
	if top == null or not top.started():
		return
	var rounds: MechaGuppyRounds = top.rounds
	var struck: Dictionary = {}
	for r: Dictionary in rounds.rounds:
		if int(r["state"]) == MechaGuppyRounds.State.DONE or r.has("passed"):
			continue
		var k: int = int(r["k"])
		if not _rounds_seen.has(k):
			_rounds_seen[k] = rounds.clock
		if rounds.clock - float(_rounds_seen[k]) < dodge_reaction - 0.0001:
			continue
		for lane: int in r["lanes"]:
			struck[lane] = true
	var aim: int = _target if _target >= 0 else p.lane
	if struck.has(aim):
		var best: int = -1
		var middle: float = (boss.lane_count() - 1) * 0.5
		for lane: int in boss.lane_count():
			if struck.has(lane):
				continue
			if best < 0 or absi(lane - p.lane) < absi(best - p.lane) \
					or (absi(lane - p.lane) == absi(best - p.lane) and absf(lane - middle) < absf(best - middle)):
				best = lane
		if best >= 0:
			top_switches += absi(best - p.lane)
			_set_target(best, "Captain Cogs' round: out of the lanes its red lines strike", now)
	var waves: MechaGuppyWaves = top.waves
	for w: Dictionary in waves.waves:
		var k: int = int(w["k"])
		if not _waves_seen.has(k):
			_waves_seen[k] = waves.clock
	for w: Dictionary in waves.waves:
		var k: int = int(w["k"])
		if _waves_jumped.has(k) or int(w["state"]) != MechaGuppyWaves.State.ROLL or w.has("passed") \
				or waves.clock - float(_waves_seen[k]) < dodge_reaction - 0.0001:
			continue
		var front: float = MechaGuppyWaves.surge_d(w, waves.clock) - boss.tuning.wave_depth * 0.5
		var gap: float = front - p.distance - boss.world.tuning.hurtbox_size.z * 0.5
		var time_to: float = gap / maxf(float(w["speed"]) + p.speed, 1.0)
		if time_to <= JUMP_LEAD and p.grounded:
			_waves_jumped[k] = true
			top_jumps += 1
			p.press(&"jump")
			log.append({"t": boss.fight_time(), "action": &"jump", "why": "a wave's surge rushing in (%.2f s away)" % time_to})


## True while a spot of Captain Cogs' lies ahead of it (it keeps to the way through rather than the worst case's lane).
func _dodging(p: Player) -> bool:
	return boss.bombs != null and not boss.bombs.spots_ahead(p.distance).is_empty()


## True if the roof under the runner (or under them in the air) reaches into `lane` where they are.
func _floor_beside(p: Player, lane: int) -> bool:
	if lane < 0 or lane >= boss.lane_count():
		return false
	var climb: MechaGuppyClimb = boss.climb
	var top: float = climb.floor_at(p.lane, p.distance, p.position.y + 0.3)
	if is_nan(top):
		return false
	var there: float = climb.floor_at(lane, p.distance, p.position.y + 0.3)
	return not is_nan(there) and absf(there - top) < 0.05


## Phase 1's and phase 2's bombs that can reach the runner (every volley's bombs and every bait's: the fallback's into the
## chasm never can), from boss `boss`'s events through phase 2's end: {count: [p1, p2], steps: [p1, p2] (the steps that
## threw any), step: [per step], second: [per second of the phase]}.
static func census(boss: MechaGuppy) -> Dictionary:
	var count: Array[int] = [0, 0]
	var seen: Array[Dictionary] = [{}, {}]
	var ends: Array[float] = [0.0, 0.0]
	var begins: Array[float] = [0.0, 0.0]
	for e: Dictionary in boss.events:
		var ph: int = int(e.get("phase", 0))
		if ph > 1:
			continue
		match e["event"]:
			&"volley":
				for spot: Dictionary in e["spots"]:
					count[ph] += (spot["lanes"] as Array).size()
				seen[ph][int(e["step"])] = true
			&"bait_lock":
				count[ph] += 1
				seen[ph][int(e["step"])] = true
			&"phase_end":
				ends[ph] = float(e["t"])
				if ph == 0:
					begins[1] = float(e["t"])
	var steps: Array[int] = [seen[0].size(), seen[1].size()]
	var step: Array[float] = []
	var second: Array[float] = []
	for ph: int in 2:
		step.append(float(count[ph]) / maxf(float(steps[ph]), 1.0))
		second.append(float(count[ph]) / maxf(ends[ph] - begins[ph], 0.001))
	return {"count": count, "steps": steps, "step": step, "second": second}


## Task E5e-b2's review, the pier trap: why a bomb's circle shows in the runner's lane while every lane they could switch
## to has no floor (on a floor, or in the air over one; on a hut a switch out of its lanes is only refused), or "". The
## bait's circle following them counts too.
static func circle_trap(boss: MechaGuppy) -> String:
	var world: RunWorld = boss.world
	var p: Player = world.player
	if p == null or not p.alive or p.surface == Player.Surface.CEILING or boss.bombs == null:
		return ""
	var shown: bool = boss.bombs.seek_ring() != null and int(boss.bombs.bait.get("lane", -1)) == p.lane
	for d: Dictionary in boss.bombs.drops():
		var circle: MeshInstance3D = d["circle"]
		if not bool(d["landed"]) and circle != null and is_instance_valid(circle) and circle.visible and int(d["lane"]) == p.lane:
			shown = true
	if not shown:
		return ""
	var climb: MechaGuppyClimb = boss.climb
	var top: float = climb.floor_at(p.lane, p.distance, p.position.y + 0.3)
	if is_nan(top):
		return ""
	for lane: int in [p.lane - 1, p.lane + 1]:
		if lane < 0 or lane >= world.geo.lane_count:
			continue
		var there: float = climb.floor_at(lane, p.distance, p.position.y + 0.3)
		if not is_nan(there) and absf(there - top) < 0.05:
			return ""
	return "a circle in the runner's lane %d with no floor beside them at %.0f m" % [p.lane, p.distance]


## The lanes that lead up from the hut a rider `p` is on, as the hut and the roofs show them (physics rays on their
## collision): each lane of the hut followed to its end (the hull layer at the rider's ceiling height), and a drop
## from there followed down to the first roof top under it (the floor layer), checked where the drop really reaches
## that height (the climb's drop timing at the run's speed). A lane leads up if a roof higher than the floor the
## rider came from is under it there.
static func read_up_lanes(world: RunWorld, climb: MechaGuppyClimb, p: Player) -> Array[int]:
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.new()
	var hut_y: float = p.ceiling_y
	var floor_y: float = p.floor_y
	var out: Array[int] = []
	for lane: int in world.geo.lane_count:
		var x: float = world.geo.lane_x(lane)
		var end: float = p.distance
		ray.collision_mask = TrackBuilder.LAYER_HULL
		while end < p.distance + 200.0:
			ray.from = Vector3(x, hut_y - 0.6, -end)
			ray.to = Vector3(x, hut_y + 0.3, -end)
			if space.intersect_ray(ray).is_empty():
				break
			end += 0.25
		# Where the first roof under the drop lies, then whether the drop comes down onto it.
		ray.collision_mask = TrackBuilder.LAYER_FLOOR
		var top: float = NAN
		var probe: float = end
		while probe < end + climb.speed * 0.8:
			ray.from = Vector3(x, hut_y - 0.5, -probe)
			ray.to = Vector3(x, floor_y - 1.0, -probe)
			var hit: Dictionary = space.intersect_ray(ray)
			if not hit.is_empty() and (hit["position"] as Vector3).y > floor_y + 0.5:
				top = (hit["position"] as Vector3).y
				break
			probe += 0.5
		if is_nan(top):
			continue
		var reach: float = end + world.tuning.foot_half_depth + climb.drop_seconds(hut_y - top) * climb.speed
		ray.from = Vector3(x, top + 0.3, -reach)
		ray.to = Vector3(x, top - 0.3, -reach)
		if not space.intersect_ray(ray).is_empty():
			out.append(lane)
	return out
