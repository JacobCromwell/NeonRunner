class_name FloatingHeadTuning
extends Resource
## The Floating Head's numbers (GDD §10; data/bosses/city_boss_tuning.tres, F6 in its fight). Timings
## are at pace 1: each phase divides them by its BossPhase.pace (GDD §10: the next phase is faster).
## The GDD fixes the first bombing run's length (about 15-20 s), the searchlight that warns where the
## bombs fall and their falling whistle; every other number here is a placeholder (DESIGN-TBD,
## docs/OPEN_QUESTIONS.md §D, items 83-92, 113-123 and the stomp windows' 158-170; the propaganda and
## the defeat: docs/questions/e1.md, From E1d).
## The fight's length (GDD §10: 60-120 s; item 169) comes from the bombing runs, the attacks before a
## tower and the towers' spacing. DESIGN-TBD (docs/questions/e1.md, From E1d, item 4): placeholders
## that bring a runner who never misses to about 100 s (a 16 s first run, two 8 s later runs, towers
## every 240 m, two attacks before one, and the laser clipping every other tower on its own for a
## runner who doesn't bait them).

@export_group("Ship")
## DESIGN-TBD (docs/OPEN_QUESTIONS.md §D, items 83-84): the hull fills the street between the walls (a
## giant ship in a street canyon), less this on each side; its loudspeaker "ears" stand out into
## that margin. The walls of its arena carry no signs, so nothing on them reaches the ship.
@export_range(0.5, 2.0, 0.05, "suffix:m") var street_margin: float = 0.6
## From the face (the stern, toward the player) to the bow.
@export_range(12.0, 40.0, 0.5, "suffix:m") var hull_length: float = 24.0
## The head's height, belly to crown, on a 3-lane street and on a 6-lane one (by width in between).
@export_range(6.0, 16.0, 0.25, "suffix:m") var head_height_narrow: float = 10.5
@export_range(6.0, 16.0, 0.25, "suffix:m") var head_height_wide: float = 12.0

@export_group("Entrance")
## DESIGN-TBD (docs/OPEN_QUESTIONS.md §D, item 85): the first phase's intro (its
## BossPhase.intro_seconds): the ship roars in overhead from behind the player, its stern starting
## this far behind them and its belly this high, and pulls ahead to its bombing station. The run
## starts when it gets there.
@export_range(10.0, 80.0, 1.0, "suffix:m") var enter_behind: float = 42.0
@export_range(6.0, 30.0, 0.5, "suffix:m") var enter_height: float = 10.5

@export_group("Bombing run")
## GDD §10: the first run lasts about 15-20 s (from the searchlight switching on to its last bomb).
@export_range(5.0, 30.0, 0.5, "suffix:s") var first_run_seconds: float = 16.0
## GDD §10: once or twice during the fight it rises for another, shorter run. DESIGN-TBD
## (docs/OPEN_QUESTIONS.md §D, item 89): at the start of the next `later_runs` phases, after it rises
## back into the sky (0 = never).
@export_range(0.0, 20.0, 0.5, "suffix:s") var later_run_seconds: float = 8.0
@export_range(0, 2) var later_runs: int = 2
## DESIGN-TBD (item 85): its station during a run: its stern this far ahead of the player and its
## belly this high, so it looms over the top of the screen with its searchlight pointing back at the
## lanes.
@export_range(10.0, 60.0, 0.5, "suffix:m") var station_ahead: float = 34.0
@export_range(8.0, 30.0, 0.5, "suffix:m") var station_height: float = 12.0

@export_group("Searchlight")
## DESIGN-TBD (docs/OPEN_QUESTIONS.md §D, item 86): how fast the light's spot sweeps sideways across
## the lanes.
@export_range(2.0, 40.0, 0.5, "suffix:m/s") var sweep_speed: float = 10.0
## After each blast the light swings away across the lanes, up to this many lanes from the player,
## before it comes back to hunt them, and sweeps at least this long before it can linger again.
@export_range(1, 4) var sweep_out_lanes: int = 2
@export_range(0.0, 3.0, 0.05, "suffix:s") var sweep_seconds: float = 0.6
## The spot rests on the player's lane this long before it locks on.
@export_range(0.0, 1.0, 0.02, "suffix:s") var settle_seconds: float = 0.12
## The warning: from the light lingering on a spot (it turns red, the target circle shows, the lock
## sound plays and the bomb falls with its whistle) to the blast.
@export_range(0.5, 3.0, 0.05, "suffix:s") var lock_seconds: float = 1.1
## Every n-th lock of a run covers two lanes side by side, so the player has to pick the free side
## (0 = never).
@export_range(0, 8) var straddle_every: int = 3
## The light's spot on the floor (radius): a lane wide; a straddle's spans both lanes.
@export_range(0.5, 3.0, 0.05, "suffix:m") var spot_radius: float = 1.35

