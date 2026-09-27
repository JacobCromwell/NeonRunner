extends "res://tools/asset_gen/sfx_bank.gd"
## The level-complete riff (GDD §11: it plays in each zone's key), one per music track: two palm-muted
## chugs on the root, one on the third, then the fourth rings out. level_complete is the riff in E,
## the City's key, and the fallback for any track without its own; level_complete_<track> is the same
## riff in that track's key, on its beat (eighths or sixteenths of its tempo) and with its sound.
## MusicDirector.level_complete_sound() picks the one for the music playing. Each ends before
## LevelRun.COMPLETE_PAUSE (2 s), when the run and its sounds are freed for the results screen.

const E2: float = 82.41
const G2: float = 98.0
const A2: float = 110.0
## How long each riff may last (s), under LevelRun.COMPLETE_PAUSE.
const LONGEST: float = 1.9


func sounds() -> Dictionary:
	return {
		"level_complete": _level_complete,
		"level_complete_gangland": _gangland,
		"level_complete_marketplace": _marketplace,
		"level_complete_corporate": _corporate,
		"level_complete_dead_zone": _dead_zone,
		"level_complete_golden": _golden,
	}


## The City (E minor, eighths at 170 BPM): E5 chug, chug, G5, then A5 rings out with a crash.
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


## Gangland (D phrygian, heavy eighths at 120 BPM): D, D, F, then G rings, the kick on every hit, an
## anvil on the last, crushed like the track.
func _gangland() -> PackedFloat32Array:
	var rng := _rng(301)
	var gap: float = 60.0 / 120.0 / 2.0
	var b := _riff(73.42, 3, gap, 1.1, rng)
	var kick := DSP.kick(0.4, 140.0, 44.0, rng)
	DSP.drive(kick, 3.0)
	DSP.crush(kick, 8, 16000.0)
	for hit: int in 4:
		DSP.mix(b, kick, gap * hit, 0.45 if hit < 3 else 0.75)
	DSP.mix(b, DSP.metal_hit(0.6, 310.0, 0.16, rng), gap * 3.0, 0.3)
	var crash := DSP.crash(0.9, rng)
	DSP.crush(crash, 8, 14000.0)
	DSP.mix(b, crash, gap * 3.0, 0.12)
	DSP.crush(b, 9, 16000.0)
	return b


## Marketplace (Bb major, bouncy eighths at 144 BPM): Bb, Bb, D, then Eb rings, crowned by the horn
## section's Eb major stab, with a tambourine on every hit and a crash.
func _marketplace() -> PackedFloat32Array:
	var rng := _rng(302)
	var gap: float = 60.0 / 144.0 / 2.0
	var b := _riff(116.54, 4, gap, 1.2, rng)
	for midi: int in [63, 67, 70]:
		var horn := Inst.fm_horn(DSP.midi_hz(midi), 0.9, rng)
		DSP.envelope(horn, 0.005, 0.6, 0.2)
		DSP.mix(b, horn, gap * 3.0, 0.2)
	for hit: int in 4:
		DSP.mix(b, DSP.hat(0.14, 0.045, rng), gap * hit, 0.25)
	DSP.mix(b, DSP.kick(0.25, 170.0, 52.0, rng), gap * 3.0, 0.7)
	DSP.mix(b, DSP.crash(0.9, rng), gap * 3.0, 0.12)
	DSP.crush(b, 11, 24000.0)
	return b


## Corporate (B minor, drop-B, tight sixteenths at 112 BPM): B, B, D, then E rings, the kick locked to
## every hit, under a cold synth-brass swell and a timpani.
func _corporate() -> PackedFloat32Array:
	var rng := _rng(303)
	var gap: float = 60.0 / 112.0 / 4.0
	var b := _riff(61.74, 3, gap, 1.3, rng)
	var kick := DSP.kick(0.22, 200.0, 55.0, rng)
	for hit: int in 4:
		DSP.mix(b, kick, gap * hit, 0.55 if hit < 3 else 0.8)
	DSP.mix(b, Inst.cs_brass([64, 67, 71], 1.0, rng), gap * 3.0, 0.3)
	DSP.mix(b, Inst.timpani(164.81, 1.2, rng), gap * 3.0, 0.4)
	DSP.crush(b, 11, 24000.0)
	return b


## Dead Zone (C# minor, sixteenths at 84 BPM): C#, C#, E, then F# rings, darker and left to die away
## over a low boom and a ghostly tremolo guitar; no crash.
func _dead_zone() -> PackedFloat32Array:
	var rng := _rng(304)
	var gap: float = 60.0 / 84.0 / 4.0
	var b := _riff(69.30, 3, gap, 1.3, rng)
	DSP.filter(b, &"lowpass", 2600.0, 0.7)
	DSP.mix(b, Inst.boom(1.3, rng), gap * 3.0, 0.5)
	DSP.mix(b, Inst.clean_guitar(DSP.midi_hz(66), 1.1, 5.6, rng), gap * 3.0, 0.35)
	DSP.crush(b, 11, 24000.0)
	return b


## Golden Zone (F# harmonic minor, eighths at 132 BPM): F#, F#, A, then B rings, crowned by a
## harpsichord flourish up the B minor chord, with a timpani and a crash.
func _golden() -> PackedFloat32Array:
	var rng := _rng(305)
	var gap: float = 60.0 / 132.0 / 2.0
	var b := _riff(92.50, 3, gap, 1.2, rng)
	var thirty_second: float = gap / 4.0
	var flourish: Array[int] = [59, 62, 66, 71, 74, 78]
	for k: int in flourish.size():
		DSP.mix(b, Inst.harpsichord(DSP.midi_hz(flourish[k]), 0.5, rng), gap * 3.0 + k * thirty_second, 0.3)
	DSP.mix(b, Inst.timpani(246.94, 1.2, rng), gap * 3.0, 0.4)
	DSP.mix(b, DSP.kick(0.3, 180.0, 50.0, rng), gap * 3.0, 0.6)
	DSP.mix(b, DSP.crash(0.9, rng), gap * 3.0, 0.12)
	DSP.crush(b, 11, 24000.0)
	return b


## The riff's guitar: chugs on the root, the root and the third (`third` semitones up: 3 in a minor
## key, 4 in a major one), `gap` seconds apart, then the fourth rings for `ring` seconds.
func _riff(root_hz: float, third: int, gap: float, ring: float, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := DSP.buffer(minf(gap * 3.0 + ring, LONGEST))
	var steps: Array[int] = [0, 0, third, 5]
	for i: int in steps.size():
		var muted: bool = i < 3
		var hz: float = root_hz * pow(2.0, steps[i] / 12.0)
		var chord := DSP.power_chord(gap if muted else ring, hz, muted, rng)
		DSP.envelope(chord, 0.002, 0.07 if muted else ring * 0.55, 0.02 if muted else 0.2)
		DSP.mix(b, chord, gap * i)
	return b
