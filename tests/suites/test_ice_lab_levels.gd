extends TestSuite
## The Ice Lab's levels (task Q1; the owner, October 21, 2026, GDD §5 Zone 9: a frozen laboratory, the campaign's zone 9
## between the Terminal and the Golden Zone, three levels and no boss). How the campaign configures them off its difficulty
## curve and leaves every other level as it was, and saves from before it, are test_campaign's. Checked here:
## - the data: data/zones/ice_lab.tres between the Terminal and the Golden Zone (id ice_lab, "The Ice Lab", Frost Foundry,
##   Relay Station and Specimen Vault, its music track `ice_lab`, an intro and an outro slot, no boss slot, outside the
##   web demo, a skin: the Corporate zone's stands in until task Q2's), its run speed between its neighbours'; its levels:
##   off the curve, their own seeds, the core patterns, the walls every other zone has (the shared wall-gap numbers, no
##   arches) with wall running, doodads that push and stand as tall as every other zone's, no dash walls and none of the
##   Terminal's debris maze, a danger density dial between their neighbours'; their features: the cyborg gangsters (window
##   cyborgs among them), the Octodogs and the heli drones, and every obstacle and mechanic introduced before them (the
##   fence generators among them), but none of the other earlier enemies (KEEPS, LEAVES_OUT);
## - every build at 3, 5 and 6 lanes, on the levels' own seeds and OTHER_SEEDS, as the campaign configures it: no warnings,
##   the campaign's fairness checks (LayoutChecks.check_layout and check_rules), the same level on a second build, and the
##   Ice Lab's rules: no enemy but cyborgs, window cyborgs, Octodogs, heli drones and fence generators, no host among them;
##   no dash walls, floor cuts, debris maze or arches' stumps; wall running on and doodads that push; the usual obstacles
##   (holes, fences, signs, ceilings and their pads, the zone doodads); every feature of the level, but the ones sprinkled
##   in (the ceiling scenarios, LayoutChecks.occasional).
## The zone's own mechanics come with their tasks, which add their features to the levels (and their checks here): Q3's
## falling gantryways (all three levels, introduced in Frost Foundry: every build hangs the level's count of them, each
## where LayoutChecks.check_gantryways finds it fair; test_gantryways has the rest), Q4's teleporters (levels 2 and 3), Q5's
## Octodog jars, and later the zone's two new enemies (GDD §5, Level schedule). Nothing here stands in for them.

const ZONE_PATH: String = "res://data/zones/ice_lab.tres"
const CAMPAIGN_PATH: String = "res://data/campaign/campaign.tres"
const MUSIC_PATH: String = "res://data/audio/music_library.tres"
## The patterns every zone but the Terminal picks from (LevelConfig.patterns_path's default: the core folder).
const CORE_PATTERNS: String = "res://data/patterns/prototype_patterns.json"
## The Ice Lab's steps, in order, after the Terminal's outro and before the Golden Zone's intro.
const STEPS: Array[String] = ["ice_lab/intro", "ice_lab/1", "ice_lab/2", "ice_lab/3", "ice_lab/outro"]
## GDD §5 (proposed names).
const NAMES: Array[String] = ["Frost Foundry", "Relay Station", "Specimen Vault"]
## Seeds besides each level's own that every check also runs on.
const OTHER_SEEDS: Array[int] = [8801, 8802, 8803]
## The enemy types a build may hold (GDD §5, Zone 9: "cyborg gangsters, Octodogs and heli drones"): the cyborgs, the window
## cyborgs (GDD §9.2: cyborgs in the building windows; the task's call, docs/questions/q1.md), the Octodogs, the heli
## drones, and the fence generators, which are part of the electric fences (GDD §9.1), one of the usual obstacles.
const ENEMY_TYPES: PackedStringArray = ["cyborg", "window_cyborg", "octodog", "drone", "generator"]
## The features introduced before the Ice Lab that every one of its levels keeps (GDD §5, Zone 9, proposed: "the usual
## obstacles stay (gaps, electric fences, signs, ceilings and pads, doodads)", wall running and ceilings as in other zones;
## anything introduced earlier keeps appearing later): its enemies and every mechanic and obstacle. DESIGN-TBD
## (docs/questions/q1.md): the ones the design doesn't name (pulsing and wall fences, ramps, speed pads, wall gaps,
## wall-run gaps, the ceiling scenarios).
const KEEPS: PackedStringArray = ["cyborg", "ceilings", "pulsing", "window_cyborg", "ramps", "wall_gaps", "octodog", "speed_pads",
	"generator", "drone", "wall_run_gaps", "wall_fences", "treasure_stash", "fenced_ceiling", "wall_fences_partial"]
