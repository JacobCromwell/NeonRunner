class_name HumanoidPanel
extends Resource
## A stiff flap on a hinge at a HumanoidRig's waist: one panel of a coat's skirt. The rig swings it
## every frame (HumanoidRig, "Panels"): it hangs toward the feet in the character's own frame,
## follows the thigh on its side with a little lag and spring, trails in the wind of the run and
## flares when falling, while the leg on its side and the ground push it out of the way. It is never
## part of collision or gameplay.
##
## All panels of a rig are merged into one mesh (one draw call) on the pelvis joint; the body shader
## turns each panel's vertices about its hinge (humanoid_panels.gdshaderinc).
##
## Coordinates: the pelvis joint's space at design scale (metres; +y up, -z forward, +x the
## character's right). The hinge and pieces are authored for a panel on the right; a left panel
## (side -1) is the mirrored copy.

## 1 = on the right as authored, -1 = the mirrored copy on the left.
@export_range(-1, 1, 2) var side: int = 1
## True for a panel behind the leg (the leg pushes it backward), false for one in front of it.
@export var behind: bool = true
## The middle of the hinge line (the panel's top edge), in the pelvis joint's space.
@export var hinge: Vector3 = Vector3.ZERO
## Hinge to hem (metres), for keeping the hem off the ground and clear of the leg.
@export_range(0.05, 1.5, 0.01) var length: float = 0.5
## Share of its thigh's swing the panel follows (0 = only hangs, 1 = moves with the thigh).
@export_range(0.0, 1.0, 0.01) var follow: float = 0.5
## The panel's pieces (HumanoidPiece; their `segment` and `side` are ignored).
@export var pieces: Array[HumanoidPiece] = []


## The hinge in the pelvis joint's space, mirrored for a left panel.
func placed_hinge() -> Vector3:
	return Vector3(hinge.x * side, hinge.y, hinge.z)
