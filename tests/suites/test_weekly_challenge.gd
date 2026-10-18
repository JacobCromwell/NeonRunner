extends TestSuite
## The weekly challenge (GDD §6, Replay features, "Weekly challenge"; the owner, October 18, 2026; task N5):
## - the shipped seed list: every entry builds a level that passes the fairness checks the campaign's levels get
##   (LayoutChecks, the guarantee that every feature appears, no generator warning), at five lanes, in its zone's
##   look with that zone's own features at Sentinel Row's difficulty, enemy scaling, density and run speed;
## - the calendar (the week from the date, the entry from the week, the board per platform) and the zones' rotation;
## - the uniform kit (Armor IV and Juggernaut dash IV, nothing else, whatever the player owns);
## - the payout (the first clear of a week only; collected credits, deaths and quits pay nothing), the boards
##   (PC and mobile apart), the locked-until-the-Floating-Head rule and the web demo's exclusion;
## - the clock: nothing paid or posted for a week before the schedule's first, or below the highest played (the
##   reviewer's sequence of clears at weeks 5, 4, 3, -1, -27 and 37: only 5 and 37 pay);
## - the reward hook (a pending record, settled once the week is over, once however many passes) and the save;
## - the LevelConfig split: every field of a week's config is the zone's, the week's or Sentinel Row's, none unclassified.

const CAMPAIGN_PATH: String = "res://data/campaign/campaign.tres"
## The weekly level's length in seconds: Sentinel Row's.
const SECONDS: float = 150.0
## One day in seconds.
const DAY: int = 86400

var campaign: Campaign
var def: WeeklyChallenge
var main: Node


## A stub whose rank takes a moment to come, as a real platform's does, and counts how often it was asked.
class SlowRank:
	extends StubBackend

	var asked: int = 0

	func leaderboard_rank(board: String) -> int:
		asked += 1
		await tree.create_timer(0.1, true).timeout
		return super(board)


func run() -> void:
	campaign = load(CAMPAIGN_PATH) as Campaign
	def = WeeklyChallenge.load_default()
	check(def != null, "the weekly challenge's data loads")
	if def == null:
		return
	_test_data()
	_test_fields()
	_test_calendar()
	_test_rotation()
	_test_kit()
	_test_profile()
	_test_rewards_hook()
	_test_levels()
	await _test_settlement()
	await _test_flow()
	await _test_demo()


# --- The data --------------------------------------------------------------------------------

func _test_data() -> void:
	check(def.lanes == 5, "five lanes on every platform (GDD §6)")
	# The weekly level keeps five lanes even if a platform's campaign lane count changes later (GDD §6).
	var pc_lanes: int = App.rules.lanes_pc
	var mobile_lanes: int = App.rules.lanes_mobile
	App.rules.lanes_pc = 3
	App.rules.lanes_mobile = 6
	var week0: WeeklyWeek = def.week(0)
	var built: LevelConfig = def.build_config(campaign, week0)
	check(built != null and built.lane_count == 5, "the weekly level has five lanes whatever the platforms' lane counts are")
	App.rules.lanes_pc = pc_lanes
	App.rules.lanes_mobile = mobile_lanes
	check(def.week_seconds == 7 * DAY, "a week is seven days")
	# The placeholder boundary: Monday 00:00 UTC. The Unix epoch was a Thursday, so a Monday is 4 days into a week.
	check((def.epoch_unix - 4 * DAY) % def.week_seconds == 0, "weeks open on Monday 00:00 UTC (DESIGN-TBD)")
	check(def.top_places == 3, "the top three earn the Leader of the Pack (the owner's number for now)")
	check(def.reward_kind == &"leader_of_the_pack", "the reward is named Leader of the Pack")
	check(def.first_clear_credits > 0, "the first clear pays")
	check(def.unlock_step == "city/boss", "it opens with the Neon City's boss (the Floating Head)")
	var density: CampaignStep = campaign.step(def.density_step)
	check(density != null and density.is_level() and density.zone.id == &"golden", "its difficulty is a Golden Zone level's (%s)" % def.density_step)
	check(density.level.display_name == "Sentinel Row", "the Golden Zone's hardest level, Sentinel Row (GDD §6, proposed)")
	for zone: ZoneDef in campaign.zones:
		var step: CampaignStep = campaign.step(String(def.source_levels.get(String(zone.id), "")))
		check(step != null and step.is_level() and not step.is_minigame() and step.zone == zone,
			"zone %s has an ordinary level of its own to take its enemies from (%s)" % [zone.id, def.source_levels.get(String(zone.id))])
		if step != null:
			check(step.level.quiet_seconds <= 0.0, "%s's source level is not paced in bursts (not The Hush)" % zone.id)
	check(def.entries().size() > 0, "the seed list loads")
	check(not def.kit.is_empty(), "the kit lists items")
	# The tunables a balancer changes are exported with ranges (the live panel only shows those).
	for prop: String in ["first_clear_credits", "top_places", "lanes", "week_seconds", "reward_check_weeks"]:
		var hint: bool = false
		for p: Dictionary in def.get_property_list():
			if p["name"] == prop and int(p["hint"]) == PROPERTY_HINT_RANGE:
				hint = true
		check(hint, "%s has a range hint" % prop)


# --- The calendar ----------------------------------------------------------------------------

