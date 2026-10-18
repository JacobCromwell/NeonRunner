extends TestSuite
## The Casino's intro (CasinoIntro; the owner's beats, October 18, 2026): its slot (before Casino 1); its two sounds; at 3,
## 5 and 6 lanes the zone's look and lanes; the Brass Lotus standing back in an opening of the left wall, its steps rising
## to its doors; the car (Gangland's outro's) driving down the street and pulling up beside the steps, clear of them, its
## door up while the runner gets out; the runner out beside it, then at the foot of the steps facing them and looking up;
## the Chairman at the top, a woman either side of him, shaking hands with each greeter (their right hands meeting), then
## through the doorway with the women and gone before the cut back to the runner; the camera in the street or the casino's
## opening, never under the steps; the zone's title card; what it costs. Then skipping, and the App's flow (skipping it
## starts Casino 1).

const LANES: Array[int] = [3, 5, 6]
const SFX_PATH: String = "res://data/audio/sfx_library.tres"
const SCENE: String = "res://scenes/cinematics/casino_intro.tscn"
const STEP: float = 1.0 / 30.0
## Its own sounds (tools/asset_gen/sfx_bank_casino_intro.gd), and every sound effect is under this long.
const SOUNDS: Array[String] = ["car_cruise", "car_arrive"]
const MAX_SOUND_SECONDS: float = 2.5
## The runner stops within this of their places, and faces the steps within this (degrees).
const STAND_SLACK: float = 0.08
const FACE_SLACK: float = 12.0
## Shaking hands, the two right hands are this close at the handshake's middle (metres).
const SHAKE_REACH: float = 0.16
## Going in, everyone keeps this far inside the doorway's sides (metres).
const DOOR_CLEARANCE: float = 0.15
## The car keeps this far out from the foot of the steps (metres).
const CAR_CLEARANCE: float = 0.3
## Over open street the camera keeps under this (nothing hangs lower).
const CAMERA_TOP: float = 9.5
## Costs, headless (generous: they catch a gross regression; the measured numbers are printed), and what its props may
## add to a frame.
const SETUP_BUDGET_MSEC: float = 1500.0
const STEP_BUDGET_MSEC: float = 30.0
const PROP_DRAW_CALLS: int = 120

var sfx: SfxLibrary
var _music_before: StringName = &""


func run() -> void:
	sfx = load(SFX_PATH) as SfxLibrary
	var music: MusicDirector = MusicDirector.instance()
	_music_before = music.current() if music != null else &""
	_test_slot()
	_test_sounds()
	var lanes_pc: int = App.rules.lanes_pc
	for lanes: int in LANES:
		App.rules.lanes_pc = lanes
		await _check_intro(lanes)
	App.rules.lanes_pc = lanes_pc
	await _test_skip()
	await _test_app_flow()
	if music != null:
		if _music_before == &"":
			music.stop(0.0)
		else:
			music.play(_music_before, 0.0)


func _step() -> CampaignStep:
	return App.campaign.step("casino/intro")


## A CasinoIntro for the Casino's intro slot, in the tree, its clock stepped by the test.
func _start() -> CasinoIntro:
	var s: CampaignStep = _step()
	if s == null or s.cinematic == null or not s.cinematic.is_built():
		return null
	var seq := (load(s.cinematic.scene) as PackedScene).instantiate() as CasinoIntro
	if seq == null:
		return null
	tree.root.add_child(seq)
	seq.play(s.cinematic, s)
	seq.set_process(false)
	return seq


func _free(node: Node) -> void:
	if node != null and is_instance_valid(node):
		node.queue_free()
	await tree.process_frame


func _test_slot() -> void:
	var s: CampaignStep = _step()
	check(s != null and s.cinematic.is_built() and s.cinematic.scene == SCENE and s.zone.intro == s.cinematic,
		"the Casino's intro slot is built: the runner pulling up at the Brass Lotus")
	var next: CampaignStep = App.campaign.next_step(s) if s != null else null
	check(next != null and next.id == "casino/1", "Casino 1 follows it")
	var seq := (load(SCENE) as PackedScene).instantiate()
	check(seq is CasinoIntro and (seq as CasinoIntro).numbers != null, "its scene is a CasinoIntro with its numbers")
	seq.free()


