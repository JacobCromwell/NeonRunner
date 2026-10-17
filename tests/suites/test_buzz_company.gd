extends TestSuite
## Company for the Buzz Overdrive (task L2; the owner, October 17, 2026, docs/USER_REQUESTS.md: other enemies and track
## hazards on the playfield with it, but where an Enforcer Truck is likely on the map with it; BuzzCompanyPlacement,
## BuzzCompanyTuning, data/tuning/buzz_company.tres):
## - its data: the tuning, and the levels that ask for it (every campaign level with the Buzz Overdrive, no other);
## - the campaign: every level with it at 3, 5 and 6 lanes on its own seed and two others builds with no warning and
##   passes every layout check (LayoutChecks: check_cuts' floor route out of a cut's lane from its warning,
##   check_buzz_company's rules, the wall fences' drop rule and the rest); the pass gives company to exactly the tanks
##   company_problem allows (not near an Enforcer Truck's chase, not the level's introduction), and nearly all of
##   those get some (rows, cyborgs or wall fences in their visit); their visits carry more than without it, and on
##   each level's own seed everything the passes before it place is the same with it as without it;
## - quick play with every feature (the fill pass, doodads, the danger density pass and wall fences too) at 3, 5 and 6
##   lanes with company: the same checks, and every kind of company comes;
## - its rules on a plain track: the escape lane and what keeps one, the tanks that get none, the lanes a row may take
##   (never the cut's, never the escape lane in the attack, holes only where GDD §9.9's whole lanes allow);
## - on real physics: a runner in a company tank's lane who leaves into its escape lane a reaction after its warning
##   is never touched while its cut runs, at 3, 5 and 6 lanes, and its company cyborgs charge no burst and land no bolt
##   while the runner is in their hold.

const Rules = preload("res://scripts/enemies/buzz_overdrive_rules.gd")
const TruckRules = preload("res://scripts/enemies/enforcer_truck_rules.gd")
const Measure = preload("res://tools/measure/buzz_company.gd")
const LEVELS: Array[String] = ["corporate/1", "corporate/2", "beach/1", "beach/3", "dead_zone/1", "dead_zone/2",
	"golden/1", "golden/2", "golden/3"]
const SEEDS: Array[int] = [-1, 9001, 9002]
const EVERY: PackedStringArray = ["ramps", "ceilings", "pulsing", "speed_pads", "cyborg", "window_cyborg",
	"hover_truck", "octodog", "screech", "drone", "generator", "host", "resonator", "barnacle_turret", "buzz_overdrive",
	"wall_fences", "wall_fences_partial"]

var sim: RunSim
var campaign: Campaign
var t: BuzzCompanyTuning
## Company tanks found in the campaign sweep for the physics runs: [{config, layout, cut}].
var _encounters: Array[Dictionary] = []


func run() -> void:
	sim = RunSim.new(tree, tuning)
	campaign = load("res://data/campaign/campaign.tres") as Campaign
	t = BuzzCompanyPlacement.tuning()
	_test_data()
	_test_rules()
	_test_campaign()
	_test_quick_play()
	await _test_physics()


# --- Data ----------------------------------------------------------------------------------------------------------

func _test_data() -> void:
	check(t.resource_path == BuzzCompanyTuning.PATH and t.enabled,
		"the company's numbers load from data/tuning/buzz_company.tres")
	check(t.rows_max > 0 and t.cyborgs_max > 0 and t.hold_before_seconds > 0.0 and t.hold_after_seconds > 0.0
		and not t.on_introduction,
		"it adds rows and cyborgs, holds their fire around the attack, and leaves the introduction alone")
	for s: CampaignStep in campaign.steps():
		if s.is_level():
			check(s.level.buzz_company == s.level.has_feature(Rules.TYPE),
				"%s %s company for the Buzz Overdrive" % [s.id, "asks for" if s.level.buzz_company else "doesn't ask for"])
	check(not (load(LEVEL_PATH) as LevelConfig).buzz_company, "quick play's level asks for none (built as before)")


# --- Rules on a plain track ----------------------------------------------------------------------------------------