func _test_calendar() -> void:
	var epoch: int = def.epoch_unix
	check(def.week_index(epoch) == 0, "the schedule's first week opens at its epoch")
	check(def.week_index(epoch - 1) == -1, "a second before it is the week before")
	check(def.week_index(epoch + 7 * DAY - 1) == 0, "the week lasts until its seventh day is out")
	check(def.week_index(epoch + 7 * DAY) == 1, "and the next one opens on the dot")
	check(def.week_index(epoch + 100 * DAY) == 14, "week 14 is 98 to 104 days in")
	check(def.week_index(epoch - 8 * DAY) == -2, "weeks count back before the epoch too")
	var entries: Array[Dictionary] = def.entries()
	var n: int = entries.size()
	for index: int in [0, 1, 5, n - 1, n, n + 3, 3 * n + 2, -1, -n, -n - 1]:
		var w: WeeklyWeek = def.week(index)
		check(w != null and w.index == index, "week %d is made" % index)
		if w == null:
			continue
		check(w.entry_index == posmod(index, n), "week %d plays entry %d of the list (the index wraps around it)" % [index, posmod(index, n)])
		check(String(w.zone_id) == String(entries[w.entry_index]["zone"]) and w.level_seed == int(entries[w.entry_index]["seed"]),
			"week %d takes its zone and seed from its entry" % index)
		check(w.ends_at - w.starts_at == def.week_seconds, "week %d is a week long" % index)
		check(def.week_index(w.starts_at) == index and def.week_index(w.ends_at - 1) == index and def.week_index(w.ends_at) == index + 1,
			"week %d opens and closes where the calendar says" % index)
		check(w.starts_at % def.week_seconds == (epoch % def.week_seconds), "week %d opens on the same weekday and time as week 0" % index)
	check(def.week(n).level_seed == def.week(0).level_seed and def.week(n).zone_id == def.week(0).zone_id,
		"after the whole list, the first entry comes round again")
	var w0: WeeklyWeek = def.week(0)
	check(w0.number() == 1, "the first week is Week 1 to the player")
	check(w0.seconds_left(w0.starts_at) == def.week_seconds and w0.seconds_left(w0.ends_at + 5) == 0, "the time left runs down to zero")
	check(w0.is_over(w0.ends_at) and not w0.is_over(w0.ends_at - 1), "a week is over when the next opens")
	# One board a week, one for each platform's players (GDD §6).
	check(def.board_id(3, false) == "weekly/pc/3" and def.board_id(3, true) == "weekly/mobile/3", "PC and mobile have their own board for a week")
	check(def.board_id(3, false) != def.board_id(4, false), "and a new board every week")
	check(WeeklyChallenge.format_date(epoch) == "Mon 19 Oct 2026, 00:00 UTC", "the first week opens on a Monday: %s" % WeeklyChallenge.format_date(epoch))
	check(WeeklyChallenge.format_left(3 * DAY + 4 * 3600 + 59) == "3d 4h" and WeeklyChallenge.format_left(5 * 3600 + 12 * 60) == "5h 12m"
		and WeeklyChallenge.format_left(12 * 60 + 5) == "12m" and WeeklyChallenge.format_left(20) == "under a minute"
		and WeeklyChallenge.format_left(-4) == "under a minute", "the time left reads as days and hours, hours and minutes, minutes")


# --- The rotation ----------------------------------------------------------------------------

## The weeks rotate through the zones (GDD §6), every zone from the start: the list is the campaign's zones in
## order, over and over, with a seed of its own each time round.
func _test_rotation() -> void:
	var zones: Array[StringName] = []
	for zone: ZoneDef in campaign.zones:
		if not zone.placeholder and not zone.levels.is_empty():
			zones.append(zone.id)
	var entries: Array[Dictionary] = def.entries()
	var n: int = entries.size()
	check(n >= zones.size() and n % zones.size() == 0, "the list goes round the %d zones a whole number of times (%d weeks)" % [zones.size(), n])
	var seen: Dictionary = {}
	for i: int in n:
		var zone: String = String(entries[i]["zone"])
		check(zone == String(zones[i % zones.size()]), "week %d is %s: the zones go round in the campaign's order" % [i, zones[i % zones.size()]])
		var level_seed: int = int(entries[i]["seed"])
		check(not seen.has(level_seed), "seed %d is in the list once" % level_seed)
		seen[level_seed] = true
		for s: CampaignStep in campaign.steps():
			if s.is_level() and not s.is_minigame():
				check(s.level.level_seed != level_seed, "seed %d is not %s's own, so the week is a level of its own" % [level_seed, s.id])
	# Every zone is in the rotation from the start, even before the player has got there in the campaign.
	for z: StringName in zones:
		var count: int = 0
		for e: Dictionary in entries:
			count += 1 if String(e["zone"]) == String(z) else 0
		check(count >= 1, "zone %s is in the rotation" % z)
		check(count == n / zones.size(), "and as often as the others (%d)" % count)
	# Any run of consecutive weeks, as long as the zones are many, meets every zone once.
	for start: int in n:
		var window: Dictionary = {}
		for k: int in zones.size():
			window[String(entries[(start + k) % n]["zone"])] = true
		check(window.size() == zones.size(), "weeks %d to %d meet every zone once" % [start, start + zones.size() - 1])


# --- The kit ---------------------------------------------------------------------------------

func _test_kit() -> void:
	var catalog: ShopCatalog = App.catalog
	for mobile: bool in [false, true]:
		var kit: Loadout = Loadout.weekly(catalog, def.kit, mobile)
		var tag: String = "mobile" if mobile else "PC"
		check(kit.armor and kit.tier(&"armor") == 4, "the kit has Armor IV over the free armor (%s)" % tag)
		check(kit.tier(&"dash") == 4, "and Juggernaut dash IV (%s)" % tag)
		check(kit.tiers.size() == 2, "and no other permanent item (%s): %s" % [tag, kit.describe()])
		check(kit.charges.is_empty(), "and no shield, grapple or revive (%s)" % tag)
		for id: StringName in [&"weapon", &"claws", &"magnet", &"slow_time"]:
			check(kit.tier(id) == 0 and not kit.has(id), "no %s (%s)" % [id, tag])
		var dash: ShopItem = catalog.item(&"dash")
		check(String(dash.tiers[3]["name"]) == "Juggernaut dash IV", "tier 4 of the dash is Juggernaut dash IV")
		check(String(catalog.item(&"armor").tiers[3]["name"]) == "Armor IV", "tier 4 of the armor is Armor IV")
	# A player's own things change nothing: not what they own, nor what they switched off.
	var rich: Profile = SampleProfiles.rich()
	rich.set_tier(&"weapon", 4)
	rich.set_tier(&"dash", 4)
	rich.set_tier(&"armor", 4)
	rich.set_equipped(&"armor", false)
	rich.set_equipped(&"dash", false)
	var saved: Profile = App.profile
	for p: Profile in [Profile.new(), rich]:
		App.profile = p
		var kit: Loadout = App.make_weekly_loadout()
		check(kit.tier(&"armor") == 4 and kit.tier(&"dash") == 4 and kit.tiers.size() == 2 and kit.charges.is_empty() and kit.armor,
			"the same kit whatever the player owns or has switched off: %s" % kit.describe())
	App.profile = saved
	# A tier past the item's last is held to it, and an item the catalog doesn't sell is left out.
	var odd: Loadout = Loadout.weekly(catalog, {"armor": 9, "dash": 0, "nonsense": 2, "shield": 3}, false)
	check(odd.tier(&"armor") == 4 and odd.tier(&"dash") == 1 and odd.tiers.size() == 2 and odd.charges.is_empty(),
		"a kit is held to the catalog's tiers, and to permanent items")


