class_name CineCameraKey
extends CineKey
## A camera key of a cinematic (CineTimeline.camera): where the camera is, what it looks at and its lens
## at `time`. Points are in track space (CineStage: x metres right of the start lane's centre, y metres
## up, z metres along the track), or offsets from an actor that the key follows or watches (x right,
## y up, z ahead of the actor), so a shot can ride along with the runner. Between keys the camera moves
## as `move` says (CinePath).

## Where the camera is: a track-space point, or an offset from the actor named in `follow`.
@export var position: Vector3 = Vector3(0.0, 4.2, -7.5)
## What it looks at: a track-space point, or an offset from the actor named in `watch`.
@export var target: Vector3 = Vector3(0.0, 1.0, 14.0)
## An actor's id: `position` is an offset from that actor (it rides along). Empty: a track-space point.
@export var follow: StringName = &""
## An actor's id: `target` is an offset from that actor (it's kept in view). Empty: a track-space point.
@export var watch: StringName = &""
## Field of view, degrees (vertical, like the game camera's MovementTuning.camera_fov).
@export_range(10.0, 120.0, 0.5, "suffix:°") var fov: float = 70.0
## Roll about the view direction, degrees (+ = clockwise as seen).
@export_range(-60.0, 60.0, 0.5, "suffix:°") var roll: float = 0.0
