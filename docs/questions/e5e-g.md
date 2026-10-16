# Questions from task E5e-g (Mecha Guppy's phase 3 reworked; the owner, October 15, 2026)

The owner's design (GDD §10, "Phase 3, level with Captain Cogs") left these details open. Each has a placeholder,
marked DESIGN-TBD in `scripts/bosses/mecha_guppy/mecha_guppy_tuning.gd` ("Phase 3") and built so it's cheap to change.

**All nine answered by the owner on October 16, 2026; filed as items 888-896 in `docs/OPEN_QUESTIONS_ANSWERED.md`. Every placeholder stands as built.**

1. **How many hits empty Mecha Guppy's bar in phase 3?** (GDD §10: "the health bar corresponds to the Mecha Guppy's
   health".) Placeholder: 16 (`data/bosses/beach_boss.tres`, phase 3's `hits`), which with the dives keeps phase 3 at
   about the old minute (55.8-61.1 s on the top, measured) and the par times where they were (three stars moved from
   177 s to 179 s).
   **Answered (owner, October 16, 2026), filed as item 888:** Placeholder of 16 hits stays.

2. **How many hits before each dive?** ("the Mecha Guppy can take some damage from the bombs ... and it will go
   underneath the water.") Placeholder: every 4 (`dive_every`), so three dives (and three waves and floor bites) in the
   phase; none after the last hit.
   **Answered (owner, October 16, 2026), filed as item 889:** Placeholder of every 4 stays.

3. **The barrages' size and order of high and low bombs.** Placeholder: four bombs a barrage, a fixed looped script
   `"LHLH HLLH LLHL HHLH"` (`barrage_script`), one bomb at a time: the next one's warning no sooner than `bomb_gap`
   (1.5 s) after the last's and never before the last has passed the runner, `barrage_rest` (1.2 s) between barrages.
   A faster barrage (two bombs warned at once) would need a way to show which comes first.
   **Answered (owner, October 16, 2026), filed as item 890:** The barrages' size and order stay as built.

4. **The bombs' warning and where they come from.** Every attack needs a visual and an audio warning. Placeholder: a
   red line across the lanes at the runner's distance, at the height the bomb will fly, and the gun's charge
   (cogs_charge, `bomb_warning` 0.8 s); the bombs fire from a new swivel gun on the captain's stern castle rail, just
   ahead of where he stands. The camera can't see beside the runner, so the ship keeps ahead of them (`level_ahead`
   11 m, a little more on a wider top: `CaptainCogsShip.level_lead`) and each bomb curves down and in over the eaves
   onto the line, then flies straight across every lane; on 5 and 6 lanes that curve comes from further ahead.
   **Answered (owner, October 16, 2026), filed as item 891:** Good as built.

5. **The bombs' size and heights.** ("a little bit smaller".) Placeholder: radius 0.45 m (the phase 1 and 2 bombs'
   size; the old cannonball was 1.15 m); a low one 0.5 m over the deck (a jump clears it), a high one 1.28 m (a slide
   passes under it, standing or jumping doesn't).
   **Answered (owner, October 16, 2026), filed as item 892:** Good as built.

6. **A bomb blocked by armor or a shield.** Placeholder: it bursts on the runner and doesn't hit Mecha Guppy (only
   dodged bombs do); the dash passes through one, which flies on and hits.
   **Answered (owner, October 16, 2026), filed as item 893:** Good as built.

7. **The floor bite's size after each wave.** ("depending on how big the bite is".) Placeholder: from the right (Mecha
   Guppy's side), the first leaving one lane (lane 0), the next across every lane to jump, alternating; the climb's
   sizes and warning rules.
   **Answered (owner, October 16, 2026), filed as item 894:** Good as built.

8. **Mecha Guppy's swim on the right.** (The owner chose it swimming level, the upper half of its face showing, bobbing
   and surging, with water on both sides, on October 15, 2026.) Placeholder numbers: its hinge 10 m ahead
   (`guppy_ahead`), 1.2 m under the deck (`MechaGuppyShark.SWIM_SINK`), bobbing 0.35 m every 2.6 s and surging 1.6 m
   every 5.5 s (`SWIM_*`); the water a plane at its waterline on each side, the backdrop's sea colour. Its splash
   (upright, facing the runner with its jaws wide, ahead where the wave's swell rises) and its roar (`guppy_roar`, a
   short mechanical growl under the clang) are placeholders too.
   **Answered (owner, October 16, 2026), filed as item 895:** Good as built.

9. **The defeat's start.** Placeholder: on the last hit Mecha Guppy dives out of sight from its watch (0.45 s), then
   the defeat plays as before (it bursts up under the ship and eats the captain); the results wait 0.45 s longer.
   **Answered (owner, October 16, 2026), filed as item 896:** Good as built.
