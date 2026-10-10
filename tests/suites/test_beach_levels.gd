extends TestSuite
## The Beach's levels: the campaign's zone 6 (task D10c; the owner, October 9, 2026: "put the beach between the
## corporate and dead zone", a boss battle to come, no new enemies for now), with the open side walls of task D10b
## (the owner, October 9, 2026: the Beach should "feel more open ... much longer sections where there aren't
## sidewalls", its side walls appearing "about 50% of the time that they are now"). How the campaign configures
## them off its difficulty curve, and leaves every other level as it was, is test_campaign's. Checked here:
## - the data: data/zones/beach.tres, the campaign's zone 6 between Corporate and the Dead Zone (id beach, the Beach
##   skin, Tiki Tides, the volleyball match (Net Gains, beach/2: the owner, October 10, 2026; a mini-game, played by
##   test_volleyball) and Sunset Strip, now beach/3, its music track `beach`, a stand-in on tracks the game has, its intro and
##   outro cinematic slots and its boss slot, a placeholder, outside the web demo); its levels: Corporate 2's
##   features (a remix, no new enemy assets), nothing introduced, off the campaign's difficulty curve, a
##   difficulty, enemy scaling, danger density and run speed between Corporate 2's and Dead Zone 1's, durations of
##   145 and 150 s, seeds of their own, the open-walls tuning (data/tuning/beach_wall_gaps.tres, whose margins
##   that time a wall run are the shared ones), and Beach 1 with no sky of its own (the zone's daylight), its last
##   level with the sunset (data/skies/beach_sunset.tres);
## - every build at 3, 5 and 6 lanes, on the levels' own seeds and OTHER_SEEDS, as the campaign configures it
##   (Campaign.configure): no warnings, the length its duration makes at the zone's speed, the campaign's fairness
##   checks (LayoutChecks.check_layout and check_rules), every feature the level lists in the layout (on other
##   seeds the Enforcer Truck, which only comes where a bait's chase has room, in nearly every build);
## - the open walls: each wall stands on ACCEPT of the level, or more only where its keep-outs leave it no more
##   free, never on less than 1 - coverage_target; over all the builds the median wall stands in AIM; every gap
##   at least open_seconds_min long, between the run-up and the end-clear stretch, clear of its wall's keep-outs
##   (WallGapPlacement.keep_outs: signs, wall fences, wall enemies, ceilings reaching the wall, ramps' launches
##   and longest wall runs, wider gaps), the wall standing at least solid_seconds_min between two of them (so the
##   walls never flicker); most of the open length in stretches of 100 m and more; both walls open at once on no
##   more than both_open_max of the level; the same gaps on a second build;
## - what the walls hold, checked on its own rather than through keep_outs (so a keep-out it forgot would show):
##   every sign, wall fence, wall enemy, ceiling reaching a wall, ramp launch with its longest wall run, wall
##   credit and wider gap's walls on solid wall;
## - the wall features still there: on the levels' own seeds, the same level with the shared tuning is the same
##   level but for its wall gaps (the signs, wall fences, ramps, window cyborgs and wall vents all stay where
##   they are, and only wall credits go);
## - the command line: --level=beach/1 plays its campaign step with the full flow, past its level introduction,
##   the runner running (tools/smoke/smoke_play.gd in a child process, as test_smoke_play does).

