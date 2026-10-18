# Build brief: the Centurion outfit, the fourth cosmetic

**Decision source:** GDD §8, "Cosmetics" (owner, October 18, 2026).
**Reference:** `docs/art/reference/outfit_centurion.webp` (side, front and back views).
**Shop:** meant to be the prize for **winning the weekly seed** (not designed yet). Until then it is sold for
5,000 credits, after Beach Master in the shop's Cosmetics section.

## Goal
A gold-and-crimson, Roman-style outfit that Razor Echo wears instead of his trench coat. **The runner stays Razor
Echo.** The same looks-only rules as the Rex outfit apply (`docs/art/BRIEF_OUTFIT_REX.md`, Goal): the shared rig,
poses, animation, scale, hitbox and gameplay sizes stay the same, and owned power-ups are still added on top.

## Keep from the sheet
- **Long crimson and black trench coat** trimmed in gold, with a high collar and gold-edged panels.
- **Gold sculpted cuirass** with an emblem on the chest, over a dark shirt.
- **Lion-head gold pauldrons** with layered scale plates, on both shoulders.
- A crimson sash and belt with **gold-tipped leather strips** (pteruges) hanging over the hips.
- **Sleek ornate gold cyber-arm** on the left, from the shoulder down, with crimson accents at the joints. It
  replaces Echo's gold arm while the outfit is worn.
- Gold bracers and fingerless gloves.
- Black pants with **gold knee plates and greaves**, and **gold-plated armoured boots.**
- **The gold skull and laurel** across the coat's back: large enough to read from behind.

## Keep from Echo *(proposed)*
- His head: face, scars, spiky black hair and his copper ocular implant (the sheet's eyepiece is his).

## Leave out
- **The ceremonial katana** and its sheath, and **the heavy pistol.** No outfit carries a weapon.
- *(Proposed)* **The dagger** at the hip: a weapon too.

## Colour rules
- **Colours as drawn.** Outfits are free of the colour rule (owner, October 18, 2026; GDD §8, Cosmetics): the gold
  and crimson stay, even where they're close to the Golden Zone's or the cult's gold.
- Keep the gold a polished metal, not emissive, so bloom doesn't wash the armour's shapes out.

## Readability (the gameplay camera sits behind and above)
- **The back view matters most:** the coat's skull and laurel, the pauldrons and the gold left arm.
- **The armor power-up must still read on top.** This outfit already wears gold plates on the shoulders and chest,
  where the armor power-up's plates go (`docs/art/BRIEF_RAZOR_ECHO.md`, Power-up looks). The player must still see
  at a glance whether their armor is up and when it shatters. If the two look alike, note it in the summary for
  the owner, with frames of both.
- **The coat in motion:** build the long skirt as a few stiff panels hinged at the waist, like Echo's
  (`docs/art/BRIEF_RAZOR_ECHO.md`, The coat in motion); the pteruges can swing a little on their own.
- Check every zone skin with rendered frames on Forward+ and the Compatibility renderer.

## Done when
- The avatar showcase (`tools/showcase/avatar_showcase.tscn`) and the scripted run review
  (`tools/showcase/avatar_run_review.tscn`) can show the outfit in every pose and with every power-up.
- Rendered frames of both are captured on both renderers.
- The tests the per-task tier selects pass, including the avatar's vertex and draw budgets.
- The task summary lists what was verified and how, the `DESIGN-TBD` items, and the frames the owner should look at.
