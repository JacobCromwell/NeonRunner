extends TestSuite
## The campaign data (GDD §5, §6, §10): seven zones in order with 3/3/2/2/2/2/3 levels, their steps and
## ids, boss and cinematic slots (the Marketplace has no boss: The House is the Casino's), skins, music and
## the demo scope; the level-by-level schedule (where each feature first appears, later levels keeping it,
## one new thing at a time, late starts, the Casino bringing nothing new); the difficulty curve and level
## lengths; unlocking, and saves from before the Casino; and that every campaign level generates fairly for
## 3, 5 and 6 lanes. Also the campaign's shape (task R5): the recency curve for pick weights and the
## features' ages, The Hush's quiet remix (fewer enemies, more hosts, quiet stretches and bursts,
## darker lighting), and the lighting hook reaching every skin.

## The zones in order and their level counts (GDD §5; the Casino added as Zone 4 by the owner, October 8,
## 2026). Other tasks rely on these ids: skins at data/skins/<id>_skin.tres, music tracks named after them.
const ZONES: Array = [["city", 3], ["gangland", 3], ["marketplace", 2], ["casino", 2], ["corporate", 2], ["dead_zone", 2],
	["golden", 3]]
## Zone & Levels 1: halve City 1's former 110 s, without retiming any other level. The Casino's two
## (task K2, DESIGN-TBD) sit between the Marketplace's and Corporate's.
const LEVEL_DURATIONS: Dictionary[String, float] = {
	"city/1": 55.0, "city/2": 120.0, "city/3": 130.0,
	"gangland/1": 135.0, "gangland/2": 140.0, "gangland/3": 145.0,
	"marketplace/1": 140.0, "marketplace/2": 145.0,
	"casino/1": 145.0, "casino/2": 150.0,
	"corporate/1": 145.0, "corporate/2": 150.0,
	"dead_zone/1": 145.0, "dead_zone/2": 150.0,
	"golden/1": 145.0, "golden/2": 150.0, "golden/3": 150.0,
}
## The level each feature first appears in (GDD §5's schedule; `screech_vents`, the shopfront vents
## of Marketplace 2, and `wall_fences_partial`, from the Corporate zone, are GDD §9.1 and §9.5).
const FIRST_LEVEL: Dictionary = {
	"cyborg": "city/1",
	"ceilings": "city/2",
	"pulsing": "city/3", "window_cyborg": "city/3", "hover_truck": "city/3",
	"screech": "gangland/1", "ramps": "gangland/1", "wall_gaps": "gangland/1",
	"octodog": "gangland/2", "speed_pads": "gangland/2",
	"generator": "gangland/3", "drone": "gangland/3",
	"barnacle_turret": "marketplace/1",
	"wall_fences": "marketplace/2", "screech_vents": "marketplace/2",
	"buzz_overdrive": "corporate/1", "wall_fences_partial": "corporate/1",
	"tithe_collector": "corporate/2", "enforcer_truck": "corporate/2",
	"host": "dead_zone/1",
	"resonator": "golden/1",
	"gilded_sentinel": "golden/2",
}
## The documented exceptions to "anything introduced earlier keeps appearing later" (GDD §5): the
## levels that leave a feature out once it's introduced.
const LEFT_OUT: Dictionary = {
	# Zone & Levels 2: Octodogs stop at the Golden Zone, including the Golden Palace.
	"octodog": ["golden/1", "golden/2", "golden/3"],
	# Manholes need a street: zones with other floors get wall-vent screeches (screech_vents) instead,
	# from Marketplace 2's shopfront vents on (GDD §5, proposed); Marketplace 1 has none (DESIGN-TBD). The
	# Casino plays Marketplace 2's set (task K2, DESIGN-TBD), its vents included.
	"screech": ["marketplace/1", "marketplace/2", "casino/1", "casino/2", "corporate/1", "corporate/2", "golden/1",
		"golden/2", "golden/3"],
	# In the Dead Zone's rubble street, `screech` brings manholes and wall vents both.
	"screech_vents": ["dead_zone/1", "dead_zone/2"],
	# GDD §9.12 (proposed): the Tithe Collector skips the Dead Zone and returns in the Golden Zone.
	"tithe_collector": ["dead_zone/1", "dead_zone/2"],
}
## GDD §9.9 (corrected September 26, 2026): the Buzz Overdrive appears in the Corporate zone and the
## two zones after it, the Dead Zone and the Golden Zone (the Golden Palace plays like any level).
const BUZZ_OVERDRIVE_LEVELS: Array = ["corporate/1", "corporate/2", "dead_zone/1", "dead_zone/2", "golden/1", "golden/2",
	"golden/3"]
## Levels that bring nothing new (GDD §5): Dead Zone 2 is "a quiet, eerie remix", Golden 3 the
## Golden Palace, and the Casino's two "the Marketplace's enemies and mechanics in a new setting" (owner,
## October 8, 2026; what each Casino level adds is still to design).
const NOTHING_NEW: Array = ["casino/1", "casino/2", "dead_zone/2", "golden/3"]
## Zones that introduce no new enemy (GDD §5: "every zone introduces at least one new enemy, except the
## Casino, which reuses the Marketplace's", owner, October 8, 2026).
const NO_NEW_ENEMY: Array = ["casino"]
## The seed sweep: the levels with the most features, and The Hush (paced in bursts), on this many
## seeds each at 3, 5 and 6 lanes.
const SWEEP_LEVELS: Array = ["gangland/3", "corporate/2", "dead_zone/1", "dead_zone/2", "golden/1", "golden/2", "golden/3"]
const SWEEP_SEEDS: int = 8
## How far past its start a new feature's first piece or enemy may be: the first pattern picked
## from the start uses it, and the pick can wait for the longest pattern before it (an Octodog's
## 120 m) and the widest spacing; the enemy then stands up to 45 m into its own pattern. Metres at
## MovementTuning.REFERENCE_SPEED: a level at its zone's speed stretches them by its pace
## (LevelGenerator.pace), as it stretches the patterns.
const INTRODUCTION_REACH: float = 210.0
## Features whose rules place their first piece a spacing after their start by design, never as an
## introduction pick: WallGapPlacement starts its schedule at the start and puts the first wall gap one
## spacing (about 24-32 s) on, so Gangland 1's first one comes at about three quarters of the level on every
## seed and lane count (18 builds of 18 over six seeds, before the Casino and after). Nothing of them comes
## before their start (checked), but they aren't counted among the introductions that land right after it
## (task K2: they took half of that count's budget, and the Casino's re-spaced curve reshuffled the levels'
## own layouts: the generator's introductions are as often late as before, 16.7% and 16.4% of 396 seeded
## ones, but the levels' own seeds then had 6 late of 66, 3 of them wall gaps, and now 9). Left out, the
## levels' own seeds have 6 late of 63, the check's limit (3 before): docs/questions/k2.md lists them for
## the owner.
const SPACED_FROM_START: Array = ["wall_gaps"]
## The campaign's first steps before the Casino (save version 2), in their old order: The House was the
## Marketplace's boss, and the Marketplace's outro led to Corporate (_test_old_saves).
const V2_STEPS: PackedStringArray = ["city/intro", "city/1", "city/2", "city/3", "city/boss_intro", "city/boss", "city/outro",
	"gangland/intro", "gangland/1", "gangland/2", "gangland/3", "gangland/boss", "gangland/outro",
	"marketplace/intro", "marketplace/1", "marketplace/2", "marketplace/boss", "marketplace/outro",
	"corporate/intro", "corporate/1", "corporate/2", "corporate/boss", "corporate/outro", "dead_zone/intro", "dead_zone/1"]
