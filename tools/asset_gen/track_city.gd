extends RefCounted
## "City", Zone 1 (the Neon City: convoys of hover trucks, ships overhead). Driving synth-metal at
## 160 BPM in E minor, 24 bars = 36 s:
##   A   bars 1–8    galloping pedal riff on E; a pulse-wave arpeggio joins in bar 5
##   B   bars 9–16   the theme on FM brass doubled by a lead guitar an octave down, over driving
##                   eighths (Em C G D Em C Am B); double kick in the second half
##   C   bars 17–20  half-time breakdown: ringing chords, pad, ride bell, arpeggio
##   C'  bars 21–24  twin-guitar harmonies in thirds, then a snare roll and riser back into A

const Song = preload("res://tools/asset_gen/music_song.gd")
const Inst = preload("res://tools/asset_gen/music_instruments.gd")
const DSP = preload("res://tools/asset_gen/sfx_dsp.gd")

const RIFF: Array = [
	"E2m . E2m E2m G2 - E2m . A2 - E2m E2m Bb2 - A2 -",
	"E2m . E2m E2m G2 - E2m . D3 - - - B2 - - -",
]
const RIFF_TURN: Array = [
	"E2m . E2m E2m G2 - E2m . A2 - E2m E2m Bb2 - A2 -",
	"E2m . E2m E2m G2 - A2 - B2 - - - B2m B2m B2m B2m",
]
const BASS_RIFF: Array = [
	"E1m . E1m E1m G1 - E1m . A1 - E1m E1m Bb1 - A1 -",
	"E1m . E1m E1m G1 - E1m . D2 - - - B1 - - -",
]
const BASS_TURN: Array = [
	"E1m . E1m E1m G1 - E1m . A1 - E1m E1m Bb1 - A1 -",
	"E1m . E1m E1m G1 - A1 - B1 - - - B1m B1m B1m B1m",
]
## Chord roots for the theme (B) and the twin-lead section (C'), guitar octave.
const THEME_ROOTS: Array = ["E2", "C3", "G2", "D3", "E2", "C3", "A2", "B2"]
const TWIN_ROOTS: Array = ["C3", "D3", "E2", "B2"]
const THEME: Array = [
	"B4 - - - E5 - - - F#5 - G5 - F#5 - E5 -",
	"G5 - - - - - E5 - C5 - - - - - - -",
	"D5 - - - B4 - - - D5 - G5 - F#5 - G5 -",
	"A5 - - - - - - - F#5 - - - D5 - - -",
	"B4 - - - E5 - - - F#5 - G5 - A5 - B5 -",
	"C6 - - - - - B5 - G5 - - - E5 - - -",
	"A5 - - - G5 - F#5 - E5 - - - C5 - - -",
	"D#5 - - - - - - - F#5 - - - B5 - - -",
]
const BREAKDOWN: Array = [
	"C3 - - - - - - - D3 - - - - - - -",
	"E2 - - - - - - - - - - - - - - -",
	"C3 - - - - - - - D3 - - - - - - -",
	"B2 - - - - - - - - - - - B2m B2m B2m B2m",
]
const BASS_BREAKDOWN: Array = [
	"C2 - - - - - - - D2 - - - - - - -",
	"E1 - - - - - - - - - - - - - - -",
	"C2 - - - - - - - D2 - - - - - - -",
	"B1 - - - - - - - - - - - B1m B1m B1m B1m",
]
## The twin leads: a melody and its diatonic third below.
const TWIN_HIGH: Array = [
	"E5 - G5 - E5 - C5 - E5 - G5 - C6 - B5 -",
	"A5 - F#5 - D5 - F#5 - A5 - D6 - C6 - A5 -",
	"B5 - G5 - E5 - G5 - B5 - E6 - D6 - B5 -",
	"D#6 - - - B5 - - - F#5 - - - D#5 - - -",
]
const TWIN_LOW: Array = [
	"C5 - E5 - C5 - A4 - C5 - E5 - A5 - G5 -",
	"F#5 - D5 - B4 - D5 - F#5 - B5 - A5 - F#5 -",
	"G5 - E5 - C5 - E5 - G5 - C6 - B5 - G5 -",
	"B5 - - - F#5 - - - D#5 - - - B4 - - -",
]
## Chords as MIDI notes: arpeggio voicing (four notes around E4) and pad voicing (lower).
const ARP_CHORDS: Dictionary = {
	"Em": [64, 67, 71, 76], "C": [60, 64, 67, 72], "D": [62, 66, 69, 74], "G": [62, 67, 71, 74],
	"Am": [57, 60, 64, 69], "Bm": [59, 62, 66, 71], "B": [59, 63, 66, 71],
}
const PAD_CHORDS: Dictionary = {
	"Em": [52, 55, 59, 64], "C": [48, 52, 55, 60], "D": [50, 54, 57, 62], "G": [50, 55, 59, 62],
	"Am": [45, 52, 57, 60], "B": [47, 51, 54, 59],
}


