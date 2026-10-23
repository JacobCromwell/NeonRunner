extends TestSuite
## Where the Cybernetic Centipede waits, and the proof that every maze stays escapable past it (task O3; GDD §9.15: it
## "haunts the debris maze, waiting in the open sections between the debris", "trapped behind debris", "in the only way
## through", and "the player is strongly encouraged to run from it"). Its behaviour on its own is test_centipede's.
## - Its rules (centipede_rules.gd) over the Terminal's levels at 3, 5 and 6 lanes, each level's own seed and others: no
##   warnings, every build passing LayoutChecks.check_layout (check_centipedes: each in the maze block it names from the
##   feature's start, in an open cell, placed as walled in exactly when its cell is, at most two a block and spaced, its
##   block escapable past them), the same placements every attempt, centipedes in every build, GDD §9.15's three places
##   all over the sweep at 5 and 6 lanes (walled in, in the block's quickest way, near it), and most builds meeting their
##   first centipede in the feature's first block (its introduction; a block with no spot that keeps it escapable passes
##   it on).
## - The proof (CentipedeEscape) on hand-made blocks (MazeKit): a way past one in a cell on the other side of a divider,
##   none past one in an open room every way crosses, a walled-in one never woken on the way out; and its bound
##   (run_reach) from a standstill.
## - Its maze model (CentipedeMaze) against the maze's own (DebrisMaze) on every block of a sweep: the floor its head can
##   reach (reach, over the open grid) and the proof's field (over the free grid) lie in its section's open group, and
##   the floor it reaches covers every section of that group.
## - Endless mode's 20-minute copy of Last Stop on arbitrary seeds: no warnings, centipedes all along it, every rule kept.
## - A level without the feature has none.
## - The bot on real physics (CentipedeBot): a hand-made block whose way out wakes its centipede, and every block with
##   centipedes of each Terminal level (its own seed) at 3, 5 and 6 lanes, run by the way the proof found past its live
##   centipedes, the runner coming in from 25 m before the run-in, the dash at its slowest recharge and just used as it
##   reaches the run-in (the proof's assumption): out alive and never bitten, every move made, never refused a switch;
##   the live centipedes keep what the proof rests on (none wakes before the runner is in the block, none moves before
##   its wake and wake_time, nor faster than its chase speed, nor into debris, nor out of its block), and the runner stays
##   out of every awake one's bound by a field of the bot's own. (The levels' ways mostly slip past their centipedes
##   asleep; test_centipede_fuzz runs the other seeds' blocks, and ways that wake them.) Each level's escape block (task
##   O5), with its centipedes or none, is run too: its way out takes no dash at its barrier and rides its pad's ceiling
##   over it on physics.
## - The first-encounter hint (data/hints/hints.json, trigger enemy:centipede): it says it chases and bites, that the dash
##   goes through it and two kill it, and is picked for Rubble Line, not for a level without one.

## Seeds besides each level's own the generator sweep builds.
const CentipedeRulesScript = preload("res://scripts/enemies/centipede_rules.gd")
const OTHER_SEEDS: Array[int] = [9311, 9312, 9313]
const LEVELS: Array[String] = ["terminal/1", "terminal/2"]
const LANES: Array[int] = [3, 5, 6]

var sim: RunSim
var campaign: Campaign


func run() -> void:
	sim = RunSim.new(tree, tuning)
	campaign = load("res://data/campaign/campaign.tres") as Campaign
	_test_generator()
	_test_proof()
	_test_endless()
	_test_without_feature()
	await _test_bot()
	_test_hint()


## Every centipede entry of `layout`.
func _centipedes(layout: LevelLayout) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in layout.enemies:
		if String(e["type"]) == "centipede":
			out.append(e)
	return out


# --- Its rules ---------------------------------------------------------------------------------------

