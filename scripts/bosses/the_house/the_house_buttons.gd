class_name TheHouseButtons
extends Node3D
## The House's 7 buttons (GDD §10, "Rigging the jackpot: while the reels spin, big glowing 7 buttons
## appear along the route. Running over one locks its reel on 7. With all three locked: JACKPOT"), phase
## 1's: all on the floor. In a spin with buttons, each reel still unlocked gets one, in reel order: the
## runner reaches the first button_first after the lever's pull and each next one button_spacing later
## (at the phase's pace), and each lights up button_lead before they get to it, with a chime. Its reel
## stops as the runner passes it: on 7 if they ran over it (`pressed`), on its symbol if not (`missed`).
## The buttons' lanes: each at most button_max_shift lanes from the one before (the first from the
## runner's lane), never the same lane as the one before (button_same_lane off), and only where
## TheHouseRoute finds a way over every one of them, in order, through whatever of the last attack still
## lies ahead (TheHouse.route_through): every button is reachable while dodging the current attack. A set
## with no such lanes now isn't offered (the lever waits).
## The look (the_house_button.gdshader): a big round ivory button flat on the floor with the reels' royal
## blue 7, ringed with chasing bulbs, and the same 7 floating upright above head height over it so it
## shows from far along the street. White, ivory and royal blue are no hazard's colours and its round
## shape no pad's: safe to run over (DESIGN-TBD, docs/questions/e5a.md).

signal pressed(reel: int)
signal missed(reel: int)

## The floating 7's height over the button (above head height and a jump's reach), and its size.
const SIGN_HEIGHT: float = 3.1
const SIGN_SIZE: float = 1.25
## How long a button takes to grow in, and to sink away once pressed or passed.
const APPEAR_SECONDS: float = 0.3
const GONE_SECONDS: float = 0.6

var boss: TheHouse
var tuning: TheHouseTuning
var world: RunWorld
## The set in play: {reel, lane, at, show (clock), state ("waiting", "lit", "pressed", "missed"), t, nodes}.
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


## Seconds after the lever's pull when the runner reaches the `k`th button of a set (the phase's pace).
func reach_time(k: int) -> float:
	return (tuning.button_first + k * tuning.button_spacing) / boss.pace()


## A set of buttons for `reels` (the reels still unlocked, in order), the lever pulled now: [{reel, lane,
## at, show}] (show: seconds from now), or [] when no lanes give a fair way over them all now. The lanes
## are the first of a seeded order that keep to the shift rules and through which a route runs.
func plan(reels: Array[int]) -> Array[Dictionary]:
	var none: Array[Dictionary] = []
	if reels.is_empty():
		return none
	var n: int = boss.lane_count()
	var d0: float = world.player.distance
	var v: float = boss.speed()
	var start: int = boss.player_lane()
	var combos: Array = []
	_combos(reels.size(), n, start, [], combos)
	_shuffle(combos)
	var first_show: float = maxf(reach_time(0) - tuning.button_lead, 0.0)
	for lanes: Array in combos:
		var waypoints: Array[Dictionary] = []
		for k: int in reels.size():
			waypoints.append({"lane": int(lanes[k]), "at": d0 + v * reach_time(k)})
		var route: Dictionary = boss.route_through([], waypoints, -1.0, first_show)
		if not route["ok"]:
			continue
		var out: Array[Dictionary] = []
		for k: int in reels.size():
			out.append({"reel": reels[k], "lane": int(lanes[k]), "at": float(waypoints[k]["at"]),
				"show": maxf(reach_time(k) - tuning.button_lead, 0.0)})
		return out
	return none


