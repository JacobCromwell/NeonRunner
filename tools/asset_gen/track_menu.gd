extends RefCounted
## "Menu": title, menus and shop. Moody neon synthwave at 100 BPM in A minor, with the metal kept
## underneath (palm-muted chugs, a singing lead guitar). Calm enough to sit under the UI sounds for a
## long stay in the shop. 16 bars = 38.4 s, the progression Am F C G Am F Dm E twice:
##   A  bars 1–8    warm pad pumped by a half-time kick, pulsing saw bass, FM bell arpeggio in eighths
##   B  bars 9–16   the lead guitar melody with echo, octave bass, sixteenth arpeggio and hats,
##                  quiet palm-muted chugs; a tom fill and a reversed crash lead back to A

const Song = preload("res://tools/asset_gen/music_song.gd")
const Inst = preload("res://tools/asset_gen/music_instruments.gd")
const DSP = preload("res://tools/asset_gen/sfx_dsp.gd")

const PROGRESSION: Array = ["Am", "F", "C", "G", "Am", "F", "Dm", "E"]
## Bass roots (low octave) and guitar roots for each chord.
const BASS_ROOTS: Dictionary = {"Am": "A1", "F": "F1", "C": "C2", "G": "G1", "Dm": "D2", "E": "E1"}
const GUITAR_ROOTS: Dictionary = {"Am": "A2", "F": "F2", "C": "C3", "G": "G2", "Dm": "D3", "E": "E2"}
const PAD_CHORDS: Dictionary = {
	"Am": [57, 60, 64], "F": [53, 57, 60], "C": [55, 60, 64], "G": [55, 59, 62], "Dm": [53, 57, 62], "E": [52, 56, 59],
}
const ARP_CHORDS: Dictionary = {
	"Am": [69, 72, 76, 81], "F": [65, 69, 72, 77], "C": [67, 72, 76, 79], "G": [67, 71, 74, 79],
	"Dm": [65, 69, 74, 77], "E": [64, 68, 71, 76],
}
const MELODY: Array = [
	"A4 - - - - - - - C5 - - - E5 - - -",
	"F5 - - - - - - - E5 - - - C5 - - -",
	"G5 - - - - - - - E5 - - - D5 - C5 -",
	"D5 - - - - - - - - - - - B4 - - -",
	"C5 - - - - - B4 - A4 - - - E5 - - -",
	"F5 - - - - - - - A5 - - - G5 - F5 -",
	"E5 - - - - - - - D5 - - - F5 - - -",
	"G#4 - - - B4 - - - E5 - - - - - - -",
]


static func compose() -> Song:
	var song := Song.new(100.0, 16, 1001)
	song.sections = [[0, "A"], [8, "B lead"]]
	var kicks: Array[int] = _drums(song)
	_bass(song)
	_pad(song, kicks)
	_arp(song)
	_guitars(song)
	_fx(song)
	song.echo("lead", 3.0, 0.4, 2200.0, 0.35)
	song.echo("arp", 3.0, 0.45, 2600.0, 0.45)
	song.mixdown({"drums": -13.0, "bass": -13.0, "pad": -14.0, "arp": -18.0, "lead": -13.0,
		"gtr": -18.5, "fx": -21.0}, -16.0)
	return song


## Drums; returns the kick positions for the pad's pumping.
static func _drums(song: Song) -> Array[int]:
	var rng := song.rng
	var kick: Array = []
	var snare: Array = []
	var hat: Array = []
	for v: int in 3:
		kick.append(DSP.kick(0.4, 120.0, 46.0, rng))
		# The 80s gated snare: a burst of room noise that stops dead.
		var s := DSP.snare(0.4, 180.0, 0.6, rng)
		var room := DSP.noise(0.2, rng)
		DSP.filter(room, &"bandpass", 2200.0, 0.5)
		DSP.envelope(room, 0.004, 0.35, 0.015)
		DSP.mix(s, room, 0.0, 0.5)
		snare.append(s)
		hat.append(DSP.hat(0.08, 0.02, rng))
	var crash: Array = [DSP.crash(2.0, rng)]
	var toms: Array = []
	for hz: float in [190.0, 150.0, 120.0, 95.0]:
		toms.append([DSP.tom(0.5, hz, rng)])

	var kick_pattern: String = "x.........x.....".repeat(8) + "x.......x.x.....".repeat(8)
	song.drum("drums", 0, kick_pattern, kick, 1.0)
	song.drum("drums", 0, "........x.......".repeat(8), snare, 0.85)
	song.drum("drums", 0, "..x...x...x...x.".repeat(7) + "..x...x.........", hat, 0.3)
	song.drum("drums", 8, "....x.......x...".repeat(7) + "....x...........", snare, 0.85)
	song.drum("drums", 8, "xoxoxoxoxoxoxoxo".repeat(7) + "xoxoxoxo........", hat, 0.3)
	# Tom fills into B and back into A.
	for bar: int in [7, 15]:
		for k: int in 4:
			song.drum("drums", bar, ".".repeat(12 + k) + "x", toms[k], 0.7)
	song.drum("drums", 0, "x", crash, 0.35)
	song.drum("drums", 8, "x", crash, 0.4)
	return song.hit_positions(0, kick_pattern)