func _test_generator() -> void:
	var places: Dictionary = {}
	var counts: Array[String] = []
	var blocks_with: int = 0
	var blocks: int = 0
	var intro_first: int = 0
	var builds: int = 0
	for id: String in LEVELS:
		var step: CampaignStep = campaign.step(id)
		for lanes: int in LANES:
			for k: int in OTHER_SEEDS.size() + 1:
				var config: LevelConfig = campaign.configure(step, lanes)
				if k > 0:
					config.level_seed = OTHER_SEEDS[k - 1]
				var tag: String = "(%s lanes=%d seed=%d)" % [id, lanes, config.level_seed]
				var patterns: Array = LevelGenerator.load_for(config)
				var gen: LevelGenerator = LayoutCache.generator(config, tuning, patterns)
				var layout: LevelLayout = gen.layout
				check(gen.warnings.is_empty(), "no warnings %s %s" % [tag, gen.warnings])
				LayoutChecks.check_layout(self, layout, config, tag)
				builds += 1
				var mine: Array[Dictionary] = _centipedes(layout)
				if k == 0:
					var again: LevelLayout = LevelGenerator.new().generate(config, tuning, patterns)
					check(JSON.stringify(_centipedes(again)) == JSON.stringify(mine), "the same centipedes every attempt " + tag)
				var used: Dictionary = {}
				for e: Dictionary in mine:
					var situation: String = String(e["params"]["situation"])
					if lanes >= 5:
						places[situation] = int(places.get(situation, 0)) + 1
					used[int(e["params"]["block"])] = true
				blocks_with += used.size()
				blocks += layout.maze.size()
				# Its introduction: the first block from the feature's start that any spot fits.
				var start: float = gen.feature_start("centipede")
				var first: int = -1
				for i: int in layout.maze.size():
					if float(layout.maze[i]["end"]) > start:
						first = i
						break
				var lowest: int = layout.maze.size()
				for i: int in used:
					lowest = mini(lowest, i)
				check(first >= 0 and lowest >= first, "no centipede before the feature's first block (%d, %d) %s" % [lowest, first, tag])
				if lowest == first:
					intro_first += 1
				counts.append("%s/%d/%d:%d" % [id.get_slice("/", 1), lanes, config.level_seed, mine.size()])
	check(int(places.get("near", 0)) > 0 and int(places.get("way", 0)) > 0 and int(places.get("trapped", 0)) > 0,
		"all three places over the sweep at 5 and 6 lanes: near the way, in it, walled in (%s)" % [places])
	check(intro_first * 4 >= builds * 3, "most levels meet their first centipede in the feature's first block (%d of %d)"
		% [intro_first, builds])
	print("  centipedes: %d of %d blocks; at 5 and 6 lanes %s; the first in the feature's first block in %d of %d builds; per build %s"
		% [blocks_with, blocks, places, intro_first, builds, " ".join(counts)])


# --- The proof ---------------------------------------------------------------------------------------

func _test_proof() -> void:
	# Its bound: from a standstill, speeding up, then at its top speed.
	check(is_zero_approx(CentipedeEscape.run_reach(0.0, 15.0, 30.0)) and is_equal_approx(CentipedeEscape.run_reach(0.2, 15.0, 30.0), 0.6)
		and is_equal_approx(CentipedeEscape.run_reach(1.5, 15.0, 30.0), 15.0 * 1.5 - 0.5 * 15.0 * 0.5),
		"a centipede's reach from a standstill: speeding up, then at its top speed")
	var mt: MovementTuning = tuning
	# A way past one in a dead-end cell on the far side of a divider: the runner takes the other side.
	var layout: LevelLayout = MazeKit.block(mt, 5, [[0, 4], [4]], [[2]], {"room": 40.0})
	var b: Dictionary = layout.maze[0]
	var at: float = float(b["rooms"][0]["start"]) + 18.0
	var found: Dictionary = CentipedeEscape.find(layout, mt, 0, [{"lane": 1, "at": at}])
	check(bool(found["ok"]) and int(found["start_lane"]) >= 3,
		"a way past one in a dead end across a divider: the other side (%s, lane %d)" % [found["reason"],
			int(found.get("start_lane", -1))])
	# None past one in an open room every way crosses.
	layout = MazeKit.block(mt, 3, [[1], [1]], [[]], {"room": 40.0})
	b = layout.maze[0]
	at = float(b["rooms"][0]["start"]) + 18.0
	found = CentipedeEscape.find(layout, mt, 0, [{"lane": 1, "at": at}])
	check(not bool(found["ok"]) and String(found["reason"]) != "",
		"no way past one in an open room every way crosses (%s)" % found["reason"])
	# A walled-in one, never woken on the way out.
	layout = MazeKit.block(mt, 5, [[4], [4]], [[3]], {"room": 40.0})
	b = layout.maze[0]
	at = float(b["rooms"][0]["start"]) + 18.0
	found = CentipedeEscape.find(layout, mt, 0, [{"lane": 1, "at": at}])
	check(bool(found["ok"]) and (found["wakes"] as PackedFloat64Array)[0] == INF,
		"past a walled-in one, which the way never wakes (%s, wakes %s)" % [found["reason"], found.get("wakes", [])])
	# Its maze model against the maze's own, over a sweep.
	for id: String in LEVELS:
		for lanes: int in LANES:
			var config: LevelConfig = campaign.configure(campaign.step(id), lanes)
			var level: LevelLayout = LayoutCache.generate(config, tuning, LevelGenerator.load_for(config))
			_check_model(level, config.movement_for(tuning), "(%s lanes=%d)" % [id, lanes])


