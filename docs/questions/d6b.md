# D6b: the Golden Palace interior skin

1. **The floor's gold inlay runner** (GDD §5: "a palace floor (marble, inlay, gold runners)"): how
   wide. **Placeholder:** `GoldenPalaceSkin.runner_half_width` (0.2 m, a roughly 0.4 m runner down
   each lane's centre), `## DESIGN-TBD` in `scripts/world/skins/golden_palace_skin.gd`.

2. **How tall the colonnade rises** above its entablature (frieze_top) before the hall reads as
   receding into haze, comfortably clear of an alcove's statue and a hung tapestry. **Placeholder:**
   `GoldenPalaceSkin.pilaster_height` (15 m), `## DESIGN-TBD` in the same file.

3. **How far a ceiling piece's structure may rise** above its underside (GDD §5: "the vast hall's
   ceiling stays far above") before the hall's haze would hide it anyway. **Placeholder:**
   `GoldenPalaceSkin.hall_clear_height` (7.5 m, close to the Corporate zone's and the Dead Zone's own
   ~7.4 m ceiling-structure budgets), `## DESIGN-TBD` in the same file.

4. **The vault above the colonnade** (GDD §5: "an enormous vaulted space, perhaps with distant halls
   and light shafts"): whether it should look like the Golden Zone's own dusk sky with the moon and
   stars turned off (what's built: `GoldenPalaceSkin.make_environment()` reuses
   `GoldenSkin.make_environment()` wholesale, its warm haze and dimmed "skyline" standing in for
   distant halls glimpsed through light shafts), or something explicitly interior instead (a painted
   or coffered ceiling glimpsed above the colonnade, a true horizon never showing).
