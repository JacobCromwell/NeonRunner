extends TestSuite
## Gangland's outro (GanglandOutro, task F2d; the owner's beats, October 9, 2026, GDD §6 Cinematics): its slot plays
## it; at 3, 5 and 6 lanes, in the fight's look and under its sky (CineStageDef.after_fight), it plays its beats in
## order: the freed Host lying in the rubble, implants dark; screeches sniffing at them for a moment, then
## scuttling away (out of sight before the runner reaches the Host); the runner walking over (a walk, not a run:
## CinePoses' walk, its planted feet not skating, turning unhurriedly) and stopping beside them; the Host
## trembling, harder as they hold the golden key up; the runner taking it (the hands meet, the key goes from the
## Host's hand to the runner's); the cut, under black, to another stretch where the car is parked (the runner
## facing the way they walk at once); the key raised and the car unlocking (its lights blinking); its scissor
## door up; the passenger shot (the owner, October 10, 2026), from inside the car, the runner getting in and
## sitting down beside the screech on the other seat (both in view), which looks round at them, and the two
## nodding to each other once they're sat, then the door down; its lights on; the runner out of sight at the cut
## to the road; the camera at road level as it launches, fast, and drives off down the street into the distance.
## And: the camera stays in the street and above it, never close to a fight's screech; the street built far enough
## wherever the camera looks; its sounds in the library; the passenger one of the screeches from before (the
## fight's body, sitting); Reduced flashing (the unlock a single slow glow); skipping; what it costs; the toolkit's
## after_fight look (an outro without it keeps the zone's own); and the App's flow (it plays after the fight, and
## the Marketplace's intro follows).

const LANES: Array[int] = [3, 5, 6]
const SFX_PATH: String = "res://data/audio/sfx_library.tres"
const SCENE: String = "res://scenes/cinematics/gangland_outro.tscn"
const STEP: float = 1.0 / 30.0
## The camera keeps this far inside the walls, above the street, and this far from a screech.
const WALL_CLEARANCE: float = 0.3
const FLOOR_CLEARANCE: float = 0.1
const SCREECH_CLEARANCE: float = 0.9
## Once the car drives off, the camera is at road level (owner): no higher than this.
const ROAD_LEVEL: float = 0.3
## A walk, not a run (m/s at most); its planted feet move at most this share of the ground it covers (they don't
## skate); it turns at most this fast (rad/s: unhurried, never snapping round).
const WALK_SPEED_MAX: float = 2.5
const FOOT_SLIP: float = 0.1
const TURN_SPEED_MAX: float = 5.0
## Its pose never jumps: a knee bends or straightens at most this far in a frame at 30 fps (degrees; in full
## stride a swinging knee moves about 14° a frame).
const KNEE_STEP_MAX: float = 18.0
## Where the camera looks, the street is built at least this far (Gangland's fog is full by about 165 m).
const STREET_SEEN: float = 150.0
## The hands meet to pass the key (metres apart at most), and it sits in the hand holding it.
const HANDS_MEET: float = 0.35
const IN_HAND: float = 0.05
## The car drives at least this far off into the distance, fast (the owner, October 10, 2026: faster): over this
## speed (m/s) FAST_WITHIN seconds after it launches.
const DRIVES_OFF: float = 90.0
const FAST_SPEED: float = 30.0
const FAST_WITHIN: float = 1.5
## Its length: longer than the GDD's 5-15 s, for the owner's many beats (docs/questions/f2d.md); at most this.
const LONGEST: float = 25.0
## Costs, headless: setting it up, the cut to the car, a step of its clock (generous: they catch a gross
## regression; the measured numbers are printed), and what its props may add to a frame (draw calls).
const SETUP_BUDGET_MSEC: float = 1500.0
const CUT_BUDGET_MSEC: float = 1000.0
const STEP_BUDGET_MSEC: float = 60.0
## (The Host on the humanoid rig is 16 of them: one a joint.)
const PROP_DRAW_CALLS: int = 30

var sfx: SfxLibrary
var _music_before: StringName = &""


