class_name HumanoidAnimTuning
extends Resource
## Pose parameters for HumanoidRig's procedural animation (CLAUDE.md principle 7: tunables live in
## data). The player's values are in data/tuning/avatar_animation.tres. Angles are degrees; lengths
## are metres at the rig's design scale. The range hints drive the inspector and the F6 panel.

@export_group("Run cycle")
## Distance covered by one full cycle (two steps) at low speed. With the default the planted foot
## stays put on the ground (no skating) up to max_cadence × stride_length m/s.
@export_range(0.5, 4.0, 0.05, "suffix:m") var stride_length: float = 2.1
## Leg cycles per second at most. Above max_cadence × stride_length the stride lengthens instead,
## so the legs stay readable at run speed (a planted foot at 18 m/s would need ~12 cycles/s).
@export_range(1.0, 6.0, 0.1, "suffix:cycles/s") var max_cadence: float = 3.3
## Speed at which the stride reaches full amplitude; slower is a jog.
@export_range(1.0, 20.0, 0.5, "suffix:m/s") var full_stride_speed: float = 6.0
## Below this speed the rig stands (idle).
@export_range(0.0, 3.0, 0.05, "suffix:m/s") var idle_speed: float = 0.5
@export_range(0.0, 80.0, 1.0, "suffix:°") var thigh_swing: float = 40.0
## Thighs sit this much further forward on average (runners reach forward more than back).
@export_range(-20.0, 30.0, 1.0, "suffix:°") var thigh_forward_bias: float = 12.0
## Knee bend while the leg swings through: the heel kick that reads well from behind.
@export_range(0.0, 150.0, 1.0, "suffix:°") var knee_lift: float = 115.0
## Knee bend while the foot is planted.
@export_range(0.0, 60.0, 1.0, "suffix:°") var knee_stance: float = 38.0
@export_range(0.0, 90.0, 1.0, "suffix:°") var arm_swing: float = 48.0
@export_range(0.0, 140.0, 1.0, "suffix:°") var elbow_bend: float = 88.0
## Arms held away from the body, so they stay visible outside the torso from behind.
@export_range(0.0, 45.0, 1.0, "suffix:°") var arm_out: float = 16.0
@export_range(0.0, 40.0, 1.0, "suffix:°") var forward_lean: float = 13.0
## Rise of the body during the flight phase of each step.
@export_range(0.0, 0.15, 0.005, "suffix:m") var bob_height: float = 0.035
@export_range(0.0, 30.0, 1.0, "suffix:°") var hip_twist: float = 7.0
## Shoulders counter-rotate against the hips.
@export_range(0.0, 40.0, 1.0, "suffix:°") var shoulder_twist: float = 11.0

@export_group("Blending")
## How fast poses blend into each other (1/s; higher = snappier).
@export_range(1.0, 60.0, 0.5, "suffix:1/s") var blend_speed: float = 14.0
## Blend speed into slide, stomp and death, which must read instantly.
@export_range(1.0, 80.0, 0.5, "suffix:1/s") var fast_blend_speed: float = 40.0

@export_group("Lane switch")
## Sideways lean into a lane switch.
@export_range(0.0, 45.0, 1.0, "suffix:°") var switch_lean: float = 16.0
@export_range(1.0, 60.0, 0.5, "suffix:1/s") var switch_lean_speed: float = 22.0

@export_group("Jump")
## Vertical speed that counts as a full rise (or a full fall) for the jump pose.
@export_range(1.0, 20.0, 0.25, "suffix:m/s") var jump_pose_speed: float = 7.0

@export_group("Landing")
## Squash on landing: the height shrinks by this fraction and the width grows by half of it.
@export_range(0.0, 0.4, 0.01) var land_squash: float = 0.14
@export_range(0.05, 0.6, 0.01, "suffix:s") var land_squash_time: float = 0.2
## Extra knee bend at the moment of landing.
@export_range(0.0, 60.0, 1.0, "suffix:°") var land_crouch: float = 30.0

@export_group("Slide")
## How far the body leans back from upright while sliding feet first.
@export_range(20.0, 80.0, 1.0, "suffix:°") var slide_lean_back: float = 64.0

@export_group("Wall run")
## Tilt away from the ground side while running on a wall (fighting gravity).
@export_range(0.0, 45.0, 1.0, "suffix:°") var wall_lean: float = 14.0
## The arm on the ground side reaches out for balance.
@export_range(0.0, 90.0, 1.0, "suffix:°") var wall_arm_reach: float = 55.0

@export_group("Juggernaut dash")
@export_range(0.0, 60.0, 1.0, "suffix:°") var dash_lean: float = 30.0
@export_range(0.5, 2.0, 0.05) var dash_stride_scale: float = 1.2
@export_range(0.5, 2.5, 0.05) var dash_cadence_scale: float = 1.3

@export_group("Death")
## Time for the collapse to reach the ground.
@export_range(0.2, 2.0, 0.05, "suffix:s") var death_time: float = 0.55

@export_group("Idle")
@export_range(0.05, 2.0, 0.05, "suffix:Hz") var breathe_rate: float = 0.35
@export_range(0.0, 10.0, 0.25, "suffix:°") var breathe_amount: float = 2.0
