extends RefCounted
## The danger density pass (the owner's request, docs/USER_REQUESTS.md: "the algorithm that is used to
## make sure that there is always a free open lane is too forgiving": more enemies and more obstacles,
## about 15% more in the first levels and about 35% more by the final ones). LevelConfig
## .danger_density_increase is each level's dial; at 0 the pass draws nothing and the level is built
## exactly as before. Its pass-wide numbers: data/tuning/danger_density.tres (danger_density_tuning.gd).
##
## It runs in two halves around the fill pass (LevelGenerator._build):
## - apply_enemies(), after the enemy rules and before the fill pass. It first runs the fill pass on the
##   layout as a trial and undoes it at once, to count what the level holds without the pass: its
##   enemies (enemy_count) and its floor pieces (floor_count: holes and fences lane by lane, signs,
##   floor cuts), and the stretches a fill pass would fill (spare_fill_seconds). Each target is that count times
##   1 + the increase (times the tuning's enemy_increase_scale or obstacle_increase_scale), the
##   fraction rounded up or down by a draw from the pass's stream (rng_for("danger_density")). Then it
##   adds enemies up to the enemy target. Being
##   before the fill pass, the fillers keep their spacing from them as from the pattern pass's enemies.
## - apply_obstacles(), right after the fill pass: floor pieces up to the floor target, from its own
##   stream (rng_for("danger_density_rows")). Fillers the new enemies took the room of count against
##   it, so the level ends with its share more pieces either way.
## - apply_wall_fences(), right after the level's own wall fences (WallFencePlacement.place): more of
##   them toward their count times 1 + the increase (times wall_fence_increase_scale), where the wall
##   fences' own rules let one stand, from its own stream (rng_for("danger_density_walls")).
## Wall fences don't count toward the floor target and nothing before them depends on them: a level is
## built the same with or without its wall-fence features but for the wall fences. The pass only adds:
## it never moves or removes what another pass placed, and every enemy before it keeps its seed
## (LevelGenerator.add_enemy).
##
## Enemies, of the tuning's enemy_types only (small threats whose rules the pass can apply), never a
## host, never before the level's first of that kind (never an introduction, never a feature the level
## would lack without the pass):
## 1. Twins: an enemy (not of its kind's first encounter) gets a partner the way one of the level's own
##    pair or row patterns of its kind places one, where the level would pick that pattern there
##    (pick_weights: its difficulty range, its features, the pacing): at the same spot in another lane
##    or on the other wall (cyborg_pair, screech_manhole_row), or that pattern's offset further on
##    (cyborg_stagger, screech_manhole_pair, window_cyborg_pair).
## 2. Encounters: one of the level's single-enemy patterns of those kinds where the level would pick
##    it (the pool cached per ENCOUNTER_CHUNK_SECONDS of track), at random spots of the clear track
##    where its attack window fits; with the tuning's spare_fill_seconds, never splitting a stretch
##    the fill pass would fill into pieces too short for it.
## 2b. Barnacle Turrets (ceiling_turrets): under a ceiling the turret rules would hang one from and none
##    did, or a second where the level pairs them, as those rules space and limit them (_add_turrets).
## A Resonator's attack is its whole visit, from its first pulse to its last pulse's wave past the
## player (the data's resonator_per_pulse off): its pulses shift at run time with the turns and floor
## waits it makes, so nothing the pass adds stands between two planned pulses. With resonator_per_pulse
## on it would be its pulses one by one, as the wall fences keep off them.
## Obstacles:
## 3. Tighter rows: a row of holes or fences (the pieces sharing a spot) takes one more lane of the same
##    piece, narrowest rows first, one lane per row per round, up to the widest row of that piece the
##    level's own fillers make at that spot.
## 4. New rows, in a level with the fill pass only (they are more of its fillers): one of the level's
##    one-row fillers, picked as the fill pass would pick it there, on a grid of row_step_seconds.
## 5. Full rows (the tuning's full_width_rows): an isolated row one lane short of the full width takes
##    its last lane, only where the level's own fillers include a full-width row of that piece there.
## 6. Staggered rows (staggered_rows): one of the level's one-row fillers between two neighbouring rows
##    closer than the clearance, where the level would pick its two-row staggered filler (fence_stagger)
##    and no closer to either than that filler's rows stand: the open lane may move by at most
##    stagger_max_shift_lanes, as it does between that filler's two rows, never vanish.
## 7. Routed rows (routed_rows), where an open lane no longer stays put for the whole clearance but the
##    ground route holds (_routes_ok): a row takes one more lane, clear of other pieces in that lane for
##    routed_row_gap_seconds either side; and corridor rows, one of the level's one-row fillers (not
##    full-width) in any gap between two spots at least twice routed_row_gap_seconds wide, centred or
##    routed_row_gap_seconds from either spot (the far one then may stand the clearance off, where any
##    lane may follow), again in the gaps they split: the longitudinal room levers 4 and 6 can't use
##    when one open lane leaves no room across. The route: through the run of
##    spots around it (ROUTE_SPOTS_MAX each way), from every lane a player could be in, a lane stays
##    reachable at every spot: any lane after the clearance (as between two patterns), one lane switch
##    after the staggered filler's spacing, and the same lane straight on when closer (a corridor no
##    lane switch is asked in); a full row (jumped or slid in every lane) is passed in the lane the
##    player comes to it in, its jump or slide's length taken from the ground for lane switches around
##    it; and the changed spot keeps min_free_lanes open lanes clear of kept stretches.
##    Where the data's own spots already leave no lane the model reaches (the level's own passage,
##    passed as its patterns intend), it starts afresh there, unless the new pieces stand in that
##    passage or narrowed the lanes coming into it; between two of the data's own spots the open lane
##    may also move as many lanes as the player can switch in the ground between (lane_switch_time each,
##    ROUTE_SWITCH_SLACK), next to the changed spot only as above.
##    Levers 6 and 7 are what tighten the "too forgiving" open lane: with only 3 lanes a row may take
##    at most two, so the final zones' extra pieces come from more rows along the track, not wider ones.
## Fairness (the open lane, tightened but never gone; nothing closer than the level's own spacing):
## - clearance: the level's spacing between two patterns there (doodad_after) times the tuning's
##   clearance_spacing_scale, the same time to react the pattern pass leaves; never shortened.
## - an added enemy's attack window (enemy_keep_out and the floor it uses: each type's warning and lead)
##   stays on the playable track with the clearance either side, and clear of the fixed stretches: ramps
##   to the end of their launch, ceiling landing zones, pads in every lane (a shot could hit a player
##   on the lift), speed pads, floor cuts, the rules' lane-less keep-outs but those of the tuning's
##   keep_out_exempt_features (a host's chase), quiet stretches (The Hush) and plain ceilings
##   (_plain_ceiling_keeps: one the level won't put a gauntlet under yet stays plain whole);
## - with the clearance, its window overlaps at most overlap_max other attack windows, all of the
##   tuning's twin_tolerated_types and none a host's (a twin's own group apart): every big threat (a
##   drone, a resonator's pulse, an Octodog, a Buzz Overdrive, a Gilded Sentinel) keeps its stretch;
## - over that whole window a floor enemy leaves min_free_lanes lanes free of floor enemies, holes,
##   fences and kept lanes (a hover truck's), all the time: the open lane never has to be switched to;
##   its type's own rules hold (a cyborg's obstacle margin and panic roll, a window cyborg's signs);
## - an added piece keeps the clearance from every fixed stretch and sign, from every enemy's attack
##   window but those of row_tolerated_types (whose floor lane stays kept and never counts as open), from
##   a quiet stretch, a cyborg's obstacle margin and a pad's lane (a row beside a pad may still lead the
##   player into it, as the gauntlets' rows do); new and full rows stay off plain ceilings as the fill
##   pass does (an open one only near its end); a full row stands clear of every attack window;
## - an added piece keeps the clearance from every other piece in its lane, and every row it adds,
##   widens or comes near keeps min_free_lanes lanes clear of pieces and kept lanes from the clearance
##   before it to the clearance after it (a lane to switch into in the time the pattern pass leaves
##   between two patterns), unless the level's own data made that row without one (levers 3 to 5;
##   levers 6 and 7 keep the moving open lane or the ground route above instead, never fewer than
##   min_free_lanes open lanes at any row); a full row stands alone and a jump clears it
##   (max_gap_jump_fraction), as the level's own full rows do.
## - zone doodads come after the pass (LevelGenerator._place_doodads) and are neither jumped nor stood
##   beside in their lane: near a row the pass touched, a doodad keeps off a lane the ground route
##   leaves the player no way around it in (doodad_ok: say a full row jumped in the only lane a new row
##   left open, landing past the doodad's front), so the floor route through the level holds.
## Pay: with the tuning's credit_added_pieces off, the credit pass gives the pieces it adds no risky
## credit (LevelGenerator.uncredited): the levels get harder, not richer, and the earnings curve the
## shop's prices were set against stays put.
## Its report (LevelGenerator.danger_density_result): the counts and targets, what each lever added,
## the added enemies and touched rows, and the shortfalls ("constraints") where no fair room was left.
## A build caches what it asks often (the first of each kind, the encounter pools, grid spots no row
## fits, gaps no corridor row fitted, each route check's walk up to its spot, the clearance and the
## staggered spacing by track distance), so the pass costs about half again the build time at the dials
## of data/levels (the final zones' most).
## Measured (tools/measure/danger_density.gd, tests/suites/test_danger_density.gd): each band's actual
## enemies and obstacles (holes and fences lane by lane, signs, floor cuts, wall fences), each on its
## own, rise about 17% to 18% in the first levels, 26% to 27% in the middle ones and 32% to 38% in the
## final ones at 3, 5 and 6 lanes;
## the late dials sit a little above 0.35 because the fairest levels (a Gilded Sentinel's stretches,
## The Hush's quiet) leave less room than they ask.

const TuningScript := preload("res://scripts/world/danger_density_tuning.gd")
const TUNING_PATH: String = "res://data/tuning/danger_density.tres"
const CYBORG_RULES: String = "res://scripts/enemies/cyborg_rules.gd"
const WINDOW_CYBORG_RULES: String = "res://scripts/enemies/window_cyborg_rules.gd"
const RESONATOR_RULES: String = "res://scripts/enemies/resonator_rules.gd"
const TURRET: String = "barnacle_turret"
const TURRET_RULES: String = "res://scripts/enemies/barnacle_turret_rules.gd"
## Two track distances closer than this are one spot.
const EPSILON: float = 0.01
## How many lane picks a new row tries before giving up its spot.
const ROW_LANE_TRIES: int = 4
## How many times the enemy half sweeps the level for new encounters while a sweep still adds one.
const ENCOUNTER_SWEEPS: int = 6
## The longest stretch (in seconds at run speed) an encounter's tries spread over: a longer clear
## stretch is cut into stretches this long, each tried on its own.
const ENCOUNTER_CHUNK_SECONDS: float = 6.0
## The most spots a routed row's check (_routes_ok) follows either side of its own.
const ROUTE_SPOTS_MAX: int = 12
## Metres a full row's jump or slide keeps before and after its pieces (a take-off and a landing or a
## stand-up clear of them), in the route check (_full_row_shift).
const FULL_ROW_MARGIN: float = 1.0
## Metres a lane switch between two of the level's own spots takes beyond lane_switch_time at run speed
## in the route check (_route_lanes): a frame's motion and the model's rounding.
const ROUTE_SWITCH_SLACK: float = 1.0
## Metres a zone doodad's stretch reaches past either end in its route check (doodad_ok): no standing
## right at it, nor a jump's arc over it.
const DOODAD_ROUTE_MARGIN: float = 1.5


## Stretches of track [lo, hi], sorted by start, each with an id: quick overlap queries. Track
## distances stay 64-bit floats (a row's pieces share theirs exactly).
class Spans:
	extends RefCounted
	var lo: PackedFloat64Array = PackedFloat64Array()
	var hi: PackedFloat64Array = PackedFloat64Array()
	var ids: PackedInt32Array = PackedInt32Array()
	## The longest stretch: none that starts further back than this before a query reaches it.
	var reach: float = 0.0

	func add(from: float, to: float, id: int = -1) -> void:
		var i: int = lo.bsearch(from, false)
		lo.insert(i, from)
		hi.insert(i, to)
		ids.insert(i, id)
		reach = maxf(reach, to - from)

	## True if no stretch but those with id `skip` overlaps [from, to] (one that only touches it doesn't).
	func clear(from: float, to: float, skip: int = -2) -> bool:
		var i: int = lo.bsearch(from - reach - 0.001, true)
		while i < lo.size() and lo[i] < to:
			if hi[i] > from and ids[i] != skip:
				return false
			i += 1
		return true

	## The ids of the stretches overlapping [from, to], each once.
	func owners_in(from: float, to: float) -> PackedInt32Array:
		var out := PackedInt32Array()
		var i: int = lo.bsearch(from - reach - 0.001, true)
		while i < lo.size() and lo[i] < to:
			if hi[i] > from and not out.has(ids[i]):
				out.append(ids[i])
			i += 1
		return out

	func vectors() -> Array[Vector2]:
		var out: Array[Vector2] = []
		for i: int in lo.size():
			out.append(Vector2(lo[i], hi[i]))
		return out


