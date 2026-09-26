extends RefCounted
## Base for the sound-effect banks (sfx_bank_*.gd). A bank lists its sounds in sounds(): name →
## function returning a mono buffer, which sfx_gen.gd finishes (loudness, edges) and writes to
## assets/sfx/<name>.wav. Shared building blocks for the banks live here.

const DSP = preload("res://tools/asset_gen/sfx_dsp.gd")
const Inst = preload("res://tools/asset_gen/music_instruments.gd")
const RATE: int = DSP.RATE


## name → Callable returning PackedFloat32Array.
func sounds() -> Dictionary:
	return {}


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## A band-limited pulse-wave blip (the 16-bit console beep): instant attack, decay time constant `tau`.
func _blip(seconds: float, hz: float, duty: float, tau: float) -> PackedFloat32Array:
	var b := Inst.pulse(seconds, hz, duty)
	DSP.envelope(b, 0.001, tau, 0.005)
	return b


## A two-operator FM note: `ratio` sets the colour (1 brassy, 2 hollow, 3.5 bell); the index falls
## from `index_from` to `index_to` in about 50 ms; amplitude decay time constant `tau`.
func _fm_note(seconds: float, hz: float, ratio: float, index_from: float, index_to: float, tau: float) -> PackedFloat32Array:
	var b := DSP.fm(seconds, func(_u: float) -> float: return hz, ratio,
		func(u: float) -> float: return index_to + (index_from - index_to) * exp(-u * seconds / 0.05))
	DSP.envelope(b, 0.002, tau, 0.01)
	return b


## Noise through a band-pass that sweeps from `from_hz` to `to_hz`, swelling up to its middle and
## away again: a whoosh or swish.
func _whoosh(seconds: float, from_hz: float, to_hz: float, q: float, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := DSP.noise(seconds, rng)
	DSP.filter_sweep(b, &"bandpass", from_hz, to_hz, q)
	var n: int = b.size()
	for i: int in n:
		b[i] *= pow(sin(PI * float(i) / n), 1.5)
	return b


## A long, deep boom: a sine that drops from `from_hz` to `to_hz` and dies away with time constant
## `tau`, with a click at the front.
func _boom(seconds: float, from_hz: float, to_hz: float, tau: float, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := DSP.buffer(seconds)
	var phase: float = 0.0
	for i: int in b.size():
		var t: float = float(i) / RATE
		phase = fmod(phase + (to_hz + (from_hz - to_hz) * exp(-t / 0.05)) / RATE, 1.0)
		b[i] = sin(phase * TAU) * exp(-t / tau) + rng.randf_range(-1.0, 1.0) * exp(-t / 0.003) * 0.4
	DSP.drive(b, 2.5)
	return b


## Short noise crackles (debris, sparks) scattered over the buffer, thinning out with time constant
## `tau`, band-passed around `hz`.
func _crackle(seconds: float, count: int, tau: float, hz: float, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := DSP.buffer(seconds)
	for k: int in count:
		var at: int = rng.randi_range(0, maxi(0, b.size() - 200))
		var level: float = rng.randf_range(0.2, 1.0) * exp(-float(at) / RATE / tau)
		for j: int in mini(120, b.size() - at):
			b[at + j] += rng.randf_range(-1.0, 1.0) * level * exp(-j / 25.0)
	DSP.filter(b, &"bandpass", hz, 0.7)
	return b


## An explosion: a sharp crack, a deep boom, a burst of noise whose low-pass closes down, and
## crackling debris. `size` (about 0.5–1.5) scales how long it roars.
func _explosion(seconds: float, size: float, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := _boom(seconds, 120.0, 34.0, 0.25 * size, rng)
	var blast := DSP.noise(seconds, rng)
	DSP.filter_sweep(blast, &"lowpass", 6000.0, 250.0, 0.7)
	DSP.envelope(blast, 0.002, 0.18 * size, 0.02)
	DSP.mix(b, blast, 0.0, 1.3)
	# The crack carries the explosion on small speakers, which can't play the boom.
	var crack := DSP.noise(minf(seconds, 0.25), rng)
	DSP.filter(crack, &"bandpass", 1400.0, 0.7)
	DSP.envelope(crack, 0.001, 0.06)
	DSP.mix(b, crack, 0.0, 2.5)
	DSP.mix(b, _crackle(seconds, int(40 * size), 0.35 * size, 2500.0, rng), 0.0, 0.6)
	DSP.drive(b, 2.0)
	DSP.crush(b, 9, 18000.0)
	return b


## Sparkle: high sine twinkles that thin out (rewards, stars).
func _sparkle(seconds: float, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := DSP.buffer(seconds)
	for k: int in int(seconds * 40.0):
		var hz: float = rng.randf_range(4000.0, 9000.0)
		var ping := DSP.osc(0.04, func(_u: float) -> float: return hz)
		DSP.envelope(ping, 0.001, 0.01)
		var at: float = rng.randf_range(0.0, seconds - 0.04)
		DSP.mix(b, ping, at, rng.randf_range(0.3, 1.0) * exp(-at / (seconds * 0.4)))
	return b


## A crude voice: a saw at `pitch` Hz (a function of normalized time) with vibrato, shaped by two
## band-pass formants that glide from `f1.x` to `f1.y` and `f2.x` to `f2.y` ("ee" ≈ 300/2300 Hz,
## "ah" ≈ 750/1200, "oo" ≈ 300/800). Moans, shrieks and screams.
func _voice(seconds: float, pitch: Callable, f1: Vector2, f2: Vector2, vibrato_hz: float, vibrato_semitones: float,
		rng: RandomNumberGenerator) -> PackedFloat32Array:
	var src := DSP.osc(seconds, func(u: float) -> float:
		return float(pitch.call(u)) * pow(2.0, vibrato_semitones * sin(TAU * vibrato_hz * u * seconds) / 12.0), &"saw")
	var breath := DSP.noise(seconds, rng)
	DSP.mix(src, breath, 0.0, 0.15)
	var low := src.duplicate()
	var high := src.duplicate()
	DSP.filter_sweep(low, &"bandpass", f1.x, f1.y, 4.0)
	DSP.filter_sweep(high, &"bandpass", f2.x, f2.y, 6.0)
	DSP.filter(src, &"lowpass", 1800.0)
	var b := DSP.buffer(seconds)
	DSP.mix(b, src, 0.0, 0.25)
	DSP.mix(b, low, 0.0, 1.0)
	DSP.mix(b, high, 0.0, 0.8)
	return b
