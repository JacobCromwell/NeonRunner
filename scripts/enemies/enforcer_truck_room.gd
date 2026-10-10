class_name EnforcerTruckRoom
extends RefCounted
## Where the Enforcer Truck has room to show itself (GDD §9.13 "Showing itself", owner, October 8, 2026): what a
## level's layout holds, read once into stretches of track by lane (cheap to ask after), and the layout's side
## of every rule a showing keeps. The truck asks it (EnforcerTruck.show_lane_now, which adds what's in play:
## enemies, attacks, the runner); the tests ask it of the campaign's levels.
## By lane, as merged stretches (Vector2(start, end), in order):
## - hard: what blocks a runner's dodge (holes, floor cuts' lane windows, fences, doodads, floor enemies), and of
##   that, must_leave: what the runner has to leave the lane for (doodads, floor enemies, a floor cut's lane
##   window; holes and fences they can jump or slide);
## - solid: what the truck never drives through on screen (fences, doodads, floor enemies, and a dash wall in every
##   lane: task H7a's walls stand across the street until the runner breaks them, and a showing puts its front
##   ahead of the runner, so it never shows itself where its view would reach a wall);
## - soft: what the runner may need (pads, speed pads, ramps);
## - deadly: what would wreck it (gaps too wide to hop, floor cuts' lane windows); it hops the other gaps.
## - held: where a hover truck holds the lane (task C6e): a wall to the runner (its sides are solid), never the
##   truck's lane, and a showing never stands between the runner and it (it would hide it).
## And: where its baits' turns begin (an Octodog's planned wind-ups; a Buzz Overdrive's claim on its turn before
## its rev) and the Buzz Overdrives' revs, where the attacks that can't wait for a turn are on (fixed: a hover truck's entrance,
## a Gilded Sentinel's turn; task C6e), where a hover truck or a Gilded Sentinel comes into play (quiet: the
## generator's first try still plans its windows away from them, NO_SHOW_TYPES), and
## the layout's enemies by where they stand (for what its body could hide from the camera: floor enemies in their
## lanes, wall enemies at their walls, Barnacle Turrets over their lanes).

## A floor enemy keeps this much of its lane (metres either side of its reach) from a showing and an escape.
const ENEMY_ROOM: float = 3.0
## The runner has room to step aside around a blocked stretch of their lane: this many seconds of running (a
## lane change takes 0.14 s).
const DODGE_ROOM_SECONDS: float = 0.2
## Its front this far behind the runner, nothing of it is in the chase camera's view (its nose, its roof and its
## riders all lie under the bottom of the view): a showing is in view from there in.
const OUT_OF_VIEW: float = 5.0
## The hover truck (a mini-boss holding an outer lane) and the Gilded Sentinel (its strike can't wait for a turn: it
## would let the runner pass). Task C6b kept every showing away from them; the owner (October 9, 2026, GDD §9.13
## "Making room where there is none", answering docs/OPEN_QUESTIONS.md items 367 and 400): they no longer stop one,
## as long as the runner keeps a free lane. A showing keeps off what of them can't wait (fixed: a hover truck's
## entrance, a Sentinel's turn), never takes a lane a hover truck holds (held) and counts it a wall to the runner. The
## generator still tries a window away from them first, as before (quiet; ShowPlanner's CLASSIC). Others wait for its
## showing's turn as for a volley's (a Resonator's pulse moves on), the hover truck's cannon and forward lurch too.
const NO_SHOW_TYPES: Array[StringName] = [&"hover_truck", &"gilded_sentinel"]
## Enemies that stay where the layout puts them over a lane, off the floor (a Barnacle Turret under its ceiling): the
## layout's shadow counts them where they hang (task C6c), as the truck's in play does.
const HANGS_OVER_LANE: PackedStringArray = ["barnacle_turret"]
const TYPE: String = "enforcer_truck"
const BuzzRules = preload("res://scripts/enemies/buzz_overdrive_rules.gd")
const HoverTruckRules = preload("res://scripts/enemies/hover_truck_rules.gd")

