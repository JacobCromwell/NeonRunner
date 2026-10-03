class_name HostileTakeoverBot
extends RefCounted
## A runner who plays Hostile Takeover's fight by what it shows, for tests and reviews
## (tools/showcase/hostile_takeover_showcase.gd). Call step() every physics frame. It only presses the
## player's named actions and reacts `reaction` seconds after something new shows, like a player:
## - the train's gaps: each jumped from HOLE_LEAD before its edge, in whatever lane it's in;
## - a live coupling (glowing red over the gap it comes to next): it heads for its lane, a lane at a time
##   and never across a guard, and jumps so it comes down on it (HostileTakeoverCouplings.descent_lead: up
##   to the jump's top and back down to the stomp box's top, at its speed), aiming `aim` of the way along
##   the box; `stomps` off, or the first `misses` live ones, it lets go by (it jumps the gap as any: from
##   the coupling's own lane with `skip_in_lane`); `side_lane` (-1 or 1) runs up in the lane beside the
##   coupling's (the other side at the edge) and moves in while in the air; `drops` runs off the roof's
##   edge in the first live coupling's lane without jumping;
## - the guards: out of a cyborg's lane ahead, and out of the line of a bolt about to reach it (unless it's
##   in a coupling's run-up, where no bolt lands: CyborgGun's clear path around a gap);
## - phase 2 (HostileTakeoverContract): out of a strafe's struck lanes (`reaction` after its line shows)
##   and out of a dropped Buzz Overdrive's lane (after it lands, until its attack is over), into the
##   nearest lane neither threatens (`ignores_strafes` stays put for a strafe, `meets_saw` heads into the
##   tank's lane instead: tests of a hit); onto the runway of pads before the armored carriage (it just
##   runs on: they're in every lane); on the gunship's belly, a jump timed to come back up onto the open
##   drop bay (HostileTakeoverContract.bay_lead), unless `bay_stomps` is off or it lets the first
##   `bay_misses` rides go by;
## - it never goes onto a wall (the wall fences never reach it); a Tithe Collector may rob it.
## Its distances are metres at 18 m/s, stretched by the run's pace (HostileTakeover.run_pace).
## `log` holds what it did.

## A gap is jumped this far before its near edge.
const HOLE_LEAD: float = 1.6
## Bolts: one that would cross its spot within this long, nearer than this sideways, is dodged.
const BOLT_REACT: float = 0.7
const BOLT_REACH: float = 0.75
## A cyborg this far ahead in a lane keeps it out of that lane; a switch across a lane waits while one
## stands within SWITCH_CLEAR either way of it there.
const CYBORG_AHEAD: float = 30.0
const SWITCH_CLEAR: float = 6.0

var boss: HostileTakeover
## Seconds from something new showing to its first move.
var reaction: float = 0.35
var stomps: bool = true
## Live couplings it lets go by before it goes for one.
var misses: int = 0
## Runs up beside the coupling's lane (-1 left, +1 right) and moves in while in the air; 0 in its lane.
var side_lane: int = 0
## Where in the coupling's stomp box it means to come down (a share of the box from its near end).
var aim: float = 0.55
## A coupling it lets go by, it still runs up in its lane (and jumps the gap the usual way).
var skip_in_lane: bool = false
## At the first live coupling it heads for its lane and never jumps that gap.
var drops: bool = false
## On the gunship's belly, it jumps to stomp the open drop bay.
var bay_stomps: bool = true
## Rides whose drop bay it lets go by (it rides on without jumping) before it stomps one.
var bay_misses: int = 0
## It ignores the strafes (stays in its lane: for tests of a strike).
var ignores_strafes: bool = false
## Once a dropped Buzz Overdrive lands, it heads into its lane and stays there until its blade has been
## blocked (the armor or the shield: it's invulnerable a moment), then leaves it (a test of its rules).
var meets_saw: bool = false
## What it did, for tests: {t (fight time), action, why}.
var log: Array[Dictionary] = []
## The lane it took off from for each gap it jumped (gap index -> lane).
var takeoffs: Dictionary = {}

var _seen: Dictionary = {}
var _skipped: Dictionary = {}
var _jumped: Dictionary = {}
var _target: int = -1
var _why: String = ""
var _move_in: int = 0
var _threat_seen: Dictionary = {}
var _bay_jumped: Dictionary = {}
var _met_saw: Dictionary = {}


func _init(p_boss: HostileTakeover) -> void:
	boss = p_boss


func step() -> void:
	var p: Player = boss.world.player
	if not p.alive or not p.running:
		return
	if p.surface == Player.Surface.CEILING:
		_ride()
		return
	var d: float = p.distance
	var k: int = boss.train.next_gap(d)
	var going: int = _coupling_target(k)
	if going >= 0:
		_head_for(_runup_lane(going), "coupling")
	elif skip_in_lane and _skipped.has(k) and boss.board.lanes.has(k):
		_head_for(int(boss.board.lanes[k]), "the lane of a coupling it lets go by")
	elif not _avoid_threats():
		_avoid_cyborgs()
		_dodge_bolts()
	_walk()
	_jump(k, going)


