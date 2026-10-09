extends SkinSuite
## Side wall gaps (the `wall_gaps` feature; owner's answers in docs/USER_REQUESTS.md: a gap removes the
## wall-running surface, a wall runner drops off automatically, rare, from Zone 2 on, both walls at
## once only rarely, no boss levels, no promise about the outer lane beside one). Checked here:
## - the data and its interval queries (LevelLayout.wall_supported, wall_solid_pieces, wall_gap_spans);
## - the track: the wall is drawn over exactly the solid stretches and the gap look over exactly the
##   gaps, across chunk boundaries (a recording skin); every zone skin builds them without errors, shows
##   the orange leading edge where the gap starts, and draws no wall face inside one;
## - real physics at 3, 5 and 6 lanes: a wall runner drops off at a gap (wall_gap_drop) into the outer
##   lane and steps back onto the wall past it, entry is refused inside a gap (wall_missing, no bump) on
##   that wall only, both walls at once;
## - the generator: Zone 2 on places a few, deterministically, rarely on both walls, clear of every
##   keep-out (WallGapPlacement.keep_outs) and with no wall credit inside one; City levels and every
##   boss arena have none, and a level is otherwise the same without the feature.
## - a level's own numbers (LevelConfig.wall_gap_tuning, task D10b): null in every campaign level but the Beach's,
##   which places its gaps by the shared file (a copy of its numbers builds the same level); the Beach's open their
##   walls by the Beach's file (task D10c: in the campaign); a level's own numbers are the ones it's built by, and
##   change nothing but its wall gaps and the wall credits a gap takes;
## - open walls (WallGapTuning.coverage_target, the Beach's; task D10b) on made-up tracks at 3, 5 and 6 lanes:
##   each wall opens what its keep-outs leave free in stretches at least open_seconds_min long, down to its
##   target, both walls at once within both_open_max; a wall whose keep-outs leave too little stands more, and
##   nothing opens through a keep-out (test_beach_levels checks the Beach's real levels).

## The levels with the shared numbers' few, rare gaps (the Beach's open their walls by their own numbers: task D10b,
## test_beach_levels).
const WITH: Array = ["gangland/1", "gangland/2", "gangland/3", "marketplace/1", "marketplace/2", "corporate/1",
	"corporate/2", "dead_zone/1", "dead_zone/2", "golden/1", "golden/2", "golden/3"]
## The Beach's open walls (task D10b), the one campaign zone with numbers of its own.
const BEACH_WALL_GAPS: String = "res://data/tuning/beach_wall_gaps.tres"
const WITHOUT: Array = ["city/1", "city/2", "city/3"]


## Records the wall calls TrackBuilder makes.
class RecordingSkin extends ZoneSkin:
	var solid: Array = []  ## [side, start, end]
	var gaps: Array = []  ## [side, start, end, gap]

	func wall_section(_parent: Node3D, side: int, _face_x: float, start: float, end: float) -> void:
		solid.append([side, start, end])

	func wall_gap(_parent: Node3D, side: int, _face_x: float, start: float, end: float, gap: Vector2) -> void:
		gaps.append([side, start, end, gap])


var sim: RunSim
var campaign: Campaign


func run() -> void:
	sim = RunSim.new(tree, tuning)
	campaign = load("res://data/campaign/campaign.tres") as Campaign
	_test_data()
	await _test_track_intervals()
	await _test_skins()
	await _test_wall_runner()
	await _test_refused_entry()
	_test_campaign_levels()
	_test_without()
	_test_bosses()
	_test_level_tuning()
	_test_open_walls()


static func _layout(lanes: int, gaps: Array, length: float = 400.0) -> LevelLayout:
	var l := RunSim.layout(lanes, length)
	for g: Array in gaps:
		l.wall_gaps.append({"side": int(g[0]), "start": float(g[1]), "end": float(g[2])})
	return l


