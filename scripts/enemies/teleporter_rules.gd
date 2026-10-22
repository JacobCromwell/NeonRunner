extends RefCounted
## Generator rules for teleporters (task Q4; GDD §5, Zone 9, the owner, October 21, 2026): "a teleporter is a square pad
## with a look all its own, with a green, slightly space-age antenna on it. Touching it teleports the runner to an output
## pad further down the track"; "think ahead: the player has to work out where it leads before touching it, or it can put
## them in harm's way. The first teleporter is safe, to teach the mechanic; later output pads may sit right in front of a
## gap or an enemy, and the player has to react quickly"; "some teleporters have a left and a right output pad. A light on
## the antenna, on its left or its right side, shows which one the runner lands on"; "some antennas' light stays on one
## side, always left or always right. Others blink left and right, and the side lit when the runner touches the pad
## decides where they land. Level 2 has fixed antennas; level 3 adds blinking ones". GDD §5's proposals: the pad fills one
## floor lane and is taken by running onto it; it is never required (the way around it is always survivable); the output
## pads stand within sight ahead, in the teleporter's look without the antenna; the runner keeps their speed and arrives
## running in the output pad's lane and skips the track in between and whatever it holds; no protection after landing, but
## never a landing straight into a hazard: a gap or an enemy in front leaves at least the usual time to react. Not an enemy:
## a set piece of the track with no patterns, placed with the rules (as the falling gantryways are) so the level makes room
## for it before it fills up. Its pads, its antenna's light and the jump are the track's and the player's (Teleporter,
## scripts/world/teleporter.gd; Player._teleport); its numbers are TeleporterTuning's (data/tuning/teleporters.tres); how
## many a level asks for is LevelConfig.teleporters, and of those how many blink LevelConfig.blinking_teleporters (with the
## `teleporter_blinking` feature, teleporter_blinking_rules.gd).
##
## A teleporter in lane P, its pad's front at T, its output pads' fronts at L = T + D (Plan; every window as seconds at the
## level's run speed, or at the fastest a runner comes onto a pad, `fastest`: the run speed, the dash's bonus and the most
## a speed pad's or a ramp's fading boost adds, so a faster zone keeps every one of them):
## - P is an inner lane (never by a side wall: a wall run that ends there never drops its runner onto the pad), and the
##   lane beside it on its `side` is the way around it: both hold nothing (no hole, fence, pad's zone, speed pad, ramp's
##   run, floor cut's lane window, doodad, floor enemy, or a lane another rule keeps) from `approach` before T to a lane
##   switch's room past the pad (its pad stretch). No ceiling's landing zone reaches either lane from `approach` before T
##   to the pad's far end (a rider dropping off a ceiling never lands on the pad unawares; a ceiling over the pad is no
##   matter: its rider passes over it). So it's never required: a runner who doesn't want it switches out of its lane.
## - D is one of the tuning's hops (hop_seconds_min to hop_seconds_max of run): the output pads stand within sight ahead and
##   within the track built ahead (TrackBuilder.BUILD_AHEAD) as the runner lines the pad up.
## - Its output pads: one, or a left and a right one (the left first) at least output_lane_gap lanes apart (fewer where the
##   track hasn't the lanes), both at L. Each one's lane holds nothing from LANDING_BACK before L to `landing` past it
##   (landing_seconds at the fastest: the usual time to react, GDD §5's proposal), and the lanes beside it no doodad or floor
##   enemy for a lane switch's room past L (the runner can switch out at once). Past that, what the level holds is there:
##   a later one prefers output pads with a hole, a fence or a floor enemy in their lane within prefer_hazard_seconds past
##   that (GDD §5: "later output pads may sit right in front of a gap or an enemy").
## - Every lane keeps, over the pad stretch and over each landing (from LANDING_BACK before L to `landing` past it), no
##   floor cut's window, dash wall, debris maze block, wall-run gap's stretch (WallRunGapPlacement.keep_out: its own
##   re-check counts every rule's keep-outs in every lane), falling gantryway (its pillar's lead to past its walkway and its
##   calm stretch), Octodog's planned charge, nor what the rules keep in every lane (a Bad Dream's chase, a treasure
##   stash's floor, an Enforcer Truck's showing window): nothing that holds the track around the runner is under way as
##   they touch the pad or arrive. Every enemy that holds an attack by a doodad holds it by a teleporter's calm stretches
##   too (LevelLayout.doodad_between, teleporter_between: its approach in P, each landing in its output pad's lane): no
##   bolt, lunge or barrage is timed onto a runner lining the pad up or just arrived, on every attempt. (What else is in
##   play as they jump is the run world's to settle: EnemyDirector.runner_teleported leaves behind what's behind the landing,
##   brings a heli drone along, and calls off any attack whose warning began before the jump.)
## - Its light (`light`, `blink`, `phase`): one output pad has none to choose (`light` 0); two have a fixed light on one
##   side (seeded), or with the `teleporter_blinking` feature a blinking one (blink_seconds a side, from a seeded side and
##   phase on the level clock), whose side lit at the touch decides. Either output pad may be taken, so both keep the rules.
## - The introduction (the level's first where it gives the feature a start: Relay Station; GDD §5: "the first teleporter is
##   safe"): one output pad, straight ahead in P, its lane holding nothing for intro_landing_seconds past it and no enemy
##   using the floor in any lane meanwhile, and no attack landing there in any lane. The first blinking one where the level
##   gives `teleporter_blinking` a start (Specimen Vault) keeps both its landings that safe. Each within
##   intro_window_seconds of its start (test_campaign's introduction reach), where the level has room.
## - Within the level: the pad's approach past the run-up (and past the feature's start; a blinking one past the blinking
##   feature's), the last landing before the end-clear stretch; pads spacing_seconds apart.
## Plain holes and fences in those windows (never a pulsing fence, one a fence generator powers, or a wall-run gap's hole)
## are taken out to make room where clear_plain_pieces allows (taking content out never makes a level unfair); a spot that
## needs nothing taken out is preferred.
##
## How many, and where: up to LevelConfig.teleporters, of which LevelConfig.blinking_teleporters blink in a level with
## `teleporter_blinking`. The introductions first, then the rest spread through the level past them (a part each, a seeded
## spot aimed for in the part, the best fair spot there: a blinking one only past the blinking start), then the best of
## the rest. Among the fixed ones past the introduction, the first has two output pads (so a level that brings fixed
## antennas in shows one's light) and each other one with two_output_share. Its own random stream
## (LevelGenerator.rng_for), after every other feature's rules (RUN_AFTER), so the passes before it place exactly what they
## did; a level without the feature draws nothing and is built byte for byte as before.
##
## What keeps off them after the rules (doodad_keep_outs, fill_keep_outs): the pad stretch and each landing in every lane
## (the danger density pass, the wider gaps, the cyborgs planted in charge paths, the fill pass and the zone doodads), and P,
## the side lane, the output lanes and the lanes beside them as above; the credits keep out of the calm stretches
## (LevelLayout.doodad_between). problems() re-checks a finished layout (LayoutChecks.check_teleporters).
## DESIGN-TBD (docs/questions/q4.md): every number, inner lanes only, the way around, the windows, the introductions.

