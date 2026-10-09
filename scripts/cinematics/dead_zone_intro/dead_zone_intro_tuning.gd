class_name DeadZoneIntroTuning
extends Resource
## The Dead Zone intro's numbers (DeadZoneIntro; data/cinematics/dead_zone_intro_tuning.tres). The beats are the
## owner's (October 9, 2026): a smoking crater in the street that looks like a gap, the runner lying in it; after a
## moment they shake themselves and start to pull themselves out; a cut to ground level, where at first only their
## hands are seen grabbing the edge, then they pull themselves up; throughout, cyborgs in the distance, two lying
## still and a third crouched over them, doing who knows what; as the runner pulls themselves up, the crouched one
## looks over, a host; a cut to an extreme close-up of its glitching face looking menacingly at the camera; then
## black. The rest (timings, distances, the camera's exact places, the sounds) is DESIGN-TBD (docs/questions/f2c.md).
## Times are seconds from the start; points are track space (CineStage: x metres right of the runner's lane, y up,
## z ahead), most of them from the crater's far edge, the one the runner climbs out over.

@export_group("Timing")
## GDD §1: 5-15 s. It ends on black: the level opens on its own view.
@export_range(5.0, 15.0, 0.1, "suffix:s") var duration: float = 12.6
@export_range(0.0, 3.0, 0.05, "suffix:s") var fade_in: float = 1.4
@export_range(0.0, 2.0, 0.05, "suffix:s") var fade_out: float = 1.1
## The zone's music comes in over this, quietly, from the start.
@export_range(0.0, 8.0, 0.1, "suffix:s") var music_fade: float = 5.0
## The stretch of street (metres; the finish line the track builder draws at its end stays out of view).
@export_range(300.0, 2000.0, 10.0, "suffix:m") var stage_length: float = 400.0

@export_group("The crater")
## Its far edge, metres along the track (far enough along that the street behind it, which the camera looks back
## down, reaches into the haze), how long it is (a hole in the runner's lane, as a gap looks) and how deep its
## floor lies (the runner hanging from the edge by their hands just touches it).
@export_range(150.0, 400.0, 1.0, "suffix:m") var crater_end: float = 200.0
@export_range(3.0, 8.0, 0.1, "suffix:m") var crater_length: float = 5.4
@export_range(1.0, 2.5, 0.01, "suffix:m") var crater_depth: float = 1.42
## The rubble on its floor: chunks of the street that came down with it, and its shades.
@export_range(0, 30) var rubble_count: int = 14
@export var rubble_colors: PackedColorArray = PackedColorArray([Color(0.16, 0.158, 0.155), Color(0.22, 0.217, 0.212),
	Color(0.11, 0.11, 0.11)])
## Smoke rising out of it: each column's base (x across, z back from the far edge), width at its base and height
## (metres), its colour (a = its opacity at the core) and how fast its billows rise.
@export var smoke_columns: PackedVector4Array = PackedVector4Array([Vector4(0.75, 4.3, 1.1, 3.6),
	Vector4(0.8, 1.2, 0.9, 2.8), Vector4(0.6, 2.7, 0.8, 2.4)])
@export var smoke_color: Color = Color(0.4, 0.394, 0.388, 0.48)
@export_range(0.0, 5.0, 0.1, "suffix:m/s") var smoke_rise: float = 0.9
## A faint, cold light down in the crater, so the runner reads in the dark: where (from the far edge), its
## colour, energy and reach. Not a hazard's colour, and it never flickers.
@export var crater_light_at: Vector3 = Vector3(0.6, 0.7, -2.2)
@export var crater_light_color: Color = Color(0.7, 0.74, 0.82)
@export_range(0.0, 4.0, 0.05) var crater_light_energy: float = 0.9
@export_range(0.5, 10.0, 0.1, "suffix:m") var crater_light_range: float = 4.0

@export_group("The runner")
## Lying on their back on the crater's floor, their hips this far back from the far edge, turned this much
## (degrees, + left).
@export_range(0.3, 5.0, 0.01, "suffix:m") var lie_back: float = 2.5
@export_range(-30.0, 30.0, 1.0, "suffix:°") var lie_yaw: float = 6.0
## After a moment they stir, the head coming up, then shake themselves (the head shaking, its turns this wide and
## this many a second) as they sit up and get to their feet, coming forward this far as they rise.
@export_range(0.5, 4.0, 0.05, "suffix:s") var stir_at: float = 1.9
@export_range(0.5, 5.0, 0.05, "suffix:s") var shake_from: float = 2.35
@export_range(0.5, 5.0, 0.05, "suffix:s") var shake_to: float = 3.0
@export_range(0.0, 60.0, 1.0, "suffix:°") var shake_turn: float = 30.0
@export_range(1.0, 10.0, 0.1, "suffix:Hz") var shake_rate: float = 4.5
@export_range(1.0, 6.0, 0.05, "suffix:s") var sit_at: float = 3.0
@export_range(1.0, 6.0, 0.05, "suffix:s") var kneel_at: float = 3.45
@export_range(1.0, 6.0, 0.05, "suffix:s") var stand_at: float = 3.9
@export_range(0.0, 1.0, 0.01, "suffix:m") var rise_ahead: float = 0.3
## Then they stagger to the far wall (`walk_to`, swaying this far from side to side) looking up at its edge, and
## reach up for it (`reach_at`), their hips this far back from the far edge.
@export_range(1.0, 8.0, 0.05, "suffix:s") var walk_to: float = 5.3
@export_range(0.0, 0.4, 0.01, "suffix:m") var walk_sway: float = 0.08
@export_range(1.0, 8.0, 0.05, "suffix:s") var reach_at: float = 5.65
@export_range(0.1, 1.5, 0.01, "suffix:m") var reach_back: float = 0.32

