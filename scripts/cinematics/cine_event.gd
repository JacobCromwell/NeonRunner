class_name CineEvent
extends Resource
## Something a cinematic does at a moment (CineTimeline.events): a sound, a music cue, a text card, an
## effect, or a cue its script hears.
##
## Text may name the slot's data, filled in when it plays: {zone} (the zone's name), {zone_number},
## {boss} (the zone's boss) and {title} (the slot's title, CinematicDef.title).

enum Kind { SOUND, MUSIC, TEXT, EFFECT, CUE }

## Effects (EFFECT's `name`).
const FADE_IN: StringName = &"fade_in"
const FADE_OUT: StringName = &"fade_out"
const FLASH: StringName = &"flash"
const SHAKE: StringName = &"shake"
const LETTERBOX_IN: StringName = &"letterbox_in"
const LETTERBOX_OUT: StringName = &"letterbox_out"
const EFFECTS: Array[StringName] = [FADE_IN, FADE_OUT, FLASH, SHAKE, LETTERBOX_IN, LETTERBOX_OUT]
## A music cue's name for the slot's own music: the zone's track, or before a boss the fight's
## (BossDef.music, else the zone's), so a later change of either reaches the cinematic.
const ZONE_MUSIC: StringName = &"@zone"

@export_range(0.0, 120.0, 0.05, "or_greater", "suffix:s") var time: float = 0.0
@export var kind: Kind = Kind.SOUND
## SOUND: a sound effect's name (data/audio/sfx_library.tres). MUSIC: a music track's name
## (data/audio/music_library.tres), ZONE_MUSIC, or empty for no music (it fades out); a track the
## library doesn't list yet is skipped quietly and the music playing carries on, so a song added later
## under that name just plays. EFFECT: one of EFFECTS. CUE: any name (CinematicSequencer.cue).
@export var name: StringName = &""
## TEXT: the card's title line, and the smaller line above it (may be empty).
@export var text: String = ""
@export var caption: String = ""
## TEXT: seconds the card stays up; MUSIC: the crossfade; fades, letterbox, flash and shake: how long
## they take.
@export_range(0.0, 30.0, 0.05, "or_greater", "suffix:s") var duration: float = 1.0
## FLASH: how bright (0-1); SHAKE: how far the camera shakes (metres).
@export_range(0.0, 2.0, 0.01) var strength: float = 1.0
## Fades and flashes: their colour.
@export var color: Color = Color.BLACK
## SOUND: dB on top of the sound's own level in the library.
@export_range(-40.0, 12.0, 0.5, "suffix:dB") var volume_db: float = 0.0
