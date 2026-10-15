extends TestSuite
## The climb's core (GDD §10, Mecha Guppy and Captain Cogs: the runner climbs by anti-grav pads and ceilings
## onto higher and higher roofs, 20-30 m above the street, the camera following them up; task E5e-a), on real
## physics at 3, 5 and 6 lanes:
## - ceilings at any height: a pad flips the runner to the ceiling over it at that ceiling's own height (from
##   the street, and from a roof 9 m up to a ceiling at 15 m), they ride it there and drop at its end; a
##   ceiling at the standard height is taken at exactly that height; one that moves while ridden takes the
##   rider along, and they drop at its end as from any;
## - a ceiling that ends lane by lane (BossProps.ceiling_lanes) holds a lane switch within the lanes it still
##   covers, and each lane drops at its own end;
## - at its end the rider lands on a raised roof in a lane it covers, and falls past it in a lane it doesn't:
##   onto the street, or to their death where the street is eaten;
## - the floor base: a fall off a roof 20 m up dies as far below it, and as soon, as a fall into the street's
##   pits, and is in the pit (no lane switches) as far below it; without a floor base the same fall lands on
##   the street; a floor base above the runner never drops them;
## - falls faster than pit_depth a frame land where they cross a floor (an air slide's fast fall onto the
##   street or back onto a ceiling, a long drop), where they used to drop through it now and then;
## - the blob shadow lies on the roof under the runner only while the climb is on (RunWorld.camera_climbs);
##   otherwise at the street's level, as it always was;
## - the grapple hook's save, and a revive after a fall, go where the boss says (Player.grapple_save, wired
##   to BossEncounter._grapple_save): onto the higher roof, into its lane; unset, as they always were;
## - the climbing camera (RunWorld.camera_climbs) keeps the runner on screen all the way up a climb to 30 m,
##   never sits inside a roof, keeps under every ceiling and never snaps; without it the runner leaves the
##   screen up there;
## - boss props at a height land where they're asked to (fences, blocks, pads, ceilings over lane ranges and
##   lane by lane, roofs, floor warnings and warned() at a height).

const LANES: Array[int] = [3, 5, 6]

var sim: RunSim


func run() -> void:
	sim = RunSim.new(tree, tuning)
	await _test_high_ceilings()
	await _test_moving_ceiling()
	await _test_lane_by_lane()
	await _test_roof_drop()
	await _test_floor_base()
	await _test_fast_falls()
	await _test_shadow()
	await _test_grapple()
	await _test_boss_hook()
	await _test_camera()
	await _test_props_at_height()


# --- Helpers -------------------------------------------------------------------------------

## A bare run world over a plain street `length` long at `lanes` lanes (with `gaps` in it: {lane, start,
## end}), with a BossProps of its own, as a boss's (named "Props", _props).
func _world(lanes: int, gaps: Array[Dictionary] = [], length: float = 600.0) -> RunWorld:
	var layout := RunSim.layout(lanes, length)
	for g: Dictionary in gaps:
		layout.gaps.append(g)
	var world: RunWorld = sim.build_world(layout)
	var props := BossProps.new()
	props.name = "Props"
	world.add_child(props)
	props.setup(world)
	return world


static func _props(world: RunWorld) -> BossProps:
	return world.get_node(^"Props") as BossProps


## Gaps in every lane but those in `keep` from `start` to `end`: the street eaten away there.
static func _eaten(lanes: int, start: float, end: float, keep: Vector2i = Vector2i(-1, -1)) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for lane: int in lanes:
		if lane < keep.x or lane > keep.y:
			out.append({"lane": lane, "start": start, "end": end})
	return out


## Puts the runner in `lane`, standing on the floor `height` up (a roof under them), before the run starts.
func _place(world: RunWorld, lane: int, height: float = 0.0) -> void:
	world.player.setup(world.tuning, world.geo, lane)
	world.player.h = height
	world.player.floor_y = height
	await tree.physics_frame


## Every movement event of the world's runner from now on.
static func _events(world: RunWorld) -> Array[StringName]:
	var out: Array[StringName] = []
	world.player.movement_event.connect(func(kind: StringName) -> void: out.append(kind))
	return out


## Steps the world (started if it wasn't) until `condition` holds or `seconds` pass. True if it held.
func _until(world: RunWorld, condition: Callable, seconds: float) -> bool:
	if not world.player.running:
		world.start()
	for i: int in int(seconds * Engine.physics_ticks_per_second):
		if condition.call():
			return true
		await tree.physics_frame
	return condition.call()


## Steps the world (started if it wasn't) frame by frame for up to `seconds`, calling `each` after every
## frame, until `stop` holds (if given).
func _step(world: RunWorld, seconds: float, each: Callable, stop: Callable = Callable()) -> void:
	if not world.player.running:
		world.start()
	for i: int in int(seconds * Engine.physics_ticks_per_second):
		await tree.physics_frame
		each.call()
		if stop.is_valid() and stop.call():
			return


static func _on_floor(p: Player) -> bool:
	return p.surface == Player.Surface.FLOOR and p.grounded


static func _on_ceiling(p: Player) -> bool:
	return p.surface == Player.Surface.CEILING and p.grounded


# --- Ceilings at any height ----------------------------------------------------------------

