extends TestSuite
## The cinematic toolkit (scripts/cinematics/, task F1): its paths (smooth, eased and cut moves), a
## timeline's checks, a cinematic played to its end (every event in order, `finished` once, the actors
## on their paths, the camera riding along), skip() ending it at once (and the pause action and the
## skip button asking for it), Reduced flashing, holding while the game is in the background, a
## cinematic described in data (the review tool's sampler), every zone's arrival flyover and the City's
## boss intro at 3, 5 and 6 lanes (the zone's skin from its data, the level's street, a camera that
## never flies into a ceiling or out of the street, a runner that never runs over a hole, ending in the
## run camera's view), and the App's flow through a built slot: it plays, the next step follows, the
## pause action and the skip button skip it, and the web demo plays it too.

const LANES: Array[int] = [3, 5, 6]
const SAMPLER_PATH: String = "res://tools/showcase/cinematic_sampler.tres"
const SFX_PATH: String = "res://data/audio/sfx_library.tres"
## The camera keeps this far under a ceiling's underside while over it or this near it (metres).
const CEILING_CLEARANCE: float = 0.4
const CEILING_MARGIN: float = 2.0
## It stays this far inside the wall faces, and under the lowest thing any zone hangs over its lanes
## (bar ceilings), and this far above the floor.
const WALL_CLEARANCE: float = 1.0
const OPEN_STREET_TOP: float = 9.5
const FLOOR_CLEARANCE: float = 1.0
## Tests that drive the clock themselves step it by this.
const STEP: float = 1.0 / 30.0

var sfx: SfxLibrary
var _music_before: StringName = &""


func run() -> void:
	sfx = load(SFX_PATH) as SfxLibrary
	var music: MusicDirector = MusicDirector.instance()
	_music_before = music.current() if music != null else &""
	_test_paths()
	_test_timeline_checks()
	await _test_play_to_end()
	await _test_skip()
	await _test_reduced_flashing()
	await _test_hold_in_background()
	await _test_sampler()
	await _test_flyovers()
	await _test_skin_from_zone_data()
	await _test_app_flow()
	if music != null:
		if _music_before == &"":
			music.stop(0.0)
		else:
			music.play(_music_before, 0.0)


# --- Paths -------------------------------------------------------------------------------------

func _key(time: float, move: CinePath.Move, trans: Tween.TransitionType = Tween.TRANS_LINEAR,
		easing: Tween.EaseType = Tween.EASE_IN_OUT) -> CineKey:
	var k := CineKey.new()
	k.time = time
	k.move = move
	k.trans = trans
	k.easing = easing
	return k


