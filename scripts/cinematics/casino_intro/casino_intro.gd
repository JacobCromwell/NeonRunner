class_name CasinoIntro
extends CinematicSequencer
## The Casino's intro, before Casino 1 (the owner's beats, October 18, 2026; GDD §6 Cinematics, "Casino intro"; the
## casino's front from the owner's reference image, docs/art/reference/casino_brass_lotus.webp):
## 1. Down the covered casino street in the violet sports car (Gangland's outro's, SportsCarModel, its numbers read from
##    that cinematic's data so it stays the same car), the camera low behind it; cut to the casino's front, the Brass Lotus
##    (CasinoIntroLotus: a grand staircase up to its doors, brass columns, the marquee and its name, a violet crest), as
##    the car pulls up beside its steps and stops.
## 2. Beside the car: its scissor door swings up and the runner gets out (CinePoses' get_in played backwards), the screech
##    on the passenger seat looking round at them and nodding; the door comes down; they turn to the steps and walk to
##    their foot.
## 3. Low behind them, looking up the grand staircase. Up it, at the top: the Chairman (CasinoPeople's look), a beautiful
##    woman either side of him (the boss intro's two: black dress and black hair, red dress and blonde hair), shaking
##    hands with a well-to-do businessman and then the "Lady Luck" gambler; then he turns and walks in through the
##    doors with the women, past two cyborg guards in the Casino's look, into the warm light.
## 4. Back to the runner, from up the steps, looking up after him; the Casino's title card, and black.
## A script on the toolkit, its numbers data (`numbers`, by default data/cinematics/casino_intro_tuning.tres,
## CasinoIntroTuning). It plays on one stretch of the zone's street in the level's lanes, the casino in an opening of
## the left wall; everything is worked out from the time (_on_advance), so stepping or skipping shows the same.
## DESIGN-TBD (docs/questions/f2j.md): the staging the beats leave open, the casino's front, who greets him.

const NUMBERS_PATH: String = "res://data/cinematics/casino_intro_tuning.tres"
## The car is Gangland's outro's (its size, paint and accent from that cinematic's numbers).
const CAR_NUMBERS_PATH: String = "res://data/cinematics/gangland_outro_tuning.tres"
## Getting out (CinePoses.get_in played backwards): the share of it by which the near foot is back out over the sill,
## the cabin's floor (metres up, in a car 1 m tall), and how far back in the seat they sit (GanglandOutro's).
const STEP_OVER: float = 0.5
const CABIN_FLOOR: float = 0.16
const SIT_BACK: float = 0.14
## How far from the car's side the runner stands once out (metres).
const DOOR_GAP: float = 0.5
## The car's nose dipping as it stops (degrees) and how long it rocks back.
const BRAKE_DIP: float = 1.6
const BRAKE_ROCK: float = 0.7
## Its lights going down as its engine stops (s).
const LIGHTS_OFF: float = 0.6
## The runner's turn rate (as GanglandOutro's, unhurried).
const TURN_RATE: float = 3.0
## A handshake: how high the hands meet (a share of the shorter one's height) and how far it pumps (metres, twice a
## second).
const SHAKE_HEIGHT: float = 0.62
const SHAKE_PUMP: float = 0.035
const SHAKE_HZ: float = 2.2

## Its numbers (null: NUMBERS_PATH's).
@export var numbers: CasinoIntroTuning

var n: CasinoIntroTuning
var lotus: CasinoIntroLotus
var car: SportsCarModel
var passenger: CarPassenger
var chairman: CasinoPerson
var escort_black: CasinoPerson
var escort_blonde: CasinoPerson
var greeters: Array[CasinoPerson] = []
var cane: MeshInstance3D
## The car's size, paint and accent (Gangland's outro's).
var car_size := Vector3(2.0, 1.1, 4.4)
var car_paint := Color(0.3, 0.12, 0.9)
var car_accent := Color(0.35, 0.85, 1.0)
## Where things are (track space): the car where it stops, the runner's seat in it, where they stand out of it and
## where they stop at the foot of the steps; the Chairman's place greeting people, and the doorway.
var car_stop := Vector3.ZERO
var seat_point := Vector3.ZERO
var out_point := Vector3.ZERO
var foot_stop := Vector3.ZERO
var greet_at := Vector3.ZERO
var doorway := Vector3.ZERO
## When things happen (seconds): the runner is out of the car, reaches the foot of the steps; the Chairman reaches
## the doorway and is gone into the light.
var t_out: float = 0.0
var t_foot: float = 0.0
var t_door: float = 0.0
var t_gone: float = 0.0
## How far the car has driven now (metres from where it starts).
var driven: float = 0.0
var _walk_last: Dictionary = {}