## A plain track of `lanes` lanes holding a Buzz Overdrive's cut in `lane` that sets off at 300 m, at 23.4 m/s.
func _plain(lanes: int, lane: int) -> Dictionary:
	var config := LevelConfig.new()
	config.lane_count = lanes
	config.run_speed = 23.4
	config.buzz_company = true
	config.features = PackedStringArray(["cyborg", Rules.TYPE])
	var m: MovementTuning = config.movement_for(tuning)
	var cut: Dictionary = Rules.plan_for(Rules.tuning(), lane, 300.0, m.run_speed, m.pace(), 0.7)
	var layout := RunSim.layout(lanes, float(cut["end"]) + 600.0)
	layout.cuts.append(cut)
	var tank := {"type": Rules.TYPE, "at": float(cut["end"]), "lane": lane, "side": 0, "seed": 11, "params": {}}
	layout.enemies.append(tank)
	var gen: LevelGenerator = LevelGenerator.for_layout(config, tuning, layout)
	return {"gen": gen, "cut": cut, "tank": tank, "layout": layout, "config": config}


func _test_rules() -> void:
	# The escape lane: a neighbour of the cut's lane holding nothing over the attack.
	var p: Dictionary = _plain(5, 2)
	var gen: LevelGenerator = p["gen"]
	var cut: Dictionary = p["cut"]
	var attack: Vector2 = BuzzCompanyPlacement.attack_of(gen, t, cut)
	check(is_equal_approx(attack.x, FloorCutPlan.warn_at(cut) - t.attack_margin_seconds * gen.speed)
		and is_equal_approx(attack.y, FloorCutPlan.window(cut, gen.speed).y), "its attack runs from just before its warning to its window's end")
	check(BuzzCompanyPlacement.stretch_of(gen, t, cut).x == FloorCutPlan.lead_at(cut), "its company comes from where it sets off")
	check(BuzzCompanyPlacement.lane_clear(gen, 1, attack, p["tank"]) and BuzzCompanyPlacement.lane_clear(gen, 3, attack, p["tank"]),
		"on a plain track both lanes beside it are clear to escape into")
	(p["layout"] as LevelLayout).fences.append({"lane": 1, "at": (attack.x + attack.y) * 0.5, "variant": "full",
		"pulsing": false, "pulse_on": 1.2, "pulse_off": 1.0, "phase": 0.0})
	(p["layout"] as LevelLayout).enemies.append({"type": "cyborg", "at": attack.y + 5.0, "lane": 3, "side": 0, "seed": 1,
		"params": {}})
	check(not BuzzCompanyPlacement.lane_clear(gen, 1, attack, p["tank"]), "a fence in the attack takes a lane out of the escape")
	check(not BuzzCompanyPlacement.lane_clear(gen, 3, attack, p["tank"]), "and so does a floor enemy whose floor reaches it")
	# The tanks that get none.
	var q: Dictionary = _plain(3, 1)
	var qgen: LevelGenerator = q["gen"]
	var qcut: Dictionary = q["cut"]
	check(BuzzCompanyPlacement.company_problem(qgen, t, qcut, true) == "", "a level's tank gets company (%s)" %
		BuzzCompanyPlacement.company_problem(qgen, t, qcut, true))
	var bare: Dictionary = qcut.duplicate()
	bare.erase("lead")
	check(BuzzCompanyPlacement.company_problem(qgen, t, bare, false) != "", "a boss's tank (no lead) gets none")
	var ages: Dictionary[String, int] = {Rules.TYPE: 0}
	(q["config"] as LevelConfig).feature_ages = ages
	check(BuzzCompanyPlacement.company_problem(qgen, t, qcut, true) == "the level's introduction"
		and BuzzCompanyPlacement.company_problem(qgen, t, qcut, false) == "",
		"the level that introduces it meets its first one alone, the later ones with company")
	var none: Dictionary[String, int] = {}
	(q["config"] as LevelConfig).feature_ages = none
	var visit: Vector2 = BuzzCompanyPlacement.visit_of(qgen, qcut)
	var tt: EnforcerTruckTuning = TruckRules.tuning()
	var chase_len: float = (tt.chase_seconds + tt.leave_seconds) * qgen.speed
	(q["layout"] as LevelLayout).enemies.append({"type": "enforcer_truck", "at": visit.x - chase_len - 0.5 * t.truck_margin_seconds
		* qgen.speed, "lane": 1, "side": 0, "seed": 2, "params": {}})
	check(BuzzCompanyPlacement.company_problem(qgen, t, qcut, false) == "an Enforcer Truck about",
		"where an Enforcer Truck's chase comes within the margin of its visit, it keeps it sparse")
	# The lanes a row may take.
	var r3: Dictionary = _plain(3, 0)
	_rows_check(r3, 1, "3 lanes, its lane 0, escaping into lane 1")
	var r5: Dictionary = _plain(5, 2)
	_rows_check(r5, 1, "5 lanes, its lane 2, escaping into lane 1")
	var r6: Dictionary = _plain(6, 5)
	_rows_check(r6, 4, "6 lanes, its lane 5, escaping into lane 4")