func _test_paths() -> void:
	var linear: Array = [_key(0.0, CinePath.Move.LINEAR), _key(2.0, CinePath.Move.LINEAR)]
	var ends: Array = [0.0, 10.0]
	check(is_equal_approx(float(CinePath.sample(linear, ends, 1.0)), 5.0), "a linear move is halfway at half time")
	check(is_equal_approx(float(CinePath.sample(linear, ends, -1.0)), 0.0)
		and is_equal_approx(float(CinePath.sample(linear, ends, 3.0)), 10.0),
		"before the first key a path holds the first key, after the last the last")
	var eased: Array = [_key(0.0, CinePath.Move.LINEAR), _key(2.0, CinePath.Move.LINEAR, Tween.TRANS_SINE, Tween.EASE_IN_OUT)]
	var early: float = float(CinePath.sample(eased, ends, 0.5))
	var middle: float = float(CinePath.sample(eased, ends, 1.0))
	var late: float = float(CinePath.sample(eased, ends, 1.5))
	check(early < 2.0 and is_equal_approx(middle, 5.0) and late > 8.0 and is_equal_approx(early + late, 10.0),
		"an eased move starts and ends slowly, symmetric about its middle (%.2f, %.2f, %.2f)" % [early, middle, late])
	var cut: Array = [_key(0.0, CinePath.Move.LINEAR), _key(2.0, CinePath.Move.CUT)]
	check(is_equal_approx(float(CinePath.sample(cut, ends, 1.99)), 0.0) and is_equal_approx(float(CinePath.sample(cut, ends, 2.0)), 10.0),
		"a cut holds the key before, then jumps at its time")
	var smooth: Array = [_key(0.0, CinePath.Move.SMOOTH), _key(1.0, CinePath.Move.SMOOTH), _key(3.0, CinePath.Move.SMOOTH),
		_key(4.0, CinePath.Move.SMOOTH)]
	var points: Array = [Vector3(0, 0, 0), Vector3(2, 3, 10), Vector3(-1, 5, 20), Vector3(4, 1, 45)]
	var through: bool = true
	for i: int in smooth.size():
		through = through and (CinePath.sample(smooth, points, (smooth[i] as CineKey).time) as Vector3).is_equal_approx(points[i])
	check(through, "a smooth path passes through every key")
	var worst: float = 0.0
	for i: int in [1, 2]:
		var t: float = (smooth[i] as CineKey).time
		var h: float = 0.0005
		var before: Vector3 = ((CinePath.sample(smooth, points, t) as Vector3) - (CinePath.sample(smooth, points, t - h) as Vector3)) / h
		var after: Vector3 = ((CinePath.sample(smooth, points, t + h) as Vector3) - (CinePath.sample(smooth, points, t) as Vector3)) / h
		worst = maxf(worst, (before - after).length() / maxf(after.length(), 0.001))
	check(worst < 0.01, "and its velocity carries on smoothly through each key (worst change %.4f)" % worst)
	var same: Array = [_key(0.0, CinePath.Move.LINEAR), _key(1.0, CinePath.Move.LINEAR), _key(1.0, CinePath.Move.LINEAR)]
	check(is_equal_approx(float(CinePath.sample(same, [0.0, 4.0, 9.0], 1.0)), 9.0), "of two keys at one moment the later wins")
	var turn: Array = [_key(0.0, CinePath.Move.LINEAR), _key(1.0, CinePath.Move.LINEAR)]
	var half: float = CinePath.sample_angle(turn, PackedFloat32Array([deg_to_rad(170.0), deg_to_rad(-170.0)]), 0.5)
	check(absf(angle_difference(half, PI)) < 0.01, "a turn goes the short way round (%.1f°)" % rad_to_deg(half))


# --- Timelines ---------------------------------------------------------------------------------

func _test_timeline_checks() -> void:
	var t: CineTimeline = _small_timeline()
	check(t.problems(sfx).is_empty(), "a sound timeline has no problems: %s" % [t.problems(sfx)])
	var bad: CineTimeline = _small_timeline()
	bad.camera[1].watch = &"nobody"
	bad.actors[0].keys[1].time = -1.0
	bad.sound(1.0, &"no_such_sound")
	bad.effect(1.0, &"explode")
	bad.card(1.0, "  ")
	bad.actors[0].keys[0].pose = &"fly"
	bad.actors[1].keys[0].aim_at = &"nobody"
	bad.cue(9.0, &"late")
	var found: PackedStringArray = bad.problems(sfx)
	var wanted: Array[String] = ["names no actor 'nobody'", "keys out of order", "no sound the library has",
		"no effect 'explode'", "has no text", "no pose 'fly'", "can't aim at 'nobody'", "outside 0-3.00 s"]
	var missed: Array[String] = []
	for w: String in wanted:
		var hit: bool = false
		for line: String in found:
			hit = hit or line.contains(w)
		if not hit:
			missed.append(w)
	check(missed.is_empty(), "problems() finds what's wrong with a timeline (missed: %s; found: %s)" % [missed, found])
	var order := CineTimeline.new()
	var first: CineEvent = order.cue(2.0, &"a")
	var second: CineEvent = order.cue(1.0, &"b")
	var third: CineEvent = order.cue(2.0, &"c")
	order.shot(3.0, Vector3.ZERO, Vector3.FORWARD)
	order.shot(1.0, Vector3.ZERO, Vector3.FORWARD)
	order.sort()
	check(order.events == [second, first, third] and order.camera[0].time == 1.0,
		"sort() puts keys and events in time order, keeping the order of those at one moment")