func _numbers() -> CasinoIntroTuning:
	if numbers == null:
		numbers = load(NUMBERS_PATH) as CasinoIntroTuning
	return numbers


func _stage_def() -> CineStageDef:
	n = _numbers()
	var d := CineStageDef.new()
	d.length = n.stage_length
	d.wall_gaps = PackedVector3Array([Vector3(-1.0, n.lotus_at - n.frontage * 0.5, n.lotus_at + n.frontage * 0.5)])
	return d


func _make_timeline() -> CineTimeline:
	n = _numbers()
	var car_numbers := load(CAR_NUMBERS_PATH) as GanglandOutroTuning
	if car_numbers != null:
		car_size = car_numbers.car_size
		car_paint = car_numbers.car_paint
		car_accent = car_numbers.car_accent
	lotus = CasinoIntroLotus.new()
	stage.add_child(lotus)
	lotus.setup(stage.skin, n)
	lotus.global_position = stage.point(Vector3(stage.wall_x(-1), 0.0, n.lotus_at))
	_plan()
	car = SportsCarModel.new()
	car.name = "Car"
	stage.add_child(car)
	car.build(car_size, car_paint, car_accent)
	passenger = CarPassenger.new()
	car.add_child(passenger)
	passenger.setup(car_size, stage.skin.enemy_variant)
	_people()
	var t := CineTimeline.new()
	t.duration = n.duration
	t.letterbox = true
	_runner(t)
	_guards(t)
	_camera(t)
	_events(t)
	_on_advance(0.0)
	return t


## A point of the casino (CasinoIntroLotus's measures: x from the wall's line, z from its front's middle) in track space.
func lp(p: Vector3) -> Vector3:
	return Vector3(stage.wall_x(-1) + p.x, p.y, n.lotus_at + p.z)


## Where and when things happen, from the numbers and the casino's shape.
func _plan() -> void:
	car_stop = lp(Vector3(n.park_out, 0.0, n.park_along))
	# Car space runs along world z, against track space's z.
	var seat: Vector3 = SportsCarModel.seat_of(car_size)
	var floor_y: float = CABIN_FLOOR * SportsCarModel.scale_of(car_size).y
	seat_point = car_stop + Vector3(seat.x, floor_y, -seat.z - SIT_BACK)
	var step: Vector3 = SportsCarModel.door_step_of(car_size)
	out_point = car_stop + Vector3(step.x - DOOR_GAP, 0.0, -step.z)
	t_out = n.get_out_at + n.get_out_seconds
	foot_stop = lp(lotus.foot_point(n.stop_out, n.stop_along))
	t_foot = maxf(n.walk_at, t_out + 0.3) + Vector2(foot_stop.x - out_point.x, foot_stop.z - out_point.z).length() / n.walk_speed + 0.4
	greet_at = lp(lotus.terrace_point(n.greet_point.x, n.greet_point.y))
	doorway = lp(lotus.door_point())
	t_door = n.go_in_at + 0.5 + Vector2(doorway.x - greet_at.x, doorway.z - greet_at.z).length() / n.walk_speed_chairman
	t_gone = t_door + n.gone_past / n.walk_speed_chairman
	if t_gone > n.runner_shot_at:
		push_warning("CasinoIntro: the Chairman is gone through the doors at %.2f s, after the cut back to the runner (%.2f s)" % [
			t_gone, n.runner_shot_at])


func _person(look: CasinoPeople.Look, height: float, node_name: String) -> CasinoPerson:
	var p := CasinoPerson.new()
	stage.add_child(p)
	p.setup(look, height)
	p.name = node_name
	return p


