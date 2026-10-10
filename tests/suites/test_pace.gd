extends TestSuite
## GDD §3, "Pace and busier levels" (owner's playtest, September 30, 2026): the run speed rises zone
## by zone (about 21 m/s in the Neon City to about 25 m/s in the Golden Zone), enemies and their
## attacks speed up to match, and the levels get busier.
## - Speeds in data: each zone's, a level's own, the tier's multiplier, the base speed for quick play
##   and the tests; a boss fight at its zone's speed like the zone's levels (E1f); the generator,
##   RunWorld and App run a level at the same speed, and a level keeps its duration in seconds.
## - Pace (MovementTuning.pace): a pattern keeps its timing in seconds at any speed; the generator's
##   fairness at 21, 23.4 and 25 m/s, at 3, 5 and 6 lanes, with every built feature and the fill pass,
##   on many seeds (the campaign suite does the campaign's levels at their zones' speeds); floor routes
##   under ceilings run on real physics at 25 m/s.
## - The world-frame enemies keep every warning and dodge window in seconds at 25 m/s: the Octodog's
##   wind-up and lunge, the Resonator's warning and wave (and it stays within laser tier 1's reach), the
##   cyborg's charge-up and bolts (a burst still hits a player who stays and misses one who switches
##   lanes), the screech's shake.
## - The fill pass (LevelConfig.fill_empty_seconds): off, a level is as it was; on, only plain obstacle
##   patterns, only in stretches empty for longer than its threshold, spaced from everything around
##   them, never under a ceiling below the level's gauntlets or over one lane, never in a hover truck's
##   lane while it's around, and deterministic.
## - F6: Save leaves the base run speed alone when the run's comes from its level.

const SPEEDS: Array[float] = [21.0, 23.4, 25.0]
const EVERY_FEATURE: PackedStringArray = ["ramps", "ceilings", "pulsing", "speed_pads", "cyborg", "window_cyborg",
	"hover_truck", "screech", "drone", "generator", "host", "octodog"]


func run() -> void:
	_test_speed_data()
	_test_movement_for()
	_test_pattern_timing()
	_test_fairness_at_speed()
	_test_fill_pass()
	_test_enemy_windows()
	await _test_world_speed()
	await _test_cyborg_at_speed()
	await _test_screech_at_speed()
	await _test_resonator_at_speed()
	await _test_floor_routes_at_speed()
	await _test_tuning_panel_keeps_speed()


func _fast(speed: float) -> MovementTuning:
	var t: MovementTuning = tuning.duplicate() as MovementTuning
	t.run_speed = speed
	return t


