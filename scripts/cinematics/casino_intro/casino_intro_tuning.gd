class_name CasinoIntroTuning
extends Resource
## The Casino intro's numbers (CasinoIntro; data/cinematics/casino_intro_tuning.tres). The beats are the owner's (October
## 18, 2026; GDD §6 Cinematics, "Casino intro"), with a reference image of the casino's front
## (docs/art/reference/casino_brass_lotus.webp): the runner pulls up to a casino in the violet car (Gangland's outro's,
## SportsCarModel); they get out and look up the grand staircase, and at its top they see the Chairman shaking hands with
## people and walking into the casino with two beautiful women, one either side of him; back to the runner, and the
## Casino's title card. The rest (timings, places, the camera, the casino's front, who greets him) is DESIGN-TBD
## (docs/questions/f2j.md). Times are seconds from the start; points are track space (CineStage: x metres right of the
## start lane, y up, z along), the casino's (CasinoIntroLotus) measured from the left wall's line (x back into the building
## is negative) and from the middle of its front (z).

@export_group("Timing")
## Longer than GDD §1's 5-15 s, as the other intros are. It ends on black: Casino 1 opens on its own view.
@export_range(10.0, 60.0, 0.1, "suffix:s") var duration: float = 25.8
@export_range(0.0, 3.0, 0.05, "suffix:s") var fade_in: float = 1.0
@export_range(0.0, 8.0, 0.1, "suffix:s") var music_fade: float = 3.0
@export_range(10.0, 60.0, 0.05, "suffix:s") var fade_at: float = 24.6
@export_range(0.0, 3.0, 0.05, "suffix:s") var fade_out: float = 1.2
## The zone's title card over the last shot of the runner, and how long it shows.
@export_range(0.0, 60.0, 0.05, "suffix:s") var card_at: float = 21.6
@export_range(0.5, 6.0, 0.05, "suffix:s") var card_seconds: float = 3.2
## The shots' cuts: the car pulling up (the casino's front), beside the car as the runner gets out, behind the runner
## looking up the staircase, up the stairs at the Chairman greeting people, as he goes in, back to the runner.
@export_range(0.0, 60.0, 0.05, "suffix:s") var front_shot_at: float = 3.0
@export_range(0.0, 60.0, 0.05, "suffix:s") var door_shot_at: float = 7.3
@export_range(0.0, 60.0, 0.05, "suffix:s") var stairs_shot_at: float = 11.4
@export_range(0.0, 60.0, 0.05, "suffix:s") var greet_shot_at: float = 13.8
@export_range(0.0, 60.0, 0.05, "suffix:s") var enter_shot_at: float = 17.4
@export_range(0.0, 60.0, 0.05, "suffix:s") var runner_shot_at: float = 21.0
## How long the stage's street is: past anything the camera sees down it.
@export_range(100.0, 2000.0, 10.0, "suffix:m") var stage_length: float = 400.0

@export_group("The casino")
## The middle of the casino's front along the street (z), and its frontage (the opening in the left wall).
@export_range(40.0, 300.0, 0.5, "suffix:m") var lotus_at: float = 110.0
@export_range(16.0, 40.0, 0.5, "suffix:m") var frontage: float = 26.0
## The pavement in front of the steps (back from the wall's line), the staircase (its depth back, its width across
## and its rise; the steps are rise / step_count high), the terrace at its top, back to the casino's face.
@export_range(0.5, 4.0, 0.05, "suffix:m") var forecourt: float = 1.4
@export_range(2.0, 10.0, 0.05, "suffix:m") var stairs_depth: float = 4.8
@export_range(4.0, 20.0, 0.05, "suffix:m") var stairs_width: float = 10.4
@export_range(1.0, 5.0, 0.05, "suffix:m") var stairs_rise: float = 2.6
@export_range(6, 40) var step_count: int = 20
@export_range(1.5, 8.0, 0.05, "suffix:m") var terrace_depth: float = 3.0
## Its doors (their width and height) and the hall behind them, lit warm (how deep the vestibule is before the light).
@export_range(1.5, 5.0, 0.05, "suffix:m") var door_width: float = 2.8
@export_range(2.5, 6.0, 0.05, "suffix:m") var door_height: float = 3.8
@export_range(1.0, 8.0, 0.1, "suffix:m") var vestibule: float = 3.4
## Its height (the street's eaves: the vault springs from them).
@export_range(12.0, 30.0, 0.5, "suffix:m") var height: float = 22.0
## The marquee over the doors: how far it stands out over the terrace, its width, its underside (over the terrace).
@export_range(0.5, 4.0, 0.05, "suffix:m") var marquee_reach: float = 2.4
@export_range(4.0, 20.0, 0.1, "suffix:m") var marquee_width: float = 10.0
@export_range(2.5, 8.0, 0.05, "suffix:m") var marquee_y: float = 4.6

