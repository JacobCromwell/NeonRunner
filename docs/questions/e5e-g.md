# Questions from task E5e-g (Mecha Guppy's phase 3 reworked; the owner, October 15, 2026)

The owner's design (GDD §10, "Phase 3, level with Captain Cogs") left these details open. Each has a placeholder,
marked DESIGN-TBD in `scripts/bosses/mecha_guppy/mecha_guppy_tuning.gd` ("Phase 3") and built so it's cheap to change.

1. **How many hits empty Mecha Guppy's bar in phase 3?** (GDD §10: "the health bar corresponds to the Mecha Guppy's
   health".) Placeholder: 16 (`data/bosses/beach_boss.tres`, phase 3's `hits`), which with the dives keeps phase 3 at
   about the old minute (55.8-61.1 s on the top, measured) and the par times where they were (three stars moved from
   177 s to 179 s).
2. **How many hits before each dive?** ("the Mecha Guppy can take some damage from the bombs ... and it will go
   underneath the water.") Placeholder: every 4 (`dive_every`), so three dives (and three waves and floor bites) in the
   phase; none after the last hit.
3. **The barrages' size and order of high and low bombs.** Placeholder: four bombs a barrage, a fixed looped script
   `"LHLH HLLH LLHL HHLH"` (`barrage_script`), one bomb at a time: the next one's warning no sooner than `bomb_gap`
   (1.5 s) after the last's and never before the last has passed the runner, `barrage_rest` (1.2 s) between barrages.
   A faster barrage (two bombs warned at once) would need a way to show which comes first.
4. **The bombs' warning and where they come from.** Every attack needs a visual and an audio warning. Placeholder: a
   red line across the lanes at the runner's distance, at the height the bomb will fly, and the gun's charge
   (cogs_charge, `bomb_warning` 0.8 s); the bombs fire from a new swivel gun on the captain's stern castle rail, just
   ahead of where he stands. The camera can't see beside the runner, so the ship keeps ahead of them (`level_ahead`
   11 m, a little more on a wider top: `CaptainCogsShip.level_lead`) and each bomb curves down and in over the eaves
   onto the line, then flies straight across every lane; on 5 and 6 lanes that curve comes from further ahead.
5. **The bombs' size and heights.** ("a little bit smaller".) Placeholder: radius 0.45 m (the phase 1 and 2 bombs'
   size; the old cannonball was 1.15 m); a low one 0.5 m over the deck (a jump clears it), a high one 1.28 m (a slide
   passes under it, standing or jumping doesn't).
6. **A bomb blocked by armor or a shield.** Placeholder: it bursts on the runner and doesn't hit Mecha Guppy (only
   dodged bombs do); the dash passes through one, which flies on and hits.
7. **The floor bite's size after each wave.** ("depending on how big the bite is".) Placeholder: from the right (Mecha
   Guppy's side), the first leaving one lane (lane 0), the next across every lane to jump, alternating; the climb's
   sizes and warning rules.
8. **Mecha Guppy's look on the right.** Placeholder: its floor-bite watch pose (upright, side-on, jaws shut), its head
   7 m ahead of the runner (`guppy_ahead`) so the whole head is in view; the bombs turn into its head's rear half after
   crossing the deck. Its splash: upright, facing the runner with its jaws wide, ahead where the wave's swell rises.
9. **The defeat's start.** Placeholder: on the last hit Mecha Guppy dives out of sight from its watch (0.45 s), then
   the defeat plays as before (it bursts up under the ship and eats the captain); the results wait 0.45 s longer.
