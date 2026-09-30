class_name BadDream
extends Enemy
## The Cyborg's Bad Dream (GDD §9.7): a ghostly apparition of vapour and liquid (BadDreamModel).
##
## - Origin: it bursts out of a host cyborg when the host is killed (Cyborg._release_bad_dream
##   spawns it where the host stood). GDD §9.7: only one on screen at a time. DESIGN-TBD: one
##   released while another is still around never appears (the host's own purple burst is all the
##   player sees).
## - Movement: it floats ahead of the player, facing them and keeping pace, inside the camera's view.
##   It passes through fences, signs and every other barrier (it ignores the level's pieces). It
##   drifts toward the player's lane at a limited sideways speed and follows onto a wall slowly. It
##   can't reach a ship's hull: while the player rides a ceiling it waits below, ahead of them, and
##   attacks again once they're back down.
## - Attack: a telegraphed lunging slash across three lanes: the player's lane and the lanes on
##   either side, clamped at the edges (DESIGN-TBD: on a wall, the wall and the outer lane). The
##   telegraph locks those lanes and lights them on the floor in enemy-attack red, filling toward
##   the player as the lunge nears; the maw opens and it shrieks (bad_dream_shriek). Then it lunges
##   (bad_dream_slash) and its claws sweep the locked lanes; a player who has left them is safe.
##   It slashes every ~3–4 s (slash_interval, from one telegraph's start to the next) for its chase
##   (20–30 s), then it dissolves (bad_dream_dissolve) and a player who survived earns the survival
##   bonus. DESIGN-TBD: the chase clock runs from the moment it bursts out, also while it holds its
##   slash (the player on a ceiling, another enemy's attack), so a chase never outlasts the pads the
##   generator planned for it. DESIGN-TBD: the claws sweep higher than a jump reaches, so only
##   leaving the lanes (to a lane, a wall or a ceiling) dodges the slash.
## - Immune to weapons (auto-fire never targets it), stomping and claws. Its slash is an enemy
##   attack, so armor or the shield blocks one; the juggernaut dash passes through it safely and
##   doesn't hurt it (DamageRules; declared properties only). DESIGN-TBD: touching its body (it never
##   comes within reach anyway) is an enemy attack too. A fence generator's EMP dissolves it early.
## - Fairness (DESIGN-TBD, not in the GDD): it lines up with the player's lane before a telegraph
##   (waiting at most max_align_wait for a player who keeps moving; a wall only once it has followed
##   them there). It only telegraphs with the player on the floor or a wall (not falling into a hole
##   or dropping from a ceiling), never when the slash couldn't land before its chase ends, and never
##   when no escape is left (a free floor lane, or a wall no sign blocks: on three lanes the middle
##   lane's slash covers the whole floor).
## - GDD §9.7 at runtime: its chase is an exclusive major attack (Enemy.exclusive_major_attack):
##   Octodogs and drones don't start a charge sequence or a barrage while it chases, and it holds its
##   slash while one of theirs is on (EnemyDirector.major_attack_blocked). While big attacks take
##   turns (GDD §9, GameRules.big_attacks_take_turns) its chase is a big attack like theirs: no other
##   type's starts while it chases, and it holds its slash until another's (a hover truck's lurch or
##   cannon shot, say) is over and its shots have passed. Its chase starts when the player kills the
##   host, so it never waits itself. The generator guarantees anti-grav pads during the chase and
##   keeps chases apart (host_rules.gd).
##
## Spawn params: from_host (bool), chase (seconds: overrides the rolled chase length), emerge (bool,
## default true; false starts it already in place, for tests and the showcase).
## Numbers: data/enemies/bad_dream.tres (BadDreamTuning).

enum State { EMERGE, DRIFT, TELEGRAPH, LUNGE, RECOVER, DISSOLVE }

