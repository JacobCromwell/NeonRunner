extends TestSuite
## Gangland's intro (GanglandIntro; the owner's story beats, October 16, 2026): its slot (after the City outro, before
## Gangland 1); at 3, 5 and 6 lanes the zone's look and lanes; the fork (a street off each side at the junction, the
## road ahead closed, the zone's wall-gap marks covered); at human height behind the runner, who looks left; the cut
## to ground level, tilting up the left gang (two cyborgs in the zone's look, a large Octodog between them); the pan
## right to the right gang (three in the zone's look, one in the Marketplace's, the leader in the Casino's, a little
## forward in the middle) and their hover truck behind them; the pan back out to both; the leader's warned shot that
## misses; the left gang angry; the Octodog's warned charge, bowling one cyborg over and pouncing on another, the
## leader dodging; the firefight; the cut back to the runner, who turns slowly to the right, their left hand coming up
## over their face, and walks off down the right-hand street; its sounds (its own, and the game's warnings each before
## its attack); what it costs; skipping; and the App's flow (skipping it starts Gangland 1).

const LANES: Array[int] = [3, 5, 6]
const SFX_PATH: String = "res://data/audio/sfx_library.tres"
const SCENE: String = "res://scenes/cinematics/gangland_intro.tscn"
const STEP: float = 1.0 / 30.0
## A cut: the camera turns or jumps further than this in one step (its own moves are far slower).
const CUT_JUMP: float = 0.5
## Human height (the first shot and the last): the camera between these heights; ground level: below this.
const HUMAN := Vector2(1.3, 2.0)
const GROUND: float = 0.3
## Back with the runner, the camera stays this near them (metres).
const NEAR: float = 8.0
## Its own sounds (tools/asset_gen/sfx_bank_gangland_intro.gd: none of them a hazard's warning).
const OWN_SOUNDS: Array[String] = ["gang_taunt", "gang_retort", "gang_jeer", "gang_rage", "octodog_tackle"]
## The miss lands at least this far from every one of the left gang (metres, from their middles).
const MISS_CLEAR: float = 0.6
## The hand over the face: the left wrist this near the head (metres), in front of it.
const HAND_NEAR: float = 0.3
## The turn is slow: the runner is most of the way round (this share of it) no sooner than SLOW_TURN after it starts
## (seconds).
const MOST_OF_TURN: float = 0.85
const SLOW_TURN: float = 1.0
## Costs, headless: setting it up and a step of its clock (generous, so a busy machine doesn't fail them: they catch
## a gross regression; the measured numbers are printed), and what its props may add to a frame.
const SETUP_BUDGET_MSEC: float = 2000.0
const STEP_BUDGET_MSEC: float = 30.0
const PROP_DRAW_CALLS: int = 140

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
	await _test_reduced_flashing()
	await _test_skip()
	await _test_app_flow()
	if music != null:
		if _music_before == &"":
			music.stop(0.0)
		else:
			music.play(_music_before, 0.0)


func _step() -> CampaignStep:
	return App.campaign.step("gangland/intro")


## A GanglandIntro for Gangland's intro slot, in the tree, its clock stepped by the test.
func _start() -> GanglandIntro:
	var s: CampaignStep = _step()
	if s == null or s.cinematic == null or not s.cinematic.is_built():
		return null
	var seq := (load(s.cinematic.scene) as PackedScene).instantiate() as GanglandIntro
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


## Gangland's intro slot plays this cinematic, between the City outro and Gangland 1.
func _test_slot() -> void:
	var s: CampaignStep = _step()
	check(s != null and s.cinematic.is_built() and s.cinematic.scene == SCENE and s.zone.intro == s.cinematic,
		"Gangland's intro slot is built: the fork in the road")
	var ids := PackedStringArray()
	for step: CampaignStep in App.campaign.steps():
		ids.append(step.id)
	var at: int = ids.find("gangland/intro")
	check(at > 0 and ids[at - 1] == "city/outro" and ids[at + 1] == "gangland/1",
		"it comes after the City outro (which drops the runner into Gangland) and before Gangland 1")
	var seq := (load(SCENE) as PackedScene).instantiate()
	check(seq is GanglandIntro and (seq as GanglandIntro).numbers != null, "its scene is a GanglandIntro with its numbers")
	seq.free()


