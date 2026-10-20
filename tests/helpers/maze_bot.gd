class_name MazeBot
extends RefCounted
## Runs a way MazeRoute found through a layout whose doodads stop the runner (task O2: the debris maze) on real physics:
## a Player on the layout's track from track distance `from`, in the route's start lane, presses the route's lane
## switches as its body's middle comes to where the route makes them, moves along a wall's face where the route does
## when it's stopped there, and dashes at a stop where the route dashes once the dash is ready, standing and waiting for
## it otherwise: the dash comes back `recharge` seconds after each (and after the start: the route's worst case, the
## dash just used). Tests only.
##   var bot := MazeBot.new(tree, level_tuning)
##   var r: Dictionary = await bot.run(layout, route, from, to, recharge)
## result: {alive, cause, reached (the body's middle got to `to`), distance, seconds (the level clock from `from` until
## then), stops, smashes, dashes, waits (seconds stood with the dash not ready), moves_left (route moves never made),
## blocked (lane switches the Player refused: lane_blocked), pushes, trace (with `trace` on: every frame's
## {t, d, x, lane, stopped, speed})}.

## A switch is pressed this far (metres) before the body's middle reaches where the route makes it: the press is read on
## the next frame.
const EARLY: float = 0.25
## How long past the route's time (seconds, and a share of it) the run may take before it's given up.
const GRACE_SECONDS: float = 6.0

var tree: SceneTree
var tuning: MovementTuning
var trace: bool = false


func _init(p_tree: SceneTree, p_tuning: MovementTuning) -> void:
	tree = p_tree
	tuning = p_tuning


func run(layout: LevelLayout, route: Dictionary, from: float, to: float, recharge: float) -> Dictionary:
	var world := Node3D.new()
	tree.root.add_child(world)
	var track := TrackBuilder.new()
	world.add_child(track)
	track.set_layout(layout, tuning)
	track.update(from, 0.0)
	var player := Player.new()
	world.add_child(player)
	player.setup(tuning, TrackGeometry.new(layout.lane_count, tuning), int(route.get("start_lane", 0)))
	player.wall_gaps = layout.wall_gaps
	player.dash_walls = layout.dash_walls
	player.wall_running = layout.wall_running
	player.doodads_stop = layout.doodads_stop
	player.distance = from
	var result := {"cause": "", "blocked": 0, "dashes": 0, "waits": 0.0, "trace": [], "events": []}
	player.died.connect(func(cause: String) -> void: result["cause"] = cause)
	player.movement_event.connect(func(kind: StringName) -> void:
		(result["events"] as Array).append([snappedf(player.elapsed, 0.01), snappedf(player.distance, 0.01), kind])
		if kind == &"lane_blocked":
			result["blocked"] = int(result["blocked"]) + 1)
	await tree.physics_frame
	await tree.physics_frame
	player.running = true
	var moves: Array = route.get("moves", [])
	var m: int = 0
	var cooldown: float = recharge
	var dt: float = 1.0 / Engine.physics_ticks_per_second
	var limit: int = int((float(route.get("seconds", 60.0)) * 1.25 + GRACE_SECONDS) * Engine.physics_ticks_per_second)
	var pressed: int = -1
	var reached: bool = false
	for frame: int in limit:
		if m < moves.size():
			var move: Dictionary = moves[m]
			var kind: String = String(move["kind"])
			var at: float = float(move["at"])
			var to_lane: int = int(move["to"])
			# Settled: no switch, bump or push under way (the lane a switch goes to is the player's from its start).
			var settled: bool = int(player.call(&"_switch_dir")) == 0
			if kind == "dash":
				# At the stop the route dashes from (its middle no further back than the route's step there).
				if player.stopped and settled and player.lane == int(move["lane"]) and player.distance >= at - MazeRoute.STEP:
					if cooldown <= 0.0:
						RunSim.act(player, &"dash")
						cooldown = recharge
						result["dashes"] = int(result["dashes"]) + 1
						m += 1
					else:
						result["waits"] = float(result["waits"]) + dt
			elif player.lane == to_lane:
				if settled:
					m += 1
					pressed = -1
			elif (kind == "switch" and player.distance >= at - EARLY) or (kind == "slide" and player.stopped):
				# One press a move (pressed again only once the last one has played out, should it have been refused).
				if pressed != m or settled:
					player.press(&"move_right" if to_lane > player.lane else &"move_left")
					pressed = m
		track.update(player.distance, player.elapsed)
		await tree.physics_frame
		cooldown -= dt
		if trace:
			(result["trace"] as Array).append({"t": player.elapsed, "d": player.distance, "x": player.position.x,
				"lane": player.lane, "stopped": player.stopped, "speed": player.speed})
		if not player.alive:
			break
		if player.distance >= to:
			reached = true
			break
	result["alive"] = player.alive
	result["reached"] = reached
	result["distance"] = player.distance
	result["seconds"] = player.elapsed
	result["stops"] = player.stops
	result["smashes"] = player.smashes
	result["pushes"] = player.pushes
	result["moves_left"] = moves.size() - m
	world.queue_free()
	await tree.process_frame
	return result