const ZONE_PATH: String = "res://data/zones/beach.tres"
const SKIN_PATH: String = "res://data/skins/beach_skin.tres"
const OPEN_WALLS_PATH: String = "res://data/tuning/beach_wall_gaps.tres"
const CAMPAIGN_PATH: String = "res://data/campaign/campaign.tres"
const MUSIC_PATH: String = "res://data/audio/music_library.tres"
const SMOKE_TOOL: String = "res://tools/smoke/smoke_play.gd"
## The generated levels (the volleyball match between them is a mini-game, MATCH): their steps, lengths (DESIGN-TBD,
## docs/OPEN_QUESTIONS.md, item 567: like their neighbours, Corporate 2 and Dead Zone 1) and names (GDD §5, October 9,
## 2026).
const NUMBERS: Array[int] = [1, 3]
const DURATIONS: Array[float] = [145.0, 150.0]
const NAMES: Array[String] = ["Tiki Tides", "Sunset Strip"]
## The volleyball match (the owner, October 10, 2026), the zone's second level.
const MATCH: int = 2
## The Beach's neighbours in the campaign (the owner, October 9, 2026: between Corporate and the Dead Zone).
const BEFORE: String = "corporate/2"
const AFTER: String = "dead_zone/1"
## The Beach's steps, in order, after Corporate's outro and before the Dead Zone's intro.
const STEPS: Array[String] = ["beach/intro", "beach/1", "beach/2", "beach/3", "beach/boss", "beach/outro"]
## Seeds besides each level's own that every check also runs on.
const OTHER_SEEDS: Array[int] = [8801, 8802]
## The share of the level each side wall stands on (the owner: about half as often as the 96-97% elsewhere):
## the median over every build aims for AIM, and every wall stands within ACCEPT unless its keep-outs leave it
## no more than FORCED_SLACK of the level more free (in stretches long enough to open) than it opened.
const AIM := Vector2(0.45, 0.55)
const ACCEPT := Vector2(0.40, 0.60)
const FORCED_SLACK: float = 0.03
## The open stretches are long: at least this share of all the open length (over every build) lies in stretches
## of LONG_METRES and more.
const LONG_METRES: float = 100.0
const LONG_SHARE: float = 0.7
## The Enforcer Truck has no patterns, so the generator's guarantee can't force one: its rules bring it in where a
## bait's chase has room (enforcer_truck_rules.gd). Every build on the levels' own seeds has one; on other seeds
## at least this share of the builds (without Corporate 2's heavier military weights, 53 of 54 builds over their
## own seeds and eight others had one, October 2026).
const ENFORCER: String = "enforcer_truck"
const TRUCK_SHARE: float = 0.8
const SMOKE_FRAMES: int = 240

var campaign: Campaign
var zone: ZoneDef


func run() -> void:
	campaign = load(CAMPAIGN_PATH) as Campaign
	zone = load(ZONE_PATH) as ZoneDef
	check(zone != null, "the Beach zone loads")
	if zone == null:
		return
	_test_data()
	_test_levels()
	_test_command_line()


