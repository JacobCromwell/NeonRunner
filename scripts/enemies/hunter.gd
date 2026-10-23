class_name Hunter
extends Enemy
## The Hunter (GDD §9.17, the owner, October 23, 2026; one of the Ice Lab's two new enemies, from Specimen Vault): "a
## fast-moving lab creation that gets around on a hovering circular platform": a torso grafted into a hover disc, large red
## scimitars on its arms (HunterModel). The owner's words, built as said:
## - "It attacks by coming up alongside the player and slashing rapidly at the player", and "stays on the player's side when
##   it does its slashing attacks, making it difficult for the player to damage it with dashes or with laser attacks".
## - "It does not wait for other big enemies to fire": it never asks the director for a turn and reports no big attack
##   (is_major_attack_active stays false), so it attacks while others do and none waits for it (GDD §9.17, proposed).
## - 25 laser hits (HunterTuning's health: 23, which laser tier 1 stretches to 25, PowerupTuning.tier1_extra_shots).
## - The way to beat it: a falling gantryway the runner drops on it (RunWorld destroys every enemy a walkway comes down on,
##   Gantryway.crushes, with defeat(&"gantryway"): its body reaches from the floor up past its head, hover and all).
## - It follows about as long as the Enforcer Truck (chase_seconds, 25 s), so teleports and ceiling escapes outlast it.
## - It hovers, so it never falls into a gap.
## The rest is GDD §9.17's proposal and task S2's placeholders (DESIGN-TBD, docs/questions/s2.md):
## - Arrival: where its entry's `at` says (the runner's distance; hunter_rules.gd plans it so a falling gantryway comes
##   during its chase), its hover whine rises and it comes up from arrive_gap behind into a lane beside the runner's, its
##   middle alongside_ahead ahead of theirs (its front level with them, on screen, its torso turned back toward them).
## - Alongside it keeps to the side it came up on (`side`): it takes the lane beside the runner's on that side
##   follow_delay_seconds after they change lanes (a log on the level clock), so a runner who steps away leaves it in the
##   lane they just left (the bait: a pillar dashed in their lane, a step away, and the walkway lands on it). It never
##   takes the runner's lane, and its body is safe but solid: a lane blocker bumps a lane change into it back (as the hover
##   truck's sides) and its body's hitbox is harmless (Hazard.harmless): only the blades hurt.
## - It steers: what stands in its lane ahead (a doodad, a gantryway's pillar, a live fence, a teleporter's pad, a ramp, a
##   standing dash wall, another enemy on the floor) it goes round in the lane further out, or, with none, it makes room.
##   Holes, gaps and floor cuts it hovers over.
## - It never takes the runner's way out: where their lane holds what they must leave it for (a doodad, a floor enemy, a
##   walkway falling on it, another enemy's lane attack, a wall-run gap) within make_room_seconds and the lane on their
##   other side isn't open, it makes room: it drops back behind the camera and comes up again once it may (regain_seconds).
## - The flurry: alongside and settled, the runner on the floor with the lane on their other side open to step into until
##   its last cut (the dodge: one lane away, never a jump), its warning (warning_seconds): both blades raised, a steel
##   scrape (hunter_scrape) and a red mark on the runner's lane; then flurry_seconds of quick cuts into that lane (its
##   attack hitbox over the lane, from the floor to over a jump, under any ceiling rider; hunter_slash). One flurry is one
##   hit: armor or the shield takes the first contact and the invulnerability window covers the rest. No flurry in the
##   level's calm start, over a gantryway's run-up and calm stretch (the bait stays clean), a teleporter's calm stretch in
##   the runner's lane or a wall-run gap's crossing. A runner who takes a pad, steps onto a wall or teleports during one
##   calls it off. It holds its lane through a warning and its cuts, then follows.
## - A runner on a ceiling or a wall it waits below, beside their lane, never cutting.
## - A teleport leaves it behind (follows_runner keeps it in play through EnemyDirector.runner_teleported): it catches up
##   from where the jump left it (no further back than catch_up_gap_max), its time running all along.
## - After chase_seconds it gives up whatever it's doing (a flurry is called off), its whine falling (hunter_give_up), and
##   drops back out of play.
## - Immune to the claws and stomps; the dash passes through it and does it no harm; other enemies' charges pass it by
##   (charge_can_hurt). Weapons hurt it, but auto-fire never picks it beside the runner (targetable: the owner's "difficult
##   for the player to damage it with dashes or with laser attacks"), only clearly ahead of them (target_ahead).
## Numbers: HunterTuning (data/enemies/hunter.tres). Its entry's params: {"baits": [{at, lane, side, id}]}: the falling
## gantryways its rules planned in its chase (its pillar's front, its walkway's lane, its pillar's push side, where its
## rules keep the floor clear for a step out). The bait shapes how it rides (task S2's placeholder, DESIGN-TBD): it comes
## up on the runner's far side from the next one's walkway lane, so they reach that lane stepping away from it, where they
## could then step out of it away from it onto open floor, else on the side away from the push (_bait_side); and over a
## bait's run-up (bait_hold_seconds before its pillar) it keeps out of the walkway's lane, one lane further out, so a
## runner it followed past that lane can step back in (_run_up_bait).

enum State { WAITING, APPROACH, ALONGSIDE, YIELD, LEAVING, DEAD }
enum Slash { IDLE, WARNING, FLURRY, RECOVER }

const STATE_NAMES: PackedStringArray = ["waiting", "approach", "alongside", "yield", "leaving", "dead"]
## What a runner its blades cut is told (Hazard.hazard_name).
const SLASH_NAME: String = "Hunter's blades"
## Further behind the runner than this (its middle, metres) it's out of the chase camera's view (MovementTuning's camera
## sits about 7.5 m behind them): it steers by nothing there, and comes into view only into a lane clear ahead.
const VIEW_GAP: float = 7.0
## In the runner's lane it stays at least this far behind them (its middle, metres): it never touches them.
const MIN_GAP_IN_LANE: float = 2.6
## Metres round a floor enemy it keeps clear of (half its body's length and a little).
const ENEMY_ROOM: float = 1.3
## The warning mark's height over the floor, and its width as a share of the lane as the warning starts and at its end.
const MARK_Y: float = 0.035
const MARK_WIDTH_START: float = 0.3
const MARK_WIDTH_END: float = 0.82
## The sweep of its blades through the lane it cuts (task S2's review: what its cuts' box reaches is drawn, a little
## further): seconds before its cuts that it sweeps out (its lunge with it), its pivot's distance in front of its chest
## beyond its lunge (metres toward that lane), and how much further than the box it reaches (metres, and radians at its
## top and bottom edges).
const TRAIL_IN: float = 0.12
const PIVOT_FORWARD: float = 0.3
const SLASH_MARGIN: float = 0.1
const SLASH_ANGLE_PAD: float = 0.08
## The enemy types whose lane attack makes a runner need a lane (_must_make_room): a big attack on (is_major_attack_active)
## of any type but these, whose attacks a jump dodges (the Octodog's lunge).
const JUMPABLE_ATTACKS: Array[StringName] = [&"octodog"]