## What one half of the pass works with in one build.
class Plan:
	extends RefCounted
	var gen: LevelGenerator
	var patterns: Array
	var tuning: Resource
	var rng: RandomNumberGenerator
	var types: PackedStringArray
	var tolerated: PackedStringArray
	var min_free: int = 1
	var scale: float = 1.0
	var lanes: int = 1
	## The playable track: after the run-up, before the end-clear stretch.
	var lo: float = 0.0
	var hi: float = 0.0
	## Half a fence's depth: a fence's piece of track either side of its spot (fill_keep_outs).
	var half: float = 0.0
	var hooks: Dictionary = {}
	## Track no added enemy touches, in any lane (_enemy_fixed).
	var fixed: Spans = Spans.new()
	## Per lane: what a rule keeps it free for (a hover truck's lane all its stay); after the fill pass
	## also each floor enemy's attack window in its lane and each pad's lane with the clearance.
	var kept: Array[Spans] = []
	## Every enemy's attack window, its id its index in layout.enemies (both halves: a full row stands
	## clear of all of them).
	var attacks: Spans = Spans.new()
	## The enemy half: every hole and fence by lane (lane_pieces) and every sign, any lane (pieces).
	var pieces: Spans = Spans.new()
	var overlap_max: int = 1
	## The difficulty from which the level puts gauntlets under its ceilings (gauntlet_difficulty).
	var gauntlets: float = INF
	## Where the level's first enemy of each kind stands (_first_at), as the pass never adds one before.
	var firsts: Dictionary = {}
	## True if every one-row filler of the level's patterns places its piece at its own spot (_spot_open).
	var fillers_at_spot: bool = false
	## The grid spots (_add_rows) where no row fitted: rows only make the floor busier, so they never will.
	var dead_spots: Dictionary = {}
	## _encounter_options per stretch of ENCOUNTER_CHUNK_SECONDS.
	var encounter_options: Dictionary = {}
	## The stretches a fill pass waiting the tuning's spare_fill_seconds would fill without the pass
	## (_trial_counts), whose ends new encounters spare.
	var fill_stretches: Array[Vector2] = []
	var cyborg_rules: GDScript
	var cyborg_tuning: Resource
	var cyborg_spans: Array[Vector2] = []
	var window_rules: GDScript
	var window_half: float = 0.0
	var added: Array[Dictionary] = []
	## After the fill pass: the stretches where rows may widen (rooms: clear of fixed stretches, signs,
	## quiet stretches and the attack windows not of row_tolerated_types, with the clearance), every row
	## ({id, kind, start, end, lanes, proto, mixed, order, w, room, max_width, all}) and its pieces by
	## lane, the rows by their span, how far a row's window reaches past it, and the rows touched.
	var rooms: Array[Vector2] = []
	var room_starts: PackedFloat64Array = PackedFloat64Array()
	## The stretches where new and full rows may go: the rooms, clear of quiet stretches, cyborgs'
	## obstacle margins and plain ceilings (_plain_ceiling_keeps) with the clearance too.
	var row_rooms: Array[Vector2] = []
	var row_room_starts: PackedFloat64Array = PackedFloat64Array()
	var rows: Array[Dictionary] = []
	var lane_pieces: Array[Spans] = []
	var row_spans: Spans = Spans.new()
	var reach: float = 0.0
	var touched: Array[Dictionary] = []
	var touched_ids: Dictionary = {}
	## _clear by track distance (the level's spacing: nothing the pass adds changes it), and in the
	## obstacle half (`stagger_memo_on`: only rows go in) _stagger_gap by track distance.
	var clear_memo: Dictionary = {}
	var stagger_memo: Dictionary = {}
	var stagger_memo_on: bool = false


## The pass's numbers (data/tuning/danger_density.tres), or the defaults without the file.
static func tuning() -> Resource:
	var res: Resource = load(TUNING_PATH) if ResourceLoader.exists(TUNING_PATH) else null
	return res if res != null else TuningScript.new()


## The enemies the pass counts in `layout`: every enemy entry.
static func enemy_count(layout: LevelLayout) -> int:
	return layout.enemies.size()


## The floor pieces the pass's floor target counts in `layout`: holes and fences lane by lane, signs and
## floor cuts.
static func floor_count(layout: LevelLayout) -> int:
	return layout.gaps.size() + layout.fences.size() + layout.signs.size() + layout.cuts.size()


## Every obstacle piece in `layout`: its floor pieces (floor_count) and wall fences.
static func obstacle_count(layout: LevelLayout) -> int:
	return floor_count(layout) + layout.wall_fences.size()


## The clear track kept around an addition at track distance `at`: the level's spacing between two
## patterns there (LevelGenerator.doodad_after), times the tuning's clearance_spacing_scale.
static func clearance(gen: LevelGenerator, at: float, p_tuning: Resource = null) -> float:
	var t: Resource = p_tuning if p_tuning != null else tuning()
	return gen.doodad_after(at) * float(t.get("clearance_spacing_scale"))


## An enemy entry's attack window: its keep-out (LevelGenerator.enemy_keep_out) and the floor it uses.
static func attack_window(gen: LevelGenerator, entry: Dictionary, hooks: Dictionary = {}) -> Vector2:
	var k: Vector2 = gen.enemy_keep_out(entry, hooks)
	var floor_span: Vector2 = LevelGenerator.enemy_floor_span(entry, gen.pace)
	if floor_span.y >= floor_span.x:
		k = Vector2(minf(k.x, floor_span.x), maxf(k.y, floor_span.y))
	return k


## The stretches enemy entry `entry` attacks over, as the pass keeps clear of them: its attack window
## (attack_window), but with the tuning's resonator_per_pulse a planned Resonator's pulses one by one
## (resonator_pulse_windows), as the wall fences keep off them (WallFencePlacement.resonator_pulses).
static func attack_windows(gen: LevelGenerator, entry: Dictionary, hooks: Dictionary = {},
		p_tuning: Resource = null) -> Array[Vector2]:
	var t: Resource = p_tuning if p_tuning != null else tuning()
	if bool(t.get("resonator_per_pulse")):
		var pulses: Array[Vector2] = resonator_pulse_windows(gen, entry)
		if not pulses.is_empty():
			return pulses
	var out: Array[Vector2] = [attack_window(gen, entry, hooks)]
	return out


## A planned Resonator's pulses (resonator_rules.gd: params "pulse_at" and "double"), each from its
## warning to where its last wave has passed the player (ResonatorTuning.pulse_seconds at run speed, or
## its meeting stretch's end if later), with the plan's margin (resonator_rules.gd's PLAN_MARGIN) either side:
## a big attack, kept clear with the clearance like any. Between two pulses it only hovers (it attacks
## nothing; Resonator.is_major_attack_active is off), and every pulse rechecks its floor at run time and
## waits for clear floor (Resonator.pulse_clear). [] for any other entry or a Resonator without a plan.
static func resonator_pulse_windows(gen: LevelGenerator, entry: Dictionary) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if String(entry.get("type", "")) != "resonator":
		return out
	var rt := EnemyDirector.tuning_for("resonator") as ResonatorTuning
	var params: Dictionary = entry.get("params", {})
	var anchors: Array = params.get("pulse_at", [])
	if rt == null or anchors.is_empty():
		return out
	var doubles: Array = params.get("double", [])
	var rules: GDScript = load(RESONATOR_RULES) as GDScript if ResourceLoader.exists(RESONATOR_RULES) else null
	var margin: float = float(rules.get_script_constant_map().get("PLAN_MARGIN", 1.0)) if rules != null else 1.0
	var scaling: float = gen.config.enemy_scaling
	for i: int in anchors.size():
		var a: float = float(anchors[i])
		var double: bool = i < doubles.size() and bool(doubles[i])
		var meeting: Vector2 = rt.meeting_stretch(a, double, gen.speed, scaling, gen.pace)
		var passed: float = a + rt.pulse_seconds(double, gen.speed, scaling, gen.tuning.hurtbox_size.z,
			EnemyDirector.SHOT_PASS_MARGIN, gen.pace) * gen.speed
		out.append(Vector2(minf(a, meeting.x) - margin, maxf(passed, meeting.y) + margin))
	return out


## The enemy half (see the header), after the enemy rules and before the fill pass. Returns the report
## so far; {} with the dial at 0 (nothing drawn).
static func apply_enemies(gen: LevelGenerator, patterns: Array) -> Dictionary:
	var increase: float = gen.config.danger_density_increase
	if increase <= 0.0:
		return {}
	var plan: Plan = _plan(gen, patterns, gen.rng_for("danger_density"))
	var base: Vector2i = _trial_counts(gen, patterns, plan.fill_stretches)
	var enemy_target: int = base.x + _rounded(base.x * increase * float(plan.tuning.get("enemy_increase_scale")),
		plan.rng)
	var floor_target: int = base.y + _rounded(base.y * increase * float(plan.tuning.get("obstacle_increase_scale")),
		plan.rng)
	_index_enemies(plan)
	var twins: int = _add_twins(plan, enemy_target)
	var encounters: int = _add_encounters(plan, enemy_target)
	var turrets: int = _add_turrets(plan, enemy_target)
	return {
		"increase": increase,
		"baseline_enemies": base.x, "enemy_target": enemy_target,
		"baseline_floor": base.y, "floor_target": floor_target,
		"twins": twins, "encounters": encounters, "turrets": turrets, "added_enemies": plan.added,
		"min_free_lanes": plan.min_free,
	}


## The obstacle half (see the header), right after the fill pass, toward `report`'s floor target (the
## enemy half's report, which it completes and returns; {} stays {}).
static func apply_obstacles(gen: LevelGenerator, patterns: Array, report: Dictionary) -> Dictionary:
	if report.is_empty():
		return report
	var plan: Plan = _plan(gen, patterns, gen.rng_for("danger_density_rows"))
	plan.stagger_memo_on = true
	_index_obstacles(plan)
	var target: int = int(report["floor_target"])
	var widened: int = 0
	var new_rows: int = 0
	var full_rows: int = 0
	var new_pieces: int = 0
	var rows_on: bool = gen.config.fill_empty_seconds > 0.0
	for _round: int in maxi(int(plan.tuning.get("obstacle_rounds")), 1):
		var before: int = floor_count(gen.layout)
		if before >= target:
			break
		widened += _widen_rows(plan, target)
		if rows_on:
			var added: Vector2i = _add_rows(plan, target)
			new_rows += added.x
			new_pieces += added.y
		if bool(plan.tuning.get("full_width_rows")):
			full_rows += _fill_rows(plan, target)
		if floor_count(gen.layout) == before:
			break
	var staggered := Vector2i.ZERO
	if rows_on and bool(plan.tuning.get("staggered_rows")) and floor_count(gen.layout) < target:
		staggered = _stagger_rows(plan, target)
	var routed: int = 0
	var routed_new := Vector2i.ZERO
	if bool(plan.tuning.get("routed_rows")) and floor_count(gen.layout) < target:
		routed = _route_rows(plan, target)
		if rows_on and floor_count(gen.layout) < target:
			routed_new = _route_new_rows(plan, target)
			if routed_new.x > 0 and floor_count(gen.layout) < target:
				routed += _route_rows(plan, target)
	var constraints: PackedStringArray = []
	if enemy_count(gen.layout) < int(report["enemy_target"]):
		constraints.append("enemies %d of %d: no fair room for another twin or encounter" % [
			enemy_count(gen.layout), int(report["enemy_target"])])
	if floor_count(gen.layout) < target:
		constraints.append("floor pieces %d of %d: no row left to widen fairly, no clear room for a row or a staggered row" % [
			floor_count(gen.layout), target])
	report.merge({
		"enemies": enemy_count(gen.layout), "floor": floor_count(gen.layout),
		"widened": widened, "new_rows": new_rows, "new_row_pieces": new_pieces, "full_rows": full_rows,
		"staggered_rows": staggered.x, "staggered_pieces": staggered.y, "routed": routed,
		"routed_rows": routed_new.x, "routed_row_pieces": routed_new.y,
		"rows_touched": plan.touched, "constraints": constraints,
	}, true)
	gen.danger_density_plan = plan
	return report


## The wall half (see the header), right after the level's wall fences (WallFencePlacement.place), toward
## their count times 1 + the increase (times the tuning's wall_fence_increase_scale), from its own stream
## (rng_for("danger_density_walls")): completes and returns `report` ({} stays {}).
static func apply_wall_fences(gen: LevelGenerator, report: Dictionary) -> Dictionary:
	if report.is_empty():
		return report
	var layout: LevelLayout = gen.layout
	var base: int = layout.wall_fences.size()
	var t: Resource = tuning()
	var rng: RandomNumberGenerator = gen.rng_for("danger_density_walls")
	var target: int = base + _rounded(base * gen.config.danger_density_increase
		* float(t.get("wall_fence_increase_scale")), rng)
	var added: int = 0
	if target > base:
		added = _add_wall_fences(gen, rng, target)
	report.merge({"baseline_wall_fences": base, "wall_fence_target": target, "wall_fences_added": added,
		"wall_fences": layout.wall_fences.size()}, true)
	if layout.wall_fences.size() < target:
		var constraints: PackedStringArray = report.get("constraints", PackedStringArray())
		constraints.append("wall fences %d of %d: no fair spot left between two" % [layout.wall_fences.size(), target])
		report["constraints"] = constraints
	return report


## Wall fences in the middles of the longest stretches between two of the level's (or after its last),
## until `target`: each at the first spot from a quarter before the middle to a quarter past it where
## the wall fences' own rules let one stand (WallFencePlacement._fit: its keep-outs on either wall, its
## spacing from every other, off an introduction's stretch), past its kind's start, of a kind as the
## wall fences pick one there (partial_share). Returns how many it added.
static func _add_wall_fences(gen: LevelGenerator, rng: RandomNumberGenerator, target: int) -> int:
	var layout: LevelLayout = gen.layout
	var wt: WallFenceTuning = WallFencePlacement.tuning()
	var full_on: bool = gen.config.has_feature(WallFencePlacement.FEATURE)
	var partial_on: bool = gen.config.has_feature(WallFencePlacement.PARTIAL)
	var keeps: Array = [WallFencePlacement.merged(WallFencePlacement.keep_outs(gen, layout, -1, wt)),
		WallFencePlacement.merged(WallFencePlacement.keep_outs(gen, layout, 1, wt))]
	var last: float = layout.length - gen.config.end_clear_distance
	# Where each kind may come from (its first, the introduction where the level has one), and the
	# introductions' stretches, where nothing else stands (WallFencePlacement._alone).
	var full_from: float = maxf(gen.feature_start(WallFencePlacement.FEATURE), gen.config.start_clear_distance)
	var partial_from: float = maxf(gen.feature_start(WallFencePlacement.PARTIAL), gen.config.start_clear_distance)
	var alone: Array[Vector2] = []
	var gap: float = wt.same_side_gap_seconds * gen.speed
	for partial: bool in [false, true]:
		var first: float = INF
		for w: Dictionary in layout.wall_fences:
			if WallFencePlan.is_partial(w) == partial:
				first = minf(first, float(w["at"]))
		if first == INF:
			continue
		if partial:
			partial_from = maxf(partial_from, first)
		else:
			full_from = maxf(full_from, first)
		var feature: String = WallFencePlacement.PARTIAL if partial else WallFencePlacement.FEATURE
		if gen.config.feature_starts.has(feature):
			alone.append(Vector2(first - gap + EPSILON, first + gap - EPSILON))
	if full_on and partial_on:
		partial_from = maxf(partial_from, full_from)
	var from: float = full_from if full_on else partial_from
	var dead: Dictionary = {}
	var added: int = 0
	while layout.wall_fences.size() < target:
		var spots: Array[float] = [from]
		for w: Dictionary in layout.wall_fences:
			if float(w["at"]) > from:
				spots.append(float(w["at"]))
		spots.append(last)
		spots.sort()
		var best := Vector2.ZERO
		for i: int in spots.size() - 1:
			var s := Vector2(spots[i], spots[i + 1])
			if s.y - s.x > best.y - best.x and not dead.has(s):
				best = s
		if best.y - best.x <= EPSILON:
			break
		dead[best] = true
		var mid: float = (best.x + best.y) * 0.5
		var quarter: float = (best.y - best.x) * 0.25
		var band: String = "full"
		if partial_on and mid > partial_from and (not full_on or rng.randf() < wt.partial_share):
			band = WallFencePlacement._partial_band(rng)
		elif not full_on:
			continue
		var side: int = -1 if rng.randf() < 0.5 else 1
		var entry: Dictionary = WallFencePlacement._fit(gen, wt, rng, keeps, band, [side, -side], mid - quarter,
			mid + quarter, false, alone)
		if not entry.is_empty():
			added += 1
	layout.wall_fences.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["at"]) < float(b["at"]))
	return added


