extends TestSuite
## The Terminal's intro (TerminalIntro; the owner's beats, October 21, 2026): its slot (before Terminal 1, no longer the arrival
## flyover); its seven sounds; at 3, 5 and 6 lanes: the Dead Zone's look outside, in the level's lanes, the station standing back
## from the street's left wall in an opening of it; "GRAND" gone from its front (its ghost, its letters in the rubble) and
## "TERMINAL" drooping with only some of its letters lit, flickering and sparking; the light spilling out; the runner's head turning as
## they survey, the walk round the heap to the route board arriving as the wipe starts, the hand on the board and the trail it wipes,
## the close-up of the board (its stops, THE PALACE last and in gold, the camera in front of it with nobody in the way), the nod and
## the turn, the entrance blocked by the heap to a crack, the climb following the heap and the squeeze through the crack; the cut
## inside onto the Terminal's own stage, the jump down onto the track, the title card; the camera in the street or on the heap, never in
## the front or in the rubble; Reduced flashing (no flicker, fewer and softer sparks); what it costs. Then skipping, and the App's flow.

const LANES: Array[int] = [3, 5, 6]
const SFX_PATH: String = "res://data/audio/sfx_library.tres"
const SCENE: String = "res://scenes/cinematics/terminal_intro.tscn"
const STEP: float = 1.0 / 30.0
const POSE_JOINTS: Array[StringName] = [&"head", &"hand_l", &"hand_r", &"foot_l", &"foot_r"]
const SOUNDS: Array[String] = ["waste_wind", "sign_buzz", "sign_zap", "grime_wipe", "rubble_scramble", "landing_thud", "station_hum"]
const MAX_SOUND_SECONDS: float = 2.5
## The runner stands within this of their places (metres).
const STAND_SLACK: float = 0.12
## The hand is on the board within this of its face (metres), and inside its frame by this much.
const HAND_SLACK: float = 0.09
## Walking, the runner keeps this far off the heap (metres), and their pace is within this range (m/s).
const HEAP_CLEARANCE: float = 0.35
const WALK_PACE := Vector2(1.2, 2.0)
## A joint of the runner moves at most this far in one step (at 30 fps, over what the actor itself moved), on a frame the camera does
## not cut in: poses do not blend, so a change of pose on camera would show as a pop of more than half a metre.
const POSE_JUMP_MAX: float = 0.5
## The wipe leaves this much of THE PALACE and its gold ring clear by the cut to the close-up (mean over its box, and at its worst
## point with the film's edge at its most torn).
const PALACE_CLEAR: float = 0.95
const PALACE_CLEAR_WORST: float = 0.75
## The camera keeps this far over the heap's surface and the ground (metres).
const CAMERA_CLEARANCE: float = 0.15
## The most a lit letter's brightness may change in one step with Reduced flashing (it breathes).
const SOFT_STEP: float = 0.05
## Costs, headless (generous: they catch a gross regression; the measured numbers are printed), and what its props may add to a frame.
const SETUP_BUDGET_MSEC: float = 2500.0
const STEP_BUDGET_MSEC: float = 40.0
const PROP_DRAW_CALLS: int = 160

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
	return App.campaign.step("terminal/intro")


## A TerminalIntro for the Terminal's intro slot, in the tree, its clock stepped by the test.
func _start() -> TerminalIntro:
	var s: CampaignStep = _step()
	if s == null or s.cinematic == null or not s.cinematic.is_built():
		return null
	var seq := (load(s.cinematic.scene) as PackedScene).instantiate() as TerminalIntro
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
		"the Terminal's intro slot is built with its own scene (no longer the arrival flyover)")
	var next: CampaignStep = App.campaign.next_step(s) if s != null else null
	check(next != null and next.id == "terminal/1", "Terminal 1 follows it")
	var seq := (load(SCENE) as PackedScene).instantiate()
	check(seq is TerminalIntro and (seq as TerminalIntro).numbers != null, "its scene is a TerminalIntro with its numbers")
	seq.free()


## Its sounds are in the library, each a sound file under the sound effects' length.
func _test_sounds() -> void:
	for v: String in SOUNDS:
		var stream := sfx.stream(StringName(v)) as AudioStreamWAV
		check(sfx.has_file(StringName(v)) and stream != null, "its sound %s is in the library" % v)
		if stream != null:
			check(stream.get_length() > 0.3 and stream.get_length() < MAX_SOUND_SECONDS,
				"%s is %.2f s (under %.1f s)" % [v, stream.get_length(), MAX_SOUND_SECONDS])


## The runner's place in the station's frame (x along its front, z out from it).
func _in_station(seq: TerminalIntro, p: Vector3) -> Vector3:
	return Vector3(p.z - seq.station.along_at, p.y, p.x - seq.station.front_x)


