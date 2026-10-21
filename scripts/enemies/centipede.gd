class_name Centipede
extends Enemy
## The Cybernetic Centipede (task O3; GDD §9.15, the owner, October 20, 2026): the Terminal's only enemy, a long,
## segmented brass-and-steel centipede that haunts the debris maze (DebrisMaze) and chases the runner along its open
## paths. Floor only. Its generator rules (centipede_rules.gd) place it in a block's open cell where the block stays
## escapable (CentipedeEscape), and every rule it keeps below is one that proof relies on.
##
## 1. It waits, still (SLEEP), its head at its spot facing back toward the runner's approach, its body behind it in its
##    lane, its lenses glowing.
## 2. It wakes when the runner, on the floor, enters a section of the maze close to it (GDD §9.15): its own section of
##    its block, or one joined to it (DebrisMaze.links(..., broken = true): through an opening, or where this attempt's
##    dashes smashed debris, so a dash that opens a walled-in cell releases it), within its wake distance along the track
##    (CentipedeTuning.wake_distance_at). A runner who keeps out of its corridor and the cells it opens onto passes it by.
##    The warning: a hiss and a clatter of legs (centipede_wake); it rears up and its lenses flare, and only after
##    wake_time does it move (WAKE).
## 3. It chases (CHASE) along the maze's open floor (CentipedeMaze.find_path toward the runner, its head aiming along the
##    way as far as it sees clear, never into debris: CentipedeMaze.clear_at), at most its chase speed (a share of the run
##    speed: the runner is slightly faster, but a stop at debris lets it catch them). It turns round in a lane to come
##    back along a cell, slowing as it swings.
## 4. Its bite: when the runner will be within its reach in front of its head by the end of the telegraph, with nothing
##    between, its head rears and its jaws open with a hiss and a clack (centipede_bite; OPENING, bite_telegraph); only
##    then is its bite live (STRIKE, bite_window: still reared, its head darts forward and back as its jaws snap shut,
##    centipede_snap), and a contact in that time is one hit (DamageRules: an enemy attack, which armor or the shield
##    absorbs, then the invulnerability window; else it kills). Its bite's hitbox reaches from its head's front to just
##    short of its jaws' tips as they're drawn that frame (with the lunge), never further than bite_reach, its height
##    under the reared head (GDD §3: hitboxes inside what's drawn). Then its jaws rest (REST) and its head sinks before
##    the next. Its body and legs are harmless (Hazard.harmless).
## 5. The dash passes through it safely and wounds it (Enemy.dash_hits: GDD §9.15, "two dashes kill it"): it recoils,
##    stunned (STUN), a tube on its back cracked and leaking green, sparks flying; then it turns and chases from behind.
##    The second dash kills it. Weapons, claws and stomps do nothing (immune_to_weapons, claw_immune, not stompable: no
##    auto-fire at it, no claw kill, and landing on it neither hurts it nor bounces the runner).
## 6. It can't follow onto a ceiling: a runner who rides one gets away, and it gives up (GIVE_UP: it slows to a stop, its
##    legs folding and its lenses dimming, and stays so). So it does when it has fallen give_up_distance behind along its
##    way, or when the runner is out past its block's last wall into the breather (leave_margin): it never leaves its
##    block's stretch. Given up, or asleep as the runner passes, it leaves play behind them (should_retire).
## It isn't a big attack (the Terminal has no other enemy to take turns with: is_major_attack_active). Its look:
## CentipedeModel.

enum State { SLEEP, WAKE, CHASE, STUN, GIVE_UP }
enum Jaw { CLOSED, OPENING, STRIKE, REST }

