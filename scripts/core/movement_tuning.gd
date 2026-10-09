class_name MovementTuning
extends Resource
## Every tunable number for player movement, piece sizes, the camera and touch input.
## Edit data/tuning/movement.tres in the inspector, or live in-game with the tuning panel (F6).
## The range hints drive both the inspector sliders and the in-game panel.
## Values marked DESIGN-TBD are prototype guesses, not design decisions.

## The run speed the generator's patterns, the enemies' along-track distances and speeds and the
## rules' margins in metres were written for (18 m/s, the first build's speed everywhere). A faster
## run stretches them by pace() so every timing stays what it was in seconds (GDD §3, "Pace and busier
## levels": a faster zone is never secretly tighter). A unit, not a tunable.
const REFERENCE_SPEED: float = 18.0

@export_group("Run")
## The base run speed: quick play, the tests and boss fights run at it. A campaign level runs at its
## zone's speed instead (GDD §3, owner's playtest September 30, 2026: about 21 m/s in the Neon City
## rising to about 25 m/s in the Golden Zone; ZoneDef.run_speed, LevelConfig.run_speed).
@export_range(5.0, 40.0, 0.5, "suffix:m/s") var run_speed: float = 18.0
## DESIGN-TBD: whether speed rises within a level is open. 0 = constant speed.
@export_range(0.0, 10.0, 0.1, "suffix:m/s per min") var speed_gain_per_minute: float = 0.0

@export_group("Lanes")
@export_range(1.5, 4.0, 0.05, "suffix:m") var lane_width: float = 2.4
## Time for one animated lane switch. The player is physically between lanes meanwhile.
@export_range(0.05, 0.4, 0.01, "suffix:s") var lane_switch_time: float = 0.14

@export_group("Jump & gravity")
@export_range(0.5, 4.0, 0.05, "suffix:m") var jump_height: float = 1.6
@export_range(0.15, 0.8, 0.01, "suffix:s") var jump_time_to_apex: float = 0.36
## Gravity multiplier while descending (above 1 = snappier landings).
@export_range(1.0, 3.0, 0.05) var fall_gravity_multiplier: float = 1.35
## Grace period after running off an edge during which jump (and wall entry) still work.
@export_range(0.0, 0.25, 0.01, "suffix:s") var coyote_time: float = 0.08
## A jump pressed this long before landing still fires on landing.
@export_range(0.0, 0.3, 0.01, "suffix:s") var jump_buffer_time: float = 0.14

@export_group("Slide")
@export_range(0.2, 1.5, 0.05, "suffix:s") var slide_duration: float = 0.7
## A feel addition, not in the design doc: pressing slide in the air drops fast and slides on
## landing. Approved as is (owner's placeholder review, September 26, 2026).
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
## GDD §3 (decided September 26, 2026): a blocked entry (a sign, or a wall a boss takes away) plays
## the clank and bumps the player out toward the wall and back, like a blocked lane switch, so they
## see why they didn't get on. The bump stops short of anything in its way (a sign that reaches down
## to the player stops it at its face), so it never moves the player into a hazard.
## DESIGN-TBD: how far and how fast (the GDD says "a small sideways bump").
@export_range(0.0, 1.0, 0.05, "suffix:m") var wall_bump_distance: float = 0.35
## DESIGN-TBD: see wall_bump_distance.
@export_range(0.05, 0.5, 0.01, "suffix:s") var wall_bump_time: float = 0.16

@export_group("Ramps & speed pads")
## DESIGN-TBD: ramp values are open (OPEN_QUESTIONS §4).
@export_range(1.0, 6.0, 0.1, "suffix:m") var ramp_entry_height: float = 4.0
## GDD §3 (decided September 26, 2026): a ramp adds a speed boost that fades away the same way a
## speed pad's does (boost_decay_per_second). DESIGN-TBD: the size is a placeholder (a speed pad's
## boost) for the owner to tune after playtesting.
@export_range(0.0, 15.0, 0.5, "suffix:m/s") var ramp_speed_boost: float = 6.0
## How fast a speed boost fades away, a ramp's and a speed pad's alike (GDD §3): the extra speed
## drops by this much every second until it's gone (boost_left).
@export_range(0.5, 20.0, 0.5, "suffix:m/s per s") var boost_decay_per_second: float = 4.0
## Speed pads are only named in the GDD (§6: they arrive a few levels in). A pad in a floor lane
## adds this much speed, which then fades like a ramp's (approved as is, FB 21).
@export_range(0.0, 20.0, 0.5, "suffix:m/s") var speed_pad_boost: float = 6.0
@export_range(0.5, 5.0, 0.1, "suffix:m") var speed_pad_length: float = 2.5

@export_group("Ceiling")
@export_range(3.5, 10.0, 0.1, "suffix:m") var ceiling_height: float = 6.0
## Speed toward the ceiling given by an anti-grav pad at the moment it flips gravity.
@export_range(0.0, 20.0, 0.5, "suffix:m/s") var antigrav_launch_velocity: float = 6.0

