extends RefCounted
## "Marketplace", Zone 3 (an open-air market, dusty and bustling: stalls and awnings, shops, casinos).
## Happy, bouncy ska-metal at 144 BPM in Bb major: a Mega Drive horn section in thirds over off-beat
## guitar chops and an organ bubble, a walking slap bass and a son clave, then a punk-polka chorus of
## ringing power chords. 24 bars = 40 s:
##   A  bars 1–8    ska verse: the horn theme in thirds (Bb Gm Eb F Bb Gm Eb–F Bb) over off-beat
##                  chops and organ, walking bass, clave, backbeat
##   B  bars 9–16   the chorus: open power chords in eighths (Eb F Dm Gm Eb F Bb F), a punk-polka beat
##                  (kick on the beat, snare off it), tambourine, a soaring horn hook in thirds
##   C  bars 17–20  breakdown: guitar stabs answered by the horns, organ chords, claps, a sixteenth
##                  build and a riser
##   D  bars 21–24  the theme's opening on lead guitar and horns over the chorus groove, fill back to A

const Song = preload("res://tools/asset_gen/music_song.gd")
const Inst = preload("res://tools/asset_gen/music_instruments.gd")
const DSP = preload("res://tools/asset_gen/sfx_dsp.gd")

## The horn theme (A; its first half again in D) and its second voice a third or sixth below.
const THEME: Array = [
	"D5 - F5 - Bb5 - - - A5 - G5 - F5 - - -",
	"G5 - - - - - F5 - D5 - - - Bb4 - C5 -",
	"Eb5 - G5 - Bb5 - - - G5 - Eb5 - G5 - - -",
	"F5 - - - A5 - - - C6 - - - - - - -",
	"D5 - F5 - Bb5 - - - A5 - G5 - F5 - - -",
	"G5 - - - - - F5 - D5 - - - Bb4 - D5 -",
	"Eb5 - - - G5 - - - F5 - - - A5 - - -",
	"Bb5 - - - - - - - - - - - . . . .",
]
const THEME_LOW: Array = [
	"Bb4 - D5 - F5 - - - F5 - Eb5 - D5 - - -",
	"Bb4 - - - - - D5 - Bb4 - - - G4 - A4 -",
	"G4 - Eb5 - G5 - - - Eb5 - Bb4 - Eb5 - - -",
	"C5 - - - F5 - - - A5 - - - - - - -",
	"Bb4 - D5 - F5 - - - F5 - Eb5 - D5 - - -",
	"Bb4 - - - - - D5 - Bb4 - - - G4 - Bb4 -",
	"G4 - - - Bb4 - - - A4 - - - C5 - - -",
	"D5 - - - - - - - - - - - . . . .",
]
## The chorus hook (B) and its second voice.
const HOOK: Array = [
	"G5 - - - - - - - Bb5 - - - G5 - - -",
	"A5 - - - - - - - C6 - - - A5 - F5 -",
	"F5 - - - - - - - A5 - - - F5 - D5 -",
	"G5 - - - - - - - - - - - D5 - F5 -",
	"G5 - - - - - - - Bb5 - - - Eb6 - - -",
	"D6 - - - C6 - - - - - - - A5 - - -",
	"Bb5 - - - - - - - F5 - - - Bb5 - D6 -",
	"C6 - - - - - - - - - - - . . . .",
]
const HOOK_LOW: Array = [
	"Eb5 - - - - - - - G5 - - - Eb5 - - -",
	"F5 - - - - - - - A5 - - - F5 - C5 -",
	"D5 - - - - - - - F5 - - - D5 - A4 -",
	"Bb4 - - - - - - - - - - - Bb4 - D5 -",
	"Eb5 - - - - - - - G5 - - - Bb5 - - -",
	"F5 - - - A5 - - - - - - - F5 - - -",
	"D5 - - - - - - - D5 - - - F5 - Bb5 -",
	"A5 - - - - - - - - - - - . . . .",
]
## The horns' answers to the guitar stabs in the breakdown (C).
const ANSWER: Array = [
	". . . . . . . . D5 - F5 - G5 - - -",
	". . . . . . . . Eb5 - G5 - Bb5 - - -",
	". . . . . . . . F5 - A5 - C6 - - -",
	"C6 - - - - - - - . . . . . . . .",
]
const ANSWER_LOW: Array = [
	". . . . . . . . Bb4 - D5 - Bb4 - - -",
	". . . . . . . . G4 - Eb5 - G5 - - -",
	". . . . . . . . A4 - F5 - A5 - - -",
	"A5 - - - - - - - . . . . . . . .",
]
const BASS_A: Array = [
	"Bb1 - - . D2 - - . F2 - - . A1 - - .",
	"G1 - - . Bb1 - - . D2 - - . F2 - - .",
	"Eb2 - - . G2 - - . Bb1 - - . E2 - - .",
	"F2 - - . A1 - - . C2 - - . A1 - - .",
	"Bb1 - - . D2 - - . F2 - - . A1 - - .",
	"G1 - - . Bb1 - - . D2 - - . F2 - - .",
	"Eb2 - - . G2 - - . F2 - - . A1 - - .",
	"Bb1 - - . D2 - - . F2 - - . D2 - - .",
]
const BASS_C: Array = [
	"G1 - - - . . G1 G1 . . Bb1 - D2 - F2 -",
	"Eb2 - - - . . Eb2 Eb2 . . G2 - Bb2 - G2 -",
	"F2 - - - . . F2 F2 . . A2 - C3 - A2 -",
	"F2 - F2 - F2 - F2 - F2 - F2 - F2 - F2 -",
]
## Chords per bar, half bars where a bar holds two.
const VERSE: Array = [["Bb"], ["Gm"], ["Eb"], ["F"], ["Bb"], ["Gm"], ["Eb", "F"], ["Bb"]]
const CHORUS: Array = ["Eb", "F", "Dm", "Gm", "Eb", "F", "Bb", "F"]
const BREAKDOWN: Array = ["Gm", "Eb", "F", "F"]
const TAG: Array = ["Bb", "Gm", "Eb", "F"]
## Guitar roots: the chops sit high (bright and light), the chorus chords lower.
const CHOP_ROOTS: Dictionary = {"Bb": "Bb3", "Gm": "G3", "Eb": "Eb3", "F": "F3"}
const CHORD_ROOTS: Dictionary = {"Bb": "Bb2", "Gm": "G2", "Eb": "Eb3", "F": "F3", "Dm": "D3"}
const BASS_ROOTS: Dictionary = {"Bb": "Bb1", "Gm": "G1", "Eb": "Eb2", "F": "F2", "Dm": "D2"}
## Organ voicings, around the middle of the keyboard.
const ORGAN_CHORDS: Dictionary = {
	"Bb": [58, 62, 65], "Gm": [55, 58, 62], "Eb": [55, 58, 63], "F": [57, 60, 65],
}


