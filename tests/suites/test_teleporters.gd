extends TestSuite
## Teleporters (task Q4; GDD §5, Zone 9, the owner, October 21, 2026: "a square pad with a look all its own, with a green,
## slightly space-age antenna on it. Touching it teleports the runner to an output pad further down the track"; "the first
## teleporter is safe"; "some teleporters have a left and a right output pad. A light on the antenna, on its left or its
## right side, shows which one the runner lands on"; "others blink left and right, and the side lit when the runner touches
## the pad decides where they land"; and the proposals: never required, the runner keeps their speed and arrives running in
## the output pad's lane with a flash and a sound, skipping the track in between and whatever it holds, never a landing
## straight into a hazard).
## - The layout: a level without teleporters is the same data as before (no "teleporters" key); copy() carries its own copy
##   and append_pieces() renumbers them; a teleporter's calm stretches count as a doodad for the enemies' and the
##   generator's checks (LevelLayout.doodad_between): its approach in its lane, each landing in its output pad's lane, an
##   introduction's landing in every lane, nothing past them.
## - The generator (teleporter_rules.gd) over Relay Station and Specimen Vault at 3, 5 and 6 lanes: the level's count, where
##   the every-feature checks find them; Relay Station introduces them within intro_window_seconds of their start (one
##   output pad, straight ahead) and has a fixed light between two output pads, no blinking one; Specimen Vault its count
##   of blinking ones, the first introduced the same way from the blinking start, none before; every one fair
##   (LayoutChecks.check_teleporters); the same level on a second build; a level without the feature, with a count of 0, or
##   with the blinking feature but no blinking count, stands none (or no blinking one). A wall-run gap's stretch (with its
##   margins) lies outside everything a teleporter keeps, and its own re-check passes beside one as near as it may stand.
##   Endless mode in the Ice Lab builds without warnings, its count spread along the whole of it, each fair. (Every build's
##   fairness on more seeds: test_ice_lab_levels; quick play's level over seeds and difficulties: test_generator.)
## - The track: a Teleporter over each entry, its pad's trigger (a square on LAYER_TRIGGER, kind &"teleporter", carrying
##   its entry; nothing else of it collides), its output pads' nodes in their lanes, its antenna's lamps lit by the level
##   clock (the light's side; a one-output teleporter's beacon), and the light's rules: a fixed light stays, a blinking one
##   changes side every blink_seconds from its phase, the brighter lamp always the side a touch takes (Reduced flashing's
##   slower fade too).
## - On real physics at 3, 5 and 6 lanes, from every inner lane: a runner who runs onto the pad lands on its output pad (the
##   one lit, both ways, fixed and blinking: the side lit at the touch), in its lane, as far on as the pad leads, keeping
##   their speed, and runs on through the landing; one in the lane beside it, one who switches out at its approach and
##   one who jumps over it run past; the dash, a slide and the protection carry through it.
## - What it skips: the enemies behind the landing leave play (a heli drone's place comes along, one waiting there never
##   comes, the entries still to come there never spawn), those ahead stay, a cyborg's charge-up and a heli drone's wind-up
##   are called off, every shot in the air goes, the credits between are passed and the stars' best score leaves them out,
##   the track is built ahead of the landing at once, the camera cuts across and the flash shows (Reduced flashing: a soft
##   tint), the sound plays (the `teleport` event).
## - Every teleporter of the campaign at 3, 5 and 6 lanes, at the level's speed, on a cut of its level: run onto, the runner
##   lands on each output pad (its light set each way) and runs through the landing alive; the way around and a switch out
##   at its approach pass it alive.
## - Every skin dresses its pads flat inside their squares (their halo aside) and its antenna on the pad's far half, no wider
##   than the lane, with left, right and beacon lamps hidden until lit, and an output pad's marker floating over its square
##   above a runner's head, all glowing only green or green-white; the warm-up draws every part, nothing physical; every
##   number reaches the F6 panel.

const TeleporterRules := preload("res://scripts/enemies/teleporter_rules.gd")
const GantrywayRules := preload("res://scripts/enemies/gantryway_rules.gd")
const DroneScript := preload("res://scripts/enemies/drone.gd")
const DUMMY_SCRIPT: String = "res://tests/helpers/dummy_enemy.gd"
const CAMPAIGN_PATH: String = "res://data/campaign/campaign.tres"
const LANE_COUNTS: Array[int] = [3, 5, 6]
## The pad's front on the hand-built tracks (metres): past the run's start, where the runner is at full speed.
const PAD: float = 90.0
## Metres of bare track before a cut of a campaign level (_cut), where the runner gets going.
const RUN_IN: float = 30.0

var tt: TeleporterTuning
var pt: PowerupTuning


func run() -> void:
	tt = TeleporterTuning.load_default()
	pt = TeleporterRules.powerups()
	_test_layout()
	_test_generator()
	_test_wall_run_gaps()
	_test_gantryways()
	_test_endless()
	await _test_track()
	_test_light()
	await _test_physics()
	await _test_skipped()
	await _test_flash()
	await _test_campaign()
	_test_skins()
	_test_tuning()


# --- The layout ---------------------------------------------------------------------------------

func _test_layout() -> void:
	var bare := LevelLayout.new()
	check(not bare.to_dict().has("teleporters"), "a level without teleporters has no \"teleporters\" key")
	var lay: LevelLayout = _layout(5, 2, 1, [1, 3], -1)
	check(lay.to_dict().has("teleporters"), "a level with them lists them")
	var copy: LevelLayout = lay.copy()
	(copy.teleporters[0]["outputs"] as Array)[0]["lane"] = 4
	copy.teleporters[0]["light"] = 1
	check(int((lay.teleporters[0]["outputs"] as Array)[0]["lane"]) == 1 and int(lay.teleporters[0]["light"]) == -1
		and copy.teleporters.size() == 1, "copy() carries them, its own copy")
	var more: LevelLayout = _layout(5, 3, -1, [3])
	more.teleporters[0]["at"] = float(more.teleporters[0]["at"]) + 300.0
	var joined: LevelLayout = lay.copy()
	joined.append_pieces(more)
	check(joined.teleporters.size() == 2 and int(joined.teleporters[1]["id"]) == 1 and int(joined.teleporters[0]["id"]) == 0
		and joined.teleporter_by_id(1) == joined.teleporters[1], "append_pieces() renumbers the appended ones")
	var tp: Dictionary = lay.teleporters[0]
	var front: float = float(tp["at"])
	var land: float = float((tp["outputs"] as Array)[0]["at"])
	var calm: Array = tp["calm"]
	var approach: float = front - float((calm[0] as Array)[1])
	check(lay.doodad_between(front - approach * 0.5, front - 0.5, 2) and lay.doodad_between(front - 1.0, front, -1)
		and not lay.doodad_between(front - approach * 0.5, front - 0.5, 0) and not lay.doodad_between(front - approach * 0.5, front - 0.5, 1),
		"its approach counts as a doodad in its lane (and in any lane with -1), not in another lane")
	check(lay.doodad_between(land + 2.0, land + 3.0, 1) and lay.doodad_between(land + 2.0, land + 3.0, 3)
		and not lay.doodad_between(land + 2.0, land + 3.0, 2) and not lay.doodad_between(land + 2.0, land + 3.0, 0),
		"each landing counts as a doodad in its output pad's lane, not in another lane")
	var landing: float = float((calm[1] as Array)[2]) - land
	check(not lay.doodad_between(land + landing + 1.0, land + landing + 5.0, 1) and not lay.doodad_between(front + 5.0, land - 5.0, 2),
		"past its landings and between its pads, the lanes are free again")
	var intro: LevelLayout = _layout(5, 2, 1, [2], 0, 0.0, 0.0, true)
	var i_land: float = float((intro.teleporters[0]["outputs"] as Array)[0]["at"])
	check(intro.doodad_between(i_land + 2.0, i_land + 3.0, 0) and intro.doodad_between(i_land + 2.0, i_land + 3.0, 4),
		"an introduction's landing counts in every lane")


# --- The generator ------------------------------------------------------------------------------