# --- The save --------------------------------------------------------------------------------

func _test_profile() -> void:
	var p := Profile.new()
	check(not p.weekly_cleared(7) and p.weekly_best(7) == 0 and p.weekly_record(7).is_empty(), "a week never played has no record")
	var r: Dictionary = p.record_weekly(7, false, 900)
	check(not r["first_clear"] and not r["new_best"] and not p.weekly_cleared(7) and int(p.weekly_record(7)["attempts"]) == 1,
		"a run that didn't clear counts as an attempt only")
	r = p.record_weekly(7, true, 5000, 1000)
	check(r["first_clear"] and r["new_best"] and p.weekly_cleared(7) and p.weekly_best(7) == 5000, "the first clear is the first clear")
	check(int(p.weekly_record(7)["paid"]) == 1000, "and keeps what it paid")
	r = p.record_weekly(7, true, 4000, 0)
	check(not r["first_clear"] and not r["new_best"] and p.weekly_best(7) == 5000 and int(p.weekly_record(7)["paid"]) == 1000,
		"a worse clear after it is neither: the best and the payout stay")
	r = p.record_weekly(7, true, 6100, 0)
	check(not r["first_clear"] and r["new_best"] and p.weekly_best(7) == 6100, "a better one is a new best, not a first clear")
	check(not p.weekly_cleared(8), "another week is separate")
	# The save round trip, through JSON as the file has it (numbers come back as floats).
	p.queue_weekly_reward(7, "weekly/pc/7", 6100, "leader_of_the_pack")
	var back: Profile = Profile.from_dict(JSON.parse_string(JSON.stringify(p.to_dict())) as Dictionary)
	check(back.weekly_cleared(7) and back.weekly_best(7) == 6100 and int(back.weekly_record(7)["paid"]) == 1000
		and int(back.weekly_record(7)["attempts"]) == 4, "the weekly record survives the save")
	check(back.weekly_rewards.size() == 1 and String(back.weekly_rewards[0]["state"]) == "pending" and int(back.weekly_rewards[0]["week"]) == 7,
		"and so does a pending reward")
	# A save from before the challenge has neither.
	var old: Dictionary = p.to_dict()
	old.erase("weekly")
	old.erase("weekly_rewards")
	var loaded: Profile = Profile.from_dict(old)
	check(loaded.weekly.is_empty() and loaded.weekly_rewards.is_empty() and loaded.earned == p.earned, "an older save loads with no weekly record")
	var damaged: Dictionary = p.to_dict()
	damaged["weekly"] = 4
	damaged["weekly_rewards"] = {"a": 1}
	var fixed: Profile = Profile.from_dict(damaged)
	check(fixed.weekly.is_empty() and fixed.weekly_rewards.is_empty(), "and a damaged field loads as none")


# --- The reward hook -------------------------------------------------------------------------

func _test_rewards_hook() -> void:
	var p := Profile.new()
	p.queue_weekly_reward(2, "weekly/pc/2", 3000, "leader_of_the_pack")
	p.queue_weekly_reward(2, "weekly/pc/2", 4500, "leader_of_the_pack")
	p.queue_weekly_reward(2, "weekly/mobile/2", 100, "leader_of_the_pack")
	check(p.weekly_rewards.size() == 2, "one record a board a week: a better score updates it")
	check(int(p.weekly_rewards[0]["score"]) == 4500, "with the best score")
	check(p.pending_weekly_rewards(2).is_empty() and p.pending_weekly_rewards(3).size() == 2,
		"a week's records wait until the week is over")
	check(not p.has_weekly_reward("leader_of_the_pack"), "and nothing is earned until the platform says so")
	p.weekly_rewards[0]["state"] = "earned"
	check(p.has_weekly_reward("leader_of_the_pack") and p.pending_weekly_rewards(3).size() == 1, "an earned record counts")