## The features introduced before the Ice Lab that it leaves out (GDD §5, Zone 9, proposed: "none of the other earlier
## enemies (screeches, trucks, turrets, Buzz Overdrives, Tithe Collectors, hosts and Bad Dreams, centipedes) ... no dash
## walls"), and the Terminal's debris maze, its doodads that stop the runner and its centipedes' home.
const LEAVES_OUT: PackedStringArray = ["hover_truck", "screech", "screech_vents", "barnacle_turret", "buzz_overdrive", "dash_wall",
	"tithe_collector", "enforcer_truck", "host", "debris_maze", "centipede"]


var campaign: Campaign
var zone: ZoneDef


func run() -> void:
	campaign = load(CAMPAIGN_PATH) as Campaign
	zone = load(ZONE_PATH) as ZoneDef
	check(campaign != null and zone != null, "the campaign and the Ice Lab's zone load")
	if campaign == null or zone == null:
		return
	_test_zone()
	_test_level_data()
	_test_levels()


func _test_zone() -> void:
	var at: int = campaign.zones.find(zone)
	check(at == 8 and at + 1 < campaign.zones.size() and campaign.zones[at - 1].id == &"terminal"
		and campaign.zones[at + 1].id == &"golden", "the campaign's zone 9 (%d), between the Terminal and the Golden Zone" % (at + 1))
	check(zone.id == &"ice_lab" and zone.display_name == "The Ice Lab" and zone.tagline != "" and zone.music == &"ice_lab"
		and not zone.in_demo and not zone.placeholder, "the Ice Lab's id, name, tagline and music track, outside the web demo")
	check(zone.boss == null and zone.boss_intro == null, "no boss (owner, October 21, 2026): it leads straight into the Golden Zone")
	check(zone.intro != null and zone.outro != null and String(zone.intro.id) == "ice_lab_intro"
		and String(zone.outro.id) == "ice_lab_outro" and zone.intro.is_built() and not zone.outro.is_built()
		and not zone.intro.is_skipped() and not zone.outro.is_skipped(),
		"an intro slot (the placeholder flyover) and an outro slot (a placeholder card)")
	# The zone's look is task Q2's (its own skin, and each level's own leaning: level 1 snow and industry, level 3 the lab,
	# through LevelConfig.skin_path); until it comes, an existing zone's stands in, named in the zone's data alone.
	check(zone.skin != null and zone.skin_path != "", "a skin, named by its path (the Corporate zone's stands in until task Q2's)")
	var terminal: ZoneDef = campaign.zones[at - 1] if at > 0 else null
	var golden: ZoneDef = campaign.zones[at + 1] if at >= 0 and at + 1 < campaign.zones.size() else null
	check(terminal != null and golden != null and zone.run_speed > terminal.run_speed and zone.run_speed < golden.run_speed,
		"it runs between the Terminal's speed and the Golden Zone's (%.1f m/s; DESIGN-TBD)" % zone.run_speed)
	# Its music (GDD §5, proposed: an earlier zone's song until the owner supplies or approves one): the track is in the
	# library, so the Music player plays it, and its levels play an earlier zone's song (test_audio checks which).
	var library := load(MUSIC_PATH) as MusicLibrary
	var song: StringName = library.run_track(zone.music)
	var earlier: bool = false
	for i: int in maxi(at, 0):
		earlier = earlier or library.run_track(campaign.zones[i].music) == song
	check(library.has(zone.music) and song != zone.music and earlier,
		"its track is in the library, and its levels play an earlier zone's song (%s; DESIGN-TBD)" % song)
	var ids: PackedStringArray = []
	for s: CampaignStep in campaign.steps():
		if s.zone == zone:
			ids.append(s.id)
	var first: CampaignStep = campaign.step(STEPS[0])
	check(ids == PackedStringArray(STEPS) and first != null and campaign.steps()[first.index - 1].id == "terminal/outro"
		and campaign.next_step(campaign.step(STEPS[-1])) == campaign.step("golden/intro"),
		"its steps: intro, Frost Foundry, Relay Station, Specimen Vault, outro, from the Terminal's outro to the Golden Zone's intro (%s)"
		% [ids])