func run() -> void:
	sfx = load(SFX_PATH) as SfxLibrary
	var music: MusicDirector = MusicDirector.instance()
	_music_before = music.current() if music != null else &""
	_test_slot()
	_test_fight_look()
	await _test_car_model()
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
	return App.campaign.step("gangland/outro")


## A GanglandOutro for Gangland's outro slot, in the tree, its clock stepped by the test.
func _start() -> GanglandOutro:
	var s: CampaignStep = _step()
	var seq := (load(s.cinematic.scene) as PackedScene).instantiate() as GanglandOutro
	tree.root.add_child(seq)
	seq.play(s.cinematic, s)
	seq.set_process(false)
	return seq


func _free(node: Node) -> void:
	if node != null and is_instance_valid(node):
		node.queue_free()
	await tree.process_frame


func _run_to(seq: GanglandOutro, t: float) -> void:
	while not seq.done and seq.time < t - 0.0001:
		seq.advance(minf(STEP, t - seq.time))


func _test_slot() -> void:
	var s: CampaignStep = _step()
	check(s != null and s.cinematic.is_built() and s.cinematic.scene == SCENE,
		"Gangland's outro slot is built: it plays the Gangland outro")
	var seq := (load(SCENE) as PackedScene).instantiate()
	check(seq is GanglandOutro and (seq as GanglandOutro).numbers != null, "its scene is a GanglandOutro with its numbers")
	seq.free()


## An outro's stage straight after the fight (after_fight) takes the fight's look and sky; without it, the zone's
## own, as before (the City outro's).
func _test_fight_look() -> void:
	var zone: ZoneDef = _step().zone
	var d := CineStageDef.new()
	var after := CineStageDef.new()
	after.after_fight = true
	var fight_sky: LevelSky = zone.boss.arena.sky if zone.boss.arena.sky != null else zone.levels.back().sky
	check(CineStage.skin_for(after, zone, &"outro") == zone.boss.arena.skin
		and CineStage.sky_for(after, zone, &"outro") == fight_sky and fight_sky != null,
		"after the fight, an outro's stage takes the arena's look and the fight's sky (Gangland 3's)")
	check(CineStage.skin_for(d, zone, &"outro") == zone.skin and CineStage.sky_for(d, zone, &"outro") == null,
		"without after_fight, an outro keeps the zone's own look and sky")
	var city: ZoneDef = App.campaign.zones[0]
	check(CineStage.skin_for(d, city, &"outro") == city.skin and CineStage.sky_for(d, city, &"outro") == null,
		"so the City outro's look is unchanged")


