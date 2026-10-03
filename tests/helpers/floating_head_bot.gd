class_name FloatingHeadBot
extends RefCounted
## A runner who plays the Floating Head's fight by its warnings, for tests and reviews
## (tools/showcase/floating_head_showcase.gd). Call step() every physics frame. It only presses the
## player's named actions, and only reacts to what the fight shows (an attack's kind, height, lane and
## where its beams are; a lit bomb target; the pinned ship, its weak points and its way up), the way a
## player reads the warnings:
## - a bomb's lock on its lane: switches to the free lane the fairness rules keep (like any player who
##   keeps moving);
## - a sweep: jumps a low one when it fires, slides under a high one as the beams reach its spot;
## - a drag: once its lane is committed (the red lane warning), switches to the free lane the fairness
##   rules keep (FloatingHead.escape_lane);
## - a marked tower: with `baits` on, moves to the outer lane on the tower's side while the drag aims,
##   and dodges only once it's committed (the bait); with `baits` off, keeps out of that lane;
## - dropped cyborgs: keeps out of the lane of one ahead of it;
## - with `routes` on, a stomp window: takes the phase's way onto its head once the laser's burning line
##   is out of the way (FloatingHead.route): into the ramp's lane, up it and off its end without a jump
##   (with `ramp_board_at`, from beside it partway along it, stepping up its lead-in's side);
##   by the wall marks (FloatingHeadWallMarks): onto the nearer wall a little past where they start and
##   a wall jump at the jump mark, inward (one lane further in the air only where the outer lane has no
##   weak point and its stomp box doesn't reach it); or over the pads, onto the ceiling, along it to the
##   nearest weak point's lane (`ceiling_moves`), and off its end. With `wrong_route` it runs on down the
##   trucks instead (a missed window).
## With `wrong` set to a sweep kind (&"low" or &"high"), it answers that kind the wrong way (slides
## under a low sweep, jumps a high one), to show the answer matters.
## With `reads_track` on (the default), it also runs the arena like any runner (_read_track): it jumps
## the holes and full fences in its lane (timed to clear them) and slides under gapped ones; and it
## watches bolts in the air (_dodge_bolts: a dropped cyborg's, wild ones too) and sidesteps one that
## would reach its lane.
## Its distances along the track are metres at 18 m/s, stretched by the run's pace
## (FloatingHead.run_pace; GDD §3), like the fight's: at a zone's speed it reads the track as many
## seconds ahead (a jump's arc is longer in metres at speed).

## The wall route: onto the wall this far past where its marks start (metres at 18 m/s, like the
## distances below: at the run's pace).
const ENTER_INTO: float = 1.0
## The second move inward comes this long after the wall jump.
const SECOND_MOVE: float = 0.1
## Reading the track: a hole is jumped this far before its edge, a full fence this far before it (the
## jump's arc is highest over it; no later than FENCE_JUMP_LAST before it, where the arc still clears
## it), a gapped fence slid under from this far before it. Sliding under a high sweep, it may jump out
## of the slide (to clear a hole or a fence behind it) once the beams are past, this long after.
const HOLE_LEAD: float = 1.6
const FENCE_JUMP_LEAD: float = 6.2
const FENCE_JUMP_LAST: float = 3.6
const FENCE_SLIDE_LEAD: float = 3.5
const SWEEP_PASSED: float = 0.3
## A bolt that would cross its spot within this long, closer than this sideways, is dodged.
const BOLT_REACT: float = 0.7
const BOLT_REACH: float = 0.75

var head: FloatingHead
var baits: bool = true
var routes: bool = true
var wrong: StringName = &""
## Stays down on the trucks through a stomp window (a miss).
var wrong_route: bool = false
## The wall the wall route takes: 0 the nearer one, -1 left, +1 right.
var wall_side: int = 0
## On the ceiling route, it moves along the ceiling to a weak point's lane (off: it drops in the lane it
## rode in, like a runner who only takes the pad).
var ceiling_moves: bool = true
## On the ramp route, it boards the ramp from beside it once this share of the ramp (foot to face) is
## behind it (_board_late; -1: it gets into the ramp's lane early, before its foot).
var ramp_board_at: float = -1.0
## On the wall route, it moves one lane further in the air where it must (off: one wall jump and no
## more, like a runner who doesn't know that move; the owner's playtest at 5 and 6 lanes before E1e).
var second_move: bool = true
## Runs the arena's holes and fences and dodges bolts too (see the header).
var reads_track: bool = true
## What it did, for tests: {t (fight time), action, why}.
var log: Array[Dictionary] = []

