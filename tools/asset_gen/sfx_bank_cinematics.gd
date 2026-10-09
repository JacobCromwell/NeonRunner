extends "res://tools/asset_gen/sfx_bank.gd"
## The cinematics' own sounds, where the game's don't fit (the owner, October 9, 2026: new sounds are fine where the
## existing ones don't cover a moment; only new music is off). In the game's crunchy 16-bit style. None of them is a
## hazard's warning, and no warning is reused for a cinematic's moment, so the warnings keep their meaning. Like every
## sound effect, each is under MAX_SECONDS. The Dead Zone's intro (DeadZoneIntro):
##   crater_smoulder  the smoking crater settling: a low rumble rising and falling, embers ticking and popping,
##                    a soft hiss of smoke, pebbles trickling down its sides
##   rubble_shift     a body shifting on rubble: grit scraping under it, a couple of chunks knocking
##   edge_grab        a gloved hand slapping down on a broken concrete edge, grit trickling off it into the hole
##   host_turn        a host lifting its head to look: a neck servo grinding and ratcheting under a burst of its
##                    screen's static
##   host_glitch      a host's corrupted screen up close: stuttering static, a low detuned hum sinking, the feed's
##                    rows jumping in digital clicks, and under it, faintly, a garbled voice (the Bad Dream inside)

const MAX_SECONDS: float = 2.45


func sounds() -> Dictionary:
	return {
		"crater_smoulder": _smoulder,
		"rubble_shift": _rubble_shift,
		"edge_grab": _edge_grab,
		"host_turn": _host_turn,
		"host_glitch": _host_glitch,
	}


## The smoking crater (2.4 s): a low rumble swelling in and dying back, embers ticking and popping, a soft hiss
## of smoke and a few trickles of pebbles down its sides.
func _smoulder() -> PackedFloat32Array:
	var rng := _rng(2101)
	var d: float = 2.4
	var b := DSP.buffer(d)
	var rumble := DSP.noise(d, rng)
	DSP.filter(rumble, &"lowpass", 95.0, 0.9)
	DSP.adsr(rumble, 0.7, 0.9, 0.55, 0.8)
	DSP.mix(b, rumble, 0.0, 2.4)
	var hiss := DSP.noise(d, rng)
	DSP.filter(hiss, &"bandpass", 4200.0, 0.6)
	DSP.adsr(hiss, 0.5, 1.0, 0.7, 0.7)
	DSP.mix(b, hiss, 0.0, 0.12)
	# Embers: small sharp ticks all through, a few bigger pops.
	DSP.mix(b, _crackle(d, 70, 6.0, 2600.0, rng), 0.0, 0.5)
	DSP.mix(b, _crackle(d, 8, 6.0, 900.0, rng), 0.0, 0.7)
	# Pebbles trickling: three short runs of ticks, each thinning out.
	for at: float in [0.35, 1.05, 1.6]:
		DSP.mix(b, _trickle(0.45, 12, rng), at, 0.6)
	DSP.shape(b, 0.25, 0.45)
	DSP.crush(b, 10, 20000.0)
	return b


## A body shifting on rubble (0.7 s): grit scraping under it, a couple of chunks knocking together.
func _rubble_shift() -> PackedFloat32Array:
	var rng := _rng(2102)
	var d: float = 0.7
	var b := DSP.buffer(d)
	var grit := DSP.noise(d, rng)
	DSP.filter_sweep(grit, &"bandpass", 1300.0, 700.0, 1.1)
	# Grainy: the scrape catches and slips.
	var n: int = grit.size()
	for i: int in n:
		var u: float = float(i) / n
		grit[i] *= (0.45 + 0.55 * absf(sin(u * 37.0 + 3.0 * sin(u * 11.0)))) * pow(sin(PI * u), 0.8)
	DSP.mix(b, grit, 0.0, 0.9)
	for at: float in [0.12, 0.38]:
		var knock := DSP.tom(0.12, rng.randf_range(230.0, 300.0), rng)
		DSP.mix(b, knock, at, 0.5)
	DSP.mix(b, _trickle(0.3, 6, rng), 0.4, 0.45)
	DSP.crush(b, 10, 20000.0)
	return b


## A gloved hand slapping down on a broken concrete edge (0.6 s), and grit trickling off it into the hole.
func _edge_grab() -> PackedFloat32Array:
	var rng := _rng(2103)
	var d: float = 0.6
	var b := DSP.buffer(d)
	var slap := DSP.noise(0.08, rng)
	DSP.filter(slap, &"bandpass", 1700.0, 0.9)
	DSP.envelope(slap, 0.0005, 0.018)
	DSP.mix(b, slap, 0.0, 1.3)
	var thump := DSP.kick(0.16, 150.0, 70.0, rng)
	DSP.mix(b, thump, 0.0, 0.45)
	var scuff := DSP.noise(0.12, rng)
	DSP.filter(scuff, &"bandpass", 900.0, 1.2)
	DSP.envelope(scuff, 0.01, 0.04)
	DSP.mix(b, scuff, 0.03, 0.5)
	DSP.mix(b, _trickle(0.45, 9, rng), 0.08, 0.5)
	DSP.crush(b, 10, 20000.0)
	return b


