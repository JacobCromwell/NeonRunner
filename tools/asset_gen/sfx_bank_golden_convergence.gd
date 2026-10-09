extends "res://tools/asset_gen/sfx_bank.gd"
## The Golden Convergence's sounds (GDD §10, task E5d-a), in the game's 16-bit style. Its warnings sound the
## same every time (no pitch variation in data/audio/sfx_library.tres) and last as long as their warnings,
## read from the fight's tuning (data/bosses/golden_boss_tuning.tres: regenerate them when those change).
## Like every sound effect, each is under MAX_SECONDS (test_units).
##   gc_rise      the entrance: something enormous rising at the far end of the court, a deep rumble and a
##                mechanical groan swelling as it rises, tapering as the chime comes in, the cape unfurling in
##                a heavy rush of cloth from unfurl_at
##   gc_chime     the cult's three-note chime (the Resonator's G5, C6, E6, §9.10) rung huge and slow: each
##                note doubled an octave and two below, further apart than the Resonator's, ringing on under
##                the next, echoing round the court
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
## E5d-b (the Fist Slam and the Missile Barrage):
##   gc_grind     the fist's warning (as long as slam_track_seconds + slam_lock_seconds): a deep grinding
##                wind-up, the arm's segments ratcheting and a groan climbing, a heavy clank as it locks
##   gc_slam      the fist landing: a huge thud through the causeway, a crack
##   gc_break     the floor breaking under it: stone splitting and rubble falling into the hole
##   gc_topple    the tower toppling (as long as tower_fall_seconds and its crash): a deep groaning creak
##                swelling, then the crash and a rumble
##   gc_hatch     the barrage's warning begins: the shoulder pipes' hatches unlatching, swinging open, a hiss
##   gc_launch    the missiles launching one after another with a roar
##   gc_whistle   their dive (as long as barrage_dive_seconds): a chorus of rising whistles
##   gc_fire      the fire landing: a blast of flame rushing over the floor, burning for fire_seconds
## E5d-c (the Refill Ship):
##   gc_ship      the ship flying in (as long as ship_in_seconds): its engines droning in from behind and above,
##                a deep hum, a turbine whine, the air rushing as it comes over
##   gc_feed      the feed line shooting out to the shoulder's pipes (feed_reach_seconds): a pneumatic pop, the
##                hose hissing out, a heavy coupling clank as it docks, the pipes taking pressure
##   gc_ride      missiles riding up the line: a clatter of rollers on the hose climbing away, a hiss
##   gc_ripple    the drones crashing into the racks and the missiles going up one after another along them
##                (ripple_seconds)
##   gc_crash     the ship exploding beside the causeway: a huge blast, its hull tearing, debris raining down
##   gc_blast     the blast racing up the feed line (blast_seconds): a roar climbing in pitch, crackling
##   gc_pipes     a shoulder's pipes blowing out: a boom, metal tearing, steam venting, a clang
##   gc_leave     a missed pad: the ship's engines spooling up and receding as it flies off (leave_seconds)

const TUNING_PATH: String = "res://data/bosses/golden_boss_tuning.tres"
## The Resonator's chime (sfx_bank_resonator.gd): its notes, struck the same way.
const ResonatorBank = preload("res://tools/asset_gen/sfx_bank_resonator.gd")
## The chime's notes rung slow (the Resonator's are 0.42 s apart): seconds from the first.
const CHIME_AT: Array[float] = [0.0, 0.7, 1.4]
## A sound effect's longest (test_units: every sound is under 2.5 s).
const MAX_SECONDS: float = 2.45


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
		# E5d-b.
		"gc_grind": _grind,
		"gc_slam": _slam,
		"gc_break": _break,
		"gc_topple": _topple,
		"gc_hatch": _hatch,
		"gc_launch": _launch,
		"gc_whistle": _whistle,
		"gc_fire": _fire,
		# E5d-c.
		"gc_ship": _ship,
		"gc_feed": _feed,
		"gc_ride": _ride,
		"gc_ripple": _ripple,
		"gc_crash": _crash,
		"gc_blast": _blast,
		"gc_pipes": _pipes,
		"gc_leave": _leave,
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


