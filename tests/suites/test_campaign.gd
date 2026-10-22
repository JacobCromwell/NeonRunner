extends TestSuite
## The campaign data (GDD §5, §6, §10): ten zones in order with 3/3/2/2/2/3/2/2/3/3 levels, their steps and
## ids, boss and cinematic slots (the Marketplace has no boss: The House is the Casino's; the Terminal has none), skins, music and
## the demo scope; the level-by-level schedule (where each feature first appears, later levels keeping it,
## one new thing at a time, late starts, the Casino and the Beach bringing nothing new); the difficulty curve and
## level lengths; unlocking, and saves from before the Casino; and that every campaign level generates fairly for
## 3, 5 and 6 lanes. Also the campaign's shape (task R5): the recency curve for pick weights and the
## features' ages, The Hush's quiet remix (fewer enemies, more hosts, quiet stretches and bursts,
## darker lighting), and the lighting hook reaching every skin. And the Beach (task D10c; the owner,
## October 9, 2026: "put the beach between the corporate and dead zone"): zone 6, a remix with nothing
## new, its levels off the difficulty curve (LevelConfig.off_curve) between Corporate 2's and Dead Zone
## 1's, and every other level and boss configured exactly as in the seven-zone campaign before it; and its
## second level, the volleyball match (the owner, October 10, 2026; a mini-game, LevelConfig.minigame, played
## by test_volleyball), which Sunset Strip, now Beach 3, follows exactly as it did before (its feature ages, its
## difficulty, its saves: Profile version 4). And the Terminal (task O1; the owner, October 20, 2026, GDD §5 Zone 8):
## zone 8, between the Dead Zone and the Golden Zone (now zone 9), two levels and no boss, off the difficulty curve
## between Dead Zone 2's and Golden 1's, none of the earlier features but its ceilings and its walls' open space (its
## arches), and every other level and boss configured exactly as in the campaign before it; a save from before it
## keeps the Golden Zone it had open (Profile version 5). test_terminal_levels checks its levels' own rules. And the Ice
## Lab (task Q1; the owner, October 21, 2026, GDD §5 Zone 9): zone 9, between the Terminal and the Golden Zone (now zone
## 10), three levels and no boss, off the difficulty curve between Terminal 2's and Golden 1's, its enemies the cyborgs,
## the Octodogs and the heli drones, no other earlier enemy and no dash walls (ICE_LAB_LEAVES_OUT), nothing new until its
## mechanics' tasks (Q3, Q4) and its two new enemies come, and every other level and boss configured exactly as in the
## campaign before it; a save from before it keeps the Golden Zone it had open (Profile version 6). test_ice_lab_levels
## checks its levels' own rules.

## The zones in order and their level counts (GDD §5; the Casino added as Zone 4 by the owner, October 8,
## 2026, the Beach as Zone 6, between Corporate and the Dead Zone, October 9, the Terminal as Zone 8, between the
## Dead Zone and the Golden Zone, October 20, and the Ice Lab as Zone 9, between the Terminal and the Golden Zone, October
## 21). Other tasks rely on these ids: skins at data/skins/<id>_skin.tres, music tracks named after them.
const ZONES: Array = [["city", 3], ["gangland", 3], ["marketplace", 2], ["casino", 2], ["corporate", 2], ["beach", 3],
	["dead_zone", 2], ["terminal", 2], ["ice_lab", 3], ["golden", 3]]
## Zones whose music track isn't made yet (the Music player skips a missing track quietly, ZoneDef.music): none now.
const MUSIC_TO_COME: Array = []
## The Terminal (task O1; GDD §5, Zone 8: none of the usual enemies, no dash walls, no wall running, a couple of
## holes, a few one-lane ceilings) keeps only these of the features introduced before it: its ceilings, and the side
## walls' open space between its narrow arches (the `wall_gaps` feature with its own numbers, WallGapTuning's Arches
## group). Every other earlier feature is left out of both its levels.
const TERMINAL_KEEPS: Array = ["ceilings", "wall_gaps"]
## The Ice Lab (task Q1; GDD §5, Zone 9: its enemies are "cyborg gangsters, Octodogs and heli drones", (proposed) none of
## the other earlier enemies, the usual obstacles, no dash walls) leaves these features introduced before it out of all
## three of its levels: every other earlier enemy, the dash walls and the Terminal's debris maze. It keeps everything else
## introduced before it (test_ice_lab_levels, KEEPS and LEAVES_OUT: the window cyborgs and the fence generators among what
## it keeps; DESIGN-TBD, docs/questions/q1.md).
const ICE_LAB_LEAVES_OUT: Array = ["hover_truck", "screech", "screech_vents", "barnacle_turret", "buzz_overdrive", "dash_wall",
	"tithe_collector", "enforcer_truck", "host", "debris_maze", "centipede"]
## Zone & Levels 1: halve City 1's former 110 s, without retiming any other level. The Casino's two
## (task K2, DESIGN-TBD) sit between the Marketplace's and Corporate's, the Beach's two (task D10c, DESIGN-TBD)
## between Corporate's and the Dead Zone's, the Terminal's two (task O1, DESIGN-TBD) between the Dead Zone's and the
## Golden Zone's, and the Ice Lab's three (task Q1, DESIGN-TBD, docs/questions/q1.md) between the Terminal's and the Golden
## Zone's, rising through the zone as its neighbours' do. The Beach's volleyball match (beach/2, a mini-game) lasts as long
## as a flawless match (test_volleyball measures it).
const LEVEL_DURATIONS: Dictionary[String, float] = {
	"city/1": 55.0, "city/2": 120.0, "city/3": 130.0,
	"gangland/1": 135.0, "gangland/2": 140.0, "gangland/3": 145.0,
	"marketplace/1": 140.0, "marketplace/2": 145.0,
	"casino/1": 145.0, "casino/2": 150.0,
	"corporate/1": 145.0, "corporate/2": 150.0,
	"beach/1": 145.0, "beach/2": 55.0, "beach/3": 150.0,
	"dead_zone/1": 145.0, "dead_zone/2": 150.0,
	"terminal/1": 140.0, "terminal/2": 145.0,
	"ice_lab/1": 140.0, "ice_lab/2": 145.0, "ice_lab/3": 150.0,
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
	# Task J2 (the owner, October 15, 2026: "especially in later zones and levels"; DESIGN-TBD where they start,
	# docs/questions/j2.md): wall-run gaps from halfway into Marketplace 1.
	"barnacle_turret": "marketplace/1", "wall_run_gaps": "marketplace/1",
	"wall_fences": "marketplace/2", "screech_vents": "marketplace/2",
	"buzz_overdrive": "corporate/1", "wall_fences_partial": "corporate/1", "dash_wall": "corporate/1",
	"tithe_collector": "corporate/2", "enforcer_truck": "corporate/2",
	"host": "dead_zone/1",
	# Task O1 (GDD §5, Zone 8): the debris maze (built by task O2) and the Cybernetic Centipede (built by task O3, GDD
	# §9.15), which waits in it.
	"debris_maze": "terminal/1", "centipede": "terminal/1",
	"resonator": "golden/1",
	"gilded_sentinel": "golden/2",
	# Task I4 (GDD §3, "Ceiling scenarios": never in zones 1-2; DESIGN-TBD, items 836–845 (docs/OPEN_QUESTIONS*.md)): from the Casino.
	"treasure_stash": "casino/1", "fenced_ceiling": "casino/2",
}
## The documented exceptions to "anything introduced earlier keeps appearing later" (GDD §5): the
## levels that leave a feature out once it's introduced.
const LEFT_OUT: Dictionary = {
	# Zone & Levels 2: Octodogs stop at the Golden Zone, including the Golden Palace.
	"octodog": ["golden/1", "golden/2", "golden/3"],
	# Manholes need a street: zones with other floors get wall-vent screeches (screech_vents) instead,
	# from Marketplace 2's shopfront vents on (GDD §5, proposed); Marketplace 1 has none (DESIGN-TBD). The
	# Casino plays Marketplace 2's set (task K2, DESIGN-TBD), its vents included; the Beach's floor is sand and
	# boardwalk (GDD §5).
	"screech": ["marketplace/1", "marketplace/2", "casino/1", "casino/2", "corporate/1", "corporate/2", "beach/1", "beach/3",
		"golden/1", "golden/2", "golden/3"],
	# In the Dead Zone's rubble street, `screech` brings manholes and wall vents both.
	"screech_vents": ["dead_zone/1", "dead_zone/2"],
	# GDD §9.12 (proposed): the Tithe Collector skips the Dead Zone and returns in the Golden Zone.
	"tithe_collector": ["dead_zone/1", "dead_zone/2"],
	# No dash walls in the Beach for now (GDD §9.14 has them in every zone after Corporate, but the Beach's side walls
	# stand open on about half of a level and it has no wall look): docs/OPEN_QUESTIONS.md item 680.
	"dash_wall": ["beach/1", "beach/3"],
	# Task O1: the Terminal's debris maze and its centipedes, which live in the maze, stay in the Terminal (DESIGN-TBD,
	# docs/questions/o1.md: GDD §5 says anything introduced keeps appearing, but the maze is the Terminal's own).
	"debris_maze": ["golden/1", "golden/2", "golden/3"],
	"centipede": ["golden/1", "golden/2", "golden/3"],
	# The owner, October 20, 2026 (task O1): The Hush leaves out the heli drone, whose anti-grav pad every 8 to 10 s left
	# its extended wall runs no room (LevelConfig.features_left_out; endless mode puts it back).
	"drone": ["dead_zone/2"],
}
## GDD §9.9 (corrected September 26, 2026): the Buzz Overdrive appears in the Corporate zone and the
## two zones after it, the Dead Zone and the Golden Zone (the Golden Palace plays like any level), and in the
## Beach between them, a remix of everything before it (owner, October 9, 2026; §9.9 names it since then,
## docs/OPEN_QUESTIONS.md, item 579).
const BUZZ_OVERDRIVE_LEVELS: Array = ["corporate/1", "corporate/2", "beach/1", "beach/3", "dead_zone/1", "dead_zone/2", "golden/1",
	"golden/2", "golden/3"]
