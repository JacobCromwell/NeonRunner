class_name MarketplaceIntro
extends CinematicSequencer
## The Marketplace's intro (the owner's beats, October 16, 2026), before Marketplace 1:
## 1. The runner walks up to one stall in a line of market stalls (the Marketplace's stall doodad), a citizen inside it.
## 2. They show her a card: a photo of the Corporate zone's boss's face (the Chairman, Hostile Takeover's). The camera
##    closes in on it, a teaser of who they're after; its writing is scribbled and hard to read.
## 3. She waves her arms about and mumbles at them (no real words: speech-like sounds, as the grown-ups talk in
##    Charlie Brown). The runner nods a couple of times and walks off down the street.
## 4. A cyborg of the zone walks up to her and talks to her, gruffer. She talks again and points after the runner.
## 5. The cyborg waves some other cyborgs over, and they set off after the runner.
## Then black, the zone's title card on it, and the level.
## A script on the toolkit, its numbers data (`numbers`, by default data/cinematics/marketplace_intro_tuning.tres,
## MarketplaceIntroTuning). One stage, the zone's street in the level's lanes; its props (MarketplaceIntroSet: the
## stalls, the vendor, the card) are worked out from the time (_on_advance), so stepping or skipping shows the same.
## DESIGN-TBD (docs/questions/f2f.md): the staging the beats leave open, and the vendor's look.

const NUMBERS_PATH: String = "res://data/cinematics/marketplace_intro_tuning.tres"
## Walkers slow to a stop over this long (an eased stop).
const ARRIVE_SETTLE: float = 0.5
## The runner's grip on the card: this far up from its bottom edge (a share of its height), and the card this far in
## front of the hand (metres, toward her), so the hand holds it from behind.
const GRIP_UP: float = 0.02
const HAND_BEHIND: float = 0.05
## Where the runner's hand grips: this far along it from the wrist (the rig's units, before its size fit).
const HAND_GRIP: float = 0.06
## The card is in the runner's hand (and shows) while their arm is this far up or more.
const CARD_SHOWN: float = 0.15
## A walker sets off over this long, then walks at its pace.
const SET_OFF: float = 0.6
## The shots looking back down the street see this far: the street stays built from here behind her stall
## (TrackBuilder keeps only 30 m behind the nearest point and builds 180 m ahead of it).
const LOOK_BACK: float = 100.0
## Cameras keep this far in from the side walls.
const WALL_CLEARANCE: float = 0.6
## The cyborg talking: its head's bob (radians) and rate (Hz), and its left forearm's beat (degrees).
const CYBORG_BOB: float = 0.06
const CYBORG_BOB_HZ: float = 2.0
const CYBORG_BEAT: float = 22.0
## Waving the others over: the arm up toward them, its forearm beckoning (degrees, Hz).
const BECKON: float = 38.0
const BECKON_HZ: float = 2.2

## Its numbers (null: NUMBERS_PATH's).
@export var numbers: MarketplaceIntroTuning

var n: MarketplaceIntroTuning
var props: MarketplaceIntroSet
## Where things are (track space): the runner's start and their place at the counter, the card held up (its face to
## the vendor's eyes); the cyborg's start and its place at the counter.
var walk_start := Vector3.ZERO
var stand_point := Vector3.ZERO
var card_point := Vector3.ZERO
var vendor_eyes := Vector3.ZERO
var cyborg_start := Vector3.ZERO
var cyborg_point := Vector3.ZERO
## When the runner and the cyborg reach the counter (seconds).
var t_arrive: float = 0.0
var t_cyborg_arrive: float = 0.0
## How far up the runner's card is now (0 put away, 1 held up to her).
var card_up: float = 0.0
## The others' ids.
var others: Array[StringName] = []


func _numbers() -> MarketplaceIntroTuning:
	if numbers == null:
		numbers = load(NUMBERS_PATH) as MarketplaceIntroTuning
	return numbers


func _stage_def() -> CineStageDef:
	n = _numbers()
	var d := CineStageDef.new()
	d.length = n.stage_length
	return d


