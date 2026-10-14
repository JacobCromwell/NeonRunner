# Questions raised during build tasks

Each build task writes its design questions to its own file here, named after its task ID in
`docs/TASK_PLAN.md` (for example `b2.md`), instead of editing `docs/OPEN_QUESTIONS*.md` directly.
That way, tasks running in parallel never edit the same list.

When the orchestrator merges a task, it numbers the task's questions and moves each into
`docs/OPEN_QUESTIONS.md` (work waits on it, or its placeholder gets costly to change later) or
`docs/OPEN_QUESTIONS_DEFERRED.md` (everything else; the placeholder stands), then deletes the file.
The rules are at the top of `docs/OPEN_QUESTIONS.md`.

For each question, write:
- **The question**, in one or two sentences, with the GDD section it relates to.
- **The placeholder** you built, and where it lives (code marked `DESIGN-TBD`, or the data file and
  value).
