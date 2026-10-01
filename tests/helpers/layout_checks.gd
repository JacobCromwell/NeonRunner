class_name LayoutChecks
extends RefCounted
## Fairness checks for generated layouts, shared by the generator suite (many seeds of the prototype
## level), the enemy suites and the campaign suite (every campaign level):
## - check_layout: every layout, whatever its features: holes are jumpable and no stretch where every
##   lane is a hole is longer than a jump (a floor cut's stretch counts as a hole), fences stand on
##   floor, ramps stand on floor with no sign at their wall entry, nothing lies in the end-clear
##   stretch, every ceiling keeps GDD §3 (check_ceilings), every zone doodad stands where its push is
##   fair (check_doodads), and every floor cut keeps GDD §9.9's limits (check_cuts).
## - check_ceilings: the floor under a ceiling may be dangerous (GDD §3, changed September 26, 2026),
##   but every pad lies under a ceiling and can be stepped on, every landing zone is safe to land on,
##   floor enemies keep off both (CeilingZones), and a floor route runs under every ceiling without
##   its pad (FloorRoute).
## - check_rules: the enemy rules still hold when many features share a level: drones get 10 s before
##   their first pad and then pads 8–10 s apart (GDD §9.6), a Bad Dream's chase has pads at most
##   10 s apart and keeps off Octodog runs (GDD §9.7), Octodog runs stay off pads and ceiling
##   landings, cyborgs keep their margin from floor obstacles, every fence generator powers a
##   fence, and Barnacle Turrets keep their limits (check_turrets, GDD §9.8).
## Each check goes through `suite.check()`, so failures are reported by the suite that called.
## Every check runs at the level's own run speed (level_tuning: a campaign level's is its zone's), with
## the margins in metres stretched by its pace, as the generator builds it (GDD §3: a faster zone keeps
## every reaction window in seconds).

const CyborgRules = preload("res://scripts/enemies/cyborg_rules.gd")
const HoverTruckRules = preload("res://scripts/enemies/hover_truck_rules.gd")
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
	check_doodads(suite, layout, config, tag)
	check_cuts(suite, layout, config, tag)
	check_wall_fences(suite, layout, config, tag)


