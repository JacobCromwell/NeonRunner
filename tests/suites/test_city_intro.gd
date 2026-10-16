extends TestSuite
## The Neon City's intro (CityIntro, task F2f; the owner's beats, GDD §6 Cinematics, "Zone 1 intro"): its slot plays it (not
## the placeholder flyover); at 3, 5 and 6 lanes it plays its beats in order on a real street (the City's stretch with no
## floor, its road lifted to y = 0): a flyby from above down into the street in one continuous camera move, cyborgs
## trudging toward the camera under the Floating Head, its face showing, its searchlight cold white (never red) sweeping over
## them, along the wall past a window and, just after it, the glass bursting; the runner leaping out onto the first cyborg's head
## (the stomp: it is squashed as a stomp kills), hopping over two more and running down the street, the light whipping back to
## catch them; the Head startled (wide eyes, an "O"), angry, yelling (the jaw open), every cyborg's screen face flickering at
## once and turning angry (Reduced flashing: one change), the cyborgs turning and chasing; then the title card over the chase and
## a fade to black. It is about 20 s; the street's traffic and people, the camera's place, what each costs, the palette (no
## hazard hue on anything safe), skipping, stepping the clock coarsely, and the App's flow (it plays first in the campaign, and the
## web demo plays it).

const Kit = preload("res://scripts/enemies/cyborg_kit.gd")
const LANES: Array[int] = [3, 5, 6]
const SFX_PATH: String = "res://data/audio/sfx_library.tres"
const STEP: float = 1.0 / 30.0
## Costs, headless (generous, so a busy machine doesn't fail them: the measured numbers are printed).
const SETUP_BUDGET_MSEC: float = 2500.0
const STEP_BUDGET_MSEC: float = 30.0
## What its props add to a frame at most (draw calls: every surface of every visible mesh under the set), the web demo's budget.
const PROP_DRAW_CALLS: int = 110

var sfx: SfxLibrary
var _music_before: StringName = &""


func run() -> void:
	sfx = load(SFX_PATH) as SfxLibrary
	var music: MusicDirector = MusicDirector.instance()
	_music_before = music.current() if music != null else &""
	_test_slot()
	_test_face_shader_default()
	var lanes_pc: int = App.rules.lanes_pc
	for lanes: int in LANES:
		App.rules.lanes_pc = lanes
		await _test_beats(lanes)
	App.rules.lanes_pc = lanes_pc
	await _test_surge(false)
	await _test_surge(true)
	await _test_stomp_squash()
	await _test_props()
	await _test_coarse_steps()
	await _test_skip()
	await _test_app_flow()
	if music != null:
		if _music_before == &"":
			music.stop(0.0)
		else:
			music.play(_music_before, 0.0)


func _step() -> CampaignStep:
	return App.campaign.step("city/intro")


## A CityIntro for the City's intro slot, in the tree, its clock stepped by the test.
func _start() -> CityIntro:
	var s: CampaignStep = _step()
	var seq := (load(s.cinematic.scene) as PackedScene).instantiate() as CityIntro
	tree.root.add_child(seq)
	seq.play(s.cinematic, s)
	seq.set_process(false)
	return seq


func _free(node: Node) -> void:
	if node != null and is_instance_valid(node):
		node.queue_free()
	await tree.process_frame


func _run_to(seq: CityIntro, t: float, step: float = STEP) -> void:
	while not seq.done and seq.time < t - 0.0001:
		seq.advance(minf(step, t - seq.time))


