class_name MechaGuppyCrescent
extends RefCounted
## Mecha Guppy's floor bite as the plan has it (GDD §10, the owner, October 11, 2026, "The floor bite"; task E5e-f): the
## crescent it bites out of a roof while the runner is still running on it, from one side of the floor, deepest in the
## middle and shallower at its front and back, like a shark's bite (the owner's sketch), its edge scalloped by its teeth.
## Pure numbers: MechaGuppyClimb plans one on the roofs it names, and the suites check them without the engine.
## Its edge is a polyline (`ds`, `ws`: track distances, and how far in from the bitten side's wall the gap reaches at
## each); the roof's collision (MechaGuppyStairs) and its look (MechaGuppyLooks) both follow it, so what looks like a
## hole is a hole, exactly.
## - A bite that leaves one lane (`keep`, phase 1's and every other one of phase 2's): at its deepest it reaches exactly
##   the inner edge of the outer lane on the far side (it takes 2 of 3 lanes there, 4 of 5, 5 of 6), fewer toward its
##   front and back.
## - A full-width bite (`full`, phase 2's): it crosses the whole floor over `through` of its length (cut_from to cut_to),
##   and its longest stretch along the track, at the bitten side, is shorter than a normal jump covers (the plan sizes it
##   so: MechaGuppyTuning.full_jump_share): every lane can jump it, the far side's shortest.
## Its moments (track distances, the plan's): its warning shows at `warn_at` (MechaGuppyPattern), its jaws have snapped by
## `snap_at`. Its state, set as the fight goes (as Roof.end is moved when a roof is bitten): `warned` once its warning
## shows (MechaGuppyClimb.Roof.covers counts the gap from then on), `eaten` once the chunk is gone, `skipped` if it never
## came (an intro, phase 3, the shark too busy: as if it had never been planned).
## DESIGN-TBD (docs/OPEN_QUESTIONS.md item 812): the shape and its teeth.

## The scallops: this many teeth along the bite, the edge bulging back toward the floor between two of them by up to
## TOOTH_BULGE (metres), less toward its ends; a tooth at the deepest point, so a bite that leaves a lane reaches its edge
## exactly there. (An even count puts a tooth in the middle.)
const TEETH: int = 12
const TOOTH_BULGE: float = 0.3
## Points along its edge from its front to its back (the collision and the look both follow them).
const POINTS: int = 65
## The gap counts as reaching a point only past this (metres): its edge points are single precision, and the lane a bite
## leaves has its edge exactly at its deepest point (task E5e-f's review: at 4 and 6 lanes the rounding gave that lane a
## stretch of no length, and a warning token).
const EDGE_EPS: float = 0.001

## The roof it's on (MechaGuppyClimb.Roof.index).
var roof: int = 0
## The side it bites from: -1 the left (lane 0's wall), +1 the right.
var side: int = -1
## Where it starts and ends along the track (track distances), and how far in from the bitten side's wall its base
## reaches at the deepest (metres; a full-width bite's goes past the far wall).
var from: float = 0.0
var to: float = 0.0
var depth: float = 0.0
var full: bool = false
## The lane it leaves (the far side's outer lane), or -1 when it's full width.
var keep: int = -1
## A full-width bite crosses the whole floor from cut_from to cut_to (track distances); otherwise cut_from > cut_to.
var cut_from: float = 1.0
var cut_to: float = 0.0
var warn_at: float = 0.0
var snap_at: float = 0.0
var warned: bool = false
var eaten: bool = false
var skipped: bool = false
## The edge, front to back: track distances, and how far in from the bitten side's wall the gap reaches at each (at most
## the floor's width, 2 * wall).
var ds := PackedFloat32Array()
var ws := PackedFloat32Array()
## The floor it bites (TrackGeometry's numbers) and the runner's footprint (its half width and half depth).
var lanes: int = 3
var lane_width: float = 2.4
var wall: float = 3.9
var foot := Vector2(0.3, 0.25)


