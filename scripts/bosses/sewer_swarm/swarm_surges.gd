class_name SwarmSurges
extends RefCounted
## The Sewer Swarm's surges (GDD §10, phase 1: "a cluster surges down a lane ahead of the player, with a red
## lane line and a rising chitter as the warning"; phase 2: "clusters also strike from behind. The warning is
## a chittering sound plus a visible rising wave of the swarm on screen, curling like a breaking wave or a
## scorpion's stinger, about to strike its lane"; "the player baits the swarm into attacking, dodges in time,
## and the swarm hits a live electric fence and is shocked ... Baiting a cluster into a hole also works").
## SewerSwarm ticks it in its pattern. One surge at a time, one at every bait spot the runner reaches
## (SewerSwarm.next_spot), all timed from the runner's distance and the physics step.
##
## From ahead (phases 1 and 2):
## - WARN (warning_seconds before the strike, when the runner reaches the spot's warn_at): the nearest
##   cluster gathers at the roadside where it will pour in (entry_at), rearing, its spines up; its chitter
##   rises (swarm_chitter); a red line runs down the runner's lane from it toward the runner, following them
##   from lane to lane (the aim line) and ending at a fence or a hole on it (SewerSwarm.bait_between: it
##   won't get past that).
## - POUR (pour_seconds before the lock): it pours out of the roadside toward the line's lane.
## - CHARGE (lock_seconds before the strike): it lands in the runner's lane (player_lane: a wall runner's
##   outer lane) and charges down it at charge_speed; the line locks (BossProps.lane_warning, the standard red
##   lane warning, from the bait or the runner to where it landed) and its rush plays (swarm_surge). Its
##   hitbox is live. It runs into the first live full fence or hole on its way (baited: shocked or falling,
##   destroyed), or passes the runner and scatters out of sight (SewerSwarm.requeue).
## From behind (phase 2, SewerSwarm.surge_from_behind):
## - WARN (behind_warning_seconds before the strike): a cluster leaves its station and rises as a wave behind
##   the runner in their lane (SwarmCluster.wave), following them from lane to lane, its crest curling over
##   them into view (the wave's foot wave_back behind them); its chitter rises (swarm_wave); the red line runs
##   down the lane ahead of the runner to the first fence or hole on it (SewerSwarm.bait_ahead).
## - LOCK (behind_lock_seconds before the strike): the line locks in the runner's lane, and the wave holds
##   over it, its lip rearing.
## - CRASH (the strike, when the runner reaches its strike point): the wave crashes down onto the lane around
##   them (swarm_surge; its hitbox live) and surges on along the lane at behind_charge_speed, faster than the
##   runner, into the first fence or hole ahead (baited) or on behind_run_on past them, back into the gutter
##   (SewerSwarm.requeue).
## The lane is the runner's at the lock: a runner who holds a bait's lane until then and gets out of it
## after (or jumps the fence or the hole, or the crash) baits it; one who leaves it before has the line
## follow them.
## DESIGN-TBD (docs/OPEN_QUESTIONS.md 324; docs/questions/e4.md, 1): how a cluster is baited, and its
## strikes from behind.
## Everything is logged (SewerSwarm.events: surge_warn, surge_lock, surge_hit, surge_pass, surge_bait,
## surge_end, and the encounter's cluster_destroyed and sounds) for the tests.

enum Stage { IDLE, WARN, POUR, CHARGE }

const STAGE_NAMES: PackedStringArray = ["idle", "warn", "pour", "charge"]
## The aim line's width (a share of a lane: a little thinner than the locked lane warning's 0.34) and its height.
const AIM_WIDTH: float = 0.28
const AIM_Y: float = 0.03
## How fast (m/s) a gathering cluster makes for where it will pour in, from its station.
const GATHER_SPEED: float = 45.0
## A wave's crash into the lane takes this long (the look; its hitbox is live from its start).
const CRASH_SECONDS: float = 0.3

