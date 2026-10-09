class_name DashBreakable
extends Area3D
## Something on the track the juggernaut dash smashes: a zone doodad (GDD §3, owner, October 8, 2026:
## "dashing into one breaks it apart, and the player keeps their lane with no push and no damage"; task
## H5), or a dash wall (GDD §9.14, owner, October 8, 2026: a building across the street that "crumbles and
## explodes into rubble"; task H7a). The track builds it (TrackBuilder._build_doodad, _build_dash_wall) with
## its collision under it and the skin dresses it:
## - a doodad's body is this area, on the doodad and lane-blocker layers, and its standable top a
##   StaticBody3D child on the floor layer;
## - a dash wall is this area on the dash wall layer (TrackBuilder.LAYER_DASH_WALL: the box its look fills,
##   which the Player's approach check finds), with a Hazard child, its forgiving hitbox (solid, armor
##   absorbs it: Hazard.armor_blocks_solid; and it breaks this at any contact: Hazard.breakable).
## The Player decides when the dash reaches it and calls smash() (and for a dash wall also on a crash or as a
## wall runner passes it); what the break looks and sounds like is the run's: Player.smashed (RunEffects
## flings its pieces in `debris_colors`: a doodad's rubble, a wall's bigger crumble and dust) and the
## `<kind>_smash` movement event (its sound: `doodad_smash.wav`, `dash_wall_smash.wav`; and a shake).
##
## It stays broken for the rest of the attempt: smash() marks its layout entry (`entry`, "smashed"), which
## the track builder never builds again, and a chunk is built once in a world anyway. A retry generates
## the level again, so every one of them stands whole on the next attempt, and an attempt that never
## touches one leaves it as it was: its seeded run is exactly as before.
##
## Enemies' fairness checks read the layout (LevelLayout.doodad_between, which counts a dash wall in every
## lane), not the node, so they treat a smashed one's stretch as they did before it broke: an attack that
## waits for one waits the same on every attempt. DESIGN-TBD (docs/OPEN_QUESTIONS.md item 638).

## The break happened (smash()): its collision is off and its look hidden.
signal smashed

## What it is: &"doodad" (Player emits `doodad_smash` for it) or &"dash_wall" (`dash_wall_smash`).
var kind: StringName = &"doodad"
## Its layout entry (a LevelLayout.doodads or LevelLayout.dash_walls dictionary), marked "smashed" when it
## breaks (and, for a dash wall, "broken_by": &"dash", &"crash" or &"pass").
var entry: Dictionary = {}
## Its collision box (width, height, length along the track), centred on this node: a dash wall's is the
## box its look fills (its hitbox is a Hazard child, a little smaller).
var size: Vector3 = Vector3.ONE
## The colours its pieces fly off in, its look's own (ZoneSkin.doodad_debris_colors,
## ZoneSkin.dash_wall_debris_colors), set once the skin has dressed it; empty until then (RunEffects then
## uses a plain grey).
var debris_colors: PackedColorArray = PackedColorArray()


## True once it has broken (on this attempt).
func is_smashed() -> bool:
	return bool(entry.get("smashed", false))


## How it broke: &"dash", &"crash" or &"pass" (a dash wall's), or &"" if it stands or nothing said.
func broken_by() -> StringName:
	return StringName(entry.get("broken_by", ""))


## Breaks it: marks its layout entry (with `how`, when given: entry["broken_by"]), switches off its
## collision (its own layers and every collision object under it: a doodad's lane blocker and standable top
## go with its body, a dash wall's hitbox with its box) and hides its look. False (and nothing happens) if it
## was broken already.
func smash(how: StringName = &"") -> bool:
	if is_smashed():
		return false
	entry["smashed"] = true
	if how != &"":
		entry["broken_by"] = String(how)
	collision_layer = 0
	for node: Node in find_children("*", "CollisionObject3D", true, false):
		(node as CollisionObject3D).collision_layer = 0
	visible = false
	smashed.emit()
	return true


## Its collision box in world space (where the pieces fly from).
func world_box() -> AABB:
	return AABB(global_position - size * 0.5, size)


## A dash wall's hitbox (its Hazard child), or null for a doodad.
func hitbox() -> Hazard:
	for child: Node in get_children():
		if child is Hazard:
			return child as Hazard
	return null