func _test_data() -> void:
	var l := _layout(3, [[1, 50.0, 70.0], [-1, 60.0, 65.0]])
	check(l.wall_supported(1, 49.9) and not l.wall_supported(1, 50.0) and not l.wall_supported(1, 69.9)
		and l.wall_supported(1, 70.0), "a gap holds [start, end) of its own wall")
	check(l.wall_supported(-1, 55.0) and not l.wall_supported(-1, 62.0), "each wall has its own gaps")
	check(str(l.wall_solid_pieces(1, 40.0, 80.0)) == str([Vector2(40, 50), Vector2(70, 80)]),
		"the solid pieces leave the gap out")
	check(str(l.wall_gap_pieces(1, 60.0, 100.0)) == str([Vector2(60, 70)])
		and str(l.wall_gap_spans(1, 60.0, 100.0)) == str([Vector2(50, 70)]), "gap pieces clip, spans don't")
	check(str(l.wall_solid_pieces(1, 0.0, 40.0)) == str([Vector2(0, 40)]), "no gap: the whole range")
	check(l.wall_gap_between(69.0, 75.0, 1) and not l.wall_gap_between(71.0, 75.0, 1), "wall_gap_between")
	check(not RunSim.layout(3).to_dict().has("wall_gaps") and l.to_dict().has("wall_gaps"),
		"a layout without gaps has no wall_gaps key (old dumps unchanged)")
	var c: LevelLayout = l.copy()
	check(JSON.stringify(c.wall_gaps) == JSON.stringify(l.wall_gaps) and not is_same(c.wall_gaps[0], l.wall_gaps[0]),
		"copy() carries the gaps")


## TrackBuilder draws the wall over exactly the solid stretches and the gap look over exactly the gaps:
## together they tile each wall, chunk by chunk, with no overlap, gaps crossing chunk boundaries too.
func _test_track_intervals() -> void:
	for lanes: int in [3, 5, 6]:
		var tag: String = "(%d lanes)" % lanes
		var layout := _layout(lanes, [[1, 30.0, 52.0], [-1, 75.0, 81.0], [1, 75.0, 81.0], [-1, 118.0, 145.0]], 200.0)
		var skin := RecordingSkin.new()
		var world := Node3D.new()
		tree.root.add_child(world)
		var track := TrackBuilder.new()
		world.add_child(track)
		track.dress_budget_usec = 0
		track.set_layout(layout, tuning, skin)
		var d: float = 0.0
		while d <= layout.length + TrackBuilder.RUN_OUT + TrackBuilder.CHUNK_LENGTH:
			track.update(d, d / tuning.run_speed)
			d += TrackBuilder.CHUNK_LENGTH
		for side: int in [-1, 1]:
			var pieces: Array = []
			for s: Array in skin.solid:
				if int(s[0]) == side:
					pieces.append([float(s[1]), float(s[2]), false])
					check(layout.wall_supported(side, (float(s[1]) + float(s[2])) * 0.5) and not layout.wall_gap_between(
						float(s[1]) + 0.001, float(s[2]) - 0.001, side), "no wall drawn over a gap: %s %s" % [s, tag])
			var drawn: Dictionary = {}
			for g: Array in skin.gaps:
				if int(g[0]) != side:
					continue
				pieces.append([float(g[1]), float(g[2]), true])
				var full: Vector2 = g[3]
				drawn[full] = float(drawn.get(full, 0.0)) + float(g[2]) - float(g[1])
				check(not layout.wall_supported(side, (float(g[1]) + float(g[2])) * 0.5), "gap look only in a gap %s" % tag)
			for g: Dictionary in layout.wall_gaps:
				if int(g["side"]) == side:
					var full := Vector2(float(g["start"]), float(g["end"]))
					check(is_equal_approx(float(drawn.get(full, 0.0)), full.y - full.x),
						"the gap %s on wall %d is drawn whole (%.2f m) %s" % [full, side, float(drawn.get(full, 0.0)), tag])
			pieces.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
			var tiled: bool = not pieces.is_empty()
			for i: int in range(1, pieces.size()):
				tiled = tiled and is_equal_approx(float(pieces[i][0]), float(pieces[i - 1][1]))
			check(tiled, "wall %d: solid and gap pieces tile the wall with no overlap or hole %s" % [side, tag])
		world.queue_free()
		await tree.process_frame


