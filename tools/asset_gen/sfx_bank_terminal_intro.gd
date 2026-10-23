extends "res://tools/asset_gen/sfx_bank_cinematics.gd"
## The Terminal intro's own sounds (TerminalIntro): the Dead Zone wasteland outside the abandoned Grand Terminal Station, its dying
## sign, the runner wiping the route board, climbing the rubble and dropping into the station. In the same crunchy 16-bit style as
## the rest (its crackle and trickle helpers are the Dead Zone intro's, sfx_bank_cinematics.gd); none is a warning; like every sound
## effect, each is under 2.5 s. The ones that run on (wind, buzz, hum) fade in and out over 0.3 s so repeats overlap evenly.
##   waste_wind        the wasteland's wind: a low swell of air over rubble with a thin whistle and ash ticking
##   sign_buzz         the sign's dying lamps: a mains hum with its harmonics wavering, crackling now and then
##   sign_zap          a letter sparking: an electrical zap, a hard snap and a ragged "bzzzt" that gutters out, crackling (1 s)
##   grime_wipe        a bare hand wiping a grimy enamel board: a dry, gritty swish
##   rubble_scramble   climbing loose rubble on hands and feet: knocks and scrapes, stones slipping away behind
##   landing_thud      dropping onto the station's floor: a dull thump, grit skittering
##   station_hum       the dark station's low hum, power still running somewhere in it, a faint creak of metal

const WIND_SECONDS: float = 2.4
const FADE: float = 0.3


func sounds() -> Dictionary:
	return {
		"waste_wind": _wind,
		"sign_buzz": _buzz,
		"sign_zap": _zap,
		"grime_wipe": _wipe,
		"rubble_scramble": _scramble,
		"landing_thud": _thud,
		"station_hum": _hum,
	}


## The wind over the wasteland (2.4 s): low air in a slow swell, a thin whistle through the ruins, flecks of ash ticking.
func _wind() -> PackedFloat32Array:
	var rng := _rng(2201)
	var d: float = WIND_SECONDS
	var b := DSP.buffer(d)
	var air := DSP.noise(d, rng)
	DSP.filter_sweep(air, &"lowpass", 380.0, 640.0, 0.9)
	DSP.adsr(air, 1.0, 0.4, 0.8, 0.8)
	DSP.mix(b, air, 0.0, 1.5)
	var hiss := DSP.noise(d, rng)
	DSP.filter(hiss, &"bandpass", 2400.0, 0.7)
	DSP.adsr(hiss, 0.9, 0.5, 0.5, 0.8)
	DSP.mix(b, hiss, 0.0, 0.1)
	var whistle := DSP.osc(d, func(u: float) -> float: return 880.0 + 120.0 * sin(TAU * (0.8 * u + 0.3)), &"sine")
	DSP.filter(whistle, &"bandpass", 900.0, 3.0)
	DSP.adsr(whistle, 0.8, 0.4, 0.5, 0.9)
	DSP.mix(b, whistle, 0.0, 0.05)
	DSP.mix(b, _crackle(d, 24, 4.0, 3200.0, rng), 0.0, 0.14)
	DSP.shape(b, FADE, FADE)
	DSP.crush(b, 10, 18000.0)
	return b


## The sign's buzz (2.4 s): a mains hum (a low saw and its harmonics, drifting a touch), crackling, a stutter of dying lamps.
func _buzz() -> PackedFloat32Array:
	var rng := _rng(2202)
	var d: float = WIND_SECONDS
	var b := DSP.buffer(d)
	for h: Array in [[100.0, 0.5], [200.0, 0.32], [300.0, 0.2], [500.0, 0.08]]:
		var hz: float = h[0]
		var hum := DSP.osc(d, func(u: float) -> float: return hz * (1.0 + 0.004 * sin(TAU * 1.3 * u)), &"saw")
		DSP.filter(hum, &"lowpass", 1400.0)
		DSP.mix(b, hum, 0.0, float(h[1]) * 0.5)
	# The wavering of a failing ballast: the level dips now and then, never fast.
	var n: int = b.size()
	for i: int in n:
		var t: float = float(i) / RATE
		b[i] *= 0.8 + 0.2 * sin(TAU * 0.9 * t) * sin(TAU * 0.37 * t + 1.0)
	DSP.drive(b, 1.6)
	DSP.mix(b, _crackle(d, 20, 3.0, 4200.0, rng), 0.0, 0.3)
	DSP.mix(b, _stutter_static(d, 0.05, 0.2, rng), 0.0, 0.05)
	DSP.shape(b, FADE, FADE)
	DSP.crush(b, 9, 16000.0)
	return b


