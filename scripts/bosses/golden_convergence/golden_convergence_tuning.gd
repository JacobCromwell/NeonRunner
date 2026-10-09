class_name GoldenConvergenceTuning
extends Resource
## The Golden Convergence's numbers (GDD §10; data/bosses/golden_boss_tuning.tres, F6 in its fight), one
## group per part of the fight so each build step (task E5d: a, the suit, the court, the entrance, the
## Helidrone Strafe and the Flying Buttress; b, the Fist Slam and the Missile Barrage; c, the Refill Ship;
## d, The Magnate) adds its own group. Timings are at pace 1: a phase's pattern divides the gaps between its
## beats and passes by its BossPhase.pace (the warnings keep their seconds: a warning is never shorter than
## its time to react). Distances that stand for a time (marked "at 18 m/s": a raked stretch, a rake's speed,
## how far apart the lines for show are) are written for MovementTuning.REFERENCE_SPEED and multiplied by
## the run's pace (GoldenConvergence.run_pace()), so the fight keeps its seconds at the Golden Zone's 25 m/s;
## where the suit floats and the squadron flies relative to the runner (framing), sizes and heights stay as
## they are. Every number here is a placeholder (DESIGN-TBD, docs/questions/e5d.md) until the owner plays it.

@export_group("The suit")
## DESIGN-TBD (GDD §10: "it floats in the distance ahead of the runner"): its waist floats this far ahead of
## the runner (framing, kept in metres) and this high over the causeway, swaying and bobbing gently. Close
## enough that the best weapons reach its chest (PowerupTuning.weapon_range: 70 m for tiers 2-4, 42 m for
## tier 1, which doesn't reach it: docs/questions/e5d.md, E5d-a), far enough that it reads whole on screen,
## halo to hands, on a phone's 16:9.
@export_range(30.0, 200.0, 0.5, "suffix:m") var suit_ahead: float = 64.0
@export_range(0.0, 40.0, 0.5, "suffix:m") var suit_height: float = 12.0
## Its size: 1 is the giant the model is built at (about 23 m from waist to crown, 30 m across the shoulders).
@export_range(0.3, 2.0, 0.01) var suit_scale: float = 1.0
@export_range(0.0, 4.0, 0.05, "suffix:m") var sway: float = 0.7
@export_range(0.0, 0.5, 0.01, "suffix:Hz") var sway_hz: float = 0.09
@export_range(0.0, 2.0, 0.05, "suffix:m") var bob: float = 0.45
@export_range(0.0, 0.5, 0.01, "suffix:Hz") var bob_hz: float = 0.16

@export_group("The entrance")
## DESIGN-TBD (GDD §10, the entrance, proposed: "it rises into view at the far end, its cape unfurling into
## its cloud. The cult's three-note chime rings out, huge and slow"): the first phase's intro
## (BossPhase.intro_seconds): it rises from this far below its place over rise_seconds; its cape unfurls
## from unfurl_at over unfurl_seconds; the chime rings at chime_at.
@export_range(10.0, 150.0, 1.0, "suffix:m") var rise_depth: float = 60.0
@export_range(0.5, 10.0, 0.1, "suffix:s") var rise_seconds: float = 3.2
@export_range(0.0, 8.0, 0.1, "suffix:s") var unfurl_at: float = 1.0
@export_range(0.3, 8.0, 0.1, "suffix:s") var unfurl_seconds: float = 2.6
@export_range(0.0, 8.0, 0.1, "suffix:s") var chime_at: float = 1.6
## A later phase's intro (GDD §10, proposed: "between phases, the suit reels from the blast for a few
## seconds"): it lurches back this far (radians) and recovers.
@export_range(0.0, 0.6, 0.01, "suffix:rad") var reel_tilt: float = 0.22

