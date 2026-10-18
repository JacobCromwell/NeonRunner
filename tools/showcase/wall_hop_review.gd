extends Node3D
## Gameplay review for the wall-hop credits (task N1; GDD §7, "Wall-hop credits"; WallHopPlacement): a campaign level's
## own line of wall-hop credits, cut out of its build onto a fresh track in its zone's look and at its zone's speed,
## ridden by a scripted runner in a real RunWorld and seen through the game's camera (RunCamera) or a still one.
##   Render:  godot --path . --write-movie build/review/f.png --fixed-fps 10 --quit-after 120
##            res://tools/showcase/wall_hop_review.tscn -- [options]
##   Options (after --):
##     --level=<id>        the campaign level whose build it's taken from (default gangland/1); its line
##     --lanes=N           lane count (default 5)
##     --take=<hop|run>    the reference hopper (WallHopPath: on at the line's entry, a hop each time its run comes
##                         down to WallHopTuning.hop_height; the default), or one wall run from the entry, no hop
##     --camera=<game|side>  the game's camera (default), or a still one by the other wall, looking across at the
##                         line's high-value credits
##     --hitboxes          show the hitboxes (the hitbox view)
## The excerpt's entry lies ENTRY_AT metres along the track. Each scripted action and movement event is printed with
## its time and distance, to find the frames (frame = time × render fps).

const TUNING_PATH: String = "res://data/tuning/movement.tres"
const RULES_PATH: String = "res://data/tuning/game_rules.tres"
const ENTRY_AT: float = 60.0

var world: RunWorld
var camera: Camera3D
var take: String = "hop"
var camera_kind: String = "game"
var line: Dictionary = {}
var _wall_frames: int = 0
var _wait: int = 0
var _on: bool = false
var _hop_height: float = 1.5


func _ready() -> void:
	var base: MovementTuning = load(TUNING_PATH) as MovementTuning
	var level_id: String = "gangland/1"
	var lanes: int = 5
	var hitboxes: bool = false
	for arg: String in OS.get_cmdline_user_args():
		var v: String = arg.get_slice("=", 1)
		if arg.begins_with("--level="):
			level_id = v
		elif arg.begins_with("--lanes="):
			lanes = clampi(int(v), 3, 8)
		elif arg.begins_with("--take="):
			take = v
		elif arg.begins_with("--camera="):
			camera_kind = v
		elif arg == "--hitboxes":
			hitboxes = true
	var campaign := load("res://data/campaign/campaign.tres") as Campaign
	var config: LevelConfig = campaign.configure(campaign.step(level_id), lanes)
	var source: LevelLayout = LevelGenerator.new().generate(config, base, LevelGenerator.load_for(config))
	if source.wall_hops.is_empty():
		push_warning("wall_hop_review: %s at %d lanes has no wall-hop line" % [level_id, lanes])
		get_tree().quit(1)
		return
	var layout: LevelLayout = _excerpt(source, source.wall_hops[0])
	var t: MovementTuning = config.movement_for(base)
	_hop_height = WallHopPlacement.tuning().hop_height
	var side: int = int(line["side"])
	var run_config := LevelConfig.new()
	run_config.lane_count = lanes
	run_config.skin = config.skin
	run_config.run_speed = config.run_speed
	var skin: ZoneSkin = config.skin if config.skin != null else GreyboxSkin.new()
	var sfx := load("res://data/audio/sfx_library.tres") as SfxLibrary
	world = RunWorld.new()
	add_child(world)
	world.build(run_config, layout, base, load(RULES_PATH) as GameRules, null, null, sfx)
	world.player.setup(world.tuning, world.geo, layout.outer_lane(side))
	world.track.set_hitboxes_visible(hitboxes)
	world.player.movement_event.connect(func(event: StringName) -> void:
		print("%5.2f s  %6.1f m  h %.2f  %s" % [world.player.elapsed, world.player.distance, world.player.h, event]))
	world.credits.collected.connect(func(value: int, _pos: Vector3) -> void:
		print("%5.2f s  %6.1f m  h %.2f  credit %d" % [world.player.elapsed, world.player.distance, world.player.h, value]))
	print("%s at %d lanes, its line on the %s wall at %.0f m (entry %.1f m here, high-value %.1f-%.1f m), at %.1f m/s (%s)" % [
		level_id, lanes, "left" if side < 0 else "right", float(source.wall_hops[0]["entry"]), float(line["entry"]),
		float(line["gems_from"]), float(line["gems_to"]), t.run_speed, take])
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
		var middle: float = (float(line["gems_from"]) + float(line["gems_to"])) * 0.5
		var geo: TrackGeometry = world.geo
		camera.position = Vector3(-side * (geo.wall_x() - 0.8), 2.2, TrackGeometry.world_z(middle - 22.0))
		camera.look_at(Vector3(side * geo.wall_x(), 2.4, TrackGeometry.world_z(middle + 2.0)))
	camera.make_current()
	world.start()


func _physics_process(_delta: float) -> void:
	if world == null or line.is_empty():
		return
	var p: Player = world.player
	var toward: StringName = &"move_left" if int(line["side"]) < 0 else &"move_right"
	_wall_frames = _wall_frames + 1 if p.surface == Player.Surface.WALL else 0
	if _wait > 0:
		_wait -= 1
		if _wait == 0:
			p.press(toward)
		return
	if not _on and p.distance >= float(line["entry"]) and p.surface == Player.Surface.FLOOR:
		_on = true
		print("%5.2f s  %6.1f m  > onto the wall" % [p.elapsed, p.distance])
		p.press(toward)
		return
	var settle: int = ceili(world.tuning.wall_entry_time * Engine.physics_ticks_per_second)
	if take == "hop" and p.surface == Player.Surface.WALL and _wall_frames > settle and p.h <= _hop_height \
			and p.distance < float(line["gems_to"]) + 1.0:
		print("%5.2f s  %6.1f m  > hop" % [p.elapsed, p.distance])
		p.press(&"jump")
		_wait = WallHopPath.HOP_FRAMES


## `source`'s line `w` (its credits) on a fresh straight track, its entry at ENTRY_AT; sets `line`.
func _excerpt(source: LevelLayout, w: Dictionary) -> LevelLayout:
	var shift: float = ENTRY_AT - float(w["entry"])
	line = w.duplicate(true)
	for key: String in ["entry", "start", "end", "gems_from", "gems_to"]:
		line[key] = float(w[key]) + shift
	var out := LevelLayout.new()
	out.lane_count = source.lane_count
	out.length = float(line["end"]) + 160.0
	out.wall_hops.append(line)
	for c: Dictionary in source.credits:
		if (c.has(WallHopPlacement.GEM) or c.has(WallHopPlacement.LEAD)) and int(c["side"]) == int(w["side"]) \
				and float(c["at"]) >= float(w["start"]) and float(c["at"]) <= float(w["end"]):
			var k: Dictionary = c.duplicate(true)
			k["at"] = float(c["at"]) + shift
			out.credits.append(k)
	return out
