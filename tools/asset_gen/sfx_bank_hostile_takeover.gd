extends "res://tools/asset_gen/sfx_bank.gd"
## Hostile Takeover's sounds (GDD §10: the Chairman's armored maglev train, a military gunship pacing it),
## in the same crunchy 16-bit / heavy-metal style as the rest: turbines, heavy steel and hydraulics.
##   takeover_gunship    the entrance: the gunship sweeping in over the runner, its turbines whining down as it
##                       passes and settles over the train, under a heavy thrum
##   takeover_couplings  the couplings go live (the first of a phase lights up red): a heavy lock clunking
##                       home, an electric hum swelling, and a short two-note tone
##   takeover_decouple   a coupling stomped: the knuckle cracking apart with a huge clank, a hydraulic burst
##                       and a ringing snap
##   takeover_breakaway  the carriages behind breaking away: steel shrieking on the guideway, scraping, and
##                       two crashes falling away behind
##   takeover_whine      a strafe's warning (phase 2): the gunship's guns spinning up, a rising whine under a
##                       servo whirr, as long as the warning (1.2 s)
##   takeover_strafe     the strafe: a rattling cannon burst raking down the lane, with ricochets
##   takeover_drop       the Buzz Overdrive landing on the roof: a huge steel slam, a crunch and a clatter
##   takeover_bay        the drop bay opening as the gunship comes down for the ride: a pneumatic hiss, two
##                       heavy clunks and a low warning tone
##   takeover_clamps     the docking (phase 3): three huge clamps slamming home one after another, hydraulics
##                       hissing, a deep lock tone
##   takeover_merger     "MERGER COMPLETE": a corporate broadcast's sting, a cold chord rising to a bright
##                       three-note fanfare over a hum
##   takeover_clamp      a docking clamp torn loose: a hydraulic burst, steel snapping with a ringing clank,
##                       a falling alarm blip
##   takeover_explode    the gunship exploding (the defeat): a huge boom, a fireball's roar and crackle, its
##                       turbines winding down, debris raining
##   takeover_derail     the locomotive derailing into the lobby: a long screech of steel, a crash of glass
##                       and girders, the sculpture's slab toppling with a deep thud


func sounds() -> Dictionary:
	return {
		"takeover_gunship": _gunship,
		"takeover_couplings": _couplings,
		"takeover_decouple": _decouple,
		"takeover_breakaway": _breakaway,
		"takeover_whine": _whine,
		"takeover_strafe": _strafe,
		"takeover_drop": _drop,
		"takeover_bay": _bay,
		"takeover_clamps": _clamps,
		"takeover_merger": _merger,
		"takeover_clamp": _clamp,
		"takeover_explode": _explode,
		"takeover_derail": _derail,
	}


## The gunship sweeping in: a turbine whine falling as it passes (a Doppler drop), a jet's roar swelling
## and easing, and the thrum of its engines.
func _gunship() -> PackedFloat32Array:
	var rng := _rng(701)
	var d: float = 2.3
	var b := DSP.buffer(d)
	var roar := DSP.noise(d, rng)
	DSP.filter_sweep(roar, &"bandpass", 2400.0, 500.0, 0.8)
	DSP.adsr(roar, 0.6, 0.5, 0.55, 0.8)
	DSP.mix(b, roar, 0.0, 0.9)
	var whine := DSP.osc(d, func(u: float) -> float: return 1500.0 - 650.0 * smoothstep(0.25, 0.6, u), &"triangle")
	DSP.adsr(whine, 0.4, 0.4, 0.5, 0.8)
	DSP.mix(b, whine, 0.0, 0.22)
	var thrum := DSP.osc(d, func(u: float) -> float: return 52.0 - 8.0 * u, &"saw")
	DSP.filter(thrum, &"lowpass", 260.0)
	DSP.drive(thrum, 2.4)
	for i: int in thrum.size():
		var t: float = float(i) / RATE
		thrum[i] *= 0.6 + 0.4 * sin(t * TAU * 14.0)
	DSP.adsr(thrum, 0.3, 0.4, 0.75, 0.7)
	DSP.mix(b, thrum, 0.0, 0.7)
	DSP.crush(b, 10, 22000.0)
	return b


