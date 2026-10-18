extends "res://tools/asset_gen/sfx_bank_gangland_outro.gd"
## The Casino intro's own sounds (CasinoIntro): the violet sports car (Gangland's outro's) cruising down the covered
## casino street and pulling up at the Brass Lotus. Its engine is that bank's (_engine), so it's the same car. In the
## same crunchy 16-bit style as the rest; neither is a warning; like every sound effect, each is under 2.5 s.
##   car_cruise  the car cruising: a steady, throaty purr in a high gear, a little swell as it passes, faded in and out
##               over 0.15 s so two overlapping repeats run on evenly (2.4 s)
##   car_arrive  pulling up: off the throttle, a blip as it drops a gear, the tyres hushing as it brakes, a moment's
##               idle and the engine switched off, ticking as it settles (2.4 s)

const CRUISE_SECONDS: float = 2.4
const CRUISE_FADE: float = 0.15
const ARRIVE_SECONDS: float = 2.4
## When the engine is switched off in car_arrive (s in).
const ENGINE_OFF: float = 1.85


func sounds() -> Dictionary:
	return {
		"car_cruise": _cruise,
		"car_arrive": _arrive,
	}


## Cruising: the engine steady and low in a high gear, its revs wavering a touch, a little swell in the middle.
func _cruise() -> PackedFloat32Array:
	var rng := _rng(1801)
	var b := _engine(CRUISE_SECONDS, func(t: float) -> float: return 0.4 + 0.03 * sin(TAU * 0.7 * t),
		func(t: float) -> float: return 0.35 - 0.3 * sin(PI * clampf(t / CRUISE_SECONDS, 0.0, 1.0)), rng)
	# The tyres on the flagstones: a soft, low hush.
	var tyres := DSP.noise(CRUISE_SECONDS, rng)
	DSP.filter(tyres, &"lowpass", 500.0)
	DSP.mix(b, tyres, 0.0, 0.18)
	DSP.shape(b, CRUISE_FADE, CRUISE_FADE)
	DSP.crush(b, 10, 22000.0)
	return b


## Pulling up: the revs falling off the throttle, a blip as it drops a gear, down to idle as it brakes (the tyres
## hushing to a stop), a moment's idle, then switched off: the revs dying away, a last cough, ticking metal.
func _arrive() -> PackedFloat32Array:
	var rng := _rng(1802)
	var b := _engine(ARRIVE_SECONDS, _arrive_rpm, func(_t: float) -> float: return 0.0, rng)
	# Switched off: the engine's sound dies away with its revs (it would idle on at its slowest otherwise), a last
	# cough a moment after.
	for i: int in b.size():
		var t: float = float(i) / RATE
		if t >= ENGINE_OFF:
			var e: float = t - ENGINE_OFF
			b[i] *= exp(-e / 0.07) + 0.6 * exp(-pow((e - 0.14) / 0.03, 2.0))
	var tyres := DSP.noise(1.5, rng)
	DSP.filter_sweep(tyres, &"lowpass", 900.0, 200.0, 0.7)
	DSP.envelope(tyres, 0.05, 1.0, 0.4)
	DSP.mix(b, tyres, 0.0, 0.3)
	# A short brake squeak just before it stops, soft.
	var squeak := DSP.osc(0.18, func(u: float) -> float: return DSP.sweep(2100.0, 1900.0, u), &"saw")
	DSP.filter(squeak, &"bandpass", 2000.0, 4.0)
	DSP.envelope(squeak, 0.03, 0.08, 0.05)
	DSP.mix(b, squeak, 1.15, 0.06)
	# Ticking as it settles.
	for k: int in 5:
		var tick := DSP.noise(0.006, rng)
		DSP.envelope(tick, 0.0005, 0.002)
		DSP.filter(tick, &"highpass", 2500.0)
		DSP.mix(b, tick, ENGINE_OFF + 0.2 + 0.07 * float(k) + rng.randf_range(0.0, 0.04), 0.12)
	DSP.shape(b, 0.005, 0.3)
	DSP.crush(b, 10, 22000.0)
	return b


## The engine's speed (0-1) pulling up, `t` seconds in: off the throttle, a blip down a gear at 0.4 s, sinking to
## idle as it brakes, idling, and dying away when it's switched off.
static func _arrive_rpm(t: float) -> float:
	var r: float = lerpf(0.42, 0.18, smoothstep(0.0, 1.3, t))
	r += 0.24 * sin(PI * clampf((t - 0.4) / 0.25, 0.0, 1.0))
	if t >= ENGINE_OFF:
		r *= exp(-(t - ENGINE_OFF) / 0.08)
	return r
