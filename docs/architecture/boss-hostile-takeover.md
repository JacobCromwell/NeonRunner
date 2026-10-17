# Architecture: Boss: Hostile Takeover

One part of the architecture notes; `docs/ARCHITECTURE.md` is the index of every part and topic.

## Bosses (continued)

**Hostile Takeover** (GDD §10, task E5b: E5b-a, the train arena, the gunship and the locomotive, and phase 1,
The Board, with the carriage couplings; E5b-b, phase 2, The Contract; E5b-c, phase 3, The Merger, the
defeat, the par times and its campaign slot). The campaign plays it after Corporate 2 at the zone's
23.4 m/s (`--level=corporate/boss` or `--boss=corporate_boss` in debug builds; the showcase and the measure
tool also play it at quick play's 18 m/s). Its tuning's distances that stand for a time (a carriage's
length, the stomp box's reach past a gap, the clear corridors around a coupling, the guards' spacing, the
tithe trail's spacing, a strafe's line, the runway of pads, the ride's landing) are written at 18 m/s and
multiplied by the run's pace (`HostileTakeover.run_pace()`), a gap is a share of a jump at the run speed,
like a level's, and a pass rides the belly at `pass_speed` whatever the run speed, so the fight keeps its
seconds at the zone's 23.4 m/s: a clean fight takes 68.6 s at 3, 5 and 6 lanes and both speeds (phase 1's
stomp at 19.6 s, phase 2's 24.8 s later, phase 3's last clamp 24.2 s after that; par 74 s for three stars,
96 s for two). Where the gunship and the locomotive fly and stand is framing, in metres. Its data turns
`BossDef.weapons_can_end_phase` off (DESIGN-TBD): weapons chip it, but only its stomps end a phase, each
phase's counted (phase 3 always takes its three clamps).
- **The train is the arena** (GDD §10: "carriage roofs are the floor and the gaps between carriages are the
  gaps, so it plays like a level"): `_plan_lap` clears each lap the generator made and puts in the train's
  gaps, one across every lane at the end of each carriage (`HostileTakeoverTrain`: `gap_jump_fraction` of
  a jump at the run speed; the carriages in the tuning's `consist`, corporate carriages `carriage_length`
  long and military flatcars `flatcar_length` long, for phase 2's drop, at the pace, stretched a little so a
  lap holds whole consists and the laps join without a seam). Gap `k` ends carriage `k` (`gap_start`,
  `roof`, `kind`, `next_flatcar`), the same over the whole fight.
- **The couplings** (`HostileTakeoverCouplings`): one over every gap, laid by the encounter from just
  behind the runner to the built track's end, each in a lane of its own (`HostileTakeoverBoard.lanes`:
  never the last one's lane, at most `coupling_max_shift` from it). From a phase's pattern on, past its
  `opening_gaps` dark gaps, they glow red (lit at least `lit_sight` before the runner reaches them) with
  green chevrons on the roof in their lane where a jump takes off to come down on them. Its weak point (its
  stomp box) spans its lane over the whole gap and `stomp_before`/`stomp_after` past its edges, up to
  `stomp_top` over the roofs: a jump that comes down over the gap in its lane, or moves into it in the air,
  stomps it, and the stomp's bounce carries the runner on (`HostileTakeoverTrain.bounce_clears`); running
  off the edge never reaches its top less the stomp tolerance, so a fall isn't a stomp. The stomp is the
  phase's hit (`stomp_weak_point`); the coupling breaks open and the carriages behind break away and tumble
  off the track (looks only: `HostileTakeoverSkin.set_breakaway` on the train's material; the collision
  stays the track's). A coupling passed is missed, harmlessly: the next gap's glows the same way.
- **The Board** (`HostileTakeoverBoard`), carriage by carriage as the built track nears it: guards (the
  zone's cyborgs, as VR runners) placed where nothing they do reaches a coupling's run-up (`approach_clear`)
  or its bounce's landing (`landing_clear`) in its lane, outside the cyborgs' own margin from a gap
  (`CyborgRules`), `guard_spacing` apart and fewer than the lanes, so a way through is always open; a partial
  wall fence (low and high in turn) on `wall_fence_share` of the carriages where `arena.wall_fence_problem`
  allows one (B5's rules), pulsing as the zone's do; and on each flatcar from `tithe_first` on a Tithe
  Collector and nothing else (no guards, no wall fence: it weaves toward the lanes with the most hazards
  ahead, and with none keeps to the runner's), brought into play in the runner's lane as they reach it
  (`spawn_enemy`), at most `tithe_visits_per_phase` a phase (OPEN_QUESTIONS item 321: a runner who lets the
  couplings go by can't farm their jackpots), with a trail of credits laid on the roof ahead of it for it to
  skim (`lay_tithe`, `CreditField.place`; a boss's track has no credits of its own). Every choice is seeded
  per carriage, so every attempt plays the same. The Board plans only while a phase plays it
  (`tick(active)`); as phase 2 begins the encounter stands it down: its guards still to come are retired as
  they come into play (each guard's entry names its `board_phase`) and its wall fences ahead are switched
  off the EMP's way (`TrackBuilder.disable_fences_near`).
- **The Contract** (`HostileTakeoverContract`, phase 2, planned from the phase's start so its first
  flatcar's cut still finds the track ahead unbuilt), one cycle after another:
  - the drop, onto the next flatcar: a level's Buzz Overdrive cut (`FloorCutPlan` with the C2 tank's own
    rev, charge and run past, no roll), in a seeded lane `arena.cut_problem` allows, added to the track;
    the gunship flies out over its spot (a red target on the roof marks it), lets the tank it carries fall
    (`drop_fall`) to land `drop_before` its rev, and the real tank comes into play there (`spawn_enemy`:
    its rev and line, its charge, the block-then-hold rule, all its own);
  - the ride, over the second carriage past it, armored (`HostileTakeoverArmored`: `armored_height` tall,
    its front in the solid obstacles' yellow and black, no dash through it), placed `ARMORED_SIGHT` ahead
    with a runway of pads in every lane before it (`pad_strip` long: no jump clears it, a dash in the air
    included, `HostileTakeoverContract.strip_clears`); the gunship comes down over the runner to the
    ceiling's height and flies on slower than them (`belly_front`), so they ride its belly from the runway
    until `landing_after` past the armored carriage's far gap; its drop bay, open and glowing red with
    green chevrons before it, is the phase's weak point (DESIGN-TBD), stomped by a jump on the belly that
    comes back up onto it (`bay_lead`); a bay let go by is missed and the next flatcar's cycle comes;
  - strafes in between, when nothing else is going on (`strafe_fits`: no drop or ride near, no phase-1
    guard about): red lines along the runner's lane and the one beside it (`struck_lanes`: never all of
    them) with the rising whine for `strafe_warning`, then the guns rake each line from its far end back
    past the runner (`HostileTakeoverStrafes`: an attack hitbox over a jump's reach in each lane; the
    walls are safe).
  Pickups keep off a ride (`_pickup_at`: an armor pickup due there goes past it, where the runner lands).
- **The Merger** (phase 3, GDD §10: "the locomotive comes back and the gunship docks onto it with huge
  clamps, forming one monstrous war engine, and 'MERGER COMPLETE' flashes on every screen ... its attacks
  combine both"): once phase 2's ride is over (a ride under way flies through), the docking
  (`Step.DOCK`, `dock_seconds`): the locomotive comes back from `loco_ahead` to `merger_ahead` while the
  gunship settles onto its rear (`DOCK_OFFSET`, its belly `dock_height` over the roofs), its arms gripping
  the locomotive's flanks and its three clamps unfolding under its belly as they lock (`set_docked`,
  `takeover_clamps`); then MERGER COMPLETE (`Step.MERGED`, `takeover_merger`, the hint
  `boss:corporate_boss/merger`) on the locomotive's rear window turned screen and two ad screens on pylons
  rising beyond the barriers ahead (`HostileTakeoverScreens`: the Chairman's face as a broadcast, the words
  flashing for `merger_flash_seconds`, steady with Reduced flashing). The war engine then leads the train,
  the locomotive moving with the gunship (`docked_pose`), and the contract plays on in its merger mode
  (`start(true, not_before)`, or `merge()` keeping phase 2's planned drops that come after the docking): the
  drops as phase 2's (the war engine moving along the line, never out over the roof), the strafes (docked,
  the first `merger_hold` after MERGER COMPLETE), and after each drop a pass instead of a ride
  (`plan_pass`): a runway of pads on the carriage after the flatcar, placed so the runner drops back onto a
  roof as far from a gap as it can be; the war engine comes back and down over them (`pass_descend_seconds`)
  so they ride its belly forward at `pass_speed` (`pass_u`) under its three clamps (`clamp_at`, one under
  each third of the belly, `clamp_side`), each glowing red with the ways up's green chevrons on the belly
  behind it (`clamp_cue`: a jump from anywhere on it comes back up onto the clamp, `clamp_lead`), live while
  they ride under it until it's torn loose (`tear_clamp`, `takeover_clamp`); at `pass_release` it pulls
  away (`pull_speed`) and they drop back onto the roof. Clamps left in a pass stay for the next; a pass let
  go by is missed and the next flatcar's cycle comes (no time limit, no escalation). The Board comes back
  on the consist's `merger_board_slots` (guards from `merger_guards`, wall fences, no Tithe Collector; never
  on a pass's runway or landing carriage). Phase 3's parts are built with the fight, hidden until needed
  (the shader warm-up draws them during the load).
- **The defeat** (GDD §10: "the gunship spins away and explodes; the locomotive derails and ploughs through
  the lobby of a corporate tower, bringing down a giant, soulless logo sculpture"): the last clamp torn
  loose, the contract halts and a corporate tower's lobby with its plaza's logo sculpture is set beside the
  line ahead (`HostileTakeoverLobby.place`, on `derail_side`; the city's towers keep clear of it,
  `HostileTakeoverSkin.set_clearing`); the gunship pulls free, climbs away beside the line spinning and
  explodes `explode_at` seconds later (`takeover_explode`); the locomotive surges on, veers off the
  guideway and ploughs into the lobby `crash_at` seconds in (`takeover_derail`), its wreck wholly beyond the
  barrier, the sculpture toppling back into the lobby; each blast a fireball big enough to read far ahead
  (`HostileTakeoverLobby.blast`: swelling and cooling, dimmer and never white-hot with Reduced flashing);
  the screens glitch and go dark (their tearing only dims with Reduced flashing). The parts no longer tick
  once the boss is beaten, so the encounter runs the screens' and the blasts' clocks (`step`). The runner
  runs on (god mode from the win on, as every boss's), and the results come `defeat_seconds` after the
  stomp.

In `scripts/bosses/hostile_takeover/`:

| File | What |
|---|---|
| `hostile_takeover.gd` (`HostileTakeover`) | the encounter: the arena (`_plan_lap`), its parts, the phases (phase 1's intro is the entrance: the gunship sweeps in from behind and above the runner with its roar; a later phase's begins with it lurching) and their patterns (`pattern_of`: The Board, The Contract, The Merger), a Board pattern lighting the couplings from `opening_for(phase)` gaps on (`couplings_from`); every frame it lays the couplings over the gaps in sight (`RIG_BEHIND` to `RIG_AHEAD`), lights the live ones (`coupling_lit`; the first brings the `takeover_couplings` cue and the hint `boss:corporate_boss/couplings`) and notes the missed ones; a stomp (`_on_weak_point_hit`: the coupling breaks open, `takeover_decouple` and `takeover_breakaway`, the breakaway's clock; or the drop bay bursts, `_bay_stomped`; or a docking clamp is torn loose, `_clamp_stomped`); phase 2's stand-down (`_stand_down`, `_on_enemy_spawned`), its ride's start and end (`ride_begins`: the bay opens, `takeover_bay`, the hint `boss:corporate_boss/ride`; `ride_ends`), pickups kept off a ride (`_pickup_at`); phase 3's docking (`_update_merger`: `docking`, `clamps_locked`, `merger_complete`; `docked`, `docked_pose`, `_docking_done_at`) and its passes' start and end (`pass_begins`: the hint `boss:corporate_boss/clamps`; `pass_ends`: `pass_landed`/`pass_missed`); the gunship's flight relative to the runner (`station_pose`: `gunship_ahead`, `gunship_height`, swaying and bobbing on the fight's clock; docked, the war engine's; the contract's `pose` over it), the locomotive `loco_ahead` ahead (docked, with the gunship); the defeat (`_on_defeated`, `_defeated_tick`, `_place_defeat`: `defeat`, `gunship_exploded`, `locomotive_crashed`; `victory_over` after `defeat_seconds`). `coupling_live`, `next_live_coupling`, `run_pace`, `sound()` (plays and logs), `warm_enemies()` (the guards, the Collector and the Buzz Overdrive); first-time hints `enemy:corporate_boss`, `boss:corporate_boss/couplings`, `/strafe`, `/ride`, `/merger` and `/clamps` |
| `hostile_takeover_train.gd` (`HostileTakeoverTrain`) | the train's plan: `plan()` (the consist), `gap_start`, `gap_end`, `next_gap`, `gap_at`, `roof`, `kind`, `carriage_at`, `next_flatcar`, `lap_gaps()` (a lap's gap entries), `ends_behind()` (for the breakaway), `bounce_clears()` |
| `hostile_takeover_board.gd` (`HostileTakeoverBoard`) | phase 1's plan (`tick(active)`, `plan`, `pause`): the couplings' lanes (every phase), the guards (`guard_fits`, `guard_reach`; none on a flatcar), the Tithe Collectors (`tithe_spot`, `tithes_due`, `lay_tithe`; `visits` a phase, capped) and the wall fences (B5's `WallFencePlan.make`, `arena.wall_fence_problem`, `arena.add_pieces`, at the arena's difficulty; none on a flatcar); in phase 3 (`merger`) only on the consist's `merger_board_slots`, no Collector; a `carriage_planned` event each |
| `hostile_takeover_contract.gd` (`HostileTakeoverContract`) | phase 2's and phase 3's plan and course (`start`, `merge`, `stop`, `halt`, `tick`; `merger`, `not_before`): the drops (`plan_drop`, `saw_now`), the rides (`plan_ride`, `ride_now`, `next_ride`, `ride_stretch`, `belly_front`, `bay_lead`, `relative_speed`, `longest_leap`, `strip_clears`), phase 3's passes (`plan_pass`, `pass_u`, `clamp_lead`, `up_time_for`), the strafes (`strafe_fits`, `struck_now`) and the gunship's flight for them (`pose`, `riding`); events `contract`, `drop_planned`/`drop_refused`, `drop_marked`, `saw_released`, `saw_landed`, `ride_planned`, `ride_placed`, `ride_begins`, `ride_boarded`, `ride_landed`/`ride_missed`, `pass_planned`, `pass_placed`, `pass_boarded`, `strafe_warned`, `strafe_rake`, `strafe_done` |
| `hostile_takeover_armored.gd` (`HostileTakeoverArmored`) | the armored carriage part, pooled: its body (a solid hitbox a little inside its look, no dash through it) and its runway (a pad trigger the lane's full width in every lane, its tiles one MultiMesh of the skin's lift pad); `place` (a pass's runway without the body), `release`, `body_span`, `strip_length` |
| `hostile_takeover_strafes.gd` (`HostileTakeoverStrafes`) | the strafes' rakes, pooled (`RIGS`): per struck lane an attack hitbox over a jump's reach, the burning streak of its impacts and the tracer from the gunship's guns (a flicker, steady with Reduced flashing); `start`, `set_front`, `stop` |
| `hostile_takeover_couplings.gd` (`HostileTakeoverCouplings`) | the couplings part: a pool of `POOL` rigs moved from gap to gap (`place`, `release_before`; the coupling's halves, its dome dark or glowing red and pulsing, steady with Reduced flashing, a red halo while live, the take-off chevrons, its weak point), `set_live`, `arm`, `break_open` (its rear half drops away), `box_span`, `takeoff` (where a jump that lands on it leaves from) and `descent_lead()`; immune to weapons, no kill of its own |
| `hostile_takeover_gunship.gd` (`HostileTakeoverGunship`) | the boss's body: it shares the fight's health (weapons chip it, up to the cap); its belly a ceiling (`belly`, the hull layer), its drop bay's weak point (`bay_point`, upside down) with its glow and the green chevrons before it (`set_bay`; the bay's pulse steady with Reduced flashing), the Buzz Overdrive it carries and lets fall (`set_saw`, `saw_world`, `set_fall`, `end_fall`: the C2 tank's own model), its chin gun's muzzle flash (`set_firing`, `gun_point`); phase 3's docking (`set_docked`: the arms gripping the locomotive, the clamps unfolded) and its three docking clamps (`clamps`: each a weak point upside down under a third of the belly, its lock glowing red and pulsing, steady with Reduced flashing, the green chevrons behind it, `clamp_cue`, `clamp_lead`; `tear_clamp`, `clamps_left`, `clamp_of`, `clamp_span`, `clamp_world`); `set_pose`, `bay_span`, `aim_point`, `hit_radius` |
| `hostile_takeover_locomotive.gd` (`HostileTakeoverLocomotive`) | the locomotive leading the train, the Chairman at its rear window (`set_front`, `set_pose` for the docked war engine and the derailment, `set_chairman_shown`, `chairman_head`); never a target |
| `hostile_takeover_screens.gd` (`HostileTakeoverScreens`), `hostile_takeover_screen.gdshader` | phase 3's screens: the locomotive's rear window turned screen and two ad screens on pylons beyond the barriers pacing the train ahead (`pace`), each the Chairman's face as a corporate broadcast (the shader: drawn as distances so it stays crisp, faint scanlines and a cold-white frame, the defeat's glitch tearing it in bands, only dimming with Reduced flashing; on the Compatibility renderer an over-bright colour is scaled down whole) under the words (`merger_text`, one TextMesh in the UI's display face for all three, translated), dark until the docking (`set_on`), the words flashing for `merger_flash_seconds` (steady with Reduced flashing, `words_shown`), glitching and going dark in the defeat (`set_glitch`; `step` runs their clock) |
| `hostile_takeover_lobby.gd` (`HostileTakeoverLobby`) | the defeat's set: a corporate tower whose sky lobby faces the line and its plaza's logo sculpture (`place`, `span`, `topple`, `lobby_world`), and its blasts (`blast`: one of RunEffects' shared fireballs, `fireball`, sized by the blast's metres across), built with the fight and hidden until the defeat; looks only |
| `hostile_takeover_model.gd` (`HostileTakeoverModel`) | the meshes, built once in code, one draw per material: the gunship (about 2,000 vertices; olive and gunmetal, its belly flush and as wide as the train, its closed bay doors, the three docking clamps folded under it, cold-white lights and blue engines), its open drop bay (`bay_open`) and the chevrons before it (`belly_cue`), the armored carriage (`armored`), the locomotive with the Chairman's lit suite (about 560) and the Chairman (about 1,000: long coat, collar, shoulder plates, cane), the coupling's parts and the take-off chevrons; phase 3's clamps (folded, unfolded, their red locks: `clamp_folded`, `clamp_body`, `clamp_core`), the docking arms (`dock_arm`), the screens' pylons (`screen_pylon`), and the defeat's tower (`lobby_tower`, about 500) and logo sculpture (`logo_sculpture`, about 190). Plain colours on everything that moves (the kit's world-space patterns would slide); nothing glows in a hazard colour but the weak points' red |
| `hostile_takeover_skin.gd` (`HostileTakeoverSkin`), `hostile_takeover_train.gdshader`, `hostile_takeover_towers.gdshader` | the arena's look, the Corporate zone's (`CorporateSkin`): the floor as one wide train (the express's roof across every lane, the usual orange edge at each gap, a floor cut sliced down its lane) in a material of its own whose vertex shader plays the breakaway, each carriage tumbling about its own rear end (`set_breakaway`, `clear_breakaway`); the runway's pad tile (`pad_tile`); the walls as the track's sound barriers (gunmetal panels between posts, the wall-run marks, nothing lit below the band's top); beyond them the city's towers rushing back at the train's speed (`towers_for`: one mesh per side per chunk, moved by its shader, so nothing is made while the train runs; `set_clearing` keeps a stretch on one side clear of them, the defeat's lobby) and far below the street streaming past (the City's road shader in the zone's colours) under the guideway's beam; nothing hangs over the street |
| `hostile_takeover_tuning.gd`, `data/bosses/corporate_boss_tuning.tres` | its numbers (F6 in its fight; all DESIGN-TBD, `docs/questions/e5b.md`) |
| `data/bosses/corporate_boss.tres` | its slot: `scene`, three phases (one stomp, one stomp, the three clamps), weapons capped at 0.34 of its health and never ending a phase (`weapons_can_end_phase` off, DESIGN-TBD), the standard armor rule with `armor_when_unprotected`, the Corporate zone's music, par times (74 s and 96 s), its arena (one lap of the train) |
| `data/bosses/corporate_boss_skin.tres` | its arena's look: the VR runners on the roofs, a thinner fog so the locomotive shows at the end of the view, nothing over the street |
| `tools/asset_gen/sfx_bank_hostile_takeover.gd` | its sounds (`takeover_*`: the gunship's entrance, the couplings going live, a coupling stomped, the carriages breaking away; the strafe's rising whine and its rake, the tank's drop, the drop bay opening; the docking clamps locking, MERGER COMPLETE's sting, a clamp torn loose, the gunship exploding, the locomotive derailing into the lobby) |
| `tools/showcase/hostile_takeover_showcase.tscn` | scripted runs and close-ups for reviews (`--scenario=run/train/gunship/locomotive/coupling/contract/merger/defeat`, `--lanes`, `--speed`, `--phase`, `--cam=back/run/side/ride/dock/belly/clamp/chase`, `--defeat-after`, `--still`, `--events`) |
| `tests/helpers/hostile_takeover_bot.gd` (`HostileTakeoverBot`) | a runner who plays it by what it shows, `reaction` seconds late: every gap jumped, each live coupling's lane reached a lane at a time (never across a guard) and a jump timed to come down on it (`stomp_lead()`; from the lane beside it with `side_lane`, the other side if a guard stands there; let go by with `misses`, from its own lane with `skip_in_lane`; `drops` runs off the edge), out of the guards' lanes and their bolts' line; in phase 2 out of a strafe's lanes and a landed tank's (`ignores_strafes`, `meets_saw` for tests of a hit), over the runway and on the belly a jump onto the drop bay (`bay_lead`; `bay_misses` lets some go by); in phase 3 on a pass the lane under the next clamp still locked ahead and a jump onto it (`clamp_lead`, `clamp_lane`; `pass_misses`, `clamps_per_pass`) |
| `tools/measure/hostile_takeover.gd` | the fight through quick play at every lane count and speed: a death in phase 3 once docked, the retry won whole with its defeat played out, whether every attempt played the same (options in its header: misses of each kind, clamps a pass) |
