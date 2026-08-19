---
goal_slug: "{{SLUG}}"
created: {{DATE}}
status: rascunho # rascunho | aprovado
plan_version: 1
prd_version: 1
---

# Plano de execução — {{TITLE}}

> Escrito pelo agent `ailfred-architect` (modo `decompose`) a partir do PRD aprovado.
> Aprovado no gate **G-G3**. Regras de fatiamento e paralelismo: skill
> `ailfred-decomposition`.

## Steps

Um step é um marco verificável de forma independente: quando fecha, a árvore está
verde. Steps rodam em ordem de dependência; tasks dentro do step podem paralelizar.

| Step | Nome | Resultado ao fechar | Tasks | Depende de | Paralelizável | Validação do step |
| ---- | ---- | ------------------- | ----- | ---------- | ------------- | ----------------- |
| S01  | <...> | <...>              | S01-T01, S01-T02 | — | sim / não | `<comandos>` |

## Mapa de paralelismo

Tasks só são paralelas se as listas `scope_allowlist` forem disjuntas. Interseção
de escopo = serializar ou fundir as tasks.

| Step | Onda | Tasks na onda | Escopos (disjuntos) | Worktree |
| ---- | ---- | ------------- | ------------------- | -------- |
| S01  | 1    | S01-T01       | `<paths>`           | não (task de base) |
| S01  | 2    | S01-T02, S01-T03 | `<paths>` / `<paths>` | sim |

## Ordem de integração

<Em execução com worktree: em que ordem os branches voltam para a base e por quê.>

## Tasks de base (sempre primeiro, na árvore principal)

<Mudanças de que todas as outras dependem: dependências, config, tipos compartilhados,
scripts. Nunca em paralelo.>

## Rastreio PRD → plano

| Critério de sucesso (PRD §4) | Coberto por |
| ---------------------------- | ----------- |
| 1 | S01-T02, S02-T01 |

## Rastreio item → task (só quando o goal veio de uma lista)

Todo `I##` da triagem aparece aqui. Item sem task, sem bloqueio e sem follow-up é
violação do plano — é assim que uma lista de to-dos perde item em silêncio.

| Item | Texto (curto) | Disposição | Resolvido por |
| ---- | ------------- | ---------- | ------------- |
| I13  | <...>         | oversized  | step S01 |
| I15  | <...>         | spike      | S01-T02 (entrega escrita) |
| I15n | <...>         | developer-action | bloqueio B1 |

## Bloqueios do desenvolvedor

| ID | Item | O que preciso de você | Enquanto está aberto |
| -- | ---- | --------------------- | -------------------- |
| B1 | I15  | <...>                 | espera / segue com premissa <...> |

## Fora deste plano

<O que o PRD marcou como non-goal e alguém pode confundir com escopo.>
