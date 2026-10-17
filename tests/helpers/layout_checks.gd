class_name LayoutChecks
extends RefCounted
## Fairness checks for generated layouts, shared by the generator suite (many seeds of the prototype
## level), the enemy suites and the campaign suite (every campaign level):
## - check_layout: every layout, whatever its features: holes are jumpable and no stretch where every
##   lane is a hole is longer than a jump (a floor cut's stretch counts as a hole), fences stand on
##   floor, ramps stand on floor with no sign at their wall entry, nothing lies in the end-clear
##   stretch, every ceiling keeps GDD §3 (check_ceilings), every zone doodad stands where its push is
##   fair (check_doodads), every floor cut keeps GDD §9.9's limits (check_cuts), the level's wider gaps
##   keep theirs (check_wide_gaps, task G7), every dash wall stands where it's fair (check_dash_walls,
##   task H7a), and every ceiling scenario keeps its rules (check_scenarios, task I4).
## - check_ceilings: the floor under a ceiling may be dangerous (GDD §3, changed September 26, 2026),
##   but every pad lies under a ceiling and can be stepped on, every landing zone is safe to land on,
##   floor enemies keep off both (CeilingZones), and a floor route runs under every ceiling without
##   its pad (FloorRoute).
## - check_rules: the enemy rules still hold when many features share a level: drones get 10 s before
##   their first pad and then pads 8–10 s apart (GDD §9.6; a fenced ceiling's added pads, a choice on one
##   ceiling, aside: task I4), a Bad Dream's chase has pads at most
##   10 s apart and keeps off Octodog runs (GDD §9.7), Octodog runs stay off pads and ceiling
##   landings, cyborgs keep their margin from floor obstacles, every fence generator powers a
##   fence, Barnacle Turrets keep their limits (check_turrets, GDD §9.8), and every cyborg planted in a
##   charge's path stands where the charge flattens it fairly (check_charge_paths, task G7).
## Each check goes through `suite.check()`, so failures are reported by the suite that called.
## Every check runs at the level's own run speed (level_tuning: a campaign level's is its zone's), with
## the margins in metres stretched by its pace, as the generator builds it (GDD §3: a faster zone keeps
## every reaction window in seconds).

const CyborgRules = preload("res://scripts/enemies/cyborg_rules.gd")
const HoverTruckRules = preload("res://scripts/enemies/hover_truck_rules.gd")
const BuzzOverdriveRulesScript = preload("res://scripts/enemies/buzz_overdrive_rules.gd")
const DashWallRulesScript = preload("res://scripts/enemies/dash_wall_rules.gd")
const TreasureStashRules = preload("res://scripts/enemies/treasure_stash_rules.gd")
const FencedCeilingRules = preload("res://scripts/enemies/fenced_ceiling_rules.gd")
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
		# Task J2: a wall-run gap's holes are crossed on its lit wall, never jumped (check_wall_run_gaps).
		if not LevelLayout.is_wall_run_hole(g):
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
	check_wide_gaps(suite, layout, config, tag)
	check_dash_walls(suite, layout, config, tag)
	check_scenarios(suite, layout, config, tag)
	check_wall_run_gaps(suite, layout, config, tag)


## Wall-run gaps (task J2; the owner, October 15, 2026: "a gap over the ENTIRE floor (every lane), and the only way to
## cross is a wall run"; WallRunGapPlacement), wherever the generator places one, at any lane count, at the level's own
## run speed:
## - only in a level with the `wall_run_gaps` feature, never in a boss arena, and every hole marked as one's
##   (LevelLayout.WALL_RUN_HOLE) belongs to one, a hole in every lane over its gap;
## - no jump crosses it: longer than a full jump with its jump grace and the dash all the way, even with a speed pad's
##   or a ramp's whole boost (and longer than the generator's longest jumpable hole);
## - a standard wall run (no claws, no wall hop) carries a runner across from anywhere on its lit stretch: one from the
##   lit stretch's first metre leaves the wall exit_margin_seconds past the gap's far edge, one from its last metre
##   (with the jump grace) drops them back onto the landing floor before it ends;
## - they keep apart (min_spacing_seconds), and the generator's own re-check finds nothing (WallRunGapPlacement
##   .problem: its shape, its clear run-in and landing floor clear in every lane of holes, fences, doodads, enemies'
##   attacks and every other keep-out, its lit wall clear of signs, wall enemies, wall fences and wall gaps over the
##   longest wall run, the other wall whole beside it).
static func check_wall_run_gaps(suite: TestSuite, layout: LevelLayout, config: LevelConfig, tag: String) -> void:
	var holes: int = 0
	for g: Dictionary in layout.gaps:
		if LevelLayout.is_wall_run_hole(g):
			holes += 1
	if layout.wall_run_gaps.is_empty():
		suite.check(holes == 0, "no wall-run gap's hole without its wall-run gap (%d) %s" % [holes, tag])
		return
	suite.check(config.has_feature(WallRunGapPlacement.FEATURE) and not WallGapPlacement.is_boss_arena(config),
		"wall-run gaps only in a level with the feature, never in a boss arena " + tag)
	suite.check(holes == layout.wall_run_gaps.size() * layout.lane_count,
		"every wall-run gap's hole belongs to one, one in each lane (%d holes, %d gaps) %s" % [holes, layout.wall_run_gaps.size(), tag])
	var tuning: MovementTuning = level_tuning(suite, config)
	var v: float = tuning.run_speed
	var t: WallRunGapTuning = WallRunGapPlacement.tuning()
	var pt: PowerupTuning = WallRunGapPlacement.powerups()
	# The longest a runner flies from the floor: a full jump with its jump grace, at the run speed with a speed pad's
	# or a ramp's whole boost, and the dash's extra all the way.
	var fast: float = v + maxf(tuning.speed_pad_boost, tuning.ramp_speed_boost)
	var reach: float = tuning.jump_distance(fast) + tuning.coyote_time * fast + pt.dash_duration * pt.dash_speed_bonus \
		+ tuning.visual_size.z
	var max_gap: float = tuning.jump_distance(v) * config.max_gap_jump_fraction
	var wall_run: float = (tuning.wall_entry_time + tuning.wall_slide_time) * v
	var drop: float = WallRunGapPlacement.drop_seconds(tuning) * v
	var gen: LevelGenerator = LevelGenerator.for_layout(config, suite.tuning, layout)
	var prev_landing: float = -INF
	for w: Dictionary in layout.wall_run_gaps:
		var start: float = float(w["start"])
		var end: float = float(w["end"])
		var entry: float = float(w["entry"])
		var landing: float = float(w["landing"])
		var where: String = "(wall-run gap %.1f-%.1f, lit wall %s) %s" % [start, end, "left" if int(w["side"]) < 0 else "right", tag]
		suite.check(end - start > reach and end - start > max_gap,
			"no jump crosses it, nor a jump and the dash (%.1f m against %.1f m) %s" % [end - start, reach, where])
		suite.check(entry + wall_run >= end + t.exit_margin_seconds * v - 0.01,
			"a standard wall run from the lit stretch's first metre leaves the wall past its far edge " + where)
		suite.check(start + tuning.coyote_time * v + wall_run + drop <= landing + 0.01,
			"a standard wall run from the lit stretch's last metre drops the runner onto the landing floor " + where)
		suite.check(float(w["approach"]) - prev_landing >= t.min_spacing_seconds * v - 0.01,
			"wall-run gaps keep their spacing " + where)
		prev_landing = landing
		var why: String = WallRunGapPlacement.problem(gen, w)
		suite.check(why == "", "a wall-run gap keeps its rules (%s) %s" % [why, where])


