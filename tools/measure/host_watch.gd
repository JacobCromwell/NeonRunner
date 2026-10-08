extends RefCounted
## Follows the host cyborgs and the Cyborg's Bad Dreams in a run (GDD §9.7; task H8: weapons hit hosts, owner,
## October 8, 2026), for tools/measure/host_releases.gd and the tests (test_host_releases.gd): where each host
## died and what killed it, and where its Bad Dream's chase began and ended, by the runner's distance. It reads
## the enemies' own states (a chase is on while its Bad Dream reports its big attack, Enemy.is_major_attack_active;
## its telegraphs and slashes from its state), never the generator's rules it's measured against (check()).
##   const HostWatch = preload("res://tools/measure/host_watch.gd")
##   var watch := HostWatch.new(world)     # before the enemies spawn
##   ... every physics frame: await tree.physics_frame; watch.observe()
##   watch.chases; watch.check(gen) (gen: LevelGenerator.for_layout over the run's layout)
##
## check() holds each chase that ran to the guarantees the generator plans a host's chase with (host_rules.gd,
## from the host's spot in the layout, BadDreamTuning.chase_stretch):
## - its anti-grav pads: never more than pad_gap_seconds of run without a pad (any lane), from where the chase
##   began to where it ended (`pad_gap`), and from its first slash's claws (`pad_gap_claws`);
## - where it ran: how far before the planned stretch it began (`early`, metres) and after it ended (`late`);
## - what the generator kept off the planned stretch for reasons of their own (`kept`): zone doodads, a floor
##   cut's attack (FloorCutPlan.attack_window), a wall fence's drop window, an Octodog's charges (floor_span), a
##   Gilded Sentinel's attack and a cyborg planted in a charge's path (task G7), wherever the chase ran outside
##   the planned stretch (inside it they're kept off by plan, LayoutChecks);
## - the others: a chase that fizzled because another Bad Dream was still about (`fizzled`: GDD §9.7, one at a
##   time), chases that overlap each other, and the big attacks on when a chase began (`others_on`: an Octodog
##   charge sequence or a drone barrage then makes the Bad Dream hold its slash, EnemyDirector).

const HostRules = preload("res://scripts/enemies/host_rules.gd")
const SentinelRules = preload("res://scripts/enemies/gilded_sentinel_rules.gd")
## Metres within which a host counts as reached for stomp_hosts (as AttackWatch.stomp_hosts).
const STOMP_REACH: float = 2.5

var world: RunWorld
## The runner stomps every host it reaches that's still alive (AttackWatch.stomp_hosts does the same; use one
## of them), so every host releases its Bad Dream: by the weapon if it got there first, else by the stomp.
var stomp_hosts: bool = false
## One per host defeated, in order: {host_at: the host's spot in the layout (where the generator planned its
## chase from), lane, cause, kill_d: the runner's distance at the kill, kill_t (level time), host_d: where the
## host stood then, dream: whether its Bad Dream was spawned, fizzled, begin_d and begin_t: where and when its
## chase began (-1: never), others_on: the other types whose big attack was on then, telegraph_d: the runner's
## distance at its first telegraph (-1: none), telegraph_ahead: how far ahead of the runner the Bad Dream was
## then, claws_d: the runner's distance at its first slash's claws (-1: none), slashes, end_d and end_t: where
## and when its chase ended (-1: still on when the run stopped), emp: an EMP dissolved it}.
var chases: Array[Dictionary] = []

## Bad Dream instance id -> its chase's index; host instance id -> its chase's index.
var _by_dream: Dictionary = {}
var _dreams: Dictionary = {}
var _hosts: Dictionary = {}


func _init(p_world: RunWorld, p_stomp_hosts: bool = false) -> void:
	world = p_world
	stomp_hosts = p_stomp_hosts
	world.director.enemy_defeated.connect(_on_defeated)
	world.director.enemy_spawned.connect(_on_spawned)


