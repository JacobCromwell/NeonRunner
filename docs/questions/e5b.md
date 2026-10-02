# E5b: Hostile Takeover (step 1, E5b-a: the train arena, the gunship and the locomotive, phase 1)

Numbers in `data/bosses/corporate_boss_tuning.tres` (F6 in its fight, groups "Train", "Couplings", "The
Board", "Gunship", "Locomotive", "Breakaway") and `data/bosses/corporate_boss_skin.tres`; play the preview
with `./play.sh --boss=corporate_boss` (debug builds: every phase plays The Board until steps E5b-b and
E5b-c); review with `tools/showcase/hostile_takeover_showcase.tscn -- --scenario=run|train|gunship|locomotive|coupling`.
Distances that stand for a time are metres at 18 m/s, stretched at the Corporate zone's 23.4 m/s, so the
seconds below hold at both. Everything below is `DESIGN-TBD`.

1. **The train's rhythm and The Board's density** (GDD §10, phase 1: "security cyborgs guard the roofs, a
   Tithe Collector skims credits, and partial wall fences run along the track's sound barriers. Each
   carriage coupling glows red and sits in one lane above the gap"; no numbers).
   **Placeholder:** a gap across every lane every 3.2 s (carriages 50 m at 18 m/s, gaps half a jump); the
   fight opens with its 3 s entrance and then 4 more dark gaps past the one in sight, so the first
   coupling glows over the sixth gap (a later phase keeps 1 dark), then every gap's coupling glows, in a
   lane of its own (never the last one's, at most 2 lanes from it); 1 or 2 guards a carriage from the
   third on (never more than the lanes less one, never near a coupling's run-up or landing), a partial
   wall fence on 70% of the carriages, a Tithe Collector every fifth carriage. A runner who never misses
   stomps the first coupling 18.5 s in. **Alternative:** fewer dark gaps, or a coupling lit only on some
   gaps (one at a time, as The House's buttons).
2. **What counts as landing on a coupling** (GDD §10: "the player stomps it by landing on it while jumping
   the gap").
   **Placeholder:** its stomp box covers its lane over the whole gap and 1 m (at 18 m/s) past either edge,
   up to 0.55 m above the roofs: any jump that comes down over the gap in that lane stomps it, also from the
   lane beside it with a move in mid-air. That takes an early jump, from 4 to 12 m before the gap (a 0.45 s
   window); green chevrons (the Floating Head's way-up language) mark it on the roof in the coupling's lane
   while it glows. A jump from the edge sails over it (a harmless miss), and running off the edge isn't a
   stomp: the runner falls as in any gap. **Alternative:** only the coupling's dome counts (a smaller
   target), or no chevrons (the red coupling as the only cue).
3. **Credits for the Tithe Collector in a boss fight** (GDD §10: "a Tithe Collector skims credits"; a
   boss's track carries no credits of its own).
   **Placeholder:** each Collector comes in the runner's lane on a carriage with no guards (it weaves toward
   the lanes with the most hazards, so guards would draw it off), and a trail of 6 credits worth 5 is laid
   on the roof ahead of it to skim. Catching it pays what it holds plus its 120-credit jackpot, and phase 1
   has no time limit, so a player who lets couplings go by can catch one every 16 s or so. **Alternative:**
   no trail (it only robs on a touch), one Collector a phase, or a smaller jackpot in a boss fight.
4. **The sound barriers and the sense of speed** (GDD §10: "the track's sound barriers act as walls"; "the
   sense of speed comes from the scenery streaming past").
   **Placeholder:** the barriers are the run's walls, so they stay put beside the runner as in any level
   (plain gunmetal panels with nothing to show they should be rushing past); beyond them the city's towers,
   and far below the gaps the street, stream back at the train's 45 m/s on top of the runner's pace.
   **Alternative:** the barriers' panels stream past too (a wall run along a moving wall).
5. **Where the gunship and the locomotive are, and the Chairman's glimpse** (GDD §10: "a military gunship
   paces the train overhead"; "the player gets a glimpse of him: in the locomotive's window during the
   fight").
   **Placeholder:** the gunship flies 22 m ahead of the runner and 13.5 m over the roofs, swaying 2.4 m
   over 9 s (it sweeps in from behind and above as the entrance); the locomotive leads the train 125 m
   ahead at the end of the view, and the Chairman stands at its lit rear window the whole fight, small
   but clear (2.4 m tall, the window 4.6 m wide). **Alternative:** the Chairman shows only at moments (a
   stomp, a phase change), with the locomotive nearer then.
