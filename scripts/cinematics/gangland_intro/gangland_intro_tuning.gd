class_name GanglandIntroTuning
extends Resource
## Gangland intro's numbers (GanglandIntro; data/cinematics/gangland_intro_tuning.tres). The owner's beats (October 16,
## 2026): at human height behind the runner, who has come to a fork in the road; they look left, and the scene cuts to
## it: at ground level the camera tilts up to two cyborg gangsters with a large Octodog between them, looking to the
## right; it pans right to another gang (three cyborgs in Gangland's look, one in the Marketplace's and, in the middle,
## a little forward and leading them, one in the Casino's look, the same as the Marketplace's) with a hover truck
## behind them; it pans back to show both. They yell at each other; the gang on the right fires a shot that misses;
## the gang on the left gets angry; their Octodog charges and tackles the cyborgs on the right, who open fire. A cut
## back to the runner, who turns slowly to the right, their left hand up over their face, and walks off down the other
## street. 20 s is fine. The rest (timings, distances, the camera's places, the sounds) is DESIGN-TBD
## (docs/OPEN_QUESTIONS_DEFERRED.md, items 897-910).
##
## Times are seconds from the start. Points in the junction's side streets are (u, v): u metres in from the main
## street's wall face, v metres along the main street from the junction's middle (+ ahead).

@export_group("Timing")
## The owner: "it is okay if this goes 20 seconds". It ends on black: the level opens on its own view.
@export_range(10.0, 25.0, 0.1, "suffix:s") var duration: float = 21.6
@export_range(0.0, 3.0, 0.05, "suffix:s") var fade_in: float = 0.8
@export_range(0.0, 3.0, 0.05, "suffix:s") var fade_out: float = 1.3
## The zone's music comes in over this from the start, and carries on into Gangland 1.
@export_range(0.0, 8.0, 0.1, "suffix:s") var music_fade: float = 3.0
## The stretch of street (metres; the finish line the track builder draws at its end stays out of view).
@export_range(200.0, 2000.0, 10.0, "suffix:m") var stage_length: float = 400.0

@export_group("The fork")
## The junction's middle, metres along the main street. Streets go off left and right there; ahead, a building across
## the street closes it, so the road forks.
@export_range(30.0, 200.0, 1.0, "suffix:m") var junction_at: float = 61.0
## The side streets' width in lanes (the main street's lane width), and the pavement past their edge lanes.
@export_range(3, 9) var side_lanes: int = 7
@export_range(0.0, 3.0, 0.05, "suffix:m") var side_margin: float = 0.6
## How far each side street runs before a building closes it (metres).
@export_range(30.0, 200.0, 1.0, "suffix:m") var left_depth: float = 82.0
@export_range(30.0, 200.0, 1.0, "suffix:m") var right_depth: float = 70.0

@export_group("The runner")
## They walk up and stop this far before the junction's middle (v), at `stop_at`, from `walk_from` metres back.
@export_range(-10.0, 0.0, 0.1, "suffix:m") var stand_v: float = -2.6
@export_range(0.0, 8.0, 0.1, "suffix:m") var walk_from: float = 3.2
@export_range(0.3, 4.0, 0.05, "suffix:s") var stop_at: float = 1.7
## They look left (head turn and a little of the body) from `look_at` over `look_seconds`.
@export_range(0.0, 5.0, 0.05, "suffix:s") var look_at: float = 2.0
@export_range(0.2, 2.0, 0.05, "suffix:s") var look_seconds: float = 0.85
@export_range(0.0, 120.0, 1.0, "suffix:°") var look_degrees: float = 62.0
@export_range(0.0, 90.0, 1.0, "suffix:°") var look_body_degrees: float = 28.0
## The cut back to them (the fight still going on behind the corner); they turn slowly to the right (their turn rate,
## CineActor.turn_rate), their left hand coming up over their face, and walk off down the right-hand street.
@export_range(5.0, 22.0, 0.05, "suffix:s") var back_at: float = 16.5
@export_range(0.0, 3.0, 0.05, "suffix:s") var turn_after: float = 0.45
@export_range(0.5, 10.0, 0.1, "suffix:1/s") var turn_rate: float = 2.0
## Their heading as they turn into the right-hand street (degrees, - right), reached as they start walking.
@export_range(-120.0, 0.0, 1.0, "suffix:°") var turn_degrees: float = -82.0
## The hand comes up over this long from the turn's start, and stays up as they walk away.
@export_range(0.1, 2.0, 0.05, "suffix:s") var hand_seconds: float = 0.75
## They start walking this long after the turn starts, at `walk_speed`, toward a point `walk_u` into the right-hand
## street.
@export_range(0.3, 4.0, 0.05, "suffix:s") var walk_after: float = 1.25
@export_range(0.5, 3.0, 0.05, "suffix:m/s") var walk_speed: float = 1.35
@export_range(3.0, 40.0, 0.5, "suffix:m") var walk_u: float = 14.0
## The zone's title card ("ZONE 2", "GANGLAND", from the zone's data) comes up this long after they start walking away
## (the owner, October 16, 2026), for `card_seconds` in all (its own fades included), held on as the picture fades to
## black and gone before the cinematic ends.
@export_range(0.0, 3.0, 0.05, "suffix:s") var card_after: float = 0.3
@export_range(1.0, 5.0, 0.05, "suffix:s") var card_seconds: float = 2.9

