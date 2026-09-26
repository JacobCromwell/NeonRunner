# Generator patterns

`prototype_patterns.json` holds the patterns the level generator picks from
(`scripts/world/level_generator.gd`). Every pattern uses abstract gameplay pieces only, and no pattern
assumes a lane count.

## Pattern fields

| Field | Meaning |
|---|---|
| `id` | Name shown in logs and tests |
| `min_difficulty` / `max_difficulty` | The pattern can be picked only while the current difficulty (0–1) is in this range |
| `weight` | Relative pick chance among the patterns that qualify |
| `min_lanes` | Optional. Skip on devices with fewer lanes |
| `requires` | Optional. `"ramps"` and/or `"ceilings"` (switched on or off per level) |
| `length` | Metres of track the pattern takes (the generator extends it for long gaps and hulls) |
| `elements` | The pieces to place (see below) |

## Element kinds

`at` is the offset in metres from the pattern's start. `at_seconds` adds an offset in seconds at run speed,
so pieces keep their timing against a hull when run speed changes.

| Kind | Fields |
|---|---|
| `gap` | `lanes`, `jump_frac` (gap length as a fraction of a full jump's distance, capped by the level's `max_gap_jump_fraction`) |
| `fence` | `lanes`, `variant` (`full` = jump or switch lanes; `gapped` = slide under), `pulse_chance`, `pulse_on`, `pulse_off` (seconds) |
| `sign` | `side` (`left`/`right`/`random`/`both`/`same`), `length`, `bottom`, `top` (height band on the wall, in metres) |
| `ramp` | `side`. The ramp sits in the outermost lane on that side and launches the player onto the wall |
| `hull` | `lanes` (where the anti-grav pad goes), `length_seconds` (how long the ceiling lasts at run speed). The floor under a ceiling always stays clear (GDD §3): the generator drops any gap or fence a pattern places there and reports it as a warning |

## Lane selectors

`{"mode": ...}`, with `count` (a number of lanes) or `frac` (a fraction of the lane count, rounded, at least 1):

- `all`: every lane
- `all_but`: every lane except `count`/`frac` random lanes, which stay free
- `random`: `count`/`frac` random lanes
- `edge`: one outermost lane, picked at random
- `center`: the middle lane
- `same`: the lanes the previous element used
- `others`: every lane the previous element didn't use