func _make_timeline() -> CineTimeline:
	props = MarketplaceIntroSet.new()
	stage.add_child(props)
	props.setup(stage, n)
	_plan()
	var t := CineTimeline.new()
	t.duration = n.duration
	t.letterbox = true
	_runner(t)
	_cyborgs(t)
	_camera(t)
	_events(t)
	return t


## Where and when things happen, from the numbers and the stalls.
func _plan() -> void:
	stand_point = props.counter(Vector3(n.counter_gap, 0.0, 0.0))
	walk_start = props.counter(n.walk_from)
	card_point = props.counter(n.card_point)
	vendor_eyes = props.counter(Vector3(-n.vendor_back, n.vendor_height * 0.9, 0.0))
	t_arrive = _arrival(n.walk_at, walk_start.distance_to(stand_point), n.walk_speed)
	cyborg_point = props.counter(Vector3(n.cyborg_gap, 0.0, 0.0))
	cyborg_start = props.counter(n.cyborg_from)
	t_cyborg_arrive = _arrival(n.cyborg_walk_at, cyborg_start.distance_to(cyborg_point), n.cyborg_walk_speed)
	if t_arrive > n.show_at:
		push_warning("MarketplaceIntro: the runner reaches the counter at %.2f s, after they show the card" % t_arrive)
	if t_cyborg_arrive > n.cyborg_talk_at:
		push_warning("MarketplaceIntro: the cyborg reaches the counter at %.2f s, after it starts talking" % t_cyborg_arrive)


## When a walker starting at `from` reaches the end of a walk `length` long at `speed`, its last ARRIVE_SETTLE an eased
## stop.
static func _arrival(from: float, length: float, speed: float) -> float:
	return from + (length - ARRIVE_SETTLE * speed * 0.5) / maxf(speed, 0.1) + ARRIVE_SETTLE


# --- The runner ------------------------------------------------------------------------------------

func _runner(t: CineTimeline) -> void:
	var r: CineActor = t.actor(&"runner")
	r.turn_rate = n.turn_rate
	_walk_up(r, n.walk_at, walk_start, stand_point, n.walk_speed, t_arrive)
	# Facing her stall (+90: -x); looking at her, the two nods, then off down the street.
	var face: float = 90.0
	_turned(r.at(t_arrive + 0.02, stand_point), face, 0.0)
	var last: float = t_arrive + 0.02
	for i: int in 2:
		var at: float = n.nod_at + n.nod_seconds * float(i)
		for k: Array in [[0.0, 0.0], [0.5, -n.nod_degrees], [1.0, 0.0]]:
			var when: float = maxf(at + n.nod_seconds * float(k[0]), last + 0.05)
			_turned(_eased(r.at(when, stand_point)), face, 0.0).look_up = float(k[1])
			last = when
	_turned(r.at(maxf(n.leave_at, last + 0.05), stand_point), face, 0.0)
	_walk_off(r, maxf(n.leave_at, last + 0.05), stand_point, Vector3(n.leave_out, 0.0, 2.2), n.leave_speed)


## A walk from `from` to `to` at `speed`, starting at `start` and arriving (an eased stop) at `arrive`: a key every half
## second along the way.
func _walk_up(a: CineActor, start: float, from: Vector3, to: Vector3, speed: float, arrive: float) -> void:
	var slow: float = arrive - ARRIVE_SETTLE
	var dir: Vector3 = (to - from).normalized()
	var at: float = start
	var first: bool = true
	while at < slow + 0.001:
		a.at(at, from + dir * speed * (at - start), &"walk" if first else &"")
		first = false
		at = slow if at < slow and at + 0.5 > slow else at + 0.5
	_eased(a.at(arrive, to), Tween.TRANS_QUAD, Tween.EASE_OUT)


## Turning from where they stand and walking off down the street (+z) at `speed`: a curve out into the street by
## `out` (x out, z along) over the first stretch, then straight on to the end.
func _walk_off(a: CineActor, start: float, from: Vector3, out: Vector3, speed: float) -> void:
	var step: Vector3 = from + Vector3(out.x * 0.3, 0.0, out.z * 0.25)
	var k: CineActorKey = _eased(a.at(start + SET_OFF, step), Tween.TRANS_QUAD, Tween.EASE_IN)
	k.face_path = true
	var turn: Vector3 = from + out
	var at: float = start + SET_OFF + step.distance_to(turn) / speed
	a.at(at, turn).face_path = true
	var far: Vector3 = turn + Vector3(0.0, 0.0, speed * maxf(n.duration - at, 0.1))
	a.at(maxf(n.duration, at + 0.1), far).face_path = true


