class_name GantrywayTuning
extends Resource
## Falling gantryways (task Q3; GDD §5, Zone 9, the owner, October 21, 2026: "an upper walkway over one lane only, looking
## like a ceiling section"; "pillars stand in the floor lanes holding them up. Dashing through a pillar knocks down its long
## section of gantryway"; "it takes about a second to fall. When it lands, it destroys any enemy in its path"; "a runner
## under it when it lands is hit"): where the generator may stand one (scripts/enemies/gantryway_rules.gd), and how one
## falls (Gantryway, scripts/world/gantryway.gd). How many a level asks for is its own LevelConfig.gantryways. Edit
## data/tuning/gantryways.tres (F6: "Gantryways", in a level that has them; Restart level rebuilds). Times are seconds of
## run at the level's run speed, or at the fastest a runner can come through a pillar where they say so (the run speed
## plus PowerupTuning.dash_speed_bonus and the most a speed pad's or a ramp's boost adds: GantrywayRules.fastest), so a
## faster zone keeps every one of them (GDD §3, Pace). Every number here is a first value for playtesting (DESIGN-TBD,
## docs/questions/q3.md).

const PATH: String = "res://data/tuning/gantryways.tres"

@export_group("The walkway")
## Seconds of run its walkway spans along its lane (GDD §5: "moderate in length: a little shorter than ceiling sections
## usually are"; the patterns' ceilings run about 4 s). Longer than a runner who stays in its lane covers while it falls
## (fall_seconds at the fastest), so staying in the lane is staying under it (GDD §5, proposed: "they switch lanes inside
## that second, or are hit").
@export_range(1.5, 6.0, 0.1, "suffix:s") var length_seconds: float = 3.0
## Its walkway's depth (metres), the box that falls: what its hitbox spans top to bottom (less hitbox_inset), and what
## the look fills.
@export_range(0.2, 1.2, 0.05, "suffix:m") var deck_thickness: float = 0.5

@export_group("The fall")
## Seconds from its pillar breaking to its walkway landing (GDD §5: "it takes about a second to fall"). The warning plays
## for all of it (warning_seconds of shudder before it drops), and a runner who dashed the pillar has that long to leave
## the lane: more than a reaction and a lane switch (0.35 s and 0.14 s, the suites' bots) at every setting this allows.
@export_range(0.7, 2.0, 0.05, "suffix:s") var fall_seconds: float = 1.0
## Seconds of that, from the pillar breaking, that the walkway holds on, shuddering, groaning and shedding snow, before
## it drops (GDD §5, proposed: "before it drops, it warns as every attack must"); the rest it falls, faster and faster.
## Its shadow darkens on the lane and the lane's red warning light deepens over the whole fall.
@export_range(0.1, 1.2, 0.05, "suffix:s") var warning_seconds: float = 0.45
## How far (metres) the walkway sags on its broken end as the pillar goes, before it drops.
@export_range(0.0, 1.0, 0.05, "suffix:m") var sag: float = 0.3
## How far (metres) the walkway shakes while it shudders, and how fast (shakes a second). With Reduced flashing it
## doesn't shake (a fast shake is a flicker of motion): it only lurches down by `sag` and holds still.
@export_range(0.0, 0.3, 0.01, "suffix:m") var shudder_amplitude: float = 0.08
@export_range(4.0, 40.0, 1.0, "suffix:Hz") var shudder_hz: float = 18.0
## How much smaller its falling hitbox is than its look, across its lane and at each end (forgiving, CLAUDE.md
## principle 4: damage only on actual contact, the hitbox a little smaller than what's drawn).
@export_range(0.0, 0.6, 0.01, "suffix:m") var hitbox_inset: float = 0.2
## Its shadow on its lane at its darkest, as it lands (black's alpha; lighter on the Compatibility renderer, which blends
## in sRGB: Gantryway.shadow_alpha_for).
@export_range(0.1, 0.95, 0.05) var shadow_darkness: float = 0.6
## How hard the camera shakes as it lands, and for how long (RunEffects.shake; Screen shake scales it): a heavy crash
## beside the runner, a little short of a dash wall crumbling through them.
@export_range(0.0, 1.0, 0.01) var land_shake_strength: float = 0.22
@export_range(0.05, 1.0, 0.01, "suffix:s") var land_shake_seconds: float = 0.3

