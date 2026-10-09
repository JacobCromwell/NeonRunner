extends TestSuite
## The Dead Zone's intro (DeadZoneIntro; the owner's story beats, October 9, 2026): its slot (before Dead Zone 1);
## at 3, 5 and 6 lanes the zone's look and lanes; a smoking crater that is a gap in the runner's lane; the runner
## lying in it, stirring and shaking their head, getting up and reaching for its far edge; the cut to ground level,
## where at first only their hands show over the edge, then they climb out (the hands holding the edge) and stand
## on the street; throughout, three cyborgs down the street in view, two lying still with their screens dark and a
## host crouched over them; as the runner gets up it looks over; the cut to an extreme close-up of its glitching,
## grinning screen face looking into the camera; the zone's music; ending on black; what it costs; skipping; and
## the App's flow (skipping it starts Dead Zone 1).

const LANES: Array[int] = [3, 5, 6]
const SFX_PATH: String = "res://data/audio/sfx_library.tres"
const SCENE: String = "res://scenes/cinematics/dead_zone_intro.tscn"
const STEP: float = 1.0 / 30.0
## The first shot looks down into the crater from at least this high; the second is at ground level (between these
## heights, on the street beyond the crater's far edge).
const HIGH_ABOVE: float = 3.0
const GROUND_LOW: float = 0.05
const GROUND_HIGH: float = 0.6
## The close-up: the host's screen at most this far from the camera, this near the middle of its view (degrees),
## and facing it (the cosine between the screen's facing and the way to the camera).
const CLOSE_DISTANCE: float = 1.0
const CLOSE_CENTER_DEG: float = 12.0
const CLOSE_FACING: float = 0.8
## Where the screen sits on a cyborg's head (CyborgSuit.SCREEN_CENTER) and the way it faces (the head's -z).
const SCREEN_CENTER := Vector3(0.0, 0.155, -0.142)
## The crater's props are greys: no more saturated than this (GDD §5: only hazards glow in hazard colours).
const NEUTRAL_SATURATION: float = 0.2
## While the hands hold the edge they stay this near the keys' grip point.
const GRIP_SLACK: float = 0.03
## Costs, headless: setting it up and a step of its clock (generous, so a busy machine doesn't fail them: they
## catch a gross regression; the measured numbers are printed), and what its props may add to a frame.
const SETUP_BUDGET_MSEC: float = 1500.0
const STEP_BUDGET_MSEC: float = 25.0
const PROP_DRAW_CALLS: int = 10

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
	return App.campaign.step("dead_zone/intro")


## A DeadZoneIntro for the Dead Zone's intro slot, in the tree, its clock stepped by the test.
func _start() -> DeadZoneIntro:
	var s: CampaignStep = _step()
	if s == null or s.cinematic == null or not s.cinematic.is_built():
		return null
	var seq := (load(s.cinematic.scene) as PackedScene).instantiate() as DeadZoneIntro
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


## The Dead Zone's intro slot plays this cinematic, between the Corporate zone and Dead Zone 1.
func _test_slot() -> void:
	var s: CampaignStep = _step()
	check(s != null and s.cinematic.is_built() and s.cinematic.scene == SCENE and s.zone.intro == s.cinematic,
		"the Dead Zone's intro slot is built: the runner climbing out of the crater")
	var ids := PackedStringArray()
	for step: CampaignStep in App.campaign.steps():
		ids.append(step.id)
	var at: int = ids.find("dead_zone/intro")
	check(at > 0 and ids[at - 1].begins_with("corporate/") and ids[at + 1] == "dead_zone/1",
		"it comes after the Corporate zone and before Dead Zone 1")
	var seq := (load(SCENE) as PackedScene).instantiate()
	check(seq is DeadZoneIntro and (seq as DeadZoneIntro).numbers != null, "its scene is a DeadZoneIntro with its numbers")
	seq.free()


# --- The beats -----------------------------------------------------------------------------------

