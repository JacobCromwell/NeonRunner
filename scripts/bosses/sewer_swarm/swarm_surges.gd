class_name SwarmSurges
extends RefCounted
## The Sewer Swarm's surges (GDD §10, phase 1: "a cluster surges down a lane ahead of the player, with a red
## lane line and a rising chitter as the warning"; "the player baits the swarm into attacking, dodges in time,
## and the swarm hits a live electric fence and is shocked ... Baiting a cluster into a hole also works").
## SewerSwarm ticks it in its pattern. One surge at a time, one at every bait spot the runner reaches
## (SewerSwarm.next_spot), all timed from the runner's distance and the physics step:
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
## The lane is the runner's at the lock: a runner who holds a bait's lane until then and gets out of it
## after (or jumps the fence or the hole) baits it; one who leaves it before has the line follow them.
## Everything is logged (SewerSwarm.events: surge_warn, surge_lock, surge_hit, surge_pass, and the encounter's
## cluster_destroyed and sounds) for the tests.

enum Stage { IDLE, WARN, POUR, CHARGE }

const STAGE_NAMES: PackedStringArray = ["idle", "warn", "pour", "charge"]
## The aim line's width (a share of a lane: a little thinner than the locked lane warning's 0.34) and its height.
const AIM_WIDTH: float = 0.28
const AIM_Y: float = 0.03
## How fast (m/s) a gathering cluster makes for where it will pour in, from its station.
const GATHER_SPEED: float = 45.0

var boss: SewerSwarm
var stage: Stage = Stage.IDLE
## The surge under way: {n, spot, cluster, t, lane (the line's lane), entry, strike, locked (lane), bait
## ({kind, at} or {})}; {} while idle.
var surge: Dictionary = {}
## Surges so far, and those baited.
var count: int = 0
var baited: int = 0
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
			_warn(delta)
		Stage.CHARGE:
			_charge(delta)


## Ends whatever surge is under way at once (a phase change, the win): its lines go, its cluster (if it still
## lives) goes back to the line.
func clear() -> void:
	_hide_aim()
	_drop_locked_line()
	if not surge.is_empty():
		var c: SwarmCluster = surge["cluster"]
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
	var spot: Dictionary = boss.next_spot()
	if spot.is_empty() or boss.player_distance() < float(spot["warn_at"]):
		return
	boss.use_spot(spot)
	var cluster: SwarmCluster = boss.next_cluster(boss.side_of_lane(int(spot["lane"])))
	if cluster == null:
		boss.log_event(&"bait_missed", {"at": spot["at"], "lane": spot["lane"], "why": "no cluster"})
		return
	count += 1
	var entry: float = boss.entry_at(spot)
	surge = {"n": count, "spot": spot, "cluster": cluster, "t": 0.0, "lane": boss.player_lane(), "entry": entry,
		"strike": boss.strike_at(spot), "locked": -1, "bait": {}}
	stage = Stage.WARN
	cluster.gather(entry)
	cluster.lane_x = boss.world.geo.lane_x(int(surge["lane"]))
	_aim_x = cluster.lane_x
	boss.sound(&"swarm_chitter", boss.sound_point(cluster.side, entry))
	boss.log_event(&"surge_warn", {"n": count, "cluster": cluster.index, "side": cluster.side, "lane": surge["lane"],
		"spot": spot["at"], "spot_lane": spot["lane"], "kind": spot["kind"], "entry": snappedf(entry, 0.01),
		"strike": snappedf(float(surge["strike"]), 0.01), "d": snappedf(boss.player_distance(), 0.01)})
	boss.hint("bait")
	_update_aim(0.0)


## The warning: the cluster rears and pours, the line follows the runner's lane; then the lock.
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
		"entry": snappedf(entry, 0.01), "d": snappedf(d, 0.01)})


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
		c.at = float(hit["at"])
		c.place()
		baited += 1
		var cause: StringName = &"hole" if hit["kind"] == "hole" else &"fence"
		boss.log_event(&"surge_bait", {"n": surge["n"], "kind": hit["kind"], "at": snappedf(float(hit["at"]), 0.01),
			"lane": lane, "d": snappedf(boss.player_distance(), 0.01)})
		_end("baited")
		# Last: the cluster's defeat may end the phase (SewerSwarm._on_part_defeated), which clears everything.
		c.defeat(cause)
		return
	c.at = next
	c.place()
	if c.at < boss.player_distance() - boss.tuning.pass_after * boss.run_pace():
		boss.log_event(&"surge_pass", {"n": surge["n"], "lane": lane})
		_end("passed")
		boss.requeue(c)


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
## fence or a hole on it (the cluster won't get past that).
func _update_aim(delta: float) -> void:
	var lane: int = int(surge["lane"])
	var entry: float = float(surge["entry"])
	var d: float = boss.player_distance()
	var bait: Dictionary = boss.bait_between(lane, d, entry)
	var from: float = float(bait["at"]) if not bait.is_empty() else d + 1.5
	var x: float = boss.world.geo.lane_x(lane)
	_aim_x = x if delta <= 0.0 else move_toward(_aim_x, x, 25.0 * delta)
	var length: float = maxf(entry - from, 0.1)
	aim.global_transform = Transform3D(Basis.from_scale(Vector3(boss.world.geo.lane_width * AIM_WIDTH, 0.04, length)),
		Vector3(_aim_x, AIM_Y, TrackGeometry.world_z((from + entry) * 0.5)))
	aim.visible = true
	surge["aim_from"] = from


func _hide_aim() -> void:
	if aim != null and _warm_frames <= 0:
		aim.visible = false


func _drop_locked_line() -> void:
	if locked_line != null and is_instance_valid(locked_line):
		boss.props.remove(locked_line)
	locked_line = null
