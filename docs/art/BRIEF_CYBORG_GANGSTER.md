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
- **Metal:** rusted steel and gunmetal, dull and unlit. **No gold or brass,** which is now the player's signature (Razor Echo's gold arm and copper conduits). The sheet's brass arm becomes rusted steel.
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