## Levels that bring nothing new (GDD §5): the Beach's, a remix of everything before it (owner, October 9, 2026:
## "Do not worry about any new enemies at this time"), Dead Zone 2 "a quiet, eerie remix", Golden 3 the Golden
## Palace, Terminal 2 a normal run with stretches of the debris maze Terminal 1 brings (GDD §5, Zone 8). (The Beach's
## volleyball match, beach/2, places no features at all: the schedule leaves it out. The Casino's two, "the
## Marketplace's enemies and mechanics in a new setting" (owner, October 8, 2026), bring the ceiling scenarios since
## task I4.) The Ice Lab's three for now (task Q1): what they bring, the falling gantryways (all three, from level 1) and
## the teleporters (levels 2 and 3), are tasks Q3's and Q4's, which take their levels out of this list as they list them,
## and in NEW_MECHANICS.
const NOTHING_NEW: Array = ["beach/1", "beach/3", "dead_zone/2", "terminal/2", "ice_lab/1", "ice_lab/2", "ice_lab/3", "golden/3"]
## Zones that introduce no new enemy, the exceptions to GDD §5's rule, and why: the Casino ("every zone introduces
## at least one new enemy, except the Casino, which reuses the Marketplace's", owner, October 8, 2026) and the Beach,
## for now (owner, October 9, 2026: "Do not worry about any new enemies at this time"), and the Ice Lab until its two new
## enemies are designed (owner, October 21, 2026: they come in later sessions). None of them introduces anything else
## either (NOTHING_NEW), but for the mechanics in NEW_MECHANICS.
const NO_NEW_ENEMY: Dictionary = {
	"casino": "it reuses the Marketplace's (GDD §5, owner)",
	"beach": "a remix of everything before it (owner, October 9, 2026)",
	"ice_lab": "its two new enemies come in later sessions (owner, October 21, 2026)",
}
## The mechanics a zone of NO_NEW_ENEMY introduces all the same: the Casino's ceiling scenarios (task I4; GDD §3,
## "Ceiling scenarios": never in zones 1-2, sprinkled into later zones; DESIGN-TBD where they start,
## items 836–845 (docs/OPEN_QUESTIONS*.md)).
const NEW_MECHANICS: Dictionary = {
	"casino": ["treasure_stash", "fenced_ceiling"],
}
## The seed sweep: the levels with the most features (the Beach's remix has as many as Corporate 2), The
## Hush (paced in bursts) and the Terminal's (task O1: its own patterns, arches and walls without wall running), on
## this many seeds each at 3, 5 and 6 lanes.
const SWEEP_LEVELS: Array = ["gangland/3", "corporate/2", "beach/1", "beach/3", "dead_zone/1", "dead_zone/2", "terminal/1",
	"terminal/2", "golden/1", "golden/2", "golden/3"]
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
## levels' own seeds had 6 late of 63 on K2's curve, the check's limit (3 before; docs/OPEN_QUESTIONS.md §D,
## item 521 lists them for the owner), and have 5 on task K4's (docs/OPEN_QUESTIONS.md §D, item 531).
## Task J2's wall-run gaps are no pattern pick either: their rules put the first where a whole clear stretch (about
## 4 s of run in every lane, its run-in, lit stretch, gap and landing floor) fits past the start, the earliest that
## takes the least out of its way, which in Marketplace 1 is 5 to 26 s after it on its own seeds (WallRunGapPlacement;
## DESIGN-TBD, docs/questions/j2.md). Nothing of them before their start is checked all the same.
const SPACED_FROM_START: Array = ["wall_gaps", "wall_run_gaps"]
## The Hush's seed sweep's builds (_test_hush) with no fair room anywhere for a wall-run gap (task J2): at 3 lanes, their
## drone's pad schedule (a ceiling every 8 to 10 s from its first wave, whose pads it owns), their only hover truck and
## Octodog, their Enforcer Truck's chase and their ceilings' landing zones take every 4-second stretch, so they warn
## and have none (WallRunGapPlacement: nothing may go that the drone or a feature counts on). Every campaign build has
## its wall-run gaps (test_wall_run_gaps). Each is checked to still warn so (else take it out of the list).
## DESIGN-TBD (docs/questions/j2.md item 12).
const WALL_RUN_GAP_CROWDED: PackedStringArray = ["Dead Zone 1 lanes=3 seed=9208"]
## The warning a build in WALL_RUN_GAP_CROWDED gives (WallRunGapPlacement.place).
const WALL_RUN_GAP_WARNING: String = "wall-run gaps: no fair room anywhere for one (every feature should appear, GDD §5)"
## The campaign's first steps before the Casino (save version 2), in their old order: The House was the
## Marketplace's boss, and the Marketplace's outro led to Corporate (_test_old_saves).
const V2_STEPS: PackedStringArray = ["city/intro", "city/1", "city/2", "city/3", "city/boss_intro", "city/boss", "city/outro",
	"gangland/intro", "gangland/1", "gangland/2", "gangland/3", "gangland/boss", "gangland/outro",
	"marketplace/intro", "marketplace/1", "marketplace/2", "marketplace/boss", "marketplace/outro",
	"corporate/intro", "corporate/1", "corporate/2", "corporate/boss", "corporate/outro", "dead_zone/intro", "dead_zone/1"]
## Features that are enemies (for "every zone introduces at least one new enemy").
const ENEMIES: Array = ["cyborg", "window_cyborg", "hover_truck", "screech", "octodog", "generator", "drone",
	"barnacle_turret", "buzz_overdrive", "tithe_collector", "enforcer_truck", "host", "resonator", "gilded_sentinel",
	"centipede"]


func run() -> void:
	var campaign := load("res://data/campaign/campaign.tres") as Campaign
	check(campaign != null, "the campaign loads")
	if campaign == null:
		return
	_test_zones(campaign)
	_test_steps(campaign)
	_test_slots(campaign)
	_test_boss_intro_slots(campaign)
	_test_schedule(campaign)
	_test_curve_and_lengths(campaign)
	_test_no_level_easier(campaign)
	_test_off_curve(campaign)
	_test_terminal_off_curve(campaign)
	_test_ice_lab_off_curve(campaign)
	_test_skins(campaign)
	_test_levels_generate(campaign)
	_test_ceiling_gauntlets(campaign)
	_test_recency(campaign)
	_test_hush(campaign)
	_test_darker_lighting(campaign)
	_test_unlocking()


## Ten zones in GDD §5's order (the Casino fourth, owner, October 8, 2026; the Beach sixth, October 9; the Terminal
## eighth, October 20; the Ice Lab ninth, October 21), each built, with its levels, skin, music and tagline; only the City
## is in the web demo.
func _test_zones(campaign: Campaign) -> void:
	check(campaign.zones.size() == ZONES.size(), "the campaign has ten zones (GDD §5): %d" % campaign.zones.size())
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
		# Zones name their track after their id, and every zone's track exists (test_audio checks the files), but the
		# ones still to come, which the Music player skips quietly (the Terminal's, task O4).
		check(zone.music == zone.id, "%s's music track is named after the zone" % id)
		check(library.has(zone.music) or MUSIC_TO_COME.has(id), "%s's music exists" % id)
		check(zone.expected_loadout.is_empty(), "%s's expected loadout is still an empty placeholder (GDD §8)" % id)
	check(campaign.planned_level_count() == 25 and campaign.level_count() == 25, "25 levels (GDD §5): %d, %d planned" % [
		campaign.level_count(), campaign.planned_level_count()])
	# Task D10c: the Beach's levels are off the difficulty curve (its volleyball match too), and so are the Terminal's
	# (task O1) and the Ice Lab's (task Q1); the curve still spans the other 17.
	check(campaign.curve_level_count() == 17, "the difficulty curve spans the 17 levels on it (%d)" % campaign.curve_level_count())
	var dead_zone: ZoneDef = _zone(campaign, "dead_zone")
	var terminal: ZoneDef = _zone(campaign, "terminal")
	var ice_lab: ZoneDef = _zone(campaign, "ice_lab")
	var golden: ZoneDef = _zone(campaign, "golden")
	check(terminal != null and terminal.display_name == "The Terminal" and dead_zone != null and golden != null
		and terminal.run_speed > dead_zone.run_speed and terminal.run_speed < golden.run_speed,
		"the Terminal runs between the Dead Zone's speed and the Golden Zone's (%.1f m/s; DESIGN-TBD)"
		% (terminal.run_speed if terminal != null else 0.0))
	check(ice_lab != null and ice_lab.display_name == "The Ice Lab" and terminal != null and golden != null
		and ice_lab.run_speed > terminal.run_speed and ice_lab.run_speed < golden.run_speed,
		"the Ice Lab runs between the Terminal's speed and the Golden Zone's (%.1f m/s; DESIGN-TBD)"
		% (ice_lab.run_speed if ice_lab != null else 0.0))
	var casino: ZoneDef = _zone(campaign, "casino")
	var market: ZoneDef = _zone(campaign, "marketplace")
	var corporate: ZoneDef = _zone(campaign, "corporate")
	check(casino != null and market != null and corporate != null and casino.run_speed > market.run_speed
		and casino.run_speed < corporate.run_speed,
		"the Casino runs between the Marketplace's speed and Corporate's (%.1f m/s)" % (casino.run_speed if casino != null else 0.0))
	check(market != null and not market.tagline.to_lower().contains("casino"), "the Marketplace's tagline leaves the casinos to the Casino")


