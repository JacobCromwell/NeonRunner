class_name CityOutro
extends CinematicSequencer
## The Neon City's outro (task F2a; the owner's story beats, GDD §6 Cinematics, October 8, 2026): after the
## Floating Head, on the way to Gangland. The owner approved the scene as built (October 9, 2026); the
## staging choices it made stay DESIGN-TBD until the owner decides them (docs/OPEN_QUESTIONS.md §D, items
## 369–381).
## 1. The Floating Head crashes. Seen from the run camera (above and behind the runner, as in play), the
##    dying ship plunges into the street ahead and breaks up into the fight's wreck (CityOutroSet).
## 2. The camera comes down to the runner's level as they slow to a stop, the wreck smoking ahead.
## 3. They look left, and the camera pans with them: in a side street opening off the left, a roadblock
##    (the game's own enemies: Barnacle Turrets standing in the barricade like cannons, a row of five
##    cyborgs, a battle truck behind them, a heli drone over it) comes alive: siren, light bar, arm cannons.
## 4. The camera pans back to the runner, startled; they turn and run the other way, to an opening in the
##    right wall, and leap off the truck roof out over the drop as the roadblock fires: a blast on the
##    edge behind them, seen from out over the drop.
## 5. They fall into the haze; under black the scene cuts to the next zone's street (Gangland), where they
##    drop in, land, look about and run off. The next zone's intro follows.
##
## A script on the toolkit, its numbers data (`outro`, by default data/cinematics/city_outro_tuning.tres,
## CityOutroTuning). The City's stretch is the zone's own look (CineStage.skin_for) and the landing the
## next zone's (its ZoneDef.skin), on the level's lanes, so a later change of either reaches it. No music
## but the zone's own, which fades as the runner leaps (the next zone's comes with its intro; the web
## demo, which stops after this, never loads it).

const OUTRO_PATH: String = "res://data/cinematics/city_outro_tuning.tres"
const BOSS_TUNING_PATH: String = "res://data/bosses/city_boss_tuning.tres"
## The landing's look when there's no campaign to ask for the next zone's (a scene played on its own).
const NEXT_SKIN_PATH: String = "res://data/skins/gangland_skin.tres"
const CYBORGS: int = 5
## The blast's flash: the fire's orange-white (a slow, faint glow with Reduced flashing).
const BLAST_FLASH := Color(1.0, 0.78, 0.5)

## Its numbers (null: OUTRO_PATH's).
@export var outro: CityOutroTuning

## The props (the ship, the roadblock, the shots and the blast), and the boss's numbers the ship is built to.
var props: CityOutroSet
var boss_tuning: FloatingHeadTuning
## Where things happen (track space, metres along the track): where the runner stops, where the ship's face
## comes down, the side street's middle, the edge the runner leaps from (x, z) and the blast.
var stop_z: float = 0.0
var crash_z: float = 0.0
var side_mid: float = 0.0
var edge := Vector2.ZERO
var blast_at := Vector3.ZERO
## When things happen (seconds): the crash, the flight away (flee), the leap, the blast, the cut to the next
## zone and the landing.
var t_crash: float = 0.0
var t_flee: float = 0.0
var t_leap: float = 0.0
var t_blast: float = 0.0
var t_black: float = 0.0
var t_cut: float = 0.0
var t_land: float = 0.0
var t_run: float = 0.0
## True once the scene has cut to the next zone.
var landed_stage: bool = false


func numbers() -> CityOutroTuning:
	if outro == null:
		outro = load(OUTRO_PATH) as CityOutroTuning
	return outro


## Where along the track the runner is at time `t` while still running in (before they slow).
func runner_at(t: float) -> float:
	return tuning.run_speed * t


