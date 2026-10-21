class_name MazeKit
extends RefCounted
## Hand-made blocks of the debris maze (task O3), for tests and review tools that need one exact shape: a LevelLayout with
## one block, its record (LevelLayout.maze) and its debris (doodads marked "maze", "part" and "index") laid out as
## DebrisMaze lays them (walls one piece of their size in every closed lane, fronts level; dividers pieces a sliver apart
## along their lane from one wall to the next), so CentipedeMaze, DebrisMaze's questions and the Player see a real maze.
##   var layout: LevelLayout = MazeKit.block(tuning, 5, [[], [2]], [[1, 3]], {"entry": 60.0})
## `walls`: each wall's open lanes (one more wall than rooms); `rooms`: each room's divider lanes. Options: entry (track
## distance of the run-in's start), run_in (metres), room (each room's length, about: its dividers' pieces decide it),
## breather (metres), wall_size (&"medium" or &"large"), length (the layout's).

## A sliver between pieces (DebrisMaze.TOUCH).
const TOUCH: float = DebrisMaze.TOUCH


static func block(tuning: MovementTuning, lanes: int, walls: Array, rooms: Array, options: Dictionary = {}) -> LevelLayout:
	var out := LevelLayout.new()
	out.lane_count = lanes
	out.doodads_stop = true
	out.wall_running = false
	var entry: float = float(options.get("entry", 60.0))
	var run_in: float = float(options.get("run_in", 25.0))
	var room_target: float = float(options.get("room", 30.0))
	var breather: float = float(options.get("breather", 40.0))
	var wall_size: StringName = StringName(options.get("wall_size", &"medium"))
	var depth: float = tuning.doodad_size(wall_size).z
	var fill: Array[StringName] = DebrisMaze._fill(tuning, room_target)
	var room_length: float = DebrisMaze.fill_length(tuning, fill)
	var cursor: float = entry + run_in
	var start: float = cursor
	var record_walls: Array[Dictionary] = []
	var record_rooms: Array[Dictionary] = []
	for w: int in walls.size():
		var open: Array = (walls[w] as Array).duplicate()
		open.sort()
		record_walls.append({"start": cursor, "end": cursor + depth, "size": String(wall_size), "open": open})
		for lane: int in lanes:
			if not open.has(lane):
				_piece(out, tuning, "wall", w, lane, cursor, wall_size)
		cursor += depth
		if w < rooms.size():
			var dividers: Array = (rooms[w] as Array).duplicate()
			dividers.sort()
			record_rooms.append({"start": cursor, "end": cursor + room_length, "dividers": dividers})
			for lane: Variant in dividers:
				var at: float = cursor + TOUCH
				for size: StringName in fill:
					_piece(out, tuning, "divider", w, int(lane), at, size)
					at += tuning.doodad_size(size).z + TOUCH
			cursor += room_length
	var end: float = cursor
	var rec := {"entry": entry, "start": start, "end": end, "exit": end + breather, "walls": record_walls,
		"rooms": record_rooms, "breaks": 0}
	rec["breaks"] = DebrisMaze.min_breaks(rec, lanes)
	out.maze = [rec]
	out.length = float(options.get("length", end + breather + 200.0))
	return out


static func _piece(layout: LevelLayout, tuning: MovementTuning, part: String, index: int, lane: int, start: float,
		size: StringName) -> void:
	layout.doodads.append({"lane": lane, "start": start, "end": start + tuning.doodad_size(size).z, "size": size,
		"side": 1 if lane * 2 < layout.lane_count - 1 else -1, "seed": layout.doodads.size() + 1, "maze": 0, "part": part,
		"index": index})


## A centipede's layout entry waiting with its head at track distance `at` in `lane` (as centipede_rules.gd places one).
static func centipede(at: float, lane: int, situation: String = "near") -> Dictionary:
	return {"type": "centipede", "at": at, "lane": lane, "side": 0, "seed": 7, "params": {"block": 0,
		"situation": situation, "floor_span": Vector2(at - 2.0, at + Centipede.BODY_LENGTH + 1.0)}}
