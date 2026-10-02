class_name TheHouseButtons
extends Node3D
## The House's 7 buttons (GDD §10, "Rigging the jackpot: while the reels spin, big glowing 7 buttons
## appear along the route. Running over one locks its reel on 7. With all three locked: JACKPOT"; "three
## phases, with the buttons getting harder to reach: (1) all three on the floor; (2) one on a wall, with
## wall fences in play; (3) one on a ceiling reached by an anti-grav pad, guarded by Barnacle Turrets"). In
## a spin with buttons, each reel still unlocked gets one, in reel order: the runner reaches the first
## button_first after the lever's pull and each next one button_spacing later (at the phase's pace), and
## each lights up button_lead before they get to it, with a chime. Its reel stops as the runner passes it:
## on 7 if they ran over it (`pressed`), on its symbol if not (`missed`).
## A phase's special reel (TheHouseTuning.special_reel, special_buttons) has its button elsewhere:
## - "wall": on a side wall's facade at wall-run height, as tall as the wall-run path, reached wall_extra
##   later and lit wall_lead before: a wall runner on that wall passing it at any height runs over it. Its
##   plan has the runner in the outer lane on its side, onto the wall wall_entry_before it and back in
##   that lane wall_after past it (a hold of the route, TheHouseRoute), every wall fence on that wall
##   between the entry and the button off while they pass it (TheHouseWalls.passage_off: wall fences in
##   play are passed by timing, GDD §9.1).
## - "ceiling": on the underside of a floating billboard (TheHouseCeiling) reached by an anti-grav pad,
##   pad_extra later than a floor button in its place: its plan has the runner in the pad's lane over the
##   pad, and a way along the ceiling past the turrets' bodies to the button (TheHouseCeiling.route), the
##   floor clear of every hazard of the last attack from the pad on (the ceiling is never required, and
##   the drop at its end lands on clear floor).
## The buttons' lanes: each floor button at most button_max_shift lanes from the one before (the first
## from the runner's lane), never the same lane as the one before (button_same_lane off), and a set is
## offered only where TheHouseRoute finds a way over every one of them, in order, through whatever of the
## last attack still lies ahead (TheHouse.route_through): every button is reachable while dodging the
## current attack. A set with no such lanes now isn't offered (the lever waits).
## The look (the_house_button.gdshader): a big round ivory button with the reels' royal blue 7, ringed
## with chasing bulbs (flat on the floor, upright on a wall's facade, on a ceiling's underside facing
## down), and the same 7 floating near it so it shows from far along the street. White, ivory and royal
## blue are no hazard's colours and its round shape no pad's: safe to run over (DESIGN-TBD, OPEN_QUESTIONS
## item 299). Pooled.

signal pressed(reel: int)
signal missed(reel: int)

## The floating 7's height over a floor button (above head height and a jump's reach), and its size.
const SIGN_HEIGHT: float = 3.1
const SIGN_SIZE: float = 1.25
## The sign shrinks away over the last this many metres (at 18 m/s) before the runner reaches its button.
const SIGN_FADE_NEAR: float = 9.0
## How long a button takes to grow in, and to sink away once pressed or passed.
const APPEAR_SECONDS: float = 0.3
const GONE_SECONDS: float = 0.6
## A wall button's sign floats this far out from the facade, and a ceiling button's this far under it.
const WALL_SIGN_OUT: float = 0.6
const CEILING_SIGN_DROP: float = 1.7
## At most this many routes are tried for one set (a set that finds none now waits for the next frame).
const MAX_TRIES: int = 16
const BUTTON_SHADER: Shader = preload("res://scripts/bosses/the_house/the_house_button.gdshader")

var boss: TheHouse
var tuning: TheHouseTuning
var world: RunWorld
## The set in play: {reel, kind ("floor", "wall", "ceiling"), lane, side (a wall button's wall), at, show
## (clock), state ("waiting", "lit", "pressed", "missed"), t, look, segment (a ceiling button's)}.
var active: Array[Dictionary] = []
## Seconds of the fight's pattern (TheHouseAttacks keeps the same clock).
var clock: float = 0.0
## Buttons pressed and missed over the fight.
var pressed_count: int = 0
var missed_count: int = 0

var _pool: Array[Dictionary] = []
var _prev_d: float = 0.0


func setup(p_boss: TheHouse) -> void:
	boss = p_boss
	tuning = boss.tuning
	world = boss.world
	top_level = true
	transform = Transform3D.IDENTITY


