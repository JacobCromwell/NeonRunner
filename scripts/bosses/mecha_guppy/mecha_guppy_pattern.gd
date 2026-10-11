class_name MechaGuppyPattern
extends RefCounted
## Mecha Guppy and Captain Cogs' pattern through phases 1 and 2 (GDD §10; tasks E5e-b2 and E5e-b3): what the shark and the
## pirate do on each step of the climb (MechaGuppyClimb.Step k: roof k, its pads and hut, the higher roof k + 1), timed
## by where the runner is, the same on every step alike (nothing changes with time but the phase: GDD §10, no escalation).
## DESIGN-TBD (docs/questions/e5e.md): the whole pattern. Each step:
## - Mecha Guppy's bite (MechaGuppyShark.bite): once the runner is up on roof k's hut it bites the roof's end off below and
##   behind them (bite_length, never past the hut's start: the floor they should have left), the collision and the look
##   together (MechaGuppyStairs.eat_roof), with rubble flying; never the floor the runner is on (it waits for them to be on
##   the hut) nor the higher roof (the safe drop). Its warning: the rumble and the shark rising beside the roof's end as
##   the runner nears the pads, or, on a roof with the bait's notch, its catch there (below), which it bites from. On a
##   step whose fallback is due, a bite that would keep the shark busy past the fallback's last moment gives way to it
##   (_bite_fits): the shark sinks off and the roof's end stays.
## - The volley (roof_spots, landing_spots): phase 1, a spot on roof k + 1's run; phase 2, after a RUN_ON step, a spot
##   where riders come down onto it (dodged by a switch in the air as they drop off the hut's end), then a spot on its
##   run, as one volley, and its spots take more bombs side by side; nearest first, planned as the runner nears them by
##   the Floating Head's salvo rules (MechaGuppyBombs.plan_spots), each spot passed in time for the bait. Their circles
##   never show before the hut's deadline (so they never tell a rider which lanes lead up: only the owner's two cues
##   do), and never on a roof before the runner can switch lanes there (task E5e-b2's review: a circle in the lane of a
##   runner on a narrow pier, with nowhere to switch to but the chasm, was a trap): a roof's spot is thrown no sooner
##   than Step.free_at.
## - The bait (GDD §10, the owner, October 11, 2026: Captain Cogs' bombs lock onto the runner's lane, and a runner who
##   dodges one at a roof's end sends it past the edge into Mecha Guppy's jaws; bait_plan): near roof k + 1's end its
##   notch (MechaGuppyClimb.Roof.notch_lane, from roof MechaGuppyClimb.FIRST_NOTCH on), with Mecha Guppy waiting in its
##   catch beside it, jaws open (the shark comes up with its rumble bite_warning before the bait begins). As the runner
##   nears, Captain Cogs takes aim and the bomb's aim follows their lane (bait_seek: MechaGuppyBombs.start_bait), then
##   locks with the throw lock_seconds before it lands as they get there, catch_in into the notch (lock_bait): a runner
##   in the notch's lane then, who switches out before its edge, sends it past the edge into the jaws, a hit
##   (MechaGuppy.register_hit); anywhere else it lands on the roof, a spot of one bomb to dodge. Never a hit on a step
##   the runner fell (catch_ok), and no bait on a step already hit (its fallback came first: a hit at most one a step).
##   An extreme tuning that leaves no room for a fair bait leaves the step without one, and it counts toward the
##   fallback.
## - The fallback (GDD §10: "a player who doesn't manage it still progresses, more slowly: Captain Cogs sometimes misses
##   into the chasm anyway"): once fallback_after steps in a row have gone by without a hit (dry), from the next step's
##   hut deadline (every rider committed), with the rider in a lane that leads up, Captain Cogs throws at the chasm in
##   front of roof k + 1 beside the lanes that lead up, on the side with more lanes that don't (hit_back before the
##   roof's front there), and Mecha Guppy rises there to eat (MechaGuppyShark.breach; until then it glides deep out of sight), its
##   jaws open as the bomb comes down: the bomb falls into the stretch it has eaten through, where it's exposed and in the
##   line of fire (GDD §10): a hit. Its bomb has nothing to dodge: its circle shows, but no throw or whistle is heard.
##   It's thrown only once the shark can rise for it, waiting while its bomb can still come down ahead of the runner.
## 4 hits end phase 1, 6 phase 2: a runner who baits every step lands one a step (from the first notch on); one who
## never does, one every fallback_after + 1 steps.
## Attacks only while the pattern runs (MechaGuppy.attacks_live: not in an intro, not in phase 3's stub, not once won);
## the shark's bite of the floor left behind is the level being eaten, not an attack, so it goes on in an intro too.