static func compose() -> Song:
	var song := Song.new(160.0, 24, 1601)
	song.sections = [[0, "A riff"], [8, "B theme"], [16, "C breakdown"], [20, "C' twin leads"]]
	var kicks: Array[int] = _drums(song)
	_guitars(song)
	_bass(song)
	_arp(song)
	_leads(song)
	_pad(song, kicks)
	_fx(song)
	song.echo("lead", 3.0, 0.3, 2600.0, 0.22)
	song.echo("solo", 3.0, 0.25, 2200.0, 0.18)
	song.echo("arp", 3.0, 0.45, 3000.0, 0.4)
	song.mixdown({"drums": -10.0, "bass": -13.0, "gtr": -11.0, "lead": -13.5, "solo": -14.0,
		"arp": -20.0, "pad": -21.0, "fx": -21.0}, -16.0)
	return song


## Drums; returns the kick positions for the pad's pumping.
static func _drums(song: Song) -> Array[int]:
	var rng := song.rng
	var kick: Array = []
	var snare: Array = []
	var hat: Array = []
	for v: int in 3:
		kick.append(DSP.kick(0.32, 175.0, 50.0, rng))
		snare.append(DSP.snare(0.36, 195.0, 0.6, rng))
		hat.append(DSP.hat(0.08, 0.022, rng))
	var open_hat: Array = [DSP.hat(0.4, 0.14, rng), DSP.hat(0.4, 0.14, rng)]
	var crash: Array = [DSP.crash(1.6, rng), DSP.crash(1.6, rng)]
	var bell := DSP.hat(0.6, 0.3, rng)
	DSP.mix(bell, DSP.metal_hit(0.6, 2350.0, 0.25, rng), 0.0, 0.5)
	var ride: Array = [bell]
	var toms: Array = [[DSP.tom(0.45, 210.0, rng)], [DSP.tom(0.45, 155.0, rng)], [DSP.tom(0.5, 110.0, rng)]]

	var kick_pattern: String = ""
	# A: gallop, bar 8 ends in a tom fill.
	kick_pattern += "x.xx....x.xx....".repeat(7) + "x.xx....x......."
	song.drum("drums", 0, "....x.......x...".repeat(7) + "....x.........XX", snare, 0.9)
	song.drum("drums", 0, "x.x.x.x.x.x.x.x.".repeat(7) + "x.x.x.x.........", hat, 0.35)
	song.drum("drums", 7, "........xx......", toms[0], 0.8)
	song.drum("drums", 7, "..........xx....", toms[1], 0.8)
	song.drum("drums", 7, "............xx..", toms[2], 0.85)
	song.drum("drums", 0, "X", crash, 0.5)
	song.drum("drums", 4, "x", crash, 0.4)
	# B: driving eighths, then double kick; bar 16 ends in a snare fill.
	kick_pattern += "x.x.x.x.x.x.x.x.".repeat(4) + "xxxxxxxxxxxxxxxx".repeat(4)
	song.drum("drums", 8, "....x.......x...".repeat(7) + "....x...x.x.xxXX", snare, 0.9)
	song.drum("drums", 8, "x...x...x...x...".repeat(4) + "x.x.x.x.x.x.x.x.".repeat(3) + "x.x.x.x.........", hat, 0.35)
	song.drum("drums", 8, "..x...x...x...x.".repeat(4), open_hat, 0.25)
	song.drum("drums", 8, "X", crash, 0.5)
	song.drum("drums", 12, "x", crash, 0.45)
	# C: half-time breakdown on the ride bell.
	kick_pattern += "x.........x.....".repeat(4)
	song.drum("drums", 16, "........x.......".repeat(3) + "........x.....xx", snare, 0.9)
	song.drum("drums", 16, "x...x...x...x...".repeat(4), ride, 0.3)
	song.drum("drums", 16, "X", crash, 0.55)
	# C': full again, then a snare roll into the loop start.
	kick_pattern += "x.x.x.x.x.x.x.x.".repeat(3) + "xxxxxxxxxxxxxxxx"
	song.drum("drums", 20, "....x.......x...".repeat(3) + "oooooooxxxxxXXXX", snare, 0.85)
	song.drum("drums", 20, "x.x.x.x.x.x.x.x.".repeat(3), hat, 0.35)
	song.drum("drums", 20, "x", crash, 0.45)
	song.drum("drums", 0, kick_pattern, kick, 1.0)
	return song.hit_positions(0, kick_pattern)


