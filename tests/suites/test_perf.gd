extends TestSuite
## Task PERF1 (the owner's "lag spikes are more common", October 2, 2026): what keeps a run's frames
## smooth, and that none of it changes what the game decides.
## - A chunk's dressing spread over frames (TrackBuilder.dress_budget_usec): its gameplay nodes are all
##   built in its frame as before, its look is the same once dressed, every chunk is dressed before the
##   player is DRESS_BY from it, a chunk freed before it was dressed is skipped, and a seeded run plays
##   out the same with and without it (the runner's trace and the enemies' event log).
## - Enemy types readied with the level (EnemyDirector.warm_up): every type's script loaded, each kind's
##   look built and freed once a process (and skin) with nothing left in the tree and nothing heard, a
##   host's Bad Dream among them, warm_looks() handing out one look of each kind, their materials kept
##   (so their shaders stay built), and a Gilded Sentinel's statue frames baked for both walls with each
##   Golden skin's own kit.
## - Hit-stops that never stack or chain (RunEffects.freeze, SpeedFxTuning.freeze_gap).
## - BossProps' target rings shared by radius.
## - The shader warm-up stage (ShaderWarmup): samples of the hidden materials, the effects' glow, every
##   enemy kind's look and each track piece, nothing in it colliding, lit or out of its tiny space, and no
##   physics object made or freed by a warm-up (the stage's track holders are made once and reused; the
##   enemy looks have none).
## - The frame monitor's tags, holds and summaries, and the frame graph's spikes and holds.

const AttackWatch = preload("res://tools/measure/attack_watch.gd")
const DUMMY: String = "res://tests/helpers/dummy_enemy.gd"
## The enemy kinds whose scripts give a warm_up look, as layout entries.
const WARM_ENTRIES: Array[Dictionary] = [
	{"type": "cyborg", "at": 400.0, "lane": 1, "seed": 3, "params": {}},
	{"type": "cyborg", "at": 420.0, "lane": 1, "seed": 4, "params": {"host": true}},
	{"type": "window_cyborg", "at": 440.0, "lane": 0, "side": 1, "seed": 5, "params": {}},
	{"type": "screech", "at": 460.0, "lane": 0, "side": -1, "seed": 6, "params": {"source": "vent"}},
	{"type": "octodog", "at": 480.0, "lane": 1, "seed": 7, "params": {}},
	{"type": "resonator", "at": 500.0, "lane": 1, "seed": 8, "params": {}},
	{"type": "barnacle_turret", "at": 520.0, "lane": 1, "seed": 9, "params": {}},
	{"type": "generator", "at": 540.0, "lane": 2, "seed": 10, "params": {}},
	{"type": "buzz_overdrive", "at": 560.0, "lane": 1, "seed": 11, "params": {}},
	{"type": "gilded_sentinel", "at": 580.0, "lane": 0, "side": 1, "seed": 12, "params": {}},
	{"type": "tithe_collector", "at": 600.0, "lane": 1, "seed": 13, "params": {}},
	{"type": "enforcer_truck", "at": 620.0, "lane": 1, "seed": 14, "params": {}},
]

var sim: RunSim
var campaign: Campaign


func run() -> void:
	sim = RunSim.new(tree, tuning)
	campaign = load("res://data/campaign/campaign.tres") as Campaign
	await _test_dressing_spread()
	await _test_dressing_freed_chunk()
	await _test_dressing_keeps_the_game()
	await _test_enemy_warm_up()
	await _test_sentinel_frames()
	await _test_freeze_never_chains()
	_test_boss_props_share_rings()
	await _test_shader_warmup()
	await _test_frame_monitor()
	_test_frame_graph()
	_test_summaries()


## A campaign level's layout and config, as the App builds it (`id`, 5 lanes).
func _level(id: String) -> Array:
	var config: LevelConfig = campaign.configure(campaign.step(id), 5)
	var t: MovementTuning = config.movement_for(tuning)
	return [config, LevelGenerator.new().generate(config, t, LevelGenerator.load_for(config)), t]


## Nodes under `root` of the engine class `cls` (and its subclasses).
static func _count(root: Node, cls: String) -> int:
	return root.find_children("*", cls, true, false).size()


