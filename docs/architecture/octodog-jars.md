# Architecture: Octodog jars

Part of the architecture notes; the index is [`docs/ARCHITECTURE.md`](../ARCHITECTURE.md).

## Octodog jars that break open (the Ice Lab)

Task Q5; GDD §5, Zone 9 (the owner, October 21, 2026): "to get extra value from the Octodog (§9.4), some jars hold a
curled-up Octodog instead of a brain. Sometimes smashing an Octodog jar doodad releases its Octodog into the world, and the
runner has to fight it." GDD §5's proposals are built as written: a jar is smashed the way every doodad is (the dash), a jar
that will release its Octodog looks the same as one that won't, the freed Octodog tumbles out, runs ahead to its usual
distance and starts its usual attack (§9.4) from the first wind-up, with its cue, never a lunge without warning, and it is
fought and killed like any Octodog. The level feature is `octodog_jar` (all three Ice Lab levels; Frost Foundry introduces
it from a start of its own at 0.02 of the level, before the gantryways' at 0.15). A level stands up to
`LevelConfig.octodog_jars` jars that release their dog (1 each), each only where its dog's usual attack has room, so a
crowded build has none (an occasional feature, as the ceiling scenarios: `OctodogJarRules.OCCASIONAL`), and
`LevelConfig.octodog_jar_decoys` decoys (2 or 3), jars dressed and broken the same whose dog never comes out. DESIGN-TBD
(`docs/questions/q5.md`).

**The files.**
- `scripts/enemies/octodog_jar_rules.gd`: the generator's rules (no patterns): where each jar stands, the plan of the dog it
  holds, the room it makes, the decoys (`after_doodads`), and `problems()`, the re-check of a finished layout
  (`LayoutChecks.check_octodog_jars`).
- `scripts/enemies/octodog.gd`: the held dog (phase `HELD`), its release (`TUMBLE`, then as after a lunge), the runtime
  "one dog at a time" (`_another_dog_charging`), `sounds_played` for the tests. `scripts/enemies/octodog_rules.gd`:
  `keep_out` (a held dog keeps the floor its charges use; a standing dog what it always kept).
- `scripts/enemies/octodog_tuning.gd` and `data/enemies/octodog.tres`, group "Jars": the tumble, `jar_settle_seconds`,
  `jar_pace_seconds` (how long a freed dog may pace before its first wind-up), `jar_intro_window_seconds`, and
  `release_distance()`, the soonest its first wind-up is planned.
- `scripts/world/level_layout.gd`: the three marks (below) and `holder_of`, `held_by`, `holds_enemy`, `held_type`,
  `is_held`, `is_decoy`.
- The look: `ZoneSkin.held_doodad_look` (the default dresses it as any doodad), overridden by `IceLabSkin` to the
  Octodog jar's look (`IceLabDoodads.OCTODOG_JAR`, task Q2's card); `TrackBuilder._build_doodad` asks it for every doodad
  holding an Octodog, decoys too.