## App.settle_weekly_rewards: a week's rank is asked for once the week is over, the top places earn the reward, the rest
## don't, a rank the platform can't say waits and then lapses, and nothing is granted twice.
func _test_settlement() -> void:
	var stub: StubBackend = Platform.backend as StubBackend
	var saved: Profile = App.profile
	App.profile = Profile.new()
	App.clock_override = def.epoch_unix + 2 * 7 * DAY + DAY   # a day into week 2
	var changed: Array[int] = [0]
	var on_change: Callable = func() -> void: changed[0] += 1
	App.profile_changed.connect(on_change)
	var kind: String = String(def.reward_kind)
	# Weeks 0 and 1 are over, week 2 is this one, and week -7 is long past (more than reward_check_weeks ago).
	for week: int in [-7, 0, 1, 2]:
		App.profile.queue_weekly_reward(week, def.board_id(week, false), 5000, kind)
	check(App.profile.weekly_rewards.size() == 4, "four boards are waiting")
	# The platform can't say (offline, or the stub): nothing is decided, and the oldest lapses.
	stub.report_ranks = false
	await App.settle_weekly_rewards()
	check(_state(-7) == "expired" and _state(0) == "pending" and _state(1) == "pending" and _state(2) == "pending",
		"a rank the platform can't say waits, and lapses after %d weeks" % def.reward_check_weeks)
	check(not App.profile.has_weekly_reward(kind), "and earns nothing")
	# The platform says: 4th in week 0, 3rd in week 1.
	stub.report_ranks = true
	stub.scores[def.board_id(0, false)] = 5000
	stub.scores[def.board_id(1, false)] = 5000
	stub.scores[def.board_id(2, false)] = 5000
	stub.board_entries[def.board_id(0, false)] = [9000, 8000, 7000]
	stub.board_entries[def.board_id(1, false)] = [9000, 8000, 3000]
	stub.board_entries[def.board_id(2, false)] = [9000]
	var before: int = changed[0]
	await App.settle_weekly_rewards()
	check(_state(0) == "missed" and int(_record(0)["rank"]) == 4, "4th place misses the top %d" % def.top_places)
	check(_state(1) == "earned" and int(_record(1)["rank"]) == 3, "3rd place earns it")
	check(_state(2) == "pending", "the week still on has to be over first")
	check(App.profile.has_weekly_reward(kind), "the reward is on the profile")
	check(changed[0] > before, "and the profile says it changed")
	# Nothing is granted twice.
	before = changed[0]
	await App.settle_weekly_rewards()
	check(changed[0] == before and _state(1) == "earned" and _state(0) == "missed", "settling again changes nothing")
	# A new week: the week that was on is over, and is settled too.
	App.clock_override = def.epoch_unix + 3 * 7 * DAY + DAY
	await App.settle_weekly_rewards()
	check(_state(2) == "earned" and int(_record(2)["rank"]) == 2, "once week 2 is over its rank is asked for")
	# The mobile board is its own: a player is ranked on the board they posted to.
	var mobile_board: String = def.board_id(3, true)
	App.profile.queue_weekly_reward(3, mobile_board, 100, kind)
	stub.scores[mobile_board] = 100
	stub.board_entries[mobile_board] = [1, 2]
	App.clock_override = def.epoch_unix + 4 * 7 * DAY + DAY
	await App.settle_weekly_rewards()
	check(_state(3) == "earned" and int(_record(3)["rank"]) == 1, "the mobile board ranks its own players")
	# Two passes at once (the weekly screen opening while the start-up pass waits on the platform) grant a record once:
	# the second asks nothing while the first is waiting.
	var slow := SlowRank.new()
	slow.tree = tree
	slow.simulate_leaderboards = true
	slow.report_ranks = true
	var board: String = def.board_id(5, false)
	slow.scores[board] = 10
	slow.board_entries[board] = [1]
	var normal: PlatformBackend = Platform.backend
	Platform.backend = slow
	App.profile.queue_weekly_reward(5, board, 10, kind)
	App.clock_override = def.epoch_unix + 6 * 7 * DAY + DAY
	var granted: Array[int] = [0]
	var on_grant: Callable = func(_record: Dictionary) -> void: granted[0] += 1
	App.weekly_reward_earned.connect(on_grant)
	App.settle_weekly_rewards()
	App.settle_weekly_rewards()
	await tree.create_timer(0.4, true).timeout
	check(granted[0] == 1 and _state(5) == "earned", "two passes at once grant a record once (%d)" % granted[0])
	check(slow.asked == 1, "and the platform is asked once (%d)" % slow.asked)
	App.settle_weekly_rewards()
	await tree.create_timer(0.2, true).timeout
	check(slow.asked == 1 and granted[0] == 1, "a pass after them has nothing to do")
	App.weekly_reward_earned.disconnect(on_grant)
	Platform.backend = normal
	# The platform's stub says nothing unless asked (so a build on it never grants a rank reward it can't know).
	stub.report_ranks = false
	check(await Platform.leaderboard_rank(def.board_id(0, false)) == 0, "the stub can't say a rank by itself")
	# The web demo has no boards: nothing is asked.
	stub.report_ranks = true
	stub.scores[def.board_id(9, false)] = 1
	App.profile.queue_weekly_reward(9, def.board_id(9, false), 1, kind)
	App.clock_override = def.epoch_unix + 12 * 7 * DAY
	BuildFlavor.set_override(BuildFlavor.Kind.WEB_DEMO)
	await App.settle_weekly_rewards()
	check(_state(9) == "pending", "the demo settles nothing, though a board could say")
	BuildFlavor.set_override(-1)
	await App.settle_weekly_rewards()
	check(_state(9) == "earned", "where there are boards, the same record settles")
	stub.report_ranks = false
	App.profile_changed.disconnect(on_change)
	stub.scores.clear()
	stub.board_entries.clear()
	App.clock_override = -1
	App.profile = saved


func _record(week: int) -> Dictionary:
	for r: Dictionary in App.profile.weekly_rewards:
		if int(r["week"]) == week:
			return r
	return {}


func _state(week: int) -> String:
	return String(_record(week).get("state", "?"))


# --- The levels ------------------------------------------------------------------------------

## Every entry of the shipped list, generated at five lanes and checked as a campaign level is.
func _test_levels() -> void:
	var stats := {"builds": 0, "levels": 0}
	var density_config: LevelConfig = campaign.configure(campaign.step(def.density_step), def.lanes)
	var entries: Array[Dictionary] = def.entries()
	for i: int in entries.size():
		check_entry(def.week(i), "week %d (%s, seed %d)" % [i, entries[i]["zone"], entries[i]["seed"]], stats, density_config)
	print("  weekly levels: %d generated, %.2f builds each" % [stats["levels"], float(stats["builds"]) / maxf(float(stats["levels"]), 1.0)])


