class_name CampaignStep
extends RefCounted
## One stop along the campaign: a cinematic, a level or a boss. Ids are stable ("city/intro",
## "city/1", "city/boss", ...) because the save file keys progress by them.

enum Kind { CINEMATIC, LEVEL, BOSS }

var id: String = ""
var kind: Kind = Kind.LEVEL
var zone: ZoneDef
var zone_index: int = 0
## Level steps: the level, and its place on the campaign's difficulty curve (0-based): its position among the
## campaign's levels, those off the curve (LevelConfig.off_curve, task D10c: the Beach's) left out, each of which
## takes the place of the level before it. The completion bonus (GameRules.completion_bonus) and the feature
## ages (Campaign.feature_ages) count it too.
var level: LevelConfig
var level_index: int = -1
## Position within the zone's levels (1-based) for level steps.
var number_in_zone: int = 0
var boss: BossDef
var cinematic: CinematicDef
## Position in the whole campaign sequence.
var index: int = 0


func title() -> String:
	match kind:
		Kind.LEVEL:
			return level.display_name if level.display_name != "" else "Level %d" % number_in_zone
		Kind.BOSS:
			return boss.display_name if boss != null else "Boss"
	return cinematic.title if cinematic != null else "Cinematic"


func is_level() -> bool:
	return kind == Kind.LEVEL


## A level step that plays a mini-game (LevelConfig.minigame: the Beach's volleyball match) rather than a generated
## layout. Still a level (records, stars, its tile, the results and the shop), but nothing about it is generated.
func is_minigame() -> bool:
	return kind == Kind.LEVEL and level != null and level.plays_minigame()