## `value`'s whole part, plus one with the chance of its fraction (the pass's stream).
static func _rounded(value: float, rng: RandomNumberGenerator) -> int:
	var whole: int = floori(value)
	return whole + (1 if rng.randf() < value - whole else 0)


## The level's enemies and floor pieces (Vector2i(enemy_count, floor_count)) as they'd be after the fill
## pass without this pass (_trial_fill). Adds to `filled` each stretch with nothing going on
## (fill_keep_outs' activity) in which a fill pass waiting the tuning's spare_fill_seconds placed a
## filler: the level's own fill pass when it waits as long, else a second trial, so the enemies never
## depend on the level's fill_empty_seconds.
static func _trial_counts(gen: LevelGenerator, patterns: Array, filled: Array[Vector2]) -> Vector2i:
	var spare: float = maxf(float(tuning().get("spare_fill_seconds")), 0.0)
	var own: float = gen.config.fill_empty_seconds
	var empties: Array[Vector2] = []
	if spare > 0.0:
		empties = LevelGenerator.free_stretches(gen.fill_keep_outs(patterns)["activity"],
			gen.config.start_clear_distance, gen.layout.length - gen.config.end_clear_distance)
	var trial: Dictionary = _trial_fill(gen, patterns, own)
	if spare > 0.0:
		var ats: PackedFloat64Array = trial["ats"] if is_equal_approx(spare, own) \
			else _trial_fill(gen, patterns, spare)["ats"]
		for at: float in ats:
			for e: Vector2 in empties:
				if e.x <= at + EPSILON and at <= e.y + EPSILON and not filled.has(e):
					filled.append(e)
					break
	return trial["counts"]


## Runs the fill pass on the layout as a trial, waiting `seconds` (the level's fill_empty_seconds or, on
## a copy of its config, another), and puts the layout and the generator back as they were (the fill
## pass draws from its own stream, rng_for("fill")): {counts: Vector2i(enemy_count, floor_count) after
## it, ats: where each filler went}.
static func _trial_fill(gen: LevelGenerator, patterns: Array, seconds: float) -> Dictionary:
	var layout: LevelLayout = gen.layout
	if seconds <= 0.0:
		return {"counts": Vector2i(enemy_count(layout), floor_count(layout)), "ats": PackedFloat64Array()}
	var gaps: Array[Dictionary] = layout.gaps.duplicate()
	var fences: Array[Dictionary] = layout.fences.duplicate()
	var enemies: Array[Dictionary] = layout.enemies.duplicate()
	var fills: Array[Dictionary] = gen.fills.duplicate()
	var stretches: Array[Vector2] = gen._clear_stretches.duplicate()
	var warnings: PackedStringArray = gen.warnings.duplicate()
	var config: LevelConfig = gen.config
	if not is_equal_approx(seconds, config.fill_empty_seconds):
		gen.config = config.duplicate() as LevelConfig
		gen.config.fill_empty_seconds = seconds
	gen._fill_empty_stretches(patterns)
	gen.config = config
	var ats: PackedFloat64Array = PackedFloat64Array()
	for i: int in range(fills.size(), gen.fills.size()):
		ats.append(float(gen.fills[i]["at"]))
	var out := Vector2i(enemy_count(layout), floor_count(layout))
	layout.gaps = gaps
	layout.fences = fences
	layout.enemies = enemies
	gen.fills = fills
	gen._clear_stretches = stretches
	gen.warnings = warnings
	return {"counts": out, "ats": ats}


static func _plan(gen: LevelGenerator, patterns: Array, rng: RandomNumberGenerator) -> Plan:
	var plan := Plan.new()
	plan.gen = gen
	plan.patterns = patterns
	plan.tuning = tuning()
	plan.rng = rng
	plan.types = plan.tuning.get("enemy_types")
	plan.tolerated = plan.tuning.get("twin_tolerated_types")
	plan.overlap_max = maxi(int(plan.tuning.get("overlap_max")), 0)
	plan.gauntlets = gen.gauntlet_difficulty(patterns)
	plan.lanes = gen.layout.lane_count
	plan.min_free = clampi(int(plan.tuning.get("min_free_lanes")), 1, maxi(plan.lanes - 1, 1))
	plan.scale = float(plan.tuning.get("clearance_spacing_scale"))
	plan.lo = gen.config.start_clear_distance
	plan.hi = gen.layout.length - gen.config.end_clear_distance
	plan.half = gen.tuning.fence_depth * 0.5
	for lane: int in plan.lanes:
		plan.kept.append(Spans.new())
		plan.lane_pieces.append(Spans.new())
	return plan


## The stretches neither half adds to, in any lane: ramps (to the end of their launch), ceiling landing
## zones, speed pads, floor cuts' windows and the rules' lane-less keep-outs (a Gilded Sentinel's
## turn; not those of the tuning's keep_out_exempt_features: a host's chase). Each half adds its own
## (_enemy_fixed, _index_obstacles): pads, quiet stretches, plain ceilings.
static func _fixed_stretches(plan: Plan) -> Array[Vector2]:
	var gen: LevelGenerator = plan.gen
	var layout: LevelLayout = gen.layout
	var out: Array[Vector2] = []
	for r: Dictionary in layout.ramps:
		var at: float = float(r["at"])
		out.append(Vector2(at, maxf(gen.ramp_launch(r).end(), at + gen.tuning.ramp_length)))
	for h: Dictionary in layout.hulls:
		out.append(gen.zones.landing_zone(h))
	for p: Dictionary in layout.speed_pads:
		out.append(Vector2(float(p["at"]), float(p["at"]) + gen.tuning.speed_pad_length))
	for c: Dictionary in layout.cuts:
		out.append(FloorCutPlan.window(c, gen.speed))
	var exempt: PackedStringArray = plan.tuning.get("keep_out_exempt_features")
	for feature: String in gen.config.features:
		if exempt.has(feature):
			continue
		var path: String = LevelGenerator.RULES_DIR.path_join("%s_rules.gd" % feature)
		var script: GDScript = load(path) as GDScript if ResourceLoader.exists(path) else null
		if script == null or not script.has_method("doodad_keep_outs"):
			continue
		for k: Dictionary in script.call("doodad_keep_outs", gen):
			if not k.has("lane"):
				out.append(Vector2(float(k["from"]), float(k["to"])))
	return out


## The stretch pad entry `p` keeps clear in its lane (CeilingZones.pad_zone) with the pad itself and, as
## the fill pass keeps it under a gauntlet's ceiling, the second after it.
static func _pad_span(plan: Plan, p: Dictionary) -> Vector2:
	var at: float = float(p["at"])
	var zone: Vector2 = plan.gen.zones.pad_zone(at)
	var after: float = maxf(plan.gen.tuning.pad_length, LevelGenerator.FILL_CEILING_AFTER_PAD_SECONDS * plan.gen.speed)
	return Vector2(minf(zone.x, at), maxf(zone.y, at + after))


## The stretches of the level's plain ceilings (_plain_ceiling) neither half adds to, as the fill pass
## keeps them: a plain ceiling the level would not yet put a gauntlet under (one lane wide, or before
## the gauntlets' difficulty: City 2 shows a plain one first, GDD §6) whole; any other only from
## FILL_CEILING_BEFORE_END_SECONDS before its end to its landing zone's end, so the floor under it may
## take what a gauntlet's would (ceiling_over_cyborgs, ceiling_over_fences).
static func _plain_ceiling_keeps(plan: Plan) -> Array[Vector2]:
	var gen: LevelGenerator = plan.gen
	var layout: LevelLayout = gen.layout
	var out: Array[Vector2] = []
	for h: Dictionary in layout.hulls:
		if not _plain_ceiling(plan, h):
			continue
		var start: float = float(h["start"])
		var landing: float = gen.zones.landing_zone(h).y
		if layout.hull_width(h) >= 2 and gen.difficulty_at(start / layout.length) >= plan.gauntlets:
			start = maxf(start, float(h["end"]) - LevelGenerator.FILL_CEILING_BEFORE_END_SECONDS * gen.speed)
		out.append(Vector2(start, landing))
	return out


## The lanes the rules keep (a hover truck's for all its stay) into `plan.kept`, a hair wider.
static func _keep_rule_lanes(plan: Plan) -> void:
	for k: Dictionary in plan.gen.rules_doodad_keep_outs():
		var lane: int = int(k.get("lane", -1))
		if lane >= 0 and lane < plan.lanes:
			plan.kept[lane].add(float(k["from"]) - EPSILON, float(k["to"]) + EPSILON)


static func _clear(plan: Plan, at: float) -> float:
	var out: Variant = plan.clear_memo.get(at)
	if out == null:
		out = clearance(plan.gen, at, plan.tuning)
		plan.clear_memo[at] = out
	return out


# --- Enemies -------------------------------------------------------------------------------------

static func _index_enemies(plan: Plan) -> void:
	var gen: LevelGenerator = plan.gen
	var layout: LevelLayout = gen.layout
	for s: Vector2 in _enemy_fixed(plan):
		plan.fixed.add(s.x, s.y)
	_keep_rule_lanes(plan)
	for i: int in layout.enemies.size():
		for w: Vector2 in attack_windows(gen, layout.enemies[i], plan.hooks, plan.tuning):
			plan.attacks.add(w.x, w.y, i)
	for g: Dictionary in layout.gaps:
		_lane_piece(plan, int(g["lane"]), Vector2(float(g["start"]), float(g["end"])))
	for f: Dictionary in layout.fences:
		_lane_piece(plan, int(f["lane"]), Vector2(float(f["at"]) - plan.half, float(f["at"]) + plan.half))
	for s: Dictionary in layout.signs:
		plan.pieces.add(float(s["start"]), float(s["end"]))
	if plan.types.has("cyborg") and ResourceLoader.exists(CYBORG_RULES):
		plan.cyborg_rules = load(CYBORG_RULES) as GDScript
		var path: String = String(plan.cyborg_rules.get_script_constant_map().get("TUNING_PATH", ""))
		plan.cyborg_tuning = load(path) if ResourceLoader.exists(path) else null
		plan.cyborg_spans.assign(plan.cyborg_rules.call("obstacle_spans", layout, gen.tuning, gen.zones))
	if plan.types.has("window_cyborg") and ResourceLoader.exists(WINDOW_CYBORG_RULES):
		plan.window_rules = load(WINDOW_CYBORG_RULES) as GDScript
		var consts: Dictionary = plan.window_rules.get_script_constant_map()
		var path: String = String(consts.get("TUNING_PATH", ""))
		var t: Resource = load(path) if ResourceLoader.exists(path) else null
		if t != null:
			plan.window_half = float(t.get("window_length")) * 0.5 + float(consts.get("SIGN_CLEARANCE", 0.0))


## Indexes a hole's or fence's `span` in `lane` (the enemy half's plan.lane_pieces).
static func _lane_piece(plan: Plan, lane: int, span: Vector2) -> void:
	if lane >= 0 and lane < plan.lanes:
		plan.lane_pieces[lane].add(span.x, span.y)


## The stretches no added enemy's attack window touches, in any lane: the fixed stretches
## (_fixed_stretches), pads in every lane with their run-up and the second after (_pad_span), quiet
## stretches and plain ceilings as _plain_ceiling_keeps keeps them. The floor under any other ceiling
## may take one, as the level's own patterns put Screeches and generators there
## (ceiling_over_manholes, ceiling_over_generator).
static func _enemy_fixed(plan: Plan) -> Array[Vector2]:
	var gen: LevelGenerator = plan.gen
	var out: Array[Vector2] = _fixed_stretches(plan)
	for p: Dictionary in gen.layout.pads:
		out.append(_pad_span(plan, p))
	out.append_array(gen.quiet_stretches())
	out.append_array(_plain_ceiling_keeps(plan))
	return out

## True if `pattern` is among what the level would pick at track distance `at` (pick_weights: its
## difficulty range there, its features, the pacing).
static func _picked_at(plan: Plan, pattern: Dictionary, at: float) -> bool:
	var id: String = String(pattern.get("id", ""))
	for p: Dictionary in _pool_at(plan, at, false)["patterns"]:
		if String(p.get("id", "")) == id:
			return true
	return false


static func _pool_at(plan: Plan, at: float, fill: bool) -> Dictionary:
	var gen: LevelGenerator = plan.gen
	return gen.pick_weights(plan.patterns, gen.difficulty_at(clampf(at / gen.layout.length, 0.0, 1.0)), at, "", fill)


## True if every feature `pattern` requires is one of the tuning's enemy types: a pattern that may
## place nothing the pass may not add (never a host's or a wall vent's).
static func _requires_ok(plan: Plan, pattern: Dictionary) -> bool:
	for need: Variant in pattern.get("requires", []):
		if not plan.types.has(String(need)):
			return false
	return true


## True if the pass may twin or add enemy entry (or pattern element) `e`: one of the tuning's types,
## never a host.
static func _allowed(plan: Plan, e: Dictionary) -> bool:
	return plan.types.has(String(e.get("type", ""))) \
		and not bool((e.get("params", {}) as Dictionary).get("host", false))


## An entry's params as a pattern sets them: without what the rules roll or plan (a cyborg's panic).
static func _pattern_params(params: Dictionary) -> Dictionary:
	var out: Dictionary = params.duplicate(true)
	out.erase("panic")
	out.erase("floor_span")
	return out


## "type|wall" or "type|floor": the kind of encounter an enemy is.
static func _kind_key(e: Dictionary) -> String:
	return "%s|%s" % [String(e.get("type", "")), "wall" if int(e.get("side", 0)) != 0 else "floor"]


## Where the level's first enemy of `e`'s kind (_kind_key) that the pass may add (_allowed) stands; INF
## without one.
static func _first_at(plan: Plan, e: Dictionary) -> float:
	var key: String = _kind_key(e)
	if plan.firsts.has(key):
		return float(plan.firsts[key])
	var out: float = INF
	for o: Dictionary in plan.gen.layout.enemies:
		if _allowed(plan, o) and _kind_key(o) == key:
			out = minf(out, float(o["at"]))
	plan.firsts[key] = out
	return out