func _test_slot() -> void:
	var s: CampaignStep = _step()
	check(s != null and s.cinematic.is_built() and s.cinematic.scene == "res://scenes/cinematics/city_intro.tscn",
		"the City's intro slot is built: it plays the City intro, no longer the arrival flyover")
	var seq := (load(s.cinematic.scene) as PackedScene).instantiate()
	check(seq is CityIntro and (seq as CityIntro).numbers != null, "its scene is a CityIntro with its numbers")
	seq.free()
	var boss: CampaignStep = App.campaign.step("city/boss_intro")
	check(boss.cinematic.scene == "res://scenes/cinematics/arrival_flyover.tscn",
		"the City's boss intro keeps the arrival flyover (the owner's beats are for the zone's intro)")
	var n := load("res://data/cinematics/city_intro_tuning.tres") as CityIntroTuning
	check(n != null and n.duration >= 19.0 and n.duration <= 21.0, "about 20 s long (%.1f s)" % [n.duration if n != null else 0.0])
	# The beats the owner gave, in order: street, escape, the window's burst, the stomp, the Head's startle, anger and yell,
	# the feed's surge, the cut back, the title card, the end.
	check(n.street_at < n.escape_at and n.escape_at < n.burst_at and n.burst_at < n.stomp_at and n.stomp_at < n.head_at
		and n.head_at == n.startle_at and n.startle_at < n.angry_at and n.angry_at < n.yell_at and n.yell_at < n.flicker_at
		and n.flicker_at + n.flicker_seconds < n.card_at and n.reverse_at < n.card_at and n.card_at + n.card_seconds <= n.duration + 0.01
		and n.head_times[0] == n.head_at and n.head_times[n.head_times.size() - 1] < n.reverse_at,
		"its beats are in the owner's order")
	check(absf((n.street_at) - 5.0) < 1.0 and absf((n.head_at - n.escape_at) - 4.0) < 0.5 and absf(n.card_seconds - 2.0) < 0.5,
		"its parts are about as long as the owner's staging (flyby 5 s, street 4 s, escape 4 s, the Head 5 s, card 2 s)")


## The face shader's new look (the startled "O") is off by default: the fight's face is as it was.
func _test_face_shader_default() -> void:
	var shader := load("res://scripts/bosses/floating_head/floating_head_face.gdshader") as Shader
	check(shader.code.contains("uniform float surprise = 0.0;"), "the face shader's surprise is 0 by default (the fight's face)")
	var body := FloatingHeadBody.new()
	check(is_zero_approx(body.surprise), "the fight's face body starts unsurprised")
	body.free()


# --- The beats -----------------------------------------------------------------------------------

