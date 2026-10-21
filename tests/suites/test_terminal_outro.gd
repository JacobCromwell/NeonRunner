extends TestSuite
## The Terminal's outro (TerminalOutro; the owner's beats, October 21, 2026): its slot (after Terminal 2, before the Golden
## Zone's intro); its nine sounds; the new poses (brace, hands_up); at 3, 5 and 6 lanes the zone's look and lanes; the
## train (a string of cars, its nose and tail where the numbers put them, in the street, nothing but the runner's lane
## beside it); the runner jogging in and stopping short of its tail; the camera never inside the train or out of the
## street; at the door the runner's hands on the handle through the shaking, the leaf rattling harder in the violent shake
## than in the first, the fist on the door at each bang, the hands thrown up over their head; the screech hidden until it
## pops up, then seen through the door's window; the door sliding open and shut, the runner stepping up and in and gone by the
## cut; the train's lights (never flickering with Reduced flashing), it standing still until it starts, moving only
## forward, and far enough off by the end to be out of sight in the haze; what it costs. Then skipping, and the App's flow
## (skipping it starts the Golden Zone's intro).

const LANES: Array[int] = [3, 5, 6]
const SFX_PATH: String = "res://data/audio/sfx_library.tres"
const SCENE: String = "res://scenes/cinematics/terminal_outro.tscn"
const STEP: float = 1.0 / 30.0
## Its own sounds (tools/asset_gen/sfx_bank_terminal_outro.gd), and every sound effect is under this long.
const SOUNDS: Array[String] = ["door_rattle", "door_rattle_hard", "door_bang", "train_door_open", "train_door_close",
	"train_start", "train_depart", "train_rush", "screech_squeak"]
const MAX_SOUND_SECONDS: float = 2.5
## The runner stops within this of their places (metres), and faces the door within this (degrees).
const STAND_SLACK: float = 0.08
const FACE_SLACK: float = 12.0
## A hand is this close to what it holds or strikes (metres): the fist is a block, the bar thin.
const HAND_REACH: float = 0.13
## The camera stays under this over open street and beyond a kerb by at most this (nothing hangs lower; the second track's
## parked cars start further out).
const CAMERA_TOP: float = 9.5
const CAMERA_KERB: float = 1.0
## The body of the train, for keeping the camera out of it (half width, height).
const BODY_HALF: float = 1.7
const BODY_HEIGHT: float = 3.8
## Costs, headless (generous: they catch a gross regression; the measured numbers are printed), and what its props may add
## to a frame.
const SETUP_BUDGET_MSEC: float = 1500.0
const STEP_BUDGET_MSEC: float = 30.0
const PROP_DRAW_CALLS: int = 30

var sfx: SfxLibrary
var _music_before: StringName = &""


func run() -> void:
	sfx = load(SFX_PATH) as SfxLibrary
	var music: MusicDirector = MusicDirector.instance()
	_music_before = music.current() if music != null else &""
	_test_slot()
	_test_sounds()
	_test_poses()
	var lanes_pc: int = App.rules.lanes_pc
	for lanes: int in LANES:
		App.rules.lanes_pc = lanes
		await _check_outro(lanes)
	App.rules.lanes_pc = lanes_pc
	await _test_lights()
	await _test_skip()
	await _test_app_flow()
	if music != null:
		if _music_before == &"":
			music.stop(0.0)
		else:
			music.play(_music_before, 0.0)


func _step() -> CampaignStep:
	return App.campaign.step("terminal/outro")


## A TerminalOutro for the Terminal's outro slot, in the tree, its clock stepped by the test.
func _start() -> TerminalOutro:
	var s: CampaignStep = _step()
	if s == null or s.cinematic == null or not s.cinematic.is_built():
		return null
	var seq := (load(s.cinematic.scene) as PackedScene).instantiate() as TerminalOutro
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
	check(s != null and s.cinematic.is_built() and s.cinematic.scene == SCENE and s.zone.outro == s.cinematic,
		"the Terminal's outro slot is built: the runner and the abandoned metro train")
	var prev: CampaignStep = App.campaign.step("terminal/2")
	var next: CampaignStep = App.campaign.next_step(prev) if prev != null else null
	check(next != null and next.id == "terminal/outro", "it follows Terminal 2 (the Terminal has no boss)")
	var after: CampaignStep = App.campaign.next_step(s) if s != null else null
	check(after != null and after.id == "golden/intro", "the Golden Zone's intro follows it")
	var seq := (load(SCENE) as PackedScene).instantiate()
	check(seq is TerminalOutro and (seq as TerminalOutro).numbers != null, "its scene is a TerminalOutro with its numbers")
	seq.free()


