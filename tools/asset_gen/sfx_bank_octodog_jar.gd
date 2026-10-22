extends "res://tools/asset_gen/sfx_bank.gd"
## The Octodog jars' sound (task Q5; GDD §5, Zone 9: "sometimes smashing an Octodog jar doodad releases its Octodog into
## the world"), in the game's 16-bit style:
##   octodog_release  a dog bursting out of its smashed jar (Octodog._release, where it comes out): the jar's glass
##                    shattering (a sharp crack, bright inharmonic pings and a glassy hiss), the cold fluid it floated in
##                    spilling out in a wet slosh, and the dog's startled snarl over its servo, the Octodog's own voice
##                    (sfx_bank_enemies.gd, octodog_windup: low, wet and organic), short and rising. Not a warning: the
##                    freed dog's attack warns as any dog's does, with its wind-up's growl and telegraph.
## The jar's break itself is the dash's doodad crunch (Player.smashed: doodad_smash), which plays with it.
## DESIGN-TBD (docs/questions/q5.md 10): the sound.


func sounds() -> Dictionary:
	return {
		"octodog_release": _release,
	}


func _release() -> PackedFloat32Array:
	var rng := _rng(1701)
	var d: float = 0.95
	var b := DSP.buffer(d)
	# The glass breaking: a sharp crack, a few high inharmonic pings and a glassy hiss.
	var crack := DSP.noise(0.06, rng)
	DSP.filter(crack, &"highpass", 2800.0)
	DSP.envelope(crack, 0.0005, 0.014)
	DSP.mix(b, crack, 0.0, 1.3)
	for k: int in 6:
		var hz: float = [2900.0, 3700.0, 4600.0, 5300.0, 6400.0, 7600.0][k]
		var ping := DSP.osc(0.3, func(_u: float) -> float: return hz)
		DSP.envelope(ping, 0.001, 0.04 + 0.015 * k)
		DSP.mix(b, ping, 0.005 + 0.018 * k + rng.randf_range(0.0, 0.01), 0.22)
	var glass := DSP.noise(0.45, rng)
	DSP.filter(glass, &"highpass", 4200.0)
	DSP.envelope(glass, 0.001, 0.1)
	DSP.mix(b, glass, 0.0, 0.6)
	# Shards tinkling down after it.
	for k: int in 7:
		var at: float = 0.12 + 0.07 * k + rng.randf_range(0.0, 0.03)
		var tink := DSP.osc(0.12, func(_u: float) -> float: return rng.randf_range(4800.0, 8200.0))
		DSP.envelope(tink, 0.001, 0.025)
		DSP.mix(b, tink, at, 0.18 * exp(-float(k) * 0.25))
	# The fluid spilling out: a wet slosh, noise through a band-pass wobbling low.
	var slosh := DSP.noise(0.6, rng)
	var f := DSP.Biquad.new()
	for i: int in slosh.size():
		if i % 16 == 0:
			f.set_filter(&"bandpass", 520.0 + 260.0 * sin(TAU * 6.0 * i / RATE), 2.5)
		slosh[i] = f.process(slosh[i])
	DSP.envelope(slosh, 0.02, 0.22, 0.05)
	DSP.mix(b, slosh, 0.03, 0.9)
	# Its startled snarl over a whirring servo, rising as it tumbles out: the Octodog's voice, short.
	var snarl := DSP.fm(0.42, func(u: float) -> float: return DSP.sweep(95.0, 150.0, u), 1.5,
		func(u: float) -> float: return 4.0 - 1.5 * u)
	var rough := DSP.noise(0.42, rng)
	DSP.filter(rough, &"lowpass", 45.0, 0.7)
	for i: int in snarl.size():
		snarl[i] *= clampf(0.6 + 14.0 * rough[i], 0.1, 1.2)
	DSP.envelope(snarl, 0.02, 0.2, 0.05)
	DSP.mix(b, snarl, 0.12, 0.75)
	var servo := DSP.osc(0.35, func(u: float) -> float: return DSP.sweep(700.0, 1100.0, u), &"saw")
	DSP.envelope(servo, 0.01, 0.15, 0.05)
	DSP.mix(b, servo, 0.14, 0.1)
	DSP.drive(b, 2.2)
	DSP.filter(b, &"lowpass", 9000.0)
	DSP.crush(b, 9, 20000.0)
	return b
