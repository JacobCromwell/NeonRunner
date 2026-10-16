class_name CityIntroTuning
extends Resource
## The City intro's numbers (CityIntro; data/cinematics/city_intro_tuning.tres). The beats are the owner's (October 16,
## 2026, GDD §6 Cinematics, "Zone 1 intro"): the game's first cinematic, about 20 seconds, punchy: a flyby over the
## busy Neon City at night (people, cars, buses and trucks on the streets), the camera following the Floating Head's
## searchlight beam down into the street in one continuous move; at street level cyborgs trudging down the street with
## the Head looming overhead, its face showing, its cold-white searchlight watching over them; the light sweeps past a
## window, the glass bursts just behind it, the runner leaps out, stomps one cyborg and jumps over the others and runs
## down the street, the light whipping back to catch them; the Head startled, then angry, then yelling, the yell going
## through the feed (every cyborg's screen face flickers at once and turns angry) and the cyborgs turning to give chase;
## then Zone 1's title card, and play begins. The rest (the street, the window, how many cyborgs, where everyone stands,
## the camera's places, the sounds) is DESIGN-TBD (docs/questions/f2f.md).
## Positions are metres in the street's own frame: x across from the street's middle (+ right, looking down the track),
## y up from the road, z the track distance (the way the runner runs; 0 where the camera starts at street level). The
## beats' times are seconds from the start.

@export_group("Timing")
## DESIGN-TBD (docs/questions/f2f.md 11): the title card and the ending.
## About 20 s (the owner: longer than GDD §1's 5-15 s is fine for this one).
@export_range(5.0, 40.0, 0.1, "suffix:s") var duration: float = 20.0
@export_range(0.0, 3.0, 0.05, "suffix:s") var fade_in: float = 0.7
## The flyby ends and the street begins (the camera is at street level then); the escape begins (the light turns to the
## window); the Head's part begins (it has seen the runner); the title card comes up; it ends in a fade to black.
@export_range(1.0, 10.0, 0.05, "suffix:s") var street_at: float = 5.0
@export_range(4.0, 14.0, 0.05, "suffix:s") var escape_at: float = 9.0
@export_range(8.0, 18.0, 0.05, "suffix:s") var head_at: float = 13.0
@export_range(14.0, 30.0, 0.05, "suffix:s") var card_at: float = 18.0
@export_range(1.0, 5.0, 0.05, "suffix:s") var card_seconds: float = 2.0
@export_range(0.1, 2.0, 0.05, "suffix:s") var fade_out: float = 0.5
@export_range(0.0, 8.0, 0.1, "suffix:s") var music_fade: float = 4.0

@export_group("The street")
## DESIGN-TBD (docs/questions/f2f.md 1): which street, how wide and how it is dressed.
## 8 lanes: a boulevard 19.8 m wide between its walls, whatever the device's lane count (the Head is built to the street's
## width, as in its fight), with the road far below the truck roofs the levels run on lifted to y = 0.
@export_range(3, 8) var street_lanes: int = 8
@export_range(200.0, 1200.0, 10.0, "suffix:m") var stage_length: float = 420.0
## What the street dresses: from this track distance to this one (behind the camera's start to the end of the fog).
@export_range(-200.0, 0.0, 5.0, "suffix:m") var dress_from: float = -120.0
@export_range(100.0, 400.0, 5.0, "suffix:m") var dress_to: float = 230.0

@export_group("Traffic and people")
## DESIGN-TBD (docs/questions/f2f.md 6): how many people, cars, buses and trucks.
## Vehicles to each of the road's two outer lanes (the cyborgs march in the middle), their speeds (m/s; the lane toward the
## camera's the first, the lane away the second), and people to each sidewalk and their walking speeds.
@export_range(0, 40) var vehicles_per_lane: int = 12
@export var vehicle_speeds: Vector2 = Vector2(10.0, 12.5)
@export_range(0, 300) var people_per_side: int = 130
@export var people_speeds: Vector2 = Vector2(1.0, 1.7)
## A low-end device gets this share of them.
@export_range(0.1, 1.0, 0.05) var low_end_share: float = 0.5
## The loop traffic and people go round (track distances): behind the camera's start to beyond the fog.
## A stretch of road both lanes keep clear where the camera looks through it (x its middle's track distance, y the time it
## is there, z its length), so no vehicle hides the window and the cyborgs as the glass bursts and the runner leaps.
@export var traffic_clear: Vector3 = Vector3(14.0, 10.3, 56.0)
@export_range(-300.0, -50.0, 5.0, "suffix:m") var loop_from: float = -110.0
@export_range(150.0, 400.0, 5.0, "suffix:m") var loop_to: float = 210.0