func _test_generator() -> void:
	var campaign := load(CAMPAIGN_PATH) as Campaign
	var stood: int = 0
	var two: int = 0
	var blinking: int = 0
	for n: int in [2, 3]:
		var step: CampaignStep = campaign.step("ice_lab/%d" % n)
		for lanes: int in LANE_COUNTS:
			var config: LevelConfig = campaign.configure(step, lanes)
			var tag: String = "%s lanes=%d" % [step.id, lanes]
			var patterns: Array = LevelGenerator.load_for(config)
			var gen: LevelGenerator = LayoutCache.generator(config, tuning, patterns)
			var layout: LevelLayout = gen.layout
			check(gen.warnings.is_empty(), "no warnings %s %s" % [tag, gen.warnings])
			check(layout.teleporters.size() == config.teleporters, "%d of %d teleporters %s" % [layout.teleporters.size(),
				config.teleporters, tag])
			check(TeleporterRules.positions(layout) == LevelGenerator.feature_positions(layout, TeleporterRules.FEATURE)
				and TeleporterRules.positions_blinking(layout) == LevelGenerator.feature_positions(layout, TeleporterRules.BLINKING),
				"the every-feature checks find them at their pads " + tag)
			LayoutChecks.check_teleporters(self, layout, config, tag)
			var window: float = tt.intro_window_seconds * gen.speed
			var blinks: Array[Dictionary] = []
			var fixed_two: int = 0
			for tp: Dictionary in layout.teleporters:
				stood += 1
				var outs: int = (tp["outputs"] as Array).size()
				two += 1 if outs == 2 else 0
				if float(tp["blink"]) > 0.0:
					blinks.append(tp)
					blinking += 1
				elif outs == 2:
					fixed_two += 1
			if n == 2:
				var start: float = gen.feature_start(TeleporterRules.FEATURE)
				var first: Dictionary = layout.teleporters[0] if not layout.teleporters.is_empty() else {}
				check(not first.is_empty() and bool(first.get("intro", false)) and (first["outputs"] as Array).size() == 1
					and int((first["outputs"] as Array)[0]["lane"]) == int(first["lane"])
					and float(first["at"]) >= start - 0.01 and float(first["at"]) <= start + window + 0.01,
					"Relay Station introduces them within %.1f s of their start (%.0f m), one output pad straight ahead (%s) %s"
					% [tt.intro_window_seconds, start, first, tag])
				check(blinks.is_empty() and fixed_two >= 1,
					"Relay Station's antennas are fixed, one lighting a side between two output pads (%d) %s" % [fixed_two, tag])
			else:
				var b_start: float = gen.feature_start(TeleporterRules.BLINKING)
				check(blinks.size() == config.blinking_teleporters,
					"Specimen Vault blinks %d of them %s" % [config.blinking_teleporters, tag])
				var b_first: Dictionary = blinks[0] if not blinks.is_empty() else {}
				check(not b_first.is_empty() and bool(b_first.get("intro", false)) and float(b_first["at"]) >= b_start - 0.01
					and float(b_first["at"]) <= b_start + window + 0.01,
					"Specimen Vault introduces the blinking ones within %.1f s of their start (%.0f m) %s"
					% [tt.intro_window_seconds, b_start, tag])
				for tp: Dictionary in layout.teleporters:
					check(not bool(tp.get("intro", false)) or is_same(tp, b_first),
						"nothing but the blinking one's introduction is an introduction in Specimen Vault " + tag)
				check(fixed_two >= 1 or layout.teleporters.size() - blinks.size() <= 1,
					"Specimen Vault keeps fixed lights too " + tag)
			# The same level on a fresh build.
			var again: LevelLayout = LevelGenerator.new().generate(config, tuning, patterns)
			check(JSON.stringify(again.teleporters) == JSON.stringify(layout.teleporters), "the same teleporters every attempt " + tag)
	print("  teleporters in the Ice Lab's own builds: %d, %d with two output pads, %d blinking" % [stood, two, blinking])
	# A level without the feature, with a count of 0, or with blinking antennas but no count of them.
	var step_3: CampaignStep = campaign.step("ice_lab/3")
	for c: int in 3:
		var config: LevelConfig = campaign.configure(step_3, 5)
		config.guarantee_features = false
		if c == 0:
			var features := PackedStringArray(config.features)
			features.remove_at(features.find(TeleporterRules.FEATURE))
			config.features = features
		elif c == 1:
			config.teleporters = 0
		else:
			config.blinking_teleporters = 0
		var gen := LevelGenerator.new()
		var layout: LevelLayout = gen.generate(config, tuning, LevelGenerator.load_for(config))
		if c < 2:
			check(layout.teleporters.is_empty() and not layout.to_dict().has("teleporters"),
				"%s stands none" % ["a level without the feature", "a count of 0"][c])
		else:
			check(layout.teleporters.size() == config.teleporters and TeleporterRules.positions_blinking(layout).is_empty(),
				"a blinking count of 0 stands every teleporter with a fixed light")


## A wall-run gap (its rules run before the teleporters') keeps every rule's keep-outs off its stretch in every lane
## (WallRunGapPlacement.problem): so every grid spot whose pad stretch or a landing, with the plan's margin
## (Plan.margin, TeleporterRules.edge), would reach its stretch with its margins (WallRunGapPlacement.keep_out) is blocked,
## and no other; and a teleporter as near as it may stand leaves the wall-run gap's own re-check passing (its keep-outs,
## as wide, still clear of it), while one whose landing reaches it is named by TeleporterRules.problems. At 3, 5 and 6
## lanes.
func _test_wall_run_gaps() -> void:
	for lanes: int in LANE_COUNTS:
		var layout := RunSim.layout(lanes, 1400.0)
		var config := LevelConfig.new()
		config.lane_count = lanes
		config.features = PackedStringArray([TeleporterRules.FEATURE, "wall_run_gaps"])
		var bare: LevelGenerator = LevelGenerator.for_layout(config, tuning, layout)
		var shape: WallRunGapPlacement.Shape = WallRunGapPlacement.shape_for(bare.tuning, bare.speed)
		var w: Dictionary = WallRunGapPlacement.make(shape, 700.0, 1)
		layout.wall_run_gaps.append(w)
		WallRunGapPlacement._set_holes(layout, w, true)
		var gen: LevelGenerator = LevelGenerator.for_layout(config, tuning, layout)
		var k: Vector2 = WallRunGapPlacement.keep_out(w)
		var plan: TeleporterRules.Plan = TeleporterRules.plan_for(gen, tt)
		var tag: String = "(lanes=%d, the wall-run gap's stretch %.1f-%.1f m)" % [lanes, k.x, k.y]
		var wrong: PackedStringArray = []
		var counts: Array[int] = [0, 0]
		var e: float = plan.margin
		for i: int in plan.size():
			var f: float = plan.front_at(i)
			var near := Vector2(f - plan.approach - e, f + plan.pad + plan.room + e)
			for h: int in plan.hops.size():
				var land := Vector2(f + plan.hops[h] - plan.back - e, f + plan.hops[h] + plan.landing + e)
				var reaches: bool = _overlap(near, k) or _overlap(land, k)
				var edge: bool = _touches(near, k) or _touches(land, k)
				var blocked: bool = plan.near[i] > 0 or plan.far[h][i] > 0
				if edge:
					continue
				counts[1 if reaches else 0] += 1
				if reaches != blocked and wrong.size() < 4:
					wrong.append("%.1f m hop %d (%s)" % [f, h, "free" if reaches else "blocked"])
		check(wrong.is_empty() and counts[0] > 0 and counts[1] > 0,
			"every spot whose pad stretch or landing would reach it is blocked (%d), and no other (%d): %s %s"
			% [counts[1], counts[0], ", ".join(wrong), tag])
		# The re-checks: a teleporter as near as it may stand (its landing with the margin ends just before its stretch), and
		# one whose landing reaches into it.
		for into: bool in [false, true]:
			var hop: float = plan.hops[0]
			var front: float = k.x - hop - plan.landing - (-0.6 if into else e + 0.06)
			var probe: LevelLayout = layout.copy()
			probe.teleporters.append(_entry(gen, 1, 1, front, [1], 0, 0.0, 0.0, false, hop))
			var probe_gen: LevelGenerator = LevelGenerator.for_layout(config, tuning, probe)
			var named: bool = false
			for why: String in TeleporterRules.problems(probe_gen):
				named = named or why.contains("every lane keeps clear")
			check(named == into, "the teleporters' re-check %s a landing %s it %s" % ["names" if into else "passes",
				"reaching into" if into else "just short of", tag])
			if not into:
				var problem: String = WallRunGapPlacement.problem(probe_gen, w)
				check(problem == "", "the wall-run gap's own re-check passes beside a teleporter as near as it may stand (%s) %s"
					% [problem, tag])


