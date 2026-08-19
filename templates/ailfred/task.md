---
id: SNN-TNN
step: SNN
goal_slug: "{{SLUG}}"
title: "<verbo + resultado>"
status: pending # pending | in_progress | blocked | done | skipped
size: S # S (<=~3 arquivos) | M (<=~6 arquivos) — L é proibido: fatiar
parallel: safe # safe | unsafe
parallel_reason: "<por que é seguro ou não>"
depends_on: []
scope_allowlist:
  - "<glob ou caminho que o worker PODE escrever>"
skills: [] # skills que o worker deve carregar (só as necessárias)
worktree: null
branch: null
# Só quando o goal veio de uma lista de to-dos: âncora do item de origem.
# `line` + `text` são o par usado no write-back do checkbox (guarda contra drift).
source_ref: null # { file: todo.md, item_id: I15, line: 25, text: "<trecho exato>" }
---

# SNN-TNN — <título>

## Objetivo

<Uma frase. O que passa a ser verdade quando esta task fecha.>

## Ler antes (contexto mínimo)

- `<caminho>` — <por que>

## Passos de implementação

1. <ação concreta em caminho concreto>

## Critérios de aceite

- [ ] <verificável, objetivo — sem "melhorar", "ajustar", "revisar">

## Evidências (comandos exatos)

```bash
<comando de validação desta task>
```

## Notas de execução

<Preenchido pelo `ailfred-task-worker`: o que mudou, o que não deu, saída resumida
das evidências, desvios do plano e por quê.>
