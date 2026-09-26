class_name Octodog
extends Enemy
## The Octodog (GDD §9.4): a mass of green tentacles on robotic dog legs, floor only.
##
## 1. It appears head-on from ahead, standing in its lane (the first few come out of a doghouse).
## 2. About halfway up the screen it winds up: it crouches, the tentacles flare, it growls
##    (octodog_windup) and a red line on the floor shows where it will go. The aim is the player's
##    lane when the wind-up starts, so switching lanes any time after that dodges it.
## 3. It lunges in a straight line toward that lane, cutting diagonally across lanes when it lines
##    up beside the player (octodog_lunge). It can't change course mid-leap. The leap is low: a jump
##    clears it. If the line carries it over a hole in the lane it's in, it falls in and dies
##    (a skill bonus, "gap_bait").
## 4. It turns, sprints past the player in another lane (harmless until it's ahead again), runs
##    ahead to about halfway up the screen and repeats. After its last charge it gives up and is
##    left behind.
##
## Every contact is its tentacles (an enemy attack): the lunge, or the grab when the player lands on
## it without claws. Armor or the shield blocks one; claws and the dash kill it; weapons need 5 laser
## tier 1 shots (health in data/enemies/octodog.tres).
##
## Charges are planned by the generator (octodog_rules.gd: params "charges" and "charge_at", the
## player distances where each wind-up may start) so no charge lands on an unavoidable obstacle.
## Before each wind-up the dog checks the stretch again and waits (runs ahead of the player) while
## it isn't clear. Spawned without a plan (tests, quick experiments), it plans for itself.

enum Phase { IDLE, WINDUP, LUNGE, TURN, SPRINT, PACE, GIVE_UP, LEAVE, FALLING }

const BODY_SIZE := Vector3(0.78, 0.72, 0.9)
const TOP_SIZE := Vector3(0.84, 0.24, 0.96)
const PHASE_NAMES: PackedStringArray = ["idle", "windup", "lunge", "turn", "sprint", "pace", "give_up", "leave", "falling"]
## ceiling_between(): metres kept clear before a ceiling section (and around a pad), and after one
## for a player dropping off it to land.
const CEILING_LEAD: float = 6.0
const CEILING_LANDING: float = 25.0

var phase: Phase = Phase.IDLE
## Charges planned for this dog, and lunges made so far.
var charges: int = 2
var charges_done: int = 0
## The lane the current (or last) lunge aims at, locked when its wind-up starts.
var target_lane: int = -1
## The current lunge's velocity: x (m/s) and track distance (m/s, negative = toward the player).
var lunge_velocity := Vector2.ZERO
## Phase changes as [phase name, player distance], for tests and debugging.
var history: Array = []
## True while hidden in its doghouse (it bursts out as the player approaches).
var in_doghouse: bool = false

var _t: OctodogTuning
var _scaling: float = 0.0
## Track distance and world x of the dog's centre on the floor.
var _d: float = 0.0
var _x: float = 0.0
var _phase_time: float = 0.0
var _anchors: Array[float] = []
var _offsets: Array[int] = []
var _lunge_time: float = 0.0
var _hop_time: float = -1.0
var _hop_length: float = 0.0
var _fall_y: float = 0.0
var _fall_v: float = 0.0
var _yaw: float = PI
var _hitboxes_on: bool = true
var _pace_since: float = 0.0
var _doghouse_key: String = ""
var _telegraph_base := Transform3D.IDENTITY

var _body: Hazard
var _top: Hazard
var _model: OctodogModel
var _telegraph: MeshInstance3D
var _doghouse: Node3D


