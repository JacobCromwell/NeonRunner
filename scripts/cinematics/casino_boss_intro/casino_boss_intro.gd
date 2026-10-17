class_name CasinoBossIntro
extends CinematicSequencer
## The Casino's boss intro, before The House (the owner's beats, October 17, 2026; GDD §10, The House, "Intro
## cinematic"):
## 1. Inside the bustling casino (CasinoHall: its tables, its holographic games, its slot machines, its bar; the crowd,
##    CasinoCrowd). Close to the roulette table, panning right to the wheel spinning; the ball lands and the players
##    cheer. Tilting up to them: the wealthy woman in red, the "Lady Luck" gambler, the grimy player and the well-to-do
##    businessman (CasinoPerson, CasinoPeople; the owner's reference, docs/art/reference/casino_patrons.webp).
## 2. Cut to the runner leaning back on the bar, the screech sitting on the counter beside them, looking over the
##    casino. They see the Chairman crossing the floor (his new look: docs/art/reference/chairman.webp), a beautiful
##    woman either side of him: one in a black dress with black hair, one in a red dress with blonde hair.
## 3. The runner pushes off the bar and moves through the crowd toward him. He looks back, sees them and flicks his
##    hand: two of his cyborg guards (in the Casino's look) rush the runner, who dives right past the first and left
##    past the second.
## 4. Cut to the back wall: the Chairman and the women go through an elegant golden door, which bangs shut behind them.
##    The wall to its left trembles; the camera pulls back to show the whole wall; it bursts into rubble and The House
##    stands in the hole, its lights blazing on. Then black, and the fight.
## A script on the toolkit, its numbers data (`numbers`, by default data/cinematics/casino_boss_intro_tuning.tres,
## CasinoBossIntroTuning). It plays wholly in the hall, a closed set on the stage (the street's track hidden under it);
## everything is worked out from the time (_on_advance), so stepping or skipping shows the same.
## DESIGN-TBD (docs/OPEN_QUESTIONS_DEFERRED.md items 948–959): the staging the beats leave open, the hall and the people's looks.

const NUMBERS_PATH: String = "res://data/cinematics/casino_boss_intro_tuning.tres"
## The fight's numbers, for The House's size (the hole is cut to fit the fight's own machine).
const HOUSE_TUNING_PATH: String = "res://data/bosses/casino_boss_tuning.tres"
## The screech on the counter: its size (the Beach outro's), its look, where it sits along the counter from the runner
## (+ further along the hall) and in from the counter's front.
const SCREECH_SIZE: float = 0.55
const SCREECH_LOOK: StringName = &"scavenger"
const SCREECH_ALONG: float = 1.5
const SCREECH_IN: float = 0.26
## The bartender's place behind the counter (along it, in from its front).
const BARTENDER_ALONG: float = -1.9
const BARTENDER_IN: float = 1.25
## The croupier at the wheel's end of the roulette table.
const CROUPIER_OUT: float = 0.9
## How the runner leans back on the bar: the chest's tilt back (degrees) and the arms back, the elbows on the counter.
const LEAN_BACK: float = 12.0
const LEAN_UPPER := Vector3(-32.0, 0.0, 16.0)
const LEAN_FORE := Vector3(12.0, 0.0, 0.0)
## The hall's light (ZoneSkin's scenery light and tint for the kit's fake light on its surfaces): warm lamplight, a
## little brighter than the street's night, set while it plays and set back after.
const HALL_LIGHT: float = 1.3
const HALL_TINT := Color(1.12, 1.0, 0.86)
## A guard's lunge: its arms out ahead, grabbing, its chest pitched forward (degrees).
const LUNGE_UPPER := Vector3(78.0, 0.0, 14.0)
const LUNGE_FORE := Vector3(18.0, 0.0, 0.0)
const LUNGE_PITCH: float = 22.0
## The Chairman's chest turning with his look back over his shoulder (radians).
const LOOK_BACK_TWIST: float = 0.45

## Its numbers (null: NUMBERS_PATH's).
@export var numbers: CasinoBossIntroTuning

var n: CasinoBossIntroTuning
var hall: CasinoHall
var crowd: CasinoCrowd
var screech: BeachOutroScreech
## The people on the rig (CasinoPerson): the roulette players (in players_x's order), the croupier, the bartender, the
## Chairman and the two women.
var players: Array[CasinoPerson] = []
var croupier: CasinoPerson
var bartender: CasinoPerson
var chairman: CasinoPerson
var escort_black: CasinoPerson
var escort_blonde: CasinoPerson
var cane: MeshInstance3D
var _light_before: float = 1.0
var _tint_before := Color.WHITE
var _fog_before: bool = false
## The walkers' last place (track space) and heading (radians), to walk them from one step to the next.
var _walk_last: Dictionary = {}


func _numbers() -> CasinoBossIntroTuning:
	if numbers == null:
		numbers = load(NUMBERS_PATH) as CasinoBossIntroTuning
	return numbers


