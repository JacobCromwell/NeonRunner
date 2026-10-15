extends TestSuite
## The Beach's outro (BeachOutro; the owner's beats, October 15, 2026): its slot (after Mecha Guppy and Captain Cogs);
## at 3, 5 and 6 lanes: the fight's look, the bar on the street by the left wall line, the pool a gap in the start
## lane; Mecha Guppy leaping out at sea and swimming off; the runner watching, walking to the counter before the cut
## to the bartender's view and facing the bar; the screech hopping up onto the counter and sitting there; the
## bartender pointing to the menu, out of his own views, his back turned as he shakes the drinks; the two fingers; the
## Golden Palace (the street hidden, its fog off, the scenery dark, the camera in its room; the Golden Convergence's
## arm up and pointing, its finger out), and everything back after it; the ships; the drinks on the counter after the
## cut; every bomb landing, none on the runner or the screech; the runner (and the screech) jumping into the pool and
## under the water; the fire filling the picture, then black; its sounds; what it costs. Then Reduced flashing (the
## fire slower and darker), skipping (at any moment, the scenery's light back), and the App's flow (skipping it starts
## the Dead Zone's intro).

const LANES: Array[int] = [3, 5, 6]
const SFX_PATH: String = "res://data/audio/sfx_library.tres"
const SCENE: String = "res://scenes/cinematics/beach_outro.tscn"
const STEP: float = 1.0 / 30.0
## A bomb's fireball keeps at least this far from the runner and the screech where it lands (metres beyond its radius).
const BLAST_CLEARANCE: float = 1.0
## The runner stops within this of their place at the counter, and faces the bar within this (degrees).
const STAND_SLACK: float = 0.05
const FACE_SLACK: float = 8.0
## Its sounds of its own (tools/asset_gen/sfx_bank_beach_outro.gd).
const OWN_SOUNDS: Array[String] = ["bar_shaker", "bar_glass"]
## Costs, headless (generous: they catch a gross regression; the measured numbers are printed), and what its props may
## add to a frame at most.
const SETUP_BUDGET_MSEC: float = 2000.0
const STEP_BUDGET_MSEC: float = 40.0
const PROP_DRAW_CALLS: int = 60

var sfx: SfxLibrary
var _music_before: StringName = &""


func run() -> void:
	sfx = load(SFX_PATH) as SfxLibrary
	var music: MusicDirector = MusicDirector.instance()
	_music_before = music.current() if music != null else &""
	_test_slot()
	var lanes_pc: int = App.rules.lanes_pc
	for lanes: int in LANES:
		App.rules.lanes_pc = lanes
		await _test_beats(lanes)
	App.rules.lanes_pc = lanes_pc
	await _test_reduced_flashing()
	await _test_skip()
	await _test_app_flow()
	if music != null:
		if _music_before == &"":
			music.stop(0.0)
		else:
			music.play(_music_before, 0.0)


func _step() -> CampaignStep:
	return App.campaign.step("beach/outro")


func _start() -> BeachOutro:
	var s: CampaignStep = _step()
	var seq := (load(s.cinematic.scene) as PackedScene).instantiate() as BeachOutro
	tree.root.add_child(seq)
	seq.play(s.cinematic, s)
	seq.set_process(false)
	return seq


func _free(node: Node) -> void:
	if node != null and is_instance_valid(node):
		node.queue_free()
	await tree.process_frame


func _run_to(seq: BeachOutro, t: float) -> void:
	while not seq.done and seq.time < t - 0.0001:
		seq.advance(minf(STEP, t - seq.time))


func _test_slot() -> void:
	var s: CampaignStep = _step()
	check(s != null and s.cinematic.is_built() and s.cinematic.scene == SCENE, "the Beach's outro slot plays the Beach outro")
	var seq := (load(SCENE) as PackedScene).instantiate()
	check(seq is BeachOutro and (seq as BeachOutro).numbers != null, "its scene is a BeachOutro with its numbers")
	seq.free()
	var next: CampaignStep = App.campaign.next_step(s)
	check(next != null and next.id == "dead_zone/intro", "the Dead Zone's intro follows it")