## An event whose moment the runner is already this far past (metres: a review moving them on) is skipped.
const STALE: float = 30.0
## The fallback's bomb comes down at least this long a run before the runner draws level with where it falls (seconds:
## in view ahead or beside them); while Mecha Guppy is still busy, the fallback waits for it no longer than that allows.
const FALLBACK_AHEAD: float = 0.0
## Mecha Guppy's jaws are wide open at least this long before the fallback's bomb comes down (seconds: fallback_flight).
const FALLBACK_OPEN: float = 0.1

var boss: MechaGuppy
var tuning: MechaGuppyTuning
var world: RunWorld
var climb: MechaGuppyClimb
## Tests: false throws no fallback and keeps the shark from catching (a fight in which no hit ever lands, to show nothing
## escalates).
var hits_enabled: bool = true
## Steps in a row gone by without a hit, as each step closes (once the runner passes the next step's pads) after its
## bait was offered, or with none to offer; the fallback comes once it reaches fallback_after.
var dry: int = 0
## What's been done (each once a step): "bite:k", "volley:k", "bait:k", "seek:k", "lurk:k", "hit:k".
var _done: Dictionary = {}
## Steps whose bait was offered (its circle followed the runner), steps a hit landed on, steps the runner fell on (the
## grapple's save or a revive: MechaGuppy._grapple_save).
var _offered: Dictionary = {}
var _hit_steps: Dictionary = {}
var _fell: Dictionary = {}
## Steps with no bait to offer while the pattern ran (no room for a notch on the roof it would come down on: an extreme
## tuning). They count toward the fallback as steps gone by without a hit, so the hits still come.
var _baitless: Dictionary = {}
## The last step closed (dry counts it).
var _closed: int = -1


func _init(p_boss: MechaGuppy) -> void:
	boss = p_boss
	tuning = boss.tuning
	world = boss.world
	climb = boss.climb


## Every physics frame the fight runs (MechaGuppy's ticks).
func tick() -> void:
	var p: Player = world.player
	if p == null or not p.alive or climb.steps.is_empty():
		return
	var d: float = p.distance
	_close_steps(d)
	var k0: int = maxi(climb.step_index_at(d) - 1, 0)
	for k: int in range(k0, mini(k0 + 3, climb.steps.size())):
		var step: MechaGuppyClimb.Step = climb.steps[k]
		if step.top:
			break
		if boss.bites_live():
			_bite(step, p)
		if boss.attacks_live():
			_volley(step, p)
			_bait(step, p)
			_lurk(step, p)
			_fallback(step, p)


# --- Hits and falls ----------------------------------------------------------------------------

## A hit landed (MechaGuppy.register_hit): the step the runner is in has had its hit.
func note_hit() -> void:
	_hit_steps[_step_now()] = true


## The runner fell (MechaGuppy._grapple_save: the grapple's save or a revive): no hit for the step they're in.
func note_fall() -> void:
	_fell[_step_now()] = true
	boss.log_event(&"fell", {"step": _step_now()})


## True while a bomb may hit Mecha Guppy now (GDD §10, never a hit from a step on which the runner fell, even if the
## grapple saved them): the runner is alive, hasn't fallen this step, and is on a hut or over a roof's floor (not
## falling into the chasm or the notch).
func catch_ok() -> bool:
	var p: Player = world.player
	if p == null or not p.alive or _fell.has(_step_now()):
		return false
	if p.surface == Player.Surface.CEILING:
		return true
	var top: float = climb.floor_at(p.lane, p.distance, p.position.y + 0.3)
	return not is_nan(top) and p.position.y > top - 0.5


## True if the runner fell during step `k` (tests).
func fell_on(k: int) -> bool:
	return _fell.has(k)


## True if a hit landed during step `k` (its bait isn't offered then: _bait).
func hit_on(k: int) -> bool:
	return _hit_steps.has(k)