func _stage_def() -> CineStageDef:
	var f: CityOutroTuning = numbers()
	boss_tuning = load(BOSS_TUNING_PATH) as FloatingHeadTuning
	_plan(f)
	var d := CineStageDef.new()
	var half: float = f.side_lanes * tuning.lane_width * 0.5 + f.side_margin
	d.wall_gaps = PackedVector3Array([Vector3(-1.0, side_mid - half, side_mid + half),
		Vector3(1.0, stop_z - f.opening_before, stop_z + f.opening_after)])
	return d


## Where and when things happen, from the numbers.
func _plan(f: CityOutroTuning) -> void:
	var v: float = tuning.run_speed
	# Slowing with an eased stop (a quadratic ease-out) keeps the run speed going into it.
	stop_z = v * (f.slow_from + (f.stop_at - f.slow_from) * 0.5)
	crash_z = stop_z + f.crash_beyond_stop
	side_mid = stop_z + f.side_ahead
	t_crash = f.fall_start + f.fall_seconds
	t_flee = f.startle_at + f.startle_seconds
	t_leap = t_flee + f.flee_seconds
	t_blast = t_leap + f.blast_after
	t_black = t_leap + f.fall_shown
	t_cut = t_black + f.black_seconds + f.black_hold
	t_land = t_cut + f.drop_seconds
	t_run = t_land + f.run_off_after


func _make_timeline() -> CineTimeline:
	var f: CityOutroTuning = numbers()
	edge = Vector2(stage.wall_x(1) - 0.25, stop_z + f.flee_ahead)
	blast_at = Vector3(edge.x - f.blast_back, 0.2, edge.y - 0.3)
	var t := CineTimeline.new()
	t.duration = f.duration
	t.letterbox = true
	_build_props(f)
	_runner(t, f)
	_cyborgs(t, f)
	_camera(t, f)
	_events(t, f)
	return t


func _build_props(f: CityOutroTuning) -> void:
	props = CityOutroSet.new()
	props.name = "Props"
	add_child(props)
	props.build_ship(stage, boss_tuning if boss_tuning != null else FloatingHeadTuning.new())
	props.build_roadblock(stage, f, side_mid, 7)
	props.build_opening(stage, f, stop_z + (f.opening_after - f.opening_before) * 0.5,
		(f.opening_before + f.opening_after) * 0.5)


# --- The runner ----------------------------------------------------------------------------------

