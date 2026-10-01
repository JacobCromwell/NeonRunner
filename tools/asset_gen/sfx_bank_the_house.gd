extends "res://tools/asset_gen/sfx_bank.gd"
## The House's sounds (GDD §10: "lights blazing and jingling. Loud, gaudy and a little ridiculous"), in
## the same crunchy 16-bit / heavy-metal style as the rest: a casino floor's bells, chimes and coin
## clatter on a machine the size of a building. Every warning has a character of its own (CLAUDE.md
## readability rules: each attack's own sound on top of the reel's ding that shows its symbol):
##   house_roll       its entrance: its treads' heavy rumble and clank under a jaunty slot jingle
##   house_lever      the spin's start (GDD §10: "yanks its giant lever"): a huge ratchet, then a clunk
##   house_spin       the reels whirring: a rattle of clicks under a rising whirr
##   house_ding       a reel stops on a symbol (GDD §10: "each with a ding"): a bright bell and a clunk
##   house_lock       a reel locked on 7 by a button: a rising two-bell chime and a sparkle, unlike the ding
##   house_button     a 7 button lights up on the route: a soft, bright bling
##   house_cherry     the cherry bombs' warning: a cartoon lob ("bloop") and the fuses' hiss (the falling
##                    whistle and the blast are the Floating Head's bombs': bomb_whistle, bomb_blast)
##   house_lightning  the rolled fence's warning: an electric zap and a buzzing crackle (the fence then
##                    crackles with its own fence_warning)
##   house_bar        the gold blocks' warning: a heavy metal ring and a falling, ringing whoosh
##   house_slam       the gold blocks slam down: a deep thud and a clanging ring
##   house_jackpot    JACKPOT: two-tone sirens wailing over a fanfare of bells
##   house_coins      the fountain: a cascade of coins tinkling and clattering
##   house_sag        it overloads and sags into the street: groaning metal and a hydraulic hiss
##   house_hit        the hopper stomped: a crunching crash, a burst of coins and its jingle dying away

const C5: float = 523.25
const E5: float = 659.26
const G5: float = 783.99
const C6: float = 1046.5
const E6: float = 1318.51
const G6: float = 1567.98
const C7: float = 2093.0


func sounds() -> Dictionary:
	return {
		"house_roll": _roll,
		"house_lever": _lever,
		"house_spin": _spin,
		"house_ding": _ding,
		"house_lock": _lock,
		"house_button": _button,
		"house_cherry": _cherry,
		"house_lightning": _lightning,
		"house_bar": _bar,
		"house_slam": _slam,
		"house_jackpot": _jackpot,
		"house_coins": _coins,
		"house_sag": _sag,
		"house_hit": _hit,
	}


## A jaunty slot-machine jingle: a pulse arpeggio climbing through `notes`, `step` apart.
func _jingle(notes: Array, step: float, duty: float) -> PackedFloat32Array:
	var b := DSP.buffer(step * notes.size() + 0.3)
	for k: int in notes.size():
		DSP.mix(b, _blip(0.16, float(notes[k]), duty, 0.06), step * k, 0.6)
	return b