## The step whose cycle the runner is in: from its pads to the next step's.
func _step_now() -> int:
	return maxi(climb.step_index_at(world.player.distance), 0)


## Closes each step the runner has passed the next step's pads of: a step whose bait was offered (or that had none to
## offer) adds to `dry`, or resets it with a hit.
func _close_steps(d: float) -> void:
	while _closed + 1 < climb.steps.size() - 1:
		var k: int = _closed + 1
		var next: MechaGuppyClimb.Step = climb.steps[k + 1]
		if next.top or d < next.pad:
			return
		_closed = k
		if _hit_steps.has(k):
			dry = 0
		elif _offered.has(k) or _baitless.has(k):
			dry += 1


# --- Mecha Guppy's bite (and its catch first) ------------------------------------------------------

func _bite(step: MechaGuppyClimb.Step, p: Player) -> void:
	var key: String = "bite:%d" % step.index
	if _done.has(key):
		return
	var speed: float = maxf(p.speed, 1.0)
	var roof: MechaGuppyClimb.Roof = climb.roofs[step.index]
	var catch: Dictionary = _catch_plan(step.index, speed)
	var start_at: float = step.pad - tuning.bite_warning * speed
	if not catch.is_empty():
		start_at = minf(start_at, float(catch["rise_at"]))
	if p.distance < start_at:
		return
	if p.distance > roof.end + STALE or roof.end >= MechaGuppyClimb.FAR * 0.5:
		_done[key] = true
		return
	# Still busy (with a fallback's breach, or an extreme tuning's closer steps): it waits while a catch can still be
	# up before its bait locks, or a bite can still be over before this step's fallback (MechaGuppyShark.bite logs one
	# it's too late for as skipped); a catch it's too late for leaves a plain bite.
	if boss.shark.busy():
		if not catch.is_empty() and p.distance < float(catch["lock_at"]) - tuning.bite_warning * speed:
			return
		catch = {}
		var bite_seconds: float = tuning.bite_warning + tuning.bite_dive + tuning.bite_rise + tuning.bite_hold \
			+ tuning.bite_snap + tuning.bite_sink + tuning.bite_spare
		if p.distance < step.deadline - bite_seconds * speed:
			return
	_done[key] = true
	var cut: float = maxf(roof.end - tuning.bite_length, step.hut_start)
	var side: int = -1 if hash([boss.def.rng_key(), "bite", step.index]) % 2 == 0 else 1
	if not catch.is_empty():
		side = roof.notch_side()
	var index: int = step.index
	var pad: float = step.pad
	var spot: Dictionary = {"side": side, "edge": roof.end, "top": roof.top, "roof": index, "cut": cut,
		"may_break": func() -> bool: return _left_roof(index, pad),
		"may_bite": func(seconds: float) -> bool: return _bite_fits(index, seconds)}
	if not catch.is_empty():
		spot["catch"] = catch["catch"]
	boss.shark.bite(spot)


## Roof `index`'s catch for the bait thrown at it (the bait of the step before: bait_plan), if it gets one: {rise_at
## (where the runner is as the shark comes up for it), lock_at (where the bait locks), catch (MechaGuppyShark.bite's)};
## {} with no bait there, no hits (hits_enabled), no attacks yet, the runner having fallen on that step, or that step
## already hit (its fallback: no bait then, _bait).
func _catch_plan(index: int, speed: float) -> Dictionary:
	if index <= 0 or not hits_enabled or not boss.attacks_live() or _fell.has(index - 1) or _hit_steps.has(index - 1):
		return {}
	var plan: Dictionary = bait_plan(climb.steps[index - 1], speed)
	if plan.is_empty():
		return {}
	var roof: MechaGuppyClimb.Roof = climb.roofs[index]
	var inner: float = world.geo.lane_x(roof.notch_lane) - float(roof.notch_side()) * world.geo.lane_width * 0.5
	return {"rise_at": float(plan["seek_at"]) - tuning.bite_warning * speed, "lock_at": float(plan["lock_at"]),
		"catch": {"inner": inner, "lane_x": world.geo.lane_x(roof.notch_lane), "at": float(plan["at"]), "top": roof.top,
			"until": INF, "step": index - 1}}