## Dash walls (task H7a; GDD §9.14, owner, October 8, 2026), wherever the generator stands one (dash_wall_rules.gd),
## at any lane count, at the level's own run speed (DashWallTuning's times are seconds at it, or at the dash's
## speed, so they hold at every zone's speed):
## - only in a level with the `dash_wall` feature, never before its start; MovementTuning.dash_wall_depth deep;
##   its footprint between the run-up and the end-clear stretch;
## - faces at least the spacing apart (the dash's longest cooldown, the margin, and the ground a dash adds);
## - its footprint (approach_seconds before its face to after_seconds past its back, at the dash's speed) holds
##   no hole, fence, floor cut's window, doodad, speed pad, pad's zone, ramp or the wall run it launches, and no
##   ceiling from its start to its landing zone's end ("no ceiling overlaps a dash wall");
## - at least one side wall open to run past it (no sign from wall_route_seconds before its face to its back),
##   and neither holds a wall gap or a wall fence there;
## - nothing that invites a dash comes within the spacing before its face (a Buzz Overdrive's charge meeting
##   the runner, a fence generator, the end of a Tithe Collector's stay; a zone doodad never needs the dash, so it
##   keeps off the footprint only);
## - no panic cyborg's run reaches its footprint, nor any cyborg's walk back (CyborgRules.limits, as the Cyborg
##   clamps them: it never runs through a standing wall nor cowers in its clear stretch);
## - and the generator's own re-check finds nothing (DashWallRules.problems: the enemies' keep-outs too).
static func check_dash_walls(suite: TestSuite, layout: LevelLayout, config: LevelConfig, tag: String) -> void:
	if layout.dash_walls.is_empty():
		return
	var tuning: MovementTuning = level_tuning(suite, config)
	var speed: float = tuning.run_speed
	var t: DashWallTuning = DashWallTuning.load_default()
	var pt := load("res://data/tuning/powerups.tres") as PowerupTuning
	var zones := CeilingZones.make(config, tuning)
	var dash: float = speed + pt.dash_speed_bonus
	var approach: float = t.approach_seconds * dash
	var after: float = t.after_seconds * dash
	var longest: float = pt.dash_cooldown
	for c: float in pt.dash_upgrade_cooldowns:
		longest = maxf(longest, c)
	var spacing: float = (longest + t.cooldown_margin_seconds) * speed + pt.dash_duration * pt.dash_speed_bonus
	var route: float = t.wall_route_seconds * speed
	var half: float = tuning.fence_depth * 0.5
	var tithe_tuning := EnemyDirector.tuning_for("tithe_collector") as TitheCollectorTuning
	var tithe_stay: float = tithe_tuning.stay_seconds() if tithe_tuning != null else 12.0
	var cyborg_tuning := EnemyDirector.tuning_for("cyborg") as CyborgTuning
	var cyborg_spans: Array[Vector2] = CyborgRules.obstacle_spans(layout, tuning, zones)
	suite.check(config.has_feature("dash_wall"), "dash walls only in a level with the feature " + tag)
	var start: float = config.feature_start("dash_wall") * layout.length
	var prev: float = -INF
	for w: Dictionary in layout.dash_walls:
		var face: float = float(w["start"])
		var back: float = float(w["end"])
		var at: String = "the dash wall at %.1f m %s" % [face, tag]
		suite.check(face >= start - 0.01, "%s comes after its feature's start (%.0f m)" % [at, start])
		suite.check(absf(back - face - tuning.dash_wall_depth) < 0.01, "%s is %.2f m deep" % [at, tuning.dash_wall_depth])
		suite.check(face - approach >= config.start_clear_distance - 0.01 and back + after <= layout.length - config.end_clear_distance + 0.01,
			"%s keeps its footprint between the run-up and the end-clear stretch" % at)
		suite.check(face - prev >= spacing - 0.01, "%s is %.0f m after the one before (at least %.0f m)" % [at, face - prev, spacing])
		prev = face
		var fp := Vector2(face - approach, back + after)
		for g: Dictionary in layout.gaps:
			suite.check(not (float(g["start"]) <= fp.y and float(g["end"]) >= fp.x), "%s has no hole around it (%.1f m)" % [at, float(g["start"])])
		for f: Dictionary in layout.fences:
			suite.check(not (float(f["at"]) - half <= fp.y and float(f["at"]) + half >= fp.x), "%s has no fence around it (%.1f m)" % [at, float(f["at"])])
		for c: Dictionary in layout.cuts:
			var win: Vector2 = FloorCutPlan.window(c, speed)
			suite.check(not (win.x <= fp.y and win.y >= fp.x), "%s isn't in a floor cut's window (%.0f-%.0f m)" % [at, win.x, win.y])
		for d: Dictionary in layout.doodads:
			suite.check(not (float(d["start"]) <= fp.y and float(d["end"]) >= fp.x), "%s has no doodad around it" % at)
		for sp: Dictionary in layout.speed_pads:
			suite.check(not (float(sp["at"]) <= fp.y and float(sp["at"]) + tuning.speed_pad_length >= fp.x), "%s has no speed pad around it" % at)
		for pad: Dictionary in layout.pads:
			var zone: Vector2 = zones.pad_zone(float(pad["at"]))
			suite.check(not (zone.x <= fp.y and zone.y >= fp.x), "%s has no anti-grav pad around it" % at)
		for r: Dictionary in layout.ramps:
			var run_end: float = maxf(RampLaunch.of(r, tuning, speed).end(), float(r["at"]) + tuning.ramp_length)
			suite.check(not (float(r["at"]) <= fp.y and run_end >= fp.x), "%s has no ramp or ramp wall run around it" % at)
		for h: Dictionary in layout.hulls:
			var landing: Vector2 = zones.landing_zone(h)
			suite.check(not (float(h["start"]) <= fp.y and landing.y >= fp.x),
				"%s has no ceiling or landing zone around it (%.0f-%.0f m)" % [at, float(h["start"]), landing.y])
		var win := Vector2(face - route, back)
		var open: int = 0
		for side: int in [-1, 1]:
			var clear: bool = true
			for sg: Dictionary in layout.signs:
				if int(sg["side"]) == side and float(sg["start"]) <= win.y and float(sg["end"]) >= win.x:
					clear = false
			open += 1 if clear else 0
			for wg: Dictionary in layout.wall_gaps:
				suite.check(not (int(wg["side"]) == side and float(wg["start"]) <= win.y and float(wg["end"]) >= win.x),
					"%s has no side wall gap beside it" % at)
			for wf: Dictionary in layout.wall_fences:
				suite.check(not (int(wf["side"]) == side and float(wf["at"]) + half >= win.x and float(wf["at"]) - half <= win.y),
					"%s has no wall fence beside it" % at)
		suite.check(open > 0, "%s leaves a side wall open to run past it (GDD §9.14)" % at)
		for e: Dictionary in layout.enemies:
			var bait: float = NAN
			match String(e.get("type", "")):
				"buzz_overdrive":
					var cut: Dictionary = BuzzOverdriveRulesScript.cut_of(layout, e)
					if not cut.is_empty():
						bait = FloorCutPlan.meet(cut, speed)
				"generator":
					bait = float(e["at"])
				"tithe_collector":
					bait = float(e["at"]) + tithe_stay * speed
			if not is_nan(bait):
				suite.check(not (bait >= face - spacing and bait <= face),
					"%s has no %s inviting the dash in the spacing before it (%.0f m)" % [at, e["type"], bait])
		for c: Dictionary in layout.enemies:
			if String(c.get("type", "")) != "cyborg":
				continue
			var home: float = float(c["at"])
			var reach: Vector2 = CyborgRules.limits(cyborg_spans, cyborg_tuning, tuning.pace(), home, layout.length)
			if home < face:
				suite.check(reach.y < fp.x, "%s: the cyborg at %.1f m runs no further than %.1f m, short of its clear approach (%.1f m)" % [
					at, home, reach.y, fp.x])
			else:
				suite.check(reach.x > fp.y, "%s: the cyborg at %.1f m walks back no further than %.1f m, past its clear stretch (%.1f m)" % [
					at, home, reach.x, fp.y])
	var gen := LevelGenerator.for_layout(config, suite.tuning, layout)
	var problems: PackedStringArray = DashWallRulesScript.problems(gen)
	suite.check(problems.is_empty(), "the dash walls keep every placement rule %s %s" % [tag, problems])


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
##   no hole, fence, floor cut, anti-grav pad or floor enemy, and no hover truck keeps that lane;
## - nothing running meanwhile: no floor cut's window, drone wave (to its first pad), hover truck's
##   stay, Octodog run, Resonator pulse (from its warning until its wave has passed the player), Bad
##   Dream chase or Gilded Sentinel's attack (from its eyes' flare to its last swing) reaches its drop
##   window; and never on a Gilded Sentinel's wall section (task C4);
## - spaced from the other wall fences: same_side_gap_seconds on its wall, gap_seconds on either;
## - no zone doodad by its wall (task L3: a row's whole stretch) where its drop window lands.
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
	var rt := EnemyDirector.tuning_for("resonator") as ResonatorTuning
	var st := EnemyDirector.tuning_for("gilded_sentinel") as GildedSentinelTuning
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
				"gilded_sentinel":
					# Task C4: off a Gilded Sentinel's wall section (its wall-run approach to past what it cuts).
					var e_swings: int = int((e.get("params", {}) as Dictionary).get("swings", 1))
					var guard: Vector2 = st.guarded_stretch(e_at, e_swings)
					suite.check(at < guard.x - st.approach_seconds * speed - half + 0.01 or at > guard.y + st.wall_clear_seconds * speed + half - 0.01,
						"no wall fence on a Gilded Sentinel's wall section (Sentinel at %.1f) %s" % [e_at, x])
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
		# Task L3: nor a zone doodad by that wall (a row's whole stretch).
		for dd: Dictionary in layout.doodads:
			var dspan: Vector2 = LevelLayout.doodad_extent(dd)
			suite.check(int(dd["lane"]) != lane or not meets.call(dspan.x, dspan.y),
				"no zone doodad where a wall runner drops off a wall fence's wall (%.1f) %s" % [dspan.x, x])
		for f: Dictionary in layout.fences:
			suite.check(int(f["lane"]) != lane or not meets.call(float(f["at"]) - half, float(f["at"]) + half),
				"no fence where a wall runner drops off (%.1f) %s" % [f["at"], x])
		for p: Dictionary in layout.pads:
			suite.check(int(p["lane"]) != lane or not meets.call(float(p["at"]), float(p["at"]) + tuning.pad_length),
				"no anti-grav pad where a wall runner drops off (%.1f) %s" % [p["at"], x])
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
				"gilded_sentinel":
					# Its whole attack, from its eyes' flare to the end of its last swing (task C4).
					busy.append(st.attack_window(e_at, int((e.get("params", {}) as Dictionary).get("swings", 1)), speed))
				"resonator":
					# Each pulse, from its warning to where its wave has passed the player (the wall is an
					# escape from it); a Resonator without a plan, its whole visit.
					var params: Dictionary = e.get("params", {})
					var anchors: Array = params.get("pulse_at", [])
					var doubles: Array = params.get("double", [])
					if anchors.is_empty():
						busy.append(resonator.call("keep_out", gen, e))
					for i: int in anchors.size():
						var meeting: Vector2 = rt.meeting_stretch(float(anchors[i]), i < doubles.size() and bool(doubles[i]), speed,
							config.enemy_scaling, pace)
						busy.append(Vector2(float(anchors[i]), meeting.y))
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
## - one at a time: no two windows (from the warning, or where a cause on its way before it sets off,
##   to the cut's end) overlap;
## - nothing else in its lane from the warning (or where its cause sets off) to past its cause's spot:
##   no hole, fence, pad's zone, speed pad, ramp (or the wall run one launches until it drops the
##   player back), zone doodad or floor credit; no landing zone of a ceiling over its lane reaches its
##   warned lane (from the warning on);
## - the other lanes whole along its stretch: on 3 lanes no hole in either (GDD §9.9), on more holes in
##   at most LevelConfig.cut_holes_beside of them (and two always whole);
## - nothing else going on meanwhile: no floor enemy's stretch (its own cause aside), Bad Dream chase,
##   drone wave before its first pad or hover truck's shortest stay reaches its attack window (from the
##   warning on), nor a truck's whole stay in its lane;
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
		var attack: Vector2 = FloorCutPlan.attack_window(c, speed)
		var warned: Vector2 = FloorCutPlan.warned_lane(c)
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
			suite.check(not layout.hull_covers(h, lane) or landing.x > warned.y or landing.y < warned.x,
				"no ceiling's landing zone over a cut's lane from its warning on (ceiling ending %.1f) %s" % [h["end"], t])
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
			if bool(c.get("park", false)) and int(e.get("lane", -1)) == lane and at > FloorCutPlan.charge_at(c) and at < end \
					and String((e.get("params", {}) as Dictionary).get(ChargePathPlacement.PARAM, "")) == ChargePathPlacement.TANK:
				continue  # Task G7: the cyborg planted in its path (check_charge_paths), the one exception.
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
				suite.check(b.y < b.x or b.x > attack.y or b.y < attack.x,
					"nothing else goes on during a cut (%s at %.0f: %.1f-%.1f) %s" % [e["type"], at, b.x, b.y, t])
		# A player in its lane when it warns can leave it.
		var from: float = FloorCutPlan.warn_at(c) + config.cut_reaction_seconds * speed
		var route: Dictionary = grid.find(from, span.y + 2.0, lane)
		suite.check(bool(route["ok"]), "a player in a cut's lane %.2f s into its warning can leave it (%s) %s" % [
			config.cut_reaction_seconds, route["reason"], t])


