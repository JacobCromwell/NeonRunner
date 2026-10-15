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
orchestrator gives each one the next free number (**751** after the sort; raise it here when you use one) and files it
here only if work waits on it or its placeholder will be costly to change later; otherwise in
`docs/OPEN_QUESTIONS_DEFERRED.md`. When the owner answers an item, record the answer in the GDD and move the item
to `docs/OPEN_QUESTIONS_ANSWERED.md` with the answer.

## Needs the owner (summary)

| Item | Question |
|---|---|
| 575 | The Beach's boss. **In progress:** the owner is designing it in another session. |

## The items in full

**The Beach joins the campaign** (from D10c; the owner, October 9, 2026: "put the beach between the corporate and dead zone. Keep in mind that there will be a boss battle for the beach, but it has not yet been created. Do not worry about any new enemies at this time. Create level names that fit the theme."; GDD §5, §6 and §10; `data/campaign/campaign.tres`, `data/zones/beach.tres`, `data/levels/beach_1.tres` (Tiki Tides) and `beach_2.tres` (Sunset Strip); play `--level=beach/1`)
575. **The boss** (GDD §10: "there will be a boss battle for the beach, but it has not yet been created"; task E5e,
    blocked on design). Placeholder: `data/bosses/beach_boss.tres`, "The Beach's boss", unbuilt: the campaign shows
    its placeholder card and passes through it to the Beach's outro and the Dead Zone, with no stars. Its fight,
    name and payout are to be designed. When it's built, `test_app_flow` and `test_screens` need another unbuilt
    stand-in for their placeholder-card checks.
    **In progress (owner, October 14, 2026):** the owner is designing the Beach's boss in another session.
