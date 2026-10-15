extends TestSuite
## The Neon City's outro (CityOutro, task F2a; the owner's beats, GDD §6 Cinematics): its slot plays it; at 3,
## 5 and 6 lanes it plays its beats in order (the Floating Head crashes ahead of the runner and becomes the
## fight's wreck; the camera comes down to the runner's level as they stop; they look left at a roadblock of
## Barnacle Turrets standing on the floor, five cyborgs, a battle truck and a heli drone in an opening of the
## left wall, which the camera pans to and back from; they hop back startled and run the other way, leaping
## out of the right wall's opening as a blast goes off behind them; the scene cuts to the next zone's street
## under black, where they land and run off); the camera never goes through a wall, only out through the
## openings; its blast is one of the shared fireballs (GDD §11); Reduced flashing (the glitch and the light bar
## steady, the blast's fireball softened; the overlay's flash is test_cinematics'); skipping; the landing
## follows the next zone's skin in the campaign's data; what it costs to set up and to play; and the App's
## flow (it plays after the boss, Gangland's intro follows, and the web demo plays it before its end screen).

const LANES: Array[int] = [3, 5, 6]
const SFX_PATH: String = "res://data/audio/sfx_library.tres"
const STEP: float = 1.0 / 30.0
## How close to the floor the camera comes at the runner's level (their height is about 1.3 m).
const GROUND_TOP: float = 1.4
## The camera keeps this far inside a wall's face, unless that wall is open where it is.
const WALL_CLEARANCE: float = 0.3
## Costs, headless: setting it up, cutting to the next zone, and a step of its clock (generous, so a busy
## machine doesn't fail them: they catch a gross regression; the measured numbers are printed, about 25 ms,
## 10 ms and 3 ms).
const SETUP_BUDGET_MSEC: float = 1500.0
const CUT_BUDGET_MSEC: float = 800.0
const STEP_BUDGET_MSEC: float = 25.0
## What its props may add to a frame at most (draw calls).
const PROP_DRAW_CALLS: int = 90

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
	await _test_next_zone_from_data()
	await _test_app_flow()
	if music != null:
		if _music_before == &"":
			music.stop(0.0)
		else:
			music.play(_music_before, 0.0)


func _step() -> CampaignStep:
	return App.campaign.step("city/outro")


## A CityOutro for the City's outro slot, in the tree, its clock stepped by the test.
func _start() -> CityOutro:
	var s: CampaignStep = _step()
	var seq := (load(s.cinematic.scene) as PackedScene).instantiate() as CityOutro
	tree.root.add_child(seq)
	seq.play(s.cinematic, s)
	seq.set_process(false)
	return seq


func _free(node: Node) -> void:
	if node != null and is_instance_valid(node):
		node.queue_free()
	await tree.process_frame


## Steps `seq` to time `t`.
func _run_to(seq: CityOutro, t: float) -> void:
	while not seq.done and seq.time < t - 0.0001:
		seq.advance(minf(STEP, t - seq.time))


func _test_slot() -> void:
	var s: CampaignStep = _step()
	check(s != null and s.cinematic.is_built() and s.cinematic.scene == "res://scenes/cinematics/city_outro.tscn",
		"the City's outro slot is built: it plays the City outro")
	var seq := (load(s.cinematic.scene) as PackedScene).instantiate()
	check(seq is CityOutro and (seq as CityOutro).numbers() != null, "its scene is a CityOutro with its numbers")
	seq.free()


# --- The beats -----------------------------------------------------------------------------------

