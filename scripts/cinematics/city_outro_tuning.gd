class_name CityOutroTuning
extends Resource
## The City outro's numbers (CityOutro; data/cinematics/city_outro_tuning.tres). The story beats are the
## owner's (GDD §6, Cinematics, October 8, 2026); the timing, the staging and every distance here are
## DESIGN-TBD placeholders (docs/OPEN_QUESTIONS.md §D, items 369–379) until the owner has watched it.
##
## Distances are along the track from where the runner starts (track space, CineStage), at the run speed
## (MovementTuning.run_speed); sideways distances are from the walls' faces or the start lane, so the scene
## reads the same at 3, 5 and 6 lanes.

@export_group("Timing")
## DESIGN-TBD (docs/OPEN_QUESTIONS.md §D, item 369): how long it lasts. GDD §1 asks for 5-15 s; the owner's
## beats are many.
@export_range(8.0, 30.0, 0.1, "suffix:s") var duration: float = 15.0
## The picture fades in from black at the start.
@export_range(0.0, 2.0, 0.05, "suffix:s") var fade_in: float = 0.5
## The ship hangs dying in the air (glitching, smoking) until this, then plunges for fall_seconds and
## crashes. Its face first keeps pace with the runner this far ahead.
@export_range(0.0, 3.0, 0.05, "suffix:s") var fall_start: float = 0.5
@export_range(0.5, 3.0, 0.05, "suffix:s") var fall_seconds: float = 1.4
@export_range(10.0, 60.0, 0.5, "suffix:m") var ship_ahead: float = 24.0
## Its belly's height as it hangs dying.
@export_range(0.0, 15.0, 0.5, "suffix:m") var ship_height: float = 4.0
## The runner runs on at the run speed until slow_from, then slows to a stop at stop_at.
@export_range(0.5, 8.0, 0.05, "suffix:s") var slow_from: float = 2.4
@export_range(1.0, 10.0, 0.05, "suffix:s") var stop_at: float = 4.0
## They turn their head left (look_degrees) over look_seconds once stopped, their body turning a little
## (look_body_degrees).
@export_range(0.2, 3.0, 0.05, "suffix:s") var look_seconds: float = 0.8
@export_range(0.0, 100.0, 1.0, "suffix:°") var look_degrees: float = 75.0
@export_range(0.0, 60.0, 1.0, "suffix:°") var look_body_degrees: float = 20.0
## The camera pans from the runner to the roadblock from pan_at over pan_seconds, holds on it (pushing in
## a little), and pans back to the runner from pan_back_at over pan_back_seconds.
@export_range(1.0, 12.0, 0.05, "suffix:s") var pan_at: float = 4.9
@export_range(0.3, 4.0, 0.05, "suffix:s") var pan_seconds: float = 1.6
@export_range(1.0, 14.0, 0.05, "suffix:s") var pan_back_at: float = 7.4
@export_range(0.3, 3.0, 0.05, "suffix:s") var pan_back_seconds: float = 0.7
## The roadblock comes alive as the camera reaches it: the siren and the light bar, the cyborgs raising
## their arm cannons (aim_at), their red charge glow and the turrets' (charge_at: the warning of the shots
## that follow, the blast).
@export_range(1.0, 14.0, 0.05, "suffix:s") var siren_at: float = 5.6
@export_range(1.0, 14.0, 0.05, "suffix:s") var aim_at: float = 6.2
@export_range(1.0, 14.0, 0.05, "suffix:s") var charge_at: float = 8.0
## The runner, startled: a hop back toward the right, startle_seconds long, its head snapping round.
@export_range(1.0, 14.0, 0.05, "suffix:s") var startle_at: float = 7.9
@export_range(0.2, 1.0, 0.05, "suffix:s") var startle_seconds: float = 0.4
@export_range(0.0, 1.0, 0.05, "suffix:m") var startle_hop: float = 0.35
## Then they run the other way, to the right wall's opening (flee_seconds), and leap off the truck roof
## out over the drop. The roadblock fires as they go: its shots land shots_seconds later, behind them on
## the edge they leapt from, in the blast (blast_after the leap).
@export_range(0.3, 3.0, 0.05, "suffix:s") var flee_seconds: float = 0.75
@export_range(0.05, 1.0, 0.05, "suffix:s") var shots_seconds: float = 0.3
@export_range(0.0, 1.0, 0.05, "suffix:s") var blast_after: float = 0.3
@export_range(0.3, 3.0, 0.05, "suffix:s") var blast_seconds: float = 1.3
@export_range(0.5, 4.0, 0.05, "suffix:m") var blast_radius: float = 2.0
## The blast's middle: this far back from the edge onto the roof they leapt from.
@export_range(0.0, 3.0, 0.05, "suffix:m") var blast_back: float = 1.5
## The leap: a jump's arc, up to leap_height over the edge and out leap_out beyond it at its apex
## (leap_apex_seconds after the leap), then on down the drop under the same pull, carrying on outward.
@export_range(0.0, 3.0, 0.05, "suffix:m") var leap_height: float = 1.4
@export_range(0.5, 6.0, 0.1, "suffix:m") var leap_out: float = 2.6
@export_range(0.2, 1.0, 0.05, "suffix:s") var leap_apex_seconds: float = 0.36
## The fall is seen this long after the leap; then the picture goes to black (black_seconds) and the scene
## cuts to Gangland under it.
@export_range(0.3, 3.0, 0.05, "suffix:s") var fall_shown: float = 1.0
@export_range(0.1, 1.5, 0.05, "suffix:s") var black_seconds: float = 0.4
@export_range(0.0, 1.0, 0.05, "suffix:s") var black_hold: float = 0.15
## In Gangland: the picture fades in, the runner drops from drop_height and lands drop_seconds after the
## cut, gets up and looks about, then runs off down the street from run_off_at; it fades to black at the end.
@export_range(0.1, 2.0, 0.05, "suffix:s") var land_fade_in: float = 0.45
@export_range(2.0, 15.0, 0.5, "suffix:m") var drop_height: float = 7.0
@export_range(0.2, 2.0, 0.05, "suffix:s") var drop_seconds: float = 0.75
@export_range(0.2, 4.0, 0.05, "suffix:s") var run_off_after: float = 1.3
@export_range(0.1, 2.0, 0.05, "suffix:s") var fade_out: float = 0.5
## The zone's music fades out over this once the runner leaps (Gangland's own comes in with its intro).
@export_range(0.0, 4.0, 0.1, "suffix:s") var music_fade: float = 1.2

