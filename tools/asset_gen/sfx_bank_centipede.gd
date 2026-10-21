extends "res://tools/asset_gen/sfx_bank.gd"
## The Cybernetic Centipede's sounds (task O3; GDD §9.15: "a hiss and a clatter of legs when it wakes, and the head
## rearing with its mandibles opening just before each bite, so every bite is seen and heard first"), in the game's
## 16-bit style:
##   centipede_wake   its warning as it wakes: a long hiss of steam through its valves, a clatter of many steel legs
##                    finding their footing (quick metal ticks, thickening), and a servo groaning up under them
##   centipede_bite   a bite's warning, as its head rears: its mandibles ratcheting open (two clacks), a sharp rising
##                    snake's hiss and a servo's whine. BITE_LENGTH long: about its telegraph (CentipedeTuning), so the
##                    hiss peaks as the jaws snap
##   centipede_snap   the bite: its jaws snapping shut, a hard steel clank and a short spit of steam
##   centipede_wound  a dash's first wound: a glass tube cracking, a burst of steam and a crackle of sparks
##   centipede_death  the second: its plates and legs clattering apart, glass shattering, a deep thud and a last falling
##                    hiss from its broken valves
## DESIGN-TBD (docs/questions/o3.md 12): the sounds.

## The bite's warning's length (seconds): its telegraph's (CentipedeTuning.bite_telegraph, 0.45 s) and a tail.
const BITE_LENGTH: float = 0.55


func sounds() -> Dictionary:
	return {
		"centipede_wake": _wake,
		"centipede_bite": _bite,
		"centipede_snap": _snap,
		"centipede_wound": _wound,
		"centipede_death": _death,
	}


