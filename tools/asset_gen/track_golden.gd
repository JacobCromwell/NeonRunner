extends RefCounted
## "Golden", Zone 6 (the elite's city of gold and the Golden Palace, the final level: decadent
## opulence, the cult felt everywhere). Neoclassical metal at 132 BPM in F# harmonic minor: harpsichord
## arpeggios, a string section, timpani and double kick under a regal, dotted theme and flashy guitar
## sweeps. No bells or chimes: the Golden Zone's decadence is in the harmony, and its warnings stay clear of the music.
## 24 bars = 43.6 s:
##   A  bars 1–8    gilded: harpsichord sixteenths (F#m Bm C# F#m D Bm C# C#) over ringing chords and
##                  eighth chugs, a continuo bass; the strings join in bar 5
##   B  bars 9–16   the procession: the dotted theme on strings and lead guitar in octaves over the
##                  circle of fifths (F#m Bm E A D Bm C# C#), timpani, double kick in the second half
##   C  bars 17–24  sweeps: guitar arpeggio runs (F#m D Bm C#) over double kick, a harpsichord interlude
##                  (F#m, E# diminished), then the Neapolitan G and a run down the harmonic minor scale
##                  with a timpani roll back to A

const Song = preload("res://tools/asset_gen/music_song.gd")
const Inst = preload("res://tools/asset_gen/music_instruments.gd")
const DSP = preload("res://tools/asset_gen/sfx_dsp.gd")

const GILDED: Array = ["F#m", "Bm", "C#", "F#m", "D", "Bm", "C#", "C#"]
const PROCESSION: Array = ["F#m", "Bm", "E", "A", "D", "Bm", "C#", "C#"]
const SWEEPS: Array = ["F#m", "D", "Bm", "C#"]
const INTERLUDE: Array = ["F#m", "E#dim7", "G", "C#"]
const THEME: Array = [
	"F#4 - - A4 C#5 - - - - - - - B4 - A4 -",
	"B4 - - D5 F#5 - - - - - - - E5 - D5 -",
	"E5 - - G#5 B5 - - - - - - - A5 - G#5 -",
	"A5 - - - - - - - C#6 - - - B5 - A5 -",
	"F#5 - - - - - - - A5 - - - F#5 - D5 -",
	"D5 - - - - - - - F#5 - - - D5 - B4 -",
	"E#5 - - - - - - - G#5 - - - E#5 - C#5 -",
	"C#5 - - - - - - - - - - - . . . .",
]
## The last two bars' run: around the Neapolitan G, then down the harmonic minor scale to C#.
const RUN: Array = [
	"B5 A5 G5 F#5 G5 D5 B4 G4 B4 D5 G5 B5 D6 B5 G5 D5",
	"C#6 B5 A5 G#5 F#5 E#5 D5 C#5 B4 A4 G#4 F#4 E#4 G#4 B4 C#5",
]
## Harpsichord voicings (four notes around middle C) and the sweeps' six notes (two octaves up).
const HARP_CHORDS: Dictionary = {
	"F#m": [54, 57, 61, 66], "Bm": [59, 62, 66, 71], "C#": [61, 65, 68, 73], "D": [62, 66, 69, 74],
	"E": [64, 68, 71, 76], "A": [57, 61, 64, 69], "G": [55, 59, 62, 67], "E#dim7": [65, 68, 71, 74],
}
const SWEEP_CHORDS: Dictionary = {
	"F#m": [66, 69, 73, 78, 81, 85], "D": [62, 66, 69, 74, 78, 81], "Bm": [59, 62, 66, 71, 74, 78],
	"C#": [61, 65, 68, 73, 77, 80],
}
const STRING_CHORDS: Dictionary = {
	"F#m": [57, 61, 66], "Bm": [59, 62, 66], "C#": [56, 61, 65], "D": [57, 62, 66],
	"E#dim7": [59, 62, 65, 68], "G": [55, 59, 62],
}
## Guitar roots (power chords) and bass roots (MIDI), and whether the chord's fifth is diminished.
const GUITAR_ROOTS: Dictionary = {"F#m": 42, "Bm": 47, "C#": 49, "D": 50, "E": 40, "A": 45, "G": 43, "E#dim7": 41}
const BASS_ROOTS: Dictionary = {"F#m": 30, "Bm": 35, "C#": 37, "D": 38, "E": 40, "A": 33, "G": 31, "E#dim7": 41}
## The sixteenth arpeggio's order through a four-note voicing.
const ORDER: Array[int] = [0, 1, 2, 3, 2, 1, 2, 1]
const SWEEP_ORDER: Array[int] = [0, 1, 2, 3, 4, 5, 4, 3, 2, 1, 0, 1, 2, 3, 4, 5]


