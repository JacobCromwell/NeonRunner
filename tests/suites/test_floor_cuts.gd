extends TestSuite
## Floors that turn into gaps during play (task B4; GDD §9.9, the Buzz Overdrive's cuts), from the
## layout to the screen. (Planning, GDD §9.9's limits and the sweeps: test_generator, _test_floor_cuts.)
## - The plan's geometry (FloorCutPlan, keyed to the player's distance) and the layout's data: no
##   "cuts" key without cuts, copies, joining, a boss arena's shifted laps.
## - The track (TrackBuilder, FloorCut): a cut built as a piece of its own where its stretch starts, the
##   lane's floor around it with no gap edges, its floor drawn in slices, whole until it begins; the
##   collision and the floor shown both ending exactly at the front as it advances, never coming back,
##   a stop, a hold, the end.
## - On real physics: a player in the lane falls through it exactly as through a normal gap; the floor
##   is removed exactly behind the stand-in cause; a player who leaves the lane after the warning is
##   never touched (3, 5 and 6 lanes, middle and edge lanes); one who stays is hit; a wall runner beside
##   it and a ceiling rider over it are safe; after the armor or the shield blocks the blade the floor
##   holds for GameRules.cut_hold_seconds (a switch saves the player, a jump lands back in the lane,
##   staying falls); killing the cause stops the cut where it dies (weapons, before the charge, the
##   dash).
## - The same at 30 and 60 Hz, under uneven steps and through a pause.
## - Runtime cuts: added in a boss arena (BossArena.cut_problem, add_pieces) and to a track that keeps
##   extending (TrackBuilder.extend_layout, endless mode).
## - Every skin's look (ZoneSkin.floor_cut; the Corporate trains and plaza, the Dead Zone, the Golden
##   Zone and the Golden Palace their own): parts registered, no collision added, a dark inside,
##   nothing glowing but the orange edges right on the collision edges, cheap to build.
## - The stand-in: its warning (a red line and a sound) only from its warning point, Reduced flashing,
##   and out of the campaign.

const Rules = preload("res://scripts/enemies/floor_cutter_rules.gd")
const CutterScript = preload("res://scripts/enemies/floor_cutter.gd")
const SKINS_DIR: String = "res://data/skins"
## The darkest a cut's inside may be drawn (linear luminance): far below any zone's floor.
const INSIDE_MAX_LUMINANCE: float = 0.012

var sim: RunSim
var rules: GameRules


## Records the floor hook's calls (and dresses nothing).
class RecordingSkin extends ZoneSkin:
	var floors: Array[Dictionary] = []
	var cuts: Array[FloorCutSection] = []

	func floor_segment(parent: Node3D, center: Vector3, size: Vector3, lane_x: float, edge_start: bool, edge_end: bool) -> void:
		floors.append({"parent": parent, "near": -(center.z + size.z * 0.5), "far": -(center.z - size.z * 0.5), "x": lane_x,
			"edge_start": edge_start, "edge_end": edge_end})

	func floor_cut(parent: Node3D, cut: FloorCutSection) -> void:
		cuts.append(cut)
		super.floor_cut(parent, cut)


func run() -> void:
	sim = RunSim.new(tree, tuning)
	rules = load("res://data/tuning/game_rules.tres") as GameRules
	_test_plan()
	_test_layout_data()
	await _test_track()
	await _test_fall_like_a_gap()
	await _test_removed_behind_cause()
	await _test_leave_in_time()
	await _test_staying_is_hit()
	await _test_wall_runner_and_rider()
	await _test_hold_after_block()
	await _test_kill_stops_cut()
	await _test_frame_rates()
	await _test_boss_runtime_cut()
	await _test_extending_track()
	await _test_skins()
	await _test_warning()
	_test_stand_in()


# --- Helpers -------------------------------------------------------------------------------------

## A cut in `lane` whose cause waits at `end`, with the stand-in's numbers at `t`'s run speed (the
## suite's by default), as the stand-in's rules plan one.
func _cut(lane: int, end: float, t: MovementTuning = null) -> Dictionary:
	var mt: MovementTuning = t if t != null else tuning
	var ct: FloorCutterTuning = Rules.tuning()
	var v: float = mt.run_speed
	var s: float = ct.charge_speed * mt.pace()
	var charge: float = ct.charge_seconds * (v + s)
	var warn: float = charge + ct.warn_seconds * v
	return FloorCutPlan.make(lane, end, warn, charge, s, v, ct.run_past, ct.keep())


## A layout of `lanes` lanes holding `cut` and, with `cutter`, its stand-in cause at its end.
func _layout(lanes: int, cut: Dictionary, cutter: bool = true, length: float = 500.0) -> LevelLayout:
	var layout := RunSim.layout(lanes, length)
	layout.cuts.append(cut)
	if cutter:
		layout.enemies.append(_cutter_entry(cut))
	return layout


func _cutter_entry(cut: Dictionary) -> Dictionary:
	return {"type": "floor_cutter", "at": float(cut["end"]), "lane": int(cut["lane"]), "side": 0, "seed": 7, "params": {}}


## A full world on `layout` with the player in `lane` at distance `from`.
func _world(layout: LevelLayout, lane: int, from: float, loadout: Loadout = null, t: MovementTuning = null) -> RunWorld:
	var mt: MovementTuning = t if t != null else tuning
	var world: RunWorld = sim.build_world(layout, loadout, mt)
	world.player.setup(mt, world.geo, lane)
	world.player.distance = from
	world.track.update(from, 0.0)
	return world


## True if a ray down at track distance `d` over lane `lane` meets floor.
func _floor_at(node: Node3D, geo: TrackGeometry, lane: int, d: float) -> bool:
	var q := PhysicsRayQueryParameters3D.create(Vector3(geo.lane_x(lane), 0.5, -d), Vector3(geo.lane_x(lane), -0.5, -d),
		TrackBuilder.LAYER_FLOOR)
	return not node.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## The floor cutter in play, or null.
func _cutter(world: RunWorld) -> Enemy:
	for e: Enemy in world.director.active:
		if is_instance_valid(e) and e.alive and e.type_id == &"floor_cutter":
			return e
	return null


## Steps the world until `done` holds or `seconds` pass. True if it held.
func _run_until(w: RunWorld, seconds: float, done: Callable) -> bool:
	if not w.player.running:
		await tree.physics_frame
		w.player.running = true
	for i: int in int(seconds * Engine.physics_ticks_per_second):
		if done.call():
			return true
		await tree.physics_frame
	return done.call()