@export_group("The beats")
## DESIGN-TBD (GDD §10, Stage 1): each phase's pattern, a beat script: beats in order, comma-separated, each
## `kind` or `kind:argument`. Kinds: strafe (the Helidrone Strafe; its argument is its pass script: V a
## vertical pass head-on, v a vertical pass from behind, H a horizontal pass), slams (the Fist Slam, E5d-b),
## barrage (the Missile Barrage, E5d-b), refill (the Refill Ship with a Helidrone Strafe, its argument that
## strafe's script; E5d-c), and stage 2's pounce and lash (The Magnate, E5d-d). A beat whose attack isn't
## built yet is a stub the pattern skips (GoldenConvergence: until E5d-c a refill beat plays its strafe
## alone). Phase 1: the strafe on its own (3 passes, it teaches the strafe), then slams, a barrage and the
## Refill Ship with a 3-pass strafe; phases 2 and 3: slams, a barrage, slams, a barrage, then the Refill Ship
## with a 7-pass strafe (the 4th and 7th from behind).
@export var phase_beats: PackedStringArray = PackedStringArray([
	"strafe:VVH,slams,barrage,refill:VVH",
	"slams,barrage,slams,barrage,refill:VVHvVHv",
	"slams,barrage,slams,barrage,refill:VVHvVHv",
	"pounce",
	"pounce,lash",
	"pounce,lash",
])
## GDD §10 ("a missed pad: the ship finishes refilling and flies off, and the phase's loop starts again from
## the slams"): once a phase's last beat is over, its pattern goes on from this beat (0 = the first): phase
## 1's opening strafe plays once.
@export var loop_from: PackedInt32Array = PackedInt32Array([1, 0, 0, 0, 0, 0])
## The first beat starts this long into a phase's pattern, and each next one this long after the last is
## over.
@export_range(0.0, 6.0, 0.05, "suffix:s") var first_beat_delay: float = 0.8
@export_range(0.0, 6.0, 0.05, "suffix:s") var beat_gap: float = 1.6

@export_group("Helidrone Strafe: the squadron")
## DESIGN-TBD (GDD §10: "heli drones (the heli drone's model, never coloured red) come out of the cape, move
## and fire as one ... and then leave"): the drones' size (the heli drone's model_scale), the height they
## rake from, and how far the spare drone (a pass covering fewer lanes than there are drones) climbs above
## the formation, holding its fire.
@export_range(0.5, 3.0, 0.05) var drone_scale: float = 1.45
@export_range(3.0, 14.0, 0.1, "suffix:m") var fly_height: float = 7.0
@export_range(1.0, 8.0, 0.1, "suffix:m") var spare_climb: float = 3.4
## Between passes the squadron waits at its station this far ahead of the runner and this high (framing).
@export_range(15.0, 120.0, 0.5, "suffix:m") var station_ahead: float = 40.0
@export_range(4.0, 30.0, 0.5, "suffix:m") var station_height: float = 12.0
## Out of the cape to the station before the first pass's warning, and back into it after the last pass.
@export_range(0.5, 6.0, 0.05, "suffix:s") var emerge_seconds: float = 1.6
@export_range(0.5, 6.0, 0.05, "suffix:s") var return_seconds: float = 2.2
## A drone flies this far ahead of (head-on) or behind (from behind) the point its guns rake (framing).
@export_range(0.0, 15.0, 0.25, "suffix:m") var rake_lead: float = 5.0

@export_group("Helidrone Strafe: vertical passes")
## DESIGN-TBD (GDD §10: "before each pass, a red line on the floor where the fire will land, about a second
## ahead, and a gatling spin-up whine"): the warning, never divided by the phase's pace.
@export_range(0.8, 3.0, 0.05, "suffix:s") var warning_seconds: float = 1.15
## A head-on pass rakes its lanes from vertical_length ahead of where the runner was as its warning began
## back to vertical_behind behind it (at 18 m/s), its guns' front closing in at rake_speed (at 18 m/s, over
## the ground): a runner who stays is hit about 1.4 s after the red lines show.
@export_range(15.0, 80.0, 0.5, "suffix:m") var vertical_length: float = 42.0
@export_range(0.0, 12.0, 0.5, "suffix:m") var vertical_behind: float = 4.0
@export_range(20.0, 120.0, 1.0, "suffix:m/s") var rake_speed: float = 55.0
## A pass from behind rakes from behind_start behind the runner forward over behind_length (at 18 m/s), its
## front gaining on the runner at behind_rake_speed (at 18 m/s): it reaches a runner who stays about 2 s
## after the red lines show.
@export_range(2.0, 30.0, 0.5, "suffix:m") var behind_start: float = 10.0
@export_range(20.0, 90.0, 0.5, "suffix:m") var behind_length: float = 46.0
@export_range(10.0, 80.0, 1.0, "suffix:m/s") var behind_rake_speed: float = 40.0
## GDD §10 ("together, the passes draw a hatch pattern over the track, one pass after another, a second or
## two apart"): the next pass's warning begins this long after a pass's fire is over (divided by the phase's
## pace).
@export_range(0.3, 5.0, 0.05, "suffix:s") var pass_gap: float = 1.5
## GDD §10 ("fire in an outer lane hits a runner low on the wall but not one high up"): a pass's fire in an
## outer lane climbs an open wall to this height; a wall runner whose feet are above it is safe.
@export_range(0.5, 4.0, 0.05, "suffix:m") var wall_fire_height: float = 1.5

