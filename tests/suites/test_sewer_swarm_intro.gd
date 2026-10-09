extends TestSuite
## Gangland's boss intro (SewerSwarmIntro, task F2b; the owner's beat, GDD §10 Sewer Swarm, "Intro cinematic"):
## its slot (after Gangland 3, before the fight); at 3, 5 and 6 lanes the fight's look, lanes and speed, the
## camera at ground level and in the street, cutting once (into the swarm's heart), the owner's beats on time
## (one screech at 2 s, three at 3 s with two on one side and one on the other, eleven at 4 s with five on the
## left and six on the right), each out of a manhole one lane over that rattles first; the runner never touching
## a screech (they jump, slide and weave); more and more screeches pouring out and dropping from out of the
## camera's view, beside the runner and never in their lane; the wall rising behind them and closing in; the
## swarm's dark heart and the Host's glint only in the cut; the fight's music; ending on black; the street built
## far enough ahead; what it costs to set up and to play; Reduced flashing (the glint a slow, faint glow); the
## low-end crowd sizes; skipping; saves from before the slot (they keep what they unlocked); and the App's flow
## (skipping it starts the Sewer Swarm). Its campaign flow from Gangland 3 is test_sewer_swarm_whole's.

const LANES: Array[int] = [3, 5, 6]
const SFX_PATH: String = "res://data/audio/sfx_library.tres"
const STEP: float = 1.0 / 30.0
const SCENE: String = "res://scenes/cinematics/sewer_swarm_intro.tscn"
## The camera stays at ground level (owner: "so that way we feel like we are more in the shoes of the
## character"): between these heights, and this far inside the walls.
const GROUND_LOW: float = 0.3
const GROUND_HIGH: float = 1.2
const WALL_CLEARANCE: float = 1.0
## The runner's body for touching a screech (half its width and depth, its height running and sliding), and
## a screech's body at a lone screech's size (half width, half length, height): a little smaller than the
## models, as hitboxes are (CLAUDE.md principle 4).
const RUNNER_HALF := Vector2(0.28, 0.24)
const RUNNER_TALL: float = 1.25
const RUNNER_SLIDING: float = 0.62
const SCREECH_HALF := Vector2(0.24, 0.34)
const SCREECH_TALL: float = 0.45
## Costs, headless: setting it up and a step of its clock (generous, so a busy machine doesn't fail them: they
## catch a gross regression; the measured numbers are printed, about 15-30 ms and 3 ms), and what its props may
## add to a frame (draw calls).
## Looking down the street before the wall rises, the camera sees it built at least this far ahead (Gangland's fog
## thickens to its full by about 165 m).
const STREET_AHEAD: float = 150.0
const SETUP_BUDGET_MSEC: float = 1500.0
const STEP_BUDGET_MSEC: float = 25.0
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
		await _check_swarm_intro(lanes)
	App.rules.lanes_pc = lanes_pc
	await _test_glint_reduced()
	await _test_low_end()
	await _test_skip()
	_test_old_save()
	await _test_app_flow()
	if music != null:
		if _music_before == &"":
			music.stop(0.0)
		else:
			music.play(_music_before, 0.0)


func _step() -> CampaignStep:
	return App.campaign.step("gangland/boss_intro")


## A SewerSwarmIntro for Gangland's boss-intro slot, in the tree, its clock stepped by the test.
func _start() -> SewerSwarmIntro:
	var s: CampaignStep = _step()
	if s == null or s.cinematic == null or not s.cinematic.is_built():
		return null
	var seq := (load(s.cinematic.scene) as PackedScene).instantiate() as SewerSwarmIntro
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


## Gangland has a boss-intro slot, between its last level and the fight, and it plays this cinematic.
func _test_slot() -> void:
	var s: CampaignStep = _step()
	check(s != null and s.cinematic.is_built() and s.cinematic.scene == SCENE and s.zone.boss_intro == s.cinematic,
		"Gangland's boss-intro slot is built: it plays the swarm rising")
	var ids := PackedStringArray()
	for step: CampaignStep in App.campaign.steps():
		ids.append(step.id)
	var at: int = ids.find("gangland/boss_intro")
	check(at > 0 and ids[at - 1] == "gangland/3" and ids[at + 1] == "gangland/boss",
		"it comes after Gangland 3 and before the Sewer Swarm")
	var seq := (load(SCENE) as PackedScene).instantiate()
	check(seq is SewerSwarmIntro and (seq as SewerSwarmIntro).numbers != null, "its scene is a SewerSwarmIntro with its numbers")
	seq.free()


