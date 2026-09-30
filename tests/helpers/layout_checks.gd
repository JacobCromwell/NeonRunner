class_name LayoutChecks
extends RefCounted
## Fairness checks for generated layouts, shared by the generator suite (many seeds of the prototype
## level), the enemy suites and the campaign suite (every campaign level):
## - check_layout: every layout, whatever its features: holes are jumpable and no stretch where every
##   lane is a hole is longer than a jump, fences stand on floor, ramps stand on floor with no sign at
##   their wall entry, nothing lies in the end-clear stretch, and every ceiling keeps GDD §3
##   (check_ceilings).
## - check_ceilings: the floor under a ceiling may be dangerous (GDD §3, changed September 26, 2026),
##   but every pad lies under a ceiling and can be stepped on, every landing zone is safe to land on,
##   floor enemies keep off both (CeilingZones), and a floor route runs under every ceiling without
##   its pad (FloorRoute).
## - check_rules: the enemy rules still hold when many features share a level: drones get 10 s before
##   their first pad and then pads 8–10 s apart (GDD §9.6), a Bad Dream's chase has pads at most
##   10 s apart and keeps off Octodog runs (GDD §9.7), Octodog runs stay off pads and ceiling
##   landings, cyborgs keep their margin from floor obstacles, and every fence generator powers a
##   fence.
## Each check goes through `suite.check()`, so failures are reported by the suite that called.
## Every check runs at the level's own run speed (level_tuning: a campaign level's is its zone's), with
## the margins in metres stretched by its pace, as the generator builds it (GDD §3: a faster zone keeps
## every reaction window in seconds).

const CyborgRules = preload("res://scripts/enemies/cyborg_rules.gd")
## A floor route under a ceiling is looked for from this far before its pad's run-up.
const ROUTE_LEAD: float = 5.0


## The movement tuning `config`'s level runs on (LevelConfig.movement_for: its own run speed, a
## campaign level's zone's), from the suite's.
static func level_tuning(suite: TestSuite, config: LevelConfig) -> MovementTuning:
	return config.movement_for(suite.tuning)


static func check_layout(suite: TestSuite, layout: LevelLayout, config: LevelConfig, tag: String) -> void:
	var tuning: MovementTuning = level_tuning(suite, config)
	var n: int = layout.lane_count
	var max_gap: float = tuning.jump_distance(tuning.run_speed) * config.max_gap_jump_fraction + 0.001
	var finish_buffer: float = layout.length - config.end_clear_distance + 0.001
	for g: Dictionary in layout.gaps:
		suite.check(g["lane"] >= 0 and g["lane"] < n, "gap lane in range " + tag)
		suite.check(g["end"] - g["start"] <= max_gap, "gap jumpable (%.1f m) %s" % [g["end"] - g["start"], tag])
		suite.check(g["end"] <= finish_buffer, "gap before the end-clear stretch " + tag)
	for f: Dictionary in layout.fences:
		suite.check(f["lane"] >= 0 and f["lane"] < n, "fence lane in range " + tag)
		suite.check(not gapped_between(layout, f["lane"], f["at"], f["at"]), "fence not over a gap at %.1f %s" % [f["at"], tag])
		suite.check(f["at"] <= finish_buffer, "fence before the end-clear stretch " + tag)
	suite.check(longest_all_lane_hole(layout) <= max_gap, "every all-lane hole is jumpable " + tag)
	check_ceilings(suite, layout, config, tag)
	for r: Dictionary in layout.ramps:
		var lane: int = layout.outer_lane(r["side"])
		suite.check(not gapped_between(layout, lane, r["at"], r["at"] + tuning.ramp_length), "ramp on solid floor " + tag)
		for s: Dictionary in layout.signs:
			if s["side"] == r["side"]:
				suite.check(s["end"] < r["at"] - 2.0 or s["start"] > r["at"] + tuning.ramp_length + 2.0,
					"ramp entry not blocked by a sign " + tag)
	for s: Dictionary in layout.signs:
		suite.check(s["end"] <= finish_buffer, "sign before the end-clear stretch " + tag)


