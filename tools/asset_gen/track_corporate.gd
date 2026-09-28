extends RefCounted
## "Corporate", Zone 4 (a harder Blade Runner: corporate towers, maglev lines and military checkpoints,
## cold white light). Oppressive cyber-metal at 112 BPM in B minor, drop-B: a machine riff of palm-
## muted sixteenths accented in threes and locked to the kick, a cold sequencer bass, a sterile pad,
## a military snare, and Vangelis-style synth brass over a heavy half-time march. 20 bars = 42.9 s:
##   A  bars 1–8    the machine: the B pedal riff (accents 3+3+3+3, then a turn through D–C# or the
##                  tritone F–E), the kick on every accent, double kick from bar 5 under a cold pad
##   B  bars 9–16   the march: half-time power chords (Bm G Em F#) with double-kick bursts, the brass
##                  theme doubled by a guitar an octave down, timpani, snare rolls
##   C  bars 17–20  the checkpoint: a snare cadence and marching stomps over the pulsing bass and a
##                  low brass call, then the riff returns over double kick and a riser back to A

const Song = preload("res://tools/asset_gen/music_song.gd")
const Inst = preload("res://tools/asset_gen/music_instruments.gd")
const DSP = preload("res://tools/asset_gen/sfx_dsp.gd")

const MACHINE: Array = [
	"B1m! B1m B1m B1m! B1m B1m B1m! B1m B1m B1m! B1m B1m D2 - C#2 -",
	"B1m! B1m B1m B1m! B1m B1m B1m! B1m B1m B1m! B1m B1m F2 - E2 -",
]
## The last bar before the march turns to the dominant.
const MACHINE_TURN: String = "B1m! B1m B1m B1m! B1m B1m B1m! B1m B1m B1m! B1m B1m F#2 - - -"
## The march (B): one chord a bar, two bars each.
const MARCH_ROOTS: Array = ["B1", "B1", "G2", "G2", "E2", "E2", "F#2", "F#2"]
const THEME: Array = [
	"F#4 - - - - - - - - - - - D4 - - -",
	"B4 - - - - - - - A4 - - - F#4 - - -",
	"G4 - - - - - - - - - - - B4 - - -",
	"D5 - - - - - - - B4 - - - G4 - - -",
	"E4 - - - - - - - G4 - - - B4 - - -",
	"E5 - - - - - - - D5 - - - B4 - - -",
	"A#4 - - - - - - - C#5 - - - - - - -",
	"F#5 - - - - - - - - - - - . . . .",
]
## Pad voicings: a cold Bm with the added ninth, and the march's chords, close together.
const PAD_CHORDS: Dictionary = {
	"Bm9": [47, 54, 61, 62], "Bm": [59, 62, 66], "G": [59, 62, 67], "Em": [59, 64, 67], "F#": [58, 61, 66],
	"drone": [47, 54, 59],
}
## Timpani pitch per march chord.
const TIMPANI_HZ: Dictionary = {"B1": 123.47, "G2": 98.0, "E2": 82.41, "F#2": 92.5}


static func compose() -> Song:
	var song := Song.new(112.0, 20, 1121)
	song.sections = [[0, "A machine"], [8, "B march"], [16, "C checkpoint"]]
	_drums(song)
	_guitars(song)
	_bass(song)
	_pad(song)
	_brass(song)
	_fx(song)
	song.echo("brass", 3.0, 0.3, 2400.0, 0.25)
	song.echo("solo", 3.0, 0.25, 2000.0, 0.15)
	song.mixdown({"drums": -10.0, "gtr": -10.5, "bass": -12.5, "brass": -13.0, "solo": -16.0,
		"pad": -20.0, "fx": -20.0}, -16.0)
	return song