## The couplings go live: a heavy lock clunking home twice, an electric hum swelling, a two-note tone.
func _couplings() -> PackedFloat32Array:
	var rng := _rng(702)
	var d: float = 1.15
	var b := DSP.buffer(d)
	DSP.mix(b, DSP.metal_hit(0.35, 150.0, 0.09, rng), 0.0, 0.85)
	DSP.mix(b, DSP.kick(0.2, 110.0, 50.0, rng), 0.0, 0.5)
	DSP.mix(b, DSP.metal_hit(0.3, 175.0, 0.07, rng), 0.16, 0.65)
	var hum := DSP.osc(0.9, func(u: float) -> float: return DSP.sweep(90.0, 120.0, minf(u * 1.6, 1.0)), &"square")
	DSP.filter(hum, &"lowpass", 900.0)
	DSP.adsr(hum, 0.25, 0.2, 0.6, 0.3)
	DSP.mix(b, hum, 0.2, 0.3)
	DSP.mix(b, _blip(0.18, 784.0, 0.25, 0.08), 0.6, 0.45)
	DSP.mix(b, _blip(0.26, 1046.5, 0.25, 0.1), 0.78, 0.5)
	DSP.crush(b, 10, 22000.0)
	return b


## A coupling stomped: the knuckle cracking apart (a huge clank and a low thud), a hydraulic burst, a
## ringing snap of steel.
func _decouple() -> PackedFloat32Array:
	var rng := _rng(703)
	var d: float = 1.1
	var b := _boom(d, 130.0, 42.0, 0.16, rng)
	DSP.mix(b, DSP.metal_hit(0.9, 118.0, 0.32, rng), 0.0, 0.95)
	DSP.mix(b, DSP.metal_hit(0.6, 233.0, 0.2, rng), 0.012, 0.5)
	var burst := DSP.noise(0.7, rng)
	DSP.filter(burst, &"highpass", 2200.0)
	DSP.adsr(burst, 0.01, 0.15, 0.4, 0.4)
	DSP.mix(b, burst, 0.05, 0.6)
	var snap := DSP.osc(0.5, func(u: float) -> float: return 1900.0 * (1.0 - 0.3 * u), &"triangle")
	DSP.envelope(snap, 0.001, 0.09)
	DSP.mix(b, snap, 0.02, 0.35)
	DSP.mix(b, _crackle(0.6, 26, 0.18, 2600.0, rng), 0.0, 0.5)
	DSP.drive(b, 1.6)
	DSP.crush(b, 9, 21000.0)
	return b


## The carriages behind breaking away: steel shrieking on the guideway (a squeal sliding down), scraping
## grit, and two crashes, the second further off.
func _breakaway() -> PackedFloat32Array:
	var rng := _rng(704)
	var d: float = 2.4
	var b := DSP.buffer(d)
	var squeal := DSP.osc(1.6, func(u: float) -> float: return DSP.sweep(2600.0, 900.0, u) * (1.0 + 0.02 * sin(u * 90.0)), &"saw")
	DSP.filter(squeal, &"bandpass", 1800.0, 3.0)
	DSP.adsr(squeal, 0.05, 0.4, 0.6, 0.7)
	DSP.mix(b, squeal, 0.05, 0.4)
	var scrape := DSP.noise(1.8, rng)
	DSP.filter_sweep(scrape, &"bandpass", 1500.0, 400.0, 1.0)
	DSP.adsr(scrape, 0.05, 0.5, 0.5, 0.8)
	DSP.mix(b, scrape, 0.0, 0.55)
	DSP.mix(b, _explosion(0.9, 0.7, rng), 0.55, 0.7)
	var far := _explosion(0.9, 0.6, rng)
	DSP.filter(far, &"lowpass", 900.0)
	DSP.mix(b, far, 1.4, 0.4)
	DSP.crush(b, 10, 22000.0)
	return b


