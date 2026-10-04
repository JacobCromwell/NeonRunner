class_name TheHouseTuning
extends Resource
## The House's numbers (GDD §10; data/bosses/marketplace_boss_tuning.tres, F6 in its fight). Timings are
## at pace 1: each phase divides them by its BossPhase.pace. Distances that stand for a time (marked "at
## 18 m/s": the buttons' depth, the stomp box's depth, the fairness margins, the fountain's spread) are
## written for the reference run speed (MovementTuning.REFERENCE_SPEED) and multiplied by the run's pace
## (TheHouse.run_pace()), so the fight keeps its seconds at the Marketplace's 22.6 m/s; where an attack or
## a button lands is a time (its warning) times the run speed. Sizes, heights and where the machine stands
## (framing) stay as they are.
## The GDD fixes what it is (a slot machine the size of a building, rolling down the market street on
## treads), the spin (it yanks its lever and three reels stop one at a time, each with a ding, over about
## 2 seconds), the three symbols and their attacks (cherry bombs with target circles, a pink fence rolled
## across some lanes, gold blocks slammed into lanes; two or three of a kind a bigger version), the 7
## buttons that lock their reels on 7, the jackpot (sirens, a fountain of real credits, the hopper bursting
## open on top as a red weak point while it sags low, stomped), three phases and the standard armor rule.
## Every number here is a placeholder (DESIGN-TBD: docs/OPEN_QUESTIONS.md items 299-303,
## docs/questions/e5a.md).
## Campaign difficulty overrides live in marketplace_boss_tuning.tres: three attack-only spins per phase,
## less space between attacks/spins and wider single cherry/lightning attacks. Warning times, the
## route check's reaction/margins, persistent 7 locks, wall/ceiling holds and the hopper window stay intact.
## The slot's par times include the additional attack-only spin in each phase.

@export_group("Machine")
## DESIGN-TBD: its cabinet fills the street between the walls less this on each side; it stands
## `height` tall (under the Marketplace's cables slung across the street, 14.4 m at their lowest) and
## at least `depth` long along the street (its tread chassis; longer when the stomp box needs it,
## TheHouseBody.depth_for).
@export_range(0.0, 2.0, 0.05, "suffix:m") var street_margin: float = 0.35
@export_range(6.0, 14.0, 0.25, "suffix:m") var height: float = 13.5
@export_range(6.0, 30.0, 0.5, "suffix:m") var depth: float = 14.0
## DESIGN-TBD: where it paces: its face this far ahead of the runner (framing, kept in metres: tier 1's
## shots reach 42 m), or further at a faster run, so every attack lands between it and the runner
## (TheHouse.stand_distance: the longest warning at the run speed plus stand_margin).
@export_range(20.0, 80.0, 0.5, "suffix:m") var stand_ahead: float = 40.0
@export_range(0.0, 20.0, 0.5, "suffix:m") var stand_margin: float = 5.0

@export_group("Entrance")
## DESIGN-TBD: the first phase's intro (its BossPhase.intro_seconds): it rolls in from this far ahead,
## lights blazing and jingling, and brakes to where it paces.
@export_range(40.0, 200.0, 1.0, "suffix:m") var enter_ahead: float = 130.0

