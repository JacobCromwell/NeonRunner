class_name FloatingHeadFaceOff
extends Node3D
## The Floating Head's face-off (GDD §10), once it hovers in front of the runner with its face on:
## - eye lasers "while it looks at the player" (proposed: "the eyes glow and whine, then twin beams
##   sweep across the lanes: jump a low sweep, slide under a high one, or switch lanes when a beam
##   drags down a lane"). Every laser attack starts with its warning: the eyes glow red
##   (FloatingHeadBody's eye_charge) and whine (head_laser_charge) for laser_charge_seconds while thin
##   aiming beams show where it goes: for a sweep, the lines it will cross the runner's spot along (low,
##   or high: two) and the wall it starts from (the one further from the runner); for a drag, a red
##   spot on the lane it will burn, following the runner's lane until the warning ends, then the
##   framework's red lane warning. Then the beams fire (head_laser_fire): a sweep crosses the street wall to wall at
## low_sweep_seconds for a low sweep or laser_sweep_speed for a high one; a drag lands under the face in that lane and burns down it to the runner's spot
##   in drag_seconds, leaving a burning line;
## - the cyborg drop (GDD §10: "its mouth opens and drops 1–2 cyborgs onto the trucks ahead, who then
##   fight like normal cyborgs"): it pulls back and opens its mouth (the warning: FloatingHeadBody's
##   jaw and head_mouth_open, with the framework's red circles where they will land), then drops
##   cyborgs_in_drop() cyborgs through the enemy director (the normal cyborg: EnemyDirector via
##   BossEncounter.spawn_enemy) onto clear roof in lanes that leave one free; they land
##   (cyborg_drop_land) and fight like any cyborg;
## - the towers (GDD §10: the player "baits the eye laser into a marked tower by leading the beam to
##   that side and dodging at the last moment"): for each marked tower it pulls back to tower_ahead
##   and times a drag so its warning ends just as the tower passes its face. If the runner is in the
##   outer lane on the tower's side then (the beam follows their lane until then), the drag lands
##   beside the tower and clips it (a bait, bait_score); once fallback_after towers have gone by in a
##   phase, it clips the next one on its own. A clipped tower topples onto the ship (FloatingHead's
##   pin).
## The attacks wait in line in the phase's order (FloatingHeadTuning.faceoff_pattern): the first that
## can start fairly goes next, then to the back of the line. Timings are at the phase's pace except
## the low sweep's crossing, which fits the player's unchanged jump arc, and
## none depends on how long the fight has lasted (GDD §10: no escalation); its distances along the
## track (where it drops cyborgs and takes aim at a tower, the fairness margins) are at the run's pace
## (FloatingHead.metres; GDD §3), so they take as long to run at any speed. Big attacks never overlap
## (GDD §9): its lasers wait while a cyborg it dropped is still ahead of the runner (drop_hold_max at
## most), and share the cyborgs' "airspace" (CyborgGun.AIRSPACE_META), so no cyborg's burst starts
## during a laser attack and no laser attack during a burst.
## Fairness: a sweep only comes while the floor is clear in every lane where the runner will be while
## it crosses the street (it's dodged in the air or on the ground); a drag only where a lane beside the
## runner's is free to switch into (FloatingHead.escape_lane), and its burning line keeps clear of a
## wall runner beside an outer lane; cyborgs only land on clear roof (their own obstacle margin), never
## on a pickup, always leaving a lane free.
## Random picks come from the fight's seeded rng and time from the physics step, so every attempt
## plays out the same way for the same inputs.

enum Step { IDLE, MOVE, WAIT_TOWER, CHARGE, FIRE, RECOVER, MOUTH, DROPPING, CLOSING, PINNED }

const CyborgRules = preload("res://scripts/enemies/cyborg_rules.gd")

const LASER_NAME: String = "Floating Head's eye laser"
const BURN_NAME: String = "Floating Head's laser burn"
const LASER_RED := Color(1.0, 0.12, 0.08)
const SPARK := Color(1.0, 0.32, 0.14)
const DUST := Color(0.5, 0.5, 0.56)
const RECOVER_SECONDS: float = 0.35
const CLOSE_SECONDS: float = 0.35
## A drop that finds no clear roof for this long gives up.
const STUCK_SECONDS: float = 2.5
## A sweep's floor stays clear from this far before where the runner is when its beams fire (metres at
## 18 m/s, like CEILING_REACH: at the run's pace).
const SWEEP_CLEAR_BEFORE: float = 6.0
## Seconds of slack a tower's sequence keeps before it.
const TOWER_SLACK: float = 0.4
## A sweep's beams run on past where they cross, to the floor, at most this far.
const BEAM_REACH: float = 40.0
## A beam's look: its radius while it aims, and once it fires.
const AIM_RADIUS: float = 0.035
const BEAM_RADIUS: float = 0.14
## A drag's impact runs this far past the runner's spot before the beams stop.
const DRAG_OVERSHOOT: float = 2.0
## A fallback's beams swing from the tower to the lane over this long.
const SWING_SECONDS: float = 0.2
## The red circle that marks where a dropped cyborg will land (radius).
const DROP_MARK_RADIUS: float = 0.9
## A dropped cyborg leaps out this far in front of the face (clear of the open jaw) and lands there.
const DROP_FRONT: float = 3.0
## No attack starts while a ceiling lies within this far ahead of the runner (_fair_to_start; metres at
## 18 m/s, at the run's pace).
const CEILING_REACH: float = 60.0

var head: FloatingHead
var tuning: FloatingHeadTuning
var world: RunWorld
## Attacking (the face-off's part of the pattern); off during a run, the reveal and a pin.
var running: bool = false
var step: Step = Step.IDLE
var step_time: float = 0.0
## The attack under way: {kind: &"low" | &"high" | &"drag" | &"drop" | &"tower", ...}, or empty.
var attack: Dictionary = {}
## This phase's attacks (its list), and the line they wait in: the first one that can start fairly
## goes next, then to the back of the line.
var pattern: PackedStringArray = PackedStringArray()
var queue: Array[StringName] = []
## Marked towers gone by unclipped in this phase (GDD §10's fallback counts them).
var missed: int = 0
## Attacks begun so far (each attack's "n"), and of the phase's list in this face-off.
var attacks: int = 0
var shown: int = 0
## The cyborgs this face-off dropped (instance ids: they may be freed any time).
var _dropped_ids: Array[int] = []
## Seconds of face-off so far (laser burns keep to this clock).
var clock: float = 0.0

