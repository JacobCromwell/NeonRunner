extends "res://tools/asset_gen/sfx_bank.gd"
## Power-ups, weapons and protective items: the dash, slow time, lasers and missiles, hits and stomps,
## the armor, shield, grapple hook and revive, and the pickups that bring them during a fight.

const E2: float = 82.41
const E4: float = 329.63
const B4: float = 493.88
const E5: float = 659.26
const GS5: float = 830.61
const B5: float = 987.77
const E6: float = 1318.51
const GS6: float = 1661.22
const B6: float = 1975.53
const A6: float = 1760.0


func sounds() -> Dictionary:
	return {
		"armor_break": _armor_break,
		"shield_break": _shield_break,
		"grapple": _grapple,
		"revive": _revive,
		"pickup": _pickup,
		"pickup_appear": _pickup_appear,
		"dash": _dash,
		"dash_ready": _dash_ready,
		"slow_time_on": _slow_time_on,
		"slow_time_off": _slow_time_off,
		"laser_fire": _laser_fire,
		"missile_fire": _missile_fire,
		"missile_explode": _missile_explode,
		"enemy_hit": _enemy_hit,
		"stomp": _stomp,
	}


## Armor breaks: metal plates shattering off. A crunchy impact, scattered clanks, rattling debris.
func _armor_break() -> PackedFloat32Array:
	var rng := _rng(201)
	var b := DSP.buffer(0.8)
	DSP.mix(b, DSP.kick(0.25, 150.0, 60.0, rng), 0.0, 0.8)
	var crunch := DSP.noise(0.15, rng)
	DSP.filter(crunch, &"bandpass", 1800.0, 0.8)
	DSP.envelope(crunch, 0.001, 0.04)
	DSP.mix(b, crunch, 0.0, 0.9)
	for k: int in 7:
		var at: float = 0.25 * pow(rng.randf(), 1.5)
		DSP.mix(b, DSP.metal_hit(0.35, rng.randf_range(900.0, 3200.0), rng.randf_range(0.05, 0.15), rng), at,
			rng.randf_range(0.3, 0.6))
	for k: int in 20:
		var at: float = 0.15 + 0.55 * pow(rng.randf(), 2.0)
		DSP.mix(b, DSP.metal_hit(0.03, rng.randf_range(4000.0, 6500.0), 0.008, rng), at, 0.25 * (1.0 - at))
	DSP.drive(b, 2.0)
	DSP.crush(b, 9, 20000.0)
	return b


## Shield breaks: an energy bubble shattering. Glassy FM shards, a falling zap and a bit-crushed power-down.
func _shield_break() -> PackedFloat32Array:
	var rng := _rng(202)
	var b := DSP.buffer(0.9)
	for k: int in 10:
		var hz: float = rng.randf_range(1800.0, 5200.0)
		var shard := DSP.fm(0.3, func(_u: float) -> float: return hz, 3.7, func(u: float) -> float: return 2.0 * exp(-u * 6.0))
		DSP.envelope(shard, 0.001, rng.randf_range(0.04, 0.12))
		DSP.mix(b, shard, rng.randf_range(0.0, 0.18), rng.randf_range(0.2, 0.45))
	var zap := DSP.fm(0.6, func(u: float) -> float: return DSP.sweep(2400.0, 120.0, u), 2.0,
		func(u: float) -> float: return 4.0 * (1.0 - u) + 0.5)
	DSP.envelope(zap, 0.002, 0.25)
	DSP.mix(b, zap, 0.0, 0.8)
	DSP.crush_sweep(b, 12.0, 5.0, 32000.0, 4000.0)
	return b