## A falling gantryway (its rules run before the teleporters') re-checks its windows against every rule's keep-outs
## (GantrywayRules.problems: the lanes they name, and every lane's): so every grid spot whose pad stretch or a landing,
## with the plan's margin, would reach what a gantryway keeps in every lane (from its pillar's lead to past its walkway
## and its calm stretch) is blocked, and a teleporter as near as it may stand before it, or after it, leaves the
## gantryway's re-check as it was (the teleporter's keep-outs are as wide as the plan's margin: the gate of task Q4 found
## them a fifth of a metre into a gantryway's windows before the plan kept that margin), while one whose keep-outs reach
## into it is named there. At 3, 5 and 6 lanes.
func _test_gantryways() -> void:
	var gt: GantrywayTuning = GantrywayTuning.load_default()
	for lanes: int in LANE_COUNTS:
		var layout := RunSim.layout(lanes, 1400.0)
		var config := LevelConfig.new()
		config.lane_count = lanes
		config.features = PackedStringArray(["gantryway", TeleporterRules.FEATURE])
		var gen: LevelGenerator = LevelGenerator.for_layout(config, tuning, layout)
		# A gantryway as its rules make one, over lane 1, its pillar at 700 m pushing to lane 2.
		var pillar: float = 700.0
		var walkway: float = GantrywayRules.walkway_length(gen, gt)
		var calm: float = GantrywayRules.calm_length(gen, gt)
		var start: float = pillar - GantrywayRules.NEAR_OVERHANG
		layout.gantryways.append({"id": 0, "lane": 1, "start": start, "end": start + walkway, "pillar": pillar, "side": 1,
			"calm": [pillar, pillar + calm], "seed": 7})
		var box: Vector3 = tuning.doodad_size(Gantryway.PILLAR_SIZE)
		layout.doodads.append({"lane": 1, "start": pillar, "end": pillar + box.z, "size": Gantryway.PILLAR_SIZE, "side": 1,
			"seed": 7, LevelLayout.GANTRY_PILLAR: 0})
		var before: float = LevelGenerator.doodad_lead_for(gen.tuning) + gen.doodad_lane_room()
		var keep := Vector2(pillar - before, maxf(start + walkway + gen.doodad_lane_room(), pillar + calm))
		var tag: String = "(lanes=%d, the gantryway's stretch %.1f-%.1f m)" % [lanes, keep.x, keep.y]
		var plan: TeleporterRules.Plan = TeleporterRules.plan_for(gen, tt)
		var e: float = plan.margin
		var wrong: PackedStringArray = []
		var counts: Array[int] = [0, 0]
		for i: int in plan.size():
			var f: float = plan.front_at(i)
			var near := Vector2(f - plan.approach - e, f + plan.pad + plan.room + e)
			for h: int in plan.hops.size():
				var land := Vector2(f + plan.hops[h] - plan.back - e, f + plan.hops[h] + plan.landing + e)
				if _touches(near, keep) or _touches(land, keep):
					continue
				var reaches: bool = _overlap(near, keep) or _overlap(land, keep)
				var blocked: bool = plan.near[i] > 0 or plan.far[h][i] > 0
				counts[1 if reaches else 0] += 1
				if reaches != blocked and wrong.size() < 4:
					wrong.append("%.1f m hop %d (%s)" % [f, h, "free" if reaches else "blocked"])
		check(wrong.is_empty() and counts[0] > 0 and counts[1] > 0,
			"every spot whose pad stretch or landing would reach it, with the margin, is blocked (%d), and no other (%d): %s %s"
			% [counts[1], counts[0], ", ".join(wrong), tag])
		# The re-check, beside a teleporter as near as it may stand (its landing with the margin just before the gantryway's
		# stretch, or its pad's approach with the margin just after it), and beside one whose keep-outs reach into it (its
		# landing itself ending just before it, the margin past that).
		var baseline: PackedStringArray = GantrywayRules.problems(gen)
		var hop: float = plan.hops[0]
		var probes: Array = [[keep.x - hop - plan.landing - e - 0.06, false], [keep.y + plan.approach + e + 0.06, false],
			[keep.x - hop - plan.landing - 0.1, true]]
		for probe_at: Array in probes:
			var front: float = probe_at[0]
			var probe: LevelLayout = layout.copy()
			probe.teleporters.append(_entry(gen, 2, 1, front, [2], 0, 0.0, 0.0, false, hop))
			var added: PackedStringArray = []
			for why: String in GantrywayRules.problems(LevelGenerator.for_layout(config, tuning, probe)):
				if not baseline.has(why):
					added.append(why)
			if bool(probe_at[1]):
				check(not added.is_empty(), "the gantryway's re-check names a teleporter whose keep-outs reach into it (%.1f m) %s"
					% [front, tag])
			else:
				check(added.is_empty(), "the gantryway's re-check is as it was beside a teleporter at %.1f m, as near as it may stand (%s) %s"
					% [front, added, tag])


static func _overlap(a: Vector2, b: Vector2) -> bool:
	return a.x < b.y and a.y > b.x


## True if `a` and `b` meet within a grid step's rounding (where the grid's marks and the test may disagree).
static func _touches(a: Vector2, b: Vector2) -> bool:
	return absf(a.y - b.x) < 0.02 or absf(a.x - b.y) < 0.02


## Endless mode with the Ice Lab as the furthest zone (App.start_endless: the zone's last level, Specimen Vault, made a
## 20-minute level of everything the zone has from the start, at the zone's speed, on a random seed), here on an
## arbitrary seed at 5 lanes, as test_gantryways' _test_endless does: it builds without warnings and stands its level's
## count of teleporters (DESIGN-TBD, docs/questions/q4.md 14: 4 over its 20 minutes, 2 of them blinking) spread along the
## whole of it, each fair (check_teleporters). No introduction: endless mode gives no feature a start.
func _test_endless() -> void:
	var zone := load("res://data/zones/ice_lab.tres") as ZoneDef
	for level_seed: int in [7310]:
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
		var tag: String = "(endless in the Ice Lab, seed %d)" % level_seed
		var gen := LevelGenerator.new()
		var spent_before: int = TeleporterRules.spent_usec
		var started: int = Time.get_ticks_usec()
		var layout: LevelLayout = gen.generate(config, tuning, LevelGenerator.load_for(config))
		var build_ms: float = (Time.get_ticks_usec() - started) / 1000.0
		check(gen.warnings.is_empty(), "no warnings %s %s" % [tag, gen.warnings])
		var fronts: Array[float] = TeleporterRules.positions(layout)
		check(fronts.size() == config.teleporters and not fronts.is_empty() and fronts[0] < layout.length * 0.4
			and fronts[-1] > layout.length * 0.6,
			"its %d teleporters spread along the whole of it (%s of %.0f m) %s" % [config.teleporters, fronts, layout.length, tag])
		check(TeleporterRules.positions_blinking(layout).size() == config.blinking_teleporters,
			"%d of them blink %s" % [config.blinking_teleporters, tag])
		var intros: int = 0
		for tp: Dictionary in layout.teleporters:
			intros += 1 if tp.has("intro") else 0
		check(intros == 0, "no introduction in endless mode " + tag)
		LayoutChecks.check_teleporters(self, layout, config, tag)
		print("  endless in the Ice Lab, seed %d: %d teleporters in %.0f m, a build %.0f ms (%.0f ms of it the teleporters' rules)"
			% [level_seed, fronts.size(), layout.length, build_ms, (TeleporterRules.spent_usec - spent_before) / 1000.0])


# --- The track ----------------------------------------------------------------------------------

