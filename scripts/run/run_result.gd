class_name RunResult
extends RefCounted
## The outcome of one run, for the results and death screens, the wallet and the records.

var context: RunContext
var completed: bool = false
## Why the player died ("fell", a hazard's name), empty on completion.
var cause: String = ""
var score: int = 0
## Value of the credits picked up during the run.
var credits_collected: int = 0
## Credits paid into the wallet: everything collected plus the completion bonus on completion,
## a share of what was collected on death (GDD §4).
var credits_earned: int = 0
var completion_bonus: int = 0
var stars: int = 0
var time: float = 0.0
var distance: float = 0.0
## ScoreKeeper.stats(): kills, stomps, blocked, ramps, longest_wall_run, bonuses, ...
var stats: Dictionary = {}
## From Profile.record_run: new_best, stars_gained, first_clear.
var record: Dictionary = {}


## Builds the result from a finished world. `rules` decides the wallet share and stars.
static func from_world(world: RunWorld, context: RunContext, completed_run: bool, death_cause: String,
		rules: GameRules) -> RunResult:
	var r := RunResult.new()
	r.context = context
	r.completed = completed_run
	r.cause = death_cause
	r.score = world.score.score
	r.credits_collected = world.score.credits
	r.time = world.player.elapsed
	r.distance = world.player.distance
	r.stats = world.score.stats()
	if completed_run:
		r.completion_bonus = rules.completion_bonus(maxi(context.level_index, 0)) if context.mode != RunContext.Mode.QUICK else 0
		r.credits_earned = r.credits_collected + r.completion_bonus
	else:
		r.credits_earned = floori(r.credits_collected * rules.death_credit_keep_fraction)
	r.stars = rules.stars_for(completed_run, r.score, world.score.max_credit_score)
	return r