var _handled: Dictionary = {}
var _target: int = -1
var _why: String = ""
## When it last slid under a high sweep (fight time).
var _sweep_slide: float = -10.0
## The stomp window it's taking: {pin (the pin's stern), stage, side, t}.
var _route: Dictionary = {}


func _init(p_head: FloatingHead, p_baits: bool = true) -> void:
	head = p_head
	baits = p_baits


## The City boss step's movement tuning as the campaign plays it (its zone's speed, 21 m/s:
## Campaign.configure_boss, LevelConfig.movement_for), from `base`: the Floating Head's suites fight at it.
static func campaign_tuning(base: MovementTuning) -> MovementTuning:
	var campaign := load("res://data/campaign/campaign.tres") as Campaign
	var step: CampaignStep = campaign.step("city/boss") if campaign != null else null
	return campaign.configure_boss(step, 3).movement_for(base) if step != null else base


func step() -> void:
	var world: RunWorld = head.world
	var player: Player = world.player
	if not player.alive or not player.running:
		return
	if routes and _take_route():
		_walk()
		return
	_dodge_bombs()
	var f: FloatingHeadFaceOff = head.faceoff
	var attack: Dictionary = f.attack
	var kind: StringName = attack.get("kind", &"")
	var id: int = int(attack.get("n", -1))
	if kind == &"low" or kind == &"high":
		if f.step == FloatingHeadFaceOff.Step.FIRE and not _handled.has(id):
			_sweep(attack, kind, id)
	elif kind == &"drag" or kind == &"tower":
		var aiming: bool = f.step == FloatingHeadFaceOff.Step.MOVE or f.step == FloatingHeadFaceOff.Step.WAIT_TOWER \
			or f.step == FloatingHeadFaceOff.Step.CHARGE
		if kind == &"tower" and aiming:
			_line_up_for_tower(attack["tower"])
		elif f.step == FloatingHeadFaceOff.Step.FIRE and attack.has("lane") and not _handled.has(id):
			_handled[id] = true
			_dodge_lane(int(attack["lane"]), "drag")
	_avoid_cyborgs()
	if reads_track:
		_dodge_bolts()
	_walk()
	if reads_track:
		_read_track()


# --- The stomp windows ---------------------------------------------------------------------------

## Takes the pin's way onto its head: true while it's doing so (nothing else steers it then).
func _take_route() -> bool:
	var pinned: bool = head.step == FloatingHead.Step.PIN_FALL or head.step == FloatingHead.Step.PINNED
	if not pinned or head.route == &"":
		_route = {}
		return false
	if wrong_route:
		# Stays down on the trucks: out of the first window's ramp lane, and over the third window's pads
		# with a jump (a pad only lifts a runner on the ground).
		var p: Player = head.world.player
		var ahead: float = head.pad_at - p.distance
		if head.route == &"ceiling" and ahead > 0.0 and ahead < _m(3.5) and p.grounded \
				and not _handled.has("pads %s" % head.pin_stern):
			_handled["pads %s" % head.pin_stern] = true
			_press(&"jump", "over the pads")
		if head.route == &"ramp":
			var ramp_lane: int = head.ramp_lane if head.ramp_lane >= 0 else head.ramp_lane_for(head.pin_side)
			if p.lane == ramp_lane and p.distance < head.pin_stern - head.metres(head.tuning.ramp_length):
				_go(ramp_lane + (1 if ramp_lane < head.lane_count() / 2 else -1), "off the ramp")
		return false
	var player: Player = head.world.player
	if player.distance > head.pass_line():
		return false
	if _route.get("pin", -1.0) != head.pin_stern:
		_route = {"pin": head.pin_stern, "stage": &"lane", "t": 0.0}
	# The drag that clipped the tower still burns down its lane for a moment: first out of its way.
	var burning: int = _burning_lane()
	var to_face: float = head.pin_stern - player.distance
	match head.route:
		&"ramp":
			var lane: int = head.ramp_lane if head.ramp_lane >= 0 else head.ramp_lane_for(head.pin_side)
			if ramp_board_at >= 0.0:
				_board_late(lane, burning)
			elif lane != burning:
				_go(lane, "ramp")
			elif player.lane == burning:
				_dodge_lane(burning, "burn")
		&"wall":
			_wall_route(to_face, burning)
		&"ceiling":
			if player.surface == Player.Surface.CEILING:
				if ceiling_moves:
					_go(_nearest_weak_lane(player.lane), "ceiling")
			elif player.lane == burning:
				_dodge_lane(burning, "burn")
	return true


