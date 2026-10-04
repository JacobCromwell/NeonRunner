class_name SwarmSurges
extends RefCounted
## The Sewer Swarm's surges (GDD §10, phase 1: "a cluster surges down a lane ahead of the player, with a red
## lane line and a rising chitter as the warning"; phase 2: "clusters also strike from behind. The warning is
## a chittering sound plus a visible rising wave of the swarm on screen, curling like a breaking wave or a
## scorpion's stinger, about to strike its lane"; "the player baits the swarm into attacking, dodges in time,
## and the swarm hits a live electric fence and is shocked ... Baiting a cluster into a hole also works").
## SewerSwarm ticks it in its pattern. Its surges come at every bait spot the runner reaches
## (SewerSwarm.next_spot), all timed from the runner's distance and the physics step: one from ahead in
## phase 1; in phase 2 (SewerSwarm.surge_mode, SewerSwarmTuning.surge_sides) a strike from behind and a surge
## from ahead at once (owner's request, docs/USER_REQUESTS.md), each with its own warning, line and hitbox,
## their charges overlapping in two different lanes so every other lane is clear.
##
## From ahead (phases 1 and 2):
## - WARN (warning_seconds before the strike, when the runner reaches the spot's warn_at): the nearest
##   cluster on the bait's side gathers at the roadside where it will pour in (entry_at), rearing, its spines
##   up; its chitter rises (swarm_chitter); a red line runs down the runner's lane from it toward the runner,
##   following them from lane to lane (the aim line) and ending at a fence or a hole on it
##   (SewerSwarm.bait_between: it won't get past that).
## - POUR (pour_seconds before the lock): it pours out of the roadside toward the line's lane.
## - CHARGE (lock_seconds before the strike): it lands in the runner's lane (player_lane: a wall runner's
##   outer lane) and charges down it at charge_speed; the line locks (BossProps.lane_warning, the standard red
##   lane warning, from the bait or the runner to where it landed) and its rush plays (swarm_surge). Its
##   hitbox is live. It runs into the first live full fence or hole on its way (baited: shocked or falling,
##   destroyed), or passes the runner and scatters out of sight (SewerSwarm.requeue).
## From behind (phase 2):
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
## Both at once (phase 2): the wave warns first (its warning is the longer and it strikes further back,
## behind_strike_before), the surge ahead while it holds; the wave crashes just before the surge ahead locks,
## and both charge at once, in two different lanes.
## The surge ahead lands in the runner's lane, unless the wave is locked there (the runner hasn't left it
## yet): then in the nearest other lane that leaves a lane beside the wave's free, not the bait's if it can
## (its line shows which as it warns). So the two never charge down the same lane, and a runner in an outer
## lane beside the wave's has a way out still: into the wave's lane once it has surged on past them.
## The lane is the runner's at the lock: a runner who holds a bait's lane until then and gets out of it
## after (or jumps the fence or the hole, or the crash) baits it; one who leaves it before has the line
## follow them.
## DESIGN-TBD (docs/OPEN_QUESTIONS.md 324; docs/questions/e4.md, 1): how a cluster is baited, and its
## strikes from behind.
## Everything is logged (SewerSwarm.events: surge_warn, surge_lock, surge_crash, surge_hit, surge_pass,
## surge_bait, surge_end, and the encounter's cluster_destroyed and sounds) for the tests.

enum Stage { IDLE, WARN, POUR, CHARGE }

const STAGE_NAMES: PackedStringArray = ["idle", "warn", "pour", "charge"]
## The aim line's width (a share of a lane: a little thinner than the locked lane warning's 0.34) and its height.
const AIM_WIDTH: float = 0.28
const AIM_Y: float = 0.03
## How fast (m/s) a gathering cluster makes for where it will pour in, from its station.
const GATHER_SPEED: float = 60.0
## A wave's crash into the lane takes this long (the look; its hitbox is live from its start).
const CRASH_SECONDS: float = 0.3
## Surges under way at once at most (phase 2: a strike from behind and a surge ahead).
const MOST: int = 2

