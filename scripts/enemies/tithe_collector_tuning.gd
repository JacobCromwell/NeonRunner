class_name TitheCollectorTuning
extends ThiefTuning
## The Tithe Collector's own numbers (GDD §9.12, task C5): how far ahead it paces the player, how it
## weaves toward the most dangerous lanes ahead of itself, its vacuum's reach, and how it flees once it
## has robbed the player. Distances and speeds are at MovementTuning.REFERENCE_SPEED (18 m/s),
## stretched by the level's pace (`_at()` helpers below), like every other enemy's (Pace,
## docs/ARCHITECTURE.md). Edit data/enemies/tithe_collector.tres (F6 in a level that has it, or
## quick play's --features=tithe_collector).

@export_group("Approach")
## How far ahead of the player it appears (like the stand-in thief's start_ahead).
@export_range(5.0, 120.0, 1.0, "suffix:m") var start_ahead: float = 30.0
## How fast the runner closes in on it (it runs this much slower than the runner, like the stand-in
## thief's approach_speed): slow enough that a stomp or the dash reaches it on an ordinary run, no
## boost needed.
@export_range(0.5, 20.0, 0.5, "suffix:m/s") var approach_speed: float = 7.0
@export_range(0.0, 3.0, 0.05, "suffix:m") var hover_height: float = 0.32
@export_range(0.2, 3.0, 0.05) var model_scale: float = 1.0

@export_group("Weaving")
## How fast it crosses the lanes (GDD §9.12: "weaves through the most dangerous lanes").
@export_range(0.5, 20.0, 0.5, "suffix:m/s") var cross_speed: float = 5.0
## How far ahead of itself, along the track, it looks for hazards to weave toward.
@export_range(5.0, 80.0, 1.0, "suffix:m") var weave_lookahead: float = 24.0
## How often it reconsiders which lane is the most dangerous ahead (seconds: a reaction time, not
## stretched by the pace, like a warning or a wind-up).
@export_range(0.2, 5.0, 0.1, "suffix:s") var weave_interval: float = 1.0

@export_group("Vacuum")
## A floor credit this close to its own position, in its own lane, is sucked up (GDD §9.12: "sucks up
## the credits in its path"): never one in another lane, and never one too far ahead or behind for it
## to have reached yet.
@export_range(0.5, 10.0, 0.25, "suffix:m") var vacuum_reach: float = 2.5
## How often it checks for a credit to vacuum (seconds, not stretched: cheap and frequent enough that
## a credit is taken the moment it comes within reach).
@export_range(0.02, 0.5, 0.01, "suffix:s") var vacuum_interval: float = 0.08

@export_group("Flee")
## After a theft it makes off with what it took (like the stand-in thief, task B6): how fast it pulls
## ahead and rises, how high it climbs (out of reach), and how far ahead it's gone for good.
@export_range(1.0, 40.0, 0.5, "suffix:m/s") var flee_speed: float = 15.0
@export_range(0.0, 10.0, 0.25, "suffix:m/s") var flee_rise: float = 2.5
@export_range(0.0, 10.0, 0.25, "suffix:m") var flee_height: float = 4.0
@export_range(10.0, 200.0, 5.0, "suffix:m") var gone_ahead: float = 65.0

@export_group("Body")
## Its collection plate and body (GDD §9.12: "a small, fast gold drone with a collection plate"). The
## hitbox sits a little inside it (CLAUDE.md principle 4: forgiving).
@export var body_size: Vector3 = Vector3(0.85, 0.55, 0.95)


func start_ahead_at(pace: float) -> float:
	return start_ahead * pace


func approach_speed_at(pace: float) -> float:
	return approach_speed * pace


func cross_speed_at(pace: float) -> float:
	return cross_speed * pace


func weave_lookahead_at(pace: float) -> float:
	return weave_lookahead * pace


func vacuum_reach_at(pace: float) -> float:
	return vacuum_reach * pace


func flee_speed_at(pace: float) -> float:
	return flee_speed * pace


func flee_rise_at(pace: float) -> float:
	return flee_rise * pace


func gone_ahead_at(pace: float) -> float:
	return gone_ahead * pace
