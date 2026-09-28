extends TestSuite
## Ceilings over a range of lanes (GDD §3, decided September 26, 2026: ceilings don't have to cover
## every lane; on one the player switches lanes only within its width; a one-lane ceiling is simply
## ridden out, very short and relatively safe), on real physics, and what builds them:
## - CeilingSection and the track builder: the collision box spans exactly the lanes a ceiling covers
##   (a full-width one exactly as before), the skin hook gets the section, and the default hook the
##   narrow box;
## - the player: a move toward a lane the ceiling doesn't cover clanks and bumps (ceiling_blocked) and
##   keeps them on it, never past its edge; moves within it switch lanes; at the track's edge nothing
##   happens, as before; a pad holds its rider to the pad's lane; a one-lane ceiling is ridden out and
##   dropped from in its lane;
## - the chase camera never rises into a ceiling (RunCamera.ceiling_limit): a drop off a far end used
##   to take it up into the ceiling, where the end band's glow flashed across the screen (task B3).
## At 3, 5 and 6 lanes, with ranges at both edges and in the middle.

var sim: RunSim


func run() -> void:
	sim = RunSim.new(tree, tuning)
	_test_sections()
	await _test_track_boxes()
	await _test_moves()
	await _test_pad_holds_lane()
	await _test_one_lane_ride()
	await _test_camera()


## The ranges tried at `lanes` lanes: one lane at each edge and in the middle, two lanes at an edge,
## all but one lane, and every lane.
static func _ranges(lanes: int) -> Array[Vector2i]:
	var mid: int = lanes / 2
	var out: Array[Vector2i] = [Vector2i(0, 0), Vector2i(lanes - 1, lanes - 1), Vector2i(mid, mid), Vector2i(0, 1),
		Vector2i(lanes - 2, lanes - 1), Vector2i(1, lanes - 1), Vector2i(0, lanes - 1)]
	if lanes >= 5:
		out.append(Vector2i(1, 3))
	return out


## CeilingSection: the box over its lanes (lane edge to lane edge), the seams between them, which sides
## reach the street's edge; a full-width section's box is the one ceilings always had.
func _test_sections() -> void:
	for lanes: int in [3, 5, 6]:
		var geo := TrackGeometry.new(lanes, tuning)
		for r: Vector2i in _ranges(lanes):
			var tag: String = "lanes=%d range %s" % [lanes, r]
			var s := CeilingSection.make(geo, tuning.ceiling_height, TrackBuilder.HULL_THICKNESS, 100.0, 160.0, r)
			var x0: float = geo.lane_x(r.x) - geo.lane_width * 0.5
			var x1: float = geo.lane_x(r.y) + geo.lane_width * 0.5
			check(absf(s.edge_x(-1) - x0) < 0.0001 and absf(s.edge_x(1) - x1) < 0.0001,
				"the box spans its lanes' floor, lane edge to lane edge (%.2f to %.2f) %s" % [s.edge_x(-1), s.edge_x(1), tag])
			check(absf(s.underside_y() - tuning.ceiling_height) < 0.0001 and absf(s.size.z - 60.0) < 0.0001
				and absf(s.center.z + 130.0) < 0.0001, "its underside is at the ceiling's height, from its start to its end " + tag)
			check(s.lane_edges_x.size() == r.y - r.x and s.lanes() == r.y - r.x + 1, "a seam between each two of its lanes " + tag)
			check(s.reaches_wall(-1) == (r.x == 0) and s.reaches_wall(1) == (r.y == lanes - 1),
				"it reaches the street's edge where it covers the outer lane " + tag)
			check(s.full() == (r == Vector2i(0, lanes - 1)), "full only over every lane " + tag)
			if s.full():
				# As TrackBuilder always built it (Vector3 holds 32-bit floats: compare vectors).
				check(s.center == Vector3(0.0, tuning.ceiling_height + TrackBuilder.HULL_THICKNESS * 0.5, -(100.0 + 160.0) * 0.5)
					and s.size == Vector3(geo.half_width() * 2.0, TrackBuilder.HULL_THICKNESS, 160.0 - 100.0),
					"a full-width ceiling's box is exactly the one ceilings always had " + tag)
		var h: Dictionary = LevelLayout.make_hull(10.0, 20.0, Vector2i(0, lanes - 1), lanes)
		check(h == {"start": 10.0, "end": 20.0}, "a hull over every lane is stored as ever, without a range (%s)" % h)
		var n: Dictionary = LevelLayout.make_hull(10.0, 20.0, Vector2i(1, 1), lanes)
		var layout := RunSim.layout(lanes)
		check(layout.hull_lanes(n) == Vector2i(1, 1) and layout.hull_width(n) == 1 and layout.hull_covers(n, 1)
			and not layout.hull_covers(n, 0) and layout.hull_lanes(h) == Vector2i(0, lanes - 1),
			"a narrow hull keeps its lanes (lanes=%d)" % lanes)