@export_group("The Floating Head")
## DESIGN-TBD (docs/questions/f2f.md 7, 8): where the Head hangs, how it sweeps, and its startled, angry and yelling faces.
## Its face's plane at this track distance, over the middle of the street, its belly this high.
@export_range(10.0, 120.0, 0.5, "suffix:m") var face_at: float = 40.0
@export_range(4.0, 25.0, 0.1, "suffix:m") var belly: float = 11.0
## Its searchlight's spot: its radius on the road and on a wall, how fast it whips (seconds to cross to the runner).
@export_range(0.5, 6.0, 0.1, "suffix:m") var spot_radius: float = 3.0
@export_range(0.5, 6.0, 0.1, "suffix:m") var wall_spot_radius: float = 2.2
@export_range(0.5, 6.0, 0.1, "suffix:m") var runner_spot_radius: float = 2.2
## Its face: startled (`startle_at`: the eyes wide, an "O" for a mouth), then angry (`angry_at`), then yelling (`yell_at`:
## the jaw wide open, the picture breaking up a little), and how long each change takes.
@export_range(8.0, 20.0, 0.05, "suffix:s") var startle_at: float = 13.0
@export_range(8.0, 20.0, 0.05, "suffix:s") var angry_at: float = 14.0
@export_range(8.0, 20.0, 0.05, "suffix:s") var yell_at: float = 15.0
@export_range(0.05, 1.0, 0.05, "suffix:s") var expression_seconds: float = 0.25
@export_range(0.0, 1.0, 0.05) var yell_glitch: float = 0.35
@export_range(0.0, 1.0, 0.05) var startle_jaw: float = 0.3

@export_group("The window")
## DESIGN-TBD (docs/questions/f2f.md 2): which window, and how it bursts.
## A building window on a wall (`window_side` -1 the left), at this track distance, its sill this high, this wide and
## tall. It bursts at `burst_at`; the glass flies out as `shard_count` shards.
@export_range(-1, 1, 2) var window_side: int = -1
@export_range(5.0, 40.0, 0.5, "suffix:m") var window_z: float = 14.0
@export_range(2.0, 7.0, 0.1, "suffix:m") var window_sill: float = 4.2
@export_range(1.0, 4.0, 0.1, "suffix:m") var window_width: float = 3.0
@export_range(1.0, 3.5, 0.1, "suffix:m") var window_height: float = 2.3
@export_range(9.0, 12.0, 0.05, "suffix:s") var burst_at: float = 9.9
@export_range(0, 120) var shard_count: int = 44

@export_group("The cyborgs")
## DESIGN-TBD (docs/questions/f2f.md 3, 4, 9): how many cyborgs and how they march, how the stomp reads, the feed's surge and the chase.
## Seven trudging down the street toward the camera at this pace (m/s), each a (x across, z behind the first) place, the
## first the one the runner stomps. `lead_z` is where the first is when it is stomped, `stomp_at` when.
@export_range(0.3, 3.0, 0.05, "suffix:m/s") var march_speed: float = 1.0
@export var march_places: PackedVector2Array = PackedVector2Array([Vector2(-2.4, 0.0), Vector2(-1.0, 2.5), Vector2(1.6, 4.0),
	Vector2(-3.6, 6.0), Vector2(0.2, 8.8), Vector2(2.9, 11.5), Vector2(-1.6, 13.5)])
@export_range(5.0, 40.0, 0.1, "suffix:m") var lead_z: float = 12.0
@export_range(9.0, 13.0, 0.05, "suffix:s") var stomp_at: float = 10.55
## The yell goes through the feed: every screen face flickers at `flicker_at` and has turned angry within `flicker_seconds`;
## they turn round (`turn_seconds`) and chase at `chase_speed` (m/s).
@export_range(12.0, 20.0, 0.05, "suffix:s") var flicker_at: float = 15.5
@export_range(0.1, 1.0, 0.05, "suffix:s") var flicker_seconds: float = 0.4
@export_range(0.2, 2.0, 0.05, "suffix:s") var turn_seconds: float = 0.5
@export_range(1.0, 12.0, 0.1, "suffix:m/s") var chase_speed: float = 7.0