@export_group("The spin")
## DESIGN-TBD: the warning (GDD §10: "it yanks its giant lever. Three huge reels on its chest spin and
## stop one at a time, each with a ding, over about 2 seconds"): the lever's pull, then the reels spin
## and stop at these times after the pull (a spin with buttons: as the runner passes each button).
@export_range(0.1, 1.5, 0.05, "suffix:s") var lever_seconds: float = 0.5
@export var reel_stop_seconds: PackedFloat32Array = PackedFloat32Array([0.85, 1.4, 1.95])
## DESIGN-TBD: what each spin of each phase shows, a list taken in order and repeated: each entry is three
## symbols in reel order ("cherry", "lightning", "bar"; two or three of a kind make a bigger attack).
## A reel locked on 7 shows 7 instead and brings no attack.
@export var spin_patterns: PackedStringArray = PackedStringArray([
	"cherry,bar,lightning|bar,bar,cherry|lightning,cherry,bar|cherry,cherry,cherry|bar,lightning,lightning|bar,bar,bar|lightning,lightning,lightning|cherry,lightning,bar",
	"bar,cherry,cherry|lightning,bar,cherry|cherry,cherry,cherry|bar,bar,lightning|lightning,lightning,lightning|cherry,bar,bar|bar,bar,bar|lightning,cherry,lightning",
	"cherry,cherry,bar|bar,bar,bar|lightning,bar,cherry|cherry,cherry,cherry|lightning,lightning,bar|bar,cherry,lightning|lightning,lightning,lightning|cherry,bar,cherry",
])
## DESIGN-TBD: each phase opens with this many spins without buttons (only attacks), so the fight lasts
## about as long as a level (GDD §10: 60-120 s); every spin after them offers buttons.
@export var opening_spins: PackedInt32Array = PackedInt32Array([2, 2, 2])
## The first spin comes this long after a phase's pattern begins.
@export_range(0.0, 5.0, 0.05, "suffix:s") var first_spin_delay: float = 0.8
## After the reels stop, the first attack's warning comes this long later; each later attack's this
## long after the one before began (they may overlap: the routes through them are checked together).
@export_range(0.0, 2.0, 0.05, "suffix:s") var result_pause: float = 0.25
@export_range(0.2, 3.0, 0.05, "suffix:s") var attack_gap: float = 0.95
## The next lever pull comes this long after a spin's last warning began.
@export_range(0.2, 5.0, 0.05, "suffix:s") var spin_gap: float = 1.25
## A strike that can't land fairly now waits for a fair moment up to this long, then is left out.
@export_range(0.0, 3.0, 0.05, "suffix:s") var strike_wait: float = 1.0

@export_group("The 7 buttons")
## DESIGN-TBD (GDD §10: "while the reels spin, big glowing 7 buttons appear along the route. Running
## over one locks its reel on 7"): in a spin with buttons, each unlocked reel gets one, in reel order: the
## runner reaches the first button_first after the lever's pull and each next one button_spacing later;
## each lights up button_lead before the runner gets to it. Its reel stops as the runner passes it: on 7 if
## they ran over it, on its symbol if not.
@export_range(0.5, 4.0, 0.05, "suffix:s") var button_first: float = 1.35
@export_range(0.3, 2.0, 0.05, "suffix:s") var button_spacing: float = 0.65
@export_range(0.6, 3.0, 0.05, "suffix:s") var button_lead: float = 1.35
## DESIGN-TBD: a button lies at most this many lanes from the one before (from the runner's lane for the
## first), and never in the same lane as the one before (so rigging the machine takes some running).
@export_range(1, 5) var button_max_shift: int = 2
@export var button_same_lane: bool = false
## DESIGN-TBD: a locked reel stays on 7 until the jackpot (later spins only offer buttons for the reels
## still spinning); off: all three in one spin.
@export var locks_persist: bool = true
## A button's size: its share of a lane's width (a disc), and the stretch along the lane where running
## over it counts (at 18 m/s); a runner counts as on it below button_reach_height.
@export_range(0.4, 1.0, 0.02) var button_width_share: float = 0.84
@export_range(1.0, 6.0, 0.1, "suffix:m") var button_depth: float = 2.6
@export_range(0.3, 2.0, 0.05, "suffix:m") var button_reach_height: float = 1.1