func _build() -> void:
	display_name = "Octodog"
	stompable = false  # GDD §9.4: landing on it without claws, the tentacles grab the player.
	_t = tuning_res as OctodogTuning if tuning_res is OctodogTuning else OctodogTuning.new()
	_scaling = world.config.enemy_scaling if world.config != null else 0.0
	var p: Dictionary = spawn.get("params", {})
	var lanes: int = world.geo.lane_count
	var lane: int = clampi(int(spawn.get("lane", lanes / 2)), 0, lanes - 1)
	_x = world.geo.lane_x(lane)
	_d = float(spawn.get("at", 0.0))
	var r: Vector2i = _t.charges_range(_scaling)
	charges = maxi(1, int(p.get("charges", rng.randi_range(r.x, r.y))))
	for a: Variant in p.get("charge_at", []):
		_anchors.append(float(a))
	for i: int in 8:
		var off: int = 0
		if rng.randf() < _t.diagonal_chance and _t.max_lanes_across > 0:
			off = -1 if rng.randf() < 0.5 else 1
		_offsets.append(off)
	# Every contact is the tentacles: an enemy attack (armor blocks one). Slightly smaller than the
	# model (GDD §3: forgiving hitboxes).
	_body = add_hitbox(&"body", BODY_SIZE, Vector3(0.0, BODY_SIZE.y * 0.5 + 0.04, 0.0), true)
	_top = add_hitbox(&"top", TOP_SIZE, Vector3(0.0, BODY_SIZE.y + 0.04 + TOP_SIZE.y * 0.5 - 0.04, 0.0), true)
	_build_visuals(p)
	_place()


func _build_visuals(p: Dictionary) -> void:
	var variant: StringName = world.skin.enemy_variant if world.skin != null else &"city"
	_model = OctodogModel.new()
	_model.name = "Model"
	add_child(_model)
	_model.build(variant, rng.randf())
	_model.rotation.y = _yaw
	_telegraph = MeshInstance3D.new()
	_telegraph.name = "LungeLine"
	_telegraph.mesh = OctodogModel.telegraph_mesh()
	_telegraph.material_override = GreyboxMaterials.glow(Color(1.0, 0.12, 0.08), 3.0, 0.5)
	_telegraph.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_telegraph.top_level = true
	_telegraph.visible = false
	add_child(_telegraph)
	var wants: Variant = p.get("doghouse", null)
	in_doghouse = bool(wants) if wants != null else _profile_wants_doghouse()
	if in_doghouse:
		_doghouse = OctodogModel.build_doghouse(variant)
		add_child(_doghouse)
		_doghouse.rotation.y = 0.0
		_model.visible = false


## GDD §9.4: only the first appearances get the doghouse hint. DESIGN-TBD: the player's first
## `doghouse_appearances` Octodogs ever, counted in the profile's `seen` list. No App (tests): none.
func _profile_wants_doghouse() -> bool:
	if not is_inside_tree():
		return false
	var app: Node = get_tree().root.get_node_or_null(^"App")
	var profile: Profile = app.get(&"profile") as Profile if app != null else null
	if profile == null:
		return false
	for i: int in _t.doghouse_appearances:
		var key: String = "hint/octodog_doghouse_%d" % (i + 1)
		if not profile.has_seen(key):
			_doghouse_key = key
			return true
	return false


# --- Behaviour ------------------------------------------------------------------------------

func _tick(delta: float) -> void:
	var player: Player = world.player
	var pd: float = player.distance
	var v: float = maxf(player.speed, 1.0)
	var rel: float = _d - pd
	_phase_time += delta
	match phase:
		Phase.IDLE:
			_idle(rel, v)
		Phase.WINDUP:
			if _phase_time >= _t.windup_time(_scaling):
				_start_lunge()
		Phase.LUNGE:
			_lunge(delta, pd)
		Phase.TURN:
			_turn(delta)
		Phase.SPRINT:
			_sprint(delta, rel, v)
		Phase.PACE:
			_pace(delta, rel, v)
		Phase.GIVE_UP:
			var k: float = maxf(0.0, 1.0 - _phase_time / 0.6)
			_d += lunge_velocity.y * k * delta
		Phase.LEAVE:
			_d += (v + _t.sprint_speed_over_player) * delta
	_update_hop(delta)
	_place()


func _set_phase(next: Phase) -> void:
	phase = next
	_phase_time = 0.0
	history.append([PHASE_NAMES[next], world.player.distance])


