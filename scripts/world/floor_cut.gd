class_name FloorCut
extends Node3D
## One floor cut on the track (task B4; GDD §9.9: the floor the Buzz Overdrive's saw cuts "becomes a
## gap, from where it started charging all the way back past the player"). The generator planned it
## (LevelLayout.cuts, FloorCutPlan); TrackBuilder builds it as a piece of its own, in the chunk where
## its stretch starts, and its cause runs it:
## - advance_to(d): the cause is at track distance d. The cut's front follows it back toward the
##   player and never comes back: the floor of [start, front] stays whole, [front, end] is a gap.
## - stop(): the cause died. The cut stops where it is, and the floor beyond it stays whole.
## - hold_under(player, seconds) (or hold()): after the shield or the armor blocked the cause, the floor
##   under the player holds for about a second (GameRules.cut_hold_seconds), as far ahead as they can
##   run meanwhile, then goes too.
## Collision stays physical: one static body on the floor layer whose two convex shapes cover the whole
## floor (and the floor held after a block). Their points change at once (no waiting for the next
## physics step), so the player falls through a cut floor by the same physics as a normal gap
## (Player._support_top): what isn't there doesn't hold them. The look never needs rebuilding: the
## track draws the lane's floor in short slices with the skin's own floor_segment (add_slice), hidden
## once the front has passed them and the one it's in shortened to it, and the skin's floor_cut()
## draws the hole (FloorCutSection: its inside, the orange edges), which this node moves along. All of
## it is a handful of transforms a frame, on any renderer.
## Wall runners and ceiling riders never touch it: it only ever takes floor away, in its own lane.

signal finished(cut: FloorCut)

## Where a shape that holds nothing waits, far below the track.
const PARKED_Y: float = -1000.0

## The layout's entry (LevelLayout.cuts).
var entry: Dictionary = {}
var lane: int = 0
var start: float = 0.0
var end: float = 0.0
## Where the cut has got to: the floor of [start, front] is whole (and what a hold keeps).
var front: float = 0.0
## The cause died: the cut stays where it is (stop()).
var stopped: bool = false
## The floor held after a block: [hold_from, hold_to] stays whole until the level clock reaches
## hold_until (hold()).
var hold_from: float = 0.0
var hold_to: float = 0.0
var hold_until: float = -INF
var section: FloorCutSection

var _holding: bool = false
var _thickness: float = 1.0
var _body: StaticBody3D
var _solid: ConvexPolygonShape3D
var _held: ConvexPolygonShape3D
## The lane's floor over the stretch: {node, from, to}, in track order as the chunks build them.
var _slices: Array[Dictionary] = []


## Builds the cut for layout entry `cut` on a track of `geo`'s lanes: its collision (all of it whole),
## and the skin's look of the hole (ZoneSkin.floor_cut), hidden until the cut begins.
func setup(geo: TrackGeometry, cut: Dictionary, thickness: float, skin: ZoneSkin) -> void:
	name = "FloorCut"
	entry = cut
	lane = int(cut["lane"])
	start = float(cut["start"])
	end = float(cut["end"])
	front = end
	_thickness = thickness
	section = FloorCutSection.make(geo, cut, thickness)
	_body = StaticBody3D.new()
	_body.name = "Floor"
	_body.collision_layer = TrackBuilder.LAYER_FLOOR
	_body.collision_mask = 0
	add_child(_body)
	_solid = _add_shape()
	_held = _add_shape()
	var look := Node3D.new()
	look.name = "Look"
	add_child(look)
	if skin != null:
		skin.floor_cut(look, section)
	_apply()


## A key for the cut in `lane` whose cause waits at `end` (TrackBuilder.floor_cut).
static func key_for(p_lane: int, p_end: float) -> String:
	return "%d:%d" % [p_lane, roundi(p_end * 100.0)]


## True once the cut has begun (its front has left `end`).
func began() -> bool:
	return front < end - 0.0001


## True once the cut has reached `start`: the whole stretch is a gap.
func done() -> bool:
	return front <= start + 0.0001


## True if the floor at track distance `d` in the cut's lane is still there (whole, or held).
func solid_at(d: float) -> bool:
	return (d >= start and d <= front) or (_holding and d >= hold_from and d <= hold_to)


## True while the floor held after a block is still there.
func holding() -> bool:
	return _holding


## The cut's cause is at track distance `d`: the cut follows it toward `start` (never back toward
## `end`), unless it was stopped.
func advance_to(d: float) -> void:
	if stopped:
		return
	var next: float = clampf(minf(front, d), start, end)
	if next >= front:
		return
	front = next
	_apply()
	if done():
		finished.emit(self)


## The cause died (GDD §9.9: "killing it mid-charge stops the cut where it dies"): the cut stays where
## it is, and the floor of [start, front] stays whole for good.
func stop() -> void:
	stopped = true


