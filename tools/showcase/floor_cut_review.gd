extends Node3D
## Gameplay review for floors that turn into gaps during play (task B4; GDD §9.9): a real RunWorld on a
## hand-built track with one floor cut and its cause (the floor cutter stand-in, until task C2's Buzz
## Overdrive), driven with press() like the tests' RunSim, seen through the game's camera (RunCamera)
## or a high one over the cut.
## The runner starts in the cut's lane, sees the warning (the red line and the rev), switches to the
## lane beside it and runs on alongside: the cutter charges back down its lane, the floor behind it
## goes, it passes, and the gap it leaves runs on ahead beside the runner. A normal hole further on in
## the cut's lane shows the zone's own gap beside the cut's.
##
##   Render:  godot --path . --write-movie build/review/f.png --fixed-fps 10 --quit-after 120
##            res://tools/showcase/floor_cut_review.tscn -- [options]
##   Options (after --):
##     --skin=<zone id>      the zone's look (data/skins/<id>_skin.tres; default city; corporate_plaza
##                           for the plaza; corporate_boss for Hostile Takeover's train,
##                           data/bosses/<id>_skin.tres)
##     --lanes=N             lane count (default 3)
##     --lane=N              the cut's lane (default the middle one)
##     --side=-1|1           the lane the runner escapes to (default: toward the track's middle)
##     --speed=N             the run speed (a zone's: 21 m/s in the City to 25 in the Golden Zone;
##                           default the base 18); the cut keeps its timing in seconds
##     --high                a camera high behind the runner, looking down the cut
##     --top                 a camera 14 m up, looking straight down 30 m ahead of the runner, to see
##                           the bottom of the hole
##     --compare             (task H3) a cut and an ordinary gap of the same stretch side by side, to see
##                           whether the cut's inside shows what the zone's own gap does: 5 lanes (unless
##                           --lanes), the cut open from the start, the runner staying in the middle
##                           between a gap on its left and the cut on its right (--god-like: the cause
##                           never reaches it), and two ordinary 6 m gaps in the outer lanes ahead of them
##                           (SHORT_GAP_AT). --open alone opens the cut at once without the gap
##     --open                the cut is open over its whole stretch from the start
##     --legacy              the cut drawn the way every skin without a look of its own drew it before
##                           task H3 (the default hook's box with a bottom), for before-and-after frames
##     --outer               with --compare: the cut in the outermost lane on the right and the gap in the
##                           outermost on the left, the runner in the middle lane, to see the edges
##                           where a lane's floor runs on to the wall
##     --stay                the runner stays in the cut's lane: its armor blocks the blade, the floor
##                           holds for a second, then it switches out
##     --kill=D              the cutter is killed when the runner reaches distance D: the cut stops there
##     --reduced-flashing    Reduced flashing on (the line holds steady, no sparks)
## Each scripted action and movement event is printed with its time and distance, and the cut's
## warning, charge, meeting point and end, to find the frames (frame = time × render fps).

## --compare's two short gaps (a first look at an ordinary gap, as the runner meets one): where they begin.
const SHORT_GAP_AT: float = 56.0
const TUNING_PATH: String = "res://data/tuning/movement.tres"
const RULES_PATH: String = "res://data/tuning/game_rules.tres"
const Rules = preload("res://scripts/enemies/floor_cutter_rules.gd")

var tuning: MovementTuning
var world: RunWorld
var camera: Camera3D
var high: bool = false
var cut: Dictionary = {}
var _pending: Array = []
var _kill_at: float = INF
var _open: bool = false
var _legacy: bool = false
var _skin: ZoneSkin
var _compare: bool = false
var _outer: bool = false
var _top: bool = false
var _opened: bool = false