var _gap: float = 0.0
var _stuck: float = 0.0
var _hold: float = 0.0
var _move_from := Vector3.ZERO
var _move_to := Vector3.ZERO
var _move_seconds: float = 0.0
var _move_t: float = 0.0
## Tower keys already attempted, skipped or passed.
var _towers_done: Dictionary = {}
var _beams: Array[MeshInstance3D] = []
var _beam_materials: Array[ShaderMaterial] = []
## A sweep's aim lines (one per beam height).
var _lines: Array[MeshInstance3D] = []
var _line_materials: Array[ShaderMaterial] = []
var _strip: MeshInstance3D
var _strip_material: ShaderMaterial
## A drag's aiming spot on the floor.
var _dot: MeshInstance3D
var _dot_material: ShaderMaterial
## A sweep's hitboxes, one along each eye's beam.
var _sweep_hazards: Array[Hazard] = []
var _burn_hazard: Hazard
## The burning line: its lane, and where the impact was when ({t: clock, d: track distance}).
var _burn_lane: int = -1
var _burn_samples: Array[Vector2] = []
var _warning: Node3D
## Cyborgs on their way down from the mouth: {id (the enemy's instance id), t, from, lane, at, mark
## (the instance id of the circle marking where it lands)}.
var _falling: Array[Dictionary] = []
var _aim := Vector3.ZERO
var _charge: float = 0.0
var _spark_t: float = 0.0

static var _cylinder: ArrayMesh
static var _quad: ArrayMesh


func setup(p_head: FloatingHead) -> void:
	head = p_head
	tuning = head.tuning
	world = head.world
	name = "FaceOff"
	top_level = true
	transform = Transform3D.IDENTITY
	var shader := load("res://scripts/bosses/floating_head/floating_head_laser.gdshader") as Shader
	for i: int in 2:
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter(&"shape", 0)
		mat.set_shader_parameter(&"laser_color", LASER_RED)
		var beam: MeshInstance3D = _mesh_node(_cylinder_mesh(), mat, "Beam")
		beam.visible = false
		_beams.append(beam)
		_beam_materials.append(mat)
	for i: int in 2:
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter(&"shape", 2)
		mat.set_shader_parameter(&"laser_color", LASER_RED)
		var line: MeshInstance3D = _mesh_node(_cylinder_mesh(), mat, "AimLine")
		line.visible = false
		_lines.append(line)
		_line_materials.append(mat)
	_strip_material = ShaderMaterial.new()
	_strip_material.shader = shader
	_strip_material.set_shader_parameter(&"shape", 1)
	_strip_material.set_shader_parameter(&"laser_color", LASER_RED)
	_strip = _mesh_node(_quad_mesh(), _strip_material, "Burn")
	_strip.visible = false
	_dot_material = ShaderMaterial.new()
	_dot_material.shader = shader
	_dot_material.set_shader_parameter(&"shape", 3)
	_dot_material.set_shader_parameter(&"laser_color", LASER_RED)
	_dot = _mesh_node(_quad_mesh(), _dot_material, "AimSpot")
	_dot.visible = false
	for i: int in 2:
		_sweep_hazards.append(_make_hazard(LASER_NAME))
	_burn_hazard = _make_hazard(BURN_NAME)


## Starts attacking for phase `index`: its attack list from the top, the tower count afresh.
func start(index: int) -> void:
	stop()
	running = true
	pattern = tuning.faceoff_pattern(index)
	queue.clear()
	for word: String in pattern:
		queue.append(StringName(word))
	missed = 0
	shown = 0
	_set_step(Step.IDLE)
	_gap = tuning.attack_gap / head.pace()
	_stuck = 0.0
	_hold_here()
	head.log_event(&"faceoff", {"attacks": pattern.size()})


## Stops attacking: the lasers and the aiming beams go out, the mouth closes. A burning line and
## cyborgs already dropped carry on.
func stop() -> void:
	running = false
	# Landing spots of cyborgs it hadn't dropped yet go.
	var spots: Array = attack.get("spots", [])
	for i: int in range(int(attack.get("dropped", 0)), spots.size()):
		_remove_prop(int((spots[i] as Dictionary).get("mark", 0)))
	attack = {}
	_set_step(Step.IDLE)
	_lasers_off()
	_release_airspace()
	if head != null and head.body != null and is_instance_valid(head.body):
		head.body.jaw_open = 0.0
		head.body.eye_charge = 0.0
		head.body.look_override = false


## Everything off, burning lines included (the fight is won or starts over).
func clear() -> void:
	stop()
	_burn_samples.clear()
	_update_burn()
	for f: Dictionary in _falling:
		_remove_prop(int(f.get("mark", 0)))
	_falling.clear()


## Back to attacking after a pin (the ship shook free): a longer pause first.
func resume() -> void:
	running = true
	attack = {}
	_set_step(Step.IDLE)
	_gap = tuning.attack_gap * 1.5 / head.pace()
	_stuck = 0.0
	_hold_here()


## The laser hitboxes live now (tests).
func laser_hazards() -> Array[Hazard]:
	var out: Array[Hazard] = []
	for h: Hazard in _sweep_hazards + [_burn_hazard]:
		if h.is_active():
			out.append(h)
	return out


## True while the aiming beams show (a laser attack's warning).
func aiming() -> bool:
	return step == Step.CHARGE and _beams[0].visible


## True while a laser attack is warning or firing.
func lasering() -> bool:
	return not attack.is_empty() and attack["kind"] != &"drop" and (step == Step.CHARGE or step == Step.FIRE)


## Where the ship hovers for an attack (a pose, like FloatingHead.pose).
func station(kind: StringName) -> Vector3:
	match kind:
		&"drop":
			return Vector3(0.0, tuning.drop_height, head.metres(tuning.drop_ahead))
		&"tower":
			return Vector3(0.0, tuning.face_height, head.metres(tuning.tower_ahead))
	return head.face_pose()


