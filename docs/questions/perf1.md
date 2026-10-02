# PERF1: lag spikes

1. **The hit-stop on every kill** (GDD §3, "a brief freeze on kills"; G2's `RunEffects.freeze`). It holds
   the camera still for about three frames (0.05 s) while the run goes on underneath, so the runner moves
   1.0 to 1.25 m away from the camera and the view catches up in one frame: on screen that is exactly what
   a dropped frame looks like. A stocked-up player's run has 4 to 24 of them a level, about 6 a minute
   (`tools/measure/frame_times.gd`, the whole campaign); the build before the playtest had none, so they
   may be most of what reads as "more lag spikes". Freezes no longer chain (below). Should every kill keep
   it, or only stomps and big kills (a host, a hover truck, a boss's part), or a shorter one (one or two
   frames), or a freeze of a different kind (the enemy and the runner's animation held for a moment, the
   camera moving on)?
   - **Placeholder:** every kill keeps it, as G2 built it. Freezes never stack or chain:
     `SpeedFxTuning.freeze_gap` (0.3 s, `data/tuning/speed_fx.tres`, F6 "Speed effects") leaves out a
     freeze asked for within 0.3 s of the last one's start. Setting `kill_freeze_time` to 0 in F6 turns
     the kills' freeze off while keeping the stomps'; Settings > Screen shake off turns every freeze off.
     The frame-time graph (F7) marks every frame a hit-stop holds the camera, so a "spike" that is one
     shows as one.

2. **A level's start** (GDD §4, the flow into a run). A level is generated and built in the frame after
   the player picks it (0.3 to 1.8 s on the dev machine, the first level of a session the longest), and
   now also readies what it will need later instead of hitching mid-run (its enemy types' scripts and
   looks, 0.1 to 0.9 s more on the dev machine the first time in a session, and on a real renderer its
   shaders, drawn once in its first frame); a phone takes several times longer. The level select holds
   still meanwhile, then the run starts at once. Should a level open behind a short loading card (the
   zone's name on its colour, shown while it loads), or stay as it is?
   - **Placeholder:** no loading card; the screen holds still until the run starts, as before.
