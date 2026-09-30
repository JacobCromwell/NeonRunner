class_name CinePath
extends RefCounted
## Interpolation for the cinematic toolkit's paths (camera keys, actor keys). Each key (CineKey) has a
## time and says how the path comes into it from the key before (`move`):
## - SMOOTH: a flight through the keys with no jolt. A cubic (Hermite) curve whose velocity at each key
##   comes from its neighbours (a Catmull-Rom spline timed by the keys' times), so the speed changes
##   smoothly across keys and the timing follows them. Easing doesn't apply. Like a crane or a drone,
##   it can swing a little past a key: a path that must keep clear of something is checked by sampling
##   it (the cinematics tests do).
## - LINEAR: a straight move, its timing shaped by Tween's transition and ease types (`trans`,
##   `easing`): TRANS_SINE with EASE_IN_OUT starts and ends at rest, TRANS_LINEAR moves at one speed.
## - CUT: holds the key before, then jumps to this one at its time.
## Before the first key a path holds the first key's value, and after the last key the last one's.
## Values are Vector3 or float; angles have their own sampler (sample_angle).

enum Move { SMOOTH, LINEAR, CUT }

## Keys closer in time than this are one moment: the later one wins, as with a cut.
const MIN_SPAN: float = 0.0001


## The value at time `t` of a path through `keys` (CineKey resources, sorted by time) whose values right
## now are `values` (one per key, Vector3 or float; a key that follows an actor has moved with it).
## Null if there are no keys.
static func sample(keys: Array, values: Array, t: float) -> Variant:
	var n: int = keys.size()
	if n == 0 or values.size() != n:
		return null
	var i: int = index_at(keys, t)
	if i < 0:
		return values[0]
	if i >= n - 1:
		return values[n - 1]
	var a := keys[i] as CineKey
	var b := keys[i + 1] as CineKey
	var span: float = b.time - a.time
	if span < MIN_SPAN:
		return values[i + 1]
	var u: float = clampf((t - a.time) / span, 0.0, 1.0)
	match b.move:
		Move.CUT:
			return values[i]
		Move.LINEAR:
			return lerp(values[i], values[i + 1], eased(b, u))
	return hermite(values[i], tangent(keys, values, i), values[i + 1], tangent(keys, values, i + 1), span, u)


## A point at time `t` on a path whose keys may ride along with something that moves (a camera key that
## follows or watches an actor). Key k is at `ride.call(refs[k], time) + offsets[k]` at any time:
## `refs[k]` names what it rides with (empty: `offsets[k]` is a fixed point, and `ride` gives
## Vector3.ZERO for it). Between two keys riding with the same thing, the path rides along with it, its
## offset moving through the keys'; between any others it flies through where the keys will be at their
## own times. Either way its velocity carries on through the keys (SMOOTH), a LINEAR move blends the
## two keys as they are at the moment, and a CUT holds the key before (riding along if it rides).
## Before the first key and after the last, the path holds that key, riding along if it rides.
static func sample_riding(keys: Array, offsets: Array, refs: Array, ride: Callable, t: float) -> Vector3:
	var n: int = keys.size()
	if n == 0 or offsets.size() != n or refs.size() != n:
		return Vector3.ZERO
	var i: int = index_at(keys, t)
	if i < 0:
		return _now(offsets, refs, ride, 0, t)
	if i >= n - 1:
		return _now(offsets, refs, ride, n - 1, t)
	var a := keys[i] as CineKey
	var b := keys[i + 1] as CineKey
	var span: float = b.time - a.time
	if span < MIN_SPAN:
		return _now(offsets, refs, ride, i + 1, t)
	var u: float = clampf((t - a.time) / span, 0.0, 1.0)
	var same: bool = StringName(refs[i]) == StringName(refs[i + 1])
	match b.move:
		Move.CUT:
			return _now(offsets, refs, ride, i, t)
		Move.LINEAR:
			if same:
				return (ride.call(refs[i], t) as Vector3) + (offsets[i] as Vector3).lerp(offsets[i + 1], eased(b, u))
			return _now(offsets, refs, ride, i, t).lerp(_now(offsets, refs, ride, i + 1, t), eased(b, u))
	var m0: Vector3 = _riding_tangent(keys, offsets, refs, ride, i)
	var m1: Vector3 = _riding_tangent(keys, offsets, refs, ride, i + 1)
	if same and StringName(refs[i]) != &"":
		# Riding along: the offset moves through the keys; the thing ridden with carries the rest.
		var v0: Vector3 = _ride_velocity(ride, refs[i], a.time)
		var v1: Vector3 = _ride_velocity(ride, refs[i + 1], b.time)
		return (ride.call(refs[i], t) as Vector3) + hermite(offsets[i], m0 - v0, offsets[i + 1], m1 - v1, span, u)
	return hermite(_at_own_time(keys, offsets, refs, ride, i), m0, _at_own_time(keys, offsets, refs, ride, i + 1),
		m1, span, u)


