class_name GoldenConvergenceSlash
extends GoldenConvergenceAttack
## The Magnate's Claw Slash (GDD §10, the owner's playtest: "he runs up behind the runner and slashes at them with
## his claws, and the player has only a split second to dodge"; approved: "The warning: his marker flashes red with
## a sharp snarl (not the Pounce's roar) and red claw marks flash on the floor of the runner's lane; the swipe comes
## about half a second later (never sooner at a faster phase), over the runner's lane only and reaching above a
## jump: dodge by switching lanes (or the dash; armor and the shield block it). In the last phase he slashes twice in
## a row, the second locking onto the lane the runner dodged into"; task E5d-e): the beat kind `slash`, and
## `slash:double` (GoldenConvergenceTuning.phase_beats). Every point is planned from the runner's distance at the
## run speed as it comes:
## - closing in (slash_close_seconds, over the phase's pace): from his place behind the runner to just behind the
##   camera, in their lane;
## - the warning (slash_warning, never over the pace), locked onto the runner's lane as it begins: his marker at the
##   screen's bottom edge flashes red (GoldenConvergenceChase.alarm_flash: steady red with Reduced flashing; held
##   shown while he's in view), magnate_snarl, and red claw marks flash on the floor of that lane where the swipe
##   will land (a floor warning: pickups keep off it; steady with Reduced flashing); he lunges in from behind to
##   slash_strike_behind behind the runner, into the camera's view at the bottom edge;
## - the swipe: his claws come in over the lane (the `slash` pose and three red claw streaks across the lane at the
##   runner's height, magnate_swipe) and an enemy attack over the claw marks (slash_width_share of the lane, up to
##   slash_height: above a jump) is live for slash_hit_seconds (GoldenConvergenceMagnate.set_slash): armor and the
##   shield block it, the dash passes through;
## - `slash:double`: slash_double_gap after the first swipe lands, the second warning locks onto the lane the runner
##   is in then (the one they dodged into), with its own snarl, marks and marker;
## - then he drops back behind the runner (the chase), and the beat is over once he's home.
## Fairness (CLAUDE.md: every attack has an escape): the warning only begins while one of the locked lane's
## neighbours can be switched into for the whole window (escapes(): no Flying Buttress's sides, no hole, no other
## floor warning, no live Lash cable on that stretch); otherwise he holds behind the camera until one can (at most
## WAIT_MAX, then he lets it go: `slash_skipped`).

enum Stage { IDLE, CLOSE, WARN, SWIPE, GAP, RETURN }

## Where he waits to lunge: this far behind the camera (the run camera's view ends about 3.5 m behind the runner).
const CLOSE_BEHIND_CAMERA: float = 1.5
## How long he may hold for a lane to dodge into before he lets the slash go.
const WAIT_MAX: float = 2.0
## How fast he moves across into the locked lane (m/s) while closing in, and while lunging.
const SIDE_SPEED: float = 14.0
const LUNGE_SIDE_SPEED: float = 26.0
## The swipe's pose starts this long before it lands (the claws raised, then swept down as it lands).
const SWIPE_LEAD: float = 0.22
## The claw streaks: how long they show, and how far ahead of the runner they cross the lane (ahead of his head, so
## his body never hides them from the camera behind him).
const STREAK_SECONDS: float = 0.25
const STREAK_AHEAD: float = 0.6
## The enemy attacks' red (the Lash's).
const COLOR := Color(1.0, 0.16, 0.08)
## The second warning of a double: he recoils this far back while it begins, then lunges again.
const RECOIL: float = 1.3

var chase: GoldenConvergenceChase
var magnate: GoldenConvergenceMagnate
var stage: Stage = Stage.IDLE
var stage_time: float = 0.0
## Beats played, swipes landed, swipes warned, slashes let go (no lane to dodge into).
var slashes: int = 0
var swipes: int = 0
var warnings: int = 0
var skipped: int = 0
## The slash under way: {n, double, k (1 or 2: which swipe), t, d0, v, lane (locked; -1 before), escapes, t_warn,
## t_swipe, from, to, rel0, x0, wait}.
var p: Dictionary = {}

var _marks: MeshInstance3D
var _marks_token: Node3D
var _marks_base: Transform3D
var _marks_t: float = 0.0
var _streaks: MeshInstance3D
var _streak_t: float = -1.0
var _streak_base: Transform3D