# --- The beats -----------------------------------------------------------------------------------

func _check_intro(lanes: int) -> void:
	var t0: int = Time.get_ticks_usec()
	var seq: TerminalIntro = _start()
	var setup_msec: float = (Time.get_ticks_usec() - t0) / 1000.0
	if seq == null:
		check(false, "%d lanes: the intro starts" % lanes)
		return
	var n: TerminalIntroTuning = seq.n
	var tag: String = "%d lanes" % lanes
	var outside_skin: ZoneSkin = load(TerminalIntro.OUTSIDE_SKIN_PATH) as ZoneSkin
	check(seq.stage.geo.lane_count == lanes and seq.stage.skin == outside_skin and seq.stage.skin != _step().zone.skin,
		"%s: it opens on the Dead Zone's look (the zone's own is the Terminal's), in the level's lanes" % tag)
	# The letters' own materials are copies of the skin's: building them must leave the skin's shared material as it was (the
	# engine's Resource.duplicate() drops a Vector3 on a colour uniform, which turned the Dead Zone's sheen to the shader's purple).
	var shared: ShaderMaterial = (outside_skin as DeadZoneSkin).solid_material()
	var own_mat: ShaderMaterial = seq.letters.materials[0]
	check(shared.get_shader_parameter(&"sheen_color") is Vector3 and own_mat != shared
		and own_mat.get_shader_parameter(&"sheen_color") == shared.get_shader_parameter(&"sheen_color")
		and own_mat.get_shader_parameter(&"dz_ash") == shared.get_shader_parameter(&"dz_ash"),
		"%s: the letters' materials copy the Dead Zone's, and leave its own parameters intact" % tag)
	check(seq.playing.problems(sfx).is_empty(), "%s: its timeline has no problems (%s)" % [tag, seq.playing.problems(sfx)])
	check(seq.duration() >= 25.0 and seq.duration() <= 32.0 + 0.001, "%s: it lasts %.1f s (the brief suggested about 25 to 32)" % [tag, seq.duration()])
	var stage: CineStage = seq.stage
	var station: TerminalIntroStation = seq.station
	# The station stands back from the street's left wall in an opening of it, and only there.
	check(stage.wall_open(-1, n.station_at - n.frontage * 0.5 + 0.5) and stage.wall_open(-1, n.station_at + n.frontage * 0.5 - 0.5)
		and not stage.wall_open(-1, n.station_at - n.frontage * 0.5 - 1.0) and not stage.wall_open(-1, n.station_at + n.frontage * 0.5 + 1.0),
		"%s: the left wall is open along the station's frontage, and only there" % tag)
	check(is_equal_approx(station.front_x, stage.wall_x(-1) - n.forecourt) and station.body != null and station.shafts != null,
		"%s: its front stands %.0f m back from the wall's line, with the shafts of light out of it" % [tag, n.forecourt])
	# "GRAND" fallen off, "TERMINAL" drooping and sparsely lit.
	var letters: TerminalIntroLetters = seq.letters
	var tipped: int = 0
	for l: Node3D in letters.letters:
		if absf(l.rotation_degrees.z) > 2.0 or absf(l.rotation_degrees.x) > 2.0:
			tipped += 1
	var lit: int = 0
	for b: bool in letters.lit:
		lit += 1 if b else 0
	check(letters.letters.size() == 8 and tipped >= 6, "%s: the eight letters of TERMINAL droop on their mounts (%d tipped)" % [tag, tipped])
	check(lit >= 2 and lit <= 4 and lit < letters.letters.size(), "%s: only a few of them are still lit (%d of %d)" % [tag, lit, letters.letters.size()])
	var fallen: int = 0
	var fallen_high: String = ""
	for node: Node in letters.get_children():
		if String(node.name).begins_with("Fallen"):
			fallen += 1
			var f := node as Node3D
			if f.position.y > n.letter_height + 0.5 or f.position.z < 0.0 or f.position.z > n.forecourt - 1.0:
				fallen_high = "%s at %s" % [f.name, f.position]
	check(fallen == 5 and fallen_high == "", "%s: the five letters of GRAND lie in the rubble on the forecourt, none in the air (%d, %s)" % [tag, fallen, fallen_high])
	check(letters.bursts.size() >= 4 and letters.bursts[0].x < 4.0, "%s: the lit letters spark now and then, the first before the sign is reached (%d bursts)" % [tag, letters.bursts.size()])
	# The entrance: blocked by rubble but for a crack of light under the lintel.
	var heap: TerminalIntroHeap = station.heap
	var blocked: bool = true
	for x: float in [-2.9, -1.5, 0.0, 1.5, 2.9]:
		blocked = blocked and heap.height(x, 0.0) >= n.heap_height - 0.02 and heap.height(x, -0.8) >= n.heap_height - 0.02
	var crack: float = n.door_height - n.heap_height
	check(blocked and crack >= 0.5 and crack <= 1.2 and absf(heap.height(0.0, n.heap_length + 0.5)) < 0.01,
		"%s: the rubble fills the doorway but for a %.2f m crack under the lintel, and spills out %.1f m onto the forecourt" % [tag, crack, n.heap_length])
	check(station.lights.size() >= 2 and station.shaft_material != null and station.pool_material != null,
		"%s: warm light comes out of the entrance and the great window (lights, shafts and a pool)" % tag)
	# The route board: the stops, THE PALACE last and in gold, the others faded.
	var board: TerminalIntroSign = seq.board
	var faded_ok: bool = true
	for c: Color in [TerminalIntroSign.FADED, TerminalIntroSign.FADED_DARK]:
		faded_ok = faded_ok and c.s < 0.35 and c.v < 0.5
	check(board.stops.size() >= 4 and board.palace == "THE PALACE" and not board.stops.has(board.palace) and faded_ok
		and TerminalIntroSign.GOLD.r > 0.9 and TerminalIntroSign.GOLD.g > 0.6 and TerminalIntroSign.GOLD.b < 0.35,
		"%s: the board lists %d dull stops (%s) and THE PALACE last, in gold" % [tag, board.stops.size(), ", ".join(board.stops)])
	# The wipe pose was measured on the real rig; the runner is placed to put the hand on the board.
	check(seq.wipe_hand.size() == TerminalIntro.WIPE_SAMPLES + 1 and board.middle.y > 0.6 and board.middle.y < 1.5,
		"%s: the board hangs at the height the runner's hand reaches (%.2f m)" % [tag, board.middle.y])

	_check_wipe(seq, tag)
	_check_walk_keys(seq, tag)
	var runner := seq.actors[&"runner"] as CineActorNode
	var runner_in := seq.actors[&"runner_in"] as CineActorNode
	var worst_step: float = 0.0
	var step_total: float = 0.0
	var steps: int = 0
	var draw_calls: int = 0
	var checked: Dictionary = {}
	var camera_out: String = ""
	var through_heap: String = ""
	var walk_min: float = INF
	var walk_max: float = 0.0
	var walk_min_at: float = 0.0
	var climb_off: float = 0.0
	var hand_worst: float = 0.0
	var hand_seen: int = 0
	var trail_off: float = 0.0
	var jump_worst: float = 0.0
	var jump_where: String = ""
	var last_joints: Dictionary = {}
	var last_roots: Dictionary = {}
	var last_cam := Vector3.INF
	var square_yaw: float = 180.0
	var looks_left: float = 0.0
	var looks_right: float = 0.0
	var landed_y: float = INF
	var in_flight: bool = false
	var low_out: String = ""
	var played: PackedStringArray = []
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
		# Their pose never pops: no joint moves more than POSE_JUMP_MAX in a step (over what the actor moved), but on a camera cut.
		var cam_now: Vector3 = seq.camera.global_position
		var cut: bool = last_cam != Vector3.INF and cam_now.distance_to(last_cam) > 1.0
		last_cam = cam_now
		for id: StringName in [&"runner", &"runner_in"]:
			var actor_node := seq.actors[id] as CineActorNode
			if actor_node == null or not actor_node.visible or actor_node.avatar == null:
				last_joints.erase(id)
				continue
			var at_root: Vector3 = actor_node.global_position
			var now: Array[Vector3] = []
			for j: StringName in POSE_JOINTS:
				var joint: Node3D = actor_node.avatar.rig.joint(j)
				now.append(joint.global_position if joint != null else at_root)
			if last_joints.has(id) and not cut:
				var moved: Vector3 = at_root - (last_roots[id] as Vector3)
				if moved.length() < CineActorNode.MAX_STEP:
					for k: int in POSE_JOINTS.size():
						var jump: float = ((now[k] - (last_joints[id] as Array[Vector3])[k]) - moved).length()
						if jump > jump_worst:
							jump_worst = jump
							jump_where = "%s %s at %.2f s (pose %s)" % [id, POSE_JOINTS[k], t, actor_node.pose]
			last_joints[id] = now
			last_roots[id] = at_root
		if not seq.inside:
			draw_calls = maxi(draw_calls, seq.props_draw_calls())
			# The camera: in the street (inside its right wall) or on the plaza, in front of the station, never in the rubble.
			var cam: Vector3 = _in_station(seq, stage.to_track(seq.camera.global_position))
			var surface: float = heap.height(cam.x, cam.z)
			if camera_out == "" and (cam.z < 0.3 or cam.z > seq.street_edge + 0.9 or cam.y < CAMERA_CLEARANCE or cam.y < surface + CAMERA_CLEARANCE):
				camera_out = "%.2f s at %s (the rubble %.2f m)" % [t, cam, surface]
			if cam.y > 30.0:
				camera_out = "%.2f s up at %s" % [t, cam]
		var p: Vector3 = _in_station(seq, runner.track_position)
		# Surveying: the head turns right, then left toward the station.
		if t < n.survey_at + 2.0:
			looks_left = maxf(looks_left, rad_to_deg(runner.look))
			looks_right = minf(looks_right, rad_to_deg(runner.look))
		# Walking to the board: the cut to them (the shot that follows them) is not in the shot before it: they are out of frame.
		if not checked.has("walk_cut") and t >= n.walk_at - STEP * 1.01 and t < n.walk_at:
			checked["walk_cut"] = true
			var up := Vector3(0.0, 0.65, 0.0)
			check(not seq.camera.is_position_in_frustum(runner.global_position + up),
				"%s: the walk's cut to where they have got to is unseen (they are out of the shot before it)" % tag)
		# Walking to the board: round the heap, at a natural pace.
		if t > seq.t_walk + 0.5 and t < n.wipe_at - 0.9:
			var spd: float = runner.speed
			if t > seq.t_walk + 1.0 and spd < walk_min:
				walk_min = spd
				walk_min_at = t
			walk_max = maxf(walk_max, spd)
			var half: float = n.door_width * 0.5 + 0.15 + (n.heap_foot_width * 0.5 - n.door_width * 0.5 - 0.15) * pow(clampf(p.z / n.heap_length, 0.0, 1.0), 0.8)
			if through_heap == "" and p.z < n.heap_length + HEAP_CLEARANCE and absf(p.x) < half + HEAP_CLEARANCE and p.z > -1.0:
				through_heap = "%.2f s at %s" % [t, p]
		# The hand on the board through the strokes.
		if t > n.wipe_at + 0.8 and t < n.sign_at - 0.5 and runner.avatar != null:
			var palm: Vector3 = runner.avatar.to_local(runner.avatar.rig.joint(&"hand_r").global_transform * Vector3(0.0, -CineActorNode.GRIP_REACH, 0.0))
			var world: Vector3 = runner.avatar.to_global(palm)
			var hp: Vector3 = _in_station(seq, stage.to_track(world))
			var off: float = absf(hp.z - TerminalIntroSign.FACE_OUT)
			var inside: bool = absf(hp.x - board.middle.x) < TerminalIntroSign.BOARD.x * 0.5 + 0.1 and absf(hp.y - board.middle.y) < TerminalIntroSign.BOARD.y * 0.5 + 0.1
			if inside:
				hand_worst = maxf(hand_worst, off)
				hand_seen += 1
				# The trail the grime clears is this hand's own path: where it is on the board now, against the trail at this moment.
				var on_board := Vector2(hp.x - board.middle.x, hp.y - board.middle.y)
				var trail_at: Vector2 = _trail_at(board, t)
				if trail_at.x < INF:
					trail_off = maxf(trail_off, on_board.distance_to(trail_at))
		# Climbing: their feet follow the heap's surface.
		if t > n.climb_from + 0.3 and t < n.crest_at - 0.1:
			climb_off = maxf(climb_off, absf(p.y - heap.height(p.x, p.z)))
		if not checked.has("sign_cut") and t >= n.sign_at + 0.2:
			checked["sign_cut"] = true
			var cam: Vector3 = _in_station(seq, stage.to_track(seq.camera.global_position))
			var ahead: Vector3 = _in_station(seq, stage.to_track(seq.camera.global_position - seq.camera.global_transform.basis.z * 3.0))
			# In front of the board, looking at it, and the runner clear of the line between (stepped back behind the camera).
			var line: Vector2 = Vector2(board.middle.x - cam.x, board.middle.z - cam.z)
			var to_runner: Vector2 = Vector2(p.x - cam.x, p.z - cam.z)
			var clear: bool = to_runner.dot(line.normalized()) < 0.0 or absf(to_runner.cross(line.normalized())) > 0.6
			check(cam.z > 0.5 and cam.z < 3.0 and absf(cam.x - board.middle.x) < 0.8 and (ahead.z - cam.z) < 0.0 and clear,
				"%s: the close-up is square in front of the board, looking at it, with no one in the way (camera %s, runner %s)" % [tag, cam, p])
		if not checked.has("mind") and t >= n.nod_at + 0.3:
			checked["mind"] = true
			check(rad_to_deg(runner.look_up) < -8.0 and runner.visible, "%s: they nod (head down %.0f°)" % [tag, rad_to_deg(runner.look_up)])
		if not checked.has("turn") and t >= n.turn_at + 1.0:
			checked["turn"] = true
			var turned: float = absf(rad_to_deg(angle_difference(runner.yaw, deg_to_rad(90.0))))
			check(turned > 60.0, "%s: they turn from the board toward the entrance (%.0f° round)" % [tag, turned])
		if not checked.has("door") and t >= n.door_at + 0.9:
			checked["door"] = true
			var foot := Vector3(n.heap_foot.x, 0.0, n.heap_foot.y)
			check(p.distance_to(foot) < STAND_SLACK and rad_to_deg(runner.look_up) > 18.0,
				"%s: they stand at the heap's foot looking up at the entrance (%.2f m off, looking up %.0f°)" % [tag, p.distance_to(foot), rad_to_deg(runner.look_up)])
		if not checked.has("square") and t >= n.wipe_at - 0.05:
			checked["square"] = true
			square_yaw = absf(rad_to_deg(angle_difference(runner.yaw, deg_to_rad(90.0))))
		if not checked.has("wipe_start") and t >= n.wipe_at + 0.05:
			checked["wipe_start"] = true
			check(p.distance_to(seq.stand) < STAND_SLACK + 0.1,
				"%s: they are at the board as the wipe starts (%.2f m off) after a walk of %.1f s" % [tag, p.distance_to(seq.stand), n.wipe_at - seq.t_walk])
		if not checked.has("wipe_end") and t >= n.sign_at - 0.04:
			checked["wipe_end"] = true
			var grime: ShaderMaterial = board.grime_material
			check(int(grime.get_shader_parameter(&"trail_count")) >= TerminalIntroSign.TRAIL_POINTS - 2,
				"%s: the wipe has cleared its whole trail by the cut (%s points)" % [tag, grime.get_shader_parameter(&"trail_count")])
		if not checked.has("squeeze") and t >= n.crest_at + 0.7:
			checked["squeeze"] = true
			check(runner.pose == &"squeeze" and runner.visible and p.z < 0.6 and p.y > n.heap_height - 0.3,
				"%s: they squeeze in through the crack at the heap's crest (pose %s, at %s)" % [tag, runner.pose, p])
		if not checked.has("gone") and t >= n.through_at + 0.5:
			checked["gone"] = true
			check(not runner.visible and runner_in.visible == (t >= n.inside_at - 0.05), "%s: they are through and gone before the cut inside" % tag)
		if not checked.has("inside") and t >= n.inside_at + 0.1:
			checked["inside"] = true
			check(seq.inside and seq.stage.skin == _step().zone.skin and seq.entry != null and seq.entry.is_inside_tree() and runner_in.visible,
				"%s: it has cut inside onto the Terminal's own stage, with the way in on it" % tag)
		if seq.inside and runner_in.visible and t >= n.inside_at:
			var q: Vector3 = runner_in.track_position
			if t >= n.jump_at and t <= seq.t_land + 0.02:
				in_flight = true
			if t >= seq.t_land + 0.1:
				landed_y = minf(landed_y, q.y)
			var cam_in: Vector3 = seq.stage.to_track(seq.camera.global_position)
			if low_out == "" and (cam_in.y < 0.3 or cam_in.x < seq.inside_wall_x + 0.3 or cam_in.x > seq.stage.wall_x(1)):
				low_out = "%.2f s at %s" % [t, cam_in]
		if not checked.has("land") and t >= seq.t_land + 1.5:
			checked["land"] = true
			var q: Vector3 = runner_in.track_position
			var lane: int = stage.geo.lane_at(q.x + stage.origin_x)
			check(absf(q.y) < 0.03 and q.x > seq.inside_wall_x + 3.0 and q.x < stage.wall_x(1) and in_flight,
				"%s: they jump down and land on the floor inside, out from the wall, on the track bed (lane %d, at %s)" % [tag, lane, q])
			var d: Vector3 = (seq.camera.global_transform.basis * Vector3.FORWARD)
			check(-d.z > 0.8 and absf(runner_in.yaw) < deg_to_rad(20.0),
				"%s: the camera looks down the line, the tracks running off ahead, the runner facing along them" % tag)
	check(looks_left > 35.0 and looks_right < -20.0, "%s: the runner's head turns right (%.0f°) and then left toward the station (%.0f°) as they survey" % [tag, looks_right, looks_left])
	check(walk_min > WALK_PACE.x and walk_max < WALK_PACE.y, "%s: they walk quickly and evenly to the board (%.2f m/s at %.2f s to %.2f m/s)" % [tag, walk_min, walk_min_at, walk_max])
	check(through_heap == "", "%s: their walk goes round the heap, not over it (%s)" % [tag, through_heap])
	check(hand_seen > 20 and hand_worst < HAND_SLACK, "%s: while they wipe, their hand is on the board's face throughout (%.3f m off at worst, over %d steps)" % [tag, hand_worst, hand_seen])
	check(trail_off < 0.07, "%s: the grime is cleared along the hand's own path (the trail is %.3f m off the hand at worst)" % [tag, trail_off])
	check(jump_worst < POSE_JUMP_MAX, "%s: their pose never pops (a joint moves %.2f m at most in a step, %s)" % [tag, jump_worst, jump_where])
	check(square_yaw < 6.0, "%s: they are square to the board when the wipe starts (%.1f° off)" % [tag, square_yaw])
	check(climb_off < 0.06, "%s: climbing, their feet follow the rubble's surface (%.3f m off at worst)" % [tag, climb_off])
	check(camera_out == "", "%s: the camera keeps in front of the station, in the street and over the rubble (%s)" % [tag, camera_out])
	check(low_out == "", "%s: inside, the camera stays in the hall (%s)" % [tag, low_out])
	check(landed_y < 0.03, "%s: they end standing on the floor (%.3f m)" % [tag, landed_y])
	var order: Array[String] = ["sound waste_wind", "sound sign_buzz", "sound sign_zap", "sound grime_wipe", "sound rubble_scramble", "cue enter", "sound landing_thud", "text The Terminal", "effect fade_out"]
	var at: int = -1
	var in_order: bool = true
	for want: String in order:
		var found: int = -1
		for i: int in seq.log_lines.size():
			if i > at and seq.log_lines[i].begins_with(want):
				found = i
				break
		if found < 0:
			in_order = false
			played.append("missing " + want)
		else:
			at = found
	check(in_order, "%s: the beats come in order: wind, the sign's buzz and sparks, the wipe, the climb, the cut inside, the landing, the title card, black (%s)" % [tag, played])
	var inside_looks: bool = false
	for line: String in seq.log_lines:
		inside_looks = inside_looks or line == "stage terminal_skin"
	check(inside_looks, "%s: the cut inside builds the Terminal's skin" % tag)
	var mean: float = step_total / maxf(float(steps), 1.0)
	print("    %s: set up %.1f ms, a step %.2f ms on average, %.2f ms at worst; props %d draw calls outside" % [tag, setup_msec, mean, worst_step, draw_calls])
	check(setup_msec < SETUP_BUDGET_MSEC and worst_step < STEP_BUDGET_MSEC and draw_calls <= PROP_DRAW_CALLS,
		"%s: it costs little (set up %.0f ms, a step at worst %.1f ms, %d draw calls)" % [tag, setup_msec, worst_step, draw_calls])
	await _free(seq)


