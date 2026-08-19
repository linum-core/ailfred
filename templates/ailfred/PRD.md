---
goal_slug: "{{SLUG}}"
title: "{{TITLE}}"
created: {{DATE}}
base_branch: "{{BRANCH}}"
status: rascunho # rascunho | aprovado
prd_version: 1
---

# PRD — {{TITLE}}

> Preenchido pelo agent `ailfred-architect` (modo `discover+prd`). Aprovado pelo
> desenvolvedor no gate **G-G2**. Depois de aprovado, mudança de escopo exige nova
> versão (`prd_version`) e novo gate — não se edita PRD aprovado em silêncio.

## 1. Objetivo

<Uma frase. Resultado observável, não atividade. "X passa a fazer Y", não "mexer em X".>

## 2. Contexto — por que agora

<2–5 linhas: o que dói hoje, o que dispara este trabalho, o que já existe.>

## 3. Fora de escopo (non-goals)

- <coisa vizinha que NÃO será feita — quanto mais explícito, menos deriva>

## 4. Critérios de sucesso

Cada critério precisa ser verificável por comando, arquivo ou observação direta.
Se não der para verificar, não é critério — é desejo.

| # | Critério | Como verificar |
| - | -------- | -------------- |
| 1 | <...>    | `<comando ou observação>` |

## 5. Restrições e invariantes

- <regras do repositório que continuam valendo (ex.: `CLAUDE.md`, `AGENTS.md`)>
- <o que não pode quebrar / contratos públicos / arquivos que não podem mudar>

## 6. Superfícies afetadas

Descoberta limitada — só o que foi realmente lido, com caminho real.

| Caminho / módulo | O que muda | Risco |
| ---------------- | ---------- | ----- |
| `<path>`         | <...>      | baixo / médio / alto |

## 7. Riscos e mitigações

| Risco | Impacto | Mitigação | Vira task? |
| ----- | ------- | --------- | ---------- |

## 8. Perguntas abertas

Nenhuma pergunta pode ficar aberta quando o PRD for aprovado — ou é respondida no
gate, ou vira premissa registrada aqui, ou vira task de investigação (spike).

- [ ] <pergunta> → <premissa assumida se não respondida>

## 9. Capacidades a reutilizar

Saída de `bash .claude/scripts/ailfred-capability-scan.sh` filtrada. Toda capacidade
candidata precisa de veredito explícito — usar ou descartar com motivo.

| Capacidade | Escopo | Veredito e motivo |
| ---------- | ------ | ----------------- |
| `<skill/agent/command>` | project / user / plugin / ref | usar em `<step/task>` — <motivo> |

## 10. Entrega e reversão

- **Como entra:** <branch, PR, commits por task>
- **Como se reverte:** <revert do merge, flag, passo manual>
- **Validação final:** <comandos que definem "pronto">