## True once nobody can be on roof `index` any more: the runner is up on a hut (or dead) past its pads at `pad`.
func _left_roof(index: int, pad: float) -> bool:
	var p: Player = world.player
	if not p.alive:
		return true
	return p.surface == Player.Surface.CEILING and p.distance >= pad - 0.5


## True unless step `index`'s fallback is due and a bite taking `seconds` from now (until Mecha Guppy has sunk out of
## sight again) would keep the shark busy past the last moment the fallback can be thrown (fallback_last): then the bite
## yields (task E5e-b3's review: a long bite left every fallback to fall into an empty chasm), the shark sinks away and
## the roof's end stays uneaten that step.
func _bite_fits(index: int, seconds: float) -> bool:
	if not fallback_due(index):
		return true
	var p: Player = world.player
	return p.distance + seconds * maxf(p.speed, 1.0) <= fallback_last(climb.steps[index], maxf(p.speed, 1.0))


## The bite's snap (MechaGuppyShark.on_snap): the roof's end goes, collision and look, and its rubble flies.
func on_snap(action: Dictionary) -> void:
	var index: int = int(action.get("roof", -1))
	var box: AABB = boss.stairs.eat_roof(index, float(action.get("cut", 0.0)))
	if box.size.z <= 0.01:
		return
	var colors := PackedColorArray()
	var beach := world.skin as BeachSkin
	if beach != null:
		colors = PackedColorArray([beach.boardwalk_color, beach.bamboo_colors[0], beach.thatch_color, beach.timber_color])
	world.effects.rubble(box, colors, Vector3(0.0, -2.0, 0.0), index)
	var near: float = clampf(1.0 - absf(-box.get_center().z - world.player.distance) / 50.0, 0.2, 1.0)
	world.effects.shake(0.3 * near, 0.35)
	boss.log_event(&"roof_eaten", {"roof": index, "cut": float(action.get("cut", 0.0)), "end": float(action.get("edge", 0.0))})


# --- The volleys --------------------------------------------------------------------------------

## The track distances of up to `count` spots, `spacing` apart, from the first a runner who can first switch at
## `s_open` has room to dodge (every escape switch and the margin), and whose throw comes no sooner than `free_at` (a
## roof's spot: never a circle in their lane before they can switch there), short of `limit`.
func _spot_places(s_open: float, count: int, limit: float, speed: float, free_at: float = -MechaGuppyClimb.FAR) -> Array[float]:
	var out: Array[float] = []
	var t: MovementTuning = world.tuning
	var first: float = s_open + (tuning.max_escape_lanes * t.lane_switch_time + tuning.dodge_margin + 0.05) * speed \
		+ tuning.blast_depth * 0.5 + t.hurtbox_size.z * 0.5
	first = maxf(first, free_at + (tuning.lock_seconds + tuning.arrival_seconds) * speed)
	var spacing: float = tuning.spot_spacing * t.pace()
	for i: int in count:
		var at: float = first + spacing * float(i)
		if at > limit:
			break
		out.append(at)
	return out


## Where a spot on roof k + 1 may lie at the latest: short of the next hut (its blast and its clearance), passed before
## the roof's notch with time to leave its lane before the edge (a dodge may have taken the runner there; task E5e-b3's
## review: with no bait, a spot near the notch sent its escape into the lane about to end), and passed in time for a
## runner to cross to the bait's notch from any lane before the bait locks (bait_after).
func _limit(step: MechaGuppyClimb.Step, speed: float) -> float:
	if step.index + 1 >= climb.steps.size():
		return -MechaGuppyClimb.FAR
	var next: MechaGuppyClimb.Step = climb.steps[step.index + 1]
	if next.top:
		return climb.roofs[step.index + 1].end - 10.0
	var limit: float = next.hut_start - tuning.hut_clear - tuning.blast_depth * 0.5 - tuning.floor_clear
	var past: float = tuning.blast_depth * 0.5 + world.tuning.hurtbox_size.z * 0.5 + MechaGuppyBombs.PAST_MARGIN
	var roof: MechaGuppyClimb.Roof = climb.roofs[step.index + 1]
	if roof.notched():
		limit = minf(limit, roof.notch_from - lock_to_edge() * speed - past)
	var plan: Dictionary = bait_plan(step, speed)
	if not plan.is_empty():
		limit = minf(limit, float(plan["lock_at"]) - bait_after() * speed - past)
	return limit