# --- The wipe and the walk ---------------------------------------------------------------------------------------

## The hand's trail at `t` (metres from the board's middle: along, up), between the trail's points; INF outside the strokes.
func _trail_at(board: TerminalIntroSign, t: float) -> Vector2:
	var times: PackedFloat32Array = board.path_times
	if times.size() < 2 or t < times[0] or t > times[times.size() - 1]:
		return Vector2(INF, INF)
	for i: int in times.size() - 1:
		if t >= times[i] and t <= times[i + 1]:
			return board.path[i].lerp(board.path[i + 1], (t - times[i]) / maxf(times[i + 1] - times[i], 0.0001))
	return Vector2(INF, INF)


## How clear `box` (metres from the board's middle, y up) is with the first `count` trail points wiped: the mean over the box and the
## worst point, the film's edge torn by `torn` (TerminalIntroSign.clearance, the grime shader's rule).
func _cleared(box: Rect2, board: TerminalIntroSign, count: int, torn: float) -> Vector2:
	var total: float = 0.0
	var worst: float = 1.0
	var points: int = 0
	for i: int in 25:
		for j: int in 5:
			var p := Vector2(lerpf(box.position.x, box.end.x, float(i) / 24.0), lerpf(box.position.y, box.end.y, float(j) / 4.0))
			var c: float = TerminalIntroSign.clearance(p, board.path, count, torn)
			total += c
			worst = minf(worst, c)
			points += 1
	return Vector2(total / float(points), worst)