## CentipedeMaze against DebrisMaze on every block of `layout` (see the header).
func _check_model(layout: LevelLayout, mt: MovementTuning, tag: String) -> void:
	var leaks: int = 0
	var misses: int = 0
	var cells: int = 0
	for i: int in layout.maze.size():
		var maze := CentipedeMaze.for_block(layout, i, mt)
		var bl: LevelLayout = maze.block_layout()
		var secs: Array[Dictionary] = DebrisMaze.sections(bl)
		var links: Array[Dictionary] = DebrisMaze.links(bl, secs)
		var b: Dictionary = layout.maze[i]
		var rooms: Array = b["rooms"]
		for r: int in rooms.size():
			for cell: Vector2i in DebrisMaze.cells_of(rooms[r]["dividers"], layout.lane_count):
				var id: int = DebrisMaze.section_id(secs, 0, r, cell.x)
				if id < 0:
					continue
				cells += 1
				var group: PackedInt32Array = DebrisMaze.open_group(links, id)
				var at: float = (float(rooms[r]["start"]) + float(rooms[r]["end"])) * 0.5
				var reached: PackedByteArray = maze.reach(cell.x, at)
				var field: PackedInt32Array = maze.field(cell.x, at)
				var seen: Dictionary = {}
				for lane: int in layout.lane_count:
					for k: int in maze.size:
						var cell_i: int = lane * maze.size + k
						var mine: bool = reached[cell_i] == 1
						if not mine and field[cell_i] >= CentipedeMaze.FAR:
							continue
						var z: float = maze.bin_middle(k)
						if z < float(b["entry"]) or z > float(b["exit"]):
							continue
						var s: int = _section_near(secs, lane, maze.bin_middle(k))
						if s == -2:
							continue
						if s < 0 or not group.has(s):
							leaks += 1
						elif mine:
							seen[s] = true
				for s: int in group:
					if not seen.has(s):
						misses += 1
	check(leaks == 0, "the floor a centipede's head reaches, and the proof's field, stay in its section's open group (%d bins out) %s"
		% [leaks, tag])
	check(misses == 0, "and the floor it reaches covers every section of that group (%d missed of %d cells' groups) %s"
		% [misses, cells, tag])


## The section holding `lane` at track distance `at`, looking a little either way along the track (a bin overlapping a
## wall's front or back), -2 inside a wall's opening (between two sections), else -1.
func _section_near(secs: Array[Dictionary], lane: int, at: float) -> int:
	var id: int = DebrisMaze.section_at(secs, lane, at)
	if id >= 0:
		return id
	var before: int = DebrisMaze.section_at(secs, lane, at - 0.6)
	var after: int = DebrisMaze.section_at(secs, lane, at + 0.6)
	if before >= 0:
		return before
	if after >= 0:
		return after
	return -2


# --- Endless mode, and a level without it --------------------------------------------------------------

