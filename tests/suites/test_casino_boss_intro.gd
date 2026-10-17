extends TestSuite
## The Casino's boss intro (CasinoBossIntro; the owner's beats, October 17, 2026; GDD §10, The House, "Intro cinematic"):
## its slot (before The House); at 3, 5 and 6 lanes: the fight's look and lanes, the street hidden and the hall built
## round it (its tables, three holograms, the bar, the golden door, the wall, The House behind it, the fight's own
## machine and a hole cut round it); the roulette ball dropping and settling before the players cheer, the players
## cheering (their hands up); the runner leaning on the bar, the screech on the counter beside them; the Chairman with a
## woman either side of him; the runner's way through the crowd and the Chairman's to the door clear of the tables,
## the holograms and the crowd; each guard lunging through where the runner was as the runner dives clear, in the air;
## the door open as the Chairman passes through it and shut behind him and the women, who are gone; the wall flush
## until it trembles, every block flying out once it bursts and lying low on the floor by the end, The House's lights on;
## the camera inside the hall; its sounds; what it costs. Then skipping, and the App's flow (skipping it starts the
## fight).

const LANES: Array[int] = [3, 5, 6]
const SFX_PATH: String = "res://data/audio/sfx_library.tres"
const SCENE: String = "res://scenes/cinematics/casino_boss_intro.tscn"
const STEP: float = 1.0 / 30.0
## Its own sounds (tools/asset_gen/sfx_bank_casino_boss_intro.gd).
const SOUNDS: Array[String] = ["roulette_spin", "roulette_drop", "crowd_cheer", "casino_bustle", "golden_door", "wall_rumble",
	"wall_collapse", "guard_halt"]
const MAX_SOUND_SECONDS: float = 2.5
## The camera keeps this far inside the hall's walls, floor and ceiling (metres).
const CAMERA_MARGIN: float = 0.3
## Walkers keep this far from a table's edge, a hologram's pedestal and anyone standing about (metres).
const TABLE_CLEARANCE: float = 0.25
const CROWD_CLEARANCE: float = 0.45
## A guard's lunge ends at least this far from the runner (metres): they dived clear.
const DODGE_CLEAR: float = 0.8
## A cheering hand is this far above the head's joint at least (metres).
const CHEER_HAND: float = 0.0
## Costs, headless (generous: they catch a gross regression; the measured numbers are printed), and what its props may
## add to a frame.
const SETUP_BUDGET_MSEC: float = 4000.0
const STEP_BUDGET_MSEC: float = 40.0
const PROP_DRAW_CALLS: int = 240

var sfx: SfxLibrary
var _music_before: StringName = &""


func run() -> void:
	sfx = load(SFX_PATH) as SfxLibrary
	var music: MusicDirector = MusicDirector.instance()
	_music_before = music.current() if music != null else &""
	_test_slot()
	_test_sounds()
	_test_looks()
	var lanes_pc: int = App.rules.lanes_pc
	for lanes: int in LANES:
		App.rules.lanes_pc = lanes
		await _check_intro(lanes)
	App.rules.lanes_pc = lanes_pc
	await _test_skip()
	await _test_app_flow()
	ZoneSkin.set_scenery_tint(Color.WHITE)
	if music != null:
		if _music_before == &"":
			music.stop(0.0)
		else:
			music.play(_music_before, 0.0)


func _step() -> CampaignStep:
	return App.campaign.step("casino/boss_intro")


func _start() -> CasinoBossIntro:
	var s: CampaignStep = _step()
	if s == null or s.cinematic == null or not s.cinematic.is_built():
		return null
	var seq := (load(s.cinematic.scene) as PackedScene).instantiate() as CasinoBossIntro
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
	check(s != null and s.cinematic.is_built() and s.cinematic.scene == SCENE and s.zone.boss_intro == s.cinematic,
		"the Casino's boss-intro slot is built: the casino, the Chairman and The House bursting in")
	var next: CampaignStep = App.campaign.next_step(s) if s != null else null
	check(next != null and next.id == "casino/boss", "The House's fight follows it")
	var seq := (load(SCENE) as PackedScene).instantiate()
	check(seq is CasinoBossIntro and (seq as CasinoBossIntro).numbers != null, "its scene is a CasinoBossIntro with its numbers")
	seq.free()