var boss: SewerSwarm
## The surges under way, the first begun first: {n, spot, cluster, behind, t, stage, lane (the line's lane),
## entry, strike, locked (lane), bait ({kind, at} or {}), aim (its aim line), aim_x, aim_from, line (its
## locked lane warning, or null), hit (its hitbox's listener while it charges)}.
var active: Array[Dictionary] = []
## The first surge under way ({} while idle), its stage, and its locked lane warning.
var surge: Dictionary:
	get:
		return active[0] if not active.is_empty() else {}
var stage: Stage:
	get:
		return active[0]["stage"] if not active.is_empty() else Stage.IDLE
var locked_line: Node3D:
	get:
		for s: Dictionary in active:
			if s["line"] != null:
				return s["line"]
		return null
## Surges so far, those baited, those from behind, and the bait spots whose two came at once.
var count: int = 0
var baited: int = 0
var from_behind: int = 0
var pairs: int = 0
## The aim lines (one for each surge under way, reused); `aim` is the first (the Host's lunge draws with it).
var aims: Array[MeshInstance3D] = []
var aim: MeshInstance3D

## Frames the aim lines are still drawn tiny at the fight's start (warming their material).
var _warm_frames: int = 0
## A bait spot's second surge, due once the runner reaches its warning point: {spot, behind, warn_at}, or {}.
var _due: Dictionary = {}


func _init(p_boss: SewerSwarm) -> void:
	boss = p_boss
	var d: float = boss.player_distance()
	for i: int in MOST:
		var line := MeshInstance3D.new()
		line.name = "SurgeAim" if i == 0 else "SurgeAim%d" % (i + 1)
		line.mesh = GreyboxMaterials.unit_box()
		# The lane warning's own material (BossProps.lane_warning): drawn from the fight's first frame on, tiny,
		# so the renderer has it ready before the first lock (no hitch then).
		line.material_override = GreyboxMaterials.glow(BossProps.WARNING_COLOR, 2.6, 0.75)
		line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		line.top_level = true
		boss.add_child(line)
		line.global_transform = Transform3D(Basis.from_scale(Vector3(0.02, 0.002, 0.02)),
			Vector3(boss.world.geo.lane_x(boss.player_lane()), 0.01, TrackGeometry.world_z(d + 4.0 + i)))
		line.visible = true
		aims.append(line)
	aim = aims[0]
	_warm_frames = 3


## True while a surge warns or strikes.
func busy() -> bool:
	return not active.is_empty()


func stage_name() -> String:
	return STAGE_NAMES[stage]


## True while the first surge under way comes from behind.
func is_behind() -> bool:
	return not active.is_empty() and bool(active[0]["behind"])


## The surge under way numbered `n` ({} if it's over).
func surge_of(n: int) -> Dictionary:
	for s: Dictionary in active:
		if int(s["n"]) == n:
			return s
	return {}


## Steps the surges on by one physics frame.
func tick(delta: float) -> void:
	if _warm_frames > 0:
		_warm_frames -= 1
		if _warm_frames == 0:
			for line: MeshInstance3D in aims:
				if not _aim_used(line):
					line.visible = false
	_try_start()
	var numbers: Array[int] = []
	for s: Dictionary in active:
		numbers.append(int(s["n"]))
	# Each looked up again: one's end (a baited cluster's defeat ending the phase) may have cleared the others.
	for n: int in numbers:
		var s: Dictionary = surge_of(n)
		if s.is_empty():
			continue
		match int(s["stage"]):
			Stage.WARN, Stage.POUR:
				if bool(s["behind"]):
					_warn_behind(s, delta)
				else:
					_warn(s, delta)
			Stage.CHARGE:
				if bool(s["behind"]):
					_charge_behind(s, delta)
				else:
					_charge(s, delta)


## Ends whatever surges are under way at once (a phase change, the win): their lines go, their clusters (if
## they still live) go back to the line.
func clear() -> void:
	_due = {}
	var was: Array[Dictionary] = active.duplicate()
	active.clear()
	for s: Dictionary in was:
		_let_go(s)
		var c: SwarmCluster = s["cluster"]
		if is_instance_valid(c) and c.alive and c.surging():
			boss.requeue(c)


