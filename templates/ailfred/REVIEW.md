---
goal_slug: "{{SLUG}}"
reviewed: null
verdict: pendente # pendente | aprovado | reprovado
---

# Review — {{TITLE}}

> Escrito pelo agent `ailfred-validator`. Julga o resultado contra o PRD, não contra
> a intenção de quem implementou.

## Critérios de sucesso (PRD §4)

| # | Critério | Verificação executada | Resultado |
| - | -------- | --------------------- | --------- |

## Validação técnica

| Checagem | Comando | Resultado |
| -------- | ------- | --------- |
| lint     | `<...>` | ok / falhou / n/a |
| types    | `<...>` | ok / falhou / n/a |
| testes   | `<...>` | ok / falhou / n/a |
| build    | `<...>` | ok / falhou / n/a |

## Escopo

- Arquivos alterados fora de `scope_allowlist` de qualquer task: <lista ou nenhum>
- Non-goals violados: <lista ou nenhum>

## Achados

| # | Severidade | Achado | Onde | Ação sugerida |
| - | ---------- | ------ | ---- | ------------- |

## Veredito

<aprovado / reprovado — e o que falta, em uma linha por item.>
