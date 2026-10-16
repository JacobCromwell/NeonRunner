class_name GanglandIntro
extends CinematicSequencer
## Gangland's intro, before Gangland 1 (the owner's story beats, October 16, 2026), after the City outro drops the
## runner into the zone.
## 1. At human height behind the runner, who walks up to a fork in the road and stops: a street goes off to the left
##    and one to the right, and a building closes the road ahead. They look left.
## 2. Cut down the left-hand street: at ground level the camera tilts up to two cyborg gangsters in Gangland's look
##    with a large Octodog between them, looking off to the right. It pans right to another gang: three cyborgs in
##    Gangland's look, one in the Marketplace's and, in the middle, a little forward and leading them, one in the
##    Casino's look; a hover truck parked behind them. It pans back and out to show both.
## 3. They yell at each other. The leader raises its arm cannon, charges it (the red glow, a cyborg's warning in
##    play) and fires: the bolt zips between a cyborg and the Octodog and bursts on the street behind them. The left
##    gang gets angry; their Octodog rears up (its wind-up), charges, bowls one cyborg over and pounces on another,
##    and the cyborgs left standing open fire.
## 4. Cut back to the runner, the fight going on round the corner: they turn slowly to the right, their left hand
##    coming up over their face (the side toward the fight), and walk off down the right-hand street. Black, and
##    Gangland 1.
##
## A script on the toolkit, its numbers data (`numbers`, by default data/cinematics/gangland_intro_tuning.tres,
## GanglandIntroTuning). The street is the zone's own look and lanes (CineStage.skin_for); the side streets, the
## buildings closing the fork, the Octodog, the hover truck and the shots are this cinematic's props (GanglandIntroSet),
## built on the stage so they hide with it and moved by the clock. The cyborgs are the timeline's actors, in the
## looks of the zones' own data (an "@zone" look is that zone's cyborgs'). DESIGN-TBD (docs/questions/f2f.md): what
## the owner's beats leave open.

const NUMBERS_PATH: String = "res://data/cinematics/gangland_intro_tuning.tres"
## A yell: how long the yeller's head bobs and how far (degrees up and down), and how often.
const YELL_SECONDS: float = 0.85
const YELL_BOB := Vector2(7.0, -4.0)
const YELL_STEP: float = 0.14
## The furthest a cyborg turns its head from its body to look at someone (degrees).
const MAX_LOOK: float = 70.0
## The left hand over the face: the wrist this far in front of the face (metres), out to the left and down, the
## elbow bending down and out.
const HAND_AHEAD: float = 0.13
const HAND_OUT: float = 0.07
const HAND_DOWN: float = 0.02
## The Octodog stops this far short of the first cyborg it bowls over (metres), and lands this far up on the one it
## pounces on.
const DOG_REACH: float = 0.55
const DOG_ON_TOP: float = 0.12
## The bolts of the firefight: how far past their mark the misses fly (metres), and the share that hit their mark.
const MISS_RANGE := Vector2(6.0, 11.0)
const HIT_SHARE: float = 0.35

## Its numbers (null: NUMBERS_PATH's).
@export var numbers: GanglandIntroTuning

## The numbers playing (numbers, or NUMBERS_PATH's).
var n: GanglandIntroTuning
var props: GanglandIntroSet
## Where the runner stands at the fork (track space), and when they turn and start walking.
var stand := Vector3.ZERO
var t_turn: float = 0.0
var t_walk: float = 0.0
## When the Octodog bowls the first cyborg over and pounces on the second.
var t_hit: float = 0.0
var t_pounce: float = 0.0
## The two cyborgs it tackles (actor ids) and where they end up (track space).
var tackled: Array[StringName] = []
var tackle_ends: Array[Vector3] = []
## How far the runner's left hand is up over their face now (0-1; tests).
var hand_up: float = 0.0

var _dog_last := Vector3.ZERO
var _dog_started: bool = false


func _numbers() -> GanglandIntroTuning:
	if numbers == null:
		numbers = load(NUMBERS_PATH) as GanglandIntroTuning
	return numbers


func _stage_def() -> CineStageDef:
	n = _numbers()
	var d := CineStageDef.new()
	d.length = n.stage_length
	var half: float = side_half()
	d.wall_gaps = PackedVector3Array([Vector3(-1.0, n.junction_at - half, n.junction_at + half),
		Vector3(1.0, n.junction_at - half, n.junction_at + half)])
	return d


## Half a side street's width, to its building fronts (metres).
func side_half() -> float:
	return n.side_lanes * tuning.lane_width * 0.5 + n.side_margin


