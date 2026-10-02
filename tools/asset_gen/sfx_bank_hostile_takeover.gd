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


func sounds() -> Dictionary:
	return {
		"takeover_gunship": _gunship,
		"takeover_couplings": _couplings,
		"takeover_decouple": _decouple,
		"takeover_breakaway": _breakaway,
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