var boss: SewerSwarm
var stage: Stage = Stage.IDLE
## The surge under way: {n, spot, cluster, behind, t, lane (the line's lane), entry, strike, locked (lane),
## bait ({kind, at} or {})}; {} while idle.
var surge: Dictionary = {}
## Surges so far, those baited, and those from behind.
var count: int = 0
var baited: int = 0
var from_behind: int = 0
## The aim line (one node, reused), and the locked lane warning while a cluster charges.
var aim: MeshInstance3D
var locked_line: Node3D

var _aim_x: float = 0.0
## Frames the aim line is still drawn tiny at the fight's start (warming its material).
var _warm_frames: int = 0
## The surge's hitbox listener, while its cluster charges.
var _on_hit_call: Callable = Callable()


func _init(p_boss: SewerSwarm) -> void:
	boss = p_boss
	aim = MeshInstance3D.new()
	aim.name = "SurgeAim"
	aim.mesh = GreyboxMaterials.unit_box()
	# The lane warning's own material (BossProps.lane_warning): drawn from the fight's first frame on, tiny,
	# so the renderer has it ready before the first lock (no hitch then).
	aim.material_override = GreyboxMaterials.glow(BossProps.WARNING_COLOR, 2.6, 0.75)
	aim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	aim.top_level = true
	boss.add_child(aim)
	var d: float = boss.player_distance()
	aim.global_transform = Transform3D(Basis.from_scale(Vector3(0.02, 0.002, 0.02)),
		Vector3(boss.world.geo.lane_x(boss.player_lane()), 0.01, TrackGeometry.world_z(d + 4.0)))
	aim.visible = true
	_warm_frames = 3


## True while a surge warns or strikes.
func busy() -> bool:
	return stage != Stage.IDLE


func stage_name() -> String:
	return STAGE_NAMES[stage]


## True while the surge under way comes from behind.
func is_behind() -> bool:
	return not surge.is_empty() and bool(surge["behind"])


## Steps the surges on by one physics frame.
func tick(delta: float) -> void:
	if _warm_frames > 0:
		_warm_frames -= 1
		if _warm_frames == 0 and stage == Stage.IDLE:
			aim.visible = false
	match stage:
		Stage.IDLE:
			_try_start()
		Stage.WARN, Stage.POUR:
			if is_behind():
				_warn_behind(delta)
			else:
				_warn(delta)
		Stage.CHARGE:
			if is_behind():
				_charge_behind(delta)
			else:
				_charge(delta)


## Ends whatever surge is under way at once (a phase change, the win): its lines go, its cluster (if it still
## lives) goes back to the line.
func clear() -> void:
	_hide_aim()
	_drop_locked_line()
	if not surge.is_empty():
		var c: SwarmCluster = surge["cluster"]
		if is_instance_valid(c) and _on_hit_call.is_valid() and c.hitbox.contacted.is_connected(_on_hit_call):
			c.hitbox.contacted.disconnect(_on_hit_call)
		_on_hit_call = Callable()
		if is_instance_valid(c) and c.alive and c.surging():
			boss.requeue(c)
	surge = {}
	stage = Stage.IDLE


## A cluster was destroyed (weapons thinned it to nothing, or the fight was won): if it was surging, its surge
## ends now, its lines with it. (A baited one's surge has ended already.)
func cluster_destroyed(cluster: SwarmCluster) -> void:
	if not surge.is_empty() and surge["cluster"] == cluster:
		_end("destroyed")