# --- The beats -----------------------------------------------------------------------------------

## In the fight's look, lanes and speed; the camera at ground level and in the street, cutting once (into the
## swarm's heart); the beats on time and as the owner told them (one screech at 2 s, three at 3 s, two on one
## side and one on the other, eleven at 4 s, five on the left and six on the right), each out of a manhole one
## lane over that rattled first; the runner never touching one (they jump, slide and weave); more and more
## screeches pouring out and dropping from out of sight, landing beside the runner, never in their lane; the
## wall rising behind them and closing in; the heart only in the cut, its glint once there; the fight's music;
## ending on black.
func _check_swarm_intro(lanes: int) -> void:
	var tag: String = "gangland/boss_intro, %d lanes" % lanes
	var t0: int = Time.get_ticks_usec()
	var seq: SewerSwarmIntro = _start()
	var setup_msec: float = (Time.get_ticks_usec() - t0) / 1000.0
	check(seq != null, "%s: Gangland's boss intro is built: the swarm rising" % tag)
	if seq == null:
		return
	var s: CampaignStep = seq.step
	var n: SewerSwarmIntroTuning = seq.n
	check(seq.stage.skin == s.zone.boss.arena.skin and seq.stage.geo.lane_count == lanes and is_equal_approx(seq.speed, s.zone.run_speed),
		"%s: in the fight's arena look, on the level's lanes, at the fight's speed (%.1f m/s)" % [tag, seq.speed])
	check(seq.playing.problems(sfx).is_empty() and seq.duration() >= 5.0 and seq.duration() <= 15.0,
		"%s: a sound timeline of 5-15 s (GDD §1): %s" % [tag, seq.playing.problems(sfx)])
	var sc: SwarmIntroScreeches = seq.screeches
	var sw: SwarmIntroSwarm = seq.swarm
	var runner := seq.actors.get(&"runner") as CineActorNode
	# The beats, as the owner told them.
	var sides: Dictionary = {1: [0, 0], 2: [0, 0], 3: [0, 0]}
	var bursts: Dictionary = {1: [], 2: [], 3: []}
	var warned: bool = true
	var one_lane_over: bool = true
	for l: SwarmIntroScreeches.Leaper in sc.leapers:
		var count: Array = sides[l.beat]
		count[0 if l.side < 0 else 1] += 1
		var times: Array = bursts[l.beat]
		times.append(l.burst)
		warned = warned and sc.lair_shake[l.lair] <= l.burst - 0.3 and l.start >= l.burst
	for i: int in sc.lair_points.size():
		one_lane_over = one_lane_over and is_equal_approx(absf(sc.lair_points[i].x), seq.stage.geo.lane_width)
		if sc.lair_burst[i] != INF:
			warned = warned and sc.lair_shake[i] < sc.lair_burst[i]
	var second: Array = sides[2]
	check(sides[1] == [0, 1] and (second == [2, 1] or second == [1, 2]) and sides[3] == [n.third_left, n.third_right]
		and n.third_left == 5 and n.third_right == 6,
		"%s: one screech, then three (two on one side, one on the other), then five on the left and six on the right (%s)" % [tag, sides])
	var on_time: bool = true
	for beat: int in [1, 2, 3]:
		var at: float = [0.0, n.first_burst, n.second_burst, n.third_burst][beat]
		for b: float in bursts[beat]:
			on_time = on_time and b >= at - 0.001 and b < at + 0.2
	check(on_time and is_equal_approx(n.first_burst, 2.0) and is_equal_approx(n.second_burst, 3.0) and is_equal_approx(n.third_burst, 4.0),
		"%s: at 2, 3 and 4 seconds (%s)" % [tag, bursts])
	check(warned, "%s: every manhole rattles before it bursts (the screech's warning, GDD §9.5)" % tag)
	check(one_lane_over, "%s: the manholes line both sides of the runner, one lane over" % tag)
	var geo: TrackGeometry = seq.stage.geo
	var cam_low: float = INF
	var cam_high: float = -INF
	var off_street: float = 0.0
	var cuts: Array[float] = []
	var last_fwd := Vector3.ZERO
	var last_rel := Vector3.INF
	var touched: String = ""
	var in_lane: String = ""
	var out_of_hole: Array[float] = []
	out_of_hole.resize(sc.leapers.size())
	out_of_hole.fill(-1.0)
	var counts: Dictionary = {}
	var rain_seen: Dictionary = {}
	var rain_in_view: int = 0
	var rain_high: float = 0.0
	var gap_at: Dictionary = {}
	var closing: bool = true
	var last_gap: float = INF
	var heart_early: bool = false
	var heart_cut: bool = false
	var glint_peak: float = 0.0
	var glint_lit: int = 0
	var glint_early: bool = false
	var steps: int = 0
	var worst_step: float = 0.0
	var max_calls: int = 0
	var street_ahead: float = INF
	while not seq.done and steps < 2000:
		var s0: int = Time.get_ticks_usec()
		seq.advance(STEP)
		if seq.time > 0.1:
			worst_step = maxf(worst_step, (Time.get_ticks_usec() - s0) / 1000.0)
		steps += 1
		max_calls = maxi(max_calls, seq.props_draw_calls())
		var t: float = seq.time
		if t < n.swing_from and not seq.done:
			street_ahead = minf(street_ahead, seq.stage.track._next_chunk * TrackBuilder.CHUNK_LENGTH
				- seq.stage.to_track(seq.camera.global_position).z)
		if seq.done:
			break
		var cam: Vector3 = seq.camera.global_position
		cam_low = minf(cam_low, cam.y)
		cam_high = maxf(cam_high, cam.y)
		off_street = maxf(off_street, absf(cam.x) - (geo.wall_x() - WALL_CLEARANCE))
		# A cut: the view turns or jumps at once (the camera rides with the runner, so it's measured from them).
		var fwd: Vector3 = -seq.camera.global_transform.basis.z
		var rel: Vector3 = cam - runner.global_position
		if last_fwd != Vector3.ZERO and (fwd.dot(last_fwd) < 0.5 or rel.distance_to(last_rel) > 1.5):
			cuts.append(t)
		last_fwd = fwd
		last_rel = rel
		var rp: Vector3 = runner.track_position
		var tall: float = RUNNER_SLIDING if seq.sliding(t) else RUNNER_TALL
		for li: int in sc.leapers.size():
			var l: SwarmIntroScreeches.Leaper = sc.leapers[li]
			if t < l.start:
				continue
			if out_of_hole[li] < 0.0:
				out_of_hole[li] = t
			var p: Vector3 = l.position
			if touched == "" and absf(p.x - rp.x) < RUNNER_HALF.x + SCREECH_HALF.x and absf(p.z - rp.z) < RUNNER_HALF.y + SCREECH_HALF.y \
					and p.y < rp.y + tall and p.y + SCREECH_TALL > rp.y:
				touched = "beat %d's screech at %.2f s (%s, runner %s)" % [l.beat, t, p, rp]
		for ci: int in sc.crowd_kind.size():
			if sc.crowd_shown[ci] == 0:
				continue
			var p: Vector3 = sc.crowd_position[ci]
			if in_lane == "" and absf(p.z - rp.z) < 1.5 and absf(p.x - rp.x) < 0.75:
				in_lane = "%.2f s: %s (runner %s)" % [t, p, rp]
			if sc.crowd_kind[ci] == SwarmIntroScreeches.Kind.RAIN:
				rain_high = maxf(rain_high, p.y)
				if not rain_seen.has(ci):
					rain_seen[ci] = true
					if seq.camera.is_position_in_frustum(seq.stage.point(p)):
						rain_in_view += 1
		for moment: float in [4.9, 6.0, 7.5, 9.0]:
			if not counts.has(moment) and t >= moment:
				counts[moment] = sc.crowd_shown_count()
		if t >= n.wall_from and t < n.cut_at:
			var gap: float = seq.wall_gap(t)
			closing = closing and gap <= last_gap + 0.0001 and sw.wall.visible
			last_gap = gap
		heart_early = heart_early or (sw.heart.visible and t < n.cut_at)
		heart_cut = heart_cut or (sw.heart.visible and t >= n.cut_at)
		glint_early = glint_early or (sw.glint_strength > 0.0 and t < n.cut_at)
		glint_peak = maxf(glint_peak, sw.glint_strength)
		glint_lit += 1 if sw.glint_strength > 0.05 else 0
		for moment: float in [n.wall_from - 0.1, n.cut_at - 0.05]:
			if not gap_at.has(moment) and t >= moment:
				gap_at[moment] = {"gap": seq.wall_gap(t), "shown": sw.wall.visible, "rise": seq.wall_rise(t)}
	check(seq.done and not seq.skipped, "%s: it plays to its end" % tag)
	check(cam_low >= GROUND_LOW and cam_high <= GROUND_HIGH and off_street <= 0.0,
		"%s: the camera stays at ground level, in the street (%.2f-%.2f m up, out by %.2f m)" % [tag, cam_low, cam_high, off_street])
	check(cuts.size() == 1 and absf(cuts[0] - n.cut_at) < STEP * 1.5, "%s: it cuts once, at %.1f s, into the swarm (%s)" % [tag, n.cut_at, cuts])
	check(touched == "", "%s: the runner never touches a screech: they jump, slide and weave (%s)" % [tag, touched])
	check(in_lane == "", "%s: the pour and the rain run beside the runner, never in their lane (%s)" % [tag, in_lane])
	check(int(counts.get(4.9, 0)) == 0 and int(counts.get(6.0, 0)) > 5 and int(counts.get(7.5, 0)) > int(counts.get(6.0, 0))
		and int(counts.get(9.0, 0)) > int(counts.get(6.0, 0)) * 3 / 2,
		"%s: from 5 s more and more screeches pour out and drop in beside the runner (%s)" % [tag, counts])
	check(rain_seen.size() > 20 and rain_high > 6.0 and rain_in_view <= rain_seen.size() / 10,
		"%s: they drop from above the camera's view (%d of %d start in it, from %.1f m)" % [tag, rain_in_view, rain_seen.size(), rain_high])
	var before: Dictionary = gap_at.get(n.wall_from - 0.1, {})
	var at_cut: Dictionary = gap_at.get(n.cut_at - 0.05, {})
	check(not bool(before.get("shown", true)) and bool(at_cut.get("shown", false)) and float(at_cut.get("rise", 0.0)) > 0.99
		and closing and absf(float(at_cut.get("gap", 0.0)) - n.gap_cut) < 0.5,
		"%s: the wall rises behind the runner and closes in, to %.1f m at the cut (%s)" % [tag, n.gap_cut, at_cut])
	check(not heart_early and heart_cut, "%s: the swarm's dark heart is the cut's alone" % tag)
	check(not glint_early and glint_peak > 0.9 and glint_lit * STEP < 0.6,
		"%s: the Host's glint, once, quickly, in the cut (peak %.2f for %.2f s)" % [tag, glint_peak, glint_lit * STEP])
	var track: StringName = s.zone.boss.music
	check(seq.log_lines.has("music %s" % track) and seq.log_lines.has("cue cut") and seq.log_lines.has("cue glint")
		and seq.log_lines[seq.log_lines.size() - 1] == "effect fade_out",
		"%s: the fight's music (%s), the cut, the glint, and it ends on black (%s)" % [tag, track, seq.log_lines])
	check(setup_msec < SETUP_BUDGET_MSEC and worst_step < STEP_BUDGET_MSEC,
		"%s: cheap enough: %.1f ms to set up, at most %.2f ms a step" % [tag, setup_msec, worst_step])
	check(max_calls <= PROP_DRAW_CALLS, "%s: its props add at most %d draw calls (%d)" % [tag, PROP_DRAW_CALLS, max_calls])
	check(street_ahead >= STREET_AHEAD, "%s: looking down the street, it's built at least %.0f m ahead (%.0f m)" % [
		tag, STREET_AHEAD, street_ahead])
	print("  swarm intro, %s: setup %.1f ms, worst step %.2f ms, props %d draw calls, %d crowd screeches" % [
		tag, setup_msec, worst_step, max_calls, sc.crowd_kind.size()])
	await _free(seq)


