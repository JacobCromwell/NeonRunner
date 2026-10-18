extends RefCounted
## Generator rules for the treasure stash (task I4; GDD §3, "Ceiling scenarios", owner, October 14, 2026): "a
## separate return pad partway along a ceiling (apart from the ceiling's usual way back down at its end) sends the
## player back to the floor as usual, and it is the only way into a treasure stash: a stretch of floor walled off by
## doodads. For a stash in the third lane: a doodad at its start in that lane, and doodads in the two adjacent
## lanes alongside it, so a player strictly on the floor can't get in. It holds two or three of the
## highest-denomination credits." LevelGenerator runs apply() for levels with the `treasure_stash` feature (never
## in zones 1-2: from Casino 1), after every rule that places ceilings, pads or floor enemies and before those that
## plan around them (RUN_AFTER), and turns up to LevelConfig.treasure_stashes of the level's ceilings into a stash's
## (CeilingScenarios: candidates, choose; the first from the feature's start in a level that gives it one, its
## introduction), only where the level's difficulty has reached CeilingScenarioTuning.stash_min_difficulty
## (endless mode's later part).
## On a ceiling it takes:
## - the stash's lane: an inner lane with inner lanes either side (lanes_for), so its walls never stand in an
##   outermost lane (a wall runner's body reaches into that lane, and one dropping off the wall lands there) and a
##   floor runner always has a lane past it; covered by the ceiling. With fewer than 5 lanes there's none, and no
##   stash (DESIGN-TBD, item 837: on 3 lanes the owner's shape would close every floor lane);
## - the return pad, in that lane on the ceiling's underside (LevelLayout.return_pads), see_seconds after where the
##   ceiling's rider arrives at the earliest, as late as the ceiling allows (partway along it); the ceiling runs on
##   past the stash (ceiling_after_seconds) where it must (CeilingScenarios.can_extend), so a rider who stays on drops
##   beyond it, and the chase camera of one riding over it rises above its doodads (RunCamera.doodad_floor);
## - the stash, from where the return pad's rider can't miss it (stash_offsets): a doodad across its lane
##   (front_size) whose end the rider passes over before coming down to its top (drop_clearance, the Player's fall:
##   CeilingScenarios.drop_seconds); doodads alongside in both neighbouring lanes, back to back (wall_chain), from
##   wall_overlap before its end (a runner beside it can't slip in where it ends) to the stash's open end; the credits
##   in its lane past where the rider lands at the latest (CeilingScenarios.flip_late, a frame's slack) and past the
##   top magnet's reach from the floor (magnet_reach), two or three of the highest denomination
##   (LevelGenerator.DENOMINATIONS), the last credit_end_margin inside the open end;
## - a second doodad across its lane in front of that one, toward the runner (the owner, October 18, 2026: "a doodad,
##   a space, then a second doodad, and then the treasure": a dash from the floor got in; outer_size): the stash's
##   start, with a space between the two as long as the most a dash that smashes the outer one still carries the
##   runner past its end (dash_space), so no single dash smashes both. The lanes beside the outer doodad and the space
##   stay open (DESIGN-TBD, docs/questions/n1.md): a runner it pushes, or one whose dash ended in the space, meets the
##   front doodad's push with room for it, as a runner in the stash's lane always did;
## - its floor in every lane, from the outer doodad's push (LevelGenerator.doodad_lead_for) to the level's spacing
##   past its open end (doodad_after), off everything another rule keeps (CeilingScenarios.busy_spans), every pad's
##   zone, ramp's wall run, speed pad and other ceiling; the holes and fences there go (CeilingScenarios.clear_floor).
## A floor runner meets the outer doodad's push into a neighbouring lane or, in the space, the front doodad's, then the
## wall's push further out: the walls push outward (their side), and every push finds room (Player._start_push), as
## the walls start only past where the front doodad's push lands. The walls' sides keep a runner beside them out. A
## dash at the outer doodad smashes it and ends in the space, short of the front one, which pushes as usual; a floor
## runner still gets in, the harder way the owner allowed: around the outer doodad, into the space, then a dash through
## the front one (H5; items 836–845 (docs/OPEN_QUESTIONS*.md)). The stash's doodads join LevelLayout.doodads at once (marked "stash"), so the rules after it
## see them (the Resonator's pulses keep off them, the Enforcer Truck's showing reads them), and the zone doodads'
## look seeds don't count them; everything after the rules keeps off its floor (doodad_keep_outs, fill_keep_outs).
## DESIGN-TBD throughout (items 836–845 (docs/OPEN_QUESTIONS*.md)).