## Ceilings at any height: from the street, a pad flips the runner to a ceiling 4 m above the standard
## height, they ride it there, and at its end drop at once and land on the street 10 m below; from a roof 9 m
## up, a pad flips them to a ceiling at 15 m (the standard height over the roof, taken exactly), and at its
## end they drop back onto the roof. A ceiling at the standard height is taken at exactly that height.
func _test_high_ceilings() -> void:
	for lanes: int in LANES:
		var tag: String = "lanes=%d" % lanes
		var mid: int = lanes / 2
		# From the street to a ceiling at 10 m.
		var world: RunWorld = _world(lanes)
		var p: Player = world.player
		_props(world).pad(mid, 40.0)
		_props(world).ceiling(37.0, 100.0, BossProps.ALL_LANES, 4.0)
		await tree.physics_frame
		var events: Array[StringName] = _events(world)
		var under: float = tuning.ceiling_height + 4.0
		var up: bool = await _until(world, func() -> bool: return _on_ceiling(p), 4.0)
		check(up and absf(p.ceiling_y - under) < 0.001 and absf(p.position.y - under) < 0.01,
			"a pad flips the runner to a ceiling at its own height, %.1f m (at %.3f m, ceiling_y %.3f) %s"
			% [under, p.position.y, p.ceiling_y, tag])
		var ride: Dictionary = {"off": 0.0, "dropped_at": -1.0, "drop_y": 0.0}
		var each := func() -> void:
			if _on_ceiling(p) and p.distance > 50.0:
				ride["off"] = maxf(float(ride["off"]), absf(p.position.y - under))
			if float(ride["dropped_at"]) < 0.0 and p.surface == Player.Surface.FLOOR:
				ride["dropped_at"] = p.distance
				ride["drop_y"] = p.position.y
		await _step(world, 6.0, each, func() -> bool: return p.distance > 105.0 and _on_floor(p))
		check(float(ride["off"]) < 0.01, "they ride it at its height (%.4f m off) %s" % [ride["off"], tag])
		check(events.has(&"hull_end") and absf(float(ride["dropped_at"]) - 100.0) < 1.0
			and absf(float(ride["drop_y"]) - under) < 0.3,
			"they drop at its end, from its height (at %.1f m, from %.2f m) %s" % [ride["dropped_at"], ride["drop_y"], tag])
		check(p.alive and _on_floor(p) and absf(p.h) < 0.01 and absf(p.floor_y) < 0.01,
			"and land on the street %.0f m below (h %.3f, %s) %s" % [under, p.h, p.last_event, tag])
		await sim.free_world(world)

		# From a roof 9 m up to a ceiling at 15 m, and back down onto the roof.
		world = _world(lanes)
		p = world.player
		var props: BossProps = _props(world)
		props.roof(BossProps.ALL_LANES, -20.0, 400.0, 9.0)
		await _place(world, mid, 9.0)
		p.floor_base = 9.0
		props.pad(mid, 40.0, 9.0)
		props.ceiling(37.0, 100.0, BossProps.ALL_LANES, 9.0)
		await tree.physics_frame
		up = await _until(world, func() -> bool: return _on_ceiling(p), 4.0)
		check(up and p.ceiling_y == 9.0 + tuning.ceiling_height and absf(p.position.y - 15.0) < 0.01,
			"from a roof 9 m up, a pad flips the runner to the ceiling at 15 m, taken at exactly its height (%.4f) %s"
			% [p.ceiling_y, tag])
		var back: bool = await _until(world, func() -> bool: return p.distance > 102.0 and _on_floor(p), 4.0)
		check(back and p.alive and absf(p.h - 9.0) < 0.01 and absf(p.floor_y - 9.0) < 0.01,
			"and at its end drops back onto the roof (h %.3f) %s" % [p.h, tag])
		await sim.free_world(world)

		# A ceiling at the standard height is taken at exactly that height.
		world = _world(lanes)
		p = world.player
		_props(world).pad(mid, 40.0)
		_props(world).ceiling(37.0, 100.0)
		await tree.physics_frame
		up = await _until(world, func() -> bool: return _on_ceiling(p) and p.distance > 50.0, 4.0)
		check(up and p.ceiling_y == tuning.ceiling_height, "a ceiling at the standard height is taken at exactly it %s" % tag)
		await sim.free_world(world)


## A ceiling that moves while it's ridden (one lowering in, a gunship's belly coming down) takes the rider
## along: from 9 m down to the standard height, where it's then taken exactly, and at its end they drop at
## once, from where it is (never rising toward where it was).
func _test_moving_ceiling() -> void:
	for lanes: int in LANES:
		var tag: String = "lanes=%d" % lanes
		var world: RunWorld = _world(lanes)
		var p: Player = world.player
		_props(world).pad(lanes / 2, 40.0)
		var ceiling: Node3D = _props(world).ceiling(37.0, 140.0, BossProps.ALL_LANES, 3.0)
		await tree.physics_frame
		var up: bool = await _until(world, func() -> bool: return _on_ceiling(p) and p.distance > 55.0, 4.0)
		check(up and absf(p.position.y - 9.0) < 0.01, "the runner rides the ceiling at 9 m %s" % tag)
		var state: Dictionary = {"t": 0.0, "off": 0.0, "drop_y": -1.0, "rose": 0.0}
		var each := func() -> void:
			# The rider against where the ceiling is (the physics sees a moved body a frame or two late).
			if _on_ceiling(p):
				state["off"] = maxf(float(state["off"]), absf(p.position.y - (9.0 + ceiling.position.y)))
			elif p.surface == Player.Surface.CEILING and float(state["drop_y"]) < 0.0:
				state["rose"] = maxf(float(state["rose"]), p.position.y - tuning.ceiling_height)
			if p.surface == Player.Surface.FLOOR and float(state["drop_y"]) < 0.0:
				state["drop_y"] = p.position.y
			# Lowered 3 m over a second, as a ceiling lowering in (0.05 m a frame).
			state["t"] = float(state["t"]) + 1.0 / Engine.physics_ticks_per_second
			ceiling.position.y = -3.0 * minf(float(state["t"]), 1.0)
		await _step(world, 6.0, each, func() -> bool: return p.distance > 145.0 and _on_floor(p))
		check(float(state["off"]) < 0.12, "it takes the rider down with it (at most %.3f m off it, two frames' fall) %s"
			% [state["off"], tag])
		check(p.ceiling_y == tuning.ceiling_height, "and at the standard height it's taken at exactly that (%.4f) %s" % [p.ceiling_y, tag])
		check(absf(float(state["drop_y"]) - tuning.ceiling_height) < 0.3 and float(state["rose"]) < 0.01,
			"at its end they drop at once from where it is (from %.2f m, rising %.3f m) %s" % [state["drop_y"], state["rose"], tag])
		check(p.alive and _on_floor(p), "and land %s" % tag)
		await sim.free_world(world)


