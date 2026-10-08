extends TestSuite
## The Floating Head's propaganda and defeat, and its fight in the campaign (GDD §10; task E1d; the
## rest of the fight: test_floating_head.gd, test_floating_head_faceoff.gd,
## test_floating_head_stomps.gd):
## - its data: the propaganda's sounds and slogans (a few, short), the defeat's sounds, par times;
## - the defeat after the last stomp, at 3, 5 and 6 lanes (a runner who reads the fight, no god mode):
##   the propaganda cuts out mid-shout (no shriek), it shakes free, lurches up in front of the runner
##   with its face glitching, loses power (its face collapses and goes dark, its lights die) and
##   crashes into the street ahead; its face lies flat before the wreck, which lies across the street
##   like a tunnel with room for a runner in every lane; no hitbox of it is live; the runner runs over
##   its face and through the wreck, and anything under it is crushed;
## - beaten by weapons in the air, it dies the same way (no shake);
## - Reduced flashing: its glitch holds steady, no sparks, the slogan doesn't jump;
## - every attempt plays out the same way, the propaganda and the crash too;
## - the whole fight through the campaign at 3, 5 and 6 lanes (a runner who reads the fight and runs
##   the arena, no god mode): the City's last level, the boss intro (skipped), the fight, a win's results
##   and stars, the shop, the outro's slot; in the web demo, then its end screen. Along the way the
##   propaganda starts with the reveal, shows its slogans, and never masks a warning (the voice ducks
##   and the slogan fades while an attack warns or strikes, and no phrase starts then); it crashes where
##   the arena's floor is clear;
## - a death restarts the fight from its start (no checkpoint).
## Every fight here runs at the City's speed (21 m/s), as the campaign plays it (GDD §3; task E1f:
## FloatingHeadBot.campaign_tuning).

const BOSS_PATH: String = "res://data/bosses/city_boss.tres"
const LANES: Array[int] = [3, 5, 6]
const SOUNDS: Array[StringName] = [&"head_voice_1", &"head_voice_2", &"head_voice_3", &"head_voice_4", &"head_voice_cut",
	&"head_power_down", &"head_crash"]
## The runner's room in the wreck is checked this far into its sides (metres).
const ROOM_SLACK: float = 0.02

var sim: RunSim
var def: BossDef


func run() -> void:
	# The fight at the City's speed, as the campaign plays it (GDD §3; E1f).
	tuning = FloatingHeadBot.campaign_tuning(tuning)
	sim = RunSim.new(tree, tuning)
	def = load(BOSS_PATH) as BossDef
	check(def != null and def.is_built(), "the Floating Head's fight exists")
	if def == null:
		return
	_test_data()
	await _test_defeat_after_stomp()
	await _test_weapons_defeat()
	await _test_reduced_flashing()
	await _test_same_every_attempt()
	await _test_campaign()
	await _test_death_restarts()


# --- Helpers -------------------------------------------------------------------------------

## The last phase for a test: straight into the face-off (no bombing runs), the marked towers every
## 200 m from 160 m with a tower lined up at once, on a plain street.
func _last_phase_def() -> BossDef:
	var out: BossDef = def.duplicate() as BossDef
	var t := (def.tuning as FloatingHeadTuning).duplicate() as FloatingHeadTuning
	t.first_run_seconds = 0.0
	t.later_runs = 0
	t.tower_first = 160.0
	t.tower_spacing = 200.0
	t.towers_after = 0
	out.tuning = t
	out.arena = null
	return out


## A fight against `p_def` in a bare world at `lanes`, starting at phase `phase`: [world, head].
func _fight(p_def: BossDef, lanes: int, phase: int = 0) -> Array:
	var head := BossEncounter.create(p_def) as FloatingHead
	var ctx := RunContext.new()
	ctx.mode = RunContext.Mode.QUICK
	ctx.boss = p_def
	ctx.config = BossArena.base_config(p_def)
	ctx.config.lane_count = lanes
	ctx.tuning = tuning
	ctx.boss_resume = {"phase": phase} if phase > 0 else {}
	var arena: BossArena = head.plan_arena(ctx)
	var world: RunWorld = sim.build_world(arena.layout, null, tuning, ctx.config)
	head.setup(world, ctx, arena)
	return [world, head]


func _events(head: BossEncounter, event: StringName) -> Array[Dictionary]:
	return _events_in(head.events, event)