const FEATURE: String = "treasure_stash"
## Sprinkled in (GDD §3: "sprinkle them in during later zones"), never guaranteed: a level gets a stash only where one
## fits (no patterns force one; with fewer than 5 lanes there's none), so the campaign's checks don't ask every build
## of a level that lists the feature for one (LayoutChecks.occasional; test_ceiling_scenarios counts them).
const OCCASIONAL: bool = true
## Every feature whose rules place, move or drop floor enemies, plan charges or cuts, or add ceilings, pads and
## ramps: a stash takes a ceiling of the level's final floor. The rules that plan around what's on the floor and
## its ceilings run after it (their own RUN_AFTER): the Barnacle Turrets (never on a scenario's ceiling), the
## Resonator's pulses (never over a doodad, a pad or a landing), the Enforcer Truck's showing windows and the dash
## walls (which keep off every ceiling and its landing).
const RUN_AFTER: Array[String] = ["ramps", "ceilings", "pulsing", "speed_pads", "cyborg", "window_cyborg", "host",
	"hover_truck", "octodog", "screech", "screech_vents", "drone", "generator", "wall_fences", "wall_fences_partial",
	"buzz_overdrive", "tithe_collector", "gilded_sentinel", "floor_cutter"]
## The walls alongside start at least this far past the front doodad's front (metres): its push looks for room
## beside it (Player._push_room) just before the runner reaches it.
const PUSH_ROOM: float = 0.5
## A stash's credits float this high above the floor (as a floor trail's).
const CREDIT_HEIGHT: float = 0.7
## The power-ups' numbers: the magnet's pull radius by tier (magnet_reach).
const POWERUPS_PATH: String = "res://data/tuning/powerups.tres"


static func apply(gen: LevelGenerator) -> void:
	var count: int = gen.config.treasure_stashes
	if count <= 0 or lanes_for(gen.layout.lane_count).is_empty():
		return
	var t: CeilingScenarioTuning = CeilingScenarios.tuning()
	var busy: Array[Vector2] = CeilingScenarios.busy_spans(gen)
	var plans: Array[Dictionary] = []
	for h: Dictionary in CeilingScenarios.candidates(gen, 1):
		var plan: Dictionary = plan_on(gen, t, h, busy)
		if not plan.is_empty():
			plans.append(plan)
	var chosen: Array[Dictionary] = CeilingScenarios.choose(gen, FEATURE, plans, count, gen.rng_for(FEATURE),
		CeilingScenarios.taken_spans(gen))
	for c: Dictionary in chosen:
		# Planned again on the level as it stands now (a stash before it cleared floor and keeps its own).
		var plan: Dictionary = plan_on(gen, t, c["hull"], CeilingScenarios.busy_spans(gen))
		if not plan.is_empty():
			_build(gen, plan)


## The lanes a stash may take at `lanes` lanes: an inner lane with an inner lane either side (the stash's walls
## never stand in an outermost lane). None with fewer than 5 lanes.
static func lanes_for(lanes: int) -> Array[int]:
	var out: Array[int] = []
	for lane: int in range(2, lanes - 2):
		out.append(lane)
	return out


## A stash's plan on ceiling `h` (see the header), or {} where none fits: {hull, lane, pad (the return pad's
## track distance), end (the ceiling's end with it), area (its floor, Vector2), span (its ceiling to its landing
## zone's end), offsets (stash_offsets)}. `busy`: CeilingScenarios.busy_spans. Changes nothing.
static func plan_on(gen: LevelGenerator, t: CeilingScenarioTuning, h: Dictionary, busy: Array[Vector2]) -> Dictionary:
	var layout: LevelLayout = gen.layout
	var v: float = gen.speed
	var pads: Array[Dictionary] = CeilingScenarios.pads_under(layout, h)
	if pads.is_empty():
		return {}
	var first_pad: float = float(pads[0]["at"])
	var last_pad: float = float(pads[-1]["at"])
	if not gen.feature_started(FEATURE, first_pad):
		return {}
	var lane: int = _lane_on(gen, h)
	if lane < 0:
		return {}
	var offsets: Dictionary = stash_offsets(gen, t, credit_count(gen, t, h))
	# Where the rider arrives at the latest, and the return pad no sooner than see_seconds after; as late as the
	# ceiling allows without running it on.
	var arrive: float = CeilingScenarios.flip_late(last_pad, v) + v * CeilingScenarios.rise_seconds(gen.tuning, 0.0)
	var tail: float = float(offsets["end"]) + t.ceiling_after_seconds * v
	var pad: float = maxf(arrive + t.see_seconds * v, float(h["end"]) - tail)
	if gen.difficulty_at(clampf(pad / layout.length, 0.0, 1.0)) < t.stash_min_difficulty - 0.0001:
		return {}
	var end: float = maxf(float(h["end"]), pad + tail)
	var lead: float = LevelGenerator.doodad_lead_for(gen.tuning)
	var walls_end: float = pad + float(offsets["end"])
	var area := Vector2(pad + float(offsets["outer_start"]) - lead, walls_end + gen.doodad_after(walls_end))
	if area.y > layout.length - gen.config.end_clear_distance or area.x <= float(h["start"]):
		return {}
	if CeilingScenarios.hits(busy, area.x, area.y) or not _floor_free(gen, h, area):
		return {}
	if end > float(h["end"]) and not CeilingScenarios.can_extend(gen, h, end, busy):
		return {}
	var landing_end: float = end + gen.zones.landing
	return {"hull": h, "lane": lane, "pad": pad, "end": end, "area": area, "offsets": offsets,
		"span": Vector2(float(h["start"]), landing_end)}