func _try_start() -> void:
	var behind: bool = boss.surge_from_behind()
	var spot: Dictionary = boss.next_spot(behind)
	if spot.is_empty() or boss.player_distance() < float(spot["warn_at"]):
		return
	boss.use_spot(spot)
	var cluster: SwarmCluster = boss.next_cluster(0 if behind else boss.side_of_lane(int(spot["lane"])))
	if cluster == null:
		boss.log_event(&"bait_missed", {"at": spot["at"], "lane": spot["lane"], "why": "no cluster"})
		return
	count += 1
	boss.note_surge()
	var d: float = boss.player_distance()
	var lane: int = boss.player_lane()
	var entry: float = boss.entry_at(spot) if not behind else d
	surge = {"n": count, "spot": spot, "cluster": cluster, "behind": behind, "t": 0.0, "lane": lane,
		"entry": entry, "strike": boss.strike_at(spot, behind), "locked": -1, "bait": {}}
	stage = Stage.WARN
	if behind:
		from_behind += 1
		cluster.wave(d - boss.tuning.wave_back, boss.world.geo.lane_x(lane))
		_aim_x = cluster.lane_x
		boss.sound(&"swarm_wave", Vector3(cluster.lane_x, 3.0, TrackGeometry.world_z(d - 2.0)))
	else:
		cluster.gather(entry)
		cluster.lane_x = boss.world.geo.lane_x(lane)
		_aim_x = cluster.lane_x
		boss.sound(&"swarm_chitter", boss.sound_point(cluster.side, entry))
	boss.log_event(&"surge_warn", {"n": count, "cluster": cluster.index, "side": cluster.side, "lane": lane,
		"spot": spot["at"], "spot_lane": spot["lane"], "kind": spot["kind"], "behind": behind,
		"entry": snappedf(entry, 0.01), "strike": snappedf(float(surge["strike"]), 0.01), "d": snappedf(d, 0.01)})
	boss.hint("behind" if behind else "bait")
	_update_aim(0.0)


## The warning from ahead: the cluster rears and pours, the line follows the runner's lane; then the lock.
func _warn(delta: float) -> void:
	var c: SwarmCluster = surge["cluster"]
	if not is_instance_valid(c) or not c.alive:
		_end("destroyed")
		return
	var t: SewerSwarmTuning = boss.tuning
	surge["t"] = float(surge["t"]) + delta
	var now: float = float(surge["t"])
	var lock_t: float = t.warning_seconds - t.lock_seconds
	var pour_t: float = lock_t - t.pour_seconds
	surge["lane"] = boss.player_lane()
	# It holds where it will pour in (from the next station along, if it's the bait's side's).
	c.at = move_toward(c.at, float(surge["entry"]), GATHER_SPEED * delta)
	c.rear = minf(c.rear + delta * 2.5, 1.0)
	c.bristle = minf(c.bristle + delta * 2.0, 1.0)
	if now >= pour_t and stage == Stage.WARN:
		stage = Stage.POUR
		c.stage = SwarmCluster.Stage.POUR
	if stage == Stage.POUR:
		c.pour = clampf((now - pour_t) / maxf(t.pour_seconds, 0.01), 0.0, 1.0)
		c.lane_x = move_toward(c.lane_x, boss.world.geo.lane_x(int(surge["lane"])), 30.0 * delta)
	_update_aim(delta)
	if now >= lock_t - 0.0001:
		_lock()


func _lock() -> void:
	var c: SwarmCluster = surge["cluster"]
	var lane: int = boss.player_lane()
	var entry: float = float(surge["entry"])
	var d: float = boss.player_distance()
	var bait: Dictionary = boss.bait_between(lane, d, entry)
	surge["locked"] = lane
	surge["lane"] = lane
	surge["bait"] = bait
	stage = Stage.CHARGE
	c.at = entry
	c.charge(lane, boss.charge_speed())
	_on_hit_call = _on_hit.bind(int(surge["n"]))
	c.hitbox.contacted.connect(_on_hit_call)
	_hide_aim()
	var from: float = float(bait["at"]) if not bait.is_empty() else d + 1.0
	locked_line = boss.props.lane_warning(lane, from, entry)
	boss.sound(&"swarm_surge", boss.sound_point(c.side, entry))
	boss.log_event(&"surge_lock", {"n": surge["n"], "lane": lane, "baited": not bait.is_empty(),
		"bait": bait.get("kind", ""), "bait_at": snappedf(float(bait.get("at", 0.0)), 0.01),
		"entry": snappedf(entry, 0.01), "d": snappedf(d, 0.01), "behind": false})