## The shapes the level's own patterns give an enemy like `anchor` (its type, wall or floor, params) at
## its spot, where the level would pick them: {"same": how many may stand at one spot, "offsets": the
## track between two of them in a pattern that places two one after the other}. Only patterns that
## place nothing but such enemies (and credits) and need nothing but the tuning's types count: a pair
## or a row, never a gauntlet.
static func _shapes(plan: Plan, anchor: Dictionary) -> Dictionary:
	var gen: LevelGenerator = plan.gen
	var type: String = String(anchor["type"])
	var wall: bool = int(anchor.get("side", 0)) != 0
	var params: Dictionary = _pattern_params(anchor.get("params", {}))
	var same: int = 1
	var offsets: Array[float] = []
	for p: Dictionary in _pool_at(plan, float(anchor["at"]), false)["patterns"]:
		if not _requires_ok(plan, p):
			continue
		var spots: Array[float] = []
		var count: int = 0
		var plain: bool = true
		for element: Dictionary in p.get("elements", []):
			var kind: String = String(element.get("kind", ""))
			if kind == "credits":
				continue
			if kind != "enemy" or String(element.get("type", "")) != type or element.has("side") != wall \
					or _pattern_params(element.get("params", {})) != params:
				plain = false
				break
			spots.append(gen.metres(float(element.get("at", 0.0))) + float(element.get("at_seconds", 0.0)) * gen.speed)
			if wall:
				count = maxi(count, 2 if String(element.get("side", "")) == "both" else 1)
			else:
				count = maxi(count, LevelGenerator._selector_count(
					element.get("lanes", {"mode": "random", "count": 1}), plan.lanes, 0))
		if not plain or spots.is_empty():
			continue
		same = maxi(same, count)
		for i: int in spots.size():
			for j: int in range(i + 1, spots.size()):
				var offset: float = absf(spots[j] - spots[i])
				if offset > EPSILON and not offsets.has(offset):
					offsets.append(offset)
	return {"same": same, "offsets": offsets}


## An entry for `type` at `at` in `lane` (on wall `side`), not yet added.
static func _probe(type: String, at: float, lane: int, side: int, params: Dictionary) -> Dictionary:
	return {"type": type, "at": at, "lane": lane, "side": side, "seed": 0, "params": params}


## True if enemy entry `e` is a host (a big attack, never tolerated next to an addition).
static func _host(e: Dictionary) -> bool:
	return bool((e.get("params", {}) as Dictionary).get("host", false))


## True if enemy `probe` over `window` leaves min_free_lanes lanes free of floor enemies (whose attack
## windows overlap it, the probe's own floor lane too), holes, fences and kept lanes, its own floor lane
## (_floor_lanes) being free of all but itself; a wall enemy's window also clear of signs. The track the
## player dodges it on stays open: every lane it doesn't take may still be holed or fenced elsewhere.
static func _floor_ok(plan: Plan, probe: Dictionary, window: Vector2) -> bool:
	var taken: Dictionary = {}
	for lane: int in _floor_lanes(plan, probe):
		if not plan.kept[lane].clear(window.x, window.y) or not plan.lane_pieces[lane].clear(window.x, window.y):
			return false
		taken[lane] = true
	if int(probe.get("side", 0)) != 0 and not plan.pieces.clear(window.x, window.y):
		return false
	for id: int in plan.attacks.owners_in(window.x, window.y):
		for lane: int in _floor_lanes(plan, plan.gen.layout.enemies[id]):
			taken[lane] = true
	for l: int in plan.lanes:
		if not plan.kept[l].clear(window.x, window.y) or not plan.lane_pieces[l].clear(window.x, window.y):
			taken[l] = true
	return plan.lanes - taken.size() >= plan.min_free


## True if, but for `group` (a twin's), the attack windows overlapping `window` are at most the tuning's
## overlap_max, every one of the twin_tolerated_types and none a host's.
static func _overlap_ok(plan: Plan, window: Vector2, group: Array[int]) -> bool:
	var count: int = 0
	for id: int in plan.attacks.owners_in(window.x, window.y):
		if group.has(id):
			continue
		var o: Dictionary = plan.gen.layout.enemies[id]
		count += 1
		if not plan.tolerated.has(String(o.get("type", ""))) or _host(o):
			return false
		if count > plan.overlap_max:
			return false
	return true


## True if `probe`'s type's own rules would keep it: a cyborg's obstacle margin (CyborgRules), a window
## cyborg's signs (WindowCyborgRules).
static func _type_rules_ok(plan: Plan, probe: Dictionary) -> bool:
	var type: String = String(probe["type"])
	var at: float = float(probe["at"])
	if type == "cyborg" and plan.cyborg_rules != null and plan.cyborg_tuning != null:
		var margin: float = plan.cyborg_rules.call("obstacle_margin_at", plan.cyborg_tuning, plan.gen.pace)
		if plan.cyborg_rules.call("near_any", plan.cyborg_spans, at, margin):
			return false
	if type == "window_cyborg" and plan.window_rules != null \
			and plan.window_rules.call("_sign_near", plan.gen.layout, int(probe["side"]), at, plan.window_half):
		return false
	return true


## Adds enemy `probe` (it fits) through LevelGenerator.add_enemy, rolling a cyborg's panic as its rules
## would (CyborgTuning.panic_chance), and indexes its attack window.
static func _add_enemy(plan: Plan, probe: Dictionary) -> Dictionary:
	var params: Dictionary = probe["params"]
	if String(probe["type"]) == "cyborg" and not params.has("panic"):
		var chance: float = float(plan.cyborg_tuning.get("panic_chance")) if plan.cyborg_tuning != null else 0.0
		params["panic"] = plan.rng.randf() < chance
	var entry: Dictionary = plan.gen.add_enemy(String(probe["type"]), float(probe["at"]), int(probe["lane"]),
		int(probe["side"]), params)
	var w: Vector2 = attack_window(plan.gen, entry, plan.hooks)
	plan.attacks.add(w.x, w.y, plan.gen.layout.enemies.size() - 1)
	plan.gen._trim_clear_stretches(w)
	plan.added.append(entry)
	return entry


## Lever 1: twins, until `target` enemies. Returns how many it added.
static func _add_twins(plan: Plan, target: int) -> int:
	var enemies: Array[Dictionary] = plan.gen.layout.enemies
	var firsts: Dictionary = {}
	var anchors: Array[int] = []
	for i: int in enemies.size():
		var e: Dictionary = enemies[i]
		if not _allowed(plan, e):
			continue
		var key: String = _kind_key(e)
		if not firsts.has(key):
			firsts[key] = _first_at(plan, e)
		if float(e["at"]) > float(firsts[key]) + EPSILON:
			anchors.append(i)
	_shuffle(anchors, plan.rng)
	var added: int = 0
	for i: int in anchors:
		if enemy_count(plan.gen.layout) >= target:
			break
		if _add_twin(plan, i):
			added += 1
	return added


static func _add_twin(plan: Plan, index: int) -> bool:
	var gen: LevelGenerator = plan.gen
	var enemies: Array[Dictionary] = gen.layout.enemies
	var e: Dictionary = enemies[index]
	var type: String = String(e["type"])
	var key: String = _kind_key(e)
	var side: int = int(e.get("side", 0))
	var at: float = float(e["at"])
	var params: Dictionary = _pattern_params(e.get("params", {}))
	var shapes: Dictionary = _shapes(plan, e)
	var offsets: Array[float] = shapes["offsets"]
	# The enemies of its kind at its spot (a pattern's pair or row), and how near the next ones are.
	var group: Array[int] = []
	var nearest: float = INF
	for j: int in enemies.size():
		var o: Dictionary = enemies[j]
		if _kind_key(o) != key:
			continue
		var d: float = absf(float(o["at"]) - at)
		if d < EPSILON:
			group.append(j)
		else:
			nearest = minf(nearest, d)
	var options: Array[Dictionary] = []
	if group.size() < int(shapes["same"]):
		if side != 0:
			if not _group_has(gen, group, "side", -side):
				options.append(_probe(type, at, gen.layout.outer_lane(-side), -side, params.duplicate(true)))
		else:
			for lane: int in plan.lanes:
				if not _group_has(gen, group, "lane", lane):
					options.append(_probe(type, at, lane, 0, params.duplicate(true)))
	if group.size() == 1:
		for offset: float in offsets:
			# Never a third one in a pattern's stagger: no other of its kind within the offset.
			if nearest <= offset + EPSILON:
				continue
			if side != 0:
				for s: int in [-1, 1]:
					options.append(_probe(type, at + offset, gen.layout.outer_lane(s), s, params.duplicate(true)))
			else:
				for lane: int in plan.lanes:
					if lane != int(e["lane"]):
						options.append(_probe(type, at + offset, lane, 0, params.duplicate(true)))
	_shuffle_dicts(options, plan.rng)
	for probe: Dictionary in options:
		if _twin_fits(plan, probe, group, at):
			_add_enemy(plan, probe)
			return true
	return false


static func _group_has(gen: LevelGenerator, group: Array[int], field: String, value: int) -> bool:
	for j: int in group:
		if int(gen.layout.enemies[j].get(field, 0)) == value:
			return true
	return false


## True if twin `probe` of the enemies at `group` (at `anchor_at`) may join: its attack window (and, one
## further on, the spacing after it) on the playable track and clear of every fixed stretch; but for its
## group's, at most overlap_max attack windows overlap it, all of tolerated types (_overlap_ok); the
## floor and its type's rules allow it (_floor_ok, _type_rules_ok).
static func _twin_fits(plan: Plan, probe: Dictionary, group: Array[int], anchor_at: float) -> bool:
	var gen: LevelGenerator = plan.gen
	var at: float = float(probe["at"])
	var k: Vector2 = attack_window(gen, probe, plan.hooks)
	var after: float = 0.0 if absf(at - anchor_at) < EPSILON else _clear(plan, at)
	var full := Vector2(k.x, k.y + after)
	if full.x < plan.lo or full.y > plan.hi or not plan.fixed.clear(full.x, full.y):
		return false
	return _overlap_ok(plan, full, group) and _floor_ok(plan, probe, full) and _type_rules_ok(plan, probe)


## True if enemy `probe` may join as an encounter of its own: its attack window with the clearance
## before and after it on the playable track, its attack window clear of every fixed stretch (as the
## pattern pass spaces patterns, not their warnings); with the clearance, at most overlap_max attack
## windows overlap it, all of tolerated types (_overlap_ok), and the floor and its type's rules allow
## it (_floor_ok, _type_rules_ok); never before the level's first of its kind.
static func _encounter_fits(plan: Plan, probe: Dictionary) -> bool:
	var at: float = float(probe["at"])
	var k: Vector2 = attack_window(plan.gen, probe, plan.hooks)
	var window := Vector2(k.x - _clear(plan, k.x), k.y + _clear(plan, k.y))
	if window.x < plan.lo or window.y > plan.hi or not plan.fixed.clear(k.x, k.y):
		return false
	var none: Array[int] = []
	return _overlap_ok(plan, window, none) and _floor_ok(plan, probe, window) \
		and _type_rules_ok(plan, probe) and at > _first_at(plan, probe) + EPSILON


## Lever 2: new single encounters, until `target` enemies, swept through the stretches clear of fixed
## stretches and big attacks (_encounter_rooms) while a sweep still adds one. Returns how many it added.
static func _add_encounters(plan: Plan, target: int) -> int:
	var added: int = 0
	for _sweep: int in ENCOUNTER_SWEEPS:
		if enemy_count(plan.gen.layout) >= target:
			break
		var rooms: Array[Vector4] = _encounter_rooms(plan)
		_shuffle_vector4s(rooms, plan.rng)
		var placed: int = 0
		for room: Vector4 in rooms:
			if enemy_count(plan.gen.layout) >= target:
				break
			placed += _place_encounters(plan, room, target)
		added += placed
		if placed == 0:
			break
	return added


## Lever 2b: Barnacle Turrets (the tuning's ceiling_turrets), until `target` enemies: one under a
## ceiling the turret rules would hang one from (mount_lanes) and none did, then a second under a
## ceiling with one where the level pairs them (pair_share_at > 0, as the rules space and limit a pair),
## each in a spot the rules allow (off its ceiling's credits, off_credits), on ceilings after the one
## the level introduces the turret under. Seeds of their own, as the rules give theirs (add_enemy's
## running count stays the same). Returns how many it added.
static func _add_turrets(plan: Plan, target: int) -> int:
	var gen: LevelGenerator = plan.gen
	var layout: LevelLayout = gen.layout
	if not bool(plan.tuning.get("ceiling_turrets")) or enemy_count(layout) >= target \
			or not gen.config.has_feature(TURRET) or not ResourceLoader.exists(TURRET_RULES):
		return 0
	var rules := load(TURRET_RULES) as GDScript
	var t: Resource = rules.call("tuning")
	var scaling: float = gen.config.enemy_scaling
	# The introduction: the level's first turret, alone on its ceiling (Marketplace 1 meets it there).
	var intro: float = INF
	for e: Dictionary in layout.enemies:
		if String(e.get("type", "")) == TURRET:
			intro = minf(intro, float(e["at"]))
	if intro == INF:
		return 0
	var spacing: float = float(t.get("spacing_seconds")) * gen.speed
	var margin: float = float(t.get("credit_margin"))
	var pairs: bool = float(t.call("pair_share_at", scaling)) > 0.0
	var hulls: Array[Dictionary] = []
	for h: Dictionary in layout.hulls:
		if float(h["start"]) > intro + EPSILON:
			hulls.append(h)
	_shuffle_dicts(hulls, plan.rng)
	var added: int = 0
	# Bare ceilings first, then the second of a pair.
	for second: bool in [false, true]:
		if second and not pairs:
			break
		for h: Dictionary in hulls:
			if enemy_count(layout) >= target:
				return added
			var on: Array[Dictionary] = rules.call("turrets_on", layout, h)
			if on.size() != (1 if second else 0):
				continue
			var spots: Array[Dictionary] = rules.call("mount_lanes", gen, h, t)
			if spots.is_empty() or (second and spots.size() < 2):
				continue
			_shuffle_dicts(spots, plan.rng)
			for spot: Dictionary in spots:
				var lane: int = int(spot["lane"])
				var lo: float = maxf(float(spot["lo"]), intro + EPSILON)
				var hi: float = float(spot["hi"])
				if second:
					var first: Dictionary = on[0]
					if int(first["lane"]) == lane:
						continue
					var a: float = float(first["at"])
					var ranges: Array[Vector2] = []
					if hi >= maxf(lo, a + spacing):
						ranges.append(Vector2(maxf(lo, a + spacing), hi))
					if minf(hi, a - spacing) >= lo:
						ranges.append(Vector2(lo, minf(hi, a - spacing)))
					if ranges.is_empty():
						continue
					var r: Vector2 = ranges[plan.rng.randi_range(0, ranges.size() - 1)]
					lo = r.x
					hi = r.y
				if hi < lo:
					continue
				var at: float = float(rules.call("off_credits", layout, h, lane, plan.rng.randf_range(lo, hi),
					Vector2(lo, hi), margin))
				if is_nan(at):
					continue
				var lane_span: Vector2i = layout.hull_lanes(h)
				var entry: Dictionary = {"type": TURRET, "at": at, "lane": lane, "side": 0,
					"seed": hash([gen.config.level_seed, TURRET, "danger_density", added]),
					"params": {"hull_start": float(h["start"]), "hull_end": float(h["end"]),
						"first_lane": lane_span.x, "last_lane": lane_span.y}}
				layout.enemies.append(entry)
				plan.added.append(entry)
				added += 1
				break
	return added