## Zone doodads (GDD §3, owner's playtest September 30, 2026): scenery standing in lanes that never
## hurts; running into one pushes the player into a neighbouring lane. Wherever one stands
## (LevelGenerator._place_doodads), at any lane count:
## - in an inner lane, or in an outermost one by an open side wall (task L3: check_wall_lane_doodad), its size
##   class's length, pushing to a side (inward from an outermost lane), after the run-up and before the
##   end-clear stretch;
## - with nothing else in any lane from its push's lead before its front to the level's hard spacing
##   after its end: no hole, fence, ramp or the wall run it launches, pad (from its run-up to its
##   lift's end), speed pad, sign, floor enemy's stretch, ceiling or landing zone. So the push lands
##   on clear floor whichever lane it goes to, the player moves on clear floor after it, it leaves
##   every lane but its own to run in, and the player can cross its lane again before what comes
##   next, as between two patterns;
## - off every lane-bound attack while it can run: every Octodog's run (its floor stretch), every Bad
##   Dream chase and drone wave until its first pad, any lane while a hover truck is surely there, and
##   never in or pushing into a truck's lane until it has left;
## - one at a time: LevelConfig.doodad_gap_seconds from one's end (a row's last one's) to the next one's front;
## - a row (task L3: doodads sharing a `row`): from two to doodad_row_max of them, never a slalom or a wall of
##   doodads: one lane, one size class, one side and one look (`look`, its first one's seed), each one's front
##   either DOODAD_ROW_TOUCH or a doodad's length past the one before's end, the same all along the row, and its
##   `row` from its first one's front to its last one's end; every rule above holds for each of them.
## A treasure stash's doodads (task I4) aren't zone doodads standing on their own: check_scenarios checks them.
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
	# A treasure stash's doodads (marked "stash", task I4) stand under its ceiling, side by side: check_scenarios checks
	# them.
	var sorted: Array[Dictionary] = []
	for d: Dictionary in layout.doodads:
		if not d.has("stash"):
			sorted.append(d)
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["start"]) < float(b["start"]))
	var prev_end: float = -INF
	# The rows (task L3), each its doodads in order, keyed by its stretch.
	var rows: Dictionary = {}
	var gen: LevelGenerator = LevelGenerator.for_layout(config, suite.tuning, layout)
	for d: Dictionary in sorted:
		var start: float = float(d["start"])
		var end: float = float(d["end"])
		var lane: int = int(d["lane"])
		var side: int = int(d["side"])
		var size := StringName(d["size"])
		var t: String = "(doodad at %.1f, lane %d) %s" % [start, lane, tag]
		var outer: bool = lane == 0 or lane == n - 1
		suite.check(lane >= 0 and lane < n and (not outer or side == (1 if lane == 0 else -1)),
			"a doodad stands in a lane of the track, pushing inward from an outermost one " + t)
		suite.check(side == -1 or side == 1, "a doodad pushes to one side " + t)
		suite.check(LevelLayout.DOODAD_SIZES.has(size) and absf(end - start - tuning.doodad_size(size).z) < 0.01,
			"a doodad is as long as its size class " + t)
		suite.check(start >= config.start_clear_distance - 0.01 and end <= layout.length - config.end_clear_distance + 0.01,
			"a doodad stands between the run-up and the end-clear stretch " + t)
		# One at a time: a row (task L3) counts as one, from its first one's front to its last one's end.
		var key: String = var_to_str(d["row"]) if d.has("row") else ""
		var first_of_row: bool = key == "" or not rows.has(key)
		if first_of_row:
			suite.check(start - prev_end >= config.doodad_gap_seconds * speed - 0.01,
				"doodads (a row as one) come one at a time (%.2f s apart) %s" % [(start - prev_end) / speed, t])
		if key != "":
			if not rows.has(key):
				rows[key] = []
			(rows[key] as Array).append(d)
		prev_end = end
		if outer:
			check_wall_lane_doodad(suite, layout, config, gen, d, t)
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
	for key: String in rows:
		check_row(suite, rows[key], config, tuning, tag)