## Grapple hook: it fires (a whip-crack whoosh with the chain rattling out), bites (clunk), and the
## winch yanks the player up.
func _grapple() -> PackedFloat32Array:
	var rng := _rng(203)
	var b := DSP.buffer(0.95)
	var whip := DSP.noise(0.18, rng)
	DSP.filter_sweep(whip, &"bandpass", 800.0, 6000.0, 2.0)
	DSP.envelope(whip, 0.005, 0.07)
	DSP.mix(b, whip, 0.0, 0.8)
	for k: int in 14:
		var at: float = 0.02 + k * 0.02 + rng.randf_range(-0.005, 0.005)
		DSP.mix(b, DSP.metal_hit(0.03, rng.randf_range(3000.0, 4500.0), 0.008, rng), at, 0.35)
	DSP.mix(b, DSP.metal_hit(0.3, 260.0, 0.08, rng), 0.3, 1.0)
	DSP.mix(b, DSP.kick(0.15, 140.0, 70.0, rng), 0.3, 0.6)
	var winch := DSP.osc(0.55, func(u: float) -> float: return DSP.sweep(90.0, 260.0, u), &"saw")
	DSP.filter(winch, &"lowpass", 1800.0)
	DSP.drive(winch, 3.0)
	DSP.shape(winch, 0.02, 0.1)
	DSP.mix(b, winch, 0.34, 0.5)
	DSP.crush(b, 9, 20000.0)
	return b


## Revive: a second chance. A reversed cymbal swells into a rising FM brass arpeggio and a ringing
## E power chord.
func _revive() -> PackedFloat32Array:
	var rng := _rng(204)
	var b := DSP.buffer(2.0)
	var swell := DSP.crash(0.6, rng)
	swell.reverse()
	DSP.mix(b, swell, 0.0, 0.35)
	var notes: Array[float] = [E4, B4, E5, GS5, B5]
	for k: int in notes.size():
		var last: bool = k == notes.size() - 1
		DSP.mix(b, Inst.fm_lead(notes[k], 0.9 if last else 0.12, 0.0, 0.3 if last else 0.0), 0.45 + k * 0.08, 0.7)
	var chord := DSP.power_chord(1.3, E2, false, rng)
	DSP.envelope(chord, 0.002, 0.7, 0.3)
	DSP.mix(b, chord, 0.77, 0.7)
	DSP.mix(b, DSP.crash(1.0, rng), 0.77, 0.12)
	DSP.mix(b, DSP.kick(0.25, 150.0, 45.0, rng), 0.77, 0.6)
	DSP.crush(b, 11, 24000.0)
	return b


## A pickup taken (GDD §10): a protective item snaps on. A quick FM swoop up, a mechanical latch
## (clack-clunk) and a hollow two-note chime rising a fourth (B5, E6) over a small power chord and a
## sparkle. Heavier and more metal than a credit's pulse blips, so the two never sound alike.
func _pickup() -> PackedFloat32Array:
	var rng := _rng(213)
	var b := DSP.buffer(0.75)
	var swoop := DSP.fm(0.12, func(u: float) -> float: return DSP.sweep(380.0, 1500.0, u), 1.0,
		func(u: float) -> float: return 2.5 * (1.0 - u) + 0.4)
	DSP.envelope(swoop, 0.002, 0.06)
	DSP.mix(b, swoop, 0.0, 0.55)
	DSP.mix(b, DSP.metal_hit(0.06, 2300.0, 0.012, rng), 0.09, 0.7)
	DSP.mix(b, DSP.metal_hit(0.12, 900.0, 0.03, rng), 0.12, 0.8)
	DSP.mix(b, DSP.kick(0.15, 170.0, 80.0, rng), 0.12, 0.45)
	DSP.mix(b, _fm_note(0.3, B5, 2.0, 2.4, 0.5, 0.08), 0.14, 0.6)
	DSP.mix(b, _fm_note(0.55, E6, 2.0, 2.4, 0.5, 0.16), 0.22, 0.65)
	var chord := DSP.power_chord(0.45, E2 * 2.0, false, rng)
	DSP.envelope(chord, 0.002, 0.18, 0.1)
	DSP.mix(b, chord, 0.12, 0.3)
	DSP.mix(b, _sparkle(0.45, rng), 0.2, 0.2)
	DSP.crush(b, 10, 24000.0)
	return b