func _people() -> void:
	chairman = _person(CasinoPeople.Look.CHAIRMAN, n.chairman_height, "Chairman")
	escort_black = _person(CasinoPeople.Look.ESCORT_BLACK, n.woman_height * 1.02, "EscortBlack")
	escort_blonde = _person(CasinoPeople.Look.ESCORT_BLONDE, n.woman_height * 1.01, "EscortBlonde")
	greeters.append(_person(CasinoPeople.Look.HIGH_ROLLER, n.man_height * 1.02, "HighRoller"))
	greeters.append(_person(CasinoPeople.Look.LADY_LUCK, n.woman_height * 0.97, "LadyLuck"))
	# His cane (the boss intro's): a black lacquered shaft with a brass head, in his left hand.
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(lotus.solid_material())
	s.prism(Vector3.ZERO, 0.012, 0.86, 6, Color(0.05, 0.05, 0.06), 0.0, MeshKit.PAT_PLAIN)
	s.prism(Vector3(0.0, 0.84, 0.0), 0.022, 0.06, 8, CasinoHall.BRASS, 0.0, MeshKit.PAT_CASINO_BRASS, true, 0.9)
	s.prism(Vector3(0.0, -0.01, 0.0), 0.016, 0.02, 6, CasinoHall.BRASS_DARK, 0.0, MeshKit.PAT_CASINO_BRASS, true, 0.6)
	cane = MeshBatch.add_instance(stage, batch.to_mesh(), "Cane")
	cane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# --- The car ---------------------------------------------------------------------------------------------------

## How far the car still has to go to where it stops at `t` (metres): cruising, then braking evenly to a stop.
func car_remaining(t: float) -> float:
	var brake: float = maxf(n.stop_at - n.brake_at, 0.05)
	var v: float = n.cruise_speed
	if t >= n.stop_at:
		return 0.0
	if t >= n.brake_at:
		var e: float = n.stop_at - t
		return 0.5 * (v / brake) * e * e
	return 0.5 * v * brake + v * (n.brake_at - t)


## Where the car is at `t` (track space, its middle on the road).
func car_at(t: float) -> Vector3:
	return car_stop - Vector3(0.0, 0.0, car_remaining(t))


func _drive_car() -> void:
	var start: float = car_remaining(0.0)
	var left: float = car_remaining(time)
	driven = start - left
	car.set_travelled(driven)
	car.set_lights(1.0 - smoothstep(n.engine_off_at, n.engine_off_at + LIGHTS_OFF, time))
	var up: float = smoothstep(n.door_up_at, n.door_up_at + n.door_seconds, time)
	var down: float = smoothstep(n.door_down_at, n.door_down_at + n.door_seconds, time)
	car.set_door(up * (1.0 - down))
	car.set_interior(smoothstep(n.door_up_at, n.door_up_at + 0.4, time) * (1.0 - smoothstep(n.door_down_at + n.door_seconds,
		n.door_down_at + n.door_seconds + 0.6, time)))
	passenger.update(time, n.passenger_looks_at, n.passenger_nods_at)
	# Its nose dipping as it pulls up, rocking back as it settles.
	var dip: float = 0.0
	if time > n.brake_at and time < n.stop_at:
		dip = smoothstep(n.brake_at, n.brake_at + 0.6, time)
	elif time >= n.stop_at:
		var e: float = time - n.stop_at
		dip = cos(e * TAU / BRAKE_ROCK) * exp(-e * 5.0) if e < BRAKE_ROCK * 2.0 else 0.0
	var basis := Basis(Vector3.RIGHT, -deg_to_rad(BRAKE_DIP) * dip)
	var mid := Vector3(0.0, SportsCarModel.REAR_RADIUS * SportsCarModel.scale_of(car_size).y, 0.0)
	car.global_transform = Transform3D(basis, stage.point(car_at(time)) + mid - basis * mid)


# --- The runner ------------------------------------------------------------------------------------------------