func _test_beats(lanes: int) -> void:
	var tag: String = "%d lanes" % lanes
	var t0: int = Time.get_ticks_usec()
	var seq: CityOutro = _start()
	var setup_msec: float = (Time.get_ticks_usec() - t0) / 1000.0
	var f: CityOutroTuning = seq.numbers()
	var zone: ZoneDef = _step().zone
	check(seq.stage.skin == zone.skin and seq.stage.geo.lane_count == lanes,
		"%s: it plays in the City's look from the zone's data, on the level's lanes" % tag)
	check(seq.playing.problems(sfx).is_empty(), "%s: a sound timeline: %s" % [tag, seq.playing.problems(sfx)])
	check(seq.duration() >= 5.0 and seq.duration() <= 15.0, "%s: 5-15 s long (GDD §1): %.1f s" % [tag, seq.duration()])
	check(seq.stage.layout.wall_gap_spans(-1, seq.side_mid, seq.side_mid).size() == 1
		and seq.stage.layout.wall_gap_spans(1, seq.stop_z, seq.stop_z).size() == 1,
		"%s: the walls open beside where the runner stops: the side street on the left, the drop on the right" % tag)
	var p: CityOutroSet = seq.props
	check(p != null and p.ship != null and p.turrets.size() == f.turrets and p.truck != null and p.drone != null
		and p.barricade != null and p.side_street.get_child_count() > f.turrets,
		"%s: the props are built: the ship, the roadblock's %d turrets, truck, drone, barricade and side street" % [
		tag, f.turrets])
	var cyborgs: Array[CineActorNode] = []
	for id: StringName in seq.actors:
		var node := seq.actors[id] as CineActorNode
		if node.body != null:
			cyborgs.append(node)
	check(cyborgs.size() == 5, "%s: a row of five cyborgs (%d)" % [tag, cyborgs.size()])
	var turned_over: bool = true
	for turret: BarnacleTurretModel in p.turrets:
		turned_over = turned_over and turret.global_transform.basis.y.y < -0.99 and turret.emerged >= 1.0
	check(turned_over, "%s: the turrets stand on the floor, turned over like cannons, out of their hatches" % tag)
	var runner := seq.actors[&"runner"] as CineActorNode
	var cam: Camera3D = seq.camera
	var geo: TrackGeometry = seq.stage.geo
	var problems: PackedStringArray = []
	var ship_ahead: bool = true
	var ground_cam: float = INF
	var look_max: float = 0.0
	var faced_block: float = -1.0
	var startled: float = 0.0
	var steps: int = 0
	var worst_step: float = 0.0
	var cut_msec: float = 0.0
	var max_calls: int = 0
	var block: Vector3 = seq.stage.point(Vector3(seq.stage.wall_x(-1) - (f.cyborgs_in + f.truck_in) * 0.5, 1.9,
		seq.side_mid))
	var left_through_opening: bool = false
	var blast_behind: bool = false
	var city_hidden: bool = false
	var landed: bool = false
	while not seq.done and steps < 2000:
		var before_cut: bool = not seq.landed_stage
		var s0: int = Time.get_ticks_usec()
		seq.advance(STEP)
		var msec: float = (Time.get_ticks_usec() - s0) / 1000.0
		steps += 1
		if before_cut and seq.landed_stage:
			cut_msec = msec
		elif seq.time > 0.1:
			worst_step = maxf(worst_step, msec)
		var t: float = seq.time
		var track_cam: Vector3 = seq.stage.to_track(cam.global_position)
		var rp: Vector3 = runner.track_position
		if not seq.landed_stage:
			max_calls = maxi(max_calls, p.draw_call_count())
			# The camera stays in the street but where a wall is open, and above its floor while in it.
			for side: int in [-1, 1]:
				var out: float = side * (cam.global_position.x) - (geo.wall_x() - WALL_CLEARANCE)
				if out > 0.0 and not seq.stage.wall_open(side, track_cam.z, 0.5):
					problems.append("%.2f s: the camera is %.2f m into the %s wall" % [t, out, "left" if side < 0 else "right"])
			if absf(cam.global_position.x) < geo.wall_x() and cam.global_position.y < 0.3:
				problems.append("%.2f s: the camera is under the street (%.2f m)" % [t, cam.global_position.y])
		if t < seq.t_crash - 0.05:
			# In the air until its plunge is halfway; then it sinks between the trucks as it lands.
			var high: bool = p.ship.global_position.y > 0.0 or t > f.fall_start + f.fall_seconds * 0.5
			ship_ahead = ship_ahead and not p.wrecked and high and -p.ship.global_position.z > rp.z + 10.0
		if absf(t - (f.stop_at + 0.3)) < STEP * 0.5:
			ground_cam = cam.global_position.y
		if t > f.stop_at + 0.2 and t < f.startle_at:
			look_max = maxf(look_max, rad_to_deg(runner.look))
		if absf(t - (f.pan_back_at - 0.1)) < STEP * 0.5:
			faced_block = (-cam.global_transform.basis.z).dot((block - cam.global_position).normalized())
		if t > f.startle_at and t < seq.t_flee:
			startled = maxf(startled, rp.y)
		if absf(t - seq.t_leap - 0.1) < STEP * 0.5:
			left_through_opening = rp.x > seq.stage.wall_x(1) and seq.stage.wall_open(1, rp.z, 0.5)
		if absf(t - seq.t_blast - 0.15) < STEP * 0.5:
			# Its blast is one of the shared fireballs (GDD §11), from the props' own pool.
			var fire: FireballPool = p.fireballs
			var blast_pos: Vector3 = fire.latest.center if fire != null and fire.latest != null else Vector3.INF
			blast_behind = fire != null and fire.plays == 1 and fire.active() == 1 and fire.visible \
				and cam.global_position.distance_to(runner.global_position) < cam.global_position.distance_to(blast_pos)
		if seq.landed_stage and not city_hidden:
			city_hidden = not p.ship.visible and not p.side_street.visible and not cyborgs[0].visible
		if t > seq.t_land + 0.1 and t < seq.t_run:
			landed = landed or (absf(rp.y) < 0.01 and absf(rp.z - f.land_at) < 0.01)
	check(seq.done and not seq.skipped, "%s: it plays to its end" % tag)
	check(ship_ahead, "%s: until it crashes, the dying ship is in the air ahead of the runner" % tag)
	check(p.wrecked and p.hull.mesh == FloatingHeadModel.meshes(p.shape)["wreck"] and p.screen.global_position.y < 0.3,
		"%s: it crashes into the fight's wreck, its face fallen flat in the street" % tag)
	check(absf(runner.track_position.z - (f.land_at + tuning.run_speed * (f.duration - seq.t_run) * 0.5)) < 0.5,
		"%s: the runner ran their path to its end" % tag)
	check(ground_cam <= GROUND_TOP, "%s: as the runner stops, the camera comes down to their level (%.2f m)" % [
		tag, ground_cam])
	check(absf(look_max - f.look_degrees) < 1.0, "%s: they look left (%.0f°)" % [tag, look_max])
	check(faced_block > 0.98, "%s: the camera pans onto the roadblock (facing it: %.3f)" % [tag, faced_block])
	check(startled >= f.startle_hop * 0.9, "%s: startled, they hop back (%.2f m)" % [tag, startled])
	check(left_through_opening, "%s: they run the other way and leap out through the right wall's opening" % tag)
	check(blast_behind, "%s: the blast goes off behind them, as the camera sees them" % tag)
	check(problems.is_empty(), "%s: the camera never goes through a wall or under the street: %s" % [
		tag, problems.slice(0, 3)])
	check(seq.landed_stage and seq.stage.skin == App.campaign.zones[1].skin and seq.log_lines.has("stage gangland_skin"),
		"%s: under black it cuts to the next zone's street, in its look (%s)" % [tag, seq.stage.skin.resource_path])
	check(city_hidden, "%s: nothing of the City shows after the cut (the ship, the roadblock, the cyborgs)" % tag)
	check(landed, "%s: they land in it, then run off" % tag)
	var wanted: PackedStringArray = ["sound head_power_down", "sound head_crash", "cue crash", "sound enforcer_siren",
		"sound cyborg_charge", "sound jump", "sound truck_explode", "cue blast", "effect fade_out", "stage gangland_skin",
		"sound land"]
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
	check(tracks == ["city", ""], "%s: only the City's music plays, fading out as they leap (%s)" % [tag, tracks])
	check(seq.overlay.fade_alpha() > 0.8 and not seq.overlay.visible,
		"%s: it ends on black, and its overlay has gone" % tag)
	check(setup_msec < SETUP_BUDGET_MSEC and cut_msec < CUT_BUDGET_MSEC and worst_step < STEP_BUDGET_MSEC,
		"%s: cheap enough: %.1f ms to set up, %.1f ms to cut to the next zone (under black), at most %.2f ms a step" % [
		tag, setup_msec, cut_msec, worst_step])
	check(max_calls <= PROP_DRAW_CALLS, "%s: its props add at most %d draw calls (%d)" % [tag, PROP_DRAW_CALLS, max_calls])
	print("  city outro, %s: setup %.1f ms, cut %.1f ms, worst step %.2f ms, props %d draw calls" % [
		tag, setup_msec, cut_msec, worst_step, max_calls])
	await _free(seq)