## A hiss: noise through a band-pass around `hz`, swelling in over `attack` and dying away with `tau`.
func _hiss(seconds: float, hz: float, q: float, attack: float, tau: float, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := DSP.noise(seconds, rng)
	DSP.filter(b, &"bandpass", hz, q)
	DSP.filter(b, &"highpass", hz * 0.5)
	DSP.envelope(b, attack, tau, 0.05)
	return b


## Steel legs clattering: `count` small metal ticks over `seconds`, closer together toward the end (`thicken`), each a
## short bright ping at a random pitch around `hz`.
func _clatter(seconds: float, count: int, hz: float, thicken: float, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := DSP.buffer(seconds)
	for k: int in count:
		var u: float = pow(float(k) / count, thicken)
		var at: float = u * (seconds - 0.05) + rng.randf_range(0.0, 0.012)
		var tick := DSP.metal_hit(0.05, hz * rng.randf_range(0.8, 1.3), 0.012, rng)
		DSP.mix(b, tick, at, rng.randf_range(0.35, 0.8))
	DSP.filter(b, &"highpass", 900.0)
	return b


func _wake() -> PackedFloat32Array:
	var rng := _rng(1501)
	var d: float = 1.3
	var b := DSP.buffer(d)
	# The hiss: steam through its valves, swelling up and trailing off.
	var hiss := _hiss(d, 4200.0, 1.1, 0.18, 0.7, rng)
	DSP.mix(b, hiss, 0.0, 0.9)
	# Its legs finding their footing: a clatter that thickens.
	DSP.mix(b, _clatter(d - 0.15, 34, 2300.0, 0.6, rng), 0.15, 0.85)
	# A servo groaning up under it.
	var servo := DSP.osc(d, func(u: float) -> float: return DSP.sweep(70.0, 190.0, smoothstep(0.0, 0.8, u)), &"saw")
	DSP.filter(servo, &"lowpass", 900.0)
	DSP.envelope(servo, 0.25, 0.9, 0.1)
	DSP.mix(b, servo, 0.0, 0.35)
	# A clank as it rears.
	DSP.mix(b, DSP.metal_hit(0.35, 160.0, 0.12, rng), 0.05, 0.5)
	DSP.drive(b, 1.6)
	DSP.crush(b, 10, 22000.0)
	return b


func _bite() -> PackedFloat32Array:
	var rng := _rng(1502)
	var d: float = BITE_LENGTH
	var b := DSP.buffer(d)
	# Its mandibles ratcheting open: two clacks.
	DSP.mix(b, DSP.metal_hit(0.12, 900.0, 0.03, rng), 0.0, 0.9)
	DSP.mix(b, DSP.metal_hit(0.12, 1100.0, 0.03, rng), 0.09, 0.8)
	# A snake's hiss, rising to the snap.
	var hiss := DSP.noise(d, rng)
	DSP.filter_sweep(hiss, &"bandpass", 2500.0, 7000.0, 1.6)
	var n: int = hiss.size()
	for i: int in n:
		var u: float = float(i) / n
		hiss[i] *= smoothstep(0.0, 0.8, u) * (1.0 - smoothstep(0.92, 1.0, u))
	DSP.mix(b, hiss, 0.0, 1.0)
	# A servo's whine as its head rears up.
	var whine := DSP.osc(d, func(u: float) -> float: return DSP.sweep(380.0, 900.0, u), &"square")
	DSP.filter(whine, &"lowpass", 2600.0)
	DSP.envelope(whine, 0.05, 0.6, 0.06)
	DSP.mix(b, whine, 0.0, 0.18)
	DSP.drive(b, 1.4)
	DSP.crush(b, 10, 22000.0)
	return b


func _snap() -> PackedFloat32Array:
	var rng := _rng(1503)
	var d: float = 0.32
	var b := DSP.buffer(d)
	# Steel jaws snapping shut.
	DSP.mix(b, DSP.metal_hit(d, 520.0, 0.06, rng), 0.0, 1.0)
	DSP.mix(b, DSP.metal_hit(d, 1340.0, 0.04, rng), 0.004, 0.6)
	# A spit of steam.
	DSP.mix(b, _hiss(0.2, 5000.0, 1.0, 0.004, 0.06, rng), 0.01, 0.5)
	DSP.drive(b, 2.0)
	DSP.crush(b, 9, 20000.0)
	return b


func _wound() -> PackedFloat32Array:
	var rng := _rng(1504)
	var d: float = 0.9
	var b := DSP.buffer(d)
	# A glass tube cracking: a sharp break and a few high inharmonic pings.
	var crack := DSP.noise(0.06, rng)
	DSP.filter(crack, &"highpass", 3000.0)
	DSP.envelope(crack, 0.0005, 0.012)
	DSP.mix(b, crack, 0.0, 1.4)
	for k: int in 4:
		var hz: float = [3100.0, 4300.0, 5600.0, 6900.0][k]
		var ping := DSP.osc(0.25, func(_u: float) -> float: return hz)
		DSP.envelope(ping, 0.001, 0.05 + 0.02 * k)
		DSP.mix(b, ping, 0.01 + 0.02 * k, 0.25)
	# Steam bursting out of it.
	DSP.mix(b, _hiss(d, 3600.0, 0.9, 0.01, 0.35, rng), 0.02, 0.8)
	# Sparks crackling.
	DSP.mix(b, _crackle(d, 26, 0.3, 4500.0, rng), 0.05, 0.6)
	DSP.drive(b, 1.6)
	DSP.crush(b, 10, 22000.0)
	return b


func _death() -> PackedFloat32Array:
	var rng := _rng(1505)
	var d: float = 1.6
	var b := DSP.buffer(d)
	# A deep thud as it slumps.
	DSP.mix(b, _boom(d, 110.0, 40.0, 0.25, rng), 0.0, 0.8)
	# Its plates and legs clattering apart.
	for k: int in 7:
		var at: float = 0.02 + 0.12 * k + rng.randf_range(0.0, 0.05)
		DSP.mix(b, DSP.metal_hit(0.45, rng.randf_range(140.0, 420.0), 0.14, rng), at, rng.randf_range(0.35, 0.7))
	DSP.mix(b, _clatter(0.9, 22, 1800.0, 1.4, rng), 0.1, 0.55)
	# Glass shattering.
	var glass := DSP.noise(0.5, rng)
	DSP.filter(glass, &"highpass", 4000.0)
	DSP.envelope(glass, 0.001, 0.12)
	DSP.mix(b, glass, 0.0, 0.7)
	# A last hiss from its broken valves, falling away.
	var hiss := DSP.noise(d, rng)
	DSP.filter_sweep(hiss, &"bandpass", 5000.0, 900.0, 1.0)
	DSP.envelope(hiss, 0.05, 0.6, 0.1)
	DSP.mix(b, hiss, 0.1, 0.6)
	DSP.drive(b, 1.8)
	DSP.crush(b, 9, 20000.0)
	return b
