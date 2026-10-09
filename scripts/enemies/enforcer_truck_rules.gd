extends RefCounted
## Generator rules for the Enforcer Truck (GDD §9.13, owner, October 4, 2026). It can only be destroyed by
## baiting an Octodog's lunge or a Buzz Overdrive's charge into it, so it is placed around those charges:
## "each one is placed only where at least one Octodog or Buzz Overdrive charge comes during its chase, so it
## always has a chance to be destroyed". LevelGenerator runs apply() for levels with the `enforcer_truck`
## feature after the rules of every other feature (RUN_AFTER): the Octodogs' planned charges and the Buzz
## Overdrives' cuts are final by then (nothing later moves or drops them).
## - Its baits: each Octodog's first planned wind-up (params "charge_at"; its later charges come after it) and
##   each Buzz Overdrive's charge (its cut's charge_at, FloorCutPlan). A truck arrives (its entry's `at`: the
##   runner's distance as it drives in behind them) so that a bait's warning (the wind-up, the rev) comes
##   bait_after_seconds or more after it (it has settled behind the runner) and its charge bait_before_seconds
##   or more before the truck would give up; where it can, the bait's hold (EnforcerTruckTuning.hold_seconds()
##   before its warning, when the truck stops firing for it) comes at a seeded spot bait_prefer_min/max_seconds
##   after it: the runner meets it, sees a volley or two, then the bait. Its params list every bait planned in
##   its chase ("baits").
## - Up to per_level_max a level (GDD §9.13: up to two), never two at once: each one's chase, and the
##   seconds it takes to drop back, keep spacing_seconds from the next one's arrival. The level's earliest
##   baits get them first (with its showing windows planned, those whose chases have room for its showing before
##   their bait: below).
## - Where it may arrive: after the run-up and the feature's start, and never while another bait attacks (an
##   Octodog's planned charges, a Buzz Overdrive's rev and charge). In a level paced in bursts (The Hush) it
##   arrives in a burst where it can (LevelGenerator.pacing_pools). Its chase may run on to the level's end.
##   Its entry's `at` is where it arrives, never a spot it takes up ahead of the runner
##   (EnemyTuning.behind_runner), so no Octodog's charge keeps clear of it.
## - Its showing window (task C6c; GDD §9.13 "Showing itself", the owner, October 8, 2026: now and then it speeds
##   up until it's on screen, so the player sees what's behind them): each chase gets, where the level has room, a
##   calm stretch where it can pull up beside the runner and stay alongside wherever the runner is, at the level's
##   speed (ShowPlanner): no other big attack, floor cut or enemy about near the runner until it has stayed
##   alongside (their keep-outs; a host's possible Bad Dream chase is the player's choice, and doesn't count), no
##   hover truck or Gilded Sentinel coming, its bait's turn far enough off, and for a runner in every lane a lane
##   beside them where its look fits on screen and its lane stays clear for the whole stay, the runner keeps a lane
##   to dodge into and it hides no enemy (EnforcerTruckRoom.layout_lane, the checks it makes in play), also when it
##   begins show_window_slack_seconds late; first one where no runner is sent off the floor (a pad's ceiling, a
##   ramp's wall run) before it has stayed alongside, else one where a runner in that lane may miss it. As it
##   arrives (its arrival showing) where any of its arrivals has one, else the earliest mid-chase one before its
##   first bait, else one after it; the arrival moves to where one fits (the preferred arrival first, then every
##   other the bait allows, the earliest too). Which baits get trucks (task C6d; the owner, October 9, 2026, GDD
##   §9.13 "Room to show itself": it shows itself before the player can bait it, and a chase with no room for that
##   gives its truck to another bait's chase that has room): the ones whose chases hold the most windows before
##   their first bait, then the most windows, then the most chases (_choose; a pair is also planned with the later
##   window first, the earlier truck arriving earlier around it); the level's introduction keeps its first bait's
##   chase where that has room before its bait, and otherwise moves only to a chase where it shows itself before its
##   bait. Where the level leaves none, it takes out what's in the way
##   (ShowPlanner's class doc). Its params hold it ("show": {at: where
##   the runner is as it begins, from and to: the stretch it keeps}), and every later pass keeps off it in every
##   lane as a calm stretch, WINDOW_EDGE wider (doodad_keep_outs: nothing they add may stand or attack in it, but
##   nothing keeps a spacing from it: the danger density pass's enemies and rows, the cyborgs in charge paths, the
##   wider gaps' rows, the zone doodads, City 1's extra gaps; fill_keep_outs: the fill pass). A Buzz Overdrive
##   given a cyborg in its charge's path later claims its turn earlier: the windows are planned as if every one
##   would (ShowPlanner.least_claim). In play the truck claims its turn ahead of its window and holds its volleys
##   for it (EnforcerTruck.claiming, show_window). gen.show_window_result reports each chase's.
## It takes little room on the track: it drives behind the runner, never on the floor ahead (its tuning's
## uses_floor is false), and its volleys check their escape at run time (EnforcerTruck.escape_clear). So the
## passes keep nothing else for it (keep_out), and its entries take seeds of their own rather than
## LevelGenerator.add_enemy's running count: a level with the feature differs only by its trucks and their showing
## windows (where those move its arrivals, what they take out and what they keep the later passes off), and by
## what the danger density pass adds for its higher enemy count. It has no patterns: these rules place every one. A
## level with no bait its chase can take gets none (GDD §9.13: it appears where Octodogs or Buzz Overdrives
## appear). DESIGN-TBD (docs/questions/c6.md): the bait's place in its chase, the spacing; (docs/OPEN_QUESTIONS.md items 400–403)
## a truck that no bait with room is left for (it keeps its chase, its window after the bait or none).

const TYPE: String = "enforcer_truck"
## Every feature whose rules place, move or drop enemies, plan charges or cuts, or add ceilings: the trucks
## are planned on the level's final baits.
const RUN_AFTER: Array[String] = ["ramps", "ceilings", "pulsing", "speed_pads", "cyborg", "window_cyborg", "host",
	"hover_truck", "octodog", "screech", "screech_vents", "drone", "generator", "wall_fences", "wall_fences_partial",
	"buzz_overdrive", "barnacle_turret", "tithe_collector", "resonator", "gilded_sentinel"]
const BuzzRules = preload("res://scripts/enemies/buzz_overdrive_rules.gd")
const HoverTruckRules = preload("res://scripts/enemies/hover_truck_rules.gd")
## Metres either side of a showing window that the later passes keep off too (doodad_keep_outs, fill_keep_outs): its
## checks count what touches the stretch they read.
const WINDOW_EDGE: float = 1.0
## The arrival offsets tried around the preferred one (seconds between them).
const OFFSET_STEP: float = 0.5


static func apply(gen: LevelGenerator) -> void:
	var t: EnforcerTruckTuning = tuning()
	if t.per_level_max <= 0:
		return
	var rng: RandomNumberGenerator = gen.rng_for(TYPE)
	var baits: Array[Dictionary] = bait_points(gen)
	var keep_outs: Array[Vector2] = arrival_keep_outs(gen)
	var planner: ShowPlanner = ShowPlanner.make(gen, t) if t.show_window_planned and t.show_count > 0 else null
	# Each bait's arrivals, best first (one draw each, in the baits' order).
	var orders: Array = []
	for b: Dictionary in baits:
		orders.append(_arrival_order(gen, t, rng, b))
	var chases: Array[Vector2] = []
	var report: Array[Dictionary] = []
	var by_bait: Array[Dictionary] = []
	if planner == null:
		# The earliest baits first.
		for i: int in baits.size():
			if report.size() >= t.per_level_max:
				break
			var spots: Array[float] = _usable(gen, t, orders[i], keep_outs, chases)
			if spots.is_empty():
				continue
			report.append(_place(gen, t, planner, baits, spots, {}, hash([gen.config.level_seed, TYPE, report.size()])))
			chases.append(chase_span(gen, t, float(report[-1]["at"])))
	else:
		# With its showing windows planned (tasks C6c, C6d): of every set of baits whose chases fit together, the one
		# with the most showing windows before their bait (then the most windows, then the most chases, then the
		# earliest baits) gets them; a level that introduces it keeps its earliest bait's where that has room, and
		# otherwise moves its introduction only to a chase where it shows itself before its bait.
		var chosen: Array[Dictionary] = _choose(gen, t, planner, orders, keep_outs, gen.feature_start(TYPE) > 0.0, baits,
			by_bait)
		for k: int in chosen.size():
			var o: Dictionary = chosen[k]
			if not planner.still_fits(o["plan"]):
				# Each window was planned on the level as it stood: one before took out the last but one of a kind this
				# one would take out too. Planned again on the level as it stands now, around the other chases.
				var others: Array[Vector2] = []
				for j: int in chosen.size():
					if j != k:
						others.append(chosen[j]["span"])
				var bait: int = int(o["bait"])
				o = _option(gen, t, planner, orders[bait], keep_outs, others, baits[bait])
				o["bait"] = bait
				chosen[k] = o
			planner.why_none = String(o["why"])
			report.append(_place(gen, t, planner, baits, o["spots"], o["plan"],
				hash([gen.config.level_seed, TYPE, report.size()])))
			report[-1]["bait"] = float(baits[int(o["bait"])]["at"])
	gen.show_window_result = {"planned": planner != null, "chases": report, "baits": by_bait}


