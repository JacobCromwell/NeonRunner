extends TestSuite
## First-encounter hints: shown once per profile, just before the first matching piece, with the
## player's own keys or touch gestures in the text; for a feature that starts late in a level (City
## 1's cyborgs), just before the player first meets it rather than at the level's start.


func run() -> void:
	var sim := RunSim.new(tree, tuning)
	var layout := RunSim.layout(3)
	layout.gaps.append({"lane": 0, "start": 60.0, "end": 64.0})
	layout.fences.append(RunSim.fence(2, 90.0, "gapped"))
	var world: RunWorld = sim.build_world(layout)
	var profile := Profile.new()
	var hints := HintDirector.new()
	world.add_child(hints)
	hints.setup(world, profile, false)
	var shown: Array = []
	hints.hint_shown.connect(func(id: String, text: String) -> void: shown.append([id, text, world.player.distance]))
	await sim.step_world(world, 5.5)
	var ids: Array = shown.map(func(s: Array) -> String: return s[0])
	check(ids.has("lanes") and ids.has("gap") and ids.has("fence_gapped"), "the start, gap and gapped-fence hints show (%s)" % [ids])
	check(not ids.has("pad") and not ids.has("fence"), "hints for things the level doesn't have stay hidden")
	for s: Array in shown:
		if s[0] == "gap":
			check(float(s[2]) < 60.0 and float(s[2]) > 60.0 - tuning.run_speed * 2.5, "the gap hint shows shortly before the gap (%.1f m)" % s[2])
			var keys: String = " / ".join(Settings.key_names(&"jump"))
			check(String(s[1]).contains(keys) and not String(s[1]).contains("{"), "the text names the player's jump keys (%s)" % s[1])
	check(profile.has_seen("hint/gap"), "a shown hint is remembered")
	await sim.free_world(world)

	# The same profile never sees them again; touch players read gestures.
	var world2: RunWorld = sim.build_world(layout)
	var again := HintDirector.new()
	world2.add_child(again)
	again.setup(world2, profile, true)
	var shown2: Array = []
	again.hint_shown.connect(func(id: String, _t: String) -> void: shown2.append(id))
	await sim.step_world(world2, 5.5)
	check(shown2.is_empty(), "hints show only once per profile (%s)" % [shown2])
	check(again.format_text("Jump with {jump}") == "Jump with swipe up", "touch players read gestures")
	await sim.free_world(world2)
	await _test_late_feature(sim)


## City 1 brings its cyborgs late in the level (GDD §5, LevelConfig.feature_starts). Walking the
## level's enemy director along the track, the cyborg hint shows as the first cyborg comes into play,
## a few seconds before the player reaches it, and nothing of the kind comes earlier.
func _test_late_feature(sim: RunSim) -> void:
	var campaign := load("res://data/campaign/campaign.tres") as Campaign
	var lead: float = EnemyDirector.lead_for("cyborg")
	for lanes: int in [3, 5, 6]:
		var config: LevelConfig = campaign.configure(campaign.step("city/1"), lanes)
		# T-SPEED: City 1's own default build (LayoutCache), shared with other suites.
		var layout: LevelLayout = LayoutCache.generate(config, tuning, LevelGenerator.load_for(config))
		var cyborgs: Array[float] = LayoutChecks.feature_positions(layout, "cyborg")
		var start: float = config.feature_start("cyborg") * layout.length
		var tag: String = "(%d lanes)" % lanes
		check(not cyborgs.is_empty() and cyborgs[0] >= start, "City 1's first cyborg comes after the start of its feature " + tag)
		if cyborgs.is_empty():
			continue
		var world: RunWorld = sim.build_world(layout, null, null, config)
		var hints := HintDirector.new()
		world.add_child(hints)
		hints.setup(world, Profile.new(), false)
		var state := {"d": 0.0, "at": -1.0}
		hints.hint_shown.connect(func(id: String, _text: String) -> void:
			if id == "cyborg" and float(state["at"]) < 0.0:
				state["at"] = state["d"])
		var d: float = 0.0
		while d <= layout.length and float(state["at"]) < 0.0:
			state["d"] = d
			world.director.update(d)
			d += 1.0
		var shown: float = state["at"]
		check(shown >= start - lead and shown <= cyborgs[0],
			"the cyborg hint shows as the first cyborg comes into play (%.0f m; first cyborg %.0f m, start %.0f m) %s" % [
				shown, cyborgs[0], start, tag])
		check(cyborgs[0] - shown <= lead + 1.0 and (cyborgs[0] - shown) / tuning.run_speed >= 3.0,
			"a few seconds before the player meets it (%.1f s) %s" % [(cyborgs[0] - shown) / tuning.run_speed, tag])
		await sim.free_world(world)