## The playable track clear of every fixed stretch and of every attack window an addition may not
## overlap (_overlap_ok: a host's, a type's not tolerated), in chunks of ENCOUNTER_CHUNK_SECONDS:
## Vector4(chunk start, chunk end, its stretch's start, its stretch's end).
static func _encounter_rooms(plan: Plan) -> Array[Vector4]:
	var busy: Array[Vector2] = plan.fixed.vectors()
	# Both ends of a stretch the fill pass would fill stay empty for longer than it waits, so it still
	# fills either side of an encounter there.
	var wait: float = float(plan.tuning.get("spare_fill_seconds")) * plan.gen.speed + EPSILON
	for e: Vector2 in plan.fill_stretches:
		busy.append(Vector2(e.x, minf(e.x + wait, e.y)))
		busy.append(Vector2(maxf(e.y - wait, e.x), e.y))
	for i: int in plan.attacks.lo.size():
		var o: Dictionary = plan.gen.layout.enemies[plan.attacks.ids[i]]
		if not plan.tolerated.has(String(o.get("type", ""))) or _host(o):
			busy.append(Vector2(plan.attacks.lo[i], plan.attacks.hi[i]))
	var out: Array[Vector4] = []
	var chunk: float = ENCOUNTER_CHUNK_SECONDS * plan.gen.speed
	for room: Vector2 in LevelGenerator.free_stretches(busy, plan.lo, plan.hi):
		var pieces: int = maxi(ceili((room.y - room.x) / chunk), 1)
		var step: float = (room.y - room.x) / pieces
		for i: int in pieces:
			out.append(Vector4(room.x + step * i, room.x + step * (i + 1), room.x, room.y))
	return out


## Tries the tuning's encounter_tries random spots in `room` (a chunk of _encounter_rooms) for one of
## the level's single-enemy patterns of the tuning's types, picked by its weight where the level would
## pick it there (_picked_at), its attack window within the chunk's stretch, placed where it fits
## (_encounter_fits), until `target` enemies. Returns how many it placed.
static func _place_encounters(plan: Plan, room: Vector4, target: int) -> int:
	var gen: LevelGenerator = plan.gen
	var options: Dictionary = _encounter_options(plan, (room.x + room.y) * 0.5)
	var candidates: Array[Dictionary] = options["candidates"]
	var elements: Array[Dictionary] = options["elements"]
	var weights: Array[float] = options["weights"]
	if candidates.is_empty():
		return 0
	var placed: int = 0
	for _try: int in maxi(int(plan.tuning.get("encounter_tries")), 1):
		if enemy_count(gen.layout) >= target:
			break
		var index: int = _weighted(weights, plan.rng)
		var element: Dictionary = elements[index]
		var probe: Dictionary = _probe(String(element["type"]), room.x, 0, 0, _pattern_params(element.get("params", {})))
		if element.has("side"):
			var s: int = -1 if plan.rng.randf() < 0.5 else 1
			probe["side"] = s
			probe["lane"] = gen.layout.outer_lane(s)
		else:
			probe["lane"] = plan.rng.randi_range(0, plan.lanes - 1)
		# Where its attack window (from its warning on) stays within the stretch.
		var k: Vector2 = attack_window(gen, probe, plan.hooks)
		var from: float = maxf(room.x, room.z + room.x - k.x)
		var to: float = minf(room.y, room.w - (k.y - room.x))
		if to < from:
			continue
		probe["at"] = plan.rng.randf_range(from, to)
		if _encounter_fits(plan, probe) and _picked_at(plan, candidates[index], float(probe["at"])):
			_add_enemy(plan, probe)
			placed += 1
	return placed


## The level's single-enemy patterns of the tuning's types (_single_enemy) it would pick about track
## distance `at`, with their elements and weights: {candidates, elements, weights}, kept per stretch of
## ENCOUNTER_CHUNK_SECONDS (each probe is checked where it lands, _picked_at).
static func _encounter_options(plan: Plan, at: float) -> Dictionary:
	var key: int = floori(at / (ENCOUNTER_CHUNK_SECONDS * plan.gen.speed))
	if plan.encounter_options.has(key):
		return plan.encounter_options[key]
	var pool: Dictionary = _pool_at(plan, at, false)
	var candidates: Array[Dictionary] = []
	var elements: Array[Dictionary] = []
	var weights: Array[float] = []
	for i: int in (pool["patterns"] as Array).size():
		var element: Dictionary = _single_enemy(plan, pool["patterns"][i])
		if element.is_empty():
			continue
		candidates.append(pool["patterns"][i])
		elements.append(element)
		weights.append(float(pool["weights"][i]))
	var out: Dictionary = {"candidates": candidates, "elements": elements, "weights": weights}
	plan.encounter_options[key] = out
	return out


## The enemy element of `pattern` if it places just one enemy of the tuning's types (and maybe credits),
## needs nothing but those types and isn't a host; else {}.
static func _single_enemy(plan: Plan, pattern: Dictionary) -> Dictionary:
	if not _requires_ok(plan, pattern):
		return {}
	var out: Dictionary = {}
	for element: Dictionary in pattern.get("elements", []):
		var kind: String = String(element.get("kind", ""))
		if kind == "credits":
			continue
		if kind != "enemy" or not out.is_empty() or not _allowed(plan, element):
			return {}
		if element.has("side"):
			if String(element.get("side", "")) == "both":
				return {}
		elif LevelGenerator._selector_count(element.get("lanes", {"mode": "random", "count": 1}), plan.lanes, 0) != 1:
			return {}
		out = element
	return out


# --- Obstacles -----------------------------------------------------------------------------------

## `span` widened at both ends by the level's spacing there (clearance): as far as the pattern pass
## spaces two patterns (the fill pass adds FILL_TAIL_SECONDS more).
static func _margined(plan: Plan, span: Vector2) -> Vector2:
	return Vector2(span.x - _clear(plan, span.x), span.y + _clear(plan, span.y))


## Indexes the layout after the fill pass for the obstacle half: the rooms and row rooms, the kept lanes
## (pads', floor enemies', the rules'), every attack window and every row of holes or fences.
static func _index_obstacles(plan: Plan) -> void:
	var gen: LevelGenerator = plan.gen
	var layout: LevelLayout = gen.layout
	plan.fillers_at_spot = _fillers_at_spot(plan.patterns)
	var protections: Array[Vector2] = []
	for s: Vector2 in _fixed_stretches(plan):
		protections.append(_margined(plan, s))
	for s: Dictionary in layout.signs:
		protections.append(_margined(plan, Vector2(float(s["start"]), float(s["end"]))))
	protections.append_array(gen.quiet_stretches())
	# Task G7: each wider gap from its take-off margin to its landing margin (WideGapPlacement.keep_outs, placed
	# before the fill pass), as it stands: those margins are the level's spacing there already, so each stays the
	# only demand at its take-off and landing.
	protections.append_array(WideGapPlacement.keep_outs(gen))
	var strict: Array[Vector2] = []
	for q: Vector2 in gen.quiet_stretches():
		strict.append(_margined(plan, q))
	# A pad keeps its own lane clear (with the margin), as the pad rules do: a row beside it may still
	# move the player into the pad's lane before it (as the ceiling gauntlets' rows do).
	for p: Dictionary in layout.pads:
		var zone: Vector2 = _margined(plan, _pad_span(plan, p))
		var pad_lane: int = int(p.get("lane", -1))
		if pad_lane >= 0 and pad_lane < plan.lanes:
			plan.kept[pad_lane].add(zone.x, zone.y)
		else:
			strict.append(zone)
	var tolerated: PackedStringArray = plan.tuning.get("row_tolerated_types")
	var margin: float = _cyborg_margin(plan) + gen.tuning.fence_depth
	for i: int in layout.enemies.size():
		var e: Dictionary = layout.enemies[i]
		if String(e["type"]) == "cyborg":
			strict.append(Vector2(float(e["at"]) - margin, float(e["at"]) + margin))
		for w: Vector2 in attack_windows(gen, e, plan.hooks, plan.tuning):
			if w.y < w.x:
				continue
			plan.attacks.add(w.x, w.y, i)
			if not tolerated.has(String(e["type"])) or _host(e):
				protections.append(_margined(plan, w))
			for lane: int in _floor_lanes(plan, e):
				plan.kept[lane].add(w.x, w.y)
	_keep_rule_lanes(plan)
	plan.rooms = LevelGenerator.free_stretches(protections, plan.lo, plan.hi)
	for r: Vector2 in plan.rooms:
		plan.room_starts.append(r.x)
	protections.append_array(strict)
	for c: Vector2 in _plain_ceiling_keeps(plan):
		protections.append(_margined(plan, c))
	plan.row_rooms = LevelGenerator.free_stretches(protections, plan.lo, plan.hi)
	for r: Vector2 in plan.row_rooms:
		plan.row_room_starts.append(r.x)
	var config: LevelConfig = gen.config
	var seconds: float = maxf(config.quiet_spacing_seconds, config.burst_spacing_seconds) \
		if config.paced_in_bursts() else maxf(config.spacing_seconds_easy, config.spacing_seconds_hard)
	plan.reach = seconds * gen.speed * plan.scale + EPSILON
	var by_key: Dictionary = {}
	for g: Dictionary in layout.gaps:
		var key: Array = ["gap", float(g["start"]), float(g["end"])]
		if not by_key.has(key):
			by_key[key] = _new_row(plan, "gap", float(g["start"]), float(g["end"]), g)
		_index_piece(plan, by_key[key], int(g["lane"]))
	for f: Dictionary in layout.fences:
		var at: float = float(f["at"])
		var key: Array = ["fence", at]
		if not by_key.has(key):
			by_key[key] = _new_row(plan, "fence", at - plan.half, at + plan.half, f)
		var row: Dictionary = by_key[key]
		var proto: Dictionary = row["proto"]
		for field: String in ["variant", "pulsing", "pulse_on", "pulse_off"]:
			if proto.get(field) != f.get(field):
				row["mixed"] = true
		_index_piece(plan, row, int(f["lane"]))


## A new row of `kind` ("gap" or "fence") over [start, end], like piece `proto`, indexed by its span.
static func _new_row(plan: Plan, kind: String, start: float, end: float, proto: Dictionary) -> Dictionary:
	var lanes: Array[int] = []
	var row: Dictionary = {
		"id": plan.rows.size(), "kind": kind, "start": start, "end": end, "lanes": lanes, "proto": proto,
		"mixed": false, "order": plan.rng.randf(),
		"w": Vector2(start - _clear(plan, start), end + _clear(plan, end)),
		"room": _in_room(plan, start, end), "max_width": -1, "all": false,
	}
	plan.rows.append(row)
	plan.row_spans.add(start, end, int(row["id"]))
	return row


static func _index_piece(plan: Plan, row: Dictionary, lane: int) -> void:
	var lanes: Array[int] = row["lanes"]
	if lane < 0 or lane >= plan.lanes:
		return
	if not lanes.has(lane):
		lanes.append(lane)
	plan.lane_pieces[lane].add(float(row["start"]), float(row["end"]), int(row["id"]))


## A cyborg's obstacle margin at the level's pace (CyborgRules.obstacle_margin_at), or 0 without it.
static func _cyborg_margin(plan: Plan) -> float:
	if not ResourceLoader.exists(CYBORG_RULES):
		return plan.gen.metres(10.0)
	var rules := load(CYBORG_RULES) as GDScript
	var path: String = String(rules.get_script_constant_map().get("TUNING_PATH", ""))
	var t: Resource = load(path) if ResourceLoader.exists(path) else null
	return float(rules.call("obstacle_margin_at", t, plan.gen.pace)) if t != null else plan.gen.metres(10.0)


## True if nothing stands on the floor under ceiling (hull) `h`, from its lead-in to its landing zone's
## end: no hole, fence or floor enemy. A plain ceiling stays plain (City 2 shows one first, GDD §6).
static func _plain_ceiling(plan: Plan, h: Dictionary) -> bool:
	var layout: LevelLayout = plan.gen.layout
	var a: float = float(h["start"])
	var b: float = plan.gen.zones.landing_zone(h).y
	for g: Dictionary in layout.gaps:
		if float(g["start"]) < b and float(g["end"]) > a:
			return false
	for f: Dictionary in layout.fences:
		if float(f["at"]) + plan.half > a and float(f["at"]) - plan.half < b:
			return false
	for e: Dictionary in layout.enemies:
		if LevelGenerator.enemy_uses_floor(e):
			var w: Vector2 = LevelGenerator.enemy_floor_span(e, plan.gen.pace)
			if (w.y >= w.x and w.x < b and w.y > a) or (float(e["at"]) >= a and float(e["at"]) <= b):
				return false
	return true


## True if [a, b] lies in one of the rooms (clear of every protection with its margin).
static func _in_room(plan: Plan, a: float, b: float) -> bool:
	var i: int = plan.room_starts.bsearch(a, false) - 1
	return i >= 0 and plan.rooms[i].y >= b


## True if [a, b] lies in one of the row rooms (clear of every enemy's attack window too).
static func _in_row_room(plan: Plan, a: float, b: float) -> bool:
	var i: int = plan.row_room_starts.bsearch(a, false) - 1
	return i >= 0 and plan.row_rooms[i].y >= b


## The floor lanes enemy entry `e` attacks in: its lane, or for a wall enemy that uses the floor (a
## vent's Screech) the outer lane on its side. None for an enemy off the floor.
static func _floor_lanes(plan: Plan, e: Dictionary) -> Array[int]:
	var out: Array[int] = []
	if not LevelGenerator.enemy_uses_floor(e):
		return out
	var lane: int = int(e.get("lane", -1))
	var side: int = int(e.get("side", 0))
	if lane >= 0 and lane < plan.lanes:
		out.append(lane)
	elif side != 0:
		out.append(plan.gen.layout.outer_lane(side))
	return out


## The lanes of `row` could take, or that stay open around it: not in it, and clear of every piece and
## kept stretch over its window (the spacing before it to the spacing after it).
static func _avail(plan: Plan, row: Dictionary) -> Array[int]:
	var w: Vector2 = row["w"]
	var lanes: Array[int] = row["lanes"]
	var out: Array[int] = []
	for l: int in plan.lanes:
		if not lanes.has(l) and plan.lane_pieces[l].clear(w.x, w.y, int(row["id"])) and plan.kept[l].clear(w.x, w.y):
			out.append(l)
	return out


## True if pieces in `added` over [a, b] leave every other row whose window they reach (but row `own`)
## min_free_lanes open lanes, or take none of its open lanes (a row the level's data made without one).
static func _neighbors_ok(plan: Plan, a: float, b: float, added: Array[int], own: int) -> bool:
	for id: int in plan.row_spans.owners_in(a - plan.reach, b + plan.reach):
		if id == own:
			continue
		var row: Dictionary = plan.rows[id]
		var w: Vector2 = row["w"]
		if w.y <= a or w.x >= b:
			continue
		var left: int = 0
		var taken: int = 0
		for l: int in _avail(plan, row):
			if added.has(l):
				taken += 1
			else:
				left += 1
		if taken > 0 and left < plan.min_free:
			return false
	return true