## A 3-second cinematic written in a script: a stage with a ceiling, the runner running 54 m in the
## start lane, a cyborg aiming at them, a camera that starts fixed and then rides behind the runner, and
## a music cue, a card, a sound, a cue and a fade.
func _small_timeline() -> CineTimeline:
	var t := CineTimeline.new()
	t.duration = 3.0
	var stage := CineStageDef.new()
	stage.ceilings = PackedVector2Array([Vector2(40.0, 70.0)])
	stage.gaps = PackedVector3Array([Vector3(-1.0, 20.0, 26.0)])
	t.stage = stage
	var runner: CineActor = t.actor(&"runner")
	runner.at(0.0, Vector3(0.0, 0.0, 0.0), &"run")
	runner.at(3.0, Vector3(0.0, 0.0, 54.0))
	var thug: CineActor = t.actor(&"thug", CineActor.Kind.CYBORG)
	var k: CineActorKey = thug.at(0.0, Vector3(2.4, 0.0, 40.0), &"aim")
	k.face_path = false
	k.yaw = 180.0
	k.aim_at = &"runner"
	k.expression = &"aiming"
	t.shot(0.0, Vector3(0.0, 6.0, -6.0), Vector3(0.0, 0.0, 40.0))
	var ride: CineCameraKey = t.shot(3.0, Vector3(0.0, 4.2, -7.5), Vector3(0.0, 1.0, 14.0))
	ride.follow = &"runner"
	ride.watch = &"runner"
	t.music(0.0, CineEvent.ZONE_MUSIC, 0.5)
	t.card(0.5, "{zone}", "ZONE {zone_number}", 1.5)
	t.sound(1.0, &"jump")
	t.cue(1.5, &"halfway")
	t.effect(2.5, CineEvent.FADE_OUT, 0.4)
	return t


## A sequencer for `t`, in the tree, playing as the City's intro would (its zone, skin and music).
func _start(t: CineTimeline) -> CinematicSequencer:
	var seq := CinematicSequencer.new()
	seq.timeline = t
	tree.root.add_child(seq)
	var s: CampaignStep = App.campaign.step("city/intro")
	seq.play(s.cinematic, s)
	return seq


func _free(node: Node) -> void:
	if node != null and is_instance_valid(node):
		node.queue_free()
	await tree.process_frame


# --- Playing ------------------------------------------------------------------------------------