## Nodes under `root` with the script class `script` (find_children only knows engine classes).
static func _count_script(root: Node, script: Script) -> int:
	var n: int = 0
	for node: Node in root.find_children("*", "", true, false):
		var s: Script = node.get_script() as Script
		while s != null:
			if s == script:
				n += 1
				break
			s = s.get_base_script()
	return n


# --- Spreading a chunk's dressing -----------------------------------------------------------------

## The same chunks built at once and spread: the same gameplay nodes in each chunk's frame, the same look
## once dressed, each dressed in time, and nothing queued without a budget.
func _test_dressing_spread() -> void:
	var level: Array = _level("marketplace/2")
	var layout: LevelLayout = level[1]
	var t: MovementTuning = level[2]
	var skin: ZoneSkin = (level[0] as LevelConfig).skin
	var holder := Node3D.new()
	tree.root.add_child(holder)
	var at_once := TrackBuilder.new()
	var spread := TrackBuilder.new()
	holder.add_child(at_once)
	holder.add_child(spread)
	# Each its own copy of the skin (a skin notes a side's wall enemies just before drawing that side).
	at_once.set_layout(layout, t, skin.duplicate() as ZoneSkin)
	spread.set_layout(_level("marketplace/2")[1], t, skin.duplicate() as ZoneSkin)
	at_once.update(0.0, 0.0)
	spread.update(0.0, 0.0)
	spread.dress_budget_usec = 1000
	var same_gameplay: bool = true
	var queued: bool = false
	var late: Array[String] = []
	var never_queued: bool = true
	var d: float = 0.0
	var step: float = t.run_speed / 60.0
	var frame: int = 0
	while d < 1500.0:
		d += step
		frame += 1
		if frame % 60 == 0:
			await tree.process_frame  # the chunks freed behind go
		at_once.update(d, d / t.run_speed)
		spread.update(d, d / t.run_speed)
		never_queued = never_queued and at_once.dressing_left() == 0
		queued = queued or spread.dressing_left() > 0
		for item: Array in spread.get(&"_dressing"):
			if float(item[0]) < d + TrackBuilder.DRESS_BY:
				late.append("%.0f at %.0f" % [float(item[0]), d])
		if at_once.get_child_count() != spread.get_child_count():
			same_gameplay = false
		elif spread.dressing_left() > 0 and (_count(at_once, "CollisionObject3D") != _count(spread, "CollisionObject3D")
				or _count(at_once, "CollisionShape3D") != _count(spread, "CollisionShape3D")):
			same_gameplay = false
	check(queued, "with a budget, a chunk's look waits in the queue")
	check(never_queued, "without a budget, every chunk is dressed in its frame (nothing queued)")
	check(same_gameplay, "a chunk's gameplay nodes (collision, hazards, triggers) are all built in its frame either way")
	check(late.is_empty(), "every chunk is dressed before the player is DRESS_BY from it (%s)" % ", ".join(late.slice(0, 4)))
	spread.dress_all()
	check(spread.dressing_left() == 0, "dress_all() dresses everything left")
	var looks_a: int = _count(at_once, "GeometryInstance3D")
	var looks_b: int = _count(spread, "GeometryInstance3D")
	check(looks_a > 0 and looks_a == looks_b, "once dressed, the chunks look the same (%d and %d drawn nodes)" % [looks_a, looks_b])
	holder.queue_free()
	await tree.process_frame


## A chunk freed before its look came (a test or a tool jumping far ahead) is skipped without errors.
func _test_dressing_freed_chunk() -> void:
	var level: Array = _level("corporate/1")
	var t: MovementTuning = level[2]
	var holder := Node3D.new()
	tree.root.add_child(holder)
	var track := TrackBuilder.new()
	holder.add_child(track)
	track.set_layout(level[1], t, (level[0] as LevelConfig).skin)
	track.update(0.0, 0.0)
	track.dress_budget_usec = 1
	track.update(250.0, 10.0)
	var waiting: int = track.dressing_left()
	var counter := SkinSuite.ErrorCounter.new()
	OS.add_logger(counter)
	track.update(1200.0, 50.0)
	await tree.process_frame
	track.update(1201.0, 50.0)
	track.dress_all()
	OS.remove_logger(counter)
	check(waiting > 0, "a chunk built with a tiny budget waits to be dressed (%d calls)" % waiting)
	check(counter.errors.is_empty() and track.dressing_left() == 0,
		"the calls of chunks freed before they were dressed are skipped without errors: %s" % "; ".join(counter.errors.slice(0, 3)))
	holder.queue_free()
	await tree.process_frame


