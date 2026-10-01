extends "res://tools/asset_gen/sfx_bank.gd"
## The Sleep Taker's sounds (GDD §10), in the same crunchy 16-bit / heavy-metal style as the rest: the
## Bad Dream's voice (sfx_bank_enemies.gd), grown into a choir of fused nightmares. Every attack's
## warning has a character of its own (CLAUDE.md readability rules):
##   sleep_taker_rise     its entrance: a deep rumble swelling under a chorus of moans a semitone
##                        apart, rising out of the street, ending in a breathy rush
##   sleep_taker_shriek   the giant slash's warning (GDD §10: "the maw opens with a shriek, the Bad
##                        Dream's warning, bigger"): the Bad Dream's tritone scream sung by a choir of
##                        voices over a low growl, swelling from nothing as its great maw gapes
##   sleep_taker_slash    the slash itself: a huge, low swish across the street, five claws ringing like
##                        blades and a deep thud
##   sleep_taker_whisper  the grasping hands' warning (GDD §10: "purple mist pools in the lane, with
##                        whispering"): many breathy voices whispering made-up words over each other,
##                        sibilant and close, swelling as the mist pools
##   sleep_taker_hand     a hand bursting up out of the mist: a wet crack of rubble, a gulp of air and a
##                        thud, then the clawed fingers' scrape as it grasps
##   sleep_taker_inhale   lights out's warning (GDD §10: "after a deep inhale, it swallows much of the
##                        light"): a long, rising, rasping inhale through dozens of maws over a moan,
##                        ending in a deep gulp as the light goes
##   sleep_taker_exhale   the light coming back: a long, sinking sigh that dies away


func sounds() -> Dictionary:
	return {
		"sleep_taker_rise": _rise,
		"sleep_taker_shriek": _shriek,
		"sleep_taker_slash": _slash,
		"sleep_taker_whisper": _whisper,
		"sleep_taker_hand": _hand,
		"sleep_taker_inhale": _inhale,
		"sleep_taker_exhale": _exhale,
	}


## Its entrance: a rumble swelling from the street with a chorus of moans rising a semitone apart.
func _rise() -> PackedFloat32Array:
	var rng := _rng(501)
	var d: float = 2.3
	var b := DSP.buffer(d)
	var rumble := DSP.noise(d, rng)
	DSP.filter(rumble, &"lowpass", 120.0, 0.9)
	DSP.adsr(rumble, 0.9, 0.6, 0.7, 0.6)
	DSP.mix(b, rumble, 0.0, 2.2)
	var drone := DSP.buffer(d)
	for base: float in [55.0, 58.27, 82.41]:
		DSP.mix(drone, DSP.osc(d, func(u: float) -> float: return base * pow(2.0, 3.0 * u / 12.0), &"saw"), 0.0, 0.3)
	DSP.filter(drone, &"lowpass", 500.0)
	DSP.adsr(drone, 1.0, 0.5, 0.8, 0.5)
	DSP.drive(drone, 2.0)
	DSP.mix(b, drone, 0.0, 0.8)
	var pitches: Array = [196.0, 207.65, 233.08, 277.18, 311.13]
	for k: int in pitches.size():
		var p0: float = float(pitches[k])
		var moan := _voice(1.6, func(u: float) -> float: return DSP.sweep(p0 * 0.85, p0 * 1.08, u), Vector2(300.0, 700.0),
			Vector2(800.0, 1150.0), 4.5 + k * 0.6, 0.5, rng)
		DSP.adsr(moan, 0.5, 0.4, 0.75, 0.4)
		DSP.mix(b, moan, 0.35 + 0.12 * k, 0.32)
	var rush := _whoosh(0.8, 300.0, 3000.0, 0.8, rng)
	DSP.mix(b, rush, 1.45, 0.6)
	DSP.crush(b, 10, 20000.0)
	return b


