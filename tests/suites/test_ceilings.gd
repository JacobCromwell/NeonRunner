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
	await _test_skins()


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


## Every zone skin (each skin in data/skins/, and the City boss arena's) dresses a ceiling from the
## lanes it covers (GDD §3; ZoneSkin.ceiling_section), full width or narrow, at 3, 5 and 6 lanes, for
## several spots along the track (the kinds of structure a skin picks by hashing where a ceiling is):
## - its underside, the surface, covers the ceiling's collision footprint, and on a side that doesn't
##   reach the street's edge stops at that edge (it never looks like it covers a lane it doesn't);
## - nothing hangs below the underside over the footprint (a lamp flush with it at most);
## - the orange band crosses the far end over the ceiling's whole width ("you drop here");
## - past the far end nothing sits below the underside, glowing or not: the chase camera passes there
##   as the player drops (RunCamera.ceiling_limit), and what glowed there flashed across the screen.
func _test_skins() -> void:
	var skins: Dictionary = {}
	for file: String in DirAccess.get_files_at("res://data/skins"):
		if file.ends_with(".tres"):
			skins[file.get_basename()] = load("res://data/skins".path_join(file))
	skins["city_boss_skin"] = load("res://data/bosses/city_boss_skin.tres")
	check(skins.size() >= 7, "every skin is swept (%d)" % skins.size())
	var built: int = 0
	for skin_name: String in skins:
		var skin := skins[skin_name] as ZoneSkin
		if skin == null:
			check(false, "%s is a zone skin" % skin_name)
			continue
		var edge_color: Color = skin.get("gap_edge_color") if skin.get("gap_edge_color") is Color else Color(1.0, 0.25, 0.04)
		var problems: PackedStringArray = []
		for lanes: int in [3, 5, 6]:
			var geo := TrackGeometry.new(lanes, tuning)
			var mid: int = lanes / 2
			var ranges: Array[Vector2i] = [Vector2i(0, lanes - 1), Vector2i(0, 0), Vector2i(mid, mid), Vector2i(lanes - 1, lanes - 1),
				Vector2i(lanes - 2, lanes - 1), Vector2i(1, lanes - 1)]
			for r: Vector2i in ranges:
				for spot: int in 3:
					var start: float = 180.0 + 97.3 * spot + 11.0 * r.x
					var length: float = 29.0 if r.x == r.y else 44.0 + 9.0 * spot
					var section := CeilingSection.make(geo, tuning.ceiling_height, TrackBuilder.HULL_THICKNESS, start,
						start + length, r)
					var tag: String = "%s lanes=%d range %s at %.0f" % [skin_name, lanes, r, start]
					var root := Node3D.new()
					tree.root.add_child(root)
					skin.ceiling_section(root, section)
					_check_dressed(root, section, edge_color, spot == 0, tag, problems)
					root.queue_free()
					built += 1
		check(problems.is_empty(), "%s dresses every ceiling from its lanes:\n    %s" % [skin_name,
			"\n    ".join(problems.slice(0, 10))])
	await tree.process_frame
	check(built >= 7 * 3 * 6 * 3, "ceilings dressed: %d" % built)


## The triangles of every visible mesh under `root`, in world space: {a, b, c, color, glow}. A kit
## mesh carries its colour and glow per vertex (COLOR.a above 0 glows on the solid material; every
## card on a glow material glows); a grey-box piece carries them in its material.
static func _triangles(root: Node) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		var m := node as MeshInstance3D
		if m == null or m.mesh == null or not m.visible:
			continue
		var xform: Transform3D = m.global_transform
		for s: int in m.mesh.get_surface_count():
			var arrays: Array = m.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var colors := PackedColorArray()
			if arrays[Mesh.ARRAY_COLOR] != null:
				colors = arrays[Mesh.ARRAY_COLOR]
			var index := PackedInt32Array()
			if arrays[Mesh.ARRAY_INDEX] != null:
				index = arrays[Mesh.ARRAY_INDEX]
			var material: Material = m.material_override if m.material_override != null else m.mesh.surface_get_material(s)
			var card: bool = material is ShaderMaterial and (material as ShaderMaterial).shader != null \
				and (material as ShaderMaterial).shader.resource_path.ends_with("kit_glow.gdshader")
			var base := Color.WHITE
			var lit_glow: bool = false
			if material is StandardMaterial3D:
				base = (material as StandardMaterial3D).albedo_color
				lit_glow = (material as StandardMaterial3D).emission_enabled
			var count: int = index.size() if not index.is_empty() else verts.size()
			for t: int in range(0, count - 2, 3):
				var i0: int = index[t] if not index.is_empty() else t
				var i1: int = index[t + 1] if not index.is_empty() else t + 1
				var i2: int = index[t + 2] if not index.is_empty() else t + 2
				var c: Color = colors[i0] if not colors.is_empty() else base
				out.append({"a": xform * verts[i0], "b": xform * verts[i1], "c": xform * verts[i2], "color": c,
					"glow": card or lit_glow or (not colors.is_empty() and c.a > 0.001)})
	return out