func _ready() -> void:
	tuning = load(TUNING_PATH) as MovementTuning
	var skin_id: String = "city"
	var lanes: int = 3
	var lane: int = -1
	var side: int = 0
	var stay: bool = false
	var compare: bool = false
	for arg: String in OS.get_cmdline_user_args():
		var v: String = arg.get_slice("=", 1)
		if arg.begins_with("--skin="):
			skin_id = v
		elif arg.begins_with("--lanes="):
			lanes = clampi(int(v), 3, 8)
		elif arg.begins_with("--lane="):
			lane = int(v)
		elif arg.begins_with("--side="):
			side = signi(int(v))
		elif arg.begins_with("--speed="):
			tuning = tuning.duplicate() as MovementTuning
			tuning.run_speed = maxf(float(v), 5.0)
		elif arg == "--high":
			high = true
		elif arg == "--stay":
			stay = true
		elif arg == "--compare":
			compare = true
			_compare = true
			_open = true
		elif arg == "--open":
			_open = true
		elif arg == "--legacy":
			_legacy = true
		elif arg == "--outer":
			_outer = true
		elif arg == "--top":
			high = true
			_top = true
		elif arg.begins_with("--kill="):
			_kill_at = float(v)
		elif arg == "--reduced-flashing":
			Settings.flashing_reduced = true
			RenderingServer.global_shader_parameter_set(&"reduced_flashing", 1.0)
	if compare:
		lanes = maxi(lanes, 5)
		if lane < 0 or lane >= lanes:
			lane = lanes - 1 if _outer else lanes / 2 + 1
	if lane < 0 or lane >= lanes:
		lane = lanes / 2
	if side == 0:
		side = 1 if lane < lanes / 2 else -1
	if lane + side < 0 or lane + side >= lanes:
		side = -side
	var skin: ZoneSkin = GreyboxSkin.new()
	_skin = skin
	var skin_path: String = "res://data/skins/%s_skin.tres" % skin_id
	if not ResourceLoader.exists(skin_path):
		# A boss arena's skin (corporate_boss: Hostile Takeover's train).
		skin_path = "res://data/bosses/%s_skin.tres" % skin_id
	if ResourceLoader.exists(skin_path):
		skin = load(skin_path) as ZoneSkin
		_skin = skin
	else:
		push_warning("floor_cut_review: no skin at %s; using the grey box" % skin_path)

	var t: FloorCutterTuning = Rules.tuning()
	var v: float = tuning.run_speed
	var speed: float = t.charge_speed * tuning.pace()
	var charge: float = t.charge_seconds * (v + speed)
	var warn: float = charge + t.warn_seconds * v
	var end: float = 60.0 + warn
	cut = FloorCutPlan.make(lane, end, warn, charge, speed, v, t.run_past, t.keep())
	var layout := LevelLayout.new()
	layout.lane_count = lanes
	layout.cuts.append(cut)
	if not compare:
		# (--compare is about the hole alone: no cause, no warning line over it.)
		layout.enemies.append({"type": "floor_cutter", "at": end, "lane": lane, "side": 0, "seed": 1, "params": {}})
	# A normal hole further on in the cut's lane, to compare the zone's gap with the cut's.
	layout.gaps.append({"lane": lane, "start": end + 40.0, "end": end + 46.0})
	if compare:
		# The same stretch as an ordinary gap, two lanes over from the cut, the runner between them.
		layout.gaps.append({"lane": 0 if _outer else lane - 2, "start": float(cut["start"]), "end": end})
		# And two ordinary 6 m gaps ahead of the stretch, either side of the runner's lane's neighbours, which
		# the runner sees in front of it first (the end face and the bottom of a gap as they're usually met).
		for short_lane: int in [0, lane + 1 if lane + 1 < lanes else lane - 3]:
			layout.gaps.append({"lane": short_lane, "start": SHORT_GAP_AT, "end": SHORT_GAP_AT + 6.0})
	layout.length = end + 220.0
	var meet: float = FloorCutPlan.meet(cut, v)
	print("cut in lane %d: %.1f-%.1f m; warning at %.1f m (%.2f s), charge at %.1f m (%.2f s), meets the runner at %.1f m (%.2f s), ends with the runner at %.1f m (%.2f s)" % [
		lane, cut["start"], end, FloorCutPlan.warn_at(cut), FloorCutPlan.warn_at(cut) / v, FloorCutPlan.charge_at(cut),
		FloorCutPlan.charge_at(cut) / v, meet, meet / v, FloorCutPlan.done_at(cut, v), FloorCutPlan.done_at(cut, v) / v])

	var config := LevelConfig.new()
	config.lane_count = lanes
	config.skin = skin
	var sfx := load("res://data/audio/sfx_library.tres") as SfxLibrary
	var loadout := Loadout.new()
	world = RunWorld.new()
	add_child(world)
	world.build(config, layout, tuning, load(RULES_PATH) as GameRules, null, loadout, sfx)
	world.player.setup(tuning, world.geo, lanes / 2 if _outer else (lane - 1 if compare else lane))
	if compare:
		pass
	elif stay:
		world.player.armor = 1
		_pending.append([meet + 3.0, &"move_left" if side < 0 else &"move_right"])
	else:
		_pending.append([FloorCutPlan.warn_at(cut) + 10.0, &"move_left" if side < 0 else &"move_right"])
	world.player.movement_event.connect(func(kind: StringName) -> void:
		print("%5.2f s  %6.1f m  %s" % [world.player.elapsed, world.player.distance, kind]))

	var env := WorldEnvironment.new()
	env.environment = skin.make_environment()
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, 25.0, 0.0)
	sun.light_energy = 0.7
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(sun)
	if high:
		camera = Camera3D.new()
		camera.fov = 62.0
		add_child(camera)
		_update_high_camera()
	else:
		var run_camera := RunCamera.new()
		add_child(run_camera)
		run_camera.follow(world)
		camera = run_camera
	camera.make_current()
	world.start()