## Coins: `count` small metallic tinks scattered over `seconds`, thinning out.
func _tinks(seconds: float, count: int, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := DSP.buffer(seconds)
	for k: int in count:
		var at: float = seconds * pow(rng.randf(), 1.6) * 0.85
		var hz: float = rng.randf_range(2600.0, 5200.0)
		var tink := _fm_note(0.12, hz, 1.41, 2.4, 0.4, 0.035)
		DSP.mix(b, tink, at, rng.randf_range(0.25, 0.7) * exp(-at / (seconds * 0.6)))
	return b


## Its entrance: tread rumble and clank under a slot jingle.
func _roll() -> PackedFloat32Array:
	var rng := _rng(601)
	var d: float = 2.4
	var b := DSP.buffer(d)
	var rumble := DSP.noise(d, rng)
	DSP.filter(rumble, &"lowpass", 140.0, 0.9)
	DSP.adsr(rumble, 0.4, 0.4, 0.8, 0.6)
	DSP.mix(b, rumble, 0.0, 2.0)
	var engine := DSP.osc(d, func(u: float) -> float: return 46.0 + 6.0 * u, &"saw")
	DSP.filter(engine, &"lowpass", 300.0)
	DSP.drive(engine, 2.2)
	DSP.adsr(engine, 0.3, 0.3, 0.7, 0.6)
	DSP.mix(b, engine, 0.0, 0.5)
	# The treads' links clanking.
	var t: float = 0.05
	while t < d - 0.2:
		DSP.mix(b, DSP.metal_hit(0.12, rng.randf_range(180.0, 240.0), 0.03, rng), t, 0.22)
		t += 0.13
	DSP.mix(b, _jingle([C5, E5, G5, C6, E6, G6, C7, G6, C7], 0.085, 0.25), 0.45, 0.85)
	DSP.mix(b, Inst.fm_bell(C7, 0.9), 1.25, 0.6)
	DSP.crush(b, 10, 22000.0)
	return b


## The lever: a big ratchet and a heavy clunk at the bottom of its pull.
func _lever() -> PackedFloat32Array:
	var rng := _rng(602)
	var b := DSP.buffer(0.65)
	for k: int in 9:
		var click := DSP.metal_hit(0.06, 900.0 + 60.0 * k, 0.012, rng)
		DSP.mix(b, click, 0.02 + 0.037 * k, 0.4)
	DSP.mix(b, DSP.metal_hit(0.4, 110.0, 0.12, rng), 0.36, 0.9)
	DSP.mix(b, DSP.kick(0.25, 90.0, 45.0, rng), 0.36, 0.7)
	DSP.drive(b, 1.6)
	DSP.crush(b, 10, 22000.0)
	return b


## The reels whirring: clicks that speed up under a rising whirr, fading as the reels slow.
func _spin() -> PackedFloat32Array:
	var rng := _rng(603)
	var d: float = 1.7
	var b := DSP.buffer(d)
	var whirr := DSP.noise(d, rng)
	DSP.filter_sweep(whirr, &"bandpass", 500.0, 1400.0, 2.0)
	DSP.adsr(whirr, 0.15, 0.3, 0.7, 0.8)
	DSP.mix(b, whirr, 0.0, 0.5)
	var hum := DSP.osc(d, func(u: float) -> float: return DSP.sweep(90.0, 160.0, minf(u * 2.0, 1.0)), &"square")
	DSP.filter(hum, &"lowpass", 600.0)
	DSP.adsr(hum, 0.1, 0.3, 0.6, 0.8)
	DSP.mix(b, hum, 0.0, 0.18)
	var t: float = 0.0
	var gap: float = 0.07
	while t < d - 0.1:
		DSP.mix(b, DSP.metal_hit(0.03, 2200.0, 0.006, rng), t, 0.35 * (1.0 - t / d))
		t += gap
		gap = maxf(gap * 0.93, 0.028)
	DSP.crush(b, 10, 22000.0)
	return b


## A reel stops on its symbol: a bright bell over a clunk.
func _ding() -> PackedFloat32Array:
	var rng := _rng(604)
	var b := DSP.buffer(0.55)
	DSP.mix(b, DSP.metal_hit(0.18, 260.0, 0.04, rng), 0.0, 0.6)
	DSP.mix(b, Inst.fm_bell(E6, 0.5), 0.01, 0.9)
	DSP.crush(b, 10, 24000.0)
	return b


## A reel locked on 7: a rising two-bell chime and a sparkle (never mistaken for the plain ding).
func _lock() -> PackedFloat32Array:
	var rng := _rng(605)
	var b := DSP.buffer(0.75)
	DSP.mix(b, DSP.metal_hit(0.16, 300.0, 0.03, rng), 0.0, 0.4)
	DSP.mix(b, Inst.fm_bell(G6, 0.5), 0.0, 0.8)
	DSP.mix(b, Inst.fm_bell(C7, 0.6), 0.09, 0.8)
	DSP.mix(b, _sparkle(0.55, rng), 0.09, 0.35)
	DSP.crush(b, 10, 24000.0)
	return b


## A 7 button lights up: a soft, bright bling.
func _button() -> PackedFloat32Array:
	var b := DSP.buffer(0.4)
	DSP.mix(b, _blip(0.12, G6, 0.5, 0.05), 0.0, 0.45)
	DSP.mix(b, _blip(0.2, C7, 0.5, 0.08), 0.06, 0.4)
	DSP.crush(b, 11, 24000.0)
	return b


## The cherry bombs' warning: a cartoon lob and the fuses' hiss.
func _cherry() -> PackedFloat32Array:
	var rng := _rng(606)
	var b := DSP.buffer(0.95)
	var bloop := DSP.osc(0.28, func(u: float) -> float: return DSP.sweep(220.0, 880.0, u), &"square")
	DSP.filter(bloop, &"lowpass", 2600.0)
	DSP.envelope(bloop, 0.004, 0.12, 0.02)
	DSP.mix(b, bloop, 0.0, 0.7)
	var pop := DSP.noise(0.05, rng)
	DSP.filter(pop, &"bandpass", 1600.0, 1.5)
	DSP.envelope(pop, 0.001, 0.015)
	DSP.mix(b, pop, 0.0, 1.2)
	DSP.mix(b, DSP.kick(0.15, 140.0, 70.0, rng), 0.0, 0.5)
	var fuse := DSP.noise(0.8, rng)
	DSP.filter(fuse, &"bandpass", 6200.0, 2.5)
	DSP.adsr(fuse, 0.05, 0.1, 0.7, 0.2)
	DSP.mix(b, fuse, 0.12, 0.35)
	DSP.mix(b, _crackle(0.8, 30, 0.6, 4500.0, rng), 0.12, 0.4)
	DSP.crush(b, 10, 22000.0)
	return b


## The rolled fence's warning: an electric zap and a buzzing crackle.
func _lightning() -> PackedFloat32Array:
	var rng := _rng(607)
	var b := DSP.buffer(0.8)
	var zap := DSP.osc(0.22, func(u: float) -> float: return DSP.sweep(2400.0, 140.0, u), &"saw")
	DSP.envelope(zap, 0.001, 0.08, 0.02)
	DSP.mix(b, zap, 0.0, 0.6)
	var buzz := DSP.osc(0.7, func(u: float) -> float: return 120.0 + 4.0 * sin(u * 60.0), &"square")
	DSP.filter(buzz, &"lowpass", 2400.0)
	DSP.adsr(buzz, 0.02, 0.2, 0.5, 0.25)
	DSP.mix(b, buzz, 0.05, 0.3)
	DSP.mix(b, _crackle(0.75, 50, 0.4, 3500.0, rng), 0.0, 0.9)
	DSP.drive(b, 1.8)
	DSP.crush(b, 9, 22000.0)
	return b


## The gold blocks' warning: a heavy metal ring and a falling, ringing whoosh.
func _bar() -> PackedFloat32Array:
	var rng := _rng(608)
	var b := DSP.buffer(1.05)
	DSP.mix(b, DSP.metal_hit(0.7, 155.0, 0.35, rng), 0.0, 0.7)
	DSP.mix(b, _whoosh(0.9, 2600.0, 500.0, 1.4, rng), 0.12, 0.6)
	var fall := DSP.osc(0.85, func(u: float) -> float: return DSP.sweep(1500.0, 600.0, u))
	DSP.envelope(fall, 0.05, 0.6, 0.05)
	DSP.mix(b, fall, 0.15, 0.25)
	DSP.crush(b, 10, 22000.0)
	return b


## The gold blocks slam down: a deep thud and a clanging ring.
func _slam() -> PackedFloat32Array:
	var rng := _rng(609)
	var b := _boom(0.8, 110.0, 38.0, 0.18, rng)
	DSP.mix(b, DSP.metal_hit(0.7, 196.0, 0.28, rng), 0.0, 0.75)
	DSP.mix(b, DSP.metal_hit(0.5, 293.0, 0.18, rng), 0.01, 0.4)
	DSP.mix(b, _crackle(0.5, 30, 0.2, 2000.0, rng), 0.0, 0.5)
	DSP.crush(b, 9, 20000.0)
	return b


## JACKPOT: two-tone sirens wailing over a fanfare of bells.
func _jackpot() -> PackedFloat32Array:
	var rng := _rng(610)
	var d: float = 2.6
	var b := DSP.buffer(d)
	var siren := DSP.osc(d, func(u: float) -> float: return 880.0 if fmod(u * d * 2.2, 1.0) < 0.5 else 660.0, &"square")
	DSP.filter(siren, &"lowpass", 3000.0)
	DSP.adsr(siren, 0.05, 0.2, 0.8, 0.4)
	DSP.mix(b, siren, 0.0, 0.3)
	var wail := DSP.osc(d, func(u: float) -> float: return 700.0 + 350.0 * sin(u * d * TAU * 0.9), &"triangle")
	DSP.adsr(wail, 0.1, 0.2, 0.8, 0.5)
	DSP.mix(b, wail, 0.0, 0.25)
	var bells: Array = [C6, E6, G6, C7, G6, C7, E6, G6, C7]
	for k: int in bells.size():
		DSP.mix(b, Inst.fm_bell(float(bells[k]), 0.5), 0.1 + 0.16 * k, 0.55)
	DSP.mix(b, _sparkle(2.0, rng), 0.2, 0.35)
	DSP.crush(b, 10, 24000.0)
	return b


## The fountain: a cascade of coins.
func _coins() -> PackedFloat32Array:
	var rng := _rng(611)
	var b := DSP.buffer(1.7)
	DSP.mix(b, _tinks(1.7, 70, rng), 0.0, 1.0)
	var rush := DSP.noise(1.2, rng)
	DSP.filter(rush, &"highpass", 3500.0)
	DSP.adsr(rush, 0.05, 0.3, 0.4, 0.6)
	DSP.mix(b, rush, 0.0, 0.2)
	DSP.crush(b, 10, 24000.0)
	return b


## It overloads and sags: groaning metal and a hydraulic hiss.
func _sag() -> PackedFloat32Array:
	var rng := _rng(612)
	var d: float = 1.3
	var b := DSP.buffer(d)
	var groan := DSP.osc(d, func(u: float) -> float: return DSP.sweep(220.0, 70.0, u) * (1.0 + 0.04 * sin(u * 70.0)), &"saw")
	DSP.filter(groan, &"bandpass", 500.0, 2.5)
	DSP.drive(groan, 2.5)
	DSP.adsr(groan, 0.05, 0.3, 0.7, 0.4)
	DSP.mix(b, groan, 0.0, 0.6)
	var hiss := DSP.noise(d, rng)
	DSP.filter(hiss, &"highpass", 2500.0)
	DSP.adsr(hiss, 0.02, 0.4, 0.4, 0.6)
	DSP.mix(b, hiss, 0.05, 0.45)
	DSP.mix(b, DSP.metal_hit(0.6, 90.0, 0.25, rng), 0.9, 0.7)
	DSP.crush(b, 10, 22000.0)
	return b


## The hopper stomped: a crunching crash, a burst of coins and its jingle dying away.
func _hit() -> PackedFloat32Array:
	var rng := _rng(613)
	var b := DSP.buffer(1.5)
	DSP.mix(b, DSP.crash(0.9, rng), 0.0, 0.6)
	DSP.mix(b, DSP.metal_hit(0.8, 130.0, 0.3, rng), 0.0, 0.9)
	DSP.mix(b, DSP.kick(0.3, 100.0, 40.0, rng), 0.0, 0.8)
	DSP.mix(b, _tinks(1.2, 40, rng), 0.05, 0.7)
	var down: Array = [C7, G6, E6, C6, G5, E5, C5]
	for k: int in down.size():
		DSP.mix(b, _blip(0.12, float(down[k]) * (1.0 - 0.02 * k), 0.25, 0.05), 0.25 + 0.1 * k, 0.4)
	DSP.drive(b, 1.5)
	DSP.crush(b, 9, 22000.0)
	return b
