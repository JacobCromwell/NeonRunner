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
orchestrator gives each one the next free number (**830** after task E5e, I9, I3 and I2; raise it here when you use one) and files it
here only if work waits on it or its placeholder will be costly to change later; otherwise in
`docs/OPEN_QUESTIONS_DEFERRED.md`. When the owner answers an item, record the answer in the GDD and move the item
to `docs/OPEN_QUESTIONS_ANSWERED.md` with the answer.

## Needs the owner (summary)

| Item | Question |
|---|---|
| 766 | Ceilings in the levels are too safe (owner, October 10, 2026): should a level keep at least one safe lane where a ceiling ends, and leave the rest free to hold gaps, hazards or enemies? A change to the generator's rules (GDD §3, Safe landing zone). |
| 828 | The web demo's music on phones: keep it as samples (about 52–60 MB a song in memory, a stop of 0.3–3 s when one starts), stream it (no memory cost, but it may crackle on a slow phone), or ship lighter songs for the web? Needs a try on a real iPhone. |

## The items in full

**The Beach's boss: the design session** (the owner with Claude, October 10, 2026; GDD §10, Mecha Guppy and Captain Cogs; task E5e)
766. **Ceilings in the levels are too safe** (GDD §3, Safe landing zone; owner, October 10, 2026: "often the ceiling is
    way too safe", to be revisited for the game itself). In the Beach's boss fight one safe place to drop to is enough.
    Should the levels follow: at least one safe lane where a ceiling ends, and the rest free to hold gaps, hazards or
    enemies? It is a change to the level generator's rules (a core task), so it waits for the owner's word.

**I3, sound on an iPhone** (from `docs/questions/i3.md`; the batch of October 14, 2026)
828. **Should the web demo's music be played as a stream, or lighter, on phones?** (GDD §11; §2, the web demo.) On the
    web Godot plays every sound as a "sample" by default: a song is decoded whole when it first plays and kept raw
    (the Zone 1 song 52 MB, the Boss 1 song 60 MB, copied again each time it starts), and decoding stops the game's one
    thread (0.3 s on a desktop, likely 1–3 s on a phone). A phone short of memory could drop the music or reload the
    page, a second possible cause of the playtester's silent iPhone (item 827, the silent switch, is the likelier).
    "Stream" playback (music only) has none of that memory and makes the death dip's low-pass work on the web, but
    without threads it mixes on the page's thread, so a phone under about 20 fps could crackle. A third way: smaller
    songs for the web build (mono, or 22 kHz). It needs a try on a real iPhone. Placeholder: none; music stays as samples.