## The wipe against the board's rows, by the grime shader's own rule: nothing is clear before the hand has been over it, the first
## stop clears before THE PALACE, and by the cut to the close-up THE PALACE, its gold ring and every stop are clear; the grime is
## opaque until then (nothing, the Palace's glow included, shows through it), drawn over the glow and under the dust, and its
## picture is the board's the right way up.
func _check_wipe(seq: TerminalIntro, tag: String) -> void:
	var board: TerminalIntroSign = seq.board
	var n: TerminalIntroTuning = seq.n
	var count_at_cut: int = 0
	for i: int in board.path_times.size():
		if board.path_times[i] <= n.sign_at:
			count_at_cut = i + 1
	var cap: float = TerminalIntroSign.PALACE_CAP
	var palace_w: float = float(TerminalIntroText.line(board.palace, cap, TerminalIntroSign.GOLD)["width"])
	var palace := Rect2(TerminalIntroSign.NAME_X, TerminalIntroSign.PALACE_ROW - cap * 0.5, palace_w, cap)
	var ring := Rect2(TerminalIntroSign.LINE_X - 0.05, TerminalIntroSign.PALACE_ROW - 0.05, 0.1, 0.1)
	var top_w: float = float(TerminalIntroText.line(board.stops[0], TerminalIntroSign.TEXT_CAP, TerminalIntroSign.FADED)["width"])
	var top_row := Rect2(TerminalIntroSign.NAME_X, TerminalIntroSign.FIRST_ROW - TerminalIntroSign.TEXT_CAP * 0.5, top_w, TerminalIntroSign.TEXT_CAP)
	var torn: float = TerminalIntroSign.RAGGED * 0.5
	var untouched: Vector2 = _cleared(Rect2(-0.7, -0.55, 1.4, 1.1), board, 0, 0.0)
	check(untouched.x < 0.001, "%s: before the hand touches it the whole board is under its grime" % tag)
	# When the top stop is clear (to the point's mean), THE PALACE is not yet.
	var first_clear: int = -1
	for count: int in range(1, count_at_cut + 1):
		if _cleared(top_row, board, count, 0.0).x >= PALACE_CLEAR:
			first_clear = count
			break
	var palace_then: float = _cleared(palace, board, first_clear, 0.0).x if first_clear > 0 else 1.0
	check(first_clear > 0 and first_clear < count_at_cut * 0.6 and palace_then < 0.5,
		"%s: the top of the list is wiped first (clear after %d of %d trail points, THE PALACE then %.0f%% clear)" % [tag, first_clear, count_at_cut, palace_then * 100.0])
	var p_all: Vector2 = _cleared(palace, board, count_at_cut, 0.0)
	var p_torn: Vector2 = _cleared(palace, board, count_at_cut, torn)
	check(p_all.x >= PALACE_CLEAR and p_torn.y >= PALACE_CLEAR_WORST,
		"%s: THE PALACE is wiped clean by the cut to the close-up (%.0f%% clear, %.0f%% at its worst point torn)" % [tag, p_all.x * 100.0, p_torn.y * 100.0])
	var r_all: Vector2 = _cleared(ring, board, count_at_cut, 0.0)
	check(r_all.x >= 0.9, "%s: so is its gold ring (%.0f%% clear)" % [tag, r_all.x * 100.0])
	var stops_ok: bool = true
	var worst_stop: float = 1.0
	for k: int in board.stops.size():
		var w: float = float(TerminalIntroText.line(board.stops[k], TerminalIntroSign.TEXT_CAP, TerminalIntroSign.FADED)["width"])
		var row := Rect2(TerminalIntroSign.NAME_X, TerminalIntroSign.FIRST_ROW - TerminalIntroSign.ROW_PITCH * float(k) - TerminalIntroSign.TEXT_CAP * 0.5,
			w, TerminalIntroSign.TEXT_CAP)
		var c: Vector2 = _cleared(row, board, count_at_cut, 0.0)
		worst_stop = minf(worst_stop, c.x)
		stops_ok = stops_ok and c.x >= 0.9
	check(stops_ok, "%s: and each stop of the list is (the least %.0f%% clear)" % [tag, worst_stop * 100.0])
	var grime: ShaderMaterial = board.grime_material
	var code: String = grime.shader.code
	check(code.contains("0.5 - UV.y") and code.contains("ALPHA = mix(1.0, residue, wiped)"),
		"%s: the grime's picture is the board's the right way up (a quad's UV.y runs down), and it is opaque until wiped" % tag)
	var dust_mat: Material = board.dust.mesh.material
	check(board.gold_halo.render_priority < grime.render_priority and grime.render_priority < dust_mat.render_priority,
		"%s: the Palace's halo is drawn under the grime and the dust over it (%d, %d, %d)" % [tag, board.gold_halo.render_priority, grime.render_priority, dust_mat.render_priority])