var geo: TrackGeometry
var hard: Array[PackedVector2Array] = []
var must_leave: Array[PackedVector2Array] = []
## must_leave with a floor cut's lane only from its charge (task C6e; can_dodge's `clip`): a runner may keep to a Buzz
## Overdrive's lane behind it until its cut runs back toward them (that's how they bait the truck into it).
var leave_late: Array[PackedVector2Array] = []
## What a runner jumps or slides in their lane (holes and fences; task C6e, can_dodge's `clip`).
var jump: Array[PackedVector2Array] = []
var solid: Array[PackedVector2Array] = []
var soft: Array[PackedVector2Array] = []
var deadly: Array[PackedVector2Array] = []
## Where a hover truck holds the lane (task C6e): from where its lane is kept free before it bursts in to where it
## has left, after its longest stay (HoverTruckRules.window_start, window_end), by lane.
var held: Array[PackedVector2Array] = []
## Where its baits' turns begin (runner distances, in order).
var baits: PackedFloat32Array = PackedFloat32Array()
## Where its baits' turns begin that aren't a claim (an Octodog's planned wind-ups: it closes up behind the runner
## close_lead_seconds before one), and where the Buzz Overdrives that claim theirs rev (their warning; task C6e,
## hold_claimed). Runner distances, in order.
var dog_turns: PackedFloat32Array = PackedFloat32Array()
var revs: PackedFloat32Array = PackedFloat32Array()
## The attacks that can't wait for a turn (task C6e): Vector2(where the runner is as one begins, where it's over), in
## order: each hover truck's entrance (from its banging, its warning, to its burst through the wall and its emerging
## into its lane) and each Gilded Sentinel's turn (from its claim, GildedSentinelTuning.claim_window, to its last
## swing's end). A showing is never on during one, nor while the truck claims its turn for its planned window.
## DESIGN-TBD (docs/OPEN_QUESTIONS.md item 410): of the hover truck's attacks only its entrance counts; its cannon shots and
## forward lurch take turns (HoverTruck asks EnemyDirector.major_attack_blocked) and wait for a showing.
var fixed: Array[Vector2] = []
## The enemies that keep it from showing itself in the generator's first try (ShowPlanner's CLASSIC mode, as tasks C6c
## and C6d planned): Vector2(where one comes into play, its `at`), in order.
var quiet: Array[Vector2] = []
## The layout's enemies: Vector2(at, world x) in order (a floor enemy or a Barnacle Turret at its lane's middle, a
## wall enemy at its wall; fliers left out).
var planned: Array[Vector2] = []