@export_group("Helidrone Strafe: horizontal passes")
## DESIGN-TBD (GDD §10: "the drones fly from wall to wall, raking a line across the track and up both walls
## at every height ... The player dodges it through a Flying Buttress"): after the warning the squadron
## sweeps across the track in sweep_seconds; the live line, at the buttress, is burning whole cross_lead
## before the runner gets to it and burns on until they're past it, then line_burn_after more.
@export_range(0.2, 1.5, 0.05, "suffix:s") var sweep_seconds: float = 0.55
@export_range(0.1, 1.0, 0.05, "suffix:s") var cross_lead: float = 0.3
@export_range(0.1, 2.0, 0.05, "suffix:s") var line_burn_after: float = 0.45
## The line's fire: above a jump (GDD §10, proposed: a jump doesn't dodge it), this deep along the track,
## and up an open wall to this height (every height a wall run reaches).
@export_range(2.8, 6.0, 0.05, "suffix:m") var line_height: float = 3.4
@export_range(0.6, 3.0, 0.05, "suffix:m") var line_depth: float = 1.6
@export_range(4.0, 10.0, 0.1, "suffix:m") var wall_line_height: float = 7.0
## The squadron's height over the lines it rakes (framing).
@export_range(4.0, 16.0, 0.1, "suffix:m") var line_fly_height: float = 8.0
## GDD §10 ("extra lines for show ... further down the field"; proposed: no warning, no buttress, their fire
## over well before the runner reaches them): the other drones rake lines this far apart beyond the live one
## (at 18 m/s), burning show_burn seconds.
@export_range(8.0, 60.0, 0.5, "suffix:m") var show_spacing: float = 24.0
@export_range(0.2, 2.0, 0.05, "suffix:s") var show_burn: float = 0.6
## Every raked line and lane leaves a dark scorch mark (never glowing: GDD §3, what looks like a hit is a
## hit), fading out over this long.
@export_range(1.0, 30.0, 0.5, "suffix:s") var scorch_seconds: float = 9.0

@export_group("Flying Buttress")
## DESIGN-TBD (GDD §10: "it comes into view well before its line, and there's always time to reach it from
## the farthest lane"): a buttress rises out of the causeway at least this long before the runner reaches
## it, over buttress_rise_seconds, with a deep rumble.
@export_range(2.0, 12.0, 0.1, "suffix:s") var buttress_sight: float = 6.0
@export_range(0.3, 4.0, 0.05, "suffix:s") var buttress_rise_seconds: float = 1.4
## Its pier: this deep along the track, its arched opening this tall (above a jump's reach), the pier this
## tall to where its flying arch springs out over the edge (it's taller than any other doodad).
@export_range(1.5, 6.0, 0.05, "suffix:m") var pier_depth: float = 3.2
@export_range(3.2, 6.0, 0.05, "suffix:m") var arch_height: float = 4.4
@export_range(9.0, 40.0, 0.5, "suffix:m") var pier_height: float = 16.0
## Its sides block a lane switch into its lane (solid but safe, like any doodad's) from this share of a lane
## switch's run before its front, so a late switch never ends inside its legs.
@export_range(0.0, 2.0, 0.05) var blocker_lead: float = 0.8
## Smashed (E5d-b's fist, E5d-d's Pounce), it crumbles over this long.
@export_range(0.3, 4.0, 0.05, "suffix:s") var crumble_seconds: float = 1.6

# --- E5d-b: the Fist Slam, the toppled tower and the Missile Barrage ----------------------------------