## Its sounds are in the library, each a sound file under the sound effects' length.
func _test_sounds() -> void:
	for v: String in SOUNDS:
		var stream := sfx.stream(StringName(v)) as AudioStreamWAV
		check(sfx.has_file(StringName(v)) and stream != null, "its sound %s is in the library" % v)
		if stream != null:
			check(stream.get_length() > 0.3 and stream.get_length() < MAX_SOUND_SECONDS,
				"%s is %.2f s (under %.1f s)" % [v, stream.get_length(), MAX_SOUND_SECONDS])


## The new poses: `brace` and `hands_up` are poses the toolkit knows; both start from standing at ease, and `hands_up`
## ends there; flung up, both arms are above the head.
func _test_poses() -> void:
	check(CinePoses.is_cine_pose(&"brace") and CinePoses.is_cine_pose(&"hands_up")
		and CineTimeline.RUNNER_POSES.has(&"brace") and CineTimeline.RUNNER_POSES.has(&"hands_up"),
		"brace and hands_up are poses a key may name")
	var at_ease := HumanoidPose.new()
	CinePoses.walk(at_ease, 0.0, 0.0, 0.0)
	var p := HumanoidPose.new()
	var worst: float = 0.0
	for pose: StringName in [&"brace", &"hands_up"]:
		CinePoses.runner(p, pose, 0.0, 0.0, 0.7)
		for j: int in HumanoidPose.JOINT_COUNT:
			worst = maxf(worst, (p.rot[j] - at_ease.rot[j]).length())
	CinePoses.runner(p, &"hands_up", 1.0, 0.0, 0.7)
	for j: int in HumanoidPose.JOINT_COUNT:
		worst = maxf(worst, (p.rot[j] - at_ease.rot[j]).length())
	check(worst < 0.01, "both poses start at standing at ease, hands_up ends there too (worst joint %.4f rad off)" % worst)
	CinePoses.runner(p, &"hands_up", 0.35, 0.0, 0.7)
	var raised: bool = true
	for joint: int in [HumanoidPose.UPPER_ARM_L, HumanoidPose.UPPER_ARM_R]:
		raised = raised and rad_to_deg(p.rot[joint].x) > 120.0
	check(raised, "flung up, both arms are raised above the head")
	CinePoses.runner(p, &"brace", 1.0, 0.0, 0.7)
	check(rad_to_deg(p.rot[HumanoidPose.CHEST].x) < -8.0 and rad_to_deg(p.rot[HumanoidPose.UPPER_ARM_R].x) > 30.0,
		"braced, the runner leans in with their arms forward")


# --- The beats -----------------------------------------------------------------------------------

