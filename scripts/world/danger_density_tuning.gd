extends Resource
## Pass-wide numbers for the danger density pass (scripts/world/danger_density.gd, the owner's request in
## docs/USER_REQUESTS.md: denser enemies and obstacles, a tighter open lane). Each level's own dial is
## LevelConfig.danger_density_increase; data/tuning/danger_density.tres holds these.

## Enemy types the pass may add (twins and new encounters). Only types whose generator rules filter or
## roll what's placed, which the pass applies to what it adds itself (the cyborg's obstacle margin and
## panic roll, the window cyborg's sign rule), or that have no rules (the Sewer Screech). Every other
## type's rules plan their own enemies (pads, ceilings, lanes, charges), so the pass never adds them.
@export var enemy_types: PackedStringArray = PackedStringArray(["cyborg", "screech", "window_cyborg"])
## Enemy types whose attack window an added enemy (twin or encounter) may overlap besides a twin's own
## group's (never a host): small threats a pattern of the level may already put together. Any other
## enemy's window, with the clearance around the addition, stays clear.
@export var twin_tolerated_types: PackedStringArray = PackedStringArray(["cyborg", "screech", "window_cyborg", "generator", "hover_truck", "tithe_collector"])
## How many attack windows of other enemies (all of twin_tolerated_types, never a host; a twin's own
## group apart) an added enemy's window, with the clearance around it, may overlap: 0 keeps every
## addition on its own, as the fill pass keeps its fillers.
@export_range(0, 4) var overlap_max: int = 2
## Random spots a new encounter tries in each stretch clear of fixed stretches and big attacks, per
## sweep (the enemy half sweeps the level while it still adds one).
@export_range(1, 16) var encounter_tries: int = 8
## A new encounter in a stretch a fill pass waiting this long would fill (nothing going on there for
## longer than this many seconds) leaves that long empty at both ends of it, so the fill pass still
## fills either side: one splitting it into two short ones would trade all its holes and fences for one
## enemy. The campaign levels' LevelConfig.fill_empty_seconds; the pass's own number, never the
## level's, so a level gets the same enemies with its fill pass off (tests/suites/test_pace.gd). 0
## spares nothing.
@export_range(0.0, 10.0, 0.1, "suffix:s") var spare_fill_seconds: float = 2.0
## Enemy types whose attack window a row the pass widens or adds may reach (never a host): their floor
## lane (a vent Screech's: the outer lane on its side) stays kept and never counts as open there. Any
## other enemy's window keeps the clearance (clearance_spacing_scale) from every added piece, and a
## full-width row stands clear of every enemy's.
@export var row_tolerated_types: PackedStringArray = PackedStringArray(["cyborg", "screech", "window_cyborg", "generator", "hover_truck", "tithe_collector"])
## Features whose lane-less keep-outs (their rules' doodad_keep_outs) the pass may still add enemies,
## holes and fences in, as the pattern and fill passes do: a host's chase stretch keeps the zone's
## doodads off (their sides and pushes could block the Bad Dream's way out), not what the passes
## place; the chase comes only if the player kills its host, and its slash takes turns with the other
## big attacks (EnemyDirector). Every other rule's keep-out (a Gilded Sentinel's turn) stays clear.
@export var keep_out_exempt_features: PackedStringArray = PackedStringArray(["host"])
## Lanes left open around everything the pass adds: every row it widens or adds (and every row near it)
## keeps this many lanes clear from the level's spacing before the row to the spacing after it, and
## every enemy it adds keeps this many lanes free of floor enemies, holes, fences and kept lanes while
## it attacks, with the clearance around it.
@export_range(1, 5) var min_free_lanes: int = 1
## The clear track kept around every row and encounter the pass adds or widens, as a share of the
## level's spacing between two patterns there (LevelGenerator.doodad_after): 1 keeps the pattern pass's
## own spacing, the fairness floor; more is stricter.
@export_range(1.0, 3.0, 0.05) var clearance_spacing_scale: float = 1.0
## Each level's dial (LevelConfig.danger_density_increase) times this is the share more enemies the
## pass aims for; 1 takes the dial as it is.
@export_range(0.0, 2.0, 0.05) var enemy_increase_scale: float = 1.0
## The same for floor pieces (holes and fences lane by lane, signs, floor cuts). Wall fences come later
## and aren't counted toward it.
@export_range(0.0, 2.0, 0.05) var obstacle_increase_scale: float = 1.0
## The same for wall fences (the wall half, DangerDensity.apply_wall_fences: more of them where the wall
## fences' own rules let one stand, after the level's own are placed); 0 adds none. The data asks more than
## the dial: the wall fences' own spacing leaves fewer fair spots than the dial asks for, so with 1.0 the final
## zones' wall fences rose only about 26% at 3 lanes, with 1.25 about 20% to 36% by lane count
## (tools/measure/danger_density.gd). DESIGN-TBD, 1.9 (task K5; docs/questions/k5.md, with open question 433):
## it adds wall fences only, 447 to 505 over the campaign levels' own builds (from Marketplace 2 on), as the owner
## finds every level too easy (docs/USER_REQUESTS.md); it makes no room the floor lacks. With the Enforcer Truck's
## showing windows (task C6e), which the pass's rows keep off, test_danger_density's 3-seed sample of the final
## zones at 3 lanes has 28.8% more obstacles at 1.25 and 30.6% at 1.9, over the band's 30% floor only with it;
## over 7 seeds (each level's own and 9001-9006) they have 30.2% and 31.9%, and their enemies 30.2% either way.
## Their own rules still decide every spot.
@export_range(0.0, 2.0, 0.05) var wall_fence_increase_scale: float = 1.0
## Whether a planned Resonator's attack is its pulses one by one (DangerDensity.resonator_pulse_windows:
## each from its warning until its last wave has passed the player, as the wall fences keep off them),
## the floor between two pulses taking what the pattern pass may put there; off, its whole visit (from
## its first pulse to its last wave). The data has it off: at run time a Resonator's pulses shift with
## the turns and floor waits it makes (tests/suites/test_resonator.gd), so a piece or enemy added
## between two planned pulses could meet a pulse; the bands still reach their targets without that room.
@export var resonator_per_pulse: bool = true
## Whether the holes and fences the pass adds get the credit pass's risky credits (a gap's edge credit
## and jump arc, a fence's): off, the pass adds danger, not pay, and the campaign's earnings curve
## (tests/suites/test_economy.gd, tools/measure/economy.gd) stays where the shop's prices were set.
@export var credit_added_pieces: bool = false
## Whether an isolated row one lane short of the full width may take its last lane, and the fill pass's
## full-width fillers may be added, where the level's own fillers include a full-width row there.
@export var full_width_rows: bool = true
## How many times the obstacle half goes through its levers (tighter rows, new rows, full rows) while
## it still adds something and the floor target isn't met.
@export_range(1, 8) var obstacle_rounds: int = 3
## Seconds at run speed between two spots where a new row may start (a grid through the clear track,
## tried in a seeded order).
@export_range(0.1, 2.0, 0.05, "suffix:s") var row_step_seconds: float = 0.5
## Whether the obstacle half, after its other levers, may stagger rows (a level with the fill pass only):
## one of the level's one-row fillers between two neighbouring rows less than the level's spacing apart,
## where the level would pick a two-row staggered filler (fence_stagger) there and no closer to either
## than that filler's rows stand, clear of every enemy's attack window with the clearance, its open
## lanes within stagger_max_shift_lanes of every open lane of the row before it and of the row after it
## (each row keeping min_free_lanes open lanes): the open lane may move, never vanish, as it does
## between the staggered filler's two rows. Off, every open lane stays put for the clearance around
## each row (the "too forgiving" open lane the owner asked to tighten).
@export var staggered_rows: bool = true
## The most lanes the open lane may move between two neighbouring rows a staggered row stands between:
## from any open lane of the row before, an open lane of the next this many lane switches away
## (MovementTuning.lane_switch_time each, which must fit in the staggered filler's spacing).
@export_range(0, 4) var stagger_max_shift_lanes: int = 1
## Whether the obstacle half, after its other levers, may route rows: a row takes one more lane of its
## piece (up to its widest filler there) clear of every other piece for routed_row_gap_seconds either
## side (the clearance with 0) and of kept stretches for the clearance, where no lane stays open for
## the whole clearance around it but the ground route holds: the row keeps min_free_lanes open lanes
## clear of kept stretches, reached from every open lane of the nearest row before it and leading to
## one of the row after it, any lane at the level's spacing (as between two of its patterns, whose
## lanes it picks afresh), within stagger_max_shift_lanes from the staggered filler's spacing, the same
## lane closer. Off, an open lane stays put around every row (lever 3 only).
@export var routed_rows: bool = true
## With routed_rows, the least clear track (seconds at run speed) a routed row keeps from every other
## piece in its lanes, and a routed new row from the spots either side of it: one of the level's
## one-row fillers (not full-width) in a gap between two neighbouring spots at least twice this wide,
## centred or this far from either spot, where the ground route holds as above (an open lane straight
## on, closer than the staggered filler's spacing; a full row passed in the lane the player comes to it
## in), again in the gaps it splits while one is wide enough. It never shortens
## a warning: every piece keeps its own, and the route rule decides the lane switches. 0 turns routed
## new rows off (routed rows then keep the clearance).
@export_range(0.0, 2.0, 0.05, "suffix:s") var routed_row_gap_seconds: float = 0.3
## Whether the enemy half, after its twins and encounters, may add Barnacle Turrets where the level's own
## turret rules let one hang (barnacle_turret_rules.gd: mount_lanes, off_credits, a second on a ceiling
## only where the level pairs them, spaced as they space them, at most two per ceiling), never on the
## ceiling of the level's first (its introduction) or before it. A turret fires only at a rider on its
## own ceiling, takes no floor and no turn from the big attacks.
@export var ceiling_turrets: bool = true
