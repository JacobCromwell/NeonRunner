extends TestSuite
## The campaign data: zones, steps, difficulty curve, unlocking, the demo scope, and that every
## campaign level generates fairly for every lane count.


func run() -> void:
	var campaign := load("res://data/campaign/campaign.tres") as Campaign
	check(campaign != null and campaign.zones.size() >= 6, "the campaign lists 6+ zones (GDD §6)")
	if campaign == null:
		return
	var ids: PackedStringArray = []
	for s: CampaignStep in campaign.steps():
		ids.append(s.id)
	var expected := PackedStringArray(["city/intro", "city/1", "city/2", "city/3", "city/boss_intro", "city/boss",
		"city/outro", "gangland/intro", "gangland/1", "gangland/2", "gangland/3", "gangland/boss", "gangland/outro"])
	check(ids == expected, "steps run intro, levels, boss, outro per built zone: %s" % ", ".join(ids))
	check(campaign.level_count() == 6, "six campaign levels so far")
	var city: ZoneDef = campaign.zones[0]
	check(city.id == &"city" and city.in_demo, "Zone 1 is the Neon City and is the demo (owner decision)")
	check(campaign.zones[1].id == &"gangland" and not campaign.zones[1].in_demo, "Zone 2 is Gangland, full game only")
	for zi: int in range(2, campaign.zones.size()):
		check(campaign.zones[zi].placeholder, "zone %d is a placeholder until designed" % (zi + 1))

	# Every boss and cinematic is a slot until built.
	for s: CampaignStep in campaign.steps():
		if s.kind == CampaignStep.Kind.BOSS:
			check(s.boss != null and not s.boss.is_built(), "boss slot %s is a placeholder" % s.id)
		elif s.kind == CampaignStep.Kind.CINEMATIC:
			check(s.cinematic != null and not s.cinematic.is_built(), "cinematic slot %s is a placeholder" % s.id)

	# Difficulty rises level by level (GDD §6), and enemy scaling runs 0 → 1.
	var last: float = -1.0
	for i: int in campaign.level_count():
		var d: float = campaign.curve_difficulty(i)
		check(d > last, "the curve rises at level %d (%.2f)" % [i, d])
		last = d
	var first_level: CampaignStep = campaign.step("city/1")
	var last_level: CampaignStep = campaign.step("gangland/3")
	var c1: LevelConfig = campaign.configure(first_level, 5)
	var c6: LevelConfig = campaign.configure(last_level, 3, 1)
	check(c1.lane_count == 5 and c6.lane_count == 3, "configure sets the lane count")
	check(is_equal_approx(c1.enemy_scaling, 0.0) and is_equal_approx(c6.enemy_scaling, 1.0), "enemy scaling spans the campaign")
	check(c6.difficulty > campaign.configure(last_level, 3, 0).difficulty, "harder tiers raise difficulty")
	check(c1.skin != null, "levels take their zone's skin")
	check(c1 != first_level.level, "configure returns a copy")

	# Every campaign level generates cleanly for every lane count.
	for s: CampaignStep in campaign.steps():
		if not s.is_level():
			continue
		for lanes: int in [3, 5, 6]:
			var config: LevelConfig = campaign.configure(s, lanes)
			var gen := LevelGenerator.new()
			var layout: LevelLayout = gen.generate(config, tuning, LevelGenerator.load_for(config))
			var tag: String = "%s lanes=%d" % [s.id, lanes]
			check(gen.warnings.is_empty(), "no pattern warnings " + tag)
			check(layout.gaps.size() + layout.fences.size() > 8, "has content " + tag)
			check(layout.credits.size() > 20, "has credits " + tag + " (%d)" % layout.credits.size())
			check(config.duration_seconds >= 90.0 and config.duration_seconds <= 150.0, "90–150 s long (GDD §4) " + tag)
			for c: Dictionary in layout.credits:
				if c["surface"] != "wall":
					check(int(c["lane"]) >= 0 and int(c["lane"]) < lanes, "credit lane in range " + tag)
			if not s.level.has_feature("ceilings"):
				check(layout.hulls.is_empty(), "no ceilings before they're introduced " + tag)
			if not s.level.has_feature("ramps"):
				check(layout.ramps.is_empty(), "no ramps before they're introduced " + tag)

	# Unlocking follows the campaign order (with a fresh profile).
	var app: Node = tree.root.get_node_or_null(^"App")
	if app == null:
		return
	var saved: Profile = App.profile
	App.profile = Profile.new()
	var steps: Array[CampaignStep] = App.campaign.steps()
	check(App.step_unlocked(steps[0]) and not App.step_unlocked(steps[1]), "only the first step is open at first")
	App.complete_step(steps[0])
	check(App.step_unlocked(steps[1]) and App.next_unfinished_step() == steps[1], "finishing a step opens the next")
	BuildFlavor.set_override(BuildFlavor.Kind.WEB_DEMO)
	check(App.in_demo_scope(steps[1]) and not App.in_demo_scope(App.campaign.step("gangland/1")),
		"the web demo covers Zone 1 only (GDD §2)")
	BuildFlavor.set_override(-1)
	check(App.in_demo_scope(App.campaign.step("gangland/1")), "the full game covers everything")
	App.profile = saved