## The furthest track distance any visible floor slice of `cut` reaches (its world extent, as shown).
func _shown_until(cut: FloorCut) -> float:
	var out: float = cut.start
	for s: Dictionary in cut.slices():
		var node: Node3D = s["node"]
		if not is_instance_valid(node) or not node.visible:
			continue
		# The slice is built over [from, to]; its transform scales it along the track.
		var z: float = node.transform.basis.z.z * TrackGeometry.world_z(float(s["to"])) + node.transform.origin.z
		out = maxf(out, -z)
	return out


## A track of `layout` with `skin`, in the tree, built around `d`.
func _track(layout: LevelLayout, skin: ZoneSkin, d: float = 0.0) -> TrackBuilder:
	var root := Node3D.new()
	tree.root.add_child(root)
	var track := TrackBuilder.new()
	root.add_child(track)
	track.set_layout(layout, tuning, skin)
	track.update(d, 0.0)
	return track


func _free_track(track: TrackBuilder) -> void:
	track.get_parent().queue_free()
	await tree.process_frame


# --- The plan and the layout ---------------------------------------------------------------------

func _test_plan() -> void:
	var v: float = 20.0
	var cut: Dictionary = FloorCutPlan.make(1, 300.0, 80.0, 50.0, 25.0, v, 20.0, 7.0)
	var r: float = 25.0 / 20.0
	var meet: float = FloorCutPlan.meet(cut, v)
	check(is_equal_approx(FloorCutPlan.warn_at(cut), 220.0) and is_equal_approx(FloorCutPlan.charge_at(cut), 250.0),
		"a cut's warning and charge points come before its end by its warn and charge")
	check(is_equal_approx(meet, (300.0 + r * 250.0) / (1.0 + r)) and is_equal_approx(float(cut["start"]), meet - 20.0),
		"it meets the player where its front reaches them, and runs on past them to its start (%.2f, %.2f)" % [meet, cut["start"]])
	check(is_equal_approx(FloorCutPlan.front_at(cut, 240.0, v), 300.0) and is_equal_approx(FloorCutPlan.front_at(cut, 250.0, v), 300.0),
		"its front stays at its end until the charge")
	check(absf(FloorCutPlan.front_at(cut, meet, v) - meet) < 0.0001, "keyed to the player's distance, it reaches the player at the meeting point")
	var done: float = FloorCutPlan.done_at(cut, v)
	check(is_equal_approx(FloorCutPlan.front_at(cut, done, v), float(cut["start"]))
		and is_equal_approx(FloorCutPlan.front_at(cut, done + 50.0, v), float(cut["start"])), "and stops at its start")
	var w: Vector2 = FloorCutPlan.window(cut, v)
	check(is_equal_approx(w.x, 220.0) and is_equal_approx(w.y, maxf(307.0, done)) and FloorCutPlan.lane_window(cut) == Vector2(220.0, 307.0),
		"its window runs from its warning to its end or past its cause's spot (%s)" % w)
	var prev: float = INF
	var monotonic: bool = true
	for i: int in 200:
		var f: float = FloorCutPlan.front_at(cut, 240.0 + i * 0.4, v)
		monotonic = monotonic and f <= prev
		prev = f
	check(monotonic, "its front only ever moves back toward the player")


func _test_layout_data() -> void:
	var l := RunSim.layout(3)
	check(not l.to_dict().has("cuts"), "a layout without floor cuts has no cuts list in its data: the same data as before")
	var cut: Dictionary = _cut(1, 200.0)
	l.cuts.append(cut)
	check((l.to_dict().get("cuts", []) as Array).size() == 1, "a layout's floor cuts are in its data")
	var c: LevelLayout = l.copy()
	c.cuts[0]["lane"] = 0
	check(int(l.cuts[0]["lane"]) == 1 and c.cuts.size() == 1, "a copy has its own cuts")
	check(l.cut_between(FloorCutPlan.warn_at(cut) + 1.0, FloorCutPlan.warn_at(cut) + 2.0, 1)
		and not l.cut_between(FloorCutPlan.warn_at(cut) + 1.0, FloorCutPlan.warn_at(cut) + 2.0, 0)
		and not l.cut_between(0.0, FloorCutPlan.warn_at(cut) - 1.0), "cut_between finds a cut's lane window by stretch and lane")
	var base := RunSim.layout(3, 100.0)
	base.append_pieces(l)
	check(base.cuts.size() == 1 and is_equal_approx(base.length, l.length), "joining a layout with cuts to one without any brings them along")
	var moved: LevelLayout = BossArena.shifted(l, 1000.0)
	var m: Dictionary = moved.cuts[0]
	check(is_equal_approx(float(m["start"]), float(cut["start"]) + 1000.0) and is_equal_approx(float(m["end"]), float(cut["end"]) + 1000.0)
		and is_equal_approx(FloorCutPlan.warn_at(m), FloorCutPlan.warn_at(cut) + 1000.0)
		and is_equal_approx(FloorCutPlan.meet(m, tuning.run_speed), FloorCutPlan.meet(cut, tuning.run_speed) + 1000.0),
		"a boss arena's shifted lap moves a cut whole: its warning, charge and meeting point with it")


# --- The track ------------------------------------------------------------------------------------