func _test_data() -> void:
	check(zone.id == &"beach" and zone.display_name == "Beach" and zone.tagline != "", "the zone is the Beach, named, with a tagline")
	check(zone.skin != null and zone.skin.resource_path == SKIN_PATH, "in the Beach skin")
	# Its place: between Corporate and the Dead Zone (the owner, October 9, 2026): zone 6, after the Casino (zone 4).
	var at: int = campaign.zones.find(zone)
	check(at > 0 and at + 1 < campaign.zones.size() and campaign.zones[at - 1].id == &"corporate"
		and campaign.zones[at + 1].id == &"dead_zone", "the campaign's zone %d, between Corporate and the Dead Zone" % (at + 1))
	var ids := PackedStringArray()
	for s: CampaignStep in campaign.steps():
		if s.zone == zone:
			ids.append(s.id)
	var first: CampaignStep = campaign.step(STEPS[0])
	check(ids == PackedStringArray(STEPS) and first != null and campaign.steps()[first.index - 1].id == "corporate/outro"
		and campaign.next_step(campaign.step(STEPS[-1])).id == "dead_zone/intro",
		"its steps run %s, after Corporate's outro and before the Dead Zone's intro (%s)" % [", ".join(STEPS), ", ".join(ids)])
	# No new songs (GDD §11): its track borrows ones the game has (DESIGN-TBD, docs/OPEN_QUESTIONS.md, item 577).
	var library := load(MUSIC_PATH) as MusicLibrary
	check(zone.music == &"beach" and library.has(zone.music) and library.path(zone.music) == library.path(&"marketplace")
		and library.has(library.run_track(zone.music)) and library.run_track(zone.music) != zone.music,
		"its music track `beach` plays the game's existing tracks: %s in cinematics, %s in its levels" % [
			library.path(zone.music).get_file(), library.path(library.run_track(zone.music)).get_file()])
	check(zone.intro != null and zone.intro.is_built() and zone.outro != null and not zone.outro.is_built() and zone.boss_intro == null,
		"its intro plays the arrival flyover, its outro is a placeholder card, and it has no boss intro")
	# The owner, October 9, 2026: "there will be a boss battle for the beach, but it has not yet been created".
	check(zone.boss != null and zone.boss.id == &"beach_boss" and not zone.boss.is_built() and zone.boss.preview() == null,
		"its boss slot is a placeholder: the campaign passes through it")
	check(not zone.in_demo, "outside the web demo")
	var before: CampaignStep = campaign.step(BEFORE)
	var after: CampaignStep = campaign.step(AFTER)
	check(zone.run_speed > before.zone.run_speed and zone.run_speed < after.zone.run_speed,
		"its run speed (%.1f m/s) lies between Corporate's and the Dead Zone's" % zone.run_speed)
	var before_config: LevelConfig = campaign.configure(before, 5)
	var after_config: LevelConfig = campaign.configure(after, 5)
	check(zone.levels.size() == 3 and zone.levels[MATCH - 1].plays_minigame()
		and campaign.step("beach/%d" % MATCH).level == zone.levels[MATCH - 1],
		"three levels, the volleyball match second (%d)" % zone.levels.size())
	var seeds: Array[int] = []
	for s: CampaignStep in campaign.steps():
		if s.is_level() and s.zone != zone:
			seeds.append(s.level.level_seed)
	var previous := -1.0
	for i: int in mini(NUMBERS.size(), DURATIONS.size()):
		var number: int = NUMBERS[i]
		var level: LevelConfig = zone.levels[number - 1] if number <= zone.levels.size() else null
		if level == null:
			continue
		var tag: String = "(beach/%d)" % number
		check(String(level.id) == "beach_%d" % number and level.resource_path == "res://data/levels/beach_%d.tres" % number
			and level.display_name == NAMES[i], "its id, file and name, %s %s" % [NAMES[i], tag])
		check(campaign.step("beach/%d" % number).level == level and not level.plays_minigame(),
			"the campaign plays it as beach/%d, a generated level" % number)
		# Corporate 2's but its dash walls (the H series' merge: none in the Beach for now, its open side walls;
		# docs/OPEN_QUESTIONS.md item 680).
		var remix: PackedStringArray = PackedStringArray(before.level.features)
		remix.erase("dash_wall")
		check(level.features == remix and before.level.features.has("dash_wall"),
			"Corporate 2's features but its dash walls, a remix with no new enemy %s" % tag)
		check(level.feature_starts.is_empty() and level.guarantee_features, "introduces nothing, guarantees every feature %s" % tag)
		check(level.off_curve, "off the campaign's difficulty curve: its own difficulty and enemy scaling %s" % tag)
		check(level.difficulty > before_config.difficulty and level.difficulty < after_config.difficulty and level.difficulty >= previous,
			"its difficulty (%.2f) lies between Corporate 2's (%.2f) and Dead Zone 1's (%.2f), rising %s" % [level.difficulty,
				before_config.difficulty, after_config.difficulty, tag])
		previous = level.difficulty
		check(level.enemy_scaling > before_config.enemy_scaling and level.enemy_scaling < after_config.enemy_scaling,
			"its enemy scaling (%.2f) lies between Corporate 2's and Dead Zone 1's %s" % [level.enemy_scaling, tag])
		check(level.danger_density_increase >= before.level.danger_density_increase
			and level.danger_density_increase <= after.level.danger_density_increase,
			"its danger density lies between Corporate 2's and Dead Zone 1's %s" % tag)
		check(is_equal_approx(level.duration_seconds, DURATIONS[i]) and level.wide_gaps == 2
			and is_equal_approx(level.narrow_ceiling_share, before.level.narrow_ceiling_share) and level.doodad_share > 0.0,
			"its length, wider gaps, narrow ceilings and doodads like its neighbours' %s" % tag)
		check(is_zero_approx(level.run_speed), "it runs at its zone's speed %s" % tag)
		check(not seeds.has(level.level_seed), "a seed of its own (%d) %s" % [level.level_seed, tag])
		seeds.append(level.level_seed)
		check(level.wall_gap_tuning != null and level.wall_gap_tuning.resource_path == OPEN_WALLS_PATH
			and level.wall_gap_tuning.opens_walls(), "its walls open by the Beach's numbers %s" % tag)
	check(zone.levels[0].sky == null, "Beach 1 has no sky of its own: the zone's daylight")
	# The owner (October 9, 2026): the last level shows the sun starting to set, not dark.
	var last: LevelConfig = zone.levels[zone.levels.size() - 1]
	check(last.sky != null and last.sky.resource_path == "res://data/skies/beach_sunset.tres",
		"the Beach's last level shows its sunset (data/skies/beach_sunset.tres)")
	# The Beach's numbers: open walls, and the margins that time a wall run (a ramp's launch and longest run, a
	# wall enemy's wall entry) the shared ones; only the clearance around signs, wall fences and ceilings is its own
	# (narrower), which keep_outs never lets narrow those margins (test_wall_gaps checks the keep-outs themselves).
	var open := load(OPEN_WALLS_PATH) as WallGapTuning
	var shared: WallGapTuning = WallGapPlacement.tuning()
	check(open.opens_walls() and open.both_open_max < 0.5, "the Beach's walls open, both at once on less than half the level")
	check(is_equal_approx(open.ramp_before_seconds, shared.ramp_before_seconds)
		and is_equal_approx(open.ramp_after_seconds, shared.ramp_after_seconds)
		and is_equal_approx(open.wall_enemy_seconds, shared.wall_enemy_seconds)
		and open.clear_seconds > 0.0 and open.clear_seconds < shared.clear_seconds,
		"the Beach keeps the shared margins around ramps and wall enemies; only its clearance is narrower")