## GDD §3: about 21 m/s in the Neon City, rising zone by zone to about 25 m/s in the Golden Zone. Every
## campaign level and boss fight takes its zone's speed (times a harder tier's multiplier); quick play
## and the tests keep the base speed; a level lasts as many seconds as before and gets longer in metres.
func _test_speed_data() -> void:
	var campaign := load("res://data/campaign/campaign.tres") as Campaign
	var last: float = 0.0
	for zone: ZoneDef in campaign.zones:
		check(zone.run_speed > last, "%s runs faster than the zone before it (%.1f m/s)" % [zone.id, zone.run_speed])
		last = zone.run_speed
	check(absf(campaign.zones[0].run_speed - 21.0) <= 0.5 and absf(campaign.zones[-1].run_speed - 25.0) <= 0.5,
		"about 21 m/s in the Neon City and about 25 m/s in the Golden Zone (%.1f, %.1f)" % [campaign.zones[0].run_speed,
			campaign.zones[-1].run_speed])
	check(is_equal_approx(tuning.run_speed, MovementTuning.REFERENCE_SPEED) and is_equal_approx(tuning.pace(), 1.0),
		"the base speed (quick play, the tests) is the reference speed, pace 1")
	var quick := load(LEVEL_PATH) as LevelConfig
	check(quick.run_speed == 0.0 and quick.fill_empty_seconds == 0.0, "quick play's level keeps the base speed and no fill pass")
	for s: CampaignStep in campaign.steps():
		# A mini-game level (the Beach's volleyball match) plans its own track, not the generator's.
		if s.is_level() and not s.is_minigame():
			var config: LevelConfig = campaign.configure(s, 3)
			check(is_equal_approx(config.run_speed, s.zone.run_speed), "%s runs at its zone's speed (%.1f)" % [s.id, config.run_speed])
			check(is_equal_approx(campaign.configure(s, 3, 1).run_speed, s.zone.run_speed * campaign.speed_multiplier(1)),
				"%s: a harder tier multiplies its speed" % s.id)
			# T-SPEED: the level's own default build (LayoutCache), shared with test_campaign.gd and others.
			var layout: LevelLayout = LayoutCache.generate(config, tuning, LevelGenerator.load_for(config))
			check(is_equal_approx(layout.length, config.run_speed * config.duration_seconds),
				"%s lasts %.0f s: %.0f m at %.1f m/s" % [s.id, config.duration_seconds, layout.length, config.run_speed])
			check(config.fill_empty_seconds > 0.0, "%s fills its long empty stretches" % s.id)
		elif s.kind == CampaignStep.Kind.BOSS and s.boss != null:
			# E1f: a boss fight runs at its zone's speed, like the zone's levels; quick play's keeps the base.
			var arena: LevelConfig = campaign.configure_boss(s, 3)
			check(is_equal_approx(arena.run_speed, s.zone.run_speed) and is_equal_approx(arena.movement_for(tuning).run_speed,
				s.zone.run_speed), "%s fights at its zone's speed (%.1f)" % [s.id, arena.run_speed])
			check(is_equal_approx(campaign.configure_boss(s, 3, 2).run_speed, s.zone.run_speed * campaign.speed_multiplier(2)),
				"%s: a harder tier multiplies its speed" % s.id)
			check(BossArena.base_config(s.boss).run_speed == 0.0, "%s in quick play keeps the base speed" % s.id)
	# A level's own speed wins over its zone's.
	var step: CampaignStep = campaign.step("city/1")
	var own := CampaignStep.new()
	own.zone = step.zone
	own.level = step.level.duplicate() as LevelConfig
	own.level.run_speed = 23.0
	check(is_equal_approx(campaign.run_speed_for(own), 23.0), "a level's own speed wins over its zone's")


func _test_movement_for() -> void:
	var config := LevelConfig.new()
	check(config.movement_for(tuning) == tuning, "no speed of its own: the base tuning itself")
	config.run_speed = 25.0
	var t: MovementTuning = config.movement_for(tuning)
	check(t != tuning and is_equal_approx(t.run_speed, 25.0) and is_equal_approx(tuning.run_speed, 18.0),
		"a speed of its own: a copy at that speed, the base untouched")
	check(is_equal_approx(t.pace(), 25.0 / 18.0) and is_equal_approx(t.jump_height, tuning.jump_height),
		"its pace is its speed over the reference speed; nothing else changes")
	check(config.movement_for(t) == t, "a tuning at the level's speed already is used as it is")