const FEATURE: String = "teleporter"
## The blinking antennas' feature (Specimen Vault; teleporter_blinking_rules.gd answers where they are).
const BLINKING: String = "teleporter_blinking"
## Every feature whose rules place, move or drop enemies, plan charges or cuts, or add ceilings, pads, ramps or set
## pieces: the teleporters are planned on the level's final rules track, the falling gantryways' included.
const RUN_AFTER: Array[String] = ["ramps", "ceilings", "pulsing", "speed_pads", "cyborg", "window_cyborg", "host",
	"hover_truck", "octodog", "screech", "screech_vents", "drone", "generator", "wall_fences", "wall_fences_partial",
	"buzz_overdrive", "barnacle_turret", "tithe_collector", "resonator", "gilded_sentinel", "enforcer_truck",
	"floor_cutter", "treasure_stash", "fenced_ceiling", "dash_wall", "wall_run_gaps", "debris_maze", "centipede",
	"gantryway"]
const GeneratorRules = preload("res://scripts/enemies/generator_rules.gd")
const POWERUPS_PATH: String = "res://data/tuning/powerups.tres"
const OCTODOG: String = "octodog"
## Metres before an output pad's front its landing keeps: the runner arrives as far past it as they were past the input
## pad's front at the touch (a frame's run at most), and their body reaches half its length behind that.
const LANDING_BACK: float = 1.0
## What only touches an end of a window (a later pass that kept exactly to it, give or take a float's rounding) isn't in
## it (problems; metres).
const TOUCH: float = 0.05
## Fitting spots kept, best first, among which a later one looks for a hazard ahead (prefer_hazard_seconds).
const BEST_KEPT: int = 24
## Kinds of teleporter (_kinds, _place).
const SINGLE: StringName = &"single"
const FIXED: StringName = &"fixed"
const BLINK: StringName = &"blink"
## A plan's marks: a piece that can't go counts this much at a spot, a plain one that may go one (Plan.blocked, cost).
const HARD: int = 1 << 16

## Review aid (tools/measure/teleporters.gd --why): print why an introduction found no spot.
static var debug: bool = false
## Review aid (tools/measure/teleporters.gd): microseconds apply() has taken, summed over every call since it was zeroed.
static var spent_usec: int = 0


## One level's teleporters at its run speed, for the pads' fronts on a grid (TeleporterTuning.search_step) from `lo` to
## `hi`: what each keeps (metres), and what stands in its way at each grid spot, lane by lane, counted from difference
## arrays. `pad`, `side` and `zone` by lane: what stands in the pad stretch of a pad's lane and of the lane beside it (a
## piece that can't go counts HARD, a plain one 1), and a ceiling's landing zone reaching a pad there; `near`: what every
## lane keeps over the pad stretch. By hop (an index of `hops`), then lane: `out`, what stands in an output pad's lane over
## its landing (an introduction's plan, `intro`, over its longer landing), `beside`, a doodad or floor enemy beside it; by
## hop, `far`, what every lane keeps over the landing, and (an introduction's plan) `quiet`, an enemy using the floor in
## any lane there. `hazards` by lane: the holes, fences and floor enemies a later one would like ahead of its landing.
class Plan:
	extends RefCounted
	var gen: LevelGenerator
	var t: TeleporterTuning
	var lanes: int = 3
	var lo: float = 0.0
	var hi: float = -1.0
	var step: float = 1.0
	## An introduction's plan: its landings keep intro_landing, and no enemy uses the floor in any lane there (`quiet`).
	var intro: bool = false
	## The pad's side (along the track as across), before its front (the approach), past its far end (a lane switch's
	## room), before an output pad's front, past it (the landing: the introduction's in its plan), beside it.
	var pad: float = 2.0
	var approach: float = 0.0
	var room: float = 0.0
	var back: float = LANDING_BACK
	var landing: float = 0.0
	## The hops tried (metres from a pad's front to its output pads').
	var hops := PackedFloat32Array()
	var fastest: float = 0.0
	var clearing: bool = true
	## The fences a fence generator powers (powered_fences): never taken out.
	var powered: Array[Dictionary] = []
	var pad_marks: Array[PackedInt32Array] = []
	var side_marks: Array[PackedInt32Array] = []
	var zone: Array[PackedInt32Array] = []
	var near := PackedInt32Array()
	## By hop, then lane (Array of Array[PackedInt32Array]).
	var out: Array = []
	var beside: Array = []
	## By hop.
	var far: Array[PackedInt32Array] = []
	var quiet: Array[PackedInt32Array] = []
	## By lane: Array[Vector2] each.
	var hazards: Array = []

	## Grid spots from lo to hi.
	func size() -> int:
		return maxi(floori((hi - lo) / step) + 1, 0)

	func front_at(i: int) -> float:
		return lo + i * step

	## The grid spot nearest `front`.
	func index_of(front: float) -> int:
		return clampi(roundi((front - lo) / step), 0, maxi(size() - 1, 0))

	## A difference array for size() spots (count() turns it into the counts).
	func fresh() -> PackedInt32Array:
		var marks := PackedInt32Array()
		marks.resize(size() + 1)
		marks.fill(0)
		return marks

	## Adds `amount`, in difference array `diff`, at the grid spots whose window [F + a, F + b] reaches `span`.
	func mark(diff: PackedInt32Array, span: Vector2, a: float, b: float, amount: int = HARD) -> void:
		var n: int = size()
		if n <= 0 or span.y < span.x:
			return
		var first: int = maxi(ceili((span.x - b - lo) / step - 0.0001), 0)
		var last: int = mini(floori((span.y - a - lo) / step + 0.0001), n - 1)
		if last < first:
			return
		diff[first] += amount
		diff[last + 1] -= amount

	## Turns difference array `diff` into each spot's count, in place.
	static func count(diff: PackedInt32Array) -> void:
		var running: int = 0
		for i: int in diff.size():
			running += diff[i]
			diff[i] = running


static func tuning() -> TeleporterTuning:
	return TeleporterTuning.load_default()


static func powerups() -> PowerupTuning:
	var res: Resource = load(POWERUPS_PATH) if ResourceLoader.exists(POWERUPS_PATH) else null
	return res as PowerupTuning if res is PowerupTuning else PowerupTuning.new()


## The fastest a runner comes onto a pad, or off an output pad, at `gen`'s level (metres a second): the run speed, the
## dash's bonus (PowerupTuning.dash_speed_bonus), and the most a speed pad's or a ramp's fading boost adds
## (MovementTuning). The teleport keeps the speed.
static func fastest(gen: LevelGenerator, pt: PowerupTuning = null) -> float:
	var p: PowerupTuning = pt if pt != null else powerups()
	return gen.speed + p.dash_speed_bonus + maxf(gen.tuning.speed_pad_boost, gen.tuning.ramp_speed_boost)


## A pad's side at `gen`'s level (metres): pad_share of a lane's width, as long along the track.
static func pad_size(gen: LevelGenerator, t: TeleporterTuning = null) -> float:
	var tt: TeleporterTuning = t if t != null else tuning()
	return gen.tuning.lane_width * tt.pad_share


## The level's teleporters (see the header), with the rules: the introductions first where the level gives the features a
## start, then the rest spread through the level.
static func apply(gen: LevelGenerator) -> void:
	var count: int = gen.config.teleporters
	if count <= 0 or not gen.config.has_feature(FEATURE):
		return
	var t0: int = Time.get_ticks_usec()
	_apply(gen, count)
	spent_usec += Time.get_ticks_usec() - t0