## A strafe's warning: the guns' barrels spinning up (a whine rising over the warning), a servo whirr and a
## pulsing tick that speeds up, ending as the burst starts.
func _whine() -> PackedFloat32Array:
	var rng := _rng(705)
	var d: float = 1.2
	var b := DSP.buffer(d)
	var whine := DSP.osc(d, func(u: float) -> float: return DSP.sweep(380.0, 2100.0, u * u), &"saw")
	DSP.filter(whine, &"bandpass", 1400.0, 1.2)
	DSP.adsr(whine, 0.15, 0.1, 0.9, 0.05)
	DSP.mix(b, whine, 0.0, 0.5)
	var tone := DSP.osc(d, func(u: float) -> float: return DSP.sweep(760.0, 1520.0, u), &"square")
	DSP.filter(tone, &"lowpass", 2600.0)
	DSP.adsr(tone, 0.2, 0.1, 0.7, 0.05)
	DSP.mix(b, tone, 0.0, 0.18)
	var whirr := DSP.noise(d, rng)
	DSP.filter_sweep(whirr, &"bandpass", 600.0, 2400.0, 2.0)
	DSP.adsr(whirr, 0.1, 0.2, 0.6, 0.1)
	DSP.mix(b, whirr, 0.0, 0.25)
	var t: float = 0.0
	var gap: float = 0.16
	while t < d - 0.05:
		DSP.mix(b, _blip(0.03, 2400.0, 0.2, 0.02), t, 0.3)
		t += gap
		gap = maxf(gap * 0.8, 0.045)
	DSP.crush(b, 10, 22000.0)
	return b


## The strafe: a rattling burst of heavy cannon rounds (shots a little irregular, each a crack and a thump),
## ricochets whining off the steel, a low rumble under it.
func _strafe() -> PackedFloat32Array:
	var rng := _rng(706)
	var d: float = 0.95
	var b := DSP.buffer(d)
	var t: float = 0.0
	while t < 0.62:
		var shot := DSP.noise(0.09, rng)
		DSP.filter(shot, &"bandpass", 1500.0 + rng.randf_range(-300.0, 300.0), 0.8)
		DSP.envelope(shot, 0.001, 0.06)
		DSP.mix(b, shot, t, 0.6)
		DSP.mix(b, DSP.kick(0.08, 140.0, 60.0, rng), t, 0.45)
		t += 0.055 + rng.randf_range(0.0, 0.02)
	for i: int in 3:
		var at: float = rng.randf_range(0.1, 0.6)
		var ric := DSP.osc(0.22, func(u: float) -> float: return DSP.sweep(3200.0, 1700.0, u), &"triangle")
		DSP.envelope(ric, 0.002, 0.16)
		DSP.mix(b, ric, at, 0.16)
	var rumble := DSP.osc(d, func(u: float) -> float: return 55.0 - 12.0 * u, &"saw")
	DSP.filter(rumble, &"lowpass", 220.0)
	DSP.adsr(rumble, 0.02, 0.2, 0.6, 0.3)
	DSP.mix(b, rumble, 0.0, 0.4)
	DSP.drive(b, 1.5)
	DSP.crush(b, 9, 21000.0)
	return b


## The Buzz Overdrive landing on the roof: a huge steel slam (a low boom and a metal hit), a crunch of grit
## and a clatter of its tracks settling.
func _drop() -> PackedFloat32Array:
	var rng := _rng(707)
	var d: float = 0.95
	var b := _boom(d, 95.0, 34.0, 0.2, rng)
	DSP.mix(b, DSP.metal_hit(0.7, 96.0, 0.3, rng), 0.0, 0.9)
	DSP.mix(b, DSP.metal_hit(0.5, 181.0, 0.18, rng), 0.01, 0.45)
	var crunch := DSP.noise(0.4, rng)
	DSP.filter(crunch, &"bandpass", 900.0, 0.7)
	DSP.adsr(crunch, 0.005, 0.12, 0.3, 0.2)
	DSP.mix(b, crunch, 0.0, 0.5)
	DSP.mix(b, _crackle(0.5, 18, 0.16, 1800.0, rng), 0.12, 0.45)
	DSP.drive(b, 1.5)
	DSP.crush(b, 9, 21000.0)
	return b


