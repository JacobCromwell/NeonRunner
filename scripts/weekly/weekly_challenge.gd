class_name WeeklyChallenge
extends Resource
## The weekly challenge (GDD §6, Replay features, "Weekly challenge"; the owner, October 18, 2026; task N5): one fixed
## level a week, the same for every player, with a leaderboard for that week. This is its data (data/weekly/
## weekly_challenge.tres) and its rules, in one place so the numbers never live in code (CLAUDE.md principle 7):
## - *Which week it is* from the date (week_index), and which level that week plays: an entry of the seed list
##   shipped with the game (data/weekly/weekly_seeds.json, entries()), picked by the week index and never by the date
##   itself, so every level a player can ever be given was built and checked in advance (test_weekly_challenge).
## - *The level* (build_config): the week's zone's own enemies, obstacles and look at the Golden Zone's density,
##   difficulty, enemy scaling and run speed, always on `lanes` lanes whatever the platform.
## - *The kit* (`kit`, Loadout.weekly): the same for every player, whatever they own.
## - *The boards* (board_id): one a week for PC and one for mobile.
## - *The rewards* (`first_clear_credits`, `top_places`, `reward_kind`).
## - *The unlock* (`unlock_step`).
## App runs a week (start_weekly) and settles a run (_settle_weekly); the screen is WeeklyScreen.

const PATH: String = "res://data/weekly/weekly_challenge.tres"
## The boards' platform names (board_id): the two boards of a week.
const BOARD_PC: String = "pc"
const BOARD_MOBILE: String = "mobile"

## The fields of a week's LevelConfig (build_config), every stored property of LevelConfig in exactly one of these three
## lists: `test_weekly_challenge` fails on a property that is in none (or two), so a dial added to LevelConfig later
## forces a decision here about whose it is.
## - The ZONE's: what a week takes from the zone's own level (`source_levels`): its enemies and obstacles (the features,
##   their pick weights, the patterns they come from) and its look (skin, sky, darkness), including the Beach's open
##   walls (`wall_gap_tuning`, and the wall-lane doodads that go with them). A dial that is about a zone's own mechanic
##   belongs here too: `wall_hop_lines` (task N1, GDD §7 "from Gangland on") is 0 in the Neon City's levels and 1 in every
##   other zone's, so a City week has no wall-hop credits (and on the Beach its open walls leave no room for a line).
##   The Terminal's rules (task O1; GDD §5, Zone 8) are its zone's too: no wall running (`wall_running`, with its
##   arches, `wall_gap_tuning`, and its own patterns, `patterns_path`) and every ceiling one lane wide
##   (`narrow_ceiling_share` and `one_lane_ceiling_share`, which every other zone's level has as Sentinel Row does, so
##   their weeks are as before).
const ZONE_FIELDS: PackedStringArray = [
	"features", "feature_weights", "patterns_path", "skin", "skin_path", "sky", "darkness", "wall_gap_tuning", "doodad_wall_lane_share",
	"wall_hop_lines", "wall_running", "narrow_ceiling_share", "one_lane_ceiling_share",
]
## - The WEEK's: what a week sets itself: which level it is (id, name, seed, lanes), that it is no level of the campaign's
##   curve or a mini-game, that every feature is there from the start (no `feature_starts`, as in endless mode) with no
##   recency curve, and that every feature must appear.
const WEEK_FIELDS: PackedStringArray = [
	"id", "display_name", "level_seed", "lane_count", "off_curve", "minigame", "feature_starts", "feature_ages",
	"feature_recency", "guarantee_features",
]
## - SENTINEL ROW's (`density_step`, as Campaign.configure sets it: difficulty, enemy scaling and run speed from its place
##   on the curve): how many things there are, how dense, how hard and how fast, and everything else about the shape of
##   the level: its length, pacing, gaps, ceilings, doodads' density, credits, fairness rules and dials for features a
##   zone may lack (a dial for a feature the zone doesn't list does nothing: the generator runs a rules script per feature
##   the level lists).
const GOLDEN_FIELDS: PackedStringArray = [
	"duration_seconds", "run_speed", "difficulty", "difficulty_bias", "difficulty_ramp", "enemy_scaling",
	"start_clear_distance", "end_clear_distance", "spacing_seconds_easy", "spacing_seconds_hard", "fill_empty_seconds",
	"gap_encounter_increase", "gap_lane_increase", "danger_density_increase", "wide_gaps", "charge_path_cyborgs",
	"buzz_company", "dash_walls", "treasure_stashes", "fenced_ceilings", "fenced_ceiling_pads", "quiet_seconds",
	"burst_seconds", "quiet_spacing_seconds", "burst_spacing_seconds", "quiet_features", "max_gap_jump_fraction",
	"hull_lead_in", "hull_landing_seconds", "cut_holes_beside", "cut_reaction_seconds",
	"narrow_ceiling_start", "narrow_ceiling_max_lanes", "one_lane_ceiling_seconds",
	"doodad_share", "doodad_spot_seconds", "doodad_start", "doodad_small_weight", "doodad_medium_weight",
	"doodad_large_weight", "doodad_gap_seconds", "doodad_reaction_seconds", "doodad_row_chance", "doodad_row_min",
	"doodad_row_max", "doodad_row_spaced_small", "doodad_row_spaced_medium", "doodad_row_spaced_large",
	"doodad_wall_clear_seconds", "credit_trail_spacing", "credit_trail_count", "credit_trail_min", "credit_trail_chance",
	"credit_gap_chance", "credit_fence_chance", "credit_wall_runs", "credit_ceilings",
]
## Properties every Resource has that are no part of a level's config (as LevelCache.CONFIG_SKIP).
const RESOURCE_PROPERTIES: PackedStringArray = ["resource_path", "resource_name", "resource_local_to_scene", "script"]

