extends "res://tools/asset_gen/sfx_bank.gd"
## Mecha Guppy and Captain Cogs' sounds (GDD §10; tasks E5e-b2 and E5e-b3), in the game's 16-bit style. They play where
## they happen (RunWorld.play_sfx_at). The bombs' own warning is the Floating Head's (bomb_whistle, then bomb_blast, GDD
## §10: "warned like the Floating Head's"); these are the fight's own:
##   cogs_throw    Captain Cogs throws (each volley, the bait as it locks): the arm's whoosh, a clockwork ratchet in
##                 the mechanical arm, and a gruff pirate's "harr!"
##   cogs_aim      Captain Cogs takes aim (the bait's warning while its circle follows the runner, as long as
##                 MechaGuppyTuning.bait_seek: regenerate it when that changes): the clockwork arm's ratchet winding
##                 up, its clicks quickening, a brass servo whirring up, a catch as the circle locks (the throw follows)
##   guppy_rumble  the shark coming up (a bite's and a breach's warning): deep machinery grinding up from below, a
##                 rising mechanical whine and the water churning
##   guppy_bite    its jaws snapping shut: a huge steel clank, hydraulics hissing, timber and thatch crunching
##   guppy_clang   a bomb in its jaws (a hit): the bomb's crack and boom, a great steel clang ringing out, sparks
##                 crackling, the shark's machinery groaning


const TUNING_PATH: String = "res://data/bosses/beach_boss_tuning.tres"


func sounds() -> Dictionary:
	return {
		"cogs_throw": _throw,
		"cogs_aim": _aim,
		"guppy_rumble": _rumble,
		"guppy_bite": _bite,
		"guppy_clang": _clang,
	}


## A throw: a quick whoosh of the arm, a clockwork ratchet (the mechanical arm), and a short gruff "harr!".
func _throw() -> PackedFloat32Array:
	var rng := _rng(2101)
	var d: float = 0.62
	var b := DSP.buffer(d)
	DSP.mix(b, _whoosh(0.32, 500.0, 2600.0, 1.4, rng), 0.0, 0.8)
	for k: int in 5:
		var tick := DSP.metal_hit(0.05, 1800.0 + 160.0 * k, 0.012, rng)
		DSP.mix(b, tick, 0.02 + 0.035 * k, 0.35)
	var harr := _voice(0.34, func(u: float) -> float: return DSP.sweep(150.0, 105.0, u), Vector2(680.0, 560.0),
		Vector2(1250.0, 1050.0), 7.0, 0.6, rng)
	DSP.drive(harr, 2.2)
	DSP.adsr(harr, 0.02, 0.08, 0.75, 0.12)
	DSP.mix(b, harr, 0.2, 0.9)
	DSP.crush(b, 10, 20000.0)
	return b


## Taking aim, as long as the bait's circle follows the runner (bait_seek): ratchet clicks quickening from 9 to 26 a
## second over a square servo whirring up from 380 to 1150 Hz (it carries on a phone's speaker), ending on a catch as the
## circle locks.
func _aim() -> PackedFloat32Array:
	var rng := _rng(2105)
	var d: float = _bait_seek()
	var b := DSP.buffer(d)
	var t: float = 0.0
	var k: int = 0
	while t < d - 0.05:
		DSP.mix(b, DSP.metal_hit(0.04, 2200.0 + 140.0 * float(k % 3), 0.01, rng), t, 0.34)
		t += 1.0 / lerpf(9.0, 26.0, t / d)
		k += 1
	var whir := DSP.osc(d, func(u: float) -> float: return DSP.sweep(380.0, 1150.0, u), &"square")
	DSP.filter(whir, &"bandpass", 900.0, 1.2)
	DSP.adsr(whir, 0.08, 0.1, 0.8, 0.04)
	DSP.mix(b, whir, 0.0, 0.3)
	DSP.mix(b, DSP.metal_hit(0.06, 1500.0, 0.015, rng), maxf(d - 0.06, 0.0), 0.6)
	DSP.crush(b, 10, 20000.0)
	return b