- The hint `octodog_jar` (`data/hints/hints.json`; `HintDirector._first_at`: the first jar holding an Octodog, decoy or
  not), the sound `octodog_release` (`tools/asset_gen/sfx_bank_octodog_jar.gd`: the dog's own; the jar's break is the
  dash's `doodad_smash`).
- `tools/showcase/octodog_jar_review.tscn` (Review tools) and `tools/measure/octodog_jars.gd`.

**The data.** A jar is an ordinary zone doodad (`LevelLayout.doodads`) of the small class marked `holds: "octodog"`
(`LevelLayout.HOLDS`); the dog is an ordinary `octodog` entry of `LevelLayout.enemies` at the jar's front in its lane, its
params marked `held: true` (`LevelLayout.HELD`) with `doghouse: false` and its plan (`charges`, `charge_at`, `floor_span`).
A decoy is a zone doodad marked `holds: "octodog"` and `decoy: true` (`LevelLayout.DECOY`) with no enemy entry. A level
without jars is the same data as before. Everything that reads doodads treats a jar or a decoy as any doodad (its push,
the smash, the lane blocker, what other doodads and enemies keep from it); everything that reads enemies treats a held dog
as an Octodog (its keep-out, which every later pass keeps off), but for the level's standing Octodogs: a held dog is never
one (`LevelGenerator.feature_positions`, `OctodogRules.dogs_in`: no cyborg is planted in its first lunge's path, the
level's guaranteed dog doesn't count on it, and an Enforcer Truck never baits it, `EnforcerTruckRules.bait_points`), and
`LayoutChecks.check_doodads` leaves a jar's own dog and room out of what the jar keeps clear.

**Where it stands** (`OctodogJarRules`; its header has the whole list). The rules run after every other feature's
(`RUN_AFTER`, the gantryways and teleporters included), on the level's final rules track. For a jar front J:
- the jar fits as a zone doodad must (`LevelGenerator.doodad_fits`, the doodad pass's own rules lane by lane, over a
  `doodad_room()` worked out from the layout as it stands): an inner lane, or an outermost one by an open side wall,
  pushing inward;
- the dog's first wind-up is planned from J + `release_distance` (the tumble, the sprint to its stop distance, the
  settle, the dash's carry) to `jar_pace_seconds` later (it paces meanwhile), each later one a cycle on or up to
  `charge_slack` later where its stretch is clear (`Octodog.charge_clear`), no pad or landing near the first or between
  two (`Octodog.pad_or_landing_between`), 2 charges at least (`MIN_CHARGES`, as a standing dog): where two don't fit, the
  jar stands elsewhere, and a build with no spot for two has no jar that releases;
- the floor its charges use (`floor_span`, from `OctodogRules.run_start` before its first wind-up to past its last, as a
  standing dog's) keeps off every pad's zone and ceiling landing, every chase and kept extended wall run, everything the
  rules keep (a gantryway's calm stretch and lane, a teleporter's way around and landings, a wall-run gap's clear
  stretch, a treasure stash's floor), every wall-run gap's stretch, and every other Octodog's run with its stop distance
  and DOG_GAP between; between the jar and that floor the dog is harmless (it tumbles, runs ahead and paces) and nothing
  is kept for it;
- what the passes after the rules keep off: the floor its charges use (its keep-out, `OctodogRules.keep_out`) and the
  jar's own room (`jar_region`, in every lane: `doodad_keep_outs`, `fill_keep_outs`), which keeps off every wall-run
  gap's stretch and every chase too;
- in the level that introduces the jars (`_intro`: Frost Foundry gives the feature a start), the first stands within
  `jar_intro_window_seconds` of the start (test_campaign's introduction reach) where its dog's usual attack has room
  there, else the nearest past it.

A jar moves what later passes place around its dog's keep-out (a wider gap, say). One such move set a wider gap's landing
margin right against a teleporter's calm stretch, which `WideGapPlacement` kept off the zone but not off a doodad's push
lead past it, as `LayoutChecks.check_wide_gaps` asks; `WideGapPlacement.blocker` now keeps `LevelLayout.doodad_between`
off the zone and that lead (no build the suites checked before had one there).

A heli drone's pad schedule (a pad every 8 to 10 s from its first one) leaves no stretch long enough for two charges, so
in the Ice Lab a freed dog's attack fits before the drone's first pad, where the level is already full. So the rules
**make room**, only for what fairness needs (`_best`): with everything that may go taken out of the layout (`_removable`:
plain pattern cyborgs, window cyborgs, fence generators and screeches, pattern ceilings with their pads and ceiling
credits, plain holes and fences; never a rule's enemy, a drone's ceiling, a ceiling scenario's, a wall-run gap's hole, a
pulsing or powered fence), every front that fits is found, its dog's plan the one whose charges need the least taken out
(`_at`, `_run_cost`, `_charge_cost`); each is ranked by what of that stands in its way with the layout put back (`_in_way`:
on its charges' stretches the enemies near them, their fences and their holes in every lane but one, as a standing dog's
charge keeps them; around the jar, in its lane and the lanes beside it), the fewest ceilings first, then the fewest
pieces, then the nearest a seeded aim; the best `ROOM_TRIES` within the caps (`MAX_TAKEN_OUT` 3 pieces,
`INTRO_MAX_TAKEN_OUT` 4 for the introduction, `MAX_CEILINGS_TAKEN_OUT` 1) are tried for real, their pieces taken out
(never the last of a feature or the first of one the level introduces: `_features_kept`) and put back if the spot
doesn't fit after all. Credits stay but for those on a ceiling taken out. Measured over 63 builds of the Ice Lab's levels
(their own seeds and six others, 3, 5 and 6 lanes): a jar in 42 (every level at 5 lanes on its own seed), its dog making
2 charges in 38 of them, 2.2 pieces taken out a jar (1.5 a build), the star credit value within 3% in 51 of the 63 (the
rest from a ceiling taken out, or from the passes after the rules, whose random streams any change ahead of them
reshuffles); the rules take 0.14 s of a level's build on average (0.44 s at most), and it needs no more builds than
without the jars (`tools/measure/octodog_jars.gd`; the numbers base to branch in `docs/questions/q5.md` 6 and 7).

**The decoys** (`after_doodads`, called after the zone doodads, `LevelGenerator._after_doodad_rules`): from a random
stream of their own, `octodog_jar_decoys` of the level's small zone doodads standing alone are marked `holds` and
`decoy`, which changes nothing but their look; where the level has too few, new small doodads stand where a zone doodad
may (`doodad_fits` over the layout as it stands), each a seeded pick among every spot that fits (`_decoy_spots`).

**On the track.** `TrackBuilder` builds a jar or a decoy as any doodad (a `DashBreakable` over its entry), its look the
skin's `held_doodad_look`. The director spawns a held dog as any enemy; `Octodog._build` finds its jar
(`LevelLayout.holder_of`) and holds it (`HELD`: no look of its own, hitboxes off, immune to weapons, not targetable, no
turn held). When the jar's entry is marked `smashed` (`DashBreakable.smash`: the dash, or a wall runner by its side wall,
task L3) the jar breaks as every doodad (the run's pieces in its look's colours and the crunch, exactly as a decoy's) and
the dog comes out just past it (`_release`: its snarl and a green spray) and tumbles ahead (`TUMBLE`, harmless), then
runs on as after a lunge (`SPRINT`, its hitboxes on once it's ahead, `PACE` at its stop distance) and winds up at its
planned charges with the growl and the telegraph, as any dog. A runner who passes the jar unbroken never meets it: it
retires once they're past. Its first wind-up asks for its turn as any dog's, and waits while another Octodog's charges
are on (`_another_dog_charging`, every dog, whether or not big attacks take turns: GDD §9's turns are between types, the
generator plans dogs one at a time, and this keeps them so when a wait moved one dog's charges).

**Tests.** `test_octodog_jars` (below), `test_ice_lab_levels` (every build's count of jars and decoys,
`check_octodog_jars` through `LayoutChecks.check_layout`), `test_campaign` (the schedule: introduced in Frost Foundry from
a start of its own, left out of the Golden Zone; an occasional feature for its every-feature and introduction checks),
`test_hints` (Frost Foundry's hint), `test_audio` (the sound).