const STATE_NAMES: PackedStringArray = ["sleep", "wake", "chase", "stun", "give_up"]
## Body segments behind the head, and the spacing of their middles along its trail (metres).
const SEGMENTS: int = 9
const SEGMENT_SPACING: float = 0.62
## The body's length behind its head's middle (metres): what a spot leaves room for in its cell (centipede_rules.gd).
const BODY_LENGTH: float = (SEGMENTS + 0.5) * SEGMENT_SPACING
## The trail its body follows: a point every TRAIL_STEP metres the head has gone.
const TRAIL_STEP: float = 0.08
## Its head's middle above the floor at rest, and the head's hitbox (harmless; a dash meets it), smaller than drawn, its
## bottom this far above the floor.
const HEAD_HEIGHT: float = 0.6
const HEAD_HIT := Vector3(0.7, 0.8, 0.6)
const HEAD_BOX_LIFT: float = 0.1
## Harmless hitboxes along its body (a dash through any of it wounds it): how many, each this size, smaller than drawn,
## their bottoms this far above the floor.
const BODY_BOXES: int = 4
const BODY_HIT := Vector3(0.66, 0.75, 1.3)
const BODY_BOX_LIFT: float = 0.08
## The farthest bin of its way it aims at (bins), and how often it looks for its way again (seconds).
const LOOKAHEAD: int = 12
const REPATH: float = 0.2
## Its way is looked for within this far beyond its head and the runner (metres).
const WINDOW: float = 40.0
## Within this far of the runner with nothing between, it goes straight for them (metres).
const STRAIGHT_RANGE: float = 14.0
## How far short of the runner's middle its head's middle stops (metres): far enough that its reared head, between the
## runner and the camera behind them, leaves their head in sight, near enough that its bite reaches them. DESIGN-TBD
## (docs/questions/o3.md 14): from behind, its reared head still hides most of the runner while it bites.
const STANDOFF: float = 1.3
## How finely a line of sight is sampled (metres).
const SIGHT_STEP: float = 0.3
## Its head turns this much slower while its jaws are open (a share of turn_rate).
const BITE_TURN_SHARE: float = 0.5
## A bite rears for the runner's body: their half width and half depth (MovementTuning.visual_size), and this much more
## across, so a runner beside its jaws' line still makes it rear (metres).
const BITE_SIDE_SLACK: float = 0.3
## Seconds it lingers after giving up before it may leave play.
const GIVE_UP_LINGER: float = 2.0
## The share of its jaws' rest over which its head sinks back down after a strike.
const REST_SINK: float = 0.5
## The shortest its bite's hitbox gets in front of its head's front (metres), and how far short of its jaws' tips drawn
## it stops (metres; GDD §3: hitboxes a little smaller than what's drawn).
const MIN_BITE: float = 0.1
const BITE_INSET: float = 0.05
## A line of sight for its bite is sampled this finely (metres), through a probe this small either way (metres): debris
## between its head and the runner keeps it from rearing at them.
const BITE_SIGHT_STEP: float = 0.25
const BITE_SIGHT_HALF: float = 0.1
## The hazard green of its glass and lenses (GDD §9.15: "glowing green", kept as drawn; the colour rule's hazard green).
const GLOW := Color(0.35, 1.0, 0.3)

var state: State = State.SLEEP
var jaw: Jaw = Jaw.CLOSED
## Where the generator put it (centipede_rules.gd): "near", "way" or "trapped" ("" for one placed by hand).
var situation: String = ""
## Its maze block (the index in LevelLayout.maze), or -1 outside any.
var block_index: int = -1
## True once a dash has wounded it.
var wounded: bool = false
## Its states as [name, level time, runner distance], for tests and tools.
var history: Array = []
## Each bite as [the level time its telegraph began, the time it went live (-1 until then)].
var bites: Array = []
## Contacts its bite made (each one hit, whatever armor or the shield made of it).
var bite_hits: int = 0
## Each contact its bite made as [the level time, its jaws live (STRIKE), seconds since that bite's telegraph began].
var bite_contacts: Array = []
## The farthest it has moved in one physics step (metres), for tests: never more than its chase speed allows.
var max_step: float = 0.0
## Every sound it has played, in order (its warnings), for tests.
var sounds_played: Array[StringName] = []

