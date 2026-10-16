# Architecture: Boss: Mecha Guppy and Captain Cogs

One part of the architecture notes; `docs/ARCHITECTURE.md` is the index of every part and topic.

## Bosses (continued)

**Mecha Guppy and Captain Cogs** (GDD §10, task E5e, in steps: E5e-a, the climb's core in the framework and the player,
above; E5e-b1, the climb, its look and the fight's frame; E5e-b2, Mecha Guppy's model and bites, Captain Cogs and the
bombs; E5e-b3, the hits by baiting, phase 2's bombs and its higher climb; E5e-c, phase 3 and the defeat; E5e-d, walls,
likely none; E5e-f, Mecha Guppy's floor bite; E5e-g, phase 3 as the owner reworked it on October 15, 2026). The Beach's fight is built: the campaign plays it after Beach 3 at the
Beach's 23.8 m/s under Sunset Strip's sunset (`Campaign.configure_boss`, its arena naming no sky), and debug builds play
that step with `--level=beach/boss` or `--boss=beach_boss` (`--phase=3` from the climb's last steps before the top). The
runner climbs through phases 1 and 2, the camera following them up past a waterfall, and the climb has to read as
climbing high (the owner's idea; task E5e-b1's review): every roof tops a tower that stands down to the water, Mecha
Guppy eats chasms between them, and the backdrop is anchored at world heights:

- **A step** (`MechaGuppyClimb`, the plan; pure numbers, so the suites check it over many steps without the
  engine). Step k takes the runner from roof k up to roof k + 1; roof 0 is the street the fight starts on. A
  strip of anti-grav pads crosses every lane at the end of roof k (but the notch's, below), longer than the longest
  jump at the run speed with the dash's reach, so every runner flips up. A tiki hut hangs over it (`hut_height`,
  8.5 m over roof k, at least `hut_clearance` over the roof under its end: the riding view, 3.6 m under a ceiling, is
  then 1.9 m over the higher roof, so its deck shows), full width until the lanes that don't lead up end. Roof k + 1
  stands `rise` (3.0 m; `phase2_rise`, 3.6 m, in phase 2) higher under the hut's end. Mecha Guppy has eaten roof k
  from just past its pads (`edge_margin`): a drop off the hut in a lane that leads up lands on roof k + 1, and a drop
  in any other lane falls into the chasm down to the water, a death unless the grapple saves it. Then the run on roof
  k + 1 (`roof_seconds`, 3.6 s at 3 lanes and a lane switch more for each lane past three, from `Step.free_at`: where
  a rider can first switch lanes there, dropping off the hut over its full width on RUN_ON, where it widens past a
  pier on REACH_BACK) to the next pads holds a volley spot and the bait at its end; a roof with a floor bite has the
  bite first, then its bait (roof 1: its bite alone; below).
- **The bait's notch** (task E5e-b3; `Roof.notch_lane`, `notch_from`): every roof from `FIRST_NOTCH` (roof 2) on has
  an outer lane eaten from `notch_back` (7.5 m) before the next hut to its end (`Roof.covers` and `end_in` know it),
  on a side seeded by the roof's index alone (on a roof with a floor bite, the bite's side, below), so it has nothing
  to do with the lanes that lead up (no third cue: the suite plans the climb with other lanes leading up and finds the
  same sides). Roof 1 has none: its run brings the climb's first floor bite, alone (task E5e-f's review; it used to
  bring the first volley, so that the bait came once that had been learned: E5e-b3's review's O5), and the first volley
  comes on roof 3, after the first bait. A roof whose run is too short for it (`notch_after()`, a reaction, a lane
  switch and `dodge_margin` past where its run begins, so a runner who lands in the notch's lane can leave it) has none.
- **The floor bite** (task E5e-f; GDD §10, the owner, October 11, 2026, "The floor bite"; `MechaGuppyCrescent`,
  `Roof.bite`, `MechaGuppyFloorBite`; DESIGN-TBD): Mecha Guppy bites a shark-bite crescent out of the roof the runner is
  still running on, between their landing and the pads, leaving one lane (in phase 2 sometimes none: a gap to jump).
  - **Which roofs** (`bitten`): roof `FIRST_BITE` (1), the first tower, where it comes on its own (no volley, no bait:
    one new mechanic at a time; task E5e-f's review moved its volley off, so the climb teaches the floor bite on roof
    1, the bait on roof 2 and the volley on roof 3), and every other roof from `FIRST_NOTCH` on (the even ones, which
    REACH_BACK steps lead onto), each with its bait after it and no volley (the bite takes the volley's place); the odd
    roofs from 3 on keep their volley and bait, so phase 2's landing spots (after RUN_ON steps) stay. A bitten roof's
    run is as long as `roof_run_seconds` or as its bite and then its bait need (`_bite_room`: the crossing back to the
    notch's lane before the bait locks; the full-width bite's room counted too, so the steps are as long in each
    phase): from roof 2 on, 4.18 s against 3.60 s at 3 lanes and 18 m/s (3.90 s at 23.8 m/s), 4.74 (4.46) against 3.88
    at 5 lanes, 5.02 (4.74) against 4.02 at 6 lanes; roof 1, with no bait, the usual run. Planned with the step from its
    roof (`_plan_bite`), before the notch.
  - **The shape** (`MechaGuppyCrescent.make`, `_sample`): a half-ellipse from one side, `floor_bite_length` (12 m) long
    at the bitten side, sampled into `POINTS` (65) edge points (`ds`, `ws`: track distance and how far in from the
    bitten side's wall), its edge scalloped by `TEETH` (12) teeth bulging back toward the floor by up to `TOOTH_BULGE`
    (0.3 m), fading toward its ends; a tooth at the deepest point. One that leaves a lane (`keep`, the far side's outer
    lane) reaches exactly that lane's inner edge at its deepest (5.1 m, 9.9 m, 12.3 m at 3, 5, 6 lanes): it takes 2 of
    3, 4 of 5, 5 of 6 lanes there and fewer toward its ends (`taken_at`, `left`, `takes` against a runner's footprint).
    A full-width one (`full`; `_bite_full`: phase 2, every `full_every`-th (2) bitten roof from `FIRST_NOTCH`, roofs 4,
    8, 12...) is `full_jump_share` (0.7) of a full jump long at the bitten side (8.4 m at 18 m/s, 11.1 m at 23.8 m/s)
    and crosses the whole floor over `full_through` (0.6) of it (`cut_from`, `cut_to`), so each lane's stretch
    (`lane_stretch`, from its floor's edge on the bitten side) is shorter than a jump, the far side's the shortest
    (6.3-8.4 m and 8.3-11.1 m).
  - **When and where** (`_bite_front`): its front a reaction (with `WARN_SLACK`, 0.15 s, for a frame and a busy shark)
    and `bite_crossing()` (every switch from the farthest lane to the one it leaves, `dodge_margin`, half a hurtbox and
    the dash's reach, as the climb's other margins hold a runner who dashes) past where its riders can first switch
    (`Step.free_at`), the reaction counted from there because that is where its warning can be read (task E5e-f's
    review: from a hut, and dropping off its end, the crescent on the roof ahead is a sliver a few pixels high), never
    from before the hut's deadline (its warning never shows sooner: no cue to the lanes that lead up); `LAND_CLEAR`
    (2 m) past the landing; late enough that Mecha Guppy rises and lunges (`bite_chain()`) after the deadline before
    the snap. It comes 1.24-1.73 s after the riders can first switch. Its warning at `warn_at`,
    `bite_warning_seconds()` before it (`floor_warning`, 1.8 s, but no less than a reaction, the slack and the
    crossing, nor than the chain and the snap's lead: 1.99 s at the defaults), never before the deadline; its snap at
    `snap_at`, `snap_lead()` before it (`floor_snap_lead`, 0.45 s; over a full-width one at least `SNAP_CLEAR`, 1 m,
    before the earliest take-off that clears it). `bite_latest()`: past that the warning can't be fair any more and
    the bite is skipped.
  - **Its side** (`_bite_side`): seeded by the roof's index, never three bites running on the same side, nothing to do
    with the lanes that lead up (the suite plans with other lanes leading up and finds the same bites). A bitten
    roof's notch is on the bite's side (`_notch`), so the lane it leaves is never the notch's; its end comes 1.62-2.24 s
    before the notch.
  - **Collision and look follow one polyline**: `Roof.covers` leaves the bite out of the lanes it takes once it's warned
    (`keeps` leaves it out from the start, warned or not: the pickups and the saves keep off where it will be),
    `MechaGuppyStairs.eat_crescent` rebuilds
    the roof's pieces across it (`_bitten_floor`: one convex shape per edge stretch, the floor from the edge to the far
    wall, with a lane blocker under it like a roof's side), and `MechaGuppyLooks` draws the deck clipped stretch by
    stretch (`_deck_bitten`, `_clip_floor`), the orange lip and coping along the scalloped edge, the glowing strip and
    the broken face down to the water, its dark timber fading into the sea haze the deeper it goes (`_bite_edge`,
    `_bite_deep`: task E5e-f's review, so a full-width trench reads as a drop), and leaves out the tower's side, eave
    and lanterns along it.
    A ray grid over each eaten bite finds the floor exactly where the deck is drawn.
- **The lanes that lead up**: a block of neighbours, one on 3 lanes, and on 5-6 lanes the counts in
  `up_counts` (1, 2, 3, 1, 3, 2), never every lane. Where the block sits is seeded (the fight's rng key, "climb"
  and the lane count, then each step's index): the same on every attempt, never the same block twice running,
  nor three times running for the same cue.
- **The two cues** alternate step by step, starting with RUN_ON:
  - RUN_ON: the hut's lanes that lead up run on `run_on` past the higher roof's front, and the others end short
    of it.
  - REACH_BACK: the hut ends across every lane together, and the roof's lanes that lead up reach `reach_back`
    back under it, on a pier in front of the tower (it reads as a landing, not a wall). A REACH_BACK step has
    at most two such lanes (`REACH_BACK_MOST`, the owner's "one or two of the roof's lanes"); they start no
    nearer than `TONGUE_CLEAR` past the latest settle, however far `reach_back` asks, so no flip meets their
    front.
- **Fairness** comes from the movement itself: a jump's airtime, the flip up to the hut, the drop off its end
  and the fall into the eaten floor, each integrated frame by frame as `Player` moves (`_surface_seconds`), at
  the run's speed and with the dash's reach. So the climb holds at any speed and movement tuning.
  - The `settle` point is the latest a rider can settle on the hut: a jump right before the pads, the dash,
    then the flip up.
  - From `settle` to the `deadline` (where the other lanes end, or the hut ends) there is `read_seconds` (0.9 s)
    plus every lane switch the farthest lane needs. A rider anywhere on the hut reaches a lane that leads up
    in time (`margin()`), and a rider who didn't jump gets about a second more. On physics the worst case (the
    farthest lane with pads, a jump and the dash right before the pads, reading `read_seconds` late, a slow
    switcher) presses its last switch with 0.04-0.13 s to spare (the lane is committed at the press:
    `Player._start_switch`).
  - The hut is full width until the deadline, so the narrow-ceiling rule never holds a rider in a lane that
    doesn't lead up while there's time.
  - A wrong drop is dead, or saved, before it reaches the higher roof's front, even dashing (`wrong_reach()`).
  - Each roof's pads come where it's full width, and huts never overlap.
- **Its distances follow the pace**: those that stand for a time (`reach_back`, `run_on`, `hut_lead`) are
  metres at 18 m/s multiplied by the pace, the margins are seconds, and heights (and the notch, sized by the shark's
  head) don't change.
- **Phase 2's faster climb** (GDD §10, 15-25%): its roofs stand `phase2_rise` (3.6 m) higher instead of 3.0 m, its
  steps as long as phase 1's (each roof's run holds a volley spot and the bait), so every margin stays: 20.0% faster
  at 3, 5 and 6 lanes and both speeds (`climb_rate`, and on physics). The steps in sight when the phase changes stay
  as they are (their notches too); the first one past the edge of sight is phase 2's: measured, its pads come
  10.6-18.7 s after the phase begins.
- **Phase 3, level with Captain Cogs** (tasks E5e-c and E5e-g, the owner's rework of October 15, 2026; `MechaGuppyTop`,
  DESIGN-TBD, `docs/OPEN_QUESTIONS_ANSWERED.md` items 888-896, answered, stands as built): its step is the top, the roof the runner is on running on flat with no pads or
  hut (and no notch), planned right after the steps in sight (it comes 4.0-13.9 s after phase 3 begins, measured).
  Captain Cogs' bombs of the climb stop as phase 3 begins (`attacks_live`); Mecha Guppy's bites of the climb go on through
  its last steps and stop when the runner stands on the top (`on_top`, `bites_live`): then `top_reached` is logged and
  signalled, the waterfall and its low cloud fade out (the Beach's own backdrop under the run's sky), and phase 3 begins
  (`MechaGuppyTop.begin`). It runs by acts (`MechaGuppyTop.Act`: `RISE`, `BARRAGE`, `DIVE`, `SPLASH`, `WAVE`, `BITE`,
  `RETURN`), only while the boss is vulnerable and its attacks are on; everything is timed by the fight's clock and the
  runner's own moments (a bomb or a wave passing them), so a retry plays the same:
  - **The bar is Mecha Guppy's health** (the owner: "the timed aspect of phase three is to be replaced instead with a
    health bar"): phase 3 has 16 hits (`BossPhase.hits`), `register_hit` counts them once the runner is on the top (none
    on phase 3's last steps of the climb), each drops the bar by one hit's share, and the 16th wins the fight.
    `health_runs_down()` (the framework's steady run-down, used by the old minute) stays false.
  - **The ship comes level on the left** (`CaptainCogsShip.come_level`, `level_seconds` 3 s): eased from its station over
    the climb to one alongside the top (`LEVEL_SIDE`), its hull `level_out` (2.5 m) outside the top's eaves, its keel
    `level_keel` (1 m) under the deck, its middle `level_lead()` ahead: `level_ahead` (11 m) and `LEVEL_PER_WALL` (0.8)
    more for each metre a wider top's wall line stands past a three-lane top's, so the captain on his stern castle stands
    on the run camera's left (measured: from every lane but a wide top's outer right ones; its sail from every lane).
  - **Mecha Guppy's watch on the right** (`MechaGuppyShark.top_watch`, `Kind.WATCH`; the owner, October 15, 2026: "horizontal,
    as though it is swimming alongside the player and the roof"): it rises (`guppy_rise` 1 s, the rumble) out of the
    water into a level pose beside the top on the right (pitch 90°, yaw 180°: its snout ahead along the track, its back up,
    an eye toward the runner, its jaws shut), its hinge `SWIM_SINK` (1.2 m) under the deck so the upper half of its face
    is over the water, its broadest `SWIM_CLEAR` (0.8 m) outside the eaves, its hinge `guppy_ahead` (10 m) ahead of the
    runner and its body running back alongside them, keeping pace (`advance`'s pace), bobbing `SWIM_BOB` (0.35 m, with
    a `SWIM_NOD` of its snout) and surging forward and back `SWIM_SURGE` (1.6 m) as it keeps up. The owner chose this
    view over one far enough ahead to show its dorsal fin (16-31 m behind its jaws). Its dive (`top_dive`) sinks it
    still level.
  - **The water** (`MechaGuppyTop._place_water`, `water_y`): from phase 3's start, a plane of sea water on each side of
    the top (`WATER_SIZE`, from the eaves outward, keeping pace; the backdrop's sea shader in the Beach's `sea_mid_color`)
    at Mecha Guppy's waterline, so it swims rather than hangs in the air, alike on both sides (the owner); the splash's
    plumes break out of it and the defeat's swim away leaps out of it (`MechaGuppyLeap._sea_y`).
  - **The barrages** (`MechaGuppyBarrage`; the owner: bombs "horizontally ... jumpable and dodgeable ... some will be up
    high and some will be down low ... a little bit smaller"): from `top_first` (4 s) on, word after word of
    `barrage_script` ("LHLH HLLH LLHL HHLH", looped), one bomb a letter, L low, H high. A bomb's warning (`fire`): the
    captain's swivel gun on his stern castle's rail (`CaptainCogsModel.swivel_at`, `CaptainCogsShip.swivel_world`)
    charges (cogs_charge, as long as `bomb_warning`, 0.8 s) and a red line shows across every lane at the runner's
    distance at the bomb's height, keeping pace (pulsing, steady with Reduced flashing). Then the shot (cogs_cannon;
    `fire_swivel`: flash, smoke, a little recoil, the captain's arm): the bomb (`MechaGuppyBombs.bomb_mesh` at
    `bomb_radius` 0.45 m, the old cannonball's 1.15) follows `path()` in the runner's frame: a cubic from the muzzle down
    and in over the eaves onto the line `ENTRY_OUT` (0.9 m) outside the wall line, straight across every lane at the
    runner's distance at `bomb_speed` (20 m/s), and a cubic on into Mecha Guppy's head (`top_flank_x`, `top_flank_ahead`):
    nothing over the lanes but the line. Its hitbox (`hit_size`: 80% of the bomb across and along, 85% up; an enemy
    attack, live only over the deck) stands `low_height` (0.5 m: 0.12-0.88 m, a jump's feet clear it for 0.44 s, a
    slide's 0.45 m hurtbox doesn't pass under it) or `high_height` (1.28 m: 0.90-1.66 m, over a slide, under a standing
    runner's 1.09 m top, over a jump's reach) over the deck. The next bomb's warning comes `bomb_gap` (1.5 s) after the
    last's at the soonest and never before the last has passed the runner by `beat_spare` (one line, one dodge at a
    time); `barrage_rest` (1.2 s) between barrages. A bomb that reaches the shark is a hit (`MechaGuppyTop.bomb_landed`:
    the clang, the fireball, a shudder, and its roar, guppy_roar); one that met the runner (armor or the shield took it) bursts there and hits
    nothing; the dash passes through one, which flies on (a hit).
  - **The dive, the splash, the wave and the bite** (the owner: "it will go underneath the water. And then when it
    reappears, it causes a splash, which causes the wave attack. Then, after the wave attack, the Mecha Guppy will do its
    signature chomp bite"): after every `dive_every` (4) hits a barrage fires no more; once its bombs are done and
    `DIVE_AFTER` (0.5 s) after the hit, the shark sinks out of sight (`top_dive`, `bite_sink`), and `surface_after`
    (0.8 s) later it bursts up out of the sea ahead on the right (`top_splash`, `Kind.SPLASH`: upright, facing the runner,
    its jaws wide and opening along the track, its head `SPLASH_CLEAR` outside the eaves; a plume, `MechaGuppySplash`, as
    it breaks out and as it falls back; guppy_leap), exactly where the wave's swell then rises as it falls back in
    (`MechaGuppyWaves.start`; the wave below). Once the surge has passed the runner by `bite_after` (0.4 s), its floor
    bite on the top (`MechaGuppyClimb.plan_top_bite`: from the right, the climb's sizes and every promise of its warning,
    `bite_warning_seconds`; the first leaving lane 0, the next across every lane to jump, alternating; the top's bites in
    `Roof.top_bites`, which `covers`, `keeps`, `bite_over`, `MechaGuppyStairs.eat_crescent` and the looks follow), the
    climb's floor bite from there on (`MechaGuppyShark.floor_bite`, `MechaGuppyFloorBite`). Once it has sunk away and the
    runner is past its gap, it rises back into its watch and the next barrage begins `barrage_rest` after.
  - **The sea at the bottom of its holes** (task J3; the owner, October 2026: "When the shark bites the roof in the beach
    boss battle, there is an open space in the THIRD phase. That open space should have blue water at the bottom. The
    shark bite in phase one and phase two still works great"; `MechaGuppyBiteWater`; DESIGN-TBD, `docs/questions/j3.md`).
    Each bite's hole opened onto the top's tower: its broken face ran down 40-75 m into the haze (3 m to the street's dark
    pool water from a `--phase=3` resume), an open space with the sea right beside it but none at its bottom. From its
    snap (`bite.eaten`), each bite on the top has a sheet of that same sea under it, in the same look (the backdrop's sea
    shader in `sea_mid_color`), at the surface of the water beside the top (`water_y`, `SURFACE_UNDER` below it so the two
    never fight). The sheet covers the crescent's span and `ENDS` (6 m) past each end, across the deck from its deepest
    point (wall to wall for a full-width one), and runs out through the bitten side, where its wall and eave are gone, to
    `OVERLAP` (0.5 m) under the water beside the top (both sides for a full-width one). The hole shows the sea at its
    bottom, one with the sea beside the top. Past the crescent's ends, the eave's open ends over the gap the water beside
    the top leaves at the tower's wall show water too, not a triangle of haze (task J3's review). Under the deck the tower
    hides the sheet. A pool of `SHEETS` (3) quads is built once and laid each frame (`update`; `holes` for the tests);
    nothing shows before the top, nor before a bite snaps. It is a look only, with no collision: phase 3's timing,
    hitboxes, attacks and falls are as E5e-g built them (a runner who falls in falls through the water, with no splash),
    and phases 1 and 2 are unchanged.
  - **The waves** (`MechaGuppyWaves`, `mecha_guppy_wave.gdshader`; the owner's warning: a rising swell and a roar, jumped
    like the Resonator's ring): `start()` raises a swell out of the sea beside the top on the right, Mecha Guppy's side
    (`WAVE_SIDE`) over `wave_warning` (1.2 s) with its roar (wave_swell, as long): from `SWELL_RISE` (11 m) down,
    eased out hard, so its crest breaks the deck's line within `CREST_BY` (0.25 s; task E5e-c's review found it hidden
    for half the warning from 30 m down) and stands `CREST_Y` (7.6 m) over the deck by the crash (`crest_above`, for the
    tests); then it crashes over every lane `wave_ahead` (24 m) ahead (wave_crash, foam bursts, a shake: the swell moves
    in, drops and flattens, `CRASH_*`) and its surge rushes along the deck at the runner at `wave_close` (30 m/s), 2.0 s
    after its warning: a low band across every lane `wave_height` (0.45 m) tall and `wave_depth` (0.5 m) deep, the
    Resonator's rule (a normal jump clears it), an enemy attack. The swell is a medium-bright turquoise wall of sea
    water with white foam along its crest, the surge a paler teal sheet with a white foaming crest, never glowing; the
    surge's face carries one red line low down (the Resonator's ring red, the hazard's own sign), and its look is a
    little bigger than its hitbox. Its streaks stand still with Reduced flashing.
  - **Fairness and measured**: `test_mecha_guppy_top` checks the bombs' bands and warning at both ends of every phase 3
    tunable's range (`MechaGuppyTuning.TOP_TUNABLES`), and a runner reacting `dodge_reaction` late (`MechaGuppyBot`:
    jumps the low bombs, slides under the high ones, jumps the waves, reads the top's floor bites) wins phase 3 untouched
    at 3, 5 and 6 lanes and 18 and 23.8 m/s: 16 bombs (8 low, 8 high), 3 dives, 55.8-61.1 s on the top.
- **The defeat** (`MechaGuppyLeap`, DESIGN-TBD; started by `_on_defeated`, ticked by `_defeated_tick`): as phase 3's
  last hit lands, every attack is cleared (`MechaGuppyTop.clear`, the bombs) and Mecha Guppy, held from its own stages
  (`MechaGuppyShark.hold`, posed by `pose_free`), sinks out of sight from its watch (`DIVE_SECONDS` 0.45 s, `DIVE_DROP`;
  task E5e-g: so it never jumps across to the ship's side in view), then bursts up out of the sea under the ship, upright and side-on (an eye
  toward the runner, its chin toward the top), its hinge `HINGE_OUT` (4 m) outside the ship's middle and its jaws
  opening `JAW_OPEN` wide round the ship's stern half (`leap_rise` 1.2 s; guppy_leap); they snap shut
  (`GULP_SECONDS`; guppy_gulp, a shudder, a shake): the captain and the stern are gone and the bow half breaks away,
  tumbling down into the sea (`CaptainCogsShip.swallow`, `wreck()`). It hangs (`leap_hang` 0.45 s), leaning out, and
  falls back out of sight beside the top (`leap_fall` 0.9 s, `FALL_DROP`). Then it swims away where the run camera
  sees it (task E5e-c's review: from the top, the deck's edge hides the sea for tens of metres out and the haze the
  rest, so a fin at the waterline was never seen): `_plan_breach` places a breach out at sea ahead, and Mecha Guppy
  bursts out of the water in one long leap heading away, on ahead and out to sea (guppy_leap again; a plume of spray,
  `MechaGuppySplash`), its whole body clear of the sea at the top of its arc (`MechaGuppySharkModel` gave it a tail),
  and dives back in head first with a bigger plume (guppy_swim), `breach_seconds` (2.8 s) from the sea back to it. The
  plan: the arc's top `BREACH_UNDER` (10 m) under the deck but at least `BREACH_LOWEST` (24 m) over the sea, and
  `BREACH_SHOW` (9 m) over the camera's line past the deck's coping (`KERB`; the camera's place from MovementTuning's
  camera numbers and the runner's lane, a lane further away to spare); at least `BREACH_CLEAR` (40 m) out (clear of
  the tower and the falling bow); past the shoreline (`BREACH_SEA`, 14 m) wherever the camera sees the sea's surface
  it breaks (a low top shows it near, a high one only far out); the top of its arc within `BREACH_VIEW` (38°) of the
  camera's forward axis and at least `BREACH_NEAR` (55 m) ahead; pulling away at `BREACH_AHEAD` (14 m/s) and out at
  `BREACH_OUT` (3 m/s), its head along the way it moves as the runner sees it; `breach_seconds` for a leap up to
  `BREACH_REF` (30 m) high, longer for a higher one so it moves the same (up to `BREACH_LONGEST`, 1.6 times: a runner
  who never baits climbs to a top about 73 m up); and from a high top, whose camera sees nothing of the rise out of
  the sea far below, it begins already under way, its snout `BREACH_HIDDEN` (2 m) under the camera's line (reckoned
  for the camera over the outer lane on that side, where it sees lowest), so no time goes by on an empty view.
  Everything keeps pace with the runner.
  No point of its jaws or its body comes over the lanes or the top's eaves at any moment (the suites check every
  frame), nothing in it has a hitbox, and the runner is in the framework's win god mode. `victory_over()` holds the
  results until `dive_after` (0.6 s) after its snout is back in the sea (5.9-6.2 s after the win, 6.6-7.0 s from a
  73 m top; `over_by`; `LevelRun.BOSS_VICTORY_MAX` 20 s); the dive goes on until its tail is under, then it's gone
  (`hold(false)`). LevelRun's riff at the defeat is off (`victory_riff()`), and the zone's level-complete riff plays
  `riff_after` (1 s) after the gulp (`victory_riff_on`).
- **The whole fight** (`test_mecha_guppy_whole`): a runner who baits every step wins in 156.5-164.1 s at the Beach's
  23.8 m/s and 160.5-178.6 s at 18 m/s (3, 5 and 6 lanes: phase 1 over at 41.0-47.2 s, phase 2 at 86.5-100.8 s, the
  top at 98.0-115.7 s, then phase 3's 16 hits, 57-63 s), one who never baits in 223.4-255.3 s (task E5e-g's phase 3
  runs a little longer on a wide top: its floor bites cross more lanes, the ship stands further ahead). Three stars at
  179 s (Hostile Takeover's margin over the slowest clean fight at 23.8 m/s, raised from 177 s by task E5e-g so the
  slowest at 18 m/s, 178.6 s, still earns them), two at 210 s (task E5e-c's review: below the quickest win without
  baiting, so two stars need some baiting and a runner who never baits earns one at every lane count and speed), the
  time bonus to 260 s. Its rewards are its neighbours' (500 credits, 5000 points; DESIGN-TBD).
- **Building it** (`MechaGuppyStairs`): everything up to the build horizon, `BUILD_MARGIN` past the edge of sight
  (`sight`: the arena skin's fog end, 200 m, fully fogged), is built through the boss's props and freed once
  passed; roofs in 24 m pieces, never past where they could still be eaten or notched: a roof whose end isn't planned
  yet is built to `notch_back` short of where the plan's next hut could start at the nearest (`_unknown_limit`: no
  nearer than the edge of sight, nor than `MechaGuppyClimb.next_hut_start`), so new pieces appear past the edge of
  sight (205 m out, measured; task E5e-b3's review found them 168-192 m out, in the haze). Each step
  is planned only as its hut comes to the horizon, in the phase of that moment, and never nearer than the edge of
  sight (`MechaGuppyClimb.plan_next`'s `not_before`); when the phase changes, every step whose hut is still past the
  edge of sight is taken back and planned again (`_replan`, `MechaGuppyClimb.truncate`). Cursors skip finished
  roofs and steps, so the work a frame doesn't grow with the fight (`visited`).
  - Each roof is a `BossProps.roof` over each run of lanes starting together, with a lane blocker on its sides
    below the top: a lane switch into a side bumps, as into a truck's. Its pieces split where its notch begins
    (`_roof_piece`): past there they leave out the notch's lane, with a blocker along the notch's inner side (a
    runner who fell into it bumps against the tower), and the step's pads skip that lane. A floor bite, once eaten
    (`eat_crescent`, at its snap), splits the pieces across it the same way: the roof's boxes before and after it and,
    over it, the floor its edge leaves (`_bitten_floor`) with its blocker; `crescents` counts them.
  - Each roof's front, below where a runner could still step up onto it, is a solid hazard ("tiki bar") that
    the dash doesn't pass: what looks like a hit is a hit. The plan keeps fronts out of every living runner's
    path; only stepping sideways off a reaching tongue into the gap beside it meets one.
  - Each step gets its pad strip (one pad per lane, the strip's length) and its hut (`BossProps.ceiling_lanes`
    at the hut's height, one section per run of lanes ending together).
  - Every frame it sets `Player.floor_base` to the roof of the step the runner is in.
- **The grapple and a revive** (`MechaGuppy._grapple_save`, DESIGN-TBD): both go up onto the higher roof, into
  its nearest lane that leads up; a runner who fell off the side of a roof (into its notch) goes back up onto it, into
  its lane beside the notch. `save_spot` picks the lowest higher roof that covers that lane where the save brings
  them down (`MechaGuppyClimb.save_seconds`). The lift starts above every solid front, so the path is clear. A
  grapple's save shows a warm-white rope for 0.35 s (`MechaGuppyRope`), from the runner, followed as the save lifts
  them, to the roof's edge it caught. Either also tells the pattern the runner fell (no hit that step, below). Near a
  floor bite (task E5e-f): a save coming down just before one that leaves a lane, too near to read it and cross from the
  lane it would bring them down in (`save_crossing`: a reaction, the switches, `dodge_margin`, half a hurtbox and the
  dash's reach; task E5e-f's review), goes into the lane it leaves; a runner who fell into an eaten bite goes up into
  the nearest lane with floor where they come down (`_nearest_covered`), in practice past the gap in their own lane.
- **Hits** (GDD §10, the owner, October 11, 2026: by baiting): each phase's hits are counted
  (`weapons_can_end_phase` off, `weapon_share_cap` 0: weapons do nothing). `register_hit(cause)` lands one while the
  climb's pattern runs (4 end phase 1, 6 phase 2), but not in an intro or in phase 3. Captain Cogs' bombs call it:
  the bait's, locked onto a runner in the notch's lane who switched out before its edge, or the fallback's (below).
- **Mecha Guppy** (`MechaGuppyShark`, its look `MechaGuppySharkModel`; E5e-b2, DESIGN-TBD): a building-sized
  mechanical shark, code-built and flat-shaded on the skin's solid material (riveted steel plates, rows of steel
  teeth, dark red glass lenses for eyes that never glow, nothing on it glowing), its jaws 12 m long (`SCALE` 1.5),
  two meshes on hinges so it opens them. It has no hitbox (it hurts nobody: a fall kills, not the shark) and is
  always shown side-on to the runner, in profile. Its pose (hinge, pitch, yaw, roll, jaw) is eased from one stage to
  the next, so it never pops while seen; a new action starts only once it has sunk out of sight from the last
  (`busy()` until then; a breach may come up from a sink that is already all under the floor). Its actions:
  - **The bite** eats the end of the roof the runner has just left, `bite_length` (14 m, never past the hut's
    start). Its warning is the rumble and the shark surging up beside the roof's end: on the street, upright, its
    chin toward the track and an eye just over the roof's top, as the runner nears the pads (`bite_warning`, 0.6 s
    ahead); on a roof with a notch, into its catch beside the notch (below), as the bait begins. It waits until the
    runner is up on the hut (`may_break`), then dives under the roof's top leaning in with its jaws opening
    (`bite_dive`; from a catch no faster than `DIVE_SPEED` along the track), lunges up with its chin low across the
    roof (`bite_rise`), holds (`bite_hold`) and snaps shut dropping 7 m away with the roof's end (`bite_snap`,
    guppy_bite; it drops first and closes late, so its closing chin never comes up): at the snap
    `MechaGuppyStairs.eat_roof` cuts the roof back, collision and look together (its full-width pieces past the cut
    freed, the one across rebuilt to end there with the eaten edge's look, its pads cut, the plan's `Roof.end` moved),
    and rubble flies. It never eats the floor the runner is on (it waits for the hut) nor the higher roof (only roof
    k). Its jaws keep `BITE_CLEAR` (2.5 m) under a rider hanging from the hut even mid-jump: measured 3.36 m (counting
    the jaws' tip caps, which task E5e-b2's measure missed: its snap's closing chin came to 2.43 m then). On a step
    whose fallback is due, a bite that would keep it busy (`bite_seconds()`, until a breach may come up) past the
    fallback's last moment gives way (`may_bite`, `MechaGuppyPattern._bite_fits`): it sinks off and that roof's end
    stays (only under extreme tunings; never at the defaults).
  - **The catch** (task E5e-b3, the bait): as the bait begins, with its rumble, it comes up beside the roof's notch
    with its jaws wide: its head out beside the track, leaning in `CATCH_LEAN` so its lower jaw lies flat under the
    notch's lane, its tip `CATCH_CLEAR` short of the next lane, the top of its open mouth `CATCH_ABOVE` over where the
    bomb lands (`catch_pose`); no part of its jaws is ever over a lane a runner may use, nor over the notch's lane
    before the notch, at any height (the bites suite checks every frame). The bait's bomb, locked in the notch's lane,
    falls into its mouth as it passes the roof's top: a hit (`hit()` snaps its jaws shut on it, with a shudder). Once
    the bomb is down (`catch_until`), or the runner falls, it shuts its jaws and settles `CATCH_SETTLE` lower to wait
    for its bite.
  - **The floor bite** (task E5e-f; `floor_bite`, `Kind.FLOOR`, `floor_pending`, `floor_snapping`, `abort_floor`,
    `floor_hinge_x`): with its own warning sound (guppy_floor_warn; task E5e-f's review: never the rumble of the
    harmless bite and the breach) it rises (`floor_rise`, 0.5 s) into its watch beside the roof's side on the bitten
    side, upright, its snout towering over the deck and its jaws outside the track; as the runner reaches the bite's
    `lunge_at` it dives
    under the deck (`bite_dive`) and bursts up through it over the crescent (`bite_rise`), leaning in `FLOOR_LEAN` so
    its lower jaw lies flat across the crescent with its teeth through the deck (`FLOOR_SINK`), its tip `FLOOR_CLEAR`
    (0.4 m) short of the deepest the bite goes (no part of its jaws is ever over the lane it leaves; the suite checks
    every frame); it holds (`bite_hold`) until its jaws, shutting, will have shut as the runner reaches `snap_at`, and
    snaps shut (`bite_snap`, guppy_bite) dropping `FLOOR_DROP` (10.5 m) with the chunk: `on_snap` (the pattern's) bites
    it out. It may start only as a breach may (`can_breach`); a phase change sinks it away before its snap
    (`abort_floor`), unless its jaws are already snapping shut (`floor_snapping`): that snap completes, the chunk going
    as warned (task E5e-f's review).
  - **The breach** is the fallback's (below): it glides deep under the middle of the chasm in front of the higher roof,
    out of sight (`lurk`: nothing of it shows, task E5e-b2's review), and when Captain Cogs throws there it surges up
    beside the lanes that don't lead up, its head `lane_clear` (1.5 m) clear of the lanes that do, its jaws opening
    outward `breach_early` (0.25 s) before the bomb lands, held `breach_hold`. Hit, it shudders and recoils, snapping
    shut and sinking at once (gone below the floor before the camera passes); on a step the runner fell it shuts at
    once. It may start only while it's free (`can_breach`: idle, lurking, or sinking already all under the floor).
- **Captain Cogs** (`CaptainCogsShip`, `CaptainCogsModel`, `CaptainCogsSuit`; DESIGN-TBD; no pronoun: the owner hasn't
  given one): a burly pirate on the humanoid rig, 2.4 m tall (a teal frock coat, a tricorn with a brass cog badge, a
  braided beard, an eyepatch, a clockwork brass arm and a monocle-eye glowing the skin's `neon_blue`; nothing red), on
  the stern castle of a flying galleon (dark planks with brass bands, gun ports and cannons, a mast with a patched sail
  bearing a skull with cog teeth and a flag, a neon violet trim, hover pods glowing the Beach's engine colour, brass
  cog wheels turning on its flanks). The ship keeps `ship_ahead` (40 m) ahead of the runner and `ship_height` (16.5 m)
  over the floor base, eased as they climb, swaying and bobbing; each bomb leaves the captain's hand as the arm whips
  over (`throw()`, `hand_world()`). It has no collision (never on the hull layer, so no pad flips a runner up to it).
- **The bombs** (`MechaGuppyBombs`; DESIGN-TBD): warned as the Floating Head's are, in a pirate look (a round black
  iron bomb with a brass band and a lit fuse whose spark is steady with Reduced flashing). A bomb's red target circle
  shows from the throw where it lands, at that floor's height (`BossProps.circle_warning`'s height, the same red at any
  distance, out of the fog), the throw is heard (cogs_throw) and it whistles down (bomb_whistle, timed to end as it
  lands), lock_seconds (1.1 s) from the throw. On a roof it bursts: a blast too tall to jump for `blast_seconds`, an
  enemy attack's hitbox smaller than its fireball (armor and the shield block it, the dash passes; real contact only).
  On a hut it would burst on the hut's top, never touching the rider under it (GDD §10), with no circle (where it
  lands decides); the pattern throws none there. With no floor under it, a bomb falls on into the chasm, unless Mecha
  Guppy's open jaws are in its way: checked all along its fall (`MechaGuppyShark.mouth_contains`), it goes into them:
  a hit, never on a step the runner fell (`MechaGuppyPattern.catch_ok`). A bomb with nothing to dodge (the fallback's:
  `Kind.HIT`) shows its circle but isn't heard thrown and doesn't whistle. The spots a runner must dodge follow the
  Floating Head's salvo rules (`plan_spots`, `way_through`, `dodge_lane`): every spot leaves a lane to be in, reached
  from where the runner can first switch (`s_open`) over floor under every lane crossed (never off a pier's side into
  the chasm, never on a hut), with `dodge_reaction` and every switch plus `dodge_margin` to spare; never under or near
  a hut (`floor_clear`, `hut_clear`); never on a pickup.
  - **The bait** (`start_bait`, `lock_bait`, `bait`, `seek_ring`): Captain Cogs takes aim (cogs_aim, as long as
    `bait_seek`, 0.6 s) and the bomb's aim follows the runner's lane where it will land (sliding a lane in about a lane
    switch): a reticle (`_aim_node`), a ring `AIM_SCALE` (1.25) of a bomb circle's size with four ticks across it in
    the circles' red, standing on the floor and leaning back `AIM_LIFT` (45°) from it with its face toward the runner,
    so it reads 40 m out (task E5e-b3's review: the flat ring it was showed there as a sliver a few pixels high);
    steady, unlike the locked circle's pulse (nothing flickers with Reduced flashing either). At the lock it gives way
    to the bomb's own flat, pulsing circle and the bomb is thrown at that lane (`Kind.BAIT`, the throw heard,
    lock_seconds before it lands as they get there). On a roof's top it's a spot of one bomb (a volley: the way through
    sees it); in the notch's lane it falls past the edge.
- **Each step's pattern** (`MechaGuppyPattern`; DESIGN-TBD), the same on every step (no escalation):
  - **the floor bite** of roof k + 1 (task E5e-f; `_floor_bite`, every step, attacks live or not): as the runner reaches
    its `warn_at`, Mecha Guppy rises for it with its own warning sound (`MechaGuppyShark.floor_bite`) and its warning
    shows (`MechaGuppyFloorBite.start`: the crescent's outline on the floor in the enemy attacks' red, the Golden
    Convergence's Fist Slam look, a glowing frame round a solid red fill, the frame deepening as the snap comes (its
    band built once, deepened and beaten by `mecha_guppy_floor_warning.gdshader`'s width: task E5e-f's review), its beat
    steady with Reduced flashing, unfogged; a floor warning on every lane it takes, so pickups keep off it; the jaws'
    hitboxes placed, off). At the snap (`on_snap` → `MechaGuppyFloorBite.snap`) the chunk goes
    (`MechaGuppyStairs.eat_crescent`, the collision and the look together), rubble flies, a shake; for `SNAP_SECONDS`
    (0.15 s) the jaws' hitboxes are live over the crescent (`SNAP_INSET` in from its edge, from under the floor to over
    a jump's reach), an enemy attack: a runner in its area as it snaps (only one put there: the snap comes before the
    runner gets there) dies of "Mecha Guppy's bite", or, blocked by armor or the shield or dashing through, has the
    floor under them held for `GameRules.cut_hold_seconds` (1 s; FloorCut's rule, drawn by
    `MechaGuppyLooks.held_floor`). A bite it's too late to warn fairly (the attacks off, the shark too busy:
    `MechaGuppyClimb.bite_latest`) is skipped, as if never planned; one warned when the attacks stop is called off
    (`call_off`; at a phase change, unless its jaws are already snapping shut). Roof k's catch and bite come only after
    its floor bite;
  - the bite of roof k, as above (an intro too: the level being eaten isn't an attack);
  - the volley on roof k + 1 (`volley`; none on a roof with a floor bite, `_volley_places`: the first comes on roof 3,
    after the first bait): phase 1 a spot on its run (`roof_spots`); phase 2, after a RUN_ON step, the landing spot
    where riders come down (`landing_spots`, dodged in the air off the hut's end; a REACH_BACK step's riders drop at the
    deadline itself, before which no circle may show, so they get none) and then the roof's spot, as one volley, its
    spots taking more bombs side by side (`spot_bombs`). Thrown as the runner nears its first spot, never before the
    hut's deadline (no circle ever tells a rider which lanes lead up: only the owner's two cues do), and a roof's spot
    never before the runner can switch lanes there (`Step.free_at`; task E5e-b2's review: a circle in the lane of a
    runner on a narrow pier, nowhere to switch but the chasm, was a trap); its last spot passed `bait_after` (a reaction
    and a switch for every lane but one) before the bait locks, and before the notch with `lock_to_edge()` to leave its
    lane (a dodge may have taken the runner there);
  - **the bait** (`bait_plan`, `_bait`): at roof k + 1's end, with the shark in its catch beside the notch, the aim
    follows the runner from `seek_at` and locks at `lock_at`; it lands `catch_in` (4 m) into the notch (on floor in
    every other lane, clear of the next hut). An extreme tuning that breaks its promises gets no bait that step (counted
    toward the fallback; task E5e-b3's review): its aim shows only once the runner can switch lanes on that roof and has
    had a reaction (`seek_at` past `Step.free_at` and the hut's deadline plus `dodge_reaction`), and a runner in the
    notch's lane as it locks has `lock_to_edge()` (a reaction, a lane switch and `dodge_margin`) to leave it before its
    edge; on a roof with a floor bite its aim shows only once the runner is past the bite, and it locks `bait_after`
    later (the crossing from the lane the bite leaves to the notch's). Once it follows, it goes stale only `STALE` past
    where it should have locked (a long `bait_seek` used to cancel it mid-follow). A step already hit (its fallback came
    first) gets none: a hit at most one a step, and an aim that follows the runner is always a chance at one;
  - **the fallback** (`_fallback`, `hit_spot`; GDD §10: "Captain Cogs sometimes misses into the chasm anyway"): once
    `fallback_after` (1; task E5e-b3's review: 2 dragged a fight with no checkpoint out to about 5 minutes) steps in a
    row have gone by without a hit (`dry`, counted as each step closes after its bait was offered, or with none to
    offer: under an extreme tuning a roof from `FIRST_NOTCH` on may have no room for one, and the hits never stall),
    from the next hut's deadline, with the rider in a lane that leads up and not fallen that step, Captain Cogs throws
    at the chasm in front of roof k + 1, beside the lanes that lead up on the side with more lanes that don't
    (`hit_back`, 6.8 m, before that roof's front; `fallback_flight()`: `hit_seconds`, 0.65 s, or longer where Mecha
    Guppy needs longer to surge up and open, `breach_rise`), and Mecha Guppy breaches there: a hit. It's thrown only
    once the shark can rise for it (`MechaGuppyShark.can_breach`), waiting while its bomb can still come down before
    the runner draws level with it (`fallback_last`); past that it waits for the next step. Never a hit on a step the
    runner fell, even if the grapple saved them (`note_fall`, `catch_ok`). One due on a step that leads onto a roof with
    a floor bite waits for the next step (`bitten_next`, logged `fallback_deferred`: the shark can't breach in front of
    that roof and rise for its bite too); at `fallback_after` 1 they never fall on those steps anyway.
  A runner who baits every step lands one hit a step from the first notch on: phase 1 ends at 41.0-47.2 s and phase 2 at
  86.5-100.8 s (3, 5, 6 lanes at 18 and 23.8 m/s); one who never baits lands one every other step: 67.4-78.5 s and
  158.5-185.7 s (1.6 and 1.8 times as long). Phase 2 has more bombs to dodge (the ones that can reach the runner, the
  bait's included, counted over the steps that threw any): 2.50-3.17 a step and 0.317-0.366 a second against phase 1's
  1.50-2.00 and 0.142-0.180 (fewer since the roofs with a floor bite have no volley). `attacks_enabled` (tests) turns the
  bombs and the bites off; `hits_enabled` (tests) keeps the hits from landing (no catch, no fallback).
- **The armor rule's pickup** (the standard 15-17 s, `armor_when_unprotected` like every boss) goes on the roof
  the runner will run along, at its height (`_on_armor_pickup_due`, `MechaGuppyStairs.pickup_spot`,
  `PickupField.place`): past where a rider lands, short of the next hut and clear of the bait (before the notch), in
  their lane or the lane they'll land in, off any boss warning, never where a floor bite will take the lane, and in a
  lane a floor bite takes far enough short of its gap that a runner who grabs it (`PICKUP_REACH` either side) still has
  every switch to the lane it leaves (none over a full-width one: its jump), `dodge_margin` and the dash's reach (one
  who dashes as they grab it still clears the bite), or past it (`clear_of_bite`; task E5e-f's review: one just short
  of the gap asked for a grab and an escape that couldn't both happen).

In `scripts/bosses/mecha_guppy/`:

| File | What |
|---|---|
| `mecha_guppy.gd` (`MechaGuppy`) | the encounter: the arena (`_plan_lap`: nothing of the generator's, a gap in every lane from `EATEN_BEHIND` behind each lap, a wall gap on both sides over every lap), the climb, the stairs, the backdrop, the climbing view, the shark, the ship, the bombs, the floor bite (`floor_bite`), the pattern and phase 3 (`_build_boss`; `_advance` drives the last six every physics step), phase 3 (`top_due`, `on_top`, `top_reached`, `top_reached_at`, `top`; its hits counted by `register_hit` once the runner is on the top), the defeat (`leap`, `_on_defeated`, `_defeated_tick`, `victory_over`, `victory_riff`), `register_hit` (it tells the pattern), `attacks_live` / `bites_live` (`attacks_enabled` for tests), `sound` (played and logged), the armor pickups (`_place_armor`, `armor_pickups_waiting`), the grapple's save and its rope (`_grapple_save`, which tells the pattern of the fall); a phase change calls off a bait still following and a floor bite whose jaws aren't yet snapping shut (one already snapping completes; the win calls off any); `run_pace` |
| `mecha_guppy_climb.gd` (`MechaGuppyClimb`) | the plan: `Roof` (top, lane starts, eaten end, notch, floor bite; `covers`, `keeps`, `end_in`, `full_from`, `notched`, `notch_side`) and `Step` (pads, hut, lane ends, the lanes that lead up, cue, settle, deadline, landing, `free_at`; `nearest_up`, `switches_from`); `make`, `plan_next` (with `not_before`), `next_hut_start`, `roof_run_seconds`, `notch_after` (and `FIRST_NOTCH`), the floor bite (`bitten`, `FIRST_BITE`, `bite_crossing`, `bite_chain`, `bite_length`, `snap_lead`, `bite_warning_seconds`, `bite_latest`, `_plan_bite`, `_bite_front`, `_bite_full`, `_bite_side`, `_bite_room`; `LAND_CLEAR`, `SNAP_CLEAR`, `WARN_SLACK`), `plan_until`, `truncate`, `top_planned`, `step_at` / `step_index_at` / `roof_index_at` (binary searches), `roofs_at`, `floor_at`, `hut_at`, `margin`, `wrong_reach`, `climb_rate`; the motions frame by frame (`jump_seconds`, `flip_seconds`, `drop_seconds`, `save_seconds`) |
| `mecha_guppy_crescent.gd` (`MechaGuppyCrescent`) | a floor bite as planned (pure numbers): its roof, side, front and end, the lane it leaves (`keep`) or `full`, its edge (`ds`, `ws`, `edge()`, scalloped by `TEETH`), its moments (`warn_at`, `snap_at`) and state (`warned`, `eaten`, `skipped`); questions: `depth_at`, `in_gap`, `w_of` / `x_of`, `takes` / `taken_at` / `left` (against a runner's footprint: `near_w`, `far_w`), `min_depth`, `deepest`, `stretch`, `lane_stretch`, `lane_drop` (the gap reaching a point only past `EDGE_EPS`: its edge points are single precision) |
| `mecha_guppy_floor_bite.gd` (`MechaGuppyFloorBite`), `mecha_guppy_floor_warning.gdshader` | the floor bite in the fight: `start` (its warning: the outline, its frame a band built once with each inner vertex's inward offset in UV, deepened and beaten by the shader's `width`, and the fill, the floor warnings, the jaws' hitboxes placed), `snap` (the chunk gone, the hitboxes live for `SNAP_SECONDS`, a runner caught meeting the damage rules, the floor held under one who lives through it: `holding`, `held`), `call_off`, `clear`, `tick`; `warning`, `hazards`, `frame_width` and its counts (`warnings`, `snaps`, `called_off`, `caught`) for tests; `BITE_NAME` |
| `mecha_guppy_stairs.gd` (`MechaGuppyStairs`) | builds the plan up to the edge of sight and a margin: each roof's front pieces (the reaching lanes' box, side blocker and solid fronts), its full-width part in pieces (split at its notch: `_roof_piece`, the notch's blocker), pad strips (none in a notch), huts; a roof whose end isn't planned yet only as far as its notch could start (`_unknown_limit`); plans each step as late as it can, never in sight, and re-plans the unseen ones when the phase changes (`_replan`); the floor base every frame; `eat_roof` (a bite: the roof cut back, collision and look together, its pads too; `eaten`); `eat_crescent` (a floor bite: the pieces across it rebuilt round its gap, `_bitten_floor`; `crescents`); questions: `runs`, `span`, `horizon`, `save_spot` (`save_crossing`), `roof_front`, `pickup_spot` (`clear_of_bite`, `PICKUP_REACH`), `roof_reach` |
| `mecha_guppy_shark.gd` (`MechaGuppyShark`) | Mecha Guppy: `hold` / `pose_free` / `head_transform` / `shudder` (the leap poses it, its stages held), `body_points` (tests), `bite` (with a catch first: `catch_pose`, `catch_until`; giving way to a fallback due: `may_bite`, `bite_seconds`), `lurk`, `breach` (`can_breach`), `floor_bite` (`floor_pending`, `floor_snapping`, `abort_floor`, `floor_hinge_x`) (its stages: `LURKING`, `RISING`, `CATCHING`, `SHUTTING`, `WAITING`, `DIVING`, `BREAKING`, `OPEN`, `SNAPPING`, `SINKING`, the pose eased between), `mouth_contains`, `hit` (the clang, fireball, sparks, smoke, shudder; a breach recoils, a catch snaps shut), `jaws_points` / `jaws_over` (tests: where its jaws reach), `on_snap` (the pattern eats the roof); counts for tests (`bites`, `catches`, `breaches`, `floors`, `hits`, `skipped`, `yielded`) |
| `mecha_guppy_shark_model.gd` (`MechaGuppySharkModel`) | its meshes, built once per skin: `upper_jaw` (the snout, back of the head, eyes, palate and teeth), `lower_jaw` (the chin, belly plating, the mouth's floor and teeth), `body` (the throat, gills, the body down into the chasm, fins, and its tail: the stalk and the crescent fin, seen in the defeat's breach); `jaw_size`, `TIP_CAP`, `TAIL_STALK`, `TAIL_FIN` |
| `captain_cogs_ship.gd` (`CaptainCogsShip`), `captain_cogs_model.gd` (`CaptainCogsModel`), `captain_cogs_suit.gd` (`CaptainCogsSuit`) | the ship's station and motion (`advance`; phase 3's station alongside the top: `come_level`, `is_level`, `level_x`, `level_lead`; the captain's swivel gun: `swivel_world`, `fire_swivel`; the broadside: `cannon_world`, `fire`, its flash, smoke and recoil; the gulp: `swallow`, the bow half breaking away as a wreck, `wreck`), the captain's stance and throw (`throw`, `hand_world`, `throws`); the ship's meshes (`meshes`: its bow and stern halves, split at `SPLIT_Z`, and the wheel; the swivel guns on the stern castle's rails; `cannon_at`, `swivel_at`, `half_beam`); the captain's parts on the humanoid rig (`parts(lens)`: the lens in the skin's `neon_blue`) |
| `mecha_guppy_bombs.gd` (`MechaGuppyBombs`) | the bombs: `throw_spots` (a volley), `throw_at` (one bomb: the fallback's, a test's), the bait (`start_bait`, `lock_bait`, `drop_bait`, `seeking`, `seek_ring`, `bait`; its aim, `_aim_node`), their circles, flight, whistle and landing (`surface_at`: a roof's top, a hut's top or the chasm; into the shark's jaws all along a fall: `_into_jaws`), the blasts (pooled hazards, `blast_hazards`), `plan_spots` / `way_through` / `dodge_lane` / `spots_ahead` (the Floating Head's salvo rules on the climb's roofs), `spot_floor`, `open_lanes`; `drops`, `stats` (tests); `bomb_mesh` |
| `mecha_guppy_top.gd` (`MechaGuppyTop`) | phase 3 (task E5e-g): `begin` (the ship coming level, Mecha Guppy's watch, the first barrage), `tick` (its acts, `Act`: `RISE`, `BARRAGE` with `_barrage_tick`, `DIVE`, `SPLASH` with the plume and the wave, `WAVE`, `BITE` with `_floor_bite`, `RETURN`), `bomb_landed` (a hit), `started`, `elapsed`, `clear`; `words` (the barrage script's words; pure, for the suites); `beats`, `hits`, `interludes` (tests) |
| `mecha_guppy_barrage.gd` (`MechaGuppyBarrage`) | Captain Cogs' bombs across the top (task E5e-g): `fire` (the red line at the bomb's height and the charge; then the shot from the swivel gun and the flight: `State` `WARN`, `FLY`, `DONE`), `path` and `point_at` (its curve onto the line, across the deck, its curve into the shark; pure), `hit_size`, `hit_band`, `meet_seconds`, `incoming` (the bot), `bomb_hazards` (pooled hitboxes), `on_landed`, `clear`; a bomb that met the runner bursts (`burst`) |
| `mecha_guppy_waves.gd` (`MechaGuppyWaves`), `mecha_guppy_wave.gdshader` | the waves: `start` (the swell and the roar; then the crash and the surge: `State` `SWELL`, `ROLL`, `DONE`), `timing`, `band_hazards`, `surges`, `swelling`, `surge_d`, `crest_above`, `clear`; `swell_mesh`; the water's shader (unshaded: deep to shallow, the foam, the red line low on the surge's face, the streaks standing still with Reduced flashing) |
| `mecha_guppy_leap.gd` (`MechaGuppyLeap`) | the defeat: `start`, `tick` (`Step` `RISE`, `HANG`, `FALL`, `BREACH`, `GONE`), `_plan_breach` (`breach`), `over`, `seconds_to_over` / `over_by`, `snout` / `tail`, `marks` (tests), the plumes, the riff after the gulp |
| `mecha_guppy_splash.gd` (`MechaGuppySplash`) | a plume of spray where Mecha Guppy breaks the sea in the defeat: jets of sea water turning to white spray over a ring of foam, up, held, falling back and spreading (`play`, `advance`, `standing`; `plume_mesh`, lit so it shows against the haze) |
| `mecha_guppy_pattern.gd` (`MechaGuppyPattern`) | each step's floor bite (`_floor_bite`), bite (with its catch), volley, bait, lurk and fallback, timed by where the runner is (`tick`); `volley` (a step's spots as they'd be thrown from a lane: the pattern and the tests), `volley_lock`, `bait_plan`, `bait_after`, `lock_to_edge`, `hit_spot`, `fallback_due`, `bitten_next`, `fallback_last`, `fallback_flight`, `on_snap` (a floor bite's snap to `MechaGuppyFloorBite.snap`, a bite's to `eat_roof`); the hits and falls (`note_hit`, `note_fall`, `catch_ok`, `fell_on`, `hit_on`, `dry`); `hits_enabled` (tests) |
| `mecha_guppy_looks.gd` (`MechaGuppyLooks`) | the look on the Beach's skin, one merged mesh per piece: each roof a boardwalk deck (its lanes' plank strips, orange lips and coping on every edge over a drop, the gap-edge language) with thatch eaves and lantern posts outside the lanes, on a tower down to the water (`roof_front`, `roof_segment`; drawn no deeper than `TOWER_DEPTH`, 300 m, under its deck, past the haze, so a long climb's meshes stop growing): storey after storey with a ledge and framed, warmly lit windows, darker the deeper (`deep`); the notch (its lane's deck ending with the eaten edge's orange, the eaten face along its inner side and across its start, the orange lip along the deck's edge over it, no eave or lantern posts past it: `notch_inner`); the reaching lanes on a pier (a lantern-lit fascia, the orange lip at its front and open sides, posts and braces on stilts down to the water); a floor bite once eaten (the deck clipped along its scalloped edge, `_deck_bitten`, `_clip_floor`, `_floor_poly`; the orange lip and coping along the edge, its glowing strip and the broken face down to the water fading into the sea haze the deeper it goes, `_bite_edge`, `_bite_deep`; the tower's side, eave and lanterns left out along it, `_without`) and the floor held over one under a runner who blocked its snap (`held_floor`); a neon sign on some fronts; the street's own sand; each hut a hovering plank platform (its underside lit on the lane seams and along each run's shared edges with joists, the orange end where each run of lanes ends: up close an orange lip with a row of lamps, hung `SHADOW_UNDER` below the underside so a rider's blob shadow never darkens it, its 4 m band from afar a glow card fading out within `END_BAND_NEAR` of the camera, task E5e-f's review, lift pods in the skin's engine colour) carrying a row of tiki huts and rails, a walkway annex over RUN_ON's running-on lanes, a sign on some; the pad strips' tiles. Its signs glow only the Beach's violet, blue or warm white |
| `mecha_guppy_skin.gd` (`MechaGuppySkin`), `data/bosses/beach_boss_skin.tres` | the arena's skin, a `BeachSkin`: the open shore on both sides (`BeachOpen.shore_side`, no shacks or gap marks: there are no walls), the water under the eaten street (the chasms' floor), no ceiling or hull looks (the huts are the looks'); its data makes the arena hazier, fully fogged past 200 m (fog 24-200 m, `fog_max` 1) |
| `mecha_guppy_bite_water.gd` (`MechaGuppyBiteWater`) | the sea at the bottom of the holes Mecha Guppy bites out of phase 3's top (task J3): `setup` (the pool of `SHEETS` quads in the sea look of the water beside the top, built once), `update` (from each top bite's snap, `holes`: its sheet just under `MechaGuppyTop.water_y`, over its crescent and `ENDS` past it either way, and out through its bitten side under the water beside the top). Look only |
| `mecha_guppy_waterfall.gd` (`MechaGuppyWaterfall`), `mecha_guppy_waterfall.gdshader`, `mecha_guppy_sea.gdshader`, `mecha_guppy_clouds.gdshader` | the backdrop: the waterfall, a flat-topped massif `DISTANCE` (420 m) ahead of the camera whose rock, lip (`LIP_Y`, 150 m) and mist are drawn at world heights (the cliffs slide down past a climber, its foot sinks below; past the lip a plateau card shows its top), its flanks sloping to the sea so the horizon shows beside it (fades out with `set_shown` at the top, its clouds with it); a sea plane at sea level around the camera out to the far plane, the sky below the horizon set to the fog's colour (`abyss_color`) so the far sea meets the horizon at any height; layers of low cloud at fixed world heights beside the climb, shown once the runner is above them. Unshaded, nothing flickering |
| `mecha_guppy_rope.gd` (`MechaGuppyRope`) | the grapple's rope: from the runner (followed frame by frame as the save lifts them) to the roof's edge, for a moment; `ends()` for tests |
| `mecha_guppy_tuning.gd`, `data/bosses/beach_boss_tuning.tres` | its numbers (F6 in its fight; all DESIGN-TBD, `docs/OPEN_QUESTIONS.md` items 767–824): the climb's (`rise`, `phase2_rise`, `roof_seconds`, ...), "Captain Cogs' bombs" (with the fairness numbers `floor_clear`, `hut_clear`, `escape_after`), "The hits" (`bait_seek`, `notch_back`, `catch_in`, `fallback_after`, `hit_back`, `hit_seconds`, `lane_clear`, `breach_early`, `lurk_seconds`), "Mecha Guppy's bites" (with `bite_spare`), "Mecha Guppy's floor bite" (`floor_warning`, `floor_rise`, `floor_bite_length`, `full_every`, `full_jump_share`, `full_through`, `floor_snap_lead`), "Captain Cogs' ship", "Phase 3" (`level_*`, `guppy_ahead`, `guppy_rise`, `top_first`, `barrage_script`, `bomb_gap`, `barrage_rest`, `beat_spare`, `bomb_*`, `low_height`, `high_height`, `dive_every`, `surface_after`, `bite_after`, `wave_*`), "The defeat" (`leap_rise`, `leap_hang`, `leap_fall`, `breach_seconds`, `dive_after`, `victory_riff_on`, `riff_after`); `per_phase`, `rise_at`, `TOP_TUNABLES` |
| `data/bosses/beach_boss.tres` | its slot: `scene`, the owner's title, three phases (4 hits, 6 hits, and 16 on the top), weapons capped at nothing and unable to end a phase, one lap of arena (the Beach's skin, no features, a clear start), the standard armor rule with `armor_when_unprotected`, the Beach's music, par times measured on the whole fight (179 s, 210 s; the time bonus to 260 s), its neighbours' rewards (500 credits, 5000 points) |

Also: `scenes/bosses/mecha_guppy.tscn`; `tools/showcase/mecha_guppy_showcase.tscn` (scripted runs for reviews:
`--scenario=climb/wrong/grapple/side/hut/top/level/leap/leapcam/shark/ship/bombs/bait/hits`, `--lanes`, `--speed` (23.8
by default), `--phase`, `--daylight`, `--reduced-flashing`, `--events`, `--no-attacks`, `--no-bait`, `--start=S` (the
runner moved on to step S's roof first: a view from higher up; with `hut`, under step S's hut), `--hits=N` (phase 3's
hits cut to N), `--stand` (phase 3's runner neither jumps nor slides), `--god`); `tests/helpers/mecha_guppy_bot.gd`
(`MechaGuppyBot`: presses only
the named actions and reads the lanes that lead up off the hut and the roofs by physics rays, never the plan
(`read_up_lanes`); `reaction` seconds after settling it switches a lane at a time to the nearest one, or, with
`wrong`, to one that doesn't; `worst_case` first takes the lane farthest from them that has pads and jumps on the
last frame before the pads (its hurtbox's front short of them), `dash_flip` dashing as it jumps; `wrong_at`,
`wrong_far`, `dash_drop` for the wrong drops; on a roof, or in the air over one, it follows a way through the circles
of Captain Cogs' spots still ahead (`MechaGuppyBombs.dodge_lane`), `dodge_reaction` (the planner's own) after they
show, switching only where the roof is under every lane it crosses (`dodges`, `dodge_moves`); with `baits` it lures
the bait into the notch's lane once its roof's volley is behind it and switches out `dodge_reaction` after the lock
(`baited`; never on a step already hit, `MechaGuppyPattern.hit_on`), without it keeps out of the notch's lane while a
bait can lock there; it never runs off a lane that ends
ahead (`stay_in_notch_at` for the fall test); Mecha Guppy's floor bite (task E5e-f) it reads off its warning
`dodge_reaction` after it first sees it from the roof's floor or in the air over it (with `bite_seen_from_free`, only
from where it can first switch lanes there, `Step.free_at`: the plan's reckoning of when it can be read): into the lane
it leaves, a lane at a time where the floor is under the lane it moves into, or over a full-width one a jump centred on
the stretch where the gap reaches into its lane, its bait and its worst case waiting until it's past the bite
(`bite_slack` and `jump_margin`, the least it had to spare, `bites`; `floor_bites` off runs on into the gap, for the
fall's test); on phase 3's top
(`top_dodges`) it reads each round's red lines and each wave's swell `dodge_reaction` late, switching to the nearest
lane the lines leave clear and jumping each surge `JUMP_LEAD` before it reaches it (`top_switches`, `top_jumps`);
`min_slack`, measured at its last switch's press, `steps_climbed`, `reads`, `dashes`; `circle_trap` (the pier trap: a
circle, or the bait's aim, in the runner's lane with no floor beside them) and `census` (phase 1's and phase 2's bombs
to dodge, a step that threw any and a second) for the suites). Sounds
(`tools/asset_gen/sfx_bank_mecha_guppy.gd`): cogs_throw, cogs_aim (the bait's aim, as long as `bait_seek`),
guppy_rumble (a bite's, a catch's and a breach's warning), guppy_floor_warn (a floor bite's own warning: knocks under
the deck, timbers groaning, teeth screeching up through the wood), guppy_bite (a bite's snap and a floor bite's),
guppy_clang; phase 3's guppy_roar (a bomb hits it), cogs_charge (a bomb's warning, as long as `bomb_warning`), cogs_cannon (its shot), guppy_leap (the
splash), wave_swell (as long as `wave_warning`) and wave_crash, and the defeat's guppy_leap (the rise, and again the breach), guppy_gulp and guppy_swim (the dive); the
bombs keep the Floating Head's bomb_whistle and bomb_blast. Hints: `enemy:beach_boss` (the climb in short, weapons doing
nothing), `boss:beach_boss/climb` (how to read the lanes that lead up), `/floor_bite` (the red crescent and the knocking
under the deck: switch into the lane it leaves; in phase 2 jump a gap across every lane), `/bombs` (the circles, the
whistle) and `/hits` (the bait: lead Captain Cogs' red target into the notch's lane, switch out before the edge; Captain
Cogs only sometimes misses for you; 4 and 6 hits), `/barrage` (the red line at the bomb's height: jump a low one, slide under a
high one; each one dodged flies into Mecha Guppy) and `/waves` (the dive, the splash, the swell and the roar: jump the
surge; then the bite). Suites: `test_mecha_guppy`
(the data, the plan and its notches, the built climb, the
hits' counting), `test_mecha_guppy_climb` (the climb on physics, the full fight with the baiting bot at every lane count
and speed with phase 2's census and the pier-trap check, the worst case, wrong drops, the camera over phase 1's steps
and phase 2's), `test_mecha_guppy_bombs` (the bombs, what counts as a hit, the census, no volley on a roof with a floor
bite), `test_mecha_guppy_bites` (the bites, the catch's reach, the breaches; the floor bite's own warning sound and
crunch counted), `test_mecha_guppy_bait` (the bait's aim and catch, a runner who never baits winning by the fallback at
every lane count and speed against one who baits, a hit at most one a step, no hit from a fall, a fallback due before a
roof with a floor bite coming a step later, the notch's side, no stall with no room for a notch but on the roofs with a
floor bite), `test_mecha_guppy_floor_bite` (task
E5e-f, at 3, 5 and 6 lanes, both speeds, both phases: the plan's promises, `MechaGuppyBiteChecks`, over many steps;
the same bites whichever lanes lead up and on a retry, alike early and late; collision against the drawn deck on a
ray grid, one lane under a whole footprint at the deepest; the warning in the fight (the red outline and fill,
unfogged, the floor warnings, its own warning sound and the snout beside the roof, its jaws never over the lane it
leaves, the crunch, never before the hut's deadline, steady with Reduced flashing); the worst case on real movement
(moved into the farthest lane where it can first switch, reading the warning from the floor, from there, and dashing as
it starts across: `dodge_margin` and the slack to spare from when it can be read; a full-width jump clearing it at both
ends); the snap's real contact (unprotected, armor, the shield, the dash, beside it); a phase change with the jaws open
(called off) and snapping shut (completing); a fall saved by the grapple and a revive; no pickup asking for a grab and an
escape that can't both happen, nor one dashing as it's grabbed, on real movement; a retry the same), `test_mecha_guppy_tunables` (every tunable at both ends of
its range, at 3 lanes and 23.8 m/s and at 6 lanes and 18 m/s: a runner who never baits lives, never meets a circle with
no floor to switch to, every bait keeps its timings, every fallback is eaten, the hits keep coming, and every floor bite
met is warned in time, leaves its lane and sits clear of the bait, with no volley on its roof; on the plan at 3, 5 and 6
lanes, both speeds and both phases, every floor bite's promises (`MechaGuppyBiteChecks`); phase 3's
and the defeat's tunables are left to `test_mecha_guppy_top`), `test_mecha_guppy_top` (phase 3, task E5e-g: the bombs' bands
and warning at the defaults and at both ends of every phase 3 tunable's range; live at 3, 5 and 6 lanes and 18 and 23.8
m/s: the ship's sail and the captain on the run camera's left and Mecha Guppy's head on its right, every bomb warned (its
line at its height, the charge) and dodged (jumped or slid under), one at a time, each into the shark a hit's share of
the bar, 16 winning; the dives, splashes (where the swell rises, its crest over the deck by `CREST_BY`), waves and floor
bites in order; nothing of the shark over the lanes but its floor bite's jaws; real contact (low: stay, jump, slide,
armor, the shield, the dash; high: stay, slide, jump, armor; the waves); a retry the same; attacks held then the
barrage's spacing kept; the defeat: the gulp, the breach and the
dive seen by the run camera over the deck's edge and past the shoreline, nothing of the jaws or the body over the lanes
or the eaves, no live hazard, the sounds and the riff, `victory_over`), `test_mecha_guppy_bite_water` (task J3, the sea
at the bottom of the top's bite holes: phases 1 and 2 through their bites, phase 2's full-width floor bite too, never
showing any; phase 3 at 3 and 6 lanes, the bot playing it: none before the top nor under a bite before its snap; from
each snap until the runner is past it (one leaving a lane, then one across every lane), a sheet showing just under the
water beside the top, under every point of the gap and out through the bitten side (both sides for a full-width one)
under that water, no floor down to it, seen by a real `RunCamera` (in its frustum, nothing solid in the way); no
collision in it; the runner untouched), `test_mecha_guppy_whole` (the whole fight,
baiting and not, at every lane count and speed, each phase's end time printed, the swim away seen from the top's real
height; the par times (two stars needing some baiting, one star for never baiting at every lane count and speed); the
campaign: the step after Beach 3 at 23.8 m/s under the sunset, a death and the retry playing the same (its floor bites
too), the win's results after the swim and `COMPLETE_PAUSE`, its stars on the level select's tile).
`tests/helpers/mecha_guppy_bite_checks.gd` (`MechaGuppyBiteChecks`): the floor bite's promises on a plan
(`plan_problem`, `shape_problem`), shared by the floor bite's suite and the tunables sweep.
