extends TestSuite
## The enemy director's turn-taking (GDD §9, "Big attacks take turns", GameRules.big_attacks_take_turns)
## on real physics: with scripted test enemies (tests/helpers/turn_dummy.gd), big attacks of different
## types never overlap, an attack waits before its warning and never after it, shots hold their
## attack's turn until they've passed the player, the enemy that has waited longest goes next (so none
## is starved by others that keep asking), GDD §9.7's exclusive rule holds either way, and with the
## switch off different types don't coordinate (as before the rule). Then over simulated runs of
## campaign levels (tools/measure/attack_watch.gd, as tools/measure/big_attacks.gd measures the whole
## campaign): no overlap between the real enemies' big attacks with the switch on, the old overlaps
## with it off, and every type still attacks.

const DUMMY: String = "res://tests/helpers/turn_dummy.gd"
const AttackWatch = preload("res://tools/measure/attack_watch.gd")

var sim: RunSim


func run() -> void:
	sim = RunSim.new(tree, tuning)
	_test_switch()
	await _test_takes_turns()
	await _test_switch_off()
	await _test_same_type()
	await _test_waits_before_warning()
	await _test_shots_hold_the_turn()
	await _test_longest_wait_first()
	await _test_no_starvation()
	await _test_keeps_place_through_a_gap()
	await _test_keeps_place_through_its_turn()
	await _test_place_lapses()
	await _test_exclusive()
	await _test_attack_on_carries_on()
	await _test_many()
	await _test_campaign()


# --- Helpers ------------------------------------------------------------------------------------

## A bare world with the switch set as asked (on a copy of the rules, so other worlds keep theirs).
func _world(turns: bool) -> RunWorld:
	var w: RunWorld = sim.build_world(RunSim.layout(3, 3000.0))
	w.rules = w.rules.duplicate() as GameRules
	w.rules.big_attacks_take_turns = turns
	return w


func _dummy(w: RunWorld, type: String, params: Dictionary) -> Enemy:
	return w.director.spawn({"type": type, "script": DUMMY, "at": 0.0, "lane": 0, "side": 0, "seed": 1,
		"params": params}) as Enemy


func _run(w: RunWorld, seconds: float) -> void:
	if not w.player.running:
		await tree.physics_frame
		w.player.running = true
	for i: int in int(seconds * Engine.physics_ticks_per_second):
		await tree.physics_frame


## The overlaps between the attacks of two dummies: [[a_start, b_start], ...] for each pair of
## attacks (warning to end) that were on at the same time.
static func _overlaps(a: Enemy, b: Enemy) -> Array:
	var out: Array = []
	for sa: Array in a.call(&"spans"):
		for sb: Array in b.call(&"spans"):
			if maxf(sa[0], sb[0]) < minf(sa[1], sb[1]) - 0.0001:
				out.append([sa[0], sb[0]])
	return out


static func _time_of(d: Enemy, event: String, nth: int = 0) -> float:
	var n: int = 0
	for h: Array in d.get(&"history"):
		if h[0] == event:
			if n == nth:
				return float(h[1])
			n += 1
	return -1.0


# --- The switch ---------------------------------------------------------------------------------

