extends "res://tools/asset_gen/sfx_bank.gd"
## The Golden Convergence's sounds (GDD §10, task E5d-a), in the game's 16-bit style. Its warnings sound the
## same every time (no pitch variation in data/audio/sfx_library.tres) and last as long as their warnings,
## read from the fight's tuning (data/bosses/golden_boss_tuning.tres: regenerate them when those change):
##   gc_rise      the entrance: something enormous rising at the far end of the court, a deep rumble and a
##                mechanical groan swelling over rise_seconds, the cape unfurling in a heavy rush of cloth
##   gc_chime     the cult's three-note chime (the Resonator's G5, C6, E6, §9.10) rung huge and slow: each
##                note doubled an octave and two below, ringing long, echoing round the court
##   gc_emerge    the squadron coming out of the cape: a rustle of cloth, three rotors spinning up
##   gc_whine     a pass's warning (as long as warning_seconds): the squadron's gatlings spinning up as one, a
##                motor climbing in three voices over barrel clicks speeding into a rattle and a rising whine
##   gc_rake      a vertical pass's fire raking down the lanes: sustained gatling cracks over the rotors and
##                rounds chewing the stone
##   gc_sweep     a horizontal pass's fire sweeping across the track: gatling cracks swept through a band
##                filter, then the line burning (a hiss dying away)
##   gc_spark     the fire meeting the Flying Buttress: ricochets pinging off its stone and gold, a crackle
##   gc_buttress  a Flying Buttress rising out of the causeway: stone grinding up, a solid thud as it locks
##   gc_crumble   a Flying Buttress crumbling: a crack, rubble falling, a deep thud
##   gc_hurl      a drone hurled up by a pad: a spring's twang, its rotor screaming up and away
##   gc_return    the squadron going back into the cape: the rotors receding under a rush of cloth

const TUNING_PATH: String = "res://data/bosses/golden_boss_tuning.tres"
## The Resonator's chime (sfx_bank_resonator.gd): its notes, struck the same way.
const ResonatorBank = preload("res://tools/asset_gen/sfx_bank_resonator.gd")
## The chime's notes rung slow: seconds from the first.
const CHIME_AT: Array[float] = [0.0, 0.85, 1.7]


func sounds() -> Dictionary:
	return {
		"gc_rise": _rise,
		"gc_chime": _chime,
		"gc_emerge": _emerge,
		"gc_whine": _whine,
		"gc_rake": _rake,
		"gc_sweep": _sweep,
		"gc_spark": _spark,
		"gc_buttress": _buttress,
		"gc_crumble": _crumble,
		"gc_hurl": _hurl,
		"gc_return": _return,
	}


## A number from the fight's tuning (`fallback` if it can't be read).
static func tuning_value(prop: String, fallback: float) -> float:
	var t: Resource = load(TUNING_PATH) if ResourceLoader.exists(TUNING_PATH) else null
	if t == null or t.get(prop) == null:
		return fallback
	return float(t.get(prop))