## A point in the left-hand street in track space: `u` metres in from the main street's left wall face, `v` along the
## main street from the junction's middle, `y` up.
func gang(u: float, v: float, y: float = 0.0) -> Vector3:
	return Vector3(stage.wall_x(-1) - u, y, n.junction_at + v)


func _make_timeline() -> CineTimeline:
	stand = Vector3(0.0, 0.0, n.junction_at + n.stand_v)
	t_turn = n.back_at + n.turn_after
	t_walk = t_turn + n.walk_after
	t_hit = n.charge_at + n.charge_seconds
	t_pounce = t_hit + n.pounce_seconds
	var t := CineTimeline.new()
	t.duration = n.duration
	t.letterbox = true
	props = GanglandIntroSet.new()
	stage.add_child(props)
	props.setup(self)
	_add_runner(t)
	_add_gangs(t)
	_add_camera(t)
	_add_events(t)
	return t


# --- The runner ----------------------------------------------------------------------------------

## DESIGN-TBD (docs/questions/f2f.md, 1 and 9): they walk the last metres up to the fork and stop; later they turn
## slowly to the right and walk off down the right-hand street, head down a little.
func _add_runner(t: CineTimeline) -> void:
	var r: CineActor = t.actor(&"runner")
	r.turn_rate = n.turn_rate
	r.at(0.0, stand - Vector3(0.0, 0.0, n.walk_from), &"walk")
	_eased(r.at(n.stop_at, stand), Tween.TRANS_SINE, Tween.EASE_OUT)
	# They look left down the side street, their body turning a little with their head; held through the gangs' scene.
	_turned(r.at(n.look_at, stand), 0.0, 0.0)
	_turned(_eased(r.at(n.look_at + n.look_seconds, stand)), n.look_body_degrees, n.look_degrees)
	_turned(r.at(t_turn, stand), n.look_body_degrees, n.look_degrees)
	# The slow turn to the right (their turn rate eases the body round), the head leading, tipped down behind the hand.
	_turned(r.at(t_turn + 0.02, stand), n.turn_degrees, n.look_degrees)
	_turned(_eased(r.at(t_turn + 0.9, stand)), n.turn_degrees, -8.0).look_up = -10.0
	_turned(r.at(t_walk, stand), n.turn_degrees, -4.0).look_up = -10.0
	# And off down the right-hand street, speeding up to a walk.
	var dest := Vector3(stage.wall_x(1) + n.walk_u, 0.0, n.junction_at)
	var dir: Vector3 = (dest - stand).normalized()
	var ramp: float = 0.8
	var k: CineActorKey = _eased(r.at(t_walk + ramp, stand + dir * n.walk_speed * ramp * 0.5), Tween.TRANS_QUAD,
		Tween.EASE_IN)
	k.look = -4.0
	k.look_up = -10.0
	var away: float = maxf(n.duration - t_walk - ramp, 0.1)
	var off: CineActorKey = r.at(n.duration, stand + dir * n.walk_speed * (ramp * 0.5 + away))
	off.look = -4.0
	off.look_up = -10.0


## A key eased in and out (a LINEAR move with a sine curve), or with the curve given.
static func _eased(k: CineActorKey, trans: Tween.TransitionType = Tween.TRANS_SINE,
		easing: Tween.EaseType = Tween.EASE_IN_OUT) -> CineActorKey:
	k.trans = trans
	k.easing = easing
	return k


## A key that holds a heading (`body` degrees, + left) and a look (`head` degrees, + left).
static func _turned(k: CineActorKey, body: float, head: float) -> CineActorKey:
	k.face_path = false
	k.yaw = body
	k.look = head
	return k


# --- The gangs -----------------------------------------------------------------------------------

func _add_gangs(t: CineTimeline) -> void:
	var leader_pos: Vector3 = gang(n.leader_at.x, n.leader_at.y)
	var lefts: Array[CineActor] = []
	for i: int in n.left_cyborgs.size():
		var c: Vector3 = n.left_cyborgs[i]
		lefts.append(_cyborg(t, StringName("left_%d" % (i + 1)), &"", gang(c.x, c.y), 90.0 - c.z, leader_pos))
	var leader: CineActor = _cyborg(t, &"leader", n.leader_look, leader_pos, -90.0 + n.leader_at.z,
		gang(n.left_cyborgs[0].x, n.left_cyborgs[0].y))
	var rights: Array[CineActor] = []
	for i: int in n.right_cyborgs.size():
		var c: Vector3 = n.right_cyborgs[i]
		var look: StringName = n.right_looks[i] if i < n.right_looks.size() else &""
		var mark: Vector3 = n.left_cyborgs[i % n.left_cyborgs.size()]
		rights.append(_cyborg(t, StringName("right_%d" % (i + 1)), look, gang(c.x, c.y), -90.0 + c.z, gang(mark.x, mark.y)))
	_yelling(t, lefts, leader, rights)
	_charge(t, leader, rights)
	_firefight(t, lefts, leader, rights)


