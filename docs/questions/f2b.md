# F2b, Gangland boss intro: open questions

The owner's story beat is in GDD §10 (Sewer Swarm, "Intro cinematic"). Built as `SewerSwarmIntro`
(`scripts/cinematics/sewer_swarm_intro/`); every number below is in `data/cinematics/sewer_swarm_intro.tres`
(`SewerSwarmIntroTuning`). Review it with `tools/showcase/cinematic_review.tscn -- --slot=gangland/boss_intro`,
or play it with `--level=gangland/boss_intro`. These questions are about what the beat leaves open.

- **How the runner dodges** ("easily avoids it", "dodges those", "runs past them"). Placeholder: the first screech
  pounces into the runner's lane and lands under them as they jump over it. Of the next three, the lone one leaps
  over the runner's lane as they slide under it, and the other two land in the lane ahead and swipe as the runner
  weaves round them (1.4 m to the right). The eleven land either side of the runner's lane and rear up and swipe
  as the runner runs straight between them. Each then gives chase and falls behind (`jump_at`, `slide_at`,
  `weave_at`, `third_land`, `chase_share`).
- **How the wall behind the runner is shown** ("soon we see that there is a wall or wave of screeches behind
  the character"). Placeholder: the camera stays at ground level (0.47–0.75 m up). It rides low behind the runner
  until 5 s, then swings round their right side (5.0–6.4 s) to low in front of them, looking back past them at the
  wall. Should it look back over the runner's shoulder instead (the runner out of view)?
- **Where the manholes are** ("manhole covers on either side of him"). Placeholder: rows one lane over on both
  sides of the runner, one every 6.5 m a side, the sides staggered.
- **What the wall looks like.** Placeholder: one wave across the street (6 m tall, its crest curling 8.5 m forward
  over the runner, as the fight's strike from behind does), with the rest of the swarm 26 m behind it. It rises
  from 6.3 s, 32 m behind the runner, and closes to 9 m by the cut. As it closes it heats toward enemy-attack red
  (0.25 to 0.5 on the fight's scale), the fight's colour for an attack. Should a cinematic use that warning colour
  at all?
- **The cut** ("a dark area, and inside that dark area, we can just make out a glint of the host").
  Placeholder: at 9.6 s, one cut to low between the runner and the wall, looking up into a dark hollow in the middle
  of the mass (1.9 × 2.3 m), with screeches heaped and crawling round its rim. The Host is held up inside it, its
  look darkened to a faint silhouette with a sickly edge. The implant at its temple glints red once, 0.9 s into the
  cut (with Reduced flashing, a slow, faint glow). Is the glint right, or should it be the Host's eyes, or the
  implants on its back (the fight's weak points)?
- **How it ends.** Placeholder: 2.4 s after the cut it fades to black (12 s in all), and the fight starts on its
  own view, whose Rising carries on from here. There is no card naming the boss, since the beat has none and
  GDD §1 asks for little or no words; the City's boss intro shows one ("ZONE 1 · BOSS / FLOATING HEAD"). Should
  Gangland's show one too, over the cut or the black?
- **How many screeches.** Placeholder: 15 in the beats; 2 to 6 out of each manhole in the pour; 110 dropping from
  the sky (45 on a low-end device); 900 in the wave and 560 behind it (360 and 220 on a low-end device). The phone
  test (risk test R4, task E3) should check these with the fight's.
- **Its speed.** Placeholder: the runner runs at Gangland's run speed (21.8 m/s), the fight's, so the fight
  follows at the same pace.
- **Slots.** This answers part of `docs/OPEN_QUESTIONS.md` items 11 and 200: Gangland now has a boss intro as
  well as the City. Should the other zones' bosses get one?