func _stage_def() -> CineStageDef:
	n = _numbers()
	var d := CineStageDef.new()
	d.length = n.stage_length
	return d


func _make_timeline() -> CineTimeline:
	n = _numbers()
	# The street stays out of sight: the hall is a closed set standing on it.
	if stage.track != null:
		stage.track.visible = false
	hall = CasinoHall.new()
	stage.add_child(hall)
	hall.global_position = stage.point(Vector3.ZERO)
	hall.setup(stage.skin, _house_shape(), n.hole_x, n.hole_margin)
	hall.place()
	_light_before = ZoneSkin.scenery_light_now
	_tint_before = ZoneSkin.scenery_tint_now
	ZoneSkin.set_scenery_light(HALL_LIGHT)
	ZoneSkin.set_scenery_tint(HALL_TINT)
	if stage.environment != null:
		_fog_before = stage.environment.fog_enabled
		stage.environment.fog_enabled = false
	crowd = CasinoCrowd.new()
	hall.add_child(crowd)
	crowd.setup(n)
	_people()
	screech = BeachOutroScreech.new()
	stage.add_child(screech)
	screech.setup_friend(SCREECH_SIZE, SCREECH_LOOK)
	var t := CineTimeline.new()
	t.duration = n.duration
	t.letterbox = true
	_runner(t)
	_guards(t)
	_camera(t)
	_events(t)
	return t


## The House the fight builds, sized to the street it's fought on (TheHouseBody).
func _house_shape() -> TheHouseModel.Shape:
	var tuning := load(HOUSE_TUNING_PATH) as TheHouseTuning
	if tuning == null:
		tuning = TheHouseTuning.new()
	var width: float = stage.wall_x(1) - stage.wall_x(-1)
	return TheHouseModel.shape_for(width, tuning, TheHouseBody.hopper_length(stage.tuning, tuning))


func _person(look: CasinoPeople.Look, height: float, node_name: String) -> CasinoPerson:
	var p := CasinoPerson.new()
	stage.add_child(p)
	p.setup(look, height)
	p.name = node_name
	return p


func _people() -> void:
	var looks: Array[CasinoPeople.Look] = [CasinoPeople.Look.LADY_IN_RED, CasinoPeople.Look.LADY_LUCK, CasinoPeople.Look.GRIMY,
		CasinoPeople.Look.HIGH_ROLLER]
	var heights: Array[float] = [n.woman_height, n.woman_height * 0.97, n.man_height, n.man_height * 1.02]
	var names: Array[String] = ["LadyInRed", "LadyLuck", "Grimy", "HighRoller"]
	for i: int in looks.size():
		players.append(_person(looks[i], heights[i], names[i]))
	croupier = _person(CasinoPeople.Look.DEALER, n.man_height * 0.98, "Croupier")
	bartender = _person(CasinoPeople.Look.DEALER, n.man_height, "Bartender")
	chairman = _person(CasinoPeople.Look.CHAIRMAN, n.chairman_height, "Chairman")
	escort_black = _person(CasinoPeople.Look.ESCORT_BLACK, n.woman_height * 1.02, "EscortBlack")
	escort_blonde = _person(CasinoPeople.Look.ESCORT_BLONDE, n.woman_height * 1.01, "EscortBlonde")
	# His cane: a black lacquered shaft with a brass head, in his left hand (placed every step).
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(hall.solid_material())
	s.prism(Vector3.ZERO, 0.012, 0.86, 6, Color(0.05, 0.05, 0.06), 0.0, MeshKit.PAT_PLAIN)
	s.prism(Vector3(0.0, 0.84, 0.0), 0.022, 0.06, 8, CasinoHall.BRASS, 0.0, MeshKit.PAT_CASINO_BRASS, true, 0.9)
	s.prism(Vector3(0.0, -0.01, 0.0), 0.016, 0.02, 6, CasinoHall.BRASS_DARK, 0.0, MeshKit.PAT_CASINO_BRASS, true, 0.6)
	cane = MeshBatch.add_instance(stage, batch.to_mesh(), "Cane")
	cane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# --- Paths ---------------------------------------------------------------------------------------------

## A point on a path of (x, z, time) points at time `t` (track space, on the floor): a Catmull-Rom curve through them,
## at rest before the first and after the last.
static func path_at(path: PackedVector3Array, t: float) -> Vector3:
	if path.is_empty():
		return Vector3.ZERO
	if t <= path[0].z:
		return Vector3(path[0].x, 0.0, path[0].y)
	var last: int = path.size() - 1
	if t >= path[last].z:
		return Vector3(path[last].x, 0.0, path[last].y)
	var i: int = 0
	while i < last - 1 and t > path[i + 1].z:
		i += 1
	var u: float = (t - path[i].z) / maxf(path[i + 1].z - path[i].z, 0.001)
	var p0: Vector2 = _xz(path[maxi(i - 1, 0)])
	var p1: Vector2 = _xz(path[i])
	var p2: Vector2 = _xz(path[i + 1])
	var p3: Vector2 = _xz(path[mini(i + 2, last)])
	# Ease in from rest at the first point and out to rest at the last.
	if i == 0:
		u = _ease_in(u)
	if i == last - 1:
		u = _ease_out(u)
	var q: Vector2 = 0.5 * ((2.0 * p1) + (-p0 + p2) * u + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * u * u
		+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * u * u * u)
	return Vector3(q.x, 0.0, q.y)