## The car: angular and low, its door swinging up from its front edge, its lights and wheels.
func _test_car_model() -> void:
	var car := SportsCarModel.new()
	tree.root.add_child(car)
	car.build()
	var box := AABB()
	for node: Node in [car.body, car.door]:
		var m := node as MeshInstance3D
		var part: AABB = m.global_transform * m.get_aabb()
		box = box.merge(part) if box.size != Vector3.ZERO else part
	check(box.size.z > box.size.x * 2.0 and box.size.y < box.size.x * 0.6
		and box.size.y <= SportsCarModel.DEFAULT_SIZE.y + 0.05,
		"the car is long, wide and low, like a supercar (%s)" % [box.size])
	var verts: PackedVector3Array = car.body.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var nose: float = 0.0
	var cabin: float = 0.0
	for v: Vector3 in verts:
		if v.z < box.position.z + 0.3:
			nose = maxf(nose, v.y)
		if absf(v.z) < 0.4:
			cabin = maxf(cabin, v.y)
	check(nose < cabin * 0.45, "a wedge: its nose (%.2f m) is far lower than its cabin (%.2f m)" % [nose, cabin])
	var shut: Vector3 = car.door.global_position + car.door.global_basis * Vector3(0.0, 0.0, 1.2)
	car.set_door(1.0)
	var open: Vector3 = car.door.global_position + car.door.global_basis * Vector3(0.0, 0.0, 1.2)
	check(open.y > shut.y + 0.8, "its door swings up from its front edge, a scissor door (its back from %.2f to %.2f m)" % [
		shut.y, open.y])
	car.set_lights(0.0)
	check(not car.glow_cards.visible, "its lights off, its glow is out")
	car.set_lights(1.0)
	var spin: float = car.wheels[0].rotation.x
	car.set_travelled(3.0)
	check(car.glow_cards.visible and not is_equal_approx(car.wheels[0].rotation.x, spin),
		"its lights come on, its wheels turn")
	check(car.draw_call_count() <= 8, "it costs %d draw calls (at most 8)" % car.draw_call_count())
	car.set_interior(0.0)
	var dark: bool = not car.cabin_light.visible
	car.set_interior(1.0)
	check(dark and car.cabin_light.visible and car.cabin_light.light_energy > 0.5
		and car.cabin_light.omni_range < SportsCarModel.DEFAULT_SIZE.x,
		"its courtesy lights light its cabin while they're on, and only its cabin")
	car.queue_free()
	await tree.process_frame
	# The screech on its passenger seat is one of the screeches from before (the owner): the fight's body, every
	# triangle and colour of it, sitting up.
	var lying: ArrayMesh = ScreechModel.mesh()
	var sitting: Array[ArrayMesh] = CarPassenger.sitting_meshes()
	var same: bool = true
	var colors: PackedColorArray = lying.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var sat_colors := PackedColorArray()
	for m: ArrayMesh in sitting:
		sat_colors.append_array(m.surface_get_arrays(0)[Mesh.ARRAY_COLOR])
	same = sat_colors.size() == colors.size()
	var count: Dictionary = {}
	for c: Color in colors:
		count[c] = int(count.get(c, 0)) + 1
	for c: Color in sat_colors:
		count[c] = int(count.get(c, 0)) - 1
	for c: Color in count:
		same = same and int(count[c]) == 0
	var head_up: float = sitting[1].get_aabb().get_center().y
	check(same and head_up > CarPassenger.NECK.y * 1.4,
		"the passenger is one of the screeches: the fight's body, all of it, sitting up (its head %.2f up, from %.2f)" % [
		head_up, CarPassenger.NECK.y])


# --- The beats ----------------------------------------------------------------------------------------