## GDD §3 (changed September 26, 2026) for every ceiling. The floor under it may hold anything, but:
## - each pad lies under a ceiling section, over the pad's own lane (a narrow ceiling's pads lie in
##   its lanes), and the player can step on it: its lane holds no hole or fence from a full jump before
##   it until its lift reaches the hull, and no ramp before it (so it's never on or at the edge of a
##   gap, never in a fence, and reachable);
## - each ceiling covers a contiguous range of real lanes (a range over every lane is stored without
##   one), and a one-lane ceiling is short: one_lane_ceiling_seconds from its pad at most;
## - each landing zone is safe to land on: no hole or fence in any lane the ceiling covers, and it
##   ends before the finish;
## - no floor enemy uses the floor on a landing zone, on a pad's zone from the pad's lane, or where a
##   pad lies from any other lane;
## - credits on a ceiling hang under a ceiling over their lane;
## - a floor route runs under every ceiling, from before its pad's run-up to the end of its landing
##   zone, without its pad (FloorRoute), so the ceiling is never required.
## The stretches come from CeilingZones (the same the generator uses); the checks are written here.
static func check_ceilings(suite: TestSuite, layout: LevelLayout, config: LevelConfig, tag: String) -> void:
	var tuning: MovementTuning = level_tuning(suite, config)
	var zones := CeilingZones.make(config, tuning)
	var finish: float = layout.length - config.end_clear_distance + 0.001
	var half: float = tuning.fence_depth * 0.5
	var grid: FloorRoute = null
	for p: Dictionary in layout.pads:
		var at: float = float(p["at"])
		var lane: int = int(p["lane"])
		var covered: bool = false
		for h: Dictionary in layout.hulls:
			covered = covered or (float(h["start"]) <= at - 1.0 and float(h["end"]) >= at + 10.0 and layout.hull_covers(h, lane))
		suite.check(covered, "pad at %.1f has a ceiling above it, over its lane %d %s" % [at, lane, tag])
		var zone: Vector2 = zones.pad_zone(at)
		suite.check(not gapped_between(layout, lane, zone.x, zone.y),
			"pad at %.1f is on solid floor, a full jump clear of any hole in its lane %s" % [at, tag])
		for f: Dictionary in layout.fences:
			suite.check(int(f["lane"]) != lane or float(f["at"]) + half < zone.x or float(f["at"]) - half > zone.y,
				"pad at %.1f: no fence in its lane from a jump before it until the lift reaches the hull (fence at %.1f) %s"
				% [at, f["at"], tag])
		for r: Dictionary in layout.ramps:
			suite.check(layout.outer_lane(int(r["side"])) != lane or float(r["at"]) > at + tuning.pad_length
				or float(r["at"]) + tuning.ramp_length < zone.x, "pad at %.1f: no ramp on the way to it %s" % [at, tag])
		for e: Dictionary in layout.enemies:
			# In the pad's lane an enemy keeps off the pad's whole zone; elsewhere off where it lies.
			var span: Vector2 = LevelGenerator.enemy_floor_span(e)
			var keep: Vector2 = zone if int(e.get("lane", -1)) == lane else Vector2(at, at + tuning.pad_length)
			suite.check(span.x > keep.y or span.y < keep.x,
				"pad at %.1f: no floor enemy in its way (%s at %.1f, lane %d) %s" % [at, e["type"], e["at"], e.get("lane", -1), tag])
	for h: Dictionary in layout.hulls:
		var landing: Vector2 = zones.landing_zone(h)
		var lanes: Vector2i = layout.hull_lanes(h)
		suite.check(landing.y <= finish, "a ceiling and its landing zone end before the finish " + tag)
		if h.has("first_lane"):
			suite.check(int(h["first_lane"]) >= 0 and int(h["first_lane"]) <= int(h["last_lane"])
				and int(h["last_lane"]) < layout.lane_count and lanes != Vector2i(0, layout.lane_count - 1),
				"the ceiling at %.1f covers a range of real lanes, fewer than all (%s) %s" % [h["start"], lanes, tag])
		if lanes.x == lanes.y and layout.lane_count > 1:
			for p: Dictionary in layout.pads:
				if float(p["at"]) >= float(h["start"]) and float(p["at"]) <= float(h["end"]):
					suite.check(float(h["end"]) - float(p["at"]) <= config.one_lane_ceiling_seconds * tuning.run_speed + 0.01,
						"a one-lane ceiling is short (%.1f s from its pad at %.1f) %s" % [
							(float(h["end"]) - float(p["at"])) / tuning.run_speed, p["at"], tag])
		for lane: int in range(lanes.x, lanes.y + 1):
			suite.check(not gapped_between(layout, lane, landing.x, landing.y),
				"the landing zone after the ceiling at %.1f has no hole (lane %d) %s" % [h["end"], lane, tag])
		for f: Dictionary in layout.fences:
			suite.check(int(f["lane"]) < lanes.x or int(f["lane"]) > lanes.y
				or float(f["at"]) + half < landing.x or float(f["at"]) - half > landing.y,
				"the landing zone after the ceiling at %.1f has no fence (%.1f, lane %d) %s" % [h["end"], f["at"], f["lane"], tag])
		for e: Dictionary in layout.enemies:
			var span: Vector2 = LevelGenerator.enemy_floor_span(e)
			suite.check(span.x > landing.y or span.y < landing.x,
				"no floor enemy on the landing zone after the ceiling at %.1f (%s at %.1f) %s" % [h["end"], e["type"], e["at"], tag])
		if grid == null:
			grid = FloorRoute.new(layout, tuning)
		var route: Dictionary = floor_route(grid, zones, h)
		suite.check(bool(route["ok"]), "a floor route runs under the ceiling at %.1f without its pad (%s) %s"
			% [h["start"], route["reason"], tag])
	for c: Dictionary in layout.credits:
		if String(c["surface"]) == "ceiling":
			suite.check(not layout.hull_at(float(c["at"]), int(c["lane"])).is_empty(),
				"a credit on the ceiling at %.1f hangs under a ceiling over its lane %d %s" % [c["at"], c["lane"], tag])