static func _guitars(song: Song) -> void:
	var rng := song.rng
	var chug := func(n: Song.Note, _previous: Song.Note) -> PackedFloat32Array:
		var key: String = "gtr:%d:%d:%s:%d" % [n.midi, n.steps, n.muted, rng.randi() % 3]
		return song.cached(key, func() -> PackedFloat32Array:
			return Inst.chord(DSP.midi_hz(n.midi), song.steps_to_seconds(n.steps), n.muted, rng))
	var bars: Array = []
	bars.append_array(RIFF + RIFF + RIFF + RIFF_TURN)
	for i: int in THEME_ROOTS.size():
		var template: String = "R - Rm . Rm . Rm . R - Rm . Rm . Rm Rm" if i < 4 \
			else "R - Rm Rm Rm Rm Rm Rm R - Rm Rm Rm Rm Rm Rm"
		bars.append(template.replace("R", THEME_ROOTS[i]))
	bars.append_array(BREAKDOWN)
	for i: int in TWIN_ROOTS.size():
		var template: String = "R - Rm . Rm . Rm . R - Rm . Rm . Rm ." if i < 3 \
			else "R - Rm . Rm . Rm . Rm Rm Rm Rm Rm Rm Rm Rm"
		bars.append(template.replace("R", TWIN_ROOTS[i]))
	song.play("gtr", Song.parse(0, bars), chug)


static func _bass(song: Song) -> void:
	var note := func(n: Song.Note, _previous: Song.Note) -> PackedFloat32Array:
		var steps: float = 1.0 if n.muted else n.steps - 0.3
		return Inst.fm_bass(DSP.midi_hz(n.midi), song.steps_to_seconds(steps), 2.6)
	# Eighths pumping between the root (an octave below the guitar) and its octave.
	var pumping := func(root: String) -> String:
		return "L . L . H . L . L . L . H . L .".replace("L", _octave(root, -1)).replace("H", root)
	var bars: Array = []
	bars.append_array(BASS_RIFF + BASS_RIFF + BASS_RIFF + BASS_TURN)
	for root: String in THEME_ROOTS:
		bars.append(pumping.call(root))
	bars.append_array(BASS_BREAKDOWN)
	for root: String in TWIN_ROOTS:
		bars.append(pumping.call(root))
	song.play("bass", Song.parse(0, bars), note)