func _test_beats(lanes: int) -> void:
	var tag: String = "%d lanes" % lanes
	var t0: int = Time.get_ticks_usec()
	var seq: GanglandOutro = _start()
	var setup_msec: float = (Time.get_ticks_usec() - t0) / 1000.0
	var n: GanglandOutroTuning = seq.n
	var zone: ZoneDef = _step().zone
	var fight_sky: LevelSky = zone.boss.arena.sky if zone.boss.arena.sky != null else zone.levels.back().sky
	check(seq.stage.skin == zone.boss.arena.skin and seq.stage.sky == fight_sky and fight_sky != null
		and seq.stage.geo.lane_count == lanes,
		"%s: it picks up where the fight ended: the arena's look, under the fight's sky, on the level's lanes" % tag)
	check(seq.playing.problems(sfx).is_empty(), "%s: a sound timeline: %s" % [tag, seq.playing.problems(sfx)])
	check(seq.duration() >= 5.0 and seq.duration() <= LONGEST, "%s: %.1f s long (at most %.0f s)" % [
		tag, seq.duration(), LONGEST])
	var p: GanglandOutroSet = seq.props
	check(p != null and p.host != null and p.rubble != null and p.screeches.size() == n.sniffers and seq.key != null,
		"%s: the rubble, the Host, %d screeches and the key are built" % [tag, n.sniffers])
	var runner := seq.actors[&"runner"] as CineActorNode
	var cam: Camera3D = seq.camera
	var problems: PackedStringArray = []
	var steps: int = 0
	var worst_step: float = 0.0
	var cut_msec: float = 0.0
	var max_calls: int = 0
	var sniffing: bool = true
	var screeches_gone: bool = false
	var screech_near_cam: float = INF
	var walk_max: float = 0.0
	var walking: bool = true
	var slipped: float = 0.0
	var covered: float = 0.0
	var last_feet: Array[Vector3] = []
	var turn_max: float = 0.0
	var knee_jump: float = 0.0
	var last_knees := Vector2(INF, INF)
	var faces_on: bool = false
	var arrived: bool = false
	var tremble_rest: float = 0.0
	var tremble_offer: float = 0.0
	var offered: float = 0.0
	var hands_gap: float = INF
	var host_holds: bool = true
	var runner_holds: bool = true
	var glinted: bool = false
	var cut_clean: bool = false
	var parked: bool = true
	var blink_peak: float = 0.0
	var dark_between: bool = true
	var door_up: bool = false
	var at_door: bool = false
	var gone_in: bool = false
	var pet: CarPassenger = null
	var pet_on_seat: bool = false
	var shot_inside: bool = true
	var shot_frames: int = 0
	var pet_in_view: bool = true
	var both_in_view: bool = true
	var sat_frames: int = 0
	var pet_looked: bool = false
	var pet_nodded: float = 0.0
	var runner_looked: bool = false
	var runner_nodded: float = 0.0
	var door_shut: bool = false
	var lit: bool = false
	var wheels_back: bool = false
	var last_turn: float = 0.0
	var road_cam: float = 0.0
	var straight: bool = true
	var last_driven: float = 0.0
	var street_seen: float = INF
	while not seq.done and steps < 2000:
		var before_cut: bool = not seq.at_car
		var s0: int = Time.get_ticks_usec()
		seq.advance(STEP)
		var msec: float = (Time.get_ticks_usec() - s0) / 1000.0
		steps += 1
		if before_cut and seq.at_car:
			cut_msec = msec
		elif seq.time > 0.1:
			worst_step = maxf(worst_step, msec)
		max_calls = maxi(max_calls, seq.props_draw_calls())
		var t: float = seq.time
		if seq.done:
			break
		var track_cam: Vector3 = seq.stage.to_track(cam.global_position)
		# In the street, above it.
		for side: int in [-1, 1]:
			var out: float = side * track_cam.x - (side * seq.stage.wall_x(side) - WALL_CLEARANCE)
			if out > 0.0:
				problems.append("%.2f s: the camera is %.2f m into the %s wall" % [t, out, "left" if side < 0 else "right"])
		if track_cam.y < FLOOR_CLEARANCE:
			problems.append("%.2f s: the camera is %.2f m up, in the street" % [t, track_cam.y])
		# The street is built wherever it looks (forward or back along it).
		var ahead: bool = (-cam.global_basis.z).z < 0.0
		var built_to: float = seq.stage.track._next_chunk * TrackBuilder.CHUNK_LENGTH
		var built_from: float = INF
		for index: int in seq.stage.track._chunks:
			built_from = minf(built_from, float(index) * TrackBuilder.CHUNK_LENGTH)
		street_seen = minf(street_seen, built_to - track_cam.z if ahead else track_cam.z - maxf(built_from, -40.0))
		# Walking, stopping, turning and getting in, no frame jumps the runner's legs (the cut aside).
		if runner.visible and absf(t - seq.t_cut) > STEP * 1.5:
			var knees := Vector2(runner.avatar.rig.joint(&"shin_r").rotation.x,
				runner.avatar.rig.joint(&"shin_l").rotation.x)
			if last_knees.x < INF:
				knee_jump = maxf(knee_jump, rad_to_deg(maxf(absf(knees.x - last_knees.x), absf(knees.y - last_knees.y))))
			last_knees = knees
		else:
			last_knees = Vector2(INF, INF)
		if not seq.at_car:
			# The screeches: sniffing round the Host until they look up, then off and out of sight before the runner
			# reaches them; never close to the camera.
			for i: int in p.screeches.size():
				if p.screech_shown[i] == 1:
					var away: float = p.screeches[i].global_position.distance_to(cam.global_position)
					screech_near_cam = minf(screech_near_cam, away)
				if t < n.look_up_at and p.screech_positions[i].distance_to(seq.host_point) > 2.0:
					sniffing = false
			if absf(t - seq.t_arrive) < STEP * 0.5:
				screeches_gone = not p.screech_shown.has(1)
			if t < seq.t_arrive - 0.6 and t > 0.2:
				walk_max = maxf(walk_max, runner.speed)
				walking = walking and runner.pose == &"walk"
			# Walking at its pace, a planted foot stays put: the lower foot moves little against the ground covered.
			var feet: Array[Vector3] = [runner.avatar.rig.joint(&"foot_r").global_position,
				runner.avatar.rig.joint(&"foot_l").global_position]
			if t > n.walk_from + 0.5 and t < seq.t_arrive and last_feet.size() == 2:
				var low: int = 0 if feet[0].y < feet[1].y else 1
				slipped += Vector2(feet[low].x - last_feet[low].x, feet[low].z - last_feet[low].z).length()
				covered += runner.speed * STEP
			last_feet = feet
			turn_max = maxf(turn_max, runner.turn_speed)
			if absf(t - (seq.t_arrive + 0.3)) < STEP * 0.5:
				arrived = runner.track_position.distance_to(seq.stop_point) < 0.05
			if t > 1.0 and t < n.offer_at - 0.2:
				tremble_rest = maxf(tremble_rest, p.trembling)
			if t > n.offer_at + n.offer_seconds and t < seq.t_take:
				tremble_offer = maxf(tremble_offer, p.trembling)
				offered = maxf(offered, p.offering)
			var host_hand: Vector3 = p.host_hand().global_position
			var runner_hand: Vector3 = runner.avatar.rig.joint(&"hand_r").global_position
			if absf(t - seq.t_take) < STEP * 0.6:
				hands_gap = minf(hands_gap, host_hand.distance_to(runner_hand))
			if t < seq.t_take - 0.05:
				host_holds = host_holds and seq.key_holder == &"host" and seq.key.global_position.distance_to(
					GanglandOutro._in_hand(p.host_hand()).origin) < IN_HAND
			if t > seq.t_take + GanglandOutro.HANDOVER_SECONDS + 0.05:
				runner_holds = runner_holds and seq.key_holder == &"runner" and seq.key.global_position.distance_to(
					GanglandOutro._in_hand(runner.avatar.rig.joint(&"hand_r")).origin) < IN_HAND
			if t > n.glint_at + 0.2 and t < n.glint_at + GanglandOutro.GLINT_SECONDS - 0.2:
				glinted = glinted or seq.key_glint.visible
		else:
			if not cut_clean and t < seq.t_cut + 0.1:
				cut_clean = seq.log_lines.has("stage gangland_boss_skin") and seq.props == null and seq.car != null \
					and seq.stage.skin == zone.boss.arena.skin and seq.stage.sky == fight_sky and seq.key.visible \
					and seq.key_holder == &"runner"
				# Facing the way they walk to the car at once, not turning from where they faced the Host.
				var way: Vector3 = seq.door_point - (seq.car_point + n.approach_from)
				faces_on = absf(angle_difference(runner.yaw, atan2(-way.x, way.z))) < deg_to_rad(15.0)
			if t < n.launch_at:
				turn_max = maxf(turn_max, runner.turn_speed)
			var car: SportsCarModel = seq.car
			# The screech on the passenger seat (the driver's mirrored), riding in the car.
			pet = seq.passenger
			if pet != null and not pet_on_seat:
				var seat: Vector3 = SportsCarModel.seat_of(n.car_size)
				pet_on_seat = pet.get_parent() == car and is_equal_approx(pet.seat.x, -seat.x) \
					and absf(pet.seat.y - seat.y) < 0.01
			# The passenger shot: from inside the car, the screech in view throughout, the runner sat beside it.
			if t > n.passenger_at + 0.02 and t < n.road_at - 0.02:
				shot_frames += 1
				var cam_car: Vector3 = car.global_transform.affine_inverse() * cam.global_position
				shot_inside = shot_inside and absf(cam_car.x) < n.car_size.x * 0.5 and absf(cam_car.z) < n.car_size.z * 0.5 \
					and cam_car.y < n.car_size.y
				var pet_head: Vector3 = pet.neck_point()
				pet_in_view = pet_in_view and cam.is_position_in_frustum(pet_head)
				if t > seq.t_get_in + n.get_in_seconds:
					var head: Vector3 = runner.avatar.rig.joint(&"head").global_position
					both_in_view = both_in_view and cam.is_position_in_frustum(pet_head) \
						and cam.is_position_in_frustum(head) and runner.visible
					sat_frames += 1
				pet_looked = pet_looked or (t > n.passenger_looks_at + 0.8 and pet.looking > 0.99)
				# Once the runner's sat, they nod to each other.
				if t > seq.t_get_in + n.get_in_seconds:
					pet_nodded = maxf(pet_nodded, pet.nodding)
					runner_looked = runner_looked or runner.look < deg_to_rad(GanglandOutro.LOOK_AT_PET * 0.8)
					if runner.look < deg_to_rad(GanglandOutro.LOOK_AT_PET * 0.8):
						runner_nodded = maxf(runner_nodded, -rad_to_deg(runner.look_up))
			if t < n.launch_at:
				parked = parked and seq.stage.to_track(car.global_position).distance_to(seq.car_point) < 0.02
			if t > n.unlock_at and t < n.unlock_at + GanglandOutro.UNLOCK_SECONDS:
				blink_peak = maxf(blink_peak, car.lights)
			if t > n.unlock_at + GanglandOutro.UNLOCK_SECONDS + 0.05 and t < n.lights_at:
				dark_between = dark_between and car.lights < 0.001
			if absf(t - seq.t_get_in) < STEP * 0.5:
				door_up = car.door_open > 0.99
				at_door = runner.track_position.distance_to(seq.door_point) < 0.05 and runner.visible
			if t > seq.t_inside + 0.05:
				gone_in = not runner.visible and not seq.key.visible
			if t > n.door_down_at + n.door_seconds + 0.05:
				door_shut = car.door_open < 0.001
			if t > n.lights_at + 0.4:
				lit = car.lights > 0.99
			# The wheels only ever turn forward, wheelspin and all.
			wheels_back = wheels_back or car.wheel_turn < last_turn - 0.0001
			last_turn = car.wheel_turn
			if t > n.road_at + 0.05:
				road_cam = maxf(road_cam, cam.global_position.y)
			if t > n.launch_at:
				var at_track: Vector3 = seq.stage.to_track(car.global_position)
				straight = straight and absf(at_track.x - seq.car_point.x) < 0.01 and seq.driven >= last_driven
				last_driven = seq.driven
	check(seq.done and not seq.skipped, "%s: it plays to its end" % tag)
	check(sniffing, "%s: the screeches sniff round the Host for a moment" % tag)
	check(screeches_gone, "%s: then scuttle away, out of sight before the runner reaches the Host" % tag)
	check(screech_near_cam > SCREECH_CLEARANCE, "%s: no screech comes within %.1f m of the camera (%.2f m)" % [
		tag, SCREECH_CLEARANCE, screech_near_cam])
	check(walk_max > 0.5 and walk_max < WALK_SPEED_MAX and walking,
		"%s: the runner walks over (CinePoses' walk, at most %.2f m/s)" % [tag, walk_max])
	check(covered > 2.0 and slipped < covered * FOOT_SLIP,
		"%s: their planted feet don't skate (they move %.2f m over the %.2f m walked)" % [tag, slipped, covered])
	check(turn_max > 0.5 and turn_max < TURN_SPEED_MAX, "%s: they turn unhurriedly (at most %.1f rad/s)" % [
		tag, turn_max])
	check(knee_jump > 1.0 and knee_jump < KNEE_STEP_MAX,
		"%s: their pose never jumps (a knee moves at most %.1f° a frame)" % [tag, knee_jump])
	check(arrived, "%s: and stops beside the Host" % tag)
	check(tremble_offer > tremble_rest * 2.0 and tremble_rest > 0.0,
		"%s: the Host trembles, harder as they hold the key up (%.1f°, %.1f°)" % [
		tag, tremble_rest, tremble_offer])
	check(offered > 0.99, "%s: the Host holds the key up to the runner" % tag)
	check(hands_gap < HANDS_MEET, "%s: the runner reaches and their hands meet (%.2f m apart)" % [tag, hands_gap])
	check(host_holds and runner_holds, "%s: the key is in the Host's hand, then the runner's" % tag)
	check(glinted, "%s: it glints" % tag)
	check(cut_clean,
		"%s: under black it cuts to another stretch of the fight's street, the car there, the key in hand" % tag)
	check(parked, "%s: the car stays parked until it launches" % tag)
	check(blink_peak > 0.9 and dark_between, "%s: the key unlocks it: its lights blink, then go out (peak %.2f)" % [
		tag, blink_peak])
	check(faces_on, "%s: at the cut, the runner faces the way they walk to the car" % tag)
	check(door_up and at_door, "%s: its scissor door is up as the runner, at it, gets in" % tag)
	check(pet_on_seat, "%s: a screech sits on the passenger seat, riding in the car" % tag)
	check(shot_frames > 10 and shot_inside and pet_in_view and both_in_view and sat_frames > 10,
		"%s: one shot from inside the car sees the runner get in and sit down beside it" % tag)
	check(pet_looked and pet_nodded > 0.9 and runner_looked and runner_nodded > GanglandOutro.RUNNER_NOD * 0.8,
		"%s: it looks round at them; once they're sat they look round at it, and the two nod to each other" % tag)
	check(n.launch_at > n.road_at,
		"%s: then (the nods seen in the shot, before the cut to the road) the car takes off" % tag)
	check(gone_in and door_shut, "%s: the door comes down, and the runner is out of sight once the camera's outside" % tag)
	check(lit, "%s: its lights come on" % tag)
	check(not wheels_back and last_turn > seq.driven, "%s: its wheels only turn forward, spinning up at the launch" % tag)
	check(road_cam > 0.0 and road_cam <= ROAD_LEVEL,
		"%s: as it drives off, the camera is at road level (%.2f m up at most)" % [
		tag, road_cam])
	check(straight and seq.driven > DRIVES_OFF, "%s: it drives straight off down the street into the distance (%.0f m)" % [
		tag, seq.driven])
	var fast_at: float = n.launch_at + FAST_WITHIN
	var speed: float = (seq.car_distance(fast_at + 0.1) - seq.car_distance(fast_at - 0.1)) / 0.2
	check(speed > FAST_SPEED, "%s: fast: %.0f m/s %.1f s after it launches" % [tag, speed, FAST_WITHIN])
	check(problems.is_empty(), "%s: the camera stays in the street, above it: %s" % [tag, problems.slice(0, 3)])
	check(street_seen >= STREET_SEEN, "%s: wherever it looks, the street is built at least %.0f m (%.0f m)" % [
		tag, STREET_SEEN, street_seen])
	var wanted: PackedStringArray = ["sound screech_sniff", "cue scuttle", "sound key_glint", "cue glint", "cue take",
		"effect fade_out", "cue car", "stage gangland_boss_skin", "sound car_unlock", "sound car_door", "cue passenger",
		"sound screech_chirp", "sound car_door", "sound car_start", "cue lights", "sound car_drive", "cue launch"]
	var at: int = -1
	var in_order: bool = true
	for w: String in wanted:
		var i: int = seq.log_lines.find(w, at + 1)
		in_order = in_order and i > at
		at = maxi(at, i)
	check(in_order, "%s: its beats come in order (%s)" % [tag, seq.log_lines])
	var tracks: Array[String] = []
	for line: String in seq.log_lines:
		if line.begins_with("music "):
			tracks.append(line.trim_prefix("music "))
	check(tracks == [""], "%s: the fight's music fades out as it opens, and no other plays (%s)" % [tag, tracks])
	check(seq.overlay.fade_alpha() > 0.8 and not seq.overlay.visible,
		"%s: it ends on black, and its overlay has gone" % tag)
	check(setup_msec < SETUP_BUDGET_MSEC and cut_msec < CUT_BUDGET_MSEC and worst_step < STEP_BUDGET_MSEC,
		"%s: cheap enough: %.1f ms to set up, %.1f ms to cut to the car (under black), at most %.2f ms a step" % [
		tag, setup_msec, cut_msec, worst_step])
	check(max_calls <= PROP_DRAW_CALLS, "%s: its props add at most %d draw calls (%d)" % [tag, PROP_DRAW_CALLS, max_calls])
	print("  gangland outro, %s: setup %.1f ms, cut %.1f ms, worst step %.2f ms, props %d draw calls; " % [
		tag, setup_msec, cut_msec, worst_step, max_calls]
		+ "feet slip %.2f m in %.2f m, turns at most %.2f rad/s, knees at most %.1f° a frame" % [slipped, covered,
		turn_max, knee_jump])
	await _free(seq)


