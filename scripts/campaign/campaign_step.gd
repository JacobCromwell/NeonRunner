class_name CampaignStep
extends RefCounted
## One stop along the campaign: a cinematic, a level or a boss. Ids are stable ("city/intro",
## "city/1", "city/boss", ...) because the save file keys progress by them.

enum Kind { CINEMATIC, LEVEL, BOSS }

var id: String = ""
var kind: Kind = Kind.LEVEL
var zone: ZoneDef
var zone_index: int = 0
## Level steps: the level, and its position among all campaign levels (0-based).
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