## A letter sparking (1.0 s): an electrical zap. A hard snap as the arc strikes with a thump behind it and a falling chirp, then a
## ragged "bzzzt": a mains buzz (100 Hz up, rich in harmonics, sagging in pitch) and a bright sizzle, both chopped by a flickering
## gate that gutters more and more as the arc dies, crackles thinning out and a faint ballast hum winding down under it.
func _zap() -> PackedFloat32Array:
	var rng := _rng(2203)
	var d: float = 1.0
	var b := DSP.buffer(d)
	# The strike: a bright burst of static, and the thump of the discharge under it.
	var snap := DSP.noise(0.12, rng)
	DSP.filter(snap, &"highpass", 1600.0)
	DSP.envelope(snap, 0.0003, 0.02)
	DSP.mix(b, snap, 0.0, 1.3)
	var thump := DSP.osc(0.1, func(u: float) -> float: return DSP.sweep(190.0, 60.0, u), &"sine")
	DSP.envelope(thump, 0.001, 0.03)
	DSP.mix(b, thump, 0.0, 0.55)
	var chirp := DSP.osc(0.25, func(u: float) -> float: return DSP.sweep(3600.0, 520.0, pow(u, 0.6)), &"saw")
	DSP.filter(chirp, &"bandpass", 1900.0, 1.2)
	DSP.envelope(chirp, 0.001, 0.07, 0.03)
	DSP.mix(b, chirp, 0.005, 0.4)
	# The arc: a buzz sagging from 240 Hz to 95 Hz (a saw and a square an octave up, driven hard so the harmonics buzz), with a sizzle
	# of high noise riding it.
	var arc_d: float = 0.88
	var pitch: Callable = func(u: float) -> float: return DSP.sweep(240.0, 95.0, pow(u, 0.6)) * (1.0 + 0.03 * sin(TAU * 31.0 * u))
	var arc := DSP.osc(arc_d, pitch, &"saw")
	DSP.mix(arc, DSP.osc(arc_d, func(u: float) -> float: return pitch.call(u) * 2.0, &"square"), 0.0, 0.5)
	DSP.drive(arc, 5.0)
	DSP.filter(arc, &"bandpass", 1900.0, 0.6)
	var sizzle := DSP.noise(arc_d, rng)
	DSP.filter(sizzle, &"bandpass", 4800.0, 0.8)
	DSP.mix(arc, sizzle, 0.0, 0.8)
	# The flicker: the arc is cut in and out in cells of about 22 ms, more and more of them out as it dies.
	var cell: int = int(0.022 * RATE)
	var at: int = 0
	while at < arc.size():
		var u: float = float(at) / float(arc.size())
		var level: float = 1.0 if rng.randf() < lerpf(0.95, 0.35, u) else 0.07
		for j: int in mini(cell, arc.size() - at):
			arc[at + j] *= level
		at += cell
	DSP.envelope(arc, 0.002, 0.3, 0.12)
	DSP.mix(b, arc, 0.01, 0.95)
	# Crackles thinning out, and the ballast's hum winding down beneath.
	DSP.mix(b, _crackle(d, 26, 0.4, 4200.0, rng), 0.03, 0.6)
	var hum := DSP.osc(0.9, func(u: float) -> float: return DSP.sweep(100.0, 70.0, u), &"saw")
	DSP.filter(hum, &"lowpass", 600.0)
	DSP.adsr(hum, 0.02, 0.2, 0.5, 0.4)
	DSP.mix(b, hum, 0.05, 0.14)
	DSP.shape(b, 0.001, 0.12)
	DSP.crush(b, 8, 16000.0)
	return b