@export_group("Collision forgiveness")
## Half-extents of the player's footprint used for floor support. Wider = more forgiving at gap edges.
@export_range(0.0, 0.6, 0.01, "suffix:m") var foot_half_width: float = 0.3
@export_range(0.0, 0.6, 0.01, "suffix:m") var foot_half_depth: float = 0.25
## Damage hitbox (smaller than the visual body, per GDD §3).
@export var hurtbox_size: Vector3 = Vector3(0.45, 1.09, 0.38)
@export_range(0.3, 1.2, 0.05, "suffix:m") var hurtbox_slide_height: float = 0.45
@export var visual_size: Vector3 = Vector3(0.6, 1.28, 0.52)
## Once this far below the floor without support, the player is falling into the gap:
## no more lane switches, jumps or wall entries.
@export_range(0.05, 1.0, 0.05, "suffix:m") var pit_depth: float = 0.35
## How far below the surface the player may drop before counting as a fall death.
@export_range(1.0, 10.0, 0.5, "suffix:m") var fall_death_depth: float = 4.0

@export_group("Piece sizes")
## Full-height fence: jump over it or switch lanes.
@export_range(0.5, 3.0, 0.05, "suffix:m") var fence_full_top: float = 1.05
## Gapped fence: open underneath, slide under it.
@export_range(0.5, 2.0, 0.05, "suffix:m") var fence_gapped_bottom: float = 0.75
@export_range(1.5, 5.0, 0.05, "suffix:m") var fence_gapped_top: float = 2.1
@export_range(0.1, 1.0, 0.05, "suffix:m") var fence_depth: float = 0.3
## Seconds of warning (flicker + buzz) before a pulsing fence switches on.
@export_range(0.1, 1.0, 0.05, "suffix:s") var fence_pulse_warning: float = 0.35
## Wall fences (task B5; GDD §9.1): an electric fence across the wall-run path, as deep as a fence
## (fence_depth), its field reaching out from the facade over the wall runner's body, with the floor
## fences' warning (fence_pulse_warning) before it switches on.
## DESIGN-TBD: the top of a full-height one, above the highest a wall run goes (wall_max_height, and
## half the body over it).
@export_range(3.0, 8.0, 0.05, "suffix:m") var wall_fence_top: float = 5.0
## DESIGN-TBD: a partial wall fence's bands (from the Corporate zone): the low one covers the wall from
## the floor up to wall_fence_low_top (passed above by entering the wall high: jumping onto it), the high
## one from wall_fence_high_bottom up to wall_fence_top (passed below by entering low: stepping onto the
## wall without a jump, or later in a wall run). A free entry (wall_entry_height, the body half a
## hurtbox's width either side of it) runs between the two.
@export_range(0.5, 3.0, 0.05, "suffix:m") var wall_fence_low_top: float = 1.8
@export_range(1.5, 4.5, 0.05, "suffix:m") var wall_fence_high_bottom: float = 2.8
## DESIGN-TBD: how far a wall fence's field reaches out from the facade toward the lanes: over a wall
## runner's body (which reaches about a hurtbox height out), never as far as a floor runner in the middle
## of the outer lane (WallFencePlan.reach holds it short of them).
@export_range(0.2, 1.5, 0.05, "suffix:m") var wall_fence_reach: float = 0.9
## How far a sign sticks out from the wall face.
@export_range(0.3, 1.5, 0.05, "suffix:m") var sign_depth: float = 0.9
@export_range(0.5, 5.0, 0.1, "suffix:m") var pad_length: float = 2.0
@export_range(1.0, 8.0, 0.1, "suffix:m") var ramp_length: float = 4.0

@export_group("Doodads")
## Zone doodads (GDD §3, owner's playtest September 30, 2026): scenery standing in a lane that never
## hurts; running into one pushes the player into a neighbouring lane. Their collision box, per size
## class (LevelLayout.DOODAD_SIZES; the zone's skin picks the look and keeps it inside the box).
## DESIGN-TBD (docs/questions/g5.md): the height, one for every class: too tall to jump (a jump's feet
## reach jump_height, 1.6 m) and low enough that a ceiling rider passes over it even mid-jump (the
## rider's head comes down to ceiling_height - jump_height - visual_size.y, about 3.1 m).
@export_range(1.8, 3.0, 0.05, "suffix:m") var doodad_height: float = 2.6
## DESIGN-TBD: each class's length along the lane and width across it (at most lane_width less a
## margin, so a neighbour passes it and a blocked switch's bump never reaches it).
@export_range(0.5, 4.0, 0.1, "suffix:m") var doodad_small_length: float = 1.4
@export_range(0.5, 2.2, 0.05, "suffix:m") var doodad_small_width: float = 1.3
@export_range(1.0, 8.0, 0.1, "suffix:m") var doodad_medium_length: float = 3.6
@export_range(0.5, 2.2, 0.05, "suffix:m") var doodad_medium_width: float = 1.9
@export_range(2.0, 12.0, 0.1, "suffix:m") var doodad_large_length: float = 6.5
@export_range(0.5, 2.2, 0.05, "suffix:m") var doodad_large_width: float = 2.0
## How long the push takes, from the doodad's lane to the neighbouring one: a quick shove (a lane
## switch takes lane_switch_time). DESIGN-TBD.
@export_range(0.05, 0.4, 0.01, "suffix:s") var doodad_push_time: float = 0.13

