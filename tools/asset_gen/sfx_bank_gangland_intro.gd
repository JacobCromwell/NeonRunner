extends "res://tools/asset_gen/sfx_bank.gd"
## Gangland intro's own sounds (GanglandIntro), in the same crunchy 16-bit style as the rest. None of them is a
## hazard's warning (the leader's charge-up and the Octodog's wind-up are the game's own warnings, before the attacks
## that follow them); like every sound effect, each is under 2.5 s. The voices are made-up syllables shouted through
## a cyborg's TV-head speaker, so they're heard as yelling and never understood.
##   gang_taunt      the left gang's cyborg yelling across at the other gang: a gruff, low bark of a phrase,
##                   rising to its stressed syllable and spat out at the end, through a blown-out speaker
##   gang_retort     the right gang's leader answering: smoother and higher, a sneering drawl that slides up and
##                   down, ending in a short buzzing laugh
##   gang_jeer       the left gang again, shorter and louder: two hard syllables and a long jeering howl
##   gang_rage       the left gang after the shot misses them: two voices roaring at once, ragged, under a
##                   speaker's crackle
##   octodog_tackle  the Octodog slamming into a cyborg: a heavy metal body hit, a wet slap of tentacles, a clatter
##                   of limbs and plating hitting the street


## Vowels: their first two formants (Hz).
const VOWELS: Dictionary = {
	&"a": Vector2(760.0, 1220.0), &"e": Vector2(500.0, 1800.0), &"i": Vector2(330.0, 2250.0),
	&"o": Vector2(520.0, 880.0), &"u": Vector2(340.0, 800.0), &"ae": Vector2(660.0, 1700.0),
}
## The phrases: syllables of [seconds, pitch from, pitch to (Hz), vowel from, vowel to, consonant before it (&"t",
## &"k", &"g", &"s", &"r" or none)]; a syllable with no vowel is a pause.
const TAUNT: Array = [[0.13, 112.0, 120.0, &"o", &"a", &"g"], [0.15, 118.0, 126.0, &"e", &"ae", &"t"],
	[0.06, 0.0, 0.0, &"", &"", &""], [0.2, 134.0, 150.0, &"a", &"o", &"k"], [0.12, 128.0, 118.0, &"u", &"e", &"r"],
	[0.3, 140.0, 104.0, &"a", &"u", &"t"]]
const RETORT: Array = [[0.18, 168.0, 196.0, &"e", &"a", &"s"], [0.13, 190.0, 176.0, &"a", &"o", &"t"],
	[0.22, 182.0, 214.0, &"ae", &"e", &""], [0.07, 0.0, 0.0, &"", &"", &""], [0.15, 196.0, 170.0, &"o", &"u", &"k"],
	[0.34, 176.0, 140.0, &"a", &"o", &"r"]]
const JEER: Array = [[0.11, 124.0, 132.0, &"a", &"e", &"k"], [0.11, 136.0, 142.0, &"o", &"a", &"t"],
	[0.5, 150.0, 118.0, &"a", &"o", &"r"]]


func sounds() -> Dictionary:
	return {
		"gang_taunt": _taunt,
		"gang_retort": _retort,
		"gang_jeer": _jeer,
		"gang_rage": _rage,
		"octodog_tackle": _tackle,
	}


## The left gang's taunt: a gruff bark of a phrase (the chest's square an octave down, louder), through a cyborg's
## speaker.
func _taunt() -> PackedFloat32Array:
	var rng := _rng(2301)
	return _speaker(_syllables(TAUNT, 0.35, 0.45, rng), 9.0, rng)


