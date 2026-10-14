# Open Questions

Questions that need the owner's answer. Sorted on October 14, 2026, when the list had grown to 794 items: the owner
is happy with the gameplay, so everything whose placeholder works moved out.

Item numbers are permanent: code comments, tests and the GDD cite them ("`docs/OPEN_QUESTIONS.md` item 628", "FB 73").
An item lives in exactly one of three files, under its original heading and number:

- `docs/OPEN_QUESTIONS.md`: the few questions that need the owner (work waits on them, or the placeholder gets
  costlier to change later).
- `docs/OPEN_QUESTIONS_DEFERRED.md`: still technically open, but the placeholder works and nothing waits on it
  (tuning, names, looks, feel). **The placeholder stands as built** until the owner reopens it while playtesting.
- `docs/OPEN_QUESTIONS_ANSWERED.md`: answered, approved, superseded, or notes that ask nothing.

To find a cited item, search the three files: `grep -n "^628\. " docs/OPEN_QUESTIONS*.md` (build phase 2 items have
no prefix; "GB n" and "FB n" are in their own sections). **Don't read these files whole.**

**New questions** from a task go in `docs/questions/<task-id>.md` (see `CLAUDE.md`). When the task merges, the
orchestrator gives each one the next free number (**749** after the sort; raise it here when you use one) and files it
here only if work waits on it or its placeholder will be costly to change later; otherwise in
`docs/OPEN_QUESTIONS_DEFERRED.md`. When the owner answers an item, record the answer in the GDD and move the item
to `docs/OPEN_QUESTIONS_ANSWERED.md` with the answer.

## Needs the owner (summary)

| Item | Question |
|---|---|
| 231 | Which web portals get the demo? Recommendation below: itch.io first, CrazyGames later with a Steam-only end screen, skip Poki. |
| 575 | The Beach's boss. **In progress:** the owner is designing it in another session. |

## The items in full


**The web demo** (from E2; export and check it with `tools/godot.sh web`, README "The web demo"; the demo is City 1–3 and the Floating Head, then the "get the full game" screen)
231. **The portals' rules on outbound links** (GDD §2: itch.io, possibly Poki or CrazyGames; "check each
    portal's rules on outbound links"). I couldn't read the rules: this build machine's network policy blocks
    itch.io, docs.crazygames.com, developers.poki.com and sdk.poki.com. For each portal the demo goes to:
    - **itch.io:** the demo's own page, where links to Steam, the App Store and Google Play are the usual
    thing. Do you want its end screen as it is (three store tiles)?
    - **Poki** and **CrazyGames:** do their rules allow links out of the game to other stores at all, only to
    some (for example the game's own Steam page), or none? Do they ask for their own SDK (their ads, their
    analytics, a "game loading/started" call) even in a game without ads? Is there a size or loading-time
    limit the demo must meet (it downloads about 14 MB compressed, see the report)?
    Placeholder: one build for every portal, with the three store tiles; the store links open through the
    platform layer (`Platform.open_store()` → `PlatformBackend.open_url()`), so a portal that forbids them
    gets a backend of its own that hides or disables the tiles, without touching the game.

    **Recommendation (October 14, 2026, for the owner's yes):** itch.io first, as built. CrazyGames later, if wanted:
    its rules allow a link to the game's own store page (Steam, Epic) on desktop at the end of a demo or in the main
    menu, as long as it isn't the main call to action; no cross-promotion otherwise. That needs a Steam-only end
    screen there. Skip Poki: it is curated, blocks requests out of the game unless they go through its SDK, and its
    traffic earns through its ads, which the demo doesn't have.

**The Beach joins the campaign** (from D10c; the owner, October 9, 2026: "put the beach between the corporate and dead zone. Keep in mind that there will be a boss battle for the beach, but it has not yet been created. Do not worry about any new enemies at this time. Create level names that fit the theme."; GDD §5, §6 and §10; `data/campaign/campaign.tres`, `data/zones/beach.tres`, `data/levels/beach_1.tres` (Tiki Tides) and `beach_2.tres` (Sunset Strip); play `--level=beach/1`)
575. **The boss** (GDD §10: "there will be a boss battle for the beach, but it has not yet been created"; task E5e,
    blocked on design). Placeholder: `data/bosses/beach_boss.tres`, "The Beach's boss", unbuilt: the campaign shows
    its placeholder card and passes through it to the Beach's outro and the Dead Zone, with no stars. Its fight,
    name and payout are to be designed. When it's built, `test_app_flow` and `test_screens` need another unbuilt
    stand-in for their placeholder-card checks.
    **In progress (owner, October 14, 2026):** the owner is designing the Beach's boss in another session.