static func compose() -> Song:
	var song := Song.new(132.0, 24, 1321)
	song.sections = [[0, "A gilded"], [8, "B procession"], [16, "C sweeps"]]
	_drums(song)
	_timpani(song)
	_harpsichord(song)
	_guitars(song)
	_bass(song)
	_strings(song)
	_lead(song)
	_fx(song)
	song.echo("lead", 3.0, 0.28, 2400.0, 0.2)
	song.echo("harpsi", 3.0, 0.2, 3000.0, 0.15)
	song.mixdown({"drums": -10.5, "timp": -17.0, "bass": -13.0, "gtr": -11.5, "harpsi": -16.0,
		"strings": -15.0, "lead": -13.0, "fx": -21.0}, -16.0)
	return song


static func _drums(song: Song) -> void:
	var rng := song.rng
	var kick: Array = []
	var snare: Array = []
	for v: int in 3:
		kick.append(DSP.kick(0.3, 180.0, 50.0, rng))
		snare.append(DSP.snare(0.4, 200.0, 0.65, rng))
	var bell := DSP.hat(0.5, 0.25, rng)
	DSP.mix(bell, DSP.metal_hit(0.5, 2500.0, 0.22, rng), 0.0, 0.35)
	var ride: Array = [bell]
	var hat: Array = [DSP.hat(0.07, 0.02, rng), DSP.hat(0.07, 0.02, rng)]
	var crash: Array = [DSP.crash(1.8, rng), DSP.crash(1.8, rng)]
	var toms: Array = [[DSP.tom(0.45, 200.0, rng)], [DSP.tom(0.45, 150.0, rng)], [DSP.tom(0.5, 110.0, rng)]]

	# A: a stately rock beat on the ride.
	song.drum("drums", 0, "x.....x.x.......".repeat(7) + "x.....x.x.x.....", kick, 1.0)
	song.drum("drums", 0, "....x.......x...".repeat(7) + "....x...x.x.xxXX", snare, 0.85)
	song.drum("drums", 0, "x.x.x.x.x.x.x.x.".repeat(7) + "x.x.x.x.........", ride, 0.28)
	song.drum("drums", 0, "X", crash, 0.5)
	song.drum("drums", 4, "x", crash, 0.45)
	# B: eighth kicks, then double kick for the grand half.
	song.drum("drums", 8, "x.x.x.x.x.x.x.x.".repeat(4) + "xxxxxxxxxxxxxxxx".repeat(4), kick, 0.95)
	song.drum("drums", 8, "....x.......x...".repeat(7) + "....x...x.x.xxXX", snare, 0.9)
	song.drum("drums", 8, "x.x.x.x.x.x.x.x.".repeat(7) + "x.x.x.x.........", hat, 0.3)
	for bar: int in [8, 10, 12, 13, 14]:
		song.drum("drums", bar, "X", crash, 0.5)
	# C: double kick under the sweeps, a hush for the harpsichord, then toms into the run.
	song.drum("drums", 16, "xxxxxxxxxxxxxxxx".repeat(4), kick, 0.9)
	song.drum("drums", 16, "....x.......x...".repeat(4), snare, 0.9)
	song.drum("drums", 16, "X", crash, 0.55)
	song.drum("drums", 18, "x", crash, 0.5)
	song.drum("drums", 20, "x.........x.....".repeat(2), kick, 0.8)
	song.drum("drums", 20, "........x.......".repeat(2), snare, 0.6)
	song.drum("drums", 20, "x...x...x...x...".repeat(2), ride, 0.25)
	song.drum("drums", 22, "x.x.x.x.x.x.x.x." + "xxxxxxxxxxxx....", kick, 0.9)
	song.drum("drums", 22, "X", crash, 0.5)
	song.drum("drums", 23, "xx..............", toms[0], 0.75)
	song.drum("drums", 23, "....xx..........", toms[1], 0.8)
	song.drum("drums", 23, "........xx..xxXX", toms[2], 0.85)


