# Build brief: Razor Echo, the player character

**Task ID:** P1 (for `docs/TASK_PLAN.md`). **Tier:** T2 (Opus 5.5; the owner runs T2 at max effort). **Size:** L.
**Decision source:** GDD §11, "Player character" (owner, September 26, 2026).
**Reference:** `docs/art/reference/player_echo.jpg` (front, side and back views).

## Goal
Rebuild the player's look to follow the owner's concept sheet. The runner is named **Razor Echo**. This replaces the current cyber suit and helmet (`scripts/player/player_suit.gd`), keeping the shared humanoid rig, the poses, the animation, the 75% player scale and every gameplay size (hitbox, jump height). This task changes looks only. Gameplay stays the same.

## Keep from the sheet
- **Weathered dark-blue trench coat,** knee to mid-calf length, with a high collar and turned-back lapels.
- **Glowing copper and brass conduits** running over the coat: along the sleeves, around the cuffs and shoulders, and a **distinctive pattern across the back**.
- **Gold/brass cybernetic left arm** from the shoulder down, with an articulated hand. The right hand wears a fingerless glove.
- **Cybernetic ocular implant over the left eye,** glowing in the copper family.
- **Tactical utility vest** over a dark shirt, with harness straps and belts.
- **Reinforced combat cargo pants,** knee pads, and **worn tactical boots.** The left shin has a mechanical leg brace.
- **Spiky black hair,** a scarred face, and no helmet.

## Leave out
- **The sword** and its scabbard. The game has no sword.
- **The holstered pistol.** The owner's rule: nothing on the character may look like a power-up, so there are no weapons on the base model at all.
- **The symbols on the coat's lower half:** the graffiti on the front and the skull emblem on the back. They'd be too small to appreciate.
- **The small cyan indicator lights on the vest.** Cyan is the anti-grav pads' colour. Any lights on the vest glow copper instead.

## Colour rules
- **The glow is copper and soft.** The conduits and the eye are the player's signature colour, replacing the old cyan. Keep them soft enough that bloom doesn't push them into the bright orange of gap edges.
- **Nothing else on the player glows in a hazard colour:** pink, yellow and black, red, bright orange or green.
- **The enemies' LED faces change from amber to cold white** (task P2), so the player and the enemies never share a glow colour.
- **Effects tied to the old suit glow follow the new copper:** the invulnerability tint, the death power-down (the conduits go dark), and any trail or dash effect. The player's shots keep their own colours (cyan, violet and white).

## Readability (the gameplay camera sits behind and above)
- **The back view matters most.** The coat's copper conduit pattern across the back, and the gold arm on the left, are what the player sees all game.
- **Watch for the dark coat on dark tracks.** A dark-blue coat can vanish on the City's night roads and the Dead Zone's ash, so the back conduits and a subtle rim light must carry it there.
- **Check every zone skin with rendered frames,** on Forward+ and on the Compatibility renderer (see `CLAUDE.md`, Commands). Where a skin isn't built yet, use the grey box.
- **The silhouette must stay clearly different from the enemy cyborgs,** whose whole head is an LED screen (task P2).

## The coat in motion
- Build the coat skirt as **a few stiff panels** hinged at the waist. They follow the thighs with a little lag and spring.
- Check it in every pose: run, jump, slide (the coat trails behind), wall run, ceiling (it hangs toward the feet in the player's frame), stomp, death.
- Clipping through the legs is acceptable only if it's brief and small. Stay within the avatar's vertex and draw budgets in `tests/suites/test_avatar.gd`.

## Power-up looks (redo them for the new design)
The current attachment sets in `scripts/player/player_suit.gd` (claws, armor, weapon tiers 1–4, magnet, shield bubble) are placeholders (OPEN_QUESTIONS §D, "How each power-up looks"). Rebuild each one to fit Razor Echo. Each must look **clearly added on top of** the base design, so a player never confuses the base look with an owned power-up.
- **Weapon line** *(proposed)*: unfolds from the shoulder of the **gold left arm**, and grows by tier. Keep the muzzle position API (`PlayerAvatar` muzzle helpers) and its floor, wall and ceiling tests working.
- **Claws** *(proposed)*: blades extending from the knuckles of both hands.
- **Armor** *(proposed)*: plates clipped over the coat's shoulders and chest. They shatter visibly when they break.
- **Shield:** the existing bubble.
- **Magnet** *(proposed)*: a coil on the back of the belt.

Mark anything the design doesn't settle as `DESIGN-TBD`, and put the questions in `docs/questions/p1.md`.

## Done when
- The avatar showcase (`tools/showcase/avatar_showcase.tscn`) and the scripted run review (`tools/showcase/avatar_run_review.tscn`) show Razor Echo in every pose and with every power-up.
- Rendered frames of both are captured on both renderers.
- `tools/godot.sh test` and `tools/godot.sh smoke` pass, including the avatar budget tests.
- The task summary lists what was verified and how, the `DESIGN-TBD` items, and the frames the owner should look at.
