# Questions from R3b (a waiting enemy keeps its place in the big-attack queue)

Follow-up to R3's "who goes first" (open questions, "From build phase 2" item 96) and R5's Octodog wait (item 157).
Measured with `tools/measure/big_attacks.gd`, big attacks taking turns, against main: every campaign level at 3, 5
and 6 lanes on its own seed and six others (9001–9006), and the eleven Octodog levels on fourteen more (9007–9020):
741 runs, about 30 hours of play, about 850 Octodogs; once before B3's narrow ceilings changed the levels' layouts
and once after.

1. **How long a waiting enemy keeps its place** (GDD §9, "Big attacks take turns"). The enemies waiting go in the
   order their waits began (R3's rule), but an enemy lost its place as soon as it was told it may go, or two frames
   after it last asked. An Octodog told it may go while the stretch its wait had moved its charges to wasn't clear
   yet paced on without charging, and once its 4 s `turn_wait_max` was used up it stopped asking: another type ready
   again (a drone's next barrage, a hover truck's cannon or lurch) went first, and the dog's slack ran out. On main
   this kept 3 dogs from ever charging before B3 (Golden 3 at 5 lanes, seed 9004; Dead Zone 1 at 5 lanes, seed 9017;
   Golden 3 at 6 lanes, seed 9019) and 4 after it (Dead Zone 1 at 3, 5 and 6 lanes, seeds 9007, 9017 and 9001;
   Golden 3 at 5 lanes, seed 9003).
   **Placeholder:** a waiting enemy keeps its place until its attack starts or it gives the attack up, as long as it
   keeps asking: through its turn too (told it may go, one that isn't quite ready and asks again still goes before
   those that waited less), and through a gap in its asks of up to `turn_place_grace` = 1 s
   (`data/tuning/game_rules.tres`, F6 "Game rules"; `DESIGN-TBD` in `scripts/core/game_rules.gd` and
   `scripts/enemies/enemy_director.gd`), while those behind it wait. After a longer gap it loses its place and the
   others go. An enemy that means to wait longer keeps asking: an Octodog that waited for its turn now asks every
   frame until it charges or its slack (40 m) runs out. An enemy that gives up says so and leaves the queue at once:
   an Octodog running off, a hover truck changing state (its pacing ended before its cannon's turn came, and the
   shot is skipped as before; or it leaves), a Resonator leaving, a dissolving Bad Dream.
   **Measured:** all those dogs charge now, after waits of 4.4 to 5.7 s. The dogs still without a charge (Gangland 3
   at 5 lanes, seed 9015; after B3 also Dead Zone 2 at 6 lanes, seed 9003) don't charge with turns off either: not a
   turn problem. Big attacks still never overlap, and no other enemy newly goes without its attack: run by run, as
   many drones (10, after B3 12, of about 810), hover trucks (about 20 of 810 never lurch, about 20 never fire) and
   Resonators (1, after B3 3, of about 350) as on main never get theirs in. 16 of the 741 runs play differently
   before B3, 17 after. The others lose a little: 7 (after B3: 4) fewer drone barrages of about 4,800, 1 (2) fewer
   cannon shots of 1,840, 2 (2) fewer lurches of 1,390; Resonators pulse 3 times more and once less before B3, 3
   times less after (of about 1,050). Waits for a turn barely change (from the first frame an enemy is held for
   another type's attack until its attack, a dog's until it charges; before B3): dogs' charges 86 → 89 waits, mean
   1.60 → 1.70 s, longest 5.60 → 5.72 s; drone barrages 853 → 865, mean 1.48 → 1.49 s, longest 7.7 → 9.5 s;
   Resonator pulses 235 → 236, mean 2.32 → 2.30 s, longest 22.6 s both; the hover trucks' and the Bad Dream's about
   as before (after B3 only the dogs' change: 88 → 92 waits, mean 1.55 → 1.65 s). A kept place cuts both ways: on
   Golden 2 at 6 lanes (seed 9014) a Resonator waiting for clear floor held the drones back for its 1 s and pulsed
   10 s sooner than on main (where two drones' barrages had kept it waiting 14.5 s), and a drone waited 9.5 s
   instead; but on Golden 1 at 6 lanes (seed 9006), and after B3 on Golden 1 at 3 lanes (seed 9015), the drone a
   Resonator held back fired that much later, over the Resonator's next clear moment, and the Resonator dropped one
   pulse of that visit (two after B3).
   Tried first: a 3 s grace, which fixed the same dogs but changed three times as many runs (12 of the first 489
   runs measured, against 4) and cost more of the others' attacks there (2 drone barrages, 2 lurches, a cannon shot
   and a Resonator pulse, against a lurch and a pulse).
   Right rule? Is 1 s the right "moment"? A longer grace makes the others wait longer for an enemy that isn't ready;
   a shorter one lets them pass it sooner. Or should an enemy in a gap keep its order without holding the others
   back (they may go while it isn't ready; when it asks again it still goes before those that began waiting after
   it)? That should spare the Resonators' pulses above (not measured), and the dogs would still charge (they keep
   asking), but a turn that comes during the gap would go to the others. And the cost of the dog's place: while it
   moves its charges on to a clear stretch, the others wait for it, up to its 4 s `turn_wait_max` plus its slack
   (about 2.2 s at run speed).