## A cyborg standing at `at` (track space), its body turned to `yaw` degrees, looking at `mark`: in look `look` (a
## CyborgSuit look, "@zone" for that zone's cyborgs', or empty for this zone's).
func _cyborg(t: CineTimeline, id: StringName, look: StringName, at: Vector3, yaw: float, mark: Vector3) -> CineActor:
	var c: CineActor = t.actor(id, CineActor.Kind.CYBORG, resolve_look(look))
	var k: CineActorKey = _hold(c, 0.0, at, yaw, _look_at(at, yaw, mark), &"idle")
	k.expression = &"neutral"
	k.charge = 0.0
	return c


## A cyborg's key holding `yaw` and a head turn (`look`), from `time`.
static func _hold(c: CineActor, time: float, at: Vector3, yaw: float, look: float, pose: StringName = &"") -> CineActorKey:
	var k: CineActorKey = c.at(time, at, pose)
	k.face_path = false
	k.yaw = yaw
	k.look = look
	return k


## The head turn (degrees, + left) for a body at `at` facing `yaw` to look at `mark`, as far as a neck turns.
static func _look_at(at: Vector3, yaw: float, mark: Vector3) -> float:
	var bearing: float = rad_to_deg(atan2(-(mark.x - at.x), mark.z - at.z))
	return clampf(rad_to_deg(angle_difference(deg_to_rad(yaw), deg_to_rad(bearing))), -MAX_LOOK, MAX_LOOK)


## The look of a cyborg: "@<zone id>" is that zone's cyborgs' (its skin's enemy look), so a change of the zones' data
## reaches it; anything else is a look's own name (empty: this zone's).
func resolve_look(look: StringName) -> StringName:
	var text: String = String(look)
	if not text.begins_with("@"):
		return look
	var app: Node = get_node_or_null(^"/root/App")
	var campaign := app.get(&"campaign") as Campaign if app != null else null
	if campaign != null:
		for z: ZoneDef in campaign.zones:
			if String(z.id) == text.substr(1) and z.skin != null:
				return z.skin.enemy_variant
	return CyborgSuit.CASINO


## The last key of a cyborg at or before `time` (its place, heading and look go on from there).
static func _last(c: CineActor, time: float) -> CineActorKey:
	var best: CineActorKey = c.keys[0]
	for k: CineActorKey in c.keys:
		if k.time <= time and k.time >= best.time:
			best = k
	return best


## A key at `time` carrying on from the cyborg's last (same place, heading and look), for a change of pose or face.
static func _then(c: CineActor, time: float, pose: StringName = &"") -> CineActorKey:
	var last: CineActorKey = _last(c, time)
	return _hold(c, time, last.position, last.yaw, last.look, pose)


## A yell: the cyborg points its arm cannon at `at_id` (a gesture: no charge) and its head bobs as it shouts.
func _yell(c: CineActor, time: float, at_id: StringName, keep_aim: bool = false) -> void:
	var k: CineActorKey = _then(c, time, &"aim")
	k.aim_at = at_id
	k.expression = &"aiming"
	var steps: int = int(YELL_SECONDS / YELL_STEP)
	for i: int in range(1, steps + 1):
		_then(c, time + i * YELL_STEP).look_up = YELL_BOB.x if i % 2 == 1 else YELL_BOB.y
	_then(c, time + (steps + 1) * YELL_STEP).look_up = 0.0
	if not keep_aim:
		var down: CineActorKey = _then(c, time + (steps + 2) * YELL_STEP, &"idle")
		down.aim_at = &"none"