## The runner's walk keys: after the last of the survey's looks, and the cut to where they have got to is a real cut (further than
## the toolkit treats as a move), on the camera's cut.
func _check_walk_keys(seq: TerminalIntro, tag: String) -> void:
	var n: TerminalIntroTuning = seq.n
	var runner := seq.actors[&"runner"] as CineActorNode
	var last_look: float = n.looks[n.looks.size() - 1].x
	check(seq.t_walk >= last_look, "%s: they set off after the survey's last look (%.2f s, the look at %.2f s)" % [tag, seq.t_walk, last_look])
	var keys: Array = runner.actor.keys
	var cut_jump: float = 0.0
	var cut_found: bool = false
	for i: int in range(1, keys.size()):
		var k := keys[i] as CineActorKey
		if k.time >= n.walk_at - TerminalIntro.CUT_LEAD - 0.01 and k.time <= n.walk_at:
			cut_found = k.move == CinePath.Move.CUT
			cut_jump = Vector2(k.position.x - (keys[i - 1] as CineActorKey).position.x, k.position.z - (keys[i - 1] as CineActorKey).position.z).length()
	check(cut_found and cut_jump > CineActorNode.MAX_STEP + 0.5,
		"%s: they are cut to where they have got to as the shot that follows them begins (a %.1f m cut)" % [tag, cut_jump])


