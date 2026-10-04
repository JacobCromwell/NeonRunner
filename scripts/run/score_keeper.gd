class_name ScoreKeeper
extends Node
## The run's two numbers (GDD §7) and its stats:
## - level score: credits collected (times any active multiplier) plus bonuses (kills, stomps, ...).
##   Feeds stars and leaderboards; never spent.
## - credits: the value of credits collected; paid into the wallet (all of it on completion, a
##   share on death, GDD §4).
## It listens to the player, the enemy director and the credit field; nothing else writes it
## except add_bonus() (enemy rules award their own bonuses, e.g. an Octodog baited into a gap) and a
## thief's hold() (below).
##
## Thefts (GDD §9.12, the Tithe Collector; task B6): a thief's touch (DamageRules ROBBED, the player's
## `robbed`) takes a share of the run's credits as they stand (rob()), and the thief holds it, as it
## holds credits it takes off the track before the player reaches them (hold(); task C5's collector
## sucks them up). Caught by the player, a thief pays back everything it holds plus its jackpot
## (Enemy.jackpot_credits), straight into the run's credits (pay_out()); one that leaves uncaught keeps
## it (stolen_kept(), which the run's pay leaves out, RunResult). The level score never drops, so a theft
## never costs a star or a leaderboard place; credits a thief takes off the track leave the best possible
## score (max_credit_score) while it holds them, so a thief in the level never costs a star either.

signal changed
## A bonus to show on the HUD.
signal bonus_awarded(label: String, points: int)
## A thief took `amount` of the run's credits from the player and holds them (rob()).
signal stolen(amount: int, thief: Node3D)
## A thief was caught: what it held (`amount`) came back into the run's credits, and its `jackpot` on
## top (pay_out()). The thief is being defeated: valid now, freed soon after.
signal recovered(amount: int, jackpot: int, thief: Node3D)

var world: RunWorld
var score: int = 0
var credits: int = 0
var credit_pickups: int = 0
var kills: int = 0
var stomps: int = 0
## Hits the armor or the shield blocked (a multi-hit armor counts each).
var blocked: int = 0
var ramps: int = 0
var longest_wall_run: float = 0.0
## kind -> total points, for the results screen.
var bonuses: Dictionary = {}
## Score multiplier on credits (a ramp-launched wall run, GDD §3).
var multiplier: float = 1.0
## Best possible credit score in this level (for stars). A thief's hold() leaves out what it took off
## the track while it holds it.
var max_credit_score: int = 0
## Thefts (GDD §9.12): how many, the credits thieves took from the player (returned or not), what caught
## thieves gave back (what they held), and the jackpots they paid on top.
var thefts: int = 0
var credits_stolen: int = 0
var credits_recovered: int = 0
var jackpots: int = 0

var _wall_start: float = -1.0
var _rules: GameRules
## What each thief holds now, by its instance id: {"taken": credits it took from the player, "picked":
## credits it took off the track}. A thief that left keeps its entry: what it took is gone.
var _held: Dictionary = {}


func setup(p_world: RunWorld) -> void:
	world = p_world
	_rules = world.rules
	max_credit_score = world.layout.total_credit_value()
	world.player.movement_event.connect(_on_player_event)
	world.player.robbed.connect(_on_robbed)
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


# --- Thefts (GDD §9.12) --------------------------------------------------------------------------

## A thief's touch robbed the player (GDD §9.12, decided September 26, 2026: the Tithe Collector takes
## 25% of the credits collected this run): `share` of the run's credits as they stand (everything
## collected so far, less what thieves hold now), rounded down, leave them, and `thief` holds it. The
## score stays (it's never spent, GDD §7). Returns the credits taken (0 when there were none).
## DESIGN-TBD (docs/questions/b6.md 3): the share of what the run holds now, the score untouched.
func rob(thief: Node3D, share: float) -> int:
	# A hair over, so a share such as 0.3 of 1000 isn't rounded down from 299.99999.
	var amount: int = clampi(floori(credits * clampf(share, 0.0, 1.0) + 0.0001), 0, credits)
	credits -= amount
	var rec: Dictionary = _record(thief)
	rec["taken"] = int(rec["taken"]) + amount
	thefts += 1
	credits_stolen += amount
	stolen.emit(amount, thief)
	changed.emit()
	return amount