## Seconds a runner needs from a spot's blast to the bait's lock to get into its notch's lane from any lane: a reaction
## (dodge_reaction) and a lane switch for every lane but one.
func bait_after() -> float:
	return tuning.dodge_reaction + float(boss.lane_count() - 1) * world.tuning.lane_switch_time


## The volley on roof k + 1, thrown as the runner nears its first spot, never before the hut's deadline.
func _volley(step: MechaGuppyClimb.Step, p: Player) -> void:
	var key: String = "volley:%d" % step.index
	if _done.has(key) or step.index + 1 >= climb.steps.size():
		return
	var speed: float = maxf(p.speed, 1.0)
	var places: Dictionary = _volley_places(step, speed)
	var ats: Array[float] = places["ats"]
	if ats.is_empty():
		_done[key] = true
		return
	var lock_at: float = maxf(ats[0] - (tuning.lock_seconds + tuning.arrival_seconds) * speed, step.deadline)
	if p.distance < lock_at:
		return
	_done[key] = true
	if p.distance > ats[0] or p.distance > lock_at + STALE:
		return
	# A landing spot is thrown at a rider up on the hut (dropping off its end they dodge it in the air); none for a
	# runner who isn't there.
	if bool(places["landing"]) and p.surface != Player.Surface.CEILING and p.distance < step.deadline - 1.0:
		return
	var plan: Dictionary = volley(step, p.lane, p.distance, speed)
	boss.bombs.throw_spots(MechaGuppyBombs.Kind.SPOT, step.index, plan["spots"], float(plan["s_open"]))


## Where the runner is as step `step`'s volley is thrown (FAR with none: no room, or a phase without one).
func volley_lock(step: MechaGuppyClimb.Step, speed: float) -> float:
	if step.index + 1 >= climb.steps.size():
		return MechaGuppyClimb.FAR
	var ats: Array[float] = _volley_places(step, maxf(speed, 1.0))["ats"]
	if ats.is_empty():
		return MechaGuppyClimb.FAR
	return maxf(ats[0] - (tuning.lock_seconds + tuning.arrival_seconds) * maxf(speed, 1.0), step.deadline)


## Step `step`'s volley on roof k + 1 as it would be thrown at a runner in `lane` at `d0` running at `speed` (the pattern
## throws it so; the tests plan it from every lane): {spots (MechaGuppyBombs.plan_spots'), s_open (where the runner can
## first switch to dodge it: off the hut's end in the air with a landing spot, else their landing or where the roof is
## full width beside a pier), landing (its first spot is the landing spot), lock_at (where the runner is as it's
## thrown)}; no spots in a phase without them, or with no room for one.
func volley(step: MechaGuppyClimb.Step, lane: int, d0: float, speed: float) -> Dictionary:
	speed = maxf(speed, 1.0)
	var places: Dictionary = _volley_places(step, speed)
	var ats: Array[float] = places["ats"]
	var spots: Array[Dictionary] = []
	var lock_at: float = MechaGuppyClimb.FAR
	if not ats.is_empty():
		var seed: int = hash([boss.def.rng_key(), "volley", step.index, boss.lane_count()])
		spots = boss.bombs.plan_spots(lane, d0, float(places["s_open"]), ats, climb.roofs[step.index + 1].top,
			boss.phase_index, seed, speed)
		lock_at = maxf(ats[0] - (tuning.lock_seconds + tuning.arrival_seconds) * speed, step.deadline)
	return {"spots": spots, "s_open": float(places["s_open"]), "landing": bool(places["landing"]), "lock_at": lock_at}