@export_group("Dash walls")
## Dash walls (task H7a; GDD §9.14, owner, October 8, 2026): a building standing across every floor lane,
## which the runner dashes through. Its look's box (TrackBuilder.dash_wall_size): this tall, this deep along
## the track, and as wide as the floor less dash_wall_wall_room beside each side wall. Its hitbox is that box
## less dash_wall_inset at its sides and its face (forgiving, CLAUDE.md principle 4), from just above the
## floor (so a slide never passes under it) to its top.
## DESIGN-TBD (docs/questions/h7a.md): taller than any jump: a jump's feet reach jump_height (1.6 m), a wall
## jump from the top of a wall run (wall_max_height) about 5.3 m; a building of two or three storeys.
@export_range(6.0, 16.0, 0.1, "suffix:m") var dash_wall_height: float = 9.0
## DESIGN-TBD: how deep the building is along the track (the runner bursts through it in a tenth of a second).
@export_range(0.5, 6.0, 0.1, "suffix:m") var dash_wall_depth: float = 2.5
## DESIGN-TBD: the strip beside each side wall the building leaves open, from the side wall's face in (GDD
## §9.14: "it blocks only the floor"; a player running on a side wall passes it). The hitbox's edge, this plus
## dash_wall_inset in from the wall's face, lies between the two runners' bodies: a wall runner's reaches a
## hurtbox's height (1.09 m) out from the wall's face, so it stays about 0.26 m clear of it; a floor runner's
## in the middle of the outer lane comes to wall_margin plus half a lane less half its body (1.28 m) from the
## wall's face, so most of it (0.38 m of its 0.45 m) is inside it.
@export_range(0.9, 1.6, 0.01, "suffix:m") var dash_wall_wall_room: float = 1.2
## DESIGN-TBD: how much smaller the hitbox is than the look, at its sides and its face.
@export_range(0.0, 0.5, 0.01, "suffix:m") var dash_wall_inset: float = 0.15

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
## How far below a ceiling's underside the camera stays while a ceiling is over it or just beside it
## (RunCamera.ceiling_limit). After a drop off a ceiling's far end the camera rises after the falling
## player; without this it climbed into the ceiling before passing its end, and what's drawn there
## filled the screen (the orange end band's glow, a flash and a glare).
@export_range(0.2, 3.0, 0.05, "suffix:m") var camera_ceiling_clearance: float = 1.0

@export_group("Touch")
## Swipe length needed, as a fraction of the screen's short side.
@export_range(0.01, 0.2, 0.005) var swipe_min_distance: float = 0.05
## A touch shorter than this that doesn't move counts as a tap (dash).
@export_range(0.05, 0.5, 0.01, "suffix:s") var tap_max_time: float = 0.22


## How much faster than REFERENCE_SPEED this tuning runs (1 at 18 m/s). Metres written for the
## reference speed (patterns, rules' margins, the enemies' along-track distances and speeds) are
## multiplied by it, so they keep their timing in seconds at any run speed.
func pace() -> float:
	return run_speed / REFERENCE_SPEED


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


## What's left of a speed boost of `boost` m/s after `seconds` (GDD §3: a ramp's boost fades away the
## same way a speed pad's does): it drops by boost_decay_per_second every second until it's gone.
## The Player fades its boost with this each physics frame.
func boost_left(boost: float, seconds: float) -> float:
	return maxf(boost - boost_decay_per_second * maxf(seconds, 0.0), 0.0)


## A doodad's collision box for size class `size` (LevelLayout.DOODAD_SIZES): Vector3(width, height,
## length), the length along the lane. An unknown class is the medium one.
func doodad_size(size: StringName) -> Vector3:
	match size:
		&"small":
			return Vector3(doodad_small_width, doodad_height, doodad_small_length)
		&"large":
			return Vector3(doodad_large_width, doodad_height, doodad_large_length)
	return Vector3(doodad_medium_width, doodad_height, doodad_medium_length)


## The extra track distance a boost of `boost` m/s adds over `seconds` while it fades (boost_left).
func boost_distance(boost: float, seconds: float) -> float:
	if boost <= 0.0:
		return 0.0
	var t: float = clampf(seconds, 0.0, boost / boost_decay_per_second)
	return boost * t - 0.5 * boost_decay_per_second * t * t
