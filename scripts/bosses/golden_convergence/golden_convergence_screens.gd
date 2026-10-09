class_name GoldenConvergenceScreens
extends GoldenConvergenceAttack
## The Magnate's Screen Storm (GDD §10, the owner's playtest: "TV screens on gold tentacles come crashing down from
## the sky on either side of the runner, smashing lots of spots in lots of lanes, so the player has to dodge and
## weave. Some of the screens hit The Magnate, chipping his health"; proposed: "Each spot is marked by a red square
## and the screen's growing shadow, with a rising glitch-whine, about 0.9 s before it crashes; a storm drops 10-16
## screens over about 5 s, planned so a runner who moves a reaction time after each warning always has a way
## through. A crash hurts only in its square (and above a jump), shatters the screen, and its tentacle yanks it back
## up: nothing stays on the track. During a storm he runs close behind the runner where the camera shows him, and
## about a third of the screens crash on him: each takes about a twelfth of the phase's health (a storm about a
## quarter), so storms alone can end a phase"; task E5d-e): the beat kind `screens`
## (GoldenConvergenceTuning.phase_beats). Every point is planned from the runner's distance when the beat starts, at
## the run speed:
## - the run-up (storm_run_up, over the phase's pace): from his place behind the runner up onto a balustrade (sides
##   in turn, the first by the fight's seed) and along it to storm_ahead in front of the runner, where the run
##   camera shows him at every lane count; he paces them there through the storm;
## - the storm (storm_seconds, never over the pace): its slots (GoldenConvergenceStormPlan.slots: count_for(lanes)
##   screens, storm_hits of them on him, the track's taking turns to come down on the runner and beside them), each
##   warned as its time comes in a lane the plan allows (GoldenConvergenceStormPlan.place_due and pick, from the
##   runner's lane then): one meant for the runner in their lane (waiting up to ON_WAIT for the rule to allow it,
##   then beside them), one beside them around their lane; a slot no lane may take yet waits a moment (SLOT_SLACK)
##   or is let go;
## - each screen (a rig of GoldenConvergenceTentacles): its warning (warning_for(): the red square over its lane
##   where it crashes, a floor warning; its shadow growing; the screen coming down on its tentacle; magnate_glitch)
##   then the crash (magnate_smash; the screen shatters; on the track its touch is live for screen_hit_seconds over
##   the square, above a jump), then its tentacle yanks it back up (magnate_yank): nothing stays;
## - a screen on him comes down onto his back on the balustrade: he staggers with a cry of pain (magnate_pain, never
##   the roar), and it deals screen_damage() (`damage(..., &"screen")`: the boss bar drops; a phase it ends ends
##   there, and the next one's intro, his hurl, follows);
## - then he drops back behind the runner along the balustrade (the chase), and the beat is over once he's home.

enum Stage { IDLE, RUN_UP, STORM, RETURN }
enum ScreenStage { WARN, CRASH, YANK }

## His back's height over the balustrade's top (where a screen comes down on him).
const BACK_HEIGHT: float = 1.25
## A screen sways this much as it comes down, and lurches this much as it's yanked away.
const SWAY: float = 0.07
const YANK_TILT: float = 0.35

var chase: GoldenConvergenceChase
var magnate: GoldenConvergenceMagnate
var rigs: GoldenConvergenceTentacles
var stage: Stage = Stage.IDLE
var stage_time: float = 0.0
## Storms so far; screens warned, crashed, on him, slots let go (tests).
var storms: int = 0
var warned: int = 0
var crashes: int = 0
var hits_on_him: int = 0
var dropped: int = 0
## The storm under way: {n, t, d0, v, side, first_warn, slots, next}.
var p: Dictionary = {}
var plan: GoldenConvergenceStormPlan
## The screens out now: {rig, n, lane (-1: on him), stage, warn_t, crash_t, at, from, to, x, token, escape,
## warned_at, crash_at (fight time), yank_t, bottom0, entry}.
var live: Array[Dictionary] = []