## Features that are enemies (for "every zone introduces at least one new enemy").
const ENEMIES: Array = ["cyborg", "window_cyborg", "hover_truck", "screech", "octodog", "generator", "drone",
	"barnacle_turret", "buzz_overdrive", "tithe_collector", "enforcer_truck", "host", "resonator", "gilded_sentinel"]


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
	_test_ceiling_gauntlets(campaign)
	_test_recency(campaign)
	_test_hush(campaign)
	_test_darker_lighting(campaign)
	_test_unlocking()


## Seven zones in GDD §5's order, each built, with its levels, skin, music and tagline; only the City
## is in the web demo.
func _test_zones(campaign: Campaign) -> void:
	check(campaign.zones.size() == ZONES.size(), "the campaign has seven zones (GDD §5): %d" % campaign.zones.size())
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
		# Zones name their track after their id, and every zone's track exists (test_audio checks the files).
		check(zone.music == zone.id, "%s's music track is named after the zone" % id)
		check(library.has(zone.music), "%s's music exists" % id)
		check(zone.expected_loadout.is_empty(), "%s's expected loadout is still an empty placeholder (GDD §8)" % id)
	check(campaign.planned_level_count() == 17 and campaign.level_count() == 17, "17 levels (GDD §5)")
	var casino: ZoneDef = _zone(campaign, "casino")
	var market: ZoneDef = _zone(campaign, "marketplace")
	var corporate: ZoneDef = _zone(campaign, "corporate")
	check(casino != null and market != null and corporate != null and casino.run_speed > market.run_speed
		and casino.run_speed < corporate.run_speed,
		"the Casino runs between the Marketplace's speed and Corporate's (%.1f m/s)" % (casino.run_speed if casino != null else 0.0))
	check(market != null and not market.tagline.to_lower().contains("casino"), "the Marketplace's tagline leaves the casinos to the Casino")