# --- Comfort, skipping and data --------------------------------------------------------------------

func _test_reduced_flashing() -> void:
	var reduced: bool = Settings.flashing_reduced
	Settings.flashing_reduced = true
	var seq: CityOutro = _start()
	var f: CityOutroTuning = seq.numbers()
	var glitches: Dictionary = {}
	var bar_steady: bool = true
	while not seq.done and seq.time < seq.t_blast + 0.6:
		seq.advance(STEP)
		if seq.time < seq.t_crash - 0.1:
			glitches[snappedf(float(seq.props.face.get_shader_parameter(&"glitch")), 0.01)] = true
		if seq.time > f.siren_at:
			bar_steady = bar_steady and seq.props.truck.flash_phase == -1
	check(glitches.size() == 1, "Reduced flashing: the dying face's glitch holds still (%s)" % [glitches.keys()])
	check(bar_steady, "Reduced flashing: the truck's light bar is steady, both halves lit")
	var fire: FireballPool = seq.props.fireballs
	check(fire != null and fire.plays == 1 and fire.last_reduced,
		"Reduced flashing: the blast's fireball plays softened (no white-hot core, swelling up instead of popping)")
	Settings.flashing_reduced = reduced
	await _free(seq)
	seq = _start()
	var phases: Dictionary = {}
	_run_to(seq, seq.numbers().siren_at + 1.0)
	for i: int in 12:
		seq.advance(0.1)
		phases[seq.props.truck.flash_phase] = true
	check(phases.has(0) and phases.has(1), "without it, the light bar alternates red and blue (%s)" % [phases.keys()])
	await _free(seq)