func _runner(t: CineTimeline) -> void:
	var r: CineActor = t.actor(&"runner")
	r.turn_rate = TURN_RATE
	r.enter = n.door_up_at
	# Sat in the car, then out of it (get_in backwards): the near foot out over the sill, standing up beside it.
	var sat: CineActorKey = GanglandOutro._turned(r.at(0.0, seat_point, &"get_in"), 0.0, 0.0)
	sat.progress = 1.0
	var wait: CineActorKey = GanglandOutro._turned(r.at(n.get_out_at, seat_point), 0.0, 0.0)
	wait.progress = 1.0
	var over: Vector3 = out_point.lerp(seat_point, 0.45)
	over.y = 0.0
	var step_out: CineActorKey = GanglandOutro._turned(GanglandOutro._eased(r.at(n.get_out_at + n.get_out_seconds * (1.0 - STEP_OVER), over)), 0.0, 0.0)
	step_out.progress = STEP_OVER
	var stood: CineActorKey = GanglandOutro._turned(GanglandOutro._eased(r.at(t_out, out_point)), 0.0, 0.0)
	stood.progress = 0.0
	# Looking round over the car's roof at the casino, then turning to its steps and walking to their foot.
	GanglandOutro._turned(r.at(maxf(n.turn_at - 0.4, t_out + 0.05), out_point, &"walk"), 0.0, 35.0).look_up = 12.0
	var facing: float = rad_to_deg(CasinoBossIntro.heading_of(out_point, foot_stop))
	var go: float = maxf(n.walk_at, t_out + 0.3)
	GanglandOutro._turned(r.at(go, out_point), facing, 0.0).look_up = 10.0
	var settle: float = 0.4
	var walk_end: float = t_foot - settle
	var far: Vector3 = foot_stop + (out_point - foot_stop).normalized() * n.walk_speed * settle * 0.5
	r.at(walk_end, far).face_path = true
	GanglandOutro._eased(r.at(t_foot, foot_stop), Tween.TRANS_QUAD, Tween.EASE_OUT).face_path = true
	# At the foot of the steps, squaring up to them and looking up to the top.
	var up_steps: float = 90.0
	GanglandOutro._turned(r.at(t_foot + 0.5, foot_stop), up_steps, 0.0).look_up = n.look_up * 0.6
	var k: CineActorKey = GanglandOutro._turned(r.at(maxf(n.stairs_shot_at + 1.2, t_foot + 1.1), foot_stop), up_steps, 0.0)
	k.look_up = n.look_up
	# Following the Chairman's way to the doors, then holding on them.
	var to_door: float = clampf(rad_to_deg(CasinoBossIntro.heading_of(foot_stop, doorway)) - up_steps, -40.0, 40.0)
	GanglandOutro._turned(r.at(n.go_in_at, foot_stop), up_steps, 0.0).look_up = n.look_up
	GanglandOutro._turned(r.at(t_door, foot_stop), up_steps, to_door * 0.5).look_up = n.look_up * 0.95
	GanglandOutro._turned(r.at(n.duration, foot_stop), up_steps, to_door * 0.3).look_up = n.look_up * 0.85


# --- The guards ------------------------------------------------------------------------------------------------

## Two cyborg guards in the Casino's look either side of the doorway on the terrace, facing the street, turning to
## watch the Chairman go in.
func _guards(t: CineTimeline) -> void:
	for side: float in [-1.0, 1.0]:
		var id: StringName = &"guard_l" if side < 0.0 else &"guard_r"
		var g: CineActor = t.actor(id, CineActor.Kind.CYBORG, &"casino")
		var at: Vector3 = lp(lotus.terrace_point(lotus.top_x - lotus.face_x - 0.7, side * (n.door_width * 0.5 + 0.75)))
		var k0: CineActorKey = g.at(0.0, at, &"idle")
		k0.face_path = false
		k0.yaw = -90.0
		var k1: CineActorKey = g.at(n.go_in_at + 0.6, at)
		k1.face_path = false
		k1.yaw = -90.0
		var k2: CineActorKey = g.at(n.go_in_at + 1.4, at)
		k2.face_path = false
		k2.yaw = -90.0
		k2.look = side * 50.0
		var k3: CineActorKey = g.at(t_gone + 0.6, at)
		k3.face_path = false
		k3.yaw = -90.0
		k3.look = side * 70.0
		var k4: CineActorKey = g.at(t_gone + 1.4, at)
		k4.face_path = false
		k4.yaw = -90.0