static func _apply(gen: LevelGenerator, count: int) -> void:
	var t: TeleporterTuning = tuning()
	var pt: PowerupTuning = powerups()
	var rng: RandomNumberGenerator = gen.rng_for(FEATURE)
	var plan: Plan = plan_for(gen, t, pt)
	var spacing: float = t.spacing_seconds * gen.speed
	var blink_count: int = clampi(gen.config.blinking_teleporters, 0, count) if gen.config.has_feature(BLINKING) else 0
	var fronts: Array[float] = []
	var placed: Array[StringName] = []
	var from: float = plan.lo
	var blink_from: float = maxf(plan.lo, gen.feature_start(BLINKING))
	var window: float = t.intro_window_seconds * gen.speed
	# The feature's introduction (Relay Station): one output pad straight ahead, safe.
	if gen.config.feature_starts.has(FEATURE):
		var spot: Dictionary = _intro(gen, t, pt, SINGLE, plan.lo, window, fronts, spacing)
		if not spot.is_empty():
			_place(gen, spot, fronts, rng)
			placed.append(SINGLE)
			from = float(spot["front"]) + spacing
	# The blinking antennas' introduction (Specimen Vault): two output pads, both landings safe.
	if blink_count > 0 and gen.config.feature_starts.has(BLINKING):
		var spot: Dictionary = _intro(gen, t, pt, BLINK, blink_from, window, fronts, spacing)
		if not spot.is_empty():
			_place(gen, spot, fronts, rng)
			placed.append(BLINK)
			blink_from = float(spot["front"]) + spacing
	# The rest, spread through the level past the introductions.
	var kinds: Array[StringName] = _kinds(t, rng, count, blink_count, placed)
	var left: int = kinds.size()
	if left > 0 and from <= plan.hi:
		var part: float = (plan.hi - from) / float(left)
		var wanted: Array[float] = []
		for k: int in left:
			wanted.append(from + k * part + rng.randf_range(0.25, 0.75) * part)
		for k: int in left:
			var a: float = from + k * part
			var b: float = a + part
			# A blinking one only past the blinking start: the first kind left that may stand in this part.
			var pick: int = -1
			for j: int in kinds.size():
				if kinds[j] != BLINK or b >= blink_from:
					pick = j
					break
			if pick < 0:
				continue
			var kind: StringName = kinds[pick]
			var lo_k: float = maxf(a, blink_from) if kind == BLINK else a
			var spot: Dictionary = _best(plan, kind, lo_k, b, maxf(wanted[k], lo_k), fronts, spacing, false)
			if not spot.is_empty():
				_place(gen, spot, fronts, rng)
				kinds.remove_at(pick)
	# Where a part had no room: the best of the rest, along the level past the introductions.
	while not kinds.is_empty():
		var kind: StringName = kinds[0]
		kinds.remove_at(0)
		var lo_k: float = maxf(from, blink_from) if kind == BLINK else from
		var spot: Dictionary = _best(plan, kind, lo_k, plan.hi, lo_k, fronts, spacing, false)
		# A two-output one with no room may stand as a one-output one.
		if spot.is_empty() and kind == FIXED:
			spot = _best(plan, SINGLE, lo_k, plan.hi, lo_k, fronts, spacing, false)
		if not spot.is_empty():
			_place(gen, spot, fronts, rng)
	if fronts.is_empty():
		gen.warnings.append("teleporters: no fair spot for one in the level (GDD §5: a feature a level has appears in it)")
	elif blink_count > 0 and positions_blinking(gen.layout).is_empty():
		gen.warnings.append("teleporters: no fair spot for a blinking one in the level (GDD §5: a feature a level has appears in it)")
	_number(gen.layout)


## An introduction of `kind` (SINGLE: the feature's; BLINK: the blinking antennas') from `start`: the best fair spot
## within `window` metres of it (the earliest that takes the fewest plain pieces out), on a plan of its own with the
## introduction's safe landings; else the first such spot past that, anywhere in the level. {} if none.
static func _intro(gen: LevelGenerator, t: TeleporterTuning, pt: PowerupTuning, kind: StringName, start: float,
		window: float, fronts: Array[float], spacing: float) -> Dictionary:
	var plan: Plan = plan_for(gen, t, pt, false, true, start, start + window)
	var spot: Dictionary = _best(plan, kind, plan.lo, plan.hi, plan.lo, fronts, spacing, true)
	if spot.is_empty() and debug:
		print("teleporters: no %s introduction within %.0f-%.0f m: %s" % [kind, plan.lo, plan.hi, _why_not(plan, plan.lo,
			plan.hi)])
	if spot.is_empty():
		plan = plan_for(gen, t, pt, false, true, start + window, INF)
		spot = _best(plan, kind, plan.lo, plan.hi, plan.lo, fronts, spacing, true)
	return spot