## The chases a level gets (tasks C6c, C6d), along the track: of every set of at most per_level_max baits (`orders`:
## each one's arrivals, _arrival_order) whose chases keep spacing_seconds apart, the one with the most showing
## windows before their chase's first bait (GDD §9.13 "Room to show itself", the owner, October 9, 2026: it shows
## itself before the player can bait it, and a chase with no room for a showing gives its truck to another bait's
## chase that has room), then the most showing windows, then the most chases, then the earliest baits. With
## `intro` (a level's introduction of the truck), its first bait that may have one keeps its truck where that
## chase has a window before its bait; else the introduction may move, to a chase where it shows itself before its
## bait. Each chase's window is planned as the level stands (ShowPlanner.plan tries every arrival the bait allows,
## the earliest too, for one before the bait).
## A set fits where its chases do planned along the track, each one again around the chases before it where those
## take its arrival away (_plan_set); planned the other way round too, a later chase's window first and the earlier
## trucks arriving earlier around it, where that gives more windows. Each: {spots, plan, at, span, why, bait (its
## index in `orders`)}. `report` gets each bait's own chase ({at: its charge, chase: the arrival, span, window:
## "before", "after" or "", chosen}) for gen.show_window_result.
static func _choose(gen: LevelGenerator, t: EnforcerTruckTuning, planner: ShowPlanner, orders: Array,
		keep_outs: Array[Vector2], intro: bool, baits: Array[Dictionary], report: Array[Dictionary]) -> Array[Dictionary]:
	var alone: Array[Dictionary] = []
	var usable: Array[int] = []
	for i: int in orders.size():
		alone.append(_option(gen, t, planner, orders[i], keep_outs, [], baits[i]))
		if not alone[i].is_empty():
			alone[i]["bait"] = i
			usable.append(i)
	# The introduction keeps its first bait's chase where that chase has room to show itself before its bait.
	var keep: int = usable[0] if intro and not usable.is_empty() and _before_bait(alone[usable[0]]) else -1
	var sets: Array = [[]]
	for i: int in usable:
		var grown: Array = []
		for set_: Array in sets:
			if set_.size() < t.per_level_max:
				grown.append(set_ + [i])
		sets.append_array(grown)
	var best: Array[Dictionary] = []
	var best_score := Vector3i(-1, -1, -1)
	var best_key: Array[int] = []
	for set_: Array in sets:
		if keep >= 0 and not set_.has(keep):
			continue
		var key: Array[int] = []
		key.assign(set_)
		# Along the track first: a set that doesn't fit so isn't one (the other orders only move its arrivals).
		var plans: Array[Dictionary] = [_plan_set(gen, t, planner, orders, keep_outs, alone, key, -1, baits)]
		if plans[0].is_empty():
			continue
		# A later chase's window planned first, the earlier trucks arriving earlier around it.
		for k: int in range(1, key.size()):
			plans.append(_plan_set(gen, t, planner, orders, keep_outs, alone, key, key[k], baits))
		# An introduction moved off its first bait goes to a chase where it shows itself before its bait.
		var moved: bool = intro and not key.is_empty() and key[0] != usable[0]
		var plan: Dictionary = {}
		for p: Dictionary in plans:
			if p.is_empty() or (moved and not _before_bait((p["picked"] as Array)[0])):
				continue
			if plan.is_empty() or (p["score"] as Vector3i) > (plan["score"] as Vector3i):
				plan = p
		if plan.is_empty():
			continue
		var score: Vector3i = plan["score"]
		if score > best_score or (score == best_score and _earlier(key, best_key)):
			best_score = score
			best_key = key
			best = plan["picked"]
	for i: int in orders.size():
		var o: Dictionary = alone[i]
		report.append({"at": float(baits[i]["at"]), "chase": float(o.get("at", INF)),
			"span": o.get("span", Vector2(INF, -INF)),
			"window": "" if o.is_empty() or (o["plan"] as Dictionary).is_empty() else ("before" if _before_bait(o) else "after"),
			"chosen": best_key.has(i)})
	return best


## The chases of the baits `set_` (indices in `orders`, along the track) planned together: `first` (one of them; -1:
## none) planned alone first, then the others along the track, each one's arrivals kept off the chases planned before
## it (its own window planned again where those take its arrival away: an earlier truck arrives earlier, a later one
## later). {picked: the options along the track, score: Vector3i(windows before the bait, windows, chases)}, or {}
## where one of them has nowhere to arrive.
static func _plan_set(gen: LevelGenerator, t: EnforcerTruckTuning, planner: ShowPlanner, orders: Array,
		keep_outs: Array[Vector2], alone: Array[Dictionary], set_: Array[int], first: int,
		baits: Array[Dictionary]) -> Dictionary:
	var order: Array[int] = set_.duplicate()
	if first >= 0:
		order.erase(first)
		order.push_front(first)
	var chases: Array[Vector2] = []
	var by: Dictionary = {}
	for i: int in order:
		var o: Dictionary = alone[i]
		if arrival_problem(gen, t, float(o["at"]), [], chases, _calm(o)) != "":
			o = _option(gen, t, planner, orders[i], keep_outs, chases, baits[i])
			if o.is_empty():
				return {}
			o["bait"] = i
		by[i] = o
		chases.append(o["span"])
	var picked: Array[Dictionary] = []
	var score := Vector3i(0, 0, set_.size())
	for i: int in set_:
		var o: Dictionary = by[i]
		picked.append(o)
		score += Vector3i(1 if _before_bait(o) else 0, 0 if (o["plan"] as Dictionary).is_empty() else 1, 0)
	return {"picked": picked, "score": score}


## True if option `o` (_option) has a showing window that comes before its chase's first bait (not after_bait).
static func _before_bait(o: Dictionary) -> bool:
	var plan: Dictionary = o.get("plan", {})
	return not plan.is_empty() and not bool(plan.get("after_bait", false))


## One bait's chase (_choose): where it may arrive (its `order` kept to where none of `chases` and `keep_outs` is in
## the way; and, for bait `bait`, inside the level's calm start, _calm_spots, task C6e), its showing window if one fits
## (ShowPlanner.plan), and where it arrives then. {} if it may arrive nowhere.
static func _option(gen: LevelGenerator, t: EnforcerTruckTuning, planner: ShowPlanner, order: Array[float],
		keep_outs: Array[Vector2], chases: Array[Vector2], bait: Dictionary = {}) -> Dictionary:
	var spots: Array[float] = _usable(gen, t, order, keep_outs, chases)
	var calm: Array[float] = []
	if not bait.is_empty():
		calm = _calm_spots(gen, t, bait, keep_outs, chases)
	if spots.is_empty() and calm.is_empty():
		return {}
	var plan: Dictionary = planner.plan(spots, 0, calm)
	if plan.is_empty() and spots.is_empty():
		return {}
	var at: float = float(plan["arrive"]) if not plan.is_empty() else spots[0]
	return {"spots": spots, "plan": plan, "at": at, "span": chase_span(gen, t, at), "why": planner.why_none}


## True if option `o` (_option) arrives inside the level's calm start (its window planned there, task C6e).
static func _calm(o: Dictionary) -> bool:
	return int((o.get("plan", {}) as Dictionary).get("mode", ShowPlanner.Mode.CLASSIC)) == ShowPlanner.Mode.CALM


## Where a truck whose chase takes bait `b` (bait_points) may arrive inside the level's calm start (task C6e; the owner,
## October 9, 2026, GDD §9.13 "Making room where there is none": where a level's first bait comes right after its calm
## start, the truck arrives a few seconds early and shows itself in the last part of it, the bait staying where it is):
## inside the run-up, from calm_start_min_seconds into the run (the player under way) and the feature's start, where
## the bait suits its chase (in_chase) and it may arrive (arrival_problem's calm start), on _arrival_order's grid
## (OFFSET_STEP steps back from the bait's hold) and at the earliest it may, latest first. ShowPlanner.plan tries them
## where no window fits before the bait otherwise (its CALM mode).
static func _calm_spots(gen: LevelGenerator, t: EnforcerTruckTuning, b: Dictionary, keep_outs: Array[Vector2],
		chases: Array[Vector2]) -> Array[float]:
	var out: Array[float] = []
	var run_up: float = gen.config.start_clear_distance
	var earliest: float = maxf(t.calm_start_min_seconds * gen.speed, gen.feature_start(TYPE))
	if earliest >= run_up:
		return out
	var hold: float = float(b["hold"])
	var spots: Array[float] = []
	var o: float = t.bait_after_seconds - (float(b["warn"]) - hold) / gen.speed
	while hold - o * gen.speed > earliest + 0.001:
		spots.append(hold - o * gen.speed)
		o += OFFSET_STEP
	spots.append(earliest)
	for at: float in spots:
		if at < run_up - 0.001 and in_chase(gen, t, b, at) and arrival_problem(gen, t, at, keep_outs, chases, true) == "":
			out.append(at)
	return out