## The charge: down the lane toward the runner, into the first fence or hole on its way, or past them.
func _charge(delta: float) -> void:
	var c: SwarmCluster = surge["cluster"]
	if not is_instance_valid(c) or not c.alive:
		_end("destroyed")
		return
	surge["t"] = float(surge["t"]) + delta
	var lane: int = int(surge["locked"])
	var next: float = c.at - c.charge_speed * delta
	var hit: Dictionary = boss.bait_between(lane, next, c.at)
	if not hit.is_empty():
		_baited(c, hit, lane)
		return
	c.at = next
	c.place()
	if c.at < boss.player_distance() - boss.tuning.pass_after * boss.run_pace():
		boss.log_event(&"surge_pass", {"n": surge["n"], "lane": lane})
		_end("passed")
		boss.requeue(c)


## The warning from behind: the wave rises behind the runner, following their lane until the lock, then holds
## over it, its lip rearing; at the strike it crashes.
func _warn_behind(delta: float) -> void:
	var c: SwarmCluster = surge["cluster"]
	if not is_instance_valid(c) or not c.alive:
		_end("destroyed")
		return
	var t: SewerSwarmTuning = boss.tuning
	surge["t"] = float(surge["t"]) + delta
	var now: float = float(surge["t"])
	var lock_t: float = t.behind_warning_seconds - t.behind_lock_seconds
	var d: float = boss.player_distance()
	c.at = d - t.wave_back
	c.wave_at = c.at
	c.rise = clampf(now / maxf(lock_t * 0.8, 0.05), 0.0, 1.0)
	c.bristle = minf(c.bristle + delta * 1.6, 1.0)
	if stage == Stage.WARN:
		surge["lane"] = boss.player_lane()
		c.lane_x = move_toward(c.lane_x, boss.world.geo.lane_x(int(surge["lane"])), 25.0 * delta)
		_update_aim(delta)
		if now >= lock_t - 0.0001:
			_lock_behind()
	else:
		c.rear = minf(c.rear + delta / maxf(t.behind_lock_seconds, 0.05), 1.0)
		c.lane_x = move_toward(c.lane_x, boss.world.geo.lane_x(int(surge["locked"])), 25.0 * delta)
		if d >= float(surge["strike"]) - 0.0001:
			_crash()
	c.place()


func _lock_behind() -> void:
	var lane: int = boss.player_lane()
	var d: float = boss.player_distance()
	var reach: float = boss.behind_reach(surge["spot"])
	var bait: Dictionary = boss.bait_ahead(lane, float(surge["strike"]), reach)
	surge["locked"] = lane
	surge["lane"] = lane
	surge["bait"] = bait
	stage = Stage.POUR
	_hide_aim()
	locked_line = boss.props.lane_warning(lane, d - 1.0, float(bait["at"]) if not bait.is_empty() else reach)
	boss.log_event(&"surge_lock", {"n": surge["n"], "lane": lane, "baited": not bait.is_empty(),
		"bait": bait.get("kind", ""), "bait_at": snappedf(float(bait.get("at", 0.0)), 0.01),
		"entry": snappedf(float(surge["strike"]), 0.01), "d": snappedf(d, 0.01), "behind": true})


## The strike from behind: the wave crashes down onto the locked lane around the runner and surges on.
func _crash() -> void:
	var c: SwarmCluster = surge["cluster"]
	var lane: int = int(surge["locked"])
	var d: float = boss.player_distance()
	stage = Stage.CHARGE
	c.at = d + maxf(boss.tuning.wave_reach - boss.tuning.wave_back, 1.0)
	c.charge(lane, boss.tuning.behind_charge_speed * boss.run_pace(), true)
	_on_hit_call = _on_hit.bind(int(surge["n"]))
	c.hitbox.contacted.connect(_on_hit_call)
	boss.sound(&"swarm_surge", Vector3(c.lane_x, 1.0, TrackGeometry.world_z(d)))
	boss.log_event(&"surge_crash", {"n": surge["n"], "lane": lane, "front": snappedf(c.at, 0.01), "d": snappedf(d, 0.01)})