func _test_play_to_end() -> void:
	var seq: CinematicSequencer = _start(_small_timeline())
	var ends: Array[int] = [0]
	var cues: Array[StringName] = []
	seq.finished.connect(func() -> void: ends[0] += 1)
	seq.cue.connect(func(n: StringName) -> void: cues.append(n))
	var zone: ZoneDef = App.campaign.step("city/intro").zone
	check(seq.step != null and seq.step.id == "city/intro" and seq.zone == zone and seq.slot == &"intro",
		"it knows its step, zone and slot")
	check(seq.stage != null and seq.stage.skin == zone.skin and seq.stage.geo.lane_count == App.lane_count(),
		"its stage is the zone's own look, with as many lanes as a level on this device")
	check(seq.camera != null and seq.camera.current, "its camera is the one in use")
	check(seq.log_lines.size() == 1 and seq.log_lines[0] == "music %s" % zone.music and MusicDirector.instance().current() == zone.music,
		"the events at time 0 fire before the first frame: the slot's music (@zone) comes in (%s)" % [seq.log_lines])
	var runner := seq.actors[&"runner"] as CineActorNode
	var thug := seq.actors[&"thug"] as CineActorNode
	var frames: int = 0
	var card_seen: bool = false
	var ran: float = 0.0
	var fade_late: float = 0.0
	while ends[0] == 0 and frames < 400:
		await tree.process_frame
		frames += 1
		card_seen = card_seen or seq.overlay.card_showing()
		if frames == 90:
			ran = runner.avatar.rig.weight(HumanoidRig.Activity.RUN)
		if seq.time >= 2.95:
			fade_late = maxf(fade_late, seq.overlay.fade_alpha())
	check(ends[0] == 1 and absi(frames - 180) <= 2, "it plays for its duration and emits finished (%d frames)" % frames)
	check(seq.log_lines == PackedStringArray(["music city", "text Neon City", "sound jump", "cue halfway", "effect fade_out"])
		and cues == [&"halfway"], "every event fired once, in order (%s)" % [seq.log_lines])
	check(card_seen and seq.overlay.card_caption.text == "ZONE 1" and seq.overlay.card_title.text == "NEON CITY",
		"the card showed the slot's data filled in (%s / %s)" % [seq.overlay.card_caption.text, seq.overlay.card_title.text])
	check(fade_late > 0.8, "the fade to black covered the end (%.2f)" % fade_late)
	check(runner.track_position.is_equal_approx(Vector3(0.0, 0.0, 54.0)) and absf(runner.distance_run - 54.0) < 0.5
		and ran > 0.9, "the runner ran its path, the stride keeping pace (%.1f m, run weight %.2f)" % [runner.distance_run, ran])
	check(thug.body.pose == CyborgBody.Pose.AIM and thug.body.face == CyborgBody.Kit.Face.AIMING
		and thug.body.look == CyborgSuit.look_for(zone.skin.enemy_variant), "the cyborg aims in its zone's look, its face set")
	var expected: Vector3 = runner.position + Vector3(0.0, 4.2, 7.5)
	check(seq.camera.global_position.is_equal_approx(expected), "the camera rode behind the runner to its last key (%s, %s)" % [
		seq.camera.global_position, expected])
	check(seq.stage.track.get_child_count() > 0 and not seq.stage.track.find_children("*", "MeshInstance3D", true, false).is_empty(),
		"the stage built its chunks, dressed")
	check(seq.done and not seq.skipped and not seq.stage.visible and not seq.overlay.visible and not runner.visible
		and seq.stage.get_node_or_null(^"Environment") == null, "once over, nothing of it shows and its environment has left")
	seq.skip()
	for i: int in 5:
		await tree.process_frame
	check(ends[0] == 1, "finished fires once, however it's asked to end afterwards")
	await _free(seq)


func _test_skip() -> void:
	var seq: CinematicSequencer = _start(_small_timeline())
	var ends: Array[int] = [0]
	seq.finished.connect(func() -> void: ends[0] += 1)
	for i: int in 45:
		await tree.process_frame
	var at: float = seq.time
	var fired: int = seq.log_lines.size()
	seq.skip()
	check(ends[0] == 1 and seq.done and seq.skipped, "skip() ends it at once: finished fires within the call")
	for i: int in 30:
		await tree.process_frame
	check(ends[0] == 1 and is_equal_approx(seq.time, at) and seq.log_lines.size() == fired,
		"nothing more happens after a skip (%.2f s, %d events)" % [seq.time, seq.log_lines.size()])
	seq.skip()
	check(ends[0] == 1, "skipping twice ends it once")
	var stopped: bool = true
	for p: Variant in seq._sounds.values():
		stopped = stopped and (p == null or not (p as AudioStreamPlayer).playing)
	check(stopped, "its sounds stop")
	await _free(seq)

	# The player asks with the pause action, or the skip button; whoever plays it answers (the App).
	seq = _start(_small_timeline())
	var asks: Array[int] = [0]
	seq.skip_requested.connect(func() -> void: asks[0] += 1)
	await tree.process_frame
	var press := InputEventAction.new()
	press.action = &"pause"
	press.pressed = true
	tree.root.push_input(press)
	check(asks[0] == 1 and not seq.done, "the pause action asks to skip (it doesn't end by itself)")
	for i: int in 30:
		await tree.process_frame
	check(seq.overlay.skip_button.visible, "the skip button shows after a moment")
	seq.overlay.skip_button.pressed.emit()
	check(asks[0] == 2, "and pressing it asks to skip too")
	await _free(seq)