func _test_skip() -> void:
	for at: float in [1.0, 9.0, 12.0]:
		var seq: CityOutro = _start()
		var ends: Array[int] = [0]
		seq.finished.connect(func() -> void: ends[0] += 1)
		_run_to(seq, at)
		seq.skip()
		check(ends[0] == 1 and seq.done and seq.skipped and not seq.stage.visible and not seq.overlay.visible
			and not seq.props.visible, "skip() at %.0f s ends it at once, and nothing of it shows (props too)" % at)
		seq.skip()
		check(ends[0] == 1, "finished fires once, at %.0f s" % at)
		await _free(seq)


## The landing's street is the next zone's skin, from the campaign's data.
func _test_next_zone_from_data() -> void:
	var next: ZoneDef = App.campaign.zones[1]
	var skin: ZoneSkin = next.skin
	var other := load("res://data/skins/marketplace_skin.tres") as ZoneSkin
	next.skin = other
	var seq: CityOutro = _start()
	_run_to(seq, seq.t_cut + 0.1)
	check(seq.stage.skin == other, "a change of the next zone's skin reaches the landing")
	await _free(seq)
	next.skin = skin


# --- Through the App -------------------------------------------------------------------------------

func _test_app_flow() -> void:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	var saved: Profile = App.profile
	App.profile = SampleProfiles.fresh()
	App.play_step(_step())
	await tree.process_frame
	var c := App.playing_cinematic() as CityOutro
	check(c != null and c.step.id == "city/outro" and App.screen == null and App.run == null,
		"the campaign's City outro slot plays the outro, in the world, with no screen over it")
	App.skip_cinematic()
	await physics_frames(3)
	var next := App.playing_cinematic() as Cinematic
	check(App.profile.is_completed("city/outro") and next != null and next.step.id == "gangland/intro",
		"skipped, it counts as done, and Gangland's intro follows")
	if next != null:
		App.skip_cinematic()
		await physics_frames(3)
	BuildFlavor.set_override(BuildFlavor.Kind.WEB_DEMO)
	App.play_step(_step())
	await tree.process_frame
	check(App.playing_cinematic() is CityOutro, "the web demo plays it too")
	App.skip_cinematic()
	await physics_frames(3)
	check(App.screen is DemoEndScreen and App.playing_cinematic() == null, "then the demo ends on its store links")
	BuildFlavor.set_override(-1)
	App.show_title()
	await tree.process_frame
	App.profile = saved
	main.queue_free()
	App.main = null
	await tree.process_frame