const STATE_NAMES: PackedStringArray = ["emerge", "drift", "telegraph", "lunge", "recover", "dissolve"]
## Its body's damage box, in the model's space (scaled with it): the head and neck, slimmer than the
## model (GDD §3); the vapour below is harmless. It never comes closer than lunge_ahead anyway.
const BODY_SIZE := Vector3(0.8, 1.5, 0.7)
const BODY_CENTER := Vector3(0.0, 2.45, 0.0)
## The lane marks start this far behind the player and reach this far past where it floats.
const MARKS_BEHIND: float = 1.2
const MARKS_BEYOND: float = 1.5
## How long the slash's claw streaks stay in view after the claws have passed.
const ARC_FADE: float = 0.22

var state: State = State.EMERGE
## Seconds since it burst out, and how long its chase lasts.
var chase_time: float = 0.0
var chase_seconds: float = 25.0
## The lanes the current (or last) slash covers, locked when its telegraph starts. Extended lane
## numbers: -1 is the left wall and lane_count the right wall.
var band := Vector2i(-1, -1)
## Slashes made so far.
var slashes: int = 0
## Events as [name, level time]: emerge, drift, telegraph, lunge, slash, recover, wait, resume,
## dissolve, emp, bonus, fizzle. Tests read it.
var history: Array = []
## Every sound it asked for, as [name, level time] (tests check each attack's audio warning).
var sounds: Array = []
## Its spot relative to the player: world x, the height of its tail's tip, metres ahead.
var rel_x: float = 0.0
var rel_y: float = 0.0
var rel_ahead: float = 0.0

var _t: BadDreamTuning
var _scaling: float = 0.0
var _state_time: float = 0.0
## chase_time from which the next telegraph may start.
var _next_slash: float = 0.0
var _align_wait: float = 0.0
var _waiting: bool = false
## The player is coming down from a ceiling (hull_end until they land).
var _dropping: bool = false
var _lunge_from: float = 0.0
var _slash_live: bool = false
var _slash_center := Vector2.ZERO
var _dissolve_len: float = 1.0
## Dissolved (or never appeared): the director retires it.
var _done: bool = false
var _arc_time: float = -1.0
var _arc_dir: float = 1.0
var _blocker_query := PhysicsShapeQueryParameters3D.new()

var _body: Hazard
var _slash: Hazard
var _slash_root: Node3D
var _model: BadDreamModel
var _marks: MeshInstance3D
var _marks_material: ShaderMaterial
var _arc: MeshInstance3D
var _arc_material: ShaderMaterial


func _build() -> void:
	_t = tuning_res as BadDreamTuning if tuning_res is BadDreamTuning else BadDreamTuning.new()
	display_name = "Bad Dream"
	# GDD §9.7: immune to weapons (auto-fire never targets it), stomping and claws; the juggernaut
	# dash passes through it safely but doesn't kill it. DamageRules reads these.
	immune_to_weapons = true
	claw_immune = true
	stompable = false
	dash_kills = false
	# GDD §9.7: never at the same time as an Octodog charge sequence or a drone barrage (whether or
	# not big attacks take turns; while they do, its chase holds every other type's too).
	exclusive_major_attack = true
	exclusive_of = [&"octodog", &"drone"]
	_scaling = world.config.enemy_scaling if world.config != null else 0.0
	var p: Dictionary = spawn.get("params", {})
	chase_seconds = float(p.get("chase", rng.randf_range(_t.chase_min_seconds, _t.chase_max_seconds)))
	var geo: TrackGeometry = world.geo
	var lane: int = clampi(int(spawn.get("lane", geo.lane_count / 2)), 0, geo.lane_count - 1)
	rel_x = geo.lane_x(lane)
	rel_y = -1.4
	rel_ahead = float(spawn.get("at", world.player.distance)) - world.player.distance
	_body = add_hitbox(&"body", BODY_SIZE * _t.model_scale, BODY_CENTER * _t.model_scale, true)
	_body.hazard_name = display_name
	_slash_root = Node3D.new()
	_slash_root.name = "SlashBox"
	_slash_root.top_level = true
	add_child(_slash_root)
	_slash = add_hitbox(&"attack", Vector3.ONE, Vector3.ZERO, true, _slash_root)
	_slash.hazard_name = "Bad Dream slash"
	_body.set_enabled(false)
	_slash.set_enabled(false)
	_blocker_query.collide_with_areas = true
	_blocker_query.collide_with_bodies = false
	_blocker_query.collision_mask = TrackBuilder.LAYER_LANE_BLOCKER
	var blocker_shape := BoxShape3D.new()
	blocker_shape.size = Vector3(geo.lane_width * 0.5, 1.0, 6.0)
	_blocker_query.shape = blocker_shape
	_build_visuals()
	world.player.movement_event.connect(_on_player_event)
	history.append(["emerge", world.level_time()])
	# GDD §9.7: only one on screen at a time. DESIGN-TBD: a second one never appears.
	for e: Enemy in world.director.active:
		if e != self and is_instance_valid(e) and e.alive and e is BadDream:
			_fizzle()
			return
	if not bool(p.get("emerge", true)):
		rel_y = _t.hover_height
		rel_ahead = _t.hover_ahead
		_model.fade = 0.0
		_body.set_enabled(true)
		_set_state(State.DRIFT)
		_next_slash = _t.first_slash_delay
	_place()


