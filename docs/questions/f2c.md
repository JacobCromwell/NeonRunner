# F2c, the Dead Zone's intro: open questions

The owner's story beat (October 9, 2026) is built as `DeadZoneIntro` (`scripts/cinematics/dead_zone_intro/`) in the
Dead Zone's intro slot. What the beat leaves open is a placeholder, with its numbers in
`data/cinematics/dead_zone_intro_tuning.tres` (`DeadZoneIntroTuning`, marked `DESIGN-TBD`).

**Answered by the owner the same day** (recorded in GDD §6, Cinematics, and §11, Music):
- The zone's title card appears in the close-up as it starts to fade to black. Built: it holds on the black.
- The runner's fall into the crater will be shown in a cinematic before this one. Its beats are still to come.
- The crater has a floor, and the host's crouched work over the bodies stays as it is.
- Instead of the zoom, there is a medium shot of the host, then the extreme close-up with its whole face filling the
  screen.
- New sound effects are fine where the existing ones don't fit; only new music is off. The owner left the call to
  the build. It now has five sounds of its own (below).

**Still open:**
- **How the runner gets out** ("shakes themselves and starts to pull themselves out"). Placeholder: they lie on their
  back, their hips 2.5 m from the crater's far wall. At 1.9 s they stir and lift their head, and from 2.35 to 3.0 s
  they shake their head (30° each way, 4.5 times a second, dying away) as they sit up. They kneel at 3.45 s and
  stand at 3.9 s, then stagger 2 m to the far wall, looking up at its edge, and reach up at 5.65 s. The cut is at
  5.75 s. They climb out toward the way the level runs, so the host is behind them.
- **The crater's size.** Placeholder: a 5.4 m gap in the runner's lane, its floor 1.42 m down (just deep enough that
  the runner, hanging from the edge, touches it), with three thin columns of the Dead Zone's own smoke and a faint
  cold light.
- **Where the cyborgs are.** Placeholder: 16 m down the street behind the crater, in the lane left of the runner's.
  The bodies lie face down with their screens dark. Should they show damage?
- **The cameras.** Placeholder:
  - The first shot is high over the crater's far end (4.8 m up, easing down to 4.0 m), looking down into it and
    down the street, with the cyborgs at the top of the view.
  - The cut to ground level puts the camera 1.3 m beyond the far edge, 0.16 m up, so at first only the hands show.
  - From 6.9 s the camera rises and pulls back (to 2.7 m back and 0.42 m up) as the runner gets to their feet.
  - The host starts to look over at 8.25 s, as the runner gets to their feet. The cut to the medium shot comes
    mid-turn at 8.6 s: 2.6 m in front of where its face turns, at its height, easing in to 2.15 m.
  - The extreme close-up comes at 10 s. The camera is straight in front of the screen, a little below its middle.
    The whole face fills 80% of the picture, pushing in to 92% by the time it's black, and the host's head holds
    still for it.
- **The host's face.** Placeholder: as it looks over, its usual face, with a host's random corrupted glitches. In the
  close-up, its corrupted grin, with its screen's glitch (row jumps and purple static) boosted from 1 to 1.8. With
  Reduced flashing it changes at the slower rate every host uses.
- **How it ends.** Placeholder: the close-up starts to fade to black at 11.5 s, over 1.2 s, and the title card comes
  up with it and holds on the black until 14.2 s (14.3 s in all). Then Dead Zone 1 opens on its own view.
- **Its sounds** (`tools/asset_gen/sfx_bank_cinematics.gd`). None of them is a hazard's warning.
  - `crater_smoulder` opens it: a low rumble, embers ticking, a hiss of smoke, pebbles trickling.
  - `rubble_shift` as they sit up, and quieter as a knee comes onto the edge.
  - `edge_grab` as the hands slap onto the edge, with grit trickling off it.
  - `host_turn` as the host lifts its head: its neck servo grinding under its screen's static.
  - `host_glitch` under the close-up: stuttering static, a sinking hum, row-jump clicks and a faint garbled voice.
  - The zone's music fades in over 5 s from the start. Should the runner have a voice (a groan, a cough)?
- **The new poses' look.** Placeholder: the runner lying, getting up and climbing out (`CinePoses`), and a cyborg
  lying still and crouched over something (`CyborgPoses.LIE`, `CROUCH`) are hand-set key poses. They are the
  toolkit's from now on, so any cinematic can reuse them.