func _idle(rel: float, v: float) -> void:
	if in_doghouse and rel <= maxf(_t.appear_distance, _t.stop_distance(v, _scaling) + 10.0):
		_burst_out_of_doghouse()
	if rel > _t.stop_distance(v, _scaling):
		return
	if _can_wind_up(v):
		_start_windup()
	else:
		# Not a clear moment: run ahead and wait for one rather than stand in the way.
		_set_phase(Phase.SPRINT)


## Whether a wind-up may start now: a charge left, the player on the floor or a wall, and the stretch
## they'll run through until the lunge has passed them free of other obstacles.
func _can_wind_up(v: float) -> bool:
	var player: Player = world.player
	if charges_done >= charges or not player.alive or player.surface == Player.Surface.CEILING:
		return false
	if world.layout.gapped_between(_lane_at(_x), _d - 0.6, _d + 0.6):
		return false  # never winds up standing over a hole
	if charges_done == 0 and world.director.major_attack_blocked(self):
		return false  # GDD §9.7: no new charge sequence while the Cyborg's Bad Dream chases
	var from: float = player.distance
	return window_clear(world.layout, from, from + _t.window_length(v, _scaling))


## GDD §9.7: its charge sequence, from its first wind-up until it gives up, is a major attack: the
## Cyborg's Bad Dream never slashes during one (EnemyDirector.major_attack_blocked).
func is_major_attack_active() -> bool:
	if not alive or phase in [Phase.IDLE, Phase.GIVE_UP, Phase.LEAVE, Phase.FALLING]:
		return false
	return charges_done > 0 or phase == Phase.WINDUP or phase == Phase.LUNGE


func _start_windup() -> void:
	target_lane = clampi(world.player.lane, 0, world.geo.lane_count - 1)
	_set_phase(Phase.WINDUP)
	_set_hitboxes(true)
	world.play_sfx_at(&"octodog_windup", global_position + Vector3(0.0, 0.8, 0.0))
	_show_telegraph()


func _start_lunge() -> void:
	var player: Player = world.player
	var distance: float = maxf(_d - player.distance, 0.5)
	var speed: float = _t.lunge_speed(_scaling)
	var t_meet: float = maxf(distance / maxf(player.speed + speed, 1.0), 0.15)
	lunge_velocity = Vector2((world.geo.lane_x(target_lane) - _x) / t_meet, -speed)
	_lunge_time = 0.0
	_set_phase(Phase.LUNGE)
	_telegraph.visible = false
	world.play_sfx_at(&"octodog_lunge", global_position + Vector3(0.0, 0.8, 0.0))


func _lunge(delta: float, pd: float) -> void:
	_lunge_time += delta
	_x = clampf(_x + lunge_velocity.x * delta, world.geo.lane_x(0), world.geo.lane_x(world.geo.lane_count - 1))
	_d += lunge_velocity.y * delta
	# GDD §9.4: baited into a gap, it falls in. Only the lunge can carry it over a hole.
	if world.layout.gapped_between(_lane_at(_x), _d, _d):
		_fall_into_gap()
		return
	if _d <= pd - _t.lunge_overshoot or _lunge_time > 4.0:
		charges_done += 1
		if charges_done < charges and _next_charge_possible():
			_set_phase(Phase.TURN)
		else:
			_set_phase(Phase.GIVE_UP)
			_set_hitboxes(false)


## Whether another charge can come: the next planned point (or, unplanned, the stretch ahead) has
## no ceiling section and fits before the level ends.
func _next_charge_possible() -> bool:
	var pd: float = world.player.distance
	var v: float = maxf(world.player.speed, 1.0)
	var until: float = pd + _t.cycle_distance(v, _scaling) + _t.stop_distance(v, _scaling) + 10.0
	if charges_done < _anchors.size():
		until = _anchors[charges_done] + _t.window_length(v, _scaling) + _t.stop_distance(v, _scaling)
	if until > world.layout.length - 10.0:
		return false
	return not ceiling_between(world.layout, pd, until)