func _build_visuals() -> void:
	_model = BadDreamModel.new()
	_model.name = "Model"
	add_child(_model)
	_model.build(rng.randf() * 10.0)
	_model.scale = Vector3.ONE * _t.model_scale
	_model.fade = 1.0
	_model.animate()
	_marks_material = BadDreamModel.mark_material()
	_marks = MeshInstance3D.new()
	_marks.name = "LaneMarks"
	_marks.material_override = _marks_material
	_marks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_marks.top_level = true
	_marks.visible = false
	add_child(_marks)
	_arc_material = BadDreamModel.arc_material()
	_arc = MeshInstance3D.new()
	_arc.name = "ClawStreaks"
	_arc.mesh = BadDreamModel.arc_mesh()
	_arc.material_override = _arc_material
	_arc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_arc.top_level = true
	_arc.visible = false
	add_child(_arc)


# --- Behaviour ---------------------------------------------------------------------------------

func _tick(delta: float) -> void:
	if _done:
		return
	var p: Player = world.player
	chase_time += delta
	_state_time += delta
	match state:
		State.EMERGE:
			_emerge(p, delta)
		State.DRIFT:
			_drift(p, delta)
		State.TELEGRAPH:
			_telegraph(delta)
		State.LUNGE:
			_lunge(p)
		State.RECOVER:
			_float_toward(p, delta, _t.hover_ahead)
			rel_y = move_toward(rel_y, _t.hover_height, 3.0 * delta)
			if _state_time >= _t.recover_time:
				_set_state(State.DRIFT)
		State.DISSOLVE:
			_float_toward(p, delta, rel_ahead)
			if _state_time >= _dissolve_len:
				_done = true
	_place()


## Rising out of the host, harmless, then off to its spot ahead of the player. It can't hurt anyone
## before it's in front of them.
func _emerge(p: Player, delta: float) -> void:
	var k: float = clampf(_state_time / _t.emerge_time, 0.0, 1.0)
	_float_toward(p, delta, _t.hover_ahead)
	rel_y = lerpf(-1.4, _t.hover_height, 1.0 - pow(1.0 - k, 2.0))
	if k >= 1.0 and rel_ahead >= _t.lunge_ahead:
		_body.set_enabled(true)
		_set_state(State.DRIFT)
		_next_slash = chase_time + _t.first_slash_delay