## Timpani: a hit on each of the procession's chord changes, and a roll swelling into the loop.
static func _timpani(song: Song) -> void:
	var rng := song.rng
	var hits: Dictionary = {}
	for spot: Array in [[8, 92.5], [10, 82.41], [12, 73.42], [14, 69.3]]:
		var hz: float = spot[1]
		if not hits.has(hz):
			hits[hz] = Inst.timpani(hz * 2.0, 1.8, rng)
		song.add("timp", hits[hz], song.at(spot[0]), 1.0)
	var roll := Inst.timpani(138.59, 0.5, rng)
	var count: int = 48
	for k: int in count:
		var u: float = float(k) / (count - 1)
		# Sixteenths through bar 23, thirty-seconds through bar 24.
		var s: float = k if k < 16 else 16.0 + (k - 16) * 0.5
		song.add("timp", roll, song.at(22, s), 0.3 + 0.7 * u * u)


static func _harpsichord(song: Song) -> void:
	var rng := song.rng
	var note := func(midi: int, steps: float) -> PackedFloat32Array:
		return song.cached("harp:%d:%.1f" % [midi, steps], func() -> PackedFloat32Array:
			return Inst.harpsichord(DSP.midi_hz(midi), song.steps_to_seconds(steps), rng))
	# [first bar, chords, notes per bar (16 or 8), level]
	var plan: Array = [[0, GILDED, 16, 1.0], [8, PROCESSION, 8, 0.7], [16, SWEEPS, 8, 0.6], [20, INTERLUDE, 16, 1.0]]
	for part: Array in plan:
		var chords: Array = part[1]
		var per_bar: int = part[2]
		var every: int = roundi(16.0 / per_bar)
		for i: int in chords.size():
			var voicing: Array = HARP_CHORDS[chords[i]]
			for k: int in per_bar:
				var midi: int = voicing[ORDER[k % ORDER.size()]]
				var accent: float = 1.0 if k % 4 == 0 else 0.8
				song.add("harpsi", note.call(midi, every * 1.5), song.at(int(part[0]) + i, k * every), float(part[3]) * accent)


static func _guitars(song: Song) -> void:
	var rng := song.rng
	var chug := func(n: Song.Note, _previous: Song.Note) -> PackedFloat32Array:
		var key: String = "gtr:%d:%d:%s:%d" % [n.midi, n.steps, n.muted, rng.randi() % 3]
		return song.cached(key, func() -> PackedFloat32Array:
			return Inst.chord(DSP.midi_hz(n.midi), song.steps_to_seconds(n.steps), n.muted, rng))
	var bars: Array = []
	for name: String in GILDED:
		bars.append(_fill("R - Rm - Rm - Rm - R - Rm - Rm - Rm -", GUITAR_ROOTS[name]))
	for i: int in PROCESSION.size():
		var template: String = "R - Rm - R - Rm - R - Rm - R - Rm -" if i < 4 \
			else "R - Rm Rm Rm Rm Rm Rm R - Rm Rm Rm Rm Rm Rm"
		bars.append(_fill(template, GUITAR_ROOTS[PROCESSION[i]]))
	for name: String in SWEEPS:
		bars.append(_fill("R - - - - - - - - - - - - - - -", GUITAR_ROOTS[name]))
	bars.append(". . . . . . . . . . . . . . . .")
	bars.append(". . . . . . . . . . . . . . . .")
	bars.append(_fill("R - - - - - - - R - - - - - - -", GUITAR_ROOTS["G"]))
	bars.append(_fill("R - - - - - - - Rm Rm Rm Rm Rm Rm Rm Rm", GUITAR_ROOTS["C#"]))
	song.play("gtr", Song.parse(0, bars), chug)


static func _bass(song: Song) -> void:
	var note := func(n: Song.Note, _previous: Song.Note) -> PackedFloat32Array:
		var steps: float = 1.0 if n.muted else n.steps - 0.2
		return song.cached("bass:%d:%.1f" % [n.midi, steps], func() -> PackedFloat32Array:
			return Inst.fm_bass(DSP.midi_hz(n.midi), song.steps_to_seconds(steps), 2.2))
	var bars: Array = []
	# A: a continuo walking root, fifth, octave, fifth.
	for name: String in GILDED:
		bars.append(_continuo(name))
	# B: eighths pumping between the root and its octave.
	for name: String in PROCESSION:
		var root: int = BASS_ROOTS[name]
		bars.append(_notes([root, root, root + 12, root, root, root, root + 12, root], 2))
	# C: whole notes under the sweeps, the continuo in the interlude, eighths into the loop.
	for name: String in SWEEPS:
		bars.append(_notes([BASS_ROOTS[name]], 16))
	for name: String in ["F#m", "E#dim7"]:
		bars.append(_continuo(name))
	for name: String in ["G", "C#"]:
		var root: int = BASS_ROOTS[name]
		bars.append(_notes([root, root, root + 12, root, root, root, root + 12, root], 2))
	song.play("bass", Song.parse(0, bars), note)


