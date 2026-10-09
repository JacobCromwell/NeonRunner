class_name SewerSwarmIntroTuning
extends Resource
## The Gangland boss intro's numbers (SewerSwarmIntro; data/cinematics/sewer_swarm_intro.tres). The beats are the
## owner's (October 9, 2026; GDD §10, Sewer Swarm): one screech at 2 s, three at 3 s (two on one side, one on the
## other), eleven at 4 s (five on the left, six on the right), then more and more pouring out and dropping from
## the sky, a wall of them chasing the runner, and one cut to the mass with the Host's glint in its dark heart; the
## camera at ground level throughout. The rest (how the runner dodges, distances, counts, the camera's exact
## places) is DESIGN-TBD (docs/OPEN_QUESTIONS.md §D, items 387–395). Times are seconds from the start; points are track space
## (CineStage: x metres right of the runner's lane, y up, z ahead).

@export_group("Timing")
## GDD §1: 5-15 s. It ends on black: the fight opens on its own view.
@export_range(5.0, 15.0, 0.1, "suffix:s") var duration: float = 12.0
@export_range(0.0, 2.0, 0.05, "suffix:s") var fade_in: float = 0.6
@export_range(0.0, 2.0, 0.05, "suffix:s") var fade_out: float = 0.55
## The fight's music fades in over this.
@export_range(0.0, 4.0, 0.1, "suffix:s") var music_fade: float = 1.0
## The street the runner runs down (metres; the finish line the track builder draws at its end stays out of view).
@export_range(300.0, 2000.0, 10.0, "suffix:m") var stage_length: float = 600.0

@export_group("The runner")
## Where the runner is at the start, metres along the track; they run at the zone's run speed, the fight's.
@export_range(0.0, 100.0, 0.5, "suffix:m") var runner_start: float = 20.0
## The first screech: the runner jumps over it, at the top of the jump at `jump_at`.
@export_range(1.0, 5.0, 0.01, "suffix:s") var jump_at: float = 2.4
@export_range(0.3, 1.0, 0.01, "suffix:s") var jump_seconds: float = 0.6
@export_range(0.5, 2.5, 0.05, "suffix:m") var jump_height: float = 1.25
## The second beat's lone screech leaps over the runner's lane as they slide under it, mid-slide at `slide_at`.
@export_range(2.0, 6.0, 0.01, "suffix:s") var slide_at: float = 3.42
@export_range(0.3, 1.2, 0.01, "suffix:s") var slide_seconds: float = 0.55
## Its other two land in the runner's lane ahead; the runner weaves round them, this far to the right at the
## weave's middle (`weave_at`).
@export_range(2.0, 6.0, 0.01, "suffix:s") var weave_at: float = 4.1
@export_range(0.3, 1.5, 0.01, "suffix:s") var weave_seconds: float = 0.7
@export_range(0.5, 2.5, 0.05, "suffix:m") var weave_side: float = 1.4

@export_group("The first screeches")
## The owner's beats: one at the first, three at the second (`second_right` on the right, the rest on the left),
## eleven at the third (`third_left` on the left, `third_right` on the right).
@export_range(0.5, 5.0, 0.05, "suffix:s") var first_burst: float = 2.0
@export_range(0.5, 6.0, 0.05, "suffix:s") var second_burst: float = 3.0
@export_range(0.5, 7.0, 0.05, "suffix:s") var third_burst: float = 4.0
@export_range(0, 12) var third_left: int = 5
@export_range(0, 12) var third_right: int = 6
## The warning before a manhole bursts (GDD §9.5: the cover rattles, its slots glowing): this long.
@export_range(0.1, 1.5, 0.05, "suffix:s") var shake_seconds: float = 0.45
## Out of the hole this long after it bursts, then the leap.
@export_range(0.0, 0.5, 0.01, "suffix:s") var emerge_seconds: float = 0.1
## A pounce's arc over its straight line, and the height the second beat's leaper crosses over the runner's lane.
@export_range(0.0, 2.0, 0.05, "suffix:m") var leap_height: float = 0.7
@export_range(1.0, 3.0, 0.05, "suffix:m") var over_height: float = 1.45
## The third beat's: their manholes from this far ahead of the runner (as they burst) over this stretch; they land
## this far either side of the runner's lane and rear up as the runner runs past them.
@export_range(2.0, 40.0, 0.5, "suffix:m") var third_from: float = 10.0
@export_range(10.0, 80.0, 1.0, "suffix:m") var third_span: float = 32.0
@export_range(1.0, 4.0, 0.05, "suffix:m") var third_land: float = 1.7
## Once past the runner they give chase at this share of the run speed, so they fall behind.
@export_range(0.2, 1.0, 0.01) var chase_share: float = 0.6