## The heading (CineActorKey.yaw, degrees: 0 down the track, + left) from `a` to `b`.
static func _yaw_to(a: Vector3, b: Vector3) -> float:
	var d: Vector3 = b - a
	return rad_to_deg(atan2(-d.x, d.z))


static func _eased(k: CineActorKey, trans: Tween.TransitionType = Tween.TRANS_SINE,
		easing: Tween.EaseType = Tween.EASE_IN_OUT) -> CineActorKey:
	k.trans = trans
	k.easing = easing
	return k


static func _turned(k: CineActorKey, body: float, head: float) -> CineActorKey:
	k.face_path = false
	k.yaw = body
	k.look = head
	return k


# --- The cyborgs -----------------------------------------------------------------------------------

func _cyborgs(t: CineTimeline) -> void:
	var c: CineActor = t.actor(&"cyborg", CineActor.Kind.CYBORG)
	c.turn_rate = n.turn_rate
	c.enter = n.street_shot_at
	_walk_up(c, n.cyborg_walk_at, cyborg_start, cyborg_point, n.cyborg_walk_speed, t_cyborg_arrive)
	# At the counter, facing her; its head turning to look where she points, after the runner (+z, on its right).
	var face: float = 90.0
	var looks: Array = [[t_cyborg_arrive + 0.02, 0.0], [n.point_at + 0.35, 0.0], [n.point_at + 0.85, -72.0],
		[n.point_at + n.point_seconds - 0.6, -72.0], [n.point_at + n.point_seconds - 0.1, 0.0]]
	var last: float = t_cyborg_arrive
	for look: Array in looks:
		last = maxf(float(look[0]), last + 0.05)
		_turned(c.at(last, cyborg_point), face, float(look[1]))
	# It turns to the others, waves them over, then sets off after the runner.
	var to_others: float = _yaw_to(cyborg_point, _others_middle())
	var turn_at: float = maxf(n.wave_at - 0.45, last + 0.05)
	_turned(c.at(turn_at, cyborg_point), to_others, 0.0)
	_turned(c.at(maxf(n.go_at, turn_at + 0.05), cyborg_point), to_others, 0.0)
	_walk_off(c, maxf(n.go_at, turn_at + 0.05), cyborg_point, Vector3(0.9, 0.0, 2.0), n.follow_speed)
	# The others, waiting about down the street; waved over, they come up beside it and go with it.
	others.clear()
	for i: int in n.others_wait.size():
		var id := StringName("cyborg_%d" % (i + 2))
		others.append(id)
		var o: CineActor = t.actor(id, CineActor.Kind.CYBORG)
		o.turn_rate = n.turn_rate
		o.enter = n.street_shot_at
		var w: Vector3 = n.others_wait[i]
		var wait: Vector3 = props.counter(Vector3(w.x, 0.0, w.y))
		_turned(o.at(n.street_shot_at, wait, &"walk"), w.z, 0.0)
		# Turning to look as it's waved over (its head first), then coming.
		var heard: float = n.wave_at + 0.25 + 0.15 * float(i)
		_turned(o.at(heard, wait), w.z, 0.0)
		var j: Vector2 = n.others_join[i] if i < n.others_join.size() else Vector2(1.0, -1.0 - float(i))
		var join: Vector3 = cyborg_point + Vector3(j.x, 0.0, j.y)
		var start: float = heard + 0.35
		_turned(o.at(start, wait), _yaw_to(wait, join), 0.0)
		var arrive: float = start + wait.distance_to(join) / n.others_speed
		var come: CineActorKey = o.at(arrive, join)
		come.face_path = true
		# On after the runner with it (no stop if it comes up after they've set off).
		var go: float = maxf(n.go_at + 0.15 * float(i + 1), arrive + 0.05)
		if go > arrive + 0.05:
			_turned(o.at(go, join), 0.0, 0.0)
		var far: Vector3 = join + Vector3(0.6, 0.0, n.follow_speed * maxf(n.duration - go, 0.1))
		o.at(maxf(n.duration, go + 0.1), far).face_path = true


