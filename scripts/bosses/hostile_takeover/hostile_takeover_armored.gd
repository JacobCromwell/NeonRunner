class_name HostileTakeoverArmored
extends BossPart
## Phase 2's armored carriage (GDD §10: "an armored carriage with no roof access blocks the way, so the
## player takes an anti-grav pad and rides the gunship's belly over it (the gunship is the ceiling)"): an
## armored car body over a carriage's whole roof (HostileTakeoverModel.armored: its front a sheer wall
## framed in the solid obstacles' yellow and black), HostileTakeoverTuning.armored_height tall, so no jump
## reaches its roof, with a solid body hitbox a little smaller than it (DamageRules: running into it
## kills, armor or not), and the anti-grav pads before it: rows of them in every lane on the carriage
## behind it (the zone's pad look), so a runner in any lane steps on one and is flipped up onto the
## gunship's belly as it comes down over them (HostileTakeoverContract). The contract only places it for
## a ride the gunship will fly: it's never there without its ceiling.
## Pooled: one car body and its pads, built once with the fight (nothing is made mid-fight), placed over
## a carriage for a ride (place) and put away once the runner is past it (release). A part of the boss
## that's no target and no kill of its own (is_obstacle).

## Pads per lane, at most (HostileTakeoverTuning.pad_rows' range).
const MAX_ROWS: int = 3
## The body's hitbox keeps this far inside its look, sideways and at its ends (metres): forgiving.
const HIT_INSET: float = 0.15

var tuning: HostileTakeoverTuning
var model: MeshInstance3D
var body_box: Hazard
## The pads: rows x lanes, built once.
var pads: Array[Area3D] = []
## The carriage it stands on (-1: put away), its roof's stretch, and its pads' rows (their near ends).
var carriage: int = -1
var span := Vector2.ZERO
var rows := PackedFloat32Array()

var _length: float = 50.0
var _width: float = 8.0
var _pad_size := Vector3.ONE


func _build() -> void:
	var params: Dictionary = spawn.get("params", {})
	tuning = params.get("tuning") as HostileTakeoverTuning
	if tuning == null:
		tuning = HostileTakeoverTuning.new()
	display_name = "Armored carriage"
	is_obstacle = true
	immune_to_weapons = true
	_length = maxf(float(params.get("length", 50.0)), 4.0)
	_width = world.geo.half_width() * 2.0
	model = MeshInstance3D.new()
	model.name = "Model"
	model.mesh = HostileTakeoverModel.armored(_length, _width, tuning.armored_height, world.skin)
	model.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(model)
	var h := Vector3(_width - HIT_INSET * 2.0, tuning.armored_height - HIT_INSET, _length - HIT_INSET * 2.0)
	body_box = add_hitbox(&"body", h, Vector3(0.0, h.y * 0.5, -_length * 0.5))
	body_box.hazard_name = "the armored carriage"
	_pad_size = Vector3(world.geo.lane_width * 0.7, 0.5, world.tuning.pad_length)
	for i: int in MAX_ROWS * world.geo.lane_count:
		var area := Area3D.new()
		area.name = "Pad%d" % i
		area.collision_layer = 0
		area.collision_mask = 0
		area.monitoring = false
		area.set_meta(&"kind", &"pad")
		area.top_level = true
		add_child(area)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = _pad_size
		shape.shape = box
		area.add_child(shape)
		world.skin.pad(area, _pad_size)
		pads.append(area)
	release()


## Stands it over carriage `k`'s roof `roof` (track distances), with its pads' rows starting at each of
## `pad_rows` (track distances, each a pad's length long) in every lane.
func place(k: int, roof: Vector2, pad_rows: PackedFloat32Array) -> void:
	carriage = k
	span = roof
	rows = pad_rows
	global_position = Vector3(0.0, 0.0, TrackGeometry.world_z(roof.x))
	visible = true
	body_box.set_enabled(true)
	var lanes: int = world.geo.lane_count
	for i: int in pads.size():
		@warning_ignore("integer_division")
		var row: int = i / lanes
		var area: Area3D = pads[i]
		var on: bool = row < pad_rows.size()
		area.visible = on
		area.collision_layer = TrackBuilder.LAYER_TRIGGER if on else 0
		if on:
			area.global_position = Vector3(world.geo.lane_x(i % lanes), _pad_size.y * 0.5,
				TrackGeometry.world_z(pad_rows[row]) - _pad_size.z * 0.5)
		else:
			area.global_position = Vector3(0.0, -200.0, 0.0)


## Puts it away (no body, no pads).
func release() -> void:
	carriage = -1
	visible = false
	if body_box != null:
		body_box.set_enabled(false)
	for area: Area3D in pads:
		area.visible = false
		area.collision_layer = 0
		area.global_position = Vector3(0.0, -200.0, 0.0)
	global_position = Vector3(0.0, -200.0, 0.0)


func in_use() -> bool:
	return carriage >= 0


## Its body's stretch along the track (its hitbox's).
func body_span() -> Vector2:
	return Vector2(span.x + HIT_INSET, span.x + _length - HIT_INSET)


## Never a target.
func targetable() -> bool:
	return false


## The fight is won: it stays as it is (a ride under way finishes).
func _on_defeated(_cause: StringName) -> void:
	pass