## A pattern keeps its timing in seconds at any run speed: its pieces' offsets and length are stretched
## by the pace, and a hole stays the same share of a (longer) jump.
func _test_pattern_timing() -> void:
	var pattern: Dictionary = {"id": "timing", "min_difficulty": 0.0, "weight": 1, "length": 30, "elements": [
		{"kind": "gap", "at": 0, "lanes": {"mode": "all_but", "count": 1}, "jump_frac": 0.45},
		{"kind": "fence", "at": 12, "variant": "full", "lanes": {"mode": "random", "count": 1}},
		{"kind": "sign", "at": 18, "side": "left", "length": 8, "bottom": 0.0, "top": 1.4}]}
	var times: Array = []
	for speed: float in [18.0, 25.0]:
		var config: LevelConfig = (load(LEVEL_PATH) as LevelConfig).duplicate() as LevelConfig
		config.features = PackedStringArray()
		config.run_speed = speed
		config.duration_seconds = 30.0
		config.difficulty_ramp = 0.0  # the same spacing all through, whatever the level's length in metres
		var gen := LevelGenerator.new()
		var layout: LevelLayout = gen.generate(config, tuning, [pattern])
		check(layout.gaps.size() > 0 and layout.fences.size() > 0 and layout.signs.size() > 0 and gen.picks.size() > 1,
			"the pattern comes more than once at %.0f m/s" % speed)
		if layout.gaps.is_empty() or layout.fences.is_empty() or layout.signs.is_empty() or gen.picks.size() < 2:
			return
		var g: Dictionary = layout.gaps[0]
		var f: Dictionary = layout.fences[0]
		var s: Dictionary = layout.signs[0]
		times.append([(float(g["end"]) - float(g["start"])) / speed, (float(f["at"]) - float(g["start"])) / speed,
			(float(s["end"]) - float(s["start"])) / speed, (float(gen.picks[1]["at"]) - float(gen.picks[0]["at"])) / speed])
	var what: PackedStringArray = ["a hole's length", "a fence's offset", "a sign's length", "the time between two patterns"]
	for i: int in 4:
		check(absf(float(times[0][i]) - float(times[1][i])) < 0.001, "%s is the same at 18 and 25 m/s (%.3f s, %.3f s)"
			% [what[i], times[0][i], times[1][i]])


## The generator's fairness at the zones' speeds: every built feature, the campaign's spacing and fill
## pass (the Neon City's first level's), at 3, 5 and 6 lanes, at three difficulties and many seeds: no
## warnings, the shared layout and rule checks, and the same level every time.
func _test_fairness_at_speed() -> void:
	var base := load(LEVEL_PATH) as LevelConfig
	var campaign_level := load("res://data/levels/city_1.tres") as LevelConfig
	var levels: int = 0
	var fills: int = 0
	for speed: float in SPEEDS:
		for lanes: int in [3, 5, 6]:
			for difficulty: float in [0.2, 0.6, 1.0]:
				for level_seed: int in range(1, 7):
					var config: LevelConfig = base.duplicate() as LevelConfig
					config.run_speed = speed
					config.lane_count = lanes
					config.difficulty = difficulty
					config.enemy_scaling = difficulty
					config.level_seed = level_seed
					config.features = EVERY_FEATURE
					config.spacing_seconds_easy = campaign_level.spacing_seconds_easy
					config.spacing_seconds_hard = campaign_level.spacing_seconds_hard
					config.fill_empty_seconds = campaign_level.fill_empty_seconds
					var tag: String = "speed=%.1f lanes=%d diff=%.1f seed=%d" % [speed, lanes, difficulty, level_seed]
					var patterns: Array = LevelGenerator.load_for(config)
					var gen := LevelGenerator.new()
					var layout: LevelLayout = gen.generate(config, tuning, patterns)
					check(gen.warnings.is_empty(), "no warnings %s %s" % [tag, gen.warnings])
					LayoutChecks.check_layout(self, layout, config, tag)
					LayoutChecks.check_rules(self, layout, config, tag)
					var again: LevelLayout = LevelGenerator.new().generate(config, tuning, patterns)
					check(JSON.stringify(again.to_dict()) == JSON.stringify(layout.to_dict()), "deterministic " + tag)
					levels += 1
					fills += gen.fills.size()
	check(fills > levels, "the fill pass placed fillers (%d in %d levels)" % [fills, levels])
	print("  fairness at 21, 23.4 and 25 m/s: %d levels, %d fillers" % [levels, fills])


