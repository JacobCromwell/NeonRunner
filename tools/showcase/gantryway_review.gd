extends Node3D
## Gameplay review for falling gantryways (task Q3; GDD §5, Zone 9, owner, October 21, 2026: "dashing through a pillar
## knocks down its long section of gantryway. It takes about a second to fall. When it lands, it destroys any enemy in its
## path. A runner under it when it lands is hit"): a real RunWorld on a hand-built track in a zone's look, driven like the
## tests' RunSim, seen through the game's camera (RunCamera), a close one or one standing beside the track. One gantryway
## over lane --lane (its pillar pushing to --side), a cyborg standing under it where the generator plants one, and the
## runner coming at the pillar in that lane (--take):
##   drop  the dash smashes the pillar, and the runner steps out into the lane the pillar pushes to while the walkway
##         shudders and drops beside them, crushing the cyborg (the default);
##   stay  the dash smashes the pillar and the runner stays under it: the armor absorbs the hit (with --god nothing
##         does; with --bare, no armor: it kills);
##   push  no dash: the pillar pushes the runner aside like a doodad, and the walkway stays up;
##   look  the camera holds still beside the track looking at the standing gantryway, no run.
##
##   Render:  godot --path . --write-movie build/review/f.png --fixed-fps 10 --quit-after 120
##            res://tools/showcase/gantryway_review.tscn -- [options]
##   Options (after --):
##     --take=<drop|stay|push|look>   what the runner does (above; default drop)
##     --zone=<zone id>       the zone's run speed and look (data/zones/<id>.tres; default ice_lab)
##     --skin=<skin id>       another look (data/skins/<id>_skin.tres)
##     --lanes=N              lane count (default 5)
##     --lane=L               the gantryway's lane (an inner one; default the one left of the middle)
##     --side=<-1|1>          the side its pillar pushes to, where the runner steps out (default -1)
##     --close                a close camera low behind the runner
##     --beside               a camera standing beside the track, level with the walkway's middle
##     --hitboxes             show the hitboxes (the hitbox view)
##     --reduced-flashing     the Reduced flashing setting on
##     --god                  god mode
##     --bare                 no armor (--take=stay: the hit kills)
##     --first=M              the pillar's front (metres, default 90)
##     --seed=N               the look's seed (default 0)
## Each scripted action, movement event, fall, landing and kill is printed with its time and distance, to find the
## frames (frame = time × render fps).

const TUNING_PATH: String = "res://data/tuning/movement.tres"
const RULES_PATH: String = "res://data/tuning/game_rules.tres"
const GantrywayRules = preload("res://scripts/enemies/gantryway_rules.gd")

var tuning: MovementTuning
var world: RunWorld
var camera: Camera3D
var take: String = "drop"
var close: bool = false
var beside: bool = false
var _pending: Array = []
var _first: float = 90.0
var _entry: Dictionary = {}