var _t: CentipedeTuning
var _maze: CentipedeMaze
var _block: Dictionary = {}
var _secs: Array[Dictionary] = []
## The sections whose runner wakes it: its own and those joined to it (ids in _secs).
var _wakers: Dictionary = {}
## Its head's middle in track terms: x (world x), y (track distance).
var _head := Vector2.ZERO
## Where its head points: 0 toward +track distance (away from the runner's approach), PI toward the runner's approach.
var _heading: float = PI
var _speed: float = 0.0
var _chase_v: float = 15.0
var _wake_d: float = 30.0
var _give_up_d: float = 45.0
var _state_time: float = 0.0
var _jaw_time: float = 0.0
var _stun_for: float = 0.0
## The head's positions behind it, newest first (TRAIL_STEP apart).
var _trail := PackedVector2Array()
var _path: Array[Vector2i] = []
var _path_cost: int = 0
var _repath_left: float = 0.0
var _gait: float = 0.0
var _head_box: Hazard
var _body_boxes: Array[Hazard] = []
var _bite_box: Hazard
var _model: CentipedeModel


## A centipede's look (every part it may show: the wounded crack, its leak and sparks), for EnemyDirector.warm_up and
## ShaderWarmup.
static func warm_up(world: RunWorld, _entry: Dictionary) -> Node:
	var model := CentipedeModel.new()
	model.build(world.skin.enemy_variant if world.skin != null else &"city", SEGMENTS, true)
	return model


func _build() -> void:
	display_name = "Cybernetic Centipede"
	immune_to_weapons = true
	claw_immune = true
	stompable = false
	dash_kills = true
	_t = tuning_res as CentipedeTuning if tuning_res is CentipedeTuning else CentipedeTuning.new()
	dash_hits = maxi(_t.dash_hits, 1)
	max_health = 1.0
	var params: Dictionary = spawn.get("params", {})
	situation = String(params.get("situation", ""))
	var lanes: int = world.geo.lane_count
	var lane: int = clampi(int(spawn.get("lane", lanes / 2)), 0, lanes - 1)
	var at: float = float(spawn.get("at", 0.0))
	block_index = CentipedeMaze.block_at(world.layout, at) if world.layout != null else -1
	if block_index >= 0:
		_maze = CentipedeMaze.for_block(world.layout, block_index, world.tuning)
		_block = world.layout.maze[block_index]
	_chase_v = _t.chase_speed(world.tuning.run_speed)
	_wake_d = _t.wake_distance_at(world.tuning.pace())
	_give_up_d = _t.give_up_distance_at(world.tuning.pace())
	_head = Vector2(world.geo.lane_x(lane), at)
	_heading = PI
	# Its body lies behind its head in its lane.
	for i: int in int(ceil(BODY_LENGTH / TRAIL_STEP)) + 2:
		_trail.append(Vector2(_head.x, at + i * TRAIL_STEP))
	# Its head and body are harmless, its bite alone hurts. DESIGN-TBD (docs/questions/o3.md 4): should running into its
	# body hurt too?
	_head_box = add_hitbox(&"body", HEAD_HIT, Vector3.ZERO)
	_head_box.harmless = true
	_head_box.is_solid = false
	_head_box.top_level = true
	for i: int in BODY_BOXES:
		var box: Hazard = add_hitbox(&"body", BODY_HIT, Vector3.ZERO)
		box.harmless = true
		box.is_solid = false
		box.top_level = true
		_body_boxes.append(box)
	_bite_box = add_hitbox(&"attack", Vector3(_t.bite_width, _t.bite_height, _t.lunge_reach + _t.bite_length),
		Vector3.ZERO, true)
	_bite_box.top_level = true
	_bite_box.hazard_name = display_name
	_bite_box.set_enabled(false)
	_bite_box.contacted.connect(_on_bitten)
	_model = CentipedeModel.new()
	_model.name = "Model"
	add_child(_model)
	_model.build(world.skin.enemy_variant if world.skin != null else &"city", SEGMENTS, false)
	_refresh_sections()
	_place(0.0)


# --- Behaviour ------------------------------------------------------------------------------

func _tick(delta: float) -> void:
	var p: Player = world.player
	_state_time += delta
	if _maze != null and _maze.refresh():
		_refresh_sections()
	match state:
		State.SLEEP:
			if _should_wake(p):
				_wake(_t.wake_time)
		State.WAKE:
			if _state_time >= _stun_for:
				_set_state(State.CHASE)
		State.CHASE:
			if _gives_up(p):
				_set_state(State.GIVE_UP)
			else:
				_chase(delta, p)
				_bite(delta, p)
		State.STUN:
			_slow(delta)
			if _state_time >= _stun_for:
				_set_state(State.CHASE)
		State.GIVE_UP:
			_slow(delta)
	if jaw != Jaw.CLOSED and state != State.CHASE:
		_close_jaws()
	_place(delta)