## Its sounds are in the library, each a sound file under the sound effects' length.
func _test_sounds() -> void:
	for v: String in SOUNDS:
		var stream := sfx.stream(StringName(v)) as AudioStreamWAV
		check(sfx.has_file(StringName(v)) and stream != null, "its sound %s is in the library" % v)
		if stream != null:
			check(stream.get_length() > 0.5 and stream.get_length() < MAX_SOUND_SECONDS,
				"%s is %.2f s (under %.1f s)" % [v, stream.get_length(), MAX_SOUND_SECONDS])


# --- The beats -----------------------------------------------------------------------------------

func _check_intro(lanes: int) -> void:
	var t0: int = Time.get_ticks_usec()
	var seq: CasinoIntro = _start()
	var setup_msec: float = (Time.get_ticks_usec() - t0) / 1000.0
	if seq == null:
		check(false, "%d lanes: the intro starts" % lanes)
		return
	var n: CasinoIntroTuning = seq.n
	var stage: CineStage = seq.stage
	var lotus: CasinoIntroLotus = seq.lotus
	var tag: String = "%d lanes" % lanes
	check(stage.geo.lane_count == lanes and stage.skin == _step().zone.skin,
		"%s: it plays on the zone's look, in the level's lanes" % tag)
	check(seq.playing.problems(sfx).is_empty(), "%s: its timeline has no problems (%s)" % [tag, seq.playing.problems(sfx)])
	# The casino: back in an opening of the left wall, its steps rising to its doors.
	check(stage.wall_open(-1, n.lotus_at - n.frontage * 0.5 + 0.5) and stage.wall_open(-1, n.lotus_at + n.frontage * 0.5 - 0.5)
		and not stage.wall_open(-1, n.lotus_at - n.frontage * 0.5 - 1.0) and not stage.wall_open(-1, n.lotus_at + n.frontage * 0.5 + 1.0),
		"%s: the left wall is open along the casino's frontage, and only there" % tag)
	check(lotus.foot_x <= 0.0 and lotus.face_x < lotus.top_x and lotus.top_x < lotus.foot_x
		and is_equal_approx(lotus.step_height(lotus.foot_x + 0.01), 0.0) and is_equal_approx(lotus.step_height(lotus.top_x - 0.01), n.stairs_rise),
		"%s: its front stands back from the street behind its steps, which rise from the street to the terrace" % tag)
	var car_numbers := load(CasinoIntro.CAR_NUMBERS_PATH) as GanglandOutroTuning
	check(car_numbers != null and seq.car.size == car_numbers.car_size and seq.car.paint == car_numbers.car_paint,
		"%s: the car is Gangland's outro's violet sports car" % tag)
	# The car pulls up beside the steps, clear of them, in the street.
	var stop: Vector3 = seq.car_stop
	var stairs_half: float = n.stairs_width * 0.5
	check(absf(stop.z - n.lotus_at) < stairs_half and stop.x - seq.car_size.x * 0.5 > stage.wall_x(-1) + lotus.foot_x + CAR_CLEARANCE
		and stop.x + seq.car_size.x * 0.5 < stage.wall_x(1),
		"%s: the car stops in the street beside the steps (at %s)" % [tag, stop])
	check(seq.car_at(0.0).z < stop.z - 30.0 and is_equal_approx(seq.car_remaining(n.stop_at), 0.0),
		"%s: it drives in from far down the street and stops at %.1f s" % [tag, n.stop_at])

	var runner := seq.actors[&"runner"] as CineActorNode
	var worst_step: float = 0.0
	var step_total: float = 0.0
	var steps: int = 0
	var camera_out: String = ""
	var shake_best: Array[float] = [INF, INF]
	var flank: String = ""
	var through: String = ""
	var shown_early: bool = false
	var draw_calls: int = 0
	var checked: Dictionary = {}
	var last_z: float = -INF
	var backwards: bool = false
	while not seq.done:
		var s0: int = Time.get_ticks_usec()
		seq.advance(STEP)
		var ms: float = (Time.get_ticks_usec() - s0) / 1000.0
		worst_step = maxf(worst_step, ms)
		step_total += ms
		steps += 1
		if seq.done:
			break
		var t: float = seq.time
		draw_calls = maxi(draw_calls, seq.props_draw_calls())
		# The car only ever drives forward.
		var cz: float = stage.to_track(seq.car.global_position).z
		backwards = backwards or cz < last_z - 0.01
		last_z = cz
		# The camera: in the street or the casino's opening, over the steps there, under what hangs over the street.
		var cam: Vector3 = stage.to_track(seq.camera.global_position)
		var in_opening: bool = absf(cam.z - n.lotus_at) < n.frontage * 0.5 and cam.x > stage.wall_x(-1) + lotus.face_x
		var floor_y: float = lotus.step_height(cam.x - stage.wall_x(-1)) if in_opening else 0.0
		if camera_out == "" and ((cam.x < stage.wall_x(-1) and not in_opening) or cam.x > stage.wall_x(1) or cam.y > CAMERA_TOP
				or cam.y < floor_y + 0.2):
			camera_out = "%.2f s at %s" % [t, cam]
		if t < n.door_up_at - 0.01 and runner.visible:
			shown_early = true
		# The women either side of him along the street while they're with him.
		if seq.chairman.visible and flank == "":
			var c: Vector3 = stage.to_track(seq.chairman.global_position)
			var b: Vector3 = stage.to_track(seq.escort_black.global_position)
			var w: Vector3 = stage.to_track(seq.escort_blonde.global_position)
			if not (b.z < c.z - 0.3 and w.z > c.z + 0.3 and b.distance_to(c) < 1.3 and w.distance_to(c) < 1.3):
				flank = "%.2f s: him %s, black %s, blonde %s" % [t, c, b, w]
			# Through the doorway, inside its sides.
			for p: Vector3 in [c, b, w]:
				var x: float = p.x - stage.wall_x(-1)
				if through == "" and x < lotus.face_x + 0.2 and x > lotus.face_x - CasinoIntroLotus.FRONT_THICK - 0.2 \
						and absf(p.z - n.lotus_at) > n.door_width * 0.5 - DOOR_CLEARANCE:
					through = "%.2f s at %s" % [t, p]
		# The handshakes: at their middle, his right hand and the greeter's meet.
		var shakes: Array[float] = [n.shake_a_at, n.shake_b_at]
		for i: int in 2:
			if absf(t - (shakes[i] + n.shake_seconds * 0.5)) < STEP * 0.6:
				var his: Vector3 = seq.chairman.hand_point(1)
				var theirs: Vector3 = seq.greeters[i].hand_point(1)
				shake_best[i] = minf(shake_best[i], his.distance_to(theirs))
		if not checked.has("door") and t >= n.get_out_at:
			checked["door"] = true
			check(runner.visible and seq.car.door_open > 0.95, "%s: the car's door is up as the runner gets out" % tag)
		if not checked.has("out") and t >= seq.t_out + 0.05:
			checked["out"] = true
			check(runner.track_position.distance_to(seq.out_point) < STAND_SLACK,
				"%s: the runner stands beside the car once out (%.2f m off)" % [tag, runner.track_position.distance_to(seq.out_point)])
		if not checked.has("foot") and t >= seq.t_foot + 1.0:
			checked["foot"] = true
			var face_err: float = absf(rad_to_deg(angle_difference(runner.yaw, PI * 0.5)))
			check(runner.track_position.distance_to(seq.foot_stop) < STAND_SLACK and face_err < FACE_SLACK and seq.t_foot < n.greet_shot_at - 0.5,
				"%s: the runner reaches the foot of the steps and faces up them (%.2f m off, %.1f° off, at %.2f s)" % [
				tag, runner.track_position.distance_to(seq.foot_stop), face_err, seq.t_foot])
		if not checked.has("up") and t >= n.greet_shot_at:
			checked["up"] = true
			check(rad_to_deg(runner.look_up) > n.look_up * 0.8, "%s: they look up the steps (%.0f°)" % [tag, rad_to_deg(runner.look_up)])
			var c: Vector3 = stage.to_track(seq.chairman.global_position)
			check(seq.chairman.visible and absf(c.y - n.stairs_rise) < 0.05 and c.x - stage.wall_x(-1) < lotus.top_x,
				"%s: the Chairman is at the top of the steps, on the terrace" % tag)
		if not checked.has("gone") and t >= n.runner_shot_at:
			checked["gone"] = true
			check(not seq.chairman.visible and not seq.escort_black.visible and not seq.escort_blonde.visible,
				"%s: he and the women are gone inside by the cut back to the runner" % tag)
		if not checked.has("door_down") and t >= n.door_down_at + n.door_seconds + 0.1:
			checked["door_down"] = true
			check(seq.car.door_open < 0.01, "%s: the car's door is down again" % tag)
	check(not shown_early, "%s: the runner isn't drawn until the car's door opens" % tag)
	check(not backwards, "%s: the car never rolls back" % tag)
	check(shake_best[0] < SHAKE_REACH and shake_best[1] < SHAKE_REACH,
		"%s: he shakes hands with each of the two (their right hands %.2f and %.2f m apart)" % [tag, shake_best[0], shake_best[1]])
	check(flank == "", "%s: a woman either side of him throughout (%s)" % [tag, flank])
	check(through == "", "%s: everyone goes in through the doorway, not its sides (%s)" % [tag, through])
	check(camera_out == "", "%s: the camera keeps in the street or the casino's opening (%s)" % [tag, camera_out])
	var heard := PackedStringArray()
	var titled: bool = false
	for line: String in seq.log_lines:
		if line.begins_with("sound car_"):
			heard.append(line.get_slice(" ", 1))
		titled = titled or line.begins_with("text ")
	check(heard.has("car_cruise") and heard.has("car_arrive") and heard.has("car_door"), "%s: the car's sounds (%s)" % [tag, heard])
	check(titled, "%s: the zone's title card comes up at the end" % tag)
	var mean: float = step_total / maxf(float(steps), 1.0)
	print("    %s: set up %.1f ms, a step %.2f ms on average, %.2f ms at worst; props %d draw calls" % [tag, setup_msec, mean,
		worst_step, draw_calls])
	check(setup_msec < SETUP_BUDGET_MSEC and worst_step < STEP_BUDGET_MSEC and draw_calls <= PROP_DRAW_CALLS,
		"%s: it costs little (set up %.0f ms, a step at worst %.1f ms, %d draw calls)" % [tag, setup_msec, worst_step, draw_calls])
	await _free(seq)