## The leader's retort: a smoother, higher drawl, then a short buzzing laugh.
func _retort() -> PackedFloat32Array:
	var rng := _rng(2302)
	var phrase := _syllables(RETORT, 0.15, 0.6, rng)
	var b := DSP.buffer(DSP.seconds_of(phrase) + 0.45)
	DSP.mix(b, phrase)
	# The laugh: four quick "ha"s falling in pitch, each a breathy burst.
	var at: float = DSP.seconds_of(phrase) - 0.1
	for i: int in 4:
		var hz: float = 210.0 - 16.0 * i
		var ha := _syllable(0.09, hz, hz - 10.0, VOWELS[&"a"], VOWELS[&"ae"], &"", 0.1, rng)
		var breath := DSP.noise(0.05, rng)
		DSP.filter(breath, &"bandpass", 1800.0, 0.8)
		DSP.envelope(breath, 0.002, 0.02)
		DSP.mix(b, breath, at + i * 0.12, 0.5)
		DSP.mix(b, ha, at + i * 0.12 + 0.02, 0.8)
	return _speaker(b, 7.0, rng)


## The left gang's jeer: two hard syllables and a long howl.
func _jeer() -> PackedFloat32Array:
	var rng := _rng(2303)
	return _speaker(_syllables(JEER, 0.3, 0.5, rng), 10.0, rng)


## The left gang's rage: two voices roaring at once (one low, one a little higher, a beat behind), ragged with a wide
## vibrato, under the speakers' crackle.
func _rage() -> PackedFloat32Array:
	var rng := _rng(2304)
	var d: float = 1.3
	var b := DSP.buffer(d + 0.3)
	for v: int in 2:
		var lo: float = 96.0 if v == 0 else 128.0
		var roar := _voice(d - 0.15 * v, func(u: float) -> float: return lo * (1.0 + 0.35 * sin(PI * u)),
			Vector2(VOWELS[&"a"].x, VOWELS[&"o"].x), Vector2(VOWELS[&"a"].y, VOWELS[&"o"].y), 9.0, 0.9, rng)
		var chest := DSP.osc(d - 0.15 * v, func(u: float) -> float: return lo * 0.5 * (1.0 + 0.35 * sin(PI * u)), &"square")
		DSP.filter(chest, &"lowpass", 300.0)
		DSP.mix(roar, chest, 0.0, 0.45)
		DSP.adsr(roar, 0.06, 0.2, 0.85, 0.3)
		DSP.mix(b, roar, 0.15 * v, 0.8)
	DSP.mix(b, _crackle(d, 40, 5.0, 2400.0, rng), 0.0, 0.25)
	return _speaker(b, 11.0, rng)


## The Octodog slamming into a cyborg: a heavy body hit (a low thump and a dented metal clang), a wet slap of
## tentacles, then limbs and plating clattering on the street.
func _tackle() -> PackedFloat32Array:
	var rng := _rng(2305)
	var d: float = 1.1
	var b := DSP.buffer(d)
	var thump := DSP.kick(0.3, 140.0, 45.0, rng)
	DSP.mix(b, thump, 0.0, 1.2)
	var clang := DSP.metal_hit(0.45, 340.0, 0.12, rng)
	DSP.filter(clang, &"lowpass", 3200.0)
	DSP.mix(b, clang, 0.005, 0.7)
	var slap := DSP.noise(0.12, rng)
	DSP.filter_sweep(slap, &"bandpass", 1400.0, 500.0, 1.3)
	DSP.envelope(slap, 0.002, 0.04)
	DSP.mix(b, slap, 0.02, 0.8)
	# The clatter: a few smaller metal knocks as it hits the ground and skids.
	for i: int in 5:
		var at: float = 0.2 + 0.11 * i + rng.randf_range(-0.03, 0.03)
		var knock := DSP.metal_hit(0.12, rng.randf_range(600.0, 1500.0), 0.03, rng)
		DSP.mix(b, knock, at, 0.45 * exp(-0.35 * i))
	var scrape := DSP.noise(0.5, rng)
	DSP.filter(scrape, &"bandpass", 2200.0, 0.9)
	DSP.adsr(scrape, 0.03, 0.15, 0.5, 0.25)
	DSP.mix(b, scrape, 0.25, 0.2)
	DSP.drive(b, 2.0)
	DSP.crush(b, 10, 22000.0)
	return b