## The fill pass: off, the level is what it was; on, more of the level's plain obstacles in its long
## empty stretches, and only there, as far from everything as the pattern pass spaces its patterns.
func _test_fill_pass() -> void:
	var campaign := load("res://data/campaign/campaign.tres") as Campaign
	var filled: int = 0
	var truck_lanes: int = 0
	for id: String in ["city/3", "gangland/3", "corporate/2", "golden/2"]:
		for lanes: int in [3, 6]:
			for k: int in 3:
				var config: LevelConfig = campaign.configure(campaign.step(id), lanes)
				config.level_seed = 7000 + k
				var patterns: Array = LevelGenerator.load_for(config)
				var tag: String = "%s lanes=%d seed=%d" % [id, lanes, config.level_seed]
				var off: LevelConfig = config.duplicate() as LevelConfig
				off.fill_empty_seconds = 0.0
				var gen := LevelGenerator.new()
				var layout: LevelLayout = gen.generate(config, tuning, patterns)
				var plain_gen := LevelGenerator.new()
				var plain: LevelLayout = plain_gen.generate(off, tuning, patterns)
				check(plain_gen.fills.is_empty(), "no fill pass with fill_empty_seconds 0 " + tag)
				if gen.attempts != plain_gen.attempts:
					continue  # the guarantee's rebuilds differed: not the same pattern pass to compare with
				check(JSON.stringify(gen.picks) == JSON.stringify(plain_gen.picks), "the fill pass leaves the pattern pass as it was " + tag)
				check(layout.enemies.size() == plain.enemies.size() and layout.hulls.size() == plain.hulls.size()
					and layout.ramps.size() == plain.ramps.size(), "and adds no enemy, ceiling or ramp " + tag)
				var by_id: Dictionary = {}
				for p: Dictionary in patterns:
					by_id[String(p.get("id", ""))] = p
				for f: Dictionary in gen.fills:
					check(LevelGenerator.is_filler(by_id.get(String(f["id"]), {})), "a filler is a plain obstacle pattern (%s) %s" % [f["id"], tag])
				filled += gen.fills.size()
				# Fillers stay off everything the level had before them, with the pattern pass's spacing.
				var outs: Dictionary = plain_gen.fill_keep_outs(patterns)
				for f: Dictionary in gen.fills:
					var span := Vector2(float(f["at"]), float(f["at"]) + float(f["used"]))
					for keep: Vector4 in outs["keep"]:
						check(span.y <= keep.x - keep.z + 0.01 or span.x >= keep.y + keep.w - 0.01,
							"a filler at %.0f keeps off %.0f–%.0f by its margin %s" % [span.x, keep.x, keep.y, tag])
					var threshold: float = config.fill_empty_seconds * plain_gen.speed
					var empty_around: bool = false
					for e: Vector2 in LevelGenerator.free_stretches(outs["activity"], config.start_clear_distance,
							plain.length - config.end_clear_distance):
						empty_around = empty_around or (e.x <= span.x and e.y >= span.y and e.y - e.x > threshold)
					check(empty_around, "a filler at %.0f stands where nothing went on for over %.1f s %s" % [span.x,
						config.fill_empty_seconds, tag])
				# A hover truck's lane stays clear of every hole and fence while it's around.
				var tt := EnemyDirector.tuning_for("hover_truck") as HoverTruckTuning
				for e: Dictionary in layout.enemies:
					if String(e["type"]) != "hover_truck":
						continue
					truck_lanes += 1
					var at: float = float(e["at"])
					var from: float = at - tt.burst_lead - tt.clear_before * gen.pace
					var to: float = at + (tt.stay_max_seconds + tt.leave_seconds) * gen.speed
					for g: Dictionary in layout.gaps:
						check(int(g["lane"]) != int(e["lane"]) or float(g["end"]) < from or float(g["start"]) > to,
							"no hole in a hover truck's lane while it's around " + tag)
					for f: Dictionary in layout.fences:
						check(int(f["lane"]) != int(e["lane"]) or float(f["at"]) < from or float(f["at"]) > to,
							"no fence in a hover truck's lane while it's around " + tag)
	check(filled > 0, "the campaign levels get fillers (%d)" % filled)
	check(truck_lanes > 0, "some levels have hover trucks to check (%d)" % truck_lanes)