## The giant slash's warning: the Bad Dream's tritone shriek, bigger: a choir of screaming voices
## over a low growl, swelling in as its great maw opens, holding to the lunge.
func _shriek() -> PackedFloat32Array:
	var rng := _rng(502)
	var d: float = 1.55
	var b := DSP.buffer(d)
	var voices: Array = [[523.25, 0.5], [740.0, 0.9], [1046.5, 0.6], [1480.0, 0.35], [370.0, 0.45]]
	for k: int in voices.size():
		var hz: float = float(voices[k][0])
		var v := _voice(d, func(u: float) -> float: return hz * (1.0 + 0.05 * u), Vector2(400.0 + 80.0 * k, 900.0),
			Vector2(2400.0 + 150.0 * k, 1700.0), 7.0 + k * 0.8, 0.7, rng)
		DSP.mix(b, v, 0.0, float(voices[k][1]))
	var growl := DSP.osc(d, func(u: float) -> float: return DSP.sweep(55.0, 49.0, u), &"saw")
	DSP.drive(growl, 4.0, 0.1)
	DSP.filter(growl, &"lowpass", 700.0)
	DSP.mix(b, growl, 0.0, 0.35)
	var gape := _whoosh(0.6, 200.0, 2500.0, 1.0, rng)
	DSP.mix(b, gape, 0.0, 0.5)
	DSP.adsr(b, 0.35, 0.5, 0.85, 0.12)
	DSP.drive(b, 2.2)
	DSP.filter(b, &"highpass", 70.0)
	DSP.crush(b, 9, 20000.0)
	return b


## The slash: a huge low swish across the street, five claws ringing, a deep thud.
func _slash() -> PackedFloat32Array:
	var rng := _rng(503)
	var b := _whoosh(0.75, 3200.0, 380.0, 1.1, rng)
	for k: int in 5:
		DSP.mix(b, _fm_note(0.32, 1900.0 + 230.0 * k, 1.41, 3.4, 0.5, 0.1), 0.06 + 0.035 * k, 0.28)
	DSP.mix(b, DSP.kick(0.35, 70.0, 38.0, rng), 0.02, 0.7)
	DSP.drive(b, 1.6)
	DSP.crush(b, 9, 20000.0)
	return b


## The hands' warning: many breathy voices whispering made-up words over each other, sibilant and close.
func _whisper() -> PackedFloat32Array:
	var rng := _rng(504)
	var d: float = 1.35
	var b := DSP.buffer(d)
	for voice: int in 4:
		var at: float = 0.04 * voice
		var f1: float = 650.0 + 160.0 * voice
		while at < d - 0.12:
			var syl: float = rng.randf_range(0.07, 0.17)
			# A breathy vowel: noise through two formants, gliding.
			var vowel := DSP.noise(syl, rng)
			var low := vowel.duplicate()
			DSP.filter_sweep(low, &"bandpass", f1 * rng.randf_range(0.8, 1.1), f1 * rng.randf_range(0.9, 1.3), 5.0)
			DSP.filter_sweep(vowel, &"bandpass", rng.randf_range(1600.0, 2400.0), rng.randf_range(1400.0, 2600.0), 6.0)
			DSP.mix(vowel, low, 0.0, 1.2)
			DSP.adsr(vowel, syl * 0.3, syl * 0.3, 0.6, syl * 0.3)
			DSP.mix(b, vowel, at, 0.55)
			at += syl
			if rng.randf() < 0.45:
				# A hiss: an "s" or a "sh".
				var hiss_len: float = rng.randf_range(0.05, 0.12)
				var hiss := DSP.noise(hiss_len, rng)
				DSP.filter(hiss, &"bandpass", rng.randf_range(4200.0, 7200.0), 2.0)
				DSP.adsr(hiss, hiss_len * 0.4, 0.0, 1.0, hiss_len * 0.5)
				DSP.mix(b, hiss, at, 0.45)
				at += hiss_len
			at += rng.randf_range(0.0, 0.05)
	var n: int = b.size()
	for i: int in n:
		var u: float = float(i) / n
		b[i] *= smoothstep(0.0, 0.25, u) * (1.0 - smoothstep(0.85, 1.0, u))
	DSP.crush(b, 11, 22000.0)
	return b


