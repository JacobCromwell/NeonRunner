class_name MechaGuppyBiteChecks
extends RefCounted
## The floor bite's promises on a climb's plan (GDD §10, the owner, October 11, 2026: "The floor bite"; task E5e-f;
## MechaGuppyClimb, MechaGuppyCrescent), for the suites (test_mecha_guppy_floor_bite, test_mecha_guppy_tunables at both ends
## of every tunable's range). Pure: the plan alone, no engine. For every roof the plan has planned the step from:
## - a bite on roof FIRST_BITE and every other roof from FIRST_NOTCH on (MechaGuppyClimb.bitten), none elsewhere;
## - its shape: a crescent from one side, deepest in the middle, shallower at its front and back; one that leaves a lane
##   takes every lane but the far side's outer one at its deepest (2 of 3, 4 of 5, 5 of 6), fewer near its ends, and never
##   that lane; a full-width one (phase 2 only, never before the first notch) takes every lane at its deepest, and its
##   longest stretch along the track in every lane is at most full_jump_share of a full jump (shorter than a normal jump
##   covers), the bitten side's the longest and the far side's the shortest;
## - where: past where its riders can first switch by the crossing (every switch from the farthest lane and dodge_margin),
##   and past a reaction after the hut's deadline by it too; past their landing; short of the roof's pads; on a notched
##   roof short of the notch, with time to cross back to the notch's lane before the bait locks (and its aim only past the
##   bite), the notch on its side (the lane it leaves is never the notch's);
## - when: its warning never before the hut's deadline, giving a reaction and the crossing from where the riders can first
##   switch, and Mecha Guppy its rise and lunge before the snap; the snap before the runner reaches it, and before the
##   earliest take-off over a full-width one;
## - its sides seeded, never three running on the same side.

## Distances' slack in the comparisons (metres).
const EPS: float = 0.01


## The first broken promise of the floor bites in plan `c` (with tuning `t`), or "".
static func plan_problem(c: MechaGuppyClimb, t: MechaGuppyTuning) -> String:
	var v: float = c.speed
	var h: float = c.movement.hurtbox_size.z * 0.5
	var crossing: float = c.bite_crossing()
	var jump: float = c.jump_seconds() * v
	var sides: Array[int] = []
	for k: int in range(1, c.steps.size()):
		var step: MechaGuppyClimb.Step = c.steps[k]
		var roof: MechaGuppyClimb.Roof = c.roofs[k]
		var into: MechaGuppyClimb.Step = c.steps[k - 1]
		var bite: MechaGuppyCrescent = roof.bite
		if step.top:
			if bite != null:
				return "roof %d (the top's) has a floor bite" % k
			continue
		if (bite != null) != MechaGuppyClimb.bitten(k):
			return "roof %d %s a floor bite" % [k, "has" if bite != null else "lacks"]
		if bite == null:
			continue
		var why: String = shape_problem(c, t, bite, step.phase)
		if why != "":
			return "roof %d: %s" % [k, why]
		sides.append(bite.side)
		if sides.size() >= 3 and sides[-1] == sides[-2] and sides[-2] == sides[-3]:
			return "roof %d: a third bite running from the same side" % k
		# Where.
		if bite.from < into.free_at + crossing - EPS:
			return "roof %d: its bite %.2f s short of a crossing from where its riders can first switch" \
				% [k, (into.free_at + crossing - bite.from) / v]
		if bite.from < into.deadline + (t.dodge_reaction + MechaGuppyClimb.WARN_SLACK) * v + crossing - EPS:
			return "roof %d: its bite short of a reaction and a crossing after the hut's deadline" % k
		if bite.from < maxf(into.land, roof.full_from()) + MechaGuppyClimb.LAND_CLEAR - EPS:
			return "roof %d: its bite eats its riders' landing" % k
		if bite.to >= step.pad - EPS:
			return "roof %d: its bite eats its pads" % k
		if roof.notched():
			if roof.notch_side() != bite.side or bite.keep == roof.notch_lane:
				return "roof %d: the lane its bite leaves is the notch's" % k
			if bite.to + h > roof.notch_from - EPS:
				return "roof %d: its bite reaches its notch" % k
			var lock: float = roof.notch_from + t.catch_in - (t.lock_seconds + t.arrival_seconds) * v
			var bait_after: float = t.dodge_reaction + float(c.lanes - 1) * c.movement.lane_switch_time
			if lock < bite.to + h + maxf(bait_after, t.bait_seek) * v - EPS:
				return "roof %d: the bait locks %.2f s after its bite, short of a crossing back to the notch" \
					% [k, (lock - bite.to - h) / v]
		# When.
		if bite.warn_at < into.deadline - EPS:
			return "roof %d: its warning before the hut's deadline" % k
		if maxf(bite.warn_at + t.dodge_reaction * v, into.free_at) + crossing > bite.from + EPS:
			return "roof %d: its warning too late for a reaction and the crossing" % k
		if bite.snap_at - bite.warn_at < c.bite_chain() * v - EPS:
			return "roof %d: its warning too late for Mecha Guppy to rise and lunge" % k
		if bite.snap_at >= bite.from - EPS:
			return "roof %d: its snap not before the runner reaches it" % k
		if bite.full and bite.snap_at > bite.from + (bite.to - bite.from) - jump - MechaGuppyClimb.SNAP_CLEAR + EPS:
			return "roof %d: its snap after the earliest take-off over it" % k
	return ""


