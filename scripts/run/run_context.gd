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
## Quick play review aid (--nofall): the grapple never runs out, so falls never end the run.
var no_fall: bool = false
## Campaign position for the completion bonus (0-based level index), -1 outside the campaign.
var level_index: int = -1
## A boss fight (GDD §10): the boss, whose arena `config` describes (BossArena.base_config). Null for
## a level.
var boss: BossDef
## Where the next attempt at a boss fight starts: {} from the beginning, or, once a checkpoint phase
## was reached (GDD §10: the final fight's halfway checkpoint), {phase, time, score, weapon_damage}
## carried from that attempt (BossEncounter). Retries keep it; starting the step afresh doesn't.
var boss_resume: Dictionary = {}


func is_campaign() -> bool:
	return mode == Mode.CAMPAIGN and step != null


func is_boss() -> bool:
	return boss != null


## The leaderboard a finished run counts for (GDD §6: per level and difficulty tier; GDD §10:
## bosses have their own, ranking the boss score).
func leaderboard_id() -> String:
	if is_boss():
		return "boss/%s/%d" % [boss.id, difficulty_tier]
	if is_campaign():
		return "level/%s/%d" % [step.id, difficulty_tier]
	if mode == Mode.ENDLESS:
		return "endless/%d/%d" % [config.lane_count, difficulty_tier]
	return ""


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
	next.no_fall = no_fall
	next.level_index = level_index
	next.boss = boss
	next.boss_resume = boss_resume.duplicate()
	return next