@export_group("Fist Slam")
## DESIGN-TBD (GDD §10, Fist Slam, proposed: "in phase 1, slams 1 and 2 come down on the runner and slam 3
## ahead; in later phases, slams 1, 3 and 4 on the runner and 2 and 5 ahead"; "the chances are ... slams 2
## and 3 in phase 1, 3 and 4 later"): each phase's slam sequence, a letter a slam in order: O comes down on
## the runner, A lands ahead of them (its hole to be jumped); lower case (o, a) is a buttress chance, a Flying
## Buttress standing where it lands. Phase 1's third slam is both ahead and a chance, as the GDD's two
## proposals give it (docs/questions/e5d.md, E5d-b). A phase past the list plays the last one.
@export var slam_scripts: PackedStringArray = PackedStringArray(["Ooa", "OAooA", "OAooA"])
## GDD §10 ("about two seconds apart, divided by the phase's pace"): one slam's impact to the next one's.
@export_range(1.0, 4.0, 0.05, "suffix:s") var slam_gap: float = 2.0
## The fist's way to a slam (GDD §10: "the fist follows the runner's lane, then locks about a second before
## it falls. The fist rises, its shadow grows on the floor, a red square marks where it will land, and a deep
## grinding wind-up plays"): the arm swings out and telescopes to hover over the runner's lane in
## slam_out_seconds (divided by the phase's pace); the warning (the red square, the shadow, the grind)
## begins slam_track_seconds before the lock, the fist following the runner's lane and rising; it locks
## slam_lock_seconds before it lands, dropping in the last slam_fall_seconds. The warning keeps its seconds
## at every pace. Every point of it is keyed to the runner's distance at the run speed, so a dash never
## desyncs a slam.
@export_range(0.3, 2.0, 0.05, "suffix:s") var slam_out_seconds: float = 0.7
@export_range(0.3, 2.0, 0.05, "suffix:s") var slam_track_seconds: float = 0.8
@export_range(0.8, 2.0, 0.05, "suffix:s") var slam_lock_seconds: float = 1.0
@export_range(0.15, 0.8, 0.05, "suffix:s") var slam_fall_seconds: float = 0.4
## After the slam, the fist goes back to rest at his side over this long (divided by the phase's pace).
@export_range(0.3, 2.0, 0.05, "suffix:s") var slam_back_seconds: float = 0.85
## Its touch (an enemy attack over the hole's footprint, from the floor to above a jump) lasts this long
## from the impact and reaches this high.
@export_range(0.05, 0.6, 0.01, "suffix:s") var slam_hit_seconds: float = 0.2
@export_range(2.8, 8.0, 0.1, "suffix:m") var slam_hit_height: float = 4.0
## A slam ahead (GDD §10: "sometimes a fist lands further ahead of the runner, so the holes have to be
## jumped") lands as the runner is this long (at the run speed) from its hole's near edge.
@export_range(0.6, 2.5, 0.05, "suffix:s") var slam_ahead_seconds: float = 1.1
## The fist's middle this high over the floor while it follows the runner's lane, and once risen.
@export_range(4.0, 20.0, 0.5, "suffix:m") var fist_hover_height: float = 8.0
@export_range(4.0, 20.0, 0.5, "suffix:m") var fist_raise_height: float = 11.0
## A buttress chance's hole ends this far before its gate's pier: the slam's row is dug just in front of the
## gate, so a hole sharing the gate's lane never goes through it (docs/questions/e5d.md, E5d-b).
@export_range(0.0, 3.0, 0.05, "suffix:m") var slam_gate_gap: float = 0.6

@export_group("The toppled tower")
## DESIGN-TBD (GDD §10: "the building it held up, off screen, topples forward along the track on the side
## the buttress's arch leans toward, and its side forms a wall ... It stays for about 8-12 seconds"): its
## side is a wall from about the buttress onward for this long of running (at the run speed).
@export_range(8.0, 12.0, 0.1, "suffix:s") var tower_wall_seconds: float = 10.0
## It topples over this long (an accelerating fall) from where it stood, out of view: its foot this far
## behind the runner as it starts, beside the causeway. It lies there this wide, its underside this far
## below the causeway's edge, its side flush with the wall's face.
@export_range(0.6, 3.0, 0.05, "suffix:s") var tower_fall_seconds: float = 1.5
@export_range(4.0, 20.0, 0.5, "suffix:m") var tower_behind: float = 9.0
@export_range(8.0, 30.0, 0.5, "suffix:m") var tower_width: float = 14.0
@export_range(1.0, 10.0, 0.5, "suffix:m") var tower_depth: float = 5.0
## Once the runner is past its end, it sinks away into the pools over this long.
@export_range(0.5, 5.0, 0.1, "suffix:s") var tower_sink_seconds: float = 2.5

