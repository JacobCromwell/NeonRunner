# Build brief: the Rex outfit, the first cosmetic

**Decision source:** GDD §8, "Cosmetics" (owner, October 18, 2026).
**Reference:** `docs/art/reference/outfit_rex.webp` (front, back and side views, and a head close-up).
**Shop:** 3,000 credits, the first item in the shop's Cosmetics section (a separate request in `docs/USER_REQUESTS.md`).

## Goal
An outfit that Razor Echo wears instead of his trench coat. **The runner stays Razor Echo:** this is a set of
clothes and an arm, not a new character. It is a looks-only change on the shared humanoid rig, with the same poses,
animation, 75% player scale, hitbox and every gameplay size. Owned power-ups are still added on top and must still
read as added (`docs/art/BRIEF_RAZOR_ECHO.md`, Power-up looks).

## Keep from the sheet
- **Magenta leather biker jacket,** waist length: wide lapels, zips, a belted waist, slightly worn.
- **Glowing circuit lines** over the sleeves and shoulders, and a **glowing line down the spine** of the back.
- **Gunmetal and copper cybernetic left arm** from the shoulder down, with exposed copper pistons, an articulated
  hand and a **glowing joint at the shoulder.** It replaces Echo's gold arm while the outfit is worn.
- A dark tank top with a chain necklace, **fingerless gloves**, a utility belt with pouches and **thigh holsters**.
- **Dark, worn cargo pants** with knee straps, and **buckled combat boots** trimmed in magenta.

## Keep from Echo *(proposed)*
- His head: face, scars, spiky black hair and his copper ocular implant.

## Leave out
- **The rifle** slung across the back. No outfit carries a weapon: nothing on the runner may look like a power-up.
- **The words on the back patches.** Keep the patches as plain shapes *(proposed)*; words are too small to read.

## Colour rules
- **The glows stay as drawn** (owner, October 18, 2026): the circuit lines **pink/magenta**, the spine line **cyan**,
  the shoulder joint **orange**. This is an owner exception to the colour rule for this outfit only.
- Keep them soft, thin lines, so bloom doesn't turn them into blobs. The jacket itself is unlit magenta leather.
- Effects tied to the suit glow (the invulnerability tint, the death power-down, the dash trail) work on this outfit
  too: its glow lines go dark on death like Echo's conduits.

## Readability (the gameplay camera sits behind and above)
- **The back view matters most:** the jacket's magenta, the spine line and the left arm are what the player sees.
- Check every zone skin with rendered frames on Forward+ and the Compatibility renderer, and note in the summary any
  zone where the outfit is hard to tell apart from a nearby electric fence, for the owner to look at.

## Done when
- The avatar showcase (`tools/showcase/avatar_showcase.tscn`) and the scripted run review
  (`tools/showcase/avatar_run_review.tscn`) can show the outfit in every pose and with every power-up.
- Rendered frames of both are captured on both renderers.
- The tests the per-task tier selects pass, including the avatar's vertex and draw budgets.
- The task summary lists what was verified and how, the `DESIGN-TBD` items, and the frames the owner should look at.