func _test_reduced_flashing() -> void:
	var was: bool = Settings.flashing_reduced
	var peaks: Array[float] = []
	var lit: Array[float] = []
	for reduced: bool in [false, true]:
		Settings.flashing_reduced = reduced
		var t: CineTimeline = _small_timeline()
		t.effect(0.2, CineEvent.FLASH, 0.2, 1.0, Color.WHITE)
		var seq: CinematicSequencer = _start(t)
		var peak: float = 0.0
		var frames_lit: int = 0
		for i: int in 90:
			await tree.process_frame
			peak = maxf(peak, seq.overlay.flash_alpha())
			frames_lit += 1 if seq.overlay.flash_alpha() > 0.02 else 0
		peaks.append(peak)
		lit.append(frames_lit / 60.0)
		await _free(seq)
	Settings.flashing_reduced = was
	check(peaks[0] > 0.75 and lit[0] < 0.3, "a flash is a quick, bright flash (peak %.2f for %.2f s)" % [peaks[0], lit[0]])
	check(peaks[1] <= CineOverlay.SOFT_FLASH_ALPHA + 0.01 and lit[1] >= CineOverlay.SOFT_FLASH_MIN_TIME * 0.6,
		"with Reduced flashing it's a slow, faint glow (peak %.2f for %.2f s)" % [peaks[1], lit[1]])


func _test_hold_in_background() -> void:
	var seq: CinematicSequencer = _start(_small_timeline())
	for i: int in 10:
		await tree.process_frame
	seq.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	var at: float = seq.time
	for i: int in 30:
		await tree.process_frame
	check(is_equal_approx(seq.time, at), "it holds while the game is in the background (%.2f s)" % seq.time)
	seq.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	for i: int in 12:
		await tree.process_frame
	check(seq.time > at + 0.15, "and carries on when it's back (%.2f s)" % seq.time)
	await _free(seq)


# --- Described in data --------------------------------------------------------------------------