## Makes a set's looks before the fight (pooled; the pool still grows if ever needed).
func prewarm() -> void:
	var looks: Array[Dictionary] = []
	for i: int in 3:
		looks.append(_free_look())
	for look: Dictionary in looks:
		_hide(look)


## Seconds after the lever's pull when the runner reaches the `k`th button of a set (the phase's pace).
func reach_time(k: int) -> float:
	return (tuning.button_first + k * tuning.button_spacing) / boss.pace()


## Where this phase puts the special reel's button: "floor", "wall" or "ceiling".
func special_kind() -> String:
	return tuning.special_for(boss.phase_index)


## A set of buttons for `reels` (the reels still unlocked, in order; a special one's button last), the lever
## pulled now: [{reel, kind, lane, side, at, show, segment}] (show: seconds from now), or [] when no set
## gives a fair way over them all now. The lanes are the first of a seeded order that keep to the shift rules and through which a
## route runs (and, for a wall or ceiling button, whose wall run or ceiling is fair).
func plan(reels: Array[int]) -> Array[Dictionary]:
	var none: Array[Dictionary] = []
	if reels.is_empty():
		return none
	var n: int = boss.lane_count()
	var d0: float = world.player.distance
	var v: float = boss.speed()
	var start: int = boss.player_lane()
	var kind: String = special_kind()
	# A wall or ceiling button comes last in its set, after the floor buttons of the other reels.
	var order: Array[int] = []
	for r: int in reels:
		if kind == "floor" or r != tuning.special_reel:
			order.append(r)
	var special: int = -1
	if order.size() < reels.size():
		order.append(tuning.special_reel)
		special = order.size() - 1
	var combos: Array = []
	_combos(order, special, kind, n, start, [], combos)
	_shuffle(combos)
	var first_show: float = maxf(_reach(0, special, kind) - _lead(0, special, kind), 0.0)
	var tries: int = 0
	for lanes: Array in combos:
		if tries >= MAX_TRIES:
			break
		var set_plan: Array[Dictionary] = _try(order, special, kind, lanes, d0, v, first_show)
		tries += 1
		if not set_plan.is_empty():
			return set_plan
	return none


## The set for `lanes` (a lane per reel; a wall button's is its outer lane, -1 for the left wall's), or
## [] if it isn't fair now.
func _try(reels: Array[int], special: int, kind: String, lanes: Array, d0: float, v: float,
		first_show: float) -> Array[Dictionary]:
	var none: Array[Dictionary] = []
	var n: int = boss.lane_count()
	var waypoints: Array[Dictionary] = []
	var out: Array[Dictionary] = []
	for k: int in reels.size():
		var at: float = d0 + v * _reach(k, special, kind)
		var lane: int = int(lanes[k])
		var b := {"reel": reels[k], "kind": "floor", "lane": lane, "side": 0, "at": at,
			"show": maxf(_reach(k, special, kind) - _lead(k, special, kind), 0.0)}
		if k == special and kind == "wall":
			var side: int = -1 if lane <= 0 else 1
			var outer: int = 0 if side < 0 else n - 1
			var entry: float = at - v * tuning.wall_entry_before / boss.pace()
			var back: float = at + v * tuning.wall_after / boss.pace()
			var body: float = world.tuning.hurtbox_size.z
			if not boss.walls.passage_off(side, entry, at + body, boss.walls.time_at(entry), v, tuning.fence_pass_margin):
				return none
			waypoints.append({"lane": outer, "at": entry, "to": back})
			b["kind"] = "wall"
			b["lane"] = outer
			b["side"] = side
		elif k == special and kind == "ceiling":
			var side_t: int = 1 if lane * 2 < n - 1 or (lane * 2 == n - 1 and boss.rng.randf() < 0.5) else -1
			if lane + side_t < 0 or lane + side_t >= n:
				side_t = -side_t
			var seg: Dictionary = boss.ceiling.plan(lane, d0, _reach(k, special, kind), v, side_t)
			# Nothing of the last attack reaches the floor from the pad on, and the ceiling has a way past its
			# turrets over the button.
			if boss.attacks.hazards_end() > float(seg["pad_at"]) - v * 0.5:
				return none
			if not boss.ceiling.route(seg)["ok"]:
				return none
			var pad_at: float = float(seg["pad_at"])
			waypoints.append({"lane": lane, "at": pad_at - 1.0, "to": pad_at + world.tuning.pad_length})
			b["kind"] = "ceiling"
			b["lane"] = int(seg["button_lane"])
			b["at"] = float(seg["button_at"])
			b["segment"] = seg
			# It lights up once the billboard has come down.
			var drop_end: float = (tuning.duck_seconds + tuning.billboard_drop_seconds) / boss.pace()
			b["show"] = maxf(float(b["show"]), drop_end)
		else:
			waypoints.append({"lane": lane, "at": at})
		out.append(b)
	if special < 0:
		if not boss.route_through([], waypoints, -1.0, first_show)["ok"]:
			return none
		return out
	# A wall or ceiling button shows later than the first floor one (a wall button once it's out from behind
	# the machine, a ceiling's pad as the billboard comes down): a way over the floor buttons from the first
	# show, then, from where that way has the runner a reaction time after the special one shows, a way on
	# over the rest and the special one's hold (the runner reads each button as it shows, like the bot).
	var hold: Dictionary = waypoints[special]
	var floors: Array[Dictionary] = waypoints.slice(0, special)
	var until: float = float(hold["to"])
	var first: Dictionary = boss.route_through([], floors, -1.0, first_show)
	if not first["ok"]:
		return none
	var reveal: float = float(out[special]["show"]) if kind == "wall" else tuning.duck_seconds / boss.pace()
	var d_r: float = d0 + v * (reveal + tuning.reaction)
	var lane_r: int = TheHouseRoute.lane_at(first, boss.player_lane(), d_r)
	var rest: Array[Dictionary] = []
	for w: Dictionary in floors:
		if float(w["at"]) > d_r:
			rest.append(w)
	rest.append(hold)
	if not boss.route_from(lane_r, d_r, rest, until)["ok"]:
		return none
	return out