## The first broken promise of bite `bite`'s shape (planned in phase `phase`), or "".
static func shape_problem(c: MechaGuppyClimb, t: MechaGuppyTuning, bite: MechaGuppyCrescent, phase: int) -> String:
	var n: int = c.lanes
	var length: float = bite.to - bite.from
	var mid: float = (bite.from + bite.to) * 0.5
	# A crescent: deepest in the middle, shallower toward its ends, on its own side.
	if bite.side != -1 and bite.side != 1:
		return "its side %d" % bite.side
	var deep_mid: float = bite.depth_at(mid)
	var deep_front: float = bite.depth_at(bite.from + length * 0.15)
	var deep_back: float = bite.depth_at(bite.to - length * 0.15)
	if not (deep_mid > deep_front + 0.5 and deep_mid > deep_back + 0.5) and not bite.full:
		return "not deepest in the middle (%.1f m against %.1f and %.1f)" % [deep_mid, deep_front, deep_back]
	if absf(bite.deepest() - deep_mid) > 0.05 and not bite.full:
		return "its deepest point isn't its middle"
	var at_mid: Array[int] = bite.taken_at(mid)
	var near_end: int = maxi(bite.taken_at(bite.from + length * 0.08).size(), bite.taken_at(bite.to - length * 0.08).size())
	if bite.full:
		if phase < 1 or bite.roof < MechaGuppyClimb.FIRST_NOTCH:
			return "a full-width bite in phase %d on roof %d" % [phase + 1, bite.roof]
		if at_mid.size() != n or not bite.left().is_empty():
			return "a full-width bite leaves lanes %s" % [bite.left()]
		var jump: float = c.jump_seconds() * c.speed
		var longest: float = 0.0
		var lengths: Array[float] = []
		for lane: int in n:
			var s: Vector2 = bite.lane_stretch(lane)
			var l: float = s.y - s.x if s.x <= s.y else 0.0
			lengths.append(l)
			longest = maxf(longest, l)
			if l > jump * t.full_jump_share + EPS or l >= jump - EPS:
				return "lane %d's stretch %.1f m against a jump's %.1f m" % [lane, l, jump]
		var bitten_side: int = 0 if bite.side < 0 else n - 1
		var far_side: int = n - 1 - bitten_side
		if lengths[bitten_side] < longest - EPS or lengths[far_side] > lengths.min() + EPS:
			return "its stretches aren't longest on the bitten side, shortest on the far side (%s)" % [lengths]
		return ""
	var keep: int = n - 1 if bite.side < 0 else 0
	if phase >= 1 and t.full_every > 0 and bite.roof >= MechaGuppyClimb.FIRST_NOTCH \
			and (bite.roof >> 1) % t.full_every == 0:
		return "phase 2's bite on roof %d should cross every lane" % bite.roof
	if bite.keep != keep or bite.left() != [keep]:
		return "it leaves lanes %s, not the far side's outer lane %d" % [bite.left(), keep]
	if at_mid.size() != n - 1 or at_mid.has(keep):
		return "at its deepest it takes lanes %s" % [at_mid]
	if near_end >= at_mid.size():
		return "as many lanes taken near its ends as at its deepest"
	return ""