## The lanes rows may take beside plain track `p`'s cut with escape lane `escape` (BuzzCompanyPlacement._row_lanes).
func _rows_check(p: Dictionary, escape: int, tag: String) -> void:
	var gen: LevelGenerator = p["gen"]
	var cut: Dictionary = p["cut"]
	var n: int = gen.layout.lane_count
	var lane: int = int(cut["lane"])
	var attack: Vector2 = BuzzCompanyPlacement.attack_of(gen, t, cut)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var mid: float = (attack.x + attack.y) * 0.5
	var roll: float = (FloorCutPlan.lead_at(cut) + attack.x) * 0.5
	var fence_all := {"kind": "fence", "variant": "full", "mode": "all", "width": n, "span": Vector2(mid - 0.3, mid + 0.3)}
	var lanes: Array[int] = BuzzCompanyPlacement._row_lanes(gen, rng, cut, attack, escape, fence_all)
	check(not lanes.has(lane) and not lanes.has(escape) and lanes.size() == n - 2,
		"(%s) a full row of fences in its attack takes every lane but its own and the escape lane: %s" % [tag, lanes])
	var fence_roll := fence_all.duplicate()
	fence_roll["span"] = Vector2(roll - 0.3, roll + 0.3)
	lanes = BuzzCompanyPlacement._row_lanes(gen, rng, cut, attack, escape, fence_roll)
	check(not lanes.has(lane) and lanes.size() == n - 1, "(%s) before its attack, every lane but its own: %s" % [tag, lanes])
	var holes := {"kind": "gap", "variant": "", "mode": "all", "width": n, "span": Vector2(mid, mid + 5.0)}
	lanes = BuzzCompanyPlacement._row_lanes(gen, rng, cut, attack, escape, holes)
	var budget: int = n - 1 - gen.whole_lanes_for_cut(n)
	var beside: bool = false
	for l: int in lanes:
		beside = beside or absi(l - lane) == 1
	check(lanes.size() <= budget and not beside and not lanes.has(lane) and not lanes.has(escape),
		"(%s) holes in its attack only where GDD §9.9's whole lanes allow (at most %d lanes, never beside it): %s" % [tag,
		budget, lanes])
	check(BuzzCompanyPlacement._row_lanes(gen, rng, cut, attack, -1, fence_all).is_empty(),
		"(%s) without an escape lane nothing goes in its attack" % tag)


# --- The campaign --------------------------------------------------------------------------------------------------

