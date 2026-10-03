class_name HostileTakeoverArmored
extends BossPart
## Phase 2's armored carriage (GDD §10: "an armored carriage with no roof access blocks the way, so the
## player takes an anti-grav pad and rides the gunship's belly over it (the gunship is the ceiling)"): an
## armored car body over a carriage's whole roof (HostileTakeoverModel.armored: its front a sheer wall
## framed in the solid obstacles' yellow and black), HostileTakeoverTuning.armored_height tall, so no jump
## reaches its roof, with a solid body hitbox a little smaller than it (DamageRules: running into it
## kills, armor or not, and no dash passes through it), and the anti-grav pads before it: a runway of them
## end to end in every lane on the carriage behind it (HostileTakeoverTuning.pad_strip: longer than any
## jump; the zone's pad look, tile by tile), each lane one trigger the lane's full width, so a runner on
## the roof steps on it wherever they are and is flipped up onto the gunship's belly as it comes down over
## them (HostileTakeoverContract). The contract only places it for a ride the gunship will fly: it's never
## there without its ceiling.
## Pooled: one car body and its runway, built once with the fight (nothing is made mid-fight; the
## runway's tiles one MultiMesh), placed over a carriage for a ride (place) and put away once the runner is
## past it (release). A part of the boss that's no target and no kill of its own (is_obstacle).

## The body's hitbox keeps this far inside its look, sideways and at its ends (metres): forgiving.
const HIT_INSET: float = 0.15
## The runway's tiles: a share of the lane's width, how tall the light over each one rises (metres),
## and about how long each one is (the pads' own length, MovementTuning.pad_length).
const TILE_WIDTH_SHARE: float = 0.7
const TILE_BEAM: float = 1.3

var tuning: HostileTakeoverTuning
var model: MeshInstance3D
var body_box: Hazard
## The runway: a trigger per lane, and its look (every lane's tiles).
var pads: Array[Area3D] = []
var runway: Node3D
## The carriage it stands on (-1: put away), its roof's stretch, and the runway's (track distances).
var carriage: int = -1
var span := Vector2.ZERO
var strip := Vector2.ZERO

var _length: float = 50.0
var _width: float = 8.0
var _strip_length: float = 18.0


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
	body_box.dash_passes = false
	_strip_length = tuning.pad_strip * world.tuning.pace()
	var lane_w: float = world.geo.lane_width
	var trigger := Vector3(lane_w, 0.5, _strip_length)
	runway = Node3D.new()
	runway.name = "Runway"
	runway.top_level = true
	add_child(runway)
	for lane: int in world.geo.lane_count:
		var area := Area3D.new()
		area.name = "Pad%d" % lane
		area.collision_layer = 0
		area.collision_mask = 0
		area.monitoring = false
		area.set_meta(&"kind", &"pad")
		runway.add_child(area)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = trigger
		shape.shape = box
		area.add_child(shape)
		area.position = Vector3(world.geo.lane_x(lane), trigger.y * 0.5, -_strip_length * 0.5)
		pads.append(area)
	_build_runway_look(lane_w)
	release()


## The runway's look: the zone's pads tile by tile down every lane, one MultiMesh (the arena's skin's lift
## pad), or each lane's trigger dressed as one long pad under another skin.
func _build_runway_look(lane_w: float) -> void:
	var tiles: int = maxi(roundi(_strip_length / maxf(world.tuning.pad_length, 0.5)), 1)
	var tile := Vector3(lane_w * TILE_WIDTH_SHARE, 0.5, _strip_length / tiles * 0.86)
	var skin := world.skin as HostileTakeoverSkin
	if skin == null:
		for area: Area3D in pads:
			world.skin.pad(area, Vector3(tile.x, tile.y, _strip_length))
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = skin.pad_tile(tile, TILE_BEAM)
	mm.instance_count = tiles * world.geo.lane_count
	var i: int = 0
	for lane: int in world.geo.lane_count:
		for t: int in tiles:
			mm.set_instance_transform(i, Transform3D(Basis.IDENTITY,
				Vector3(world.geo.lane_x(lane), tile.y * 0.5, -(t + 0.5) * _strip_length / tiles)))
			i += 1
	var look := MultiMeshInstance3D.new()
	look.name = "Tiles"
	look.multimesh = mm
	look.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	runway.add_child(look)


## Stands it over carriage `k`'s roof `roof` (track distances), its runway of pads from the start of
## `p_strip` (track distances; as long as the tuning's pad_strip at the run's pace) in every lane.
func place(k: int, roof: Vector2, p_strip: Vector2) -> void:
	carriage = k
	span = roof
	strip = Vector2(p_strip.x, p_strip.x + _strip_length)
	global_position = Vector3(0.0, 0.0, TrackGeometry.world_z(roof.x))
	visible = true
	body_box.set_enabled(true)
	runway.global_position = Vector3(0.0, 0.0, TrackGeometry.world_z(p_strip.x))
	runway.visible = true
	for area: Area3D in pads:
		area.collision_layer = TrackBuilder.LAYER_TRIGGER


## Puts it away (no body, no pads).
func release() -> void:
	carriage = -1
	visible = false
	if body_box != null:
		body_box.set_enabled(false)
	for area: Area3D in pads:
		area.collision_layer = 0
	if runway != null:
		runway.visible = false
		runway.global_position = Vector3(0.0, -200.0, 0.0)
	global_position = Vector3(0.0, -200.0, 0.0)


## The runway's length along the track (metres).
func strip_length() -> float:
	return _strip_length


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