func _init(p_boss: GoldenConvergence) -> void:
	super(p_boss, &"slash")
	chase = boss.chase
	magnate = boss.magnate


## The claw marks and the swipe's streaks, made now (their sizes are the fight's: its run speed).
func prewarm() -> void:
	if _marks != null:
		return
	var geo: TrackGeometry = boss.world.geo
	var depth: float = stretch()
	_marks = MeshBatch.add_instance(boss, marks_mesh(geo.lane_width * 0.86, depth), "ClawMarks")
	_marks.top_level = true
	_marks.visible = false
	_streaks = MeshBatch.add_instance(boss, streaks_mesh(geo.lane_width), "ClawStreaks")
	_streaks.top_level = true
	_streaks.visible = false


## The swipe's stretch along the track: from slash_behind behind the runner as it lands to slash_ahead past where
## they are when it's over, at the run speed.
func stretch() -> float:
	var t: GoldenConvergenceTuning = boss.tuning
	return t.slash_behind + boss.speed_planned() * t.slash_hit_seconds + t.slash_ahead


## Three claw marks across a lane, `width` wide and `depth` long (its middle at the origin): broad slanted red bars
## raked down the lane in the warnings' red, a faint wash round them. One mesh, two surfaces.
static func marks_mesh(width: float, depth: float) -> ArrayMesh:
	var batch := MeshBatch.new()
	var bars: MeshLayer = batch.layer(GreyboxMaterials.glow(BossProps.WARNING_COLOR, 3.0, 0.92))
	var slant: float = 0.3
	for k: int in 3:
		var x: float = (float(k) - 1.0) * width * 0.3
		var length: float = depth * (0.92 if k == 1 else 0.8)
		var xform := Transform3D(Basis(Vector3.UP, slant) * Basis.from_scale(Vector3(0.3, 0.04, length)), Vector3(x, 0.0, 0.0))
		bars.box_xform(xform, Color.WHITE)
	var wash: MeshLayer = batch.layer(GreyboxMaterials.glow(BossProps.WARNING_COLOR, 1.2, 0.16))
	wash.box(Vector3(0.0, -0.01, 0.0), Vector3(width, 0.02, depth), Color.WHITE)
	return batch.to_mesh()


## His claws coming in: three broad red streaks sweeping down and across a lane `width` wide, wider than it and from
## above his head, so they show round him from the camera behind (its foot at the origin, facing the camera).
static func streaks_mesh(width: float) -> ArrayMesh:
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(GreyboxMaterials.glow(COLOR, 4.4, 1.0))
	var steps: int = 12
	var span: float = width * 0.85
	for k: int in 3:
		var dz: float = (float(k) - 1.0) * 0.5
		var lift: float = (float(k) - 1.0) * 0.28
		var prev := Vector3.ZERO
		for i: int in steps + 1:
			var u: float = float(i) / float(steps)
			# From high on one side, sweeping down and across to low on the other.
			var p := Vector3(lerpf(-span, span, u), 3.0 - 2.6 * u + 0.5 * sin(PI * u) + lift, dz - 0.5 * sin(PI * u))
			if i > 0:
				var along: Vector3 = p - prev
				var thick: float = 0.12 * (0.35 + sin(PI * u))
				var basis := Basis.looking_at(along.normalized(), Vector3.UP if absf(along.normalized().y) < 0.98 else Vector3.BACK)
				s.box_xform(Transform3D(basis * Basis.from_scale(Vector3(thick, thick * 0.6, along.length() + 0.03)), (prev + p) * 0.5),
					Color.WHITE)
			prev = p
	return batch.to_mesh()


func busy() -> bool:
	if stage == Stage.RETURN and chase.home():
		_set_stage(Stage.IDLE)
	return stage != Stage.IDLE


## Its warning shows or the swipe is live.
func warning_on() -> bool:
	return stage == Stage.WARN or stage == Stage.SWIPE


## Starts a Claw Slash (`beat`'s argument "double": twice in a row).
func start(beat: Dictionary) -> void:
	clear()
	prewarm()
	slashes += 1
	var from: Vector3 = magnate.global_position
	var d0: float = boss.player_distance()
	p = {"n": slashes, "double": String(beat.get("arg", "")) == "double", "k": 1, "t": 0.0, "d0": d0,
		"v": boss.speed_planned(), "lane": -1, "rel0": -from.z - d0, "x0": from.x, "wait": 0.0,
		"close": boss.tuning.slash_close_seconds / boss.pace()}
	chase.drive(self)
	_set_stage(Stage.CLOSE)
	boss.log_event(&"slash_start", {"n": slashes, "double": p["double"], "runner": d0})