## A row of zone doodads (task L3, the owner, October 17, 2026: "rows of similar doodads"; LevelLayout.doodads
## `row`), its doodads `row` in order: from two to doodad_row_max of them, never a slalom or a wall of doodads (one
## lane, one size class, one side) and of one kind (one look, its first one's seed), each one's front either
## LevelGenerator.DOODAD_ROW_TOUCH or a doodad's length past the end of the one before, the same all along, and
## its stretch from its first one's front to its last one's end.
static func check_row(suite: TestSuite, row: Array, config: LevelConfig, tuning: MovementTuning, tag: String) -> void:
	var first: Dictionary = row[0]
	var last: Dictionary = row[-1]
	var stretch: Array = first["row"]
	var t: String = "(row of %d at %.1f, lane %d) %s" % [row.size(), float(first["start"]), int(first["lane"]), tag]
	suite.check(row.size() >= 2 and row.size() <= maxi(config.doodad_row_min, config.doodad_row_max),
		"a row holds two doodads to doodad_row_max " + t)
	suite.check(absf(float(stretch[0]) - float(first["start"])) < 0.01 and absf(float(stretch[1]) - float(last["end"])) < 0.01,
		"a row's stretch runs from its first one's front to its last one's end " + t)
	suite.check(int(first.get("look", -1)) == int(first["seed"]), "a row's look is its first one's seed " + t)
	var length: float = tuning.doodad_size(StringName(first["size"])).z
	var step: float = NAN
	for i: int in range(1, row.size()):
		var d: Dictionary = row[i]
		suite.check(int(d["lane"]) == int(first["lane"]) and StringName(d["size"]) == StringName(first["size"])
			and int(d["side"]) == int(first["side"]) and int(d.get("look", -2)) == int(first.get("look", -1)),
			"a row's doodads share one lane, size class, side and look (no slalom, one kind) " + t)
		var space: float = float(d["start"]) - float((row[i - 1] as Dictionary)["end"])
		suite.check(absf(space - LevelGenerator.DOODAD_ROW_TOUCH) < 0.01 or absf(space - length) < 0.01,
			"a row's doodads stand one right after the other or a doodad's length apart (%.2f m) %s" % [space, t])
		if not is_nan(step):
			suite.check(absf(space - step) < 0.01, "a row keeps one spacing all along (%.2f m, then %.2f m) %s" % [step, space, t])
		step = space


## A zone doodad `d` standing in an outermost lane (task L3, the owner, October 9, 2026: "doodads prefer the lane
## next to the side wall when it's open, without costing gameplay"; LevelGenerator.wall_lane_keep_outs), checked
## over its own stretch (a row's whole stretch, LevelLayout.doodad_extent) on the wall beside it: nothing stands on
## that wall within LevelConfig.doodad_wall_clear_seconds (no sign, no wall enemy, nor where the fill pass keeps for
## one or a window cyborg's window or a Gilded Sentinel's wall section; no ramp from its foot to the end of the
## longest wall run it launches; no wall-run gap's lit wall), no dash wall's wall route on either wall reaches it, no
## wall fence's drop window reaches it, no side wall gap stands beside it or starts within LevelGenerator.doodad_wall_drop
## before it (a wall runner dropping off never comes down on it), and no wall credit lies within
## LevelGenerator.DOODAD_WALL_CREDIT_MARGIN of it on that wall. Every lane around it is clear already (check_doodads).
static func check_wall_lane_doodad(suite: TestSuite, layout: LevelLayout, config: LevelConfig, gen: LevelGenerator,
		d: Dictionary, t: String) -> void:
	var wall: int = -1 if int(d["lane"]) == 0 else 1
	var span: Vector2 = LevelLayout.doodad_extent(d)
	var speed: float = gen.speed
	var clear: float = config.doodad_wall_clear_seconds * speed - 0.01
	var x: String = "(by wall %+d) %s" % [wall, t]
	var near := func(from: float, to: float, margin: float) -> bool:
		return from - margin <= span.y and to + margin >= span.x
	for s: Dictionary in layout.signs:
		if int(s["side"]) == wall:
			suite.check(not near.call(float(s["start"]), float(s["end"]), clear),
				"no sign on the wall beside a doodad by it (sign %.1f-%.1f) %s" % [s["start"], s["end"], x])
	var wt := EnemyDirector.tuning_for("window_cyborg") as WindowCyborgTuning
	for e: Dictionary in layout.enemies:
		if int(e.get("side", 0)) != wall:
			continue
		var at: float = float(e["at"])
		var k: Vector2 = gen.enemy_keep_out(e)
		var window: float = wt.window_length * 0.5
		suite.check(not near.call(minf(k.x, at - window), maxf(k.y, at + window), clear),
			"no wall enemy on the wall beside a doodad by it (%s at %.0f) %s" % [e["type"], at, x])
		if String(e["type"]) == "gilded_sentinel":
			var section: Vector2 = WallFencePlacement.sentinel_wall_section(gen, e)
			suite.check(not near.call(section.x, section.y, clear), "nor a Gilded Sentinel's wall section (at %.0f) %s" % [at, x])
	for r: Dictionary in layout.ramps:
		if int(r["side"]) == wall:
			suite.check(not near.call(float(r["at"]), WallFencePlacement.ramp_run_end(gen, r), clear),
				"no ramp launches a wall run past a doodad by its wall (ramp at %.1f) %s" % [r["at"], x])
	for k: Vector2 in WallRunGapPlacement.wall_keep_outs_for(layout, speed, wall, false):
		suite.check(not near.call(k.x, k.y, clear), "no wall-run gap's lit wall beside a doodad by it " + x)
	for k: Vector2 in DashWallRulesScript.wall_keep_outs(gen):
		suite.check(not near.call(k.x, k.y, 0.0), "no dash wall's wall route beside a doodad by a wall " + x)
	for w: Dictionary in layout.wall_fences:
		if int(w["side"]) == wall:
			var drop: Vector2 = WallFencePlacement.drop_window(gen, float(w["at"]))
			suite.check(not near.call(drop.x, drop.y, 0.0),
				"no wall fence's drop-off lands by a doodad by its wall (fence at %.1f) %s" % [w["at"], x])
	var reach: float = gen.doodad_wall_drop()
	for g: Dictionary in layout.wall_gaps:
		if int(g["side"]) == wall:
			suite.check(not near.call(float(g["start"]), maxf(float(g["end"]), float(g["start"]) + reach), 0.0),
				"no side wall gap beside a doodad by its wall, nor one dropping a wall runner onto it (gap %.1f-%.1f) %s"
				% [g["start"], g["end"], x])
	for c: Dictionary in layout.credits:
		if String(c["surface"]) == "wall" and int(c["side"]) == wall:
			suite.check(not near.call(float(c["at"]), float(c["at"]), LevelGenerator.DOODAD_WALL_CREDIT_MARGIN - 0.01),
				"no wall credit lures a wall run past a doodad by its wall (credit at %.1f) %s" % [c["at"], x])


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


