extends TestSuite
## The Marketplace's intro (MarketplaceIntro; the owner's beats, October 16, 2026): its slot (before Marketplace 1); at
## 3, 5 and 6 lanes the zone's look and lanes; the line of market stalls (the stall doodad's cards) along the left of the
## street, end to end, inside it; the stall-keeper in hers, facing the street; the runner walking up to her counter and
## facing it before they show the card; the card hidden until then, then in their hand, its face to her; the close-up
## on it (the card filling much of the picture, facing the camera); her mouth working only while she talks; the
## runner's two nods, then off down the street; the cyborg out of sight until the street behind her stall shows, at the
## counter before it talks; her arm pointing after the runner; the others waved over and all of them following the
## runner down the street; nobody walking through the stalls; the camera inside the street; the voices (mumbling, no
## words) and the zone's title card; what it costs. Then skipping, and the App's flow (skipping it starts
## Marketplace 1).

const LANES: Array[int] = [3, 5, 6]
const SFX_PATH: String = "res://data/audio/sfx_library.tres"
const SCENE: String = "res://scenes/cinematics/marketplace_intro.tscn"
const STEP: float = 1.0 / 30.0
## Its voices, in the order they're heard (tools/asset_gen/sfx_bank_marketplace_intro.gd).
const VOICES: Array[String] = ["mumble_vendor", "mumble_cyborg", "mumble_vendor_point", "mumble_cyborg_call"]
## A sound effect is under this long (every bank's rule).
const MAX_SOUND_SECONDS: float = 2.5
## The runner stops within this of their place at the counter, and faces it within this (degrees).
const STAND_SLACK: float = 0.06
const FACE_SLACK: float = 10.0
## In the close-up the card is this near the middle of the view (degrees), faces the camera this squarely (the cosine),
## and fills at least this share of the picture's width.
const CARD_CENTER_DEG: float = 6.0
const CARD_FACING: float = 0.95
const CARD_FILL: float = 0.35
## Held up, the card's bottom edge is within this of the runner's wrist (metres): in their hand.
const HAND_REACH: float = 0.12
## Walkers keep at least this far out from the stalls' counters (metres).
const STALL_CLEARANCE: float = 0.15
## Her arm points within this of the runner (the cosine between the arm and the way to them).
const POINT_AIM: float = 0.85
## Over open street the camera keeps under this (nothing hangs lower).
const CAMERA_TOP: float = 9.5
## Costs, headless (generous: they catch a gross regression; the measured numbers are printed), and what its props may
## add to a frame.
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
	_test_voices()
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
	return App.campaign.step("marketplace/intro")


## A MarketplaceIntro for the Marketplace's intro slot, in the tree, its clock stepped by the test.
func _start() -> MarketplaceIntro:
	var s: CampaignStep = _step()
	if s == null or s.cinematic == null or not s.cinematic.is_built():
		return null
	var seq := (load(s.cinematic.scene) as PackedScene).instantiate() as MarketplaceIntro
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
		"the Marketplace's intro slot is built: the runner asking round the market stalls")
	var next: CampaignStep = App.campaign.next_step(s) if s != null else null
	check(next != null and next.id == "marketplace/1", "Marketplace 1 follows it")
	var seq := (load(SCENE) as PackedScene).instantiate()
	check(seq is MarketplaceIntro and (seq as MarketplaceIntro).numbers != null, "its scene is a MarketplaceIntro with its numbers")
	seq.free()


## The voices are in the library, each a sound file under the sound effects' length.
func _test_voices() -> void:
	for v: String in VOICES:
		var stream := sfx.stream(StringName(v)) as AudioStreamWAV
		check(sfx.has_file(StringName(v)) and stream != null, "its voice %s is a sound in the library" % v)
		if stream != null:
			check(stream.get_length() > 0.3 and stream.get_length() < MAX_SOUND_SECONDS,
				"%s is %.2f s (under %.1f s)" % [v, stream.get_length(), MAX_SOUND_SECONDS])


# --- The beats -----------------------------------------------------------------------------------