## Where a sweep's twin beams (the left eye's, the right eye's) cross the runner's spot: a low sweep's
## both low; a high sweep's one at sweep_high_height and one at sweep_high_top.
func sweep_heights(kind: StringName) -> Array[float]:
	var out: Array[float] = [tuning.sweep_low_height, tuning.sweep_low_height]
	if kind == &"high":
		out = [tuning.sweep_high_height, tuning.sweep_high_top]
	return out


func sweep_speed(kind: StringName) -> float:
	if kind == &"low":
		return 2.0 * _sweep_reach() / tuning.low_sweep_seconds
	return tuning.laser_sweep_speed * head.pace()


## One physics step (FloatingHead's pattern calls it every frame of its fight).
func tick(delta: float) -> void:
	clock += delta
	_update_falling(delta)
	_update_burn()
	if running:
		step_time += delta
		_run(delta)
	_update_look(delta)


# --- The attacks in turn -------------------------------------------------------------------------

func _run(delta: float) -> void:
	var v: float = world.player.speed
	match step:
		Step.IDLE:
			_follow_move(delta)
			_gap -= delta
			if _gap > 0.0:
				return
			if _holding(delta):
				return
			_choose_next()
		Step.MOVE:
			if _follow_move(delta):
				_arrived()
		Step.WAIT_TOWER:
			_follow_move(delta)
			var t: Dictionary = attack["tower"]
			if float(t["at"]) - world.player.distance <= head.metres(tuning.tower_ahead) + v * _charge_time() + 0.001:
				_begin_charge()
		Step.CHARGE:
			_follow_move(delta)
			_charge = clampf(step_time / _charge_time(), 0.0, 1.0)
			_update_charge(delta)
			if step_time >= _charge_time() - 0.0001:
				_commit()
		Step.FIRE:
			_follow_move(delta)
			_update_fire(delta)
		Step.RECOVER:
			_follow_move(delta)
			_charge = move_toward(_charge, 0.0, delta / RECOVER_SECONDS)
			head.body.eye_charge = _charge
			if step_time >= RECOVER_SECONDS:
				_lasers_off()
				_end_attack()
		Step.MOUTH:
			_follow_move(delta)
			head.body.jaw_open = move_toward(head.body.jaw_open, 1.0, delta / 0.3)
			if step_time >= tuning.mouth_seconds / head.pace():
				_set_step(Step.DROPPING)
				attack["next_drop"] = 0.0
		Step.DROPPING:
			_follow_move(delta)
			_update_dropping()
		Step.CLOSING:
			_follow_move(delta)
			head.body.jaw_open = move_toward(head.body.jaw_open, 0.0, delta / CLOSE_SECONDS)
			if step_time >= CLOSE_SECONDS:
				head.body.jaw_open = 0.0
				_hold = tuning.drop_hold_max
				_end_attack()
		Step.PINNED:
			# Pinned under the tower: its eyes' glow dies away (red means a laser is coming).
			_charge = move_toward(_charge, 0.0, delta / RECOVER_SECONDS)
			head.body.eye_charge = _charge


## Picks the next attack: a marked tower's drag when it's due, once the face-off has shown towers_after
## attacks; else the first attack in line that can start fairly now (and be over before a tower's drag
## is due), which then goes to the back of the line. If none can, it waits.
func _choose_next() -> void:
	var v: float = maxf(world.player.speed, 0.1)
	_skip_passed_towers()
	var until: float = INF
	var tower: Dictionary = _next_tower() if shown >= tuning.towers_after else {}
	if not tower.is_empty():
		until = (float(tower["at"]) - world.player.distance
			- (head.metres(tuning.tower_ahead) + v * (_charge_time() + _move_time() + TOWER_SLACK))) / v
		if until <= 0.0:
			# Seconds until it takes aim (at least the move to the tower station, _next_tower).
			var lead: float = maxf(until + _move_time() + TOWER_SLACK, 0.0)
			if _airspace_until() > world.level_time() + lead:
				# A cyborg's burst would still be under way as it takes aim: this tower goes by.
				_towers_done[tower["key"]] = true
				head.log_event(&"tower_skipped", {"at": tower["at"], "side": tower["side"], "why": &"burst"})
				return
			var blocker: StringName = head.pin_zone_blocker(float(tower["at"]))
			if blocker != &"":
				# The pin and its way up would land on a pickup or a cyborg it dropped: this tower goes by.
				_towers_done[tower["key"]] = true
				head.log_event(&"tower_skipped", {"at": tower["at"], "side": tower["side"], "why": blocker})
				return
			_begin_tower(tower, lead)
			return
	for i: int in queue.size():
		var kind: StringName = queue[i]
		if _estimate(kind) <= until and _fair_to_start(kind):
			queue.remove_at(i)
			queue.append(kind)
			_begin(kind)
			return


## One of the phase's attacks begins: to its station, then its warning.
func _begin(kind: StringName) -> void:
	attacks += 1
	shown += 1
	match kind:
		&"low", &"high":
			attack = {"kind": kind, "n": attacks, "heights": sweep_heights(kind)}
		&"drag":
			attack = {"kind": kind, "n": attacks}
		&"drop":
			attack = {"kind": kind, "n": attacks, "count": tuning.cyborgs_in_drop(head.phase_index)}
	_go_to(station(kind))


## A marked tower's drag begins: to the tower station, then a charge timed for the tower (in about
## `lead` seconds). No cyborg starts a burst from now until its drag is over.
func _begin_tower(tower: Dictionary, lead: float) -> void:
	_towers_done[tower["key"]] = true
	attacks += 1
	attack = {"kind": &"tower", "n": attacks, "tower": tower}
	_claim_airspace(lead + _charge_time() + _drag_time() + 0.3)
	head.log_event(&"tower_attempt", {"at": tower["at"], "side": tower["side"]})
	_go_to(station(&"tower"))


## Starts moving to `pose` (a pose relative to the runner); MOVE until it's there.
func _go_to(pose: Vector3) -> void:
	_move_from = head.pose
	_move_to = pose
	_move_t = 0.0
	_move_seconds = _move_time() if head.pose.distance_to(pose) > 0.05 else 0.0
	_set_step(Step.MOVE)


## Stays where the ship is (the face-off's station until an attack moves it).
func _hold_here() -> void:
	_move_from = head.pose
	_move_to = head.pose
	_move_t = 0.0
	_move_seconds = 0.0