## Reads `layout` (a level at `run_speed`, `mt` its movement tuning, `t` the truck's tuning). A Buzz Overdrive's
## turn comes `least_claim` seconds or more before its rev (the generator's plan for a pass that may give it a longer
## claim later, ShowPlanner).
static func build(layout: LevelLayout, geometry: TrackGeometry, mt: MovementTuning, t: EnforcerTruckTuning,
		run_speed: float, least_claim: float = 0.0) -> EnforcerTruckRoom:
	var room := EnforcerTruckRoom.new()
	room.geo = geometry
	var lanes: int = geometry.lane_count
	var pace: float = run_speed / MovementTuning.REFERENCE_SPEED
	var by: Dictionary = {"hard": [], "must": [], "late": [], "jump": [], "solid": [], "soft": [], "deadly": [], "held": []}
	for key: String in by:
		for l: int in lanes:
			(by[key] as Array).append([])
	var too_wide: float = t.max_hop_jump_fraction * mt.jump_distance(run_speed) + 0.001
	for g: Dictionary in layout.gaps:
		var from: float = float(g["start"])
		var to: float = float(g["end"])
		_add(by["hard"], int(g["lane"]), from, to)
		_add(by["jump"], int(g["lane"]), from, to)
		if to - from > too_wide:
			_add(by["deadly"], int(g["lane"]), from, to)
	for c: Dictionary in layout.cuts:
		var w: Vector2 = FloorCutPlan.lane_window(c)
		for key: String in ["hard", "must", "deadly"]:
			_add(by[key], int(c["lane"]), minf(w.x, float(c["start"])), w.y)
		_add(by["late"], int(c["lane"]), FloorCutPlan.charge_at(c), w.y)
	var half: float = mt.fence_depth * 0.5 + 0.5
	for f: Dictionary in layout.fences:
		for key: String in ["hard", "jump", "solid"]:
			_add(by[key], int(f["lane"]), float(f["at"]) - half, float(f["at"]) + half)
	for d: Dictionary in layout.doodads:
		for key: String in ["hard", "must", "late", "solid"]:
			_add(by[key], int(d["lane"]), float(d["start"]), float(d["end"]))
	# A dash wall (task H7a) stands in every lane: it would drive into it ahead of the runner, who breaks it only as
	# they reach it. (The generator keeps every wall off its planned showing windows; this keeps its other showings
	# off them too.) DESIGN-TBD (docs/OPEN_QUESTIONS.md item 671).
	for w: Dictionary in layout.dash_walls:
		for l: int in lanes:
			_add(by["solid"], l, float(w["start"]), float(w["end"]))
	for p: Dictionary in layout.pads:
		_add(by["soft"], int(p["lane"]), float(p["at"]) - mt.pad_length, float(p["at"]) + mt.pad_length)
	for p: Dictionary in layout.speed_pads:
		_add(by["soft"], int(p["lane"]), float(p["at"]) - mt.speed_pad_length, float(p["at"]) + mt.speed_pad_length)
	for r: Dictionary in layout.ramps:
		_add(by["soft"], layout.outer_lane(int(r["side"])), float(r["at"]) - mt.ramp_length, float(r["at"]) + mt.ramp_length)
	var warns: Array[float] = []
	var dogs: Array[float] = []
	var revs_at: Array[float] = []
	var buzz := EnemyDirector.tuning_for("buzz_overdrive") as BuzzOverdriveTuning
	for e: Dictionary in layout.enemies:
		var type: String = String(e.get("type", ""))
		if type == TYPE:
			continue
		var at: float = float(e.get("at", 0.0))
		match type:
			"octodog":
				for a: Variant in (e.get("params", {}) as Dictionary).get("charge_at", []):
					warns.append(float(a))
					dogs.append(float(a))
			"buzz_overdrive":
				var cut: Dictionary = BuzzRules.cut_of(layout, e)
				if not cut.is_empty():
					var claim: float = float(cut.get("claim_seconds", buzz.claim_seconds if buzz != null else 2.5))
					warns.append(FloorCutPlan.warn_at(cut) - maxf(claim, least_claim) * run_speed)
					revs_at.append(FloorCutPlan.warn_at(cut))
			"hover_truck":
				var ht := EnemyDirector.tuning_for(type) as HoverTruckTuning
				if ht != null:
					_add(by["held"], int(e.get("lane", -1)), HoverTruckRules.window_start(ht, at, pace),
						HoverTruckRules.window_end(ht, at, run_speed))
					room.fixed.append(entrance(ht, at, run_speed))
			"gilded_sentinel":
				var st := EnemyDirector.tuning_for(type) as GildedSentinelTuning
				if st != null:
					room.fixed.append(sentinel_turn(st, at, int((e.get("params", {}) as Dictionary).get("swings", 1)),
						run_speed))
		if StringName(type) in NO_SHOW_TYPES:
			var et := EnemyDirector.tuning_for(type) as EnemyTuning
			room.quiet.append(Vector2(at - (et.spawn_lead if et != null else 100.0), at))
		if LevelGenerator.enemy_uses_floor(e):
			var span: Vector2 = LevelGenerator.enemy_floor_span(e, pace)
			if span.x > span.y:
				span = Vector2(at, at)
			for key: String in ["hard", "must", "late", "solid"]:
				_add(by[key], int(e.get("lane", 0)), span.x - ENEMY_ROOM, span.y + ENEMY_ROOM)
			room.planned.append(Vector2(at, geometry.lane_x(clampi(int(e.get("lane", 0)), 0, lanes - 1))))
		elif int(e.get("side", 0)) != 0:
			room.planned.append(Vector2(at, signf(float(e["side"])) * geometry.wall_x()))
		elif HANGS_OVER_LANE.has(type):
			room.planned.append(Vector2(at, geometry.lane_x(clampi(int(e.get("lane", 0)), 0, lanes - 1))))
	warns.sort()
	room.baits = PackedFloat32Array(warns)
	dogs.sort()
	room.dog_turns = PackedFloat32Array(dogs)
	revs_at.sort()
	room.revs = PackedFloat32Array(revs_at)
	room.fixed.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	room.quiet.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	room.planned.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	for l: int in lanes:
		room.hard.append(merged(by["hard"][l]))
		room.must_leave.append(merged(by["must"][l]))
		room.leave_late.append(merged(by["late"][l]))
		room.jump.append(merged(by["jump"][l]))
		room.solid.append(merged(by["solid"][l]))
		room.soft.append(merged(by["soft"][l]))
		room.deadly.append(merged(by["deadly"][l]))
		room.held.append(merged(by["held"][l]))
	return room