## A seeded run on a campaign level with its enemies plays out the same with every chunk dressed at once
## and with the dressing spread: the runner's trace, its events and the enemies' event log.
func _test_dressing_keeps_the_game() -> void:
	var runs: Array[Dictionary] = []
	for budget: int in [0, 1000, 1]:
		var level: Array = _level("gangland/2")
		var world := sim.build_world(level[1], Loadout.full(App.catalog), level[2], level[0])
		world.player.god_mode = true
		world.player.grapples = 1_000_000
		world.track.dress_budget_usec = budget
		var watch := AttackWatch.new(world)
		var trace := PackedStringArray()
		var events := PackedStringArray()
		world.player.movement_event.connect(func(kind: StringName) -> void: events.append("%.3f %s" % [world.level_time(), kind]))
		world.director.enemy_defeated.connect(func(e: Enemy, cause: StringName) -> void:
			events.append("%.3f kill %s %s" % [world.level_time(), e.type_id, cause]))
		await tree.physics_frame
		world.start()
		var rng := RandomNumberGenerator.new()
		rng.seed = 11
		for i: int in 30 * 60:
			if i % 40 == 0:
				world.player.press([&"move_left", &"move_right", &"jump", &"slide"][rng.randi_range(0, 3)])
			await tree.physics_frame
			watch.observe()
			if i % 30 == 0:
				trace.append("%.3f %.4f %d %d %.4f" % [world.level_time(), world.player.distance, world.player.lane,
					world.player.surface, world.player.h])
		runs.append({"trace": trace, "events": events, "log": watch.log_hash(), "kills": events.size()})
		await sim.free_world(world)
	for i: int in [1, 2]:
		var tag: String = "a budget of %d µs" % [0, 1000, 1][i]
		check(runs[i]["trace"] == runs[0]["trace"], "the runner's trace is the same with %s" % tag)
		check(runs[i]["events"] == runs[0]["events"], "the runner's events and the kills are the same with %s (%d)" % [tag,
			(runs[0]["events"] as PackedStringArray).size()])
		check(runs[i]["log"] == runs[0]["log"], "the enemies' event log is the same with %s" % tag)


# --- Readying enemy types -------------------------------------------------------------------------

func _test_enemy_warm_up() -> void:
	var layout := RunSim.layout(5, 800.0)
	for e: Dictionary in WARM_ENTRIES:
		layout.enemies.append(e.duplicate(true))
	var config := LevelConfig.new()
	config.skin = load("res://data/skins/gangland_skin.tres") as ZoneSkin
	var world := sim.build_world(layout, null, null, config)
	var director: EnemyDirector = world.director
	# Again, from scratch: what this process readied before doesn't count here.
	EnemyDirector._warmed.clear()
	EnemyDirector._kept.clear()
	var heard: Array[StringName] = []
	world.sounds.requested.connect(func(sound: StringName) -> void: heard.append(sound))
	var nodes_before: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var children_before: int = director.get_child_count()
	director.warm_up()
	var missing: PackedStringArray = []
	for e: Dictionary in WARM_ENTRIES + [{"type": "bad_dream"}]:
		var key: String = director.warm_key(e)
		if not EnemyDirector._warmed.has(key):
			missing.append(key)
	check(missing.is_empty(), "every kind the level brings is readied, a host's Bad Dream too (missing: %s)" % ", ".join(missing))
	var unloaded: PackedStringArray = []
	for e: Dictionary in director.warm_entries():
		if not EnemyDirector._scripts.has(String(e["type"])) or EnemyDirector._scripts[String(e["type"])] == null:
			unloaded.append(String(e["type"]))
	check(unloaded.is_empty() and director.warm_entries().size() == 13,
		"each type's script is loaded with the level (%d kinds; not loaded: %s)" % [director.warm_entries().size(), ", ".join(unloaded)])
	check(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)) == nodes_before and director.get_child_count() == children_before
		and director.active.is_empty(), "nothing it built stays: no node in the tree, no enemy in play")
	check(heard.is_empty(), "nothing is heard while it readies them (%s)" % ", ".join(heard))
	check(EnemyDirector._kept.size() >= 13, "the looks' materials are kept, so their shaders stay built (%d)" % EnemyDirector._kept.size())
	var count: int = EnemyDirector._warmed.size()
	director.warm_up()
	check(EnemyDirector._warmed.size() == count, "once a process: a second level with the same kinds readies nothing again")
	var looks: Array[Node] = director.warm_looks()
	var empty: int = 0
	var physics: PackedStringArray = []
	for look: Node in looks:
		if look.is_inside_tree() or _count(look, "GeometryInstance3D") == 0:
			empty += 1
		if _count(look, "CollisionObject3D") > 0 or look is CollisionObject3D:
			physics.append(String(look.name))
		look.free()
	check(physics.is_empty(), "a look has no physics object (freeing one would reorder later contacts): %s" % ", ".join(physics))
	check(looks.size() == 13 and empty == 0, "warm_looks() gives one look of each kind, built outside the tree (%d, %d empty)" % [
		looks.size(), empty])
	await sim.free_world(world)


