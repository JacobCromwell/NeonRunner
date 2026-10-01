class_name SleepTakerTuning
extends Resource
## The Sleep Taker's numbers (GDD §10; data/bosses/dead_zone_boss_tuning.tres, F6 in its fight). Timings
## are at pace 1: each phase divides them by its BossPhase.pace (GDD §10: it gets hungrier each phase).
## Distances that stand for a time (marked "at 18 m/s": the refuges' spacing, the fairness margins, the
## generators' spacing) are written for the reference run speed (MovementTuning.REFERENCE_SPEED) and
## multiplied by the run's pace (MovementTuning.pace(), SleepTaker.run_pace()), so the fight keeps its
## seconds at any run speed (GDD §3: the run speed rises zone by zone, 24.2 m/s in the Dead Zone).
## Distances that are sizes or framing (where it looms, the mist's pool, hitboxes) stay as they are.
## The GDD fixes what it is (the Dead Zone's Bad Dreams fused into one colossal nightmare, dozens of
## maws, long clawed fingers), its three attacks and their warnings (the giant slash across three lanes
## after its maw opens with a shriek; grasping hands after purple mist pools in the lane, with
## whispering; lights out after a deep inhale), that the ceiling is safe, and that the arena is darker
## than normal but never pitch black. Every number here is a placeholder (DESIGN-TBD,
## docs/questions/e5c.md).

@export_group("Nightmare")
## DESIGN-TBD: its body fills the street between the walls, less this on each side, and its size
## follows the street's width (a whole nightmare drawn at REF_WIDTH, scaled uniformly within
## min_scale-max_scale, so its maws stay round): about 12 m tall over 3 lanes, 18 m over 5, 22 m
## over 6.
@export_range(0.0, 2.0, 0.05, "suffix:m") var street_margin: float = 0.5
@export_range(0.3, 1.0, 0.01) var min_scale: float = 0.62
@export_range(1.0, 2.0, 0.01) var max_scale: float = 1.2
## DESIGN-TBD: where it looms: its centre this far ahead of the runner, keeping pace, its vapour
## touching the street.
@export_range(10.0, 80.0, 0.5, "suffix:m") var hover_ahead: float = 26.0
## It leans toward the runner's side of the street (it fills the street, so only a little): this
## share of the runner's sideways position, at most drift_speed.
@export_range(0.0, 1.0, 0.05) var drift_share: float = 0.25
@export_range(0.0, 10.0, 0.25, "suffix:m/s") var drift_speed: float = 2.0

@export_group("Entrance")
## DESIGN-TBD: the first phase's intro (its BossPhase.intro_seconds): it rises out of the street this
## far ahead of the runner, from this deep, materializing as it comes up, then drifts in to hover_ahead.
@export_range(20.0, 150.0, 1.0, "suffix:m") var enter_ahead: float = 60.0
@export_range(0.0, 30.0, 0.5, "suffix:m") var enter_depth: float = 12.0

@export_group("Pattern")
## DESIGN-TBD: each phase's attacks, a comma-separated list taken in order and repeated ("hands",
## "lights_out"); the first that can start fairly goes next. The giant slash isn't in the lists: it
## comes at every refuge (below). GDD §10: hungrier each phase (faster hands, more lights out), so the
## later lists hold more lights_out and their phases a higher pace.
@export var attack_patterns: PackedStringArray = PackedStringArray([
	"hands,hands,lights_out,hands,hands,hands",
	"hands,lights_out,hands,hands,hands,lights_out",
	"hands,lights_out,hands,lights_out,hands,hands",
])
## Seconds between one attack's end (its hazard has passed the runner) and the next one's warning.
@export_range(0.0, 5.0, 0.05, "suffix:s") var attack_gap: float = 1.3
## The first attack comes this long after the pattern begins.
@export_range(0.0, 10.0, 0.1, "suffix:s") var first_attack_delay: float = 1.5

@export_group("Refuges")
## DESIGN-TBD (GDD §10: "it can't reach the ceiling, so anti-grav pads are the refuge from the big
## slashes"): a charred bridge across the street (the Dead Zone's ceiling look) with pads before it
## stands every refuge_spacing metres of each lap from refuge_first on, and the giant slash comes at
## each one, timed to strike while a runner who took its pad rides the ceiling. A three-lane slash
## covers the whole street at 3 lanes, so this is how the mobile runner always has an escape. Both at
## 18 m/s (multiplied by the run's pace).
@export_range(60.0, 1000.0, 5.0, "suffix:m") var refuge_first: float = 200.0
@export_range(120.0, 1000.0, 5.0, "suffix:m") var refuge_spacing: float = 240.0
## How long the bridge's ceiling lasts past its pads, at run speed.
@export_range(1.5, 6.0, 0.1, "suffix:s") var refuge_seconds: float = 2.4
## DESIGN-TBD: off: pads in the middle lane (both middle lanes at an even lane count), at most one lane
## switch away at 3 lanes and two at 5 and 6, so taking the refuge is a choice; on: a pad in every lane
## (a runner can't miss one unless they jump it).
@export var refuge_pads_every_lane: bool = false