## The world-frame enemies' warnings and dodge windows keep their seconds at the fastest zone's pace
## (the Golden Zone, 25 m/s): the Octodog's wind-up and lunge, the Resonator's warning and wave (it
## hovers as far ahead in every zone, within laser tier 1's reach, and the runner closes in on its
## waves as fast). The warnings themselves are seconds and never change.
func _test_enemy_windows() -> void:
	var ot := EnemyDirector.tuning_for("octodog") as OctodogTuning
	var rt := EnemyDirector.tuning_for("resonator") as ResonatorTuning
	for speed: float in SPEEDS:
		var p: float = speed / MovementTuning.REFERENCE_SPEED
		for s: float in [0.0, 0.5, 1.0]:
			check(absf(ot.time_to_meet(speed, s, p) - ot.time_to_meet(18.0, s)) < 0.0001,
				"an Octodog's lunge takes as long to reach the player at %.1f m/s (%.3f s)" % [speed, ot.time_to_meet(speed, s, p)])
			check(absf(ot.window_length(speed, s, p) / speed - ot.window_length(18.0, s) / 18.0) < 0.0001,
				"its whole charge takes as long at %.1f m/s" % speed)
			check(ot.lunge_speed_at(s, p) > ot.lunge_speed(s), "it lunges faster at %.1f m/s" % speed)
			check(absf(rt.travel_seconds(speed, s, p) - rt.travel_seconds(18.0, s)) < 0.0001
				and absf(rt.meet_offset(speed, s, p) / speed - rt.meet_offset(18.0, s) / 18.0) < 0.0001,
				"a Resonator's wave takes as long to reach the player at %.1f m/s" % speed)
			check(absf(speed + rt.wave_speed_at(s, p) - (18.0 + rt.wave_speed_at(s))) < 0.0001 and rt.wave_speed_at(s, p) > 0.0,
				"the runner closes in on its waves as fast at %.1f m/s, and they still roll toward them (%.1f m/s)"
				% [speed, rt.wave_speed_at(s, p)])
	var powerups := load("res://data/tuning/powerups.tres") as PowerupTuning
	var tier1_range: float = PowerupTuning.at_tier(powerups.weapon_range, 1)
	check(rt.hover_ahead < tier1_range - 5.0,
		"in every zone the Resonator hovers within laser tier 1's reach, the shortest (%.0f of %.0f m)"
		% [rt.hover_ahead, tier1_range])


## RunWorld runs a level at its own speed whatever tuning it's handed, as the generator built it.
func _test_world_speed() -> void:
	var sim := RunSim.new(tree, tuning)
	var config := LevelConfig.new()
	config.run_speed = 25.0
	var w: RunWorld = sim.build_world(RunSim.layout(3, 600.0), null, tuning, config)
	check(is_equal_approx(w.tuning.run_speed, 25.0) and is_equal_approx(tuning.run_speed, 18.0),
		"the world runs at the level's speed (%.1f m/s)" % w.tuning.run_speed)
	var r: Dictionary = await sim.step_world(w, 1.0)
	check(absf(w.player.speed - 25.0) < 0.01 and bool(r["alive"]), "and so does the player (%.1f m/s)" % w.player.speed)
	await sim.free_world(w)


