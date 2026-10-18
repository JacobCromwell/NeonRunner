class_name WallHopPlacement
extends RefCounted
## Wall-hop credits (task N1; GDD §7, "Wall-hop credits", owner, October 9, 2026: "a gentle nudge toward the wall hop
## (§3). Some long walls carry high-value credits further along than one wall run reaches, so only a player inventive
## enough to wall hop collects them. (Proposed) From Gangland on, about once a level, on a stretch of wall long enough
## with no wall gap"). The wall hop itself is the Player's and stays as it is (GDD §3: it must not be patched out);
## this only lays credits along a wall for it. LevelGenerator's credit pass runs place() for a level with
## LevelConfig.wall_hop_lines (1 from Gangland 1 on), after the ramps' wall-run credits, from a random stream of its
## own (`rng_for("wall_hops")`), so every other credit comes out as before; with 0 it draws nothing.
##
## A line, laid out for the reference hopper (WallHopPath: steps onto the wall from the outer lane at the line's entry
## and wall hops whenever its wall run has come down to WallHopTuning.hop_height), from the shape at the level's speed
## (shape_for):
## - the lead-in: plain credits (lead_value) along the first wall run from the entry, lead_step_seconds apart, until
##   its hop: where to get on, pointing along the wall (they count toward the stars like any);
## - the high-value credits (`gems` of gem_value, gem_step_seconds apart, marked GEM), together in one of the reference
##   hopper's fresh wall runs: the first past where one wall run from the entry (the standard one) has dropped its
##   runner off the wall, by reach_margin_seconds; at gem_height(), above the highest a fresh wall run carries a pickup
##   when its runner never hops (WallHopPath.fresh_top: a step onto the wall from the floor, or straight back onto it
##   as a wall run drops them; pickup_reach) by gem_clearance, so a runner who stays off the wall and steps on further
##   along, or one whose single run claws carry on, passes under them, while a hop starts its fresh wall run higher
##   (MovementTuning.wall_air_entry_factor of the height it hops from); each where the reference hopper passes within
##   its reach. A jump onto the wall from the floor starts high too (DESIGN-TBD,
##   docs/questions/n1.md). They're left out of the stars' best score (LevelLayout.star_credit_value), as a treasure
##   stash's are.
## Its stretch (from run_in_seconds before the entry to where a runner who jumps off the wall at the last high-value
## credit comes down, and landing_seconds after that) is on one side wall, inside the level's clear ends, off
## everything a wall runner, or one who hops off there, could meet (busy_spans): its wall whole (no side wall gap: GDD
## §7, "a stretch of wall ... with no wall gap") and clear of what stands on it (signs, wall enemies, ramps' wall runs,
## wall fences and their drop windows, a wall-run gap's lit wall, a dash wall's wall route, other wall credits:
## LevelGenerator.wall_lane_keep_outs, with its doodad_wall_clear_seconds); the outer lane's floor beside it clear (no
## hole, fence, pad, speed pad, ramp, zone doodad, floor cut's window or ceiling fence there: nothing the hop carries a
## runner into); no enemy in that lane, no hover truck and no attack a wall runner can't dodge (WALL_RUN_ATTACKERS), no
## dash wall and nothing the rules keep in every lane meanwhile; attacks elsewhere come with their warnings, as on any
## wall run. A level takes up to its count, each a seeded spot among those that fit, min_gap_seconds apart; none where
## none fits (it is sprinkled, never guaranteed). problem() re-checks a finished layout (LayoutChecks.check_wall_hops).
## DESIGN-TBD throughout (docs/questions/n1.md).

## The high-value credits' mark (LevelLayout.credits): the stars' best score leaves them out
## (LevelLayout.star_credit_value).
const GEM: String = "wall_hop"
## The lead-in's mark (LevelLayout.credits).
const LEAD: String = "wall_hop_lead"
## A high-value credit lies where the reference hopper passes within its pickup's reach less this (metres): slack for
## the Player's frame steps (a real hop comes a frame or two after its height says).
const REACH_SLACK: float = 0.1
## The step (seconds) the search for the high-value credits walks the reference hopper's path in.
const SEARCH_STEP: float = 0.01
const POWERUPS_PATH: String = "res://data/tuning/powerups.tres"
const DashWallRules = preload("res://scripts/enemies/dash_wall_rules.gd")
## The enemies whose attacks a wall runner can't dodge, which hold off while a wall-run gap's crossing lies in their
## reach (Drone._wall_run_in_reach, BadDream._wall_run_in_reach, EnforcerTruck._wall_run_in_reach; a host's Bad Dream
## comes at run time, and its chase is the host rules' keep-out), and the hover truck, from whose roof a step onto the
## wall starts high (GDD §9.3): a line keeps off each one's keep-out (LevelGenerator.enemy_keep_out) in any lane.
const WALL_RUN_ATTACKERS: Array[String] = ["drone", "bad_dream", "enforcer_truck", "hover_truck"]