## Phase 2's threats (see the header): true if one keeps it busy (heading out of it, or holding a lane
## clear of it).
func _avoid_threats() -> bool:
	var c: HostileTakeoverContract = boss.contract
	if c == null:
		return false
	var bad: Array[int] = []
	var now: float = boss.fight_time()
	if not ignores_strafes:
		var struck: Array[int] = c.struck_now()
		if not struck.is_empty():
			var key: String = "strafe%d" % c.strafes
			if not _threat_seen.has(key):
				_threat_seen[key] = now
			if now - float(_threat_seen[key]) >= reaction:
				bad.append_array(struck)
	var saw: Dictionary = c.saw_now()
	if not saw.is_empty() and int(saw["stage"]) == HostileTakeoverContract.DropStage.LANDED:
		var key2: String = "saw%d" % int(saw["k"])
		if not _threat_seen.has(key2):
			_threat_seen[key2] = now
		if now - float(_threat_seen[key2]) >= reaction:
			if meets_saw and not _met_saw.has(key2):
				if boss.world.player.invulnerable_left > 0.0:
					_met_saw[key2] = true
				else:
					_head_for(int(saw["lane"]), "into the Buzz Overdrive's lane")
					return true
			bad.append(int(saw["lane"]))
	if bad.is_empty():
		return false
	var p: Player = boss.world.player
	var lane: int = _target if _target >= 0 else p.lane
	if not bad.has(lane):
		return true
	for s: int in [1, -1, 2, -2, 3, -3, 4, -4, 5, -5]:
		var to: int = lane + s
		if to >= 0 and to < boss.lane_count() and not bad.has(to):
			_head_for(to, "strafe" if not c.struck_now().is_empty() and c.struck_now().has(lane) else "the Buzz Overdrive")
			return true
	return true


## On the gunship's belly: a jump timed so it comes back up onto the open drop bay.
func _ride() -> void:
	var c: HostileTakeoverContract = boss.contract
	if c == null or not bay_stomps:
		return
	var ride: Dictionary = c.ride_now()
	if ride.is_empty() or ride["stomped"] or not boss.gunship.bay_open or _bay_jumped.has(int(ride["k"])):
		return
	if bay_misses > 0:
		bay_misses -= 1
		_bay_jumped[int(ride["k"])] = true
		log.append({"t": boss.fight_time(), "action": &"skip", "why": "lets the drop bay %d go by" % int(ride["k"])})
		return
	var p: Player = boss.world.player
	if not p.grounded:
		return
	var span: Vector2 = boss.gunship.bay_span()
	var ahead: float = (span.x + span.y) * 0.5 - p.distance
	if ahead <= c.bay_lead(ride) and ahead > -0.5:
		_bay_jumped[int(ride["k"])] = true
		_press(&"jump", "the drop bay %d" % int(ride["k"]))


## The lane it runs up in for a coupling in `lane`: its own, or the one beside it on side_lane's side
## (the other side at the track's edge, or where a guard stands in it before the gap: the guards keep only
## the coupling's own lane clear over its run-up).
func _runup_lane(lane: int) -> int:
	if side_lane == 0:
		return lane
	var p: Player = boss.world.player
	var edge: float = boss.train.gap_start(boss.train.next_gap(p.distance))
	for side: int in [side_lane, -side_lane]:
		var to: int = lane + side
		if to >= 0 and to < boss.lane_count() and not _cyborg_in(to, p.distance - 1.0, edge):
			return to
	return lane


## The coupling over gap `k` it goes for: its lane, or -1 (none live, not seen long enough, or let go by).
func _coupling_target(k: int) -> int:
	if not stomps or not boss.coupling_live(k):
		return -1
	var now: float = boss.fight_time()
	if not _seen.has(k):
		_seen[k] = now
	if now - float(_seen[k]) < reaction:
		return -1
	if not _skipped.has(k) and misses > 0:
		_skipped[k] = true
		misses -= 1
		log.append({"t": now, "action": &"skip", "why": "lets coupling %d go by" % k})
	if _skipped.has(k):
		return -1
	return int(boss.board.lanes.get(k, -1))