static func _strings(song: Song) -> void:
	var rng := song.rng
	# A: long chords as the melody's bed, then the interlude and the run's chords in C.
	for spot: Array in [[4, "D"], [5, "Bm"], [6, "C#"], [7, "C#"], [20, "F#m"], [21, "E#dim7"], [22, "G"], [23, "C#"]]:
		var sound := Inst.strings(STRING_CHORDS[spot[1]], song.steps_to_seconds(16.0), 0.25, rng)
		song.add("strings", sound, song.at(spot[0]), 0.8)
	# B: the theme in octaves.
	var theme := func(n: Song.Note, _previous: Song.Note) -> PackedFloat32Array:
		return Inst.strings([n.midi, n.midi - 12], song.steps_to_seconds(maxf(n.steps - 0.2, 0.8)), 0.05, rng)
	song.play("strings", Song.parse(8, THEME), theme)


static func _lead(song: Song) -> void:
	var rng := song.rng
	# B: the theme an octave down, with vibrato on the long notes.
	var singing := func(n: Song.Note, _previous: Song.Note) -> PackedFloat32Array:
		var long_note: bool = n.steps >= 4
		return Inst.guitar_note(DSP.midi_hz(n.midi - 12), song.steps_to_seconds(n.steps), false,
			1.0 if long_note else 0.0, 0.35 if long_note else 0.0, rng)
	song.play("lead", Song.parse(8, THEME), singing, 0.85)
	# C: sweeps, one arpeggio up, down and up again each bar, then the run.
	var picked := func(midi: int) -> PackedFloat32Array:
		return song.cached("lead:%d" % midi, func() -> PackedFloat32Array:
			return Inst.guitar_note(DSP.midi_hz(midi), song.steps_to_seconds(1.3), false, 0.0, 0.0, rng))
	for i: int in SWEEPS.size():
		var arp: Array = SWEEP_CHORDS[SWEEPS[i]]
		for k: int in SWEEP_ORDER.size():
			song.add("lead", picked.call(arp[SWEEP_ORDER[k]]), song.at(16 + i, k), 0.9 if k % 4 == 0 else 0.75)
	for n: Song.Note in Song.parse(22, RUN):
		song.add("lead", picked.call(n.midi), song.at(n.bar, n.step), 0.85)


static func _fx(song: Song) -> void:
	var rng := song.rng
	var bar_seconds: float = song.steps_to_seconds(16.0)
	var suck := Inst.reverse_crash(bar_seconds, rng)
	song.add("fx", suck, song.at(8) - suck.size(), 0.8)
	song.add("fx", Inst.boom(1.4, rng), song.at(8), 0.9)
	var rise := Inst.riser(bar_seconds, rng)
	song.add("fx", rise, song.at(24) - rise.size(), 0.7)


## A bar pattern with "R" for the root's note name.
static func _fill(template: String, midi: int) -> String:
	return template.replace("R", _name(midi))


## A continuo bar: root, fifth, octave, fifth in eighths, twice (a diminished chord's fifth is flat).
static func _continuo(chord: String) -> String:
	var root: int = BASS_ROOTS[chord]
	var fifth: int = root + (6 if chord.ends_with("dim7") else 7)
	return _notes([root, fifth, root + 12, fifth, root, fifth, root + 12, fifth], 2)


## A bar of notes, each `steps` long.
static func _notes(midis: Array, steps: int) -> String:
	var tokens: PackedStringArray = []
	for m: int in midis:
		tokens.append(_name(m))
		for k: int in steps - 1:
			tokens.append("-")
	return " ".join(tokens)


## MIDI 42 → "F#2".
static func _name(midi: int) -> String:
	const NAMES: Array[String] = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
	return "%s%d" % [NAMES[midi % 12], floori(midi / 12.0) - 1]
