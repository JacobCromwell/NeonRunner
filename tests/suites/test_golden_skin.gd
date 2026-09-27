extends SkinSuite
## The Golden Zone skin (GoldenSkin, Zone 6).

const GOLDEN_SKIN_PATH: String = "res://data/skins/golden_skin.tres"
const GOLDEN_ZONE_PATH: String = "res://data/zones/golden.tres"
const GOLDEN_LEVEL_PATH: String = "res://data/levels/golden_2.tres"


func run() -> void:
	var skin := load(GOLDEN_SKIN_PATH) as GoldenSkin
	check(skin != null, "the golden skin loads")
	if skin == null:
		return
	start_error_count()
	for lanes: int in [3, 5, 6]:
		await whole_level(skin, "golden", GOLDEN_LEVEL_PATH, lanes)
	await hazards_and_triggers(skin)
	await determinism(skin, GOLDEN_LEVEL_PATH)
	stop_error_count("building golden levels")
