extends Node3D
## Gameplay review for the ceiling scenarios (task I4; GDD §3, "Ceiling scenarios"): a campaign level's own treasure
## stash or fenced ceiling, cut out of its build (the ceiling, its pads, the scenario's pieces) onto a fresh track in
## its zone's look and at its zone's speed, played by a scripted runner in a real RunWorld and seen through the game's
## camera (RunCamera) or a still one.
##   Render:  godot --path . --write-movie build/review/f.png --fixed-fps 10 --quit-after 150
##            res://tools/showcase/ceiling_scenario_review.tscn -- [options]
##   Options (after --):
##     --scenario=<stash|fenced>   which one (default stash)
##     --level=<id>        the campaign level whose build it's taken from (default casino/1 for a stash, casino/2
##                         for a fenced ceiling); its first scenario of the kind
##     --lanes=N           lane count (default 5; a stash needs 5 or more)
##     --take=<...>        what the runner does:
##                           stash:  return (the default: the first pad, then the stash's lane on the ceiling, its
##                                   return pad drops them in), floor (a floor runner in the stash's lane, pushed out
##                                   and pressing back in), stay (a rider who stays on in another lane)
##                           fenced: safe (the default: past the unsafe pads in a lane free of them, then the safe
##                                   pad), unsafe (the first pad, into the fences; --god rides on), floor (under them)
##     --camera=<game|look|side>   the game's camera (default), a still one on the floor before the ceiling's first
##                         pad looking along it, or a still one beside the track at the scenario's middle
##     --reduced-flashing  the Reduced flashing setting on
##     --hitboxes          show the hitboxes (the hitbox view)
##     --god               god mode
## The excerpt's first pad lies PAD_AT metres along the track. Each scripted action, movement event and death is
## printed with its time and distance, to find the frames (frame = time × render fps).

const TUNING_PATH: String = "res://data/tuning/movement.tres"
const RULES_PATH: String = "res://data/tuning/game_rules.tres"
const PAD_AT: float = 80.0

var world: RunWorld
var camera: Camera3D
var scenario: String = "stash"
var take: String = ""
var camera_kind: String = "game"
## The excerpt's ceiling, its stash (or {}), the lane the rider aims for on the ceiling (-1: none), and the floor
## moves still to make: [distance, action].
var hull: Dictionary = {}
var stash: Dictionary = {}
var ride_lane: int = -1
var _pending: Array = []
var _press_back: int = -1