# --- Ceilings that end lane by lane ----------------------------------------------------------

## A ceiling whose lanes end at different distances (GDD §10: the lanes that lead up run further), built as
## one section per run of lanes ending together: a lane switch is held within the lanes still covered where
## the rider is (the clank and a bump, as on any narrow ceiling), moves within them work, and each lane drops
## at its own end.
func _test_lane_by_lane() -> void:
	for lanes: int in LANES:
		var tag: String = "lanes=%d" % lanes
		var last: int = lanes - 1
		var ends := PackedFloat32Array()
		for lane: int in lanes:
			ends.append(130.0 if lane == last else 90.0)
		for lane: int in [last, 0]:
			var world: RunWorld = _world(lanes)
			var p: Player = world.player
			var sections: Array[Node3D] = _props(world).ceiling_lanes(37.0, ends, 3.0)
			_props(world).pad(lane, 40.0)
			await _place(world, lane)
			var drops: Array[float] = []
			p.movement_event.connect(func(kind: StringName) -> void:
				if kind == &"hull_end":
					drops.append(p.distance))
			if lane == last:
				check(sections.size() == 2, "one section for the lanes ending together, one for the lane that runs on (%d) %s"
					% [sections.size(), tag])
				var r: Dictionary = await sim.step_world(world, 9.0,
					[[60.0, &"move_left"], [75.0, &"move_right"], [100.0, &"move_left"]], [70.0, 85.0, 110.0, 128.0, 150.0])
				var at: Dictionary = r["at"]
				check(at[70.0]["surface"] == "ceiling" and int(at[70.0]["lane"]) == last - 1,
					"a move into a lane still covered works (%s) %s" % [at[70.0], tag])
				check(at[85.0]["surface"] == "ceiling" and int(at[85.0]["lane"]) == last, "and back (%s) %s" % [at[85.0], tag])
				check(at[110.0]["surface"] == "ceiling" and int(at[110.0]["lane"]) == last
					and (r["events"] as Array).count(&"ceiling_blocked") == 1,
					"past the other lanes' end, a move toward them is held, with the clank (%s, %s) %s" % [at[110.0], r["events"], tag])
				check(at[128.0]["surface"] == "ceiling" and at[150.0]["surface"] == "floor" and bool(at[150.0]["alive"]),
					"the lane that runs on is ridden to its own end and dropped from (%s) %s" % [at[150.0], tag])
				check(drops.size() == 1 and absf(drops[0] - 130.0) < 1.0, "it drops at its own lane's end (%s) %s" % [drops, tag])
			else:
				var r0: Dictionary = await sim.step_world(world, 7.0, [], [85.0, 100.0])
				check(r0["at"][85.0]["surface"] == "ceiling" and r0["at"][100.0]["surface"] == "floor" and drops.size() == 1
					and absf(drops[0] - 90.0) < 1.0, "a lane that ends sooner drops at its own end (%s) %s" % [drops, tag])
			await sim.free_world(world)


# --- The drop onto a roof, or past it --------------------------------------------------------

## At a ceiling's end over a higher roof (GDD §10: some lanes drop the runner onto the higher roof, the rest
## past it, back down to the floor they came from): in a lane the roof covers they land on it, in one it
## doesn't they fall past it onto the street, or to their death where the street is eaten.
func _test_roof_drop() -> void:
	for lanes: int in LANES:
		var lead := Vector2i(lanes - 1 if lanes == 3 else lanes - 2, lanes - 1)
		for case: int in 3:
			var lane: int = lead.y if case == 0 else 0
			var eaten: bool = case == 2
			var tag: String = "lanes=%d lane %d%s" % [lanes, lane, ", the street eaten" if eaten else ""]
			var gaps: Array[Dictionary] = []
			if eaten:
				gaps = _eaten(lanes, 95.0, 400.0, lead)
			var world: RunWorld = _world(lanes, gaps)
			var p: Player = world.player
			var props: BossProps = _props(world)
			props.ceiling(37.0, 100.0, BossProps.ALL_LANES, 4.0)
			# The roof's lanes reach back under the ceiling's end: a rider passes over its start.
			props.roof(lead, 94.0, 400.0, 6.5)
			props.pad(lane, 40.0)
			await _place(world, lane)
			var low: Dictionary = {"y": INF}
			var each := func() -> void:
				if p.distance > 100.0:
					low["y"] = minf(float(low["y"]), p.position.y)
			await _step(world, 7.0, each, func() -> bool: return not p.alive or (p.distance > 102.0 and _on_floor(p)))
			match case:
				0:
					check(p.alive and _on_floor(p) and absf(p.h - 6.5) < 0.01 and absf(p.floor_y - 6.5) < 0.01 and p.lane == lane,
						"in a lane the roof covers, the drop lands on it (h %.3f) %s" % [p.h, tag])
				1:
					check(p.alive and _on_floor(p) and absf(p.h) < 0.01 and float(low["y"]) < 0.5,
						"in a lane it doesn't, they fall past it onto the street (h %.3f) %s" % [p.h, tag])
				2:
					check(not p.alive and p.last_event == "died: fell" and float(low["y"]) < 0.0,
						"and where the street is eaten, to their death (%s) %s" % [p.last_event, tag])
			await sim.free_world(world)


# --- Falls counted from the floor fallen from ------------------------------------------------