## Wall fences (task B5; GDD §9.1: "never where a ramp launches the player into one while it's on, and
## never on the same wall section as a sign or a window cyborg"; a player on the wall always sees the
## warning in time to drop off or time it), wherever the generator puts one (WallFencePlacement), at any
## lane count, at the level's own run speed (WallFenceTuning's times are seconds at it, so they hold at
## every zone's speed):
## - on a real wall, over a known band, pulsing (on, and off long enough to hold its whole warning, the
##   floor fence's), a phase within its cycle; only in a level with its feature (full-height ones
##   `wall_fences`, partial ones `wall_fences_partial`), never before that feature's start;
## - its drop window (drop_before_seconds before it to drop_after_seconds after it) between the run-up
##   and the end-clear stretch;
## - nothing else on its wall section: no sign or window cyborg within wall_clear_seconds of it on its
##   wall, no wall vent's screech from vent_before_seconds before it to vent_after_seconds after;
## - never where a ramp launches the player along its wall: off the whole wall run a ramp on its wall
##   launches (RampLaunch, with R1's fading boost; also the longest one, with claws and a speed pad's
##   boost carried onto it), and the tuning's margins around it;
## - the floor beside it clear to drop off into: over its drop window the outer lane on its side holds
##   no hole, fence, floor cut, pad, speed pad, ramp or floor enemy, and no hover truck keeps that lane;
## - nothing running meanwhile: no floor cut's window, drone wave (to its first pad), hover truck's
##   stay, Octodog run, Resonator visit or Bad Dream chase reaches its drop window;
## - spaced from the other wall fences: same_side_gap_seconds on its wall, gap_seconds on either.
static func check_wall_fences(suite: TestSuite, layout: LevelLayout, config: LevelConfig, tag: String) -> void:
	if layout.wall_fences.is_empty():
		return
	var tuning: MovementTuning = level_tuning(suite, config)
	var speed: float = tuning.run_speed
	var pace: float = tuning.pace()
	var t: WallFenceTuning = WallFencePlacement.tuning()
	var half: float = tuning.fence_depth * 0.5
	var before: float = t.drop_before_seconds * speed
	var after: float = t.drop_after_seconds * speed
	var clear: float = t.wall_clear_seconds * speed
	var pt := load("res://data/tuning/powerups.tres") as PowerupTuning
	var bt := EnemyDirector.tuning_for("bad_dream") as BadDreamTuning
	var tt := EnemyDirector.tuning_for("hover_truck") as HoverTruckTuning
	var dt := EnemyDirector.tuning_for("drone") as DroneTuning
	var wt := EnemyDirector.tuning_for("window_cyborg") as WindowCyborgTuning
	var resonator: GDScript = load("res://scripts/enemies/resonator_rules.gd") as GDScript
	var gen: LevelGenerator = LevelGenerator.for_layout(config, tuning, layout)
	var partial_start: float = config.feature_start("wall_fences_partial") * layout.length
	var full_start: float = config.feature_start("wall_fences") * layout.length
	for w: Dictionary in layout.wall_fences:
		var side: int = int(w["side"])
		var at: float = float(w["at"])
		var band: String = String(w["band"])
		var lane: int = layout.outer_lane(side)
		var drop := Vector2(at - before, at + after)
		var x: String = "(wall fence on side %d at %.1f, %s) %s" % [side, at, band, tag]
		var meets := func(from: float, to: float) -> bool: return from <= drop.y and to >= drop.x
		# What it is.
		suite.check(side == -1 or side == 1, "a wall fence is on a wall " + x)
		suite.check(WallFencePlan.BANDS.has(band), "a wall fence covers a known band " + x)
		suite.check(float(w["pulse_on"]) > 0.0 and float(w["pulse_off"]) >= tuning.fence_pulse_warning + 0.1,
			"a wall fence switches on and off, its whole warning within its off time (on %.2f s, off %.2f s) %s" % [
				w["pulse_on"], w["pulse_off"], x])
		suite.check(float(w["phase"]) >= 0.0 and float(w["phase"]) < 1.0, "its phase lies in its cycle " + x)
		if band == "full":
			suite.check(config.has_feature("wall_fences") and at >= full_start - 0.01,
				"a full-height wall fence only with `wall_fences`, after its start (%.0f m) %s" % [full_start, x])
		else:
			suite.check(config.has_feature("wall_fences_partial") and at >= partial_start - 0.01 and at >= full_start - 0.01,
				"a partial wall fence only with `wall_fences_partial`, after its start (%.0f m) %s" % [partial_start, x])
		suite.check(drop.x >= config.start_clear_distance - 0.01 and drop.y <= layout.length - config.end_clear_distance + 0.01,
			"a wall fence lies between the run-up and the end-clear stretch " + x)
		# Its wall section.
		for s: Dictionary in layout.signs:
			if int(s["side"]) == side:
				suite.check(float(s["end"]) < at - half - clear + 0.01 or float(s["start"]) > at + half + clear - 0.01,
					"no sign on a wall fence's wall section (sign %.1f-%.1f) %s" % [s["start"], s["end"], x])
		for e: Dictionary in layout.enemies:
			if int(e.get("side", 0)) != side:
				continue
			var e_at: float = float(e["at"])
			match String(e["type"]):
				"window_cyborg":
					suite.check(absf(e_at - at) >= wt.window_length * 0.5 + half + clear - 0.01,
						"no window cyborg on a wall fence's wall section (%.1f) %s" % [e_at, x])
				"screech":
					if String((e.get("params", {}) as Dictionary).get("source", "vent")) == "vent":
						suite.check(at < e_at - t.vent_before_seconds * speed - half + 0.01 or at > e_at + t.vent_after_seconds * speed + half - 0.01,
							"no wall vent's screech by a wall fence on its wall (vent at %.1f) %s" % [e_at, x])
		# Ramps: never where one launches the player along its wall.
		for r: Dictionary in layout.ramps:
			if int(r["side"]) != side:
				continue
			var plain: RampLaunch = RampLaunch.of(r, tuning, speed)
			var longest: RampLaunch = RampLaunch.of(r, tuning, speed, tuning.speed_pad_boost, pt.claws_wall_time_multiplier)
			suite.check(at + half < float(r["at"]) or at - half > plain.end(),
				"a ramp never launches the player into a wall fence (ramp at %.1f, its wall run to %.1f) %s" % [r["at"], plain.end(), x])
			suite.check(at < float(r["at"]) - t.ramp_before_seconds * speed - half + 0.01
				or at > longest.end() + t.ramp_after_seconds * speed + half - 0.01,
				"nor along the longest wall run it launches, with the margins (ramp at %.1f, to %.1f) %s" % [r["at"], longest.end(), x])
		# The outer lane beside it, clear to drop off into.
		for g: Dictionary in layout.gaps:
			suite.check(int(g["lane"]) != lane or not meets.call(float(g["start"]), float(g["end"])),
				"no hole where a wall runner drops off a wall fence's wall (%.1f) %s" % [g["start"], x])
		for f: Dictionary in layout.fences:
			suite.check(int(f["lane"]) != lane or not meets.call(float(f["at"]) - half, float(f["at"]) + half),
				"no fence where a wall runner drops off (%.1f) %s" % [f["at"], x])
		for p: Dictionary in layout.pads:
			suite.check(int(p["lane"]) != lane or not meets.call(float(p["at"]), float(p["at"]) + tuning.pad_length),
				"no pad where a wall runner drops off (%.1f) %s" % [p["at"], x])
		for p: Dictionary in layout.speed_pads:
			suite.check(int(p["lane"]) != lane or not meets.call(float(p["at"]), float(p["at"]) + tuning.speed_pad_length),
				"no speed pad where a wall runner drops off (%.1f) %s" % [p["at"], x])
		for r: Dictionary in layout.ramps:
			suite.check(layout.outer_lane(int(r["side"])) != lane or not meets.call(float(r["at"]), float(r["at"]) + tuning.ramp_length),
				"no ramp where a wall runner drops off (%.1f) %s" % [r["at"], x])
		for c: Dictionary in layout.cuts:
			var lw: Vector2 = FloorCutPlan.lane_window(c)
			suite.check(int(c["lane"]) != lane or not meets.call(lw.x, lw.y), "no floor cut where a wall runner drops off " + x)
			var cw: Vector2 = FloorCutPlan.window(c, speed)
			suite.check(not meets.call(cw.x, cw.y), "no floor cut runs by a wall fence (one thing at a time) " + x)
		# Enemies: none on the floor beside it, and no big attack meanwhile.
		for e: Dictionary in layout.enemies:
			var e_at: float = float(e["at"])
			var type: String = String(e["type"])
			if int(e.get("side", 0)) == 0 and int(e.get("lane", -1)) == lane:
				var span: Vector2 = LevelGenerator.enemy_floor_span(e, pace)
				suite.check(span.y < span.x or not meets.call(span.x, span.y),
					"no floor enemy where a wall runner drops off (%s at %.0f) %s" % [type, e_at, x])
			var busy: Array[Vector2] = []
			match type:
				"cyborg":
					if bool((e.get("params", {}) as Dictionary).get("host", false)):
						busy.append(bt.chase_stretch(e_at, speed))
				"drone":
					busy.append(Vector2(e_at, e_at + dt.first_pad_seconds * speed))
				"hover_truck":
					busy.append(Vector2(HoverTruckRules.window_start(tt, e_at, pace), e_at + tt.stay_min_seconds * speed))
					if int(e.get("lane", -1)) == lane:
						busy.append(Vector2(HoverTruckRules.window_start(tt, e_at, pace), HoverTruckRules.window_end(tt, e_at, speed)))
				"octodog":
					busy.append(LevelGenerator.enemy_floor_span(e, pace))
				"resonator":
					busy.append(resonator.call("keep_out", gen, e))
			for b: Vector2 in busy:
				var s: Vector2 = b
				# A drone wave ends at its first pad when that comes sooner.
				if type == "drone":
					for p: Dictionary in layout.pads:
						if float(p["at"]) > e_at + 0.01 and float(p["at"]) < s.y:
							s.y = float(p["at"])
				suite.check(s.y < s.x or not meets.call(s.x, s.y),
					"no big attack runs by a wall fence (%s at %.0f: %.1f-%.1f) %s" % [type, e_at, s.x, s.y, x])
		# Other wall fences.
		for o: Dictionary in layout.wall_fences:
			if is_same(o, w):
				continue
			var apart: float = absf(float(o["at"]) - at)
			suite.check(apart >= t.gap_seconds * speed - 0.02, "wall fences stand %.1f s apart at least (%.1f m) %s" % [
				t.gap_seconds, apart, x])
			if int(o["side"]) == side:
				suite.check(apart >= t.same_side_gap_seconds * speed - 0.02,
					"wall fences on one wall stand %.1f s apart at least (%.1f m) %s" % [t.same_side_gap_seconds, apart, x])