static func _xz(p: Vector3) -> Vector2:
	return Vector2(p.x, p.y)


static func _ease_in(u: float) -> float:
	return u * u * (2.0 - u) if u < 1.0 else 1.0


static func _ease_out(u: float) -> float:
	return 1.0 - _ease_in(1.0 - u)


## The heading (radians, 0 down the track, + left) of moving from `a` to `b`.
static func heading_of(a: Vector3, b: Vector3) -> float:
	var d: Vector3 = b - a
	return atan2(-d.x, d.z)


## A point `offset` (x across to the right, y ahead) from `p` in the frame of `heading`.
static func in_frame(p: Vector3, heading: float, offset: Vector2) -> Vector3:
	var fwd := Vector3(-sin(heading), 0.0, cos(heading))
	var right := Vector3(cos(heading), 0.0, sin(heading))
	return p + right * offset.x + fwd * offset.y


## The Chairman's place and heading at `t`.
func chairman_at(t: float) -> Vector3:
	return path_at(n.chairman_path, t)


func chairman_heading(t: float) -> float:
	var a: Vector3 = chairman_at(t - 0.15)
	var b: Vector3 = chairman_at(t + 0.15)
	if a.distance_to(b) < 0.02:
		var p := n.chairman_path
		if p.size() >= 2:
			return heading_of(Vector3(p[0].x, 0.0, p[0].y), Vector3(p[1].x, 0.0, p[1].y)) if t < p[0].z else \
				heading_of(Vector3(p[p.size() - 2].x, 0.0, p[p.size() - 2].y), Vector3(p[p.size() - 1].x, 0.0, p[p.size() - 1].y))
		return 0.0
	return heading_of(a, b)


## Where a woman beside him walks (`side` -1 his left, 1 his right), closing in at the door.
func escort_at(t: float, side: float) -> Vector3:
	var c: Vector3 = chairman_at(t)
	var near_door: float = 1.0 - smoothstep(1.2, 4.0, c.distance_to(CasinoHall.door_point()))
	if c.z > CasinoHall.door_point().z:
		near_door = 1.0
	var off: Vector2 = n.escort_offset.lerp(n.escort_door_offset, near_door)
	return in_frame(c, chairman_heading(t), Vector2(side * off.x, off.y))


# --- The runner ----------------------------------------------------------------------------------------

func _runner(t: CineTimeline) -> void:
	var r: CineActor = t.actor(&"runner")
	r.turn_rate = 8.0
	r.enter = n.bar_shot_at - 0.1
	var lean: Vector3 = CasinoHall.bar_lean(n.lean_z)
	# Leaning back on the bar, facing out over the hall (-x: +90), looking about, then across at the Chairman.
	var face: float = 90.0
	_turned(r.at(0.0, lean), face, 0.0)
	_turned(r.at(n.look_out_at - 0.3, lean), face, 18.0)
	var chair_dir: float = rad_to_deg(heading_of(lean, chairman_at(n.chairman_shot_at)))
	_turned(r.at(n.look_out_at + 0.5, lean), face, clampf(chair_dir - face, -70.0, 70.0))
	_turned(r.at(n.push_off_at, lean), face, clampf(rad_to_deg(heading_of(lean, chairman_at(n.push_off_at))) - face, -70.0, 70.0))
	# Through the crowd.
	var path: PackedVector3Array = n.runner_path
	for i: int in range(1, path.size()):
		var k: CineActorKey = r.at(path[i].z, Vector3(path[i].x, 0.0, path[i].y))
		k.face_path = true
	# The dives: right past the first guard, left past the second, each a low leap sideways and on.
	var at: Vector3 = Vector3(path[path.size() - 1].x, 0.0, path[path.size() - 1].y)
	var last: float = path[path.size() - 1].z
	var dives: Array = [[n.dive_right_at, 1.0], [n.dive_left_at, -1.0]]
	for d: Array in dives:
		var start: float = maxf(float(d[0]), last + 0.05)
		if start > last + 0.06:
			# Running on up to it.
			at = at + Vector3(0.0, 0.0, n.run_speed * (start - last) * 0.8)
			r.at(start, at).face_path = true
		var land: Vector3 = at + Vector3(float(d[1]) * n.dive_side, 0.0, n.dive_on)
		var steps: int = 4
		for s: int in range(1, steps + 1):
			var u: float = float(s) / float(steps)
			var p: Vector3 = at.lerp(land, u) + Vector3(0.0, 4.0 * n.dive_height * u * (1.0 - u), 0.0)
			var k2: CineActorKey = r.at(start + n.dive_seconds * u, p)
			k2.face_path = false
			k2.yaw = 0.0
		at = land
		last = start + n.dive_seconds
	# On toward the door, slowing to a stop; facing it, then looking left at the wall as it trembles.
	var stop := Vector3(n.runner_stop.x, 0.0, n.runner_stop.y)
	var mid: Vector3 = at.lerp(stop, 0.6)
	r.at(last + at.distance_to(mid) / n.run_speed, mid).face_path = true
	var settle: CineActorKey = r.at(maxf(n.runner_stop_at, last + 0.6), stop)
	settle.trans = Tween.TRANS_QUAD
	settle.easing = Tween.EASE_OUT
	_turned(settle, 0.0, 0.0)
	_turned(r.at(n.tremble_at + 0.4, stop), 0.0, 0.0)
	var to_wall: float = rad_to_deg(heading_of(stop, hall.hole_point() + Vector3(0.0, 0.0, -2.0)))
	_turned(r.at(n.tremble_at + 1.0, stop), 0.0, clampf(to_wall, -80.0, 80.0)).look_up = 8.0
	var k3: CineActorKey = _turned(r.at(n.burst_at + 0.3, stop), to_wall * 0.5, clampf(to_wall * 0.5, -80.0, 80.0))
	k3.look_up = 22.0
	_turned(r.at(n.duration, stop), to_wall * 0.5, clampf(to_wall * 0.5, -80.0, 80.0)).look_up = 24.0