@export_group("Bombs")
## DESIGN-TBD (docs/OPEN_QUESTIONS.md §D, item 87): the bomb is aimed at where the player will be:
## they would reach the blast's centre this long after it goes off, when the fireball is at its
## biggest.
@export_range(0.0, 0.3, 0.01, "suffix:s") var arrival_seconds: float = 0.1
## How long a blast burns (its hitbox is live).
@export_range(0.1, 1.0, 0.05, "suffix:s") var blast_seconds: float = 0.35
## The target circle's radius, and the fireball's.
@export_range(0.5, 2.0, 0.05, "suffix:m") var blast_radius: float = 1.1
## The blast's hitbox: its share of the lane's width, its depth along the track and its height
## (too tall to jump over). Forgiving (GDD §3): a little smaller than the fireball, and on an outer
## lane it keeps clear of a wall runner beside it.
@export_range(0.3, 1.0, 0.05) var blast_width_share: float = 0.7
@export_range(0.5, 3.0, 0.05, "suffix:m") var blast_depth: float = 1.9
@export_range(1.0, 4.0, 0.1, "suffix:m") var blast_height: float = 2.4

@export_group("Fairness")
## DESIGN-TBD (docs/OPEN_QUESTIONS.md §D, item 88): a bomb only falls where the lanes it strikes are
## free of holes and fences from this far before the blast to this far after it: it lands on a
## roof, and nothing else needs dodging there.
@export_range(0.0, 20.0, 0.5, "suffix:m") var clear_before_impact: float = 8.0
@export_range(0.0, 20.0, 0.5, "suffix:m") var clear_after_impact: float = 5.0
## ...and only where the player has a way out: a lane it doesn't strike, at most this many lanes
## away, with that lane and every lane on the way free of holes and fences from the player to this far
## past the blast, so the dodge is a plain lane switch.
@export_range(1, 3) var max_escape_lanes: int = 2
@export_range(0.0, 20.0, 0.5, "suffix:m") var escape_clear_after: float = 5.0
## ...and never on a pickup waiting in its lane within this distance.
@export_range(0.0, 10.0, 0.5, "suffix:m") var pickup_margin: float = 3.0

@export_group("Reveal")
## DESIGN-TBD (docs/OPEN_QUESTIONS.md §D, item 90): after a run it drops in front of the player, its
## stern this far ahead and its belly this high: above the fences' stacks (2.5 m), so the track stays
## in view under it.
@export_range(1.0, 6.0, 0.1, "suffix:s") var descend_seconds: float = 3.0
@export_range(10.0, 60.0, 0.5, "suffix:m") var face_ahead: float = 26.0
@export_range(2.6, 10.0, 0.1, "suffix:m") var face_height: float = 3.0
## GDD §10's reveal: the first time it drops in front of the player, its back turns out to be a face.
## The face screen powers on this long before it settles (and takes this long to come on).
@export_range(0.5, 4.0, 0.1, "suffix:s") var boot_seconds: float = 1.6

@export_group("Face-off")
## DESIGN-TBD (docs/OPEN_QUESTIONS.md §D, item 116): the face-off's attacks, one list per phase (the
## last list for any later phase), taken in turn over and over (when one can't start fairly, the next
## in line that can goes first): "low" (the eye lasers sweep across the lanes low: jump them), "high"
## (high: slide under them), "drag" (they burn down the runner's lane: switch lanes) and "drop" (the
## cyborg drop). A drag timed for each marked tower comes on top (Towers). It hovers at its face pose
## (Reveal) for the lasers. These and the timings below set the face-off's pace.
@export var faceoff_patterns: PackedStringArray = ["low,drag,high,drop,drag", "high,drag,low,drop,low,drag",
	"drag,high,low,drop,drag,high,drop"]
## Seconds from one attack's end to the next one's warning, and to move between its places.
@export_range(0.0, 4.0, 0.05, "suffix:s") var attack_gap: float = 0.8
@export_range(0.2, 3.0, 0.05, "suffix:s") var move_seconds: float = 0.9