## Eases the ship toward its current station. True once it's there.
func _follow_move(delta: float) -> bool:
	if head.step != FloatingHead.Step.FACE_OFF:
		return true
	if _move_seconds <= 0.0:
		head.pose = _move_to
		return true
	_move_t = minf(_move_t + delta, _move_seconds)
	head.pose = _move_from.lerp(_move_to, smoothstep(0.0, 1.0, _move_t / _move_seconds))
	return _move_t >= _move_seconds


func _arrived() -> void:
	var kind: StringName = attack.get("kind", &"")
	match kind:
		&"low", &"high", &"drag":
			if _fair_to_start(kind):
				_begin_charge()
			else:
				# The floor ahead changed while it moved: it waits in place for a fair moment, the attack
				# back at the front of the line.
				queue.remove_at(queue.rfind(kind))
				queue.insert(0, kind)
				shown -= 1
				attack = {}
				_set_step(Step.IDLE)
		&"drop":
			var spots: Array[Dictionary] = _plan_drop()
			if spots.is_empty():
				_stuck += get_physics_process_delta_time()
				if _stuck >= STUCK_SECONDS:
					head.log_event(&"attack_skipped", {"kind": kind})
					_stuck = 0.0
					_end_attack()
				return
			_stuck = 0.0
			# The warning: the mouth opens with its grinding sound, and red circles show where they land
			# (pickups keep off them).
			var lanes: Array[int] = []
			var ats: Array[float] = []
			for s: Dictionary in spots:
				var mark: Node3D = head.props.circle_warning(float(s["at"]), int(s["lane"]), DROP_MARK_RADIUS)
				s["mark"] = mark.get_instance_id()
				lanes.append(int(s["lane"]))
				ats.append(float(s["at"]))
			attack["spots"] = spots
			head.sound(&"head_mouth_open", head.body.mouth_world())
			head.log_event(&"drop_warn", {"lanes": lanes, "ats": ats})
			_set_step(Step.MOUTH)
		&"tower":
			_set_step(Step.WAIT_TOWER)
		_:
			_end_attack()


func _end_attack() -> void:
	attack = {}
	_set_step(Step.IDLE)
	_gap = tuning.attack_gap / head.pace()


## Whether `kind` may start now (from where the ship is): nothing starts while a ceiling (the third
## stomp window's, after a missed window) lies within an attack's reach of the runner, who may be riding
## it or dropping from it; a drop waits until the runner is past the cyborgs of the last one; lasers
## wait for the airspace; a sweep needs the floor clear in every lane where the runner will be while its
## beams cross the street (from SWEEP_CLEAR_BEFORE before where they are when it fires to
## sweep_clear_after past where they are when it's done); a drag a lane to switch into. Its margins
## along the track are at the run's pace (FloatingHead.metres: as long to run at any speed).
func _fair_to_start(kind: StringName) -> bool:
	var before: float = head.metres(SWEEP_CLEAR_BEFORE)
	if head.ceiling_between(world.player.distance - before, world.player.distance + head.metres(CEILING_REACH)):
		return false
	if kind == &"drop":
		return not _cyborgs_ahead()
	if not _airspace_free():
		return false
	var d0: float = world.player.distance
	var v: float = world.player.speed
	var move: float = _move_time() if head.pose.distance_to(station(kind)) > 0.05 else 0.0
	if kind == &"low" or kind == &"high":
		var fire: float = move + _charge_time()
		return head.floor_clear_all(d0 + v * fire - before,
			d0 + v * (fire + _sweep_time(kind)) + head.metres(tuning.sweep_clear_after))
	var pl: int = head.player_lane()
	var lanes: Array[int] = [pl]
	return head.escape_lane(lanes, pl, d0, d0 + v * (move + _charge_time() + _drag_time()
		+ tuning.burn_seconds / head.pace()) + head.metres(tuning.escape_clear_after), true) >= 0


# --- Lasers ----------------------------------------------------------------------------------------

func _begin_charge() -> void:
	var kind: StringName = attack["kind"]
	_set_step(Step.CHARGE)
	_charge = 0.0
	_claim_airspace(_charge_time() + (_sweep_time(kind) if kind == &"low" or kind == &"high" else _drag_time()) + 0.3)
	if kind == &"low" or kind == &"high":
		var dir: int = 1 if world.player.global_position.x <= 0.0 else -1
		# A low sweep starts at the far wall, giving a normal jump time to rise before contact.
		if kind == &"low":
			dir = -dir
		attack["dir"] = dir
		attack["start_x"] = -dir * _sweep_reach()
	else:
		_aim = _drag_aim(head.player_lane())
	head.sound(&"head_laser_charge", head.body.screen_world())
	head.log_event(&"laser_charge", {"kind": attack["kind"]})


## The warning: the eyes glow up, the aiming beams show where the attack goes.
func _update_charge(delta: float) -> void:
	var kind: StringName = attack["kind"]
	head.body.eye_charge = _charge
	head.body.anger = lerpf(0.35, 0.9, _charge)
	if kind == &"low" or kind == &"high":
		var targets: Array[Vector3] = _sweep_targets(float(attack["start_x"]))
		_aim = (targets[0] + targets[1]) * 0.5
		_show_aim_lines(attack["heights"], 0.25 + 0.75 * _charge)
		_show_beams(targets, AIM_RADIUS, 0.35 + 0.5 * _charge, 0.0, false)
	else:
		# The drag's aim follows the runner's lane (a little behind), on the floor under the face, where
		# a red spot shows it.
		var target: Vector3 = _drag_aim(head.player_lane())
		_aim = Vector3(move_toward(_aim.x, target.x, 16.0 * delta), target.y, target.z)
		_show_beams([_aim, _aim], AIM_RADIUS, 0.35 + 0.5 * _charge, 0.0, false)
		var w: float = world.geo.lane_width * 0.55
		_dot.global_transform = Transform3D(Basis.from_scale(Vector3(w, 1.0, w * 1.6)), _aim + Vector3(0.0, 0.03, 0.0))
		_dot.visible = true
		_dot_material.set_shader_parameter(&"strength", 0.5 + 0.9 * _charge)