func _test_sounds() -> void:
	for v: String in SOUNDS:
		var stream := sfx.stream(StringName(v)) as AudioStreamWAV
		check(sfx.has_file(StringName(v)) and stream != null, "its sound %s is in the library" % v)
		if stream != null:
			check(stream.get_length() > 0.3 and stream.get_length() < MAX_SOUND_SECONDS,
				"%s is %.2f s (under %.1f s)" % [v, stream.get_length(), MAX_SOUND_SECONDS])


## The people's looks (CasinoPeople, from the owner's reference): built, each its own; nothing on anyone glows but the
## Chairman's tech, in the Corporate brand's blue (never a hazard's colour, never the reference's cyan); his height the
## tallest; the two women beside him built like the woman in red.
func _test_looks() -> void:
	var keys := {}
	for look: int in CasinoPeople.Look.values():
		var parts: HumanoidParts = CasinoPeople.parts(look)
		check(parts != null and not parts.pieces.is_empty() and not keys.has(parts.cache_key),
			"the %s look is built, with its own meshes" % CasinoPeople.look_name(look))
		keys[parts.cache_key] = true
		var glowing: Array[Color] = []
		var all: Array[HumanoidPiece] = parts.pieces.duplicate()
		for panel: HumanoidPanel in parts.panels:
			all.append_array(panel.pieces)
		for piece: HumanoidPiece in all:
			if piece.glow > 0.0:
				glowing.append(piece.color)
		if look == CasinoPeople.Look.CHAIRMAN:
			var blue: bool = not glowing.is_empty()
			for c: Color in glowing:
				blue = blue and c.h > 0.58 and c.h < 0.72
			check(blue, "the Chairman's tech glows the brand's blue, nothing else on him")
		else:
			check(glowing.is_empty(), "nothing on the %s look glows (%s)" % [CasinoPeople.look_name(look), glowing])
	for look: int in CasinoPeople.Look.values():
		if look != CasinoPeople.Look.CHAIRMAN:
			check(CasinoPeople.design_height(look) <= CasinoPeople.design_height(CasinoPeople.Look.CHAIRMAN),
				"the Chairman stands tallest (%s)" % CasinoPeople.look_name(look))
	for look: int in [CasinoPeople.Look.ESCORT_BLACK, CasinoPeople.Look.ESCORT_BLONDE]:
		check(CasinoPeople.has_panels(look) == CasinoPeople.has_panels(CasinoPeople.Look.LADY_IN_RED)
			and CasinoPeople.parts(look).panels.size() == CasinoPeople.parts(CasinoPeople.Look.LADY_IN_RED).panels.size(),
			"%s wears the woman in red's gown" % CasinoPeople.look_name(look))


# --- The beats -----------------------------------------------------------------------------------