@export_group("Eye lasers")
## GDD §10 (proposed): "the eyes glow and whine, then twin beams sweep across the lanes". DESIGN-TBD
## (docs/OPEN_QUESTIONS.md §D, items 113-115): the warning: the eyes glow red and whine for this long
## while thin aiming beams show where the attack goes.
@export_range(0.4, 3.0, 0.05, "suffix:s") var laser_charge_seconds: float = 1.0
## Where a sweep's twin beams cross the runner's spot: a low sweep's both at sweep_low_height (jump
## them: a sliding runner is 0.45 m tall); a high sweep's one at sweep_high_height and the other at
## sweep_high_top, the shape of a gapped fence (slide under both: a standing runner, 1.09 m tall, meets
## the lower one, and a jump can't clear the upper one or fit between them).
@export_range(0.1, 0.8, 0.01, "suffix:m") var sweep_low_height: float = 0.35
@export_range(0.55, 1.05, 0.01, "suffix:m") var sweep_high_height: float = 0.85
@export_range(1.2, 2.2, 0.05, "suffix:m") var sweep_high_top: float = 1.9
## How fast a sweep crosses the street from wall to wall.
@export_range(4.0, 40.0, 0.5, "suffix:m/s") var laser_sweep_speed: float = 13.0
## The beams' hitbox radius (thinner than the beams you see).
@export_range(0.03, 0.3, 0.01, "suffix:m") var beam_radius: float = 0.08
## A drag: the beams land under the face in the lane they aimed at and burn down it, reaching the
## runner's spot this long after (the time to switch lanes), leaving a burning line that lasts
## burn_seconds, burn_width_share of a lane wide (clear of a wall runner beside an outer lane) and
## burn_height tall (too tall to jump for long).
@export_range(0.4, 3.0, 0.05, "suffix:s") var drag_seconds: float = 1.0
@export_range(0.1, 3.0, 0.05, "suffix:s") var burn_seconds: float = 0.8
@export_range(0.3, 1.0, 0.05) var burn_width_share: float = 0.7
@export_range(0.5, 3.0, 0.1, "suffix:m") var burn_height: float = 1.4
## Fairness: a sweep only comes while the floor is clear of holes and fences in every lane from the
## runner to this far past where they will be when it has crossed the street (it's dodged with a
## jump or a slide); a drag needs a free lane beside it like a bomb (Fairness above).
@export_range(0.0, 30.0, 0.5, "suffix:m") var sweep_clear_after: float = 10.0

@export_group("Cyborg drop")
## GDD §10: "its mouth opens and drops 1–2 cyborgs onto the trucks ahead, who then fight like normal
## cyborgs". DESIGN-TBD (docs/OPEN_QUESTIONS.md §D, items 117-118): it pulls back to drop them this
## far ahead (room for them to fight), its belly this high; the mouth opens (the warning, with its
## grinding sound and red circles where they'll land) this long before the first drops, the cyborgs
## drop drop_interval apart and fall for drop_fall_seconds.
@export_range(20.0, 90.0, 0.5, "suffix:m") var drop_ahead: float = 50.0
@export_range(0.5, 10.0, 0.1, "suffix:m") var drop_height: float = 2.6
@export_range(0.3, 3.0, 0.05, "suffix:s") var mouth_seconds: float = 0.8
@export_range(0.1, 2.0, 0.05, "suffix:s") var drop_interval: float = 0.4
@export_range(0.2, 2.0, 0.05, "suffix:s") var drop_fall_seconds: float = 0.6
## Cyborgs per drop, one number per phase (the last for any later phase): GDD §10, "the next phase is
## faster, with more cyborgs".
@export var cyborgs_per_drop: PackedInt32Array = [1, 2, 2]
## DESIGN-TBD (docs/OPEN_QUESTIONS.md §D, item 118): its lasers wait while a cyborg it dropped is
## still ahead of the runner (no big attacks at once, GDD §9), at most this long.
@export_range(0.0, 10.0, 0.1, "suffix:s") var drop_hold_max: float = 4.0