static func compose() -> Song:
	var song := Song.new(144.0, 24, 1441)
	song.sections = [[0, "A verse"], [8, "B chorus"], [16, "C breakdown"], [20, "D tag"]]
	_drums(song)
	_guitars(song)
	_bass(song)
	_organ(song)
	_horns(song)
	_fx(song)
	song.echo("horns", 3.0, 0.22, 2600.0, 0.16)
	song.echo("solo", 3.0, 0.25, 2200.0, 0.18)
	song.echo("keys", 2.0, 0.2, 1800.0, 0.12)
	song.mixdown({"drums": -10.0, "perc": -20.0, "bass": -12.5, "gtr": -11.5, "horns": -13.0,
		"solo": -14.0, "keys": -19.0, "fx": -21.0}, -16.0)
	return song


static func _drums(song: Song) -> void:
	var rng := song.rng
	var kick: Array = []
	var snare: Array = []
	var hat: Array = []
	for v: int in 3:
		kick.append(DSP.kick(0.3, 170.0, 52.0, rng))
		snare.append(DSP.snare(0.3, 235.0, 0.7, rng))
		hat.append(DSP.hat(0.06, 0.018, rng))
	var open_hat: Array = [DSP.hat(0.3, 0.09, rng), DSP.hat(0.3, 0.09, rng)]
	var crash: Array = [DSP.crash(1.4, rng), DSP.crash(1.4, rng)]
	var clap: Array = [_clap(rng), _clap(rng)]
	var tambourine: Array = [DSP.hat(0.14, 0.045, rng), DSP.hat(0.14, 0.045, rng)]
	var block: Array = [_woodblock(rng)]
	var toms: Array = [[DSP.tom(0.4, 230.0, rng)], [DSP.tom(0.4, 175.0, rng)], [DSP.tom(0.45, 130.0, rng)]]

	# A: ska: kick on 1 and 3, backbeat, hats on the beat and open on the off-beats, son clave (3-2).
	song.drum("drums", 0, "x.......x.......".repeat(7) + "x.......x.x.....", kick, 1.0)
	song.drum("drums", 0, "....x.......x...".repeat(7) + "....x.......xxXX", snare, 0.85)
	song.drum("drums", 0, "x...x...x...x...".repeat(7) + "x...x...x.......", hat, 0.35)
	song.drum("drums", 0, "..x...x...x...x.".repeat(7) + "..x...x.........", open_hat, 0.2)
	song.drum("perc", 0, ("x.....x.....x..." + "....x...x.......").repeat(4), block, 1.0)
	song.drum("drums", 0, "X", crash, 0.5)
	song.drum("drums", 4, "x", crash, 0.4)
	# B: punk polka: kick on every beat, snare on every off-beat, ride-like hats and tambourine.
	song.drum("drums", 8, "x...x...x...x...".repeat(7) + "x...x...x.x.x...", kick, 1.0)
	song.drum("drums", 8, "..x...x...x...x.".repeat(7) + "..x...x.x.x.xxXX", snare, 0.8)
	song.drum("drums", 8, "x.x.x.x.x.x.x.x.".repeat(7) + "x.x.x.x.........", hat, 0.3)
	song.drum("perc", 8, "xoxoxoxoxoxoxoxo".repeat(7) + "xoxoxoxo........", tambourine, 0.8)
	song.drum("drums", 8, "X", crash, 0.55)
	song.drum("drums", 12, "x", crash, 0.45)
	# C: half-time breakdown with claps, then a sixteenth build.
	song.drum("drums", 16, "x.....x.x.......".repeat(3), kick, 1.0)
	song.drum("drums", 16, "........x.......".repeat(3), clap, 0.8)
	song.drum("drums", 16, "x.x.x.x.x.x.x.x.".repeat(3), hat, 0.3)
	song.drum("drums", 16, "X", crash, 0.5)
	song.drum("drums", 19, "x...x...x.x.xxxx", kick, 1.0)
	song.drum("drums", 19, "oooooooxxxxxXXXX", snare, 0.8)
	# D: the polka again, then a tom fill back to the verse.
	song.drum("drums", 20, "x...x...x...x...".repeat(3) + "x...x...x.......", kick, 1.0)
	song.drum("drums", 20, "..x...x...x...x.".repeat(3) + "..x...x.........", snare, 0.8)
	song.drum("drums", 20, "x.x.x.x.x.x.x.x.".repeat(3) + "x.x.x.x.........", hat, 0.3)
	song.drum("perc", 20, "xoxoxoxoxoxoxoxo".repeat(3), tambourine, 0.8)
	song.drum("perc", 20, ("x.....x.....x..." + "....x...x.......").repeat(2), block, 0.9)
	song.drum("drums", 20, "X", crash, 0.55)
	song.drum("drums", 23, "........xx......", toms[0], 0.8)
	song.drum("drums", 23, "..........xx....", toms[1], 0.8)
	song.drum("drums", 23, "............xxXX", toms[2], 0.85)