func _check_outro(lanes: int) -> void:
	var t0: int = Time.get_ticks_usec()
	var seq: TerminalOutro = _start()
	var setup_msec: float = (Time.get_ticks_usec() - t0) / 1000.0
	if seq == null:
		check(false, "%d lanes: the outro starts" % lanes)
		return
	var n: TerminalOutroTuning = seq.n
	var stage: CineStage = seq.stage
	var train: TerminalTrainModel = seq.train
	var tag: String = "%d lanes" % lanes
	check(stage.geo.lane_count == lanes and stage.skin == _step().zone.skin,
		"%s: it plays on the zone's look, in the level's lanes" % tag)
	check(seq.playing.problems(sfx).is_empty(), "%s: its timeline has no problems (%s)" % [tag, seq.playing.problems(sfx)])
	# The train: cars end to end, its nose where the numbers put it, in the street, on a track lane.
	var length: float = TerminalTrainModel.length_of(n.cars)
	check(is_equal_approx(train.length(), length) and is_equal_approx(seq.nose_z - seq.tail_z, length) and length > 40.0,
		"%s: the train is %d cars, %.1f m from nose to tail" % [tag, n.cars, length])
	check(seq.train_x - TerminalTrainModel.WALL > stage.wall_x(-1) and seq.train_x + TerminalTrainModel.WALL < stage.wall_x(1),
		"%s: it stands inside the street (its middle at %.2f)" % [tag, seq.train_x])
	check(absf(seq.run_x - seq.train_x) > TerminalTrainModel.WALL + 0.35 and seq.run_x < stage.wall_x(1),
		"%s: the runner's lane is clear of it (x %.2f beside it at %.2f)" % [tag, seq.run_x, seq.train_x])
	check(seq.nose_z + 6.0 < n.stage_length and seq.tail_z - n.run_speed * n.stop_at > 0.0,
		"%s: the street under it is long enough" % tag)
	var door_world: Vector3 = stage.to_track(train.global_position)
	check(absf(door_world.x - seq.train_x) < 0.001 and absf(door_world.z - seq.nose_z) < 0.001 and train.door_open < 0.01,
		"%s: it stands with its nose at the numbers' place, its door shut" % tag)

	var runner := seq.actors[&"runner"] as CineActorNode
	var hand_l: Node3D = runner.avatar.rig.joint(&"hand_l")
	var hand_r: Node3D = runner.avatar.rig.joint(&"hand_r")
	var head: Node3D = runner.avatar.rig.joint(&"head")
	var worst_step: float = 0.0
	var step_total: float = 0.0
	var steps: int = 0
	var camera_out: String = ""
	var runner_in: String = ""
	var draw_calls: int = 0
	var checked: Dictionary = {}
	var last_moved: float = 0.0
	var backwards: bool = false
	var early_move: bool = false
	var rattle_a: float = 0.0
	var rattle_b: float = 0.0
	var rattle_pause: float = 0.0
	var grip_worst: float = 0.0
	var grip_n: int = 0
	var bang_best: Array[float] = []
	for k: int in n.bangs:
		bang_best.append(INF)
	var hands_best: float = -INF
	var in_window: float = INF
	var screech_early: bool = false
	var screech_seen: bool = false
	var screech_out: String = ""
	var door_max: float = 0.0
	var door_leaf: float = 0.0
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
		# The camera: in the street (or just over its kerb), under what hangs over it, above the floor, never in the train.
		var cam: Vector3 = stage.to_track(seq.camera.global_position)
		var nose: float = seq.nose_z + seq.moved
		var inside_train: bool = absf(cam.x - seq.train_x) < BODY_HALF and cam.y < BODY_HEIGHT and cam.z < nose + 0.05 \
			and cam.z > nose - length - 0.05
		if camera_out == "" and (cam.x < stage.wall_x(-1) - 0.2 or cam.x > stage.wall_x(1) + CAMERA_KERB or cam.y > CAMERA_TOP
				or cam.y < 0.45 or inside_train):
			camera_out = "%.2f s at %s (train nose %.1f)" % [t, cam, nose]
		# The runner: not through the train's body except in at its door.
		if runner.visible and runner_in == "":
			var p: Vector3 = runner.track_position
			var in_body: bool = absf(p.x - seq.train_x) < BODY_HALF - 0.1 and p.z < nose - 0.05 and p.z > nose - length
			var through_door: bool = absf(p.x - seq.train_x) + 0.3 <= TerminalTrainModel.DOOR_HALF + 0.02 and p.z > nose - 2.0
			if in_body and not through_door:
				runner_in = "%.2f s at %s" % [t, p]
		# The train stands until it starts, and goes only forward.
		if t < n.start_at - 0.01 and seq.moved > 0.0:
			early_move = true
		backwards = backwards or seq.moved < last_moved - 0.0001
		last_moved = seq.moved
		# The leaf's rattle: its offset from where its slide puts it.
		var slide: float = -TerminalTrainModel.SLIDE * smoothstep(0.0, 1.0, train.door_open)
		var rattle: float = (train.door_node.position - Vector3(slide, 0.0, 0.0)).length()
		if t >= n.shake_a_at and t < n.shake_a_at + n.shake_a_seconds:
			rattle_a = maxf(rattle_a, rattle)
		elif t >= n.shake_b_at and t < n.shake_b_at + n.shake_b_seconds:
			rattle_b = maxf(rattle_b, rattle)
		elif t >= n.shake_a_at + n.shake_a_seconds + 0.1 and t < n.shake_b_at - 0.1:
			rattle_pause = maxf(rattle_pause, rattle)
		door_max = maxf(door_max, train.door_open)
		if t > n.open_at + n.open_seconds + 0.05 and t < n.close_at:
			door_leaf = minf(door_leaf, train.door_node.position.x)
		# The hands: on the handle through both shakes (midway through each heave's peaks), the right fist on the door at each
		# bang, both hands up over the head as they throw them up.
		var handle: Vector3 = train.global_transform * (TerminalTrainModel.handle_point() + train.door_node.position)
		var fist_l: Vector3 = hand_l.global_transform * Vector3(0.0, -CineActorNode.GRIP_REACH, 0.0)
		var fist_r: Vector3 = hand_r.global_transform * Vector3(0.0, -CineActorNode.GRIP_REACH, 0.0)
		if (t > n.shake_a_at + 0.05 and t < n.shake_a_at + n.shake_a_seconds - 0.05) \
				or (t > n.shake_b_at + 0.3 and t < n.shake_b_at + n.shake_b_seconds - 0.3):
			grip_n += 1
			var bar_lo: Vector3 = handle - Vector3(0.0, 0.33, 0.0)
			var bar_hi: Vector3 = handle + Vector3(0.0, 0.33, 0.0)
			grip_worst = maxf(grip_worst, maxf(_segment_distance(fist_l, bar_lo, bar_hi), _segment_distance(fist_r, bar_lo, bar_hi)))
		for k: int in n.bangs:
			if absf(t - seq.bang_time(k)) < 0.1:
				# On the door: the fist at the leaf's face (a plane at its depth, the leaf's rattle with it), at its closest
				# in the moment of the strike.
				var leaf: Vector3 = train.global_transform * Vector3(0.0, 0.0, TerminalTrainModel.LEAF_BACK + train.door_node.position.z)
				bang_best[k] = minf(bang_best[k], absf(fist_r.z - leaf.z))
		if t > n.hands_up_at + 0.55 and t < n.hands_up_at + 0.9:
			hands_best = maxf(hands_best, minf(fist_l.y, fist_r.y) - head.global_position.y)
		# The screech: hidden until it pops up, then its head seen through the door's window from the camera.
		if t < n.pop_at - 0.05 and seq.screech.visible:
			screech_early = true
		if t > n.pop_at + 0.45 and t < n.pop_at + 0.75:
			screech_seen = screech_seen or seq.screech.visible
			var neck: Vector3 = train.global_transform.affine_inverse() * seq.screech.neck_point()
			var eye: Vector3 = train.global_transform.affine_inverse() * seq.camera.global_position
			var window_z: float = TerminalTrainModel.window_point().z
			var along: float = (window_z - eye.z) / (neck.z - eye.z)
			var hit: Vector3 = eye + (neck - eye) * along
			var off: float = maxf(absf(hit.x) - TerminalTrainModel.WINDOW_HALF,
				maxf(TerminalTrainModel.WINDOW_LOW - hit.y, hit.y - TerminalTrainModel.WINDOW_HIGH))
			in_window = minf(in_window, -off)
		# The screech stays in the cab while it is inside (the vestibule's sides, then the doorway).
		if seq.screech.visible and t > n.pop_at + n.pop_seconds and screech_out == "":
			var m: Vector3 = train.global_transform.affine_inverse() * seq.screech.global_position
			if absf(m.x) > TerminalTrainModel.VESTIBULE_HALF - 0.1 or m.z < 0.1 or m.y < TerminalTrainModel.FLOOR - 0.05:
				screech_out = "%.2f s at %s" % [t, m]
		if not checked.has("stop") and t >= n.stop_at + 0.1:
			checked["stop"] = true
			var stopped := Vector3(seq.run_x, 0.0, seq.stop_z)
			check(runner.track_position.distance_to(stopped) < STAND_SLACK and runner.speed < 0.05,
				"%s: the runner stops short of the train's tail (%.2f m off, %.1f m short)" % [tag, runner.track_position.distance_to(stopped),
				seq.tail_z - runner.track_position.z])
		if not checked.has("stand") and t >= n.shake_a_at - 0.1:
			checked["stand"] = true
			var face_err: float = absf(rad_to_deg(angle_difference(runner.yaw, PI)))
			check(runner.track_position.distance_to(seq.stand) < STAND_SLACK and face_err < FACE_SLACK,
				"%s: the runner stands at the front door, facing it (%.2f m off, %.1f° off)" % [tag,
				runner.track_position.distance_to(seq.stand), face_err])
		if not checked.has("shut") and t >= n.open_at - 0.05:
			checked["shut"] = true
			check(train.door_open < 0.01, "%s: the door stays shut through the shaking and the banging" % tag)
		if not checked.has("open") and t >= n.open_at + n.open_seconds + 0.05:
			checked["open"] = true
			check(train.door_open > 0.99 and train.door_node.position.x < -0.8, "%s: the door slides open (%.2f, leaf %.2f m)" % [
				tag, train.door_open, train.door_node.position.x])
		if not checked.has("in") and t >= n.leave_shot_at - 0.05:
			checked["in"] = true
			var p: Vector3 = runner.track_position
			check(runner.visible and p.z < seq.nose_z - 1.0 and absf(p.x - seq.train_x) < 0.5 and is_equal_approx(p.y, TerminalTrainModel.FLOOR),
				"%s: the runner is inside the cab, on its floor, by the cut (%s)" % [tag, p])
			check(train.door_open < 0.05, "%s: the door has shut behind them by the cut (%.2f)" % [tag, train.door_open])
		if not checked.has("gone") and t >= n.leave_shot_at + 0.05:
			checked["gone"] = true
			check(not runner.visible and not seq.screech.visible, "%s: they and the screech are out of sight after the cut" % tag)
		if not checked.has("dark") and t >= n.lights_at - 0.05:
			checked["dark"] = true
			check(train.lights < 0.01 and train.interior < 0.01 and train.emergency > 0.9,
				"%s: the train is dark (its cab on the emergency light) until its lights come on" % tag)
	var cam_end: Vector3 = stage.to_track(seq.camera.global_position)
	var tail_end: float = seq.nose_z + seq.moved - length
	var skin_fog: float = (stage.skin as TerminalSkin).fog_end if stage.skin is TerminalSkin else 170.0
	check(tail_end - cam_end.z > skin_fog,
		"%s: by the end the train's tail is %.0f m from the camera, past the haze (%.0f m): out of sight" % [tag, tail_end - cam_end.z, skin_fog])
	check(not early_move and not backwards and seq.moved > 150.0,
		"%s: it stands until it starts, then only goes forward (%.0f m)" % [tag, seq.moved])
	check(camera_out == "", "%s: the camera keeps in the street, clear of the train (%s)" % [tag, camera_out])
	check(runner_in == "", "%s: the runner goes into the train only by its door (%s)" % [tag, runner_in])
	check(rattle_a > 0.003 and rattle_b > rattle_a * 2.0 and rattle_pause < 0.0005,
		"%s: the door rattles a little in the first shake (%.3f m), much more in the violent one (%.3f m), and not between (%.4f)" % [
		tag, rattle_a, rattle_b, rattle_pause])
	check(grip_n > 10 and grip_worst < HAND_REACH,
		"%s: both hands are on the handle through the shaking (worst %.3f m over %d steps)" % [tag, grip_worst, grip_n])
	var bang_worst: float = bang_best.max()
	check(bang_worst < HAND_REACH, "%s: the fist is on the door at each of the %d bangs (at its closest, %.3f m off its face at worst)" % [
		tag, n.bangs, bang_worst])
	check(hands_best > 0.1, "%s: both hands are thrown up above their head (%.2f m over it)" % [tag, hands_best])
	check(not screech_early and screech_seen and in_window > 0.0,
		"%s: the screech is hidden until it pops up, then seen through the door's window (%.2f m inside its frame)" % [tag, in_window])
	check(screech_out == "", "%s: the screech stays inside the cab (%s)" % [tag, screech_out])
	check(door_max > 0.99 and door_leaf < -0.8, "%s: the door opens all the way" % tag)
	var heard := PackedStringArray()
	for line: String in seq.log_lines:
		if line.begins_with("sound "):
			heard.append(line.get_slice(" ", 1))
	var expected: PackedStringArray = ["door_rattle", "door_rattle_hard", "door_bang", "door_bang", "door_bang", "screech_squeak",
		"train_door_open", "train_door_close", "train_start", "train_depart", "train_rush"]
	check(heard == expected, "%s: its sounds in order (%s)" % [tag, heard])
	var mean: float = step_total / maxf(float(steps), 1.0)
	print("    %s: set up %.1f ms, a step %.2f ms on average, %.2f ms at worst; props %d draw calls" % [tag, setup_msec, mean,
		worst_step, draw_calls])
	check(setup_msec < SETUP_BUDGET_MSEC and worst_step < STEP_BUDGET_MSEC and draw_calls <= PROP_DRAW_CALLS,
		"%s: it costs little (set up %.0f ms, a step at worst %.1f ms, %d draw calls)" % [tag, setup_msec, worst_step, draw_calls])
	await _free(seq)