func _set_state(next: State) -> void:
	state = next
	_state_time = 0.0
	history.append([STATE_NAMES[next], world.level_time(), world.player.distance])
	match next:
		State.CHASE:
			_repath_left = 0.0
		State.GIVE_UP:
			_model.set_awake(false)


## True if the runner wakes it now (see the header, 2). DESIGN-TBD (docs/questions/o3.md 1): "close to it" read as the
## runner on the floor in its own section or one joined to it, within its wake distance.
func _should_wake(p: Player) -> bool:
	if not p.alive or p.surface != Player.Surface.FLOOR or _maze == null:
		return false
	if absf(p.distance - _head.y) > _wake_d:
		return false
	return _wakers.has(_runner_section(p))


## Wakes it (the warning: the hiss and the legs' clatter, its rearing up), to move `still` seconds later.
func _wake(still: float) -> void:
	_stun_for = still
	_set_state(State.WAKE)
	_model.set_awake(true)
	_play(&"centipede_wake")


## Plays `sound` at its head (its warnings and its wounds), and notes it (sounds_played).
func _play(sound: StringName) -> void:
	sounds_played.append(sound)
	world.play_sfx_at(sound, _world_head())


## The sections of its block (DebrisMaze.sections and links with this attempt's smashes, on the block alone) and those
## whose runner wakes it (its own, and every one joined to it), made again whenever a dash smashes some of the block: a
## dash that opens a walled-in one's cell releases it. DESIGN-TBD (docs/questions/o3.md 8): the release.
func _refresh_sections() -> void:
	_wakers.clear()
	if _maze == null:
		return
	var bl: LevelLayout = _maze.block_layout()
	_secs = DebrisMaze.sections(bl, true)
	var mine: int = DebrisMaze.section_at(_secs, _maze.lane_at(_head.x), _head.y)
	if mine < 0:
		return
	_wakers[mine] = true
	for k: Dictionary in DebrisMaze.links(bl, _secs, true):
		if int(k["from"]) == mine:
			_wakers[int(k["to"])] = true
		elif int(k["to"]) == mine:
			_wakers[int(k["from"])] = true


## The sections whose runner wakes it now (ids in its block's sections), for tests.
func waking_sections() -> Array:
	return _wakers.keys()


## The runner's section of its block, or -1 (not in the block, or nowhere open).
func _runner_section(p: Player) -> int:
	return _section_near(world.geo.lane_at(p.position.x), p.distance)


## The section holding `lane` at track distance `at`, or, inside a wall's opening (no section there), the one just
## past or before it in that lane: -1 if none is near, or if `at` is outside its block's stretch (from its run-in's start
## to its breather's end: no probe looks past either, so a runner not yet in the block never wakes it, as the escape
## proof's runner starts at the run-in).
func _section_near(lane: int, at: float) -> int:
	var lo: float = float(_block.get("entry", -INF))
	var hi: float = float(_block.get("exit", INF))
	if at < lo or at > hi:
		return -1
	for dz: float in [0.0, 2.0, -2.0, 4.0, -4.0, 7.0, -7.0]:
		if at + dz < lo or at + dz > hi:
			continue
		var id: int = DebrisMaze.section_at(_secs, lane, at + dz)
		if id >= 0:
			return id
	return -1


## True if it gives up the chase now (see the header, 6). DESIGN-TBD (docs/questions/o3.md 5): when it gives up.
func _gives_up(p: Player) -> bool:
	if not p.alive or p.surface == Player.Surface.CEILING or _maze == null:
		return true
	if p.distance > float(_block["end"]) + _t.leave_margin:
		return true
	if p.distance - _head.y > _give_up_d:
		return true
	return not _path.is_empty() and float(_path_cost) / CentipedeMaze.STEP_COST * CentipedeMaze.BIN > _give_up_d