func _turn(delta: float) -> void:
	# Skid out of the lunge, turn around and step out of the player's lane.
	var k: float = maxf(0.0, 1.0 - _phase_time / maxf(_t.turnaround_time, 0.01))
	_d += lunge_velocity.y * k * delta
	_step_toward(_passing_lane(), delta)
	_set_hitboxes(false)
	if _phase_time >= _t.turnaround_time:
		_set_phase(Phase.SPRINT)


func _sprint(delta: float, rel: float, v: float) -> void:
	_d += (v + _t.sprint_speed_over_player) * delta
	var ahead: bool = rel >= _t.pass_clearance
	# Passing in another lane and harmless until it's ahead again: never an attack from behind.
	_set_hitboxes(ahead)
	_step_toward(_windup_lane() if ahead else _passing_lane(), delta)
	if rel >= _t.stop_distance(v, _scaling) - 0.5:
		_pace_since = world.player.distance
		_set_phase(Phase.PACE)


func _pace(delta: float, rel: float, v: float) -> void:
	# Hold position about halfway up the screen, lined up to charge, until the planned moment.
	var want: float = _t.stop_distance(v, _scaling)
	_d += (v + clampf((want - rel) * 4.0, -8.0, 8.0)) * delta
	var lane: int = _windup_lane()
	_step_toward(lane, delta)
	var pd: float = world.player.distance
	var anchor: float = _anchors[charges_done] if charges_done < _anchors.size() else _pace_since
	var in_place: bool = absf(rel - want) < 1.5 and absf(_x - world.geo.lane_x(lane)) < 0.25
	if pd >= anchor and in_place and _can_wind_up(v):
		_start_windup()
	elif pd > anchor + _t.charge_slack or not world.player.alive:
		# No clear moment came: it gives up and runs off.
		_set_phase(Phase.LEAVE)
		_set_hitboxes(false)


## The lane to charge from: the player's, or one beside it for a diagonal lunge (seeded), never
## one with a hole under the dog.
func _windup_lane() -> int:
	var lanes: int = world.geo.lane_count
	var base: int = clampi(world.player.lane, 0, lanes - 1)
	var off: int = clampi(_offsets[charges_done % _offsets.size()], -_t.max_lanes_across, _t.max_lanes_across)
	var candidates: Array[int] = [base + off, base - off, base]
	for lane: int in candidates:
		if lane >= 0 and lane < lanes and not world.layout.gapped_between(lane, _d - 1.0, _d + 1.0):
			return lane
	return base


## A lane other than the player's, nearest the dog, to run past them in.
func _passing_lane() -> int:
	var lanes: int = world.geo.lane_count
	var mine: int = _lane_at(_x)
	var theirs: int = clampi(world.player.lane, 0, lanes - 1)
	if mine != theirs or lanes < 2:
		return mine
	if theirs == 0:
		return 1
	if theirs == lanes - 1:
		return lanes - 2
	return theirs - 1 if _x < world.geo.lane_x(theirs) else theirs + 1


func _step_toward(lane: int, delta: float) -> void:
	_x = move_toward(_x, world.geo.lane_x(lane), _t.lateral_speed * delta)


func _set_hitboxes(on: bool) -> void:
	if on == _hitboxes_on or not alive:
		return
	_hitboxes_on = on
	_body.set_enabled(on)
	_top.set_enabled(on)


func _fall_into_gap() -> void:
	_set_phase(Phase.FALLING)
	_telegraph.visible = false
	world.score.add_bonus(&"gap_bait", _t.gap_bait_bonus, "Gap bait!")
	world.play_sfx(&"bonus")
	defeat(&"gap")


func _burst_out_of_doghouse() -> void:
	in_doghouse = false
	_model.visible = true
	if _doghouse != null:
		world.effects.burst(_doghouse.global_position + Vector3(0.0, 0.8, 0.0), Color(1.0, 0.6, 0.25), 24, 0.8)
		_doghouse.queue_free()
		_doghouse = null
	if _doghouse_key != "":
		var app: Node = get_tree().root.get_node_or_null(^"App")
		var profile: Profile = app.get(&"profile") as Profile if app != null else null
		if profile != null:
			profile.mark_seen(_doghouse_key)