## The warning is over: the attack fires (or, if it can't fire fairly any more, powers down).
func _commit() -> void:
	var kind: StringName = attack["kind"]
	for line: MeshInstance3D in _lines:
		line.visible = false
	_dot.visible = false
	if kind == &"low" or kind == &"high":
		attack["x"] = float(attack["start_x"])
		_set_step(Step.FIRE)
		head.sound(&"head_laser_fire", head.body.screen_world())
		head.log_event(&"laser_fire", {"kind": kind, "heights": (attack["heights"] as Array).duplicate(),
			"dir": attack["dir"], "d0": world.player.distance})
		return
	var d0: float = world.player.distance
	var lane: int = head.player_lane()
	var start: float = d0 + head.pose.z - 1.0
	var lanes: Array[int] = [lane]
	var fair: bool = head.escape_lane(lanes, lane, d0, d0 + world.player.speed * (_drag_time()
		+ tuning.burn_seconds / head.pace()) + head.metres(tuning.escape_clear_after), true) >= 0
	if not fair:
		# No lane to switch into any more: it powers down without firing.
		head.log_event(&"laser_cancel", {"kind": kind, "lane": lane})
		_set_step(Step.RECOVER)
		return
	if kind == &"tower":
		_commit_tower(lane)
	attack["lane"] = lane
	attack["start"] = start
	attack["start_rel"] = start - d0
	_burn_lane = lane
	_burn_samples.clear()
	_warning = head.props.lane_warning(lane, d0, start)
	_set_step(Step.FIRE)
	head.sound(&"head_laser_fire", head.body.screen_world())
	head.log_event(&"laser_fire", {"kind": kind, "lane": lane, "start": start, "d0": d0})


## A marked tower's drag: a bait when the runner led the beam to the tower's side, or the fallback.
func _commit_tower(lane: int) -> void:
	var tower: Dictionary = attack["tower"]
	var side: int = int(tower["side"])
	var outer: int = 0 if side < 0 else head.lane_count() - 1
	var baited: bool = lane == outer
	var fallback: bool = not baited and missed >= tuning.fallback_after
	var node: FloatingHeadTower = head.tower_node(tower)
	if (baited or fallback) and node != null:
		node.clip()
		attack["clipped"] = true
		attack["fallback"] = fallback
		missed = 0
		head.sound(&"tower_crack", node.strike_point())
		head.log_event(&"tower_clip", {"baited": baited, "lane": lane, "at": tower["at"], "side": side})
		if baited:
			world.score.add_bonus(&"tower_bait", tuning.bait_score, "Tower!")
		head.begin_pin(node)
	else:
		missed += 1
		head.log_event(&"tower_missed", {"at": tower["at"], "side": side, "lane": lane, "missed": missed})


func _update_fire(delta: float) -> void:
	var kind: StringName = attack["kind"]
	if kind == &"low" or kind == &"high":
		_update_sweep(delta)
	else:
		_update_drag()


## A sweep: the twin beams cross the runner's spot at the attack's heights, wall to wall, each with its
## hitbox along it there.
func _update_sweep(delta: float) -> void:
	var dir: int = attack["dir"]
	var x: float = float(attack["x"]) + dir * sweep_speed(attack["kind"]) * delta
	attack["x"] = x
	var targets: Array[Vector3] = _sweep_targets(x)
	_aim = (targets[0] + targets[1]) * 0.5
	_show_beams(targets, BEAM_RADIUS, 1.0, 1.0, true)
	_spark_t -= delta
	var sparks: bool = _spark_t <= 0.0
	if sparks:
		_spark_t = 0.06
	for i: int in 2:
		var eye: Vector3 = head.body.eye_world(-1 if i == 0 else 1)
		var p: Vector3 = targets[i]
		var along: Vector3 = (p - eye).normalized()
		var up: Vector3 = Vector3.UP if absf(along.y) < 0.98 else Vector3.BACK
		var hazard: Hazard = _sweep_hazards[i]
		hazard.global_transform = Transform3D(Basis.looking_at(along, up), p)
		_set_box(hazard, Vector3(tuning.beam_radius * 2.0, tuning.beam_radius * 2.0, 3.0))
		hazard.set_enabled(true)
		if sparks:
			world.effects.burst(_floor_hit(eye, p), SPARK, 5, 0.25)
	if (dir > 0 and x > _sweep_reach() + 0.3) or (dir < 0 and x < -_sweep_reach() - 0.3):
		for hazard: Hazard in _sweep_hazards:
			hazard.set_enabled(false)
		head.log_event(&"laser_end", {"kind": attack["kind"], "d": world.player.distance})
		_set_step(Step.RECOVER)


## Where a sweep's beams cross the runner's spot (the left eye's, the right eye's) with them at `x`.
func _sweep_targets(x: float) -> Array[Vector3]:
	var heights: Array = attack["heights"]
	var z: float = world.player.global_position.z
	var out: Array[Vector3] = [Vector3(x, float(heights[0]), z), Vector3(x, float(heights[1]), z)]
	return out


## A drag: the beams land under the face and burn down the lane to the runner's spot and a little past.
func _update_drag() -> void:
	var t: float = step_time
	var dur: float = _drag_time()
	var start_rel: float = attack["start_rel"]
	var lane: int = attack["lane"]
	var rel: float = start_rel - (start_rel + DRAG_OVERSHOOT) * clampf(t / dur, 0.0, 1.0)
	var d: float = world.player.distance + rel
	_burn_samples.append(Vector2(clock, d))
	var hit := Vector3(world.geo.lane_x(lane), 0.05, TrackGeometry.world_z(d))
	var target: Vector3 = hit
	if attack.get("fallback", false) and t < SWING_SECONDS / head.pace():
		# The fallback: the beams strike the tower first, then swing into the lane.
		var node: FloatingHeadTower = head.tower_node(attack["tower"])
		if node != null:
			target = node.strike_point().lerp(hit, clampf(t / (SWING_SECONDS / head.pace()), 0.0, 1.0))
	_aim = target
	_show_beams([target, target], BEAM_RADIUS, 1.0, 1.0, false)
	_spark_t -= get_physics_process_delta_time()
	if _spark_t <= 0.0:
		_spark_t = 0.05
		world.effects.burst(hit + Vector3(0.0, 0.2, 0.0), SPARK, 6, 0.35)
	if t >= dur:
		head.log_event(&"laser_end", {"kind": attack["kind"], "lane": lane, "d": world.player.distance})
		if attack.get("clipped", false):
			_lasers_off()
			_set_step(Step.PINNED)
		else:
			_set_step(Step.RECOVER)


