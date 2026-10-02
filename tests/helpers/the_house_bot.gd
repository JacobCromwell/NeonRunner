class_name TheHouseBot
extends RefCounted
## A runner who plays The House's fight by what it shows, for tests and reviews
## (tools/showcase/the_house_showcase.gd). Call step() every physics frame. It only presses the player's
## named actions and reacts `reaction` seconds after something new shows, like a player:
## - every warning on the track (the cherry bombs' target circles, the BAR rows' red lanes and their
##   blocks, the rolled fences) and every lit 7 button: it plans a way through them all and over the
##   buttons, in order (TheHouseRoute, the machine's own fairness check: the route a player who reads the
##   warnings would take), dropping the last buttons if it can't make them all (`takes_buttons` off: it
##   never goes for one; `avoids_buttons`: it steers around them), and follows it lane by lane;
## - a wall button: to the outer lane on its wall, onto the wall wall_entry_before it (TheHouseTuning),
##   and a wall jump back to the street once past it (or at once if a wall fence ahead on its wall would
##   be on when it got there);
## - a ceiling button: to the pad's lane over the pad (it never jumps a pad), then along the ceiling by
##   the ceiling's route (TheHouseCeiling.route) over the button, dodging the turrets' bolts into the lane
##   beside the pad's that has no turret (and back), until it drops back down at the end;
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
## A bolt that would cross its spot within this long, less than BOLT_REACH to the side, sends it out of
## its lane (as FloatingHeadBot).
const BOLT_REACT: float = 0.4
const BOLT_REACH: float = 0.9
## Past a wall button by this much (metres), it jumps back off the wall.
const WALL_PAST: float = 1.0

var boss: TheHouse
## Seconds from something new showing to its first move.
var reaction: float = 0.3
var takes_buttons: bool = true
## Steers around every lit button (a player who lets a whole set go by).
var avoids_buttons: bool = false
var stomps: bool = true
## The buttons it lets go by (their reels), whatever else it does.
var skip_reels: Array[int] = []
## What it did, for tests: {t (fight time), action, why}.
var log: Array[Dictionary] = []
## Routes it couldn't find (it keeps its last one).
var stuck: int = 0
## Bursts it dodged on a ceiling.
var dodges: int = 0

var _seen: Dictionary = {}
var _replan_at: float = -1.0
var _route: Dictionary = {}
var _route_from: int = 0
var _jumped_window: int = -1
var _fence_done: Dictionary = {}
var _ceiling_route: Dictionary = {}
var _ceiling_for: int = -1
var _dodging: bool = false


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
	match p.surface:
		Player.Surface.FLOOR:
			_follow()
			_take_wall()
			_read_fences()
			if stomps:
				_read_jackpot()
		Player.Surface.WALL:
			_on_wall()
		Player.Surface.CEILING:
			_on_ceiling()


## True if a strike, a button or a ceiling has shown since it last looked.
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
	var seg: Dictionary = boss.ceiling.segment
	if not seg.is_empty() and bool(seg.get("shown", false)):
		var id: String = "c%d" % boss.ceiling.count
		if not _seen.has(id):
			_seen[id] = true
			fresh = true
	return fresh


## The lit buttons it goes for, ahead of it.
func _wanted() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not takes_buttons or avoids_buttons:
		return out
	var d0: float = boss.world.player.distance
	for b: Dictionary in boss.buttons.active:
		if b["state"] == "lit" and float(b["at"]) > d0 + 1.0 and not skip_reels.has(int(b["reel"])):
			out.append(b)
	return out


## A route from where it is through every warning on the track and over the lit buttons it goes for (a
## wall button as a hold of its outer lane over its wall run; a ceiling button as a hold of its pad's
## lane over the pad).
func _plan() -> void:
	var p: Player = boss.world.player
	var d0: float = p.distance
	var v: float = boss.speed()
	var obstacles: Array[Dictionary] = boss.attacks.obstacles(d0 - 3.0)
	var waypoints: Array[Dictionary] = []
	if avoids_buttons:
		var half: float = boss.tuning.button_depth * boss.run_pace() * 0.5
		for b: Dictionary in boss.buttons.active:
			if b["state"] == "lit" and b["kind"] == "floor" and float(b["at"]) > d0 + 1.0:
				obstacles.append(TheHouseRoute.obstacle(int(b["lane"]), float(b["at"]) - half, float(b["at"]) + half))
	else:
		for b: Dictionary in _wanted():
			match String(b["kind"]):
				"wall":
					var at: float = float(b["at"])
					waypoints.append({"lane": int(b["lane"]), "at": at - v * _entry_before(),
						"to": at + v * boss.tuning.wall_after / boss.pace()})
				"ceiling":
					pass
				_:
					waypoints.append({"lane": int(b["lane"]), "at": float(b["at"])})
		var seg: Dictionary = boss.ceiling.segment
		if takes_buttons and not avoids_buttons and not seg.is_empty() and bool(seg.get("shown", false)) \
				and float(seg["pad_at"]) > d0 + 1.0 and _wants_ceiling(seg):
			var pad_at: float = float(seg["pad_at"])
			waypoints.append({"lane": int(seg["pad_lane"]), "at": pad_at - 1.0,
				"to": pad_at + boss.world.tuning.pad_length})
	waypoints.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["at"]) < float(b["at"]))
	var end: float = d0 + 10.0
	for o: Dictionary in obstacles:
		end = maxf(end, float(o["to"]))
	for w: Dictionary in waypoints:
		end = maxf(end, float(w.get("to", w["at"])))
	end += 8.0 * boss.run_pace()
	var r: TheHouseRoute = boss.route()
	var start: int = boss.player_lane()
	while true:
		var route: Dictionary = r.find(start, d0, d0, end, obstacles, waypoints)
		if route["ok"]:
			_route = route
			_route_from = start
			log.append({"t": boss.fight_time(), "action": &"plan", "why": "%d obstacles, %d waypoints, %d moves" % [
				obstacles.size(), waypoints.size(), (route["moves"] as Array).size()]})
			return
		if waypoints.is_empty():
			break
		waypoints.pop_back()
	stuck += 1
	log.append({"t": boss.fight_time(), "action": &"stuck", "why": "no route through %d obstacles" % obstacles.size(),
		"lane": start, "d": d0, "x": p.position.x, "h": p.h, "obstacles": obstacles})