## A hand bursting up out of the mist: a wet crack, a thud, and the claws' scrape as it grasps.
func _hand() -> PackedFloat32Array:
	var rng := _rng(505)
	var d: float = 0.75
	var b := DSP.buffer(d)
	var burst := DSP.noise(0.3, rng)
	DSP.filter_sweep(burst, &"lowpass", 5000.0, 300.0, 0.9)
	DSP.envelope(burst, 0.002, 0.09)
	DSP.mix(b, burst, 0.0, 1.0)
	DSP.mix(b, _crackle(0.4, 26, 0.12, 2200.0, rng), 0.0, 0.7)
	DSP.mix(b, DSP.kick(0.3, 95.0, 45.0, rng), 0.0, 0.8)
	var gulp := _voice(0.2, func(u: float) -> float: return DSP.sweep(260.0, 120.0, u), Vector2(700.0, 300.0),
		Vector2(1300.0, 800.0), 0.0, 0.0, rng)
	DSP.envelope(gulp, 0.01, 0.08)
	DSP.mix(b, gulp, 0.05, 0.5)
	for k: int in 3:
		var scrape := DSP.noise(0.14, rng)
		DSP.filter(scrape, &"bandpass", 3200.0 + 500.0 * k, 4.0)
		DSP.envelope(scrape, 0.005, 0.05)
		DSP.mix(b, scrape, 0.3 + 0.07 * k, 0.4)
	DSP.drive(b, 1.8)
	DSP.crush(b, 9, 18000.0)
	return b


## Lights out's warning: a long rasping inhale through dozens of maws rising over a moan, ending in a
## deep gulp as the light goes.
func _inhale() -> PackedFloat32Array:
	var rng := _rng(506)
	var d: float = 2.25
	var b := DSP.buffer(d)
	var breath_len: float = 1.95
	var air := DSP.noise(breath_len, rng)
	DSP.filter_sweep(air, &"bandpass", 280.0, 2600.0, 1.6)
	var rasp := DSP.noise(breath_len, rng)
	DSP.filter_sweep(rasp, &"bandpass", 900.0, 4200.0, 3.0)
	DSP.mix(air, rasp, 0.0, 0.5)
	var n: int = air.size()
	var phase: float = 0.0
	for i: int in n:
		var u: float = float(i) / n
		# The rasp flutters faster as it fills up.
		phase += lerpf(9.0, 22.0, u) / DSP.RATE
		air[i] *= pow(u, 1.4) * (0.75 + 0.25 * sin(TAU * phase))
	DSP.mix(b, air, 0.0, 1.0)
	var moan := _voice(breath_len, func(u: float) -> float: return DSP.sweep(98.0, 147.0, u), Vector2(350.0, 600.0),
		Vector2(800.0, 1000.0), 3.0, 0.4, rng)
	DSP.adsr(moan, 0.8, 0.4, 0.8, 0.2)
	DSP.mix(b, moan, 0.0, 0.45)
	var gulp := DSP.kick(0.3, 80.0, 32.0, rng)
	DSP.mix(b, gulp, breath_len - 0.03, 1.4)
	var drop := _voice(0.25, func(u: float) -> float: return DSP.sweep(180.0, 60.0, u), Vector2(600.0, 250.0),
		Vector2(1100.0, 700.0), 0.0, 0.0, rng)
	DSP.envelope(drop, 0.01, 0.1)
	DSP.mix(b, drop, breath_len - 0.02, 0.6)
	DSP.crush(b, 10, 20000.0)
	return b


## The light coming back: a long sigh sinking and dying away.
func _exhale() -> PackedFloat32Array:
	var rng := _rng(507)
	var d: float = 1.6
	var b := DSP.noise(d, rng)
	DSP.filter_sweep(b, &"bandpass", 2400.0, 260.0, 1.4)
	var n: int = b.size()
	for i: int in n:
		var u: float = float(i) / n
		b[i] *= smoothstep(0.0, 0.08, u) * pow(1.0 - u, 1.6)
	var moan := _voice(d, func(u: float) -> float: return DSP.sweep(147.0, 92.0, u), Vector2(600.0, 320.0),
		Vector2(1000.0, 760.0), 3.5, 0.5, rng)
	DSP.envelope(moan, 0.1, 0.7, 0.2)
	DSP.mix(b, moan, 0.0, 0.5)
	DSP.crush(b, 10, 20000.0)
	return b