# --- Comfort, skipping and the App ----------------------------------------------------------------------

## With Reduced flashing the unlock is one slow glow, half as bright, not two blinks.
func _test_reduced_flashing() -> void:
	var reduced: bool = Settings.flashing_reduced
	Settings.flashing_reduced = true
	var seq: GanglandOutro = _start()
	var n: GanglandOutroTuning = seq.n
	_run_to(seq, n.unlock_at)
	var peak: float = 0.0
	var rises: int = 0
	var last: float = 0.0
	var rising: bool = false
	while seq.time < n.unlock_at + GanglandOutro.UNLOCK_SECONDS + 0.1:
		seq.advance(STEP)
		var l: float = seq.car.lights
		peak = maxf(peak, l)
		if l > last + 0.001 and not rising:
			rises += 1
		rising = l > last + 0.001
		last = l
	Settings.flashing_reduced = reduced
	check(rises == 1 and peak <= GanglandOutro.UNLOCK_SOFT + 0.01 and peak > 0.2,
		"Reduced flashing: the unlock is one slow glow (%d rise, peak %.2f)" % [rises, peak])
	await _free(seq)
	seq = _start()
	_run_to(seq, n.unlock_at)
	rises = 0
	last = 0.0
	rising = false
	while seq.time < n.unlock_at + GanglandOutro.UNLOCK_SECONDS + 0.1:
		seq.advance(STEP)
		var l: float = seq.car.lights
		if l > last + 0.001 and not rising:
			rises += 1
		rising = l > last + 0.001
		last = l
	check(rises == 2, "without it, the lights blink twice (%d)" % rises)
	await _free(seq)