func _chase(delta: float, p: Player) -> void:
	var runner := Vector2(p.position.x, p.distance)
	_repath_left -= delta
	if _repath_left <= 0.0:
		_repath_left = REPATH
		var lo: float = minf(_head.y, runner.y) - WINDOW
		var hi: float = maxf(_head.y, runner.y) + WINDOW
		_path = _maze.find_path(_maze.lane_at(_head.x), _head.y, world.geo.lane_at(runner.x), runner.y, lo, hi)
		_path_cost = _cost_of(_path)
	var target: Vector2 = _target(runner)
	_steer(delta, target, runner)


## The cost of way `path` (find_path's units).
func _cost_of(path: Array[Vector2i]) -> int:
	var out: int = 0
	for i: int in range(1, path.size()):
		var dl: int = absi(path[i].x - path[i - 1].x)
		var dk: int = absi(path[i].y - path[i - 1].y)
		out += _maze.diagonal_cost if dl > 0 and dk > 0 else (_maze.lateral_cost if dl > 0 else CentipedeMaze.STEP_COST)
	return out


## Where its head aims now: straight for the runner (STANDOFF short of them) if they're near with nothing between, else
## the farthest bin of its way (within LOOKAHEAD) it can see clear to; its own spot if it has no way.
func _target(runner: Vector2) -> Vector2:
	var short: Vector2 = _short_of(runner)
	if runner.distance_to(_head) <= STRAIGHT_RANGE and _sight(_head, short):
		return short
	if _path.size() < 2:
		return _head
	var best: Vector2 = _bin_point(_path[1])
	for i: int in range(mini(_path.size() - 1, LOOKAHEAD), 0, -1):
		var point: Vector2 = _bin_point(_path[i])
		if _sight(_head, point):
			best = point
			break
	if _path.size() - 1 <= LOOKAHEAD and _sight(_head, short):
		return short
	return best


## STANDOFF short of `runner` on the line from its head.
func _short_of(runner: Vector2) -> Vector2:
	var to: Vector2 = runner - _head
	if to.length() <= STANDOFF:
		return _head
	return runner - to.normalized() * STANDOFF


func _bin_point(cell: Vector2i) -> Vector2:
	return Vector2(_maze.lane_x(cell.x), _maze.bin_middle(cell.y))


## True if its head can go straight from `a` to `b` without touching debris.
func _sight(a: Vector2, b: Vector2) -> bool:
	var length: float = a.distance_to(b)
	var steps: int = maxi(int(ceil(length / SIGHT_STEP)), 1)
	for i: int in range(1, steps + 1):
		var q: Vector2 = a.lerp(b, float(i) / steps)
		if not _maze.clear_at(q.x, q.y):
			return false
	return true


## Turns its head toward `target` and moves it on (see the header, 3); arrived there, it turns to face `face`.
func _steer(delta: float, target: Vector2, face: Vector2) -> void:
	var to: Vector2 = target - _head
	var want: float = 0.0
	var look: Vector2 = to if to.length() > 0.2 else face - _head
	if look.length() > 0.05:
		var desired: float = atan2(look.x, look.y)
		var turn: float = _t.turn_rate * delta * (BITE_TURN_SHARE if jaw != Jaw.CLOSED else 1.0)
		_heading = wrapf(_heading + clampf(wrapf(desired - _heading, -PI, PI), -turn, turn), -PI, PI)
	if to.length() > 0.2:
		var align: float = cos(wrapf(atan2(to.x, to.y) - _heading, -PI, PI))
		want = _chase_v * clampf(align, _t.turn_slow_share, 1.0)
		# It eases in to stop where it aims.
		want = minf(want, sqrt(2.0 * _t.acceleration * to.length()))
	_speed = move_toward(_speed, want, _t.acceleration * delta)
	_move(Vector2(sin(_heading), cos(_heading)) * _speed * delta)


## Slows to a stop where it is.
func _slow(delta: float) -> void:
	_speed = move_toward(_speed, 0.0, _t.acceleration * delta)
	_move(Vector2(sin(_heading), cos(_heading)) * _speed * delta)