## Over a gap or near a fence while running, it hops (visual only).
func _update_hop(delta: float) -> void:
	if phase in [Phase.SPRINT, Phase.PACE, Phase.LEAVE] and _hop_time < 0.0:
		var lane: int = _lane_at(_x)
		var obstacle: bool = world.layout.gapped_between(lane, _d - 1.0, _d + 1.5)
		if not obstacle:
			for f: Dictionary in world.layout.fences:
				if int(f["lane"]) == lane and absf(float(f["at"]) - _d - 1.0) < 1.2:
					obstacle = true
					break
		if obstacle:
			_hop_time = 0.0
			_hop_length = 0.45
	if _hop_time >= 0.0:
		_hop_time += delta
		if _hop_time >= _hop_length:
			_hop_time = -1.0


func _place() -> void:
	position = Vector3(_x, 0.0, TrackGeometry.world_z(_d))


func _lane_at(x: float) -> int:
	var geo: TrackGeometry = world.geo
	for lane: int in geo.lane_count:
		var span: Vector2 = geo.lane_floor_span(lane)
		if x >= span.x and x <= span.y:
			return lane
	return 0 if x < 0.0 else geo.lane_count - 1


# --- Presentation -----------------------------------------------------------------------------

func _process(delta: float) -> void:
	if _model == null or world == null:
		return
	var windup: bool = phase == Phase.WINDUP
	var lunging: bool = phase == Phase.LUNGE
	var ground_speed: float = 0.0
	var target_yaw: float = PI
	match phase:
		Phase.WINDUP:
			# Face along the lunge line: x toward the target lane, z toward the player (+z).
			var v: float = maxf(world.player.speed, 1.0)
			var aim := Vector2(world.geo.lane_x(target_lane) - _x,
				_t.lunge_speed(_scaling) * _t.time_to_meet(v, _scaling) + 0.5)
			target_yaw = atan2(-aim.x, -aim.y)
		Phase.LUNGE, Phase.FALLING:
			target_yaw = atan2(-lunge_velocity.x, lunge_velocity.y)
			ground_speed = 8.0
		Phase.TURN:
			target_yaw = 0.0
			ground_speed = 4.0
		Phase.SPRINT, Phase.PACE, Phase.LEAVE:
			target_yaw = 0.0
			ground_speed = maxf(world.player.speed, 1.0)
		Phase.GIVE_UP:
			target_yaw = PI * 0.75
	_yaw = lerp_angle(_yaw, target_yaw, 1.0 - exp(-14.0 * delta))
	_model.rotation.y = _yaw
	_model.ground_speed = ground_speed
	_model.crouch = move_toward(_model.crouch, 1.0 if windup else 0.0, delta * 5.0)
	_model.flare = move_toward(_model.flare, 1.0 if windup else 0.0, delta * 4.0)
	_model.reach = move_toward(_model.reach, 1.0 if lunging else 0.0, delta * 8.0)
	_model.leap = move_toward(_model.leap, 1.0 if lunging else 0.0, delta * 8.0)
	_model.sitting = move_toward(_model.sitting, 1.0 if phase == Phase.GIVE_UP else 0.0, delta * 2.0)
	var y: float = 0.0
	if lunging:
		var total: float = _t.lunge_duration(maxf(world.player.speed, 1.0), _scaling)
		y = _t.lunge_hop_height * sin(PI * clampf(_lunge_time / maxf(total, 0.05), 0.0, 1.0))
	elif _hop_time >= 0.0:
		y = 0.45 * sin(PI * clampf(_hop_time / _hop_length, 0.0, 1.0))
	if phase == Phase.FALLING:
		_fall_v -= 22.0 * delta
		_fall_y += _fall_v * delta
		_x += lunge_velocity.x * 0.5 * delta
		_d += lunge_velocity.y * 0.5 * delta
		_place()
		_model.rotation.x = lerpf(_model.rotation.x, 1.1, 1.0 - exp(-4.0 * delta))
		y = _fall_y
		if _fall_y < -6.0:
			queue_free()
	_model.position.y = y
	_model.animate(delta)
	if windup and _telegraph.visible:
		# The line pulses and widens as the lunge nears.
		var k: float = clampf(_phase_time / maxf(_t.windup_time(_scaling), 0.05), 0.0, 1.0)
		var pulse: float = (0.6 + 0.5 * k) * (0.9 + 0.15 * sin(_phase_time * 30.0))
		_telegraph.global_transform = _telegraph_base * Transform3D(Basis.from_scale(Vector3(pulse, 1.0, 1.0)), Vector3.ZERO)


