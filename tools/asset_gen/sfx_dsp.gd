extends RefCounted
## A small offline DSP toolkit for the sound-effect and music generators (tools/asset_gen/sfx_gen.gd,
## music_gen.gd). Buffers are mono floats at RATE.
## The game never uses this at runtime; it only plays the .wav files the generators write.

## 32 kHz: the SNES sample rate, which suits the crunchy 16-bit character.
const RATE: int = 32000


class Biquad:
	extends RefCounted
	## RBJ cookbook biquad. Coefficients can change per sample for sweeps.
	const FS: float = 32000.0
	var b0: float = 1.0
	var b1: float = 0.0
	var b2: float = 0.0
	var a1: float = 0.0
	var a2: float = 0.0
	var _x1: float = 0.0
	var _x2: float = 0.0
	var _y1: float = 0.0
	var _y2: float = 0.0

	func set_filter(kind: StringName, hz: float, q: float, gain_db: float = 0.0) -> void:
		var w0: float = TAU * clampf(hz, 10.0, FS * 0.45) / FS
		var cosw: float = cos(w0)
		var alpha: float = sin(w0) / (2.0 * q)
		var a0: float = 1.0 + alpha
		match kind:
			&"lowpass":
				b0 = (1.0 - cosw) * 0.5
				b1 = 1.0 - cosw
				b2 = b0
			&"highpass":
				b0 = (1.0 + cosw) * 0.5
				b1 = -(1.0 + cosw)
				b2 = b0
			&"bandpass":
				b0 = alpha
				b1 = 0.0
				b2 = -alpha
			&"peaking":
				var amp: float = pow(10.0, gain_db / 40.0)
				b0 = 1.0 + alpha * amp
				b1 = -2.0 * cosw
				b2 = 1.0 - alpha * amp
				a0 = 1.0 + alpha / amp
		a1 = -2.0 * cosw
		a2 = 1.0 - (alpha / pow(10.0, gain_db / 40.0) if kind == &"peaking" else alpha)
		b0 /= a0
		b1 /= a0
		b2 /= a0
		a1 /= a0
		a2 /= a0

	func process(x: float) -> float:
		var y: float = b0 * x + b1 * _x1 + b2 * _x2 - a1 * _y1 - a2 * _y2
		_x2 = _x1
		_x1 = x
		_y2 = _y1
		_y1 = y
		return y


static func buffer(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * RATE))
	return b


static func seconds_of(b: PackedFloat32Array) -> float:
	return float(b.size()) / RATE


## Exponential sweep: `from` at u = 0 to `to` at u = 1.
static func sweep(from: float, to: float, u: float) -> float:
	return from * pow(to / from, clampf(u, 0.0, 1.0))