@export_group("Giant slash")
## DESIGN-TBD: the warning: its great maw opens with its shriek, the lanes it will slash light up in
## enemy-attack red (filling toward the runner) and its claws heat up; then it lunges. The lanes are
## locked when the warning starts, so leaving them any time during it dodges the slash.
@export_range(0.5, 4.0, 0.05, "suffix:s") var slash_telegraph: float = 1.6
@export_range(0.1, 1.0, 0.01, "suffix:s") var slash_lunge: float = 0.3
## The claws are live this long at the runner's spot, then it pulls back over slash_recover.
@export_range(0.05, 0.5, 0.01, "suffix:s") var slash_active: float = 0.15
@export_range(0.1, 3.0, 0.05, "suffix:s") var slash_recover: float = 0.9
## DESIGN-TBD: the strike lands this long after a runner reaches the refuge's pads, so one who took a
## pad is up on the ceiling by then (its lift takes about 0.45 s); the warning starts slash_warning()
## before the strike, so a runner reacting then has the warning less this to reach a pad's lane.
@export_range(0.5, 2.0, 0.05, "suffix:s") var strike_after_pad: float = 0.8
## A slash held up (an attack still on, the runner down) may still start this long after its moment.
@export_range(0.0, 1.0, 0.05, "suffix:s") var slash_late: float = 0.25
## GDD §10: across three lanes: the runner's and the lanes on either side, kept within the street (at
## an edge it covers the three outermost lanes; at 3 lanes, the whole street).
@export_range(1, 5) var slash_lanes: int = 3
## The slash's damage box (GDD §3: slightly smaller than what's shown): the covered lanes less
## side_margin at an edge next to a free lane and less wall_clearance at the street's edge (a wall
## runner is never touched), from the floor to slash_height (above a jump's reach: only leaving the
## lanes or the ceiling dodges it), slash_depth along the track at the runner's spot.
@export_range(1.0, 5.0, 0.05, "suffix:m") var slash_height: float = 2.3
@export_range(0.0, 1.0, 0.05, "suffix:m") var side_margin: float = 0.2
@export_range(0.0, 1.5, 0.05, "suffix:m") var wall_clearance: float = 0.9
@export_range(0.5, 4.0, 0.1, "suffix:m") var slash_depth: float = 2.0
## Lunging, its claws' tips come to this far in front of the runner (its body follows them in).
@export_range(0.0, 10.0, 0.25, "suffix:m") var lunge_gap: float = 1.5

@export_group("Grasping hands")
## DESIGN-TBD: the warning: purple mist pools in the runner's lane ahead, with whispering, where the
## runner will be once it has shown mist_seconds and the hand has been up hand_rise_lead; the hand
## bursts up out of the mist as the runner comes within hand_rise_lead of it. One lane switch dodges it.
@export_range(0.5, 3.0, 0.05, "suffix:s") var mist_seconds: float = 1.2
@export_range(0.0, 1.5, 0.05, "suffix:s") var hand_rise_lead: float = 0.45
@export_range(0.05, 1.0, 0.01, "suffix:s") var hand_rise_seconds: float = 0.2
## Once the runner is past it, it grasps a moment longer, then sinks back into the mist.
@export_range(0.0, 3.0, 0.05, "suffix:s") var hand_linger: float = 0.5
## The mist's pool along the lane, centred on the hand.
@export_range(2.0, 20.0, 0.5, "suffix:m") var mist_length: float = 7.0
## The hand's damage box (GDD §3: a little smaller than the hand): this share of a lane wide, from
## the floor to hand_height (above a jump's reach: only a lane switch dodges it), hand_depth along it.
@export_range(0.2, 1.0, 0.02) var hand_width_share: float = 0.62
@export_range(1.0, 4.0, 0.05, "suffix:m") var hand_height: float = 2.6
@export_range(0.5, 4.0, 0.1, "suffix:m") var hand_depth: float = 1.6
## Fairness: a hand only rises where its lane's floor is clear of holes and fences this far before and
## after it, and only while a lane at most max_escape_lanes away is clear from the runner to
## escape_clear_after past the hand (the slash's escape keeps that much clear past its strike too). All
## three at 18 m/s (multiplied by the run's pace).
@export_range(0.0, 20.0, 0.5, "suffix:m") var hand_clear_before: float = 6.0
@export_range(0.0, 20.0, 0.5, "suffix:m") var hand_clear_after: float = 4.0
@export_range(0.0, 30.0, 0.5, "suffix:m") var escape_clear_after: float = 6.0
@export_range(1, 3) var max_escape_lanes: int = 1

