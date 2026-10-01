class_name SleepTakerBot
extends RefCounted
## A runner who plays the Sleep Taker's fight by its warnings, for tests and reviews
## (tools/showcase/sleep_taker_showcase.gd). Call step() every physics frame. It only presses the
## player's named actions, only reacts to what the fight shows, and reacts `reaction` seconds after a
## warning starts, like a player:
## - the giant slash's warning (the lanes it lights red, the shriek): if it's in those lanes, it heads
##   for the refuge's nearest pad lane (`slash_escape` &"pad"), or for the nearest lane outside the slash
##   whose floor is clear (&"lanes"; the pad when there's none), or stays put (&"none", to show the
##   slash hits);
## - a hand's mist in its lane: it switches to the lane the fight keeps free (SleepTaker.escape_lane),
##   unless `dodges_hands` is off;
## - a generator in sight (SleepTakerLure): with `smashes` on, it heads for the generator's lane and
##   stomps it (jumping so it comes down on its top) or, with `dashes` on, dashes into it; with
##   `smashes` off it keeps out of its lane (a runner who lets every generator go by);
## - otherwise it keeps to `home_lane` (if set) and, with `reads_track` on, runs the arena like any
##   runner: it jumps the holes and full fences in its lane and slides under gapped ones.
## On the ceiling it rides it out.

## Reading the track (as FloatingHeadBot): a hole is jumped this far before its edge, a full fence this
## far before it, no later than FENCE_JUMP_LAST before it; a gapped fence slid under from this far.
## Metres at 18 m/s: it multiplies them by the run's pace (MovementTuning.pace()), like the game's own
## distances that stand for a time.
const HOLE_LEAD: float = 1.6
const FENCE_JUMP_LEAD: float = 6.2
const FENCE_JUMP_LAST: float = 3.6
const FENCE_SLIDE_LEAD: float = 3.5

var boss: SleepTaker
var slash_escape: StringName = &"pad"
var dodges_hands: bool = true
## Seconds from a warning's start to its first move.
var reaction: float = 0.3
## The lane it keeps to while nothing threatens it (-1: wherever it is).
var home_lane: int = -1
var reads_track: bool = true
## Goes for each generator (stomps it, or dashes into it with `dashes`), or keeps out of its lane; it
## lets the first `skips` generators go by either way.
var smashes: bool = true
var dashes: bool = false
var skips: int = 0
## What it did, for tests: {t (fight time), action, why}.
var log: Array[Dictionary] = []

var _handled: Dictionary = {}
var _target: int = -1
var _why: String = ""
## Moves decided but waiting for its reaction: {at (fight time), lane, why}.
var _pending: Array[Dictionary] = []
## Until this fight time it holds its dodge (it doesn't walk home).
var _hold_until: float = -1.0
## The generator it's going for (the lure's count when it saw it), and whether it has jumped for it.
var _gen_seen: int = 0
var _gen_jumped: int = 0


func _init(p_boss: SleepTaker, p_escape: StringName = &"pad") -> void:
	boss = p_boss
	slash_escape = p_escape


func step() -> void:
	var player: Player = boss.world.player
	if not player.alive or not player.running:
		return
	_read_slash()
	if dodges_hands:
		_read_hands()
	var now: float = boss.fight_time()
	for i: int in range(_pending.size() - 1, -1, -1):
		if now >= float(_pending[i]["at"]):
			_go(int(_pending[i]["lane"]), String(_pending[i]["why"]))
			_hold_until = maxf(_hold_until, now + 2.5)
			_pending.remove_at(i)
	var gen_lane: int = _read_generator()
	if gen_lane >= 0 and _target < 0 and _pending.is_empty() and player.surface == Player.Surface.FLOOR \
			and not boss.slash.warning_on() and not _mist_in(gen_lane):
		if player.lane != gen_lane:
			_go(gen_lane, "generator" if smashes else "around a generator")
	elif home_lane >= 0 and _target < 0 and _pending.is_empty() and now > _hold_until \
			and player.surface == Player.Surface.FLOOR and not boss.slash.warning_on() and not boss.hands.busy():
		if player.lane != home_lane:
			_go(home_lane, "home")
	_walk()
	_smash()
	if reads_track:
		_read_track()


## The lane it wants for the generator in sight: its own (to smash it), or the nearest other whose floor
## is clear past it (to let it go by); -1 for none.
func _read_generator() -> int:
	var lure: SleepTakerLure = boss.lure
	if lure == null or lure.generator == null or not is_instance_valid(lure.generator) or not lure.generator.alive:
		return -1
	if lure.stage != SleepTakerLure.Stage.WAITING and not lure.luring():
		return -1
	var lane: int = int(lure.site["lane"])
	var at: float = float(lure.site["at"])
	if lure.count != _gen_seen:
		_gen_seen = lure.count
		log.append({"t": boss.fight_time(), "action": &"sees", "why": "generator in lane %d at %.0f m" % [lane, at]})
	if _goes_for(lure):
		return lane if _gen_jumped != lure.count else -1
	var d: float = boss.world.player.distance
	return _free_lane([lane], lane, d, at + 10.0) if at - d < 40.0 * boss.run_pace() else -1