## A thief took a credit worth `value` off the track before the player reached it (GDD §9.12: the Tithe
## Collector sucks up the credits in its path; task C5): it holds it too. While it does, the best
## possible credit score leaves it out (max_credit_score, for stars); caught, it pays it back as a
## credit collected (the score too).
func hold(thief: Node3D, value: int) -> void:
	if value <= 0:
		return
	var rec: Dictionary = _record(thief)
	rec["picked"] = int(rec["picked"]) + value
	max_credit_score -= value
	changed.emit()


## Everything `thief` holds now (taken from the player and off the track); 0 for anything else.
func held_by(thief: Node3D) -> int:
	var rec: Dictionary = _held.get(thief.get_instance_id(), {})
	return int(rec.get("taken", 0)) + int(rec.get("picked", 0))


## Credits thieves took from the player and still hold, the ones that got away included: the run's pay
## leaves them out (RunResult).
func stolen_kept() -> int:
	var total: int = 0
	for rec: Dictionary in _held.values():
		total += int(rec["taken"])
	return total


## A thief was caught (GDD §9.12: "it bursts into everything it took plus a jackpot"): everything it
## holds and `jackpot` go straight into the run's credits (RunEffects flies them in as a burst of
## coins), with the payout's sound (as the credit field plays a credit's). What it took off the track and
## the jackpot count as collected, in the score too; what it took from the player was scored already.
## Returns the credits paid. The director's enemy_defeated calls it for player-attributed defeats
## (a thief must be spawned through the director).
## DESIGN-TBD (docs/questions/b6.md 4): straight into the run's credits, not scattered to collect.
func pay_out(thief: Node3D, jackpot: int) -> int:
	var key: int = thief.get_instance_id()
	var rec: Dictionary = _held.get(key, {})
	_held.erase(key)
	var taken: int = int(rec.get("taken", 0))
	var picked: int = int(rec.get("picked", 0))
	var bonus: int = maxi(jackpot, 0)
	if taken + picked + bonus <= 0:
		return 0
	credits += taken + picked + bonus
	score += picked + bonus
	max_credit_score += picked
	credits_recovered += taken + picked
	jackpots += bonus
	world.play_sfx(&"jackpot")
	recovered.emit(taken + picked, bonus, thief)
	changed.emit()
	return taken + picked + bonus


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
		"thefts": thefts,
		"credits_stolen": credits_stolen,
		"credits_recovered": credits_recovered,
		"jackpots": jackpots,
		"stolen_kept": stolen_kept(),
	}


func _record(thief: Node3D) -> Dictionary:
	var key: int = thief.get_instance_id()
	if not _held.has(key):
		_held[key] = {"taken": 0, "picked": 0}
	return _held[key]


func _on_robbed(hazard: Hazard) -> void:
	rob(hazard.enemy if hazard.enemy != null else hazard, hazard.steals_share)


func _on_enemy_defeated(enemy: Enemy, cause: StringName) -> void:
	if cause == &"enemy_charge":
		return
	if not enemy.is_obstacle:
		kills += 1
	add_bonus(&"kill", enemy.score_value, enemy.display_name)
	if cause == &"stomp":
		stomps += 1
		add_bonus(&"stomp", _rules.stomp_bonus, "Stomp")
	# A caught thief pays back what it holds, plus its jackpot (GDD §9.12).
	pay_out(enemy, enemy.jackpot_credits)


func _on_player_event(kind: StringName) -> void:
	match kind:
		&"armor_hit", &"armor_break", &"shield_break":
			blocked += 1
			changed.emit()
		&"ramp":
			ramps += 1
			multiplier = _rules.ramp_score_multiplier
			_wall_start = world.player.distance
		&"wall_enter":
			_wall_start = world.player.distance
		&"wall_exit", &"wall_jump", &"wall_gap_drop", &"died":
			_end_wall_run()


func _end_wall_run() -> void:
	multiplier = 1.0
	if _wall_start >= 0.0:
		longest_wall_run = maxf(longest_wall_run, world.player.distance - _wall_start)
		_wall_start = -1.0
