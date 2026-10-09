class_name ZoneDef
extends Resource
## One zone (GDD §6): 1–3 levels plus a boss, with its own look (skin) and music. Zones that
## aren't designed yet are placeholders: listed as "coming soon", with no levels.

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
## (LevelConfig.run_speed); 0: the movement tuning's base run speed. Boss fights keep the base speed.
## The generator stretches its patterns and margins with it, and the enemies their along-track
## distances and speeds, so every warning and reaction window keeps its seconds
## (MovementTuning.pace). DESIGN-TBD: each zone's value (a straight rise from 21 to 25 m/s).
@export_range(0.0, 40.0, 0.1, "suffix:m/s") var run_speed: float = 0.0
## Optional cinematic before the first level.
@export var intro: CinematicDef
## Optional cinematic before the boss.
@export var boss_intro: CinematicDef
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


## Level `number` (1 = the zone's first) ready to generate outside the campaign (task D10b: a zone with no
## campaign slot yet, such as the Beach, plays through App.start_zone_level, and its tests build it the same
## way): a copy at `lane_count` lanes, in the zone's look unless the level has its own skin, at the zone's run
## speed unless it has its own. Its difficulty and enemy scaling are the level's own (there's no campaign curve
## to place it on), and no recency curve shapes its picks. Null if the zone has no such level.
func standalone_level(number: int, lane_count: int) -> LevelConfig:
	if number < 1 or number > levels.size() or levels[number - 1] == null:
		return null
	var config: LevelConfig = levels[number - 1].duplicate() as LevelConfig
	config.lane_count = lane_count
	if config.skin == null:
		config.skin = skin
	if config.run_speed <= 0.0:
		config.run_speed = run_speed
	return config