func _test_beats(lanes: int) -> void:
	var t0: int = Time.get_ticks_usec()
	var seq: BeachOutro = _start()
	var setup_msec: float = (Time.get_ticks_usec() - t0) / 1000.0
	var n: BeachOutroTuning = seq.n
	var stage: CineStage = seq.stage
	var zone: ZoneDef = _step().zone
	var tag: String = "%d lanes" % lanes
	check(stage.geo.lane_count == lanes and stage.skin == zone.boss.arena.skin,
		"%s: it plays on the fight's look (the arena's open shore), in the level's lanes" % tag)
	check(seq.playing.problems(sfx).is_empty(), "%s: its timeline has no problems (%s)" % [tag, seq.playing.problems(sfx)])
	# The set: the bar on the street by the left wall line, the pool a gap in the start lane.
	var back: float = seq.counter.x - (n.kiosk_size.x - BeachOutroBar.COUNTER_FRONT_IN) * n.kiosk_scale
	check(back >= stage.wall_x(-1) - 0.01 and seq.counter.x < 0.0, "%s: the bar stands on the street, its back at the left wall line" % tag)
	var pool_mid: float = n.bar_at + n.pool_from + n.pool_length * 0.5
	check(stage.gap_at(stage.start_lane, pool_mid) and not stage.gap_at(stage.start_lane, n.bar_at),
		"%s: the pool is a gap in the start lane (the Beach's gaps are pools of water)" % tag)
	var worst_step: float = 0.0
	var steps: int = 0
	var step_total: float = 0.0
	var shark_out_at_sea: bool = true
	var shark_high: float = -INF
	var shark_shown_after: bool = false
	var near_blast: String = ""
	var landed: int = 0
	var light_in_palace: float = -1.0
	var palace_ok: bool = true
	var cam_in_room: bool = true
	var pov_hidden: bool = true
	var draw_calls: int = 0
	var runner := seq.actors[&"runner"] as CineActorNode
	var checked: Dictionary = {}
	while not seq.done:
		var s0: int = Time.get_ticks_usec()
		seq.advance(STEP)
		var msec: float = (Time.get_ticks_usec() - s0) / 1000.0
		worst_step = maxf(worst_step, msec)
		step_total += msec
		steps += 1
		var t: float = seq.time
		if seq.done:
			break
		draw_calls = maxi(draw_calls, seq.props_draw_calls())
		# Mecha Guppy: out at sea (beyond the left wall line) whenever it shows; gone after its swim.
		if seq.shark.visible:
			var head: Vector3 = stage.to_track(seq.shark.global_position)
			shark_out_at_sea = shark_out_at_sea and head.x < stage.wall_x(-1) - 20.0
			shark_high = maxf(shark_high, head.y)
			if t > n.breach_at + n.breach_seconds + n.fin_seconds + 0.1:
				shark_shown_after = true
		# The bartender is out of his own views.
		if seq.pov_shot(t) and seq.bar.bartender.visible:
			pov_hidden = false
		# The palace: the street hidden, its fog off, the scenery dark, the camera in its room.
		if t > n.palace_at + 0.05 and t < n.ships_at - 0.05:
			light_in_palace = ZoneSkin.scenery_light_now
			palace_ok = palace_ok and seq.in_palace and not stage.visible and seq.palace.visible \
				and not stage.environment.fog_enabled
			var local: Vector3 = seq.palace.to_local(seq.camera.global_position)
			var half: Vector3 = n.room_size * 0.5
			cam_in_room = cam_in_room and absf(local.x) < half.x and local.y > -n.room_size.y * 0.3 \
				and local.z < n.room_size.z * 0.38
		# Each bomb as it lands: never on the runner or the screech, but the last, which goes off as they go into the
		# pool (the owner: "jumps in just as an explosion happens"): by then they're off the ground, over the pool.
		var now_landed: int = seq.raid.landed_by(t)
		while landed < now_landed:
			if landed == n.bombs.size() - 1:
				var over: Vector3 = runner.track_position
				check(t > n.jump_at and stage.gap_at(stage.start_lane, over.z),
					"%s: the last bomb goes off as the runner is over the pool (%.2f s, %.1f m along)" % [tag, t, over.z])
				landed += 1
				continue
			var b: Vector4 = n.bombs[landed]
			var at: Vector3 = seq.raid.impact(landed)
			var r: Vector3 = runner.track_position
			var sc: Vector3 = stage.to_track(seq.screech.global_position)
			var clear: float = minf(Vector2(at.x - r.x, at.z - r.z).length(), Vector2(at.x - sc.x, at.z - sc.z).length()) - b.w
			if clear < BLAST_CLEARANCE:
				near_blast += " bomb %d (%.1f m)" % [landed, clear]
			landed += 1
		# Moments.
		if t >= n.bartender_view_at and not checked.has("arrived"):
			checked["arrived"] = true
			check(runner.track_position.distance_to(seq.stand_point) < STAND_SLACK,
				"%s: the runner has walked up to the counter by the cut to the bartender's view (%.2f m off)" % [tag,
				runner.track_position.distance_to(seq.stand_point)])
		if t >= n.bartender_shot_at and not checked.has("facing"):
			checked["facing"] = true
			check(absf(rad_to_deg(angle_difference(runner.yaw, PI * 0.5))) < FACE_SLACK,
				"%s: they face the bar (%.0f°)" % [tag, rad_to_deg(runner.yaw)])
			var perch: Vector3 = stage.to_track(seq.screech.global_position)
			check(seq.screech.sitting and absf(perch.y - seq.bar.counter_top) < 0.01 and perch.x < seq.counter.x,
				"%s: the screech has hopped up and sits on the counter's top (%.2f m up)" % [tag, perch.y])
			check(seq.raid.ships.all(func(s: Node3D) -> bool: return s.global_position.y > 30.0)
				and not seq.bar.drinks[0].visible, "%s: no drinks yet" % tag)
		if t >= n.gesture_at + n.gesture_seconds * 0.5 and not checked.has("gesture"):
			checked["gesture"] = true
			var hand: Vector3 = seq.bar.rig.joint(&"hand_r").global_position
			var shoulder: Vector3 = seq.bar.rig.joint(&"upper_arm_r").global_position
			check(hand.y > shoulder.y, "%s: the bartender's hand is up, pointing to the menu" % tag)
		if t >= n.fingers_at + n.fingers_seconds * 0.5 and not checked.has("fingers"):
			checked["fingers"] = true
			var hand_r: Node3D = runner.avatar.rig.joint(&"hand_r")
			check(seq.fingers.visible and hand_r.global_position.y > runner.avatar.rig.joint(&"chest").global_position.y,
				"%s: the runner holds up two fingers" % tag)
		if t >= n.shake_at + 0.3 and not checked.has("shake"):
			checked["shake"] = true
			check(absf(angle_difference(seq.bar.bartender.rotation.y, PI * 0.5)) < 0.05 and seq.bar.shaker.visible,
				"%s: the bartender has turned his back and shakes the drinks" % tag)
		if t >= n.point_at + n.point_seconds and not checked.has("point"):
			checked["point"] = true
			check(seq.palace.pointing > 0.99 and seq.palace.fist.visible and not seq.palace.hand.visible,
				"%s: the Golden Convergence's arm is up, its finger pointing" % tag)
			var tip: Vector3 = seq.palace.to_local(seq.palace.finger_tip())
			var shoulder_at: Vector3 = seq.palace.to_local(seq.palace.shoulder.global_position)
			check(tip.z > shoulder_at.z + 3.0, "%s: it points ahead (its fingertip %.1f m in front of its shoulder)" % [tag,
				tip.z - shoulder_at.z])
		if t >= n.ships_at + 0.05 and not checked.has("back"):
			checked["back"] = true
			check(not seq.in_palace and stage.visible and stage.environment.fog_enabled and not seq.palace.visible
				and is_equal_approx(ZoneSkin.scenery_light_now, 1.0), "%s: after the palace, the beach is back as it was" % tag)
		if t >= n.raid_at + 0.1 and not checked.has("drinks"):
			checked["drinks"] = true
			check(seq.bar.drinks.all(func(d: Node3D) -> bool: return d.visible), "%s: back at the bar, the two drinks are on it" % tag)
	check(steps > 0 and seq.time >= n.duration - 0.001, "%s: it plays out to the end (%.1f s)" % [tag, seq.time])
	check(checked.size() == 8, "%s: every moment came (%s)" % [tag, checked.keys()])
	check(shark_out_at_sea and shark_high > n.breach_height * 0.5 and not shark_shown_after,
		"%s: Mecha Guppy leaps out at sea (its head %.1f m up at the top) and is gone once it has swum off" % [tag, shark_high])
	check(pov_hidden, "%s: the bartender is out of his own views" % tag)
	check(palace_ok and is_equal_approx(light_in_palace, n.palace_light) and cam_in_room,
		"%s: the Golden Palace: the street hidden, no fog, the scenery dark (%.2f), the camera in its room" % [tag, light_in_palace])
	check(landed == n.bombs.size() and near_blast == "", "%s: every bomb lands (%d), none on the runner or the screech%s" % [
		tag, landed, near_blast])
	var r_end: Vector3 = runner.track_position
	check(r_end.y < seq.water_y - 1.0 and absf(r_end.x) < stage.geo.lane_width * 0.5
		and r_end.z > n.bar_at + n.pool_from and r_end.z < n.bar_at + n.pool_from + n.pool_length,
		"%s: the runner has jumped into the pool and gone under (%s)" % [tag, r_end])
	check(seq.splashed.has("runner"), "%s: they splash into it" % tag)
	var fade: Color = seq.overlay.fade_rect.color
	check(fade.a > 0.99 and fade.r < 0.02 and fade.g < 0.02, "%s: it ends on black, after the fire" % tag)
	var log: String = "\n".join(seq.log_lines)
	var own: bool = true
	for sound: String in OWN_SOUNDS:
		own = own and log.contains("sound %s" % sound) and sfx.stream(StringName(sound)) != null
	check(own and log.contains("sound guppy_leap") and log.contains("sound gc_chime") and log.contains("sound bomb_blast")
		and log.contains("sound splash") and log.contains("palace in") and log.contains("palace out"),
		"%s: its sounds play (its own: %s)" % [tag, ", ".join(OWN_SOUNDS)])
	check(draw_calls <= PROP_DRAW_CALLS, "%s: its props add at most %d draw calls (%d)" % [tag, PROP_DRAW_CALLS, draw_calls])
	print("    beach outro %s: setup %.1f ms, a step %.2f ms on average, at most %.1f ms; props %d draw calls" % [tag,
		setup_msec, step_total / maxf(steps, 1), worst_step, draw_calls])
	check(setup_msec < SETUP_BUDGET_MSEC and worst_step < STEP_BUDGET_MSEC,
		"%s: it sets up in %.0f ms and steps in at most %.1f ms" % [tag, setup_msec, worst_step])
	await _free(seq)


