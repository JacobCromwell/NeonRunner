# E5e: Mecha Guppy and Captain Cogs, open questions

Raised by step E5e-a (the climb's core). The fight itself is built in E5e-b and E5e-c, which can answer
these as they go.

- **How the grapple's save onto the higher roof looks** (GDD §8, §10: "it pulls the runner up onto the
  higher roof"). The save today has no rope or hook on screen: the runner pops up out of the pit with the
  grapple's pull (`GameRules.grapple_pull_velocity`, 10 m/s). In the climb the save starts just under the
  higher roof's top, several metres above where the runner was falling, and moves them across into the
  roof's lane like a lane switch, so the jump up happens in one frame (the climbing camera eases after
  it). Placeholder: that lift (`Player._pull_up`, driven by the boss's `BossEncounter._grapple_save`), with
  no rope. Proposed for E5e-b: a glowing rope from the runner to the roof's edge for a moment as it fires
  (`RunEffects.line`, "the grapple rope", which nothing calls yet). Should the save instead reel the runner
  up visibly over a fraction of a second?
- **Where a revive after a fall puts the runner in the climb** (GDD §4: the revive item "revives on the
  spot"; §10). A fall in the climb ends in the floor Mecha Guppy has eaten, so a revive on the spot would
  drop the runner straight into another fall. Placeholder: a revive after a fall goes where the grapple's
  save goes (`Player.grapple_save` is asked with the cause, `&"revive"`), so in this fight it would put the
  runner on the higher roof, in its lane that leads up; the boss may answer the revive differently. Is that
  right, or should a revive put them back on the roof they fell from?
- **Landing back on the floor they came from** (GDD §10: "the rest drop them back onto the floor they came
  from, where Mecha Guppy is eating: falling into it is instant death"). Is landing on a part of the lower
  floor the shark hasn't eaten yet survivable (the runner carries on down there, where the next pad up may
  still be, or the shark eats them), or is every drop past the higher roof a death? Placeholder: none yet
  (E5e-b decides). E5e-a makes either possible: an intact floor below is landed on from any height, an
  eaten one (a gap) is a fall, and the falls count from the floor base the boss sets
  (`Player.floor_base`), so a death comes as far below the floor fallen from as it would below the street.
