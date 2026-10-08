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
##   boss arena have none, and a level is otherwise the same without the feature; the one exception is
##   an arena that opts in with numbers of its own (LevelConfig.wall_gap_tuning: the Sleep Taker's, owner,
##   October 8, 2026), which gets many, by its numbers, clear of the same keep-outs, every lap keeping
##   them as it joins the track.

const WITH: Array = ["gangland/1", "gangland/2", "gangland/3", "marketplace/1", "marketplace/2", "corporate/1",
	"corporate/2", "dead_zone/1", "dead_zone/2", "golden/1", "golden/2", "golden/3"]
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
	var t: WallGapTuning = WallGapPlacement.tuning()
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


## Every boss arena: no gaps, even if its config were to list the feature, unless it opts in with numbers
## of its own (the Sleep Taker's: _test_opted_in).
func _test_bosses() -> void:
	var opted: int = 0
	for file: String in DirAccess.get_files_at("res://data/bosses"):
		if not file.ends_with(".tres"):
			continue
		var def := load("res://data/bosses".path_join(file)) as BossDef
		if def == null:
			continue
		if def.arena != null and def.arena.wall_gap_tuning != null:
			opted += 1
			_test_opted_in(def)
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
	check(opted == 1, "only the Sleep Taker's arena opts into wall gaps (%d)" % opted)


## The Sleep Taker's arena (owner, October 8, 2026: "the walls aren't safe"): it keeps the feature with
## numbers of its own, in quick play and in the campaign; at 3, 5 and 6 lanes its laps (as the fight plans
## them, refuges and all) have many gaps, far more than a level, each as long as its numbers say and clear
## of every keep-out a level's keeps (by its numbers), the same on every attempt, and a lap joining the
## track later keeps them.
func _test_opted_in(def: BossDef) -> void:
	var t: WallGapTuning = def.arena.wall_gap_tuning
	check(def.arena.has_feature(WallGapPlacement.FEATURE) and BossArena.base_config(def).has_feature(WallGapPlacement.FEATURE)
		and WallGapPlacement.tuning_for(BossArena.base_config(def)) == t, "%s's arena opts in with numbers of its own" % def.id)
	for step: CampaignStep in campaign.steps():
		if not step.is_level() and step.boss == def:
			var boss_config: LevelConfig = campaign.configure_boss(step, 5)
			check(boss_config.has_feature(WallGapPlacement.FEATURE) and boss_config.wall_gap_tuning == t,
				"%s's campaign fight keeps them" % def.id)
	for lanes: int in [3, 5, 6]:
		var tag: String = "(%s, %d lanes)" % [def.id, lanes]
		var config: LevelConfig = BossArena.base_config(def)
		config.lane_count = lanes
		var plans: Array[String] = []
		var arena: BossArena = null
		for attempt: int in 2:
			var encounter: BossEncounter = BossEncounter.create(def)
			encounter.def = def
			arena = BossArena.plan(def, config, tuning, encounter)
			encounter.free()
			var all: Array = []
			for lap: LevelLayout in arena.laps:
				all.append(lap.wall_gaps)
			plans.append(JSON.stringify(all))
		check(plans[0] == plans[1], "the same gaps every attempt %s" % tag)
		var count: int = 0
		var sized: bool = true
		var clear: bool = true
		for lap: LevelLayout in arena.laps:
			var gen: LevelGenerator = LevelGenerator.for_layout(config, tuning, lap)
			for g: Dictionary in lap.wall_gaps:
				count += 1
				var secs: float = (float(g["end"]) - float(g["start"])) / tuning.run_speed
				sized = sized and secs >= t.length_seconds_min - 0.01 and secs <= t.length_seconds_max + 0.01
			for side: int in [-1, 1]:
				for kp: Vector2 in WallGapPlacement.keep_outs(gen, lap, side, t):
					for g: Dictionary in lap.wall_gaps:
						if int(g["side"]) == side and float(g["start"]) < kp.y - 0.01 and float(g["end"]) > kp.x + 0.01:
							clear = false
		var a_minute: float = count / (arena.laps.size() * arena.lap_length / tuning.run_speed / 60.0)
		check(a_minute >= 8.0, "many wall gaps: %.1f a minute (a level's median is under 3.5) %s" % [a_minute, tag])
		check(sized, "each lasts %.1f-%.1f s %s" % [t.length_seconds_min, t.length_seconds_max, tag])
		check(clear, "each clear of every keep-out (the refuges' bridges, the run-up, the end) %s" % tag)
		var joined: LevelLayout = arena.lap(arena.laps.size())
		check(joined.wall_gaps.size() == arena.laps[0].wall_gaps.size() and not joined.wall_gaps.is_empty()
			and is_equal_approx(float(joined.wall_gaps[0]["start"]), float(arena.laps[0].wall_gaps[0]["start"]) + arena.lap_length * arena.laps.size()),
			"a lap joining the track later keeps its gaps, moved along %s" % tag)
