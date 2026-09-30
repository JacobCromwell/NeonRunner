class_name CineActor
extends Resource
## A character in a cinematic (CineTimeline.actors), on the shared humanoid rig: the runner (Razor
## Echo, PlayerAvatar) or a cyborg (CyborgBody, in its zone's look). It moves along its keys
## (CineActorKey) and is in the scene from `enter` until `leave`.

enum Kind { RUNNER, CYBORG }

## The name keys, camera shots and aims refer to it by.
@export var id: StringName = &"runner"
@export var kind: Kind = Kind.RUNNER
## A cyborg's look: a skin's enemy_variant or a look's own name (CyborgSuit.look_for). Empty: the
## stage's zone look (its skin's enemy_variant), as the zone's enemies wear.
@export var look: StringName = &""
## A cyborg carrying a Bad Dream (GDD §9.7): the host's purple glitch and veins.
@export var host: bool = false
## Seconds when it appears and leaves (leave below 0: stays to the end).
@export_range(0.0, 120.0, 0.05, "or_greater", "suffix:s") var enter: float = 0.0
@export_range(-1.0, 120.0, 0.05, "or_greater", "suffix:s") var leave: float = -1.0
## Its path, sorted by time.
@export var keys: Array[CineActorKey] = []


## Adds a key (for cinematics written in a script) and returns it for further settings.
func at(time: float, position: Vector3, pose: StringName = &"", move: CinePath.Move = CinePath.Move.LINEAR) -> CineActorKey:
	var k := CineActorKey.new()
	k.time = time
	k.position = position
	k.pose = pose
	k.move = move
	k.trans = Tween.TRANS_LINEAR
	keys.append(k)
	return k