## The ramp boarded late (`ramp_board_at`), the way the owner's playtest met it: it runs beside the ramp
## in the lane nearer the middle (the other side where there's none) and switches into its lane once
## that share of the ramp is behind it (stepping up its lead-in's bevelled side; E1c's slab bumps).
func _board_late(lane: int, burning: int) -> void:
	var player: Player = head.world.player
	var n: int = head.lane_count()
	var beside: int = lane + (1 if lane * 2 < n - 1 else -1)
	if beside < 0 or beside >= n:
		beside = lane - (1 if lane * 2 < n - 1 else -1)
	var ramp: FloatingHeadRamp = head.ramp
	if ramp == null or not is_instance_valid(ramp) or not ramp.landed:
		if beside != burning:
			_go(beside, "beside the ramp")
		return
	var board_at: float = ramp.foot + (ramp.face - ramp.foot) * ramp_board_at
	var key: String = "board %s" % head.pin_stern
	if player.distance >= board_at and lane != burning and player.lane == beside and not _handled.has(key):
		# One switch into its lane (a slab it can't board bumps it back, and it stays beside it).
		_handled[key] = true
		_target = -1
		_press(&"move_right" if lane > player.lane else &"move_left", "ramp, late")
	elif not _handled.has(key) and player.lane != beside and beside != burning:
		_go(beside, "beside the ramp")
	elif player.lane == burning:
		_dodge_lane(burning, "burn")


## The wall route, by the wall marks (FloatingHeadWallMarks, where they are on the wall): to the outer
## lane by the nearer wall (or `wall_side`), onto the wall ENTER_INTO past where the marks start, and a
## wall jump at the jump mark, inward; one lane further in the air only where the outer lane has no weak
## point and no stomp box reaches it.
func _wall_route(to_face: float, burning: int) -> void:
	var player: Player = head.world.player
	var n: int = head.lane_count()
	if not _route.has("side"):
		var side: int = wall_side
		if side == 0:
			side = -1 if player.lane * 2 < n - 1 else (1 if player.lane * 2 > n - 1 else head.pin_side)
		_route["side"] = side
	var side: int = int(_route["side"])
	var outer: int = 0 if side < 0 else n - 1
	var inward: StringName = &"move_right" if side < 0 else &"move_left"
	match _route["stage"]:
		&"lane":
			if outer != burning:
				_go(outer, "wall")
			elif player.lane == burning:
				_dodge_lane(burning, "burn")
			if player.lane == outer and player.surface == Player.Surface.FLOOR and player.grounded \
					and to_face <= _marks_start() - _m(ENTER_INTO) and outer != burning:
				_target = -1
				_press(&"move_left" if side < 0 else &"move_right", "wall enter")
				_route["stage"] = &"wall"
		&"wall":
			if player.surface == Player.Surface.WALL and to_face <= _jump_mark():
				_press(inward, "wall jump")
				_route["stage"] = &"jumped"
				_route["t"] = head.fight_time()
		&"jumped":
			if second_move and not head.weak_point_lanes().has(outer) and not head.tuning.stomp_covers_outer_lanes \
					and head.fight_time() - float(_route["t"]) >= SECOND_MOVE:
				_press(inward, "onto the weak point")
				_route["stage"] = &"done"


## Where the wall marks start, and their jump mark, as metres before the pinned ship's face (from the
## marks on the wall; the fight's numbers if they aren't lit).
func _marks_start() -> float:
	var marks: FloatingHeadWallMarks = head.wall_marks
	if marks != null and is_instance_valid(marks):
		return head.pin_stern - marks.start
	return head.before_face(head.tuning.wall_entry_before)


func _jump_mark() -> float:
	var marks: FloatingHeadWallMarks = head.wall_marks
	if marks != null and is_instance_valid(marks):
		return head.pin_stern - marks.jump_at
	return head.before_face(head.tuning.wall_jump_before)


## `reference` metres (at 18 m/s) at the run's pace.
func _m(reference: float) -> float:
	return head.metres(reference)