## Where the runner will be `t` seconds into the slash (planned at the run speed).
func planned(t: float) -> float:
	return float(p["d0"]) + float(p["v"]) * t


func tick(delta: float) -> void:
	_tick_looks(delta)
	if stage == Stage.IDLE or p.is_empty():
		return
	stage_time += delta
	p["t"] = float(p["t"]) + delta
	var t: float = float(p["t"])
	match stage:
		Stage.CLOSE:
			_tick_close(delta, t)
		Stage.WARN:
			_tick_warn(delta, t)
		Stage.SWIPE:
			_tick_swipe(delta, t)
		Stage.GAP:
			_tick_gap(delta, t)


## The marks' pulse and the streaks' life (also while the encounter's intro or the defeat runs: look_tick).
func look_tick(delta: float) -> void:
	_tick_looks(delta)


# --- Closing in, the warning ------------------------------------------------------------------------------

## Where he waits to lunge, relative to the runner: just behind the camera.
func _close_rel() -> float:
	return -(boss.world.tuning.camera_distance + CLOSE_BEHIND_CAMERA)


func _tick_close(delta: float, t: float) -> void:
	var close: float = float(p["close"])
	var u: float = clampf(t / maxf(close, 0.05), 0.0, 1.0)
	var e: float = u * u * (3.0 - 2.0 * u)
	var rel: float = lerpf(float(p["rel0"]), _close_rel(), e)
	var x: float = move_toward(magnate.global_position.x, boss.world.geo.lane_x(boss.player_lane()), SIDE_SPEED * delta)
	var y: float = move_toward(magnate.global_position.y, 0.0, 8.0 * delta)
	magnate.play(&"run")
	chase.place(Vector3(x, y, TrackGeometry.world_z(boss.player_distance() + rel)), 0.0, delta)
	if u < 1.0:
		return
	# In place: warn once a lane beside the runner's is clear to dodge into, or let it go.
	if not _warn():
		p["wait"] = float(p["wait"]) + delta
		if float(p["wait"]) >= WAIT_MAX:
			skipped += 1
			boss.log_event(&"slash_skipped", {"n": int(p["n"]), "lane": boss.player_lane(), "runner": boss.player_distance()})
			_finish()


## The lanes beside `lane` a runner can switch into now and stay in until a swipe from now on is over: none whose
## floor is warned or a hole over the stretch they'd run, none a Flying Buttress's sides block, none a Lash's cable
## lies across.
func escapes(lane: int) -> Array[int]:
	var out: Array[int] = []
	var t: GoldenConvergenceTuning = boss.tuning
	var d: float = boss.player_distance()
	var to: float = d + boss.speed_planned() * (t.slash_warning + t.slash_hit_seconds) + t.slash_ahead + 1.0
	var from: float = d - 1.0
	var lanes: int = boss.lane_count()
	for other: int in [lane - 1, lane + 1]:
		if other < 0 or other >= lanes:
			continue
		if boss.props.warned(other, from, to):
			continue
		if boss.arena != null and boss.arena.hole_between(from, to, other):
			continue
		var blocked: bool = false
		for b: GoldenConvergenceButtress in boss.buttresses:
			var span: Vector2 = b.blocked_span()
			if b.standing() and b.lane == other and span.x <= to and span.y >= from:
				blocked = true
		var cables: Dictionary = boss.lash.live_cables() if boss.lash != null else {}
		if not cables.is_empty() and float(cables["line_at"]) >= from and float(cables["line_at"]) <= to:
			blocked = true
		if not blocked:
			out.append(other)
	return out