## Every skin: builds gaps without errors, marks the leading edge in orange on the wall face where
## the gap starts, and draws no wall face inside the gap (no ghost wall to run along).
func _test_skins() -> void:
	var skins: Array[ZoneSkin] = [GreyboxSkin.new()]
	var names: Array[String] = ["grey box"]
	for file: String in DirAccess.get_files_at("res://data/skins"):
		if file.ends_with(".tres"):
			skins.append(load("res://data/skins".path_join(file)) as ZoneSkin)
			names.append(file.get_basename())
	for i: int in skins.size():
		for lanes: int in [3, 5, 6]:
			var tag: String = "(%s, %d lanes)" % [names[i], lanes]
			# The right gap crosses a chunk boundary (40 m); the left one shares part of it (both walls).
			var layout := _layout(lanes, [[1, 30.0, 52.0], [-1, 44.0, 60.0]], 200.0)
			var face: float = TrackGeometry.new(lanes, tuning).wall_x()
			var lead := {-1: false, 1: false}
			var ghosts: Array[String] = []
			start_error_count()
			await visit_level(layout, skins[i], func(m: MeshInstance3D, arrays: Array, _mat: Material) -> void:
				var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var colors: Variant = arrays[Mesh.ARRAY_COLOR]
				var xf: Transform3D = m.global_transform
				for k: int in verts.size():
					var p: Vector3 = xf * verts[k]
					var along: float = -p.z
					for g: Dictionary in layout.wall_gaps:
						var side: int = int(g["side"])
						var out_from_face: float = (p.x - side * face) * side
						var start: float = float(g["start"])
						if colors is PackedColorArray and (colors as PackedColorArray).size() > k:
							var c: Color = (colors as PackedColorArray)[k]
							if c.r > 0.9 and c.g < 0.5 and c.b < 0.2 and p.y > 3.0 and absf(out_from_face) < 0.6 \
									and absf(along - start) < 0.6:
								lead[side] = true
						# A wall face in the gap: anything standing up at the face, between floor and wall-run height.
						if along > start + 1.0 and along < float(g["end"]) - 1.0 and absf(out_from_face) < 0.15 \
								and p.y > 1.0 and p.y < 4.5:
							ghosts.append("%s %s" % [m.get_parent().name, p]))
			stop_error_count("building wall gaps " + tag)
			check(lead[-1] and lead[1], "an orange leading edge on the face at each gap's start %s" % tag)
			check(ghosts.is_empty(), "no wall face inside a gap %s: %s" % [tag, ghosts.slice(0, 3)])


func _test_wall_runner() -> void:
	for lanes: int in [3, 5, 6]:
		var tag: String = "(%d lanes)" % lanes
		var right: int = lanes - 1
		# Supported: a wall run past the same stretch with the gap on the other wall goes on.
		var r: Dictionary = await sim.run(_layout(lanes, [[-1, 60.0, 90.0]]), right, 7.0, [[40.0, &"move_right"]], [55.0, 70.0])
		check(r["at"][55.0]["surface"] == "wall" and r["at"][70.0]["surface"] == "wall" and not r["events"].has(&"wall_gap_drop"),
			"a gap on the other wall changes nothing %s" % tag)
		# Missing: the runner drops off at the gap into the outer lane, then steps back on past it.
		r = await sim.run(_layout(lanes, [[1, 60.0, 90.0]]), right, 7.0, [[40.0, &"move_right"], [95.0, &"move_right"]],
			[55.0, 61.0, 80.0, 105.0])
		check(r["at"][55.0]["surface"] == "wall", "on the wall before the gap %s" % tag)
		check(r["at"][61.0]["surface"] == "floor", "dropped off at the gap's start %s" % tag)
		check(r["at"][80.0]["surface"] == "floor" and r["at"][80.0]["lane"] == right and r["at"][80.0]["h"] == 0.0
			and r["at"][80.0]["alive"], "landed alive in the outer lane %s: %s" % [tag, r["at"][80.0]])
		check(r["events"].has(&"wall_gap_drop") and not r["events"].has(&"wall_blocked"), "the drop is its own event %s: %s" % [tag, r["events"]])
		check(r["at"][105.0]["surface"] == "wall", "back on the wall past the gap with the move input %s" % tag)
		# Left wall the same.
		r = await sim.run(_layout(lanes, [[-1, 60.0, 90.0]]), 0, 7.0, [[40.0, &"move_left"]], [55.0, 61.0])
		check(r["at"][55.0]["surface"] == "wall" and r["at"][61.0]["surface"] == "floor" and r["events"].has(&"wall_gap_drop"),
			"the left wall drops too %s" % tag)