## Moves its head by `step` where the floor is clear, or as much of it along the track or across as is (sliding along
## debris), never more than `step`.
func _move(step: Vector2) -> void:
	if step.length() < 0.00001:
		return
	var options: Array[Vector2] = [_head + step, _head + Vector2(0.0, step.y), _head + Vector2(step.x, 0.0)]
	for q: Vector2 in options:
		if q != _head and _maze.clear_at(q.x, q.y):
			var moved: float = q.distance_to(_head)
			max_step = maxf(max_step, moved)
			_head = q
			_extend_trail()
			_gait += moved
			return
	_speed = minf(_speed, 0.5 * _chase_v)


## Adds the head's new position to its trail, a point every TRAIL_STEP, and drops what's past its tail.
func _extend_trail() -> void:
	var last: Vector2 = _trail[0]
	var gap: float = last.distance_to(_head)
	if gap < TRAIL_STEP:
		return
	var count: int = int(gap / TRAIL_STEP)
	for i: int in range(1, count + 1):
		_trail.insert(0, last.lerp(_head, float(i) * TRAIL_STEP / gap))
	var keep: int = int(ceil(BODY_LENGTH / TRAIL_STEP)) + 4
	if _trail.size() > keep:
		_trail.resize(keep)


# --- The bite -------------------------------------------------------------------------------

func _bite(delta: float, p: Player) -> void:
	_jaw_time += delta
	match jaw:
		Jaw.CLOSED:
			if _bite_coming(p):
				jaw = Jaw.OPENING
				_jaw_time = 0.0
				bites.append([world.level_time(), -1.0])
				_play(&"centipede_bite")
		Jaw.OPENING:
			if _jaw_time >= _t.bite_telegraph:
				jaw = Jaw.STRIKE
				_jaw_time = 0.0
				(bites[-1] as Array)[1] = world.level_time()
				_bite_box.set_enabled(true)
				_play(&"centipede_snap")
		Jaw.STRIKE:
			if _jaw_time >= _t.bite_window:
				_close_jaws()
		Jaw.REST:
			if _jaw_time >= _t.bite_rest:
				jaw = Jaw.CLOSED
				_jaw_time = 0.0


## True if the runner will be within its bite's reach in front of its head by the end of a telegraph begun now: in front,
## within its jaws' width (and their body's), no further than the bite reaches and they close in meanwhile, with no
## debris between.
func _bite_coming(p: Player) -> bool:
	if not p.alive or p.surface != Player.Surface.FLOOR:
		return false
	var dir := Vector2(sin(_heading), cos(_heading))
	var runner := Vector2(p.position.x, p.distance)
	var rel: Vector2 = runner - _head
	var ahead: float = rel.dot(dir)
	var side: float = absf(rel.dot(Vector2(dir.y, -dir.x)))
	var vt: MovementTuning = world.tuning
	if ahead <= 0.0 or side > _t.bite_width * 0.5 + vt.visual_size.x * 0.5 + BITE_SIDE_SLACK:
		return false
	var closing: float = maxf(_speed - p.speed * dir.y, 0.0)
	if ahead > _t.bite_reach(CentipedeMaze.HEAD_HALF_LENGTH) + vt.visual_size.z * 0.5 + closing * _t.bite_telegraph:
		return false
	return _maze == null or _clear_line(_head, runner)


## True if no debris stands on the line from `a` to `b` (track terms; a thin probe, so a runner stopped at a piece's face
## counts as in sight).
func _clear_line(a: Vector2, b: Vector2) -> bool:
	var steps: int = maxi(int(ceil(a.distance_to(b) / BITE_SIGHT_STEP)), 1)
	for i: int in range(1, steps + 1):
		var q: Vector2 = a.lerp(b, float(i) / steps)
		if not _maze.clear_at(q.x, q.y, BITE_SIGHT_HALF, BITE_SIGHT_HALF):
			return false
	return true


## Its jaws snap shut (a contact, the bite's time over, a wound or a stop): its bite goes dead, and its jaws rest.
func _close_jaws() -> void:
	_bite_box.set_enabled(false)
	if jaw == Jaw.REST:
		return
	jaw = Jaw.REST
	_jaw_time = 0.0