@export_group("Towers")
## GDD §10: "marked, cracked towers stand ahead at the roadside". DESIGN-TBD (docs/OPEN_QUESTIONS.md
## §D, items 119-121): one every tower_spacing metres (sides in turn), the first tower_first into each
## lap, tower_height tall (its head, the top 30%, juts out over the street above the ship's highest
## flight) and tower_width wide. The track stays clear of holes and fences from tower_clear_before
## before a tower to tower_clear_after past it (the pin, the ways onto its head, and the run up to it).
@export_range(80.0, 800.0, 5.0, "suffix:m") var tower_spacing: float = 240.0
@export_range(0.0, 800.0, 5.0, "suffix:m") var tower_first: float = 240.0
@export_range(15.0, 80.0, 0.5, "suffix:m") var tower_height: float = 40.0
@export_range(2.0, 8.0, 0.1, "suffix:m") var tower_width: float = 3.6
@export_range(0.0, 150.0, 1.0, "suffix:m") var tower_clear_before: float = 90.0
@export_range(0.0, 150.0, 1.0, "suffix:m") var tower_clear_after: float = 50.0
## For each marked tower it takes aim from this far ahead (its belly at the face pose's height), so its
## drag's first strike lands beside the tower just as it passes the face: in the tower's lane when the
## runner leads the beam there (the bait), or at the tower anyway once fallback_after towers have gone
## by in the phase (GDD §10: "the laser eventually clips a tower on its own").
@export_range(20.0, 90.0, 0.5, "suffix:m") var tower_ahead: float = 48.0
@export_range(0, 6) var fallback_after: int = 1
## A face-off shows this many of its attacks before it takes aim at a tower (one new thing at a time:
## the lasers first); towers that go by sooner are just scenery.
@export_range(0, 10) var towers_after: int = 2
## GDD §10: "baiting it is faster and scores more". DESIGN-TBD: points for a baited tower.
@export_range(0, 10000, 50) var bait_score: int = 500
## The clipped tower topples forward onto the ship this long (it brakes under it).
@export_range(0.4, 3.0, 0.05, "suffix:s") var tower_fall_seconds: float = 1.1

@export_group("Pinned")
## GDD §10: "the tower topples onto the ship and pins it low across the trucks". DESIGN-TBD
## (docs/OPEN_QUESTIONS.md §D, item 122): pinned, it sinks between the trucks until the highest top of
## its weak points' sockets is this high (so the stomp windows' ways onto its head reach it: a wall jump
## off a free wall entry peaks about 2.9 m up, a ceiling is 6 m), rolled toward the tower by
## pin_roll_degrees (about its crown, so its weak points stay over their lanes), with the tower resting
## on its crown pin_rest_offset behind its face.
@export_range(1.0, 6.0, 0.05, "suffix:m") var pin_top_height: float = 2.5
@export_range(0.0, 20.0, 0.5, "suffix:deg") var pin_roll_degrees: float = 5.0
@export_range(4.0, 20.0, 0.5, "suffix:m") var pin_rest_offset: float = 9.0
@export_range(0.1, 2.0, 0.05, "suffix:s") var pin_sink_seconds: float = 0.35
## DESIGN-TBD (docs/OPEN_QUESTIONS.md §D, item 162): after a missed window it rises back to its
## face pose in this long, and the face-off goes on.
@export_range(0.3, 3.0, 0.05, "suffix:s") var release_seconds: float = 1.1

@export_group("Stomp windows")
## GDD §10: "while it's pinned, the player stomps one [weak point]. Each phase uses a different Zone 1
## skill to get on top: (1) run up the fallen tower like a ramp; (2) wall-jump onto it; (3) ride a
## ship's underside via an anti-grav pad and drop onto it when the hull ends." One word per phase (the
## last for any later phase): "ramp", "wall" or "ceiling".
@export var stomp_routes: PackedStringArray = ["ramp", "wall", "ceiling"]
## DESIGN-TBD (docs/OPEN_QUESTIONS.md §D, item 160): a weak point sits over every lane whose
## centre lies within this share of the ship's width from its centre line (3, 3 and 4 of them at 3, 5
## and 6 lanes).
@export_range(0.2, 0.45, 0.01) var weak_point_reach: float = 0.38
## DESIGN-TBD (item 160): where a stomp counts: a box over each weak point this wide and this deep
## (along the track), from a little under its socket to stomp_top above it; a runner coming down with
## their feet within GameRules.stomp_tolerance under its top stomps it. Generous: the red dome is
## 1.7 m across.
@export_range(1.0, 2.4, 0.05, "suffix:m") var stomp_width: float = 2.0
@export_range(1.0, 5.0, 0.1, "suffix:m") var stomp_depth: float = 3.0
@export_range(0.3, 1.2, 0.05, "suffix:m") var stomp_top: float = 0.55
## DESIGN-TBD (item 162): the window closes (a miss) when the runner is still down on the trucks (feet
## under window_floor_height) within window_release_gap of its face, or has run window_pass_margin past
## its weak points without a stomp. Then it shakes free: no time limit, no escalation (GDD §10).
@export_range(2.0, 20.0, 0.5, "suffix:m") var window_release_gap: float = 8.0
@export_range(0.1, 1.5, 0.05, "suffix:m") var window_floor_height: float = 0.5
@export_range(0.0, 5.0, 0.25, "suffix:m") var window_pass_margin: float = 1.0
## DESIGN-TBD (items 162-163): shaking free (after a stomp or a miss), it lurches shake_ahead further
## ahead of the runner and shake_lift up over shake_seconds (the tower breaks up and drops away), then
## rises.
@export_range(0.2, 2.0, 0.05, "suffix:s") var shake_seconds: float = 0.7
@export_range(2.0, 20.0, 0.5, "suffix:m") var shake_ahead: float = 8.0
@export_range(0.0, 2.0, 0.05, "suffix:m") var shake_lift: float = 0.4
## DESIGN-TBD (item 159): the tower breaks where it crosses this far behind the weak points' stomp
## boxes: the part beyond stays on the ship's back, the part below (towards its foot) drops away or
## makes the ramp.
@export_range(0.5, 8.0, 0.25, "suffix:m") var tower_break_after: float = 2.5