## Steps run intro, levels, boss intro, boss, outro per zone; step and level ids stay stable (the
## save file keys progress by step id: The House's records moved to casino/boss with the Casino, see
## _test_old_saves), the Marketplace, the Terminal and the Ice Lab lead from their levels to their outros with no boss, and
## Golden 3 is the Golden Palace. Each level's place on the difficulty curve (CampaignStep.level_index) counts the levels on
## it; the Beach's, off it (task D10c), take Corporate 2's, and the Terminal's (task O1) and the Ice Lab's (task Q1) Dead
## Zone 2's.
func _test_steps(campaign: Campaign) -> void:
	var expected := PackedStringArray([
		"city/intro", "city/1", "city/2", "city/3", "city/boss_intro", "city/boss", "city/outro",
		"gangland/intro", "gangland/1", "gangland/2", "gangland/3", "gangland/boss_intro", "gangland/boss", "gangland/outro",
		"marketplace/intro", "marketplace/1", "marketplace/2", "marketplace/outro",
		"casino/intro", "casino/1", "casino/2", "casino/boss_intro", "casino/boss", "casino/outro",
		"corporate/intro", "corporate/1", "corporate/2", "corporate/boss", "corporate/outro",
		"beach/intro", "beach/1", "beach/2", "beach/3", "beach/boss", "beach/outro",
		"dead_zone/intro", "dead_zone/1", "dead_zone/2", "dead_zone/boss", "dead_zone/outro",
		"terminal/intro", "terminal/1", "terminal/2", "terminal/outro",
		"ice_lab/intro", "ice_lab/1", "ice_lab/2", "ice_lab/3", "ice_lab/outro",
		"golden/intro", "golden/1", "golden/2", "golden/3", "golden/boss", "golden/outro"])
	var ids := PackedStringArray()
	for s: CampaignStep in campaign.steps():
		ids.append(s.id)
	check(ids == expected, "the campaign's steps, in order: %s" % ", ".join(ids))
	var seeds: Dictionary = {}
	var place: int = 0
	for s: CampaignStep in campaign.steps():
		if not s.is_level():
			continue
		var level_id: String = "%s_%d" % [s.zone.id, s.number_in_zone]
		check(String(s.level.id) == level_id and s.level.resource_path == "res://data/levels/%s.tres" % level_id,
			"step %s plays level %s from its own file (%s)" % [s.id, level_id, s.level.resource_path])
		var off: bool = s.zone.id == &"beach" or s.zone.id == &"terminal" or s.zone.id == &"ice_lab"
		check(s.level.off_curve == off, "%s is %s the difficulty curve" % [s.id, "off" if off else "on"])
		var at: int = maxi(place - 1, 0) if s.level.off_curve else place
		check(s.level_index == at, "%s takes place %d on the difficulty curve (%d)" % [s.id, at + 1, s.level_index + 1])
		check(s.level.display_name != "", "%s has a name" % s.id)
		check(not seeds.has(s.level.level_seed), "%s has its own fixed seed (GDD §6)" % s.id)
		seeds[s.level.level_seed] = true
		if not s.level.off_curve:
			place += 1
	check(campaign.step("golden/3") != null and campaign.step("golden/3").title() == "The Golden Palace",
		"Golden 3 is the Golden Palace (GDD §5)")
	check(campaign.step("beach/1").title() == "Tiki Tides" and campaign.step("beach/2").title() == "Net Gains"
		and campaign.step("beach/3").title() == "Sunset Strip",
		"the Beach's levels are Tiki Tides, Net Gains (the volleyball match) and Sunset Strip (GDD §5)")
	check(campaign.step("terminal/1").title() == "Rubble Line" and campaign.step("terminal/2").title() == "Last Stop",
		"the Terminal's levels are Rubble Line and Last Stop (GDD §5, proposed)")
	check(campaign.step("terminal/1").level_index == campaign.step("dead_zone/2").level_index
		and campaign.step("golden/1").level_index == campaign.step("dead_zone/2").level_index + 1,
		"the Terminal's levels take Dead Zone 2's place on the curve, and Golden 1 keeps its own")
	check(campaign.step("ice_lab/1").title() == "Frost Foundry" and campaign.step("ice_lab/2").title() == "Relay Station"
		and campaign.step("ice_lab/3").title() == "Specimen Vault",
		"the Ice Lab's levels are Frost Foundry, Relay Station and Specimen Vault (GDD §5, proposed)")
	var at_dz2: bool = true
	for number: int in [1, 2, 3]:
		at_dz2 = at_dz2 and campaign.step("ice_lab/%d" % number).level_index == campaign.step("dead_zone/2").level_index
	check(at_dz2, "the Ice Lab's levels take Dead Zone 2's place on the curve too, the last level on it before them")
	for st: CampaignStep in campaign.steps():
		check(st.is_minigame() == (st.id == "beach/2"), "%s %s a mini-game" % [st.id, "plays" if st.id == "beach/2" else "doesn't play"])


## A boss slot per zone from GDD §10's roster (none for the Marketplace, which leads straight into the
## Casino, whose boss The House now is: owner, October 8, 2026), and cinematic slots: every zone's intro and
## outro, and the City's and Gangland's boss intros (the intros play placeholder flyovers, task F1, but the
## Dead Zone's, and Gangland's boss intro and the Dead Zone's intro the owner's beats; test_cinematics,
## test_sewer_swarm_intro and test_dead_zone_intro check them).
func _test_slots(campaign: Campaign) -> void:
	# The Beach's boss: Mecha Guppy and Captain Cogs (GDD §10; the owner's title, docs/OPEN_QUESTIONS.md, item 762).
	# The Terminal has no boss (owner, October 20, 2026; GDD §5, Zone 8): it leads straight into the next zone, the Ice
	# Lab, which has none either (owner, October 21, 2026; GDD §5, Zone 9) and leads straight into the Golden Zone.
	var bosses: Dictionary = {"city": "Floating Head", "gangland": "Sewer Swarm", "marketplace": "",
		"casino": "The House", "corporate": "Hostile Takeover", "beach": "Mecha Guppy and Captain Cogs", "dead_zone": "Sleep Taker",
		"terminal": "", "ice_lab": "", "golden": "The Golden Convergence"}
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
		# Item 395: every boss has an intro slot; the City's, Gangland's and the Casino's are built, the rest empty and
		# skipped.
		check((zone.boss_intro != null) == (zone.boss != null), "%s has a boss-intro slot exactly when it has a boss" % id)
		check(zone.boss_intro == null or (zone.boss_intro.is_built() == (id in ["city", "gangland", "casino"])
			and zone.boss_intro.is_skipped() == not (id in ["city", "gangland", "casino"])),
			"%s's boss-intro slot is built (the City's, Gangland's, the Casino's) or empty and skipped (item 395)" % id)
		for def: CinematicDef in [zone.intro, zone.boss_intro, zone.outro]:
			if def != null:
				check(String(def.id).begins_with(id + "_") and def.title != "" and def.placeholder_text != "",
					"cinematic slot %s has its id, title and text" % def.id)
	var golden: ZoneDef = campaign.zones[-1]
	check(golden.boss != null and golden.boss.notes.contains("checkpoint halfway"),
		"the final villain's slot notes the halfway checkpoint (GDD §10)")
	check(golden.boss != null and golden.boss.phase_count() == 6 and golden.boss.checkpoint_phase() == 3,
		"and its data has the checkpoint at the second stage's first phase (phase 4 of 6, task E5d-a)")
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
		elif s.kind == CampaignStep.Kind.BOSS and s.zone.id == &"golden":
			check(s.boss != null and s.boss.is_built(), "the Golden Zone's boss step plays The Golden Convergence's fight (task E5d-c)")
		elif s.kind == CampaignStep.Kind.BOSS and s.zone.id == &"beach":
			# GDD §10: Mecha Guppy and Captain Cogs (task E5e): the slot names its scene since E5e-c.
			check(s.boss != null and s.boss.is_built() and s.boss.preview() == null and s.boss.phase_count() == 3
				and s.boss.scene == "res://scenes/bosses/mecha_guppy.tscn",
				"the Beach's boss step plays Mecha Guppy and Captain Cogs' fight (task E5e-c)")
		elif s.kind == CampaignStep.Kind.BOSS:
			check(s.boss != null and not s.boss.is_built(), "boss slot %s is still a placeholder" % s.id)
		elif s.kind == CampaignStep.Kind.CINEMATIC and s.id == "gangland/boss_intro":
			check(s.cinematic != null and s.cinematic.scene == "res://scenes/cinematics/sewer_swarm_intro.tscn" and s.cinematic.is_built(),
				"Gangland's boss intro plays its own scene, the owner's beat (task F2b)")
		elif s.kind == CampaignStep.Kind.CINEMATIC and s.id == "casino/boss_intro":
			check(s.cinematic != null and s.cinematic.scene == "res://scenes/cinematics/casino_boss_intro.tscn" and s.cinematic.is_built(),
				"the Casino's boss intro plays its own scene, the owner's beats (task F2i)")
		elif s.kind == CampaignStep.Kind.CINEMATIC and s.id == "gangland/intro":
			check(s.cinematic != null and s.cinematic.scene == "res://scenes/cinematics/gangland_intro.tscn" and s.cinematic.is_built(),
				"Gangland's intro plays its own scene, the owner's beats (task F2h)")
		elif s.kind == CampaignStep.Kind.CINEMATIC and s.id == "terminal/intro":
			check(s.cinematic != null and s.cinematic.scene == "res://scenes/cinematics/terminal_intro.tscn" and s.cinematic.is_built(),
				"the Terminal's intro plays its own scene, the owner's beats (task F2k)")
		elif s.kind == CampaignStep.Kind.CINEMATIC and s.id == "casino/intro":
			check(s.cinematic != null and s.cinematic.scene == "res://scenes/cinematics/casino_intro.tscn" and s.cinematic.is_built(),
				"the Casino's intro plays its own scene, the owner's beats (task F2j)")
		elif s.kind == CampaignStep.Kind.CINEMATIC and s.id == "marketplace/intro":
			check(s.cinematic != null and s.cinematic.scene == "res://scenes/cinematics/marketplace_intro.tscn" and s.cinematic.is_built(),
				"the Marketplace's intro plays its own scene, the owner's beats (task F2f)")
		elif s.kind == CampaignStep.Kind.CINEMATIC and s.id == "dead_zone/intro":
			check(s.cinematic != null and s.cinematic.scene == "res://scenes/cinematics/dead_zone_intro.tscn" and s.cinematic.is_built(),
				"the Dead Zone's intro plays its own scene, the owner's beats (task F2d)")
		elif s.kind == CampaignStep.Kind.CINEMATIC and s.id == "city/intro":
			check(s.cinematic != null and s.cinematic.scene == "res://scenes/cinematics/city_intro.tscn" and s.cinematic.is_built(),
				"the City's intro plays its own scene, the owner's beats (task F2h)")
		elif s.kind == CampaignStep.Kind.CINEMATIC and s.id.ends_with("intro"):
			check(s.cinematic != null and s.cinematic.scene == "res://scenes/cinematics/arrival_flyover.tscn"
				and s.cinematic.is_built(), "cinematic slot %s plays the placeholder arrival flyover (task F1)" % s.id)
		elif s.kind == CampaignStep.Kind.CINEMATIC and s.zone == campaign.zones[0] and s.id.ends_with("outro"):
			check(s.cinematic != null and s.cinematic.scene == "res://scenes/cinematics/city_outro.tscn"
				and s.cinematic.is_built(), "the City's outro slot plays its cinematic (task F2a)")
		elif s.kind == CampaignStep.Kind.CINEMATIC and s.id == "gangland/outro":
			check(s.cinematic != null and s.cinematic.scene == "res://scenes/cinematics/gangland_outro.tscn"
				and s.cinematic.is_built(), "Gangland's outro slot plays its cinematic, the owner's beats (task F2d)")
		elif s.kind == CampaignStep.Kind.CINEMATIC and s.id == "beach/outro":
			check(s.cinematic != null and s.cinematic.scene == "res://scenes/cinematics/beach_outro.tscn"
				and s.cinematic.is_built(), "the Beach's outro slot plays its cinematic, the owner's beats (task F2e)")
		elif s.kind == CampaignStep.Kind.CINEMATIC:
			check(s.cinematic != null and not s.cinematic.is_built(), "cinematic slot %s is still a placeholder" % s.id)