func _test_sampler() -> void:
	var t := load(SAMPLER_PATH) as CineTimeline
	check(t != null and t.problems(sfx).is_empty(), "the sampler, a cinematic described in data, has no problems: %s" % [
		t.problems(sfx) if t != null else PackedStringArray()])
	if t == null:
		return
	var seq: CinematicSequencer = _start(t)
	seq.set_process(false)
	var ends: Array[int] = [0]
	seq.finished.connect(func() -> void: ends[0] += 1)
	var zone: ZoneDef = App.campaign.step("city/intro").zone
	var runner := seq.actors[&"runner"] as CineActorNode
	var thug := seq.actors[&"thug"] as CineActorNode
	var host := seq.actors[&"host"] as CineActorNode
	check(host.body.host and thug.body.look == CyborgSuit.look_for(zone.skin.enemy_variant) and not thug.body.host,
		"its cyborgs wear the zone's look, the host its glitch")
	var seen: Dictionary = {}
	var last_cam := Vector3.INF
	var jumps: Array[float] = []
	var steps: int = 0
	while not seq.done and steps < 2000:
		seq.advance(STEP)
		steps += 1
		var cam: Vector3 = seq.camera.global_position
		if last_cam != Vector3.INF and cam.distance_to(last_cam) > 5.0:
			jumps.append(seq.time)
		last_cam = cam
		for moment: float in [1.0, 2.0, 2.7, 3.3, 3.9, 5.4, 8.0, 9.0]:
			if not seen.has(moment) and seq.time >= moment:
				seen[moment] = {"host_visible": host.visible, "thug_pose": thug.body.pose, "charge": thug.body.charge,
					"runner_y": runner.track_position.y, "air": runner.avatar.rig.weight(HumanoidRig.Activity.AIR),
					"slide": runner.avatar.rig.weight(HumanoidRig.Activity.SLIDE),
					"dash": runner.avatar.rig.weight(HumanoidRig.Activity.DASH)}
	check(ends[0] == 1 and seq.log_lines.size() == t.events.size(), "it plays to its end, every event fired (%d of %d)" % [
		seq.log_lines.size(), t.events.size()])
	check(jumps.size() == 1 and absf(jumps[0] - 2.5) < STEP * 1.5, "the camera cuts once, at 2.5 s, and otherwise moves smoothly (%s)" % [jumps])
	check(not bool(seen[1.0]["host_visible"]) and bool(seen[3.9]["host_visible"]), "an actor shows only from its entrance")
	check(int(seen[2.0]["thug_pose"]) == CyborgBody.Pose.AIM and float(seen[2.7]["charge"]) > 0.9
		and int(seen[3.9]["thug_pose"]) == CyborgBody.Pose.RUN_AWAY, "the cyborg aims, charges and runs off, key by key")
	check(float(seen[3.3]["runner_y"]) > 1.2 and float(seen[3.3]["air"]) > 0.5 and float(seen[5.4]["slide"]) > 0.5
		and float(seen[8.0]["dash"]) > 0.5, "the runner jumps, slides and dashes on its keys (%s)" % [seen])
	await _free(seq)


# --- The arrival flyovers ------------------------------------------------------------------------

func _test_flyovers() -> void:
	var lanes_pc: int = App.rules.lanes_pc
	var slots: Array[CampaignStep] = []
	for s: CampaignStep in App.campaign.steps():
		if s.kind == CampaignStep.Kind.CINEMATIC and s.cinematic.is_built():
			slots.append(s)
	var ids: PackedStringArray = []
	for s: CampaignStep in slots:
		ids.append(s.id)
	check(ids == PackedStringArray(["city/intro", "city/boss_intro", "gangland/intro", "marketplace/intro", "corporate/intro",
		"dead_zone/intro", "golden/intro"]), "every zone's intro plays its arrival flyover, and the City's boss intro (%s)" % [ids])
	for lanes: int in LANES:
		App.rules.lanes_pc = lanes
		for s: CampaignStep in slots:
			await _check_flyover(s, lanes)
	App.rules.lanes_pc = lanes_pc