## The ceiling scenarios (task I4; GDD §3, "Ceiling scenarios"; CeilingScenarios), wherever the generator makes one,
## at any lane count, at the level's own run speed (CeilingScenarioTuning's times are seconds at it):
## - each only in a level with its feature (a treasure stash's pieces `treasure_stash`, a fenced ceiling's
##   `fenced_ceiling`), on a ceiling of its own whose pads come after the feature's start, no Barnacle Turret hanging
##   from it, at most the level's count of each, min_gap_seconds from the scenario before;
## - a treasure stash (check_stash): in an inner lane with inner lanes either side; its return pad on its ceiling's
##   underside over its lane, see_seconds after the ceiling's rider arrives at the latest; the ceiling running on past
##   it; one doodad across its lane at its start, its walls back to back alongside in both neighbouring lanes, pushing
##   outward, from beside that one (room for its push, then overlapping it) to its open end; two or three credits of
##   the highest denomination inside, past where the return pad's rider lands, and no other floor credit in it or
##   beside it; its floor, from the front doodad's push to the spacing past its open end, holding nothing else in any
##   lane (no hole, fence, floor cut's window, floor enemy, pad's zone, speed pad, ramp's run, other doodad, dash wall
##   or other ceiling);
## - a fenced ceiling (check_fenced): two lanes wide or more; every pad under it marked, the unsafe ones (half the
##   level's fenced_ceiling_pads, rounded up, or more) before its rows of fences and the safe ones (the rest, at least
##   one) past them, in lanes of their own; rows across every lane it covers, within it, from past where the last
##   unsafe pad's rider (at the fastest, rider_boost) comes within a fence's reach of the underside, no further apart
##   than row_plan's spacing and over at least a jump at that speed; a safe pad's rider clear of the last row as they
##   rise, and the ceiling running on safe_ride_seconds past their arrival; no ceiling credit by a fence, and no wall
##   jump reaching a row (CeilingScenarios.wall_jump_near);
## - and no ceiling fence, return pad or added pad anywhere else.
## Their physics (where a rider meets a fence, lands in the stash) is replayed by test_ceiling_scenarios.gd.
static func check_scenarios(suite: TestSuite, layout: LevelLayout, config: LevelConfig, tag: String) -> void:
	var taken: Array[Dictionary] = []
	for h: Dictionary in layout.hulls:
		if h.has(CeilingScenarios.KEY):
			taken.append(h)
	var added: bool = false
	for p: Dictionary in layout.pads:
		added = added or p.has("added") or p.has("fenced")
	if taken.is_empty() and not added and layout.stashes.is_empty() and layout.return_pads.is_empty() \
			and layout.ceiling_fences.is_empty():
		return
	var gen := LevelGenerator.for_layout(config, suite.tuning, layout)
	var t: CeilingScenarioTuning = CeilingScenarios.tuning()
	taken.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["start"]) < float(b["start"]))
	var counts: Dictionary = {CeilingScenarios.STASH: 0, CeilingScenarios.FENCED: 0}
	var prev_end: float = -INF
	for h: Dictionary in taken:
		var kind: String = CeilingScenarios.scenario_of(h)
		var at: String = "the %s ceiling at %.1f m %s" % [kind, float(h["start"]), tag]
		suite.check(counts.has(kind), "%s is a known scenario" % at)
		suite.check(config.has_feature(kind), "%s: only in a level with its feature" % at)
		suite.check(not CeilingScenarios.turret_on(layout, h), "%s: no Barnacle Turret hangs from it" % at)
		var pads: Array[Dictionary] = CeilingScenarios.pads_under(layout, h)
		suite.check(not pads.is_empty() and float(pads[0]["at"]) >= config.feature_start(kind) * layout.length - 0.01,
			"%s: its pads come after its feature's start" % at)
		var span := Vector2(float(h["start"]), gen.zones.landing_zone(h).y)
		suite.check(span.x - prev_end >= t.min_gap_seconds * gen.speed - 0.01,
			"%s: %.1f s after the scenario before it (at least %.0f s)" % [at, (span.x - prev_end) / gen.speed, t.min_gap_seconds])
		prev_end = span.y
		counts[kind] = int(counts.get(kind, 0)) + 1
		if kind == CeilingScenarios.FENCED:
			check_fenced(suite, gen, t, h, tag)
	suite.check(int(counts[CeilingScenarios.STASH]) <= config.treasure_stashes and layout.stashes.size() == int(counts[CeilingScenarios.STASH]),
		"a treasure stash for every stash's ceiling, at most the level's %d %s" % [config.treasure_stashes, tag])
	suite.check(int(counts[CeilingScenarios.FENCED]) <= config.fenced_ceilings,
		"at most the level's %d fenced ceilings %s" % [config.fenced_ceilings, tag])
	for s: Dictionary in layout.stashes:
		check_stash(suite, gen, t, s, tag)
	# Nothing of theirs anywhere else.
	var half: float = gen.tuning.fence_depth * 0.5
	for f: Dictionary in layout.ceiling_fences:
		var h: Dictionary = layout.hull_at(float(f["at"]), int(f["lane"]))
		suite.check(CeilingScenarios.scenario_of(h) == CeilingScenarios.FENCED and float(f["at"]) - half >= float(h["start"])
			and float(f["at"]) + half <= float(h["end"]),
			"a ceiling fence (at %.1f m, lane %d) hangs within a fenced ceiling over its lane %s" % [f["at"], f["lane"], tag])
	for r: Dictionary in layout.return_pads:
		var mine: bool = false
		for s: Dictionary in layout.stashes:
			mine = mine or (int(s["lane"]) == int(r["lane"]) and absf(float(s["pad"]) - float(r["at"])) < 0.01)
		suite.check(mine, "a return pad (at %.1f m) is a treasure stash's %s" % [r["at"], tag])
	for p: Dictionary in layout.pads:
		if p.has("added") or p.has("fenced"):
			var h: Dictionary = layout.hull_at(float(p["at"]), int(p["lane"]))
			suite.check(CeilingScenarios.scenario_of(h) == CeilingScenarios.FENCED,
				"a pad marked by a fenced ceiling (at %.1f m) lies under one %s" % [p["at"], tag])