func _ready() -> void:
	tuning = load(TUNING_PATH) as MovementTuning
	var zone_id: String = "ice_lab"
	var skin_id: String = ""
	var lanes: int = 5
	var lane: int = -1
	var side: int = -1
	var hitboxes: bool = false
	var reduced_flashing: bool = false
	var god: bool = false
	var bare: bool = false
	var look_seed: int = 0
	for arg: String in OS.get_cmdline_user_args():
		var v: String = arg.get_slice("=", 1)
		if arg.begins_with("--take="):
			take = v
		elif arg.begins_with("--zone="):
			zone_id = v
		elif arg.begins_with("--skin="):
			skin_id = v
		elif arg.begins_with("--lanes="):
			lanes = clampi(int(v), 3, 8)
		elif arg.begins_with("--lane="):
			lane = int(v)
		elif arg.begins_with("--side="):
			side = -1 if int(v) < 0 else 1
		elif arg == "--close":
			close = true
		elif arg == "--beside":
			beside = true
		elif arg == "--hitboxes":
			hitboxes = true
		elif arg == "--reduced-flashing":
			reduced_flashing = true
		elif arg == "--god":
			god = true
		elif arg == "--bare":
			bare = true
		elif arg.begins_with("--first="):
			_first = maxf(float(v), 40.0)
		elif arg.begins_with("--seed="):
			look_seed = int(v)
	if lane < 1 or lane > lanes - 2:
		lane = maxi(lanes / 2 - (1 if lanes > 3 else 0), 1)
	var config := LevelConfig.new()
	config.lane_count = lanes
	var skin: ZoneSkin = GreyboxSkin.new()
	var zone_path: String = "res://data/zones/%s.tres" % zone_id
	if ResourceLoader.exists(zone_path):
		var zone := load(zone_path) as ZoneDef
		if zone != null:
			config.run_speed = zone.run_speed
			if ResourceLoader.exists(zone.skin_path):
				skin = load(zone.skin_path) as ZoneSkin
	if skin_id != "":
		var skin_path: String = "res://data/skins/%s_skin.tres" % skin_id
		if ResourceLoader.exists(skin_path):
			skin = load(skin_path) as ZoneSkin
		else:
			push_warning("gantryway_review: no skin at %s; keeping the zone's" % skin_path)
	config.skin = skin
	config.features = PackedStringArray([GantrywayRules.FEATURE])
	var t: MovementTuning = config.movement_for(tuning)
	var gt: GantrywayTuning = GantrywayTuning.load_default()
	var pt := load("res://data/tuning/powerups.tres") as PowerupTuning
	var layout := LevelLayout.new()
	layout.lane_count = lanes
	# The gantryway as its rules make one (GantrywayRules: walkway, calm stretch, the planted cyborg's place and orders).
	var walkway: float = gt.length_seconds * t.run_speed
	var fastest: float = t.run_speed + pt.dash_speed_bonus + maxf(t.speed_pad_boost, t.ramp_speed_boost)
	var calm: float = (gt.fall_seconds + gt.escape_after_seconds) * fastest
	var start: float = _first - GantrywayRules.NEAR_OVERHANG
	_entry = {"id": 0, "lane": lane, "start": start, "end": start + walkway, "pillar": _first, "side": side,
		"calm": [_first, _first + calm], "seed": look_seed, "intro": true, "both": true}
	layout.gantryways.append(_entry)
	var pillar: Vector3 = t.doodad_size(Gantryway.PILLAR_SIZE)
	layout.doodads.append({"lane": lane, "start": _first, "end": _first + pillar.z, "size": Gantryway.PILLAR_SIZE,
		"side": side, "seed": look_seed, LevelLayout.GANTRY_PILLAR: 0})
	var near: float = _first + (gt.fall_seconds + gt.crush_margin_seconds) * fastest + GantrywayRules.CYBORG_HALF
	var hold := Vector2(_first - gt.hold_before_seconds * t.run_speed, _first + calm)
	layout.enemies.append({"type": "cyborg", "at": near + 2.0, "lane": lane, "side": 0, "seed": 11,
		"params": {"panic": false, "host": false, "stand": true, "hold_fire": hold, GantrywayRules.PARAM: 0}})
	layout.length = start + walkway + 120.0
	var dash_length: float = pt.dash_duration * (t.run_speed + pt.dash_speed_bonus)
	match take:
		"drop":
			_pending.append([_first - 0.6 * dash_length, &"dash"])
			_pending.append([_first + 2.0, &"move_left" if side < 0 else &"move_right"])
		"stay":
			_pending.append([_first - 0.6 * dash_length, &"dash"])

	var sfx := load("res://data/audio/sfx_library.tres") as SfxLibrary
	var loadout := Loadout.new()
	loadout.tiers[&"dash"] = 4
	world = RunWorld.new()
	add_child(world)
	world.build(config, layout, tuning, load(RULES_PATH) as GameRules, null, loadout, sfx)
	world.player.setup(world.tuning, world.geo, lane)
	world.player.steady_flash = reduced_flashing
	Settings.flashing_reduced = reduced_flashing
	world.player.god_mode = god
	# The armor, carried and whole, unless --bare.
	world.player.armor_state.carried = not bare
	world.player.armor_state.hits = 0 if bare else world.player.armor_state.max_hits
	world.track.set_hitboxes_visible(hitboxes)
	world.track.gantryway_fell.connect(func(g: Gantryway) -> void:
		print("%5.2f s  %6.1f m  the gantryway over lane %d falls (lands in %.2f s)" % [world.player.elapsed,
			world.player.distance, g.lane, g.tuning.fall_seconds]))
	world.track.gantryway_landed.connect(func(g: Gantryway) -> void:
		print("%5.2f s  %6.1f m  the gantryway landed" % [world.player.elapsed, world.player.distance]))
	world.director.enemy_defeated.connect(func(e: Enemy, cause: StringName) -> void:
		print("%5.2f s  %6.1f m  %s defeated (%s)" % [world.player.elapsed, world.player.distance, e.type_id, cause]))
	world.player.movement_event.connect(func(kind: StringName) -> void:
		print("%5.2f s  %6.1f m  %s" % [world.player.elapsed, world.player.distance, kind]))
	world.player.died.connect(func(cause: String) -> void:
		print("%5.2f s  %6.1f m  died (%s)" % [world.player.elapsed, world.player.distance, cause]))
	print("gantryway over lane %d from %.1f to %.1f m, its pillar at %.1f m pushing %s; a cyborg at %.1f m" % [lane, start,
		start + walkway, _first, "left" if side < 0 else "right", near + 2.0])

	var env := WorldEnvironment.new()
	env.environment = skin.make_environment()
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, 25.0, 0.0)
	sun.light_energy = 0.7
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(sun)
	if close or beside or take == "look":
		camera = Camera3D.new()
		camera.fov = 60.0
		add_child(camera)
		_update_fixed_camera()
	else:
		var run_camera := RunCamera.new()
		add_child(run_camera)
		run_camera.follow(world)
		camera = run_camera
	camera.make_current()
	if take != "look":
		world.start()


func _physics_process(_delta: float) -> void:
	var player: Player = world.player
	while not _pending.is_empty() and player.distance >= float(_pending[0][0]):
		var action: StringName = _pending.pop_front()[1]
		print("%5.2f s  %6.1f m  > %s" % [player.elapsed, player.distance, action])
		if action == &"dash":
			world.powerups.call(&"try_dash")
		else:
			player.press(action)


func _process(_delta: float) -> void:
	if close or beside or take == "look":
		_update_fixed_camera()


## Low behind the runner (--close); or standing beside the track level with the walkway's near third, looking across at
## it (--beside, and --take=look).
func _update_fixed_camera() -> void:
	if close:
		var p: Player = world.player
		camera.position = Vector3(p.position.x * 0.5, 3.4, p.position.z + 6.5)
		camera.look_at(Vector3(p.position.x * 0.5, 1.6, p.position.z - 8.0))
		return
	var at: float = float(_entry["pillar"])
	var x: float = world.geo.lane_x(int(_entry["lane"]))
	var across: float = -1.0 if x > 0.0 else 1.0
	camera.position = Vector3(across * (world.geo.wall_x() - 0.6), 2.4, TrackGeometry.world_z(at - 9.0))
	camera.look_at(Vector3(x, 3.2, TrackGeometry.world_z(at + 9.0)))