static func _guitars(song: Song) -> void:
	var rng := song.rng
	var chord := func(n: Song.Note, _previous: Song.Note) -> PackedFloat32Array:
		var key: String = "gtr:%d:%d:%s:%d" % [n.midi, n.steps, n.muted, rng.randi() % 3]
		return song.cached(key, func() -> PackedFloat32Array:
			return Inst.chord(DSP.midi_hz(n.midi), song.steps_to_seconds(n.steps), n.muted, rng))
	var bars: Array = []
	# A: a short open chop on every off-beat, high on the neck.
	for chords: Array in VERSE:
		var bar: String = ""
		for beat: int in 4:
			var name: String = _on_beat(chords, beat)
			bar += ". . %s . " % CHOP_ROOTS[name]
		bars.append(bar.strip_edges())
	# B: open eighths, ringing into each other.
	for name: String in CHORUS:
		bars.append("R - R - R - R - R - R - R - R -".replace("R", CHORD_ROOTS[name]))
	# C: stabs for the horns to answer, then a sixteenth chug build.
	for i: int in 3:
		bars.append("R - - - . . Rm Rm . . . . . . . .".replace("R", CHORD_ROOTS[BREAKDOWN[i]]))
	bars.append("F2m F2m F2m F2m F2m F2m F2m F2m F2m F2m F2m F2m F2m F2m F2m F2m")
	# D: the chorus's eighths under the theme.
	for name: String in TAG:
		bars.append("R - R - R - R - R - R - R - R -".replace("R", CHORD_ROOTS[name]))
	song.play("gtr", Song.parse(0, bars), chord)


static func _bass(song: Song) -> void:
	var note := func(n: Song.Note, _previous: Song.Note) -> PackedFloat32Array:
		var steps: float = 1.0 if n.muted else n.steps - 0.25
		return song.cached("bass:%d:%.2f" % [n.midi, steps], func() -> PackedFloat32Array:
			return Inst.fm_bass(DSP.midi_hz(n.midi), song.steps_to_seconds(steps), 3.4))
	# The chorus and the tag pump eighths between the root and its octave.
	var pumping := func(root: String) -> String:
		var high: String = root.left(root.length() - 1) + str(int(root.right(1)) + 1)
		return "L - L - H - L - L - L - H - L -".replace("L", root).replace("H", high)
	var bars: Array = []
	bars.append_array(BASS_A)
	for name: String in CHORUS:
		bars.append(pumping.call(BASS_ROOTS[name]))
	bars.append_array(BASS_C)
	for name: String in TAG:
		bars.append(pumping.call(BASS_ROOTS[name]))
	song.play("bass", Song.parse(0, bars), note)


