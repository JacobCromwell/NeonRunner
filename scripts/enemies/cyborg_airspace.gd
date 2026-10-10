class_name CyborgAirspace
extends RefCounted
## The cyborgs' airspace (GDD §9.2): the bursts of the cyborg-type guns (CyborgGun: cyborgs, window
## cyborgs, Barnacle Turrets) that are in the air. One per RunWorld, in its metadata (of()), so every
## attempt's new world starts with it empty.
## - Up to two bursts at once (owner, October 8, 2026; the build had allowed one, which looked
##   unnatural): a burst claims its place from the start of its charge-up until
##   CyborgGunTuning.burst_gap after its last bolt, and one only starts while fewer than
##   GameRules.max_bursts_in_air claims are on (may_start).
## - Each claim is its shooter's own: a release (a cancelled charge-up, a shooter that stops) ends that
##   shooter's claim and no other, and a claim whose shooter has left play (defeated, retired or freed)
##   no longer counts, so a shooter that's gone never holds the air for the others.
## - A boss may claim the whole airspace (the Floating Head's eye lasers, FloatingHeadFaceOff; big
##   attacks take turns, GDD §9): no burst starts while that claim is on, and the boss only claims it
##   once no burst is on (claimed_until).
## - It also keeps, for each burst, when its charge-up began, when its bolts arrive and, once its aim
##   locks, the line they fly along and the surface it was aimed at, until they have all arrived: the
##   guns' crossfire rule reads them (near(), CyborgGun._crossfire_fair).
## Everything runs in the physics step, in the order the guns ask, so every attempt at a seed plays
## out the same way.

## RunWorld metadata: the world's airspace.
const META: StringName = &"cyborg_airspace"
## The bursts at once when the world has no GameRules (GameRules.max_bursts_in_air's default).
const DEFAULT_MOST: int = 2
## A burst whose bolts are on their way is kept this long after its last one arrives (longer than any
## CyborgGunTuning.crossfire_gap), so a burst arriving near it still sees it.
const KEEP_AFTER: float = 2.0

## The claims, oldest first: {"owner" (instance id of the shooter or the boss), "whole" (the whole
## airspace, a boss's), "t0" (level time the claim began: a burst's charge-up), "until" (level time the
## claim ends), "aimed" (its aim is locked and its bolts are on their way), "line" (once aimed: the
## world x its bolts fly along, the runner's at the lock), "surface" and "side" (once aimed: the
## Player.Surface the runner was on at the lock, and the wall's side for a wall runner), "wild" (wild
## fire, landing anywhere around the runner: the panic variant's), "first" and "last" (level times its
## first and last bolts arrive: predicted until each bolt flies)}.
var _claims: Array[Dictionary] = []


## The airspace of `world` (made on first use).
static func of(world: Node) -> CyborgAirspace:
	if world.has_meta(META):
		return world.get_meta(META) as CyborgAirspace
	var airspace := CyborgAirspace.new()
	world.set_meta(META, airspace)
	return airspace


## A burst's place in the air for `owner` (its shooter) until `until` (level time). `first` and `last`:
## when its bolts would arrive (level times), `wild`: wild fire. Returns the claim, which the gun hands
## back to aim(), arrives() and near().
func claim(owner: Object, until: float, first: float, last: float, wild: bool, now: float) -> Dictionary:
	_prune(now)
	var c := {"owner": owner.get_instance_id(), "whole": false, "t0": now, "until": until, "aimed": false,
		"line": 0.0, "surface": 0, "side": 0, "wild": wild, "first": first, "last": last}
	_claims.append(c)
	return c


## Claims the whole airspace for `owner` (a boss) until `until` (level time), or longer if its claim
## already runs longer: no burst starts until then.
func claim_whole(owner: Object, until: float, now: float) -> void:
	_prune(now)
	var id: int = owner.get_instance_id()
	for c: Dictionary in _claims:
		if bool(c["whole"]) and int(c["owner"]) == id:
			c["until"] = maxf(float(c["until"]), until)
			return
	_claims.append({"owner": id, "whole": true, "t0": now, "until": until, "aimed": false, "line": 0.0,
		"surface": 0, "side": 0, "wild": false, "first": INF, "last": -INF})