## A skin that records what the track builder hands it.
class SectionSkin extends ZoneSkin:
	var sections: Array[CeilingSection] = []

	func ceiling_section(_parent: Node3D, section: CeilingSection) -> void:
		sections.append(section)


## A skin with only the old hook: it gets the ceiling's own box.
class BoxSkin extends ZoneSkin:
	var boxes: Array[Array] = []

	func hull(_parent: Node3D, center: Vector3, size: Vector3, lane_edges_x: Array[float]) -> void:
		boxes.append([center, size, lane_edges_x])


## The track builder's ceilings: one static body on the hull layer per ceiling, its box over the
## ceiling's lanes (a ray up from each lane's middle hits it only in those lanes), and the skin
## dresses the same section (the default hook, hull(), gets the narrow box).
func _test_track_boxes() -> void:
	for lanes: int in [3, 5, 6]:
		var layout := RunSim.layout(lanes, 600.0)
		var ranges: Array[Vector2i] = _ranges(lanes)
		for i: int in ranges.size():
			layout.hulls.append(LevelLayout.make_hull(40.0 + 60.0 * i, 80.0 + 60.0 * i, ranges[i], lanes))
		var skin := SectionSkin.new()
		var world := Node3D.new()
		tree.root.add_child(world)
		var track := TrackBuilder.new()
		world.add_child(track)
		track.set_layout(layout, tuning, skin)
		var geo := TrackGeometry.new(lanes, tuning)
		var ray := PhysicsRayQueryParameters3D.new()
		ray.collision_mask = TrackBuilder.LAYER_HULL
		for i: int in ranges.size():
			# Built around the ceiling (the track frees what's behind the player).
			track.update(40.0 + 60.0 * i, 0.0)
			await tree.physics_frame
			var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
			var r: Vector2i = ranges[i]
			var z: float = -(60.0 + 60.0 * i)
			var hits: Array[int] = []
			for lane: int in lanes:
				ray.from = Vector3(geo.lane_x(lane), tuning.ceiling_height - 1.0, z)
				ray.to = Vector3(geo.lane_x(lane), tuning.ceiling_height + 1.0, z)
				if not space.intersect_ray(ray).is_empty():
					hits.append(lane)
			var want: Array[int] = []
			for lane: int in range(r.x, r.y + 1):
				want.append(lane)
			check(hits == want, "the ceiling over lanes %s is solid over exactly those lanes (%s) lanes=%d" % [r, hits, lanes])
		check(skin.sections.size() == ranges.size(), "the skin dresses every ceiling (%d) lanes=%d" % [skin.sections.size(), lanes])
		for s: CeilingSection in skin.sections:
			var h: Dictionary = layout.hull_at(s.start + 1.0)
			check(not h.is_empty() and layout.hull_lanes(h) == Vector2i(s.first_lane, s.last_lane) and s.lane_count == lanes
				and absf(s.wall_x - geo.wall_x()) < 0.0001, "with its lanes and the walls (%d-%d) lanes=%d" % [s.first_lane, s.last_lane, lanes])
		world.queue_free()
		await tree.process_frame
		# The default hook gets the narrow ceiling's box.
		var box_skin := BoxSkin.new()
		var one := RunSim.layout(lanes, 200.0)
		one.hulls.append(LevelLayout.make_hull(40.0, 80.0, Vector2i(lanes - 1, lanes - 1), lanes))
		var w2 := Node3D.new()
		tree.root.add_child(w2)
		var t2 := TrackBuilder.new()
		w2.add_child(t2)
		t2.set_layout(one, tuning, box_skin)
		t2.update(0.0, 0.0)
		check(box_skin.boxes.size() == 1 and absf((box_skin.boxes[0][0] as Vector3).x - geo.lane_x(lanes - 1)) < 0.0001
			and absf((box_skin.boxes[0][1] as Vector3).x - geo.lane_width) < 0.0001 and (box_skin.boxes[0][2] as Array).is_empty(),
			"a skin with only hull() gets a one-lane ceiling's own box (lanes=%d)" % lanes)
		w2.queue_free()
		await tree.process_frame