## GDD §9.2 at 25 m/s: the charge-up and the bolts' minimum flight keep their seconds, a burst still
## hits a player who stays in its path and misses one who switches lanes after the charge-up, and the
## cyborg engages from further out, with faster bolts.
func _test_cyborg_at_speed() -> void:
	var fast: MovementTuning = _fast(25.0)
	var sim := RunSim.new(tree, fast)
	var ct := EnemyDirector.tuning_for("cyborg") as CyborgTuning
	var w: RunWorld = sim.build_world(RunSim.layout(3, 800.0), null, fast)
	var c := w.director.spawn({"type": "cyborg", "at": 160.0, "lane": 2, "side": 0, "seed": 7,
		"params": {"panic": false}}) as Cyborg
	check(c.gun.pace > 1.3 and c.gun.engage_distance() > ct.engage_distance and c.gun.bolt_speed() > ct.bolt_speed_at(0.0),
		"at 25 m/s it engages from further out, with faster bolts")
	var r: Dictionary = await sim.step_world(w, 8.0)
	check(not r["alive"] and r["cause"] == CyborgGun.SHOT_NAME, "a burst hits a player who stays in its path at 25 m/s (%s)" % r["cause"])
	var charge: Dictionary = {}
	var shot: Dictionary = {}
	for e: Dictionary in c.gun.events:
		if charge.is_empty() and e["event"] == &"charge":
			charge = e
		if shot.is_empty() and e["event"] == &"shot":
			shot = e
	check(not charge.is_empty() and not shot.is_empty(), "it charged up and fired")
	if not charge.is_empty() and not shot.is_empty():
		check(float(shot["t"]) - float(charge["t"]) >= ct.charge_time - 0.02,
			"the charge-up still comes %.2f s before the first bolt" % (float(shot["t"]) - float(charge["t"])))
		check(float(shot["arrive"]) - float(shot["t"]) >= ct.min_warning_time,
			"the first bolt still takes at least %.2f s to arrive (%.2f s)" % [ct.min_warning_time,
				float(shot["arrive"]) - float(shot["t"])])
	await sim.free_world(w)
	w = sim.build_world(RunSim.layout(3, 800.0), null, fast)
	c = w.director.spawn({"type": "cyborg", "at": 160.0, "lane": 2, "side": 0, "seed": 7,
		"params": {"panic": false}}) as Cyborg
	var fired: bool = false
	w.player.running = true
	for i: int in 8 * Engine.physics_ticks_per_second:
		await tree.physics_frame
		if c.gun.state == CyborgGun.State.FIRING:
			fired = true
			break
	check(fired, "it fires at an approaching player at 25 m/s")
	w.player.press(&"move_left")
	for i: int in 3 * Engine.physics_ticks_per_second:
		await tree.physics_frame
	check(w.player.alive and w.player.lane == 0, "switching lanes after the charge-up still dodges the whole burst")
	await sim.free_world(w)


## GDD §9.5 at 25 m/s: a screech still shakes its cover at least min_warning_seconds before the player
## reaches it, and then comes out.
func _test_screech_at_speed() -> void:
	var fast: MovementTuning = _fast(25.0)
	var sim := RunSim.new(tree, fast)
	var st := EnemyDirector.tuning_for("screech") as ScreechTuning
	var layout: LevelLayout = RunSim.layout(3, 600.0)
	var w: RunWorld = sim.build_world(layout, null, fast)
	var s := w.director.spawn({"type": "screech", "at": 150.0, "lane": 1, "side": 0, "seed": 3,
		"params": {"source": "manhole"}}) as Screech
	w.player.god_mode = true
	var shook_at: float = -1.0
	w.player.running = true
	for i: int in 8 * Engine.physics_ticks_per_second:
		await tree.physics_frame
		for h: Array in s.history:
			if shook_at < 0.0 and h[0] == "shake":
				shook_at = float(h[1])
		if w.player.distance > 160.0:
			break
	check(shook_at >= 0.0, "it shakes its cover at 25 m/s")
	if shook_at >= 0.0:
		check((150.0 - shook_at) / 25.0 >= st.min_warning_seconds - 0.02,
			"at least %.2f s before the player reaches it (%.2f s)" % [st.min_warning_seconds, (150.0 - shook_at) / 25.0])
	await sim.free_world(w)