## The distance from `p` to the segment a-b.
static func _segment_distance(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab: Vector3 = b - a
	var u: float = clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * u)


## Its lights: dark until `lights_at`, then fully on; with Reduced flashing they glow on without a flicker, never jumping
## by more than a slow glow's step, and the saloon's follow.
func _test_lights() -> void:
	var reduced: bool = Settings.flashing_reduced
	for soft: bool in [true, false]:
		Settings.flashing_reduced = soft
		var seq: TerminalOutro = _start()
		if seq == null:
			check(false, "the outro starts for the lights' test")
			return
		var n: TerminalOutroTuning = seq.n
		var last: float = 0.0
		var biggest: float = 0.0
		var dips: int = 0
		var peak: float = 0.0
		while not seq.done and seq.time < n.start_at:
			seq.advance(STEP)
			var l: float = seq.train.lights
			biggest = maxf(biggest, absf(l - last))
			if l < last - 0.05:
				dips += 1
			last = l
			peak = maxf(peak, l)
		check(peak > 0.99 and seq.train.interior > 0.9 and seq.train.emergency < 0.1,
			"Reduced flashing %s: the lights and the saloon's come on fully by the time it starts (%.2f, %.2f)" % [
			soft, peak, seq.train.interior])
		if soft:
			check(dips == 0 and biggest < 0.2, "Reduced flashing: the lights glow on slowly, with no flicker (%d dips, steps up to %.2f)" % [dips, biggest])
		else:
			check(dips >= 1, "without it the lights stutter on like a failing strip (%d dips)" % dips)
		await _free(seq)
	Settings.flashing_reduced = reduced