func _test_campaign() -> void:
	var company: int = 0
	var with_some: int = 0
	var rows: int = 0
	var cyborgs: int = 0
	var fenced: int = 0
	var rate_on := Vector2.ZERO
	var rate_off := Vector2.ZERO
	var skipped: Dictionary = {}
	for id: String in LEVELS:
		var step: CampaignStep = campaign.step(id)
		for lanes: int in [3, 5, 6]:
			for s: int in SEEDS:
				var config: LevelConfig = campaign.configure(step, lanes)
				if s >= 0:
					config.level_seed = s
				var m: MovementTuning = config.movement_for(tuning)
				var patterns: Array = LevelGenerator.load_for(config)
				var tag: String = "(%s, %d lanes, seed %d)" % [id, lanes, config.level_seed]
				# The level's own seed is its default build, shared with the other suites (LayoutCache).
				var gen: LevelGenerator = LayoutCache.generator(config, m, patterns) if s < 0 else LevelGenerator.new()
				var layout: LevelLayout = gen.layout if s < 0 else gen.generate(config, m, patterns)
				check(gen.warnings.is_empty(), "no warnings %s %s" % [tag, gen.warnings])
				LayoutChecks.check_layout(self, layout, config, tag)
				LayoutChecks.check_rules(self, layout, config, tag)
				var report: Dictionary = gen.buzz_company_result
				var tanks: Array[Dictionary] = Rules.tanks_in(layout)
				var marked: int = 0
				for i: int in tanks.size():
					var cut: Dictionary = Rules.cut_of(layout, tanks[i])
					var why: String = BuzzCompanyPlacement.company_problem(gen, t, cut, i == 0)
					check(cut.has(BuzzCompanyPlacement.CUT_KEY) == (why == ""),
						"company exactly where it may come (the tank at %.0f: '%s') %s" % [float(tanks[i]["at"]), why, tag])
					if why != "":
						skipped[why] = int(skipped.get(why, 0)) + 1
						continue
					marked += 1
					company += 1
					var pieces: int = BuzzCompanyPlacement.pieces_of(layout, cut).size()
					var mates: int = BuzzCompanyPlacement.cyborgs_of(layout, cut).size()
					var visit: Vector2 = BuzzCompanyPlacement.visit_of(gen, cut)
					var wall: bool = layout.wall_fence_between(visit.x, visit.y)
					rows += pieces
					cyborgs += mates
					fenced += 1 if wall else 0
					if pieces + mates > 0 or wall:
						with_some += 1
					if s < 0:
						_encounters.append({"config": config, "layout": layout, "cut": cut, "movement": m})
				check(report.is_empty() or (report["tanks"] as Array).size() == marked,
					"its report lists every tank with company %s" % tag)
				if s >= 0 or marked == 0:
					continue
				# With it and without it, on the level's own seed: what the passes before it place is the same.
				var off_config: LevelConfig = config.duplicate() as LevelConfig
				off_config.buzz_company = false
				var off_gen := LevelGenerator.new()
				var off: LevelLayout = off_gen.generate(off_config, m, patterns)
				check(JSON.stringify(_before_company(layout)) == JSON.stringify(_before_company(off))
					and JSON.stringify(gen.picks) == JSON.stringify(off_gen.picks) and JSON.stringify(gen.fills) == JSON.stringify(off_gen.fills)
					and gen.attempts == off_gen.attempts, "everything the passes before it place is the same without it %s" % tag)
				# The company tanks' visits, with it and without it.
				var on_m: Dictionary = Measure.measure(gen, layout, config)
				var off_m: Dictionary = Measure.measure(off_gen, off, off_config)
				for j: int in (on_m["tanks"] as Array).size():
					var tank_on: Dictionary = on_m["tanks"][j]
					if not bool(tank_on["company"]) or j >= (off_m["tanks"] as Array).size():
						continue
					var tank_off: Dictionary = off_m["tanks"][j]
					rate_on += Vector2(float(tank_on["visit"]["threats"]), float(tank_on["visit_s"]))
					rate_off += Vector2(float(tank_off["visit"]["threats"]), float(tank_off["visit_s"]))
	print("  company: %d tanks (%d with some: %d pieces, %d cyborgs, %d with a wall fence); none for %s; threats a second in their visits on the levels' own seeds %.2f against %.2f without it" % [
		company, with_some, rows, cyborgs, fenced, skipped, rate_on.x / maxf(rate_on.y, 0.001), rate_off.x / maxf(rate_off.y, 0.001)])
	check(company > 0 and with_some >= roundi(company * 0.75), "most tanks with company get some (%d of %d)" % [with_some, company])
	check(rows > 0 and cyborgs > 0 and fenced > 0, "rows, cyborgs and wall fences all keep it company")
	check(rate_on.y > 0.0 and rate_on.x / rate_on.y >= 1.5 * rate_off.x / maxf(rate_off.y, 0.001),
		"its visits carry half as many threats again as without it, at least (%.2f against %.2f a second)" % [
		rate_on.x / maxf(rate_on.y, 0.001), rate_off.x / maxf(rate_off.y, 0.001)])