## The lunge line on the floor: from the dog to where the lunge will carry it, in the ground's
## frame (the path it will actually take, so a hole on it is a hole it will fall into).
func _show_telegraph() -> void:
	var v: float = maxf(world.player.speed, 1.0)
	var speed: float = _t.lunge_speed(_scaling)
	var t_meet: float = _t.time_to_meet(v, _scaling)
	var duration: float = _t.lunge_duration(v, _scaling)
	var start := Vector3(_x, 0.03, TrackGeometry.world_z(_d))
	var end_x: float = _x + (world.geo.lane_x(target_lane) - _x) * duration / maxf(t_meet, 0.05)
	var end := Vector3(end_x, 0.03, TrackGeometry.world_z(_d - speed * duration))
	var dir: Vector3 = end - start
	if dir.length() < 0.5:
		dir = Vector3(0.0, 0.0, 1.0)
	var length: float = maxf(dir.length(), 2.5)
	_telegraph_base = Transform3D(Basis.looking_at(dir, Vector3.UP), start) \
		* Transform3D(Basis.from_scale(Vector3(1.0, 1.0, length)), Vector3.ZERO)
	_telegraph.global_transform = _telegraph_base
	_telegraph.visible = true


func _on_defeated(cause: StringName) -> void:
	_telegraph.visible = false
	if cause == &"gap":
		_fall_v = 1.5
		return  # falls into the hole (_process), then frees itself
	world.play_sfx_at(&"enemy_death", global_position)
	world.effects.burst(aim_point(), OctodogModel.TENTACLE_GREEN_TIP, 28, 0.8)
	world.effects.burst(aim_point(), Color(0.7, 0.75, 0.8), 12, 0.6)
	queue_free()


func should_retire() -> bool:
	if phase == Phase.LEAVE and _d - world.player_distance() > 110.0:
		return true
	return super.should_retire()


## Auto-fire only picks it once it's in view (and out of its doghouse), doghouse or not, so the
## hint never changes what the weapon does.
func targetable() -> bool:
	return super.targetable() and not in_doghouse and _d - world.player_distance() <= _t.appear_distance


func aim_point() -> Vector3:
	return global_position + Vector3(0.0, 0.65, 0.0)


func hit_radius() -> float:
	return 0.75


# --- Layout checks (shared with octodog_rules.gd) ---------------------------------------------

## True if a charge may happen while the player runs from `from` to `to`: no fence (unless an EMP
## switched it off), no ceiling section or anti-grav pad, and holes in at most one lane (a single
## hole can be switched away from or jumped, and may be the bait for a gap kill).
static func window_clear(layout: LevelLayout, from: float, to: float) -> bool:
	for f: Dictionary in layout.fences:
		if float(f["at"]) >= from - 1.0 and float(f["at"]) <= to and not f.get("disabled", false):
			return false
	if ceiling_between(layout, from, to):
		return false
	var holed: Dictionary = {}
	for g: Dictionary in layout.gaps:
		if float(g["start"]) <= to and float(g["end"]) >= from:
			holed[int(g["lane"])] = true
	return holed.size() <= 1


## True if a ceiling section (with its lead-in and landing) or an anti-grav pad touches [from, to].
static func ceiling_between(layout: LevelLayout, from: float, to: float) -> bool:
	for h: Dictionary in layout.hulls:
		if float(h["start"]) - CEILING_LEAD <= to and float(h["end"]) + CEILING_LANDING >= from:
			return true
	for p: Dictionary in layout.pads:
		if float(p["at"]) >= from - CEILING_LEAD and float(p["at"]) <= to + CEILING_LEAD:
			return true
	return false