## A run off the end of a floor `height` up (the street with a pit, or a roof over an eaten street, or over
## the whole street with `intact`) in `lane`, with the floor base at `base`: when they left it (frames), when
## they were in the pit (and at what height, and whether a lane switch then was refused) and when and where
## they died, or landed.
func _fall(lanes: int, lane: int, height: float, base: float, intact: bool = false) -> Dictionary:
	var gaps: Array[Dictionary] = []
	if height <= 0.0:
		gaps.append({"lane": lane, "start": 60.0, "end": 400.0})
	elif not intact:
		gaps = _eaten(lanes, 55.0, 400.0)
	var world: RunWorld = _world(lanes, gaps)
	var p: Player = world.player
	if height > 0.0:
		_props(world).roof(BossProps.ALL_LANES, -20.0, 60.0, height)
	await _place(world, lane, height)
	p.floor_base = base
	var out: Dictionary = {"left": -1, "pit": -1, "pit_h": 0.0, "died": -1, "death_h": 0.0, "lane_kept": true,
		"landed": false, "land_h": 0.0, "frame": 0}
	var each := func() -> void:
		var f: int = int(out["frame"])
		out["frame"] = f + 1
		if int(out["left"]) < 0 and p.distance > 55.0 and not p.grounded:
			out["left"] = f
		if int(out["pit"]) < 0 and p.in_pit:
			out["pit"] = f
			out["pit_h"] = p.h
			var before: int = p.lane
			p.press(&"move_left" if lane > 0 else &"move_right")
			out["lane_before"] = before
		elif int(out["pit"]) >= 0 and out.has("lane_before"):
			out["lane_kept"] = bool(out["lane_kept"]) and p.lane == int(out["lane_before"])
		if int(out["died"]) < 0 and not p.alive:
			out["died"] = f
			out["death_h"] = p.h
		if int(out["left"]) >= 0 and not bool(out["landed"]) and _on_floor(p):
			out["landed"] = true
			out["land_h"] = p.h
	await _step(world, 6.0, each, func() -> bool: return not p.alive or bool(out["landed"]))
	await sim.free_world(world)
	return out


## The floor base (GDD §10: falls counted from the floor fallen from): off a roof 20 m up with the floor base
## there, the runner is in the pit as far below it as below the street, dies as far below it, and as many
## frames after leaving it, as a runner falling into the street's pit; without the floor base the same fall
## lands on the street below. A floor base above the floor the runner stands on never drops them.
func _test_floor_base() -> void:
	var drop: float = tuning.gravity() * tuning.fall_gravity_multiplier * 1.2 / Engine.physics_ticks_per_second
	for lanes: int in LANES:
		var tag: String = "lanes=%d" % lanes
		var mid: int = lanes / 2
		var street: Dictionary = await _fall(lanes, mid, 0.0, 0.0)
		var high: Dictionary = await _fall(lanes, mid, 20.0, 20.0)
		check(int(street["died"]) > 0 and int(high["died"]) > 0, "both falls end in death %s" % tag)
		var street_frames: int = int(street["died"]) - int(street["left"])
		var high_frames: int = int(high["died"]) - int(high["left"])
		check(absi(street_frames - high_frames) <= 1,
			"a fall off a roof 20 m up ends as soon as one into the street's pit (%d frames, %d from the street) %s"
			% [high_frames, street_frames, tag])
		var depth: float = 20.0 - float(high["death_h"])
		var street_depth: float = -float(street["death_h"])
		check(depth >= tuning.fall_death_depth and depth < tuning.fall_death_depth + drop and absf(depth - street_depth) < drop,
			"as far below the floor fallen from (%.2f m; %.2f m from the street) %s" % [depth, street_depth, tag])
		var pit_depth: float = 20.0 - float(high["pit_h"])
		check(pit_depth >= tuning.pit_depth and pit_depth < tuning.pit_depth + drop and bool(high["lane_kept"])
			and bool(street["lane_kept"]), "and in the pit as far below it, where a lane switch is refused (%.2f m) %s"
			% [pit_depth, tag])
		# Without the floor base, the same fall is counted from the street, and lands on it.
		var counted: Dictionary = await _fall(lanes, mid, 20.0, 0.0, true)
		check(bool(counted["landed"]) and int(counted["died"]) < 0 and absf(float(counted["land_h"])) < 0.01,
			"without a floor base, the fall off the roof lands on the street 20 m below (%.3f) %s" % [counted["land_h"], tag])
		# A floor base above the runner (raised ahead of the climb) counts from the floor they stand on.
		var pit: Array[Dictionary] = [{"lane": mid, "start": 80.0, "end": 400.0}]
		var world: RunWorld = _world(lanes, pit)
		var p: Player = world.player
		p.floor_base = 20.0
		var r: Dictionary = await sim.step_world(world, 5.0, [[30.0, &"jump"]], [60.0])
		check(bool(r["at"][60.0]["alive"]) and r["at"][60.0]["surface"] == "floor",
			"a floor base above the runner never drops them: a jump lands as ever (%s) %s" % [r["at"][60.0], tag])
		check(not r["alive"] and r["cause"] == "fell" and p.h < -tuning.fall_death_depth + 0.01
			and p.h > -tuning.fall_death_depth - drop, "and a pit in the street still ends a fall 4 m down (%.2f) %s" % [p.h, tag])
		await sim.free_world(world)


# --- Fast falls land ------------------------------------------------------------------------