## One week's level: its config (Sentinel Row's numbers, the zone's features and look, five lanes, the entry's seed)
## and the layout it builds, with the checks the campaign levels get (test_campaign's `_check_level`). Failures are
## added to `failures`; tools/measure/weekly_seeds.gd uses this to look for seeds that pass.
func check_entry(w: WeeklyWeek, tag: String, stats: Dictionary, density_config: LevelConfig = null) -> void:
	var config: LevelConfig = def.build_config(campaign, w)
	check(config != null, "%s has a level" % tag)
	if config == null:
		return
	var zone: ZoneDef = WeeklyChallenge.zone_of(campaign, w.zone_id)
	var source: LevelConfig = campaign.step(String(def.source_levels[String(w.zone_id)])).level
	var golden: LevelConfig = density_config if density_config != null else campaign.configure(campaign.step(def.density_step), def.lanes)
	# Its config: Sentinel Row's numbers, the zone's own features and look, the week's own seed and lanes.
	check(config.lane_count == 5, "%s: five lanes" % tag)
	check(config.level_seed == w.level_seed, "%s: the entry's seed" % tag)
	check(is_equal_approx(config.run_speed, 25.0), "%s: the Golden Zone's 25 m/s (%.1f)" % [tag, config.run_speed])
	check(is_equal_approx(config.duration_seconds, SECONDS), "%s: %.0f s long" % [tag, config.duration_seconds])
	_check_config(config, source, zone, golden, w, tag)
	check(not config.paced_in_bursts(), "%s: paced evenly, not The Hush's bursts" % tag)
	if zone.id != &"golden":
		check(not config.has_feature("gilded_sentinel") or source.has_feature("gilded_sentinel"),
			"%s: nothing of the Golden Zone's own in another zone's week" % tag)
	# The layout it builds.
	var patterns: Array = LevelGenerator.load_for(config)
	var gen: LevelGenerator = LayoutCache.generator(config, tuning, patterns)
	var layout: LevelLayout = gen.layout
	var movement: MovementTuning = config.movement_for(tuning)
	var expected_length: float = movement.run_speed * SECONDS + 0.5 * movement.speed_gain_per_minute / 60.0 * SECONDS * SECONDS
	check(is_equal_approx(layout.length, expected_length), "%s: finish line matches %.0f s: %.1f m" % [tag, SECONDS, layout.length])
	check(layout.lane_count == 5, "%s: the layout has five lanes" % tag)
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
			check(LayoutChecks.feature_positions(layout, f).is_empty(), "no `%s` in a zone without it %s" % [f, tag])
	var placeable: PackedStringArray = gen.placeable_features(patterns)
	for f: String in config.features:
		if not LayoutChecks.can_locate(f):
			check(not placeable.has(f), "`%s` is planned: nothing places it yet %s" % [f, tag])
			continue
		var at: Array[float] = LayoutChecks.feature_positions(layout, f)
		check(not at.is_empty() or LayoutChecks.occasional(f), "%s has `%s` (GDD §5: every feature of the zone appears) %s" % [zone.id, f, tag])
	if zone.id == &"golden":
		check(LayoutChecks.feature_positions(layout, "octodog").is_empty(), "%s has no Octodogs: the Golden Zone has none %s" % [zone.id, tag])


## Every field of `config` is what its kind says (WeeklyChallenge.ZONE_FIELDS, WEEK_FIELDS, GOLDEN_FIELDS): the zone's
## level's, the week's own, or Sentinel Row's as the campaign configures it (`golden`).
func _check_config(config: LevelConfig, source: LevelConfig, zone: ZoneDef, golden: LevelConfig, w: WeeklyWeek, tag: String) -> void:
	for field: String in WeeklyChallenge.config_fields():
		match WeeklyChallenge.field_owner(field):
			&"zone":
				var expected: Variant = source.get(field)
				if field == "skin" and expected == null:
					expected = zone.skin
				check(config.get(field) == expected, "%s: %s is the zone's" % [tag, field])
			&"golden":
				check(config.get(field) == golden.get(field), "%s: %s is Sentinel Row's (%s, not %s)" % [tag, field,
					config.get(field), golden.get(field)])
	check(config.id == &"weekly" and config.display_name.contains(zone.display_name) and config.display_name.contains(str(w.number())),
		"%s: named for its zone and week (%s)" % [tag, config.display_name])
	check(config.feature_starts.is_empty() and config.feature_ages.is_empty() and config.feature_recency == null,
		"%s: every feature from the start, no recency curve" % tag)
	check(config.guarantee_features and config.minigame == null and not config.off_curve,
		"%s: an ordinary level that guarantees every feature" % tag)
	check(config.skin != null, "%s: the zone's look" % tag)


## Every stored property of LevelConfig is in exactly one of the week's three lists, and no list names a property that
## isn't there: a dial added to LevelConfig later fails here until someone decides whose it is.
func _test_fields() -> void:
	var fields: PackedStringArray = WeeklyChallenge.config_fields()
	check(fields.size() >= 70, "LevelConfig's stored properties are found (%d)" % fields.size())
	for field: String in fields:
		check(WeeklyChallenge.field_owner(field) != &"",
			"LevelConfig.%s is in none of WeeklyChallenge's ZONE_FIELDS, WEEK_FIELDS and GOLDEN_FIELDS: decide whose it is" % field)
	var seen: Dictionary = {}
	for list: PackedStringArray in [WeeklyChallenge.ZONE_FIELDS, WeeklyChallenge.WEEK_FIELDS, WeeklyChallenge.GOLDEN_FIELDS]:
		for field: String in list:
			check(fields.has(field), "%s is no stored property of LevelConfig any more" % field)
			check(not seen.has(field), "%s is in more than one of the week's lists" % field)
			seen[field] = true
	# What a zone's week takes from the zone is its identity: its enemies and its look.
	for field: String in ["features", "feature_weights", "skin", "sky", "darkness", "wall_gap_tuning"]:
		check(WeeklyChallenge.field_owner(field) == &"zone", "%s is the zone's" % field)
	# What makes a week as dense and hard as Sentinel Row is the Golden Zone's.
	for field: String in ["difficulty", "enemy_scaling", "run_speed", "danger_density_increase", "spacing_seconds_easy",
			"fill_empty_seconds", "duration_seconds", "wide_gaps", "narrow_ceiling_share", "doodad_share"]:
		check(WeeklyChallenge.field_owner(field) == &"golden", "%s is Sentinel Row's" % field)


