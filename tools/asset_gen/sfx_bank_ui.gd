extends "res://tools/asset_gen/sfx_bank.gd"
## Menu, results and reward sounds: short, bright 16-bit blips in E major that sit on top of the music.
## Credits climb E major by denomination: bigger coins play more notes with a richer tail, so they can
## be told apart by ear. The bonus is a brassier fanfare, so it doesn't read as a coin.

const E2: float = 82.41
const A2: float = 110.0
const E4: float = 329.63
const E5: float = 659.26
const GS5: float = 830.61
const A5: float = 880.0
const B5: float = 987.77
const E6: float = 1318.51
const GS6: float = 1661.22
const A6: float = 1760.0
const B6: float = 1975.53
const E7: float = 2637.02


func sounds() -> Dictionary:
	return {
		"ui_move": _ui_move,
		"ui_select": _ui_select,
		"ui_back": _ui_back,
		"ui_buy": _ui_buy,
		"ui_error": _ui_error,
		"ui_equip": _ui_equip,
		"ui_unlock": _ui_unlock,
		"star": _star,
		"countdown": _countdown,
		"go": _go,
		"credit_1": _credit_1,
		"credit_5": _credit_5,
		"credit_25": _credit_25,
		"credit_100": _credit_100,
		"bonus": _bonus,
	}


## Focus moves: a tiny, soft pulse tick.
func _ui_move() -> PackedFloat32Array:
	var b := _blip(0.11, E6, 0.25, 0.016)
	DSP.mix(b, _blip(0.11, E5, 0.5, 0.012), 0.0, 0.5)
	DSP.filter(b, &"lowpass", 6000.0)
	DSP.crush(b, 8, 16000.0)
	return b


## Confirm: two hollow FM notes rising a fourth (B5, E6).
func _ui_select() -> PackedFloat32Array:
	var b := DSP.buffer(0.22)
	DSP.mix(b, _fm_note(0.08, B5, 2.0, 2.2, 0.6, 0.04), 0.0)
	DSP.mix(b, _fm_note(0.16, E6, 2.0, 2.2, 0.6, 0.06), 0.06)
	DSP.crush(b, 9, 24000.0)
	return b


## Back: two softer, rounder FM notes falling a fourth (E6, B5): the confirm sound undone.
func _ui_back() -> PackedFloat32Array:
	var b := DSP.buffer(0.2)
	DSP.mix(b, _fm_note(0.08, E6, 1.0, 1.2, 0.3, 0.035), 0.0)
	DSP.mix(b, _fm_note(0.14, B5, 1.0, 1.2, 0.3, 0.05), 0.06)
	DSP.filter(b, &"lowpass", 5000.0)
	DSP.crush(b, 9, 24000.0)
	return b


## Purchase: a coin run up to a ringing bell over a palm-muted guitar chug (ka-ching, metal style).
func _ui_buy() -> PackedFloat32Array:
	var rng := _rng(101)
	var b := DSP.buffer(0.7)
	var chug := DSP.power_chord(0.2, E2, true, rng)
	DSP.envelope(chug, 0.002, 0.07, 0.02)
	DSP.mix(b, chug, 0.0, 0.5)
	var run: Array[float] = [B5, E6, GS6]
	for k: int in run.size():
		DSP.mix(b, _blip(0.07, run[k], 0.25, 0.03), k * 0.045, 0.6)
	DSP.mix(b, Inst.fm_bell(E6, 0.55), 0.13, 0.9)
	DSP.mix(b, _sparkle(0.5, rng), 0.13, 0.25)
	DSP.crush(b, 10, 24000.0)
	return b


## Can't afford / locked: a double buzz on a tritone (D4 + G#4). Harsh and unmistakably "no".
func _ui_error() -> PackedFloat32Array:
	var b := DSP.buffer(0.3)
	for k: int in 2:
		var buzz := Inst.pulse(0.1, 293.66, 0.5)
		DSP.mix(buzz, Inst.pulse(0.1, 415.3, 0.5), 0.0, 0.8)
		DSP.shape(buzz, 0.002, 0.015)
		DSP.mix(b, buzz, k * 0.13)
	DSP.filter(b, &"lowpass", 4000.0)
	DSP.drive(b, 3.0)
	DSP.crush(b, 6, 11025.0)
	return b


## Equip toggle (on or off): a mechanical latch, click-clack, with a small blip.
func _ui_equip() -> PackedFloat32Array:
	var rng := _rng(102)
	var b := DSP.buffer(0.2)
	DSP.mix(b, DSP.metal_hit(0.05, 2600.0, 0.012, rng), 0.0, 0.8)
	DSP.mix(b, DSP.metal_hit(0.07, 1700.0, 0.018, rng), 0.05, 0.9)
	DSP.mix(b, _blip(0.1, GS5, 0.25, 0.03), 0.05, 0.4)
	DSP.crush(b, 9, 24000.0)
	return b


## A level or zone unlocks: a rising E major arpeggio on FM brass into a ringing power chord.
func _ui_unlock() -> PackedFloat32Array:
	var rng := _rng(103)
	var b := DSP.buffer(1.3)
	var notes: Array[float] = [E5, GS5, B5, E6]
	for k: int in notes.size():
		var last: bool = k == notes.size() - 1
		DSP.mix(b, Inst.fm_lead(notes[k], 0.8 if last else 0.09, 0.0, 0.3 if last else 0.0), k * 0.07, 0.8)
	var chord := DSP.power_chord(1.0, E2 * 2.0, false, rng)
	DSP.envelope(chord, 0.002, 0.5, 0.2)
	DSP.mix(b, chord, 0.21, 0.6)
	DSP.mix(b, _sparkle(0.9, rng), 0.21, 0.3)
	DSP.crush(b, 11, 24000.0)
	return b