## The middle of where the others wait (track space).
func _others_middle() -> Vector3:
	var sum := Vector3.ZERO
	for w: Vector3 in n.others_wait:
		sum += props.counter(Vector3(w.x, 0.0, w.y))
	return sum / maxf(float(n.others_wait.size()), 1.0)


# --- The camera ------------------------------------------------------------------------------------

func _camera(t: CineTimeline) -> void:
	var c: Vector3 = props.counter(Vector3.ZERO)
	var head: Vector3 = vendor_eyes
	# Across the street, ahead of her stall: looking back along the line of stalls as the runner walks up to it,
	# coming down as they near it.
	t.shot(0.0, _in(c + Vector3(5.0, 2.6, 6.4)), c + Vector3(-0.3, 0.9, -4.5), CinePath.Move.SMOOTH, 50.0)
	t.shot(n.counter_shot_at - 0.004, _in(c + Vector3(4.3, 1.55, 5.0)), c + Vector3(0.0, 0.85, -0.8),
		CinePath.Move.SMOOTH, 46.0)
	# Cut: the two of them at the counter, side on, from up the street; the card comes up.
	t.shot(n.counter_shot_at, _in(c + Vector3(1.85, 1.12, 2.35)), c + Vector3(-0.05, 0.92, -0.1), CinePath.Move.CUT, 48.0)
	t.shot(n.card_shot_at - 0.004, _in(c + Vector3(1.75, 1.1, 2.15)), c + Vector3(-0.05, 0.92, -0.1),
		CinePath.Move.SMOOTH, 46.0)
	# Cut: the card, close, from her side of it (its face is turned to her), pushing in.
	var to_her: Vector3 = (head - card_point).normalized()
	var lift := Vector3(0.0, 0.004, 0.0)
	t.shot(n.card_shot_at, card_point + to_her * n.card_close_from + lift, card_point, CinePath.Move.CUT, n.card_fov)
	t.shot(n.talk_shot_at - 0.004, card_point + to_her * n.card_close_to + lift, card_point, CinePath.Move.SMOOTH,
		n.card_fov)
	# Cut: her, over the runner's right shoulder, as she talks.
	t.shot(n.talk_shot_at, _in(stand_point + Vector3(0.6, 1.3, 0.78)), head + Vector3(0.0, -0.06, -0.05),
		CinePath.Move.CUT, 44.0)
	t.shot(n.leave_shot_at - 0.004, _in(stand_point + Vector3(0.52, 1.28, 0.7)), head + Vector3(0.0, -0.06, -0.05),
		CinePath.Move.SMOOTH, 42.0)
	# Cut: wider, from out in the street up from her stall: the nods; then they turn and walk off, the camera turning
	# to watch them go.
	var wide: Vector3 = _in(c + Vector3(3.3, 1.3, 2.4))
	t.shot(n.leave_shot_at, wide, c + Vector3(0.15, 0.9, 0.15), CinePath.Move.CUT, 46.0)
	t.shot(n.leave_at + 0.3, wide + Vector3(0.0, 0.0, 0.05), c + Vector3(0.25, 0.9, 0.2), CinePath.Move.SMOOTH, 46.0)
	var watch: CineCameraKey = t.shot(n.street_shot_at - 0.004, wide + Vector3(0.0, 0.05, 0.3), Vector3(0.0, 0.9, 0.0),
		CinePath.Move.SMOOTH, 44.0)
	watch.watch = &"runner"
	# Cut: low beside her stall, looking back down the street: the cyborg walking up, the others about behind it.
	t.shot(n.street_shot_at, _in(c + Vector3(0.7, 0.72, 3.6)), c + Vector3(1.7, 0.95, -8.0), CinePath.Move.CUT, 50.0)
	t.shot(n.cyborg_shot_at - 0.004, _in(c + Vector3(0.82, 0.78, 3.3)), c + Vector3(1.3, 0.95, -5.5),
		CinePath.Move.SMOOTH, 48.0)
	# Cut: the cyborg and her at the counter, from the street behind it: it talks, she answers and points.
	t.shot(n.cyborg_shot_at, _in(c + Vector3(2.2, 1.3, -2.1)), c + Vector3(-0.1, 1.0, 0.15), CinePath.Move.CUT, 46.0)
	t.shot(n.after_shot_at - 0.004, _in(c + Vector3(2.05, 1.28, -1.9)), c + Vector3(-0.1, 1.0, 0.15),
		CinePath.Move.SMOOTH, 46.0)
	# Cut: behind them, along her pointing arm, down the street after the runner, small in the distance.
	t.shot(n.after_shot_at, _in(c + Vector3(1.05, 1.32, -2.9)), c + Vector3(1.4, 0.95, 24.0), CinePath.Move.CUT, 44.0)
	t.shot(n.wave_shot_at - 0.004, _in(c + Vector3(1.05, 1.3, -2.6)), c + Vector3(1.4, 0.95, 24.0), CinePath.Move.SMOOTH,
		42.0)
	# Cut: from across the street, beside the others' way to it: it turns to them and waves them over (its front to us).
	t.shot(n.wave_shot_at, _in(c + Vector3(5.0, 1.4, -4.6)), c + Vector3(1.3, 1.0, -1.4), CinePath.Move.CUT, 52.0)
	t.shot(n.follow_shot_at - 0.004, _in(c + Vector3(4.9, 1.4, -4.2)), c + Vector3(1.4, 0.95, -1.0), CinePath.Move.SMOOTH,
		52.0)
	# Cut: low behind them as they set off down the street after the runner, rising a little.
	t.shot(n.follow_shot_at, _in(c + Vector3(1.9, 1.0, -7.2)), c + Vector3(1.6, 0.95, 20.0), CinePath.Move.CUT, 46.0)
	t.shot(n.duration, _in(c + Vector3(1.9, 1.45, -6.4)), c + Vector3(1.6, 1.0, 22.0), CinePath.Move.SMOOTH, 46.0)