func _test_endless() -> void:
	var zone := load("res://data/zones/terminal.tres") as ZoneDef
	for level_seed: int in [7310, 424242]:
		var config: LevelConfig = (zone.levels[zone.levels.size() - 1] as LevelConfig).duplicate() as LevelConfig
		# As App.start_endless makes it.
		config.id = &"endless"
		config.level_seed = level_seed
		config.lane_count = 5
		config.duration_seconds = App.ENDLESS_SECONDS
		config.difficulty = 0.2
		config.difficulty_ramp = 0.8
		config.enemy_scaling = 1.0
		var starts: Dictionary[String, float] = {}
		config.feature_starts = starts
		config.guarantee_features = false
		config.quiet_seconds = 0.0
		config.extended_wall_runs = []
		var features: PackedStringArray = config.features.duplicate()
		for f: String in config.features_left_out:
			if not features.has(f):
				features.append(f)
		config.features = features
		config.features_left_out = PackedStringArray()
		config.darkness = 0.0
		config.sky = null
		if config.run_speed <= 0.0:
			config.run_speed = zone.run_speed
		var tag: String = "(endless in the Terminal, seed %d)" % level_seed
		var gen := LevelGenerator.new()
		var layout: LevelLayout = gen.generate(config, tuning, LevelGenerator.load_for(config))
		check(gen.warnings.is_empty(), "no warnings %s %s" % [tag, gen.warnings])
		var mine: Array[Dictionary] = _centipedes(layout)
		var last: float = 0.0
		for e: Dictionary in mine:
			last = maxf(last, float(e["at"]))
		check(mine.size() >= 10 and last > layout.length * 0.7,
			"centipedes all along it (%d, the last at %.0f of %.0f m) %s" % [mine.size(), last, layout.length, tag])
		LayoutChecks.check_centipedes(self, layout, config, tag)


func _test_without_feature() -> void:
	for id: String in ["dead_zone/2", "golden/1"]:
		var config: LevelConfig = campaign.configure(campaign.step(id), 5)
		var layout: LevelLayout = LayoutCache.generate(config, tuning, LevelGenerator.load_for(config))
		check(_centipedes(layout).is_empty(), "%s has no centipede" % id)


# --- The bot on real physics ---------------------------------------------------------------------------

