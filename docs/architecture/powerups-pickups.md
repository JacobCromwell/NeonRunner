# Architecture: Power-ups and pickups

One part of the architecture notes; `docs/ARCHITECTURE.md` is the index of every part and topic.

## Power-ups

`PowerupController` (`scripts/powerups/powerup_controller.gd`) runs one `PowerupModule` per owned,
switched-on permanent item: `WeaponPowerup` (auto-fire, tiers 1–4, enemy health bars), `ClawsPowerup`,
`DashPowerup`, `MagnetPowerup` and `SlowTimePowerup`. The armor is the damage rules' (`DamageRules.Armor`,
see Damage and interactions); the breakables (shield, grapple) are charges on the Player. The
controller's header documents its API: `hud_state()` for the HUD (`charges` -1 for permanent items; the
armor's hits, with its return as `ready`), `equipment()` for the player model, and `try_dash()` /
`try_slow_time()`.
Dash has four permanent tiers: prices 1,800 / 800 / 1,000 / 1,200 credits in the shop catalog, with
cooldowns 8 / 6 / 4 / 3 seconds in the powerup tuning resource. Its module selects the owned tier
for both runtime readiness and the HUD. The dash also smashes the zone doodads it runs into (GDD §3,
owner, October 8, 2026; task H5): the Player does that (Damage and interactions, "The dash smashes a zone
doodad"), as it does the dash's speed. Existing tier-1 ownership and equip state need no save migration;
the generic shop advances sequentially and marks tier 4 maxed.
The player model shows what the run carries (`PlayerAvatar.set_equipment`, looks in `PlayerSuit`): the
weapon sits over the gold arm's (left) shoulder, so shots leave from there (`Player.weapon_muzzle()`),
and armor that breaks in play shatters. Effects tied to the runner's own glow (the dash's shell and
lines, the invulnerability tint) use its copper, thinned toward white; the shots keep their colours.

## Pickups

GDD §10 puts armor, shield and grapple pickups in boss fights (the standard armor rule, and fights
that offer their own), never in levels, so no pattern places one. `PickupField`
(`scripts/run/pickup_field.gd`, in every `RunWorld`) runs them; its numbers are in
`data/tuning/pickups.tres` (`PickupTuning`, F6).

- **Offers:** `offer(item, at, lane)` (a boss calls `BossEncounter.offer_pickup`) queues a pickup,
  which appears at the first fair spot, now or as soon as there is one: at least `lead_distance`
  ahead (within `search_window` beyond, on the built track), at most `reach_lanes` from the player's
  lane (nearer lanes first), with `clear_before` of floor before it and `clear_after` after it free of
  gaps, fences of any kind, pads, ramps, speed pads, ceilings overhead and enemies (planned on the
  track near the lane, or in play: any hitbox, fence, block or lane blocker up to `clear_height`), and
  no boss floor warning over it (`BossProps.warned`). `at` and `lane` are requests the rules still
  apply to. `find_spot()` and the static `layout_fair()` answer placement questions for tests.
- **Taking:** the player's hitbox (swept over the frame) reaching its `take_box()` takes it:
  `Player.gain_item(item, max_charges)` adds a shield or grapple charge unless the player holds all they
  may, the `Loadout` counts it in `picked_up` (the App asks `Loadout.costs_stock()` when an item breaks,
  so a picked-up charge, like a granted one, never costs stock), and `collected(pickup, gained)` fires.
  An armor pickup brings the armor back whole at once (`DamageRules.Armor.take_pickup`: on whole armor it
  adds a hit, up to `GameRules.armor_pickup_extra_hits`), and isn't counted: the armor is no stock. The
  HUD shows the item in its place among the protections and flashes it; the power-up controller lists
  it in `hud_state()` and the player model shows armor and shields. A pickup the player runs past is
  `missed` and gone. `clear()` removes everything (a boss beaten: none after the fight).
- **Look:** `Pickup` (`scripts/run/pickup.gd`, `pickup.gdshader`) is the HUD's round badge for the
  item standing upright at chest height: the item's icon white-hot on a dark disc in a white ring,
  with a halo and a floor glow, bobbing but never spinning, the same in every zone. Neutral whites keep
  it clear of every hazard colour; its size and icon keep it apart from credits. Sounds `pickup_appear`
  and `pickup`; a first-encounter hint per item (`pickup:<item>` in `data/hints/hints.json`). Pickups
  are pooled.
- **Review:** quick play's `--pickups[=armor,shield,grapple]` offers them in turn (debug builds).