## The drop bay opening: a pneumatic hiss, two heavy clunks as the doors part, and a low two-note warning
## tone (the bay glows red: the weak point).
func _bay() -> PackedFloat32Array:
	var rng := _rng(708)
	var d: float = 1.0
	var b := DSP.buffer(d)
	var hiss := DSP.noise(0.7, rng)
	DSP.filter(hiss, &"highpass", 3000.0)
	DSP.adsr(hiss, 0.02, 0.2, 0.5, 0.35)
	DSP.mix(b, hiss, 0.0, 0.45)
	DSP.mix(b, DSP.metal_hit(0.35, 132.0, 0.1, rng), 0.05, 0.8)
	DSP.mix(b, DSP.kick(0.2, 100.0, 45.0, rng), 0.05, 0.45)
	DSP.mix(b, DSP.metal_hit(0.3, 158.0, 0.08, rng), 0.24, 0.6)
	DSP.mix(b, _blip(0.2, 392.0, 0.25, 0.1), 0.5, 0.4)
	DSP.mix(b, _blip(0.26, 330.0, 0.25, 0.12), 0.7, 0.45)
	DSP.crush(b, 10, 22000.0)
	return b


## The docking: three huge clamps slamming home one after another (each a heavy clank over a thud), the
## hydraulics hissing, a deep lock tone at the end.
func _clamps() -> PackedFloat32Array:
	var rng := _rng(709)
	var d: float = 1.4
	var b := DSP.buffer(d)
	for i: int in 3:
		var at: float = 0.08 + i * 0.26
		DSP.mix(b, DSP.metal_hit(0.45, 96.0 + i * 14.0, 0.16, rng), at, 0.85)
		DSP.mix(b, DSP.kick(0.22, 90.0, 40.0, rng), at, 0.6)
		var hiss := DSP.noise(0.25, rng)
		DSP.filter(hiss, &"highpass", 2800.0)
		DSP.adsr(hiss, 0.01, 0.08, 0.4, 0.12)
		DSP.mix(b, hiss, at + 0.04, 0.3)
	var lock := DSP.osc(0.6, func(u: float) -> float: return 62.0 - 6.0 * u, &"square")
	DSP.filter(lock, &"lowpass", 420.0)
	DSP.adsr(lock, 0.02, 0.15, 0.6, 0.3)
	DSP.mix(b, lock, 0.78, 0.55)
	DSP.drive(b, 1.4)
	DSP.crush(b, 10, 22000.0)
	return b


## "MERGER COMPLETE": a corporate broadcast's sting: a cold chord swelling (square waves through a soft
## filter), then a bright three-note fanfare, a hum under it.
func _merger() -> PackedFloat32Array:
	var d: float = 1.7
	var b := DSP.buffer(d)
	for f: float in [196.0, 246.94, 293.66]:
		var chord := DSP.osc(0.9, func(_u: float) -> float: return f, &"square")
		DSP.filter(chord, &"lowpass", 1400.0)
		DSP.adsr(chord, 0.25, 0.2, 0.7, 0.3)
		DSP.mix(b, chord, 0.0, 0.16)
	var notes: Array[float] = [392.0, 493.88, 587.33]
	for i: int in notes.size():
		var at: float = 0.6 + i * 0.16
		DSP.mix(b, _blip(0.5 if i == notes.size() - 1 else 0.15, notes[i], 0.3, 0.12 if i == notes.size() - 1 else 0.06), at, 0.4)
	var hum := DSP.osc(d, func(_u: float) -> float: return 98.0, &"saw")
	DSP.filter(hum, &"lowpass", 300.0)
	DSP.adsr(hum, 0.3, 0.3, 0.5, 0.6)
	DSP.mix(b, hum, 0.0, 0.25)
	DSP.crush(b, 10, 22000.0)
	return b