## The one-row fillers the level would pick at track distance `at` (pick_weights with fill), placed
## from there: [{kind, variant, mode, width, weight, span, element}]. Only fillers of one hole or fence
## element, its lanes random, all but some or all, never pulsing (nothing the pass adds is a feature).
static func _filler_rows(plan: Plan, at: float) -> Array[Dictionary]:
	var gen: LevelGenerator = plan.gen
	var pool: Dictionary = _pool_at(plan, at, true)
	var out: Array[Dictionary] = []
	for i: int in (pool["patterns"] as Array).size():
		var elements: Array = (pool["patterns"][i] as Dictionary).get("elements", [])
		if elements.size() != 1:
			continue
		var element: Dictionary = elements[0]
		var kind: String = String(element.get("kind", ""))
		var selector: Dictionary = element.get("lanes", {})
		var mode: String = String(selector.get("mode", "random"))
		if not (kind in ["gap", "fence"]) or not (mode in ["random", "all_but", "all"]) \
				or float(element.get("pulse_chance", 0.0)) > 0.0:
			continue
		var spot: float = at + gen.metres(float(element.get("at", 0.0))) + float(element.get("at_seconds", 0.0)) * gen.speed
		var span := Vector2(spot - plan.half, spot + plan.half)
		if kind == "gap":
			span = Vector2(spot, spot + minf(float(element.get("jump_frac", 0.5)), gen.config.max_gap_jump_fraction)
				* gen.jump_distance)
		out.append({
			"kind": kind, "variant": String(element.get("variant", "full")) if kind == "fence" else "",
			"mode": mode, "width": LevelGenerator._selector_count(selector, plan.lanes, 0),
			"weight": float(pool["weights"][i]), "span": span, "element": element,
		})
	return out


## How wide `row` may grow: up to the widest of the level's one-row fillers of its piece at its spot
## that aren't full-width (row.max_width), and whether one of them is full-width (row.all).
static func _row_limits(plan: Plan, row: Dictionary) -> void:
	if int(row["max_width"]) >= 0:
		return
	var widest: int = 0
	var all: bool = false
	var variant: String = String((row["proto"] as Dictionary).get("variant", "full")) if row["kind"] == "fence" else ""
	for f: Dictionary in _filler_rows(plan, float(row["start"])):
		if f["kind"] != row["kind"] or String(f["variant"]) != variant:
			continue
		if f["mode"] == "all":
			all = true
		else:
			widest = maxi(widest, int(f["width"]))
	row["max_width"] = widest
	row["all"] = all


## Adds a piece of `row` in `lane`: a hole like its others, or a fence like its first (its own phase).
static func _add_piece(plan: Plan, row: Dictionary, lane: int) -> void:
	var layout: LevelLayout = plan.gen.layout
	if row["kind"] == "gap":
		layout.gaps.append(_uncredit(plan, {"lane": lane, "start": float(row["start"]), "end": float(row["end"])}))
	else:
		var f: Dictionary = (row["proto"] as Dictionary).duplicate(true)
		f["lane"] = lane
		f["phase"] = plan.rng.randf()
		layout.fences.append(_uncredit(plan, f))
	_index_piece(plan, row, lane)
	_touch(plan, row)


## `piece`, which the credit pass gives no risky credit unless the tuning's credit_added_pieces.
static func _uncredit(plan: Plan, piece: Dictionary) -> Dictionary:
	if not bool(plan.tuning.get("credit_added_pieces")):
		plan.gen.uncredited[piece] = true
	return piece


static func _touch(plan: Plan, row: Dictionary) -> void:
	var id: int = int(row["id"])
	if plan.touched_ids.has(id):
		plan.touched[int(plan.touched_ids[id])]["lanes"] = (row["lanes"] as Array).duplicate()
		return
	plan.touched_ids[id] = plan.touched.size()
	plan.touched.append({"kind": row["kind"], "start": row["start"], "end": row["end"],
		"lanes": (row["lanes"] as Array).duplicate()})


## Lever 3: one more lane for rows (see the header), until `target` floor pieces. Returns how many
## pieces it added.
static func _widen_rows(plan: Plan, target: int) -> int:
	var layout: LevelLayout = plan.gen.layout
	var added: int = 0
	var progress: bool = true
	while progress and floor_count(layout) < target:
		progress = false
		var candidates: Array[Dictionary] = []
		for row: Dictionary in plan.rows:
			if row["mixed"] or not row["room"]:
				continue
			_row_limits(plan, row)
			var width: int = (row["lanes"] as Array).size()
			if width + 1 <= mini(plan.lanes - plan.min_free, int(row["max_width"])):
				candidates.append(row)
		candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var wa: int = (a["lanes"] as Array).size()
			var wb: int = (b["lanes"] as Array).size()
			return wa < wb if wa != wb else float(a["order"]) < float(b["order"]))
		for row: Dictionary in candidates:
			if floor_count(layout) >= target:
				break
			var avail: Array[int] = _avail(plan, row)
			if avail.size() < 1 + plan.min_free:
				continue
			_shuffle(avail, plan.rng)
			for lane: int in avail:
				if _neighbors_ok(plan, float(row["start"]), float(row["end"]), _one(lane), int(row["id"])):
					_add_piece(plan, row, lane)
					added += 1
					progress = true
					break
	return added


## Lever 4: new one-row fillers on a grid through the rooms (the tuning's row_step_seconds), in a
## seeded order, until `target` floor pieces. Returns Vector2i(rows, pieces) added.
static func _add_rows(plan: Plan, target: int) -> Vector2i:
	var gen: LevelGenerator = plan.gen
	var step: float = maxf(float(plan.tuning.get("row_step_seconds")) * gen.speed, 1.0)
	var spots: Array[float] = []
	for room: Vector2 in plan.row_rooms:
		var x: float = room.x
		while x < room.y:
			spots.append(x)
			x += step
	_shuffle_floats(spots, plan.rng)
	var out := Vector2i.ZERO
	for x: float in spots:
		if floor_count(gen.layout) >= target:
			break
		if plan.dead_spots.has(x) or (plan.fillers_at_spot and not _spot_open(plan, x)):
			plan.dead_spots[x] = true
			continue
		var pieces: int = _place_row(plan, x)
		if pieces > 0:
			out += Vector2i(1, pieces)
		else:
			plan.dead_spots[x] = true
	return out


## True if a row from track distance `x` could leave min_free_lanes open lanes: one more lane than that
## clear of pieces and kept stretches over the spacing around `x` (a little less: every row's window
## holds it). Spares the filler pick (_filler_rows) where none could fit.
static func _spot_open(plan: Plan, x: float) -> bool:
	var reach: float = _clear(plan, x) * 0.9
	var free: int = 0
	for l: int in plan.lanes:
		if plan.lane_pieces[l].clear(x - reach, x + reach) and plan.kept[l].clear(x - reach, x + reach):
			free += 1
	return free >= 1 + plan.min_free


## True if every one-row filler among `patterns` (is_filler, one hole or fence element) places its
## piece at the spot it's placed from.
static func _fillers_at_spot(patterns: Array) -> bool:
	for p: Dictionary in patterns:
		var elements: Array = p.get("elements", [])
		if elements.size() != 1 or not LevelGenerator.is_filler(p):
			continue
		var element: Dictionary = elements[0]
		if float(element.get("at", 0.0)) != 0.0 or float(element.get("at_seconds", 0.0)) != 0.0:
			return false
	return true


## Places one of the level's one-row fillers from track distance `x` (_filler_rows, a weighted pick),
## if it fits (see the header). Returns how many pieces it placed.
static func _place_row(plan: Plan, x: float) -> int:
	var rows: Array[Dictionary] = _filler_rows(plan, x)
	var weights: Array[float] = []
	for r: Dictionary in rows:
		weights.append(float(r["weight"]))
	while not rows.is_empty():
		var index: int = _weighted(weights, plan.rng)
		var shape: Dictionary = rows[index]
		rows.remove_at(index)
		weights.remove_at(index)
		var span: Vector2 = shape["span"]
		if not _in_row_room(plan, span.x, span.y):
			continue
		var w := Vector2(span.x - _clear(plan, span.x), span.y + _clear(plan, span.y))
		var free: Array[int] = []
		for l: int in plan.lanes:
			if plan.lane_pieces[l].clear(w.x, w.y) and plan.kept[l].clear(w.x, w.y):
				free.append(l)
		var lanes: Array[int] = []
		if shape["mode"] == "all":
			if not bool(plan.tuning.get("full_width_rows")) or free.size() < plan.lanes \
					or not plan.attacks.clear(w.x, w.y) or not _neighbors_ok(plan, span.x, span.y, free, -1):
				continue
			lanes = free
		else:
			var width: int = mini(int(shape["width"]), plan.lanes - plan.min_free)
			if width < 1 or free.size() < width + plan.min_free:
				continue
			for _try: int in ROW_LANE_TRIES:
				_shuffle(free, plan.rng)
				var pick: Array[int] = []
				for i: int in width:
					pick.append(free[i])
				if _neighbors_ok(plan, span.x, span.y, pick, -1):
					lanes = pick
					break
			if lanes.is_empty():
				continue
		_add_row(plan, shape, span, lanes)
		return lanes.size()
	return 0


static func _add_row(plan: Plan, shape: Dictionary, span: Vector2, lanes: Array[int]) -> void:
	var layout: LevelLayout = plan.gen.layout
	var element: Dictionary = shape["element"]
	var proto: Dictionary = {}
	if shape["kind"] == "gap":
		proto = {"lane": lanes[0], "start": span.x, "end": span.y}
	else:
		proto = {
			"lane": lanes[0], "at": (span.x + span.y) * 0.5, "variant": String(shape["variant"]), "pulsing": false,
			"pulse_on": float(element.get("pulse_on", 1.2)), "pulse_off": float(element.get("pulse_off", 1.0)),
			"phase": 0.0,
		}
	var row: Dictionary = _new_row(plan, String(shape["kind"]), span.x, span.y, proto)
	lanes.sort()
	for lane: int in lanes:
		if shape["kind"] == "gap":
			layout.gaps.append(_uncredit(plan, {"lane": lane, "start": span.x, "end": span.y}))
		else:
			var f: Dictionary = proto.duplicate(true)
			f["lane"] = lane
			f["phase"] = plan.rng.randf()
			layout.fences.append(_uncredit(plan, f))
		_index_piece(plan, row, lane)
	_touch(plan, row)
	plan.gen._trim_clear_stretches(span)


## Lever 5: full rows (see the header), until `target` floor pieces. Returns how many it filled.
static func _fill_rows(plan: Plan, target: int) -> int:
	var gen: LevelGenerator = plan.gen
	var longest: float = gen.jump_distance * gen.config.max_gap_jump_fraction + 0.001
	var candidates: Array[Dictionary] = []
	for row: Dictionary in plan.rows:
		if row["mixed"] or (row["lanes"] as Array).size() != plan.lanes - 1 \
				or not _in_row_room(plan, float(row["start"]), float(row["end"])):
			continue
		if row["kind"] == "gap" and float(row["end"]) - float(row["start"]) > longest:
			continue
		_row_limits(plan, row)
		if row["all"]:
			candidates.append(row)
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["order"]) < float(b["order"]))
	var added: int = 0
	for row: Dictionary in candidates:
		if floor_count(gen.layout) >= target:
			break
		var w: Vector2 = row["w"]
		var lanes: Array[int] = row["lanes"]
		var missing: int = -1
		var alone: bool = true
		for l: int in plan.lanes:
			alone = alone and plan.lane_pieces[l].clear(w.x, w.y, int(row["id"])) and plan.kept[l].clear(w.x, w.y)
			if not lanes.has(l):
				missing = l
		alone = alone and plan.attacks.clear(w.x, w.y)
		if alone and missing >= 0 and _neighbors_ok(plan, float(row["start"]), float(row["end"]), _one(missing), int(row["id"])):
			_add_piece(plan, row, missing)
			added += 1
	return added


## Lever 6: staggered rows (see the header), until `target` floor pieces. Returns Vector2i(rows, pieces)
## added.
static func _stagger_rows(plan: Plan, target: int) -> Vector2i:
	var gen: LevelGenerator = plan.gen
	var out := Vector2i.ZERO
	var clusters: Array[Dictionary] = _clusters(plan)
	var pairs: Array[int] = []
	for i: int in range(clusters.size() - 1):
		pairs.append(i)
	_shuffle(pairs, plan.rng)
	var added := Spans.new()
	for i: int in pairs:
		if floor_count(gen.layout) >= target:
			break
		var pieces: int = _stagger_between(plan, clusters, i, added)
		if pieces > 0:
			out += Vector2i(1, pieces)
	return out


## The rows (plan.rows) as clusters of rows whose spans overlap (a hole and the fence a pattern puts in
## its open lane), sorted: [{lo, hi, lanes, fences}], `lanes` every lane a piece of theirs is in, `fences`
## false if one of them is a hole or mixes fences of different kinds (fence_mixed).
static func _clusters(plan: Plan) -> Array[Dictionary]:
	var rows: Array[Dictionary] = plan.rows.duplicate()
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["start"]) < float(b["start"]))
	var out: Array[Dictionary] = []
	for row: Dictionary in rows:
		var start: float = float(row["start"])
		var end: float = float(row["end"])
		var fence: bool = row["kind"] == "fence" and not bool(row["mixed"])
		if not out.is_empty() and start <= float(out[-1]["hi"]) + EPSILON:
			var last: Dictionary = out[-1]
			last["hi"] = maxf(float(last["hi"]), end)
			last["fences"] = bool(last["fences"]) and fence
			var lanes: Array[int] = last["lanes"]
			for l: int in row["lanes"]:
				if not lanes.has(l):
					lanes.append(l)
			continue
		var own: Array[int] = []
		for l: int in row["lanes"]:
			own.append(l)
		out.append({"lo": start, "hi": end, "lanes": own, "fences": fence})
	return out


