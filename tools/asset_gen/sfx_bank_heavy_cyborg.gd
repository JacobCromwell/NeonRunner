extends "res://tools/asset_gen/sfx_bank.gd"
## The Heavy Cyborg's sounds (task S1; GDD §9.16), in the game's 16-bit style:
##   heavy_cyborg_windup  the warning before a stream (CLAUDE.md: every attack warns): its gatling's barrels spinning
##                        up, a deep motor grinding up from 55 to 300 Hz with a whine a fifth above it, heavy ratchet
##                        clunks speeding up from 5 to 36 a second into a rattle, and the red charge's hum rising under
##                        it all, swelling. It lasts the whole wind-up (charge_time in data/enemies/heavy_cyborg.tres:
##                        1 s) and runs 30 ms into the first round, so the warning never goes quiet before the stream.
##                        Lower and heavier than the heli drone's wind-up (a buzzing motor over light clicks), so the two
##                        are told apart.
##   heavy_cyborg_shot    one round of the stream: a low, heavy double crack, over in 0.2 s, well inside the gap
##                        between two rounds as they're fired.
## DESIGN-TBD (docs/questions/s1.md): the sounds.

const WINDUP_SECONDS: float = 1.0


func sounds() -> Dictionary:
	return {
		"heavy_cyborg_windup": _windup,
		"heavy_cyborg_shot": _shot,
	}


func _windup() -> PackedFloat32Array:
	var rng := _rng(1801)
	var d: float = WINDUP_SECONDS + 0.03
	var b := DSP.buffer(d)
	# The motor grinding up, low-passed and driven, and the barrel cluster's whine a fifth above it.
	var motor := DSP.osc(d, func(u: float) -> float: return DSP.sweep(55.0, 300.0, u), &"saw")
	DSP.filter(motor, &"lowpass", 1400.0)
	DSP.drive(motor, 2.4)
	DSP.mix(b, motor, 0.0, 0.55)
	var whine := DSP.osc(d, func(u: float) -> float: return DSP.sweep(82.0, 450.0, u) * 1.01, &"saw")
	DSP.filter(whine, &"lowpass", 1800.0)
	DSP.mix(b, whine, 0.0, 0.25)
	# The barrels' ratchet: heavy clunks speeding up into a rattle.
	var clunk := DSP.metal_hit(0.035, 1300.0, 0.012, rng)
	var t: float = 0.0
	while t < d - 0.04:
		DSP.mix(b, clunk, t, 0.7)
		t += 1.0 / lerpf(5.0, 36.0, pow(t / d, 1.4))
	# The red charge's hum, rising under it all.
	var hum := DSP.fm(d, func(u: float) -> float: return DSP.sweep(140.0, 620.0, u), 2.0,
		func(u: float) -> float: return 0.6 + 1.6 * u)
	DSP.mix(b, hum, 0.0, 0.3)
	var n: int = b.size()
	for i: int in n:
		b[i] *= 0.4 + 0.6 * float(i) / n
	DSP.shape(b, 0.02, 0.02)
	DSP.crush(b, 8, 16000.0)
	return b


func _shot() -> PackedFloat32Array:
	var rng := _rng(1802)
	var b := DSP.buffer(0.2)
	for k: int in 2:
		var crack := DSP.noise(0.08, rng)
		DSP.filter(crack, &"bandpass", 2400.0, 0.6)
		DSP.envelope(crack, 0.0005, 0.025)
		DSP.mix(crack, DSP.kick(0.08, 420.0, 110.0, rng), 0.0, 0.22)
		DSP.mix(crack, DSP.metal_hit(0.04, 2600.0, 0.01, rng), 0.0, 0.45)
		DSP.mix(b, crack, k * 0.05, 1.0 - 0.25 * k)
	DSP.drive(b, 3.0)
	DSP.crush(b, 7, 12000.0)
	return b