# --- Reduced flashing ------------------------------------------------------------------------------------------

func _test_reduced_flashing() -> void:
	var was: bool = Settings.flashing_reduced
	var results: Array = []
	for soft: bool in [false, true]:
		Settings.flashing_reduced = soft
		var seq: TerminalIntro = _start()
		if seq == null:
			check(false, "reduced flashing: the intro starts")
			Settings.flashing_reduced = was
			return
		var letters: TerminalIntroLetters = seq.letters
		var lowest: float = INF
		var biggest_step: float = 0.0
		var sparks: int = 0
		var last: Array[float] = []
		var light_min: float = INF
		var light_max: float = -INF
		while not seq.done and seq.time < 16.0:
			seq.advance(STEP)
			for i: int in letters.letters.size():
				if letters.lit[i]:
					var b: float = float(letters.materials[i].get_shader_parameter(&"state_glow"))
					lowest = minf(lowest, b)
					if last.size() > i and last[i] >= 0.0:
						biggest_step = maxf(biggest_step, absf(b - last[i]))
				while last.size() <= i:
					last.append(-1.0)
				last[i] = float(letters.materials[i].get_shader_parameter(&"state_glow")) if letters.lit[i] else -1.0
			sparks = maxi(sparks, letters.live_sparks)
			var level: float = float(seq.station.shaft_material.get_shader_parameter(&"state_glow"))
			light_min = minf(light_min, level)
			light_max = maxf(light_max, level)
		var zaps: int = 0
		for line: String in seq.log_lines:
			zaps += 1 if line == "sound sign_zap" else 0
		results.append({"lowest": lowest, "step": biggest_step, "sparks": sparks, "light": light_max - light_min, "zaps": zaps})
		await _free(seq)
	Settings.flashing_reduced = was
	var normal: Dictionary = results[0]
	var soft_run: Dictionary = results[1]
	check(float(normal["lowest"]) < 0.5 and float(normal["step"]) > 0.15,
		"normally the lit letters flicker (down to %.2f, a step of %.2f)" % [normal["lowest"], normal["step"]])
	check(float(soft_run["lowest"]) > 0.55 and float(soft_run["step"]) < SOFT_STEP and float(soft_run["light"]) < 0.001,
		"with Reduced flashing they breathe slowly instead (lowest %.2f, steps of at most %.3f) and the station's light holds steady" % [soft_run["lowest"], soft_run["step"]])
	check(int(soft_run["sparks"]) < int(normal["sparks"]) and int(soft_run["sparks"]) > 0,
		"and there are fewer sparks (%d at most against %d)" % [soft_run["sparks"], normal["sparks"]])
	check(int(soft_run["zaps"]) > 0 and int(soft_run["zaps"]) * 2 <= int(normal["zaps"]) + 1,
		"and a zap only for the bursts that show sparks (%d against %d)" % [soft_run["zaps"], normal["zaps"]])


