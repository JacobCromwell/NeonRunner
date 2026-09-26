# Build brief: the ragged cyborg gangster (the new cyborg base model)

**Task ID:** P2 (for `docs/TASK_PLAN.md`). **Tier:** T2 (Opus 5.5; the owner runs T2 at max effort). **Size:** M–L.
**Decision source:** GDD §9.2, "Default look" (owner, September 26, 2026).
**Reference:** `docs/art/reference/cyborg_gangster_default.jpg` (three looks: Chem-Junky, Scavenged Runner, Wired-Out).

## Goal
Replace the cyborgs' looks with **one ragged, strung-out gangster**. It is the **base model for every cyborg**: the normal and panic cyborgs, window cyborgs and hosts. It **replaces the sleek city citizen and the patched scavenger** in every zone, including the Neon City. Zone variants will be derived from this base later, from concept art the owner will supply. This task changes looks only: behaviour, timings and **hitboxes stay exactly as they are** (the body box and the stompable head box in `scripts/enemies/cyborg.gd`).

## One body, blending the three looks
The owner wants **one body** to keep things simple, not three variants. Blend these traits:
- **Silhouette and outfit** from the middle look, the Scavenged Runner:
  - a hoodie under a tactical vest with pouches
  - patched cargo pants, knee pads and scuffed boots
- **From the Chem-Junky:**
  - a gaunt, sickly frame
  - torn, grimy layers
  - a small chem canister on the back with **unlit** tubes running into the neck or arm (murky, not glowing)
- **From the Wired-Out:**
  - the **bulky, scavenged piston arm**, which becomes the **arm cannon** (the cyborg's weapon, GDD §9.2)
  - patches and torn hems
- **Posture:** hunched and twitchy. A jittery idle and a shambling walk fit "strung out". Keep the existing poses' timings and reach.

If blending proves too hard, build the **Scavenged Runner** alone (the owner's fallback), plus the piston arm cannon.

## The head is an LED screen
- **The entire head is an LED screen,** a beat-up, boxy screen-head (cracked casing, taped edges). There's no hair, face or mask. That keeps it simple, and the expressions stay large and readable on small phone screens.
- **The expressions carry over:** normal, the panic variant's shocked "O", and the host's corrupted glitching.
- **LED colour: cold white** (changed from amber), so enemies never share the player's copper glow.

## Colour rules
- **Clothing:** grimy khaki, olive, brown and faded grey. Nothing on it glows.
- **Metal:** rusted steel and gunmetal, dull and unlit. **No gold or brass,** which is now the player's signature (Razor Echo's gold arm and copper conduits).
- **The only glows on a cyborg:**
  - the **white LED face**
  - the arm cannon's **charge-up in enemy-fire red** (unchanged)
  - on **hosts only**, **purple** glitch static on the screen, plus purple glowing veins along the neck and arms. Purple on a cyborg always and only means "host".
- **Nothing else** uses hazard colours (pink, yellow and black, orange, green) or the "safe" colours (cyan, green). The sheet's cyan and green chem tubes become murky and unlit, the red goggle is gone (the screen head replaces it), and the Wired-Out's purple veins now appear only on hosts.

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
