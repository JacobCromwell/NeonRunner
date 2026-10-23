extends TestSuite
## The escape proof against many more Cybernetic Centipedes than test_centipede_maze's bot meets (task O3; the review's
## fuzz), each run on physics by CentipedeBot along the way out CentipedeEscape finds, the runner coming in from 25 m
## before the run-in with the dash just used as it reaches it (the proof's assumption). Over the Terminal's levels at
## 3, 5 and 6 lanes, each level's own seed and others, every maze block from the feature's start:
## - the levels' own placements at the other seeds (test_centipede_maze runs each level's own seed's);
## - every spot its rules may offer a centipede (centipede_rules.gd: candidates_for, kept off pads as the rules keep
##   them), alone, and every pair of those spaced as the rules space two, wherever the way out wakes it (both, for a
##   pair): the levels' own ways mostly slip past their centipedes asleep.
## Every run: out alive and never bitten, every move made, never refused a switch; no centipede wakes before the runner
## is in the block, moves before its wake and wake_time, faster than its chase speed, into debris or out of its block;
## the runner stays out of every awake one's bound by the bot's own field. And the woken spots' live centipedes mostly
## wake on those ways (the proof wakes them as early as the runner might, with the way's smashes open from the start, so
## not every one does). Slow (a few minutes): the full tier's, and the gate's when the centipede's files change.

const RulesScript = preload("res://scripts/enemies/centipede_rules.gd")
const LEVELS: Array[String] = ["terminal/1", "terminal/2"]
const LANES: Array[int] = [3, 5, 6]
## Seeds besides each level's own.
const OTHER_SEEDS: Array[int] = [9311, 9312, 9313]
## The spots' lanes and places in their cells are drawn from this seed (each build's on top).
const SPOT_SEED: int = 4242
## At least this many ways that wake a centipede, alone and in pairs, and blocks of the levels' own: the sweep's reach
## (90, 33 and 71 when the proof took the dash as just used at the run-in).
const MIN_SINGLES: int = 40
const MIN_PAIRS: int = 10
const MIN_OWN: int = 40

var sim: RunSim
var campaign: Campaign