func _test_level_data() -> void:
	var at: int = campaign.zones.find(zone)
	# Every feature the campaign introduces before the Ice Lab is kept or left out, by name: one added to an earlier zone
	# later fails here until it's decided for the Ice Lab.
	var before: Dictionary = {}
	for s: CampaignStep in campaign.steps():
		if s.is_level() and s.zone_index < at:
			for f: String in s.level.features:
				before[f] = true
	for f: String in before:
		check(KEEPS.has(f) != LEAVES_OUT.has(f), "`%s`, introduced before the Ice Lab, is kept or left out there (KEEPS, LEAVES_OUT)" % f)
	for f: String in KEEPS + LEAVES_OUT:
		check(before.has(f), "`%s` is introduced before the Ice Lab" % f)
	var later: Dictionary = {}
	for s: CampaignStep in campaign.steps():
		if s.is_level() and s.zone_index > at:
			for f: String in s.level.features:
				if not before.has(f):
					later[f] = true
	var seeds: Dictionary = {}
	for s: CampaignStep in campaign.steps():
		if s.is_level() and s.zone != zone:
			seeds[s.level.level_seed] = true
	var dial_before: float = campaign.step("terminal/2").level.danger_density_increase
	var dial_after: float = campaign.step("golden/1").level.danger_density_increase
	check(zone.levels.size() == 3, "three levels (GDD §5, Zone 9)")
	for n: int in mini(zone.levels.size(), 3):
		var level: LevelConfig = zone.levels[n]
		var tag: String = "ice_lab/%d" % (n + 1)
		check(String(level.id) == "ice_lab_%d" % (n + 1) and level.display_name == NAMES[n], "%s is %s" % [tag, NAMES[n]])
		check(level.off_curve and level.guarantee_features and level.minigame == null and not seeds.has(level.level_seed),
			"%s is off the difficulty curve, guarantees its features and has a seed of its own" % tag)
		check(level.patterns_path == CORE_PATTERNS, "%s picks from the core patterns, as every zone but the Terminal does" % tag)
		check(level.wall_gap_tuning == null and level.wall_running,
			"%s: the walls every other zone has (the shared wall-gap numbers), and they can be run on" % tag)
		check(level.doodad_share > 0.0 and not level.doodads_stop and level.doodad_height == 0.0 and level.debris_maze_tuning == null
			and is_equal_approx(level.movement_for(tuning).doodad_height, tuning.doodad_height),
			"%s: the zone doodads push, as tall as every other zone's (none of the Terminal's debris)" % tag)
		check(level.dash_walls == 0 and not level.has_feature("dash_wall"), "%s: no dash walls (GDD §5, Zone 9)" % tag)
		check(level.wide_gaps == 2 and level.charge_path_cyborgs == 1 and not level.buzz_company and level.wall_hop_lines == 1
			and level.fill_empty_seconds > 0.0,
			"%s: two wider gaps, a cyborg in an Octodog's charge path, wall-hop credits and the fill pass, as its neighbours" % tag)
		check(level.features_left_out.is_empty() and level.extended_wall_runs.is_empty() and not level.paced_in_bursts()
			and level.quiet_features.is_empty() and level.darkness == 0.0 and level.sky == null,
			"%s: none of another level's set pieces (The Hush's quiet stretches, darkness or extended wall runs), its zone's sky" % tag)
		check(level.danger_density_increase >= dial_before - 0.001 and level.danger_density_increase <= dial_after + 0.001,
			"%s: its danger density dial (%.2f) between Terminal 2's and Golden 1's" % [tag, level.danger_density_increase])
		for f: String in KEEPS:
			check(level.has_feature(f), "%s keeps `%s`" % [tag, f])
		for f: String in LEAVES_OUT:
			check(not level.has_feature(f), "%s leaves out `%s` (GDD §5, Zone 9: no other earlier enemy, no dash walls, no maze)" % [tag, f])
		for f: String in later:
			check(not level.has_feature(f), "%s has nothing of a later zone's (`%s`)" % [tag, f])
		# Nothing earlier is introduced again: a start only for a feature of the Ice Lab's own (tasks Q3 and Q4 bring theirs).
		for f: String in level.feature_starts:
			check(not before.has(f), "%s gives a start only to what it introduces (`%s`)" % [tag, f])
		# Task Q3: every level hangs falling gantryways, and Frost Foundry introduces them.
		check(level.has_feature("gantryway") and level.gantryways > 0 and level.feature_starts.has("gantryway") == (n == 0),
			"%s hangs falling gantryways (%d)%s" % [tag, level.gantryways, ", introducing them" if n == 0 else ""])