## True if it goes for the ceiling `seg`'s button (it takes the pad).
func _wants_ceiling(seg: Dictionary) -> bool:
	for b: Dictionary in boss.buttons.active:
		if b["kind"] == "ceiling" and b.get("segment", {}).get("pad_at", -1.0) == seg["pad_at"]:
			return not skip_reels.has(int(b["reel"])) and b["state"] != "missed"
	return false


## How long before a wall button it gets onto the wall.
func _entry_before() -> float:
	return boss.tuning.wall_entry_before / boss.pace()


## One lane a frame toward the lane its route has it in now.
func _follow() -> void:
	var p: Player = boss.world.player
	if _route.is_empty():
		return
	var want: int = TheHouseRoute.lane_at(_route, _route_from, p.distance)
	if want == p.lane:
		return
	_press(&"move_right" if want > p.lane else &"move_left", "route")


## A lit wall button ahead: once it's in the outer lane on its wall and its entry is here, onto the wall.
func _take_wall() -> void:
	var p: Player = boss.world.player
	if not p.grounded:
		return
	var v: float = boss.speed()
	for b: Dictionary in _wanted():
		if b["kind"] != "wall":
			continue
		var at: float = float(b["at"])
		var outer: int = int(b["lane"])
		if p.lane != outer:
			continue
		if p.distance >= at - v * _entry_before() and p.distance < at:
			_press(&"move_left" if int(b["side"]) < 0 else &"move_right", "onto the wall")
			return


## On a wall: back to the street once past the wall button (or at once if a wall fence ahead on its wall
## would be on when it got there).
func _on_wall() -> void:
	var p: Player = boss.world.player
	var v: float = boss.speed()
	var inward: StringName = &"move_right" if p.wall_side < 0 else &"move_left"
	var past: bool = true
	for b: Dictionary in boss.buttons.active:
		if b["kind"] == "wall" and int(b["side"]) == p.wall_side and b["state"] == "lit" and float(b["at"]) + WALL_PAST > p.distance:
			past = false
	var danger: bool = not boss.walls.passage_off(p.wall_side, p.distance, p.distance + v * 0.5, boss.world.level_time(),
		v, 0.1)
	if past or danger:
		_press(inward, "off the wall" if past else "a wall fence")


## On the ceiling: the ceiling's route over the button, out of a bolt's way into the lane beside the
## pad's with no turret (and back once it's gone by).
func _on_ceiling() -> void:
	var p: Player = boss.world.player
	var seg: Dictionary = boss.ceiling.segment
	if seg.is_empty():
		return
	if _ceiling_for != boss.ceiling.count:
		_ceiling_for = boss.ceiling.count
		_ceiling_route = boss.ceiling.route(seg)
		_dodging = false
	var want: int = int(seg["pad_lane"])
	if bool(_ceiling_route.get("ok", false)):
		want = TheHouseRoute.lane_at(_ceiling_route, int(seg["pad_lane"]), p.distance)
	var dodge: int = int(seg["pad_lane"]) - int(seg.get("side", 1))
	var n: int = boss.lane_count()
	if dodge < 0 or dodge >= n or dodge == int(seg["turret_lane"]):
		dodge = int(seg["pad_lane"])
	if _bolt_toward(p.lane):
		var to: int = dodge if p.lane != dodge else int(seg["pad_lane"])
		if to != p.lane and not _bolt_toward(to):
			if not _dodging:
				dodges += 1
			_dodging = true
			_go(to, "a bolt")
			return
	if _dodging and _bolt_toward(want):
		_go(p.lane, "waiting out a bolt")
		return
	_dodging = false
	_go(want, "the ceiling")


func _go(lane: int, why: String) -> void:
	var p: Player = boss.world.player
	if lane == p.lane:
		return
	_press(&"move_right" if lane > p.lane else &"move_left", why)


## True if a hostile bolt will cross the runner's spot in `lane` soon (see BOLT_REACT).
func _bolt_toward(lane: int) -> bool:
	var world: RunWorld = boss.world
	var player: Player = world.player
	var x: float = world.geo.lane_x(lane)
	for shot: Projectile in world.projectiles.live_shots():
		if shot.friendly:
			continue
		var gap: float = -shot.global_position.z - player.distance
		var closing: float = shot.velocity.z + player.speed
		if gap < -0.5 or closing <= 0.1:
			continue
		var t: float = maxf(gap, 0.0) / closing
		if t > BOLT_REACT:
			continue
		if absf(shot.global_position.x + shot.velocity.x * t - x) < BOLT_REACH:
			return true
	return false


## Fences in its lane: a full one jumped, a gapped one slid under.
func _read_fences() -> void:
	var p: Player = boss.world.player
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
	if _jumped_window == j.count or not p.grounded:
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
