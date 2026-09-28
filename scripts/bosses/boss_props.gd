class_name BossProps
extends Node3D
## What a boss puts in the arena within sight during its fight (GDD §10), built with the track's
## collision layers and the zone skin's looks, and freed once the player is past it. (Pieces planned
## further ahead go on the track itself: BossArena.add_pieces.) Every call takes track coordinates
## (lane, distance, wall side) and returns the node, which a boss script may move (a fence rolled
## across the lanes), switch (Hazard.set_enabled) or remove early (remove()):
## - fence(lane, at, variant, warning_seconds): a pink electric fence with the normal fence rules
##   (armor, the shield and the dash get through; claws don't); it can come in flickering first;
## - block(lane, at, size): a solid obstacle slammed into a lane (The House's gold blocks): deadly to
##   run into, solid to switch lanes into; the boss script adds its look;
## - pad(lane, at) and ceiling(start, end): an anti-grav pad and a ceiling section (the zone's looks);
## - block_wall(side, from, to): a stretch of wall the player can't enter (the Sewer Swarm climbs one
##   wall at a time); the boss script draws what took it;
## - lane_warning(lane, from, to) and circle_warning(at, lane, radius): the red floor warnings of an
##   attack (a lane about to be struck, a bomb's target circle), pulsing, or glowing steadily with
##   Reduced flashing (Settings); warned() says where they are (pickups keep off them);
## - keep(node, until): anything else, freed once the player is past `until`.
## The node sits at the world origin whatever its parent does (top_level).

## A prop is freed once the player is this far past its end.
const KEEP_BEHIND: float = 30.0
## The warnings' colour: enemy-attack red, in every zone (CLAUDE.md readability rules).
const WARNING_COLOR := Color(1.0, 0.12, 0.08)

var world: RunWorld
## Placed props: {node, until}.
var _placed: Array[Dictionary] = []
## Warnings that pulse: {node, base: Transform3D, t}.
var _pulsing: Array[Dictionary] = []
## Floor warnings, for warned(): {node, from, to, x0, x1} (track distances, world x).
var _warned: Array[Dictionary] = []


func setup(p_world: RunWorld) -> void:
	world = p_world
	top_level = true
	transform = Transform3D.IDENTITY


## A pink electric fence across `lane` at track distance `at`: "full" (jump it or switch lanes) or
## "gapped" (slide under it). With `warning_seconds`, it flickers harmlessly (and crackles) that long
## before it switches on, the fence's own warning.
func fence(lane: int, at: float, variant: String = "full", warning_seconds: float = 0.0) -> Hazard:
	var t: MovementTuning = world.tuning
	var gapped: bool = variant == "gapped"
	var bottom: float = t.fence_gapped_bottom if gapped else 0.0
	var top: float = t.fence_gapped_top if gapped else t.fence_full_top
	var size := Vector3(world.geo.lane_width - 0.2, top - bottom, t.fence_depth)
	var hazard: Hazard = _hazard(Vector3(world.geo.lane_x(lane), (bottom + top) * 0.5, TrackGeometry.world_z(at)),
		size, TrackBuilder.LAYER_HAZARD)
	hazard.hazard_name = "fence (%s)" % variant
	hazard.is_electrical = true
	world.skin.fence(hazard, size, -(bottom + top) * 0.5, gapped)
	if warning_seconds > 0.0:
		_add_warning_sound(hazard)
		_warn_then_arm(hazard, warning_seconds)
	keep(hazard, at + t.fence_depth)
	return hazard


## A solid obstacle filling `lane` from `at` on (size: width, height and depth in metres): deadly to
## run into, and the player can't switch lanes into it (a truck's side). Armor doesn't stop it; the
## shield and the dash do (the shared rules for solid collisions).
func block(lane: int, at: float, size: Vector3, block_name: String = "block") -> Hazard:
	var center := Vector3(world.geo.lane_x(lane), size.y * 0.5, TrackGeometry.world_z(at + size.z * 0.5))
	var hazard: Hazard = _hazard(center, size, TrackBuilder.LAYER_HAZARD)
	hazard.hazard_name = block_name
	hazard.is_solid = true
	var blocker := Area3D.new()
	blocker.collision_layer = TrackBuilder.LAYER_LANE_BLOCKER
	blocker.collision_mask = 0
	blocker.monitoring = false
	hazard.add_child(blocker)
	_add_shape(blocker, size)
	keep(hazard, at + size.z)
	return hazard


