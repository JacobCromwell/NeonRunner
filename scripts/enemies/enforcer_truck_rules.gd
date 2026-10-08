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
##   baits get them first.
## - Where it may arrive: after the run-up and the feature's start, and never while another bait attacks (an
##   Octodog's planned charges, a Buzz Overdrive's rev and charge). In a level paced in bursts (The Hush) it
##   arrives in a burst where it can (LevelGenerator.pacing_pools). Its chase may run on to the level's end.
##   Its entry's `at` is where it arrives, never a spot it takes up ahead of the runner
##   (EnemyTuning.behind_runner), so no Octodog's charge keeps clear of it.
## - Its showing window (task C6c; GDD §9.13 "Showing itself", the owner, October 8, 2026: now and then it speeds
##   up until it's on screen, so the player sees what's behind them): each chase gets a calm stretch where it can
##   pull up beside the runner and stay show_seconds wherever the runner is, at the level's speed (plan_show): no
##   enemy about and no other attack (their keep-outs), no hover truck or Gilded Sentinel coming, its bait's turn
##   far enough off, and for a runner in every lane a lane beside them where its look fits on screen and its lane
##   stays clear for the whole stay, the runner keeps a lane to dodge into and it hides no enemy (EnforcerTruckRoom
##   .layout_lane, the checks it makes in play), also when it begins show_window_slack_seconds late. As it arrives
##   (its arrival showing) where any of its arrivals has one, else the earliest mid-chase one; the arrival moves to
##   where one fits (the preferred arrival first). Its params hold it ("show": {at: where the runner is as it
##   begins, from and to: the stretch it keeps}), and every later pass keeps off it in every lane, as off a Gilded
##   Sentinel's strike (doodad_keep_outs: the danger density pass, the cyborgs in charge paths, the wider gaps, the
##   zone doodads, City 1's extra gaps; LevelGenerator.fill_keep_outs: the fill pass). In play the truck holds its
##   volleys for it (EnforcerTruck.show_window). gen.show_window_result reports each chase's.
## It takes little room on the track: it drives behind the runner, never on the floor ahead (its tuning's
## uses_floor is false), and its volleys check their escape at run time (EnforcerTruck.escape_clear). So the
## passes keep nothing else for it (keep_out), and its entries take seeds of their own rather than
## LevelGenerator.add_enemy's running count: a level with the feature differs only by its trucks and what their
## showing windows keep the later passes off (and by what the danger density pass adds for its higher enemy
## count). It has no patterns: these rules place every one. A level with no bait its chase can take gets none (GDD
## §9.13: it appears where Octodogs or Buzz Overdrives appear). DESIGN-TBD (docs/questions/c6.md): the bait's
## place in its chase, the spacing, which baits get one; (docs/questions/c6c.md) the showing window.

const TYPE: String = "enforcer_truck"
## Every feature whose rules place, move or drop enemies, plan charges or cuts, or add ceilings: the trucks
## are planned on the level's final baits.
const RUN_AFTER: Array[String] = ["ramps", "ceilings", "pulsing", "speed_pads", "cyborg", "window_cyborg", "host",
	"hover_truck", "octodog", "screech", "screech_vents", "drone", "generator", "wall_fences", "wall_fences_partial",
	"buzz_overdrive", "barnacle_turret", "tithe_collector", "resonator", "gilded_sentinel"]
const BuzzRules = preload("res://scripts/enemies/buzz_overdrive_rules.gd")
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
	var taken: Array[bool] = []
	taken.resize(baits.size())
	# With its showing windows planned (task C6c), a level that introduces it gives its earliest bait the first one
	# (its introduction); then baits whose chase has room for a showing get them first, earliest first; then the
	# rest, earliest first, as without them.
	var passes: Array[String] = []
	if planner != null:
		if gen.feature_start(TYPE) > 0.0:
			passes.append("intro")
		passes.append("window")
	passes.append("any")
	for kind: String in passes:
		for i: int in baits.size():
			if report.size() >= t.per_level_max:
				break
			if taken[i]:
				continue
			var spots: Array[float] = _usable(gen, t, orders[i], keep_outs, chases)
			if spots.is_empty():
				continue
			var seed: int = hash([gen.config.level_seed, TYPE, report.size()])
			var plan: Dictionary = planner.plan(spots, seed) if planner != null else {}
			if kind == "window" and plan.is_empty():
				continue
			taken[i] = true
			report.append(_place(gen, t, planner, baits, spots, plan, seed))
			chases.append(chase_span(gen, t, float(report[-1]["at"])))
			if kind == "intro":
				break
	gen.show_window_result = {"planned": planner != null, "chases": report}