## They yell at each other; the leader charges its arm cannon and fires a shot that misses; the left gang gets angry.
## DESIGN-TBD (docs/questions/f2f.md, 5 and 6): three yells, each yeller pointing its cannon (no charge); the miss
## zips between a left cyborg and the Octodog.
func _yelling(t: CineTimeline, lefts: Array[CineActor], leader: CineActor, rights: Array[CineActor]) -> void:
	var y: PackedFloat32Array = n.yells
	if y.size() > 0:
		_yell(lefts[0], y[0], &"leader")
	if y.size() > 1:
		_yell(leader, y[1], &"left_1", true)
		# The leader's gang backs it up, arm cannons raised.
		for i: int in rights.size():
			var up: CineActorKey = _then(rights[i], y[1] + 0.25 + 0.12 * i, &"aim")
			up.aim_at = StringName("left_%d" % (i % lefts.size() + 1))
	if y.size() > 2:
		_yell(lefts[lefts.size() - 1], y[2], &"leader")
	# The leader's shot: its cannon charges (the red glow) and fires.
	_then(leader, n.aim_at).charge = 0.35
	_then(leader, lerpf(n.aim_at, n.shot_at, 0.6)).charge = 0.75
	_then(leader, n.shot_at - 0.05).charge = 1.0
	_then(leader, n.shot_at + 0.08).charge = 0.0
	# It zips past: the left gang flinches, looks round at where it burst, then rounds on the leader.
	for c: CineActor in lefts:
		var last: CineActorKey = _last(c, n.shot_at)
		var flinch: CineActorKey = _then(c, n.shot_at + 0.05, &"idle")
		flinch.aim_at = &"none"
		flinch.expression = &"shocked"
		flinch.look = _look_at(last.position, last.yaw, gang(n.miss_at.x, n.miss_at.z))
		var angry: CineActorKey = _then(c, n.angry_at, &"aim")
		angry.look = _look_at(last.position, last.yaw, gang(n.leader_at.x, n.leader_at.y))
		angry.aim_at = &"leader"
		angry.expression = &"aiming"


## The Octodog's charge: the leader throws itself out of its way; it bowls the first cyborg over and pounces on the
## next, who goes down under it. DESIGN-TBD (docs/questions/f2f.md, 7): who it tackles, and that nobody dies on screen.
func _charge(_t: CineTimeline, leader: CineActor, rights: Array[CineActor]) -> void:
	var dodge: CineActorKey = _then(leader, n.charge_at + 0.08, &"cower")
	dodge.aim_at = &"none"
	dodge.expression = &"shocked"
	var from: Vector3 = dodge.position
	var aside := Vector3(0.0, 0.0, 1.3)
	_hold(leader, n.charge_at + 0.28, from + aside * 0.6 + Vector3(0.0, 0.35, 0.0), dodge.yaw, dodge.look)
	_eased(_hold(leader, n.charge_at + 0.5, from + aside, dodge.yaw, dodge.look), Tween.TRANS_QUAD, Tween.EASE_IN)
	tackled.clear()
	tackle_ends.clear()
	var dog_from: Vector3 = gang(n.dog_at.x, n.dog_at.y)
	for j: int in mini(n.tackles.size(), 2):
		var index: int = n.tackles[j]
		if index < 0 or index >= rights.size():
			continue
		var c: CineActor = rights[index]
		var at: CineActorKey = _last(c, n.charge_at)
		var hit: float = t_hit if j == 0 else t_pounce
		var push: Vector3 = at.position - dog_from
		push.y = 0.0
		push = push.normalized()
		var scared: CineActorKey = _then(c, hit - 0.15)
		scared.expression = &"shocked"
		scared.aim_at = &"none"
		# Thrown back off its feet (bowled over) or knocked flat under the dog (the pounce), out cold.
		var far: float = n.throw_distance if j == 0 else n.throw_distance * 0.35
		var lift: float = n.throw_height if j == 0 else n.throw_height * 0.3
		var down: CineActorKey = _hold(c, hit, at.position, at.yaw, 0.0, &"lie")
		down.aim_at = &"none"
		_hold(c, hit + 0.2, at.position + push * far * 0.6 + Vector3(0.0, lift, 0.0), at.yaw, 0.0)
		var end: Vector3 = at.position + push * far
		_eased(_hold(c, hit + 0.42, end, at.yaw, 0.0), Tween.TRANS_QUAD, Tween.EASE_IN)
		tackled.append(c.id)
		tackle_ends.append(end)
		dog_from = at.position


## Those left standing open fire: the right gang at the left, the left gang back. DESIGN-TBD (docs/questions/f2f.md, 8).
func _firefight(t: CineTimeline, lefts: Array[CineActor], leader: CineActor, rights: Array[CineActor]) -> void:
	var shooters: Array[CineActor] = [leader]
	for c: CineActor in rights:
		if not tackled.has(c.id):
			shooters.append(c)
	for i: int in shooters.size():
		var c: CineActor = shooters[i]
		var k: CineActorKey = _then(c, n.fire_at - 0.55 + 0.07 * i, &"aim")
		k.aim_at = lefts[i % lefts.size()].id
		k.expression = &"aiming"
		k.charge = 0.8
	for i: int in lefts.size():
		var k: CineActorKey = _then(lefts[i], n.fire_at - 0.2 + 0.1 * i, &"aim")
		k.aim_at = shooters[i % shooters.size()].id
		k.charge = 0.8
	for i: int in shooters.size():
		for b: int in n.bolts_each:
			t.sound(_launch(i, b), &"cyborg_shot", -4.0 - 2.0 * (i % 2))
	for i: int in lefts.size():
		for b: int in n.bolts_each:
			t.sound(_launch(shooters.size() + i, b), &"cyborg_shot", -5.0)