func _test_track() -> void:
	var sim := RunSim.new(tree, tuning)
	for lanes: int in LANE_COUNTS:
		var lane: int = maxi(lanes / 2, 1)
		var outs: Array = [0, lanes - 1]
		for light: int in [-1, 1, 0]:
			var layout: LevelLayout = _layout(lanes, lane, 1 if lane < lanes - 1 else -1, outs if light != 0 else [lane], light)
			var world: RunWorld = sim.build_world(layout)
			world.track.update(PAD, 0.0)
			world.track.dress_all()
			world.track.light_teleporters(0.0)
			var tp: Dictionary = layout.teleporters[0]
			var node: Teleporter = world.track.teleporter_for(tp)
			var tag: String = "(lanes=%d light=%d)" % [lanes, light]
			check(node != null and world.track.teleporter_nodes().size() == 1, "the track builds its teleporter " + tag)
			if node == null:
				await sim.free_world(world)
				continue
			var side: float = TeleporterRules.pad_size(LevelGenerator.for_layout(world.config, tuning, layout), tt)
			var box := node.pad.get_child(0) as CollisionShape3D
			check(node.pad.collision_layer == TrackBuilder.LAYER_TRIGGER and node.pad.collision_mask == 0
				and node.pad.get_meta(&"kind") == Teleporter.KIND and is_same(node.pad.get_meta(Teleporter.META), tp)
				and box != null and (box.shape as BoxShape3D).size.is_equal_approx(Vector3(side, Teleporter.TRIGGER_HEIGHT, side)),
				"its pad is a trigger square on the trigger layer, %.2f m a side, carrying its entry %s" % [side, tag])
			var pad_pos: Vector3 = node.pad.global_position
			check(absf(pad_pos.x - world.geo.lane_x(lane)) < 0.01
				and absf(pad_pos.z - TrackGeometry.world_z(float(tp["at"]) + side * 0.5)) < 0.01
				and absf(pad_pos.y - Teleporter.TRIGGER_HEIGHT * 0.5) < 0.01,
				"its pad lies in its lane from its front on, on the floor " + tag)
			var placed: bool = node.outputs.size() == (tp["outputs"] as Array).size()
			for k: int in mini(node.outputs.size(), (tp["outputs"] as Array).size()):
				var o: Dictionary = (tp["outputs"] as Array)[k]
				var at: Vector3 = node.outputs[k].global_position
				placed = placed and absf(at.x - world.geo.lane_x(int(o["lane"]))) < 0.01 \
					and absf(at.z - TrackGeometry.world_z(float(o["at"]) + side * 0.5)) < 0.01
			check(placed, "its output pads stand in their lanes at their spots " + tag)
			var bodies: int = 0
			for c: Node in node.find_children("*", "CollisionObject3D", true, false):
				bodies += 1 if c != node.pad and (c as CollisionObject3D).collision_layer != 0 else 0
			check(bodies == 0, "nothing of it collides but its pad's trigger " + tag)
			check(node.lamps.has(-1) and node.lamps.has(1) and node.lamps.has(0), "the skin dressed its antenna's lamps " + tag)
			if node.lamps.has(-1) and node.lamps.has(1) and node.lamps.has(0):
				var shown: Array[bool] = [(node.lamps[-1] as Node3D).visible, (node.lamps[1] as Node3D).visible,
					(node.lamps[0] as Node3D).visible]
				var want: Array[bool] = [light < 0, light > 0, light == 0]
				check(shown == want, "its lamps show the light (%s, want %s) %s" % [shown, want, tag])
			await sim.free_world(world)


## The light's rules (Teleporter.lit_side, lamp_level, output_at): one output pad lights neither side; a fixed light stays on
## its side; a blinking one changes side every blink seconds from its phase (half a cycle on, the other side); the
## brighter lamp is always the side lit_side gives (both at a half at the change itself), with either fade.
func _test_light() -> void:
	var outs: Array = [{"lane": 0, "at": 150.0, "end": 152.0}, {"lane": 2, "at": 150.0, "end": 152.0}]
	var one: Dictionary = {"outputs": [outs[0]], "light": 0, "blink": 0.0, "phase": 0.0}
	check(Teleporter.lit_side(one, 3.3) == 0 and Teleporter.lamp_level(one, -1, 3.3, 0.06) == 0.0
		and Teleporter.output_at(one, 3.3) == outs[0], "one output pad: no side lit, it's where the runner lands")
	for light: int in [-1, 1]:
		var fixed: Dictionary = {"outputs": outs, "light": light, "blink": 0.0, "phase": 0.0}
		var stays: bool = true
		for k: int in 50:
			var t: float = k * 0.173
			stays = stays and Teleporter.lit_side(fixed, t) == light \
				and Teleporter.output_at(fixed, t) == outs[0 if light < 0 else 1] \
				and Teleporter.lamp_level(fixed, light, t, 0.06) == 1.0 and Teleporter.lamp_level(fixed, -light, t, 0.06) == 0.0
		check(stays, "a fixed light stays on its side (%d), and it decides" % light)
	var blink: float = tt.blink_seconds
	for phase: float in [0.0, 0.3]:
		var b: Dictionary = {"outputs": outs, "light": -1, "blink": blink, "phase": phase}
		var flipped: Dictionary = b.duplicate()
		flipped["phase"] = phase + 0.5
		var changes: int = 0
		var last: int = Teleporter.lit_side(b, 0.0)
		var ok: bool = true
		var opposite: bool = true
		for fade: float in [tt.blink_fade_seconds, tt.reduced_blink_fade_seconds]:
			for k: int in 1200:
				var t: float = k * 0.005
				var side: int = Teleporter.lit_side(b, t)
				if fade == tt.blink_fade_seconds and side != last:
					changes += 1
					last = side
				var l: float = Teleporter.lamp_level(b, -1, t, fade)
				var r: float = Teleporter.lamp_level(b, 1, t, fade)
				ok = ok and absf(l + r - 1.0) < 0.001 and (side < 0 and l >= r - 0.0001 or side > 0 and r >= l - 0.0001) \
					and Teleporter.output_at(b, t) == outs[0 if side < 0 else 1]
				opposite = opposite and Teleporter.lit_side(flipped, t) == -side
		var expect: int = int(1200 * 0.005 / blink)
		check(ok, "a blinking light: the brighter lamp is always the side a touch takes (phase %.1f)" % phase)
		check(absi(changes - expect) <= 1, "it changes side every %.1f s (%d changes in 6 s)" % [blink, changes])
		check(opposite, "half a cycle on, the other side (phase %.1f)" % phase)
		var change: float = (1.0 - fposmod(phase * 2.0, 1.0)) * blink
		check(absf(Teleporter.lamp_level(b, -1, change, 0.06) - 0.5) < 0.01, "both lamps at a half at the change itself")


# --- On real physics ----------------------------------------------------------------------------