## A pickup appears ahead (GDD §10): a soft shimmer. A reversed swell into a quiet high bell pair
## (E6, B6) with a sparkle: friendly, nothing like an attack's warning.
func _pickup_appear() -> PackedFloat32Array:
	var rng := _rng(214)
	var b := DSP.buffer(0.8)
	var swell := DSP.crash(0.35, rng)
	swell.reverse()
	DSP.filter(swell, &"highpass", 3000.0)
	DSP.mix(b, swell, 0.0, 0.25)
	DSP.mix(b, Inst.fm_bell(E6, 0.5), 0.3, 0.45)
	DSP.mix(b, Inst.fm_bell(B6, 0.45), 0.36, 0.3)
	DSP.mix(b, _fm_note(0.3, GS6, 3.5, 1.5, 0.3, 0.1), 0.33, 0.2)
	DSP.mix(b, _sparkle(0.45, rng), 0.3, 0.3)
	DSP.crush(b, 11, 24000.0)
	return b


## Juggernaut dash: a heavy burst. A kick, a roaring low rumble, a fast whoosh and a muted power chord.
func _dash() -> PackedFloat32Array:
	var rng := _rng(205)
	var b := DSP.buffer(0.65)
	DSP.mix(b, DSP.kick(0.3, 130.0, 42.0, rng), 0.0, 0.9)
	var roar := DSP.noise(0.6, rng)
	DSP.filter_sweep(roar, &"lowpass", 1200.0, 250.0, 1.2)
	DSP.envelope(roar, 0.005, 0.2)
	DSP.drive(roar, 4.0)
	DSP.mix(b, roar, 0.0, 0.8)
	DSP.mix(b, _whoosh(0.4, 600.0, 4000.0, 1.5, rng), 0.0, 0.7)
	var hit := DSP.power_chord(0.3, E2, true, rng)
	DSP.envelope(hit, 0.002, 0.1, 0.05)
	DSP.mix(b, hit, 0.0, 0.6)
	DSP.crush(b, 9, 18000.0)
	return b


## Dash ready (cooldown over): a light reload clack-clack and a bright FM chime.
func _dash_ready() -> PackedFloat32Array:
	var rng := _rng(206)
	var b := DSP.buffer(0.4)
	DSP.mix(b, DSP.metal_hit(0.05, 1400.0, 0.012, rng), 0.0, 0.6)
	DSP.mix(b, DSP.metal_hit(0.06, 2100.0, 0.015, rng), 0.05, 0.7)
	DSP.mix(b, _fm_note(0.3, A6, 3.0, 2.5, 0.4, 0.09), 0.1, 0.7)
	DSP.mix(b, _fm_note(0.3, A6 * 1.5, 3.0, 2.0, 0.4, 0.07), 0.1, 0.3)
	DSP.crush(b, 9, 24000.0)
	return b


## A tape-speed sweep: a chord (E4 B4 E5) whose pitch goes from `from_ratio` to `to_ratio` of normal
## while its wobble goes from `wobble_from` to `wobble_to` Hz.
func _tape(seconds: float, from_ratio: float, to_ratio: float, wobble_from: float, wobble_to: float) -> PackedFloat32Array:
	var b := DSP.buffer(seconds)
	for hz: float in [E4, B4, E5]:
		var voice := DSP.fm(seconds, func(u: float) -> float: return hz * DSP.sweep(from_ratio, to_ratio, u), 1.0,
			func(_u: float) -> float: return 1.5)
		DSP.mix(b, voice, 0.0, 0.3)
	var n: int = b.size()
	var phase: float = 0.0
	for i: int in n:
		phase += lerpf(wobble_from, wobble_to, float(i) / n) / RATE
		b[i] *= 0.65 + 0.35 * sin(TAU * phase)
	return b


## Slow time on: a tape stop. The chord slides down an octave and its wobble slows, over a deep whoom.
func _slow_time_on() -> PackedFloat32Array:
	var rng := _rng(207)
	var b := _tape(0.9, 1.0, 0.5, 14.0, 3.0)
	DSP.shape(b, 0.01, 0.2)
	DSP.mix(b, _boom(0.9, 70.0, 35.0, 0.35, rng), 0.0, 0.7)
	DSP.crush_sweep(b, 12.0, 8.0, 32000.0, 12000.0)
	return b