@export_group("The manholes")
## Manholes along both sides of the runner, one lane over: one every `lair_spacing` metres a side (the sides
## staggered), moved up to `lair_jitter` along, none within `lair_clear` of the beats' own on its side.
@export_range(3.0, 20.0, 0.5, "suffix:m") var lair_spacing: float = 6.5
@export_range(0.0, 4.0, 0.1, "suffix:m") var lair_jitter: float = 1.2
@export_range(0.5, 6.0, 0.1, "suffix:m") var lair_clear: float = 3.0
## They line the street from behind the runner's start to this far past where the runner is at the cut.
@export_range(0.0, 80.0, 1.0, "suffix:m") var lairs_past: float = 30.0

@export_group("The pour")
## From `pour_from` to `pour_to` the manholes around the runner burst one after another, more and more of them,
## each between `pour_lead_min` and `pour_lead_max` seconds before the runner reaches it (below 0: after they
## pass it), and those up to `pour_behind` metres behind the runner as it starts; each pours out from `pour_first`
## screeches (the first) to `pour_last` (the last), which run along beside the runner.
@export_range(2.0, 10.0, 0.05, "suffix:s") var pour_from: float = 5.0
@export_range(3.0, 12.0, 0.05, "suffix:s") var pour_to: float = 9.4
@export_range(-2.0, 2.0, 0.05, "suffix:s") var pour_lead_min: float = -0.6
@export_range(-2.0, 3.0, 0.05, "suffix:s") var pour_lead_max: float = 1.0
@export_range(0.0, 60.0, 1.0, "suffix:m") var pour_behind: float = 25.0
@export_range(0, 12) var pour_first: int = 2
@export_range(0, 16) var pour_last: int = 6
## A low-end device pours out this share of them.
@export_range(0.1, 1.0, 0.05) var pour_low_end_share: float = 0.5

@export_group("The rain")
## From `rain_from` to `rain_to`, more and more of them (`rain_count`, `rain_count_low_end` on a low-end device)
## drop from `rain_height` (above the camera's view), falling at `rain_gravity`, and land beside the runner
## between `rain_behind` behind them and `rain_ahead` ahead.
@export_range(2.0, 12.0, 0.05, "suffix:s") var rain_from: float = 5.6
@export_range(3.0, 12.0, 0.05, "suffix:s") var rain_to: float = 9.2
@export_range(0, 400, 5) var rain_count: int = 110
@export_range(0, 200, 5) var rain_count_low_end: int = 45
@export_range(4.0, 30.0, 0.5, "suffix:m") var rain_height: float = 11.0
@export_range(5.0, 40.0, 0.5, "suffix:m/s²") var rain_gravity: float = 22.0
@export_range(0.0, 20.0, 0.5, "suffix:m") var rain_behind: float = 8.0
@export_range(0.0, 10.0, 0.5, "suffix:m") var rain_ahead: float = 3.0

@export_group("Beside the runner")
## The pour and the rain run beside the runner, never in their lane: at least `beside_inner` from its middle and
## `beside_wall` from the walls, at between `speed_share_min` and `speed_share_max` of the run speed; after
## `fall_back_after` seconds they drop back, slowing by `fall_back` m/s², into the wall chasing the runner.
@export_range(0.6, 2.0, 0.05, "suffix:m") var beside_inner: float = 1.1
@export_range(0.1, 1.5, 0.05, "suffix:m") var beside_wall: float = 0.45
@export_range(0.5, 1.1, 0.01) var speed_share_min: float = 0.93
@export_range(0.5, 1.1, 0.01) var speed_share_max: float = 1.0
@export_range(0.0, 5.0, 0.1, "suffix:s") var fall_back_after: float = 1.2
@export_range(0.0, 10.0, 0.1, "suffix:m/s²") var fall_back: float = 2.5

@export_group("The wall")
## From `wall_from` the swarm rises behind the runner over `rise_seconds`: a wall of them across the street
## (`wall_inset` in from each wall) curling over like a breaking wave (`wave_height` tall, its crest `wave_reach`
## forward), with the rest of the swarm behind it (`mass_length` long, `mass_height` high). Its foot is
## `gap_start` metres behind the runner as it rises, `gap_cut` at the cut (`gap_ease`: 0 closing steadily, 1
## faster and faster), and it closes in by `close_after_cut` m/s after.
@export_range(3.0, 11.0, 0.05, "suffix:s") var wall_from: float = 6.3
@export_range(0.2, 4.0, 0.1, "suffix:s") var rise_seconds: float = 2.2
@export_range(0.0, 1.0, 0.05, "suffix:m") var wall_inset: float = 0.3
@export_range(2.0, 12.0, 0.25, "suffix:m") var wave_height: float = 6.0
@export_range(2.0, 20.0, 0.5, "suffix:m") var wave_reach: float = 8.5
@export_range(5.0, 60.0, 1.0, "suffix:m") var mass_length: float = 26.0
@export_range(0.5, 4.0, 0.05, "suffix:m") var mass_height: float = 2.0
@export_range(8.0, 60.0, 0.5, "suffix:m") var gap_start: float = 32.0
@export_range(3.0, 20.0, 0.5, "suffix:m") var gap_cut: float = 9.0
@export_range(0.0, 1.0, 0.05) var gap_ease: float = 0.5
@export_range(0.0, 5.0, 0.1, "suffix:m/s") var close_after_cut: float = 0.7
## Creatures in the wave and in the mass behind it (fewer on a low-end device).
@export_range(50, 2000, 10) var wave_creatures: int = 900
@export_range(20, 1000, 10) var wave_creatures_low_end: int = 360
@export_range(50, 2000, 10) var mass_creatures: int = 560
@export_range(20, 1000, 10) var mass_creatures_low_end: int = 220
## How hot it glows as it closes in (its spines and silhouette toward enemy-attack red: 0.25 none, 1 a surge's
## height), from `heat_from` as it rises to `heat_cut` at the cut.
@export_range(0.25, 1.0, 0.01) var heat_from: float = 0.25
@export_range(0.25, 1.0, 0.01) var heat_cut: float = 0.5