## Every build of both levels (see the header), then the open walls' figures over all of them.
func _test_levels() -> void:
	var stats := {"stands": [] as Array[float], "open": 0.0, "long": 0.0, "stretches": 0, "both": [] as Array[float],
		"trucks": 0, "truck_builds": 0, "between": [] as Array[float], "pieces": {}}
	for number: int in NUMBERS:
		for lanes: int in [3, 5, 6]:
			for level_seed: int in [0] + OTHER_SEEDS:
				var config: LevelConfig = campaign.configure(campaign.step("beach/%d" % number), lanes)
				if level_seed != 0:
					config.level_seed = level_seed
				_check_level(config, "beach/%d lanes=%d seed=%d" % [number, lanes, config.level_seed], level_seed == 0, stats)
	var stands: Array[float] = stats["stands"]
	stands.sort()
	var median: float = stands[stands.size() / 2]
	check(median >= AIM.x and median <= AIM.y, "the median wall stands on %.1f%% of its level (aim %.0f-%.0f%%)" % [
		median * 100.0, AIM.x * 100.0, AIM.y * 100.0])
	var long_share: float = float(stats["long"]) / maxf(float(stats["open"]), 1.0)
	check(long_share >= LONG_SHARE, "most of the open length in stretches of %.0f m and more (%.0f%%)" % [LONG_METRES, long_share * 100.0])
	check(int(stats["trucks"]) >= ceili(TRUCK_SHARE * int(stats["truck_builds"])),
		"an Enforcer Truck on other seeds in nearly every build (%d of %d)" % [stats["trucks"], stats["truck_builds"]])
	var aimed: int = 0
	for s: float in stands:
		aimed += 1 if s >= AIM.x and s <= AIM.y else 0
	var both: Array[float] = stats["both"]
	both.sort()
	var between: Array[float] = stats["between"]
	between.sort()
	print("  beach walls stand %.1f-%.1f%% (median %.1f%%; %d of %d walls in %.0f-%.0f%%); %d open stretches, %.0f%% of the open length in %.0f m and more; both open %.1f-%.1f%%; %d standing pieces between two open stretches, the shortest %.0f m" % [
		stands[0] * 100.0, stands[-1] * 100.0, median * 100.0, aimed, stands.size(), AIM.x * 100.0, AIM.y * 100.0,
		int(stats["stretches"]), long_share * 100.0, LONG_METRES, both[0] * 100.0, both[-1] * 100.0, between.size(),
		between[0] if not between.is_empty() else 0.0])
	print("  on solid wall in every build: %s" % [stats["pieces"]])