## Slow time off: the tape starts again. The chord slides back up to pitch with a rising whoosh.
func _slow_time_off() -> PackedFloat32Array:
	var rng := _rng(208)
	var b := _tape(0.6, 0.5, 1.0, 3.0, 14.0)
	DSP.shape(b, 0.02, 0.12)
	DSP.mix(b, _whoosh(0.6, 300.0, 4000.0, 1.2, rng), 0.0, 0.6)
	DSP.crush_sweep(b, 8.0, 12.0, 12000.0, 32000.0)
	return b


## Player laser (weapon tiers 1–2): a clean, bright 16-bit "pew" that drops fast. Short, as it repeats.
func _laser_fire() -> PackedFloat32Array:
	var b := DSP.fm(0.14, func(u: float) -> float: return DSP.sweep(2600.0, 520.0, pow(u, 0.6)), 1.0,
		func(u: float) -> float: return 2.0 * (1.0 - u) + 0.3)
	DSP.envelope(b, 0.001, 0.05)
	DSP.crush(b, 8, 24000.0)
	return b


## Missile launch (weapon tiers 3–4): a thump, the ignition roar and a sizzling trail that flies off.
func _missile_fire() -> PackedFloat32Array:
	var rng := _rng(209)
	var b := DSP.buffer(0.55)
	DSP.mix(b, DSP.kick(0.2, 110.0, 50.0, rng), 0.0, 0.7)
	var ignition := DSP.noise(0.5, rng)
	DSP.filter_sweep(ignition, &"bandpass", 400.0, 3500.0, 0.9)
	DSP.envelope(ignition, 0.003, 0.18)
	DSP.drive(ignition, 3.0)
	DSP.mix(b, ignition, 0.0, 0.9)
	var sizzle := _crackle(0.5, 60, 0.3, 6000.0, rng)
	DSP.mix(b, sizzle, 0.03, 0.5)
	DSP.crush(b, 9, 20000.0)
	return b


## A missile hits: a mid-size explosion, smaller than a truck's.
func _missile_explode() -> PackedFloat32Array:
	return _explosion(0.9, 0.8, _rng(210))


## A weapon hit lands: a metallic tick and a crunch. Short, as it repeats a lot.
func _enemy_hit() -> PackedFloat32Array:
	var rng := _rng(211)
	var b := DSP.metal_hit(0.15, 1900.0, 0.025, rng)
	var crunch := DSP.noise(0.05, rng)
	DSP.filter(crunch, &"bandpass", 3000.0, 1.0)
	DSP.envelope(crunch, 0.0005, 0.012)
	DSP.mix(b, crunch, 0.0, 0.8)
	DSP.mix(b, DSP.kick(0.08, 200.0, 100.0, rng), 0.0, 0.4)
	DSP.crush(b, 7, 16000.0)
	return b


## Stomp kill: a heavy boot. A kick drum, crunching metal and a robotic squelch that drops away.
func _stomp() -> PackedFloat32Array:
	var rng := _rng(212)
	var b := DSP.buffer(0.45)
	DSP.mix(b, DSP.kick(0.3, 160.0, 45.0, rng), 0.0, 1.0)
	DSP.mix(b, DSP.metal_hit(0.3, 380.0, 0.07, rng), 0.0, 0.7)
	var crunch := DSP.noise(0.1, rng)
	DSP.filter(crunch, &"bandpass", 1500.0, 0.9)
	DSP.envelope(crunch, 0.001, 0.03)
	DSP.mix(b, crunch, 0.0, 1.5)
	var squelch := DSP.fm(0.25, func(u: float) -> float: return DSP.sweep(900.0, 120.0, u), 0.5,
		func(u: float) -> float: return 3.0 * (1.0 - u))
	DSP.envelope(squelch, 0.002, 0.1)
	DSP.mix(b, squelch, 0.02, 0.5)
	DSP.crush(b, 8, 16000.0)
	return b