## Where a stash's pieces lie, in metres from its return pad's start, at `gen`'s run speed, with `credits` credits
## (see the header): {front (the size class of the doodad right before its treasure), front_start, front_end, outer
## (the outer doodad's size class), outer_start, outer_end (the stash's start and that doodad's end, the space
## before front_start), land (where the return pad's rider lands at the latest), credits (Array[float]), walls_from,
## chain (the walls' size classes, back to back), end (its open end)}.
static func stash_offsets(gen: LevelGenerator, t: CeilingScenarioTuning, credits: int) -> Dictionary:
	var mt: MovementTuning = gen.tuning
	var v: float = gen.speed
	var front: StringName = LevelLayout.DOODAD_SIZES[clampi(t.front_size, 0, LevelLayout.DOODAD_SIZES.size() - 1)]
	var outer: StringName = LevelLayout.DOODAD_SIZES[clampi(t.outer_size, 0, LevelLayout.DOODAD_SIZES.size() - 1)]
	# The return pad's rider, flipped as early as can be, still has their feet drop_clearance above the front
	# doodad's top (and a foot's reach: Player._support_top) as they pass its end: they never land on it.
	var front_end: float = CeilingScenarios.flip_early(0.0) \
		+ v * CeilingScenarios.drop_seconds(mt, mt.doodad_height + t.drop_clearance) - mt.foot_half_depth
	var front_start: float = front_end - mt.doodad_size(front).z
	# The owner, October 18, 2026: the second doodad, a space before that one (dash_space).
	var outer_end: float = front_start - dash_space(mt, v, t)
	var outer_start: float = outer_end - mt.doodad_size(outer).z
	# ... and lands at the latest a frame after the fall alone takes them to the floor.
	var land: float = CeilingScenarios.flip_late(0.0, v) \
		+ v * (CeilingScenarios.drop_seconds(mt, 0.0) + CeilingScenarios.frame_seconds())
	var walls_from: float = maxf(front_start + PUSH_ROOM, front_end - t.wall_overlap)
	# Past the top magnet's reach from the floor (task I4's review: "out of the magnet's reach only by luck"). The
	# magnet reaches a credit from a lane next to the player's at most (CreditField.MAGNET_LANES), and a floor runner
	# that close to the stash's lane is short of its walls' start: beside a wall, its push keeps the body more than a
	# lane and a quarter out. From there it pulls up to magnet_reach() ahead of the body's middle; a frame's run on.
	var first: float = maxf(land + gen.metres(t.credit_lead),
		walls_from + magnet_reach() + v * CeilingScenarios.frame_seconds())
	var spots: Array[float] = []
	for i: int in maxi(credits, 1):
		spots.append(first + gen.metres(i * t.credit_spacing))
	var need: float = spots[-1] + t.credit_end_margin
	var chain: Array[StringName] = wall_chain(mt, need - walls_from)
	var length: float = 0.0
	for s: StringName in chain:
		length += mt.doodad_size(s).z
	return {"front": front, "front_start": front_start, "front_end": front_end, "outer": outer,
		"outer_start": outer_start, "outer_end": outer_end, "land": land, "credits": spots, "walls_from": walls_from,
		"chain": chain, "end": walls_from + length}