## Its own sounds are in the library, with their files.
func _test_sounds() -> void:
	var missing := PackedStringArray()
	for sound: String in OWN_SOUNDS:
		if not sfx.names().has(sound) or not sfx.has_file(StringName(sound)):
			missing.append(sound)
	check(missing.is_empty(), "its own sounds are in the sound library, with their files (missing: %s)" % [missing])


# --- The beats -----------------------------------------------------------------------------------

func _check_intro(lanes: int) -> void:
	var tag: String = "gangland/intro, %d lanes" % lanes
	var t0: int = Time.get_ticks_usec()
	var seq: GanglandIntro = _start()
	var setup_msec: float = (Time.get_ticks_usec() - t0) / 1000.0
	check(seq != null, "%s: Gangland's intro is built" % tag)
	if seq == null:
		return
	var s: CampaignStep = seq.step
	var n: GanglandIntroTuning = seq.n
	var stage: CineStage = seq.stage
	var props: GanglandIntroSet = seq.props
	check(stage.skin == s.zone.skin and stage.geo.lane_count == lanes, "%s: in the zone's look, on the level's lanes" % tag)
	check(seq.playing.problems(sfx).is_empty() and seq.duration() >= 15.0 and seq.duration() <= 22.0,
		"%s: a sound timeline of about 20 s (the owner: 20 s is fine): %.1f s %s" % [tag, seq.duration(),
		seq.playing.problems(sfx)])
	# The fork: open to both sides at the junction, side streets of the zone's street, a building across the road.
	var j: float = n.junction_at
	check(stage.wall_open(-1, j) and stage.wall_open(1, j) and not stage.wall_open(-1, j + seq.side_half() + 2.0)
		and not stage.wall_open(1, j - seq.side_half() - 2.0),
		"%s: at the junction both walls open onto a side street" % tag)
	check(props.left_street.find_children("Floor*", "", false, false).size() == n.side_lanes
		and props.right_street.find_children("Floor*", "", false, false).size() == n.side_lanes
		and props.get_node_or_null(^"Across") != null and props.get_node_or_null(^"Corners") != null,
		"%s: both side streets have the zone's street and building fronts, and a building closes the road ahead (a fork)"
		% tag)
	# The cast.
	var zone_look: StringName = CyborgSuit.look_for(s.zone.skin.enemy_variant)
	var market_look: StringName = CyborgSuit.look_for(_zone_skin(&"marketplace").enemy_variant)
	var casino_look: StringName = CyborgSuit.look_for(_zone_skin(&"casino").enemy_variant)
	var runner := seq.actors.get(&"runner") as CineActorNode
	var leader := seq.actors.get(&"leader") as CineActorNode
	var lefts: Array[CineActorNode] = []
	var rights: Array[CineActorNode] = []
	for id: StringName in seq.actors:
		if String(id).begins_with("left_"):
			lefts.append(seq.actors[id])
		elif String(id).begins_with("right_"):
			rights.append(seq.actors[id])
	var right_looks: Dictionary = {}
	for c: CineActorNode in rights:
		right_looks[c.body.look] = int(right_looks.get(c.body.look, 0)) + 1
	check(lefts.size() == 2 and lefts[0].body.look == zone_look and lefts[1].body.look == zone_look,
		"%s: the left gang: two cyborgs in the zone's look" % tag)
	check(leader != null and leader.body.look == casino_look and rights.size() == 4
		and int(right_looks.get(zone_look, 0)) == 3 and int(right_looks.get(market_look, 0)) == 1,
		"%s: the right gang: three in the zone's look, one in the Marketplace's, the leader in the Casino's (%s)" % [
		tag, right_looks])
	check(props.dog != null and n.dog_scale > 1.3 and props.truck != null and n.truck_at.x > n.leader_at.x + 3.0,
		"%s: a large Octodog (%.2f times its size), and a hover truck behind the right gang" % [tag, n.dog_scale])
	if runner == null or leader == null or lefts.size() < 2 or rights.size() < 4:
		await _free(seq)
		return
	# The leader leads: in front of the rest (nearer the other gang) and in the middle of them.
	var behind_u: float = INF
	var mid_v: float = 0.0
	for c: Vector3 in n.right_cyborgs:
		behind_u = minf(behind_u, c.x)
		mid_v += c.y / n.right_cyborgs.size()
	check(n.leader_at.x < behind_u - 0.5 and absf(n.leader_at.y - mid_v) < 1.0 and n.leader_scale >= 1.0,
		"%s: the leader stands a little forward of the others, in the middle" % tag)

	var cuts: Array[float] = []
	var last_cam := Vector3.INF
	var last_fwd := Vector3.ZERO
	var first_shot: String = ""
	var looked_left: bool = false
	var low: String = ""
	var tilt := Vector2(INF, -INF)
	var unseen := PackedStringArray()
	var panned_right: bool = false
	var pan_from := Vector3.ZERO
	var charged: float = 0.0
	var miss_bolts: int = 0
	var angry: bool = false
	var dog_home_held: bool = true
	var windup: Vector2 = Vector2.ZERO
	var downed: Array[StringName] = []
	var leader_down: bool = false
	var firefight: int = 0
	var back_shot: String = ""
	var turned_by: float = -1.0
	var yaw_at_cut: float = 0.0
	var yaw_end: float = 0.0
	var hand_early: bool = false
	var hand_near: float = INF
	var worst_step: float = 0.0
	var max_calls: int = 0
	var steps: int = 0
	var home: Vector3 = stage.point(seq.gang(n.dog_at.x, n.dog_at.y))
	while not seq.done and steps < 2000:
		var s0: int = Time.get_ticks_usec()
		seq.advance(STEP)
		if seq.time > 0.1:
			worst_step = maxf(worst_step, (Time.get_ticks_usec() - s0) / 1000.0)
		steps += 1
		max_calls = maxi(max_calls, _draw_calls(props))
		if seq.done:
			break
		var t: float = seq.time
		var cam: Camera3D = seq.camera
		var cam_track: Vector3 = stage.to_track(cam.global_position)
		var fwd: Vector3 = -cam.global_transform.basis.z
		if last_cam != Vector3.INF and (fwd.dot(last_fwd) < 0.5 or cam.global_position.distance_to(last_cam) > CUT_JUMP):
			cuts.append(t)
		last_cam = cam.global_position
		last_fwd = fwd
		var rp: Vector3 = runner.track_position
		# At human height behind the runner, who comes to the fork and looks left.
		if t < n.gang_at - STEP:
			if (cam_track.y < HUMAN.x or cam_track.y > HUMAN.y or cam_track.z > rp.z - 1.0) and first_shot == "":
				first_shot = "%.2f s: camera %s, runner %s" % [t, cam_track, rp]
			if t > n.look_at + n.look_seconds:
				looked_left = rad_to_deg(runner.yaw + runner.look) > 60.0 and rp.distance_to(seq.stand) < 0.05
		# Down the left-hand street at ground level, tilting up the left gang.
		elif t < n.pan_at and t > n.gang_at + 0.01:
			if cam_track.y > GROUND and low == "":
				low = "%.2f s: %.2f m up" % [t, cam_track.y]
			tilt = Vector2(minf(tilt.x, fwd.y), maxf(tilt.y, fwd.y))
			if t > n.tilt_end - STEP:
				_seen(cam, Array(lefts) + [props.dog], "the left gang", t, unseen)
			pan_from = fwd
		# The pan right to the right gang and their truck.
		elif t < n.wide_at:
			if t > n.pan_at + n.pan_seconds:
				panned_right = pan_from.cross(fwd).y < -0.5
				_seen(cam, Array(rights) + [leader, props.truck], "the right gang", t, unseen)
		# Out to both, held through the yelling and the shot.
		elif t < n.charge_cut - STEP:
			if t > n.wide_at + n.wide_seconds:
				_seen(cam, Array(lefts) + Array(rights) + [leader, props.dog], "both gangs", t, unseen)
		if t < n.shot_at:
			charged = maxf(charged, leader.body.charge)
		elif t < n.shot_at + n.shot_seconds:
			miss_bolts = props.bolts_shown()
		if t > n.angry_at + 0.05 and t < n.charge_at:
			angry = lefts[0].body.face == CyborgBody.Kit.Face.AIMING and lefts[1].body.face == CyborgBody.Kit.Face.AIMING
		if t < n.windup_at - STEP:
			dog_home_held = dog_home_held and props.dog.global_position.distance_to(home) < 0.05
		elif t < n.charge_at:
			windup = Vector2(maxf(windup.x, props.dog.crouch), maxf(windup.y, props.dog.flare))
		if t > seq.t_pounce + 0.5:
			downed.clear()
			for c: CineActorNode in rights:
				if c.body.pose == CyborgBody.Pose.LIE:
					downed.append(c.actor.id)
			leader_down = leader_down or leader.body.pose == CyborgBody.Pose.LIE
		if t > n.fire_at and t < n.back_at:
			firefight = maxi(firefight, props.bolts_shown())
		# Back with the runner: at human height, near them; they turn slowly to the right, the hand coming up.
		if t > n.back_at + STEP:
			if (cam_track.y < HUMAN.x or cam_track.y > HUMAN.y or cam.global_position.distance_to(runner.global_position) > NEAR
					or not cam.is_position_in_frustum(runner.global_position + Vector3(0.0, 1.0, 0.0))) and back_shot == "":
				back_shot = "%.2f s: camera %s" % [t, cam_track]
		if t < seq.t_turn:
			yaw_at_cut = rad_to_deg(runner.yaw)
			var hand: Vector3 = runner.avatar.rig.joint(&"hand_l").global_position
			hand_early = hand_early or hand.distance_to(runner.avatar.rig.joint(&"head").global_position) < HAND_NEAR
		else:
			if turned_by < 0.0 and rad_to_deg(runner.yaw) < lerpf(yaw_at_cut, n.turn_degrees, MOST_OF_TURN):
				turned_by = t - seq.t_turn
			yaw_end = rad_to_deg(runner.yaw)
			if t > seq.t_turn + n.hand_seconds:
				var head: Node3D = runner.avatar.rig.joint(&"head")
				var hand: Vector3 = runner.avatar.rig.joint(&"hand_l").global_position
				var ahead: Vector3 = -runner.avatar.global_basis.z
				var off: Vector3 = hand - head.global_position
				hand_near = minf(hand_near, off.length()) if off.dot(ahead) > 0.0 else hand_near
	var end: Vector3 = runner.track_position
	check(seq.done and not seq.skipped, "%s: it plays to its end" % tag)
	check(cuts.size() == 3 and absf(cuts[0] - n.gang_at) < STEP * 1.5 and absf(cuts[1] - n.charge_cut) < STEP * 1.5
		and absf(cuts[2] - n.back_at) < STEP * 1.5,
		"%s: it cuts three times, to the gangs at %.2f s, to the charge at %.2f s and back to the runner at %.2f s (%s)" % [
		tag, n.gang_at, n.charge_cut, n.back_at, cuts])
	check(first_shot == "" and looked_left,
		"%s: at human height behind the runner, who comes to the fork and looks left (%s)" % [tag, first_shot])
	check(low == "" and tilt.y > tilt.x + 0.15, "%s: down the left-hand street at ground level, tilting up (%s, %s)" % [
		tag, low, tilt])
	check(panned_right, "%s: the camera pans right to the other gang" % tag)
	check(unseen.is_empty(), "%s: each gang in the picture as the camera comes to it, then both (%s)" % [tag, unseen])
	check(charged > 0.9 and miss_bolts >= 1 and n.aim_at < n.shot_at,
		"%s: the leader charges its arm cannon (the red glow, its warning) and fires" % tag)
	var miss: Vector3 = stage.point(seq.gang(n.miss_at.x, n.miss_at.z, n.miss_at.y))
	var nearest: float = INF
	for c: Vector3 in n.left_cyborgs:
		nearest = minf(nearest, Vector2(miss.x, miss.z).distance_to(_flat(stage.point(seq.gang(c.x, c.y)))))
	nearest = minf(nearest, Vector2(miss.x, miss.z).distance_to(_flat(home)))
	check(nearest > MISS_CLEAR, "%s: the shot misses: it bursts %.2f m from the nearest of the left gang" % [tag, nearest])
	check(angry, "%s: the left gang gets angry (their faces) after the miss" % tag)
	check(dog_home_held and windup.x > 0.4 and windup.y > 0.9 and n.windup_at < n.charge_at,
		"%s: their Octodog holds its ground, then rears up (its wind-up, its warning) before it charges (%s)" % [
		tag, windup])
	check(downed.size() == 2 and not leader_down,
		"%s: it bowls one cyborg over and pounces on another; the leader dodges (%s down)" % [tag, downed])
	check(firefight >= 3, "%s: those left standing open fire (%d bolts in the air at once)" % [tag, firefight])
	check(back_shot == "", "%s: back with the runner, at human height, near them and in view (%s)" % [tag, back_shot])
	check(yaw_at_cut > 15.0 and yaw_end < -60.0 and turned_by > SLOW_TURN,
		"%s: they turn slowly to the right (from %.0f° to %.0f°, most of the way round only after %.2f s)" % [
		tag, yaw_at_cut, yaw_end, turned_by])
	check(not hand_early and hand_near < HAND_NEAR and seq.hand_up > 0.99,
		"%s: their left hand comes up in front of their face as they turn, and stays up (%.2f m from the head)" % [
		tag, hand_near])
	check(end.x > seq.stand.x + 3.0 and end.x > stage.wall_x(1) - 3.0 and absf(end.z - j) < seq.side_half(),
		"%s: and they walk off toward the right-hand street (%s)" % [tag, end])
	check(seq.log_lines.has("music %s" % s.zone.music), "%s: the zone's music (%s)" % [tag, seq.log_lines])
	var heard := PackedStringArray()
	for line: String in seq.log_lines:
		if line.begins_with("sound "):
			heard.append(line.trim_prefix("sound "))
	var own_heard: bool = true
	for sound: String in OWN_SOUNDS:
		own_heard = own_heard and heard.has(sound)
	check(own_heard, "%s: its own sounds play (%s)" % [tag, heard])
	# The game's warnings keep their meaning: each right before the attack it warns of.
	var charge_at: int = heard.find("cyborg_charge")
	var windup_at: int = heard.find("octodog_windup")
	check(charge_at >= 0 and heard.find("cyborg_shot", charge_at) > charge_at and heard.find("cyborg_shot") > charge_at
		and windup_at >= 0 and heard.find("octodog_lunge") == windup_at + 1,
		"%s: the cyborg's charge-up comes before its shot, the Octodog's wind-up right before its lunge" % tag)
	check(setup_msec < SETUP_BUDGET_MSEC and worst_step < STEP_BUDGET_MSEC,
		"%s: cheap enough: %.1f ms to set up, at most %.2f ms a step" % [tag, setup_msec, worst_step])
	check(max_calls <= PROP_DRAW_CALLS, "%s: its props add at most %d draw calls (%d)" % [tag, PROP_DRAW_CALLS, max_calls])
	print("  gangland intro, %s: setup %.1f ms, worst step %.2f ms, props %d draw calls" % [tag, setup_msec, worst_step,
		max_calls])
	await _free(seq)