## With Reduced flashing the glint is a slow, faint glow.
func _test_glint_reduced() -> void:
	var was: bool = Settings.flashing_reduced
	Settings.flashing_reduced = true
	var seq: SewerSwarmIntro = _start()
	if seq == null:
		Settings.flashing_reduced = was
		return
	var peak: float = 0.0
	var lit: int = 0
	while not seq.done:
		seq.advance(STEP)
		peak = maxf(peak, seq.swarm.glint_strength)
		lit += 1 if seq.swarm.glint_strength > 0.02 else 0
	Settings.flashing_reduced = was
	check(peak > 0.1 and peak <= SwarmIntroSwarm.SOFT_PEAK + 0.01 and lit * STEP >= CineOverlay.SOFT_FLASH_MIN_TIME * 0.6,
		"with Reduced flashing the Host's glint is a slow, faint glow (peak %.2f for %.2f s)" % [peak, lit * STEP])
	await _free(seq)


## On a low-end device it draws fewer: the data's low-end crowd sizes.
func _test_low_end() -> void:
	var s: CampaignStep = _step()
	var seq := (load(s.cinematic.scene) as PackedScene).instantiate() as SewerSwarmIntro
	seq.low_end = true
	tree.root.add_child(seq)
	seq.play(s.cinematic, s)
	seq.set_process(false)
	var n: SewerSwarmIntroTuning = seq.n
	var rain: int = 0
	var pour: int = 0
	for k: int in seq.screeches.crowd_kind:
		rain += 1 if k == SwarmIntroScreeches.Kind.RAIN else 0
		pour += 1 if k == SwarmIntroScreeches.Kind.POUR else 0
	var full: SewerSwarmIntro = _start()
	var full_pour: int = full.screeches.crowd_kind.size() - n.rain_count
	check(seq.swarm.wave.count == n.wave_creatures_low_end and seq.swarm.mass.count == n.mass_creatures_low_end
		and seq.swarm.mound.multimesh.instance_count == n.mound_creatures_low_end and rain == n.rain_count_low_end
		and pour < full_pour, "a low-end device draws the low-end crowds (wave %d, mass %d, mound %d, rain %d, pour %d of %d)" % [
		seq.swarm.wave.count, seq.swarm.mass.count, seq.swarm.mound.multimesh.instance_count, rain, pour, full_pour])
	await _free(full)
	await _free(seq)