## GDD §9.10 at the Golden Zone's speed, on real physics: the Resonator paces the runner hover_ahead
## ahead, where laser tier 1's auto-fire targets it, its warning lasts as long, and its wave takes as long
## from leaving it to passing the runner as at 18 m/s.
func _test_resonator_at_speed() -> void:
	var rt := EnemyDirector.tuning_for("resonator") as ResonatorTuning
	var pt := load("res://data/tuning/powerups.tres") as PowerupTuning
	var dt: float = 1.0 / Engine.physics_ticks_per_second
	var flights: Array[float] = []
	for speed: float in [MovementTuning.REFERENCE_SPEED, 25.0]:
		var tag: String = "at %.0f m/s" % speed
		var fast: MovementTuning = _fast(speed)
		var sim := RunSim.new(tree, fast)
		var w: RunWorld = sim.build_world(RunSim.layout(3, 900.0), null, fast)
		w.player.god_mode = true
		var r := w.director.spawn({"type": "resonator", "at": 80.0, "lane": 1, "side": 0, "seed": 5,
			"params": {"pulses": 1}}) as Resonator
		await tree.physics_frame
		w.player.running = true
		var id: int = r.get_instance_id()
		var ahead_ok: bool = true
		var targeted: bool = false
		var paced: int = 0
		for i: int in 12 * Engine.physics_ticks_per_second:
			await tree.physics_frame
			var o: Object = instance_from_id(id)
			var res: Resonator = o as Resonator if is_instance_valid(o) else null
			if res == null or res.state == Resonator.State.LEAVE:
				break
			if res.state in [Resonator.State.PACE, Resonator.State.WARNING, Resonator.State.PULSE]:
				paced += 1
				ahead_ok = ahead_ok and absf(res.track_distance() - w.player.distance - rt.hover_ahead) < 0.5
				var range_1: float = PowerupTuning.at_tier(pt.weapon_range, 1)
				targeted = targeted or (res.targetable()
					and w.director.targets_ahead(w.player.position + Vector3.UP, range_1).has(res))
		check(paced > 0 and ahead_ok, "it paces the runner hover_ahead (%.0f m) ahead %s" % [rt.hover_ahead, tag])
		check(targeted, "laser tier 1's auto-fire can target it " + tag)
		var o2: Object = instance_from_id(id)
		var done: Resonator = o2 as Resonator if is_instance_valid(o2) else null
		var warning: Array = done.events(PackedStringArray(["warning"])) if done != null else []
		var wave: Array = done.events(PackedStringArray(["wave"])) if done != null else []
		var passed: Array = done.events(PackedStringArray(["pass"])) if done != null else []
		check(warning.size() == 1 and wave.size() == 1 and passed.size() == 1, "one warning, one wave, and it passes " + tag)
		if warning.size() == 1 and wave.size() == 1 and passed.size() == 1:
			check(absf(float(wave[0][1]) - float(warning[0][1]) - rt.warning_seconds) <= dt * 1.5,
				"the whole warning (%.2f s) comes before its wave %s" % [rt.warning_seconds, tag])
			flights.append(float(passed[0][1]) - float(wave[0][1]))
		await sim.free_world(w)
	check(flights.size() == 2 and absf(flights[1] - flights[0]) <= dt * 2.5,
		"its wave takes as long from leaving it to passing the runner at 25 m/s as at 18 (%s s)" % str(flights))