# --- Skipping and the App ----------------------------------------------------------------------------

func _test_skip() -> void:
	for at: float in [1.0, 7.0, 13.0, 17.0, 21.0, 25.0]:
		var seq: TerminalOutro = _start()
		if seq == null:
			return
		var ends: Array[int] = [0]
		seq.finished.connect(func() -> void: ends[0] += 1)
		while not seq.done and seq.time < at - 0.0001:
			seq.advance(STEP)
		seq.skip()
		check(ends[0] == 1 and seq.done and seq.skipped and not seq.stage.visible and not seq.overlay.visible
			and not seq.train.visible and not seq.screech.visible,
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
	var c := App.playing_cinematic() as TerminalOutro
	check(c != null and c.step.id == "terminal/outro" and App.screen == null and App.run == null,
		"the Terminal's outro slot plays it, in the world, with no screen over it")
	var press := InputEventAction.new()
	press.action = &"pause"
	press.pressed = true
	tree.root.push_input(press)
	await physics_frames(3)
	var next_c: Cinematic = App.playing_cinematic()
	check(App.profile.is_completed("terminal/outro") and next_c != null and next_c.step.id == "golden/intro" and not tree.paused,
		"the pause action skips it: the Golden Zone's intro starts at once, and nothing is paused")
	App.show_title()
	await tree.process_frame
	App.profile = saved
	main.queue_free()
	App.main = null
	await tree.process_frame