@export_group("The climb")
## At ground level: their hands come up over the edge and grab it (`grab_at`), hold a moment, then they pull
## themselves up (`climb_from`), a knee on the edge (`knee_at`), and are up on their feet (`up_at`), this far
## from the edge. The hands grip this far over the edge.
@export_range(3.0, 8.0, 0.05, "suffix:s") var grab_at: float = 6.0
@export_range(3.0, 8.0, 0.05, "suffix:s") var climb_from: float = 6.35
@export_range(3.0, 10.0, 0.05, "suffix:s") var knee_at: float = 7.9
@export_range(3.0, 10.0, 0.05, "suffix:s") var up_at: float = 8.55
@export_range(0.0, 0.3, 0.01, "suffix:m") var grip_over: float = 0.07
@export_range(0.1, 1.5, 0.01, "suffix:m") var up_ahead: float = 0.45

@export_group("The cyborgs")
## Down the street behind the crater (lanes from the runner's, metres back from the far edge): the host crouched
## low over the two lying still beside it, facing them (`host_yaw`, degrees, + left of facing down the track).
@export_range(-2, 2) var host_lane: int = -1
@export_range(10.0, 60.0, 0.5, "suffix:m") var host_back: float = 16.0
@export_range(-180.0, 180.0, 1.0, "suffix:°") var host_yaw: float = -90.0
## The two lying still: each one's place from the host (x across, z along) and heading (degrees).
@export var body_a: Vector3 = Vector3(0.85, 0.0, 0.35)
@export_range(-180.0, 180.0, 1.0, "suffix:°") var body_a_yaw: float = 20.0
@export var body_b: Vector3 = Vector3(1.1, 0.0, -0.75)
@export_range(-180.0, 180.0, 1.0, "suffix:°") var body_b_yaw: float = -140.0
## As the runner pulls themselves up, it looks over: its head turns (and comes up) this far over this long.
@export_range(3.0, 10.0, 0.05, "suffix:s") var look_at: float = 8.15
@export_range(0.1, 1.5, 0.05, "suffix:s") var look_seconds: float = 0.45
@export_range(-150.0, 150.0, 1.0, "suffix:°") var look_turn: float = 92.0
@export_range(-90.0, 90.0, 1.0, "suffix:°") var look_up: float = 78.0

@export_group("The cameras")
## High over the crater's far end, looking down into it and down the street beyond, easing in a little.
@export var high_from: Vector3 = Vector3(1.2, 4.8, 3.2)
@export var high_to: Vector3 = Vector3(0.9, 4.0, 2.5)
@export var high_look_from: Vector3 = Vector3(-0.6, -0.6, -6.0)
@export var high_look_to: Vector3 = Vector3(-0.5, -0.7, -5.0)
@export_range(30.0, 90.0, 1.0, "suffix:°") var high_fov: float = 58.0
## The cut to ground level (`cut_at`): low on the street beyond the far edge, looking back over it and down the
## street, then (from `rise_from`) rising a little as the runner gets up, and (from `push_from`) closing in on the
## host down the street as it looks over.
@export_range(3.0, 8.0, 0.05, "suffix:s") var cut_at: float = 5.75
@export var ground_at: Vector3 = Vector3(-0.5, 0.16, 1.3)
@export var ground_look: Vector3 = Vector3(-0.15, 0.16, -10.0)
@export_range(30.0, 90.0, 1.0, "suffix:°") var ground_fov: float = 50.0
@export_range(3.0, 10.0, 0.05, "suffix:s") var rise_from: float = 6.9
@export var risen_at: Vector3 = Vector3(-0.85, 0.42, 2.7)
@export var risen_look: Vector3 = Vector3(-0.7, 0.6, -10.0)
@export_range(3.0, 10.0, 0.05, "suffix:s") var push_from: float = 8.6
@export_range(10.0, 60.0, 1.0, "suffix:°") var push_fov: float = 16.0
## The cut to the host's face (`close_up_at`): from in front of its screen, a little below it, pushing in.
## Offsets from the host (x across, y up, z along the track, the way its face turns to look).
@export_range(5.0, 14.0, 0.05, "suffix:s") var close_up_at: float = 9.65
@export var face_at: Vector3 = Vector3(0.26, 0.99, 0.28)
@export var close_from: Vector3 = Vector3(0.02, -0.1, 0.75)
@export var close_to: Vector3 = Vector3(0.0, -0.06, 0.42)
@export_range(10.0, 70.0, 1.0, "suffix:°") var close_fov: float = 36.0
## Its screen glitches harder close up (its shader's glitch: 1 for every host).
@export_range(1.0, 3.0, 0.05) var close_glitch: float = 1.8