## What the passes before the company pass place in `layout`, without its company (and the passes after it: the wall
## fences, which run by a tank with company, the wall gaps, which keep off them, and the credits).
static func _before_company(layout: LevelLayout) -> Dictionary:
	var d: Dictionary = layout.to_dict().duplicate(true)
	for key: String in ["wall_fences", "wall_gaps", "credits"]:
		d.erase(key)
	for key: String in ["gaps", "fences"]:
		var kept: Array = []
		for piece: Dictionary in d[key]:
			if not piece.has(BuzzCompanyPlacement.PARAM):
				kept.append(piece)
		d[key] = kept
	var enemies: Array = []
	for e: Dictionary in d["enemies"]:
		if not BuzzCompanyPlacement.is_company(e):
			enemies.append(e)
	d["enemies"] = enemies
	if d.has("cuts"):
		for c: Dictionary in d["cuts"]:
			c.erase(BuzzCompanyPlacement.CUT_KEY)
	return d


# --- Quick play ----------------------------------------------------------------------------------------------------

func _test_quick_play() -> void:
	var base := load(LEVEL_PATH) as LevelConfig
	var company: int = 0
	var pieces: int = 0
	var cyborgs: int = 0
	var fenced: int = 0
	for lanes: int in [3, 5, 6]:
		for level_seed: int in [1, 2, 3, 4]:
			var config: LevelConfig = base.duplicate() as LevelConfig
			config.lane_count = lanes
			config.level_seed = level_seed
			config.difficulty = 0.6
			config.enemy_scaling = 0.7
			config.features = EVERY
			config.fill_empty_seconds = 2.0
			config.doodad_share = 0.5
			config.run_speed = 24.2
			config.narrow_ceiling_share = 0.5
			config.danger_density_increase = 0.3
			config.buzz_company = true
			var tag: String = "(quick play with every feature and company, %d lanes, seed %d)" % [lanes, level_seed]
			var gen := LevelGenerator.new()
			var layout: LevelLayout = gen.generate(config, config.movement_for(tuning), LevelGenerator.load_for(config))
			check(gen.warnings.is_empty(), "no warnings %s %s" % [tag, gen.warnings])
			LayoutChecks.check_layout(self, layout, config, tag)
			LayoutChecks.check_rules(self, layout, config, tag)
			for c: Dictionary in layout.cuts:
				if not c.has(BuzzCompanyPlacement.CUT_KEY):
					continue
				company += 1
				pieces += BuzzCompanyPlacement.pieces_of(layout, c).size()
				cyborgs += BuzzCompanyPlacement.cyborgs_of(layout, c).size()
				var visit: Vector2 = BuzzCompanyPlacement.visit_of(gen, c)
				fenced += 1 if layout.wall_fence_between(visit.x, visit.y) else 0
	check(company > 0 and pieces > 0 and cyborgs > 0 and fenced > 0,
		"quick play's Buzz Overdrives get company of every kind among every other feature (%d tanks: %d pieces, %d cyborgs, %d by a wall fence)"
		% [company, pieces, cyborgs, fenced])


# --- Real physics --------------------------------------------------------------------------------------------------