static func _drums(song: Song) -> void:
	var rng := song.rng
	var kick: Array = []
	var snare: Array = []
	var hat: Array = []
	for v: int in 3:
		kick.append(DSP.kick(0.22, 200.0, 55.0, rng))
		# A military snare: tight, crisp wires.
		snare.append(DSP.snare(0.28, 215.0, 0.95, rng))
		hat.append(DSP.hat(0.05, 0.015, rng))
	var bell := DSP.hat(0.5, 0.22, rng)
	DSP.mix(bell, DSP.metal_hit(0.5, 2100.0, 0.2, rng), 0.0, 0.4)
	var ride: Array = [bell]
	var crash: Array = [DSP.crash(1.8, rng), DSP.crash(1.8, rng)]
	var stomp: Array = []
	for v: int in 2:
		var s := DSP.kick(0.2, 120.0, 45.0, rng)
		var crunch := DSP.noise(0.08, rng)
		DSP.filter(crunch, &"lowpass", 1400.0)
		DSP.envelope(crunch, 0.001, 0.02, 0.01)
		DSP.mix(s, crunch, 0.0, 0.6)
		stomp.append(s)

	# A: the kick on the riff's accents, then double kick; a straight backbeat.
	song.drum("drums", 0, "x..x..x..x..x.x.".repeat(4), kick, 1.0)
	song.drum("drums", 4, "XooXooXooXooXoXo".repeat(4), kick, 0.95)
	song.drum("drums", 0, "....x.......x...".repeat(7) + "....x...x.x.xxXX", snare, 0.85)
	song.drum("drums", 0, "x.x.x.x.x.x.x.x.".repeat(7) + "x.x.x.x.........", hat, 0.3)
	song.drum("drums", 0, "X", crash, 0.5)
	song.drum("drums", 4, "x", crash, 0.45)
	# B: half-time, the kick locked to the chug bursts, snare on 3, a ride on the beat.
	song.drum("drums", 8, "x.......xxx.xxx.".repeat(7) + "x.......xxxxxxxx", kick, 1.0)
	song.drum("drums", 8, "........x.......".repeat(8), snare, 0.95)
	song.drum("drums", 8, "x...x...x...x...".repeat(7) + "x...x...........", ride, 0.3)
	song.drum("drums", 8, "X", crash, 0.55)
	song.drum("drums", 12, "x", crash, 0.5)
	for bar: int in [9, 11, 13]:
		_roll(song, bar, 12.0, 16.0, snare, 0.25, 0.8)
	# C: a snare cadence over marching stomps, then the machine's double kick and a roll.
	song.drum("drums", 16, "X.o.x.o.X.o.x.oo" + "X.o.x.o.X.o.xxxx" + "X.o.x.o.X.o.x.oo", snare, 0.8)
	song.drum("drums", 16, "x...x...x...x...".repeat(3), stomp, 1.0)
	song.drum("drums", 19, "xxxxxxxxxxxxxxxx", kick, 0.9)
	song.drum("drums", 19, "x.o.x.o.x.o.....", snare, 0.8)
	_roll(song, 19, 12.0, 16.0, snare, 0.4, 1.0)

	# Timpani on each chord change of the march.
	var timpani: Dictionary = {}
	for i: int in range(0, MARCH_ROOTS.size(), 2):
		var root: String = MARCH_ROOTS[i]
		if not timpani.has(root):
			timpani[root] = Inst.timpani(TIMPANI_HZ[root], 1.6, rng)
		song.add("drums", timpani[root], song.at(8 + i), 0.9)


## A snare roll in thirty-second notes from `from_step` to `to_step` of a bar, swelling in.
static func _roll(song: Song, bar: int, from_step: float, to_step: float, snare: Array, gain_from: float,
		gain_to: float) -> void:
	var count: int = roundi((to_step - from_step) * 2.0)
	for k: int in count:
		var u: float = float(k) / maxf(count - 1, 1)
		var sound: PackedFloat32Array = snare[k % snare.size()]
		song.add("drums", sound, song.at(bar, from_step + k * 0.5), lerpf(gain_from, gain_to, u))


static func _guitars(song: Song) -> void:
	var rng := song.rng
	var chug := func(n: Song.Note, _previous: Song.Note) -> PackedFloat32Array:
		var key: String = "gtr:%d:%d:%s:%d" % [n.midi, n.steps, n.muted, rng.randi() % 3]
		return song.cached(key, func() -> PackedFloat32Array:
			return Inst.chord(DSP.midi_hz(n.midi), song.steps_to_seconds(n.steps), n.muted, rng))
	var bars: Array = []
	bars.append_array(MACHINE + MACHINE + MACHINE)
	bars.append_array([MACHINE[0], MACHINE_TURN])
	for i: int in MARCH_ROOTS.size():
		var template: String = "R - - - - - - - Rm Rm Rm . Rm Rm Rm ." if i < 7 \
			else "R - - - - - - - Rm Rm Rm Rm Rm Rm Rm Rm"
		bars.append(template.replace("R", MARCH_ROOTS[i]))
	song.play("gtr", Song.parse(0, bars), chug)
	# C: silent through the cadence, a quiet chug creeping in, then the riff returns.
	var creep: Array = [
		"B1m . B1m . B1m . B1m . B1m B1m B1m B1m B1m B1m B1m B1m",
		"B1m! B1m B1m B1m! B1m B1m B1m! B1m B1m B1m! B1m B1m F#2 - - -",
	]
	song.play("gtr", Song.parse(18, creep.slice(0, 1)), chug, 0.55)
	song.play("gtr", Song.parse(19, creep.slice(1, 2)), chug)