@export_group("Missile Barrage")
## DESIGN-TBD (GDD §10, Missile Barrage, proposed: "the missiles hang at the top of their climb, then dive
## with a rising whistle while the marks fill in; the fire lands when they're full"): the shoulder pipes'
## hatches open over barrage_hatch_seconds (the warning begins), the missiles launch one after another over
## barrage_salvo_seconds with a roar and climb for barrage_climb_seconds (the red target marks spreading over
## the floor meanwhile), hang barrage_hang_seconds, then dive for barrage_dive_seconds while the marks fill
## in; the fire lands as the runner reaches where the barrage planned them at the run speed. The warning
## keeps its seconds at every pace and leaves time to reach the wall from the far side: barrage_reaction,
## every lane switch, the wall entry and barrage_margin (GDD §10: "up to 5 lane switches on 6 lanes, plus
## the wall entry"; the tests check it at 3, 5 and 6 lanes).
@export_range(0.2, 1.5, 0.05, "suffix:s") var barrage_hatch_seconds: float = 0.5
@export_range(0.1, 1.5, 0.05, "suffix:s") var barrage_salvo_seconds: float = 0.5
@export_range(0.5, 2.5, 0.05, "suffix:s") var barrage_climb_seconds: float = 1.0
@export_range(0.0, 1.5, 0.05, "suffix:s") var barrage_hang_seconds: float = 0.5
@export_range(0.5, 2.0, 0.05, "suffix:s") var barrage_dive_seconds: float = 1.0
@export_range(0.3, 1.5, 0.05, "suffix:s") var barrage_reaction: float = 0.7
@export_range(0.0, 1.0, 0.05, "suffix:s") var barrage_margin: float = 0.4
## GDD §10 ("longer than one layer of protection alone can carry the runner through ... long enough that two
## layers can ... and shorter than one wall run without claws"; proposed: "about 1.5 seconds ... its flames
## reach about a metre up, so a jump only delays them"): the fire burns this long, this high.
@export_range(0.8, 2.5, 0.05, "suffix:s") var fire_seconds: float = 1.5
@export_range(0.5, 2.0, 0.05, "suffix:m") var fire_height: float = 1.0
## It covers every lane from fire_behind behind the runner as it lands to as far as they can run while it
## burns (the run speed plus a dash's bonus) and fire_ahead more: they can't outrun it.
@export_range(1.0, 10.0, 0.5, "suffix:m") var fire_behind: float = 3.0
@export_range(1.0, 15.0, 0.5, "suffix:m") var fire_ahead: float = 5.0
## Red target marks per lane over its stretch (one missile each), and their size.
@export_range(2, 10) var marks_per_lane: int = 5
@export_range(0.4, 1.2, 0.05, "suffix:m") var mark_radius: float = 0.95
## The missiles hang this high over the causeway in front of the suit, in the run camera's view (framing:
## GoldenConvergenceBarrage.APEX_AHEAD).
@export_range(10.0, 80.0, 1.0, "suffix:m") var missile_apex_height: float = 22.0

@export_group("The court")
## DESIGN-TBD (GDD §10: "no side walls ... a low golden balustrade bumps the runner back"): the walls are
## taken away (BossProps.block_wall) from just behind the runner to this far ahead, in stretches this long,
## except where a wall is opened (GoldenConvergenceCourt.open_wall).
@export_range(60.0, 400.0, 5.0, "suffix:m") var wall_block_ahead: float = 240.0
@export_range(10.0, 120.0, 5.0, "suffix:m") var wall_block_stretch: float = 40.0


## Phase `index`'s beat script, as {kind, arg} entries in order (an empty list for a phase it doesn't name).
func beats_for(index: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if phase_beats.is_empty():
		return out
	var line: String = phase_beats[clampi(index, 0, phase_beats.size() - 1)]
	for raw: String in line.split(",", false):
		var beat: String = raw.strip_edges()
		if beat == "":
			continue
		var kind: String = beat.get_slice(":", 0).strip_edges()
		var arg: String = beat.get_slice(":", 1).strip_edges() if beat.contains(":") else ""
		out.append({"kind": StringName(kind), "arg": arg})
	return out


## Where phase `index`'s pattern goes on from once its last beat is over.
func loop_start(index: int) -> int:
	if loop_from.is_empty():
		return 0
	return maxi(loop_from[clampi(index, 0, loop_from.size() - 1)], 0)


## How many drones fly at `lanes` lanes (GDD §10: "one drone for every other lane (half the lanes, rounded
## up): 2 on 3 lanes, 3 on 5 or 6 lanes").
static func squadron_size(lanes: int) -> int:
	return maxi(ceili(lanes / 2.0), 1)


## The lanes a vertical pass covers at `lanes` lanes with `parity` (0: lanes 1, 3, 5 counting from 1, which
## takes the outer lanes on 3 and 5 lanes; 1: lanes 2, 4, 6): every other lane. DESIGN-TBD (docs/questions/
## e5d.md, E5d-a 5): on 6 lanes the first pass (parity 0) takes only the left outer lane, as the GDD's
## "lanes 1, 3, 5" says.
static func covered_lanes(lanes: int, parity: int) -> Array[int]:
	var out: Array[int] = []
	for lane: int in lanes:
		if lane % 2 == parity % 2:
			out.append(lane)
	return out