static func _turned(k: CineActorKey, body: float, head: float) -> CineActorKey:
	k.face_path = false
	k.yaw = body
	k.look = head
	return k


# --- The guards ----------------------------------------------------------------------------------------

func _guards(t: CineTimeline) -> void:
	for side: float in [-1.0, 1.0]:
		var id: StringName = &"guard_l" if side < 0.0 else &"guard_r"
		var g: CineActor = t.actor(id, CineActor.Kind.CYBORG, &"casino")
		g.turn_rate = 7.0
		g.enter = n.chairman_shot_at - 0.1
		# Walking behind him until he gives the order.
		var at: float = n.chairman_path[0].z
		var first: bool = true
		while at < n.guards_go_at - 0.001:
			var p: Vector3 = in_frame(chairman_at(at), chairman_heading(at), Vector2(side * n.guard_offset.x, n.guard_offset.y))
			g.at(at, p, &"walk" if first else &"").face_path = true
			first = false
			at = minf(at + 0.5, n.guards_go_at)
		var go: Vector3 = in_frame(chairman_at(n.guards_go_at), chairman_heading(n.guards_go_at), Vector2(side * n.guard_offset.x, n.guard_offset.y))
		g.at(n.guards_go_at, go).face_path = true
		# The rush to where it lunges from, the lunge through where the runner is, the stumble on and the recovery.
		var from2: Vector2 = n.guard_left_from if side < 0.0 else n.guard_right_from
		var to2: Vector2 = n.guard_left_to if side < 0.0 else n.guard_right_to
		var lunge_at: float = n.lunge_left_at if side < 0.0 else n.lunge_right_at
		var from := Vector3(from2.x, 0.0, from2.y)
		var to := Vector3(to2.x, 0.0, to2.y)
		g.at(lunge_at, from).face_path = true
		g.at(lunge_at + n.lunge_seconds, to).face_path = true
		var over: Vector3 = to + (to - from).normalized() * 0.5
		var stumble: CineActorKey = g.at(lunge_at + n.lunge_seconds + 0.45, over)
		stumble.face_path = false
		stumble.yaw = rad_to_deg(heading_of(from, to))
		stumble.trans = Tween.TRANS_QUAD
		stumble.easing = Tween.EASE_OUT
		# Turning round after the runner, then to the wall as it trembles.
		var after: float = rad_to_deg(heading_of(over, Vector3(n.runner_stop.x, 0.0, n.runner_stop.y)))
		var k: CineActorKey = g.at(lunge_at + n.lunge_seconds + 1.1, over)
		k.face_path = false
		k.yaw = after
		var k2: CineActorKey = g.at(n.tremble_at + 0.8, over)
		k2.face_path = false
		k2.yaw = after
		var k3: CineActorKey = g.at(n.tremble_at + 1.6, over)
		k3.face_path = false
		k3.yaw = rad_to_deg(heading_of(over, hall.hole_point()))
		k3.look_up = 15.0


# --- The camera ----------------------------------------------------------------------------------------

