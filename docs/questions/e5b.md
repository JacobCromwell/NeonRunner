# Questions from E5b-b (Hostile Takeover, phase 2: The Contract)

Numbers in `data/bosses/corporate_boss_tuning.tres` (F6 in the fight). Play it with
`./play.sh --boss=corporate_boss` (add `--phase=2` to start at The Contract); review it with
`tools/showcase/hostile_takeover_showcase.tscn --scenario=contract`. For a runner who never misses,
phase 2 takes about 25 s: phase 1's last guards clear, one or two strafes, the drop about 13 s in, then
the ride and the stomp (21 s from a checkpoint).

1. **The train's carriages, and the Tithe Collectors** (GDD §10: "carriage roofs are the floor and the gaps
   between carriages are the gaps"; phase 2's Buzz Overdrive "cuts a carriage lane"; OPEN_QUESTIONS items 319
   and 321).
   **Placeholder:** the train repeats corporate carriage, corporate carriage, military flatcar, then three
   corporate carriages. A corporate carriage is 50 m and a flatcar 130 m (at 18 m/s). A Buzz Overdrive needs
   about 100 m of whole roof in its lane, from its rev to its charge past the runner, which no corporate
   carriage has. In phase 1 a Tithe Collector comes on each flatcar from carriage 3, so item 319's "every
   fifth carriage" is now every flatcar, every sixth carriage. At most 2 come in a phase
   (`tithe_visits_per_phase`): without a cap, a runner who lets couplings go by could farm their 120-credit
   jackpots (item 321). Code: `HostileTakeoverTrain`, `HostileTakeoverBoard`.
   **Alternative:** longer carriages all along (a slower rhythm of gaps), or a cut that may span a gap. For
   the Collectors: one a phase, or none once the first coupling has been let go by.

2. **The strafes** (GDD §10, phase 2: "the gunship strafes the lanes (a warning line and a rising whine)").
   **Placeholder:** red lines light the runner's lane and the one beside it, from 3 m behind them to 40 m
   ahead, with a 1.2 s rising whine. At 3 lanes it strikes one lane; at 5 or 6 lanes, two; never all. Then
   the guns rake each line from its far end back past the runner at 55 m/s (at 18 m/s). A rake hits anyone
   in the lane, a jump included; leaving the lane dodges it, and the walls are safe. Strafes come about a
   second apart when nothing else is going on: never near the drop or the ride, and never while phase 1's
   guards are still about. Code: `HostileTakeoverContract`, `HostileTakeoverStrafes`.
   **Alternative:** a sweep across the lanes that a jump dodges, or a line that follows the runner from lane
   to lane.

3. **The drop** (GDD §10: the gunship "drops a Buzz Overdrive onto the roof ahead, which cuts a carriage
   lane").
   **Placeholder:** one lands on each flatcar. The gunship flies out over the spot, and a red target marks
   where it will land. The tank falls for 0.7 s and lands 0.6 s before its rev. From then on it is the C2
   tank: its rev and red line, its charge cutting the lane past the runner, and the block-then-hold rule. Its
   cut is planned like a level's (`FloorCutPlan`, `cut_problem`), in a seeded lane. Code:
   `HostileTakeoverContract.plan_drop`.
   **Alternative:** it lands further ahead and rolls in, as it does in the levels, or it drops onto a lane
   chosen from where the runner is.

4. **The armored carriage and the ride** (GDD §10: "an armored carriage with no roof access blocks the way,
   so the player takes an anti-grav pad and rides the gunship's belly over it (the gunship is the
   ceiling)").
   **Placeholder:** the second carriage after each flatcar is armored. It is 2.1 m tall: too tall to jump
   onto, and below a belly rider's jump. Its front is framed in the solid obstacles' yellow and black, and
   it is in sight 240 m ahead. Before it lies a runway of anti-grav pads in every lane, 18 m long at 18 m/s.
   That is longer than any jump, a dash in the air included, so no runner on the roof can skip it. The
   gunship comes down over the runner as they reach it and flies on slower than them, so they ride its belly
   over the armored carriage and drop off 10 m past its far gap. A runner who isn't flipped up (in practice,
   none) crashes into the armored front; the dash doesn't pass through it. Code:
   `HostileTakeoverArmored`, `HostileTakeoverContract.plan_ride`.
   **Alternative:** a single pad in each lane, as "an anti-grav pad" reads, which a jump can skip, or pads
   in some lanes only.

5. **Phase 2's weak point** (GDD §10 names none for The Contract).
   **Placeholder:** the gunship's drop bay, which the Buzz Overdrive fell from. During the ride it is open on
   the belly, glowing the weak points' red, with green chevrons before it. A jump on the belly that comes
   back up onto the bay stomps it, a stomp from the ceiling. A missed bay is harmless: the ride ends, and the
   next flatcar's drop and ride come about 23 s later. Each cycle brings another Buzz Overdrive, worth 600
   score to kill. Code: `HostileTakeoverGunship.bay_point`, `HostileTakeover._bay_stomped`.
   **Alternative:** a weak point reached another way (the tank's clamp under the belly, or a part shot
   off), or the phase's hit for just completing the ride.

6. **Weapons ending a phase** (GDD §10, the Floating Head: "weapons chip away slowly (tuned so even the
   best weapon saves at most one stomp over the whole fight)").
   **Question:** should weapons be able to end a boss's phase (saving one stomp, as the Floating Head's
   rule says), or should only stomps end phases? And should that be decided per boss?
   **Placeholder:** `BossDef.weapons_can_end_phase`, checked in `BossEncounter.damage()`. It is on for
   every boss (the behaviour so far, The House included: a 0.34 cap over three phases of a third each). It
   is off for Hostile Takeover (`data/bosses/corporate_boss.tres`), whose weapons chip a phase only to just
   above its end. Damage carries from one phase into the next. So a runner who chipped a phase to its floor
   starts the next one a hair above that one's end. In the preview, one stomp then ends phase 3 instead of
   three; phase 3 itself (task E5b-c) can decide how its hits count.
   **Alternative:** on everywhere (weapons may save a stomp in every fight), or off everywhere.
