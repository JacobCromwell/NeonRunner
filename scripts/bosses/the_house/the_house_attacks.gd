class_name TheHouseAttacks
extends Node3D
## The House's three attacks (GDD §10: "the symbols announce the attacks, in reel order"):
## - Cherry: "cherry bombs lobbed into lanes, with target circles on the floor (the Floating Head's bomb
##   warning)": a volley of bombs lobbed from its coin chute into a run of lanes, each with its red target
##   circle (BossProps.circle_warning) and the falling whistle, blowing as the runner would get there (a
##   blast too tall to jump: leave the lane).
## - Lightning: "a pink electric fence rolled across some lanes (normal fence rules)": a spool rolls across
##   the street unrolling a fence (BossProps.fence) over a run of lanes, flickering harmlessly with its
##   crackle (the fence's own warning) until it switches on, before the runner gets there. Jump it, or take
##   a lane it doesn't cover.
## - BAR: "heavy gold blocks slammed down into lanes; switch around them": the lanes about to be struck
##   light up red (BossProps.lane_warning), gold blocks fall from high above and slam down (BossProps.block:
##   solid, deadly to run into, solid to switch into) before the runner gets there.
## "Two or three of a kind make a bigger version of that attack": the reels' symbols are grouped by kind, in
## the order their first reel shows them (queue_spin); a kind's count is its size: more strikes (cherry
## volleys, BAR rows), wider ones, and for three lightnings two rows across every lane, a full-height fence
## to jump and then a gapped one to slide under.
## Each strike is planned as it's revealed, from where the runner is: its lanes are the first of a seeded
## list (those holding the runner first: the attack aims at them) through which TheHouseRoute finds a way,
## with everything else still ahead on the track, for a runner who moves a reaction time after the warning
## (TheHouse.route_through), and off phase 2's wall fences' drop windows (TheHouseWalls.in_drop_window). A
## strike with no fair lanes now waits up to strike_wait, then is left out (logged). So every attack has
## an escape at every lane count, and what strikes is exactly what its warning showed (lanes, place and
## time; the tests check both). A new attack waits while the runner goes for a wall or ceiling button
## (TheHouse.attacks_held). Timings are at the phase's pace; where a strike lands is its warning times
## the run speed.

enum Kind { CHERRY, LIGHTNING, BAR }

const KIND_NAMES: PackedStringArray = ["cherry", "lightning", "bar"]
const BOMB_NAME: String = "The House's cherry bomb"
const BLOCK_NAME: String = "The House's gold block"
const FIRE := Color(1.0, 0.36, 0.12)
const FIRE_HOT := Color(1.0, 0.8, 0.5)
## Enemy-attack red: the bombs and the blocks' hot edges (the weak points' and the warnings' red).
const ATTACK_RED := Color(1.0, 0.08, 0.1)
const GOLD := Color(0.86, 0.66, 0.24)
const FENCE_PINK := Color(1.0, 0.18, 0.62)
## A fireball lasts this long (its hitbox only blast_seconds).
const FIRE_SECONDS: float = 0.6
## The falling whistle's length, if the sound library doesn't say.
const WHISTLE_SECONDS: float = 0.9
## How high a gold block falls from.
const DROP_HEIGHT: float = 26.0

var boss: TheHouse
var tuning: TheHouseTuning
var world: RunWorld
## Seconds of fight pattern so far (strikes keep to this clock).
var clock: float = 0.0
## Attacks waiting their turn, in reel order: {kind, size, reel}.
var queue: Array[Dictionary] = []
## The attack revealing its strikes: {kind, size, reel, strikes (how many in all), done (revealed so far),
## next_at (clock), waited, n}, or empty.
var current: Dictionary = {}
## Every strike revealed whose hazards may still lie ahead: {n, attack, kind, size, lanes: Array[int], at
## (track distance), variant ("full"/"gapped" for a fence), reveal and land (clock), d0 (the runner's
## distance at the reveal), state ("warn", "struck", "over"), nodes...}.
var strikes: Array[Dictionary] = []
## When the last strike was revealed (clock), or -1.
var last_reveal: float = -1.0
## Strikes revealed so far, and strikes left out (no fair lanes in time).
var count: int = 0
var skipped: int = 0

var _attacks_started: int = 0
var _next_attack_at: float = 0.0
var _whistle: float = WHISTLE_SECONDS
# Everything an attack shows is pooled, so a fight allocates nothing once its pools have grown to
# what one spin needs: bombs, blasts' boxes and fireballs, gold blocks and spools.
var _bombs: Array[MeshInstance3D] = []
var _blast_boxes: Array[Hazard] = []
var _fires: Array[MeshInstance3D] = []
var _blasts: Array[Dictionary] = []
## Gold blocks: {hazard, blocker, look, used}. Each hazard is BossProps.block's kind (solid: deadly to
## run into, a lane blocker to switch into), on from the slam; put away, both its layers are cleared.
var _blocks: Array[Dictionary] = []
var _spools: Array[MeshInstance3D] = []
## How many times each pool was drawn on, for pool_stats().
var _taken: Dictionary = {}