## Reduced flashing: the fire comes up more slowly and darker; nothing else of it flashes.
func _test_reduced_flashing() -> void:
	var reduced: bool = Settings.flashing_reduced
	var alphas: Array[float] = []
	var full: Color = Color.BLACK
	var fire: Color = Color.BLACK
	for soft: bool in [false, true]:
		Settings.flashing_reduced = soft
		var seq: BeachOutro = _start()
		fire = seq.n.fire_color
		_run_to(seq, seq.n.fire_at + seq.n.fire_seconds * 0.5)
		alphas.append(seq.overlay.fade_rect.color.a)
		if soft:
			_run_to(seq, seq.n.fire_at + seq.n.fire_seconds * BeachOutro.SOFT_FIRE_SLOW)
			full = seq.overlay.fade_rect.color
		await _free(seq)
	Settings.flashing_reduced = reduced
	check(alphas[1] < alphas[0] - 0.1 and full.a > 0.99 and full.r < fire.r * 0.8,
		"Reduced flashing: the fire fills the picture more slowly (%.2f against %.2f) and darker (%.2f red)" % [alphas[1],
		alphas[0], full.r])


func _test_skip() -> void:
	for at: float in [1.0, 14.0, 25.5, 33.0, 38.0]:
		var seq: BeachOutro = _start()
		var ends: Array[int] = [0]
		seq.finished.connect(func() -> void: ends[0] += 1)
		_run_to(seq, at)
		seq.skip()
		var hidden: bool = not seq.screech.visible and not seq.palace.visible and not seq.raid.visible and not seq.shark.visible
		check(ends[0] == 1 and seq.done and seq.skipped and not seq.stage.visible and not seq.overlay.visible and hidden
			and is_equal_approx(ZoneSkin.scenery_light_now, 1.0),
			"skip() at %.1f s ends it at once: nothing of it shows, the scenery's light is back" % at)
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
	await tree.process_frame
	var c := App.playing_cinematic() as BeachOutro
	check(c != null and c.step.id == "beach/outro" and App.screen == null and App.run == null,
		"the campaign's Beach outro slot plays the outro, in the world, with no screen over it")
	App.skip_cinematic()
	await physics_frames(3)
	var next := App.playing_cinematic() as Cinematic
	check(App.profile.is_completed("beach/outro") and next != null and next.step.id == "dead_zone/intro",
		"skipped, it counts as done, and the Dead Zone's intro follows")
	if next != null:
		App.skip_cinematic()
		await physics_frames(3)
	App.show_title()
	await tree.process_frame
	App.profile = saved
	main.queue_free()
	App.main = null
	await tree.process_frame
