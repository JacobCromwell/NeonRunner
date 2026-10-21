class_name TerminalOutroTuning
extends Resource
## The Terminal outro's numbers (TerminalOutro; data/cinematics/terminal_outro_tuning.tres). The beats are the owner's
## (October 21, 2026; GDD §6, Cinematics, "Terminal outro"): the runner finds an abandoned metro train, a modern one,
## dirty and run down and not a steam train; the camera pans along it (it looks still in working order); the runner
## tries its front door, shaking it once (it stays firm), then violently and noisily (it still won't open), bangs on it
## and throws their hands up; the friendly screech pops up in the door's window on the other side, squeaks and opens the
## door; the runner goes in and the camera pulls back to watch the train speed away down the tracks and out of sight.
## The rest (timings, places, the train's look, the camera, the sounds) is DESIGN-TBD (docs/questions/f2k.md). Times are
## seconds from the start; places are track space (CineStage: x metres right of the start lane's centre, y up, z along
## the track), the train's measured from its nose (z) and its lane's middle (x).

@export_group("Timing")
## Within the 20-28 s the brief asks for. It ends on black: the Golden Zone's intro opens on its own view.
@export_range(10.0, 60.0, 0.1, "suffix:s") var duration: float = 28.0
@export_range(0.0, 3.0, 0.05, "suffix:s") var fade_in: float = 0.8
@export_range(10.0, 60.0, 0.05, "suffix:s") var fade_at: float = 27.3
@export_range(0.0, 3.0, 0.05, "suffix:s") var fade_out: float = 0.7
## The zone's music comes in over this long (the Terminal's own track is a later task: none plays until it exists).
@export_range(0.0, 8.0, 0.1, "suffix:s") var music_fade: float = 2.0
## The shots' cuts: the runner looking at the train (from in front of them), the pan along the train, the runner at the
## front door, close on the window (the screech), the train leaving.
@export_range(0.0, 60.0, 0.05, "suffix:s") var look_shot_at: float = 3.6
@export_range(0.0, 60.0, 0.05, "suffix:s") var pan_shot_at: float = 5.2
@export_range(0.0, 60.0, 0.05, "suffix:s") var door_shot_at: float = 9.9
@export_range(0.0, 60.0, 0.05, "suffix:s") var window_shot_at: float = 16.4
@export_range(0.0, 60.0, 0.05, "suffix:s") var leave_shot_at: float = 20.4
## How long the stage's street is: past anything the camera sees.
@export_range(150.0, 2000.0, 10.0, "suffix:m") var stage_length: float = 500.0

@export_group("The train")
## How many cars it has (the two ends are cabs), where its tail stands along the street (its nose is its length on),
## and which lane it stands in, counted from the start lane (a street too narrow for a lane beside the start lane uses
## the start lane itself).
@export_range(2, 6) var cars: int = 4
@export_range(40.0, 200.0, 1.0, "suffix:m") var tail_at: float = 60.0
@export_range(-3, 0) var lane_offset: int = -1
## Its paint: a faded cream with a dull blue stripe, the dirt over it, and the rust coming through.
@export var paint: Color = Color(0.72, 0.68, 0.56)
@export var stripe: Color = Color(0.2, 0.34, 0.4)
## How dirty it is: 0 clean to 1 filthy (streaks, grime at the foot, flaking paint), and how much rust shows.
@export_range(0.0, 1.0, 0.01) var grime: float = 0.85
@export_range(0.0, 1.0, 0.01) var rust: float = 0.45
## The vines hanging off its roof (a few strips down its sides and over its tail; 0 none).
@export_range(0, 12) var vines: int = 6

@export_group("The approach")
## The runner jogs in at this speed (from as far back as they need to be, to arrive on time) and eases to a stop
## `stop_short` metres short of the train's tail at `stop_at` (the camera behind them), then looks up at it.
@export_range(2.0, 14.0, 0.1, "suffix:m/s") var run_speed: float = 7.0
@export_range(3.0, 30.0, 0.5, "suffix:m") var stop_short: float = 11.0
@export_range(1.0, 10.0, 0.05, "suffix:s") var stop_at: float = 3.0
## Their lane: they run beside the train (metres right of its middle line).
@export_range(0.0, 6.0, 0.1, "suffix:m") var run_side: float = 2.4
## The pan along the train: from near its tail at the cut, to near its nose, this far from its side (the street, or
## the kerb's edge, where it is too narrow for that).
@export_range(2.0, 12.0, 0.1, "suffix:m") var pan_distance: float = 5.2
@export_range(0.5, 3.0, 0.05, "suffix:m") var pan_height: float = 1.5