func _test_track() -> void:
	var cut: Dictionary = _cut(1, 150.0)
	var start: float = cut["start"]
	var end: float = cut["end"]
	var layout := _layout(3, cut, false)
	layout.gaps.append({"lane": 1, "start": end + 30.0, "end": end + 36.0})
	var skin := RecordingSkin.new()
	var track: TrackBuilder = _track(layout, skin)
	await physics_frames(2)
	var fc: FloorCut = track.floor_cut(1, end)
	check(fc != null and track.floor_cuts().size() == 1, "the cut is built as a piece of its own (a FloorCut)")
	if fc == null:
		await _free_track(track)
		return
	check(skin.cuts.size() == 1 and is_equal_approx(skin.cuts[0].start, start) and is_equal_approx(skin.cuts[0].end, end)
		and skin.cuts[0].lane == 1, "the skin draws the cut's hole from its section (ZoneSkin.floor_cut)")
	# The lane's floor: whole around the cut with no gap edges at its ends, drawn in slices over it.
	var lane_x: float = track.geo.lane_x(1)
	var at_start: bool = false
	var at_end: bool = false
	var edged: bool = false
	var gap_edges: int = 0
	for f: Dictionary in skin.floors:
		if absf(float(f["x"]) - lane_x) > 0.01:
			continue
		if absf(float(f["far"]) - start) < 0.001:
			at_start = true
			edged = edged or bool(f["edge_end"])
		if absf(float(f["near"]) - end) < 0.001:
			at_end = true
			edged = edged or bool(f["edge_start"])
		if absf(float(f["far"]) - (end + 30.0)) < 0.001 and bool(f["edge_end"]):
			gap_edges += 1
	check(at_start and at_end and not edged, "the lane's floor runs up to the cut and on from its end with no gap edge there")
	check(gap_edges == 1, "a normal hole in the lane still gets its edge")
	var covered: float = start
	var contiguous: bool = true
	var short: bool = true
	for s: Dictionary in fc.slices():
		contiguous = contiguous and absf(float(s["from"]) - covered) < 0.001
		short = short and float(s["to"]) - float(s["from"]) <= TrackBuilder.CUT_SLICE + 0.001
		covered = float(s["to"])
	check(contiguous and short and absf(covered - end) < 0.001 and not fc.slices().is_empty(),
		"its floor is drawn in slices of at most %.0f m covering its stretch exactly (%d slices)" % [TrackBuilder.CUT_SLICE, fc.slices().size()])
	var bodies: int = 0
	for node: Node in fc.find_children("*", "CollisionObject3D", true, false):
		bodies += 1
	check(bodies == 1, "the cut holds one collision body, the skin none (%d)" % bodies)
	# Whole until it begins.
	var whole: bool = true
	var d: float = start + 0.3
	while d < end - 0.3:
		whole = whole and _floor_at(track, track.geo, 1, d)
		d += 1.7
	check(whole and not fc.began(), "until it begins, the whole stretch is floor")
	var hidden: bool = true
	for node: Node3D in fc.section.spans + fc.section.fronts + fc.section.fars:
		hidden = hidden and not node.visible
	check(hidden and not fc.section.fronts.is_empty() and not fc.section.fars.is_empty() and not fc.section.statics.is_empty(),
		"the hole's edges are hidden until it begins")
	# It advances: the collision and the floor shown end exactly at its front.
	var mid: float = start + (end - start) * 0.43
	fc.advance_to(mid)
	check(is_equal_approx(fc.front, mid) and fc.began(), "advance_to moves its front")
	check(_floor_at(track, track.geo, 1, mid - 0.05) and not _floor_at(track, track.geo, 1, mid + 0.05)
		and _floor_at(track, track.geo, 1, start + 0.2) and not _floor_at(track, track.geo, 1, end - 0.2),
		"the floor ahead of its front is whole, behind it a hole, collision included, at once")
	check(absf(_shown_until(fc) - mid) < 0.001, "the floor shown ends exactly at its front (%.3f vs %.3f)" % [_shown_until(fc), mid])
	var shown: bool = true
	for node: Node3D in fc.section.spans + fc.section.fronts + fc.section.fars:
		shown = shown and node.visible
	var front_part: Node3D = fc.section.fronts[0]
	check(shown and absf(front_part.position.z - (end - mid)) < 0.001, "the hole's edges show, the front's lip moved to the front")
	fc.advance_to(mid + 10.0)
	check(is_equal_approx(fc.front, mid), "a cut never comes back")
	# A hold keeps whole slices, then lets go.
	fc.advance_to(start + 2.0)
	fc.hold(mid + 1.0, mid + 9.0, 5.0)
	check(fc.holding() and fc.hold_from <= mid + 1.0 and fc.hold_to >= mid + 9.0, "a hold covers what it's asked to")
	var held_slices: bool = true
	for s: Dictionary in fc.slices():
		if float(s["from"]) < fc.hold_to and float(s["to"]) > fc.hold_from:
			held_slices = held_slices and (s["node"] as Node3D).visible
		elif float(s["from"]) >= fc.front:
			held_slices = held_slices and not (s["node"] as Node3D).visible
	check(held_slices and _floor_at(track, track.geo, 1, fc.hold_from + 0.05) and _floor_at(track, track.geo, 1, fc.hold_to - 0.05)
		and not _floor_at(track, track.geo, 1, fc.hold_to + 0.1), "the held floor shows and holds exactly as far as its slices")
	fc.tick(4.99)
	check(fc.holding(), "the hold lasts until its time")
	fc.tick(5.0)
	check(not fc.holding() and not _floor_at(track, track.geo, 1, mid + 5.0), "then the floor goes, at once")
	var finished: Array[bool] = [false]
	fc.finished.connect(func(_c: FloorCut) -> void: finished[0] = true)
	fc.advance_to(start - 50.0)
	check(fc.done() and is_equal_approx(fc.front, start) and finished[0] and not _floor_at(track, track.geo, 1, start + 0.1),
		"at its start it's done: the whole stretch is a gap")
	await _free_track(track)
	# A stopped cut stays where it is.
	var track2: TrackBuilder = _track(_layout(3, _cut(1, 150.0), false), ZoneSkin.new())
	var fc2: FloorCut = track2.floor_cut(1, 150.0)
	fc2.advance_to(130.0)
	fc2.stop()
	fc2.advance_to(110.0)
	check(fc2.stopped and is_equal_approx(fc2.front, 130.0), "a stopped cut stays where it stopped")
	await _free_track(track2)


# --- On real physics -----------------------------------------------------------------------------

## GDD §4 and the brief: the player falls through a cut floor by the same physics as a normal gap.
func _test_fall_like_a_gap() -> void:
	var cut := {"lane": 1, "start": 100.0, "end": 200.0, "warn": 60.0, "charge": 40.0, "keep": 5.0, "speed": 18.0}
	var a: RunWorld = _world(_layout(3, cut, false), 1, 130.0)
	var fc: FloorCut = a.track.floor_cut(1, 200.0)
	var cut_trace: Array[Vector2] = []
	var cause: Array[String] = [""]
	a.player.died.connect(func(c: String) -> void: cause[0] = c)
	await _run_until(a, 0.2, func() -> bool: return false)
	fc.advance_to(100.0)
	await _run_until(a, 2.0, func() -> bool:
		cut_trace.append(Vector2(a.player.h, 1.0 if a.player.grounded else 0.0))
		return not a.player.alive)
	check(cause[0] == "fell", "a player standing on floor the cut takes falls, and the fall ends the run (%s)" % cause[0])
	await sim.free_world(a)
	var gap_layout := RunSim.layout(3, 500.0)
	gap_layout.gaps.append({"lane": 1, "start": 140.0, "end": 200.0})
	var b: RunWorld = _world(gap_layout, 1, 130.0)
	var gap_trace: Array[Vector2] = []
	await _run_until(b, 3.0, func() -> bool:
		gap_trace.append(Vector2(b.player.h, 1.0 if b.player.grounded else 0.0))
		return not b.player.alive)
	await sim.free_world(b)
	var i: int = 0
	while i < cut_trace.size() and cut_trace[i].y > 0.5:
		i += 1
	var j: int = 0
	while j < gap_trace.size() and gap_trace[j].y > 0.5:
		j += 1
	var same: bool = i < cut_trace.size() and j < gap_trace.size()
	var worst: float = 0.0
	for k: int in 30:
		if i + k >= cut_trace.size() or j + k >= gap_trace.size():
			break
		worst = maxf(worst, absf(cut_trace[i + k].x - gap_trace[j + k].x))
	check(same and worst < 0.0001, "the fall follows exactly the same heights frame by frame as off a normal gap's edge (worst %.6f m)" % worst)