func _test_physics() -> void:
	var sim := RunSim.new(tree, tuning)
	for lanes: int in LANE_COUNTS:
		for lane: int in range(1, lanes - 1):
			var side: int = 1 if lane < lanes - 1 else -1
			var tag: String = "(lanes=%d lane=%d)" % [lanes, lane]
			# One output pad, in another lane where there's one.
			var target: int = lane + side
			var r: Dictionary = await _take(sim, _layout(lanes, lane, side, [target]), lane)
			check(_landed(r, target) and absf(float(r["to"]) - float(r["from"]) - _hop()) < 0.001,
				"run onto, the runner lands on its output pad in lane %d, %.1f m on, and runs through the landing %s %s"
				% [target, _hop(), _brief(r), tag])
			check(absf(float(r["speed_after"]) - float(r["speed_before"])) < 0.001 and (r["events"] as Array).count(&"teleport") == 1
				and int(r["sounds"]) == 1,
				"keeping their speed (%.2f, %.2f m/s), the `teleport` event and its sound once (%d) %s" % [float(r["speed_before"]),
					float(r["speed_after"]), int(r["sounds"]), tag])
			# Two output pads, a fixed light each way, and a blinking light at two phases half a cycle apart.
			var left: int = 0
			var right: int = lanes - 1
			for light: int in [-1, 1]:
				r = await _take(sim, _layout(lanes, lane, side, [left, right], light), lane)
				var want: int = left if light < 0 else right
				check(_landed(r, want), "a fixed light on the %s: the runner lands on the %s output pad (lane %d) %s %s"
					% ["left" if light < 0 else "right", "left" if light < 0 else "right", want, _brief(r), tag])
			var landed: Dictionary = {}
			for phase: float in [0.2, 0.7]:
				var layout: LevelLayout = _layout(lanes, lane, side, [left, right], -1, tt.blink_seconds, phase)
				r = await _take(sim, layout, lane)
				var expect: Dictionary = Teleporter.output_at(layout.teleporters[0], float(r["at_touch"]))
				check(_landed(r, int(expect.get("lane", -2))),
					"a blinking light: the side lit at the touch (%.3f s) decides (lane %d) %s %s" % [float(r["at_touch"]),
						int(expect.get("lane", -2)), _brief(r), tag])
				landed[int(r["out_lane"])] = true
			check(landed.size() == 2, "half a cycle apart, the two touches land on both output pads %s" % tag)
			# The way around: in the lane beside it, a switch out at its approach, a jump over it.
			r = await _take(sim, _layout(lanes, lane, side, [target]), lane + side)
			check(bool(r["alive"]) and int(r["teleports"]) == 0 and float(r["distance"]) > PAD + 20.0,
				"a runner in the lane beside it runs past %s %s" % [_brief(r), tag])
			var approach: float = tt.approach_seconds * tuning.run_speed
			r = await _take(sim, _layout(lanes, lane, side, [target]), lane,
				[[PAD - approach, &"move_right" if side > 0 else &"move_left"]])
			check(bool(r["alive"]) and int(r["teleports"]) == 0 and int(r["lane"]) == lane + side,
				"a runner who switches out as its approach begins runs past %s %s" % [_brief(r), tag])
			r = await _take(sim, _layout(lanes, lane, side, [target]), lane, [[PAD - 2.5, &"jump"]])
			check(bool(r["alive"]) and int(r["teleports"]) == 0 and int(r["lane"]) == lane,
				"a runner who jumps over it isn't taken %s %s" % [_brief(r), tag])
		var mid: int = maxi(lanes / 2, 1)
		var mid_side: int = 1 if mid < lanes - 1 else -1
		var at: String = "(lanes=%d)" % lanes
		# The dash, a slide and the protection carry through it.
		var r: Dictionary = await _take(sim, _layout(lanes, mid, mid_side, [mid]), mid, [[PAD - 6.0, &"dash"]])
		check(_landed(r, mid) and bool(r["dashing"]) and float(r["speed_after"]) > tuning.run_speed + 0.5,
			"dashing onto it, the runner arrives still dashing, at the dash's speed %s %s" % [_brief(r), at])
		r = await _take(sim, _layout(lanes, mid, mid_side, [mid]), mid, [[PAD - 3.0, &"slide"]])
		check(_landed(r, mid) and bool(r["sliding"]), "sliding onto it, the runner arrives sliding %s %s" % [_brief(r), at])
		r = await _take(sim, _layout(lanes, mid, mid_side, [mid]), mid, [], func(p: Player, _w: RunWorld) -> void:
			p.armor_state.carried = true
			p.armor_state.hits = p.armor_state.max_hits
			p.shield = 1
			p.invulnerable_left = 100.0)
		check(_landed(r, mid) and bool(r["armor"]) and int(r["shield"]) == 1 and float(r["invulnerable"]) > 90.0,
			"the armor, the shield and an invulnerability window carry through it as they were %s %s" % [_brief(r), at])


## One take on real physics: `layout`'s teleporter, the runner starting in lane `start`, `actions` ([distance, action],
## RunSim's), `prepare` called with the Player and the world before the run. Run until a little past the landing (or
## until the runner dies). The result: step_world's, and the teleport's: "teleports", "from", "to", "out_lane", "at_touch"
## (the level clock), "speed_before" (a frame before the touch) and "speed_after", "dashing" and "sliding" right after,
## "armor", "shield", "invulnerable", "built_to" (how far the track was built then), "camera_x" (the camera's x then, with
## `camera`).
func _take(sim: RunSim, layout: LevelLayout, start: int, actions: Array = [], prepare: Callable = Callable()) -> Dictionary:
	var world: RunWorld = sim.build_world(layout)
	world.player.setup(world.tuning, world.geo, start)
	var p: Player = world.player
	if prepare.is_valid():
		prepare.call(p, world)
	var out := {"teleports": 0, "from": -1.0, "to": -1.0, "out_lane": -1, "at_touch": -1.0, "speed_before": 0.0,
		"speed_after": 0.0, "dashing": false, "sliding": false, "armor": false, "shield": 0, "invulnerable": 0.0, "lane_after": -1}
	var last_speed: Array[float] = [0.0]
	var track_speed := func() -> void: last_speed[0] = p.speed
	world.get_tree().physics_frame.connect(track_speed)
	out["sounds"] = 0
	world.sounds.requested.connect(func(sound: StringName) -> void:
		if sound == &"teleport":
			out["sounds"] = int(out["sounds"]) + 1)
	world.teleported.connect(func(from: float, to: float, _entry: Dictionary, output: Dictionary) -> void:
		out["teleports"] = int(out["teleports"]) + 1
		out["from"] = from
		out["to"] = to
		out["out_lane"] = int(output["lane"])
		out["lane_after"] = p.lane
		out["at_touch"] = p.elapsed
		out["speed_before"] = last_speed[0]
		out["speed_after"] = p.speed
		out["dashing"] = p.dashing
		out["sliding"] = p.is_sliding()
		out["armor"] = p.armor_state.carried and p.armor_state.hits == p.armor_state.max_hits
		out["shield"] = p.shield
		out["invulnerable"] = p.invulnerable_left)
	var tp: Dictionary = layout.teleporters[0]
	var land: float = float((tp["outputs"] as Array)[0]["at"])
	var landing: float = float((tp["span"] as Array)[1]) - land
	var seconds: float = (land + landing + 4.0) / tuning.run_speed
	var r: Dictionary = await sim.step_world(world, seconds, actions)
	world.get_tree().physics_frame.disconnect(track_speed)
	r.merge(out)
	r["landing_end"] = land + landing
	await sim.free_world(world)
	return r


## True if take `r` teleported once onto the output pad in `lane`, arrived in it, and ran alive through the landing.
func _landed(r: Dictionary, lane: int) -> bool:
	return bool(r["alive"]) and int(r["teleports"]) == 1 and int(r["out_lane"]) == lane and int(r["lane_after"]) == lane \
		and float(r["distance"]) >= float(r["landing_end"])


func _brief(r: Dictionary) -> String:
	return "(alive %s, cause '%s', lane %d, teleports %d to lane %d, %.1f-%.1f m, distance %.1f)" % [r.get("alive"),
		r.get("cause", ""), int(r.get("lane", -1)), int(r.get("teleports", 0)), int(r.get("out_lane", -1)),
		float(r.get("from", -1.0)), float(r.get("to", -1.0)), float(r.get("distance", -1.0))]


## The hop of the hand-built tracks (metres): the middle of the tuning's hops at the suite's run speed.
func _hop() -> float:
	var hops: PackedFloat32Array = tt.hops()
	return hops[hops.size() / 2] * tuning.run_speed


# --- What a teleport skips ----------------------------------------------------------------------

