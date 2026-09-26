class_name MovementTuning
extends Resource
## Every tunable number for player movement, piece sizes, the camera and touch input.
## Edit data/tuning/movement.tres in the inspector, or live in-game with the tuning panel (F6).
## The range hints drive both the inspector sliders and the in-game panel.
## Values marked DESIGN-TBD are prototype guesses, not design decisions.

@export_group("Run")
## DESIGN-TBD: base run speed is open (OPEN_QUESTIONS §8).
@export_range(5.0, 40.0, 0.5, "suffix:m/s") var run_speed: float = 18.0
## DESIGN-TBD: whether speed rises within a level is open. 0 = constant speed.
@export_range(0.0, 10.0, 0.1, "suffix:m/s per min") var speed_gain_per_minute: float = 0.0

@export_group("Lanes")
@export_range(1.5, 4.0, 0.05, "suffix:m") var lane_width: float = 2.4
## Time for one animated lane switch. The player is physically between lanes meanwhile.
@export_range(0.05, 0.4, 0.01, "suffix:s") var lane_switch_time: float = 0.14

@export_group("Jump & gravity")
@export_range(0.5, 4.0, 0.05, "suffix:m") var jump_height: float = 2.1
@export_range(0.15, 0.8, 0.01, "suffix:s") var jump_time_to_apex: float = 0.36
## Gravity multiplier while descending (above 1 = snappier landings).
@export_range(1.0, 3.0, 0.05) var fall_gravity_multiplier: float = 1.35
## Grace period after running off an edge during which jump (and wall entry) still work.
@export_range(0.0, 0.25, 0.01, "suffix:s") var coyote_time: float = 0.08
## A jump pressed this long before landing still fires on landing.
@export_range(0.0, 0.3, 0.01, "suffix:s") var jump_buffer_time: float = 0.14

@export_group("Slide")
@export_range(0.2, 1.5, 0.05, "suffix:s") var slide_duration: float = 0.7
## DESIGN-TBD: pressing slide in the air to drop fast is not in the design doc.
@export var air_slide_fast_fall: bool = true
@export_range(5.0, 40.0, 0.5, "suffix:m/s") var fast_fall_speed: float = 22.0

@export_group("Side walls")
## GDD §3: the player slides down the wall over 2 seconds, then drops to the floor.
@export_range(0.5, 4.0, 0.05, "suffix:s") var wall_slide_time: float = 2.0
## Time to move from the outer lane onto the wall.
@export_range(0.05, 0.5, 0.01, "suffix:s") var wall_entry_time: float = 0.16
## DESIGN-TBD: entry heights are not specified yet.
@export_range(0.5, 5.0, 0.05, "suffix:m") var wall_entry_height: float = 2.2
## Extra entry height gained per metre of height the player had when entering from a jump.
@export_range(0.0, 1.5, 0.05) var wall_air_entry_factor: float = 0.6
@export_range(1.0, 6.0, 0.1, "suffix:m") var wall_max_height: float = 4.5
## Shapes the descent curve. 1 = linear; above 1 lingers high then drops faster.
@export_range(0.5, 4.0, 0.05) var wall_descent_exponent: float = 1.6
## Height at which the wall run ends and the player drops to the floor.
@export_range(0.0, 1.5, 0.05, "suffix:m") var wall_exit_height: float = 0.4
@export_range(0.0, 12.0, 0.25, "suffix:m/s") var wall_jump_velocity: float = 6.0
## Gap between the outer lane edge and the wall face.
@export_range(0.0, 1.0, 0.05, "suffix:m") var wall_margin: float = 0.3

@export_group("Ramps")
## DESIGN-TBD: ramp values are open (OPEN_QUESTIONS §4).
@export_range(1.0, 6.0, 0.1, "suffix:m") var ramp_entry_height: float = 4.0
@export_range(0.0, 15.0, 0.5, "suffix:m/s") var ramp_speed_boost: float = 0.0
@export_range(0.5, 20.0, 0.5, "suffix:m/s per s") var ramp_boost_decay_per_second: float = 4.0

