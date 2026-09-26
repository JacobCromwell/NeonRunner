extends RefCounted
## Instruments for the music loops (tools/asset_gen/music_gen.gd) in the crunchy 16-bit /
## heavy-metal style of the sound effects: FM bass and brass (Mega Drive), pulse-wave arpeggios,
## band-limited saw pads, distorted guitars through sfx_dsp.gd's amp, and FX sweeps.
## Each function renders one note into a new buffer; the Song mixes it in at the note's step.

const DSP = preload("res://tools/asset_gen/sfx_dsp.gd")
const RATE: int = DSP.RATE


## PolyBLEP: smooths an oscillator's jump so synth notes don't alias into fizz.
static func _blep(t: float, dt: float) -> float:
	if t < dt:
		t /= dt
		return t + t - t * t - 1.0
	if t > 1.0 - dt:
		t = (t - 1.0) / dt
		return t * t + t + t + 1.0
	return 0.0


## Band-limited sawtooth voices, one per entry of `freqs` (Hz), summed at `gain` each.
static func saws(seconds: float, freqs: Array, gain: float, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := DSP.buffer(seconds)
	for hz: float in freqs:
		var p: float = rng.randf()
		var dt: float = hz / RATE
		for i: int in b.size():
			p += dt
			if p >= 1.0:
				p -= 1.0
			b[i] += (2.0 * p - 1.0 - _blep(p, dt)) * gain
	return b


## A band-limited pulse wave with duty cycle `duty` (0.5 = square, 0.125 = thin and nasal).
static func pulse(seconds: float, hz: float, duty: float) -> PackedFloat32Array:
	var b := DSP.buffer(seconds)
	var p: float = 0.0
	var dt: float = hz / RATE
	for i: int in b.size():
		p += dt
		if p >= 1.0:
			p -= 1.0
		b[i] = (1.0 if p < duty else -1.0) + _blep(p, dt) - _blep(fmod(p + 1.0 - duty, 1.0), dt)
	return b


## FM bass, the Mega Drive slap: the modulator's index snaps down from `bite` to a warm body.
static func fm_bass(hz: float, seconds: float, bite: float) -> PackedFloat32Array:
	var b := DSP.buffer(seconds + 0.02)
	var pc: float = 0.0
	var pm: float = 0.0
	var inc: float = hz / RATE
	for i: int in b.size():
		var t: float = float(i) / RATE
		pc = fmod(pc + inc, 1.0)
		pm = fmod(pm + inc, 1.0)
		var index: float = 0.9 + bite * exp(-t / 0.045)
		b[i] = sin(TAU * pc + index * sin(TAU * pm)) + 0.5 * sin(TAU * pc)
	DSP.adsr(b, 0.002, 0.2, 0.7, 0.02)
	DSP.drive(b, 1.8)
	DSP.filter(b, &"lowpass", 2400.0, 0.7)
	DSP.crush(b, 10, 20000.0)
	return b


## A filthy synth bass: a saw and a square an octave down, overdriven and crushed to 6 bits.
static func dirty_bass(hz: float, seconds: float, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := saws(seconds + 0.02, [hz, hz * 1.006], 0.5, rng)
	DSP.mix(b, pulse(seconds + 0.02, hz * 0.5, 0.5), 0.0, 0.6)
	DSP.filter(b, &"lowpass", 900.0, 1.2)
	DSP.drive(b, 5.0, 0.15)
	DSP.filter(b, &"lowpass", 2200.0, 0.7)
	DSP.adsr(b, 0.003, 0.3, 0.75, 0.02)
	DSP.crush(b, 6, 12000.0)
	return b


## Synthwave bass: a warm saw whose low-pass opens with each pluck.
static func saw_bass(hz: float, seconds: float, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := saws(seconds + 0.02, [hz, hz * 0.997], 0.55, rng)
	DSP.filter_sweep(b, &"lowpass", 1800.0, 350.0, 1.1)
	DSP.adsr(b, 0.003, 0.12, 0.6, 0.02)
	DSP.drive(b, 1.5)
	return b


## A chiptune arpeggio note: a pulse wave that decays fast, crushed to 9 bits.
static func pulse_note(hz: float, seconds: float, duty: float, decay: float) -> PackedFloat32Array:
	var b := pulse(seconds, hz, duty)
	DSP.envelope(b, 0.001, decay, 0.008)
	DSP.filter(b, &"lowpass", 6000.0, 0.7)
	DSP.crush(b, 9, 24000.0)
	return b


## An FM bell (inharmonic modulator): glassy neon sparkle for slow arpeggios.
static func fm_bell(hz: float, seconds: float) -> PackedFloat32Array:
	var b := DSP.fm(seconds, func(_u: float) -> float: return hz, 3.5,
		func(u: float) -> float: return 0.4 + 2.4 * exp(-u * seconds / 0.12))
	DSP.envelope(b, 0.002, 0.3, 0.02)
	DSP.crush(b, 10, 24000.0)
	return b


## A Mega Drive FM lead: brassy (modulator at the carrier's pitch) with a hollow, detuned second
## voice, a quick glide from `from_hz` (0 = none) and vibrato that fades in on long notes.
static func fm_lead(hz: float, seconds: float, from_hz: float, vibrato: float) -> PackedFloat32Array:
	var b := DSP.buffer(seconds + 0.06)
	var pc: float = 0.0
	var pm: float = 0.0
	var pc2: float = 0.0
	var pm2: float = 0.0
	for i: int in b.size():
		var t: float = float(i) / RATE
		var f: float = hz
		if from_hz > 0.0:
			f = hz * pow(from_hz / hz, exp(-t / 0.03))
		f *= pow(2.0, vibrato * sin(TAU * 5.5 * t) * smoothstep(0.18, 0.45, t) / 12.0)
		var index: float = 1.1 + 2.0 * exp(-t / 0.09)
		pc = fmod(pc + f / RATE, 1.0)
		pm = fmod(pm + f / RATE, 1.0)
		pc2 = fmod(pc2 + f * 1.0035 / RATE, 1.0)
		pm2 = fmod(pm2 + f * 2.007 / RATE, 1.0)
		b[i] = 0.65 * sin(TAU * pc + index * sin(TAU * pm)) + 0.35 * sin(TAU * pc2 + index * 0.8 * sin(TAU * pm2))
	DSP.adsr(b, 0.008, 0.25, 0.8, 0.06)
	DSP.drive(b, 1.6)
	DSP.crush(b, 11, 22000.0)
	return b


## A dirty synth lead for grim streets: two detuned saws over a square an octave down, through a
## resonant low-pass, overdriven and crushed to 7 bits, with a slow slide from `from_hz` (0 = none)
## and wide, slow vibrato.
static func dirty_lead(hz: float, seconds: float, from_hz: float, vibrato: float,
		rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := DSP.buffer(seconds + 0.08)
	var n: int = b.size()
	var inc := PackedFloat32Array()
	inc.resize(n)
	for i: int in n:
		var t: float = float(i) / RATE
		var f: float = hz
		if from_hz > 0.0:
			f = hz * pow(from_hz / hz, exp(-t / 0.06))
		f *= pow(2.0, vibrato * sin(TAU * 4.5 * t) * smoothstep(0.2, 0.6, t) / 12.0)
		inc[i] = f / RATE
	for detune: float in [0.993, 1.007]:
		var p: float = rng.randf()
		for i: int in n:
			var dt: float = inc[i] * detune
			p += dt
			if p >= 1.0:
				p -= 1.0
			b[i] += (2.0 * p - 1.0 - _blep(p, dt)) * 0.4
	var q: float = 0.0
	for i: int in n:
		q = fmod(q + inc[i] * 0.5, 1.0)
		b[i] += 0.3 if q < 0.5 else -0.3
	DSP.filter(b, &"lowpass", 2200.0, 1.6)
	DSP.drive(b, 4.0, 0.1)
	DSP.filter(b, &"lowpass", 3500.0, 0.7)
	DSP.adsr(b, 0.012, 0.3, 0.85, 0.08)
	DSP.crush(b, 7, 16000.0)
	return b


## A distorted single-note guitar through the same kind of amp as DSP.power_chord. It slides up
## into the note from `bend_from` semitones below (0 = none); `vibrato` (semitones) wobbles long notes.
static func guitar_note(hz: float, seconds: float, muted: bool, bend_from: float, vibrato: float,
		rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := DSP.buffer(seconds + (0.02 if muted else 0.08))
	var n: int = b.size()
	var pitch := PackedFloat32Array()
	pitch.resize(n)
	for i: int in n:
		var t: float = float(i) / RATE
		var semis: float = -bend_from * exp(-t / 0.05)
		if vibrato > 0.0:
			semis += vibrato * sin(TAU * 5.8 * t) * smoothstep(0.15, 0.4, t)
		pitch[i] = hz * pow(2.0, semis / 12.0) / RATE
	for cents: float in [-5.0, 6.0]:
		var phase: float = rng.randf()
		var mult: float = pow(2.0, cents / 1200.0)
		for i: int in n:
			phase = fmod(phase + pitch[i] * mult, 1.0)
			b[i] += (phase * 2.0 - 1.0) * 0.45
	var tau: float = 0.08 if muted else 2.5
	for i: int in n:
		b[i] *= exp(-float(i) / RATE / tau)
	DSP.filter(b, &"highpass", 160.0)
	DSP.filter(b, &"lowpass", 800.0 if muted else 2800.0)
	DSP.drive(b, 22.0, 0.07)
	DSP.filter(b, &"lowpass", 4300.0, 0.9)
	DSP.filter(b, &"lowpass", 3400.0, 0.7)
	DSP.filter(b, &"peaking", 1400.0, 1.0, 3.0)
	DSP.filter(b, &"peaking", 700.0, 0.9, -4.0)
	DSP.filter(b, &"highpass", 90.0)
	DSP.adsr(b, 0.003, 10.0, 1.0, 0.03 if muted else 0.06)
	return b


## A power chord (sfx_dsp.gd's amp) shaped for a riff: palm-muted chugs die fast, open chords ring
## for the note's length and then are damped.
static func chord(root_hz: float, seconds: float, muted: bool, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := DSP.power_chord(seconds + (0.03 if muted else 0.1), root_hz, muted, rng)
	DSP.envelope(b, 0.002, 0.075 if muted else 1.2, 0.02 if muted else 0.08)
	DSP.crush(b, 11, 24000.0)
	return b


## A warm pad: three detuned band-limited saws per note, low-passed, slow attack and release.
static func pad(midis: Array, seconds: float, cutoff: float, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var freqs: Array = []
	for m: int in midis:
		var hz: float = DSP.midi_hz(m)
		for cents: float in [-9.0, 0.0, 8.0]:
			freqs.append(hz * pow(2.0, cents / 1200.0))
	var b := saws(seconds + 0.4, freqs, 0.2, rng)
	DSP.filter(b, &"lowpass", cutoff, 0.8)
	DSP.filter(b, &"lowpass", cutoff * 1.5, 0.6)
	DSP.adsr(b, 0.25, 1.5, 0.8, 0.4)
	return b


## Noise that swells and brightens into the next downbeat: a section transition.
static func riser(seconds: float, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := DSP.noise(seconds, rng)
	DSP.filter_sweep(b, &"bandpass", 300.0, 7000.0, 1.4)
	var n: int = b.size()
	for i: int in n:
		var u: float = float(i) / n
		b[i] *= u * u
	_fade_out(b, 0.01)
	return b


## A crash cymbal played backwards: sucks into the next downbeat.
static func reverse_crash(seconds: float, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := DSP.crash(seconds, rng)
	b.reverse()
	_fade_out(b, 0.01)
	return b


## A short linear fade at the end, so a sound that stops at full level doesn't click.
static func _fade_out(b: PackedFloat32Array, seconds: float) -> void:
	var count: int = mini(b.size(), int(seconds * RATE))
	for i: int in count:
		b[b.size() - 1 - i] *= float(i) / count


## A deep rumbling hit for big downbeats: a slow sub drop under filtered noise.
static func boom(seconds: float, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := DSP.kick(seconds, 90.0, 32.0, rng)
	var rumble := DSP.noise(seconds, rng)
	DSP.filter(rumble, &"lowpass", 400.0, 0.8)
	DSP.envelope(rumble, 0.002, seconds * 0.3)
	DSP.mix(b, rumble, 0.0, 0.8)
	DSP.envelope(b, 0.001, seconds * 0.4, 0.05)
	return b