## One take at 5 lanes with everything a teleport settles: dummy enemies between its pads and past its landing (and one
## that follows the runner), a heli drone in play and one waiting between, a cyborg ahead charging up, a shot in the air, credits
## between and past, the camera and the flash: all as RunWorld._on_teleported says. The attacks under way and the shot are
## set going at the touch itself (a handler on Player.teleported ahead of RunWorld's), so nothing else calls them off
## first. And the director on its own: entries still to come behind the landing never spawn, those past it do.
func _test_skipped() -> void:
	var sim := RunSim.new(tree, tuning)
	var layout: LevelLayout = _layout(5, 2, 1, [0], 0)
	var tp: Dictionary = layout.teleporters[0]
	var land: float = float((tp["outputs"] as Array)[0]["at"])
	var credit := func(at: float, lane: int, value: int) -> Dictionary:
		return {"at": at, "surface": "floor", "lane": lane, "side": 0, "height": 1.0, "value": value}
	layout.credits.append(credit.call(PAD + 20.0, 2, 5))
	layout.credits.append(credit.call(PAD + 30.0, 1, 25))
	layout.credits.append(credit.call(land + 25.0, 0, 5))
	var world: RunWorld = sim.build_world(layout)
	world.player.setup(world.tuning, world.geo, 2)
	var p: Player = world.player
	var camera := RunCamera.new()
	world.add_child(camera)
	camera.follow(world)
	var flash := TeleportFlash.new()
	world.add_child(flash)
	flash.setup(world, tt)
	var d := world.director
	var dummy := func(lane: int, at: float) -> Enemy:
		return d.spawn({"type": "dummy", "script": DUMMY_SCRIPT, "lane": lane, "at": at, "params": {}})
	var between: Enemy = dummy.call(1, land - 15.0)
	var ahead: Enemy = dummy.call(3, land + 50.0)
	var follower: Enemy = dummy.call(4, PAD + 12.0)
	follower.follows_runner = true
	var waiting: Enemy = d.spawn({"type": "drone", "lane": 2, "at": land - 10.0, "seed": 3, "params": {"slot": 0}})
	var drone: Enemy = d.spawn({"type": "drone", "lane": 2, "at": 55.0, "seed": 4, "params": {"slot": 1}})
	var max_before: int = world.score.max_credit_score
	var r := {"cut": false, "retired_between": false, "ahead": false, "follower": false, "waiting_gone": false,
		"drone_on": false, "drone_state": -1, "drone_before": -1, "shots": -1, "cyborg_state": -1, "cyborg_why": &"",
		"cyborg_before": -1, "built": 0.0, "camera": false, "flash": 0.0, "skipped": 0, "max_after": 0}
	var cyborg: Array[Enemy] = []
	# At the touch, ahead of RunWorld's handler: a cyborg ahead charging up, the drone winding up, a shot in the air.
	var at_touch := func(_from: float, _to: float, _entry: Dictionary, _output: Dictionary) -> void:
		world.projectiles.fire_enemy(world.lane_point(2, PAD + 15.0, 1.0), Vector3(0.0, 0.0, 5.0))
		var c: Enemy = d.spawn({"type": "cyborg", "lane": 3, "at": land + 45.0, "seed": 5, "params": {"panic": false}})
		cyborg.append(c)
		var gun: CyborgGun = c.get(&"gun")
		gun.call(&"_start_charge")
		r["cyborg_before"] = gun.state
		if is_instance_valid(drone) and drone.alive:
			drone.call(&"_start_windup", p)
			r["drone_before"] = int(drone.get(&"state"))
	p.teleported.disconnect(Callable(world, &"_on_teleported"))
	p.teleported.connect(at_touch)
	p.teleported.connect(Callable(world, &"_on_teleported"))
	world.teleported.connect(func(_from: float, to: float, _entry: Dictionary, _output: Dictionary) -> void:
		r["retired_between"] = not is_instance_valid(between) or not between.alive
		r["ahead"] = is_instance_valid(ahead) and ahead.alive and d.active.has(ahead)
		r["follower"] = is_instance_valid(follower) and follower.alive
		r["waiting_gone"] = not is_instance_valid(waiting) or not waiting.alive
		r["drone_on"] = is_instance_valid(drone) and drone.alive
		r["drone_state"] = int(drone.get(&"state")) if is_instance_valid(drone) else -1
		r["shots"] = world.projectiles.live_count()
		if not cyborg.is_empty() and is_instance_valid(cyborg[0]):
			var gun: CyborgGun = cyborg[0].get(&"gun")
			r["cyborg_state"] = gun.state
			r["cyborg_why"] = gun.events[-1].get("why", &"") if not gun.events.is_empty() else &""
		r["built"] = int(world.track.get(&"_next_chunk")) * TrackBuilder.CHUNK_LENGTH
		r["camera"] = absf(camera.position.x - p.position.x * world.tuning.camera_follow_x) < 0.01
		r["flash"] = flash.alpha()
		r["skipped"] = world.score.credits_skipped
		r["max_after"] = world.score.max_credit_score
		r["to"] = to)
	var res: Dictionary = await sim.step_world(world, (land + 30.0) / tuning.run_speed)
	check(bool(res["alive"]) and float(res["distance"]) > land and not cyborg.is_empty(),
		"the take runs through its teleport (%s)" % [res])
	check(bool(r["retired_between"]) and bool(r["ahead"]) and bool(r["follower"]),
		"an enemy between its pads leaves play, one past its landing stays, one that follows the runner comes along")
	check(bool(r["waiting_gone"]) and bool(r["drone_on"]) and int(r["drone_before"]) == DroneScript.State.WINDUP
		and int(r["drone_state"]) == DroneScript.State.FOLLOW,
		"a heli drone waiting between never comes; one in play comes along, its wind-up called off (state %d, then %d)"
		% [int(r["drone_before"]), int(r["drone_state"])])
	check(int(r["cyborg_before"]) == CyborgGun.State.CHARGING and int(r["cyborg_state"]) == CyborgGun.State.READY
		and StringName(r["cyborg_why"]) == &"teleport",
		"a cyborg ahead charging up is called off (state %d, why %s)" % [int(r["cyborg_state"]), r["cyborg_why"]])
	check(int(r["shots"]) == 0, "every shot in the air goes")
	check(int(r["skipped"]) == 30 and int(r["max_after"]) == max_before - 30,
		"the credits between are passed, and the stars' best score leaves them out (%d skipped, best %d of %d)"
		% [int(r["skipped"]), int(r["max_after"]), max_before])
	check(float(r["built"]) >= float(r.get("to", 0.0)) + TrackBuilder.BUILD_AHEAD - TrackBuilder.CHUNK_LENGTH,
		"the track is built ahead of the landing at once (to %.0f m)" % float(r["built"]))
	check(bool(r["camera"]), "the camera cuts across to the runner's new lane")
	check(absf(float(r["flash"]) - tt.flash_alpha) < 0.01, "the flash shows (%.2f)" % float(r["flash"]))
	check(world.score.credits >= 5 and world.score.stats().get("credits_skipped", -1) == 30,
		"the credit past the landing is still there to collect, and the run's stats name the skipped ones")
	await sim.free_world(world)
	# The director on its own: entries still to come behind the landing never spawn, those past it do.
	var bare: LevelLayout = RunSim.layout(5, 900.0)
	for at: float in [500.0, 700.0]:
		bare.enemies.append({"type": "dummy", "script": DUMMY_SCRIPT, "lane": 1, "at": at, "seed": 1, "params": {}})
	var w2: RunWorld = sim.build_world(bare)
	w2.director.runner_teleported(0.0, 600.0)
	w2.director.update(760.0)
	var spawned: Array[float] = []
	for e: Enemy in w2.director.active:
		if is_instance_valid(e) and e.alive:
			spawned.append(float(e.spawn.get("at", -1.0)))
	check(spawned == [700.0], "entries still to come behind the landing never spawn, those past it do (%s)" % [spawned])
	await sim.free_world(w2)


## The flash (TeleportFlash): flash_alpha fading out over flash_seconds; with Reduced flashing no flash, a soft tint
## easing in and out, never above reduced_flash_alpha; it shows on a teleport and clears.
func _test_flash() -> void:
	var a0: float = TeleportFlash.alpha_at(tt, 0.0, false)
	var fades: bool = absf(a0 - tt.flash_alpha) < 0.001 and TeleportFlash.alpha_at(tt, tt.flash_seconds, false) == 0.0
	var last: float = a0
	for k: int in 20:
		var a: float = TeleportFlash.alpha_at(tt, k * tt.flash_seconds / 20.0, false)
		fades = fades and a <= last + 0.0001
		last = a
	check(fades, "the flash: from %.2f down to none over %.2f s" % [tt.flash_alpha, tt.flash_seconds])
	var soft: bool = TeleportFlash.alpha_at(tt, 0.0, true) == 0.0 and TeleportFlash.alpha_at(tt, tt.reduced_flash_seconds, true) == 0.0
	var top: float = 0.0
	for k: int in 40:
		top = maxf(top, TeleportFlash.alpha_at(tt, k * tt.reduced_flash_seconds / 40.0, true))
	check(soft and top <= tt.reduced_flash_alpha + 0.0001 and top > 0.0 and tt.reduced_flash_alpha < tt.flash_alpha,
		"with Reduced flashing, a soft tint easing in and out (at most %.2f) instead" % top)
	var sim := RunSim.new(tree, tuning)
	var world: RunWorld = sim.build_world(_layout(5, 2, 1, [2]))
	var flash := TeleportFlash.new()
	world.add_child(flash)
	flash.setup(world, tt)
	for reduced: bool in [false, true]:
		Settings.flashing_reduced = reduced
		world.teleported.emit(PAD, PAD + 60.0, {}, {"lane": 2, "at": PAD + 60.0})
		var most: float = flash.alpha()
		for i: int in 60:
			await tree.process_frame
			most = maxf(most, flash.alpha())
		check(flash.alpha() == 0.0 and most > 0.0 and most <= (tt.reduced_flash_alpha if reduced else tt.flash_alpha) + 0.001,
			"it shows on a teleport and clears (at most %.2f, Reduced flashing %s)" % [most, "on" if reduced else "off"])
	check(flash.shown == 2, "it counts the teleports it showed")
	Settings.flashing_reduced = false
	await sim.free_world(world)


# --- The campaign's own, on real physics --------------------------------------------------------