## A fall faster than pit_depth a frame lands where it crosses a floor (Player._crossed_top): an air slide's
## fast fall, pressed 1 to 40 frames into a jump, onto the street and back onto a ceiling by a rider who
## jumped off it (on the unchanged code, 437d46e, the slide dropped through the street at 4 of those 40
## timings, 3, 11, 30 and 34 frames, and at the same 4 threw the ceiling rider off it mid-ceiling with an
## early hull_end); and drops of 15 m onto the street at many frame phases.
func _test_fast_falls() -> void:
	for lanes: int in LANES:
		var tag: String = "lanes=%d" % lanes
		var world: RunWorld = _world(lanes, [], 2400.0)
		var p: Player = world.player
		world.start()
		await physics_frames(10)
		var landed: int = 0
		var trials: int = 0
		for wait: int in range(1, 41):
			p.press(&"jump")
			await physics_frames(wait)
			p.press(&"slide")
			await _until(world, func() -> bool: return _on_floor(p) or not p.alive, 2.0)
			trials += 1
			if p.alive and absf(p.h) < 0.01:
				landed += 1
			if not p.alive:
				break
			await physics_frames(10)
		check(landed == trials and trials == 40, "an air slide's fast fall lands on the street at any moment of a jump (%d of %d) %s"
			% [landed, trials, tag])
		# On a ceiling: a rider jumps off it and slides back up onto it, never through it.
		var high: RunWorld = _world(lanes, [], 1500.0)
		var rider: Player = high.player
		_props(high).pad(lanes / 2, 40.0)
		_props(high).ceiling(37.0, 1400.0)
		await tree.physics_frame
		var ends: Array[StringName] = _events(high)
		await _until(high, func() -> bool: return _on_ceiling(rider), 4.0)
		var back: int = 0
		var tries: int = 0
		for wait: int in range(1, 41):
			rider.press(&"jump")
			await physics_frames(wait)
			rider.press(&"slide")
			await _until(high, func() -> bool: return _on_ceiling(rider) or rider.surface == Player.Surface.FLOOR, 2.0)
			tries += 1
			if _on_ceiling(rider) and not ends.has(&"hull_end"):
				back += 1
			else:
				break
			await physics_frames(10)
		check(back == tries and tries == 40 and rider.alive,
			"a ceiling rider's slide back up lands on the ceiling at any moment of a jump, never thrown off it (%d of %d, %s) %s"
			% [back, tries, ends.count(&"hull_end"), tag])
		await sim.free_world(high)
		landed = 0
		trials = 0
		if p.alive:
			for i: int in 16:
				p.h = 15.0 + i * 0.0217
				p.grounded = false
				p.vh = 0.0
				await _until(world, func() -> bool: return _on_floor(p) or not p.alive, 3.0)
				trials += 1
				if p.alive and absf(p.h) < 0.01:
					landed += 1
				if not p.alive:
					break
				await physics_frames(5)
		check(landed == trials and trials == 16, "a 15 m drop lands on the street at every frame phase (%d of %d) %s"
			% [landed, trials, tag])
		await sim.free_world(world)


# --- The blob shadow -----------------------------------------------------------------------

## The blob shadow (Player._update_shadow) lies on the roof under the runner only while the climb is on
## (RunWorld.camera_climbs, through Player.shadow_on_floor); otherwise it's drawn at the street's level under
## them, as it always was (on a hover truck's roof or a boss's deck in every level).
func _test_shadow() -> void:
	for lanes: int in LANES:
		var tag: String = "lanes=%d" % lanes
		var world: RunWorld = _world(lanes)
		var p: Player = world.player
		_props(world).roof(BossProps.ALL_LANES, -20.0, 300.0, 9.0)
		await _place(world, lanes / 2, 9.0)
		var shadow := p.get(&"_shadow") as MeshInstance3D
		await _until(world, func() -> bool: return p.distance > 20.0, 2.0)
		check(not p.shadow_on_floor and shadow.visible and absf(shadow.global_position.y - 0.02) < 0.001,
			"off the climb, the shadow is drawn at the street's level, as ever (%.3f m) %s" % [shadow.global_position.y, tag])
		world.camera_climbs = true
		await physics_frames(2)
		check(p.shadow_on_floor and shadow.visible and absf(shadow.global_position.y - 9.02) < 0.001,
			"with the climb on, on the roof under the runner (%.3f m) %s" % [shadow.global_position.y, tag])
		await sim.free_world(world)


# --- The grapple hook ----------------------------------------------------------------------

## The grapple's save goes where the boss says (Player.grapple_save): off a roof 4 m up over an eaten street,
## the hook pulls the runner up onto the higher roof 7 m up, into its lane (the far one), where they land;
## a revive after the fall goes there too. Unset, the save is as it always was: straight up out of the
## street's pit, landing beyond it, in their lane.
func _test_grapple() -> void:
	for lanes: int in LANES:
		var tag: String = "lanes=%d" % lanes
		var mid: int = lanes / 2
		var last: int = lanes - 1
		# Unset: as ever.
		var pit: Array[Dictionary] = [{"lane": mid, "start": 40.0, "end": 47.0}]
		var plain: RunWorld = _world(lanes, pit)
		plain.player.grapples = 1
		var events: Array[StringName] = _events(plain)
		var r: Dictionary = await sim.step_world(plain, 4.0, [], [70.0])
		check(events.has(&"grapple") and plain.player.grapples == 0 and bool(r["at"][70.0]["alive"])
			and r["at"][70.0]["surface"] == "floor" and int(r["at"][70.0]["lane"]) == mid and absf(float(r["at"][70.0]["h"])) < 0.01,
			"without a hook, the grapple pulls the runner straight up out of the pit, as ever (%s) %s" % [r["at"][70.0], tag])
		await sim.free_world(plain)
		for revive: bool in [false, true]:
			var world: RunWorld = _world(lanes, _eaten(lanes, 48.0, 400.0))
			var p: Player = world.player
			var props: BossProps = _props(world)
			props.roof(BossProps.ALL_LANES, -20.0, 50.0, 4.0)
			props.roof(Vector2i(last, last), 40.0, 400.0, 7.0)
			await _place(world, 0, 4.0)
			p.floor_base = 4.0
			p.grapples = 0 if revive else 1
			var asked: Array[StringName] = []
			p.grapple_save = func(_who: Player, cause: StringName) -> Dictionary:
				asked.append(cause)
				return {"lane": last, "height": 7.0}
			var mode: String = "a revive after the fall" if revive else "the grapple's save"
			if revive:
				var died: bool = await _until(world, func() -> bool: return not p.alive, 4.0)
				check(died and p.last_event == "died: fell", "with no grapple, the fall off the roof kills %s" % tag)
				p.revive()
			var on_roof: bool = await _until(world, func() -> bool: return not p.alive or (p.distance > 52.0 and _on_floor(p)), 4.0)
			check(on_roof and p.alive and p.lane == last and absf(p.h - 7.0) < 0.01 and absf(p.floor_y - 7.0) < 0.01,
				"%s pulls the runner up onto the higher roof, into its lane (lane %d, h %.3f) %s" % [mode, p.lane, p.h, tag])
			check(asked.size() == 1 and asked[0] == (&"revive" if revive else &"grapple"),
				"the hook is asked once, with the cause (%s) %s" % [asked, tag])
			check(revive or p.grapples == 0, "and the grapple is used up %s" % tag)
			await sim.free_world(world)


