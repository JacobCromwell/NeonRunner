class_name GoldenConvergenceCourt
extends RefCounted
## The Grand Court's walls (GDD §10, the arena, proposed: "a wide golden causeway ... No walls line it: low
## golden balustrades edge it"; "No side walls: the arena has none, except where a destroyed Flying Buttress
## brings a building down to make one ... Beyond the outer lanes, a low golden balustrade bumps the runner
## back (the bump the game already uses when a boss takes a wall away), so there's no new way to die").
## A small part of the encounter (GoldenConvergence.court) that keeps both walls taken away
## (BossProps.block_wall: the clank and the bump of Player._wall_blocked, LAYER_WALL_BLOCKER) from just behind
## the runner to GoldenConvergenceTuning.wall_block_ahead ahead, laid in stretches as the runner goes, except
## where a wall is open:
## - open_wall(side, from, to): the wall on `side` is there between two track distances (E5d-b's toppled
##   tower draws itself as the wall there); the blockers over that stretch are taken up and laid again around
##   it; close_wall(id) gives the stretch back to the balustrade;
## - is_open(side, d): whether a runner may be on that wall at `d` (the strafe's wall rules read it: GDD §10,
##   "fire in an outer lane hits a runner low on the wall", the horizontal pass "up both walls at every
##   height");
## - a wall runner who reaches the end of an open stretch (or one that closes under them) drops off into the
##   outer lane with the blocked wall's clank (Player.repel_from_wall).
## The skin (GoldenCourtSkin) draws the balustrade everywhere; what opens a wall draws the wall itself.

## Blockers start this far behind the runner.
const BEHIND: float = 10.0

var boss: GoldenConvergence
## The open stretches: {id, side, from, to}.
var openings: Array[Dictionary] = []
## Wall runners dropped off where the wall wasn't open (tests).
var repels: int = 0

## How far the blockers are laid on each side (-1 left, 1 right).
var _laid: Dictionary = {}
## The blockers laid: {side, from, to, node}.
var _blockers: Array[Dictionary] = []
var _next_id: int = 1


func _init(p_boss: GoldenConvergence) -> void:
	boss = p_boss


## Every physics frame of the fight: lays the blockers on ahead, and drops a wall runner off where their
## wall isn't open.
func tick() -> void:
	var d: float = boss.player_distance()
	var t: GoldenConvergenceTuning = boss.tuning
	var stretch: float = maxf(t.wall_block_stretch, 5.0)
	var ahead: float = d + t.wall_block_ahead
	for side: int in [-1, 1]:
		var from: float = maxf(float(_laid.get(side, -INF)), d - BEHIND)
		while from < ahead:
			_lay(side, from, from + stretch)
			from += stretch
		_laid[side] = from
	for i: int in range(_blockers.size() - 1, -1, -1):
		if not is_instance_valid(_blockers[i]["node"]):
			_blockers.remove_at(i)
	var p: Player = boss.world.player
	if p.alive and p.surface == Player.Surface.WALL and not is_open(p.wall_side, p.distance):
		if p.repel_from_wall():
			repels += 1
			boss.log_event(&"wall_repel", {"side": p.wall_side, "at": p.distance})


## Opens the wall on `side` (-1 left, 1 right) between track distances `from` and `to`: a runner may enter
## it and run on it there. Returns the opening's id (close_wall).
func open_wall(side: int, from: float, to: float) -> int:
	var id: int = _next_id
	_next_id += 1
	openings.append({"id": id, "side": signi(side), "from": minf(from, to), "to": maxf(from, to)})
	_relay(signi(side), minf(from, to), maxf(from, to))
	boss.log_event(&"wall_open", {"side": signi(side), "from": from, "to": to, "id": id})
	return id


## Gives an opened stretch of wall back to the balustrade.
func close_wall(id: int) -> void:
	for i: int in openings.size():
		var o: Dictionary = openings[i]
		if int(o["id"]) == id:
			openings.remove_at(i)
			_relay(int(o["side"]), float(o["from"]), float(o["to"]))
			boss.log_event(&"wall_close", {"id": id})
			return


## Closes every opening (a phase change, the defeat).
func clear() -> void:
	var ids: Array[int] = []
	for o: Dictionary in openings:
		ids.append(int(o["id"]))
	for id: int in ids:
		close_wall(id)


## True if the wall on `side` is open at track distance `d`.
func is_open(side: int, d: float) -> bool:
	for o: Dictionary in openings:
		if int(o["side"]) == signi(side) and d >= float(o["from"]) and d <= float(o["to"]):
			return true
	return false


## True if a blocker lies on the wall on `side` at `d` (tests).
func blocked(side: int, d: float) -> bool:
	for b: Dictionary in _blockers:
		if int(b["side"]) == side and is_instance_valid(b["node"]) and d >= float(b["from"]) and d <= float(b["to"]):
			return true
	return false


## How far ahead the walls are blocked on `side`.
func laid_until(side: int) -> float:
	return float(_laid.get(side, -INF))


## Lays the blockers over [from, to] on `side`, around the open stretches.
func _lay(side: int, from: float, to: float) -> void:
	var pieces: Array[Vector2] = [Vector2(from, to)]
	for o: Dictionary in openings:
		if int(o["side"]) != side:
			continue
		var cut: Array[Vector2] = []
		for p: Vector2 in pieces:
			var a: float = float(o["from"])
			var b: float = float(o["to"])
			if b <= p.x or a >= p.y:
				cut.append(p)
				continue
			if a > p.x:
				cut.append(Vector2(p.x, a))
			if b < p.y:
				cut.append(Vector2(b, p.y))
		pieces = cut
	for p: Vector2 in pieces:
		if p.y - p.x < 0.05:
			continue
		var node: Area3D = boss.props.block_wall(side, p.x, p.y)
		_blockers.append({"side": side, "from": p.x, "to": p.y, "node": node})


## Takes up the blockers on `side` that reach into [from, to] and lays their stretch again (around the
## openings now).
func _relay(side: int, from: float, to: float) -> void:
	var lo: float = INF
	var hi: float = -INF
	for i: int in range(_blockers.size() - 1, -1, -1):
		var b: Dictionary = _blockers[i]
		if int(b["side"]) != side or float(b["to"]) < from or float(b["from"]) > to:
			continue
		lo = minf(lo, float(b["from"]))
		hi = maxf(hi, float(b["to"]))
		boss.props.remove(b["node"] as Node)
		_blockers.remove_at(i)
	# A stretch closed again inside what's laid needs its blockers back even if none was there.
	var laid: float = float(_laid.get(side, -INF))
	if from < laid:
		lo = minf(lo, from)
		hi = maxf(hi, minf(to, laid))
	if lo < hi:
		_lay(side, lo, hi)