static func _bass(song: Song) -> void:
	var rng := song.rng
	var note := func(n: Song.Note, _previous: Song.Note) -> PackedFloat32Array:
		var steps: float = 1.0 if n.muted else n.steps - 0.2
		return song.cached("bass:%d:%.1f:%s" % [n.midi, steps, n.accent], func() -> PackedFloat32Array:
			return Inst.seq_bass(DSP.midi_hz(n.midi), song.steps_to_seconds(steps), n.accent, rng))
	var bars: Array = []
	# A: the riff, note for note.
	bars.append_array(MACHINE + MACHINE + MACHINE)
	bars.append_array([MACHINE[0], MACHINE_TURN])
	# B: the march roots, held, with the chug bursts.
	for i: int in MARCH_ROOTS.size():
		var low: String = MARCH_ROOTS[i]
		if low != "B1":
			low = low.left(low.length() - 1) + str(int(low.right(1)) - 1)
		bars.append("R - - - - - - - Rm Rm Rm . Rm Rm Rm .".replace("R", low))
	# C: a pulse in eighths through the cadence, sixteenths into the loop.
	for i: int in 3:
		bars.append("B1m . B1m . B1m . B1m . B1m . B1m . B1m . B1m .")
	bars.append("B1m! B1m B1m B1m! B1m B1m B1m! B1m B1m B1m! B1m B1m F#1 - - -")
	song.play("bass", Song.parse(0, bars), note)


static func _pad(song: Song) -> void:
	var rng := song.rng
	# [bar, chord, steps, level]: the cold pad joins the machine, carries the march, drones at the
	# checkpoint.
	var plan: Array = [
		[4, "Bm9", 32, 0.7], [6, "Bm9", 32, 0.7],
		[8, "Bm", 32, 1.0], [10, "G", 32, 1.0], [12, "Em", 32, 1.0], [14, "F#", 32, 1.0],
		[16, "drone", 32, 0.8], [18, "drone", 32, 0.8],
	]
	for entry: Array in plan:
		var sound := Inst.pad(PAD_CHORDS[entry[1]], song.steps_to_seconds(entry[2]), 2300.0, rng)
		song.add("pad", sound, song.at(entry[0]), entry[3])


static func _brass(song: Song) -> void:
	var rng := song.rng
	var brass := func(n: Song.Note, _previous: Song.Note) -> PackedFloat32Array:
		return Inst.cs_brass([n.midi], song.steps_to_seconds(n.steps), rng)
	song.play("brass", Song.parse(8, THEME), brass)
	# The theme doubled on guitar an octave down, sliding into the long notes.
	var guitar := func(n: Song.Note, _previous: Song.Note) -> PackedFloat32Array:
		return Inst.guitar_note(DSP.midi_hz(n.midi - 12), song.steps_to_seconds(n.steps), false,
			1.0 if n.steps >= 4 else 0.0, 0.3 if n.steps >= 8 else 0.0, rng)
	song.play("solo", Song.parse(8, THEME), guitar)
	# C: a low brass call over the checkpoint, twice.
	for bar: int in [16, 18]:
		song.add("brass", Inst.cs_brass([59, 66], song.steps_to_seconds(28.0), rng), song.at(bar), 0.7)


static func _fx(song: Song) -> void:
	var rng := song.rng
	var bar_seconds: float = song.steps_to_seconds(16.0)
	var suck := Inst.reverse_crash(bar_seconds, rng)
	song.add("fx", suck, song.at(8) - suck.size(), 0.8)
	song.add("fx", Inst.boom(1.6, rng), song.at(8), 1.0)
	var rise := Inst.riser(bar_seconds, rng)
	song.add("fx", rise, song.at(20) - rise.size(), 0.8)