## A bite on roof `p_roof` from side `p_side`, starting at track distance `p_from`, `p_length` long at the bitten side;
## `p_full` crosses every lane (over `through` of its length), else it leaves the far side's outer lane. `geo`: the
## floor's lanes; `p_foot`: the runner's footprint (MovementTuning.foot_half_width, foot_half_depth).
static func make(p_roof: int, p_side: int, p_from: float, p_length: float, p_full: bool, through: float,
		geo: TrackGeometry, p_foot: Vector2) -> MechaGuppyCrescent:
	var out := MechaGuppyCrescent.new()
	out.roof = p_roof
	out.side = -1 if p_side < 0 else 1
	out.from = p_from
	out.to = p_from + maxf(p_length, 0.5)
	out.full = p_full
	out.lanes = geo.lane_count
	out.lane_width = geo.lane_width
	out.wall = geo.wall_x()
	out.foot = p_foot
	if p_full:
		out.keep = -1
		out.depth = out.width() / sqrt(maxf(1.0 - through * through, 0.01))
	else:
		out.keep = geo.lane_count - 1 if out.side < 0 else 0
		var span: Vector2 = geo.lane_floor_span(out.keep)
		out.depth = out.w_of(span.x if out.side < 0 else span.y)
	out._sample()
	return out


## The floor's width (wall to wall).
func width() -> float:
	return wall * 2.0


## How far in from the bitten side's wall world x `x` is (0 at that wall, width() at the far one).
func w_of(x: float) -> float:
	return wall - float(side) * x


## World x of the point `w` in from the bitten side's wall.
func x_of(w: float) -> float:
	return float(side) * (wall - w)


## How far in from the bitten side's wall the gap reaches at track distance `d` (0 outside the bite; at most width()).
func depth_at(d: float) -> float:
	if d <= from or d >= to or ds.size() < 2:
		return 0.0
	var lo: int = 0
	var hi: int = ds.size() - 1
	while hi - lo > 1:
		var mid: int = (lo + hi) >> 1
		if ds[mid] <= d:
			lo = mid
		else:
			hi = mid
	var span: float = ds[hi] - ds[lo]
	var k: float = (d - ds[lo]) / span if span > 0.0001 else 0.0
	return lerpf(ws[lo], ws[hi], clampf(k, 0.0, 1.0))


## True if world point (x, d) is in the gap.
func in_gap(x: float, d: float) -> bool:
	return w_of(x) < depth_at(d)


## World x of the lane's middle (TrackGeometry.lane_x).
func lane_x(lane: int) -> float:
	return (float(lane) - (lanes - 1) * 0.5) * lane_width


## How far in from the bitten side's wall a runner's footprint in `lane` comes nearest to it (its corner on that side).
func near_w(lane: int) -> float:
	return w_of(lane_x(lane) + float(side) * foot.x)


## How far in from the bitten side's wall a runner's footprint in `lane` reaches furthest (its corner on the far side).
func far_w(lane: int) -> float:
	return w_of(lane_x(lane) - float(side) * foot.x)


## True if the gap reaches into a runner's footprint in `lane` at track distance `d`: the lane isn't wholly floor there.
func takes(lane: int, d: float) -> bool:
	return depth_at(d) > near_w(lane) + EDGE_EPS


## The lanes it takes at track distance `d` (some of a runner's footprint over the gap).
func taken_at(d: float) -> Array[int]:
	var out: Array[int] = []
	for lane: int in lanes:
		if takes(lane, d):
			out.append(lane)
	return out


## The lanes it never takes anywhere along it: the one a bite that leaves a lane leaves; none when it's full width.
func left() -> Array[int]:
	var most: float = 0.0
	for w: float in ws:
		most = maxf(most, w)
	var out: Array[int] = []
	for lane: int in lanes:
		if most <= near_w(lane) + EDGE_EPS:
			out.append(lane)
	return out


## The shallowest the gap is over track distances [a, b] (metres in from the bitten side's wall: the least at its edge's
## points there and at the ends; 0 where that's outside the bite).
func min_depth(a: float, b: float) -> float:
	if b < a:
		return 0.0
	var out: float = minf(depth_at(a), depth_at(b))
	for i: int in ds.size():
		if ds[i] > a and ds[i] < b:
			out = minf(out, ws[i])
	return out


## The deepest it reaches (metres in from the bitten side's wall; at most width()).
func deepest() -> float:
	var most: float = 0.0
	for w: float in ws:
		most = maxf(most, w)
	return most


## The stretch along the track where the gap reaches past `w` in from the bitten side's wall: Vector2(first, last), or
## Vector2(INF, -INF) where it never does.
func stretch(w: float) -> Vector2:
	var first: float = INF
	var last: float = -INF
	for i: int in ds.size() - 1:
		var a: float = ws[i] - w - EDGE_EPS
		var b: float = ws[i + 1] - w - EDGE_EPS
		if a <= 0.0 and b <= 0.0:
			continue
		var d0: float = ds[i]
		var d1: float = ds[i + 1]
		var lo: float = d0 if a > 0.0 else lerpf(d0, d1, a / (a - b))
		var hi: float = d1 if b > 0.0 else lerpf(d0, d1, a / (a - b))
		first = minf(first, lo)
		last = maxf(last, hi)
	return Vector2(first, last)