## GDD §3 at the Golden Zone's speed: the floor routes FloorRoute finds under a level's ceilings (with
## the fill pass's fillers under some of them) are run by the real Player on real physics, never
## stepping on the pad.
func _test_floor_routes_at_speed() -> void:
	var campaign := load("res://data/campaign/campaign.tres") as Campaign
	var ran: int = 0
	for lanes: int in [3, 5, 6]:
		var config: LevelConfig = campaign.configure(campaign.step("golden/2"), lanes)
		var fast: MovementTuning = config.movement_for(tuning)
		var sim := RunSim.new(tree, fast)
		# T-SPEED: golden/2's own default build (LayoutCache), shared with test_campaign.gd and others.
		var layout: LevelLayout = LayoutCache.generate(config, tuning, LevelGenerator.load_for(config))
		var zones := CeilingZones.make(config, fast)
		var grid := FloorRoute.new(layout, fast)
		var runs: int = 0
		for h: Dictionary in layout.hulls:
			if runs >= 3:
				break
			var route: Dictionary = LayoutChecks.floor_route(grid, zones, h)
			var tag: String = "golden/2 lanes=%d, the ceiling at %.0f" % [lanes, h["start"]]
			check(bool(route["ok"]), "a floor route under %s (%s)" % [tag, route["reason"]])
			if not bool(route["ok"]):
				continue
			var r: Dictionary = await _replay(sim, fast, layout, route)
			check(bool(r["alive"]) and not (r["events"] as Array).has(&"pad") and bool(r["reached"])
				and not (r["events"] as Array).has(&"doodad_push"), "the player runs it at 25 m/s: %s, %s" % [tag, r["cause"]])
			runs += 1
			ran += 1
	check(ran >= 6, "floor routes run at 25 m/s: %d" % ran)


## Runs `route` on real physics (as test_generator's _replay, at `t`'s speed).
func _replay(sim: RunSim, t: MovementTuning, layout: LevelLayout, route: Dictionary) -> Dictionary:
	const LEAD: float = 40.0
	var from: float = float(route["from"])
	var to: float = float(route["to"])
	var offset: float = LEAD - from
	var part := RunSim.layout(layout.lane_count, to - from + LEAD + 100.0)
	var lists: Dictionary = layout.to_dict()
	var into: Dictionary = part.to_dict()
	for key: String in ["gaps", "fences", "pads", "hulls", "ramps", "speed_pads", "signs"]:
		for item: Dictionary in lists[key]:
			var start: float = float(item.get("start", item.get("at", 0.0)))
			var end: float = float(item.get("end", start + 5.0))
			if end < from - 1.0 or start > to:
				continue
			var moved: Dictionary = item.duplicate()
			for k: String in ["at", "start", "end"]:
				if moved.has(k):
					moved[k] = float(moved[k]) + offset
			(into[key] as Array).append(moved)
	# Zone doodads too (G5): the route keeps out of their lanes where they stand (FloorRoute).
	for d: Dictionary in layout.doodads:
		if float(d["end"]) < from - 1.0 or float(d["start"]) > to:
			continue
		var moved_doodad: Dictionary = d.duplicate()
		moved_doodad["start"] = float(d["start"]) + offset
		moved_doodad["end"] = float(d["end"]) + offset
		part.doodads.append(moved_doodad)
	var actions: Array = []
	for a: Array in route["actions"]:
		actions.append([float(a[0]) + offset - t.run_speed / Engine.physics_ticks_per_second, a[1]])
	var r: Dictionary = await sim.run(part, int(route["start_lane"]), (to - from + LEAD + 10.0) / t.run_speed, actions)
	r["reached"] = float(r["distance"]) >= to + offset
	return r


## F6 (TuningPanel): a section's "keep" properties aren't written by Save: a campaign level's run speed
## (its zone's) never ends up in the movement tuning.
func _test_tuning_panel_keeps_speed() -> void:
	var path: String = "user://test_pace_movement.tres"
	check(ResourceSaver.save(tuning.duplicate(), path) == OK, "a scratch copy of the movement tuning")
	var live: MovementTuning = tuning.duplicate() as MovementTuning
	live.run_speed = 25.0
	live.jump_height = tuning.jump_height + 0.2
	var panel := TuningPanel.new()
	tree.root.add_child(panel)
	var sections: Array[Dictionary] = [{"title": "Movement", "resource": live, "path": path,
		"keep": PackedStringArray(["run_speed"])}]
	panel.setup(sections)
	panel._save()
	var saved := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as MovementTuning
	check(saved != null and is_equal_approx(saved.run_speed, tuning.run_speed)
		and is_equal_approx(saved.jump_height, tuning.jump_height + 0.2), "Save writes the rest and leaves the base run speed")
	panel.queue_free()
	await tree.process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