static func noise(seconds: float, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := buffer(seconds)
	for i: int in b.size():
		b[i] = rng.randf_range(-1.0, 1.0)
	return b


## Oscillator. `freq` maps normalized time u (0–1) to Hz. Shapes: sine, saw, square, triangle.
static func osc(seconds: float, freq: Callable, shape: StringName = &"sine", phase: float = 0.0) -> PackedFloat32Array:
	var b := buffer(seconds)
	var n: int = b.size()
	for i: int in n:
		phase = fmod(phase + float(freq.call(float(i) / n)) / RATE, 1.0)
		match shape:
			&"saw":
				b[i] = phase * 2.0 - 1.0
			&"square":
				b[i] = 1.0 if phase < 0.5 else -1.0
			&"triangle":
				b[i] = 1.0 - absf(phase * 4.0 - 2.0)
			_:
				b[i] = sin(phase * TAU)
	return b


## Two-operator FM (the Mega Drive / Genesis sound): carrier Hz, modulator at `ratio` × carrier,
## modulation index over time. Both callables take normalized time u.
static func fm(seconds: float, carrier: Callable, ratio: float, index: Callable) -> PackedFloat32Array:
	var b := buffer(seconds)
	var n: int = b.size()
	var pc: float = 0.0
	var pm: float = 0.0
	for i: int in n:
		var u: float = float(i) / n
		var f: float = carrier.call(u)
		pc = fmod(pc + f / RATE, 1.0)
		pm = fmod(pm + f * ratio / RATE, 1.0)
		b[i] = sin(TAU * pc + float(index.call(u)) * sin(TAU * pm))
	return b


## Adds `src` into `dst` at `at_seconds`, scaled by `gain`.
static func mix(dst: PackedFloat32Array, src: PackedFloat32Array, at_seconds: float = 0.0, gain: float = 1.0) -> void:
	var offset: int = int(at_seconds * RATE)
	for i: int in src.size():
		var j: int = offset + i
		if j >= dst.size():
			break
		dst[j] += src[i] * gain


static func filter(b: PackedFloat32Array, kind: StringName, hz: float, q: float = 0.707, gain_db: float = 0.0) -> void:
	var f := Biquad.new()
	f.set_filter(kind, hz, q, gain_db)
	for i: int in b.size():
		b[i] = f.process(b[i])


## A filter whose frequency sweeps exponentially from `from_hz` to `to_hz` over the buffer.
static func filter_sweep(b: PackedFloat32Array, kind: StringName, from_hz: float, to_hz: float, q: float = 0.707) -> void:
	var f := Biquad.new()
	var n: int = b.size()
	for i: int in n:
		if i % 16 == 0:
			f.set_filter(kind, sweep(from_hz, to_hz, float(i) / n), q)
		b[i] = f.process(b[i])


## Saturating overdrive. Higher gain = more crunch; `bias` adds asymmetric (tube-like) grit.
static func drive(b: PackedFloat32Array, gain: float, bias: float = 0.0) -> void:
	var norm: float = 1.0 / tanh(gain)
	var offset: float = tanh(gain * bias)
	for i: int in b.size():
		b[i] = (tanh(gain * (b[i] + bias)) - offset) * norm


## Bit crusher: sample-and-hold at `hold_hz`, quantized to `bits`.
static func crush(b: PackedFloat32Array, bits: float, hold_hz: float) -> void:
	crush_sweep(b, bits, bits, hold_hz, hold_hz)


## Bit crusher whose depth and rate change over the buffer (for power-down glitches).
static func crush_sweep(b: PackedFloat32Array, bits_from: float, bits_to: float, hold_from: float, hold_to: float) -> void:
	var n: int = b.size()
	var held: float = 0.0
	var acc: float = 1.0
	for i: int in n:
		var u: float = float(i) / n
		acc += sweep(hold_from, hold_to, u) / RATE
		if acc >= 1.0:
			acc -= floorf(acc)
			var step: float = 2.0 / pow(2.0, lerpf(bits_from, bits_to, u))
			held = roundf(b[i] / step) * step
		b[i] = held


## Amplitude: linear attack, exponential decay (time constant `tau`), and a short fade at the end.
static func envelope(b: PackedFloat32Array, attack: float, tau: float, release: float = 0.01) -> void:
	var n: int = b.size()
	for i: int in n:
		var t: float = float(i) / RATE
		var a: float = minf(1.0, t / maxf(attack, 0.0001)) * exp(-t / tau)
		var left: float = float(n - i) / RATE
		if left < release:
			a *= left / release
		b[i] *= a


## Amplitude: linear attack, full level, linear release at the end.
static func shape(b: PackedFloat32Array, attack: float, release: float) -> void:
	envelope(b, attack, 1e9, release)


## A metal kick drum: a sine that drops from `from_hz` to `to_hz`, plus a beater click.
static func kick(seconds: float, from_hz: float, to_hz: float, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := buffer(seconds)
	var phase: float = 0.0
	for i: int in b.size():
		var t: float = float(i) / RATE
		phase = fmod(phase + (to_hz + (from_hz - to_hz) * exp(-t / 0.03)) / RATE, 1.0)
		var click: float = rng.randf_range(-1.0, 1.0) * exp(-t / 0.0025) * 0.5
		b[i] = sin(phase * TAU) * exp(-t / 0.1) + click
	drive(b, 2.5)
	return b


## A crash cymbal: bright noise with a long decay.
static func crash(seconds: float, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := noise(seconds, rng)
	filter(b, &"highpass", 4500.0, 0.7)
	filter(b, &"peaking", 7500.0, 1.0, 6.0)
	envelope(b, 0.002, seconds * 0.45, seconds * 0.3)
	return b


## MIDI note number to Hz (69 = A4 = 440 Hz; 40 = E2, the low guitar string).
static func midi_hz(note: float) -> float:
	return 440.0 * pow(2.0, (note - 69.0) / 12.0)


## Amplitude: linear attack, exponential decay (time constant `decay`) towards `sustain`, and a
## linear release over the last `release` seconds.
static func adsr(b: PackedFloat32Array, attack: float, decay: float, sustain: float, release: float) -> void:
	var n: int = b.size()
	for i: int in n:
		var t: float = float(i) / RATE
		var a: float = minf(1.0, t / maxf(attack, 0.0001))
		a *= sustain + (1.0 - sustain) * exp(-maxf(0.0, t - attack) / maxf(decay, 0.0001))
		var left: float = float(n - i) / RATE
		if left < release:
			a *= left / release
		b[i] *= a


## Bit-depth reduction without sample-and-hold: grit with no memory, so it is safe on a music loop.
static func quantize(b: PackedFloat32Array, bits: float) -> void:
	var step: float = 2.0 / pow(2.0, bits)
	for i: int in b.size():
		b[i] = roundf(b[i] / step) * step


## A snare drum: a triangle-wave body that drops to `tone_hz`, plus bright wire rattle.
## `snappy` (0–1) trades body for rattle and lengthens the rattle.
static func snare(seconds: float, tone_hz: float, snappy: float, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := buffer(seconds)
	var phase: float = 0.0
	for i: int in b.size():
		var t: float = float(i) / RATE
		phase = fmod(phase + tone_hz * (1.0 + 0.7 * exp(-t / 0.01)) / RATE, 1.0)
		b[i] = (1.0 - absf(phase * 4.0 - 2.0)) * exp(-t / 0.05) * (1.0 - 0.5 * snappy)
	var rattle := noise(seconds, rng)
	filter(rattle, &"highpass", 1100.0)
	filter(rattle, &"peaking", 4200.0, 0.8, 6.0)
	envelope(rattle, 0.0005, 0.06 + 0.12 * snappy, 0.005)
	mix(b, rattle, 0.0, 0.45 + 0.6 * snappy)
	drive(b, 2.2)
	return b


## A hi-hat or ride: six clashing square waves (the drum-machine cymbal) and noise, high-passed.
## `decay` is the time constant: about 0.03 s closed, 0.2 s open.
static func hat(seconds: float, decay: float, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := noise(seconds, rng)
	var n: int = b.size()
	for i: int in n:
		b[i] *= 0.6
	for hz: float in [205.3, 304.4, 369.6, 522.7, 540.0, 800.0]:
		var phase: float = rng.randf()
		var inc: float = hz * 1.9 / RATE
		for i: int in n:
			phase = fmod(phase + inc, 1.0)
			b[i] += 0.25 if phase < 0.5 else -0.25
	filter(b, &"highpass", 6500.0, 0.8)
	filter(b, &"highpass", 6500.0, 0.8)
	filter(b, &"peaking", 10000.0, 1.0, 4.0)
	envelope(b, 0.0005, decay, 0.004)
	return b


## A tom drum: a sine that settles on `hz` after a short pitch drop, with a stick click.
static func tom(seconds: float, hz: float, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := buffer(seconds)
	var phase: float = 0.0
	for i: int in b.size():
		var t: float = float(i) / RATE
		phase = fmod(phase + hz * (1.0 + 0.5 * exp(-t / 0.04)) / RATE, 1.0)
		b[i] = sin(phase * TAU) * exp(-t / 0.22) + rng.randf_range(-1.0, 1.0) * exp(-t / 0.003) * 0.35
	drive(b, 2.0)
	return b


## A struck piece of metal (girder, pipe, plate, manhole cover): inharmonic FM partials and a noisy
## strike. A low `hz` sounds heavy; `ring` is the decay time constant in seconds.
static func metal_hit(seconds: float, hz: float, ring: float, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := fm(seconds, func(_u: float) -> float: return hz, 1.414,
		func(u: float) -> float: return 5.0 * exp(-u * seconds / (ring * 0.5)) + 0.8)
	var upper := fm(seconds, func(_u: float) -> float: return hz * 2.76, 1.73,
		func(u: float) -> float: return 3.0 * exp(-u * seconds / (ring * 0.3)))
	mix(b, upper, 0.0, 0.45)
	envelope(b, 0.0005, ring)
	var strike := noise(minf(seconds, 0.04), rng)
	filter(strike, &"bandpass", minf(hz * 4.0, 12000.0), 1.2)
	envelope(strike, 0.0003, 0.006)
	mix(b, strike, 0.0, 1.2)
	return b


## A distorted guitar power chord (root, fifth, octave) through a scooped, cabinet-filtered amp.
## `palm_mute` damps it into a chug. `bend` maps normalized time to a pitch multiplier (dive bombs).
static func power_chord(seconds: float, root_hz: float, palm_mute: bool, rng: RandomNumberGenerator,
		bend: Callable = Callable()) -> PackedFloat32Array:
	var b := buffer(seconds)
	var n: int = b.size()
	var ratios: Array[float] = [1.0, 1.4983, 2.0]
	var weights: Array[float] = [1.0, 0.8, 0.55]
	for v: int in ratios.size():
		for cents: float in [-7.0, 6.0]:
			var mult: float = ratios[v] * pow(2.0, cents / 1200.0)
			var phase: float = rng.randf()
			for i: int in n:
				var pitch: float = float(bend.call(float(i) / n)) if bend.is_valid() else 1.0
				phase = fmod(phase + root_hz * mult * pitch / RATE, 1.0)
				b[i] += (phase * 2.0 - 1.0) * weights[v] * 0.3
	# Pick attack and the string's own decay before the amp.
	for i: int in n:
		var t: float = float(i) / RATE
		b[i] *= exp(-t / (0.08 if palm_mute else 1.5))
	filter(b, &"highpass", 110.0)
	filter(b, &"lowpass", 750.0 if palm_mute else 3200.0)
	drive(b, 28.0, 0.08)
	# Cabinet: roll off fizz, scoop the mids (the classic metal EQ), keep a tight low end.
	filter(b, &"lowpass", 4200.0, 0.9)
	filter(b, &"lowpass", 3300.0, 0.7)
	filter(b, &"peaking", 750.0, 0.9, -6.0)
	filter(b, &"peaking", 120.0, 1.0, 3.0)
	filter(b, &"highpass", 70.0)
	return b


## Removes DC, fades the edges, and brings the sound to a target loudness. Peaks that would pass
## `knee` are rounded off by a soft limiter (never above `ceiling`), so spiky sounds such as the
## engine reach the same loudness as the rest instead of being turned down to fit their peaks.
## The ceiling leaves headroom: resampling the crushed, stepped waveforms to the output rate overshoots.
static func finish(b: PackedFloat32Array, target_rms_db: float = -16.0, knee: float = 0.6, ceiling: float = 0.8) -> void:
	filter(b, &"highpass", 25.0)
	var n: int = b.size()
	var fade_in: int = int(0.001 * RATE)
	var fade_out: int = int(0.006 * RATE)
	for i: int in mini(fade_in, n):
		b[i] *= float(i) / fade_in
	for i: int in mini(fade_out, n):
		b[n - 1 - i] *= float(i) / fade_out
	normalize(b, target_rms_db, knee, ceiling)


## The loudness half of finish(): brings the buffer to `target_rms_db`, soft-limiting peaks above
## `knee` so they never pass `ceiling`. No fades, so a music loop stays seamless.
static func normalize(b: PackedFloat32Array, target_rms_db: float, knee: float, ceiling: float) -> void:
	var n: int = b.size()
	var range_above: float = ceiling - knee
	# Two passes: the limiter takes a little loudness off, so the second pass tops it back up.
	for pass_index: int in 2:
		var sum: float = 0.0
		for x: float in b:
			sum += x * x
		if sum <= 0.0:
			return
		var gain: float = db_to_linear(target_rms_db) / sqrt(sum / n)
		for i: int in n:
			var x: float = b[i] * gain
			var mag: float = absf(x)
			if mag > knee:
				x = signf(x) * (knee + range_above * tanh((mag - knee) / range_above))
			b[i] = x


static func to_wav(b: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(b.size() * 2)
	for i: int in b.size():
		data.encode_s16(i * 2, int(clampf(b[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return wav
