# The Golden Convergence (E5d): questions for the owner

The owner designed the fight with Claude on October 9, 2026, then asked Claude to fill in the rest and
build it while they were away ("You have leeway to make decisions on how the rest of this boss battle
should go ... If there are any thing that seem like it really needs my input, please save those
questions"). Every choice Claude made is marked *(proposed)* in GDD §10 (The Golden Convergence) and
listed here with where its placeholder lives. The build tasks add their own questions below, under their
step.

## Design choices made under the owner's mandate

1. **The arena: the Grand Court** (GDD §10, The arena). A golden causeway through the palace's vast
   central hall, balustrades at the edges, reflecting pools below, towers to either side with giant feed
   screens. A plain track: no holes, fences, ceilings, doodads or enemies of its own. Is this the place
   you pictured for the fight?
2. **Stage 2 keeps the open causeway** (no side walls). The reason: with permanent walls, the wall hop
   (GDD §3) would let a runner wait out every attack on a wall. The Magnate's "walls and ceilings" are the
   balustrades, the towers' faces and the high arches, out of the runner's reach. Do you agree, or should
   stage 2 move into walled galleries (and then The Magnate needs an attack that reaches wall runners)?
3. **The entrance:** the suit rises at the far end of the court, its cape unfurling, to the cult's
   three-note chime (the Resonator's) played huge and slow.
4. **Paces:** stage 1's phases at 1, 1.1 and 1.2; stage 2's at 1, 1.15 and 1.3 (the Sleep Taker's).
5. **The strafe's first pass covers the outer lanes**; in the 7-pass strafe the 4th and 7th passes come
   from behind.
6. **The horizontal pass's live line reaches above a jump** (a jump doesn't dodge it: the buttress or the
   dash does).
7. **Which slams land ahead, and which are buttress chances** (a fixed script): phase 1, slams 1 and 2 on
   the runner and 3 ahead, chances on 2 and 3; later phases, slams 1, 3 and 4 on the runner and 2 and 5
   ahead, chances on 3 and 4. About two seconds apart, faster with the phase's pace.
8. **The hole's footprint:** around the locked lane, moved inward at the edge; a fist locked onto another
   lane never digs through a buttress.
9. **The barrage's fire** is about 1.5 s and a metre high (a jump only delays it); the missiles hang at
   the top of their climb, then dive with a whistle while the red marks fill in.
10. **The Refill Ship's strafe holds its fire** while the cage comes up and the runner goes for it, so the
    route to the pad is always clear, then fires on once they're past the pad.
11. **The cage's sides** are fences along the pad lane's edges (a new lengthwise fence, the same pink
    crackle and rules as any fence).
12. **Stage 2's attacks:** the Pounce (bait it into a Flying Buttress to stun him; stomp a red spine port
    by jumping onto his back) and, from stage 2's second phase, the Cable Lash (low: jump; high: slide).
    A buttress comes up for every second Pounce. Do you want a third attack for stage 2's last phase?
13. **The defeat:** his cables tear out, the screens go dark one after another, the music cuts out with
    them, he collapses in silence, then the victory riff. Should the riff play at all, or should the
    fight end in silence like the Sleep Taker's and leave the music to the ending cinematic?
14. **Numbers:** six phases of the boss's health (a sixth each); weapons chip at most one big hit's worth
    over the whole fight; 1,000 credits and 10,000 points for the win; par times measured from a clean
    fight.
15. **Music:** the Golden Zone's track for now. Would you like a final boss theme of its own?

## E5d-a

Built in task E5d-a (the golden suit, the Grand Court, the entrance, the Helidrone Strafe and the Flying
Buttress). Every number below is in `data/bosses/golden_boss_tuning.tres` (`GoldenConvergenceTuning`, F6 in
the fight) or `data/bosses/golden_boss_skin.tres` (`GoldenCourtSkin`) unless it says otherwise, marked
`DESIGN-TBD` in code.

1. **How far ahead the suit floats, and which weapons reach it** (GDD §10: "it floats in the distance ahead
   of the runner"; "weapons chip at it slowly"). The suit's chest is 64 m ahead (`suit_ahead`), 12 m over the
   causeway (`suit_height`): far enough to read whole on a phone's screen, halo to hands, and inside the 70 m
   reach of weapon tiers 2-4, but **out of the tier-1 weapon's 42 m** (`PowerupTuning.weapon_range`), so the
   starting weapon never chips it. Should every tier reach it (bring it to 40 m, or give weapons a longer
   reach in this fight), or is it fine that only bought upgrades chip the suit?
2. **The suit's look** (GDD §10, Look): heavy half-closed eyes looking down the causeway and a faint smile
   (a calm face cast in gold, `GoldenConvergenceModel.face_relief`/`face_marks`); the dull red tear runs from
   under its left eye (the runner's right) down its cheek to a drop; a three-pointed diadem (the Triad's
   arrows) and two halo rings with rays turning slowly behind the head; filigree waves along the pauldrons'
   rims; four missile pipes in a row on each pauldron, angled up and back under a hinged hatch; eight
   tentacle pipes, the middle ones trailing back over the causeway, the outer ones splaying out past its
   edges and down toward the pools; the cape a cloud fanned out behind it from the shoulders, up over the
   halo and down past its sides, deep pleats with black troughs (`golden_convergence_cape.gdshader`,
   `cloth_color` 0.31/0.03/0.075 sRGB, darker burgundy with more black in its folds after the orchestrator's review, never glowing; the suit's gold a little richer than the palace's, 0.85/0.67/0.42, inside the suite's chroma limit). Is this the suit you pictured?
3. **The squadron's look** (GDD §10: "the heli drone's model, never coloured red"): the heli drone's model at
   1.45x (`drone_scale`), its red eye and band redrawn in a cold white glow and unlit gold, no amber
   (`add_model(..., hostile = false)` in `scripts/enemies/drone.gd`). Their fire and its warnings stay the
   enemy attacks' red.
4. **A jump doesn't dodge a vertical pass either.** The rake's fire reaches 3.2 m up
   (`GoldenConvergenceFire.RAKE_HEIGHT`, over a jump's reach), as the GDD proposes for the horizontal line,
   so each vertical pass makes the runner change lanes ("each vertical pass moves the player").
5. **The first pass on 6 lanes.** "The first pass covers the outer lanes (lanes 1, 3, 5 counting from 1)":
   on 3 and 5 lanes those take both outer lanes; on 6 lanes lanes 1, 3 and 5 take only the left one (lane 6
   is safe on the first pass). Built as written (`GoldenConvergenceTuning.covered_lanes`, parity 0 first).
6. **The strafe's timings** (GDD §10: "about a second ahead"; "a second or two apart"): the red lines and
   the whine come 1.15 s before the guns open up at the far end of the raked stretch (`warning_seconds`,
   never divided by the pace); a head-on pass rakes 42 m of lane toward the runner at 55 m/s, so a runner who
   stays is hit about 1.4 s after the lines show; a pass from behind about 2 s after; the next pass's warning 1.5 s after a pass's fire
   (`pass_gap`, divided by the phase's pace); out of the cape 1.6 s, back 2.2 s. The squadron waits 40 m
   ahead and 12 m up between passes and rakes from 7 m up.
7. **The horizontal pass:** the sweep crosses the track in 0.55 s; the live line burns whole 0.3 s before
   the runner reaches it and 0.45 s after they're past it; its fire reaches 3.4 m up (above a jump) and 1.6 m
   along the track; the lines for show lie 24 m apart beyond it (one per other drone), burn 0.6 s and have no
   hitbox at all (their fire is out long before the runner gets there); scorch marks fade over 9 s.
8. **The Flying Buttress** (GDD §10: "taller than other doodads ... it comes into view well before its line"):
   it rises out of the causeway 6 s before the runner reaches it (`buttress_sight`) over 1.4 s, with a deep
   grinding rumble; its pier 3.2 m deep and 16 m tall, its arched opening 4.4 m tall and about 1.4 m wide in
   the lane's middle; its flying arch leaps 70 m out and 38 m up toward its tower, leaning toward the
   nearer edge (by the fight's seed in the middle lane); the Triad in gold on its face. Its sides bump a
   lane switch into its lane from just before its front (`blocker_lead`). **A switch out of the arch while
   inside it isn't blocked** (the runner slips through the leg): should it be (a lane blocker on both sides
   of the pier, the runner bumped back into the arch)?
9. **The walls:** where nothing opens a wall, both walls are taken away (`BossProps.block_wall`) from just
   behind the runner to 240 m ahead (`wall_block_ahead`), so a move past an outer lane bumps them back with
   the clank, as the GDD says. An open wall (E5d-b's toppled tower) is fired on low (an outer lane's rake
   climbs it to 1.5 m, `wall_fire_height`: a wall runner above it is safe, so a wall run is safe for about
   its first second, from its 2.2 m entry, and hit low in the rest of its slide; the rake's box in the lane
   keeps clear of a wall runner's body) and at every height by the live line (7 m, `wall_line_height`).
   Is "low" about right?
10. **The Grand Court's numbers:** the balustrade 1.1 m tall with lamp posts every 5 m; the pools 22 m below;
    a tower every 120 m along each side (alternating), 30 m out, each with a 17 m feed screen 24 m up showing
    the calm golden face and the emblem in turn (`golden_court_feed.gdshader`; stage 2's roaring Magnate is a
    darkened placeholder until E5d-d); the hall's colonnade 95 m out, columns 135 m tall, the vault's ribs
    every 160 m.
11. **The entrance's timing** (proposed in the GDD): the first phase's intro is 5.5 s: the suit rises 60 m
    over 3.2 s, the cape unfurls from 1 s over 2.6 s, the chime rings at 1.6 s (the Resonator's G5, C6 and E6,
    0.7 s apart where the Resonator's are 0.42 s, each doubled an octave and two below, with the court's
    echo: `gc_chime`; every sound effect stays under 2.5 s, so the rise's rumble tapers off under the chime); then the first
    beat 0.8 s into the pattern. A later stage 1 phase's 3 s intro: the suit reels back (0.22 rad) and
    recovers.
12. **The fight's numbers for now:** 600 health; pars 330 s (two stars) and 260 s (three) and a 400 s time
    bonus, all provisional until the whole fight is built; phase names "The Golden Suit" (1-3) and "The
    Magnate" (4-6). The boss bar shows the phase's number alone ("1/6") when the boss's long name and the
    phase's title don't both fit (`BossBar._refresh`).
13. **Until the later steps:** a beat whose attack isn't built yet is skipped (slams, barrage: E5d-b), a
    refill beat plays its strafe alone (E5d-c), and stage 2 (phases 4-6) idles the suit with no attack
    (E5d-d), so `--boss=golden_boss --phase=4` plays.

## E5d-b

Built in task E5d-b (the Fist Slam with its Flying Buttress bait and the toppled tower's wall, and the Missile
Barrage). Every number below is in `data/bosses/golden_boss_tuning.tres` (`GoldenConvergenceTuning`, groups
"Fist Slam", "The toppled tower" and "Missile Barrage", F6 in the fight) unless it says otherwise, marked
`DESIGN-TBD` in code.

1. **Phase 1's third slam is both ahead and a chance.** The GDD's two proposals overlap: "in phase 1, slams 1
   and 2 come down on the runner and slam 3 ahead" and "the chances are slams that come down on the runner:
   slams 2 and 3 in phase 1". Built as both (`slam_scripts` "Ooa": a lower-case letter is a chance), so phase
   1's last chance is an ahead slam: its fist locks on the runner's lane and lands ahead, and a runner in the
   gate's lane as it locks smashes the gate. Later phases ("OAooA") have no such overlap. Should phase 1's
   third slam come down on the runner instead, or stay ahead?
2. **Where a chance's hole is dug.** "A fist locked onto another lane digs its hole beside the buttress,
   never through it": a chance's row ends 0.6 m before the gate's pier (`slam_gate_gap`), so its hole lies
   in front of the gate, never through it, whichever lanes the footprint takes. On 3 lanes the middle lane is
   the only inner lane and every two-lane footprint takes it, so the hole always opens in the gate's lane, in
   front of it (the gate still stands). Is "in front of it" what you meant by "beside it"?
3. **The square footprint** (GDD §10, proposed: "around the locked lane, moved inward at the edge"): two
   lanes on 3 lanes, three on 5 and 6 (`GoldenConvergenceHole.hole_lanes`), as long along the track as it is
   wide. On 3 lanes, from the middle lane the second lane is on the slamming fist's side (they take turns);
   from an outer lane, the middle lane. Never every lane, so a lane switch always gets out from under it.
4. **The fist's timing:** out over the runner's lane in 0.7 s (over the pace), the warning (the fist rising
   from 8 m to 11 m, its shadow growing, the red square, the grind) 0.8 s before the lock, the lock 1 s before
   it lands, the drop in the last 0.4 s; slams 2 s apart (over the pace); back to rest in 0.85 s. An ahead slam
   lands as the runner is 1.1 s from its hole (`slam_ahead_seconds`), to be jumped or switched around. The
   touch lasts 0.2 s from the impact and reaches 4 m up over the hole's square (`slam_hit_seconds`,
   `slam_hit_height`: a jump doesn't clear it).
5. **The hold after a blocked hit** (GDD §10: "the floor under the runner holds for about a second ... A dash
   through the fist gets the same second"): it's given to any runner the touch doesn't kill: the armor or the
   shield blocking it, the dash, and also a runner still invulnerable from an earlier hit (and god mode).
   Only the lanes under the runner's feet hold, for `GameRules.cut_hold_seconds` (1 s). The grapple saves
   the fall into the hole, never the hit.
6. **The arm's reach.** The suit floats 64 m ahead, so a fist over the runner's lane is 45-70 m from its
   shoulder: past a full telescope, each golden sleeve also stretches, up to 2.4 times its length
   (`GoldenConvergenceSuit.EXTEND_MAX`). Is a stretched arm fine, or should the suit lean in or come closer
   for its slams?
7. **The first slam can stalk.** A slam's hole is a floor cut, and floor cuts must lie past the track built
   ahead (about 200 m), so each sequence is planned while the beat before it plays (from where that beat
   will be over): after a strafe or a barrage, the first impact comes about 2.4 s after the beat begins. A
   phase that opens with slams (phases 2 and 3) can only plan them during its short intro, so its first fist
   comes out at once and follows the runner's lane until its warning: its first impact comes about 4.5 s
   after the beat begins at 25 m/s (7.7 s at quick play's 18 m/s). Fine, or should those phases open with a
   longer intro or another attack?
8. **A bait ends the sequence at once:** the other gate, if it's up, sinks back into the causeway the way it
   rose; the barrage starts warming up the same frame (no gap after a bait; the usual `beat_gap` otherwise).
9. **The toppled tower** (GDD §10: "the building it held up, off screen, topples forward along the track"):
   it appears standing beside the causeway out of view, its foot at least 9 m behind the runner
   (`tower_behind`; farther back so its crown ends at its wall's end), and falls forward over 1.5 s
   (`tower_fall_seconds`), so the run camera sees only its last moment as it comes down beside the runner
   (with a rumble, dust and a shake; no flash). It is long enough for its wall: about 230 m at 18 m/s, 300 m
   at 25 m/s. It lies with its side flush with the wall's line, 14 m wide, its top about 9 m above the
   causeway (`tower_width`, `tower_depth`): white marble, gold bands, lit windows on its top and outer side,
   a gold crown and spire. Its side is the wall from the gate's front for 10 s of running
   (`tower_wall_seconds`); once the runner is past it, it sinks into the pools behind them over 2.5 s.
   Should more of the fall be seen (for example the tower already standing marked at the roadside ahead, as
   the Floating Head's are)?
10. **The barrage's warning:** the hatches open over 0.5 s, the missiles launch one after another over 0.5 s
    and climb for 1 s, arcing up out of view, then hang 0.5 s 22 m up and about 46 m ahead, out to either side
    of the suit's chest and keeping pace with the runner (`missile_apex_height`;
    `GoldenConvergenceBarrage.APEX_*`), then dive for 1 s with the whistle while the marks fill in: the fire
    lands 3 s after the hatches open, at every pace. Reaching the wall from the far side needs 1.5 s on 3
    lanes and 2 s on 6 (a 0.7 s reaction, 0.14 s a lane switch, the 0.16 s wall entry and a 0.4 s margin:
    `barrage_reaction`, `barrage_margin`). The red marks spread over the floor from the launch: 5 a lane
    (`marks_per_lane`, one missile each), 0.95 m across (`mark_radius`). Like every other attack it's keyed
    to the runner's distance at the run speed, so a dash during the warning brings the fire a little sooner.
11. **The fire's stretch:** every lane from 3 m behind where the runner is as it lands (`fire_behind`) to as
    far as they could run while it burns, a dash included, and 5 m more (`fire_ahead`): it can't be outrun.
    In an outer lane it stops short of a wall runner's body, so the wall is safe at every height. It leaves
    no scorch marks (the strafe's do); it dies down over 0.35 s after its 1.5 s.
12. **Pickups keep off** a slam's rows and the barrage's stretch (both are floor warnings, like the strafe's
    red lines).
13. **One armor hit plus the dash is a tight fit** at 1.5 s of fire (1.6 s of protection, as the GDD gives
    it): two armor hits and armor plus the shield carry the runner through on their own, but with the armor
    and the dash the dash has to start within about 0.1 s of the fire landing (so the armor's second follows
    it) or within the last 0.1 s of the armor's second. A runner who dashes at any other moment burns. Is that
    the "a bit toasty" you meant, or should the fire be a little shorter (1.3-1.4 s gives a 0.2-0.3 s window)?