func _check_intro(lanes: int) -> void:
	var tag: String = "dead_zone/intro, %d lanes" % lanes
	var t0: int = Time.get_ticks_usec()
	var seq: DeadZoneIntro = _start()
	var setup_msec: float = (Time.get_ticks_usec() - t0) / 1000.0
	check(seq != null, "%s: the Dead Zone's intro is built" % tag)
	if seq == null:
		return
	var s: CampaignStep = seq.step
	var n: DeadZoneIntroTuning = seq.n
	var stage: CineStage = seq.stage
	check(stage.skin == s.zone.skin and stage.geo.lane_count == lanes, "%s: in the zone's look, on the level's lanes" % tag)
	check(seq.playing.problems(sfx).is_empty() and seq.duration() >= 5.0 and seq.duration() <= 15.0,
		"%s: a sound timeline of 5-15 s (GDD §1): %s" % [tag, seq.playing.problems(sfx)])
	var mid: float = (seq.crater_start() + n.crater_end) * 0.5
	check(stage.gap_at(stage.start_lane, mid) and stage.gap_at(stage.start_lane, n.crater_end - 0.2)
		and not stage.gap_at(stage.start_lane, n.crater_end + 0.2) and not stage.gap_at(stage.start_lane, seq.crater_start() - 0.2),
		"%s: the crater is a gap in the runner's lane, so it looks like one" % tag)
	check(seq.crater != null and seq.crater.smoke != null and seq.crater.floor_root.get_child_count() > 1,
		"%s: down in it a floor of rubble, and smoke rising out of it" % tag)
	var hues: Array[String] = []
	for c: Color in Array(n.rubble_colors) + [n.smoke_color, n.crater_light_color]:
		if c.s > NEUTRAL_SATURATION:
			hues.append(str(c))
	check(hues.is_empty(), "%s: the crater's rubble, smoke and light are ash greys, never a hazard's colour (%s)" % [tag, hues])
	var runner := seq.actors.get(&"runner") as CineActorNode
	var host := seq.actors.get(&"host") as CineActorNode
	var bodies: Array[CineActorNode] = [seq.actors.get(&"body_a") as CineActorNode, seq.actors.get(&"body_b") as CineActorNode]
	check(host != null and host.actor.host and bodies[0] != null and bodies[1] != null and not bodies[0].actor.host
		and not bodies[1].actor.host, "%s: three cyborgs: a host and two others" % tag)
	if runner == null or host == null or bodies[0] == null or bodies[1] == null:
		await _free(seq)
		return
	var cuts: Array[float] = []
	var last_cam := Vector3.INF
	var last_fwd := Vector3.ZERO
	var high_low: float = INF
	var ground_range := Vector2(INF, -INF)
	var behind_edge: bool = true
	var lying: bool = true
	var shake_turns: int = 0
	var last_shake: float = 0.0
	var reached: bool = false
	var hands_first: String = ""
	var held: float = 0.0
	var up_on_street: bool = false
	var cyborgs_seen: bool = true
	var unseen: String = ""
	var bodies_still: bool = true
	var crouched: bool = true
	var turned_early: bool = false
	var looked: bool = false
	var close: Dictionary = {"far": 0.0, "off": 0.0, "facing": 1.0, "grin": true}
	var glitched: bool = false
	var worst_step: float = 0.0
	var max_calls: int = 0
	var steps: int = 0
	while not seq.done and steps < 2000:
		var s0: int = Time.get_ticks_usec()
		seq.advance(STEP)
		if seq.time > 0.1:
			worst_step = maxf(worst_step, (Time.get_ticks_usec() - s0) / 1000.0)
		steps += 1
		max_calls = maxi(max_calls, _draw_calls(seq.crater))
		if seq.done:
			break
		var t: float = seq.time
		var cam: Camera3D = seq.camera
		var cam_track: Vector3 = stage.to_track(cam.global_position)
		var fwd: Vector3 = -cam.global_transform.basis.z
		if last_cam != Vector3.INF and (fwd.dot(last_fwd) < 0.5 or cam.global_position.distance_to(last_cam) > 1.5):
			cuts.append(t)
		last_cam = cam.global_position
		last_fwd = fwd
		var rp: Vector3 = runner.track_position
		# The first shot: high over the crater, the runner down in it.
		if t < n.cut_at:
			high_low = minf(high_low, cam_track.y)
			lying = lying and (t >= n.stir_at or (runner.pose == &"lie" and is_equal_approx(rp.y, -n.crater_depth)
				and stage.gap_at(stage.start_lane, rp.z)))
			if t > n.shake_from and t < n.shake_to:
				if signf(runner.look) != 0.0 and signf(runner.look) != signf(last_shake):
					shake_turns += 1
				last_shake = runner.look
			if t > n.reach_at and runner.pose == &"get_up" and runner.progress > 0.99 and rp.y < -1.0 and rp.z > n.crater_end - 0.6:
				reached = true
		# The second: at ground level beyond the far edge.
		elif t > n.cut_at and t < n.close_up_at:
			ground_range = Vector2(minf(ground_range.x, cam_track.y), maxf(ground_range.y, cam_track.y))
			behind_edge = behind_edge and cam_track.z > n.crater_end + 0.5
		# At first only the hands, over the edge.
		if t > n.grab_at + 0.1 and t < n.climb_from - 0.05:
			var grip: Vector3 = runner.to_global(runner.grip_point())
			var head_y: float = runner.avatar.rig.joint(&"head").global_position.y
			if not (grip.y > -0.02 and head_y < -0.1 and cam.is_position_in_frustum(grip)):
				hands_first = "%.2f s: grip %s, head %.2f m" % [t, grip, head_y]
		if runner.pose == &"climb" and t > n.grab_at and runner.progress < CinePoses.LET_GO.x:
			held = maxf(held, runner.grip_point().length())
		if t > n.up_at + 0.1:
			up_on_street = is_zero_approx(rp.y) and rp.z > n.crater_end + 0.2 and runner.progress > 0.99
		# The cyborgs, in view throughout, until the close-up.
		if t < n.close_up_at - STEP:
			for c: CineActorNode in [host, bodies[0], bodies[1]]:
				if not cam.is_position_in_frustum(c.global_position + Vector3(0.0, 0.3, 0.0)) and unseen == "":
					unseen = "%s at %.2f s" % [c.actor.id, t]
					cyborgs_seen = false
		for b: CineActorNode in bodies:
			bodies_still = bodies_still and b.body.pose == CyborgBody.Pose.LIE and is_zero_approx(b.body.screen_power)
		crouched = crouched and host.body.pose == CyborgBody.Pose.CROUCH
		if t < n.look_at - STEP:
			turned_early = turned_early or host.body.head_turn != Vector2.ZERO
		elif t > n.look_at + n.look_seconds + 0.05:
			looked = looked or host.body.head_turn.x > deg_to_rad(n.look_turn - 1.0)
		# The close-up: its screen near, in the middle of the view, facing the camera, grinning, glitching hard.
		if t > n.close_up_at + STEP:
			var head: Node3D = host.body.rig.joint(&"head")
			var screen: Vector3 = head.global_transform * SCREEN_CENTER
			var to_cam: Vector3 = cam.global_position - screen
			var facing: float = (-head.global_basis.z).normalized().dot(to_cam.normalized())
			close["far"] = maxf(float(close["far"]), to_cam.length())
			close["off"] = maxf(float(close["off"]), rad_to_deg(fwd.angle_to(-to_cam)))
			close["facing"] = minf(float(close["facing"]), facing)
			close["grin"] = bool(close["grin"]) and host.body.face == CyborgBody.Kit.Face.CORRUPT_GRIN
			glitched = is_equal_approx(float(host.body.material.get_shader_parameter(&"glitch")), n.close_glitch)
	check(seq.done and not seq.skipped, "%s: it plays to its end" % tag)
	check(cuts.size() == 2 and absf(cuts[0] - n.cut_at) < STEP * 1.5 and absf(cuts[1] - n.close_up_at) < STEP * 1.5,
		"%s: it cuts twice, to ground level at %.2f s and to the host's face at %.2f s (%s)" % [tag, n.cut_at, n.close_up_at, cuts])
	check(high_low >= HIGH_ABOVE, "%s: the first shot looks down into the crater from high over it (%.2f m up)" % [tag, high_low])
	check(ground_range.x >= GROUND_LOW and ground_range.y <= GROUND_HIGH and behind_edge,
		"%s: the second is at ground level beyond the far edge (%.2f-%.2f m up)" % [tag, ground_range.x, ground_range.y])
	check(lying, "%s: the runner lies on their back down in the crater until they stir" % tag)
	check(shake_turns >= 3, "%s: they shake themselves, their head turning from side to side (%d turns)" % [tag, shake_turns])
	check(reached, "%s: they get up and reach up at the far wall before the cut" % tag)
	check(hands_first == "", "%s: at ground level, at first only their hands show, grabbing the edge (%s)" % [tag, hands_first])
	check(held < GRIP_SLACK, "%s: climbing out, their hands hold the edge (off by at most %.3f m)" % [tag, held])
	check(up_on_street, "%s: they end up on their feet on the street beyond the edge" % tag)
	check(cyborgs_seen, "%s: the cyborgs are in view throughout, until the close-up (%s)" % [tag, unseen])
	check(bodies_still and crouched, "%s: two lie still, their screens dark, the host crouched over them" % tag)
	check(not turned_early and looked and n.look_at > n.climb_from and n.look_at < n.up_at,
		"%s: as the runner gets up, the host looks over (and not before)" % tag)
	check(float(close["far"]) < CLOSE_DISTANCE and float(close["off"]) < CLOSE_CENTER_DEG and float(close["facing"]) > CLOSE_FACING
		and bool(close["grin"]) and glitched,
		"%s: an extreme close-up of its glitching, grinning screen looking into the camera (%s)" % [tag, close])
	check(seq.log_lines.has("music %s" % s.zone.music) and seq.log_lines.has("cue close_up")
		and seq.log_lines[seq.log_lines.size() - 1] == "effect fade_out",
		"%s: the zone's music, the close-up, and it ends on black (%s)" % [tag, seq.log_lines])
	check(setup_msec < SETUP_BUDGET_MSEC and worst_step < STEP_BUDGET_MSEC,
		"%s: cheap enough: %.1f ms to set up, at most %.2f ms a step" % [tag, setup_msec, worst_step])
	check(max_calls <= PROP_DRAW_CALLS, "%s: the crater adds at most %d draw calls (%d)" % [tag, PROP_DRAW_CALLS, max_calls])
	print("  dead zone intro, %s: setup %.1f ms, worst step %.2f ms, crater %d draw calls" % [tag, setup_msec, worst_step, max_calls])
	await _free(seq)


