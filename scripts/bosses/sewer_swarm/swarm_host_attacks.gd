class_name SwarmHostAttacks
extends RefCounted
## Phase 3 of the Sewer Swarm, The Host (GDD §10: "the Host bursts out of a big sewer pipe ahead and flings the
## remaining clusters at the player"; "its fused implants, glowing red ... The player reaches them by a ramp
## and a wall jump, Gangland's big new move. Three stomps, each knocking screeches off and revealing more of
## the person. Its lunge can also be baited into a fence"; "Defeat: the Host is freed"; the owner has since
## doubled its hits to six, docs/USER_REQUESTS.md: BossPhase.hits). SewerSwarm runs it;
## SwarmHost is the body it moves. Everything is timed from the runner's distance and the physics step, at the
## arena's spots (SewerSwarm.spots_between, host_spots_between), so every attempt plays the same way:
##
## - ENTRANCE (the phase's intro): the pipe hangs across the street pipe_ahead ahead; when the runner is
##   host_burst_at from it, its middle tears open (host_burst) and the Host drops out onto the street, then
##   leaps to its station.
## - PACE: it keeps host_ahead ahead of the runner in the middle of the street, facing them.
## - FLING (at a hole spot: the hole stays clear, fling_before past where it lands): it rears with a cluster
##   scooped from the swarm (host_fling) and lobs it into the runner's lane; a red circle marks where it lands
##   from the wind-up on. It splats there (an enemy attack, splat_seconds) as the runner would reach it, and
##   scatters. DESIGN-TBD (docs/questions/e4.md, the clusters in phase 3).
## - LUNGE (at a fence spot: lunge_warning_seconds, the surge's lock_seconds and charge_speed): it rears at the
##   roadside where it will land, roaring (host_roar), a red line down the runner's lane from there, following
##   them and ending at a fence on it; at the lock it lands in their lane and charges down it (its attack's
##   hitbox live). Into the fence: shocked, a hit (BossEncounter.damage, cause &"fence"), down in that lane
##   for stun_seconds; otherwise it charges on past the runner and leaps back over them.
## - CROUCH (at a host spot): when the runner is crouch_settle before the spot's ramp, it leaps into the
##   ramp's lane past the ramp and crouches there, long and low (solid, its sides bumping lane switches back),
##   its implants glowing along its back (the weak point: a stomp from above is a hit) and green chevrons on
##   the ramp's wall where to jump (SwarmJumpMarks); a ramp, a wall run and a wall jump bring the runner down
##   on them. Stomped, it shorts an implant and stays down until the runner has passed it; then it rises
##   and leaps back to its station.
## - FREED (the defeat, any of the above): the screeches scatter, the implants short out, the person slumps.
## A spot whose moment passed while it was busy (or before it came) goes by (logged: host_missed). It never
## does two things at once, and every attack is warned (visual and audio) before it can hit.

enum Step { IDLE, ENTRANCE, DROP, LEAP, PACE, FLING, LUNGE, CHARGE, STUNNED, CROUCH, FREED }

const STEP_NAMES: PackedStringArray = ["idle", "entrance", "drop", "leap", "pace", "fling", "lunge", "charge",
	"stunned", "crouch", "freed"]
## How long the Host takes to drop out of the pipe, and to settle into a crouch before its implants go live.
const DROP_SECONDS: float = 0.55
const SETTLE_SECONDS: float = 0.35
## How fast it keeps to its station and its x (m/s), and gathers to where it lands for a lunge.
const PACE_EASE: float = 30.0
## The circle warning's radius (a share of a lane) where a fling lands.
const CIRCLE_SHARE: float = 0.62

var boss: SewerSwarm
var host: SwarmHost
var pipe: SwarmPipe
var marks: SwarmJumpMarks
var step: Step = Step.IDLE
## Seconds in the current step.
var t: float = 0.0
## The spot under way ({} none): a bait spot (a fling or a lunge) or a host spot (a crouch), with its own
## numbers (lane, the landing, the lock, ...).
var event: Dictionary = {}
## Counts, for tests: flings, lunges (and those baited into a fence), crouches (and stomps).
var flings: int = 0
var lunges: int = 0
var shocked: int = 0
var crouches: int = 0
var stomps: int = 0

var _leap: Dictionary = {}
var _ball: SwarmCrowd
var _ball_release: float = -1.0
var _circle: Node3D
var _line: Node3D
var _aim_x: float = 0.0