func _camera(t: CineTimeline) -> void:
	var w: Vector3 = CasinoHall.wheel_center()
	var table: Vector3 = CasinoHall.ROULETTE
	# Low at the table's near side, panning right along the layout to the wheel, close.
	t.shot(0.0, Vector3(table.x - 2.0, 1.12, table.z - 1.5), Vector3(table.x - 1.1, 0.62, table.z + 0.05), CinePath.Move.SMOOTH, 44.0)
	t.shot(2.6, Vector3(w.x - 0.5, 1.28, w.z - 1.0), w + Vector3(0.0, 0.0, 0.05), CinePath.Move.SMOOTH, 42.0)
	t.shot(n.tilt_at - 0.004, Vector3(w.x - 0.35, 1.22, w.z - 0.82), w + Vector3(0.0, 0.0, 0.06), CinePath.Move.SMOOTH, 40.0)
	# Tilting up and easing back to the players across the table, cheering.
	var players_mid := Vector3(table.x + 0.0, 1.0, table.z + n.players_back)
	t.shot(n.tilt_at + 0.6, Vector3(w.x - 0.4, 1.15, w.z - 0.95), w.lerp(players_mid, 0.35) + Vector3(0.0, 0.1, 0.0), CinePath.Move.SMOOTH, 42.0)
	t.shot(n.bar_shot_at - 0.004, Vector3(table.x + 0.55, 1.02, table.z - 1.85), players_mid + Vector3(0.0, 0.08, 0.0),
		CinePath.Move.SMOOTH, 50.0)
	# Cut: the runner leaning on the bar, the screech beside them, from out on the floor to their right; pushing in.
	var lean: Vector3 = CasinoHall.bar_lean(n.lean_z)
	var head := lean + Vector3(0.05, 1.08, 0.0)
	t.shot(n.bar_shot_at, lean + Vector3(-2.2, 1.0, 0.85), head + Vector3(0.05, -0.2, 0.5), CinePath.Move.CUT, 46.0)
	t.shot(n.chairman_shot_at - 0.004, lean + Vector3(-1.85, 1.02, 0.7), head + Vector3(0.05, -0.17, 0.45), CinePath.Move.SMOOTH, 44.0)
	# Cut: over their shoulder from behind the counter, across the hall at the Chairman and the women, tracking them.
	var over := lean + Vector3(0.5, 1.5, 0.3)
	var steps: int = 4
	for i: int in steps + 1:
		var at: float = lerpf(n.chairman_shot_at, n.resolve_shot_at - 0.004, float(i) / float(steps))
		var key: CineCameraKey = t.shot(at, over + Vector3(0.0, 0.0, 0.05 * float(i)), chairman_at(at) + Vector3(0.0, 0.85, 0.0),
			CinePath.Move.CUT if i == 0 else CinePath.Move.SMOOTH, 10.0)
	# Cut: close on the runner's face as they make up their mind and push off the bar.
	t.shot(n.resolve_shot_at, lean + Vector3(-1.05, 1.08, 0.95), head + Vector3(0.0, -0.04, 0.0), CinePath.Move.CUT, 38.0)
	t.shot(n.crowd_shot_at - 0.004, lean + Vector3(-1.2, 1.08, 1.05), head + Vector3(-0.4, -0.06, 0.5), CinePath.Move.SMOOTH, 40.0)
	# Cut: following them through the crowd from behind and to their right.
	var follow: CineCameraKey = t.shot(n.crowd_shot_at, Vector3(1.9, 1.5, -2.3), Vector3(0.0, 0.85, 1.5), CinePath.Move.CUT, 50.0)
	follow.follow = &"runner"
	follow.watch = &"runner"
	var follow2: CineCameraKey = t.shot(n.notice_shot_at - 0.004, Vector3(1.4, 1.45, -2.6), Vector3(0.0, 0.85, 2.0), CinePath.Move.SMOOTH, 50.0)
	follow2.follow = &"runner"
	follow2.watch = &"runner"
	# Cut: the Chairman, from ahead of him: he looks back over his shoulder, sees them and flicks his hand.
	var c0: Vector3 = chairman_at(n.notice_shot_at)
	var h0: float = chairman_heading(n.notice_shot_at)
	var cam0: Vector3 = in_frame(c0, h0, Vector2(1.4, 2.7)) + Vector3(0.0, 1.25, 0.0)
	t.shot(n.notice_shot_at, cam0, c0 + Vector3(0.0, 1.05, 0.0), CinePath.Move.CUT, 40.0)
	var c1: Vector3 = chairman_at(n.guards_shot_at)
	t.shot(n.guards_shot_at - 0.004, cam0 + (c1 - c0) * 0.7, c1 + Vector3(0.0, 1.05, 0.0), CinePath.Move.SMOOTH, 40.0)
	# Cut: wide, from ahead of the runner off to the right: the guards rush them, the dives.
	t.shot(n.guards_shot_at, Vector3(10.4, 2.5, 31.4), Vector3(6.2, 0.7, 26.2), CinePath.Move.CUT, 46.0)
	t.shot(n.dive_left_at + n.dive_seconds, Vector3(10.5, 2.5, 31.9), Vector3(6.3, 0.7, 27.3), CinePath.Move.SMOOTH, 46.0)
	t.shot(n.door_shot_at - 0.004, Vector3(10.6, 2.5, 32.4), Vector3(6.4, 0.75, 29.4), CinePath.Move.SMOOTH, 46.0)
	# Cut: the golden door, the Chairman and the women going through it, the runner coming up behind; it bangs shut.
	var door: Vector3 = CasinoHall.door_point()
	t.shot(n.door_shot_at, Vector3(door.x - 3.9, 1.65, door.z - 9.2), door + Vector3(0.0, 1.6, 0.0), CinePath.Move.CUT, 44.0)
	t.shot(n.pull_back_at, Vector3(door.x - 4.1, 1.7, door.z - 9.6), door + Vector3(-1.2, 1.9, 0.0), CinePath.Move.SMOOTH, 44.0)
	# Pulling back (and over to the left, rising) to show the whole wall as it trembles; holding as it bursts and The
	# House is revealed, easing in.
	var hole: Vector3 = hall.hole_point()
	var wide := Vector3(hole.x + 3.6, 4.6, 13.5)
	var wide_target := Vector3(hole.x + 1.6, 6.0, CasinoHall.DEPTH)
	var pb: CineCameraKey = t.shot(n.pull_back_at + n.pull_back_seconds, wide, wide_target, CinePath.Move.LINEAR, 52.0)
	pb.trans = Tween.TRANS_SINE
	pb.easing = Tween.EASE_IN_OUT
	t.shot(n.burst_at + 0.6, wide + Vector3(0.0, -0.05, 0.3), wide_target, CinePath.Move.SMOOTH, 52.0)
	t.shot(n.duration, wide + Vector3(-0.4, -0.4, 2.6), wide_target + Vector3(-0.4, -0.3, 0.0), CinePath.Move.SMOOTH, 50.0)