## A hand wiping a board (0.7 s): a dry swish rising and falling, gritty, a few flecks coming off.
func _wipe() -> PackedFloat32Array:
	var rng := _rng(2204)
	var d: float = 0.7
	var b := DSP.buffer(d)
	var swish := DSP.noise(d, rng)
	DSP.filter_sweep(swish, &"bandpass", 1500.0, 2600.0, 0.9)
	var n: int = swish.size()
	for i: int in n:
		var u: float = float(i) / n
		swish[i] *= pow(sin(PI * u), 1.2) * (0.6 + 0.4 * absf(sin(u * 41.0 + 2.0 * sin(u * 13.0))))
	DSP.mix(b, swish, 0.0, 0.8)
	var low := DSP.noise(d, rng)
	DSP.filter(low, &"lowpass", 420.0)
	DSP.adsr(low, 0.25, 0.2, 0.4, 0.2)
	DSP.mix(b, low, 0.0, 0.5)
	DSP.mix(b, _trickle(0.4, 8, rng), 0.25, 0.4)
	DSP.shape(b, 0.02, 0.15)
	DSP.crush(b, 10, 20000.0)
	return b


## Scrambling up loose rubble (1.8 s): hands and feet finding holds, stones knocking and sliding away behind.
func _scramble() -> PackedFloat32Array:
	var rng := _rng(2205)
	var d: float = 1.8
	var b := DSP.buffer(d)
	var at: float = 0.05
	var k: int = 0
	while at < d - 0.3:
		var scrape := DSP.noise(0.16, rng)
		DSP.filter_sweep(scrape, &"bandpass", 1400.0, 700.0, 1.1)
		DSP.envelope(scrape, 0.004, 0.05, 0.04)
		DSP.mix(b, scrape, at, 0.7)
		var knock := DSP.tom(0.1, rng.randf_range(200.0, 340.0), rng)
		DSP.mix(b, knock, at + 0.03, 0.35)
		DSP.mix(b, _trickle(0.3, 7, rng), at + 0.06, 0.4)
		at += 0.27 + rng.randf_range(-0.03, 0.05)
		k += 1
	DSP.shape(b, 0.01, 0.25)
	DSP.crush(b, 10, 20000.0)
	return b


## Dropping to the floor (0.7 s): a dull thump through the boots, grit skittering away.
func _thud() -> PackedFloat32Array:
	var rng := _rng(2206)
	var d: float = 0.7
	var b := DSP.buffer(d)
	DSP.mix(b, DSP.kick(0.3, 120.0, 45.0, rng), 0.0, 0.9)
	var slap := DSP.noise(0.08, rng)
	DSP.filter(slap, &"lowpass", 1600.0)
	DSP.envelope(slap, 0.0005, 0.02)
	DSP.mix(b, slap, 0.0, 0.6)
	DSP.mix(b, _trickle(0.5, 14, rng), 0.05, 0.5)
	DSP.shape(b, 0.001, 0.2)
	DSP.crush(b, 9, 18000.0)
	return b


## The station's hum (2.4 s): power running somewhere in the dark, low and steady, a creak of metal far off.
func _hum() -> PackedFloat32Array:
	var rng := _rng(2207)
	var d: float = WIND_SECONDS
	var b := DSP.buffer(d)
	for h: Array in [[55.0, 0.7], [110.0, 0.35], [165.0, 0.12]]:
		var hz: float = h[0]
		var tone := DSP.osc(d, func(u: float) -> float: return hz * (1.0 + 0.003 * sin(TAU * 0.7 * u)), &"saw")
		DSP.filter(tone, &"lowpass", 500.0)
		DSP.mix(b, tone, 0.0, float(h[1]) * 0.6)
	var n: int = b.size()
	for i: int in n:
		b[i] *= 0.85 + 0.15 * sin(TAU * 0.5 * float(i) / RATE)
	var creak := DSP.osc(0.5, func(u: float) -> float: return DSP.sweep(380.0, 520.0, u), &"saw")
	DSP.filter(creak, &"bandpass", 600.0, 4.0)
	DSP.adsr(creak, 0.15, 0.1, 0.4, 0.2)
	DSP.mix(b, creak, 1.1, 0.06)
	DSP.mix(b, _crackle(d, 8, 5.0, 1800.0, rng), 0.0, 0.1)
	DSP.shape(b, FADE, FADE)
	DSP.crush(b, 10, 16000.0)
	return b