static func tuning() -> WallHopTuning:
	return WallHopTuning.load_default()


## The longest single wall run's slide, as a multiple of a plain one's: claws' (PowerupTuning.claws_wall_time_multiplier).
static func claws_multiplier() -> float:
	var res: Resource = load(POWERUPS_PATH) if ResourceLoader.exists(POWERUPS_PATH) else null
	return maxf((res as PowerupTuning).claws_wall_time_multiplier, 1.0) if res is PowerupTuning else 1.5


## The height on the wall the high-value credits hang at (metres): above where a pickup reaches from the highest a
## fresh wall run carries a runner who never hops (WallHopPath.fresh_top, pickup_reach), by `t`'s gem_clearance.
static func gem_height(mt: MovementTuning, t: WallHopTuning) -> float:
	return WallHopPath.fresh_top(mt) + WallHopPath.pickup_reach(mt) + t.gem_clearance


## A line's shape at run speed `v`, for the reference hopper stepping onto the wall at track distance 0: {path
## (WallHopPath), lead and gems (each an Array of {t, at, height}: seconds after the entry, metres past it, height on
## the wall), from (where its stretch starts, metres, negative), to (where it ends), run (the reference hopper's wall
## run holding the high-value credits)}; {} if none of its fresh runs passes their height within reach for long
## enough (a hop_height too low for its fresh runs to climb there).
## The high-value credits lie together in the first of the reference hopper's fresh wall runs that passes within
## their reach long enough past one wall run's reach from the entry (the standard wall run, MovementTuning
## wall_entry_time + wall_slide_time, as the wall-run gaps measure it) and reach_margin_seconds. A single run with
## claws (PowerupTuning.claws_wall_time_multiplier) slides on further but never rises above a fresh run's height, so it
## passes under them. The stretch ends where a runner who jumps off the wall at the last of them comes down in the
## outer lane (wall_jump_seconds) and landing_seconds after that.
static func shape_for(mt: MovementTuning, v: float, t: WallHopTuning) -> Dictionary:
	var path := WallHopPath.of(0.0, mt, v, t.hop_height)
	var lead: Array[Dictionary] = []
	var first_hop: float = minf(float(path.runs[0]["hop"]), path.run_end(0))
	var i: int = 1
	while mt.wall_entry_time + t.lead_step_seconds * i < first_hop:
		var lt: float = mt.wall_entry_time + t.lead_step_seconds * i
		lead.append({"t": lt, "at": path.distance_at(lt), "height": path.height_at(lt)})
		i += 1
	var height: float = gem_height(mt, t)
	var reach: float = WallHopPath.pickup_reach(mt) - REACH_SLACK
	var earliest: float = path.run_end(0) + t.reach_margin_seconds
	var span: float = t.gem_step_seconds * maxf(t.gems - 1, 0)
	for k: int in path.runs.size():
		var window: Vector2 = _within(path, k, height, reach)
		var first: float = maxf(window.x, earliest)
		if window.y < window.x or first + span > window.y:
			continue
		var gems: Array[Dictionary] = []
		for j: int in t.gems:
			var gt: float = first + j * t.gem_step_seconds
			gems.append({"t": gt, "at": path.distance_at(gt), "height": height})
		var off: float = float(gems[-1]["t"]) + wall_jump_seconds(mt, height) + t.landing_seconds
		return {"path": path, "lead": lead, "gems": gems, "from": -t.run_in_seconds * v, "to": path.distance_at(off),
			"run": k}
	return {}


## The stretch of fresh wall run `k` of `path` (seconds after the entry) where the hopper's height lies within `reach`
## of `height`: from where its entry first brings it there to where its slide takes it out (Vector2(1, 0), empty, if
## it never does), walked in SEARCH_STEP steps.
static func _within(path: WallHopPath, k: int, height: float, reach: float) -> Vector2:
	var run: Dictionary = path.runs[k]
	var from: float = float(run["start"])
	var to: float = minf(float(run["hop"]), path.run_end(k))
	var out := Vector2(1.0, 0.0)
	var tt: float = from
	while tt <= to:
		if absf(path.height_at(tt) - height) <= reach:
			if out.x > out.y:
				out = Vector2(tt, tt)
			out.y = tt
		elif out.x <= out.y:
			break
		tt += SEARCH_STEP
	return out


## Seconds a runner who jumps off a wall from `height` takes to come down onto the floor (Player._leave_wall: up at
## wall_jump_velocity, then down at the descending gravity).
static func wall_jump_seconds(mt: MovementTuning, height: float) -> float:
	var g: float = mt.gravity()
	var up: float = mt.wall_jump_velocity / g
	var top: float = height + mt.wall_jump_velocity * up * 0.5
	return up + sqrt(2.0 * maxf(top, 0.0) / maxf(g * mt.fall_gravity_multiplier, 0.01))