## The kinds of the teleporters still to place past the introductions (`placed`), in a seeded order: the blinking ones
## left of `blink_count`, and fixed ones for the rest, the first fixed one with two output pads and each later one with
## two_output_share (else one).
static func _kinds(t: TeleporterTuning, rng: RandomNumberGenerator, count: int, blink_count: int,
		placed: Array[StringName]) -> Array[StringName]:
	var blinks: int = maxi(blink_count - placed.count(BLINK), 0)
	var fixed: int = maxi(count - placed.size() - blinks, 0)
	var out: Array[StringName] = []
	for k: int in blinks:
		out.append(BLINK)
	for k: int in fixed:
		out.append(FIXED if k == 0 or rng.randf() < t.two_output_share else SINGLE)
	# A seeded order, so a level's kinds take turns along it.
	for i: int in range(out.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var swap: StringName = out[i]
		out[i] = out[j]
		out[j] = swap
	return out


## The output lanes a teleporter of `kind` may lead to, each a list (the left first): every single lane for one output pad
## (an introduction's: its pad's lane only, _best); a left and a right lane at least output_lane_gap apart (or as far apart
## as the track allows) for two.
static func _output_sets(plan: Plan, kind: StringName) -> Array[PackedInt32Array]:
	var sets: Array[PackedInt32Array] = []
	if kind == SINGLE:
		for l: int in plan.lanes:
			sets.append(PackedInt32Array([l]))
		return sets
	var gap: int = clampi(plan.t.output_lane_gap, 1, maxi(plan.lanes - 1, 1))
	for l: int in plan.lanes:
		for r: int in range(l + gap, plan.lanes):
			sets.append(PackedInt32Array([l, r]))
	return sets


## The best spot for a teleporter of `kind` (SINGLE, FIXED, BLINK) with its pad's front in [a, b] (the grid's), as
## {front, lane, side, hop (metres), outputs (lanes), cost, kind, intro}: one that fits, taking out the fewest plain pieces,
## then nearest `want` (the earliest with `earliest`), then the seeded tie; among the best BEST_KEPT of those, a later one
## (not on an introduction's plan) takes the first with a hazard ahead of an output pad (_hazard_ahead) at the best cost.
## The grid is searched outward from `want` (onward from `a` with `earliest`) and stops once what's left can't beat what
## it has. An introduction's one output pad stands straight ahead in its pad's lane. {} if none fits.
static func _best(plan: Plan, kind: StringName, a: float, b: float, want: float, fronts: Array[float], spacing: float,
		earliest: bool) -> Dictionary:
	var n: int = plan.size()
	if n <= 0:
		return {}
	var first: int = maxi(ceili((a - plan.lo) / plan.step - 0.0001), 0)
	var last: int = mini(floori((b - plan.lo) / plan.step + 0.0001), n - 1)
	if last < first:
		return {}
	var straight: bool = plan.intro and kind == SINGLE
	var sets: Array[PackedInt32Array] = _output_sets(plan, kind)
	var lanes: int = plan.lanes
	var land_cost := PackedInt32Array()
	land_cost.resize(lanes)
	# The grid's order: outward from `want`, or onward from `a`.
	var order := PackedInt32Array()
	if earliest:
		for i: int in range(first, last + 1):
			order.append(i)
	else:
		var mid: int = clampi(plan.index_of(want), first, last)
		order.append(mid)
		for k: int in range(1, last - first + 1):
			if mid + k <= last:
				order.append(mid + k)
			if mid - k >= first:
				order.append(mid - k)
	var best: Array[Array] = []
	for i: int in order:
		var f: float = plan.front_at(i)
		var off: float = f - a if earliest else absf(f - want)
		# Nothing further off can beat a full list of spots that take nothing out.
		if best.size() >= BEST_KEPT and int(best[best.size() - 1][0]) == 0 and off > float(best[best.size() - 1][1]) + 0.001:
			break
		if plan.near[i] > 0:
			continue
		var spaced: bool = true
		for other: float in fronts:
			spaced = spaced and absf(f - other) >= spacing - 0.001
		if not spaced:
			continue
		# The pads that may stand here: [lane, side, cost].
		var pads: Array[Vector3i] = []
		for lane: int in range(1, lanes - 1):
			var p: int = plan.pad_marks[lane][i]
			if p >= HARD or plan.zone[lane][i] > 0 or (p > 0 and not plan.clearing):
				continue
			for side: int in [-1, 1]:
				var by: int = lane + side
				if by < 0 or by >= lanes:
					continue
				var s: int = plan.side_marks[by][i]
				if s >= HARD or plan.zone[by][i] > 0 or (s > 0 and not plan.clearing):
					continue
				pads.append(Vector3i(lane, side, p + s))
		if pads.is_empty():
			continue
		for h: int in plan.hops.size():
			if plan.far[h][i] > 0 or (plan.intro and plan.quiet[h][i] > 0):
				continue
			var outs_h: Array = plan.out[h]
			var beside_h: Array = plan.beside[h]
			# What standing an output pad in each lane at this hop takes out, or -1 where it can't stand.
			var any: bool = false
			for l: int in lanes:
				var c: int = (outs_h[l] as PackedInt32Array)[i]
				var ok: bool = c < HARD and (c == 0 or plan.clearing)
				if ok and l > 0 and (beside_h[l - 1] as PackedInt32Array)[i] > 0:
					ok = false
				if ok and l < lanes - 1 and (beside_h[l + 1] as PackedInt32Array)[i] > 0:
					ok = false
				land_cost[l] = c if ok else -1
				any = any or ok
			if not any:
				continue
			for pad: Vector3i in pads:
				for outs: PackedInt32Array in sets:
					if straight and (outs.size() != 1 or outs[0] != pad.x):
						continue
					var cost: int = pad.z
					var fits: bool = true
					for l: int in outs:
						if land_cost[l] < 0:
							fits = false
							break
						cost += land_cost[l]
					if not fits:
						continue
					if best.size() >= BEST_KEPT:
						var worst: Array = best[best.size() - 1]
						if cost > int(worst[0]) or (cost == int(worst[0]) and off > float(worst[1]) + 0.001):
							continue
					var item: Array = [cost, off, _tie(plan, i, pad.x, pad.y, h, outs), i, pad.x, pad.y, h, outs]
					if best.size() >= BEST_KEPT and not _better(item, best[best.size() - 1]):
						continue
					var at: int = best.size()
					while at > 0 and _better(item, best[at - 1]):
						at -= 1
					best.insert(at, item)
					if best.size() > BEST_KEPT:
						best.pop_back()
	if best.is_empty():
		return {}
	var pick: Array = best[0]
	if not plan.intro and plan.t.prefer_hazard_seconds > 0.0:
		for item: Array in best:
			if int(item[0]) != int(best[0][0]):
				break
			if _hazard_ahead(plan, int(item[3]), int(item[6]), item[7]):
				pick = item
				break
	return {"front": plan.front_at(int(pick[3])), "lane": int(pick[4]), "side": int(pick[5]),
		"hop": plan.hops[int(pick[6])], "outputs": pick[7], "cost": int(pick[0]), "kind": kind, "intro": plan.intro,
		"plan": plan}


## True if candidate spot `x` ([cost, off, tie, ...]: _best) is better than `y`: fewer pieces out, then nearer, then the
## seeded tie.
static func _better(x: Array, y: Array) -> bool:
	if int(x[0]) != int(y[0]):
		return int(x[0]) < int(y[0])
	if absf(float(x[1]) - float(y[1])) > 0.001:
		return float(x[1]) < float(y[1])
	return int(x[2]) < int(y[2])


## A seeded order between spots equally good otherwise, so a level's lanes, sides and hops take turns.
static func _tie(plan: Plan, i: int, lane: int, side: int, h: int, outs: PackedInt32Array) -> int:
	return hash([plan.gen.config.level_seed, FEATURE, i, lane, side, h, outs]) & 0xffff


## True if an output pad at hop `h` from grid spot `i` in a lane of `outs` has a hole, a fence or a floor enemy in its lane
## within prefer_hazard_seconds past its landing (GDD §5: "later output pads may sit right in front of a gap or an
## enemy").
static func _hazard_ahead(plan: Plan, i: int, h: int, outs: PackedInt32Array) -> bool:
	var from: float = plan.front_at(i) + plan.hops[h] + plan.landing
	var to: float = from + plan.t.prefer_hazard_seconds * plan.gen.speed
	for l: int in outs:
		for span: Vector2 in (plan.hazards[l] as Array):
			if span.x <= to and span.y >= from:
				return true
	return false


## Why no spot of fronts [a, b] fits (debug): how many grid spots each rule turns down.
static func _why_not(plan: Plan, a: float, b: float) -> String:
	var n: int = plan.size()
	var first: int = maxi(ceili((a - plan.lo) / plan.step - 0.0001), 0)
	var last: int = mini(floori((b - plan.lo) / plan.step + 0.0001), n - 1)
	var counts: Dictionary = {}
	for i: int in range(first, last + 1):
		var why: PackedStringArray = []
		if plan.near[i] > 0:
			why.append("every lane at the pad")
		for lane: int in range(1, plan.lanes - 1):
			if plan.pad_marks[lane][i] >= HARD:
				why.append("lane %d" % lane)
			if plan.zone[lane][i] > 0:
				why.append("a landing zone in %d" % lane)
		var hops_far: int = 0
		var hops_quiet: int = 0
		for h: int in plan.hops.size():
			hops_far += 1 if plan.far[h][i] > 0 else 0
			hops_quiet += 1 if plan.intro and plan.quiet[h][i] > 0 else 0
		if hops_far == plan.hops.size():
			why.append("every lane at the landings")
		if hops_quiet == plan.hops.size():
			why.append("an enemy by the landings")
		var key: String = ", ".join(why)
		counts[key] = int(counts.get(key, 0)) + 1
	return str(counts)


## Stands a teleporter at `spot` (_best, with its plan): takes out the plain pieces in its windows, and adds its entry (its
## light from `rng`). Its id is set by _number once every one stands.
static func _place(gen: LevelGenerator, spot: Dictionary, fronts: Array[float], rng: RandomNumberGenerator) -> void:
	var plan: Plan = spot["plan"]
	var lay: LevelLayout = gen.layout
	var lane: int = int(spot["lane"])
	var side: int = int(spot["side"])
	var front: float = float(spot["front"])
	var intro: bool = bool(spot.get("intro", false))
	var kind: StringName = StringName(spot["kind"])
	var land: float = front + float(spot["hop"])
	var outs: PackedInt32Array = spot["outputs"]
	var windows: Array[Array] = [[lane, Vector2(front - plan.approach, front + plan.pad + plan.room)],
		[lane + side, Vector2(front - plan.approach, front + plan.pad + plan.room)]]
	for o: int in outs:
		windows.append([o, Vector2(land - plan.back, land + plan.landing)])
	var half: float = gen.tuning.fence_depth * 0.5
	var powered: Array[Dictionary] = plan.powered
	_keep(lay.gaps, func(g: Dictionary) -> bool:
		if LevelLayout.is_wall_run_hole(g):
			return true
		return not _in_windows(windows, int(g["lane"]), Vector2(float(g["start"]), float(g["end"]))))
	_keep(lay.fences, func(f: Dictionary) -> bool:
		if bool(f.get("pulsing", false)) or powered.has(f):
			return true
		return not _in_windows(windows, int(f["lane"]), Vector2(float(f["at"]) - half, float(f["at"]) + half)))
	var outputs: Array[Dictionary] = []
	for o: int in outs:
		outputs.append({"lane": o, "at": land, "end": land + plan.pad})
	var light: int = 0
	var blink: float = 0.0
	var phase: float = 0.0
	if outs.size() > 1:
		light = -1 if rng.randf() < 0.5 else 1
		if kind == BLINK:
			blink = plan.t.blink_seconds
			phase = snappedf(rng.randf(), 0.001)
	var calm: Array = [[lane, front - plan.approach, front + plan.pad]]
	for o: int in outs:
		calm.append([-1 if intro else o, land - plan.back, land + plan.landing])
	var index: int = lay.teleporters.size()
	var tp := {"id": index, "lane": lane, "at": front, "end": front + plan.pad, "side": side, "outputs": outputs,
		"light": light, "blink": blink, "phase": phase, "calm": calm,
		"span": [front - plan.approach, land + plan.landing], "seed": hash([gen.config.level_seed, FEATURE, index])}
	if intro:
		tp["intro"] = true
	lay.teleporters.append(tp)
	fronts.append(front)


## Gives the level's teleporters their ids in track order.
static func _number(lay: LevelLayout) -> void:
	lay.teleporters.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["at"]) < float(b["at"]))
	for i: int in lay.teleporters.size():
		lay.teleporters[i]["id"] = i