## A cluster was destroyed (weapons thinned it to nothing, or the fight was won): if it was surging, its surge
## ends now, its lines with it. (A baited one's surge has ended already.)
func cluster_destroyed(cluster: SwarmCluster) -> void:
	for s: Dictionary in active.duplicate():
		if s["cluster"] == cluster:
			_end(s, "destroyed")


func _try_start() -> void:
	var d: float = boss.player_distance()
	if not _due.is_empty():
		if d >= float(_due["warn_at"]):
			var due: Dictionary = _due
			_due = {}
			_begin(due["spot"], bool(due["behind"]))
		return
	if not active.is_empty():
		return
	var spot: Dictionary = boss.next_spot(boss.surge_mode())
	if spot.is_empty() or d < float(spot["warn_at"]):
		return
	boss.use_spot(spot)
	boss.note_spot()
	var sides: Array = spot["sides"]
	if sides.size() > 1:
		pairs += 1
	_begin(spot, bool(sides[0]))
	for i: int in range(1, sides.size()):
		var behind: bool = bool(sides[i])
		var at: float = boss.warn_at(spot, behind)
		if d >= at:
			_begin(spot, behind)
		else:
			_due = {"spot": spot, "behind": behind, "warn_at": at}


## A surge's warning begins at `spot` (from behind, or from ahead), if a cluster is waiting to make it.
func _begin(spot: Dictionary, behind: bool) -> bool:
	var cluster: SwarmCluster = boss.next_cluster(0 if behind else boss.side_of_lane(int(spot["lane"])))
	if cluster == null:
		boss.log_event(&"bait_missed", {"at": spot["at"], "lane": spot["lane"], "why": "no cluster", "behind": behind})
		return false
	count += 1
	boss.note_surge()
	var d: float = boss.player_distance()
	var lane: int = boss.player_lane() if behind else _front_lane(spot)
	var entry: float = boss.entry_at(spot) if not behind else d
	var s: Dictionary = {"n": count, "spot": spot, "cluster": cluster, "behind": behind, "t": 0.0, "stage": Stage.WARN,
		"lane": lane, "entry": entry, "strike": boss.strike_at(spot, behind), "locked": -1, "bait": {},
		"aim": _free_aim(), "aim_x": 0.0, "aim_from": 0.0, "line": null, "hit": Callable()}
	active.append(s)
	if behind:
		from_behind += 1
		cluster.wave(d - boss.tuning.wave_back, boss.world.geo.lane_x(lane))
		s["aim_x"] = cluster.lane_x
		boss.sound(&"swarm_wave", Vector3(cluster.lane_x, 3.0, TrackGeometry.world_z(d - 2.0)))
	else:
		cluster.gather(entry)
		cluster.lane_x = boss.world.geo.lane_x(lane)
		s["aim_x"] = cluster.lane_x
		boss.sound(&"swarm_chitter", boss.sound_point(cluster.side, entry))
	boss.log_event(&"surge_warn", {"n": count, "cluster": cluster.index, "side": cluster.side, "lane": lane,
		"spot": spot["at"], "spot_lane": spot["lane"], "kind": spot["kind"], "behind": behind,
		"pair": (spot["sides"] as Array).size() > 1, "entry": snappedf(entry, 0.01),
		"strike": snappedf(float(s["strike"]), 0.01), "d": snappedf(d, 0.01)})
	boss.hint("behind" if behind else "bait")
	_update_aim(s, 0.0)
	return true


## The lane a surge from ahead lands in: the runner's, unless a strike from behind is locked in it (both at
## once, the runner still in the wave's lane): then the nearest other lane that leaves one beside the wave's
## free for the runner, not the bait's if it can (the bait is the runner's to use, not a gift).
func _front_lane(spot: Dictionary) -> int:
	var p: int = boss.player_lane()
	var held: int = -1
	for s: Dictionary in active:
		if bool(s["behind"]) and int(s["locked"]) >= 0:
			held = int(s["locked"])
	var n: int = boss.lane_count()
	if held < 0 or p != held or n < 2:
		return p
	var best: int = -1
	var best_score: int = 0
	for lane: int in n:
		if lane == held:
			continue
		var score: int = absi(lane - p)
		if lane == int(spot["lane"]):
			score += 10
		var free_beside: bool = (held - 1 >= 0 and held - 1 != lane) or (held + 1 < n and held + 1 != lane)
		if not free_beside:
			score += 100
		if best < 0 or score < best_score:
			best = lane
			best_score = score
	return best