## The burning line: where the drag's impact passed within the last burn_seconds, with its hitbox.
func _update_burn() -> void:
	var life: float = tuning.burn_seconds / (head.pace() if head != null else 1.0)
	while not _burn_samples.is_empty() and clock - _burn_samples[0].x > life:
		_burn_samples.remove_at(0)
	if _burn_samples.is_empty() or _burn_lane < 0:
		_burn_hazard.set_enabled(false)
		_strip.visible = false
		if _warning != null and is_instance_valid(_warning) and not (step == Step.FIRE and attack.get("lane", -2) == _burn_lane):
			head.props.remove(_warning)
			_warning = null
		return
	var near: float = _burn_samples[0].y
	var far: float = _burn_samples[0].y
	for s: Vector2 in _burn_samples:
		near = minf(near, s.y)
		far = maxf(far, s.y)
	var geo: TrackGeometry = world.geo
	var half: float = geo.lane_width * tuning.burn_width_share * 0.5
	var x: float = geo.lane_x(_burn_lane)
	# A wall runner's body reaches this far in from the wall's face: the burn keeps clear of it.
	var reach: float = geo.wall_x() - world.tuning.hurtbox_size.y - 0.05
	var x0: float = maxf(x - half, -reach)
	var x1: float = minf(x + half, reach)
	var depth: float = maxf(far - near, 0.3)
	var size := Vector3(x1 - x0, tuning.burn_height, depth)
	_burn_hazard.global_transform = Transform3D(Basis.IDENTITY,
		Vector3((x0 + x1) * 0.5, size.y * 0.5, TrackGeometry.world_z((near + far) * 0.5)))
	_set_box(_burn_hazard, size)
	_burn_hazard.set_enabled(true)
	# The strip you see: a little wider and longer than the hitbox.
	_strip.visible = true
	var w: float = geo.lane_width * tuning.burn_width_share * 1.15
	_strip.global_transform = Transform3D(Basis(Vector3(w, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, depth + 0.6)),
		Vector3(x, 0.04, TrackGeometry.world_z((near + far) * 0.5)))
	_strip_material.set_shader_parameter(&"strength", 1.4)


func _lasers_off() -> void:
	for beam: MeshInstance3D in _beams:
		beam.visible = false
	for line: MeshInstance3D in _lines:
		line.visible = false
	if _dot != null:
		_dot.visible = false
	for hazard: Hazard in _sweep_hazards:
		hazard.set_enabled(false)
	if head != null and head.body != null and is_instance_valid(head.body):
		head.body.anger = 0.35


## The eyes' beams, each from its eye (left, right) to its target, `radius` thick at `strength` (their
## pale core `core`); a sweep's run on past it to the floor.
func _show_beams(targets: Array[Vector3], radius: float, strength: float, core: float, extend: bool) -> void:
	for i: int in 2:
		var eye: Vector3 = head.body.eye_world(-1 if i == 0 else 1)
		var target: Vector3 = targets[i]
		var dir: Vector3 = target - eye
		var length: float = dir.length()
		if length < 0.1:
			_beams[i].visible = false
			continue
		if extend:
			length = _floor_hit(eye, target).distance_to(eye)
		var up: Vector3 = Vector3.UP if absf(dir.normalized().y) < 0.98 else Vector3.BACK
		_beams[i].global_transform = Transform3D(Basis.looking_at(dir, up) * Basis.from_scale(Vector3(radius, radius, length)), eye)
		_beams[i].visible = true
		_beam_materials[i].set_shader_parameter(&"strength", strength)
		_beam_materials[i].set_shader_parameter(&"core", core)


## A sweep's warning: thin lines across the street through the runner's spot at its beams' heights
## (one line when both are the same).
func _show_aim_lines(heights: Array, strength: float) -> void:
	var z: float = world.player.global_position.z
	var reach: float = _sweep_reach()
	# The tube runs along its -z: turned to run along +x, wall to wall.
	var along := Basis(Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(-1, 0, 0))
	for i: int in 2:
		var h: float = float(heights[i])
		var shown: bool = i == 0 or not is_equal_approx(h, float(heights[0]))
		_lines[i].visible = shown
		if shown:
			_lines[i].global_transform = Transform3D(along * Basis.from_scale(Vector3(0.05, 0.05, reach * 2.0)),
				Vector3(-reach, h, z))
			_line_materials[i].set_shader_parameter(&"strength", strength)


## Where a beam from `eye` through `p` meets the floor (or runs out).
func _floor_hit(eye: Vector3, p: Vector3) -> Vector3:
	var dir: Vector3 = p - eye
	if dir.y >= -0.001:
		return p + dir.normalized() * BEAM_REACH
	var s: float = -eye.y / dir.y
	var hit: Vector3 = eye + dir * s
	if hit.distance_to(p) > BEAM_REACH:
		hit = p + dir.normalized() * BEAM_REACH
	return hit


## A drag's aim: the floor of `lane` just under the face.
func _drag_aim(lane: int) -> Vector3:
	return Vector3(world.geo.lane_x(lane), 0.05, TrackGeometry.world_z(world.player.distance + head.pose.z - 1.0))


## The face watches the runner, the laser's aim while it attacks, or the marked tower it's lining up.
func _update_look(_delta: float) -> void:
	if head.body == null or not is_instance_valid(head.body):
		return
	var aiming: bool = running and not attack.is_empty() and attack["kind"] != &"drop" \
		and (step == Step.CHARGE or step == Step.FIRE)
	var eyeing: FloatingHeadTower = null
	if running and attack.get("kind", &"") == &"tower" and (step == Step.MOVE or step == Step.WAIT_TOWER):
		eyeing = head.tower_node(attack["tower"])
	head.body.look_override = aiming or eyeing != null
	if aiming:
		head.body.look_point = _aim
	elif eyeing != null:
		head.body.look_point = eyeing.strike_point() + Vector3(0.0, 6.0, 0.0)


# --- The cyborg drop -------------------------------------------------------------------------------