## Never a big attack: the Terminal has no other enemy to take turns with. DESIGN-TBD (docs/questions/o3.md 10).
func is_major_attack_active() -> bool:
	return false


## Its bite touched the runner (Hazard.contacted from the Player: armor or the shield took it, or it killed).
func _on_bitten(outcome: int) -> void:
	if outcome == DamageRules.Outcome.IGNORE or outcome == DamageRules.Outcome.WOUND_ENEMY \
			or outcome == DamageRules.Outcome.DEFEAT_ENEMY:
		return
	bite_hits += 1
	var since: float = world.level_time() - float((bites[-1] as Array)[0]) if not bites.is_empty() else -1.0
	bite_contacts.append([world.level_time(), jaw == Jaw.STRIKE, since])
	_close_jaws()


## True while its bite is live (STRIKE).
func bite_live() -> bool:
	return jaw == Jaw.STRIKE and _bite_box.is_active()


# --- Wounds and defeat ---------------------------------------------------------------------

func _on_wounded(_cause: StringName) -> void:
	wounded = true
	_model.set_wounded(true, Settings.flashing_reduced)
	_play(&"centipede_wound")
	world.effects.burst(aim_point(), GLOW, 18, 0.6)
	world.effects.shake(0.18, 0.2)
	_close_jaws()
	var asleep: bool = state == State.SLEEP or state == State.WAKE
	if asleep:
		# The wound wakes it, and it still keeps still for its wake time (the warning) before it moves.
		_model.set_awake(true)
		_play(&"centipede_wake")
	_stun_for = maxf(_t.wound_stun, _t.wake_time if asleep else 0.0)
	_set_state(State.STUN)


func _on_defeated(_cause: StringName) -> void:
	var at: Vector3 = aim_point()
	_play(&"centipede_death")
	world.effects.burst(at, GLOW, 36, 1.2)
	for i: int in range(0, SEGMENTS, 3):
		world.effects.debris(_world_point(_trail_point(SEGMENT_SPACING * (i + 1)), HEAD_HEIGHT),
			CentipedeModel.BRASS, 4, 0.5)
	world.effects.shake(0.3, 0.25)
	queue_free()


func should_retire() -> bool:
	if world == null:
		return false
	var behind: float = world.player.distance - _head.y
	match state:
		State.SLEEP:
			return behind > _t.retire_behind
		State.GIVE_UP:
			return behind > _t.retire_behind or (_state_time > GIVE_UP_LINGER and behind > _t.retire_behind * 0.5)
	return behind > _give_up_d + _t.retire_behind


func track_distance() -> float:
	return _head.y


func aim_point() -> Vector3:
	return _world_head() + Vector3(0.0, 0.2, 0.0)


func hit_radius() -> float:
	return 0.6


## Its head's middle in track terms (x: world x, y: track distance), and its heading (radians; PI toward the runner's
## approach).
func head() -> Vector2:
	return _head


func heading() -> float:
	return _heading


func speed() -> float:
	return _speed


## Its body's points along its trail (track terms), one for each segment, from behind the head to the tail.
func body_points() -> PackedVector2Array:
	var out := PackedVector2Array()
	for i: int in SEGMENTS:
		out.append(_trail_point(SEGMENT_SPACING * (i + 1)))
	return out


## The model (CentipedeModel).
func model() -> CentipedeModel:
	return _model


## Its hitboxes, for tests and tools: its head's and its body's (harmless: only a dash's contact counts, a wound), and
## its bite's (live only while it strikes).
func head_box() -> Hazard:
	return _head_box


func body_boxes() -> Array[Hazard]:
	return _body_boxes


func bite_box() -> Hazard:
	return _bite_box


# --- Placing it -------------------------------------------------------------------------------

func _world_head() -> Vector3:
	return _world_point(_head, HEAD_HEIGHT)


func _world_point(p: Vector2, height: float) -> Vector3:
	return Vector3(p.x, height, TrackGeometry.world_z(p.y))


