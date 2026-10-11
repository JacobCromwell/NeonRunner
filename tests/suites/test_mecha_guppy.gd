extends TestSuite
## Mecha Guppy and Captain Cogs, the Beach's boss (GDD §10; task E5e-b1: the climb, its look and the fight's frame),
## at 3, 5 and 6 lanes, at the reference 18 m/s and the Beach's 23.8 m/s:
## - its data: the slot (beach_boss) names its scene (task E5e-c: the campaign plays it after Sunset Strip), the owner's
##   title, three phases (4 hits, 6 hits, phase 3 the minute on the top), weapons doing nothing, the standard armor rule,
##   the Beach's look without walls, the campaign under Sunset Strip's sky at the Beach's speed, its rewards in line with
##   its neighbours', its hints (the climb, the bombs, the hits, phase 3's rounds and waves);
## - the climb's plan (MechaGuppyClimb), over many steps: the lanes that lead up (one on 3 lanes; one, two or three
##   on 5 and 6, the count changing every step, one or two on a roof that reaches back; neighbours; never every lane;
##   never the same block twice running), the two cues alternating and each shaped as the owner put it, the
##   reading margin for a rider in any lane (at least
##   read_seconds beyond every switch, from the latest anyone settles on the hut), the hut full width until then,
##   a wrong drop dead before the higher roof's front even dashing, a pad strip no jump clears, huts that never
##   overlap, phase 2's climb 15-25% faster (its roofs higher, its steps as long) with every margin kept, no escalation,
##   and a retry planning the same; the bait's notch on every roof from MechaGuppyClimb.FIRST_NOTCH on (task E5e-b3: an
##   outer lane eaten from notch_back before the next hut to the roof's end, a reaction, a switch and dodge_margin past
##   where the roof's run begins, on a side that has nothing to do with the lanes that lead up); every tunable at both
##   ends of its range keeping those promises;
## - the towers drawn down to the water, but no deeper than TOWER_DEPTH under their decks: a long climb's meshes stop
##   growing;
## - the built climb against the plan, on real physics: roof tops, each hut lane's end, the pads in every lane, the
##   roofs' solid fronts and blocked sides, the notch (no floor in its lane past its start, the other lanes' floor
##   on), and the lanes that lead up read off the hut and the roofs themselves (MechaGuppyBot.read_up_lanes) the same as
##   planned;
## - the roofs' faces: a lane switch into a roof's side from below its top bumps; stepping off a roof's lanes that
##   reach back into the gap is a fall, into the front of the lanes beyond it a crash (what looks like a hit is a
##   hit), and the grapple saves either before it gets there;
## - hits (register_hit, which Captain Cogs' bombs call: test_mecha_guppy_bombs): none in an intro, 4 end phase 1, 6
##   phase 2; weapons do nothing;
##   phase 3's minute ends top_seconds after the runner reaches the top (the leap: the fight won); the waterfall in phases
##   1 and 2 only; the floor base follows the climb and the climbing view is on;
## - the armor rule's pickups on the roof the runner will run along, at its height, not under a hut.

const BOSS_PATH: String = "res://data/bosses/beach_boss.tres"
const SKY_PATH: String = "res://data/skies/beach_sunset.tres"
const LANES: Array[int] = [3, 5, 6]
const SPEEDS: Array[float] = [18.0, 23.8]
## Steps planned for the plan's checks.
const PLAN_STEPS: int = 60

var sim: RunSim
var def: BossDef


func run() -> void:
	sim = RunSim.new(tree, tuning)
	var slot := load(BOSS_PATH) as BossDef
	def = slot if slot != null and slot.is_built() else null
	if def == null:
		check(false, "Mecha Guppy and Captain Cogs' fight loads as the Beach's boss slot's scene")
		return
	_test_data(slot)
	_test_plan()
	_test_tunables()
	await _test_tower_depth()
	await _test_geometry()
	await _test_roof_faces()
	await _test_hits_and_phases()
	await _test_pickups()


# --- Helpers -------------------------------------------------------------------------------

## A run's movement at `speed` m/s (the base tuning at 18).
func _movement(speed: float) -> MovementTuning:
	if is_equal_approx(speed, tuning.run_speed):
		return tuning
	var t: MovementTuning = tuning.duplicate() as MovementTuning
	t.run_speed = speed
	return t


## The fight at `lanes` and `speed` m/s (with `p_def`, the slot's by default): [world, boss]. These checks are of
## the climb and the fight's frame on their own: Captain Cogs' bombs and Mecha Guppy's bites are off (MechaGuppy.
## attacks_enabled; test_mecha_guppy_bombs and _bites check them).
func _fight(lanes: int, speed: float, resume: Dictionary = {}, p_def: BossDef = null) -> Array:
	var d: BossDef = p_def if p_def != null else def
	var t: MovementTuning = _movement(speed)
	var boss := BossEncounter.create(d) as MechaGuppy
	var ctx := RunContext.new()
	ctx.mode = RunContext.Mode.QUICK
	ctx.boss = d
	ctx.config = BossArena.base_config(d)
	ctx.config.lane_count = lanes
	ctx.tuning = t
	ctx.boss_resume = resume
	var arena: BossArena = boss.plan_arena(ctx)
	var world: RunWorld = sim.build_world(arena.layout, null, t, ctx.config)
	boss.setup(world, ctx, arena)
	boss.attacks_enabled = false
	return [world, boss]


## The slot with a tuning of its own (changed by `edit`, called with the copy).
func _def_with(edit: Callable) -> BossDef:
	var out: BossDef = def.duplicate() as BossDef
	var t: MechaGuppyTuning = (def.tuning as MechaGuppyTuning).duplicate() as MechaGuppyTuning
	edit.call(t)
	out.tuning = t
	return out


func _plan(lanes: int, speed: float, phase: int = 0, seed: int = 7) -> MechaGuppyClimb:
	var dash: float = MechaGuppyClimb.dash_reach_of(load("res://data/tuning/powerups.tres") as PowerupTuning)
	var c: MechaGuppyClimb = MechaGuppyClimb.make(_movement(speed), def.tuning as MechaGuppyTuning, lanes, dash, seed)
	for i: int in PLAN_STEPS:
		c.plan_next(phase)
	return c