func _test_refused_entry() -> void:
	for lanes: int in [3, 5, 6]:
		var tag: String = "(%d lanes)" % lanes
		var right: int = lanes - 1
		var both := _layout(lanes, [[1, 60.0, 90.0], [-1, 60.0, 90.0]])
		var r: Dictionary = await sim.run(both, right, 7.0, [[65.0, &"move_right"]], [75.0])
		check(r["at"][75.0]["surface"] == "floor" and r["at"][75.0]["lane"] == right and r["events"].has(&"wall_missing")
			and not r["events"].has(&"wall_blocked") and r["alive"], "no wall to step onto in a gap, no bump %s: %s" % [tag, r["events"]])
		r = await sim.run(both, 0, 7.0, [[65.0, &"move_left"]], [75.0])
		check(r["at"][75.0]["surface"] == "floor" and r["events"].has(&"wall_missing"), "both walls at once %s" % tag)
		# A jump first (in the air over the floor) is refused the same way.
		r = await sim.run(both, right, 7.0, [[62.0, &"jump"], [64.0, &"move_right"]], [75.0])
		check(r["at"][75.0]["surface"] == "floor" and r["events"].has(&"wall_missing"), "nor from a jump %s" % tag)
		r = await sim.run(_layout(lanes, [[-1, 60.0, 90.0]]), right, 7.0, [[65.0, &"move_right"]], [75.0])
		check(r["at"][75.0]["surface"] == "wall", "the other wall is still there %s" % tag)


## The generator: Zone 2 on, deterministic, rare, rarely on both walls, clear of the keep-outs.
func _test_campaign_levels() -> void:
	var per_minute: Array[float] = []
	var events: int = 0
	var bilateral: int = 0
	var lengths: Array[float] = []
	for id: String in WITH:
		for lanes: int in [3, 5, 6]:
			for k: int in 3:
				var config: LevelConfig = campaign.configure(campaign.step(id), lanes)
				if k > 0:
					config.level_seed = 7300 + k
				var tag: String = "%s lanes=%d seed=%d" % [id, lanes, config.level_seed]
				var t: WallGapTuning = WallGapPlacement.tuning_for(config)
				var patterns: Array = LevelGenerator.load_for(config)
				var gen: LevelGenerator = LayoutCache.generator(config, tuning, patterns)
				var layout: LevelLayout = gen.layout
				check(gen.warnings.is_empty(), "no warnings %s %s" % [tag, gen.warnings])
				check(not layout.wall_gaps.is_empty(), "every Zone 2+ level has a wall gap %s" % tag)
				var starts: Dictionary = {}
				for g: Dictionary in layout.wall_gaps:
					var key: float = float(g["start"])
					starts[key] = int(starts.get(key, 0)) + 1
					var secs: float = (float(g["end"]) - float(g["start"])) / gen.speed
					lengths.append(secs)
					check(secs >= t.length_seconds_min - 0.01 and secs <= t.length_seconds_max + 0.01, "gap length %.2f s %s" % [secs, tag])
				for key: float in starts:
					events += 1
					if int(starts[key]) > 1:
						bilateral += 1
				per_minute.append(starts.size() / (layout.length / gen.speed) * 60.0)
				for side: int in [-1, 1]:
					var keeps: Array[Vector2] = WallGapPlacement.keep_outs(gen, layout, side, t)
					for g: Dictionary in layout.wall_gaps:
						if int(g["side"]) != side:
							continue
						for kp: Vector2 in keeps:
							check(not (float(g["start"]) < kp.y - 0.01 and float(g["end"]) > kp.x + 0.01),
								"gap %s clear of keep-out %s %s" % [g, kp, tag])
				for c: Dictionary in layout.credits:
					if c["surface"] == "wall":
						check(layout.wall_supported(int(c["side"]), float(c["at"])), "no wall credit in a gap %s" % tag)
				if k == 0:
					var again: LevelLayout = LevelGenerator.new().generate(config, tuning, patterns)
					check(JSON.stringify(again.wall_gaps) == JSON.stringify(layout.wall_gaps), "the same gaps every attempt " + tag)
	per_minute.sort()
	lengths.sort()
	var share: float = float(bilateral) / maxf(events, 1)
	check(per_minute[per_minute.size() / 2] >= 1.0 and per_minute[per_minute.size() / 2] <= 3.5,
		"low frequency: median %.2f a minute" % per_minute[per_minute.size() / 2])
	check(bilateral > 0 and share <= 0.25, "both walls at once, but rarely (%d of %d, %.0f%%)" % [bilateral, events, share * 100.0])
	print("  wall gaps per minute: %.2f to %.2f (median %.2f); %d gaps, %d on both walls (%.1f%%); length %.2f-%.2f s" % [
		per_minute[0], per_minute[-1], per_minute[per_minute.size() / 2], events, bilateral, share * 100.0, lengths[0], lengths[-1]])