## A boss decides where the save goes with its hook (BossEncounter._grapple_save, wired to the player as the
## fight begins); the framework's own says nothing, so the save is as it always was.
func _test_boss_hook() -> void:
	var def: BossDef = DummyBoss.make_def([[1, 1, false, 0.1]])
	for saving: bool in [false, true]:
		var enc: DummyBoss = SavingBoss.new() if saving else DummyBoss.new()
		var world: RunWorld = _fight(enc, def, 5)
		var p: Player = world.player
		check(p.grapple_save.is_valid() and p.grapple_save.get_method() == &"_grapple_save",
			"the fight wires its hook to the player (saving %s)" % saving)
		var answer: Dictionary = p.grapple_save.call(p, &"grapple")
		if not saving:
			check(answer.is_empty(), "the framework's own hook leaves the save as it is")
			await sim.free_world(world)
			continue
		check(answer == {"lane": 0, "height": 3.0}, "a boss's own hook answers for it (%s)" % answer)
		(enc as SavingBoss).asked.clear()
		await _until(world, func() -> bool: return p.distance > 20.0, 2.0)
		# Below the street, falling: the grapple fires, and the boss's hook takes the runner up into lane 0.
		p.grapples = 1
		p.h = -0.5
		p.vh = -2.0
		p.grounded = false
		var peak: Dictionary = {"h": -INF}
		await _step(world, 3.0, func() -> void: peak["h"] = maxf(float(peak["h"]), p.h),
			func() -> bool: return not p.alive or (_on_floor(p) and float(peak["h"]) > 0.0))
		var asked: Array[StringName] = (enc as SavingBoss).asked
		check(asked.size() == 1 and asked[0] == &"grapple" and p.alive and p.lane == 0 and float(peak["h"]) > 3.0,
			"the boss's hook moves the save: up toward its floor 3 m up, into its lane (lane %d, up to %.2f m, %s)"
			% [p.lane, peak["h"], asked])
		await sim.free_world(world)


## A boss whose hook sends the grapple's save to lane 0, onto a floor 3 m up.
class SavingBoss extends DummyBoss:
	var asked: Array[StringName] = []

	func _grapple_save(_player: Player, cause: StringName) -> Dictionary:
		asked.append(cause)
		return {"lane": 0, "height": 3.0}


## A fight in a bare RunWorld (no App, no LevelRun), as test_bosses builds one.
func _fight(enc: BossEncounter, def: BossDef, lanes: int) -> RunWorld:
	var ctx := RunContext.new()
	ctx.mode = RunContext.Mode.QUICK
	ctx.boss = def
	ctx.config = BossArena.base_config(def)
	ctx.config.lane_count = lanes
	ctx.tuning = tuning
	var arena: BossArena = enc.plan_arena(ctx)
	var world: RunWorld = sim.build_world(arena.layout, null, ctx.tuning, ctx.config)
	enc.setup(world, ctx, arena)
	return world


# --- The climbing camera -------------------------------------------------------------------

## A climb of five steps from the street to a roof 30 m up, in the outer lane (0): from each floor a pad
## lifts the runner to a ceiling 9 m above it over every lane, and at its end they drop 3 m onto the next
## roof, over the two outer lanes (the lanes that lead up), which reaches back under the ceiling (GDD §10's
## climb). Returns the ceilings and roofs as AABBs ({"ceilings": [...], "roofs": [...]}).
func _build_climb(world: RunWorld) -> Dictionary:
	var props: BossProps = _props(world)
	var half: float = world.geo.half_width()
	var lead := Vector2i(0, 1)
	var x0: float = world.geo.lane_floor_span(lead.x).x
	var x1: float = world.geo.lane_floor_span(lead.y).y
	var ceilings: Array[AABB] = []
	var roofs: Array[AABB] = []
	for k: int in 5:
		var floor_h: float = 6.0 * k
		var pad_at: float = 40.0 + 80.0 * k
		var end: float = pad_at + 40.0
		props.pad(0, pad_at, floor_h)
		props.ceiling(pad_at - 3.0, end, BossProps.ALL_LANES, floor_h + 3.0)
		var under: float = floor_h + 3.0 + tuning.ceiling_height
		ceilings.append(AABB(Vector3(-half, under, -end), Vector3(half * 2.0, TrackBuilder.HULL_THICKNESS, end - pad_at + 3.0)))
		var top: float = floor_h + 6.0
		var roof_end: float = end + (90.0 if k < 4 else 200.0)
		props.roof(lead, end - 8.0, roof_end, top)
		roofs.append(AABB(Vector3(x0, 0.0, -roof_end), Vector3(x1 - x0, top, roof_end - end + 8.0)))
	return {"ceilings": ceilings, "roofs": roofs}