## The staggered filler spacing at track distance `at`: the least clear track between two rows of a
## filler the level would pick there (pick_weights with fill) that places two or more rows of fences in
## random lanes one after another (fence_stagger), each row its own pick; -1 where it picks none.
static func _stagger_gap(plan: Plan, at: float) -> float:
	if plan.stagger_memo_on and plan.stagger_memo.has(at):
		return plan.stagger_memo[at]
	var gen: LevelGenerator = plan.gen
	var pool: Dictionary = _pool_at(plan, at, true)
	var out: float = -1.0
	for i: int in (pool["patterns"] as Array).size():
		if float(pool["weights"][i]) <= 0.0:
			continue
		var spots: Array[float] = []
		for element: Dictionary in (pool["patterns"][i] as Dictionary).get("elements", []):
			var selector: Dictionary = element.get("lanes", {})
			if String(element.get("kind", "")) != "fence" or String(selector.get("mode", "random")) != "random":
				spots.clear()
				break
			spots.append(gen.metres(float(element.get("at", 0.0))) + float(element.get("at_seconds", 0.0)) * gen.speed)
		if spots.size() < 2:
			continue
		spots.sort()
		for k: int in range(1, spots.size()):
			var gap: float = spots[k] - spots[k - 1] - 2.0 * plan.half
			if gap > EPSILON and (out < 0.0 or gap < out):
				out = gap
	if plan.stagger_memo_on:
		plan.stagger_memo[at] = out
	return out


## Tries a staggered row between clusters[i] and clusters[i + 1] (see the header and the tuning's
## staggered_rows): one of the level's one-row fence fillers there, at least the staggered filler's
## spacing from both, the clearance from every other row and every row this lever added (`added`), clear
## of every enemy's attack window, its open lanes reachable from the row before and to the row after
## within stagger_max_shift_lanes lane switches. Returns how many pieces it placed.
static func _stagger_between(plan: Plan, clusters: Array[Dictionary], i: int, added: Spans) -> int:
	var gen: LevelGenerator = plan.gen
	var p: Dictionary = clusters[i]
	var q: Dictionary = clusters[i + 1]
	if not bool(p["fences"]) or not bool(q["fences"]):
		return 0
	var mid: float = (float(p["hi"]) + float(q["lo"])) * 0.5
	var gap: float = _stagger_gap(plan, mid)
	if gap < 0.0:
		return 0
	var c: float = _clear(plan, mid)
	var lo: float = float(p["hi"]) + gap + plan.half
	var hi: float = float(q["lo"]) - gap - plan.half
	if i > 0:
		lo = maxf(lo, float(clusters[i - 1]["hi"]) + c + plan.half)
	if i + 2 < clusters.size():
		hi = minf(hi, float(clusters[i + 2]["lo"]) - c - plan.half)
	if hi < lo:
		return 0
	var shift: int = int(plan.tuning.get("stagger_max_shift_lanes"))
	if gap < shift * gen.tuning.lane_switch_time * gen.speed:
		shift = 0
	var at: float = plan.rng.randf_range(lo, hi)
	var shapes: Array[Dictionary] = []
	var weights: Array[float] = []
	for shape: Dictionary in _filler_rows(plan, at):
		var span: Vector2 = shape["span"]
		if shape["kind"] == "fence" and shape["mode"] != "all" \
				and span.x >= lo - plan.half - EPSILON and span.y <= hi + plan.half + EPSILON:
			shapes.append(shape)
			weights.append(float(shape["weight"]))
	if shapes.is_empty():
		return 0
	var pick: Dictionary = shapes[_weighted(weights, plan.rng)]
	var s: Vector2 = pick["span"]
	var whole := Vector2(minf(s.x - c, float(p["lo"])), maxf(s.y + c, float(q["hi"])))
	if not _in_row_room(plan, s.x, s.y) or not plan.attacks.clear(whole.x, whole.y) \
			or not added.clear(s.x - c, s.y + c):
		return 0
	var usable: Array[int] = []
	for l: int in plan.lanes:
		if plan.kept[l].clear(whole.x, whole.y):
			usable.append(l)
	var before: Array[int] = _open_lanes(usable, p["lanes"])
	var after: Array[int] = _open_lanes(usable, q["lanes"])
	if before.size() < plan.min_free or after.size() < plan.min_free:
		return 0
	var width: int = mini(int(pick["width"]), plan.lanes - plan.min_free)
	while width >= 1:
		var fits: Array = []
		for combo: Array[int] in _combos(usable, width):
			var open: Array[int] = _open_lanes(usable, combo)
			if open.size() >= plan.min_free and _reaches(before, open, shift) and _reaches(open, after, shift):
				fits.append(combo)
		if not fits.is_empty():
			var lanes: Array[int] = []
			lanes.assign(fits[plan.rng.randi_range(0, fits.size() - 1)])
			_add_row(plan, pick, s, lanes)
			added.add(s.x, s.y)
			return lanes.size()
		width -= 1
	return 0


## Lever 7: routed rows (see the header and the tuning's routed_rows), until `target` floor pieces: a
## row takes one more lane of the same piece, narrowest rows first, up to its widest filler there (as
## lever 3), in a lane clear of every other piece and kept stretch for the clearance either side, where
## the ground route holds (_routes_ok) though no lane stays open for the whole clearance around it.
## Returns how many pieces it added.
static func _route_rows(plan: Plan, target: int) -> int:
	var layout: LevelLayout = plan.gen.layout
	var keep: float = float(plan.tuning.get("routed_row_gap_seconds")) * plan.gen.speed
	var added: int = 0
	var progress: bool = true
	while progress and floor_count(layout) < target:
		progress = false
		var candidates: Array[Dictionary] = []
		for row: Dictionary in plan.rows:
			if row["mixed"] or not row["room"]:
				continue
			_row_limits(plan, row)
			var width: int = (row["lanes"] as Array).size()
			if width + 1 <= mini(plan.lanes - plan.min_free, int(row["max_width"])):
				candidates.append(row)
		candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var wa: int = (a["lanes"] as Array).size()
			var wb: int = (b["lanes"] as Array).size()
			return wa < wb if wa != wb else float(a["order"]) < float(b["order"]))
		for row: Dictionary in candidates:
			if floor_count(layout) >= target:
				break
			var avail: Array[int] = _avail(plan, row) if keep <= 0.0 else _route_avail(plan, row, keep)
			_shuffle(avail, plan.rng)
			var span := Vector2(float(row["start"]), float(row["end"]))
			var route: Dictionary = {} if avail.is_empty() else _route_chain(plan, span, int(row["id"]))
			for lane: int in avail:
				if _routes_ok(plan, span, _one(lane), int(row["id"]), route):
					_add_piece(plan, row, lane)
					added += 1
					progress = true
					break
	return added


## The lanes `row` could take as a routed row: not in it, clear of every other piece for `keep` either
## side and of every kept stretch over its window (the clearance either side).
static func _route_avail(plan: Plan, row: Dictionary, keep: float) -> Array[int]:
	var w: Vector2 = row["w"]
	var lanes: Array[int] = row["lanes"]
	var a: float = float(row["start"]) - keep
	var b: float = float(row["end"]) + keep
	var out: Array[int] = []
	for l: int in plan.lanes:
		if not lanes.has(l) and plan.lane_pieces[l].clear(a, b, int(row["id"])) and plan.kept[l].clear(w.x, w.y):
			out.append(l)
	return out


## Lever 7, new rows (see the header): one of the level's one-row fillers that isn't full-width, in the
## clear track between two neighbouring spots (_route_new_row), at least the tuning's
## routed_row_gap_seconds from each, in the row rooms, in lanes clear of kept stretches for the
## clearance around it, where the ground route holds (_routes_ok), in a seeded order, until `target`
## floor pieces; then again over the gaps those rows split, while any is still wide enough (a gap that
## took nothing only once a row lands near enough to change its route). Returns Vector2i(rows, pieces)
## added.
static func _route_new_rows(plan: Plan, target: int) -> Vector2i:
	var gen: LevelGenerator = plan.gen
	var out := Vector2i.ZERO
	var keep: float = float(plan.tuning.get("routed_row_gap_seconds")) * gen.speed
	if keep <= 0.0:
		return out
	var progress: bool = true
	var failed: Dictionary = {}
	while progress and floor_count(gen.layout) < target:
		progress = false
		var rows: Array[Dictionary] = plan.rows.duplicate()
		rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["start"]) < float(b["start"]))
		var spots: Array[Vector2] = []
		for row: Dictionary in rows:
			var s := Vector2(float(row["start"]), float(row["end"]))
			if not spots.is_empty() and s.x <= spots[-1].y + EPSILON:
				spots[-1].y = maxf(spots[-1].y, s.y)
			else:
				spots.append(s)
		var order: Array[int] = []
		for i: int in range(spots.size() - 1):
			var gap: float = spots[i + 1].x - spots[i].y
			if gap >= 2.0 * keep:
				order.append(i)
		_shuffle(order, plan.rng)
		for i: int in order:
			if floor_count(gen.layout) >= target:
				break
			var between := Vector2(spots[i].y, spots[i + 1].x)
			var key := Vector2i(roundi(between.x * 100.0), roundi(between.y * 100.0))
			if failed.has(key):
				continue
			var pieces: int = _route_new_row(plan, between.x, between.y, keep)
			if pieces == 0:
				failed[key] = between
				continue
			out += Vector2i(1, pieces)
			progress = true
			# A gap that took nothing is tried again once a row lands near enough to change its route.
			var near: float = 2.0 * _clear(plan, between.x)
			for k: Vector2i in failed.keys():
				var g: Vector2 = failed[k]
				if g.y > between.x - near and g.x < between.y + near:
					failed.erase(k)
	return out


## Places one routed new row between track distances `a` and `b` (_route_new_rows), `keep` from each, if
## one fits. Returns how many pieces it placed.
static func _route_new_row(plan: Plan, a: float, b: float, keep: float) -> int:
	var mid: float = (a + b) * 0.5
	var shapes: Array[Dictionary] = _filler_rows(plan, mid)
	var weights: Array[float] = []
	for r: Dictionary in shapes:
		weights.append(float(r["weight"]))
	while not shapes.is_empty():
		var index: int = _weighted(weights, plan.rng)
		var shape: Dictionary = shapes[index]
		shapes.remove_at(index)
		weights.remove_at(index)
		if shape["mode"] == "all":
			continue
		var length: float = (shape["span"] as Vector2).y - (shape["span"] as Vector2).x
		# Centred, else as near either spot as `keep` lets it (the far one then may stand the clearance
		# off, where any lane may follow).
		for x: float in [mid - length * 0.5, a + keep, b - keep - length]:
			var span := Vector2(x, x + length)
			if span.x - a < keep - EPSILON or b - span.y < keep - EPSILON or not _in_row_room(plan, span.x, span.y):
				continue
			var c: float = _clear(plan, span.x)
			var free: Array[int] = []
			for l: int in plan.lanes:
				if plan.lane_pieces[l].clear(span.x - keep, span.y + keep) and plan.kept[l].clear(span.x - c, span.y + c):
					free.append(l)
			var route: Dictionary = {} if free.is_empty() else _route_chain(plan, span, -1)
			for width: int in range(mini(int(shape["width"]), plan.lanes - plan.min_free), 0, -1):
				var combos: Array[Array] = _combos(free, width)
				var picks: Array[int] = []
				for k: int in combos.size():
					picks.append(k)
				_shuffle(picks, plan.rng)
				for k: int in picks:
					var lanes: Array[int] = []
					lanes.assign(combos[k])
					if _routes_ok(plan, span, lanes, -1, route):
						_add_row(plan, shape, span, lanes)
						return lanes.size()
	return 0


## True if pieces in `lanes` over `span` (of row `own`, or of a new row with -1) keep the ground route
## (lever 7): the spot they join (every row whose span touches theirs, as _clusters joins them) keeps
## min_free_lanes lanes no piece stands in, clear of kept stretches for the clearance around it, and
## through the run of spots each less than the clearance from the next around it (a player coming from
## further back may take any lane, as between two of the level's patterns) a lane stays reachable at
## every spot from a lane open at the spot before (_route_lanes lane switches), min_free_lanes at theirs,
## and a full row (no lane free of pieces) is passed in the lane it's come to in, with no lane switch
## during its jump or slide (_full_row_shift).
static func _routes_ok(plan: Plan, span: Vector2, lanes: Array[int], own: int, route: Dictionary = {}) -> bool:
	if route.is_empty():
		route = _route_chain(plan, span, own)
	var unchanged: Dictionary = route["unchanged"]
	var spot: Dictionary = unchanged.duplicate()
	var blocked: Array[int] = (unchanged["blocked"] as Array[int]).duplicate()
	for l: int in lanes:
		if not blocked.has(l):
			blocked.append(l)
	spot["blocked"] = blocked
	var open_index: Array[int] = _spot_open_lanes(plan, spot, true)
	if open_index.size() < plan.min_free:
		return false
	# `before` follows the same spots without the new pieces (a new row's spot left out). Where the
	# data's own spots already leave no lane this model reaches (a passage the level's patterns made,
	# passed as they intend: a jump over a fence, two lane switches), both start afresh from the spot's
	# open lanes, unless the new pieces stand in that passage or narrowed the lanes coming into it: the
	# model can't tell they leave the level's own way through. A full row (no lane free of pieces: jumped
	# or slid in every lane) is passed in the lane the player comes to it in, so it carries their lanes
	# on, and its jump or slide takes its length of ground from the lane switches either side
	# (_full_row_shift). Once past the spot both walks hold the same lanes, the rest is the level's own.
	# The walk up to their spot doesn't depend on `lanes`: _route_walk keeps it with the chain.
	var start: Dictionary = _route_walk(plan, route, route["index"])
	if not bool(start["ok"]):
		return false
	return bool(_route_walk(plan, route, -1, start, open_index)["ok"])


## True if a zone doodad from `start` to `end` in `lane` keeps the ground route the pass's pieces left
## (LevelGenerator._add_doodad asks, with the obstacle half's plan kept for it, gen.danger_density_plan).
## Doodads come after the pass, where nothing else goes on in any lane, but a doodad is never jumped or
## stood beside in its lane: where the pass's pieces route the player into a lane (a full row passed in
## the lane they come to it in), a doodad right after them in that lane would leave no way on. So
## wherever the run of spots around it (_route_chain, the doodad's own stretch DOODAD_ROUTE_MARGIN
## wider) holds a row the pass touched, the walk (_route_walk, the lane switches either side of it as
## many as fit) must pass it in another lane; elsewhere the level's own rules place it, as without the
## pass.
static func doodad_ok(gen: LevelGenerator, lane: int, start: float, end: float) -> bool:
	var plan: Plan = gen.danger_density_plan as Plan
	if plan == null:
		return true
	var span := Vector2(start - DOODAD_ROUTE_MARGIN, end + DOODAD_ROUTE_MARGIN)
	var route: Dictionary = _route_chain(plan, span, -1)
	var chain: Array[Dictionary] = route["spots"]
	var touched: bool = false
	for id: int in plan.row_spans.owners_in(float(chain[0]["lo"]) - EPSILON, float(chain[-1]["hi"]) + EPSILON):
		if plan.touched_ids.has(id):
			touched = true
			break
	if not touched:
		return true
	var open_index: Array[int] = []
	for l: int in plan.lanes:
		if l != lane:
			open_index.append(l)
	var none: Array[int] = []
	var walk: Dictionary = _route_walk(plan, route, route["index"], {}, none, true)
	if not bool(walk["ok"]):
		return false
	return bool(_route_walk(plan, route, -1, walk, open_index, true)["ok"])