func _init(p_boss: SewerSwarm, p_host: SwarmHost, p_pipe: SwarmPipe, p_marks: SwarmJumpMarks) -> void:
	boss = p_boss
	host = p_host
	pipe = p_pipe
	marks = p_marks
	# Every contact with its attacks and its body is logged (tests: a hit only through a hitbox, and only when
	# the runner stayed in its way).
	host.lunge_box.contacted.connect(_on_contact.bind("lunge"))
	host.splat_box.contacted.connect(_on_contact.bind("splat"))
	host.body.contacted.connect(_on_contact.bind("body"))


func _on_contact(outcome: int, what: String) -> void:
	boss.log_event(&"host_hit", {"what": what, "outcome": outcome, "d": snappedf(boss.player_distance(), 0.01),
		"lane": boss.player_lane()})


func step_name() -> String:
	return STEP_NAMES[step]


## True while an attack of its warns or strikes (a fling, a lunge).
func busy() -> bool:
	return step in [Step.FLING, Step.LUNGE, Step.CHARGE]


## Phase 3 begins: the pipe ahead, the Host waiting in it.
func begin() -> void:
	var t_: SewerSwarmTuning = boss.tuning
	var d: float = boss.player_distance()
	pipe.place(d + t_.pipe_ahead * boss.run_pace())
	host.stand()
	host.visible = false
	host.at = pipe.at
	host.x = 0.0
	host.lift = t_.pipe_height
	host.crouch = 0.0
	host.place()
	step = Step.ENTRANCE
	t = 0.0
	boss.log_event(&"host_pipe", {"at": snappedf(pipe.at, 0.01)})


## Steps phase 3 on by one physics frame (its intro and its pattern alike).
func tick(delta: float) -> void:
	t += delta
	_tick_ball(delta)
	match step:
		Step.ENTRANCE:
			if boss.player_distance() >= pipe.at - boss.tuning.host_burst_at * boss.run_pace():
				_burst()
		Step.DROP:
			var k: float = clampf(t / DROP_SECONDS, 0.0, 1.0)
			host.lift = boss.tuning.pipe_height * (1.0 - k * k)
			host.rear = 1.0 - k
			if k >= 1.0:
				boss.world.effects.shake(0.35, 0.3)
				_leap_to_station()
		Step.LEAP:
			_tick_leap(delta)
		Step.PACE:
			_pace(delta)
			_look_for_events()
		Step.FLING:
			_tick_fling(delta)
		Step.LUNGE:
			_tick_lunge(delta)
		Step.CHARGE:
			_tick_charge(delta)
		Step.STUNNED:
			host.charge = move_toward(host.charge, 0.0, delta * 3.0)
			if t >= boss.tuning.stun_seconds:
				host.rise()
				_leap_to_station()
		Step.CROUCH:
			_tick_crouch(delta)
		Step.FREED:
			_tick_freed(delta)
	if pipe.visible and boss.player_distance() > pipe.at + 30.0:
		pipe.stow()
	host.place()


## Ends whatever is under way at once (the phase changing): its warnings go.
func clear() -> void:
	_drop_warnings()
	marks.hide_marks()
	host.splat(0.0, 0, false)


## A stomp landed on the crouching Host's implants (before its damage: SewerSwarm._on_weak_point_hit).
func stomped() -> void:
	stomps += 1
	host.knock(true)
	boss.sound(&"host_short", host.aim_point())
	boss.log_event(&"host_stomped", {"n": stomps, "d": snappedf(boss.player_distance(), 0.01)})
	event["stomped"] = true


## The fight is won: the Host is freed wherever it is.
func free_host() -> void:
	_drop_warnings()
	marks.hide_marks()
	host.splat(0.0, 0, false)
	host.free_person()
	host.lift = 0.0
	step = Step.FREED
	t = 0.0
	boss.sound(&"host_short", host.aim_point())
	boss.log_event(&"host_freed", {"at": snappedf(host.at, 0.01), "x": snappedf(host.x, 0.01)})


# --- The entrance and pacing ---------------------------------------------------------------------------