## The warning from ahead: the cluster rears and pours, the line follows the runner's lane; then the lock.
func _warn(s: Dictionary, delta: float) -> void:
	var c: SwarmCluster = s["cluster"]
	if not is_instance_valid(c) or not c.alive:
		_end(s, "destroyed")
		return
	var t: SewerSwarmTuning = boss.tuning
	s["t"] = float(s["t"]) + delta
	var now: float = float(s["t"])
	var lock_t: float = t.warning_seconds - t.lock_seconds
	var pour_t: float = lock_t - t.pour_seconds
	s["lane"] = _front_lane(s["spot"])
	# It holds where it will pour in (from the next station along, if it's the bait's side's).
	c.at = move_toward(c.at, float(s["entry"]), GATHER_SPEED * delta)
	c.rear = minf(c.rear + delta * 2.5, 1.0)
	c.bristle = minf(c.bristle + delta * 2.0, 1.0)
	if now >= pour_t and int(s["stage"]) == Stage.WARN:
		s["stage"] = Stage.POUR
		c.stage = SwarmCluster.Stage.POUR
	if int(s["stage"]) == Stage.POUR:
		c.pour = clampf((now - pour_t) / maxf(t.pour_seconds, 0.01), 0.0, 1.0)
		c.lane_x = move_toward(c.lane_x, boss.world.geo.lane_x(int(s["lane"])), 30.0 * delta)
	_update_aim(s, delta)
	if now >= lock_t - 0.0001:
		_lock(s)


func _lock(s: Dictionary) -> void:
	var c: SwarmCluster = s["cluster"]
	var lane: int = _front_lane(s["spot"])
	var entry: float = float(s["entry"])
	var d: float = boss.player_distance()
	var bait: Dictionary = boss.bait_between(lane, d, entry)
	s["locked"] = lane
	s["lane"] = lane
	s["bait"] = bait
	s["stage"] = Stage.CHARGE
	c.at = entry
	c.charge(lane, boss.charge_speed())
	s["hit"] = _on_hit.bind(int(s["n"]))
	c.hitbox.contacted.connect(s["hit"])
	_hide_aim(s)
	var from: float = float(bait["at"]) if not bait.is_empty() else d + 1.0
	s["line"] = boss.props.lane_warning(lane, from, entry)
	boss.sound(&"swarm_surge", boss.sound_point(c.side, entry))
	boss.log_event(&"surge_lock", {"n": s["n"], "lane": lane, "baited": not bait.is_empty(),
		"bait": bait.get("kind", ""), "bait_at": snappedf(float(bait.get("at", 0.0)), 0.01),
		"entry": snappedf(entry, 0.01), "d": snappedf(d, 0.01), "behind": false})


## The charge: down the lane toward the runner, into the first fence or hole on its way, or past them.
func _charge(s: Dictionary, delta: float) -> void:
	var c: SwarmCluster = s["cluster"]
	if not is_instance_valid(c) or not c.alive:
		_end(s, "destroyed")
		return
	s["t"] = float(s["t"]) + delta
	var lane: int = int(s["locked"])
	var next: float = c.at - c.charge_speed * delta
	var hit: Dictionary = boss.bait_between(lane, next, c.at)
	if not hit.is_empty():
		_baited(s, c, hit, lane)
		return
	c.at = next
	c.place()
	if c.at < boss.player_distance() - boss.tuning.pass_after * boss.run_pace():
		boss.log_event(&"surge_pass", {"n": s["n"], "lane": lane})
		_end(s, "passed")
		boss.requeue(c)


