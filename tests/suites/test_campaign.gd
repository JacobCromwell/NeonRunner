extends TestSuite
## The campaign data (GDD §5, §6, §10): six zones in order with 3/3/2/2/2/3 levels, their steps and
## ids, boss and cinematic slots, skins, music and the demo scope; the level-by-level schedule (where
## each feature first appears, later levels keeping it, one new thing at a time, late starts); the
## difficulty curve and level lengths; unlocking; and that every campaign level generates fairly for
## 3, 5 and 6 lanes.

## The zones in order and their level counts (GDD §5). Other tasks rely on these ids: skins at
## data/skins/<id>_skin.tres, music tracks named after them.
const ZONES: Array = [["city", 3], ["gangland", 3], ["marketplace", 2], ["corporate", 2], ["dead_zone", 2], ["golden", 3]]
## The level each feature first appears in (GDD §5's schedule; `screech_vents`, the shopfront vents
## of Marketplace 2, and `wall_fences_partial`, from the Corporate zone, are GDD §9.1 and §9.5).
const FIRST_LEVEL: Dictionary = {
	"cyborg": "city/1",
	"ceilings": "city/2",
	"pulsing": "city/3", "window_cyborg": "city/3", "hover_truck": "city/3",
	"screech": "gangland/1", "ramps": "gangland/1",
	"octodog": "gangland/2", "speed_pads": "gangland/2",
	"generator": "gangland/3", "drone": "gangland/3",
	"barnacle_turret": "marketplace/1",
	"wall_fences": "marketplace/2", "screech_vents": "marketplace/2",
	"buzz_overdrive": "corporate/1", "wall_fences_partial": "corporate/1",
	"tithe_collector": "corporate/2",
	"host": "dead_zone/1",
	"resonator": "golden/1",
	"gilded_sentinel": "golden/2",
}
## The documented exceptions to "anything introduced earlier keeps appearing later" (GDD §5): the
## levels that leave a feature out once it's introduced.
const LEFT_OUT: Dictionary = {
	# Manholes need a street: zones with other floors get wall-vent screeches (screech_vents) instead,
	# from Marketplace 2's shopfront vents on (GDD §5, proposed); Marketplace 1 has none (DESIGN-TBD).
	"screech": ["marketplace/1", "marketplace/2", "corporate/1", "corporate/2", "golden/1", "golden/2", "golden/3"],
	# In the Dead Zone's rubble street, `screech` brings manholes and wall vents both.
	"screech_vents": ["dead_zone/1", "dead_zone/2"],
	# GDD §9.9: the Buzz Overdrive appears in only two zones (DESIGN-TBD: Corporate and the Dead Zone).
	"buzz_overdrive": ["golden/1", "golden/2", "golden/3"],
	# GDD §9.12 (proposed): the Tithe Collector skips the Dead Zone and returns in the Golden Zone.
	"tithe_collector": ["dead_zone/1", "dead_zone/2"],
}
## Levels that bring nothing new (GDD §5): Dead Zone 2 is "a quiet, eerie remix", Golden 3 the
## Golden Palace.
const NOTHING_NEW: Array = ["dead_zone/2", "golden/3"]
## Features that are enemies (for "every zone introduces at least one new enemy").
const ENEMIES: Array = ["cyborg", "window_cyborg", "hover_truck", "screech", "octodog", "generator", "drone",
	"barnacle_turret", "buzz_overdrive", "tithe_collector", "host", "resonator", "gilded_sentinel"]


func run() -> void:
	var campaign := load("res://data/campaign/campaign.tres") as Campaign
	check(campaign != null, "the campaign loads")
	if campaign == null:
		return
	_test_zones(campaign)
	_test_steps(campaign)
	_test_slots(campaign)
	_test_schedule(campaign)
	_test_curve_and_lengths(campaign)
	_test_skins(campaign)
	_test_levels_generate(campaign)
	_test_unlocking()


