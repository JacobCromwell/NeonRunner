class_name SewerSwarmBot
extends RefCounted
## A runner who plays the Sewer Swarm's fight by what it shows, for tests and reviews
## (tools/showcase/sewer_swarm_showcase.gd). Call step() every physics frame. It only presses the player's
## named actions and reacts `reaction` seconds after a warning starts or locks, like a player:
## - a surge's warning (the red line down its lane, the chitter): with `baits` on it heads for the lane of
##   the fence or the hole on the street ahead (the bait spot's), so the line follows it there; with
##   `baits` off it keeps to its lane;
## - the lock (the cluster lands and charges, the line locks): in the locked lane it gets out of the way:
##   out of the bait's lane to the nearest lane whose floor is clear (`bait_escape` &"switch"), or it stays
##   and jumps the fence or the hole (&"jump"); out of an unbaited surge's lane the same way, unless
##   `dodges` is off (it stands in the surge, to show it hits);
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


func _init(p_boss: SewerSwarm) -> void:
	boss = p_boss


func step() -> void:
	var player: Player = boss.world.player
	if not player.alive or not player.running:
		return
	_read_surge()
	var now: float = boss.fight_time()
	for i: int in range(_pending.size() - 1, -1, -1):
		if now >= float(_pending[i]["at"]):
			_go(int(_pending[i]["lane"]), String(_pending[i]["why"]))
			_pending.remove_at(i)
	if home_lane >= 0 and _target < 0 and _pending.is_empty() and not boss.surges.busy() \
			and player.surface == Player.Surface.FLOOR and player.lane != home_lane:
		_go(home_lane, "home")
	_walk()
	if reads_track:
		_read_track()


## A surge's warning and its lock: where to go, once it reacts.
func _read_surge() -> void:
	var s: SwarmSurges = boss.surges
	if s.surge.is_empty():
		return
	var n: int = int(s.surge["n"])
	var spot: Dictionary = s.surge["spot"]
	var player: Player = boss.world.player
	if not _handled.has("warn%d" % n):
		_handled["warn%d" % n] = true
		if baits:
			_pending.append({"at": boss.fight_time() + reaction, "lane": int(spot["lane"]), "why": "bait"})
	if s.stage == SwarmSurges.Stage.CHARGE and not _handled.has("lock%d" % n):
		_handled["lock%d" % n] = true
		var locked: int = int(s.surge["locked"])
		var mine: int = _target if _target >= 0 else player.lane
		if locked != mine and locked != player.lane:
			return
		var baited: bool = not (s.surge["bait"] as Dictionary).is_empty()
		if baited and bait_escape == &"jump":
			return
		if not baited and not dodges:
			return
		var to: float = float(s.surge["entry"]) + 4.0 * boss.run_pace()
		var e: int = escape_lane(locked, player.distance, to)
		_pending.clear()
		_pending.append({"at": boss.fight_time() + reaction, "lane": e, "why": "out of the bait's lane" if baited else "dodge"})


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
			if ok:
				return e
	return locked + 1 if locked + 1 < n else locked - 1


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