## True if `span` in `lane` reaches one of `windows` ([lane, Vector2]).
static func _in_windows(windows: Array[Array], lane: int, span: Vector2) -> bool:
	for w: Array in windows:
		var win: Vector2 = w[1]
		if int(w[0]) == lane and span.x <= win.y and span.y >= win.x:
			return true
	return false


## True if `a` and `b` overlap by more than TOUCH.
static func _hits(a: Vector2, b: Vector2) -> bool:
	return a.x < b.y - TOUCH and a.y > b.x + TOUCH


## Keeps the items of `list` for which `keep` returns true (in place, so typed arrays stay typed).
static func _keep(list: Array[Dictionary], keep: Callable) -> void:
	var kept: Array[Dictionary] = []
	for item: Dictionary in list:
		if keep.call(item):
			kept.append(item)
	list.assign(kept)


## What the level's teleporters keep, and where on its track a pad's front may stand (see the header): from `from` to `to`
## (the level's whole room where those are left as they are); with `intro`, an introduction's (its landings longer, and no
## enemy using the floor in any lane there); with `checking`, for a finished layout, everything there counts against a
## spot, plain pieces too (while placing, plain pieces only cost what taking them out costs).
static func plan_for(gen: LevelGenerator, t: TeleporterTuning = null, pt: PowerupTuning = null, checking: bool = false,
		intro: bool = false, from: float = -INF, to: float = INF) -> Plan:
	var p := Plan.new()
	p.gen = gen
	p.t = t if t != null else tuning()
	p.intro = intro
	var mt: MovementTuning = gen.tuning
	var lay: LevelLayout = gen.layout
	p.lanes = lay.lane_count
	p.fastest = fastest(gen, pt)
	p.pad = pad_size(gen, p.t)
	p.approach = p.t.approach_seconds * p.fastest
	p.room = gen.doodad_lane_room()
	p.landing = landing_length(gen, p.t, pt, intro)
	for s: float in p.t.hops():
		p.hops.append(s * gen.speed)
	var longest_hop: float = p.hops[p.hops.size() - 1] if not p.hops.is_empty() else 0.0
	p.step = maxf(p.t.search_step, 0.05)
	p.clearing = p.t.clear_plain_pieces and not checking
	p.lo = maxf(maxf(gen.config.start_clear_distance + p.approach, gen.feature_start(FEATURE)), from)
	p.hi = minf(lay.length - gen.config.end_clear_distance - longest_hop - p.landing, to)
	var lanes: int = p.lanes
	for lane: int in lanes:
		p.pad_marks.append(p.fresh())
		p.side_marks.append(p.fresh())
		p.zone.append(p.fresh())
		p.hazards.append([] as Array[Vector2])
	p.near = p.fresh()
	for h: int in p.hops.size():
		var outs: Array[PackedInt32Array] = []
		var besides: Array[PackedInt32Array] = []
		for lane: int in lanes:
			outs.append(p.fresh())
			besides.append(p.fresh())
		p.out.append(outs)
		p.beside.append(besides)
		p.far.append(p.fresh())
		p.quiet.append(p.fresh() if intro else PackedInt32Array())
	if p.size() <= 0:
		return p
	# The windows, from a pad's front (grid spot F): its pad stretch, and each hop's landing.
	var near_a: float = -p.approach
	var near_b: float = p.pad + p.room
	p.powered = powered_fences(gen)
	var keeps: Array[Dictionary] = gen.rules_doodad_keep_outs()
	# What stands in a lane: [lane, span, plain, solid (a doodad or a floor enemy: it counts beside an output pad too),
	# hazard (a hole, a fence or a floor enemy: one a later output pad would like ahead of its landing)].
	for piece: Array in lane_pieces(gen, p.clearing, p.powered, keeps):
		var lane: int = piece[0]
		var span: Vector2 = piece[1]
		if lane < 0 or lane >= lanes:
			continue
		var amount: int = 1 if bool(piece[2]) else HARD
		p.mark(p.pad_marks[lane], span, near_a, near_b, amount)
		p.mark(p.side_marks[lane], span, near_a, near_b, amount)
		for h: int in p.hops.size():
			var d: float = p.hops[h]
			p.mark((p.out[h] as Array)[lane], span, d - p.back, d + p.landing, amount)
			if bool(piece[3]):
				p.mark((p.beside[h] as Array)[lane], span, d - p.back, d + p.room)
		if bool(piece[4]):
			(p.hazards[lane] as Array).append(span)
	# What every lane keeps, over the pad stretch and over each landing.
	for span: Vector2 in every_keeps(gen, keeps):
		p.mark(p.near, span, near_a, near_b)
		for h: int in p.hops.size():
			var d: float = p.hops[h]
			p.mark(p.far[h], span, d - p.back, d + p.landing)
	# An introduction's landing: no enemy using the floor in any lane.
	if intro:
		for e: Dictionary in lay.enemies:
			if not LevelGenerator.enemy_uses_floor(e):
				continue
			var span: Vector2 = LevelGenerator.enemy_floor_span(e, gen.pace)
			for h: int in p.hops.size():
				var d: float = p.hops[h]
				p.mark(p.quiet[h], span, d - p.back, d + p.landing)
	# No ceiling's landing zone reaching the pad's lane or the side lane from its approach to its far end.
	for h: Dictionary in lay.hulls:
		var hl: Vector2i = lay.hull_lanes(h)
		var zone: Vector2 = gen.zones.landing_zone(h)
		for lane: int in range(hl.x, hl.y + 1):
			p.mark(p.zone[lane], zone, near_a, p.pad)
	for lane: int in lanes:
		Plan.count(p.pad_marks[lane])
		Plan.count(p.side_marks[lane])
		Plan.count(p.zone[lane])
	Plan.count(p.near)
	for h: int in p.hops.size():
		for lane: int in lanes:
			Plan.count((p.out[h] as Array)[lane])
			Plan.count((p.beside[h] as Array)[lane])
		Plan.count(p.far[h])
		if intro:
			Plan.count(p.quiet[h])
	return p