## GDD §5's schedule in the level data: each feature first appears in its level; later levels keep
## it (with the documented exceptions); every zone brings a new enemy and each level about one new
## thing, each introduced at a start of its own (LevelConfig.feature_starts), City 1's cyborgs late.
## Item 395 (task I8): every boss has an intro slot. The City's, Gangland's and the Casino's play (The House's since the
## owner's beats of October 17, 2026); the other four (Hostile Takeover, the Beach's, the Sleep Taker's, the Golden
## Convergence's) are empty slots the campaign skips:
## no step, so no screen, no delay and no save entry; Marketplace has no boss, so no slot. Filling one needs only
## its def's scene.
func _test_boss_intro_slots(campaign: Campaign) -> void:
	var empty_zones: PackedStringArray = ["corporate", "beach", "dead_zone", "golden"]
	var listed: PackedStringArray = []
	for slot: Dictionary in campaign.empty_slots():
		listed.append(String(slot["id"]))
	check(listed == PackedStringArray(["corporate/boss_intro", "beach/boss_intro", "dead_zone/boss_intro", "golden/boss_intro"]),
		"the campaign lists the four empty boss-intro slots in order (%s)" % [listed])
	for zone: ZoneDef in campaign.zones:
		var id: String = String(zone.id)
		if id in empty_zones:
			var def: CinematicDef = zone.boss_intro
			check(def != null and def.scene == "" and def.skip_while_empty and def.is_skipped() and not def.is_built()
				and String(def.id) == id + "_boss_intro", "%s's boss intro is an empty slot" % id)
			check(campaign.step(id + "/boss_intro") == null, "%s's boss intro has no step: the campaign skips it" % id)
			var boss: CampaignStep = campaign.step(id + "/boss")
			var before: CampaignStep = campaign.steps()[boss.index - 1]
			check(boss != null and before.zone == zone and before.is_level() and campaign.next_step(before) == boss,
				"%s: the step after the zone's last level is its boss (nothing between)" % id)
		elif id in ["city", "gangland"]:
			var built: CampaignStep = campaign.step(id + "/boss_intro")
			check(built != null and built.cinematic.is_built() and not built.cinematic.is_skipped()
				and campaign.next_step(built) == campaign.step(id + "/boss"), "%s's boss intro still plays, before its boss" % id)
	# Nothing else about the schedule changes: no empty slot has a step, and the indices run on without a gap.
	var ids: PackedStringArray = []
	var in_order: bool = true
	for s: CampaignStep in campaign.steps():
		in_order = in_order and s.index == ids.size()
		ids.append(s.id)
	var no_empty: bool = true
	for slot: Dictionary in campaign.empty_slots():
		no_empty = no_empty and not ids.has(String(slot["id"]))
	check(in_order and no_empty, "no empty slot has a step, and the steps' indices run on in order")
	# Filling a slot is data only: with a scene set, the same campaign gets the step, before the boss.
	var def: CinematicDef = campaign.step("golden/boss").zone.boss_intro
	def.scene = "res://scenes/cinematics/arrival_flyover.tscn"
	var filled := campaign.duplicate() as Campaign
	var added: CampaignStep = filled.step("golden/boss_intro")
	check(added != null and filled.next_step(added) == filled.step("golden/boss") and filled.steps().size() == ids.size() + 1
		and not def.is_skipped() and filled.empty_slots().size() == 3 and filled.step("golden/3").index + 1 == added.index,
		"setting the slot's scene brings its step in, between the last level and the boss, and takes it off the empty list")
	var old_save := Profile.new()
	for s: CampaignStep in campaign.steps():
		if s.index <= campaign.step("golden/boss").index:
			old_save.record_run(s.id, 0, true, 1000, 3, 90.0)
	var app: Node = tree.root.get_node_or_null(^"App")
	var saved: Campaign = null
	var saved_profile: Profile = null
	if app != null:
		saved = App.campaign
		saved_profile = App.profile
		App.campaign = filled
		App.profile = old_save
		check(App.step_done(added) and App.step_unlocked(filled.step("golden/boss")) and App.step_unlocked(filled.step("golden/outro"))
			and App.next_unfinished_step() == filled.step("golden/outro"),
			"a save from before the slot was filled counts it done: the boss stays open and Continue goes on to the outro")
		App.campaign = saved
		App.profile = saved_profile
	def.scene = ""
	check(def.is_skipped() and campaign.step("golden/boss_intro") == null, "(the slot is empty again)")
	# The web demo ends after the City's boss: its scope and steps are as they were.
	BuildFlavor.set_override(BuildFlavor.Kind.WEB_DEMO)
	for s: CampaignStep in campaign.steps():
		check(s.zone.in_demo == (s.zone.id == &"city"), "web demo: %s is in scope only for the City" % s.id)
	BuildFlavor.set_override(-1)


func _test_schedule(campaign: Campaign) -> void:
	var levels: Array[CampaignStep] = []
	for s: CampaignStep in campaign.steps():
		# The Beach's volleyball match places no features: it's no part of the schedule.
		if s.is_level() and not s.is_minigame():
			levels.append(s)
	check(campaign.step("beach/2").level.features.is_empty(), "the volleyball match lists no features")
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
		# Anything introduced earlier keeps appearing later (GDD §5), bar the documented exceptions: the Terminal keeps
		# only its ceilings and its walls' open space (TERMINAL_KEEPS), and the Ice Lab leaves out every earlier enemy but
		# its cyborgs, Octodogs and heli drones, the dash walls and the Terminal's maze (ICE_LAB_LEAVES_OUT).
		var terminal: bool = s.zone.id == &"terminal"
		var ice_lab: bool = s.zone.id == &"ice_lab"
		for f: String in seen:
			if not s.level.has_feature(f):
				check((LEFT_OUT.get(f, []) as Array).has(s.id) or (terminal and FIRST_LEVEL.get(f, "") != "terminal/1")
					or (ice_lab and ICE_LAB_LEAVES_OUT.has(f)), "%s keeps `%s` (introduced in %s)" % [s.id, f, first_seen[f]])
			elif terminal and FIRST_LEVEL.get(f, "") != "terminal/1":
				check(TERMINAL_KEEPS.has(f), "%s leaves out `%s`: none of the usual enemies, no dash walls, no wall running (GDD §5, Zone 8)"
					% [s.id, f])
			elif ice_lab:
				check(not ICE_LAB_LEAVES_OUT.has(f),
					"%s leaves out `%s`: its enemies are the cyborgs, the Octodogs and the heli drones, and no dash walls (GDD §5, Zone 9)"
					% [s.id, f])
		if first_seen.has("screech") and s.id != "marketplace/1" and not terminal and not ice_lab:
			check(s.level.has_feature("screech") or s.level.has_feature("screech_vents"),
				"%s keeps sewer screeches, from manholes or wall vents" % s.id)
	for f: String in FIRST_LEVEL:
		check(first_seen.get(f, "") == FIRST_LEVEL[f], "`%s` first appears in %s (%s)" % [f, FIRST_LEVEL[f], first_seen.get(f, "never")])
	for f: String in first_seen:
		check(FIRST_LEVEL.has(f), "`%s` has its place in the schedule" % f)
	for zone: Array in ZONES:
		var new_enemy: bool = false
		var new_thing: bool = false
		for f: String in first_seen:
			new_enemy = new_enemy or (ENEMIES.has(f) and String(first_seen[f]).begins_with(String(zone[0]) + "/"))
			new_thing = new_thing or (String(first_seen[f]).begins_with(String(zone[0]) + "/")
				and not (NEW_MECHANICS.get(zone[0], []) as Array).has(f))
		if NO_NEW_ENEMY.has(zone[0]):
			check(not new_enemy and not new_thing, "%s introduces no new enemy, nor anything else: %s" % [zone[0],
				NO_NEW_ENEMY[zone[0]]])
		else:
			check(new_enemy, "%s introduces at least one new enemy (GDD §5)" % zone[0])
	# The Casino plays the Marketplace's last level's set (task K2, DESIGN-TBD until the owner says what each Casino
	# level adds): every feature the Marketplace brought, and no new enemy; and it brings in the ceiling scenarios
	# (task I4), Casino 1 the treasure stash and Casino 2 the fenced ceiling, each from a start of its own.
	var market_2: LevelConfig = campaign.step("marketplace/2").level
	var scenarios: Dictionary = {"casino/1": ["treasure_stash"], "casino/2": ["treasure_stash", "fenced_ceiling"]}
	for id: String in scenarios:
		var casino: LevelConfig = campaign.step(id).level
		var want: PackedStringArray = market_2.features.duplicate()
		for f: String in scenarios[id]:
			want.append(f)
		var starts: Array = casino.feature_starts.keys()
		check(casino.features == want and starts.size() == 1 and starts[0] == (scenarios[id] as Array)[-1],
			"%s plays Marketplace 2's features and brings in a ceiling scenario (%s; starts %s)" % [id, casino.features, starts])
	var city_1: LevelConfig = campaign.step("city/1").level
	check(city_1.feature_start("cyborg") >= 0.5, "City 1's cyborgs come late in the level (%.2f)" % city_1.feature_start("cyborg"))
	for id: String in ["marketplace/1", "marketplace/2", "casino/1", "casino/2", "corporate/1", "corporate/2", "beach/1", "beach/3",
			"terminal/1", "terminal/2", "ice_lab/1", "ice_lab/2", "ice_lab/3", "golden/1", "golden/2", "golden/3"]:
		check(not campaign.step(id).level.has_feature("screech"), "no manholes in %s's floor" % id)
	# GDD §9.9 (corrected): the Buzz Overdrive, from Corporate 1 through the Golden Zone.
	for s: CampaignStep in levels:
		var listed: bool = BUZZ_OVERDRIVE_LEVELS.has(s.id)
		check(s.level.has_feature("buzz_overdrive") == listed,
			"%s %s the Buzz Overdrive (GDD §9.9)" % [s.id, "lists" if listed else "doesn't list"])
	for s: CampaignStep in levels:
		var has_octodogs: bool = s.level_index >= campaign.step("gangland/2").level_index \
			and s.zone.id != &"golden" and s.zone.id != &"terminal"
		check(s.level.has_feature("octodog") == has_octodogs,
			"%s keeps Octodogs only from Gangland 2 through the Dead Zone and in the Ice Lab (Zone & Levels 2; none in the Terminal, GDD §5)"
			% s.id)
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


## No level gets easier when levels are added (owner, October 9, 2026, GDD §6; task K4): every level the
## campaign had before the Casino is at least as hard as on the 15-level linear curve it had then (the
## campaign without the Casino's zone, and without the Beach's, at exponent 1), City 1 and Golden 3 as they were;
## the Marketplace's at least as hard (a little harder is welcome). The curve's exponent
## (data/campaign/campaign.tres) lifts the early and middle levels, and leaves enemy scaling linear. (The Beach's
## levels, the Terminal's and the Ice Lab's, off the curve, change nothing on it: _test_off_curve.)
func _test_no_level_easier(campaign: Campaign) -> void:
	var before := campaign.duplicate() as Campaign
	var zones: Array[ZoneDef] = []
	for z: ZoneDef in campaign.zones:
		if z.id != &"casino" and z.id != &"beach" and z.id != &"terminal" and z.id != &"ice_lab":
			zones.append(z)
	before.zones = zones
	before.difficulty_curve_exponent = 1.0
	check(before.level_count() == 15, "the campaign before the Casino, the Beach, the Terminal and the Ice Lab had 15 levels (%d)"
		% before.level_count())
	check(campaign.difficulty_curve_exponent < 1.0, "the curve is concave: it lifts the early and middle levels (%.2f)"
		% campaign.difficulty_curve_exponent)
	var lines: PackedStringArray = []
	for s: CampaignStep in before.steps():
		if not s.is_level():
			continue
		var was: float = before.configure(s, 5).difficulty
		var now: float = campaign.configure(campaign.step(s.id), 5).difficulty
		check(now >= was - 0.0005, "%s is no easier than before the Casino (%.3f, was %.3f)" % [s.id, now, was])
		if s.id == "city/1" or s.id == "golden/3":
			check(is_equal_approx(now, was), "%s keeps its difficulty (%.3f)" % [s.id, now])
		lines.append("%s %.3f→%.3f" % [s.id, was, now])
	print("  difficulty against the 15-level curve before the Casino: %s" % ", ".join(lines))
	# The exponent bends the difficulty only: enemy scaling stays linear over the 17 levels on the curve (the
	# Beach's, off it, play at their own: _test_off_curve), which task K2's moved thresholds
	# (docs/OPEN_QUESTIONS.md §D, item 520) were set against.
	for s: CampaignStep in campaign.steps():
		if s.is_level() and not s.level.off_curve:
			var linear: float = float(s.level_index) / float(campaign.curve_level_count() - 1)
			check(is_equal_approx(campaign.configure(s, 5).enemy_scaling, linear),
				"%s keeps its linear enemy scaling (%.4f)" % [s.id, campaign.configure(s, 5).enemy_scaling])