## A camera point kept inside the street, off the side walls.
func _in(p: Vector3) -> Vector3:
	return Vector3(clampf(p.x, stage.wall_x(-1) + WALL_CLEARANCE, stage.wall_x(1) - WALL_CLEARANCE), p.y, p.z)


## The shots that look back down the street (the first, the street behind her stall, the wave) see well beyond the
## actors: the street stays built back that far.
func _stage_near(near: float) -> float:
	var back: bool = time < n.counter_shot_at or (time >= n.street_shot_at and time < n.cyborg_shot_at) \
		or (time >= n.wave_shot_at and time < n.follow_shot_at)
	return minf(near, n.stall_at - LOOK_BACK) if back else near


# --- Sounds, effects and cues ------------------------------------------------------------------------

func _events(t: CineTimeline) -> void:
	t.effect(0.0, CineEvent.FADE_IN, n.fade_in)
	t.music(0.0, CineEvent.ZONE_MUSIC, n.music_fade)
	# The voices: no real words (the owner: speech-like mumbling, as the grown-ups talk in Charlie Brown).
	t.sound(n.talk_at, &"mumble_vendor")
	t.sound(n.cyborg_talk_at, &"mumble_cyborg")
	t.sound(n.reply_at, &"mumble_vendor_point")
	t.sound(n.wave_at + 0.1, &"mumble_cyborg_call")
	# Black, the zone's title card on it, and the level.
	t.effect(n.fade_at, CineEvent.FADE_OUT, n.fade_out)
	t.card(n.fade_at, "{zone}", "ZONE {zone_number}", n.card_seconds)


# --- On the clock ------------------------------------------------------------------------------------

func _on_advance(delta: float) -> void:
	if n == null or props == null:
		return
	var runner := actors.get(&"runner") as CineActorNode
	var cyborg := actors.get(&"cyborg") as CineActorNode
	_pose_vendor(delta, runner, cyborg)
	if runner != null and runner.avatar != null:
		_pose_runner(runner)
	if cyborg != null and cyborg.body != null and cyborg.visible:
		_pose_cyborg(cyborg)