## A star pops onto the results screen: a quick upward chirp, a bell and a sparkle.
func _star() -> PackedFloat32Array:
	var rng := _rng(104)
	var b := DSP.buffer(0.6)
	var chirp := DSP.fm(0.08, func(u: float) -> float: return DSP.sweep(700.0, 2600.0, u), 1.0,
		func(_u: float) -> float: return 1.5)
	DSP.envelope(chirp, 0.001, 0.05)
	DSP.mix(b, chirp, 0.0, 0.8)
	DSP.mix(b, Inst.fm_bell(B6 * 0.5, 0.5), 0.05, 0.9)
	DSP.mix(b, _sparkle(0.5, rng), 0.05, 0.35)
	DSP.crush(b, 10, 24000.0)
	return b


## Countdown tick (3, 2, 1): a firm square beep with a thump for weight.
func _countdown() -> PackedFloat32Array:
	var b := DSP.buffer(0.3)
	var beep := Inst.pulse(0.16, A5, 0.5)
	DSP.shape(beep, 0.002, 0.03)
	DSP.filter(beep, &"lowpass", 5000.0)
	DSP.mix(b, beep, 0.0, 0.8)
	DSP.mix(b, DSP.kick(0.2, 120.0, 55.0, _rng(105)), 0.0, 0.5)
	DSP.crush(b, 9, 24000.0)
	return b


## GO: the countdown beep an octave up and held, over a ringing A power chord, a kick and a crash.
func _go() -> PackedFloat32Array:
	var rng := _rng(106)
	var b := DSP.buffer(1.4)
	var beep := Inst.pulse(0.45, A6, 0.5)
	DSP.shape(beep, 0.002, 0.08)
	DSP.filter(beep, &"lowpass", 6000.0)
	DSP.mix(b, beep, 0.0, 0.6)
	var chord := DSP.power_chord(1.2, A2, false, rng)
	DSP.envelope(chord, 0.002, 0.6, 0.2)
	DSP.mix(b, chord, 0.0, 0.8)
	DSP.mix(b, DSP.kick(0.25, 150.0, 45.0, rng), 0.0, 0.7)
	DSP.mix(b, DSP.crash(1.2, rng), 0.0, 0.12)
	DSP.crush(b, 10, 24000.0)
	return b


# DESIGN-TBD: the credit denominations (1, 5, 25, 100) come from the build brief; the GDD (§7) only
# asks for several clearly distinguishable ones. A new denomination needs a sound here.
## A run of quick pulse notes up E major, with an FM bell on the last note for the bigger coins.
func _coin(seconds: float, notes: Array[float], bell: float, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := DSP.buffer(seconds)
	for k: int in notes.size():
		var last: bool = k == notes.size() - 1
		DSP.mix(b, _blip(0.12 if last else 0.05, notes[k], 0.25, 0.05 if last else 0.02), k * 0.04, 0.7)
	if bell > 0.0:
		DSP.mix(b, Inst.fm_bell(notes[notes.size() - 1], seconds - (notes.size() - 1) * 0.04), (notes.size() - 1) * 0.04, bell)
	DSP.crush(b, 9, 24000.0)
	return b


## 1 credit: a single high blip.
func _credit_1() -> PackedFloat32Array:
	return _coin(0.13, [E6], 0.0, _rng(107))


## 5 credits: two notes, a fourth up.
func _credit_5() -> PackedFloat32Array:
	return _coin(0.2, [B5, E6], 0.0, _rng(108))


## 25 credits: three notes and a bell.
func _credit_25() -> PackedFloat32Array:
	return _coin(0.4, [E6, GS6, B6], 0.5, _rng(109))


## 100 credits: four notes up to E7, a ringing bell chord, a low thump and a sparkle.
func _credit_100() -> PackedFloat32Array:
	var rng := _rng(110)
	var b := _coin(0.9, [E6, GS6, B6, E7], 0.6, rng)
	DSP.mix(b, Inst.fm_bell(B6, 0.7), 0.12, 0.4)
	DSP.mix(b, DSP.kick(0.25, 110.0, 55.0, rng), 0.0, 0.5)
	DSP.mix(b, _sparkle(0.7, rng), 0.12, 0.3)
	return b


## Score bonus popup: a short FM brass fanfare (E5 B5 E6, the last held with vibrato) and a sparkle.
func _bonus() -> PackedFloat32Array:
	var rng := _rng(111)
	var b := DSP.buffer(0.8)
	DSP.mix(b, Inst.fm_lead(E5, 0.07, 0.0, 0.0), 0.0, 0.8)
	DSP.mix(b, Inst.fm_lead(B5, 0.07, 0.0, 0.0), 0.08, 0.8)
	DSP.mix(b, Inst.fm_lead(E6, 0.5, B5, 0.3), 0.16, 0.8)
	DSP.mix(b, _sparkle(0.6, rng), 0.16, 0.25)
	DSP.crush(b, 11, 24000.0)
	return b