## Each level is slightly harder than the last (GDD §6), up to Golden 2's peak (GDD §5, proposed), the
## automatic curve spanning the 17 levels on it; enemy scaling runs 0 → 1 across the campaign; City 1 lasts 55 s
## (Zone & Levels 1), the other levels keep their durations within 90–150 s, and together take about 57 minutes
## (GDD §5, with the Casino's, the Beach's, the Terminal's and the Ice Lab's levels). A level off the curve (the Beach's,
## task D10c; the Terminal's, task O1; the Ice Lab's, task Q1) lies strictly between the levels on it either side, in
## difficulty and enemy scaling, and still rises from the level before it.
func _test_curve_and_lengths(campaign: Campaign) -> void:
	var last_curve: float = -1.0
	for i: int in campaign.curve_level_count():
		var d: float = campaign.curve_difficulty(i)
		check(d > last_curve, "the curve rises at level %d (%.2f)" % [i + 1, d])
		last_curve = d
	var difficulties: Array[float] = []
	var scaling: Array[float] = []
	var total: float = 0.0
	var steps: Array[CampaignStep] = []
	for s: CampaignStep in campaign.steps():
		if s.is_minigame():
			# The volleyball match: its length counts toward a flawless run, but nothing generated rises with it.
			total += s.level.duration_seconds
			check(is_equal_approx(s.level.duration_seconds, LEVEL_DURATIONS[s.id]), "%s lasts %.0f s" % [s.id, LEVEL_DURATIONS[s.id]])
			continue
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
	var on_curve: int = 0
	for i: int in range(1, difficulties.size()):
		if steps[i].level.off_curve:
			var next: int = i + 1
			while next < steps.size() and steps[next].level.off_curve:
				next += 1
			check(next < steps.size() and difficulties[i] > difficulties[i - 1] and difficulties[i] < difficulties[next],
				"%s, off the curve, is harder than %s and easier than %s (%.3f)" % [steps[i].id, steps[i - 1].id,
					steps[mini(next, steps.size() - 1)].id, difficulties[i]])
			check(next < steps.size() and scaling[i] > scaling[i - 1] and scaling[i] < scaling[next],
				"and its enemy scaling lies between theirs (%.3f)" % scaling[i])
			continue
		if i <= peak:
			# The levels on the curve each step up from the last level on it.
			check(difficulties[i] > difficulties[on_curve] + 0.02 and difficulties[i] > difficulties[i - 1],
				"%s is harder than %s (%.2f after %.2f)" % [steps[i].id, steps[on_curve].id, difficulties[i], difficulties[on_curve]])
		else:
			check(difficulties[i] < difficulties[peak] and difficulties[i] > difficulties[peak - 1],
				"%s sits just below Golden 2's peak (%.2f)" % [steps[i].id, difficulties[i]])
		check(scaling[i] > scaling[i - 1], "enemy scaling rises at %s" % steps[i].id)
		on_curve = i
	check(peak == difficulties.size() - 2 and difficulties.max() == difficulties[peak], "Golden 2 is the hardest level")
	check(is_equal_approx(scaling[0], 0.0) and is_equal_approx(scaling[-1], 1.0), "enemy scaling runs 0 → 1 (GDD §6)")
	# GDD §5 says about 45 minutes; the Terminal's two levels (task O1: 140 and 145 s, like their neighbours') made it
	# about 50 (DESIGN-TBD, docs/questions/o1.md, item 1053), and the Ice Lab's three (task Q1: 140, 145 and 150 s) about
	# 57 (DESIGN-TBD, docs/questions/q1.md).
	check(total >= 54.0 * 60.0 and total <= 59.0 * 60.0,
		"a flawless run through every level takes about 57 minutes (GDD §5's 45, the Terminal's two levels and the Ice Lab's three): %.1f min"
		% (total / 60.0))
	var first: CampaignStep = campaign.step("city/1")
	var c1: LevelConfig = campaign.configure(first, 5)
	check(c1.lane_count == 5 and c1 != first.level, "configure returns a copy with the lane count")
	check(campaign.configure(steps[-1], 3, 1).difficulty >= campaign.configure(steps[-1], 3, 0).difficulty,
		"harder tiers never lower difficulty")
	check(campaign.configure(steps[4], 3, 1).difficulty > campaign.configure(steps[4], 3, 0).difficulty,
		"harder tiers raise difficulty")


## The Beach joins the campaign off its difficulty curve (task D10c; LevelConfig.off_curve): at 3, 5 and 6 lanes and
## every difficulty tier its levels play at their own difficulty (plus the tier's bonus) and enemy scaling, strictly
## between Corporate 2's and Dead Zone 1's, at the zone's run speed, and its boss slot's arena at Sunset Strip's
## scaling. Every other level and boss configures exactly as in the seven-zone campaign before the Beach (origin/main's,
## with the Casino: task D10d): the same place on the curve, difficulty, enemy scaling, run speed, feature ages, skin and
## sky, and the same completion bonus.
func _test_off_curve(campaign: Campaign) -> void:
	var before: CampaignStep = campaign.step("corporate/2")
	var after: CampaignStep = campaign.step("dead_zone/1")
	var corporate: ZoneDef = _zone(campaign, "corporate")
	var dead: ZoneDef = _zone(campaign, "dead_zone")
	var beach: ZoneDef = _zone(campaign, "beach")
	check(beach != null and beach.run_speed > corporate.run_speed and beach.run_speed < dead.run_speed
		and is_equal_approx(beach.run_speed, 23.8), "the Beach runs at 23.8 m/s, between Corporate and the Dead Zone")
	var last_difficulty: float = campaign.configure(before, 5).difficulty
	var last_scaling: float = campaign.configure(before, 5).enemy_scaling
	# The Beach's generated levels (its volleyball match, beach/2, is off the curve too but generates nothing:
	# _test_steps, test_volleyball).
	for number: int in [1, 3]:
		var s: CampaignStep = campaign.step("beach/%d" % number)
		for tier: int in campaign.tier_count():
			for lanes: int in [3, 5, 6]:
				var tag: String = "%s lanes=%d tier=%d" % [s.id, lanes, tier]
				var config: LevelConfig = campaign.configure(s, lanes, tier)
				check(config.lane_count == lanes and config.off_curve
					and is_equal_approx(config.difficulty, clampf(s.level.difficulty + campaign.tier_difficulty_bonus[tier], 0.0, 1.0))
					and is_equal_approx(config.enemy_scaling, s.level.enemy_scaling),
					"%s plays at its own difficulty plus the tier's bonus (%.2f) and its own enemy scaling (%.2f)" % [tag,
						config.difficulty, config.enemy_scaling])
				check(is_equal_approx(config.run_speed, beach.run_speed * campaign.speed_multiplier(tier)),
					"%s runs at the Beach's speed times the tier's (%.2f)" % [tag, config.run_speed])
		var plain: LevelConfig = campaign.configure(s, 5)
		check(plain.difficulty > last_difficulty and plain.difficulty < campaign.configure(after, 5).difficulty
			and plain.enemy_scaling > last_scaling and plain.enemy_scaling < campaign.configure(after, 5).enemy_scaling,
			"%s lies strictly between Corporate 2 and Dead Zone 1, rising (difficulty %.3f, enemy scaling %.3f)" % [s.id,
				plain.difficulty, plain.enemy_scaling])
		last_difficulty = plain.difficulty
		last_scaling = plain.enemy_scaling
		check(s.level_index == before.level_index and App.rules.completion_bonus(s.level_index) == App.rules.completion_bonus(before.level_index),
			"%s takes Corporate 2's place on the curve, and its completion bonus (DESIGN-TBD, docs/OPEN_QUESTIONS.md, item 572)" % s.id)
	var boss: CampaignStep = campaign.step("beach/boss")
	for tier: int in campaign.tier_count():
		var arena: LevelConfig = campaign.configure_boss(boss, 5, tier)
		check(is_equal_approx(arena.enemy_scaling, campaign.step("beach/3").level.enemy_scaling)
			and is_equal_approx(arena.run_speed, beach.run_speed * campaign.speed_multiplier(tier))
			and arena.sky == campaign.step("beach/3").level.sky,
			"the Beach's boss slot fights at Sunset Strip's enemy scaling, the Beach's speed and Sunset Strip's sky (tier %d)" % tier)

	# The campaign before the Beach, built from the same data without it (and without the Terminal and the Ice Lab, which
	# came after it: _test_terminal_off_curve, _test_ice_lab_off_curve).
	var seven := campaign.duplicate() as Campaign
	var zones: Array[ZoneDef] = []
	for zone: ZoneDef in campaign.zones:
		if zone.id != &"beach" and zone.id != &"terminal" and zone.id != &"ice_lab":
			zones.append(zone)
	seven.zones = zones
	check(seven.steps().size() == campaign.steps().size() - 6 - 4 - 5 and seven.level_count() == 17
		and seven.curve_level_count() == 17,
		"the seven-zone campaign has the Beach's six steps, the Terminal's four and the Ice Lab's five less and 17 levels (%d)"
		% seven.level_count())
	var same: int = 0
	for old: CampaignStep in seven.steps():
		var now: CampaignStep = campaign.step(old.id)
		check(now != null and now.kind == old.kind and now.level_index == old.level_index,
			"%s keeps its kind and its place on the curve (%d)" % [old.id, now.level_index if now != null else -99])
		if now == null or old.kind == CampaignStep.Kind.CINEMATIC:
			continue
		var ok: bool = true
		for tier: int in campaign.tier_count():
			for lanes: int in [3, 5, 6]:
				var a: LevelConfig = seven.configure(old, lanes, tier) if old.is_level() else seven.configure_boss(old, lanes, tier)
				var b: LevelConfig = campaign.configure(now, lanes, tier) if now.is_level() else campaign.configure_boss(now, lanes, tier)
				ok = ok and a.difficulty == b.difficulty and a.enemy_scaling == b.enemy_scaling and a.run_speed == b.run_speed \
					and a.lane_count == b.lane_count and a.skin == b.skin and a.sky == b.sky and a.feature_recency == b.feature_recency \
					and var_to_str(a.feature_ages) == var_to_str(b.feature_ages)
		if old.is_level():
			ok = ok and App.rules.completion_bonus(old.level_index) == App.rules.completion_bonus(now.level_index)
		check(ok, "%s configures exactly as before the Beach, at 3, 5 and 6 lanes and every tier" % old.id)
		same += 1 if ok else 0
	check(same == 17 + 6, "every level and boss before and after the Beach is unchanged (%d of 23)" % same)

	# The volleyball match (the owner, October 10, 2026) came in as Beach 2: the campaign with the Beach's first two
	# levels only, as before it, configures every step the same, Sunset Strip (now beach/3, then beach/2) included:
	# the match is off the curve and counts for no level's feature ages.
	var two_level_beach := beach.duplicate() as ZoneDef
	var two_levels: Array[LevelConfig] = []
	for level: LevelConfig in beach.levels:
		if not level.plays_minigame():
			two_levels.append(level)
	two_level_beach.levels = two_levels
	var before_match := campaign.duplicate() as Campaign
	var with_two: Array[ZoneDef] = []
	for zone: ZoneDef in campaign.zones:
		# The Terminal and the Ice Lab came after the match (tasks O1, Q1): left out here, as they were then.
		if zone.id != &"terminal" and zone.id != &"ice_lab":
			with_two.append(two_level_beach if zone == beach else zone)
	before_match.zones = with_two
	check(before_match.level_count() == 19 and before_match.curve_level_count() == 17
		and before_match.step("beach/2").level == campaign.step("beach/3").level,
		"before the match, Sunset Strip was beach/2 of 19 levels, 17 on the curve")
	var unchanged: int = 0
	var compared: int = 0
	for old: CampaignStep in before_match.steps():
		if old.kind == CampaignStep.Kind.CINEMATIC:
			continue
		var now_id: String = "beach/3" if old.id == "beach/2" else old.id
		var now: CampaignStep = campaign.step(now_id)
		var ok: bool = now != null and now.level_index == old.level_index
		for tier: int in campaign.tier_count():
			for lanes: int in [3, 5, 6]:
				if not ok:
					break
				var a: LevelConfig = before_match.configure(old, lanes, tier) if old.is_level() \
					else before_match.configure_boss(old, lanes, tier)
				var b: LevelConfig = campaign.configure(now, lanes, tier) if now.is_level() else campaign.configure_boss(now, lanes, tier)
				ok = ok and a.difficulty == b.difficulty and a.enemy_scaling == b.enemy_scaling and a.run_speed == b.run_speed \
					and a.skin == b.skin and a.sky == b.sky and var_to_str(a.feature_ages) == var_to_str(b.feature_ages)
		compared += 1
		unchanged += 1 if ok else 0
		if not ok:
			check(false, "%s (now %s) configures as before the volleyball match" % [old.id, now_id])
	check(unchanged == compared and compared == 19 + 7, "every level and boss configures as before the volleyball match (%d of %d)" % [
		unchanged, compared])


