class_name WallHopTuning
extends Resource
## Wall-hop credits (task N1; GDD §7, "Wall-hop credits", owner, October 9, 2026: "some long walls carry high-value
## credits further along than one wall run reaches, so only a player inventive enough to wall hop collects them";
## WallHopPlacement): a line of credits along a long, clear stretch of one side wall, from a free entry along the wall
## run, and a few high-value ones further along than one wall run from there reaches and higher than a step onto the
## wall from the floor carries a pickup, where a runner who wall hops (GDD §3: jumping off a wall and straight back on
## starts a fresh wall run) passes them. A jump onto the wall from the floor at the right spot starts a run high enough
## too (DESIGN-TBD, docs/questions/n1.md question 4); the magnet leaves them alone (CreditField._in_magnet). How many a
## level gets is its own (LevelConfig.wall_hop_lines, 1 from Gangland 1 on). Edit
## data/tuning/wall_hops.tres (F6: "Wall-hop credits", in a level that has them; Restart level rebuilds). Times are
## seconds of run at the level's run speed, so a faster zone keeps them. Every number here is a first value for
## playtesting (DESIGN-TBD, docs/questions/n1.md).

const PATH: String = "res://data/tuning/wall_hops.tres"

@export_group("The reference hopper")
## The runner the line is laid out for (WallHopPath): steps onto the wall from the outer lane at the line's entry,
## and wall hops each time its wall run has come down to this height (metres on the wall), partway down the run, as a
## runner hops to stay on a wall that would drop them.
@export_range(0.6, 2.0, 0.05, "suffix:m") var hop_height: float = 1.5

@export_group("The line")
## The line's first credits lie along the first wall run from the entry, this far apart, until that run's hop: they
## show where to get on and point along the wall.
@export_range(0.1, 1.0, 0.05, "suffix:s") var lead_step_seconds: float = 0.3
## The lead-in's credits' value (LevelGenerator.DENOMINATIONS): reached by any wall run from the entry, they count
## toward the stars like any credit.
@export_range(1, 100) var lead_value: int = 1
## How many high-value credits lie past one wall run's reach (GDD §7: "high-value credits further along than one
## wall run reaches").
@export_range(1, 6) var gems: int = 3
## Their value (LevelGenerator.DENOMINATIONS). Left out of the stars' best score (LevelLayout.star_credit_value), as a
## treasure stash's are: a reward for a move the game never asks for.
@export_range(1, 100) var gem_value: int = 25
## They lie this far apart along the wall (seconds of run).
@export_range(0.05, 0.5, 0.01, "suffix:s") var gem_step_seconds: float = 0.12
## The first lies at least this long past where one wall run from the entry (the standard one,
## MovementTuning.wall_entry_time + wall_slide_time) has dropped its runner off the wall. One with claws slides on
## further, but never above a fresh run's height (gem_clearance), so it passes under them.
@export_range(0.0, 2.0, 0.05, "suffix:s") var reach_margin_seconds: float = 0.25
## They hang this far above the highest a fresh wall run carries a credit pickup's reach when its runner steps on and
## never hops (WallHopPath.fresh_top: a step onto the wall from the floor, or straight back onto it as a wall run drops
## them; WallHopPath.pickup_reach): such a runner passes under them, while a hop's fresh wall run starts higher
## (MovementTuning.wall_air_entry_factor of the height it hops from), and so does one a jump from the floor starts
## (docs/questions/n1.md question 4).
@export_range(0.0, 1.0, 0.025, "suffix:m") var gem_clearance: float = 0.1

@export_group("Its stretch")
## The outer lane's floor beside the wall stays clear from this long before the entry (a step into the lane and onto
## the wall)...
@export_range(0.0, 2.0, 0.05, "suffix:s") var run_in_seconds: float = 0.5
## ... to this long past where a runner who jumps off the wall at the last high-value credit comes down in the outer
## lane (WallHopPlacement.wall_jump_seconds): a reaction on clear floor after a hop that didn't come back.
@export_range(0.0, 2.0, 0.05, "suffix:s") var landing_seconds: float = 0.5
## Lines in one level keep at least this long apart (seconds of run).
@export_range(0.0, 120.0, 1.0, "suffix:s") var min_gap_seconds: float = 30.0


## The shared numbers (data/tuning/wall_hops.tres), or the defaults without the file.
static func load_default() -> WallHopTuning:
	var res: Resource = load(PATH) if ResourceLoader.exists(PATH) else null
	return res as WallHopTuning if res is WallHopTuning else WallHopTuning.new()