func _test_beats(lanes: int) -> void:
	var tag: String = "%d lanes" % lanes
	var t0: int = Time.get_ticks_usec()
	var seq: CityIntro = _start()
	var setup_msec: float = (Time.get_ticks_usec() - t0) / 1000.0
	var n: CityIntroTuning = seq.n
	var zone: ZoneDef = _step().zone
	check(seq.stage.skin == zone.skin and seq.stage.geo.lane_count == n.street_lanes,
		"%s: it plays in the City's look from the zone's data, on its own street (%d lanes, whatever the device's)" % [tag, n.street_lanes])
	check(seq.playing.problems(sfx).is_empty(), "%s: a sound timeline: %s" % [tag, seq.playing.problems(sfx)])
	check(seq.duration() >= 19.0 and seq.duration() <= 21.0, "%s: about 20 s (%.1f s)" % [tag, seq.duration()])
	# The street: no truck roofs, every lane a hole over the road, which is y = 0 (the stage lifted to it).
	var no_roofs: bool = true
	for lane: int in seq.stage.geo.lane_count:
		for z: float in [0.0, 25.0, 60.0, 120.0]:
			no_roofs = no_roofs and seq.stage.gap_at(lane, z, 0.0)
	check(no_roofs, "%s: no truck roofs: every lane of the stage is a gap" % tag)
	check(is_equal_approx(seq.stage.position.y, seq.lift) and seq.lift > 5.0
		and is_zero_approx(seq.street.get_global_transform().origin.y),
		"%s: the road far below the roofs is the street, at y = 0 (the stage lifted %.1f m)" % [tag, seq.lift])
	var runner := seq.actors[&"runner"] as CineActorNode
	var cyborgs: Array[CineActorNode] = []
	for i: int in n.march_places.size():
		cyborgs.append(seq.actors[StringName("cyborg_%d" % i)] as CineActorNode)
	check(cyborgs.size() == 7 and runner != null and runner.avatar != null, "%s: the runner and seven cyborgs are in it" % tag)
	var look: StringName = &""
	check(cyborgs[0].body.look == CyborgSuit.look_for(zone.skin.enemy_variant), "%s: the cyborgs wear the City's look" % tag)
	var top: float = seq.head_top()
	var geo: TrackGeometry = seq.stage.geo
	var cam: Camera3D = seq.camera
	var problems: PackedStringArray = []
	var jumps: Array[float] = []
	var last_cam := Vector3.INF
	var worst_step: float = 0.0
	var sum_step: float = 0.0
	var steps: int = 0
	var max_calls: int = 0
	var seen: Dictionary = {}
	var stomp_gap: float = INF
	var inside: PackedStringArray = []
	var lamp_red: bool = false
	var surprise_peak: float = 0.0
	var jaw_peak: float = 0.0
	var anger_peak: float = 0.0
	var light_ok: bool = true
	var spot_at_window: float = INF
	var spot_after: float = -INF
	var spot_on_runner: float = INF
	var hop_clear: Array[float] = [INF, INF]
	var hop_gap: Array[float] = [INF, INF]
	var hops: Array[float] = [n.stomp_at + n.stomp_hold + n.hop_seconds * 0.5,
		n.stomp_at + n.stomp_hold + n.hop_seconds + n.stride_seconds + n.hop_seconds * 0.5]
	var hop_over: Array[int] = [1, 4]
	while not seq.done and steps < 1000:
		var s0: int = Time.get_ticks_usec()
		seq.advance(STEP)
		var msec: float = (Time.get_ticks_usec() - s0) / 1000.0
		steps += 1
		if seq.time > 0.1:
			worst_step = maxf(worst_step, msec)
			sum_step += msec
		var t: float = seq.time
		var p: Vector3 = cam.global_position
		if last_cam != Vector3.INF:
			var moved: float = p.distance_to(last_cam)
			if moved > 4.0:
				jumps.append(snappedf(t, 0.01))
			elif t < n.head_at - 0.01 and moved > 1.5:
				problems.append("%.2f s: the camera moved %.2f m in a step" % [t, moved])
		last_cam = p
		# In the street: inside the walls, above the road, clear of the traffic lanes when low.
		if absf(p.x) > geo.wall_x() - 0.3:
			problems.append("%.2f s: the camera is at the wall (x %.2f)" % [t, p.x])
		if p.y < 1.0:
			problems.append("%.2f s: the camera is under the street's eye level (%.2f m)" % [t, p.y])
		if p.y < 3.6 and absf(p.x) > seq.street.road_half * 0.5 + 0.3 and t < n.head_at:
			problems.append("%.2f s: the camera is low and in a traffic lane (x %.2f)" % [t, p.x])
		max_calls = maxi(max_calls, _draw_calls(seq.set_root))
		# The Head's face and light.
		var face: ShaderMaterial = seq.head.face
		surprise_peak = maxf(surprise_peak, float(face.get_shader_parameter(&"surprise")))
		anger_peak = maxf(anger_peak, float(face.get_shader_parameter(&"anger")))
		jaw_peak = maxf(jaw_peak, seq.head.jaw_open)
		var beam_color: Color = seq.head._beam_material.get_shader_parameter(&"light_color")
		var spot_color: Color = seq.head._spot_material.get_shader_parameter(&"light_color")
		light_ok = light_ok and _cold(beam_color) and _cold(spot_color)
		# The light: along the wall past the window just before the glass bursts, then on the runner.
		var light: Dictionary = seq.light_at(t)
		var lp: Vector3 = light["point"]
		if absf(t - (n.burst_at - 0.3)) < STEP * 0.5:
			spot_at_window = Vector2(lp.z - n.window_z, lp.y - (n.window_sill + n.window_height * 0.5)).length()
			seen["wall_normal"] = (light["normal"] as Vector3).x * -float(n.window_side)
		if absf(t - n.burst_at) < STEP * 0.5:
			spot_after = (lp.z - n.window_z) * 1.0
		if absf(t - (seq.catch_at + 0.3)) < STEP * 0.5:
			var rp: Vector3 = seq._street_of(runner.global_position)
			spot_on_runner = Vector2(lp.x - rp.x, lp.z - rp.z).length()
		# The stomp, the hops, and never inside a cyborg.
		if absf(t - n.stomp_at) < STEP * 0.5:
			var land: Vector3 = seq.cyborg_at(0, n.stomp_at)
			var rp2: Vector3 = runner.track_position
			var street_rp: Vector3 = Vector3(rp2.x + seq.stage.origin_x, rp2.y, rp2.z)
			stomp_gap = Vector2(street_rp.x - land.x, street_rp.z - land.z).length()
			seen["stomp_height"] = street_rp.y - top
		for k: int in 2:
			if absf(t - hops[k]) < STEP * 0.5:
				var rp3: Vector3 = runner.track_position
				var c: Vector3 = seq.cyborg_at(hop_over[k], t)
				hop_gap[k] = Vector2(rp3.x + seq.stage.origin_x - c.x, rp3.z - c.z).length()
				hop_clear[k] = rp3.y - top
		if t > n.burst_at and t < seq.run_from_at:
			for i: int in cyborgs.size():
				if i == 0 and t > n.stomp_at:
					continue
				var c2: Vector3 = seq.cyborg_at(i, t)
				var rp4: Vector3 = runner.track_position
				var d: float = Vector2(rp4.x + seq.stage.origin_x - c2.x, rp4.z - c2.z).length()
				if d < 0.5 and rp4.y < top - 0.15 and not (i == 0 and t < n.stomp_at + 0.02):
					inside.append("%.2f s: inside cyborg %d" % [t, i])
		for moment: float in [n.burst_at - 0.05, n.burst_at + 0.2, n.stomp_at + 0.3, n.stomp_at + 1.0, n.startle_at + 0.4,
				n.angry_at + 0.5, n.yell_at + 0.5, n.card_at - 0.3]:
			if not seen.has(moment) and t >= moment:
				seen[moment] = {"window_intact": seq.window.intact.visible, "opening": seq.window.broken.visible,
					"shards": seq.window.shards.visible, "c0_face": cyborgs[0].body.face, "c0_screen": cyborgs[0].body.screen_power,
					"surprise": float(face.get_shader_parameter(&"surprise")), "anger": float(face.get_shader_parameter(&"anger")),
					"jaw": seq.head.jaw_open, "mouth": seq.head.mouth_glow.visible, "glitch": float(face.get_shader_parameter(&"glitch")),
					"runner_visible": runner.visible, "runner_x": runner.position.x}
	check(seq.done and not seq.skipped, "%s: it plays to its end" % tag)
	var s_before: Dictionary = seen[n.burst_at - 0.05]
	var s_after: Dictionary = seen[n.burst_at + 0.2]
	check(bool(s_before["window_intact"]) and not bool(s_before["opening"]) and absf(float(s_before["runner_x"])) > seq.street.wall_half,
		"%s: before the burst the window is intact, a lit pane, and the runner is still behind the wall" % tag)
	check(not bool(s_after["window_intact"]) and bool(s_after["opening"]) and bool(s_after["shards"]) and bool(s_after["runner_visible"]),
		"%s: it bursts as planned: the pane gone, an opening, glass flying, the runner out of it" % tag)
	check(spot_at_window < 3.0 and float(seen["wall_normal"]) > 0.9,
		"%s: the light is on the wall at the window just before it bursts (%.1f m off, facing the street)" % [tag, spot_at_window])
	check(spot_after > 1.5, "%s: and has swept past it by the time the glass bursts (%.1f m past)" % [tag, spot_after])
	check(stomp_gap < 0.3 and absf(float(seen["stomp_height"])) < 0.15,
		"%s: the runner lands on the first cyborg's head (%.2f m off, %.2f m from its top)" % [tag, stomp_gap, float(seen["stomp_height"])])
	var squashed: Dictionary = seen[n.stomp_at + 0.3]
	check(int(squashed["c0_face"]) == Kit.Face.DEAD or float(squashed["c0_screen"]) < 1.0,
		"%s: that cyborg is killed the way a stomp kills in play (its screen shows ERR, then goes dark)" % tag)
	check(hop_gap[0] < 0.6 and hop_clear[0] >= n.hop_clearance * 0.8 and hop_gap[1] < 0.6 and hop_clear[1] >= n.hop_clearance * 0.8,
		"%s: they hop over the second cyborg and the fifth (%.2f / %.2f m across, %.2f / %.2f m clear)" % [
		tag, hop_gap[0], hop_gap[1], hop_clear[0], hop_clear[1]])
	check(inside.is_empty(), "%s: the runner is never inside a cyborg after the leap: %s" % [tag, inside.slice(0, 3)])
	check(spot_on_runner < 2.5, "%s: the light whips back and is on the runner (%.1f m) as the Head has them" % [tag, spot_on_runner])
	var startled: Dictionary = seen[n.startle_at + 0.4]
	check(float(startled["surprise"]) > 0.95 and float(startled["anger"]) < 0.05 and float(startled["jaw"]) > n.startle_jaw * 0.9
		and float(startled["jaw"]) < 0.5, "%s: the Head is startled (wide eyes, an O, the jaw just open: %s)" % [tag, startled])
	var angry: Dictionary = seen[n.angry_at + 0.5]
	check(float(angry["surprise"]) < 0.02 and float(angry["anger"]) > 0.95 and float(angry["jaw"]) < 0.1,
		"%s: then angry (the brows down, the jaw shut: %s)" % [tag, angry])
	var yelling: Dictionary = seen[n.yell_at + 0.5]
	check(float(yelling["jaw"]) > 0.95 and bool(yelling["mouth"]) and float(yelling["glitch"]) > 0.2 and float(yelling["anger"]) > 0.95,
		"%s: then it yells (the jaw wide open, the mouth lit, the picture breaking up: %s)" % [tag, yelling])
	check(light_ok, "%s: its light is cold white throughout, never red (red is the bombs')" % tag)
	check(jumps == [snappedf(n.head_at, 0.01), snappedf(n.reverse_at, 0.01), snappedf(n.card_at, 0.01)] or _same_times(jumps,
		[n.head_at, n.reverse_at, n.card_at]), "%s: the camera cuts only three times: to the Head's face, back to the street, to the chase (%s)" % [tag, jumps])
	check(problems.is_empty(), "%s: the camera moves in one continuous move down to the street, stays in it and above the road: %s" % [
		tag, problems.slice(0, 3)])
	check(setup_msec < SETUP_BUDGET_MSEC and worst_step < STEP_BUDGET_MSEC,
		"%s: cheap enough: %.1f ms to set up, at most %.2f ms a step (%.2f ms on average)" % [
		tag, setup_msec, worst_step, sum_step / maxf(steps, 1)])
	check(max_calls <= PROP_DRAW_CALLS, "%s: its props add at most %d draw calls (%d)" % [tag, PROP_DRAW_CALLS, max_calls])
	print("  city intro, %s: setup %.1f ms, step %.2f ms (worst %.2f), props %d draw calls" % [
		tag, setup_msec, sum_step / maxf(steps, 1), worst_step, max_calls])
	var wanted: PackedStringArray = ["music city", "sound window_smash", "sound jump", "sound stomp", "sound enemy_death",
		"sound head_startle", "sound head_yell", "sound feed_surge", "text Neon City", "effect fade_out"]
	var at: int = -1
	var in_order: bool = true
	for w: String in wanted:
		var i: int = seq.log_lines.find(w, at + 1)
		in_order = in_order and i > at
		at = maxi(at, i)
	check(in_order, "%s: its beats come in order (%s)" % [tag, seq.log_lines])
	check(not seq.log_lines.has("effect flash"), "%s: nothing flashes the picture (the glass is shards, not a flash)" % tag)
	var tracks: Array[String] = []
	for line: String in seq.log_lines:
		if line.begins_with("music "):
			tracks.append(line.trim_prefix("music "))
	check(tracks == ["city"], "%s: only the City's own music plays (%s)" % [tag, tracks])
	check(seq.overlay.fade_alpha() > 0.8 and not seq.overlay.visible, "%s: it ends on black, and its overlay has gone" % tag)
	await _free(seq)