func _drift(p: Player, delta: float) -> void:
	var waiting: bool = p.surface == Player.Surface.CEILING
	if waiting != _waiting:
		_waiting = waiting
		history.append(["wait" if waiting else "resume", world.level_time()])
	if chase_time >= chase_seconds:
		_start_dissolve(true, false)
		return
	_float_toward(p, delta, _t.wait_ahead if _waiting else _t.hover_ahead)
	rel_y = move_toward(rel_y, _t.hover_height, 3.0 * delta)
	if chase_time < _next_slash or not _may_slash(p):
		_align_wait = 0.0
		return
	# DESIGN-TBD: line up with the player's lane first; a player who keeps moving is attacked anyway
	# after max_align_wait, but one on a wall only once it has followed them there.
	_align_wait += delta
	var lined_up: bool = absf(rel_x - _target_x(p)) <= _t.align_tolerance
	if not lined_up and (_align_wait < _t.max_align_wait or p.surface == Player.Surface.WALL):
		return
	var b: Vector2i = band_for(p)
	if _escape_open(p, b):
		_start_telegraph(b)


## Whether a telegraph may start now: the player is on the floor or a wall, not falling into a hole
## or coming down from a ceiling (it waits below the hull until they're down); no other enemy's
## major attack is on (GDD §9.7, and GDD §9 while big attacks take turns); and the slash lands
## before the chase ends.
func _may_slash(p: Player) -> bool:
	if not p.alive or not p.running or p.in_pit or _dropping or p.surface == Player.Surface.CEILING:
		return false
	if world.director.major_attack_blocked(self):
		return false
	return chase_time + _t.warning_time(_scaling) + _t.slash_active <= chase_seconds


func _start_telegraph(b: Vector2i) -> void:
	band = b
	var box: AABB = slash_box_for(b)
	_slash.size = box.size
	((_slash.get_child(0) as CollisionShape3D).shape as BoxShape3D).size = box.size
	_slash_center = Vector2(box.get_center().x, box.get_center().y)
	_next_slash = chase_time + rng.randf_range(_t.slash_interval_min, _t.slash_interval_max)
	_arc_dir = 1.0 if rng.randf() < 0.5 else -1.0
	_set_state(State.TELEGRAPH)
	_sfx(&"bad_dream_shriek")
	_show_marks(b)


func _telegraph(delta: float) -> void:
	# It squares up over the lanes it's about to slash and rears back a little.
	rel_x = move_toward(rel_x, _band_center_x(band), _t.drift_speed * delta)
	rel_ahead = move_toward(rel_ahead, _t.hover_ahead + 0.6, _t.approach_speed * delta)
	rel_y = move_toward(rel_y, _t.hover_height + 0.25, 1.5 * delta)
	if _state_time >= _t.telegraph_time(_scaling):
		_lunge_from = rel_ahead
		_set_state(State.LUNGE)
		_sfx(&"bad_dream_slash")


## The lunge: it rushes at the player and, as it arrives, its claws are live over the locked lanes
## for slash_active.
func _lunge(p: Player) -> void:
	var k: float = clampf(_state_time / _t.lunge_time, 0.0, 1.0)
	rel_ahead = lerpf(_lunge_from, _t.lunge_ahead, k * k)
	rel_y = lerpf(_t.hover_height + 0.25, _t.hover_height - 0.6, k)
	if _state_time >= _t.lunge_time and not _slash_live:
		_slash_live = true
		_slash.set_enabled(true)
		slashes += 1
		_arc_time = 0.0
		history.append(["slash", world.level_time()])
	if _slash_live:
		_place_slash(p)
		if _state_time >= _t.lunge_time + _t.slash_active:
			_slash_live = false
			_slash.set_enabled(false)
			_set_state(State.RECOVER)


