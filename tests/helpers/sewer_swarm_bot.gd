class_name SewerSwarmBot
extends RefCounted
## A runner who plays the Sewer Swarm's fight by what it shows, for tests and reviews
## (tools/showcase/sewer_swarm_showcase.gd). Call step() every physics frame. It only presses the player's
## named actions and reacts `reaction` seconds after a warning starts or locks, like a player:
## - a surge's warning (the red line down its lane, the chitter; from behind, the wave): with `baits` on it
##   heads for the lane of the fence or the hole on the street ahead (the bait spot's), so the line follows
##   it there; with `baits` off it keeps to its lane;
## - the lock (the cluster lands and charges; from behind, the wave locks over the lane): in the locked lane
##   it gets out of the way: out of the bait's lane to the nearest lane whose floor is clear (`bait_escape`
##   &"switch"), or (a surge from ahead) it stays and jumps the fence or the hole (&"jump"); out of an
##   unbaited surge's lane the same way, unless `dodges` is off (it stands in the surge, to show it hits);
## - the Host (phase 3): a fling's red circle in its lane, it leaves the lane; a lunge it baits like a surge
##   (into the fence spot's lane while it warns, `baits`) and dodges at the lock; a crouch (its implants
##   glowing by a ramp, `stomps` on): into the ramp's lane, up the ramp onto the wall, and a wall jump
##   `jump_after` past the ramp (the green chevrons' window) down onto the implants; with `stomps` off it
##   keeps out of the ramp's lane;
## - otherwise it runs the arena like any runner (`reads_track`): it jumps the holes and full fences in its
##   lane and slides under gapped ones.

## Reading the track (as SleepTakerBot): a hole is jumped this far before its edge, a full fence this far
## before it, no later than FENCE_JUMP_LAST before it; a gapped fence slid under from this far. Metres at
## 18 m/s, multiplied by the run's pace.
const HOLE_LEAD: float = 1.6
const FENCE_JUMP_LEAD: float = 6.2
const FENCE_JUMP_LAST: float = 3.6
const FENCE_SLIDE_LEAD: float = 3.5

var boss: SewerSwarm
var baits: bool = true
var bait_escape: StringName = &"switch"
var dodges: bool = true
var reads_track: bool = true
## The Host's crouches: take the ramp and wall-jump onto its implants (off: keep out of the ramp's lane).
var stomps: bool = true
## The wall jump comes this far past the ramp's start (metres at 18 m/s, at the run's pace): in the green
## chevrons' window.
var jump_after: float = 6.0
## Seconds from a warning's start (or its lock) to its move.
var reaction: float = 0.35
## The lane it keeps to while nothing threatens it (-1: wherever it is).
var home_lane: int = -1
## What it did, for tests: {t (fight time), action, why}.
var log: Array[Dictionary] = []

var _handled: Dictionary = {}
var _target: int = -1
var _why: String = ""
## Moves decided but waiting for its reaction: {at (fight time), lane, why}.
var _pending: Array[Dictionary] = []
## The crouch it's taking (a host spot), {} none.
var _route: Dictionary = {}


func _init(p_boss: SewerSwarm) -> void:
	boss = p_boss


func step() -> void:
	var player: Player = boss.world.player
	if not player.alive or not player.running:
		return
	_read_surge()
	_read_host()
	var now: float = boss.fight_time()
	for i: int in range(_pending.size() - 1, -1, -1):
		if now >= float(_pending[i]["at"]):
			_go(int(_pending[i]["lane"]), String(_pending[i]["why"]))
			_pending.remove_at(i)
	if home_lane >= 0 and _target < 0 and _pending.is_empty() and not boss.warning_active() and _route.is_empty() \
			and player.surface == Player.Surface.FLOOR and player.lane != home_lane:
		_go(home_lane, "home")
	_walk()
	if reads_track:
		_read_track()


## A surge's warning and its lock: where to go, once it reacts.
func _read_surge() -> void:
	var s: SwarmSurges = boss.surges
	if s == null or s.surge.is_empty():
		return
	var n: int = int(s.surge["n"])
	var spot: Dictionary = s.surge["spot"]
	var behind: bool = bool(s.surge["behind"])
	if not _handled.has("warn%d" % n):
		_handled["warn%d" % n] = true
		if baits:
			_pending.append({"at": boss.fight_time() + reaction, "lane": int(spot["lane"]), "why": "bait"})
	if int(s.surge["locked"]) >= 0 and not _handled.has("lock%d" % n):
		_handled["lock%d" % n] = true
		var baited: bool = not (s.surge["bait"] as Dictionary).is_empty()
		var to: float = float(s.surge["entry"]) + 4.0 * boss.run_pace()
		if behind:
			to = float(s.surge["strike"]) + 6.0 * boss.run_pace()
		_dodge(int(s.surge["locked"]), baited, not behind, to)


## Out of `locked` lane (a surge or a lunge that locked there), once it reacts: to the nearest lane whose floor
## is clear up to `to`; a baited one from ahead may be jumped instead (bait_escape &"jump").
func _dodge(locked: int, baited: bool, can_jump: bool, to: float) -> void:
	var player: Player = boss.world.player
	var mine: int = _target if _target >= 0 else player.lane
	if locked != mine and locked != player.lane:
		return
	if baited and can_jump and bait_escape == &"jump":
		return
	if not baited and not dodges:
		return
	var e: int = escape_lane(locked, player.distance, to)
	_pending.clear()
	_pending.append({"at": boss.fight_time() + reaction, "lane": e, "why": "out of the bait's lane" if baited else "dodge"})