# --- Skipping and the App ----------------------------------------------------------------------------

func _test_skip() -> void:
	for at: float in [1.0, 8.0, 15.0, 20.0, 24.0, 29.0]:
		var seq: TerminalIntro = _start()
		if seq == null:
			return
		var ends: Array[int] = [0]
		seq.finished.connect(func() -> void: ends[0] += 1)
		while not seq.done and seq.time < at - 0.0001:
			seq.advance(STEP)
		seq.skip()
		check(ends[0] == 1 and seq.done and seq.skipped and not seq.stage.visible and not seq.overlay.visible,
			"skip() at %.1f s ends it at once, and nothing of it shows" % at)
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
	var c := App.playing_cinematic() as TerminalIntro
	check(c != null and c.step.id == "terminal/intro" and App.screen == null and App.run == null,
		"the Terminal's intro slot plays it, in the world, with no screen over it")
	var press := InputEventAction.new()
	press.action = &"pause"
	press.pressed = true
	tree.root.push_input(press)
	await physics_frames(3)
	check(App.run != null and App.run.context.step.id == "terminal/1" and App.profile.is_completed("terminal/intro")
		and App.playing_cinematic() == null and not tree.paused,
		"the pause action skips it: Terminal 1 starts at once, and nothing is paused")
	App.show_title()
	await tree.process_frame
	App.profile = saved
	main.queue_free()
	App.main = null
	await tree.process_frame