var tuning: HunterTuning
var state: State = State.WAITING
var slash: Slash = Slash.IDLE
## The lane under its middle, the lane it's heading for, and the side of the runner it rides on (-1 left, 1 right).
var lane: int = 0
var target_lane: int = 0
var side: int = 1
## Its middle's distance behind the runner's (metres; negative: ahead of them).
var gap: float = 0.0
## The lane the current (or last) flurry cuts, locked as its warning starts (-1 before the first).
var slash_lane: int = -1
## Flurries warned so far, and flurries whose cuts came (not called off).
var flurries: int = 0
var flurries_cut: int = 0
## Seconds since it arrived (its chase; it gives up at chase_seconds).
var chase_time: float = 0.0
## What happened, as [event, runner distance, level time] (tests and the showcase read it): arrive, alongside, warn, cut,
## cut_end, called_off, yield, steer, left_behind, give_up, defeat:<cause>.
var history: Array = []
## Every sound it asked for, as [sound, level time] (tests: each warning is heard; silent headless runs ask all the same).
var sounds_played: Array = []
var model: HunterModel

var _x: float = 0.0
var _switch_from: float = 0.0
var _switch_to: float = 0.0
var _switch_t: float = 1.0
## How long the lane change under way takes (switch_seconds, or walkway_switch_seconds following the runner out from
## under a falling walkway).
var _switch_seconds: float = 0.25
## The runner's lane changes, [level time, lane] (their floor lane, or the outer lane under the wall they run on), oldest
## first: it follows the one follow_delay_seconds old.
var _lane_log: Array = []
var _slash_t: float = 0.0
var _next_slash: float = 0.0
var _yield_t: float = 0.0
var _approach_whined: bool = false
var _body: Hazard
var _slash_box: Hazard
var _slash_root: Node3D
var _blocker: Area3D
var _mark: MeshInstance3D
## The sweep of its blades (slash_fan): its mesh, and its shape {x (its pivot from its middle toward the lane it cuts), y
## (its pivot's height), inner, outer, low, high, half_depth}.
var _trail: MeshInstance3D
var _fan: Dictionary = {}
var _blocker_query := PhysicsShapeQueryParameters3D.new()
## The layout's standing pieces by lane, for its steering: [starts (PackedFloat32Array), ends, entries] per lane, sorted
## by start; and the longest one's length (a row of doodads counts whole: LevelLayout.doodad_extent).
var _lane_doodads: Array = []
var _doodad_reach: float = 0.0
var _lane_fences: Array = []
var _run_speed: float = 18.0


## A Hunter's whole look for EnemyDirector.warm_up (which frees it) and ShaderWarmup (task PERF1): its model calm and
## alert (the eyes' and blades' brighter materials on extra nodes), its warning mark and the sweep of its blades. The first
## one builds the meshes and materials every later Hunter shares. No physics object.
static func warm_up(_world: RunWorld, _entry: Dictionary) -> Node:
	var look := HunterModel.new()
	look.name = "HunterWarmUp"
	look.build()
	var m: Dictionary = HunterModel.meshes()
	for part: String in ["eyes", "blade_l"]:
		var alert := MeshInstance3D.new()
		alert.mesh = m[part]
		alert.material_override = HunterModel.eye_material(true) if part == "eyes" else HunterModel.blade_material(true)
		look.add_child(alert)
	var mark := MeshInstance3D.new()
	mark.mesh = GreyboxMaterials.unit_box()
	mark.material_override = HunterModel.mark_material()
	look.add_child(mark)
	var sweep := MeshInstance3D.new()
	sweep.mesh = HunterModel.slash_mesh(0.4, 3.0, -1.2, 1.0, 1.2)
	look.add_child(sweep)
	return look


func _build() -> void:
	tuning = tuning_res as HunterTuning
	if tuning == null:
		tuning = HunterTuning.new()
	display_name = "Hunter"
	# GDD §9.17 (proposed): immune to the claws and stomps; the dash passes through it safely and does it no harm; other
	# enemies' charges pass it by (charge_can_hurt). Weapons hurt it (25 laser hits). It keeps its place by the runner,
	# so a teleport leaves it in play, behind them (runner_teleported).
	claw_immune = true
	stompable = false
	dash_kills = false
	follows_runner = true
	_run_speed = world.tuning.run_speed
	_index_layout()
	model = HunterModel.new()
	model.name = "Model"
	add_child(model)
	model.build()
	model.hover = tuning.hover_height
	model.cuts = tuning.cuts
	var h: Vector3 = tuning.hitbox_size
	_body = add_hitbox(&"body", h, Vector3(0.0, tuning.hover_height + h.y * 0.5, 0.0))
	_body.hazard_name = display_name
	_body.harmless = true
	_body.set_enabled(false)
	# Its solid sides (GDD §9.17, proposed, as the hover truck's, §9.3): a lane change into it is bumped back.
	_blocker = add_lane_blocker(Vector3(world.geo.lane_width * 0.9, tuning.blocker_height, tuning.blocker_length),
		Vector3(0.0, tuning.blocker_height * 0.5, 0.0))
	_set_blocker(false)
	# Its cuts' box: an attack over the lane it cuts, placed each tick where the runner is along the track.
	_slash_root = Node3D.new()
	_slash_root.name = "SlashBox"
	_slash_root.top_level = true
	add_child(_slash_root)
	_slash_box = add_hitbox(&"attack", Vector3.ONE, Vector3.ZERO, true, _slash_root)
	_slash_box.hazard_name = SLASH_NAME
	_slash_box.set_enabled(false)
	_mark = MeshInstance3D.new()
	_mark.name = "WarningMark"
	_mark.mesh = GreyboxMaterials.unit_box()
	_mark.material_override = HunterModel.mark_material()
	_mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mark.top_level = true
	_mark.visible = false
	add_child(_mark)
	_build_trail()
	_blocker_query.collide_with_areas = true
	_blocker_query.collide_with_bodies = false
	_blocker_query.collision_mask = TrackBuilder.LAYER_LANE_BLOCKER
	_blocker_query.shape = BoxShape3D.new()
	if world.player != null:
		world.player.movement_event.connect(_on_player_event)
	lane = clampi(world.player.lane if world.player != null else int(spawn.get("lane", 0)), 0, world.geo.lane_count - 1)
	target_lane = lane
	_x = world.geo.lane_x(lane)
	gap = tuning.arrive_gap
	visible = false
	position = Vector3(_x, -60.0, TrackGeometry.world_z(float(spawn.get("at", 0.0))))


# --- Behaviour ---------------------------------------------------------------------------------------

func _tick(delta: float) -> void:
	match state:
		State.WAITING:
			if world.player_distance() < float(spawn.get("at", 0.0)):
				return
			_arrive()
		State.DEAD:
			return
	var p: Player = world.player
	if not p.alive or not p.running:
		# The runner is down (or paused): it holds where it is by them.
		_place(0.0)
		return
	chase_time += delta
	_log_runner_lane()
	if state != State.LEAVING and chase_time >= tuning.chase_seconds:
		_give_up()
	match state:
		State.APPROACH:
			_approach(delta)
		State.ALONGSIDE:
			_alongside(delta)
		State.YIELD:
			_yield(delta)
		State.LEAVING:
			gap += tuning.leave_speed * delta
	_update_lane(delta)
	_update_slash(delta)
	_place(delta)


## Its hover whine rises and it comes in from arrive_gap behind, on the side it picks.
func _arrive() -> void:
	chase_time = 0.0
	var r: int = runner_lane()
	_lane_log = [[world.level_time() - tuning.follow_delay_seconds, r]]
	visible = true
	_body.set_enabled(true)
	_set_blocker(true)
	gap = tuning.arrive_gap
	side = _pick_side(true)
	if side == 0:
		side = 1 if r < world.geo.lane_count - 1 else -1
	_snap_lane(clampi(r + side, 0, world.geo.lane_count - 1))
	_note(&"arrive")
	_begin_approach()


## It comes up from behind (arriving, again after making room, or catching up after a teleport): its whine rises.
func _begin_approach() -> void:
	state = State.APPROACH
	_approach_whined = false
	_whine()


