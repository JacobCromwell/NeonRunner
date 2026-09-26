class_name BossPhase
extends Resource
## One phase of a boss fight (GDD §10), listed in its BossDef. Phases run in order; each covers a
## share of the boss's health and ends when weak-point stomps or weapon chip damage take that share.
## The boss script reads its phase's numbers to run its pattern, which cycles until the phase ends:
## nothing in a phase changes while the player struggles (GDD §10: no escalation), and only a later
## phase may be faster (`pace`). A boss with numbers of its own per phase extends this class, the way
## enemy tunings extend EnemyTuning.

## Shown on the HUD's boss bar. Empty = "PHASE n".
@export var display_name: String = ""
## Share of the boss's health this phase covers. The shares of all phases are scaled to add up to 1.
@export_range(0.05, 1.0, 0.01) var health_share: float = 1.0
## Weak-point stomps that clear this phase on their own; each takes an equal part of its health
## (GDD §10: one stomp per phase for the Floating Head). Weapon damage counts too, so chip damage can
## save a stomp.
@export_range(1, 10) var stomps: int = 1
## How fast the boss runs its pattern (1 = its base timing). Boss scripts divide their timings by it.
## GDD §10: a later phase may be faster; nothing else changes with time.
@export_range(0.5, 3.0, 0.05) var pace: float = 1.0
## A death after this phase has begun restarts the fight here instead of at the start (GDD §10: the
## final fight has a checkpoint halfway).
@export var checkpoint: bool = false
## Seconds the phase takes to begin: the boss's entrance for the first phase, the transition after
## the phase before ends for the others (the Floating Head shakes free, shrieks and rises). Meanwhile
## the boss can't be hurt and doesn't attack.
@export_range(0.0, 10.0, 0.1, "suffix:s") var intro_seconds: float = 2.0


## The name the HUD shows for the phase at `index` (0-based).
func title(index: int) -> String:
	return display_name if display_name != "" else "Phase %d" % (index + 1)
