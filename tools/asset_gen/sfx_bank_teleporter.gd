extends "res://tools/asset_gen/sfx_bank.gd"
## The teleporters' sound (task Q4; GDD §5, Zone 9, proposed: the runner "arrives running in the output pad's lane, with
## a short flash and a sound"), in the game's 16-bit style:
##   teleport  the jump (the Player's `teleport` event, as the runner lands on the output pad): a space-age warp. A
##             bright FM chirp shooting up (the runner leaving), a fluttering shimmer of sparkles sweeping down through
##             it (the beam), and the arrival: a soft low thump and a glassy bell ping on the output pad, all over about
##             0.7 s, so it never covers a warning of what's ahead of the landing for long.
## Nothing about a teleporter hurts, so it has no warning sound (CLAUDE.md: every attack warns; a teleporter is no attack).
## DESIGN-TBD (docs/questions/q4.md): the sound.


func sounds() -> Dictionary:
	return {
		"teleport": _teleport,
	}


func _teleport() -> PackedFloat32Array:
	var rng := _rng(1701)
	var d: float = 0.72
	var b := DSP.buffer(d)
	# The leaving: an FM chirp shooting up, its index opening as it goes (brighter, more space-age).
	var chirp_s: float = 0.2
	var chirp := DSP.fm(chirp_s, func(u: float) -> float: return DSP.sweep(320.0, 2600.0, u), 1.5,
		func(u: float) -> float: return 0.8 + 2.4 * u)
	DSP.envelope(chirp, 0.01, 0.5, 0.03)
	DSP.mix(b, chirp, 0.0, 0.5)
	# Two detuned saws gliding up under it, a phaser's comb (the warp's body).
	for detune: float in [1.0, 1.013]:
		var saw := DSP.osc(chirp_s, func(u: float) -> float: return DSP.sweep(160.0, 1300.0, u) * detune, &"saw")
		DSP.filter(saw, &"lowpass", 2400.0)
		DSP.envelope(saw, 0.01, 0.12, 0.03)
		DSP.mix(b, saw, 0.0, 0.18)
	# The beam: bright sparkles sweeping down, fluttering.
	var beam_s: float = 0.55
	var beam := DSP.noise(beam_s, rng)
	DSP.filter_sweep(beam, &"bandpass", 9000.0, 2200.0, 2.2)
	for i: int in beam.size():
		var t: float = float(i) / RATE
		beam[i] *= 0.6 + 0.4 * sin(TAU * 28.0 * t)
	DSP.envelope(beam, 0.04, 0.22, 0.08)
	DSP.mix(b, beam, 0.06, 0.55)
	DSP.mix(b, _crackle(beam_s, 14, 0.25, 6500.0, rng), 0.08, 0.35)
	# The arrival: a soft low thump on the output pad and a glassy ping over it.
	var thump := DSP.osc(0.25, func(u: float) -> float: return DSP.sweep(190.0, 70.0, u))
	DSP.envelope(thump, 0.003, 0.07, 0.03)
	DSP.mix(b, thump, 0.17, 0.75)
	var ping := _fm_note(0.5, 1320.0, 3.5, 2.2, 0.4, 0.14)
	DSP.mix(b, ping, 0.18, 0.4)
	var ping_high := _fm_note(0.4, 1980.0, 3.5, 1.6, 0.3, 0.09)
	DSP.mix(b, ping_high, 0.2, 0.22)
	DSP.drive(b, 1.3)
	DSP.crush(b, 11, 24000.0)
	return b