## When shooter `i` (the right gang's first, then the left's) fires its bolt `b` (seconds).
func _launch(i: int, b: int) -> float:
	return n.fire_at + 0.11 * i + b * n.bolt_interval + 0.04 * ((i * 7 + b * 3) % 5)


# --- The camera ----------------------------------------------------------------------------------

func _add_camera(t: CineTimeline) -> void:
	# At human height behind the runner as they walk up to the fork, riding along; turning a little with their look.
	_ride(t.shot(0.0, Vector3(n.behind_side, n.eye_height, -n.behind), Vector3(0.0, 1.35, 7.0),
		CinePath.Move.SMOOTH, n.fov))
	_ride(t.shot(n.look_at, Vector3(n.behind_side, n.eye_height, -n.behind), Vector3(-0.4, 1.35, 7.0),
		CinePath.Move.SMOOTH, n.fov))
	_ride(t.shot(n.gang_at - 0.02, Vector3(n.behind_side + 0.15, n.eye_height, -n.behind + 0.35),
		Vector3(-3.6, 1.4, 5.0), CinePath.Move.SMOOTH, n.fov))
	# Cut down the left-hand street: at ground level, tilting up the left gang from their feet.
	var left_mid := Vector3.ZERO
	for c: Vector3 in n.left_cyborgs:
		left_mid += Vector3(c.x, 0.0, c.y)
	left_mid = (left_mid + Vector3(n.dog_at.x, 0.0, n.dog_at.y)) / float(n.left_cyborgs.size() + 1)
	var right_mid := Vector3(n.leader_at.x, 0.0, n.leader_at.y)
	for c: Vector3 in n.right_cyborgs:
		right_mid += Vector3(c.x, 0.0, c.y)
	right_mid /= float(n.right_cyborgs.size() + 1)
	var low: Vector3 = gang(n.ground_eye.x, n.ground_eye.y, n.ground_height)
	t.shot(n.gang_at, low, gang(left_mid.x, left_mid.z, 0.2), CinePath.Move.CUT, n.fov)
	_pan(t.shot(n.tilt_end, low + Vector3(0.0, 0.02, -0.25), gang(left_mid.x, left_mid.z, 1.45), CinePath.Move.LINEAR,
		n.fov))
	_still(t.shot(n.pan_at, low + Vector3(0.0, 0.03, -0.3), gang(left_mid.x, left_mid.z, 1.5), CinePath.Move.LINEAR, n.fov))
	# The pan right to the other gang, the truck behind them.
	var pan_eye: Vector3 = gang(n.pan_eye.x, n.pan_eye.y, n.pan_eye.z)
	_pan(t.shot(n.pan_at + n.pan_seconds, pan_eye, gang(right_mid.x, right_mid.z, 1.35), CinePath.Move.LINEAR, n.fov))
	_still(t.shot(n.wide_at, pan_eye + Vector3(0.0, 0.03, -0.25), gang(right_mid.x + 0.3, right_mid.z, 1.4),
		CinePath.Move.LINEAR, n.fov))
	# Pulling back past the left gang's shoulder to show both, held through the yelling and the shot, edging in.
	var wide: Vector3 = gang(n.wide_eye.x, n.wide_eye.y, n.wide_eye.z)
	var both: Vector3 = gang(n.wide_look.x, n.wide_look.y, n.wide_look.z)
	_pan(t.shot(n.wide_at + n.wide_seconds, wide, both, CinePath.Move.LINEAR, n.wide_fov))
	var nearer: Vector3 = wide + (both - wide).normalized() * 0.7
	_still(t.shot(n.charge_cut - 0.02, nearer, both, CinePath.Move.LINEAR, n.wide_fov - 2.0))
	# Cut: low by the right gang's flank as the Octodog charges in, following it into them, then the firefight.
	var charge: Vector3 = gang(n.charge_eye.x, n.charge_eye.y, n.charge_eye.z)
	var dog_home: Vector3 = gang(n.dog_at.x, n.dog_at.y, 0.9)
	t.shot(n.charge_cut, charge, dog_home, CinePath.Move.CUT, n.fov)
	_still(t.shot(n.charge_at, charge, dog_home, CinePath.Move.LINEAR, n.fov))
	var brawl: Vector3 = gang(right_mid.x - 0.6, right_mid.z, 0.85)
	_pan(t.shot(t_pounce, charge + Vector3(0.0, 0.05, 0.0), brawl, CinePath.Move.LINEAR, n.fov))
	_still(t.shot(n.back_at - 0.02, charge + Vector3(0.0, 0.05, 0.4), gang(left_mid.x * 0.4 + right_mid.x * 0.6,
		right_mid.z, 1.0), CinePath.Move.LINEAR, n.wide_fov - 4.0))
	# Cut back to the runner, from their left: they turn their back on the camera and the fight, the hand coming up on
	# that side, and walk off down the right-hand street, the camera watching them go.
	var back: Vector3 = stand + n.back_eye
	var first: CineCameraKey = t.shot(n.back_at, back, Vector3(0.0, 1.3, 0.0), CinePath.Move.CUT, n.fov)
	first.watch = &"runner"
	var go: CineCameraKey = t.shot(t_walk, back, Vector3(0.0, 1.3, 0.0), CinePath.Move.SMOOTH, n.fov)
	go.watch = &"runner"
	var gone: CineCameraKey = t.shot(n.duration, back + Vector3(0.6, 0.0, -0.3), Vector3(0.0, 1.2, 0.0),
		CinePath.Move.SMOOTH, n.fov - 4.0)
	gone.watch = &"runner"


