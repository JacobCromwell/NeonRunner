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
## - solid: what the truck never drives through on screen (fences, doodads, floor enemies);
## - soft: what the runner may need (pads, speed pads, ramps);
## - deadly: what would wreck it (gaps too wide to hop, floor cuts' lane windows); it hops the other gaps.
## And: where its baits' turns begin (an Octodog's planned wind-ups; a Buzz Overdrive's claim on its turn before
## its rev), where the enemies that keep it from showing itself come into play (NO_SHOW_TYPES), and
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
## DESIGN-TBD (docs/questions/c6b.md): enemies that keep it from showing itself while one is in play or coming:
## the hover truck (a mini-boss holding an outer lane) and the Gilded Sentinel (its strike can't wait for a turn:
## it would let the runner pass). Others wait for its showing's turn as for a volley's (a Resonator's pulse moves
## on).
const NO_SHOW_TYPES: Array[StringName] = [&"hover_truck", &"gilded_sentinel"]
## Enemies that stay where the layout puts them over a lane, off the floor (a Barnacle Turret under its ceiling): the
## layout's shadow counts them where they hang (task C6c), as the truck's in play does.
const HANGS_OVER_LANE: PackedStringArray = ["barnacle_turret"]
const TYPE: String = "enforcer_truck"
const BuzzRules = preload("res://scripts/enemies/buzz_overdrive_rules.gd")

var geo: TrackGeometry
var hard: Array[PackedVector2Array] = []
var must_leave: Array[PackedVector2Array] = []
var solid: Array[PackedVector2Array] = []
var soft: Array[PackedVector2Array] = []
var deadly: Array[PackedVector2Array] = []
## Where its baits' turns begin (runner distances, in order).
var baits: PackedFloat32Array = PackedFloat32Array()
## The enemies that keep it from showing itself: Vector2(where one comes into play, its `at`), in order.
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
	var by: Dictionary = {"hard": [], "must": [], "solid": [], "soft": [], "deadly": []}
	for key: String in by:
		for l: int in lanes:
			(by[key] as Array).append([])
	var too_wide: float = t.max_hop_jump_fraction * mt.jump_distance(run_speed) + 0.001
	for g: Dictionary in layout.gaps:
		var from: float = float(g["start"])
		var to: float = float(g["end"])
		_add(by["hard"], int(g["lane"]), from, to)
		if to - from > too_wide:
			_add(by["deadly"], int(g["lane"]), from, to)
	for c: Dictionary in layout.cuts:
		var w: Vector2 = FloorCutPlan.lane_window(c)
		for key: String in ["hard", "must", "deadly"]:
			_add(by[key], int(c["lane"]), minf(w.x, float(c["start"])), w.y)
	var half: float = mt.fence_depth * 0.5 + 0.5
	for f: Dictionary in layout.fences:
		for key: String in ["hard", "solid"]:
			_add(by[key], int(f["lane"]), float(f["at"]) - half, float(f["at"]) + half)
	for d: Dictionary in layout.doodads:
		for key: String in ["hard", "must", "solid"]:
			_add(by[key], int(d["lane"]), float(d["start"]), float(d["end"]))
	for p: Dictionary in layout.pads:
		_add(by["soft"], int(p["lane"]), float(p["at"]) - mt.pad_length, float(p["at"]) + mt.pad_length)
	for p: Dictionary in layout.speed_pads:
		_add(by["soft"], int(p["lane"]), float(p["at"]) - mt.speed_pad_length, float(p["at"]) + mt.speed_pad_length)
	for r: Dictionary in layout.ramps:
		_add(by["soft"], layout.outer_lane(int(r["side"])), float(r["at"]) - mt.ramp_length, float(r["at"]) + mt.ramp_length)
	var warns: Array[float] = []
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
			"buzz_overdrive":
				var cut: Dictionary = BuzzRules.cut_of(layout, e)
				if not cut.is_empty():
					var claim: float = float(cut.get("claim_seconds", buzz.claim_seconds if buzz != null else 2.5))
					warns.append(FloorCutPlan.warn_at(cut) - maxf(claim, least_claim) * run_speed)
		if StringName(type) in NO_SHOW_TYPES:
			var et := EnemyDirector.tuning_for(type) as EnemyTuning
			room.quiet.append(Vector2(at - (et.spawn_lead if et != null else 100.0), at))
		if LevelGenerator.enemy_uses_floor(e):
			var span: Vector2 = LevelGenerator.enemy_floor_span(e, pace)
			if span.x > span.y:
				span = Vector2(at, at)
			for key: String in ["hard", "must", "solid"]:
				_add(by[key], int(e.get("lane", 0)), span.x - ENEMY_ROOM, span.y + ENEMY_ROOM)
			room.planned.append(Vector2(at, geometry.lane_x(clampi(int(e.get("lane", 0)), 0, lanes - 1))))
		elif int(e.get("side", 0)) != 0:
			room.planned.append(Vector2(at, signf(float(e["side"])) * geometry.wall_x()))
		elif HANGS_OVER_LANE.has(type):
			room.planned.append(Vector2(at, geometry.lane_x(clampi(int(e.get("lane", 0)), 0, lanes - 1))))
	warns.sort()
	room.baits = PackedFloat32Array(warns)
	room.quiet.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	room.planned.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	for l: int in lanes:
		room.hard.append(merged(by["hard"][l]))
		room.must_leave.append(merged(by["must"][l]))
		room.solid.append(merged(by["solid"][l]))
		room.soft.append(merged(by["soft"][l]))
		room.deadly.append(merged(by["deadly"][l]))
	return room


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
## close_lead_seconds) before `to_bait` seconds from now and before `chase_left` seconds from now. Under
## show_min_seconds: no showing.
static func hold_for(t: EnforcerTruckTuning, gap: float, to_bait: float, chase_left: float) -> float:
	var close_in: float = t.show_close_seconds(gap)
	var drop: float = t.ease_seconds(t.follow_gap + t.show_ahead, t.show_drop_speed)
	var room_left: float = minf(to_bait - t.show_margin_seconds - t.close_lead_seconds, chase_left)
	return minf(t.show_seconds, room_left - close_in - drop)