## In the generator's lane as it nears: a jump timed to come down on its top (a stomp), or the dash.
func _smash() -> void:
	var lure: SleepTakerLure = boss.lure
	var player: Player = boss.world.player
	if lure == null or not _goes_for(lure) or lure.generator == null or not is_instance_valid(lure.generator) \
			or not lure.generator.alive or _gen_jumped == lure.count:
		return
	if player.surface != Player.Surface.FLOOR or player.lane != int(lure.site["lane"]):
		return
	var ahead: float = float(lure.site["at"]) - player.distance
	if dashes:
		if ahead <= 2.0 * boss.run_pace():
			_gen_jumped = lure.count
			_press(&"dash", "generator")
		return
	if player.grounded and ahead <= stomp_lead():
		_gen_jumped = lure.count
		if ahead >= stomp_lead() - 1.0 * boss.run_pace():
			_press(&"jump", "stomp the generator")
		else:
			# Too late to come down on it: out of its lane instead.
			var lane: int = int(lure.site["lane"])
			_go(_free_lane([lane], lane, player.distance, float(lure.site["at"]) + 10.0), "too late for the generator")


## True if it goes for the lure's generator now (smashes on, and past the ones it lets go by).
func _goes_for(lure: SleepTakerLure) -> bool:
	return smashes and lure.count > skips


## How far before a generator to jump so the runner comes down on its top: the time up to the jump's
## top and back down to the generator's top, at the run speed.
func stomp_lead() -> float:
	var t: MovementTuning = boss.world.tuning
	var top: float = FenceGenerator.TOP_Y
	var t_down: float = sqrt(2.0 * maxf(t.jump_height - top, 0.0) / (t.gravity() * t.fall_gravity_multiplier))
	return boss.speed() * (t.jump_time_to_apex + t_down)


## True if a hand's mist (or hand) is in `lane` ahead.
func _mist_in(lane: int) -> bool:
	for h: Dictionary in boss.hands.active:
		if int(h["lane"]) == lane and int(h["stage"]) != SleepTakerHands.Stage.SINK:
			return true
	return false


## The slash's warning: where to go, once it reacts.
func _read_slash() -> void:
	var s: SleepTakerSlash = boss.slash
	if not s.warning_on() or s.attack.is_empty():
		return
	var id: String = "slash%d" % int(s.attack["n"])
	if _handled.has(id):
		return
	_handled[id] = true
	var lanes: Array[int] = s.lanes()
	var pl: int = boss.player_lane()
	if slash_escape == &"none" or not lanes.has(pl) or boss.world.player.surface == Player.Surface.CEILING:
		return
	var to: int = -1
	if slash_escape == &"lanes":
		to = _free_lane(lanes, pl, float(s.attack["at"]), float(s.attack["strike_at"]) + 3.0)
	if to < 0 and float(s.attack["refuge"]) >= 0.0:
		to = _nearest(SleepTaker.pad_lanes(boss.lane_count(), boss.tuning), pl)
	if to >= 0:
		_pending.append({"at": boss.fight_time() + reaction, "lane": to, "why": "slash"})


## A hand's mist in its lane: out of it, once it reacts.
func _read_hands() -> void:
	var player: Player = boss.world.player
	for h: Dictionary in boss.hands.active:
		var id: String = "hand%d" % int(h["n"])
		if _handled.has(id) or int(h["stage"]) != SleepTakerHands.Stage.MIST:
			continue
		_handled[id] = true
		var lane: int = int(h["lane"])
		var mine: int = _target if _target >= 0 else player.lane
		if lane != mine:
			continue
		var struck: Array[int] = [lane]
		var e: int = boss.escape_lane(struck, lane, player.distance,
			float(h["at"]) + boss.tuning.escape_clear_after * boss.run_pace())
		if e < 0:
			e = lane + (1 if lane < boss.lane_count() - 1 else -1)
		_pending.append({"at": boss.fight_time() + reaction, "lane": e, "why": "hand"})


## The nearest lane outside `struck` whose floor (and the lanes on the way) is clear from `from` to `to`.
func _free_lane(struck: Array[int], pl: int, from: float, to: float) -> int:
	var n: int = boss.lane_count()
	for dist: int in range(1, n):
		for s: int in [-1, 1]:
			var e: int = pl + s * dist
			if e < 0 or e >= n or struck.has(e):
				continue
			var ok: bool = true
			for l: int in range(mini(pl, e), maxi(pl, e) + 1):
				if l != pl and not boss.floor_clear_lane(l, from, to):
					ok = false
			if ok:
				return e
	return -1


static func _nearest(lanes: Array[int], pl: int) -> int:
	var best: int = -1
	for l: int in lanes:
		if best < 0 or absi(l - pl) < absi(best - pl):
			best = l
	return best


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


## One lane a frame toward the lane it's heading for (on the floor or the ceiling).
func _walk() -> void:
	var player: Player = boss.world.player
	if _target < 0 or player.surface == Player.Surface.WALL:
		return
	if player.lane == _target:
		_target = -1
		return
	_press(&"move_right" if _target > player.lane else &"move_left", _why)


func _press(action: StringName, why: String) -> void:
	boss.world.player.press(action)
	log.append({"t": boss.fight_time(), "action": action, "why": why})
