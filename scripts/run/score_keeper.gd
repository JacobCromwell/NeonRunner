class_name ScoreKeeper
extends Node
## The run's two numbers (GDD §7) and its stats:
## - level score: credits collected (times any active multiplier) plus bonuses (kills, stomps, ...).
##   Feeds stars and leaderboards; never spent.
## - credits: the value of credits collected; paid into the wallet (all of it on completion, a
##   share on death, GDD §4).
## It listens to the player, the enemy director and the credit field; nothing else writes it
## except add_bonus() (enemy rules award their own bonuses, e.g. an Octodog baited into a gap).

signal changed
## A bonus to show on the HUD.
signal bonus_awarded(label: String, points: int)

var world: RunWorld
var score: int = 0
var credits: int = 0
var credit_pickups: int = 0
var kills: int = 0
var stomps: int = 0
var blocked: int = 0
var ramps: int = 0
var longest_wall_run: float = 0.0
## kind -> total points, for the results screen.
var bonuses: Dictionary = {}
## Score multiplier on credits (a ramp-launched wall run, GDD §3).
var multiplier: float = 1.0
## Best possible credit score in this level (for stars).
var max_credit_score: int = 0

var _wall_start: float = -1.0
var _rules: GameRules


func setup(p_world: RunWorld) -> void:
	world = p_world
	_rules = world.rules
	max_credit_score = world.layout.total_credit_value()
	world.player.movement_event.connect(_on_player_event)
	world.player.item_used.connect(_on_item_used)
	world.director.enemy_defeated.connect(_on_enemy_defeated)


func add_credit(value: int) -> void:
	credits += value
	credit_pickups += 1
	score += roundi(value * multiplier)
	changed.emit()


## Adds bonus points of a kind (e.g. &"kill", &"stomp", &"gap_bait", &"host", &"chase") and tells
## the HUD. `label` is what the player reads.
func add_bonus(kind: StringName, points: int, label: String = "") -> void:
	if points == 0:
		return
	score += points
	bonuses[kind] = int(bonuses.get(kind, 0)) + points
	bonus_awarded.emit(label if label != "" else String(kind).capitalize(), points)
	changed.emit()


func stats() -> Dictionary:
	return {
		"score": score,
		"credits": credits,
		"credit_pickups": credit_pickups,
		"kills": kills,
		"stomps": stomps,
		"blocked": blocked,
		"ramps": ramps,
		"longest_wall_run": longest_wall_run,
		"bonuses": bonuses.duplicate(),
		"max_credit_score": max_credit_score,
	}


func _on_enemy_defeated(enemy: Enemy, cause: StringName) -> void:
	if not enemy.is_obstacle:
		kills += 1
	add_bonus(&"kill", enemy.score_value, enemy.display_name)
	if cause == &"stomp":
		stomps += 1
		add_bonus(&"stomp", _rules.stomp_bonus, "Stomp")


func _on_item_used(item: StringName) -> void:
	if item == &"armor" or item == &"shield":
		blocked += 1
		changed.emit()


func _on_player_event(kind: StringName) -> void:
	match kind:
		&"ramp":
			ramps += 1
			multiplier = _rules.ramp_score_multiplier
			_wall_start = world.player.distance
		&"wall_enter":
			_wall_start = world.player.distance
		&"wall_exit", &"wall_jump", &"died":
			_end_wall_run()


func _end_wall_run() -> void:
	multiplier = 1.0
	if _wall_start >= 0.0:
		longest_wall_run = maxf(longest_wall_run, world.player.distance - _wall_start)
		_wall_start = -1.0