# --- The flow --------------------------------------------------------------------------------

func _test_flow() -> void:
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	var saved: Profile = App.profile
	var stub: StubBackend = Platform.backend as StubBackend
	var saved_mobile: bool = App.mobile
	App.mobile = false
	App.clock_override = def.epoch_unix + 2 * DAY
	App.profile = Profile.new()
	var week: WeeklyWeek = App.current_week()
	check(week.index == 0, "the clock puts us in week 0")

	# Locked until the Floating Head is beaten.
	check(App.weekly_available() and not App.weekly_unlocked(), "a new player has the weekly challenge, locked")
	App.show_weekly()
	await tree.process_frame
	var locked := App.screen as WeeklyScreen
	check(locked != null and locked.play_button != null and locked.play_button.disabled, "its screen shows it locked, with PLAY off")
	App.start_weekly()
	await tree.process_frame
	check(App.run == null and App.screen is WeeklyScreen and App.weekly_state() == &"locked", "and starting it does nothing but show why")
	App.show_title()
	await tree.process_frame
	var title := App.screen as TitleScreen
	check(title.buttons.has("weekly"), "the title has a WEEKLY button")
	App.profile.record_run("city/3", 0, true, 5000, 2, 100.0)
	check(not App.weekly_unlocked(), "beating the Neon City's levels isn't enough")
	App.profile.record_run("city/boss", 0, true, 9000, 3, 90.0)
	check(App.weekly_unlocked(), "beating the Floating Head opens it")
	App.show_weekly()
	await tree.process_frame
	var open := App.screen as WeeklyScreen
	check(open != null and open.play_button != null and not open.play_button.disabled, "its screen offers PLAY")
	check(open.buttons.has("board") and open.countdown_label != null and open.countdown_label.text.begins_with("ENDS IN "),
		"with the board and the time left")
	check(open.best_label.text == "NOT CLEARED YET", "and says it isn't cleared yet")

	# A week's level: five lanes, the zone, the kit.
	var wallet_before: int = App.profile.credits()
	App.start_weekly()
	await physics_frames(3)
	check(App.run != null and App.run.context.is_weekly() and App.run.context.mode == RunContext.Mode.WEEKLY, "PLAY starts a weekly run")
	var ctx: RunContext = App.run.context
	check(ctx.weekly.index == 0 and ctx.config.level_seed == week.level_seed and String(ctx.weekly.zone_id) == String(week.zone_id),
		"of the week's level")
	check(ctx.config.lane_count == 5 and ctx.loadout.tier(&"armor") == 4 and ctx.loadout.tier(&"dash") == 4 and ctx.loadout.tiers.size() == 2,
		"on five lanes, with the kit")
	check(ctx.leaderboard_id() == "weekly/pc/0" and ctx.record_id() == "weekly/0", "counting for the PC board")
	App.begin_run()
	await physics_frames(10)
	check(App.run.world.geo.lane_count == 5 and App.run.world.loadout.tier(&"armor") == 4 and App.run.world.loadout.tier(&"dash") == 4,
		"the world is built on five lanes with the kit")
	check(App.run.world.player.armor_state.max_hits == App.rules.armor_hits_at(4), "Armor IV is on the runner (%d hits)" % App.run.world.player.armor_state.max_hits)
	check(App.revive_options()["item"] == false and App.revive_options()["ad"] == false, "no revive, from stock or for an ad")

	# A clear: the first one pays, collected credits don't, and the score goes to the board.
	var world: RunWorld = App.run.world
	world.score.add_credit(100)
	world.player.distance = world.layout.length - 3.0
	await physics_frames(int((LevelRun.COMPLETE_PAUSE + 0.5) * 60.0))
	await tree.process_frame
	check(App.screen is ResultsScreen, "a clear shows the results (%s)" % App.screen)
	var result: RunResult = (App.screen as ResultsScreen).result if App.screen is ResultsScreen else null
	if result == null:
		_restore(saved, saved_mobile)
		return
	check(result.completed and result.stars == 0, "a clear, with no stars to give")
	check(result.credits_earned == def.first_clear_credits and result.completion_bonus == def.first_clear_credits,
		"the first clear pays the week's %d, not the credits collected (%d)" % [def.first_clear_credits, result.credits_earned])
	check(App.profile.credits() == wallet_before + def.first_clear_credits, "into the wallet")
	check(App.profile.weekly_cleared(0) and App.profile.weekly_best(0) == result.score, "and the week is cleared, with its best")
	check(bool(result.record.get("first_clear")) and bool(result.record.get("submitted")), "the results say first clear, posted")
	check(stub.scores.has("weekly/pc/0") and int(stub.scores["weekly/pc/0"]) == result.score, "the score is on the week's PC board")
	check(not stub.scores.has("weekly/mobile/0"), "and not on the mobile board")
	check(App.profile.weekly_rewards.size() == 1 and String(App.profile.weekly_rewards[0]["state"]) == "pending",
		"a reward record waits for the week to end")
	check(not App.profile.is_completed("weekly/0"), "it is no campaign record")
	var screen := App.screen as ResultsScreen
	check(screen.stars == null, "the results show no stars")
	check(screen.buttons.has("retry"), "and RETRY NOW is there")
	var first_score: int = result.score

	# A second clear of the week pays nothing.
	var after_first: int = App.profile.credits()
	App.retry(result.context)
	await physics_frames(3)
	check(App.run != null and App.run.context.attempt == 2 and App.run.context.config.level_seed == week.level_seed,
		"RETRY NOW is attempt 2 of the same level")
	App.begin_run()
	await physics_frames(10)
	world = App.run.world
	world.score.add_credit(100)
	world.player.distance = world.layout.length - 3.0
	await physics_frames(int((LevelRun.COMPLETE_PAUSE + 0.5) * 60.0))
	await tree.process_frame
	result = (App.screen as ResultsScreen).result if App.screen is ResultsScreen else null
	check(result != null and result.completed, "a second clear")
	if result != null:
		check(result.credits_earned == 0 and result.completion_bonus == 0 and App.profile.credits() == after_first,
			"pays nothing: the week's first clear paid (%d)" % result.credits_earned)
		check(not bool(result.record.get("first_clear")), "the results don't call it a first clear")
		check(App.profile.weekly_best(0) == maxi(first_score, result.score), "the best of the week is kept")
		check(int(stub.scores["weekly/pc/0"]) == maxi(first_score, result.score), "and the board has it")
		check(int(App.profile.weekly_record(0)["attempts"]) == 2, "both attempts are counted")
		check(App.profile.weekly_rewards.size() == 1, "one reward record a week")

	# A death pays nothing, whatever it collected, and posts nothing.
	App.retry(result.context)
	await physics_frames(3)
	App.begin_run()
	await physics_frames(10)
	var posted_before: int = int(stub.scores["weekly/pc/0"])
	App.run.world.score.add_credit(250)
	App.run.world.player._die("test hazard")
	await physics_frames(int((App.rules.death_screen_delay + 0.3) * 60.0))
	await tree.process_frame
	check(App.screen is ResultsScreen, "a death with no revive goes straight to the summary")
	var died: RunResult = (App.screen as ResultsScreen).result if App.screen is ResultsScreen else null
	check(died != null and not died.completed and died.credits_collected >= 250 and died.credits_earned == 0 and App.profile.credits() == after_first,
		"and keeps none of the credits collected")
	check(int(stub.scores["weekly/pc/0"]) == posted_before, "nor does it change the board")

	# Quitting from the pause menu pays nothing either.
	App.retry(died.context)
	await physics_frames(3)
	App.begin_run()
	await physics_frames(10)
	App.run.world.score.add_credit(250)
	App.pause_game()
	App.quit_run()
	await tree.process_frame
	check(App.screen is WeeklyScreen, "quitting goes back to the weekly screen")
	check(App.profile.credits() == after_first, "and keeps no credits")

	# On mobile the board is the mobile one, on the same five lanes and the same level.
	App.mobile = true
	App.clock_override = def.epoch_unix + 2 * DAY
	App.profile.weekly.erase("0")
	App.start_weekly()
	await physics_frames(3)
	check(App.run.context.leaderboard_id() == "weekly/mobile/0" and App.run.context.config.lane_count == 5
		and App.run.context.config.level_seed == week.level_seed, "on mobile: the mobile board, five lanes, the same level")
	check(App.run.context.loadout.tier(&"armor") == 4 and App.run.context.loadout.tier(&"dash") == 4 and App.run.context.loadout.tiers.size() == 2,
		"and the same kit")
	check(App.weekly_board_id(week) != "weekly/pc/0", "the two boards have different names")
	App.mobile = false

	# Another week: the first clear pays again, on the new week's board.
	App.clock_override = def.epoch_unix + 9 * DAY
	var week1: WeeklyWeek = App.current_week()
	check(week1.index == 1 and not App.profile.weekly_cleared(1), "next week is another week, not cleared")
	App.start_weekly()
	await physics_frames(3)
	check(App.run.context.weekly.index == 1 and App.run.context.config.level_seed == week1.level_seed
		and App.run.context.leaderboard_id() == "weekly/pc/1", "with its own level and board")
	App.begin_run()
	await physics_frames(10)
	world = App.run.world
	world.player.distance = world.layout.length - 3.0
	await physics_frames(int((LevelRun.COMPLETE_PAUSE + 0.5) * 60.0))
	await tree.process_frame
	check(App.profile.credits() == after_first + def.first_clear_credits, "its first clear pays the %d again" % def.first_clear_credits)

	# The week turning over between tries: a retry plays the new week's level.
	App.clock_override = def.epoch_unix + 9 * DAY
	App.start_weekly()
	await physics_frames(3)
	var old_ctx: RunContext = App.run.context
	App.clock_override = def.epoch_unix + 16 * DAY
	App.retry(old_ctx)
	await physics_frames(3)
	check(App.run.context.weekly.index == 2, "a retry after the week turned over plays the new week")

	# A review run (--weekly) keeps its five lanes and its kit whatever else it is given, and opens without the Floating Head.
	App.profile = Profile.new()
	App.set(&"_review_args", PackedStringArray(["--weekly=1", "--lanes=3", "--full-loadout", "--god"]))
	App.start_weekly()
	await physics_frames(3)
	check(App.run != null and App.run.context.weekly.index == 1 and App.run.context.config.lane_count == 5
		and App.run.context.loadout.tiers.size() == 2 and App.run.context.loadout.charges.is_empty() and App.run.context.god_mode,
		"--weekly=1 plays week 1 on five lanes with the kit, whatever --lanes and --full-loadout say, in god mode")
	App.set(&"_review_args", PackedStringArray())

	await _test_clock(stub)
	_restore(saved, saved_mobile)