## A treasure stash `s` (LevelLayout.stashes) in `gen`'s level keeps its rules (check_scenarios).
static func check_stash(suite: TestSuite, gen: LevelGenerator, t: CeilingScenarioTuning, s: Dictionary, tag: String) -> void:
	var layout: LevelLayout = gen.layout
	var mt: MovementTuning = gen.tuning
	var v: float = gen.speed
	var n: int = layout.lane_count
	var lane: int = int(s["lane"])
	var start: float = float(s["start"])
	var end: float = float(s["end"])
	var pad: float = float(s["pad"])
	var at: String = "the treasure stash at %.1f m (lane %d) %s" % [start, lane, tag]
	suite.check(gen.config.has_feature(CeilingScenarios.STASH), "%s: only in a level with the feature" % at)
	suite.check(lane >= 2 and lane <= n - 3, "%s is in an inner lane with inner lanes either side" % at)
	# Its ceiling and its return pad.
	var h: Dictionary = {}
	for x: Dictionary in layout.hulls:
		if absf(float(x["start"]) - float(s["hull_start"])) < 0.01:
			h = x
	suite.check(CeilingScenarios.scenario_of(h) == CeilingScenarios.STASH, "%s has its ceiling" % at)
	if h.is_empty():
		return
	var returns: int = 0
	for r: Dictionary in layout.return_pads:
		returns += 1 if int(r["lane"]) == lane and absf(float(r["at"]) - pad) < 0.01 else 0
	suite.check(returns == 1, "%s has its return pad over its lane" % at)
	suite.check(layout.hull_covers(h, lane) and pad >= float(h["start"]) and pad + mt.pad_length <= float(h["end"]),
		"%s: its return pad hangs under its ceiling" % at)
	var pads: Array[Dictionary] = CeilingScenarios.pads_under(layout, h)
	if not pads.is_empty():
		var arrive: float = CeilingScenarios.flip_late(float(pads[-1]["at"]), v) + v * CeilingScenarios.rise_seconds(mt, 0.0)
		suite.check(pad >= arrive + t.see_seconds * v - 0.01,
			"%s: its return pad comes %.2f s after the ceiling's rider arrives (at least %.1f s)" % [at, (pad - arrive) / v, t.see_seconds])
	suite.check(float(h["end"]) >= end + t.ceiling_after_seconds * v - 0.01, "%s: its ceiling runs on past its open end" % at)
	# Its doodads.
	var front: Array[Dictionary] = []
	var left: Array[Dictionary] = []
	var right: Array[Dictionary] = []
	for d: Dictionary in layout.doodads:
		if not d.has("stash") or float(d["end"]) < start - 0.01 or float(d["start"]) > end + 0.01:
			continue
		if int(d["lane"]) == lane:
			front.append(d)
		elif int(d["lane"]) == lane - 1:
			left.append(d)
		elif int(d["lane"]) == lane + 1:
			right.append(d)
	suite.check(front.size() == 1, "%s: one doodad across its lane at its start (%d)" % [at, front.size()])
	if front.size() != 1:
		return
	var front_end: float = float(front[0]["end"])
	suite.check(absf(float(front[0]["start"]) - start) < 0.01, "%s: the doodad across its lane stands at its start" % at)
	suite.check(absf(front_end - start - mt.doodad_size(StringName(front[0]["size"])).z) < 0.01,
		"%s: the doodad across it is as long as its size class" % at)
	# The walls start past room for that doodad's push, and overlap it by wall_overlap (or all it leaves).
	var overlap: float = minf(t.wall_overlap, front_end - start - TreasureStashRules.PUSH_ROOM)
	for side: int in [-1, 1]:
		var chain: Array[Dictionary] = left if side < 0 else right
		var w: String = "%s: its wall in lane %d" % [at, lane + side]
		suite.check(not chain.is_empty(), "%s stands" % w)
		if chain.is_empty():
			continue
		chain.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["start"]) < float(b["start"]))
		var first: float = float(chain[0]["start"])
		suite.check(absf(first - float(s["walls_from"])) < 0.01, "%s starts where the record says" % w)
		suite.check(first >= start + TreasureStashRules.PUSH_ROOM - 0.01 and first <= front_end - overlap + 0.01,
			"%s starts beside the doodad across it (%.2f m past its front, %.2f m before its end)" % [w, first - start, front_end - first])
		var cursor: float = first
		for d: Dictionary in chain:
			suite.check(absf(float(d["start"]) - cursor) < 0.01, "%s runs back to back (%.2f m)" % [w, float(d["start"])])
			suite.check(int(d["side"]) == side, "%s pushes outward" % w)
			suite.check(absf(float(d["end"]) - float(d["start"]) - mt.doodad_size(StringName(d["size"])).z) < 0.01,
				"%s: each doodad is as long as its size class" % w)
			cursor = float(d["end"])
		suite.check(absf(cursor - end) < 0.01, "%s reaches its open end" % w)
	# Its credits.
	var land: float = pad + CeilingScenarios.flip_late(0.0, v) \
		+ v * (CeilingScenarios.drop_seconds(mt, 0.0) + CeilingScenarios.frame_seconds())
	var mine: int = 0
	for c: Dictionary in layout.credits:
		var d: float = float(c["at"])
		if String(c["surface"]) != "floor" or absi(int(c["lane"]) - lane) > 1 or d < start - 1.0 or d > end + 1.0:
			continue
		if not c.has("stash"):
			suite.check(false, "%s holds only its own credits (a credit at %.1f m, lane %d)" % [at, d, c["lane"]])
			continue
		mine += 1
		suite.check(int(c["lane"]) == lane and int(c["value"]) == LevelGenerator.DENOMINATIONS.max(),
			"%s: its credits are the highest denomination, in its lane" % at)
		suite.check(d >= land - 0.01 and d <= end - t.credit_end_margin + 0.01,
			"%s: a credit (%.1f m) lies past where the return pad's rider lands (%.1f m) and inside its open end" % [at, d, land])
		# Task I4's review: past the top magnet's reach from wherever a floor runner close enough to pull from is (short
		# of the walls' start).
		var pull: float = float(s["walls_from"]) + TreasureStashRules.magnet_reach()
		suite.check(TreasureStashRules.magnet_reach() > 0.0 and d > pull,
			"%s: a credit (%.1f m) lies past the top magnet's reach from the floor (%.1f m)" % [at, d, pull])
	suite.check(mine >= mini(t.credits_min, t.credits_max) and mine <= maxi(t.credits_min, t.credits_max),
		"%s holds %d credits (%d to %d)" % [at, mine, t.credits_min, t.credits_max])
	# Its floor.
	var area := Vector2(float(s["keep_from"]), float(s["keep_to"]))
	suite.check(area.x <= start - LevelGenerator.doodad_lead_for(mt) + 0.01 and area.y >= end + gen.doodad_after(end) - 0.01,
		"%s keeps its floor from the push before it to the spacing past it" % at)
	var half: float = mt.fence_depth * 0.5
	var busy: Array[Array] = []
	for g: Dictionary in layout.gaps:
		busy.append(["a hole", Vector2(g["start"], g["end"])])
	for f: Dictionary in layout.fences:
		busy.append(["a fence", Vector2(float(f["at"]) - half, float(f["at"]) + half)])
	for c: Dictionary in layout.cuts:
		busy.append(["a floor cut's window", FloorCutPlan.window(c, v)])
	for e: Dictionary in layout.enemies:
		var span: Vector2 = LevelGenerator.enemy_floor_span(e, gen.pace)
		if span.y >= span.x:
			busy.append(["a floor enemy (%s at %.0f)" % [e["type"], e["at"]], span])
	for p: Dictionary in layout.pads:
		busy.append(["a pad's zone", gen.zones.pad_zone(float(p["at"]))])
	for p: Dictionary in layout.speed_pads:
		busy.append(["a speed pad", Vector2(p["at"], float(p["at"]) + mt.speed_pad_length)])
	for r: Dictionary in layout.ramps:
		busy.append(["a ramp and its wall run", Vector2(r["at"], maxf(gen.ramp_launch(r).end(), float(r["at"]) + mt.ramp_length))])
	for d: Dictionary in layout.doodads:
		if not d.has("stash"):
			busy.append(["a zone doodad", Vector2(d["start"], d["end"])])
	for w: Dictionary in layout.dash_walls:
		busy.append(["a dash wall", DashWallRulesScript.footprint(gen, w)])
	for x: Dictionary in layout.hulls:
		if not is_same(x, h):
			busy.append(["another ceiling", Vector2(float(x["start"]), gen.zones.landing_zone(x).y)])
	for b: Array in busy:
		var span: Vector2 = b[1]
		suite.check(span.x > area.y or span.y < area.x, "%s: nothing else on its floor (%s at %.1f-%.1f m)" % [at, b[0], span.x, span.y])