## The Host's attacks and crouches (phase 3).
func _read_host() -> void:
	var h: SwarmHostAttacks = boss.host_attacks
	if h == null or h.event.is_empty():
		if h != null and not _route.is_empty() and h.step != SwarmHostAttacks.Step.CROUCH:
			_route = {}
		_wall_jump()
		return
	var e: Dictionary = h.event
	var n: int = int(e.get("n", 0))
	match String(e["kind"]):
		"fling":
			if not _handled.has("fling%d" % n):
				_handled["fling%d" % n] = true
				var lane: int = int(e["lane"])
				var player: Player = boss.world.player
				if (lane == player.lane or lane == _target) and dodges:
					var land: float = float(e["land"])
					var k: float = boss.run_pace()
					_pending.clear()
					_pending.append({"at": boss.fight_time() + reaction, "lane": escape_lane(lane, land - 6.0 * k, land + 6.0 * k),
						"why": "fling"})
		"lunge":
			if not _handled.has("lunge%d" % n):
				_handled["lunge%d" % n] = true
				if baits:
					_pending.append({"at": boss.fight_time() + reaction, "lane": int((e["spot"] as Dictionary)["lane"]), "why": "bait"})
			if int(e["locked"]) >= 0 and not _handled.has("lunge_lock%d" % n):
				_handled["lunge_lock%d" % n] = true
				_dodge(int(e["locked"]), not (e["fence"] as Dictionary).is_empty(), false, float(e["entry"]) + 4.0 * boss.run_pace())
		"crouch":
			var spot: Dictionary = e["spot"]
			if not _handled.has("crouch%d" % n):
				_handled["crouch%d" % n] = true
				_pending.clear()
				if stomps:
					_route = spot
					_go(int(spot["lane"]), "ramp")
				else:
					var lane: int = int(spot["lane"])
					var player: Player = boss.world.player
					if player.lane == lane or _target == lane:
						_go(lane + (1 if lane == 0 else -1), "off the ramp")
	_wall_jump()


## On the ramp's wall: the wall jump, jump_after past the ramp.
func _wall_jump() -> void:
	if _route.is_empty():
		return
	var player: Player = boss.world.player
	if player.surface == Player.Surface.WALL and player.distance >= float(_route["at"]) + jump_after * boss.run_pace() \
			and not _handled.has("jumped%s" % str(_route["key"])):
		_handled["jumped%s" % str(_route["key"])] = true
		_press(&"jump", "wall jump")


## The nearest lane other than `locked` whose floor (and that of every lane on the way) is clear of holes and
## fences from `from` to `to`; the nearest other lane if none is.
func escape_lane(locked: int, from: float, to: float) -> int:
	var n: int = boss.lane_count()
	for dist: int in range(1, n):
		for sgn: int in [-1, 1]:
			var e: int = locked + sgn * dist
			if e < 0 or e >= n:
				continue
			var ok: bool = true
			for l: int in range(mini(locked, e), maxi(locked, e) + 1):
				if l != locked and not boss.arena.floor_clear(from, to, l):
					ok = false
			if ok and not _host_in(e, from, to):
				return e
	return locked + 1 if locked + 1 < n else locked - 1


## True if the crouching Host lies in `lane` between two track distances.
func _host_in(lane: int, from: float, to: float) -> bool:
	var host: SwarmHost = boss.host
	if host == null or host.pose != SwarmHost.Pose.CROUCH:
		return false
	var h0: float = host.at - host.crouch_length * 0.5
	var h1: float = host.at + host.crouch_length * 0.5
	return is_equal_approx(boss.world.geo.lane_x(lane), host.x) and h0 <= to and h1 >= from


## The arena's own holes and fences in the lane it runs in (or is moving to), read like any runner.
func _read_track() -> void:
	var player: Player = boss.world.player
	if boss.arena == null or player.surface != Player.Surface.FLOOR or not player.grounded:
		return
	var d: float = player.distance
	var k: float = boss.run_pace()
	var lanes: Array[int] = [player.lane]
	if _target >= 0 and _target != player.lane:
		lanes.append(_target)
	var layout: LevelLayout = boss.arena.layout
	var can_jump: bool = not player.is_sliding()
	for f: Dictionary in layout.fences:
		if lanes.has(int(f["lane"])) and f["variant"] == "gapped" and absf(float(f["at"]) - d - 0.5 * k) <= 1.5 * k:
			can_jump = false
	for g: Dictionary in layout.gaps:
		var ahead: float = float(g["start"]) - d
		if lanes.has(int(g["lane"])) and ahead > -0.2 and ahead <= HOLE_LEAD * k:
			if can_jump:
				_press(&"jump", "hole")
			return
	for f: Dictionary in layout.fences:
		if not lanes.has(int(f["lane"])) or f.get("disabled", false):
			continue
		var ahead: float = float(f["at"]) - d
		if f["variant"] == "gapped":
			if ahead > 0.0 and ahead <= FENCE_SLIDE_LEAD * k and not player.is_sliding():
				_press(&"slide", "gapped fence")
				return
		elif ahead > FENCE_JUMP_LAST * k and ahead <= FENCE_JUMP_LEAD * k:
			if can_jump:
				_press(&"jump", "fence")
			return


func _go(lane: int, why: String) -> void:
	_target = clampi(lane, 0, boss.lane_count() - 1)
	_why = why


## One lane a frame toward the lane it's heading for.
func _walk() -> void:
	var player: Player = boss.world.player
	if _target < 0 or player.surface != Player.Surface.FLOOR:
		return
	if player.lane == _target:
		_target = -1
		return
	_press(&"move_right" if _target > player.lane else &"move_left", _why)


func _press(action: StringName, why: String) -> void:
	boss.world.player.press(action)
	log.append({"t": boss.fight_time(), "action": action, "why": why})