func _start_dissolve(survived: bool, emp: bool) -> void:
	_slash_live = false
	_slash.set_enabled(false)
	_body.set_enabled(false)
	_marks.visible = false
	# Its chase is over: a slash it was holding for another's attack won't come (GDD §9).
	world.director.give_up_turn(self)
	_dissolve_len = _t.emp_dissolve_time if emp else _t.dissolve_time
	_set_state(State.DISSOLVE)
	_sfx(&"bad_dream_dissolve")
	world.effects.burst(head_point(), BadDreamModel.PURPLE, 30, 0.9)
	world.effects.burst(global_position + Vector3(0.0, 1.2, 0.0), Color(0.12, 0.03, 0.2), 20, 0.6)
	if survived and world.player.alive:
		# GDD §9.7: surviving the full chase earns a score bonus.
		world.score.add_bonus(&"chase", _t.survival_bonus, "Survived the Bad Dream")
		world.play_sfx(&"bonus")
		history.append(["bonus", world.level_time()])


func _fizzle() -> void:
	history.append(["fizzle", world.level_time()])
	visible = false
	_done = true
	state = State.DISSOLVE


## GDD §9.7: a fence generator's EMP dissolves it early. DESIGN-TBD: wherever it is (the EMP's radius
## only limits the fences it switches off), and without the survival bonus.
func on_emp(_center: Vector3, _radius: float) -> void:
	if _done or state == State.DISSOLVE:
		return
	history.append(["emp", world.level_time()])
	_start_dissolve(false, true)


func _on_player_event(kind: StringName) -> void:
	match kind:
		&"hull_end":
			_dropping = true
		&"land", &"revive", &"died":
			_dropping = false


func _sfx(sound: StringName) -> void:
	sounds.append([sound, world.level_time()])
	world.play_sfx_at(sound, head_point())


func _set_state(next: State) -> void:
	state = next
	_state_time = 0.0
	history.append([STATE_NAMES[next], world.level_time()])


# --- Where it goes -----------------------------------------------------------------------------

## Keeps its distance ahead of the player (closing at approach_speed) and drifts toward the x it
## follows: at drift_speed over the floor, at wall_follow_speed while the player is on a wall.
func _float_toward(p: Player, delta: float, ahead: float) -> void:
	rel_ahead = move_toward(rel_ahead, ahead, _t.approach_speed * delta)
	var speed: float = _t.wall_follow_speed if p.surface == Player.Surface.WALL else _t.drift_speed
	rel_x = move_toward(rel_x, _target_x(p), speed * delta)


## The x it follows: the player's lane (on the floor or a ceiling), or just inside their wall.
func _target_x(p: Player) -> float:
	if p.surface == Player.Surface.WALL:
		return p.wall_side * (world.geo.wall_x() - _t.wall_inset)
	return world.geo.lane_x(clampi(p.lane, 0, world.geo.lane_count - 1))


## The middle of a band (a wall counts as the spot just inside it).
func _band_center_x(b: Vector2i) -> float:
	var sum: float = 0.0
	for lane: int in range(b.x, b.y + 1):
		sum += _extended_lane_x(lane)
	return sum / float(b.y - b.x + 1)


func _extended_lane_x(lane: int) -> float:
	var geo: TrackGeometry = world.geo
	if lane < 0:
		return -(geo.wall_x() - _t.wall_inset)
	if lane >= geo.lane_count:
		return geo.wall_x() - _t.wall_inset
	return geo.lane_x(lane)


func _place() -> void:
	position = Vector3(rel_x, rel_y, TrackGeometry.world_z(world.player.distance + rel_ahead))


## The slash's damage box sits on the player's spot along the track while it's live.
func _place_slash(p: Player) -> void:
	_slash_root.global_transform = Transform3D(Basis.IDENTITY,
		Vector3(_slash_center.x, _slash_center.y, TrackGeometry.world_z(p.distance)))


# --- The slash's lanes -------------------------------------------------------------------------