## A hover truck's entrance standing at `at` (task C6e; hover_truck.gd), at `run_speed`: Vector2(where the runner is as
## its banging begins, its warning, until it has burst through the wall and emerged into its lane). It can't wait for a
## turn (the generator planned where it bursts out), so a showing is never on meanwhile.
static func entrance(ht: HoverTruckTuning, at: float, run_speed: float) -> Vector2:
	var burst: float = at - ht.burst_lead
	return Vector2(burst - ht.bang_seconds * run_speed, burst + ht.emerge_seconds * run_speed)


## A Gilded Sentinel's turn standing at `at` with `swings` swings (task C6e), at `run_speed`: from its claim
## (GildedSentinelTuning.claim_window) until its last swing's cut is over. A statue can't wait for a turn (it lets the
## runner pass if another type's attack is on as its warning would start), so a showing is never on meanwhile.
static func sentinel_turn(st: GildedSentinelTuning, at: float, swings: int, run_speed: float) -> Vector2:
	var claim: Vector2 = st.claim_window(at, swings, run_speed)
	return Vector2(claim.x, claim.y + st.strike_seconds * run_speed)


static func _add(by_lane: Array, l: int, from: float, to: float) -> void:
	if l >= 0 and l < by_lane.size():
		(by_lane[l] as Array).append(Vector2(from, to))


## `spans` (Vector2(start, end)) in order, overlapping ones merged.
static func merged(spans: Array) -> PackedVector2Array:
	spans.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var out := PackedVector2Array()
	for s: Vector2 in spans:
		if not out.is_empty() and s.x <= out[-1].y:
			out[-1] = Vector2(out[-1].x, maxf(out[-1].y, s.y))
		else:
			out.append(s)
	return out


## True if a stretch of `spans` (merged, in order) reaches into [from, to].
static func hit(spans: PackedVector2Array, from: float, to: float) -> bool:
	var i: int = first(spans, from)
	return i < spans.size() and spans[i].x <= to


## The first stretch of `spans` (merged, in order) that ends at or after `from`.
static func first(spans: PackedVector2Array, from: float) -> int:
	var lo: int = 0
	var hi: int = spans.size()
	while lo < hi:
		var mid: int = (lo + hi) >> 1
		if spans[mid].y < from:
			lo = mid + 1
		else:
			hi = mid
	return lo


# --- A showing's needs (the layout's side) --------------------------------------------------------------

## How long it can stay alongside on a showing starting with the runner at `d` and its front `gap` behind them
## (`v`: the run speed): show_seconds, or less so it's back behind the runner show_margin_seconds (and
## close_lead_seconds) before `to_bait` seconds from now, show_margin_seconds before `to_fixed` seconds from now (an
## attack that can't wait for a turn, task C6e: fixed) and before `chase_left` seconds from now. Under
## show_min_seconds: no showing.
static func hold_for(t: EnforcerTruckTuning, gap: float, to_bait: float, chase_left: float, to_fixed: float = INF) -> float:
	var close_in: float = t.show_close_seconds(gap)
	var drop: float = t.ease_seconds(t.follow_gap + t.show_ahead, t.show_drop_speed)
	var room_left: float = minf(minf(to_bait - t.show_margin_seconds - t.close_lead_seconds, chase_left),
		to_fixed - t.show_margin_seconds)
	return minf(t.show_seconds, room_left - close_in - drop)


## hold_for for a showing a Buzz Overdrive's claim on its turn may come during (task C6e; ShowPlanner's CLAIM and CALM
## modes, the owner's answer to docs/OPEN_QUESTIONS.md item 400: it shows itself before the bait, the bait staying
## where it is): the claim only holds back the attacks that get ready during it, and one begun before it carries on,
## so the showing need only be out of view (no longer holding the turn) show_margin_seconds before the tank's rev, its
## warning, `to_rev` seconds from now; and back behind the runner, as hold_for, show_margin_seconds and
## close_lead_seconds before an Octodog's wind-up `to_dog` seconds from now (it closes up for it), show_margin_seconds
## before `to_fixed` and before `chase_left`.
static func hold_claimed(t: EnforcerTruckTuning, gap: float, to_rev: float, to_dog: float, chase_left: float,
		to_fixed: float = INF) -> float:
	var close_in: float = t.show_close_seconds(gap)
	var out_of_view: float = t.show_drop_view_seconds(OUT_OF_VIEW)
	var by_rev: float = to_rev - t.show_margin_seconds - close_in - out_of_view
	return minf(by_rev, hold_for(t, gap, to_dog, chase_left, to_fixed))