## Where its cyborgs will land ({lane, at} each), from where the mouth is now: the first under the mouth
## once it's open, the others drop_interval apart (the ship keeps pace with the runner); on clear roof
## (the cyborg's own obstacle margin, every lane), not near a pickup or another warning, always leaving
## a lane free. Empty if it isn't fair now.
func _plan_drop() -> Array[Dictionary]:
	var none: Array[Dictionary] = []
	var n: int = head.lane_count()
	var count: int = mini(int(attack.get("count", 1)), n - 1)
	if count <= 0:
		return none
	var v: float = world.player.speed
	var first: float = _drop_at() + v * tuning.mouth_seconds / head.pace()
	var apart: float = v * tuning.drop_interval / head.pace()
	var last: float = first + apart * (count - 1)
	var margin: float = _cyborg_margin()
	if not head.floor_clear_all(first - margin, last + margin):
		return none
	var lanes: Array[int] = []
	for l: int in n:
		if not head.pickup_near(l, (first + last) * 0.5, (last - first) * 0.5 + margin) \
				and not head.props.warned(l, first - margin, last + margin):
			lanes.append(l)
	if lanes.size() < count:
		return none
	# A seeded shuffle, then the first `count`.
	for i: int in range(lanes.size() - 1, 0, -1):
		var j: int = head.rng.randi() % (i + 1)
		var tmp: int = lanes[i]
		lanes[i] = lanes[j]
		lanes[j] = tmp
	var out: Array[Dictionary] = []
	for i: int in count:
		out.append({"lane": lanes[i], "at": first + apart * i})
	return out


## The roof just in front of the mouth now (clear of its open jaw).
func _drop_at() -> float:
	return world.player.distance + head.pose.z - DROP_FRONT


## A cyborg's own obstacle margin at the run's pace (CyborgRules.obstacle_margin_at: how the cyborg it
## drops keeps clear of holes and fences at this speed).
func _cyborg_margin() -> float:
	var t := EnemyDirector.tuning_for("cyborg") as CyborgTuning
	return CyborgRules.obstacle_margin_at(t, head.run_pace()) if t != null else head.metres(10.0)


func _update_dropping() -> void:
	var spots: Array = attack["spots"]
	var next: int = int(attack.get("dropped", 0))
	attack["next_drop"] = float(attack.get("next_drop", 0.0)) - get_physics_process_delta_time()
	if next < spots.size() and float(attack["next_drop"]) <= 0.0:
		_drop_one(spots[next])
		attack["dropped"] = next + 1
		attack["next_drop"] = tuning.drop_interval / head.pace()
	if int(attack.get("dropped", 0)) >= spots.size() and _falling.is_empty():
		_set_step(Step.CLOSING)


## One cyborg out of the mouth: a normal cyborg from the director, holding its fire until it lands on
## its spot.
func _drop_one(spot: Dictionary) -> void:
	var lane: int = int(spot["lane"])
	var at: float = float(spot["at"])
	var enemy: Enemy = head.spawn_enemy("cyborg", at, lane, 0, {"fires": false})
	if enemy == null:
		_remove_prop(int(spot.get("mark", 0)))
		return
	_dropped_ids.append(enemy.get_instance_id())
	var from: Vector3 = head.body.mouth_world()
	enemy.global_position = from
	_falling.append({"id": enemy.get_instance_id(), "t": 0.0, "from": from, "lane": lane, "at": at,
		"mark": int(spot.get("mark", 0))})
	head.log_event(&"cyborg_drop", {"lane": lane, "at": at})


## Takes away a prop (a landing spot's circle) by its instance id, if it's still there.
func _remove_prop(id: int) -> void:
	var node: Object = instance_from_id(id) if id != 0 else null
	if node != null and node is Node:
		head.props.remove(node as Node)


## Cyborgs falling from the mouth to the roof; on landing they fight like any cyborg.
func _update_falling(delta: float) -> void:
	var fall: float = tuning.drop_fall_seconds / (head.pace() if head != null else 1.0)
	for i: int in range(_falling.size() - 1, -1, -1):
		var f: Dictionary = _falling[i]
		var enemy := instance_from_id(int(f["id"])) as Enemy
		if enemy == null or not enemy.alive:
			_remove_prop(int(f.get("mark", 0)))
			_falling.remove_at(i)
			continue
		f["t"] = float(f["t"]) + delta
		var s: float = clampf(float(f["t"]) / fall, 0.0, 1.0)
		var from: Vector3 = f["from"]
		var to: Vector3 = world.lane_point(int(f["lane"]), float(f["at"]))
		var pos := Vector3(lerpf(from.x, to.x, smoothstep(0.0, 1.0, s)), lerpf(from.y, to.y, s * s), to.z)
		enemy.global_position = pos
		if s >= 1.0:
			_remove_prop(int(f.get("mark", 0)))
			_falling.remove_at(i)
			enemy.global_position = to
			var cyborg := enemy as Cyborg
			if cyborg != null and cyborg.gun != null:
				cyborg.gun.enabled = true
			world.play_sfx_at(&"cyborg_drop_land", to)
			head.log_event(&"sound", {"name": &"cyborg_drop_land"})
			world.effects.burst(to + Vector3(0.0, 0.2, 0.0), DUST, 14, 0.6)
			world.effects.shake(0.12, 0.15)
			head.log_event(&"cyborg_land", {"lane": f["lane"], "at": f["at"]})


## After a drop, its lasers wait while one of its cyborgs is still ahead of the runner (at most
## drop_hold_max).
func _holding(delta: float) -> bool:
	if _hold <= 0.0:
		return false
	_hold -= delta
	if not _cyborgs_ahead() and _falling.is_empty():
		_hold = 0.0
		return false
	return _hold > 0.0


## True while a cyborg this face-off dropped is still ahead of the runner (or on its way down).
func _cyborgs_ahead() -> bool:
	if not _falling.is_empty():
		return true
	for e: Enemy in dropped():
		if e.track_distance() > world.player.distance + 0.5:
			return true
	return false


## The cyborgs this face-off dropped that are still alive.
func dropped() -> Array[Enemy]:
	var out: Array[Enemy] = []
	for i: int in range(_dropped_ids.size() - 1, -1, -1):
		var e := instance_from_id(_dropped_ids[i]) as Enemy
		if e == null or not e.alive:
			_dropped_ids.remove_at(i)
			continue
		out.append(e)
	return out


