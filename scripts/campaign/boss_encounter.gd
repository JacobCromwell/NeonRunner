class_name BossEncounter
extends Node3D
## Base for a boss mini-game scene (GDD §10; each boss is a standalone mini-game with its own
## rules, owner decision September 26, 2026). The App instances the boss's scene, calls begin(),
## and waits for `finished`. Bosses must follow the shared rules: named input actions only,
## damage through DamageRules, bosses ignore claw contact kills, every attack telegraphed, and
## every boss beatable with only the power-ups granted before the fight (BossDef.granted_items).

## `won`: the boss was beaten. `score` feeds the zone's boss record; `credits` go to the wallet.
signal finished(won: bool, score: int, credits: int)

var boss: BossDef
var loadout: Loadout
var lane_count: int = 3
var difficulty_tier: int = 0


## Called once after the scene enters the tree.
func begin(p_boss: BossDef, p_loadout: Loadout, p_lane_count: int, p_difficulty_tier: int) -> void:
	boss = p_boss
	loadout = p_loadout
	lane_count = p_lane_count
	difficulty_tier = p_difficulty_tier
	_start()


## Override: build and start the encounter.
func _start() -> void:
	pass
