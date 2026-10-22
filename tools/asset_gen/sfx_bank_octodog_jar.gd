extends "res://tools/asset_gen/sfx_bank.gd"
## The Octodog jars' sound (task Q5; GDD §5, Zone 9: "sometimes smashing an Octodog jar doodad releases its Octodog into
## the world"), in the game's 16-bit style:
##   octodog_release  a dog bursting out of its smashed jar (Octodog._release, where it comes out): a wet slap of
##                    tentacles as it springs free and its startled snarl over its servo, the Octodog's own voice
##                    (sfx_bank_enemies.gd, octodog_windup: low, wet and organic), short and rising. The dog's alone: the
##                    jar's break is every doodad's (Player.smashed: doodad_smash), so a jar whose dog never comes out (a
##                    decoy, LevelLayout.DECOY) breaks exactly as one that releases its dog. Not a warning: the freed
##                    dog's attack warns as any dog's does, with its wind-up's growl and telegraph.
## DESIGN-TBD (docs/questions/q5.md 10): the sound.


func sounds() -> Dictionary:
	return {
		"octodog_release": _release,
	}


func _release() -> PackedFloat32Array:
	var rng := _rng(1701)
	var d: float = 0.7
	var b := DSP.buffer(d)
	# Its tentacles slapping free: two short wet smacks, noise through a low band-pass.
	for k: int in 2:
		var slap := DSP.noise(0.09, rng)
		DSP.filter(slap, &"bandpass", 420.0 + 180.0 * k, 1.4)
		DSP.envelope(slap, 0.002, 0.05)
		DSP.mix(b, slap, 0.0 + 0.07 * k, 0.8)
	# Its startled snarl over a whirring servo, rising as it tumbles out: the Octodog's voice, short.
	var snarl := DSP.fm(0.42, func(u: float) -> float: return DSP.sweep(95.0, 150.0, u), 1.5,
		func(u: float) -> float: return 4.0 - 1.5 * u)
	var rough := DSP.noise(0.42, rng)
	DSP.filter(rough, &"lowpass", 45.0, 0.7)
	for i: int in snarl.size():
		snarl[i] *= clampf(0.6 + 14.0 * rough[i], 0.1, 1.2)
	DSP.envelope(snarl, 0.02, 0.2, 0.05)
	DSP.mix(b, snarl, 0.04, 0.85)
	var servo := DSP.osc(0.35, func(u: float) -> float: return DSP.sweep(700.0, 1100.0, u), &"saw")
	DSP.envelope(servo, 0.01, 0.15, 0.05)
	DSP.mix(b, servo, 0.06, 0.1)
	DSP.drive(b, 2.2)
	DSP.filter(b, &"lowpass", 9000.0)
	DSP.crush(b, 9, 20000.0)
	return b