## How far past an output pad's front its landing keeps (metres, at `gen`'s level): landing_seconds at the fastest; an
## introduction's (`intro`) intro_landing_seconds at the run speed where that's longer.
static func landing_length(gen: LevelGenerator, t: TeleporterTuning = null, pt: PowerupTuning = null,
		intro: bool = false) -> float:
	var tt: TeleporterTuning = t if t != null else tuning()
	var landing: float = tt.landing_seconds * fastest(gen, pt)
	return maxf(landing, tt.intro_landing_seconds * gen.speed) if intro else landing


## What stands in each lane that a teleporter keeps its windows clear of (plan_for, problems), [lane, span, plain, solid,
## hazard]: its holes and fences (plain: one that may be taken out, never a wall-run gap's hole, a pulsing fence or one a
## fence generator powers; none with `plain_ok` off), speed pads, anti-grav pads' zones (CeilingZones.pad_zone: the run-up
## and the lift), a ramp in the outermost lane on its side to where its wall run drops the runner back, floor cuts' lane
## windows, the doodads (a row as one; a falling gantryway's pillar, a treasure stash's walls, a maze's debris), the floor
## its enemies use (LevelGenerator.enemy_floor_span; a wall enemy's that uses the floor in the outermost lane by its wall),
## and the lanes the rules keep (`keeps`, LevelGenerator.rules_doodad_keep_outs: {lane, from, to}, a hover truck's, a
## falling gantryway's). `solid`: a doodad or an enemy, which also counts beside an output pad; `hazard`: a hole, a fence or
## a floor enemy, which a later output pad would like ahead of its landing (_hazard_ahead).
static func lane_pieces(gen: LevelGenerator, plain_ok: bool, powered: Array[Dictionary] = [],
		keeps: Array[Dictionary] = []) -> Array[Array]:
	var lay: LevelLayout = gen.layout
	var mt: MovementTuning = gen.tuning
	var out: Array[Array] = []
	var half: float = mt.fence_depth * 0.5
	if plain_ok and powered.is_empty():
		powered = powered_fences(gen)
	for g: Dictionary in lay.gaps:
		out.append([int(g["lane"]), Vector2(float(g["start"]), float(g["end"])),
			plain_ok and not LevelLayout.is_wall_run_hole(g), false, true])
	for f: Dictionary in lay.fences:
		out.append([int(f["lane"]), Vector2(float(f["at"]) - half, float(f["at"]) + half),
			plain_ok and not bool(f.get("pulsing", false)) and not powered.has(f), false, true])
	for s: Dictionary in lay.speed_pads:
		out.append([int(s["lane"]), Vector2(float(s["at"]), float(s["at"]) + mt.speed_pad_length), false, false, false])
	for pad: Dictionary in lay.pads:
		out.append([int(pad["lane"]), gen.zones.pad_zone(float(pad["at"])), false, false, false])
	for r: Dictionary in lay.ramps:
		var at: float = float(r["at"])
		out.append([lay.outer_lane(int(r["side"])), Vector2(at, maxf(gen.ramp_launch(r).end(), at + mt.ramp_length)), false,
			false, false])
	for c: Dictionary in lay.cuts:
		out.append([int(c["lane"]), FloorCutPlan.lane_window(c), false, false, false])
	for d: Dictionary in lay.doodads:
		out.append([int(d["lane"]), LevelLayout.doodad_extent(d), false, true, false])
	for e: Dictionary in lay.enemies:
		if not LevelGenerator.enemy_uses_floor(e):
			continue
		var lane: int = int(e.get("lane", -1))
		if (lane < 0 or lane >= lay.lane_count) and int(e.get("side", 0)) != 0:
			lane = lay.outer_lane(int(e["side"]))
		out.append([lane, LevelGenerator.enemy_floor_span(e, gen.pace), false, true, true])
	for k: Dictionary in (keeps if not keeps.is_empty() else gen.rules_doodad_keep_outs()):
		if k.has("lane") and String(k.get("type", "")) != FEATURE:
			out.append([int(k["lane"]), Vector2(float(k["from"]), float(k["to"])), false, false, false])
	return out


## What every lane keeps clear of a teleporter's pad stretch and its landings (plan_for, problems): every floor cut's
## window, every dash wall's footprint, every debris maze block (its run-in to its breather), every wall-run gap's stretch
## with its margins (WallRunGapPlacement.keep_out), every falling gantryway (from its pillar's lead to past its walkway and
## its calm stretch), every Octodog's planned charge (its window from a metre before its anchor), and what the rules keep
## in every lane (`keeps`, LevelGenerator.rules_doodad_keep_outs: their calm stretches too; never a teleporter's own).
static func every_keeps(gen: LevelGenerator, keeps: Array[Dictionary] = []) -> Array[Vector2]:
	var lay: LevelLayout = gen.layout
	var out: Array[Vector2] = []
	for c: Dictionary in lay.cuts:
		out.append(FloorCutPlan.window(c, gen.speed))
	for w: Dictionary in lay.dash_walls:
		out.append(LevelGenerator.DashWallRules.footprint(gen, w))
	for b: Dictionary in lay.maze:
		out.append(Vector2(float(b["entry"]), float(b["exit"])))
	for w: Dictionary in lay.wall_run_gaps:
		out.append(WallRunGapPlacement.keep_out(w))
	var lead: float = LevelGenerator.doodad_lead_for(gen.tuning) + gen.doodad_lane_room()
	for g: Dictionary in lay.gantryways:
		var calm: Array = g.get("calm", [g["pillar"], g["end"]])
		out.append(Vector2(float(g["pillar"]) - lead, maxf(float(g["end"]) + gen.doodad_lane_room(), float(calm[1]))))
	for k: Dictionary in (keeps if not keeps.is_empty() else gen.rules_doodad_keep_outs()):
		if not k.has("lane") and String(k.get("type", "")) != FEATURE:
			out.append(Vector2(float(k["from"]), float(k["to"])))
	var ot := EnemyDirector.tuning_for(OCTODOG) as OctodogTuning
	if ot != null:
		var window: float = ot.window_length(gen.speed, gen.config.enemy_scaling, gen.pace)
		for e: Dictionary in lay.enemies:
			if String(e.get("type", "")) != OCTODOG:
				continue
			for a: Variant in (e.get("params", {}) as Dictionary).get("charge_at", []):
				out.append(Vector2(float(a) - 1.0, float(a) + window))
	return out