## How far the juggernaut dash carries a runner at run speed `v` (metres): its time at its speed bonus (PowerupTuning:
## the same at every tier, only its cooldown changes), plus the most a speed pad's or a ramp's fading boost adds over
## that time (MovementTuning.boost_distance). A doodad whose front lies further than that ahead of a dasher's body is
## one the dash can't claim (Player._dash_claims: a claim needs the dash to reach it before it ends).
static func dash_carry(mt: MovementTuning, v: float) -> float:
	var pt := load(POWERUPS_PATH) as PowerupTuning if ResourceLoader.exists(POWERUPS_PATH) else null
	var duration: float = pt.dash_duration if pt != null else 0.6
	var bonus: float = pt.dash_speed_bonus if pt != null else 8.0
	return (v + bonus) * duration + mt.boost_distance(maxf(mt.speed_pad_boost, mt.ramp_speed_boost), duration)


## The space between a stash's two doodads in its lane, from the outer one's end to the front one's front (metres, at
## run speed `v`): no single dash smashes both (the owner, October 18, 2026: "a dash from the floor got into the
## stash"). The latest dash that still smashes the outer doodad starts with the body beside its end (a dashing switch
## into its side: its front a body's length past the end, MovementTuning.visual_size), and carries the runner
## dash_carry on; a frame of the dash's speed covers the physics' frame steps, and outer_space_margin more. At the
## Casino's 23 m/s it is 23.1 m (1.0 s of run), at the Golden Zone's 25 m/s 24.4 m.
static func dash_space(mt: MovementTuning, v: float, t: CeilingScenarioTuning) -> float:
	var pt := load(POWERUPS_PATH) as PowerupTuning if ResourceLoader.exists(POWERUPS_PATH) else null
	var fastest: float = v + (pt.dash_speed_bonus if pt != null else 8.0) + maxf(mt.speed_pad_boost, mt.ramp_speed_boost)
	return dash_carry(mt, v) + mt.visual_size.z + fastest * CeilingScenarios.frame_seconds() + t.outer_space_margin


## How far ahead of a player's middle the top tier of the magnet pulls a credit (CreditField._in_magnet:
## MAGNET_AHEAD of PowerupTuning.magnet_radius's largest radius), in metres; 0 without the power-ups' numbers.
static func magnet_reach() -> float:
	var pt := load(POWERUPS_PATH) as PowerupTuning if ResourceLoader.exists(POWERUPS_PATH) else null
	var radius: float = 0.0
	if pt != null:
		for r: float in pt.magnet_radius:
			radius = maxf(radius, r)
	return CreditField.MAGNET_AHEAD * radius


## The size classes of a stash's wall (LevelLayout.DOODAD_SIZES), back to back, at least `length` metres: the
## largest while more than one of them is left, then the smallest that covers the rest.
static func wall_chain(mt: MovementTuning, length: float) -> Array[StringName]:
	var out: Array[StringName] = []
	var largest: StringName = LevelLayout.DOODAD_SIZES[-1]
	var left: float = length
	while left > 0.001:
		var pick: StringName = largest
		if left <= mt.doodad_size(largest).z:
			for s: StringName in LevelLayout.DOODAD_SIZES:
				if mt.doodad_size(s).z >= left:
					pick = s
					break
		out.append(pick)
		left -= mt.doodad_size(pick).z
	return out


## How many credits the stash on ceiling `h` holds: between credits_min and credits_max, from the ceiling's spot.
static func credit_count(gen: LevelGenerator, t: CeilingScenarioTuning, h: Dictionary) -> int:
	var lo: int = mini(t.credits_min, t.credits_max)
	var hi: int = maxi(t.credits_min, t.credits_max)
	return lo + posmod(hash([gen.config.level_seed, FEATURE, "credits", snappedf(float(h["start"]), 0.01)]), hi - lo + 1)


## The stash's lane on ceiling `h`: one of lanes_for() the ceiling covers, from the ceiling's spot; -1 if none.
static func _lane_on(gen: LevelGenerator, h: Dictionary) -> int:
	var covered: Vector2i = gen.layout.hull_lanes(h)
	var lanes: Array[int] = []
	for lane: int in lanes_for(gen.layout.lane_count):
		if CeilingZones.in_lanes(lane, covered):
			lanes.append(lane)
	if lanes.is_empty():
		return -1
	return lanes[posmod(hash([gen.config.level_seed, FEATURE, "lane", snappedf(float(h["start"]), 0.01)]), lanes.size())]