## A floor route (FloorRoute.find, on the layout's `grid`) under ceiling section `h` to the end of its
## landing zone, never stepping on a pad. It starts at the last clear stretch before its pads'
## run-up (FloorRoute.clear_start): the player may be in any lane there, as between any two of the
## generator's patterns.
static func floor_route(grid: FloorRoute, zones: CeilingZones, h: Dictionary) -> Dictionary:
	var from: float = float(h["start"])
	for p: Dictionary in grid.layout.pads:
		if float(p["at"]) >= float(h["start"]) and float(p["at"]) <= float(h["end"]):
			from = minf(from, zones.pad_zone(float(p["at"])).x)
	return grid.find(grid.clear_start(from - ROUTE_LEAD), zones.landing_zone(h).y)


static func check_rules(suite: TestSuite, layout: LevelLayout, config: LevelConfig, tag: String) -> void:
	var tuning: MovementTuning = level_tuning(suite, config)
	var speed: float = tuning.run_speed
	var pace: float = tuning.pace()
	var pads: Array[float] = []
	for p: Dictionary in layout.pads:
		if not pads.has(float(p["at"])):
			pads.append(float(p["at"]))
	pads.sort()
	# Drones (GDD §9.6).
	var dt := EnemyDirector.tuning_for("drone") as DroneTuning
	var drones: Array[float] = []
	for e: Dictionary in layout.enemies:
		if String(e["type"]) == "drone":
			drones.append(float(e["at"]))
	drones.sort()
	for d: float in drones:
		var first: float = INF
		for p: float in pads:
			if p > d + 0.01:
				first = p
				break
		suite.check(first < INF and (first - d) / speed >= dt.first_pad_seconds - 0.001,
			"at least %d s of dodging before a drone's first pad (%.2f s) %s" % [dt.first_pad_seconds, (first - d) / speed, tag])
	if not drones.is_empty():
		var schedule_start: float = INF
		for p: float in pads:
			if p > drones[0] + 0.01:
				schedule_start = p
				break
		for i: int in pads.size() - 1:
			if pads[i] < schedule_start - 0.01:
				continue
			var gap: float = (pads[i + 1] - pads[i]) / speed
			suite.check(gap >= dt.pad_repeat_min_seconds - 0.001 and gap <= dt.pad_repeat_max_seconds + 0.001,
				"a drone's pads stay 8–10 s apart (%.2f s at %.0f m) %s" % [gap, pads[i], tag])
	# Bad Dream chases (GDD §9.7).
	var bt := EnemyDirector.tuning_for("bad_dream") as BadDreamTuning
	var last_ok: float = layout.length - config.end_clear_distance \
		- (bt.pad_ceiling_seconds + config.hull_landing_seconds) * speed
	var prev_end: float = -INF
	var hosts: Array[float] = []
	for e: Dictionary in layout.enemies:
		if String(e["type"]) == "cyborg" and bool((e.get("params", {}) as Dictionary).get("host", false)):
			hosts.append(float(e["at"]))
	hosts.sort()
	for at: float in hosts:
		var s: Vector2 = bt.chase_stretch(at, speed)
		suite.check(s.y <= last_ok + 0.01, "a host's chase fits before the level's end " + tag)
		suite.check(s.x >= prev_end + bt.host_gap_seconds * speed - 0.01, "Bad Dream chases never overlap " + tag)
		prev_end = s.y
		var cursor: float = s.x
		var worst: float = 0.0
		for p: float in pads:
			if p > s.x and p <= s.y:
				worst = maxf(worst, p - cursor)
				cursor = p
		worst = maxf(worst, s.y - cursor)
		suite.check(worst <= bt.pad_gap_seconds * speed + 0.01,
			"anti-grav pads through a whole chase, at most %.0f s apart (%.1f s) %s" % [bt.pad_gap_seconds, worst / speed, tag])
		# The Bad Dream's chase and an Octodog's charges never overlap (GDD §9.7): the Octodog rules,
		# which run after the host rules, plan each dog's run off the chases.
		for e: Dictionary in layout.enemies:
			if String(e["type"]) == "octodog":
				var run: Vector2 = LevelGenerator.enemy_floor_span(e)
				suite.check(run.y < s.x or run.x > s.y,
					"a Bad Dream's chase (%.0f–%.0f) keeps off an Octodog's run (%.0f–%.0f) %s" % [s.x, s.y, run.x, run.y, tag])
	# Octodog charges and runs stay off pads and ceiling landings (the floor under a ceiling is theirs
	# too, GDD §3).
	var ot := EnemyDirector.tuning_for("octodog") as OctodogTuning
	var window: float = ot.window_length(speed, config.enemy_scaling, pace)
	var stop: float = ot.stop_distance(speed, config.enemy_scaling, pace)
	for e: Dictionary in layout.enemies:
		if String(e["type"]) != "octodog":
			continue
		var charges: Array = (e.get("params", {}) as Dictionary).get("charge_at", [])
		suite.check(not charges.is_empty(), "an Octodog has its charges planned " + tag)
		for a: Variant in charges:
			suite.check(Octodog.window_clear(layout, float(a), float(a) + window, pace), "an Octodog charge has a clear stretch " + tag)
		if not charges.is_empty():
			suite.check(not Octodog.pad_or_landing_between(layout, float(charges[0]) - 6.0 * pace,
				float(charges[-1]) + stop + 2.0 * pace, pace), "an Octodog's whole run stays off pads and ceiling landings " + tag)
	# Cyborgs keep their margin from floor obstacles and landing zones; every generator powers a fence.
	var ct := EnemyDirector.tuning_for("cyborg") as CyborgTuning
	var spans: Array[Vector2] = CyborgRules.obstacle_spans(layout, tuning, CeilingZones.make(config, tuning))
	var gt := EnemyDirector.tuning_for("generator") as FenceGeneratorTuning
	var geo := TrackGeometry.new(layout.lane_count, tuning)
	for e: Dictionary in layout.enemies:
		match String(e["type"]):
			"cyborg":
				var margin: float = CyborgRules.obstacle_margin_at(ct, pace)
				suite.check(not CyborgRules.near_any(spans, float(e["at"]), margin),
					"a cyborg keeps %.1f m from floor obstacles (at %.0f) %s" % [margin, e["at"], tag])
			"generator":
				suite.check(not FenceGenerator.fences_in_reach(layout, geo, float(e["at"]), int(e["lane"]), gt.emp_radius).is_empty(),
					"a fence generator powers a fence (at %.0f) %s" % [e["at"], tag])


