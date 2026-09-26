class_name LayoutChecks
extends RefCounted
## Fairness checks for generated layouts, shared by the generator suite (many seeds of the prototype
## level) and the campaign suite (every campaign level):
## - check_layout: every layout, whatever its features: holes are jumpable and no stretch where every
##   lane is a hole is longer than a jump, fences stand on floor, pads sit under a ceiling on solid
##   floor, the floor under a ceiling and its landing stay clear (GDD §3), ramps stand on floor with
##   no sign at their wall entry, and nothing lies in the end-clear stretch.
## - check_rules: the enemy rules still hold when many features share a level: drones get 10 s before
##   their first pad and then pads 8–10 s apart (GDD §9.6), a Bad Dream's chase has pads at most
##   10 s apart and keeps off Octodog runs (GDD §9.7), Octodog runs stay off ceilings (GDD §3),
##   cyborgs keep their margin from floor obstacles, and every fence generator powers a fence.
## Each check goes through `suite.check()`, so failures are reported by the suite that called.

const CyborgRules = preload("res://scripts/enemies/cyborg_rules.gd")


static func check_layout(suite: TestSuite, layout: LevelLayout, config: LevelConfig, tag: String) -> void:
	var tuning: MovementTuning = suite.tuning
	var n: int = layout.lane_count
	var max_gap: float = tuning.jump_distance(tuning.run_speed) * config.max_gap_jump_fraction + 0.001
	var finish_buffer: float = layout.length - config.end_clear_distance + 0.001
	var landing: float = config.hull_landing_seconds * tuning.run_speed
	for g: Dictionary in layout.gaps:
		suite.check(g["lane"] >= 0 and g["lane"] < n, "gap lane in range " + tag)
		suite.check(g["end"] - g["start"] <= max_gap, "gap jumpable (%.1f m) %s" % [g["end"] - g["start"], tag])
		suite.check(g["end"] <= finish_buffer, "gap before the end-clear stretch " + tag)
	for f: Dictionary in layout.fences:
		suite.check(f["lane"] >= 0 and f["lane"] < n, "fence lane in range " + tag)
		suite.check(not gapped_between(layout, f["lane"], f["at"], f["at"]), "fence not over a gap at %.1f %s" % [f["at"], tag])
		suite.check(f["at"] <= finish_buffer, "fence before the end-clear stretch " + tag)
	suite.check(longest_all_lane_hole(layout) <= max_gap, "every all-lane hole is jumpable " + tag)
	for p: Dictionary in layout.pads:
		var covered: bool = false
		for h: Dictionary in layout.hulls:
			if h["start"] <= p["at"] - 1.0 and h["end"] >= p["at"] + 10.0:
				covered = true
		suite.check(covered, "pad at %.1f has a hull above %s" % [p["at"], tag])
		suite.check(not gapped_between(layout, p["lane"], p["at"] - 6.0, p["at"] + tuning.pad_length),
			"pad at %.1f is reachable on solid floor %s" % [p["at"], tag])
	for h: Dictionary in layout.hulls:
		suite.check(h["end"] + landing <= finish_buffer, "hull and its landing end before the finish " + tag)
		for f: Dictionary in layout.fences:
			suite.check(f["at"] < h["start"] or f["at"] > h["end"], "no fence under the ceiling at %.1f %s" % [f["at"], tag])
		for lane: int in n:
			suite.check(not gapped_between(layout, lane, h["start"], h["end"]), "no gap under the ceiling at %.1f %s" % [h["start"], tag])
		for lane: int in n:
			suite.check(not gapped_between(layout, lane, h["end"] - 2.0, h["end"] + landing * 0.8),
				"hull landing clear at %.1f %s" % [h["end"], tag])
	for r: Dictionary in layout.ramps:
		var lane: int = layout.outer_lane(r["side"])
		suite.check(not gapped_between(layout, lane, r["at"], r["at"] + tuning.ramp_length), "ramp on solid floor " + tag)
		for s: Dictionary in layout.signs:
			if s["side"] == r["side"]:
				suite.check(s["end"] < r["at"] - 2.0 or s["start"] > r["at"] + tuning.ramp_length + 2.0,
					"ramp entry not blocked by a sign " + tag)
	for s: Dictionary in layout.signs:
		suite.check(s["end"] <= finish_buffer, "sign before the end-clear stretch " + tag)


static func check_rules(suite: TestSuite, layout: LevelLayout, config: LevelConfig, tag: String) -> void:
	var tuning: MovementTuning = suite.tuning
	var speed: float = tuning.run_speed
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
	# Octodog runs stay off ceilings (GDD §3).
	var ot := EnemyDirector.tuning_for("octodog") as OctodogTuning
	var window: float = ot.window_length(speed, config.enemy_scaling)
	var stop: float = ot.stop_distance(speed, config.enemy_scaling)
	for e: Dictionary in layout.enemies:
		if String(e["type"]) != "octodog":
			continue
		var charges: Array = (e.get("params", {}) as Dictionary).get("charge_at", [])
		suite.check(not charges.is_empty(), "an Octodog has its charges planned " + tag)
		for a: Variant in charges:
			suite.check(Octodog.window_clear(layout, float(a), float(a) + window), "an Octodog charge has a clear stretch " + tag)
		if not charges.is_empty():
			suite.check(not Octodog.ceiling_between(layout, float(charges[0]) - 6.0, float(charges[-1]) + stop + 2.0),
				"an Octodog's whole run stays off ceilings " + tag)
	# Cyborgs keep their margin from floor obstacles; every generator powers a fence.
	var ct := EnemyDirector.tuning_for("cyborg") as CyborgTuning
	var spans: Array[Vector2] = CyborgRules.obstacle_spans(layout, tuning)
	var gt := EnemyDirector.tuning_for("generator") as FenceGeneratorTuning
	var geo := TrackGeometry.new(layout.lane_count, tuning)
	for e: Dictionary in layout.enemies:
		match String(e["type"]):
			"cyborg":
				suite.check(not CyborgRules.near_any(spans, float(e["at"]), ct.obstacle_margin),
					"a cyborg keeps %.0f m from floor obstacles (at %.0f) %s" % [ct.obstacle_margin, e["at"], tag])
			"generator":
				suite.check(not FenceGenerator.fences_in_reach(layout, geo, float(e["at"]), int(e["lane"]), gt.emp_radius).is_empty(),
					"a fence generator powers a fence (at %.0f) %s" % [e["at"], tag])


## A feature the game knows (LevelConfig.features): one feature_positions() can find, an enemy type
## with generator rules, or a planned feature (LevelConfig.PLANNED_FEATURES). Catches typos in level
## and pattern data.
static func known_feature(feature: String) -> bool:
	return can_locate(feature) or LevelConfig.PLANNED_FEATURES.has(feature) \
		or ResourceLoader.exists("res://scripts/enemies/%s_rules.gd" % feature)


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
