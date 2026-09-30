class_name PickupField
extends Node3D
## In-run pickups (GDD §10): armor, shield and grapple pickups on the floor, which the player takes by
## running through them. The GDD puts them in boss fights only ("some fights may also offer pickups",
## and the standard armor rule, BossEncounter.armor_pickup_due), so levels never place any; a boss
## script offers them through BossEncounter.offer_pickup(), and quick play shows them for review
## (--pickups). RunWorld creates this node for every run.
##
## offer(item, at, lane) asks for a pickup; it appears at the first fair spot, now or as soon as there
## is one (an offer waits while nothing in reach is fair). A fair spot is (PickupTuning):
## - ahead of the player, at least lead_distance away and within search_window beyond it, on the built
##   track: in plain view, with time to see it and change lanes;
## - within reach: at most reach_lanes from the player's lane (the nearest lanes first; a wall runner
##   counts as the outer lane on that side, a ceiling rider as the lane under them);
## - on floor with nothing in the way: from clear_before before the spot to clear_after after it, its
##   lane has no gap (so never over or at the edge of one), no fence of any kind (so never in one or
##   under a gapped fence's hitbox), no pad, ramp or speed pad, no ceiling overhead (plain view, and a
##   ceiling rider has landed before it), and no enemy: none planned on the track near its lane, and no
##   hitbox, fence, block or lane blocker in play there up to clear_height;
## - not where an attack is telegraphed: no boss floor warning (BossProps.warned) over it.
## `at` asks for a spot at or after a track distance (a boss's section of floor), `lane` for a lane
## (the nearest lane to it within reach is used); the fairness rules hold either way.
##
## Taking it: the player's hitbox (swept over the frame) reaching its take_box() takes it: one charge
## of a shield or grapple (Player.gain_item, up to PickupTuning.max_charges), counted as the fight's
## rather than the player's (Loadout.picked_up: breaking it costs no stock), or the armor back whole at
## once (GDD §4, §8: DamageRules.Armor.take_pickup, which adds a hit to whole armor), with the pickup
## sound and a burst. A pickup the player has run past is missed and gone. Pickups are pooled.
##
## DESIGN-TBD (docs/questions/b7.md): where a pickup appears (PickupTuning), that an offer waits for a
## fair spot however long it takes, and that a missed pickup is gone for good.
##
## Signals for the HUD, hints and tests: spawned, collected (with whether a charge was added), missed.

## A pickup appeared on the track.
signal spawned(pickup: Pickup)
## The player took it; `gained` is false when they already held all the charges they can.
signal collected(pickup: Pickup, gained: bool)
## The player ran past it: it's gone.
signal missed(pickup: Pickup)

const TUNING_PATH: String = "res://data/tuning/pickups.tres"
## The breakable items a pickup can give (GDD §10: armor, shield or grapple).
const ITEMS: Array[StringName] = [&"armor", &"shield", &"grapple"]
## Quick play's review aid (--pickups): seconds between pickups.
const REVIEW_SECONDS: float = 5.0
## How far past its `at` a pad, ramp or speed pad may reach (more than any of their lengths), for
## local_layout().
const PIECE_REACH: float = 10.0
## The check for things in play covers the stretch this much less at each end (see _in_play_near).
const EDGE: float = 0.25

var world: RunWorld
var tuning: PickupTuning
## Pickups on the track now (takeable), in the order they appeared.
var active: Array[Pickup] = []
## Offers waiting for a fair spot, in order: {item, at, lane}.
var pending: Array[Dictionary] = []
## Pickups made so far (taken from the pool or new), for tests of the pooling.
var made: int = 0

var _pool: Array[Pickup] = []
var _query := PhysicsShapeQueryParameters3D.new()
var _box := BoxShape3D.new()
var _review: PackedStringArray = []
var _review_next: int = 0
var _review_timer: float = 0.0


## Starts the run's pickups afresh: nothing on the track, nothing waiting, and no charges picked up
## yet in the run's loadout.
func setup(p_world: RunWorld) -> void:
	world = p_world
	if tuning == null:
		tuning = load(TUNING_PATH) as PickupTuning if ResourceLoader.exists(TUNING_PATH) else null
		if tuning == null:
			tuning = PickupTuning.new()
	clear()
	if world.loadout != null:
		world.loadout.picked_up.clear()
	_query.shape = _box
	_query.collide_with_areas = true
	_query.collide_with_bodies = false
	_query.collision_mask = TrackBuilder.LAYER_HAZARD | TrackBuilder.LAYER_LANE_BLOCKER


