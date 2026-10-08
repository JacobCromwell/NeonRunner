extends "res://tools/asset_gen/sfx_bank.gd"
## The Resonator's sounds (GDD §9.10), in the game's 16-bit style:
##   resonator_warning  the warning before every pulse (owner, October 8, 2026: "a crackling build of fire
##                    and a crashing wave", replacing the three-note chime, which sounded like a doorbell):
##                    fire catching and roaring up, its crackle thickening, flaring on each of the three
##                    moments a halo swings into line (Resonator.LINE_UP_AT), then drawing a breath and
##                    breaking into a heavy wave crash exactly when the red wave is released (the end of
##                    ResonatorTuning.warning_seconds: regenerate it when that changes), a fiery foam
##                    sizzling out under the wave's roll. Noise only: nothing tonal, bell-like or
##                    melodic. The same every time: a warning must be learnable.
##   resonator_pulse  the wave leaving: a deep thump and the rush of the wave rolling in along the floor,
##                    peaking as it reaches the runner about 1.1 s later (its travel from
##                    ResonatorTuning.hover_ahead at run speed: regenerate it when those change)
##   resonator_death  shot down: three resonant tones bent out of tune and falling apart, shattering
##                    glass and a small explosion

const ResonatorScript = preload("res://scripts/enemies/resonator.gd")
## The three tones its death bends out of tune (Hz): G5, C6, E6.
const DEATH_TONES_HZ: Array[float] = [783.99, 1046.5, 1318.51]
## Seconds the crash rolls out after the wave is released, and how loud its layers are against the
## build-up's (the crash ends up a few dB above the build-up's loudest flare).
const CRASH_SECONDS: float = 0.85
const CRASH_GAIN: float = 1.5
## The build-up draws a breath before the crash (the wave sucking back before it breaks): its roar
## falls away over BREATH_SECONDS, ending BREATH_GAP before the crash.
const BREATH_SECONDS: float = 0.075
const BREATH_GAP: float = 0.012


func sounds() -> Dictionary:
	return {
		"resonator_warning": _resonator_warning,
		"resonator_pulse": _resonator_pulse,
		"resonator_death": _resonator_death,
	}


## Seconds the warning lasts (ResonatorTuning.warning_seconds): the crash lands at its end.
func _warning_seconds() -> float:
	var t := load("res://data/enemies/resonator.tres") as ResonatorTuning
	return t.warning_seconds if t != null else 1.3


## The warning: a fire roaring up for warning_seconds and a wave crashing at the end of it. The build
## has a flaring roar (a rumble under a mid roar and a hiss, each brightening), a flickering level and
## thickening crackle; the crash is the wave breaking: a slap of noise whose low-pass closes down, a
## rolling wash, foam and the last of the fire crackling out. Lightly driven and crushed to sit with
## the other 16-bit sounds.
func _resonator_warning() -> PackedFloat32Array:
	var rng := _rng(1001)
	var crest: float = _warning_seconds()
	var b := DSP.buffer(crest + CRASH_SECONDS)
	DSP.mix(b, _fire_build(crest, rng), 0.0, 1.0)
	DSP.mix(b, _wave_crash(CRASH_SECONDS, rng), crest, CRASH_GAIN)
	DSP.filter(b, &"highpass", 60.0)
	_set_loudest_rms(b, 0.36)
	DSP.drive(b, 1.2)
	DSP.crush(b, 10, 22000.0)
	return b


## Brings `b` to a root-mean-square level, so layers can be mixed by how loud they are meant to be.
func _set_rms(b: PackedFloat32Array, rms: float) -> void:
	var sum: float = 0.0
	for x: float in b:
		sum += x * x
	if sum <= 0.0:
		return
	var gain: float = rms / sqrt(sum / b.size())
	for i: int in b.size():
		b[i] *= gain


## Scales `b` so its loudest 50 ms has root-mean-square level `rms`: the drive and crush after it then
## bite the same amount however the layers add up.
func _set_loudest_rms(b: PackedFloat32Array, rms: float) -> void:
	var window: int = int(0.05 * RATE)
	var sum: float = 0.0
	var best: float = 0.0
	for i: int in b.size():
		sum += b[i] * b[i]
		if i >= window:
			sum -= b[i - window] * b[i - window]
		best = maxf(best, sum)
	if best <= 0.0:
		return
	var gain: float = rms / sqrt(best / window)
	for i: int in b.size():
		b[i] *= gain