## Looks at the run once; call it every physics frame.
func observe() -> void:
	var p: Player = world.player
	var now: float = world.level_time()
	for e: Enemy in world.director.active:
		if stomp_hosts and is_instance_valid(e) and e.alive and e.is_host:
			var ahead: float = e.track_distance() - p.distance
			if ahead > 0.0 and ahead < STOMP_REACH:
				e.defeat(&"stomp")
	for id: int in _dreams.keys():
		var c: Dictionary = chases[int(_by_dream[id])]
		var o: Object = instance_from_id(id)
		var dream: BadDream = o as BadDream if is_instance_valid(o) else null
		if dream != null and not bool(c["fizzled"]):
			c["fizzled"] = _seen(dream, "fizzle")
		var on: bool = dream != null and dream.alive and dream.is_major_attack_active()
		if on and float(c["begin_d"]) < 0.0:
			c["begin_d"] = p.distance
			c["begin_t"] = now
			var types: PackedStringArray = []
			for e: Enemy in world.director.active:
				if is_instance_valid(e) and e != dream and e.alive and e.is_major_attack_active() \
						and not types.has(String(e.type_id)):
					types.append(String(e.type_id))
			c["others_on"] = types
		if dream != null and float(c["telegraph_d"]) < 0.0 and dream.state == BadDream.State.TELEGRAPH:
			c["telegraph_d"] = p.distance
			c["telegraph_ahead"] = dream.rel_ahead
		if dream != null and float(c["claws_d"]) < 0.0 and dream.slashes > 0:
			c["claws_d"] = p.distance
		if dream != null:
			c["slashes"] = dream.slashes
			c["emp"] = bool(c["emp"]) or _seen(dream, "emp")
		if float(c["begin_d"]) >= 0.0 and not on:
			c["end_d"] = p.distance
			c["end_t"] = now
		if dream == null or (float(c["end_d"]) >= 0.0) or bool(c["fizzled"]):
			_dreams.erase(id)


## Holds each chase to the generator's guarantees (see the header). `gen` is a generator over the run's layout
## (LevelGenerator.for_layout, at the level's run speed). Returns {chases: each chase with its numbers added
## (planned: the planned stretch, early, late, pad_gap, pad_gap_claws in seconds at run speed, kept: what the
## generator kept off its stretch that it met outside it), fizzled, overlapping (chases that overlap the next
## one), released (chases that began)}.
func check(gen: LevelGenerator) -> Dictionary:
	var t: BadDreamTuning = HostRules.tuning()
	var speed: float = gen.speed
	var layout: LevelLayout = gen.layout
	var pads: Array[float] = []
	for pad: Dictionary in layout.pads:
		pads.append(float(pad["at"]))
	pads.sort()
	var kept: Array[Dictionary] = kept_off_chases(gen)
	var out: Array[Dictionary] = []
	var fizzled: int = 0
	var overlapping: int = 0
	var released: int = 0
	var last_end: float = -INF
	for c: Dictionary in chases:
		var r: Dictionary = c.duplicate()
		if bool(c["fizzled"]):
			fizzled += 1
		var begin: float = float(c["begin_d"])
		if begin < 0.0:
			out.append(r)
			continue
		released += 1
		var end: float = float(c["end_d"]) if float(c["end_d"]) >= 0.0 else world.player.distance
		var plan: Vector2 = t.chase_stretch(float(c["host_at"]), speed)
		r["planned"] = plan
		r["early"] = maxf(plan.x - begin, 0.0)
		r["late"] = maxf(end - plan.y, 0.0)
		r["pad_gap"] = pad_gap(pads, begin, end) / speed
		var claws: float = float(c["claws_d"])
		r["pad_gap_claws"] = pad_gap(pads, claws, end) / speed if claws >= 0.0 else 0.0
		var met: PackedStringArray = []
		for k: Dictionary in kept:
			var span: Vector2 = k["span"]
			var before_plan: bool = span.x < plan.x and span.y >= begin and span.x <= minf(plan.x, end)
			var after_plan: bool = span.y > plan.y and span.x <= end and span.y >= maxf(plan.y, begin)
			if before_plan or after_plan:
				met.append("%s %.0f-%.0f" % [k["what"], span.x, span.y])
		r["kept"] = met
		if begin < last_end:
			overlapping += 1
		last_end = maxf(last_end, end)
		out.append(r)
	return {"chases": out, "fizzled": fizzled, "overlapping": overlapping, "released": released}