func _same_times(a: Array[float], b: Array[float]) -> bool:
	if a.size() != b.size():
		return false
	for i: int in a.size():
		if absf(a[i] - b[i]) > STEP * 1.5:
			return false
	return true


## The light is a cool white (blue at least as strong as red and no saturated hue): never the bombs' red.
func _cold(c: Color) -> bool:
	return c.b >= c.r and c.g >= c.r and c.r > 0.5


## Every surface of every visible mesh under `root` (a MultiMesh's surfaces count once, however many it holds).
func _draw_calls(root: Node) -> int:
	var count: int = 0
	for node: Node in root.find_children("*", "VisualInstance3D", true, false):
		if node is MeshInstance3D and (node as MeshInstance3D).is_visible_in_tree() and (node as MeshInstance3D).mesh != null:
			count += (node as MeshInstance3D).mesh.get_surface_count()
		elif node is MultiMeshInstance3D and (node as MultiMeshInstance3D).is_visible_in_tree():
			var mm: MultiMesh = (node as MultiMeshInstance3D).multimesh
			if mm != null and mm.mesh != null and mm.visible_instance_count != 0:
				count += mm.mesh.get_surface_count()
	return count


# --- The feed's surge ----------------------------------------------------------------------------

## Every cyborg's screen face flickers at once when the yell goes through the feed and turns angry (with Reduced flashing:
## one change, no flicker); then they turn round and chase.
func _test_surge(reduced: bool) -> void:
	var was: bool = Settings.flashing_reduced
	Settings.flashing_reduced = reduced
	var tag: String = "Reduced flashing" if reduced else "normal"
	var seq: CityIntro = _start()
	var n: CityIntroTuning = seq.n
	var live: Array[CineActorNode] = []
	for i: int in range(1, n.march_places.size()):
		live.append(seq.actors[StringName("cyborg_%d" % i)] as CineActorNode)
	_run_to(seq, n.flicker_at - 0.3)
	var before_calm: bool = true
	for c: CineActorNode in live:
		before_calm = before_calm and c.body.face == Kit.Face.NEUTRAL
	var faces: Array = []
	var firsts: Array[float] = []
	for c: CineActorNode in live:
		faces.append([c.body.face])
		firsts.append(-1.0)
	while seq.time < n.flicker_at + n.flicker_seconds + 0.2:
		seq.advance(1.0 / 60.0)
		for i: int in live.size():
			var list: Array = faces[i]
			if live[i].body.face != list[list.size() - 1]:
				list.append(live[i].body.face)
				if firsts[i] < 0.0:
					firsts[i] = seq.time
	var all_angry: bool = true
	var changes_min: int = 99
	var spread: float = 0.0
	for i: int in live.size():
		var list: Array = faces[i]
		all_angry = all_angry and list[list.size() - 1] == Kit.Face.AIMING
		changes_min = mini(changes_min, list.size() - 1)
		spread = maxf(spread, firsts[i] - firsts[0])
	check(before_calm, "%s: before the surge every cyborg's screen is calm" % tag)
	check(all_angry, "%s: every cyborg's screen has turned angry when it is over" % tag)
	check(absf(spread) < 0.1, "%s: and they all change at once (within %.0f ms of each other)" % [tag, spread * 1000.0])
	if reduced:
		check(changes_min == 1, "%s: one change, calm to angry, no flicker (%d)" % [tag, changes_min])
	else:
		check(changes_min >= 3, "%s: the screens flicker through static first (%d changes)" % [tag, changes_min])
	# They turn and give chase.
	var before := seq.actors[&"cyborg_1"] as CineActorNode
	check(absf(wrapf(before.yaw - PI, -PI, PI)) < 0.3, "%s: until then they face the camera" % tag)
	_run_to(seq, n.duration - 0.1)
	var chasing: bool = true
	for c: CineActorNode in live:
		chasing = chasing and absf(wrapf(c.yaw, -PI, PI)) < 0.3 and c.speed > n.chase_speed * 0.85
	check(chasing, "%s: and they have turned round to give chase, at %.1f m/s" % [tag, n.chase_speed])
	Settings.flashing_reduced = was
	await _free(seq)