static func _arp(song: Song) -> void:
	# Bars 5–8 over the riff, then the breakdown and twin-lead bars. Two chords per bar.
	var plan: Array = [
		[4, "Em", "Em"], [5, "Em", "Bm"], [6, "Em", "Em"], [7, "Em", "B"],
		[16, "C", "D"], [17, "Em", "Em"], [18, "C", "D"], [19, "B", "B"],
		[20, "C", "C"], [21, "D", "D"], [22, "Em", "Em"], [23, "B", "B"],
	]
	var order: Array[int] = [0, 1, 2, 3, 2, 1, 0, 1]
	for entry: Array in plan:
		for half: int in 2:
			var chord: Array = ARP_CHORDS[entry[1 + half]]
			for k: int in 8:
				var hz: float = DSP.midi_hz(chord[order[k]])
				var sound: PackedFloat32Array = song.cached("arp:%.1f" % hz, func() -> PackedFloat32Array:
					return Inst.pulse_note(hz, song.steps_to_seconds(1.0), 0.25, 0.07))
				song.add("arp", sound, song.at(entry[0], half * 8 + k), 1.0 if k % 2 == 0 else 0.75)


static func _leads(song: Song) -> void:
	var rng := song.rng
	var brass := func(n: Song.Note, previous: Song.Note) -> PackedFloat32Array:
		var from_hz: float = 0.0
		if previous != null and previous.bar * 16 + previous.step + previous.steps == n.bar * 16 + n.step:
			from_hz = DSP.midi_hz(previous.midi)
		return Inst.fm_lead(DSP.midi_hz(n.midi), song.steps_to_seconds(n.steps), from_hz, 0.35 if n.steps >= 4 else 0.0)
	song.play("lead", Song.parse(8, THEME), brass)
	# The same theme on guitar, an octave down, sliding into the long notes.
	var guitar := func(n: Song.Note, _previous: Song.Note) -> PackedFloat32Array:
		var long_note: bool = n.steps >= 4
		return Inst.guitar_note(DSP.midi_hz(n.midi - 12), song.steps_to_seconds(n.steps), false,
			1.0 if long_note else 0.0, 0.4 if long_note else 0.0, rng)
	song.play("solo", Song.parse(8, THEME), guitar, 0.8)
	var twin := func(n: Song.Note, _previous: Song.Note) -> PackedFloat32Array:
		return Inst.guitar_note(DSP.midi_hz(n.midi), song.steps_to_seconds(n.steps), false,
			0.0, 0.35 if n.steps >= 4 else 0.0, rng)
	song.play("solo", Song.parse(20, TWIN_HIGH), twin, 0.8)
	song.play("solo", Song.parse(20, TWIN_LOW), twin, 0.6)


static func _pad(song: Song, kicks: Array[int]) -> void:
	var rng := song.rng
	# [bar, chord, steps, level]: quiet under the theme, full in the breakdown.
	var plan: Array = [
		[8, "Em", 16, 0.45], [9, "C", 16, 0.45], [10, "G", 16, 0.45], [11, "D", 16, 0.45],
		[12, "Em", 16, 0.45], [13, "C", 16, 0.45], [14, "Am", 16, 0.45], [15, "B", 16, 0.45],
		[16, "C", 8, 1.0], [16.5, "D", 8, 1.0], [17, "Em", 16, 1.0], [18, "C", 8, 1.0], [18.5, "D", 8, 1.0],
		[19, "B", 16, 1.0], [20, "C", 16, 0.7], [21, "D", 16, 0.7], [22, "Em", 16, 0.7], [23, "B", 16, 0.7],
	]
	for entry: Array in plan:
		var start: float = entry[0]
		var sound := Inst.pad(PAD_CHORDS[entry[1]], song.steps_to_seconds(entry[2]), 1500.0, rng)
		song.add("pad", sound, song.at(int(start), fmod(start, 1.0) * 16.0), entry[3])
	song.pump("pad", kicks, 0.5, 0.12)


static func _fx(song: Song) -> void:
	var rng := song.rng
	var bar_seconds: float = song.steps_to_seconds(16.0)
	var suck := Inst.reverse_crash(bar_seconds, rng)
	song.add("fx", suck, song.at(16) - suck.size(), 0.8)
	song.add("fx", Inst.boom(1.2, rng), song.at(16), 1.0)
	var rise := Inst.riser(bar_seconds, rng)
	song.add("fx", rise, song.at(24) - rise.size(), 0.9)


## "E2" → "E1" for octave -1.
static func _octave(note_name: String, octaves: int) -> String:
	var digits: int = note_name.length() - 1
	return note_name.left(digits) + str(int(note_name.right(1)) + octaves)