## Key k of a riding path where it is at time `t`.
static func _now(offsets: Array, refs: Array, ride: Callable, k: int, t: float) -> Vector3:
	return (ride.call(refs[k], t) as Vector3) + (offsets[k] as Vector3)


## Key k of a riding path where it is at its own time.
static func _at_own_time(keys: Array, offsets: Array, refs: Array, ride: Callable, k: int) -> Vector3:
	return _now(offsets, refs, ride, k, (keys[k] as CineKey).time)


## The velocity a riding path passes key k with: from where its neighbours are at their own times.
static func _riding_tangent(keys: Array, offsets: Array, refs: Array, ride: Callable, k: int) -> Vector3:
	var n: int = keys.size()
	var key := keys[k] as CineKey
	var has_prev: bool = k > 0 and key.move != Move.CUT and key.time - (keys[k - 1] as CineKey).time >= MIN_SPAN
	var has_next: bool = k < n - 1 and (keys[k + 1] as CineKey).move != Move.CUT \
		and (keys[k + 1] as CineKey).time - key.time >= MIN_SPAN
	var lo: int = k - 1 if has_prev else k
	var hi: int = k + 1 if has_next else k
	if lo == hi:
		return _ride_velocity(ride, refs[k], key.time)
	return (_at_own_time(keys, offsets, refs, ride, hi) - _at_own_time(keys, offsets, refs, ride, lo)) \
		/ ((keys[hi] as CineKey).time - (keys[lo] as CineKey).time)


## How fast the thing `ref` names moves at time `t` (zero for a fixed point).
static func _ride_velocity(ride: Callable, ref: StringName, t: float) -> Vector3:
	if ref == &"":
		return Vector3.ZERO
	var h: float = 1.0 / 60.0
	return ((ride.call(ref, t + h) as Vector3) - (ride.call(ref, t - h) as Vector3)) / (2.0 * h)


## An angle (radians) at time `t` through `keys` and their `angles`: turned the short way round, timed
## like a LINEAR move (a SMOOTH key turns with a sine ease), and a CUT jumps.
static func sample_angle(keys: Array, angles: PackedFloat32Array, t: float) -> float:
	var n: int = keys.size()
	if n == 0 or angles.size() != n:
		return 0.0
	var i: int = index_at(keys, t)
	if i < 0:
		return angles[0]
	if i >= n - 1:
		return angles[n - 1]
	var a := keys[i] as CineKey
	var b := keys[i + 1] as CineKey
	var span: float = b.time - a.time
	if span < MIN_SPAN:
		return angles[i + 1]
	var u: float = clampf((t - a.time) / span, 0.0, 1.0)
	match b.move:
		Move.CUT:
			return angles[i]
		Move.LINEAR:
			return lerp_angle(angles[i], angles[i + 1], eased(b, u))
	return lerp_angle(angles[i], angles[i + 1], smoothstep(0.0, 1.0, u))


## The last key at or before `t` (-1 before the first key).
static func index_at(keys: Array, t: float) -> int:
	var lo: int = -1
	for i: int in keys.size():
		if (keys[i] as CineKey).time <= t:
			lo = i
		else:
			break
	return lo


## `u` (0-1 through a LINEAR move into `key`) shaped by the key's transition and ease.
static func eased(key: CineKey, u: float) -> float:
	if key.trans == Tween.TRANS_LINEAR:
		return u
	return float(Tween.interpolate_value(0.0, 1.0, u, 1.0, key.trans, key.easing))


## The velocity (per second) a SMOOTH path passes key `k` with: from its neighbours on either side, or
## from the one neighbour it has where the path starts, ends or is cut.
static func tangent(keys: Array, values: Array, k: int) -> Variant:
	var n: int = keys.size()
	var key := keys[k] as CineKey
	var has_prev: bool = k > 0 and key.move != Move.CUT and key.time - (keys[k - 1] as CineKey).time >= MIN_SPAN
	var has_next: bool = k < n - 1 and (keys[k + 1] as CineKey).move != Move.CUT \
		and (keys[k + 1] as CineKey).time - key.time >= MIN_SPAN
	if has_prev and has_next:
		return (values[k + 1] - values[k - 1]) / ((keys[k + 1] as CineKey).time - (keys[k - 1] as CineKey).time)
	if has_next:
		return (values[k + 1] - values[k]) / ((keys[k + 1] as CineKey).time - key.time)
	if has_prev:
		return (values[k] - values[k - 1]) / (key.time - (keys[k - 1] as CineKey).time)
	return values[k] * 0.0


## A cubic Hermite curve from p0 (velocity m0) to p1 (velocity m1) over `span` seconds, at `u` (0-1).
static func hermite(p0: Variant, m0: Variant, p1: Variant, m1: Variant, span: float, u: float) -> Variant:
	var u2: float = u * u
	var u3: float = u2 * u
	return p0 * (2.0 * u3 - 3.0 * u2 + 1.0) + m0 * (span * (u3 - 2.0 * u2 + u)) \
		+ p1 * (3.0 * u2 - 2.0 * u3) + m1 * (span * (u3 - u2))