## Adds a truck arriving at `spots[0]`, or where showing window `plan` (ShowPlanner.plan) has it arrive, taking out
## what the window needs gone. Returns its line of the report: {at, preferred, arrivals, window, taken_out, why}.
static func _place(gen: LevelGenerator, t: EnforcerTruckTuning, planner: ShowPlanner, baits: Array[Dictionary],
		spots: Array[float], plan: Dictionary, seed: int) -> Dictionary:
	var at: float = spots[0]
	var taken: int = 0
	var params := {}
	if not plan.is_empty():
		at = float(plan["arrive"])
		taken = planner.take_out(plan)
	params["baits"] = baits_in(gen, t, baits, at)
	if not plan.is_empty():
		params["show"] = {"at": plan["at"], "from": plan["from"], "to": plan["to"]}
	gen.layout.enemies.append({"type": TYPE, "at": at, "lane": gen.layout.lane_count / 2, "side": 0,
		"seed": seed, "params": params})
	return {"at": at, "preferred": spots[0], "arrivals": spots.size(),
		"window": {} if plan.is_empty() else {"at": plan["at"], "from": plan["from"], "to": plan["to"],
			"hold": plan["hold"], "arrival": plan["arrival"], "after_bait": plan.get("after_bait", false)},
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
## charges or a Buzz Overdrive's attack there (keep_outs), or another truck's chase (with spacing_seconds).
static func arrival_problem(gen: LevelGenerator, t: EnforcerTruckTuning, at: float, keep_outs: Array[Vector2],
		chases: Array[Vector2]) -> String:
	if at < maxf(gen.config.start_clear_distance, gen.feature_start(TYPE)) - 0.001:
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


## What the generator's later passes keep off in every lane (LevelGenerator.rules_doodad_keep_outs, as a Gilded
## Sentinel's strike): each truck's planned showing window (task C6c), {from, to, type}. The zone doodads, the
## danger density pass's enemies and rows, the cyborgs in charge paths, the wider gaps and City 1's extra gaps keep
## off it; the fill pass, fill_keep_outs.
static func doodad_keep_outs(gen: LevelGenerator) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for w: Vector2 in show_windows(gen.layout):
		out.append({"from": w.x, "to": w.y, "type": TYPE})
	return out


## What the generator's fill pass keeps off in every lane besides the enemies' stretches (LevelGenerator
## .rules_fill_keep_outs, without its margin): each truck's planned showing window (task C6c).
static func fill_keep_outs(gen: LevelGenerator) -> Array[Vector2]:
	return show_windows(gen.layout)


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
		var why: String = arrival_problem(gen, t, at, keep_outs, chases)
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
## finished level as planned. A window: where the runner is as the showing begins (`at`), and the stretch it keeps
## (`from`, `to`): from the truck's rear as it closes in (its lane's holes count from there) to past where it's back
## behind the runner, by what its checks look ahead (its lane's wider gaps and cuts, the runner's lane to dodge
## into, the enemies it could hide: show_shadow_reach). As the truck asks in play (EnforcerTruck.show_lane_now and
## its giving way), no other enemy's attack (its warning, its shots) comes and no enemy is about near the runner
## from where the showing begins until it has stayed alongside (busy), no hover truck or Gilded Sentinel comes, and
## for a runner in every lane there's a lane beside them where it can stay (EnforcerTruckRoom.layout_lane), also when
## it begins show_window_slack_seconds late (for as long as still fits, show_min_seconds at least).
## Where the level leaves no such stretch (the patterns' rows of fences, which it never drives through on screen,
## rows of holes leaving a runner no lane to dodge into, and their cyborgs), the planner takes out what's in the
## way: plain holes and fences (never a pulsing fence or one a fence generator powers), and plain cyborgs and window
## cyborgs (never a host, nor the level's first of its kind), and only those the showing needs gone (each one kept
## that isn't). Taking pieces and enemies out never makes a level unfair; it's the window's cost to the danger
## density (the owner's request, docs/USER_REQUESTS.md), counted in gen.show_window_result. Its order: as the level
## stands, the arrival showing at the first arrival with room for one, else the earliest mid-chase one before its
## first bait; then the same taking things out; then both again with a shorter stay (show_min_seconds at least).
class ShowPlanner:
	extends RefCounted
	## Seconds after its arrival a mid-chase showing may begin, past the time it takes to close in to its follow gap.
	const SETTLE_SECONDS: float = 0.5
	## Enemies that neither shoot nor make a big attack (a fence generator; a Sewer Screech, whose swipe is a floor
	## enemy's in its lane): the room's lanes keep the truck and the runner's way off them (floor enemies), and its
	## shadow off where they stand, so they may stand in a window.
	const PASSIVE_TYPES: PackedStringArray = ["generator", "screech"]
	## Enemies a window may take out (plain ones: never a host, nor the first of a kind the level introduces, and
	## never the level's last of its kind): ones that shoot, where they would (busy), and passive floor ones
	## where they stand in its way (PASSIVE_REMOVABLE).
	const REMOVABLE_TYPES: PackedStringArray = ["cyborg", "window_cyborg"]
	const PASSIVE_REMOVABLE: PackedStringArray = ["screech"]
	## Metres of track around a window a local room holds (_local_room): what its checks reach and more.
	const LOCAL_MARGIN: float = 60.0
	## Metres behind the runner as a showing begins from which an enemy about counts (the truck's in-play checks).
	const BEHIND: float = 3.0

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
	## Why the last plan() found none: what kept the most of its tries out.
	var why_none: String = ""


	static func make(p_gen: LevelGenerator, p_t: EnforcerTruckTuning) -> ShowPlanner:
		var p := ShowPlanner.new()
		p.gen = p_gen
		p.t = p_t
		var lanes: int = p_gen.layout.lane_count
		p.geo = TrackGeometry.new(lanes, p_gen.tuning)
		p.room = EnforcerTruckRoom.build(p_gen.layout, p.geo, p_gen.tuning, p_t, p_gen.speed)
		p.fits = EnforcerTruckRoom.fits_for(p_gen.tuning, p_t, lanes)
		p._index_busy()
		return p


	## The window for a truck that may arrive at any of `spots` (best first; _usable), its seed `seed`: {arrive
	## (where it arrives), at, from, to, hold (seconds alongside), arrival (true: as it arrives), gaps, fences and
	## enemies (what to take out)}, or {} (why_none says why). See the class doc for the order it tries them in.
	func plan(spots: Array[float], seed: int) -> Dictionary:
		why_none = ""
		var counts: Dictionary = {}
		var settle: float = t.ease_seconds(t.arrive_gap - t.follow_gap, t.gap_speed_max) + SETTLE_SECONDS
		var v: float = gen.speed
		for phase: Vector2i in [Vector2i(0, 1), Vector2i(1, 1), Vector2i(0, 0), Vector2i(1, 0)]:
			var clearing: bool = phase.x == 1
			var whole: bool = phase.y == 1
			for at: float in spots:
				var w: Dictionary = _window(at, 0.0, t.arrive_gap, seed, clearing, whole, counts)
				if not w.is_empty():
					return w
			for at: float in spots:
				# Before its first bait's turn: a bait may destroy it.
				var last: float = minf(t.chase_seconds - t.show_min_seconds, room.seconds_to_bait(at, v))
				var c: float = settle
				while c <= last:
					var w: Dictionary = _window(at, c, t.follow_gap, seed, clearing, whole, counts)
					if not w.is_empty():
						return w
					c += OFFSET_STEP
		# Else after its first bait: a runner who didn't destroy it with that bait sees it then (and one who did sees
		# its wreck blow up in view, EnforcerTruck._explode). At the preferred arrival only.
		var first: float = room.seconds_to_bait(spots[0], v)
		for phase: Vector2i in [Vector2i(0, 1), Vector2i(1, 1), Vector2i(0, 0), Vector2i(1, 0)]:
			var c: float = maxf(first, settle)
			while c <= t.chase_seconds - t.show_min_seconds:
				var w: Dictionary = _window(spots[0], c, t.follow_gap, seed, phase.x == 1, phase.y == 1, counts)
				if not w.is_empty():
					w["after_bait"] = true
					return w
				c += OFFSET_STEP
		var most: int = 0
		for why: String in counts:
			if int(counts[why]) > most:
				most = int(counts[why])
				why_none = why
		return {}


	## The window of a showing beginning `c` seconds into the chase of a truck arriving at `at`, its front `gap`
	## behind the runner, or {} (counting why in `counts`): staying alongside show_seconds (`whole`), or as long as
	## fits before its bait's turn (show_min_seconds at least); with `clearing`, taking out what's in its way (only
	## where it needs something taken out: one that needs nothing was tried without).
	func _window(at: float, c: float, gap: float, seed: int, clearing: bool, whole: bool, counts: Dictionary) -> Dictionary:
		var v: float = gen.speed
		var d: float = at + c * v
		var hold: float = EnforcerTruckRoom.hold_for(t, gap, room.seconds_to_bait(d, v), t.chase_seconds - c)
		if hold < (t.show_seconds if whole else t.show_min_seconds) - 0.001:
			return _none(counts, "its bait or its chase's end too near")
		# The same showing begun show_window_slack_seconds late (closer in by then as it arrives), as long as fits.
		var late: float = t.show_window_slack_seconds
		var d2: float = d + late * v
		var gap2: float = maxf(gap - late * t.gap_speed_max, t.follow_gap + 1.0) if gap > t.follow_gap + 1.0 else gap
		var hold2: float = EnforcerTruckRoom.hold_for(t, gap2, room.seconds_to_bait(d2, v), t.chase_seconds - c - late)
		if hold2 < t.show_min_seconds:
			return _none(counts, "its bait or its chase's end too near")
		var total: float = t.show_total_seconds(gap, hold)
		var total2: float = t.show_total_seconds(gap2, hold2)
		var end: float = maxf(d + total * v, d2 + total2 * v)
		var from: float = d - (t.follow_gap + 2.0 + t.body_size.z + 1.0)
		var to: float = end + maxf((t.show_margin_seconds + t.switch_seconds) * v,
			maxf((t.show_margin_seconds + EnforcerTruckRoom.DODGE_ROOM_SECONDS) * v, t.show_shadow_reach))
		if room.quiet_near(d, (to - d) / v, v):
			return _none(counts, "a hover truck or a Gilded Sentinel")
		# No attack and no enemy about near the runner until it has stayed alongside: its whole stay (`whole`), or its
		# shortest (an attack after that only has it give way sooner, once the runner has seen it).
		var stay: float = hold if whole else t.show_min_seconds
		var calm_to: float = maxf(d + (t.show_close_seconds(gap) + stay) * v,
			d2 + (t.show_close_seconds(gap2) + minf(stay, hold2)) * v)
		var blockers: Array[Dictionary] = []
		var other: String = _busy_in(d, Vector2(d - BEHIND, calm_to), Vector2(from, to), blockers)
		if other != "":
			return _none(counts, other)
		if not blockers.is_empty() and not clearing:
			return _none(counts, String(blockers[0]["kind"]))
		var starts: Array[Vector4] = [Vector4(d, gap, hold, 0.0), Vector4(d2, gap2, hold2, 0.0)]
		var w: Dictionary = {"arrive": at, "at": d, "from": from, "to": to, "hold": hold, "arrival": c == 0.0,
			"gaps": [], "fences": [], "enemies": []}
		var gone: Array[Dictionary] = []
		for b: Dictionary in blockers:
			if not _in(gone, b["entry"]):
				gone.append(b["entry"])
		if not _leaves_one_each(gone):
			return _none(counts, String(blockers[0]["kind"]))
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
		# The passive floor enemies that stand where it reads the floor or could hide one (a Sewer Screech's manhole).
		for e: Dictionary in gen.layout.enemies:
			if not PASSIVE_REMOVABLE.has(String(e.get("type", ""))) or _in(gone, e) \
					or (gen.feature_start(String(e["type"])) > 0.0 and is_same(_first_of(String(e["type"])), e)):
				continue
			var span: Vector2 = LevelGenerator.enemy_floor_span(e, gen.pace)
			if span.y >= reads.x - EnforcerTruckRoom.ENEMY_ROOM and span.x <= to + EnforcerTruckRoom.ENEMY_ROOM:
				pieces.append(e)
		var lo: float = from - LOCAL_MARGIN
		var hi: float = to + LOCAL_MARGIN
		var skip: Array[Dictionary] = gone.duplicate()
		skip.append_array(pieces)
		if gone.is_empty() and pieces.is_empty():
			return _none(counts, "no lane beside a runner (nothing to take out)")
		var lane: int = _lanes_fail(_local_room(lo, hi, skip), starts, seed)
		if lane >= 0:
			return _none(counts, ("a pulsing or powered fence in the way" if fixed else "no lane beside a runner in lane %d, even taking things out" % lane))
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
			room = EnforcerTruckRoom.build(gen.layout, geo, gen.tuning, t, gen.speed)
			busy.clear()
			busy_starts.clear()
			powered.clear()
			longest = 0.0
			_index_busy()
		return out


	## The first runner lane no showing beginning at any of `starts` (Vector4(where the runner is, its gap, its hold,
	## _)) fits beside in `r_room` (EnforcerTruckRoom.layout_lane), or -1 if one fits beside every lane.
	func _lanes_fail(r_room: EnforcerTruckRoom, starts: Array[Vector4], seed: int) -> int:
		for r: int in gen.layout.lane_count:
			for s: Vector4 in starts:
				if r_room.layout_lane(r, t, fits, s.x, s.y, s.z, gen.speed, seed) < 0:
					return r
		return -1


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
			if ((float(e["at"]) >= lo and float(e["at"]) <= hi) or (span.y >= lo and span.x <= hi)) and not _in(skip, e):
				lay.enemies.append(e)
		return EnforcerTruckRoom.build(lay, geo, gen.tuning, t, gen.speed)


	## The layout's first enemy of `type` along the track ({} if none).
	func _first_of(type: String) -> Dictionary:
		var out: Dictionary = {}
		for e: Dictionary in gen.layout.enemies:
			if String(e.get("type", "")) == type and (out.is_empty() or float(e["at"]) < float(out["at"])):
				out = e
		return out


	## True if the layout keeps at least one enemy of each type in `gone` without them.
	func _leaves_one_each(gone: Array[Dictionary]) -> bool:
		var left: Dictionary = {}
		for e: Dictionary in gen.layout.enemies:
			var type: String = String(e.get("type", ""))
			left[type] = int(left.get(type, 0)) + 1
		for e: Dictionary in gone:
			var type: String = String(e.get("type", ""))
			left[type] = int(left.get(type, 0)) - 1
			if int(left[type]) < 1:
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


	## What keeps a showing beginning at `d` from its window ("" if nothing), with the enemies it could take out
	## added to `removable`: another enemy's attack or stay near the runner reaching `calm` (Vector2), a big attack
	## that waits for its turn (a Resonator's pulse) where the showing begins (show_window_slack_seconds late at
	## most), or a floor cut's attack or a hover truck's or Gilded Sentinel's stay reaching `kept` (the whole
	## window); but for a bait's whose turn comes after the showing begins.
	func _busy_in(d: float, calm: Vector2, kept: Vector2, removable: Array[Dictionary]) -> String:
		var lo: float = minf(calm.x, kept.x)
		var hi: float = maxf(calm.y, kept.y)
		var i: int = busy_starts.bsearch(lo - longest - 0.001)
		while i < busy.size() and busy_starts[i] <= hi:
			var b: Dictionary = busy[i]
			i += 1
			var span: Vector2 = b["span"]
			var reach: Vector2 = kept if bool(b["whole"]) else calm
			if bool(b.get("waits", false)):
				reach = Vector2(calm.x, d + (t.show_window_slack_seconds + 0.5) * gen.speed)
			if span.y < reach.x or span.x > reach.y:
				continue
			var turn: float = float(b["turn"])
			if turn < INF and turn >= d - 0.001:
				continue
			if not bool(b["removable"]):
				return String(b["kind"])
			if not _in(removable, b):
				removable.append(b)
		return ""


	## Indexes every other enemy's attack or stay near the runner and every floor cut's window (busy), and the
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
		var firsts: Dictionary = {}
		for e: Dictionary in gen.layout.enemies:
			var type: String = String(e.get("type", ""))
			if not firsts.has(type) or float(e["at"]) < float((firsts[type] as Dictionary)["at"]):
				firsts[type] = e
		var out: Array[Dictionary] = []
		for e: Dictionary in gen.layout.enemies:
			var type: String = String(e.get("type", ""))
			var kind: String = "a %s about" % type.replace("_", " ")
			match type:
				TYPE:
					continue
				"buzz_overdrive":
					if not BuzzRules.cut_of(gen.layout, e).is_empty():
						continue  # Its cut's window, below.
				"octodog":
					var anchors: Array = (e.get("params", {}) as Dictionary).get("charge_at", [])
					if not anchors.is_empty():
						out.append(_busy(Vector2(float(anchors[0]) - gen.metres(Octodog.OTHER_ENEMY_BEFORE),
							float(anchors[-1]) + dog_window), float(anchors[0]), false, "an Octodog's charges", e, false))
						continue
				"generator":
					if gt != null:
						powered.append_array(FenceGenerator.fences_in_reach(gen.layout, geo, float(e["at"]),
							int(e.get("lane", 0)), gt.emp_radius))
				"resonator":
					# Its pulses, one by one, and only where a showing begins (`waits`): between them it paces the runner
					# hover_ahead in front, beyond the reach of what the truck could hide, and a pulse due during a showing
					# waits for its turn (the director's turn_wait_max at most, as for a volley).
					var pulses: Array[Vector2] = LevelGenerator.DangerDensity.resonator_pulse_windows(gen, e)
					if not pulses.is_empty():
						for w: Vector2 in pulses:
							var b: Dictionary = _busy(w, INF, false, "a Resonator's pulse", e, false)
							b["waits"] = true
							out.append(b)
						continue
			if PASSIVE_TYPES.has(type):
				continue
			var whole: bool = StringName(type) in EnforcerTruckRoom.NO_SHOW_TYPES
			var params: Dictionary = e.get("params", {})
			# Never a host, nor the first of a kind the level introduces (LevelConfig.feature_starts).
			var removable: bool = REMOVABLE_TYPES.has(type) and not bool(params.get("host", false)) \
				and not (gen.feature_start(type) > 0.0 and is_same(firsts.get(type), e))
			var et := EnemyDirector.tuning_for(type) as EnemyTuning
			if et is ThiefTuning and et.get(&"approach_speed") != null:
				# A thief comes in from start_ahead ahead of the runner as they reach spawn_lead before its spot, and
				# weaves in the lanes ahead of them until it meets them.
				var from: float = float(e["at"]) - et.spawn_lead
				var meet: float = float(et.get(&"start_ahead")) / maxf(float(et.get(&"approach_speed")), 0.01)
				out.append(_busy(Vector2(from, from + (meet + 1.0) * v), INF, whole, kind, e, removable))
				continue
			var k: Vector2 = LevelGenerator.DangerDensity.attack_window(gen, e, hooks)
			if k.y >= k.x:
				out.append(_busy(k, INF, whole, kind, e, removable))
		for c: Dictionary in gen.layout.cuts:
			var w: Vector2 = FloorCutPlan.attack_window(c, v)
			var turn: float = INF
			for e: Dictionary in gen.layout.enemies:
				if String(e.get("type", "")) == "buzz_overdrive" and is_same(BuzzRules.cut_of(gen.layout, e), c):
					turn = FloorCutPlan.warn_at(c) - float(c.get("claim_seconds", claim)) * v
			out.append(_busy(w, turn, true, "a Buzz Overdrive's attack" if turn < INF else "a floor cut", {}, false))
		out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return (a["span"] as Vector2).x < (b["span"] as Vector2).x)
		for b: Dictionary in out:
			busy.append(b)
			busy_starts.append((b["span"] as Vector2).x)
			longest = maxf(longest, (b["span"] as Vector2).y - (b["span"] as Vector2).x)


	static func _busy(span: Vector2, turn: float, whole: bool, kind: String, entry: Dictionary, removable: bool) -> Dictionary:
		return {"span": span, "turn": turn, "whole": whole, "kind": kind, "entry": entry, "removable": removable}
