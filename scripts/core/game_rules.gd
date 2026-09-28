class_name GameRules
extends Resource
## Game-wide rules that aren't movement: lanes per device, death and revive, protection, score and
## the credit economy. Edit data/tuning/game_rules.tres (also live in the F6 tuning panel).
## Values marked DESIGN-TBD are placeholders, not design decisions (see docs/OPEN_QUESTIONS.md).

@export_group("Lanes")
## GDD §3: 3 lanes on mobile, 5–6 on PC. DESIGN-TBD: the exact PC count is open (OPEN_QUESTIONS §8).
@export_range(3, 8) var lanes_pc: int = 5
@export_range(3, 8) var lanes_mobile: int = 3

@export_group("Death & revive")
## GDD §4: on death the player keeps 20% of the credits collected during that attempt.
@export_range(0.0, 1.0, 0.05) var death_credit_keep_fraction: float = 0.2
## GDD §4: about 1 second of invulnerability after armor or a shield breaks.
@export_range(0.2, 3.0, 0.05, "suffix:s") var hit_invulnerability: float = 1.0
## DESIGN-TBD: invulnerability after a revive, so the player isn't killed again at once.
@export_range(0.5, 5.0, 0.1, "suffix:s") var revive_invulnerability: float = 2.0
## DESIGN-TBD: revives allowed per attempt, by item or ad (OPEN_QUESTIONS §7).
@export_range(0, 5) var max_revives_per_attempt: int = 1
## Pause before the death screen appears, so the death reads.
@export_range(0.2, 3.0, 0.1, "suffix:s") var death_screen_delay: float = 1.0

@export_group("Interactions")
## Upward speed after stomping an enemy.
@export_range(0.0, 15.0, 0.25, "suffix:m/s") var stomp_bounce_velocity: float = 7.5
## A contact counts as a stomp when the player's feet are at most this far below the enemy's top.
@export_range(0.0, 1.0, 0.05, "suffix:m") var stomp_tolerance: float = 0.45
## DESIGN-TBD: the grapple hook's pull out of a gap (upward speed).
@export_range(4.0, 20.0, 0.5, "suffix:m/s") var grapple_pull_velocity: float = 10.0
## Share of a lane switch the player travels before being bumped back by a solid side.
@export_range(0.1, 0.6, 0.05) var lane_bump_fraction: float = 0.3

@export_group("Enemies")
## GDD §9 (decided September 26, 2026): the big attacks of different enemy types take turns, so the
## player never has to dodge two at once (EnemyDirector.major_attack_blocked). The owner may revert
## this after playtesting: switched off, each type only spaces its own attacks, and the Bad Dream
## still never overlaps an Octodog's charges or a drone barrage (GDD §9.7), as before the rule.
@export var big_attacks_take_turns: bool = true

@export_group("Score")
## DESIGN-TBD: score multiplier on credits collected during a ramp-launched wall run (GDD §3).
@export_range(1.0, 5.0, 0.25) var ramp_score_multiplier: float = 2.0
## DESIGN-TBD: bonus score per stomp, on top of the enemy's own score.
@export_range(0, 1000, 10) var stomp_bonus: int = 50
## DESIGN-TBD: score per metre of the longest wall run, shown on the results screen.
@export_range(0, 50, 1) var wall_run_score_per_metre: int = 0

@export_group("Economy")
## DESIGN-TBD: credits paid for completing a level, on top of the credits collected (GDD §4:
## completing always pays far more than dying).
@export_range(0, 5000, 10) var completion_bonus_base: int = 100
## Extra completion bonus per campaign level index (later levels pay more).
@export_range(0, 1000, 5) var completion_bonus_per_level: int = 25
## DESIGN-TBD: star thresholds as a share of the best possible credit score (OPEN_QUESTIONS §5).
## One star for finishing, two and three for reaching these shares.
@export_range(0.0, 1.0, 0.05) var two_star_share: float = 0.45
@export_range(0.0, 1.0, 0.05) var three_star_share: float = 0.75


func lanes_for_device(mobile: bool) -> int:
	return lanes_mobile if mobile else lanes_pc


## Credits paid for finishing the level at `level_index` (0-based campaign position).
func completion_bonus(level_index: int) -> int:
	return completion_bonus_base + completion_bonus_per_level * maxi(level_index, 0)


## Stars for a run: 0 if not finished, else 1–3 by the share of the best possible credit score.
func stars_for(completed: bool, score: int, max_score: int) -> int:
	if not completed:
		return 0
	if max_score <= 0:
		return 3
	var share: float = float(score) / float(max_score)
	if share >= three_star_share:
		return 3
	if share >= two_star_share:
		return 2
	return 1