## Runs the climb with the camera climbing or not, checking each frame (after the camera's own update)
## that the runner is on screen, the camera is in no roof and keeps camera_floor_clearance above one it's
## over, keeps camera_ceiling_clearance under a ceiling over or beside it, and how far it moved up or down.
func _climb_camera(lanes: int, climbing: bool) -> Dictionary:
	var world: RunWorld = _world(lanes, [], 800.0)
	var p: Player = world.player
	var pieces: Dictionary = _build_climb(world)
	await _place(world, 0)
	world.camera_climbs = climbing
	world.effects.shake_scale = 0.0
	var camera := RunCamera.new()
	tree.root.add_child(camera)
	camera.follow(world)
	await tree.physics_frame
	world.start()
	var rect := Rect2(Vector2.ZERO, camera.get_viewport().get_visible_rect().size)
	var out: Dictionary = {"off_screen": 0, "off_high": 0, "in_roof": 0, "near_roof": INF, "under": -INF, "step": 0.0,
		"high_frames": 0, "top": -INF, "worst_note": ""}
	var last_y: float = NAN
	for i: int in int(28.0 * Engine.physics_ticks_per_second):
		await tree.physics_frame
		await tree.process_frame
		if not p.alive:
			break
		var cam: Vector3 = camera.global_position
		var head: Vector3 = p.position + Vector3(0.0, -tuning.visual_size.y if p.surface == Player.Surface.CEILING else tuning.visual_size.y, 0.0)
		var seen: bool = true
		for point: Vector3 in [p.position, head]:
			if camera.is_position_behind(point) or not rect.has_point(camera.unproject_position(point)):
				seen = false
		out["top"] = maxf(float(out["top"]), p.position.y)
		if not seen:
			out["off_screen"] = int(out["off_screen"]) + 1
			if p.position.y >= 25.0:
				out["off_high"] = int(out["off_high"]) + 1
		elif p.position.y >= 25.0 and p.position.y <= 30.5:
			out["high_frames"] = int(out["high_frames"]) + 1
		for box: AABB in pieces["roofs"]:
			if box.has_point(cam):
				out["in_roof"] = int(out["in_roof"]) + 1
				out["worst_note"] = "in a roof at %s (cam %s)" % [box, cam]
			elif cam.x > box.position.x and cam.x < box.end.x and cam.z > box.position.z and cam.z < box.end.z:
				out["near_roof"] = minf(float(out["near_roof"]), cam.y - box.end.y - tuning.camera_floor_clearance)
		for box: AABB in pieces["ceilings"]:
			var beside: bool = cam.x > box.position.x - RunCamera.CEILING_SIDE and cam.x < box.end.x + RunCamera.CEILING_SIDE
			if beside and cam.z > box.position.z and cam.z < box.end.z:
				out["under"] = maxf(float(out["under"]), cam.y - (box.position.y - tuning.camera_ceiling_clearance))
		if not is_nan(last_y):
			out["step"] = maxf(float(out["step"]), absf(cam.y - last_y))
		last_y = cam.y
		if p.distance > 470.0:
			break
	out["alive"] = p.alive
	out["distance"] = p.distance
	out["floor_y"] = p.floor_y
	camera.queue_free()
	await sim.free_world(world)
	return out


## The climbing camera (RunWorld.camera_climbs) up a climb to 30 m: the runner stays on screen all the way
## (and at 25-30 m), the camera never sits inside a roof (and keeps its clearance over one), keeps under
## every ceiling as ever, and moves smoothly (no snap on a ride up or a landing on a higher roof). Without
## the climbing view, the runner leaves the top of the screen up there.
func _test_camera() -> void:
	for lanes: int in LANES:
		var tag: String = "lanes=%d" % lanes
		var r: Dictionary = await _climb_camera(lanes, true)
		check(bool(r["alive"]) and float(r["distance"]) > 470.0 and absf(float(r["floor_y"]) - 30.0) < 0.01,
			"the runner climbs onto the roof 30 m up (on %.2f m, up to %.1f m, at %.0f m) %s"
			% [r["floor_y"], r["top"], r["distance"], tag])
		check(int(r["off_screen"]) == 0 and int(r["high_frames"]) > 60,
			"the climbing camera keeps the runner on screen all the way up (%d frames off; %d frames on screen at 25-30 m) %s"
			% [r["off_screen"], r["high_frames"], tag])
		check(int(r["in_roof"]) == 0 and float(r["near_roof"]) > -0.01,
			"it never sits inside a roof and keeps its clearance over one (%d frames in; %.3f m short; %s) %s"
			% [r["in_roof"], r["near_roof"], r["worst_note"], tag])
		check(float(r["under"]) <= 0.001, "it keeps camera_ceiling_clearance under every ceiling (%.3f m over) %s" % [r["under"], tag])
		check(float(r["step"]) < 0.4, "and never snaps: at most %.3f m up or down in a frame %s" % [r["step"], tag])
	var plain: Dictionary = await _climb_camera(5, false)
	check(int(plain["off_high"]) > 0, "without the climbing view, the runner leaves the screen 25-30 m up (%d frames)" % plain["off_high"])


# --- Boss props at a height ----------------------------------------------------------------

