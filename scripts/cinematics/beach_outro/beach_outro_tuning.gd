class_name BeachOutroTuning
extends Resource
## The Beach's outro's numbers (BeachOutro; the owner's beats, October 15, 2026):
## data/cinematics/beach_outro_tuning.tres. Times are seconds from its start; places are in track space (CineStage:
## x metres right of the start lane's centre, y up, z along the track), most of them from the tiki bar's counter.
## DESIGN-TBD (docs/questions/f2e.md): the staging these fill in.

@export_group("Length")
@export_range(20.0, 60.0, 0.1, "suffix:s") var duration: float = 39.6
@export_range(0.0, 2.0, 0.05, "suffix:s") var fade_in: float = 0.8
## The fight's music fades out over this long as it opens: the fight is over.
@export_range(0.0, 6.0, 0.1, "suffix:s") var music_fade: float = 3.0
@export_range(150.0, 1000.0, 10.0, "suffix:m") var stage_length: float = 420.0
## How far along the stretch the bar stands (the ships' shot looks back up the street, which must be built back
## there: BeachOutro.LOOK_BACK).
@export_range(150.0, 300.0, 1.0, "suffix:m") var bar_at: float = 200.0

@export_group("Mecha Guppy swims away")
## Its leap out of the sea, heading away out to sea: from the sea's surface out past the left shore, its arc this
## high, this long, then its dive back in; then it swims on away under the surface, only its back and dorsal fin
## showing, until it sinks out of sight.
@export_range(0.0, 3.0, 0.05, "suffix:s") var breach_at: float = 0.5
@export_range(1.0, 5.0, 0.05, "suffix:s") var breach_seconds: float = 2.8
@export_range(5.0, 40.0, 0.5, "suffix:m") var breach_height: float = 16.0
## Where it bursts out, from the bar along the track (z) and past the left wall line (x, metres out).
@export_range(30.0, 160.0, 1.0, "suffix:m") var breach_out: float = 58.0
@export_range(-80.0, 80.0, 1.0, "suffix:m") var breach_along: float = -30.0
## Its leap and swim head this way (metres a second, out to sea and along the track).
@export var swim_velocity: Vector2 = Vector2(-16.0, 9.0)
## How long its back and fin show after the dive, and how far under the surface it swims.
@export_range(0.0, 6.0, 0.05, "suffix:s") var fin_seconds: float = 2.6
@export_range(1.0, 10.0, 0.1, "suffix:m") var fin_depth: float = 5.6
## Its size (MechaGuppySharkModel's metres times this; the fight's is 1.5).
@export_range(0.5, 2.0, 0.05) var shark_scale: float = 1.1
## The plumes where it breaks the sea (height, width; metres).
@export var burst_plume: Vector2 = Vector2(14.0, 11.0)
@export var dive_plume: Vector2 = Vector2(18.0, 13.0)

@export_group("The runner")
## Watching the sea from near the bar (from the counter's front: x across, z along), the screech at their feet; they
## turn to the bar and walk over, along the edge of the promenade, at a walk.
@export var watch_from: Vector3 = Vector3(1.7, 0.0, -6.0)
@export_range(1.0, 20.0, 0.05, "suffix:s") var walk_at: float = 7.3
@export_range(0.5, 3.0, 0.05, "suffix:m/s") var walk_speed: float = 1.45
@export_range(0.5, 20.0, 0.1, "suffix:1/s") var turn_rate: float = 3.0
## Where they stand at the counter, out from its front.
@export_range(0.15, 1.0, 0.01, "suffix:m") var counter_gap: float = 0.3
## Holding up two fingers for two drinks: the hand up, held, down.
@export_range(10.0, 30.0, 0.05, "suffix:s") var fingers_at: float = 19.5
@export_range(0.5, 3.0, 0.05, "suffix:s") var fingers_seconds: float = 1.6
## They run for it: from the bar down the street to the pool (their pace is what reaches its edge at jump_at).
@export_range(20.0, 40.0, 0.05, "suffix:s") var run_at: float = 33.9

