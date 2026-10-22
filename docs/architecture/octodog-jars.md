# Architecture: Octodog jars

Part of the architecture notes; the index is [`docs/ARCHITECTURE.md`](../ARCHITECTURE.md).

## Octodog jars that break open (the Ice Lab)

Task Q5; GDD §5, Zone 9 (the owner, October 21, 2026): "to get extra value from the Octodog (§9.4), some jars hold a
curled-up Octodog instead of a brain. Sometimes smashing an Octodog jar doodad releases its Octodog into the world, and the
runner has to fight it." GDD §5's proposals are built as written: a jar is smashed the way every doodad is (the dash), a jar
that will release its Octodog looks the same as one that won't, the freed Octodog tumbles out, runs ahead to its usual
distance and starts its usual attack (§9.4) from the first wind-up, with its cue, never a lunge without warning, and it is
fought and killed like any Octodog. The level feature is `octodog_jar` (all three Ice Lab levels, from Frost Foundry, no
start of its own); a level's count is `LevelConfig.octodog_jars` (1 each), DESIGN-TBD (`docs/questions/q5.md`).

**The files.**
- `scripts/enemies/octodog_jar_rules.gd`: the generator's rules (no patterns): where each jar stands, the plan of the dog it
  holds, the room it makes, and `problems()`, the re-check of a finished layout (`LayoutChecks.check_octodog_jars`).
- `scripts/enemies/octodog.gd`: the held dog (phase `HELD`), its release (`TUMBLE`, then as after a lunge), the runtime
  "one dog at a time" (`_another_dog_charging`), `sounds_played` for the tests.
- `scripts/enemies/octodog_tuning.gd` and `data/enemies/octodog.tres`, group "Jars": the tumble and `jar_settle_seconds`,
  and `release_distance()`, where the dog's first wind-up is planned.
- `scripts/world/level_layout.gd`: the two marks (below) and `holder_of`, `held_by`, `holds_enemy`, `held_type`,
  `is_held`.
- The look: `ZoneSkin.held_doodad_look` (the default dresses it as any doodad), overridden by `IceLabSkin` to the
  Octodog jar's look (`IceLabDoodads.OCTODOG_JAR`, task Q2's card); `TrackBuilder._build_doodad` asks it for a jar.
- The hint `octodog_jar` (`data/hints/hints.json`; `HintDirector._first_at`: the first jar holding an Octodog), the sound
  `octodog_release` (`tools/asset_gen/sfx_bank_octodog_jar.gd`).
- `tools/showcase/octodog_jar_review.tscn` (Review tools) and `tools/measure/octodog_jars.gd`.

**The data.** A jar is an ordinary zone doodad (`LevelLayout.doodads`) of the small class marked `holds: "octodog"`
(`LevelLayout.HOLDS`); the dog is an ordinary `octodog` entry of `LevelLayout.enemies` at the jar's front in its lane, its
params marked `held: true` (`LevelLayout.HELD`) with `doghouse: false` and its plan (`charges`, `charge_at`, `floor_span`).
A level without jars is the same data as before. Everything that reads doodads treats a jar as any doodad (its push, the
smash, the lane blocker, what other doodads and enemies keep from it); everything that reads enemies treats its dog as an
Octodog (its keep-out and floor, which every later pass keeps off), but for the level's standing Octodogs: a held dog is
never one (`LevelGenerator.feature_positions`, `OctodogRules.dogs_in`: no cyborg is planted in its first lunge's path, and
the level's guaranteed dog doesn't count on it), and `LayoutChecks.check_doodads` leaves a jar's own dog out of what the
jar keeps clear.

**Where it stands** (`OctodogJarRules`; its header has the whole list). The rules run after every other feature's
(`RUN_AFTER`, the gantryways and teleporters included), on the level's final rules track. For a jar front J:
- the jar fits as a zone doodad must (`LevelGenerator.doodad_fits`, the doodad pass's own rules lane by lane, over a
  `doodad_room()` worked out from the layout as it stands): an inner lane, or an outermost one by an open side wall,
  pushing inward;
- the dog's first wind-up is planned at J + `release_distance` (the tumble, the sprint to its stop distance, the settle,
  the dash's carry), each later one a cycle on or up to `charge_slack` later where its stretch is clear
  (`Octodog.charge_clear`), no pad or landing near the first or between two (`Octodog.pad_or_landing_between`), 2
  charges at least (one where no spot in the level has room for two, even with room made);
- its whole run, from the jar's push lead to past its last charge, keeps off every pad's zone and ceiling landing, every
  chase and kept extended wall run, everything the rules keep (a gantryway's calm stretch and lane, a teleporter's way
  around and landings, a wall-run gap's clear stretch, a treasure stash's floor), and every other Octodog's run with its
  stop distance and DOG_GAP between.

A heli drone's pad schedule (a pad every 8 to 10 s from its first one) leaves no stretch long enough for two charges, so
in the Ice Lab a freed dog's attack fits before the drone's first pad only, where the level is already full. So the rules
**make room** as a gantryway's introduction does (`_best`): with everything that may go taken out of the layout
(`_removable`: plain pattern cyborgs, window cyborgs and fence generators, pattern ceilings with their pads and ceiling
credits, plain holes and fences; never a rule's enemy, a drone's ceiling, a ceiling scenario's, a wall-run gap's hole, a
pulsing or powered fence), every front that fits is found; each is ranked by what of that stands in its way with the layout
put back (`_in_way`, from the lane that takes the fewest out), the fewest first, then the nearest a seeded aim; the best
`ROOM_TRIES` are tried for real, their pieces taken out (never the last of a feature or the first of one the level
introduces: `_features_kept`) and put back if the spot doesn't fit after all. Measured over 63 builds of the Ice Lab's
levels (their own seeds and six others, 3, 5 and 6 lanes): a jar in every one, its dog making 2 or 3 charges in three
builds of four, 4 to 6 pieces taken out on average; about 0.1 s of a level's build (`tools/measure/octodog_jars.gd`).

**On the track.** `TrackBuilder` builds a jar as any doodad (a `DashBreakable` over its entry), its look the skin's
`held_doodad_look`. The director spawns the dog as any enemy; `Octodog._build` finds its jar (`LevelLayout.holder_of`) and
holds it (`HELD`: no look of its own, hitboxes off, immune to weapons, not targetable, no turn held). When the jar's entry
is marked `smashed` (`DashBreakable.smash`: the dash, or a wall runner by its side wall, task L3) the dog comes out just
past it (`_release`: the sound, pale glass and a green spray) and tumbles ahead (`TUMBLE`, harmless), then runs on as after
a lunge (`SPRINT`, its hitboxes on once it's ahead, `PACE` at its stop distance) and winds up at its planned charges with
the growl and the telegraph, as any dog. A runner who passes the jar unbroken never meets it: it retires once they're
past. Its first wind-up asks for its turn as any dog's, and waits while another Octodog's charges are on
(`_another_dog_charging`, every dog: GDD §9's turns are between types, the generator plans dogs one at a time, and this
keeps them so when a wait moved one dog's charges).

**Tests.** `test_octodog_jars` (below), `test_ice_lab_levels` (every build's count, `check_octodog_jars` through
`LayoutChecks.check_layout`), `test_campaign` (the schedule: from Frost Foundry, left out of the Golden Zone), `test_hints`
(Frost Foundry's hint), `test_audio` (the sound).
