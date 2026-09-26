class_name Campaign
extends Resource
## The campaign: zones in order (GDD §6). Each built zone contributes its steps: intro cinematic,
## levels, boss intro cinematic, boss, outro cinematic. Levels get their difficulty from an
## automatic curve across the whole campaign plus each level's own bias, and their enemy scaling
## from their position (GDD §6).

@export var zones: Array[ZoneDef] = []
## Difficulty of the first and last campaign levels; levels in between follow the curve.
@export_range(0.0, 1.0, 0.05) var difficulty_start: float = 0.1
@export_range(0.0, 1.0, 0.05) var difficulty_end: float = 0.9
## Shapes the curve: 1 = linear, above 1 = gentle start and steeper end.
@export_range(0.3, 3.0, 0.05) var difficulty_curve_exponent: float = 1.0
## Levels each placeholder zone will have once designed (GDD §6: 1–3 per zone). The curve spans the
## planned campaign, so the first zones don't jump to end-game difficulty while later zones are missing.
@export_range(1, 3) var planned_levels_per_placeholder_zone: int = 3
## DESIGN-TBD: the harder difficulty tiers unlocked after finishing the game (GDD §6).
## Index 0 is the normal game.
@export var tier_names: PackedStringArray = PackedStringArray(["Normal", "Hard", "Insane"])
@export var tier_difficulty_bonus: PackedFloat32Array = PackedFloat32Array([0.0, 0.15, 0.3])
@export var tier_speed_multiplier: PackedFloat32Array = PackedFloat32Array([1.0, 1.1, 1.2])

var _steps: Array[CampaignStep] = []


## Every step in order, built once.
func steps() -> Array[CampaignStep]:
	if _steps.is_empty():
		_build_steps()
	return _steps


func step(id: String) -> CampaignStep:
	for s: CampaignStep in steps():
		if s.id == id:
			return s
	return null


func next_step(current: CampaignStep) -> CampaignStep:
	var all: Array[CampaignStep] = steps()
	var i: int = current.index + 1
	return all[i] if i < all.size() else null


## Number of levels across every built zone.
func level_count() -> int:
	var n: int = 0
	for s: CampaignStep in steps():
		if s.is_level():
			n += 1
	return n


## The campaign's difficulty for level `level_index` (0-based among all levels), before its bias.
func curve_difficulty(level_index: int) -> float:
	var t: float = level_progress(level_index)
	return lerpf(difficulty_start, difficulty_end, pow(t, difficulty_curve_exponent))


## 0 for the first level, 1 for the last level of the planned campaign.
func level_progress(level_index: int) -> float:
	var n: int = planned_level_count()
	return 0.0 if n <= 1 else clampf(float(level_index) / float(n - 1), 0.0, 1.0)


## Built levels plus the levels planned for placeholder zones.
func planned_level_count() -> int:
	var n: int = level_count()
	for zone: ZoneDef in zones:
		if zone.placeholder or zone.levels.is_empty():
			n += planned_levels_per_placeholder_zone
	return n


func tier_count() -> int:
	return tier_names.size()


## A copy of the step's level, ready to generate: lane count, difficulty (curve + bias + tier),
## enemy scaling, and the zone's skin if the level has none.
func configure(s: CampaignStep, lane_count: int, difficulty_tier: int = 0) -> LevelConfig:
	var config: LevelConfig = s.level.duplicate() as LevelConfig
	config.lane_count = lane_count
	var bonus: float = tier_difficulty_bonus[clampi(difficulty_tier, 0, tier_difficulty_bonus.size() - 1)] \
		if not tier_difficulty_bonus.is_empty() else 0.0
	config.difficulty = clampf(curve_difficulty(s.level_index) + s.level.difficulty_bias + bonus, 0.0, 1.0)
	config.enemy_scaling = level_progress(s.level_index)
	if config.skin == null and s.zone.skin != null:
		config.skin = s.zone.skin
	return config


func speed_multiplier(difficulty_tier: int) -> float:
	if tier_speed_multiplier.is_empty():
		return 1.0
	return tier_speed_multiplier[clampi(difficulty_tier, 0, tier_speed_multiplier.size() - 1)]


func _build_steps() -> void:
	_steps.clear()
	var level_index: int = 0
	for zi: int in zones.size():
		var zone: ZoneDef = zones[zi]
		if zone.placeholder or zone.levels.is_empty():
			continue
		if zone.intro != null:
			_add_cinematic(zone, zi, "intro", zone.intro)
		for li: int in zone.levels.size():
			var s := CampaignStep.new()
			s.kind = CampaignStep.Kind.LEVEL
			s.id = "%s/%d" % [zone.id, li + 1]
			s.zone = zone
			s.zone_index = zi
			s.level = zone.levels[li]
			s.level_index = level_index
			s.number_in_zone = li + 1
			level_index += 1
			_append(s)
		if zone.boss_intro != null:
			_add_cinematic(zone, zi, "boss_intro", zone.boss_intro)
		if zone.boss != null:
			var b := CampaignStep.new()
			b.kind = CampaignStep.Kind.BOSS
			b.id = "%s/boss" % zone.id
			b.zone = zone
			b.zone_index = zi
			b.boss = zone.boss
			_append(b)
		if zone.outro != null:
			_add_cinematic(zone, zi, "outro", zone.outro)


func _add_cinematic(zone: ZoneDef, zi: int, slot: String, def: CinematicDef) -> void:
	var s := CampaignStep.new()
	s.kind = CampaignStep.Kind.CINEMATIC
	s.id = "%s/%s" % [zone.id, slot]
	s.zone = zone
	s.zone_index = zi
	s.cinematic = def
	_append(s)


func _append(s: CampaignStep) -> void:
	s.index = _steps.size()
	_steps.append(s)
