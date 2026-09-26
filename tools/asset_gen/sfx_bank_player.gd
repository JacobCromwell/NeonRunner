extends "res://tools/asset_gen/sfx_bank.gd"
## Player movement and level sounds: jump, land, slide, wall runs, ramps, pads, the hull, death, the
## pulsing fence's warning and the level-complete riff.

const E2: float = 82.41
const G2: float = 98.0
const A2: float = 110.0


func sounds() -> Dictionary:
	return {
		"jump": _jump,
		"land": _land,
		"slide": _slide,
		"wall_enter": _wall_enter,
		"wall_jump": _wall_jump,
		"wall_blocked": _wall_blocked,
		"ramp": _ramp,
		"pad": _pad,
		"hull_end": _hull_end,
		"died": _died,
		"fence_warning": _fence_warning,
		"level_complete": _level_complete,
	}


## Jump: a 16-bit console "boing" upward. Two-operator FM with a rising pitch, bit-crushed.
func _jump() -> PackedFloat32Array:
	var b := DSP.fm(0.17, func(u: float) -> float: return DSP.sweep(240.0, 640.0, sqrt(u)), 2.0,
		func(u: float) -> float: return 0.6 + 3.5 * exp(-u * 6.0))
	DSP.envelope(b, 0.002, 0.08)
	DSP.crush(b, 8, 16000.0)
	return b


## Land: a distorted metal kick drum.
func _land() -> PackedFloat32Array:
	var b := DSP.kick(0.22, 160.0, 46.0, _rng(2))
	DSP.drive(b, 2.0)
	DSP.crush(b, 10, 22000.0)
	return b


## Slide: metal grinding on metal, with sparks.
func _slide() -> PackedFloat32Array:
	var rng := _rng(3)
	var d: float = 0.38
	var b := DSP.noise(d, rng)
	DSP.filter_sweep(b, &"bandpass", 2800.0, 1900.0, 2.5)
	var sparks := DSP.buffer(d)
	for s: int in 45:
		var at: int = rng.randi_range(0, sparks.size() - 64)
		var level: float = rng.randf_range(0.4, 1.0)
		for k: int in 64:
			sparks[at + k] += rng.randf_range(-1.0, 1.0) * level * exp(-k / 8.0)
	DSP.filter(sparks, &"highpass", 4000.0)
	DSP.mix(b, sparks, 0.0, 1.2)
	DSP.drive(b, 4.0)
	DSP.shape(b, 0.02, 0.12)
	DSP.crush(b, 7, 14000.0)
	return b


## Wall run: a guitar pick scrape. The pick clicks across the string windings, slowing as it slides.
func _wall_enter() -> PackedFloat32Array:
	var rng := _rng(4)
	var b := DSP.noise(0.45, rng)
	var n: int = b.size()
	var phase: float = 0.0
	for i: int in n:
		phase += DSP.sweep(95.0, 38.0, float(i) / n) / DSP.RATE
		b[i] *= 0.3 + 0.7 * pow(1.0 - fmod(phase, 1.0), 6.0)
	DSP.filter_sweep(b, &"bandpass", 4200.0, 650.0, 5.0)
	DSP.drive(b, 14.0)
	DSP.filter(b, &"lowpass", 5000.0)
	DSP.filter(b, &"highpass", 150.0)
	DSP.shape(b, 0.008, 0.1)
	DSP.crush(b, 10, 22000.0)
	return b


## Wall jump: a single distorted A5 power-chord stab.
func _wall_jump() -> PackedFloat32Array:
	var b := DSP.power_chord(0.36, A2, false, _rng(5))
	DSP.envelope(b, 0.002, 0.12)
	DSP.crush(b, 10, 24000.0)
	return b


## Wall entry blocked by a sign: a dull metallic clank. Inharmonic FM plus a thud.
func _wall_blocked() -> PackedFloat32Array:
	var d: float = 0.26
	var b := DSP.fm(d, func(_u: float) -> float: return 210.0, 1.414, func(u: float) -> float: return 7.0 * exp(-u * 9.0))
	var ring := DSP.fm(d, func(_u: float) -> float: return 587.0, 2.76, func(u: float) -> float: return 3.0 * exp(-u * 12.0))
	DSP.mix(b, ring, 0.0, 0.5)
	DSP.envelope(b, 0.001, 0.07)
	DSP.mix(b, DSP.kick(0.15, 120.0, 70.0, _rng(6)), 0.0, 0.8)
	DSP.crush(b, 7, 12000.0)
	return b


