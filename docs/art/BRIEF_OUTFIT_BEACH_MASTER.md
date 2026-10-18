# Build brief: the Beach Master outfit, the third cosmetic

**Decision source:** GDD §8, "Cosmetics" (owner, October 18, 2026).
**Reference:** `docs/art/reference/outfit_beach_master.webp` (side, front and back views).
**Shop:** meant to be **won by completing challenges** (not designed yet). Until then it is sold for 5,000 credits,
after Camo in the shop's Cosmetics section.

## Goal
A beach outfit that Razor Echo wears instead of his trench coat. **The runner stays Razor Echo.** The same
looks-only rules as the Rex outfit apply (`docs/art/BRIEF_OUTFIT_REX.md`, Goal): the shared rig, poses, animation,
scale, hitbox and gameplay sizes stay the same, and owned power-ups are still added on top and read as added.

## Keep from the sheet
- **Open short-sleeved tropical shirt,** sleeves rolled: dark teal with **coral hibiscus and palm-leaf prints.**
- **Camo tactical plate carrier** with pouches over bare skin, a belt and harness straps.
- **Sea-salt corroded cyber-arm** on the left, from the shoulder down: rusty, patchy brass with green corrosion,
  bound in **worn cloth wraps**, with an articulated hand. It replaces Echo's gold arm while the outfit is worn.
- Fingerless gloves and a bead bracelet on the right wrist.
- **Dark cargo shorts** with knee pads, bare lower legs, and **strapped tactical sandals.**
- *(Proposed)* **The skull and palm-leaf print** across the shirt's back: it's large enough to read from behind,
  and it's the outfit's signature from the gameplay camera.

## Keep from Echo *(proposed)*
- His head: face, scars, spiky black hair and his copper ocular implant (the sheet's gold eyepiece is his).

## Leave out
- **The katana** and its sheath, and **the pistol** at the hip. No outfit carries a weapon.
- *(Proposed)* **The grenades and the knife** on the plate carrier: they are weapons too.

## Colour rules
- *(Proposed)* **The back print is printed, not glowing.** The sheet draws it glowing green, and green is a hazard
  colour; a muted green or teal print on the shirt keeps the design. The owner may still choose the glow, as for Rex.
- Nothing else glows except Echo's own copper implant. Keep the shirt's coral flowers matte so they don't read as
  red or orange hazard lights.
- Effects tied to the suit glow (the invulnerability tint, the death power-down, the dash trail) must still read on
  an outfit with no glow lines.

## Readability (the gameplay camera sits behind and above)
- **The back view matters most:** the shirt's back print, the corroded left arm and the bare legs.
- The shirt is short, so it needs none of the coat's hinged panels; let its open front and hem move a little.
- Check every zone skin with rendered frames on Forward+ and the Compatibility renderer.

## Done when
- The avatar showcase (`tools/showcase/avatar_showcase.tscn`) and the scripted run review
  (`tools/showcase/avatar_run_review.tscn`) can show the outfit in every pose and with every power-up.
- Rendered frames of both are captured on both renderers.
- The tests the per-task tier selects pass, including the avatar's vertex and draw budgets.
- The task summary lists what was verified and how, the `DESIGN-TBD` items, and the frames the owner should look at.