@export_group("The gangs")
## The left gang (the Octodog's crew): its two cyborgs (u, v, and the degrees their bodies are turned from facing the
## other gang toward the camera), in Gangland's look (DESIGN-TBD, docs/OPEN_QUESTIONS_DEFERRED.md items 898 and 899:
## they face the other gang, "to their right" read as the camera's right; the beats don't name their look), and their
## Octodog between them, `dog_scale` times its size in play (the owner: a large one).
@export var left_cyborgs: PackedVector3Array = PackedVector3Array([Vector3(27.4, 2.2, 22.0), Vector3(28.9, -2.7, 30.0)])
@export var dog_at: Vector2 = Vector2(28.2, 0.0)
@export_range(1.0, 3.0, 0.05) var dog_scale: float = 1.75
## The right gang: the leader (the Casino's look, a little forward, in the middle) and the four behind them, each
## (u, v, and the degrees its body is turned toward the camera) with its look: "@<zone id>" wears that zone's cyborgs'
## look (its skin's), empty this zone's, anything else a look's own name (CyborgSuit).
@export var leader_at: Vector3 = Vector3(34.6, -0.3, 24.0)
@export var leader_look: StringName = &"@casino"
## The leader stands a little taller than the rest (scale). DESIGN-TBD (docs/OPEN_QUESTIONS_DEFERRED.md item 900): the
## Marketplace and the Casino share one look, so this and its place are all that set it apart.
@export_range(1.0, 1.3, 0.01) var leader_scale: float = 1.08
@export var right_cyborgs: PackedVector3Array = PackedVector3Array([Vector3(36.2, 2.5, 30.0), Vector3(36.6, 0.9, 24.0),
	Vector3(36.9, -1.6, 20.0), Vector3(36.4, -3.3, 16.0)])
@export var right_looks: Array[StringName] = [&"", &"", &"@marketplace", &""]
## The hover truck parked behind the right gang, side on across the street (its middle, u and v), facing +v or -v.
@export var truck_at: Vector2 = Vector2(41.2, -0.6)
@export var truck_faces_ahead: bool = true