## Seconds after the pull when the runner reaches the `k`th button of the set: a wall button wall_extra
## later than a floor one, a ceiling button's pad pad_extra later.
func _reach(k: int, special: int, kind: String) -> float:
	var t: float = reach_time(k)
	if k == special and kind == "wall":
		t += tuning.wall_extra / boss.pace()
	elif k == special and kind == "ceiling":
		t += tuning.pad_extra / boss.pace()
	return t


func _lead(k: int, special: int, kind: String) -> float:
	if k == special and kind == "wall":
		return tuning.wall_lead / boss.pace()
	return tuning.button_lead / boss.pace()


## Every run of lanes for the set's buttons that keeps to the shift rules, from `prev`: a floor button at
## most button_max_shift lanes from the one before (never the same, button_same_lane off); a wall
## button's lane is its outer lane (either wall, whatever came before); a ceiling button's pad off the
## edges (TheHouseCeiling.pad_lane_ok) and within the shift.
func _combos(reels: Array[int], special: int, kind: String, n: int, prev: int, so_far: Array, out: Array) -> void:
	var k: int = so_far.size()
	if k == reels.size():
		out.append(so_far.duplicate())
		return
	if k == special and kind == "wall":
		for lane: int in ([0, n - 1] if n > 1 else [0]):
			so_far.append(lane)
			_combos(reels, special, kind, n, lane, so_far, out)
			so_far.pop_back()
		return
	for lane: int in n:
		if absi(lane - prev) > tuning.button_max_shift:
			continue
		if lane == prev and not tuning.button_same_lane and not so_far.is_empty():
			continue
		if k == special and kind == "ceiling" and not boss.ceiling.pad_lane_ok(lane):
			continue
		so_far.append(lane)
		_combos(reels, special, kind, n, lane, so_far, out)
		so_far.pop_back()


func _shuffle(list: Array) -> void:
	for i: int in range(list.size() - 1, 0, -1):
		var j: int = boss.rng.randi_range(0, i)
		var t: Variant = list[i]
		list[i] = list[j]
		list[j] = t


## Puts a planned set (plan()) on the track: each lights up at its time.
func start(set_plan: Array[Dictionary]) -> void:
	clear()
	for b: Dictionary in set_plan:
		var entry: Dictionary = b.duplicate()
		entry["show"] = clock + float(b["show"])
		entry["state"] = "waiting"
		entry["t"] = 0.0
		entry["look"] = _free_look()
		active.append(entry)
		boss.log_event(&"button_planned", {"reel": int(b["reel"]), "kind": String(b["kind"]), "lane": int(b["lane"]),
			"side": int(b["side"]), "at": float(b["at"])})
	_prev_d = world.player.distance