# --- Skipping, saves and the App --------------------------------------------------------------------

func _test_skip() -> void:
	for at: float in [1.0, 5.5, 10.0]:
		var seq: SewerSwarmIntro = _start()
		if seq == null:
			return
		var ends: Array[int] = [0]
		seq.finished.connect(func() -> void: ends[0] += 1)
		while not seq.done and seq.time < at - 0.0001:
			seq.advance(STEP)
		seq.skip()
		check(ends[0] == 1 and seq.done and seq.skipped and not seq.stage.visible and not seq.overlay.visible
			and not seq.screeches.is_visible_in_tree() and not seq.swarm.is_visible_in_tree(),
			"skip() at %.1f s ends it at once, and nothing of it shows (the swarm too)" % at)
		seq.skip()
		check(ends[0] == 1, "finished fires once, at %.1f s" % at)
		await _free(seq)


## A save from before the slot was added (it had beaten Gangland and gone on) keeps what it unlocked: the Sewer Swarm
## stays open and Continue goes on from where it was, not back to the intro; a save that hasn't passed it yet
## still meets it before the fight.
func _test_old_save() -> void:
	var saved: Profile = App.profile
	var old := Profile.new()
	SampleProfiles.complete_until(old, App.campaign, "marketplace/2")
	old.records.erase(Profile.record_key("gangland/boss_intro", 0))
	App.profile = old
	var next: CampaignStep = App.next_unfinished_step()
	check(App.step_unlocked(App.campaign.step("gangland/boss")) and next != null and next.id == "marketplace/2",
		"a save from before the slot keeps the Sewer Swarm open and goes on from Marketplace 2 (%s)" % [next.id if next != null else "-"])
	var current := Profile.new()
	SampleProfiles.complete_until(current, App.campaign, "gangland/boss_intro")
	App.profile = current
	next = App.next_unfinished_step()
	check(not App.step_unlocked(App.campaign.step("gangland/boss")) and next != null and next.id == "gangland/boss_intro",
		"a save just past Gangland 3 meets the intro before the fight (%s)" % [next.id if next != null else "-"])
	App.profile = saved


func _test_app_flow() -> void:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	var saved: Profile = App.profile
	App.profile = SampleProfiles.fresh()
	App.play_step(_step())
	await physics_frames(10)
	var c := App.playing_cinematic() as SewerSwarmIntro
	check(c != null and c.step.id == "gangland/boss_intro" and App.screen == null and App.run == null,
		"Gangland's boss-intro slot plays the swarm rising, in the world, with no screen over it")
	var press := InputEventAction.new()
	press.action = &"pause"
	press.pressed = true
	tree.root.push_input(press)
	await physics_frames(3)
	check(App.run != null and App.run.encounter is SewerSwarm and App.run.context.step.id == "gangland/boss"
		and App.profile.is_completed("gangland/boss_intro") and App.playing_cinematic() == null and not tree.paused,
		"the pause action skips it: the Sewer Swarm starts at once, and nothing is paused")
	App.show_title()
	await tree.process_frame
	App.profile = saved
	main.queue_free()
	App.main = null
	await tree.process_frame