@export_group("The car")
## It cruises down the street, brakes and pulls up beside the steps: its cruising speed, when it starts braking and
## when it stops; where it stops (its middle: across, out from the wall's line, and along, from the casino's middle).
@export_range(2.0, 30.0, 0.1, "suffix:m/s") var cruise_speed: float = 12.0
@export_range(0.0, 60.0, 0.05, "suffix:s") var brake_at: float = 3.3
@export_range(0.0, 60.0, 0.05, "suffix:s") var stop_at: float = 6.6
@export_range(1.0, 5.0, 0.05, "suffix:m") var park_out: float = 2.5
@export_range(-10.0, 10.0, 0.05, "suffix:m") var park_along: float = 0.6
## Its lights go down as the engine stops; its door swings up (over door_seconds), the runner gets out (over
## get_out_seconds), the door comes down behind them.
@export_range(0.0, 60.0, 0.05, "suffix:s") var engine_off_at: float = 7.0
@export_range(0.0, 60.0, 0.05, "suffix:s") var door_up_at: float = 7.6
@export_range(0.2, 3.0, 0.05, "suffix:s") var door_seconds: float = 0.9
@export_range(0.0, 60.0, 0.05, "suffix:s") var get_out_at: float = 8.4
@export_range(0.5, 4.0, 0.05, "suffix:s") var get_out_seconds: float = 1.7
@export_range(0.0, 60.0, 0.05, "suffix:s") var door_down_at: float = 10.9
## The screech on the passenger seat looks round at the runner as they get out, and nods to them.
@export_range(0.0, 60.0, 0.05, "suffix:s") var passenger_looks_at: float = 8.0
@export_range(0.0, 60.0, 0.05, "suffix:s") var passenger_nods_at: float = 9.9

@export_group("The runner")
## Out of the car they turn to the steps, walk to their foot (walk_speed) and stop there, looking up them.
@export_range(0.0, 60.0, 0.05, "suffix:s") var turn_at: float = 10.3
@export_range(0.0, 60.0, 0.05, "suffix:s") var walk_at: float = 10.6
@export_range(0.3, 3.0, 0.05, "suffix:m/s") var walk_speed: float = 1.0
## Where they stop: out from the foot of the steps (metres toward the street) and along from their middle.
@export_range(0.0, 4.0, 0.05, "suffix:m") var stop_out: float = 0.55
@export_range(-5.0, 5.0, 0.05, "suffix:m") var stop_along: float = 0.0
## How far up they look at the top of the steps (degrees), and after, at the doors.
@export_range(0.0, 60.0, 1.0, "suffix:°") var look_up: float = 30.0

@export_group("The Chairman")
## Heights (feet to the top of the head; the runner is 1.28 m): the women, the men, the Chairman.
@export_range(1.0, 1.7, 0.01, "suffix:m") var woman_height: float = 1.26
@export_range(1.0, 1.7, 0.01, "suffix:m") var man_height: float = 1.34
@export_range(1.0, 1.7, 0.01, "suffix:m") var chairman_height: float = 1.42
## Where he stands at the top of the steps greeting people (x back from the stairs' top edge, z along from the
## casino's middle), the two he shakes hands with (each placed facing him from this offset in his frame: x to his
## right, y ahead of him), and when each handshake starts and how long it lasts.
@export var greet_point: Vector2 = Vector2(0.7, -0.6)
@export var greeter_a: Vector2 = Vector2(0.58, 0.34)
@export var greeter_b: Vector2 = Vector2(-0.58, 0.34)
@export_range(0.0, 60.0, 0.05, "suffix:s") var shake_a_at: float = 13.6
@export_range(0.0, 60.0, 0.05, "suffix:s") var shake_b_at: float = 15.4
@export_range(0.3, 3.0, 0.05, "suffix:s") var shake_seconds: float = 1.3
## A woman either side of him (x out to each side, y back from him): a step back and wider while he greets people
## (escort_greeting, clear of the two he greets), beside him as he walks in (escort_offset).
@export var escort_greeting: Vector2 = Vector2(1.05, 0.4)
## Then he turns and walks in through the doors (at walk_speed_chairman), the women beside him, and they are gone into
## the light this far past the doors.
@export_range(0.0, 60.0, 0.05, "suffix:s") var go_in_at: float = 16.9
@export_range(0.3, 3.0, 0.05, "suffix:m/s") var walk_speed_chairman: float = 1.1
@export var escort_offset: Vector2 = Vector2(0.6, 0.1)
@export_range(0.5, 5.0, 0.05, "suffix:m") var gone_past: float = 1.4