## A pan: eased in and out (a LINEAR move with a sine curve).
static func _pan(k: CineCameraKey) -> CineCameraKey:
	k.trans = Tween.TRANS_SINE
	k.easing = Tween.EASE_IN_OUT
	return k


## A slow, steady drift into this key (a hold that never quite stops).
static func _still(k: CineCameraKey) -> CineCameraKey:
	k.trans = Tween.TRANS_LINEAR
	return k


## The key rides along with the runner (its position and target are offsets from them).
static func _ride(k: CineCameraKey) -> CineCameraKey:
	k.follow = &"runner"
	k.watch = &"runner"
	return k


# --- Sounds, effects and cues --------------------------------------------------------------------

## DESIGN-TBD (docs/questions/f2f.md, 10): no title card naming the zone (the arrival flyover had one).
func _add_events(t: CineTimeline) -> void:
	t.effect(0.0, CineEvent.FADE_IN, n.fade_in)
	t.music(0.0, CineEvent.ZONE_MUSIC, n.music_fade)
	var voices: Array[StringName] = [&"gang_taunt", &"gang_retort", &"gang_jeer"]
	for i: int in mini(n.yells.size(), voices.size()):
		t.sound(n.yells[i], voices[i])
	t.sound(n.aim_at, &"cyborg_charge")
	t.sound(n.shot_at, &"cyborg_shot")
	t.cue(n.shot_at, &"miss")
	t.sound(n.shot_at + n.shot_seconds, &"enemy_hit", -3.0)
	t.sound(n.angry_at, &"gang_rage")
	t.sound(n.windup_at, &"octodog_windup")
	t.sound(n.charge_at, &"octodog_lunge")
	t.sound(t_hit, &"octodog_tackle")
	t.effect(t_hit, CineEvent.SHAKE, 0.35, 0.25)
	t.sound(t_pounce, &"octodog_tackle", -2.0)
	t.effect(t_pounce, CineEvent.SHAKE, 0.3, 0.2)
	t.sound(n.fire_at - 0.5, &"cyborg_charge", -3.0)
	t.cue(n.fire_at - 0.6, &"open_fire")
	# Round the corner, the fight goes on while the runner turns away: shots further off, thinning out.
	var at: float = n.back_at + 0.35
	var k: int = 0
	while at < n.duration - n.fade_out * 0.5:
		t.sound(at, &"cyborg_shot", -13.0 - 1.5 * float(k % 3) - 0.8 * float(k))
		at += 0.3 + 0.17 * float((k * 5) % 4)
		k += 1
	t.effect(n.duration - n.fade_out, CineEvent.FADE_OUT, n.fade_out)


func _on_cue(cue_name: StringName) -> void:
	match cue_name:
		&"miss":
			var leader := actors.get(&"leader") as CineActorNode
			var from: Vector3 = leader.body.muzzle_position() if leader != null and leader.body != null \
				else stage.point(gang(n.leader_at.x, n.leader_at.y, 1.2))
			props.add_bolt(from, stage.point(gang(n.miss_at.x, n.miss_at.z, n.miss_at.y)), n.shot_at, n.shot_seconds)
		&"open_fire":
			_open_fire()