func _ready() -> void:
	var base: MovementTuning = load(TUNING_PATH) as MovementTuning
	var level_id: String = ""
	var lanes: int = 5
	var reduced_flashing: bool = false
	var hitboxes: bool = false
	var god: bool = false
	for arg: String in OS.get_cmdline_user_args():
		var v: String = arg.get_slice("=", 1)
		if arg.begins_with("--scenario="):
			scenario = v
		elif arg.begins_with("--level="):
			level_id = v
		elif arg.begins_with("--lanes="):
			lanes = clampi(int(v), 3, 8)
		elif arg.begins_with("--take="):
			take = v
		elif arg.begins_with("--camera="):
			camera_kind = v
		elif arg == "--reduced-flashing":
			reduced_flashing = true
		elif arg == "--hitboxes":
			hitboxes = true
		elif arg == "--god":
			god = true
	var kind: String = CeilingScenarios.STASH if scenario == "stash" else CeilingScenarios.FENCED
	if level_id == "":
		level_id = "casino/1" if kind == CeilingScenarios.STASH else "casino/2"
	if take == "":
		take = "return" if kind == CeilingScenarios.STASH else "safe"
	var campaign := load("res://data/campaign/campaign.tres") as Campaign
	var config: LevelConfig = campaign.configure(campaign.step(level_id), lanes)
	var source: LevelLayout = LevelGenerator.new().generate(config, base, LevelGenerator.load_for(config))
	var h: Dictionary = {}
	for x: Dictionary in source.hulls:
		if CeilingScenarios.scenario_of(x) == kind:
			h = x
			break
	if h.is_empty():
		push_warning("ceiling_scenario_review: %s at %d lanes has no %s" % [level_id, lanes, kind])
		get_tree().quit(1)
		return
	var layout: LevelLayout = _excerpt(source, h)
	var t: MovementTuning = config.movement_for(base)
	var geo := TrackGeometry.new(lanes, t)
	var start_lane: int = int(layout.pads[0]["lane"])
	match take:
		"return":
			ride_lane = int(stash["lane"])
		"stay":
			ride_lane = int(stash["lane"]) + 1 if layout.hull_covers(hull, int(stash["lane"]) + 1) else int(stash["lane"]) - 1
		"floor":
			_pending.clear()
			if kind == CeilingScenarios.STASH:
				layout.pads.clear()
				start_lane = int(stash["lane"])
				_press_back = start_lane
			else:
				start_lane = _free_lane(layout, [])
		"safe":
			var unsafe_lanes: Array[int] = []
			var last_unsafe: float = 0.0
			var safe_pad: Dictionary = {}
			for p: Dictionary in layout.pads:
				if String(p.get("fenced", "")) == "unsafe":
					unsafe_lanes.append(int(p["lane"]))
					last_unsafe = maxf(last_unsafe, float(p["at"]))
				elif safe_pad.is_empty():
					safe_pad = p
			start_lane = _free_lane(layout, unsafe_lanes)
			var target: int = int(safe_pad["lane"])
			for k: int in absi(target - start_lane):
				_pending.append([last_unsafe + t.pad_length + 2.0 + k * 3.0, &"move_right" if target > start_lane else &"move_left"])
	var run_config := LevelConfig.new()
	run_config.lane_count = lanes
	run_config.skin = config.skin
	run_config.run_speed = config.run_speed
	var skin: ZoneSkin = config.skin if config.skin != null else GreyboxSkin.new()
	var sfx := load("res://data/audio/sfx_library.tres") as SfxLibrary
	world = RunWorld.new()
	add_child(world)
	world.build(run_config, layout, base, load(RULES_PATH) as GameRules, null, null, sfx)
	world.player.setup(world.tuning, world.geo, start_lane)
	world.player.steady_flash = reduced_flashing
	world.player.god_mode = god
	world.track.set_hitboxes_visible(hitboxes)
	world.player.movement_event.connect(func(event: StringName) -> void:
		print("%5.2f s  %6.1f m  %s" % [world.player.elapsed, world.player.distance, event]))
	world.player.died.connect(func(cause: String) -> void:
		print("%5.2f s  %6.1f m  died (%s)" % [world.player.elapsed, world.player.distance, cause]))
	print("%s at %d lanes, its %s on the ceiling at %.0f m (%.0f-%.0f m here), at %.1f m/s; runner from lane %d (%s)" % [
		level_id, lanes, kind, float(h["start"]), float(hull["start"]), float(hull["end"]), t.run_speed, start_lane, take])
	for p: Dictionary in layout.pads:
		print("  pad lane %d at %.1f m %s" % [p["lane"], p["at"], p.get("fenced", "")])
	if not stash.is_empty():
		print("  stash lane %d %.1f-%.1f m, return pad at %.1f m" % [stash["lane"], stash["start"], stash["end"], stash["pad"]])
	if not layout.ceiling_fences.is_empty():
		print("  ceiling fences %.1f-%.1f m" % [layout.ceiling_fences[0]["at"], layout.ceiling_fences[-1]["at"]])

	var env := WorldEnvironment.new()
	env.environment = skin.make_environment()
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, 25.0, 0.0)
	sun.light_energy = 0.7
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(sun)
	if camera_kind == "game":
		var run_camera := RunCamera.new()
		add_child(run_camera)
		run_camera.follow(world)
		camera = run_camera
	else:
		camera = Camera3D.new()
		camera.fov = 62.0
		add_child(camera)
		var first: float = float(layout.pads[0]["at"]) if not layout.pads.is_empty() else float(hull["start"]) + 10.0
		var middle: float = (float(stash["start"]) + float(stash["end"])) * 0.5 if not stash.is_empty() \
			else (float(layout.ceiling_fences[0]["at"]) + float(layout.ceiling_fences[-1]["at"])) * 0.5
		if camera_kind == "side":
			camera.position = Vector3(geo.wall_x() - 0.6, 3.0, TrackGeometry.world_z(middle - 9.0))
			camera.look_at(Vector3(0.0, 2.6, TrackGeometry.world_z(middle + 4.0)))
		else:
			var aim: float = first if stash.is_empty() else float(stash["start"])
			camera.position = Vector3(geo.lane_x(start_lane), 1.7, TrackGeometry.world_z(aim - 16.0))
			camera.look_at(Vector3(geo.lane_x(start_lane), 3.2, TrackGeometry.world_z(aim + 12.0)))
	camera.make_current()
	world.start()