## Ends `owner`'s claims that are still on, and only those. A burst whose bolts are on their way is still
## kept for the crossfire rule until they've arrived; one that never fired is dropped.
func release(owner: Object, now: float) -> void:
	var id: int = owner.get_instance_id()
	for i: int in range(_claims.size() - 1, -1, -1):
		var c: Dictionary = _claims[i]
		if int(c["owner"]) != id or float(c["until"]) <= now:
			continue
		if bool(c["aimed"]):
			c["until"] = now
		else:
			_claims.remove_at(i)


## A burst's aim locks: its bolts fly along world x `line` at a runner on `surface` (Player.Surface; a wall
## runner's wall on `side`) and arrive between `first` and `last` (level times).
func aim(c: Dictionary, line: float, surface: int, side: int, first: float, last: float) -> void:
	c["aimed"] = true
	c["line"] = line
	c["surface"] = surface
	c["side"] = side
	c["first"] = first
	c["last"] = last


## One of a burst's bolts flies, arriving at `at` (level time): the burst's arrivals take it in (the
## runner's speed may have changed since the prediction).
func arrives(c: Dictionary, at: float) -> void:
	c["first"] = minf(float(c["first"]), at)
	c["last"] = maxf(float(c["last"]), at)


## The bursts in the air: claims still on whose shooter is still in play.
func bursts(now: float) -> int:
	var count: int = 0
	for c: Dictionary in _claims:
		if not bool(c["whole"]) and _on(c, now):
			count += 1
	return count


## Whether a burst may start now: nothing holds the whole airspace and fewer than `most` bursts are in
## the air.
func may_start(now: float, most: int) -> bool:
	_prune(now)
	var count: int = 0
	for c: Dictionary in _claims:
		if not _on(c, now):
			continue
		if bool(c["whole"]):
			return false
		count += 1
	return count < most


## Until when (level time) a claim still in play holds the airspace: the latest, a burst's or a boss's;
## -1e9 when none does.
func claimed_until(now: float) -> float:
	var until: float = -1.0e9
	for c: Dictionary in _claims:
		if _on(c, now):
			until = maxf(until, float(c["until"]))
	return until


## The other bursts (not `own`) whose bolts arrive within `gap` seconds of `first` to `last` (level
## times). `aimed_only`: only those whose aim has locked; otherwise bursts still charging count too, as
## predicted (a charge-up whose shooter has left play never fires and doesn't).
func near(own: Dictionary, first: float, last: float, gap: float, aimed_only: bool, now: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for c: Dictionary in _claims:
		if is_same(c, own) or bool(c["whole"]):
			continue
		if not bool(c["aimed"]) and (aimed_only or not _on(c, now)):
			continue
		if float(c["first"]) < last + gap and first < float(c["last"]) + gap:
			out.append(c)
	return out


## True while a claim is on: not over, and its owner still in play.
static func _on(c: Dictionary, now: float) -> bool:
	return float(c["until"]) > now and _in_play(int(c["owner"]))


## Whether the object with instance id `id` is still in play: not freed, not leaving the tree, and for
## an enemy, alive.
static func _in_play(id: int) -> bool:
	var o: Object = instance_from_id(id)
	if o == null:
		return false
	var enemy := o as Enemy
	if enemy != null:
		return enemy.alive and not enemy.is_queued_for_deletion()
	var node := o as Node
	return node == null or not node.is_queued_for_deletion()


## Drops what can no longer matter: claims that are over (or whose owner is gone) and whose bolts, if
## any flew, all arrived more than KEEP_AFTER ago.
func _prune(now: float) -> void:
	for i: int in range(_claims.size() - 1, -1, -1):
		var c: Dictionary = _claims[i]
		if _on(c, now):
			continue
		if not bool(c["aimed"]) or float(c["last"]) + KEEP_AFTER < now:
			_claims.remove_at(i)