func _burst() -> void:
	pipe.burst()
	host.visible = true
	host.stand()
	host.rear = 1.0
	step = Step.DROP
	t = 0.0
	var mouth: Vector3 = pipe.mouth() + Vector3(0.0, boss.tuning.pipe_height, 0.0)
	boss.sound(&"host_burst", mouth)
	boss.world.effects.burst(mouth, Color(0.38, 0.24, 0.15), 30, 1.4)
	boss.world.effects.burst(mouth, ScreechLair.MIST, 30, 1.2)
	boss.log_event(&"host_burst", {"at": snappedf(pipe.at, 0.01), "d": snappedf(boss.player_distance(), 0.01)})


## Its station: host_ahead ahead of the runner, in the middle of the street.
func station_at() -> float:
	return boss.player_distance() + boss.tuning.host_ahead * boss.run_pace()


func _pace(delta: float) -> void:
	host.at = move_toward(host.at, station_at(), PACE_EASE * delta + boss.run_speed() * delta * 1.2)
	host.x = move_toward(host.x, 0.0, 6.0 * delta)
	host.rear = move_toward(host.rear, 0.0, delta * 2.0)
	host.charge = move_toward(host.charge, 0.0, delta * 2.0)
	host.crouch = move_toward(host.crouch, 0.0, delta * 2.5)
	host.heat = move_toward(host.heat, 0.0, delta * 3.0)


## A leap to `to_at` (a track distance, or its station while `to_station`) and `to_x`, over leap_seconds,
## then `then` (a Callable, or back to pacing).
func _start_leap(to_at: float, to_x: float, to_station: bool, then: Callable = Callable()) -> void:
	host.stand()
	_leap = {"from_at": host.at, "from_x": host.x, "from_lift": host.lift, "to_at": to_at, "to_x": to_x,
		"station": to_station, "then": then, "t": 0.0}
	step = Step.LEAP
	t = 0.0


func _leap_to_station() -> void:
	_start_leap(station_at(), 0.0, true)


func _tick_leap(delta: float) -> void:
	var seconds: float = boss.tuning.leap_seconds
	_leap["t"] = float(_leap["t"]) + delta
	var k: float = clampf(float(_leap["t"]) / seconds, 0.0, 1.0)
	var to_at: float = station_at() if bool(_leap["station"]) else float(_leap["to_at"])
	var e: float = smoothstep(0.0, 1.0, k)
	host.at = lerpf(float(_leap["from_at"]), to_at, e)
	host.x = lerpf(float(_leap["from_x"]), float(_leap["to_x"]), e)
	host.lift = lerpf(float(_leap["from_lift"]), 0.0, k) + 4.0 * boss.tuning.leap_height * k * (1.0 - k)
	host.rear = 0.4 * sin(PI * k)
	host.heat = move_toward(host.heat, 0.0, delta * 3.0)
	if k >= 1.0:
		host.lift = 0.0
		var then: Callable = _leap["then"]
		_leap = {}
		if then.is_valid():
			then.call()
		else:
			step = Step.PACE
			t = 0.0


## The next spot's moment: a crouch at a host spot, a fling at a hole spot, a lunge at a fence spot,
## whichever comes first; spots whose moment passed go by.
func _look_for_events() -> void:
	var d: float = boss.player_distance()
	var k: float = boss.run_pace()
	var tuning: SewerSwarmTuning = boss.tuning
	for h: Dictionary in boss.host_spots_between(d - 60.0 * k, d + SewerSwarm.SIGHT * k):
		if not boss.spot_unused(h):
			continue
		var settle: float = float(h["at"]) - tuning.crouch_settle * k
		if d < settle:
			break
		boss.use_spot(h)
		if d > float(h["at"]) - tuning.crouch_latest * k:
			boss.log_event(&"host_missed", {"kind": "crouch", "at": h["at"]})
			continue
		_start_crouch(h)
		return
	for s: Dictionary in boss.spots_between(d - 60.0 * k, d + SewerSwarm.SIGHT * k):
		if not boss.spot_unused(s):
			continue
		var trigger: float = fling_warn_at(s) if s["kind"] == "hole" else boss.lunge_warn_at(s)
		if d < trigger:
			break
		boss.use_spot(s)
		if d > trigger + boss.run_speed() * (1.5 / 60.0):
			boss.log_event(&"host_missed", {"kind": s["kind"], "at": s["at"]})
			continue
		if s["kind"] == "hole":
			_start_fling(s)
		else:
			_start_lunge(s)
		return