func _events_in(events: Array[Dictionary], event: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in events:
		if e["event"] == event:
			out.append(e)
	return out


func _sounds_in(events: Array[Dictionary], sound: StringName) -> int:
	var n: int = 0
	for e: Dictionary in _events_in(events, &"sound"):
		if e["name"] == sound:
			n += 1
	return n


## The order the defeat's steps came in (event names).
func _defeat_steps(events: Array[Dictionary]) -> PackedStringArray:
	var out := PackedStringArray()
	for e: Dictionary in events:
		if e["event"] in [&"defeated", &"voice_cut", &"shake_free", &"dying", &"fall", &"crashed", &"wreck_passed"]:
			if e["event"] == &"shake_free" and out.is_empty():
				continue
			out.append(String(e["event"]))
	return out


## An attack of its own warns or strikes now (independently of FloatingHead.warning_active): a bomb's
## lock and fall, the eyes charging or the lasers firing, the mouth open for a drop, a tower toppling.
func _attack_warning(head: FloatingHead) -> bool:
	if not head.bombing.target.is_empty() or head.step == FloatingHead.Step.PIN_FALL:
		return true
	var s: FloatingHeadFaceOff.Step = head.faceoff.step
	return s == FloatingHeadFaceOff.Step.CHARGE or s == FloatingHeadFaceOff.Step.FIRE \
		or s == FloatingHeadFaceOff.Step.MOUTH or s == FloatingHeadFaceOff.Step.DROPPING


## The runner's room in the wreck now: how far its hurtbox is from the wreck's inside plating (negative:
## it would pass through it), or INF while it isn't inside.
func _room(head: FloatingHead) -> float:
	var body: FloatingHeadBody = head.body
	var s: FloatingHeadModel.Shape = body.shape
	var to_ship: Transform3D = body.ship_global().affine_inverse()
	var box: AABB = head.world.player.hurtbox_aabb()
	var room: float = INF
	for i: int in 8:
		var local: Vector3 = to_ship * box.get_endpoint(i)
		if local.z > 0.0 or local.z < -head.wreck_length():
			continue
		room = minf(room, FloatingHeadModel.wreck_inner_half(s, local.y, local.z) - absf(local.x))
	return room


## True if any of the wreck's hitboxes is live.
func _live_hitbox(body: FloatingHeadBody) -> bool:
	for child: Node in body.find_children("*", "Hazard", true, false):
		if (child as Hazard).is_active():
			return true
	return false


## Watches a beaten ship until the runner is through its wreck (or `seconds`): {room (the least room the
## runner had inside it), ahead (the face stayed ahead of the runner while it was in the air), glitch
## (lowest while dying), dark (the face and the lights were out by the crash), dead (the runner died)}.
func _watch_defeat(world: RunWorld, head: FloatingHead, seconds: float) -> Dictionary:
	var out := {"room": INF, "ahead": true, "glitch": INF, "powered": INF, "dead": false, "live": false, "solid": false,
		"face_on": INF, "warns": false}
	for i: int in int(seconds * Engine.physics_ticks_per_second):
		if not world.player.alive:
			out["dead"] = true
			break
		if head.wreck_passed():
			break
		match head.step:
			FloatingHead.Step.DYING:
				out["glitch"] = minf(float(out["glitch"]), head.body.glitch)
				out["face_on"] = minf(float(out["face_on"]), head.body.screen_power)
				out["ahead"] = bool(out["ahead"]) and head.pose.z > 0.0
				out["warns"] = bool(out["warns"]) or head.body.eye_charge > 0.0 or head.body.jaw_open > 0.0
			FloatingHead.Step.FALLING:
				out["ahead"] = bool(out["ahead"]) and head.pose.z > 0.0
				out["warns"] = bool(out["warns"]) or head.body.eye_charge > 0.0 or head.body.jaw_open > 0.0
			FloatingHead.Step.WRECKED:
				out["room"] = minf(float(out["room"]), _room(head))
				out["powered"] = minf(float(out["powered"]), 1.0 - maxf(head.body.power, head.body.screen_power))
				out["live"] = bool(out["live"]) or _live_hitbox(head.body)
				out["solid"] = bool(out["solid"]) or head.body.top_solid() or head.body.hull_solid()
		await tree.physics_frame
	return out


# --- Data -------------------------------------------------------------------------------------------

func _test_data() -> void:
	var t := def.tuning as FloatingHeadTuning
	var sfx := load("res://data/audio/sfx_library.tres") as SfxLibrary
	for sound: StringName in SOUNDS:
		check(sfx.names().has(String(sound)) and sfx.stream(sound) != null, "its sound %s exists" % sound)
	check(sfx.volume(&"head_voice_1") < sfx.volume(&"head_laser_charge") - 3.0,
		"the propaganda sits under its warnings in the mix (%.1f dB against %.1f)" % [sfx.volume(&"head_voice_1"),
		sfx.volume(&"head_laser_charge")])
	check(t.slogans.size() >= 3 and t.slogans.size() <= 8, "a few slogans (%d)" % t.slogans.size())
	var short: bool = true
	for slogan: String in t.slogans:
		var lines: PackedStringArray = slogan.split("\n")
		short = short and not slogan.strip_edges().is_empty() and lines.size() <= 2
		for line: String in lines:
			short = short and line.length() <= 12
	check(short, "each slogan is short: at most two lines of 12 characters, so it reads from the runner's distance")
	check(t.voice_duck_db <= -12.0 and t.voice_duck_seconds <= 0.1,
		"under a warning the voice ducks well down (%.0f dB) at once (%.2f s)" % [t.voice_duck_db, t.voice_duck_seconds])
	check(def.three_star_seconds < def.two_star_seconds and def.three_star_seconds >= 60.0 and def.two_star_seconds <= 200.0,
		"its par times: three stars under %.0f s, two under %.0f s" % [def.three_star_seconds, def.two_star_seconds])
	check(t.crash_clear_before > 0.0 and t.crash_clear_after > 0.0 and t.crash_ahead >= 30.0,
		"it crashes well ahead, where the street is clear around its wreck")


# --- The defeat -------------------------------------------------------------------------------------

## The last stomp at every lane count, no god mode: the propaganda cuts out, it shakes free, dies in the
## air in front of the runner and crashes ahead; the runner runs over its face and through the wreck.
func _test_defeat_after_stomp() -> void:
	for lanes: int in LANES:
		var pair: Array = _fight(_last_phase_def(), lanes, 2)
		var world: RunWorld = pair[0]
		var head: FloatingHead = pair[1]
		var tag: String = "(%d lanes)" % lanes
		var bot := FloatingHeadBot.new(head, true)
		var cause: Array[String] = [""]
		world.player.died.connect(func(c: String) -> void: cause[0] = c)
		var fires: Array[float] = []
		world.effects.fireball_played.connect(func(_at: Vector3, size: float) -> void: fires.append(size))
		world.player.running = true
		for i: int in 90 * 60:
			if head.is_defeated() or not world.player.alive:
				break
			bot.step()
			await tree.physics_frame
		check(head.is_defeated() and world.player.alive, "a runner who reads it lands the last stomp (%s) %s" % [cause[0], tag])
		if not head.is_defeated():
			await sim.free_world(world)
			continue
		var w: Dictionary = await _watch_defeat(world, head, 20.0)
		var steps: PackedStringArray = _defeat_steps(head.events)
		check(steps == PackedStringArray(["defeated", "voice_cut", "shake_free", "dying", "fall", "crashed", "wreck_passed"]),
			"GDD §10: the propaganda cuts out, it shakes free, dies in the air, falls and crashes, and the runner runs through the wreck (%s) %s" % [
			", ".join(steps), tag])
		var phase_sounds: int = 0
		for e: Dictionary in _events(head, &"sound"):
			if e["name"] == &"head_shriek" and int(e["phase"]) == 2:
				phase_sounds += 1
		check(phase_sounds == 0 and _events(head, &"voice_cut").size() == 1,
			"the last stomp's cry is the propaganda cutting out mid-shout, not the shriek %s" % tag)
		check(_sounds_in(head.events, &"head_power_down") == 1 and _sounds_in(head.events, &"head_crash") == 1,
			"it's heard losing power and crashing %s" % tag)
		var crash_size: float = FloatingHead.CRASH_FIRE_SIZE
		check(fires.count(crash_size) == 1 and fires.count(crash_size * 0.75) == 1 and fires.count(crash_size * 0.6) == 1,
			"its crash is three fireballs: over the wreck and at each end of it (%s) %s" % [fires, tag])
		check(float(w["glitch"]) >= 0.5 and float(w["face_on"]) >= 0.99, "its face glitches, still on, as it dies in the air %s" % tag)
		check(not bool(w["warns"]), "with no warning of an attack on it (its eyes dark, its mouth shut) %s" % tag)
		check(bool(w["ahead"]), "in the air it stays ahead of the runner, its face toward them %s" % tag)
		check(float(w["powered"]) >= 0.999, "wrecked, its face and its lights are dark %s" % tag)
		check(not bool(w["live"]) and not bool(w["solid"]), "nothing on the wreck can hurt: no hitbox, no deck %s" % tag)
		check(not bool(w["dead"]) and head.wreck_passed() and world.player.alive,
			"the runner runs over its face and through the wreck, no god mode %s" % tag)
		check(float(w["room"]) >= ROOM_SLACK and float(w["room"]) < INF,
			"with room to spare inside it (%.2f m) %s" % [float(w["room"]), tag])
		var face: Transform3D = head.body.face_transform()
		var face_at: float = -face.origin.z
		check(face.basis.z.normalized().dot(Vector3.UP) > 0.99 and face_at < head.crash_at and face_at > head.crash_at - head.face_lead(),
			"its face lies flat in the street in front of the wreck %s" % tag)
		check(head.body.is_wreck() and absf(head.body.global_position.y - head.wreck_belly()) < 0.01,
			"the wreck lies sunk between the trucks %s" % tag)
		check(head.victory_over(), "and the results may follow %s" % tag)
		await sim.free_world(world)


## Beaten by weapons while it flies (no pin): it dies the same way, without shaking free; a cyborg
## left where it lands is crushed.
func _test_weapons_defeat() -> void:
	var pair: Array = _fight(_last_phase_def(), 5, 2)
	var world: RunWorld = pair[0]
	var head: FloatingHead = pair[1]
	world.player.god_mode = true
	world.player.running = true
	var bot := FloatingHeadBot.new(head, false)
	for i: int in 30 * 60:
		if head.step == FloatingHead.Step.FACE_OFF and head.state == BossEncounter.State.FIGHT:
			break
		bot.step()
		await tree.physics_frame
	var dealt: float = head.damage(head.health, &"weapon")
	check(head.is_defeated() and dealt > 0.0, "weapons can finish its last phase (within their share)")
	var d: float = world.player.distance
	var cyborg: Enemy = head.spawn_enemy("cyborg", d + 75.0, 1, 0, {"fires": false})
	var w: Dictionary = await _watch_defeat(world, head, 20.0)
	var steps: PackedStringArray = _defeat_steps(head.events)
	check(steps == PackedStringArray(["defeated", "voice_cut", "dying", "fall", "crashed", "wreck_passed"]),
		"beaten in the air, it glitches, falls and crashes, and the runner runs through the wreck (%s)" % ", ".join(steps))
	var crushed: bool = cyborg == null or not is_instance_valid(cyborg) or not cyborg.alive
	var in_zone: bool = head.crash_at - head.face_lead() - 2.0 <= d + 75.0 and d + 75.0 <= head.crash_at + head.wreck_length() + 2.0
	check(not in_zone or crushed, "a cyborg left where it comes down is crushed")
	check(not bool(w["dead"]) and head.wreck_passed(), "and the runner runs through the wreck")
	await sim.free_world(world)


## Settings > Reduced flashing: its dying glitch holds steady (the face shader holds its tearing and
## static still too), no sparks spit, and the slogan's text doesn't jump.
func _test_reduced_flashing() -> void:
	var glitches: Dictionary = {}
	var sparks: Dictionary = {}
	for reduced: bool in [false, true]:
		var profile := Profile.new()
		Settings.set_value(profile, "reduced_flashing", reduced)
		Settings.apply_visuals(profile)
		var pair: Array = _fight(_last_phase_def(), 5, 2)
		var world: RunWorld = pair[0]
		var head: FloatingHead = pair[1]
		world.player.god_mode = true
		world.player.running = true
		var bot := FloatingHeadBot.new(head, false)
		for i: int in 30 * 60:
			if head.step == FloatingHead.Step.FACE_OFF and head.state == BossEncounter.State.FIGHT:
				break
			bot.step()
			await tree.physics_frame
		head.body.show_slogan(head.tuning.slogans[0])
		head.body.caption = 1.0
		head.damage(head.health, &"weapon")
		var seen: Dictionary = {}
		var jumps: Dictionary = {}
		for i: int in 20 * 60:
			if head.wreck_passed():
				break
			if head.step == FloatingHead.Step.DYING:
				seen[snappedf(head.body.glitch, 0.001)] = true
				if head.body.caption_label().visible:
					jumps[snappedf(head.body.caption_label().position.x, 0.001)] = true
			await tree.physics_frame
		glitches[reduced] = seen.size()
		sparks[reduced] = head.sparks_shown
		if reduced:
			check(jumps.size() <= 1, "the slogan's text holds still as the face glitches (%d places)" % jumps.size())
		await sim.free_world(world)
	var calm := Profile.new()
	Settings.set_value(calm, "reduced_flashing", false)
	Settings.apply_visuals(calm)
	check(int(glitches[false]) > 1 and int(sparks[false]) > 0, "normally its face glitches in bursts and sparks spit from the wreck")
	check(int(glitches[true]) == 1 and int(sparks[true]) == 0,
		"with Reduced flashing the glitch holds steady (%d levels) and no sparks spit (%d)" % [glitches[true], sparks[true]])
	var code: String = FileAccess.get_file_as_string("res://scripts/bosses/floating_head/floating_head_face.gdshader")
	check(code.contains("kit_flash.gdshaderinc") and code.contains("reduced_flashing"),
		"its face shader holds its tearing and static still with Reduced flashing")


## Two attempts with the same moves play out the same way: the propaganda, the defeat and the crash.
func _test_same_every_attempt() -> void:
	var runs: Array[String] = []
	for attempt: int in 2:
		var pair: Array = _fight(_last_phase_def(), 5, 2)
		var world: RunWorld = pair[0]
		var head: FloatingHead = pair[1]
		world.player.running = true
		var bot := FloatingHeadBot.new(head, true)
		for i: int in 110 * 60:
			if head.wreck_passed() or not world.player.alive:
				break
			bot.step()
			await tree.physics_frame
		var log: PackedStringArray = []
		for e: Dictionary in head.events:
			log.append("%s %.3f %s" % [e["event"], float(e["t"]), e])
		log.append("crash %.3f" % head.crash_at)
		runs.append("\n".join(log))
		await sim.free_world(world)
	check(runs[0] == runs[1] and runs[0].contains("voice_cut") and runs[0].contains("crashed"),
		"every attempt plays out the same way, its propaganda and its crash too")


# --- Through the campaign ---------------------------------------------------------------------------

## The whole fight through the campaign's flow at every lane count, with a runner who reads the fight
## and runs the arena (no god mode): from the City's last level through the boss step to the outro; in
## the web demo (5 lanes), on to its end screen.
func _test_campaign() -> void:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	var saved: Profile = App.profile
	var lanes_pc: int = App.rules.lanes_pc
	for lanes: int in LANES:
		var demo: bool = lanes == 5
		if demo:
			BuildFlavor.set_override(BuildFlavor.Kind.WEB_DEMO)
			Platform.configure_for(BuildFlavor.Kind.WEB_DEMO)
		App.profile = SampleProfiles.fresh()
		App.rules.lanes_pc = lanes
		await _campaign_flow(lanes, demo)
		if demo:
			BuildFlavor.set_override(-1)
			Platform.configure_for(BuildFlavor.current())
	App.rules.lanes_pc = lanes_pc
	App.show_title()
	await tree.process_frame
	App.profile = saved
	main.queue_free()
	App.main = null
	await tree.process_frame


func _campaign_flow(lanes: int, demo: bool) -> void:
	var tag: String = "(%d lanes%s)" % [lanes, ", web demo" if demo else ""]
	# The City's last level, finished.
	App.play_step(App.campaign.step("city/3"))
	App.begin_run()
	await physics_frames(10)
	check(App.run != null and App.run.world.geo.lane_count == lanes, "the City's last level starts %s" % tag)
	if App.run == null:
		return
	App.run.world.player.distance = App.run.world.layout.length - 3.0
	await physics_frames(int((LevelRun.COMPLETE_PAUSE + 0.5) * 60.0))
	await tree.process_frame
	var level_result: RunResult = (App.screen as ResultsScreen).result if App.screen is ResultsScreen else null
	check(level_result != null and level_result.completed, "and finished %s" % tag)
	if level_result == null:
		return
	App.continue_after_result(level_result)
	(App.screen as ShopScreen).on_close.call()
	await tree.process_frame
	# The boss intro plays its flyover (task F1); the player skips it.
	var intro: Cinematic = App.playing_cinematic()
	check(intro != null and intro.step.id == "city/boss_intro", "then the boss intro's cinematic %s" % tag)
	if intro == null:
		return
	App.skip_cinematic()
	App.begin_run()
	await physics_frames(3)
	var run: LevelRun = App.run
	check(run != null and run.encounter is FloatingHead and run.context.step.id == "city/boss"
		and run.world.geo.lane_count == lanes and not run.world.player.god_mode, "then the fight, no god mode %s" % tag)
	if run == null or not run.encounter is FloatingHead:
		return
	var head := run.encounter as FloatingHead
	var world: RunWorld = run.world
	var events: Array[Dictionary] = head.events
	var t: FloatingHeadTuning = head.tuning
	var bot := FloatingHeadBot.new(head, true)
	var cause: Array[String] = [""]
	world.player.died.connect(func(c: String) -> void: cause[0] = c)
	var p := {"warned_for": 0.0, "clear_for": 10.0, "loud": 0, "shown": 0, "started_warned": 0, "phrases": 0,
		"caption_seen": false, "room": INF, "fight": 0.0, "crash_clear": false, "wreck_passed": false, "live": false}
	var step_s: float = 1.0 / Engine.physics_ticks_per_second
	for i: int in 400 * 60:
		if App.screen is ResultsScreen or App.run != run:
			break
		if not is_instance_valid(head) or not world.player.alive:
			break
		bot.step()
		var warned: bool = _attack_warning(head)
		p["warned_for"] = float(p["warned_for"]) + step_s if warned else 0.0
		p["clear_for"] = 0.0 if warned else float(p["clear_for"]) + step_s
		var voice: FloatingHeadVoice = head.voice
		if int(voice.phrases) > int(p["phrases"]):
			p["phrases"] = voice.phrases
			if warned or head.warning_active():
				p["started_warned"] = int(p["started_warned"]) + 1
		if float(p["warned_for"]) >= t.voice_duck_seconds + 2.0 * step_s and not voice.cut_off and voice.duck < 0.999:
			p["loud"] = int(p["loud"]) + 1
		if float(p["warned_for"]) >= FloatingHeadVoice.CAPTION_AWAY + 2.0 * step_s and head.body.caption > 0.01:
			p["shown"] = int(p["shown"]) + 1
		var label: Label3D = head.body.caption_label()
		if label.visible and t.slogans.has(label.text):
			p["caption_seen"] = true
		if head.is_defeated():
			p["fight"] = head.fight_time()
			if head.step == FloatingHead.Step.WRECKED:
				p["room"] = minf(float(p["room"]), _room(head))
				p["live"] = bool(p["live"]) or _live_hitbox(head.body)
				if not bool(p["crash_clear"]) and head.arena != null:
					p["crash_clear"] = head.arena.floor_clear(head.crash_at - head.face_lead() - head.metres(t.crash_clear_before),
						head.crash_at + head.wreck_length() + head.metres(t.crash_clear_after))
			p["wreck_passed"] = head.wreck_passed()
		await tree.physics_frame
	await tree.process_frame
	# The fight, as it went.
	var stomps: Array[Dictionary] = _events_in(events, &"stomp")
	check(_events_in(events, &"defeated").size() == 1 and stomps.size() == 3 and cause[0] == "",
		"a runner who reads it beats it with three stomps, never hit (%s) %s" % [cause[0], tag])
	check(float(p["fight"]) >= 60.0 and float(p["fight"]) <= 120.0,
		"GDD §10: the fight lasts 60-120 s for a runner who never misses (%.1f s) %s" % [float(p["fight"]), tag])
	print("  Floating Head through the campaign (%d lanes): %.1f s of fight, %d pins, %d phrases of propaganda" % [
		lanes, float(p["fight"]), _events_in(events, &"pinned").size(), int(p["phrases"])])
	# The propaganda.
	var reveal: Array[Dictionary] = _events_in(events, &"reveal")
	var voices: Array[Dictionary] = _events_in(events, &"voice")
	check(not reveal.is_empty() and not voices.is_empty() and float(voices[0]["t"]) > float(reveal[0]["t"]) + t.boot_seconds - 0.05,
		"its propaganda starts once its face is on (the reveal) %s" % tag)
	check(voices.size() >= 5 and bool(p["caption_seen"]), "it shouts its propaganda all through, with its slogans on its face (%d phrases) %s" % [
		voices.size(), tag])
	var repeats: int = 0
	for i: int in range(1, voices.size()):
		repeats += 1 if voices[i]["phrase"] == voices[i - 1]["phrase"] else 0
	check(repeats == 0, "never the same phrase twice running %s" % tag)
	check(int(p["loud"]) == 0 and int(p["shown"]) == 0 and int(p["started_warned"]) == 0,
		"it never masks a warning: ducked (%d loud frames), no slogan up (%d), no phrase starting under one (%d) %s" % [
		int(p["loud"]), int(p["shown"]), int(p["started_warned"]), tag])
	# The defeat on its real arena.
	check(bool(p["crash_clear"]), "it crashes where the arena's floor is clear around its wreck %s" % tag)
	check(bool(p["wreck_passed"]) and float(p["room"]) >= ROOM_SLACK and not bool(p["live"]),
		"the runner runs through the wreck, with room to spare (%.2f m), nothing live on it %s" % [float(p["room"]), tag])
	# The results, the shop and the outro.
	var result: RunResult = (App.screen as ResultsScreen).result if App.screen is ResultsScreen else null
	check(result != null and result.completed and result.context.is_boss(), "a win's results follow the wreck %s" % tag)
	if result == null:
		return
	check(result.stars == def.stars_for(true, result.time) and result.stars >= 2,
		"with stars from the par times (%d for %.1f s) %s" % [result.stars, result.time, tag])
	check(App.profile.is_completed("city/boss"), "the boss step counts as done %s" % tag)
	App.continue_after_result(result)
	var shop := App.screen as ShopScreen
	check(shop != null and shop.play_label == "Next", "then the shop %s" % tag)
	if shop == null:
		return
	shop.on_close.call()
	await tree.process_frame
	var outro := App.screen as SlotScreen
	check(outro != null and outro.step.id == "city/outro", "then the zone's outro (its slot) %s" % tag)
	if outro == null or not demo:
		return
	outro.continue_button.pressed.emit()
	await tree.process_frame
	check(App.screen is DemoEndScreen, "and the web demo ends on its end screen, the store links (GDD §2) %s" % tag)


## A death restarts the fight from its start (GDD §10: no checkpoints): after the retry it's the first
## phase again, the entrance, at full health.
func _test_death_restarts() -> void:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	var saved: Profile = App.profile
	App.profile = SampleProfiles.fresh()
	App.play_step(App.campaign.step("city/boss"))
	App.begin_run()
	await physics_frames(3)
	var run: LevelRun = App.run
	var head := run.encounter as FloatingHead if run != null else null
	check(head != null, "the fight starts")
	if head != null:
		# Two phases along (as if stomped), then the runner dies in the last one.
		for phase: int in 2:
			for i: int in 20 * 60:
				if head.state == BossEncounter.State.FIGHT:
					break
				await tree.physics_frame
			head.damage(head.hit_damage(), &"stomp")
		check(head.phase_index == 2 and run.context.boss_resume.is_empty(), "in its last phase, with no checkpoint on the way")
		run.world.player._die("test hazard")
		await physics_frames(int((App.rules.death_screen_delay + 0.3) * 60.0))
		await tree.process_frame
		var result: RunResult = (App.screen as ResultsScreen).result if App.screen is ResultsScreen else null
		check(result != null and not result.completed, "a death ends the attempt")
		if result != null:
			App.continue_after_result(result)
			var shop := App.screen as ShopScreen
			check(shop != null and shop.play_label == "Retry", "with a retry")
			if shop != null:
				shop.on_close.call()
				await physics_frames(3)
				var again: LevelRun = App.run
				var head2 := again.encounter as FloatingHead if again != null else null
				check(head2 != null and again.context.attempt == 2 and again.context.boss_resume.is_empty()
					and head2.phase_index == 0 and head2.step == FloatingHead.Step.ENTER
					and is_equal_approx(head2.health, head2.max_health),
					"the retry starts the fight over: the first phase, its entrance, full health")
	App.show_title()
	await tree.process_frame
	App.profile = saved
	main.queue_free()
	App.main = null
	await tree.process_frame