func _check_intro(lanes: int) -> void:
	var t0: int = Time.get_ticks_usec()
	var seq: MarketplaceIntro = _start()
	var setup_msec: float = (Time.get_ticks_usec() - t0) / 1000.0
	if seq == null:
		check(false, "%d lanes: the intro starts" % lanes)
		return
	var n: MarketplaceIntroTuning = seq.n
	var stage: CineStage = seq.stage
	var props: MarketplaceIntroSet = seq.props
	var tag: String = "%d lanes" % lanes
	check(stage.geo.lane_count == lanes and stage.skin == _step().zone.skin,
		"%s: it plays on the zone's look, in the level's lanes" % tag)
	check(seq.playing.problems(sfx).is_empty(), "%s: its timeline has no problems (%s)" % [tag, seq.playing.problems(sfx)])
	# The stalls: a line of them along the left of the street, end to end, inside it; hers in the line.
	var back: float = props.front_x - props.stall_size.x
	check(props.stalls.size() == n.stall_count and back >= stage.wall_x(-1) - 0.01 and props.front_x < stage.lane_x(stage.start_lane),
		"%s: %d stalls stand along the left of the street, their backs at its wall line" % [tag, n.stall_count])
	var apart: bool = true
	for i: int in range(1, props.stall_z.size()):
		apart = apart and props.stall_z[i] - props.stall_z[i - 1] >= props.stall_size.z - 0.001
	check(apart and is_equal_approx(props.stall_z[n.vendor_stall], n.stall_at), "%s: end to end, hers among them" % tag)
	var cards_ok: bool = true
	for st: MeshInstance3D in props.stalls:
		cards_ok = cards_ok and DoodadCards.is_card_material(st.material_override)
	check(cards_ok, "%s: each stall is the Marketplace's stall doodad (its picture cards)" % tag)
	var v: Vector3 = stage.to_track(props.vendor.global_position)
	var faces: Vector3 = props.vendor.global_basis * Vector3.FORWARD
	check(v.x < props.front_x and v.x > back and absf(v.z - n.stall_at - n.counter_along) < 0.01 and absf(n.counter_along) < props.stall_size.z * 0.5 - 0.3 and faces.x > 0.99,
		"%s: the stall-keeper stands in her stall, facing the street" % tag)

	var runner := seq.actors[&"runner"] as CineActorNode
	var cyborg := seq.actors[&"cyborg"] as CineActorNode
	var others: Array[CineActorNode] = []
	for id: StringName in seq.others:
		others.append(seq.actors[id] as CineActorNode)
	var worst_step: float = 0.0
	var step_total: float = 0.0
	var steps: int = 0
	var card_early: bool = false
	var card_in_close_up: bool = true
	var close_checked: bool = false
	var talking_off: bool = true
	var talking_on: float = 0.0
	var cyborg_early: bool = false
	var through_stalls: String = ""
	var camera_out: String = ""
	var point_best: float = -1.0
	var nod_low: float = 0.0
	var draw_calls: int = 0
	var checked: Dictionary = {}
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
		var cam: Vector3 = stage.to_track(seq.camera.global_position)
		if camera_out == "" and (cam.x < stage.wall_x(-1) or cam.x > stage.wall_x(1) or cam.y > CAMERA_TOP or cam.y < 0.2):
			camera_out = "%.2f s at %s" % [t, cam]
		if t < n.show_at - 0.01 and props.card.visible:
			card_early = true
		# Walkers keep out of the stalls.
		for a: CineActorNode in [runner, cyborg] + others:
			if a.visible and through_stalls == "":
				var p: Vector3 = a.track_position
				var along: bool = p.z > props.stall_z[0] - props.stall_size.z * 0.5 and p.z < props.stall_z[props.stall_z.size() - 1] + props.stall_size.z * 0.5
				if along and p.x < props.front_x + STALL_CLEARANCE:
					through_stalls = "%s at %.2f s (%s)" % [a.actor.id, t, p]
		if t < n.street_shot_at - 0.01 and (cyborg.visible or others.any(func(o: CineActorNode) -> bool: return o.visible)):
			cyborg_early = true
		# Her mouth: shut but while she talks.
		var talking: bool = (t >= n.talk_at and t <= n.talk_at + n.talk_seconds) or (t >= n.reply_at and t <= n.reply_at + n.reply_seconds)
		if not talking and props.vendor.mouth_open() > 0.01:
			talking_off = false
		if talking:
			talking_on = maxf(talking_on, props.vendor.mouth_open())
		if t >= n.nod_at and t <= n.nod_at + n.nod_seconds * 2.0:
			nod_low = minf(nod_low, rad_to_deg(runner.look_up))
		# The close-up: the card in the middle of the view, big and square to the camera.
		if t >= n.card_shot_at + 0.2 and t < n.talk_shot_at - 0.05:
			close_checked = true
			var c: Vector3 = props.card.global_position
			var to_cam: Vector3 = (seq.camera.global_position - c).normalized()
			var ahead: Vector3 = -seq.camera.global_basis.z
			var off: float = rad_to_deg(ahead.angle_to(c - seq.camera.global_position))
			var facing: float = (props.card.global_basis.z).dot(to_cam)
			var share: float = _card_share(seq)
			if not (props.card.visible and not props.vendor.visible and off < CARD_CENTER_DEG and facing > CARD_FACING and share > CARD_FILL):
				if card_in_close_up:
					print("    close-up at %.2f s: visible %s, %.1f° off the middle, facing %.3f, %.2f of the width" % [t,
						props.card.visible, off, facing, share])
				card_in_close_up = false
		# Her arm pointing after the runner.
		if t >= n.point_at + 0.6 and t <= n.point_at + n.point_seconds - 0.6:
			var side: StringName = &"l"
			var local: Vector3 = props.vendor.global_transform.affine_inverse() * runner.global_position
			if local.x > 0.0:
				side = &"r"
			var upper: Node3D = props.vendor.rig.joint(StringName("upper_arm_%s" % side))
			var hand: Node3D = props.vendor.rig.joint(StringName("hand_%s" % side))
			var arm: Vector3 = (hand.global_position - upper.global_position).normalized()
			var want: Vector3 = (seq._head_of(runner) - upper.global_position).normalized()
			point_best = maxf(point_best, arm.dot(want))
		if not checked.has("arrive") and t >= n.show_at:
			checked["arrive"] = true
			var face_err: float = absf(rad_to_deg(angle_difference(runner.yaw, PI * 0.5)))
			check(runner.track_position.distance_to(seq.stand_point) < STAND_SLACK and face_err < FACE_SLACK,
				"%s: the runner has walked up to her counter and faces it before showing the card (%.2f m off, %.1f° off)" % [
				tag, runner.track_position.distance_to(seq.stand_point), face_err])
		if not checked.has("held") and t >= n.show_at + n.raise_seconds + 0.1:
			checked["held"] = true
			var to_her: Vector3 = (stage.point(seq.vendor_eyes) - props.card.global_position).normalized()
			check(props.card.visible and props.card.global_basis.z.dot(to_her) > 0.99,
				"%s: the card is held up, its face to her" % tag)
			var hand: Node3D = runner.avatar.rig.joint(&"hand_r")
			var bottom: Vector3 = props.card.global_position - props.card.global_basis.y * n.card_size.y * 0.5
			check(hand.global_position.distance_to(bottom) < HAND_REACH,
				"%s: the runner's hand holds it at its bottom edge (%.3f m away)" % [tag, hand.global_position.distance_to(bottom)])
		if not checked.has("cyborg") and t >= n.cyborg_talk_at:
			checked["cyborg"] = true
			check(cyborg.visible and cyborg.track_position.distance_to(seq.cyborg_point) < STAND_SLACK,
				"%s: the cyborg is at her counter when it talks" % tag)
		if not checked.has("end") and t >= n.fade_at:
			checked["end"] = true
			check(not props.card.visible and runner.track_position.z > seq.stand_point.z + 15.0,
				"%s: the runner has put the card away and gone off down the street" % tag)
			var lagging: String = ""
			for o: CineActorNode in [cyborg] + others:
				if not (o.visible and o.track_position.z > seq.cyborg_point.z and o.track_position.z < runner.track_position.z - 3.0
						and o.speed > 1.0 and absf(rad_to_deg(angle_difference(o.yaw, 0.0))) < 45.0):
					lagging += " %s at %s, %.2f m/s, heading %.0f°;" % [o.actor.id, o.track_position, o.speed, rad_to_deg(o.yaw)]
			check(lagging == "", "%s: the cyborg and the others it waved over are following the runner down the street (%s)" % [
				tag, lagging])
	check(not card_early, "%s: the card stays out of sight until the runner shows it" % tag)
	check(close_checked and card_in_close_up,
		"%s: the close-up shows the card in the middle, square on, filling much of the picture (from her view: she's hidden)" % tag)
	check(talking_off and talking_on > 0.5, "%s: her mouth works while she talks, and only then (%.2f)" % [tag, talking_on])
	check(nod_low < -10.0, "%s: the runner nods (head down %.0f°)" % [tag, nod_low])
	check(not cyborg_early, "%s: no cyborg shows before the street behind her stall does" % tag)
	check(point_best > POINT_AIM, "%s: she points after the runner (%.2f)" % [tag, point_best])
	check(through_stalls == "", "%s: nobody walks through the stalls (%s)" % [tag, through_stalls])
	check(camera_out == "", "%s: the camera keeps inside the street (%s)" % [tag, camera_out])
	var voices := PackedStringArray()
	var titled: bool = false
	for line: String in seq.log_lines:
		if line.begins_with("sound mumble"):
			voices.append(line.get_slice(" ", 1))
		titled = titled or line.begins_with("text ")
	check(voices == PackedStringArray(VOICES), "%s: its voices, in order (%s)" % [tag, voices])
	check(titled, "%s: the zone's title card comes up at the end" % tag)
	var mean: float = step_total / maxf(float(steps), 1.0)
	print("    %s: set up %.1f ms, a step %.2f ms on average, %.2f ms at worst; props %d draw calls" % [tag, setup_msec, mean,
		worst_step, draw_calls])
	check(setup_msec < SETUP_BUDGET_MSEC and worst_step < STEP_BUDGET_MSEC and draw_calls <= PROP_DRAW_CALLS,
		"%s: it costs little (set up %.0f ms, a step at worst %.1f ms, %d draw calls)" % [tag, setup_msec, worst_step, draw_calls])
	await _free(seq)