# --- Flings --------------------------------------------------------------------------------------------

## Where a hole spot's fling lands (fling_before before the hole), and where the runner is when its wind-up
## starts.
func fling_land_at(s: Dictionary) -> float:
	return float(s["at"]) - boss.tuning.fling_before * boss.run_pace()


func fling_warn_at(s: Dictionary) -> float:
	var t_: SewerSwarmTuning = boss.tuning
	return fling_land_at(s) - boss.run_speed() * (t_.fling_lead_seconds + t_.fling_windup + t_.fling_flight)


func _start_fling(s: Dictionary) -> void:
	var lane: int = boss.player_lane()
	var land: float = fling_land_at(s)
	flings += 1
	event = {"kind": "fling", "spot": s, "lane": lane, "land": land, "n": flings}
	step = Step.FLING
	t = 0.0
	_circle = boss.props.circle_warning(land, lane, boss.world.geo.lane_width * CIRCLE_SHARE)
	_ball = boss.take_crowd()
	if _ball != null:
		_ball.visible = true
		_ball.set_ball(1.05)
		_ball.set_motion(0.0, 0.0, 0.25, 0.0)
		_ball.set_life(1.0, 0.0, 0, 0.0)
		_ball.show_up_to(1.0)
	boss.sound(&"host_fling", host.aim_point())
	boss.log_event(&"host_fling", {"n": flings, "lane": lane, "land": snappedf(land, 0.01), "spot": s["at"],
		"d": snappedf(boss.player_distance(), 0.01)})


func _tick_fling(delta: float) -> void:
	var t_: SewerSwarmTuning = boss.tuning
	_pace(delta)
	host.rear = minf(host.rear + delta * 3.0, 1.0) if t < t_.fling_windup else move_toward(host.rear, 0.0, delta * 3.0)
	host.heat = host.rear
	var lane: int = int(event["lane"])
	var land: float = float(event["land"])
	var lane_x: float = boss.world.geo.lane_x(lane)
	var hand := Vector3(host.x, host.lift + t_.host_height + 1.0, TrackGeometry.world_z(host.at))
	var target := Vector3(lane_x, 0.9, TrackGeometry.world_z(land))
	if t < t_.fling_windup:
		if _ball != null:
			_ball.global_position = hand
			_ball.set_life(1.0, clampf(t / t_.fling_windup * 1.3, 0.0, 1.0), 0, 0.0)
		return
	var flight: float = t - t_.fling_windup
	if flight < t_.fling_flight:
		if not event.has("thrown"):
			event["thrown"] = true
			event["from"] = hand
		var k: float = flight / t_.fling_flight
		var from: Vector3 = event["from"]
		var p: Vector3 = from.lerp(target, k) + Vector3(0.0, 3.5 * sin(PI * k), 0.0)
		if _ball != null:
			_ball.global_position = p
			_ball.set_life(1.0, 1.0, 0, 0.0)
		return
	var on_ground: float = flight - t_.fling_flight
	if not event.has("landed"):
		event["landed"] = true
		host.splat(land, lane, true)
		boss.sound(&"swarm_scatter", target)
		boss.world.effects.burst(target, ScreechLair.MIST, 24, 1.0)
		boss.log_event(&"host_splat", {"n": event["n"], "lane": lane, "at": snappedf(land, 0.01),
			"d": snappedf(boss.player_distance(), 0.01)})
		if _ball != null:
			# It splats into a short mass across the lane, then scatters.
			_ball.global_position = Vector3(0.0, 0.0, TrackGeometry.world_z(land - t_.splat_length * 0.5))
			_ball.set_formation(0.0, 1, 0.0, lane_x, 0.0, 1.0)
			_ball.set_param(&"mass", Vector4(lane_x, 0.0, t_.splat_length, boss.world.geo.lane_width * 0.8))
			_ball.set_motion(1.0, 0.0, 0.25, 0.0)
	if on_ground >= t_.splat_seconds:
		host.splat(land, lane, false)
		if _ball != null:
			_ball.set_life(1.0, 1.0, 3, 0.0)
			_ball_release = 0.0
		_drop_warnings()
		event = {}
		step = Step.PACE
		t = 0.0