func _whine() -> void:
	if _approach_whined:
		return
	_approach_whined = true
	_sfx(&"hunter_whine")


## Coming up from behind into the lane beside the runner on its side: out of view it may change lanes at once; it comes
## into view only into a lane clear ahead of it (else it holds back there, trying the other side), and once alongside and
## settled it rides there.
func _approach(delta: float) -> void:
	var n: int = world.geo.lane_count
	var r: int = runner_lane()
	var want: int = r + side
	if want < 0 or want >= n or (gap > VIEW_GAP and not _lane_clear_ahead(want, true)) or _blocks_bait(side, r):
		var s: int = _pick_side(false)
		if s != 0:
			side = s
			want = r + side
	if want < 0 or want >= n or _blocks_bait(side, r):
		# No lane beside the runner to come up into, or only one between them and its bait's walkway lane (it lets them past
		# first, _blocks_bait): it holds back unseen, just behind the camera.
		_ease_gap(maxf(VIEW_GAP + 1.0, minf(gap, tuning.yield_gap)), tuning.approach_speed, delta)
		return
	if gap > VIEW_GAP:
		# Unseen: it lines up at once.
		if lane != want or _switch_t < 1.0:
			_snap_lane(want)
	else:
		_set_target(want)
	var may_close: bool = _lane_clear_ahead(want, true) and not (world.player.surface == Player.Surface.FLOOR
		and _must_make_room())
	var to: float = -tuning.alongside_ahead if may_close else maxf(VIEW_GAP + 0.5, minf(gap, tuning.yield_gap))
	if _crossing_runner():
		# The runner stepped into its lane in front of it, or into the one it's changing to: it keeps behind them (as
		# beside them, _alongside) until its lane change has taken it out of their way, never coming up into their body.
		to = maxf(to, MIN_GAP_IN_LANE)
	_ease_gap(to, tuning.approach_speed, delta)
	if may_close and lane == want and _switch_t >= 1.0 and absf(gap + tuning.alongside_ahead) < 0.35:
		state = State.ALONGSIDE
		_next_slash = maxf(_next_slash, chase_time + tuning.first_slash_seconds)
		_note(&"alongside")


## True if the lane the runner is in or heading for (runner_lane) lies across its solid side's way, where it is or along
## the lane change it's making (the runner's body and its sides reach that far across the track): coming up from behind
## it keeps MIN_GAP_IN_LANE behind them then (_approach).
func _crossing_runner() -> bool:
	if world.player.surface != Player.Surface.FLOOR:
		return false
	var reach: float = (world.geo.lane_width * 0.9 + world.tuning.hurtbox_size.x) * 0.5
	var x: float = world.geo.lane_x(runner_lane())
	return x > minf(_x, _switch_to) - reach and x < maxf(_x, _switch_to) + reach


## Alongside the runner (see the class doc): following their lane changes a moment late on its side, steering round what
## stands in its lane, making room where they need its lane, waiting below a runner on a ceiling or a wall.
func _alongside(delta: float) -> void:
	var p: Player = world.player
	var n: int = world.geo.lane_count
	var r: int = runner_lane()
	var off_floor: bool = p.surface != Player.Surface.FLOOR
	var idle: bool = slash != Slash.WARNING and slash != Slash.FLURRY
	if not off_floor and idle and _blocks_bait(side, r):
		# It rides between the runner and its bait's walkway lane: it drops back out of their way, and comes up on their
		# other side once they're past (_pick_side).
		_start_yield(&"bait")
		return
	var want: int = _follow_lane() + side
	var quick: bool = false
	if off_floor:
		# Waits below, beside their lane, on whichever side has a lane (it may cross under them: they're off the floor).
		want = r + side
		if want < 0 or want >= n:
			side = -side
			want = r + side
	elif slash == Slash.WARNING or slash == Slash.FLURRY:
		# It holds its lane through a warning and its cuts.
		want = target_lane
	if want == r and not off_floor:
		# Never into the runner's lane: it stays where it is (they came across before it followed).
		want = target_lane if target_lane != r else r + side
	if not off_floor and idle:
		var beside: int = r + side
		if beside != want and beside >= 0 and beside < n and _walkway_falling_on(beside, world.player_distance() - gap):
			# The runner has stepped out from under a falling walkway: it follows them at once, quickly, into the lane they
			# left, the walkway's (the bait: whenever they step out and live, it's under the walkway as it lands).
			want = beside
			quick = true
		var run_up: Dictionary = _run_up_bait()
		if not run_up.is_empty() and want == int(run_up["lane"]) and want != r:
			# Over a bait's run-up it keeps out of the walkway's lane (the runner's way to its pillar): one lane further out.
			var further: int = want + signi(want - r)
			if further >= 0 and further < n and _lane_clear_ahead(further, false):
				want = further
	if want < 0 or want >= n:
		_start_yield(&"edge")
		return
	var steer: int = want
	if not _lane_clear_ahead(want, false):
		# Its lane is shut ahead: the lane the runner has just left (when they stepped away from it), at once, rather than a
		# moment later; else the lane further out; else it makes room.
		var left_lane: int = r + side
		var out: int = want + signi(want - r) if want != r else want + side
		if not off_floor and (slash == Slash.IDLE or slash == Slash.RECOVER):
			if left_lane != want and left_lane >= 0 and left_lane < n and left_lane != r and _lane_clear_ahead(left_lane, false):
				out = left_lane
		if out >= 0 and out < n and out != r and _lane_clear_ahead(out, false):
			steer = out
			if target_lane != out:
				_note(&"steer")
		else:
			_start_yield(&"blocked")
			return
	if not off_floor and _must_make_room():
		_start_yield(&"make_room")
		return
	if steer != target_lane and (slash == Slash.WARNING or slash == Slash.FLURRY):
		_call_off_slash()
	_set_target(steer, quick and steer == want)
	var least: float = -INF
	if lane == r and not off_floor:
		least = MIN_GAP_IN_LANE
	_ease_gap(maxf(-tuning.alongside_ahead, least), tuning.approach_speed, delta)


## It makes room (or can't stay beside the runner): it drops back behind the camera, its cuts called off, and comes up again
## once it may.
func _start_yield(why: StringName) -> void:
	state = State.YIELD
	_yield_t = 0.0
	_call_off_slash()
	_note(StringName("yield:" + String(why)))


func _yield(delta: float) -> void:
	_yield_t += delta
	var r: int = runner_lane()
	if gap < VIEW_GAP and not _lane_clear_ahead(lane, false):
		# Its own lane is shut ahead and it can't go round: once it's behind the runner it takes their lane behind them.
		if gap >= tuning.blocker_length * 0.5 + 0.6 and world.player.surface == Player.Surface.FLOOR:
			_set_target(r)
	var least: float = MIN_GAP_IN_LANE if lane == r else -INF
	_ease_gap(maxf(tuning.yield_gap, least), tuning.drop_speed, delta)
	if _yield_t >= tuning.regain_seconds and gap >= VIEW_GAP:
		var s: int = _pick_side(false)
		if s != 0:
			side = s
			_begin_approach()


## It gives up (GDD §9.17: after about as long as the Enforcer Truck, chase_seconds) whatever it's doing: a warning or a
## flurry on is called off, and it drops back out of play, its whine falling.
func _give_up() -> void:
	_call_off_slash()
	state = State.LEAVING
	_set_blocker(false)
	_sfx(&"hunter_give_up")
	_note(&"give_up")


func should_retire() -> bool:
	return state == State.LEAVING and gap >= tuning.gone_gap