## The share of the picture's width the card fills now (0 if a corner is off it).
func _card_share(seq: MarketplaceIntro) -> float:
	var size: Vector2 = seq.camera.get_viewport().get_visible_rect().size
	var half: Vector2 = seq.n.card_size * 0.5
	var lo: float = INF
	var hi: float = -INF
	for corner: Vector2 in [Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(-half.x, half.y), Vector2(half.x, half.y)]:
		var w: Vector3 = seq.props.card.global_transform * Vector3(corner.x, corner.y, 0.0)
		if not seq.camera.is_position_in_frustum(w):
			return 0.0
		var p: Vector2 = seq.camera.unproject_position(w)
		lo = minf(lo, p.x)
		hi = maxf(hi, p.x)
	return (hi - lo) / size.x


# --- Skipping and the App ----------------------------------------------------------------------------

func _test_skip() -> void:
	for at: float in [1.0, 8.0, 20.0, 30.0, 36.0]:
		var seq: MarketplaceIntro = _start()
		if seq == null:
			return
		var ends: Array[int] = [0]
		seq.finished.connect(func() -> void: ends[0] += 1)
		while not seq.done and seq.time < at - 0.0001:
			seq.advance(STEP)
		seq.skip()
		check(ends[0] == 1 and seq.done and seq.skipped and not seq.stage.visible and not seq.overlay.visible
			and not seq.props.is_visible_in_tree(), "skip() at %.1f s ends it at once, and nothing of it shows (its props too)" % at)
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
	var c := App.playing_cinematic() as MarketplaceIntro
	check(c != null and c.step.id == "marketplace/intro" and App.screen == null and App.run == null,
		"the Marketplace's intro slot plays it, in the world, with no screen over it")
	var press := InputEventAction.new()
	press.action = &"pause"
	press.pressed = true
	tree.root.push_input(press)
	await physics_frames(3)
	check(App.run != null and App.run.context.step.id == "marketplace/1" and App.profile.is_completed("marketplace/intro")
		and App.playing_cinematic() == null and not tree.paused,
		"the pause action skips it: Marketplace 1 starts at once, and nothing is paused")
	App.show_title()
	await tree.process_frame
	App.profile = saved
	main.queue_free()
	App.main = null
	await tree.process_frame