## The stall-keeper: watching the runner come up, talking to them with her arms waving about, watching them go; then
## the cyborg, talking to it and pointing after the runner (her eyes following her arm a moment).
func _pose_vendor(delta: float, runner: CineActorNode, cyborg: CineActorNode) -> void:
	var v: MarketplaceIntroVendor = props.vendor
	# The close-up on the card is from her side of it, near her eyes: her body would be in the way.
	v.visible = not (time >= n.card_shot_at and time < n.talk_shot_at)
	var look_at := Vector3.ZERO
	var looking: bool = false
	var runner_head: Vector3 = _head_of(runner)
	var cyborg_head: Vector3 = _head_of(cyborg)
	var follow_point: bool = time >= n.point_at + 0.3 and time < n.point_at + 1.5
	if cyborg != null and cyborg.visible and time >= n.cyborg_walk_at + 1.5 and not follow_point:
		look_at = cyborg_head
		looking = true
	elif runner != null and runner.visible and time >= n.walk_at + 2.0:
		look_at = runner_head
		looking = true
	var talk: float = maxf(_window(time, n.talk_at, n.talk_at + 0.12, n.talk_at + n.talk_seconds - 0.12, n.talk_at + n.talk_seconds),
		_window(time, n.reply_at, n.reply_at + 0.12, n.reply_at + n.reply_seconds - 0.12, n.reply_at + n.reply_seconds))
	var wave: float = maxf(_window(time, n.talk_at - 0.1, n.talk_at + 0.3, n.talk_at + n.talk_seconds - 0.1,
		n.talk_at + n.talk_seconds + 0.4), 0.7 * _window(time, n.reply_at - 0.1, n.reply_at + 0.3,
		n.reply_at + n.reply_seconds - 0.1, n.reply_at + n.reply_seconds + 0.4))
	var point: float = _window(time, n.point_at, n.point_at + 0.45, n.point_at + n.point_seconds - 0.45,
		n.point_at + n.point_seconds)
	var point_at: Vector3 = runner_head if runner != null else stage.point(props.counter(Vector3(1.4, 1.0, 30.0)))
	v.pose(time, delta, look_at, looking, talk, wave, point, point_at)


## The runner: the card held up to her (it's in their right hand, its face to her), and put away again.
func _pose_runner(runner: CineActorNode) -> void:
	var rig: HumanoidRig = runner.avatar.rig
	var card: MeshInstance3D = props.card
	card_up = _window(time, n.show_at, n.show_at + n.raise_seconds, n.put_away_at, n.put_away_at + n.raise_seconds)
	card.visible = card_up >= CARD_SHOWN and runner.visible
	if card_up <= 0.0:
		return
	var held: Transform3D = MarketplaceIntroSet.facing(stage.point(card_point), stage.point(vendor_eyes))
	# The hand reaches just behind the card's bottom edge, the elbow bending as far as it must.
	var grip: Vector3 = held.origin - held.basis.y * n.card_size.y * (0.5 - GRIP_UP) - held.basis.z * HAND_BEHIND
	_reach(rig, &"r", grip, card_up)
	if not card.visible:
		return
	# Coming up (or going down) in the hand, at its place, its face to her, once it's up.
	var hand: Node3D = rig.joint(&"hand_r")
	var grip_now: Vector3 = hand.global_position + (hand.global_basis * Vector3(0.0, -HAND_GRIP, 0.0))
	var in_hand: Vector3 = grip_now + held.basis.y * n.card_size.y * (0.5 - GRIP_UP) + held.basis.z * HAND_BEHIND
	card.global_transform = Transform3D(held.basis, in_hand.lerp(held.origin, smoothstep(0.6, 1.0, card_up)))


