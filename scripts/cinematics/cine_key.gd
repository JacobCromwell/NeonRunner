class_name CineKey
extends Resource
## One key on a cinematic path (a camera key or an actor key): a time and how the path comes into this
## key from the one before it (CinePath has the details). Keys of a path are sorted by time.

## Seconds from the cinematic's start.
@export_range(0.0, 120.0, 0.05, "or_greater", "suffix:s") var time: float = 0.0
## How the path reaches this key: SMOOTH (a flight through the keys, never a jolt), LINEAR (a straight
## move timed by `trans` and `easing`) or CUT (holds the key before, then jumps here at `time`).
@export var move: CinePath.Move = CinePath.Move.SMOOTH
## LINEAR moves: Tween's transition type (how the move speeds up and slows down) and ease type.
@export var trans: Tween.TransitionType = Tween.TRANS_SINE
@export var easing: Tween.EaseType = Tween.EASE_IN_OUT
