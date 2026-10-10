class_name Campaign
extends Resource
## The campaign: zones in order (GDD §6). Each built zone contributes its steps: intro cinematic,
## levels, boss intro cinematic, boss, outro cinematic. Levels get their difficulty from an
## automatic curve across the whole campaign plus each level's own bias, and their enemy scaling
## from their position (GDD §6). A level off the curve (LevelConfig.off_curve, task D10c: the Beach's,
## added between Corporate and the Dead Zone after the owner's playtests) plays at its own difficulty
## and enemy scaling instead, and leaves the curve's count and the other levels' feature ages alone, so
## every level on the curve keeps what it had.

@export var zones: Array[ZoneDef] = []
## DESIGN-TBD: difficulty of the first and last campaign levels (FB 4, reopened by the owner's playtests and G1); levels in between follow the curve,
## so each level is slightly harder than the last (GDD §6). Levels add their difficulty_bias on top:
## Golden 2's makes it the campaign's peak (GDD §5, proposed), with Golden 3 a little below it.
@export_range(0.0, 1.0, 0.05) var difficulty_start: float = 0.1
@export_range(0.0, 1.0, 0.05) var difficulty_end: float = 0.9
## Shapes the curve: 1 = linear, above 1 = gentle start and steeper end, below 1 lifts the early and
## middle levels. DESIGN-TBD, the campaign's is 0.79 (task K4): no level gets easier when levels are added
## (owner, October 9, 2026, GDD §6), so with the Casino's two levels in, every level is at least as hard as
## on the 15-level linear curve before them; Marketplace 2 binds it (0.500 or more up to about 0.84). 0.79
## makes the Marketplace a little harder (0.469 and 0.516), keeps City 1 and Golden 3 as they were, and its
## levels' own builds miss the fewest of the design properties their suites check (one, as with 0.81 and
## 0.82, which leave Marketplace 2 under +0.01; docs/OPEN_QUESTIONS.md §D, item 528 has the scan).
@export_range(0.3, 3.0, 0.01) var difficulty_curve_exponent: float = 1.0
## Levels each placeholder zone will have once designed (GDD §6: 1–3 per zone). The curve spans the
## planned campaign, so the first zones don't jump to end-game difficulty while later zones are missing.
@export_range(1, 3) var planned_levels_per_placeholder_zone: int = 3
## The harder difficulty tiers unlocked after finishing the game (GDD §6; FB 5).
## Index 0 is the normal game.
@export var tier_names: PackedStringArray = PackedStringArray(["Normal", "Hard", "Insane"])
@export var tier_difficulty_bonus: PackedFloat32Array = PackedFloat32Array([0.0, 0.15, 0.3])
@export var tier_speed_multiplier: PackedFloat32Array = PackedFloat32Array([1.0, 1.1, 1.2])
## The recency curve for every campaign level's pick weights (GDD §5, owner's review P2 13: a level's
## newest things get the most picks): configure() gives each level's copy this curve and how many
## levels ago the campaign introduced each of its features (LevelConfig.feature_ages).
@export var feature_recency: FeatureRecency

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


## The campaign's difficulty for the level at place `level_index` on its curve (CampaignStep.level_index), before
## its bias.
func curve_difficulty(level_index: int) -> float:
	var t: float = level_progress(level_index)
	return lerpf(difficulty_start, difficulty_end, pow(t, difficulty_curve_exponent))


## 0 for the first level on the curve, 1 for the last level of the planned campaign's curve.
func level_progress(level_index: int) -> float:
	var n: int = curve_level_count()
	return 0.0 if n <= 1 else clampf(float(level_index) / float(n - 1), 0.0, 1.0)


## Built levels plus the levels planned for placeholder zones.
func planned_level_count() -> int:
	var n: int = level_count()
	for zone: ZoneDef in zones:
		if zone.placeholder or zone.levels.is_empty():
			n += planned_levels_per_placeholder_zone
	return n


## The levels the difficulty curve spans (task D10c): the planned levels but those off it (LevelConfig.off_curve:
## the Beach's, added after the owner's playtests), so every level on it keeps its place.
func curve_level_count() -> int:
	var n: int = planned_level_count()
	for s: CampaignStep in steps():
		if s.is_level() and s.level.off_curve:
			n -= 1
	return n


## The enemy scaling level step `s` plays at: its place on the curve's (level_progress), or its own off the
## curve (LevelConfig.off_curve).
func level_scaling(s: CampaignStep) -> float:
	return s.level.enemy_scaling if s.level.off_curve else level_progress(s.level_index)


func tier_count() -> int:
	return tier_names.size()


## A copy of the step's level, ready to generate: lane count, difficulty (curve + bias + tier),
## enemy scaling, its run speed (run_speed_for), the zone's skin if the level has none, and the
## recency curve with its features' ages (feature_ages). A level off the curve (LevelConfig.off_curve, task
## D10c: the Beach's) keeps its own difficulty, plus the tier's bonus, and its own enemy scaling.
func configure(s: CampaignStep, lane_count: int, difficulty_tier: int = 0) -> LevelConfig:
	var config: LevelConfig = s.level.duplicate() as LevelConfig
	config.lane_count = lane_count
	var bonus: float = tier_difficulty_bonus[clampi(difficulty_tier, 0, tier_difficulty_bonus.size() - 1)] \
		if not tier_difficulty_bonus.is_empty() else 0.0
	if s.level.off_curve:
		config.difficulty = clampf(s.level.difficulty + bonus, 0.0, 1.0)
	else:
		config.difficulty = clampf(curve_difficulty(s.level_index) + s.level.difficulty_bias + bonus, 0.0, 1.0)
	config.enemy_scaling = level_scaling(s)
	config.run_speed = run_speed_for(s, difficulty_tier)
	if config.skin == null and s.zone.skin != null:
		config.skin = s.zone.skin
	config.feature_ages = feature_ages(s)
	config.feature_recency = feature_recency
	return config