@export_group("The screech")
## Its size (the Gangland outro's passenger's is 0.55), and the look it has kept since Gangland.
@export_range(0.3, 1.0, 0.01) var screech_size: float = 0.55
@export var screech_look: StringName = &"scavenger"
## Its hop up onto the counter: when, how long, how high over the counter's top.
@export_range(10.0, 25.0, 0.05, "suffix:s") var hop_at: float = 13.7
@export_range(0.2, 1.5, 0.05, "suffix:s") var hop_seconds: float = 0.55
@export_range(0.1, 1.5, 0.05, "suffix:m") var hop_height: float = 0.45
## Where it sits on the counter, along it from the runner (to their left as they face the bar).
@export_range(-1.5, 1.5, 0.05, "suffix:m") var perch_along: float = -0.62

@export_group("The bar")
## The tiki bar kiosk (BeachDoodads' large doodad) built at this size and scaled down to the characters (the runner
## is about 1.3 m tall): its depth across the track, height and length along it.
@export var kiosk_size: Vector3 = Vector3(3.6, 4.4, 6.4)
@export_range(0.4, 1.2, 0.01) var kiosk_scale: float = 0.7
## Its back this far in from the left wall line.
@export_range(0.0, 2.0, 0.05, "suffix:m") var kiosk_inset: float = 0.25
## The bartender (the volleyball match's opponent, VolleyballRivalSuit): his height, where he stands behind the
## counter (from the counter's front: x back from it, z along it).
@export_range(1.0, 2.0, 0.01, "suffix:m") var bartender_height: float = 1.4
@export var bartender_at: Vector3 = Vector3(-0.95, 0.0, 0.35)
## He turns round to the menu on the wall and points to it, turns back and asks; nods; turns his back to make the drinks (shaking them); then he's
## set them on the counter (the cut away and back) and ducks when the bombs fall.
@export_range(10.0, 30.0, 0.05, "suffix:s") var gesture_at: float = 16.0
@export_range(0.5, 3.0, 0.05, "suffix:s") var gesture_seconds: float = 1.9
@export_range(10.0, 30.0, 0.05, "suffix:s") var ask_at: float = 18.0
@export_range(10.0, 30.0, 0.05, "suffix:s") var nod_at: float = 21.5
@export_range(10.0, 30.0, 0.05, "suffix:s") var turn_back_at: float = 21.9
@export_range(10.0, 30.0, 0.05, "suffix:s") var shake_at: float = 22.6
@export_range(25.0, 40.0, 0.05, "suffix:s") var duck_at: float = 32.0

@export_group("The cuts")
## The bar's shots: walking up to it, the bartender's view, the bartender, the two of them, his back.
@export_range(5.0, 20.0, 0.05, "suffix:s") var up_close_at: float = 10.9
@export_range(5.0, 25.0, 0.05, "suffix:s") var bartender_view_at: float = 13.1
@export_range(5.0, 25.0, 0.05, "suffix:s") var bartender_shot_at: float = 15.6
@export_range(5.0, 30.0, 0.05, "suffix:s") var order_shot_at: float = 19.0
@export_range(5.0, 30.0, 0.05, "suffix:s") var back_shot_at: float = 21.4
## The Golden Palace: the Golden Convergence's face in its dark room of screens, its hand rising to point; then its
## ships, flying.
@export_range(15.0, 35.0, 0.05, "suffix:s") var palace_at: float = 24.2
@export_range(15.0, 40.0, 0.05, "suffix:s") var point_at: float = 26.3
@export_range(0.5, 3.0, 0.05, "suffix:s") var point_seconds: float = 1.3
@export_range(15.0, 40.0, 0.05, "suffix:s") var ships_at: float = 28.4
## Back at the beach: the bombs; looking up at the ships; the run; the pool.
@export_range(20.0, 40.0, 0.05, "suffix:s") var raid_at: float = 31.2
@export_range(20.0, 40.0, 0.05, "suffix:s") var look_up_at: float = 32.3
@export_range(20.0, 40.0, 0.05, "suffix:s") var sky_shot_at: float = 32.8
@export_range(20.0, 45.0, 0.05, "suffix:s") var run_shot_at: float = 33.9
@export_range(20.0, 45.0, 0.05, "suffix:s") var pool_shot_at: float = 36.6