## The warning: locks onto the runner's lane if a lane beside it is clear to dodge into (false: not yet).
func _warn() -> bool:
	var lane: int = boss.player_lane()
	var ways: Array[int] = escapes(lane)
	if ways.is_empty():
		return false
	var t: GoldenConvergenceTuning = boss.tuning
	var now: float = float(p["t"])
	p["lane"] = lane
	p["escapes"] = ways
	p["t_warn"] = now
	p["t_swipe"] = now + t.slash_warning
	p["warned_at"] = boss.fight_time()
	# The claw marks: where the runner will be from the swipe's landing to its end, a margin either side.
	var from: float = planned(now + t.slash_warning) - t.slash_behind
	var to: float = from + stretch()
	p["from"] = from
	p["to"] = to
	p["rel_w0"] = -magnate.global_position.z - boss.player_distance()
	warnings += 1
	_show_marks(lane, from, to)
	chase.alarm = 1.0
	chase.alarm_flash = true
	chase.marker_hold = true
	magnate.play(&"run")
	boss.sound(&"magnate_snarl", boss.sound_point(magnate.head_point()))
	boss.hint("slash")
	boss.log_event(&"slash_warned", {"n": int(p["n"]), "k": int(p["k"]), "lane": lane, "escapes": ways,
		"from": from, "to": to, "runner": boss.player_distance(), "runner_lane": boss.player_lane()})
	_set_stage(Stage.WARN)
	return true


## The lunge: from where he waits into the locked lane, to slash_strike_behind behind the runner as the swipe lands
## (a double's second: a recoil first).
func _tick_warn(delta: float, t: float) -> void:
	var tu: GoldenConvergenceTuning = boss.tuning
	var u: float = clampf((t - float(p["t_warn"])) / maxf(tu.slash_warning, 0.05), 0.0, 1.0)
	var rel0: float = float(p["rel_w0"])
	var strike: float = -tu.slash_strike_behind
	var rel: float
	if int(p["k"]) == 2:
		# Recoiling, then lunging again.
		var back: float = strike - RECOIL
		rel = lerpf(rel0, back, minf(u * 2.0, 1.0)) if u < 0.5 else lerpf(back, strike, pow((u - 0.5) * 2.0, 2.0))
	else:
		rel = lerpf(rel0, strike, u * u)
	var lane_x: float = boss.world.geo.lane_x(int(p["lane"]))
	var x: float = move_toward(magnate.global_position.x, lane_x, LUNGE_SIDE_SPEED * delta)
	chase.place(Vector3(x, 0.0, TrackGeometry.world_z(boss.player_distance() + rel)), 0.0, delta)
	if t >= float(p["t_swipe"]) - SWIPE_LEAD:
		magnate.play(&"slash")
	if t >= float(p["t_swipe"]):
		_swipe()


# --- The swipe ------------------------------------------------------------------------------------------------

func _swipe() -> void:
	var tu: GoldenConvergenceTuning = boss.tuning
	var geo: TrackGeometry = boss.world.geo
	var lane: int = int(p["lane"])
	var from: float = float(p["from"])
	var to: float = float(p["to"])
	var w: float = geo.lane_width * tu.slash_width_share
	magnate.set_slash(true, Vector3(geo.lane_x(lane), tu.slash_height * 0.5, TrackGeometry.world_z((from + to) * 0.5)),
		Vector3(w, tu.slash_height, to - from))
	swipes += 1
	_show_streaks(lane)
	boss.world.effects.shake(0.18, 0.2)
	boss.sound(&"magnate_swipe", boss.sound_point(magnate.head_point()))
	boss.log_event(&"slash_swipe", {"n": int(p["n"]), "k": int(p["k"]), "lane": lane, "runner": boss.player_distance(),
		"runner_lane": boss.player_lane()})
	_set_stage(Stage.SWIPE)


func _tick_swipe(delta: float, t: float) -> void:
	var tu: GoldenConvergenceTuning = boss.tuning
	chase.place(Vector3(magnate.global_position.x, 0.0, TrackGeometry.world_z(boss.player_distance() - tu.slash_strike_behind)),
		0.0, delta)
	if t < float(p["t_swipe"]) + tu.slash_hit_seconds:
		return
	magnate.set_slash(false)
	_hide_marks()
	if bool(p["double"]) and int(p["k"]) == 1:
		p["k"] = 2
		_set_stage(Stage.GAP)
		return
	_finish()


## Between a double's swipes: his place behind the runner, then the second warning (locked onto the lane they're in
## now: the one they dodged into).
func _tick_gap(delta: float, t: float) -> void:
	var tu: GoldenConvergenceTuning = boss.tuning
	chase.place(Vector3(magnate.global_position.x, 0.0, TrackGeometry.world_z(boss.player_distance() - tu.slash_strike_behind)),
		0.0, delta)
	magnate.play(&"run")
	if t < float(p["t_swipe"]) + tu.slash_double_gap:
		return
	if not _warn():
		p["wait"] = float(p["wait"]) + delta
		if float(p["wait"]) >= WAIT_MAX:
			skipped += 1
			boss.log_event(&"slash_skipped", {"n": int(p["n"]), "lane": boss.player_lane(), "runner": boss.player_distance()})
			_finish()