## A slow, irregular level between 1 - depth and 1: `hz` random knots a second, smoothly joined (the
## flicker of flame, the unevenness of a roll).
func _flicker(seconds: float, hz: float, depth: float, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var knots := PackedFloat32Array()
	for k: int in int(seconds * hz) + 3:
		knots.append(1.0 - depth * rng.randf())
	var b := DSP.buffer(seconds)
	for i: int in b.size():
		var x: float = float(i) / RATE * hz
		var k: int = int(x)
		b[i] = lerpf(knots[k], knots[k + 1], smoothstep(0.0, 1.0, x - k))
	return b


## Crackling: short noise pops scattered at random, `rate_from` a second changing to `rate_to` by the
## end (along a curve: `curve` above 1 saves the change for the end), each with a random size (mostly
## small, a few loud, between `loudness.x` and `loudness.y` from start to end) and snap (`tau_from`
## to `tau_to` samples of decay). Each of `flurries` (seconds) bursts into a dozen extra pops.
func _pops(seconds: float, rate_from: float, rate_to: float, curve: float, loudness: Vector2, tau_from: float, tau_to: float,
		flurries: Array[float], rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := DSP.buffer(seconds)
	var starts := PackedInt32Array()
	for i: int in b.size():
		var u: float = float(i) / b.size()
		if rng.randf() < lerpf(rate_from, rate_to, pow(u, curve)) / RATE:
			starts.append(i)
	for at: float in flurries:
		for _k: int in 12:
			starts.append(int((at + rng.randf_range(0.0, 0.06)) * RATE))
	for at: int in starts:
		if at >= b.size():
			continue
		var u: float = float(at) / b.size()
		var level: float = lerpf(loudness.x, loudness.y, u) * (0.15 + 0.85 * pow(rng.randf(), 3.0))
		var tau: float = rng.randf_range(tau_from, tau_to)
		for j: int in mini(int(tau * 6.0), b.size() - at):
			b[at + j] += rng.randf_range(-1.0, 1.0) * level * exp(-j / tau)
	return b


## The build-up: fire catching and roaring up over `crest` seconds. A rumble under a mid roar that
## brightens as it climbs and a hiss on top, flaring on each halo's line-up (the floor between the
## flares climbing, so each flare lands higher than the last), flickering, with a crackle that starts as
## a few ticks and snaps and thickens into a sizzle. The roar draws back just before the end, leaving a
## gap for the crash to hit.
func _fire_build(crest: float, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var beats: Array[float] = ResonatorScript.LINE_UP_AT
	var rumble := DSP.noise(crest, rng)
	DSP.filter_sweep(rumble, &"lowpass", 300.0, 650.0, 0.7)
	_set_rms(rumble, 0.5)
	var roar := DSP.noise(crest, rng)
	DSP.filter_sweep(roar, &"bandpass", 1100.0, 2600.0, 0.5)
	_set_rms(roar, 0.4)
	var hiss := DSP.noise(crest, rng)
	DSP.filter(hiss, &"highpass", 3600.0, 0.7)
	_set_rms(hiss, 0.1)
	var flicker := _flicker(crest, 17.0, 0.45, rng)
	var b := DSP.buffer(crest)
	var breath_from: float = crest - BREATH_SECONDS - BREATH_GAP
	for i: int in b.size():
		var t: float = float(i) / RATE
		var u: float = t / crest
		var level: float = 0.55 + 0.45 * pow(u, 1.6)
		for k: int in beats.size():
			var since: float = t - beats[k]
			if since > 0.0:
				level += (1.0 - 0.1 * k) * minf(1.0, since / 0.02) * exp(-since / 0.16)
		level *= flicker[i] * (1.0 - 0.7 * smoothstep(breath_from, crest - BREATH_GAP, t))
		b[i] = (rumble[i] * (1.0 - 0.3 * u) + roar[i] + hiss[i] * u) * level
	# The crackle: ticks (bright, many, small) and snaps (lower, fewer, bigger), thickening to the end.
	var ticks := _pops(crest, 14.0, 230.0, 1.8, Vector2(0.35, 0.8), 6.0, 16.0, beats, rng)
	DSP.filter(ticks, &"bandpass", 3300.0, 0.7)
	_set_rms(ticks, 0.3)
	var snaps := _pops(crest, 5.0, 38.0, 1.3, Vector2(0.5, 1.0), 30.0, 80.0, beats, rng)
	DSP.filter(snaps, &"bandpass", 1100.0, 0.8)
	_set_rms(snaps, 0.45)
	for i: int in b.size():
		var t: float = float(i) / RATE
		var louder: float = 0.55 + 0.45 * pow(t / crest, 0.8)
		var gap: float = 1.0 - 0.8 * smoothstep(breath_from, crest - BREATH_GAP, t)
		b[i] += (ticks[i] + snaps[i]) * louder * gap
	return b


## A wave crashing: the slap as it breaks (a hard noise burst whose low-pass closes down from the
## treble), a rolling wash under it that flutters, foam fizzing on top, a chest-height thump of body
## (the pulse's boom, which plays with it, carries the deep end), and the last crackle of the fire
## thinning out as it rolls away.
func _wave_crash(seconds: float, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var slap := DSP.noise(seconds, rng)
	DSP.filter_sweep(slap, &"lowpass", 8000.0, 380.0, 0.8)
	DSP.envelope(slap, 0.003, 0.2, 0.2)
	_set_loudest_rms(slap, 1.0)
	var wash := DSP.noise(seconds, rng)
	DSP.filter_sweep(wash, &"bandpass", 1500.0, 330.0, 0.55)
	var roll := _flicker(seconds, 9.0, 0.55, rng)
	for i: int in wash.size():
		var t: float = float(i) / RATE
		wash[i] *= roll[i] * minf(1.0, t / 0.04) * exp(-t / 0.42)
	_set_loudest_rms(wash, 0.55)
	var foam := DSP.noise(seconds, rng)
	DSP.filter(foam, &"highpass", 2800.0, 0.7)
	DSP.envelope(foam, 0.004, 0.3, 0.2)
	_set_loudest_rms(foam, 0.18)
	var body := DSP.noise(seconds, rng)
	DSP.filter(body, &"lowpass", 170.0, 0.9)
	DSP.envelope(body, 0.002, 0.16, 0.2)
	_set_loudest_rms(body, 0.5)
	var fizz := _pops(seconds, 260.0, 0.0, 0.7, Vector2(0.8, 0.2), 6.0, 20.0, [], rng)
	DSP.filter(fizz, &"bandpass", 2600.0, 0.7)
	_set_loudest_rms(fizz, 0.2)
	var b := DSP.buffer(seconds)
	DSP.mix(b, slap, 0.0, 0.85)
	DSP.mix(b, wash, 0.0, 0.8)
	DSP.mix(b, foam, 0.0, 1.0)
	DSP.mix(b, body, 0.0, 0.6)
	for i: int in b.size():
		var t: float = float(i) / RATE
		b[i] += fizz[i] * exp(-t / 0.45)
	return b


## The wave leaving and rolling in: a deep thump dropping away (the release: it plays alone for a
## double pulse's second wave, and under the warning's crash for the first), a low roll of noise that
## swells as the wave comes on, and a rush that rises and brightens as it rolls toward the runner,
## peaking as it gets there (_wave_travel) and cut off as it passes. Noise and a thump: no pitched
## hum, which would be the one tone left under the warning's roar.
func _resonator_pulse() -> PackedFloat32Array:
	var rng := _rng(1002)
	var length: float = 1.55
	var peak: float = _wave_travel()
	var b := _boom(length, 150.0, 38.0, 0.22, rng)
	var roll := DSP.noise(length, rng)
	DSP.filter_sweep(roll, &"lowpass", 180.0, 520.0, 0.8)
	_set_rms(roll, 0.5)
	var surge := _flicker(length, 8.0, 0.4, rng)
	for i: int in roll.size():
		var t: float = float(i) / RATE
		roll[i] *= surge[i] * pow(clampf(t / peak, 0.0, 1.0), 1.5) * exp(-maxf(t - peak, 0.0) / 0.08)
	DSP.mix(b, roll, 0.0, 1.0)
	var rush := DSP.noise(length, rng)
	DSP.filter_sweep(rush, &"bandpass", 250.0, 2600.0, 1.2)
	for i: int in rush.size():
		var t: float = float(i) / RATE
		var rise: float = pow(clampf(t / peak, 0.0, 1.0), 2.0)
		var gone: float = exp(-maxf(t - peak, 0.0) / 0.06)
		rush[i] *= rise * gone
	DSP.mix(b, rush, 0.0, 0.9)
	# Its crackling front, on the phone speaker's range.
	var front := _crackle(length, 40, 0.8, 1800.0, rng)
	for i: int in front.size():
		var t: float = float(i) / RATE
		front[i] *= pow(clampf(t / peak, 0.0, 1.0), 1.5) * exp(-maxf(t - peak, 0.0) / 0.05)
	DSP.mix(b, front, 0.0, 0.7)
	DSP.drive(b, 1.8)
	DSP.crush(b, 10, 20000.0)
	return b


## Seconds a wave takes to reach the runner (ResonatorTuning.travel_seconds at run speed, halfway through
## the Golden Zone's scaling): about 1.1 s.
func _wave_travel() -> float:
	var t := load("res://data/enemies/resonator.tres") as ResonatorTuning
	var movement := load("res://data/tuning/movement.tres") as MovementTuning
	if t == null or movement == null:
		return 1.1
	return t.travel_seconds(movement.run_speed, lerpf(t.scaling_from, t.scaling_to, 0.5))


## Shot down: three resonant tones struck together and bending down out of tune as the halos break,
## glass shattering, a small explosion and metal clattering.
func _resonator_death() -> PackedFloat32Array:
	var rng := _rng(1003)
	var length: float = 1.4
	var b := _explosion(length, 0.7, rng)
	for k: int in DEATH_TONES_HZ.size():
		var hz: float = DEATH_TONES_HZ[k]
		var drop: float = 0.55 + 0.1 * k
		var bent := DSP.fm(1.1, func(u: float) -> float: return hz * lerpf(1.0, drop, pow(u, 0.7)), 3.5,
			func(u: float) -> float: return 1.2 + 2.0 * u)
		DSP.envelope(bent, 0.002, 0.35)
		DSP.mix(b, bent, 0.02 * k, 0.35)
	var glass := _crackle(length, 90, 0.35, 5200.0, rng)
	DSP.mix(b, glass, 0.03, 1.1)
	DSP.mix(b, DSP.metal_hit(0.8, 620.0, 0.25, rng), 0.12, 0.4)
	DSP.mix(b, DSP.metal_hit(0.7, 910.0, 0.2, rng), 0.3, 0.3)
	DSP.crush(b, 9, 18000.0)
	return b
