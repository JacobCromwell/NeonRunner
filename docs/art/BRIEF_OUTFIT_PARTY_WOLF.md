# Build brief: the Party Wolf outfit, the fifth cosmetic

**Decision source:** GDD §8, "Cosmetics" (owner, October 18, 2026).
**Reference:** `docs/art/reference/outfit_party_wolf.webp` (side, front and back views).
**Shop:** meant to reward **promoting the game** (inviting a friend, buying it for a friend, posting about it; not
designed yet). Until then it is sold for 5,000 credits, after Centurion in the shop's Cosmetics section.

## Goal
A neon rave outfit with a wolf mask that Razor Echo wears instead of his trench coat. **The runner stays Razor
Echo.** The same looks-only rules as the Rex outfit apply (`docs/art/BRIEF_OUTFIT_REX.md`, Goal): the shared rig,
poses, animation, scale, hitbox and gameplay sizes stay the same, and owned power-ups are still added on top.

## Keep from the sheet
- **Cyber wolf mask** over Echo's face: grey fur with neon purple and cyan markings, pointed ears, bared teeth and
  a **glowing pink eyepiece** over the left eye. Echo's spiky black hair shows behind it. This is the one outfit
  that covers his head.
- **Long purple coat covered in neon graffiti** (cyan, pink, green and yellow tags), with **grey faux-fur** collar
  and cuffs.
- On the coat's back: a **neon wolf in shades** across the shoulders, and **"PARTY WOLF"** sprayed across the lower
  back *(proposed: kept in words; it's large enough to read and it's the outfit's name)*.
- A dark T-shirt with a **glowing howling-wolf-and-moon print**, under a pink chest rig.
- **Glowing purple and cyan rave cyber-arm** on the left, from the shoulder down. It replaces Echo's gold arm while
  the outfit is worn.
- A studded belt with hanging **glow sticks** and a **grey wolf tail**; rave bracelets and fingerless gloves.
- Dark pants with graffiti, **glowing knee pads** and pink straps; **neon-laced combat boots.**

## Leave out
- **The neon katana** and its sheath, and **the pistol** at the hip. No outfit carries a weapon.

## Colour rules
- **Colours and glows as drawn.** Outfits are free of the colour rule (owner, October 18, 2026; GDD §8, Cosmetics).
- This is the most glowing outfit: keep the graffiti and trims thin and soft so bloom doesn't merge the back into
  one blur, and check it fits the avatar's draw budget (bake the graffiti into textures or vertex colours rather
  than separate meshes).
- Effects tied to the suit glow (the invulnerability tint, the death power-down, the dash trail) work on this outfit
  too: its glows go dark on death like Echo's conduits.

## Readability (the gameplay camera sits behind and above)
- **The back view matters most:** the neon wolf, "PARTY WOLF", the fur collar and the rave arm.
- **The coat in motion:** build the long skirt as a few stiff panels hinged at the waist, like Echo's
  (`docs/art/BRIEF_RAZOR_ECHO.md`, The coat in motion); the tail can swing a little on its own.
- Check every zone skin with rendered frames on Forward+ and the Compatibility renderer.

## Done when
- The avatar showcase (`tools/showcase/avatar_showcase.tscn`) and the scripted run review
  (`tools/showcase/avatar_run_review.tscn`) can show the outfit in every pose and with every power-up.
- Rendered frames of both are captured on both renderers.
- The tests the per-task tier selects pass, including the avatar's vertex and draw budgets.
- The task summary lists what was verified and how, the `DESIGN-TBD` items, and the frames the owner should look at.