@export_group("Cherry")
## DESIGN-TBD (GDD §10: "cherry bombs lobbed into lanes, with target circles on the floor (the Floating
## Head's bomb warning)"): each volley's target circles show cherry_warning before the runner would reach
## them; the bombs, lobbed from its coin chute, land and blow as the runner would get there
## (arrival_seconds early), burning blast_seconds. One cherry: one volley; two: two volleys; three:
## three, volley_gap apart. A volley strikes cherry_lanes lanes (by lane count 3, 5 and 6; the bigger
## versions one more at 5 and 6 lanes), always leaving an escape.
@export_range(0.6, 3.0, 0.05, "suffix:s") var cherry_warning: float = 1.25
@export_range(0.0, 0.3, 0.01, "suffix:s") var arrival_seconds: float = 0.1
@export_range(0.1, 1.0, 0.05, "suffix:s") var blast_seconds: float = 0.3
@export_range(0.2, 1.5, 0.05, "suffix:s") var volley_gap: float = 0.6
@export var cherry_lanes: PackedInt32Array = PackedInt32Array([2, 2, 3])
@export_range(0.5, 2.0, 0.05, "suffix:m") var blast_radius: float = 1.1
## The blast's hitbox (GDD §3: a little smaller than the fireball): its share of a lane's width, its
## depth along the track and its height (above a jump's reach: leaving the lane dodges it).
@export_range(0.3, 1.0, 0.05) var blast_width_share: float = 0.7
@export_range(0.5, 3.0, 0.05, "suffix:m") var blast_depth: float = 1.9
@export_range(1.0, 4.0, 0.1, "suffix:m") var blast_height: float = 2.4

@export_group("Lightning")
## DESIGN-TBD (GDD §10: "a pink electric fence rolled across some lanes (normal fence rules)"): a fence
## across fence_lanes lanes (by lane count 3, 5 and 6) rolls out of a spool across the street, flickering
## harmlessly with its crackle from fence_warning before the runner would reach it until fence_on_lead
## before, then it's on. Jump it, or take a lane it doesn't cover. Two of a kind: across every lane but
## one. Three: two rows across every lane, a full-height one to jump and a gapped one to slide under,
## fence_row_gap apart.
@export_range(0.6, 3.0, 0.05, "suffix:s") var fence_warning: float = 1.5
@export_range(0.2, 1.5, 0.05, "suffix:s") var fence_on_lead: float = 0.7
@export var fence_lanes: PackedInt32Array = PackedInt32Array([1, 2, 3])
@export_range(0.5, 2.5, 0.05, "suffix:s") var fence_row_gap: float = 1.0

@export_group("BAR")
## DESIGN-TBD (GDD §10: "heavy gold blocks slammed down into lanes; switch around them"): each row's
## lanes light up red bar_warning before the runner would reach it, the blocks fall from high above and
## slam down bar_slam_lead before the runner gets there; solid (deadly to run into, solid to switch
## into). A row blocks bar_lanes lanes (by lane count 3, 5 and 6; the bigger versions one more at 5 and 6
## lanes), always leaving a way through; two of a kind: two rows, three: three, row_gap apart.
@export_range(0.6, 3.0, 0.05, "suffix:s") var bar_warning: float = 1.4
@export_range(0.3, 1.5, 0.05, "suffix:s") var bar_slam_lead: float = 0.75
@export_range(0.3, 1.5, 0.05, "suffix:s") var row_gap: float = 0.7
@export var bar_lanes: PackedInt32Array = PackedInt32Array([2, 3, 4])
## A block's size: its share of a lane's width, its height (too tall to jump) and its depth.
@export_range(0.5, 1.0, 0.02) var block_width_share: float = 0.86
@export_range(1.8, 4.0, 0.1, "suffix:m") var block_height: float = 2.4
@export_range(0.8, 4.0, 0.1, "suffix:m") var block_depth: float = 1.8