## Where step `step`'s volley lands: {ats (nearest first), s_open, landing (true if its first spot is the landing spot)}.
func _volley_places(step: MechaGuppyClimb.Step, speed: float) -> Dictionary:
	var roof: MechaGuppyClimb.Roof = climb.roofs[step.index + 1]
	var limit: float = _limit(step, speed)
	var on_roof: int = MechaGuppyTuning.per_phase(tuning.roof_spots, boss.phase_index)
	var landing: Array[float] = _landing_places(step, speed, limit)
	if not landing.is_empty():
		var ats: Array[float] = landing.duplicate()
		var spacing: float = tuning.spot_spacing * world.tuning.pace()
		for i: int in on_roof:
			var at: float = ats[-1] + spacing
			if at > limit:
				break
			ats.append(at)
		return {"ats": ats, "s_open": _drop(step), "landing": true}
	var s_open: float = maxf(step.land, roof.full_from())
	var out: Array[float] = []
	if on_roof > 0:
		out = _spot_places(s_open, on_roof, limit, speed, step.free_at)
	return {"ats": out, "s_open": s_open, "landing": false}


## Where a rider drops off step `step`'s hut: where the lanes that lead up end (RUN_ON runs them on, REACH_BACK ends
## them all), past the foot's reach.
func _drop(step: MechaGuppyClimb.Step) -> float:
	return (step.hut_end() if step.cue == MechaGuppyClimb.Cue.RUN_ON else step.deadline) + world.tuning.foot_half_depth


## Where the landing spots lie (landing_spots of them, the first no nearer than the landing): room to dodge from the
## drop, short of `limit`. Only on a RUN_ON step: its riders drop off the hut's lanes that run on, well past the
## deadline, over the higher roof's full width; a REACH_BACK step's riders drop at the deadline itself, before which no
## circle may show, so a spot thrown then would come down past where they land (its riders get the roof's spot).
func _landing_places(step: MechaGuppyClimb.Step, speed: float, limit: float) -> Array[float]:
	var count: int = MechaGuppyTuning.per_phase(tuning.landing_spots, boss.phase_index)
	if count <= 0 or step.cue != MechaGuppyClimb.Cue.RUN_ON:
		return []
	var ats: Array[float] = _spot_places(_drop(step), count, limit, speed)
	if not ats.is_empty():
		ats[0] = maxf(ats[0], step.land + tuning.blast_depth * 0.5 + 0.3)
		if ats[0] > limit:
			ats.clear()
	return ats


# --- The bait --------------------------------------------------------------------------------------

## Step `step`'s bait (see the header) for a runner at `speed`: {at (where its bomb comes down: catch_in into roof k + 1's
## notch), y (that roof's top), notch (the notch's lane), lock_at (where the runner is as it locks: lock_seconds and
## arrival_seconds before they get there), seek_at (bait_seek before that)}; {} where roof k + 1 has no notch, where the
## bomb couldn't land fairly beside the notch (on the roof's top, no hut near: MechaGuppyBombs.spot_floor), or where an
## extreme tuning breaks its promises (task E5e-b3's review): its aim shows only once the runner can switch lanes on
## that roof and has had a reaction (past Step.free_at, after the hut's deadline: never a circle in the lane of a runner
## who can't leave it, never a hint at the lanes that lead up), and a runner in the notch's lane as it locks has
## lock_to_edge() to leave it before its edge.
func bait_plan(step: MechaGuppyClimb.Step, speed: float) -> Dictionary:
	if step.top or step.index + 1 >= climb.roofs.size():
		return {}
	var roof: MechaGuppyClimb.Roof = climb.roofs[step.index + 1]
	if not roof.notched():
		return {}
	var at: float = roof.notch_from + tuning.catch_in
	var beside: int = roof.notch_lane + (1 if roof.notch_lane == 0 else -1)
	if not boss.bombs.spot_floor(beside, at, roof.top):
		return {}
	speed = maxf(speed, 1.0)
	var lock_at: float = at - (tuning.lock_seconds + tuning.arrival_seconds) * speed
	var seek_at: float = lock_at - tuning.bait_seek * speed
	if seek_at < maxf(step.free_at, step.deadline) + tuning.dodge_reaction * speed:
		return {}
	if (roof.notch_from - lock_at) / speed < lock_to_edge():
		return {}
	return {"at": at, "y": roof.top, "notch": roof.notch_lane, "lock_at": lock_at, "seek_at": seek_at}


## The least a runner in the notch's lane as the bait locks has to leave it before its edge (seconds): a reaction, a lane
## switch and dodge_margin.
func lock_to_edge() -> float:
	return tuning.dodge_reaction + world.tuning.lane_switch_time + tuning.dodge_margin


