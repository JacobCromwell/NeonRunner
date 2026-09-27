class_name FloatingHeadBot
extends RefCounted
## A runner who plays the Floating Head's face-off by its warnings, for tests and reviews
## (tools/showcase/floating_head_showcase.gd). Call step() every physics frame. It only presses the
## player's named actions, and only reacts to what the fight shows (an attack's kind, height, lane and
## where its beams are), the way a player reads the warnings:
## - a sweep: jumps a low one, slides under a high one, as the beams reach its spot;
## - a drag: once its lane is committed (the red lane warning), switches to the free lane the fairness
##   rules keep (FloatingHead.escape_lane);
## - a marked tower: with `baits` on, moves to the outer lane on the tower's side while the drag aims,
##   and dodges only once it's committed (the bait); with `baits` off, keeps out of that lane;
## - dropped cyborgs: keeps out of the lane of one ahead of it.
## With `wrong` set to a sweep kind (&"low" or &"high"), it answers that kind the wrong way (slides
## under a low sweep, jumps a high one), to show the answer matters.

var head: FloatingHead
var baits: bool = true
var wrong: StringName = &""
## What it did, for tests: {t (fight time), action, why}.
var log: Array[Dictionary] = []

var _handled: Dictionary = {}
var _target: int = -1
var _why: String = ""


func _init(p_head: FloatingHead, p_baits: bool = true) -> void:
	head = p_head
	baits = p_baits


func step() -> void:
	var world: RunWorld = head.world
	var player: Player = world.player
	if not player.alive or not player.running:
		return
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
	_walk()


## Jumps or slides as the beams reach its spot.
func _sweep(attack: Dictionary, kind: StringName, id: int) -> void:
	var player: Player = head.world.player
	if player.surface != Player.Surface.FLOOR:
		return
	var speed: float = head.tuning.laser_sweep_speed * head.pace()
	var dx: float = absf(float(attack["x"]) - player.global_position.x)
	# Just before the beams arrive: a jump is up past them in 0.06 s, a slide down at once.
	var lead: float = 0.3 + speed * (0.16 if kind == &"low" else 0.1)
	if dx > lead:
		return
	_handled[id] = true
	var jump: bool = kind == &"low"
	if wrong == kind:
		jump = not jump
	_press(&"jump" if jump else &"slide", String(kind))


## Out of a committed drag's lane into the free lane the fairness rules keep.
func _dodge_lane(lane: int, why: String) -> void:
	var pl: int = head.player_lane()
	if pl != lane:
		return
	var d0: float = head.world.player.distance
	var lanes: Array[int] = [lane]
	var e: int = head.escape_lane(lanes, pl, d0, d0 + 45.0, true)
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
				if to >= 0 and to < n and not _cyborg_in(to, player.distance, player.distance + 30.0):
					_go(to, "bolts")
					break
	var lane: int = _target if _target >= 0 else player.lane
	if not _cyborg_in(lane, player.distance, player.distance + 30.0):
		return
	var n: int = head.lane_count()
	for s: int in [1, -1, 2, -2]:
		var to: int = lane + s
		if to >= 0 and to < n and not _cyborg_in(to, player.distance, player.distance + 30.0):
			_go(to, "cyborg")
			return


func _cyborg_in(lane: int, from: float, to: float) -> bool:
	for e: Enemy in head.faceoff.dropped():
		if int(e.spawn.get("lane", -1)) == lane \
				and e.track_distance() >= from and e.track_distance() <= to:
			return true
	return false


func _go(lane: int, why: String) -> void:
	_target = clampi(lane, 0, head.lane_count() - 1)
	_why = why


## One lane a frame toward the lane it's heading for.
func _walk() -> void:
	var player: Player = head.world.player
	if _target < 0 or player.surface != Player.Surface.FLOOR:
		return
	var pl: int = player.lane
	if pl == _target:
		_target = -1
		return
	_press(&"move_right" if _target > pl else &"move_left", _why)


func _press(action: StringName, why: String) -> void:
	head.world.player.press(action)
	log.append({"t": head.fight_time(), "action": action, "why": why})