## A host lifting its head to look (1.0 s): its neck servo grinding up and ratcheting, under a burst of its screen's
## static that crackles and settles.
func _host_turn() -> PackedFloat32Array:
	var rng := _rng(2104)
	var d: float = 1.0
	var b := DSP.buffer(d)
	var servo := DSP.osc(d, func(u: float) -> float: return DSP.sweep(70.0, 125.0, u), &"square")
	DSP.filter(servo, &"lowpass", 900.0)
	# The ratchet: the grind catching in quick steps, slowing as the head comes round.
	var n: int = servo.size()
	var phase: float = 0.0
	for i: int in n:
		var u: float = float(i) / n
		phase += lerpf(26.0, 12.0, u) / RATE
		servo[i] *= (1.0 if fmod(phase, 1.0) < 0.6 else 0.3) * pow(sin(PI * minf(u * 1.15, 1.0)), 0.6)
	DSP.drive(servo, 1.8)
	DSP.mix(b, servo, 0.0, 0.5)
	var fizz := _stutter_static(0.7, 0.03, 0.08, rng)
	DSP.envelope(fizz, 0.01, 0.35, 0.1)
	DSP.mix(b, fizz, 0.05, 0.55)
	DSP.mix(b, _crackle(0.6, 14, 0.3, 3200.0, rng), 0.05, 0.6)
	DSP.shape(b, 0.01, 0.12)
	DSP.crush(b, 8, 16000.0)
	return b


## A host's corrupted screen up close (2.4 s): stuttering static, a low detuned hum sinking, the feed's rows jumping
## in short digital clicks, and under it, faintly, a garbled voice: the Bad Dream inside. It swells to the end.
func _host_glitch() -> PackedFloat32Array:
	var rng := _rng(2105)
	var d: float = 2.4
	var b := DSP.buffer(d)
	var hum := DSP.buffer(d)
	for base: float in [55.0, 57.6]:
		DSP.mix(hum, DSP.osc(d, func(u: float) -> float: return base * pow(2.0, -2.0 * u / 12.0), &"saw"), 0.0, 0.5)
	DSP.filter(hum, &"lowpass", 420.0)
	DSP.drive(hum, 1.6)
	DSP.mix(b, hum, 0.0, 0.55)
	DSP.mix(b, _stutter_static(d, 0.02, 0.07, rng), 0.0, 0.42)
	# The rows jumping: short square clicks at odd pitches.
	var at: float = 0.05
	while at < d - 0.05:
		var hz: float = rng.randf_range(900.0, 3200.0)
		var blip := DSP.osc(0.025, func(_u: float) -> float: return hz, &"square")
		DSP.envelope(blip, 0.0005, 0.008)
		DSP.mix(b, blip, at, 0.22)
		at += rng.randf_range(0.06, 0.22)
	# The voice under it: a breathy formant wobbling, chopped as the feed drops out.
	var voice := _voice(d, func(u: float) -> float: return DSP.sweep(150.0, 120.0, u), Vector2(400.0, 650.0),
		Vector2(1100.0, 900.0), 5.5, 1.5, rng)
	var n: int = voice.size()
	var i: int = 0
	while i < n:
		var span: int = int(rng.randf_range(0.04, 0.12) * RATE)
		var level: float = 1.0 if rng.randf() < 0.55 else 0.0
		for j: int in mini(span, n - i):
			voice[i + j] *= level
		i += span
	DSP.filter(voice, &"highpass", 200.0)
	DSP.mix(b, voice, 0.0, 0.3)
	# It swells to the end.
	for k: int in b.size():
		b[k] *= 0.5 + 0.5 * float(k) / b.size()
	DSP.shape(b, 0.02, 0.2)
	DSP.crush(b, 8, 16000.0)
	return b


## Pebbles trickling down (`seconds`): `count` short ticks, close together at first, thinning out.
func _trickle(seconds: float, count: int, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := DSP.buffer(seconds)
	var at: float = 0.0
	for k: int in count:
		var tick := DSP.noise(0.012, rng)
		DSP.filter(tick, &"bandpass", rng.randf_range(1800.0, 4200.0), 2.0)
		DSP.envelope(tick, 0.0003, 0.003)
		DSP.mix(b, tick, at, rng.randf_range(0.4, 1.0) * (1.0 - float(k) / count))
		at += rng.randf_range(0.01, 0.06) * (1.0 + 2.0 * float(k) / count)
		if at >= seconds - 0.015:
			break
	return b


## A screen's static, cut in and out in stutters `span_min`-`span_max` seconds long.
func _stutter_static(seconds: float, span_min: float, span_max: float, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := DSP.noise(seconds, rng)
	DSP.filter(b, &"highpass", 1200.0)
	DSP.crush(b, 4, 6000.0)
	var n: int = b.size()
	var i: int = 0
	while i < n:
		var span: int = int(rng.randf_range(span_min, span_max) * RATE)
		var level: float = 1.0 if rng.randf() < 0.6 else 0.15
		for j: int in mini(span, n - i):
			b[i + j] *= level
		i += span
	return b