## Six zones in GDD §5's order, each built, with its levels, skin, music and tagline; only the City
## is in the web demo.
func _test_zones(campaign: Campaign) -> void:
	check(campaign.zones.size() == ZONES.size(), "the campaign has six zones (GDD §5): %d" % campaign.zones.size())
	var library := load("res://data/audio/music_library.tres") as MusicLibrary
	for zi: int in mini(campaign.zones.size(), ZONES.size()):
		var zone: ZoneDef = campaign.zones[zi]
		var id: String = ZONES[zi][0]
		check(String(zone.id) == id, "zone %d is %s (%s)" % [zi + 1, id, zone.id])
		check(zone.levels.size() == ZONES[zi][1], "%s has %d levels (%d)" % [id, ZONES[zi][1], zone.levels.size()])
		check(not zone.placeholder, "%s is built, not a placeholder" % id)
		check(zone.display_name != "" and zone.tagline != "", "%s has a name and a tagline" % id)
		check(zone.skin != null, "%s has a skin" % id)
		check(zone.in_demo == (id == "city"), "%s %s the web demo (GDD §2)" % [id, "is in" if id == "city" else "isn't in"])
		# Zones name their track after their id; until the music task makes one, the Music player skips
		# it quietly (test_audio).
		check(zone.music == zone.id, "%s's music track is named after the zone" % id)
		if id in ["city", "gangland"]:
			check(library.has(zone.music), "%s's music exists" % id)
		check(zone.expected_loadout.is_empty(), "%s's expected loadout is still an empty placeholder (GDD §8)" % id)
	check(campaign.planned_level_count() == 15 and campaign.level_count() == 15, "15 levels (GDD §5)")


## Steps run intro, levels, boss intro, boss, outro per zone; step and level ids stay stable (the
## save file keys progress by step id), and Golden 3 is the Golden Palace.
func _test_steps(campaign: Campaign) -> void:
	var expected := PackedStringArray([
		"city/intro", "city/1", "city/2", "city/3", "city/boss_intro", "city/boss", "city/outro",
		"gangland/intro", "gangland/1", "gangland/2", "gangland/3", "gangland/boss", "gangland/outro",
		"marketplace/intro", "marketplace/1", "marketplace/2", "marketplace/boss", "marketplace/outro",
		"corporate/intro", "corporate/1", "corporate/2", "corporate/boss", "corporate/outro",
		"dead_zone/intro", "dead_zone/1", "dead_zone/2", "dead_zone/boss", "dead_zone/outro",
		"golden/intro", "golden/1", "golden/2", "golden/3", "golden/boss", "golden/outro"])
	var ids := PackedStringArray()
	for s: CampaignStep in campaign.steps():
		ids.append(s.id)
	check(ids == expected, "the campaign's steps, in order: %s" % ", ".join(ids))
	var seeds: Dictionary = {}
	var index: int = 0
	for s: CampaignStep in campaign.steps():
		if not s.is_level():
			continue
		var level_id: String = "%s_%d" % [s.zone.id, s.number_in_zone]
		check(String(s.level.id) == level_id and s.level.resource_path == "res://data/levels/%s.tres" % level_id,
			"step %s plays level %s from its own file (%s)" % [s.id, level_id, s.level.resource_path])
		check(s.level_index == index, "%s is campaign level %d" % [s.id, index + 1])
		check(s.level.display_name != "", "%s has a name" % s.id)
		check(not seeds.has(s.level.level_seed), "%s has its own fixed seed (GDD §6)" % s.id)
		seeds[s.level.level_seed] = true
		index += 1
	check(campaign.step("golden/3") != null and campaign.step("golden/3").title() == "The Golden Palace",
		"Golden 3 is the Golden Palace (GDD §5)")