## Seconds of running from `d` until the next of the layout's baits' turns (INF: none).
func seconds_to_bait(d: float, v: float) -> float:
	var i: int = baits.bsearch(d - 1.0)
	return maxf(baits[i] - d, 0.0) / maxf(v, 0.01) if i < baits.size() else INF


## Seconds of running from `d` until the next of `marks` (runner distances, in order: dog_turns, revs; INF: none).
static func seconds_to(marks: PackedFloat32Array, d: float, v: float) -> float:
	var i: int = marks.bsearch(d - 1.0)
	return maxf(marks[i] - d, 0.0) / maxf(v, 0.01) if i < marks.size() else INF


## Seconds of running from `d` until the next attack that can't wait for a turn (fixed) begins: 0 while one is on,
## INF: none.
func seconds_to_fixed(d: float, v: float) -> float:
	for f: Vector2 in fixed:
		if f.y >= d:
			return maxf(f.x - d, 0.0) / maxf(v, 0.01)
	return INF


## True if an attack that can't wait for a turn (fixed) is on anywhere from `from` to `to`.
func fixed_in(from: float, to: float) -> bool:
	for f: Vector2 in fixed:
		if f.x <= to and f.y >= from:
			return true
	return false


## The lanes a hover truck holds anywhere from `from` to `to` (held), by lane: walls to the runner, never its lane.
func held_lanes(from: float, to: float) -> Array[bool]:
	var out: Array[bool] = []
	for l: int in held.size():
		out.append(hit(held[l], from, to))
	return out


## True if lane `l` is one of `held` (held_lanes; [] holds none).
static func is_held(held_by_lane: Array[bool], l: int) -> bool:
	return l >= 0 and l < held_by_lane.size() and held_by_lane[l]


## True if one of the layout's enemies that keep it from showing itself comes into play within `seconds` of
## running from `d` (or is still about from just before).
func quiet_near(d: float, seconds: float, v: float) -> bool:
	var to: float = d + seconds * v
	for q: Vector2 in quiet:
		if q.x > to:
			break
		if q.y >= d - 10.0:
			return true
	return false


## True if lane `l` suits a showing starting with the runner at `d`, its front `gap` behind them, taking `total`
## seconds at `v`: nothing that would wreck it until it's back in the runner's lane, and where it's in view nothing
## it would drive through or the runner may need: for its shortest showing (show_min_seconds alongside: it drops
## back sooner before anything in its lane ahead, EnforcerTruck._lane_ahead_clear), or with `alongside` for that
## many seconds alongside (the generator plans a whole stay, task C6c).
func lane_clear(l: int, t: EnforcerTruckTuning, d: float, gap: float, total: float, v: float,
		alongside: float = -1.0) -> bool:
	var rear: float = d - minf(gap, t.follow_gap + 2.0) - t.body_size.z - 1.0
	if hit(deadly[l], rear, d + (total + t.show_margin_seconds + t.switch_seconds) * v):
		return false
	var span: Vector2 = view_stretch(t, d, gap, v, alongside)
	return not hit(solid[l], span.x, span.y) and not hit(soft[l], span.x, span.y)


## The stretch of its lane a showing starting now has in view: from its rear where it comes into view (OUT_OF_VIEW
## behind the runner) to where its front gets before it has dropped back out of view after `alongside` seconds
## alongside (show_min_seconds, its shortest showing, when negative).
static func view_stretch(t: EnforcerTruckTuning, d: float, gap: float, v: float, alongside: float = -1.0) -> Vector2:
	var stay: float = t.show_min_seconds if alongside < 0.0 else alongside
	var into_view: float = maxf(gap - t.follow_gap, 0.0) / maxf(t.gap_speed_max, 0.01) \
		+ maxf(minf(gap, t.follow_gap) - OUT_OF_VIEW, 0.0) / maxf(t.show_close_speed, 0.01)
	var from: float = d + into_view * v - OUT_OF_VIEW - t.body_size.z - 1.0
	var to: float = d + (t.show_close_seconds(gap) + stay + t.show_drop_view_seconds(OUT_OF_VIEW)) * v \
		- OUT_OF_VIEW + 2.0
	return Vector2(from, to)