func _runner(t: CineTimeline, f: CityOutroTuning) -> void:
	var r: CineActor = t.actor(&"runner")
	var v: float = tuning.run_speed
	r.at(0.0, Vector3.ZERO, &"run")
	r.at(f.slow_from, Vector3(0.0, 0.0, runner_at(f.slow_from)))
	_eased(r.at(f.stop_at, Vector3(0.0, 0.0, stop_z)), Tween.TRANS_QUAD, Tween.EASE_OUT)
	# They look left, their body turning a little with their head.
	var settle: float = f.stop_at + 0.1
	_turned(r.at(settle, Vector3(0.0, 0.0, stop_z)), 0.0, 0.0)
	_turned(_eased(r.at(settle + f.look_seconds, Vector3(0.0, 0.0, stop_z))), f.look_body_degrees, f.look_degrees)
	_turned(r.at(f.startle_at, Vector3(0.0, 0.0, stop_z)), f.look_body_degrees, f.look_degrees)
	# DESIGN-TBD (docs/OPEN_QUESTIONS.md §D, item 377): startled, a hop back to the right (the jump pose), the head
	# snapping round; they land facing their way out.
	var hop: CineActorKey = r.at(f.startle_at + f.startle_seconds * 0.45, Vector3(0.3, f.startle_hop, stop_z - 0.15))
	_turned(_eased(hop, Tween.TRANS_SINE, Tween.EASE_OUT), -10.0, 15.0)
	var landing: CineActorKey = _eased(r.at(t_flee, Vector3(0.55, 0.0, stop_z - 0.2)), Tween.TRANS_SINE, Tween.EASE_IN)
	landing.face_path = true
	# DESIGN-TBD (docs/OPEN_QUESTIONS.md §D, item 374): "the opposite direction" is away from the roadblock, at a
	# sprint to the right wall's opening (speeding up from a standstill).
	_eased(r.at(t_leap, Vector3(edge.x, 0.0, edge.y)), Tween.TRANS_QUAD, Tween.EASE_IN)
	# The leap off the truck roof: a jump's arc out over the drop, falling on under the same pull.
	var g: float = 2.0 * f.leap_height / (f.leap_apex_seconds * f.leap_apex_seconds)
	var up: float = g * f.leap_apex_seconds
	var out: float = f.leap_out / f.leap_apex_seconds
	var along: float = clampf(f.flee_ahead / maxf(f.flee_seconds, 0.1), 0.0, v) * 0.5
	var flight: float = t_cut - 0.02 - t_leap
	var steps: int = maxi(ceili(flight / 0.06), 2)
	for i: int in range(1, steps + 1):
		var s: float = flight * float(i) / steps
		r.at(t_leap + s, Vector3(edge.x + out * s, up * s - 0.5 * g * s * s, edge.y + along * s))
	# In the next zone: they drop in from above, land, look about, and run off down the street.
	var drop: CineActorKey = r.at(t_cut, Vector3(0.0, f.drop_height, f.land_at - 1.0))
	drop.move = CinePath.Move.CUT
	_turned(drop, 0.0, 0.0)
	_turned(_eased(r.at(t_land, Vector3(0.0, 0.0, f.land_at)), Tween.TRANS_QUAD, Tween.EASE_IN), 0.0, 0.0)
	var about: float = t_run - t_land
	_turned(_eased(r.at(t_land + about * 0.35, Vector3(0.0, 0.0, f.land_at))), 0.0, 35.0)
	_turned(_eased(r.at(t_land + about * 0.75, Vector3(0.0, 0.0, f.land_at))), 0.0, -25.0)
	var go: CineActorKey = _eased(r.at(t_run, Vector3(0.0, 0.0, f.land_at)))
	go.face_path = true
	var run_off: float = maxf(f.duration - t_run, 0.1)
	_eased(r.at(f.duration, Vector3(0.0, 0.0, f.land_at + v * run_off * 0.5)), Tween.TRANS_QUAD, Tween.EASE_IN)


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


# --- The roadblock's cyborgs -----------------------------------------------------------------------

## The five cyborgs in a row behind the barricade, facing the main street: they stand, raise their arm
## cannons at the runner one after another, charge (the red glow: the shots follow) and fire. Gone at the cut.
func _cyborgs(t: CineTimeline, f: CityOutroTuning) -> void:
	var x: float = stage.wall_x(-1) - f.cyborgs_in
	var launch: float = t_blast - f.shots_seconds
	for i: int in CYBORGS:
		var c: CineActor = t.actor(StringName("cyborg_%d" % (i + 1)), CineActor.Kind.CYBORG)
		c.leave = t_cut
		var at := Vector3(x, 0.0, side_mid + (float(i) - (CYBORGS - 1) * 0.5) * f.cyborg_spacing)
		var k: CineActorKey = c.at(0.0, at, &"idle")
		k.expression = &"neutral"
		k.charge = 0.0
		var aim: CineActorKey = c.at(f.aim_at + 0.09 * i, at, &"aim")
		aim.aim_at = &"runner"
		aim.expression = &"aiming"
		c.at(f.charge_at + 0.05 * i, at).charge = 0.35
		c.at(lerpf(f.charge_at, launch, 0.5), at).charge = 0.7
		c.at(launch - 0.06 * i, at).charge = 1.0
		c.at(launch - 0.06 * i + 0.12, at).charge = 0.0
		for key: CineActorKey in c.keys:
			key.face_path = false
			key.yaw = -90.0  # Facing the main street.


# --- The camera ----------------------------------------------------------------------------------