## How many levels ago the campaign introduced each of step `s`'s features: 0 for a feature `s`
## introduces (the first level that lists it), 1 for one the level before introduced, and so on.
## A feature left out of some levels in between (manhole screeches outside street zones) still
## counts from its first level. A level on the curve counts the levels on it (their places, level_index) and
## leaves out the levels off it (LevelConfig.off_curve, task D10c), so the levels after the Beach keep their
## ages; a level off the curve counts every level before it, in the order they're played, but a mini-game level
## (LevelConfig.minigame: the Beach's volleyball match, which is off the curve and has no features).
func feature_ages(s: CampaignStep) -> Dictionary[String, int]:
	var out: Dictionary[String, int] = {}
	if s == null or s.level == null:
		return out
	for f: String in s.level.features:
		out[f] = 0
	if s.level.off_curve:
		# A mini-game level (the Beach's volleyball match) places no features, so it counts as no level ago: Sunset
		# Strip, after it, keeps the ages and recency it had before it was added.
		var before: Array[CampaignStep] = []
		for other: CampaignStep in steps():
			if other.is_level() and other.index < s.index and not other.is_minigame():
				before.append(other)
		for i: int in before.size():
			for f: String in before[i].level.features:
				if out.has(f):
					out[f] = maxi(out[f], before.size() - i)
		return out
	for other: CampaignStep in steps():
		if not other.is_level() or other.level.off_curve or other.level_index >= s.level_index:
			continue
		for f: String in other.level.features:
			if out.has(f):
				out[f] = maxi(out[f], s.level_index - other.level_index)
	return out


## The boss step's arena, ready to plan (BossArena.base_config): lane count, the arena's own
## difficulty plus the tier's bonus (bosses keep their own difficulty rather than the level curve),
## its run speed like a level's (run_speed_for: its zone's, times the tier's multiplier; GDD §3, the
## fight is as fast as the zone's levels), enemy scaling as in the zone's last level (enemies a boss
## brings in fight like the zone's; level_scaling, so after a level off the curve its own), the zone's
## skin unless the arena has its own, and the sky of the level just before it unless the arena has its
## own (owner, October 8, 2026: a fight after a level whose sky has turned keeps that sky; LevelConfig.sky).
func configure_boss(s: CampaignStep, lane_count: int, difficulty_tier: int = 0) -> LevelConfig:
	var config: LevelConfig = BossArena.base_config(s.boss)
	config.lane_count = lane_count
	var bonus: float = tier_difficulty_bonus[clampi(difficulty_tier, 0, tier_difficulty_bonus.size() - 1)] \
		if not tier_difficulty_bonus.is_empty() else 0.0
	config.difficulty = clampf(config.difficulty + bonus, 0.0, 1.0)
	config.run_speed = run_speed_for(s, difficulty_tier)
	var before: CampaignStep = null
	for other: CampaignStep in steps():
		if other.index >= s.index:
			break
		if other.is_level():
			before = other
	config.enemy_scaling = level_scaling(before) if before != null else level_progress(0)
	if config.skin == null and s.zone != null and s.zone.skin != null:
		config.skin = s.zone.skin
	if config.sky == null and before != null and before.zone == s.zone:
		config.sky = before.level.sky
	return config


func speed_multiplier(difficulty_tier: int) -> float:
	if tier_speed_multiplier.is_empty():
		return 1.0
	return tier_speed_multiplier[clampi(difficulty_tier, 0, tier_speed_multiplier.size() - 1)]


## The run speed of level or boss step `s` (GDD §3, owner's playtest September 30, 2026: it rises zone
## by zone, and a boss fight runs at its zone's speed like the levels before it): the level's own
## (LevelConfig.run_speed; a boss's arena config's, BossDef.arena) or its zone's (ZoneDef.run_speed),
## times the difficulty tier's speed multiplier. 0 when none sets one: the run then takes the movement
## tuning's base speed, and App applies the tier's multiplier to that.
func run_speed_for(s: CampaignStep, difficulty_tier: int = 0) -> float:
	if s == null:
		return 0.0
	var own: LevelConfig = s.level
	if own == null and s.boss != null:
		own = s.boss.arena
	if own == null and s.boss == null:
		return 0.0
	var speed: float = own.run_speed if own != null else 0.0
	if speed <= 0.0 and s.zone != null:
		speed = s.zone.run_speed
	return speed * speed_multiplier(difficulty_tier) if speed > 0.0 else 0.0


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
			s.number_in_zone = li + 1
			# A level off the curve (task D10c) takes the place of the level on it before it, and leaves the next
			# level on it its own.
			if s.level.off_curve:
				s.level_index = maxi(level_index - 1, 0)
			else:
				s.level_index = level_index
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
