extends RefCounted
## "Gangland", Zone 2 (grimy post-apocalyptic streets). Industrial metal at 120 BPM in D phrygian:
## heavier and dirtier than the city, with anvil clanks, a crushed synth bass, mains hum and crackle.
## 20 bars = 40 s:
##   A  bars 1–8    syncopated drop-D groove riff (dotted-eighth chugs, the kick locked to the guitar),
##                  half-time snare, anvil backbeat; a tritone turn every fourth bar
##   B  bars 9–16   the chorus: four-on-the-floor stomp, machine hiss in sixteenths, open chords
##                  (D D Bb C D D Ab A) under a slow, sliding dirty synth lead
##   C  bars 17–20  stop-start breakdown with a power-down, then sixteenth chugs and a riser back to A

const Song = preload("res://tools/asset_gen/music_song.gd")
const Inst = preload("res://tools/asset_gen/music_instruments.gd")
const DSP = preload("res://tools/asset_gen/sfx_dsp.gd")

const GROOVE: Array = [
	"D2m . . D2m . . D2m . . D2m . . D2m . Eb2 -",
	"D2m . . D2m . . D2m . G2 - - - F2 - Eb2 -",
	"D2m . . D2m . . D2m . . D2m . . D2m . Eb2 -",
	"D2m . . D2m . . D2m . Ab2 - - - G2 - F2 -",
]
const GROOVE_TURN: Array = [
	"D2m . . D2m . . D2m . . D2m . . D2m . Eb2 -",
	"D2m . . D2m . . D2m . G2 - - - F2 - Eb2 -",
	"D2m . . D2m . . D2m . . D2m . . D2m . Eb2 -",
	"D2m . . D2m . . D2m . C3 - - - Bb2 - A2 -",
]
const CHORUS_ROOTS: Array = ["D2", "D2", "Bb2", "C3", "D2", "D2", "Ab2", "A2"]
const BREAKDOWN: Array = [
	"D2 - - . . . D2 - - . . . D2 - . .",
	"D2 - - . . . D2 - - . . . Eb2 - - -",
	"D2 - - . . . D2 - - . . . D2 - . .",
	"D2m D2m D2m D2m D2m D2m D2m D2m Bb2 - - - A2 - - -",
]
const SIREN: Array = [
	"D5 - - - - - - - Eb5 - - - D5 - - -",
	"C5 - - - - - - - Bb4 - - - A4 - - -",
	"D5 - - - - - - - F5 - - - Eb5 - - -",
	"C5 - - - - - - - - - - - G4 - - -",
	"D5 - - - - - - - Eb5 - - - F5 - - -",
	"G5 - - - - - - - F5 - - - Eb5 - - -",
	"Eb5 - - - - - - - C5 - - - Ab4 - - -",
	"A4 - - - - - - - C#5 - - - E5 - - -",
]


static func compose() -> Song:
	var song := Song.new(120.0, 20, 1201)
	song.sections = [[0, "A groove"], [8, "B chorus"], [16, "C breakdown"]]
	_drums(song)
	_guitars(song)
	_bass(song)
	_lead(song)
	_grime(song)
	_fx(song)
	song.echo("lead", 3.0, 0.35, 1800.0, 0.3)
	song.echo("machine", 1.5, 0.3, 4000.0, 0.25)
	song.mixdown({"drums": -10.0, "bass": -12.5, "gtr": -10.5, "lead": -13.5, "machine": -20.0,
		"grime": -27.0, "fx": -19.0}, -16.0)
	return song


static func _drums(song: Song) -> void:
	var rng := song.rng
	var kick: Array = []
	var snare: Array = []
	var hiss: Array = []
	for v: int in 3:
		var k := DSP.kick(0.4, 140.0, 44.0, rng)
		DSP.drive(k, 3.0)
		DSP.crush(k, 8, 16000.0)
		kick.append(k)
		var s := DSP.snare(0.45, 165.0, 0.8, rng)
		DSP.mix(s, DSP.metal_hit(0.3, 430.0, 0.09, rng), 0.0, 0.45)
		DSP.crush(s, 7, 12000.0)
		snare.append(s)
		var h := DSP.noise(0.09, rng)
		DSP.filter(h, &"bandpass", 5200.0, 1.5)
		DSP.envelope(h, 0.0005, 0.018, 0.004)
		DSP.crush(h, 6, 11025.0)
		hiss.append(h)
	var anvil: Array = [DSP.metal_hit(0.5, 310.0, 0.16, rng), DSP.metal_hit(0.5, 318.0, 0.16, rng)]
	var pipe: Array = [DSP.metal_hit(0.3, 820.0, 0.06, rng)]
	var crash_sound := DSP.crash(2.2, rng)
	DSP.crush(crash_sound, 8, 14000.0)
	var crash: Array = [crash_sound]

	# A: the kick follows the guitar; the snare is half-time, the anvil clanks on 2 and 4.
	var groove_kick: String = "x..x..x..x..x.x." + "x..x..x.x...x.x." + "x..x..x..x..x.x." + "x..x..x.x...x.x."
	song.drum("drums", 0, groove_kick.repeat(2), kick, 1.0)
	song.drum("drums", 0, "........x.......".repeat(8), snare, 0.9)
	song.drum("drums", 0, "....x.......x...".repeat(8), anvil, 0.55)
	song.drum("drums", 0, "x.x.x.x.x.x.x.x.".repeat(7) + "x.x.x.x.x.x.....", hiss, 0.3)
	song.drum("drums", 3, "..............x.", pipe, 0.5)
	song.drum("drums", 7, "..........o.x.xx", snare, 0.8)
	song.drum("drums", 0, "X", crash, 0.5)
	song.drum("drums", 4, "x", crash, 0.4)
	# B: four-on-the-floor stomp, snare and anvil together on 2 and 4, sixteenth machine hiss.
	song.drum("drums", 8, "x...x...x...x...".repeat(3) + "x...x...x...x.x.", kick, 1.0)
	song.drum("drums", 12, "x...x...x...x...".repeat(3) + "x...x...x.x.xxxx", kick, 1.0)
	song.drum("drums", 8, "....x.......x...".repeat(7) + "....x.......xxXX", snare, 0.9)
	song.drum("drums", 8, "....x.......x...".repeat(8), anvil, 0.4)
	song.drum("machine", 8, "xoxoxoxoxoxoxoxo".repeat(8), hiss, 1.0)
	song.drum("drums", 8, "X", crash, 0.55)
	song.drum("drums", 12, "x", crash, 0.45)
	# C: every chord hit lands with kick, crash and anvil; then a sixteenth build.
	var stabs: String = "x.....x.....x..." + "x.....x.....x..." + "x.....x.....x..."
	song.drum("drums", 16, stabs, kick, 1.1)
	song.drum("drums", 16, stabs, crash, 0.3)
	song.drum("drums", 16, stabs, anvil, 0.6)
	song.drum("drums", 19, "xxxxxxxxx...x...", kick, 1.0)
	song.drum("drums", 19, "....oooxxxxxXXXX", snare, 0.85)