# --- Sounds, effects and cues ------------------------------------------------------------------------

func _events(t: CineTimeline) -> void:
	t.effect(0.0, CineEvent.FADE_IN, n.fade_in)
	t.music(0.0, CineEvent.ZONE_MUSIC, n.music_fade)
	# The floor's bustle under it all, until the wall starts to shake.
	var at: float = 0.0
	while at < n.tremble_at + 0.4:
		t.sound(at, &"casino_bustle")
		at += 2.1
	t.sound(0.5, &"roulette_spin")
	t.sound(n.ball_drop_at, &"roulette_drop")
	t.sound(n.cheer_at, &"crowd_cheer")
	t.sound(n.push_off_at + 0.05, &"screech_chirp", -6.0)
	t.sound(n.guards_go_at - 0.05, &"guard_halt")
	t.sound(n.dive_right_at, &"jump", -6.0)
	t.sound(n.dive_right_at + n.dive_seconds, &"land", -6.0)
	t.sound(n.dive_left_at, &"jump", -6.0)
	t.sound(n.dive_left_at + n.dive_seconds, &"land", -6.0)
	t.sound(n.door_close_at + n.door_close_seconds * 0.4, &"golden_door")
	t.sound(n.tremble_at, &"wall_rumble")
	t.sound(n.tremble_at + 1.2, &"wall_rumble")
	t.effect(n.tremble_at, CineEvent.SHAKE, n.burst_at - n.tremble_at, n.tremble_shake)
	t.sound(n.burst_at - 0.05, &"wall_collapse")
	t.effect(n.burst_at, CineEvent.SHAKE, 1.3, n.burst_shake)
	t.sound(n.house_lights_at, &"house_spin")
	t.effect(n.fade_at, CineEvent.FADE_OUT, n.fade_out)


# --- On the clock ------------------------------------------------------------------------------------

func _on_advance(delta: float) -> void:
	if n == null or hall == null:
		return
	hall.update(time, n)
	if crowd != null:
		crowd.update(time, n)
	_pose_players(delta)
	_pose_staff(delta)
	_pose_chairman(delta)
	var runner := actors.get(&"runner") as CineActorNode
	if runner != null and runner.avatar != null:
		_pose_runner(runner)
		_place_screech(runner)
	for id: StringName in [&"guard_l", &"guard_r"]:
		var g := actors.get(id) as CineActorNode
		if g != null and g.body != null and g.visible:
			_pose_guard(g, id == &"guard_l")