## True if the sorted bait indices `a` come before `b` (the earliest baits first).
static func _earlier(a: Array[int], b: Array[int]) -> bool:
	for k: int in mini(a.size(), b.size()):
		if a[k] != b[k]:
			return a[k] < b[k]
	return a.size() < b.size()


## Adds a truck arriving at `spots[0]`, or where showing window `plan` (ShowPlanner.plan) has it arrive, taking out
## what the window needs gone. Returns its line of the report: {at, preferred, arrivals, window, taken_out, why}
## (apply adds its bait's charge, `bait`).
static func _place(gen: LevelGenerator, t: EnforcerTruckTuning, planner: ShowPlanner, baits: Array[Dictionary],
		spots: Array[float], plan: Dictionary, seed: int) -> Dictionary:
	var at: float = spots[0] if not spots.is_empty() else float(plan["arrive"])
	var preferred: float = at
	var taken: int = 0
	var params := {}
	var mode: String = ""
	if not plan.is_empty():
		at = float(plan["arrive"])
		taken = planner.take_out(plan)
		mode = ShowPlanner.MODE_NAMES[int(plan.get("mode", ShowPlanner.Mode.CLASSIC))]
	params["baits"] = baits_in(gen, t, baits, at)
	if not plan.is_empty():
		var show: Dictionary = {"at": plan["at"], "from": plan["from"], "to": plan["to"]}
		if mode != "":
			# How it was planned (task C6e): the truck in play reads a window its bait's claim may come during ("claim",
			# "calm") and one in the calm start (it arrives at its follow gap there).
			show["mode"] = mode
		params["show"] = show
	gen.layout.enemies.append({"type": TYPE, "at": at, "lane": gen.layout.lane_count / 2, "side": 0,
		"seed": seed, "params": params})
	return {"at": at, "preferred": preferred, "arrivals": spots.size(),
		"window": {} if plan.is_empty() else {"at": plan["at"], "from": plan["from"], "to": plan["to"],
			"hold": plan["hold"], "arrival": plan["arrival"], "after_bait": plan.get("after_bait", false),
			"every_lane": plan["every_lane"], "mode": mode, "excused": plan.get("excused", [])},
		"taken_out": taken, "why": planner.why_none if planner != null and plan.is_empty() else ""}


static func tuning() -> EnforcerTruckTuning:
	var res: Resource = EnemyDirector.tuning_for(TYPE)
	return res as EnforcerTruckTuning if res is EnforcerTruckTuning else EnforcerTruckTuning.new()


## Every Enforcer Truck in the layout, along the track.
static func trucks_in(layout: LevelLayout) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in layout.enemies:
		if String(e.get("type", "")) == TYPE:
			out.append(e)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["at"]) < float(b["at"]))
	return out


## The level's baits, along the track (runner distances): {at (where its charge comes: an Octodog's first
## planned wind-up, a Buzz Overdrive's charge), warn (where its warning starts: the wind-up, the rev), hold
## (where the truck stops firing for it: hold_seconds() before its warning), kind, entry (its enemy entry)}.
static func bait_points(gen: LevelGenerator) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var hold: float = tuning().hold_seconds() * gen.speed
	for e: Dictionary in gen.layout.enemies:
		match String(e.get("type", "")):
			"octodog":
				var anchors: Array = (e.get("params", {}) as Dictionary).get("charge_at", [])
				if not anchors.is_empty():
					var a: float = float(anchors[0])
					out.append({"at": a, "warn": a, "hold": a - hold, "kind": "octodog", "entry": e})
			"buzz_overdrive":
				var cut: Dictionary = BuzzRules.cut_of(gen.layout, e)
				if not cut.is_empty():
					var warn: float = FloorCutPlan.warn_at(cut)
					out.append({"at": FloorCutPlan.charge_at(cut), "warn": warn, "hold": warn - hold, "kind": "buzz_overdrive",
						"entry": e})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["at"]) < float(b["at"]))
	return out


## The baits a truck arriving at `at` has in its chase (in_chase): where their charges come.
static func baits_in(gen: LevelGenerator, t: EnforcerTruckTuning, baits: Array[Dictionary], at: float) -> Array[float]:
	var out: Array[float] = []
	for b: Dictionary in baits:
		if in_chase(gen, t, b, at):
			out.append(float(b["at"]))
	return out


## True if bait `b` (bait_points) suits a truck arriving at `at`: its warning comes bait_after_seconds or more
## after the arrival (the truck has settled behind the runner), and its charge bait_before_seconds or more
## before the truck would give up.
static func in_chase(gen: LevelGenerator, t: EnforcerTruckTuning, b: Dictionary, at: float) -> bool:
	return float(b["warn"]) >= at + t.bait_after_seconds * gen.speed - 0.001 \
		and float(b["at"]) <= at + (t.chase_seconds - t.bait_before_seconds) * gen.speed + 0.001


## The track a truck arriving at `at` takes up: its chase and its drop back out of sight.
static func chase_span(gen: LevelGenerator, t: EnforcerTruckTuning, at: float) -> Vector2:
	return Vector2(at, at + (t.chase_seconds + t.leave_seconds) * gen.speed)


## Where no truck may arrive (it would drive in while a bait attacks): each Octodog's planned charges (from a
## little before its first wind-up to the end of its last charge's stretch), each Buzz Overdrive's attack (from
## its rev's warning to the end of its cut, FloorCutPlan.attack_window). (Its entry never holds back an Octodog
## whose charges a wait moved on: Octodog.charge_clear leaves out enemies that only drive behind the runner,
## EnemyTuning.behind_runner.)
static func arrival_keep_outs(gen: LevelGenerator) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var dog := EnemyDirector.tuning_for("octodog") as OctodogTuning
	if dog == null:
		dog = OctodogTuning.new()
	var window: float = dog.window_length(gen.speed, gen.config.enemy_scaling, gen.pace)
	for e: Dictionary in gen.layout.enemies:
		match String(e.get("type", "")):
			"octodog":
				var anchors: Array = (e.get("params", {}) as Dictionary).get("charge_at", [])
				if not anchors.is_empty():
					out.append(Vector2(float(anchors[0]) - gen.metres(Octodog.OTHER_ENEMY_BEFORE),
						float(anchors[-1]) + window))
			"buzz_overdrive":
				var cut: Dictionary = BuzzRules.cut_of(gen.layout, e)
				if not cut.is_empty():
					out.append(FloorCutPlan.attack_window(cut, gen.speed))
	return out


## Where a truck whose chase takes bait `b` (bait_points) may arrive as far as the bait goes (in_chase), best first
## ([]: nowhere): the preferred spot first (a seeded one bait_prefer_min/max_seconds before the bait's hold), then the
## others in OFFSET_STEP steps nearest to it first; in a level paced in bursts, those in a burst before the rest.
## _usable keeps those where it may arrive; the first of them is where it arrives, unless its showing window fits
## only at another (ShowPlanner, task C6c).
static func _arrival_order(gen: LevelGenerator, t: EnforcerTruckTuning, rng: RandomNumberGenerator,
		b: Dictionary) -> Array[float]:
	var out: Array[float] = []
	# Offsets: seconds from the arrival to the bait's hold (in_chase's limits).
	var hold: float = float(b["hold"])
	var lo: float = t.bait_after_seconds - (float(b["warn"]) - hold) / gen.speed
	var hi: float = t.chase_seconds - t.bait_before_seconds - (float(b["at"]) - hold) / gen.speed
	if hi < lo - 0.001:
		return out
	var prefer: float = clampf(rng.randf_range(t.bait_prefer_min_seconds, t.bait_prefer_max_seconds), lo, hi)
	var offsets: Array[float] = []
	var o: float = lo
	while o <= hi + 0.001:
		offsets.append(o)
		o += OFFSET_STEP
	offsets.sort_custom(func(a: float, b: float) -> bool: return absf(a - prefer) < absf(b - prefer))
	offsets.push_front(prefer)
	var spots: Array[float] = []
	for off: float in offsets:
		spots.append(hold - off * gen.speed)
	for pool: Array[float] in gen.pacing_pools(spots, TYPE):
		for at: float in pool:
			if not out.has(at):
				out.append(at)
	return out


## The spots of `order` (_arrival_order) where a truck may arrive (arrival_problem), in order.
static func _usable(gen: LevelGenerator, t: EnforcerTruckTuning, order: Array[float], keep_outs: Array[Vector2],
		chases: Array[Vector2]) -> Array[float]:
	var out: Array[float] = []
	for at: float in order:
		if arrival_problem(gen, t, at, keep_outs, chases) == "":
			out.append(at)
	return out