# --- The Chairman and the people at the top ----------------------------------------------------------------------

## His place at `t`: greeting people at the top of the steps, then walking in through the doors.
func chairman_at(t: float) -> Vector3:
	var start: float = n.go_in_at + 0.5
	if t <= start:
		return greet_at
	var to_door: Vector3 = doorway - greet_at
	var along: float = (t - start) * n.walk_speed_chairman
	var reach: float = to_door.length()
	if along <= reach:
		# Easing into the walk over its first half metre.
		var e: float = minf(along, 0.5)
		along = along - 0.5 + e * e if along < 0.5 else along - 0.25
		return greet_at + to_door.normalized() * maxf(along, 0.0)
	return doorway + Vector3(-1.0, 0.0, 0.0) * (along - 0.25 - reach)


## His heading (radians): toward the street greeting people, turning round to the doors and walking in.
func chairman_heading(t: float) -> float:
	var out: float = -PI * 0.5
	var into: float = CasinoBossIntro.heading_of(greet_at, doorway)
	var u: float = smoothstep(n.go_in_at, n.go_in_at + 0.7, t)
	# Turning by his left (+), round past looking up the street.
	return out + wrapf(into - out, 0.0, TAU) * u


## Where a woman beside him stands at `t` (`side` -1 toward the lower z, 1 the higher): either side of him along the
## street, a step back and a little wider while he greets people, closing in beside him as he walks.
func escort_at(t: float, side: float) -> Vector3:
	var c: Vector3 = chairman_at(t)
	var walking: float = smoothstep(n.go_in_at + 0.3, n.go_in_at + 1.1, t)
	var off: Vector2 = n.escort_greeting.lerp(n.escort_offset, walking)
	# Behind him: toward the doors as he greets people (he faces the street), toward the street as he walks in.
	var back: float = lerpf(-off.y, off.y, walking)
	return c + Vector3(back, 0.0, side * off.x)


## Where greeter `i` stands, facing him: in his frame as he greets people.
func greeter_at(i: int) -> Vector3:
	var off: Vector2 = n.greeter_a if i == 0 else n.greeter_b
	return CasinoBossIntro.in_frame(greet_at, -PI * 0.5, off)


func _pose_people(delta: float) -> void:
	var shown: bool = time >= n.stairs_shot_at - 0.5 and time < t_gone
	for p: CasinoPerson in [chairman, escort_black, escort_blonde]:
		p.visible = shown
	cane.visible = shown
	for p: CasinoPerson in greeters:
		p.visible = time >= n.stairs_shot_at - 0.5 and time < n.runner_shot_at
	if not shown and not greeters[0].visible:
		return
	var heading: float = chairman_heading(time)
	if shown:
		_walk(chairman, &"chairman", chairman_at(time), heading, delta)
		_walk(escort_black, &"black", escort_at(time, -1.0), heading, delta)
		_walk(escort_blonde, &"blonde", escort_at(time, 1.0), heading, delta)
	# The greeters, facing him; each shaking his hand in turn, then watching him go.
	for i: int in greeters.size():
		var g: CasinoPerson = greeters[i]
		if not g.visible:
			continue
		var at: Vector3 = greeter_at(i)
		var face: float = CasinoBossIntro.heading_of(at, greet_at)
		g.global_transform = Transform3D(Basis(Vector3.UP, face), stage.point(at))
		g.stand(time + 1.3 * float(i), delta)
		g.look_at_point(chairman.head_point(), 1.0)
	if not shown:
		return
	# The handshakes: his right hand in theirs, pumping; he looks at each in turn.
	var shakes: Array[float] = [n.shake_a_at, n.shake_b_at]
	for i: int in greeters.size():
		var k: float = _window(time, shakes[i], shakes[i] + 0.35, shakes[i] + n.shake_seconds - 0.3, shakes[i] + n.shake_seconds)
		if k <= 0.0:
			continue
		var g: CasinoPerson = greeters[i]
		var meet: Vector3 = (chairman.global_position + g.global_position) * 0.5
		meet.y = stage.point(greet_at).y + minf(n.chairman_height, n.woman_height) * SHAKE_HEIGHT
		meet.y += SHAKE_PUMP * sin(TAU * SHAKE_HZ * (time - shakes[i])) * k
		chairman.shake_hand(meet, k)
		g.shake_hand(meet, k)
	var look_k: float = 1.0 - smoothstep(n.go_in_at - 0.2, n.go_in_at + 0.3, time)
	if look_k > 0.0:
		var who: int = 0 if time < (n.shake_a_at + n.shake_seconds + n.shake_b_at) * 0.5 else 1
		chairman.look_at_point(greeters[who].head_point(), look_k)
		escort_black.look_at_point(greeters[who].head_point(), 0.5 * look_k)
		escort_blonde.look_at_point(greeters[who].head_point(), 0.5 * look_k)
	# His cane in his left hand.
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