## The runner was teleported (task Q4; EnemyDirector.runner_teleported, which keeps it in play: follows_runner). One still
## waiting for the runner whose arrival the jump skipped never comes (the runner skipped it). Otherwise the jump leaves it
## behind (GDD §9.17, proposed): a flurry on is called off, and it catches up from where it was left, no further back than
## catch_up_gap_max, its time running on.
func runner_teleported(from: float, to: float) -> void:
	if state == State.WAITING:
		if to >= float(spawn.get("at", 0.0)):
			retire()
		return
	if state == State.DEAD or state == State.LEAVING:
		gap += to - from
		return
	_call_off_slash()
	gap = clampf(gap + (to - from), tuning.arrive_gap, maxf(tuning.catch_up_gap_max, tuning.arrive_gap))
	_lane_log = [[world.level_time() - tuning.follow_delay_seconds, runner_lane()]]
	_note(&"left_behind")
	_begin_approach()


# --- Lanes ---------------------------------------------------------------------------------------------

## The runner's lane for it: their floor lane (on the floor or a ceiling), or the outer lane under the wall they run on.
func runner_lane() -> int:
	var p: Player = world.player
	var n: int = world.geo.lane_count
	if p.surface == Player.Surface.WALL:
		return 0 if p.wall_side < 0 else n - 1
	return clampi(p.lane, 0, n - 1)


func _log_runner_lane() -> void:
	var l: int = runner_lane()
	if _lane_log.is_empty() or int(_lane_log[-1][1]) != l:
		_lane_log.append([world.level_time(), l])


## The runner's lane follow_delay_seconds ago: the lane beside which it rides.
func _follow_lane() -> int:
	var now: float = world.level_time()
	var want: int = runner_lane()
	var keep: int = 0
	var found: bool = false
	for i: int in _lane_log.size():
		if now - float(_lane_log[i][0]) >= tuning.follow_delay_seconds - 0.0001:
			want = int(_lane_log[i][1])
			keep = i
			found = true
		else:
			break
	if keep > 0:
		_lane_log = _lane_log.slice(keep)
	return want if found else runner_lane()


## Heads for lane `l` over switch_seconds, or walkway_switch_seconds with `quick` (from wherever it is: a switch under way
## turns round).
func _set_target(l: int, quick: bool = false) -> void:
	if l == target_lane:
		return
	target_lane = l
	_switch_from = _x
	_switch_to = world.geo.lane_x(l)
	_switch_t = 0.0
	_switch_seconds = tuning.walkway_switch_seconds if quick else tuning.switch_seconds


## In lane `l` at once (out of view).
func _snap_lane(l: int) -> void:
	target_lane = l
	lane = l
	_x = world.geo.lane_x(l)
	_switch_from = _x
	_switch_to = _x
	_switch_t = 1.0


func _update_lane(delta: float) -> void:
	if _switch_t < 1.0:
		_switch_t = minf(1.0, _switch_t + delta / maxf(_switch_seconds, 0.01))
		_x = lerpf(_switch_from, _switch_to, smoothstep(0.0, 1.0, _switch_t))
	lane = world.geo.lane_at(_x)


## Eases its gap toward `want`, at most `top` metres a second.
func _ease_gap(want: float, top: float, delta: float) -> void:
	var eased: float = want + (gap - want) * exp(-tuning.gap_rate * delta)
	var step: float = top * delta
	gap = clampf(eased, gap - step, gap + step)


## The side it comes up on beside the runner (-1 left, 1 right; 0: none has room now): one whose lane is on the track and
## clear ahead (where it comes into view) and doesn't stand between them and the next planned bait's walkway lane
## (_blocks_bait), the side that bait asks for first where it comes in its chase (_bait_side: the runner can reach the
## walkway's lane stepping away from it, then step out from under the walkway away from it), else the side toward the
## nearer edge (the runner keeps the most lanes on their other side), else seeded. `arriving`: it's far behind (its lane's
## clearness counts where it will come into view).
func _pick_side(arriving: bool) -> int:
	var n: int = world.geo.lane_count
	var r: int = runner_lane()
	var options: Array[int] = []
	for s: int in [-1, 1]:
		var l: int = r + s
		if l >= 0 and l < n and (arriving or _lane_clear_ahead(l, true)) and not _blocks_bait(s, r):
			options.append(s)
	if options.is_empty():
		return 0
	if options.size() == 1:
		return options[0]
	var bait: Dictionary = _next_bait()
	if not bait.is_empty():
		var wanted: int = _bait_side(bait, r)
		if options.has(wanted):
			return wanted
	var room_left: int = r
	var room_right: int = n - 1 - r
	if room_left != room_right:
		# Toward the nearer edge: the runner's far side is the one with more lanes.
		return -1 if room_left < room_right else 1
	return options[rng.randi_range(0, 1)]


## The side of a runner in lane `r` it rides on for bait `b` (its walkway's lane and its pillar's push side, `side`): their
## far side from the walkway's lane, so they reach that lane stepping away from it, where they'd then step out of it away
## from it onto open floor: the push side (its rules' bait, kept clear for the push) or the other side where that's open
## (_out_open). Else, and with the runner in the walkway's lane, the side away from the push (its rules' bait).
func _bait_side(b: Dictionary, r: int) -> int:
	var l: int = int(b.get("lane", -1))
	var s: int = int(b.get("side", 0))
	if r == l or s == 0:
		return -s
	var far: int = signi(r - l)
	if -far == s or _out_open(b, -far):
		return far
	return -s


## True if riding on side `s` of a runner in lane `r` would stand between them and the next planned bait's walkway lane
## (two lanes or more from them on that side, so they can't reach it stepping away from it) while that bait can still be
## lined up: its pillar further ahead than its run-up (bait_hold_seconds of run), and the runner then able to step out of
## the walkway's lane on that side (away from it, once it has come up on their other side): the push side, or the other
## where it's open (_out_open). It lets them past first (task S2's review: _approach holds back, _alongside drops back).
func _blocks_bait(s: int, r: int) -> bool:
	if s == 0:
		return false
	var b: Dictionary = _next_bait()
	if b.is_empty() or (int(b.get("lane", r)) - r) * s < 2:
		return false
	var v: float = maxf(world.player.speed, _run_speed)
	if float(b.get("at", -INF)) - world.player_distance() < tuning.bait_hold_seconds * v:
		return false
	return s == int(b.get("side", 0)) or _out_open(b, s)


## True if a runner who dashes bait `b`'s pillar can step out of its walkway's lane to side `out` onto open floor until
## its calm stretch is over (no hole, floor cut, doodad, live fence, floor enemy, planned or in play, or solid side there:
## lane_open), with a lane on the walkway's other side for it to ride in meanwhile.
func _out_open(b: Dictionary, out: int) -> bool:
	var n: int = world.geo.lane_count
	var l: int = int(b.get("lane", -1))
	var lane: int = l + out
	var g: Dictionary = world.layout.gantryway_by_id(int(b.get("id", -1)))
	if g.is_empty() or lane < 0 or lane >= n or l - out < 0 or l - out >= n:
		return false
	var from: float = float(g["pillar"]) - 1.0
	var to: float = float((g.get("calm", [from, from]) as Array)[1])
	if not lane_open(lane, from, to, true):
		return false
	for e: Dictionary in world.layout.enemies:
		var at: float = float(e.get("at", -INF))
		if int(e.get("lane", -1)) == lane and at >= from - 3.0 and at <= to + 3.0 and LevelGenerator.enemy_uses_floor(e):
			return false
	return true