## The stomped cyborg goes the way a stomp kills in play: squashed flat, its screen dark (its tween runs in real time).
func _test_stomp_squash() -> void:
	var seq: CityIntro = _start()
	_run_to(seq, seq.n.stomp_at + 0.05)
	var c0 := seq.actors[&"cyborg_0"] as CineActorNode
	check(c0.body.face == Kit.Face.DEAD, "the stomped cyborg's screen shows ERR as it is squashed")
	await tree.create_timer(0.8).timeout
	check(c0.body.screen_power < 0.01 and c0.body._root.scale.y < 0.3, "then its screen goes dark and it is flattened (%.2f)" % c0.body._root.scale.y)
	await _free(seq)


# --- Props ---------------------------------------------------------------------------------------

func _test_props() -> void:
	var seq: CityIntro = _start()
	var n: CityIntroTuning = seq.n
	var street: CityIntroStreet = seq.street
	var traffic: CityIntroTraffic = seq.traffic
	var crowd: CityIntroCrowd = seq.crowd
	check(street.lamp_heads.size() > 10 and street.draw_calls <= 3, "the street is dressed with lamps, shops and paint in %d draw calls" % street.draw_calls)
	# Traffic: two lanes of vehicles, never on top of each other, never in the stretch kept clear when the camera looks there.
	check(traffic.vehicles.size() == n.vehicles_per_lane * 2 and traffic.looks.size() == 17, "%d vehicles in %d looks" % [
		traffic.vehicles.size(), traffic.looks.size()])
	var overlap: bool = false
	var in_clear: int = 0
	for t: float in [0.0, 3.3, 7.0, n.traffic_clear.y, 14.0, 19.9]:
		for a: int in traffic.vehicles.size():
			var va: CityIntroTraffic.Vehicle = traffic.vehicles[a]
			var za: float = traffic.distance_of(va, t)
			if t == n.traffic_clear.y and absf(za - n.traffic_clear.x) < n.traffic_clear.z * 0.5 - 1.0:
				in_clear += 1
			for b: int in range(a + 1, traffic.vehicles.size()):
				var vb: CityIntroTraffic.Vehicle = traffic.vehicles[b]
				if va.lane_x != vb.lane_x:
					continue
				var gap: float = absf(za - traffic.distance_of(vb, t))
				gap = minf(gap, traffic.loop_length - gap)
				if gap < (traffic.looks[va.look].length + traffic.looks[vb.look].length) * 0.5:
					overlap = true
	check(not overlap, "no two vehicles in a lane ever overlap")
	check(in_clear == 0, "no vehicle is in the stretch kept clear where the camera looks through it as the glass bursts (%d)" % in_clear)
	var lanes_ok: bool = true
	for v: CityIntroTraffic.Vehicle in traffic.vehicles:
		lanes_ok = lanes_ok and absf(v.lane_x) < street.road_half and absf(v.lane_x) > street.road_half * 0.5
	check(lanes_ok, "the traffic keeps to the road's outer lanes, the middle is the cyborgs'")
	# People: on the sidewalks, always, walking.
	check(crowd.count == n.people_per_side * 2, "%d people on the sidewalks" % crowd.count)
	var on_walk: bool = true
	var moved: bool = false
	for i: int in range(0, crowd.count, 7):
		for t: float in [0.0, 8.0, 19.0]:
			var p: Vector3 = crowd.position_at(i, t)
			on_walk = on_walk and absf(p.x) > street.road_half and absf(p.x) < street.wall_half
			moved = moved or crowd.position_at(i, 8.0).distance_to(crowd.position_at(i, 0.0)) > 5.0
	check(on_walk and moved, "everyone stays on a sidewalk and walks (%d people)" % crowd.count)
	# Safe things look safe: nothing glows in a hazard's hue (orange, yellow, red, pink, green, cyan).
	var palette: Array[Color] = []
	palette.append_array(CityIntroStreet.SHOP_LIGHTS)
	palette.append_array([CityIntroStreet.LAMP_LIGHT, CityIntroTraffic.WINDOW_LIGHT, CityIntroTraffic.SIGN_LIGHT,
		CityIntroWindow.ROOM_LIGHT, seq.stage.skin.get(&"traffic_tail_color"), seq.stage.skin.get(&"thruster_color")])
	palette.append_array(CityIntroTraffic.PAINTS)
	for c: Color in seq.stage.skin.get(&"neon_colors"):
		palette.append(c)
	var hazard: PackedStringArray = []
	for c: Color in palette:
		if _hazard_hue(c):
			hazard.append(c.to_html())
	check(hazard.is_empty(), "no lit or painted colour of the street, its traffic or its window is a hazard's hue: %s" % [hazard])
	await _free(seq)


