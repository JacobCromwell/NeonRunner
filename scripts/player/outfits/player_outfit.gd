class_name PlayerOutfit
extends RefCounted
## An outfit for Razor Echo (GDD §8, "Cosmetics"): a look for the runner that the player buys in the
## shop and wears instead of his own (PlayerSuit). The runner stays Razor Echo: an outfit is clothes and
## an arm on the same skeleton, so every pose, the animation, the 75% scale and the hitbox are
## unchanged, and the owned power-ups are still added on top of it. Visual only.
##
## One file per outfit, `scripts/player/outfits/<id>.gd`, `extends PlayerOutfit`, where <id> is its id in
## data/shop/catalog.json. PlayerOutfits finds the file by that name (nothing else to register), composes
## the HumanoidParts and gives them to every PlayerAvatar that wears it. Override what the outfit changes:
##
##   body_pieces()          everything but the head: the pelvis, chest, arms, hands, legs and feet, as
##                          HumanoidPieces on those segments (Echo's own coat, arms and boots are NOT
##                          kept: an outfit dresses the whole body). Required.
##   head_pieces()          the neck and head. Echo's stay his own (PlayerSuit.head_pieces) unless the
##                          outfit covers them: return its own, or `super()` plus a mask or a hat.
##   panels()               stiff flaps hinged at the waist that the rig swings (a coat's skirt); none by
##                          default. Echo's coat skirt is not kept either.
##   attachment_overrides() power-up sets (claws, armor, weapon_1..4, magnet) refitted to this outfit's
##                          shapes, by name. Echo's sets are used for every one not named.
##
## The rules an outfit follows (the owner's, October 18, 2026):
## - No weapon of any kind, and nothing that could be taken for a power-up (steel blades, a shoulder
##   emitter, an azure coil), since those are what the power-up looks are.
## - The colours and glows are the outfit's own, hazard colours included: outfits are free of the colour
##   rule (the base look keeps it). Keep glows thin and soft so bloom doesn't turn them into blobs.
## - The size is Echo's: the hair tips must still average PlayerSuit.DESIGN_SIZE.y over a stride, and the
##   whole look, every power-up on, stays inside test_avatar's triangle and draw-call budgets.
## - Read from the gameplay camera (behind and above): the back view is what the player sees all game.
##
## Piece coordinates are the segment's joint space at design scale (metres; +y up the rest pose, -z the
## way the runner faces, +x his right). Limb pieces are authored for the right limb and mirrored with
## `side` (MIRRORED both, RIGHT/LEFT one). `add()` and `pipe()` below are the builders PlayerSuit uses.

const BOX := HumanoidPiece.Shape.BOX
const PRISM := HumanoidPiece.Shape.PRISM
const LATHE := HumanoidPiece.Shape.LATHE
const BAND := HumanoidPiece.Shape.BAND
const TORUS := HumanoidPiece.Shape.TORUS
const SHELL := HumanoidPiece.Shape.SHELL
const MIRRORED := HumanoidPiece.Placement.MIRRORED
const RIGHT := HumanoidPiece.Placement.RIGHT
const LEFT := HumanoidPiece.Placement.LEFT
const CENTER := HumanoidPiece.Placement.CENTER


## Everything below the neck, on the segments pelvis, chest, upper_arm, forearm, hand, thigh, shin and foot.
func body_pieces() -> Array[HumanoidPiece]:
	return []


## The neck and head (segments neck and head). Echo's own unless the outfit covers it.
func head_pieces() -> Array[HumanoidPiece]:
	return PlayerSuit.head_pieces()


## The outfit's skirt or coat tails (at most HumanoidRig.MAX_PANELS), swung by the rig like Echo's.
func panels() -> Array[HumanoidPanel]:
	return []


## Power-up sets refitted to the outfit: name (&"armor", &"weapon_2", ...) -> Array[HumanoidPiece].
func attachment_overrides() -> Dictionary:
	return {}


# --- Builders -------------------------------------------------------------------------

## A piece; `extra` sets any other HumanoidPiece property by name (side, chamfer, profile, shine, ...).
static func piece(segment: StringName, shape: HumanoidPiece.Shape, size: Vector3, at: Vector3, color: Color,
		glow: float = 0.0, extra: Dictionary = {}) -> HumanoidPiece:
	var p := HumanoidPiece.new()
	p.segment = segment
	p.shape = shape
	p.size = size
	p.offset = at
	p.color = color
	p.glow = glow
	for key: String in extra:
		p.set(key, extra[key])
	return p


## Adds a piece to `list` (see `piece`).
static func add(list: Array[HumanoidPiece], segment: StringName, shape: HumanoidPiece.Shape, size: Vector3,
		at: Vector3, color: Color, glow: float = 0.0, extra: Dictionary = {}) -> void:
	list.append(piece(segment, shape, size, at, color, glow, extra))


## A thin three-sided pipe from `a` to `b` (a cable, a circuit line, a strap edge) with its flat face
## toward `face`.
static func pipe_piece(segment: StringName, a: Vector3, b: Vector3, width: float, face: Vector3, color: Color,
		glow: float = 0.0) -> HumanoidPiece:
	var along: Vector3 = b - a
	var y: Vector3 = along.normalized()
	var z: Vector3 = (face - y * face.dot(y)).normalized()
	var basis := Basis(y.cross(z), y, z)
	return piece(segment, PRISM, Vector3(width, along.length() + width * 0.5, width), (a + b) * 0.5, color, glow,
		{"sides": 3, "rotation_degrees": basis.get_euler() * (180.0 / PI)})


## Adds a pipe to `list` (see `pipe_piece`); `side` places it on one limb or both.
static func pipe(list: Array[HumanoidPiece], segment: StringName, a: Vector3, b: Vector3, width: float, face: Vector3,
		color: Color, glow: float = 0.0, side: HumanoidPiece.Placement = HumanoidPiece.Placement.CENTER) -> void:
	var p: HumanoidPiece = pipe_piece(segment, a, b, width, face, color, glow)
	p.side = side
	list.append(p)


## `base` with `more` merged over it (piece options shared by several pieces).
static func merged(base: Dictionary, more: Dictionary) -> Dictionary:
	var out: Dictionary = base.duplicate()
	out.merge(more, true)
	return out
