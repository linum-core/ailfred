---
description: Reports progress of one or all goals — steps, tasks, gates, live worktrees, drift between state and disk, and the exact next action
argument-hint: [goal-slug] [--all] [--drift]
---

# Goal — status (`/ailfred-status`)

**Comando do plugin `ailfred`** — instalado a partir do marketplace
`ailfred-marketplace` (repositório `GgvGomes/ailfred`). Autocontido: comandos, agents,
skills, scripts e templates vivem todos dentro do plugin; o runtime de cada goal fica
no projeto aberto, em `.claude/ailfred/<slug>/`.

Leitura apenas. Diz onde o goal parou, o que trava e qual é o próximo comando.
Nenhum spawn, nenhuma escrita, nenhuma correção — `/ailfred-status` nunca conserta nada.

**Scripts do kit** — resolva o root do plugin uma vez por sessão e depois use `$AF`:

```bash
AF="${CLAUDE_PLUGIN_ROOT:-./ailfred}"   # instalado → cache do plugin; dev neste repo → ./ailfred
```

## Host action

1. Sem argumento: se houver um único goal em `planning|planned|executing|blocked|validating`, usar; havendo vários, listar todos em formato resumido. `--all` força a lista completa, inclusive `done` e `cancelled`.
2. Ler, do goal escolhido: `state.yaml` (fonte da verdade), `plan.md` (nomes dos steps), `steps/*-report.md` (última evidência), `REVIEW.md` (se existir).
3. Conferir disco contra estado — sempre, não só com `--drift`:
   - `bash "$AF/scripts/ailfred-worktree.sh" list <slug>` vs `state.yaml → worktrees`
   - `git status --porcelain` e `git branch --show-current`
   - tasks `done` cujo arquivo ainda tem critério de aceite desmarcado
   - tasks marcadas `done` sem seção "Notas de execução" preenchida
   - goal vindo de lista: `source.file` ainda existe? a linha de cada `source_ref` ainda casa com `text` (`ailfred-todo-parse.sh` de novo, sem escrever)? item com todas as tasks `done` e checkbox ainda `- [ ]`?
4. Emitir o relatório abaixo em português. Sem sugerir nada além do próximo comando.

## Formato do relatório

```
Goal <slug> — <título>
Status: <status>   Modo: <execution_mode>   Branch: <work_branch ou base_branch>
Criado em: <data>   PRD v<n> / plano v<n>

Gates: <tokens aprovados em ordem>

Steps
| Step | Nome | Status | Tasks done/total | Validação |

Tasks abertas
| Task | Step | Status | Tamanho | Paralela | Worktree |

Worktrees vivos
| Task | Branch | Caminho | Sujo | Integrado |

Itens da lista de origem (quando o goal veio de lista)
| Item | Texto (curto) | Disposição | Task(s) | Status | Checkbox na origem |

Divergências
- <estado x disco, ou "nenhuma">

Follow-ups
- <lista ou nenhum>

Próxima ação: <comando exato>
```

## Regras do campo "Próxima ação"

| Situação | Próxima ação |
| --- | --- |
| Sem PRD aprovado | `/ailfred --continue` |
| PRD aprovado, plano não | `/ailfred --continue` |
| Plano aprovado, sem `execution_mode` | `/ailfred --continue` (gate G-G4) |
| `planned` ou `executing` com step pendente | `/ailfred-execute <slug>` |
| `blocked` | descrever o bloqueio em uma linha, depois `/ailfred-execute <slug> --step SNN` |
| Worktree órfão | resolver primeiro: `ailfred-worktree.sh integrate` ou `remove` |
| Todos os steps `done`, sem `REVIEW.md` | `/ailfred-execute <slug>` (fecha no gate G-G6) |
| Itens fechados com checkbox pendente na origem | `/ailfred-execute <slug>` (gate G-G6 → `ailfred-accept-sync`) |
| `source_ref` com drift de linha | re-parsear antes de qualquer write-back: `ailfred-todo-parse.sh <arquivo>` |
| `done` | nada — listar follow-ups, se houver |

## Anti-patterns

- Escrever em `state.yaml`, nos relatórios ou nas tasks a partir deste comando.
- Spawnar subagent para "descobrir" o estado: o estado está em disco.
- Recomendar mais de uma próxima ação.
- Relatar progresso a partir do plano em vez do `state.yaml` e dos relatórios.
- Esconder divergência entre estado e disco por ser "detalhe".