## The lanes a slash at `p` would cover now (GDD §9.7): their lane and the lanes on either side,
## clamped at the edges. DESIGN-TBD: on a wall, the wall and the outer floor lane beside it.
## Extended lane numbers: -1 is the left wall, lane_count the right wall.
func band_for(p: Player) -> Vector2i:
	var n: int = world.geo.lane_count
	if p.surface == Player.Surface.WALL:
		return Vector2i(-1, 0) if p.wall_side < 0 else Vector2i(n - 1, n)
	var lane: int = clampi(p.lane, 0, n - 1)
	return Vector2i(maxi(lane - 1, 0), mini(lane + 1, n - 1))


## The locked lanes of the current (or last) slash, as a list of extended lane numbers.
func slash_lanes() -> Array[int]:
	var out: Array[int] = []
	if band.y >= band.x and not (band.x == -1 and band.y == -1):
		for lane: int in range(band.x, band.y + 1):
			out.append(lane)
	return out


## The slash's damage box for band `b`: world x and y, and z around the player's spot (depth
## slash_depth). Slightly smaller than the lit lanes (GDD §3): side_margin at an edge next to a free
## lane, wall_clearance at an edge by a wall (so a player who escapes onto that wall is never
## clipped), from the floor to slash_height. A wall in the band is covered up to wall_slash_top.
func slash_box_for(b: Vector2i) -> AABB:
	var geo: TrackGeometry = world.geo
	var n: int = geo.lane_count
	var lo: int = clampi(b.x, 0, n - 1)
	var hi: int = clampi(b.y, 0, n - 1)
	var half: float = geo.lane_width * 0.5
	var x0: float = geo.lane_x(lo) - half + (_t.wall_clearance if lo == 0 else _t.side_margin)
	var x1: float = geo.lane_x(hi) + half - (_t.wall_clearance if hi == n - 1 else _t.side_margin)
	var top: float = _t.slash_height
	if b.x < 0:
		x0 = -geo.wall_x() - 0.5
		top = _t.wall_slash_top
	if b.y >= n:
		x1 = geo.wall_x() + 0.5
		top = _t.wall_slash_top
	return AABB(Vector3(x0, 0.0, -_t.slash_depth * 0.5), Vector3(x1 - x0, top, _t.slash_depth))


## DESIGN-TBD (fairness, not in the GDD): a slash over `b` must leave the player somewhere to go: a
## floor lane outside it that no solid side fills (a hover truck), or a wall beside it that no sign
## blocks until the slash has passed. With three lanes and the player in the middle, the band covers
## the whole floor.
func _escape_open(p: Player, b: Vector2i) -> bool:
	var n: int = world.geo.lane_count
	for lane: int in n:
		if (lane < b.x or lane > b.y) and not _lane_blocked(lane, p):
			return true
	var until: float = p.distance + maxf(p.speed, 1.0) * (_t.warning_time(_scaling) + _t.slash_active) + 2.0
	for side: int in [-1, 1]:
		var wall: int = -1 if side < 0 else n
		if wall >= b.x and wall <= b.y:
			continue
		if not _sign_between(side, p.distance - 1.0, until):
			return true
	return false


func _lane_blocked(lane: int, p: Player) -> bool:
	if not is_inside_tree():
		return false
	_blocker_query.transform = Transform3D(Basis.IDENTITY,
		Vector3(world.geo.lane_x(lane), 0.6, TrackGeometry.world_z(p.distance)))
	return not get_world_3d().direct_space_state.intersect_shape(_blocker_query, 1).is_empty()


func _sign_between(side: int, from: float, to: float) -> bool:
	for s: Dictionary in world.layout.signs:
		if int(s["side"]) == side and float(s["start"]) <= to and float(s["end"]) >= from:
			return true
	return false


# --- Declared properties and the director ------------------------------------------------------

## GDD §9.7: its whole chase is a major attack (from bursting out until it dissolves). DESIGN-TBD
## (docs/questions/r3.md): while big attacks take turns (GDD §9) the whole chase holds every other
## type's big attack too, not only between its slashes.
func is_major_attack_active() -> bool:
	return alive and not _done and state != State.DISSOLVE