## The bait whose run-up the runner is in (its pillar within bait_hold_seconds of run ahead of them), or {}.
func _run_up_bait() -> Dictionary:
	var d: float = world.player_distance()
	var v: float = maxf(world.player.speed, _run_speed)
	for b: Variant in (spawn.get("params", {}) as Dictionary).get("baits", []):
		if b is Dictionary:
			var at: float = float((b as Dictionary).get("at", -INF))
			if at > d and at - tuning.bait_hold_seconds * v <= d:
				return b
	return {}


## The next bait its rules planned (params "baits") that the runner hasn't passed and could reach in its chase, or {}.
func _next_bait() -> Dictionary:
	var baits: Array = (spawn.get("params", {}) as Dictionary).get("baits", [])
	var d: float = world.player_distance()
	var v: float = maxf(world.player.speed, _run_speed)
	var left: float = maxf(tuning.chase_seconds - chase_time, 0.0) * v
	for b: Variant in baits:
		if not (b is Dictionary):
			continue
		var at: float = float((b as Dictionary).get("at", -INF))
		if at > d and at <= d + left:
			return b
	return {}


# --- What stands in a lane --------------------------------------------------------------------------------

## The layout's doodads and fences by lane, sorted (its steering reads them each tick).
func _index_layout() -> void:
	var n: int = world.geo.lane_count
	_lane_doodads.clear()
	_lane_fences.clear()
	_doodad_reach = 0.0
	for l: int in n:
		var spans: Array = []
		for d: Dictionary in world.layout.doodads:
			if int(d["lane"]) == l:
				var s: Vector2 = LevelLayout.doodad_extent(d)
				spans.append([s.x, s.y, d])
				_doodad_reach = maxf(_doodad_reach, s.y - s.x)
		spans.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
		var starts := PackedFloat32Array()
		var ends := PackedFloat32Array()
		var entries: Array = []
		for s: Array in spans:
			starts.append(float(s[0]))
			ends.append(float(s[1]))
			entries.append(s[2])
		_lane_doodads.append([starts, ends, entries])
		var fences: Array = []
		for f: Dictionary in world.layout.fences:
			if int(f["lane"]) == l:
				fences.append(f)
		fences.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["at"]) < float(b["at"]))
		_lane_fences.append(fences)


## True if its body can ride lane `l` from its rear to steer_ahead_seconds past its front (at the runner's speed): no
## standing doodad (a gantryway's pillar, a jar, a row: doodad_extent), live fence, teleporter's pad, ramp, standing dash
## wall, nor another enemy on the floor there. With `to_runner`, from where it is up to the runner's front and on (as it
## comes into view from behind). It hovers over holes, gaps and floor cuts. A floor enemy under a walkway falling on that
## lane doesn't count: the walkway is about to crush it.
func _lane_clear_ahead(l: int, to_runner: bool) -> bool:
	var n: int = world.geo.lane_count
	if l < 0 or l >= n:
		return false
	var d: float = world.player_distance()
	var v: float = maxf(world.player.speed, 1.0)
	var mid: float = d - gap
	var from: float = mid - tuning.blocker_length * 0.5 - 0.5
	var to: float = maxf(mid, d if to_runner else mid) + tuning.blocker_length * 0.5 + tuning.steer_ahead_seconds * v
	if to_runner:
		from = maxf(from, d - VIEW_GAP)
	return not blocked_in(l, from, to)


## True if something its body must go round stands in lane `l` between track distances `from` and `to` (see
## _lane_clear_ahead).
func blocked_in(l: int, from: float, to: float) -> bool:
	if _doodad_in(l, from, to):
		return true
	var half: float = world.tuning.fence_depth * 0.5 + 0.4
	for f: Dictionary in _lane_fences[l]:
		var at: float = float(f["at"])
		if at - half > to:
			break
		if at + half >= from and not bool(f.get("disabled", false)):
			return true
	var lay: LevelLayout = world.layout
	for tp: Dictionary in lay.teleporters:
		if int(tp["lane"]) == l and float(tp["at"]) - 0.5 <= to and float(tp["end"]) + 0.5 >= from:
			return true
	for r: Dictionary in lay.ramps:
		var at: float = float(r["at"])
		if lay.outer_lane(int(r["side"])) == l and at <= to and at + world.tuning.ramp_length >= from:
			return true
	for w: Dictionary in lay.dash_walls:
		if not bool(w.get("smashed", false)) and float(w["start"]) <= to and float(w["end"]) >= from:
			return true
	return _floor_enemy_in(l, from - ENEMY_ROOM, to + ENEMY_ROOM, true)


## A standing doodad in lane `l` reaching into [from, to].
func _doodad_in(l: int, from: float, to: float) -> bool:
	var spans: Array = _lane_doodads[l]
	var starts: PackedFloat32Array = spans[0]
	var ends: PackedFloat32Array = spans[1]
	var entries: Array = spans[2]
	var i: int = starts.bsearch(to, false) - 1
	while i >= 0 and starts[i] >= from - _doodad_reach - 0.01:
		if ends[i] >= from and not bool((entries[i] as Dictionary).get("smashed", false)):
			return true
		i -= 1
	return false


## A floor enemy in play (or a hover truck holding its lane) in lane `l` between `from` and `to`. With
## `skip_crushed`, one under a walkway falling on that lane doesn't count.
func _floor_enemy_in(l: int, from: float, to: float, skip_crushed: bool) -> bool:
	for e: Enemy in world.director.active:
		if not is_instance_valid(e) or not e.alive or e == self:
			continue
		var at: float = e.track_distance()
		if at < from or at > to:
			continue
		if e.type_id == &"hover_truck":
			if int(e.get(&"lane")) == l:
				return true
			continue
		if not LevelGenerator.enemy_uses_floor({"type": String(e.type_id)}):
			continue
		if world.geo.lane_at(e.global_position.x) != l:
			continue
		if skip_crushed and _walkway_falling_on(l, at):
			continue
		return true
	return false


## True if a falling gantryway (fallen, not landed yet) is coming down on lane `l` over track distance `at`.
func _walkway_falling_on(l: int, at: float) -> bool:
	for g: Dictionary in world.layout.gantryways:
		if int(g["lane"]) == l and bool(g.get("fallen", false)) and not bool(g.get("landed", false)) \
				and at >= float(g["start"]) - 1.0 and at <= float(g["end"]) + 1.0:
			return true
	return false


## True if the runner needs the lane it rides now (see the class doc): their lane holds what they must leave it for within
## make_room_seconds (a standing doodad or pillar, a floor enemy, a walkway falling on it, another enemy's lane attack on),
## and the lane on their other side isn't open where they'd step into it; or a wall-run gap's crossing is in reach.
func _must_make_room() -> bool:
	var p: Player = world.player
	var n: int = world.geo.lane_count
	var r: int = runner_lane()
	var v: float = maxf(p.speed, _run_speed)
	var from: float = p.distance
	var to: float = p.distance + tuning.make_room_seconds * v
	if world.layout.wall_run_between(from - 1.0, to):
		return true
	var need: Vector2 = _needs_leaving(r, from, to, v)
	if need.y < need.x:
		return false
	var f: int = r - side
	return f < 0 or f >= n or not lane_open(f, need.x, need.y, false)


