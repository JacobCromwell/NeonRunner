# Questions raised during build tasks

Each build task writes its design questions to its own file here, named after its task ID in
`docs/TASK_PLAN.md` (for example `b2.md`), instead of editing `docs/OPEN_QUESTIONS.md` directly.
That way, tasks running in parallel never edit the same list.

When the orchestrator merges a task, it moves the task's questions into `docs/OPEN_QUESTIONS.md`
under "Raised during build" and deletes the file.

For each question, write:
- **The question**, in one or two sentences, with the GDD section it relates to.
- **The placeholder** you built, and where it lives (code marked `DESIGN-TBD`, or the data file and
  value).