## The bait on roof k + 1: its aim follows the runner from seek_at (on that roof's floor), then it locks.
func _bait(step: MechaGuppyClimb.Step, p: Player) -> void:
	var key: String = "bait:%d" % step.index
	# Roof k + 1's notch is known once the step after it is planned.
	if _done.has(key) or step.index + 1 >= climb.steps.size():
		return
	var speed: float = maxf(p.speed, 1.0)
	var plan: Dictionary = bait_plan(step, speed)
	if plan.is_empty():
		_done[key] = true
		# A roof that could have had the bait but has no room for it (an extreme tuning) counts toward the fallback.
		if step.index + 1 >= MechaGuppyClimb.FIRST_NOTCH:
			_baitless[step.index] = true
		return
	if p.distance < float(plan["seek_at"]):
		return
	# A step already hit (its fallback came first) gets no bait: a hit at most one a step (task E5e-b3's review), and an
	# aim that follows the runner is always a chance at one.
	if _hit_steps.has(step.index):
		_done[key] = true
		boss.bombs.drop_bait()
		return
	# Stale (a review moved the runner on): past where its bomb comes down, or long past where it should have begun, or,
	# once it follows them, long past where it should have locked (task E5e-b3's review: a long bait_seek follows them
	# further than STALE).
	var seek_key: String = "seek:%d" % step.index
	var following: bool = _done.has(seek_key)
	if p.distance > float(plan["at"]) or p.distance > float(plan["lock_at" if following else "seek_at"]) + STALE:
		_done[key] = true
		boss.bombs.drop_bait()
		return
	if not following:
		_done[seek_key] = true
		_offered[step.index] = true
		boss.bombs.start_bait(step.index, float(plan["at"]), float(plan["y"]), int(plan["notch"]))
		boss.log_event(&"bait", {"step": step.index, "at": float(plan["at"]), "notch": int(plan["notch"]),
			"phase_step": climb.steps.size()})
	if p.distance < float(plan["lock_at"]):
		return
	_done[key] = true
	var d: Dictionary = boss.bombs.lock_bait()
	if not d.is_empty():
		boss.shark.catch_until(float(d["impact"]) + MechaGuppyShark.CATCH_AFTER)


# --- The fallback -------------------------------------------------------------------------------

## True if step `index`'s fallback is due (see the header): hits on, the pattern running, fallback_after steps in a row
## gone by without a hit, and this step neither hit, nor fallen on, nor its fallback done.
func fallback_due(index: int) -> bool:
	return hits_enabled and boss.attacks_live() and dry >= tuning.fallback_after and not _hit_steps.has(index) \
		and not _fell.has(index) and not _done.has("hit:%d" % index)


## The furthest the runner may be for step `step`'s fallback to be thrown at `speed`: its bomb still comes down
## FALLBACK_AHEAD ahead of them, fallback_flight() after the throw (never before the hut's deadline: -FAR without a
## spot).
func fallback_last(step: MechaGuppyClimb.Step, speed: float) -> float:
	var spot: Dictionary = hit_spot(step)
	if spot.is_empty():
		return -MechaGuppyClimb.FAR
	return maxf(float(spot["at"]) - (fallback_flight() + FALLBACK_AHEAD) * maxf(speed, 1.0), step.deadline)


## How long the fallback's bomb flies (seconds): hit_seconds, or longer where Mecha Guppy needs longer to surge up and
## open its jaws (MechaGuppyShark.MIN_RISE and breach_rise: task E5e-b3's review sweep, a slow breach_rise left every
## fallback to fall past still-opening jaws), with FALLBACK_OPEN to spare.
func fallback_flight() -> float:
	return maxf(tuning.hit_seconds, MechaGuppyShark.MIN_RISE + tuning.breach_rise + FALLBACK_OPEN)


## Once a rider is up on the hut (and the shark has bitten their roof), with the fallback due, it glides deep under where
## the fallback's breach will come, out of sight (MechaGuppyShark.lurk), so it can surge up in time.
func _lurk(step: MechaGuppyClimb.Step, p: Player) -> void:
	var key: String = "lurk:%d" % step.index
	if _done.has(key) or not fallback_due(step.index) or p.surface != Player.Surface.CEILING \
			or p.distance < step.pad or p.distance >= step.deadline or step.index + 1 >= climb.roofs.size() or boss.shark.busy():
		return
	_done[key] = true
	var spot: Dictionary = hit_spot(step)
	if spot.is_empty():
		return
	boss.shark.lurk({"x": world.geo.lane_x(int(spot["lane"])) + float(spot["x_off"]), "at": float(spot["at"]),
		"top": float(spot["y"]), "side": int(spot["side"]), "open_at": INF, "step": step.index})