func _physics_process(_delta: float) -> void:
	if world == null:
		return
	var p: Player = world.player
	while not _pending.is_empty() and p.distance >= float(_pending[0][0]):
		var action: StringName = _pending.pop_front()[1]
		print("%5.2f s  %6.1f m  > %s" % [p.elapsed, p.distance, action])
		p.press(action)
	if ride_lane >= 0 and p.surface == Player.Surface.CEILING and p.lane != ride_lane:
		p.press(&"move_right" if ride_lane > p.lane else &"move_left")
	# A floor runner who keeps pressing back toward the stash's lane, from the stash's front to its open end.
	if _press_back >= 0 and p.lane != _press_back and p.distance >= float(stash["start"]) - 8.0 \
			and p.distance <= float(stash["end"]) and Engine.get_physics_frames() % 6 == 0:
		p.press(&"move_right" if _press_back > p.lane else &"move_left")


## `source`'s ceiling `h` with its pads and its scenario's pieces on a fresh straight track, its first pad at PAD_AT;
## sets `hull` and `stash`.
func _excerpt(source: LevelLayout, h: Dictionary) -> LevelLayout:
	var pads: Array[Dictionary] = CeilingScenarios.pads_under(source, h)
	var shift: float = PAD_AT - float(pads[0]["at"])
	hull = h.duplicate(true)
	hull["start"] = float(h["start"]) + shift
	hull["end"] = float(h["end"]) + shift
	if h.has("pick"):
		hull["pick"] = [float(h["pick"][0]) + shift, float(h["pick"][1]) + shift]
	var out := LevelLayout.new()
	out.lane_count = source.lane_count
	out.length = float(hull["end"]) + 160.0
	out.hulls.append(hull)
	for p: Dictionary in pads:
		var q: Dictionary = p.duplicate(true)
		q["at"] = float(p["at"]) + shift
		out.pads.append(q)
	for f: Dictionary in source.ceiling_fences:
		if float(f["at"]) >= float(h["start"]) and float(f["at"]) <= float(h["end"]):
			out.ceiling_fences.append({"lane": int(f["lane"]), "at": float(f["at"]) + shift})
	for s: Dictionary in source.stashes:
		if absf(float(s["hull_start"]) - float(h["start"])) > 0.01:
			continue
		stash = s.duplicate(true)
		for key: String in ["start", "end", "walls_from", "pad", "hull_start", "keep_from", "keep_to"]:
			stash[key] = float(s[key]) + shift
		out.stashes.append(stash)
		out.return_pads.append({"lane": int(s["lane"]), "at": float(s["pad"]) + shift})
		for d: Dictionary in source.doodads:
			if d.has("stash") and float(d["start"]) >= float(s["start"]) - 0.01 and float(d["end"]) <= float(s["end"]) + 0.01:
				var e: Dictionary = d.duplicate(true)
				e["start"] = float(d["start"]) + shift
				e["end"] = float(d["end"]) + shift
				out.doodads.append(e)
		for c: Dictionary in source.credits:
			if c.has("stash") and float(c["at"]) >= float(s["start"]) and float(c["at"]) <= float(s["end"]):
				var k: Dictionary = c.duplicate(true)
				k["at"] = float(c["at"]) + shift
				out.credits.append(k)
	return out


## The lane nearest the middle that holds no pad in `avoid`'s lanes (every lane but those; with `avoid` empty, a lane
## with no pad at all), or the middle lane.
static func _free_lane(layout: LevelLayout, avoid: Array[int]) -> int:
	var taken: Array[int] = avoid.duplicate()
	if taken.is_empty():
		for p: Dictionary in layout.pads:
			taken.append(int(p["lane"]))
	var mid: int = layout.lane_count / 2
	var best: int = -1
	for lane: int in layout.lane_count:
		if not taken.has(lane) and (best < 0 or absi(lane - mid) < absi(best - mid)):
			best = lane
	return best if best >= 0 else mid