func _camera(t: CineTimeline, f: CityOutroTuning) -> void:
	var side: float = stage.origin_x * (tuning.camera_follow_x - 1.0)
	# The run camera's view, looking a little higher at the ship ahead, through the crash.
	for at: float in [0.0, t_crash + 0.2]:
		_ride(t.shot(at, Vector3(side, tuning.camera_height, -tuning.camera_distance),
			Vector3(side, 1.0 + f.open_look_up, tuning.camera_look_ahead), CinePath.Move.SMOOTH, tuning.camera_fov))
	# Down to the runner's level as they stop, behind them to their left, looking past them at the wreck.
	_ride(t.shot(f.stop_at, Vector3(-f.ground_side, f.ground_height, -f.ground_behind), Vector3(0.0, 1.2, 12.0),
		CinePath.Move.SMOOTH, f.fov))
	_ride(t.shot(f.pan_at, Vector3(-f.ground_side - 0.1, f.ground_height + 0.15, -f.ground_behind + 0.1),
		Vector3(-0.8, 1.2, 8.0), CinePath.Move.SMOOTH, f.fov))
	# The pan left over their shoulder onto the roadblock, the lens narrowing, then a slow push in on it.
	# Pans are eased straight moves: a smooth path would swing past what it turns to.
	var eye := Vector3(-f.ground_side - 0.1, f.ground_height + 0.35, stop_z - f.ground_behind + 0.2)
	var block := Vector3(stage.wall_x(-1) - (f.cyborgs_in + f.truck_in) * 0.5, 1.9, side_mid)
	_pan(t.shot(f.pan_at + f.pan_seconds, eye, block, CinePath.Move.LINEAR, f.reveal_fov))
	var pushed: Vector3 = eye + (block - eye).normalized() * f.push_in
	pushed.y = eye.y
	var held: CineCameraKey = t.shot(f.pan_back_at, pushed, block + Vector3(0.0, 0.3, 0.0), CinePath.Move.LINEAR,
		f.reveal_fov - 4.0)
	held.trans = Tween.TRANS_LINEAR
	# The pan back to the runner as they're startled, then watching them turn and run for the opening.
	var back: CineCameraKey = _pan(t.shot(f.pan_back_at + f.pan_back_seconds, pushed, Vector3(0.0, 1.1, 0.0),
		CinePath.Move.LINEAR, f.fov))
	back.watch = &"runner"
	var follow: CineCameraKey = t.shot(t_leap - 0.12, pushed, Vector3(0.0, 1.0, 0.0), CinePath.Move.LINEAR, f.fov)
	follow.watch = &"runner"
	follow.trans = Tween.TRANS_LINEAR
	# Cut: out over the drop at their height, looking back at the edge as they leap toward the camera, the
	# blast going off behind them; then down after them as they fall past.
	var out := Vector3(stage.wall_x(1) + f.leap_cam_out, f.leap_cam_height, edge.y + f.leap_cam_ahead)
	t.shot(t_leap - 0.1, out, Vector3(edge.x - 1.0, 1.0, edge.y), CinePath.Move.CUT, f.leap_fov)
	t.shot(t_blast + 0.2, out, Vector3(edge.x + 1.0, 1.0, edge.y + 0.5), CinePath.Move.SMOOTH, f.leap_fov)
	var down: CineCameraKey = t.shot(t_black + f.black_seconds, out + Vector3(0.0, 0.5, 0.0), Vector3(0.0, 0.3, 0.0),
		CinePath.Move.SMOOTH, f.leap_fov)
	down.watch = &"runner"
	# Cut, under black: low in the next zone's street, behind where they land, watching them come down,
	# look about and run off into it.
	var land := Vector3(f.land_cam_side, f.land_cam_height, f.land_at - f.land_cam_behind)
	t.shot(t_cut, land, Vector3(0.0, 1.8, f.land_at), CinePath.Move.CUT, f.fov)
	_pan(t.shot(t_land, land, Vector3(0.0, 1.0, f.land_at), CinePath.Move.LINEAR, f.fov))
	var watch_go: CineCameraKey = t.shot(t_run, land, Vector3(0.0, 1.0, 0.0), CinePath.Move.LINEAR, f.fov)
	watch_go.watch = &"runner"
	var gone: CineCameraKey = t.shot(f.duration, land + Vector3(0.0, 0.3, 2.0), Vector3(0.0, 1.0, 3.0),
		CinePath.Move.SMOOTH, f.fov)
	gone.watch = &"runner"