## One build of a Beach level (`own`: on its own seed): fairness, features, open walls (_check_open_walls), and on
## its own seed the same gaps on a second build and the same level with the shared tuning but for its gaps.
func _check_level(config: LevelConfig, tag: String, own: bool, stats: Dictionary) -> void:
	var patterns: Array = LevelGenerator.load_for(config)
	var gen: LevelGenerator = LayoutCache.generator(config, tuning, patterns)
	var layout: LevelLayout = gen.layout
	var movement: MovementTuning = config.movement_for(tuning)
	var seconds: float = config.duration_seconds
	check(gen.warnings.is_empty(), "no warnings %s %s" % [tag, gen.warnings])
	check(is_equal_approx(gen.speed, zone.run_speed), "built at the zone's run speed (%.1f m/s) %s" % [gen.speed, tag])
	check(is_equal_approx(layout.length, movement.run_speed * seconds + 0.5 * movement.speed_gain_per_minute / 60.0 * seconds * seconds),
		"the finish line matches %.0f s %s" % [seconds, tag])
	check(layout.gaps.size() + layout.fences.size() > 8 and layout.credits.size() > 20, "has content and credits " + tag)
	LayoutChecks.check_layout(self, layout, config, tag)
	LayoutChecks.check_rules(self, layout, config, tag)
	var placeable: PackedStringArray = gen.placeable_features(patterns)
	for f: String in config.features:
		if not LayoutChecks.can_locate(f):
			check(not placeable.has(f), "`%s` is planned: nothing places it yet %s" % [f, tag])
			continue
		var present: bool = not LayoutChecks.feature_positions(layout, f).is_empty()
		if f == ENFORCER and not own:
			# It has no patterns for the guarantee to force: its rules bring one in only where a bait's chase has
			# room (enforcer_truck_rules.gd). Counted over the other seeds' builds (_test_levels).
			stats["truck_builds"] = int(stats["truck_builds"]) + 1
			stats["trucks"] = int(stats["trucks"]) + (1 if present else 0)
			continue
		check(present, "has `%s` %s" % [f, tag])
	check(not layout.signs.is_empty(), "has wall signs " + tag)
	_check_open_walls(gen, config, tag, stats)
	_check_wall_pieces(gen, tag, stats)
	if not own:
		return
	var again: LevelLayout = LevelGenerator.new().generate(config, tuning, patterns)
	check(JSON.stringify(again.wall_gaps) == JSON.stringify(layout.wall_gaps), "the same gaps every attempt " + tag)
	# The wall features stay: with the shared tuning, the level is the same level but for its gaps.
	var shared_config: LevelConfig = config.duplicate() as LevelConfig
	shared_config.wall_gap_tuning = null
	var shared: LevelLayout = LayoutCache.generate(shared_config, tuning, patterns)
	var a: Dictionary = layout.to_dict()
	var b: Dictionary = shared.to_dict()
	for key: String in ["wall_gaps", "credits"]:
		a.erase(key)
		b.erase(key)
	check(JSON.stringify(a) == JSON.stringify(b),
		"the open walls change nothing but the gaps: the signs, wall fences, ramps and wall enemies stay %s" % tag)
	var kept: bool = true
	for c: Dictionary in layout.credits:
		kept = kept and shared.credits.has(c)
	check(kept, "the open walls only take wall credits away %s" % tag)


