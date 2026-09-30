extends TestSuite
## Speed effects and spectacle (G2, the owner's playtest, September 30, 2026): the run camera's
## field-of-view kick follows Player.speed and eases back; the Screen shake setting switches shake
## and hit-stop off; hit-stop (RunEffects.freeze) never changes what a seeded run decides, because it
## never touches Engine.time_scale and only holds the camera; and nothing this task adds (speed
## lines, kill sparks, debris, blocked-hit sparks, the weapon's kill flash) glows in a hazard colour.

const MIN_HAZARD_DISTANCE: float = 0.3
const DUMMY: String = "res://tests/helpers/dummy_enemy.gd"

var sim: RunSim
var speed_fx: SpeedFxTuning


func run() -> void:
	sim = RunSim.new(tree, tuning)
	speed_fx = load("res://data/tuning/speed_fx.tres") as SpeedFxTuning
	await _test_fov_follows_speed_and_returns()
	await _test_lane_lean_follows_switch_dir()
	await _test_settings_switch_effects_off()
	await _test_hit_stop_never_changes_the_game()
	await _test_hit_stop_holds_the_camera()
	await _test_kill_and_block_fx_fire()
	_test_no_hazard_colours()
	Engine.time_scale = 1.0  # never leak a slowed engine into the next suite


func _camera_on(world: RunWorld) -> RunCamera:
	var camera := RunCamera.new()
	tree.root.add_child(camera)
	camera.follow(world)
	return camera


# --- Field of view and lean -------------------------------------------------

func _test_fov_follows_speed_and_returns() -> void:
	var world := sim.build_world(RunSim.layout(3, 200.0))
	var camera := _camera_on(world)
	var base_fov: float = world.tuning.camera_fov
	check(absf(camera.fov - base_fov) < 0.1, "the camera starts at rest at the base fov (%.2f vs %.2f)" %
		[camera.fov, base_fov])
	# A fast zone or a boost (Player.speed folds both in): the kick should grow.
	world.player.speed = speed_fx.fov_reference_speed + 20.0
	for i: int in 240:
		camera._update(1.0 / 60.0, false)
	var kicked: float = camera.fov
	check(kicked > base_fov + 3.0 and kicked <= base_fov + speed_fx.fov_kick_max + 0.01,
		"the fov widens with speed, within its cap (%.2f, base %.2f, cap +%.2f)" %
		[kicked, base_fov, speed_fx.fov_kick_max])
	# Speed drops back to the reference: the kick eases back out.
	world.player.speed = speed_fx.fov_reference_speed
	for i: int in 600:
		camera._update(1.0 / 60.0, false)
	check(absf(camera.fov - base_fov) < 0.1, "the fov eases back to the base fov once speed settles (%.2f vs %.2f)" %
		[camera.fov, base_fov])
	camera.queue_free()
	await sim.free_world(world)


func _test_lane_lean_follows_switch_dir() -> void:
	var world := sim.build_world(RunSim.layout(3, 200.0))
	var camera := _camera_on(world)
	world.start()
	for i: int in 5:
		await tree.physics_frame
		camera._update(1.0 / 60.0, false)
	check(absf(camera._lean_deg) < 0.05, "no lean while the player isn't switching lanes")
	world.player.press(&"move_right")
	var switched: bool = false
	for i: int in 30:
		await tree.physics_frame
		camera._update(1.0 / 60.0, false)
		if absf(camera._lean_deg) > 0.3:
			switched = true
			break
	check(switched, "the camera leans while a lane switch is under way")
	camera.queue_free()
	await sim.free_world(world)


# --- Settings ----------------------------------------------------------------

func _test_settings_switch_effects_off() -> void:
	var world := sim.build_world(RunSim.layout(3, 100.0))
	world.effects.shake_scale = 0.0
	var shook: Array = [false]  # a lambda captures locals by value, so a mutable box holds the flag
	world.effects.shake_requested.connect(func(_s: float, _d: float) -> void: shook[0] = true)
	world.effects.shake(1.0, 0.3)
	world.effects.freeze(1.0)
	check(not shook[0] and world.effects.freeze_left == 0.0,
		"Screen shake off silences both shake and hit-stop")
	world.effects.shake_scale = 1.0
	world.effects.shake(1.0, 0.3)
	world.effects.freeze(0.2)
	check(shook[0] and world.effects.freeze_left > 0.0, "Screen shake on lets both through again")
	await sim.free_world(world)


# --- Hit-stop determinism -----------------------------------------------------

