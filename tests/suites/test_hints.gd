extends TestSuite
## First-encounter hints: shown once per profile, just before the first matching piece, with the
## player's own keys or touch gestures in the text.


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