## Floor cuts (task B4; GDD §9.9, the Buzz Overdrive's: "it never cuts a lane holding a ramp, a pad or
## the safe landing zone after a ceiling. On 3 lanes, two lanes always stay whole"; "only one at a
## time"; "leave its lane before it arrives"), wherever one is planned (LevelLayout.cuts, FloorCutPlan),
## at any lane count:
## - in a real lane, its warning before its charge, its stretch around where it meets the player, all
##   between the run-up and the end-clear stretch, and its cause standing at its end, in its lane;
## - one at a time: no two windows (from the warning to the cut's end) overlap;
## - nothing else in its lane from the warning to past its cause's spot: no hole, fence, pad's zone,
##   speed pad, ramp (or the wall run one launches until it drops the player back), zone doodad or
##   floor credit; no landing zone of a ceiling over its lane reaches there;
## - the other lanes whole along its stretch: on 3 lanes no hole in either (GDD §9.9), on more holes in
##   at most LevelConfig.cut_holes_beside of them (and two always whole);
## - nothing else going on meanwhile: no floor enemy's stretch (its own cause aside), Bad Dream chase,
##   drone wave before its first pad or hover truck's shortest stay reaches its window, nor a truck's
##   whole stay in its lane;
## - a floor route (FloorRoute, which keeps out of a cut's lane from where it would reach a player in
##   it) from its lane, LevelConfig.cut_reaction_seconds after its warning starts, to past its cause's
##   spot: a player who reacts can always leave the lane.
static func check_cuts(suite: TestSuite, layout: LevelLayout, config: LevelConfig, tag: String) -> void:
	if layout.cuts.is_empty():
		return
	var tuning: MovementTuning = level_tuning(suite, config)
	var speed: float = tuning.run_speed
	var pace: float = tuning.pace()
	var zones := CeilingZones.make(config, tuning)
	var n: int = layout.lane_count
	var half: float = tuning.fence_depth * 0.5
	var whole: int = n - 1 if n <= 3 else maxi(n - 1 - config.cut_holes_beside, mini(2, n - 1))
	var grid := FloorRoute.new(layout, tuning)
	var bt := EnemyDirector.tuning_for("bad_dream") as BadDreamTuning
	var tt := EnemyDirector.tuning_for("hover_truck") as HoverTruckTuning
	var dt := EnemyDirector.tuning_for("drone") as DroneTuning
	var sorted: Array[Dictionary] = layout.cuts.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["end"]) < float(b["end"]))
	var prev: float = -INF
	for c: Dictionary in sorted:
		var lane: int = int(c["lane"])
		var start: float = float(c["start"])
		var end: float = float(c["end"])
		var t: String = "(cut in lane %d, %.1f-%.1f) %s" % [lane, start, end, tag]
		var meet: float = FloorCutPlan.meet(c, speed)
		var lane_span: Vector2 = FloorCutPlan.lane_window(c)
		var span: Vector2 = FloorCutPlan.window(c, speed)
		suite.check(lane >= 0 and lane < n, "a cut is in a real lane " + t)
		suite.check(FloorCutPlan.warn_at(c) < FloorCutPlan.charge_at(c) and FloorCutPlan.charge_at(c) < meet
			and start < meet and meet < end, "a cut warns, then runs from its end to past where it meets the player " + t)
		suite.check(lane_span.x >= config.start_clear_distance - 0.01 and span.y <= layout.length - config.end_clear_distance + 0.01,
			"a cut lies between the run-up and the end-clear stretch " + t)
		suite.check(span.x > prev, "one cut at a time (the last one's window ends at %.1f) %s" % [prev, t])
		prev = span.y
		var cause: bool = false
		for e: Dictionary in layout.enemies:
			cause = cause or (int(e.get("lane", -1)) == lane and absf(float(e["at"]) - end) < 0.01)
		suite.check(cause, "a cut's cause waits at its end, in its lane " + t)
		# Nothing else in its lane over its lane window.
		var inside := func(from: float, to: float) -> bool: return from <= lane_span.y and to >= lane_span.x
		for g: Dictionary in layout.gaps:
			suite.check(int(g["lane"]) != lane or not inside.call(float(g["start"]), float(g["end"])),
				"no hole in a cut's lane (%.1f) %s" % [g["start"], t])
		for f: Dictionary in layout.fences:
			suite.check(int(f["lane"]) != lane or not inside.call(float(f["at"]) - half, float(f["at"]) + half),
				"no fence in a cut's lane (%.1f) %s" % [f["at"], t])
		for p: Dictionary in layout.pads:
			var zone: Vector2 = zones.pad_zone(float(p["at"]))
			suite.check(int(p["lane"]) != lane or not inside.call(zone.x, zone.y),
				"no pad's zone in a cut's lane (pad at %.1f) %s" % [p["at"], t])
		for p: Dictionary in layout.speed_pads:
			suite.check(int(p["lane"]) != lane or not inside.call(float(p["at"]), float(p["at"]) + tuning.speed_pad_length),
				"no speed pad in a cut's lane (%.1f) %s" % [p["at"], t])
		for r: Dictionary in layout.ramps:
			var run: float = maxf(RampLaunch.of(r, tuning, speed).end(), float(r["at"]) + tuning.ramp_length)
			suite.check(layout.outer_lane(int(r["side"])) != lane or not inside.call(float(r["at"]), run),
				"no ramp, or the wall run it launches, in a cut's lane (ramp at %.1f) %s" % [r["at"], t])
		suite.check(not layout.doodad_between(lane_span.x, lane_span.y, lane), "no zone doodad in a cut's lane " + t)
		for credit: Dictionary in layout.credits:
			suite.check(String(credit["surface"]) != "floor" or int(credit["lane"]) != lane
				or not inside.call(float(credit["at"]), float(credit["at"])), "no floor credit in a cut's lane (%.1f) %s" % [credit["at"], t])
		for h: Dictionary in layout.hulls:
			var landing: Vector2 = zones.landing_zone(h)
			suite.check(not layout.hull_covers(h, lane) or not inside.call(landing.x, landing.y),
				"no ceiling's landing zone over a cut's lane (ceiling ending %.1f) %s" % [h["end"], t])
		# The other lanes whole along its stretch.
		var holed: Dictionary = {}
		for g: Dictionary in layout.gaps:
			if int(g["lane"]) != lane and float(g["start"]) <= end and float(g["end"]) >= start:
				holed[int(g["lane"])] = true
		suite.check(holed.size() <= n - 1 - whole, "%d lanes beside a cut stay whole (holes in %s) %s" % [whole, holed.keys(), t])
		# Nothing else going on meanwhile.
		for e: Dictionary in layout.enemies:
			var at: float = float(e["at"])
			if int(e.get("lane", -1)) == lane and absf(at - end) < 0.01:
				continue
			var busy: Array[Vector2] = [LevelGenerator.enemy_floor_span(e, pace)]
			match String(e["type"]):
				"cyborg":
					if bool((e.get("params", {}) as Dictionary).get("host", false)):
						busy.append(bt.chase_stretch(at, speed))
				"drone":
					busy.append(Vector2(at, at + dt.first_pad_seconds * speed))
				"hover_truck":
					busy.append(Vector2(HoverTruckRules.window_start(tt, at, pace), at + tt.stay_min_seconds * speed))
					if int(e.get("lane", -1)) == lane:
						busy.append(Vector2(HoverTruckRules.window_start(tt, at, pace), HoverTruckRules.window_end(tt, at, speed)))
			for b: Vector2 in busy:
				suite.check(b.y < b.x or b.x > span.y or b.y < span.x,
					"nothing else goes on during a cut (%s at %.0f: %.1f-%.1f) %s" % [e["type"], at, b.x, b.y, t])
		# A player in its lane when it warns can leave it.
		var from: float = FloorCutPlan.warn_at(c) + config.cut_reaction_seconds * speed
		var route: Dictionary = grid.find(from, span.y + 2.0, lane)
		suite.check(bool(route["ok"]), "a player in a cut's lane %.2f s into its warning can leave it (%s) %s" % [
			config.cut_reaction_seconds, route["reason"], t])


