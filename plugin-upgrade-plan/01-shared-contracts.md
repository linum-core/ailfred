# 01 · Contratos compartilhados (leitura obrigatória em toda janela)

> ✅ **EXECUTADO em 2026-08-19.** Aplicado ao plugin: `templates/ailfred/state.yaml` ganhou
> `execution_mode: single|loop|parallel|graph`, `mode_reason`, `validation`, blocos
> `project:` e `board:`, e a tabela de gates como comentário. Vocabulário renomeado em
> commands/agents/skills (`sequential`→`single`, `worktrees`→`parallel`; tokens
> `ailfred-exec-single|parallel|later`). Gates realinhados: `G-G6-goal-closure` →
> `G-G5-deliver`; o fechamento de step virou `G-S-step-closure` (interno, fora da escada
> numerada). `board.yaml` e `ailfred-migrate-state.sh` continuam com o prompt 03.

> **Como usar:** cole este arquivo inteiro no topo de *qualquer* janela que execute um
> prompt `02`–`10`. Ele é referência, não tarefa: nenhum arquivo é criado a partir daqui.

## 1. Layout de caminhos (canônico)

```
${CLAUDE_PLUGIN_ROOT}/                  # o plugin, autocontido
  commands/  agents/  skills/  scripts/  templates/ailfred/

<projeto>/.claude/ailfred/<goal-slug>/  # runtime de UM goal, versionável
  PRD.md  plan.md  state.yaml  board.yaml  REVIEW.md
  tasks/<SNN-TNN>.md
  reports/<SNN-TNN>.md
  source-list.md  source-items.yaml     # só em modo lista

~/.claude/ailfred/                      # memória, fora do repo, nunca commitada
  registry.yaml                         # v2 — índice de projetos/contas (prompt 10)
  project/<project-slug>/
    config.yaml                         # overrides do projeto (prompt 06)
    memory/                             # vault Obsidian (prompt 02)
      MOC.md
      architecture/  decisions/  goals/  surfaces/  pitfalls/
      .obsidian/                        # opcional, criado só se dev abrir o vault
```

**`<project-slug>`** = `basename` do toplevel git, kebab-case, sufixado com os 8 primeiros
caracteres do SHA-1 do caminho absoluto — evita colisão entre dois repos de mesmo nome:

```bash
root="$(git rev-parse --show-toplevel)"
slug="$(basename "$root" | tr '[:upper:] ' '[:lower:]-' | tr -cd 'a-z0-9-')"
hash="$(printf '%s' "$root" | shasum | cut -c1-8)"
project_slug="${slug}-${hash}"
```

Toda geração desse slug **passa por `scripts/ailfred-project-slug.sh`** (criado no prompt 02).
Nenhum outro arquivo reimplementa essa lógica.

## 2. `state.yaml` — campos novos do v0.2

Mantém tudo do v0.1. Acrescenta:

```yaml
goal:
  # ... campos existentes ...
  execution_mode: null   # single | loop | parallel | graph   (era: sequential|worktrees)
  mode_reason: null      # uma frase: por que este modo foi escolhido
  validation: null       # full | checkpoints | autonomous    (prompt 05)

project:
  slug: null             # <project-slug>, ver seção 1
  memory_path: null      # ~/.claude/ailfred/project/<slug>/memory
  memory_synced_at: null # ISO8601 da última escrita de memória

board:
  path: board.yaml
  wip_limit: 3
  updated_at: null
```

**Migração:** `execution_mode: sequential` → `single`; `worktrees` → `parallel`. Um script
`scripts/ailfred-migrate-state.sh` faz isso in-place e é idempotente (prompt 03 entrega).

## 3. `board.yaml` — fonte única do Kanban

Uma task existe em **dois** lugares: `tasks/<id>.md` (o contrato, escrito pelo architect)
e `board.yaml` (a posição no fluxo, escrita pelo host). Nunca duplique conteúdo entre eles —
o board guarda só o que muda com o tempo.

```yaml
version: 1
wip_limit: 3
columns: [backlog, ready, in_progress, blocked, review, done]
cards:
  - id: S01-T02
    column: in_progress
    step: S01
    wave: 1
    title: "curto, o mesmo do front-matter da task"
    size: S
    parallel: safe
    depends_on: [S01-T01]
    assignee: ailfred-task-worker   # ou "host"
    worktree: null
    branch: null
    blocked_by: null                # texto livre quando column=blocked
    moved_at: 2026-08-19T10:00:00Z
    history:
      - { at: 2026-08-19T09:40:00Z, from: ready, to: in_progress }
```

**Regras de coluna:**
- `backlog` → `ready` exige `depends_on` todos em `done`.
- `ready` → `in_progress` exige `count(in_progress) < wip_limit`.
- `in_progress` → `review` exige `reports/<id>.md` existir.
- `review` → `done` exige evidência registrada; em `validation: full`, exige token de gate.
- Qualquer coluna → `blocked` exige `blocked_by` preenchido.

## 4. Gates — nomenclatura estável

| id | Momento | Token |
| --- | --- | --- |
| `G-G0-backlog-scope` | escolha de cluster (modo lista) | `ailfred-scope-approve` |
| `G-G0b-backlog-triage` | triagem dos itens | `ailfred-triage-approve` |
| `G-G1-grill` | perguntas do grill respondidas | `ailfred-grill-done` |
| `G-G2-prd` | PRD aprovado | `ailfred-prd-approve` |
| `G-G3-plan` | plano + tasks aprovados | `ailfred-plan-approve` |
| `G-G4-execute` | liberação para executar | `ailfred-execute-approve` |
| `G-G5-deliver` | entrega / merge | `ailfred-deliver-approve` |

Registro em `state.yaml → gates[]`: `{ id, token, at, skipped_by_policy: bool }`.

## 5. Ordem de precedência de configuração

```
1. flag na invocação do comando        (--mode graph)
2. .claude/ailfred/<slug>/config.yaml  (por goal)
3. .claude/ailfred/config.yaml         (por repo, versionável)
4. ~/.claude/ailfred/project/<slug>/config.yaml (por repo, local, não versionado)
5. ${CLAUDE_PLUGIN_ROOT}/templates/ailfred/config.yaml (default do plugin)
```

Resolução por `scripts/ailfred-config.sh get <chave>` (prompt 06). **O host nunca lê YAML
de config com os próprios olhos** — chama o script e usa a saída.

## 6. Orçamento de token (metas duras)

| Fluxo | Orçamento do host | Subagents permitidos |
| --- | --- | --- |
| task única trivial | ≤ 8k | 0 |
| goal pequeno (1 step, ≤3 tasks) | ≤ 25k | 1 (architect) |
| goal médio | ≤ 60k | 1 architect + N workers |
| goal grande / graph | sem teto rígido | architect + runner + workers |

Se um prompt de construção fizer o host ler mais de 2 arquivos `.md` do plugin num fluxo
simples, o design está errado — vire config.

## 7. Estilo dos artefatos que você vai escrever

- Front-matter YAML em toda skill/agent/command, com `name` e `description` acionáveis.
- Instruções em **inglês**; exemplos de saída ao dev em **português**.
- Sem prosa motivacional. Tabela > parágrafo. Comando exato > descrição de comando.
- Todo script: `#!/usr/bin/env bash`, `set -euo pipefail`, `usage()` e saída legível por
  máquina (uma linha `chave=valor` ou YAML), nunca texto decorado.
- Todo script é idempotente e roda fora de sessão Claude (testável em terminal).