func _events(boss: BossEncounter, event: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in boss.events:
		if e["event"] == event:
			out.append(e)
	return out


## Steps the world (started if it wasn't) until `done` holds, the runner dies or `seconds` pass, calling `each`
## before every frame.
func _run(world: RunWorld, seconds: float, done: Callable, each: Callable = Callable()) -> void:
	if not world.player.running:
		await tree.physics_frame
		world.player.running = true
	for i: int in int(seconds * Engine.physics_ticks_per_second):
		if each.is_valid():
			each.call()
		if done.call() or not world.player.alive:
			return
		await tree.physics_frame


# --- Data ------------------------------------------------------------------------------------

func _test_data(slot: BossDef) -> void:
	check(slot.id == &"beach_boss" and slot.display_name == "Mecha Guppy and Captain Cogs",
		"the Beach's slot keeps its id (save keys) and takes the owner's title (%s)" % slot.display_name)
	check(slot.is_built() and slot.scene == "res://scenes/bosses/mecha_guppy.tscn" and slot.preview_scene == ""
		and slot.preview() == null, "the campaign plays the fight in the Beach's boss slot (its scene, task E5e-c)")
	var list: Array[BossPhase] = def.phase_list()
	check(list.size() == 3 and list[0].hits == 4 and list[1].hits == 6 and list[2].hits == 1
		and list[2].display_name == "Level with Captain Cogs",
		"GDD §10: three phases; 4 hits end phase 1, 6 phase 2; phase 3, level with Captain Cogs, ends with its minute")
	var corporate := load("res://data/bosses/corporate_boss.tres") as BossDef
	var dead_zone := load("res://data/bosses/dead_zone_boss.tres") as BossDef
	check(def.payout_credits == corporate.payout_credits and def.payout_credits == dead_zone.payout_credits
		and def.defeat_score == corporate.defeat_score and def.defeat_score == dead_zone.defeat_score,
		"its rewards are in line with its neighbours' (Hostile Takeover's and the Sleep Taker's: %d credits, %d points; DESIGN-TBD)"
		% [def.payout_credits, def.defeat_score])
	check(def.three_star_seconds < def.two_star_seconds and def.time_bonus_seconds > def.two_star_seconds,
		"par times for two and three stars, and a time bonus running out past two stars (%.0f, %.0f, %.0f s)"
		% [def.three_star_seconds, def.two_star_seconds, def.time_bonus_seconds])
	check(def.weapon_share_cap == 0.0 and not def.weapons_can_end_phase,
		"GDD §10: weapons do nothing (no chip damage); each phase's hits are counted")
	check(def.armor_rule and def.armor_delay_min == 15.0 and def.armor_delay_max == 17.0 and def.armor_pickups_per_phase == 1
		and def.armor_when_unprotected, "the standard armor rule (15-17 s, once a phase, a phase begun unprotected counting as a break)")
	check(def.arena != null and def.arena.skin is MechaGuppySkin and def.arena.skin is BeachSkin and def.arena.sky == null
		and def.arena.features.is_empty() and def.tuning is MechaGuppyTuning,
		"its arena: the Beach's look (MechaGuppySkin), nothing of the generator's, the sky left to the campaign")
	var campaign := load("res://data/campaign/campaign.tres") as Campaign
	var config: LevelConfig = campaign.configure_boss(campaign.step("beach/boss"), 5)
	check(config.sky == load(SKY_PATH) and is_equal_approx(config.run_speed, 23.8),
		"in the campaign it fights under Sunset Strip's setting sun, at the Beach's 23.8 m/s (GDD §5, §10)")
	var hints: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/hints/hints.json"))
	var triggers: Array = []
	for h: Dictionary in (hints as Dictionary).get("hints", []):
		triggers.append(h.get("trigger", ""))
	check(triggers.has("enemy:beach_boss") and triggers.has("boss:beach_boss/climb") and triggers.has("boss:beach_boss/bombs")
		and triggers.has("boss:beach_boss/hits") and triggers.has("boss:beach_boss/rounds") and triggers.has("boss:beach_boss/waves"),
		"its hints: the fight, how to read the lanes that lead up, Captain Cogs' bombs and how they hurt Mecha Guppy, phase 3's rounds and waves")
	var t := def.tuning as MechaGuppyTuning
	check(maxf(t.rise, t.phase2_rise) <= RunCamera.FLOOR_REACH - 1.0,
		"each step's rise (%.1f m, %.1f m in phase 2) stays well within the climbing camera's roof reach (%.1f m)"
		% [t.rise, t.phase2_rise, RunCamera.FLOOR_REACH])


# --- The plan ------------------------------------------------------------------------------------

func _test_plan() -> void:
	var t := def.tuning as MechaGuppyTuning
	var powerups := load("res://data/tuning/powerups.tres") as PowerupTuning
	var dash: float = MechaGuppyClimb.dash_reach_of(powerups)
	for speed: float in SPEEDS:
		var mt: MovementTuning = _movement(speed)
		for lanes: int in LANES:
			var tag: String = "(%d lanes, %.1f m/s)" % [lanes, speed]
			var c: MechaGuppyClimb = _plan(lanes, speed)
			var counts: Array[int] = []
			var cues_alternate: bool = true
			var shapes: bool = true
			var neighbours: bool = true
			var repeats: int = 0
			var worst_margin: float = INF
			var full_width: bool = true
			var wrong_clear: bool = true
			var strip_ok: bool = true
			var huts_apart: bool = true
			var pads_on_roof: bool = true
			var rise_ok: bool = true
			var clearance: float = INF
			for s: MechaGuppyClimb.Step in c.steps:
				counts.append(s.up_count())
				neighbours = neighbours and s.up.x >= 0 and s.up.y < lanes and s.up.x <= s.up.y and s.up_count() < lanes
				if s.index > 0:
					var before: MechaGuppyClimb.Step = c.steps[s.index - 1]
					if before.up == s.up:
						repeats += 1
					cues_alternate = cues_alternate and s.cue != before.cue
					huts_apart = huts_apart and s.hut_start >= before.hut_end() + MechaGuppyClimb.HUT_GAP - 0.001
				var roof: MechaGuppyClimb.Roof = c.roofs[s.index + 1]
				var from: MechaGuppyClimb.Roof = c.roofs[s.index]
				rise_ok = rise_ok and is_equal_approx(roof.top - from.top, t.rise_at(s.phase))
				clearance = minf(clearance, s.hut_y - s.top_y)
				# The cue: the hut's lanes that lead up run further (RUN_ON), or the roof's reach further back.
				for lane: int in lanes:
					var up: bool = s.leads_up(lane)
					if s.cue == MechaGuppyClimb.Cue.RUN_ON:
						shapes = shapes and is_equal_approx(roof.start_in(lane), roof.start_in(0)) \
							and ((s.ends[lane] > roof.start_in(lane) + 0.5) == up) and (up or is_equal_approx(s.ends[lane], s.deadline))
					else:
						shapes = shapes and is_equal_approx(s.ends[lane], s.deadline) \
							and ((roof.start_in(lane) < s.deadline - 0.5) == up)
					worst_margin = minf(worst_margin, c.margin(s, lane))
					# A wrong drop is dead before the higher roof's front in its lane, even dashing.
					if not up:
						wrong_clear = wrong_clear and roof.start_in(lane) >= s.deadline + c.wrong_reach(s) - 0.001
				# The hut is full width until the deadline: no rider is held in a lane that doesn't lead up while
				# there's time (the narrow-ceiling rule).
				for lane: int in lanes:
					full_width = full_width and s.ends[lane] >= s.deadline - 0.001
				strip_ok = strip_ok and s.pad_end - s.pad >= c.jump_seconds() * c.speed + dash + t.strip_margin - 0.001 \
					and from.end > s.pad_end
				pads_on_roof = pads_on_roof and s.pad >= from.full_from() + MechaGuppyClimb.PAD_CLEAR - 0.001
			if lanes == 3:
				check(counts.count(1) == counts.size(), "GDD §10: one lane leads up on 3 lanes, every step %s" % tag)
			else:
				var cycle: bool = true
				var changes: bool = true
				for i: int in counts.size():
					cycle = cycle and counts[i] == [1, 2, 3, 1, 3, 2][i % 6]
					changes = changes and (i == 0 or counts[i] != counts[i - 1])
				check(cycle and changes, "GDD §10: one, two or three lanes lead up, alternating, on %d lanes (%s...) %s"
					% [lanes, counts.slice(0, 6), tag])
			var reach_most: int = 0
			var thrice: int = 0
			var clamp_ok: bool = true
			for s: MechaGuppyClimb.Step in c.steps:
				if s.cue == MechaGuppyClimb.Cue.REACH_BACK:
					reach_most = maxi(reach_most, s.up_count())
					var r: MechaGuppyClimb.Roof = c.roofs[s.index + 1]
					clamp_ok = clamp_ok and r.start_in(s.up.x) >= s.settle + MechaGuppyClimb.TONGUE_CLEAR - 0.001
				if s.index >= 4 and s.up == c.steps[s.index - 2].up and s.up == c.steps[s.index - 4].up:
					thrice += 1
			check(reach_most >= 1 and reach_most <= 2,
				"GDD §10: one or two of the roof's lanes reach further back (at most %d on a step) %s" % [reach_most, tag])
			check(thrice == 0, "the same lanes never lead up on three steps of a cue running (%d times) %s" % [thrice, tag])
			check(clamp_ok, "a roof's lanes that reach back start past the latest settle on the hut (no flip meets their front) %s" % tag)
			check(neighbours, "the lanes that lead up are neighbours on the track, never every lane %s" % tag)
			check(repeats == 0, "never the same lanes twice running (%d repeats in %d steps) %s" % [repeats, c.steps.size(), tag])
			check(cues_alternate, "the two cues alternate step by step %s" % tag)
			check(shapes, "each cue as the owner put it: the hut's lanes that lead up run further, or the roof's reach back %s" % tag)
			check(worst_margin >= t.read_seconds - 0.001,
				"a rider in any lane, settling as late as anyone can, has %.2f s beyond every switch to a lane that leads up (at least %.2f) %s"
				% [worst_margin, t.read_seconds, tag])
			check(full_width, "every hut is full width until its deadline: the narrow-ceiling rule never traps a rider %s" % tag)
			check(wrong_clear, "a wrong drop dies (or the grapple saves it) before the higher roof's front, even dashing %s" % tag)
			check(strip_ok, "each pad strip is longer than any jump with the dash, on a roof eaten only past it %s" % tag)
			check(pads_on_roof, "each roof's pads come where it's full width %s" % tag)
			check(huts_apart and rise_ok and clearance >= t.hut_clearance - 0.001,
				"huts never overlap, each roof is %.1f m higher, a hut keeps %.1f m over the roof under its end %s" % [t.rise, clearance, tag])
			# The bait's notch on every roof from FIRST_NOTCH on (none on the street nor on roof 1, whose run brings the
			# first volley; the top has no next hut).
			var notched: int = 0
			var why_not: String = ""
			for s: MechaGuppyClimb.Step in c.steps:
				if s.index == 0 or s.top:
					continue
				var why: String = _notch_problem(c, t, s)
				if why == "":
					notched += 1 if c.roofs[s.index].notched() else 0
				elif why_not == "":
					why_not = why
			check(why_not == "" and notched >= c.steps.size() - 1 - MechaGuppyClimb.FIRST_NOTCH and not c.roofs[1].notched(),
				"every roof from roof %d on has its notch: an outer lane eaten from %.1f m before the next hut to the roof's end, past where its run begins (%d roofs; roof 1 has none) %s%s"
				% [MechaGuppyClimb.FIRST_NOTCH, t.notch_back, notched, tag, "" if why_not == "" else ": " + why_not])
			# No escalation (GDD §10): steps of the same cue and count, early and late, are the same length.
			var same: bool = true
			for i: int in range(7, c.steps.size() - 1):
				var a: MechaGuppyClimb.Step = c.steps[i]
				var b: MechaGuppyClimb.Step = c.steps[1 + (i - 1) % 6]
				same = same and absf((a.deadline - a.pad) - (b.deadline - b.pad)) < 0.01 \
					and absf((a.deadline - a.settle) - (b.deadline - b.settle)) < 0.01 \
					and absf((a.land - a.deadline) - (b.land - b.deadline)) < 0.01 \
					and absf((c.steps[i + 1].pad - a.pad) - (c.steps[2 + (i - 1) % 6].pad - b.pad)) < 0.01
			check(same, "no escalation: a late step is as long, with the same margins, as an early one like it %s" % tag)
			# A retry plans the same.
			var again: MechaGuppyClimb = _plan(lanes, speed)
			var match_all: bool = true
			for i: int in c.steps.size():
				match_all = match_all and again.steps[i].up == c.steps[i].up and is_equal_approx(again.steps[i].pad, c.steps[i].pad)
			check(match_all, "a retry plans the same climb %s" % tag)
			# Phase 2's climb: 15-25% faster (proposed: about 20%), the margins kept.
			var r1: float = MechaGuppyClimb.climb_rate(mt, t, lanes, dash, 0)
			var r2: float = MechaGuppyClimb.climb_rate(mt, t, lanes, dash, 1)
			var faster: float = r2 / r1 - 1.0
			var c2: MechaGuppyClimb = _plan(lanes, speed, 1)
			var margin2: float = INF
			for s: MechaGuppyClimb.Step in c2.steps:
				for lane: int in lanes:
					margin2 = minf(margin2, c2.margin(s, lane))
			var period: float = (c2.steps[8].pad - c2.steps[2].pad) - (c.steps[8].pad - c.steps[2].pad)
			check(faster >= 0.15 and faster <= 0.25 and margin2 >= t.read_seconds - 0.001 and absf(period) < 0.01,
				"GDD §10: phase 2 climbs %.0f%% faster (%.2f against %.2f m/s), each roof %.1f m higher, its steps as long, every margin kept (%.2f s) %s"
				% [faster * 100.0, r2, r1, t.phase2_rise, margin2, tag])
			# The notch's side has nothing to do with the lanes that lead up: other lanes lead up (other up_counts), the
			# same sides.
			var other: MechaGuppyTuning = t.duplicate() as MechaGuppyTuning
			other.up_counts = PackedInt32Array([1])
			var c3: MechaGuppyClimb = MechaGuppyClimb.make(mt, other, lanes, dash, 7)
			var sides_same: bool = true
			var sides: Array[int] = [0, 0]
			for i: int in PLAN_STEPS:
				c3.plan_next(0)
			for i: int in range(1, mini(c.roofs.size(), c3.roofs.size()) - 1):
				if c.roofs[i].notched() and c3.roofs[i].notched():
					sides_same = sides_same and c.roofs[i].notch_side() == c3.roofs[i].notch_side()
					sides[0 if c.roofs[i].notch_side() < 0 else 1] += 1
			check(sides_same and sides[0] > 0 and sides[1] > 0,
				"the notch's side has nothing to do with the lanes that lead up (the same sides with other lanes leading up; %d left, %d right) %s"
				% [sides[0], sides[1], tag])


# --- Every tunable across its range ------------------------------------------------------------------

## The plan's promises hold for every tunable at both ends of its F6 range (`@export_range`), one at a time, and for a
## few extreme roof runs and lane counts: at 3, 5 and 6 lanes and both speeds, in phases 1 and 2, over many steps.
## (task E5e-b1's review: reach_back at 20 m once put a roof's solid front in a late flip's path.)
func _test_tunables() -> void:
	var base := def.tuning as MechaGuppyTuning
	var variants: Array[Dictionary] = []
	for prop: Dictionary in base.get_property_list():
		if int(prop["hint"]) != PROPERTY_HINT_RANGE or not (int(prop["usage"]) & PROPERTY_USAGE_EDITOR):
			continue
		var parts: PackedStringArray = String(prop["hint_string"]).split(",")
		if parts.size() < 2:
			continue
		for v: float in [float(parts[0]), float(parts[1])]:
			variants.append({"name": String(prop["name"]), "value": v})
	for counts: PackedInt32Array in [PackedInt32Array([1]), PackedInt32Array([3, 3])]:
		variants.append({"name": "up_counts", "value": counts})
	var powerups := load("res://data/tuning/powerups.tres") as PowerupTuning
	var dash: float = MechaGuppyClimb.dash_reach_of(powerups)
	var bad: Array[String] = []
	for variant: Dictionary in variants:
		var t: MechaGuppyTuning = base.duplicate() as MechaGuppyTuning
		t.set(variant["name"], variant["value"])
		for speed: float in SPEEDS:
			var mt: MovementTuning = _movement(speed)
			for lanes: int in LANES:
				for phase: int in 2:
					var c: MechaGuppyClimb = MechaGuppyClimb.make(mt, t, lanes, dash, 11)
					for i: int in 24:
						c.plan_next(phase)
					var why: String = _plan_problem(c, t, dash)
					if why != "":
						bad.append("%s=%s (%d lanes, %.1f m/s, phase %d): %s" % [variant["name"], variant["value"], lanes, speed, phase + 1, why])
	check(bad.is_empty(), "every tunable at both ends of its range keeps the plan's promises (%d variants)%s"
		% [variants.size(), "" if bad.is_empty() else ": " + "; ".join(bad.slice(0, 4))])


## The first broken promise of plan `c` (tuning `t`, the dash's reach `dash`), or "".
func _plan_problem(c: MechaGuppyClimb, t: MechaGuppyTuning, dash: float) -> String:
	var lanes: int = c.lanes
	for s: MechaGuppyClimb.Step in c.steps:
		if s.index + 1 >= c.steps.size():
			break
		var from: MechaGuppyClimb.Roof = c.roofs[s.index]
		var roof: MechaGuppyClimb.Roof = c.roofs[s.index + 1]
		for value: float in [s.pad, s.pad_end, s.hut_start, s.settle, s.deadline, s.land, s.hut_y, s.top_y]:
			if not is_finite(value):
				return "step %d: a number isn't finite" % s.index
		if s.up.x < 0 or s.up.y >= lanes or s.up.x > s.up.y or s.up_count() >= lanes:
			return "step %d: lanes that lead up %s" % [s.index, s.up]
		if s.hut_y - s.top_y < t.hut_clearance - 0.001 or not is_equal_approx(s.top_y - s.floor_y, t.rise_at(s.phase)):
			return "step %d: heights" % s.index
		if s.index > 0 and c.roofs[s.index].notched():
			var notch_why: String = _notch_problem(c, t, s)
			if notch_why != "":
				return notch_why
		if s.pad_end - s.pad < c.jump_seconds() * c.speed + dash + t.strip_margin - 0.001 or from.end <= s.pad_end:
			return "step %d: the pad strip" % s.index
		if s.pad < from.full_from() + MechaGuppyClimb.PAD_CLEAR - 0.001:
			return "step %d: pads before the roof's full width" % s.index
		if s.index > 0 and s.hut_start < c.steps[s.index - 1].hut_end() + MechaGuppyClimb.HUT_GAP - 0.001:
			return "step %d: huts overlap" % s.index
		for lane: int in lanes:
			if c.margin(s, lane) < t.read_seconds - 0.001:
				return "step %d: the reading margin in lane %d" % [s.index, lane]
			if s.ends[lane] < s.deadline - 0.001:
				return "step %d: the hut narrows before its deadline" % s.index
			if s.leads_up(lane):
				if not roof.covers(lane, s.land):
					return "step %d: a drop in lane %d misses the higher roof" % [s.index, lane]
				if roof.start_in(lane) < s.settle + MechaGuppyClimb.TONGUE_CLEAR - 0.001 \
						or roof.start_in(lane) < from.end + MechaGuppyClimb.MIN_BITE - 0.001:
					return "step %d: the higher roof's front in a flip's path (lane %d)" % [s.index, lane]
			elif roof.start_in(lane) < s.deadline + c.wrong_reach(s) - 0.001:
				return "step %d: a wrong drop reaches the front (lane %d)" % [s.index, lane]
		if s.cue == MechaGuppyClimb.Cue.RUN_ON:
			if s.ends[s.up.x] <= roof.start_in(s.up.x) + 0.5:
				return "step %d: the hut's lanes that lead up don't run on" % s.index
		elif roof.start_in(s.up.x) >= s.deadline - 0.5:
			return "step %d: the roof's lanes that lead up don't reach back" % s.index
	return ""


## Why step `s`'s roof (roof s.index) breaks the notch's promises, or "": from FIRST_NOTCH on it has a notch (on a roof
## long enough for one), on an outer lane, from notch_back before the step's hut to the roof's end (its pads gone there),
## past where the roof's run begins (notch_after(): a reaction, a switch and dodge_margin past the landing, the riders'
## first switch and the full width), short of its pads; before FIRST_NOTCH, none.
func _notch_problem(c: MechaGuppyClimb, t: MechaGuppyTuning, s: MechaGuppyClimb.Step) -> String:
	var roof: MechaGuppyClimb.Roof = c.roofs[s.index]
	if roof.index < MechaGuppyClimb.FIRST_NOTCH:
		return "" if not roof.notched() else "roof %d has a notch before roof %d" % [roof.index, MechaGuppyClimb.FIRST_NOTCH]
	var into: MechaGuppyClimb.Step = c.steps[s.index - 1]
	var begins: float = maxf(maxf(into.free_at, into.land), roof.full_from())
	var at: float = s.hut_start - t.notch_back
	if not roof.notched():
		return "" if at < begins + c.notch_after() else "roof %d has no notch" % roof.index
	if roof.notch_lane != 0 and roof.notch_lane != c.lanes - 1:
		return "roof %d's notch isn't an outer lane" % roof.index
	if not is_equal_approx(roof.notch_from, at) or roof.notch_from < begins + c.notch_after() - 0.001 \
			or roof.notch_from >= s.pad:
		return "roof %d's notch starts at %.1f m (its run begins %.1f m, its pads %.1f m)" % [roof.index, roof.notch_from, begins, s.pad]
	if roof.covers(roof.notch_lane, roof.notch_from + 0.1) or not roof.covers(roof.notch_lane, roof.notch_from - 0.1):
		return "roof %d's notch's lane isn't eaten from its start" % roof.index
	for lane: int in c.lanes:
		if lane != roof.notch_lane and not roof.covers(lane, roof.end - 0.1):
			return "roof %d's lane %d is eaten before its end" % [roof.index, lane]
	return ""


# --- The towers' depth ----------------------------------------------------------------------------

## A tower stands down to the water, drawn no deeper than MechaGuppyLooks.TOWER_DEPTH under its deck (the haze hides
## anything deeper): a roof piece's mesh grows with the drop below it only that far, so the builder's meshes stop
## growing however long the climb goes on (GDD §10: no time limit).
func _test_tower_depth() -> void:
	var pair: Array = _fight(6, 23.8)
	var world: RunWorld = pair[0]
	var boss: MechaGuppy = pair[1]
	var looks: MechaGuppyLooks = boss.stairs.looks
	var water: float = -(world.skin as BeachSkin).pool_depth
	var cap: float = MechaGuppyLooks.TOWER_DEPTH
	check(is_equal_approx(looks.bottom(30.0), water) and is_equal_approx(looks.bottom(cap + 100.0), 100.0),
		"a tower reaches the water (%.2f m) under a deck 30 m up, and stops TOWER_DEPTH under a higher one (%.1f m under one %.0f m up)"
		% [looks.bottom(30.0), looks.bottom(cap + 100.0), cap + 100.0])
	var tops: Array[float] = [60.0, cap + 100.0, cap * 2.0 + 300.0]
	var counts: Array[int] = []
	for top: float in tops:
		var r := MechaGuppyClimb.Roof.new()
		r.index = 7
		r.top = top
		r.starts.resize(world.geo.lane_count)
		r.starts.fill(900.0)
		var piece: Node3D = looks.roof_segment(r, 1000.0, 1024.0, true)
		counts.append(_vertices(piece))
		piece.free()
	check(counts[0] > 0 and counts[0] < counts[1] and counts[1] == counts[2],
		"a roof piece's mesh grows with the drop below it only down to TOWER_DEPTH (%s vertices %s m up)" % [counts, tops])
	await sim.free_world(world)


## The vertices of every mesh under `node`.
func _vertices(node: Node) -> int:
	var n: int = 0
	var instance := node as MeshInstance3D
	if instance != null and instance.mesh != null:
		for i: int in instance.mesh.get_surface_count():
			n += instance.mesh.surface_get_array_len(i)
	for child: Node in node.get_children():
		n += _vertices(child)
	return n


# --- The built climb ----------------------------------------------------------------------------

## The climb as built, on real physics, against its plan: for the first steps, the roof tops under each lane, where
## each lane of the hut ends, a pad in every lane, the solid fronts and blocked sides; and a rider on each hut reads
## the lanes that lead up off the hut and the roofs as planned.
func _test_geometry() -> void:
	for lanes: int in LANES:
		var tag: String = "(%d lanes)" % lanes
		var pair: Array = _fight(lanes, 23.8)
		var world: RunWorld = pair[0]
		var boss: MechaGuppy = pair[1]
		var c: MechaGuppyClimb = boss.climb
		var p: Player = world.player
		check(world.camera_climbs and p.shadow_on_floor, "the climbing view is on for the fight %s" % tag)
		check(BossArena.base_config(def).features.is_empty() and world.layout.wall_gaps.size() >= 2
			and not p.wall_supported(-1, 50.0) and not p.wall_supported(1, 50.0),
			"no side walls anywhere in the climb (a wall entry from a high roof can't snap to the street's heights) %s" % tag)
		var beach := world.skin as BeachSkin
		check(beach != null and is_equal_approx(boss.stairs.sight, beach.fog_end) and beach.fog_max >= 1.0,
			"the climb is built past the arena's fog's end, where the fog hides everything (%.0f m) %s" % [boss.stairs.sight, tag])
		var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
		var ray := PhysicsRayQueryParameters3D.new()
		var tops_ok: bool = true
		var ends_ok: bool = true
		var pads_ok: bool = true
		var reads_ok: bool = true
		var fronts_ok: bool = true
		var notch_ok: bool = true
		var notches: int = 0
		var checked: int = 0
		for i: int in 3:
			# The runner on step i's roof short of its pads (moving on, step by step): everything of the step is built.
			if c.steps.size() <= i:
				p.distance = c.steps[i - 1].pad
				boss.stairs.update(p.distance)
			var s: MechaGuppyClimb.Step = c.steps[i]
			p.distance = s.pad - 25.0
			p.surface = Player.Surface.FLOOR
			p.floor_y = s.floor_y
			p.h = s.floor_y
			p.vh = 0.0
			p.grounded = true
			boss.stairs.update(p.distance)
			await tree.physics_frame
			checked += 1
			var roof: MechaGuppyClimb.Roof = c.roofs[s.index + 1]
			for lane: int in lanes:
				var x: float = world.geo.lane_x(lane)
				# The higher roof's top just past its front in this lane, and nothing just before it.
				ray.collision_mask = TrackBuilder.LAYER_FLOOR
				var front: float = roof.start_in(lane)
				ray.from = Vector3(x, roof.top + 2.0, -(front + 1.0))
				ray.to = Vector3(x, roof.top - 2.0, -(front + 1.0))
				var hit: Dictionary = space.intersect_ray(ray)
				tops_ok = tops_ok and not hit.is_empty() and absf((hit["position"] as Vector3).y - roof.top) < 0.01
				ray.from = Vector3(x, roof.top + 2.0, -(front - 1.0))
				ray.to = Vector3(x, s.floor_y - 6.0, -(front - 1.0))
				tops_ok = tops_ok and space.intersect_ray(ray).is_empty()
				# The hut over this lane until its own end, and not past it.
				ray.collision_mask = TrackBuilder.LAYER_HULL
				for at: float in [s.ends[lane] - 0.5, s.ends[lane] + 0.5]:
					ray.from = Vector3(x, s.hut_y - 0.6, -at)
					ray.to = Vector3(x, s.hut_y + 0.3, -at)
					ends_ok = ends_ok and (space.intersect_ray(ray).is_empty() == (at > s.ends[lane]))
				# A pad under the hut in this lane, along the whole strip (none in the bait's notch's lane).
				var padded: bool = c.roofs[s.index].covers(lane, s.pad)
				var q := PhysicsShapeQueryParameters3D.new()
				var box := BoxShape3D.new()
				box.size = Vector3(0.3, 0.3, 0.3)
				q.shape = box
				q.collide_with_areas = true
				q.collide_with_bodies = false
				q.collision_mask = TrackBuilder.LAYER_TRIGGER
				for at: float in [s.pad + 0.3, (s.pad + s.pad_end) * 0.5, s.pad_end - 0.3]:
					q.transform = Transform3D(Basis.IDENTITY, Vector3(x, s.floor_y + 0.2, -at))
					var found: bool = false
					for h: Dictionary in space.intersect_shape(q, 4):
						found = found or (h["collider"] as Node).get_meta(&"kind", &"") == &"pad"
					pads_ok = pads_ok and found == padded
				# The bait's notch on this step's roof: no floor in its lane past its start, the floor there before it.
				var on: MechaGuppyClimb.Roof = c.roofs[s.index]
				if on.notched():
					ray.collision_mask = TrackBuilder.LAYER_FLOOR
					for at: float in [on.notch_from - 1.0, on.notch_from + 1.0, (on.notch_from + on.end) * 0.5]:
						ray.from = Vector3(x, on.top + 1.0, -at)
						ray.to = Vector3(x, on.top - 1.0, -at)
						var floor_there: bool = not space.intersect_ray(ray).is_empty()
						notch_ok = notch_ok and floor_there == on.covers(lane, at)
					notches += 1 if lane == on.notch_lane else 0
				# The higher roof's front: solid below where a runner could still step up onto it.
				var hq := PhysicsShapeQueryParameters3D.new()
				hq.shape = box
				hq.collide_with_areas = true
				hq.collide_with_bodies = false
				hq.collision_mask = TrackBuilder.LAYER_HAZARD
				hq.transform = Transform3D(Basis.IDENTITY, Vector3(x, roof.top - 1.5, -(front + 0.15)))
				var solid: bool = false
				for h: Dictionary in space.intersect_shape(hq, 4):
					var hz := h["collider"] as Hazard
					solid = solid or (hz != null and hz.is_solid and not hz.dash_passes and hz.top_y() <= roof.top - tuning.pit_depth - 0.05)
				fronts_ok = fronts_ok and solid
			# A rider on the hut reads the lanes that lead up off the hut and the roofs, as planned.
			await _ride(world, s)
			var read: Array[int] = MechaGuppyBot.read_up_lanes(world, c, p)
			var want: Array[int] = []
			for lane: int in range(s.up.x, s.up.y + 1):
				want.append(lane)
			reads_ok = reads_ok and read == want
			if read != want:
				check(false, "step %d: read %s, planned %s %s" % [s.index, read, want, tag])
		check(checked >= 2, "the first steps are built within sight (%d) %s" % [checked, tag])
		check(tops_ok, "each higher roof's top is where the plan has it, lane by lane, and nothing under a drop before it %s" % tag)
		check(ends_ok, "each lane of a hut ends where the plan has it %s" % tag)
		check(pads_ok, "a pad in every lane along each strip but the bait's notch's %s" % tag)
		check(notch_ok and notches >= 1, "the bait's notch: no floor in its lane past its start, the floor there before it, the other lanes' floor on to the roof's end (%d notches) %s"
			% [notches, tag])
		check(fronts_ok, "each roof's front is solid (the dash doesn't pass it) below where a runner could step up onto it %s" % tag)
		check(reads_ok, "a rider reads the lanes that lead up off the hut and the roofs as planned (both cues) %s" % tag)
		await sim.free_world(world)


## Puts the runner on step `s`'s hut, just past its strip, in the middle lane (riding, still running), and lets
## the world settle a frame.
func _ride(world: RunWorld, s: MechaGuppyClimb.Step) -> void:
	var p: Player = world.player
	# Through the pads: a runner on the roof just before them flips up as any does.
	p.floor_y = s.floor_y
	p.h = s.floor_y
	p.distance = s.pad - 1.0
	p.grounded = true
	p.surface = Player.Surface.FLOOR
	if not p.running:
		world.start()
	for i: int in 60:
		await tree.physics_frame
		if p.surface == Player.Surface.CEILING and p.grounded:
			break


# --- The roofs' faces ------------------------------------------------------------------------------

## GDD §10's climb leaves the roofs' faces to the build (DESIGN-TBD, docs/questions/e5e.md): a lane switch into a
## roof's side from below its top is a blocked move; off a roof's lanes that reach back (REACH_BACK) the gap beside
## them is a fall, and a runner falling there who reaches the front of the lanes beyond crashes into it; the
## grapple saves them before they get there, back up onto the roof.
func _test_roof_faces() -> void:
	for lanes: int in [3, 6]:
		var tag: String = "(%d lanes)" % lanes
		# Step 1 (REACH_BACK): roof 2's lanes that lead up reach back past the others.
		for case: int in 3:
			var pair: Array = _fight(lanes, 18.0)
			var world: RunWorld = pair[0]
			var boss: MechaGuppy = pair[1]
			var c: MechaGuppyClimb = boss.climb
			var p: Player = world.player
			c.plan_until(800.0, 0)
			var s: MechaGuppyClimb.Step = c.steps[1]
			var roof: MechaGuppyClimb.Roof = c.roofs[2]
			var up: int = s.up.x
			var beside: int = up - 1 if up > 0 else s.up.y + 1
			var events: Array[StringName] = []
			p.movement_event.connect(func(kind: StringName) -> void: events.append(kind))
			# On the roof's tongue right after landing (bring the stairs up to it first).
			boss.stairs.update(s.land - 5.0)
			await tree.physics_frame
			match case:
				0:
					# Falling beside the tongue, below its top: a switch toward it bumps.
					p.distance = s.deadline + 4.0
					p.surface = Player.Surface.FLOOR
					p.floor_y = s.floor_y
					p.h = roof.top - 1.0
					p.vh = -1.0
					p.grounded = false
					p.lane = beside
					p.set(&"_x", world.geo.lane_x(beside))
					p.grapples = 0
					world.start()
					await tree.physics_frame
					p.press(&"move_right" if up > beside else &"move_left")
					await physics_frames(3)
					check(events.has(&"lane_blocked") and p.lane == beside,
						"a switch into a roof's side from below its top bumps (%s) %s" % [events, tag])
				_:
					# Standing on the tongue, a switch into the gap beside it: a fall, into the front beyond.
					var at: float = roof.start_in(beside) - (0.3 * c.speed)
					p.distance = at
					p.surface = Player.Surface.FLOOR
					p.floor_y = roof.top
					p.h = roof.top
					p.grounded = true
					p.lane = up
					p.set(&"_x", world.geo.lane_x(up))
					p.floor_base = roof.top
					p.grapples = 1 if case == 2 else 0
					var died: Array[String] = [""]
					p.died.connect(func(cause: String) -> void: died[0] = cause)
					world.start()
					await tree.physics_frame
					p.press(&"move_right" if beside > up else &"move_left")
					await _run(world, 1.5, func() -> bool: return p.grounded and p.distance > roof.start_in(beside) + 2.0)
					if case == 1:
						check(not p.alive and died[0] == "tiki bar" and p.distance <= roof.start_in(beside) + 0.5,
							"stepping off a roof's tongue into the gap is a fall: into the front beyond, a crash (%s at %.1f m, the front at %.1f m) %s"
							% [died[0], p.distance, roof.start_in(beside), tag])
					else:
						check(p.alive and p.grounded and absf(p.floor_y - roof.top) < 0.01 and p.grapples == 0,
							"the grapple saves them back up onto the roof before the front (h %.2f, lane %d) %s" % [p.h, p.lane, tag])
			await sim.free_world(world)


# --- Hits, phases, weapons ---------------------------------------------------------------------------

func _test_hits_and_phases() -> void:
	var quick: BossDef = _def_with(func(t: MechaGuppyTuning) -> void: t.top_seconds = 3.0)
	var pair: Array = _fight(5, 18.0, {}, quick)
	var world: RunWorld = pair[0]
	var boss: MechaGuppy = pair[1]
	# A runner who climbs keeps the fight going through its phases.
	var climber := MechaGuppyBot.new(boss)
	check(not boss.register_hit(), "no hit counts in an intro (the boss can't be hurt then)")
	await _run(world, 5.0, func() -> bool: return boss.is_vulnerable(), climber.step)
	check(boss.is_vulnerable() and boss.phase_index == 0, "phase 1's pattern begins after its intro")
	check(boss.damage(50.0, &"weapon") == 0.0 and not boss.weapons_can_hurt(), "weapons do nothing (GDD §10: no chip damage)")
	check(boss.waterfall != null and boss.waterfall.shown > 0.99, "the waterfall backdrop in phase 1")
	for i: int in 3:
		boss.register_hit()
	check(boss.phase_index == 0 and boss.phase_hits == 3, "three hits leave phase 1 running (%d)" % boss.phase_hits)
	boss.register_hit()
	check(boss.phase_index == 1 and not boss.is_vulnerable(), "the fourth hit ends phase 1 (GDD §10: 4 hits)")
	await _run(world, 4.0, func() -> bool: return boss.is_vulnerable(), climber.step)
	for i: int in 5:
		boss.register_hit()
	check(boss.phase_index == 1, "five hits leave phase 2 running")
	boss.register_hit()
	check(boss.phase_index == 2 and boss.top_due(), "the sixth hit ends phase 2 (GDD §10: 6 hits): phase 3, the top")
	await _run(world, 4.0, func() -> bool: return boss.is_vulnerable(), climber.step)
	check(not boss.register_hit() and boss.phase_index == 2, "phase 3 isn't ended by hits (GDD §10: by a minute of dodging)")
	check(boss.waterfall.shown > 0.99 and boss.top_reached_at < 0.0, "the waterfall stays while the runner climbs on to the top")
	await _run(world, 40.0, func() -> bool: return boss.top_reached_at >= 0.0, climber.step)
	check(boss.top_reached_at >= 0.0 and boss.on_top() and _events(boss, &"top_reached").size() == 1,
		"phase 3: the runner reaches the top, which runs on flat (logged: top_reached)")
	await _run(world, 2.3, func() -> bool: return false, climber.step)
	check(boss.waterfall.shown < 0.01 and not boss.is_defeated(), "then the Beach's own backdrop (the waterfall gone)")
	await _run(world, 6.0, func() -> bool: return boss.is_defeated(), climber.step)
	var over: Array[Dictionary] = _events(boss, &"top_over")
	check(boss.is_defeated() and over.size() == 1 and absf(float(over[0]["t"]) - boss.top_reached_at - 3.0) < 0.1,
		"phase 3's minute ends top_seconds after the runner reaches the top: the fight is won (defeated %s)" % boss.is_defeated())
	check(_events(boss, &"hit").size() == 10 and world.player.alive, "every hit logged (%d)" % _events(boss, &"hit").size())
	await sim.free_world(world)
	# The floor base follows the climb: the roof of the step the runner is in.
	pair = _fight(3, 18.0)
	world = pair[0]
	boss = pair[1]
	var bot := MechaGuppyBot.new(boss)
	var bases_ok: Array[bool] = [true]
	await _run(world, 16.0, func() -> bool: return bot.steps_climbed >= 2, func() -> void:
		bot.step()
		var s: MechaGuppyClimb.Step = boss.climb.step_at(world.player.distance)
		bases_ok[0] = bases_ok[0] and is_equal_approx(world.player.floor_base, s.top_y) \
			and world.player.fall_base() <= world.player.floor_y + 0.001)
	check(bot.steps_climbed >= 2 and bases_ok[0], "the floor base follows the climb: the roof of the step the runner is in (%d steps)"
		% bot.steps_climbed)
	await sim.free_world(world)


# --- The armor rule's pickups ---------------------------------------------------------------------

## GDD §10's standard armor rule, on the climb: the pickup appears on the roof the runner will run along, at its
## height, past a landing and short of the next hut, in a lane they'll be in; the runner takes it.
func _test_pickups() -> void:
	for lanes: int in LANES:
		var tag: String = "(%d lanes)" % lanes
		var pair: Array = _fight(lanes, 23.8)
		var world: RunWorld = pair[0]
		var boss: MechaGuppy = pair[1]
		var bot := MechaGuppyBot.new(boss)
		var taken: Array[bool] = [false]
		world.pickups.collected.connect(func(_p: Pickup, _g: bool) -> void: taken[0] = true)
		await _run(world, 8.0, func() -> bool: return world.player.surface == Player.Surface.CEILING, bot.step)
		boss._on_armor_pickup_due(&"protection_broken")
		var placed: bool = not world.pickups.active.is_empty()
		var spot_ok: bool = false
		if placed:
			var pk: Pickup = world.pickups.active[0]
			var c: MechaGuppyClimb = boss.climb
			for i: int in range(1, c.steps.size()):
				var roof: MechaGuppyClimb.Roof = c.roofs[i]
				var into: MechaGuppyClimb.Step = c.steps[i - 1]
				var next: MechaGuppyClimb.Step = c.steps[i]
				if absf(pk.position.y - roof.top) < 0.01 and roof.covers(pk.lane, pk.at) and pk.at > into.land \
						and pk.at < next.hut_start and into.leads_up(pk.lane):
					spot_ok = true
		check(placed and spot_ok and boss.armor_pickups_waiting() == 0,
			"the armor pickup appears on the next roof, at its height, past the landing, short of the next hut, in a lane that leads up %s" % tag)
		await _run(world, 8.0, func() -> bool: return taken[0], bot.step)
		check(taken[0], "the climbing runner takes it %s" % tag)
		await sim.free_world(world)