## Every run of lanes for `count` buttons that keeps to the shift rules, from `start`.
func _combos(count: int, n: int, prev: int, so_far: Array, out: Array) -> void:
	if so_far.size() == count:
		out.append(so_far.duplicate())
		return
	for lane: int in n:
		if absi(lane - prev) > tuning.button_max_shift:
			continue
		if lane == prev and not tuning.button_same_lane and not so_far.is_empty():
			continue
		so_far.append(lane)
		_combos(count, n, lane, so_far, out)
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
		boss.log_event(&"button_planned", {"reel": int(b["reel"]), "lane": int(b["lane"]), "at": float(b["at"])})
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
	var half_depth: float = tuning.button_depth * boss.run_pace() * 0.5
	for b: Dictionary in active:
		b["t"] = float(b["t"]) + delta
		var at: float = float(b["at"])
		match String(b["state"]):
			"waiting":
				if clock >= float(b["show"]):
					b["state"] = "lit"
					b["t"] = 0.0
					boss.sound(&"house_button", world.lane_point(int(b["lane"]), at, 0.5))
					boss.log_event(&"button_lit", {"reel": int(b["reel"]), "lane": int(b["lane"]), "at": at})
			"lit":
				if _over(b, _prev_d, d, half_depth):
					b["state"] = "pressed"
					b["t"] = 0.0
					pressed_count += 1
					boss.log_event(&"button_pressed", {"reel": int(b["reel"]), "lane": int(b["lane"]), "at": at})
					pressed.emit(int(b["reel"]))
				elif d > at + half_depth:
					b["state"] = "missed"
					b["t"] = 0.0
					missed_count += 1
					boss.log_event(&"button_missed", {"reel": int(b["reel"]), "lane": int(b["lane"]), "at": at,
						"player_lane": p.lane})
					missed.emit(int(b["reel"]))
		_draw(b)
	_prev_d = d
	for i: int in range(active.size() - 1, -1, -1):
		var b: Dictionary = active[i]
		if (b["state"] == "pressed" or b["state"] == "missed") and float(b["t"]) > GONE_SECONDS \
				and float(b["at"]) < d - 4.0:
			_hide(b["look"])
			active.remove_at(i)


## True if the runner ran over button `b` this frame (from `d_from` to `d_to`): on the floor in its lane
## (its middle within the button's width) and low enough, over its stretch of the lane.
func _over(b: Dictionary, d_from: float, d_to: float, half_depth: float) -> bool:
	var p: Player = world.player
	var at: float = float(b["at"])
	if d_to < at - half_depth or d_from > at + half_depth:
		return false
	if p.surface != Player.Surface.FLOOR or p.position.y > tuning.button_reach_height:
		return false
	var half: float = world.geo.lane_width * tuning.button_width_share * 0.5 + world.tuning.hurtbox_size.x * 0.5
	return absf(p.position.x - world.geo.lane_x(int(b["lane"]))) <= half


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
	var size: float = world.geo.lane_width * tuning.button_width_share
	var at: float = float(b["at"])
	var x: float = world.geo.lane_x(int(b["lane"]))
	disc.global_transform = Transform3D(Basis(Vector3.RIGHT, -PI * 0.5) * Basis.from_scale(Vector3(size, size, 1.0)),
		Vector3(x, 0.05, TrackGeometry.world_z(at)))
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
	var sign_y: float = SIGN_HEIGHT + bob + sink * 2.5
	sign_node.global_transform = Transform3D(Basis.from_scale(Vector3.ONE * SIGN_SIZE * maxf(appear, 0.05) * (1.0 - 0.6 * sink)),
		Vector3(x, sign_y, TrackGeometry.world_z(at)))
	sign_node.visible = sink < 0.99
	for m: ShaderMaterial in [look["disc_mat"], look["sign_mat"]]:
		m.set_shader_parameter(&"appear", appear)
		m.set_shader_parameter(&"pressed", press * (1.0 - 0.5 * sink))
		m.set_shader_parameter(&"missed", dim)


func _free_look() -> Dictionary:
	for look: Dictionary in _pool:
		if not look["used"]:
			look["used"] = true
			return look
	var shader := load("res://scripts/bosses/the_house/the_house_button.gdshader") as Shader
	var disc_mat := ShaderMaterial.new()
	disc_mat.shader = shader
	disc_mat.set_shader_parameter(&"part", 0)
	var sign_mat := ShaderMaterial.new()
	sign_mat.shader = shader
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