func _test_bot() -> void:
	# A hand-made block where the way out wakes one: a dead-end cell joined to the run-in, across a divider from the way.
	var made: LevelLayout = MazeKit.block(tuning, 5, [[0, 4], [4]], [[2]], {"room": 40.0})
	var spot := {"lane": 1, "at": float(made.maze[0]["rooms"][0]["start"]) + 18.0}
	made.enemies.append(MazeKit.centipede(float(spot["at"]), 1))
	var made_way: Dictionary = CentipedeEscape.find(made, tuning, 0, [spot])
	check(bool(made_way["ok"]) and (made_way["wakes"] as PackedFloat64Array)[0] < INF,
		"the hand-made block's way out wakes its centipede (%s, wakes %s)" % [made_way["reason"], made_way.get("wakes", [])])
	if bool(made_way["ok"]):
		var r: Dictionary = await CentipedeBot.new(sim, tuning).run(made, 0, made_way)
		check(r["alive"] and r["reached"] and int(r["bites"]) == 0 and int(r["woke"]) == 1 and int(r["before_run_in"]) == 0
			and int(r["early"]) == 0 and float(r["fast"]) <= 0.001 and int(r["in_debris"]) == 0 and float(r["margin"]) > 0.0,
			"the bot runs it past the woken centipede on physics, unbitten, out of its bound (%.2f m to spare) %s" % [r["margin"], r])
	var lines: PackedStringArray = []
	for id: String in LEVELS:
		for lanes: int in LANES:
			var config: LevelConfig = campaign.configure(campaign.step(id), lanes)
			var mt: MovementTuning = config.movement_for(tuning)
			var layout: LevelLayout = LayoutCache.generate(config, tuning, LevelGenerator.load_for(config))
			var by_block: Dictionary = {}
			for e: Dictionary in _centipedes(layout):
				var i: int = int(e["params"]["block"])
				if not by_block.has(i):
					by_block[i] = []
				(by_block[i] as Array).append(CentipedeRulesScript.spot_of(layout, e))
			var runs: int = 0
			var least: float = INF
			var woke: int = 0
			var escapes: int = 0
			# Every escape block too, with its centipedes or none: its way out is its pad (task O5).
			for i: int in layout.maze.size():
				if DebrisMaze.is_escape(layout.maze[i]) and not by_block.has(i):
					by_block[i] = []
			for i: int in by_block:
				var tag: String = "(%s lanes=%d block %d, %d centipedes)" % [id, lanes, i, (by_block[i] as Array).size()]
				var escape: bool = DebrisMaze.is_escape(layout.maze[i])
				var way: Dictionary = CentipedeEscape.find(layout, mt, i, by_block[i])
				check(bool(way["ok"]), "the proof finds a way out (%s) %s" % [way["reason"], tag])
				if not bool(way["ok"]):
					continue
				var bot := CentipedeBot.new(sim, mt)
				var r: Dictionary = await bot.run(layout, i, way)
				runs += 1
				woke += int(r["woke"])
				least = minf(least, float(r["margin"]))
				check(r["alive"] and r["reached"] and int(r["bites"]) == 0 and int(r["moves_left"]) == 0 and int(r["blocked"]) == 0,
					"the bot runs the way out alive and unbitten, every move made, never refused (%s, %d bites, %d moves left, %d refused) %s"
					% [r["cause"], r["bites"], r["moves_left"], r["blocked"], tag])
				check(int(r["before_run_in"]) == 0 and int(r["early"]) == 0 and float(r["fast"]) <= 0.001
					and int(r["in_debris"]) == 0 and int(r["outside"]) == 0,
					"the live centipedes keep what the proof rests on (woke before the run-in %d, moved early %d, over their speed %.4f m, in debris %d, out of their block %d) %s"
					% [r["before_run_in"], r["early"], r["fast"], r["in_debris"], r["outside"], tag])
				check(float(r["margin"]) > 0.0, "the runner stays out of every awake one's bound (%.2f m to spare) %s"
					% [r["margin"], tag])
				if escape:
					escapes += 1
					var barrier: int = (layout.maze[i]["walls"] as Array).size() - 1
					var through: bool = false
					for move: Dictionary in way["moves"]:
						through = through or (String(move["kind"]) == "dash" and float(move["at"]) >= float(layout.maze[i]["walls"][barrier]["start"]) - 1.0)
					check(not through and bool(r["ceiling"]),
						"an escape block's way out is its pad: no dash at its barrier, the runner rides the ceiling over it on physics (dash there %s, rode %s) %s"
						% [through, r["ceiling"], tag])
			check(escapes >= 1, "every Terminal level has an escape block (%s lanes=%d)" % [id, lanes])
			lines.append("%s at %d lanes: %d blocks run (%d escapes), %d woke, %.1f m to spare at the least" % [id, lanes, runs, escapes, woke, least])
	print("  the bot past live centipedes: %s" % "; ".join(lines))


# --- The hint ------------------------------------------------------------------------------------------

func _test_hint() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/hints/hints.json"))
	var hint: Dictionary = {}
	for h: Dictionary in (parsed as Dictionary).get("hints", []):
		if String(h.get("id", "")) == "centipede":
			hint = h
	var text: String = String(hint.get("text", "")).to_lower()
	check(String(hint.get("trigger", "")) == "enemy:centipede" and text.contains("chases") and text.contains("bite")
		and text.contains("{dash}") and text.contains("two") and text.contains("ceiling"),
		"the hint says it chases and bites, the dash goes through it, two kill it, and it can't follow onto a ceiling (%s)" % [hint])
	var config: LevelConfig = campaign.configure(campaign.step("terminal/1"), 5)
	var layout: LevelLayout = LayoutCache.generate(config, tuning, LevelGenerator.load_for(config))
	for with_it: bool in [true, false]:
		var world := RunWorld.new()
		world.config = config if with_it else LevelConfig.new()
		world.layout = layout if with_it else RunSim.layout(5)
		world.director = EnemyDirector.new()
		world.add_child(world.director)
		var director := HintDirector.new()
		director.setup(world, Profile.new(), false)
		var ids: Array = director.intro_hints.map(func(entry: Dictionary) -> String: return entry["id"])
		check(ids.has("centipede") == with_it, "the hint is picked %s (%s)" % ["for Rubble Line" if with_it else "only with one", ids])
		director.free()
		world.free()