## A boss slot per zone from GDD §10's roster, and cinematic slots: every zone's intro and outro, and
## the City's boss intro. All stay unbuilt slots for now.
func _test_slots(campaign: Campaign) -> void:
	var bosses: Dictionary = {"city": "Floating Head", "gangland": "Sewer Swarm", "marketplace": "The House",
		"corporate": "Hostile Takeover", "dead_zone": "Sleep Taker", "golden": "The final villain"}
	for zone: ZoneDef in campaign.zones:
		var id: String = String(zone.id)
		check(zone.boss != null and zone.boss.display_name == bosses.get(id, ""),
			"%s's boss slot is the %s (GDD §10)" % [id, bosses.get(id, "?")])
		check(zone.boss != null and String(zone.boss.id) == id + "_boss" and zone.boss.notes != "",
			"%s's boss slot has its id and notes" % id)
		check(zone.intro != null and zone.outro != null, "%s has intro and outro cinematic slots" % id)
		check((zone.boss_intro != null) == (id == "city"), "only the City has a boss-intro slot")
		for def: CinematicDef in [zone.intro, zone.boss_intro, zone.outro]:
			if def != null:
				check(String(def.id).begins_with(id + "_") and def.title != "" and def.placeholder_text != "",
					"cinematic slot %s has its id, title and text" % def.id)
	var golden: ZoneDef = campaign.zones[-1]
	check(golden.boss != null and golden.boss.notes.contains("checkpoint halfway"),
		"the final villain's slot notes the halfway checkpoint (GDD §10)")
	check(golden.boss != null and golden.boss.checkpoint_phase() == golden.boss.phase_count() - 1
		and golden.boss.phase_count() == 2, "and its data has the checkpoint at the second of its two stages")
	var head: BossDef = campaign.zones[0].boss
	check(head.phase_count() == 3 and is_equal_approx(head.phase_ends()[0], 2.0 / 3.0) and head.phase_list()[0].hits == 1
		and head.phase_list()[2].pace > head.phase_list()[0].pace,
		"the Floating Head has three phases, a stomp taking a third each, the later ones faster (GDD §10)")
	check(head.weapon_share_cap <= 1.0 / 3.0 + 0.01, "its weapons can save at most one of the three stomps (GDD §10)")
	for s: CampaignStep in campaign.steps():
		if s.kind == CampaignStep.Kind.BOSS:
			check(s.boss != null and not s.boss.is_built(), "boss slot %s is still a placeholder" % s.id)
		elif s.kind == CampaignStep.Kind.CINEMATIC:
			check(s.cinematic != null and not s.cinematic.is_built(), "cinematic slot %s is still a placeholder" % s.id)


## GDD §5's schedule in the level data: each feature first appears in its level; later levels keep
## it (with the documented exceptions); every zone brings a new enemy and each level about one new
## thing, each introduced at a start of its own (LevelConfig.feature_starts), City 1's cyborgs late.
func _test_schedule(campaign: Campaign) -> void:
	var levels: Array[CampaignStep] = []
	for s: CampaignStep in campaign.steps():
		if s.is_level():
			levels.append(s)
	var first_seen: Dictionary = {}
	var seen: Dictionary = {}
	for s: CampaignStep in levels:
		var fresh: PackedStringArray = []
		for f: String in s.level.features:
			check(LayoutChecks.known_feature(f), "%s's feature `%s` is one the game knows" % [s.id, f])
			if not seen.has(f):
				fresh.append(f)
				first_seen[f] = s.id
				seen[f] = true
		for f: String in fresh:
			check(s.level.feature_starts.has(f), "%s introduces `%s` at a start of its own" % [s.id, f])
		for f: String in s.level.feature_starts:
			check(fresh.has(f), "%s only gives starts to what it introduces (`%s`)" % [s.id, f])
		if s.id != "city/1":
			check(fresh.size() <= 3, "%s brings at most three new things (%s)" % [s.id, fresh])
			check(fresh.size() >= 1 or NOTHING_NEW.has(s.id), "%s brings something new (GDD §5)" % s.id)
		# Anything introduced earlier keeps appearing later (GDD §5), bar the documented exceptions.
		for f: String in seen:
			if not s.level.has_feature(f):
				check((LEFT_OUT.get(f, []) as Array).has(s.id), "%s keeps `%s` (introduced in %s)" % [s.id, f, first_seen[f]])
		if first_seen.has("screech") and s.id != "marketplace/1":
			check(s.level.has_feature("screech") or s.level.has_feature("screech_vents"),
				"%s keeps sewer screeches, from manholes or wall vents" % s.id)
	for f: String in FIRST_LEVEL:
		check(first_seen.get(f, "") == FIRST_LEVEL[f], "`%s` first appears in %s (%s)" % [f, FIRST_LEVEL[f], first_seen.get(f, "never")])
	for f: String in first_seen:
		check(FIRST_LEVEL.has(f), "`%s` has its place in the schedule" % f)
	for zone: Array in ZONES:
		var new_enemy: bool = false
		for f: String in first_seen:
			new_enemy = new_enemy or (ENEMIES.has(f) and String(first_seen[f]).begins_with(String(zone[0]) + "/"))
		check(new_enemy, "%s introduces at least one new enemy (GDD §5)" % zone[0])
	var city_1: LevelConfig = campaign.step("city/1").level
	check(city_1.feature_start("cyborg") >= 0.5, "City 1's cyborgs come late in the level (%.2f)" % city_1.feature_start("cyborg"))
	for id: String in ["marketplace/1", "marketplace/2", "corporate/1", "corporate/2", "golden/1", "golden/2", "golden/3"]:
		check(not campaign.step(id).level.has_feature("screech"), "no manholes in %s's floor" % id)
	var corporate_2: LevelConfig = campaign.step("corporate/2").level
	check(corporate_2.feature_weight("drone") > 1.0 and corporate_2.feature_weight("hover_truck") > 1.0,
		"Corporate 2 has a heavier military presence (GDD §5, proposed)")