func _test_hit_stop_never_changes_the_game() -> void:
	# Two separate LevelLayout instances: TrackBuilder streams chunks into the one it's given, so
	# sharing a single instance between two worlds would make the second build on the first's
	# already-streamed state instead of the same fresh layout.
	var actions: Array = [[8.0, &"jump"], [16.0, &"slide"], [24.0, &"move_right"], [40.0, &"dash"]]

	var plain := sim.build_world(RunSim.layout(3, 400.0))
	plain.start()
	var r1: Dictionary = await sim.step_world(plain, 2.5, actions, [], false)
	await sim.free_world(plain)

	var frozen := sim.build_world(RunSim.layout(3, 400.0))
	frozen.start()
	frozen.effects.freeze(999.0)  # held "frozen" for the whole run
	var r2: Dictionary = await sim.step_world(frozen, 2.5, actions, [], false)
	await sim.free_world(frozen)

	check(Engine.time_scale == 1.0, "freeze() never touches Engine.time_scale")
	check(float(r1["distance"]) > 10.0 and is_equal_approx(float(r1["distance"]), float(r2["distance"])),
		"hit-stop never changes the distance covered (%.5f vs %.5f)" % [r1["distance"], r2["distance"]])
	check(r1["events"] == r2["events"], "hit-stop never changes the event log (%s vs %s)" % [r1["events"], r2["events"]])
	check(r1["lane"] == r2["lane"] and r1["alive"] == r2["alive"], "hit-stop never changes the outcome")


func _test_hit_stop_holds_the_camera() -> void:
	var world := sim.build_world(RunSim.layout(3, 200.0))
	var camera := _camera_on(world)
	for i: int in 10:
		camera._update(1.0 / 60.0, false)
	var held_pos: Vector3 = camera.position
	var held_fov: float = camera.fov
	world.effects.freeze(1.0)
	world.player.position.z -= 30.0  # the world moves on underneath
	world.player.speed = speed_fx.fov_reference_speed + 25.0
	camera._process(1.0 / 10.0)  # a big, frozen step
	check(camera.position.is_equal_approx(held_pos) and is_equal_approx(camera.fov, held_fov),
		"the camera holds its view while hit-stop is running")
	camera.queue_free()
	await sim.free_world(world)


# --- Kills and blocked hits ---------------------------------------------------

func _test_kill_and_block_fx_fire() -> void:
	var world := sim.build_world(RunSim.layout(3, 100.0))
	var shakes: Array = [0]  # see _test_settings_switch_effects_off: a lambda captures locals by value
	world.effects.shake_requested.connect(func(_s: float, _d: float) -> void: shakes[0] += 1)
	var dummy: Enemy = world.director.spawn({"type": "dummy", "script": DUMMY, "at": 30.0, "lane": 1,
		"seed": 1, "params": {}})
	check(is_instance_valid(dummy), "the test can spawn a dummy enemy")
	dummy.defeat(&"test")
	check(shakes[0] > 0 and world.effects.freeze_left > 0.0, "a kill shakes the camera and starts hit-stop")

	world.effects.freeze_left = 0.0
	shakes[0] = 0
	world.player._event(&"armor_hit")
	check(shakes[0] > 0, "a blocked hit shakes the camera")
	await sim.free_world(world)


# --- Colour rules --------------------------------------------------------------

## The hazard colours every skin and enemy fire use (mirrors test_avatar._hazard_colors).
static func _hazard_colors() -> Dictionary:
	var out: Dictionary = {}
	for file: String in DirAccess.get_files_at("res://data/skins/"):
		if not file.ends_with(".tres"):
			continue
		var skin: Resource = load("res://data/skins/" + file)
		for property: String in ["gap_edge_color", "fence_color", "sign_color", "sign_frame_color", "ramp_color",
				"speed_pad_color"]:
			if property in skin:
				out["%s %s" % [file.get_basename(), property.trim_suffix("_color")]] = skin.get(property)
	for look: StringName in [&"enemy_bolt", &"enemy_shell", &"enemy_bullet"]:
		out[String(look)] = (ProjectilePool.LOOKS[look] as Dictionary)["color"]
	return out


static func _chroma_distance(a: Color, b: Color) -> float:
	return (Vector2(cos(TAU * a.h), sin(TAU * a.h)) * a.s).distance_to(Vector2(cos(TAU * b.h), sin(TAU * b.h)) * b.s)


func _test_no_hazard_colours() -> void:
	var hazards: Dictionary = _hazard_colors()
	check(hazards.size() >= 10, "the check covers every skin's hazard colours and enemy fire (%d)" % hazards.size())
	var samples: Dictionary = {
		"speed lines": SpeedLines.COLOR,
		"kill spark": Color(1.0, 0.96, 0.88),
		"kill debris": Color(0.55, 0.52, 0.5),
		"armor block spark": PlayerSuit.GLOW,
		"shield block spark": PlayerSuit.SHIELD,
	}
	for look: StringName in [&"laser", &"laser_2", &"missile", &"heavy_missile"]:
		var base: Color = (ProjectilePool.LOOKS[look] as Dictionary)["color"]
		samples["weapon kill flash (%s)" % look] = base.lerp(Color.WHITE, 0.5)
	var wrong: PackedStringArray = []
	for name: String in samples:
		var least: float = INF
		var nearest: String = ""
		for hazard: String in hazards:
			var d: float = _chroma_distance(samples[name], hazards[hazard])
			if d < least:
				least = d
				nearest = hazard
		if least < MIN_HAZARD_DISTANCE:
			wrong.append("%s is only %.2f from the %s" % [name, least, nearest])
	check(wrong.is_empty(), "no speed effect glows in a hazard colour (%s)" % ", ".join(wrong))