## The point `arc` metres back along its trail from its head (track terms).
func _trail_point(arc: float) -> Vector2:
	var left: float = arc
	var prev: Vector2 = _head
	for q: Vector2 in _trail:
		var d: float = prev.distance_to(q)
		if d >= left and d > 0.0:
			return prev.lerp(q, left / d)
		left -= d
		prev = q
	return prev


## Where it faces at `arc` along its trail: toward the point a little ahead of it (toward its head), as a world basis
## whose -z looks that way.
func _facing_at(arc: float) -> Basis:
	var ahead: Vector2 = _trail_point(maxf(arc - 0.3, 0.0)) if arc > 0.01 else _head + Vector2(sin(_heading), cos(_heading))
	var here: Vector2 = _trail_point(arc)
	var d: Vector2 = ahead - here
	if d.length() < 0.001:
		d = Vector2(sin(_heading), cos(_heading))
	return Basis.looking_at(Vector3(d.x, 0.0, -d.y).normalized(), Vector3.UP)


func _place(delta: float) -> void:
	global_position = _world_head()
	var face: Basis = Basis.looking_at(Vector3(sin(_heading), 0.0, -cos(_heading)), Vector3.UP)
	var dir := Vector2(sin(_heading), cos(_heading))
	_head_box.global_transform = Transform3D(face, _world_point(_head, HEAD_HIT.y * 0.5 + HEAD_BOX_LIFT))
	for i: int in BODY_BOXES:
		var arc: float = 0.9 + i * (BODY_LENGTH - 1.2) / maxf(BODY_BOXES - 1, 1)
		_body_boxes[i].global_transform = Transform3D(_facing_at(arc), _world_point(_trail_point(arc),
			BODY_HIT.y * 0.5 + BODY_BOX_LIFT))
	var segs: Array[Transform3D] = []
	for i: int in SEGMENTS:
		var arc: float = SEGMENT_SPACING * (i + 1)
		segs.append(Transform3D(_facing_at(arc), _world_point(_trail_point(arc), 0.0)))
	var rear: float = 0.0
	var open: float = 0.0
	var lunge: float = 0.0
	if state == State.CHASE:
		match jaw:
			Jaw.OPENING:
				rear = clampf(_jaw_time / maxf(_t.bite_telegraph, 0.01), 0.0, 1.0)
				open = rear
			Jaw.STRIKE:
				# Still reared, its head darts forward and back as its jaws snap shut.
				var k: float = clampf(_jaw_time / maxf(_t.bite_window, 0.01), 0.0, 1.0)
				rear = 1.0
				open = 1.0 - k
				lunge = _t.lunge_reach * sin(PI * k)
			Jaw.REST:
				# Then its head sinks back down.
				rear = 1.0 - clampf(_jaw_time / maxf(_t.bite_rest * REST_SINK, 0.01), 0.0, 1.0)
	elif state == State.WAKE:
		rear = clampf(_state_time / maxf(_stun_for, 0.01), 0.0, 1.0) * 0.6
	_model.pose(Transform3D(face, _world_point(_head + dir * lunge, 0.0)), segs, _gait, _speed / maxf(_chase_v, 0.01),
		rear, open, delta)
	_place_bite(face, dir)


## Its bite's hitbox for this frame (live only while it strikes; see the header, 4): from its head's front to BITE_INSET
## short of its jaws' tips as the model draws them now (CentipedeModel.jaws_reach, the lunge in it), never further than
## bite_reach, nor shorter than MIN_BITE; bite_height tall, under its reared head.
func _place_bite(face: Basis, dir: Vector2) -> void:
	var front: float = CentipedeMaze.HEAD_HALF_LENGTH
	var tips: float = _model.jaws_reach(_world_point(_head, 0.0), Vector3(dir.x, 0.0, -dir.y))
	var length: float = clampf(tips - BITE_INSET, front + MIN_BITE, _t.bite_reach(front)) - front
	var size := Vector3(_t.bite_width, _t.bite_height, length)
	if not _bite_box.size.is_equal_approx(size):
		_bite_box.size = size
		((_bite_box.get_child(0) as CollisionShape3D).shape as BoxShape3D).size = size
	_bite_box.global_transform = Transform3D(face, _world_point(_head + dir * (front + length * 0.5), _t.bite_height * 0.5))