## The longest stretch of track (metres) between `from` and `to` with no anti-grav pad (`pads`: their spots,
## sorted), counting from `from` to the first and from the last to `to`.
static func pad_gap(pads: Array[float], from: float, to: float) -> float:
	var longest: float = 0.0
	var last: float = from
	for at: float in pads:
		if at <= from:
			continue
		if at >= to:
			break
		longest = maxf(longest, at - last)
		last = at
	return maxf(longest, to - last)


## What the generator keeps off every planned chase for reasons of its own (see the header), as
## [{what, span: Vector2}] along the track.
static func kept_off_chases(gen: LevelGenerator) -> Array[Dictionary]:
	var layout: LevelLayout = gen.layout
	var out: Array[Dictionary] = []
	for d: Dictionary in layout.doodads:
		out.append({"what": "a doodad", "span": Vector2(float(d["start"]), float(d["end"]))})
	for cut: Dictionary in layout.cuts:
		out.append({"what": "a floor cut's attack", "span": FloorCutPlan.attack_window(cut, gen.speed)})
	for w: Dictionary in layout.wall_fences:
		out.append({"what": "a wall fence's drop window", "span": WallFencePlacement.drop_window(gen, float(w["at"]))})
	for e: Dictionary in layout.enemies:
		var params: Dictionary = e.get("params", {})
		match String(e.get("type", "")):
			"octodog":
				if params.get("floor_span") is Vector2:
					out.append({"what": "an Octodog's charges", "span": params["floor_span"]})
			"cyborg":
				if params.has(ChargePathPlacement.PARAM) and params.get("hold_fire") is Vector2:
					out.append({"what": "a cyborg planted in a charge's path", "span": params["hold_fire"]})
	if gen.config.has_feature("gilded_sentinel"):
		for k: Dictionary in SentinelRules.doodad_keep_outs(gen):
			out.append({"what": "a Gilded Sentinel's attack", "span": Vector2(float(k["from"]), float(k["to"]))})
	return out


func _on_defeated(e: Enemy, cause: StringName) -> void:
	if not e.is_host or _hosts.has(e.get_instance_id()):
		return
	_hosts[e.get_instance_id()] = chases.size()
	chases.append({"host_at": float(e.spawn.get("at", 0.0)), "lane": int(e.spawn.get("lane", 0)),
		"seed": int(e.spawn.get("seed", 0)), "cause": String(cause), "kill_d": world.player.distance,
		"kill_t": world.level_time(), "host_d": e.track_distance(), "dream": false, "fizzled": false,
		"begin_d": -1.0, "begin_t": -1.0, "others_on": PackedStringArray(), "telegraph_d": -1.0, "telegraph_ahead": -1.0, "claws_d": -1.0,
		"slashes": 0, "end_d": -1.0, "end_t": -1.0, "emp": false})


func _on_spawned(e: Enemy) -> void:
	if not e is BadDream:
		return
	# Its host's: the Bad Dream's seed is made from its host's (Cyborg._release_bad_dream).
	var dream_seed: int = int(e.spawn.get("seed", 0))
	for i: int in range(chases.size() - 1, -1, -1):
		var c: Dictionary = chases[i]
		if not bool(c["dream"]) and hash([c["seed"], "bad_dream"]) == dream_seed:
			c["dream"] = true
			_by_dream[e.get_instance_id()] = i
			_dreams[e.get_instance_id()] = true
			c["fizzled"] = _seen(e as BadDream, "fizzle")
			return


static func _seen(dream: BadDream, event: String) -> bool:
	for h: Array in dream.history:
		if h[0] == event:
			return true
	return false