## Rotor chop: noise through a band-pass, chopped by blades turning at `chop_hz` (from, to), `level` over
## the sound (from, to).
func _rotor(seconds: float, chop_from: float, chop_to: float, band_from: float, band_to: float, level_from: float,
		level_to: float, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := DSP.noise(seconds, rng)
	var n: int = b.size()
	var f := DSP.Biquad.new()
	var chop: float = rng.randf()
	for i: int in n:
		var u: float = float(i) / n
		if i % 16 == 0:
			f.set_filter(&"bandpass", lerpf(band_from, band_to, u), 1.2)
		chop += lerpf(chop_from, chop_to, u) / RATE
		b[i] = f.process(b[i]) * pow(0.5 + 0.5 * cos(TAU * chop), 3.0) * lerpf(level_from, level_to, u) * 2.5
	return b


## Heavy cloth rushing: noise through a low band-pass that flutters, swelling and fading.
func _cloth(seconds: float, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := DSP.noise(seconds, rng)
	DSP.filter_sweep(b, &"bandpass", 260.0, 700.0, 0.8)
	var n: int = b.size()
	for i: int in n:
		var t: float = float(i) / RATE
		var u: float = float(i) / n
		b[i] *= pow(sin(PI * u), 1.2) * (0.75 + 0.25 * sin(TAU * 7.0 * t + 2.0 * sin(TAU * 1.3 * t)))
	return b


## One gatling round: a sharp crack.
func _round(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var shot := DSP.noise(0.05, rng)
	DSP.filter(shot, &"bandpass", 2300.0, 0.9)
	DSP.envelope(shot, 0.0005, 0.012)
	DSP.mix(shot, DSP.kick(0.04, 650.0, 260.0, rng), 0.0, 0.3)
	return shot


## The entrance: a sub rumble and a mechanical groan swelling as it rises, a deep hum climbing, and the cape
## unfurling (a heavy rush of cloth from unfurl_at).
func _rise() -> PackedFloat32Array:
	var rng := _rng(1701)
	var d: float = clampf(tuning_value("rise_seconds", 3.2), 1.5, 5.0)
	var unfurl_at: float = clampf(tuning_value("unfurl_at", 1.0), 0.0, d - 0.5)
	var length: float = maxf(d, unfurl_at + 1.6) + 0.4
	var b := DSP.buffer(length)
	var rumble := DSP.noise(length, rng)
	DSP.filter(rumble, &"lowpass", 140.0)
	DSP.filter(rumble, &"lowpass", 140.0)
	DSP.shape(rumble, d * 0.7, 0.6)
	DSP.mix(b, rumble, 0.0, 2.2)
	var hum := DSP.osc(length, func(u: float) -> float: return DSP.sweep(36.0, 62.0, minf(u * length / d, 1.0)), &"saw")
	DSP.filter(hum, &"lowpass", 420.0)
	DSP.shape(hum, d * 0.6, 0.5)
	DSP.mix(b, hum, 0.0, 0.5)
	var groan := DSP.fm(length, func(u: float) -> float: return DSP.sweep(70.0, 96.0, u), 1.41,
		func(u: float) -> float: return 2.5 + 1.5 * sin(u * 9.0))
	DSP.filter(groan, &"bandpass", 260.0, 0.9)
	DSP.shape(groan, d * 0.5, 0.7)
	DSP.mix(b, groan, 0.0, 0.35)
	# Its plates creaking as it rises (heard on a phone's speaker too).
	var creak := DSP.osc(length, func(u: float) -> float: return DSP.sweep(140.0, 190.0, u) * (1.0 + 0.04 * sin(u * 40.0)), &"saw")
	DSP.filter(creak, &"bandpass", 1100.0, 2.5)
	DSP.shape(creak, d * 0.6, 0.6)
	DSP.mix(b, creak, 0.0, 0.9)
	DSP.mix(b, _cloth(1.8, rng), unfurl_at, 0.9)
	DSP.drive(b, 1.6)
	DSP.crush(b, 10, 20000.0)
	return b


## The cult's chime, huge and slow: the Resonator's mallet-and-glass notes (G5, C6, E6) on CHIME_AT, each
## doubled an octave and two octaves down so it fills the court, ringing long, with a hall's echo.
func _chime() -> PackedFloat32Array:
	var rng := _rng(1702)
	var resonator: RefCounted = ResonatorBank.new()
	var hz: Array[float] = ResonatorBank.CHIME_HZ
	var length: float = CHIME_AT[-1] + 2.6
	var b := DSP.buffer(length)
	for k: int in hz.size():
		var ring: float = length - CHIME_AT[k]
		DSP.mix(b, resonator.call(&"_chime_note", hz[k], ring, rng), CHIME_AT[k], 0.7)
		DSP.mix(b, resonator.call(&"_chime_note", hz[k] * 0.5, ring, rng), CHIME_AT[k], 0.8)
		var low := DSP.osc(ring, func(_u: float) -> float: return hz[k] * 0.25, &"triangle")
		DSP.envelope(low, 0.01, 1.4, 0.2)
		DSP.mix(b, low, CHIME_AT[k], 0.35)
	# The court's echo: a few taps, each darker and softer.
	var dry: PackedFloat32Array = b.duplicate()
	for tap: Vector2 in [Vector2(0.23, 0.32), Vector2(0.47, 0.22), Vector2(0.81, 0.14)]:
		var echo: PackedFloat32Array = dry.duplicate()
		DSP.filter(echo, &"lowpass", 2600.0)
		DSP.mix(b, echo.slice(0, maxi(echo.size() - int(tap.x * RATE), 0)), tap.x, tap.y)
	DSP.filter(b, &"highpass", 70.0)
	DSP.crush(b, 11, 26000.0)
	return b


## The squadron out of the cape: a rustle of cloth, then three rotors spinning up, a little apart.
func _emerge() -> PackedFloat32Array:
	var rng := _rng(1703)
	var d: float = 1.5
	var b := DSP.buffer(d)
	DSP.mix(b, _cloth(0.7, rng), 0.0, 0.8)
	for k: int in 3:
		var rotor := _rotor(d - 0.2 - k * 0.12, 6.0, 23.0 + k * 1.5, 500.0, 1300.0 + k * 120.0, 0.2, 1.0, rng)
		DSP.shape(rotor, 0.25, 0.1)
		DSP.mix(b, rotor, 0.15 + k * 0.12, 0.45)
	DSP.drive(b, 1.4)
	DSP.crush(b, 9, 20000.0)
	return b


## A pass's warning, as long as warning_seconds: the squadron's gatlings spinning up together (the heli drone's
## motor in three voices, climbing), barrel clicks speeding up into a rattle, a high whine rising to the shot.
func _whine() -> PackedFloat32Array:
	var rng := _rng(1704)
	var d: float = clampf(tuning_value("warning_seconds", 1.15), 0.6, 2.4)
	var b := DSP.buffer(d)
	for detune: float in [1.0, 1.06, 0.95]:
		var motor := DSP.osc(d, func(u: float) -> float: return DSP.sweep(100.0, 640.0, u) * detune, &"saw")
		DSP.filter(motor, &"lowpass", 2600.0)
		DSP.drive(motor, 2.0)
		DSP.mix(b, motor, 0.0, 0.28)
	var whine := DSP.osc(d, func(u: float) -> float: return DSP.sweep(1100.0, 2700.0, u * u), &"sine")
	DSP.adsr(whine, 0.25, 0.05, 0.9, 0.02)
	DSP.mix(b, whine, 0.0, 0.22)
	var click := DSP.metal_hit(0.02, 2900.0, 0.004, rng)
	var t: float = 0.0
	while t < d - 0.02:
		DSP.mix(b, click, t, 0.55)
		t += 1.0 / lerpf(8.0, 60.0, pow(t / d, 1.4))
	var n: int = b.size()
	for i: int in n:
		b[i] *= 0.45 + 0.55 * float(i) / n
	DSP.shape(b, 0.02, 0.02)
	DSP.crush(b, 8, 17000.0)
	return b


## A vertical pass's fire: rounds cracking 22 a second over the rotors, rounds chewing the stone (low
## thuds), dying off as the rake goes by.
func _rake() -> PackedFloat32Array:
	var rng := _rng(1705)
	var d: float = 0.95
	var b := DSP.buffer(d + 0.2)
	var t: float = 0.0
	while t < d:
		DSP.mix(b, _round(rng), t, 0.9)
		if rng.randf() < 0.5:
			var thud := DSP.noise(0.06, rng)
			DSP.filter(thud, &"lowpass", 500.0)
			DSP.envelope(thud, 0.001, 0.02)
			DSP.mix(b, thud, t + 0.01, 0.7)
		t += 1.0 / 22.0
	DSP.mix(b, _rotor(d + 0.2, 23.0, 21.0, 900.0, 800.0, 0.7, 0.3, rng), 0.0, 0.35)
	DSP.shape(b, 0.005, 0.2)
	DSP.drive(b, 2.4)
	DSP.crush(b, 8, 15000.0)
	return b


## A horizontal pass's fire: rounds swept through a band-pass from low to high as the fire crosses the
## track, a rush with it, then the line burning (a hiss dying away).
func _sweep() -> PackedFloat32Array:
	var rng := _rng(1706)
	var sweep: float = clampf(tuning_value("sweep_seconds", 0.55), 0.3, 1.2)
	var d: float = sweep + 0.75
	var b := DSP.buffer(d)
	var fire := DSP.buffer(sweep + 0.05)
	var t: float = 0.0
	while t < sweep:
		DSP.mix(fire, _round(rng), t, 0.9)
		t += 1.0 / 24.0
	DSP.filter_sweep(fire, &"bandpass", 900.0, 3200.0, 0.7)
	DSP.mix(b, fire, 0.0, 1.6)
	DSP.mix(b, _whoosh(sweep + 0.1, 400.0, 2400.0, 1.0, rng), 0.0, 0.5)
	var burn := DSP.noise(0.75, rng)
	DSP.filter(burn, &"highpass", 3000.0)
	DSP.envelope(burn, 0.03, 0.25, 0.05)
	DSP.mix(b, burn, sweep - 0.05, 0.4)
	DSP.drive(b, 2.0)
	DSP.crush(b, 8, 16000.0)
	return b


## The fire meeting the buttress: ricochets (high pings falling in pitch) off its stone and gold, a crackle.
func _spark() -> PackedFloat32Array:
	var rng := _rng(1707)
	var d: float = 0.7
	var b := DSP.buffer(d)
	for k: int in 5:
		var hz: float = rng.randf_range(2200.0, 3600.0)
		var ping := DSP.osc(0.22, func(u: float) -> float: return DSP.sweep(hz, hz * 0.55, u), &"sine")
		DSP.envelope(ping, 0.001, 0.06)
		DSP.mix(b, ping, k * 0.09 + rng.randf_range(0.0, 0.04), 0.45)
		DSP.mix(b, DSP.metal_hit(0.08, rng.randf_range(900.0, 1500.0), 0.02, rng), k * 0.09, 0.3)
	DSP.mix(b, _crackle(d, 30, 0.3, 2400.0, rng), 0.0, 0.5)
	DSP.crush(b, 9, 20000.0)
	return b


## A Flying Buttress rising: stone grinding and scraping up (noise juddering at 20-30 Hz), a rumble, and a
## solid thud as it locks in place.
func _buttress() -> PackedFloat32Array:
	var rng := _rng(1708)
	var rise: float = clampf(tuning_value("buttress_rise_seconds", 1.4), 0.5, 3.0)
	var d: float = rise + 0.5
	var b := DSP.buffer(d)
	var grind := DSP.noise(rise, rng)
	DSP.filter(grind, &"bandpass", 950.0, 1.0)
	var judder: float = 0.0
	for i: int in grind.size():
		var u: float = float(i) / grind.size()
		judder += lerpf(20.0, 30.0, u) / RATE
		grind[i] *= (0.55 + 0.45 * sin(TAU * judder)) * (0.4 + 0.6 * u)
	DSP.mix(b, grind, 0.0, 1.0)
	var scrape := DSP.noise(rise, rng)
	DSP.filter(scrape, &"bandpass", 2200.0, 1.6)
	DSP.shape(scrape, 0.1, 0.2)
	DSP.mix(b, scrape, 0.0, 0.6)
	var rumble := DSP.noise(rise, rng)
	DSP.filter(rumble, &"lowpass", 150.0)
	DSP.shape(rumble, rise * 0.5, 0.1)
	DSP.mix(b, rumble, 0.0, 0.9)
	DSP.mix(b, _boom(0.5, 140.0, 48.0, 0.15, rng), rise, 0.9)
	DSP.drive(b, 1.5)
	DSP.crush(b, 9, 18000.0)
	return b


## A Flying Buttress crumbling: a sharp crack, a deep thud, rubble pattering down and dying away.
func _crumble() -> PackedFloat32Array:
	var rng := _rng(1709)
	var d: float = clampf(tuning_value("crumble_seconds", 1.6), 0.8, 3.0) + 0.3
	var b := DSP.buffer(d)
	var crack := DSP.noise(0.12, rng)
	DSP.filter(crack, &"highpass", 1500.0)
	DSP.envelope(crack, 0.0005, 0.03)
	DSP.mix(b, crack, 0.0, 1.0)
	DSP.mix(b, _boom(0.9, 120.0, 40.0, 0.3, rng), 0.03, 0.9)
	for k: int in 26:
		var at: float = 0.08 + pow(rng.randf(), 1.6) * (d - 0.4)
		var bit := DSP.noise(0.05, rng)
		DSP.filter(bit, &"bandpass", rng.randf_range(250.0, 900.0), 1.0)
		DSP.envelope(bit, 0.001, 0.015)
		DSP.mix(b, bit, at, 0.6 * (1.0 - at / d))
	var dust := DSP.noise(d, rng)
	DSP.filter(dust, &"lowpass", 600.0)
	DSP.envelope(dust, 0.02, 0.5, 0.1)
	DSP.mix(b, dust, 0.0, 0.5)
	DSP.drive(b, 1.6)
	DSP.crush(b, 9, 18000.0)
	return b


## A drone hurled up by a pad: a spring's twang, its rotor screaming up in pitch as it's flung away.
func _hurl() -> PackedFloat32Array:
	var rng := _rng(1710)
	var d: float = 0.9
	var b := DSP.buffer(d)
	var twang := DSP.fm(0.35, func(u: float) -> float: return DSP.sweep(180.0, 420.0, u), 2.0,
		func(u: float) -> float: return 3.0 * exp(-u * 3.0))
	DSP.envelope(twang, 0.001, 0.12)
	DSP.mix(b, twang, 0.0, 0.6)
	DSP.mix(b, _rotor(d, 24.0, 40.0, 900.0, 2400.0, 1.0, 0.2, rng), 0.02, 0.6)
	DSP.mix(b, _whoosh(0.6, 500.0, 2600.0, 1.2, rng), 0.0, 0.5)
	DSP.crush(b, 9, 20000.0)
	return b


## The squadron going back into the cape: the rotors receding (slowing, darker, softer) under a rush of cloth.
func _return() -> PackedFloat32Array:
	var rng := _rng(1711)
	var d: float = 1.6
	var b := DSP.buffer(d)
	for k: int in 3:
		DSP.mix(b, _rotor(d - k * 0.1, 23.0, 14.0, 1300.0, 450.0, 1.0, 0.0, rng), k * 0.08, 0.4)
	DSP.mix(b, _cloth(0.9, rng), d - 0.95, 0.8)
	DSP.crush(b, 9, 20000.0)
	return b