## The lane of the drag's burning line while it still reaches ahead of the runner (-1: none).
func _burning_lane() -> int:
	var player: Player = head.world.player
	for h: Hazard in head.faceoff.laser_hazards():
		if h.hazard_name != FloatingHeadFaceOff.BURN_NAME:
			continue
		var near: float = -h.global_position.z - h.size.z * 0.5
		var far: float = -h.global_position.z + h.size.z * 0.5
		if far > player.distance - 1.0 or near > player.distance - 1.0:
			return clampi(roundi(h.global_position.x / head.world.geo.lane_width + (head.lane_count() - 1) * 0.5),
				0, head.lane_count() - 1)
	return -1


## The weak point's lane nearest `lane`.
func _nearest_weak_lane(lane: int) -> int:
	var best: int = lane
	var dist: int = 1000
	for l: int in head.weak_point_lanes():
		if absi(l - lane) < dist:
			dist = absi(l - lane)
			best = l
	return best


# --- The bombing run -----------------------------------------------------------------------------

## A lock on its lane: to the free lane the rules leave it (once per lock).
func _dodge_bombs() -> void:
	var b: FloatingHeadBombing = head.bombing
	if b.target.is_empty():
		return
	var key: String = "lock %s" % b.target["lock"]
	if _handled.has(key):
		return
	_handled[key] = true
	var pl: int = head.player_lane()
	var lanes: Array[int] = []
	for l: int in b.target["lanes"]:
		lanes.append(l)
	if not lanes.has(pl):
		return
	var e: int = b.escape_lane(lanes, pl, head.world.player.distance, float(b.target["at"]))
	if e >= 0:
		_go(e, "bomb")


# --- The face-off --------------------------------------------------------------------------------

## Jumps at a low sweep's firing cue or slides as a high sweep reaches its spot.
func _sweep(attack: Dictionary, kind: StringName, id: int) -> void:
	var player: Player = head.world.player
	if player.surface != Player.Surface.FLOOR:
		return
	var speed: float = head.faceoff.sweep_speed(kind)
	var dx: float = absf(float(attack["x"]) - player.global_position.x)
	# Just before the beams arrive: a jump is up past them in 0.06 s, a slide down at once.
	var lead: float = 0.3 + speed * (0.16 if kind == &"low" else 0.1)
	if kind == &"high" and dx > lead:
		return
	_handled[id] = true
	var jump: bool = kind == &"low"
	if wrong == kind:
		jump = not jump
	if not jump:
		_sweep_slide = head.fight_time()
	_press(&"jump" if jump else &"slide", String(kind))


## Out of a committed drag's lane into the free lane the fairness rules keep.
func _dodge_lane(lane: int, why: String) -> void:
	var pl: int = head.player_lane()
	if pl != lane:
		return
	var d0: float = head.world.player.distance
	var lanes: Array[int] = [lane]
	var e: int = head.escape_lane(lanes, pl, d0, d0 + _m(45.0), true)
	if e < 0:
		e = pl + (1 if pl < head.lane_count() - 1 else -1)
	_go(e, why)


## A marked tower's drag is aiming: to the tower's outer lane (a bait), or out of it.
func _line_up_for_tower(tower: Dictionary) -> void:
	var outer: int = 0 if int(tower["side"]) < 0 else head.lane_count() - 1
	if baits:
		_go(outer, "bait")
	elif head.player_lane() == outer or _target == outer:
		_go(outer + (1 if outer == 0 else -1), "avoid tower")


## Out of the lane of a dropped cyborg ahead, and out of the line of its burst once its aim locks (the
## end of its charge-up: its bolts fly along that line).
func _avoid_cyborgs() -> void:
	var player: Player = head.world.player
	if player.surface != Player.Surface.FLOOR:
		return
	for e: Enemy in head.faceoff.dropped():
		var c := e as Cyborg
		if c == null or c.gun == null:
			continue
		var charges: int = 0
		for ev: Dictionary in c.gun.events:
			if ev["event"] == &"charge":
				charges += 1
		var burst: String = "%d:%d" % [c.get_instance_id(), charges]
		if c.gun.state == CyborgGun.State.FIRING and not _handled.has(burst):
			_handled[burst] = true
			var n: int = head.lane_count()
			for s: int in [1, -1]:
				var to: int = player.lane + s
				if to >= 0 and to < n and not _cyborg_in(to, player.distance, player.distance + _m(30.0)):
					_go(to, "bolts")
					break
	var lane: int = _target if _target >= 0 else player.lane
	if not _cyborg_in(lane, player.distance, player.distance + _m(30.0)):
		return
	var n: int = head.lane_count()
	for s: int in [1, -1, 2, -2]:
		var to: int = lane + s
		if to >= 0 and to < n and not _cyborg_in(to, player.distance, player.distance + _m(30.0)):
			_go(to, "cyborg")
			return