## The fences a fence generator powers (FenceGenerator.fences_in_reach): with the pulsing ones, the fences a teleporter
## never takes out to make room (the `pulsing` feature counts those; a generator powering nothing goes).
static func powered_fences(gen: LevelGenerator) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var has_generators: bool = false
	for e: Dictionary in gen.layout.enemies:
		has_generators = has_generators or String(e.get("type", "")) == "generator"
	if not has_generators:
		return out
	var gt: FenceGeneratorTuning = GeneratorRules.tuning()
	var geo := TrackGeometry.new(gen.layout.lane_count, gen.tuning)
	for e: Dictionary in gen.layout.enemies:
		if String(e.get("type", "")) == "generator":
			out.append_array(FenceGenerator.fences_in_reach(gen.layout, geo, float(e["at"]), int(e["lane"]), gt.emp_radius))
	return out


## Every teleporter in `layout`: its pad's front (LevelGenerator.feature_positions: the every-feature check and the
## introduction's).
static func positions(layout: LevelLayout) -> Array[float]:
	var out: Array[float] = []
	for tp: Dictionary in layout.teleporters:
		out.append(float(tp["at"]))
	return out


## Every teleporter in `layout` with a blinking antenna (teleporters `blink` above 0): its pad's front
## (teleporter_blinking_rules.gd's positions()).
static func positions_blinking(layout: LevelLayout) -> Array[float]:
	var out: Array[float] = []
	for tp: Dictionary in layout.teleporters:
		if float(tp.get("blink", 0.0)) > 0.0:
			out.append(float(tp["at"]))
	return out


## The stretches teleporter `tp` keeps, as {lane: [Vector2, ...]} (lane -1: every lane) at `gen`'s level: its pad stretch
## (from its approach to a lane switch's room past its far end) in every lane, its own lane and the side lane; each
## landing (from LANDING_BACK before its output pad's front to its landing's end) in every lane and its output pad's lane.
static func windows_of(gen: LevelGenerator, tp: Dictionary, t: TeleporterTuning = null, pt: PowerupTuning = null) -> Dictionary:
	var tt: TeleporterTuning = t if t != null else tuning()
	var front: float = float(tp["at"])
	var pad: float = float(tp["end"]) - front
	var approach: float = tt.approach_seconds * fastest(gen, pt)
	var room: float = gen.doodad_lane_room()
	var landing: float = landing_length(gen, tt, pt, bool(tp.get("intro", false)))
	var lane: int = int(tp["lane"])
	var out: Dictionary = {}
	var add := func(l: int, span: Vector2) -> void:
		if not out.has(l):
			out[l] = [] as Array[Vector2]
		(out[l] as Array).append(span)
	var stretch := Vector2(front - approach, front + pad + room)
	add.call(-1, stretch)
	add.call(lane, stretch)
	add.call(lane + int(tp["side"]), stretch)
	for o: Dictionary in tp.get("outputs", []):
		var at: float = float(o["at"])
		add.call(-1, Vector2(at - LANDING_BACK, at + landing))
		add.call(int(o["lane"]), Vector2(at - LANDING_BACK, at + landing))
	return out


## What the passes after the rules keep off (LevelGenerator.rules_doodad_keep_outs: the danger density pass, the wider
## gaps, the cyborgs planted in charge paths, the zone doodads): every teleporter's pad stretch and each of its landings in
## every lane, and its lanes there ({lane, from, to}: its pad's, the side lane, each output pad's, and the lanes beside that
## a lane switch's room past its front), each widened by `edge` at both ends.
static func doodad_keep_outs(gen: LevelGenerator) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if gen.layout.teleporters.is_empty():
		return out
	var t: TeleporterTuning = tuning()
	var pt: PowerupTuning = powerups()
	var room: float = gen.doodad_lane_room()
	var e: float = edge(gen)
	for tp: Dictionary in gen.layout.teleporters:
		var windows: Dictionary = windows_of(gen, tp, t, pt)
		for l: Variant in windows:
			for span: Vector2 in windows[l]:
				if int(l) < 0:
					out.append({"from": span.x - e, "to": span.y + e, "type": FEATURE})
				elif int(l) < gen.layout.lane_count:
					out.append({"lane": int(l), "from": span.x - e, "to": span.y + e, "type": FEATURE})
		for o: Dictionary in tp.get("outputs", []):
			var at: float = float(o["at"])
			for by: int in [int(o["lane"]) - 1, int(o["lane"]) + 1]:
				if by >= 0 and by < gen.layout.lane_count:
					out.append({"lane": by, "from": at - LANDING_BACK - e, "to": at + room + e, "type": FEATURE})
	return out


## What the fill pass keeps off (LevelGenerator.rules_fill_keep_outs, every lane): every teleporter's pad stretch and each
## of its landings, each widened by `edge` at both ends.
static func fill_keep_outs(gen: LevelGenerator) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if gen.layout.teleporters.is_empty():
		return out
	var t: TeleporterTuning = tuning()
	var pt: PowerupTuning = powerups()
	var e: float = edge(gen)
	for tp: Dictionary in gen.layout.teleporters:
		for span: Vector2 in windows_of(gen, tp, t, pt).get(-1, []):
			out.append(Vector2(span.x - e, span.y + e))
	return out


## How much wider than a window the keep-outs handed to the passes after the rules are at each end (metres): half a
## fence's depth and TOUCH. A pass that keeps a fence's `at` (a point) out of a keep-out may stand it right at the
## keep-out's end (the fill pass starts a filler there), and its body reaches half its depth back in.
static func edge(gen: LevelGenerator) -> float:
	return gen.tuning.fence_depth * 0.5 + TOUCH