## The warning from behind: the wave rises behind the runner, following their lane until the lock, then holds
## over it, its lip rearing; at the strike it crashes.
func _warn_behind(s: Dictionary, delta: float) -> void:
	var c: SwarmCluster = s["cluster"]
	if not is_instance_valid(c) or not c.alive:
		_end(s, "destroyed")
		return
	var t: SewerSwarmTuning = boss.tuning
	s["t"] = float(s["t"]) + delta
	var now: float = float(s["t"])
	var lock_t: float = t.behind_warning_seconds - t.behind_lock_seconds
	var d: float = boss.player_distance()
	c.at = d - t.wave_back
	c.wave_at = c.at
	c.rise = clampf(now / maxf(lock_t * 0.8, 0.05), 0.0, 1.0)
	c.bristle = minf(c.bristle + delta * 1.6, 1.0)
	if int(s["stage"]) == Stage.WARN:
		s["lane"] = boss.player_lane()
		c.lane_x = move_toward(c.lane_x, boss.world.geo.lane_x(int(s["lane"])), 25.0 * delta)
		_update_aim(s, delta)
		if now >= lock_t - 0.0001:
			_lock_behind(s)
	else:
		c.rear = minf(c.rear + delta / maxf(t.behind_lock_seconds, 0.05), 1.0)
		c.lane_x = move_toward(c.lane_x, boss.world.geo.lane_x(int(s["locked"])), 25.0 * delta)
		if d >= float(s["strike"]) - 0.0001:
			_crash(s)
	c.place()


func _lock_behind(s: Dictionary) -> void:
	var lane: int = boss.player_lane()
	var d: float = boss.player_distance()
	var reach: float = boss.behind_reach(s["spot"])
	var bait: Dictionary = boss.bait_ahead(lane, float(s["strike"]), reach)
	s["locked"] = lane
	s["lane"] = lane
	s["bait"] = bait
	s["stage"] = Stage.POUR
	_hide_aim(s)
	s["line"] = boss.props.lane_warning(lane, d - 1.0, float(bait["at"]) if not bait.is_empty() else reach)
	boss.log_event(&"surge_lock", {"n": s["n"], "lane": lane, "baited": not bait.is_empty(),
		"bait": bait.get("kind", ""), "bait_at": snappedf(float(bait.get("at", 0.0)), 0.01),
		"entry": snappedf(float(s["strike"]), 0.01), "d": snappedf(d, 0.01), "behind": true})


## The strike from behind: the wave crashes down onto the locked lane around the runner and surges on.
func _crash(s: Dictionary) -> void:
	var c: SwarmCluster = s["cluster"]
	var lane: int = int(s["locked"])
	var d: float = boss.player_distance()
	s["stage"] = Stage.CHARGE
	c.at = d + maxf(boss.tuning.wave_reach - boss.tuning.wave_back, 1.0)
	c.charge(lane, boss.tuning.behind_charge_speed * boss.run_pace(), true)
	s["hit"] = _on_hit.bind(int(s["n"]))
	c.hitbox.contacted.connect(s["hit"])
	boss.sound(&"swarm_surge", Vector3(c.lane_x, 1.0, TrackGeometry.world_z(d)))
	boss.log_event(&"surge_crash", {"n": s["n"], "lane": lane, "front": snappedf(c.at, 0.01), "d": snappedf(d, 0.01)})


## The surge from behind: on along the lane, faster than the runner, into the first fence or hole ahead, or on
## past them and back into the gutter.
func _charge_behind(s: Dictionary, delta: float) -> void:
	var c: SwarmCluster = s["cluster"]
	if not is_instance_valid(c) or not c.alive:
		_end(s, "destroyed")
		return
	s["t"] = float(s["t"]) + delta
	c.pour = minf(c.pour + delta / CRASH_SECONDS, 1.0)
	c.rear = move_toward(c.rear, 0.0, delta * 3.0)
	var lane: int = int(s["locked"])
	var next: float = c.at + c.charge_speed * delta
	var hit: Dictionary = boss.bait_ahead(lane, c.at, next)
	if not hit.is_empty():
		_baited(s, c, hit, lane)
		return
	c.at = next
	c.place()
	if c.at > boss.behind_reach(s["spot"]) and c.at > boss.player_distance() + 6.0 * boss.run_pace():
		boss.log_event(&"surge_pass", {"n": s["n"], "lane": lane})
		_end(s, "passed")
		boss.requeue(c)