## City (Zone 1) levels have none, and a Zone 2 level is the same without the feature but for its
## gaps and the wall credits a gap took.
func _test_without() -> void:
	for id: String in WITHOUT:
		for lanes: int in [3, 5, 6]:
			var config: LevelConfig = campaign.configure(campaign.step(id), lanes)
			var layout: LevelLayout = LayoutCache.generate(config, tuning, LevelGenerator.load_for(config))
			check(layout.wall_gaps.is_empty() and not layout.to_dict().has("wall_gaps"), "%s (%d lanes) has no wall gaps" % [id, lanes])
	for id: String in ["gangland/1", "corporate/2"]:
		var config: LevelConfig = campaign.configure(campaign.step(id), 5)
		var patterns: Array = LevelGenerator.load_for(config)
		var with_gaps: LevelLayout = LayoutCache.generate(config, tuning, patterns)
		var bare: LevelConfig = config.duplicate() as LevelConfig
		var features := PackedStringArray(config.features)
		features.remove_at(features.find(WallGapPlacement.FEATURE))
		bare.features = features
		bare.feature_ages = config.feature_ages.duplicate()
		bare.feature_ages.erase(WallGapPlacement.FEATURE)
		var without: LevelLayout = LevelGenerator.new().generate(bare, tuning, patterns)
		var a: Dictionary = with_gaps.to_dict()
		var b: Dictionary = without.to_dict()
		for key: String in ["wall_gaps", "credits"]:
			a.erase(key)
			b.erase(key)
		check(JSON.stringify(a) == JSON.stringify(b), "%s is otherwise the same without wall gaps" % id)
		var kept: int = 0
		for c: Dictionary in with_gaps.credits:
			if without.credits.has(c):
				kept += 1
		check(kept == with_gaps.credits.size(), "%s: the gaps only take credits away (%d of %d kept, %d without)" % [
			id, kept, with_gaps.credits.size(), without.credits.size()])


## Every boss arena: no gaps, even if its config were to list the feature.
func _test_bosses() -> void:
	for file: String in DirAccess.get_files_at("res://data/bosses"):
		if not file.ends_with(".tres"):
			continue
		var def := load("res://data/bosses".path_join(file)) as BossDef
		if def == null:
			continue
		var config: LevelConfig = BossArena.base_config(def)
		check(not config.has_feature(WallGapPlacement.FEATURE), "%s's arena lists no wall gaps" % def.id)
		config.lane_count = 5
		var forced: PackedStringArray = PackedStringArray(config.features)
		forced.append(WallGapPlacement.FEATURE)
		config.features = forced
		var arena: BossArena = BossArena.plan(def, config, tuning)
		for lap: LevelLayout in arena.laps:
			check(lap.wall_gaps.is_empty(), "%s: no wall gap in a lap even with the feature forced" % def.id)
		for step: CampaignStep in campaign.steps():
			if step.is_level() or step.boss != def:
				continue
			var boss_config: LevelConfig = campaign.configure_boss(step, 5)
			check(not boss_config.has_feature(WallGapPlacement.FEATURE), "%s's campaign fight lists no wall gaps" % def.id)