static func _bass(song: Song) -> void:
	var rng := song.rng
	var note := func(n: Song.Note, _previous: Song.Note) -> PackedFloat32Array:
		return song.cached("bass:%d" % n.midi, func() -> PackedFloat32Array:
			return Inst.saw_bass(DSP.midi_hz(n.midi), song.steps_to_seconds(1.6), rng))
	var bars: Array = []
	for section: int in 2:
		for chord: String in PROGRESSION:
			var low: String = BASS_ROOTS[chord]
			var high: String = low.left(low.length() - 1) + str(int(low.right(1)) + 1)
			# A pulses on the root; B jumps octaves.
			var template: String = "L . L . L . L . L . L . L . L ." if section == 0 else "L . H . L . H . L . H . L . H ."
			bars.append(template.replace("L", low).replace("H", high))
	song.play("bass", Song.parse(0, bars), note)


static func _pad(song: Song, kicks: Array[int]) -> void:
	var rng := song.rng
	for bar: int in 16:
		var chord: String = PROGRESSION[bar % 8]
		var sound := Inst.pad(PAD_CHORDS[chord], song.steps_to_seconds(16.0), 1200.0 if bar < 8 else 1600.0, rng)
		song.add("pad", sound, song.at(bar), 1.0)
	song.pump("pad", kicks, 0.45, 0.18)


static func _arp(song: Song) -> void:
	var order: Array[int] = [0, 1, 2, 3, 2, 1, 0, 1]
	for bar: int in 16:
		var chord: Array = ARP_CHORDS[PROGRESSION[bar % 8]]
		# Eighths in A, sixteenths in B.
		var every: int = 2 if bar < 8 else 1
		var k: int = 0
		for s: int in range(0, 16, every):
			var hz: float = DSP.midi_hz(chord[order[k % 8]])
			var sound: PackedFloat32Array = song.cached("arp:%.1f" % hz, func() -> PackedFloat32Array:
				return Inst.fm_bell(hz, 0.6))
			song.add("arp", sound, song.at(bar, s), 1.0 if s % 4 == 0 else 0.7)
			k += 1


static func _guitars(song: Song) -> void:
	var rng := song.rng
	var lead := func(n: Song.Note, _previous: Song.Note) -> PackedFloat32Array:
		var long_note: bool = n.steps >= 4
		return Inst.guitar_note(DSP.midi_hz(n.midi), song.steps_to_seconds(n.steps), false,
			1.0 if long_note else 0.0, 0.35 if long_note else 0.0, rng)
	song.play("lead", Song.parse(8, MELODY), lead)
	var chug := func(n: Song.Note, _previous: Song.Note) -> PackedFloat32Array:
		return song.cached("gtr:%d:%d" % [n.midi, rng.randi() % 3], func() -> PackedFloat32Array:
			return Inst.chord(DSP.midi_hz(n.midi), song.steps_to_seconds(1.0), true, rng))
	var bars: Array = []
	for chord: String in PROGRESSION:
		bars.append("Rm . Rm Rm Rm . Rm . Rm . Rm Rm Rm . Rm .".replace("R", GUITAR_ROOTS[chord]))
	song.play("gtr", Song.parse(8, bars), chug)


static func _fx(song: Song) -> void:
	var rng := song.rng
	var bar_seconds: float = song.steps_to_seconds(16.0)
	for bar: int in [8, 16]:
		var suck := Inst.reverse_crash(bar_seconds, rng)
		song.add("fx", suck, song.at(bar) - suck.size(), 0.7)
