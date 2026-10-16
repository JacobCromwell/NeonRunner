# Workflow: how the owner runs build sessions

Written October 14, 2026, from the owner's answers: the **weekly usage limit** runs out before time does; requests
come in mixed sizes (a new boss or cinematic, gameplay tweaks, an object's look); the orchestrator may merge into
`main`; the owner playtests once or twice a day; Claude Code runs only in the cloud, and GitHub Copilot in WSL handles
some small edits.

## The pattern: one orchestrator session per batch

1. **Collect requests** in `docs/USER_REQUESTS.md` as `- [ ]` items under a dated heading, during or after playtesting.
2. **Start a fresh orchestrator session per batch** (prompt below), once or twice a day, before playtesting. It
   delegates each request to the agent for its tier, reviews, merges into `main` one task at a time, ticks the
   request and moves it to `docs/USER_REQUESTS_DONE.md`, and ends. Don't reuse a session for the next batch: an
   orchestrator's context grows with every task, and each turn pays for all of it again.
3. **Playtest `main`** and write the next batch.
4. **Answer `docs/OPEN_QUESTIONS.md`** when you have a moment. It holds only what work waits on (12 items at the
   sort). Everything in `docs/OPEN_QUESTIONS_DEFERRED.md` stands as built; reopen one only if playtesting shows a problem.

**Outside a batch:**
- **A tiny tweak** (one number in a `.tres` or `.json`, a volume, a colour): use Copilot in WSL. It doesn't spend
  the Claude limit. Run `tools/godot.sh test --gate` before pushing; tunables live in `data/` (`CLAUDE.md` principle 7).
- **One small but real change** (a bug, a single behaviour change): a standalone Claude session on Sonnet, prompt below.
- **A design conversation** (a new boss, a zone, story beats): its own session with no building. It ends with the
  decisions recorded in the GDD, then a batch builds them.

## Why batches and not one session per request
- The orchestrator merges one task at a time, so parallel work no longer collides (the history shows many
  "merge main into the branch" commits from parallel sessions).
- It routes each task to its tier: Haiku for data entry and Sonnet for most work. A standalone session runs
  whatever model it was opened with.
- Each batch starts with a short context.

## Spending less of the weekly limit
- **Read little.** `CLAUDE.md`, "Reading the docs": the architecture notes are split into parts
  (`docs/architecture/`, with an index), and the questions list is short. Before the split, an agent that read the
  architecture notes and the questions paid about 270k tokens before writing a line.
- **Review to the tier.** Spawn the `reviewer` (Opus, max effort) for T1 and T2 tasks only. For T3 and T4 work
  (data, docs, small tools), the orchestrator reads the diff itself and checks the gate passed.
- **Orchestrator effort.** The orchestrator mostly routes and reviews; Opus at high or extra-high effort is enough.
  Keep max effort for T1 builds and their reviews.
- **Test tiers.** Agents run `--gate` per task; the orchestrator runs `--tier=merge` before a merge and `--tier=full`
  once per batch, not after every merge (`CLAUDE.md`, Workflow rules).
- **Shard long tiers.** `--tier=full` (and `--tier=merge` on a loaded machine) takes 50+ minutes on one container,
  long enough to hit the 2400 s "stuck" timer or a container restart. Run it as `--shard=K/N` over 5 or 6
  containers (cloud sessions via `create_session`, one per shard, on a pushed commit) and count it as passed only
  when every shard exits 0 (`CLAUDE.md`, Workflow rules). Agents push and checkpoint before any long run.
- **Bundle small requests.** Several tweaks in the same area go to one agent as one task.

## Prompts to paste

**Batch orchestrator** (Opus, high or extra-high effort):

> You are the orchestrator for this batch. Read `CLAUDE.md` and `docs/WORKFLOW.md`, then the unchecked requests in
> `docs/USER_REQUESTS.md`. Read architecture parts and GDD sections only as each task needs them. For each request:
> size it and pick its tier and agent (`docs/TASK_PLAN.md`, Model tiers), bundling small ones in the same area, and
> give the agent a short brief with the files and docs parts it needs. Run up to three tasks at once, but only one that
> touches a core file. Review T1/T2 tasks with the `reviewer` agent and T3/T4 diffs yourself. Merge into `main` one at
> a time (merge `main` into the branch, `--tier=merge`, then merge), file each task's `docs/questions/<task-id>.md` per
> the rules at the top of `docs/OPEN_QUESTIONS.md`, tick each request with a short DONE note and move it to
> `docs/USER_REQUESTS_DONE.md`. Run `--tier=full` once at the end (sharded over 5 or 6 containers, `--shard=K/N`, if it would run longer than ~10 minutes). Stop and ask me only for a design gap that a marked
> placeholder can't cover. End with a list of what changed, what to playtest, and any new questions.

**Single fix** (Sonnet):

> Read `CLAUDE.md`. Task: <what to change, and where you saw it>. Read only the architecture part and code it needs.
> Make the change on this branch, run `tools/godot.sh test --gate`, commit and push, and report what you verified.

**Design session** (Opus):

> Read `CLAUDE.md` and the GDD sections about <topic>. We're designing <topic>; don't build anything. Ask me questions
> until it's specified, then record the decisions in `docs/GDD_CHECKPOINT.md` and add the build requests to
> `docs/USER_REQUESTS.md`.