## Places up to gen.config.wall_hop_lines lines (see the header): their records (LevelLayout.wall_hops) and their
## credits (LevelLayout.credits). Nothing, and no random number drawn, with the count at 0.
static func place(gen: LevelGenerator) -> void:
	var count: int = gen.config.wall_hop_lines
	if count <= 0:
		return
	var t: WallHopTuning = tuning()
	var shape: Dictionary = shape_for(gen.tuning, gen.speed, t)
	if shape.is_empty():
		return
	var rng: RandomNumberGenerator = gen.rng_for("wall_hops")
	var layout: LevelLayout = gen.layout
	var lo_limit: float = gen.config.start_clear_distance
	var hi_limit: float = layout.length - gen.config.end_clear_distance
	var gap: float = t.min_gap_seconds * gen.speed
	var busy: Dictionary = {-1: busy_spans(gen, -1), 1: busy_spans(gen, 1)}
	for n: int in count:
		# Every stretch of entries that fits: Vector3(side, first entry, last entry).
		var options: Array[Vector3] = []
		var total: float = 0.0
		for side: int in [-1, 1]:
			for free: Vector2 in LevelGenerator.free_stretches(busy[side], lo_limit, hi_limit):
				var lo: float = free.x - float(shape["from"])
				var hi: float = free.y - float(shape["to"])
				if hi >= lo:
					options.append(Vector3(side, lo, hi))
					total += hi - lo + 1.0
		if options.is_empty():
			return
		var pick: float = rng.randf() * total
		var chosen: Vector3 = options[-1]
		for o: Vector3 in options:
			pick -= o.z - o.y + 1.0
			if pick <= 0.0:
				chosen = o
				break
		var line: Dictionary = _build(gen, t, int(chosen.x), lerpf(chosen.y, chosen.z, rng.randf()), shape)
		for side: int in [-1, 1]:
			(busy[side] as Array).append(Vector2(float(line["start"]) - gap, float(line["end"]) + gap))


## Adds a line on wall `side` whose reference hopper steps onto it at track distance `entry` (`shape`: shape_for at
## the level's speed): its credits and its record, which it returns.
static func _build(gen: LevelGenerator, t: WallHopTuning, side: int, entry: float, shape: Dictionary) -> Dictionary:
	var layout: LevelLayout = gen.layout
	var lane: int = layout.outer_lane(side)
	for c: Dictionary in shape["lead"]:
		layout.credits.append({"at": entry + float(c["at"]), "surface": "wall", "lane": lane, "side": side,
			"height": float(c["height"]), "value": t.lead_value, "risky": true, LEAD: true})
	for c: Dictionary in shape["gems"]:
		layout.credits.append({"at": entry + float(c["at"]), "surface": "wall", "lane": lane, "side": side,
			"height": float(c["height"]), "value": t.gem_value, "risky": true, GEM: true})
	var gems: Array = shape["gems"]
	var line := {"side": side, "entry": entry, "start": entry + float(shape["from"]), "end": entry + float(shape["to"]),
		"gems_from": entry + float(gems[0]["at"]), "gems_to": entry + float(gems[-1]["at"])}
	layout.wall_hops.append(line)
	return line