## Where the runner needs a lane beside theirs (`r`) between `from` and `to` (Vector2(from, to) of that lane; empty, x > y,
## where they need none): round the first standing doodad in their lane (a pillar too: without the dash it pushes them
## aside) or floor enemy ahead of them, from a lane switch and a push before it; from now while a walkway falls on them or
## another enemy's lane attack is on (a big attack a jump doesn't dodge).
func _needs_leaving(r: int, from: float, to: float, v: float) -> Vector2:
	var out := Vector2(INF, -INF)
	var lead: float = (world.tuning.doodad_push_time + world.tuning.lane_switch_time) * v + 1.0
	var at: float = _first_doodad_in(r, from, to)
	if at < INF:
		out = Vector2(maxf(from, at - lead), at + 2.0)
	if _small_attack_on(r):
		# A small attack at them too (task S2's review: its body must never take away a dodge from any other attack).
		out = Vector2(from, maxf(out.y, to))
	for e: Enemy in world.director.active:
		if not is_instance_valid(e) or not e.alive or e == self:
			continue
		if not JUMPABLE_ATTACKS.has(e.type_id) and e.is_major_attack_active():
			out = Vector2(from, maxf(out.y, to))
			continue
		var d: float = e.track_distance()
		if d < from or d > to or not LevelGenerator.enemy_uses_floor({"type": String(e.type_id)}) \
				or world.geo.lane_at(e.global_position.x) != r:
			continue
		out = Vector2(minf(out.x, maxf(from, d - lead)), maxf(out.y, d + ENEMY_ROOM))
	for g: Dictionary in world.layout.gantryways:
		if int(g["lane"]) == r and bool(g.get("fallen", false)) and not bool(g.get("landed", false)) \
				and from >= float(g["start"]) - 2.0 and from <= float(g["end"]) + 1.0:
			out = Vector2(from, maxf(out.y, from + lead))
	return out


## True if a small attack is on at a runner in lane `r` that they may dodge one lane over (task S2's review): a cyborg-type
## gun (CyborgGun: a floor or window cyborg's, or any enemy's built on it, as a `gun`) charging or firing at them, or an
## enemy's shot on its way to their lane within make_room_seconds.
func _small_attack_on(r: int) -> bool:
	for e: Enemy in world.director.active:
		if not is_instance_valid(e) or not e.alive or e == self:
			continue
		var g: Variant = e.get(&"gun")
		if g is CyborgGun and (g as CyborgGun).is_attacking():
			return true
	var p: Player = world.player
	var v: float = maxf(p.speed, _run_speed)
	var x: float = world.geo.lane_x(r)
	for shot: Projectile in world.projectiles.live_shots():
		if shot.friendly or not shot.in_use:
			continue
		# How long until it's level with the runner (it flies at them as they run on), and where across the track then.
		var ahead: float = p.position.z - shot.position.z
		var closing: float = shot.velocity.z + v
		if ahead < -1.0 or closing <= 0.1:
			continue
		var t: float = maxf(ahead, 0.0) / closing
		if t <= tuning.make_room_seconds and absf(shot.position.x + shot.velocity.x * t - x) <= world.geo.lane_width * 0.5 + 0.3:
			return true
	return false


## The front of the first standing doodad in lane `l` reaching into [from, to] (INF: none).
func _first_doodad_in(l: int, from: float, to: float) -> float:
	var spans: Array = _lane_doodads[l]
	var starts: PackedFloat32Array = spans[0]
	var ends: PackedFloat32Array = spans[1]
	var entries: Array = spans[2]
	var first: float = INF
	var i: int = starts.bsearch(to, false) - 1
	while i >= 0 and starts[i] >= from - _doodad_reach - 0.01:
		if ends[i] >= from and not bool((entries[i] as Dictionary).get("smashed", false)):
			first = minf(first, maxf(starts[i], from))
		i -= 1
	return first


## True if a runner can step into lane `l` and stay there from track distance `from` to `to`: no hole, live fence, floor
## cut, doodad, floor enemy, solid side (a hover truck's, another's lane blocker) or trap pad (one lifting them onto a
## fenced ceiling's fence: _trap_pad_in). With `strict` (a flurry's escape) a doodad's or a calm stretch's stretch counts
## whether or not it's smashed (LevelLayout.doodad_between: the same on every attempt); without, only what stands.
func lane_open(l: int, from: float, to: float, strict: bool) -> bool:
	var lay: LevelLayout = world.layout
	if lay.gapped_between(l, from, to) or lay.cut_between(from, to, l) or _trap_pad_in(l, from, to):
		return false
	if strict:
		if lay.doodad_between(from, to, l):
			return false
	elif _doodad_in(l, from, to):
		return false
	var half: float = world.tuning.fence_depth * 0.5 + 0.5
	for f: Dictionary in _lane_fences[l]:
		var at: float = float(f["at"])
		if at - half > to:
			break
		if at + half >= from and not bool(f.get("disabled", false)):
			return false
	if _floor_enemy_in(l, from - 3.0, to + 3.0, false):
		return false
	return not _solid_side_in(l, from, to)


## True if a pad in lane `l` from `from` to `to` lifts a runner onto a fenced ceiling's fence (task S2's review): a fenced
## ceiling's trap pad (its "fenced" mark "unsafe", fenced_ceiling_rules.gd), or any pad under a ceiling with a fence in
## that lane before its end.
func _trap_pad_in(l: int, from: float, to: float) -> bool:
	var lay: LevelLayout = world.layout
	for pad: Dictionary in lay.pads:
		var at: float = float(pad.get("at", -INF))
		if int(pad.get("lane", -1)) != l or at + world.tuning.pad_length < from or at > to:
			continue
		if String(pad.get("fenced", "")) == "unsafe":
			return true
		var h: Dictionary = lay.hull_at(at + world.tuning.pad_length, l)
		if h.is_empty():
			continue
		for cf: Dictionary in lay.ceiling_fences:
			if int(cf.get("lane", -1)) == l and float(cf.get("at", -INF)) >= at and float(cf.get("at", INF)) <= float(h["end"]):
				return true
	return false


## A lane blocker (another's solid side) in lane `l` between `from` and `to`, its own left out.
func _solid_side_in(l: int, from: float, to: float) -> bool:
	if not is_inside_tree():
		return false
	(_blocker_query.shape as BoxShape3D).size = Vector3(world.geo.lane_width * 0.5, 1.0, maxf(to - from, 0.1))
	_blocker_query.transform = Transform3D(Basis.IDENTITY, Vector3(world.geo.lane_x(l), 0.6,
		TrackGeometry.world_z((from + to) * 0.5)))
	_blocker_query.exclude = [_blocker.get_rid()]
	return not get_world_3d().direct_space_state.intersect_shape(_blocker_query, 1).is_empty()


# --- The flurry ----------------------------------------------------------------------------------------

func _update_slash(delta: float) -> void:
	match slash:
		Slash.IDLE:
			if state == State.ALONGSIDE and chase_time >= _next_slash and may_slash():
				_warn()
		Slash.WARNING:
			_slash_t += delta
			if _runner_gone_from_floor():
				_call_off_slash()
			elif _slash_t >= tuning.warning_seconds:
				_cut()
		Slash.FLURRY:
			_slash_t += delta
			if _runner_gone_from_floor():
				_call_off_slash()
			elif _slash_t >= tuning.flurry_seconds:
				_end_flurry()
			else:
				_place_slash_box()
		Slash.RECOVER:
			_slash_t += delta
			if _slash_t >= tuning.recover_seconds:
				slash = Slash.IDLE
	_update_mark()
	_update_trail()