## A charging cluster met a live fence or a hole (`hit`: {kind, at}): it's destroyed there.
func _baited(s: Dictionary, c: SwarmCluster, hit: Dictionary, lane: int) -> void:
	c.at = float(hit["at"])
	c.pour = 1.0
	c.place()
	baited += 1
	var cause: StringName = &"hole" if hit["kind"] == "hole" else &"fence"
	boss.log_event(&"surge_bait", {"n": s["n"], "kind": hit["kind"], "at": snappedf(float(hit["at"]), 0.01),
		"lane": lane, "d": snappedf(boss.player_distance(), 0.01), "behind": bool(s["behind"])})
	_end(s, "baited")
	# Last: the cluster's defeat may end the phase (SewerSwarm._on_part_defeated), which clears everything.
	c.defeat(cause)


func _on_hit(outcome: int, n: int) -> void:
	boss.log_event(&"surge_hit", {"n": n, "outcome": outcome, "d": snappedf(boss.player_distance(), 0.01),
		"lane": boss.player_lane()})


func _end(s: Dictionary, why: String) -> void:
	var i: int = active.find(s)
	if i < 0:
		return
	active.remove_at(i)
	_let_go(s)
	boss.log_event(&"surge_end", {"n": s["n"], "why": why})


## A surge's aim line, locked line and hitbox listener let go of.
func _let_go(s: Dictionary) -> void:
	_hide_aim(s)
	var line: Node3D = s["line"]
	if line != null and is_instance_valid(line):
		boss.props.remove(line)
	s["line"] = null
	var c: SwarmCluster = s["cluster"]
	var call: Callable = s["hit"]
	if is_instance_valid(c) and call.is_valid() and c.hitbox.contacted.is_connected(call):
		c.hitbox.contacted.disconnect(call)
	s["hit"] = Callable()


## The aim line: down the runner's lane from where the cluster will land toward the runner, ending at a
## fence or a hole on it (the cluster won't get past that); from behind, from the runner on down the lane
## ahead to the first fence or hole on it (or behind_run_on on).
func _update_aim(s: Dictionary, delta: float) -> void:
	var line: MeshInstance3D = s["aim"]
	if line == null:
		return
	var lane: int = int(s["lane"])
	var d: float = boss.player_distance()
	var from: float
	var to: float
	if bool(s["behind"]):
		to = boss.behind_reach(s["spot"])
		var bait: Dictionary = boss.bait_ahead(lane, maxf(float(s["strike"]), d), to)
		from = d - 1.0
		if not bait.is_empty():
			to = float(bait["at"])
	else:
		to = float(s["entry"])
		var bait: Dictionary = boss.bait_between(lane, d, to)
		from = float(bait["at"]) if not bait.is_empty() else d + 1.5
	var x: float = boss.world.geo.lane_x(lane)
	s["aim_x"] = x if delta <= 0.0 else move_toward(float(s["aim_x"]), x, 25.0 * delta)
	var length: float = maxf(to - from, 0.1)
	line.global_transform = Transform3D(Basis.from_scale(Vector3(boss.world.geo.lane_width * AIM_WIDTH, 0.04, length)),
		Vector3(float(s["aim_x"]), AIM_Y, TrackGeometry.world_z((from + to) * 0.5)))
	line.visible = true
	s["aim_from"] = from


func _hide_aim(s: Dictionary) -> void:
	var line: MeshInstance3D = s["aim"]
	if line != null and _warm_frames <= 0:
		line.visible = false


## An aim line no surge under way draws.
func _free_aim() -> MeshInstance3D:
	for line: MeshInstance3D in aims:
		if not _aim_used(line):
			return line
	return null


func _aim_used(line: MeshInstance3D) -> bool:
	for s: Dictionary in active:
		if s["aim"] == line:
			return true
	return false