## A fenced ceiling `h` in `gen`'s level keeps its rules (check_scenarios).
static func check_fenced(suite: TestSuite, gen: LevelGenerator, t: CeilingScenarioTuning, h: Dictionary, tag: String) -> void:
	var layout: LevelLayout = gen.layout
	var mt: MovementTuning = gen.tuning
	var v: float = gen.speed
	var v_max: float = v + t.rider_boost
	var half: float = mt.fence_depth * 0.5
	var lanes: Vector2i = layout.hull_lanes(h)
	var at: String = "the fenced ceiling at %.1f m %s" % [float(h["start"]), tag]
	suite.check(layout.hull_width(h) >= 2, "%s is two lanes wide or more" % at)
	var unsafe: Array[Dictionary] = []
	var safe: Array[Dictionary] = []
	var pads: Array[Dictionary] = CeilingScenarios.pads_under(layout, h)
	for p: Dictionary in pads:
		match String(p.get("fenced", "")):
			"unsafe":
				unsafe.append(p)
			"safe":
				safe.append(p)
	suite.check(unsafe.size() + safe.size() == pads.size(), "%s: every pad under it is marked unsafe or safe" % at)
	var total: int = FencedCeilingRules.pad_count(gen.config.fenced_ceiling_pads, layout.lane_count)
	suite.check(unsafe.size() >= FencedCeilingRules.unsafe_count(total), "%s has %d unsafe pads (at least %d)"
		% [at, unsafe.size(), FencedCeilingRules.unsafe_count(total)])
	suite.check(safe.size() == maxi(total - FencedCeilingRules.unsafe_count(total), 1), "%s has %d safe pads" % [at, safe.size()])
	if unsafe.is_empty() or safe.is_empty():
		return
	var rows: Array[float] = []
	for f: Dictionary in layout.ceiling_fences:
		var d: float = float(f["at"])
		if d >= float(h["start"]) and d <= float(h["end"]) and not rows.has(d):
			rows.append(d)
	rows.sort()
	var plan: Dictionary = CeilingScenarios.row_plan(mt, v, v_max, t.row_margin)
	suite.check(rows.size() >= 2, "%s hangs rows of fences (%d)" % [at, rows.size()])
	if rows.size() < 2:
		return
	var want: Array[int] = []
	for lane: int in range(lanes.x, lanes.y + 1):
		want.append(lane)
	for r: float in rows:
		var covered: Array[int] = []
		for f: Dictionary in layout.ceiling_fences:
			if float(f["at"]) == r:
				covered.append(int(f["lane"]))
		covered.sort()
		suite.check(covered == want, "%s: the row at %.1f m crosses every lane it covers (%s)" % [at, r, covered])
		suite.check(r - half >= float(h["start"]) and r + half <= float(h["end"]), "%s: the row at %.1f m hangs within it" % [at, r])
	for i: int in rows.size() - 1:
		suite.check(rows[i + 1] - rows[i] <= float(plan["spacing"]) + 0.01,
			"%s: its rows are at most %.2f m apart (%.2f m)" % [at, float(plan["spacing"]), rows[i + 1] - rows[i]])
	suite.check(rows[-1] - rows[0] >= CeilingScenarios.jump_seconds(mt) * v_max - 0.01,
		"%s: its rows reach over a whole jump at %.0f m/s (%.1f m)" % [at, v_max, rows[-1] - rows[0]])
	var last_unsafe: float = float(unsafe[-1]["at"])
	var reach: float = CeilingScenarios.flip_late(last_unsafe, v_max) \
		+ v_max * CeilingScenarios.rise_seconds(mt, mt.ceiling_fence_depth) + half
	suite.check(rows[0] >= reach - 0.01, "%s: its first row (%.1f m) is past where the last unsafe pad's rider comes within reach (%.1f m)"
		% [at, rows[0], reach])
	var safe_lanes: Array[int] = []
	for p: Dictionary in safe:
		var body_back: float = CeilingScenarios.flip_early(float(p["at"])) - mt.hurtbox_size.z * 0.5
		suite.check(body_back > rows[-1] + half, "%s: the safe pad at %.1f m lifts its rider clear of the last row" % [at, p["at"]])
		suite.check(not safe_lanes.has(int(p["lane"])), "%s: its safe pads lie in lanes of their own" % at)
		safe_lanes.append(int(p["lane"]))
	var arrive: float = CeilingScenarios.flip_late(float(safe[-1]["at"]), v_max) + v_max * CeilingScenarios.rise_seconds(mt, 0.0)
	suite.check(float(h["end"]) >= arrive + t.safe_ride_seconds * v - 0.01,
		"%s runs on %.1f s past its last safe pad's rider's arrival" % [at, (float(h["end"]) - arrive) / v])
	for c: Dictionary in layout.credits:
		if String(c["surface"]) != "ceiling" or float(c["at"]) < float(h["start"]) or float(c["at"]) > float(h["end"]):
			continue
		for r: float in rows:
			suite.check(absf(float(c["at"]) - r) >= half + LevelGenerator.CEILING_FENCE_CREDIT_MARGIN - 0.01,
				"%s: no ceiling credit by a fence (%.1f m, row %.1f m)" % [at, c["at"], r])
	suite.check(not CeilingScenarios.wall_jump_near(gen, h, rows[0] - half, rows[-1] + half),
		"%s: no wall jump reaches its rows (a ramp's wall run or a hover truck beside them)" % at)
	# The heli drones (task I4's review). It records its pick, which a drone that outlived its pads holds its barrages
	# through (LevelLayout.fenced_pick_between, Drone._pick_in_reach); no wave arrives during it, nor has its first pad
	# there; and with a wave about, the last pad before the pick that works (any but a trap) lies no more than the
	# drone schedule's pad_repeat_max_seconds before it (GDD §9.6: a missed pad, another 8–10 s later), and the pick
	# ends with its safe pads: a missed pad costs no more barrage time than the schedule allows.
	var pick: Variant = h.get("pick")
	var scene := Vector2(gen.zones.pad_zone(float(pads[0]["at"])).x, float(safe[-1]["at"]) + mt.pad_length)
	suite.check(pick is Array and (pick as Array).size() == 2 and float(pick[0]) <= scene.x + 0.01 and float(pick[1]) >= scene.y - 0.01,
		"%s records its pick, from its first pad's run-up to its last safe pad (%s; %.1f-%.1f m)" % [at, pick, scene.x, scene.y])
	suite.check(layout.fenced_pick_between(scene.x, scene.x) and layout.fenced_pick_between(scene.y, scene.y),
		"%s: a drone reads its pick from the layout" % at)
	for w: Vector2 in CeilingScenarios.drone_windows(gen, t.drone_margin_seconds):
		suite.check(w.y < scene.x or w.x > scene.y, "%s: no drone wave arrives or waits for its first pad during its pick (%.0f-%.0f m)"
			% [at, w.x, w.y])
	var dt := EnemyDirector.tuning_for("drone") as DroneTuning
	var first_wave: float = INF
	for e: Dictionary in layout.enemies:
		if String(e.get("type", "")) == "drone":
			first_wave = minf(first_wave, float(e["at"]))
	if dt != null and first_wave < scene.x:
		var before: float = -INF
		for p: Dictionary in layout.pads:
			if String(p.get("fenced", "")) != "unsafe" and float(p["at"]) < scene.x and float(p["at"]) > first_wave:
				before = maxf(before, float(p["at"]))
		suite.check((scene.x - before) / v <= dt.pad_repeat_max_seconds + 0.001,
			"%s: with a drone wave about, the pad before its pick that works lies %.2f s before it (at most %.1f s)"
			% [at, (scene.x - before) / v, dt.pad_repeat_max_seconds])


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
		# The schedule is the pads every rule but a ceiling scenario places: a fenced ceiling's added pads (task I4,
		# marked "added") are a choice on a ceiling after its first pad, off every drone wave's window
		# (CeilingScenarios.drone_windows; the first pad after a drone, above, counts them).
		var schedule: Array[float] = []
		for p: Dictionary in layout.pads:
			if not p.has("added") and not schedule.has(float(p["at"])):
				schedule.append(float(p["at"]))
		schedule.sort()
		for i: int in schedule.size() - 1:
			if schedule[i] < schedule_start - 0.01:
				continue
			var gap: float = (schedule[i + 1] - schedule[i]) / speed
			suite.check(gap >= dt.pad_repeat_min_seconds - 0.001 and gap <= dt.pad_repeat_max_seconds + 0.001,
				"a drone's pads stay 8–10 s apart (%.2f s at %.0f m) %s" % [gap, schedule[i], tag])
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
	check_charge_paths(suite, layout, config, tag)


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


## Wider gaps (task G7; owner, October 7, 2026, GDD §9.13 "Holes": a couple a level, uncommon, still jumpable,
## and too wide for an Enforcer Truck following the runner in to hop), in a level that asks for them
## (LevelConfig.wide_gaps; WideGapPlacement), at the level's own run speed:
## - as many as the level asks for (on a seed not its own, at least one), each its WideGapTuning.jump_fraction of a
##   jump: more than the truck hops
##   (EnforcerTruckTuning.max_hop_jump_fraction) and no more than a level may ask a runner to jump
##   (max_gap_jump_fraction); spacing_seconds apart;
## - never stacked with another demand (WideGapPlacement.blocker): from its take-off margin to its landing margin
##   (zone_of: clear_before_seconds, clear_after_seconds, never less than the level's spacing there) no other
##   hole, fence, ramp or where its wall run drops the runner back, pad's zone, speed pad, ceiling's landing zone,
##   floor cut's window, enemy's attack or floor, attack the rules keep doodads off, or zone doodad (nor its push's
##   lead), in any lane; no ceiling or ramp's wall run over the jump itself; and no side wall gap on either wall
##   within wall_gap_clear_seconds of it.
## A level that asks for none has none (its rows are 0.55 of a jump at most).
static func check_wide_gaps(suite: TestSuite, layout: LevelLayout, config: LevelConfig, tag: String) -> void:
	var tuning: MovementTuning = level_tuning(suite, config)
	var speed: float = tuning.run_speed
	var jump: float = tuning.jump_distance(speed)
	var et := EnemyDirector.tuning_for("enforcer_truck") as EnforcerTruckTuning
	var hop: float = et.max_hop_jump_fraction if et != null else 0.6
	var rows: Array[Dictionary] = WideGapPlacement.wide_rows(layout, jump, hop)
	if config.wide_gaps <= 0 or WallGapPlacement.is_boss_arena(config):
		suite.check(rows.is_empty(), "no wider gaps where the level asks for none (%d) %s" % [rows.size(), tag])
		return
	var t: WideGapTuning = WideGapPlacement.tuning()
	# Every campaign level gets its count on its own seed (test_wide_gaps); on another seed a level crowded with
	# other demands may fit one fewer (the generator says so, LevelGenerator.wide_gap_result), never none.
	suite.check(rows.size() <= config.wide_gaps and rows.size() >= maxi(config.wide_gaps - 1, mini(config.wide_gaps, 1)),
		"the level has its %d wider gaps, or one fewer where nothing else fits (%d) %s" % [config.wide_gaps, rows.size(), tag])
	var gen: LevelGenerator = LevelGenerator.for_layout(config, suite.tuning, layout)
	var keeps: Array[Dictionary] = WideGapPlacement.keeps_of(gen)
	var lead: float = LevelGenerator.doodad_lead_for(gen.tuning)
	var prev_end: float = -INF
	for row: Dictionary in rows:
		var start: float = float(row["start"])
		var end: float = float(row["end"])
		var w: String = "(wider gap %.1f-%.1f, %.2f of a jump, lanes %s) %s" % [start, end, (end - start) / jump, row["lanes"], tag]
		suite.check(end - start > hop * jump + 0.001 and end - start <= config.max_gap_jump_fraction * jump + 0.001
			and absf(end - start - minf(t.jump_fraction, config.max_gap_jump_fraction) * jump) < 0.01,
			"a wider gap is too wide for an Enforcer Truck to hop and still jumpable " + w)
		suite.check(start - prev_end >= t.spacing_seconds * speed - 0.01, "wider gaps keep their spacing " + w)
		prev_end = end
		var why: String = WideGapPlacement.blocker(gen, t, Vector2(start, end), row, keeps)
		suite.check(why == "", "nothing else in any lane from a wider gap's take-off margin to its landing margin (%s) %s"
			% [why, w])
		var zone: Vector2 = WideGapPlacement.zone_of(gen, t, Vector2(start, end))
		suite.check(not layout.doodad_between(zone.x + 0.01, zone.y + lead - 0.01),
			"no zone doodad (nor its push's lead) at a wider gap's take-off or landing " + w)
		var clear: float = t.wall_gap_clear_seconds * speed
		suite.check(not layout.wall_gap_between(start - clear, end + clear), "no side wall gap beside a wider gap " + w)