## Every teleporter of Relay Station and Specimen Vault at 3, 5 and 6 lanes, at the level's speed, on real physics, on a cut
## of the level around it (_cut: every piece reaching from its approach to its landings' end; nothing else): run onto,
## with its light set to each side in turn (either output pad may be taken: a blinking one's both, a fixed one's both
## kept fair), the runner lands on that output pad and runs through the landing alive with no input; in the lane beside it
## (its way around), and switching out of its lane as its approach begins, the runner passes it alive.
func _test_campaign() -> void:
	var campaign := load(CAMPAIGN_PATH) as Campaign
	var sim := RunSim.new(tree, tuning)
	var landings: int = 0
	var arounds: int = 0
	for n: int in [2, 3]:
		var step: CampaignStep = campaign.step("ice_lab/%d" % n)
		for lanes: int in LANE_COUNTS:
			var config: LevelConfig = campaign.configure(step, lanes)
			var gen: LevelGenerator = LayoutCache.generator(config, tuning, LevelGenerator.load_for(config))
			for tp: Dictionary in gen.layout.teleporters:
				var lane: int = int(tp["lane"])
				var side: int = int(tp["side"])
				var tag: String = "(%s lanes=%d, the teleporter at %.0f m in lane %d)" % [step.id, lanes, float(tp["at"]), lane]
				var outs: Array = tp["outputs"]
				for k: int in outs.size():
					var r: Dictionary = await _campaign_take(sim, gen, tp, lane, -1 if k == 0 else 1)
					var want: int = int((outs[k] as Dictionary)["lane"])
					check(bool(r["alive"]) and int(r["teleports"]) == 1 and int(r["lane"]) == want and bool(r["through"]),
						"run onto, the runner lands on its output pad in lane %d and runs through its landing %s %s" % [want,
							_brief(r), tag])
					landings += 1
				var r: Dictionary = await _campaign_take(sim, gen, tp, lane + side, 0)
				check(bool(r["alive"]) and int(r["teleports"]) == 0 and bool(r["past"]),
					"in the lane beside it, the runner passes it %s %s" % [_brief(r), tag])
				r = await _campaign_take(sim, gen, tp, lane, 0, side)
				check(bool(r["alive"]) and int(r["teleports"]) == 0 and bool(r["past"]) and int(r["lane"]) == lane + side,
					"switching out as its approach begins, the runner passes it %s %s" % [_brief(r), tag])
				arounds += 2
	check(landings >= 25 and arounds >= 40, "the campaign's teleporters were taken (%d landings) and passed (%d)" % [landings, arounds])
	print("  the Ice Lab's teleporters on real physics: %d landings, %d passes" % [landings, arounds])


## One take of _test_campaign on a cut of `gen`'s level around teleporter `tp` (_cut), at the level's run speed, the runner
## starting in `start`: `light` -1 or 1 sets its light to that side (no blinking) and runs on to the end of its landing;
## 0 runs past its pad (to a lane switch's room past it), with `switch` switching that way as its approach begins.
func _campaign_take(sim: RunSim, gen: LevelGenerator, tp: Dictionary, start: int, light: int, switch: int = 0) -> Dictionary:
	var t: MovementTuning = gen.tuning
	var approach: float = tt.approach_seconds * TeleporterRules.fastest(gen, pt)
	var front: float = float(tp["at"])
	var from: float = front - approach
	var to: float = float((tp["span"] as Array)[1])
	var offset: float = RUN_IN - from
	var cut: LevelLayout = _cut(gen, from, to, offset)
	var entry: Dictionary = _moved(tp, offset)
	if light != 0:
		entry["light"] = light
		entry["blink"] = 0.0
	cut.teleporters.append(entry)
	var world: RunWorld = sim.build_world(cut, null, t)
	world.player.setup(world.tuning, world.geo, start)
	var p: Player = world.player
	var out := {"teleports": 0, "out_lane": -1, "from": -1.0, "to": -1.0}
	world.teleported.connect(func(f: float, d: float, _e: Dictionary, o: Dictionary) -> void:
		out["teleports"] = int(out["teleports"]) + 1
		out["out_lane"] = int(o["lane"])
		out["from"] = f
		out["to"] = d)
	var actions: Array = []
	if switch != 0:
		actions.append([from + offset, &"move_right" if switch > 0 else &"move_left"])
	var past: float = float(tp["end"]) + gen.doodad_lane_room() + offset
	var end: float = (to + offset - 1.0) if light != 0 else (past - 1.0)
	var seconds: float = (end + 10.0) / t.run_speed
	var r: Dictionary = {}
	# Run until the runner is through (the landing's end, or past the pad), then stop: past that, what the level holds
	# is the player's to read.
	var reached: Array[bool] = [false]
	var watch := func() -> void:
		if p.distance >= end:
			reached[0] = true
			p.running = false
	world.get_tree().physics_frame.connect(watch)
	r = await sim.step_world(world, seconds, actions)
	world.get_tree().physics_frame.disconnect(watch)
	r.merge(out)
	r["through"] = reached[0]
	r["past"] = reached[0]
	await sim.free_world(world)
	return r


## A plain track holding every piece of `gen`'s level that reaches into [from, to] moved on by `offset` (its gaps, fences,
## pads, ceilings, ramps, speed pads, signs and doodads, as test_gantryways cuts a level).
func _cut(gen: LevelGenerator, from: float, to: float, offset: float) -> LevelLayout:
	var layout: LevelLayout = gen.layout
	var t: MovementTuning = gen.tuning
	var part := RunSim.layout(layout.lane_count, to - from + RUN_IN + 90.0)
	var lists: Dictionary = layout.to_dict()
	var into: Dictionary = part.to_dict()
	var extent: Dictionary = {"fences": t.fence_depth * 0.5, "pads": t.pad_length, "ramps": t.ramp_length,
		"speed_pads": t.speed_pad_length}
	for key: String in ["gaps", "fences", "pads", "hulls", "ramps", "speed_pads", "signs", "doodads"]:
		for item: Dictionary in lists.get(key, []):
			var start: float = float(item.get("start", item.get("at", 0.0)))
			var end: float = float(item["end"]) if item.has("end") else start + float(extent.get(key, 0.0))
			if key == "fences":
				start -= float(extent["fences"])
			if end < from or start > to:
				continue
			var moved: Dictionary = _moved(item, offset)
			if key == "doodads":
				part.doodads.append(moved)
			else:
				(into[key] as Array).append(moved)
	return part


## A copy of layout entry `item` moved on by `offset` along the track: its at, start and end, a row's stretch, and a
## teleporter's output pads, calm stretches and span.
static func _moved(item: Dictionary, offset: float) -> Dictionary:
	var moved: Dictionary = item.duplicate(true)
	for k: String in ["at", "start", "end", "pillar"]:
		if moved.has(k):
			moved[k] = float(moved[k]) + offset
	if moved.has("row"):
		var row: Array = moved["row"]
		moved["row"] = [float(row[0]) + offset, float(row[1]) + offset]
	if moved.has("outputs"):
		for o: Dictionary in moved["outputs"]:
			o["at"] = float(o["at"]) + offset
			o["end"] = float(o["end"]) + offset
		for c: Array in moved["calm"]:
			c[1] = float(c[1]) + offset
			c[2] = float(c[2]) + offset
		var span: Array = moved["span"]
		moved["span"] = [float(span[0]) + offset, float(span[1]) + offset]
	return moved


# --- Skins, the warm-up and the numbers ---------------------------------------------------------