@export_group("Ramp window")
## DESIGN-TBD (docs/OPEN_QUESTIONS.md §D, item 158): the first way up. As the tower crashes onto
## the ship, its broken lower section slams down in the weak point's lane nearest the tower's wall,
## ramp_length long, leaning on the ship's face with its top end ramp_lift above the crown there (the
## runner runs off its end and drops onto the weak point), resting ramp_overhang onto the crown. Solid
## all over: its top is a floor, its sides block a lane switch.
@export_range(6.0, 30.0, 0.5, "suffix:m") var ramp_length: float = 14.0
@export_range(0.2, 2.0, 0.05, "suffix:m") var ramp_lift: float = 0.8
@export_range(0.0, 2.0, 0.05, "suffix:m") var ramp_overhang: float = 0.8
@export_range(0.1, 1.0, 0.05, "suffix:s") var ramp_slam_seconds: float = 0.3

@export_group("Ceiling window")
## DESIGN-TBD (docs/OPEN_QUESTIONS.md §D, item 165): the third way up. As the tower falls,
## anti-grav pads light up in every lane pad_before_face before the ship's pinned face, and a ceiling
## (the zone's ceiling section, a ship's underside) lowers in over them once the ship is past where it
## will end, ceiling_end_before_face before its face (the drop from its end lands on the weak points),
## over ceiling_lower_seconds.
@export_range(12.0, 60.0, 0.5, "suffix:m") var pad_before_face: float = 26.0
@export_range(2.0, 10.0, 0.25, "suffix:m") var ceiling_end_before_face: float = 5.5
@export_range(0.1, 2.0, 0.05, "suffix:s") var ceiling_lower_seconds: float = 0.5

@export_group("Propaganda")
## GDD §10: "a heavily distorted announcement voice that isn't meant to be understood, plus a few short
## slogans shown as text on its face screen (so only those slogans need translating)"
## (FloatingHeadVoice). From the reveal on it shouts a phrase every so often (head_voice_1-4, in a
## seeded order), voice_gap_min to voice_gap_max seconds apart, each with the next slogan on its face
## screen's caption band, which stays up slogan_hold_seconds after the phrase. DESIGN-TBD
## (docs/questions/e1.md, From E1d, items 1-2): the pauses, and the slogans: placeholders until the owner
## writes them. They are the fight's only text (a Label3D, which Godot translates like the UI's labels
## once the game has translations); "\n" breaks a line, and a line keeps to about 12 characters so it
## reads from the runner's distance.
@export_range(0.5, 10.0, 0.1, "suffix:s") var voice_gap_min: float = 1.5
@export_range(0.5, 10.0, 0.1, "suffix:s") var voice_gap_max: float = 3.5
@export var slogans: PackedStringArray = ["EVERY PATH\nLEADS TO HIM", "STAY\nALIGNED", "DON'T RUN.\nCONVERGE.",
	"HE SEES\nYOU", "RETURN TO\nTHE FEED"]