@export_group("The Golden Palace")
## How dark its room is (ZoneSkin.scenery_light: the gold in the screens' light), its size round the Golden
## Convergence, and the screens: how many rows round it, each how many, their size (metres; the suit is about 23 m
## from its waist to its crown at scale 1, built here at suit_scale).
@export_range(0.05, 1.0, 0.01) var palace_light: float = 0.25
@export_range(0.1, 1.0, 0.01) var suit_scale: float = 0.3
@export var room_size: Vector3 = Vector3(26.0, 16.0, 24.0)
@export_range(1, 5) var screen_rows: int = 3
@export_range(2, 16) var screens_per_row: int = 9
@export var screen_size: Vector2 = Vector2(2.6, 1.6)
## Its cape's cloud, gathered in a little (1: the fight's whole cloud), so the screens show round it.
@export_range(0.0, 1.0, 0.01) var cape_unfurl: float = 0.7

@export_group("The ships")
## The Golden Convergence's refill ships (GoldenConvergenceShipModel), in a V: how many, how high they fly over
## the beach, how fast along the track, their spacing; they pass over the bar at this time.
@export_range(1, 5) var ships: int = 3
@export_range(15.0, 80.0, 1.0, "suffix:m") var ship_height: float = 44.0
@export_range(5.0, 60.0, 1.0, "suffix:m/s") var ship_speed: float = 24.0
@export var ship_spacing: Vector2 = Vector2(26.0, 22.0)
@export_range(20.0, 45.0, 0.05, "suffix:s") var over_bar_at: float = 33.2
## The bombs (one of the racks' missiles each): when each lands and where (x across the track, z from the bar),
## and its fireball's radius; each falls for bomb_fall seconds before it lands, whistling.
## The first three land out on the beach beyond the bar, then one to each side of the runner in turn as they run
## (+x first: the screen's left as the camera looks back at them), one ahead by the pool, and the last on it.
@export var bombs: PackedVector4Array = PackedVector4Array([
	Vector4(31.9, -22.0, 16.0, 5.0), Vector4(32.6, -28.0, 4.0, 4.5), Vector4(33.5, -16.0, 24.0, 4.5),
	Vector4(34.7, 6.5, 3.5, 3.0), Vector4(35.5, -6.5, 9.0, 3.0), Vector4(36.3, 5.5, 15.5, 3.0),
	Vector4(37.2, -5.5, 33.0, 3.4), Vector4(38.05, 0.8, 32.5, 4.2)])
@export_range(0.3, 2.0, 0.05, "suffix:s") var bomb_fall: float = 1.0

@export_group("The pool")
## The pool the runner jumps into: a gap in the start lane (the Beach's gaps are pools of water), from the bar
## along the track; the jump: its takeoff short of the pool, its height, and how far down they sink.
@export_range(10.0, 60.0, 0.5, "suffix:m") var pool_from: float = 28.0
@export_range(3.0, 12.0, 0.5, "suffix:m") var pool_length: float = 6.0
@export_range(20.0, 45.0, 0.05, "suffix:s") var jump_at: float = 37.7
@export_range(0.2, 2.0, 0.05, "suffix:m") var jump_height: float = 0.9
## The fire fills the picture (a fade to its colour) as the runner goes in, then black.
@export_range(20.0, 45.0, 0.05, "suffix:s") var fire_at: float = 38.3
@export_range(0.05, 1.0, 0.05, "suffix:s") var fire_seconds: float = 0.3
@export var fire_color: Color = Color(1.0, 0.45, 0.08)
@export_range(0.1, 2.0, 0.05, "suffix:s") var black_seconds: float = 0.7
