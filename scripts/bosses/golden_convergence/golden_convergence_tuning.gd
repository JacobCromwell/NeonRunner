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
## strafe's script; E5d-c), and stage 2's overtake, pounce and lash (The Magnate, E5d-d). A beat kind with no
## attack registered is a stub the pattern skips (GoldenConvergence: beat_stub). Phase 1: the strafe on its own
## (3 passes, it teaches the strafe), then slams, a barrage and the Refill Ship with a 3-pass strafe; phases 2
## and 3: slams, a barrage, slams, a barrage, then the Refill Ship with a 7-pass strafe (the 4th and 7th from
## behind).
@export var phase_beats: PackedStringArray = PackedStringArray([
	"strafe:VVH,slams,barrage,refill:VVH",
	"slams,barrage,slams,barrage,refill:VVHvVHv",
	"slams,barrage,slams,barrage,refill:VVHvVHv",
	"overtake,pounce,pounce:bait",
	"pounce,lash:low,pounce:bait,lash:high",
	"pounce,lash:high,lash:low,pounce:bait,lash:low,lash:high",
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
## DESIGN-TBD (E5d polish; docs/questions/e5d.md): one slam's row and the next one's (its gate, for a chance) are
## always at least a lane switch's run apart at the run speed plus this long (GoldenConvergenceSlams.row_gap): a
## runner landing past a hole has room to switch out of the next one's footprint, and two rows never meet. Where
## the script's spacing (slam_gap over the pace, an ahead slam's lead) would bring them closer, the later slams
## come that much later.
@export_range(0.1, 1.0, 0.05, "suffix:s") var slam_row_margin: float = 0.3

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

# --- E5d-c: the Refill Ship ------------------------------------------------------------------------------

@export_group("Refill Ship: the ship")
## DESIGN-TBD (GDD §10, proposed: "a gilded cult cargo ship, its flat plated belly across every lane at ceiling
## height, racks of missiles along its flanks, pacing the runner while it refills"): it flies in from behind and
## above the runner over ship_in_seconds to its station beside the causeway on the fed shoulder's side,
## ship_side out from the track's middle (beyond the balustrade, so the strafe's passes have the track),
## ship_station_ahead ahead of the runner and its belly ship_station_height up (framing, kept in metres), and
## paces them there while it refills: the feed line shoots out to the shoulder's pipes feed_reach_seconds after it
## arrives, a missile riding up it every feed_every seconds at feed_speed along the line.
@export_range(0.5, 6.0, 0.05, "suffix:s") var ship_in_seconds: float = 2.4
@export_range(12.0, 60.0, 0.5, "suffix:m") var ship_side: float = 22.0
@export_range(0.0, 80.0, 0.5, "suffix:m") var ship_station_ahead: float = 36.0
@export_range(8.0, 40.0, 0.5, "suffix:m") var ship_station_height: float = 11.0
@export_range(0.1, 2.0, 0.05, "suffix:s") var feed_reach_seconds: float = 0.5
@export_range(0.1, 2.0, 0.05, "suffix:s") var feed_every: float = 0.45
@export_range(5.0, 80.0, 1.0, "suffix:m/s") var feed_speed: float = 30.0

@export_group("Refill Ship: the cage")
## DESIGN-TBD (GDD §10: "the squadron holds its fire while the cage comes up and the runner goes for it"): the
## cage comes up once the beat's strafe has flown cage_after passes (the squadron holds its fire from then), and
## the runner reaches its front fence cage_lead later at the run speed (time to read it, reach the generator's
## lane from the farthest lane and stomp it). Its fences flicker in with the fence warning over cage_flicker, then
## switch on.
@export_range(0, 6) var cage_after: int = 1
@export_range(2.5, 10.0, 0.05, "suffix:s") var cage_lead: float = 4.5
@export_range(0.2, 2.0, 0.05, "suffix:s") var cage_flicker: float = 1.0
## DESIGN-TBD (GDD §10: "the front fence placed so a jump over it lands past the pad"; proposed: "the cage's sides
## are fences running along the pad lane's edges, from the front fence to past the pad"): the pad is
## cage_pad_length deep, just behind the front fence (shorter than a level's pad, so even the earliest jump that
## clears the fence comes down past it at 18 m/s); the sides are cage_side_height tall (above a jump's reach: a
## switch into the cage touches one, in the air too) and run cage_side_past past the pad (at 18 m/s).
@export_range(0.8, 2.5, 0.05, "suffix:m") var cage_pad_length: float = 1.4
@export_range(1.8, 4.0, 0.05, "suffix:m") var cage_side_height: float = 2.4
@export_range(0.0, 6.0, 0.1, "suffix:m") var cage_side_past: float = 1.5
## DESIGN-TBD (GDD §10: "the generator stands in a lane next to the cage, just before it, with room after its
## pulse to switch into the pad's lane"): it stands generator_before (at 18 m/s) before the front fence, so a
## stomp's bounce comes down before the cage (and a dash through it has room to switch in).
@export_range(6.0, 40.0, 0.5, "suffix:m") var generator_before: float = 16.0

@export_group("Refill Ship: the ride")
## DESIGN-TBD: as the cage comes up the ship comes over the causeway and down to the ceiling's height over
## descend_seconds, its belly over every lane and the runner (pacing them: they're under it RIDER metres behind
## its middle, GoldenConvergenceShipModel), settled settle_before before the runner reaches the front fence. A
## runner past the pad by miss_after (at 18 m/s) and not riding it has missed it: the strafe fires on, the ship
## climbs back to its station over climb_seconds, finishes refilling finish_seconds later and flies off over
## leave_seconds (GDD §10: "the ship finishes refilling and flies off").
@export_range(0.5, 5.0, 0.05, "suffix:s") var descend_seconds: float = 2.0
@export_range(0.3, 3.0, 0.05, "suffix:s") var settle_before: float = 1.0
@export_range(0.5, 10.0, 0.25, "suffix:m") var miss_after: float = 3.0
@export_range(0.5, 5.0, 0.05, "suffix:s") var climb_seconds: float = 1.6
@export_range(0.0, 5.0, 0.05, "suffix:s") var finish_seconds: float = 1.5
@export_range(0.5, 6.0, 0.05, "suffix:s") var leave_seconds: float = 2.2

@export_group("Refill Ship: the chain reaction")
## DESIGN-TBD (GDD §10: the pad "hurls the whole squadron up into the Refill Ship, setting off a chain reaction":
## the ship's missiles explode, it spins off to the side and explodes, the squadron explodes, "the explosion races
## up the feed line into his shoulders, and the boss takes damage"; "the runner falls back to the floor
## unharmed"). Seconds from the pad: the drones, hurled up from where they hold beside the ship, crash into its
## missile racks; its missiles explode in a ripple along the racks from ripple_at over ripple_seconds; the ship
## spins off to the side from spin_at (its belly gone: the runner drops back to the floor) over spin_seconds and
## explodes; the blast races up the feed line over blast_seconds, into his shoulder, and the hit lands.
@export_range(0.0, 1.5, 0.05, "suffix:s") var ripple_at: float = 0.3
@export_range(0.2, 2.0, 0.05, "suffix:s") var ripple_seconds: float = 0.8
@export_range(0.6, 3.0, 0.05, "suffix:s") var spin_at: float = 1.4
@export_range(0.4, 3.0, 0.05, "suffix:s") var spin_seconds: float = 1.3
@export_range(0.3, 2.0, 0.05, "suffix:s") var blast_seconds: float = 0.9

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


# --- Stage 2, The Magnate (task E5d-d) -----------------------------------------------------------------
# Its beats (phase_beats, phases 4-6): overtake (he shows himself, GoldenConvergenceOvertake), pounce (the
# Pounce; `pounce:bait` with a Flying Buttress for the bait, GoldenConvergencePounce) and lash (the Cable Lash,
# `lash:low` or `lash:high`, GoldenConvergenceLash). DESIGN-TBD (docs/questions/e5d.md, E5d-d): phase 4 an
# overtake, a Pounce and a Pounce with the bait, looped; phase 5 adds a low and a high Lash between the Pounces;
# phase 6 more Lashes, faster (its pace). A missed bait comes around again with the loop (no escalation).

@export_group("The Magnate")
## DESIGN-TBD (GDD §10, Second stage: "two to three times the runner's size"): his size, 1 the model's
## (GoldenConvergenceMagnateModel: about 3.5 m from snout to rump and 1.8 m at the shoulder on all fours,
## about 2.6 times the runner's 1.28 m reared up).
@export_range(0.5, 2.0, 0.01) var magnate_scale: float = 1.0
## DESIGN-TBD (GDD §10, optional: "cracks leaking the cult's warm white glow, as if the broadcast lives inside
## him"): how much of the cult's warm white shows in his cracks (0: none, dark cracks).
@export_range(0.0, 1.0, 0.05) var crack_glow: float = 0.55
## DESIGN-TBD (GDD §10, proposed: "behind the runner, his shadow and a marker at the screen's bottom edge show
## his lane"): the chase. He keeps this far behind the runner (framing, kept in metres: behind the camera), takes
## up the runner's lane this long after they change it, at this sideways speed.
@export_range(8.0, 30.0, 0.5, "suffix:m") var chase_gap: float = 10.5
@export_range(0.0, 2.0, 0.05, "suffix:s") var chase_lane_delay: float = 0.6
@export_range(2.0, 30.0, 0.5, "suffix:m/s") var chase_side_speed: float = 10.0
## His breathing and growls behind the runner, this many seconds apart (positional, from where he is).
@export_range(0.5, 5.0, 0.1, "suffix:s") var breath_every: float = 1.6
@export_range(2.0, 15.0, 0.5, "suffix:s") var growl_every: float = 5.5
## Done with an attack, he drops back behind the runner over this long (divided by the phase's pace), along a
## balustrade where he's on one.
@export_range(0.5, 4.0, 0.05, "suffix:s") var drop_back_seconds: float = 1.6

@export_group("The Magnate: the transition")
## DESIGN-TBD (GDD §10, proposed: "the third ship's blast bursts the suit open; its golden plates fall away and
## the empty suit crashes down beside the causeway. The Magnate claws his way out, roars, and leaps over the
## runner to land behind them"): phase 4's intro (BossPhase.intro_seconds), on a retry from the checkpoint too.
## The chest's plates burst open over burst_seconds and fly off from plates_off_at; he claws out of the man's room
## from claw_at over claw_seconds; roars at roar_at (the feed switches to his face); the empty suit topples
## off the causeway's side from suit_fall_at over suit_fall_seconds (pacing the runner, never over the track);
## he leaps off it at leap_at, over the runner, landing behind them transition_leap_seconds later.
@export_range(0.1, 2.0, 0.05, "suffix:s") var burst_seconds: float = 0.5
@export_range(0.0, 3.0, 0.05, "suffix:s") var plates_off_at: float = 0.35
@export_range(0.0, 3.0, 0.05, "suffix:s") var claw_at: float = 0.55
@export_range(0.3, 3.0, 0.05, "suffix:s") var claw_seconds: float = 1.1
@export_range(0.0, 5.0, 0.05, "suffix:s") var roar_at: float = 1.75
@export_range(0.0, 5.0, 0.05, "suffix:s") var suit_fall_at: float = 2.3
@export_range(0.5, 5.0, 0.05, "suffix:s") var suit_fall_seconds: float = 2.2
@export_range(0.5, 6.0, 0.05, "suffix:s") var leap_at: float = 2.75
@export_range(0.5, 3.0, 0.05, "suffix:s") var transition_leap_seconds: float = 1.5

@export_group("The Magnate: the overtake")
## DESIGN-TBD (GDD §10: "he overtakes along a wall or ceiling, lands ahead, then drops back"; proposed: the
## balustrades, out of the runner's reach): an overtake beat lasts this long (divided by the phase's pace): up
## onto the nearer balustrade, past the runner along it to overtake_ahead ahead (framing), a leap across the
## causeway high over the lanes (overtake_height) onto the other balustrade, then back behind the runner.
@export_range(2.0, 10.0, 0.1, "suffix:s") var overtake_seconds: float = 4.4
@export_range(5.0, 40.0, 0.5, "suffix:m") var overtake_ahead: float = 15.0
@export_range(3.0, 12.0, 0.5, "suffix:m") var overtake_height: float = 6.5

@export_group("The Magnate: the Pounce")
## DESIGN-TBD (GDD §10, proposed: "with a roar, his marker turns red and he leaps from behind over the runner,
## locking onto their lane about a second before he lands; a red square marks where he'll land, ahead in that
## lane. Dodge: leave the lane. He crashes down, then bounds off onto a balustrade or an arch and drops back
## behind"). The roar (and the marker red) comes pounce_windup before his leap; the leap lasts pounce_flight;
## its last lock_seconds (never divided by the phase's pace: the dodge keeps its second) the lane is locked and
## the red square shows. The rest of the windup and the flight are divided by the pace.
@export_range(0.2, 2.0, 0.05, "suffix:s") var pounce_windup: float = 0.75
@export_range(1.0, 3.0, 0.05, "suffix:s") var pounce_flight: float = 1.7
@export_range(0.8, 2.0, 0.05, "suffix:s") var lock_seconds: float = 1.05
## He lands this long (at the run speed) before the runner would reach the square: in front of them, where
## they'd be. The square is crash_depth deep along the lane (his body, metres).
@export_range(0.0, 0.6, 0.01, "suffix:s") var land_lead: float = 0.15
@export_range(2.0, 6.0, 0.1, "suffix:m") var crash_depth: float = 3.6
## The leap's height over the runner.
@export_range(3.0, 12.0, 0.25, "suffix:m") var pounce_apex: float = 5.5
## The crash: an enemy attack over this share of the lane's width, up to crash_height (above a jump's reach),
## live from his landing until the runner is past the square (at least crash_min, at most crash_max; he
## crouches there meanwhile); then he bounds off onto a balustrade over bound_seconds (divided by the pace).
@export_range(0.4, 1.0, 0.01) var crash_width_share: float = 0.84
@export_range(2.8, 6.0, 0.05, "suffix:m") var crash_height: float = 3.2
@export_range(0.1, 1.0, 0.05, "suffix:s") var crash_min: float = 0.3
@export_range(0.3, 2.5, 0.05, "suffix:s") var crash_max: float = 1.2
@export_range(0.2, 2.0, 0.05, "suffix:s") var bound_seconds: float = 0.55

@export_group("The Magnate: the bait")
## DESIGN-TBD (GDD §10, proposed: "a Flying Buttress comes up ahead for every second Pounce. Locked onto the
## buttress's lane as the runner reaches it, he crashes into the gate, too big to fit through, and is stunned:
## he slumps in its rubble across two lanes, his back to the runner, the red ports on his spine glowing. The
## runner stomps a port by jumping onto his back (from either lane). If they haven't by the time they're nearly
## on him, he shakes free and leaps away (a miss), and the bait comes around again"). A bait Pounce raises its
## buttress (an inner lane, by the fight's seed) bait_sight before the runner reaches it (at least
## buttress_sight); his landing is timed so that, locked onto its lane, he crashes into the gate stun_lead before
## the runner reaches his back (never divided by the pace: the way onto his back keeps its time).
@export_range(4.0, 12.0, 0.1, "suffix:s") var bait_sight: float = 6.5
@export_range(0.8, 3.0, 0.05, "suffix:s") var stun_lead: float = 1.6
## The release: a runner still on the floor stun_release (at the run speed) short of his back, or one past him,
## and he shakes free and leaps away (a miss) before they reach him.
@export_range(0.1, 0.6, 0.01, "suffix:s") var stun_release: float = 0.25
## His weak points: a stomp box over his back in each of his two lanes, reaching stun_reach (at 18 m/s,
## stretched by the run's pace) from his back toward the runner and stun_stomp_top above it: generous, like The
## House's hopper and the Floating Head's domes.
@export_range(0.5, 6.0, 0.1, "suffix:m") var stun_reach: float = 3.5
@export_range(0.1, 1.0, 0.05, "suffix:m") var stun_stomp_top: float = 0.4
## After a stomp he hurls himself clear, howling, and drops back behind over this long: the next phase's intro
## (BossPhase.intro_seconds).
@export_range(1.0, 5.0, 0.05, "suffix:s") var hurl_seconds: float = 2.3

@export_group("The Magnate: the Cable Lash")
## DESIGN-TBD (GDD §10, proposed: "running along a balustrade beside the track, he rears back one of his
## broadcast cables (with a rising crackle) and whips it across every lane ahead: low, jump it; high, slide under
## it. A red line across the floor shows where it will sweep, as with the Floating Head's lasers"). He runs up
## along a balustrade (lash_run_up, divided by the pace) and plants himself where the cable will cross; the
## warning (the rearing, the crackle, the red line across every lane and thin red aim lines at its heights) lasts
## lash_warning (never divided by the pace); the whip crosses every lane in lash_sweep and lies across them
## lash_cross_lead before the runner gets there, until lash_after after they're past; then he yanks it back
## (lash_yank) and drops back.
@export_range(1.0, 4.0, 0.05, "suffix:s") var lash_run_up: float = 2.3
@export_range(0.8, 2.0, 0.05, "suffix:s") var lash_warning: float = 1.25
@export_range(0.1, 0.8, 0.05, "suffix:s") var lash_sweep: float = 0.25
@export_range(0.1, 1.0, 0.05, "suffix:s") var lash_cross_lead: float = 0.3
@export_range(0.1, 1.0, 0.05, "suffix:s") var lash_after: float = 0.35
@export_range(0.1, 1.0, 0.05, "suffix:s") var lash_yank: float = 0.4
## Its heights, as the Floating Head's sweeps': a low lash at lash_low (jump it: a sliding runner is 0.45 m
## tall); a high one a cable at lash_high and a second above it at lash_high_top, the shape of a gapped fence
## (slide under both: a standing runner meets the lower one, a jump can't clear the upper one or fit between
## them). The cables' hitboxes are lash_radius thick (thinner than drawn).
@export_range(0.1, 0.8, 0.01, "suffix:m") var lash_low: float = 0.35
@export_range(0.55, 1.05, 0.01, "suffix:m") var lash_high: float = 0.85
@export_range(1.2, 2.2, 0.05, "suffix:m") var lash_high_top: float = 1.9
@export_range(0.03, 0.3, 0.01, "suffix:m") var lash_radius: float = 0.09

@export_group("The Magnate: the defeat")
## DESIGN-TBD (GDD §10, proposed: "the third stomp: he convulses, his cables tear out of his back one by one, and
## the screens on the towers glitch and go dark, one after another outward. The music cuts out with them. In the
## silence he collapses on the causeway ahead, the last light in his cracks goes out, and the runner runs past
## him; then the victory riff"). He lurches ahead of the runner over defeat_lurch, into the lane furthest from
## them, defeat_ahead (at the run speed) in front; a cable tears out every tear_every from tear_at; the screens
## glitch, and go dark outward from him at blackout_speed (out to blackout_reach, then every screen in the world),
## from blackout_at, when the music cuts out (over music_cut); he collapses once the last cable is out, over
## collapse_seconds, the light in his cracks dying over crack_fade.
@export_range(0.3, 3.0, 0.05, "suffix:s") var defeat_lurch: float = 1.2
@export_range(0.5, 3.0, 0.05, "suffix:s") var defeat_ahead: float = 1.5
@export_range(0.0, 3.0, 0.05, "suffix:s") var tear_at: float = 0.6
@export_range(0.1, 1.0, 0.05, "suffix:s") var tear_every: float = 0.3
@export_range(0.0, 3.0, 0.05, "suffix:s") var blackout_at: float = 0.9
@export_range(10.0, 300.0, 5.0, "suffix:m/s") var blackout_speed: float = 90.0
@export_range(100.0, 2000.0, 10.0, "suffix:m") var blackout_reach: float = 700.0
@export_range(0.0, 2.0, 0.05, "suffix:s") var music_cut: float = 0.25
@export_range(0.3, 3.0, 0.05, "suffix:s") var collapse_seconds: float = 1.1
@export_range(0.3, 4.0, 0.05, "suffix:s") var crack_fade: float = 1.4
## DESIGN-TBD (docs/questions/e5d.md, 13: "should the riff play at all, or should the fight end in silence like
## the Sleep Taker's?"): the victory riff once the runner is past him (riff_after later), or silence.
@export var victory_riff_on: bool = true
@export_range(0.0, 2.0, 0.05, "suffix:s") var riff_after: float = 0.35