## Starts the week's level, runs it to the finish and gives the result the results screen shows (null if no run started).
func _clear_week() -> RunResult:
	App.start_weekly()
	await physics_frames(3)
	if App.run == null:
		return null
	App.begin_run()
	await physics_frames(10)
	var world: RunWorld = App.run.world
	world.player.distance = world.layout.length - 3.0
	await physics_frames(int((LevelRun.COMPLETE_PAUSE + 0.5) * 60.0))
	await tree.process_frame
	return (App.screen as ResultsScreen).result if App.screen is ResultsScreen else null


## The reviewer's repro of clock farming: clears at weeks 5, 4, 3, -1, -27 and 37 paid 1,000 each, though 5, -27 and 37
## are one layout. Weeks only go forward and none comes before the schedule's first, so only 5 and 37 pay (37 is the
## clock moved forward, which only a trusted time can stop: docs/questions/n5.md, 2).
func _test_clock(stub: StubBackend) -> void:
	App.profile = Profile.new()
	App.profile.record_run("city/boss", 0, true, 9000, 3, 90.0)
	App.mobile = false
	stub.scores.clear()
	var start: int = App.profile.credits()
	var expected: Array = [
		[5, &"open", def.first_clear_credits], [4, &"behind", 0], [3, &"behind", 0],
		[-1, &"not_yet", 0], [-27, &"not_yet", 0], [37, &"open", def.first_clear_credits],
	]
	for step: Array in expected:
		var index: int = step[0]
		App.clock_override = def.week_start(index) + DAY
		var before: int = App.profile.credits()
		check(App.weekly_state() == step[1], "at week %d the weekly challenge is %s (%s)" % [index, step[1], App.weekly_state()])
		var result: RunResult = await _clear_week()
		if step[1] == &"open":
			check(result != null and result.completed, "week %d is played" % index)
		else:
			check(result == null and App.run == null and App.screen is WeeklyScreen,
				"week %d isn't played: its screen says why" % index)
		check(App.profile.credits() - before == int(step[2]), "week %d pays %d (%d)" % [index, step[2], App.profile.credits() - before])
	check(App.profile.credits() - start == 2 * def.first_clear_credits, "of the six, two paid")
	var boards: PackedStringArray = []
	for key: Variant in stub.scores:
		if String(key).begins_with("weekly/"):
			boards.append(String(key))
	boards.sort()
	check(boards == PackedStringArray(["weekly/pc/37", "weekly/pc/5"]), "and two went to a board: %s" % [boards])
	check(App.profile.weekly_high_water() == 37 and not App.profile.weekly.has("-1") and not App.profile.weekly.has("-27"),
		"the highest week played is 37, and no week before the schedule's is kept")
	# Back to week 5 (the clock set right again): behind, and week 37 once cleared isn't paid again.
	App.clock_override = def.week_start(5) + DAY
	check(App.weekly_state() == &"behind", "the clock back at week 5 is behind the highest week played")
	App.show_weekly()
	await tree.process_frame
	var behind := App.screen as WeeklyScreen
	check(behind != null and behind.play_button != null and behind.play_button.disabled, "its screen has PLAY off")
	check(_labels_of(behind).contains("week 38"), "and says which week it goes on at")
	App.clock_override = def.week_start(37) + DAY
	var again: RunResult = await _clear_week()
	check(again != null and again.credits_earned == 0 and App.profile.credits() - start == 2 * def.first_clear_credits,
		"week 37 again pays nothing")
	# The defense under the screen: a run whose week the clock has put out of reach (the clock moved back while it ran)
	# pays and posts nothing, however it is finished.
	for index: int in [4, -1]:
		var stale: RunResult = _stale_result(index)
		var wallet: int = App.profile.credits()
		App._apply_result(stale)
		check(stale.credits_earned == 0 and App.profile.credits() == wallet and bool(stale.record["closed"]),
			"a finished run of week %d (closed) pays nothing and says so" % index)
		check(not stub.scores.has(def.board_id(index, false)), "and posts nothing to week %d's board" % index)
		if index < 0:
			check(not App.profile.weekly.has(str(index)), "and a week before the schedule's first leaves no record")
	# The screen before the schedule's first week.
	App.clock_override = def.epoch_unix - 3 * DAY
	App.show_weekly()
	await tree.process_frame
	var early := App.screen as WeeklyScreen
	check(early != null and early.play_button != null and early.play_button.disabled and _labels_of(early).contains("19 Oct 2026"),
		"before the first week its screen has PLAY off and the date it opens")
	App.clock_override = -1


