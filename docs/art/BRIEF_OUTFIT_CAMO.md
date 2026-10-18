# Build brief: the Camo outfit, the second cosmetic

**Decision source:** GDD §8, "Cosmetics" (owner, October 18, 2026).
**Reference:** `docs/art/reference/outfit_camo.webp` (side, front and back views).
**Shop:** 3,000 credits, after Rex in the shop's Cosmetics section.

## Goal
A military outfit that Razor Echo wears instead of his trench coat. **The runner stays Razor Echo.** The same
looks-only rules as the Rex outfit apply (`docs/art/BRIEF_OUTFIT_REX.md`, Goal): the shared rig, poses, animation,
scale, hitbox and gameplay sizes stay the same, and owned power-ups are still added on top and read as added.

## Keep from the sheet
- **Aged olive military trench coat,** long, with a high collar, epaulettes and a worn, stained hem. **Camo
  patches** on the coat, and **dark tubing** across the upper back.
- **Camo tactical plate carrier** with pouches over a dark shirt, a belt and harness straps.
- **Armoured brass militarized cyber-arm** on the left, from the shoulder down: a shoulder plate, forearm plates,
  exposed joints and an articulated hand. It replaces Echo's gold arm while the outfit is worn.
- Fingerless gloves, **dark camo cargo pants** with knee pads, and **tall laced combat boots**.

## Keep from Echo *(proposed)*
- His head: face, scars, spiky black hair and his copper ocular implant (the sheet's gold eyepiece is his).

## Leave out
- **The katana** and its sheath, and **the holstered pistol.** No outfit carries a weapon.
- *(Proposed)* **The grenades and the knife** on the plate carrier: they are weapons too.
- *(Proposed)* **The skull on the coat's lower back,** as on Echo's own coat: too small to appreciate.

## Colour rules
- *(Proposed)* Nothing glows except Echo's own copper implant. The coat, carrier and arm are unlit; keep the brass
  arm a dull, worn metal so it doesn't read as gold treasure or a power-up.
- Effects tied to the suit glow (the invulnerability tint, the death power-down, the dash trail) must still read on
  an outfit with no glow lines.

## Readability (the gameplay camera sits behind and above)
- **The back view matters most:** the long olive coat with its tubing and the brass left arm.
- **Watch for the dark olive coat on dark tracks** (the City's night roads, the Dead Zone's ash, Gangland). Add a
  subtle rim light if it vanishes.
- **The coat in motion:** build the long skirt as a few stiff panels hinged at the waist, like Echo's
  (`docs/art/BRIEF_RAZOR_ECHO.md`, The coat in motion).
- Check every zone skin with rendered frames on Forward+ and the Compatibility renderer.

## Done when
- The avatar showcase (`tools/showcase/avatar_showcase.tscn`) and the scripted run review
  (`tools/showcase/avatar_run_review.tscn`) can show the outfit in every pose and with every power-up.
- Rendered frames of both are captured on both renderers.
- The tests the per-task tier selects pass, including the avatar's vertex and draw budgets.
- The task summary lists what was verified and how, the `DESIGN-TBD` items, and the frames the owner should look at.