## The floor is removed exactly behind the cause (the stand-in), frame by frame.
func _test_removed_behind_cause() -> void:
	for lanes: int in [3, 5, 6]:
		var lane: int = lanes / 2 if lanes != 6 else 5
		var cut: Dictionary = _cut(lane, 220.0)
		var w: RunWorld = _world(_layout(lanes, cut), 0 if lane > 0 else 1, FloorCutPlan.warn_at(cut) - 15.0)
		var samples: Array[int] = [0, 0]
		var ahead_ok: Array[bool] = [true]
		var behind_ok: Array[bool] = [true]
		var follows: Array[bool] = [true]
		var shown_ok: Array[bool] = [true]
		await _run_until(w, 8.0, func() -> bool:
			var e: Enemy = _cutter(w)
			var fc: FloorCut = w.track.floor_cut(lane, 220.0)
			if e == null or fc == null or not fc.began():
				return fc != null and fc.done()
			var front: float = e.get("front")
			samples[0] += 1
			follows[0] = follows[0] and absf(fc.front - front) < 0.0001 and absf(e.track_distance() - front) < 0.001
			if front - 0.06 > float(cut["start"]):
				ahead_ok[0] = ahead_ok[0] and _floor_at(w, w.geo, lane, front - 0.06)
			if front + 0.06 < float(cut["end"]):
				behind_ok[0] = behind_ok[0] and not _floor_at(w, w.geo, lane, front + 0.06)
				samples[1] += 1
			shown_ok[0] = shown_ok[0] and absf(_shown_until(fc) - front) < 0.001
			return fc.done())
		var tag: String = "(%d lanes, lane %d, %d frames sampled)" % [lanes, lane, samples[0]]
		check(samples[0] > 30 and samples[1] > 30, "the cut ran in front of the camera " + tag)
		check(follows[0], "the cut's front is where the cause is, every frame " + tag)
		check(ahead_ok[0] and behind_ok[0], "the floor ahead of the cause stays whole, behind it is a gap, collision included " + tag)
		check(shown_ok[0], "and the floor shown ends exactly there " + tag)
		var fc_end: FloorCut = w.track.floor_cut(lane, 220.0)
		check(fc_end != null and fc_end.done(), "the cut ran all the way to its start " + tag)
		await sim.free_world(w)


## GDD §9.9: "leave its lane before it arrives". A player in the cut's lane who switches out after the
## warning is never touched (no armor: a touch would end the run) and runs on alongside the gap.
func _test_leave_in_time() -> void:
	for setup: Array in [[3, 1], [3, 0], [5, 2], [5, 4], [6, 0], [6, 3]]:
		var lanes: int = setup[0]
		var lane: int = setup[1]
		var cut: Dictionary = _cut(lane, 240.0)
		var w: RunWorld = _world(_layout(lanes, cut), lane, FloorCutPlan.warn_at(cut) - 10.0, Loadout.new())
		var move: StringName = &"move_right" if lane < lanes - 1 else &"move_left"
		# Half a second into the warning (LevelConfig.cut_reaction_seconds, what the generator gives a player to react).
		var react: float = FloorCutPlan.warn_at(cut) + LevelConfig.new().cut_reaction_seconds * tuning.run_speed
		var r: Dictionary = await sim.step_world(w, (FloorCutPlan.window(cut, tuning.run_speed).y - w.player.distance) / tuning.run_speed + 1.0,
			[[react, move]])
		var fc: FloorCut = w.track.floor_cut(lane, 240.0)
		var tag: String = "(%d lanes, cut in lane %d)" % [lanes, lane]
		check(bool(r["alive"]) and r["cause"] == "", "a player who leaves the lane half a second into the warning is never touched %s" % tag)
		check(int(r["lane"]) == lane + (1 if move == &"move_right" else -1), "and runs on in the lane beside it %s" % tag)
		check(fc != null and fc.done(), "while the cut runs to its start beside them %s" % tag)
		check(not r["events"].has(&"armor_hit") and not r["events"].has(&"armor_break") and not r["events"].has(&"shield_break"),
			"nothing was blocked: no contact at all %s" % tag)
		await sim.free_world(w)


func _test_staying_is_hit() -> void:
	var cut: Dictionary = _cut(1, 240.0)
	var w: RunWorld = _world(_layout(3, cut), 1, FloorCutPlan.warn_at(cut) - 10.0, Loadout.new())
	var r: Dictionary = await sim.step_world(w, 8.0)
	check(not bool(r["alive"]) and r["cause"] == "floor cutter", "a player who stays in the lane is hit by the blade (%s)" % r["cause"])
	await sim.free_world(w)


## GDD §9.9: "It only threatens its own floor lane: wall runners and ceiling runners are safe, even
## beside it."
func _test_wall_runner_and_rider() -> void:
	# A wall runner on the wall beside a cut in the outer lane as the blade passes.
	var cut: Dictionary = _cut(0, 240.0)
	var w: RunWorld = _world(_layout(3, cut), 0, FloorCutPlan.warn_at(cut) - 10.0, Loadout.new())
	var meet: float = FloorCutPlan.meet(cut, tuning.run_speed)
	var on_wall: Array[bool] = [false]
	var passed: Array[bool] = [false]
	await sim.step_world(w, 0.05)
	await _run_until(w, 8.0, func() -> bool:
		if w.player.distance >= meet - 18.0 and w.player.surface == Player.Surface.FLOOR and not on_wall[0]:
			w.player.press(&"move_left")
			on_wall[0] = true
		var e: Enemy = _cutter(w)
		if e != null and e.track_distance() < w.player.distance - 3.0:
			passed[0] = passed[0] or w.player.surface == Player.Surface.WALL
		return passed[0] or not w.player.alive)
	check(passed[0] and w.player.alive, "a wall runner beside a cut in the outer lane is safe as its blade passes below")
	await sim.free_world(w)
	# A ceiling rider over the cut's lane as it runs beneath, landing past it.
	var cut2: Dictionary = _cut(1, 240.0)
	var layout := _layout(3, cut2)
	var pad_at: float = FloorCutPlan.warn_at(cut2) - 30.0
	layout.pads.append({"lane": 0, "at": pad_at})
	layout.hulls.append({"start": pad_at - 3.0, "end": FloorCutPlan.lane_window(cut2).y + 25.0})
	var w2: RunWorld = _world(layout, 0, pad_at - 20.0, Loadout.new())
	var r: Dictionary = await sim.step_world(w2, (float(layout.hulls[0]["end"]) + 30.0 - w2.player.distance) / tuning.run_speed,
		[[pad_at + 12.0, &"move_right"]], [FloorCutPlan.meet(cut2, tuning.run_speed)])
	var at_meet: Dictionary = r["at"].get(FloorCutPlan.meet(cut2, tuning.run_speed), {})
	check(String(at_meet.get("surface", "")) == "ceiling" and int(at_meet.get("lane", -1)) == 1,
		"a rider is on the ceiling over the cut's lane as the cut runs beneath (%s)" % at_meet)
	check(bool(r["alive"]) and String(r["surface"]) == "floor", "and is safe, landing past it")
	await sim.free_world(w2)


