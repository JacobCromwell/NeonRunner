extends "res://tools/asset_gen/sfx_bank.gd"
## The Marketplace intro's own sounds (MarketplaceIntro): the voices. No real words (the owner, October 16, 2026:
## speech-like mumbling, as the grown-ups talk in Charlie Brown, a placeholder for speech): each syllable a "wah", a
## buzzing voice through two vowel resonances that open from an "oo" into the syllable's vowel and close again, the
## sound of a muted trombone talking, with the rise and fall of a sentence. In the same crunchy 16-bit style as the
## rest; none of them is a warning; like every sound effect, each is under 2.5 s.
##   mumble_vendor        the stall-keeper telling the runner all about it: quick, chatty, up and down (2.3 s)
##   mumble_vendor_point  her answer to the cyborg, emphatic, up to a high "that way!" (2.1 s)
##   mumble_cyborg        the cyborg's question to her: low, gruff, slow, with a digital grit (1.8 s)
##   mumble_cyborg_call   the cyborg calling the others over: two loud gruff syllables (0.75 s)

## Vowel resonances (Hz): the two lowest formants of each vowel, and the "oo" every syllable opens from.
const VOWELS: Dictionary = {
	"a": Vector2(760.0, 1220.0),
	"o": Vector2(520.0, 880.0),
	"u": Vector2(620.0, 1150.0),
	"e": Vector2(560.0, 1750.0),
	"i": Vector2(380.0, 2050.0),
}
const OO := Vector2(330.0, 760.0)


func sounds() -> Dictionary:
	return {
		"mumble_vendor": _vendor,
		"mumble_vendor_point": _vendor_point,
		"mumble_cyborg": _cyborg,
		"mumble_cyborg_call": _cyborg_call,
	}


## Quick and chatty, two phrases, the first rising like a question, the second running down.
func _vendor() -> PackedFloat32Array:
	var s: Array = [
		[0.02, 0.17, 1.0, 1.05, "a", 0.8], [0.2, 0.15, 1.08, 1.1, "e", 0.7], [0.36, 0.2, 1.12, 1.02, "a", 0.9],
		[0.58, 0.16, 1.0, 0.98, "o", 0.7], [0.76, 0.18, 1.04, 1.16, "a", 0.85], [0.96, 0.26, 1.2, 1.32, "e", 1.0],
		[1.32, 0.15, 1.1, 1.12, "a", 0.8], [1.48, 0.16, 1.14, 1.06, "u", 0.75], [1.66, 0.18, 1.04, 0.98, "a", 0.85],
		[1.86, 0.15, 0.98, 0.94, "o", 0.7], [2.02, 0.24, 0.94, 0.84, "a", 0.8],
	]
	return _mumble(2.3, s, 225.0, false, 3101)


## Emphatic, building to a high, long "that way!".
func _vendor_point() -> PackedFloat32Array:
	var s: Array = [
		[0.02, 0.16, 1.0, 1.04, "u", 0.75], [0.2, 0.16, 1.06, 1.08, "a", 0.8], [0.38, 0.2, 1.1, 1.16, "e", 0.9],
		[0.66, 0.16, 1.1, 1.12, "a", 0.8], [0.84, 0.16, 1.16, 1.2, "o", 0.85], [1.02, 0.22, 1.24, 1.3, "a", 1.0],
		[1.36, 0.2, 1.36, 1.46, "e", 1.0], [1.58, 0.48, 1.5, 1.22, "a", 1.0],
	]
	return _mumble(2.1, s, 230.0, false, 3102)


## Low and slow, a gruff question that falls away at the end.
func _cyborg() -> PackedFloat32Array:
	var s: Array = [
		[0.02, 0.22, 1.0, 0.98, "o", 0.9], [0.27, 0.2, 1.0, 1.02, "a", 0.85], [0.5, 0.26, 1.06, 1.0, "u", 1.0],
		[0.84, 0.2, 0.98, 0.96, "a", 0.85], [1.07, 0.22, 1.02, 1.08, "e", 0.9], [1.33, 0.4, 1.06, 0.86, "o", 0.95],
	]
	return _mumble(1.8, s, 98.0, true, 3103)


