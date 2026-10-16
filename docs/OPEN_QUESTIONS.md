# Open Questions

Questions that need the owner's answer. Sorted on October 14, 2026, when the list had grown to 794 items: the owner
is happy with the gameplay, so everything whose placeholder works moved out.

Item numbers are permanent: code comments, tests and the GDD cite them ("`docs/OPEN_QUESTIONS.md` item 628", "FB 73").
An item lives in exactly one of three files, under its original heading and number:

- `docs/OPEN_QUESTIONS.md`: the few questions that need the owner (work waits on them, or the placeholder gets
  costlier to change later).
- `docs/OPEN_QUESTIONS_DEFERRED.md`: still technically open, but the placeholder works and nothing waits on it
  (tuning, names, looks, feel). **The placeholder stands as built** until the owner reopens it while playtesting.
- `docs/OPEN_QUESTIONS_ANSWERED.md`: answered, approved, superseded, or notes that ask nothing.

To find a cited item, search the three files: `grep -n "^628\. " docs/OPEN_QUESTIONS*.md` (build phase 2 items have
no prefix; "GB n" and "FB n" are in their own sections). **Don't read these files whole.**

**New questions** from a task go in `docs/questions/<task-id>.md` (see `CLAUDE.md`). When the task merges, the
orchestrator gives each one the next free number (**878** after task E5e, I1–I9, F2e, J2 and J3 so far, not counting E5e-g's file, which is still to file; raise it here when you use one) and files it
here only if work waits on it or its placeholder will be costly to change later; otherwise in
`docs/OPEN_QUESTIONS_DEFERRED.md`. When the owner answers an item, record the answer in the GDD and move the item
to `docs/OPEN_QUESTIONS_ANSWERED.md` with the answer.

## Needs the owner (summary)

| Item | Question |
|---|---|
| 766 | Ceilings in the levels are too safe (owner, October 10, 2026): should a level keep at least one safe lane where a ceiling ends, and leave the rest free to hold gaps, hazards or enemies? A change to the generator's rules (GDD §3, Safe landing zone). |
| 828 | The web demo's music on phones: keep it as samples (about 52–60 MB a song in memory, a stop of 0.3–3 s when one starts), stream it (no memory cost, but it may crackle on a slow phone), or ship lighter songs for the web? Needs a try on a real iPhone. |
| 837 | No treasure stash on 3 or 4 lanes, so phone players never see one (the owner's shape would wall every floor lane on 3). Keep, or an outer-lane stash walled by the side wall, or a shorter one? |
| 838 | GDD §3 calls the return pad the only way into a stash, but the dash smashes in and a wall-jump can land on a stash wall and step down. Allow both as skill routes, or block them? |
| 848 | The economy's payouts: held at 100 + 25 a level and a flat 500 per boss (77% of a City 3 finish, 46% of a Dead Zone 1 finish) while I7 re-placed the prices. Change them, or keep them? |
| 864 | Wall-run-only gaps (J2): the Beach and Golden Zone get the fewest (about 1.3–2 a level against 2–2.5 mid-campaign), the opposite of the owner's "especially later zones", because those levels are crowded. Take a big encounter out per extra gap, let gaps win over wider gaps and dash walls late, or keep it? (Full text below.) |

## The items in full

**The Beach's boss: the design session** (the owner with Claude, October 10, 2026; GDD §10, Mecha Guppy and Captain Cogs; task E5e)
766. **Ceilings in the levels are too safe** (GDD §3, Safe landing zone; owner, October 10, 2026: "often the ceiling is
    way too safe", to be revisited for the game itself). In the Beach's boss fight one safe place to drop to is enough.
    Should the levels follow: at least one safe lane where a ceiling ends, and the rest free to hold gaps, hazards or
    enemies? It is a change to the level generator's rules (a core task), so it waits for the owner's word.

**I3, sound on an iPhone** (from `docs/questions/i3.md`; the batch of October 14, 2026)
828. **Should the web demo's music be played as a stream, or lighter, on phones?** (GDD §11; §2, the web demo.) On the
    web Godot plays every sound as a "sample" by default: a song is decoded whole when it first plays and kept raw
    (the Zone 1 song 52 MB, the Boss 1 song 60 MB, copied again each time it starts), and decoding stops the game's one
    thread (0.3 s on a desktop, likely 1–3 s on a phone). A phone short of memory could drop the music or reload the
    page, a second possible cause of the playtester's silent iPhone (item 827, the silent switch, is the likelier).
    "Stream" playback (music only) has none of that memory and makes the death dip's low-pass work on the web, but
    without threads it mixes on the page's thread, so a phone under about 20 fps could crackle. A third way: smaller
    songs for the web build (mono, or 22 kHz). It needs a try on a real iPhone. Placeholder: none; music stays as samples.

**I4, ceiling scenarios** (from `docs/questions/i4.md`; GDD §3, "Ceiling scenarios"; numbers in `data/tuning/ceiling_scenarios.tres`, F6 "Ceiling scenarios", or the level data)
837. **No treasure stash on 3 or 4 lanes.** The owner's shape (a doodad across the stash's lane, doodads in both
  neighbouring lanes alongside) would close every floor lane on 3 lanes, and on 4 it puts a wall in an outermost lane,
  where a wall runner's body reaches and where one dropping off the wall lands.
  **Placeholder:** a stash only in an inner lane with inner lanes either side (`treasure_stash_rules.gd`, `lanes_for`):
  lane 3 of 5, lane 3 or 4 of 6; none on mobile's 3 lanes. Alternatives: an outermost-lane stash walled on one side by
  doodads and on the other by the side wall (with a sign along it, so no wall run drops in), or a shorter stash.
838. **Other ways into a stash.** GDD §3 calls the return pad "the only way in".
  **Placeholder (nothing blocks these):** the dash (H5) smashes the doodad across the stash's lane and runs in
  (test_ceiling_scenarios checks it does); proposed: keep, as the dash's reward. A floor runner can't jump a doodad
  (2.6 m tall, a jump's feet reach 1.6 m) and is pushed out of the stash's lane at its front and out of its walls'
  lanes alongside, and no magnet reaches a stash's credits from the floor: they lie past the top tier's pull from
  wherever a runner is still close enough beside the stash to pull from (`treasure_stash_rules.gd`, `magnet_reach`;
  before the review they cleared it by luck, 0.10 m at the closest). But a doodad's top is a surface: a runner who jumps
  onto the side wall before a stash in lane 3 (5 lanes) and wall-jumps off it can land on the stash's wall in lane 2
  and step down into the stash (tried on real physics: it collects the credits). Proposed: allow it as a skill route;
  or stand a sign on the side wall before and alongside the stash.

**I7, the economy rebalanced for eight zones** (from `docs/questions/i7.md`; GDD §7–§8; measure with `tools/measure/economy.gd --lanes=5 --seeds=0`, pins `FIRST_FIT` and `IN_TIME` in `tests/suites/test_economy.gd`, prices in `data/shop/catalog.json`. "First fits at N": a typical player's wallet (70% of each level's credits, no deaths, nothing bought, no boss payouts, as the October 3 anchors were measured) covers the tier's line total after finishing level N in play order, so it is usable from N + 1; the "+boss" reading is up to three levels earlier for the capstones)
848. **The payouts.** (GDD §7.) The owner asked for the completion payouts to be rebalanced too. Measured, the
  completion bonus (100 + 25 a level, so 100 at City 1 and 500 at Golden 3; the Beach's levels share Corporate 2's
  place, item 572, so the plateau is 375 for three levels) and the boss payouts fit the placements above, and
  City 1-3 are the approved early revision, so they are unchanged. Raising the slope moves only the late tiers:
  at 35 a level a typical player's Heavy missile first fits at level 17 (Dead Zone 2) and Armor IV at 14; at 15
  a level, Heavy at 19 and Armor IV at 16 (`--bonus-per-level=35`). **The boss payout is flat:** every boss pays
  500 (1,000 for the last) whatever the zone, 77% of a City 3 finish but 46% of a Dead Zone 1 finish. Should the
  late levels, or the bosses, pay more?
  - **Placeholder:** unchanged (`data/tuning/game_rules.tres`, `data/bosses/*.tres`).

**Wall-run-only gaps** (the owner, October 15, 2026; GDD §3, §5, §9; task J2)
864. **How often.** How many a level, and how should that rise through the campaign? (GDD §5, Level schedule.)
   Placeholder: about one per 70 s of run at difficulty 0 to one per 40 s at difficulty 1 (`spacing_seconds_easy`,
   `spacing_seconds_hard`), each placed within 40 s of a seeded spot (`search_seconds`), at least 15 s between two
   (`min_spacing_seconds`), at least one in every level with the feature. Measured over the campaign's own seed and two
   more at 3, 5 and 6 lanes, a build has on average 1.9 in the Marketplace (one in Marketplace 1), 2.6 in the Casino,
   2.3 in Corporate, 2.1 on the Beach, 2.0 in the Dead Zone and 1.5 in the Golden Zone, where the levels are most
   crowded and fewer fit than the numbers ask for (3 to 4); 15 of those 117 builds had one give way to a wider gap or a
   dash wall (item 10). So the latest zone has the fewest, the opposite of "especially in later zones". Asking for more
   there doesn't help: the Golden Zone's and the Beach's builds already ask for 3 to 4 and fit fewer (the Beach's open
   walls leave few lit walls whole). Should more room be made for them there, and at what cost? Taking a big encounter
   out for every one, not only a level's only one (item 8), would take Resonators and Gilded Sentinels out of the
   Golden Zone (Golden 2 is "Sentinel Row"); letting them win over the wider gaps and the dash walls (item 10) would
   leave those levels short of their own counts (GDD §9.13, §9.14); and more of them takes more of the room the
   danger density pass fills at 3 lanes (item 12). None of that is done yet.