@export_group("Schedule")
## The moment week 0 opens, UTC unix seconds (owner, October 18, 2026, item 1025; GDD §6): Monday 00:00 UTC,
## October 19, 2026, so every week opens Monday 00:00 UTC, the same instant for every player. Boards are named
## after the week index counted from it, so it must never change once the game has shipped.
@export var epoch_unix: int = 1792368000
## The length of a week in seconds (7 days).
@export_range(86400, 1209600, 3600, "suffix:s") var week_seconds: int = 604800
## The shipped seed list: [{"zone": <zone id>, "seed": <int>}, ...]. A week plays entry `week index mod size`.
@export_file("*.json") var seeds_path: String = "res://data/weekly/weekly_seeds.json"

@export_group("The level")
## Lanes on every platform (GDD §3, §6): PC and mobile play the same layout, so the boards are comparable. The weekly
## level keeps this even if a platform's campaign lane count (GameRules.lanes_pc, lanes_mobile) changes later.
@export_range(3, 8) var lanes: int = 5
## The campaign level whose difficulty, enemy scaling, density and run speed every week plays at (GDD §6, proposed:
## the Golden Zone's hardest level, Sentinel Row): a campaign step id. DESIGN-TBD (items 1034 and 1035):
## a Neon City week is far denser and faster than any Neon City level; whether that is what "Golden Zone difficulty"
## means, and whether the pace is the Golden Zone's in every zone.
@export var density_step: String = "golden/2"
## Each zone's own level, whose enemies, obstacles and look the zone's week plays in: zone id -> campaign step id
## (the zone's last ordinary level: not the Beach's volleyball match, not The Hush, not the Golden Palace).
## DESIGN-TBD (items 1031, 1032 and 1033): which level stands for each zone, and that every feature is there
## from the start.
@export var source_levels: Dictionary[String, String] = {}

@export_group("Kit")
## The uniform kit (GDD §6): shop item id -> tier. Armor IV and Juggernaut dash IV, nothing else; the free armor every
## run starts with (GDD §4) stays under the upgrade as ever.
@export var kit: Dictionary[String, int] = {"armor": 4, "dash": 4}

