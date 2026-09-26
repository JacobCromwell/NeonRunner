# Generator patterns

The level generator (`scripts/world/level_generator.gd`) picks patterns from **every `.json` file in
this folder**: the level's main file (`prototype_patterns.json`) first, then the others in name order.
Every pattern uses abstract gameplay pieces only, and no pattern assumes a lane count.

A level only picks patterns whose `requires` entries are all in its `features` list
(`LevelConfig.features`), so a pattern file for a new enemy type changes nothing until a level turns
that enemy on (GDD §6: introduce one new mechanic at a time).

## Pattern fields

| Field | Meaning |
|---|---|
| `id` | Name shown in logs and tests |
| `min_difficulty` / `max_difficulty` | The pattern can be picked only while the current difficulty (0–1) is in this range |
| `weight` | Relative pick chance among the patterns that qualify |
| `min_lanes` | Optional. Skip on devices with fewer lanes |
| `requires` | Optional. Features the level must have: `ramps`, `ceilings`, `pulsing`, `speed_pads`, or an enemy type (`cyborg`, `window_cyborg`, `host`, `hover_truck`, `octodog`, `screech`, `drone`, `generator`) |
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
| `hull` | `lanes` (where the anti-grav pad goes), `length_seconds` (how long the ceiling lasts at run speed). The floor under a ceiling always stays clear (GDD §3): the generator drops any gap, fence or floor enemy a pattern places there and reports it as a warning |
| `speed_pad` | `lanes`. A speed pad in each lane (DESIGN-TBD: GDD §6 only names speed pads) |
| `enemy` | `type` (the enemy type name), `lanes` (floor enemies; one per lane) **or** `side` (wall enemies, e.g. window cyborgs: `left`/`right`/`random`/`same`), `params` (passed to the enemy as `spawn.params`), `allow_under_hull` (optional, for flying enemies) |
| `credits` | `surface` (`floor`/`ceiling`/`wall`), `lanes` or `side`, `count`, `spacing` (m), `value` (1, 5, 25 or 100), `height` (m from the surface, or the height on the wall) |

Credits are also placed automatically after the patterns (trails in clear stretches; rich credits at gap
edges, by fences, along wall runs and on ceilings), tuned in the level's Credits group.

## Lane selectors

`{"mode": ...}`, with `count` (a number of lanes) or `frac` (a fraction of the lane count, rounded, at least 1):

- `all`: every lane
- `all_but`: every lane except `count`/`frac` random lanes, which stay free
- `random`: `count`/`frac` random lanes
- `edge`: one outermost lane, picked at random
- `center`: the middle lane
- `same`: the lanes the previous element used
- `others`: every lane the previous element didn't use

## Enemy rules

Rules that patterns can't express (e.g. "an anti-grav pad at least 10 s after a drone appears, then every
8–10 s", GDD §9.6) go in `scripts/enemies/<type>_rules.gd` as `static func apply(gen: LevelGenerator)`.
They run after the patterns for every feature the level has. See `docs/ARCHITECTURE.md`.
