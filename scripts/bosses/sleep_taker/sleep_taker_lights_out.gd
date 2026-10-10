class_name SleepTakerLightsOut
extends Node
## The Sleep Taker's lights out (GDD §10: "after a deep inhale, it swallows much of the light. It gets
## darker still, but not pitch black, and the glowing hazards stay visible while hands and slashes keep
## coming"; owner, October 10, 2026: "a completely dark tunnel, and the only thing that they will be
## able to see is the glow of the hazards and the glow of the attacks"):
## - the warning (inhale_seconds, SleepTakerTuning): a deep inhale (sleep_taker_inhale), every maw
##   gaping and its heads swelling, the street's light streaming into its maws;
## - then the light sinks to dark_level of the arena's own over dim_seconds (BossEncounter.
##   set_light_level: the environment's ambient and sky light, its fog's light, the sun and the scenery's
##   own light, never below its own floors, SleepTaker.light_floor and scenery_floor; glowing things keep
##   their colours) and stays dark for dark_seconds, the swallowed light glowing in its throats, while the
##   other attacks carry on. Owner, October 8, 2026: half as bright as first built (dark_level 0.45 then,
##   0.225); October 10, 2026: 90% darker again (0.0225), so only what glows shows, and the runner glows
##   by its own light as the light sinks (SleepTaker.runner_glow_now, Player.set_dark_glow);
## - then it breathes out (sleep_taker_exhale) and the light comes back over return_seconds.
## Its timings don't follow the phase's pace (later phases have more of it in their lists instead).
## The light always comes back: after the dark, and at once on clear() (a phase change, the defeat); the
## framework gives the run its light back when the fight leaves the tree.

enum Stage { IDLE, INHALE, DIM, DARK, RETURN }

var boss: SleepTaker
var stage: Stage = Stage.IDLE
var stage_time: float = 0.0
## Lights outs started so far.
var count: int = 0


func setup(p_boss: SleepTaker) -> void:
	boss = p_boss
	name = "LightsOut"


## Starts the inhale (its warning).
func start() -> void:
	count += 1
	_set_stage(Stage.INHALE)
	boss.body.inhale = 1.0
	boss.sound(&"sleep_taker_inhale", boss.body.mouth_world())
	boss.log_event(&"inhale", {"n": count})


## True while its warning plays and the light sinks (nothing else starts meanwhile).
func warning_on() -> bool:
	return stage == Stage.INHALE or stage == Stage.DIM


## True while the light is down (or going down, or coming back).
func is_dark() -> bool:
	return stage != Stage.IDLE


func idle() -> bool:
	return stage == Stage.IDLE


## The light comes back now (a phase change, the defeat): over return_seconds, never a flash.
func clear() -> void:
	if stage != Stage.IDLE:
		boss.set_light_level(1.0, boss.tuning.return_seconds)
		boss.log_event(&"light_back", {"n": count, "early": true})
	if boss.body != null and is_instance_valid(boss.body):
		boss.body.inhale = 0.0
		boss.body.swallowed = 0.0
	_set_stage(Stage.IDLE)


func tick(delta: float) -> void:
	if stage == Stage.IDLE:
		return
	var t: SleepTakerTuning = boss.tuning
	stage_time += delta
	match stage:
		Stage.INHALE:
			if stage_time >= t.inhale_seconds:
				_set_stage(Stage.DIM)
				boss.body.inhale = 0.0
				boss.body.swallowed = 1.0
				boss.set_light_level(t.dark_level, t.dim_seconds)
				boss.log_event(&"dark", {"n": count, "level": t.dark_level})
		Stage.DIM:
			if stage_time >= t.dim_seconds:
				_set_stage(Stage.DARK)
		Stage.DARK:
			if stage_time >= t.dark_seconds:
				_set_stage(Stage.RETURN)
				boss.body.swallowed = 0.0
				boss.set_light_level(1.0, t.return_seconds)
				boss.sound(&"sleep_taker_exhale", boss.body.mouth_world())
				boss.log_event(&"light_back", {"n": count})
		Stage.RETURN:
			if stage_time >= t.return_seconds:
				_set_stage(Stage.IDLE)


func _set_stage(next: Stage) -> void:
	stage = next
	stage_time = 0.0