# --- The camera --------------------------------------------------------------------------------------------------

func _camera(t: CineTimeline) -> void:
	# Low behind the car's left rear quarter, riding with it down the covered street.
	var steps: int = 6
	for i: int in steps + 1:
		var at: float = lerpf(0.0, n.front_shot_at - 0.004, float(i) / float(steps))
		var c: Vector3 = car_at(at)
		var lead: float = float(i) / float(steps)
		t.shot(at, c + Vector3(-1.9 + 0.3 * lead, 0.75, -5.6 + 0.8 * lead), c + Vector3(0.2, 0.55, 7.0), CinePath.Move.SMOOTH, 54.0)
	# Cut: the casino's front from across the street, the car coming in from behind the camera and pulling up at its
	# steps; craning up a little as it stops.
	var face: Vector3 = lp(Vector3(lotus.face_x, 0.0, 0.0))
	var across: float = stage.wall_x(1) - 1.0
	var from := Vector3(across, 1.5, n.lotus_at - 21.0)
	t.shot(n.front_shot_at, from, Vector3(face.x + 3.0, 5.2, n.lotus_at + 1.0), CinePath.Move.CUT, 60.0)
	t.shot(n.door_shot_at - 0.004, from + Vector3(-0.4, 1.0, 2.2), Vector3(face.x + 3.0, 6.4, n.lotus_at + 1.0), CinePath.Move.SMOOTH, 58.0)
	# Cut: low off the car's front corner on the casino's side, looking back at its door as the runner gets out, then
	# round after them as they turn to the steps.
	var corner: Vector3 = car_stop + Vector3(-2.6, 0.75, 3.4)
	t.shot(n.door_shot_at, corner, out_point + Vector3(0.3, 0.75, 0.0), CinePath.Move.CUT, 50.0)
	t.shot(t_out, corner + Vector3(-0.2, 0.15, -0.3), out_point + Vector3(0.2, 0.9, 0.0), CinePath.Move.SMOOTH, 50.0)
	var follow: CineCameraKey = t.shot(n.stairs_shot_at - 0.004, corner + Vector3(-0.6, 0.35, -1.2), Vector3(0.0, 0.9, 0.0),
		CinePath.Move.SMOOTH, 52.0)
	follow.watch = &"runner"
	# Cut: low behind the runner at the foot of the steps, tilting up the grand staircase to the top.
	var behind: Vector3 = foot_stop + Vector3(1.7, 0.55, -0.9)
	var top: Vector3 = lp(Vector3(lotus.top_x - 1.0, n.stairs_rise + 1.2, 0.0))
	t.shot(n.stairs_shot_at, behind, foot_stop + Vector3(-2.0, 1.6, 0.3), CinePath.Move.CUT, 56.0)
	t.shot(n.greet_shot_at - 0.004, behind + Vector3(0.25, -0.1, -0.15), top, CinePath.Move.SMOOTH, 56.0)
	# Cut: up the steps from beside the runner's head, close on the Chairman greeting people.
	var eye: Vector3 = foot_stop + Vector3(0.35, 1.25, -0.45)
	var group: Vector3 = greet_at + Vector3(0.35, 0.95, 0.0)
	t.shot(n.greet_shot_at, eye, group, CinePath.Move.CUT, 22.0)
	t.shot(n.enter_shot_at - 0.004, eye + Vector3(0.0, 0.0, 0.1), group + Vector3(0.0, 0.0, 0.05), CinePath.Move.SMOOTH, 21.0)
	# Cut: wider, after him as he walks in with the women, into the light.
	var door_look: Vector3 = doorway + Vector3(0.6, 1.4, 0.0)
	t.shot(n.enter_shot_at, eye + Vector3(0.2, 0.05, 0.0), greet_at.lerp(door_look, 0.3) + Vector3(0.0, 1.0, 0.0), CinePath.Move.CUT, 34.0)
	t.shot(n.runner_shot_at - 0.004, eye + Vector3(0.1, 0.05, 0.05), door_look, CinePath.Move.SMOOTH, 30.0)
	# Cut: back to the runner, from a few steps up, looking down at them; easing in as the title comes up.
	var up_steps: Vector3 = foot_stop + Vector3(-2.1, lotus.step_height(foot_stop.x - stage.wall_x(-1) - 2.1) + 0.7, 0.55)
	# The runner a little left of the middle (the camera faces the street: its right is -z) and high, clear of the card.
	var r0: CineCameraKey = t.shot(n.runner_shot_at, up_steps, Vector3(0.0, 0.72, -0.75), CinePath.Move.CUT, 48.0)
	r0.watch = &"runner"
	var r1: CineCameraKey = t.shot(n.duration, up_steps + Vector3(0.35, -0.05, -0.1), Vector3(0.0, 0.76, -0.7), CinePath.Move.SMOOTH, 42.0)
	r1.watch = &"runner"