## Seconds from a telegraph's start until its claws are live (the slash's warning).
func warning_time() -> float:
	return _t.warning_time(_scaling)


## While the player rides a ceiling it waits below.
func is_waiting() -> bool:
	return _waiting and state == State.DRIFT


func is_attacking() -> bool:
	return state == State.TELEGRAPH or state == State.LUNGE


## The slash's damage box is live.
func is_slashing() -> bool:
	return _slash_live


func body_hitbox() -> Hazard:
	return _body


func slash_hitbox() -> Hazard:
	return _slash


func should_retire() -> bool:
	return _done


func head_point() -> Vector3:
	return global_position + BadDreamModel.HEAD_CENTER * _t.model_scale


## World height of the top of its head (GDD §9.7: it never reaches a ship's hull).
func top_height() -> float:
	return global_position.y + (BadDreamModel.HEAD_CENTER.y + BadDreamModel.HEAD_RADII.y) * _t.model_scale


func aim_point() -> Vector3:
	return head_point()


func hit_radius() -> float:
	return 0.6


## Nothing defeats it (immune to weapons, stomping and claws; the dash passes through). Should a
## rule ever call defeat(), it melts away like a dissolve.
func _on_defeated(_cause: StringName) -> void:
	_sfx(&"bad_dream_dissolve")
	world.effects.burst(head_point(), BadDreamModel.PURPLE, 30, 0.9)
	queue_free()


# --- Presentation ------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if _model == null or world == null or _done or not is_instance_valid(world.player):
		return
	var p: Player = world.player
	var maw: float = 0.12 + 0.06 * sin(chase_time * 2.3)
	var raise: float = 0.0
	var slash: float = 0.0
	var attack: float = 0.0
	var lunge: float = 0.0
	var fade: float = 0.0
	var reach: float = 1.0
	match state:
		State.EMERGE:
			fade = 1.0 - smoothstep(0.0, 1.0, _state_time / _t.emerge_time)
			maw = 0.7 * (1.0 - fade)
		State.DRIFT:
			if _waiting:
				# Reaching up at the hull it can't reach, maw open.
				maw = 0.5 + 0.1 * sin(chase_time * 3.1)
				raise = 0.6
		State.TELEGRAPH:
			var k: float = clampf(_state_time / _t.telegraph_time(_scaling), 0.0, 1.0)
			maw = smoothstep(0.0, 0.35, k)
			raise = smoothstep(0.0, 0.55, k)
			attack = smoothstep(0.05, 0.85, k)
			reach = _band_reach()
		State.LUNGE:
			var k: float = clampf(_state_time / (_t.lunge_time + _t.slash_active), 0.0, 1.0)
			maw = 1.0
			raise = 1.0 - k
			slash = k
			attack = 1.0
			lunge = k
			reach = _band_reach()
		State.RECOVER:
			var k: float = clampf(_state_time / _t.recover_time, 0.0, 1.0)
			maw = 1.0 - 0.85 * k
			slash = 1.0 - k
			attack = 1.0 - k
			lunge = 1.0 - k
			reach = lerpf(_band_reach(), 1.0, k)
		State.DISSOLVE:
			fade = clampf(_state_time / maxf(_dissolve_len, 0.01), 0.0, 1.0)
			maw = 0.8
	var smooth: float = 1.0 - exp(-18.0 * delta)
	_model.maw = lerpf(_model.maw, maw, smooth)
	_model.raise = lerpf(_model.raise, raise, smooth)
	_model.slash = lerpf(_model.slash, slash, 1.0 - exp(-40.0 * delta))
	_model.attack = lerpf(_model.attack, attack, smooth)
	_model.lunge = lerpf(_model.lunge, lunge, 1.0 - exp(-30.0 * delta))
	_model.reach = lerpf(_model.reach, reach, smooth)
	_model.fade = fade
	_model.animate()
	# It faces the player; it leans in to lunge and tips its head back to look up at a ceiling.
	var yaw: float = atan2(p.position.x - rel_x, maxf(rel_ahead, 0.5))
	_model.rotation.y = lerp_angle(_model.rotation.y, yaw, 1.0 - exp(-8.0 * delta))
	var pitch: float = 0.3 * _model.lunge - (0.22 if _waiting and state == State.DRIFT else 0.0)
	_model.rotation.x = lerpf(_model.rotation.x, pitch, 1.0 - exp(-8.0 * delta))
	_update_marks()
	_update_arc(delta)


