---
name: ailfred-memory
description: Use when an Ailfred goal starts, closes, or reports a durable finding — reads and writes the per-repository memory vault so the second goal in a repo costs less than the first.
---

# Ailfred — per-repository memory

The vault lives at `~/.claude/ailfred/project/<project-slug>/memory/`, **outside** the
user's repository. Plain markdown with front-matter and `[[wiki-links]]`; Obsidian is an
optional reader and is never required or installed.

Everything goes through scripts. Never hand-craft a note file, never edit `MOC.md`.

```bash
AF="${CLAUDE_PLUGIN_ROOT:-./ailfred}"
bash "$AF/scripts/ailfred-memory-init.sh"                       # CREATED|EXISTS <path>
bash "$AF/scripts/ailfred-memory-read.sh" --max-notes 12 --tags auth,build
bash "$AF/scripts/ailfred-memory-write.sh" --type decision \
     --title "..." --tags a,b --body-file <path> [--goal-slug S] [--supersedes "titulo"]
```

## Note types

| Pasta | Tipo | Responde | Quem propõe |
| --- | --- | --- | --- |
| `architecture/` | `architecture` | como este repo é montado (camadas, build, testes) | architect, após discovery |
| `decisions/` | `decision` | escolha tomada, porquê, alternativa descartada | host, após um gate |
| `goals/` | `goal` | o que um goal entregou, com slug e data | host, ao fechar o goal |
| `surfaces/` | `surface` | arquivo/módulo quente: o que é, quem toca, armadilha | architect ou worker |
| `pitfalls/` | `pitfall` | algo que quebrou e como não repetir | worker, ao registrar falha |

Corpo de nota: **um fato**, 3–10 linhas, seguido de `**Por quê:**` e `**Como aplicar:**`.
Uma nota que precisa de dois "porquês" são duas notas.

## Single writer

Subagents **propõem**, o host **aplica**. O architect devolve no handoff:

```yaml
memory_notes:
  - { type: architecture, title: "...", tags: [build], confidence: high, body: "..." }
```

O host chama `memory-write.sh` uma vez por item. Nenhum subagent escreve no vault —
mesma invariante do `state.yaml`.

## Dedup e supersede

`type` + `title` iguais → o arquivo existente é reescrito, `created` preservado e
`updated` atualizado (saída `UPDATED`). Fato mudou? Reescreva a nota. Fato foi
substituído por outro conceito? Nota nova com `supersedes: "titulo antigo"`.

Antes de propor uma nota, olhe o pacote de leitura: se o título já existe, é update.

## A economia principal

`ailfred-memory-read.sh` devolve `architecture_fresh_days`.

- `null`, ou `> capability_scan_ttl_days` (default 30) → rode `ailfred-capability-scan.sh`
  e proponha/atualize a nota `architecture`.
- `<= 30` → **não rode o scan**. A memória já responde. Essa linha é o motivo de a
  memória existir.

## Fluxo

1. `/ailfred` Passo 1, mesmo turno do scaffold: `memory-init.sh`, depois
   `memory-read.sh --max-notes 12 > .claude/ailfred/<slug>/memory-context.yaml`.
2. Host grava `project.slug` e `project.memory_path` em `state.yaml` e passa ao architect
   **o caminho** do `memory-context.yaml` — nunca o conteúdo colado no prompt.
3. Quem precisa de uma nota inteira abre o `path` que veio no pacote. O pacote é índice,
   não conteúdo.
4. Ao fechar o goal (`status: done`): uma nota `goal` e uma `decision` por gate cuja
   escolha não foi óbvia. Atualize `project.memory_synced_at`.

## O que nunca vai para a memória

- Segredo, token, senha, chave, `.env`, string de conexão — em nenhuma forma, nem
  "mascarada". Se a nota precisa citar credencial, cite **o nome da variável**.
- Trecho longo de código proprietário. Aponte `caminho:linha`; o código vive no repo.
- Dado pessoal de terceiro, conteúdo de cliente, log bruto.
- Histórico de sessão. Nota é fato durável, não diário: "tentei X, depois Y, depois Z"
  não é nota; "Y não funciona porque W" é.
- Suposição não verificada. Sem evidência → `confidence: low` ou nada.

## Anti-patterns

- Escrever nota no repo do usuário ou commitar o vault.
- Criar `.obsidian/` — quem quiser abre o vault no Obsidian por conta própria.
- Despejar o vault no prompt em vez de usar `memory-read.sh`.
- Nota de título genérico ("arquitetura", "notas") — o título é a chave de dedup.
