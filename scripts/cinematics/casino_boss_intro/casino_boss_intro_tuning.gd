class_name CasinoBossIntroTuning
extends Resource
## The Casino boss intro's numbers (CasinoBossIntro; data/cinematics/casino_boss_intro_tuning.tres). The beats are the
## owner's (October 17, 2026; GDD §10, The House, "Intro cinematic"): inside the bustling casino, close to a table,
## panning right to a roulette wheel spinning and people cheering as it lands; tilting up to its players (the wealthy
## woman in red, the "Lady Luck" gambler, the grimy player and the well-to-do businessman); cut to the runner leaning
## on the bar, the screech beside them, looking over the casino; they see the Chairman, a beautiful woman either side
## of him (one in black with black hair, one in red with blonde hair); the runner moves through the crowd toward him;
## he notices and two of his cyborg guards try to block the runner, who dives left and right past them; cut to the
## wall, where the Chairman goes through an elegant golden door that closes behind him; the wall to its left trembles,
## the camera pulls back to show it whole, it collapses into rubble and The House stands in the hole.
## The rest (timings, places, the camera, the hall, the people's looks, the sounds) is DESIGN-TBD
## (docs/questions/casino_boss_intro.md). Times are seconds from the start; points are track space (CineStage: x metres
## right, y up, z along), the hall's (CasinoHall: the near wall at z = 0, the back wall at z = 40).

@export_group("Timing")
## The beats take longer than GDD §1's 5-15 s, as the other intros do. It ends on black: the fight opens on its own view.
@export_range(10.0, 60.0, 0.1, "suffix:s") var duration: float = 34.8
@export_range(0.0, 3.0, 0.05, "suffix:s") var fade_in: float = 1.0
@export_range(0.0, 8.0, 0.1, "suffix:s") var music_fade: float = 3.0
@export_range(10.0, 60.0, 0.05, "suffix:s") var fade_at: float = 33.6
@export_range(0.0, 3.0, 0.05, "suffix:s") var fade_out: float = 1.1
## The shots' cuts: the roulette players (the tilt up), the runner at the bar, the Chairman seen across the hall, the
## runner pushing off the bar, through the crowd, the Chairman noticing, the guards, the door, the wall.
@export_range(0.0, 60.0, 0.05, "suffix:s") var tilt_at: float = 4.5
@export_range(0.0, 60.0, 0.05, "suffix:s") var bar_shot_at: float = 8.2
@export_range(0.0, 60.0, 0.05, "suffix:s") var chairman_shot_at: float = 11.0
@export_range(0.0, 60.0, 0.05, "suffix:s") var resolve_shot_at: float = 14.0
@export_range(0.0, 60.0, 0.05, "suffix:s") var crowd_shot_at: float = 15.4
@export_range(0.0, 60.0, 0.05, "suffix:s") var notice_shot_at: float = 18.0
@export_range(0.0, 60.0, 0.05, "suffix:s") var guards_shot_at: float = 19.5
@export_range(0.0, 60.0, 0.05, "suffix:s") var door_shot_at: float = 22.9
@export_range(0.0, 60.0, 0.05, "suffix:s") var pull_back_at: float = 25.9
@export_range(0.0, 60.0, 0.05, "suffix:s") var pull_back_seconds: float = 2.3
## How long the stage's street is (hidden: the cinematic plays in the hall).
@export_range(100.0, 2000.0, 10.0, "suffix:m") var stage_length: float = 200.0

@export_group("The roulette")
## The wheel's spin (rad/s) and the ball's (rad/s, the other way, slowing to its drop); when the ball drops off the
## track and when it comes to rest in a pocket; the players cheer.
@export_range(0.0, 10.0, 0.05, "suffix:rad/s") var wheel_spin: float = 1.6
@export_range(0.0, 30.0, 0.1, "suffix:rad/s") var ball_spin: float = 9.0
@export_range(0.0, 60.0, 0.05, "suffix:s") var ball_drop_at: float = 3.0
@export_range(0.0, 60.0, 0.05, "suffix:s") var ball_settle_at: float = 3.8
@export_range(0.0, 60.0, 0.05, "suffix:s") var cheer_at: float = 3.9
@export_range(0.5, 6.0, 0.05, "suffix:s") var cheer_seconds: float = 3.2

@export_group("The people")
## Heights (feet to the top of the head): the runner is 1.28 m (PlayerAvatar); the women, the men, the Chairman.
@export_range(1.0, 1.7, 0.01, "suffix:m") var woman_height: float = 1.26
@export_range(1.0, 1.7, 0.01, "suffix:m") var man_height: float = 1.34
@export_range(1.0, 1.7, 0.01, "suffix:m") var chairman_height: float = 1.42
## The roulette players along the table's far side (x along it, from the table's middle) and the croupier at the wheel's
## end: [woman in red, Lady Luck, grimy, high-roller].
@export var players_x: PackedFloat32Array = PackedFloat32Array([0.95, 0.15, -0.65, -1.35])
@export_range(0.6, 1.6, 0.01, "suffix:m") var players_back: float = 1.12