## GDD §9 (may be reverted after playtesting): one switch in the game rules, on by default, shown in
## the F6 panel (a bool exported on GameRules).
func _test_switch() -> void:
	var rules := load("res://data/tuning/game_rules.tres") as GameRules
	check(rules.big_attacks_take_turns and GameRules.new().big_attacks_take_turns,
		"big attacks take turns by default (data/tuning/game_rules.tres)")
	var shown: bool = false
	for prop: Dictionary in rules.get_property_list():
		if prop["name"] == "big_attacks_take_turns":
			shown = prop["type"] == TYPE_BOOL and (int(prop["usage"]) & PROPERTY_USAGE_EDITOR) != 0 \
				and (int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0
	check(shown, "the switch is an exported bool, so the F6 panel shows it")


# --- Turns --------------------------------------------------------------------------------------

## Two types ready at the same moment, again and again: their attacks never overlap, and both keep
## attacking, each right after the other.
func _test_takes_turns() -> void:
	var w: RunWorld = _world(true)
	var a := _dummy(w, "alpha", {"first": 0.5, "interval": 0.3, "warning": 0.6, "attack": 0.6})
	var b := _dummy(w, "beta", {"first": 0.5, "interval": 0.3, "warning": 0.6, "attack": 0.6})
	await _run(w, 8.0)
	check(_overlaps(a, b).is_empty(), "two types' big attacks never overlap (%s)" % [_overlaps(a, b)])
	var na: int = int(a.call(&"count", "start"))
	var nb: int = int(b.call(&"count", "start"))
	check(na >= 3 and nb >= 3 and absi(na - nb) <= 1, "both keep attacking, in turn (%d and %d attacks)" % [na, nb])
	var end_a: float = _time_of(a, "end")
	var start_b: float = _time_of(b, "start")
	check(start_b >= end_a - 0.0001 and start_b <= end_a + 2.5 / Engine.physics_ticks_per_second,
		"the second goes as soon as the first is over (%.3f s after it)" % (start_b - end_a))
	check(_time_of(b, "held") >= 0.0 and _time_of(b, "held") < start_b, "it waited for its turn first")
	await sim.free_world(w)


## With the switch off, different types don't coordinate: the same two attack at once, as before the
## rule (GDD §9: the owner may revert it after playtesting).
func _test_switch_off() -> void:
	var w: RunWorld = _world(false)
	var a := _dummy(w, "alpha", {"first": 0.5, "interval": 0.3, "warning": 0.6, "attack": 0.6})
	var b := _dummy(w, "beta", {"first": 0.5, "interval": 0.3, "warning": 0.6, "attack": 0.6})
	await _run(w, 4.0)
	check(not _overlaps(a, b).is_empty() and absf(_time_of(a, "start") - _time_of(b, "start")) < 0.001,
		"switched off, both attack at once (%s)" % [_overlaps(a, b)])
	check(int(a.call(&"count", "held")) == 0 and int(b.call(&"count", "held")) == 0, "and nobody waits")
	check(not w.director.is_waiting(a) and not w.director.is_waiting(b) and w.director.turn_wait(b) == 0.0,
		"the director keeps no turns")
	await sim.free_world(w)


## Enemies of one type space their own attacks (one drone barrage at a time, one Octodog or truck at a
## time): the turn-taking between types leaves them alone.
func _test_same_type() -> void:
	var w: RunWorld = _world(true)
	var a := _dummy(w, "alpha", {"first": 0.5, "interval": 0.3, "warning": 0.6, "attack": 0.6})
	var b := _dummy(w, "alpha", {"first": 0.5, "interval": 0.3, "warning": 0.6, "attack": 0.6})
	await _run(w, 3.0)
	check(not _overlaps(a, b).is_empty() and int(b.call(&"count", "held")) == 0,
		"two of the same type aren't held by each other")
	await sim.free_world(w)


## An attack waits before its warning, never after it: one that is on runs its course (warning and
## attack, whoever becomes ready meanwhile), and the one that became ready during it starts its
## warning only once it's over.
func _test_waits_before_warning() -> void:
	var w: RunWorld = _world(true)
	var a := _dummy(w, "alpha", {"first": 0.2, "interval": 10.0, "warning": 1.0, "attack": 2.0})
	var b := _dummy(w, "beta", {"first": 0.8, "interval": 10.0, "warning": 0.5, "attack": 0.5})
	await _run(w, 5.0)
	var spans_a: Array = a.call(&"spans")
	check(spans_a.size() == 1 and absf(float(spans_a[0][1]) - float(spans_a[0][0]) - 3.0) < 0.05,
		"a started attack always finishes: its warning and its attack in full (%s)" % [spans_a])
	var ready_b: float = _time_of(b, "ready")
	var start_b: float = _time_of(b, "start")
	check(_time_of(b, "held") == ready_b and start_b >= float(spans_a[0][1]) - 0.0001,
		"one ready during it waits, and only starts its warning after it (ready %.2f, start %.2f, end %.2f)"
		% [ready_b, start_b, spans_a[0][1]])
	var waited: Array[float] = b.get(&"waits")
	check(waited.size() == 1 and absf(waited[0] - (start_b - ready_b)) < 0.001 and waited[0] > 2.0,
		"it waited %.2f s for its turn" % (waited[0] if not waited.is_empty() else -1.0))
	await sim.free_world(w)


## Shots hold their attack's turn until they've passed the player (EnemyDirector.note_attack_shot,
## SHOT_PASS_MARGIN behind them), watched where they really are: the next type's warning starts only
## then.
func _test_shots_hold_the_turn() -> void:
	var w: RunWorld = _world(true)
	var a := _dummy(w, "alpha", {"first": 0.2, "interval": 10.0, "warning": 0.4, "attack": 0.2, "shot": 0.8})
	var b := _dummy(w, "beta", {"first": 0.3, "interval": 10.0, "warning": 0.4, "attack": 0.4})
	var in_flight: Array = [false]
	if not w.player.running:
		await tree.physics_frame
		w.player.running = true
	for i: int in 4 * Engine.physics_ticks_per_second:
		await tree.physics_frame
		if _time_of(a, "end") >= 0.0 and _time_of(b, "start") < 0.0:
			in_flight[0] = in_flight[0] or w.director.shots_on_their_way(&"alpha")
	var hit: float = _time_of(a, "hit")
	var start_b: float = _time_of(b, "start")
	check(in_flight[0], "after its attack, its shot is still on its way")
	# It comes level with the player 0.8 s after it's fired, and is past them a few frames later.
	check(start_b >= hit + 0.8 and start_b <= hit + 0.8 + 0.2,
		"another type starts once the shot has passed the player (%.2f s after it was fired)" % (start_b - hit))
	check(not w.director.shots_on_their_way(&"alpha"), "and then it's gone")
	await sim.free_world(w)

	# Fired while the player dashes, the shot comes much later once the dash ends (they slow down):
	# its turn lasts until it has really passed them, not until it would have at the dash's speed.
	w = _world(true)
	a = _dummy(w, "alpha", {"first": 0.2, "interval": 10.0, "warning": 0.4, "attack": 0.2, "shot": 0.8})
	b = _dummy(w, "beta", {"first": 0.3, "interval": 10.0, "warning": 0.4, "attack": 0.4})
	await tree.physics_frame
	w.player.running = true
	w.player.start_dash(0.75, 8.0)
	var passed: float = -1.0
	var reach: float = w.tuning.hurtbox_size.z * 0.5
	for i: int in 5 * Engine.physics_ticks_per_second:
		await tree.physics_frame
		if passed < 0.0 and _time_of(a, "hit") >= 0.0:
			var ahead: bool = false
			for s: Projectile in w.projectiles.live_shots():
				ahead = ahead or (not s.friendly and s.position.z <= w.player.position.z + reach)
			if not ahead:
				passed = w.level_time()
	hit = _time_of(a, "hit")
	start_b = _time_of(b, "start")
	check(passed > hit + 1.5, "the dash's end slows the shot's arrival (it passed the player %.2f s after it was fired)" % (passed - hit))
	check(start_b >= passed - 0.001 and start_b <= passed + 0.25,
		"another type starts once it has really passed them (%.2f s after it was fired, %.2f s after it passed)"
		% [start_b - hit, start_b - passed])
	await sim.free_world(w)


## Of those waiting, the one that has waited longest goes first, whatever order they came into play.
func _test_longest_wait_first() -> void:
	var w: RunWorld = _world(true)
	var a := _dummy(w, "alpha", {"first": 0.1, "interval": 10.0, "warning": 0.5, "attack": 2.0})
	var late := _dummy(w, "beta", {"first": 1.3, "interval": 10.0, "warning": 0.3, "attack": 0.3})
	var early := _dummy(w, "gamma", {"first": 0.6, "interval": 10.0, "warning": 0.3, "attack": 0.3})
	await _run(w, 2.0)
	check(w.director.is_waiting(late) and w.director.is_waiting(early) and w.director.held_for_turn(early),
		"both are waiting for their turn")
	check(w.director.turn_wait(early) > w.director.turn_wait(late) + 0.5,
		"the director knows how long each has waited (%.2f s and %.2f s)" % [w.director.turn_wait(early), w.director.turn_wait(late)])
	await _run(w, 3.0)
	var end_a: float = _time_of(a, "end")
	var start_early: float = _time_of(early, "start")
	var start_late: float = _time_of(late, "start")
	check(start_early >= end_a - 0.0001 and start_early < start_late,
		"the one that waited longest goes first (%.2f, then %.2f), though it came into play later" % [start_early, start_late])
	check(start_late >= _time_of(early, "end") - 0.0001, "then the other")
	await sim.free_world(w)


## Three types that are ready again as soon as they're done go round in turns: none waits longer than
## one attack of each other type, and none is kept from its turns.
func _test_no_starvation() -> void:
	var w: RunWorld = _world(true)
	var a := _dummy(w, "alpha", {"first": 0.0, "interval": 0.02, "warning": 0.3, "attack": 0.3})
	var b := _dummy(w, "beta", {"first": 0.0, "interval": 0.02, "warning": 0.3, "attack": 0.3})
	var c := _dummy(w, "gamma", {"first": 0.2, "interval": 0.02, "warning": 0.3, "attack": 0.3})
	await _run(w, 10.0)
	var worst: float = 0.0
	for d: Enemy in [a, b, c]:
		for wait: float in d.get(&"waits"):
			worst = maxf(worst, wait)
	var counts: Array = [a.call(&"count", "start"), b.call(&"count", "start"), c.call(&"count", "start")]
	check(int(counts[2]) >= 4 and absi(int(counts[0]) - int(counts[2])) <= 1 and absi(int(counts[1]) - int(counts[2])) <= 1,
		"a third type gets its turns too (%s attacks)" % [counts])
	check(worst <= 2 * 0.6 + 0.1, "nobody waits longer than one attack of each other type (%.2f s at most)" % worst)
	check(_overlaps(a, b).is_empty() and _overlaps(a, c).is_empty() and _overlaps(b, c).is_empty(), "and none overlap")
	await sim.free_world(w)


## A waiting enemy keeps its place in the queue through a short gap in its asks (its stretch not clear
## for a moment): when the attack that was on is over, a type that began waiting later doesn't go
## first, even though the gap spans that moment. With no grace (GameRules.turn_place_grace 0) the gap
## sends it to the back of the queue, as before.
func _test_keeps_place_through_a_gap() -> void:
	for grace: float in [2.0, 0.0]:
		var tag: String = "grace %.1f s" % grace
		var w: RunWorld = _world(true)
		w.rules.turn_place_grace = grace
		var a := _dummy(w, "alpha", {"first": 0.1, "interval": 10.0, "warning": 0.5, "attack": 1.4})
		var gap := _dummy(w, "beta", {"first": 0.5, "interval": 10.0, "warning": 0.3, "attack": 0.3,
			"pauses": [[1.5, 2.4]]})
		var late := _dummy(w, "gamma", {"first": 1.0, "interval": 10.0, "warning": 0.3, "attack": 0.3})
		await _run(w, 1.8)
		if grace > 0.0:
			check(w.director.is_waiting(gap) and not w.director.held_for_turn(gap) and w.director.turn_wait(gap) > 1.2,
				"%s: it isn't asking, but it's still waiting, since it first asked (%.2f s)" % [tag, w.director.turn_wait(gap)])
		await _run(w, 2.2)
		var end_a: float = _time_of(a, "end")
		var start_gap: float = _time_of(gap, "start")
		var start_late: float = _time_of(late, "start")
		check(_overlaps(gap, late).is_empty() and _overlaps(a, gap).is_empty() and _overlaps(a, late).is_empty(),
			"%s: no two overlap" % tag)
		if grace > 0.0:
			check(start_gap >= 2.4 - 0.001 and start_gap <= 2.4 + 0.05 and start_late >= _time_of(gap, "end") - 0.0001,
				"%s: it goes as soon as it asks again (%.2f s), before the one that began waiting later (%.2f s); the attack on was over at %.2f s"
				% [tag, start_gap, start_late, end_a])
		else:
			check(start_late >= end_a - 0.0001 and start_late < end_a + 0.05 and start_gap > start_late,
				"%s: the gap cost it its place: the other went first (%.2f s, then %.2f s)" % [tag, start_late, start_gap])
		await sim.free_world(w)


## Told it may go, an enemy that isn't quite ready yet (an Octodog whose moved-on stretch isn't clear)
## keeps asking and keeps its place: another type that is ready again waits for it rather than go
## first again.
func _test_keeps_place_through_its_turn() -> void:
	var w: RunWorld = _world(true)
	var a := _dummy(w, "alpha", {"first": 0.1, "interval": 0.3, "warning": 0.5, "attack": 1.4})
	var slow := _dummy(w, "beta", {"first": 0.5, "interval": 10.0, "warning": 0.3, "attack": 0.3,
		"stalls": [[1.9, 3.2]]})
	await _run(w, 5.0)
	var end_a: float = _time_of(a, "end")
	var stalled: float = _time_of(slow, "stalled")
	var start_slow: float = _time_of(slow, "start")
	var again_a: float = _time_of(a, "start", 1)
	check(stalled >= end_a - 0.0001 and stalled < end_a + 0.05 and start_slow >= 3.2 - 0.001 and start_slow <= 3.2 + 0.05,
		"its turn came at %.2f s and it was ready at %.2f s" % [stalled, start_slow])
	check(_time_of(a, "ready", 1) < start_slow and again_a >= _time_of(slow, "end") - 0.0001,
		"the other, ready again at %.2f s, went after it (%.2f s)" % [_time_of(a, "ready", 1), again_a])
	check(_overlaps(a, slow).is_empty(), "and they never overlap")
	await sim.free_world(w)


## Nothing waits for ever: an enemy that gives its attack up (EnemyDirector.give_up_turn) leaves the
## queue at once, and one that stops asking without saying so loses its place
## GameRules.turn_place_grace after its last ask; the next in the queue goes then.
func _test_place_lapses() -> void:
	for quiet: bool in [false, true]:
		var tag: String = "stops asking" if quiet else "gives up"
		var w: RunWorld = _world(true)
		var grace: float = w.rules.turn_place_grace
		var a := _dummy(w, "alpha", {"first": 0.1, "interval": 10.0, "warning": 0.5, "attack": 0.5})
		var p := {"first": 0.3, "interval": 10.0, "warning": 0.3, "attack": 0.3}
		if quiet:
			p["pauses"] = [[0.6, 100.0]]
		else:
			p["give_up"] = 0.3
		var quits := _dummy(w, "beta", p)
		var next := _dummy(w, "gamma", {"first": 0.5, "interval": 10.0, "warning": 0.3, "attack": 0.3})
		await _run(w, 0.6 + grace + 1.0)
		var end_a: float = _time_of(a, "end")
		var start_next: float = _time_of(next, "start")
		check(_time_of(quits, "start") < 0.0 and not w.director.is_waiting(quits), "%s: it never went" % tag)
		if quiet:
			check(start_next >= end_a + 0.5 and absf(start_next - (0.6 + grace)) < 0.05,
				"%s: the next went once its place was gone, %.1f s after its last ask (%.2f s)" % [tag, grace, start_next])
		else:
			check(_time_of(quits, "gave_up") < end_a and start_next >= end_a - 0.0001 and start_next < end_a + 0.05,
				"%s: the next went as soon as the attack on was over (%.2f s, over at %.2f s)" % [tag, start_next, end_a])
		await sim.free_world(w)


## GDD §9.7 holds whether or not big attacks take turns: an exclusive attack and those of the types it
## names never overlap. Switched off, other types still don't coordinate with it; switched on, they
## take turns with it like everyone.
func _test_exclusive() -> void:
	for turns: bool in [false, true]:
		var tag: String = "turns %s" % ("on" if turns else "off")
		var w: RunWorld = _world(turns)
		var x := _dummy(w, "dream", {"first": 0.2, "interval": 10.0, "warning": 0.5, "attack": 2.0,
			"exclusive": true, "exclusive_of": ["alpha"]})
		var named := _dummy(w, "alpha", {"first": 0.6, "interval": 10.0, "warning": 0.3, "attack": 0.3})
		var other := _dummy(w, "beta", {"first": 0.6, "interval": 10.0, "warning": 0.3, "attack": 0.3})
		await _run(w, 1.0)
		if turns:
			check(w.director.is_waiting(named) and not w.director.held_for_turn(named)
				and w.director.held_for_turn(other), "%s: the named type is held by the exclusive rule, the other by turns" % tag)
		await _run(w, 3.0)
		check(_overlaps(x, named).is_empty() and _time_of(named, "held") >= 0.0,
			"%s: a type it names waits for the exclusive attack" % tag)
		if turns:
			check(_overlaps(x, other).is_empty() and _time_of(other, "held") >= 0.0, "%s: so does any other type" % tag)
		else:
			check(not _overlaps(x, other).is_empty() and _time_of(other, "held") < 0.0,
				"%s: another type doesn't, as before the rule" % tag)
		await sim.free_world(w)
	# The other way round: the exclusive one waits for a named type's attack that is on (the Bad Dream
	# holds its slash during a drone barrage).
	var w2: RunWorld = _world(false)
	var named2 := _dummy(w2, "alpha", {"first": 0.1, "interval": 10.0, "warning": 0.5, "attack": 1.0})
	var x2 := _dummy(w2, "dream", {"first": 0.3, "interval": 10.0, "warning": 0.3, "attack": 0.3,
		"exclusive": true, "exclusive_of": ["alpha"]})
	await _run(w2, 3.0)
	check(_overlaps(x2, named2).is_empty() and _time_of(x2, "start") >= _time_of(named2, "end") - 0.0001,
		"turns off: the exclusive one waits for a named type's attack")
	await sim.free_world(w2)


## An enemy whose big attack is already on carries on through it (the Bad Dream's next slash in its
## chase): enemies waiting for their turn don't hold it.
func _test_attack_on_carries_on() -> void:
	var w: RunWorld = _world(true)
	var x := _dummy(w, "dream", {"first": 0.1, "interval": 10.0, "warning": 2.0, "attack": 0.3, "chain": true})
	var y := _dummy(w, "beta", {"first": 0.3, "interval": 10.0, "warning": 0.3, "attack": 0.3})
	await _run(w, 3.0)
	check(int(x.call(&"count", "again")) > 60 and int(x.call(&"count", "again_held")) == 0,
		"its asks while its attack is on are never held by a waiting enemy (%d)" % int(x.call(&"count", "again_held")))
	check(_overlaps(x, y).is_empty() and _time_of(y, "held") >= 0.0, "which waits for it to be over")
	await sim.free_world(w)


## Five types on random schedules for a minute of play, some firing shots: no two types' big attacks
## ever overlap (shots included), nothing deadlocks, and every one gets its turns, never waiting
## longer than one attack of each other type. (Without the order of waiting, first come first served,
## one of these five never gets a turn.)
func _test_many() -> void:
	var w: RunWorld = _world(true)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var dummies: Array[Enemy] = []
	var longest: float = 0.0
	for i: int in 5:
		var p := {"first": rng.randf_range(0.0, 1.0), "interval": rng.randf_range(0.1, 2.0),
			"warning": rng.randf_range(0.3, 1.0), "attack": rng.randf_range(0.1, 0.8),
			"shot": rng.randf_range(0.3, 0.9) if i % 2 == 0 else 0.0}
		longest = maxf(longest, float(p["warning"]) + float(p["attack"])
			+ (float(p["shot"]) + 0.2 if float(p["shot"]) > 0.0 else 0.0))
		dummies.append(_dummy(w, "type%d" % i, p))
	await _run(w, 60.0)
	var overlaps: int = 0
	var shot_overlaps: int = 0
	for i: int in dummies.size():
		for j: int in range(i + 1, dummies.size()):
			overlaps += _overlaps(dummies[i], dummies[j]).size()
		# A shot's flight belongs to its attack: nobody else's warning starts before it has passed.
		var shot: float = float(dummies[i].get(&"shot"))
		if shot <= 0.0:
			continue
		for h: Array in dummies[i].get(&"history"):
			if h[0] != "hit":
				continue
			for j: int in dummies.size():
				if j == i:
					continue
				for g: Array in dummies[j].get(&"history"):
					if g[0] == "start" and float(g[1]) > float(h[1]) + 0.0001 \
							and float(g[1]) < float(h[1]) + shot - 0.02:
						shot_overlaps += 1
	check(overlaps == 0 and shot_overlaps == 0, "no two types' big attacks overlap (%d, %d during shots)" % [overlaps, shot_overlaps])
	var worst: float = 0.0
	var fewest: int = 1000
	for d: Enemy in dummies:
		fewest = mini(fewest, int(d.call(&"count", "start")))
		for wait: float in d.get(&"waits"):
			worst = maxf(worst, wait)
	check(fewest >= 5, "every type keeps getting turns (the fewest attacked %d times)" % fewest)
	check(worst <= 4.0 * longest + 0.1, "no wait is longer than one attack of each other type (%.2f s, bound %.2f s)"
		% [worst, 4.0 * longest + 0.1])
	await sim.free_world(w)


# --- The campaign -------------------------------------------------------------------------------

## Simulated runs of campaign levels, measured as tools/measure/big_attacks.gd does (a god-mode runner
## in the middle lane stomping every host it passes, the real enemies): with the switch on the big
## attacks of different types never overlap, every type still attacks and every Octodog charges;
## with it off the old overlaps are back. Gangland 3 is item 27's level (drones, Octodogs, hover
## trucks), at 3 lanes and at 6, whose layout has the overlaps; Dead Zone 1 adds hosts and the Bad
## Dream.
func _test_campaign() -> void:
	var campaign := load("res://data/campaign/campaign.tres") as Campaign
	var cases: Array = [["gangland/3", 3, true], ["gangland/3", 6, true], ["gangland/3", 6, false], ["dead_zone/1", 5, true]]
	for case: Array in cases:
		var tag: String = "%s lanes=%d turns %s" % [case[0], case[1], "on" if case[2] else "off"]
		var config: LevelConfig = campaign.configure(campaign.step(case[0]), case[1])
		config.skin = null  # the grey box: skins never change gameplay
		var layout: LevelLayout = LevelGenerator.new().generate(config, tuning, LevelGenerator.load_for(config))
		var w: RunWorld = sim.build_world(layout, null, null, config)
		w.rules = w.rules.duplicate() as GameRules
		w.rules.big_attacks_take_turns = case[2]
		w.player.god_mode = true
		w.player.grapples = 1_000_000
		var watch: AttackWatch = AttackWatch.new(w, true)
		await tree.physics_frame
		w.player.running = true
		while w.player.distance < layout.length:
			await tree.physics_frame
			watch.observe()
		var a: Dictionary = watch.attacks
		if case[2]:
			check(is_zero_approx(watch.overlap), "%s: no two types' big attacks overlap (%.2f s: %s)" % [tag, watch.overlap, watch.overlap_pairs])
			var kinds: Array = ["drone", "truck_lurch", "truck_cannon", "dog_charge"]
			if case[0] == "dead_zone/1":
				kinds.append("dream_slash")
			for kind: String in kinds:
				check(int(a.get(kind, 0)) > 0, "%s: %s attacks still come (%s)" % [tag, kind, a])
			check(watch.dogs_without_a_charge() == 0, "%s: every Octodog charges" % tag)
		else:
			check(watch.overlap > 0.5, "%s: the old overlaps are back (%.2f s: %s)" % [tag, watch.overlap, watch.overlap_pairs])
		await sim.free_world(w)