## The syllables of a phrase, one after another, with `tail` seconds of room after them; `chest` is how loud the
## square an octave down is (a gruffer voice louder).
func _syllables(parts: Array, tail: float, chest: float, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var total: float = tail
	for p: Array in parts:
		total += float(p[0])
	var b := DSP.buffer(total)
	var at: float = 0.0
	for p: Array in parts:
		var d: float = float(p[0])
		if StringName(p[3]) != &"":
			DSP.mix(b, _syllable(d, float(p[1]), float(p[2]), VOWELS[p[3]], VOWELS[p[4]], StringName(p[5]), chest, rng),
				at)
		at += d
	return b


## A syllable: a consonant's burst, hiss or roll, then the voiced vowel gliding between two vowels' formants as its
## pitch moves from `hz_from` to `hz_to`.
func _syllable(d: float, hz_from: float, hz_to: float, vowel_from: Vector2, vowel_to: Vector2, consonant: StringName,
		chest: float, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := DSP.buffer(d)
	var onset: float = 0.0
	match consonant:
		&"t", &"k", &"g":
			var burst := DSP.noise(0.03, rng)
			DSP.filter(burst, &"bandpass", {&"t": 2800.0, &"k": 1600.0, &"g": 900.0}[consonant], 1.2)
			DSP.envelope(burst, 0.001, 0.008)
			DSP.mix(b, burst, 0.0, 1.3)
			onset = 0.018
		&"s":
			var hiss := DSP.noise(0.07, rng)
			DSP.filter(hiss, &"highpass", 3600.0)
			DSP.shape(hiss, 0.01, 0.02)
			DSP.mix(b, hiss, 0.0, 0.7)
			onset = 0.05
		&"r":
			# A rolled r: the voice chopped a few times.
			var roll := DSP.osc(0.06, func(_u: float) -> float: return hz_from, &"saw")
			var m: int = roll.size()
			for i: int in m:
				roll[i] *= 0.5 + 0.5 * sin(TAU * 28.0 * float(i) / RATE)
			DSP.filter(roll, &"lowpass", 1400.0)
			DSP.mix(b, roll, 0.0, 0.5)
			onset = 0.045
	var v: float = maxf(d - onset, 0.03)
	var pitch := func(u: float) -> float: return lerpf(hz_from, hz_to, u)
	var voiced := _voice(v, pitch, Vector2(vowel_from.x, vowel_to.x), Vector2(vowel_from.y, vowel_to.y), 6.0, 0.35, rng)
	var low := DSP.osc(v, func(u: float) -> float: return float(pitch.call(u)) * 0.5, &"square")
	DSP.filter(low, &"lowpass", 320.0)
	DSP.mix(voiced, low, 0.0, chest)
	DSP.adsr(voiced, 0.012, 0.07, 0.85, minf(0.05, v * 0.3))
	DSP.mix(b, voiced, onset)
	return b


## A cyborg's TV-head speaker: a ring-modulated buzz, a narrow, blown-out band (overdriven by `drive`, bit-crushed),
## a little line hiss, and one short slap back off the street's walls.
func _speaker(dry: PackedFloat32Array, drive: float, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n: int = dry.size()
	for i: int in n:
		dry[i] *= 0.7 + 0.3 * sin(TAU * 73.0 * float(i) / RATE)
	DSP.filter(dry, &"highpass", 260.0)
	DSP.filter(dry, &"peaking", 1500.0, 0.9, 8.0)
	DSP.drive(dry, drive)
	DSP.filter(dry, &"lowpass", 3800.0)
	DSP.crush(dry, 8, 12000.0)
	var line := DSP.noise(DSP.seconds_of(dry), rng)
	DSP.filter(line, &"bandpass", 3000.0, 0.7)
	DSP.mix(dry, line, 0.0, 0.02)
	var wet := dry.duplicate()
	DSP.filter(wet, &"lowpass", 2000.0)
	var out := dry.duplicate()
	DSP.mix(out, wet, 0.09, 0.3)
	return out