func _check_flyover(s: CampaignStep, lanes: int) -> void:
	var tag: String = "%s, %d lanes" % [s.id, lanes]
	var seq := (load(s.cinematic.scene) as PackedScene).instantiate() as CinematicSequencer
	check(seq is ArrivalFlyover, "%s: the arrival flyover" % tag)
	tree.root.add_child(seq)
	seq.play(s.cinematic, s)
	seq.set_process(false)
	var boss: bool = s.id.ends_with("/boss_intro")
	var skin: ZoneSkin = s.zone.boss.arena.skin if boss and s.zone.boss.arena.skin != null else s.zone.skin
	check(seq.stage != null and seq.stage.skin == skin and seq.stage.geo.lane_count == lanes,
		"%s: built in its zone's skin from the zone's data (%s), on the level's lanes" % [tag, skin.resource_path])
	check(seq.playing.problems(sfx).is_empty() and seq.duration() >= 5.0 and seq.duration() <= 15.0,
		"%s: a sound timeline of 5-15 s (GDD §1): %s" % [tag, seq.playing.problems(sfx)])
	var runner := seq.actors.get(&"runner") as CineActorNode
	check(runner != null and runner.avatar != null, "%s: the runner is in it" % tag)
	if runner == null:
		await _free(seq)
		return
	var geo: TrackGeometry = seq.stage.geo
	var high: float = 0.0
	var off_street: float = 0.0
	var into_ceiling: float = -1.0
	var over_hole: float = -1.0
	var steps: int = 0
	while not seq.done and steps < 2000:
		seq.advance(STEP)
		steps += 1
		var cam: Vector3 = seq.camera.global_position
		var d: float = seq.stage.to_track(cam).z
		high = maxf(high, cam.y)
		off_street = maxf(off_street, absf(cam.x) - (geo.wall_x() - WALL_CLEARANCE))
		if cam.y < FLOOR_CLEARANCE:
			off_street = maxf(off_street, FLOOR_CLEARANCE - cam.y)
		if seq.stage.ceiling_over(d, CEILING_MARGIN) != Vector2.ZERO and cam.y > seq.tuning.ceiling_height - CEILING_CLEARANCE \
				and into_ceiling < 0.0:
			into_ceiling = seq.time
		if seq.stage.gap_at(seq.stage.start_lane, runner.track_position.z, 0.3) and over_hole < 0.0:
			over_hole = seq.time
	check(seq.done and not seq.skipped, "%s: it plays to its end" % tag)
	check(high <= OPEN_STREET_TOP and off_street <= 0.0, "%s: the camera stays over the street, under anything hung over it (top %.2f m, out by %.2f m)" % [
		tag, high, off_street])
	check(into_ceiling < 0.0, "%s: the camera never flies into a ceiling (at %.2f s)" % [tag, into_ceiling])
	check(over_hole < 0.0, "%s: the runner never runs over a hole (at %.2f s)" % [tag, over_hole])
	var t: MovementTuning = seq.tuning
	var side: float = geo.lane_x(seq.stage.start_lane) * (t.camera_follow_x - 1.0)
	var expected: Vector3 = runner.position + Vector3(side, t.camera_height, t.camera_distance)
	check(seq.camera.global_position.is_equal_approx(expected) and is_equal_approx(seq.camera.fov, t.camera_fov),
		"%s: it ends in the run camera's view of the runner (%s, %s)" % [tag, seq.camera.global_position, expected])
	var title: String = s.zone.boss.display_name if boss else s.zone.display_name
	var track: StringName = s.zone.boss.music if boss and s.zone.boss.music != &"" else s.zone.music
	check(seq.log_lines.has("text %s" % title) and seq.log_lines.has("music %s" % track),
		"%s: its card names %s and the music is %s (%s)" % [tag, title, track, seq.log_lines])
	await _free(seq)


## A later change to the zone's data reaches the flyover: another skin, another music track, and before
## a boss the arena's own look, or the zone's without one.
func _test_skin_from_zone_data() -> void:
	var s: CampaignStep = App.campaign.step("city/intro")
	var zone: ZoneDef = s.zone
	var skin: ZoneSkin = zone.skin
	var music: StringName = zone.music
	var other := load("res://data/skins/gangland_skin.tres") as ZoneSkin
	zone.skin = other
	zone.music = &"gangland"
	var seq := (load(s.cinematic.scene) as PackedScene).instantiate() as CinematicSequencer
	tree.root.add_child(seq)
	seq.play(s.cinematic, s)
	check(seq.stage.skin == other and MusicDirector.instance().current() == &"gangland",
		"a change of the zone's skin and music reaches its flyover")
	seq.skip()
	await _free(seq)
	zone.skin = skin
	zone.music = music
	var b: CampaignStep = App.campaign.step("city/boss_intro")
	var arena: LevelConfig = b.zone.boss.arena
	var arena_skin: ZoneSkin = arena.skin
	arena.skin = null
	seq = (load(b.cinematic.scene) as PackedScene).instantiate() as CinematicSequencer
	tree.root.add_child(seq)
	seq.play(b.cinematic, b)
	check(seq.stage.skin == zone.skin, "a boss intro without an arena look of its own takes the zone's")
	seq.skip()
	await _free(seq)
	arena.skin = arena_skin