## On a ceiling over some lanes: a move toward a lane it doesn't cover plays ceiling_blocked (the
## clank) and a bump out toward it and back; the player stays in their lane, on the ceiling, alive,
## and the body never goes past the ceiling's edge. A move within it switches lanes. At the track's
## edge a move does nothing, as it always did. Then the drop off its far end, in one of its lanes.
func _test_moves() -> void:
	sim.trace = true
	var half: float = tuning.visual_size.x * 0.5
	for lanes: int in [3, 5, 6]:
		var geo := TrackGeometry.new(lanes, tuning)
		for r: Vector2i in _ranges(lanes):
			for pad_lane: int in [r.x, r.y]:
				var tag: String = "lanes=%d range %s pad %d" % [lanes, r, pad_lane]
				var layout := RunSim.layout(lanes)
				layout.pads.append({"lane": pad_lane, "at": 20.0})
				layout.hulls.append(LevelLayout.make_hull(17.0, 90.0, r, lanes))
				# Outward from the pad's lane (past the range's edge on that side), then back inward.
				var out_dir: int = -1 if pad_lane == r.x else 1
				var out_action: StringName = &"move_left" if out_dir < 0 else &"move_right"
				var in_action: StringName = &"move_right" if out_dir < 0 else &"move_left"
				var width: int = r.y - r.x + 1
				var at_edge: bool = (pad_lane + out_dir < 0) or (pad_lane + out_dir >= lanes)
				var actions: Array = [[40.0, out_action]]
				if width > 1:
					actions.append([55.0, in_action])
				var res: Dictionary = await sim.run(layout, pad_lane, 6.0, actions, [50.0, 70.0, 100.0])
				var events: Array = res["events"]
				var on: Dictionary = res["at"][50.0]
				if at_edge:
					check(not events.has(&"ceiling_blocked") and on["surface"] == "ceiling" and int(on["lane"]) == pad_lane,
						"at the track's edge a move on the ceiling does nothing, as before %s" % tag)
				else:
					check(events.count(&"ceiling_blocked") == 1 and on["surface"] == "ceiling" and int(on["lane"]) == pad_lane,
						"a move past the ceiling's edge is blocked, with the clank, and the player stays on it in their lane (%s, %s) %s"
						% [events, on, tag])
					var edge: float = geo.lane_x(pad_lane) + out_dir * geo.lane_width * 0.5
					var worst: float = -INF
					for s: Dictionary in res["trace"]:
						if float(s["d"]) >= 40.0 and float(s["d"]) <= 50.0:
							worst = maxf(worst, out_dir * (float(s["x"]) - edge) + half)
					check(worst <= 0.0001, "the bump goes out toward the edge but never takes the body past it (%.3f m) %s" % [worst, tag])
					var leans: Array = []
					for s: Dictionary in res["trace"]:
						if float(s["d"]) >= 40.0 and float(s["d"]) <= 43.0 and not leans.has(s["lean"]):
							leans.append(s["lean"])
					check(leans.has(out_dir), "the runner leans into the blocked side, like a lane bump %s" % tag)
				var later: Dictionary = res["at"][70.0]
				if width > 1:
					check(later["surface"] == "ceiling" and int(later["lane"]) == pad_lane - out_dir,
						"a move within the ceiling switches lanes (%s) %s" % [later, tag])
				check(res["alive"] and res["surface"] == "floor" and events.has(&"hull_end"),
					"the player drops off the far end and lands (%s) %s" % [res["cause"], tag])
				var landed: Dictionary = res["at"][100.0]
				check(int(landed["lane"]) >= r.x and int(landed["lane"]) <= r.y, "in one of the ceiling's lanes (%d) %s" % [landed["lane"], tag])
	sim.trace = false