## GDD §9.9: "After a block, the floor under the player holds for about a second, just enough to switch
## lanes (a jump would land back in the cut lane)" (GameRules.cut_hold_seconds).
func _test_hold_after_block() -> void:
	var hold: float = rules.cut_hold_seconds
	var dt: float = 1.0 / Engine.physics_ticks_per_second
	for plan: String in ["stay", "switch", "jump", "shield"]:
		var cut: Dictionary = _cut(1, 240.0)
		var w: RunWorld = _world(_layout(3, cut), 1, FloorCutPlan.warn_at(cut) - 10.0, Loadout.new())
		if plan == "shield":
			w.player.shield = 1
		else:
			w.player.armor = 1
		var blocked: Array[float] = [-1.0]
		var fell: Array[float] = [-1.0]
		var landed: Array[bool] = [false]
		w.player.movement_event.connect(func(kind: StringName) -> void:
			if (kind == &"armor_break" or kind == &"armor_hit" or kind == &"shield_break") and blocked[0] < 0.0:
				blocked[0] = w.player.elapsed
				if plan == "jump":
					w.player.press(&"jump")
			elif kind == &"land" and blocked[0] >= 0.0:
				landed[0] = true)
		await _run_until(w, 10.0, func() -> bool:
			if blocked[0] >= 0.0 and plan == "switch" and w.player.elapsed >= blocked[0] + hold * 0.5 and w.player.lane == 1:
				w.player.press(&"move_left")
			if blocked[0] >= 0.0 and fell[0] < 0.0 and w.player.h < -0.05:
				fell[0] = w.player.elapsed
			return not w.player.alive or (blocked[0] >= 0.0 and w.player.elapsed > blocked[0] + hold + 1.5))
		var tag: String = "(%s)" % plan
		check(blocked[0] >= 0.0, "the %s blocks the blade %s" % ["shield" if plan == "shield" else "armor", tag])
		match plan:
			"stay", "shield":
				check(fell[0] >= blocked[0] + hold - dt and fell[0] <= blocked[0] + hold + 0.2,
					"the floor under the player holds for %.1f s, then they fall (%.3f s after the block) %s" % [hold,
					fell[0] - blocked[0], tag])
				check(not w.player.alive, "staying in the lane ends the run " + tag)
			"switch":
				check(w.player.alive and w.player.lane == 0 and fell[0] < 0.0, "switching lanes within the hold saves the player")
			"jump":
				check(landed[0] and fell[0] >= blocked[0] + hold - dt and not w.player.alive,
					"a jump lands back on the held floor in the cut's lane, which then goes (%.3f s)" % (fell[0] - blocked[0]))
		await sim.free_world(w)


## GDD §9.9: "Killing it before it charges saves the floor; killing it mid-charge stops the cut where
## it dies."
func _test_kill_stops_cut() -> void:
	var cut: Dictionary = _cut(1, 240.0)
	var mid: float = (float(cut["start"]) + float(cut["end"])) * 0.5
	var w: RunWorld = _world(_layout(3, cut), 0, FloorCutPlan.warn_at(cut) - 10.0, Loadout.new())
	var killed_at: Array[float] = [-1.0]
	await _run_until(w, 8.0, func() -> bool:
		var e: Enemy = _cutter(w)
		if e != null and float(e.get("front")) <= mid and killed_at[0] < 0.0:
			killed_at[0] = float(e.get("front"))
			e.take_damage(1000.0, &"weapon")
		return killed_at[0] >= 0.0)
	await sim.step_world(w, 1.5)
	var fc: FloorCut = w.track.floor_cut(1, 240.0)
	check(fc != null and fc.stopped and absf(fc.front - killed_at[0]) < 0.0001, "killed mid-charge, the cut stops where its cause died")
	if fc != null:
		check(_floor_at(w, w.geo, 1, fc.front - 0.06) and _floor_at(w, w.geo, 1, float(cut["start"]) + 0.5)
			and not _floor_at(w, w.geo, 1, fc.front + 0.06), "the floor beyond it stays whole; behind it the gap stays")
		check(absf(_shown_until(fc) - fc.front) < 0.001, "and the floor shown ends exactly there")
	await sim.free_world(w)
	# Killed during its warning: the cut never begins.
	var w2: RunWorld = _world(_layout(3, cut), 0, FloorCutPlan.warn_at(cut) - 10.0, Loadout.new())
	await _run_until(w2, 6.0, func() -> bool:
		var e: Enemy = _cutter(w2)
		if e != null and int(e.get("state")) == 1:
			e.defeat(&"weapon")
			return true
		return false)
	await sim.step_world(w2, 4.0)
	var fc2: FloorCut = w2.track.floor_cut(1, 240.0)
	check(fc2 != null and not fc2.began() and _floor_at(w2, w2.geo, 1, mid), "killed before it charges, the floor is saved")
	await sim.free_world(w2)
	# The dash smashes it (a risky panic move: the player dashes into the cut lane).
	var w3: RunWorld = _world(_layout(3, cut), 1, FloorCutPlan.warn_at(cut) - 10.0, Loadout.new())
	var dashed: Array[bool] = [false]
	var cause: Array[StringName] = [&""]
	w3.director.enemy_defeated.connect(func(_e: Enemy, c: StringName) -> void: cause[0] = c)
	await _run_until(w3, 8.0, func() -> bool:
		var e: Enemy = _cutter(w3)
		if e != null and not dashed[0] and float(e.get("front")) - w3.player.distance < 5.0:
			w3.player.start_dash(0.6, 0.0)
			dashed[0] = true
		return cause[0] != &"" or not w3.player.alive)
	var fc3: FloorCut = w3.track.floor_cut(1, 240.0)
	check(cause[0] == &"dash" and fc3 != null and fc3.stopped, "the dash smashes it, and the cut stops there (%s)" % cause[0])
	await sim.free_world(w3)