@export_group("The front door")
## The runner is walking up to the door as its shot opens; they stand on its step plate, `stand_off` metres in front of the nose.
@export_range(0.2, 0.5, 0.01, "suffix:m") var stand_off: float = 0.3
@export_range(0.3, 3.0, 0.05, "suffix:m/s") var walk_speed: float = 1.3
@export_range(0.0, 60.0, 0.05, "suffix:s") var arrive_at: float = 11.2
## They grip the handle and shake the door once, small and firm; pause; then shake it violently (the door rattling, the
## body heaving); bang on it with a fist (this many thumps, this far apart); then throw their hands up.
@export_range(0.0, 60.0, 0.05, "suffix:s") var shake_a_at: float = 11.7
@export_range(0.1, 3.0, 0.05, "suffix:s") var shake_a_seconds: float = 0.5
@export_range(0.0, 60.0, 0.05, "suffix:s") var shake_b_at: float = 12.7
@export_range(0.3, 5.0, 0.05, "suffix:s") var shake_b_seconds: float = 1.6
@export_range(2.0, 12.0, 0.1, "suffix:Hz") var shake_b_rate: float = 5.2
@export_range(0.0, 60.0, 0.05, "suffix:s") var bang_at: float = 14.5
@export_range(1, 8) var bangs: int = 3
@export_range(0.15, 1.0, 0.01, "suffix:s") var bang_gap: float = 0.34
@export_range(0.0, 60.0, 0.05, "suffix:s") var hands_up_at: float = 16.1
@export_range(0.5, 4.0, 0.05, "suffix:s") var hands_up_seconds: float = 2.15
## How far the door's leaf rattles at the first shake and the second (metres), and the camera's shake with the second
## (CineEvent.SHAKE's strength, scaled by Settings > Screen shake).
@export_range(0.0, 0.1, 0.002, "suffix:m") var rattle_small: float = 0.012
@export_range(0.0, 0.1, 0.002, "suffix:m") var rattle_big: float = 0.06
@export_range(0.0, 0.5, 0.01) var camera_shake: float = 0.08

@export_group("The screech")
## It is the screech friend from the other outros (BeachOutroScreech: the Gangland car's passenger, in the scavengers'
## look), this big (the fight's are 0.7), popping up in the door's window `pop_seconds` long from `pop_at`, squeaking at
## `squeak_at`; the door slides open from `open_at` over `open_seconds`; it hops down and trots in; the runner steps up
## and goes in from `walk_in_at` (and is gone `gone_after` seconds on); the door closes behind them from `close_at`.
@export_range(0.3, 1.0, 0.01) var screech_size: float = 0.55
@export var screech_look: StringName = &"scavenger"
@export_range(0.0, 60.0, 0.05, "suffix:s") var pop_at: float = 16.8
@export_range(0.2, 2.0, 0.05, "suffix:s") var pop_seconds: float = 1.3
@export_range(0.0, 60.0, 0.05, "suffix:s") var squeak_at: float = 17.1
@export_range(0.0, 60.0, 0.05, "suffix:s") var open_at: float = 18.2
@export_range(0.3, 3.0, 0.05, "suffix:s") var open_seconds: float = 0.9
@export_range(0.0, 60.0, 0.05, "suffix:s") var walk_in_at: float = 18.5
@export_range(0.3, 3.0, 0.05, "suffix:m/s") var walk_in_speed: float = 1.4
@export_range(0.0, 60.0, 0.05, "suffix:s") var close_at: float = 19.4
## How high the screech hops up to the window (metres above the vestibule's floor).
@export_range(0.1, 1.0, 0.01, "suffix:m") var pop_height: float = 0.7

@export_group("The departure")
## The train's lights come on (its headlights, tail lights and the saloon's, flickering on in the order of a failing
## strip; one slow glow with Reduced flashing), it starts, and accelerates away (`ramp` s to full acceleration).
@export_range(0.0, 60.0, 0.05, "suffix:s") var lights_at: float = 20.7
@export_range(0.0, 60.0, 0.05, "suffix:s") var start_at: float = 21.9
@export_range(1.0, 30.0, 0.1, "suffix:m/s²") var acceleration: float = 14.0
@export_range(0.2, 4.0, 0.05, "suffix:s") var ramp: float = 1.5
## How far the camera pulls back from the train's tail, and how high it rises, over the last shot.
@export_range(2.0, 40.0, 0.5, "suffix:m") var pull_back: float = 22.0
@export_range(1.0, 12.0, 0.1, "suffix:m") var pull_up: float = 5.0