## The Terminal joins the campaign off its difficulty curve (task O1, like the Beach; the owner's rule, GDD §6: no level
## gets easier when levels are added): its levels lie strictly between Dead Zone 2's and Golden 1's, at the zone's run
## speed, between the Dead Zone's and the Golden Zone's, and take Dead Zone 2's place on the curve and its completion
## bonus; every other level and boss configures exactly as in the campaign before it (the same data without the Terminal,
## or the Ice Lab, which came after it), so the Golden Zone and the weekly challenge's Sentinel Row play as they did
## (_check_joins_off_curve). DESIGN-TBD (docs/questions/o1.md): the numbers, and whether the curve is later re-spread over
## every level.
func _test_terminal_off_curve(campaign: Campaign) -> void:
	_check_joins_off_curve(campaign, "terminal", "dead_zone/2", "golden/1", ["terminal", "ice_lab"], 20)


## The Ice Lab joins the campaign off its difficulty curve (task Q1, like the Terminal): its three levels lie strictly
## between Terminal 2's and Golden 1's, rising, at the zone's run speed, between the Terminal's and the Golden Zone's, and
## take Dead Zone 2's place on the curve (the last level on it before them) and its completion bonus; every other level
## and boss configures exactly as in the campaign before it (the same data without the Ice Lab), so the Golden Zone and
## the weekly challenge's Sentinel Row play as they did, and the Terminal as it did (_check_joins_off_curve). DESIGN-TBD
## (docs/questions/q1.md): the numbers.
func _test_ice_lab_off_curve(campaign: Campaign) -> void:
	var ice_lab: ZoneDef = _zone(campaign, "ice_lab")
	var terminal: ZoneDef = _zone(campaign, "terminal")
	var golden: ZoneDef = _zone(campaign, "golden")
	check(ice_lab != null and terminal != null and golden != null and ice_lab.run_speed > terminal.run_speed
		and ice_lab.run_speed < golden.run_speed, "the Ice Lab runs between the Terminal's speed and the Golden Zone's")
	_check_joins_off_curve(campaign, "ice_lab", "terminal/2", "golden/1", ["ice_lab"], 22)


## Zone `id`, which the campaign plays off its difficulty curve: at 3, 5 and 6 lanes and every difficulty tier each of its
## levels plays at its own difficulty (plus the tier's bonus) and enemy scaling, each strictly between the level before it
## (`before`'s, then the zone's own levels') and `after`'s, at the zone's run speed (times the tier's); each takes the
## place on the curve of the last level on it before the zone, and that level's completion bonus. The campaign before the
## zone came (the same data without the zones `newer`: it and any that came after it) has `levels` levels, and every step
## of it but the cinematics, levels and bosses alike, configures exactly as it does now: the same place on the curve,
## difficulty, enemy scaling, run speed, feature ages, skin, sky and recency curve, and the same completion bonus.
func _check_joins_off_curve(campaign: Campaign, id: String, before_id: String, after_id: String, newer: Array,
		levels: int) -> void:
	var zone: ZoneDef = _zone(campaign, id)
	var before: CampaignStep = campaign.step(before_id)
	var after: CampaignStep = campaign.step(after_id)
	check(zone != null and before != null and after != null, "%s, %s and %s are in the campaign" % [id, before_id, after_id])
	if zone == null or before == null or after == null:
		return
	# The last level on the curve before the zone: the place its levels take.
	var place: CampaignStep = null
	for s: CampaignStep in campaign.steps():
		if s.zone == zone:
			break
		if s.is_level() and not s.level.off_curve:
			place = s
	var last_difficulty: float = campaign.configure(before, 5).difficulty
	var last_scaling: float = campaign.configure(before, 5).enemy_scaling
	var tag_before: String = before.title()
	for number: int in range(1, zone.levels.size() + 1):
		var s: CampaignStep = campaign.step("%s/%d" % [id, number])
		for tier: int in campaign.tier_count():
			for lanes: int in [3, 5, 6]:
				var tag: String = "%s lanes=%d tier=%d" % [s.id, lanes, tier]
				var config: LevelConfig = campaign.configure(s, lanes, tier)
				check(config.lane_count == lanes and config.off_curve
					and is_equal_approx(config.difficulty, clampf(s.level.difficulty + campaign.tier_difficulty_bonus[tier], 0.0, 1.0))
					and is_equal_approx(config.enemy_scaling, s.level.enemy_scaling),
					"%s plays at its own difficulty plus the tier's bonus (%.3f) and its own enemy scaling (%.3f)" % [tag,
						config.difficulty, config.enemy_scaling])
				check(is_equal_approx(config.run_speed, zone.run_speed * campaign.speed_multiplier(tier)),
					"%s runs at %s's speed times the tier's (%.2f)" % [tag, zone.display_name, config.run_speed])
		var plain: LevelConfig = campaign.configure(s, 5)
		check(plain.difficulty > last_difficulty and plain.difficulty < campaign.configure(after, 5).difficulty
			and plain.enemy_scaling > last_scaling and plain.enemy_scaling < campaign.configure(after, 5).enemy_scaling,
			"%s lies strictly between %s and %s, rising (difficulty %.3f, enemy scaling %.3f)" % [s.id, tag_before, after.title(),
				plain.difficulty, plain.enemy_scaling])
		last_difficulty = plain.difficulty
		last_scaling = plain.enemy_scaling
		tag_before = s.title()
		check(place != null and s.level_index == place.level_index
			and App.rules.completion_bonus(s.level_index) == App.rules.completion_bonus(place.level_index),
			"%s takes %s's place on the curve, the last level on it before %s, and its completion bonus (DESIGN-TBD)" % [s.id,
				place.id if place != null else "?", zone.display_name])
	var without := campaign.duplicate() as Campaign
	var zones: Array[ZoneDef] = []
	var fewer: int = 0
	for z: ZoneDef in campaign.zones:
		if newer.has(String(z.id)):
			for s: CampaignStep in campaign.steps():
				fewer += 1 if s.zone == z else 0
		else:
			zones.append(z)
	without.zones = zones
	check(without.steps().size() == campaign.steps().size() - fewer and without.level_count() == levels
		and without.curve_level_count() == 17, "the campaign before %s has %d steps less and %d levels (%d)" % [zone.display_name,
			fewer, levels, without.level_count()])
	var same: int = 0
	var compared: int = 0
	var bosses: int = 0
	for old: CampaignStep in without.steps():
		if old.kind == CampaignStep.Kind.CINEMATIC:
			continue
		bosses += 1 if old.kind == CampaignStep.Kind.BOSS else 0
		var now: CampaignStep = campaign.step(old.id)
		var ok: bool = now != null and now.kind == old.kind and now.level_index == old.level_index
		for tier: int in campaign.tier_count():
			for lanes: int in [3, 5, 6]:
				if not ok:
					break
				var a: LevelConfig = without.configure(old, lanes, tier) if old.is_level() else without.configure_boss(old, lanes, tier)
				var b: LevelConfig = campaign.configure(now, lanes, tier) if now.is_level() else campaign.configure_boss(now, lanes, tier)
				ok = ok and a.difficulty == b.difficulty and a.enemy_scaling == b.enemy_scaling and a.run_speed == b.run_speed \
					and a.lane_count == b.lane_count and a.skin == b.skin and a.sky == b.sky and a.feature_recency == b.feature_recency \
					and var_to_str(a.feature_ages) == var_to_str(b.feature_ages)
		if ok and old.is_level():
			ok = App.rules.completion_bonus(old.level_index) == App.rules.completion_bonus(now.level_index)
		compared += 1
		same += 1 if ok else 0
		if not ok:
			check(false, "%s configures exactly as before %s, at 3, 5 and 6 lanes and every tier" % [old.id, zone.display_name])
	check(same == compared and compared == levels + 7 and bosses == 7,
		"every level and boss before and after %s is unchanged (%d of %d)" % [zone.display_name, same, compared])