@export_group("Places")
## The ship's face comes down this far beyond where the runner stops (its wreck lies past it).
@export_range(8.0, 60.0, 0.5, "suffix:m") var crash_beyond_stop: float = 18.0
## The side street on the left, where the roadblock stands: its middle this far along from where the runner
## stops, as many lanes wide as side_lanes (the City's truck roofs laid across it), side_depth deep, lined
## with the zone's building fronts; the wall's opening is side_margin wider on each end.
@export_range(-10.0, 15.0, 0.5, "suffix:m") var side_ahead: float = 3.0
@export_range(2, 4) var side_lanes: int = 3
@export_range(10.0, 80.0, 1.0, "suffix:m") var side_depth: float = 40.0
@export_range(0.0, 3.0, 0.1, "suffix:m") var side_margin: float = 0.4
## The opening in the right wall the runner leaps out of: from opening_before before the stop to
## opening_after past it. The runner reaches its edge flee_ahead further along than where they stopped.
@export_range(2.0, 20.0, 0.5, "suffix:m") var opening_before: float = 6.0
@export_range(4.0, 30.0, 0.5, "suffix:m") var opening_after: float = 12.0
## The buildings lining the opening (the zone's own wall look, as on the side street): this deep.
@export_range(5.0, 60.0, 1.0, "suffix:m") var opening_depth: float = 24.0
@export_range(0.0, 10.0, 0.5, "suffix:m") var flee_ahead: float = 4.0
## Where the runner lands in Gangland, along its street.
@export_range(10.0, 200.0, 1.0, "suffix:m") var land_at: float = 40.0

@export_group("Roadblock")
## Into the side street from the main street's wall line: the barricade with the turrets in it, the row of
## cyborgs just behind it, the battle truck's front, and the drone's height over the truck.
@export_range(0.5, 10.0, 0.1, "suffix:m") var barricade_in: float = 1.3
@export_range(0.5, 12.0, 0.1, "suffix:m") var cyborgs_in: float = 2.4
@export_range(2.0, 20.0, 0.1, "suffix:m") var truck_in: float = 4.2
@export_range(2.0, 10.0, 0.1, "suffix:m") var drone_height: float = 4.6
## The five cyborgs' spacing along the row, and how many Barnacle Turrets stand in the barricade.
@export_range(0.6, 2.0, 0.05, "suffix:m") var cyborg_spacing: float = 1.25
@export_range(1, 4) var turrets: int = 3
## Riders on the truck's roof (EnforcerTruckModel.set_riders) and its light bar's flash rate (it alternates
## red and blue, steady with Reduced flashing).
@export_range(0, 3) var truck_riders: int = 2
@export_range(0.5, 6.0, 0.1, "suffix:Hz") var light_bar_rate: float = 2.5

@export_group("Camera")
## The run camera's view at the start looks a little higher than in play, at the ship ahead.
@export_range(0.0, 6.0, 0.1, "suffix:m") var open_look_up: float = 2.5
## The camera comes down to the runner's level: ground_height up, ground_side to the runner's left and
## ground_behind behind them as they stop, looking past them down the street at the wreck. It pans from
## there, over their left shoulder, onto the roadblock and back.
@export_range(0.3, 2.0, 0.05, "suffix:m") var ground_height: float = 0.85
@export_range(0.0, 4.0, 0.1, "suffix:m") var ground_side: float = 1.3
@export_range(-2.0, 6.0, 0.1, "suffix:m") var ground_behind: float = 2.2
## On the roadblock it pushes in this far, its lens narrowing to reveal_fov.
@export_range(0.0, 3.0, 0.1, "suffix:m") var push_in: float = 0.8
@export_range(20.0, 90.0, 0.5, "suffix:°") var reveal_fov: float = 46.0
## The leap is seen from outside the street, out over the drop: leap_cam_out beyond the right wall's face,
## leap_cam_ahead along from the edge, leap_cam_height up, looking back at the edge.
@export_range(2.0, 15.0, 0.5, "suffix:m") var leap_cam_out: float = 5.5
@export_range(-6.0, 10.0, 0.5, "suffix:m") var leap_cam_ahead: float = 2.5
@export_range(-3.0, 4.0, 0.1, "suffix:m") var leap_cam_height: float = 1.6
## The landing is seen low in Gangland's street, land_cam_behind behind where the runner lands and
## land_cam_side to their side (- left), so they run off into the street ahead.
@export_range(2.0, 15.0, 0.5, "suffix:m") var land_cam_behind: float = 4.5
@export_range(-4.0, 4.0, 0.1, "suffix:m") var land_cam_side: float = -1.2
@export_range(0.3, 3.0, 0.05, "suffix:m") var land_cam_height: float = 0.9
## The lens (degrees), and a wider one for the leap.
@export_range(30.0, 100.0, 0.5, "suffix:°") var fov: float = 62.0
@export_range(30.0, 110.0, 0.5, "suffix:°") var leap_fov: float = 74.0
