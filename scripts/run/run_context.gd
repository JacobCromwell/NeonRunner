class_name RunContext
extends RefCounted
## Everything needed to start (or retry) one run: which level, how many lanes, the difficulty
## tier, the loadout and the attempt number.

enum Mode { CAMPAIGN, ENDLESS, QUICK }

var mode: Mode = Mode.QUICK
## Campaign runs: the step being played.
var step: CampaignStep
## Ready to generate: lane count and difficulty already set.
var config: LevelConfig
## Movement tuning for this run (a copy when a difficulty tier changes the speed).
var tuning: MovementTuning
var difficulty_tier: int = 0
var loadout: Loadout
var attempt: int = 1
var revives_used: int = 0
var god_mode: bool = false
## Campaign position for the completion bonus (0-based level index), -1 outside the campaign.
var level_index: int = -1


func is_campaign() -> bool:
	return mode == Mode.CAMPAIGN and step != null


## The id records and leaderboards use.
func record_id() -> String:
	if is_campaign():
		return step.id
	if mode == Mode.ENDLESS:
		return "endless"
	return "quick/%d" % config.level_seed


## A fresh context for the next attempt at the same level (same seed: GDD §6 campaign rule).
func retry() -> RunContext:
	var next := RunContext.new()
	next.mode = mode
	next.step = step
	next.config = config
	next.tuning = tuning
	next.difficulty_tier = difficulty_tier
	next.loadout = loadout
	next.attempt = attempt + 1
	next.god_mode = god_mode
	next.level_index = level_index
	return next