## Where `lane` loses its floor along the track anywhere across its floor's span (from its edge on the bitten side):
## Vector2(first, last), or Vector2(INF, -INF) where it keeps it all along. The longest stretch a runner in that lane
## could have to jump.
func lane_stretch(lane: int) -> Vector2:
	var lo: float = lane_x(lane) - lane_width * 0.5
	var hi: float = lane_x(lane) + lane_width * 0.5
	if lane == 0:
		lo = -wall
	if lane == lanes - 1:
		hi = wall
	return stretch(w_of(lo if side < 0 else hi))


## Where a runner in the middle of `lane` would have no floor under any of their feet (their footprint wholly over the
## gap): Vector2(first, last) of their middle along the track, or Vector2(INF, -INF) where they're never unsupported.
## (Player._support_top: a runner stands while any corner of their footprint is over floor.)
func lane_drop(lane: int) -> Vector2:
	var s: Vector2 = stretch(far_w(lane))
	if s.x > s.y:
		return s
	var a: float = s.x + foot.y
	var b: float = s.y - foot.y
	return Vector2(a, b) if a <= b else Vector2(INF, -INF)


## The edge's points over track distances [d0, d1] (clamped to the bite), front to back, as Vector2(x, d): world x and
## track distance, with the end points interpolated.
func edge(d0: float = -INF, d1: float = INF) -> PackedVector2Array:
	var out := PackedVector2Array()
	var a: float = maxf(d0, from)
	var b: float = minf(d1, to)
	if b <= a:
		return out
	out.append(Vector2(x_of(depth_at(a) if a > from else 0.0), a))
	for i: int in ds.size():
		if ds[i] > a + 0.0001 and ds[i] < b - 0.0001:
			out.append(Vector2(x_of(ws[i]), ds[i]))
	out.append(Vector2(x_of(depth_at(b) if b < to else 0.0), b))
	return out


## The edge front to back, sampled (see the header), the scallops tapering to nothing at its ends; a full-width bite's
## points where it meets the far wall added exactly, so each stretch between two points is either over the whole floor or
## not at all.
func _sample() -> void:
	ds = PackedFloat32Array()
	ws = PackedFloat32Array()
	var mid: float = (from + to) * 0.5
	var half: float = (to - from) * 0.5
	var raw_d := PackedFloat32Array()
	var raw_w := PackedFloat32Array()
	for i: int in POINTS:
		var th: float = PI * float(i) / float(POINTS - 1)
		var t: float = th * float(TEETH) / PI
		var f: float = t - floorf(t)
		var bump: float = 1.0 - (2.0 * f - 1.0) * (2.0 * f - 1.0)
		var base: float = depth * sin(th)
		# No bulge where the edge meets the far wall (a full-width bite's cut stays whole across the floor).
		var fade: float = clampf((width() - base) / TOOTH_BULGE, 0.0, 1.0)
		var w: float = base - TOOTH_BULGE * bump * sin(th) * fade
		raw_d.append(mid - half * cos(th))
		raw_w.append(clampf(w, 0.0, width()))
	raw_d[0] = from
	raw_d[POINTS - 1] = to
	raw_w[0] = 0.0
	raw_w[POINTS - 1] = 0.0
	var top: float = width()
	for i: int in POINTS:
		if i > 0:
			var a: float = raw_w[i - 1]
			var b: float = raw_w[i]
			# Where it reaches the far wall between two points, a point there.
			if (a < top - 0.0001) != (b < top - 0.0001) and absf(b - a) > 0.0001:
				var k: float = (top - a) / (b - a)
				var cross: float = lerpf(raw_d[i - 1], raw_d[i], k)
				if cross > ds[-1] + 0.0001 and cross < raw_d[i] - 0.0001:
					ds.append(cross)
					ws.append(top)
		ds.append(raw_d[i])
		ws.append(raw_w[i])
	cut_from = 1.0
	cut_to = 0.0
	if full:
		for i: int in ds.size():
			if ws[i] >= top - 0.0001:
				if cut_from > cut_to:
					cut_from = ds[i]
				cut_to = ds[i]