func _physics_process(_delta: float) -> void:
	var player: Player = world.player
	if (_open or _legacy) and not _opened:
		var track_cut: FloorCut = world.track.floor_cut(int(cut["lane"]), float(cut["end"]))
		if track_cut != null:
			_opened = true
			if _legacy:
				_use_default_look(track_cut)
			if _open:
				track_cut.advance_to(float(cut["start"]))
	while not _pending.is_empty() and player.distance >= float(_pending[0][0]):
		var action: StringName = _pending.pop_front()[1]
		print("%5.2f s  %6.1f m  > %s" % [player.elapsed, player.distance, action])
		player.press(action)
	if player.distance >= _kill_at:
		_kill_at = INF
		for e: Enemy in world.director.active:
			if is_instance_valid(e) and e.alive and e.type_id == &"floor_cutter":
				print("%5.2f s  %6.1f m  > the cutter is killed" % [player.elapsed, player.distance])
				e.defeat(&"weapon")


func _process(_delta: float) -> void:
	if high:
		_update_high_camera()


## The cut's look as it was before task H3 for the City, Gangland and the Marketplace: the default hook's
## dark box with a bottom, drawn in the kit's plain materials (for before-and-after frames).
func _use_default_look(track_cut: FloorCut) -> void:
	var look: Node3D = track_cut.get_node("Look")
	for child: Node in look.get_children():
		look.remove_child(child)
		child.queue_free()
	var section: FloorCutSection = track_cut.section
	section.statics.clear()
	section.spans.clear()
	section.fronts.clear()
	section.fars.clear()
	var edge: Variant = _skin.get("gap_edge_color")
	var inside: Variant = _skin.get("gap_inside_color")
	ZoneSkin.standard_floor_cut(look, section, MeshKit.solid(), MeshKit.glow(), {
		"edge": edge if edge is Color else ZoneSkin.CUT_EDGE_COLOR,
		"inside": inside if inside is Color else ZoneSkin.CUT_INSIDE_COLOR,
	})
	track_cut.call("_apply")


## High behind the runner and over the cut's lane, looking down the track: the cut's whole stretch.
func _update_high_camera() -> void:
	var p: Player = world.player
	var x: float = world.geo.lane_x(int(cut["lane"]))
	if _compare:
		x = world.geo.lane_x(world.geo.lane_count / 2 if _outer else int(cut["lane"]) - 1)
	if _top:
		camera.position = Vector3(x, 14.0, p.position.z - 30.0)
		camera.look_at(Vector3(x, 0.0, p.position.z - 30.0), Vector3(0.0, 0.0, -1.0))
		return
	camera.position = Vector3(x * 0.6, 9.0, p.position.z + 9.0)
	camera.look_at(Vector3(x, 0.0, p.position.z - 22.0))