@export_group("Rewards")
## DESIGN-TBD (item 1028): the credits the week's first clear pays: "equal to a middle-of-the-road
## level's payout" (GDD §6). The placeholder is the typical player's finish payout of the campaign's middle level
## (credits kept at 70% of what a level holds, plus its completion bonus: the median over the 19 generated levels is
## 993, Marketplace 2's, with N1's wall-hop credits in; 1,023 before; tools/measure/economy.gd), rounded. Paid once a
## week: every other run pays nothing.
@export_range(0, 20000, 50) var first_clear_credits: int = 1000
## The places on a week's board that earn the Leader of the Pack cosmetic (GDD §6: the top three "for now; the owner
## will adjust it"). DESIGN-TBD (item 1037): on each platform's board, or on one combined ranking.
@export_range(1, 100, 1) var top_places: int = 3
## What a top place earns (DESIGN-TBD, item 977 in docs/OPEN_QUESTIONS.md: the cosmetic is still to be designed, so the
## game records the reward under this name and grants nothing yet; App._grant_weekly_reward; item 1039).
@export var reward_kind: StringName = &"leader_of_the_pack"
## A week's rank is only final once the week is over, so the game asks the platform for it later (App.
## settle_weekly_rewards). A week whose rank the platform still can't say after this many weeks is dropped.
## DESIGN-TBD (item 1038): when a reward is granted and how long the game keeps asking.
@export_range(1, 52, 1) var reward_check_weeks: int = 8

@export_group("Unlock")
## The campaign step that opens the weekly challenge once it is done (GDD §6: the Neon City's boss, the Floating Head).
@export var unlock_step: String = "city/boss"

var _entries: Array[Dictionary] = []


static func load_default() -> WeeklyChallenge:
	return load(PATH) as WeeklyChallenge


# --- The calendar -------------------------------------------------------------------------

## The week `unix` (UTC seconds) falls in: 0 from `epoch_unix` for a week, 1 the next, negative before it.
func week_index(unix: int) -> int:
	return floori(float(unix - epoch_unix) / float(week_seconds))


## When week `index` opens (UTC unix seconds).
func week_start(index: int) -> int:
	return epoch_unix + index * week_seconds


## Week `index`: its level (an entry of the seed list) and its dates. Null if the seed list is empty or unreadable.
func week(index: int) -> WeeklyWeek:
	var list: Array[Dictionary] = entries()
	if list.is_empty():
		return null
	var w := WeeklyWeek.new()
	w.index = index
	w.entry_index = posmod(index, list.size())
	w.zone_id = StringName(String(list[w.entry_index]["zone"]))
	w.level_seed = int(list[w.entry_index]["seed"])
	w.starts_at = week_start(index)
	w.ends_at = week_start(index + 1)
	return w


## The week it is at `unix`.
func week_at(unix: int) -> WeeklyWeek:
	return week(week_index(unix))


## The shipped seed list: [{"zone": String, "seed": int}], in week order (read once).
func entries() -> Array[Dictionary]:
	if _entries.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(seeds_path))
		if typeof(parsed) != TYPE_DICTIONARY:
			push_error("WeeklyChallenge: could not read %s" % seeds_path)
			return _entries
		for d: Variant in (parsed as Dictionary).get("entries", []):
			if typeof(d) == TYPE_DICTIONARY and (d as Dictionary).has("zone") and (d as Dictionary).has("seed"):
				_entries.append({"zone": String((d as Dictionary)["zone"]), "seed": int((d as Dictionary)["seed"])})
	return _entries


## The board a clear of week `index` is posted to (Platform.submit_score): one a week for each platform's
## players (GDD §6: "two boards: one for PC, one for mobile").
func board_id(index: int, mobile: bool) -> String:
	return "weekly/%s/%d" % [BOARD_MOBILE if mobile else BOARD_PC, index]


## "Mon 19 Oct 2026, 00:00 UTC": a moment (UTC unix seconds) for the screen.
static func format_date(unix: int) -> String:
	var d: Dictionary = Time.get_datetime_dict_from_unix_time(unix)
	var days: PackedStringArray = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
	var months: PackedStringArray = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	return "%s %d %s %d, %02d:%02d UTC" % [days[int(d["weekday"])], int(d["day"]), months[int(d["month"]) - 1], int(d["year"]),
		int(d["hour"]), int(d["minute"])]


## "3d 4h", "5h 12m", "12m", "under a minute": the time left in a week for the screen.
static func format_left(seconds: int) -> String:
	var s: int = maxi(seconds, 0)
	var days: int = s / 86400
	var hours: int = (s % 86400) / 3600
	var minutes: int = (s % 3600) / 60
	if days > 0:
		return "%dd %dh" % [days, hours]
	if hours > 0:
		return "%dh %dm" % [hours, minutes]
	if minutes > 0:
		return "%dm" % minutes
	return "under a minute"


# --- The level ----------------------------------------------------------------------------