## A pan: eased in and out (a LINEAR move with a sine curve).
static func _pan(k: CineCameraKey) -> CineCameraKey:
	k.trans = Tween.TRANS_SINE
	k.easing = Tween.EASE_IN_OUT
	return k


## The key rides along with the runner (its position and target are offsets from them).
static func _ride(k: CineCameraKey) -> CineCameraKey:
	k.follow = &"runner"
	k.watch = &"runner"
	return k


# --- Sounds, effects and cues --------------------------------------------------------------------

func _events(t: CineTimeline, f: CityOutroTuning) -> void:
	t.effect(0.0, CineEvent.FADE_IN, f.fade_in)
	t.music(0.0, CineEvent.ZONE_MUSIC, 0.6)
	t.sound(f.fall_start, &"head_power_down")
	t.sound(t_crash, &"head_crash")
	t.effect(t_crash, CineEvent.SHAKE, 0.9, 0.35)
	t.cue(t_crash, &"crash")
	t.sound(f.siren_at, &"enforcer_siren")
	t.sound(f.siren_at + 0.35, &"drone_swoop")
	t.sound(f.charge_at, &"cyborg_charge")
	t.sound(f.charge_at + 0.15, &"barnacle_charge")
	t.sound(t_leap, &"jump")
	t.music(t_leap, &"", f.music_fade)  # DESIGN-TBD (docs/OPEN_QUESTIONS.md §D, item 378): no sting of its own.
	var launch: float = t_blast - f.shots_seconds
	t.sound(launch - 0.12, &"cyborg_shot")
	t.sound(launch, &"barnacle_shot")
	t.cue(launch - 0.3, &"fire")
	t.sound(t_blast, &"truck_explode")
	t.effect(t_blast, CineEvent.FLASH, 0.35, 0.45, BLAST_FLASH)
	t.effect(t_blast, CineEvent.SHAKE, 0.5, 0.2)
	t.cue(t_blast, &"blast")
	t.effect(t_black, CineEvent.FADE_OUT, f.black_seconds)
	t.cue(t_cut, &"next_zone")
	t.effect(t_cut, CineEvent.FADE_IN, f.land_fade_in)
	t.sound(t_land, &"land")
	t.effect(t_land, CineEvent.SHAKE, 0.3, 0.12)
	t.effect(f.duration - f.fade_out, CineEvent.FADE_OUT, f.fade_out)


func _on_cue(cue_name: StringName) -> void:
	match cue_name:
		&"crash":
			props.wreck_ship(crash_z, _wreck_belly())
		&"fire":
			_volley()
		&"blast":
			props.start_blast(stage.point(blast_at), numbers().blast_radius, numbers().blast_seconds)
		&"next_zone":
			_to_next_zone()


## DESIGN-TBD (docs/OPEN_QUESTIONS.md §D, item 375): the roadblock's volley, a bolt from each cyborg's arm cannon and
## each turret's muzzle, landing on the edge the runner leaps from as the blast goes off.
func _volley() -> void:
	var f: CityOutroTuning = numbers()
	var launch: float = t_blast - f.shots_seconds
	var target: Vector3 = stage.point(blast_at)
	var i: int = 0
	for id: StringName in actors:
		var node := actors[id] as CineActorNode
		if node.body == null:
			continue
		var from: Vector3 = node.global_position + Vector3(0.45, 1.15, 0.0)
		props.add_bolt(from, target + Vector3(0.0, 0.0, (i % 3 - 1) * 0.5), launch - 0.06 * i, f.shots_seconds)
		i += 1
	for turret: BarnacleTurretModel in props.turrets:
		var muzzle: Vector3 = turret.global_transform * BarnacleTurretModel.MUZZLE
		props.add_bolt(muzzle, target, launch, f.shots_seconds)


