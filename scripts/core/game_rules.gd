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
## Invulnerability after a revive, so the player isn't killed again at once (FB 16: 2 s).
@export_range(0.5, 5.0, 0.1, "suffix:s") var revive_invulnerability: float = 2.0
## Revives allowed per attempt, by item or ad (FB 16: at most one).
@export_range(0, 5) var max_revives_per_attempt: int = 1
## Pause before the death screen appears, so the death reads.
@export_range(0.2, 3.0, 0.1, "suffix:s") var death_screen_delay: float = 1.0

@export_group("Armor")
## GDD §4 (owner's playtest, September 30, 2026): every level and boss fight starts with armor, free.
## It blocks this many enemy attacks or electrical hazards before it breaks (GDD §8: one)...
@export_range(1, 5) var armor_hits: int = 1
## ...and comes back whole this long after it breaks (GDD §4: 30 seconds), on the run's clock
## (DamageRules.Armor).
@export_range(1.0, 120.0, 0.5, "suffix:s") var armor_recharge: float = 30.0
## DESIGN-TBD (the balancing pass, R7, tunes them): the shop's armor upgrade, one entry per tier (tier 1
## first, as many as the shop catalog's armor tiers): hits before it breaks. GDD §8: the tiers alternate
## between one more hit and a shorter wait.
@export var armor_tier_hits: PackedInt32Array = PackedInt32Array([2, 2, 3, 3])
## DESIGN-TBD (R7 tunes them): the armor upgrade's wait before it comes back, per tier (tier 1 first).
@export var armor_tier_recharge: PackedFloat32Array = PackedFloat32Array([30.0, 25.0, 25.0, 20.0])
## DESIGN-TBD (docs/questions/g3.md): an armor pickup (GDD §10) brings broken or worn armor back whole at
## once; taken while the armor is whole, it adds a hit, up to this many over the armor's count (0: it
## does nothing then).
@export_range(0, 3) var armor_pickup_extra_hits: int = 1

@export_group("Thefts")
## GDD §9.12 (the Tithe Collector, task C5): a thief's touch isn't deadly, it robs (DamageRules ROBBED).
## For this long after a theft no theft can happen again, so one touch robs once (the player's other
## protection is untouched: a theft is no hit). DESIGN-TBD (docs/questions/b6.md): the length.
@export_range(0.2, 5.0, 0.1, "suffix:s") var theft_grace: float = 1.5

@export_group("Interactions")
## Upward speed after stomping an enemy.
@export_range(0.0, 15.0, 0.25, "suffix:m/s") var stomp_bounce_velocity: float = 7.5
## A contact counts as a stomp when the player's feet are at most this far below the enemy's top.
@export_range(0.0, 1.0, 0.05, "suffix:m") var stomp_tolerance: float = 0.45
## The grapple hook's pull out of a gap it's falling into (upward speed; FB 18).
@export_range(4.0, 20.0, 0.5, "suffix:m/s") var grapple_pull_velocity: float = 10.0
## Share of a lane switch the player travels before being bumped back by a solid side.
@export_range(0.1, 0.6, 0.05) var lane_bump_fraction: float = 0.3
## GDD §9.9 (task B4): after the shield or the armor blocks what cuts the floor (the Buzz Overdrive's
## saw), the floor under the player holds for about a second, just enough to switch lanes
## (FloorCut.hold_under).
@export_range(0.2, 3.0, 0.05, "suffix:s") var cut_hold_seconds: float = 1.0

@export_group("Enemies")
## GDD §9 (decided September 26, 2026): the big attacks of different enemy types take turns, so the
## player never has to dodge two at once (EnemyDirector.major_attack_blocked). The owner may revert
## this after playtesting: switched off, each type only spaces its own attacks, and the Bad Dream
## still never overlaps an Octodog's charges or a drone barrage (GDD §9.7), as before the rule.
@export var big_attacks_take_turns: bool = true
## DESIGN-TBD (docs/questions/r3b.md): while big attacks take turns, an enemy waiting for its turn keeps
## its place in the queue until its attack starts or it gives it up, as long as it keeps asking, and
## through a gap in its asks of up to this long (its stretch not clear for a moment, its planned point
## not reached yet); after a longer gap it isn't ready, and loses its place, so the others don't wait
## for it (EnemyDirector.major_attack_blocked). An enemy that means to wait longer keeps asking (an
## Octodog, through its slack).
@export_range(0.0, 10.0, 0.1, "suffix:s") var turn_place_grace: float = 1.0

@export_group("Score")
## Score multiplier on credits collected during a ramp-launched wall run (GDD §3; FB 20: x2).
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


## Hits the armor blocks before it breaks at upgrade tier `tier` (0: the free armor). A tier past the
## data's last uses the last.
func armor_hits_at(tier: int) -> int:
	if tier <= 0 or armor_tier_hits.is_empty():
		return armor_hits
	return maxi(armor_tier_hits[mini(tier, armor_tier_hits.size()) - 1], 1)


## Seconds the armor takes to come back after it breaks, at upgrade tier `tier` (0: the free armor).
func armor_recharge_at(tier: int) -> float:
	if tier <= 0 or armor_tier_recharge.is_empty():
		return armor_recharge
	return maxf(armor_tier_recharge[mini(tier, armor_tier_recharge.size()) - 1], 1.0)


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
