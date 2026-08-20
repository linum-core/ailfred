# 02 · Prompt — Memória por repositório (vault Obsidian)

> ✅ **EXECUTADO em 2026-08-19.** Entregues: `scripts/ailfred-project-slug.sh`,
> `ailfred-memory-init.sh`, `ailfred-memory-read.sh`, `ailfred-memory-write.sh`,
> `templates/ailfred/memory/` (MOC + 5 notas), `skills/ailfred-memory/SKILL.md` (90 linhas).
> Integrado em `commands/ailfred.md` (Passo 1 e 1L, capability-scan condicionado a
> `architecture_fresh_days > 30`), `commands/ailfred-execute.md` (Passo 7 alimenta a
> memória no fechamento) e `agents/ailfred-architect.md` (lê `memory_context_path`,
> devolve `memory_notes[]`). DoD verificado em terminal: CREATED/EXISTS, WROTE/UPDATED,
> 50 notas → 12 devolvidas (~1.3k tokens), MOC com 50 linhas e 0 duplicatas.

> Janela limpa. Cole `01-shared-contracts.md` antes deste arquivo. Não leia os outros prompts.

## Missão

Dar ao Ailfred memória persistente **por repositório**, gravada como um vault Obsidian
legível por humano em `~/.claude/ailfred/project/<project-slug>/memory/`, de modo que o
segundo goal num repo custe menos que o primeiro.

## Problema concreto que isso resolve

Hoje `ailfred-capability-scan.sh` roda a cada goal e o architect redescobre a mesma
arquitetura toda vez. Convenções decididas no goal A não chegam ao goal B. Erros
repetem.

## Escopo — arquivos que você cria

```
scripts/ailfred-project-slug.sh      # resolve <project-slug>; fonte única da lógica
scripts/ailfred-memory-init.sh       # cria vault + MOC se não existir; idempotente
scripts/ailfred-memory-read.sh       # devolve pacote de contexto comprimido p/ o host
scripts/ailfred-memory-write.sh      # grava/atualiza uma nota; nunca duplica
templates/ailfred/memory/MOC.md
templates/ailfred/memory/note-architecture.md
templates/ailfred/memory/note-decision.md
templates/ailfred/memory/note-goal.md
templates/ailfred/memory/note-surface.md
templates/ailfred/memory/note-pitfall.md
skills/ailfred-memory/SKILL.md
```

E **edita**: `commands/ailfred.md` (Passo 1 chama memory-init + memory-read),
`agents/ailfred-architect.md` (recebe pacote de memória; devolve notas propostas).

## Modelo de dados

Cada nota = um arquivo `.md` com front-matter, um fato, links `[[wiki]]`. Cinco tipos:

| Pasta | Tipo | Responde | Quem escreve |
| --- | --- | --- | --- |
| `architecture/` | `architecture` | como este repo é montado (camadas, build, testes) | architect após discovery |
| `decisions/` | `decision` | escolha tomada + porquê + alternativa descartada | host após um gate |
| `goals/` | `goal` | o que um goal entregou, com slug e data | host ao fechar goal |
| `surfaces/` | `surface` | arquivo/módulo quente: o que é, quem toca, armadilha | architect / worker |
| `pitfalls/` | `pitfall` | algo que quebrou e como não repetir | worker ao registrar falha |

Front-matter obrigatório:

```yaml
---
type: architecture | decision | goal | surface | pitfall
title: "frase curta e específica"
created: 2026-08-19
updated: 2026-08-19
goal_slug: <slug ou null>
confidence: high | medium | low
tags: [build, testing, auth]
supersedes: null   # título de nota que esta substitui
---
```

Corpo: **um fato**, 3–10 linhas. Depois `**Por quê:**` e `**Como aplicar:**`. Links
`[[titulo-da-nota]]` à vontade — link para nota inexistente é sinal de trabalho futuro,
não erro.

`MOC.md` é o índice (Map of Content): uma linha por nota, agrupada por tipo,
`- [[titulo]] — gancho de uma linha`. `ailfred-memory-write.sh` atualiza o MOC no mesmo
comando em que grava a nota. **MOC nunca contém conteúdo**, só ponteiros.

## Contrato dos scripts

```bash
ailfred-project-slug.sh                     # stdout: <project-slug>
ailfred-memory-init.sh                      # cria árvore + MOC; stdout: CREATED|EXISTS <path>
ailfred-memory-read.sh [--tags a,b] [--max-notes N] [--type T]
    # stdout: YAML compacto — só front-matter + primeira linha do corpo de cada nota
    # default --max-notes 12, ordenado por updated desc
ailfred-memory-write.sh --type T --title "..." --tags a,b --body-file <path> \
    [--goal-slug S] [--supersedes "titulo"]
    # dedup: se existir nota do mesmo type+title, faz UPDATE (bump updated) em vez de criar
    # stdout: WROTE <path> | UPDATED <path>
```

`memory-read.sh` é a peça de custo: ele **não despeja o vault**. Devolve no máximo ~1.5k
tokens. Se o vault for maior, corta por `updated` e por match de tags contra o objetivo.

## Integração no fluxo

1. `/ailfred` Passo 1, mesmo turno do scaffold:
   ```bash
   bash "$AF/scripts/ailfred-memory-init.sh"
   bash "$AF/scripts/ailfred-memory-read.sh" --max-notes 12 > .claude/ailfred/<slug>/memory-context.yaml
   ```
2. O host grava `project.slug` e `project.memory_path` em `state.yaml` e **passa o caminho**
   `memory-context.yaml` ao architect — não o conteúdo colado no prompt.
3. `ailfred-capability-scan.sh` só roda se a memória **não** tiver nota `architecture` com
   `updated` nos últimos 30 dias. Essa é a economia principal: registre-a no SKILL.
4. O architect devolve, no handoff, `memory_notes[]` — propostas de nota. **O host aplica**
   chamando `memory-write.sh`. Architect não escreve no vault (mantém escritor único).
5. Ao fechar um goal (`status: done`), host grava uma nota `goal` e uma `decision` por gate
   que teve escolha não-óbvia.

## Anti-requisitos

- Não instalar Obsidian, não exigir Obsidian. O vault é markdown puro; Obsidian é só um
  leitor opcional. `.obsidian/` não é criado pelo plugin.
- Não commitar memória no repo do usuário. Ela vive em `~/.claude/ailfred/`.
- Não gravar segredo, token, `.env` ou trecho de código proprietário longo na memória —
  o SKILL precisa de uma seção **"o que nunca vai para a memória"** explícita.
- Não deixar a memória virar log: nota é fato durável, não histórico de sessão.

## Definição de pronto

- [ ] `bash scripts/ailfred-memory-init.sh` duas vezes seguidas → `CREATED` depois `EXISTS`
- [ ] `memory-write.sh` com mesmo type+title duas vezes → `WROTE` depois `UPDATED`, um arquivo só
- [ ] `memory-read.sh` num vault de 50 notas devolve ≤ 12 notas e ≤ ~1.5k tokens
- [ ] MOC lista toda nota existente, sem órfã e sem duplicata
- [ ] `/ailfred` num repo com memória fresca **não** roda capability-scan
- [ ] `skills/ailfred-memory/SKILL.md` cabe em < 120 linhas