@export_group("Getting out from under it")
## Seconds past its landing, at the fastest a runner comes through its pillar, that the lane a runner who dashed the
## pillar steps into holds nothing (no hole, fence, pad, doodad or enemy, and no attack in any lane): they land in it
## and have this long to see what comes next. The fall and this make the gantryway's calm stretch (GantrywayRules
## .calm_length), which every lane keeps quiet.
@export_range(0.2, 2.0, 0.05, "suffix:s") var escape_after_seconds: float = 0.5
## The level's first gantryway (where it gives the feature a start: its introduction) keeps both lanes beside it clear
## for the whole calm stretch, not only the one its pillar pushes into: room to step out either way (an easy first one,
## task Q3's brief; DESIGN-TBD, docs/questions/q3.md).
@export var intro_both_sides: bool = true

@export_group("The enemy beneath")
## A plain cyborg stands under each gantryway (GDD §5, Zone 9: "it destroys any enemy in its path"; its level schedule
## row: "dash a pillar to drop a one-lane walkway on the enemies below"; one under every gantryway is task Q3's proposal,
## DESIGN-TBD docs/questions/q3.md), where a runner who stays in the lane meets it only after the walkway has landed:
## crush_margin_seconds past the fastest runner's spot at the landing, and the same (at run speed) before the walkway's far
## end. It stands where it's put and holds its fire from hold_before_seconds before the runner reaches the pillar until
## the calm stretch is over (CyborgGun.hold), so the dash and the step out are never shot at. Off: none is planted.
@export var plant_cyborg: bool = true
@export_range(0.0, 1.0, 0.05, "suffix:s") var crush_margin_seconds: float = 0.2
@export_range(0.0, 5.0, 0.1, "suffix:s") var hold_before_seconds: float = 2.0

@export_group("Placement")
## Seconds of run between two gantryways' pillars at the least.
@export_range(4.0, 60.0, 0.5, "suffix:s") var spacing_seconds: float = 12.0
## A level that gives the feature a start (LevelConfig.feature_starts: Frost Foundry) introduces it at the best fair
## spot within this many seconds of run from there (the one taking the fewest plain pieces out, then the earliest), so
## the player meets it right after its first-encounter hint: within the reach every introduction keeps from its start
## (test_campaign's INTRODUCTION_REACH, 210 m at 18 m/s, about 11.7 s). DESIGN-TBD (docs/questions/q3.md 12): the
## introduction, Frost Foundry's from 0.15 of the level (its feature_starts).
@export_range(2.0, 40.0, 0.5, "suffix:s") var intro_window_seconds: float = 11.5
## Plain holes and fences (never a pulsing fence or one a fence generator powers) that stand where a gantryway needs
## clear floor may be taken out to make room for it (taking content out never makes a level unfair); a spot that needs
## nothing taken out is preferred. Off: gantryways stand only where the floor is clear already.
@export var clear_plain_pieces: bool = true
## The grid pillars' fronts are tried on (metres): finer finds a spot nearer the one aimed for, coarser is cheaper.
@export_range(0.25, 4.0, 0.25, "suffix:m") var search_step: float = 1.0


## The shared tuning (data/tuning/gantryways.tres), or the defaults if it's missing.
static func load_default() -> GantrywayTuning:
	var res: Resource = load(PATH) if ResourceLoader.exists(PATH) else null
	return res as GantrywayTuning if res is GantrywayTuning else GantrywayTuning.new()


## Seconds of the fall it holds on, shuddering, before it drops: warning_seconds, never more than fall_seconds leaves a
## drop of a tenth of a second.
func hold_seconds() -> float:
	return clampf(warning_seconds, 0.0, maxf(fall_seconds - 0.1, 0.0))


## Seconds of the fall it drops for (fall_seconds less the hold).
func drop_seconds() -> float:
	return maxf(fall_seconds - hold_seconds(), 0.05)