## Two loud gruff syllables, the second higher and held: "hey, you lot!".
func _cyborg_call() -> PackedFloat32Array:
	var s: Array = [[0.02, 0.2, 1.05, 1.15, "e", 0.9], [0.26, 0.42, 1.28, 1.1, "a", 1.0]]
	return _mumble(0.75, s, 104.0, true, 3104)


## A mumbling voice `seconds` long: syllables [start, length, pitch at its start and end (times `pitch`), vowel,
## loudness]; `gruff` for a cyborg's (lower, a rasp at half its pitch, a breathy edge, overdriven, crushed).
func _mumble(seconds: float, syllables: Array, pitch: float, gruff: bool, seed_value: int) -> PackedFloat32Array:
	var rng := _rng(seed_value)
	var b := DSP.buffer(seconds)
	var phase: float = 0.0
	var sub: float = 0.0
	# Two band-passes (state-variable filters) for the vowel resonances, and the mute's low-pass.
	var lo1: float = 0.0
	var bp1: float = 0.0
	var lo2: float = 0.0
	var bp2: float = 0.0
	var mute: float = 0.0
	var wobble: float = rng.randf() * TAU
	var k: int = 0
	for i: int in b.size():
		var t: float = float(i) / RATE
		while k < syllables.size() - 1 and t > float(syllables[k][0]) + float(syllables[k][1]):
			k += 1
		var syl: Array = syllables[k]
		var u: float = (t - float(syl[0])) / float(syl[1])
		# The syllable's swell: in quickly, held, out; nothing between syllables.
		var env: float = 0.0
		if u >= 0.0 and u <= 1.0:
			env = smoothstep(0.0, 0.14, u) * (1.0 - smoothstep(0.72, 1.0, u)) * float(syl[5])
		# The pitch: gliding through the syllable, a little vibrato and jitter.
		var glide: float = lerpf(float(syl[2]), float(syl[3]), clampf(u, 0.0, 1.0))
		var f0: float = pitch * glide * (1.0 + 0.018 * sin(TAU * 5.5 * t + wobble)) * (1.0 + rng.randf_range(-0.006, 0.006))
		phase = fmod(phase + f0 / RATE, 1.0)
		var src: float = 2.0 * phase - 1.0
		if gruff:
			# A rasp: a pulse at half the pitch under it, and breath.
			sub = fmod(sub + f0 * 0.5 / RATE, 1.0)
			src += (0.55 if sub < 0.5 else -0.55) + rng.randf_range(-0.25, 0.25)
		# The vowel: opening from "oo" into the syllable's vowel, closing toward "m" at its end.
		var vowel: Vector2 = VOWELS[String(syl[4])]
		var open: float = smoothstep(0.0, 0.38, u) * (1.0 - 0.45 * smoothstep(0.7, 1.0, u))
		var f: Vector2 = OO.lerp(vowel, clampf(open, 0.0, 1.0)) * (0.82 if gruff else 1.0)
		var g1: float = 2.0 * sin(PI * f.x / RATE)
		var g2: float = 2.0 * sin(PI * f.y / RATE)
		var hp1: float = src - lo1 - 0.35 * bp1
		bp1 += g1 * hp1
		lo1 += g1 * bp1
		var hp2: float = src - lo2 - 0.3 * bp2
		bp2 += g2 * hp2
		lo2 += g2 * bp2
		var y: float = bp1 * 0.55 + bp2 * 0.3 + lo1 * 0.08
		# The mute: a low-pass that opens with the syllable's swell (the "wah").
		var cut: float = 450.0 + 2600.0 * clampf(env * 1.2, 0.0, 1.0)
		mute += (y - mute) * (1.0 - exp(-TAU * cut / RATE))
		b[i] = mute * env
	if gruff:
		DSP.drive(b, 2.2)
		DSP.filter(b, &"lowpass", 3200.0)
		DSP.crush(b, 9, 14000.0)
	else:
		DSP.filter(b, &"highpass", 140.0)
		DSP.crush(b, 11, 22000.0)
	return b