## Turns a rig's arm (`side` &"l" or &"r") so its hand's grip comes to `target` (world space), by `k` (0-1): the upper
## arm and the forearm in the vertical plane through the shoulder and the target, the elbow bending below the line
## between them as far as the arm is longer than the reach (a straight arm, pointing, if it's shorter).
static func _reach(rig: HumanoidRig, side: StringName, target: Vector3, k: float) -> void:
	var upper: Node3D = rig.joint(StringName("upper_arm_%s" % side))
	var fore: Node3D = rig.joint(StringName("forearm_%s" % side))
	var hand: Node3D = rig.joint(StringName("hand_%s" % side))
	if upper == null or fore == null or hand == null or k <= 0.0:
		return
	var shoulder: Vector3 = upper.global_position
	var l1: float = shoulder.distance_to(fore.global_position)
	var l2: float = fore.global_position.distance_to(hand.global_position) + HAND_GRIP * rig.global_basis.get_scale().y
	var to: Vector3 = target - shoulder
	var d: float = clampf(to.length(), absf(l1 - l2) + 0.001, l1 + l2 - 0.001)
	var dir: Vector3 = to.normalized()
	var axis: Vector3 = dir.cross(Vector3.DOWN)
	if axis.length_squared() < 0.0001:
		axis = rig.global_basis.x
	var lift: float = acos(clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0))
	var elbow: Vector3 = shoulder + dir.rotated(axis.normalized(), lift) * l1
	GanglandOutro.aim_arm(rig, side, elbow + (elbow - shoulder), k)
	var local: Vector3 = (upper.global_basis.orthonormalized().inverse() * (target - fore.global_position)).normalized()
	if local.dot(Vector3.UP) < 0.999:
		fore.quaternion = fore.quaternion.slerp(Quaternion(Vector3.DOWN, local), k)


## The cyborg: its head bobbing and its left hand beating time as it talks; its right arm up toward the others,
## beckoning, as it waves them over.
func _pose_cyborg(cyborg: CineActorNode) -> void:
	var rig: HumanoidRig = cyborg.body.rig
	var talk: float = _window(time, n.cyborg_talk_at, n.cyborg_talk_at + 0.15, n.cyborg_talk_at + n.cyborg_talk_seconds - 0.15,
		n.cyborg_talk_at + n.cyborg_talk_seconds)
	if talk > 0.0:
		var u: float = time - n.cyborg_talk_at
		rig.joint(&"head").rotate_object_local(Vector3.RIGHT, CYBORG_BOB * talk * sin(TAU * CYBORG_BOB_HZ * u))
		_blend_limb(rig, &"upper_arm_l", -1, Vector3(35.0, 0.0, 14.0), talk)
		_blend_limb(rig, &"forearm_l", -1, Vector3(70.0 + CYBORG_BEAT * sin(TAU * CYBORG_BOB_HZ * u + 0.6), 0.0, 0.0), talk)
	var wave: float = _window(time, n.wave_at, n.wave_at + 0.35, n.wave_at + n.wave_seconds - 0.35, n.wave_at + n.wave_seconds)
	if wave > 0.0:
		var up: Vector3 = stage.point(_others_middle() + Vector3(0.0, 6.0, 0.0))
		GanglandOutro.aim_arm(rig, &"r", cyborg.global_position.lerp(up, 0.35), wave)
		var fore: Node3D = rig.joint(&"forearm_r")
		if fore != null:
			var beckon: float = deg_to_rad(BECKON) * (0.5 + 0.5 * sin(TAU * BECKON_HZ * (time - n.wave_at)))
			fore.rotate_object_local(Vector3.RIGHT, beckon * wave)


static func _blend_limb(rig: HumanoidRig, joint_name: StringName, side: int, degrees: Vector3, k: float) -> void:
	BeachOutroBar._blend(rig.joint(joint_name), VolleyballRival._limb(side, degrees), k)


## An actor's head, world space (its node's place, up by its height).
func _head_of(actor: CineActorNode) -> Vector3:
	if actor == null:
		return Vector3.ZERO
	var rig: HumanoidRig = actor.avatar.rig if actor.avatar != null else (actor.body.rig if actor.body != null else null)
	var head: Node3D = rig.joint(&"head") if rig != null else null
	return head.global_position if head != null else actor.global_position + Vector3(0.0, 1.1, 0.0)


## 0 before `a`, rising to 1 by `b`, 1 until `c`, falling to 0 by `d` (eased in and out).
static func _window(t: float, a: float, b: float, c: float, d: float) -> float:
	return GanglandOutro._window(t, a, b, c, d)


## Draw calls its props add now (each visible mesh's surfaces): tests.
func props_draw_calls() -> int:
	return props.draw_calls() if props != null else 0