@export_group("The runner")
## DESIGN-TBD (docs/questions/f2f.md 5): how fast they run.
## They burst out of the window, land on the first cyborg's head (the stomp), hop over the second and a later one, and run
## down the street at this speed (m/s), the way the levels run.
@export_range(5.0, 25.0, 0.5, "suffix:m/s") var run_speed: float = 8.5
@export_range(0.5, 3.0, 0.05, "suffix:m") var hop_clearance: float = 0.8
## A hop over a cyborg takes this long, and the strides between the two are this long.
@export_range(0.3, 1.2, 0.05, "suffix:s") var hop_seconds: float = 0.65
## The runner hangs on the cyborg's head this long before they bounce on (a hit-stop, as a stomp has in play).
@export_range(0.0, 0.4, 0.01, "suffix:s") var stomp_hold: float = 0.12
@export_range(0.05, 0.6, 0.05, "suffix:s") var stride_seconds: float = 0.15

@export_group("The cameras")
## DESIGN-TBD (docs/questions/f2f.md 10): the camera's places.
## One continuous move from the flyby down into the street and through the escape, until the cut to the Head (`head_at`):
## its keys' times, where the camera is, what it looks at and its lens.
@export var move_times: PackedFloat32Array = PackedFloat32Array([0.0, 2.0, 3.6, 5.0, 7.0, 9.0, 10.2, 10.7, 11.3, 12.2, 12.99])
@export var move_positions: PackedVector3Array = PackedVector3Array([Vector3(2.5, 46.0, -48.0), Vector3(-1.5, 24.0, -26.0),
	Vector3(0.8, 8.0, -8.0), Vector3(2.6, 1.8, 3.0), Vector3(1.6, 1.65, 4.2), Vector3(0.4, 1.6, 4.8),
	Vector3(0.0, 1.65, 5.4), Vector3(-0.6, 1.5, 6.4), Vector3(-0.2, 1.8, 7.0), Vector3(0.2, 2.3, 7.6),
	Vector3(0.4, 2.6, 8.2)])
@export var move_targets: PackedVector3Array = PackedVector3Array([Vector3(0.0, 0.0, 8.0), Vector3(0.5, 0.0, 13.0),
	Vector3(0.0, 3.0, 18.0), Vector3(0.0, 5.0, 24.0), Vector3(-0.8, 3.8, 21.0), Vector3(-3.6, 3.4, 16.5),
	Vector3(-3.6, 3.2, 13.5), Vector3(-2.4, 2.4, 12.5), Vector3(-0.8, 2.4, 18.0), Vector3(0.3, 2.4, 28.0),
	Vector3(0.4, 3.2, 36.0)])
@export var move_fovs: PackedFloat32Array = PackedFloat32Array([62.0, 60.0, 58.0, 55.0, 50.0, 46.0, 40.0, 36.0, 40.0, 44.0, 46.0])
## The cut to the Head's face (`head_at`), looking up at it from the street: tight on the startled face, pushing in as it
## turns angry, then pulling back and tilting down to show the jaw drop for the yell, until the cut back (`reverse_at`).
## Positions are from the Head's face (x across, y up from the road, z toward the camera along the track), by time.
@export var head_times: PackedFloat32Array = PackedFloat32Array([13.0, 14.0, 14.9, 15.44])
@export var head_positions: PackedVector3Array = PackedVector3Array([Vector3(3.0, 7.0, -13.0), Vector3(2.0, 8.0, -11.0),
	Vector3(1.6, 8.5, -10.5), Vector3(0.5, 7.0, -20.0)])
@export var head_looks: PackedVector3Array = PackedVector3Array([Vector3(0.0, 18.4, 0.0), Vector3(0.0, 18.0, 0.0),
	Vector3(0.0, 17.5, 0.0), Vector3(0.0, 14.2, 0.0)])
@export var head_fovs: PackedFloat32Array = PackedFloat32Array([34.0, 30.0, 30.0, 38.0])
@export_range(10.0, 20.0, 0.05, "suffix:s") var reverse_at: float = 15.45
## The cut back to the street (`reverse_at`) for the cyborgs' surge and turn, from low in the street.
@export var street_from: Vector3 = Vector3(0.8, 1.5, 2.5)
@export var street_to: Vector3 = Vector3(0.6, 1.8, 5.0)
@export var street_look_from: Vector3 = Vector3(0.0, 2.4, 12.0)
@export var street_look_to: Vector3 = Vector3(0.0, 2.8, 20.0)
@export_range(15.0, 80.0, 0.5, "suffix:°") var street_fov: float = 40.0
## The street camera goes on through the title card (`card_at`), drifting on behind the chase to this (an ease, no cut): low
## behind the cyborgs running for the Head, under the title card.
@export var chase_to: Vector3 = Vector3(0.6, 2.4, 13.0)
@export var chase_look_to: Vector3 = Vector3(0.0, 4.5, 40.0)
@export_range(15.0, 80.0, 0.5, "suffix:°") var chase_fov: float = 54.0