## Holds the floor of [from, to] whole until the level clock reaches `until`, wider to the whole floor
## slices it touches so the floor that holds is exactly the floor that shows. A new hold replaces one
## still on.
func hold(from: float, to: float, until: float) -> void:
	var a: float = clampf(minf(from, to), start, end)
	var b: float = clampf(maxf(from, to), start, end)
	for s: Dictionary in _slices:
		if float(s["from"]) < b and float(s["to"]) > a:
			a = minf(a, float(s["from"]))
			b = maxf(b, float(s["to"]))
	hold_from = a
	hold_to = b
	hold_until = until
	_holding = b > a
	_apply()


## After the shield or the armor blocked the cut's cause (GDD §9.9: "after a block, the floor under the
## player holds for about a second, just enough to switch lanes"): the floor under `player` holds for
## `seconds` on the level clock, from just behind them to as far as they run meanwhile at their speed
## now (a jump lands back in the cut lane, and falls once the hold is over). DESIGN-TBD
## (docs/questions/b4.md): the held floor's look, the lane's own floor shown again with the cut's
## edges along it until it goes all at once.
func hold_under(player: Player, seconds: float) -> void:
	var reach: float = maxf(player.speed, 0.0) * seconds + 2.0
	hold(player.distance - 1.0, player.distance + reach, player.elapsed + seconds)


## The level clock (TrackBuilder.update, every physics frame before the player moves): a hold that's
## over lets go of the floor, so a player still on it falls this very frame.
func tick(level_time: float) -> void:
	if _holding and level_time >= hold_until:
		_holding = false
		_apply()


## One slice of the lane's floor over the stretch, drawn by the skin's floor_segment under `node`, from
## track distance `from` to `to` (TrackBuilder, as each chunk is built).
func add_slice(node: Node3D, from: float, to: float) -> void:
	_slices.append({"node": node, "from": from, "to": to})
	_apply_slice(_slices[-1])


## The slices of the lane's floor the track has built so far (tests and review tools).
func slices() -> Array[Dictionary]:
	return _slices


## Puts the collision, the floor's slices and the hole's look where the front and the hold say.
func _apply() -> void:
	_set_box(_solid, start, front)
	_set_box(_held, hold_from if _holding else 0.0, hold_to if _holding else 0.0)
	for s: Dictionary in _slices:
		_apply_slice(s)
	var on: bool = began()
	var k: float = clampf((end - front) / maxf(end - start, 0.001), 0.0, 1.0)
	for node: Node3D in section.statics:
		node.visible = true
	for node: Node3D in section.spans:
		node.visible = on
		# Built over [start, end]; scaled about `end` to cover [front, end].
		node.transform = Transform3D(Basis.from_scale(Vector3(1.0, 1.0, maxf(k, 0.0001))), Vector3(0.0, 0.0, end * (k - 1.0)))
	for node: Node3D in section.fronts:
		node.visible = on
		node.position = Vector3(0.0, 0.0, end - front)
	for node: Node3D in section.fars:
		node.visible = on


## Shows a floor slice whole, shortened to the front, or not at all.
func _apply_slice(s: Dictionary) -> void:
	var node: Node3D = s["node"]
	if not is_instance_valid(node):
		return
	var from: float = s["from"]
	var to: float = s["to"]
	if (_holding and from < hold_to and to > hold_from) or to <= front + 0.0001:
		node.visible = true
		node.transform = Transform3D.IDENTITY
	elif from < front:
		var k: float = (front - from) / (to - from)
		node.visible = true
		node.transform = Transform3D(Basis.from_scale(Vector3(1.0, 1.0, k)), Vector3(0.0, 0.0, from * (k - 1.0)))
	else:
		node.visible = false


func _add_shape() -> ConvexPolygonShape3D:
	var shape := CollisionShape3D.new()
	var convex := ConvexPolygonShape3D.new()
	# A shape needs its points before it joins the physics world (an empty hull is an error).
	_set_box(convex, 0.0, 0.0)
	shape.shape = convex
	_body.add_child(shape)
	return convex


## The lane's floor box over [from, to] (top at y = 0), or far below the track when it's empty. A
## convex shape's points take effect at once.
func _set_box(shape: ConvexPolygonShape3D, from: float, to: float) -> void:
	var x0: float = section.x0
	var x1: float = section.x1
	var y0: float = -_thickness
	var y1: float = 0.0
	if to - from < 0.001:
		x0 = 0.0
		x1 = 0.01
		y0 = PARKED_Y
		y1 = PARKED_Y + 0.01
		from = 0.0
		to = 0.01
	var points := PackedVector3Array()
	for x: float in [x0, x1]:
		for y: float in [y0, y1]:
			for d: float in [from, to]:
				points.append(Vector3(x, y, TrackGeometry.world_z(d)))
	shape.points = points