## An anti-grav pad in `lane` at `at`, with the zone's pad look. Give it a ceiling above (ceiling()),
## or the player flips up into nothing and drops straight back.
func pad(lane: int, at: float) -> Area3D:
	var size := Vector3(world.geo.lane_width * 0.7, 0.5, world.tuning.pad_length)
	var area := Area3D.new()
	area.collision_layer = TrackBuilder.LAYER_TRIGGER
	area.collision_mask = 0
	area.monitoring = false
	area.set_meta(&"kind", &"pad")
	area.position = Vector3(world.geo.lane_x(lane), size.y * 0.5, TrackGeometry.world_z(at) - size.z * 0.5)
	add_child(area)
	_add_shape(area, size)
	world.skin.pad(area, size)
	keep(area, at + size.z)
	return area


## A ceiling section over every lane from `start` to `end`, with the zone's ceiling look.
func ceiling(start: float, end: float) -> Node3D:
	var root := Node3D.new()
	root.name = "Ceiling"
	add_child(root)
	var section := CeilingSection.make(world.geo, world.tuning.ceiling_height, TrackBuilder.HULL_THICKNESS, start, end,
		Vector2i(0, world.geo.lane_count - 1))
	var body := StaticBody3D.new()
	body.collision_layer = TrackBuilder.LAYER_HULL
	body.collision_mask = 0
	body.position = section.center
	root.add_child(body)
	_add_shape(body, section.size)
	world.skin.ceiling_section(root, section)
	keep(root, end)
	return root


## Takes the wall on `side` (-1 left, +1 right) away between two track distances: the player can't
## enter it there (like a sign, without the hurt). The boss script shows what took it, and removes it
## (remove()) to give the wall back.
func block_wall(side: int, from: float, to: float) -> Area3D:
	var area := Area3D.new()
	area.collision_layer = TrackBuilder.LAYER_WALL_BLOCKER
	area.collision_mask = 0
	area.monitoring = false
	area.position = Vector3(side * (world.geo.wall_x() - 0.3), 5.0, -(from + to) * 0.5)
	add_child(area)
	_add_shape(area, Vector3(0.6, 12.0, maxf(to - from, 0.1)))
	keep(area, to)
	return area


## A red warning line on the floor of `lane` from track distance `from` to `to`: where an attack
## will strike. It pulses as long as it's shown (a steady glow with Reduced flashing).
func lane_warning(lane: int, from: float, to: float) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.mesh = GreyboxMaterials.unit_box()
	mesh.material_override = GreyboxMaterials.glow(WARNING_COLOR, 2.6, 0.75)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var base := Transform3D(Basis.from_scale(Vector3(world.geo.lane_width * 0.34, 0.04, absf(to - from))),
		Vector3(world.geo.lane_x(lane), 0.03, -(from + to) * 0.5))
	mesh.transform = base
	add_child(mesh)
	_pulsing.append({"node": mesh, "base": base, "t": 0.0})
	_warned.append({"node": mesh, "from": minf(from, to), "to": maxf(from, to),
		"x0": world.geo.lane_x(lane) - world.geo.lane_width * 0.5, "x1": world.geo.lane_x(lane) + world.geo.lane_width * 0.5})
	keep(mesh, maxf(from, to))
	return mesh


## A red target circle on the floor at track distance `at` over `lane` (x offset `x` from the lane's
## centre): where a bomb or a blow will land.
func circle_warning(at: float, lane: int, radius: float = 1.0, x: float = 0.0) -> MeshInstance3D:
	var ring := TorusMesh.new()
	ring.inner_radius = radius * 0.78
	ring.outer_radius = radius
	ring.rings = 24
	ring.ring_segments = 6
	var mesh := MeshInstance3D.new()
	mesh.mesh = ring
	mesh.material_override = GreyboxMaterials.glow(WARNING_COLOR, 2.6, 0.85)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var base := Transform3D(Basis.from_scale(Vector3(1.0, 0.25, 1.0)),
		Vector3(world.geo.lane_x(lane) + x, 0.05, TrackGeometry.world_z(at)))
	mesh.transform = base
	add_child(mesh)
	_pulsing.append({"node": mesh, "base": base, "t": 0.0})
	var cx: float = world.geo.lane_x(lane) + x
	_warned.append({"node": mesh, "from": at - radius, "to": at + radius, "x0": cx - radius, "x1": cx + radius})
	keep(mesh, at + radius)
	return mesh