## The fallback (see the header): from the hut's deadline, after fallback_after steps in a row without a hit, the bomb
## thrown at the chasm in front of roof k + 1 under the lanes that don't lead up, and Mecha Guppy rising there with its
## jaws open as it lands; only for a rider in a lane that leads up who hasn't fallen this step. Thrown only once the
## shark can rise there (task E5e-b3's review: a bomb thrown while it was still busy fell into an empty chasm): while
## it's still sinking from its bite, the fallback waits, as long as its bomb can still come down ahead of the runner
## (fallback_last); past that, it waits for the next step (dry still counting).
func _fallback(step: MechaGuppyClimb.Step, p: Player) -> void:
	var key: String = "hit:%d" % step.index
	if _done.has(key) or p.distance < step.deadline or step.index + 1 >= climb.roofs.size():
		return
	if p.distance > step.deadline + STALE or not hits_enabled or dry < tuning.fallback_after:
		_done[key] = true
		return
	if _fell.has(step.index) or not step.leads_up(p.lane) or not catch_ok():
		_done[key] = true
		boss.log_event(&"fallback_skipped", {"step": step.index, "lane": p.lane})
		return
	var spot: Dictionary = hit_spot(step)
	if spot.is_empty():
		_done[key] = true
		return
	if not boss.shark.can_breach(float(spot["y"])):
		if p.distance <= fallback_last(step, p.speed):
			return
		_done[key] = true
		boss.log_event(&"fallback_skipped", {"step": step.index, "lane": p.lane, "busy": true})
		return
	_done[key] = true
	var d: Dictionary = boss.bombs.throw_at(MechaGuppyBombs.Kind.HIT, int(spot["lane"]), float(spot["at"]), float(spot["y"]),
		float(spot["x_off"]), fallback_flight())
	boss.log_event(&"fallback", {"step": step.index, "dry": dry})
	boss.shark.breach({"x": float(d["x"]), "at": float(spot["at"]), "top": float(spot["y"]), "side": int(spot["side"]),
		"open_at": float(d["impact"]) - tuning.breach_early, "step": step.index})


## Where step `step`'s fallback lands: {lane (the lane that doesn't lead up beside the nearest that does, on the side
## with more of them; a seeded side on a tie), side (-1 left of the lanes that lead up, +1 right), x_off (from that lane's
## middle out to where the bomb falls: into the jaws of Mecha Guppy's head, which keeps lane_clear from the lanes that
## lead up, so on a narrow street it falls past the roof's side), at (hit_back before roof k + 1's front in that lane:
## over the chasm, the shark's head short of that roof's face), y (that roof's top)}; {} if every lane leads up (never:
## one always doesn't).
func hit_spot(step: MechaGuppyClimb.Step) -> Dictionary:
	var n: int = boss.lane_count()
	var left: int = step.up.x
	var right: int = n - 1 - step.up.y
	if left <= 0 and right <= 0:
		return {}
	var side: int = -1
	if right > left:
		side = 1
	elif right == left:
		side = -1 if hash([boss.def.rng_key(), "hit", step.index]) % 2 == 0 else 1
	var lane: int = step.up.x - 1 if side < 0 else step.up.y + 1
	var roof: MechaGuppyClimb.Roof = climb.roofs[step.index + 1]
	var geo: TrackGeometry = world.geo
	var edge: float = geo.lane_x(step.up.x) - geo.lane_width * 0.5 if side < 0 else geo.lane_x(step.up.y) + geo.lane_width * 0.5
	var x: float = edge + side * (tuning.lane_clear + MechaGuppySharkModel.HALF_DEPTH * MechaGuppyShark.SCALE
		+ MechaGuppyShark.MOUTH_OUT)
	return {"lane": lane, "side": side, "x_off": x - geo.lane_x(lane), "at": roof.start_in(lane) - tuning.hit_back,
		"y": roof.top}
