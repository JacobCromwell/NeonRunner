class_name ZoneDef
extends Resource
## One zone (GDD §6): 1–3 levels plus a boss (the Marketplace has none), with its own look (skin) and
## music. Zones that aren't designed yet are placeholders: listed as "coming soon", with no levels.

@export var id: StringName = &""
@export var display_name: String = ""
## A line for the zone select screen.
@export var tagline: String = ""
## The zone's visuals (GDD §5: gameplay pieces are abstract; zones are skins). A zone without its own
## skin yet uses the grey-box skin (data/skins/greybox_skin.tres); zone skins live at
## data/skins/<zone id>_skin.tres. A level's own skin wins over this one (Campaign.configure).
@export var skin: ZoneSkin
## Music track name in data/audio/music_library.tres, by convention the zone's id. Until a zone's
## track is made, the Music player skips the name quietly and the menu music carries on.
@export var music: StringName = &""
@export var levels: Array[LevelConfig] = []
## The run speed of the zone's levels (GDD §3, owner's playtest September 30, 2026: about 21 m/s in
## the Neon City, rising zone by zone to about 25 m/s in the Golden Zone). A level may set its own
## (LevelConfig.run_speed); 0: the movement tuning's base run speed. The zone's boss fight runs at it too
## (Campaign.run_speed_for). The generator stretches its patterns and margins with it, and the enemies their
## along-track distances and speeds, so every warning and reaction window keeps its seconds
## (MovementTuning.pace). DESIGN-TBD: each zone's value (a straight rise from 21 to 25 m/s over the first six
## zones; the Casino's 23, added between the Marketplace's 22.6 and Corporate's 23.4, OPEN_QUESTIONS.md §D, item 380).
@export_range(0.0, 40.0, 0.1, "suffix:m/s") var run_speed: float = 0.0
## Optional cinematic before the first level.
@export var intro: CinematicDef
## Optional cinematic before the boss.
@export var boss_intro: CinematicDef
## The zone's boss (GDD §10); none for a zone that leads straight into the next (the Marketplace, into the
## Casino: owner, October 8, 2026).
@export var boss: BossDef
## Optional cinematic after the boss.
@export var outro: CinematicDef
## Part of the web demo (GDD §2: the demo is Zone 1 including its boss).
@export var in_demo: bool = false
## Not designed yet: shown locked as "coming soon".
@export var placeholder: bool = false
## DESIGN-TBD (GDD §8): the loadout the generator may assume players have by this zone. Empty in
## every zone for now, and nothing reads it yet.
@export var expected_loadout: PackedStringArray = PackedStringArray()
