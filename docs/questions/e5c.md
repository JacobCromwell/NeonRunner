# E5c: the Sleep Taker (step 1, E5c-a: the nightmare, its arena, entrance and attacks)

Numbers in `data/bosses/dead_zone_boss_tuning.tres` (F6 in its fight) and `data/bosses/dead_zone_boss.tres`;
play it with `./play.sh --boss=dead_zone_boss` (debug builds; a preview until E5c-b); review with
`tools/showcase/sleep_taker_showcase.tscn` (scenarios `model`, `front`, `entrance`, `slash`, `hands`,
`lights_out`, `fight`, `measure`). Everything below is `DESIGN-TBD`.

1. **The refuge from the giant slash** (GDD §10: "get out of those lanes, or up onto the ceiling"; at
   3 lanes a three-lane slash covers the whole street).
   **Placeholder:** every slash comes at a refuge: every 240 m (`refuge_spacing`, about 13 s) a charred
   bridge crosses the street (the Dead Zone's ceiling look) with a pad in the middle lane (both middle
   lanes at 6), at most one lane switch away at 3 lanes and two at 5 and 6; the slash's warning
   (1.9 s) starts 1.1 s before the runner reaches the pads and it strikes 0.8 s after, while a runner who
   took a pad rides the ceiling. At 5 and 6 lanes, leaving its three lanes dodges it as well, and a wall
   is always safe from it. The street is kept clear of holes and fences from the warning to the strike.
   **Alternatives:** a pad in every lane (`refuge_pads_every_lane`: a runner can't miss one, so the
   slash never threatens anyone who doesn't jump the pad); or, at 5 and 6 lanes, more slashes between
   the bridges, dodged only by leaving the lanes.
2. **Its look and size** (GDD §10: one colossal nightmare, black with purple highlights, dozens of
   circular maws and long clawed fingers).
   **Placeholder:** a hunched mass of fused Bad Dream heads over a chest and waist, trailing vapour to
   the street, 28 maws all facing the runner, two long arms hanging wide of the middle lanes and four
   tendrils of clawed fingers; about 12 m tall over 3 lanes, 18 m over 5 and 22 m over 6, filling the
   street 26 m ahead. Its great maw (the slash's warning) gapes in its belly, about 5 m up, so it shows
   under a refuge's bridge; the bridges cut through its upper body like a ghost's. Its throat and claws
   heat to enemy-attack red as it shrieks and slashes. **Alternative:** the great maw in its head (hidden
   by the bridge during a slash, leaving the red lanes and its rising arms as the warning's look).
3. **How dark** (GDD §10: darker than normal, never pitch black; lights out darker still).
   **Placeholder:** the arena at `darkness` 0.4 (the scenery at 72% of the Dead Zone's light); lights
   out, after a 2 s inhale, brings the arena's light down to 45% for 8 s, the scenery to 32% (its floor
   is 30%), then it breathes out and the light comes back over 1.6 s. Measured on screen at 5 lanes
   (`--scenario=measure`, grey value 0-255, the arena's light → the darkest point): the street 80 → 50,
   the walls 34 → 25 on Forward+, the same on the Compatibility renderer; the slash's red lanes, the
   hand's purple mist, the pink fence and generator, the cyan pad and its maws keep their colours and
   stand out from the street as much or more (their colour distance from it: red lanes 101 → 96, fence
   148 → 224, pad 194 → 233 on Forward+; red lanes 64 → 41 on Compatibility, where their bright edges
   carry them). Dark enough, or darker (it would need a lower floor than The Hush's 30%)?
4. **The hands** (GDD §10: purple mist pools in the lane, with whispering; switch lanes).
   **Placeholder:** one hand at a time, in the runner's lane: the mist pools 1.2 s before the hand bursts
   up, 0.45 s before the runner would reach it, about one every 3 s between the refuges; the hand reaches
   above a jump, so only a lane switch (or a wall or the ceiling) dodges it, and one only comes while the
   next lane is clear. The mist is the nightmare's own purple; only the hand's claws heat red as it
   rises. **Alternative:** a red line under the mist, like the other bosses' floor warnings.
5. **Its rhythm, and lights out with the other attacks** (GDD §10: hands and slashes keep coming in the
   dark). **Placeholder:** each phase's list (`attack_patterns`; the first: hands, hands, lights out,
   hands, hands, hands), one attack at a time, 1.3 s apart (`attack_gap`), never one that would still be
   on when the next refuge's slash is due; the dark lasts while the next attacks come. Measured on its
   arena at 5 lanes (`test_sleep_taker_attacks`): 61 s of pattern bring 4 slashes, 9 hands and 2 lights
   outs (a slash about every 15 s, a hand every 7 s, lights out every 30 s); fewer hands than the list
   asks for, since a hand only comes where its lane and the next are clear of the arena's holes and
   fences. Right amount? (E5c-b makes the later phases hungrier: faster hands, more lights out.)