## Why a truck can't arrive at `at` ("" if it can): before the run-up or the feature's start, an Octodog's
## charges or a Buzz Overdrive's attack there (keep_outs), or another truck's chase (with spacing_seconds). With `calm`
## (a truck showing itself in the level's calm start, task C6e: _calm_spots), inside the run-up instead, from
## calm_start_min_seconds into the run (the player under way) and the feature's start.
static func arrival_problem(gen: LevelGenerator, t: EnforcerTruckTuning, at: float, keep_outs: Array[Vector2],
		chases: Array[Vector2], calm: bool = false) -> String:
	if calm:
		if at < maxf(t.calm_start_min_seconds * gen.speed, gen.feature_start(TYPE)) - 0.001:
			return "before calm_start_min_seconds into the run or the feature's start"
		if at > gen.config.start_clear_distance + 0.001:
			return "past the calm start"
	elif at < maxf(gen.config.start_clear_distance, gen.feature_start(TYPE)) - 0.001:
		return "before the run-up or the feature's start"
	for k: Vector2 in keep_outs:
		if at >= k.x and at <= k.y:
			return "an Octodog's charges or a Buzz Overdrive's attack is on"
	var span: Vector2 = chase_span(gen, t, at)
	var room: float = t.spacing_seconds * gen.speed
	for c: Vector2 in chases:
		if span.x < c.y + room and span.y + room > c.x:
			return "another Enforcer Truck's chase is on"
	return ""


## What the generator keeps off around a truck's entry as around an enemy (LevelGenerator.enemy_keep_out: the
## fill pass's margin, the wall fences' calm): nothing (an empty span). It drives behind the runner, never on the
## floor ahead, and its volleys find their own escape at run time. What its showing window keeps is
## doodad_keep_outs' and show_windows' (task C6c).
static func keep_out(_gen: LevelGenerator, _e: Dictionary) -> Vector2:
	return Vector2(INF, -INF)


## Each truck's planned showing window in `layout` (task C6c; params "show"), along the track: Vector2(from, to),
## the stretch every later pass keeps off in every lane.
static func show_windows(layout: LevelLayout) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for e: Dictionary in trucks_in(layout):
		var w: Vector2 = window_of(e)
		if w.y > w.x:
			out.append(w)
	return out


## Truck entry `e`'s planned showing window: Vector2(from, to), or Vector2(INF, -INF) without one.
static func window_of(e: Dictionary) -> Vector2:
	var show: Variant = (e.get("params", {}) as Dictionary).get("show")
	if not (show is Dictionary) or not (show as Dictionary).has("from"):
		return Vector2(INF, -INF)
	return Vector2(float(show["from"]), float(show["to"]))


## True if truck entry `e` arrives inside the level's calm start to show itself there (task C6e; its window's mode).
static func is_calm_start(e: Dictionary) -> bool:
	var show: Variant = (e.get("params", {}) as Dictionary).get("show")
	return show is Dictionary and String((show as Dictionary).get("mode", "")) == "calm"


## The stretches a wider gap's row keeps off (WideGapPlacement.keeps_of; task C6e, approved with C6d's follow-up):
## each truck's chase before its showing, from its arrival to its window's end (WINDOW_EDGE more), so no wider gap
## wrecks it before it has shown itself. Vector2(from, to), along the track; none for a truck without a window.
static func wide_gap_keep_outs(layout: LevelLayout) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for e: Dictionary in trucks_in(layout):
		var w: Vector2 = window_of(e)
		if w.y > w.x:
			out.append(Vector2(minf(float(e["at"]), w.x - WINDOW_EDGE), w.y + WINDOW_EDGE))
	return out


## What the generator's later passes keep off in every lane (LevelGenerator.rules_doodad_keep_outs): each truck's
## planned showing window (task C6c), {from, to, type, calm}. A calm stretch: nothing they add may stand or attack in
## it, but it's no attack itself, so nothing keeps a spacing from it (as from a Gilded Sentinel's strike) and it
## shapes no pass's search for room. The zone doodads, the danger density pass's enemies and rows (Plan.calm), the
## cyborgs in charge paths (where they stand), the wider gaps (their rows) and City 1's extra gaps keep off it; the
## fill pass, fill_keep_outs.
static func doodad_keep_outs(gen: LevelGenerator) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for w: Vector2 in show_windows(gen.layout):
		out.append({"from": w.x - WINDOW_EDGE, "to": w.y + WINDOW_EDGE, "type": TYPE, "calm": true})
	return out


## What the generator's fill pass keeps off in every lane besides the enemies' stretches (LevelGenerator
## .rules_fill_keep_outs, without its margin): each truck's planned showing window (task C6c).
static func fill_keep_outs(gen: LevelGenerator) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for w: Vector2 in show_windows(gen.layout):
		out.append(Vector2(w.x - WINDOW_EDGE, w.y + WINDOW_EDGE))
	return out


## Every placement rule a generated level's trucks break, for the tests: more than per_level_max, two at
## once, an arrival where none may be, or no bait in a chase. [] if none.
static func problems(gen: LevelGenerator) -> PackedStringArray:
	var out: PackedStringArray = []
	var t: EnforcerTruckTuning = tuning()
	var trucks: Array[Dictionary] = trucks_in(gen.layout)
	if trucks.size() > t.per_level_max:
		out.append("%d Enforcer Trucks (at most %d)" % [trucks.size(), t.per_level_max])
	var baits: Array[Dictionary] = bait_points(gen)
	var keep_outs: Array[Vector2] = arrival_keep_outs(gen)
	var chases: Array[Vector2] = []
	for e: Dictionary in trucks:
		var at: float = float(e["at"])
		var why: String = arrival_problem(gen, t, at, keep_outs, chases, is_calm_start(e))
		if why != "":
			out.append("the truck arriving at %.1f m: %s" % [at, why])
		if baits_in(gen, t, baits, at).is_empty():
			out.append("the truck arriving at %.1f m has no bait in its chase" % at)
		chases.append(chase_span(gen, t, at))
	return out