## A flung ball's scatter plays out, then its crowd goes back to the pool.
func _tick_ball(delta: float) -> void:
	if _ball == null or _ball_release < 0.0:
		return
	_ball_release += delta
	_ball.set_life(1.0, 1.0, 3, _ball_release)
	if _ball_release >= 1.2:
		boss.release_crowd(_ball)
		_ball = null
		_ball_release = -1.0


# --- Lunges --------------------------------------------------------------------------------------------

func _start_lunge(s: Dictionary) -> void:
	lunges += 1
	var entry: float = boss.entry_at(s)
	event = {"kind": "lunge", "spot": s, "entry": entry, "strike": boss.strike_at(s), "lane": boss.player_lane(),
		"locked": -1, "fence": {}, "n": lunges}
	step = Step.LUNGE
	t = 0.0
	_aim_x = boss.world.geo.lane_x(int(event["lane"]))
	boss.sound(&"host_roar", host.aim_point())
	boss.log_event(&"host_lunge_warn", {"n": lunges, "lane": event["lane"], "spot": s["at"], "spot_lane": s["lane"],
		"entry": snappedf(entry, 0.01), "d": snappedf(boss.player_distance(), 0.01)})


## The lunge's warning: it gathers where it will land (rearing, roaring), the line follows the runner's lane;
## then the lock.
func _tick_lunge(delta: float) -> void:
	var t_: SewerSwarmTuning = boss.tuning
	var lane: int = boss.player_lane()
	event["lane"] = lane
	var lane_x: float = boss.world.geo.lane_x(lane)
	host.at = move_toward(host.at, float(event["entry"]), 45.0 * delta)
	host.x = move_toward(host.x, lane_x * 0.5, 8.0 * delta)
	host.rear = minf(host.rear + delta * 2.5, 1.0)
	host.heat = host.rear
	_update_aim(delta, lane)
	if t >= t_.lunge_warning_seconds - t_.lock_seconds - 0.0001:
		_lock_lunge()


func _lock_lunge() -> void:
	var lane: int = boss.player_lane()
	var d: float = boss.player_distance()
	var entry: float = float(event["entry"])
	var fence: Dictionary = boss.fence_between(lane, d, entry)
	event["locked"] = lane
	event["fence"] = fence
	_hide_aim()
	_line = boss.props.lane_warning(lane, float(fence["at"]) if not fence.is_empty() else d + 1.0, entry)
	host.at = entry
	host.lunge(boss.world.geo.lane_x(lane))
	host.rear = 0.0
	host.charge = 1.0
	host.heat = 1.0
	step = Step.CHARGE
	t = 0.0
	boss.sound(&"swarm_surge", host.aim_point())
	boss.log_event(&"host_lunge", {"n": event["n"], "lane": lane, "baited": not fence.is_empty(),
		"fence_at": snappedf(float(fence.get("at", 0.0)), 0.01), "entry": snappedf(entry, 0.01), "d": snappedf(d, 0.01)})


## The charge: down the lane at the runner, into the fence (shocked) or on past them.
func _tick_charge(delta: float) -> void:
	var lane: int = int(event["locked"])
	var next: float = host.at - boss.charge_speed() * delta
	var fence: Dictionary = boss.fence_between(lane, next, host.at)
	if not fence.is_empty():
		_shocked(float(fence["at"]), lane)
		return
	host.at = next
	if host.at < boss.player_distance() - boss.tuning.pass_after * boss.run_pace():
		boss.log_event(&"host_lunge_pass", {"n": event["n"], "lane": lane})
		_drop_warnings()
		event = {}
		host.charge = 0.0
		host.heat = 0.0
		_leap_to_station()


## Baited into a live fence: shocked, a hit, and down in its lane past the fence for stun_seconds.
func _shocked(fence_at: float, lane: int) -> void:
	shocked += 1
	_drop_warnings()
	host.heat = 0.0
	host.stunned(boss.world.geo.lane_x(lane), fence_at + 2.4)
	host.knock(false)
	step = Step.STUNNED
	t = 0.0
	boss.sound(&"swarm_shock", host.aim_point())
	boss.world.score.add_bonus(&"swarm_bait", boss.tuning.bait_score, "Shocked!")
	boss.world.effects.shake(0.4, 0.35)
	boss.log_event(&"host_shocked", {"n": event["n"], "lane": lane, "at": snappedf(fence_at, 0.01),
		"d": snappedf(boss.player_distance(), 0.01)})
	event = {}
	# Last: the hit may end the fight (SewerSwarm._on_defeated frees the Host).
	boss.damage(boss.hit_damage(), &"fence")