## The arena's own holes and fences in the lane it runs in (or is moving to), read like any runner:
## a hole or a full fence is jumped (a fence so the jump's arc is highest over it), a gapped fence slid
## under. Pulsing fences count as always on.
func _read_track() -> void:
	var player: Player = head.world.player
	if head.arena == null or player.surface != Player.Surface.FLOOR or not player.grounded:
		return
	var d: float = player.distance
	var lanes: Array[int] = [player.lane]
	if _target >= 0 and _target != player.lane:
		lanes.append(_target)
	var layout: LevelLayout = head.arena.layout
	# Sliding: under a gapped fence it stays down; under a high sweep it may jump out once it's past.
	var can_jump: bool = not player.is_sliding() or head.fight_time() - _sweep_slide >= SWEEP_PASSED
	for f: Dictionary in layout.fences:
		if lanes.has(int(f["lane"])) and f["variant"] == "gapped" and absf(float(f["at"]) - d - 0.5) <= 1.5:
			can_jump = false
	for g: Dictionary in layout.gaps:
		var ahead: float = float(g["start"]) - d
		if lanes.has(int(g["lane"])) and ahead > -0.2 and ahead <= _m(HOLE_LEAD):
			if can_jump:
				_press(&"jump", "hole")
			return
	for f: Dictionary in layout.fences:
		if not lanes.has(int(f["lane"])) or f.get("disabled", false):
			continue
		var ahead: float = float(f["at"]) - d
		if f["variant"] == "gapped":
			if ahead > 0.0 and ahead <= _m(FENCE_SLIDE_LEAD) and not player.is_sliding():
				_press(&"slide", "gapped fence")
				return
		elif ahead > _m(FENCE_JUMP_LAST) and ahead <= _m(FENCE_JUMP_LEAD):
			if can_jump:
				_press(&"jump", "fence")
			return


## Bolts in the air (a dropped cyborg's, wild ones too): one that would cross its spot within
## BOLT_REACT seconds, less than BOLT_REACH to the side, sends it to the nearest lane no bolt is heading
## for (like a player watching the bolts).
func _dodge_bolts() -> void:
	var world: RunWorld = head.world
	var player: Player = world.player
	if player.surface != Player.Surface.FLOOR:
		return
	var lane: int = _target if _target >= 0 else player.lane
	if not _bolt_toward(lane):
		return
	for s: int in [1, -1, 2, -2]:
		var to: int = lane + s
		if to >= 0 and to < head.lane_count() and not _bolt_toward(to) \
				and not _cyborg_in(to, player.distance, player.distance + _m(30.0)) \
				and head.floor_clear_lane(to, player.distance, player.distance + _m(12.0)):
			_go(to, "bolt")
			return


## True if a hostile bolt will cross the runner's spot in `lane` soon (see _dodge_bolts).
func _bolt_toward(lane: int) -> bool:
	var world: RunWorld = head.world
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


func _cyborg_in(lane: int, from: float, to: float) -> bool:
	for e: Enemy in head.faceoff.dropped():
		if int(e.spawn.get("lane", -1)) == lane \
				and e.track_distance() >= from and e.track_distance() <= to:
			return true
	return false


func _go(lane: int, why: String) -> void:
	_target = clampi(lane, 0, head.lane_count() - 1)
	_why = why


## One lane a frame toward the lane it's heading for (on the trucks or the ceiling).
func _walk() -> void:
	var player: Player = head.world.player
	if _target < 0 or player.surface == Player.Surface.WALL:
		return
	var pl: int = player.lane
	if pl == _target:
		_target = -1
		return
	_press(&"move_right" if _target > pl else &"move_left", _why)


func _press(action: StringName, why: String) -> void:
	head.world.player.press(action)
	log.append({"t": head.fight_time(), "action": action, "why": why})