## Zone doodads (GDD §3, owner's playtest September 30, 2026): scenery standing in lanes that never
## hurts; running into one pushes the player into a neighbouring lane. Wherever one stands
## (LevelGenerator._place_doodads), at any lane count:
## - in an inner lane (never the outermost: a wall runner's body reaches into it), its size class's
##   length, pushing to a side, after the run-up and before the end-clear stretch;
## - with nothing else in any lane from its push's lead before its front to the level's hard spacing
##   after its end: no hole, fence, ramp or the wall run it launches, pad (from its run-up to its
##   lift's end), speed pad, sign, floor enemy's stretch, ceiling or landing zone. So the push lands
##   on clear floor whichever lane it goes to, the player moves on clear floor after it, it leaves
##   every lane but its own to run in, and the player can cross its lane again before what comes
##   next, as between two patterns;
## - off every lane-bound attack while it can run: every Octodog's run (its floor stretch), every Bad
##   Dream chase and drone wave until its first pad, any lane while a hover truck is surely there, and
##   never in or pushing into a truck's lane until it has left;
## - one at a time: LevelConfig.doodad_gap_seconds from one's end to the next one's front.
static func check_doodads(suite: TestSuite, layout: LevelLayout, config: LevelConfig, tag: String) -> void:
	if layout.doodads.is_empty():
		return
	var tuning: MovementTuning = level_tuning(suite, config)
	var speed: float = tuning.run_speed
	var pace: float = tuning.pace()
	var zones := CeilingZones.make(config, tuning)
	var lead: float = LevelGenerator.doodad_lead_for(tuning)
	var after: float = config.spacing_seconds_hard * speed
	var half: float = tuning.fence_depth * 0.5
	var n: int = layout.lane_count
	var busy: Array[Array] = []  # [what, Vector2]
	for g: Dictionary in layout.gaps:
		busy.append(["a hole", Vector2(g["start"], g["end"])])
	for f: Dictionary in layout.fences:
		busy.append(["a fence", Vector2(float(f["at"]) - half, float(f["at"]) + half)])
	for r: Dictionary in layout.ramps:
		busy.append(["a ramp and its wall run", Vector2(r["at"], maxf(RampLaunch.of(r, tuning, speed).end(),
			float(r["at"]) + tuning.ramp_length))])
	for p: Dictionary in layout.pads:
		busy.append(["a pad's zone", zones.pad_zone(float(p["at"]))])
	for p: Dictionary in layout.speed_pads:
		busy.append(["a speed pad", Vector2(p["at"], float(p["at"]) + tuning.speed_pad_length)])
	for s: Dictionary in layout.signs:
		busy.append(["a sign", Vector2(s["start"], s["end"])])
	for h: Dictionary in layout.hulls:
		busy.append(["a ceiling or its landing zone", Vector2(h["start"], zones.landing_zone(h).y)])
	var bt := EnemyDirector.tuning_for("bad_dream") as BadDreamTuning
	var tt := EnemyDirector.tuning_for("hover_truck") as HoverTruckTuning
	var dt := EnemyDirector.tuning_for("drone") as DroneTuning
	var trucks: Array[Dictionary] = []
	for e: Dictionary in layout.enemies:
		var at: float = float(e["at"])
		var span: Vector2 = LevelGenerator.enemy_floor_span(e, pace)
		if span.y >= span.x:
			busy.append(["a floor enemy's stretch (%s at %.0f)" % [e["type"], at], span])
		match String(e["type"]):
			"cyborg":
				if bool((e.get("params", {}) as Dictionary).get("host", false)):
					busy.append(["a Bad Dream's chase", bt.chase_stretch(at, speed)])
			"drone":
				var first: float = INF
				for p: Dictionary in layout.pads:
					if float(p["at"]) > at + 0.01:
						first = minf(first, float(p["at"]))
				busy.append(["a drone wave until its first pad", Vector2(at, minf(first, at + dt.first_pad_seconds * speed))])
			"hover_truck":
				trucks.append(e)
				busy.append(["a hover truck's shortest stay", Vector2(HoverTruckRules.window_start(tt, at, pace),
					at + tt.stay_min_seconds * speed)])
	var sorted: Array[Dictionary] = layout.doodads.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["start"]) < float(b["start"]))
	var prev_end: float = -INF
	for d: Dictionary in sorted:
		var start: float = float(d["start"])
		var end: float = float(d["end"])
		var lane: int = int(d["lane"])
		var side: int = int(d["side"])
		var size := StringName(d["size"])
		var t: String = "(doodad at %.1f, lane %d) %s" % [start, lane, tag]
		suite.check(lane >= 1 and lane <= n - 2, "a doodad stands in an inner lane, never the outermost " + t)
		suite.check(side == -1 or side == 1, "a doodad pushes to one side " + t)
		suite.check(LevelLayout.DOODAD_SIZES.has(size) and absf(end - start - tuning.doodad_size(size).z) < 0.01,
			"a doodad is as long as its size class " + t)
		suite.check(start >= config.start_clear_distance - 0.01 and end <= layout.length - config.end_clear_distance + 0.01,
			"a doodad stands between the run-up and the end-clear stretch " + t)
		suite.check(start - prev_end >= config.doodad_gap_seconds * speed - 0.01,
			"doodads come one at a time (%.2f s apart) %s" % [(start - prev_end) / speed, t])
		prev_end = end
		var zone := Vector2(start - lead, end + after)
		for b: Array in busy:
			var span: Vector2 = b[1]
			suite.check(span.x > zone.y or span.y < zone.x,
				"nothing else goes on in any lane from a doodad's push to the spacing after it: %s at %.1f–%.1f %s"
				% [b[0], span.x, span.y, t])
		for e: Dictionary in trucks:
			var at: float = float(e["at"])
			var truck_lane: int = int(e.get("lane", -1))
			if HoverTruckRules.window_start(tt, at, pace) <= zone.y and HoverTruckRules.window_end(tt, at, speed) >= zone.x:
				suite.check(lane != truck_lane and lane + side != truck_lane,
					"a doodad neither stands in a hover truck's lane nor pushes into it while it's around " + t)


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
			var span: Vector2 = LevelGenerator.enemy_floor_span(e, zones.pace)
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
			var span: Vector2 = LevelGenerator.enemy_floor_span(e, zones.pace)
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
	check_turrets(suite, layout, config, speed, tag)