## Seconds of running from `d` until the next of the layout's baits' turns (INF: none).
func seconds_to_bait(d: float, v: float) -> float:
	var i: int = baits.bsearch(d - 1.0)
	return maxf(baits[i] - d, 0.0) / maxf(v, 0.01) if i < baits.size() else INF


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
## (further off, or two lanes off with a lane on each side of them).
func escape_lane(r: int, l: int) -> int:
	var n: int = hard.size()
	match absi(l - r):
		1:
			var o: int = 2 * r - l
			return o if o >= 0 and o < n else -1
		2:
			var other: int = r - signi(l - r)
			return (r + l) / 2 if other < 0 or other >= n else -2
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
## own lane to dodge back into: it's held to the same rule.
func can_dodge(r: int, l: int, t: EnforcerTruckTuning, d: float, seconds: float, v: float) -> bool:
	if r < 0 or r >= hard.size() or l < 0 or l >= hard.size():
		return false
	var o: int = escape_lane(r, l)
	if o == -2:
		return true
	if o < 0:
		return false
	var to: float = d + (seconds + t.show_margin_seconds) * v
	var step: float = DODGE_ROOM_SECONDS * v
	if not _dodges(r, o, l, d, to, step):
		return false
	return absi(l - r) != 2 or _dodges(o, r, l, d, to, step)


## True if wherever lane `mine` is blocked between `from` and `to`, lane `escape` is open around it (`step` either
## side), or `mine` holds only something to jump or slide there and the truck's lane `truck` is blocked too
## (can_dodge).
func _dodges(mine: int, escape: int, truck: int, from: float, to: float, step: float) -> bool:
	var spans: PackedVector2Array = hard[mine]
	var i: int = first(spans, from)
	while i < spans.size() and spans[i].x <= to:
		var span: Vector2 = spans[i]
		if hit(hard[escape], span.x - step, span.y + step) \
				and (hit(must_leave[mine], span.x, span.y) or not hit(hard[truck], span.x, span.y)):
			return false
		i += 1
	return true


## True if none of the layout's enemies stands in lane `l` or beyond it (toward that side's wall, away from the
## runner's lane `r`) between just behind the runner at `d` and show_shadow_reach ahead of where the runner is
## `seconds` later: from the camera the truck would hide one there.
func shadow_clear(l: int, r: int, t: EnforcerTruckTuning, d: float, seconds: float, v: float) -> bool:
	var side: float = signf(float(l - r))
	if side == 0.0:
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
## into (escape_lane). DESIGN-TBD (docs/questions/c6c.md, task C6c): beside them on their inner side it would take
## their only lane to dodge into, and at 5 and 6 lanes it would stand under the camera (which sits inward of a
## runner by a wall) and hide up to 25 m of the floor of their lane; two lanes in it hides nothing of their lane
## or the lane between (EnforcerTruckView.check).
func sides(r: int, seed: int) -> Array[int]:
	var n: int = hard.size()
	var out: Array[int] = []
	if r <= 0 or r >= n - 1:
		var l: int = r + (2 if r <= 0 else -2)
		if l >= 0 and l < n:
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
## pair of a runner lane and a lane it may show itself in beside them (sides(): next to a runner with a lane on each
## side, two lanes in from one by a wall) at `lanes` lanes: runner lane * 64 + truck lane.
static func fits_for(mt: MovementTuning, t: EnforcerTruckTuning, lanes: int) -> Dictionary:
	var out: Dictionary = {}
	var profiles: Array = []
	for look: StringName in EnforcerTruckModel.LOOKS:
		profiles.append(EnforcerTruckModel.profile(look, t.body_size, EnforcerTruckModel.RIDER_SLOTS.size()))
	for r: int in lanes:
		var ls: Array[int] = []
		if r > 0 and r < lanes - 1:
			ls.append_array([r - 1, r + 1])
		else:
			ls.append(r + (2 if r == 0 else -2))
		for l: int in ls:
			if l < 0 or l >= lanes:
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
## the layout's enemies (shadow_clear). `seed` picks the side for a runner in the middle lane (sides()).
func layout_lane(r: int, t: EnforcerTruckTuning, fits: Dictionary, d: float, gap: float, hold: float, v: float,
		seed: int) -> int:
	var total: float = t.show_total_seconds(gap, hold)
	for l: int in sides(r, seed):
		if bool(fits.get(r * 64 + l, false)) and lane_clear(l, t, d, gap, total, v, hold) \
				and can_dodge(r, l, t, d, total, v) and shadow_clear(l, r, t, d, total, v):
			return l
	return -1