## Task D10b: a level's own numbers (LevelConfig.wall_gap_tuning). Every campaign level has none and places its
## gaps by the shared file, as before; a level built with a copy of the shared numbers is the same level; a
## level's own numbers are the ones it's built by, and they change nothing but its wall gaps (and the wall
## credits a gap takes).
func _test_level_tuning() -> void:
	var shared: WallGapTuning = WallGapPlacement.tuning()
	check(shared.resource_path == WallGapPlacement.TUNING_PATH and not shared.opens_walls(),
		"the shared numbers are %s, with open walls off" % WallGapPlacement.TUNING_PATH)
	check(WallGapPlacement.tuning_for(null) == shared, "no level: the shared numbers")
	for s: CampaignStep in campaign.steps():
		if not s.is_level():
			continue
		if s.zone.id == &"beach":
			check(s.level.wall_gap_tuning != null and s.level.wall_gap_tuning.resource_path == BEACH_WALL_GAPS
				and WallGapPlacement.tuning_for(campaign.configure(s, 5)) == s.level.wall_gap_tuning,
				"%s opens its walls by the Beach's numbers" % s.id)
		else:
			check(s.level.wall_gap_tuning == null and WallGapPlacement.tuning_for(campaign.configure(s, 5)) == shared,
				"%s has no wall-gap numbers of its own: the shared ones" % s.id)
	for id: String in ["gangland/1", "corporate/2"]:
		var config: LevelConfig = campaign.configure(campaign.step(id), 5)
		var patterns: Array = LevelGenerator.load_for(config)
		var base: LevelLayout = LayoutCache.generate(config, tuning, patterns)
		var copy: LevelConfig = config.duplicate() as LevelConfig
		copy.wall_gap_tuning = shared.duplicate() as WallGapTuning
		check(WallGapPlacement.tuning_for(copy) == copy.wall_gap_tuning, "%s: a level's own numbers are the ones it uses" % id)
		var same: LevelLayout = LevelGenerator.new().generate(copy, tuning, patterns)
		check(JSON.stringify(same.to_dict()) == JSON.stringify(base.to_dict()),
			"%s with a copy of the shared numbers of its own is the same level" % id)
		var longer: WallGapTuning = shared.duplicate() as WallGapTuning
		longer.length_seconds_min = 2.5
		longer.length_seconds_max = 2.5
		copy.wall_gap_tuning = longer
		var other: LevelLayout = LevelGenerator.new().generate(copy, tuning, patterns)
		var v: float = config.movement_for(tuning).run_speed
		var exact: bool = not other.wall_gaps.is_empty()
		for g: Dictionary in other.wall_gaps:
			exact = exact and absf(float(g["end"]) - float(g["start"]) - 2.5 * v) < 0.01
		check(exact, "%s: its own numbers place its gaps (all 2.5 s long): %s" % [id, other.wall_gaps.slice(0, 3)])
		var a: Dictionary = other.to_dict()
		var b: Dictionary = base.to_dict()
		for key: String in ["wall_gaps", "credits"]:
			a.erase(key)
			b.erase(key)
		check(JSON.stringify(a) == JSON.stringify(b), "%s: its own numbers change nothing but the wall gaps" % id)
		var kept: bool = true
		for c: Dictionary in other.credits:
			kept = kept and base.credits.has(c)
		check(kept, "%s: they take wall credits away, never add any" % id)