## DESIGN-TBD (docs/OPEN_QUESTIONS.md §D, item 376): cuts to the next zone's street (its skin from the campaign's
## data) under black, rather than following the fall all the way down.
func _to_next_zone() -> void:
	props.hide_city()
	var d := CineStageDef.new()
	switch_stage(d, next_skin())
	landed_stage = true


## The next zone's look: the zone after this one in the campaign (Gangland after the City), or Gangland's
## when it plays on its own.
func next_skin() -> ZoneSkin:
	var app: Node = get_node_or_null(^"/root/App")
	var campaign := app.get(&"campaign") as Campaign if app != null else null
	if campaign != null and step != null and step.zone_index + 1 < campaign.zones.size():
		var next: ZoneDef = campaign.zones[step.zone_index + 1]
		if next.skin != null:
			return next.skin
	return load(NEXT_SKIN_PATH) as ZoneSkin


## Over (played out or skipped): its props go out of view with the rest of it.
func _finish() -> void:
	if props != null and not done:
		props.visible = false
	super()


## The wreck's belly height: sunk between the trucks as in the fight (FloatingHead.wreck_belly).
func _wreck_belly() -> float:
	return -boss_tuning.wreck_floor_share * props.shape.height if boss_tuning != null else -4.0


# --- The props on the clock ----------------------------------------------------------------------

func _on_advance(delta: float) -> void:
	if props == null or landed_stage:
		return
	var f: CityOutroTuning = numbers()
	if not props.wrecked:
		_fly_ship(f)
	else:
		props.update_face(delta)
	var runner := actors.get(&"runner") as CineActorNode
	var target: Vector3 = runner.global_position + Vector3(0.0, 0.9, 0.0) if runner != null else Vector3.ZERO
	var launch: float = t_blast - f.shots_seconds
	var charge: float = 0.0
	if time >= f.charge_at and time < launch:
		charge = clampf((time - f.charge_at) / maxf(launch - f.charge_at, 0.05), 0.0, 1.0)
	props.update_roadblock(time, delta, time >= f.siren_at, f.light_bar_rate, target, charge)
	props.update_bolts(time)
	props.update_blast(delta)


## The dying ship: it hangs ahead of the runner, wallowing, its face tearing into static (held still with
## Reduced flashing), then loses power and plunges forward and down into the street, its nose dipping
## (the fight's fall: FloatingHead._falling_tick).
func _fly_ship(f: CityOutroTuning) -> void:
	var glitch: float = 0.8
	if not Settings.flashing_reduced:
		var burst: float = fposmod(sin(floorf(time * 7.0) * 12.9898) * 43758.5453, 1.0)
		glitch = 1.0 if burst > 0.4 else 0.55
	if time < f.fall_start:
		props.pose_ship(runner_at(time) + f.ship_ahead, f.ship_height + 0.3 * sin(time * 2.0), 0.0, 1.0, glitch)
		props.set_ship_power(1.0)
		return
	var span: float = maxf(f.fall_seconds, 0.05)
	var k: float = clampf((time - f.fall_start) / span, 0.0, 1.0)
	var e: float = k * span
	var s0: float = runner_at(f.fall_start) + f.ship_ahead
	var v0: float = tuning.run_speed
	var a: float = (crash_z - s0 - v0 * span) / (span * span)
	var belly: float = lerpf(f.ship_height, _wreck_belly(), k * k)
	props.pose_ship(s0 + v0 * e + a * e * e, belly, FloatingHead.FALL_DIVE * sin(PI * k),
		1.0 - smoothstep(0.0, 0.6, k), glitch)
	props.set_ship_power(1.0 - smoothstep(0.0, 0.8, k))