static var _bomb_mesh: ArrayMesh
static var _block_mesh_cache: Dictionary = {}
static var _spool_mesh: ArrayMesh


func setup(p_boss: TheHouse) -> void:
	boss = p_boss
	tuning = boss.tuning
	world = boss.world
	top_level = true
	transform = Transform3D.IDENTITY
	if world.sfx_library != null and world.sfx_library.stream(&"bomb_whistle") != null:
		_whistle = world.sfx_library.stream(&"bomb_whistle").get_length()


## Fills the pools for a spin at this lane count before the fight (and builds the looks' meshes), so the
## first attacks make nothing either: a volley's bombs, blasts' boxes and fireballs, BAR rows' blocks,
## spools. They still grow if a spin ever needs more.
func prewarm() -> void:
	var n: int = boss.lane_count()
	for i: int in n + 2:
		_new_bomb()
		_new_fire()
		_new_blast_box()
	for i: int in 3 * maxi(n - 1, 1):
		_new_block()
	for i: int in 2:
		_new_spool()


static func kind_name(kind: int) -> String:
	return KIND_NAMES[clampi(kind, 0, KIND_NAMES.size() - 1)]


## The attacks a spin's symbols (TheHouseReels.Symbol, in reel order) bring: one per kind shown, in the
## order its first reel shows it, as big as the reels showing it (a 7 brings none). Returns them.
static func attacks_for(symbols: Array[int]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for reel: int in symbols.size():
		var kind: int = _kind_of(symbols[reel])
		if kind < 0:
			continue
		var found: bool = false
		for a: Dictionary in out:
			if int(a["kind"]) == kind:
				a["size"] = int(a["size"]) + 1
				found = true
		if not found:
			out.append({"kind": kind, "size": 1, "reel": reel})
	return out


static func _kind_of(symbol: int) -> int:
	match symbol:
		TheHouseReels.Symbol.CHERRY:
			return Kind.CHERRY
		TheHouseReels.Symbol.LIGHTNING:
			return Kind.LIGHTNING
		TheHouseReels.Symbol.BAR:
			return Kind.BAR
	return -1


## Queues the attacks of a spin that stopped on `symbols`; the first comes result_pause from now.
func queue_spin(symbols: Array[int]) -> void:
	var list: Array[Dictionary] = attacks_for(symbols)
	if list.is_empty():
		return
	queue.append_array(list)
	_next_attack_at = maxf(_next_attack_at, clock + tuning.result_pause / boss.pace())


## True while an attack waits its turn or still has strikes to reveal.
func busy() -> bool:
	return not queue.is_empty() or not current.is_empty()


## True while a strike warns or strikes (its warning showing, its hazards about to hit or live): the
## House's big attack, for the director and the bot.
func warning_on() -> bool:
	if busy():
		return true
	for s: Dictionary in strikes:
		if s["state"] == "warn" or (s["state"] == "struck" and float(s["at"]) > world.player.distance - 2.0):
			return true
	return false


## The route obstacles (TheHouseRoute.obstacle) of every strike revealed whose hazards reach past `from`.
func obstacles(from: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s: Dictionary in strikes:
		if s["state"] == "over":
			continue
		for o: Dictionary in strike_obstacles(s):
			if float(o["to"]) >= from:
				out.append(o)
	return out


## The farthest track distance any revealed strike's hazards reach (-INF for none).
func hazards_end() -> float:
	var end: float = -INF
	for s: Dictionary in strikes:
		if s["state"] == "over":
			continue
		for o: Dictionary in strike_obstacles(s):
			end = maxf(end, float(o["to"]))
	return end


## A strike's hazards as route obstacles: a blast's stretch in each struck lane, a block's, a fence's.
func strike_obstacles(s: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var at: float = float(s["at"])
	for lane: int in s["lanes"]:
		match int(s["kind"]):
			Kind.CHERRY:
				out.append(TheHouseRoute.obstacle(lane, at - tuning.blast_depth * 0.5, at + tuning.blast_depth * 0.5))
			Kind.BAR:
				out.append(TheHouseRoute.obstacle(lane, at, at + tuning.block_depth))
			Kind.LIGHTNING:
				var depth: float = world.tuning.fence_depth
				var kind: int = TheHouseRoute.Kind.GAPPED if s["variant"] == "gapped" else TheHouseRoute.Kind.FENCE
				out.append(TheHouseRoute.obstacle(lane, at - depth * 0.5, at + depth * 0.5, kind))
	return out


## Everything off now (a phase's end, the jackpot window, the defeat): queued attacks dropped, warnings
## and live hazards gone.
func clear() -> void:
	queue.clear()
	current = {}
	for s: Dictionary in strikes:
		_retire(s)
	strikes.clear()
	for b: Dictionary in _blasts:
		(b["hazard"] as Hazard).set_enabled(false)
		(b["hazard"] as Hazard).collision_layer = 0
		(b["fire"] as Node3D).visible = false
	_blasts.clear()
	for bomb: MeshInstance3D in _bombs:
		bomb.visible = false


func tick(delta: float) -> void:
	clock += delta
	_update_strikes()
	_update_blasts()
	# A new attack waits while the runner goes for a wall or ceiling button (TheHouse.attacks_held).
	if current.is_empty() and not queue.is_empty() and clock >= _next_attack_at and not boss.attacks_held():
		var a: Dictionary = queue.pop_front()
		_attacks_started += 1
		current = {"kind": a["kind"], "size": a["size"], "reel": a["reel"], "strikes": strikes_in(int(a["kind"]),
			int(a["size"])), "done": 0, "next_at": clock, "waited": 0.0, "n": _attacks_started, "order": []}
		boss.log_event(&"attack", {"kind": kind_name(int(a["kind"])), "size": int(a["size"])})
		if int(a["size"]) >= 2:
			# A big attack: the citizens in the shop windows duck (GDD §10).
			boss.react_citizens(&"startled")
	if not current.is_empty() and clock >= float(current["next_at"]):
		_try_strike(delta)


## How many strikes an attack of `kind` and `size` reveals.
static func strikes_in(kind: int, size: int) -> int:
	match kind:
		Kind.LIGHTNING:
			return 2 if size >= 3 else 1
	return clampi(size, 1, 3)


# --- Planning ------------------------------------------------------------------------------------

## Reveals the current attack's next strike if its lanes can be fair now; otherwise waits (up to
## strike_wait), then leaves it out.
func _try_strike(delta: float) -> void:
	var kind: int = int(current["kind"])
	var size: int = int(current["size"])
	var index: int = int(current["done"])
	var plan: Dictionary = plan_strike(kind, size, index)
	if plan.is_empty():
		current["waited"] = float(current["waited"]) + delta
		if float(current["waited"]) >= tuning.strike_wait / boss.pace():
			skipped += 1
			boss.log_event(&"strike_skipped", {"kind": kind_name(kind), "size": size, "index": index})
			_after_strike()
		return
	_reveal(plan)
	_after_strike()


func _after_strike() -> void:
	current["done"] = int(current["done"]) + 1
	current["waited"] = 0.0
	current["order"] = []
	if int(current["done"]) >= int(current["strikes"]):
		current = {}
		_next_attack_at = clock + tuning.attack_gap / boss.pace()
	else:
		current["next_at"] = clock + _strike_gap(int(current["kind"])) / boss.pace()


func _strike_gap(kind: int) -> float:
	match kind:
		Kind.CHERRY:
			return tuning.volley_gap
		Kind.LIGHTNING:
			return tuning.fence_row_gap
	return tuning.row_gap


## A fair strike of the attack (`kind`, `size`) as its `index`th strike, revealed now: {kind, size, lanes,
## at, variant, land, route}, or {} if none is fair now. Its lanes are the first fair ones of a seeded
## order (fixed for the strike: retries try the same order), those holding the runner first.
func plan_strike(kind: int, size: int, index: int) -> Dictionary:
	var n: int = boss.lane_count()
	var d0: float = world.player.distance
	var v: float = boss.speed()
	var warning: float = warning_for(kind)
	var at: float = d0 + v * warning
	var variant: String = "full"
	var candidates: Array = current.get("order", []) if not current.is_empty() else []
	if candidates.is_empty():
		candidates = _candidates(kind, size, index, n)
		if not current.is_empty():
			current["order"] = candidates
	if kind == Kind.LIGHTNING and size >= 3 and index >= 1:
		variant = "gapped"
	for lanes: Array in candidates:
		var plan := {"kind": kind, "size": size, "lanes": lanes.duplicate(), "at": at, "variant": variant}
		var extra: Array[Dictionary] = strike_obstacles(plan)
		# Off the wall fences' drop windows (B5: no big attack reaches the outer lane a wall runner drops into).
		if boss.walls.in_drop_window(extra):
			continue
		var route: Dictionary = boss.route_through(extra)
		if route["ok"]:
			plan["route"] = route
			plan["warning"] = warning
			return plan
	return {}


## Seconds from a strike of `kind` being revealed to the runner reaching it.
func warning_for(kind: int) -> float:
	match kind:
		Kind.CHERRY:
			return tuning.cherry_warning
		Kind.LIGHTNING:
			return tuning.fence_warning
	return tuning.bar_warning


## Every lane set a strike may take, in the order it tries them: those holding the runner's lane first
## (seeded order within each group).
func _candidates(kind: int, size: int, index: int, n: int) -> Array:
	var pl: int = boss.player_lane()
	var sets: Array = []
	match kind:
		Kind.CHERRY:
			var c: int = TheHouseTuning.per_lanes(tuning.cherry_lanes, n) + (1 if size >= 2 and n >= 5 else 0)
			sets = _runs(mini(c, n - 1), n)
		Kind.BAR:
			var c: int = TheHouseTuning.per_lanes(tuning.bar_lanes, n) + (1 if size >= 2 and n >= 5 else 0)
			sets = _subsets(mini(c, n - 1), n)
		Kind.LIGHTNING:
			if size >= 3:
				var all: Array[int] = []
				for l: int in n:
					all.append(l)
				return [all]
			var c: int = n - 1 if size >= 2 else TheHouseTuning.per_lanes(tuning.fence_lanes, n)
			sets = _runs(mini(c, n - 1), n)
	var hit: Array = []
	var miss: Array = []
	for s: Array in sets:
		if s.has(pl):
			hit.append(s)
		else:
			miss.append(s)
	_shuffle(hit)
	_shuffle(miss)
	return hit + miss


## Every run of `c` neighbouring lanes.
static func _runs(c: int, n: int) -> Array:
	var out: Array = []
	for first: int in range(0, n - c + 1):
		var s: Array[int] = []
		for l: int in range(first, first + c):
			s.append(l)
		out.append(s)
	return out


## Every set of `c` lanes (in lane order).
static func _subsets(c: int, n: int) -> Array:
	var out: Array = []
	for mask: int in range(1 << n):
		var s: Array[int] = []
		for l: int in n:
			if mask & (1 << l):
				s.append(l)
		if s.size() == c:
			out.append(s)
	return out


func _shuffle(list: Array) -> void:
	for i: int in range(list.size() - 1, 0, -1):
		var j: int = boss.rng.randi_range(0, i)
		var t: Variant = list[i]
		list[i] = list[j]
		list[j] = t


# --- Strikes -------------------------------------------------------------------------------------

## Shows a planned strike's warning now and schedules its hazards.
func _reveal(plan: Dictionary) -> void:
	count += 1
	last_reveal = clock
	var kind: int = int(plan["kind"])
	var s: Dictionary = plan.duplicate()
	s.erase("route")
	s["n"] = count
	s["attack"] = int(current["n"]) if not current.is_empty() else 0
	s["reveal"] = clock
	s["d0"] = world.player.distance
	s["state"] = "warn"
	s["nodes"] = []
	var at: float = float(s["at"])
	var p: float = boss.pace()
	match kind:
		Kind.CHERRY:
			s["land"] = clock + (tuning.cherry_warning - tuning.arrival_seconds)
			s["circles"] = []
			s["bombs"] = []
			var chute: Vector3 = boss.body.chute_world()
			for lane: int in s["lanes"]:
				(s["circles"] as Array).append(boss.props.circle_warning(at, lane, tuning.blast_radius))
				(s["bombs"] as Array).append({"bomb": _free_bomb(chute), "lane": lane, "from": chute})
			boss.sound(&"house_cherry", chute)
			s["whistle_at"] = maxf(clock, float(s["land"]) - _whistle)
			s["whistled"] = false
		Kind.LIGHTNING:
			s["land"] = clock + (tuning.fence_warning - tuning.fence_on_lead)
			var lanes: Array = s["lanes"]
			s["from_side"] = -1 if boss.rng.randf() < 0.5 else 1
			s["fences"] = []
			for lane: int in lanes:
				(s["fences"] as Array).append(boss.props.fence(lane, at, String(s["variant"]),
					maxf(float(s["land"]) - clock, 0.05)))
			s["spool"] = _free_spool()
			_update_fence(s)
			boss.sound(&"house_lightning", world.lane_point(int(lanes[0]), at, 1.0))
		Kind.BAR:
			s["land"] = clock + (tuning.bar_warning - tuning.bar_slam_lead)
			s["warnings"] = []
			s["blocks"] = []
			for lane: int in s["lanes"]:
				(s["warnings"] as Array).append(boss.props.lane_warning(lane, at - 0.5, at + tuning.block_depth + 0.5))
				var block: Dictionary = _free_block()
				(block["look"] as Node3D).global_position = Vector3(world.geo.lane_x(lane), DROP_HEIGHT,
					TrackGeometry.world_z(at + tuning.block_depth * 0.5))
				(s["blocks"] as Array).append({"lane": lane, "block": block})
			boss.sound(&"house_bar", boss.body.chute_world())
	strikes.append(s)
	boss.log_event(&"strike", {"kind": kind_name(kind), "size": int(s["size"]), "lanes": (s["lanes"] as Array).duplicate(),
		"at": at, "d0": float(s["d0"]), "warning": float(s["land"]) - clock, "pace": p, "n": count,
		"variant": String(s.get("variant", ""))})


func _update_strikes() -> void:
	var d: float = world.player.distance
	for i: int in range(strikes.size() - 1, -1, -1):
		var s: Dictionary = strikes[i]
		match int(s["kind"]):
			Kind.CHERRY:
				_update_cherry(s)
			Kind.LIGHTNING:
				_update_fence(s)
			Kind.BAR:
				_update_bar(s)
		# Gone once the runner is well past it.
		if s["state"] != "warn" and float(s["at"]) + 8.0 < d:
			s["state"] = "over"
		if s["state"] == "over" and float(s["at"]) + BossProps.KEEP_BEHIND < d:
			_retire(s)
			strikes.remove_at(i)


func _update_cherry(s: Dictionary) -> void:
	var land: float = float(s["land"])
	var at: float = float(s["at"])
	if s["state"] == "warn":
		for b: Dictionary in s["bombs"]:
			_place_bomb(b["bomb"], b["from"], world.lane_point(int(b["lane"]), at, 0.3), float(s["reveal"]), land)
		if not s["whistled"] and clock >= float(s["whistle_at"]):
			s["whistled"] = true
			boss.sound(&"bomb_whistle", world.lane_point(int((s["lanes"] as Array)[0]), at, 1.0))
		if clock >= land - 0.0001:
			s["state"] = "struck"
			for c: Node in s["circles"]:
				boss.props.remove(c)
			# The bombs go back to the pool (another volley may take them before this strike retires).
			for b: Dictionary in s["bombs"]:
				(b["bomb"] as Node3D).visible = false
			s["bombs"] = []
			for lane: int in s["lanes"]:
				_blast(lane, at, int(s["n"]))


func _update_fence(s: Dictionary) -> void:
	var land: float = float(s["land"])
	var spool: MeshInstance3D = s.get("spool")
	if s["state"] == "warn":
		var k: float = clampf((clock - float(s["reveal"])) / maxf(land - float(s["reveal"]), 0.05), 0.0, 1.0)
		if spool != null:
			var lanes: Array = s["lanes"]
			var side: int = int(s["from_side"])
			var first: int = int(lanes[0]) if side < 0 else int(lanes[-1])
			var last: int = int(lanes[-1]) if side < 0 else int(lanes[0])
			var x0: float = world.geo.lane_x(first) - side * world.geo.lane_width * 0.5
			var x1: float = world.geo.lane_x(last) + side * world.geo.lane_width * 0.5
			var x: float = lerpf(x0, x1, smoothstep(0.0, 1.0, k))
			spool.global_position = Vector3(x, 0.45, TrackGeometry.world_z(float(s["at"])))
			spool.rotation = Vector3(0.0, 0.0, -side * (x - x0) / 0.45)
		if clock >= land - 0.0001:
			s["state"] = "struck"
			boss.log_event(&"fence_on", {"n": int(s["n"]), "at": float(s["at"])})
			if spool != null:
				spool.visible = false
			s["spool"] = null


func _update_bar(s: Dictionary) -> void:
	var land: float = float(s["land"])
	var at: float = float(s["at"])
	if s["state"] != "warn":
		return
	# The blocks fall from high above, ever faster, landing at the slam.
	var fall: float = clampf((clock - float(s["reveal"])) / maxf(land - float(s["reveal"]), 0.05), 0.0, 1.0)
	for b: Dictionary in s["blocks"]:
		(b["block"]["look"] as Node3D).global_position = Vector3(world.geo.lane_x(int(b["lane"])),
			DROP_HEIGHT * (1.0 - fall * fall), TrackGeometry.world_z(at + tuning.block_depth * 0.5))
	if clock >= land - 0.0001:
		s["state"] = "struck"
		for w: Node in s["warnings"]:
			boss.props.remove(w)
		var size := Vector3(world.geo.lane_width * tuning.block_width_share, tuning.block_height, tuning.block_depth)
		for b: Dictionary in s["blocks"]:
			_slam_block(b["block"], int(b["lane"]), at, size)
			world.effects.burst(world.lane_point(int(b["lane"]), at + size.z * 0.5, 0.3), GOLD, 18, 0.7)
		var near: float = clampf(1.0 - (at - world.player.distance) / 40.0, 0.25, 1.0)
		world.effects.shake(0.35 * near, 0.3)
		boss.sound(&"house_slam", world.lane_point(int((s["lanes"] as Array)[0]), at, 0.5))
		boss.log_event(&"slam", {"n": int(s["n"]), "at": at})


func _retire(s: Dictionary) -> void:
	for key: String in ["circles", "warnings", "fences"]:
		for node: Variant in s.get(key, []):
			if is_instance_valid(node):
				boss.props.remove(node as Node)
	for b: Dictionary in s.get("bombs", []):
		(b["bomb"] as Node3D).visible = false
	for b: Dictionary in s.get("blocks", []):
		_put_away_block(b["block"])
	var spool: MeshInstance3D = s.get("spool")
	if spool != null:
		spool.visible = false
	s["spool"] = null


# --- Bombs and blasts ----------------------------------------------------------------------------

## A bomb lobbed from the chute to its circle: a high arc, landing at the blast.
func _place_bomb(bomb: MeshInstance3D, from: Vector3, to: Vector3, t0: float, t1: float) -> void:
	var s: float = clampf((clock - t0) / maxf(t1 - t0, 0.01), 0.0, 1.0)
	var apex: float = maxf(from.y, to.y) + 9.0
	var y: float = lerpf(from.y, to.y, s) + 4.0 * (apex - lerpf(from.y, to.y, 0.5)) * s * (1.0 - s)
	bomb.visible = true
	bomb.global_position = Vector3(lerpf(from.x, to.x, s), y, lerpf(from.z, to.z, s))
	bomb.rotation = Vector3(s * 9.0, s * 4.0, 0.0)


## A blast: its hitbox burns for blast_seconds (a little smaller than the fireball, clear of a wall
## runner); the fireball, sparks, the boom and a shake.
func _blast(lane: int, at: float, n: int) -> void:
	var geo: TrackGeometry = world.geo
	var half: float = geo.lane_width * tuning.blast_width_share * 0.5
	var x: float = geo.lane_x(lane)
	var reach: float = geo.wall_x() - world.tuning.hurtbox_size.y - 0.05
	var x0: float = maxf(x - half, -reach)
	var x1: float = minf(x + half, reach)
	var hazard: Hazard = _free_hazard()
	var size := Vector3(x1 - x0, tuning.blast_height, tuning.blast_depth)
	hazard.size = size
	((hazard.get_child(0) as CollisionShape3D).shape as BoxShape3D).size = size
	hazard.global_position = Vector3((x0 + x1) * 0.5, size.y * 0.5, TrackGeometry.world_z(at))
	hazard.collision_layer = TrackBuilder.LAYER_HAZARD
	hazard.set_enabled(true)
	var fire: MeshInstance3D = _free_fire()
	fire.global_position = Vector3(x, 0.6, TrackGeometry.world_z(at))
	fire.visible = true
	_blasts.append({"hazard": hazard, "fire": fire, "start": clock, "n": n})
	var center := Vector3(x, 0.8, TrackGeometry.world_z(at))
	world.effects.burst(center, FIRE, 36, 1.0)
	world.effects.burst(center + Vector3(0.0, 0.4, 0.0), FIRE_HOT, 14, 0.6)
	var near: float = clampf(1.0 - (at - world.player.distance) / 40.0, 0.2, 1.0)
	world.effects.shake(0.25 * near, 0.25)
	boss.sound(&"bomb_blast", center)
	boss.log_event(&"blast", {"lane": lane, "at": at, "n": n})


func _update_blasts() -> void:
	for i: int in range(_blasts.size() - 1, -1, -1):
		var b: Dictionary = _blasts[i]
		var age: float = clock - float(b["start"])
		var hazard: Hazard = b["hazard"]
		if hazard.is_active() and age >= tuning.blast_seconds - 0.0001:
			hazard.set_enabled(false)
			hazard.collision_layer = 0
		var fire: MeshInstance3D = b["fire"]
		if age >= FIRE_SECONDS:
			fire.visible = false
			if not hazard.is_active():
				_blasts.remove_at(i)
			continue
		var k: float = age / FIRE_SECONDS
		var r: float = tuning.blast_radius * (0.4 + 0.6 * (1.0 - pow(1.0 - minf(age / 0.12, 1.0), 3.0)))
		fire.scale = Vector3(r, r * 1.2, r)
		var hot: float = clampf(1.0 - age / 0.08, 0.0, 1.0) * (0.4 if Settings.flashing_reduced else 0.8)
		var color: Color = FIRE.lerp(FIRE_HOT, hot) * (1.0 - k * k) * 0.95
		(fire.material_override as StandardMaterial3D).albedo_color = Color(color.r, color.g, color.b, 1.0)


## The live blasts' hitboxes (tests).
func blast_hazards() -> Array[Hazard]:
	var out: Array[Hazard] = []
	for b: Dictionary in _blasts:
		if (b["hazard"] as Hazard).is_active():
			out.append(b["hazard"])
	return out


## The gold blocks standing now (tests).
func block_hazards() -> Array[Hazard]:
	var out: Array[Hazard] = []
	for b: Dictionary in _blocks:
		if b["used"] and (b["hazard"] as Hazard).is_active():
			out.append(b["hazard"])
	return out


## The pools: what each holds and how many times it was drawn on ({bombs, fires, blast_boxes, blocks,
## spools: [made, taken]}).
func pool_stats() -> Dictionary:
	return {"bombs": [_bombs.size(), int(_taken.get(&"bombs", 0))], "fires": [_fires.size(), int(_taken.get(&"fires", 0))],
		"blast_boxes": [_blast_boxes.size(), int(_taken.get(&"blast_boxes", 0))],
		"blocks": [_blocks.size(), int(_taken.get(&"blocks", 0))], "spools": [_spools.size(), int(_taken.get(&"spools", 0))]}


func _took(pool: StringName) -> void:
	_taken[pool] = int(_taken.get(pool, 0)) + 1


## A cherry bomb from the pool, shown at `from` (the coin chute): shown, it's taken (a volley's bombs are
## each its own) until its strike puts it away.
func _free_bomb(from: Vector3) -> MeshInstance3D:
	_took(&"bombs")
	var bomb: MeshInstance3D = null
	for b: MeshInstance3D in _bombs:
		if not b.visible:
			bomb = b
			break
	if bomb == null:
		bomb = _new_bomb()
	bomb.global_position = from
	bomb.visible = true
	return bomb


func _new_bomb() -> MeshInstance3D:
	var bomb := MeshInstance3D.new()
	bomb.name = "CherryBomb"
	bomb.mesh = bomb_mesh()
	bomb.material_override = TheHouseModel.solid_material(world.skin)
	bomb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bomb.visible = false
	add_child(bomb)
	_bombs.append(bomb)
	return bomb


func _free_hazard() -> Hazard:
	_took(&"blast_boxes")
	for h: Hazard in _blast_boxes:
		if not h.is_active() and not _burning(h):
			return h
	return _new_blast_box()


## A blast's box: off, and out of every query (no layer), until a blast burns in it.
func _new_blast_box() -> Hazard:
	var hazard := Hazard.new()
	hazard.name = "Blast"
	hazard.hazard_name = BOMB_NAME
	hazard.is_enemy_attack = true
	hazard.part = &"attack"
	hazard.collision_layer = 0
	hazard.collision_mask = 0
	hazard.monitoring = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3.ONE
	shape.shape = box
	hazard.add_child(shape)
	add_child(hazard)
	hazard.set_enabled(false)
	_blast_boxes.append(hazard)
	return hazard


func _burning(h: Hazard) -> bool:
	for b: Dictionary in _blasts:
		if b["hazard"] == h:
			return true
	return false


func _free_fire() -> MeshInstance3D:
	_took(&"fires")
	for f: MeshInstance3D in _fires:
		if not f.visible:
			return f
	return _new_fire()


func _new_fire() -> MeshInstance3D:
	var fire := MeshInstance3D.new()
	fire.name = "Fireball"
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 12
	sphere.rings = 6
	fire.mesh = sphere
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color.BLACK
	m.disable_receive_shadows = true
	fire.material_override = m
	fire.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fire.visible = false
	add_child(fire)
	_fires.append(fire)
	return fire


# --- Looks ---------------------------------------------------------------------------------------

## A cherry bomb: two enemy-red cherries on a dark stem with a glowing fuse tip.
static func bomb_mesh() -> ArrayMesh:
	if _bomb_mesh != null:
		return _bomb_mesh
	var batch := MeshBatch.new()
	var m: MeshLayer = batch.layer(TheHouseModel.solid_material())
	for side: int in [-1, 1]:
		var c := Vector3(side * 0.32, 0.0, 0.0)
		m.prism(c + Vector3(0.0, -0.36, 0.0), 0.26, 0.12, 10, ATTACK_RED, 0.6)
		m.prism(c + Vector3(0.0, -0.24, 0.0), 0.38, 0.48, 10, ATTACK_RED, 0.6)
		m.prism(c + Vector3(0.0, 0.24, 0.0), 0.26, 0.12, 10, ATTACK_RED, 0.6)
	m.prism_xform(Transform3D(Basis(Vector3.BACK, 0.35) * Basis.from_scale(Vector3(0.05, 0.75, 0.05)), Vector3(-0.32, 0.3, 0.0)), 6,
		Color(0.12, 0.2, 0.08))
	m.prism_xform(Transform3D(Basis(Vector3.BACK, -0.35) * Basis.from_scale(Vector3(0.05, 0.75, 0.05)), Vector3(0.32, 0.3, 0.0)), 6,
		Color(0.12, 0.2, 0.08))
	m.box(Vector3(0.0, 1.0, 0.0), Vector3(0.14, 0.14, 0.14), Color(1.0, 0.9, 0.7), 1.0)
	_bomb_mesh = batch.to_mesh()
	return _bomb_mesh


## A gold block from the pool, its look sized by tuning (shown, falling from high above), its hazard
## still off.
func _free_block() -> Dictionary:
	_took(&"blocks")
	var size := Vector3(world.geo.lane_width * tuning.block_width_share, tuning.block_height, tuning.block_depth)
	var block: Dictionary = {}
	for b: Dictionary in _blocks:
		if not b["used"]:
			block = b
			break
	if block.is_empty():
		block = _new_block()
	block["used"] = true
	var look: MeshInstance3D = block["look"]
	look.mesh = _block_mesh(size)
	look.visible = true
	return block


## A gold block for the pool: its hazard off with no layers, its look hidden (its mesh built now).
func _new_block() -> Dictionary:
	var hazard := Hazard.new()
	hazard.name = "GoldBlock"
	hazard.hazard_name = BLOCK_NAME
	hazard.is_solid = true
	hazard.collision_layer = 0
	hazard.collision_mask = 0
	hazard.monitoring = false
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	hazard.add_child(shape)
	var blocker := Area3D.new()
	blocker.collision_layer = 0
	blocker.collision_mask = 0
	blocker.monitoring = false
	var blocker_shape := CollisionShape3D.new()
	blocker_shape.shape = BoxShape3D.new()
	blocker.add_child(blocker_shape)
	hazard.add_child(blocker)
	add_child(hazard)
	hazard.set_enabled(false)
	var look := MeshInstance3D.new()
	look.name = "GoldBlockLook"
	look.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	look.mesh = _block_mesh(Vector3(world.geo.lane_width * tuning.block_width_share, tuning.block_height, tuning.block_depth))
	# Lit like the machine, with its arena's warm light (the cached mesh keeps the default).
	look.material_override = TheHouseModel.solid_material(world.skin)
	look.visible = false
	add_child(look)
	var block := {"hazard": hazard, "blocker": blocker, "look": look, "used": false}
	_blocks.append(block)
	return block


## Slams a block down in `lane` at `at`: its look at rest, its hazard (and lane blocker) on where it stands.
func _slam_block(block: Dictionary, lane: int, at: float, size: Vector3) -> void:
	var center := Vector3(world.geo.lane_x(lane), size.y * 0.5, TrackGeometry.world_z(at + size.z * 0.5))
	var hazard: Hazard = block["hazard"]
	var blocker: Area3D = block["blocker"]
	hazard.size = size
	((hazard.get_child(0) as CollisionShape3D).shape as BoxShape3D).size = size
	((blocker.get_child(0) as CollisionShape3D).shape as BoxShape3D).size = size
	hazard.global_position = center
	hazard.collision_layer = TrackBuilder.LAYER_HAZARD
	blocker.collision_layer = TrackBuilder.LAYER_LANE_BLOCKER
	hazard.set_enabled(true)
	(block["look"] as Node3D).global_position = Vector3(center.x, 0.0, center.z)


## Puts a block back in the pool: off, out of every query, hidden.
func _put_away_block(block: Dictionary) -> void:
	if not block.get("used", false):
		return
	block["used"] = false
	var hazard: Hazard = block["hazard"]
	hazard.set_enabled(false)
	hazard.collision_layer = 0
	(block["blocker"] as Area3D).collision_layer = 0
	(block["look"] as Node3D).visible = false


## A gold block's look (a heavy ingot with red-hot edges: deadly, never a doodad), one mesh per size.
static func _block_mesh(size: Vector3) -> ArrayMesh:
	var key: String = str(size)
	if not _block_mesh_cache.has(key):
		var batch := MeshBatch.new()
		var m: MeshLayer = batch.layer(TheHouseModel.solid_material())
		var hw: float = size.x * 0.5
		var hd: float = size.z * 0.5
		m.box(Vector3(0.0, size.y * 0.5, 0.0), Vector3(size.x * 0.92, size.y, size.z * 0.92), GOLD, 0.0, MeshKit.PAT_PLAIN,
			MeshKit.NO_BOTTOM)
		# A bevelled cap, and red-hot seams round its foot and top (it's an attack: deadly to run into).
		m.box(Vector3(0.0, size.y + 0.05, 0.0), Vector3(size.x * 0.8, 0.1, size.z * 0.8), GOLD.lightened(0.15))
		for y: float in [0.06, size.y - 0.06]:
			m.box(Vector3(0.0, y, hd * 0.92), Vector3(size.x * 0.94, 0.12, 0.04), ATTACK_RED, 1.0)
			m.box(Vector3(0.0, y, -hd * 0.92), Vector3(size.x * 0.94, 0.12, 0.04), ATTACK_RED, 1.0)
			m.box(Vector3(hw * 0.92, y, 0.0), Vector3(0.04, 0.12, size.z * 0.94), ATTACK_RED, 1.0)
			m.box(Vector3(-hw * 0.92, y, 0.0), Vector3(0.04, 0.12, size.z * 0.94), ATTACK_RED, 1.0)
		# "BAR" stamped on its face: three dark bars.
		for k: int in 3:
			m.box(Vector3(0.0, size.y * (0.35 + 0.15 * k), hd * 0.93), Vector3(size.x * 0.5, 0.12, 0.03), Color(0.3, 0.2, 0.05))
		_block_mesh_cache[key] = batch.to_mesh()
	return _block_mesh_cache[key]


## The fence's spool from the pool (shown, it's taken): a drum with fence-pink glowing caps that rolls
## across the lanes unrolling it.
func _free_spool() -> MeshInstance3D:
	_took(&"spools")
	for sp: MeshInstance3D in _spools:
		if not sp.visible:
			sp.visible = true
			return sp
	var spool: MeshInstance3D = _new_spool()
	spool.visible = true
	return spool


func _new_spool() -> MeshInstance3D:
	if _spool_mesh == null:
		var batch := MeshBatch.new()
		var m: MeshLayer = batch.layer(TheHouseModel.solid_material())
		var xform := Transform3D(Basis(Vector3.FORWARD, PI * 0.5) * Basis.from_scale(Vector3(0.42, 0.5, 0.42)), Vector3(-0.25, 0.0, 0.0))
		m.prism_xform(xform, 10, Color(0.25, 0.25, 0.28))
		for x: float in [-0.3, 0.3]:
			var cap := Transform3D(Basis(Vector3.FORWARD, PI * 0.5) * Basis.from_scale(Vector3(0.46, 0.06, 0.46)), Vector3(x - 0.03, 0.0, 0.0))
			m.prism_xform(cap, 10, FENCE_PINK, 1.0)
		_spool_mesh = batch.to_mesh()
	var node := MeshInstance3D.new()
	node.name = "Spool"
	node.mesh = _spool_mesh
	# Lit like the machine, with its arena's warm light (the cached mesh keeps the default).
	node.material_override = TheHouseModel.solid_material(world.skin)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.visible = false
	add_child(node)
	_spools.append(node)
	return node