## Barnacle Turrets (GDD §9.8; barnacle_turret_rules.gd), at run speed `speed`: only in a level with the
## feature and never before its start; each under the ceiling its params name, over a lane that ceiling
## covers but no pad's, never on a one-lane ceiling, at most 2 per ceiling and those spaced apart, past
## the ceiling's pads and before its end by the tuning's times, off every credit on the ceiling in its
## lane, and never using the floor.
static func check_turrets(suite: TestSuite, layout: LevelLayout, config: LevelConfig, speed: float, tag: String) -> void:
	var t := EnemyDirector.tuning_for("barnacle_turret") as BarnacleTurretTuning
	var per_ceiling: Dictionary = {}
	for e: Dictionary in layout.enemies:
		if String(e["type"]) != "barnacle_turret":
			continue
		var at: float = e["at"]
		var lane: int = e["lane"]
		var where: String = "(at %.0f, lane %d) %s" % [at, lane, tag]
		suite.check(config.has_feature("barnacle_turret"), "a Barnacle Turret only in a level with the feature " + where)
		suite.check(at >= config.feature_start("barnacle_turret") * layout.length - 0.01,
			"no Barnacle Turret before the feature's start " + where)
		suite.check(not LevelGenerator.enemy_uses_floor(e), "a Barnacle Turret never uses the floor " + where)
		var params: Dictionary = e.get("params", {})
		var h: Dictionary = {}
		for hull: Dictionary in layout.hulls:
			if absf(float(hull["start"]) - float(params.get("hull_start", -INF))) < 0.01:
				h = hull
		suite.check(not h.is_empty() and absf(float(h["end"]) - float(params.get("hull_end", INF))) < 0.01,
			"a Barnacle Turret's params name its ceiling " + where)
		if h.is_empty() or t == null:
			continue
		var lanes: Vector2i = layout.hull_lanes(h)
		suite.check(at >= float(h["start"]) and at <= float(h["end"]) and layout.hull_covers(h, lane),
			"a Barnacle Turret hangs under its ceiling, over a lane it covers " + where)
		suite.check(int(params.get("first_lane", -1)) == lanes.x and int(params.get("last_lane", -1)) == lanes.y,
			"a Barnacle Turret's params give its ceiling's lanes " + where)
		suite.check(layout.hull_width(h) >= 2, "never a Barnacle Turret on a one-lane ceiling " + where)
		var last_pad: float = -INF
		var after: float = t.after_pad_seconds
		for p: Dictionary in layout.pads:
			if float(p["at"]) >= float(h["start"]) and float(p["at"]) <= float(h["end"]):
				last_pad = maxf(last_pad, float(p["at"]))
				var pad_lane: int = p["lane"]
				suite.check(pad_lane != lane, "a Barnacle Turret never hangs over a pad's lane " + where)
				# In the only lane beside a pad's, the rider's only lane to dodge into: more room.
				var others: bool = (pad_lane - 1 >= lanes.x and pad_lane - 1 != lane) or (pad_lane + 1 <= lanes.y and pad_lane + 1 != lane)
				if absi(pad_lane - lane) == 1 and not others:
					after = maxf(after, t.tight_after_pad_seconds)
		suite.check(at >= last_pad + after * speed - 0.01
			and at <= float(h["end"]) - t.before_end_seconds * speed + 0.01,
			"a Barnacle Turret stands past its ceiling's pads (%.1f s) and before its end %s" % [after, where])
		for c: Dictionary in layout.credits:
			if String(c["surface"]) == "ceiling" and int(c["lane"]) == lane:
				suite.check(absf(float(c["at"]) - at) >= t.credit_margin - 0.01,
					"a Barnacle Turret keeps off the ceiling's credits in its lane (credit at %.1f) %s" % [c["at"], where])
		var key: String = "%.2f" % float(h["start"])
		if not per_ceiling.has(key):
			per_ceiling[key] = {"ats": [], "free": 0}
			var pad_lanes: Array[int] = []
			for p: Dictionary in layout.pads:
				if float(p["at"]) >= float(h["start"]) and float(p["at"]) <= float(h["end"]) and not pad_lanes.has(int(p["lane"])):
					pad_lanes.append(int(p["lane"]))
			per_ceiling[key]["free"] = layout.hull_width(h) - pad_lanes.size()
		(per_ceiling[key]["ats"] as Array).append(at)
	for key: String in per_ceiling:
		var ats: Array = per_ceiling[key]["ats"]
		suite.check(ats.size() <= 2, "at most 2 Barnacle Turrets per ceiling (%d on the one at %s) %s" % [ats.size(), key, tag])
		if ats.size() == 2 and t != null:
			suite.check(absf(float(ats[1]) - float(ats[0])) >= t.spacing_seconds * speed - 0.01,
				"two Barnacle Turrets on one ceiling stand apart (%.1f m) %s" % [absf(float(ats[1]) - float(ats[0])), tag])
			suite.check(int(per_ceiling[key]["free"]) >= 2,
				"two Barnacle Turrets only where two of the ceiling's lanes are free of pads %s" % tag)


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


## True if feature_positions() can find `feature`'s pieces or enemies: the mechanics, the wall fences
## (full-height and partial), hosts, vent screeches, any enemy type with a script (a planned feature
## once its enemy is built), and a feature whose rules script answers for itself (`positions`).
static func can_locate(feature: String) -> bool:
	if feature in ["ramps", "ceilings", "speed_pads", "pulsing", "wall_fences", "wall_fences_partial", "host", "screech_vents"]:
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


## Longest stretch where every lane is a hole at once (intersection of the lanes' gap intervals; a
## floor cut's stretch counts as a hole in its lane).
static func longest_all_lane_hole(layout: LevelLayout) -> float:
	var common: Array[Vector2] = []
	for lane: int in layout.lane_count:
		var mine: Array[Vector2] = []
		for g: Dictionary in layout.gaps:
			if g["lane"] == lane:
				mine.append(Vector2(g["start"], g["end"]))
		for c: Dictionary in layout.cuts:
			if int(c["lane"]) == lane:
				mine.append(Vector2(c["start"], c["end"]))
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