## A Gilded Sentinel's statue frames come with the level for both walls, with the skin's own kit: the
## Golden Zone's and the Golden Palace's share a zone look, not their statues, so each readies its own.
func _test_sentinel_frames() -> void:
	EnemyDirector._warmed.clear()
	GildedSentinel._frames.clear()
	var tune := EnemyDirector.tuning_for("gilded_sentinel") as GildedSentinelTuning
	for path: String in ["res://data/skins/golden_skin.tres", "res://data/skins/golden_palace_skin.tres"]:
		var layout := RunSim.layout(5, 800.0)
		layout.enemies.append({"type": "gilded_sentinel", "at": 400.0, "lane": 0, "side": -1, "seed": 1, "params": {}})
		var config := LevelConfig.new()
		config.skin = load(path) as ZoneSkin
		var world := sim.build_world(layout, null, null, config)
		var kit: GoldenStatue = (config.skin as GoldenSkin).statues()
		var walls: int = 0
		for mirrored: bool in [false, true]:
			if GildedSentinel._frames.has([kit.get_instance_id(), snappedf(tune.statue_scale, 0.001), mirrored]):
				walls += 1
		check(walls == 2, "%s: the Sentinels' frames are baked for both walls with the level (%d)" % [path.get_file(), walls])
		await sim.free_world(world)
	var kept: Dictionary = {}
	for m: Material in EnemyDirector._kept:
		kept[ShaderWarmup.shader_key(m)] = true
	check(kept.has(ShaderWarmup.shader_key(GildedSentinel._eyes_material())),
		"a material like a Sentinel's eyes is kept (each Sentinel makes its own, which built its shader again)")


# --- Hit-stop -------------------------------------------------------------------------------------

func _test_freeze_never_chains() -> void:
	var world := sim.build_world(RunSim.layout(3, 100.0))
	var fx: RunEffects = world.effects
	var gap: float = fx.tuning.freeze_gap
	fx.freeze(0.05)
	fx.freeze(0.07)
	check(is_equal_approx(fx.freeze_left, 0.07), "requests in the frame a freeze begins keep the longer one, not their sum (%.3f)" % fx.freeze_left)
	fx._process(0.1)
	check(fx.freeze_left == 0.0, "the freeze runs out")
	fx.freeze(0.05)
	check(fx.freeze_left == 0.0, "a freeze asked for %.2f s after the last one began is left out (it would chain)" % 0.1)
	fx._process(gap)
	fx.freeze(0.05)
	check(is_equal_approx(fx.freeze_left, 0.05), "one asked for freeze_gap (%.2f s) after the last one began holds the camera again" % gap)
	fx.freeze(0.2)
	check(is_equal_approx(fx.freeze_left, 0.2), "and in its own frame still keeps the longer request")
	fx._process(0.01)
	fx.freeze(0.5)
	check(fx.freeze_left < 0.2, "a request while one holds never extends it")
	await sim.free_world(world)


func _test_boss_props_share_rings() -> void:
	var a: TorusMesh = BossProps._ring(1.25)
	var b: TorusMesh = BossProps._ring(1.25)
	var c: TorusMesh = BossProps._ring(2.0)
	check(a == b and a != c and is_equal_approx(c.outer_radius, 2.0) and is_equal_approx(a.inner_radius, 1.25 * 0.78),
		"target circles of one size share one ring mesh")


# --- The shader warm-up stage ---------------------------------------------------------------------