@export_group("Jackpot")
## DESIGN-TBD (GDD §10: "sirens go off, the machine overloads and sprays a fountain of real credits to
## grab, and its coin hopper bursts open on top as a glowing red weak point while it sags low. The player
## stomps it."): it stalls where it is (further on if something of its last attack still lies in the
## way), and over sag_seconds sinks into the street until its top is deck_height above it, a deck the
## runner steps onto, its hopper open in it, glowing red, across the street; the stomp box covers the
## hopper, stomp_depth long (at 18 m/s), from a little under the deck to stomp_top above it. Jump onto it
## (from the street, or from the deck: the box is longer than a jump). Once the runner has passed the box
## without a stomp, or stomped it, it lurches ahead (lurch_speed faster than the runner) out from under
## them and rises back to where it paces over recover_seconds.
@export_range(0.2, 3.0, 0.05, "suffix:s") var sag_seconds: float = 0.9
@export_range(0.1, 0.6, 0.05, "suffix:m") var deck_height: float = 0.35
@export_range(4.0, 24.0, 0.5, "suffix:m") var stomp_depth: float = 12.0
@export_range(0.1, 1.0, 0.05, "suffix:m") var stomp_top: float = 0.35
## The hopper's box starts this far behind the machine's face (its top's front edge), and the deck runs
## on this far past the box's end.
@export_range(0.0, 4.0, 0.25, "suffix:m") var stomp_front_margin: float = 1.0
@export_range(1.0, 8.0, 0.25, "suffix:m") var deck_back_margin: float = 3.0
## Its approach stays clear: it stalls only where the last attack's hazards end at least this far (at
## 18 m/s) before its face.
@export_range(0.0, 40.0, 0.5, "suffix:m") var approach_clear: float = 18.0
## DESIGN-TBD: it stalls where the runner reaches its face this long after the JACKPOT (at any speed:
## the window keeps its seconds), or further if it's already further off.
@export_range(1.5, 6.0, 0.1, "suffix:s") var jackpot_approach: float = 2.6
@export_range(4.0, 40.0, 0.5, "suffix:m/s") var lurch_speed: float = 16.0
@export_range(0.5, 6.0, 0.1, "suffix:s") var recover_seconds: float = 1.8
## DESIGN-TBD: the fountain: fountain_count credits (every fountain_rich_every-th worth 25, the rest
## 5) burst out of the hopper as it opens and land over the street between the runner and the machine,
## from fountain_near to fountain_far ahead of the runner (at 18 m/s), after fountain_flight seconds.
@export_range(0, 60) var fountain_count: int = 18
@export_range(0, 20) var fountain_rich_every: int = 6
@export_range(0.2, 3.0, 0.05, "suffix:s") var fountain_flight: float = 0.9
@export_range(5.0, 40.0, 0.5, "suffix:m") var fountain_near: float = 14.0
@export_range(10.0, 60.0, 0.5, "suffix:m") var fountain_far: float = 30.0

@export_group("Phases 2 and 3")
## DESIGN-TBD (GDD §10: "three phases, with the buttons getting harder to reach, as the Marketplace's final
## exam: (1) all three on the floor; (2) one on a wall, with wall fences in play; (3) one on a ceiling
## reached by an anti-grav pad, guarded by Barnacle Turrets"): where each phase puts special_reel's button
## ("floor", "wall" or "ceiling"); the other reels' stay on the floor. A locked reel keeps its 7
## (locks_persist), so a phase's special button is run over once.
@export var special_buttons: PackedStringArray = PackedStringArray(["floor", "wall", "ceiling"])
@export_range(0, 2) var special_reel: int = 2