## The bait's aim (seconds: MechaGuppyTuning.bait_seek).
func _bait_seek() -> float:
	var t := load(TUNING_PATH) as MechaGuppyTuning
	return t.bait_seek if t != null else 0.6


## Coming up from below: a deep saw grinding up in pitch, a churning band of noise sweeping up (the water), a
## mechanical whine rising over it, swelling to the surface.
func _rumble() -> PackedFloat32Array:
	var rng := _rng(2102)
	var d: float = 1.25
	var b := DSP.buffer(d)
	var grind := DSP.osc(d, func(u: float) -> float: return DSP.sweep(38.0, 70.0, u), &"saw")
	DSP.mix(grind, DSP.osc(d, func(u: float) -> float: return DSP.sweep(41.0, 76.0, u), &"saw"), 0.0, 0.8)
	DSP.filter(grind, &"lowpass", 420.0)
	DSP.drive(grind, 2.6)
	DSP.adsr(grind, 0.35, 0.2, 0.85, 0.2)
	DSP.mix(b, grind, 0.0, 0.6)
	var churn := DSP.noise(d, rng)
	DSP.filter_sweep(churn, &"bandpass", 300.0, 2600.0, 1.4)
	DSP.adsr(churn, 0.45, 0.2, 0.85, 0.15)
	DSP.mix(b, churn, 0.0, 0.8)
	# The whine and the plates' clanks carry the warning on a phone's speaker, which can't play the grinding.
	var whine := DSP.osc(d, func(u: float) -> float: return DSP.sweep(260.0, 1300.0, u * u), &"square")
	DSP.filter(whine, &"bandpass", 1000.0, 1.0)
	DSP.adsr(whine, 0.5, 0.1, 0.9, 0.1)
	DSP.mix(b, whine, 0.0, 0.6)
	for k: int in 4:
		DSP.mix(b, DSP.metal_hit(0.22, 320.0 + 90.0 * k, 0.07, rng), 0.35 + 0.2 * k, 0.75)
	DSP.crush(b, 10, 18000.0)
	return b


## The snap: a huge low steel clank (the jaws meeting), a hydraulic hiss, timber and thatch crunching, a thud.
func _bite() -> PackedFloat32Array:
	var rng := _rng(2103)
	var d: float = 0.95
	var b := DSP.buffer(d)
	var clank := DSP.metal_hit(0.8, 92.0, 0.22, rng)
	DSP.mix(b, clank, 0.0, 1.0)
	DSP.mix(b, DSP.metal_hit(0.5, 240.0, 0.1, rng), 0.005, 0.6)
	DSP.mix(b, _boom(0.6, 90.0, 38.0, 0.14, rng), 0.0, 0.7)
	var hiss := DSP.noise(0.5, rng)
	DSP.filter(hiss, &"highpass", 3000.0)
	DSP.adsr(hiss, 0.01, 0.15, 0.4, 0.2)
	DSP.mix(b, hiss, 0.06, 0.25)
	DSP.mix(b, _crackle(0.8, 50, 0.25, 1600.0, rng), 0.02, 1.0)
	DSP.drive(b, 1.8)
	DSP.crush(b, 9, 18000.0)
	return b


## A hit: the bomb's crack and boom, a great steel clang ringing out over it, sparks crackling, and the shark's
## machinery groaning down.
func _clang() -> PackedFloat32Array:
	var rng := _rng(2104)
	var d: float = 1.5
	var b := _explosion(d, 0.8, rng)
	var ring := DSP.metal_hit(d, 176.0, 0.55, rng)
	DSP.mix(b, ring, 0.0, 1.1)
	DSP.mix(b, DSP.metal_hit(1.0, 523.0, 0.3, rng), 0.0, 0.55)
	DSP.mix(b, _crackle(1.0, 70, 0.3, 4200.0, rng), 0.05, 0.6)
	var groan := DSP.osc(0.9, func(u: float) -> float: return DSP.sweep(95.0, 52.0, u), &"saw")
	DSP.filter(groan, &"lowpass", 500.0)
	DSP.adsr(groan, 0.08, 0.2, 0.6, 0.3)
	DSP.mix(b, groan, 0.35, 0.5)
	DSP.crush(b, 10, 20000.0)
	return b