## True while a button of the set is still ahead (waiting, or lit and not yet passed).
func pending() -> bool:
	for b: Dictionary in active:
		if b["state"] == "waiting" or b["state"] == "lit":
			return true
	return false


## The button of `reel` in play, or {}.
func of_reel(reel: int) -> Dictionary:
	for b: Dictionary in active:
		if int(b["reel"]) == reel:
			return b
	return {}


func clear() -> void:
	for b: Dictionary in active:
		_hide(b["look"])
	active.clear()


func tick(delta: float) -> void:
	clock += delta
	var p: Player = world.player
	var d: float = p.distance
	for b: Dictionary in active:
		b["t"] = float(b["t"]) + delta
		var at: float = float(b["at"])
		var half_depth: float = _half_depth(b)
		match String(b["state"]):
			"waiting":
				if clock >= float(b["show"]):
					b["state"] = "lit"
					b["t"] = 0.0
					boss.sound(&"house_button", _spot(b))
					boss.log_event(&"button_lit", {"reel": int(b["reel"]), "kind": String(b["kind"]), "lane": int(b["lane"]),
						"side": int(b["side"]), "at": at})
			"lit":
				if _over(b, _prev_d, d, half_depth):
					b["state"] = "pressed"
					b["t"] = 0.0
					pressed_count += 1
					boss.log_event(&"button_pressed", {"reel": int(b["reel"]), "kind": String(b["kind"]),
						"lane": int(b["lane"]), "at": at})
					pressed.emit(int(b["reel"]))
				elif d > at + half_depth:
					b["state"] = "missed"
					b["t"] = 0.0
					missed_count += 1
					boss.log_event(&"button_missed", {"reel": int(b["reel"]), "kind": String(b["kind"]), "lane": int(b["lane"]),
						"at": at, "player_lane": p.lane, "surface": p.surface_name()})
					missed.emit(int(b["reel"]))
		_draw(b)
	_prev_d = d
	for i: int in range(active.size() - 1, -1, -1):
		var b: Dictionary = active[i]
		if (b["state"] == "pressed" or b["state"] == "missed") and float(b["t"]) > GONE_SECONDS \
				and float(b["at"]) < d - 4.0:
			_hide(b["look"])
			active.remove_at(i)


## The stretch along the track where running over button `b` counts, either side of its middle.
func _half_depth(b: Dictionary) -> float:
	var depth: float = tuning.wall_button_length if b["kind"] == "wall" else tuning.button_depth
	return depth * boss.run_pace() * 0.5


## True if the runner ran over button `b` this frame (from `d_from` to `d_to`) over its stretch: on the floor
## in its lane (its middle within the button's width) and low enough; on its wall, at any height; on the
## ceiling in its lane.
func _over(b: Dictionary, d_from: float, d_to: float, half_depth: float) -> bool:
	var p: Player = world.player
	var at: float = float(b["at"])
	if d_to < at - half_depth or d_from > at + half_depth:
		return false
	var half: float = world.geo.lane_width * tuning.button_width_share * 0.5 + world.tuning.hurtbox_size.x * 0.5
	match String(b["kind"]):
		"wall":
			return p.surface == Player.Surface.WALL and p.wall_side == int(b["side"])
		"ceiling":
			return p.surface == Player.Surface.CEILING and absf(p.position.x - world.geo.lane_x(int(b["lane"]))) <= half
	if p.surface != Player.Surface.FLOOR or p.position.y > tuning.button_reach_height:
		return false
	return absf(p.position.x - world.geo.lane_x(int(b["lane"]))) <= half


## Where button `b` is in the world (its chime comes from there).
func _spot(b: Dictionary) -> Vector3:
	var at: float = float(b["at"])
	match String(b["kind"]):
		"wall":
			return Vector3(int(b["side"]) * world.geo.wall_x(), tuning.wall_button_height, TrackGeometry.world_z(at))
		"ceiling":
			return world.lane_point(int(b["lane"]), at, world.tuning.ceiling_height - 0.2)
	return world.lane_point(int(b["lane"]), at, 0.5)


# --- Looks ---------------------------------------------------------------------------------------