## The one lane a runner in lane `r` has to dodge into while the truck holds lane `l`: the lane on their other side
## while it's beside them, or the lane between them while it's two lanes in from a runner by a wall (sides(), task
## C6c). -1 when it leaves them none (beside them, with a wall on their other side); -2 when it doesn't hem them in
## (further off, or two lanes off with a lane on each side of them). A lane a hover truck holds (`held`, held_lanes;
## task C6e) is a wall to them: its sides are solid.
func escape_lane(r: int, l: int, held_by_lane: Array[bool] = []) -> int:
	var n: int = hard.size()
	match absi(l - r):
		1:
			var o: int = 2 * r - l
			return o if o >= 0 and o < n and not is_held(held_by_lane, o) else -1
		2:
			var other: int = r - signi(l - r)
			return (r + l) / 2 if other < 0 or other >= n or is_held(held_by_lane, other) else -2
		0:
			return -1
	return -2


## True if a runner in lane `r` keeps a lane to dodge into for `seconds` from `d` while the truck holds lane `l`
## (GDD §9.13: it never takes the only free lane), as far as the layout goes, with room around each place to step
## across: wherever they must leave their lane (must_leave), the lane they dodge into (escape_lane: beside them on
## their other side, or between them and the truck two lanes in) is open (a zone doodad's push goes there too, its
## side toward the truck being solid); and wherever their lane is blocked otherwise (a hole or a fence they can jump),
## that lane is open or the truck's lane is blocked there as well (a row across the lanes: the truck takes no free
## lane, and hops its gap). Two lanes in, the lane between them is theirs to step into, beside the truck, with their
## own lane to dodge back into: it's held to the same rule. A lane a hover truck holds (`held`) counts as a wall.
## With `clip` (task C6e: the truck in play, and the generator's windows beside a hover truck or a Gilded Sentinel,
## ShowPlanner's modes after CLASSIC) the same rule holds stretch by stretch, for what its stay reaches of each: once
## it's back behind the runner every lane is theirs again (a Buzz Overdrive rolling in their lane ahead of its cut keeps
## that lane blocked for seconds past the showing); and a floor cut's lane is one they must leave only from its charge
## (leave_late: before it they may keep to it, behind the Buzz Overdrive, to bait the truck).
func can_dodge(r: int, l: int, t: EnforcerTruckTuning, d: float, seconds: float, v: float,
		held_by_lane: Array[bool] = [], clip: bool = false) -> bool:
	if r < 0 or r >= hard.size() or l < 0 or l >= hard.size() or is_held(held_by_lane, l):
		return false
	var o: int = escape_lane(r, l, held_by_lane)
	if o == -2:
		return true
	if o < 0:
		return false
	var to: float = d + (seconds + t.show_margin_seconds) * v
	var step: float = DODGE_ROOM_SECONDS * v
	if not _dodges(r, o, l, d, to, step, clip):
		return false
	return absi(l - r) != 2 or _dodges(o, r, l, d, to, step, clip)


## True if wherever lane `mine` is blocked between `from` and `to` (with `clip`, only that part of each blocked
## stretch), lane `escape` is open around it (`step` either
## side), or `mine` holds only something to jump or slide there and the truck's lane `truck` is blocked too
## (can_dodge).
func _dodges(mine: int, escape: int, truck: int, from: float, to: float, step: float, clip: bool = false) -> bool:
	if clip:
		# Stretch by stretch (task C6e): around each place they must leave their lane the escape is open; around each
		# hole or fence they'd jump it's open or the truck's lane is blocked there too.
		for c: Vector2 in within(leave_late[mine], from, to):
			if hit(hard[escape], c.x - step, c.y + step):
				return false
		for c: Vector2 in within(jump[mine], from, to):
			if hit(hard[escape], c.x - step, c.y + step) and not hit(hard[truck], c.x, c.y):
				return false
		return true
	var spans: PackedVector2Array = hard[mine]
	var i: int = first(spans, from)
	while i < spans.size() and spans[i].x <= to:
		var span: Vector2 = spans[i]
		if hit(hard[escape], span.x - step, span.y + step) \
				and (hit(must_leave[mine], span.x, span.y) or not hit(hard[truck], span.x, span.y)):
			return false
		i += 1
	return true