var _rng := RandomNumberGenerator.new()
var _first_side: int = 0
var _stagger_left: float = 0.0


func _init(p_boss: GoldenConvergence) -> void:
	super(p_boss, &"screens")
	chase = boss.chase
	magnate = boss.magnate
	rigs = boss.tentacles
	var r := RandomNumberGenerator.new()
	r.seed = hash([String(boss.def.id), "screens", boss.rng.seed])
	_first_side = -1 if r.randf() < 0.5 else 1


## The square's depth along the track: screen_depth, or at least the runner's run while a crash is live and their
## body's depth (a runner who stays in the lane is always inside it while it's live).
static func square_depth(t: GoldenConvergenceTuning, movement: MovementTuning) -> float:
	return maxf(t.screen_depth, movement.run_speed * t.screen_hit_seconds + movement.hurtbox_size.z + 0.2)


func busy() -> bool:
	if stage == Stage.RETURN and chase.home():
		_set_stage(Stage.IDLE)
	return stage != Stage.IDLE


## A screen's warning shows or a crash is live.
func warning_on() -> bool:
	for s: Dictionary in live:
		if int(s["stage"]) != ScreenStage.YANK:
			return true
	return false


func start(_beat: Dictionary) -> void:
	clear()
	storms += 1
	_rng.seed = hash([String(boss.def.id), "storm", storms, boss.rng.seed])
	var t: GoldenConvergenceTuning = boss.tuning
	var lanes: int = boss.lane_count()
	plan = GoldenConvergenceStormPlan.make(lanes, t, boss.world.tuning)
	var count: int = GoldenConvergenceStormPlan.count_for(t, lanes)
	var slots: Array[Dictionary] = GoldenConvergenceStormPlan.slots(count, t.storm_hits, t.storm_seconds, _rng)
	plan.set_slots(slots, t.storm_run_up / boss.pace())
	var from: Vector3 = magnate.global_position
	var d0: float = boss.player_distance()
	var side: int = _first_side if storms % 2 == 1 else -_first_side
	p = {"n": storms, "t": 0.0, "d0": d0, "v": boss.speed_planned(), "side": side,
		"first_warn": plan.first_warn, "rel0": -from.z - d0, "from_x": from.x, "from_y": from.y, "count": count}
	chase.drive(self)
	_set_stage(Stage.RUN_UP)
	boss.log_event(&"storm_start", {"n": storms, "side": side, "count": count, "hits": t.storm_hits, "runner": d0})


## Where the runner will be `t` seconds into the storm (planned at the run speed).
func planned(t: float) -> float:
	return float(p["d0"]) + float(p["v"]) * t


func tick(delta: float) -> void:
	if stage == Stage.IDLE or p.is_empty():
		_tick_yanks(delta)
		return
	stage_time += delta
	p["t"] = float(p["t"]) + delta
	var t: float = float(p["t"])
	match stage:
		Stage.RUN_UP:
			_tick_run_up(delta, t)
			if t >= float(p["first_warn"]):
				_set_stage(Stage.STORM)
		Stage.STORM:
			_pace_him(delta)
			_place_due(t)
			_tick_screens(t)
			if stage != Stage.STORM:
				# A screen on him ended the phase (clear() ran): the next phase's intro has him now.
				_tick_yanks(delta)
				return
			if plan.all_placed() and not warning_on():
				_set_stage(Stage.RETURN)
				magnate.play(&"run")
				chase.drop_back(self, int(p["side"]))
				boss.log_event(&"storm_done", {"n": int(p["n"]), "warned": plan.screens.size(), "dropped": dropped,
					"hits": hits_on_him})
	_tick_yanks(delta)


## The frames its tick doesn't run (a phase's intro, the defeat): the screens still out are yanked away.
func look_tick(delta: float) -> void:
	_tick_yanks(delta)