## The open walls of one build (see the header), adding its figures to `stats`.
func _check_open_walls(gen: LevelGenerator, config: LevelConfig, tag: String, stats: Dictionary) -> void:
	var layout: LevelLayout = gen.layout
	var t: WallGapTuning = WallGapPlacement.tuning_for(config)
	var length: float = layout.length
	var from: float = config.start_clear_distance
	var last: float = length - config.end_clear_distance
	var min_open: float = t.open_seconds_min * gen.speed
	var min_solid: float = t.solid_seconds_min * gen.speed
	var sides: Array = []
	for side: int in [-1, 1]:
		var w: String = "(wall %d) %s" % [side, tag]
		var spans: Array[Vector2] = layout.wall_gap_spans(side, -INF, INF)
		sides.append(spans)
		var keeps: Array[Vector2] = WallGapPlacement.keep_outs(gen, layout, side, t)
		var prev: float = -INF
		for g: Vector2 in spans:
			check(g.y - g.x >= min_open - 0.01, "an open stretch at least open_seconds_min long (%.1f m) %s" % [g.y - g.x, w])
			check(g.x >= from and g.y <= last, "open between the run-up and the end-clear stretch %s" % w)
			if prev > -INF:
				# The walls never flicker: a wall that stands again between two open stretches stands at least
				# solid_seconds_min, however little holds it up (a lone wall fence, a sign).
				check(g.x - prev >= min_solid - 0.01, "the wall stands at least solid_seconds_min between two open stretches (%.1f m from %.0f m) %s"
					% [g.x - prev, prev, w])
				(stats["between"] as Array[float]).append(g.x - prev)
			prev = g.y
			for kp: Vector2 in keeps:
				check(not (g.x < kp.y - 0.01 and g.y > kp.x + 0.01), "gap %s clear of keep-out %s %s" % [g, kp, w])
			stats["open"] = float(stats["open"]) + g.y - g.x
			stats["long"] = float(stats["long"]) + (g.y - g.x if g.y - g.x >= LONG_METRES else 0.0)
			stats["stretches"] = int(stats["stretches"]) + 1
		var open: float = WallGapPlacement.span_total(spans)
		var stands: float = 1.0 - open / length
		(stats["stands"] as Array[float]).append(stands)
		var free: float = WallGapPlacement.span_total(WallGapPlacement.open_stretches(keeps, from, last, min_open))
		check(open <= t.coverage_target * length + 0.01, "open on no more than its target %s" % w)
		check(stands >= ACCEPT.x and (stands <= ACCEPT.y or open >= free - FORCED_SLACK * length),
			"stands on %.1f%% of the level (%.0f-%.0f%%, or more only where its keep-outs leave it no more free: %.1f%% free) %s"
			% [stands * 100.0, ACCEPT.x * 100.0, ACCEPT.y * 100.0, free / length * 100.0, w])
	var both: float = WallGapPlacement.span_total(WallGapPlacement.spans_overlap(sides[0], sides[1]))
	(stats["both"] as Array[float]).append(both / length)
	check(both <= t.both_open_max * length + 0.01, "both walls open at once on %.1f%% of the level, at most %.0f%% %s" % [
		both / length * 100.0, t.both_open_max * 100.0, tag])