func _check_intro(lanes: int) -> void:
	var t0: int = Time.get_ticks_usec()
	var seq: CasinoBossIntro = _start()
	var setup_msec: float = (Time.get_ticks_usec() - t0) / 1000.0
	if seq == null:
		check(false, "%d lanes: the intro starts" % lanes)
		return
	var n: CasinoBossIntroTuning = seq.n
	var stage: CineStage = seq.stage
	var hall: CasinoHall = seq.hall
	var tag: String = "%d lanes" % lanes
	var boss := App.campaign.step("casino/boss").boss as BossDef
	check(stage.geo.lane_count == lanes and boss != null and stage.skin == boss.arena.skin,
		"%s: it plays in the fight's look and lanes" % tag)
	check(seq.playing.problems(sfx).is_empty(), "%s: its timeline has no problems (%s)" % [tag, seq.playing.problems(sfx)])
	check(stage.track != null and not stage.track.visible and hall != null and hall.is_visible_in_tree(),
		"%s: the street is hidden, the hall built on it" % tag)
	check(hall.holo.dice.size() == 3 and hall.holo.wheel != null and hall.holo.globe != null and hall.roulette != null
		and hall.door != null and hall.wall_break.blocks.size() > 20, "%s: its tables, three holograms, the door and the wall" % tag)
	check(seq.crowd.count() >= 50, "%s: a crowd about the hall (%d)" % [tag, seq.crowd.count()])
	var shape: TheHouseModel.Shape = hall.house_shape
	var want: TheHouseModel.Shape = seq._house_shape()
	check(is_equal_approx(shape.width, want.width) and is_equal_approx(shape.height, want.height)
		and hall.hole_width > shape.width and hall.hole_height > shape.height and hall.hole_height < CasinoHall.HEIGHT,
		"%s: The House is the fight's machine (%.1f m wide), the hole cut round it (%.1f m by %.1f m)" % [tag, shape.width,
		hall.hole_width, hall.hole_height])
	var door_x0: float = CasinoHall.DOOR_X - CasinoHall.DOOR_WIDTH * 0.5
	check(hall.hole_x + hall.hole_width * 0.5 < door_x0 - 0.5 and hall.hole_x - hall.hole_width * 0.5 > -CasinoHall.HALF_WIDTH + 0.5,
		"%s: the hole is in the wall to the left of the golden door" % tag)
	_check_paths(seq, tag)

	var runner := seq.actors[&"runner"] as CineActorNode
	var guards: Array[CineActorNode] = [seq.actors[&"guard_l"] as CineActorNode, seq.actors[&"guard_r"] as CineActorNode]
	var worst_step: float = 0.0
	var step_total: float = 0.0
	var steps: int = 0
	var draw_calls: int = 0
	var camera_out: String = ""
	var cheered: int = 0
	var leaning: bool = true
	var screech_on: bool = true
	var escorts: String = ""
	var airborne: Array[bool] = [false, false]
	var through_door: String = ""
	var wall_still: bool = true
	var checked: Dictionary = {}
	var rest: Array[Transform3D] = []
	for b: Dictionary in hall.wall_break.blocks:
		rest.append(hall.wall_break.block_transform(b, 0.0, n))
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
		if camera_out == "" and (absf(cam.x) > CasinoHall.HALF_WIDTH - CAMERA_MARGIN or cam.z < CAMERA_MARGIN
				or cam.z > CasinoHall.DEPTH - CAMERA_MARGIN or cam.y < 0.2 or cam.y > CasinoHall.HEIGHT - 1.0):
			camera_out = "%.2f s at %s" % [t, cam]
		# The players cheering: a hand up over the head.
		if t > n.cheer_at + 0.6 and t < n.cheer_at + n.cheer_seconds - 0.6:
			for p: CasinoPerson in seq.players:
				var head: float = p.head_point().y
				if maxf(p.hand_point(1).y, p.hand_point(-1).y) > head + CHEER_HAND:
					cheered += 1
		# At the bar.
		if t > n.bar_shot_at + 0.1 and t < n.push_off_at - 0.3:
			var lean: Vector3 = CasinoHall.bar_lean(n.lean_z)
			if runner.track_position.distance_to(lean) > 0.05 or absf(rad_to_deg(angle_difference(runner.yaw, PI * 0.5))) > 8.0:
				leaning = false
			var sp: Vector3 = stage.to_track(seq.screech.global_position)
			if not seq.screech.visible or absf(sp.y - CasinoHall.BAR_HEIGHT) > 0.02 or sp.x < CasinoHall.BAR_FRONT:
				screech_on = false
		# The women either side of him.
		if seq.chairman.visible and escorts == "" and t < n.door_open_at:
			var inv: Transform3D = seq.chairman.global_transform.affine_inverse()
			var bl: Vector3 = inv * seq.escort_black.global_position
			var bd: Vector3 = inv * seq.escort_blonde.global_position
			if not (bl.x < -0.3 and bd.x > 0.3 and bl.length() < 1.3 and bd.length() < 1.3):
				escorts = "%.2f s: black %s, blonde %s" % [t, bl, bd]
		# The dives: in the air partway.
		for i: int in 2:
			var at: float = n.dive_right_at if i == 0 else n.dive_left_at
			if t > at + n.dive_seconds * 0.3 and t < at + n.dive_seconds * 0.7 and runner.track_position.y > 0.2:
				airborne[i] = true
		# Each lunge ends with the runner clear of the guard.
		for i: int in 2:
			var at2: float = n.lunge_left_at if i == 0 else n.lunge_right_at
			var key: String = "lunge%d" % i
			if not checked.has(key) and t >= at2 + n.lunge_seconds:
				checked[key] = true
				var g: Vector3 = guards[i].track_position
				var d: float = Vector2(g.x - runner.track_position.x, g.z - runner.track_position.z).length()
				check(d > DODGE_CLEAR, "%s: the %s guard's lunge misses: the runner dived clear (%.2f m)" % [tag,
					"first" if i == 0 else "second", d])
		# The Chairman passes the door's plane only while it's open.
		var cz: float = seq.chairman_at(t).z
		if seq.chairman.visible and cz > CasinoHall.door_point().z - 0.2 and cz < CasinoHall.DEPTH + 0.6 \
				and CasinoGoldenDoor.openness(t, n) < 0.85 and through_door == "":
			through_door = "%.2f s, open %.2f" % [t, CasinoGoldenDoor.openness(t, n)]
		if t < n.tremble_at - 0.01:
			for i: int in hall.wall_break.blocks.size():
				var xf: Transform3D = hall.wall_break.block_transform(hall.wall_break.blocks[i], t, n)
				if xf.origin.distance_to(rest[i].origin) > 0.001:
					wall_still = false
		if not checked.has("ball") and t >= n.cheer_at:
			checked["ball"] = true
			var b: Vector3 = hall.roulette.ball.position
			var r: float = Vector2(b.x, b.z).length()
			check(hall.roulette.ball_settled(t, n) and r > CasinoRoulette.POCKET_IN and r < CasinoRoulette.POCKET_OUT,
				"%s: the ball has dropped into a pocket before they cheer (%.3f m from the middle)" % [tag, r])
		if not checked.has("shut") and t >= n.door_close_at + n.door_close_seconds + 0.1:
			checked["shut"] = true
			check(CasinoGoldenDoor.openness(t, n) < 0.06 and not seq.chairman.visible and not seq.escort_black.visible
				and not seq.escort_blonde.visible and seq.chairman_at(n.door_close_at).z > CasinoHall.DEPTH + 0.6
				and seq.escort_at(n.door_close_at, -1.0).z > CasinoHall.DEPTH + 0.5 and seq.escort_at(n.door_close_at, 1.0).z > CasinoHall.DEPTH + 0.5,
				"%s: the door has banged shut behind the Chairman and the women, who are gone" % tag)
		if not checked.has("end") and t >= n.fade_at:
			checked["end"] = true
			var high: int = 0
			var flown: int = 0
			for i: int in hall.wall_break.blocks.size():
				var xf: Transform3D = hall.wall_break.block_transform(hall.wall_break.blocks[i], t, n)
				if xf.origin.y > CasinoWallBreak.HEAP_HEIGHT + 0.6:
					high += 1
				if xf.origin.distance_to(rest[i].origin) > 0.5 and xf.origin.z < CasinoHall.DEPTH + CasinoHall.WALL_THICK:
					flown += 1
			check(high == 0 and flown == hall.wall_break.blocks.size(),
				"%s: the wall has burst: every block thrown out of it and down on the floor (%d high, %d of %d out)" % [tag, high, flown,
				hall.wall_break.blocks.size()])
			check(hall.house.lights > 0.99 and hall.house.visible, "%s: The House stands in the hole, its lights on" % tag)
			check(runner.visible and runner.track_position.distance_to(Vector3(n.runner_stop.x, 0.0, n.runner_stop.y)) < 0.1,
				"%s: the runner has come to a stop before the wall" % tag)
	check(camera_out == "", "%s: the camera keeps inside the hall (%s)" % [tag, camera_out])
	check(cheered > 0, "%s: the roulette's players cheer as the ball lands, hands in the air" % tag)
	check(leaning, "%s: the runner leans on the bar, facing out over the hall, until they push off" % tag)
	check(screech_on, "%s: the screech sits on the counter beside them" % tag)
	check(escorts == "", "%s: a woman on either side of the Chairman (%s)" % [tag, escorts])
	check(airborne[0] and airborne[1], "%s: the runner dives (in the air) right and then left" % tag)
	check(through_door == "", "%s: the Chairman goes through the door only while it's open (%s)" % [tag, through_door])
	check(wall_still, "%s: the wall stays still, flush, until it trembles" % tag)
	var heard := PackedStringArray()
	for line: String in seq.log_lines:
		if line.begins_with("sound "):
			heard.append(line.get_slice(" ", 1))
	for v: String in ["roulette_spin", "roulette_drop", "crowd_cheer", "guard_halt", "golden_door", "wall_rumble", "wall_collapse"]:
		check(heard.has(v), "%s: its sound %s plays" % [tag, v])
	var mean: float = step_total / maxf(float(steps), 1.0)
	print("    %s: set up %.1f ms, a step %.2f ms on average, %.2f ms at worst; props %d draw calls" % [tag, setup_msec, mean,
		worst_step, draw_calls])
	check(setup_msec < SETUP_BUDGET_MSEC and worst_step < STEP_BUDGET_MSEC and draw_calls <= PROP_DRAW_CALLS,
		"%s: it costs little (set up %.0f ms, a step at worst %.1f ms, %d draw calls)" % [tag, setup_msec, worst_step, draw_calls])
	await _free(seq)