func _update_aim(delta: float, lane: int) -> void:
	var aim: MeshInstance3D = boss.surges.aim
	var d: float = boss.player_distance()
	var entry: float = float(event["entry"])
	var fence: Dictionary = boss.fence_between(lane, d, entry)
	var from: float = float(fence["at"]) if not fence.is_empty() else d + 1.5
	var x: float = boss.world.geo.lane_x(lane)
	_aim_x = move_toward(_aim_x, x, 25.0 * delta)
	var length: float = maxf(entry - from, 0.1)
	aim.global_transform = Transform3D(Basis.from_scale(Vector3(boss.world.geo.lane_width * SwarmSurges.AIM_WIDTH, 0.04, length)),
		Vector3(_aim_x, SwarmSurges.AIM_Y, TrackGeometry.world_z((from + entry) * 0.5)))
	aim.visible = true


func _hide_aim() -> void:
	boss.surges.aim.visible = false


# --- Crouches ------------------------------------------------------------------------------------------

func _start_crouch(h: Dictionary) -> void:
	crouches += 1
	event = {"kind": "crouch", "spot": h, "n": crouches, "settled": false}
	var lane_x: float = boss.world.geo.lane_x(int(h["lane"]))
	host.crouch_length = float(h["to"]) - float(h["from"])
	_start_leap((float(h["from"]) + float(h["to"])) * 0.5, lane_x, false, _land_crouch)
	boss.log_event(&"host_crouch_leap", {"n": crouches, "side": h["side"], "lane": h["lane"], "ramp": h["at"],
		"d": snappedf(boss.player_distance(), 0.01)})


func _land_crouch() -> void:
	var h: Dictionary = event["spot"]
	host.crouch_at(boss.world.geo.lane_x(int(h["lane"])), float(h["from"]), float(h["to"]))
	marks.show_at(int(h["side"]), float(h["at"]) + 1.0)
	step = Step.CROUCH
	t = 0.0
	boss.sound(&"host_crouch", host.aim_point())
	boss.world.effects.shake(0.3, 0.25)
	boss.log_event(&"host_crouch", {"n": event["n"], "side": h["side"], "lane": h["lane"], "ramp": h["at"],
		"from": snappedf(float(h["from"]), 0.01), "to": snappedf(float(h["to"]), 0.01),
		"d": snappedf(boss.player_distance(), 0.01)})
	boss.hint("host")


func _tick_crouch(delta: float) -> void:
	host.crouch = minf(host.crouch + delta / SETTLE_SECONDS, 1.0)
	host.rear = move_toward(host.rear, 0.0, delta * 3.0)
	host.heat = move_toward(host.heat, 0.0, delta * 3.0)
	var h: Dictionary = event["spot"]
	if not bool(event["settled"]) and t >= SETTLE_SECONDS:
		event["settled"] = true
		host.open()
	if boss.player_distance() > float(h["to"]) + 2.0:
		marks.hide_marks()
		if not bool(event.get("stomped", false)):
			boss.log_event(&"host_crouch_missed", {"n": event["n"]})
		event = {}
		host.rise()
		_leap_to_station()


# --- Freed ---------------------------------------------------------------------------------------------

func _tick_freed(delta: float) -> void:
	host.heat = 0.0
	host.rear = move_toward(host.rear, 0.0, delta * 2.0)
	host.charge = move_toward(host.charge, 0.0, delta * 2.0)
	# Its back stays under a runner still on it until they've run off it.
	if host.pose == SwarmHost.Pose.FREED and host.crouch > 0.5 \
			and boss.player_distance() > host.at + host.crouch_length * 0.5 + 1.0:
		host.surface.position = Vector3(0.0, -50.0, 0.0)


func _drop_warnings() -> void:
	_hide_aim()
	if _circle != null and is_instance_valid(_circle):
		boss.props.remove(_circle)
	_circle = null
	if _line != null and is_instance_valid(_line):
		boss.props.remove(_line)
	_line = null
	# A ball in the air goes; one that has splatted scatters.
	if _ball != null and _ball_release < 0.0:
		if event.has("landed"):
			_ball.set_life(1.0, 1.0, 3, 0.0)
			_ball_release = 0.0
		else:
			boss.release_crowd(_ball)
			_ball = null