# --- Through the App ------------------------------------------------------------------------------

func _test_app_flow() -> void:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	var saved: Profile = App.profile
	App.profile = SampleProfiles.fresh()

	# A new player's campaign opens on the City's arrival flyover, then City 1 follows.
	App.continue_campaign()
	await tree.process_frame
	var c := App.playing_cinematic() as CinematicSequencer
	check(c is ArrivalFlyover and c.step.id == "city/intro" and App.screen == null and App.run == null,
		"the campaign opens on the City's arrival flyover, in the world, with no screen over it")
	check(c != null and c.stage.skin == App.campaign.step("city/intro").zone.skin and MusicDirector.instance().current() == &"city",
		"in the City's look, with the City's music")
	var duration: float = c.duration() if c != null else 0.0
	var frames: int = 0
	while App.run == null and frames < 20 * 60:
		await tree.process_frame
		frames += 1
	check(App.run != null and App.run.context.step.id == "city/1" and absf(frames - duration * 60.0) <= 3.0,
		"once it has played out (%d frames for %.1f s), City 1 starts" % [frames, duration])
	check(App.profile.is_completed("city/intro") and App.profile.has_seen("cinematic/city/intro") and App.playing_cinematic() == null,
		"the slot counts as done and seen, and the cinematic is gone")
	await physics_frames(3)
	check(App.run != null and App.run.camera.current and App.run.world.player.running, "the level plays under its own camera")

	# Skipping with the pause action: the boss intro, then the fight at once.
	App.show_level_select()
	await tree.process_frame
	App.play_step(App.campaign.step("city/boss_intro"))
	await physics_frames(20)
	c = App.playing_cinematic() as CinematicSequencer
	var arena_skin: ZoneSkin = App.campaign.step("city/boss").boss.arena.skin
	check(c != null and c.step.id == "city/boss_intro" and c.stage.skin == arena_skin, "the boss intro plays over the fight's arena look")
	var press := InputEventAction.new()
	press.action = &"pause"
	press.pressed = true
	tree.root.push_input(press)
	await physics_frames(3)
	check(App.run != null and App.run.encounter is FloatingHead and App.run.context.step.id == "city/boss"
		and App.profile.is_completed("city/boss_intro"), "the pause action skips it: the fight starts at once")
	check(not get_tree_paused() and App.overlay == null, "skipping doesn't pause anything")

	# The skip button (touch screens).
	App.show_level_select()
	await tree.process_frame
	App.play_step(App.campaign.step("city/intro"))
	await physics_frames(30)
	c = App.playing_cinematic() as CinematicSequencer
	if c != null:
		c.overlay.skip_button.pressed.emit()
	await physics_frames(3)
	check(App.run != null and App.run.context.step.id == "city/1", "its skip button skips it too")

	# The web demo plays the City's flyovers too, and still ends after the Zone 1 boss.
	BuildFlavor.set_override(BuildFlavor.Kind.WEB_DEMO)
	App.play_step(App.campaign.step("city/intro"))
	await tree.process_frame
	check(App.playing_cinematic() is ArrivalFlyover, "the web demo plays the City's flyover")
	App.skip_cinematic()
	await physics_frames(3)
	check(App.run != null and App.run.context.step.id == "city/1", "then its first level")
	App.play_step(App.campaign.step("gangland/intro"))
	await tree.process_frame
	check(App.screen is DemoEndScreen and App.playing_cinematic() == null, "the next zone's flyover is the full game's: the demo ends there")
	BuildFlavor.set_override(-1)

	App.show_title()
	await tree.process_frame
	App.profile = saved
	main.queue_free()
	App.main = null
	await tree.process_frame


func get_tree_paused() -> bool:
	return tree.paused