## The runner's and the Chairman's ways (and the women's beside him) keep clear of the tables, the holograms'
## pedestals, the bar and everyone standing about.
func _check_paths(seq: CasinoBossIntro, tag: String) -> void:
	var n: CasinoBossIntroTuning = seq.n
	var obstacles: Array = [[CasinoHall.ROULETTE, Vector2(CasinoHall.ROULETTE_SIZE.x * 0.5, CasinoHall.ROULETTE_SIZE.y * 0.5)],
		[CasinoHall.BLACKJACK_A, Vector2(1.2, 1.2)], [CasinoHall.BLACKJACK_B, Vector2(1.2, 1.2)], [CasinoHall.POKER, Vector2(1.5, 0.8)],
		[CasinoHall.DICE_TABLE, Vector2(0.85, 1.6)], [CasinoHall.HOLO_DICE, Vector2(1.1, 1.1)], [CasinoHall.HOLO_WHEEL, Vector2(1.1, 1.1)],
		[CasinoHall.HOLO_SPHERE, Vector2(1.1, 1.1)]]
	var bad: String = ""
	var t: float = n.chairman_path[0].z
	while t < n.duration and bad == "":
		var walkers: Dictionary = {"chairman": seq.chairman_at(t), "black": seq.escort_at(t, -1.0), "blonde": seq.escort_at(t, 1.0)}
		if t >= n.push_off_at:
			walkers["runner"] = CasinoBossIntro.path_at(n.runner_path, t) if t <= n.runner_path[n.runner_path.size() - 1].z else Vector3.INF
		for who: String in walkers:
			var p: Vector3 = walkers[who]
			if p == Vector3.INF or p.z > CasinoHall.DEPTH - 0.4:
				continue
			for o: Array in obstacles:
				var c: Vector3 = o[0]
				var half: Vector2 = o[1]
				if absf(p.x - c.x) < half.x + TABLE_CLEARANCE and absf(p.z - c.z) < half.y + TABLE_CLEARANCE:
					bad = "%s at %.2f s (%s) by the table at %s" % [who, t, p, c]
			for s: Dictionary in seq.crowd.spots:
				var at: Vector3 = s["at"]
				if Vector2(p.x - at.x, p.z - at.z).length() < CROWD_CLEARANCE:
					bad = "%s at %.2f s (%s) through someone at %s" % [who, t, p, at]
		t += 0.1
	check(bad == "", "%s: the runner, the Chairman and the women keep clear of the tables and the crowd (%s)" % [tag, bad])


