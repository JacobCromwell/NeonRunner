class_name TestBossTuning
extends Resource
## The test boss's numbers (data/bosses/test_boss_tuning.tres; F6 in a test boss fight). Timings are
## at pace 1: each phase divides them by its BossPhase.pace. The test boss exists to exercise the boss
## framework, so none of this is game design.

@export_group("Hover")
## How far ahead of the player the core hovers, and how high.
@export_range(10.0, 60.0, 0.5, "suffix:m") var hover_ahead: float = 26.0
@export_range(2.0, 8.0, 0.1, "suffix:m") var hover_height: float = 4.2
## Sideways speed while it follows the player's lane.
@export_range(1.0, 20.0, 0.5, "suffix:m/s") var drift_speed: float = 7.0
## Pause before each attack or drop.
@export_range(0.2, 5.0, 0.05, "suffix:s") var hover_seconds: float = 1.4

@export_group("Lane blast")
## The telegraph: the eye glows and the targeted lane lights up red, with the charge sound.
@export_range(0.3, 3.0, 0.05, "suffix:s") var charge_seconds: float = 1.1
@export_range(1, 6) var bolts: int = 3
@export_range(0.05, 0.6, 0.01, "suffix:s") var bolt_interval: float = 0.16
## Bolt speed over the ground, toward the player.
@export_range(3.0, 40.0, 0.5, "suffix:m/s") var bolt_speed: float = 11.0
@export_range(0.2, 5.0, 0.05, "suffix:s") var cooldown_seconds: float = 1.0
## Blasts before each stomp window.
@export_range(1, 6) var attacks_per_cycle: int = 2
## Fairness: the floor in every lane must be free of holes and fences from this far before the bolts
## arrive to this far after, or the blast waits.
@export_range(0.0, 30.0, 0.5, "suffix:m") var clear_before_impact: float = 12.0
@export_range(0.0, 30.0, 0.5, "suffix:m") var clear_after_impact: float = 8.0

@export_group("Stomp window")
## The core drops into the player's lane this far ahead, dazed, with its weak point up.
@export_range(20.0, 120.0, 1.0, "suffix:m") var drop_lead: float = 48.0
@export_range(0.3, 3.0, 0.05, "suffix:s") var drop_seconds: float = 1.2
## Height of the dazed core's centre (its weak point sits on top).
@export_range(0.2, 1.5, 0.05, "suffix:m") var dazed_height: float = 0.45
## The floor of the drop lane must be clear from this far before the core to this far after.
@export_range(0.0, 30.0, 0.5, "suffix:m") var clear_before_drop: float = 16.0
@export_range(0.0, 20.0, 0.5, "suffix:m") var clear_after_drop: float = 4.0
@export_range(0.3, 3.0, 0.05, "suffix:s") var rise_seconds: float = 1.0