func _test_shader_warmup() -> void:
	check(not ShaderWarmup.needed(), "a headless run never needs the warm-up stage (LevelRun leaves it out)")
	var level: Array = _level("golden/2")
	var layout: LevelLayout = level[1]
	for e: Dictionary in WARM_ENTRIES:
		layout.enemies.append(e.duplicate(true))
	var world := sim.build_world(layout, Loadout.full(App.catalog), level[2], level[0])
	var camera := Camera3D.new()
	tree.root.add_child(camera)
	var stage := ShaderWarmup.new()
	stage.setup(world, camera)
	check(stage.get_parent() == camera and stage.scale.x <= 0.01, "the stage sits in front of the camera, tiny")
	var drawn: Array[Material] = ShaderWarmup.materials_of(stage)
	check(drawn.size() > 0 and ShaderWarmup._kept == drawn,
		"the stage's materials are kept past it, until the next level's stage (%d)" % drawn.size())
	var stray: PackedStringArray = []
	for node: Node in stage.find_children("*", "Node3D", true, false):
		var n3 := node as Node3D
		if n3.top_level:
			stray.append("%s is top-level" % n3.name)
		if node is Light3D and n3.visible:
			stray.append("%s is a light" % n3.name)
		if node is CollisionObject3D:
			stray.append("%s is a physics object" % n3.name)
	check(stray.is_empty(), "nothing in it collides, lights the street or leaves its tiny space: %s" % ", ".join(stray.slice(0, 4)))
	var all_holders: Array[Area3D] = []
	all_holders.append_array(ShaderWarmup._hazards)
	all_holders.append_array(ShaderWarmup._areas)
	var holders: int = all_holders.size()
	var outside: bool = true
	for holder: Area3D in all_holders:
		outside = outside and not holder.is_inside_tree() and holder.get_child_count() == 0
	check(holders > 0 and outside, "the track samples are dressed on hazards and areas kept out of the tree (%d)" % holders)
	for i: int in 3:
		await tree.process_frame
	var big: PackedStringArray = []
	for node: Node in stage.find_children("*", "Node3D", true, false):
		var n3 := node as Node3D
		if n3.global_transform.basis.get_scale().x > ShaderWarmup.SCALE * 100.0:
			big.append("%s (%s)" % [stage.get_path_to(n3), node.get_script().resource_path.get_file() if node.get_script() else node.get_class()])
	check(big.is_empty(), "a few frames on, every sample is still too small to see (none at full size in the world): %s" %
		", ".join(big.slice(0, 4)))
	check(_count_script(stage, CyborgBody) >= 3, "it draws the cyborgs' looks (a cyborg, a host, a window cyborg)")
	var cuts: int = 0
	for node: Node in stage.find_children("*", "MeshInstance3D", true, false):
		var cut := (node as MeshInstance3D).material_override as ShaderMaterial
		if cut != null and cut.shader == GildedSentinel.cut_shader():
			cuts += 1
	check(cuts >= 1, "it draws a Gilded Sentinel's cut marks (their shader came first at its first warning)")
	var states: Dictionary = {}
	for v: Node in stage.find_children("*", "Node", true, false):
		if v is HazardStateVisual:
			states[(v as HazardStateVisual).state] = true
	check(states.size() == 3, "it draws fence looks in every state (on, warning, off)")
	var particles: int = 0
	for mm: Node in stage.find_children("*", "MultiMeshInstance3D", true, false):
		if (mm as MultiMeshInstance3D).multimesh.use_custom_data:
			particles += 1
	check(particles >= 2, "it draws the particles' glow as particles (%d)" % particles)
	var hidden: int = 0
	for g: Node in world.find_children("*", "GeometryInstance3D", true, false):
		if not (g as GeometryInstance3D).is_visible_in_tree():
			hidden += 1
	check(hidden > 0 and stage.keys.size() > 0, "it samples the run's hidden looks (%d samples of %d hidden nodes)" % [
		stage.keys.size(), hidden])
	var credit_shaders: int = 0
	for value: int in CreditField.LOOKS:
		if drawn.has(CreditField.material_for(value)):
			credit_shaders += 1
	check(credit_shaders == CreditField.LOOKS.size(),
		"it draws every credit denomination's look, even a boss's whose track carries none of its own (%d of %d)" %
		[credit_shaders, CreditField.LOOKS.size()])
	stage.queue_free()
	await tree.process_frame
	var again := ShaderWarmup.new()
	again.setup(world, camera)
	check(ShaderWarmup._hazards.size() + ShaderWarmup._areas.size() == holders,
		"the next level's stage dresses the same hazards and areas again (no physics object made or freed)")
	again.queue_free()
	camera.queue_free()
	await sim.free_world(world)