## What the walls hold, on solid wall in one build, checked on its own rather than through WallGapPlacement.keep_outs
## (so a keep-out it forgot would show): every sign and wall fence over its whole length, every wall enemy (a window
## cyborg, a wall vent, a hover truck's burst, a Gilded Sentinel) a metre either side of its spot, every ceiling
## reaching a wall over its length, every ramp from its launch to the end of its longest wall run
## (WallFencePlacement.ramp_run_end: with claws and a speed pad's boost), every wall credit, and both walls over
## every wider gap (a runner on them is never dropped into one). Counts them into `stats`.
func _check_wall_pieces(gen: LevelGenerator, tag: String, stats: Dictionary) -> void:
	var layout: LevelLayout = gen.layout
	var counts: Dictionary = stats["pieces"]
	var outer_lanes: Dictionary = {-1: layout.outer_lane(-1), 1: layout.outer_lane(1)}
	for s: Dictionary in layout.signs:
		_on_wall(layout, int(s["side"]), float(s["start"]), float(s["end"]), "sign", tag, counts)
	var fence_half: float = gen.tuning.fence_depth * 0.5
	for f: Dictionary in layout.wall_fences:
		_on_wall(layout, int(f["side"]), float(f["at"]) - fence_half, float(f["at"]) + fence_half, "wall fence", tag, counts)
	for e: Dictionary in layout.enemies:
		var side: int = int(e.get("side", 0))
		if side != 0:
			_on_wall(layout, side, float(e["at"]) - 1.0, float(e["at"]) + 1.0, String(e["type"]), tag, counts)
	for h: Dictionary in layout.hulls:
		for side: int in [-1, 1]:
			if layout.hull_covers(h, int(outer_lanes[side])):
				_on_wall(layout, side, float(h["start"]), float(h["end"]), "ceiling", tag, counts)
	for r: Dictionary in layout.ramps:
		_on_wall(layout, int(r["side"]), float(r["at"]), WallFencePlacement.ramp_run_end(gen, r), "ramp's wall run", tag, counts)
	for c: Dictionary in layout.credits:
		if c["surface"] == "wall":
			_on_wall(layout, int(c["side"]), float(c["at"]), float(c["at"]), "wall credit", tag, counts)
	for row: Vector2 in WideGapPlacement.rows_of(gen):
		for side: int in [-1, 1]:
			_on_wall(layout, side, row.x, row.y, "wall beside a wider gap", tag, counts)


## Checks that wall `side` is solid over [from, to] (no wall gap overlaps it), counting `what` in `counts`.
func _on_wall(layout: LevelLayout, side: int, from: float, to: float, what: String, tag: String, counts: Dictionary) -> void:
	var gaps: Array[Vector2] = layout.wall_gap_spans(side, from - 0.001, to + 0.001)
	check(gaps.is_empty(), "%s on wall %d over %.1f-%.1f m stands on solid wall (gaps %s) %s" % [what, side, from, to, gaps, tag])
	counts[what] = int(counts.get(what, 0)) + 1


## The command line: --level=beach/1 is the Beach's campaign step, with the full flow (its level introduction, then
## the run), played end to end in a child process.
func _test_command_line() -> void:
	if OS.get_name() != "Linux" or not FileAccess.file_exists("/usr/bin/env"):
		check(true, "skipped: the smoke tool's child process needs /usr/bin/env")
		return
	var played: String = _smoke(["--level=beach/1", "--lanes=5", "--god", "--nofall"])
	check(played.contains("PLAY pressed") and not played.contains("smoke:") and not played.contains("SCRIPT ERROR"),
		"--level=beach/1 plays the campaign step past its level introduction with no problem:\n%s" % played)
	check(_distance(played) > 5.0, "--level=beach/1: the runner ran %.1f m in %d frames:\n%s" % [_distance(played), SMOKE_FRAMES, played])


## The smoke tool's output for `args` (game args), SMOKE_FRAMES frames long, with its report on (test_smoke_play's
## way: its own XDG_DATA_HOME, so its saves leave this run's profile alone).
func _smoke(args: Array[String]) -> String:
	var dir: String = OS.get_user_data_dir().path_join("smoke_child")
	DirAccess.make_dir_recursive_absolute(dir)
	var argv := PackedStringArray(["XDG_DATA_HOME=" + dir, OS.get_executable_path(), "--headless", "--path",
		ProjectSettings.globalize_path("res://"), "--fixed-fps", "60", "-s", SMOKE_TOOL, "--",
		"--smoke-frames=%d" % SMOKE_FRAMES, "--smoke-report"])
	argv.append_array(PackedStringArray(args))
	var output: Array = []
	OS.execute("/usr/bin/env", argv, output, true)
	return "\n".join(output)


## The "furthest distance N m" of the smoke tool's report, 0 when it has none.
func _distance(text: String) -> float:
	var at: int = text.find("furthest distance ")
	return text.substr(at + 18).to_float() if at >= 0 else 0.0
