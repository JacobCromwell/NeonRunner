extends TestSuite
## First-encounter hints are collected before play, acknowledged by the intro and never emitted
## by runtime encounters. Existing keys, touch wording and profile history are retained.


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
	check(not profile.has_seen("hint/gap"), "preparing the intro does not consume hints")
	hints.acknowledge(hints.intro_hints)
	var before_run: int = shown.size()
	await sim.step_world(world, 5.5)
	check(shown.size() == before_run, "no hint is emitted in the middle of a run")
	var ids: Array = shown.map(func(s: Array) -> String: return s[0])
	check(ids.has("lanes") and ids.has("gap") and ids.has("fence_gapped"), "the start, gap and gapped-fence hints show (%s)" % [ids])
	check(not ids.has("pad") and not ids.has("fence"), "hints for things the level doesn't have stay hidden")
	for s: Array in shown:
		if s[0] == "gap":
			check(is_zero_approx(float(s[2])), "the gap hint is available before the run")
			var keys: String = " / ".join(Settings.key_names(&"jump"))
			check(String(s[1]).contains(keys) and not String(s[1]).contains("{"), "the text names the player's jump keys (%s)" % s[1])
	check(profile.has_seen("hint/gap"), "a shown hint is remembered")
	profile = Profile.from_dict(profile.to_dict())
	check(profile.has_seen("hint/gap"), "intro hint history survives save serialization")
	await sim.free_world(world)

	# The same profile never sees them again; touch players read gestures.
	var world2: RunWorld = sim.build_world(layout)
	var again := HintDirector.new()
	world2.add_child(again)
	again.setup(world2, profile, true)
	var shown2: Array = []
	again.hint_shown.connect(func(id: String, _t: String) -> void: shown2.append(id))
	again.acknowledge(again.intro_hints)
	await sim.step_world(world2, 5.5)
	check(shown2.is_empty(), "hints show only once per profile (%s)" % [shown2])
	check(again.format_text("Jump with {jump}") == "Jump with swipe up", "touch players read gestures")
	var rebound := InputEventKey.new()
	rebound.physical_keycode = KEY_J
	Settings.bind_key(profile, &"jump", rebound)
	again.touch = false
	check(again.format_text("Jump with {jump}").contains("J"), "intro text uses rebound action keys")
	InputMap.load_from_project_settings()
	await sim.free_world(world2)
	await _test_late_feature(sim)
	_test_campaign_relevance()
	_test_settings_and_acknowledgement()


## City 1's late cyborg hint moves to the intro too, without changing its scheduled encounter.
func _test_late_feature(sim: RunSim) -> void:
	var campaign := load("res://data/campaign/campaign.tres") as Campaign
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
		var ids: Array = hints.intro_hints.map(func(entry: Dictionary) -> String: return entry["id"])
		check(ids.has("cyborg"), "the late cyborg's hint is available on the intro " + tag)
		var shown: Array[String] = []
		hints.hint_shown.connect(func(id: String, _text: String) -> void: shown.append(id))
		world.director.update(cyborgs[0])
		check(shown.is_empty(), "spawning the cyborg never interrupts play " + tag)
		await sim.free_world(world)


func _test_campaign_relevance() -> void:
	var campaign := load("res://data/campaign/campaign.tres") as Campaign
	var expected: Dictionary = {
		"city/2": ["pad"],
		"city/3": ["pulsing", "window_cyborg", "hover_truck"],
		"gangland/1": ["ramp", "screech", "wall_gap"],
		"gangland/2": ["octodog", "speed_pad"],
		"gangland/3": ["generator", "drone"],
		"marketplace/1": ["barnacle_turret"],
		"marketplace/2": ["wall_fence"],
		"corporate/1": ["buzz_overdrive", "wall_fence_low", "wall_fence_high"],
		"corporate/2": ["tithe_collector"],
		"dead_zone/1": ["host", "bad_dream"],
		"golden/1": ["resonator"],
		"golden/2": ["gilded_sentinel"],
	}
	var profile := Profile.new()
	for step: CampaignStep in campaign.steps():
		# A mini-game level's own hint (the Beach's volleyball match) is test_volleyball's: its track isn't generated.
		if not step.is_level() or step.is_minigame():
			continue
		var config: LevelConfig = campaign.configure(step, 3)
		var world := RunWorld.new()
		world.config = config
		world.layout = LayoutCache.generate(config, tuning, LevelGenerator.load_for(config))
		world.director = EnemyDirector.new()
		world.add_child(world.director)
		var ctx := RunContext.new()
		ctx.mode = RunContext.Mode.CAMPAIGN
		ctx.step = step
		ctx.config = config
		ctx.level_index = step.level_index
		var director := HintDirector.new()
		director.setup(world, profile, false, ctx)
		var ids: Array = director.intro_hints.map(func(entry: Dictionary) -> String: return entry["id"])
		for id: String in expected.get(step.id, []):
			check(ids.has(id), "%s introduces %s from its actual config/layout (%s)" % [step.id, id, ids])
		check(not ids.has("boss") and not ids.has("pickup_armor") and not ids.has("pickup_shield") \
			and not ids.has("pickup_grapple"), "%s has no unrelated boss/pickup hints" % step.id)
		if step.zone.id == &"golden":
			check(not ids.has("octodog"), "%s has no removed octodog hint" % step.id)
			for enemy: Dictionary in world.layout.enemies:
				check(String(enemy["type"]) != "octodog", "%s has no octodog encounter" % step.id)
		director.acknowledge(director.intro_hints)
		# A fresh profile jumping ahead still sees this level's new content first, not random
		# enemies or the lane-control primer. Older relevant unseen content remains recoverable.
		director.setup(world, Profile.new(), false, ctx)
		ids = director.intro_hints.map(func(entry: Dictionary) -> String: return entry["id"])
		if step.level_index > 0:
			check(not ids.has("lanes"), "%s does not repeat the start primer" % step.id)
		var introduced: Array = expected.get(step.id, [])
		if not introduced.is_empty():
			check(introduced.has(ids[0]), "%s prioritizes its newly introduced content (%s)" % [step.id, ids])
		director.free()
		world.free()


func _test_settings_and_acknowledgement() -> void:
	var world := RunWorld.new()
	world.config = LevelConfig.new()
	world.layout = RunSim.layout(3)
	world.layout.gaps.append({"lane": 0, "start": 60.0, "end": 64.0})
	world.director = EnemyDirector.new()
	world.add_child(world.director)
	var profile := Profile.new()
	var director := HintDirector.new()
	profile.settings["hints"] = false
	director.setup(world, profile, false)
	check(director.intro_hints.is_empty(), "Hints off prevents selection and history consumption")
	profile.settings["hints"] = true
	director.setup(world, profile, false)
	var first: Array[Dictionary] = [director.intro_hints[0]]
	director.acknowledge([{"id": "octodog", "text": "not selected"}])
	check(not profile.has_seen("hint/octodog"), "unselected entries cannot enter hint history")
	director.acknowledge(first)
	check(profile.has_seen("hint/lanes") and not profile.has_seen("hint/gap"), "only acknowledged pages enter history")
	director.setup(world, profile, false)
	check(director.intro_hints.size() == 1 and director.intro_hints[0]["id"] == "gap",
		"replay offers the unpresented relevant page")
	profile.settings["hints"] = false
	director.acknowledge(director.intro_hints)
	check(not profile.has_seen("hint/gap"), "Hints off also guards acknowledgement")
	director.free()
	world.free()