## Asks for a pickup of `item` (&"armor", &"shield" or &"grapple"): at the first fair spot ahead of the
## player (see the header), at or after track distance `at` if given, in or nearest to `lane` if given.
## It appears at once if a spot is fair now, else as soon as one is. Returns false for an unknown item.
func offer(item: StringName, at: float = -1.0, lane: int = -1) -> bool:
	if not ITEMS.has(item):
		push_warning("PickupField: no pickup for '%s' (only %s)" % [item, ITEMS])
		return false
	pending.append({"item": item, "at": at, "lane": lane})
	if world != null and world.player != null and world.player.alive:
		_place_pending()
	return true


## Removes every pickup on the track and every offer still waiting (a boss beaten: no pickup after
## the fight).
func clear() -> void:
	pending.clear()
	for p: Pickup in active.duplicate():
		_to_pool(p)
	active.clear()


## Quick play's review aid (--pickups, debug builds): offers `items` in turn, one every few seconds,
## so their look can be checked in any zone. Levels never place pickups in the game (GDD §10).
func start_review(items: PackedStringArray) -> void:
	_review = PackedStringArray()
	for item: String in items:
		if ITEMS.has(StringName(item)):
			_review.append(item)
	_review_next = 0
	_review_timer = 1.0


## Pickups waiting for a fair spot.
func waiting() -> int:
	return pending.size()


## The first fair spot for a pickup (see the header): {lane, at}, or {} if none is fair right now.
## Nearer spots come first, and at each distance the nearer lanes (reachable_lanes).
func find_spot(at: float = -1.0, lane: int = -1) -> Dictionary:
	var player: Player = world.player
	var first: float = player.distance + tuning.lead_distance
	if at >= 0.0:
		first = maxf(first, at)
	var last: float = minf(first + tuning.search_window,
		minf(world.track.built_until(), world.layout.length) - tuning.clear_after)
	if last < first:
		return {}
	# Only the pieces around the stretch searched: a boss arena's layout grows lap after lap.
	var near: LevelLayout = local_layout(world.layout, first - tuning.clear_before, last + tuning.clear_after)
	var lanes: Array[int] = reachable_lanes(lane)
	var d: float = first
	while d <= last + 0.001:
		for l: int in lanes:
			if layout_fair(near, l, d, tuning, world.tuning) and not _in_play_near(l, d) and not _telegraphed(l, d):
				return {"lane": l, "at": d}
		d += maxf(tuning.search_step, 0.1)
	return {}


## The lanes within reach of the player (PickupTuning.reach_lanes), nearest first: to the player's
## lane, or to `prefer` if given (its nearest reachable lanes), then toward the middle of the track.
func reachable_lanes(prefer: int = -1) -> Array[int]:
	var count: int = world.geo.lane_count
	var own: int = player_lane()
	var to: int = clampi(prefer, 0, count - 1) if prefer >= 0 else own
	var out: Array[int] = []
	for l: int in count:
		if absi(l - own) <= tuning.reach_lanes:
			out.append(l)
	var middle: float = (count - 1) * 0.5
	out.sort_custom(func(a: int, b: int) -> bool:
		if absi(a - to) != absi(b - to):
			return absi(a - to) < absi(b - to)
		if not is_equal_approx(absf(a - middle), absf(b - middle)):
			return absf(a - middle) < absf(b - middle)
		return a < b)
	return out


## The lane the player is in or over: a wall runner counts as the outer lane on that side.
func player_lane() -> int:
	var p: Player = world.player
	if p.surface == Player.Surface.WALL:
		return 0 if p.wall_side < 0 else world.geo.lane_count - 1
	return clampi(p.lane, 0, world.geo.lane_count - 1)


## True if a pickup in `lane` at track distance `at` would be fair now: the track there (layout_fair),
## nothing in play in the way (hitboxes, fences, blocks, lane blockers) and no attack telegraphed.
func spot_fair(lane: int, at: float) -> bool:
	return layout_fair(world.layout, lane, at, tuning, world.tuning) and not _in_play_near(lane, at) \
		and not _telegraphed(lane, at)


