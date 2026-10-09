class_name DashWallTuning
extends Resource
## Dash walls (task H7a; GDD §9.14, owner, October 8, 2026: "walls the player can dash through ... blocking
## the path forward ... like a building in the middle of the street"): where the generator may stand one
## (scripts/enemies/dash_wall_rules.gd). How many a level asks for is its own LevelConfig.dash_walls; the
## wall's size is MovementTuning's ("Dash walls" group). Edit data/tuning/dash_walls.tres (F6: "Dash walls",
## in a level that has them; Restart level rebuilds). Times are seconds of run at the level's run speed, or
## at the dash's speed where they say so (the run speed plus PowerupTuning.dash_speed_bonus: the fastest a
## runner comes at or through a wall), so a faster zone keeps every one of them (GDD §3, Pace). Every number
## here is a first value for playtesting (DESIGN-TBD, docs/questions/h7a.md).

const PATH: String = "res://data/tuning/dash_walls.tres"

@export_group("Around a wall")
## Seconds before a wall's face, at the dash's speed, with nothing else in any lane (GDD §9.14: "nothing else
## that needs the dash comes just before one"): no hole or floor cut, fence, doodad, pad, ramp, speed pad,
## ceiling or landing zone, and no enemy's attack. The dash's own length (0.6 s): a dash started as the runner
## clears whatever comes before still lasts to the wall, and it's more than a reaction and a lane switch
## (0.35 s and 0.14 s, the reaction the suites' bots use, as task H5 measured for doodads).
@export_range(0.3, 2.0, 0.05, "suffix:s") var approach_seconds: float = 0.6
## Seconds past a wall's back, at the dash's speed, with nothing in any lane: what the wall hid shows only as
## it breaks (at its face), so the runner who bursts through has a reaction and a lane switch to see it and
## move, with the wall's own depth to spare.
@export_range(0.3, 2.0, 0.05, "suffix:s") var after_seconds: float = 0.6
## Seconds of run before a wall's face that at least one side wall stays open to run along until past the
## wall (GDD §9.14: "a player running on a side wall passes it"): no sign there on that wall (a sign blocks
## the entry and hurts), and no wall gap or wall fence on either (they come after the walls and keep off this
## stretch). Long enough to step onto the wall (MovementTuning.wall_entry_time, 0.16 s) after a reaction.
@export_range(0.0, 3.0, 0.05, "suffix:s") var wall_route_seconds: float = 0.6

@export_group("Spacing")
## Seconds added to the dash's longest cooldown (PowerupTuning: dash_cooldown and dash_upgrade_cooldowns, 8 s
## at tier 1) between one wall's face and the next one's (GDD §9.14, proposed: "walls are spaced so the dash's
## longest cooldown is always over before the next wall"): the time to see the dash is back and use it, and a
## speed pad's boost on the way. The distance also takes the extra ground a dash covers (its duration times its
## speed bonus).
@export_range(0.0, 5.0, 0.1, "suffix:s") var cooldown_margin_seconds: float = 1.0
## The same spacing keeps whatever else invites a dash from coming just before a wall (GDD §9.14): a Buzz
## Overdrive's charge (a panic dash smashes it, GDD §9.9) never meets the runner within it before a wall's
## face, and no fence generator stands there (its hint says to dash through it). A zone doodad isn't one: it
## never needs the dash (it only pushes the runner aside). Off: only the walls keep it.
@export var keep_dash_baits: bool = true

@export_group("Placement")
## A level that gives the feature a start (LevelConfig.feature_starts: Corporate 1, after the Buzz Overdrive's
## introduction) introduces it at the first fair spot from there; where none comes within this many seconds of
## run, it makes room for one there (dash_wall_rules.gd: taking out a few enemies, never the last of their kind
## nor another feature's introduction), so the player meets it right after its first-encounter hint.
@export_range(2.0, 30.0, 0.5, "suffix:s") var intro_window_seconds: float = 10.0
## Plain holes and fences (never a pulsing fence or one a fence generator powers) and signs on a side wall
## that stand where a wall would need clear track may be taken out to make room for it (taking content out
## never makes a level unfair); a spot that needs nothing taken out is preferred (but for the introduction,
## which takes the first fair spot from its start). Off: walls stand only where the track is clear already.
@export var clear_plain_pieces: bool = true
## The grid fronts are tried on (metres): finer finds a spot nearer the one aimed for, coarser is cheaper.
@export_range(0.25, 4.0, 0.25, "suffix:m") var search_step: float = 1.0


## The shared tuning (data/tuning/dash_walls.tres), or the defaults if it's missing.
static func load_default() -> DashWallTuning:
	var res: Resource = load(PATH) if ResourceLoader.exists(PATH) else null
	return res as DashWallTuning if res is DashWallTuning else DashWallTuning.new()


## The stretch wall entry `w` (LevelLayout.dash_walls) keeps clear in every lane: approach_seconds before its face
## to after_seconds past its back, at `dash_speed` (the level's run speed plus PowerupTuning.dash_speed_bonus).
## DashWallRules.footprint and CyborgRules.obstacle_spans (a panic cyborg cowers before it) use it.
func footprint(w: Dictionary, dash_speed: float) -> Vector2:
	return Vector2(float(w["start"]) - approach_seconds * dash_speed, float(w["end"]) + after_seconds * dash_speed)