@export_group("Wall button")
## DESIGN-TBD: a wall button stands on a side wall's facade, its middle wall_button_height up, as tall as
## the wall-run path (wall_button_size) and wall_button_length along the wall (at 18 m/s): a wall runner
## passing it at any height runs over it. The runner reaches it wall_extra later than a floor button in its
## place; it lights up wall_lead before. Its plan has the runner onto the wall wall_entry_before it (any
## entry from a wall run's length before it works) and back in the outer lane wall_after past it; a wall
## fence on its wall between the entry and the button is off as the runner passes it, with
## fence_pass_margin either side.
@export_range(0.0, 2.0, 0.05, "suffix:s") var wall_extra: float = 0.7
@export_range(0.6, 3.0, 0.05, "suffix:s") var wall_lead: float = 1.6
@export_range(0.3, 1.8, 0.05, "suffix:s") var wall_entry_before: float = 0.8
@export_range(0.3, 2.5, 0.05, "suffix:s") var wall_after: float = 1.1
@export_range(1.0, 8.0, 0.1, "suffix:m") var wall_button_length: float = 4.0
@export_range(1.0, 4.0, 0.05, "suffix:m") var wall_button_size: float = 2.5
@export_range(0.5, 3.0, 0.05, "suffix:m") var wall_button_height: float = 1.35
@export_range(0.0, 1.0, 0.05, "suffix:s") var fence_pass_margin: float = 0.3

@export_group("Wall fences")
## DESIGN-TBD (GDD §10, phase 2: "with wall fences in play"; GDD §9.1, full-height ones from Marketplace 2):
## in the phases listed (0-based), full-height wall fences (task B5) stand along both walls, one every
## wall_fence_every seconds of run on alternating walls, wall_fence_on seconds on and wall_fence_off off on
## the level clock (with the fence's warning before each switch on), planned wall_fence_ahead seconds of
## run past the built track at a time. The machine's strikes keep off their drop windows (B5).
@export var wall_fence_phases: PackedInt32Array = PackedInt32Array([1])
@export_range(1.0, 10.0, 0.1, "suffix:s") var wall_fence_every: float = 2.2
@export_range(0.3, 3.0, 0.05, "suffix:s") var wall_fence_on: float = 1.0
@export_range(0.5, 4.0, 0.05, "suffix:s") var wall_fence_off: float = 1.4
@export_range(2.0, 20.0, 0.5, "suffix:s") var wall_fence_ahead: float = 6.0

@export_group("Ceiling button")
## DESIGN-TBD: phase 3's special button is on the underside of a floating billboard over every lane (a
## Marketplace ceiling, GDD §5: "floating advertisements"), reached by an anti-grav pad in its lane: the
## runner reaches the pad pad_extra later than a floor button in its place. The button is
## ceiling_button_after past the pad, in the pad's lane (ceiling_button_shift lanes over); Barnacle
## Turrets guard the ceiling past it in a lane beside the pad's (turrets_by_lanes at 3, 5 and 6 lanes;
## C1's limits: at most two, never over the pad's lane, at least its after_pad_seconds past the pad and
## spacing_seconds apart, before_end_seconds before the end), and the billboard ends ceiling_end_after past
## the last. The machine is taller than a ceiling: at the lever's pull it squats on its treads over
## duck_seconds until its top is duck_top up, and the billboard comes down from the sky over it (over
## billboard_drop_seconds) with its pad; it rises again once it has rolled past the billboard's end.
@export_range(0.0, 2.0, 0.05, "suffix:s") var pad_extra: float = 0.35
@export_range(0.6, 2.0, 0.05, "suffix:s") var ceiling_button_after: float = 1.1
@export_range(0, 2) var ceiling_button_shift: int = 0
@export var turrets_by_lanes: PackedInt32Array = PackedInt32Array([1, 2, 2])
@export_range(0.2, 2.0, 0.05, "suffix:s") var ceiling_end_after: float = 0.6
@export_range(2.0, 5.5, 0.05, "suffix:m") var duck_top: float = 4.9
@export_range(0.2, 2.0, 0.05, "suffix:s") var duck_seconds: float = 0.7
@export_range(0.2, 2.0, 0.05, "suffix:s") var billboard_drop_seconds: float = 0.7