## A pad lands the player on its ceiling in its own lane (GDD §3): a lane switch still under way from
## the floor as the pad lifts them is blocked like any move off the ceiling (the clank, then back in
## the pad's lane) when the ceiling doesn't cover the lane they were moving to, and carries on when
## it does.
func _test_pad_holds_lane() -> void:
	for lanes: int in [3, 5, 6]:
		var mid: int = lanes / 2
		var tag: String = "lanes=%d" % lanes
		var one := RunSim.layout(lanes)
		one.pads.append({"lane": mid, "at": 30.0})
		one.hulls.append(LevelLayout.make_hull(27.0, 70.0, Vector2i(mid, mid), lanes))
		var r: Dictionary = await sim.run(one, mid, 3.0, [[29.7, &"move_right"]], [40.0])
		var events: Array = r["events"]
		var on: Dictionary = r["at"][40.0]
		check(events.has(&"pad") and events.has(&"ceiling_blocked") and on["surface"] == "ceiling" and int(on["lane"]) == mid,
			"switching away over a one-lane ceiling's pad: the pad lifts the player into its lane (%s, %s) %s" % [events, on, tag])
		check(r["alive"] and int(r["lane"]) == mid, "and they ride it out and land in it %s" % tag)
		var two := RunSim.layout(lanes)
		two.pads.append({"lane": mid, "at": 30.0})
		two.hulls.append(LevelLayout.make_hull(27.0, 70.0, Vector2i(mid, mid + 1), lanes))
		r = await sim.run(two, mid, 3.0, [[29.7, &"move_right"]], [40.0])
		on = r["at"][40.0]
		check(r["events"].has(&"pad") and not r["events"].has(&"ceiling_blocked") and on["surface"] == "ceiling"
			and int(on["lane"]) == mid + 1, "over a ceiling that covers the other lane too, the switch carries on (%s) %s" % [on, tag])


## A one-lane ceiling is simply ridden out (GDD §3): the player rides it to its end without a move and
## drops in its lane, where the landing zone is clear, even with holes and fences right after its end
## in every other lane (a narrow ceiling's landing zone covers its own lanes).
func _test_one_lane_ride() -> void:
	var seconds: float = (load(LEVEL_PATH) as LevelConfig).one_lane_ceiling_seconds
	for lanes: int in [3, 5, 6]:
		for lane: int in [0, lanes / 2, lanes - 1]:
			var tag: String = "lanes=%d lane %d" % [lanes, lane]
			var layout := RunSim.layout(lanes)
			var end: float = 30.0 + seconds * tuning.run_speed
			layout.pads.append({"lane": lane, "at": 30.0})
			layout.hulls.append(LevelLayout.make_hull(27.0, end, Vector2i(lane, lane), lanes))
			for other: int in lanes:
				if other != lane:
					layout.gaps.append({"lane": other, "start": end + 2.0, "end": end + 8.0})
					layout.fences.append(RunSim.fence(other, end + 12.0, "full"))
			var r: Dictionary = await sim.run(layout, lane, 5.0, [], [40.0, end + 20.0])
			check(r["at"][40.0]["surface"] == "ceiling", "the player rides the one-lane ceiling %s" % tag)
			check(r["alive"] and r["events"].has(&"hull_end") and int(r["at"][end + 20.0]["lane"]) == lane
				and r["at"][end + 20.0]["surface"] == "floor", "and drops back into its lane, safe (%s) %s" % [r["cause"], tag])


