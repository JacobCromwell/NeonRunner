extends "res://tools/asset_gen/sfx_bank.gd"
## The Barnacle Turret's sounds (GDD §9.8), in the game's 16-bit style. One set for both looks (the
## mechanical turret and the furry creature), so its warning is learned once:
##   barnacle_emerge  it pops out of its hatch in the ceiling: a hatch clunk, a rubbery pop and a short
##                    servo chirp rising (not a warning: it's there, it hasn't attacked)
##   barnacle_charge  the warning before every burst, in the cyborg's family (a whine climbing and
##                    pulsing faster) but lower and bubbling, so the two are told apart: it lasts the
##                    whole charge-up (charge_time in data/enemies/barnacle_turret.tres: 0.75 s) and
##                    runs 30 ms into the first bolt's sound
##   barnacle_shot    each bolt: a rounder, plosive "pew" than the cyborg's saw zap
##   barnacle_death   shot, clawed, dashed or stomped: a squeal falling away, a pop and a fizzle

const TUNING_PATH: String = "res://data/enemies/barnacle_turret.tres"


func sounds() -> Dictionary:
	return {
		"barnacle_emerge": _barnacle_emerge,
		"barnacle_charge": _barnacle_charge,
		"barnacle_shot": _barnacle_shot,
		"barnacle_death": _barnacle_death,
	}


## The charge-up's length from the turret's tuning (0.75 s if it can't be read).
static func charge_time() -> float:
	var t: Resource = load(TUNING_PATH) if ResourceLoader.exists(TUNING_PATH) else null
	return float(t.get("charge_time")) if t != null and t.get("charge_time") != null else 0.75


## Out of the hatch: a dull metal clunk, a rubbery pop as the dome comes out, and a servo chirp rising.
func _barnacle_emerge() -> PackedFloat32Array:
	var rng := _rng(1101)
	var b := DSP.buffer(0.5)
	DSP.mix(b, DSP.metal_hit(0.25, 210.0, 0.08, rng), 0.0, 0.55)
	var pop := DSP.osc(0.12, func(u: float) -> float: return DSP.sweep(140.0, 420.0, u), &"sine")
	DSP.envelope(pop, 0.002, 0.05)
	DSP.mix(b, pop, 0.03, 0.9)
	var servo := DSP.osc(0.26, func(u: float) -> float: return DSP.sweep(520.0, 1350.0, u * u), &"square")
	DSP.filter(servo, &"lowpass", 3200.0)
	DSP.shape(servo, 0.02, 0.06)
	DSP.mix(b, servo, 0.12, 0.22)
	DSP.crush(b, 9, 22000.0)
	return b


## The warning: an FM whine climbing from 220 Hz to 1.4 kHz (the cyborg's runs 320 Hz to 2.2 kHz), a
## fourth above it, bubbling (a wobble that speeds up from 7 to 30 Hz) and swelling over the charge-up.
func _barnacle_charge() -> PackedFloat32Array:
	var d: float = charge_time() + 0.03
	var b := DSP.fm(d, func(u: float) -> float: return DSP.sweep(220.0, 1400.0, u), 1.5,
		func(u: float) -> float: return 1.0 + 1.6 * u)
	var fourth := DSP.fm(d, func(u: float) -> float: return DSP.sweep(293.0, 1870.0, u), 1.5,
		func(u: float) -> float: return 0.6 + u)
	DSP.mix(b, fourth, 0.0, 0.3)
	var n: int = b.size()
	var phase: float = 0.0
	for i: int in n:
		var u: float = float(i) / n
		phase += lerpf(7.0, 30.0, u) / RATE
		# A bubbling wobble: rounder than the cyborg's pulse.
		var bubble: float = 0.5 + 0.5 * sin(TAU * phase)
		b[i] *= (0.5 + 0.5 * bubble * bubble) * (0.3 + 0.7 * u)
	DSP.filter(b, &"lowpass", 5200.0)
	DSP.shape(b, 0.01, 0.02)
	DSP.crush(b, 9, 22000.0)
	return b


## A bolt: a plosive thump and a rounder pulse-wave "pew" falling from 1.1 kHz, with a little crackle.
func _barnacle_shot() -> PackedFloat32Array:
	var rng := _rng(1103)
	var d: float = 0.24
	var pew := DSP.osc(d, func(u: float) -> float: return DSP.sweep(1100.0, 230.0, pow(u, 0.6)), &"square")
	DSP.filter(pew, &"lowpass", 2600.0)
	DSP.envelope(pew, 0.001, 0.08)
	var b := DSP.buffer(d)
	DSP.mix(b, pew, 0.0, 0.8)
	DSP.mix(b, DSP.kick(0.1, 160.0, 70.0, rng), 0.0, 0.5)
	var crackle := DSP.noise(0.08, rng)
	DSP.filter(crackle, &"bandpass", 2400.0, 1.2)
	DSP.envelope(crackle, 0.001, 0.025)
	DSP.mix(b, crackle, 0.0, 0.3)
	DSP.drive(b, 2.2)
	DSP.crush(b, 8, 16000.0)
	return b


## Defeated: a squeal falling away (the creature's yelp, the turret's servo dying), a pop and a fizzle.
func _barnacle_death() -> PackedFloat32Array:
	var rng := _rng(1104)
	var b := DSP.buffer(0.62)
	var squeal := DSP.fm(0.42, func(u: float) -> float: return DSP.sweep(1300.0, 160.0, pow(u, 0.7)), 2.0,
		func(u: float) -> float: return 2.0 - 1.4 * u)
	DSP.envelope(squeal, 0.003, 0.2)
	DSP.crush_sweep(squeal, 10.0, 5.0, 26000.0, 5000.0)
	DSP.mix(b, squeal, 0.0, 0.8)
	var pop := DSP.noise(0.05, rng)
	DSP.filter(pop, &"lowpass", 2200.0)
	DSP.envelope(pop, 0.0005, 0.018)
	DSP.mix(b, pop, 0.0, 1.0)
	DSP.mix(b, DSP.kick(0.14, 200.0, 75.0, rng), 0.0, 0.45)
	DSP.mix(b, _crackle(0.5, 22, 0.16, 3600.0, rng), 0.1, 0.45)
	return b
