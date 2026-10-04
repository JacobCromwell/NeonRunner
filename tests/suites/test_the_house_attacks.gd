extends TestSuite
## The House's attacks (GDD §10; task E5a-a: "each attack strikes only where and when its warning said,
## and has an escape"; "two and three of a kind"; "a 3-lane mix of cherry bombs plus BAR blocks must
## still leave a way through"), at 3, 5 and 6 lanes, at the reference 18 m/s and the Marketplace's
## 22.6 m/s, on its real arena, with spins that show every symbol and every size (no buttons):
## - every strike's warning shows from its reveal where it will hit (the cherry bombs' target circles and
##   the BAR rows' red lanes as floor warnings, the fence flickering harmlessly in its lanes), with its
##   sound; what hits then is exactly that: blasts in those lanes at that spot when the bombs land, blocks
##   slammed there, the fence switched on there; nothing hits anywhere else; every warning gives the
##   runner at least its time;
## - the bigger versions: two cherries two volleys, three three, wider at 5 and 6 lanes; two BARs two rows,
##   three three; two lightnings across every lane but one, three two rows across every lane, a full-height
##   fence then a gapped one;
## - every attack has an escape: a runner who reads the warnings (TheHouseBot, reacting REACTION late, no
##   god mode, no armor) gets through every spin alive, always finding a way;
## - the 3-lane mix of cherry bombs and BAR blocks leaves a way through;
## - the citizens duck at a big attack;
## - the spin lists of all three phases, over a few seeds, at every lane count and speed: the runner lives;
## - a volley's bombs and a row's blocks are each their own, and what attacks show is pooled: bombs,
##   blocks, spools and blasts are reused from strike to strike, nothing made anew once the pools fit a spin.

const BOSS_PATH: String = "res://data/bosses/marketplace_boss.tres"
const LANES: Array[int] = [3, 5, 6]
const SPEEDS: Array[float] = [18.0, 22.6]
const REACTION: float = 0.35
## Spins showing every attack at every size: three singles, three pairs, three triples.
const EVERY_SIZE: String = "cherry,bar,lightning|cherry,cherry,bar|bar,bar,lightning|lightning,lightning,cherry|cherry,cherry,cherry|bar,bar,bar|lightning,lightning,lightning"
## A warning shows at least this long before its strike hits (cherry: the bombs land; BAR: the blocks
## slam; lightning: the fence switches on), and the runner reaches it this long after its reveal at least.
const MIN_TELEGRAPH: float = 0.6
const MIN_REACH: float = 1.2

var sim: RunSim
var def: BossDef


func run() -> void:
	sim = RunSim.new(tree, tuning)
	var slot := load(BOSS_PATH) as BossDef
	def = slot if slot != null and slot.is_built() else null
	if def == null:
		check(false, "The House's fight loads")
		return
	for lanes: int in LANES:
		for speed: float in SPEEDS:
			await _test_every_size(lanes, speed)
	await _test_three_lane_mix()
	await _test_lists()


## A copy of the slot with these spins in every phase and no buttons.
func _attacks_only(spins: String, seed_value: int = -1) -> BossDef:
	var out: BossDef = def.duplicate() as BossDef
	var t: TheHouseTuning = (def.tuning as TheHouseTuning).duplicate() as TheHouseTuning
	if spins != "":
		t.spin_patterns = PackedStringArray([spins, spins, spins])
	t.opening_spins = PackedInt32Array([1000])
	out.tuning = t
	if seed_value >= 0:
		out.arena = def.arena.duplicate() as LevelConfig
		out.arena.level_seed = seed_value
	return out


## The fight at `lanes` and `speed`: [world, boss].
func _fight(p_def: BossDef, lanes: int, speed: float) -> Array:
	var boss := BossEncounter.create(p_def) as TheHouse
	var t: MovementTuning = tuning
	if not is_equal_approx(speed, tuning.run_speed):
		t = tuning.duplicate() as MovementTuning
		t.run_speed = speed
	var ctx := RunContext.new()
	ctx.mode = RunContext.Mode.QUICK
	ctx.boss = p_def
	ctx.config = BossArena.base_config(p_def)
	ctx.config.lane_count = lanes
	ctx.tuning = t
	var arena: BossArena = boss.plan_arena(ctx)
	var world: RunWorld = sim.build_world(arena.layout, null, t, ctx.config)
	boss.setup(world, ctx, arena)
	return [world, boss]