## A runner in a company tank's lane from its company cyborgs' hold on leaves into its escape lane a reaction after
## its warning and runs on there to the end of its window, at every lane count the sweep found one at (its own seed),
## preferring ones with company cyborgs: never touched, its cut done beside them, and the company cyborgs charge no
## burst and land no bolt over their hold. The other enemies are left out (each keeps its own rules).
func _test_physics() -> void:
	var by_lanes: Dictionary = {}
	for enc: Dictionary in _encounters:
		var cut: Dictionary = enc["cut"]
		if int(cut[BuzzCompanyPlacement.CUT_KEY]) < 0:
			continue
		var lanes: int = (enc["layout"] as LevelLayout).lane_count
		var mates: int = BuzzCompanyPlacement.cyborgs_of(enc["layout"], cut).size()
		if not by_lanes.has(lanes) or mates > int(by_lanes[lanes]["mates"]):
			enc["mates"] = mates
			by_lanes[lanes] = enc
	check(by_lanes.size() >= 2, "the sweep finds company tanks with an escape lane at two lane counts or more (%s)" % [by_lanes.keys()])
	var with_mates: int = 0
	for lanes: int in by_lanes:
		var enc: Dictionary = by_lanes[lanes]
		var cut: Dictionary = enc["cut"]
		var m: MovementTuning = enc["movement"]
		var config: LevelConfig = enc["config"]
		var layout: LevelLayout = (enc["layout"] as LevelLayout).copy()
		var gen: LevelGenerator = LevelGenerator.for_layout(config, tuning, layout)
		var hold: Vector2 = BuzzCompanyPlacement.hold_of(gen, t, cut)
		var window_end: float = FloorCutPlan.window(cut, m.run_speed).y
		var kept: Array[Dictionary] = []
		for e: Dictionary in layout.enemies:
			var is_tank: bool = String(e["type"]) == Rules.TYPE and absf(float(e["at"]) - float(cut["end"])) < 0.01
			if is_tank or (BuzzCompanyPlacement.is_company(e) and absf(float(e["params"][BuzzCompanyPlacement.PARAM]) - float(cut["end"])) < 0.01):
				kept.append(e)
		layout.enemies.assign(kept)
		var lane: int = int(cut["lane"])
		var escape: int = int(cut[BuzzCompanyPlacement.CUT_KEY])
		var w: RunWorld = sim.build_world(layout, Loadout.new(), m, config)
		w.player.setup(m, w.geo, lane)
		w.player.distance = hold.x
		w.track.update(hold.x, 0.0)
		var events: Array[Array] = []
		w.director.enemy_spawned.connect(func(e: Enemy) -> void:
			if e is Cyborg and BuzzCompanyPlacement.is_company(e.spawn):
				events.append((e as Cyborg).gun.events))
		var react: float = FloorCutPlan.warn_at(cut) + config.cut_reaction_seconds * m.run_speed
		var move: StringName = &"move_right" if escape > lane else &"move_left"
		var r: Dictionary = await sim.step_world(w, (window_end - hold.x) / m.run_speed, [[react, move]])
		var tag: String = "(%s lanes, its lane %d, escaping into %d, %d company cyborgs)" % [lanes, lane, escape, int(enc["mates"])]
		check(bool(r["alive"]) and String(r["cause"]) == "" and not r["events"].has(&"armor_hit") and not r["events"].has(&"shield_break"),
			"a runner who leaves into its escape lane at the warning is never touched %s (%s)" % [tag, r["cause"]])
		var fc: FloorCut = w.track.floor_cut(lane, float(cut["end"]))
		check(fc != null and fc.done(), "its cut runs beside them %s" % tag)
		var held: bool = true
		for list: Array in events:
			for ev: Dictionary in list:
				if StringName(ev["event"]) == &"shot" and float(ev["impact"]) >= hold.x and float(ev["impact"]) <= hold.y:
					held = false
				if StringName(ev["event"]) == &"charge" and float(ev["player_d"]) >= hold.x and float(ev["player_d"]) <= hold.y:
					held = false
		with_mates += 1 if int(enc["mates"]) > 0 and not events.is_empty() else 0
		check(held, "its company cyborgs charge no burst and land no bolt while the runner is in %.0f-%.0f m %s" % [hold.x, hold.y, tag])
		await sim.free_world(w)
	check(with_mates > 0, "a physics run has company cyborgs in play (%d)" % with_mates)