## A feature the game knows (LevelConfig.features): one feature_positions() can find, an enemy type
## with generator rules, a planned feature (LevelConfig.PLANNED_FEATURES), or one a boss's arena
## lists. Catches typos in level and pattern data.
static func known_feature(feature: String) -> bool:
	return can_locate(feature) or LevelConfig.PLANNED_FEATURES.has(feature) \
		or ResourceLoader.exists("res://scripts/enemies/%s_rules.gd" % feature) \
		or boss_arena_features().has(feature)


## The features the bosses' arena configs list (data/bosses/*.tres, BossDef.arena): a pattern for one
## boss's arena alone requires a feature only that arena lists.
static func boss_arena_features() -> PackedStringArray:
	var out := PackedStringArray()
	for file: String in DirAccess.get_files_at("res://data/bosses"):
		if not file.ends_with(".tres"):
			continue
		var def := load("res://data/bosses".path_join(file)) as BossDef
		if def != null and def.arena != null:
			for f: String in def.arena.features:
				if not out.has(f):
					out.append(f)
	return out


## True if feature_positions() can find `feature`'s pieces or enemies: the mechanics, hosts, vent
## screeches, any enemy type with a script (a planned feature once its enemy is built), and a
## feature whose rules script answers for itself (`positions`, e.g. wall fences once B5 adds them).
static func can_locate(feature: String) -> bool:
	if feature in ["ramps", "ceilings", "speed_pads", "pulsing", "host", "screech_vents"]:
		return true
	var rules: String = "res://scripts/enemies/%s_rules.gd" % feature
	if ResourceLoader.exists(rules) and (load(rules) as GDScript).has_method("positions"):
		return true
	return ResourceLoader.exists("res://scripts/enemies/%s.gd" % feature)