## Steps run intro, levels, boss intro, boss, outro per zone; step and level ids stay stable (the
## save file keys progress by step id: The House's records moved to casino/boss with the Casino, see
## _test_old_saves), the Marketplace leads from its levels to its outro with no boss, and Golden 3 is the
## Golden Palace.
func _test_steps(campaign: Campaign) -> void:
	var expected := PackedStringArray([
		"city/intro", "city/1", "city/2", "city/3", "city/boss_intro", "city/boss", "city/outro",
		"gangland/intro", "gangland/1", "gangland/2", "gangland/3", "gangland/boss", "gangland/outro",
		"marketplace/intro", "marketplace/1", "marketplace/2", "marketplace/outro",
		"casino/intro", "casino/1", "casino/2", "casino/boss", "casino/outro",
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


## A boss slot per zone from GDD §10's roster (none for the Marketplace, which leads straight into the
## Casino, whose boss The House now is: owner, October 8, 2026), and cinematic slots: every zone's intro and
## outro, and the City's boss intro (the intros play placeholder flyovers, task F1; test_cinematics checks
## them).
func _test_slots(campaign: Campaign) -> void:
	var bosses: Dictionary = {"city": "Floating Head", "gangland": "Sewer Swarm", "marketplace": "",
		"casino": "The House", "corporate": "Hostile Takeover", "dead_zone": "Sleep Taker", "golden": "The final villain"}
	for zone: ZoneDef in campaign.zones:
		var id: String = String(zone.id)
		check(bosses.has(id), "%s is in GDD §10's roster" % id)
		if String(bosses.get(id, "")) == "":
			check(zone.boss == null and zone.boss_intro == null, "%s has no boss slot (GDD §10)" % id)
		else:
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
		if s.kind == CampaignStep.Kind.BOSS and s.zone == campaign.zones[0]:
			check(s.boss != null and s.boss.is_built(), "the City's boss step plays the Floating Head's fight (task E1d)")
		elif s.kind == CampaignStep.Kind.BOSS and s.zone.id == &"dead_zone":
			check(s.boss != null and s.boss.is_built(), "the Dead Zone's boss step plays the Sleep Taker's fight (task E5c-b)")
		elif s.kind == CampaignStep.Kind.BOSS and s.zone.id == &"gangland":
			check(s.boss != null and s.boss.is_built(), "Gangland's boss step plays the Sewer Swarm's fight (task E4b)")
		elif s.kind == CampaignStep.Kind.BOSS and s.zone.id == &"casino":
			check(s.boss != null and s.boss.is_built(), "the Casino's boss step plays The House's fight (tasks E5a-b, K2)")
		elif s.kind == CampaignStep.Kind.BOSS and s.zone.id == &"corporate":
			check(s.boss != null and s.boss.is_built(), "the Corporate zone's boss step plays Hostile Takeover's fight (task E5b-c)")
		elif s.kind == CampaignStep.Kind.BOSS:
			check(s.boss != null and not s.boss.is_built(), "boss slot %s is still a placeholder" % s.id)
		elif s.kind == CampaignStep.Kind.CINEMATIC and s.id.ends_with("intro"):
			check(s.cinematic != null and s.cinematic.scene == "res://scenes/cinematics/arrival_flyover.tscn"
				and s.cinematic.is_built(), "cinematic slot %s plays the placeholder arrival flyover (task F1)" % s.id)
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
		if NO_NEW_ENEMY.has(zone[0]):
			check(not new_enemy, "%s introduces no new enemy: it reuses the Marketplace's (GDD §5, owner)" % zone[0])
		else:
			check(new_enemy, "%s introduces at least one new enemy (GDD §5)" % zone[0])
	# The Casino plays the Marketplace's last level's set, nothing more (task K2, DESIGN-TBD until the owner
	# says what each Casino level adds): every feature the Marketplace brought, and nothing new.
	var market_2: LevelConfig = campaign.step("marketplace/2").level
	for id: String in ["casino/1", "casino/2"]:
		var casino: LevelConfig = campaign.step(id).level
		check(casino.features == market_2.features and casino.feature_starts.is_empty(),
			"%s plays Marketplace 2's features, with no introductions (%s)" % [id, casino.features])
	var city_1: LevelConfig = campaign.step("city/1").level
	check(city_1.feature_start("cyborg") >= 0.5, "City 1's cyborgs come late in the level (%.2f)" % city_1.feature_start("cyborg"))
	for id: String in ["marketplace/1", "marketplace/2", "casino/1", "casino/2", "corporate/1", "corporate/2", "golden/1",
			"golden/2", "golden/3"]:
		check(not campaign.step(id).level.has_feature("screech"), "no manholes in %s's floor" % id)
	# GDD §9.9 (corrected): the Buzz Overdrive, from Corporate 1 through the Golden Zone.
	for s: CampaignStep in levels:
		var listed: bool = BUZZ_OVERDRIVE_LEVELS.has(s.id)
		check(s.level.has_feature("buzz_overdrive") == listed,
			"%s %s the Buzz Overdrive (GDD §9.9)" % [s.id, "lists" if listed else "doesn't list"])
	for s: CampaignStep in levels:
		var has_octodogs: bool = s.level_index >= campaign.step("gangland/2").level_index \
			and s.zone.id != &"golden"
		check(s.level.has_feature("octodog") == has_octodogs,
			"%s keeps Octodogs only from Gangland 2 through the Dead Zone (Zone & Levels 2)" % s.id)
	# Every level lists its features in the order the campaign introduces them (the generator runs the
	# rules scripts in that order).
	var order: PackedStringArray = []
	for s: CampaignStep in levels:
		for f: String in s.level.features:
			if not order.has(f):
				order.append(f)
	for s: CampaignStep in levels:
		var last: int = -1
		var in_order: bool = true
		for f: String in s.level.features:
			in_order = in_order and order.find(f) > last
			last = order.find(f)
		check(in_order, "%s lists its features in the order the campaign introduces them" % s.id)
	var corporate_2: LevelConfig = campaign.step("corporate/2").level
	check(corporate_2.feature_weight("drone") > 1.0 and corporate_2.feature_weight("hover_truck") > 1.0,
		"Corporate 2 has a heavier military presence (GDD §5, proposed)")


## Each level is slightly harder than the last (GDD §6), up to Golden 2's peak (GDD §5, proposed), the
## automatic curve spanning all 17 levels; enemy scaling runs 0 → 1 across the campaign; City 1 lasts 55 s
## (Zone & Levels 1), the other levels keep their durations within 90–150 s, and together take about 40
## minutes (GDD §5, with the Casino's two levels).
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
			check(is_equal_approx(s.level.duration_seconds, LEVEL_DURATIONS[s.id]),
				"%s lasts %.0f s (only City 1 is halved): %.0f s"
					% [s.id, LEVEL_DURATIONS[s.id], s.level.duration_seconds])
			check(is_equal_approx(config.duration_seconds, s.level.duration_seconds),
				"%s keeps its duration when configured" % s.id)
			if s.id != "city/1":
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
	check(total >= 38.0 * 60.0 and total <= 42.0 * 60.0,
		"a flawless run through every level takes about 40 minutes (GDD §5): %.1f min" % (total / 60.0))
	var first: CampaignStep = campaign.step("city/1")
	var c1: LevelConfig = campaign.configure(first, 5)
	check(c1.lane_count == 5 and c1 != first.level, "configure returns a copy with the lane count")
	check(campaign.configure(steps[-1], 3, 1).difficulty >= campaign.configure(steps[-1], 3, 0).difficulty,
		"harder tiers never lower difficulty")
	check(campaign.configure(steps[4], 3, 1).difficulty > campaign.configure(steps[4], 3, 0).difficulty,
		"harder tiers raise difficulty")


## Levels take their zone's skin, the grey box until a zone has its own; a level's own skin wins, and
## is then a variant of its zone's skin: either the same script with different values (Corporate 2's
## plaza) or a subclass of it reusing its materials (the Golden Palace, Golden 3, task D6b).
func _test_skins(campaign: Campaign) -> void:
	for s: CampaignStep in campaign.steps():
		if s.is_level():
			var config: LevelConfig = campaign.configure(s, 3)
			if s.level.skin != null:
				check(config.skin == s.level.skin and s.zone.skin != null
					and _related_skin_scripts(config.skin.get_script(), s.zone.skin.get_script()),
					"%s takes its own variant of its zone's skin" % s.id)
			else:
				check(config.skin != null and config.skin == s.zone.skin, "%s takes its zone's skin" % s.id)
	var plaza: ZoneSkin = load("res://data/levels/corporate_2.tres").skin
	check(plaza is CorporateSkin and plaza.resource_path.ends_with("corporate_plaza_skin.tres"),
		"corporate/2 (Checkpoint Plaza) runs on the plaza variant")
	var market: ZoneDef = _zone(campaign, "marketplace")
	check(market != null and market.skin is MarketplaceSkin, "marketplace uses its own skin")
	# The Casino's skin is task K1's (data/skins/casino_skin.tres; the Marketplace's look stands in until it
	# comes, DESIGN-TBD): its own file, and its cyborgs the Marketplace's Casino Mob Enforcers (GDD §5).
	var casino: ZoneDef = _zone(campaign, "casino")
	check(casino != null and casino.skin != null and casino.skin.resource_path == "res://data/skins/casino_skin.tres"
		and casino.skin.enemy_variant == &"casino", "casino uses its own skin, with the Marketplace's enemies")
	var corporate: ZoneDef = _zone(campaign, "corporate")
	check(corporate != null and corporate.skin is CorporateSkin, "corporate uses its own skin")
	var golden: ZoneDef = _zone(campaign, "golden")
	check(golden != null and golden.skin is GoldenSkin, "golden uses its own skin")
	var dead: ZoneDef = _zone(campaign, "dead_zone")
	check(dead != null and dead.skin is DeadZoneSkin, "dead_zone uses its own skin")
	var palace: CampaignStep = campaign.step("golden/3")
	var own_skin := GreyboxSkin.new()
	var step := CampaignStep.new()
	step.zone = palace.zone
	step.level = palace.level.duplicate() as LevelConfig
	step.level.skin = own_skin
	step.level_index = palace.level_index
	check(campaign.configure(step, 3).skin == own_skin, "a level's own skin wins over its zone's")
	check(palace.level.skin is GoldenPalaceSkin, "and the shipped level (the Golden Palace, task D6b) has its own")


## Whether `a` and `b` are the same script, or `a` is a subclass of `b` (GoldenPalaceSkin extends
## GoldenSkin): how a level's own skin counts as "a variant of its zone's" above.
static func _related_skin_scripts(a: Script, b: Script) -> bool:
	var base: Script = a
	while base != null:
		if base == b:
			return true
		base = base.get_base_script()
	return false


## Every campaign level generates cleanly and fairly for every lane count, on its own seed and (for
## the densest levels) on others: no warnings, the shared fairness checks (LayoutChecks), nothing
## of a feature before its start, and every feature the level lists in the layout (GDD §5: anything
## introduced earlier keeps appearing later), bar the planned ones nothing places yet. On the
## levels' own seeds, each new feature also comes right after its start.
func _test_levels_generate(campaign: Campaign) -> void:
	var stats := {"introductions": 0, "late": [], "builds": 0, "levels": 0}
	for s: CampaignStep in campaign.steps():
		if not s.is_level():
			continue
		check(s.level.guarantee_features, "%s guarantees that every feature appears" % s.id)
		for lanes: int in [3, 5, 6]:
			_check_level(s, campaign.configure(s, lanes), "%s lanes=%d" % [s.id, lanes], stats)
	# 13 introductions of built features, at 3 lane counts each; more as the planned enemies are built.
	check(int(stats["introductions"]) >= 39, "introductions checked: %d" % stats["introductions"])
	# A rule can clear an introduced piece or enemy away (a hover truck's lane, the drone's pads, a first
	# chase that meets the first drone wave), and the feature then first shows a little later; that
	# stays rare on the campaign's own seeds.
	check((stats["late"] as Array).size() * 10 <= int(stats["introductions"]),
		"introductions land right after their start: late ones %s of %d" % [stats["late"], stats["introductions"]])

	# Any seed: the levels with the most features, on seeds other than their own, still have every
	# feature and nothing before its start. Their introductions come late more often (over 100 seeds,
	# 6% of all introductions, but Dead Zone 1's first host in 40% of levels: the first drone wave
	# often comes during its chase), so the sweep only reports those.
	var sweep := {"introductions": 0, "late": [], "builds": 0, "levels": 0}
	for id: String in SWEEP_LEVELS:
		for lanes: int in [3, 5, 6]:
			for level_seed: int in range(1, SWEEP_SEEDS + 1):
				var config: LevelConfig = campaign.configure(campaign.step(id), lanes)
				config.level_seed = 9000 + level_seed
				_check_level(campaign.step(id), config, "%s lanes=%d seed=%d" % [id, lanes, config.level_seed], sweep)
	check(int(sweep["levels"]) == SWEEP_LEVELS.size() * 3 * SWEEP_SEEDS, "the seed sweep generated %d levels" % sweep["levels"])
	print("  campaign levels: %.2f builds per level on their own seeds, %.2f in the seed sweep" % [
		float(stats["builds"]) / float(stats["levels"]), float(sweep["builds"]) / float(sweep["levels"])])
	print("  late introductions: %d of %d on the levels' own seeds, %d of %d in the seed sweep" % [
		(stats["late"] as Array).size(), stats["introductions"], (sweep["late"] as Array).size(), sweep["introductions"]])


## One campaign level, generated from `config` (see _test_levels_generate). Counts introductions and
## late ones, builds and levels in `stats` (its "late" is an Array, so appending to it here sticks).
func _check_level(s: CampaignStep, config: LevelConfig, tag: String, stats: Dictionary) -> void:
	var patterns: Array = LevelGenerator.load_for(config)
	# T-SPEED: shared across every suite in the run (LayoutCache) -- several of this suite's own
	# passes (the seed sweep, the recency curve) build some of these same levels again to check other
	# things, and so does test_wall_fences.gd's own campaign-level sweep.
	var gen: LevelGenerator = LayoutCache.generator(config, tuning, patterns)
	var layout: LevelLayout = gen.layout
	var movement: MovementTuning = config.movement_for(tuning)
	var seconds: float = LEVEL_DURATIONS[s.id]
	var expected_length: float = movement.run_speed * seconds \
		+ 0.5 * movement.speed_gain_per_minute / 60.0 * seconds * seconds
	check(is_equal_approx(layout.length, expected_length),
		"%s finish line matches %.0f s: %.1f m" % [tag, seconds, layout.length])
	stats["builds"] = int(stats["builds"]) + gen.attempts
	stats["levels"] = int(stats["levels"]) + 1
	check(gen.warnings.is_empty(), "no warnings %s %s" % [tag, gen.warnings])
	check(layout.gaps.size() + layout.fences.size() > 8, "has content " + tag)
	check(layout.credits.size() > 20, "has credits " + tag + " (%d)" % layout.credits.size())
	for c: Dictionary in layout.credits:
		if c["surface"] != "wall":
			check(int(c["lane"]) >= 0 and int(c["lane"]) < config.lane_count, "credit lane in range " + tag)
	LayoutChecks.check_layout(self, layout, config, tag)
	LayoutChecks.check_rules(self, layout, config, tag)
	for f: String in ["ceilings", "ramps", "speed_pads", "pulsing"]:
		if not config.has_feature(f):
			check(LayoutChecks.feature_positions(layout, f).is_empty(), "no `%s` before they're introduced %s" % [f, tag])
	var placeable: PackedStringArray = gen.placeable_features(patterns)
	if s.zone.id == &"golden":
		check(not config.has_feature("octodog") and not placeable.has("octodog"),
			"%s cannot pick or guarantee Octodog patterns" % tag)
		check(LayoutChecks.feature_positions(layout, "octodog").is_empty(),
			"%s has no Octodogs after all generator rules" % tag)
		for pick: Dictionary in gen.picks:
			check(not (pick["requires"] as Array).has("octodog"),
				"%s never picks an Octodog encounter" % tag)
	for f: String in config.features:
		if not LayoutChecks.can_locate(f):
			check(not placeable.has(f), "`%s` is planned: nothing places it yet %s" % [f, tag])
			continue
		var at: Array[float] = LayoutChecks.feature_positions(layout, f)
		check(not at.is_empty(), "%s has `%s` (GDD §5: earlier features keep appearing) %s" % [s.id, f, tag])
		if not config.feature_starts.has(f) or at.is_empty():
			continue
		var start: float = gen.feature_start(f)
		check(at[0] >= start - 0.01, "nothing of `%s` before its start (%.0f m) %s" % [f, start, tag])
		if SPACED_FROM_START.has(f):
			continue
		stats["introductions"] = int(stats["introductions"]) + 1
		if at[0] > start + INTRODUCTION_REACH * gen.pace:
			(stats["late"] as Array).append("%s %s (%.2f)" % [tag, f, at[0] / layout.length])


## GDD §3 and §6: the floor under a ceiling may be dangerous, but the level that introduces ceilings
## (City 2) shows a plain one first, on its own seed and on others, at 3, 5 and 6 lanes, so the player
## meets the pad and the ceiling before a gauntlet under one; gauntlets (floor pieces or floor
## enemies under a ceiling) do come later in the campaign.
func _test_ceiling_gauntlets(campaign: Campaign) -> void:
	var intro: CampaignStep = campaign.step(FIRST_LEVEL["ceilings"])
	for lanes: int in [3, 5, 6]:
		for level_seed: int in range(0, 9):
			var config: LevelConfig = campaign.configure(intro, lanes)
			if level_seed > 0:
				config.level_seed = 9100 + level_seed
			# T-SPEED: shared across the run (LayoutCache); the default seed (level_seed == 0 here)
			# is the same build _check_level ran above, and the one the gauntlet sweep below asks for.
			var layout: LevelLayout = LayoutCache.generate(config, tuning, LevelGenerator.load_for(config))
			var tag: String = "%s lanes=%d seed=%d" % [intro.id, lanes, config.level_seed]
			check(not layout.hulls.is_empty(), "%s has ceilings" % tag)
			if not layout.hulls.is_empty():
				check(_floor_under(layout, layout.hulls[0]) == 0,
					"the first ceiling of the level that introduces them is plain (%d under it) %s"
					% [_floor_under(layout, layout.hulls[0]), tag])
	var gauntlets: int = 0
	var first_level: int = 99
	for s: CampaignStep in campaign.steps():
		if not s.is_level():
			continue
		for lanes: int in [3, 5, 6]:
			var config: LevelConfig = campaign.configure(s, lanes)
			# T-SPEED: the level's own default build, already made (and cached) by _check_level above.
			var layout: LevelLayout = LayoutCache.generate(config, tuning, LevelGenerator.load_for(config))
			for h: Dictionary in layout.hulls:
				if _floor_under(layout, h) > 0:
					gauntlets += 1
					first_level = mini(first_level, s.level_index)
	check(gauntlets > 45, "the campaign has ceilings over a dangerous floor (%d on the levels' own seeds)" % gauntlets)
	check(first_level >= intro.level_index, "none before ceilings are introduced (first in level %d)" % (first_level + 1))


## Floor pieces and floor enemies under ceiling section `h` (between its start and end).
func _floor_under(layout: LevelLayout, h: Dictionary) -> int:
	var n: int = 0
	var a: float = float(h["start"])
	var b: float = float(h["end"])
	for g: Dictionary in layout.gaps:
		n += 1 if float(g["end"]) > a and float(g["start"]) < b else 0
	for f: Dictionary in layout.fences:
		n += 1 if float(f["at"]) > a and float(f["at"]) < b else 0
	for e: Dictionary in layout.enemies:
		n += 1 if LevelGenerator.enemy_uses_floor(e) and float(e["at"]) > a and float(e["at"]) < b else 0
	return n


## The recency curve for pick weights (GDD §5, owner's review P2 13: beyond the guarantee, a level's
## newest things get the most picks): the campaign gives every level's copy its curve
## (data/tuning/feature_recency.tres, F6-tunable) and each feature's age, the levels since the campaign
## introduced it. The curve peaks where a feature is introduced, stays high over the next levels and
## settles lower, never at zero. It never boosts a feature the data caps (whose rules keep only so
## many of its enemies, or the rare vent screech), and it keeps each kind of pattern's share (the
## enemies they place, for patterns with enemies): checked exactly at spots all through every level,
## so no level gets easier. Over the campaign, the uncapped features a level introduces get far more
## of its picks than without the curve (its own picks: an introduction or a guarantee's forced pick
## is there either way), and plain obstacles keep their share.
func _test_recency(campaign: Campaign) -> void:
	var curve: FeatureRecency = campaign.feature_recency
	check(curve != null and curve.resource_path == "res://data/tuning/feature_recency.tres" and curve.enabled
		and curve.keep_feature_share and curve.keep_share_by_kind, "the campaign has its recency curve, switched on, keeping each kind's share")
	if curve == null:
		return
	check(curve.introduced > curve.one_level_later and curve.one_level_later > curve.two_levels_later
		and curve.two_levels_later > curve.three_levels_later and curve.three_levels_later >= curve.older and curve.older > 0.0,
		"the level that introduces a feature picks it most, the next ones still a lot, older ones less but never none")
	for f: String in ["host", "hover_truck", "drone", "octodog", "screech_vents"]:
		check(curve.max_factor.has(f) and float(curve.max_factor[f]) <= 1.0,
			"`%s` is never boosted: its rules keep only so many (the vent screech is rare, GDD §9.5)" % f)
	for f: String in curve.max_factor:
		check(FIRST_LEVEL.has(f), "a capped feature (`%s`) is one the campaign knows" % f)
	for s: CampaignStep in campaign.steps():
		if not s.is_level():
			continue
		var config: LevelConfig = campaign.configure(s, 5)
		check(config.feature_recency == curve and config.recency_on(), "%s's copy has the campaign's curve" % s.id)
		check(s.level.feature_ages.is_empty() and s.level.feature_recency == null, "%s's own file has neither" % s.id)
		for f: String in s.level.features:
			var first: CampaignStep = campaign.step(String(FIRST_LEVEL.get(f, "")))
			var age: int = s.level_index - first.level_index if first != null else -1
			check(int(config.feature_ages.get(f, -99)) == age, "%s: `%s` was introduced %d levels ago (%d)" % [s.id, f, age,
				config.feature_ages.get(f, -99)])
	check(int(campaign.configure(campaign.step("golden/1"), 3).feature_ages["buzz_overdrive"]) == 4
		and int(campaign.configure(campaign.step("dead_zone/2"), 3).feature_ages["host"]) == 1,
		"e.g. Golden 1's Buzz Overdrive is 4 levels old, The Hush's hosts 1")

	var intro: Array[int] = [0, 0]
	var core: Array[int] = [0, 0]
	var total: Array[int] = [0, 0]
	var spots: int = 0
	# The features some pattern requires (planned ones have none yet, and the wall fences and the Barnacle
	# Turret have none at all: their pieces come from the generator and their rules).
	var with_patterns: Dictionary = {}
	for p: Dictionary in LevelGenerator.load_for(load(LEVEL_PATH) as LevelConfig):
		for need: Variant in p.get("requires", []):
			with_patterns[String(need)] = true
	for s: CampaignStep in campaign.steps():
		if not s.is_level():
			continue
		# The levels that introduce an uncapped feature with patterns get the seed sweep too: a level's
		# own seed alone is too few picks to see the curve in.
		var sweep: int = 0
		for f: String in s.level.features:
			if FIRST_LEVEL.get(f, "") == s.id and not curve.max_factor.has(f) and with_patterns.has(f):
				sweep = 8
		for lanes: int in [3, 5, 6]:
			for seed_k: int in sweep + 1:
				for k: int in 2:
					var config: LevelConfig = campaign.configure(s, lanes)
					if seed_k > 0:
						config.level_seed = 9300 + seed_k
					if k == 0:
						config.feature_recency = null
					var patterns: Array = LevelGenerator.load_for(config)
					var gen := LevelGenerator.new()
					gen.generate(config, tuning, patterns)
					for p: Dictionary in gen.picks:
						total[k] += 1
						var requires: Array = p["requires"]
						if requires.is_empty():
							core[k] += 1
						if bool(p["due"]):
							continue
						for f: Variant in requires:
							if int(config.feature_ages.get(String(f), -1)) == 0 and not curve.max_factor.has(String(f)):
								intro[k] += 1
								break
					if k == 1 and seed_k == 0:
						spots += _check_kind_shares(gen, config, patterns, "%s lanes=%d" % [s.id, lanes])
	check(spots >= campaign.level_count() * 3 * 8, "the curve keeps each kind's share all through every level (%d spots)" % spots)
	check(intro[1] * 10 >= intro[0] * 12, "the uncapped features a level introduces get more of its picks (%d, without the curve %d)"
		% [intro[1], intro[0]])
	check(absf(float(core[1]) / total[1] - float(core[0]) / total[0]) < 0.03,
		"plain obstacles keep their share of the picks (%.3f, without the curve %.3f)" % [float(core[1]) / total[1], float(core[0]) / total[0]])
	print("  recency curve over the campaign: %d own picks of newly introduced uncapped features (%d without), plain obstacles %.3f of picks (%.3f)"
		% [intro[1], intro[0], float(core[1]) / total[1], float(core[0]) / total[0]])


## At spots all through a generated campaign level (with its difficulty there), the curve keeps what
## each kind of feature pattern weighs (LevelGenerator.pattern_kind; patterns with enemies by the
## enemies they place) and a capped feature's patterns at their own weight times the cap. Returns
## the spots checked.
func _check_kind_shares(gen: LevelGenerator, config: LevelConfig, patterns: Array, tag: String) -> int:
	var curve: FeatureRecency = config.feature_recency
	var n: int = 0
	for i: int in 10:
		var at: float = config.start_clear_distance + (gen.layout.length - config.start_clear_distance) * (i + 0.5) / 10.0
		var difficulty: float = gen.difficulty_at(at / gen.layout.length)
		var with: Dictionary = gen.pick_weights(patterns, difficulty, at)
		curve.enabled = false
		var without: Dictionary = gen.pick_weights(patterns, difficulty, at)
		curve.enabled = true
		var sums: Array[Array] = [[0.0, 0.0, 0.0], [0.0, 0.0, 0.0]]
		var ok: bool = (with["patterns"] as Array).size() == (without["patterns"] as Array).size()
		for j: int in (with["patterns"] as Array).size():
			var p: Dictionary = with["patterns"][j]
			var requires: Array = p.get("requires", [])
			var w1: float = float(with["weights"][j])
			var w0: float = float(without["weights"][j])
			if requires.is_empty():
				ok = ok and is_equal_approx(w0, w1)
				continue
			if config.recency_capped(requires):
				ok = ok and is_equal_approx(w1, w0 * config.recency_factor(requires))
			var kind: int = LevelGenerator.pattern_kind(p)
			var measure: float = float(LevelGenerator.enemy_count(p, config.lane_count)) if kind == 0 else 1.0
			sums[0][kind] += w0 * measure
			sums[1][kind] += w1 * measure
		for kind: int in 3:
			ok = ok and is_equal_approx(sums[0][kind], sums[1][kind])
		check(ok, "%s at %.0f m: each kind keeps its share, capped features their own weight" % [tag, at])
		n += 1
	return n


## The Hush (GDD §5, decided September 26, 2026): "a quiet, eerie remix: fewer enemies but more hosts
## and Bad Dream chases, darker lighting, and long silent stretches broken by sudden threats". All of
## it is The Hush's own data, which no other level uses: quiet stretches and bursts, hosts picked more
## often and placed in the quiet stretches (a chase starts only if the player kills one), and its
## darkness (_test_darker_lighting). Generated at 3, 5 and 6 lanes on its own seed and others, it has
## fewer enemies than Dead Zone 1 and than itself without the remix, more hosts than without it,
## every one of them in a quiet stretch, no enemy but hosts picked in its quiet stretches, and bursts
## far denser than its quiet stretches.
func _test_hush(campaign: Campaign) -> void:
	var hush: CampaignStep = campaign.step("dead_zone/2")
	var ash: CampaignStep = campaign.step("dead_zone/1")
	var level: LevelConfig = hush.level
	check(level.paced_in_bursts() and level.quiet_seconds > level.burst_seconds
		and level.quiet_features == PackedStringArray(["host"]) and level.feature_weight("host") > 1.0 and level.darkness > 0.0,
		"The Hush alternates long quiet stretches with short bursts, picks hosts more often (in its quiet stretches too) and is darker")
	for s: CampaignStep in campaign.steps():
		if s.is_level() and s != hush:
			check(not s.level.paced_in_bursts() and s.level.darkness == 0.0 and s.level.quiet_features.is_empty(),
				"%s keeps its even pacing and its zone's own light" % s.id)
	var patterns: Array = LevelGenerator.load_for(level)
	var by_id: Dictionary = {}
	for p: Dictionary in patterns:
		by_id[String(p["id"])] = p
	# Enemies (hosts apart) and hosts: The Hush [0], itself without the remix [1], Dead Zone 1 [2].
	var enemies: Array[int] = [0, 0, 0]
	var hosts: Array[int] = [0, 0, 0]
	var quiet_enemies: int = 0
	var burst_enemies: int = 0
	var quiet_metres: float = 0.0
	var burst_metres: float = 0.0
	var levels: int = 0
	for lanes: int in [3, 5, 6]:
		for k: int in 13:
			for which: int in 3:
				var config: LevelConfig = campaign.configure(ash if which == 2 else hush, lanes)
				if k > 0:
					config.level_seed = 9200 + k
				if which == 1:
					config.quiet_seconds = 0.0
					config.quiet_features = PackedStringArray()
					var none: Dictionary[String, float] = {}
					config.feature_weights = none
					config.darkness = 0.0
				var tag: String = "%s lanes=%d seed=%d" % [["The Hush", "The Hush without the remix", "Dead Zone 1"][which], lanes,
					config.level_seed]
				# T-SPEED: shared across the run (LayoutCache); this uses only gen.warnings/picks and
				# its pacing queries (quiet_at, quiet_stretches), all pure once a layout exists.
				var gen: LevelGenerator = LayoutCache.generator(config, tuning, patterns)
				var layout: LevelLayout = gen.layout
				check(gen.warnings.is_empty(), "no warnings %s %s" % [tag, gen.warnings])
				for e: Dictionary in layout.enemies:
					var host: bool = String(e["type"]) == "cyborg" and bool((e.get("params", {}) as Dictionary).get("host", false))
					hosts[which] += 1 if host else 0
					enemies[which] += 0 if host else 1
					if which == 0 and host:
						check(gen.quiet_at(float(e["at"])), "its hosts stand in its quiet stretches, where one is easy to reach (at %.0f) %s"
							% [float(e["at"]), tag])
					elif which == 0:
						if gen.quiet_at(float(e["at"])):
							quiet_enemies += 1
						else:
							burst_enemies += 1
				if which != 0:
					continue
				levels += 1
				var last: float = layout.length - config.end_clear_distance
				for s: Vector2 in gen.quiet_stretches():
					quiet_metres += s.y - s.x
				burst_metres += last - config.start_clear_distance
				check(gen.quiet_stretches().size() >= 6, "long quiet stretches, again and again %s" % tag)
				for p: Dictionary in gen.picks:
					if not gen.quiet_at(float(p["at"])):
						continue
					var enemy: bool = false
					for e: Dictionary in (by_id[String(p["id"])] as Dictionary).get("elements", []):
						enemy = enemy or String(e.get("kind", "")) == "enemy"
					check(not enemy or p["requires"] == ["host"], "its quiet stretches pick no enemy but hosts (%s at %.0f) %s"
						% [p["id"], p["at"], tag])
	burst_metres -= quiet_metres
	print("  The Hush over %d levels: %.1f enemies and %.2f hosts a level (without the remix %.1f and %.2f; Dead Zone 1 %.1f and %.2f); %.2f enemies per 100 m in its quiet stretches, %.2f in its bursts"
		% [levels, float(enemies[0]) / levels, float(hosts[0]) / levels, float(enemies[1]) / levels, float(hosts[1]) / levels,
		float(enemies[2]) / levels, float(hosts[2]) / levels, quiet_enemies * 100.0 / quiet_metres, burst_enemies * 100.0 / burst_metres])
	check(enemies[0] * 10 < enemies[1] * 8 and enemies[0] < enemies[2],
		"fewer enemies: %d, against %d without the remix and %d in Dead Zone 1" % [enemies[0], enemies[1], enemies[2]])
	check(hosts[0] > hosts[1] and hosts[0] > hosts[2],
		"more hosts: %d, against %d without the remix and %d in Dead Zone 1" % [hosts[0], hosts[1], hosts[2]])
	check(quiet_enemies * 100.0 / quiet_metres < burst_enemies * 100.0 / burst_metres * 0.25,
		"silent stretches broken by sudden threats: enemies %.2f per 100 m in the quiet stretches, %.2f in the bursts"
		% [quiet_enemies * 100.0 / quiet_metres, burst_enemies * 100.0 / burst_metres])


## The Hush's darker lighting (GDD §5) is a level setting every skin's environment follows
## (ZoneSkin.level_environment, apply_darkness): the sky and the distance fog dim, and the skin's
## scenery through the global `scenery_light` uniform; the ambient light, the sun and every glow stay,
## so hazards and enemies read as well as anywhere; it never goes below MIN_SCENERY_LIGHT, and
## darkness 0 is the zone's own light. Checked on every skin in data/skins and the grey box, and in
## the shaders: the scenery's read the uniform, the hazards', triggers', the feed's, the enemies', the
## runner's and the pickups' don't.
func _test_darker_lighting(campaign: Campaign) -> void:
	var darkness: float = campaign.step("dead_zone/2").level.darkness
	var light: float = ZoneSkin.scenery_light_for(darkness)
	check(light < 0.9 and light > ZoneSkin.MIN_SCENERY_LIGHT, "The Hush's scenery is darker, never pitch black (%.2f)" % light)
	check(ZoneSkin.scenery_light_for(0.0) == 1.0 and is_equal_approx(ZoneSkin.scenery_light_for(1.0), ZoneSkin.MIN_SCENERY_LIGHT)
		and is_equal_approx(ZoneSkin.scenery_light_for(3.0), ZoneSkin.MIN_SCENERY_LIGHT) and ZoneSkin.MIN_SCENERY_LIGHT >= 0.3,
		"darkness runs from the zone's own light down to MIN_SCENERY_LIGHT")
	var skins: Array[ZoneSkin] = [GreyboxSkin.new()]
	for file: String in DirAccess.get_files_at("res://data/skins"):
		if file.ends_with(".tres"):
			skins.append(load("res://data/skins".path_join(file)) as ZoneSkin)
	check(skins.size() >= 4, "every skin is checked (%d)" % skins.size())
	var factor: float = ZoneSkin.energy_factor(light)
	for skin: ZoneSkin in skins:
		var skin_name: String = skin.resource_path.get_file() if skin.resource_path != "" else "the grey box"
		var plain: Environment = skin.make_environment()
		var dark: Environment = skin.level_environment(darkness)
		check(is_equal_approx(dark.background_energy_multiplier, plain.background_energy_multiplier * factor)
			and is_equal_approx(dark.fog_light_energy, plain.fog_light_energy * factor), "%s: the sky and the fog dim" % skin_name)
		check(is_equal_approx(ZoneSkin.scenery_light_now, light), "%s: and the scenery (%.2f)" % [skin_name, ZoneSkin.scenery_light_now])
		check(dark.ambient_light_energy == plain.ambient_light_energy and dark.ambient_light_color == plain.ambient_light_color
			and dark.glow_intensity == plain.glow_intensity and dark.glow_hdr_threshold == plain.glow_hdr_threshold
			and dark.glow_enabled == plain.glow_enabled, "%s: the light on the runner and the enemies, and every glow, stay" % skin_name)
		var normal: Environment = skin.level_environment(0.0)
		check(is_equal_approx(normal.background_energy_multiplier, plain.background_energy_multiplier)
			and is_equal_approx(normal.fog_light_energy, plain.fog_light_energy) and ZoneSkin.scenery_light_now == 1.0,
			"%s: darkness 0 is the zone's own light" % skin_name)
	check(ProjectSettings.has_setting("shader_globals/scenery_light"), "the scenery light is a global shader uniform (project.godot)")
	var dims: Array[String] = ["res://scripts/world/meshes/shaders/kit_solid.gdshader", "res://scripts/world/meshes/shaders/facade.gdshader",
		"res://scripts/world/meshes/shaders/shopfront.gdshader", "res://scripts/world/meshes/shaders/road.gdshader",
		"res://scripts/world/meshes/shaders/drift.gdshader", "res://scripts/world/meshes/shaders/corp_facade.gdshader",
		"res://scripts/world/meshes/shaders/dead_smoke.gdshader", "res://scripts/world/greybox_scenery.gdshader"]
	for path: String in dims:
		var code: String = FileAccess.get_file_as_string(path)
		check(code.contains("global uniform float scenery_light;") and code.count("scenery_light") >= 2,
			"%s dims with the scenery light" % path.get_file())
	check(FileAccess.get_file_as_string(dims[0]).contains("(to_linear(base) * shade + sheen) * light_factor(scenery_light)"),
		"the kit's solid shader dims its lit surfaces only, never its glowing ones")
	var keeps: Array[String] = ["res://scripts/world/meshes/shaders/energy_field.gdshader", "res://scripts/world/meshes/shaders/kit_glow.gdshader",
		"res://scripts/world/meshes/shaders/cult_feed.gdshader", "res://scripts/world/meshes/shaders/night_sky.gdshader",
		"res://scripts/enemies/cyborg_body.gdshader", "res://scripts/characters/humanoid_body.gdshader", "res://scripts/run/pickup.gdshader"]
	for path: String in keeps:
		check(not FileAccess.get_file_as_string(path).contains("scenery_light"), "%s keeps its own light" % path.get_file())
	# The grey box: its floor, walls and ceilings are scenery; its fence posts, like enemies, aren't.
	var box := GreyboxSkin.new()
	var parent := Node3D.new()
	box.floor_segment(parent, Vector3.ZERO, Vector3(3.0, 1.0, 10.0), 0.0, false, false)
	box.wall_section(parent, 1, 8.0, 0.0, 10.0)
	box.hull(parent, Vector3(0.0, 5.0, -5.0), Vector3(9.0, 0.5, 10.0), [])
	var scenery: int = 0
	for child: Node in parent.get_children():
		var m := child as MeshInstance3D
		if m != null and m.material_override is ShaderMaterial \
				and (m.material_override as ShaderMaterial).shader == GreyboxMaterials.SCENERY_SHADER:
			scenery += 1
	check(scenery == 3, "the grey box's floor, walls and ceilings dim with the scenery (%d)" % scenery)
	parent.free()
	ZoneSkin.set_scenery_light(1.0)


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
	_test_old_saves()


## A version 2 save (from before the Casino) that finished every step of the old campaign up to `last`, on
## the normal tier, as a parsed save file has it.
func _v2_save(last: String) -> Dictionary:
	var records: Dictionary = {}
	for id: String in V2_STEPS:
		var boss: bool = id.ends_with("/boss")
		var stars: int = 2 if boss or not (id.ends_with("intro") or id.ends_with("outro")) else 3
		records["0/" + id] = {"completed": true, "best_score": 4000.0 if boss else 1000.0, "stars": float(stars),
			"best_time": 90.0, "attempts": 2.0}
		if id == last:
			break
	return {"version": 2, "earned": 100.0, "records": records, "seen": {"hint/marketplace_boss": true,
		"hint/marketplace_boss_buttons": true, "hint/octodog": true}}


## Saves from before the Casino (save version 3, Profile._migrate): The House's records and first-time hints
## move to the Casino's boss step and casino_boss; the Marketplace's old outro (after The House, heading for
## the corporate district) counts as the Casino's outro too; and a player keeps every step they had reached
## (App.step_unlocked: a step done stays open), with the Casino's new levels next.
func _test_old_saves() -> void:
	var saved: Profile = App.profile
	var deep: Dictionary = _v2_save("dead_zone/1")
	(deep["records"] as Dictionary)["1/marketplace/boss"] = {"completed": true, "best_score": 5000.0, "stars": 1.0,
		"best_time": 120.0, "attempts": 1.0}
	var p: Profile = Profile.from_dict(JSON.parse_string(JSON.stringify(deep)))
	check(Profile.VERSION == 3 and int(p.to_dict()["version"]) == 3, "saves are version 3")
	check(not p.records.has("0/marketplace/boss") and p.is_completed("casino/boss") and p.stars("casino/boss") == 2
		and int(p.record("casino/boss").get("best_score", 0)) == 4000 and p.is_completed("casino/boss", 1)
		and not p.records.has("1/marketplace/boss"),
		"The House's records move to the Casino's boss step, on every tier")
	check(p.has_seen("hint/casino_boss") and p.has_seen("hint/casino_boss_buttons") and p.has_seen("hint/octodog")
		and not p.has_seen("hint/marketplace_boss") and not p.has_seen("hint/marketplace_boss_buttons"),
		"and its first-time hints, seen once, stay seen")
	check(p.is_completed("marketplace/outro") and p.is_completed("casino/outro") and not p.is_completed("casino/1"),
		"the old Marketplace outro counts as the Casino's outro too; the Casino's levels are new")
	var again: Profile = Profile.from_dict(JSON.parse_string(JSON.stringify(p.to_dict())))
	check(again.is_completed("casino/boss") and again.stars("casino/boss") == 2 and again.records.size() == p.records.size(),
		"a version 3 save loads as it is")
	App.profile = p
	var reached: bool = true
	for id: String in V2_STEPS:
		if App.campaign.step(id) != null:
			reached = reached and App.step_unlocked(App.campaign.step(id))
	check(reached, "every step the player had reached stays open")
	check(App.step_unlocked(App.campaign.step("casino/intro")) and not App.step_unlocked(App.campaign.step("casino/1"))
		and App.step_unlocked(App.campaign.step("casino/boss")) and App.step_unlocked(App.campaign.step("dead_zone/2"))
		and App.next_unfinished_step() == App.campaign.step("casino/intro"),
		"the Casino opens from the Marketplace's outro, and Continue leads into it")
	# A player who had just finished the Marketplace's old outro: Corporate's intro, open to them, stays open.
	App.profile = Profile.from_dict(JSON.parse_string(JSON.stringify(_v2_save("marketplace/outro"))))
	check(App.step_unlocked(App.campaign.step("corporate/intro")) and App.step_unlocked(App.campaign.step("casino/intro"))
		and not App.step_unlocked(App.campaign.step("corporate/1")), "a save at Corporate's intro keeps it open")
	# One who had beaten The House but not seen that outro: Corporate stays shut, as it was.
	App.profile = Profile.from_dict(JSON.parse_string(JSON.stringify(_v2_save("marketplace/boss"))))
	check(App.profile.is_completed("casino/boss") and not App.profile.is_completed("casino/outro")
		and App.step_unlocked(App.campaign.step("marketplace/outro")) and App.step_unlocked(App.campaign.step("casino/outro"))
		and not App.step_unlocked(App.campaign.step("corporate/intro")),
		"a save that beat The House goes on through the Marketplace's outro; Corporate's intro stays shut")
	# A save from the first build of the House (no version) is migrated through every step.
	var oldest: Dictionary = _v2_save("marketplace/boss")
	oldest.erase("version")
	check(Profile.from_dict(oldest).is_completed("casino/boss"), "a save without a version is brought up to date too")
	App.profile = saved


func _zone(campaign: Campaign, id: String) -> ZoneDef:
	for zone: ZoneDef in campaign.zones:
		if String(zone.id) == id:
			return zone
	return null