## True if a flurry may begin now (the class doc): alongside and settled beside the runner, on the floor in their lane's
## middle, with the lane on their other side open to step into from escape_reaction_seconds after its warning to its last
## cut (lane_open: a trap pad there too); not in the level's calm start, a gantryway's run-up or calm stretch, a
## teleporter's calm stretch in their lane, a wall-run gap's crossing or a fenced ceiling's pick (where they read which pad
## is the trap: LevelLayout.fenced_pick_between, as a heli drone's barrage); not while another enemy's small attack is on
## at them (_small_attack_on); never one whose dodge would take them two lanes or more past the next bait's walkway lane;
## and over before it gives up.
func may_slash() -> bool:
	var p: Player = world.player
	if not p.alive or not p.running or p.surface != Player.Surface.FLOOR or p.in_pit:
		return false
	var n: int = world.geo.lane_count
	var r: int = runner_lane()
	if lane != r + side or target_lane != lane or _switch_t < 1.0 or absf(gap + tuning.alongside_ahead) > 0.4:
		return false
	if absf(p.position.x - world.geo.lane_x(r)) > 0.15:
		return false
	var f: int = r - side
	if f < 0 or f >= n:
		return false
	if chase_time + tuning.attack_seconds() > tuning.chase_seconds:
		return false
	if world.config != null and p.distance < world.config.start_clear_distance:
		return false
	# Once a bait is planned in its chase, a flurry never carries the runner two lanes or more past its walkway's lane: it
	# would follow and ride between them and it (task S2's review).
	var bait: Dictionary = _next_bait()
	if not bait.is_empty() and (f - int(bait.get("lane", f))) * -side >= 2:
		return false
	var v: float = maxf(p.speed, 1.0)
	var to: float = p.distance + tuning.attack_seconds() * v + 2.0
	if _bait_near(p.distance - 1.0, to) or world.layout.teleporter_between(p.distance - 1.0, to, r) \
			or world.layout.wall_run_between(p.distance - 1.0, to) or world.layout.fenced_pick_between(p.distance - 1.0, to):
		return false
	# Not while another enemy's small attack is on at them (a cyborg's burst: its dodge and the flurry's are one move).
	if _small_attack_on(r) or _small_attack_on(f):
		return false
	return lane_open(f, p.distance + tuning.escape_reaction_seconds * v, to, true)


## True if a gantryway's run-up (bait_hold_seconds of run before its pillar) or its calm stretch, in any lane, reaches
## into [from, to]: the bait stays clean (no flurry while the runner lines it up or steps out from under it).
func _bait_near(from: float, to: float) -> bool:
	var v: float = maxf(world.player.speed, _run_speed)
	for g: Dictionary in world.layout.gantryways:
		var calm: Array = g.get("calm", [g["pillar"], g["pillar"]])
		if float(g["pillar"]) - tuning.bait_hold_seconds * v <= to and float(calm[1]) >= from:
			return true
	return false


## The warning: both blades up, the steel scrape, the red mark on the runner's lane (locked: the lane its cuts will reach).
func _warn() -> void:
	slash = Slash.WARNING
	_slash_t = 0.0
	flurries += 1
	slash_lane = runner_lane()
	_next_slash = chase_time + tuning.slash_interval(rng)
	_mark.visible = true
	_sfx_at(&"hunter_scrape")
	_note(&"warn")


## The cuts: its blades live over the locked lane for flurry_seconds.
func _cut() -> void:
	slash = Slash.FLURRY
	_slash_t = 0.0
	flurries_cut += 1
	var geo: TrackGeometry = world.geo
	var half: float = geo.lane_width * 0.5 - tuning.side_margin
	var box := Vector3(half * 2.0, tuning.slash_height, tuning.slash_depth)
	_slash_box.size = box
	((_slash_box.get_child(0) as CollisionShape3D).shape as BoxShape3D).size = box
	_place_slash_box()
	_slash_box.set_enabled(true)
	_sfx_at(&"hunter_slash")
	_note(&"cut")


func _end_flurry() -> void:
	_slash_box.set_enabled(false)
	slash = Slash.RECOVER
	_slash_t = 0.0
	_note(&"cut_end")


## A warning or a flurry on is called off (the runner left the floor or teleported; it makes room, steers or gives up):
## its blades go down, its mark and its sweep go.
func _call_off_slash() -> void:
	if slash != Slash.WARNING and slash != Slash.FLURRY:
		return
	_slash_box.set_enabled(false)
	slash = Slash.RECOVER
	_slash_t = 0.0
	_mark.visible = false
	_trail.visible = false
	_note(&"called_off")


func _runner_gone_from_floor() -> bool:
	var p: Player = world.player
	return p.surface != Player.Surface.FLOOR or p.in_pit or not p.alive


## Its cuts' box over the locked lane, where the runner is along the track.
func _place_slash_box() -> void:
	var p: Player = world.player
	_slash_root.global_transform = Transform3D(Basis.IDENTITY, Vector3(world.geo.lane_x(slash_lane),
		tuning.slash_height * 0.5, TrackGeometry.world_z(p.distance)))


## The sweep of its blades through the lane it cuts (task S2's review, CLAUDE.md principle 4: its cuts' box reaches no
## further than what's drawn): a red see-through fan (HunterModel.slash_mesh) round a pivot PIVOT_FORWARD in front of its
## chest as it lunges (HunterModel.LUNGE) at its shoulders' height, from its cuts' box's near edge at the top of the box to
## its near edge at the floor, out to past the box's far corners, two sheets each side of the runner along the track, the
## whole box inside it with SLASH_MARGIN (and SLASH_ANGLE_PAD) to spare. Built once for the lane width.
func _build_trail() -> void:
	var lw: float = world.geo.lane_width
	var half: float = lw * 0.5 - tuning.side_margin
	var pivot_x: float = HunterModel.LUNGE + PIVOT_FORWARD
	var near: float = lw - half - pivot_x
	var far: float = lw + half - pivot_x
	var sy: float = tuning.hover_height + HunterModel.WAIST_Y + HunterModel.SHOULDER.y
	var top: float = tuning.slash_height
	_fan = {
		"x": pivot_x,
		"y": sy,
		"inner": clampf(near - 0.25, 0.05, 0.4),
		"outer": Vector2(far, maxf(sy, top - sy)).length() + SLASH_MARGIN,
		"low": atan2(-sy, near) - SLASH_ANGLE_PAD,
		"high": atan2(top - sy, near) + SLASH_ANGLE_PAD,
		"half_depth": tuning.slash_depth * 0.5 + SLASH_MARGIN,
	}
	_trail = MeshInstance3D.new()
	_trail.name = "SlashSweep"
	_trail.mesh = HunterModel.slash_mesh(float(_fan["inner"]), float(_fan["outer"]), float(_fan["low"]), float(_fan["high"]),
		float(_fan["half_depth"]))
	_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_trail.top_level = true
	_trail.visible = false
	add_child(_trail)


## How far its sweep and lunge are out (0-1): sweeping out over the warning's last TRAIL_IN, out through the cuts.
func _sweep_share() -> float:
	match slash:
		Slash.WARNING:
			return clampf((_slash_t - (tuning.warning_seconds - TRAIL_IN)) / TRAIL_IN, 0.0, 1.0)
		Slash.FLURRY:
			return 1.0
	return 0.0


## Shows the sweep (see _build_trail) where its cuts' box is: growing out over the warning's last TRAIL_IN, whole through
## the cuts (its box live only then), gone once they end or are called off. Steady: no pulse, no flicker (one sweep a
## flurry), so Reduced flashing leaves it as it is.
func _update_trail() -> void:
	var k: float = _sweep_share()
	_trail.visible = k > 0.0 and slash_lane >= 0
	if not _trail.visible:
		return
	var dir: float = signf(world.geo.lane_x(slash_lane) - _x)
	if dir == 0.0:
		dir = float(-side)
	var pivot := Vector3(_x + dir * float(_fan["x"]), float(_fan["y"]), TrackGeometry.world_z(world.player_distance()))
	_trail.global_transform = Transform3D(Basis.from_scale(Vector3(dir * k, k, 1.0)), pivot)