# --- Him ------------------------------------------------------------------------------------------------------

## His place through the storm: on the balustrade on the storm's side, storm_ahead in front of the runner.
func _his_place() -> Vector3:
	return Vector3(chase.balustrade_x(int(p["side"])), chase.balustrade_y(),
		TrackGeometry.world_z(boss.player_distance() + boss.tuning.storm_ahead))


## Up onto the balustrade from behind (while still behind the camera), then along it past the runner.
func _tick_run_up(delta: float, t: float) -> void:
	var u: float = clampf(t / maxf(float(p["first_warn"]), 0.05), 0.0, 1.0)
	var side: int = int(p["side"])
	var k: float = clampf(u / 0.25, 0.0, 1.0)
	k = k * k * (3.0 - 2.0 * k)
	var e: float = u * u * (3.0 - 2.0 * u)
	var x: float = lerpf(float(p["from_x"]), chase.balustrade_x(side), k)
	var y: float = lerpf(float(p["from_y"]), chase.balustrade_y(), k)
	var rel: float = lerpf(float(p["rel0"]), boss.tuning.storm_ahead, e)
	magnate.play(&"run")
	chase.place(Vector3(x, y, TrackGeometry.world_z(boss.player_distance() + rel)), 0.0, delta)


func _pace_him(delta: float) -> void:
	_stagger_left -= delta
	magnate.play(&"stagger" if _stagger_left > 0.0 else &"run")
	chase.place(_his_place(), 0.0, delta)


# --- The screens ----------------------------------------------------------------------------------------------

## Warns the slots whose time has come (GoldenConvergenceStormPlan.place_due: his, and the track's in a lane the plan
## allows now), each on a rig of its own.
func _place_due(t: float) -> void:
	var before: int = plan.dropped
	for entry: Dictionary in plan.place_due(t, boss.player_lane(), _rng):
		_warn(int(entry["lane"]), entry)
	for k: int in plan.dropped - before:
		dropped += 1
		boss.log_event(&"screen_dropped", {"storm": int(p["n"])})


## A screen's warning: a rig comes down over `lane` (or onto him, -1) for `entry` (the plan's).
func _warn(lane: int, entry: Dictionary) -> void:
	var t: GoldenConvergenceTuning = boss.tuning
	var geo: TrackGeometry = boss.world.geo
	var rig: int = rigs.take()
	var crash_t: float = float(entry["crash"])
	var s: Dictionary = {"rig": rig, "n": int(entry["n"]), "lane": lane, "stage": ScreenStage.WARN,
		"warn_t": float(entry["warn"]), "crash_t": crash_t, "escape": int(entry["escape"]),
		"escapes": entry["escapes"], "warned_at": boss.fight_time(),
		"crash_at": boss.fight_time() + (crash_t - float(p["t"])), "token": null, "storm": int(p["n"])}
	warned += 1
	var where: Vector3
	if lane >= 0:
		# The square: where the runner will be halfway through the crash's touch, its depth around it.
		var at: float = planned(crash_t + t.screen_hit_seconds * 0.5)
		var depth: float = square_depth(t, boss.world.tuning)
		s["at"] = at
		s["from"] = at - depth * 0.5
		s["to"] = at + depth * 0.5
		s["x"] = geo.lane_x(lane)
		var token := Node3D.new()
		token.name = "ScreenWarning"
		boss.props.add_child(token)
		boss.props.floor_warning(token, lane, float(s["from"]), float(s["to"]))
		s["token"] = token
		where = Vector3(float(s["x"]), 0.5, TrackGeometry.world_z(at))
	else:
		where = _his_place()
	live.append(s)
	_place_screen(s, float(p["t"]))
	boss.sound(&"magnate_glitch", boss.sound_point(where))
	boss.hint("screens")
	boss.log_event(&"screen_warned", {"storm": int(p["n"]), "n": int(s["n"]), "lane": lane, "escape": int(s["escape"]),
		"escapes": s["escapes"], "from": s.get("from", 0.0), "to": s.get("to", 0.0), "crash": float(s["crash_at"]),
		"runner": boss.player_distance(), "runner_lane": boss.player_lane()})


