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
## A feature whose rules keep only so many of its enemies is boosted no further than its cap
## (max_factor), so the curve never spends picks on enemies the rules would drop, leaving their
## stretch empty. With keep_feature_share on, the factors then only move picks between the level's
## features: at every pick the features' patterns together weigh what they weighed without the
## curve, so a level picks plain obstacles as often as before and gets no emptier or busier, only a
## different mix. With keep_share_by_kind, that holds kind by kind (LevelGenerator.pattern_kind):
## patterns with enemies keep the number of enemies they place, those with obstacles only and the
## safe ones (a plain ceiling, a ramp, a speed pad) their share, so the curve never trades an enemy
## for an obstacle or a safe mechanic, and no level gets easier. A level's own feature_weights still
## apply on top (Corporate 2's military, The Hush's hosts).
##
## DESIGN-TBD (docs/questions/r5.md): the whole curve, and the caps.

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
## Features whose extra picks the level can't keep, and the most the curve multiplies the weight of
## the patterns that require them by (1: never boosted). Their patterns keep that factor and are
## never scaled back with the rest (keep_feature_share). The data caps those whose rules keep only
## so many of their enemies (the host: one Bad Dream chase at a time; the hover truck: one at a time
## and one a level early on; the drone: its waves apart; the Octodog: one at a time, on a clear
## stretch; the Buzz Overdrive: one cut at a time, owner, October 10, 2026) and the vent screech (rare,
## GDD §9.5).
@export var max_factor: Dictionary[String, float] = {}
## Keep how often the level picks its features' patterns over plain obstacles (see the header).
@export var keep_feature_share: bool = true
## With keep_feature_share: keep it for each kind of pattern apart, and the patterns with enemies
## the number of enemies they place (see the header).
@export var keep_share_by_kind: bool = true


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
