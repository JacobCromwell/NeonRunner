extends RefCounted
## Generator rules for host cyborgs (GDD §9.7): hosts are cyborgs (type `cyborg` with
## `params.host`), so they follow the cyborg rules. Running them twice (a level with both the
## `cyborg` and `host` features) changes nothing the second time.

const CyborgRules = preload("res://scripts/enemies/cyborg_rules.gd")


static func apply(gen: LevelGenerator) -> void:
	CyborgRules.apply(gen)