static func _guitars(song: Song) -> void:
	var rng := song.rng
	var chug := func(n: Song.Note, _previous: Song.Note) -> PackedFloat32Array:
		var key: String = "gtr:%d:%d:%s:%d" % [n.midi, n.steps, n.muted, rng.randi() % 3]
		return song.cached(key, func() -> PackedFloat32Array:
			return Inst.chord(DSP.midi_hz(n.midi), song.steps_to_seconds(n.steps), n.muted, rng))
	var bars: Array = []
	bars.append_array(GROOVE + GROOVE_TURN)
	for root: String in CHORUS_ROOTS:
		bars.append("R - - - Rm . Rm . R - Rm . Rm . Rm Rm".replace("R", root))
	bars.append_array(BREAKDOWN)
	song.play("gtr", Song.parse(0, bars), chug)


static func _bass(song: Song) -> void:
	var rng := song.rng
	var note := func(n: Song.Note, _previous: Song.Note) -> PackedFloat32Array:
		var steps: float = 1.0 if n.muted else n.steps - 0.2
		return song.cached("bass:%d:%.1f" % [n.midi, steps], func() -> PackedFloat32Array:
			return Inst.dirty_bass(DSP.midi_hz(n.midi), song.steps_to_seconds(steps), rng))
	# The bass doubles the guitar's riff; its square adds the octave below.
	var bars: Array = []
	bars.append_array(GROOVE + GROOVE_TURN)
	for root: String in CHORUS_ROOTS:
		bars.append("R - R - R - R - R - R - R - R -".replace("R", root))
	bars.append_array(BREAKDOWN)
	song.play("bass", Song.parse(0, bars), note)


static func _lead(song: Song) -> void:
	var rng := song.rng
	var siren := func(n: Song.Note, previous: Song.Note) -> PackedFloat32Array:
		var from_hz: float = DSP.midi_hz(previous.midi) if previous != null else DSP.midi_hz(n.midi - 1)
		return Inst.dirty_lead(DSP.midi_hz(n.midi), song.steps_to_seconds(n.steps), from_hz, 0.45, rng)
	song.play("lead", Song.parse(8, SIREN), siren)


## Mains hum, crackle and static: the broken-amp grime under the whole loop.
static func _grime(song: Song) -> void:
	var rng := song.rng
	var n: int = song.length
	var bed := DSP.noise(song.seconds(), rng)
	DSP.filter(bed, &"bandpass", 2500.0, 0.7)
	var hum := PackedFloat32Array()
	hum.resize(n)
	# 50 Hz and harmonics: a whole number of cycles in the 40 s loop, so it wraps cleanly.
	for i: int in n:
		var t: float = float(i) / DSP.RATE
		hum[i] = 0.5 * sin(TAU * 50.0 * t) + 0.3 * sin(TAU * 100.0 * t) + 0.2 * sin(TAU * 150.0 * t) + 0.1 * sin(TAU * 250.0 * t)
	song.add("grime", hum, 0, 1.0)
	song.add("grime", bed, 0, 0.12)
	for c: int in int(song.seconds() * 7.0):
		var pop := DSP.noise(rng.randf_range(0.001, 0.004), rng)
		DSP.filter(pop, &"highpass", 1500.0)
		song.add("grime", pop, rng.randi_range(0, n - 1), rng.randf_range(0.3, 1.2))
	DSP.crush(song.stem("grime"), 8, float(DSP.RATE))


static func _fx(song: Song) -> void:
	var rng := song.rng
	var bar_seconds: float = song.steps_to_seconds(16.0)
	var suck := Inst.reverse_crash(bar_seconds, rng)
	DSP.crush(suck, 8, 14000.0)
	song.add("fx", suck, song.at(8) - suck.size(), 0.8)
	# A machine powering down between the breakdown's second and last stabs.
	var down := DSP.fm(0.6, func(u: float) -> float: return DSP.sweep(900.0, 55.0, u), 2.0,
		func(u: float) -> float: return 3.0 - 2.0 * u)
	DSP.envelope(down, 0.003, 0.35, 0.05)
	DSP.crush_sweep(down, 10.0, 4.0, 24000.0, 2000.0)
	song.add("fx", down, song.at(17, 7), 0.9)
	var rise := Inst.riser(bar_seconds, rng)
	song.add("fx", rise, song.at(20) - rise.size(), 0.9)
	song.add("fx", Inst.boom(1.5, rng), song.at(16), 1.0)