## Done: the marker calm, and he drops back behind the runner.
func _finish() -> void:
	magnate.set_slash(false)
	_hide_marks()
	chase.alarm = 0.0
	chase.alarm_flash = false
	chase.marker_hold = false
	_set_stage(Stage.RETURN)
	chase.drop_back(self, 0)
	boss.log_event(&"slash_done", {"n": int(p["n"]), "swipes": swipes})


# --- Its looks -----------------------------------------------------------------------------------------------

func _show_marks(lane: int, from: float, to: float) -> void:
	if _marks == null:
		prewarm()
	_hide_marks()
	_marks_base = Transform3D(Basis.IDENTITY, Vector3(boss.world.geo.lane_x(lane), 0.04, TrackGeometry.world_z((from + to) * 0.5)))
	_marks.transform = _marks_base
	_marks.visible = true
	_marks_t = 0.0
	# A floor warning over the lane's stretch (pickups keep off it; warned() finds it).
	_marks_token = Node3D.new()
	_marks_token.name = "SlashWarning"
	boss.props.add_child(_marks_token)
	boss.props.floor_warning(_marks_token, lane, from, to)


func _hide_marks() -> void:
	if _marks != null:
		_marks.visible = false
	if _marks_token != null and is_instance_valid(_marks_token):
		boss.props.remove(_marks_token)
	_marks_token = null


## The claw marks on the floor now (tests, the bot): {lane, from, to} or {}.
func marks() -> Dictionary:
	if _marks == null or not _marks.visible or p.is_empty() or int(p.get("lane", -1)) < 0:
		return {}
	return {"lane": int(p["lane"]), "from": float(p["from"]), "to": float(p["to"])}


func marks_node() -> MeshInstance3D:
	return _marks


func _show_streaks(lane: int) -> void:
	if _streaks == null:
		return
	var at: float = boss.player_distance()
	_streak_base = Transform3D(Basis.IDENTITY, Vector3(boss.world.geo.lane_x(lane), 0.0, TrackGeometry.world_z(at + STREAK_AHEAD)))
	_streaks.transform = _streak_base
	_streaks.visible = true
	_streak_t = 0.0


func _tick_looks(delta: float) -> void:
	if _marks != null and _marks.visible:
		_marks_t += delta
		# Flashing as it's shown (a beat on its brightness: its size); steady with Reduced flashing.
		var beat: float = 1.0 if Settings.flashing_reduced else 1.0 + 0.09 * signf(sin(_marks_t * 30.0))
		var grow: float = 0.9 + 0.1 * clampf(_marks_t / 0.25, 0.0, 1.0)
		_marks.transform = Transform3D(Basis.from_scale(Vector3(grow * beat, 1.0, grow * beat)), _marks_base.origin)
	if _streak_t >= 0.0 and _streaks != null:
		_streak_t += delta
		var k: float = clampf(_streak_t / STREAK_SECONDS, 0.0, 1.0)
		# Swept in fast, then thinning away (it moves with the runner, where the claws met their lane).
		var s: float = (1.0 - k * 0.6)
		var base: Transform3D = _streak_base
		_streaks.transform = Transform3D(Basis.from_scale(Vector3(1.0, s, 1.0)), Vector3(base.origin.x, 0.0,
			TrackGeometry.world_z(boss.player_distance() + STREAK_AHEAD)))
		if k >= 1.0:
			_streaks.visible = false
			_streak_t = -1.0


func _set_stage(next: Stage) -> void:
	stage = next
	stage_time = 0.0


## Everything at once (a phase's end, the defeat): the swipe, the marks and the streaks gone, the marker calm;
## whoever comes next moves him.
func clear() -> void:
	super()
	if magnate != null:
		magnate.set_slash(false)
	_hide_marks()
	if _streaks != null:
		_streaks.visible = false
	_streak_t = -1.0
	if chase != null:
		chase.alarm = 0.0
		chase.alarm_flash = false
		chase.marker_hold = false
	_set_stage(Stage.IDLE)
	p = {}