## Track distances of everything `feature` placed (the generator's own check,
## LevelGenerator.feature_positions).
static func feature_positions(layout: LevelLayout, feature: String) -> Array[float]:
	return LevelGenerator.feature_positions(layout, feature)


static func gapped_between(layout: LevelLayout, lane: int, from: float, to: float) -> bool:
	for g: Dictionary in layout.gaps:
		if g["lane"] == lane and g["start"] <= to and g["end"] >= from:
			return true
	return false


## Longest stretch where every lane is a hole at once (intersection of the lanes' gap intervals).
static func longest_all_lane_hole(layout: LevelLayout) -> float:
	var common: Array[Vector2] = []
	for lane: int in layout.lane_count:
		var mine: Array[Vector2] = []
		for g: Dictionary in layout.gaps:
			if g["lane"] == lane:
				mine.append(Vector2(g["start"], g["end"]))
		if lane == 0:
			common = mine
			continue
		var next: Array[Vector2] = []
		for a: Vector2 in common:
			for b: Vector2 in mine:
				var lo: float = maxf(a.x, b.x)
				var hi: float = minf(a.y, b.y)
				if hi > lo:
					next.append(Vector2(lo, hi))
		common = next
	var longest: float = 0.0
	for v: Vector2 in common:
		longest = maxf(longest, v.y - v.x)
	return longest