@export_group("The standoff")
## The cut to the gangs; the camera's tilt up the left gang ends at `tilt_end`; the pan right to the other gang runs
## from `pan_at` over `pan_seconds`; the pan back and out to show both, from `wide_at` over `wide_seconds`.
@export_range(1.0, 8.0, 0.05, "suffix:s") var gang_at: float = 3.4
@export_range(1.0, 10.0, 0.05, "suffix:s") var tilt_end: float = 5.7
@export_range(1.0, 12.0, 0.05, "suffix:s") var pan_at: float = 6.0
@export_range(0.3, 4.0, 0.05, "suffix:s") var pan_seconds: float = 1.6
@export_range(1.0, 14.0, 0.05, "suffix:s") var wide_at: float = 8.2
@export_range(0.3, 4.0, 0.05, "suffix:s") var wide_seconds: float = 1.7
## The yelling: the left gang first, then the leader answers, then the left gang again.
@export var yells: PackedFloat32Array = PackedFloat32Array([9.9, 10.8, 11.5])
## The leader raises its arm cannon (`aim_at`), charges it (the red glow, a cyborg's warning) and fires one shot
## that misses: between a left cyborg and the Octodog, bursting on the street behind them (`miss_at`).
@export_range(1.0, 18.0, 0.05, "suffix:s") var aim_at: float = 12.0
@export_range(1.0, 18.0, 0.05, "suffix:s") var shot_at: float = 12.9
@export_range(0.05, 1.0, 0.01, "suffix:s") var shot_seconds: float = 0.18
## Where the miss lands (u, y, v): on the street just behind the left gang, past a cyborg and the Octodog.
@export var miss_at: Vector3 = Vector3(23.4, 0.03, 0.9)
## The left gang gets angry: their faces, a roar, and their Octodog rearing up (its wind-up, as in play).
@export_range(1.0, 18.0, 0.05, "suffix:s") var angry_at: float = 13.25
@export_range(1.0, 18.0, 0.05, "suffix:s") var windup_at: float = 13.55
## The Octodog's charge: it lunges at the right gang, bowls over the first cyborg in its way (`tackles`, indices into
## right_cyborgs, in order) and pounces on the next.
@export_range(1.0, 20.0, 0.05, "suffix:s") var charge_at: float = 14.3
@export_range(0.2, 2.0, 0.05, "suffix:s") var charge_seconds: float = 0.55
@export_range(0.1, 2.0, 0.05, "suffix:s") var pounce_seconds: float = 0.45
@export var tackles: PackedInt32Array = PackedInt32Array([2, 1])
## How far a tackled cyborg is thrown (metres) and how high.
@export_range(0.0, 5.0, 0.05, "suffix:m") var throw_distance: float = 2.4
@export_range(0.0, 2.0, 0.05, "suffix:m") var throw_height: float = 0.7
## The cyborgs left standing open fire (the right gang, then the left answering), this many bolts each, this far apart.
@export_range(1.0, 20.0, 0.05, "suffix:s") var fire_at: float = 15.0
@export_range(1, 8) var bolts_each: int = 4
@export_range(0.05, 1.0, 0.01, "suffix:s") var bolt_interval: float = 0.32
@export_range(0.05, 1.0, 0.01, "suffix:s") var bolt_seconds: float = 0.2

@export_group("Camera")
@export_range(10.0, 100.0, 0.5, "suffix:°") var fov: float = 58.0
@export_range(10.0, 100.0, 0.5, "suffix:°") var wide_fov: float = 60.0
## Behind the runner at human height: how far behind, how high, how far to their right.
@export_range(1.0, 8.0, 0.05, "suffix:m") var behind: float = 3.1
@export_range(0.5, 3.0, 0.05, "suffix:m") var eye_height: float = 1.62
@export_range(-2.0, 2.0, 0.05, "suffix:m") var behind_side: float = 0.45
## The tilt up the left gang: from ground level (the camera `ground_height` up) at (u, v).
@export var ground_eye: Vector2 = Vector2(31.9, 4.0)
@export_range(0.05, 1.0, 0.01, "suffix:m") var ground_height: float = 0.16
## Where the pan to the right gang looks from (u, v, height); the wide shot of both, from behind the left gang's
## shoulder (so the left gang is on the left and the right gang on the right, each at its own depth, and both fit a
## narrow screen as well as a wide one), and what it looks at.
@export var pan_eye: Vector3 = Vector3(31.6, 4.4, 0.45)
@export var wide_eye: Vector3 = Vector3(24.6, 6.4, 1.55)
@export var wide_look: Vector3 = Vector3(33.0, -0.5, 1.1)
## The charge: low beyond the right gang's flank, looking back at the Octodog coming (u, v, height).
@export var charge_eye: Vector3 = Vector3(38.2, 7.5, 1.0)
@export_range(0.0, 15.0, 0.05, "suffix:s") var charge_cut: float = 14.05
## Back with the runner: where the camera stands, to their left and a little ahead (offsets from where they stand: x
## right, height, z ahead): they face it at the cut, looking toward the fight, then turn their back on it, the hand
## they raise on its side, and walk away from it down the right-hand street.
@export var back_eye: Vector3 = Vector3(-2.7, 1.6, 1.3)