## How far the arms stretch to reach over the band's outer lanes.
func _band_reach() -> float:
	var half_width: float = absf(_extended_lane_x(band.y) - _extended_lane_x(band.x)) * 0.5
	return clampf(0.85 + half_width / (2.6 * _t.model_scale), 1.0, 1.9)


func _show_marks(b: Vector2i) -> void:
	var geo: TrackGeometry = world.geo
	var n: int = geo.lane_count
	var strips: Array[Vector2] = []
	for lane: int in range(maxi(b.x, 0), mini(b.y, n - 1) + 1):
		strips.append(Vector2(geo.lane_x(lane) - geo.lane_width * 0.5 + 0.12,
			geo.lane_x(lane) + geo.lane_width * 0.5 - 0.12))
	var wall_x: float = 0.0
	if b.x < 0:
		wall_x = -geo.wall_x() + 0.03
	elif b.y >= n:
		wall_x = geo.wall_x() - 0.03
	_marks.mesh = BadDreamModel.marks_mesh(strips, wall_x, _t.wall_slash_top, MARKS_BEHIND,
		_t.hover_ahead + MARKS_BEYOND)
	_marks.visible = true


func _update_marks() -> void:
	var shown: bool = state == State.TELEGRAPH or state == State.LUNGE \
		or (state == State.RECOVER and _state_time < 0.25)
	_marks.visible = shown
	if not shown:
		return
	var progress: float = 1.0
	var fade: float = 1.0
	if state == State.TELEGRAPH:
		progress = clampf(_state_time / _t.telegraph_time(_scaling), 0.0, 1.0)
		fade = clampf(_state_time / 0.12, 0.0, 1.0)
	elif state == State.LUNGE:
		# Dimmer as the claws sweep, so the streaks stand out.
		fade = lerpf(1.0, 0.45, clampf(_state_time / maxf(_t.lunge_time, 0.01), 0.0, 1.0))
	elif state == State.RECOVER:
		fade = 0.45 * (1.0 - _state_time / 0.25)
	_marks_material.set_shader_parameter(&"progress", progress)
	_marks_material.set_shader_parameter(&"fade", fade)
	_marks.global_position = Vector3(0.0, 0.035, world.player.position.z)


func _update_arc(delta: float) -> void:
	if _arc_time < 0.0:
		_arc.visible = false
		return
	_arc_time += delta
	var life: float = _t.slash_active + ARC_FADE
	if _arc_time >= life:
		_arc_time = -1.0
		_arc.visible = false
		return
	_arc.visible = true
	_arc_material.set_shader_parameter(&"sweep", clampf(_arc_time / maxf(_t.slash_active, 0.01), 0.0, 1.0))
	_arc_material.set_shader_parameter(&"fade", 1.0 - clampf((_arc_time - _t.slash_active) / ARC_FADE, 0.0, 1.0))
	_arc_material.set_shader_parameter(&"dir", _arc_dir)
	var width: float = maxf(_slash.size.x, 0.5)
	var height: float = _slash.size.y / _t.slash_height
	_arc.global_transform = Transform3D(Basis.from_scale(Vector3(width, height, 1.0)),
		Vector3(_slash_center.x, 0.0, world.player.position.z - 0.2))
