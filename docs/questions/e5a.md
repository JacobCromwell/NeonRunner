# E5a: The House (step 2, E5a-b: phases 2 and 3, the defeat, par times, its campaign slot)

Numbers in `data/bosses/marketplace_boss_tuning.tres` (F6 in its fight, groups "Phases 2 and 3", "Wall
button", "Wall fences", "Ceiling button", "Defeat") and `data/bosses/marketplace_boss.tres`; play it with
`./play.sh --boss=marketplace_boss` (or `--level=marketplace/boss`, `--phase=2` or `3` to start there);
review with `tools/showcase/the_house_showcase.tscn -- --scenario=wall|ceiling|defeat`. Everything below
is `DESIGN-TBD`; step 1's questions are OPEN_QUESTIONS items 299-303.

1. **Phase 2's wall button** (GDD §10: "(2) one on a wall, with wall fences in play").
   **Placeholder:** the last button of the set (reel 3's, `special_reel`) stands upright on a side wall's
   facade at wall-run height, the same ivory disc and blue 7 as the floor's, reached by a wall run from
   the outer lane and passed at any height. Full-height wall fences pulse along both walls all phase (one
   every 2.2 s of run on alternating walls, on 1.0 s, off 1.4 s); a set is offered only where the wall run
   passes every fence while it's off, so the player wins it by timing. The machine's new attacks wait
   while the player goes for it. **Alternative:** partial-height fences, the button reached by entering
   high or low (B5's other way).
2. **Phase 3's ceiling button and its turrets** (GDD §10: "(3) one on a ceiling reached by an anti-grav
   pad, guarded by Barnacle Turrets").
   **Placeholder:** a floating billboard (GDD §5: the Marketplace's ceilings include "floating
   advertisements") comes down from the sky over every lane with a pad under it; the button is on its
   underside 1.1 s past the pad, in the pad's lane; one turret (3 lanes) or two (5-6 lanes) hang further
   along in a lane beside the pad's (C1's limits keep them at least 2.2 s past a pad, so they come after
   the button) and fire at the rider, who dodges a lane over. **Alternative:** a longer ceiling with the
   button past the turrets.
3. **The machine is taller than a ceiling** (GDD §10 gives it a building's height; a ceiling is 6 m up).
   **Placeholder:** at the lever's pull it squats on its treads to 4.9 m and stays down until it has rolled
   past the billboard's end, then rises. **Alternative:** it drops back further while a ceiling is over
   the street (smaller on screen for that stretch).
4. **The defeat** (GDD §10: "the reels spin wildly and jam, TILT flashes, and it collapses in an explosion
   of coins while the shops erupt in cheers").
   **Placeholder:** after the last stomp it lurches out and rises as after any stomp; its reels spin
   wildly for 1.0 s and jam between symbols, TILT flashes over them for 1.4 s (steady with Reduced
   flashing), and it tips over into the street ahead over 1.8 s while 90 coins burst out (for show: the
   fight's credits are the fountains') and the citizens cheer. **Alternative:** the coins land as real
   credits to collect.
5. **Par times** (GDD §10: "two and three stars for beating par times set per boss in data").
   **Placeholder:** a clean fight takes 66-68 s at 3, 5 and 6 lanes and both speeds; three stars at 72 s
   and two at 92 s (the Sleep Taker's margins over its clean run).