## Draw calls the crater's props add now (each visible mesh's surfaces).
func _draw_calls(root: Node) -> int:
	var count: int = 0
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var m := node as MeshInstance3D
		if m.is_visible_in_tree() and m.mesh != null:
			count += m.mesh.get_surface_count()
	return count


# --- Skipping and the App ----------------------------------------------------------------------------

func _test_skip() -> void:
	for at: float in [1.0, 6.5, 10.5]:
		var seq: DeadZoneIntro = _start()
		if seq == null:
			return
		var ends: Array[int] = [0]
		seq.finished.connect(func() -> void: ends[0] += 1)
		while not seq.done and seq.time < at - 0.0001:
			seq.advance(STEP)
		seq.skip()
		check(ends[0] == 1 and seq.done and seq.skipped and not seq.stage.visible and not seq.overlay.visible
			and not seq.crater.is_visible_in_tree(), "skip() at %.1f s ends it at once, and nothing of it shows (the crater too)" % at)
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
	var c := App.playing_cinematic() as DeadZoneIntro
	check(c != null and c.step.id == "dead_zone/intro" and App.screen == null and App.run == null,
		"the Dead Zone's intro slot plays the runner climbing out of the crater, in the world, with no screen over it")
	var press := InputEventAction.new()
	press.action = &"pause"
	press.pressed = true
	tree.root.push_input(press)
	await physics_frames(3)
	check(App.run != null and App.run.context.step.id == "dead_zone/1" and App.profile.is_completed("dead_zone/intro")
		and App.playing_cinematic() == null and not tree.paused,
		"the pause action skips it: Dead Zone 1 starts at once, and nothing is paused")
	App.show_title()
	await tree.process_frame
	App.profile = saved
	main.queue_free()
	App.main = null
	await tree.process_frame