## A saturated red, orange, yellow, pink, green or cyan: the hazards' colours (GDD §11).
func _hazard_hue(c: Color) -> bool:
	if c.s < 0.6 or c.v < 0.25:
		return false
	var h: float = c.h * 360.0
	return h < 65.0 or h > 295.0 and h < 350.0 or h > 100.0 and h < 200.0 or h >= 350.0


# --- Skipping and stepping -----------------------------------------------------------------------

## Stepping the clock in big jumps shows the same moment as small steps (props and actors follow the clock, not frames).
func _test_coarse_steps() -> void:
	var a: CityIntro = _start()
	_run_to(a, 12.0, STEP)
	var b: CityIntro = _start()
	_run_to(b, 12.0, 0.25)
	var ra := a.actors[&"runner"] as CineActorNode
	var rb := b.actors[&"runner"] as CineActorNode
	check(ra.track_position.distance_to(rb.track_position) < 0.01,
		"the runner is in the same place at 12 s however the clock got there (%s, %s)" % [ra.track_position, rb.track_position])
	check(absf(a.head.anger - b.head.anger) < 0.001 and a.head.jaw_open == b.head.jaw_open
		and a.head.lens_world().distance_to(b.head.lens_world()) < 0.01, "the Head's face and light are the same")
	check(a.traffic.looks[0].multi.get_instance_transform(0).origin.distance_to(b.traffic.looks[0].multi.get_instance_transform(0).origin) < 0.01
		and a.window.shard_position(3, 2.0).distance_to(b.window.shard_position(3, 2.0)) < 0.001,
		"so are the traffic and the glass")
	await _free(a)
	await _free(b)


