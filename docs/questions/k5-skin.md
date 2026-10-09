# K5 (skin side): the Casino under the build budget

Raised while merging main into the Casino branch and bringing its chunk build time under the budget
(`SkinSuite.BUILD_BUDGET_MEAN_MS`, 4 ms a chunk at 6 lanes). The Casino's build read 4.4-4.5 ms on this
machine against the Marketplace's 3.7-3.9, so its dressing was thinned. Nothing here changes a hazard, a
collision, the roof (still whole) or the two names.

## DESIGN-TBD: how busy the street is (extends `docs/OPEN_QUESTIONS.md` item 420, "How much each kind of piece appears")

The placeholder densities in item 420 (and the roof's in item 421) were trimmed to buy back build time:

| export                | was  | now  |
|-----------------------|------|------|
| `balcony_share`       | 0.55 | 0.42 |
| `pipe_share`          | 0.55 | 0.42 |
| `unit_share`          | 0.50 | 0.25 |
| `lantern_share`       | 0.50 | 0.35 |
| `fan_share`           | 0.28 | 0.20 |
| `banner_share`        | 0.70 | 0.60 |
| `crossbeam_spacing`   | 32 m | 40 m |
| `bay_scale` (new)     | 1.0  | 1.5  |

`bay_scale` widens the shop windows' bays to 1.5 times the Marketplace's (the same piers, a third fewer, broader
windows), which also thins the citizens by a third. Measured on this machine (6 lanes, mean chunk build): the
street was 4.4-4.5 ms, it is now 3.8-3.9 (the Marketplace 3.7-3.9). Every one of these is an export on
`CasinoSkin`, so a busier street is a `.tres` edit away; the price is about 0.1-0.15 ms a chunk for each of the
three biggest (balconies and units together, the roof's hangings together, the window bays).

Question for the owner: is the thinner street fine, or should it be as busy as the reference and the build
budget (or the machine it is measured on) be revisited instead?

## Not a design question, for the orchestrator

- The skin budget's load factor (`REFERENCE_IDLE_MS` = 2.7, a 40-lane greybox build) reads 1.00 on the machines
  this was measured on, yet every skin's build there ran about 1.3 times slower than in earlier sessions
  (the Marketplace 2.4-2.8 ms then, 3.2-3.9 now; the pre-merge tree runs equally slowly today, so main did not
  cause it). A greybox build is mostly node creation, a GDScript-heavy skin build is not, so the load factor
  cannot see this. A reference that builds a skin-sized mesh in GDScript would.