func _draw(b: Dictionary) -> void:
	var look: Dictionary = b["look"]
	var disc: MeshInstance3D = look["disc"]
	var sign_node: MeshInstance3D = look["sign"]
	var state: String = b["state"]
	var t: float = float(b["t"])
	if state == "waiting":
		disc.visible = false
		sign_node.visible = false
		return
	disc.visible = true
	sign_node.visible = true
	var at: float = float(b["at"])
	var z: float = TrackGeometry.world_z(at)
	var appear: float = clampf(t / APPEAR_SECONDS, 0.0, 1.0) if state == "lit" else 1.0
	var press: float = 0.0
	var dim: float = 0.0
	var sink: float = 0.0
	if state == "pressed":
		press = 1.0
		sink = clampf(t / GONE_SECONDS, 0.0, 1.0)
	elif state == "missed":
		dim = clampf(t / 0.25, 0.0, 1.0)
	var bob: float = 0.12 * sin(clock * 2.2 + at)
	# The sign marks the button from afar, then shrinks away as the runner nears it (it would fill the view
	# as it passes over the run camera).
	var near: float = clampf((at - world.player.distance) / (SIGN_FADE_NEAR * boss.run_pace()), 0.0, 1.0)
	var sign_scale: float = SIGN_SIZE * maxf(appear, 0.05) * (1.0 - 0.6 * sink) * near
	var sign_pos: Vector3
	match String(b["kind"]):
		"wall":
			var side: int = int(b["side"])
			var size_w: float = tuning.wall_button_size
			# Upright on the facade, facing the street.
			disc.global_transform = Transform3D(Basis(Vector3.UP, -side * PI * 0.5) * Basis.from_scale(Vector3(size_w, size_w, 1.0)),
				Vector3(side * (world.geo.wall_x() - 0.03), tuning.wall_button_height, z))
			sign_pos = Vector3(side * (world.geo.wall_x() - WALL_SIGN_OUT),
				tuning.wall_button_height + size_w * 0.5 + 0.9 + bob + sink * 2.0, z)
		"ceiling":
			var size_c: float = world.geo.lane_width * tuning.button_width_share
			disc.global_transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5) * Basis.from_scale(Vector3(size_c, size_c, 1.0)),
				Vector3(world.geo.lane_x(int(b["lane"])), world.tuning.ceiling_height - 0.03, z))
			sign_pos = Vector3(world.geo.lane_x(int(b["lane"])), world.tuning.ceiling_height - CEILING_SIGN_DROP + bob
				- sink * 1.5, z)
		_:
			var size: float = world.geo.lane_width * tuning.button_width_share
			disc.global_transform = Transform3D(Basis(Vector3.RIGHT, -PI * 0.5) * Basis.from_scale(Vector3(size, size, 1.0)),
				Vector3(world.geo.lane_x(int(b["lane"])), 0.05, z))
			sign_pos = Vector3(world.geo.lane_x(int(b["lane"])), SIGN_HEIGHT + bob + sink * 2.5, z)
	sign_node.global_transform = Transform3D(Basis.from_scale(Vector3.ONE * maxf(sign_scale, 0.001)), sign_pos)
	sign_node.visible = sink < 0.99 and sign_scale > 0.02
	for m: ShaderMaterial in [look["disc_mat"], look["sign_mat"]]:
		m.set_shader_parameter(&"appear", appear)
		m.set_shader_parameter(&"pressed", press * (1.0 - 0.5 * sink))
		m.set_shader_parameter(&"missed", dim)


func _free_look() -> Dictionary:
	for look: Dictionary in _pool:
		if not look["used"]:
			look["used"] = true
			return look
	var disc_mat := ShaderMaterial.new()
	disc_mat.shader = BUTTON_SHADER
	disc_mat.set_shader_parameter(&"part", 0)
	var sign_mat := ShaderMaterial.new()
	sign_mat.shader = BUTTON_SHADER
	sign_mat.set_shader_parameter(&"part", 1)
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var disc := MeshInstance3D.new()
	disc.name = "Button"
	disc.mesh = quad
	disc.material_override = disc_mat
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	disc.visible = false
	add_child(disc)
	var sign_node := MeshInstance3D.new()
	sign_node.name = "ButtonSign"
	sign_node.mesh = quad
	sign_node.material_override = sign_mat
	sign_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sign_node.visible = false
	add_child(sign_node)
	var look := {"used": true, "disc": disc, "sign": sign_node, "disc_mat": disc_mat, "sign_mat": sign_mat}
	_pool.append(look)
	return look


func _hide(look: Dictionary) -> void:
	look["used"] = false
	(look["disc"] as Node3D).visible = false
	(look["sign"] as Node3D).visible = false