## Open walls (WallGapTuning.coverage_target; task D10b) on made-up 3000 m tracks at the reference speed, at 3, 5
## and 6 lanes:
## - nothing on the walls: each wall opens to its target in long stretches, the second taking what the first
##   left standing, so both walls are open at once only where they meet;
## - signs every 40 m along the left wall: no stretch between them is long enough to open, so that wall stands
##   whole, and the right wall still opens to its target;
## - a target of 0.8 on both walls: at most both_open_max of the track is open on both walls at once;
## - a ceiling over the outer lanes, signs, a wall fence, a window cyborg and a ramp: no gap reaches into what
##   its wall keeps, and a free stretch shorter than open_seconds_min stays standing.
## The same tracks with the shared numbers get the rare short gaps (open walls off).
func _test_open_walls() -> void:
	for lanes: int in [3, 5, 6]:
		var tag: String = "(%d lanes)" % lanes
		var open: WallGapTuning = WallGapPlacement.tuning().duplicate() as WallGapTuning
		open.coverage_target = 0.5
		open.open_seconds_min = 2.0
		open.solid_seconds_min = 2.0
		open.both_open_max = 0.3
		# Nothing on the walls.
		var gen: LevelGenerator = _open_walls_track(lanes, open, [])
		var length: float = gen.layout.length
		for side: int in [-1, 1]:
			var spans: Array[Vector2] = gen.layout.wall_gap_spans(side, -INF, INF)
			var stands: float = 1.0 - WallGapPlacement.span_total(spans) / length
			check(absf(stands - 0.5) < 0.01, "an empty wall %d stands on its target half (%.3f) %s" % [side, stands, tag])
			check(spans.size() == 1, "in one long open stretch %s: %s" % [tag, spans])
		var both: float = WallGapPlacement.span_total(WallGapPlacement.spans_overlap(
			gen.layout.wall_gap_spans(-1, -INF, INF), gen.layout.wall_gap_spans(1, -INF, INF))) / length
		check(both < 0.1, "the second wall keeps what the first left standing: %.0f%% open on both %s" % [both * 100.0, tag])
		_check_open_walls(gen, open, tag + " empty")
		var rare: LevelGenerator = _open_walls_track(lanes, null, [])
		var short: bool = not rare.layout.wall_gaps.is_empty()
		for g: Dictionary in rare.layout.wall_gaps:
			short = short and float(g["end"]) - float(g["start"]) <= WallGapPlacement.tuning().length_seconds_max * rare.speed + 0.01
		check(short, "the shared numbers on the same track: the rare short gaps %s" % tag)
		# Signs every 40 m on the left wall.
		var signs: Array[Dictionary] = []
		var at: float = 50.0
		while at < 3000.0:
			signs.append({"kind": "sign", "side": -1, "start": at, "end": at + 6.0})
			at += 40.0
		gen = _open_walls_track(lanes, open, signs)
		check(gen.layout.wall_gap_spans(-1, -INF, INF).is_empty(), "a wall with no free stretch long enough stands whole %s" % tag)
		var right: float = 1.0 - WallGapPlacement.span_total(gen.layout.wall_gap_spans(1, -INF, INF)) / length
		check(absf(right - 0.5) < 0.01, "the other wall still opens to its target (%.3f) %s" % [right, tag])
		_check_open_walls(gen, open, tag + " signs")
		# A target of 0.8 on both walls: both open at once on at most both_open_max of the track.
		var wide: WallGapTuning = open.duplicate() as WallGapTuning
		wide.coverage_target = 0.8
		gen = _open_walls_track(lanes, wide, [])
		both = WallGapPlacement.span_total(WallGapPlacement.spans_overlap(gen.layout.wall_gap_spans(-1, -INF, INF),
			gen.layout.wall_gap_spans(1, -INF, INF)))
		check(both <= wide.both_open_max * length + 0.01 and both >= wide.both_open_max * length - 2.0 * wide.open_seconds_min * gen.speed,
			"both walls open at once on at most both_open_max of the track (%.0f of %.0f m) %s" % [both, wide.both_open_max * length, tag])
		_check_open_walls(gen, wide, tag + " wide")
		# Pieces on the walls: nothing opens into what a wall keeps, nor a free stretch too short to open.
		var pieces: Array[Dictionary] = [
			{"kind": "hull", "start": 400.0, "end": 480.0},
			{"kind": "sign", "side": 1, "start": 900.0, "end": 908.0},
			{"kind": "sign", "side": 1, "start": 940.0, "end": 948.0},
			{"kind": "wall_fence", "side": -1, "at": 1300.0},
			{"kind": "enemy", "side": 1, "at": 1700.0},
			{"kind": "ramp", "side": -1, "at": 2100.0},
		]
		gen = _open_walls_track(lanes, open, pieces)
		check(gen.layout.wall_supported(1, 924.0), "a free stretch shorter than open_seconds_min stands %s" % tag)
		check(gen.layout.wall_supported(-1, 440.0) and gen.layout.wall_supported(1, 440.0), "a ceiling over the outer lanes keeps both walls %s" % tag)
		_check_open_walls(gen, open, tag + " pieces")