## A docking clamp torn loose: a hydraulic burst, steel snapping with a ringing clank, an alarm blip falling.
func _clamp() -> PackedFloat32Array:
	var rng := _rng(710)
	var d: float = 1.0
	var b := _boom(d, 120.0, 40.0, 0.14, rng)
	DSP.mix(b, DSP.metal_hit(0.8, 140.0, 0.3, rng), 0.0, 0.9)
	DSP.mix(b, DSP.metal_hit(0.5, 267.0, 0.18, rng), 0.03, 0.45)
	var burst := DSP.noise(0.6, rng)
	DSP.filter(burst, &"highpass", 2000.0)
	DSP.adsr(burst, 0.005, 0.12, 0.45, 0.35)
	DSP.mix(b, burst, 0.02, 0.55)
	var alarm := DSP.osc(0.35, func(u: float) -> float: return DSP.sweep(880.0, 440.0, u), &"square")
	DSP.filter(alarm, &"lowpass", 2200.0)
	DSP.envelope(alarm, 0.01, 0.3)
	DSP.mix(b, alarm, 0.35, 0.22)
	DSP.drive(b, 1.6)
	DSP.crush(b, 9, 21000.0)
	return b


## The gunship exploding: a huge boom, a fireball's roar and crackle, its turbines winding down, debris
## raining.
func _explode() -> PackedFloat32Array:
	var rng := _rng(711)
	var d: float = 2.2
	var b := DSP.buffer(d)
	DSP.mix(b, _explosion(1.6, 1.0, rng), 0.0, 1.0)
	DSP.mix(b, _boom(1.2, 70.0, 28.0, 0.3, rng), 0.0, 0.8)
	var roar := DSP.noise(1.6, rng)
	DSP.filter_sweep(roar, &"lowpass", 2400.0, 300.0, 0.7)
	DSP.adsr(roar, 0.02, 0.4, 0.5, 0.9)
	DSP.mix(b, roar, 0.05, 0.6)
	var turbine := DSP.osc(1.4, func(u: float) -> float: return DSP.sweep(1300.0, 180.0, u), &"triangle")
	DSP.adsr(turbine, 0.02, 0.3, 0.5, 0.8)
	DSP.mix(b, turbine, 0.1, 0.18)
	DSP.mix(b, _crackle(1.6, 40, 0.2, 2200.0, rng), 0.3, 0.45)
	DSP.drive(b, 1.6)
	DSP.crush(b, 9, 21000.0)
	return b


## The locomotive derailing: a long screech of steel sliding off the guideway, a crash of glass and girders
## as it ploughs into the lobby, and the sculpture's slab toppling with a deep thud.
func _derail() -> PackedFloat32Array:
	var rng := _rng(712)
	var d: float = 2.4
	var b := DSP.buffer(d)
	var screech := DSP.osc(1.4, func(u: float) -> float: return DSP.sweep(2300.0, 700.0, u) * (1.0 + 0.03 * sin(u * 120.0)), &"saw")
	DSP.filter(screech, &"bandpass", 1500.0, 2.5)
	DSP.adsr(screech, 0.05, 0.4, 0.6, 0.5)
	DSP.mix(b, screech, 0.0, 0.4)
	DSP.mix(b, _explosion(1.2, 0.9, rng), 0.9, 0.85)
	var glass := DSP.noise(0.9, rng)
	DSP.filter(glass, &"highpass", 4200.0)
	DSP.adsr(glass, 0.005, 0.2, 0.4, 0.6)
	DSP.mix(b, glass, 0.92, 0.5)
	DSP.mix(b, _crackle(1.0, 30, 0.2, 3400.0, rng), 0.95, 0.4)
	DSP.mix(b, _boom(0.9, 60.0, 26.0, 0.25, rng), 1.45, 0.8)
	DSP.drive(b, 1.5)
	DSP.crush(b, 9, 21000.0)
	return b