@export_group("Defeat")
## DESIGN-TBD (GDD §10: "the reels spin wildly and jam, TILT flashes, and it collapses in an explosion of
## coins while the shops erupt in cheers"): after the last stomp it lurches out from under the runner and
## rises as after any stomp; then its reels spin wildly for tilt_spin_seconds and jam, TILT flashes for
## tilt_seconds (a steady glow with Reduced flashing), and it collapses into the street over
## collapse_seconds, collapse_coins coins bursting out of it.
@export_range(0.2, 3.0, 0.05, "suffix:s") var tilt_spin_seconds: float = 1.0
@export_range(0.3, 4.0, 0.05, "suffix:s") var tilt_seconds: float = 1.4
@export_range(0.3, 4.0, 0.05, "suffix:s") var collapse_seconds: float = 1.8
@export_range(0, 120) var collapse_coins: int = 90

@export_group("Fairness")
## A player's reaction: every route (through an attack, to a button, the jackpot's approach) is checked
## for a runner who moves this long after its warning starts (TheHouseRoute).
@export_range(0.0, 1.0, 0.05, "suffix:s") var reaction: float = 0.35
## A lane switch is counted this many times its real length, and a body this far along the track either
## side of the runner's middle.
@export_range(1.0, 3.0, 0.05) var switch_margin: float = 1.5
@export_range(0.2, 1.5, 0.05, "suffix:m") var body_margin: float = 0.55
## Every route must also carry on this far (at 18 m/s) past an attack's last hazard.
@export_range(0.0, 30.0, 0.5, "suffix:m") var escape_clear_after: float = 8.0


## The longest warning an attack or a button gives: how far ahead of the runner something can land.
func longest_warning() -> float:
	return maxf(maxf(cherry_warning, fence_warning), maxf(bar_warning, button_lead))


## The spin list of phase `phase` (the last's for any later phase): each entry three symbols in reel
## order. Unknown symbols are left out (a reel with none shows a cherry).
func spins_for(phase: int) -> Array[PackedStringArray]:
	var out: Array[PackedStringArray] = []
	if spin_patterns.is_empty():
		out.append(PackedStringArray(["cherry", "bar", "lightning"]))
		return out
	var line: String = spin_patterns[clampi(phase, 0, spin_patterns.size() - 1)]
	for entry: String in line.split("|", false):
		var spin := PackedStringArray()
		for part: String in entry.split(",", false):
			var symbol: String = part.strip_edges()
			if symbol in ["cherry", "lightning", "bar"]:
				spin.append(symbol)
		while spin.size() < 3:
			spin.append("cherry")
		spin.resize(3)
		out.append(spin)
	if out.is_empty():
		out.append(PackedStringArray(["cherry", "bar", "lightning"]))
	return out


## How many spins of phase `phase` come without buttons.
func opening_spins_for(phase: int) -> int:
	if opening_spins.is_empty():
		return 0
	return maxi(opening_spins[clampi(phase, 0, opening_spins.size() - 1)], 0)


## An entry of a per-lane-count list (3, 5 and 6 lanes; 4 takes 5's, fewer 3's, more 6's), at most
## `lanes - 1` and at least 1: every attack leaves a lane free.
static func per_lanes(list: PackedInt32Array, lanes: int) -> int:
	if list.is_empty():
		return 1
	var i: int = 0 if lanes <= 3 else (1 if lanes <= 5 else 2)
	return clampi(list[mini(i, list.size() - 1)], 1, maxi(lanes - 1, 1))


## Where phase `phase`'s special reel's button goes: "floor", "wall" or "ceiling".
func special_for(phase: int) -> String:
	if special_buttons.is_empty():
		return "floor"
	var kind: String = special_buttons[clampi(phase, 0, special_buttons.size() - 1)]
	return kind if kind in ["floor", "wall", "ceiling"] else "floor"


## True if phase `phase` has wall fences along its walls.
func wall_fences_in(phase: int) -> bool:
	return wall_fence_phases.has(phase)
