class_name RunResult
extends RefCounted
## The outcome of one run, for the results and death screens, the wallet and the records.

var context: RunContext
var completed: bool = false
## Why the player died ("fell", a hazard's name), empty on completion.
var cause: String = ""
var score: int = 0
## Value of the credits picked up during the run (a caught thief's jackpot too), before thefts.
var credits_collected: int = 0
## Credits thieves took and kept (GDD §9.12: a thief that leaves uncaught keeps what it took): part
## of credits_collected, and never paid.
var credits_stolen: int = 0
## Credits paid into the wallet: everything collected (less what thieves kept) plus the completion
## bonus on completion, a share of that on death (GDD §4).
var credits_earned: int = 0
## What completing paid on top of the credits collected: a level's completion bonus, a boss's payout, a mini-game's
## payout (MiniGame.payout: the volleyball match's credits for the points won).
var completion_bonus: int = 0
var stars: int = 0
## Seconds of play: a level's run time, a boss fight's time (with what a checkpoint carried).
var time: float = 0.0
var distance: float = 0.0
## ScoreKeeper.stats(): kills, stomps, blocked, ramps, longest_wall_run, bonuses, ...; a boss fight
## adds BossEncounter.stats(): weak_points, phase, phases, time_bonus; a mini-game level MiniGame.stats(): minigame
## (its id) and the game's own (the volleyball match's points_won, points_lost, returns).
var stats: Dictionary = {}
## From Profile.record_run: new_best, stars_gained, first_clear.
var record: Dictionary = {}


## A boss fight's result (GDD §10): a win pays everything collected plus the boss's payout, with
## stars from its par times; a death pays the usual share (GDD §4). The score already holds the weak
## points, the defeat and the time bonus (BossEncounter scores them as they happen).
static func from_boss(world: RunWorld, encounter: BossEncounter, context: RunContext, won: bool,
		death_cause: String, rules: GameRules) -> RunResult:
	var r := RunResult.new()
	r.context = context
	r.completed = won
	r.cause = death_cause
	r.score = world.score.score
	r._count_credits(world.score)
	r.distance = world.player.distance
	r.stats = world.score.stats()
	var def: BossDef = context.boss
	r.time = encounter.fight_time() if encounter != null else world.player.elapsed
	if encounter != null:
		r.stats.merge(encounter.stats(), true)
	if won:
		r.completion_bonus = def.payout_credits if context.mode != RunContext.Mode.QUICK else 0
	r._pay(won, rules)
	r.stars = def.stars_for(won, r.time)
	return r


## Builds the result from a finished world. `rules` decides the wallet share and stars.
static func from_world(world: RunWorld, context: RunContext, completed_run: bool, death_cause: String,
		rules: GameRules) -> RunResult:
	var r := RunResult.new()
	r.context = context
	r.completed = completed_run
	r.cause = death_cause
	r.score = world.score.score
	r._count_credits(world.score)
	r.time = world.player.elapsed
	r.distance = world.player.distance
	r.stats = world.score.stats()
	# A level that plays a mini-game (the Beach's volleyball match) pays the game's payout instead of the level's
	# completion bonus, and takes its stars from the game.
	var game: MiniGame = MiniGame.of(world)
	if game != null:
		r.stats.merge(game.stats(), true)
	if completed_run and context.mode != RunContext.Mode.QUICK:
		r.completion_bonus = game.payout() if game != null else rules.completion_bonus(maxi(context.level_index, 0))
	r._pay(completed_run, rules)
	# Stars measure the score, which a theft never lowers (ScoreKeeper): a theft costs no star.
	r.stars = game.stars(completed_run) if game != null \
		else rules.stars_for(completed_run, r.score, world.score.max_credit_score)
	return r


## Credits the run holds at its end, as paid from: collected, less what thieves kept.
func credits_kept() -> int:
	return credits_collected - credits_stolen


func _count_credits(keeper: ScoreKeeper) -> void:
	credits_stolen = keeper.stolen_kept()
	credits_collected = keeper.credits + credits_stolen


## Completion pays the credits the run kept plus the bonus; a death (or quitting) a share of them (GDD
## §4: after a theft, a share of what's left).
func _pay(completed_run: bool, rules: GameRules) -> void:
	if completed_run:
		credits_earned = credits_kept() + completion_bonus
	else:
		credits_earned = floori(credits_kept() * rules.death_credit_keep_fraction)