## The organ doubles the verse's chops (the ska bubble) and holds the breakdown's chords.
static func _organ(song: Song) -> void:
	var rng := song.rng
	for bar: int in VERSE.size():
		var chords: Array = VERSE[bar]
		for beat: int in 4:
			var name: String = _on_beat(chords, beat)
			var sound: PackedFloat32Array = song.cached("organ:chop:" + name, func() -> PackedFloat32Array:
				return Inst.organ(ORGAN_CHORDS[name], song.steps_to_seconds(1.5), rng))
			song.add("keys", sound, song.at(bar, beat * 4 + 2), 1.0)
	for i: int in BREAKDOWN.size():
		var name: String = BREAKDOWN[i]
		var sound := Inst.organ(ORGAN_CHORDS[name], song.steps_to_seconds(15.0), rng)
		song.add("keys", sound, song.at(16 + i), 0.8)


static func _horns(song: Song) -> void:
	var rng := song.rng
	# Short, punchy notes: a held note still leaves a breath before the next.
	var horn := func(n: Song.Note, _previous: Song.Note) -> PackedFloat32Array:
		var steps: float = maxf(n.steps - 0.35, 0.6)
		return song.cached("horn:%d:%.2f" % [n.midi, steps], func() -> PackedFloat32Array:
			return Inst.fm_horn(DSP.midi_hz(n.midi), song.steps_to_seconds(steps), rng))
	song.play("horns", Song.parse(0, THEME), horn)
	song.play("horns", Song.parse(0, THEME_LOW), horn, 0.7)
	song.play("horns", Song.parse(8, HOOK), horn)
	song.play("horns", Song.parse(8, HOOK_LOW), horn, 0.7)
	song.play("horns", Song.parse(16, ANSWER), horn)
	song.play("horns", Song.parse(16, ANSWER_LOW), horn, 0.7)
	song.play("horns", Song.parse(20, THEME.slice(0, 4)), horn, 0.9)
	song.play("horns", Song.parse(20, THEME_LOW.slice(0, 4)), horn, 0.65)
	# D: the lead guitar takes the theme an octave down, sliding into the long notes.
	var guitar := func(n: Song.Note, _previous: Song.Note) -> PackedFloat32Array:
		var long_note: bool = n.steps >= 4
		return Inst.guitar_note(DSP.midi_hz(n.midi - 12), song.steps_to_seconds(n.steps), false,
			1.0 if long_note else 0.0, 0.3 if long_note else 0.0, rng)
	song.play("solo", Song.parse(20, THEME.slice(0, 4)), guitar)


static func _fx(song: Song) -> void:
	var rng := song.rng
	var bar_seconds: float = song.steps_to_seconds(16.0)
	var suck := Inst.reverse_crash(bar_seconds, rng)
	song.add("fx", suck, song.at(8) - suck.size(), 0.8)
	song.add("fx", Inst.boom(1.0, rng), song.at(16), 0.9)
	var rise := Inst.riser(bar_seconds, rng)
	song.add("fx", rise, song.at(20) - rise.size(), 0.8)
	var suck_back := Inst.reverse_crash(bar_seconds, rng)
	song.add("fx", suck_back, song.at(24) - suck_back.size(), 0.6)


## The chord on a beat of a verse bar, which holds one chord or two (a half bar each).
static func _on_beat(chords: Array, beat: int) -> String:
	return chords[1] if chords.size() > 1 and beat >= 2 else chords[0]


## A hand clap: three quick bursts and a short room tail.
static func _clap(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := DSP.buffer(0.25)
	for k: int in 3:
		var burst := DSP.noise(0.012, rng)
		DSP.envelope(burst, 0.0005, 0.004, 0.001)
		DSP.mix(b, burst, k * 0.011, 1.0 - 0.15 * k)
	var tail := DSP.noise(0.2, rng)
	DSP.envelope(tail, 0.001, 0.05, 0.02)
	DSP.mix(b, tail, 0.03, 0.6)
	DSP.filter(b, &"bandpass", 1300.0, 0.9)
	DSP.filter(b, &"highpass", 500.0)
	return b


## A woodblock for the clave: a hollow, woody tock.
static func _woodblock(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := DSP.fm(0.09, func(_u: float) -> float: return 1150.0, 1.47,
		func(u: float) -> float: return 1.4 * exp(-u * 10.0))
	DSP.envelope(b, 0.0005, 0.022, 0.005)
	var click := DSP.noise(0.003, rng)
	DSP.filter(click, &"highpass", 2000.0)
	DSP.mix(b, click, 0.0, 0.3)
	return b