func _test_skip() -> void:
	for at: float in [1.0, 9.5, 15.0, 19.0]:
		var seq: GanglandOutro = _start()
		var ends: Array[int] = [0]
		seq.finished.connect(func() -> void: ends[0] += 1)
		_run_to(seq, at)
		seq.skip()
		var car_hidden: bool = seq.car == null or not seq.car.is_visible_in_tree()
		var props_hidden: bool = seq.props == null or not seq.props.is_visible_in_tree()
		check(ends[0] == 1 and seq.done and seq.skipped and not seq.stage.visible and not seq.overlay.visible
			and not seq.key.visible and car_hidden and props_hidden,
			"skip() at %.1f s ends it at once, and nothing of it shows (the key, the car, the rubble)" % at)
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
	var c := App.playing_cinematic() as GanglandOutro
	check(c != null and c.step.id == "gangland/outro" and App.screen == null and App.run == null,
		"the campaign's Gangland outro slot plays the outro, in the world, with no screen over it")
	App.skip_cinematic()
	await physics_frames(3)
	var next := App.playing_cinematic() as Cinematic
	check(App.profile.is_completed("gangland/outro") and next != null and next.step.id == "marketplace/intro",
		"skipped, it counts as done, and the Marketplace's intro follows")
	if next != null:
		App.skip_cinematic()
		await physics_frames(3)
	App.show_title()
	await tree.process_frame
	App.profile = saved
	main.queue_free()
	App.main = null
	await tree.process_frame