## A cut starts, runs and ends the same at every frame rate (keyed to the player's distance), under
## uneven steps, and through a pause.
func _test_frame_rates() -> void:
	var saved: int = Engine.physics_ticks_per_second
	var cut: Dictionary = _cut(1, 240.0)
	var done_at: Array[float] = []
	for hz: int in [30, 60]:
		Engine.physics_ticks_per_second = hz
		var w: RunWorld = _world(_layout(3, cut), 0, FloorCutPlan.warn_at(cut) - 10.0, Loadout.new())
		var worst: Array[float] = [0.0]
		var finished: Array[float] = [-1.0]
		var paused: Array[bool] = [false]
		await _run_until(w, 9.0, func() -> bool:
			var fc: FloorCut = w.track.floor_cut(1, 240.0)
			if fc == null:
				return false
			worst[0] = maxf(worst[0], absf(fc.front - FloorCutPlan.front_at(cut, w.player.distance, tuning.run_speed)))
			if fc.done() and finished[0] < 0.0:
				finished[0] = w.player.distance
			if not paused[0] and fc.began():
				paused[0] = true
				tree.paused = true
				await_pause()
			return finished[0] >= 0.0)
		tree.paused = false
		check(worst[0] < 0.0001, "at %d Hz the cut's front is where the plan says for the player's distance, every frame (worst %.6f m)" % [hz, worst[0]])
		check(finished[0] >= 0.0 and finished[0] - FloorCutPlan.done_at(cut, tuning.run_speed) < tuning.run_speed / hz + 0.001
			and finished[0] >= FloorCutPlan.done_at(cut, tuning.run_speed) - 0.001,
			"at %d Hz it ends where the plan says, within a frame's run (%.3f m)" % [hz, finished[0]])
		check(w.player.alive and w.player.lane == 0, "at %d Hz the player beside it runs on" % hz)
		done_at.append(finished[0])
		await sim.free_world(w)
	Engine.physics_ticks_per_second = saved
	check(done_at.size() == 2 and absf(done_at[0] - done_at[1]) <= tuning.run_speed / 30.0 + 0.001,
		"it ends at the same place at 30 and 60 Hz (%s)" % [done_at])
	# Uneven steps: the front follows the plan exactly, and a hold ends on the step that reaches it.
	var track: TrackBuilder = _track(_layout(3, cut, false), ZoneSkin.new(), 100.0)
	var fc: FloorCut = track.floor_cut(1, 240.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var p: float = FloorCutPlan.charge_at(cut) - 5.0
	var exact: bool = true
	var never_back: bool = true
	var prev: float = INF
	while p < FloorCutPlan.done_at(cut, tuning.run_speed) + 5.0:
		p += rng.randf_range(0.02, 2.5)
		fc.advance_to(FloorCutPlan.front_at(cut, p, tuning.run_speed))
		exact = exact and absf(fc.front - FloorCutPlan.front_at(cut, p, tuning.run_speed)) < 0.0001
		never_back = never_back and fc.front <= prev
		prev = fc.front
	check(exact and never_back, "with uneven steps the front is exactly where the plan says, and never comes back")
	await _free_track(track)
	var track2: TrackBuilder = _track(_layout(3, cut, false), ZoneSkin.new(), 100.0)
	var fc2: FloorCut = track2.floor_cut(1, 240.0)
	fc2.advance_to(float(cut["start"]) + 1.0)
	fc2.hold(200.0, 210.0, 3.0)
	var t: float = 2.0
	var ended: float = -1.0
	while ended < 0.0 and t < 10.0:
		t += rng.randf_range(0.004, 0.05)
		fc2.tick(t)
		if not fc2.holding():
			ended = t
	check(ended >= 3.0 and ended < 3.05, "with uneven steps a hold ends on the step that reaches its time (%.4f s)" % ended)
	await _free_track(track2)


## Holds the tree paused for a few frames (a stutter in the run), then lets it go on.
func await_pause() -> void:
	_resume_later()


func _resume_later() -> void:
	await tree.process_frame
	await tree.process_frame
	await tree.process_frame
	tree.paused = false


## Hostile Takeover (GDD §10): "the gunship ... drops a Buzz Overdrive onto the roof ahead, which cuts a
## carriage lane": a cut added during a boss fight (BossArena.add_pieces) past the built track, with its
## cause, held to GDD §9.9's limits first (BossArena.cut_problem).
func _test_boss_runtime_cut() -> void:
	var def: BossDef = DummyBoss.make_def([[1, 1, false, 0.2]])
	var enc := DummyBoss.new()
	var ctx := RunContext.new()
	ctx.mode = RunContext.Mode.QUICK
	ctx.boss = def
	ctx.config = BossArena.base_config(def)
	ctx.config.lane_count = 5
	ctx.tuning = tuning
	var arena: BossArena = enc.plan_arena(ctx)
	var world: RunWorld = sim.build_world(arena.layout, Loadout.new(), tuning, ctx.config)
	enc.setup(world, ctx, arena)
	world.player.setup(tuning, world.geo, 0)
	await sim.step_world(world, 0.3)
	var from: float = arena.stream_from()
	var near: Dictionary = _cut(1, from + 20.0)
	var far: Dictionary = _cut(1, from + 260.0)
	check(arena.cut_problem(far) == "", "a cut past the built track keeps GDD §9.9's limits on the arena (%s)" % arena.cut_problem(far))
	var refused := LevelLayout.new()
	refused.lane_count = 5
	refused.cuts.append(near)
	check(arena.add_pieces(refused) == 0 and world.layout.cuts.is_empty(), "a cut within the built track is left out")
	var extra := LevelLayout.new()
	extra.lane_count = 5
	extra.cuts.append(far)
	extra.enemies.append(_cutter_entry(far))
	check(arena.add_pieces(extra) == 2 and world.layout.cuts.size() == 1, "a cut and its cause join the arena's track")
	world.player.distance = FloorCutPlan.warn_at(far) - 30.0
	var began: Array[bool] = [false]
	var behind_ok: Array[bool] = [true]
	var ok: bool = await _run_until(world, 12.0, func() -> bool:
		var fc: FloorCut = world.track.floor_cut(1, float(far["end"]))
		if fc == null:
			return false
		if fc.began() and not fc.done():
			began[0] = true
			behind_ok[0] = behind_ok[0] and not _floor_at(world, world.geo, 1, minf(fc.front + 0.1, float(far["end"]) - 0.1)) \
				and _floor_at(world, world.geo, 1, maxf(fc.front - 0.1, float(far["start"]) + 0.1))
		return fc.done())
	check(ok and began[0] and behind_ok[0], "it's built and runs in the fight like a level's: floor ahead of its cause, a gap behind")
	check(world.player.alive, "the runner beside it is safe")
	await sim.free_world(world)


## Endless mode (R4) keeps extending the track: a cut can join it during the run like any piece
## (TrackBuilder.extend_layout), its cause brought in by whatever extends it.
func _test_extending_track() -> void:
	var w: RunWorld = _world(RunSim.layout(3, 300.0), 0, 0.0, Loadout.new())
	var from: float = w.track.built_until()
	var cut: Dictionary = _cut(2, from + 200.0)
	var extra := RunSim.layout(3, from + 400.0)
	extra.cuts.append(cut)
	w.track.extend_layout(extra)
	check(w.layout.cuts.size() == 1 and is_equal_approx(w.layout.length, from + 400.0), "a cut joins a track that's running")
	w.player.distance = FloorCutPlan.warn_at(cut) - 60.0
	w.director.spawn(_cutter_entry(cut))
	var ok: bool = await _run_until(w, 10.0, func() -> bool:
		var fc: FloorCut = w.track.floor_cut(2, float(cut["end"]))
		return fc != null and fc.done())
	check(ok and w.player.alive, "it's built as the runner nears it and runs to its end")
	await sim.free_world(w)


# --- Every skin's look ---------------------------------------------------------------------------

## ZoneSkin.floor_cut for every skin (the default, and the Corporate trains and plaza, the Dead Zone, the
## Golden Zone and the Golden Palace their own): it reads as a hole like any gap (CLAUDE.md readability rules): a dark
## inside, nothing glowing but the orange edges, those right on the collision edges, no collision, the
## same every build, and cheap.
func _test_skins() -> void:
	var skins: Dictionary = {"grey box": GreyboxSkin.new(), "base": ZoneSkin.new()}
	for file: String in DirAccess.get_files_at(SKINS_DIR):
		if file.ends_with("_skin.tres"):
			skins[file.trim_suffix("_skin.tres")] = load(SKINS_DIR.path_join(file)) as ZoneSkin
	check(skins.has("corporate") and skins.has("corporate_plaza") and skins.has("dead_zone") and skins.has("golden")
		and skins.has("golden_palace"), "the zones where the Buzz Overdrive appears are among the skins")
	for skin_name: String in skins:
		var skin: ZoneSkin = skins[skin_name]
		for lanes: int in [3, 5]:
			for lane: int in [0, lanes / 2]:
				await _check_look(skin, skin_name, lanes, lane)
		await _check_build_cost(skin, skin_name)


## Building the chunks a cut runs through stays within the chunk budgets (SkinSuite): its floor's slices
## and its look cost little more than the floor they stand in for. Five lanes, the cut in the middle,
## the first five chunks, warmed up, the fastest of three builds with and without the cut.
func _check_build_cost(skin: ZoneSkin, skin_name: String) -> void:
	var cut := {"lane": 2, "start": 80.0, "end": 140.0, "warn": 70.0, "charge": 40.0, "keep": 7.0, "speed": 18.0}
	var with_cut: LevelLayout = _layout(5, cut, false)
	var without := RunSim.layout(5, 500.0)
	var best: Array[float] = [INF, INF]
	for i: int in 4:
		for k: int in 2:
			var t0: int = Time.get_ticks_usec()
			var track: TrackBuilder = _track(with_cut if k == 0 else without, skin)
			var ms: float = (Time.get_ticks_usec() - t0) / 1000.0
			var chunks: int = track.get_child_count()
			await _free_track(track)
			# The first build makes the skin's shared templates: warm-up only.
			if i > 0:
				best[k] = minf(best[k], ms / maxf(chunks, 1))
	var extra: float = best[0] - best[1]
	print("  %s: chunks with a cut %.2f ms, without %.2f ms (+%.2f ms a chunk)" % [skin_name, best[0], best[1], extra])
	check(best[0] < SkinSuite.BUILD_BUDGET_MAX_MS and extra < SkinSuite.BUILD_BUDGET_MEAN_MS,
		"building chunks with a cut stays within the chunk budgets (%s: %.2f ms a chunk, +%.2f ms)" % [skin_name, best[0], extra])


func _check_look(skin: ZoneSkin, skin_name: String, lanes: int, lane: int) -> void:
	var tag: String = "(%s, %d lanes, lane %d)" % [skin_name, lanes, lane]
	var cut := {"lane": lane, "start": 80.0, "end": 140.0, "warn": 70.0, "charge": 40.0, "keep": 7.0, "speed": 18.0}
	var track: TrackBuilder = _track(_layout(lanes, cut, false), skin)
	var fc: FloorCut = track.floor_cut(lane, 140.0)
	if fc == null:
		check(false, "the cut is built " + tag)
		await _free_track(track)
		return
	var front: float = 107.0
	fc.advance_to(front)
	var section: FloorCutSection = fc.section
	var edge: Color = _edge_color(skin)
	var faults: PackedStringArray = []
	var dark: int = 0
	var lips: Dictionary = {"front": -INF, "far": INF, "left": -INF, "right": INF}
	var parts: Array[Node3D] = section.statics + section.spans + section.fronts + section.fars
	check(not section.statics.is_empty() and not section.fronts.is_empty() and not section.fars.is_empty()
		and (section.spans.size() > 0 or lanes == 1), "the look registers its inside, its edges, its front and its far side " + tag)
	for part: Node3D in parts:
		for node: Node in [part] + part.find_children("*", "", true, false):
			if node is CollisionObject3D or node is CollisionShape3D:
				faults.append("collision under the look")
			var m := node as MeshInstance3D
			if m == null or m.mesh == null:
				continue
			for s: int in m.mesh.get_surface_count():
				var arrays: Array = m.mesh.surface_get_arrays(s)
				var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
				var uv2s: Variant = arrays[Mesh.ARRAY_TEX_UV2]
				var additive: bool = uv2s is PackedVector2Array and m.mesh.surface_get_material(s) is ShaderMaterial \
					and ((m.mesh.surface_get_material(s) as ShaderMaterial).shader.resource_path.ends_with("kit_glow.gdshader"))
				for i: int in verts.size():
					var p: Vector3 = m.global_transform * verts[i]
					var c: Color = colors[i] if i < colors.size() else Color.WHITE
					var glowing: bool = additive or c.a > 0.001
					if glowing:
						if not _same_rgb(c, edge):
							faults.append("a glow in %s at %s" % [c, p])
							continue
						# The lips on the floor, right at the collision edges.
						if p.y > 0.0 and not additive:
							if part in section.fronts:
								lips["front"] = maxf(float(lips["front"]), -p.z)
							elif part in section.fars:
								lips["far"] = minf(float(lips["far"]), -p.z)
							elif part in section.spans:
								if p.x <= section.x0 + 0.001:
									lips["left"] = maxf(float(lips["left"]), p.x)
								if p.x >= section.x1 - 0.001:
									lips["right"] = minf(float(lips["right"]), p.x)
					elif part in section.statics:
						if p.y > 0.0001:
							faults.append("the inside reaches above the floor at %s" % p)
						if _luminance(c) > INSIDE_MAX_LUMINANCE:
							faults.append("an inside lit %s (%.4f) at %s" % [c, _luminance(c), p])
						dark += 1
					elif p.y < -0.0001 and _luminance(c) > INSIDE_MAX_LUMINANCE:
						faults.append("a lit face below the floor %s at %s" % [c, p])
	check(faults.is_empty(), "nothing in the look glows but the orange edges, nothing collides, and its inside is dark %s: %s" % [tag,
		", ".join(faults.slice(0, 4))])
	check(dark > 0, "the hole has a dark inside " + tag)
	check(absf(float(lips["front"]) - front) < 0.005, "the front's orange lip ends right at the collision edge (%.3f vs %.3f) %s" % [
		lips["front"], front, tag])
	check(absf(float(lips["far"]) - 140.0) < 0.005, "the far side's lip starts right at the collision edge (%.3f) %s" % [lips["far"], tag])
	if lane > 0:
		check(absf(float(lips["left"]) - section.x0) < 0.005, "the left lip ends right at the collision edge %s" % tag)
	if lane < lanes - 1:
		check(absf(float(lips["right"]) - section.x1) < 0.005, "the right lip starts right at the collision edge %s" % tag)
	check(absf(_shown_until(fc) - front) < 0.001, "the floor shown ends at the front " + tag)
	await _free_track(track)


## The orange a skin draws gap edges in (its gap_edge_color), or the default look's.
func _edge_color(skin: ZoneSkin) -> Color:
	var c: Variant = skin.get("gap_edge_color")
	return c if c is Color else ZoneSkin.CUT_EDGE_COLOR


static func _same_rgb(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.01 and absf(a.g - b.g) < 0.01 and absf(a.b - b.b) < 0.01


## Linear luminance of an sRGB vertex colour.
static func _luminance(c: Color) -> float:
	var l: Color = c.srgb_to_linear()
	return 0.2126 * l.r + 0.7152 * l.g + 0.0722 * l.b


# --- The stand-in ---------------------------------------------------------------------------------

## The stand-in's warning (a placeholder until C2's, CLAUDE.md readability rules: a visual and an audio
## warning): from its warning point, never before, and before its charge, a red line down the lane it's
## about to cut, from the cut's start to where its blade is, and a sound the library has (the hover
## truck's rev). The line pulses; with Reduced flashing it holds still.
func _test_warning() -> void:
	var library := load("res://data/audio/sfx_library.tres") as SfxLibrary
	check(library != null and library.stream(&"truck_rev") != null, "the stand-in's warning sound is in the library")
	var saved: bool = Settings.flashing_reduced
	for reduced: bool in [false, true]:
		Settings.flashing_reduced = reduced
		var tag: String = "(Reduced flashing %s)" % ("on" if reduced else "off")
		var cut: Dictionary = _cut(1, 300.0)
		var w: RunWorld = _world(_layout(3, cut), 0, FloorCutPlan.warn_at(cut) - 25.0)
		w.player.god_mode = true
		var warn_at: float = FloorCutPlan.warn_at(cut)
		# [shown early, shown in its warning, red, reaches from the start to the blade]
		var seen: Array[bool] = [false, false, true, true]
		var widths: Array[float] = []
		await _run_until(w, 8.0, func() -> bool:
			var e: Enemy = _cutter(w)
			if e == null:
				return false
			var line := e.find_child("WarningLine", false, false) as MeshInstance3D
			var p: float = w.player.distance
			var state: int = int(e.get("state"))
			if line == null:
				return false
			if line.visible and p < warn_at - 0.01:
				seen[0] = true
			if state == CutterScript.State.WARN and line.visible:
				seen[1] = true
				var m := line.material_override as StandardMaterial3D
				seen[2] = seen[2] and m != null and m.emission.r > 0.9 and m.emission.g < 0.3 and m.emission.b < 0.3
				var reach: float = line.global_transform.basis.z.length()
				seen[3] = seen[3] and absf(reach - (float(cut["end"]) - float(cut["start"]))) < 0.05
				# Past the line's first grow.
				if p > warn_at + 0.9 * w.tuning.run_speed:
					widths.append(line.global_transform.basis.x.length())
			return state == CutterScript.State.CHARGE)
		check(not seen[0] and seen[1], "the warning line shows from the warning point on, never before %s" % tag)
		check(seen[2] and seen[3], "it's red and runs down the lane from the cut's start to the blade %s" % tag)
		var spread: float = (widths.max() - widths.min()) if widths.size() > 10 else -1.0
		if reduced:
			check(spread >= 0.0 and spread < 0.0001, "with Reduced flashing the line holds still (%.4f) %s" % [spread, tag])
		else:
			check(spread > 0.02, "without it the line pulses (%.4f) %s" % [spread, tag])
		await sim.free_world(w)
	Settings.flashing_reduced = saved


func _test_stand_in() -> void:
	var campaign := load("res://data/campaign/campaign.tres") as Campaign
	var listed: PackedStringArray = []
	for zone: ZoneDef in campaign.zones:
		for level: LevelConfig in zone.levels:
			if level.has_feature("floor_cutter"):
				listed.append(String(level.id))
	check(listed.is_empty(), "no campaign level has the stand-in's cuts (%s)" % ", ".join(listed))
	check(not LevelConfig.PLANNED_FEATURES.has("floor_cutter"), "the stand-in is no planned feature of the campaign")
	check(LayoutChecks.known_feature("floor_cutter"), "the stand-in is a known feature (quick play: --features=floor_cutter)")
	var t := EnemyDirector.tuning_for("floor_cutter") as FloorCutterTuning
	check(t != null and not t.uses_floor and t.hitbox_size.x < tuning.lane_width * 0.4,
		"its tuning is data, its floor is its cut's, and its hitbox stays inside its lane")