## Every screen out: coming down, crashing, its touch's end.
func _tick_screens(t: float) -> void:
	for i: int in range(live.size() - 1, -1, -1):
		if i >= live.size():
			continue
		var s: Dictionary = live[i]
		match int(s["stage"]):
			ScreenStage.WARN:
				if t >= float(s["crash_t"]):
					_crash(s)
					if stage != Stage.STORM:
						return
				else:
					_place_screen(s, t)
			ScreenStage.CRASH:
				if t >= float(s["crash_t"]) + boss.tuning.screen_hit_seconds:
					_end_touch(s)
					_start_yank(s, t)


## A warned screen at storm time `t`: coming down on its tentacle (from screen_drop_height, faster and faster), its
## square and shadow on the floor under it (a screen on him: over his back, no square: he's off the track).
func _place_screen(s: Dictionary, t: float) -> void:
	var tu: GoldenConvergenceTuning = boss.tuning
	var u: float = clampf((t - float(s["warn_t"])) / maxf(float(s["crash_t"]) - float(s["warn_t"]), 0.05), 0.0, 1.0)
	var drop: float = tu.screen_drop_height * (1.0 - u) * (1.0 - u)
	var tilt: float = SWAY * sin(t * 5.0 + float(s["n"])) * (1.0 - u)
	var rig: int = int(s["rig"])
	if int(s["lane"]) >= 0:
		var x: float = float(s["x"])
		var z: float = TrackGeometry.world_z(float(s["at"]))
		rigs.set_screen(rig, x, z, drop, tilt)
		rigs.set_square(rig, x, float(s["at"]), u)
		rigs.set_shadow(rig, x, z, u)
	else:
		var him: Vector3 = _his_place()
		rigs.set_screen(rig, him.x, him.z, him.y + BACK_HEIGHT + drop, tilt)


## The crash: the screen shatters on the floor (its touch live over the square) or on his back (his health).
func _crash(s: Dictionary) -> void:
	var tu: GoldenConvergenceTuning = boss.tuning
	var geo: TrackGeometry = boss.world.geo
	var rig: int = int(s["rig"])
	s["stage"] = ScreenStage.CRASH
	crashes += 1
	var lane: int = int(s["lane"])
	if lane >= 0:
		var x: float = float(s["x"])
		var z: float = TrackGeometry.world_z(float(s["at"]))
		var half: float = geo.lane_width * tu.screen_width_share * 0.5
		rigs.set_screen(rig, x, z, 0.0, 0.0, false)
		rigs.set_touch(rig, x - half, x + half, float(s["from"]), float(s["to"]))
		rigs.shatter(rig, Vector3(x, 0.7, z))
		boss.world.effects.shake(0.12, 0.15)
		boss.sound(&"magnate_smash", boss.sound_point(Vector3(x, 0.5, z)))
		boss.log_event(&"screen_crash", {"storm": int(s["storm"]), "n": int(s["n"]), "lane": lane,
			"runner": boss.player_distance(), "runner_lane": boss.player_lane()})
		return
	# On him: it shatters over his back; he staggers and cries out; the boss bar drops.
	var him: Vector3 = _his_place()
	rigs.set_screen(rig, him.x, him.z, him.y + BACK_HEIGHT, 0.0, false)
	rigs.shatter(rig, magnate.back_point() + Vector3(0.0, 0.4, 0.0))
	hits_on_him += 1
	_stagger_left = tu.stagger_seconds
	magnate.play(&"stagger")
	boss.world.effects.shake(0.2, 0.25)
	boss.sound(&"magnate_smash", boss.sound_point(him))
	boss.sound(&"magnate_pain", boss.sound_point(magnate.head_point()))
	var amount: float = boss.screen_damage()
	var phase: int = boss.phase_index
	boss.log_event(&"screen_hit", {"storm": int(s["storm"]), "n": int(s["n"]), "damage": amount, "health": boss.health})
	var dealt: float = boss.damage(amount, &"screen")
	if boss.phase_index == phase and not boss.is_defeated():
		boss.log_event(&"screen_dealt", {"n": int(s["n"]), "dealt": dealt, "health": boss.health})


