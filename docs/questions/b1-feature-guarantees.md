# Questions from b1-feature-guarantees (every feature appears in every campaign level)

1. **Where a guaranteed enemy goes** (GDD §5: earlier features keep appearing). When the rules have
   dropped every host or every Octodog in a campaign level, those rules add one themselves where it fits
   every rule; otherwise the generator builds the level again with a pick of the missing feature forced
   at a new spot. Should a guaranteed one go somewhere in particular (early, late, spread out), or is
   anywhere that fits fine?
   - Placeholder: a spot chosen at random among those that fit (`DESIGN-TBD` in
     `scripts/enemies/host_rules.gd` and `scripts/enemies/octodog_rules.gd`). The generator's forced
     picks go to fixed shares of the level (`GUARANTEE_SHARES` in `scripts/world/level_generator.gd`).

2. **Introductions that come late** (GDD §5, §6; OPEN_QUESTIONS "Campaign restructure" item 2). A
   level's new feature is placed right at its start, but an older feature's rules can clear it away. It
   then first appears later in the level. Over 100 random seeds, 6% of introductions came more than
   210 m after their start (none were missing). Two cases account for almost all of them:
   - **Dead Zone 1's first host** (40% of generations): the first drone wave arrives during the Bad
     Dream's chase. The drones own every anti-grav pad from their first wave on (GDD §9.6), so the chase
     can't get its pads and that host is left out.
   - **Marketplace 2's first vent screech** (36%): a hover truck's lane or the drones' pads clear it.

   Should the older feature make way for the level's new one (for example, no drone wave during an
   introduced host's chase), or is "a little later in the level" fine?
   - Placeholder: the older feature's rules win, as before. The campaign tests allow up to 10% of
     introductions to come late (`tests/suites/test_campaign.gd`).
