class_name TheHouseBot
extends RefCounted
## A runner who plays The House's fight by what it shows, for tests and reviews
## (tools/showcase/the_house_showcase.gd). Call step() every physics frame. It only presses the player's
## named actions and reacts `reaction` seconds after something new shows, like a player:
## - every warning on the track (the cherry bombs' target circles, the BAR rows' red lanes and their
##   blocks, the rolled fences) and every lit 7 button: it plans a way through them all and over the
##   buttons, in order (TheHouseRoute, the machine's own fairness check: the route a player who reads the
##   warnings would take), dropping the last buttons if it can't make them all (`takes_buttons` off: it
##   never goes for one), and follows it lane by lane;
## - fences in its lane: it jumps a full one and slides under a gapped one;
## - the jackpot: once the hopper bursts open it jumps so it comes down on the hopper (`stomps` off: it
##   runs on and lets the window pass).
## `log` holds what it did.

## Reading fences (as FloatingHeadBot): a full fence jumped this far before it, no later than
## FENCE_JUMP_LAST before it; a gapped one slid under from this far. Metres at 18 m/s, times the run's pace.
const FENCE_JUMP_LEAD: float = 6.2
const FENCE_JUMP_LAST: float = 3.4
const FENCE_SLIDE_LEAD: float = 3.5
## Where in the hopper's stomp box it aims to come down (a share of the box from its front).
const HOPPER_AIM: float = 0.3

var boss: TheHouse
## Seconds from something new showing to its first move.
var reaction: float = 0.3
var takes_buttons: bool = true
var stomps: bool = true
## The buttons it lets go by (their reels), whatever else it does.
var skip_reels: Array[int] = []
## What it did, for tests: {t (fight time), action, why}.
var log: Array[Dictionary] = []
## Routes it couldn't find (it keeps its last one).
var stuck: int = 0

var _seen: Dictionary = {}
var _replan_at: float = -1.0
var _route: Dictionary = {}
var _route_from: int = 0
var _jumped_window: int = -1
var _fence_done: Dictionary = {}


func _init(p_boss: TheHouse) -> void:
	boss = p_boss


func step() -> void:
	var p: Player = boss.world.player
	if not p.alive or not p.running:
		return
	var now: float = boss.fight_time()
	if _something_new():
		_replan_at = now + reaction if _replan_at < 0.0 else minf(_replan_at, now + reaction)
	if _replan_at >= 0.0 and now >= _replan_at:
		_replan_at = -1.0
		_plan()
	_follow()
	_read_fences()
	if stomps:
		_read_jackpot()


## True if a strike or a button has shown since it last looked.
func _something_new() -> bool:
	var fresh: bool = false
	for s: Dictionary in boss.attacks.strikes:
		var id: String = "s%d" % int(s["n"])
		if not _seen.has(id):
			_seen[id] = true
			fresh = true
	for b: Dictionary in boss.buttons.active:
		if b["state"] != "lit":
			continue
		var id: String = "b%d_%.1f" % [int(b["reel"]), float(b["at"])]
		if not _seen.has(id):
			_seen[id] = true
			fresh = true
	return fresh


## A route from where it is through every warning on the track and over the lit buttons it goes for.
func _plan() -> void:
	var p: Player = boss.world.player
	var d0: float = p.distance
	var obstacles: Array[Dictionary] = boss.attacks.obstacles(d0 - 3.0)
	var buttons: Array[Dictionary] = []
	if takes_buttons:
		for b: Dictionary in boss.buttons.active:
			if b["state"] == "lit" and float(b["at"]) > d0 + 1.0 and not skip_reels.has(int(b["reel"])):
				buttons.append({"lane": int(b["lane"]), "at": float(b["at"])})
	buttons.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["at"]) < float(b["at"]))
	var end: float = d0 + 10.0
	for o: Dictionary in obstacles:
		end = maxf(end, float(o["to"]))
	for w: Dictionary in buttons:
		end = maxf(end, float(w["at"]))
	end += 8.0 * boss.run_pace()
	var r: TheHouseRoute = boss.route()
	var start: int = boss.player_lane()
	while true:
		var route: Dictionary = r.find(start, d0, d0, end, obstacles, buttons)
		if route["ok"]:
			_route = route
			_route_from = start
			log.append({"t": boss.fight_time(), "action": &"plan", "why": "%d obstacles, %d buttons, %d moves" % [
				obstacles.size(), buttons.size(), (route["moves"] as Array).size()]})
			return
		if buttons.is_empty():
			break
		buttons.pop_back()
	stuck += 1
	log.append({"t": boss.fight_time(), "action": &"stuck", "why": "no route through %d obstacles" % obstacles.size()})


## One lane a frame toward the lane its route has it in now.
func _follow() -> void:
	var p: Player = boss.world.player
	if _route.is_empty() or p.surface != Player.Surface.FLOOR:
		return
	var want: int = TheHouseRoute.lane_at(_route, _route_from, p.distance)
	if want == p.lane:
		return
	_press(&"move_right" if want > p.lane else &"move_left", "route")


## Fences in its lane: a full one jumped, a gapped one slid under.
func _read_fences() -> void:
	var p: Player = boss.world.player
	if p.surface != Player.Surface.FLOOR:
		return
	var d: float = p.distance
	var k: float = boss.run_pace()
	for s: Dictionary in boss.attacks.strikes:
		if int(s["kind"]) != TheHouseAttacks.Kind.LIGHTNING or not (s["lanes"] as Array).has(p.lane):
			continue
		var id: String = "f%d" % int(s["n"])
		if _fence_done.has(id):
			continue
		var ahead: float = float(s["at"]) - d
		if s["variant"] == "gapped":
			if ahead > 0.0 and ahead <= FENCE_SLIDE_LEAD * k and p.grounded:
				_fence_done[id] = true
				_press(&"slide", "gapped fence")
		elif ahead > FENCE_JUMP_LAST * k and ahead <= FENCE_JUMP_LEAD * k and p.grounded:
			_fence_done[id] = true
			_press(&"jump", "fence")


## The jackpot: once the hopper is open (or about to be), a jump timed to come down on it.
func _read_jackpot() -> void:
	var j: TheHouseJackpot = boss.jackpot
	var p: Player = boss.world.player
	if j.stage != TheHouseJackpot.Stage.OPEN and j.stage != TheHouseJackpot.Stage.SAG:
		return
	if _jumped_window == j.count or not p.grounded or p.surface != Player.Surface.FLOOR:
		return
	if j.stage == TheHouseJackpot.Stage.SAG and boss.body.sag < 0.9:
		return
	var span: Vector2 = boss.body.hopper_span(j.stall_front)
	var aim: float = lerpf(span.x, span.y, HOPPER_AIM)
	var lead: float = stomp_lead(p.h)
	if p.distance >= aim - lead:
		_jumped_window = j.count
		_press(&"jump", "the hopper")


## How far before the point it means to come down on the hopper a runner at height `h0` jumps: up to the
## jump's top and back down to the hopper's stomp height, at the run speed.
func stomp_lead(h0: float) -> float:
	var t: MovementTuning = boss.world.tuning
	var top: float = boss.tuning.deck_height + boss.tuning.stomp_top
	var drop: float = maxf(h0 + t.jump_height - top, 0.05)
	var t_down: float = sqrt(2.0 * drop / (t.gravity() * t.fall_gravity_multiplier))
	return boss.speed() * (t.jump_time_to_apex + t_down)


func _press(action: StringName, why: String) -> void:
	boss.world.player.press(action)
	log.append({"t": boss.fight_time(), "action": action, "why": why})
