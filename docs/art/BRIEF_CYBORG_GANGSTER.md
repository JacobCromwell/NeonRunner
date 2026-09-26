# Build brief: the ragged cyborg gangster (the new cyborg base model)

**Task ID:** P2 (for `docs/TASK_PLAN.md`). **Tier:** T2 (Opus 5.5; the owner runs T2 at max effort). **Size:** M–L.
**Decision source:** GDD §9.2, "Default look" (owner, September 26, 2026).
**Reference:** `docs/art/reference/cyborg_viewing_devices.jpg`. **Build Variant 1, the "Static TV Head" Infiltrator.** Variants 2 and 3 on the same sheet are for later zone variants, not this task.

## Goal
Replace the cyborgs' looks with **one ragged, strung-out gangster**. It is the **base model for every cyborg**: the normal and panic cyborgs, window cyborgs and hosts. It **replaces the sleek city citizen and the patched scavenger** in every zone, including the Neon City. Zone variants will be derived from this base later, from concept art the owner will supply. This task changes looks only: behaviour, timings and **hitboxes stay exactly as they are** (the body box and the stompable head box in `scripts/enemies/cyborg.gd`).

## The body (Variant 1)
**One body,** kept simple:
- A **worn leather vest over a hoodie,** with torn olive and khaki layers and frayed hems.
- **Patched cargo pants** and laced, scuffed boots.
- A **boxy backpack** with thick cables running up into the screen head.
- One **scavenged cyber arm**, which becomes the **arm cannon** (the cyborg's weapon, GDD §9.2). Use whichever arm the current code fires from.
- **Posture:** gaunt, hunched and twitchy. A jittery idle and a shambling walk fit "strung out". Keep the existing poses' timings and reach.

## The head is a screen
- **The entire head is a beat-up CRT television:** a boxy casing with a bezel, a dented frame, and the backpack cables plugged into the back. There's no hair, face or mask. That keeps it simple, and the expressions stay large and readable on small phone screens. The boxy top is also a clear stomp target.
- **The screen is the LED face.** Expressions carry over: normal, the panic variant's shocked "O", and the host's corrupted glitching. *(Proposed)* A defeated cyborg's screen flashes **ERR** before it goes dark, as on the sheet.
- **LED colour: cold white** (changed from amber), so enemies never share the player's copper glow. The sheet's cyan static and red "ERR" are recoloured to the game's rules below.

## Colour rules
- **Clothing:** grimy khaki, olive, brown and faded grey. Nothing on it glows.
- **Metal:** rusted steel and gunmetal, dull and unlit, on the base. The sheet's brass arm becomes rusted steel. Gold and brass may appear on zone variants **only as unlit ornament** (see "Zone variants"). **Nothing on a cyborg glows copper,** since that glow is Razor Echo's signature.
- **The only glows on a cyborg:**
  - the **white LED face**
  - the arm cannon's **charge-up in enemy-fire red** (unchanged)
  - on **hosts only**, **purple** glitch static on the screen, plus purple glowing veins along the neck and arms. Purple on a cyborg always and only means "host".
- **Nothing else** uses hazard colours (pink, yellow and black, orange, green) or the "safe" colours (cyan, green). The sheet's cyan screen glow becomes cold white; red on the screen is avoided, since red means enemy fire.

## Where it's used
- **`scripts/enemies/cyborg_suit.gd` and `cyborg_kit.gd`:** replace the `city` and `scavenger` looks with this base look. Keep `world.skin.enemy_variant` working, so zone variants can be added later as tweaks of this base.
- **Window cyborgs:** the same upper body in the window.
- **The Bad Dream** still bursts out of a host; its look is unchanged.

## Done when
- The enemy showcase (`tools/showcase/enemy_showcase.tscn`) shows the base cyborg, the panic face, a window cyborg and a host. Rendered frames are captured on Forward+ and the Compatibility renderer, including a far view at gameplay distance showing that the face expressions read.
- `tests/suites/test_cyborg.gd`, `test_cyborg_body.gd` and `test_window_cyborg.gd` pass, with hitboxes unchanged. The full `tools/godot.sh test` and `tools/godot.sh smoke` pass too.
- Questions go in `docs/questions/p2.md`.

## Running it alongside P1
Both tasks may need new part shapes in the shared humanoid rig (`scripts/characters/humanoid_*`). Run P1 and P2 one after the other, or have P2 leave the shared rig files untouched.

---

# Zone variants (task P3)

**Task ID:** P3. **Tier:** T2. **Size:** L. **Needs:** P2, since every variant is a tweak of the base. The zone skins don't need to exist yet: use `--skin=` and the grey box for checks.
**Decision source:** GDD §9.2, "Zone variants" (owner, September 26, 2026).

**They are the same unit,** and the owner approved these rules (September 26, 2026). Every variant has the same behaviour, timings, attacks, hitboxes, face expressions and colour rules as the base. A variant changes **only the look**: different enough that the player can tell it fits the zone, never so different that it reads as a new enemy. Variants are selected by `world.skin.enemy_variant`.

| Zone | Variant | Reference |
|---|---|---|
| 1. Neon City | **The base** (Static TV Head) | `cyborg_viewing_devices.jpg`, Variant 1 |
| 2. Gangland | **"Broadcast Brute" Enforcer:** a caged screen head with two small side monitors and an antenna; heavy, scavenged armour plates over a work jumpsuit | `cyborg_viewing_devices.jpg`, Variant 3 |
| 3. Marketplace | **"Casino Mob Enforcer":** a gilded screen head engraved with card suits; a pinstripe suit with gold trim; gold armour plates on the shoulders and knees; a backpack cabled into the head | `cyborg_casino_enforcer.jpg` |
| 4. Corporate | **"Wide-Aspect VR" Runner:** a wide VR headset visor as the screen (the lower face is hidden or covered); a sleek dark jacket; chrome hands; a tablet in the off hand | `cyborg_viewing_devices.jpg`, Variant 2 |
| 5. Dead Zone | **The base, burned out:** soot, ash and scorch marks, torn further, with a flickering screen. The art agent derives it from the base. | – |
| 6. Golden Zone | **Derived from the Casino Mob Enforcer by the art agent:** more opulent and ceremonial, in the zone's white, cream, red and gold, with the cult's Convergent Triad worn openly | `cyborg_casino_enforcer.jpg` |

## Rules for every variant
- **The screen is always the face.** It glows **cold white** and shows the shared expressions, the panic "O" and host purple. Zone-flavoured glyphs are welcome in cold white, for example dice and card suits on the Casino Mob Enforcer's screen.
- **Recolour the sheets' glows:** the cyan visor and trim, the orange X screens, and the red and orange dice all become cold white or unlit.
- **Gold and brass only as unlit ornament** (Casino Mob Enforcer, Golden Zone, the Brute's armour). Nothing glows copper.
- **One visible weapon, one attack.** The shot and its **red charge-up** look the same in every zone (hazard shapes and colours never change); only the weapon's model fits the zone:
  - Base and Dead Zone: the scavenged arm cannon.
  - Brute: the pipe on the sheet becomes a crude **pipe gun**.
  - Casino Mob Enforcer: its **drum-fed gun** is the weapon, and the separate "SPADE" arm cannon is dropped, so only one thing shoots.
  - VR Runner: a sleek chrome arm cannon, with the tablet in the other hand (unlit, not cyan).
  - Golden Zone: an ornate version of the Casino Mob Enforcer's gun.
- **No variant is bigger than the base,** the Brute included. The concept sheets are **references and jumping-off points**, not specs to copy: a bigger body would no longer match the hitboxes, which are the base's. Hitboxes may be slightly smaller than the visuals, never larger (CLAUDE.md principle 4).
- **Window cyborgs and hosts** use their zone's variant.

## Done when
- The enemy showcase can switch between all six zone variants.
- Rendered frames show each variant beside the base, on Forward+ and on the Compatibility renderer, including a far view at gameplay distance.
- The cyborg tests pass with hitboxes unchanged, and the full `tools/godot.sh test` and `tools/godot.sh smoke` pass.
- Questions go in `docs/questions/p3.md`.