## The street stays built back far enough for the first shots looking down it past the car, and for the shots looking
## back from the steps.
func _stage_near(near: float) -> float:
	return minf(near, car_at(0.0).z - 20.0)


# --- Sounds, effects and cues --------------------------------------------------------------------------------------

func _events(t: CineTimeline) -> void:
	t.effect(0.0, CineEvent.FADE_IN, n.fade_in)
	t.music(0.0, CineEvent.ZONE_MUSIC, n.music_fade)
	t.sound(0.1, &"car_cruise")
	t.sound(2.3, &"car_cruise")
	t.sound(n.engine_off_at - 2.0, &"car_arrive")
	# The murmur of the casino's front, from the cut to it.
	var at: float = n.front_shot_at
	while at < n.fade_at:
		t.sound(at, &"casino_bustle", -4.0)
		at += 2.1
	t.sound(n.door_up_at, &"car_door")
	t.sound(n.passenger_nods_at, &"screech_chirp", -4.0)
	t.sound(n.door_down_at, &"car_door")
	t.card(n.card_at, "{zone}", "ZONE {zone_number}", n.card_seconds)
	t.effect(n.fade_at, CineEvent.FADE_OUT, n.fade_out)


# --- On the clock ------------------------------------------------------------------------------------------------

func _on_advance(delta: float) -> void:
	if n == null or car == null:
		return
	_drive_car()
	_pose_people(delta)


## Over (played out or skipped): its people hidden.
func _finish() -> void:
	if not done:
		for node: Node3D in [cane, chairman, escort_black, escort_blonde] + greeters:
			if node != null:
				node.visible = false
	super()


## 0 before `a`, rising to 1 by `b`, 1 until `c`, falling to 0 by `d` (eased in and out).
static func _window(t: float, a: float, b: float, c: float, d: float) -> float:
	return GanglandOutro._window(t, a, b, c, d)


## Draw calls its props add now (the casino, the car, the people on the rig): tests.
func props_draw_calls() -> int:
	var calls: int = lotus.draw_calls() if lotus != null else 0
	if car != null and car.is_visible_in_tree():
		calls += car.draw_call_count()
	for node: Node in [cane, chairman, escort_black, escort_blonde] + greeters:
		if node == null or not (node as Node3D).is_visible_in_tree():
			continue
		for mi: Node in node.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			if m.is_visible_in_tree() and m.mesh != null:
				calls += m.mesh.get_surface_count()
		if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
			calls += (node as MeshInstance3D).mesh.get_surface_count()
	return calls
