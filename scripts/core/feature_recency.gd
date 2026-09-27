class_name FeatureRecency
extends Resource
## How a campaign level's pick weights follow how recently the campaign introduced each feature
## (GDD §5, owner's placeholder review P2 13: beyond the "every feature at least once" guarantee, a
## level's newest things get the most picks). In data/tuning/feature_recency.tres, set on the
## campaign (Campaign.feature_recency) and tunable live under F6 ("Restart level" rebuilds with it).
##
## Each pattern's pick weight is multiplied by factor(age), where age is how many levels ago the
## campaign introduced the newest feature the pattern requires (LevelConfig.feature_ages; 0 in the
## level that introduces it). Patterns that require no feature (gaps, fences, signs) aren't touched.
## With keep_feature_share on, the factors then only move picks between the level's features: at
## every pick the features' patterns together weigh what they weighed without the curve, so a level
## picks plain obstacles as often as before and gets no emptier or busier, only a different mix. A
## level's own feature_weights still apply on top (Corporate 2's military, The Hush's hosts).
##
## DESIGN-TBD (docs/questions/r5.md): the whole curve.

## Off: every feature competes on equal terms again (plus feature_weights), as before the curve.
@export var enabled: bool = true
## The factor in the level that introduces the feature.
@export_range(0.05, 10.0, 0.05) var introduced: float = 4.0
## One, two and three levels after its introduction.
@export_range(0.05, 10.0, 0.05) var one_level_later: float = 2.5
@export_range(0.05, 10.0, 0.05) var two_levels_later: float = 1.75
@export_range(0.05, 10.0, 0.05) var three_levels_later: float = 1.25
## Four levels after its introduction and later: less, but never zero.
@export_range(0.05, 10.0, 0.05) var older: float = 1.0
## Keep how often the level picks its features' patterns over plain obstacles (see the header).
@export var keep_feature_share: bool = true


## The factor for a feature introduced `age` levels ago (0 = this level). A feature the campaign
## hasn't dated (a negative age) keeps its weight.
func factor(age: int) -> float:
	if age < 0:
		return 1.0
	match age:
		0:
			return introduced
		1:
			return one_level_later
		2:
			return two_levels_later
		3:
			return three_levels_later
	return older