## The surge from behind: on along the lane, faster than the runner, into the first fence or hole ahead, or on
## past them and back into the gutter.
func _charge_behind(delta: float) -> void:
	var c: SwarmCluster = surge["cluster"]
	if not is_instance_valid(c) or not c.alive:
		_end("destroyed")
		return
	surge["t"] = float(surge["t"]) + delta
	c.pour = minf(c.pour + delta / CRASH_SECONDS, 1.0)
	c.rear = move_toward(c.rear, 0.0, delta * 3.0)
	var lane: int = int(surge["locked"])
	var next: float = c.at + c.charge_speed * delta
	var hit: Dictionary = boss.bait_ahead(lane, c.at, next)
	if not hit.is_empty():
		_baited(c, hit, lane)
		return
	c.at = next
	c.place()
	if c.at > boss.behind_reach(surge["spot"]) and c.at > boss.player_distance() + 6.0 * boss.run_pace():
		boss.log_event(&"surge_pass", {"n": surge["n"], "lane": lane})
		_end("passed")
		boss.requeue(c)


## A charging cluster met a live fence or a hole (`hit`: {kind, at}): it's destroyed there.
func _baited(c: SwarmCluster, hit: Dictionary, lane: int) -> void:
	c.at = float(hit["at"])
	c.pour = 1.0
	c.place()
	baited += 1
	var cause: StringName = &"hole" if hit["kind"] == "hole" else &"fence"
	boss.log_event(&"surge_bait", {"n": surge["n"], "kind": hit["kind"], "at": snappedf(float(hit["at"]), 0.01),
		"lane": lane, "d": snappedf(boss.player_distance(), 0.01), "behind": is_behind()})
	_end("baited")
	# Last: the cluster's defeat may end the phase (SewerSwarm._on_part_defeated), which clears everything.
	c.defeat(cause)


func _on_hit(outcome: int, n: int) -> void:
	boss.log_event(&"surge_hit", {"n": n, "outcome": outcome, "d": snappedf(boss.player_distance(), 0.01),
		"lane": boss.player_lane()})


func _end(why: String) -> void:
	_hide_aim()
	_drop_locked_line()
	if not surge.is_empty():
		var c: SwarmCluster = surge["cluster"]
		if is_instance_valid(c) and _on_hit_call.is_valid() and c.hitbox.contacted.is_connected(_on_hit_call):
			c.hitbox.contacted.disconnect(_on_hit_call)
		_on_hit_call = Callable()
		boss.log_event(&"surge_end", {"n": surge["n"], "why": why})
	surge = {}
	stage = Stage.IDLE


## The aim line: down the runner's lane from where the cluster will land toward the runner, ending at a
## fence or a hole on it (the cluster won't get past that); from behind, from the runner on down the lane
## ahead to the first fence or hole on it (or behind_run_on on).
func _update_aim(delta: float) -> void:
	var lane: int = int(surge["lane"])
	var d: float = boss.player_distance()
	var from: float
	var to: float
	if is_behind():
		to = boss.behind_reach(surge["spot"])
		var bait: Dictionary = boss.bait_ahead(lane, maxf(float(surge["strike"]), d), to)
		from = d - 1.0
		if not bait.is_empty():
			to = float(bait["at"])
	else:
		to = float(surge["entry"])
		var bait: Dictionary = boss.bait_between(lane, d, to)
		from = float(bait["at"]) if not bait.is_empty() else d + 1.5
	var x: float = boss.world.geo.lane_x(lane)
	_aim_x = x if delta <= 0.0 else move_toward(_aim_x, x, 25.0 * delta)
	var length: float = maxf(to - from, 0.1)
	aim.global_transform = Transform3D(Basis.from_scale(Vector3(boss.world.geo.lane_width * AIM_WIDTH, 0.04, length)),
		Vector3(_aim_x, AIM_Y, TrackGeometry.world_z((from + to) * 0.5)))
	aim.visible = true
	surge["aim_from"] = from


func _hide_aim() -> void:
	if aim != null and _warm_frames <= 0:
		aim.visible = false


func _drop_locked_line() -> void:
	if locked_line != null and is_instance_valid(locked_line):
		boss.props.remove(locked_line)
	locked_line = null