## The roulette players and the croupier: watching the wheel, cheering as the ball lands (the woman in red drinking to
## it, the businessman clapping).
func _pose_players(delta: float) -> void:
	var shown: bool = time < n.bar_shot_at
	var table: Vector3 = CasinoHall.ROULETTE
	var wheel: Vector3 = stage.point(CasinoHall.wheel_center())
	var cheer: float = _window(time, n.cheer_at, n.cheer_at + 0.35, n.cheer_at + n.cheer_seconds - 0.5, n.cheer_at + n.cheer_seconds)
	for i: int in players.size():
		var p: CasinoPerson = players[i]
		p.visible = shown
		if not shown:
			continue
		var pos := Vector3(table.x + n.players_x[i], 0.0, table.z + n.players_back)
		p.global_transform = Transform3D(Basis(Vector3.UP, PI), stage.point(pos))
		p.stand(time + float(i) * 1.7, delta)
		p.look_at_point(wheel, 1.0 - cheer * 0.6)
		match i:
			0:
				p.hold_glass(1.0 - cheer, -1)
				p.cheer(cheer * 0.8, time)
				p.drink(_window(time, n.cheer_at + n.cheer_seconds - 0.6, n.cheer_at + n.cheer_seconds, 7.5, 8.2), -1)
			3:
				p.clap(cheer, time)
			_:
				p.cheer(cheer, time + float(i) * 0.3)
	croupier.visible = shown
	if shown:
		var cp: Vector3 = CasinoHall.wheel_center() + Vector3(CROUPIER_OUT, 0.0, 0.0)
		cp.y = 0.0
		croupier.global_transform = Transform3D(Basis(Vector3.UP, PI * 0.5), stage.point(cp))
		croupier.stand(time + 0.6, delta)
		croupier.look_at_point(wheel, 1.0)


## The bartender behind the counter, polishing a glass; looking up after the runner as they go.
func _pose_staff(delta: float) -> void:
	var shown: bool = time >= n.bar_shot_at and time < n.crowd_shot_at and not (time >= n.chairman_shot_at and time < n.resolve_shot_at)
	bartender.visible = shown
	if not shown:
		return
	var pos: Vector3 = CasinoHall.bar_top(n.lean_z + BARTENDER_ALONG, BARTENDER_IN)
	pos.y = 0.0
	bartender.global_transform = Transform3D(Basis(Vector3.UP, PI * 0.5), stage.point(pos))
	bartender.stand(time + 2.3, delta)
	bartender.hold_glass(1.0, 1)
	bartender.hold_glass(1.0, -1)


## The Chairman walking to the door with a woman on either side, his cane in his left hand; looking back over his
## shoulder at the runner and flicking his hand to his guards.
func _pose_chairman(delta: float) -> void:
	var start: float = n.chairman_path[0].z
	var gone: bool = CasinoGoldenDoor.is_shut(time, n)
	var shown: bool = time >= start - 0.2 and not gone and time >= n.chairman_shot_at - 0.5
	for p: CasinoPerson in [chairman, escort_black, escort_blonde]:
		p.visible = shown
	cane.visible = shown
	if not shown:
		return
	var heading: float = chairman_heading(time)
	_walk(chairman, &"chairman", chairman_at(time), heading, delta)
	_walk(escort_black, &"black", escort_at(time, -1.0), heading, delta)
	_walk(escort_blonde, &"blonde", escort_at(time, 1.0), heading, delta)
	var runner := actors.get(&"runner") as CineActorNode
	var look: float = _window(time, n.notice_at, n.notice_at + 0.35, n.door_open_at - 0.4, n.door_open_at)
	if runner != null and runner.avatar != null and look > 0.0:
		var at: Vector3 = runner.avatar.rig.joint(&"head").global_position
		var side: float = signf((chairman.global_transform.affine_inverse() * at).x)
		var chest: Node3D = chairman.rig.joint(&"chest")
		if chest != null:
			chest.rotate_object_local(Vector3.UP, -side * LOOK_BACK_TWIST * look)
		chairman.look_at_point(at, look)
	chairman.gesture_flick(_window(time, n.order_at, n.order_at + 0.2, n.order_at + 0.55, n.order_at + 0.85), time)
	# The women glance back too, a moment after him.
	if runner != null and runner.avatar != null:
		var glance: float = 0.6 * _window(time, n.notice_at + 0.3, n.notice_at + 0.7, n.order_at + 0.6, n.order_at + 1.1)
		for p: CasinoPerson in [escort_black, escort_blonde]:
			p.look_at_point(runner.avatar.rig.joint(&"head").global_position, glance)
	# The cane in his left hand, its foot swinging just clear of the floor.
	var hand: Vector3 = chairman.hand_point(-1)
	cane.global_transform = Transform3D(Basis(Vector3.UP, heading) * Basis(Vector3.RIGHT, -0.12), hand - Vector3(0.0, 0.84, 0.0))