## The firefight's bolts, from each shooter's arm cannon at its mark (the other gang's cyborg it aims at): some hit,
## bursting on them, the rest fly past and burst on the street or the walls beyond. Fixed by a seed, so every
## playing is the same.
func _open_fire() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7151
	var ids: Array[StringName] = []
	var marks: Array[StringName] = []
	for a: CineActor in playing.actors:
		if a.kind != CineActor.Kind.CYBORG or tackled.has(a.id):
			continue
		var aim: StringName = &""
		for k: CineActorKey in a.keys:
			if k.time <= n.fire_at and k.aim_at != &"":
				aim = k.aim_at
		if aim != &"" and aim != &"none":
			ids.append(a.id)
			marks.append(aim)
	# The right gang fires first (the order _launch counts them in), then the left.
	var order: Array[int] = []
	for i: int in ids.size():
		if not String(ids[i]).begins_with("left_"):
			order.append(i)
	for i: int in ids.size():
		if String(ids[i]).begins_with("left_"):
			order.append(i)
	for s: int in order.size():
		var shooter := actors.get(ids[order[s]]) as CineActorNode
		var mark := actors.get(marks[order[s]]) as CineActorNode
		if shooter == null or mark == null or shooter.body == null:
			continue
		var from: Vector3 = shooter.body.muzzle_position()
		for b: int in n.bolts_each:
			var aim_point: Vector3 = mark.global_position + Vector3(rng.randf_range(-0.5, 0.5), rng.randf_range(0.5, 1.6),
				rng.randf_range(-0.5, 0.5))
			var to: Vector3 = aim_point
			if rng.randf() >= HIT_SHARE:
				var dir: Vector3 = (aim_point - from).normalized()
				to = from + dir * rng.randf_range(MISS_RANGE.x, MISS_RANGE.y)
				to.y = maxf(to.y, 0.05)
			props.add_bolt(from, to, _launch(s, b), n.bolt_seconds)


# --- The props on the clock ----------------------------------------------------------------------

func _on_advance(delta: float) -> void:
	if props == null:
		return
	props.update(time)
	var leader := actors.get(&"leader") as CineActorNode
	if leader != null:
		leader.scale = Vector3.ONE * n.leader_scale
	_place_dog(delta)
	var runner := actors.get(&"runner") as CineActorNode
	if runner != null and runner.avatar != null:
		_hand_over_face(runner)


## The Octodog at `time`: standing its ground beside its gang, rearing up (its wind-up: crouched, tentacles spread),
## lunging at the right gang, bowling over the first cyborg and pouncing on the next, then mauling it.
func _place_dog(delta: float) -> void:
	var home: Vector3 = gang(n.dog_at.x, n.dog_at.y)
	var leader: Vector3 = gang(n.leader_at.x, n.leader_at.y)
	var first: Vector3 = _tackle_start(0, leader)
	var second: Vector3 = tackle_ends[1] if tackle_ends.size() > 1 else first
	var p: Vector3 = home
	var facing: Vector3 = leader - home
	var crouch: float = 0.0
	var flare: float = 0.15
	var reach: float = 0.0
	var leap: float = 0.0
	if time < n.windup_at:
		pass
	elif time < n.charge_at:
		var k: float = clampf((time - n.windup_at) / maxf(n.charge_at - n.windup_at, 0.05), 0.0, 1.0)
		crouch = smoothstep(0.0, 0.5, k)
		flare = lerpf(0.15, 1.0, k)
		facing = first - home
	elif time < t_hit:
		var k: float = clampf((time - n.charge_at) / maxf(n.charge_seconds, 0.05), 0.0, 1.0)
		var stop: Vector3 = first - (first - home).normalized() * DOG_REACH
		p = home.lerp(stop, k * k)
		p.y = 0.35 * sin(PI * k) * n.dog_scale * 0.4
		facing = first - home
		reach = 1.0
		leap = 0.7
		flare = 0.6
	elif time < t_pounce:
		var k: float = clampf((time - t_hit) / maxf(n.pounce_seconds, 0.05), 0.0, 1.0)
		var from: Vector3 = first - (first - home).normalized() * DOG_REACH
		p = from.lerp(second, smoothstep(0.0, 1.0, k))
		p.y = 0.7 * sin(PI * k) + DOG_ON_TOP * k
		facing = second - from
		reach = 1.0
		leap = 1.0
		flare = 0.8
	else:
		# Mauling: on top of it, tentacles lashing.
		var from: Vector3 = first - (first - home).normalized() * DOG_REACH
		p = second + Vector3(0.0, DOG_ON_TOP, 0.0)
		facing = second - from
		crouch = 0.45
		flare = 0.75 + 0.25 * sin(time * 9.0)
		reach = 0.5 + 0.5 * sin(time * 7.0)
	var world: Vector3 = stage.point(p)
	var speed: float = 0.0
	if _dog_started and delta > 0.0:
		speed = Vector2(world.x - _dog_last.x, world.z - _dog_last.z).length() / delta
	_dog_started = true
	_dog_last = world
	var yaw: float = atan2(-facing.x, facing.z)
	props.pose_dog(world, yaw, speed if speed < 40.0 else 0.0, crouch, flare, reach, leap, delta)