## A made-up level with the wall_gaps feature, `tuning`'s own wall-gap numbers (null: the shared ones), a 3000 m
## track and `pieces` on it ({kind: hull | sign | wall_fence | enemy | ramp, ...}), with its wall gaps placed.
func _open_walls_track(lanes: int, own: WallGapTuning, pieces: Array[Dictionary]) -> LevelGenerator:
	var config := LevelConfig.new()
	config.id = &"open_walls"
	config.lane_count = lanes
	config.features = PackedStringArray([WallGapPlacement.FEATURE])
	config.wall_gap_tuning = own
	var layout: LevelLayout = RunSim.layout(lanes, 3000.0)
	for p: Dictionary in pieces:
		match String(p["kind"]):
			"hull":
				layout.hulls.append({"start": float(p["start"]), "end": float(p["end"])})
			"sign":
				layout.signs.append({"side": int(p["side"]), "start": float(p["start"]), "end": float(p["end"]),
					"lanes": [layout.outer_lane(int(p["side"]))]})
			"wall_fence":
				layout.wall_fences.append({"side": int(p["side"]), "at": float(p["at"]), "band": "full",
					"pulse_on": 1.0, "pulse_off": 1.5, "phase": 0.0})
			"enemy":
				layout.enemies.append({"type": "window_cyborg", "at": float(p["at"]), "lane": 0, "side": int(p["side"]),
					"seed": 1, "params": {}})
			"ramp":
				layout.ramps.append({"side": int(p["side"]), "at": float(p["at"])})
	var gen: LevelGenerator = LevelGenerator.for_layout(config, tuning, layout)
	WallGapPlacement.place(gen)
	return gen


## Open walls' rules on `gen`'s layout, with numbers `t`: each gap at least open_seconds_min long and clear of
## its wall's keep-outs, between the run-up and the end-clear stretch; gaps on a wall never touch; each wall
## open on no more than its target (and a step's worth), both walls at once on no more than both_open_max.
func _check_open_walls(gen: LevelGenerator, t: WallGapTuning, tag: String) -> void:
	var layout: LevelLayout = gen.layout
	var min_open: float = t.open_seconds_min * gen.speed
	var spans: Array = []
	for side: int in [-1, 1]:
		var mine: Array[Vector2] = layout.wall_gap_spans(side, -INF, INF)
		spans.append(mine)
		var keeps: Array[Vector2] = WallGapPlacement.keep_outs(gen, layout, side, t)
		var prev: float = -INF
		for g: Vector2 in mine:
			check(g.y - g.x >= min_open - 0.01, "an open stretch at least open_seconds_min long (%.1f m) %s" % [g.y - g.x, tag])
			check(g.x >= gen.config.start_clear_distance and g.y <= layout.length - gen.config.end_clear_distance,
				"open between the run-up and the end-clear stretch %s" % tag)
			check(g.x > prev + 0.01, "gaps on a wall never touch %s" % tag)
			prev = g.y
			for kp: Vector2 in keeps:
				check(not (g.x < kp.y - 0.01 and g.y > kp.x + 0.01), "gap %s clear of keep-out %s %s" % [g, kp, tag])
		check(WallGapPlacement.span_total(mine) <= t.coverage_target * layout.length + 0.01,
			"wall %d open on no more than its target %s" % [side, tag])
	var both: float = WallGapPlacement.span_total(WallGapPlacement.spans_overlap(spans[0], spans[1]))
	check(both <= t.both_open_max * layout.length + 0.01, "both walls open at once within both_open_max %s" % tag)