func _test_skip() -> void:
	for at: float in [0.0, 4.0, 10.0, 17.0]:
		var seq: CityIntro = _start()
		var ends: Array[int] = [0]
		seq.finished.connect(func() -> void: ends[0] += 1)
		_run_to(seq, at)
		seq.skip()
		check(ends[0] == 1 and seq.done and seq.skipped and not seq.stage.visible and not seq.overlay.visible
			and not seq.set_root.is_visible_in_tree(), "skip() at %.0f s ends it at once, and nothing of it shows (props too)" % at)
		seq.skip()
		check(ends[0] == 1, "finished fires once, at %.0f s" % at)
		await _free(seq)


# --- Through the App -----------------------------------------------------------------------------

func _test_app_flow() -> void:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	var saved: Profile = App.profile
	App.profile = SampleProfiles.fresh()
	App.continue_campaign()
	await tree.process_frame
	var c := App.playing_cinematic() as CityIntro
	check(c != null and c.step.id == "city/intro" and App.screen == null and App.run == null,
		"a new player's campaign opens on the City intro, in the world, with no screen over it")
	App.skip_cinematic()
	await physics_frames(3)
	check(App.profile.is_completed("city/intro") and App.profile.has_seen("cinematic/city/intro") and App.run != null
		and App.run.context.step.id == "city/1", "skipped, it counts as done and seen, and City 1 follows")
	App.show_level_select()
	await tree.process_frame
	BuildFlavor.set_override(BuildFlavor.Kind.WEB_DEMO)
	App.play_step(_step())
	await tree.process_frame
	check(App.playing_cinematic() is CityIntro, "the web demo plays it too")
	App.skip_cinematic()
	await physics_frames(3)
	check(App.run != null and App.run.context.step.id == "city/1", "then its first level")
	BuildFlavor.set_override(-1)
	App.show_title()
	await tree.process_frame
	App.profile = saved
	main.queue_free()
	App.main = null
	await tree.process_frame
