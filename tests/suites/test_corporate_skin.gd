extends SkinSuite
## The Corporate skin (CorporateSkin, Zone 4), which the Corporate zone uses. The shared skin checks
## (SkinSuite) over the whole of Corporate 2 for 3, 5 and 6 lanes, then the zone's own.

const CORP_SKIN_PATH: String = "res://data/skins/corporate_skin.tres"
const PLAZA_SKIN_PATH: String = "res://data/skins/corporate_plaza_skin.tres"
const CORP_ZONE_PATH: String = "res://data/zones/corporate.tres"
## The Corporate zone's campaign level with the most in it (Corporate 2 adds the Tithe Collector and a
## heavier military presence).
const CORP_LEVEL_PATH: String = "res://data/levels/corporate_2.tres"


func run() -> void:
	var skin := load(CORP_SKIN_PATH) as CorporateSkin
	check(skin != null, "the corporate skin loads")
	if skin == null:
		return
	var zone := load(CORP_ZONE_PATH) as ZoneDef
	check(zone != null and zone.skin is CorporateSkin, "the Corporate zone uses the corporate skin")
	start_error_count()
	var env: Environment = skin.make_environment()
	check(env != null and env.sky != null and env.glow_enabled and env.fog_enabled,
		"the corporate environment has a sky, glow and fog")
	for lanes: int in [3, 5, 6]:
		await whole_level(skin, "corporate", CORP_LEVEL_PATH, lanes)
	await hazards_and_triggers(skin)
	await determinism(skin, CORP_LEVEL_PATH)
	var plaza := load(PLAZA_SKIN_PATH) as CorporateSkin
	check(plaza != null and plaza.floor_style == CorporateSkin.FloorStyle.PLAZA, "the plaza variant loads")
	if plaza != null:
		await whole_level(plaza, "corporate plaza", CORP_LEVEL_PATH, 5)
		await hazards_and_triggers(plaza)
	stop_error_count("building corporate levels")