func _test_skins() -> void:
	var skins: Array[ZoneSkin] = [GreyboxSkin.new()]
	var names: Array[String] = ["grey box"]
	for file: String in DirAccess.get_files_at("res://data/skins"):
		if file.ends_with("_skin.tres"):
			var s := load("res://data/skins".path_join(file)) as ZoneSkin
			if s != null:
				skins.append(s)
				names.append(file)
	var side: float = tuning.lane_width * tt.pad_share
	var size := Vector3(side, Teleporter.TRIGGER_HEIGHT, side)
	var floor_y: float = -size.y * 0.5
	for k: int in skins.size():
		var skin: ZoneSkin = skins[k]
		var tag: String = "(%s)" % names[k]
		for look_seed: int in [0, 1]:
			var pad := Node3D.new()
			skin.teleporter_pad(pad, size, look_seed)
			var halo: float = 1.5
			_check_look(pad, AABB(Vector3(-side * 0.5 * halo, floor_y - 0.01, -side * 0.5 * halo),
				Vector3(side * halo, 0.15, side * halo)), "its pad " + tag)
			var lamps: Dictionary = skin.teleporter_antenna(pad, size, look_seed)
			check(lamps.has(-1) and lamps.has(1) and lamps.has(0), "its antenna has a left, a right and a beacon lamp " + tag)
			var hidden: bool = true
			for key: Variant in lamps:
				var lamp: Variant = lamps[key]
				hidden = hidden and lamp is Node3D and not (lamp as Node3D).visible and (lamp as Node3D).get_parent() == pad
			check(hidden, "its lamps are nodes under the pad, hidden until lit " + tag)
			# The antenna (every mesh under the pad but its own look): on the pad's far half, no wider than the lane.
			var far_half := AABB(Vector3(-tuning.lane_width * 0.5, floor_y - 0.01, -side * 0.5),
				Vector3(tuning.lane_width, 3.2, side * 0.5))
			for n: Node in pad.find_children("*", "MeshInstance3D", true, false):
				var mi := n as MeshInstance3D
				if mi.name == "Look":
					continue
				var aabb: AABB = mi.transform * mi.mesh.get_aabb()
				check(far_half.grow(0.01).encloses(aabb), "its antenna's %s stands on the pad's far half, within the lane (%s) %s"
					% [mi.name, aabb, tag])
				_check_glow(mi, "its antenna's %s %s" % [mi.name, tag])
			pad.free()
			# An output pad: the pad's look, and over it what makes it read from afar, above a runner's head, within its
			# square across and along (no column of light from the floor, nothing across the lane).
			var output := Node3D.new()
			skin.teleporter_output(output, size, look_seed)
			var flat: int = 0
			var over: int = 0
			for n: Node in output.find_children("*", "MeshInstance3D", true, false):
				var mi := n as MeshInstance3D
				var aabb: AABB = mi.transform * mi.mesh.get_aabb()
				_check_glow(mi, "its output pad's %s %s" % [mi.name, tag])
				if aabb.end.y <= floor_y + 0.15:
					flat += 1
					continue
				over += 1
				check(aabb.position.y >= floor_y + 1.4 and AABB(Vector3(-side * 0.5, floor_y, -side * 0.5), Vector3(side, 3.2, side))
					.grow(0.01).encloses(aabb), "its output pad's %s floats over its square, above a runner's head (%s) %s"
					% [mi.name, aabb, tag])
			check(flat >= 1 and over >= 1, "its output pad lies flat with a marker over it (%d, %d) %s" % [flat, over, tag])
			output.free()
		check(TeleporterKit.GLOW_FADE.y >= 200.0, "its glow reads from 200 m off, as an output pad from its teleporter's approach")
	# The warm-up's sample: every part, nothing physical.
	var stage := Node3D.new()
	var sample: Node3D = Teleporter.warm_look(stage, GreyboxSkin.new(), TrackGeometry.new(5, tuning), tuning)
	var meshes: int = sample.find_children("*", "MeshInstance3D", true, false).size()
	check(meshes >= 7 and sample.find_children("*", "CollisionObject3D", true, false).is_empty(),
		"the warm-up draws its pad, antenna, three lamps and an output pad with its marker (%d meshes), with nothing that collides"
		% meshes)
	stage.free()


## Every mesh under `root` lies inside `bounds` (`root`'s space, a centimetre's slack) and glows only green or green-white.
func _check_look(root: Node3D, bounds: AABB, what: String) -> void:
	var instances: Array[Node] = root.find_children("*", "MeshInstance3D", true, false)
	check(not instances.is_empty(), "%s has a look" % what)
	for n: Node in instances:
		var mi := n as MeshInstance3D
		var aabb: AABB = mi.transform * mi.mesh.get_aabb()
		check(bounds.grow(0.01).encloses(aabb), "%s stays flat inside its square, its halo aside (%s in %s)" % [what, aabb, bounds])
		_check_glow(mi, what)


## `mi` glows (vertex COLOR.a above 0) only in green or green-white: never a hazard's red, pink, orange or yellow, nor
## the anti-grav pads' cyan.
func _check_glow(mi: MeshInstance3D, what: String) -> void:
	var wrong: Array[Color] = []
	for s: int in mi.mesh.get_surface_count():
		var colors: PackedColorArray = mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_COLOR]
		for c: Color in colors:
			if c.a > 0.0001 and (c.g < c.r + 0.1 or c.g < c.b + 0.1) and wrong.size() < 3:
				wrong.append(c)
	check(wrong.is_empty(), "%s glows only green or green-white (%s)" % [what, wrong])


## Every number of TeleporterTuning reaches the F6 panel (an @export_range hint); the hops run from the shortest to the
## longest, the blinking light changes side about once a second (GDD §5, proposed).
func _test_tuning() -> void:
	var ranged: bool = true
	var count: int = 0
	for p: Dictionary in tt.get_property_list():
		if not (int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) or not (int(p["usage"]) & PROPERTY_USAGE_EDITOR):
			continue
		if int(p["type"]) == TYPE_FLOAT or int(p["type"]) == TYPE_INT:
			count += 1
			if int(p["hint"]) != PROPERTY_HINT_RANGE:
				ranged = false
				failures.append("TeleporterTuning.%s has no range hint" % p["name"])
	check(ranged and count >= 18, "every number of the teleporters' tuning has a range for the F6 panel (%d)" % count)
	var hops: PackedFloat32Array = tt.hops()
	check(hops.size() == tt.hop_choices and is_equal_approx(hops[0], tt.hop_seconds_min) and is_equal_approx(hops[-1], tt.hop_seconds_max),
		"its hops run from %.1f s to %.1f s (%s)" % [tt.hop_seconds_min, tt.hop_seconds_max, hops])
	check(tt.blink_seconds >= 0.8 and tt.blink_seconds <= 1.2, "a blinking light changes side about once a second (%.2f s)" % tt.blink_seconds)
	var reach: float = tt.approach_seconds * (tuning.run_speed + pt.dash_speed_bonus) + tt.hop_seconds_max * tuning.run_speed \
		+ tt.intro_landing_seconds * tuning.run_speed
	check(reach < TrackBuilder.BUILD_AHEAD, "from its approach to an introduction's landing's end it's all built ahead (%.0f m)" % reach)


# --- Helpers ------------------------------------------------------------------------------------

## A hand-built track `lanes` wide with one teleporter, as its rules make one (_entry), its pad's front at PAD in `lane`,
## the way around on `side`, its output pads in `outs` (the left first).
func _layout(lanes: int, lane: int, side: int, outs: Array, light: int = 0, blink: float = 0.0, phase: float = 0.0,
		intro: bool = false) -> LevelLayout:
	var layout := RunSim.layout(lanes, 700.0)
	var config := LevelConfig.new()
	config.lane_count = lanes
	var gen: LevelGenerator = LevelGenerator.for_layout(config, tuning, layout)
	layout.teleporters.append(_entry(gen, lane, side, PAD, outs, light, blink, phase, intro))
	return layout


## A teleporter's entry as its rules make one (TeleporterRules._place) at `gen`'s level: its pad `lane`, the way around on
## `side`, its pad's front at `front`, its output pads in `outs` `hop` metres on (the middle hop at the run speed where
## it's 0), its light, blinking and phase; its calm stretches and span.
func _entry(gen: LevelGenerator, lane: int, side: int, front: float, outs: Array, light: int, blink: float, phase: float,
		intro: bool, hop: float = 0.0) -> Dictionary:
	var pad: float = TeleporterRules.pad_size(gen, tt)
	var approach: float = tt.approach_seconds * TeleporterRules.fastest(gen, pt)
	var landing: float = TeleporterRules.landing_length(gen, tt, pt, intro)
	var hops: PackedFloat32Array = tt.hops()
	var land: float = front + (hop if hop > 0.0 else hops[hops.size() / 2] * gen.speed)
	var outputs: Array[Dictionary] = []
	var calm: Array = [[lane, front - approach, front + pad]]
	for o: Variant in outs:
		outputs.append({"lane": int(o), "at": land, "end": land + pad})
		calm.append([-1 if intro else int(o), land - TeleporterRules.LANDING_BACK, land + landing])
	var tp := {"id": 0, "lane": lane, "at": front, "end": front + pad, "side": side, "outputs": outputs, "light": light,
		"blink": blink, "phase": phase, "calm": calm, "span": [front - approach, land + landing], "seed": 7}
	if intro:
		tp["intro"] = true
	return tp
