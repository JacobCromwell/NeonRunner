class_name RunSim
extends RefCounted
## Runs a Player over a hand-built LevelLayout on real physics, for movement and interaction tests.
##   var sim := RunSim.new(tree, tuning)
##   var r: Dictionary = await sim.run(layout, start_lane, seconds, [[distance, &"jump"]], [probe_distance])
## `actions`: [distance, action] pairs, each fired once when the player reaches that distance.
## `probes`: distances at which to record the player's state in result["at"][distance].

var tree: SceneTree
var tuning: MovementTuning


func _init(p_tree: SceneTree, p_tuning: MovementTuning) -> void:
	tree = p_tree
	tuning = p_tuning


static func layout(lanes: int, length: float = 400.0) -> LevelLayout:
	var out := LevelLayout.new()
	out.lane_count = lanes
	out.length = length
	return out


static func fence(lane: int, at: float, variant: String) -> Dictionary:
	return {"lane": lane, "at": at, "variant": variant, "pulsing": false,
		"pulse_on": 1.0, "pulse_off": 1.0, "phase": 0.0}


func run(p_layout: LevelLayout, start_lane: int, seconds: float, actions: Array,
		probes: Array = [], p_tuning: MovementTuning = null) -> Dictionary:
	var t: MovementTuning = p_tuning if p_tuning != null else tuning
	var world := Node3D.new()
	tree.root.add_child(world)
	var track := TrackBuilder.new()
	world.add_child(track)
	track.set_layout(p_layout, t)
	track.update(0.0, 0.0)
	var player := Player.new()
	world.add_child(player)
	player.setup(t, TrackGeometry.new(p_layout.lane_count, t), start_lane)
	var result := {"cause": "", "max_wall_h": 0.0, "events": [], "at": {}}
	player.died.connect(func(cause: String) -> void: result["cause"] = cause)
	player.movement_event.connect(func(kind: StringName) -> void: result["events"].append(kind))
	await tree.physics_frame
	await tree.physics_frame
	player.running = true
	var pending: Array = actions.duplicate()
	var pending_probes: Array = probes.duplicate()
	var frames: int = int(seconds * Engine.physics_ticks_per_second)
	for i: int in frames:
		while not pending.is_empty() and player.distance >= float(pending[0][0]):
			player.press(pending.pop_front()[1])
		track.update(player.distance, player.elapsed)
		await tree.physics_frame
		while not pending_probes.is_empty() and player.distance >= float(pending_probes[0]):
			result["at"][pending_probes.pop_front()] = {"surface": player.surface_name(), "lane": player.lane,
				"h": player.h, "sliding": player.is_sliding(), "alive": player.alive}
		if player.surface == Player.Surface.WALL:
			result["max_wall_h"] = maxf(result["max_wall_h"], player.h)
		if not player.alive:
			break
	for d: Variant in pending_probes:
		result["at"][d] = {"surface": "not reached", "lane": -1, "h": 0.0, "sliding": false, "alive": player.alive}
	result["alive"] = player.alive
	result["surface"] = player.surface_name()
	result["lane"] = player.lane
	result["distance"] = player.distance
	result["grounded"] = player.grounded
	world.queue_free()
	await tree.process_frame
	return result
