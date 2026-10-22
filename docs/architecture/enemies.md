# Architecture: Enemies: the files of a type, the director, airspace, pace, floor use, dash walls

One part of the architecture notes; `docs/ARCHITECTURE.md` is the index of every part and topic.

## Enemies

An enemy type needs only files of its own; nothing shared is edited:

| File | Purpose |
|---|---|
| `scripts/enemies/<type>.gd` | the `Enemy` subclass (found by name) |
| `scripts/enemies/<type>_tuning.gd` | its tuning class, extending `EnemyTuning` |
| `data/enemies/<type>.tres` | its tuning values (spawn lead, score, health early/late, floor use, and its own numbers) |
| `data/patterns/<type>.json` | patterns that place it, each with `"requires": ["<type>"]` |
| `scripts/enemies/<type>_rules.gd` | optional generator rules: `static func apply(gen: LevelGenerator)` (and hooks such as `after_fill`, `after_doodads`, `keep_out`, `doodad_keep_outs`) |
| `tests/suites/test_<type>.gd` | its tests |

`Enemy` (`scripts/enemies/enemy.gd`) declares properties (`immune_to_weapons`, `is_host`,
`claw_immune`, `stompable`, `dash_kills`, `is_boss`, `is_obstacle`, `is_swarm`, `max_health`,
`score_value`) and provides `add_hitbox(part, size, offset, attack)`, `add_lane_blocker(size, offset)`,
`take_damage()`, `defeat(cause)`, `retire()`. Subclasses override `_build()` (visuals, hitboxes,
properties), `_tick(delta)` (behaviour), and optionally `_on_defeated`, `should_retire`, `aim_point`,
`hit_radius`. A layout entry is `{type, at, lane, side, seed, params}`; `rng` is seeded from it, so
every attempt at a seed plays out the same way. **Weapons hit hosts** (task H8; GDD §9.7, owner,
October 8, 2026, replacing the September 26 rule that made `is_host` also set `immune_to_weapons`): `is_host`
is a declared property of its own, so auto-fire targets a host like any other cyborg (`targetable()`), shots
and splash hurt it, it shows a health bar and laser tier 1 takes a cyborg's shots to kill it; a fence
generator still declares `immune_to_weapons` (GDD §9.1). Killing a host by any means releases its Bad Dream
(`Cyborg._release_bad_dream`); a stomp, the claws or the dash also earn the host bonus, a weapon kill only the
kill's score (`Cyborg.host_bonus_for`, `CyborgTuning.weapon_host_bonus`, DESIGN-TBD, `docs/OPEN_QUESTIONS.md` item 628).
A player who doesn't want Bad Dreams released switches the weapon off in the shop (the equip toggle, GDD §8).
Every attack needs a visual **and** audio warning before it can hurt (CLAUDE.md readability rules).
**Enemy charge contacts** (owner revision, October 3, 2026): Octodog and Buzz Overdrive active charges
use one shared swept-box contact helper on `Enemy`, against live physical enemy hitboxes rather than
lane labels or detached attack effects. Each victim is hit at most once per charge through
`take_damage(..., &"enemy_charge")`; bosses and weapon-immune enemies retain their immunity, and hosts
are never a charge's victims although weapons hit them (`Enemy.charge_can_hurt`, DESIGN-TBD,
`docs/OPEN_QUESTIONS.md` item 629).
`EnemyDirector.enemy_defeated` still drives lifecycle/effects, but `ScoreKeeper` ignores that cause:
no player kill count, bonus or thief jackpot/recovery is awarded for an NPC collision. The one exception
is an enemy that declares `charge_bait` (task C6, the Enforcer Truck, GDD §9.13): weapon-immune, it is
still hurt by a charge's contact (`take_damage` lets `&"enemy_charge"` through, `_hurt_charge_contacts`
keeps it as a victim), and `ScoreKeeper` counts that defeat as the player's kill (a bait), with its score.
Hosts and fence generators don't declare it, so charges pass them by as before (`charge_can_hurt`).
**Readied with the level** (task PERF1): `EnemyDirector.warm_up()` (from `setup()`, during the load) loads
the script and tuning of every type the layout names, and for a type whose script has a static
`warm_up(world: RunWorld, entry: Dictionary) -> Node` builds one look of each kind (type, skin, host:
`warm_key()`; a zone's skin counts by its resource, since the Golden Zone and the Golden Palace share a zone
look but not their statue kits) and frees it, once a process: what a type's first spawn used to do in its
own frame (compiling its scripts and building the meshes, materials and shaders its kind shares; up to
290 ms for a cyborg). It keeps the look's materials for the process (`ShaderWarmup.materials_of()`): the
engine frees a standard material's shader with the last material using it and generates and compiles it
again for the next, so a kind that makes its own material at each spawn (a Gilded Sentinel's eyes) paid
about 1 ms (and a compile on a real renderer) at every spawn with none of its kind left. The hook builds
the visual model only (never a physics object: see Smooth frames), as `entry`'s would be, outside the tree,
with every part the enemy may show later
(a muzzle's charge, a lunge line, a wave), since `ShaderWarmup` draws the same looks once during the load
(`warm_looks()`, A run). A type whose enemies bring others into play names them with a static
`brings(entry: Dictionary) -> Array[Dictionary]` (a host cyborg's Bad Dream). The cyborg, window cyborg,
screech, Octodog, Resonator, Barnacle Turret, Bad Dream, fence generator, Buzz Overdrive, Gilded Sentinel
(its statue's frames for both walls, its eyes, its cut marks' shader), Enforcer Truck (its model with
every rider, its light bar's and floor lights' states, its warning line) and hover truck (its model, the glows
its parts swap in, the wall effects, its warning glow: task I5) have hooks, and a boss fight names the
enemies it brings itself with `BossEncounter.warm_enemies()` (the Floating Head's dropped cyborgs, the Sleep
Taker's generators); a new enemy whose first spawn builds anything costly adds one, and a kit keeps the
shaders it loads (a static cache, as the kits do) rather than loading them per spawn (`test_perf` checks
every hooked kind is readied and nothing of it stays).
Enemy fire uses the pool's red "enemy_*" looks in every zone. `world.skin.enemy_variant` picks the
zone look: the cyborgs (window cyborgs and hosts too) dress in the zone variant
`CyborgSuit.look_for()` finds for it (see Zone skins for each zone's value, and Characters), and the
other enemies weather by it (`&"scavenger"` weathered, any other value the clean `&"city"` look).
**Drawn size** (GDD §9.2, "Drawn 20% bigger", owner, October 14, 2026; tasks I2, J1): `ZoneSkin.cyborg_draw_scale`
(`CyborgSuit.draw_scale(skin)`; 1.2 in every zone skin in `data/skins/` and every boss-arena skin in `data/bosses/`
(the Floating Head's dropped cyborgs, the Board's guards), the class default 1.0 for a skin made in code, DESIGN-TBD:
item 829) scales the cyborgs' model only, never a hitbox: the floor cyborgs (the panic variant and
the hosts too, the same model) set it as `body.scale`, so they stay standing on the floor (the body's origin is its
soles); a window cyborg multiplies it into its own `BODY_SCALE` (1.25) and places the body so its waist stays where it
was (the legs are hidden: it grows up and out of the same place, its head reaching the window frame's top). Every
hitbox, the gun's muzzle point (`CyborgGun.muzzle_offset`, `muzzle_reach`: the bolts start where they did even
though the drawn cannon sits a little higher and further out) and the floor-use spans are unchanged;
`test_cyborg_body` (`_test_draw_scale`) pins all of it. Not scaled: the hover truck's driver and
cinematic cyborgs (`CineActorNode`), which build `CyborgBody` themselves. It is read once at spawn, so a change shows
on the next run (it isn't in the F6 panel, which lists tuning resources rather than skins).

A level uses an enemy only if its `features` list has the type's name (GDD §6: one new thing at a
time), from the feature's start if the level gives it one (The generator). Quick play can add
features: `./play.sh --features=cyborg,drone`. The campaign already lists the enemies still to be
built under the names their tasks must use (`LevelConfig.PLANNED_FEATURES`: `barnacle_turret`,
`resonator`), so a new enemy's own files are all it takes to bring it into its levels.

Built so far: cyborg (with its panic variant and hosts), window cyborg, fence generator, hover
truck, Octodog, sewer screech (manholes, and wall vents; `screech_vents` is wall vents only, for zones
whose floor has no manholes; its body, `ScreechModel`, also comes at a lower detail for crowds,
`crowd_mesh()`, the same parts and colours in about a third of the triangles: the Sewer Swarm's),
heli drone, the Cyborg's Bad Dream (released by a killed host, spawned by the director at run
time rather than placed by the generator; one that bursts out further ahead than its hover spot, its host
shot down, lurks over that spot, harmless, its maw closed once risen (an open maw belongs to a slash's
warning) and holding no attack back (an EMP dissolves it where it hangs), until the runner is within
`hover_ahead`, and only then begins its chase, so every chase begins where the host rules plan it, at its
host's spot: task H8, DESIGN-TBD, `docs/OPEN_QUESTIONS.md` item 630; it slashes a runner on a ceiling too, task K1,
below), the Resonator (GDD §9.10, the Golden Zone: a golden
broadcast spire hovering far ahead whose red waves roll along the floor across every lane; its model,
`resonator_model.gd`, is built in code, and `resonator_rules.gd` plans each pulse where its wave meets
the player on clear floor), the Barnacle Turret (GDD §9.8, from Marketplace 1: a ceiling enemy, see
below), the Buzz Overdrive (GDD §9.9, from Corporate 1: a buzzsaw tank that cuts its lane's floor into
a gap, see below), the Tithe Collector (GDD §9.12, from Corporate 2, skipping the Dead Zone, back in
the Golden Zone: see Thefts above), the Gilded Sentinels (GDD §9.11, from Golden 2: live statues in
wall niches whose halberd cuts their wall section and the outer lane, see below), the Enforcer Truck
(GDD §9.13, from Corporate 2: an armoured truck chasing the runner from behind that only other enemies'
charges, a floor cut or a too-wide gap destroy, see below), and the Cybernetic Centipede (GDD §9.15, the Terminal's
only enemy: it waits in the debris maze's cells, chases along its open paths and takes two dashes; its placements
proven escapable, `enemy-centipede.md`).
`scripts/enemies/mesh_batch.gd` merges an enemy's low-poly parts into one mesh per material to keep draw
calls down.

**Big attacks take turns through the director** (GDD §9, decided September 26, 2026). The big attacks
of different enemy types never overlap, so the player never has to dodge two at once. The owner may
revert this after playtesting, so it sits behind one switch, `GameRules.big_attacks_take_turns` (on by
default, in the F6 panel); switched off, the game plays exactly as before the rule. The big attacks
(DESIGN-TBD, `docs/questions/r3.md`): the Octodog's charge sequence (its first wind-up until it gives
up), the drone's wind-up and barrage, the hover truck's rev and forward lurch and its cannon's charge
and volley, the Bad Dream's chase, the Resonator's pulse (its warning until its last wave has passed
the player; DESIGN-TBD, `docs/questions/c3.md`), the Buzz Overdrive's rev and charge (its warning
until it has passed the player and gone; it never waits, so it claims its turn a moment before and lets
the runner pass if another's is still on, below; DESIGN-TBD, `docs/questions/fix2.md`), a Gilded Sentinel's attack (its
eyes' flare until its last swing is over; it can't wait either, so it claims its turn a moment before
and lets the runner pass if another's is still on, below; DESIGN-TBD, `docs/questions/c4.md`), and an
Enforcer Truck's volley (its warning until its last bolt has passed the runner; GDD §9.13, proposed) and its showing
(from the moment it pulls up beside the runner until it has dropped back out of view; task C6b). Small attacks (a cyborg's burst, a window
cyborg's shot, a Barnacle Turret's burst, a screech's swipe) and the hover truck's entrance don't take
part (the cyborg-type guns share an airspace of their own instead: The cyborgs' airspace, below). An
enemy takes part like this, opting in for whichever of its attacks count as big:
- **Report it.** `is_major_attack_active()` is true from the start of the attack's warning until its
  last hazard is over (the lunge has passed, the lurch has ended). Each shot fired in it goes to
  `world.director.note_attack_shot(self, shot)` (the Projectile `fire_enemy()` returned): the attack's
  turn lasts until the shot is behind the player (`EnemyDirector.SHOT_PASS_MARGIN`) or gone. The
  director watches where the shot really is, so a change in the player's speed (a dash ending) can't
  cut the turn short.
- **Ask before the warning, never after it.** Just before the warning would start, once everything
  else about the attack is ready (its own spacing, its target, a clear stretch), the enemy asks
  `world.director.major_attack_blocked(self)`, and while the answer is true it doesn't start, asks
  again next frame, and goes on as it was: the drone keeps following, the truck holds back or keeps
  pacing, the Octodog paces in position. Asking only when ready matters: the director queues those
  held. Once a warning has started the attack runs its course; nothing stops it for another's turn.
- **Keep asking to keep your place; give up out loud.** A waiting enemy keeps its place in the queue
  until its attack starts, as long as it keeps asking: through its turn too (told it may go, one that
  isn't quite ready and asks again still goes before those that waited less), and through a gap in
  its asks (its stretch not clear for a moment, its planned point not reached yet) of up to
  `GameRules.turn_place_grace` (1 s; DESIGN-TBD, `docs/questions/r3b.md`); meanwhile those behind
  it wait. After a longer gap it loses its place, so the others don't wait long for an enemy that
  isn't ready (a Resonator waiting for clear floor): an enemy that means to wait longer keeps asking
  (the Octodog, below). An enemy that gives up the attack it waited for calls
  `world.director.give_up_turn(self)` and leaves the queue at once: the Octodog runs off, the hover
  truck changes state (it asks only while pacing, for its cannon, or holding back, for its lurch), the
  Resonator leaves, the Bad Dream dissolves. One that leaves play loses its place at once.
- **An attack that may only come within a window** (the Octodog's planned charges) moves the window
  on while `held_for_turn(self)` says it's waiting for another type, up to a limit of its own
  (`OctodogTuning.turn_wait_max`), and keeps every fairness rule it was planned with. The Octodog also
  waits so for another Octodog (`Octodog._another_dog_charging`: while another dog's charges are on, its
  own first wind-up is held as for another type's turn, whether or not big attacks take turns, as drones fire one
  barrage at a time; task Q5, a dog let out of an Octodog jar can come out late; DESIGN-TBD,
  `docs/questions/q5.md` 8). Once held it
  keeps asking every frame until its turn comes, whether or not its stretch is clear by then, and if
  the wait made it miss its planned stretch, the window keeps moving on until the stretch ahead is
  clear again (within the same limit), so waiting for its turn never costs it its charges. After
  that it still asks every frame while its `charge_slack` lasts, so all along it keeps its place: another
  type ready again waits for it rather than go first again, until it charges or runs off. The
  Resonator's planned pulses do the same: a pulse held for another type's turn, or for clear floor
  where its wave would meet the player, moves the rest of its visit on; after
  `ResonatorTuning.turn_wait_max` spent waiting for other attacks (waiting for clear floor doesn't
  count) it drops its remaining pulses and leaves, never before its first. A first pulse still owed keeps
  its place once it has waited `first_pulse_wait_max` (waiting for either; 0, at once): it also asks while
  it waits for clear floor (`Resonator._first_overdue`), so another type ready again waits for it and it
  pulses at the next clear floor (FIX4: before, it lost its place at every floor wait; on Golden 2 at 6
  lanes a long Bad Dream chase over a visit's planned pulses, then a drone that stays, took every turn the
  dense floor left it for 55 s, until the next Resonator's arrival sent it away without a pulse. Task N1:
  the threshold was `turn_wait_max`, 8 s, and on Golden 1 at 5 lanes a drone that stays took the turn in
  every stretch of clear floor a visit had before then, so it left without a pulse; DESIGN-TBD, item 350).
- **An attack that can't wait** because the player sets it off (the Bad Dream bursts out of a killed
  host, its chase begun by the runner; one shot down ahead lurks first, reporting nothing) or the generator
  planned its moment still reports itself: the others wait for it. It can
  overlap an attack that was already on when it came; the Bad Dream holds its slash until that one
  is over. A planned floor cut (B4's stand-in, C2's Buzz Overdrive) reports itself from its warning
  until its charge ends; the generator keeps every other enemy's planned stretch off its attack window
  (Floor cuts, under The generator), but not the attacks enemies time themselves at run time (a drone's
  barrage, a hover truck's lurch or cannon shot, a pulse or a charge moved on): one that asked a moment
  before the cut's warning, when nothing was on yet, went, and the warning then started on top of it.
  So an attack that can't wait claims its turn a moment before its warning and lets the runner pass if
  one begun before its claim is still on then: the Gilded Sentinel (C4) and the Buzz Overdrive (task
  FIX2, below; the stand-in cut, a review tool, doesn't).

The director holds a big attack while another type's is on or its shots are still on their way; an
enemy whose own attack is on carries on (the Bad Dream's next slash in its chase); and the enemies of
different types waiting go in the order their waits began (then the one spawned first), whether or not
they're asking at that moment, so none is kept from its turn by others that keep asking: one that
began waiting later never goes first. An attack that is on never waits for another (the Bad Dream
holds a slash within its chase only for an attack that was already on when the chase began, and that
one doesn't wait), and in the queue a waiting enemy is only ever held by those ahead of it, so two
enemies can't wait on each other; the one at the head starts, gives up, or loses its place a grace
after it stops asking (asking while it isn't ready holds the others back: only the Octodog does that,
and only until it charges or runs off, `turn_wait_max` plus its `charge_slack` at most), so nothing
waits for ever.
Types space their own attacks themselves (one drone barrage at a time; one Octodog, one hover truck at
a time). GDD §9.7's rule holds with the switch off as well: an `exclusive_major_attack` (the Bad
Dream's chase) and the attacks of the types in its `exclusive_of` (Octodogs', drones') never overlap. `is_waiting()` and `turn_wait()` say whether and
how long an enemy has been waiting (from its first held ask until its attack starts or it loses its
place). `tools/measure/big_attacks.gd` measures the overlaps, the delays and the enemies that never got
a big attack in over the campaign (Review tools); `tests/helpers/turn_dummy.gd` is a scripted big
attack for tests (with pauses in its asks and stalls when it may go).

**The cyborgs' airspace** (GDD §9.2, owner, October 8, 2026: up to two cyborg-type bursts in the air at
once; the build had allowed one, which looked unnatural). The cyborg-type guns (`CyborgGun`: cyborgs,
window cyborgs, Barnacle Turrets) share one `CyborgAirspace` (`scripts/enemies/cyborg_airspace.gd`) per
world, in the RunWorld's metadata, so every attempt starts with it empty:
- **Claims.** A burst claims its place from the start of its charge-up until `burst_gap` after its last
  bolt, and a gun starts one only while fewer than `GameRules.max_bursts_in_air` claims are on (2, in
  the F6 panel; 1 brings back one at a time) and no boss holds the whole airspace (`may_start`). Each
  claim is its shooter's own: a release (a cancelled charge-up, `CyborgGun.stop`) ends that shooter's
  claim and no other, and a shooter that has left play (defeated, retired or freed) holds none.
- **A boss's claim.** The Floating Head's eye lasers claim the whole airspace (`claim_whole`): no burst
  starts during a laser attack, and a laser attack only starts once no burst is on (`claimed_until`).
- **The crossfire rule** (DESIGN-TBD, `docs/OPEN_QUESTIONS.md` item 600). The airspace also keeps each burst's
  start, its arrivals (predicted, then each bolt's own) and, once its aim locks, the line its bolts fly
  along and the surface the runner was on, until a while after they've arrived (`near`). Bursts whose
  bolts arrive within `CyborgGunTuning.crossfire_gap` (0.5 s) of each other must leave the runner a way
  out: a place one move away that none of them is aimed at (`CyborgGun.way_out`). The places
  (`_here`, `_moves`) are lanes and walls: from a floor or ceiling lane the lanes beside it, from a wall
  only the outer lane below; a lane a lane blocker holds from the runner to past the bolts (a hover truck
  alongside, a boss's prop: what bumps a lane switch back; zone doodads don't count, `path_clear` keeps
  them off the bolts' arrival) is none, nor one the gun's `lane_rule` rules out (a Barnacle Turret's keeps
  a rider within its ceiling and out of a turret's lane, as its `_path_fair` does). A burst is aimed
  (`aims_at`) at the places on the surface it was aimed at within half a lane of its line, or at its wall:
  bolts at a wall runner pass wide of the lane below, a floor runner's under a wall runner. Wild fire
  (the panic variant) never arrives that close to another burst. A burst that would leave no way out
  waits **before** its telegraph (task R3's rule for a waiting attack): as it would start its charge-up,
  wherever the runner may be by its lock (where they are or one move away, a wall they could step onto
  included) must leave a way out, with bursts already aimed counted along their lines and one still
  charging that began more than `reaction_time` (0.25 s) ago taken as aimed where the runner is now (the
  runner may dodge it first); one that began since will lock where this one does. That start check
  counts bursts `START_MARGIN` further apart than the gap, for predictions a little off by the lock. The
  same check as its aim locks, with only bursts already aimed counted, is a last resort that calls the
  charge-up off (`_cancel(&"crossfire")`); a runner who moves while two charge-ups that began together end
  can bring it about. The cost: on three lanes a second burst begun well after the first waits while the
  runner is in the middle lane or in an outer lane beside a wall they could step onto; on five or six
  lanes it waits only one lane in from an edge or beside a wall. The cyborgs' `burst_gap`,
  `crossfire_gap` and `reaction_time` are per type; a check uses the asking gun's.

**Pace** (GDD §3, owner's playtest September 30, 2026: the runner rises from about 21 m/s in the
Neon City to about 25 m/s in the Golden Zone, and enemies and their attacks speed up to match, never
with shorter warnings). An enemy that stands or moves in the world's frame gives its distances along
the track and its speeds at `MovementTuning.REFERENCE_SPEED` (18 m/s) and stretches them by the level's
pace (`world.tuning.pace()`; its rules by `LevelGenerator.pace`): in a faster zone it moves, lunges and
fires faster from further out, and every wind-up, flight and dodge takes the seconds it took at 18 m/s.
So far: the cyborgs' gun (engage distance, bolt speed, the clear path around an impact, `CyborgGun.pace`)
and their walk, flight and margin; the Octodog (its tuning's helpers take the pace: the lunge's start
and speed, the sprint, the run's margins, `charge_slack`, `appear_distance`); the Resonator (its
easing in and its margins; it hovers `hover_ahead` ahead at every pace, within laser tier 1's reach, so
the runner closes in on its waves as fast as at 18 m/s instead: they roll slower along the floor and take
as long to arrive, `ResonatorTuning.wave_speed_at`); the screech's dash; and every floor enemy's reach
(`LevelGenerator.enemy_floor_span` takes the pace; `CeilingZones.pace`). Warnings, charge-ups and wind-ups are seconds and stay what they
were. Enemies that move with the player (the drone, the hover truck once it's out, the Bad Dream) fire in
the player's frame, so nothing of theirs depends on the run speed. Boss fights run at their zone's speed
too (E1f), so the enemies a boss brings in follow its pace like a level's. What made the enemies livelier is data: less idle time between attacks (reloads, follow and
pacing times, cannon intervals, rests; DESIGN-TBD, `docs/questions/g1.md`). A new enemy whose distances
set a warning or a dodge window follows the pace the same way.

**Floor use.** The floor under a ceiling may hold enemies (GDD §3, changed September 26, 2026), but
a ceiling's landing zone and the spot of each of its pads keep off the floor enemies use (see
Ceilings under The generator). A type's tuning says whether it uses the floor (`uses_floor`: false
for fliers like drones and hover trucks, wall-only enemies like window cyborgs, and the Barnacle Turret,
which hangs from a ceiling) and how much of
it around its spot (`floor_reach_before`/`_after`: where it stands, moves and attacks a player in its
lane; the screech's 30 m before covers where it springs out). Rules that plan a longer run for one
enemy store it in `params.floor_span` (the Octodog's charges). An enemy that only ever drives behind the
runner (`behind_runner`: the Enforcer Truck) uses no floor ahead, and its entry's `at` is where it
arrives, not a spot it takes: `Octodog.charge_clear` leaves such entries out when a wait has moved a
dog's charges on. `LevelGenerator.enemy_floor_span(entry)`
and `enemy_uses_floor(entry)` read all of this; `CeilingZones`, `floor_clear` and `add_hull_with_pad`
respect it. An enemy that can't reach the ceiling stays consistent with it at run time: cyborgs, window
cyborgs and hover trucks hold fire at a player riding a ceiling, the drone waits below, the Octodog never
winds up and a screech stays in its manhole. The Bad Dream no longer waits (owner, task K1: it can hit a ceiling
rider; see the Bad Dream's ceiling slash below).

**The Bad Dream's ceiling slash** (task K1; owner, October 2026, replacing GDD §9.7's "cannot reach the ship's
hull"; DESIGN-TBD, `docs/questions/k1.md`). A runner on a ceiling is slashed like one on the floor, in `bad_dream.gd`
and `BadDreamTuning`'s "Slashing a ceiling rider" group (`data/enemies/bad_dream.tres`): the same telegraph (shriek,
maw, the covered lanes lit red, here on the underside by `_show_marks`, only where the ceiling is; the dream rears up
to `_rear_y()`, its head `hull_clearance` under the hull, arms up: the model's `swing_down` is 0), the same
`band_for()` lanes (the rider's and one either side, clamped at the street's edges) and lunge. `_start_telegraph`
locks the surface: a ceiling slash's box (`slash_box_for(band, ceiling_y)`) hangs `ceiling_slash_reach` (1.75 m, so a
jump away from the ceiling is still hit, as a floor jump is) from the rider's `Player.ceiling_y` with `side_margin` at
every edge, and stays there whatever the player does meanwhile, so a runner who drops or flips out of it is safe.
Fairness (`_may_slash`, `_escape_open`): only a rider who has been up `ceiling_settle_time` (the flight from the pad
takes about 0.4 s); only under a ceiling that lasts over their lane until the claws have passed (`_ceiling_holds`:
`_hull_lasts` reads `LevelLayout.hull_at` along the way, `_return_pad_in` the `return_pads`; falling off an end or a
return pad's drop would pass through claws hanging from the underside); and only when a lane outside the band is left
to move to (`_ceiling_lane_open`): the ceiling over every lane from theirs, now and as they arrive
(`LevelLayout.under_hull`) and over that lane until the strike (`_strike_reach`), no return pad dropping them there,
no enemy's body in it (`_body_in_lane`: a physics query on the hazard layer for a hitbox with an `enemy`, a Barnacle
Turret's, from a little behind the rider to the strike) and no solid side. A ceiling has no wall to run to (Player: no
way from the ceiling onto a wall) and nothing drops a rider at will; where the three-lane band would cover every
ceiling lane (the middle lane of a 3-lane street, a ceiling three lanes wide), `_narrowed_ceiling_band` locks two
lanes, the rider's and one side's (random, one whose way out is open), or on a two-lane ceiling the rider's alone
(DESIGN-TBD, `docs/questions/k1.md` 1); a one-lane ceiling, or one whose other lanes are shut, is a refuge: the dream
just floats (maw shut, head tipped back). The floor and wall slashes, the generator (pads, host rules) and the Sleep
Taker's slash (its own `SleepTakerSlash`; it shares only `BadDreamModel`'s lane marks and streaks) are as they were.
`test_bad_dream` covers the box, the warning, the dodge (a jump doesn't), the narrowed bands and the middle lane's
hit and dodge, ceilings and turrets that shut the way out, and a ceiling that ends or a return pad that comes too soon.

**Dash walls** (task H7a; GDD §9.14: a building across every floor lane, which the runner breaks as they
reach it). Every enemy that holds an attack by a zone doodad holds it by a wall (`LevelLayout.doodad_between`
counts the walls in every lane, broken or not, so the same on every attempt): the cyborgs' guns
(`CyborgGun.path_clear`), the Octodog's charge, the Resonator's pulses, the drone's barrage, the hover truck's
cannon and the Enforcer Truck's volleys (their escape). What moves ahead of the runner deals with a standing
wall in its way (DESIGN-TBD, `docs/OPEN_QUESTIONS.md` items 648 and 654–656):
- **the hover truck gives way** (`HoverTruck._wall_ahead`): a standing wall coming within the time it needs to
  drop behind the runner (`HoverTruckTuning.give_way_seconds` from its offset, `WALL_GIVE_WAY_MARGIN` more)
  sends it from pacing or from alongside into its lurch back, and it holds back, revving for no forward lurch
  (`_attack_seconds`), until the runner has broken the wall, then follows them through; where it can't drop
  back (the runner in its lane behind it, ridden, leaving ahead) its nose bursts through a standing wall it
  reaches (`_burst_dash_walls`: broken by `hover_truck`, the crumble and its crash; one whose chunk isn't built
  is marked broken in the layout). So the runner meets every wall first, and the generator keeps walls off the
  truck's entrance only;
- **flyers rise over it** (`Enemy.dash_wall_lift(at, half_length, from_height, closing_speed)`: the wall's top
  plus `DASH_WALL_CLEARANCE` from when a climb at `DASH_WALL_CLIMB_SPEED` must start until the body is past the
  wall's back; 0 with no standing wall in its way): the heli drone in every state (`lift`, added to its height;
  its wind-up never starts while a wall is within its barrage's reach or its climb), the Resonator (pulling away,
  or resting at its spot past one) and a fleeing Tithe Collector;
- **ground enemies running off ahead leave play at its face** (`Enemy.dash_wall_reached(front)`: a standing wall's
  face between the runner and the enemy's front): an Octodog running off ahead or pacing the runner
  (`Octodog.should_retire`, giving up its turn) and a Buzz Overdrive speeding off after letting the runner pass
  (`BuzzOverdrive._tick`: gone);
- **a panic cyborg's run stops short of its clear approach** (`CyborgRules.obstacle_spans` holds every wall's
  footprint, `DashWallTuning.footprint`; `CyborgRules.limits`, which the Cyborg's `_compute_limits` uses): it never
  runs through a standing wall nor cowers in the clear stretch behind it, and one past a wall never walks back
  into that stretch;
- the Enforcer Truck drives behind the runner, so it only ever meets a wall already broken; when it shows itself
  (C6b) it pulls up beside the runner, its front ahead of them, so the generator keeps every wall off its planned
  showing windows (its rules' calm stretches, which `DashWallRules` counts with the rules' keep-outs) and in play
  it never shows itself where its view would reach a wall (`EnforcerTruckRoom`: a wall is solid in every lane).
