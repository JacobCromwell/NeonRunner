extends "res://tools/asset_gen/sfx_bank.gd"
## The Resonator's sounds (GDD §9.10), in the game's 16-bit style:
##   resonator_chime  the warning before every pulse: the cult's signature three-note chime, a pleasant
##                    public-address jingle (its pleasantness is the creepy part). Soft mallets on
##                    tuned metal bars with a glassy FM shimmer, rising G5, C6, E6 (a bright major
##                    triad, far from the Golden music's F sharp minor, which has no bells or chimes at
##                    all), exactly on Resonator.CHIME_NOTES, where its halos swing into line. The
##                    same every time: a warning must be learnable.
##   resonator_pulse  the wave leaving: a deep resonant thump and hum, then the rush of the wave rolling
##                    in along the floor, peaking as it reaches the runner about 1.3 s later
##   resonator_death  shot down: the chime's notes bent out of tune and falling apart, shattering glass
##                    and a small explosion

const ResonatorScript = preload("res://scripts/enemies/resonator.gd")
## The chime's notes (Hz): G5, C6, E6.
const CHIME_HZ: Array[float] = [783.99, 1046.5, 1318.51]


func sounds() -> Dictionary:
	return {
		"resonator_chime": _resonator_chime,
		"resonator_pulse": _resonator_pulse,
		"resonator_death": _resonator_death,
	}


## One chime note: a soft mallet on a tuned bar (the fundamental, a quiet octave and the bar's bright
## fourth partial, which dies fast), a glassy FM bell over it, and a slow shimmer.
func _chime_note(hz: float, seconds: float, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := DSP.buffer(seconds)
	var partials: Array[Vector3] = [Vector3(1.0, 1.0, 0.9), Vector3(2.0, 0.22, 0.45), Vector3(3.98, 0.16, 0.12)]
	for p: Vector3 in partials:
		var phase: float = rng.randf()
		for i: int in b.size():
			var t: float = float(i) / RATE
			phase = fmod(phase + hz * p.x / RATE, 1.0)
			b[i] += sin(phase * TAU) * p.y * exp(-t / p.z)
	var glass := _fm_note(seconds, hz, 3.5, 1.6, 0.25, 0.35)
	DSP.mix(b, glass, 0.0, 0.3)
	# A gentle, slow shimmer (like a vibraphone's), and a soft mallet attack.
	for i: int in b.size():
		var t: float = float(i) / RATE
		b[i] *= (1.0 + 0.08 * sin(TAU * 5.2 * t)) * minf(1.0, t / 0.004)
	var knock := DSP.noise(0.03, rng)
	DSP.filter(knock, &"bandpass", hz * 2.0, 1.5)
	DSP.envelope(knock, 0.0005, 0.006)
	DSP.mix(b, knock, 0.0, 0.25)
	return b


## The warning: three rising notes on Resonator.CHIME_NOTES, each ringing on under the next, the last
## held a little longer, lightly crushed to sit with the other 16-bit sounds without losing its sweetness.
func _resonator_chime() -> PackedFloat32Array:
	var rng := _rng(1001)
	var notes: Array[float] = ResonatorScript.CHIME_NOTES
	var length: float = notes[-1] + 1.05
	var b := DSP.buffer(length)
	for k: int in notes.size():
		var ring: float = length - notes[k]
		DSP.mix(b, _chime_note(CHIME_HZ[k], ring, rng), notes[k], 0.85 + 0.1 * k)
	# A soft pad of the same chord under the last note: the jingle resolving.
	var pad := DSP.buffer(1.0)
	for hz: float in CHIME_HZ:
		var tone := DSP.osc(1.0, func(_u: float) -> float: return hz * 0.5, &"triangle")
		DSP.mix(pad, tone, 0.0, 0.12)
	DSP.shape(pad, 0.15, 0.6)
	DSP.mix(b, pad, notes[-1], 1.0)
	DSP.filter(b, &"highpass", 180.0)
	DSP.crush(b, 11, 26000.0)
	return b


## The wave leaving and rolling in: a deep thump dropping away, a resonant hum on the chime's root two
## octaves down, wobbling as it fades, and a rush of noise that rises and brightens as the wave rolls
## toward the runner, peaking at about 1.3 s (the wave's travel at run speed) and cut off as it passes.
func _resonator_pulse() -> PackedFloat32Array:
	var rng := _rng(1002)
	var length: float = 1.55
	var b := _boom(length, 150.0, 38.0, 0.3, rng)
	var hum := DSP.fm(length, func(u: float) -> float: return CHIME_HZ[0] * 0.25 * (1.0 - 0.06 * u), 2.0,
		func(u: float) -> float: return 1.4 * exp(-u * 3.0) + 0.3)
	for i: int in hum.size():
		var t: float = float(i) / RATE
		hum[i] *= exp(-t / 0.55) * (0.8 + 0.2 * sin(TAU * 7.0 * t))
	DSP.mix(b, hum, 0.0, 0.55)
	var rush := DSP.noise(length, rng)
	DSP.filter_sweep(rush, &"bandpass", 250.0, 2600.0, 1.2)
	var peak: float = 1.3
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


## Shot down: the chime's three notes struck together and bending down out of tune as the halos break,
## glass shattering, a small explosion and metal clattering.
func _resonator_death() -> PackedFloat32Array:
	var rng := _rng(1003)
	var length: float = 1.4
	var b := _explosion(length, 0.7, rng)
	for k: int in CHIME_HZ.size():
		var hz: float = CHIME_HZ[k]
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