## True if nothing but plain holes and fences stands on the floor in `area`, in any lane: no pad's zone, ramp's
## wall run, speed pad or other ceiling (from its start to its landing zone's end).
static func _floor_free(gen: LevelGenerator, h: Dictionary, area: Vector2) -> bool:
	var layout: LevelLayout = gen.layout
	for p: Dictionary in layout.pads:
		var zone: Vector2 = gen.zones.pad_zone(float(p["at"]))
		if zone.x <= area.y and zone.y >= area.x:
			return false
	for r: Dictionary in layout.ramps:
		var at: float = float(r["at"])
		if at <= area.y and maxf(gen.ramp_launch(r).end(), at + gen.tuning.ramp_length) >= area.x:
			return false
	for s: Dictionary in layout.speed_pads:
		if float(s["at"]) <= area.y and float(s["at"]) + gen.tuning.speed_pad_length >= area.x:
			return false
	for other: Dictionary in layout.hulls:
		if not is_same(other, h) and float(other["start"]) <= area.y and gen.zones.landing_zone(other).y >= area.x:
			return false
	return true


## Turns plan `plan` (plan_on) into the stash: clears its floor, runs its ceiling on where it must, marks the
## ceiling, and adds its return pad, its record (LevelLayout.stashes), its doodads (marked "stash": the outer one
## across its lane at its start, the space, the front one across its lane before its treasure, its walls alongside in
## both neighbouring lanes, pushing outward, back to back to its open end; each with a look seed of its own, and the
## zone doodads' seeds don't count them) and its credits.
static func _build(gen: LevelGenerator, plan: Dictionary) -> void:
	var layout: LevelLayout = gen.layout
	var h: Dictionary = plan["hull"]
	var pad: float = plan["pad"]
	var lane: int = plan["lane"]
	var area: Vector2 = plan["area"]
	var o: Dictionary = plan["offsets"]
	CeilingScenarios.clear_floor(gen, area.x, area.y, Vector2i(0, layout.lane_count - 1))
	if float(plan["end"]) > float(h["end"]):
		CeilingScenarios.extend(gen, h, plan["end"])
	h[CeilingScenarios.KEY] = FEATURE
	layout.return_pads.append({"lane": lane, "at": pad})
	var seed: int = hash([gen.config.level_seed, FEATURE, layout.stashes.size()])
	var start: float = pad + float(o["outer_start"])
	var front: float = pad + float(o["front_start"])
	var walls_from: float = pad + float(o["walls_from"])
	layout.stashes.append({"lane": lane, "start": start, "front": front, "end": pad + float(o["end"]),
		"walls_from": walls_from, "pad": pad, "hull_start": float(h["start"]), "keep_from": area.x, "keep_to": area.y})
	var outer_seed: int = hash([seed, "outer"])
	layout.doodads.append({"lane": lane, "start": start, "end": pad + float(o["outer_end"]), "size": o["outer"],
		"side": -1 if posmod(outer_seed, 2) == 0 else 1, "seed": outer_seed, "stash": true})
	layout.doodads.append({"lane": lane, "start": front, "end": pad + float(o["front_end"]), "size": o["front"],
		"side": -1 if posmod(seed, 2) == 0 else 1, "seed": hash([seed, "front"]), "stash": true})
	for side: int in [-1, 1]:
		var cursor: float = walls_from
		var k: int = 0
		for size: StringName in o["chain"]:
			var length: float = gen.tuning.doodad_size(size).z
			layout.doodads.append({"lane": lane + side, "start": cursor, "end": cursor + length, "size": size,
				"side": side, "seed": hash([seed, side, k]), "stash": true})
			cursor += length
			k += 1
	var value: int = LevelGenerator.DENOMINATIONS.max()
	for c: float in o["credits"]:
		layout.credits.append({"at": pad + c, "surface": "floor", "lane": lane, "side": 0, "height": CREDIT_HEIGHT,
			"value": value, "risky": true, "stash": true})


## Every stash in `layout`: where it starts (LevelGenerator.feature_positions).
static func positions(layout: LevelLayout) -> Array[float]:
	var out: Array[float] = []
	for s: Dictionary in layout.stashes:
		out.append(float(s["start"]))
	return out


## What the passes after the rules keep off in every lane (LevelGenerator.rules_doodad_keep_outs: the zone doodads,
## the danger density pass, the wider gaps, the cyborgs planted in charge paths, the other scenarios): each stash's
## floor, from its outer doodad's push to the level's spacing past its open end.
static func doodad_keep_outs(gen: LevelGenerator) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s: Dictionary in gen.layout.stashes:
		out.append({"from": float(s["keep_from"]), "to": float(s["keep_to"]), "type": FEATURE})
	return out


## What the fill pass keeps off (LevelGenerator.rules_fill_keep_outs): each stash's floor, as doodad_keep_outs.
static func fill_keep_outs(gen: LevelGenerator) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for s: Dictionary in gen.layout.stashes:
		out.append(Vector2(float(s["keep_from"]), float(s["keep_to"])))
	return out