## A finished, cleared run of week `index` for _apply_result, as the clock moved back mid-run would leave one.
func _stale_result(index: int) -> RunResult:
	var ctx := RunContext.new()
	ctx.mode = RunContext.Mode.WEEKLY
	ctx.weekly = def.week(index)
	ctx.weekly_board = def.board_id(index, false)
	ctx.config = def.build_config(campaign, ctx.weekly)
	var r := RunResult.new()
	r.context = ctx
	r.completed = true
	r.score = 5000
	r.credits_collected = 300
	return r


## The text of every label under `node`, joined.
func _labels_of(node: Node) -> String:
	var out := PackedStringArray()
	for label: Node in node.find_children("*", "Label", true, false):
		out.append((label as Label).text)
	return " ".join(out)


func _restore(saved: Profile, saved_mobile: bool) -> void:
	App.clock_override = -1
	App.mobile = saved_mobile
	App.show_title()
	App.profile = saved
	main.queue_free()
	App.main = null


# --- The web demo ----------------------------------------------------------------------------

func _test_demo() -> void:
	# (After _test_flow: the main scene is gone; the demo's checks need only the App.)
	BuildFlavor.set_override(BuildFlavor.Kind.WEB_DEMO)
	Platform.configure_for(BuildFlavor.Kind.WEB_DEMO)
	check(not App.weekly_available() and not App.weekly_unlocked(), "the web demo has no weekly challenge")
	var saved: Profile = App.profile
	App.profile = Profile.new()
	App.profile.record_run("city/boss", 0, true, 9000, 3, 90.0)
	check(not App.weekly_unlocked(), "not even for a player who beat the Floating Head")
	check(not Platform.leaderboards_available(), "there are no leaderboards there")
	var title := TitleScreen.new()
	tree.root.add_child(title)
	await tree.process_frame
	check(not title.buttons.has("weekly") and not title.buttons.has("endless"), "and its title has no WEEKLY button")
	title.queue_free()
	await tree.process_frame
	BuildFlavor.set_override(-1)
	Platform.configure_for(BuildFlavor.current())
	App.profile = saved
	# The full builds have it.
	for flavor: BuildFlavor.Kind in [BuildFlavor.Kind.FULL_PC, BuildFlavor.Kind.FULL_MOBILE]:
		BuildFlavor.set_override(flavor)
		check(App.weekly_available(), "%s has the weekly challenge" % BuildFlavor.name_of(flavor))
	BuildFlavor.set_override(-1)
