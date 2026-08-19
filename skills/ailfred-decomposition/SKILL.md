---
name: ailfred-decomposition
description: Doctrine for breaking one large request into an approvable PRD plus steps and tasks — sizing rules, scope allowlists, parallel-safety test, capability reuse (scan the skills present on this machine before improvising), and the rejection checklist a plan must pass. Use with /ailfred, /ailfred-execute and /ailfred-status, or whenever a request is too large to implement in one pass.
---

# Goal decomposition (doctrine)

> Skill do plugin `ailfred`. Lida por `/ailfred` e pelo agent `ailfred-architect`.

Method only — domain-agnostic. The goal supplies the domain; this doc supplies how
it is cut. Runtime artifacts live in `.claude/ailfred/<slug>/`; templates in
`${CLAUDE_PLUGIN_ROOT}/templates/ailfred/`; commands in `${CLAUDE_PLUGIN_ROOT}/commands/`; workers in
`${CLAUDE_PLUGIN_ROOT}/agents/`.

**Self-contained.** Everything the method needs ships inside the plugin; the only thing
written into the open project is the goal runtime under `.claude/ailfred/<slug>/`.

## Language

Instruction files (commands, agents, skills) in English. Runtime artifacts under
`.claude/ailfred/**` and every developer-facing message in Portuguese. When the open
project states its own language or file-content policy (`CLAUDE.md`, `AGENTS.md`, a
skill), that policy wins for files inside that project — read it before writing.

## The three artifacts

| Artifact | Answers | Written by | Approved at |
| --- | --- | --- | --- |
| `PRD.md` | what outcome, verified how, explicitly not what | `ailfred-architect` | G-G2 |
| `plan.md` | which steps, which order, what runs in parallel | `ailfred-architect` | G-G3 |
| `tasks/<id>.md` | one unit a single worker can finish and prove | `ailfred-architect` | with the plan |

`state.yaml` is machine state, not a document: single writer is the host session.

## PRD quality bar

A PRD is approvable only when all of these hold:

1. The objective is an **outcome**, not an activity ("`/ailfred` breaks a request into an executable backlog", not "work on decomposition").
2. Every success criterion names **how it is verified** — a command, a file that must exist, an observable behavior. A criterion nobody can check is deleted or turned into a spike task.
3. **Non-goals are explicit.** At least one, always: the neighbouring thing that will *not* be done is what stops scope drift during execution.
4. Affected surfaces list **real paths that were actually read** during discovery — never guessed.
5. **No open question remains**: each one is answered at the gate, downgraded to a recorded assumption, or converted into a spike task with a written deliverable.
6. Section 9 has a **verdict for every candidate capability** — reused, or discarded with a reason.

## Capability reuse (mandatory step, before planning method)

Run the scan and read it before designing anything:

```bash
bash "$AF/scripts/ailfred-capability-scan.sh"
```

Rules:

- Prefer an existing skill/agent/command over inventing a procedure. If a loaded skill covers the domain (research, TDD, debugging, code review, domain modeling, validation), the PRD must say **use it** or **not applicable, because …**.
- `ref` entries (loose `.md` in a skills dir) are *not* auto-loaded. They are readable reference material: cite the path and read it on demand.
- Cap at **3 skills per worker**. More context is not more capability.
- The repo's own contracts win over any generic skill: `CLAUDE.md`, `AGENTS.md`, `.claude/rules/**`.

## Task sizing

- **S** = up to ~3 files, one coherent change. **M** = up to ~6 files. **L is forbidden** — split it. If a task cannot be described without "and then also", it is two tasks.
- One task = one objective + one set of acceptance criteria + one runnable evidence command. No task without an evidence command; if nothing can be run, the evidence is a diff or a written artifact, named explicitly.
- A task a worker cannot finish without re-planning is mis-sized. Symptoms: unknown target paths, acceptance criteria phrased as "improve/adjust/review", dependencies discovered mid-way.
- Investigation is a **spike task**: deliverable is a written file (findings, decision, recommended slicing), never code.
- Max ~7 tasks per step. More than that, the step is really two steps.

## Step boundaries

- A step is a **verifiable milestone**: when it closes, the tree is green (lint/types/tests/build as applicable to the repo) and the work is coherent even if the goal stops there.
- Steps are ordered by dependency, not by convenience. The first step of any risky goal is usually the foundation step (shared types, config, dependencies, scripts) — done alone, in the main tree.
- Each step declares its own validation commands, taken from the project (`package.json` scripts and equivalents), not invented.

## Scope allowlist and parallel safety

Every task declares `scope_allowlist` — the paths it may write. This is the mechanism
that makes parallel execution safe and post-hoc review honest.

The test, applied per step:

1. Compute the intersection of the allowlists of the tasks in the step.
2. **Empty intersection → parallel-safe** (candidate wave).
3. **Non-empty intersection → not parallel-safe**: serialize them, merge them into one task, or extract the shared part into a foundation task that runs first.

Always `parallel: unsafe` regardless of paths: dependency manifests and lockfiles,
global config, code generation that rewrites shared output, anything requiring an
exclusive port or a single dev server, anything that reformats broadly.

## Plan rejection checklist

The host rejects the plan and respawns the architect with the specific violation when:

- any task is `size: L`, or has no acceptance criteria, or no evidence command;
- two tasks in the same wave have overlapping `scope_allowlist`;
- a success criterion from PRD §4 maps to no task;
- a task's `depends_on` points forward (later step or later wave);
- a step has no validation command;
- the plan touches paths never mentioned in PRD §6.

Reject with the violation named; never patch the plan inline in the principal session.

## Goals that target a distributed kit, plugin or template

When the goal edits something the repository *publishes* (a plugin, a scaffolding kit, a
shared template, a package), the plan must account for the distribution mechanics — they
are the part that silently breaks:

- **Contract vs runtime:** which paths are the shipped contract and which are per-project state. A task may not blur the two.
- **Mirrors and sync steps:** if a sync script copies the source into another directory, editing the source without running the sync leaves two truths. The sync is a step of the task, not an afterthought.
- **Prune behaviour:** a sync that deletes what it does not own can erase files added by hand. Check before placing new files inside a synced directory.
- **Version and release effects:** a version bump, tag or cache invalidation is usually required for consumers to see the change — and consumers may have their own state keyed to the old version.
- **Content rules of the target tree:** language, formatting or lint rules the published tree enforces (see § Language).

## Anti-patterns

- Writing the plan before the PRD is approved, or executing before the plan is approved.
- Discovery in the principal session beyond `git status` and reading root contracts — delegate to `ailfred-architect`.
- Tasks whose real content is "figure out what to do" without a spike deliverable.
- A step that closes red "because the next step fixes it".
- Copying the whole PRD or plan into a spawn briefing — pass paths and IDs.
- Sizing by time estimates instead of scope and verifiability.
- Adding scope during execution: it goes to `state.yaml → followups`, or the PRD gets a new version and a new gate.
