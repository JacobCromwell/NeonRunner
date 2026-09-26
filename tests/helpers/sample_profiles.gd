class_name SampleProfiles
extends RefCounted
## Profiles for screen tests and the screens showcase: a fresh one, and a "rich" one partway
## through Zone 1 with credits, items (some switched off), stock, records and the second
## difficulty tier open, so every screen has something in each of its states.


static func fresh() -> Profile:
	return Profile.new()


static func rich() -> Profile:
	var p := Profile.new()
	p.add_earned(12450)
	p.set_tier(&"weapon", 2)
	p.set_tier(&"claws", 1)
	p.set_tier(&"magnet", 1)
	p.set_equipped(&"magnet", false)
	p.add_stock(&"armor", 3)
	p.add_stock(&"shield", 5)
	p.add_stock(&"grapple", 1)
	p.add_stock(&"revive", 2)
	p.record_run("city/intro", 0, true, 0, 3, 0.0)
	p.record_run("city/1", 0, true, 12340, 3, 88.2)
	p.record_run("city/2", 0, false, 3100, 0, 41.0)
	p.record_run("city/2", 0, true, 9870, 2, 95.6)
	p.record_run("city/3", 0, false, 2200, 0, 30.5)
	p.unlocked_tier = 1
	p.stat_add("runs", 6)
	return p


## Completes every campaign step before `step_id` on the normal tier (levels with two stars), so
## the profile's next step is that one. Nothing happens for an unknown id.
static func complete_until(p: Profile, campaign: Campaign, step_id: String) -> void:
	if campaign.step(step_id) == null:
		return
	for s: CampaignStep in campaign.steps():
		if s.id == step_id:
			return
		p.record_run(s.id, 0, true, 5000 if s.is_level() else 0, 2 if s.is_level() else 3, 100.0)


## A boss fight's result for the results screen: the City's boss beaten in 88 s, or a death in its
## second phase.
static func boss_result(won: bool) -> RunResult:
	var ctx := RunContext.new()
	ctx.mode = RunContext.Mode.CAMPAIGN
	ctx.step = App.campaign.step("city/boss")
	ctx.boss = ctx.step.boss
	ctx.config = App.campaign.configure_boss(ctx.step, 5)
	ctx.tuning = App.tuning
	ctx.loadout = Loadout.new()
	var r := RunResult.new()
	r.context = ctx
	r.completed = won
	r.time = 88.0 if won else 41.5
	r.stats = {"kills": 2, "stomps": 3, "blocked": 1, "weak_points": 3 if won else 1, "phase": 3 if won else 2,
		"phases": 3, "time_bonus": ctx.boss.time_bonus(88.0) if won else 0}
	if won:
		r.score = 14100
		r.completion_bonus = ctx.boss.payout_credits
		r.credits_earned = r.completion_bonus
		r.stars = ctx.boss.stars_for(true, r.time)
		r.record = {"new_best": true, "stars_gained": r.stars, "first_clear": true}
	else:
		r.cause = "Test Core bolt"
		r.score = 1750
		r.record = {"new_best": false}
	return r


## A campaign result for the results screen: a clear of city/2, or a death in it.
static func result(completed: bool) -> RunResult:
	var ctx := RunContext.new()
	ctx.mode = RunContext.Mode.CAMPAIGN
	ctx.step = App.campaign.step("city/2")
	ctx.level_index = ctx.step.level_index
	ctx.config = App.campaign.configure(ctx.step, 5)
	ctx.tuning = App.tuning
	ctx.loadout = Loadout.new()
	var r := RunResult.new()
	r.context = ctx
	r.completed = completed
	r.stats = {"kills": 7, "stomps": 3, "blocked": 1, "ramps": 2, "longest_wall_run": 38.4}
	if completed:
		r.score = 12340
		r.credits_collected = 340
		r.completion_bonus = 200
		r.credits_earned = 540
		r.stars = 2
		r.time = 95.6
		r.distance = 1204.0
		r.record = {"new_best": true, "stars_gained": 0, "first_clear": false}
	else:
		r.cause = "Cyborg"
		r.score = 4210
		r.credits_collected = 180
		r.credits_earned = 36
		r.time = 44.2
		r.distance = 530.0
		r.record = {"new_best": false}
	return r
