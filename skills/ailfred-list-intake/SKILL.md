---
name: ailfred-list-intake
description: How to ingest a to-do list or backlog (nested markdown checklist, a file, or a pasted list) as the input of a goal — deterministic parsing, cluster splitting, per-item triage into ready/vague/oversized/spike/developer-action, batched clarification, item-to-task traceability, and writing completion back into the source checkboxes. Use whenever the input of /ailfred is a list of items instead of a single objective.
---

# Goal list intake (backlog as input)

> Skill do plugin `ailfred`. Lida por `/ailfred` no modo intake e pelo agent `ailfred-architect`.

A one-line objective and a to-do list are different inputs. A list arrives with mixed
granularity, implicit hierarchy, shorthand ("e tals", "e tudo mais"), items that are
really decisions, and checkboxes the developer expects to see ticked afterwards.
Feeding a raw list into decomposition produces vague tasks; this skill is what stands
between the two. Complements skill `ailfred-decomposition` — the sizing and
parallel-safety rules there still apply to every task produced here.

## When intake mode applies

- `/ailfred --from <file>` (optionally `--section "<heading>"`, `--pending-only`)
- `$ARGUMENTS` is a path to a file containing `- [ ]` lines
- the pasted text contains two or more checklist lines

A pasted list is first written verbatim to `.claude/ailfred/<slug>/source-list.md` so line
numbers become stable, and `source.writeback` is set to `false` — there is no original
file to tick.

## Step 1 — Parse deterministically (never by eye)

```bash
AF="${CLAUDE_PLUGIN_ROOT:-./ailfred}"   # installed → plugin cache; dev in this repo → ./ailfred
bash "$AF/scripts/ailfred-todo-parse.sh" <file> [--section "<heading>"] [--pending-only] \
  > .claude/ailfred/<slug>/source-items.yaml
```

The YAML is the contract for everything downstream:

| Field | Meaning for planning |
| --- | --- |
| `id` (`I01`…) | stable handle for traceability; every task cites the item it serves |
| `line` | write-back anchor in the source file |
| `depth` / `parent` / `has_children` | the list's own hierarchy: parent → step candidate, leaf → task candidate |
| `checked` | already done: never re-planned, only reported |
| `section` | nearest heading; different sections are usually different goals |
| `notes` | nested bullets without a checkbox: context and acceptance hints, **never** tasks |

Trust the parse, not the prose: item counts, hierarchy and line numbers come from the
file. If `max_depth` looks wrong (mixed tabs and spaces make depth ambiguous), say so in
the triage table instead of guessing.

## Step 2 — Split clusters before planning

One goal covers **one coherent cluster**. Two unrelated sections are two goals, planned
and approved separately — a mega-goal spanning a whole `todo.md` cannot have a coherent
PRD objective or non-goals.

More than one candidate cluster → emit gate **G-G0-backlog-scope** and let the developer
pick. Items outside the chosen cluster are not "later tasks": they are simply not in
this goal (record them as `out-of-cluster` in the triage table).

## Step 3 — Triage every item

Each parsed item gets exactly one disposition. This table is the deliverable of intake:

| Disposition | Means | Becomes |
| --- | --- | --- |
| `ready` | outcome and boundary are clear enough to verify | task (or step, if it has children) |
| `vague` | shorthand or open-ended: "e tals", "e tudo mais", "ajustar", "melhorar", "revisar", "etc" | one batched question, else a `spike` |
| `oversized` | is a project, not a task ("configurar para agents e skills serem específicos do fluxo") | step with its own tasks, or its own goal |
| `spike` | needs investigation or a decision before implementation | task whose deliverable is a **written artifact** under `evidence/`, never code |
| `developer-action` | only the developer can do it ("vou ter q desenhar isso", credentials, external approval) | blocker recorded in the plan; the goal either waits or proceeds under a stated assumption |
| `done` | `checked: true` | reported, never re-planned |
| `duplicate` | same outcome as another item | merged, with both item ids cited |
| `out-of-cluster` | belongs to another goal | listed, not planned |

Hard rule: **an item never disappears.** By the end of intake, every `I##` appears in the
triage table with a disposition, and every non-`done` disposition is traceable to a task,
a blocker, or `state.yaml → followups`. The validator audits exactly this.

## Step 4 — Batch the questions

A 15-item list must not become 15 questions. Group by theme, ask at most **4** in one
`AskUserQuestion`, and always carry a default so silence still yields a decision:

- boundary questions ("`validar se todas envs estão corretas` — quais superfícies? projeto / k8s / postStart / todas?")
- decision questions ("`definições de camadas` — você desenha antes, ou o kit propõe e você aprova?")
- ordering questions when the list implies a dependency it does not state

Answers are folded into the PRD (assumptions in §5, questions closed in §8, item →
disposition in the triage table). Never leave a `vague` item as a task: either the answer
sharpened it, or it is a `spike`, or it leaves the goal.

## Step 5 — Map items to steps and tasks

- parent with ≥2 children → **step**; its children → tasks of that step
- leaf without siblings → task inside the step of the nearest parent, or a step of its own when nothing else relates to it
- `notes` → the task's "Ler antes" and acceptance criteria; a note that implies work of its own is promoted to an item in the triage table (with a reason), not silently expanded into a task
- an `oversized` item that became a step must declare its own validation command
- dependency inference: a `spike` or `developer-action` always precedes the items that consume it; record it in `plan.md § Ordem de integração` and in `depends_on`

Every task file carries `source_ref: { file, item_id, line, text }` in its frontmatter —
that is what makes write-back and the coverage audit possible.

## Step 6 — Write completion back to the source

Only after the developer approves it at closure (token `ailfred-accept-sync`), one call per
completed item:

```bash
bash "$AF/scripts/ailfred-todo-sync.sh" <file> --line <N> --expect "<substring do texto>" --check
```

- `--dry-run` first when more than three items will be ticked; show the developer the list.
- Exit `3` = drift (the developer edited the file meanwhile): **re-parse** and use the new line, never force the old one.
- Only items whose tasks are all `done` get ticked. Partially done parent → stays unchecked, and the report says which child is missing.
- `source.writeback: false` (pasted list) → skip this step and report the completed items as a checklist in the closing message instead.

## Anti-patterns

- Reading the list "by eye" and inventing item ids instead of running the parser.
- One goal for a whole `todo.md` spanning unrelated sections.
- Turning a `vague` item into a task with acceptance criteria like "ajustado corretamente".
- Turning a `note` into a task, or dropping notes on the floor.
- Asking one question per item; asking without a default.
- Implementing a `developer-action` item on the developer's behalf.
- Ticking a checkbox for a task that ended `blocked`, or ticking a parent whose children are not all done.
- Forcing a write-back after an exit-3 drift, or rewriting/reformatting the source file (only the single checkbox line may change).
- Re-planning items already `checked: true`.
