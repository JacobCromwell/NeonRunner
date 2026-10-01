extends "res://tools/asset_gen/sfx_bank.gd"
## The Tithe Collector's sounds (GDD §9.12), in the game's 16-bit style:
##   tithe_collector_cue  the approach cue (not a warning: touching it isn't an attack, but CLAUDE.md
##                        still asks that the player notice it): three short, descending smug "heh"
##                        chuckles, then two bright bell blips, a tiny cash-register "cha-ching" (the
##                        collector cashing in), so it reads as gaudy and self-satisfied, not hostile.
##                        The same every time: a cue must be learnable.


func sounds() -> Dictionary:
	return {
		"tithe_collector_cue": _tithe_collector_cue,
	}


## A smug little chuckle: three "heh" syllables, each a touch lower, a crude voice (sfx_bank._voice)
## on a low saw with "ah" formants, short and plosive.
func _tithe_collector_cue() -> PackedFloat32Array:
	var rng := _rng(1301)
	var b := DSP.buffer(1.05)
	var hehs: Array[float] = [150.0, 138.0, 128.0]
	for k: int in hehs.size():
		var at: float = 0.02 + k * 0.11
		var heh := _voice(0.09, func(_u: float) -> float: return hehs[k], Vector2(650.0, 900.0),
			Vector2(1100.0, 1500.0), 0.0, 0.0, rng)
		DSP.envelope(heh, 0.01, 0.045, 0.01)
		DSP.mix(b, heh, at, 0.6 + 0.08 * k)
	# The cash-register ding: two bright bell blips (the coin look's shine), a fifth apart.
	var root: float = 1568.0  # G6
	DSP.mix(b, _fm_note(0.22, root, 3.5, 1.6, 0.2, 0.09), 0.46, 0.5)
	DSP.mix(b, _fm_note(0.3, root * 1.5, 3.5, 1.6, 0.2, 0.11), 0.56, 0.55)
	var tick := DSP.noise(0.02, rng)
	DSP.filter(tick, &"bandpass", 3200.0, 2.0)
	DSP.envelope(tick, 0.0005, 0.012)
	DSP.mix(b, tick, 0.55, 0.3)
	DSP.filter(b, &"highpass", 160.0)
	DSP.crush(b, 10, 24000.0)
	return b
