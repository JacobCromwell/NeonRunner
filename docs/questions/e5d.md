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

## E5d-d

Built in task E5d-d (stage 2, The Magnate, and the defeat, "the feed dies"). Every number is in
`data/bosses/golden_boss_tuning.tres` (`GoldenConvergenceTuning`'s "The Magnate" groups, F6 in the fight) unless
it says otherwise, marked `DESIGN-TBD` in code. Review it with `./play.sh --boss=golden_boss --phase=4` and the
showcase (`res://tools/showcase/golden_convergence_magnate_showcase.tscn`, its header lists the scenarios).

1. **His look** (GDD §10, Look, owner approved): built as written on all fours, a hunched predator about 3.5 m
   from snout to rump and 1.95 m at the shoulder, 2.7 times the runner's drawn height (`magnate_scale` 1):
   blackish-grey skin cracked in a fine cell network, the plates between toned like burnt paper; dull gold
   splashes on his shoulders and haunches; half the calm golden mask fused to his left side (the runner's
   right as he faces them), its closed eye and dull red tear, his real right half a heavy brow, a wild pale
   eye and a roaring jaw; five red ports along his spine (the weak points' red, the only thing on him that
   glows a hazard colour); burgundy tatters from his shoulders trailing grey smoke; the six broadcast cables
   (the suit's tentacle pipes, burnt black with dull gold bands) trailing from his back to the ground behind
   him. Is this him?
2. **The warm white in his cracks** (optional in the GDD): on, at `crack_glow` 0.55, leaking only from some
   cracks in patches; it flares as he claws out of the suit and dies with him. Its colour is the feed's warm
   white (1.0/0.93/0.82), clearly whiter than the runner's copper glow (0.96/0.64/0.46). Keep it, or dark
   cracks (0)?
3. **The chase** (proposed: "his shadow and a marker at the screen's bottom edge show his lane"): he keeps
   10.5 m behind the runner (`chase_gap`, behind the camera) and takes up their lane 0.6 s after they change it
   (`chase_lane_delay`). His shadow is a soft dark blob in his lane from 2.5 m ahead of the runner to 4.5 m
   behind them (`GoldenConvergenceChase.SHADOW_*`; the run camera's view ends just behind the runner's feet, so
   the shadow has to reach past them to show). The marker is a chevron with two claw marks at the bottom edge
   under his lane, in the feed's warm white while he follows and the enemy attacks' red at a Pounce's warning.
   His breathing and growls play from where he is. Is the shadow readable without looking like a hole (the
   Grand Court has none)?
4. **The overtake** (GDD: "he overtakes along a wall or ceiling, lands ahead, then drops back"): with no walls
   or ceilings over the causeway, he runs past the runner along the nearer balustrade to 15 m ahead
   (`overtake_ahead`), leaps across the causeway 6.5 m over every lane (`overtake_height`) onto the other
   balustrade ahead, and drops back along it (4.4 s, `overtake_seconds`, divided by the pace). He lands on the
   balustrade, never on the track, so an overtake can't be mistaken for a Pounce; it growls rather than roars
   (the roar is the Pounce's warning). It opens phase 4 and each of its loops. Should he land on the track
   ahead instead (harmless)?
5. **The Pounce** (proposed): the roar and the red marker 0.75 s before he leaps (`pounce_windup`, divided by
   the pace); the leap 1.7 s (`pounce_flight`), 5.5 m over the runner (`pounce_apex`); he locks onto the
   runner's lane 1.05 s before he lands (`lock_seconds`, never divided by the pace) and the red square (with an
   X) shows there, 3.6 m deep (`crash_depth`); he lands 0.15 s (`land_lead`) before the runner would reach it.
   The crash is an enemy attack over 84% of the lane's width, up to 3.2 m (above a jump: a jump doesn't clear
   him), live until the runner is past the square (0.3-1.2 s); then he bounds off onto the balustrade away
   from the runner (no arches over the causeway to bound onto) and drops back. Armor and the shield block the
   crash; the dash passes through it.
6. **The bait** (proposed: "a Flying Buttress comes up ahead for every second Pounce"): each phase's script has
   a plain Pounce, then a Pounce with the bait (`pounce:bait`). Its buttress rises in an inner lane (by the
   fight's seed) 6.5 s before the runner reaches it (`bait_sight`). A runner in its lane as he locks on makes
   him aim at the gate: he crashes into it 1.6 s before they reach his back (`stun_lead`, never divided by the
   pace) and slumps across its lane and the next one away from its lean (toward the middle; on 3 lanes the
   gate is the middle lane and he slumps toward the side away from the lean), his back to the runner. His
   weak points are a stomp box over his back in each of his lanes, reaching 3.5 m toward the runner (at
   18 m/s, longer at the Golden Zone's pace: `stun_reach`) and 0.4 m over his back (`stun_stomp_top`); his
   sides block a switch into him (a bump, never a hit). A runner who comes down on the floor 0.25 s (at the
   run speed, `stun_release`) short of his back, or runs past him, makes him shake free and leap away before
   reaching him; the bait comes round again with the phase's loop (no escalation). Is 0.25 s fair, or should a
   miss also cost something?
7. **The Cable Lash** (proposed): he runs up along a balustrade (sides in turn) for 2.3 s (`lash_run_up`,
   divided by the pace), then rears back on it for the warning, 1.25 s (`lash_warning`, never divided by the
   pace): his cables rise crackling red, a red line lies across every lane where it will sweep, and thin red
   aim lines cross the track at its heights. The whip crosses every lane in 0.25 s and lies across them 0.3 s
   before the runner gets there. A low lash is one cable at 0.35 m (jump it); **a high lash is two cables, at
   0.85 m and 1.9 m** (slide under both), the shape of a gapped fence and of the Floating Head's twin beams, so
   that a jump can't clear it too. Should the high lash be a single cable (then a jump would clear it as well
   as a slide)?
8. **The phases' scripts** (`phase_beats`): phase 4 an overtake, a Pounce, a Pounce with the bait; phase 5 a
   Pounce, a low Lash, a Pounce with the bait, a high Lash; phase 6 a Pounce, a high and a low Lash, a Pounce
   with the bait, a low and a high Lash; each looped until the stomp. A clean stage 2 from the checkpoint takes
   about 76 s of fight (about 25 s a phase). The GDD asks "do you want a third attack for stage 2's last
   phase?" (question 12 above): phase 6 is the Lash's mixes at the fastest pace for now.
9. **The transition** (proposed): phase 4's intro is 5 s (`data/bosses/golden_boss.tres`): the suit's chest
   bursts open over 0.5 s and its plates fly off from 0.35 s; he claws out of the man's room from 0.55 s and
   roars at 1.75 s (the screens switch to his roaring face, with a glitch); the empty suit topples off the
   causeway's side (by the fight's seed) from 2.3 s over 2.2 s and splashes into the pools far below; he leaps
   off the suit at 2.75 s, high over the runner, landing behind them 1.5 s later. It plays the same on a retry
   from the checkpoint. Phases 5 and 6's intros (2.5 s) are his hurl clear after a stomp, howling.
10. **The defeat** (proposed): he lurches 1.5 s (at the run speed) ahead of the runner into the lane furthest
    from them over 1.2 s, convulsing; his six cables tear out every 0.3 s from 0.6 s; from 0.9 s the screens
    glitch and go dark outward from him at 90 m/s (`blackout_speed`; beyond 700 m every screen in the world)
    and the music cuts out over 0.25 s; he collapses once his last cable is out, the light in his cracks dying
    over 1.4 s; once the runner is past him, the victory riff 0.35 s later. Question 13 above (the riff or
    silence) is the switch `victory_riff_on` (on).
11. **His sounds** (`tools/asset_gen/sfx_bank_magnate.gd`): his roar is both a Pounce's warning and the
    transition's screech; a howl when he hurls himself clear; a convulsive death roar; a heavy collapse in the
    silence. Is his voice the creature you pictured?
12. **Weapons in stage 2:** he can't be targeted until he's out of the suit; then weapons chip him like any
    boss part, within the fight's weapon cap (`weapon_share_cap`, one sixth over the whole fight). As in
    stage 1, `weapons_can_end_phase` is on, so a runner with enough weapon damage left could end one of his
    phases without a stomp. Should stage 2 only end on stomps?
