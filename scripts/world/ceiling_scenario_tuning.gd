class_name CeilingScenarioTuning
extends Resource
## The ceiling scenarios' numbers (task I4; GDD §3, "Ceiling scenarios", owner, October 14, 2026): the treasure
## stash (treasure_stash_rules.gd) and the fenced ceiling (fenced_ceiling_rules.gd), both in CeilingScenarios.
## Edit data/tuning/ceiling_scenarios.tres (F6: "Ceiling scenarios", in a level that has them; Restart level
## rebuilds). How many a level gets is its own (LevelConfig.treasure_stashes, fenced_ceilings,
## fenced_ceiling_pads). Times are seconds at the level's run speed and lengths in metres at
## MovementTuning.REFERENCE_SPEED (stretched by the level's pace) unless they say otherwise, so a faster zone keeps
## them in seconds (GDD §3, Pace). Every number here is a first value for playtesting (DESIGN-TBD,
## docs/questions/i4.md).

@export_group("Both")
## A scenario keeps at least this long (seconds of run) from another's ceiling, so a level sprinkles them rather
## than stacking them.
@export_range(0.0, 60.0, 0.5, "suffix:s") var min_gap_seconds: float = 10.0
## A pad a scenario adds keeps this long before a drone wave arrives: a pad hurls every drone on screen (GDD §9.6),
## and from a wave's arrival to its first pad the drone rules own every pad.
@export_range(0.0, 10.0, 0.5, "suffix:s") var drone_margin_seconds: float = 3.0

@export_group("Treasure stash")
## Endless mode (and any level) gets stashes only where its difficulty (LevelGenerator.difficulty_at) has reached
## this: about Casino 1's, where the campaign brings them in (GDD §3: "sprinkle them in during later zones").
@export_range(0.0, 1.0, 0.05) var stash_min_difficulty: float = 0.5
## The return pad comes this long after the ceiling's rider arrives on it, so they see it and can reach its lane.
@export_range(0.5, 5.0, 0.1, "suffix:s") var see_seconds: float = 1.5
## The size class of the doodad across the stash's own lane at its start (LevelLayout.DOODAD_SIZES).
@export_enum("small", "medium", "large") var front_size: int = 1
## How far the doodads alongside the stash reach back beside the one across its start (metres): a runner beside
## it can't switch into the stash where the one ends and the others begin.
@export_range(0.6, 3.0, 0.1, "suffix:m") var wall_overlap: float = 1.0
## How far above the front doodad's top the return pad's rider still is as they pass its end (metres).
@export_range(0.0, 1.5, 0.05, "suffix:m") var drop_clearance: float = 0.5
## How many credits of the highest denomination a stash holds, drawn evenly between these (GDD §3: "two or three").
@export_range(1, 3) var credits_min: int = 2
@export_range(1, 3) var credits_max: int = 3
## The first credit lies this far past where the return pad's rider lands, the others this far apart.
@export_range(0.0, 4.0, 0.25, "suffix:m") var credit_lead: float = 1.0
@export_range(1.0, 6.0, 0.25, "suffix:m") var credit_spacing: float = 2.0
## The last credit lies at least this far inside the stash's open end (metres, not stretched).
@export_range(0.5, 4.0, 0.25, "suffix:m") var credit_end_margin: float = 1.5
## The ceiling runs on this long past the stash's open end, so a rider who stays on drops beyond it.
@export_range(0.0, 2.0, 0.05, "suffix:s") var ceiling_after_seconds: float = 0.3

@export_group("Fenced ceiling")
## Endless mode (and any level) gets fenced ceilings only where its difficulty has reached this: about Casino 2's.
@export_range(0.0, 1.0, 0.05) var fenced_min_difficulty: float = 0.55
## How much faster than the run speed a rider may take a pad (m/s): a speed pad's or a ramp's fading boost. The
## fences come after where even such a rider arrives, and cover a jump at that speed.
@export_range(0.0, 12.0, 0.5, "suffix:m/s") var rider_boost: float = 6.0
## Slack taken off the rows' spacing and added past the fastest arrival (metres, not stretched): the physics'
## frame steps.
@export_range(0.0, 2.0, 0.05, "suffix:m") var row_margin: float = 0.5
## The first pad past the fences lies this far beyond the last row (metres, not stretched), so it reads as past them.
@export_range(0.5, 6.0, 0.25, "suffix:m") var safe_gap: float = 1.5
## The ceiling runs on this long past where a safe pad's rider arrives: the safe part of the ceiling.
@export_range(0.5, 4.0, 0.1, "suffix:s") var safe_ride_seconds: float = 1.5
## Pads of the same kind on one fenced ceiling (the later version's several pads) are this long apart, each in
## another lane.
@export_range(0.2, 2.0, 0.05, "suffix:s") var pad_step_seconds: float = 0.6