## The stretches of `spans` (merged, in order) that reach into [from, to], each cut to it.
static func within(spans: PackedVector2Array, from: float, to: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var i: int = first(spans, from)
	while i < spans.size() and spans[i].x <= to:
		out.append(Vector2(maxf(spans[i].x, from), minf(spans[i].y, to)))
		i += 1
	return out


## True if none of the layout's enemies stands in lane `l` or beyond it (toward that side's wall, away from the
## runner's lane `r`) between just behind the runner at `d` and show_shadow_reach ahead of where the runner is
## `seconds` later: from the camera the truck would hide one there. Nor does a hover truck hold such a lane (`held`,
## held_lanes; task C6e): it paces the runner from behind them to ahead, so the truck stays on their other side.
func shadow_clear(l: int, r: int, t: EnforcerTruckTuning, d: float, seconds: float, v: float,
		held_by_lane: Array[bool] = []) -> bool:
	var side: float = signf(float(l - r))
	if side == 0.0:
		return false
	for h: int in held_by_lane.size():
		if held_by_lane[h] and signf(float(h - r)) == side and absi(h - r) >= absi(l - r):
			return false
	var edge: float = geo.lane_x(l) - side * geo.lane_width * 0.5
	var to: float = d + seconds * v + t.show_shadow_reach
	var lo: int = 0
	var hi: int = planned.size()
	while lo < hi:
		var mid: int = (lo + hi) >> 1
		if planned[mid].x < d - 3.0:
			lo = mid + 1
		else:
			hi = mid
	while lo < planned.size() and planned[lo].x <= to:
		if (planned[lo].y - edge) * side > 0.0:
			return false
		lo += 1
	return true


## The lanes a showing beside a runner in lane `r` may take, the outer one first (the camera sits inward of the
## runner, so the truck there covers less of the street); `seed` picks the side for a runner in the middle lane.
## A runner in an outer lane (by a wall) has one: two lanes in, the lane between them left free for them to dodge
## into (escape_lane; the owner, October 9, 2026, GDD §9.13 "Room to show itself", answering docs/OPEN_QUESTIONS.md
## item 382): beside them on their inner side it would take their only lane to dodge into, and at 5 and 6 lanes it
## would stand under the camera (which sits inward of a runner by a wall) and hide up to 25 m of the floor of their
## lane; two lanes in it hides nothing of their lane or the lane between (EnforcerTruckView.check). A lane a hover
## truck holds (`held`, held_lanes; task C6e, the owner, October 9, 2026: it may show itself while one is around, as
## long as the runner keeps a free lane) is a wall to them too (its sides are solid) and never the truck's: beside
## one, it shows itself two lanes in on their other side, the lane between left free.
func sides(r: int, seed: int, held_by_lane: Array[bool] = []) -> Array[int]:
	var n: int = hard.size()
	var out: Array[int] = []
	var wall_left: bool = r <= 0 or is_held(held_by_lane, r - 1)
	var wall_right: bool = r >= n - 1 or is_held(held_by_lane, r + 1)
	if wall_left or wall_right:
		if wall_left and wall_right:
			return out
		var l: int = r + (2 if wall_left else -2)
		if l >= 0 and l < n and not is_held(held_by_lane, l):
			out.append(l)
		return out
	var out_side: int = int(signf(geo.lane_x(r)))
	if out_side == 0:
		out_side = 1 if seed % 2 == 0 else -1
	out.append(r + out_side)
	out.append(r - out_side)
	return out


## Whether the truck's look fits on screen beside a runner, hiding neither them nor the floor of their lane, the
## lanes past it and any lane between them and the truck (EnforcerTruckView.check, to 60 m ahead), with every
## rider it may carry, in every one of its looks (so the layout's plan is the same in every zone's skin), for every
## pair of a runner lane and a lane it may show itself in (sides(): next to a runner with a lane on each side, two
## lanes in from one by a wall, and two lanes in from one beside an outer lane a hover truck holds, task C6e) at `lanes`
## lanes: runner lane * 64 + truck lane. (A hover truck holds the outer lane on its side, HoverTruckRules.)
static func fits_for(mt: MovementTuning, t: EnforcerTruckTuning, lanes: int) -> Dictionary:
	var out: Dictionary = {}
	var profiles: Array = []
	for look: StringName in EnforcerTruckModel.LOOKS:
		profiles.append(EnforcerTruckModel.profile(look, t.body_size, EnforcerTruckModel.RIDER_SLOTS.size()))
	for r: int in lanes:
		var ls: Array[int] = []
		if r > 0 and r < lanes - 1:
			ls.append_array([r - 1, r + 1])
			if r == 1:
				ls.append(3)
			if r == lanes - 2:
				ls.append(lanes - 4)
		else:
			ls.append(r + (2 if r == 0 else -2))
		for l: int in ls:
			if l < 0 or l >= lanes or out.has(r * 64 + l):
				continue
			var ok: bool = true
			for profile: Array[AABB] in profiles:
				var c: Dictionary = EnforcerTruckView.check(mt, lanes, r, l, t.show_ahead, profile)
				ok = ok and bool(c["fits"]) and not bool(c["hides_runner"]) and not bool(c["hides_floor"])
			out[r * 64 + l] = ok
	return out


## The lane a showing beside a runner in lane `r` may take as far as the layout goes (show_lane_now's layout side;
## the generator plans each chase's showing with it, task C6c), or -1: starting with the runner at `d` and its front
## `gap` behind them at `v`, staying alongside `hold` seconds, where its look fits (`fits`: fits_for()), its lane stays
## clear for that whole stay (lane_clear), the runner keeps a lane to dodge into (can_dodge) and it would hide none of
## the layout's enemies (shadow_clear), a lane a hover truck holds meanwhile counting as a wall (held_lanes; task C6e;
## `clip`: can_dodge's). `seed` picks the side for a runner in the middle lane (sides()).
func layout_lane(r: int, t: EnforcerTruckTuning, fits: Dictionary, d: float, gap: float, hold: float, v: float,
		seed: int, clip: bool = false) -> int:
	var total: float = t.show_total_seconds(gap, hold)
	var held_by_lane: Array[bool] = _held_for(t, d, total, v)
	for l: int in sides(r, seed, held_by_lane):
		if bool(fits.get(r * 64 + l, false)) and lane_clear(l, t, d, gap, total, v, hold) \
				and can_dodge(r, l, t, d, total, v, held_by_lane, clip) and shadow_clear(l, r, t, d, total, v, held_by_lane):
			return l
	return -1


## True if no showing starting with the runner at `d` and its front `gap` behind them could ever stand beside a runner
## in lane `r` (task C6e): every lane it may take beside them (sides()) is one a hover truck holds, one between them and
## a hover truck (it would hide it: shadow_clear), or one a floor cut or a gap too wide to hop would wreck it in (deadly:
## a Buzz Overdrive rolls ahead of its cut there), or there's none (at 3 lanes, a hover truck's lane beside a runner in
## the middle). The generator's windows beside a hover truck or a Gilded Sentinel, or with their bait's claim during
## them, leave out such a runner lane (ShowPlanner._lanes_fail): nothing taken out could make room there.
func unreachable(r: int, t: EnforcerTruckTuning, d: float, gap: float, hold: float, v: float, seed: int) -> bool:
	var total: float = t.show_total_seconds(gap, hold)
	var held_by_lane: Array[bool] = _held_for(t, d, total, v)
	var rear: float = d - minf(gap, t.follow_gap + 2.0) - t.body_size.z - 1.0
	for l: int in sides(r, seed, held_by_lane):
		if is_held(held_by_lane, l) or hit(deadly[l], rear, d + (total + t.show_margin_seconds + t.switch_seconds) * v):
			continue
		var hides: bool = false
		for h: int in held_by_lane.size():
			hides = hides or (held_by_lane[h] and signi(h - r) == signi(l - r) and absi(h - r) >= absi(l - r))
		if not hides:
			return false
	return true


## The lanes a hover truck holds over the stretch a showing starting at `d` that takes `total` seconds reads (held_lanes).
func _held_for(t: EnforcerTruckTuning, d: float, total: float, v: float) -> Array[bool]:
	return held_lanes(d - OUT_OF_VIEW - t.body_size.z - 1.0, d + (total + t.show_margin_seconds) * v + t.show_shadow_reach)