## The sweep its cuts' box lies in while it shows (tests): {pivot (world), dir (-1, 1: across toward the lane it cuts),
## share (how far out, 0-1), inner, outer, low, high (radians from across, up positive), half_depth}; {} while it shows
## none.
func slash_fan() -> Dictionary:
	if _trail == null or not _trail.visible:
		return {}
	var out: Dictionary = _fan.duplicate()
	var b: Basis = _trail.global_transform.basis
	out["pivot"] = _trail.global_position
	out["dir"] = signf(b.x.x)
	out["share"] = absf(b.x.x)
	return out


func slash_trail() -> MeshInstance3D:
	return _trail


## The red mark on the locked lane through a warning and its cuts: from mark_behind behind the runner to mark_ahead ahead,
## widening over the warning and pulsing (only widening with Reduced flashing).
func _update_mark() -> void:
	if slash != Slash.WARNING and slash != Slash.FLURRY:
		_mark.visible = false
		return
	_mark.visible = true
	var k: float = 1.0 if slash == Slash.FLURRY else clampf(_slash_t / maxf(tuning.warning_seconds, 0.05), 0.0, 1.0)
	var beat: float = 1.0 if Settings.flashing_reduced else 0.9 + 0.12 * sin(world.level_time() * 28.0)
	var width: float = world.geo.lane_width * lerpf(MARK_WIDTH_START, MARK_WIDTH_END, k) * beat
	var pd: float = world.player_distance()
	var from: float = pd - tuning.mark_behind
	var to: float = pd + tuning.mark_ahead
	_mark.global_transform = Transform3D(Basis.from_scale(Vector3(width, 0.04, to - from)),
		Vector3(world.geo.lane_x(slash_lane), MARK_Y, TrackGeometry.world_z((from + to) * 0.5)))


## The runner's events: a pad taken (they're off the floor this very step: a warning or a flurry on is called off before the
## hazard check, so a dodge onto a ceiling is never cut).
func _on_player_event(kind: StringName) -> void:
	if not alive:
		return
	if kind == &"pad" or kind == &"teleport":
		_call_off_slash()


# --- Declared properties ----------------------------------------------------------------------------

## GDD §9.17 (the owner): it doesn't wait for the other big enemies, and (proposed) nor do they wait for it: its flurries
## are no big attack for the director's turns.
func is_major_attack_active() -> bool:
	return false


## GDD §9.17 (proposed): other enemies' charges pass it by (an Octodog's lunge, a Buzz Overdrive's charge), though weapons
## hurt it.
func charge_can_hurt() -> bool:
	return false


## Auto-fire may pick it (the laser and the missiles alike: EnemyDirector.targets_ahead) only while it's seen and clearly
## ahead of the runner, its middle target_ahead or more in front of theirs (GDD §9.17, the owner: staying at their side
## makes it "difficult for the player to damage it with dashes or with laser attacks"): never while it rides alongside,
## comes up from behind, drops back or waits unseen. A shot meant for something else still hits it on the way
## (ProjectilePool hits whatever a shot passes through), and its health stays 25 laser tier 1 shots.
func targetable() -> bool:
	return super.targetable() and visible and gap <= -tuning.target_ahead


## True while its cuts' box is live.
func is_cutting() -> bool:
	return slash == Slash.FLURRY


## True from a warning's start to its last cut.
func is_attacking() -> bool:
	return slash == Slash.WARNING or slash == Slash.FLURRY


func body_hitbox() -> Hazard:
	return _body


func slash_hitbox() -> Hazard:
	return _slash_box


## True while its solid sides are on.
func blocking() -> bool:
	return _blocker != null and _blocker.collision_layer != 0


func _set_blocker(on: bool) -> void:
	if _blocker != null:
		_blocker.collision_layer = TrackBuilder.LAYER_LANE_BLOCKER if on else 0


## Where weapons aim and effects appear: its chest.
func aim_point() -> Vector3:
	return global_position + Vector3(0.0, tuning.hover_height + 1.0, 0.0)


func hit_radius() -> float:
	return 0.85


## Destroyed (a walkway came down on it, weapons): its blades and solid sides go at once; it breaks up in sparks, debris
## and a small fireball where it was (GDD §11: every explosion is one), with its death's crunch and failing whine.
func _on_defeated(cause: StringName) -> void:
	state = State.DEAD
	_slash_box.set_enabled(false)
	_set_blocker(false)
	_mark.visible = false
	_trail.visible = false
	_note(StringName("defeat:" + String(cause)))
	var at: Vector3 = aim_point()
	_sfx_at(&"hunter_death")
	world.effects.burst(at, Color(1.0, 0.45, 0.15), 28, 0.9)
	world.effects.debris(at, Color(0.3, 0.31, 0.34), 10, 0.9)
	world.effects.fireball(global_position + Vector3(0.0, tuning.hover_height + 0.3, 0.0), 1.3, false, 1.2, 0.8)
	world.effects.shake(0.18, 0.2)
	queue_free()


# --- Presentation ----------------------------------------------------------------------------------------

## Its place by the runner and its pose: its torso turned toward the runner, its blades raised through a warning and
## chopping through a flurry, its disc rolling into a lane change.
func _place(delta: float) -> void:
	var p: Player = world.player
	position = Vector3(_x, 0.0, TrackGeometry.world_z(world.player_distance() - gap))
	if model == null:
		return
	var yaw: float = 0.0
	if state == State.ALONGSIDE or (state == State.APPROACH and gap < VIEW_GAP):
		var dx: float = p.position.x - _x
		var dz: float = p.position.z - position.z
		yaw = atan2(-dx, -dz)
	model.face_yaw = lerp_angle(model.face_yaw, yaw, 1.0 - exp(-10.0 * delta))
	var raise: float = 0.0
	var lean: float = 0.0
	var cut: float = -1.0
	match slash:
		Slash.WARNING:
			raise = smoothstep(0.0, 0.5, _slash_t / maxf(tuning.warning_seconds, 0.05))
			lean = 0.08
		Slash.FLURRY:
			raise = 1.0
			cut = clampf(_slash_t / maxf(tuning.flurry_seconds, 0.05), 0.0, 1.0)
			lean = 0.32
		Slash.RECOVER:
			raise = 1.0 - clampf(_slash_t / maxf(tuning.recover_seconds, 0.05), 0.0, 1.0)
	model.raise = raise
	model.cut = cut
	model.lean = lerpf(model.lean, lean, 1.0 - exp(-12.0 * delta))
	model.alert = slash == Slash.WARNING or slash == Slash.FLURRY
	# Its lunge toward the lane it cuts, with the sweep of its blades (_update_trail), easing back as it recovers.
	model.reach = _sweep_share() if slash != Slash.RECOVER \
		else minf(model.reach, 1.0 - clampf(_slash_t / maxf(tuning.recover_seconds, 0.05), 0.0, 1.0))
	if slash_lane >= 0 and absf(world.geo.lane_x(slash_lane) - _x) > 0.01:
		model.reach_dir = signf(world.geo.lane_x(slash_lane) - _x)
	var dir: float = signf(_switch_to - _switch_from)
	model.roll = -dir * 0.2 * sin(PI * _switch_t) if _switch_t < 1.0 else 0.0
	model.animate(delta)


func _note(event: StringName) -> void:
	history.append([String(event), world.player_distance(), world.level_time()])


## A sound for everyone to hear (it comes from behind: its arrival's whine, its giving up).
func _sfx(sound: StringName) -> void:
	sounds_played.append([sound, world.level_time()])
	world.play_sfx(sound)


## A sound from where it is (its warning's scrape, its cuts, its death).
func _sfx_at(sound: StringName) -> void:
	sounds_played.append([sound, world.level_time()])
	world.play_sfx_at(sound, aim_point())