## The track's part of the fairness rules, from the layout alone: in `lane` from clear_before before
## `at` to clear_after after it, floor with no gap, no fence of any kind, no pad, ramp or speed pad, no
## ceiling overhead, no floor-using enemy planned in or near the lane, and all of it before the track's
## end. `movement` gives the pads' and ramps' lengths.
static func layout_fair(layout: LevelLayout, lane: int, at: float, t: PickupTuning, movement: MovementTuning) -> bool:
	var from: float = at - t.clear_before
	var to: float = at + t.clear_after
	if from < 0.0 or to > layout.length or lane < 0 or lane >= layout.lane_count:
		return false
	if layout.gapped_between(lane, from, to):
		return false
	for f: Dictionary in layout.fences:
		if int(f["lane"]) == lane and float(f["at"]) >= from and float(f["at"]) <= to:
			return false
	for h: Dictionary in layout.hulls:
		if float(h["start"]) <= to and float(h["end"]) >= from:
			return false
	if _piece_in(layout.pads, lane, from, to, movement.pad_length) \
			or _piece_in(layout.speed_pads, lane, from, to, movement.speed_pad_length):
		return false
	for r: Dictionary in layout.ramps:
		if layout.outer_lane(int(r["side"])) == lane and float(r["at"]) <= to and float(r["at"]) + movement.ramp_length >= from:
			return false
	for e: Dictionary in layout.enemies:
		# Enemies that never use the floor (fliers, wall enemies) have an empty span.
		if absi(int(e.get("lane", lane)) - lane) > t.enemy_lane_margin:
			continue
		var span: Vector2 = LevelGenerator.enemy_floor_span(e)
		if span.x <= to and span.y >= from:
			return false
	return true


## The pieces of `layout` that reach into the stretch [from, to] (enemies by the floor they use), with
## its lane count and length: enough to check every spot in that stretch with layout_fair.
static func local_layout(layout: LevelLayout, from: float, to: float) -> LevelLayout:
	var out := LevelLayout.new()
	out.lane_count = layout.lane_count
	out.length = layout.length
	for g: Dictionary in layout.gaps:
		if float(g["start"]) <= to and float(g["end"]) >= from:
			out.gaps.append(g)
	for f: Dictionary in layout.fences:
		if float(f["at"]) >= from and float(f["at"]) <= to:
			out.fences.append(f)
	for h: Dictionary in layout.hulls:
		if float(h["start"]) <= to and float(h["end"]) >= from:
			out.hulls.append(h)
	# Pads, ramps and speed pads reach a few metres past their `at`.
	for p: Dictionary in layout.pads:
		if float(p["at"]) <= to and float(p["at"]) + PIECE_REACH >= from:
			out.pads.append(p)
	for p: Dictionary in layout.speed_pads:
		if float(p["at"]) <= to and float(p["at"]) + PIECE_REACH >= from:
			out.speed_pads.append(p)
	for r: Dictionary in layout.ramps:
		if float(r["at"]) <= to and float(r["at"]) + PIECE_REACH >= from:
			out.ramps.append(r)
	for e: Dictionary in layout.enemies:
		var span: Vector2 = LevelGenerator.enemy_floor_span(e)
		if span.x <= to and span.y >= from:
			out.enemies.append(e)
	return out


## True if a piece of `list` ({lane, at}, `length` long from `at`) in `lane` reaches into [from, to].
static func _piece_in(list: Array[Dictionary], lane: int, from: float, to: float, length: float) -> bool:
	for p: Dictionary in list:
		if int(p["lane"]) == lane and float(p["at"]) <= to and float(p["at"]) + length >= from:
			return true
	return false


func _physics_process(delta: float) -> void:
	if world == null or world.player == null or not world.player.running or not world.player.alive:
		return
	if not _review.is_empty():
		_update_review(delta)
	if not pending.is_empty():
		_place_pending()
	if active.is_empty():
		return
	var player: Player = world.player
	var motion: float = player.speed * delta
	# The player's hitbox, swept back over this frame's motion, like the hazard checks.
	var box: AABB = player.hurtbox_aabb()
	box = box.merge(AABB(box.position + Vector3(0.0, 0.0, motion), box.size))
	for p: Pickup in active.duplicate():
		if box.intersects(p.take_box()):
			_take(p)
		elif player.distance > p.at + tuning.miss_distance:
			_miss(p)