## The checks _test_skins makes of one dressed ceiling (see there), adding what fails to `problems`.
## `coverage`: also sample the underside's coverage of the footprint (the slowest check).
func _check_dressed(root: Node3D, section: CeilingSection, edge_color: Color, coverage: bool, tag: String,
		problems: PackedStringArray) -> void:
	var y0: float = section.underside_y()
	var x0: float = section.edge_x(-1)
	var x1: float = section.edge_x(1)
	var tris: Array[Dictionary] = _triangles(root)
	if tris.is_empty():
		problems.append("%s: nothing drawn" % tag)
		return
	var plane: Array[Dictionary] = []
	var band := Vector2(INF, -INF)
	var plane_x := Vector2(INF, -INF)
	var below_past: String = ""
	var hanging: String = ""
	for tri: Dictionary in tris:
		var pts: Array[Vector3] = [tri["a"], tri["b"], tri["c"]]
		var in_plane: bool = true
		var past: bool = false
		var lowest: float = INF
		for p: Vector3 in pts:
			in_plane = in_plane and absf(p.y - y0) < 0.006
			past = past or -p.z > section.end + 0.01
			lowest = minf(lowest, p.y)
			if hanging == "" and p.x > x0 + 0.02 and p.x < x1 - 0.02 and -p.z > section.start + 0.02 \
					and -p.z < section.end - 0.02 and p.y < y0 - 0.1 and p.y > 0.5:
				hanging = "%s" % p
		if past and lowest < y0 - 0.001 and below_past == "":
			below_past = "%s%s" % [pts, " (glowing)" if tri["glow"] else ""]
		if in_plane:
			plane.append(tri)
			for p: Vector3 in pts:
				plane_x = Vector2(minf(plane_x.x, p.x), maxf(plane_x.y, p.x))
		var c: Color = tri["color"]
		if tri["glow"] and absf(c.r - edge_color.r) < 0.02 and absf(c.g - edge_color.g) < 0.02 \
				and absf(c.b - edge_color.b) < 0.02:
			var near_end: bool = true
			for p: Vector3 in pts:
				near_end = near_end and -p.z > section.end - 1.6 and absf(p.y - y0) < 0.08
			if near_end:
				for p: Vector3 in pts:
					band = Vector2(minf(band.x, p.x), maxf(band.y, p.x))
	if below_past != "":
		problems.append("%s: past the far end something sits below the underside: %s" % [tag, below_past])
	if hanging != "":
		problems.append("%s: something hangs below the underside over the lanes at %s" % [tag, hanging])
	if band.x > x0 + 0.05 or band.y < x1 - 0.05:
		problems.append("%s: the orange band spans %.2f to %.2f, not the ceiling's width %.2f to %.2f" % [tag, band.x,
			band.y, x0, x1])
	if not section.reaches_wall(-1) and plane_x.x < x0 - 0.35:
		problems.append("%s: the underside reaches %.2f past its free left edge %.2f" % [tag, plane_x.x, x0])
	if not section.reaches_wall(1) and plane_x.y > x1 + 0.35:
		problems.append("%s: the underside reaches %.2f past its free right edge %.2f" % [tag, plane_x.y, x1])
	if not coverage:
		return
	var xs: Array[float] = [x0 + 0.1, x1 - 0.1]
	for lane: int in range(section.first_lane, section.last_lane + 1):
		xs.append(section.center.x + (float(lane) - (section.first_lane + section.last_lane) * 0.5) * section.lane_width)
	var bare: int = 0
	var d: float = section.start + 0.4
	while d < section.end - 0.2:
		for x: float in xs:
			if not _covered(plane, Vector2(x, -d)):
				bare += 1
		d += 3.7
	if bare > 0:
		problems.append("%s: the underside leaves %d points of the footprint bare" % [tag, bare])


static func _covered(tris: Array[Dictionary], p: Vector2) -> bool:
	for tri: Dictionary in tris:
		var a := Vector2((tri["a"] as Vector3).x, (tri["a"] as Vector3).z)
		var b := Vector2((tri["b"] as Vector3).x, (tri["b"] as Vector3).z)
		var c := Vector2((tri["c"] as Vector3).x, (tri["c"] as Vector3).z)
		if p.x < minf(a.x, minf(b.x, c.x)) - 0.001 or p.x > maxf(a.x, maxf(b.x, c.x)) + 0.001:
			continue
		var d1: float = (p - b).cross(a - b)
		var d2: float = (p - c).cross(b - c)
		var d3: float = (p - a).cross(c - a)
		var has_neg: bool = d1 < 0.0 or d2 < 0.0 or d3 < 0.0
		var has_pos: bool = d1 > 0.0 or d2 > 0.0 or d3 > 0.0
		if not (has_neg and has_pos):
			return true
	return false