## The chase camera never rises into a ceiling (RunCamera.ceiling_limit): through a drop off a far
## end, while it is under the ceiling or within CEILING_SIDE of a narrow one's side it stays
## camera_ceiling_clearance below the underside, and past the end it stays below the underside, where
## no skin puts a glow (MeshKit.ceiling_end). Full-width and narrow ceilings, at 3, 5 and 6 lanes.
func _test_camera() -> void:
	var clearance: float = tuning.camera_ceiling_clearance
	for lanes: int in [3, 5, 6]:
		for r: Vector2i in [Vector2i(0, lanes - 1), Vector2i(lanes / 2, lanes / 2), Vector2i(0, 1), Vector2i(lanes - 1, lanes - 1)]:
			var tag: String = "lanes=%d range %s" % [lanes, r]
			var layout := RunSim.layout(lanes, 400.0)
			layout.pads.append({"lane": r.x, "at": 20.0})
			layout.hulls.append(LevelLayout.make_hull(17.0, 60.0, r, lanes))
			var world: RunWorld = sim.build_world(layout)
			world.player.setup(tuning, world.geo, r.x)
			var camera := RunCamera.new()
			tree.root.add_child(camera)
			camera.follow(world)
			await tree.physics_frame
			world.start()
			var x0: float = world.geo.lane_x(r.x) - world.geo.lane_width * 0.5 - RunCamera.CEILING_SIDE
			var x1: float = world.geo.lane_x(r.y) + world.geo.lane_width * 0.5 + RunCamera.CEILING_SIDE
			var under: float = -INF
			var past: float = -INF
			var rode: bool = false
			for i: int in 220:
				await tree.physics_frame
				await tree.process_frame
				rode = rode or world.player.surface == Player.Surface.CEILING
				var cam: Vector3 = camera.global_position
				var d: float = -cam.z
				var beside: bool = cam.x >= x0 and cam.x <= x1
				if beside and d >= 17.0 and d <= 60.0:
					under = maxf(under, cam.y - tuning.ceiling_height)
				elif d > 60.0 and d < 72.0:
					past = maxf(past, cam.y - tuning.ceiling_height)
			check(rode and world.player.alive and world.player.surface == Player.Surface.FLOOR, "the player rode the ceiling and dropped " + tag)
			check(under <= -clearance + 0.001, "the camera stays %.1f m below the ceiling while under or beside it (%.3f) %s"
				% [clearance, under, tag])
			check(past < -0.05, "and below its underside past its end (%.3f) %s" % [past, tag])
			camera.queue_free()
			await sim.free_world(world)
	# The limit itself: none without a ceiling, the clearance under one and beside a narrow one.
	var open := RunSim.layout(5, 200.0)
	open.hulls.append(LevelLayout.make_hull(40.0, 80.0, Vector2i(0, 0), 5))
	var w: RunWorld = sim.build_world(open)
	await tree.physics_frame
	var space: PhysicsDirectSpaceState3D = w.get_world_3d().direct_space_state
	var lane0: float = w.geo.lane_x(0)
	check(RunCamera.ceiling_limit(space, Vector3(0.0, 4.2, -20.0), tuning) == INF, "no limit where no ceiling is near")
	check(absf(RunCamera.ceiling_limit(space, Vector3(lane0, 4.2, -60.0), tuning) - (tuning.ceiling_height - clearance)) < 0.001,
		"under a ceiling: its underside less the clearance")
	check(absf(RunCamera.ceiling_limit(space, Vector3(lane0 + w.geo.lane_width * 0.5 + 0.8, 4.2, -60.0), tuning)
		- (tuning.ceiling_height - clearance)) < 0.001, "just beside a narrow one too")
	check(RunCamera.ceiling_limit(space, Vector3(lane0 + w.geo.lane_width * 0.5 + 1.5, 4.2, -60.0), tuning) == INF,
		"but not further off")
	check(absf(RunCamera.ceiling_limit(space, Vector3(lane0, 4.2, -38.5), tuning) - (tuning.ceiling_height - clearance)) < 0.001,
		"and just before one, so the camera comes down before it gets there")
	await sim.free_world(w)