@export_range(0.0, 5.0, 0.1, "suffix:s") var slogan_hold_seconds: float = 1.2
## It never masks an attack's warning: while one is on (FloatingHead.warning_active: a warning or an
## attack of its own, one of its cues just sounded, a cyborg it dropped still about, a pulsing fence
## ahead), the voice ducks voice_duck_db under its level (down in voice_duck_seconds, back up in
## voice_recover_seconds) and the slogan fades out; a new phrase waits until they have been over for
## voice_clear_seconds.
@export_range(-40.0, 0.0, 0.5, "suffix:dB") var voice_duck_db: float = -18.0
@export_range(0.01, 1.0, 0.01, "suffix:s") var voice_duck_seconds: float = 0.06
@export_range(0.05, 3.0, 0.05, "suffix:s") var voice_recover_seconds: float = 0.6
@export_range(0.0, 3.0, 0.05, "suffix:s") var voice_clear_seconds: float = 0.5

@export_group("Defeat")
## GDD §10: "its face glitches, the propaganda cuts out mid-shout, and it crashes into the street ahead;
## the runner runs through the wreck". DESIGN-TBD (docs/questions/e1.md, From E1d, items 3 and 6): pinned, it
## first shakes free as after any stomp; then, its face glitching, it lurches up in front of the runner
## (its face defeat_ahead ahead and its belly defeat_height up) over defeat_glitch_seconds, loses power
## (its face screen collapses to a line and goes dark, its lights die) and plunges forward into the
## street over defeat_fall_seconds.
@export_range(0.3, 4.0, 0.05, "suffix:s") var defeat_glitch_seconds: float = 1.4
@export_range(10.0, 60.0, 0.5, "suffix:m") var defeat_ahead: float = 30.0
@export_range(0.0, 15.0, 0.5, "suffix:m") var defeat_height: float = 4.0
@export_range(0.5, 4.0, 0.05, "suffix:s") var defeat_fall_seconds: float = 1.4
## Where it comes down: its face crash_ahead ahead of the runner as it starts to fall, or further (up to
## crash_search more) at the first spot where the street is clear of holes and fences in every lane from
## crash_clear_before its fallen face to crash_clear_after past the wreck. With none in reach it limps on
## ahead, glitching, until there is one (crash_limp_max seconds at most).
@export_range(20.0, 150.0, 1.0, "suffix:m") var crash_ahead: float = 50.0
@export_range(0.0, 150.0, 1.0, "suffix:m") var crash_search: float = 50.0
@export_range(0.0, 30.0, 0.5, "suffix:m") var crash_clear_before: float = 8.0
@export_range(0.0, 30.0, 0.5, "suffix:m") var crash_clear_after: float = 10.0
@export_range(0.0, 20.0, 0.5, "suffix:s") var crash_limp_max: float = 6.0
## The wreck (FloatingHeadModel's): it hits the street and breaks up; its face tears off and falls flat
## in front of it, and its stern half lies across the street, sunk between the trucks until the roofs
## meet it wreck_floor_share of its height up, where it's widest, so the lanes run through it like a
## tunnel: the runner runs over its dead face and through the wreck. Nothing in it hurts.
@export_range(0.3, 0.5, 0.01) var wreck_floor_share: float = 0.42


## The face-off's attacks for phase `index`, in turn (Face-off).
func faceoff_pattern(index: int) -> PackedStringArray:
	if faceoff_patterns.is_empty():
		return PackedStringArray(["low", "drag", "high"])
	var out := PackedStringArray()
	for word: String in faceoff_patterns[clampi(index, 0, faceoff_patterns.size() - 1)].split(","):
		var w: String = word.strip_edges()
		if w in ["low", "high", "drag", "drop"]:
			out.append(w)
	return out if not out.is_empty() else PackedStringArray(["low", "drag", "high"])


## Cyborgs per drop in phase `index`.
func cyborgs_in_drop(index: int) -> int:
	if cyborgs_per_drop.is_empty():
		return 1
	return maxi(cyborgs_per_drop[clampi(index, 0, cyborgs_per_drop.size() - 1)], 1)


## The way onto its head in phase `index`'s stomp windows (Stomp windows): &"ramp", &"wall" or
## &"ceiling" (an unknown word counts as "ramp").
func stomp_route(index: int) -> StringName:
	if stomp_routes.is_empty():
		return &"ramp"
	var word: String = stomp_routes[clampi(index, 0, stomp_routes.size() - 1)].strip_edges()
	return StringName(word) if word in ["ramp", "wall", "ceiling"] else &"ramp"