## Ramp: a V-twin motorbike rev (Motörhead). Uneven firing pairs, the throttle opening up.
func _ramp() -> PackedFloat32Array:
	var rng := _rng(7)
	var d: float = 0.85
	var b := DSP.buffer(d)
	var n: int = b.size()
	var phase: float = 0.0
	for i: int in n:
		var u: float = float(i) / n
		var throttle: float = smoothstep(0.0, 0.6, u)
		var crank: float = lerpf(26.0, 105.0, throttle) - 14.0 * smoothstep(0.78, 1.0, u)
		phase += crank / DSP.RATE
		# Two firings per two crank turns, 270° apart: the lopsided V-twin beat.
		var p: float = fmod(phase, 2.0)
		var since: float = (p if p < 0.75 else p - 0.75) / crank
		var burst: float = exp(-since / 0.007)
		var body: float = (fmod(phase, 1.0) * 2.0 - 1.0) * 0.35
		b[i] = (burst * (0.75 + 0.25 * rng.randf_range(-1.0, 1.0)) + body) * (0.4 + 0.6 * throttle)
	DSP.filter_sweep(b, &"lowpass", 650.0, 2600.0, 1.2)
	DSP.drive(b, 6.0, 0.1)
	DSP.filter(b, &"lowpass", 3500.0)
	DSP.filter(b, &"highpass", 45.0)
	DSP.shape(b, 0.01, 0.15)
	DSP.crush(b, 10, 20000.0)
	return b


## Anti-grav pad: a futuristic rising FM sweep with a whoosh and a sub thump.
func _pad() -> PackedFloat32Array:
	var d: float = 0.5
	var b := DSP.fm(d, func(u: float) -> float: return DSP.sweep(130.0, 1500.0, u), 0.5, func(_u: float) -> float: return 2.2)
	var detuned := DSP.fm(d, func(u: float) -> float: return DSP.sweep(131.5, 1518.0, u), 0.5, func(_u: float) -> float: return 2.2)
	DSP.mix(b, detuned, 0.0, 0.8)
	var whoosh := DSP.noise(d, _rng(8))
	DSP.filter_sweep(whoosh, &"bandpass", 300.0, 5000.0, 1.2)
	DSP.mix(b, whoosh, 0.0, 0.9)
	DSP.shape(b, 0.015, 0.12)
	DSP.mix(b, DSP.kick(0.2, 90.0, 50.0, _rng(9)), 0.0, 0.9)
	DSP.crush(b, 9, 18000.0)
	return b


## Hull ends: a power-down. The pitch falls while the bit depth and sample rate collapse.
func _hull_end() -> PackedFloat32Array:
	var b := DSP.fm(0.4, func(u: float) -> float: return DSP.sweep(1100.0, 110.0, u), 2.0,
		func(u: float) -> float: return 3.0 - 2.0 * u)
	DSP.envelope(b, 0.003, 0.3)
	DSP.crush_sweep(b, 12.0, 4.0, 32000.0, 2500.0)
	return b


## Death: a guitar dive bomb. An E power chord bent down two octaves, with a kick and a crash.
func _died() -> PackedFloat32Array:
	var d: float = 1.3
	var dive := func(u: float) -> float: return 1.0 if u < 0.07 else pow(0.22, pow((u - 0.07) / 0.93, 0.8))
	var b := DSP.power_chord(d, E2, false, _rng(10), dive)
	DSP.envelope(b, 0.002, 0.9, 0.25)
	DSP.crush_sweep(b, 12.0, 6.0, 32000.0, 8000.0)
	DSP.mix(b, DSP.kick(0.3, 140.0, 45.0, _rng(11)), 0.0, 0.9)
	DSP.mix(b, DSP.crash(0.7, _rng(12)), 0.0, 0.12)
	return b


## Pulsing fence about to switch on: a crunchy electric crackle that swells.
func _fence_warning() -> PackedFloat32Array:
	var rng := _rng(13)
	var b := DSP.buffer(0.35)
	var n: int = b.size()
	var phase: float = 0.0
	var level: float = 1.0
	for i: int in n:
		var u: float = float(i) / n
		phase += 120.0 / DSP.RATE
		if i % 96 == 0:
			level = rng.randf_range(0.15, 1.0) if rng.randf() < 0.6 else 1.0
		var buzz: float = (fmod(phase, 1.0) * 2.0 - 1.0) * level + sin(TAU * phase * 0.5) * 0.4
		var spark: float = rng.randf_range(-1.0, 1.0) * 2.0 if rng.randf() < 0.004 else 0.0
		b[i] = (buzz + spark) * (0.25 + 0.75 * u)
	DSP.filter(b, &"bandpass", 1800.0, 0.6)
	DSP.drive(b, 5.0)
	DSP.crush(b, 6, 11025.0)
	return b


## Level complete: a short power-chord riff. E5 chug, chug, G5, then A5 rings out with a crash.
func _level_complete() -> PackedFloat32Array:
	var rng := _rng(14)
	var eighth: float = 60.0 / 170.0 / 2.0
	var b := DSP.buffer(eighth * 3.0 + 1.3)
	var hits: Array = [[0.0, E2, true], [eighth, E2, true], [eighth * 2.0, G2, true], [eighth * 3.0, A2, false]]
	for hit: Array in hits:
		var muted: bool = hit[2]
		var chord := DSP.power_chord(eighth if muted else 1.3, hit[1], muted, rng)
		DSP.envelope(chord, 0.002, 0.07 if muted else 0.7, 0.02 if muted else 0.2)
		DSP.mix(b, chord, hit[0])
	DSP.mix(b, DSP.crash(0.9, _rng(15)), eighth * 3.0, 0.12)
	DSP.mix(b, DSP.kick(0.25, 150.0, 45.0, _rng(16)), eighth * 3.0, 0.7)
	DSP.crush(b, 11, 24000.0)
	return b