## The stretches a line on wall `side` keeps off (see the header), as the level stands in the credit pass: what stands
## on that wall (LevelGenerator.wall_lane_keep_outs, the wall fences themselves and other wall credits on it, each
## doodad_wall_clear_seconds either side), what stands on the outer lane's floor beside it, an enemy in that lane, the
## attacks a wall runner can't dodge (WALL_RUN_ATTACKERS), dash walls and what the rules keep in every lane or in that
## lane.
static func busy_spans(gen: LevelGenerator, side: int) -> Array[Vector2]:
	var layout: LevelLayout = gen.layout
	var mt: MovementTuning = gen.tuning
	var lane: int = layout.outer_lane(side)
	var clear: float = gen.config.doodad_wall_clear_seconds * gen.speed
	var half: float = mt.fence_depth * 0.5
	var out: Array[Vector2] = gen.wall_lane_keep_outs(side)
	# Its wall.
	for w: Dictionary in layout.wall_fences:
		if int(w["side"]) == side:
			out.append(Vector2(float(w["at"]) - clear, float(w["at"]) + clear))
	for g: Dictionary in layout.wall_gaps:
		if int(g["side"]) == side:
			out.append(Vector2(float(g["start"]) - clear, float(g["end"]) + clear))
	for c: Dictionary in layout.credits:
		if String(c["surface"]) == "wall" and int(c["side"]) == side and not c.has(GEM) and not c.has(LEAD):
			out.append(Vector2(float(c["at"]) - clear, float(c["at"]) + clear))
	# The outer lane's floor beside it.
	for g: Dictionary in layout.gaps:
		if int(g["lane"]) == lane:
			out.append(Vector2(float(g["start"]), float(g["end"])))
	for f: Dictionary in layout.fences:
		if int(f["lane"]) == lane:
			out.append(Vector2(float(f["at"]) - half, float(f["at"]) + half))
	for p: Dictionary in layout.pads:
		if int(p["lane"]) == lane:
			out.append(Vector2(float(p["at"]), float(p["at"]) + mt.pad_length))
	for p: Dictionary in layout.speed_pads:
		if int(p["lane"]) == lane:
			out.append(Vector2(float(p["at"]), float(p["at"]) + mt.speed_pad_length))
	for r: Dictionary in layout.ramps:
		if int(r["side"]) == side:
			out.append(Vector2(float(r["at"]), float(r["at"]) + mt.ramp_length))
	for d: Dictionary in layout.doodads:
		if int(d["lane"]) == lane:
			var span: Vector2 = LevelLayout.doodad_extent(d)
			out.append(Vector2(span.x - LevelGenerator.DOODAD_WALL_CREDIT_MARGIN, span.y + LevelGenerator.DOODAD_WALL_CREDIT_MARGIN))
	for c: Dictionary in layout.cuts:
		if int(c["lane"]) == lane:
			out.append(FloorCutPlan.lane_window(c))
	for f: Dictionary in layout.ceiling_fences:
		if int(f["lane"]) == lane:
			out.append(Vector2(float(f["at"]) - half, float(f["at"]) + half))
	# What stands or attacks there meanwhile: an enemy in the outer lane, a hover truck anywhere (from its roof a step
	# onto the wall starts high, GDD §9.3), an attack a wall runner can't dodge (WALL_RUN_ATTACKERS), and what the
	# rules keep in every lane or in the outer lane (a Bad Dream's chase, a dash wall's footprint, a Gilded Sentinel's
	# strike, an Enforcer Truck's showing window, a stash's floor, a wall-run gap's clear stretch, a hover truck's lane).
	var hooks: Dictionary = {}
	for e: Dictionary in layout.enemies:
		var type: String = String(e.get("type", ""))
		if int(e.get("lane", -1)) == lane or WALL_RUN_ATTACKERS.has(type):
			var k: Vector2 = gen.enemy_keep_out(e, hooks)
			if k.y >= k.x:
				out.append(k)
	for w: Dictionary in layout.dash_walls:
		out.append(DashWallRules.footprint(gen, w))
	for k: Dictionary in gen.rules_doodad_keep_outs():
		if not k.has("lane") or int(k["lane"]) == lane:
			out.append(Vector2(float(k["from"]), float(k["to"])))
	return out


## Why line `line` (LevelLayout.wall_hops) doesn't keep its rules in `gen`'s finished level, or "": its credits where
## its shape at the level's speed puts them (every one there, the high-value ones marked), its stretch inside the
## level's clear ends, its wall whole over it, and nothing of busy_spans in it.
static func problem(gen: LevelGenerator, line: Dictionary) -> String:
	var layout: LevelLayout = gen.layout
	var t: WallHopTuning = tuning()
	var side: int = int(line["side"])
	if absi(side) != 1:
		return "its side is a wall's"
	var shape: Dictionary = shape_for(gen.tuning, gen.speed, t)
	if shape.is_empty():
		return "no shape at the level's speed"
	var entry: float = float(line["entry"])
	if absf(float(line["start"]) - entry - float(shape["from"])) > 0.01 or absf(float(line["end"]) - entry - float(shape["to"])) > 0.01:
		return "its stretch isn't its shape's"
	if float(line["start"]) < gen.config.start_clear_distance - 0.01 \
			or float(line["end"]) > layout.length - gen.config.end_clear_distance + 0.01:
		return "it reaches into the level's clear ends"
	if layout.wall_gap_between(float(line["start"]), float(line["end"]), side):
		return "a side wall gap on its wall"
	for kind: String in [LEAD, GEM]:
		var want: Array = shape["lead" if kind == LEAD else "gems"]
		for c: Dictionary in want:
			var at: float = entry + float(c["at"])
			var found: bool = false
			for k: Dictionary in layout.credits:
				if k.has(kind) and String(k["surface"]) == "wall" and int(k["side"]) == side and absf(float(k["at"]) - at) < 0.01 \
						and absf(float(k["height"]) - float(c["height"])) < 0.01:
					found = true
					break
			if not found:
				return "its %s credit at %.1f m is missing" % ["lead-in" if kind == LEAD else "high-value", at]
	for b: Vector2 in busy_spans(gen, side):
		if b.x <= float(line["end"]) and b.y >= float(line["start"]):
			return "something on its wall, its outer lane or in every lane at %.1f-%.1f m" % [b.x, b.y]
	return ""