@export_group("The cut")
## The one cut, to the mass: a dark hollow in its middle (`maw_size`: width, height and depth), `maw_forward`
## in front of the wall's foot with its middle `maw_height` up, ringed by `mound_creatures` screeches heaped
## `mound_width` out from its rim and sloping back to the wall; in the dark the Host (held up, its look darkened
## by `host_shade`), and `glint_after` into the cut the glint of the implant at its temple (`glint_size` across).
@export_range(6.0, 14.0, 0.05, "suffix:s") var cut_at: float = 9.6
@export var maw_size: Vector3 = Vector3(1.9, 2.3, 1.0)
@export_range(0.5, 4.0, 0.05, "suffix:m") var maw_forward: float = 2.0
@export_range(0.5, 4.0, 0.05, "suffix:m") var maw_height: float = 1.75
@export_range(0, 400, 5) var mound_creatures: int = 110
@export_range(0, 200, 5) var mound_creatures_low_end: int = 50
@export_range(0.2, 3.0, 0.05, "suffix:m") var mound_width: float = 1.6
@export_range(0.0, 1.0, 0.01) var host_shade: float = 0.7
@export_range(0.1, 2.5, 0.05, "suffix:s") var glint_after: float = 0.9
@export_range(0.1, 2.0, 0.05, "suffix:m") var glint_size: float = 1.0

@export_group("Camera")
## At ground level throughout (owner): low behind the runner looking down the street (offsets from the runner's
## line: x right, y up, z ahead)...
@export var behind: Vector3 = Vector3(0.45, 0.75, -3.6)
@export var behind_look: Vector3 = Vector3(0.0, 1.0, 14.0)
@export_range(30.0, 100.0, 0.5, "suffix:°") var behind_fov: float = 70.0
## ...swinging round the runner's right side between `swing_from` and `swing_to`, at most `swing_side` out to
## their side (and always `swing_wall` off the wall)...
@export_range(2.0, 9.0, 0.05, "suffix:s") var swing_from: float = 5.0
@export_range(3.0, 10.0, 0.05, "suffix:s") var swing_to: float = 6.4
@export_range(0.5, 5.0, 0.05, "suffix:m") var swing_side: float = 2.2
@export_range(0.5, 3.0, 0.05, "suffix:m") var swing_wall: float = 1.2
## ...to low in front of them looking back past them (from `front` and `front_look` to `front_end` and
## `front_look_end` by the cut, tilting up as the wall looms)...
@export var front: Vector3 = Vector3(0.35, 0.62, 4.8)
@export var front_end: Vector3 = Vector3(0.3, 0.58, 4.0)
@export var front_look: Vector3 = Vector3(0.0, 1.6, -12.0)
@export var front_look_end: Vector3 = Vector3(0.0, 3.0, -9.0)
@export_range(30.0, 100.0, 0.5, "suffix:°") var front_fov: float = 70.0
## ...and after the cut low between the runner and the wall, looking into the hollow (from `cut_camera` to
## `cut_camera_end`).
@export var cut_camera: Vector3 = Vector3(0.15, 0.5, -0.8)
@export var cut_camera_end: Vector3 = Vector3(0.1, 0.55, -1.2)
@export_range(30.0, 100.0, 0.5, "suffix:°") var cut_fov: float = 60.0
## A key every this long (smooth between them).
@export_range(0.05, 1.0, 0.05, "suffix:s") var camera_key_step: float = 0.2
## The ground shakes as the wall closes in, and in the cut (the Screen shake setting scales both).
@export_range(0.0, 0.3, 0.005, "suffix:m") var approach_shake: float = 0.05
@export_range(0.0, 0.3, 0.005, "suffix:m") var cut_shake: float = 0.03