## A route check's walk (_routes_ok) along `route`'s spots (_route_chain): up to (not into) spot `upto`
## from the start, or with `upto` -1 on from where walk `from` stopped to the end, `open_index` the
## changed spot's lanes. With `switch_around` the lane switches into and out of the changed spot are as
## many as fit in the clear track there (a zone doodad's, doodad_ok), not only _route_shift's. Returns
## {ok, k (where it stopped), reach, before, passage_from, reach_from}.
static func _route_walk(plan: Plan, route: Dictionary, upto: int, from: Dictionary = {},
		open_index: Array[int] = [], switch_around: bool = false) -> Dictionary:
	if upto >= 0 and route.has("walk"):
		return route["walk"]
	var chain: Array[Dictionary] = route["spots"]
	var index: int = route["index"]
	var fulls: Array[bool] = route["full"]
	var opens: Array = route["open"]
	var unchanged: Dictionary = route["unchanged"]
	var new_row: bool = route["new_row"]
	var reach: Dictionary = _route_state() if from.is_empty() else (from["reach"] as Dictionary).duplicate()
	var before: Dictionary = _route_state() if from.is_empty() else (from["before"] as Dictionary).duplicate()
	var passage_from: int = -1 if from.is_empty() else int(from["passage_from"])
	var reach_from: int = -1 if from.is_empty() else int(from["reach_from"])
	var out: Dictionary = {"ok": true}
	for k: int in range(0 if from.is_empty() else int(from["k"]), chain.size() if upto < 0 else upto):
		var s: Dictionary = chain[k]
		var lo: float = float(s["lo"])
		var hi: float = float(s["hi"])
		if fulls[k]:
			_route_full(plan, reach, lo, hi)
			_route_full(plan, before, lo, hi)
			continue
		var open: Array[int] = open_index if k == index else opens[k]
		var came: Array[int] = reach["lanes"]
		var lanes_now: Array[int] = _route_next(plan, reach, lo, hi, open,
			switch_around or (k != index and reach_from != index))
		reach_from = k
		if k == index and new_row:
			reach["lanes"] = lanes_now
			if lanes_now.size() < plan.min_free:
				out["ok"] = false
				break
			continue
		var open_before: Array[int] = _spot_to(plan, unchanged) if k == index else open
		var came_before: Array[int] = before["lanes"]
		var lanes_before: Array[int] = _route_next(plan, before, lo, hi, open_before, true)
		if lanes_before.is_empty():
			if k >= index and (passage_from <= index or not _same_lanes(came, came_before)):
				out["ok"] = false
				break
			lanes_now = open
			lanes_before = open_before
		reach["lanes"] = lanes_now
		before["lanes"] = lanes_before
		passage_from = k
		if lanes_now.size() < (plan.min_free if k == index else 1):
			out["ok"] = false
			break
		if k > index and _same_lanes(lanes_now, lanes_before):
			break
	if upto >= 0:
		out.merge({"k": upto, "reach": reach, "before": before, "passage_from": passage_from,
			"reach_from": reach_from})
		route["walk"] = out
	return out


## The run of spots a route check (_routes_ok) follows around pieces over `span` (of row `own`, or of a
## new row with -1), whichever lanes they take: {spots, index (theirs), unchanged (their spot without
## them), new_row, full and open (each spot's, as _routes_ok walks them)}.
static func _route_chain(plan: Plan, span: Vector2, own: int) -> Dictionary:
	var none: Array[int] = []
	var unchanged: Dictionary = _spot(plan, span, none, own)
	var chain: Array[Dictionary] = [unchanged]
	var at: Dictionary = unchanged
	while chain.size() < ROUTE_SPOTS_MAX:
		at = _spot_near(plan, float(at["lo"]), -1)
		if at.is_empty():
			break
		chain.push_front(at)
	var index: int = chain.size() - 1
	at = unchanged
	while chain.size() < 2 * ROUTE_SPOTS_MAX:
		at = _spot_near(plan, float(at["hi"]), 1)
		if at.is_empty():
			break
		chain.append(at)
	var full: Array[bool] = []
	var open: Array = []
	for k: int in chain.size():
		var f: bool = k != index and _spot_open_lanes(plan, chain[k], false).is_empty()
		full.append(f)
		open.append(none if f or k == index else _spot_to(plan, chain[k]))
	return {"spots": chain, "index": index, "unchanged": unchanged, "new_row": (unchanged["blocked"] as Array).is_empty(),
		"full": full, "open": open}


## A route check's walk along its spots (_routes_ok): the lanes a player may be in at the last spot with
## an open lane, where it ends (`hi`), and the full rows since it (`full`, empty while x > y).
static func _route_state() -> Dictionary:
	var lanes: Array[int] = []
	return {"lanes": lanes, "hi": -INF, "full": Vector2(INF, -INF), "started": false}


## A full row over lo..hi in a route check's walk: passed in the lanes the player has (every lane before
## the first spot).
static func _route_full(plan: Plan, state: Dictionary, lo: float, hi: float) -> void:
	var full: Vector2 = state["full"]
	state["full"] = Vector2(minf(full.x, lo), maxf(full.y, hi))
	if not bool(state["started"]):
		state["lanes"] = _every_lane(plan)
		state["started"] = true


## The lanes of `open` (a spot over lo..hi) a route check's walk reaches from its last spot, past the
## full rows between; moves the walk on to the spot (its lanes are the caller's to set).
static func _route_next(plan: Plan, state: Dictionary, lo: float, hi: float, open: Array[int],
		own: bool) -> Array[int]:
	var out: Array[int] = open
	if bool(state["started"]):
		var full: Vector2 = state["full"]
		var shift: int = _route_lanes(plan, lo - float(state["hi"]), lo, own) if full.x > full.y \
			else _full_row_shift(plan, float(state["hi"]), full, lo, own)
		out = _shifted(state["lanes"], open, shift)
	state["hi"] = hi
	state["full"] = Vector2(INF, -INF)
	state["started"] = true
	return out


static func _same_lanes(a: Array[int], b: Array[int]) -> bool:
	if a.size() != b.size():
		return false
	for l: int in a:
		if not b.has(l):
			return false
	return true


## The most lanes the open lane may move between a spot ending at `from_hi` and one starting at `to_lo`
## with the full rows over `full` between them: the jump or slide that passes them (the longer of the
## two, or the rows' own length, with FULL_ROW_MARGIN either side) is taken in one lane, and lane
## switches fit in the ground on one side of it (_route_lanes), wherever along it the player takes it.
static func _full_row_shift(plan: Plan, from_hi: float, full: Vector2, to_lo: float, own: bool) -> int:
	var gen: LevelGenerator = plan.gen
	var action: float = maxf(maxf(gen.jump_distance, gen.tuning.slide_duration * gen.speed), full.y - full.x) \
		+ 2.0 * FULL_ROW_MARGIN
	var lead: float = minf(full.x - FULL_ROW_MARGIN, to_lo - action) - from_hi
	var trail: float = to_lo - maxf(from_hi, full.y + FULL_ROW_MARGIN - action) - action
	return maxi(_route_lanes(plan, lead, full.x, own), _route_lanes(plan, trail, to_lo, own))


static func _every_lane(plan: Plan) -> Array[int]:
	var out: Array[int] = []
	for l: int in plan.lanes:
		out.append(l)
	return out


## The lanes of `to` within `shift` lanes of one of `from`.
static func _shifted(from: Array[int], to: Array[int], shift: int) -> Array[int]:
	var out: Array[int] = []
	for l: int in to:
		for a: int in from:
			if absi(a - l) <= shift:
				out.append(l)
				break
	return out


## The spot pieces in `lanes` over `span` (of row `own`, or -1) stand in: {lo, hi, blocked, ids}, grown
## by every row whose span touches it until none more does.
static func _spot(plan: Plan, span: Vector2, lanes: Array[int], own: int) -> Dictionary:
	var lo: float = span.x
	var hi: float = span.y
	var blocked: Array[int] = lanes.duplicate()
	var seen: Dictionary = {}
	var grew: bool = true
	if own >= 0:
		seen[own] = true
		for l: int in plan.rows[own]["lanes"]:
			if not blocked.has(l):
				blocked.append(l)
	while grew:
		grew = false
		for id: int in plan.row_spans.owners_in(lo - EPSILON, hi + EPSILON):
			if seen.has(id):
				continue
			seen[id] = true
			grew = true
			var row: Dictionary = plan.rows[id]
			lo = minf(lo, float(row["start"]))
			hi = maxf(hi, float(row["end"]))
			for l: int in row["lanes"]:
				if not blocked.has(l):
					blocked.append(l)
	return {"lo": lo, "hi": hi, "blocked": blocked}


## The nearest spot wholly before track distance `x` (`dir` -1) or after it (1), within the clearance
## there; {} if none.
static func _spot_near(plan: Plan, x: float, dir: int) -> Dictionary:
	var c: float = _clear(plan, x)
	var best: int = -1
	var best_gap: float = INF
	var ids: PackedInt32Array = plan.row_spans.owners_in(x - c, x) if dir < 0 else plan.row_spans.owners_in(x, x + c)
	for id: int in ids:
		var row: Dictionary = plan.rows[id]
		var gap: float = x - float(row["end"]) if dir < 0 else float(row["start"]) - x
		if gap >= EPSILON and gap < best_gap:
			best_gap = gap
			best = id
	if best < 0:
		return {}
	var row: Dictionary = plan.rows[best]
	var none: Array[int] = []
	return _spot(plan, Vector2(float(row["start"]), float(row["end"])), none, best)


## The lanes no piece of `spot` stands in; if `strict`, also clear of every kept stretch for the
## clearance either side.
static func _spot_open_lanes(plan: Plan, spot: Dictionary, strict: bool) -> Array[int]:
	var lo: float = float(spot["lo"])
	var hi: float = float(spot["hi"])
	var w := Vector2(lo - _clear(plan, lo), hi + _clear(plan, hi))
	var blocked: Array[int] = spot["blocked"]
	var out: Array[int] = []
	for l: int in plan.lanes:
		if not blocked.has(l) and (not strict or plan.kept[l].clear(w.x, w.y)):
			out.append(l)
	return out


## Every lane a player may be in at `spot`: its open lanes, or every lane over a full row (jumped).
static func _spot_from(plan: Plan, spot: Dictionary) -> Array[int]:
	var out: Array[int] = _spot_open_lanes(plan, spot, false)
	if out.is_empty():
		for l: int in plan.lanes:
			out.append(l)
	return out


## The lanes a player may pass `spot` in: its open lanes clear of kept stretches, else its open lanes,
## else every lane (a full row, jumped).
static func _spot_to(plan: Plan, spot: Dictionary) -> Array[int]:
	var out: Array[int] = _spot_open_lanes(plan, spot, true)
	return out if not out.is_empty() else _spot_from(plan, spot)


## The most lanes the open lane may move over `gap` of clear track before track distance `at`: any at
## the clearance (the level's spacing between two patterns, whose lanes it picks afresh); the tuning's
## stagger_max_shift_lanes from the staggered filler's spacing there (fence_stagger, _stagger_gap) if
## those lane switches fit; none (the same lane straight on) closer.
static func _route_shift(plan: Plan, gap: float, at: float) -> int:
	if gap >= _clear(plan, at) - EPSILON:
		return plan.lanes
	var shift: int = int(plan.tuning.get("stagger_max_shift_lanes"))
	var stagger: float = _stagger_gap(plan, at)
	if stagger < 0.0 or gap < stagger - EPSILON or gap < shift * plan.gen.tuning.lane_switch_time * plan.gen.speed:
		return 0
	return shift


## The lanes the open lane may move over `gap` of clear track before `at` in a route check: between
## two of the level's own spots (`own`: neither the changed one), also as many as the player can switch
## there (lane_switch_time each, ROUTE_SWITCH_SLACK and FULL_ROW_MARGIN at either end), as the level's
## own patterns may ask; next to the changed spot only _route_shift's.
static func _route_lanes(plan: Plan, gap: float, at: float, own: bool) -> int:
	var shift: int = _route_shift(plan, gap, at)
	if not own:
		return shift
	var per: float = plan.gen.tuning.lane_switch_time * plan.gen.speed + ROUTE_SWITCH_SLACK
	return clampi(maxi(shift, int(floor((gap - 2.0 * FULL_ROW_MARGIN) / per))), 0, plan.lanes)


## The lanes of `usable` not in `taken`.
static func _open_lanes(usable: Array[int], taken: Array) -> Array[int]:
	var out: Array[int] = []
	for l: int in usable:
		if not taken.has(l):
			out.append(l)
	return out


## Every set of `width` lanes from `lanes`, in order.
static func _combos(lanes: Array[int], width: int) -> Array[Array]:
	var out: Array[Array] = []
	if width <= 0 or width > lanes.size():
		return out
	var index: Array[int] = []
	for k: int in width:
		index.append(k)
	while true:
		var combo: Array[int] = []
		for k: int in index:
			combo.append(lanes[k])
		out.append(combo)
		var k: int = width - 1
		while k >= 0 and index[k] == lanes.size() - width + k:
			k -= 1
		if k < 0:
			break
		index[k] += 1
		for m: int in range(k + 1, width):
			index[m] = index[m - 1] + 1
	return out


## True if from every lane of `from` a lane of `to` is at most `shift` lanes away.
static func _reaches(from: Array[int], to: Array[int], shift: int) -> bool:
	for a: int in from:
		var ok: bool = false
		for b: int in to:
			if absi(a - b) <= shift:
				ok = true
				break
		if not ok:
			return false
	return true


static func _one(lane: int) -> Array[int]:
	var out: Array[int] = [lane]
	return out


# --- Random helpers (the pass's own streams) ------------------------------------------------------

static func _weighted(weights: Array[float], rng: RandomNumberGenerator) -> int:
	var total: float = 0.0
	for w: float in weights:
		total += w
	var roll: float = rng.randf() * total
	for i: int in weights.size():
		roll -= weights[i]
		if roll <= 0.0:
			return i
	return weights.size() - 1


static func _shuffle(values: Array[int], rng: RandomNumberGenerator) -> void:
	for i: int in range(values.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: int = values[i]
		values[i] = values[j]
		values[j] = tmp


static func _shuffle_floats(values: Array[float], rng: RandomNumberGenerator) -> void:
	for i: int in range(values.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: float = values[i]
		values[i] = values[j]
		values[j] = tmp


static func _shuffle_dicts(values: Array[Dictionary], rng: RandomNumberGenerator) -> void:
	for i: int in range(values.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Dictionary = values[i]
		values[i] = values[j]
		values[j] = tmp


static func _shuffle_vector4s(values: Array[Vector4], rng: RandomNumberGenerator) -> void:
	for i: int in range(values.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Vector4 = values[i]
		values[i] = values[j]
		values[j] = tmp
