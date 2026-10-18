# Architecture: Mini-games (the volleyball match)

One part of the architecture notes; `docs/ARCHITECTURE.md` is the index of every part and topic.

## Mini-games

A level may play a mini-game instead of a generated layout (`LevelConfig.minigame`, a `MiniGameDef`; task D10e, the
owner, October 10, 2026: the Beach's second level is a beach volleyball match). It is a run like any level's: the
same `LevelRun`, world, controls, camera, HUD, pause, death flow, results and shop, and it ends as every level does,
when the runner crosses the finish line at the end of the track.

```
MiniGame.create(def)              the game's scene (MiniGameDef.scene; its root extends MiniGame)
  .plan_layout(context) → LevelLayout   the level's track (instead of LevelCache / the generator)
RunWorld.build(layout)
game.setup(world, context)        joins the world right after the player (it acts on the player's moves the frame
                                  they happen), seeds its rng from the def's id and the level's seed, _start()
```

| File | What |
|---|---|
| `scripts/minigames/minigame_def.gd`, `minigame.gd` | the slot (id, scene, tuning; `star_text()`: the tuning's wording of how the stars are earned, for the results screen) and the base: `create`, `of(world)` (the world's meta), `plan_layout`, `setup`, `payout()`, `stars()`, `stats()`, `hint_trigger()` (`minigame:<id>`) |
| `scripts/minigames/volleyball/volleyball_match.gd` (`VolleyballMatch`), `scenes/minigames/volleyball.tscn` | the volleyball match (below) |
| `volleyball_tuning.gd`, `data/minigames/volleyball_tuning.tres` | its numbers (F6 in the level: "Mini-game: Beach Volleyball") |
| `volleyball_court.gd` and its shaders | the court: raked sand over the street with the boundary tapes, the net and its padded posts, which sink into the sand (`sink`) |
| `volleyball_ball.gd`, `volleyball_ball.gdshader` | the ball: exact arcs (`throw_to(from, to, seconds)`: where and when it arrives is known when it's hit), a shadow, bounces when out of play |
| `volleyball_rival.gd`, `volleyball_rival_suit.gd` | the rival on the shared `HumanoidRig`: his look (a new `HumanoidParts`), the rig's activities for his stance, run and jump, his arms posed over them (serve, hit, dive, cheer, hands on his head, wave) |
| `volleyball_hud.gd`, `volleyball_marker.gdshader` | the scoreboard (points, "FIRST TO 4", a pip per return the rally needs, the calls and the payout) and the landing ring with its closing ring |
| `data/levels/beach_2.tres`, `data/minigames/volleyball.tres` | the level (*Net Gains*, off the curve, no features) and the slot |
| `tests/helpers/volleyball_bot.gd`, `tests/suites/test_volleyball.gd`, `tools/showcase/volleyball_review.gd` | the bot that plays it through the runner's actions, its suite, and a review tool (screenshots on events, a close-up of the rival, a view beside the court) |

What the framework touches outside its folder:
- `LevelRun._build` asks a mini-game level's game for its track and sets the game up after the world is built
  (`LevelRun.minigame`); its tuning joins the F6 panel.
- `Player.speed_override`: while 0 or more, the runner moves along the track at that speed instead of the run's
  (boosts and the dash's bonus included), and lanes, jumps and slides work as usual; below 0 (every run's start), the
  run's own. The game walks the runner up and stands them still with it, and hands the run back with -1.
- `RunResult.from_world` merges the game's `stats()`, pays its `payout()` as the completion bonus (instead of the
  level's, DESIGN-TBD) and takes its `stars()`; the results screen calls it "Match payout" and shows the game's stats.
- `HintDirector`: a hint whose trigger is `minigame:<id>` pages first on the game's level introduction; anything else
  unseen on its track follows as a reminder.
- `Campaign.feature_ages` leaves mini-game levels out (they have no features), and `CampaignStep.is_minigame()` lets
  the suites and the measuring tools that generate every level skip them.

**The volleyball match** (`VolleyballMatch`; the owner's design and the placeholders, GDD §5, the Beach, and
`docs/questions/d10e.md`):
- **The track** (`plan_layout`, `_plan_track`): `run_in_seconds` of the level's run speed (2.5 s, about 60 m at
  the Beach's 23.8 m/s) with two short trails of credits, slowing evenly to `walk_speed` over `brake_seconds`,
  walking for `walk_seconds`, then easing to a stop over `stop_distance` on the runner's line (`approach_speed(d)`,
  set as the runner's `speed_override` each frame, so the stop lands within millimetres at every speed); the net
  `court_depth` on, the rival's line `rival_depth` past it, and the finish `exit_seconds` of run past the line (and
  well past the rival's end line). Both side walls open `open_walls_before` the line to past the finish
  (`LevelLayout.wall_gaps`: the Beach's open beach shows round the court). Nothing on it hurts and it has no gaps.
- **A rally**: the rival serves (the toss, `serve_toss_seconds`, then the hit at the top of his jump). Each ball to
  the runner comes down in a lane on their line (`_aim`: at least one lane from them, at most `lanes_away(ball)`, now
  and then their own) at `strike_height`, flying `flight_for(ball, lanes)`: the serve's `serve_flight`, each later
  ball `flight_step` quicker down to `min_flight`, never under `fair_flight` (react, cross the lanes at
  `lane_margin` switches' time each, jump). The ring marks its lane from the hit; the closing ring meets it
  `jump_lead_seconds` before the ball reaches the line. Every physics frame after the player moves, `_runner_contact`
  decides: an airborne runner whose hit box (`hit_center_height`, `hit_half_size` around the head and hands)
  reaches the ball returns it (`_runner_hit`); a grounded one in its way takes it on the head (`bonk_half_size`: the
  ball bounces off, his point); a ball that lands is his point. A return flies `return_flight` back to where the
  rival can reach it; the rally's `returns_to_win_point`-th lands on the side of his court away from him (`WINNER`:
  he dives, and misses) for the runner's point.
- **The match**: first to `points_to_win`; then `payout_per_point` × points won, shown (the jackpot sound when
  there is one), the rival's goodbye, and after `payout_seconds` the net sinks (`net_sink_seconds`), the rival steps
  aside to the kerb and waves, and the runner speeds back up to the run speed over `exit_accel_seconds` and runs on
  to the finish. Scoring: `return_score` a return and `point_score` a point won (score bonuses).
- **The stars** (owner, October 18, 2026, task N2: by how the match went, never how fast; `VolleyballTuning.stars_for(won,
  lost)`, `VolleyballMatch.stars`): 4 points to the rival's 0 is three stars (`three_star_points` 4 with the rival on at most
  `three_star_rival_points`, 0), under `two_star_points` (2) points won one star, anything in between two. Read literally, a
  4-1, 4-2 or 4-3 win is two stars, and so is a loss with 2 or 3 points (the runner finishes the level whoever wins). Time and
  the run-in's credits count for nothing. The results screen lists the rule under the stars (`ResultsScreen.star_text` →
  `MiniGameDef.star_text` → `VolleyballTuning.star_text`: three lines, worded from the data, no par times), and
  `Profile.record_run` keeps the best. The suite plays a 4-K win by switching `VolleyballBot` from "idle" to "perfect" once the rival has K points.
- **What it records** (`events`, `lowest_over_net`): every serve, ball (its lane, the runner's lane and its flight),
  hit, bonk, drop, winner, point, the match and the exit, for the suite and the review tool.
- **Looks**: the court's sand, the net, the posts, the ball and the ring are unshaded in the street's light
  (`scenery_light`, `scenery_tint`) but the ball (lit like the characters); nothing glows but the rival's thin violet
  sunglasses rim (the Beach's decorative neon) and nothing uses a hazard colour, so nothing reads as a hazard. The
  runner's arms reach up over the jump's pose as the ball nears (posed on the avatar's rig after its own animation).
- **Sounds**: `volley_hit`, `volley_bounce` and `volley_whistle` (`tools/asset_gen/sfx_bank_minigames.gd`).
