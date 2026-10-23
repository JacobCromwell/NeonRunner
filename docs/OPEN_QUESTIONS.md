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
orchestrator gives each one the next free number (**1229** after task E5e, I1–I9, F2e, E5e-g, J2, J3, K1, K2, K3, F2g, F2h, L1, L4, L5, L2, L3, F2i, L9, L7 and L6, the weekly challenge's design session, M1, L10, M2, M3, N3, N2, N4, N1, N5 and O1, the Terminal's O1–O4 and F2k, and the Ice Lab's Q1–Q6, S1 and S2, so far; raise it here when you use one) and files it
here only if work waits on it or its placeholder will be costly to change later; otherwise in
`docs/OPEN_QUESTIONS_DEFERRED.md`. When the owner answers an item, record the answer in the GDD and move the item
to `docs/OPEN_QUESTIONS_ANSWERED.md` with the answer.

## Needs the owner (summary)

| Item | Question |
|---|---|
| 766 | Ceilings in the levels are too safe (owner, October 10, 2026): should a level keep at least one safe lane where a ceiling ends, and leave the rest free to hold gaps, hazards or enemies? A change to the generator's rules (GDD §3, Safe landing zone). |
| 837 | No treasure stash on 3 or 4 lanes (since October 18, 2026 no platform runs 3, so it matters only if one goes back), so phone players never see one (the owner's shape would wall every floor lane on 3). Keep, or an outer-lane stash walled by the side wall, or a shorter one? |
| 838 | GDD §3 calls the return pad the only way into a stash, but the dash smashes in and a wall-jump can land on a stash wall and step down. Allow both as skill routes, or block them? |
| 848 | The economy's payouts: held at 100 + 25 a level and a flat 500 per boss (77% of a City 3 finish, 46% of a Dead Zone 1 finish) while I7 re-placed the prices. Change them, or keep them? |
| 923 | The web demo on a phone in a fixed-size itch.io frame: send it to a full-screen tab of its own ("Play it full screen" card, with "Play here anyway"), though the tab exposes the game's file address and probably has its own save? Or rely on "Mobile friendly" and drop the card? |
| 932 | With the wall-run guide gone after the Marketplace (L5), nothing marks which wall is safe: in 18% of later gaps the other wall has a sign, window cyborg or live Sentinel along the crossing. Accept it ("use their brain"), keep the other wall clear too (generator), or a subtler cue? |
| 934 | The Buzz Overdrive's company (L2) skips every tank an Enforcer Truck chases for, which is nearly every tank from Corporate 2 on (131 of 143; all of the Golden Zone), so the change shows mostly in Corporate 1 and endless. Give those tanks company too (new truck rules), or keep them sparse? |
| 977 | The Leader of the Pack cosmetic (the weekly challenge's top-three reward): what it is and how it shows. The owner will design it in a later session. |
| 1061 | The Terminal pays about half of what its neighbours do, yet the Heavy missile (line 15,800) now first fits at Terminal 1, a level earlier than the Golden Zone it was placed for, so Golden 1 gets easier for buyers. Raise the missile's price (8,000 puts it back), or let the Terminal pay like its neighbours? |
| 1072 | A bot taking the quickest way through Rubble Line's maze finishes in 140 to 159 s (4 to 23 s of it waiting for the dash) on 138 s of track, so a run can outlast the level by up to 21 s. Are 1 or 2 breaks a block right, or should they scale with depth, difficulty or lane count? |
| 1207 | The Heavy Cyborg's placement leaves the Golden Zone's final stretch about x1.27 more dangerous at 5 lanes, below the approved 30-40%. Accept, raise the Golden levels' danger density, or rework the placement (a count rule, S1b, was started and stopped unmerged at the owner's word)? |
| 1208 | The Hunter's 25 laser hits: auto-fire never aims at it beside the runner, so only stray shots hurt it. Keep, give it low-priority targeting beside the runner, or a smaller `target_ahead`? |
| 1227 | The Hunter never slashes a runner in an edge lane (no lane to step away into), so the edges are a refuge for its whole chase. Keep, or obstacles in the edge lanes while it rides, or another rule? |
| 1228 | The Hunter's attack rate after the owner's "2× more often": 2.7× for a runner going for the bait, 1.4× for one who only dodges (held by the edge refuge, 1227). Enough? |

## The items in full

**The Beach's boss: the design session** (the owner with Claude, October 10, 2026; GDD §10, Mecha Guppy and Captain Cogs; task E5e)
766. **Ceilings in the levels are too safe** (GDD §3, Safe landing zone; owner, October 10, 2026: "often the ceiling is
    way too safe", to be revisited for the game itself). In the Beach's boss fight one safe place to drop to is enough.
    Should the levels follow: at least one safe lane where a ceiling ends, and the rest free to hold gaps, hazards or
    enemies? It is a change to the level generator's rules (a core task), so it waits for the owner's word.

**I4, ceiling scenarios** (from `docs/questions/i4.md`; GDD §3, "Ceiling scenarios"; numbers in `data/tuning/ceiling_scenarios.tres`, F6 "Ceiling scenarios", or the level data)
837. **No treasure stash on 3 or 4 lanes.** The owner's shape (a doodad across the stash's lane, doodads in both
  neighbouring lanes alongside) would close every floor lane on 3 lanes, and on 4 it puts a wall in an outermost lane,
  where a wall runner's body reaches and where one dropping off the wall lands.
  **Placeholder:** a stash only in an inner lane with inner lanes either side (`treasure_stash_rules.gd`, `lanes_for`):
  lane 3 of 5, lane 3 or 4 of 6; none on 3 lanes (mobile's count until October 18, 2026, when the owner set it to 5 like PC). Alternatives: an outermost-lane stash walled on one side by
  doodads and on the other by the side wall (with a sign along it, so no wall run drops in), or a shorter stash.
838. **Other ways into a stash.** GDD §3 calls the return pad "the only way in".
  **Placeholder (nothing blocks these):** the dash (H5) smashes the doodad across the stash's lane and runs in;
  **since October 18, 2026 (owner; task N1) the stash's lane has a second doodad in front, a dash's carry apart**, so one
  dash never smashes both (test_ceiling_scenarios checks it), and a floor runner gets in only the harder way, around the
  outer doodad and then a dash through the front one (item 1018). A floor runner can't jump a doodad
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

**L1, the demo's menus on an iPhone, from itch.io** (from `docs/questions/l1.md`; the batch of October 17, 2026)
923. **Should the web demo send a phone whose frame doesn't fit its screen to a full-screen tab of its own?**
   (GDD §2, platforms; item 233 is its sibling, the turn-your-phone cover.) An itch.io page that isn't set
   "Mobile friendly" shows the game in a fixed-size frame (960×540, say) that a phone's browser shrinks or crops,
   so however the menus are drawn, they are small or cut off. Placeholder (`DESIGN-TBD` in the preset's
   `html/head_include`, `export_presets.cfg`): a phone whose frame is not about the screen's size gets a cover,
   "Play it full screen" (a link that opens the game's own page in a tab of its own, where the page is the phone's;
   the Fullscreen API where the browser has it, which an iPhone doesn't), with "Play here anyway" under it, so the
   cover never locks anyone out. The cover also appears where the phone says it is held upright inside a landscape
   frame. The link carries the game's own address on itch.io's file host, which is not the project page's secret
   URL: whoever has it can open the game without the page. The tab's save is probably separate from the frame's
   (browsers partition a frame's storage by the page around it), so a player who opens it starts the demo's
   progress afresh there. If that matters, the owner sets "Mobile friendly" and the
   cover is only a net; or removes the cover and keeps the safe-area and scale fixes (both are independent of it).
   A running level pauses behind either cover, as for a phone call (`App._on_page_cover`, marked DESIGN-TBD): a
   placeholder too, since it is the cover's reason to exist that the game can't be played behind it.

**L5, the wall-run guide only where it's introduced** (from `docs/questions/l5.md`; the batch of October 17, 2026)
932. **Without the lit wall, nothing marks which wall is safe.** (Found in L5's review.) The gap's own wall is kept clear
   of signs, wall enemies, wall fences and side wall gaps; the other wall is kept clear only of wall fences and side wall
   gaps (`WallRunGapPlacement.wall_keep_outs_for`), because J2 took the lit wall to show the way
   (`wall_run_gap_tuning.gd`). Measured over the later zones' levels (own seeds plus two, 3/5/6 lanes), in 37 of 201
   gaps (18%) the unlit wall carries a hazard along a crossing's stretch: Casino 10/46, Corporate 5/41, Beach 9/37,
   Dead Zone 4/36, Golden 9/41; window cyborgs 30, signs 14, live Gilded Sentinels 3. Over the hole the runner can't
   leave the wall, and a sign kills without armor, a window cyborg's body hurts through armor, and a live Sentinel is
   told from the statues only by its red eyes; on 6 lanes the clear wall may be five lane changes (0.7 s) away.
   (a) Accept it as part of "use their brain" (the hint says "a clear wall"); (b) keep signs and wall enemies off the
   other wall too where there's no guide (a core generator task, costing room where gaps already fit fewer than asked,
   `docs/questions/j2.md` item 2; the generator would need to know where the guide shows); or (c) a subtler cue on the
   clear wall than the arrows. Placeholder: (a).

**L2, the Buzz Overdrive's company** (from `docs/questions/l2.md`; the batch of October 17, 2026)
934. **Where an Enforcer Truck is about.** The owner: sparse is fine where an Enforcer Truck is likely on the map with it.
   Placeholder: a tank whose visit (from where it comes into view to where it's gone) comes within 2 s of a truck's chase
   (its arrival until it has dropped back) gets none (`truck_margin_seconds`). From Corporate 2 on that is nearly every
   tank: over each level's own seed and four others at 3, 5 and 6 lanes, 131 of the 143 tanks from Corporate 2 to the
   Golden Palace, and every one in the Golden Zone (whose only baits are Buzz Overdrives). So the request mostly
   changes Corporate 1 (21 of its 36 tanks) and, elsewhere, about one tank in every six builds of a level (12 of the
   143). Should the later zones' tanks get company too where the truck is about but not yet attacking?

**The weekly challenge** (the owner's design session, October 18, 2026; GDD §6, Replay features, "Weekly challenge")
977. **The Leader of the Pack cosmetic.** A player who finishes in the **top three** of a week's board (the cut-off is the
   owner's for now and will be adjusted) earns the Leader of the Pack cosmetic. What it is (a runner skin, a trail, a
   badge...), how it shows, and whether it can be lost again are to be designed: the owner will come back to it in a
   later session. Outfits are the game's cosmetics (GDD §8, Cosmetics, the owner's session of the same day, task M1).
   **Overlap to settle:** that session made the **Centurion** outfit "the prize for winning the weekly seed"; this one
   gives the top three Leader of the Pack. Are they one reward (Centurion is Leader of the Pack), or two (Centurion for
   first place, Leader of the Pack for the top three)?
   It also needs a rule for when the reward is granted: a week's rank is only final once the week is over, so the game
   would check it the next time it is online. Placeholder: none yet; work on the reward waits on this item.

**The Terminal in the campaign** (task O1 of the Terminal workstream, October 20, 2026; from `docs/questions/o1.md`; GDD §5, Zone 8)
1061. **The Terminal's payouts, and the Heavy missile.** Placeholder: each Terminal level's completion bonus is Dead
   Zone 2's (425; an off-curve level pays the last on-curve level's, as the Beach's do), and its credits are a trail
   of six along one lane in each open stretch (`terminal_patterns.json`, the open track's credits) plus the usual
   trails: 329 and 343 credits on the levels' own seeds at five lanes, so a typical finish pays 655 and 665, about
   half of what its neighbours pay (960-1,332), until O2's maze changes where they lie. Even so the two levels add
   1,320 to a typical playthrough, and the Heavy missile (line 15,800, placed to first fit at Golden 1) now first
   fits at Terminal 1, by 90 credits (`tests/suites/test_economy.gd`, `FIRST_FIT`, moved there; still affordable
   before Golden 2's Sentinels, as placed). Should the Terminal pay like its neighbours, and should the Heavy
   missile cost more (8,000, a line of 16,800, would put it back at Golden 1)?

**The Terminal's debris maze** (task O2 of the Terminal workstream, October 20, 2026; from `docs/questions/o2.md`; GDD §5, "The debris maze")
1072. **How many breaks a block needs.** ("Can't get through without dashing ... choose where to break through.")
   Placeholder: the least dashes a block takes is drawn per block in `breaks_min`..`breaks_max`: 1 or 2 in Rubble
   Line, 1 in Last Stop; with the dash at its slowest recharge (8 s) a runner may wait for it. A bot taking the
   quickest way with that dash (test_debris_maze) runs Rubble Line's 138 s of track in 140, 151 and 159 s at 3, 5 and 6
   lanes (4, 15 and 23 s of it waiting for the dash), and Last Stop's 143 s in about 141 s (its dashes make up for its
   stops). Should blocks need more breaks further into a level, or with the difficulty, or fewer at 6 lanes?

**S1, the Heavy Cyborg** (task S1, October 23, 2026; from `docs/questions/s1.md`, whose item n is 1194 + n here; GDD §9.16; numbers in `data/enemies/heavy_cyborg.tres`, F6)
1207. **The danger density pass in the Golden Zone** (the owner's danger density request against the Heavy Cyborg). Each
    Heavy Cyborg keeps two seconds of clear floor before it, which the pass's rows keep off as off any big attack's
    window, and the pass adds no cyborg or window cyborg within a second of run of one (other enemies, and those further
    off, it may add near one), so in the Golden Zone it adds a little less: over test_danger_density's sample the final
    band lands at about x1.27 for enemies at 5 lanes (x1.30 at the least before; x1.26 at 3 lanes, x1.27 built without
    its teleporters, and x1.32 at 6, which keep their floors). Placeholder: the suite's floor is 0.04 lower there at 5
    lanes (HEAVY_CYBORG_ROOM), as for the wall-run gaps and the teleporters at 3. The band moves a few hundredths with
    each level's weight for the pattern (Golden 2's was chosen where it holds at 3 and 6 lanes). Which request gives
    way?

**S2, the Hunter** (task S2 with its review rounds and S2c, October 23, 2026; from `docs/questions/s2.md`, whose item n is 1207 + n here; GDD §9.17; numbers in `data/enemies/hunter.tres`, F6 "Enemy: hunter"; notes in `docs/architecture/enemy-hunter.md`)
1208. **The laser beside the runner: can its 25 laser hits ever be dealt?** The owner: it "stays on the player's side when
   it does its slashing attacks, making it difficult for the player to damage it with dashes or with laser attacks", and
   its health is 25 laser hits. Built so (the placeholder, "not while alongside"): auto-fire, the laser and the missiles
   alike, never picks it while it rides alongside (`Hunter.targetable`), only while it's seen and its middle
   `target_ahead` (3 m) or more in front of the runner's. It never rides that far ahead in this build (it comes from
   behind and rides with its middle 0.6 m ahead), so in play weapons never aim at it, and its 25 laser hits can only
   come from shots meant for something else that pass through it. Measured (test_hunter): over a whole 25 s chase beside
   a runner auto-firing laser tier 1 at cyborgs ahead in the other lanes, 40 shots, none at the Hunter, none reaching
   it; it gave up whole. Before this, auto-fire picked it beside the runner and laser tier 1 destroyed it in about 8 s
   of its chase. Which does the owner want: (a) as built, weapons in effect never hurt it (the gantryway is the only
   way); (b) auto-fire picks it beside the runner only when nothing else is ahead (a lower priority), so the laser wears
   it down slowly; (c) a smaller `target_ahead` (it's picked while it rides a little ahead, as it does while it warns
   and cuts)?

1227. **The edge refuge.** A runner in an edge lane with the Hunter beside them has no lane away from it to step into, so
    it never slashes them there (no flurry without a way out, item 7); a runner can ride out its chase by the edge, only
    the level and other enemies moving them. Kept as built (task S2's review, and task S2c: item 21 has what changing it
    would take). Is the edge meant to be a way to escape
    it, like teleporters and ceilings, or should something move the runner off it (the level's obstacles in the edge
    lanes while a Hunter rides, say)?

1228. **How often it attacks** (task S2's second review: "aim for something like 3+ warned flurries per chase where the
    runner isn't in an edge lane"). Placeholder: the shorter rest and quicker approach (items 3 and 6), its rising over
    full fences and crossing behind the runner rather than dropping out of view, and its short make-room (item 8).
    Measured (`tools/measure/hunter_chases.gd --seeds=2`: Specimen Vault's builds at 3, 5 and 6 lanes, its own seed,
    9001 and 9002, 12 chases; a god-mode runner who dodges each flurry, or who also goes for the bait), flurries warned
    for each 25 s of chase the runner spends off the edge lanes, then a chase, beside the runner, unseen:

    | Runner | Lanes | Before (abd091b) | After |
    |---|---|---|---|
    | Dodges | 3 | 1.0 (0.2 a chase) | 2.4 (0.5 a chase) |
    | Dodges | 5 | 0.7 (0.4) | 1.9 (1.4) |
    | Dodges | 6 | 1.8 (1.3) | 5.2 (2.3) |
    | Dodges | all | 1.1 (0.6), beside 38%, unseen 39% | 2.7 (1.3), beside 53%, unseen 20% |
    | Goes for the bait | all | 0.8 (0.3), beside 41%, unseen 42% | 1.4 (0.6), beside 57%, unseen 24%; 12 of 12 baits |

    What holds back the flurries that are due is the level and the fairness rules (seconds over the dodger's 12 chases):
    the edge refuge 25.7 (item 20), a gantryway's run-up and calm stretch 20.1 (the level's own every-lane calm), not
    yet settled beside them 17.8 (following a moment late, steering round, over a run-up), the runner off the floor 8.6,
    no way out 8.4, a fence it would be risen over 3.2, a teleporter's calm 2.8, a small attack 2.3, a fenced pick 2.2.
    At 3 lanes a runner who dodges ends up by the edge most of the time (53 to 100% of a chase). Is this rate what the
    owner wants, and if more: should the edge refuge go (item 20), or flurries come during a gantryway's calm stretch
    (the level keeps every lane quiet there)? Task S2's third review: a few warnings end without cuts, called off as its
    lane shuts ahead (it steers, crosses or drops back) or as it makes room. Holding a warning back whenever its own lane
    would shut before its last cut (its lane clear through the whole attack and its steering's look ahead past it) cost
    a fifth of the flurries: over 31 chases (its own seed and 9001 to 9006), 25 warned and 22 cut without it, 18 and 18
    with it (0.8 and 0.6 warned a chase, 1.8 and 1.3 for each 25 s off the edge lanes), so it isn't built. Are a few
    warnings with no cuts acceptable (they stop their scrape), or worth that rate?

    Task S2c (the owner, playtesting the session branch: "it doesn't attack often enough, it should attack 2 times more
    often than it does currently"). Built: its first flurry 0.4 s after it settles beside the runner (1.0 s) and each
    next 1.8 to 2.0 s after the last one's warning (2.3 s at most; a flurry's warning, cuts and recovery take 1.75 s);
    back beside them sooner: `approach_speed` 16 m/s (14), `follow_delay_seconds` 0.15 s (0.25), `switch_seconds` 0.2 s
    (0.25), `regain_seconds` 0.5 s (1.2), `yield_gap` 8 m (9); fewer warnings called off: through a warning and its cuts
    it looks ahead in its lane only as far as they last and 0.3 s more, steering round what lies past them afterwards
    (item 6); and its own holds shorter: no flurry from `bait_hold_seconds` 2 s before a gantryway's pillar (2.5 s), and
    the bait-lane hold (item 7) only once the pillar is within `bait_cross_seconds` and a flurry's length of run (before,
    whenever a bait was planned in its chase). The fairness rules stand (the 0.85 s warning seen and heard, a lane to
    step into, one flurry one hit, no flurry risen over a fence or in a fenced pick, test_hunter's view checks), and so
    do the edge refuge (item 20) and a gantryway's calm stretch. Measured (`tools/measure/hunter_chases.gd --seeds=6`:
    Specimen Vault at 3, 5 and 6 lanes, its own seed and 9001 to 9006; before, the session branch with S1's Heavy
    Cyborg, 30 chases; after, 31: the 6-lane introduction now lands, item 13):

    | Runner | | Before (9b40d3f) | After |
    |---|---|---|---|
    | Dodges | flurries warned a chase (cut) | 0.67 (0.43) | 0.94 (0.77) |
    | Dodges | warned a chase at 3 / 5 / 6 lanes | 0.11 / 0.82 / 1.00 | 0.22 / 1.27 / 1.18 |
    | Dodges | warned a 25 s off the edge lanes | 1.7 | 2.7 |
    | Dodges | beside, unseen | 49%, 22% | 51%, 20% |
    | Goes for the bait | flurries warned a chase (cut) | 0.30 (0.20) | 0.81 (0.65) |
    | Goes for the bait | warned a chase at 3 / 5 / 6 lanes | 0.22 / 0.18 / 0.50 | 0.44 / 0.82 / 1.09 |
    | Goes for the bait | warned a 25 s off the edge lanes | 0.8 | 2.3 |
    | Goes for the bait | beside, unseen | 51%, 23% | 54%, 19% |
    | Goes for the bait | baits landed | 28 of 30 | 29 of 31 |

    test_hunter_baits: 200 of 200 takes, with 253 flurries dodged on the way (166 before), and the step-out window as
    before (0.00 to 0.90 s). The runner who goes for the bait (back toward the middle for the walkway's lane, as a player
    playing the level does) gets 2.7 times the warned flurries a chase. The runner who dodges each flurry gets 1.4 times
    (1.6 for each 25 s off the edge lanes): it never steps back toward the middle, so its dodges take it to the edge (one
    from the middle at 3 lanes, two or three at 5 and 6), and it is in an edge lane 65% of its chase time, where the edge
    refuge holds 154 s of its flurries over the 31 chases (72% of the time at 3 lanes). Its flurries a chase can't double
    unless the edge refuge goes. What could change there, and why none is built:
    (a) Reaching across: by a runner in an edge lane it rides two lanes in and cuts their lane over the empty lane
        between, dodged into that lane, toward it. Not fair as it stands: the dodge is toward it, against GDD §9.17's
        proposal ("it slashes into the runner's lane from the lane beside it ... dodged by stepping one lane away from
        it"), and its blades would sweep over the lane the runner must step into (safe things must look safe).
    (b) Crossing to the runner's other side before a dodge takes them into an edge lane, so the next flurry carries them
        back toward the middle: built and measured in this task, then taken out. It goes against "keeps to the side it
        came up on" (GDD §9.17, proposed; 26 of test_hunter's checks), it cost baits (22 of 31 landed), and the dodging
        runner got no more flurries (24 warned against 26).
    (c) The level moving the runner off the edge (obstacles in the edge lanes while a Hunter rides: item 20's question):
        fair (the usual obstacles and their warnings) but level design for the owner, and the measure's god-mode runner
        doesn't move for obstacles.
    Is this rate what the owner wants, and should the edge stay a refuge?