## The zone `zone_id` in `campaign`, or null.
static func zone_of(campaign: Campaign, zone_id: StringName) -> ZoneDef:
	for zone: ZoneDef in campaign.zones:
		if zone.id == zone_id:
			return zone
	return null


## Every stored property of LevelConfig (the ones a level's data holds), in declaration order.
static func config_fields() -> PackedStringArray:
	var out := PackedStringArray()
	for prop: Dictionary in (LevelConfig.new() as Object).get_property_list():
		var field: String = prop["name"]
		if int(prop["usage"]) & PROPERTY_USAGE_STORAGE and not RESOURCE_PROPERTIES.has(field):
			out.append(field)
	return out


## Whose a LevelConfig field is in a week: &"zone" (ZONE_FIELDS), &"week" (WEEK_FIELDS), &"golden" (GOLDEN_FIELDS), or
## &"" for one that is in none (a test fails on that).
static func field_owner(field: String) -> StringName:
	if ZONE_FIELDS.has(field):
		return &"zone"
	if WEEK_FIELDS.has(field):
		return &"week"
	if GOLDEN_FIELDS.has(field):
		return &"golden"
	return &""


## The level week `w` plays, ready to generate (GDD §6): Sentinel Row's numbers (density_step) with the week's zone's
## own features and look. Each field of the LevelConfig is one of three kinds (ZONE_FIELDS, WEEK_FIELDS, GOLDEN_FIELDS).
## - *Sentinel Row's, as the campaign configures it* (Campaign.configure): the start, and every field not taken from
##   the zone or set by the week stays as it is (GOLDEN_FIELDS): difficulty, enemy scaling (fire rate, projectile speed,
##   health), run speed, length and every pacing, density, gap and credit dial.
## - *The zone's, from its level in `source_levels`* (ZONE_FIELDS): its features and their pick weights, its skin
##   (the zone's own where the level has none), sky and darkness, its open walls or arches, whether its walls can be
##   run on, and its ceilings' widths.
## - *The week's own* (WEEK_FIELDS): the week's seed, `lanes` lanes, every feature from the start (as endless mode does: a
##   campaign level's introductions, `feature_starts`, would hold features back in a level the player meets on its own),
##   and no recency curve (the campaign's newest-first picks mean nothing for a level outside it).
## The weekly always plays on the Normal tier's numbers. DESIGN-TBD (item 1041): whether the Hard and
## Insane tiers (GDD §6) should touch it.
## Null if the zone or either level isn't in the campaign.
func build_config(campaign: Campaign, w: WeeklyWeek) -> LevelConfig:
	var zone: ZoneDef = zone_of(campaign, w.zone_id)
	var density: CampaignStep = campaign.step(density_step)
	var source: CampaignStep = campaign.step(String(source_levels.get(String(w.zone_id), "")))
	if zone == null or density == null or source == null or source.level == null:
		push_error("WeeklyChallenge: no level for zone '%s' (density %s, source %s)" % [w.zone_id, density_step,
			source_levels.get(String(w.zone_id), "?")])
		return null
	var config: LevelConfig = campaign.configure(density, lanes)
	for field: String in ZONE_FIELDS:
		config.set(field, _own(source.level.get(field)))
	if config.skin == null:
		config.skin = zone.skin
	config.id = &"weekly"
	config.display_name = "%s, week %d" % [zone.display_name, w.number()]
	config.level_seed = w.level_seed
	config.lane_count = lanes
	config.off_curve = false
	config.minigame = null
	config.guarantee_features = true
	var starts: Dictionary[String, float] = {}
	config.feature_starts = starts
	var ages: Dictionary[String, int] = {}
	config.feature_ages = ages
	config.feature_recency = null
	return config


## A copy of a level's field value a week may keep: lists and dictionaries are copied (the level's own stay as they are),
## a resource is shared.
static func _own(value: Variant) -> Variant:
	match typeof(value):
		TYPE_DICTIONARY:
			return (value as Dictionary).duplicate()
		TYPE_ARRAY:
			return (value as Array).duplicate()
		TYPE_PACKED_STRING_ARRAY:
			return (value as PackedStringArray).duplicate()
	return value


# --- The kit ------------------------------------------------------------------------------

## The tier of shop item `id` in the kit (0 if it isn't in it).
func kit_tier(id: StringName) -> int:
	return int(kit.get(String(id), 0))