func _place_pending() -> void:
	var i: int = 0
	while i < pending.size():
		var offer_entry: Dictionary = pending[i]
		var spot: Dictionary = find_spot(float(offer_entry["at"]), int(offer_entry["lane"]))
		if spot.is_empty():
			i += 1
			continue
		pending.remove_at(i)
		_spawn(StringName(offer_entry["item"]), int(spot["lane"]), float(spot["at"]))


func _spawn(item: StringName, lane: int, at: float) -> Pickup:
	var p: Pickup = _pool.pop_back() if not _pool.is_empty() else null
	if p == null:
		p = Pickup.new()
		add_child(p)
		p.vanished.connect(_on_vanished)
	made += 1
	p.show_item(item, lane, at, world.lane_point(lane, at), tuning)
	active.append(p)
	world.effects.burst(p.position + Vector3(0.0, tuning.float_height, 0.0), Pickup.RING_COLOR, 16, 0.45)
	world.play_sfx(&"pickup_appear")
	spawned.emit(p)
	return p


func _take(p: Pickup) -> void:
	active.erase(p)
	var gained: bool = world.player.gain_item(p.item, tuning.max_charges)
	# A picked-up charge is the fight's (it costs no stock); the armor is no stock at all (GDD §8).
	if gained and world.loadout != null and p.item != &"armor":
		world.loadout.add_picked_up(p.item)
	world.play_sfx(&"pickup")
	world.effects.burst(p.badge_position(), Pickup.RING_COLOR, 22, 0.6)
	p.take(world.player.hurtbox_aabb().get_center())
	collected.emit(p, gained)


func _miss(p: Pickup) -> void:
	active.erase(p)
	p.miss()
	missed.emit(p)


func _to_pool(p: Pickup) -> void:
	p.release()
	if not _pool.has(p):
		_pool.append(p)


func _on_vanished(p: Pickup) -> void:
	if not active.has(p):
		_to_pool(p)


## True if something in play would be in the way of a pickup at the spot: an enemy's hitbox, a fence
## (of the track or a boss's, whatever its state), a block, or a solid side, from the floor up to
## clear_height over the lane from clear_before before the spot to clear_after after it. Signs are
## wall pieces (a floor runner never touches one) and don't count.
func _in_play_near(lane: int, at: float) -> bool:
	if not is_inside_tree():
		return false
	# A hair inside the stretch the layout checks, so a track fence just outside it (its hitbox has
	# some depth) doesn't count here when it doesn't there.
	var from: float = at - tuning.clear_before + EDGE
	var to: float = at + tuning.clear_after - EDGE
	_box.size = Vector3(world.geo.lane_width * 0.9, tuning.clear_height, to - from)
	_query.transform = Transform3D(Basis.IDENTITY,
		Vector3(world.geo.lane_x(lane), tuning.clear_height * 0.5, TrackGeometry.world_z((from + to) * 0.5)))
	for hit: Dictionary in get_world_3d().direct_space_state.intersect_shape(_query, 16):
		var area := hit["collider"] as Area3D
		if area == null or area.collision_layer & TrackBuilder.LAYER_WALL_BLOCKER:
			continue
		var hazard := area as Hazard
		if hazard == null:
			return true  # a lane blocker (a solid side)
		if hazard.is_electrical or hazard.state != Hazard.State.OFF:
			return true
	return false


## True if a boss's floor warning (a lane about to be struck, a bomb's circle) covers the spot.
func _telegraphed(lane: int, at: float) -> bool:
	var encounter: BossEncounter = BossEncounter.of(world)
	if encounter == null or encounter.props == null:
		return false
	return encounter.props.warned(lane, at - tuning.clear_before, at + tuning.clear_after)


func _update_review(delta: float) -> void:
	_review_timer -= delta
	if _review_timer > 0.0 or not active.is_empty() or not pending.is_empty():
		return
	_review_timer = REVIEW_SECONDS
	offer(StringName(_review[_review_next % _review.size()]))
	_review_next += 1