# --- The frame monitor and graph ------------------------------------------------------------------

func _test_frame_monitor() -> void:
	var world := sim.build_world(RunSim.layout(3, 2000.0))
	var monitor := FrameMonitor.new()
	monitor.keep_all = true
	tree.root.add_child(monitor)
	monitor.watch(world)
	world.start()
	var built_before: int = world.track.get(&"_next_chunk")
	for i: int in 240:
		await tree.physics_frame
	var dummy: Enemy = world.director.spawn({"type": "dummy", "script": DUMMY, "at": world.player.distance + 30.0,
		"lane": 1, "seed": 1, "params": {}})
	await tree.physics_frame
	dummy.defeat(&"test")
	for i: int in 20:
		await tree.physics_frame
	var built: int = int(world.track.get(&"_next_chunk")) - built_before
	var tagged: int = 0
	var kills: int = 0
	var stops: int = 0
	var spawns: int = 0
	for list: PackedStringArray in monitor.tags:
		for t: String in list:
			if t.begins_with("chunk+"):
				tagged += int(t.trim_prefix("chunk+"))
			kills += 1 if t == "kill:dummy" else 0
			stops += 1 if t == "hit-stop" else 0
			spawns += 1 if t == "spawn:dummy" else 0
	var held: int = 0
	for f: int in monitor.frozen:
		held += f
	check(monitor.frame_count() >= 260, "it records every frame (%d)" % monitor.frame_count())
	check(built > 0 and tagged == built, "each chunk built is tagged in its frame (%d built, %d tagged)" % [built, tagged])
	check(spawns == 1 and kills == 1 and stops == 1, "a spawn, a kill and its hit-stop are tagged (%d, %d, %d)" % [spawns, kills, stops])
	check(held >= 2, "the frames the hit-stop holds the camera are marked (%d)" % held)
	var totals: PackedFloat32Array = monitor.totals_ms()
	check(totals.size() == monitor.frame_count() and totals[10] > 0.0, "every frame has a time")
	monitor.queue_free()
	await sim.free_world(world)


func _test_frame_graph() -> void:
	var monitor := FrameMonitor.new()
	var graph := FrameGraph.new()
	graph.monitor = monitor
	for i: int in 200:
		var ms: float = 16.0
		var tags := PackedStringArray()
		var held: int = 0
		if i == 150:
			ms = 60.0
			tags = PackedStringArray(["spawn:cyborg", "credit", "sound:credit_5"])
		elif i >= 170 and i < 173:
			held = 1
			if i == 170:
				tags = PackedStringArray(["kill:cyborg", "hit-stop"])
		monitor.starts.append(i * 16000)
		monitor.totals.append(int(ms * 1000.0))
		monitor.logics.append(int(ms * 500.0))
		monitor.physics.append(1000)
		monitor.frozen.append(held)
		monitor.tags.append(tags)
	var events: Array[Dictionary] = graph.events()
	check(events.size() == 2 and int(events[0]["held"]) == 3 and int(events[0]["frame"]) == 170 and int(events[1]["frame"]) == 150,
		"the graph lists the hit-stop's hold (3 frames, from its first) and the spike, newest first: %s" % str(events))
	check(graph.spike_limit_ms() > 16.0 and graph.spike_limit_ms() < 60.0, "a spike is a frame well over the median")
	check(FrameGraph._short_tags(events[1]["tags"]) == "spawn:cyborg", "a spike's list leaves out the credits and sounds")
	graph.free()
	monitor.free()


func _test_summaries() -> void:
	var times := PackedFloat32Array()
	for i: int in 100:
		times.append(1.05 + i * 0.1)
	times.append(20.0)
	var s: Dictionary = FrameMonitor.summarize(times)
	check(int(s["frames"]) == 101 and absf(float(s["median"]) - 6.05) < 0.001 and is_equal_approx(float(s["worst"]), 20.0),
		"the summary's median and worst (%s)" % str(s))
	check(absf(float(s["p99"]) - 10.95) < 0.001 and int(s["over16"]) == 1 and int(s["over8"]) == 31,
		"its 99th percentile (nearest rank) and the frames over 8 and 16 ms (%s)" % str(s))