## A zone's skin by its id.
func _zone_skin(id: StringName) -> ZoneSkin:
	for z: ZoneDef in App.campaign.zones:
		if z.id == id:
			return z.skin
	return null


static func _flat(p: Vector3) -> Vector2:
	return Vector2(p.x, p.z)


## Notes any of `nodes` (actors or props) whose middle isn't in the camera's view at `t`.
func _seen(cam: Camera3D, nodes: Array, what: String, t: float, out: PackedStringArray) -> void:
	for node: Node3D in nodes:
		if node != null and not cam.is_position_in_frustum(node.global_position + Vector3(0.0, 0.8, 0.0)):
			out.append("%s: %s at %.2f s" % [what, node.name, t])
			return


## Draw calls the props add now (each visible mesh's surfaces), the stage's own street pieces aside.
func _draw_calls(root: Node) -> int:
	var count: int = 0
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var m := node as MeshInstance3D
		if m.is_visible_in_tree() and m.mesh != null:
			count += m.mesh.get_surface_count()
	return count


# --- Reduced flashing, skipping and the App -----------------------------------------------------

## With Reduced flashing the bolts' bursts are smaller and slower; nothing in it flashes (its two shakes follow the
## Screen shake setting).
func _test_reduced_flashing() -> void:
	var was: bool = Settings.flashing_reduced
	Settings.flashing_reduced = true
	var seq: GanglandIntro = _start()
	if seq == null:
		Settings.flashing_reduced = was
		return
	var biggest: float = 0.0
	while not seq.done and seq.time < seq.n.back_at:
		seq.advance(STEP)
		for b: MeshInstance3D in seq.props.bursts:
			if b.visible:
				biggest = maxf(biggest, b.scale.x)
	var flashes := PackedStringArray()
	for e: CineEvent in seq.playing.events:
		if e.kind == CineEvent.Kind.EFFECT and e.name == CineEvent.FLASH:
			flashes.append("%.2f s" % e.time)
	check(biggest > 0.0 and biggest <= GanglandIntroSet.SOFT_BURST_SIZE + 0.001 and flashes.is_empty(),
		"with Reduced flashing the bolts' bursts are smaller (%.2f m at most) and nothing flashes (%s)" % [biggest, flashes])
	Settings.flashing_reduced = was
	await _free(seq)