## Every build at 3, 5 and 6 lanes on the levels' own seeds and others, as the campaign configures it.
func _test_levels() -> void:
	var builds: int = 0
	var levels: int = 0
	var gantryways: int = 0
	var enemies: Dictionary = {}
	for n: int in [1, 2, 3]:
		var step: CampaignStep = campaign.step("ice_lab/%d" % n)
		for lanes: int in [3, 5, 6]:
			for k: int in OTHER_SEEDS.size() + 1:
				var config: LevelConfig = campaign.configure(step, lanes)
				if k > 0:
					config.level_seed = OTHER_SEEDS[k - 1]
				var tag: String = "%s lanes=%d seed=%d" % [step.id, lanes, config.level_seed]
				var patterns: Array = LevelGenerator.load_for(config)
				var gen: LevelGenerator = LayoutCache.generator(config, tuning, patterns)
				var layout: LevelLayout = gen.layout
				builds += gen.attempts
				levels += 1
				check(gen.warnings.is_empty(), "no warnings %s %s" % [tag, gen.warnings])
				LayoutChecks.check_layout(self, layout, config, tag)
				LayoutChecks.check_rules(self, layout, config, tag)
				if k == 0:
					var again: LevelLayout = LevelGenerator.new().generate(config, tuning, patterns)
					check(JSON.stringify(again.to_dict()) == JSON.stringify(layout.to_dict()), "the same level every attempt " + tag)
				check(layout.wall_running and not layout.doodads_stop and layout.wall_stumps.is_empty(),
					"its walls can be run on, its doodads push, and no arch stands for a wall %s" % tag)
				var others: Array = []
				for e: Dictionary in layout.enemies:
					var type: String = String(e["type"])
					var host: bool = bool((e.get("params", {}) as Dictionary).get("host", false))
					if host or not ENEMY_TYPES.has(type):
						others.append("%s%s" % [type, " (a host)" if host else ""])
					enemies[type] = int(enemies.get(type, 0)) + 1
				check(others.is_empty(), "no enemy but cyborgs, window cyborgs, Octodogs, heli drones and fence generators (%s) %s"
					% [others, tag])
				check(layout.dash_walls.is_empty() and layout.cuts.is_empty() and layout.maze.is_empty(),
					"no dash walls, floor cuts or debris maze %s" % tag)
				# Task Q3: as many falling gantryways as the level asks for (LayoutChecks.check_gantryways: each fair).
				check(layout.gantryways.size() == config.gantryways,
					"%d of the level's %d falling gantryways %s" % [layout.gantryways.size(), config.gantryways, tag])
				gantryways += layout.gantryways.size()
				check(not layout.gaps.is_empty() and not layout.fences.is_empty() and not layout.signs.is_empty()
					and not layout.hulls.is_empty() and not layout.pads.is_empty() and not layout.doodads.is_empty(),
					"the usual obstacles: %d holes, %d fences, %d signs, %d ceilings and %d pads, %d doodads %s" % [layout.gaps.size(),
						layout.fences.size(), layout.signs.size(), layout.hulls.size(), layout.pads.size(), layout.doodads.size(), tag])
				var placeable: PackedStringArray = gen.placeable_features(patterns)
				for f: String in config.features:
					if not LayoutChecks.can_locate(f):
						check(not placeable.has(f), "`%s` is planned: nothing places it yet %s" % [f, tag])
						continue
					check(not LayoutChecks.feature_positions(layout, f).is_empty() or LayoutChecks.occasional(f),
						"has `%s` (GDD §5: earlier features keep appearing) %s" % [f, tag])
	print("  the Ice Lab's builds: %.2f generator builds a level over %d levels; enemies %s; %d falling gantryways" % [
		float(builds) / maxf(levels, 1.0), levels, enemies, gantryways])
