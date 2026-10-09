# F2c, the Dead Zone's intro: open questions

The owner's story beat (October 9, 2026) is built as `DeadZoneIntro` (`scripts/cinematics/dead_zone_intro/`) in the
Dead Zone's intro slot. What the beat leaves open is a placeholder, with its numbers in
`data/cinematics/dead_zone_intro_tuning.tres` (`DeadZoneIntroTuning`, marked `DESIGN-TBD`).

- **No title card** (GDD §6, Cinematics). The arrival flyover this replaces named the zone on a card ("ZONE 5",
  "DEAD ZONE"); the owner's beat has none, so this has none. Should it name the zone somewhere (over the crater
  shot, or on the black at the end)?
- **What put the runner in the crater** (GDD §1, a light story). The step before is the Corporate zone's outro,
  still the placeholder flyover. The crater suggests the runner fell or crashed into the Dead Zone. Should the
  Corporate outro end with that fall?
- **How the runner gets out** ("shakes themselves and starts to pull themselves out"). Placeholder: they lie on their
  back, their hips 2.5 m from the crater's far wall. At 1.9 s they stir and lift their head, and from 2.35 to 3.0 s
  they shake their head (30° each way, 4.5 times a second, dying away) as they sit up. They kneel at 3.45 s and
  stand at 3.9 s, then stagger 2 m to the far wall, looking up at its edge, and reach up at 5.65 s. The cut is at
  5.75 s. They climb out toward the way the level runs, so the host is behind them.
- **The crater** ("a smoking crater ... it looks like a gap"). Placeholder: a 5.4 m gap in the runner's lane, with the
  zone's orange gap edges. Inside it, 1.42 m down (just deep enough that the runner, hanging from the edge, touches
  the floor), is a floor of the zone's broken street plates, with slabs leaning on its walls and chunks of rubble.
  Three thin columns of the Dead Zone's own smoke rise from it, and a faint cold light keeps the runner readable.
  Holes in play never show a floor; this one does, because the runner lies on it. Is that all right?
- **Where the cyborgs are and what the host is doing** ("we can't tell if ... it was eating the other cyborgs or what
  exactly it was doing"). Placeholder: 16 m down the street behind the crater, in the lane left of the runner's.
  The two bodies lie face down with their screens dark. The host crouches over them, facing across the street,
  its hands down on them, each arm tugging back in turn, its screen bowed over them. It stops as it looks up. Is
  that ambiguous enough? Should the bodies show damage?
- **The cameras.** Placeholder:
  - The first shot is high over the crater's far end (4.8 m up, easing down to 4.0 m), looking down into it and
    down the street, with the cyborgs at the top of the view.
  - The cut to ground level puts the camera 1.3 m beyond the far edge, 0.16 m up, so at first only the hands show.
  - From 6.9 s the camera rises and pulls back (to 2.7 m back and 0.42 m up) as the runner gets to their feet.
  - As the host looks over (8.15 s), the camera zooms past the runner's shoulder onto it (field of view 50° to 16°).
  - The close-up (9.65 s) is in front of the host's screen, a little below it, pushing in from 0.75 m to 0.42 m.
  - Should the zoom be a cut to a medium shot instead?
- **The host's face.** Placeholder: as it looks over, its usual face, with a host's random corrupted glitches. In the
  close-up, its corrupted grin, with its screen's glitch (row jumps and purple static) boosted from 1 to 1.8. With
  Reduced flashing it changes at the slower rate every host uses.
- **How it ends.** Placeholder: the close-up holds for about 1.85 s, then fades to black over 1.1 s (12.6 s in all),
  and Dead Zone 1 opens on its own view.
- **Sounds and music.** Placeholder: existing sounds only, no new ones.
  - `doodad_push` for the rubble shifting as they sit up, the hands slapping onto the edge, and the knee on it.
  - `host_short` as the host's screen crackles while it turns.
  - `magnate_glitch` and a quiet `sleep_taker_whisper` (the Bad Dream inside it) under the close-up.
  - The zone's music fades in over 5 s from the start.
  - Should the cinematic have sounds of its own (a groan, a cough, a scrape)?
- **The new poses' look.** Placeholder: the runner lying, getting up and climbing out (`CinePoses`), and a cyborg
  lying still and crouched over something (`CyborgPoses.LIE`, `CROUCH`) are hand-set key poses. They are the
  toolkit's from now on, so any cinematic can reuse them.
