# E5c: the Sleep Taker (step 2, E5c-b: hurting it, the phases, the defeat, its campaign slot)

Numbers in `data/bosses/dead_zone_boss_tuning.tres` (F6 in its fight) and `data/bosses/dead_zone_boss.tres`;
it plays after Dead Zone 2 (`--level=dead_zone/boss`, or `--boss=dead_zone_boss`); review with
`tools/showcase/sleep_taker_showcase.tscn -- --scenario=lure` (with `--phase=2`: the defeat). Everything
below is `DESIGN-TBD`.

1. **The lure** (GDD §10: "the player lures it close (it lunges toward them), then destroys the generator
   with a stomp or the dash").
   **Placeholder:** going for a generator is the lure. 3 s before the runner reaches one
   (`lure_seconds`), the nightmare lunges in after them with a hungry roar and holds its claws 3.5 m in
   front of them, attacking nothing, until they're past it. While it's lured and within 24 m of the
   generator (`emp_reach`, at 18 m/s; it scales with the run speed), pink arcs crackle from the generator
   into it: smash the generator now. The arcs show 1.7-1.8 s before a stomp lands (at 18 and 24.2 m/s,
   at 3, 5 and 6 lanes). Hovering, it's never in reach. **Alternative:** lure it with its own slash (a
   generator by a refuge, smashed while it lunges in to strike).
2. **The generators** (GDD §10: they "stand along the route"; "a missed generator is followed by
   another"). **Placeholder:** one at a time, from 9 s into each phase's pattern (`generator_delay`),
   placed in sight 160 m ahead (at 18 m/s: about 9 s, at any speed) in the runner's lane, or the nearest
   lane whose floor is clear around it, never near a refuge's slash or under a ceiling; another 3 s after
   a miss. They power no fences of their own, and a pink beacon rising from each shows through the
   nightmare, which looms between the runner and it. **Alternative:** fixed spots in the arena, each
   powering a fence or two.
3. **Its phases** (GDD §10: three EMP hits, hungrier each phase: faster hands, more lights out).
   **Placeholder:** each EMP tears a chunk away (its left cluster of heads, then its right, ripping off in
   a burst of wisps), and it recoils howling and re-forms over 2.5 s. Phases 2 and 3 run at pace 1.15 and
   1.3 (shorter hand warnings and gaps) with more lights out in their lists. A phase begun with the armor
   down counts as a break (`armor_when_unprotected`, as for the Floating Head).
4. **The defeat** (GDD §10: hundreds of wisps, faint faces or figures drifting upward; "then silence, and
   the first grey dawn light").
   **Placeholder:** 260 wisps (faces with open mouths, sleeping faces, figures with raised arms) rise and
   fade over 4.5 s as it dissolves. The music fades out over 2 s, and the win plays no victory riff. Then
   the night sky turns to a grey dawn over 3.2 s (the light up to 1.25 times the zone's own), and the
   results follow. **Alternative:** keep the victory riff, as after every other win.
5. **Its length and par times** (GDD §10: 60-120 s; stars from par times).
   **Placeholder:** a runner who never misses wins in about 78 s (measured at every lane count and at
   18 and 24.2 m/s); a missed generator costs about 12 s. Three stars at 86 s or less, two at 110 s or
   less (up to two misses).