## The crash's touch is over: its square, shadow and floor warning go.
func _end_touch(s: Dictionary) -> void:
	var rig: int = int(s["rig"])
	rigs.touch_off(rig)
	rigs.hide_square(rig)
	rigs.hide_shadow(rig)
	var token: Variant = s.get("token")
	if token != null and is_instance_valid(token):
		boss.props.remove(token as Node)
	s["token"] = null


## Its tentacle yanks the shattered screen back up (yank seconds from `t`, on the storm's clock or the frames'
## after a clear: _tick_yanks counts it down).
func _start_yank(s: Dictionary, _t: float) -> void:
	s["stage"] = ScreenStage.YANK
	s["yank_left"] = boss.tuning.screen_yank_seconds
	s["bottom0"] = rigs.screen_bottom(int(s["rig"]))
	var at: Vector3 = rigs.screen_point(int(s["rig"]))
	s["yank_x"] = at.x
	s["yank_z"] = at.z
	boss.sound(&"magnate_yank", boss.sound_point(at))


## The screens being yanked away: up out of sight, faster and faster, lurching; then back to the pool.
func _tick_yanks(delta: float) -> void:
	for i: int in range(live.size() - 1, -1, -1):
		var s: Dictionary = live[i]
		if int(s["stage"]) != ScreenStage.YANK:
			continue
		s["yank_left"] = float(s["yank_left"]) - delta
		var total: float = maxf(boss.tuning.screen_yank_seconds, 0.05)
		var k: float = clampf(1.0 - float(s["yank_left"]) / total, 0.0, 1.0)
		var bottom: float = float(s["bottom0"]) + (boss.tuning.screen_drop_height + 6.0) * k * k
		var dir: float = 1.0 if int(s["n"]) % 2 == 0 else -1.0
		rigs.set_screen(int(s["rig"]), float(s["yank_x"]), float(s["yank_z"]) - 2.0 * k, bottom, dir * YANK_TILT * k, false)
		if k >= 1.0:
			rigs.release(int(s["rig"]))
			live.remove_at(i)


## The screens out now for the bot and the tests: [{n, lane, escape, warned_at, crash_at, stage}] (fight times).
func threats() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s: Dictionary in live:
		out.append({"n": int(s["n"]), "storm": int(s["storm"]), "lane": int(s["lane"]), "escape": int(s["escape"]),
			"warned_at": float(s["warned_at"]), "crash_at": float(s["crash_at"]), "stage": int(s["stage"])})
	return out


func _set_stage(next: Stage) -> void:
	stage = next
	stage_time = 0.0


## Everything at once (a phase's end, the defeat): every touch, square, shadow and floor warning gone, the screens
## still out yanked away (harmless); whoever comes next moves him.
func clear() -> void:
	super()
	for s: Dictionary in live:
		if int(s["stage"]) != ScreenStage.YANK:
			_end_touch(s)
			if rigs != null:
				s["stage"] = ScreenStage.YANK
				s["yank_left"] = boss.tuning.screen_yank_seconds
				s["bottom0"] = rigs.screen_bottom(int(s["rig"]))
				var at: Vector3 = rigs.screen_point(int(s["rig"]))
				s["yank_x"] = at.x
				s["yank_z"] = at.z
	_stagger_left = 0.0
	_set_stage(Stage.IDLE)
	p = {}
