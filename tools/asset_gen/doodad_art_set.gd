class_name DoodadArtSet
extends RefCounted
## One zone's doodad pictures and how they go onto the doodads' boxes, while the generator paints them
## (tools/asset_gen/doodad_art_gen.gd). A zone's art script (tools/asset_gen/doodad_art/*_art.gd) asks
## for canvases sized to the boxes' faces, paints them, and adds designs: a size class's look as a
## list of cards (a face of the box, or a card inside it) each showing one picture. The generator then
## packs every picture into the zone's atlas and writes the manifest DoodadCards reads in the game.
##
## A card: {plane, at, rect, image, flip}.
##   plane  "z": across the lane, facing the runner (the box's front is at = 1, its back at = 0);
##          "x": along the lane (the side at x+ is at = 1, the side at x- at = 0);
##          "y": level (the top is at = 1).
##   rect   [u0, v0, u1, v1], the share of the box the card covers on its plane: on a "z" plane u runs
##          from x- to x+ and v from the bottom up; on an "x" plane u runs from the box's front back
##          along the lane and v up; on a "y" plane u runs from x- to x+ and v from the front back.
##   image  the picture's name; flip mirrors it left to right.
## Pictures are drawn as seen from outside the box: a front face's left edge is x-, a side's left
## edge is the end toward the runner as seen from the x+ side (the x- side flips it), a top's top
## edge is the far end (the back).

## Pixels per metre of every picture (a doodad's front is 2.6 m tall: 250 pixels).
var px_per_m: float = 96.0
var zone: String
## The boxes' sizes by size class (MovementTuning.doodad_size): the pictures are drawn to fit them.
var boxes: Dictionary = {}
## Finished pictures by name.
var pictures: Dictionary = {}
## Designs by size class: Array of {name, colors, cards}.
var designs: Dictionary = {}


func _init(p_zone: String, tuning: MovementTuning) -> void:
	zone = p_zone
	for size: StringName in LevelLayout.DOODAD_SIZES:
		boxes[String(size)] = tuning.doodad_size(size)


func box(size_class: String) -> Vector3:
	return boxes[size_class]


## A blank canvas `w` × `h` metres.
func canvas(w: float, h: float) -> DoodadPaint:
	return DoodadPaint.new(w, h, px_per_m)


## Canvases sized to a box's front (width × height), side (length × height) and top (width × length).
func front_canvas(size_class: String) -> DoodadPaint:
	var b: Vector3 = box(size_class)
	return canvas(b.x, b.y)


func side_canvas(size_class: String) -> DoodadPaint:
	var b: Vector3 = box(size_class)
	return canvas(b.z, b.y)


func top_canvas(size_class: String) -> DoodadPaint:
	var b: Vector3 = box(size_class)
	return canvas(b.x, b.z)


## Keeps a finished picture under `name` (zone-unique).
func add_picture(name: String, p: DoodadPaint) -> String:
	assert(not pictures.has(name), "picture %s added twice" % name)
	pictures[name] = p.finish()
	return name


## Adds a look for `size_class`: its `cards`, and its main `colors` (the pieces' colours if it's ever
## smashed, and the look's summary in the manifest).
func add_design(size_class: String, name: String, colors: Array[Color], cards: Array[Dictionary]) -> void:
	if not designs.has(size_class):
		designs[size_class] = []
	var hexes: Array[String] = []
	for c: Color in colors:
		hexes.append(c.to_html(false))
	(designs[size_class] as Array).append({"name": name, "colors": hexes, "cards": cards})


# --- Cards ----------------------------------------------------------------------------------------

static func card(plane: String, at: float, image: String, rect: Array = [0.0, 0.0, 1.0, 1.0], flip: bool = false) -> Dictionary:
	return {"plane": plane, "at": at, "rect": rect, "image": image, "flip": flip}


## The box's front, facing the runner (a picture drawn as seen from the front).
static func front(image: String, rect: Array = [0.0, 0.0, 1.0, 1.0]) -> Dictionary:
	return card("z", 1.0, image, rect)


## The box's back (the front's picture, seen from behind: mirrored).
static func back(image: String, rect: Array = [0.0, 0.0, 1.0, 1.0]) -> Dictionary:
	return card("z", 0.0, image, rect, true)


## Both long sides from one picture drawn as seen from the x+ side, its end toward the runner on the
## left. The x- side shows it mirrored, so from there that end is on the right, where it belongs.
static func sides(image: String, rect: Array = [0.0, 0.0, 1.0, 1.0]) -> Array[Dictionary]:
	return [card("x", 1.0, image, rect), card("x", 0.0, image, rect, true)]


static func top(image: String, rect: Array = [0.0, 0.0, 1.0, 1.0], at: float = 1.0) -> Dictionary:
	return card("y", at, image, rect)


## A whole box: front and back from `front_image`, both sides from `side_image`, and the top.
static func box_cards(front_image: String, side_image: String, top_image: String = "") -> Array[Dictionary]:
	var out: Array[Dictionary] = [front(front_image), back(front_image)]
	out.append_array(sides(side_image))
	if not top_image.is_empty():
		out.append(top(top_image))
	return out