func _test_skip() -> void:
	for at: float in [1.0, 5.0, 12.95, 14.6, 18.0]:
		var seq: GanglandIntro = _start()
		if seq == null:
			return
		var ends: Array[int] = [0]
		seq.finished.connect(func() -> void: ends[0] += 1)
		while not seq.done and seq.time < at - 0.0001:
			seq.advance(STEP)
		seq.skip()
		check(ends[0] == 1 and seq.done and seq.skipped and not seq.stage.visible and not seq.overlay.visible
			and not seq.props.is_visible_in_tree(), "skip() at %.1f s ends it at once, and nothing of it shows" % at)
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
	var c := App.playing_cinematic() as GanglandIntro
	check(c != null and c.step.id == "gangland/intro" and App.screen == null and App.run == null,
		"Gangland's intro slot plays the fork in the road, in the world, with no screen over it")
	var press := InputEventAction.new()
	press.action = &"pause"
	press.pressed = true
	tree.root.push_input(press)
	await physics_frames(3)
	check(App.run != null and App.run.context.step.id == "gangland/1" and App.profile.is_completed("gangland/intro")
		and App.playing_cinematic() == null and not tree.paused,
		"the pause action skips it: Gangland 1 starts at once, and nothing is paused")
	App.show_title()
	await tree.process_frame
	App.profile = saved
	main.queue_free()
	App.main = null
	await tree.process_frame