## Plans each chase's showing window (task C6c; GDD §9.13 "Showing itself", the owner, October 8, 2026: now and
## then it speeds up until it's on screen, so the player sees what's chasing them) on the layout as it stands when
## the trucks are placed: the patterns' and every other feature's rules' pieces and enemies (EnforcerTruckRoom reads
## them). Every later pass keeps off the window it finds (doodad_keep_outs, fill_keep_outs), so it holds in the
## finished level as planned (problem_of checks it there). A window: where the runner is as the showing begins
## (`at`), and the stretch it keeps (`from`, `to`): from the truck's rear as it closes in (its lane's holes count from
## there) to past where it's back behind the runner, by what its checks look ahead (its lane's wider gaps and cuts,
## the runner's lane to dodge into, the enemies it could hide: show_shadow_reach). As the truck asks in play
## (EnforcerTruck.show_lane_now and its giving way), no other enemy's big attack (its warning, its shots) comes and no
## enemy is about near the runner from where the showing begins until it has stayed alongside (busy), no floor cut's
## attack, hover truck or Gilded Sentinel reaches the stretch, and for a runner in every lane there's a lane beside
## them where it can stay (EnforcerTruckRoom.layout_lane), also when it begins show_window_slack_seconds late (for as
## long as still fits, show_min_seconds at least).
## Where the level leaves no such stretch (the patterns' rows of fences, which it never drives through on screen,
## rows of holes leaving a runner no lane to dodge into, and their cyborgs), the planner takes out what's in the
## way: plain holes and fences (never a pulsing fence or one a fence generator powers), and plain cyborgs, window
## cyborgs and Screeches (never a host, the first of a kind the level introduces, or the last of its kind or of one
## of the level's features), and only those the showing needs gone (each one kept that isn't). Taking pieces and enemies out never makes a level
## unfair; it's the window's cost to the danger density (the owner's request, docs/USER_REQUESTS.md), counted in
## gen.show_window_result. Its order: with no runner in any lane sent off the floor before it has stayed alongside
## (`every_lane`), as the level stands, its whole stay (show_seconds): the arrival showing at the first arrival with
## room for one, else the earliest mid-chase one before its first bait (none at an arrival with a bait under way: a
## Buzz Overdrive that claimed its turn before it, task C6d); then a shorter stay (show_min_seconds at
## least); then both taking things out; then all of that again allowing a runner off the floor in a lane; else, at
## the preferred arrival, the same after its first bait (a runner who didn't destroy it with that bait sees it
## then; the rules give the truck to another bait's chase with a window before its bait wherever the level has one,
## task C6d). What it may take out, and that cost: the owner's (October 9, 2026; docs/OPEN_QUESTIONS.md item 383).
class ShowPlanner:
	extends RefCounted
	## How a window is planned, in the order plan() tries them for one before the chase's first bait (task C6e; the
	## owner, October 9, 2026, GDD §9.13 "Making room where there is none"):
	## - CLASSIC: as tasks C6c and C6d planned it: no hover truck or Gilded Sentinel about (quiet, and their stays are
	##   kept off the whole window), back behind the runner before its bait's turn (hold_for). A chase that has one
	##   keeps it, so the levels C6d planned keep their windows.
	## - AROUND: beside a hover truck or a Gilded Sentinel, as long as the runner keeps a free lane: a lane a hover truck
	##   holds is a wall to the runner and never the truck's (EnforcerTruckRoom.held), and the showing keeps off what
	##   can't wait for a turn (EnforcerTruckRoom.fixed: a hover truck's entrance, a Sentinel's turn), from its claim on
	##   its turn on. Their attacks that take turns (the hover truck's cannon and forward lurch) wait for it.
	## - CLAIM: as AROUND, its bait's claim on its turn may come during it (it begins before the claim, which only holds
	##   back the attacks that get ready during it): out of view show_margin_seconds before its bait's warning
	##   (EnforcerTruckRoom.hold_before_warning). The truck doesn't give way to that claim in play.
	## - CALM: the level's calm start (its run-up), where no window fits between the run-up's end and the first bait:
	##   as CLAIM, the truck arriving inside the run-up (calm_start_min_seconds into the run at the earliest) right
	##   behind the runner (at its follow gap) and showing itself as it arrives; nothing taken out.
	## After the bait (the last resort): CLASSIC, then AROUND.
	enum Mode { CLASSIC, AROUND, CLAIM, CALM }
	## Each mode's name in a window's params ("show": {mode}; CLASSIC's windows carry none, as before).
	const MODE_NAMES: PackedStringArray = ["", "around", "claim", "calm"]
	## Seconds after its arrival a mid-chase showing may begin, past the time it takes to close in to its follow gap.
	const SETTLE_SECONDS: float = 0.5
	## Enemies that make no big attack (the truck's checks in play never wait for their shots: only a big attack's,
	## EnemyDirector.note_attack_shot) and stand where the layout says, on the floor, a wall or a ceiling over a lane:
	## the room's lanes keep the truck and the runner's way off the floor ones, and its shadow off where they all
	## stand (EnforcerTruckRoom), so they may stand in a window where those checks hold.
	const ROOM_TYPES: PackedStringArray = ["cyborg", "window_cyborg", "screech", "generator", "barnacle_turret"]
	## Of those, the ones a window may take out where they're in its way: plain ones (never a host, nor the first
	## of a kind the level introduces, and never the level's last of its kind or of one of its features).
	const REMOVABLE_TYPES: PackedStringArray = ["cyborg", "window_cyborg", "screech"]
	## Metres of track around a window a local room holds (_local_room): what its checks reach and more.
	const LOCAL_MARGIN: float = 60.0
	## Metres behind the runner as a showing begins from which an enemy about counts (the truck's in-play checks).
	const BEHIND: float = 3.0
	## Why a window doesn't fit where the truck's bait or its chase's end comes before it could stay alongside (why_none
	## names another reason where one held: this one holds for every late try).
	const TOO_NEAR: String = "its bait or its chase's end too near"
	## Why a window doesn't come before the bait at an arrival with a bait under way (_under_way).
	const UNDER_WAY: String = "a bait under way as it arrives"
	## Why a window doesn't fit where an attack that can't wait for a turn (EnforcerTruckRoom.fixed) is on as the truck
	## claims its turn for it or begins.
	const FIXED: String = "a hover truck's entrance or a Gilded Sentinel's turn"

	var gen: LevelGenerator
	var t: EnforcerTruckTuning
	var room: EnforcerTruckRoom
	var geo: TrackGeometry
	## EnforcerTruckRoom.fits_for at the level's lane count.
	var fits: Dictionary = {}
	## Every other enemy's attack or stay near the runner, and every floor cut's attack, by `span.x`: {span (Vector2),
	## turn (where a bait's turn comes: an Octodog's first planned wind-up, a Buzz Overdrive's claim on it; INF for the
	## rest), whole (a cut's attack or a hover truck's or Gilded Sentinel's stay: kept off the whole window), kind
	## (what it is), entry (its enemy entry, or {}), removable}. A window holds none of them, but for a bait whose turn
	## comes after the showing begins (hold_for keeps the showing over first, and the truck's checks keep it off the
	## bait where it stands), and those it takes out.
	var busy: Array[Dictionary] = []
	var busy_starts: PackedFloat64Array = PackedFloat64Array()
	## The longest of them.
	var longest: float = 0.0
	## The fences a fence generator powers (never taken out).
	var powered: Array[Dictionary] = []
	## Seconds before its rev a Buzz Overdrive's turn comes at the earliest: the cyborgs planted in charge paths come
	## after the trucks, and one planted in its charge's path has it claim its turn this early (ChargePathPlacement:
	## its tuning's claim_seconds), so each window is planned as if every one might (0 in a level that plants none).
	var least_claim: float = 0.0
	## Why the last plan() found none: what kept the most of its tries out.
	var why_none: String = ""
	## The mode the window being tried is planned in (Mode).
	var mode: Mode = Mode.CLASSIC
	## Why the tries keeping every runner on the floor failed (kept apart from why_none's counts).
	var _strict_counts: Dictionary = {}


	static func make(p_gen: LevelGenerator, p_t: EnforcerTruckTuning) -> ShowPlanner:
		var p := ShowPlanner.new()
		p.gen = p_gen
		p.t = p_t
		var lanes: int = p_gen.layout.lane_count
		p.geo = TrackGeometry.new(lanes, p_gen.tuning)
		if p_gen.config.charge_path_cyborgs > 0:
			p.least_claim = ChargePathPlacement.tuning().claim_seconds
		p.room = EnforcerTruckRoom.build(p_gen.layout, p.geo, p_gen.tuning, p_t, p_gen.speed, p.least_claim)
		p.fits = EnforcerTruckRoom.fits_for(p_gen.tuning, p_t, lanes)
		p._index_busy()
		return p


	## The window for a truck that may arrive at any of `spots` (best first; _usable), or inside the level's calm start
	## at any of `calm_spots` (latest first; _calm_spots, task C6e), its seed `seed`: {arrive (where it arrives), at,
	## from, to, hold (seconds alongside), arrival (true: as it arrives), every_lane (true: no runner in any lane off
	## the floor until it has stayed alongside), mode (Mode), gaps, fences and enemies (what to take out)}, or {}
	## (why_none says why). See the class doc for the order it tries them in.
	func plan(spots: Array[float], seed: int, calm_spots: Array[float] = []) -> Dictionary:
		why_none = ""
		var counts: Dictionary = {}
		# An arrival with a bait under way (a Buzz Overdrive that claimed its turn before it, its charge still to come,
		# task C6d) has its first bait right away: no window there comes before it.
		var free: Array[float] = []
		for at: float in spots:
			if _under_way(at) > at:
				_none(counts, UNDER_WAY)
			else:
				free.append(at)
		var w: Dictionary = {}
		# Before its first bait: as tasks C6c and C6d planned it, then (task C6e) beside a hover truck or a Gilded
		# Sentinel (the same as CLASSIC in a level with neither), then with its bait's claim during it. Why none: what
		# kept the most of the last mode's tries out, and of the calm start's and the fallback's after it.
		for m: Mode in [Mode.CLASSIC, Mode.AROUND, Mode.CLAIM]:
			if m == Mode.AROUND and room.quiet.is_empty():
				continue
			mode = m
			counts.clear()
			if free.size() < spots.size():
				counts[UNDER_WAY] = spots.size() - free.size()
			w = _before_bait(free, seed, counts)
			if not w.is_empty():
				break
		if w.is_empty() and not calm_spots.is_empty():
			mode = Mode.CALM
			w = _calm_start(calm_spots, seed, counts)
		# Else after its first bait (one under way as it arrives, or the first whose turn comes after): a runner who
		# didn't destroy it with that bait sees it then (and one who did sees its wreck blow up in view,
		# EnforcerTruck._explode). At the preferred arrival only; as before, then beside a hover truck or a Sentinel.
		for m: Mode in [Mode.CLASSIC, Mode.AROUND]:
			if not w.is_empty() or spots.is_empty() or (m == Mode.AROUND and room.quiet.is_empty()):
				break
			mode = m
			w = _after_bait(spots[0], seed, counts)
			if not w.is_empty():
				w["after_bait"] = true
		if not w.is_empty():
			w["mode"] = mode
			mode = Mode.CLASSIC
			return w
		mode = Mode.CLASSIC
		var most: int = 0
		for why: String in counts:
			if int(counts[why]) > most and (why != TOO_NEAR or counts.size() == 1):
				most = int(counts[why])
				why_none = why
		return {}


	## Phases: Vector3i(taking things out, its whole stay, no runner in any lane off the floor until it has stayed
	## alongside): one that holds wherever the runner is first, then one that takes nothing out, then its whole stay.
	const PHASES: Array[Vector3i] = [Vector3i(0, 1, 1), Vector3i(0, 0, 1), Vector3i(1, 1, 1), Vector3i(1, 0, 1),
		Vector3i(0, 1, 0), Vector3i(0, 0, 0), Vector3i(1, 1, 0), Vector3i(1, 0, 0)]


	## Seconds after an arrival from arrive_gap a mid-chase showing may begin (it has closed in to its follow gap).
	func _settle() -> float:
		return t.ease_seconds(t.arrive_gap - t.follow_gap, t.gap_speed_max) + SETTLE_SECONDS


	## plan()'s window before the first bait in the current mode: as its truck arrives at any of `free`, then mid-chase,
	## phase by phase; {} if none.
	func _before_bait(free: Array[float], seed: int, counts: Dictionary) -> Dictionary:
		var v: float = gen.speed
		for phase: Vector3i in PHASES:
			for at: float in free:
				var w: Dictionary = _window(at, 0.0, t.arrive_gap, seed, phase, counts)
				if not w.is_empty():
					return w
			for at: float in free:
				# Before its first bait's turn: a bait may destroy it.
				var last: float = minf(t.chase_seconds - t.show_min_seconds, room.seconds_to_bait(at, v))
				var c: float = _settle()
				while c <= last:
					var w: Dictionary = _window(at, c, t.follow_gap, seed, phase, counts)
					if not w.is_empty():
						return w
					c += OFFSET_STEP
		return {}


	## plan()'s window in the level's calm start (CALM, task C6e): the truck arriving at any of `calm_spots` (inside the
	## run-up) at its follow gap, showing itself as it arrives. The calm start itself (the run-up) holds nothing to take
	## out; past it, with calm_start_takes_out, the window may take out what's in its way as any other may. {} if none.
	func _calm_start(calm_spots: Array[float], seed: int, counts: Dictionary) -> Dictionary:
		for phase: Vector3i in PHASES:
			if phase.x == 1 and not t.calm_start_takes_out:
				continue
			for at: float in calm_spots:
				var w: Dictionary = _window(at, 0.0, t.follow_gap, seed, phase, counts)
				if not w.is_empty():
					return w
		return {}


	## plan()'s last resort in the current mode: a window after the first bait of a truck arriving at `at`. {} if none.
	func _after_bait(at: float, seed: int, counts: Dictionary) -> Dictionary:
		var v: float = gen.speed
		var first: float = room.seconds_to_bait(at, v)
		if _under_way(at) > at:
			first = minf(first, (_under_way(at) - at) / v)
		for phase: Vector3i in PHASES:
			var c: float = maxf(first, _settle())
			while c <= t.chase_seconds - t.show_min_seconds:
				var w: Dictionary = _window(at, c, t.follow_gap, seed, phase, counts)
				if not w.is_empty():
					return w
				c += OFFSET_STEP
		return {}


	## How long a showing beginning with the runner at `d`, its front `gap` behind them, `chase_left` seconds before
	## its chase ends, may stay alongside in the current mode (EnforcerTruckRoom.hold_for; hold_before_warning in
	## CLAIM and CALM; outside CLASSIC, off the attacks that can't wait for a turn).
	func _hold(gap: float, d: float, chase_left: float) -> float:
		var v: float = gen.speed
		if mode == Mode.CLASSIC:
			return EnforcerTruckRoom.hold_for(t, gap, room.seconds_to_bait(d, v), chase_left)
		var to_fixed: float = room.seconds_to_fixed(d, v)
		if mode == Mode.AROUND:
			return EnforcerTruckRoom.hold_for(t, gap, room.seconds_to_bait(d, v), chase_left, to_fixed)
		return EnforcerTruckRoom.hold_before_warning(t, gap, room.seconds_to_warning(d, v), chase_left, to_fixed)


	## The mode a window's params ("show") were planned in.
	static func mode_of(show: Dictionary) -> Mode:
		return maxi(MODE_NAMES.find(String(show.get("mode", ""))), 0) as Mode


	## The window of a showing beginning `c` seconds into the chase of a truck arriving at `at`, its front `gap`
	## behind the runner, or {} (counting why in `counts`), in `phase` (Vector3i): staying alongside show_seconds
	## (y), or as long as fits before its bait's turn (show_min_seconds at least); taking out what's in its way (x;
	## only where it needs something taken out: one that needs nothing was tried without); with no runner in any
	## lane off the floor as it begins (z: an anti-grav pad's ceiling or a ramp's wall run).
	func _window(at: float, c: float, gap: float, seed: int, phase: Vector3i, counts: Dictionary) -> Dictionary:
		var clearing: bool = phase.x == 1
		var whole: bool = phase.y == 1
		var strict: bool = phase.z == 1
		if strict:
			# Why a try keeping every runner on the floor failed doesn't say why none fits: the looser tries follow.
			counts = _strict_counts
		var v: float = gen.speed
		var d: float = at + c * v
		var hold: float = _hold(gap, d, t.chase_seconds - c)
		if hold < (t.show_seconds if whole else t.show_min_seconds) - 0.001:
			return _none(counts, TOO_NEAR)
		# The same showing begun show_window_slack_seconds late (closer in by then as it arrives), as long as fits.
		var late: float = t.show_window_slack_seconds
		var d2: float = d + late * v
		var gap2: float = maxf(gap - late * t.gap_speed_max, t.follow_gap + 1.0) if gap > t.follow_gap + 1.0 else gap
		var hold2: float = _hold(gap2, d2, t.chase_seconds - c - late)
		if hold2 < t.show_min_seconds:
			return _none(counts, TOO_NEAR)
		var total: float = t.show_total_seconds(gap, hold)
		var total2: float = t.show_total_seconds(gap2, hold2)
		var end: float = maxf(d + total * v, d2 + total2 * v)
		var from: float = d - (t.follow_gap + 2.0 + t.body_size.z + 1.0)
		var to: float = end + maxf((t.show_margin_seconds + t.switch_seconds) * v,
			maxf((t.show_margin_seconds + EnforcerTruckRoom.DODGE_ROOM_SECONDS) * v, t.show_shadow_reach))
		if mode == Mode.CLASSIC:
			if room.quiet_near(d, (to - d) / v, v):
				return _none(counts, "a hover truck or a Gilded Sentinel")
		elif room.fixed_in(d - t.show_claim_seconds * v, d2):
			# Task C6e: nor while an attack that can't wait for a turn (a hover truck's entrance, a Gilded Sentinel's turn)
			# is on as the truck claims its turn for the window or begins (a Sentinel that finds its turn taken as its
			# warning would start lets the runner pass); _hold has it over before the next one.
			return _none(counts, FIXED)
		if (mode == Mode.CLAIM or mode == Mode.CALM) and room.seconds_to_bait(d, v) * v <= d2 - d + 0.01:
			# It begins before its bait claims its turn, late too: one can't begin during the claim.
			return _none(counts, TOO_NEAR)
		# No attack and no enemy about near the runner until it has stayed alongside: its whole stay (`whole`), or its
		# shortest (an attack after that only has it give way sooner, once the runner has seen it).
		var stay: float = hold if whole else t.show_min_seconds
		var calm_to: float = maxf(d + (t.show_close_seconds(gap) + stay) * v,
			d2 + (t.show_close_seconds(gap2) + minf(stay, hold2)) * v)
		var other: String = _busy_in(d, Vector2(d - BEHIND, calm_to), Vector2(from, to))
		if other != "":
			return _none(counts, other)
		# A runner sent onto a ceiling or a wall before it has stayed alongside has it give way.
		var off: String = _off_the_floor(d - BEHIND, calm_to) if strict else ""
		if off != "":
			return _none(counts, off)
		var starts: Array[Vector4] = [Vector4(d, gap, hold, 0.0), Vector4(d2, gap2, hold2, 0.0)]
		var w: Dictionary = {"arrive": at, "at": d, "from": from, "to": to, "hold": hold, "arrival": c == 0.0,
			"every_lane": strict, "gaps": [], "fences": [], "enemies": []}
		if mode != Mode.CLASSIC:
			# The runner lane it leaves out, if any (task C6e; _lanes_fail).
			w["excused"] = _excused(room, starts, seed)
		var gone: Array[Dictionary] = []
		if not clearing:
			var lane: int = _lanes_fail(room, starts, seed)
			return w if lane < 0 else _none(counts, "no lane beside a runner in lane %d" % lane)
		# What the showing reads of the floor: from where it begins to where the runner's room to dodge ends.
		var reads := Vector2(d, maxf(d + (total + t.show_margin_seconds + EnforcerTruckRoom.DODGE_ROOM_SECONDS) * v,
			d2 + (total2 + t.show_margin_seconds + EnforcerTruckRoom.DODGE_ROOM_SECONDS) * v))
		var pieces: Array[Dictionary] = []
		for g: Dictionary in gen.layout.gaps:
			if float(g["end"]) >= reads.x and float(g["start"]) <= reads.y:
				pieces.append(g)
		var half: float = gen.tuning.fence_depth * 0.5 + 0.5
		var fixed: bool = false
		for f: Dictionary in gen.layout.fences:
			if float(f["at"]) + half >= reads.x and float(f["at"]) - half <= reads.y:
				if bool(f.get("pulsing", false)) or powered.has(f):
					fixed = true
				else:
					pieces.append(f)
		# The plain enemies that stand where it reads the floor or where it could hide one from the camera.
		for e: Dictionary in gen.layout.enemies:
			var type: String = String(e.get("type", ""))
			if not REMOVABLE_TYPES.has(type) or bool((e.get("params", {}) as Dictionary).get("host", false)) \
					or (gen.feature_start(type) > 0.0 and is_same(_first_of(type), e)):
				continue
			var span: Vector2 = LevelGenerator.enemy_floor_span(e, gen.pace)
			if span.y < span.x:
				span = Vector2(float(e["at"]), float(e["at"]))
			if span.y >= d - BEHIND - EnforcerTruckRoom.ENEMY_ROOM and span.x <= to + EnforcerTruckRoom.ENEMY_ROOM:
				pieces.append(e)
		var lo: float = from - LOCAL_MARGIN
		var hi: float = to + LOCAL_MARGIN
		var skip: Array[Dictionary] = gone.duplicate()
		skip.append_array(pieces)
		if gone.is_empty() and pieces.is_empty():
			return _none(counts, "no lane beside a runner (nothing to take out)")
		var lane: int = _lanes_fail(_local_room(lo, hi, skip), starts, seed)
		if lane >= 0:
			return _none(counts, "a pulsing or powered fence in the way" if fixed
				else "no lane beside a runner in lane %d, even taking things out" % lane)
		# Keep each piece that needn't go (the ones furthest into the window first). Its blocking enemies go.
		for i: int in range(pieces.size() - 1, -1, -1):
			var trial: Array[Dictionary] = pieces.duplicate()
			trial.remove_at(i)
			var trial_skip: Array[Dictionary] = gone.duplicate()
			trial_skip.append_array(trial)
			if _lanes_fail(_local_room(lo, hi, trial_skip), starts, seed) < 0:
				pieces = trial
		var enemies: Array[Dictionary] = gone.duplicate()
		for p: Dictionary in pieces:
			if p.has("type"):
				enemies.append(p)
			else:
				(w["gaps"] if p.has("start") else w["fences"]).append(p)
		if not _leaves_one_each(enemies):
			return _none(counts, "no lane beside a runner: the last of a kind in the way")
		w["enemies"] = enemies
		return w


	## Why truck entry `e`'s planned showing window (its params' "show") doesn't hold in the layout as it stands ("" if
	## it does, or it has none), for the tests: its showing begun where it's due (as it arrives, or at its follow gap)
	## and show_window_slack_seconds later, staying alongside show_min_seconds at least, taking nothing out, a runner in
	## any lane (_window's checks), keeping the stretch it was planned with.
	func problem_of(e: Dictionary) -> String:
		var show: Dictionary = (e.get("params", {}) as Dictionary).get("show", {})
		if show.is_empty():
			return ""
		var at: float = float(e["at"])
		var d: float = float(show["at"])
		var arrival: bool = absf(d - at) < 0.001
		var counts: Dictionary = {}
		# In the mode it was planned in (task C6e); a calm start's truck arrives at its follow gap.
		mode = mode_of(show)
		var gap: float = t.arrive_gap if arrival and mode != Mode.CALM else t.follow_gap
		var w: Dictionary = _window(at, 0.0 if arrival else (d - at) / gen.speed, gap, 0, Vector3i(0, 0, 0), counts)
		mode = Mode.CLASSIC
		if w.is_empty():
			return String(counts.keys()[0]) if not counts.is_empty() else "no window"
		if absf(float(w["from"]) - float(show["from"])) > 0.01 or absf(float(w["to"]) - float(show["to"])) > 0.01:
			return "the stretch it keeps isn't the one planned (%.1f-%.1f)" % [float(w["from"]), float(w["to"])]
		return ""


	## Where the attack of a bait under way for a truck arriving at `at` ends (-INF: none): a bait whose turn began before
	## it (a Buzz Overdrive claims its turn before its rev, and a truck may arrive before the rev, arrival_keep_outs) and
	## whose attack ends after it, so its charge comes before any showing in that chase (task C6d: the player could bait
	## the truck with it first). An Octodog's charges keep every arrival off them.
	func _under_way(at: float) -> float:
		var out: float = -INF
		for b: Dictionary in busy:
			var turn: float = float(b["turn"])
			if turn < INF and turn < at - 0.001 and (b["span"] as Vector2).y > at:
				out = maxf(out, (b["span"] as Vector2).y)
		return out


	## True if window `w` (plan; {}: none) may still take out what it would on the layout as it stands now: the level
	## keeps one of each kind and of each of its features without those (_leaves_one_each; another window may have
	## taken some out since it was planned).
	func still_fits(w: Dictionary) -> bool:
		var enemies: Array[Dictionary] = []
		enemies.assign(w.get("enemies", []))
		return enemies.is_empty() or _leaves_one_each(enemies)


	## Takes out of the layout what window `w` (plan) needs gone, and reads the layout again. Returns how many
	## pieces and enemies went.
	func take_out(w: Dictionary) -> int:
		var out: int = 0
		for key: String in ["gaps", "fences", "enemies"]:
			var list: Array[Dictionary] = gen.layout.get(key)
			for p: Dictionary in w.get(key, []):
				for i: int in list.size():
					if is_same(list[i], p):
						list.remove_at(i)
						out += 1
						break
		if out > 0:
			room = EnforcerTruckRoom.build(gen.layout, geo, gen.tuning, t, gen.speed, least_claim)
			busy.clear()
			busy_starts.clear()
			powered.clear()
			longest = 0.0
			_index_busy()
		return out


	## The first runner lane no showing beginning at any of `starts` (Vector4(where the runner is, its gap, its hold,
	## _)) fits beside in `r_room` (EnforcerTruckRoom.layout_lane), or -1 if one fits beside every lane. Outside CLASSIC
	## mode (task C6e) its dodge checks are clipped to its stay (as the truck's in play), and one runner lane no showing
	## could reach (EnforcerTruckRoom.unreachable: beside a hover truck at 3 lanes, or with only a cut's lane to show
	## itself in) may be left out (_excused); two such lanes leave the window none.
	func _lanes_fail(r_room: EnforcerTruckRoom, starts: Array[Vector4], seed: int) -> int:
		var classic: bool = mode == Mode.CLASSIC
		var excused: Array[int] = []
		if not classic:
			excused = _excused(r_room, starts, seed)
		if excused.size() > 1:
			return excused[1]
		for r: int in gen.layout.lane_count:
			if excused.has(r):
				continue
			for s: Vector4 in starts:
				if r_room.layout_lane(r, t, fits, s.x, s.y, s.z, gen.speed, seed, not classic) < 0:
					return r
		return -1


	## The runner lanes no showing beginning at any of `starts` could reach in `r_room` (EnforcerTruckRoom.unreachable).
	func _excused(r_room: EnforcerTruckRoom, starts: Array[Vector4], seed: int) -> Array[int]:
		var out: Array[int] = []
		for r: int in gen.layout.lane_count:
			for s: Vector4 in starts:
				if r_room.unreachable(r, t, s.x, s.y, s.z, gen.speed, seed):
					out.append(r)
					break
		return out


	## The layout's floor and enemies from `lo` to `hi`, but `skip` (what's taken out), read into a room
	## (EnforcerTruckRoom.build) for the checks of a window there.
	func _local_room(lo: float, hi: float, skip: Array[Dictionary]) -> EnforcerTruckRoom:
		var src: LevelLayout = gen.layout
		var lay := LevelLayout.new()
		lay.lane_count = src.lane_count
		lay.length = src.length
		for g: Dictionary in src.gaps:
			if float(g["end"]) >= lo and float(g["start"]) <= hi and not _in(skip, g):
				lay.gaps.append(g)
		for f: Dictionary in src.fences:
			if float(f["at"]) >= lo and float(f["at"]) <= hi and not _in(skip, f):
				lay.fences.append(f)
		for d: Dictionary in src.doodads:
			if float(d["end"]) >= lo and float(d["start"]) <= hi:
				lay.doodads.append(d)
		for key: String in ["pads", "speed_pads", "ramps"]:
			for p: Dictionary in src.get(key):
				if float(p["at"]) >= lo - 20.0 and float(p["at"]) <= hi + 20.0:
					(lay.get(key) as Array).append(p)
		for c: Dictionary in src.cuts:
			var w: Vector2 = FloorCutPlan.lane_window(c)
			if w.y >= lo and minf(w.x, float(c["start"])) <= hi:
				lay.cuts.append(c)
		for e: Dictionary in src.enemies:
			var span: Vector2 = LevelGenerator.enemy_floor_span(e, gen.pace)
			# A hover truck holds its lane, and a Sentinel's turn reaches, far from where they stand (task C6e).
			if ((float(e["at"]) >= lo and float(e["at"]) <= hi) or (span.y >= lo and span.x <= hi)
					or StringName(String(e.get("type", ""))) in EnforcerTruckRoom.NO_SHOW_TYPES) and not _in(skip, e):
				lay.enemies.append(e)
		return EnforcerTruckRoom.build(lay, geo, gen.tuning, t, gen.speed, least_claim)


	## What would have a runner in some lane off the floor as a showing begins between `from` and `to` ("" if
	## nothing): an anti-grav pad's ceiling run (from its pad to its ceiling's landing zone's end) or a ramp's wall
	## run (from the ramp to where it drops the runner back, RampLaunch).
	func _off_the_floor(from: float, to: float) -> String:
		for p: Dictionary in gen.layout.pads:
			var at: float = float(p["at"])
			if at > to:
				continue
			var h: Dictionary = gen.layout.hull_at(at + gen.tuning.pad_length, int(p["lane"]))
			var until: float = gen.zones.landing_zone(h).y if not h.is_empty() else at + gen.tuning.pad_length
			if until >= from:
				return "a runner on a ceiling (a pad's)"
		for r: Dictionary in gen.layout.ramps:
			var at: float = float(r["at"])
			if at <= to and maxf(gen.ramp_launch(r).end(), at + gen.tuning.ramp_length) >= from:
				return "a runner on a wall (a ramp's)"
		return ""


	## The layout's first enemy of `type` along the track ({} if none).
	func _first_of(type: String) -> Dictionary:
		var out: Dictionary = {}
		for e: Dictionary in gen.layout.enemies:
			if String(e.get("type", "")) == type and (out.is_empty() or float(e["at"]) < float(out["at"])):
				out = e
		return out


	## True if the layout keeps at least one enemy of each type in `gone` without them, and every feature of the level
	## they could stand for that it has now (LevelGenerator.feature_positions: a cyborg that isn't a host, a Screech
	## from a wall vent; the generator builds the level again where one goes missing, GDD §5).
	func _leaves_one_each(gone: Array[Dictionary]) -> bool:
		var left: Dictionary = {}
		for e: Dictionary in gen.layout.enemies:
			var type: String = String(e.get("type", ""))
			left[type] = int(left.get(type, 0)) + 1
		var features: Dictionary = {}
		for e: Dictionary in gone:
			var type: String = String(e.get("type", ""))
			left[type] = int(left.get(type, 0)) - 1
			if int(left[type]) < 1:
				return false
			features[type] = true
			if type == "screech":
				features["screech_vents"] = true
		var rest := LevelLayout.new()
		rest.lane_count = gen.layout.lane_count
		rest.length = gen.layout.length
		for e: Dictionary in gen.layout.enemies:
			if not _in(gone, e):
				rest.enemies.append(e)
		for feature: String in features:
			if gen.config.has_feature(feature) and not LevelGenerator.feature_positions(gen.layout, feature).is_empty() \
					and LevelGenerator.feature_positions(rest, feature).is_empty():
				return false
		return true


	static func _in(list: Array[Dictionary], item: Dictionary) -> bool:
		for p: Dictionary in list:
			if is_same(p, item):
				return true
		return false


	static func _none(counts: Dictionary, why: String) -> Dictionary:
		counts[why] = int(counts.get(why, 0)) + 1
		return {}


	## What keeps a showing beginning at `d` from its window ("" if nothing): another enemy's big attack or stay
	## near the runner reaching `calm` (Vector2), or a floor cut's attack or a hover truck's or Gilded Sentinel's
	## stay reaching `kept` (the whole window); but for a bait's whose turn comes after the showing begins. Outside
	## CLASSIC mode (task C6e) a hover truck's or a Sentinel's stay doesn't count (what of them can't wait for a turn is
	## EnforcerTruckRoom.fixed, and a hover truck's lane EnforcerTruckRoom.held).
	func _busy_in(d: float, calm: Vector2, kept: Vector2) -> String:
		var lo: float = minf(calm.x, kept.x)
		var hi: float = maxf(calm.y, kept.y)
		var i: int = busy_starts.bsearch(lo - longest - 0.001)
		while i < busy.size() and busy_starts[i] <= hi:
			var b: Dictionary = busy[i]
			i += 1
			if mode != Mode.CLASSIC and bool(b["quiet"]):
				continue
			var span: Vector2 = b["span"]
			var reach: Vector2 = kept if bool(b["whole"]) else calm
			if span.y < reach.x or span.x > reach.y:
				continue
			var turn: float = float(b["turn"])
			if turn < INF and turn >= d - 0.001:
				continue
			return String(b["kind"])
		return ""


	## Indexes every other enemy's big attack or stay near the runner and every floor cut's attack (busy), and the
	## fences a fence generator powers (powered).
	func _index_busy() -> void:
		var hooks: Dictionary = {}
		var v: float = gen.speed
		var dog := EnemyDirector.tuning_for("octodog") as OctodogTuning
		if dog == null:
			dog = OctodogTuning.new()
		var dog_window: float = dog.window_length(v, gen.config.enemy_scaling, gen.pace)
		var buzz := EnemyDirector.tuning_for("buzz_overdrive") as BuzzOverdriveTuning
		var claim: float = buzz.claim_seconds if buzz != null else 2.5
		var gt := EnemyDirector.tuning_for("generator") as FenceGeneratorTuning
		var ht := EnemyDirector.tuning_for("hover_truck") as HoverTruckTuning
		var out: Array[Dictionary] = []
		for e: Dictionary in gen.layout.enemies:
			var type: String = String(e.get("type", ""))
			var at: float = float(e["at"])
			var kind: String = "a %s about" % type.replace("_", " ")
			var whole: bool = StringName(type) in EnforcerTruckRoom.NO_SHOW_TYPES
			match type:
				TYPE:
					continue
				"buzz_overdrive":
					if not BuzzRules.cut_of(gen.layout, e).is_empty():
						continue  # Its cut's attack, below.
				"octodog":
					var anchors: Array = (e.get("params", {}) as Dictionary).get("charge_at", [])
					if not anchors.is_empty():
						out.append(_busy(Vector2(float(anchors[0]) - gen.metres(Octodog.OTHER_ENEMY_BEFORE),
							float(anchors[-1]) + dog_window), float(anchors[0]), false, "an Octodog's charges", e))
						continue
				"generator":
					if gt != null:
						powered.append_array(FenceGenerator.fences_in_reach(gen.layout, geo, at, int(e.get("lane", 0)),
							gt.emp_radius))
				"resonator", "drone":
					# Big attacks that take turns, from beside the runner's way: a Resonator paces the runner hover_ahead
					# in front, beyond the reach of what the truck could hide, a drone hovers over the runner's own lane,
					# and the truck claims its turn before its planned showing (EnforcerTruck.claiming), so a pulse or a
					# barrage due meanwhile waits for it (turn_wait_max at most, as for a volley).
					continue
				"hover_truck":
					# In play until it has left, after its longest stay.
					if ht != null:
						out.append(_busy(Vector2(HoverTruckRules.window_start(ht, at, gen.pace),
							HoverTruckRules.window_end(ht, at, v)), INF, true, kind, e, true))
						continue

			if ROOM_TYPES.has(type):
				# Not a host's possible Bad Dream chase: killing a host is always the player's choice (GDD §9.7), and a
				# runner who releases one sees the truck after it (the chase is an exclusive big attack: its showing
				# waits), as the danger density pass leaves it out (its keep_out_exempt_features).
				continue
			var et := EnemyDirector.tuning_for(type) as EnemyTuning
			if et is ThiefTuning and et.get(&"approach_speed") != null:
				# A thief comes in from start_ahead ahead of the runner as they reach spawn_lead before its spot, and
				# weaves in the lanes ahead of them until it meets them.
				var from: float = at - et.spawn_lead
				var meet: float = float(et.get(&"start_ahead")) / maxf(float(et.get(&"approach_speed")), 0.01)
				out.append(_busy(Vector2(from, from + (meet + 1.0) * v), INF, whole, kind, e, whole))
				continue
			var k: Vector2 = LevelGenerator.DangerDensity.attack_window(gen, e, hooks)
			if k.y >= k.x:
				out.append(_busy(k, INF, whole, kind, e, whole))
		for c: Dictionary in gen.layout.cuts:
			var w: Vector2 = FloorCutPlan.attack_window(c, v)
			var turn: float = INF
			for e: Dictionary in gen.layout.enemies:
				if String(e.get("type", "")) == "buzz_overdrive" and is_same(BuzzRules.cut_of(gen.layout, e), c):
					turn = FloorCutPlan.warn_at(c) - maxf(float(c.get("claim_seconds", claim)), least_claim) * v
			out.append(_busy(w, turn, true, "a Buzz Overdrive's attack" if turn < INF else "a floor cut", {}))
		out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return (a["span"] as Vector2).x < (b["span"] as Vector2).x)
		for b: Dictionary in out:
			busy.append(b)
			busy_starts.append((b["span"] as Vector2).x)
			longest = maxf(longest, (b["span"] as Vector2).y - (b["span"] as Vector2).x)


	## A busy entry (_index_busy); `quiet`: a hover truck's or a Gilded Sentinel's stay (only CLASSIC mode counts it).
	static func _busy(span: Vector2, turn: float, whole: bool, kind: String, entry: Dictionary, quiet: bool = false) -> Dictionary:
		return {"span": span, "turn": turn, "whole": whole, "kind": kind, "entry": entry, "quiet": quiet}