## Levels take their zone's skin, the grey box until a zone has its own; a level's own skin wins, and
## is then a variant of its zone's skin: either the same script with different values (Corporate 2's
## plaza) or a subclass of it reusing its materials (the Golden Palace, Golden 3, task D6b).
func _test_skins(campaign: Campaign) -> void:
	# Skins are named by path and loaded on first use (ZoneDef.skin_path): the campaign loads every zone at start,
	# and a skin held as a resource would load, and compile its scripts, for every zone a player never reaches.
	var held := PackedStringArray()
	for dir: String in ["res://data/zones", "res://data/levels", "res://data/bosses"]:
		for file: String in DirAccess.get_files_at(dir):
			if file.ends_with(".tres") and FileAccess.get_file_as_string(dir.path_join(file)).contains("\nskin = ExtResource("):
				held.append(file)
	check(held.is_empty(), "no zone, level or boss data holds its skin itself, only its skin_path (held: %s)" % ", ".join(held))
	var lazy := ZoneDef.new()
	lazy.skin_path = "res://data/skins/greybox_skin.tres"
	check(lazy.skin is GreyboxSkin and lazy.skin == load(lazy.skin_path), "a zone's skin loads from its skin_path when first read")
	var assigned := GreyboxSkin.new()
	lazy.skin = assigned
	check(lazy.skin == assigned and lazy.skin_path == "", "and a skin set in code wins over the path")
	lazy.skin = null
	check(lazy.skin == null, "and setting it to null leaves the zone without one, as before skins were named by path")
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
	var beach: ZoneDef = _zone(campaign, "beach")
	check(beach != null and beach.skin is BeachSkin, "beach uses its own skin")
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
		# The volleyball match plans its own track (test_volleyball).
		if not s.is_level() or s.is_minigame():
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
	if s.zone.id == &"terminal":
		# GDD §5, Zone 8: "a couple of holes, not many", and no fences: its holes are its wider gaps' rows
		# (test_terminal_levels checks the rest of its rules).
		check(layout.fences.is_empty() and GapDensity.rows(layout).size() <= config.wide_gaps
			and GapDensity.rows(layout).size() >= 1, "a couple of holes and no fences (%d rows) %s"
			% [GapDensity.rows(layout).size(), tag])
	else:
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
		# A feature sprinkled in (the ceiling scenarios, task I4) may miss a build: test_ceiling_scenarios counts them.
		check(not at.is_empty() or LayoutChecks.occasional(f),
			"%s has `%s` (GDD §5: earlier features keep appearing) %s" % [s.id, f, tag])
		if not config.feature_starts.has(f) or at.is_empty():
			continue
		var start: float = gen.feature_start(f)
		check(at[0] >= start - 0.01, "nothing of `%s` before its start (%.0f m) %s" % [f, start, tag])
		# A ceiling scenario's introduction (task I4) is the first of the level's own ceilings that fits one from its
		# start, not a pattern picked there: test_ceiling_scenarios checks it's the first.
		if SPACED_FROM_START.has(f) or LayoutChecks.occasional(f):
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
		if not s.is_level() or s.is_minigame():
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
		# The volleyball match has no features to date.
		if not s.is_level() or s.is_minigame():
			continue
		var config: LevelConfig = campaign.configure(s, 5)
		check(config.feature_recency == curve and config.recency_on(), "%s's copy has the campaign's curve" % s.id)
		check(s.level.feature_ages.is_empty() and s.level.feature_recency == null, "%s's own file has neither" % s.id)
		for f: String in s.level.features:
			var first: CampaignStep = campaign.step(String(FIRST_LEVEL.get(f, "")))
			# A level on the curve counts the levels on it (their places); one off it (the Beach's, task D10c)
			# every level before it, in the order they're played.
			var age: int = -1
			if first != null:
				age = _level_number(campaign, s) - _level_number(campaign, first) if s.level.off_curve \
					else s.level_index - first.level_index
			check(int(config.feature_ages.get(f, -99)) == age, "%s: `%s` was introduced %d levels ago (%d)" % [s.id, f, age,
				config.feature_ages.get(f, -99)])
	check(int(campaign.configure(campaign.step("golden/1"), 3).feature_ages["buzz_overdrive"]) == 4
		and int(campaign.configure(campaign.step("dead_zone/2"), 3).feature_ages["host"]) == 1,
		"e.g. Golden 1's Buzz Overdrive is 4 levels old, The Hush's hosts 1")
	check(int(campaign.configure(campaign.step("beach/1"), 3).feature_ages["tithe_collector"]) == 1
		and int(campaign.configure(campaign.step("beach/3"), 3).feature_ages["tithe_collector"]) == 2
		and int(campaign.configure(campaign.step("dead_zone/1"), 3).feature_ages["buzz_overdrive"]) == 2,
		"the Beach's Tithe Collectors are 1 and 2 levels old, and the levels after it keep their ages (Dead Zone 1's Buzz Overdrive 2)")

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
		if not s.is_level() or s.is_minigame():
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
					config.extended_wall_runs = []
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
				if WALL_RUN_GAP_CROWDED.has(tag):
					check(gen.warnings == PackedStringArray([WALL_RUN_GAP_WARNING]) and layout.wall_run_gaps.is_empty(),
						"%s still has no room for a wall-run gap, and warns of nothing else (else take it out of WALL_RUN_GAP_CROWDED): %s"
						% [tag, gen.warnings])
				else:
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
		"res://scripts/world/meshes/shaders/shopfront.gdshader", "res://scripts/world/meshes/shaders/casino_facade.gdshader",
		"res://scripts/world/meshes/shaders/road.gdshader",
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


## Unlocking follows the campaign order (with a fresh profile); the web demo covers Zone 1 only. The Beach
## (task D10c) opens after Corporate's outro, its placeholder boss slot passes on to its outro, and its outro
## opens the Dead Zone; a save from before the Beach keeps the Dead Zone it had open, and Continue offers it
## the Beach (DESIGN-TBD, docs/OPEN_QUESTIONS.md, item 574).
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

	# The Beach, between Corporate and the Dead Zone.
	var campaign: Campaign = App.campaign
	check(campaign.next_step(campaign.step("corporate/outro")) == campaign.step("beach/intro")
		and campaign.next_step(campaign.step("beach/outro")) == campaign.step("dead_zone/intro"),
		"the Beach comes after Corporate's outro, and the Dead Zone after the Beach's")
	App.profile = Profile.new()
	SampleProfiles.complete_until(App.profile, campaign, "beach/intro")
	check(App.step_unlocked(campaign.step("beach/intro")) and App.next_unfinished_step() == campaign.step("beach/intro")
		and not App.step_unlocked(campaign.step("beach/1")) and not App.step_unlocked(campaign.step("dead_zone/intro")),
		"Corporate's outro opens the Beach, and not the Dead Zone")
	SampleProfiles.complete_until(App.profile, campaign, "beach/boss")
	var boss: CampaignStep = campaign.step("beach/boss")
	check(App.step_unlocked(boss) and not App.step_unlocked(campaign.step("beach/outro")), "Sunset Strip opens the Beach's boss slot")
	App.complete_step(boss)
	check(App.step_unlocked(campaign.step("beach/outro")) and App.profile.stars(boss.id) == 0,
		"the boss step done opens the outro (complete_step gives a boss no stars: its fight records them through its results)")
	App.complete_step(campaign.step("beach/outro"))
	check(App.step_unlocked(campaign.step("dead_zone/intro")) and App.next_unfinished_step() == campaign.step("dead_zone/intro"),
		"the Beach's outro opens the Dead Zone")
	# A save from before the Beach, partway through the Dead Zone.
	App.profile = Profile.new()
	for s: CampaignStep in steps:
		if s.index > campaign.step("dead_zone/1").index:
			break
		if s.zone.id != &"beach":
			App.profile.record_run(s.id, 0, true, 5000 if s.is_level() else 0, 2 if s.is_level() else 3, 100.0)
	check(App.step_unlocked(campaign.step("dead_zone/1")) and App.step_unlocked(campaign.step("dead_zone/2")),
		"a save from before the Beach keeps the Dead Zone it had open")
	check(App.step_unlocked(campaign.step("beach/intro")) and App.next_unfinished_step() == campaign.step("beach/intro")
		and not App.step_unlocked(campaign.step("beach/1")), "and Continue offers it the Beach, from its intro")
	# The Terminal (task O1), between the Dead Zone and the Ice Lab (task Q1; the Golden Zone before it), with no boss: its
	# last level opens its outro, and its outro the Ice Lab.
	check(campaign.next_step(campaign.step("dead_zone/outro")) == campaign.step("terminal/intro")
		and campaign.next_step(campaign.step("terminal/2")) == campaign.step("terminal/outro")
		and campaign.next_step(campaign.step("terminal/outro")) == campaign.step("ice_lab/intro"),
		"the Terminal comes after the Dead Zone's outro, its outro straight after its last level, and the Ice Lab after it")
	App.profile = Profile.new()
	SampleProfiles.complete_until(App.profile, campaign, "terminal/intro")
	check(App.step_unlocked(campaign.step("terminal/intro")) and App.next_unfinished_step() == campaign.step("terminal/intro")
		and not App.step_unlocked(campaign.step("terminal/1")) and not App.step_unlocked(campaign.step("golden/intro")),
		"the Dead Zone's outro opens the Terminal, and not the Golden Zone")
	SampleProfiles.complete_until(App.profile, campaign, "terminal/outro")
	check(App.step_unlocked(campaign.step("terminal/outro")) and not App.step_unlocked(campaign.step("golden/intro")),
		"Last Stop opens the Terminal's outro")
	App.complete_step(campaign.step("terminal/outro"))
	check(App.step_unlocked(campaign.step("ice_lab/intro")) and App.next_unfinished_step() == campaign.step("ice_lab/intro")
		and not App.step_unlocked(campaign.step("ice_lab/1")) and not App.step_unlocked(campaign.step("golden/intro")),
		"the Terminal's outro opens the Ice Lab, and not the Golden Zone")
	# The Ice Lab (task Q1), between the Terminal and the Golden Zone, with no boss: its levels one after another, its last
	# level opens its outro, and its outro the Golden Zone.
	check(campaign.next_step(campaign.step("ice_lab/3")) == campaign.step("ice_lab/outro")
		and campaign.next_step(campaign.step("ice_lab/outro")) == campaign.step("golden/intro"),
		"the Ice Lab's outro comes straight after its last level, and the Golden Zone after it")
	App.complete_step(campaign.step("ice_lab/intro"))
	check(App.step_unlocked(campaign.step("ice_lab/1")) and not App.step_unlocked(campaign.step("ice_lab/2"))
		and App.next_unfinished_step() == campaign.step("ice_lab/1"), "the Ice Lab's intro opens Frost Foundry, and only it")
	SampleProfiles.complete_until(App.profile, campaign, "ice_lab/3")
	check(App.step_unlocked(campaign.step("ice_lab/3")) and not App.step_unlocked(campaign.step("ice_lab/outro")),
		"Relay Station opens Specimen Vault")
	SampleProfiles.complete_until(App.profile, campaign, "ice_lab/outro")
	check(App.step_unlocked(campaign.step("ice_lab/outro")) and not App.step_unlocked(campaign.step("golden/intro")),
		"Specimen Vault opens the Ice Lab's outro")
	App.complete_step(campaign.step("ice_lab/outro"))
	check(App.step_unlocked(campaign.step("golden/intro")) and App.next_unfinished_step() == campaign.step("golden/intro"),
		"the Ice Lab's outro opens the Golden Zone")
	App.profile = saved
	_test_old_saves()
	_test_saves_before_terminal()
	_test_saves_before_ice_lab()


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
	check(Profile.VERSION == 6 and int(p.to_dict()["version"]) == 6, "saves are version 6")
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
		"a version 6 save loads as it is")
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