## Keeps `node` (added here if it has no parent) until the player is KEEP_BEHIND past `until`.
func keep(node: Node3D, until: float) -> Node3D:
	if node.get_parent() == null:
		add_child(node)
	_placed.append({"node": node, "until": until})
	return node


## Removes a prop now (a warning after its attack, a wall given back).
func remove(node: Node) -> void:
	if node != null and is_instance_valid(node) and not node.is_queued_for_deletion():
		if node is Hazard:
			(node as Hazard).set_enabled(false)
		node.queue_free()


## True while a floor warning (lane_warning, circle_warning) still shown reaches the middle of `lane`
## (where a runner in that lane is: a circle that only grazes the lane's edge doesn't count) somewhere
## between track distances `from` and `to`: an attack is telegraphed there.
func warned(lane: int, from: float, to: float) -> bool:
	var x0: float = world.geo.lane_x(lane) - world.geo.lane_width * 0.25
	var x1: float = world.geo.lane_x(lane) + world.geo.lane_width * 0.25
	for i: int in range(_warned.size() - 1, -1, -1):
		var w: Dictionary = _warned[i]
		if not is_instance_valid(w["node"]) or (w["node"] as Node).is_queued_for_deletion():
			_warned.remove_at(i)
			continue
		if float(w["from"]) <= to and float(w["to"]) >= from and float(w["x0"]) < x1 and float(w["x1"]) > x0:
			return true
	return false


## Props placed so far and still in the arena.
func count() -> int:
	var n: int = 0
	for p: Dictionary in _placed:
		if is_instance_valid(p["node"]) and not (p["node"] as Node).is_queued_for_deletion():
			n += 1
	return n


func _physics_process(_delta: float) -> void:
	if world == null or world.player == null:
		return
	var d: float = world.player.distance
	for i: int in range(_placed.size() - 1, -1, -1):
		var p: Dictionary = _placed[i]
		if not is_instance_valid(p["node"]):
			_placed.remove_at(i)
		elif float(p["until"]) < d - KEEP_BEHIND:
			remove(p["node"])
			_placed.remove_at(i)


func _process(delta: float) -> void:
	for i: int in range(_pulsing.size() - 1, -1, -1):
		var w: Dictionary = _pulsing[i]
		if not is_instance_valid(w["node"]):
			_pulsing.remove_at(i)
			continue
		var node: MeshInstance3D = w["node"]
		w["t"] = float(w["t"]) + delta
		# Widens as it's shown; the beat stops with Reduced flashing.
		var grow: float = 0.85 + 0.25 * clampf(float(w["t"]) / 0.8, 0.0, 1.0)
		var beat: float = 1.0 if Settings.flashing_reduced else 1.0 + 0.12 * sin(float(w["t"]) * 24.0)
		var base: Transform3D = w["base"]
		node.transform = Transform3D(base.basis * Basis.from_scale(Vector3(grow * beat, 1.0, 1.0 if node.mesh is BoxMesh else grow * beat)),
			base.origin)


func _hazard(center: Vector3, size: Vector3, layers: int) -> Hazard:
	var hazard := Hazard.new()
	hazard.size = size
	hazard.collision_layer = layers
	hazard.collision_mask = 0
	hazard.monitoring = false
	hazard.position = center
	add_child(hazard)
	_add_shape(hazard, size)
	return hazard


## The fence's warning sound (the track's pulsing fences crackle the same way).
func _add_warning_sound(hazard: Hazard) -> void:
	var sfx: SfxLibrary = world.sfx_library
	if sfx == null or sfx.stream(&"fence_warning") == null:
		return
	var telegraph := HazardTelegraph.new()
	hazard.add_child(telegraph)
	telegraph.bind(hazard, sfx.stream(&"fence_warning"), sfx.volume(&"fence_warning"),
		sfx.warning_full_volume_distance, sfx.warning_max_distance)


## Shows the hazard's WARNING state (harmless) for `seconds`, then switches it on.
func _warn_then_arm(hazard: Hazard, seconds: float) -> void:
	hazard.state = Hazard.State.WARNING
	hazard.state_changed.emit(Hazard.State.WARNING)
	# By id: a boss may remove the fence while it's still flickering in.
	var id: int = hazard.get_instance_id()
	get_tree().create_timer(seconds, false, true).timeout.connect(func() -> void:
		var h := instance_from_id(id) as Hazard
		if h != null and h.state == Hazard.State.WARNING:
			h.set_enabled(true))


static func _add_shape(owner_node: CollisionObject3D, size: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	owner_node.add_child(shape)