## Each level is slightly harder than the last (GDD §6), up to Golden 2's peak (GDD §5, proposed);
## enemy scaling runs 0 → 1 across the campaign; levels last 90–150 s and add up to about 35 minutes
## (GDD §5).
func _test_curve_and_lengths(campaign: Campaign) -> void:
	var last_curve: float = -1.0
	for i: int in campaign.level_count():
		var d: float = campaign.curve_difficulty(i)
		check(d > last_curve, "the curve rises at level %d (%.2f)" % [i + 1, d])
		last_curve = d
	var difficulties: Array[float] = []
	var scaling: Array[float] = []
	var total: float = 0.0
	var steps: Array[CampaignStep] = []
	for s: CampaignStep in campaign.steps():
		if s.is_level():
			steps.append(s)
			var config: LevelConfig = campaign.configure(s, 5)
			difficulties.append(config.difficulty)
			scaling.append(config.enemy_scaling)
			total += s.level.duration_seconds
			check(s.level.duration_seconds >= 90.0 and s.level.duration_seconds <= 150.0,
				"%s lasts 90–150 s (GDD §4): %.0f s" % [s.id, s.level.duration_seconds])
	var peak: int = steps.find(campaign.step("golden/2"))
	for i: int in range(1, difficulties.size()):
		if i <= peak:
			check(difficulties[i] > difficulties[i - 1] + 0.02,
				"%s is harder than %s (%.2f after %.2f)" % [steps[i].id, steps[i - 1].id, difficulties[i], difficulties[i - 1]])
		else:
			check(difficulties[i] < difficulties[peak] and difficulties[i] > difficulties[peak - 1],
				"%s sits just below Golden 2's peak (%.2f)" % [steps[i].id, difficulties[i]])
		check(scaling[i] > scaling[i - 1], "enemy scaling rises at %s" % steps[i].id)
	check(peak == difficulties.size() - 2 and difficulties.max() == difficulties[peak], "Golden 2 is the hardest level")
	check(is_equal_approx(scaling[0], 0.0) and is_equal_approx(scaling[-1], 1.0), "enemy scaling runs 0 → 1 (GDD §6)")
	check(total >= 33.0 * 60.0 and total <= 37.0 * 60.0,
		"a flawless run through every level takes about 35 minutes (GDD §5): %.1f min" % (total / 60.0))
	var first: CampaignStep = campaign.step("city/1")
	var c1: LevelConfig = campaign.configure(first, 5)
	check(c1.lane_count == 5 and c1 != first.level, "configure returns a copy with the lane count")
	check(campaign.configure(steps[-1], 3, 1).difficulty >= campaign.configure(steps[-1], 3, 0).difficulty,
		"harder tiers never lower difficulty")
	check(campaign.configure(steps[4], 3, 1).difficulty > campaign.configure(steps[4], 3, 0).difficulty,
		"harder tiers raise difficulty")


## Levels take their zone's skin, the grey box until a zone has its own; a level's own skin wins (the
## Golden Palace may get one, GDD §5).
func _test_skins(campaign: Campaign) -> void:
	for s: CampaignStep in campaign.steps():
		if s.is_level():
			var config: LevelConfig = campaign.configure(s, 3)
			check(config.skin != null and config.skin == s.zone.skin, "%s takes its zone's skin" % s.id)
	for id: String in ["marketplace", "corporate", "dead_zone", "golden"]:
		var zone: ZoneDef = _zone(campaign, id)
		check(zone != null and zone.skin is GreyboxSkin, "%s uses the grey-box skin until it has its own" % id)
	var palace: CampaignStep = campaign.step("golden/3")
	var own_skin := GreyboxSkin.new()
	var step := CampaignStep.new()
	step.zone = palace.zone
	step.level = palace.level.duplicate() as LevelConfig
	step.level.skin = own_skin
	step.level_index = palace.level_index
	check(campaign.configure(step, 3).skin == own_skin, "a level's own skin wins over its zone's")
	check(palace.level.skin == null, "and the shipped level has none of its own yet")


