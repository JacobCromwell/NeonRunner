extends RefCounted
## Blinking antennas (task Q4; GDD §5, Zone 9, the owner, October 21, 2026: "others blink left and right, and the side lit
## when the runner touches the pad decides where they land. Level 2 has fixed antennas; level 3 adds blinking ones"): the
## `teleporter_blinking` feature, which a level lists with `teleporter` (Specimen Vault). The teleporters' rules place them
## (teleporter_rules.gd: LevelConfig.blinking_teleporters of the level's teleporters, from this feature's start where the
## level gives it one); this answers where they are, for the every-feature check, the introduction's and the schedule's
## (LevelGenerator.feature_positions). It has no apply(): nothing of it runs as rules of its own.

const TeleporterRules = preload("res://scripts/enemies/teleporter_rules.gd")

const FEATURE: String = "teleporter_blinking"


## Every teleporter in `layout` with a blinking antenna: its pad's front.
static func positions(layout: LevelLayout) -> Array[float]:
	return TeleporterRules.positions_blinking(layout)