# --- Skipping and the App ----------------------------------------------------------------------------

func _test_skip() -> void:
	for at: float in [1.0, 8.0, 15.0, 22.0]:
		var seq: CasinoIntro = _start()
		if seq == null:
			return
		var ends: Array[int] = [0]
		seq.finished.connect(func() -> void: ends[0] += 1)
		while not seq.done and seq.time < at - 0.0001:
			seq.advance(STEP)
		seq.skip()
		check(ends[0] == 1 and seq.done and seq.skipped and not seq.stage.visible and not seq.overlay.visible
			and not seq.lotus.is_visible_in_tree() and not seq.chairman.visible,
			"skip() at %.1f s ends it at once, and nothing of it shows (its props too)" % at)
		seq.skip()
		check(ends[0] == 1, "finished fires once, at %.1f s" % at)
		await _free(seq)


func _test_app_flow() -> void:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	var saved: Profile = App.profile
	App.profile = SampleProfiles.fresh()
	App.play_step(_step())
	await physics_frames(10)
	var c := App.playing_cinematic() as CasinoIntro
	check(c != null and c.step.id == "casino/intro" and App.screen == null and App.run == null,
		"the Casino's intro slot plays it, in the world, with no screen over it")
	var press := InputEventAction.new()
	press.action = &"pause"
	press.pressed = true
	tree.root.push_input(press)
	await physics_frames(3)
	check(App.run != null and App.run.context.step.id == "casino/1" and App.profile.is_completed("casino/intro")
		and App.playing_cinematic() == null and not tree.paused,
		"the pause action skips it: Casino 1 starts at once, and nothing is paused")
	App.show_title()
	await tree.process_frame
	App.profile = saved
	main.queue_free()
	App.main = null
	await tree.process_frame
