class_name ArrivalFlyoverTuning
extends Resource
## The placeholder arrival flyover's numbers (ArrivalFlyover; data/cinematics/arrival_flyover.tres).
## DESIGN-TBD (docs/questions/f1.md 1): the whole flyover stands in for the story beats the owner will
## describe (GDD §1: 5-15 second cinematics).
##
## Heights keep clear of the street's furniture in every zone: nothing hangs over the lanes below
## about 10 m but ceilings (6 m up, their structure up to 13 m), so the camera stays under
## `glide_height` over open street and drops to the run camera's height before it passes under the
## ceiling. The cinematics tests check the path against the stage at 3, 5 and 6 lanes.

@export_group("Timing")
## How long it lasts (GDD §1: 5-15 s).
@export_range(5.0, 15.0, 0.1, "suffix:s") var duration: float = 9.5
## The opening shot (looking up the street at the zone's skyline, tilting down as the runner runs in)
## ends here, and the glide over the street behind the runner ends here; then it settles.
@export_range(1.0, 6.0, 0.1, "suffix:s") var reveal_end: float = 3.0
@export_range(2.0, 12.0, 0.1, "suffix:s") var glide_end: float = 6.3
## It settles into the run camera's view of the runner this long before the end.
@export_range(0.2, 4.0, 0.1, "suffix:s") var settled_before_end: float = 1.1
## From black at the start, and to black at the end.
@export_range(0.0, 2.0, 0.05, "suffix:s") var fade_in: float = 0.8
@export_range(0.0, 2.0, 0.05, "suffix:s") var fade_out: float = 0.45
## The zone's music fades in over this.
@export_range(0.0, 4.0, 0.1, "suffix:s") var music_fade: float = 1.5

@export_group("Card")
## The card naming the zone (before a boss, the boss) comes in here and stays this long.
@export_range(0.0, 5.0, 0.05, "suffix:s") var card_at: float = 0.9
@export_range(1.0, 6.0, 0.1, "suffix:s") var card_seconds: float = 2.9

@export_group("Camera")
## The opening shot: the camera starts this high, this far right of the runner's lane and this far
## along the track, looking up at a point this high and this far ahead...
@export_range(0.5, 6.0, 0.1, "suffix:m") var open_height: float = 2.4
@export_range(-3.0, 3.0, 0.1, "suffix:m") var open_side: float = 1.2
@export_range(-20.0, 20.0, 0.5, "suffix:m") var open_at: float = -4.0
@export_range(0.0, 80.0, 1.0, "suffix:m") var open_look_height: float = 34.0
@export_range(20.0, 200.0, 1.0, "suffix:m") var open_look_ahead: float = 80.0
## ...then rises and tilts down to look down the street, reaching this height and this far along.
@export_range(2.0, 9.5, 0.1, "suffix:m") var reveal_height: float = 7.5
@export_range(-10.0, 60.0, 0.5, "suffix:m") var reveal_at: float = 16.0
## The glide: above and behind the runner (height, how far behind, how far to the side), looking this
## far ahead of the runner at the street.
@export_range(2.0, 9.5, 0.1, "suffix:m") var glide_height: float = 6.0
@export_range(4.0, 30.0, 0.5, "suffix:m") var glide_behind: float = 8.5
@export_range(-3.0, 3.0, 0.1, "suffix:m") var glide_side: float = 1.1
@export_range(10.0, 80.0, 1.0, "suffix:m") var glide_look_ahead: float = 22.0
## The camera's lens, degrees (the run camera's own for the settled view: MovementTuning.camera_fov).
@export_range(30.0, 100.0, 0.5, "suffix:°") var fov: float = 70.0

@export_group("Runner")
## Where the runner starts, metres along the track (behind the camera: it runs in past it). It runs at
## the run speed (MovementTuning.run_speed).
@export_range(-40.0, 0.0, 0.5, "suffix:m") var runner_start: float = -22.0

@export_group("Stage")
## A ceiling (the zone's own kind) the runner and then the camera run under at the end: it starts this
## far behind where the runner ends up, and is this long.
@export_range(0.0, 60.0, 0.5, "suffix:m") var ceiling_before_end: float = 24.0
@export_range(10.0, 80.0, 1.0, "suffix:m") var ceiling_length: float = 52.0
## Holes in the floor beside the runner's lane (lane from the start lane, start, end): the zone's floor
## pieces with their edges, never in the runner's own lane.
@export var gaps: PackedVector3Array = PackedVector3Array([Vector3(-1.0, 46.0, 53.0), Vector3(1.0, 68.0, 75.0),
	Vector3(-1.0, 96.0, 102.0), Vector3(2.0, 58.0, 64.0), Vector3(-2.0, 80.0, 86.0)])