## Cyborgs in charge paths (task G7; owner, October 7, 2026, GDD §9.13 "Teaching"; ChargePathPlacement), at the
## level's own run speed. Each planted cyborg:
## - is a plain floor cyborg: never a host, never the panic variant, standing where it's placed;
## - stands in the path of its charger's charge: an Octodog's planned first lunge, from where the dog stands, two
##   lanes across along a line through the cyborg (the cyborg in the lane beside the dog's, dog_cyborg_ahead in
##   front of it, the path free of holes), or a parked Buzz Overdrive's charge (the cyborg in the cut's lane, in
##   front of its end, past where the cut meets the runner);
## - is reached by it in view, in_view_seconds or more ahead of a runner at the run speed;
## - holds its fire from hold_before_seconds before the charge's warning until the charge has passed the runner;
## - comes where no other big attack is planned around it (attack_margin_seconds).
## (check_rules' cyborg margin and check_ceilings' floor enemies hold for it as for any cyborg.)
static func check_charge_paths(suite: TestSuite, layout: LevelLayout, config: LevelConfig, tag: String) -> void:
	var planted: Array[Dictionary] = ChargePathPlacement.planted_in(layout)
	if config.charge_path_cyborgs <= 0:
		suite.check(planted.is_empty(), "no cyborg planted in a charge's path where the level asks for none " + tag)
		return
	suite.check(planted.size() <= config.charge_path_cyborgs, "at most %d cyborgs planted in charge paths (%d) %s"
		% [config.charge_path_cyborgs, planted.size(), tag])
	var tuning: MovementTuning = level_tuning(suite, config)
	var v: float = tuning.run_speed
	var pace: float = tuning.pace()
	var t: ChargePathTuning = ChargePathPlacement.tuning()
	var gen: LevelGenerator = LevelGenerator.for_layout(config, suite.tuning, layout)
	var ot := EnemyDirector.tuning_for("octodog") as OctodogTuning
	var scaling: float = config.enemy_scaling
	for e: Dictionary in planted:
		var at: float = float(e["at"])
		var lane: int = int(e["lane"])
		var params: Dictionary = e.get("params", {})
		var kind: String = String(params.get(ChargePathPlacement.PARAM, ""))
		var w: String = "(%s's cyborg at %.1f, lane %d) %s" % [kind, at, lane, tag]
		suite.check(String(e["type"]) == "cyborg" and int(e.get("side", 0)) == 0 and not bool(params.get("host", false))
			and not bool(params.get("panic", true)) and bool(params.get("stand", false)),
			"a plain floor cyborg, never a host, standing where it's placed " + w)
		var charger: Dictionary = ChargePathPlacement.charger_of(layout, e)
		suite.check(not charger.is_empty() and String(charger.get("type", "")) == kind, "it stands in its charger's path " + w)
		if charger.is_empty():
			continue
		var hold: Vector2 = params.get("hold_fire", Vector2(INF, -INF))
		var cp: Dictionary = charger.get("params", {})
		var warn: float = INF
		var strike_end: float = -INF
		var span := Vector2(INF, -INF)
		var lanes: Array[int] = [lane]
		if kind == ChargePathPlacement.DOG:
			var d: float = float(charger["at"])
			var anchors: Array = cp.get("charge_at", [])
			var dog_lane: int = int(charger["lane"])
			var far: int = lane + (lane - dog_lane)
			suite.check(absi(lane - dog_lane) == 1 and far >= 0 and far < layout.lane_count,
				"in the lane beside the dog's, its lunge two lanes across " + w)
			var most: float = t.dog_cyborg_ahead + ChargePathPlacement.DOG_SPOT_STEP * (ChargePathPlacement.DOG_SPOTS - 1)
			suite.check(d - at >= t.dog_cyborg_ahead * pace - 0.01 and d - at <= most * pace + 0.01,
				"dog_cyborg_ahead (or a little more) in front of the dog (%.2f m) %s" % [d - at, w])
			suite.check(not anchors.is_empty() and absf(float(anchors[0]) - (d - ot.stop_distance(v, scaling, pace))) < 0.5,
				"the dog's first lunge is from its spot " + w)
			suite.check(ChargePathPlacement.path_clear(gen, ot, dog_lane, lane, d, at), "the lunge's path keeps off every hole " + w)
			warn = float(anchors[0]) if not anchors.is_empty() else INF
			strike_end = warn + (ot.windup_time(scaling) + ot.lunge_duration(v, scaling, pace)) * v
			suite.check(ChargePathPlacement.dog_in_view(gen, t, ot, d, at), "the lunge reaches it in view " + w)
			span = Vector2(float(cp.get("claim_at", warn)) - t.attack_margin_seconds * v, strike_end + t.attack_margin_seconds * v)
			lanes = [dog_lane, lane, far]
			suite.check(absf(float(cp.get("claim_at", INF)) - (warn - t.claim_seconds * v)) < 0.01,
				"the dog claims its turn claim_seconds before its wind-up " + w)
		else:
			var cut: Dictionary = BuzzOverdriveRulesScript.cut_of(layout, charger)
			suite.check(bool(cut.get("park", false)) and int(cut["lane"]) == lane and at < float(cut["end"])
				and at > FloorCutPlan.meet(cut, v), "in the parked tank's lane, in front of it, past where its cut meets the runner " + w)
			warn = FloorCutPlan.warn_at(cut)
			strike_end = FloorCutPlan.meet(cut, v)
			suite.check(ChargePathPlacement.tank_in_view(gen, t, cut, at), "the blade reaches it in view " + w)
			var claim: float = maxf(t.claim_seconds, BuzzOverdriveRulesScript.tuning().claim_seconds)
			suite.check(is_equal_approx(float(cut.get("claim_seconds", -1.0)), claim), "the tank claims its turn claim_seconds before its rev " + w)
			span = Vector2(warn - claim * v - t.attack_margin_seconds * v, FloorCutPlan.window(cut, v).y + t.attack_margin_seconds * v)
		suite.check(hold.x <= warn - t.hold_before_seconds * v + 0.01 and hold.y >= strike_end - 0.01,
			"it holds its fire from before the warning until the charge has passed the runner " + w)
		var near: String = ChargePathPlacement.attack_near(gen, charger, span, lanes)
		suite.check(near == "", "no other big attack planned around it (%s) %s" % [near, w])


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
	if feature in ["ramps", "ceilings", "speed_pads", "pulsing", "wall_fences", "wall_fences_partial", "wall_gaps", "host", "screech_vents"]:
		return true
	var rules: String = "res://scripts/enemies/%s_rules.gd" % feature
	if ResourceLoader.exists(rules) and (load(rules) as GDScript).has_method("positions"):
		return true
	return ResourceLoader.exists("res://scripts/enemies/%s.gd" % feature)


## True if `feature` is sprinkled in rather than guaranteed (its rules script's OCCASIONAL: the ceiling scenarios,
## task I4): a build of a level that lists it may have none, so the campaign checks don't ask every build for one.
static func occasional(feature: String) -> bool:
	var rules: String = "res://scripts/enemies/%s_rules.gd" % feature
	if not ResourceLoader.exists(rules):
		return false
	var script := load(rules) as GDScript
	return script != null and bool(script.get_script_constant_map().get("OCCASIONAL", false))


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
## floor cut's stretch counts as a hole in its lane). A wall-run gap's holes (task J2) are left out: no jump
## crosses one, its lit wall does (check_wall_run_gaps keeps every other hole out of its clear stretch).
static func longest_all_lane_hole(layout: LevelLayout) -> float:
	var common: Array[Vector2] = []
	for lane: int in layout.lane_count:
		var mine: Array[Vector2] = []
		for g: Dictionary in layout.gaps:
			if g["lane"] == lane and not LevelLayout.is_wall_run_hole(g):
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
