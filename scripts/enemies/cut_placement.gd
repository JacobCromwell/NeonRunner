extends RefCounted
## Floor cuts that a rules script plans at a spot of its choosing (task B4; GDD §9.9): the stand-in's
## (floor_cutter_rules.gd) now, task C2's Buzz Overdrive's later. Like PadPlacement for pads, it makes
## room for a cut by taking out only what may go (taking content out never makes a level unfair), then
## adds it through the generator, which holds it to GDD §9.9's limits (LevelGenerator.cut_problem).
## (Not a `<feature>_rules.gd` script: LevelGenerator never runs it on its own.)

const GeneratorRules = preload("res://scripts/enemies/generator_rules.gd")


## A floor cut (FloorCutPlan.make) where it lies, if taking out what may go makes it fit: in its lane
## over its lane window (FloorCutPlan.lane_window), the holes, fences and speed pads; along its stretch
## in the other lanes, the holes beyond those whole_lanes_for_cut() lets stay (the lanes nearest the cut
## first, so its neighbours are whole). It never takes out a ramp, a pad, a ceiling, an enemy or another
## cut: where one of those is in the way, the cut doesn't fit. It tries the cut on a copy of the layout
## first, so one that doesn't fit changes nothing. A fence generator left with nothing to power goes
## (GeneratorRules). Returns true if the cut was added; the caller then adds its cause (an entry at the
## cut's end, in its lane).
static func place(gen: LevelGenerator, cut: Dictionary) -> bool:
	var trial: LevelLayout = gen.layout.copy()
	clear(gen, trial, cut)
	if gen.cut_problem(cut, trial) != "":
		return false
	if clear(gen, gen.layout, cut) > 0:
		GeneratorRules.keep_powered(gen)
	return gen.add_cut(cut)


## Takes out of `layout` what's in floor cut `cut`'s way and may go (see place()). Returns how many
## pieces went.
static func clear(gen: LevelGenerator, layout: LevelLayout, cut: Dictionary) -> int:
	var lane: int = int(cut["lane"])
	var span: Vector2 = FloorCutPlan.lane_window(cut)
	var start: float = float(cut["start"])
	var end: float = float(cut["end"])
	var half: float = gen.tuning.fence_depth * 0.5
	var before: int = layout.gaps.size() + layout.fences.size() + layout.speed_pads.size()
	_keep(layout.gaps, func(g: Dictionary) -> bool:
		return int(g["lane"]) != lane or float(g["start"]) > span.y or float(g["end"]) < span.x)
	_keep(layout.fences, func(f: Dictionary) -> bool:
		return int(f["lane"]) != lane or float(f["at"]) - half > span.y or float(f["at"]) + half < span.x)
	_keep(layout.speed_pads, func(p: Dictionary) -> bool:
		return int(p["lane"]) != lane or float(p["at"]) > span.y or float(p["at"]) + gen.tuning.speed_pad_length < span.x)
	# The other lanes holding holes along the stretch, nearest the cut first: clear them until no more
	# hold holes than may.
	var holed: Array[int] = []
	for g: Dictionary in layout.gaps:
		var other: int = int(g["lane"])
		if other != lane and float(g["start"]) <= end and float(g["end"]) >= start and not holed.has(other):
			holed.append(other)
	holed.sort_custom(func(a: int, b: int) -> bool:
		return absi(a - lane) < absi(b - lane) or (absi(a - lane) == absi(b - lane) and a < b))
	var allowed: int = layout.lane_count - 1 - gen.whole_lanes_for_cut(layout.lane_count)
	while holed.size() > allowed:
		var clear_lane: int = holed.pop_front()
		_keep(layout.gaps, func(g: Dictionary) -> bool:
			return int(g["lane"]) != clear_lane or float(g["start"]) > end or float(g["end"]) < start)
	return before - (layout.gaps.size() + layout.fences.size() + layout.speed_pads.size())


## Keeps the items of `list` for which `keep` returns true (in place, so typed arrays stay typed).
static func _keep(list: Array[Dictionary], keep: Callable) -> void:
	var out: Array[Dictionary] = []
	for item: Dictionary in list:
		if keep.call(item):
			out.append(item)
	list.assign(out)