## Every placement rule a finished level's teleporters break (see the header), for the tests: [] if none. Run on the
## finished layout, so it also catches a pass after the rules that put something where a teleporter keeps.
static func problems(gen: LevelGenerator) -> PackedStringArray:
	var out: PackedStringArray = []
	var lay: LevelLayout = gen.layout
	if lay.teleporters.is_empty():
		return out
	var t: TeleporterTuning = tuning()
	var pt: PowerupTuning = powerups()
	var v: float = fastest(gen, pt)
	var spacing: float = t.spacing_seconds * gen.speed
	var pad: float = pad_size(gen, t)
	var room: float = gen.doodad_lane_room()
	var keeps: Array[Dictionary] = gen.rules_doodad_keep_outs()
	var pieces: Array[Array] = lane_pieces(gen, false, [], keeps)
	var every: Array[Vector2] = every_keeps(gen, keeps)
	var hop_lo: float = minf(t.hop_seconds_min, t.hop_seconds_max) * gen.speed
	var hop_hi: float = maxf(t.hop_seconds_min, t.hop_seconds_max) * gen.speed
	var gap: int = clampi(t.output_lane_gap, 1, maxi(lay.lane_count - 1, 1))
	var blink_from: float = gen.feature_start(BLINKING)
	var approach: float = t.approach_seconds * v
	var prev: float = -INF
	for tp: Dictionary in lay.teleporters:
		var lane: int = int(tp["lane"])
		var side: int = int(tp["side"])
		var front: float = float(tp["at"])
		var tag: String = "the teleporter at %.1f m (lane %d)" % [front, lane]
		var outs: Array = tp.get("outputs", [])
		var intro: bool = bool(tp.get("intro", false))
		var landing: float = landing_length(gen, t, pt, intro)
		if lane < 1 or lane > lay.lane_count - 2:
			out.append("%s: not in an inner lane" % tag)
		if absi(side) != 1 or lane + side < 0 or lane + side >= lay.lane_count:
			out.append("%s: no lane beside it as the way around" % tag)
		if absf(float(tp["end"]) - front - pad) > 0.01:
			out.append("%s: its pad isn't %.2f m square" % [tag, pad])
		if outs.is_empty() or outs.size() > 2:
			out.append("%s: %d output pads" % [tag, outs.size()])
			continue
		var land: float = float((outs[0] as Dictionary)["at"])
		for o: Dictionary in outs:
			if absf(float(o["at"]) - land) > 0.01 or absf(float(o["end"]) - float(o["at"]) - pad) > 0.01:
				out.append("%s: its output pads aren't side by side, %.2f m square" % [tag, pad])
			if int(o["lane"]) < 0 or int(o["lane"]) >= lay.lane_count:
				out.append("%s: an output pad in lane %d" % [tag, int(o["lane"])])
		if land - front < hop_lo - 0.05 or land - front > hop_hi + 0.05:
			out.append("%s: its output pads %.1f m on, not %.1f-%.1f m (within sight ahead)" % [tag, land - front, hop_lo, hop_hi])
		var light: int = int(tp.get("light", 0))
		var blink: float = float(tp.get("blink", 0.0))
		if outs.size() == 2:
			if int((outs[1] as Dictionary)["lane"]) - int((outs[0] as Dictionary)["lane"]) < gap:
				out.append("%s: its left and right output pads are fewer than %d lanes apart" % [tag, gap])
			if absi(light) != 1:
				out.append("%s: two output pads but no light on a side" % tag)
			if blink > 0.0 and (not gen.config.has_feature(BLINKING) or front < blink_from - 0.01):
				out.append("%s: a blinking antenna where the level has none (or before their start)" % tag)
			if blink > 0.0 and absf(blink - t.blink_seconds) > 0.001:
				out.append("%s: it blinks every %.2f s, not %.2f s" % [tag, blink, t.blink_seconds])
		elif light != 0 or blink > 0.0:
			out.append("%s: one output pad and a light to choose between none" % tag)
		if intro and outs.size() == 1 and int((outs[0] as Dictionary)["lane"]) != lane:
			out.append("%s: the introduction's output pad isn't straight ahead in its lane" % tag)
		var span: Array = tp.get("span", [])
		if span.size() != 2 or absf(float(span[0]) - (front - approach)) > 0.05 or absf(float(span[1]) - (land + landing)) > 0.05:
			out.append("%s: its span %s isn't from its approach to its landings' end" % [tag, span])
		if front - approach < gen.config.start_clear_distance - 0.01 or front < gen.feature_start(FEATURE) - 0.01 \
				or land + landing > lay.length - gen.config.end_clear_distance + 0.01:
			out.append("%s: not between the run-up (or the feature's start) and the end-clear stretch" % tag)
		if front - prev < spacing - 0.01:
			out.append("%s: %.1f m after the one before (at least %.1f m)" % [tag, front - prev, spacing])
		prev = front
		# The calm stretches: its approach in its lane, each landing in its output pad's lane (every lane for an
		# introduction's).
		var calm: Array = tp.get("calm", [])
		if calm.size() != 1 + outs.size() or int((calm[0] as Array)[0]) != lane \
				or float((calm[0] as Array)[1]) > front - approach + 0.05 or float((calm[0] as Array)[2]) < front + pad - 0.05:
			out.append("%s: its calm stretches %s aren't its approach and its landings" % [tag, calm])
		else:
			for k: int in outs.size():
				var c: Array = calm[k + 1]
				var o: Dictionary = outs[k]
				if int(c[0]) != (-1 if intro else int(o["lane"])) or float(c[1]) > float(o["at"]) - LANDING_BACK + 0.01 \
						or float(c[2]) < float(o["at"]) + landing - 0.05:
					out.append("%s: no calm stretch over its landing in lane %d" % [tag, int(o["lane"])])
		# Its lanes: nothing there over what it keeps.
		var windows: Dictionary = windows_of(gen, tp, t, pt)
		for piece: Array in pieces:
			var p_lane: int = piece[0]
			var p_span: Vector2 = piece[1]
			for w: Vector2 in windows.get(p_lane, []):
				if _hits(p_span, w):
					out.append("%s: something stands in lane %d at %.2f-%.2f m, where it keeps clear (%.2f-%.2f m)" % [tag,
						p_lane, p_span.x, p_span.y, w.x, w.y])
			# Beside an output pad: no doodad or floor enemy a lane switch's room past its front.
			if bool(piece[3]):
				for o: Dictionary in outs:
					var at: float = float(o["at"])
					if absi(p_lane - int(o["lane"])) == 1 and _hits(p_span, Vector2(at - LANDING_BACK, at + room)):
						out.append("%s: a doodad or an enemy beside its output pad in lane %d (lane %d at %.1f-%.1f m)" % [
							tag, int(o["lane"]), p_lane, p_span.x, p_span.y])
		for k: Vector2 in every:
			for w: Vector2 in windows.get(-1, []):
				if _hits(k, w):
					out.append("%s: something every lane keeps clear of is at %.1f-%.1f m, in what it keeps (%.1f-%.1f m)" % [
						tag, k.x, k.y, w.x, w.y])
		# No ceiling's landing zone reaching its lane or the side lane from its approach to its far end.
		var touch_span := Vector2(front - approach, front + pad)
		for h: Dictionary in lay.hulls:
			var hl: Vector2i = lay.hull_lanes(h)
			var zone: Vector2 = gen.zones.landing_zone(h)
			for l: int in [lane, lane + side]:
				if l >= hl.x and l <= hl.y and _hits(zone, touch_span):
					out.append("%s: a ceiling's landing zone (%.1f-%.1f m) in lane %d by its pad" % [tag, zone.x, zone.y, l])
		# The introductions' landings: no enemy using the floor in any lane.
		if intro:
			for e: Dictionary in lay.enemies:
				if not LevelGenerator.enemy_uses_floor(e):
					continue
				var s: Vector2 = LevelGenerator.enemy_floor_span(e, gen.pace)
				for o: Dictionary in outs:
					var at: float = float(o["at"])
					if _hits(s, Vector2(at - LANDING_BACK, at + landing)):
						out.append("%s: a %s (at %.1f m) on the floor by the introduction's landing" % [tag, String(e["type"]),
							float(e["at"])])
	return out