## Fades the last `seconds` of `b` out smoothly (a long sound brought in under MAX_SECONDS).
func _fade_out(b: PackedFloat32Array, seconds: float) -> void:
	var n: int = b.size()
	var span: int = mini(int(seconds * RATE), n)
	for i: int in span:
		var k: float = float(i) / float(maxi(span, 1))
		b[n - 1 - i] *= k * k * (3.0 - 2.0 * k)


## One gatling round: a sharp crack.
func _round(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var shot := DSP.noise(0.05, rng)
	DSP.filter(shot, &"bandpass", 2300.0, 0.9)
	DSP.envelope(shot, 0.0005, 0.012)
	DSP.mix(shot, DSP.kick(0.04, 650.0, 260.0, rng), 0.0, 0.3)
	return shot


## The entrance: a sub rumble and a mechanical groan swelling as it rises, a deep hum climbing, and the cape
## unfurling (a heavy rush of cloth from unfurl_at); it tapers off as the chime comes in (MAX_SECONDS: the
## rise itself goes on a little longer, under the chime).
func _rise() -> PackedFloat32Array:
	var rng := _rng(1701)
	var length: float = MAX_SECONDS
	var d: float = minf(clampf(tuning_value("rise_seconds", 3.2), 1.5, 5.0), length - 0.5)
	var unfurl_at: float = clampf(tuning_value("unfurl_at", 1.0), 0.0, length - 0.8)
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
	DSP.mix(b, _cloth(length - unfurl_at, rng), unfurl_at, 0.9)
	_fade_out(b, 0.5)
	DSP.drive(b, 1.6)
	DSP.crush(b, 10, 20000.0)
	return b


## The cult's chime, huge and slow: the Resonator's mallet-and-glass notes (G5, C6, E6) on CHIME_AT, each
## doubled an octave and two octaves down so it fills the court, ringing on under the next, with a hall's
## echo, the last note fading out by MAX_SECONDS.
func _chime() -> PackedFloat32Array:
	var rng := _rng(1702)
	var resonator: RefCounted = ResonatorBank.new()
	var hz: Array[float] = ResonatorBank.CHIME_HZ
	var length: float = MAX_SECONDS
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
	_fade_out(b, 0.6)
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


# --- E5d-b: the Fist Slam and the Missile Barrage -------------------------------------------------------

## The fist's warning, as long as it lasts (slam_track_seconds + slam_lock_seconds): a deep grinding wind-up,
## stone-heavy noise juddering faster and faster, the arm's segments ratcheting out (metal clicks speeding up), a
## groan climbing under it, and at the lock (slam_track_seconds in) a heavy clank; the grind tightens on to the
## end.
func _grind() -> PackedFloat32Array:
	var rng := _rng(1712)
	var track: float = clampf(tuning_value("slam_track_seconds", 0.8), 0.3, 1.5)
	var d: float = minf(track + clampf(tuning_value("slam_lock_seconds", 1.0), 0.6, 1.6), MAX_SECONDS)
	var b := DSP.buffer(d)
	var grind := DSP.noise(d, rng)
	DSP.filter(grind, &"lowpass", 260.0)
	DSP.filter(grind, &"lowpass", 260.0)
	var judder: float = 0.0
	for i: int in grind.size():
		var u: float = float(i) / grind.size()
		judder += lerpf(14.0, 34.0, u) / RATE
		grind[i] *= (0.5 + 0.5 * sin(TAU * judder)) * (0.5 + 0.5 * u)
	DSP.mix(b, grind, 0.0, 2.4)
	var scrape := DSP.noise(d, rng)
	DSP.filter(scrape, &"bandpass", 700.0, 1.4)
	DSP.shape(scrape, 0.15, 0.1)
	DSP.mix(b, scrape, 0.0, 0.55)
	var groan := DSP.fm(d, func(u: float) -> float: return DSP.sweep(46.0, 74.0, u), 1.5,
		func(u: float) -> float: return 2.0 + 2.0 * u)
	DSP.filter(groan, &"bandpass", 300.0, 0.8)
	DSP.shape(groan, 0.2, 0.05)
	DSP.mix(b, groan, 0.0, 0.5)
	# The segments ratcheting out until the lock.
	var at: float = 0.0
	while at < track - 0.03:
		DSP.mix(b, DSP.metal_hit(0.04, 1500.0, 0.008, rng), at, 0.45)
		at += 1.0 / lerpf(9.0, 26.0, at / track)
	# The lock: a heavy clank, a thud under it.
	DSP.mix(b, DSP.metal_hit(0.35, 520.0, 0.12, rng), track, 1.1)
	DSP.mix(b, _boom(0.4, 150.0, 60.0, 0.12, rng), track, 0.8)
	DSP.drive(b, 1.6)
	DSP.crush(b, 9, 18000.0)
	return b


## The fist landing: a huge thud through the causeway, the golden fist's clank and the stone's thump (heard on a
## phone's speaker too), a sharp crack, a sub thump.
func _slam() -> PackedFloat32Array:
	var rng := _rng(1713)
	var d: float = 1.3
	var b := _boom(d, 115.0, 30.0, 0.42, rng)
	var crack := DSP.noise(0.2, rng)
	DSP.filter(crack, &"bandpass", 1300.0, 0.7)
	DSP.envelope(crack, 0.0005, 0.05)
	DSP.mix(b, crack, 0.0, 2.6)
	var thump := DSP.noise(0.5, rng)
	DSP.filter(thump, &"bandpass", 380.0, 1.2)
	DSP.envelope(thump, 0.001, 0.09, 0.05)
	DSP.mix(b, thump, 0.0, 3.0)
	DSP.mix(b, DSP.metal_hit(0.6, 310.0, 0.14, rng), 0.0, 1.2)
	var body := DSP.noise(d, rng)
	DSP.filter_sweep(body, &"lowpass", 3000.0, 180.0, 0.7)
	DSP.envelope(body, 0.002, 0.16, 0.05)
	DSP.mix(b, body, 0.0, 1.1)
	DSP.drive(b, 1.8)
	DSP.crush(b, 9, 17000.0)
	return b


## The floor breaking under it: stone splitting (sharp cracks), slabs grinding apart, rubble pattering down
## into the hole, a low rumble dying away.
func _break() -> PackedFloat32Array:
	var rng := _rng(1714)
	var d: float = 1.5
	var b := DSP.buffer(d)
	for k: int in 4:
		var crack := DSP.noise(0.09, rng)
		DSP.filter(crack, &"highpass", 1700.0 + 300.0 * k)
		DSP.envelope(crack, 0.0005, 0.025)
		DSP.mix(b, crack, 0.02 + k * 0.07 + rng.randf_range(0.0, 0.03), 0.9 - k * 0.15)
	var slab := DSP.noise(0.6, rng)
	DSP.filter(slab, &"bandpass", 420.0, 1.1)
	DSP.envelope(slab, 0.02, 0.2, 0.05)
	DSP.mix(b, slab, 0.05, 0.9)
	for k: int in 30:
		var at: float = 0.12 + pow(rng.randf(), 1.5) * (d - 0.3)
		var bit := DSP.noise(0.05, rng)
		DSP.filter(bit, &"bandpass", rng.randf_range(300.0, 1100.0), 1.0)
		DSP.envelope(bit, 0.001, 0.014)
		DSP.mix(b, bit, at, 0.55 * (1.0 - at / d))
	var rumble := DSP.noise(d, rng)
	DSP.filter(rumble, &"lowpass", 120.0)
	DSP.envelope(rumble, 0.03, 0.45, 0.1)
	DSP.mix(b, rumble, 0.0, 1.4)
	DSP.drive(b, 1.5)
	DSP.crush(b, 9, 18000.0)
	return b


## The tower toppling: a deep groaning creak and a rumble swelling as it leans and falls (tower_fall_seconds),
## then its crash beside the causeway (a boom, a blast of rubble, debris) and a rumble rolling away by
## MAX_SECONDS.
func _topple() -> PackedFloat32Array:
	var rng := _rng(1715)
	var length: float = MAX_SECONDS
	var fall: float = clampf(tuning_value("tower_fall_seconds", 1.5), 0.6, length - 0.7)
	var b := DSP.buffer(length)
	var creak := DSP.osc(fall, func(u: float) -> float: return DSP.sweep(62.0, 110.0, u) * (1.0 + 0.05 * sin(u * 37.0)), &"saw")
	DSP.filter(creak, &"bandpass", 520.0, 2.0)
	DSP.shape(creak, fall * 0.5, 0.08)
	DSP.mix(b, creak, 0.0, 0.9)
	var rumble := DSP.noise(fall, rng)
	DSP.filter(rumble, &"lowpass", 150.0)
	DSP.filter(rumble, &"lowpass", 150.0)
	for i: int in rumble.size():
		var u: float = float(i) / rumble.size()
		rumble[i] *= u * u
	DSP.mix(b, rumble, 0.0, 3.0)
	DSP.mix(b, _whoosh(fall * 0.7, 200.0, 900.0, 0.8, rng), fall * 0.3, 0.6)
	DSP.mix(b, _explosion(length - fall, 1.2, rng), fall, 1.2)
	_fade_out(b, 0.35)
	DSP.crush(b, 9, 18000.0)
	return b


## The barrage's warning begins: the hatches over the shoulder pipes unlatching (two clanks), a hydraulic hiss as
## they swing open, a heavy thunk as they stop.
func _hatch() -> PackedFloat32Array:
	var rng := _rng(1716)
	var open: float = clampf(tuning_value("barrage_hatch_seconds", 0.5), 0.2, 1.2)
	var d: float = open + 0.35
	var b := DSP.buffer(d)
	DSP.mix(b, DSP.metal_hit(0.12, 1700.0, 0.03, rng), 0.0, 0.9)
	DSP.mix(b, DSP.metal_hit(0.12, 1450.0, 0.03, rng), 0.07, 0.8)
	var hiss := DSP.noise(open, rng)
	DSP.filter(hiss, &"highpass", 2600.0)
	DSP.filter_sweep(hiss, &"bandpass", 2400.0, 5200.0, 0.8)
	DSP.shape(hiss, 0.04, open * 0.4)
	DSP.mix(b, hiss, 0.06, 0.75)
	DSP.mix(b, _boom(0.35, 170.0, 70.0, 0.08, rng), open, 0.9)
	DSP.mix(b, DSP.metal_hit(0.25, 640.0, 0.08, rng), open, 0.7)
	DSP.crush(b, 9, 19000.0)
	return b


## The missiles launching one after another over barrage_salvo_seconds: each a rocket's ignition (a pop and a
## rising whoosh), over a roar that swells and climbs away.
func _launch() -> PackedFloat32Array:
	var rng := _rng(1717)
	var salvo: float = clampf(tuning_value("barrage_salvo_seconds", 0.5), 0.1, 1.2)
	var d: float = salvo + 0.9
	var b := DSP.buffer(d)
	var roar := DSP.noise(d, rng)
	DSP.filter_sweep(roar, &"lowpass", 500.0, 2200.0, 0.8)
	DSP.shape(roar, 0.08, 0.5)
	DSP.mix(b, roar, 0.0, 1.6)
	for k: int in 8:
		var at: float = salvo * float(k) / 8.0 + rng.randf_range(0.0, 0.02)
		DSP.mix(b, DSP.kick(0.08, 300.0, 110.0, rng), at, 0.45)
		DSP.mix(b, _whoosh(0.5, 300.0, 2600.0, 1.4, rng), at, 0.55)
	DSP.drive(b, 2.0)
	DSP.crush(b, 9, 18000.0)
	return b


## Their dive, as long as barrage_dive_seconds: a chorus of whistles rising as they come down, louder to the
## end.
func _whistle() -> PackedFloat32Array:
	var rng := _rng(1718)
	var d: float = clampf(tuning_value("barrage_dive_seconds", 1.0), 0.4, 2.0)
	var b := DSP.buffer(d)
	for detune: float in [1.0, 1.07, 0.93, 1.15]:
		var lag: float = rng.randf_range(0.0, 0.08)
		var w := DSP.osc(d - lag, func(u: float) -> float: return DSP.sweep(620.0, 1500.0, u) * detune * (1.0 + 0.012 * sin(u * 70.0)))
		DSP.mix(b, w, lag, 0.25)
	var air := DSP.noise(d, rng)
	DSP.filter_sweep(air, &"bandpass", 900.0, 2600.0, 1.6)
	DSP.mix(b, air, 0.0, 0.3)
	var n: int = b.size()
	for i: int in n:
		var u: float = float(i) / n
		b[i] *= 0.35 + 0.65 * u * u
	DSP.shape(b, 0.03, 0.02)
	DSP.crush(b, 10, 20000.0)
	return b


## The fire landing: a blast of flame rushing over the floor (a boom and a whoosh), then the fire roaring for
## fire_seconds, crackling, dying away.
func _fire() -> PackedFloat32Array:
	var rng := _rng(1719)
	var burn: float = clampf(tuning_value("fire_seconds", 1.5), 0.6, 2.0)
	var d: float = minf(burn + 0.4, MAX_SECONDS)
	var b := DSP.buffer(d)
	DSP.mix(b, _boom(0.6, 130.0, 45.0, 0.15, rng), 0.0, 0.9)
	DSP.mix(b, _whoosh(0.45, 300.0, 3000.0, 0.9, rng), 0.0, 1.0)
	var roar := DSP.noise(d, rng)
	DSP.filter(roar, &"lowpass", 900.0)
	var n: int = roar.size()
	for i: int in n:
		var t: float = float(i) / RATE
		var flutter: float = 0.7 + 0.3 * sin(TAU * 9.0 * t + 2.0 * sin(TAU * 2.3 * t))
		roar[i] *= flutter * (1.0 if t < burn else maxf(0.0, 1.0 - (t - burn) / 0.4))
	DSP.mix(b, roar, 0.0, 1.5)
	DSP.mix(b, _crackle(d, 60, burn, 2600.0, rng), 0.0, 0.8)
	_fade_out(b, 0.3)
	DSP.drive(b, 1.6)
	DSP.crush(b, 9, 18000.0)
	return b


# --- E5d-c: the Refill Ship ---------------------------------------------------------------------------------

## The ship's engines: two deep detuned saws (a heavy hum) and a turbine's whine at `whine_hz` (from, to), under
## a low rush, `level` over the sound (from, to). The ship's arrival and its leaving share it.
func _engines(seconds: float, hum_from: float, hum_to: float, whine_from: float, whine_to: float, level_from: float,
		level_to: float, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := DSP.buffer(seconds)
	for detune: float in [1.0, 1.013]:
		var hum := DSP.osc(seconds, func(u: float) -> float: return DSP.sweep(hum_from, hum_to, u) * detune, &"saw")
		DSP.filter(hum, &"lowpass", 380.0)
		DSP.mix(b, hum, 0.0, 0.45)
	var whine := DSP.osc(seconds, func(u: float) -> float: return DSP.sweep(whine_from, whine_to, u) * (1.0 + 0.006 * sin(u * 90.0)))
	DSP.mix(b, whine, 0.0, 0.12)
	var rush := DSP.noise(seconds, rng)
	DSP.filter(rush, &"bandpass", 520.0, 0.6)
	DSP.mix(b, rush, 0.0, 0.7)
	var n: int = b.size()
	for i: int in n:
		b[i] *= lerpf(level_from, level_to, float(i) / n)
	return b


## The ship flying in, as long as ship_in_seconds: its engines droning in from behind and above, swelling (a deep
## hum climbing a little, the pale engines' turbine whine), the air rushing past as it comes over, settling
## into a steady drone as it takes its station.
func _ship() -> PackedFloat32Array:
	var rng := _rng(1720)
	var d: float = minf(clampf(tuning_value("ship_in_seconds", 2.4), 0.8, 3.0) + 0.2, MAX_SECONDS)
	var b := _engines(d, 38.0, 46.0, 780.0, 1040.0, 0.25, 1.0, rng)
	var over := _whoosh(d * 0.7, 300.0, 1600.0, 0.9, rng)
	DSP.mix(b, over, d * 0.2, 1.1)
	var rumble := DSP.noise(d, rng)
	DSP.filter(rumble, &"lowpass", 110.0)
	DSP.filter(rumble, &"lowpass", 110.0)
	DSP.shape(rumble, d * 0.6, 0.3)
	DSP.mix(b, rumble, 0.0, 2.0)
	DSP.shape(b, 0.4, 0.35)
	DSP.drive(b, 1.5)
	DSP.crush(b, 10, 20000.0)
	return b


## The feed line shooting out to the shoulder's pipes (feed_reach_seconds): a pneumatic pop, the hose hissing
## out (a rising rush and its bands rattling), a heavy coupling clank as it docks, then the pipes taking the
## pressure (a hiss dying down).
func _feed() -> PackedFloat32Array:
	var rng := _rng(1721)
	var reach: float = clampf(tuning_value("feed_reach_seconds", 0.5), 0.15, 1.2)
	var d: float = reach + 0.6
	var b := DSP.buffer(d)
	DSP.mix(b, DSP.kick(0.12, 260.0, 90.0, rng), 0.0, 0.8)
	DSP.mix(b, _whoosh(reach + 0.05, 400.0, 2800.0, 1.1, rng), 0.0, 1.0)
	var at: float = 0.02
	while at < reach - 0.02:
		DSP.mix(b, DSP.metal_hit(0.03, 2100.0, 0.006, rng), at, 0.35)
		at += 1.0 / lerpf(18.0, 34.0, at / reach)
	DSP.mix(b, DSP.metal_hit(0.4, 560.0, 0.11, rng), reach, 1.1)
	DSP.mix(b, _boom(0.3, 180.0, 70.0, 0.07, rng), reach, 0.7)
	var hiss := DSP.noise(d - reach, rng)
	DSP.filter(hiss, &"highpass", 2400.0)
	DSP.envelope(hiss, 0.01, 0.18, 0.05)
	DSP.mix(b, hiss, reach + 0.02, 0.5)
	DSP.crush(b, 9, 19000.0)
	return b


## Missiles riding up the line: a clatter of rollers on the hose (clicks speeding up) climbing away, a hiss with
## them.
func _ride() -> PackedFloat32Array:
	var rng := _rng(1722)
	var d: float = 1.1
	var b := DSP.buffer(d)
	var at: float = 0.0
	while at < d - 0.05:
		var u: float = at / d
		DSP.mix(b, DSP.metal_hit(0.035, lerpf(1300.0, 2300.0, u), 0.007, rng), at, 0.5 * (1.0 - 0.7 * u))
		at += 1.0 / lerpf(14.0, 30.0, u)
	var rush := _whoosh(d, 700.0, 2600.0, 1.3, rng)
	DSP.mix(b, rush, 0.0, 0.45)
	DSP.shape(b, 0.03, 0.25)
	DSP.crush(b, 9, 19000.0)
	return b


## The drones crashing into the racks (metal smashing), then the missiles going up one after another along them
## over ripple_seconds (each a sharp blast, the string climbing), crackling, a rumble under it all.
func _ripple() -> PackedFloat32Array:
	var rng := _rng(1723)
	var span: float = clampf(tuning_value("ripple_seconds", 0.8), 0.2, 1.5)
	var d: float = minf(span + 0.75, MAX_SECONDS)
	var b := DSP.buffer(d)
	DSP.mix(b, DSP.metal_hit(0.3, 420.0, 0.09, rng), 0.0, 1.0)
	DSP.mix(b, DSP.metal_hit(0.25, 690.0, 0.07, rng), 0.03, 0.8)
	var count: int = 9
	for k: int in count:
		var at: float = 0.06 + span * float(k) / float(count) + rng.randf_range(0.0, 0.02)
		var pop := _explosion(0.45, 0.45, rng)
		DSP.mix(b, pop, at, 0.45 + 0.03 * k)
	var rumble := DSP.noise(d, rng)
	DSP.filter(rumble, &"lowpass", 130.0)
	DSP.shape(rumble, span * 0.5, 0.4)
	DSP.mix(b, rumble, 0.0, 1.8)
	_fade_out(b, 0.25)
	DSP.drive(b, 1.4)
	DSP.crush(b, 9, 18000.0)
	return b


## The ship exploding beside the causeway: a huge blast, a second on its heels, its hull tearing (a groaning metal
## screech), debris raining down, a rumble rolling away by MAX_SECONDS.
func _crash() -> PackedFloat32Array:
	var rng := _rng(1724)
	var d: float = MAX_SECONDS
	var b := _explosion(d, 1.5, rng)
	DSP.mix(b, _explosion(d - 0.18, 1.1, rng), 0.18, 0.7)
	var tear := DSP.osc(0.9, func(u: float) -> float: return DSP.sweep(240.0, 120.0, u) * (1.0 + 0.06 * sin(u * 53.0)), &"saw")
	DSP.filter(tear, &"bandpass", 900.0, 2.2)
	DSP.shape(tear, 0.05, 0.4)
	DSP.mix(b, tear, 0.12, 0.5)
	DSP.mix(b, _crackle(d - 0.4, 50, 0.9, 1800.0, rng), 0.35, 0.6)
	_fade_out(b, 0.4)
	DSP.drive(b, 1.3)
	DSP.crush(b, 9, 17000.0)
	return b


## The blast racing up the feed line over blast_seconds: a roar climbing in pitch as it goes (a rising rush,
## fire crackling), popping as it eats the hose.
func _blast() -> PackedFloat32Array:
	var rng := _rng(1725)
	var span: float = clampf(tuning_value("blast_seconds", 0.9), 0.3, 1.8)
	var d: float = span + 0.35
	var b := DSP.buffer(d)
	var roar := DSP.noise(d, rng)
	DSP.filter_sweep(roar, &"bandpass", 260.0, 2200.0, 0.8)
	DSP.shape(roar, 0.05, 0.3)
	DSP.mix(b, roar, 0.0, 1.8)
	var low := DSP.noise(d, rng)
	DSP.filter_sweep(low, &"lowpass", 300.0, 900.0, 0.7)
	DSP.shape(low, 0.03, 0.3)
	DSP.mix(b, low, 0.0, 1.0)
	var at: float = 0.0
	while at < span:
		DSP.mix(b, DSP.kick(0.08, 240.0 + 300.0 * at / span, 90.0, rng), at, 0.4)
		at += 0.09
	DSP.mix(b, _crackle(d, 50, span, 2600.0, rng), 0.0, 0.7)
	DSP.drive(b, 1.8)
	DSP.crush(b, 9, 18000.0)
	return b


## A shoulder's pipes blowing out: a boom, the metal tearing open (a screech falling), steam venting in a hiss that
## dies down, a heavy clang as a hatch is torn loose.
func _pipes() -> PackedFloat32Array:
	var rng := _rng(1726)
	var d: float = 1.6
	var b := _explosion(d, 0.9, rng)
	var screech := DSP.osc(0.6, func(u: float) -> float: return DSP.sweep(1500.0, 620.0, u) * (1.0 + 0.04 * sin(u * 70.0)), &"saw")
	DSP.filter(screech, &"bandpass", 1300.0, 3.0)
	DSP.shape(screech, 0.03, 0.3)
	DSP.mix(b, screech, 0.04, 0.5)
	var steam := DSP.noise(d - 0.1, rng)
	DSP.filter(steam, &"highpass", 2800.0)
	DSP.envelope(steam, 0.02, 0.5, 0.1)
	DSP.mix(b, steam, 0.1, 0.8)
	DSP.mix(b, DSP.metal_hit(0.5, 380.0, 0.15, rng), 0.22, 1.0)
	_fade_out(b, 0.25)
	DSP.crush(b, 9, 18000.0)
	return b


## A missed pad: the ship done refilling, its engines spooling up and receding as it flies off ahead and away
## (leave_seconds): the whine climbing, the hum falling away, softer to the end.
func _leave() -> PackedFloat32Array:
	var rng := _rng(1727)
	var d: float = minf(clampf(tuning_value("leave_seconds", 2.2), 0.8, 3.0), MAX_SECONDS)
	var b := _engines(d, 44.0, 36.0, 1000.0, 1500.0, 1.0, 0.0, rng)
	DSP.mix(b, _whoosh(d * 0.6, 1400.0, 400.0, 0.9, rng), 0.1, 0.9)
	DSP.shape(b, 0.15, 0.4)
	DSP.drive(b, 1.4)
	DSP.crush(b, 10, 20000.0)
	return b