@export_group("Generators and the lure")
## DESIGN-TBD (GDD §10: "glowing fence generators stand along the route. The player lures it close
## (it lunges toward them), then destroys the generator with a stomp or the dash; the EMP rips a chunk
## of the nightmare away"; "a missed generator is followed by another"): one generator at a time, in
## sight generator_sight ahead (at 18 m/s), in a lane whose floor is clear generator_clear_before it to
## generator_clear_after past it (at 18 m/s), away from the refuges' slashes and from ceilings. A
## phase's first comes generator_delay into its pattern; after a miss, the next generator_again later.
@export_range(0.0, 60.0, 0.5, "suffix:s") var generator_delay: float = 6.0
@export_range(0.0, 60.0, 0.5, "suffix:s") var generator_again: float = 2.0
@export_range(40.0, 300.0, 5.0, "suffix:m") var generator_sight: float = 110.0
@export_range(10.0, 80.0, 1.0, "suffix:m") var generator_clear_before: float = 30.0
@export_range(2.0, 30.0, 1.0, "suffix:m") var generator_clear_after: float = 8.0
## DESIGN-TBD: the lure: lure_seconds before the runner reaches a generator, the nightmare lunges toward
## them over lure_lunge_seconds (with its hungry roar), reaching for them, and holds there, its claws
## lure_gap in front of them, until they're lure_release past the generator (at 18 m/s); then it pulls
## back to hover over lure_back_seconds. It doesn't attack while lured.
@export_range(1.0, 8.0, 0.1, "suffix:s") var lure_seconds: float = 3.0
@export_range(0.1, 2.0, 0.05, "suffix:s") var lure_lunge_seconds: float = 0.6
@export_range(0.5, 10.0, 0.25, "suffix:m") var lure_gap: float = 3.5
@export_range(0.0, 20.0, 0.5, "suffix:m") var lure_release: float = 6.0
@export_range(0.2, 3.0, 0.05, "suffix:s") var lure_back_seconds: float = 1.0
## DESIGN-TBD: close enough: a generator's EMP tears a chunk away when its centre is within this far
## (along the street) of the nightmare's middle; while it is, arcs crackle from the generator into it.
## Lured, it's lure_gap plus its claws' reach (8-12 m) ahead of the runner; hovering, hover_ahead.
@export_range(4.0, 40.0, 0.5, "suffix:m") var emp_reach: float = 18.0

@export_group("Defeat")
## DESIGN-TBD (GDD §10: "the last EMP bursts it into hundreds of wisps, each a faint face or figure that
## drifts upward and fades as the dreams are released. Then silence, and the first grey dawn light breaks
## over the Dead Zone"): wisp_count wisps burst out of it as it dissolves and rise for wisp_seconds; the
## music fades out over silence_fade (no victory riff); dawn_delay after the burst the sky and the light
## turn to a grey dawn over dawn_seconds (the sky's zenith, horizon and haze colours, the fog's colour,
## and the light: dawn_light times the zone's own, never darker than it). The fight's results follow
## once the dawn has broken.
@export_range(50, 600, 10) var wisp_count: int = 260
@export_range(1.0, 10.0, 0.25, "suffix:s") var wisp_seconds: float = 4.5
@export_range(0.0, 6.0, 0.1, "suffix:s") var silence_fade: float = 2.0
@export_range(0.0, 6.0, 0.1, "suffix:s") var dawn_delay: float = 1.8
@export_range(0.5, 10.0, 0.1, "suffix:s") var dawn_seconds: float = 3.2
@export_range(1.0, 2.5, 0.05) var dawn_light: float = 1.25
@export var dawn_zenith: Color = Color(0.28, 0.3, 0.35)
@export var dawn_horizon: Color = Color(0.52, 0.5, 0.5)
@export var dawn_haze: Color = Color(0.64, 0.6, 0.58)
@export var dawn_fog: Color = Color(0.42, 0.41, 0.41)

@export_group("Lights out")
## DESIGN-TBD: the warning: a deep inhale (every maw opens, the street's light streams into them) for
## inhale_seconds, then the light sinks to dark_level (of the arena's own light: BossEncounter.
## set_light_level, never below BossEncounter.MIN_LIGHT_LEVEL) over dim_seconds and stays dark for
## dark_seconds while hands and slashes keep coming; then it breathes out and the light comes back over
## return_seconds. Glowing things (hazards, warnings, pads, the generators) keep their colours.
@export_range(0.5, 4.0, 0.05, "suffix:s") var inhale_seconds: float = 2.0
@export_range(0.1, 3.0, 0.05, "suffix:s") var dim_seconds: float = 0.8
@export_range(0.3, 1.0, 0.01) var dark_level: float = 0.45
@export_range(1.0, 30.0, 0.5, "suffix:s") var dark_seconds: float = 8.0
@export_range(0.2, 5.0, 0.1, "suffix:s") var return_seconds: float = 1.6


## Seconds from the slash's warning to its claws striking.
func slash_warning() -> float:
	return slash_telegraph + slash_lunge


## The phase's attack list (the last phase's for any later one; the first's if a phase has none).
func pattern_for(phase: int) -> PackedStringArray:
	if attack_patterns.is_empty():
		return PackedStringArray(["hands"])
	var line: String = attack_patterns[clampi(phase, 0, attack_patterns.size() - 1)]
	var out := PackedStringArray()
	for part: String in line.split(",", false):
		var kind: String = part.strip_edges()
		if kind != "":
			out.append(kind)
	return out if not out.is_empty() else PackedStringArray(["hands"])