## Walks a person to `pos` (track space) facing `heading` from wherever it was last step.
func _walk(p: CasinoPerson, key: StringName, pos: Vector3, heading: float, delta: float) -> void:
	var last: Vector3 = _walk_last.get(key, pos)
	var moved: float = Vector2(pos.x - last.x, pos.z - last.z).length()
	if moved > 2.0:
		moved = 0.0
	_walk_last[key] = pos
	var speed: float = moved / maxf(delta, 0.001) if delta > 0.0 else 0.0
	p.global_transform = Transform3D(Basis(Vector3.UP, heading), stage.point(pos))
	if speed > 0.05:
		p.walk(moved, speed, time, delta)
	else:
		p.stand(time, delta)


## The runner leaning back on the bar: their chest tipped back, their elbows behind them on the counter; easing out of
## it as they push off.
func _pose_runner(runner: CineActorNode) -> void:
	var k: float = 1.0 - smoothstep(n.push_off_at - 0.25, n.push_off_at + 0.2, time)
	if k <= 0.0:
		return
	var rig: HumanoidRig = runner.avatar.rig
	var chest: Node3D = rig.joint(&"chest")
	if chest != null:
		chest.rotate_object_local(Vector3.RIGHT, deg_to_rad(-LEAN_BACK) * k)
	for side: int in [1, -1]:
		var pre: String = "_l" if side < 0 else "_r"
		BeachOutroBar._blend(rig.joint(StringName("upper_arm" + pre)), VolleyballRival._limb(side, LEAN_UPPER), k)
		BeachOutroBar._blend(rig.joint(StringName("forearm" + pre)), VolleyballRival._limb(side, LEAN_FORE), k)


## The screech sitting on the counter beside the runner: looking about, then where the runner looks, up at them as
## they push off.
func _place_screech(runner: CineActorNode) -> void:
	var shown: bool = time >= n.bar_shot_at and time < n.crowd_shot_at
	screech.visible = shown
	if not shown:
		return
	var pos: Vector3 = CasinoHall.bar_top(n.lean_z + SCREECH_ALONG, SCREECH_IN)
	var heading: float = deg_to_rad(90.0)
	var look: float = lerpf(0.35, -0.25, smoothstep(n.look_out_at, n.look_out_at + 0.6, time))
	var up: float = 0.15 + 0.45 * smoothstep(n.push_off_at - 0.2, n.push_off_at + 0.2, time)
	look = lerpf(look, -0.9, smoothstep(n.push_off_at - 0.2, n.push_off_at + 0.2, time))
	screech.sit(time, look, up, 0.0)
	screech.global_transform = Transform3D(Basis(Vector3.UP, heading), stage.point(pos))


## A guard: its arms out ahead, grabbing, as it lunges; pitched forward as it stumbles on.
func _pose_guard(g: CineActorNode, left: bool) -> void:
	var at: float = n.lunge_left_at if left else n.lunge_right_at
	var k: float = _window(time, at - 0.15, at + 0.1, at + n.lunge_seconds + 0.2, at + n.lunge_seconds + 0.9)
	if k <= 0.0:
		return
	var rig: HumanoidRig = g.body.rig
	var chest: Node3D = rig.joint(&"chest")
	if chest != null:
		chest.rotate_object_local(Vector3.RIGHT, deg_to_rad(-LUNGE_PITCH) * k)
	for side: int in [1, -1]:
		var pre: String = "_l" if side < 0 else "_r"
		BeachOutroBar._blend(rig.joint(StringName("upper_arm" + pre)), VolleyballRival._limb(side, LUNGE_UPPER), k)
		BeachOutroBar._blend(rig.joint(StringName("forearm" + pre)), VolleyballRival._limb(side, LUNGE_FORE), k)


## Over (played out or skipped): the street's light and fog as they were, its people hidden.
func _finish() -> void:
	if not done:
		ZoneSkin.set_scenery_light(_light_before)
		ZoneSkin.set_scenery_tint(_tint_before)
		if stage != null and stage.environment != null:
			stage.environment.fog_enabled = _fog_before
		for node: Node3D in [screech, cane, chairman, escort_black, escort_blonde, croupier, bartender] + players:
			if node != null:
				node.visible = false
	super()


## 0 before `a`, rising to 1 by `b`, 1 until `c`, falling to 0 by `d` (eased in and out).
static func _window(t: float, a: float, b: float, c: float, d: float) -> float:
	return GanglandOutro._window(t, a, b, c, d)


## The stage's street is never seen: no need to keep it built behind anything.
func _stage_near(near: float) -> float:
	return near


## Draw calls its props add now (the hall, the crowd, the people on the rig, the screech): tests.
func props_draw_calls() -> int:
	var calls: int = hall.draw_calls() if hall != null else 0
	for node: Node in [screech, cane] + players + [croupier, bartender, chairman, escort_black, escort_blonde]:
		if node == null or not (node as Node3D).is_visible_in_tree():
			continue
		for mi: Node in node.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			if m.is_visible_in_tree() and m.mesh != null:
				calls += m.mesh.get_surface_count()
		if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
			calls += (node as MeshInstance3D).mesh.get_surface_count()
	return calls
