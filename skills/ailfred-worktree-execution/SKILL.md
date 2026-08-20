---
name: ailfred-worktree-execution
description: When and how to run goal tasks in parallel git worktrees — the decision rules that justify isolation, branch and path layout, concurrency cap, integration order, conflict handling, and cleanup. Use during /ailfred-execute, or whenever independent tasks could run concurrently in separate working trees.
---

# Goal worktree execution (parallel mechanics)

> Skill do plugin `ailfred`. Lida por `/ailfred-execute` e pelo agent `ailfred-step-runner`.

Companion to skill `ailfred-decomposition`. That one decides *what* the tasks are; this
one decides *where* they run and how the results come back together.

Helper (never call raw `git worktree` from an agent):

```bash
bash "$AF/scripts/ailfred-worktree.sh" add       <slug> <task-id> [base-branch]
bash "$AF/scripts/ailfred-worktree.sh" list      [slug]
bash "$AF/scripts/ailfred-worktree.sh" status    <slug> <task-id>
bash "$AF/scripts/ailfred-worktree.sh" integrate <slug> <task-id> [into-branch]
bash "$AF/scripts/ailfred-worktree.sh" remove    <slug> <task-id> [--force]
```

Layout: `../.ailfred-worktrees/<repo-name>/<slug>/<task-id>` on branch
`goal/<slug>/<task-id>`. Outside the repo on purpose — the main working tree stays
clean and nothing lands in `.gitignore`.

## Use a worktree when — all of these

1. The step has **≥2 tasks marked `parallel: safe`** in the same wave.
2. Their `scope_allowlist` sets are **disjoint** (the test lives in skill `ailfred-decomposition`).
3. Each is **size M**, or S but slow (long build, long test run). Two quick S tasks are cheaper sequentially than the isolation overhead.
4. The main tree is **clean** at wave start (`git status --porcelain` empty).
5. Each task can be **validated on its own** — its evidence command does not need the sibling task's changes.

## Do not use a worktree when — any of these

- Tasks share files, or the change is a broad reformat/codemod.
- The task edits dependency manifests, lockfiles, or global config (foundation task: main tree, alone, first).
- Validation needs a single exclusive resource — one dev server, one fixed port, one database.
- The step has a single task, or the developer chose `single` at gate **G-G4**.
- The repo is mid-merge/mid-rebase, or the developer has uncommitted work they have not agreed to park.

Sequential in the main tree is the default. Parallel isolation is an optimization
that has to earn its cost.

## Dispatch

Preferred, one worker per worktree, spawned concurrently in a single message:

```text
Agent(subagent_type="ailfred:ailfred-task-worker", isolation="worktree")
```

Fallback when harness-managed isolation is unavailable, or when the worktree must
outlive the worker: `ailfred-worktree.sh add`, then spawn the worker with an explicit
`workdir` in its briefing.

Rules:

- **Concurrency cap 3** by default (`state.yaml → goal.max_parallel`). The cap exists so integration and review stay tractable, not because more agents would not run.
- One task per worker. A worker that finishes early does **not** pick up the next task — the step orchestrator dispatches the next wave.
- Every worker briefing carries: `task_id`, task file path, `scope_allowlist`, evidence commands, and the branch/worktree it owns. Never the plan or PRD body.
- The worker **commits inside its own worktree** (message `ailfred(<slug>/<task-id>): <objective>`), and never merges, rebases, pushes, or touches another task's branch.

## Integration

Serial, in dependency order, on the base branch — never concurrent merges:

1. Base branch checked out in the main tree, tree clean.
2. `ailfred-worktree.sh integrate <slug> <task-id>` per task, in the plan's documented order (foundation tasks first, then the wave in `depends_on` order).
3. **Re-run the step validation after each merge**, not only after the last one. A conflict-free merge is not a working merge.
4. Exit code `2` = conflict: resolve in the main tree with the conflicting task files as reference (skill `mattpocock-skills:resolving-merge-conflicts` if available), commit, then continue. Never `--force` past a conflict.
5. Record every merge in `steps/SNN-report.md` § Integração, and clear the entry from `state.yaml → worktrees`.

If two merges conflict repeatedly, the decomposition was wrong: stop the wave, report
the overlap, and let the architect re-slice. Do not keep hand-resolving.

## Cleanup

- Remove a worktree only after its branch is integrated and the step validation is green: `ailfred-worktree.sh remove <slug> <task-id>`.
- The helper refuses to remove a dirty or unmerged worktree. That refusal is a signal — surface it to the developer; do not reach for `--force` on your own.
- Branches are kept after removal. Deleting them is a developer decision.
- At goal closure `/ailfred-status` must report zero live worktrees; leftovers are listed as pendências.

## Anti-patterns

- Worktrees for tasks that were never marked `parallel: safe`.
- Dispatching a wave while the previous wave's branches are unmerged.
- Raw `git worktree` / `git merge` from an agent instead of the helper (loses the precondition checks: dirty tree, wrong branch, uncommitted worker changes).
- A worker running the whole step's validation instead of its own task evidence.
- Merging everything at the end in one batch to "save time".
- Leaving `state.yaml → worktrees` out of sync with `ailfred-worktree.sh list`.