## Boss props at a height (BossProps' `height`: a raised floor's top) land where they're asked, and without
## one where they always did: fences and blocks on the floor, pads, ceilings ceiling_height above the floor
## over a range of lanes and lane by lane, roofs over their lanes, red warnings on the floor, warned() at a
## height counting only the warnings on that floor.
func _test_props_at_height() -> void:
	var t: MovementTuning = tuning
	for lanes: int in LANES:
		var tag: String = "lanes=%d" % lanes
		var world: RunWorld = _world(lanes)
		var props: BossProps = _props(world)
		var geo: TrackGeometry = world.geo
		var full_mid: float = t.fence_full_top * 0.5
		var gapped_mid: float = (t.fence_gapped_bottom + t.fence_gapped_top) * 0.5
		var fence: Hazard = props.fence(1, 50.0, "full", 0.0, 9.0)
		var gapped: Hazard = props.fence(1, 52.0, "gapped", 0.0, 9.0)
		var low_fence: Hazard = props.fence(1, 54.0)
		check(absf(fence.position.y - (9.0 + full_mid)) < 0.0001 and absf(gapped.position.y - (9.0 + gapped_mid)) < 0.0001
			and absf(low_fence.position.y - full_mid) < 0.0001 and absf(fence.position.x - geo.lane_x(1)) < 0.0001,
			"fences stand on the floor they're given (%.3f, %.3f; on the street %.3f) %s"
			% [fence.position.y, gapped.position.y, low_fence.position.y, tag])
		var block: Hazard = props.block(0, 60.0, Vector3(2.0, 1.5, 4.0), "block", 9.0)
		var low_block: Hazard = props.block(0, 70.0, Vector3(2.0, 1.5, 4.0))
		check(absf(block.position.y - 9.75) < 0.0001 and absf(low_block.position.y - 0.75) < 0.0001,
			"a block stands on the floor it's given (%.3f; on the street %.3f) %s" % [block.position.y, low_block.position.y, tag])
		var pad: Area3D = props.pad(lanes - 1, 80.0, 9.0)
		var low_pad: Area3D = props.pad(lanes - 1, 90.0)
		check(absf(pad.position.y - 9.25) < 0.0001 and absf(low_pad.position.y - 0.25) < 0.0001,
			"a pad lies on the floor it's given (%.3f; on the street %.3f) %s" % [pad.position.y, low_pad.position.y, tag])
		var line: MeshInstance3D = props.lane_warning(1, 100.0, 120.0, 9.0)
		var circle: MeshInstance3D = props.circle_warning(130.0, 0, 1.2, 0.0, 9.0)
		var low_line: MeshInstance3D = props.lane_warning(2, 100.0, 120.0)
		check(absf(line.transform.origin.y - 9.03) < 0.0001 and absf(circle.transform.origin.y - 9.05) < 0.0001
			and absf(low_line.transform.origin.y - 0.03) < 0.0001,
			"red warnings lie on the floor they're given (%.3f, %.3f; on the street %.3f) %s"
			% [line.transform.origin.y, circle.transform.origin.y, low_line.transform.origin.y, tag])
		var mist := Node3D.new()
		props.floor_warning(mist, 0, 140.0, 150.0, 9.0)
		check(props.warned(1, 105.0, 110.0, 9.0) and not props.warned(1, 105.0, 110.0, 0.0) and props.warned(1, 105.0, 110.0)
			and props.warned(0, 142.0, 144.0, 9.0) and not props.warned(0, 142.0, 144.0, 0.0)
			and props.warned(2, 105.0, 110.0, 0.0) and not props.warned(2, 105.0, 110.0, 9.0),
			"warned() at a height counts only the warnings on that floor; without one, any floor's %s" % tag)
		# Ceilings: over a range of lanes at a height, over every lane by default, and lane by lane.
		props.ceiling(200.0, 240.0, Vector2i(1, lanes - 1), 3.0)
		props.ceiling(250.0, 290.0)
		var ends := PackedFloat32Array()
		for lane: int in lanes:
			ends.append(360.0 if lane == 0 else (300.0 if lane == lanes - 1 else 340.0))
		var stepped: Array[Node3D] = props.ceiling_lanes(292.0, ends, 3.0)
		# Roofs, where the street is built: over a range of lanes, and over every lane 1 m deep.
		props.roof(Vector2i(1, 2), 150.0, 165.0, 9.0)
		props.roof(BossProps.ALL_LANES, 168.0, 178.0, 4.0, 1.0, true)
		await tree.physics_frame
		var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
		var hull_hits := func(z: float) -> Array:
			var hits: Array = []
			var ray := PhysicsRayQueryParameters3D.new()
			ray.collision_mask = TrackBuilder.LAYER_HULL
			for lane: int in lanes:
				ray.from = Vector3(geo.lane_x(lane), 0.5, -z)
				ray.to = Vector3(geo.lane_x(lane), 30.0, -z)
				var hit: Dictionary = space.intersect_ray(ray)
				hits.append(snappedf((hit["position"] as Vector3).y, 0.001) if not hit.is_empty() else -1.0)
			return hits
		var under: float = 3.0 + t.ceiling_height
		var narrow: Array = hull_hits.call(220.0)
		var want: Array = []
		for lane: int in lanes:
			want.append(-1.0 if lane == 0 else under)
		check(narrow == want, "a ceiling at a height covers its lanes, %.0f m up (%s) %s" % [under, narrow, tag])
		var plain: Array = hull_hits.call(270.0)
		var std: Array = []
		for lane: int in lanes:
			std.append(snappedf(t.ceiling_height, 0.001))
		check(plain == std, "a ceiling without them covers every lane at the standard height, as ever (%s) %s" % [plain, tag])
		var early: Array = hull_hits.call(305.0)
		var later: Array = hull_hits.call(350.0)
		var early_want: Array = []
		var later_want: Array = []
		for lane: int in lanes:
			early_want.append(under if lane < lanes - 1 else -1.0)
			later_want.append(under if lane == 0 else -1.0)
		var none: Array[Node3D] = props.ceiling_lanes(370.0, ends, 3.0)
		check(stepped.size() == 3 and early == early_want and later == later_want and none.is_empty(),
			"a ceiling lane by lane: one section per run of lanes ending together, each lane ending at its own end, none in a"
			+ " lane ending before it starts (%d; %s; %s) %s" % [stepped.size(), early, later, tag])
		var floor_hits := func(z: float) -> Array:
			var hits: Array = []
			var ray := PhysicsRayQueryParameters3D.new()
			ray.collision_mask = TrackBuilder.LAYER_FLOOR
			for lane: int in lanes:
				ray.from = Vector3(geo.lane_x(lane), 30.0, -z)
				ray.to = Vector3(geo.lane_x(lane), -0.5, -z)
				var hit: Dictionary = space.intersect_ray(ray)
				hits.append(snappedf((hit["position"] as Vector3).y, 0.001) if not hit.is_empty() else -1.0)
			return hits
		var roof_hits: Array = floor_hits.call(158.0)
		var roof_want: Array = []
		for lane: int in lanes:
			roof_want.append(9.0 if lane >= 1 and lane <= 2 else 0.0)
		check(roof_hits == roof_want, "a roof's top is a floor over exactly its lanes, the street beside it (%s) %s"
			% [roof_hits, tag])
		var slab: Array = floor_hits.call(173.0)
		# Under the slab's underside (3 m up) a ray going up meets it; one starting below that, going down,
		# meets the street and nothing else.
		var up := PhysicsRayQueryParameters3D.new()
		up.collision_mask = TrackBuilder.LAYER_FLOOR
		up.from = Vector3(geo.lane_x(0), 2.0, -173.0)
		up.to = Vector3(geo.lane_x(0), 3.5, -173.0)
		var hit_up: Dictionary = space.intersect_ray(up)
		check(slab.count(4.0) == lanes and not hit_up.is_empty() and absf((hit_up["position"] as Vector3).y - 3.0) < 0.001,
			"over every lane, `depth` deep: a slab 1 m thick under its top (%s) %s" % [slab, tag])
		mist.queue_free()
		await sim.free_world(world)
