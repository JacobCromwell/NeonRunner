class_name DashBreakable
extends Area3D
## Something on the track the juggernaut dash smashes: a zone doodad (GDD §3, owner, October 8, 2026:
## "dashing into one breaks it apart, and the player keeps their lane with no push and no damage"; task
## H5). The track builds it (TrackBuilder._build_doodad) with its collision under it (a doodad's body is
## this area, on the doodad and lane-blocker layers, and its standable top a StaticBody3D child on the
## floor layer) and the skin dresses it. The Player decides when the dash reaches it and calls smash();
## what the break looks and sounds like is the run's: Player.smashed (RunEffects.rubble flings pieces in
## `debris_colors`), and the `<kind>_smash` movement event (its sound, `doodad_smash.wav`, and a light
## shake).
##
## It stays broken for the rest of the attempt: smash() marks its layout entry (`entry`, "smashed"), which
## the track builder never builds again, and a chunk is built once in a world anyway. A retry generates
## the level again, so every one of them stands whole on the next attempt, and an attempt without a dash
## never touches one: its seeded run is exactly as before.
##
## The shared path task H7a's dash walls can extend: a kind of its own (`kind`, which names the movement
## event), its layout entry, its box and the colours its pieces fly off in. Enemies' fairness checks read
## the layout (LevelLayout.doodad_between), not the node, so they treat a smashed doodad's stretch as they
## did before it broke: an attack that waits for one waits the same on every attempt. DESIGN-TBD
## (docs/questions/h5.md 5).

## The break happened (smash()): its collision is off and its look hidden.
signal smashed

## What it is: &"doodad" (Player emits `doodad_smash` for it). Task H7a's dash walls add their own.
var kind: StringName = &"doodad"
## Its layout entry (a LevelLayout.doodads dictionary), marked "smashed" when it breaks.
var entry: Dictionary = {}
## Its collision box (width, height, length along the track), centred on this node.
var size: Vector3 = Vector3.ONE
## The colours its pieces fly off in, its look's own (ZoneSkin.doodad_debris_colors), set once the skin
## has dressed it; empty until then (RunEffects.rubble then uses a plain grey).
var debris_colors: PackedColorArray = PackedColorArray()


## True once it has broken (on this attempt).
func is_smashed() -> bool:
	return bool(entry.get("smashed", false))


## Breaks it: marks its layout entry, switches off its collision (its own layers and every collision
## object under it: a doodad's lane blocker and standable top go with its body) and hides its look.
## False (and nothing happens) if it was broken already.
func smash() -> bool:
	if is_smashed():
		return false
	entry["smashed"] = true
	collision_layer = 0
	for node: Node in find_children("*", "CollisionObject3D", true, false):
		(node as CollisionObject3D).collision_layer = 0
	visible = false
	smashed.emit()
	return true


## Its collision box in world space (where the pieces fly from).
func world_box() -> AABB:
	return AABB(global_position - size * 0.5, size)