# --- Skipping and the App ----------------------------------------------------------------------------

func _test_skip() -> void:
	for at: float in [1.0, 12.0, 21.0, 27.0, 30.0]:
		var seq: CasinoBossIntro = _start()
		if seq == null:
			return
		var ends: Array[int] = [0]
		seq.finished.connect(func() -> void: ends[0] += 1)
		while not seq.done and seq.time < at - 0.0001:
			seq.advance(STEP)
		seq.skip()
		check(ends[0] == 1 and seq.done and seq.skipped and not seq.stage.visible and not seq.overlay.visible
			and not seq.hall.is_visible_in_tree(), "skip() at %.1f s ends it at once, and nothing of it shows" % at)
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
	var c := App.playing_cinematic() as CasinoBossIntro
	check(c != null and c.step.id == "casino/boss_intro" and App.screen == null and App.run == null,
		"the Casino's boss-intro slot plays it, in the world, with no screen over it")
	var press := InputEventAction.new()
	press.action = &"pause"
	press.pressed = true
	tree.root.push_input(press)
	await physics_frames(3)
	check(App.run != null and App.run.encounter is TheHouse and App.run.context.step.id == "casino/boss"
		and App.profile.is_completed("casino/boss_intro") and App.playing_cinematic() == null and not tree.paused,
		"the pause action skips it: The House's fight starts at once, and nothing is paused")
	App.show_title()
	await tree.process_frame
	App.profile = saved
	main.queue_free()
	App.main = null
	await tree.process_frame