## The cyborgs still on their way down from the mouth (holding their fire until they land).
func falling() -> Array[Enemy]:
	var out: Array[Enemy] = []
	for f: Dictionary in _falling:
		var e := instance_from_id(int(f["id"])) as Enemy
		if e != null:
			out.append(e)
	return out


# --- Towers ----------------------------------------------------------------------------------------

## The next marked tower it can still time a drag for (with time to get to the tower station first),
## or empty.
func _next_tower() -> Dictionary:
	var v: float = world.player.speed
	var from: float = world.player.distance + head.metres(tuning.tower_ahead) + v * (_charge_time() + _move_time())
	for t: Dictionary in head.towers_between(from, from + 800.0):
		if not _towers_done.has(t["key"]):
			return t
	return {}


## Towers it can no longer time a drag for go by as scenery (not counted as missed).
func _skip_passed_towers() -> void:
	var v: float = world.player.speed
	var until: float = world.player.distance + head.metres(tuning.tower_ahead) + v * (_charge_time() + _move_time())
	for t: Dictionary in head.towers_between(world.player.distance - 50.0, until):
		if not _towers_done.has(t["key"]):
			_towers_done[t["key"]] = true
			head.log_event(&"tower_skipped", {"at": t["at"], "side": t["side"]})


# --- Timings ---------------------------------------------------------------------------------------

func _charge_time() -> float:
	return tuning.laser_charge_seconds / head.pace()


func _move_time() -> float:
	return tuning.move_seconds / head.pace()


func _drag_time() -> float:
	return tuning.drag_seconds / head.pace()


func _sweep_time(kind: StringName) -> float:
	return 2.0 * _sweep_reach() / maxf(sweep_speed(kind), 0.1)


## How far a sweep runs to either side: wall to wall.
func _sweep_reach() -> float:
	return world.geo.wall_x()


## A rough length for an attack, from its start to the next one's pause (for fitting it before a tower).
func _estimate(kind: StringName) -> float:
	match kind:
		&"low", &"high":
			return _move_time() + _charge_time() + _sweep_time(kind) + RECOVER_SECONDS
		&"drag":
			return _move_time() + _charge_time() + _drag_time() + RECOVER_SECONDS
		&"drop":
			# Its lasers then wait until the runner is past the cyborgs it dropped.
			return _move_time() * 2.0 + (tuning.mouth_seconds + tuning.drop_interval * 2.0
				+ tuning.drop_fall_seconds) / head.pace() + CLOSE_SECONDS \
				+ minf(tuning.drop_hold_max, head.metres(tuning.drop_ahead) / maxf(world.player.speed, 1.0))
	return 1.0


# --- Airspace (big attacks take turns with the cyborgs' bursts) -------------------------------------

func _airspace_free() -> bool:
	return world.level_time() >= _airspace_until()


## Until when (level time) the airspace is claimed.
func _airspace_until() -> float:
	return float(world.get_meta(CyborgGun.AIRSPACE_META, -1.0e9))


func _claim_airspace(seconds: float) -> void:
	world.set_meta(CyborgGun.AIRSPACE_META, maxf(float(world.get_meta(CyborgGun.AIRSPACE_META, -1.0e9)),
		world.level_time() + seconds))


func _release_airspace() -> void:
	if world != null and world.has_meta(CyborgGun.AIRSPACE_META) \
			and float(world.get_meta(CyborgGun.AIRSPACE_META)) > world.level_time():
		world.set_meta(CyborgGun.AIRSPACE_META, world.level_time())


# --- Nodes -----------------------------------------------------------------------------------------

func _set_step(next: Step) -> void:
	step = next
	step_time = 0.0


func _make_hazard(hazard_name: String) -> Hazard:
	var hazard := Hazard.new()
	hazard.name = "LaserHitbox"
	hazard.hazard_name = hazard_name
	hazard.is_enemy_attack = true
	hazard.part = &"attack"
	hazard.collision_layer = TrackBuilder.LAYER_HAZARD
	hazard.collision_mask = 0
	hazard.monitoring = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3.ONE
	shape.shape = box
	hazard.add_child(shape)
	add_child(hazard)
	hazard.set_enabled(false)
	return hazard


func _set_box(hazard: Hazard, size: Vector3) -> void:
	hazard.size = size
	((hazard.get_child(0) as CollisionShape3D).shape as BoxShape3D).size = size


func _mesh_node(mesh: Mesh, material: Material, node_name: String) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node


## A beam: an open cylinder along -z from z = 0 to -1, radius 1, UV.y along it.
static func _cylinder_mesh() -> ArrayMesh:
	if _cylinder != null:
		return _cylinder
	var sides: int = 10
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	for i: int in sides:
		var a0: float = TAU * i / sides
		var a1: float = TAU * (i + 1) / sides
		var n0 := Vector3(cos(a0), sin(a0), 0.0)
		var n1 := Vector3(cos(a1), sin(a1), 0.0)
		var p10: Vector3 = n0 + Vector3(0, 0, -1)
		var p11: Vector3 = n1 + Vector3(0, 0, -1)
		verts.append_array(PackedVector3Array([n0, p10, p11, n0, p11, n1]))
		normals.append_array(PackedVector3Array([n0, n0, n1, n0, n1, n1]))
		var u0: float = float(i) / sides
		var u1: float = float(i + 1) / sides
		uvs.append_array(PackedVector2Array([Vector2(u0, 0), Vector2(u0, 1), Vector2(u1, 1), Vector2(u0, 0),
			Vector2(u1, 1), Vector2(u1, 0)]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	_cylinder = ArrayMesh.new()
	_cylinder.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return _cylinder


## A flat strip: x from -0.5 to 0.5 (UV.x), z from 0.5 (UV.y 0) to -0.5 (UV.y 1), facing up.
static func _quad_mesh() -> ArrayMesh:
	if _quad != null:
		return _quad
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-0.5, 0, 0.5), Vector3(-0.5, 0, -0.5), Vector3(0.5, 0, -0.5),
		Vector3(-0.5, 0, 0.5), Vector3(0.5, 0, -0.5), Vector3(0.5, 0, 0.5)])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 0), Vector2(0, 1), Vector2(1, 1), Vector2(0, 0),
		Vector2(1, 1), Vector2(1, 0)])
	_quad = ArrayMesh.new()
	_quad.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return _quad