func run() -> void:
	sim = RunSim.new(tree, tuning)
	campaign = load("res://data/campaign/campaign.tres") as Campaign
	var spacing: float = RulesScript.tuning().min_spacing
	var jobs: Array[Dictionary] = []
	var counts := {"own": 0, "spots": 0, "ways": 0, "one": 0, "two": 0}
	for id: String in LEVELS:
		for lanes: int in LANES:
			for k: int in OTHER_SEEDS.size() + 1:
				var config: LevelConfig = campaign.configure(campaign.step(id), lanes)
				if k > 0:
					config.level_seed = OTHER_SEEDS[k - 1]
				var gen: LevelGenerator = LayoutCache.generator(config, tuning, LevelGenerator.load_for(config))
				var layout: LevelLayout = gen.layout
				var mt: MovementTuning = config.movement_for(tuning)
				var start: float = gen.feature_start("centipede")
				var rng := RandomNumberGenerator.new()
				rng.seed = SPOT_SEED + config.level_seed * 7 + lanes
				var build: String = "%s lanes=%d seed=%d" % [id, lanes, config.level_seed]
				var own: Dictionary = {}
				for e: Dictionary in layout.enemies:
					# A free one (item 1202) has no escape proof to test: left out.
					if String(e["type"]) == RulesScript.FEATURE and not RulesScript.is_free(e):
						var at_block: int = int(e["params"]["block"])
						if not own.has(at_block):
							own[at_block] = []
						(own[at_block] as Array).append(RulesScript.spot_of(layout, e))
				for i: int in layout.maze.size():
					if float(layout.maze[i]["end"]) <= start:
						continue
					var ctx: CentipedeEscape.Context = CentipedeEscape.context(layout, mt, i)
					if k > 0 and own.has(i):
						var way: Dictionary = ctx.find(own[i])
						check(bool(way["ok"]), "the proof finds a way out past the level's own (%s) (%s block %d)"
							% [way["reason"], build, i])
						if bool(way["ok"]):
							counts["own"] = int(counts["own"]) + 1
							jobs.append({"kind": "own", "layout": layout, "mt": mt, "i": i, "spots": own[i], "way": way,
								"tag": "(%s block %d, the level's own %s)" % [build, i, JSON.stringify(own[i])]})
					var woken: Array[Dictionary] = []
					for c: Dictionary in RulesScript.candidates_for(gen, ctx, start, rng):
						var spot := {"lane": int(c["lane"]), "at": float(c["at"])}
						if not gen.zones.enemy_clear(layout, _entry(i, spot)):
							continue
						counts["spots"] = int(counts["spots"]) + 1
						var way: Dictionary = ctx.find([spot])
						if not bool(way["ok"]):
							continue
						counts["ways"] = int(counts["ways"]) + 1
						if (way["wakes"] as PackedFloat64Array)[0] == INF:
							continue
						counts["one"] = int(counts["one"]) + 1
						woken.append(spot)
						jobs.append({"kind": "one", "layout": layout, "mt": mt, "i": i, "spots": [spot], "way": way,
							"tag": "(%s block %d, one at %d/%.1f, %s)" % [build, i, spot["lane"], spot["at"], c["situation"]]})
					# Pairs of this block's woken ones, spaced as the rules space two.
					for a: int in woken.size():
						for b: int in range(a + 1, woken.size()):
							if absf(float(woken[a]["at"]) - float(woken[b]["at"])) < spacing:
								continue
							var pair: Array = [woken[a], woken[b]]
							var way: Dictionary = ctx.find(pair)
							if not bool(way["ok"]):
								continue
							var wakes: PackedFloat64Array = way["wakes"]
							if wakes[0] == INF or wakes[1] == INF:
								continue
							counts["two"] = int(counts["two"]) + 1
							jobs.append({"kind": "two", "layout": layout, "mt": mt, "i": i, "spots": pair, "way": way,
								"tag": "(%s block %d, two at %d/%.1f and %d/%.1f)" % [build, i, pair[0]["lane"], pair[0]["at"],
									pair[1]["lane"], pair[1]["at"]]})
	check(int(counts["one"]) >= MIN_SINGLES and int(counts["two"]) >= MIN_PAIRS and int(counts["own"]) >= MIN_OWN,
		"the sweep finds ways to run: %d blocks of the levels' own; %d spots, %d with a way out, %d of those waking it, %d pairs waking both"
		% [counts["own"], counts["spots"], counts["ways"], counts["one"], counts["two"]])
	var runs: int = 0
	var bad: int = 0
	var woken_runs: int = 0
	var fuzz_runs: int = 0
	var woke: int = 0
	var least: float = INF
	var least_tag: String = ""
	for job: Dictionary in jobs:
		var layout: LevelLayout = (job["layout"] as LevelLayout).copy()
		var i: int = job["i"]
		var enemies: Array[Dictionary] = []
		for spot: Dictionary in job["spots"]:
			enemies.append(_entry(i, spot))
		layout.enemies = enemies
		var r: Dictionary = await CentipedeBot.new(sim, job["mt"]).run(layout, i, job["way"])
		runs += 1
		woke += int(r["woke"])
		if String(job["kind"]) != "own":
			fuzz_runs += 1
			if int(r["woke"]) > 0:
				woken_runs += 1
		if float(r["margin"]) < least:
			least = float(r["margin"])
			least_tag = job["tag"]
		var ok: bool = r["alive"] and r["reached"] and int(r["bites"]) == 0 and int(r["moves_left"]) == 0 \
			and int(r["blocked"]) == 0 and int(r["before_run_in"]) == 0 \
			and int(r["early"]) == 0 and float(r["fast"]) <= 0.001 and int(r["in_debris"]) == 0 and int(r["outside"]) == 0 \
			and float(r["margin"]) > 0.0
		if not ok:
			bad += 1
		check(ok, ("the bot runs the way out past the live centipedes alive and unbitten, every move made, never refused, "
			+ "the proof's rules kept and the runner out of their bound (%s: alive %s, out %s, %d bites, %d moves left, "
			+ "%d refused, woke %d, before the run-in %d, early %d, over their speed %.4f m, in debris %d, out of the block %d, "
			+ "%.2f m to spare) %s") % [r["cause"], r["alive"], r["reached"], r["bites"], r["moves_left"], r["blocked"],
				r["woke"], r["before_run_in"], r["early"], r["fast"], r["in_debris"], r["outside"], r["margin"], job["tag"]])
	check(woken_runs * 2 > fuzz_runs and woken_runs >= MIN_SINGLES,
		"the woken spots' live centipedes mostly wake on those ways (in %d of %d runs)" % [woken_runs, fuzz_runs])
	print("  centipede fuzz: %d blocks of the levels' own; %d spots, %d with a way out, %d waking it, %d pairs waking both; %d bot runs (%d of the spots' woke one, %d woke in all), %d bad; %.2f m to spare at the least %s"
		% [counts["own"], counts["spots"], counts["ways"], counts["one"], counts["two"], runs, woken_runs, woke, bad, least,
			least_tag])


## A centipede's layout entry at `spot` ({lane, at}) in block `index`, as the rules make one.
func _entry(index: int, spot: Dictionary) -> Dictionary:
	# A level's own ambush (task O5) stays one: hidden in its debris until it breaks out.
	if bool(spot.get("ambush", false)):
		return RulesScript.ambush_entry(index, spot)
	var at: float = float(spot["at"])
	return {"type": RulesScript.FEATURE, "at": at, "lane": int(spot["lane"]), "side": 0, "seed": 7, "params": {
		"block": index, "situation": "fuzz",
		"floor_span": Vector2(at - RulesScript.FLOOR_BEFORE, at + Centipede.BODY_LENGTH + RulesScript.FLOOR_AFTER)}}
