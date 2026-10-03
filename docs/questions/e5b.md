# Task E5b-c: Hostile Takeover, phase 3 (The Merger), the defeat and its campaign slot

- **The docking and MERGER COMPLETE** (GDD §10, phase 3: "the locomotive comes back and the gunship docks
  onto it with huge clamps, forming one monstrous war engine, and 'MERGER COMPLETE' flashes on every
  screen"; the player glimpses the Chairman "as the face on the 'MERGER COMPLETE' screens"). Which screens,
  and how long does the docking take?
  **Placeholder:** once phase 2's last ride is over, a 3 s docking: the locomotive comes back from far ahead
  to 64 m ahead of the runner while the gunship settles onto its rear, three arms gripping it and its three
  clamps unfolding as they lock. Then MERGER COMPLETE flashes for 5 s (steady with Reduced flashing) on the
  locomotive's rear window, turned screen, and on two ad screens on pylons that rise beyond the sound
  barriers and pace the train ahead (the arena has nothing over the street). Each shows the Chairman's face
  as a corporate broadcast; he leaves his window. The war engine's first strafe waits 1.5 s after the words
  come up. Code: `HostileTakeover._update_merger`, `HostileTakeoverScreens`, tuning group "The Merger".
  **Alternative:** the city's own screens on the towers, a longer docking the player watches, or the
  Chairman staying at his window.
- **How the clamps are reached** (GDD §10: "the player stomps the three glowing docking clamps (red weak
  points) to tear the gunship loose"; it doesn't say where the clamps are or how the runner gets to them).
  **Placeholder:** after each drop, a pass: a runway of anti-grav pads on the carriage after the flatcar;
  the war engine comes back down over the runner there, and they ride its belly forward at 3 m/s (at any
  run speed, 6.3 s) under its three clamps, one under each third of the belly (7, 12.75 and 18.5 m from its
  stern), each glowing red with green chevrons behind it. A jump from the belly that comes back up onto a
  clamp stomps it. Then the war engine pulls away and the runner drops back onto a roof clear of the gaps.
  All three can be torn loose in one pass (1.9 s apart: after a stomp's bounce there is time for a
  reaction and two lane moves), and clamps missed come around on the next pass, about 25 s later. Code:
  `HostileTakeoverContract.plan_pass`, `HostileTakeoverGunship.clamps`, tuning group "The Merger".
  **Alternative:** the clamps reached from the roof (a ramp onto the locomotive), one clamp a pass, or the
  clamps on the war engine's rear, stomped with a jump from the roofs.
- **Phase 3's attacks** (GDD §10: "its attacks combine both"). Which of the earlier phases' attacks come
  back, and how dense?
  **Placeholder:** the Board's guards (one on the first carriage of each consist of six) and partial wall
  fences (on its first two carriages; no Tithe Collector), the war engine's drops (a Buzz Overdrive onto
  each flatcar, as phase 2's) and its strafes, only when nothing else is going on (one attack at a time, as
  in phase 2). In a fight without a miss, phase 3 shows the Board's pieces, a drop and the pass; strafes
  come between later cycles (after a missed pass). Code: `HostileTakeoverBoard.merger`,
  `HostileTakeoverTuning.merger_board_slots`, `merger_guards`, `merger_hold`.
  **Alternative:** a strafe guaranteed before the first pass (the phase grows by a few seconds), or a
  denser Board.
- **How phase 3's three hits count** (follows item 336: weapons can't end Hostile Takeover's phases).
  **Placeholder:** a framework change, `BossEncounter.phase_hits`: while a boss's weapons can't end a phase,
  its big hits are counted. Each deals an equal part of what's left of the phase for each hit still to
  land, and only the phase's last one ends it, exactly at its end. So nothing weapons chipped carries into
  the next phase, and phase 3 always takes its three clamps, however far weapons chipped it (weapons still
  chip within their 0.34 cap). Code: `BossEncounter.hit_damage`, `BossEncounter.damage`.
  **Alternative:** damage carrying over (a phase chipped to its floor shortens the next one), or counting
  only the last phase's hits.
- **The defeat** (GDD §10: "the gunship spins away and explodes; the locomotive derails and ploughs
  through the lobby of a corporate tower, bringing down a giant, soulless logo sculpture").
  **Placeholder:** the last clamp torn loose, the gunship pulls free, climbs away spinning and explodes
  1.6 s later; the locomotive surges on, veers off the guideway to the right and ploughs into the sky lobby
  of a corporate tower standing beside the line at the train's level 2.6 s in, the brand's mark (a giant
  steel sculpture on its plaza) toppling; the screens glitch and go dark. The runner and the rest of the
  train run on along the guideway, and the results come 5.5 s after the stomp. Code:
  `HostileTakeover._on_defeated`, `_place_defeat`, `HostileTakeoverLobby`, tuning group "The defeat".
  **Alternative:** the whole train derailing (the runner jumping clear), or a cut to a short cinematic.
- **Par times** (GDD §10, proposed: stars for beating par times set per boss).
  **Placeholder:** 74 s for three stars and 96 s for two. A fight without a miss takes 68.6 s at 3, 5 and 6
  lanes and at 18 and 23.4 m/s; a missed pass costs about 25 s. Data: `data/bosses/corporate_boss.tres`.