@export_group("The runner")
## Where along the bar the runner leans (z), when they look out over the hall and when they push off the bar.
@export_range(7.0, 21.0, 0.05, "suffix:m") var lean_z: float = 15.0
@export_range(0.0, 60.0, 0.05, "suffix:s") var look_out_at: float = 9.4
@export_range(0.0, 60.0, 0.05, "suffix:s") var push_off_at: float = 14.7
## The runner's way through the crowd: points (x, z) and when they reach each (x, y = z, z = time).
@export var runner_path: PackedVector3Array = PackedVector3Array([
	Vector3(12.28, 15.0, 14.9), Vector3(10.6, 16.9, 15.95), Vector3(8.5, 19.6, 17.1), Vector3(6.8, 22.5, 18.3),
	Vector3(5.9, 24.6, 19.25), Vector3(5.6, 25.9, 19.95)])
## The dives: when each starts, how long it's in the air, how far sideways (+ right, - left; metres) and how far on.
@export_range(0.0, 60.0, 0.05, "suffix:s") var dive_right_at: float = 20.05
@export_range(0.0, 60.0, 0.05, "suffix:s") var dive_left_at: float = 20.95
@export_range(0.2, 1.5, 0.05, "suffix:s") var dive_seconds: float = 0.55
@export_range(0.5, 3.0, 0.05, "suffix:m") var dive_side: float = 1.4
@export_range(0.0, 3.0, 0.05, "suffix:m") var dive_on: float = 0.9
@export_range(0.1, 1.5, 0.05, "suffix:m") var dive_height: float = 0.55
## After the dives: on toward the door, coming to a stop here (x, z) by this time.
@export var runner_stop: Vector2 = Vector2(6.3, 33.0)
@export_range(0.0, 60.0, 0.05, "suffix:s") var runner_stop_at: float = 24.2
@export_range(0.0, 20.0, 0.1, "suffix:m/s") var run_speed: float = 3.6

@export_group("The Chairman")
## His walk across the hall to the golden door and through it: points (x, z) and when he reaches each.
@export var chairman_path: PackedVector3Array = PackedVector3Array([
	Vector3(-4.6, 24.6, 9.0), Vector3(0.0, 29.5, 14.0), Vector3(4.5, 34.0, 18.9), Vector3(7.4, 37.4, 22.3),
	Vector3(7.5, 39.4, 23.3), Vector3(7.5, 42.4, 24.7)])
## The women beside him (across, behind; metres, his frame), closing in as they pass through the door.
@export var escort_offset: Vector2 = Vector2(0.72, -0.2)
@export var escort_door_offset: Vector2 = Vector2(0.42, -0.35)
## He notices the runner: a look back over his shoulder from `notice_at`, the flick of his hand to his guards at
## `order_at`.
@export_range(0.0, 60.0, 0.05, "suffix:s") var notice_at: float = 18.25
@export_range(0.0, 60.0, 0.05, "suffix:s") var order_at: float = 18.85
## His guards walking behind him (across, behind; his frame).
@export var guard_offset: Vector2 = Vector2(0.95, -1.7)

@export_group("The guards")
## Each guard's rush: when it sets off, the point it lunges from (x, z), when it lunges and where its lunge carries it.
@export_range(0.0, 60.0, 0.05, "suffix:s") var guards_go_at: float = 19.0
@export var guard_left_from: Vector2 = Vector2(4.3, 27.1)
@export var guard_left_to: Vector2 = Vector2(6.3, 25.9)
@export var guard_right_from: Vector2 = Vector2(8.2, 28.0)
@export var guard_right_to: Vector2 = Vector2(6.0, 27.0)
@export_range(0.0, 60.0, 0.05, "suffix:s") var lunge_left_at: float = 19.95
@export_range(0.0, 60.0, 0.05, "suffix:s") var lunge_right_at: float = 20.85
@export_range(0.2, 1.5, 0.05, "suffix:s") var lunge_seconds: float = 0.6

@export_group("The door and the wall")
## The golden door opens as he comes up to it and bangs shut behind him.
@export_range(0.0, 60.0, 0.05, "suffix:s") var door_open_at: float = 21.6
@export_range(0.1, 3.0, 0.05, "suffix:s") var door_open_seconds: float = 0.9
@export_range(0.0, 60.0, 0.05, "suffix:s") var door_close_at: float = 24.6
@export_range(0.1, 3.0, 0.05, "suffix:s") var door_close_seconds: float = 0.6
## The hole The House bursts through: its middle along the back wall (x) and the margin round the machine.
@export_range(-12.0, 4.0, 0.1, "suffix:m") var hole_x: float = -4.5
@export var hole_margin: Vector2 = Vector2(1.0, 1.0)
## The wall trembles from `tremble_at` and bursts at `burst_at`; The House's lights come on.
@export_range(0.0, 60.0, 0.05, "suffix:s") var tremble_at: float = 25.5
@export_range(0.0, 60.0, 0.05, "suffix:s") var burst_at: float = 28.3
@export_range(0.0, 60.0, 0.05, "suffix:s") var house_lights_at: float = 29.3
@export_range(0.1, 3.0, 0.05, "suffix:s") var house_lights_seconds: float = 0.9
## The shakes: the tremble's (growing), the burst's.
@export_range(0.0, 2.0, 0.05) var tremble_shake: float = 0.25
@export_range(0.0, 3.0, 0.05) var burst_shake: float = 1.0