@export_group("Ceiling")
@export_range(3.5, 10.0, 0.1, "suffix:m") var ceiling_height: float = 6.0
## Speed toward the ceiling given by an anti-grav pad at the moment it flips gravity.
@export_range(0.0, 20.0, 0.5, "suffix:m/s") var antigrav_launch_velocity: float = 6.0

@export_group("Collision forgiveness")
## Half-extents of the player's footprint used for floor support. Wider = more forgiving at gap edges.
@export_range(0.0, 0.6, 0.01, "suffix:m") var foot_half_width: float = 0.3
@export_range(0.0, 0.6, 0.01, "suffix:m") var foot_half_depth: float = 0.25
## Damage hitbox (smaller than the visual body, per GDD §3).
@export var hurtbox_size: Vector3 = Vector3(0.6, 1.45, 0.5)
@export_range(0.3, 1.2, 0.05, "suffix:m") var hurtbox_slide_height: float = 0.6
@export var visual_size: Vector3 = Vector3(0.8, 1.7, 0.7)
## Once this far below the floor without support, the player is falling into the gap:
## no more lane switches, jumps or wall entries.
@export_range(0.05, 1.0, 0.05, "suffix:m") var pit_depth: float = 0.35
## How far below the surface the player may drop before counting as a fall death.
@export_range(1.0, 10.0, 0.5, "suffix:m") var fall_death_depth: float = 4.0

@export_group("Piece sizes")
## Full-height fence: jump over it or switch lanes.
@export_range(0.5, 3.0, 0.05, "suffix:m") var fence_full_top: float = 1.4
## Gapped fence: open underneath, slide under it.
@export_range(0.5, 2.0, 0.05, "suffix:m") var fence_gapped_bottom: float = 1.0
@export_range(1.5, 5.0, 0.05, "suffix:m") var fence_gapped_top: float = 2.8
@export_range(0.1, 1.0, 0.05, "suffix:m") var fence_depth: float = 0.3
## Seconds of warning (flicker + buzz) before a pulsing fence switches on.
@export_range(0.1, 1.0, 0.05, "suffix:s") var fence_pulse_warning: float = 0.35
## How far a sign sticks out from the wall face.
@export_range(0.3, 1.5, 0.05, "suffix:m") var sign_depth: float = 0.9
@export_range(0.5, 5.0, 0.1, "suffix:m") var pad_length: float = 2.0
@export_range(1.0, 8.0, 0.1, "suffix:m") var ramp_length: float = 4.0

@export_group("Camera")
@export_range(3.0, 15.0, 0.1, "suffix:m") var camera_distance: float = 7.5
@export_range(1.0, 8.0, 0.1, "suffix:m") var camera_height: float = 4.2
@export_range(2.0, 30.0, 0.5, "suffix:m") var camera_look_ahead: float = 14.0
@export_range(40.0, 100.0, 1.0, "suffix:°") var camera_fov: float = 70.0
## Share of the player's sideways offset the camera follows (0 = fixed at track centre).
@export_range(0.0, 1.0, 0.05) var camera_follow_x: float = 0.55
@export_range(0.0, 1.0, 0.05) var camera_follow_y: float = 0.45
## Camera height while the player is on the ceiling (the camera drops below and looks up).
@export_range(0.5, 5.0, 0.1, "suffix:m") var camera_ceiling_height: float = 2.4
@export_range(1.0, 30.0, 0.5) var camera_smoothing: float = 8.0

@export_group("Touch")
## Swipe length needed, as a fraction of the screen's short side.
@export_range(0.01, 0.2, 0.005) var swipe_min_distance: float = 0.05
## A touch shorter than this that doesn't move counts as a tap (dash).
@export_range(0.05, 0.5, 0.01, "suffix:s") var tap_max_time: float = 0.22


func gravity() -> float:
	return 2.0 * jump_height / (jump_time_to_apex * jump_time_to_apex)


func jump_velocity() -> float:
	return 2.0 * jump_height / jump_time_to_apex


## Horizontal distance covered by a full jump from flat ground at the given speed.
func jump_distance(speed: float) -> float:
	var g_up: float = gravity()
	var g_down: float = g_up * fall_gravity_multiplier
	var t_up: float = jump_velocity() / g_up
	var t_down: float = sqrt(2.0 * jump_height / g_down)
	return (t_up + t_down) * speed