## Where the cyborg the Octodog bowls over first stands before it's hit (track space).
func _tackle_start(j: int, fallback: Vector3) -> Vector3:
	if j >= n.tackles.size() or n.tackles[j] < 0 or n.tackles[j] >= n.right_cyborgs.size():
		return fallback
	var c: Vector3 = n.right_cyborgs[n.tackles[j]]
	return gang(c.x, c.y)


## The runner's left hand coming up over their face as they turn away, on the side toward the fight, and staying up
## as they walk off (on top of their pose: the rig sets every joint afresh each update, so nothing builds up).
## DESIGN-TBD (docs/questions/f2f.md, 9): the hand in front of the left side of the face.
func _hand_over_face(runner: CineActorNode) -> void:
	var k: float = smoothstep(t_turn, t_turn + n.hand_seconds, time)
	hand_up = k
	if k <= 0.0 or not runner.visible:
		return
	var rig: HumanoidRig = runner.avatar.rig
	var head: Node3D = rig.joint(&"head")
	if head == null:
		return
	var basis: Basis = runner.avatar.global_basis.orthonormalized()
	var ahead: Vector3 = -basis.z
	var left: Vector3 = -basis.x
	var face: Vector3 = head.global_position + Vector3.UP * 0.02
	var wrist: Vector3 = face + ahead * HAND_AHEAD + left * HAND_OUT - Vector3.UP * HAND_DOWN
	reach_arm(rig, &"l", wrist, left * 0.9 - Vector3.UP + ahead * 0.2, k)
	# The hand turned up across the face, its fingers toward the brow.
	var hand: Node3D = rig.joint(&"hand_l")
	if hand != null:
		var parent := hand.get_parent() as Node3D
		var up_dir: Vector3 = (face + Vector3.UP * 0.08 - left * 0.03 - wrist).normalized()
		var local_dir: Vector3 = (parent.global_basis.orthonormalized().inverse() * up_dir).normalized()
		if absf(local_dir.dot(Vector3.DOWN)) < 0.999:
			hand.quaternion = hand.quaternion.slerp(Quaternion(Vector3.DOWN, local_dir), k)


## Two-bone reach: arm `side` (&"l" or &"r") of `rig` brought round so its wrist is at `target` (world space), the
## elbow bending toward `pole` (a world direction), by `k` (0-1, blended from the pose already set).
static func reach_arm(rig: HumanoidRig, side: StringName, target: Vector3, pole: Vector3, k: float) -> void:
	var upper: Node3D = rig.joint(StringName("upper_arm_%s" % side))
	var fore: Node3D = rig.joint(StringName("forearm_%s" % side))
	var hand: Node3D = rig.joint(StringName("hand_%s" % side))
	if upper == null or fore == null or hand == null or k <= 0.0:
		return
	var shoulder: Vector3 = upper.global_position
	var a: float = (fore.global_position - shoulder).length()
	var b: float = (hand.global_position - fore.global_position).length()
	var to: Vector3 = target - shoulder
	var d: float = clampf(to.length(), absf(a - b) + 0.001, a + b - 0.001)
	var dir: Vector3 = to.normalized()
	var along: float = (a * a - b * b + d * d) / (2.0 * d)
	var h: float = sqrt(maxf(a * a - along * along, 0.0))
	var bend: Vector3 = pole - dir * pole.dot(dir)
	bend = bend.normalized() if bend.length_squared() > 0.0001 else Vector3.DOWN
	var elbow: Vector3 = shoulder + dir * along + bend * h
	var wrist: Vector3 = shoulder + dir * d
	_point(upper, elbow - shoulder, k)
	_point(fore, wrist - elbow, k)


## Turns `joint` (its bone along its -y) to point along `world_dir`, by `k`.
static func _point(joint: Node3D, world_dir: Vector3, k: float) -> void:
	var parent := joint.get_parent() as Node3D
	var local_dir: Vector3 = (parent.global_basis.orthonormalized().inverse() * world_dir).normalized()
	if absf(local_dir.dot(Vector3.DOWN)) > 0.9999:
		joint.quaternion = joint.quaternion.slerp(Quaternion.IDENTITY, k)
		return
	joint.quaternion = joint.quaternion.slerp(Quaternion(Vector3.DOWN, local_dir), k)