## Jumps the gap it comes to: onto the coupling (see the header), else from HOLE_LEAD before the edge.
func _jump(k: int, coupling_lane: int) -> void:
	var p: Player = boss.world.player
	if _jumped.has(k) or not p.grounded or p.surface != Player.Surface.FLOOR:
		return
	var d: float = p.distance
	if coupling_lane >= 0:
		if drops:
			return
		var span: Vector2 = boss.couplings.box_span(k)
		var at: float = lerpf(span.x, span.y, aim)
		var lead: float = stomp_lead()
		if d >= at - lead:
			_jumped[k] = true
			takeoffs[k] = p.lane
			_press(&"jump", "coupling %d from lane %d" % [k, p.lane])
			_move_in = signi(coupling_lane - p.lane)
			return
	var edge: float = boss.train.gap_start(k)
	if edge - d <= HOLE_LEAD * boss.run_pace():
		_jumped[k] = true
		takeoffs[k] = p.lane
		_press(&"jump", "gap %d from lane %d" % [k, p.lane])


## How far before the point it means to come down on a coupling it jumps (at its speed now).
func stomp_lead() -> float:
	var t: MovementTuning = boss.world.tuning
	var lead: float = HostileTakeoverCouplings.descent_lead(t, boss.tuning.stomp_top)
	return lead * boss.world.player.speed / maxf(t.run_speed, 0.1)


## Out of a cyborg's lane ahead (the nearest lane without one).
func _avoid_cyborgs() -> void:
	var p: Player = boss.world.player
	if p.surface != Player.Surface.FLOOR:
		return
	var lane: int = _target if _target >= 0 else p.lane
	var ahead: float = CYBORG_AHEAD * boss.run_pace()
	if not _cyborg_in(lane, p.distance - 1.0, p.distance + ahead):
		return
	for s: int in [1, -1, 2, -2, 3, -3]:
		var to: int = lane + s
		if to >= 0 and to < boss.lane_count() and not _cyborg_in(to, p.distance - 1.0, p.distance + ahead):
			_head_for(to, "cyborg")
			return


## A hostile bolt about to cross its spot (see the header): the nearest lane no bolt is heading for.
func _dodge_bolts() -> void:
	var p: Player = boss.world.player
	if p.surface != Player.Surface.FLOOR:
		return
	var lane: int = _target if _target >= 0 else p.lane
	if not _bolt_toward(lane):
		return
	for s: int in [1, -1, 2, -2]:
		var to: int = lane + s
		if to >= 0 and to < boss.lane_count() and not _bolt_toward(to) \
				and not _cyborg_in(to, p.distance - 1.0, p.distance + CYBORG_AHEAD * boss.run_pace()):
			_target = to
			_why = "bolt"
			return


func _bolt_toward(lane: int) -> bool:
	var world: RunWorld = boss.world
	var p: Player = world.player
	var x: float = world.geo.lane_x(lane)
	for shot: Projectile in world.projectiles.live_shots():
		if shot.friendly:
			continue
		var gap: float = -shot.global_position.z - p.distance
		var closing: float = shot.velocity.z + p.speed
		if gap < -0.5 or closing <= 0.1:
			continue
		var t: float = maxf(gap, 0.0) / closing
		if t > BOLT_REACT:
			continue
		if absf(shot.global_position.x + shot.velocity.x * t - x) < BOLT_REACH:
			return true
	return false


## True if a live cyborg stands in `lane` between track distances `from` and `to`.
func _cyborg_in(lane: int, from: float, to: float) -> bool:
	for e: Enemy in boss.world.director.active:
		if not is_instance_valid(e) or not e.alive or not e is Cyborg:
			continue
		var c := e as Cyborg
		var at: float = c.track_distance()
		if c.lane == lane and at >= from and at <= to:
			return true
	return false


func _head_for(lane: int, why: String) -> void:
	_target = clampi(lane, 0, boss.lane_count() - 1)
	_why = why


## One lane a frame toward the lane it's heading for, never across a cyborg standing near; in the air
## after a coupling jump from the lane beside it, the move in.
func _walk() -> void:
	var p: Player = boss.world.player
	if p.surface != Player.Surface.FLOOR:
		return
	if _move_in != 0 and not p.grounded:
		_press(&"move_right" if _move_in > 0 else &"move_left", "into the coupling's lane %d" % (p.lane + _move_in))
		_move_in = 0
		_target = -1
		return
	# Out of a strafe's or a Buzz Overdrive's lane even in the air (mid-jump over a gap); other moves wait
	# for the roof.
	if _target < 0 or (not p.grounded and _why != "strafe" and _why != "the Buzz Overdrive"):
		return
	if p.lane == _target:
		_target = -1
		return
	var dir: int = 1 if _target > p.lane else -1
	if _cyborg_in(p.lane + dir, p.distance - SWITCH_CLEAR, p.distance + SWITCH_CLEAR):
		return
	_press(&"move_right" if dir > 0 else &"move_left", _why)


func _press(action: StringName, why: String) -> void:
	boss.world.player.press(action)
	log.append({"t": boss.fight_time(), "action": action, "why": why})