func _events(boss: BossEncounter, event: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in boss.events:
		if e["event"] == event:
			out.append(e)
	return out


## Every spin of `p_def` until `spins` have struck (and their hazards are behind the runner), with the
## bot playing: watches every strike's warning and what hits. Returns {alive, stuck, strikes (the strike
## dictionaries as revealed, with what was seen), problems (strings)}.
func _play(p_def: BossDef, lanes: int, speed: float, spins: int, watch: bool = true) -> Dictionary:
	var pair: Array = _fight(p_def, lanes, speed)
	var world: RunWorld = pair[0]
	var boss: TheHouse = pair[1]
	var bot := TheHouseBot.new(boss)
	bot.reaction = REACTION
	var out := {"alive": true, "stuck": 0, "strikes": [], "problems": [], "boss_events": [], "reactions": {}}
	var seen: Dictionary = {}
	var t: TheHouseTuning = boss.tuning
	await tree.physics_frame
	world.player.running = true
	var frames: int = int((8.0 + spins * 8.0) * 60.0)
	for i: int in frames:
		bot.step()
		await tree.physics_frame
		if not world.player.alive:
			out["alive"] = false
			break
		if not watch:
			if _events(boss, &"spin").size() > spins and not boss.attacks.busy():
				break
			continue
		# Each strike as it's revealed: its warning is on the track where it will hit.
		for s: Dictionary in boss.attacks.strikes:
			var id: int = int(s["n"])
			if seen.has(id):
				continue
			seen[id] = true
			var rec: Dictionary = {"n": id, "kind": int(s["kind"]), "size": int(s["size"]), "lanes": (s["lanes"] as Array).duplicate(),
				"at": float(s["at"]), "variant": String(s.get("variant", "full")), "reveal": float(s["reveal"]), "land": float(s["land"]),
				"d0": float(s["d0"]), "attack": int(s["attack"])}
			(out["strikes"] as Array).append(rec)
			_check_warning(boss, world, s, out["problems"])
		_check_hazards(boss, world, out["problems"])
		if _events(boss, &"spin").size() > spins and not boss.attacks.busy() \
				and boss.attacks.hazards_end() < world.player.distance - 2.0:
			break
	out["stuck"] = bot.stuck
	out["boss_events"] = boss.events.duplicate()
	out["reactions"] = boss.reactions.duplicate()
	out["skipped"] = boss.attacks.skipped
	out["sounds"] = []
	for e: Dictionary in _events(boss, &"sound"):
		(out["sounds"] as Array).append(e["name"])
	out["distance"] = world.player.distance
	out["pools"] = boss.attacks.pool_stats()
	await sim.free_world(world)
	return out


## A strike just revealed: its warning is where it will hit, and gives the runner time.
func _check_warning(boss: TheHouse, world: RunWorld, s: Dictionary, problems: Array) -> void:
	var at: float = float(s["at"])
	var v: float = boss.speed()
	var reach: float = (at - world.player.distance) / v
	if reach < MIN_REACH:
		problems.append("strike %d reaches the runner %.2f s after its warning" % [int(s["n"]), reach])
	if float(s["land"]) - float(s["reveal"]) < MIN_TELEGRAPH:
		problems.append("strike %d hits %.2f s after its warning" % [int(s["n"]), float(s["land"]) - float(s["reveal"])])
	# Each lane's bomb or block is its own, shown from the reveal (one per lane, never shared).
	var own: Dictionary = {}
	for b: Dictionary in s.get("bombs", []):
		if (b["bomb"] as Node3D).visible:
			own[b["bomb"]] = true
	for b: Dictionary in s.get("blocks", []):
		if (b["block"]["look"] as Node3D).visible:
			own[b["block"]["look"]] = true
	if int(s["kind"]) != TheHouseAttacks.Kind.LIGHTNING and own.size() != (s["lanes"] as Array).size():
		problems.append("strike %d shows %d bombs or blocks for %d lanes" % [int(s["n"]), own.size(), (s["lanes"] as Array).size()])
	for lane: int in s["lanes"]:
		match int(s["kind"]):
			TheHouseAttacks.Kind.CHERRY:
				if not boss.props.warned(lane, at - 0.5, at + 0.5):
					problems.append("strike %d: no target circle in lane %d" % [int(s["n"]), lane])
			TheHouseAttacks.Kind.BAR:
				if not boss.props.warned(lane, at, at + boss.tuning.block_depth):
					problems.append("strike %d: no red lane warning in lane %d" % [int(s["n"]), lane])
			TheHouseAttacks.Kind.LIGHTNING:
				var fence: Hazard = _fence_at(boss, world, lane, at)
				if fence == null or fence.state != Hazard.State.WARNING:
					problems.append("strike %d: no fence flickering in lane %d" % [int(s["n"]), lane])
	# Nothing it warns of covers every lane but a fence (jumped or slid under).
	if int(s["kind"]) != TheHouseAttacks.Kind.LIGHTNING and (s["lanes"] as Array).size() >= boss.lane_count():
		problems.append("strike %d covers every lane" % int(s["n"]))


## Every live hazard of its attacks is one a revealed strike warned of, in its lanes and at its spot.
func _check_hazards(boss: TheHouse, world: RunWorld, problems: Array) -> void:
	for h: Hazard in boss.attacks.blast_hazards():
		if not _warned_by(boss, world, h, TheHouseAttacks.Kind.CHERRY):
			problems.append("a blast where no strike warned (x %.1f, at %.1f)" % [h.global_position.x, -h.global_position.z])
	for h: Hazard in boss.attacks.block_hazards():
		if not _warned_by(boss, world, h, TheHouseAttacks.Kind.BAR):
			problems.append("a gold block where no strike warned (x %.1f, at %.1f)" % [h.global_position.x, -h.global_position.z])
	for node: Node in boss.props.get_children():
		var h := node as Hazard
		if h == null or not h.is_active():
			continue
		var kind: int = TheHouseAttacks.Kind.BAR if h.is_solid else TheHouseAttacks.Kind.LIGHTNING
		if not _warned_by(boss, world, h, kind):
			problems.append("a %s where no strike warned (x %.1f, at %.1f)" % [h.hazard_name, h.global_position.x, -h.global_position.z])


## True if a revealed strike of `kind` covers hazard `h` (its lane and its spot).
func _warned_by(boss: TheHouse, world: RunWorld, h: Hazard, kind: int) -> bool:
	var lane: int = world.geo.lane_at(h.global_position.x)
	var at: float = -h.global_position.z
	for s: Dictionary in boss.attacks.strikes:
		if int(s["kind"]) != kind or not (s["lanes"] as Array).has(lane):
			continue
		var from: float = float(s["at"]) - 1.5
		var to: float = float(s["at"]) + (boss.tuning.block_depth if kind == TheHouseAttacks.Kind.BAR else 0.0) + 1.5
		if at >= from and at <= to:
			return true
	return false


func _fence_at(boss: TheHouse, world: RunWorld, lane: int, at: float) -> Hazard:
	for node: Node in boss.props.get_children():
		var h := node as Hazard
		if h != null and not h.is_solid and world.geo.lane_at(h.global_position.x) == lane and absf(-h.global_position.z - at) < 0.5:
			return h
	return null


# --- Every attack, every size ---------------------------------------------------------------------

func _test_every_size(lanes: int, speed: float) -> void:
	var tag: String = "(%d lanes, %.1f m/s)" % [lanes, speed]
	var t := def.tuning as TheHouseTuning
	var r: Dictionary = await _play(_attacks_only(EVERY_SIZE), lanes, speed, 7)
	check(r["alive"] and int(r["stuck"]) == 0, "a runner who reads the warnings gets through every attack alive %s" % tag)
	var problems: Array = r["problems"]
	check(problems.is_empty(), "every strike hits only where and when its warning said %s%s" % [tag,
		"" if problems.is_empty() else ": " + str(problems.slice(0, 3))])
	var strikes: Array = r["strikes"]
	var events: Array = r["boss_events"]
	# What struck matches the warnings: each blast in a warned lane, at its spot, on time; each slam; each
	# fence switched on.
	var mismatched: int = 0
	for e: Dictionary in events:
		match e["event"]:
			&"blast":
				var s: Dictionary = _strike(strikes, int(e["n"]))
				if s.is_empty() or not (s["lanes"] as Array).has(int(e["lane"])) or not is_equal_approx(float(e["at"]), float(s["at"])) \
						or absf(float(e["t"]) - _fight_time_at(events, s, float(s["land"]))) > 0.05:
					mismatched += 1
			&"slam", &"fence_on":
				var s: Dictionary = _strike(strikes, int(e["n"]))
				if s.is_empty() or not is_equal_approx(float(e["at"]), float(s["at"])):
					mismatched += 1
	check(mismatched == 0, "every blast, slam and fence is its strike's (%d strikes) %s" % [strikes.size(), tag])
	check(int(r["skipped"]) == 0, "no strike was left out for want of a fair moment %s" % tag)
	# Sizes.
	var by_attack: Dictionary = {}
	for s: Dictionary in strikes:
		var key: int = int(s["attack"])
		if not by_attack.has(key):
			by_attack[key] = []
		(by_attack[key] as Array).append(s)
	var sizes_seen: Dictionary = {}
	var size_ok: bool = true
	for key: int in by_attack:
		var list: Array = by_attack[key]
		var first: Dictionary = list[0]
		var kind: int = int(first["kind"])
		var size: int = int(first["size"])
		sizes_seen["%d_%d" % [kind, size]] = true
		if list.size() != TheHouseAttacks.strikes_in(kind, size):
			size_ok = false
		for s: Dictionary in list:
			var n: int = (s["lanes"] as Array).size()
			var want: int = 0
			match kind:
				TheHouseAttacks.Kind.CHERRY:
					want = mini(TheHouseTuning.per_lanes(t.cherry_lanes, lanes) + (1 if size >= 2 and lanes >= 5 else 0), lanes - 1)
				TheHouseAttacks.Kind.BAR:
					want = mini(TheHouseTuning.per_lanes(t.bar_lanes, lanes) + (1 if size >= 2 and lanes >= 5 else 0), lanes - 1)
				TheHouseAttacks.Kind.LIGHTNING:
					want = lanes if size >= 3 else (lanes - 1 if size == 2 else TheHouseTuning.per_lanes(t.fence_lanes, lanes))
			if n != want:
				size_ok = false
		if kind == TheHouseAttacks.Kind.LIGHTNING and size >= 3:
			if list.size() != 2 or list[0]["variant"] != "full" or list[1]["variant"] != "gapped":
				size_ok = false
	check(sizes_seen.size() == 9, "every attack came at every size (%d of 9) %s" % [sizes_seen.size(), tag])
	check(size_ok, "two and three of a kind are bigger: more strikes, wider ones; three lightnings a full fence then a gapped one %s" % tag)
	# Each strike's own warning sound, and the reels' dings.
	var sounds: Array = r["sounds"]
	check(sounds.count(&"house_cherry") >= 6 and sounds.count(&"house_bar") >= 6 and sounds.count(&"house_lightning") >= 5
		and sounds.count(&"house_ding") >= 21 and sounds.count(&"house_lever") >= 7,
		"each strike sounds its warning, each reel its ding, each spin its lever %s" % tag)
	check(int((r["reactions"] as Dictionary).get(&"startled", 0)) >= 6, "the citizens duck at each big attack %s" % tag)
	# Pooled: every pool is drawn on more often than it has things in it (strikes reuse them).
	var pools: Dictionary = r["pools"]
	var reused: bool = true
	for key: String in ["bombs", "fires", "blast_boxes", "blocks", "spools"]:
		var made: int = int(pools[key][0])
		var taken: int = int(pools[key][1])
		if made <= 0 or made >= taken:
			reused = false
	check(reused, "its bombs, blasts, blocks and spools are pooled, reused from strike to strike %s: %s" % [tag, pools])


## The strike numbered `n` among those recorded.
func _strike(strikes: Array, n: int) -> Dictionary:
	for s: Dictionary in strikes:
		if int(s["n"]) == n:
			return s
	return {}


## The fight time at the attacks' clock time `clock` (both run on the pattern's physics steps: their
## difference is the strike's reveal offset).
func _fight_time_at(events: Array, s: Dictionary, clock: float) -> float:
	for e: Dictionary in events:
		if e["event"] == &"strike" and int(e["n"]) == int(s["n"]):
			return float(e["t"]) + (clock - float(s["reveal"]))
	return -1.0


# --- The 3-lane mix ------------------------------------------------------------------------------

## GDD §10's cherry bombs and gold blocks together at 3 lanes (the narrowest street): there is always a way.
func _test_three_lane_mix() -> void:
	for speed: float in SPEEDS:
		var tag: String = "(3 lanes, %.1f m/s)" % speed
		var r: Dictionary = await _play(_attacks_only("cherry,bar,bar|bar,cherry,cherry|cherry,bar,cherry|bar,bar,cherry"), 3, speed, 4)
		check(r["alive"] and int(r["stuck"]) == 0 and (r["problems"] as Array).is_empty(),
			"cherry bombs and gold blocks together leave a way through %s" % tag)
		# The way, checked on the strikes as they came: from where the runner was as each showed, through every
		# strike still ahead then, a route exists.
		var strikes: Array = r["strikes"]
		var t := def.tuning as TheHouseTuning
		var mt: MovementTuning = tuning.duplicate() as MovementTuning
		mt.run_speed = speed
		var route: TheHouseRoute = TheHouseRoute.for_run(3, speed, mt, t)
		var mixed: int = 0
		for i: int in strikes.size():
			var s: Dictionary = strikes[i]
			var obstacles: Array = []
			var kinds: Dictionary = {}
			for o: Dictionary in strikes:
				if float(o["reveal"]) <= float(s["reveal"]) + 0.001 and float(o["at"]) + 3.0 >= float(s["d0"]):
					kinds[int(o["kind"])] = true
					for lane: int in o["lanes"]:
						var depth: float = t.blast_depth * 0.5 if int(o["kind"]) == TheHouseAttacks.Kind.CHERRY else 0.0
						var to: float = float(o["at"]) + (t.block_depth if int(o["kind"]) == TheHouseAttacks.Kind.BAR else depth)
						obstacles.append(TheHouseRoute.obstacle(lane, float(o["at"]) - depth, to))
			if kinds.size() >= 2:
				mixed += 1
			var ok: bool = false
			for lane: int in 3:
				var found: Dictionary = route.find(lane, float(s["d0"]), float(s["d0"]) + speed * REACTION, float(s["at"]) + 20.0, obstacles)
				ok = ok or found["ok"]
			check(ok, "a way through the bombs and blocks ahead as strike %d showed %s" % [int(s["n"]), tag])
		check(mixed >= 3, "bombs and blocks were on the track together (%d times) %s" % [mixed, tag])


# --- The phases' own lists -----------------------------------------------------------------------

## The three phases' spin lists (no buttons), over a few seeds, at every lane count and speed: the runner
## gets through them all.
func _test_lists() -> void:
	var t := def.tuning as TheHouseTuning
	var deaths: Array[String] = []
	var stuck: int = 0
	var skipped: int = 0
	var runs: int = 0
	for phase: int in 3:
		var spins: PackedStringArray = PackedStringArray()
		for spin: PackedStringArray in t.spins_for(phase):
			spins.append(",".join(spin))
		var list: String = "|".join(spins)
		for lanes: int in LANES:
			for speed: float in SPEEDS:
				var seed_value: int = 1301 + 97 * phase + lanes
				var r: Dictionary = await _play(_attacks_only(list, seed_value), lanes, speed, spins.size(), false)
				runs += 1
				stuck += int(r["stuck"])
				skipped += int(r["skipped"])
				if not r["alive"]:
					deaths.append("phase %d's list, %d lanes, %.1f m/s" % [phase + 1, lanes, speed])
	check(deaths.is_empty() and stuck == 0, "every phase's spins at every lane count and speed: the runner always finds a way (%d runs)%s" % [
		runs, "" if deaths.is_empty() else ": died in " + ", ".join(deaths)])
	check(skipped == 0, "the denser and wider phase patterns retain every attack (%d runs)" % runs)