## A version 4 save (from before the Terminal, task O1) that finished every step of the campaign up to `last` but the
## Terminal's and the Ice Lab's (which came after it, task Q1), on the normal tier (and Dead Zone's outro on the Hard tier
## too, `hard_outro`), as a parsed save file has it.
func _v4_save(last: String, hard_outro: bool = false) -> Dictionary:
	var records: Dictionary = {}
	for s: CampaignStep in App.campaign.steps():
		if s.zone.id == &"terminal" or s.zone.id == &"ice_lab":
			continue
		var stars: int = 2 if s.is_level() or s.kind == CampaignStep.Kind.BOSS else 3
		records["0/" + s.id] = {"completed": true, "best_score": 1000.0, "stars": float(stars), "best_time": 90.0,
			"attempts": 1.0}
		if s.id == last:
			break
	if hard_outro:
		records["1/dead_zone/outro"] = {"completed": true, "best_score": 0.0, "stars": 3.0, "best_time": 0.0, "attempts": 1.0}
	return {"version": 4, "earned": 100.0, "records": records}


## Saves from before the Terminal (save version 5, Profile._migrate; task O1): the Golden Zone's step ids are as they
## were, so its records stay; the Dead Zone's old outro, which led to the Golden Zone, also counts as the Terminal's
## outro (on every tier it was finished), and that, since the Ice Lab came in after it (save version 6, task Q1), as the
## Ice Lab's outro too, so a player who had reached the Golden Zone keeps it open; the Terminal is open from the Dead
## Zone's outro and Continue leads into it. One who hadn't seen the Dead Zone's outro goes on through it, the Golden Zone
## shut as before.
func _test_saves_before_terminal() -> void:
	var saved: Profile = App.profile
	var campaign: Campaign = App.campaign
	var p: Profile = Profile.from_dict(JSON.parse_string(JSON.stringify(_v4_save("dead_zone/outro", true))))
	App.profile = p
	check(int(p.to_dict()["version"]) == 6 and p.is_completed("dead_zone/outro") and p.is_completed("terminal/outro")
		and p.is_completed("terminal/outro", 1) and not p.is_completed("terminal/1") and not p.is_completed("terminal/intro"),
		"a version 4 save that finished the Dead Zone's outro counts the Terminal's outro done too, on every tier it did")
	check(p.is_completed("ice_lab/outro") and p.is_completed("ice_lab/outro", 1) and not p.is_completed("ice_lab/intro")
		and not p.is_completed("ice_lab/1"), "and so the Ice Lab's outro too, which leads to the Golden Zone now, on every tier")
	# (The Ice Lab's intro is open too, after the Terminal's outro it counts as done, as the Golden Zone's is: such a save
	# may play either new zone from the level select. DESIGN-TBD, docs/questions/q1.md.)
	check(App.step_unlocked(campaign.step("golden/intro")) and App.step_unlocked(campaign.step("terminal/intro"))
		and not App.step_unlocked(campaign.step("terminal/1")) and not App.step_unlocked(campaign.step("golden/1"))
		and App.step_unlocked(campaign.step("ice_lab/intro")) and not App.step_unlocked(campaign.step("ice_lab/1"))
		and App.next_unfinished_step() == campaign.step("terminal/intro"),
		"it keeps the Golden Zone's intro open, and Continue leads into the Terminal")
	# Deep into the Golden Zone: every step it had reached stays open.
	App.profile = Profile.from_dict(JSON.parse_string(JSON.stringify(_v4_save("golden/2"))))
	var reached: bool = true
	for s: CampaignStep in campaign.steps():
		if s.zone.id != &"terminal" and s.zone.id != &"ice_lab" and s.index <= campaign.step("golden/2").index:
			reached = reached and App.step_unlocked(s) and App.profile.is_completed(s.id)
	check(reached and App.step_unlocked(campaign.step("golden/3")) and not App.step_unlocked(campaign.step("golden/boss"))
		and App.next_unfinished_step() == campaign.step("terminal/intro"),
		"a save partway through the Golden Zone keeps every step it reached, and the next; Continue offers the Terminal")
	# One that beat the Sleep Taker but hadn't seen the Dead Zone's outro: it goes on through it, the Golden Zone shut.
	App.profile = Profile.from_dict(JSON.parse_string(JSON.stringify(_v4_save("dead_zone/boss"))))
	check(not App.profile.is_completed("terminal/outro") and not App.profile.is_completed("ice_lab/outro")
		and App.step_unlocked(campaign.step("dead_zone/outro")) and not App.step_unlocked(campaign.step("terminal/intro"))
		and not App.step_unlocked(campaign.step("golden/intro")) and App.next_unfinished_step() == campaign.step("dead_zone/outro"),
		"a save that beat the Dead Zone's boss goes on through its outro into the Terminal; the Golden Zone stays shut")
	App.profile = saved


## A version 5 save (from before the Ice Lab, task Q1) that finished every step of the campaign up to `last` but the Ice
## Lab's, on the normal tier (and the Terminal's outro on the Hard tier too, `hard_outro`), as a parsed save file has it.
func _v5_save(last: String, hard_outro: bool = false) -> Dictionary:
	var records: Dictionary = {}
	for s: CampaignStep in App.campaign.steps():
		if s.zone.id == &"ice_lab":
			continue
		var stars: int = 2 if s.is_level() or s.kind == CampaignStep.Kind.BOSS else 3
		records["0/" + s.id] = {"completed": true, "best_score": 1000.0, "stars": float(stars), "best_time": 90.0,
			"attempts": 1.0}
		if s.id == last:
			break
	if hard_outro:
		records["1/terminal/outro"] = {"completed": true, "best_score": 0.0, "stars": 3.0, "best_time": 0.0, "attempts": 1.0}
	return {"version": 5, "earned": 100.0, "records": records}


## Saves from before the Ice Lab (save version 6, Profile._migrate; task Q1): the Golden Zone's step ids are as they were,
## so its records stay; the Terminal's old outro, which led to the Golden Zone, also counts as the Ice Lab's outro (on
## every tier it was finished), so a player who had reached the Golden Zone keeps it open and keeps their place; the Ice
## Lab is open from the Terminal's outro and Continue leads into it. One who hadn't seen the Terminal's outro goes on
## through it, the Ice Lab next and the Golden Zone shut as before. A save of this version loads as it is.
func _test_saves_before_ice_lab() -> void:
	var saved: Profile = App.profile
	var campaign: Campaign = App.campaign
	var p: Profile = Profile.from_dict(JSON.parse_string(JSON.stringify(_v5_save("terminal/outro", true))))
	App.profile = p
	check(int(p.to_dict()["version"]) == 6 and p.is_completed("terminal/outro") and p.is_completed("ice_lab/outro")
		and p.is_completed("ice_lab/outro", 1) and not p.is_completed("ice_lab/intro") and not p.is_completed("ice_lab/1")
		and p.stars("ice_lab/outro") == p.stars("terminal/outro"),
		"a version 5 save that finished the Terminal's outro counts the Ice Lab's outro done too, on every tier it did")
	check(App.step_unlocked(campaign.step("golden/intro")) and App.step_unlocked(campaign.step("ice_lab/intro"))
		and not App.step_unlocked(campaign.step("ice_lab/1")) and not App.step_unlocked(campaign.step("golden/1"))
		and App.next_unfinished_step() == campaign.step("ice_lab/intro"),
		"it keeps the Golden Zone's intro open, and Continue leads into the Ice Lab")
	# Deep into the Golden Zone: every step it had reached stays open, the Terminal's too.
	App.profile = Profile.from_dict(JSON.parse_string(JSON.stringify(_v5_save("golden/2"))))
	var reached: bool = true
	for s: CampaignStep in campaign.steps():
		if s.zone.id != &"ice_lab" and s.index <= campaign.step("golden/2").index:
			reached = reached and App.step_unlocked(s) and App.profile.is_completed(s.id)
	check(reached and App.step_unlocked(campaign.step("golden/3")) and not App.step_unlocked(campaign.step("golden/boss"))
		and App.next_unfinished_step() == campaign.step("ice_lab/intro"),
		"a save partway through the Golden Zone keeps every step it reached, and the next; Continue offers the Ice Lab")
	# One that finished Last Stop but hadn't seen the Terminal's outro: it goes on through it into the Ice Lab, the Golden
	# Zone shut.
	App.profile = Profile.from_dict(JSON.parse_string(JSON.stringify(_v5_save("terminal/2"))))
	check(not App.profile.is_completed("ice_lab/outro") and App.step_unlocked(campaign.step("terminal/outro"))
		and not App.step_unlocked(campaign.step("ice_lab/intro")) and not App.step_unlocked(campaign.step("golden/intro"))
		and App.next_unfinished_step() == campaign.step("terminal/outro"),
		"a save that finished Last Stop goes on through the Terminal's outro into the Ice Lab; the Golden Zone stays shut")
	# A version 6 save loads as it is: an Ice Lab outro it hasn't finished stays unfinished, whatever the Terminal's.
	var current: Dictionary = _v5_save("terminal/outro")
	current["version"] = 6
	var again: Profile = Profile.from_dict(JSON.parse_string(JSON.stringify(current)))
	check(not again.is_completed("ice_lab/outro") and again.records.size() == (current["records"] as Dictionary).size(),
		"a version 6 save loads as it is: nothing is migrated again")
	App.profile = saved


## Level step `s`'s number in the order the campaign plays its levels (0 for the first), mini-game levels (the
## Beach's volleyball match) left out, as Campaign.feature_ages leaves them out.
func _level_number(campaign: Campaign, s: CampaignStep) -> int:
	var n: int = 0
	for other: CampaignStep in campaign.steps():
		if other == s:
			return n
		if other.is_level() and not other.is_minigame():
			n += 1
	return -1


func _zone(campaign: Campaign, id: String) -> ZoneDef:
	for zone: ZoneDef in campaign.zones:
		if String(zone.id) == id:
			return zone
	return null