## Every campaign level generates cleanly and fairly for every lane count: no pattern warnings, the
## shared fairness checks (LayoutChecks), nothing of a feature before its start, and each new
## feature right after its start. An introduction can come later when a fairness rule clears the
## introduced enemy away (a hover truck's lane), but that stays rare.
func _test_levels_generate(campaign: Campaign) -> void:
	var introductions: int = 0
	var late: PackedStringArray = []
	var reach: float = 210.0
	for s: CampaignStep in campaign.steps():
		if not s.is_level():
			continue
		for lanes: int in [3, 5, 6]:
			var config: LevelConfig = campaign.configure(s, lanes)
			var gen := LevelGenerator.new()
			var layout: LevelLayout = gen.generate(config, tuning, LevelGenerator.load_for(config))
			var tag: String = "%s lanes=%d" % [s.id, lanes]
			check(gen.warnings.is_empty(), "no pattern warnings %s %s" % [tag, gen.warnings])
			check(layout.gaps.size() + layout.fences.size() > 8, "has content " + tag)
			check(layout.credits.size() > 20, "has credits " + tag + " (%d)" % layout.credits.size())
			for c: Dictionary in layout.credits:
				if c["surface"] != "wall":
					check(int(c["lane"]) >= 0 and int(c["lane"]) < lanes, "credit lane in range " + tag)
			LayoutChecks.check_layout(self, layout, config, tag)
			LayoutChecks.check_rules(self, layout, config, tag)
			for f: String in ["ceilings", "ramps", "speed_pads", "pulsing"]:
				if not config.has_feature(f):
					check(LayoutChecks.feature_positions(layout, f).is_empty(), "no `%s` before they're introduced %s" % [f, tag])
			for f: String in config.feature_starts:
				if not LayoutChecks.can_locate(f):
					continue  # a planned feature: nothing places it yet
				var start: float = gen.feature_start(f)
				var at: Array[float] = LayoutChecks.feature_positions(layout, f)
				check(at.is_empty() or at[0] >= start - 0.01, "nothing of `%s` before its start (%.0f m) %s" % [f, start, tag])
				check(not at.is_empty(), "%s shows `%s`, which it introduces %s" % [s.id, f, tag])
				introductions += 1
				if at.is_empty() or at[0] > start + reach:
					late.append("%s %s (%s)" % [tag, f, "none" if at.is_empty() else "%.2f" % (at[0] / layout.length)])
	# 13 introductions of built features, at 3 lane counts each; more as the planned enemies are built.
	check(introductions >= 39, "introductions checked: %d" % introductions)
	check(late.size() * 10 <= introductions, "introductions land right after their start: late ones %s of %d" % [late, introductions])


## Unlocking follows the campaign order (with a fresh profile); the web demo covers Zone 1 only.
func _test_unlocking() -> void:
	var app: Node = tree.root.get_node_or_null(^"App")
	if app == null:
		return
	var saved: Profile = App.profile
	App.profile = Profile.new()
	var steps: Array[CampaignStep] = App.campaign.steps()
	check(App.step_unlocked(steps[0]) and not App.step_unlocked(steps[1]), "only the first step is open at first")
	App.complete_step(steps[0])
	check(App.step_unlocked(steps[1]) and App.next_unfinished_step() == steps[1], "finishing a step opens the next")
	BuildFlavor.set_override(BuildFlavor.Kind.WEB_DEMO)
	check(App.in_demo_scope(steps[1]) and not App.in_demo_scope(App.campaign.step("gangland/1"))
		and not App.in_demo_scope(App.campaign.step("golden/3")), "the web demo covers Zone 1 only (GDD §2)")
	BuildFlavor.set_override(-1)
	check(App.in_demo_scope(App.campaign.step("golden/boss")), "the full game covers everything")
	App.profile = saved


func _zone(campaign: Campaign, id: String) -> ZoneDef:
	for zone: ZoneDef in campaign.zones:
		if String(zone.id) == id:
			return zone
	return null
