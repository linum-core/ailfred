# 03 · Prompt — Mini-tasks em board Kanban

> Janela limpa. Cole `01-shared-contracts.md` antes deste arquivo. Não leia os outros prompts.

## Missão

Transformar o backlog de tasks do Ailfred num **board Kanban real**: colunas, limite de WIP,
transições com pré-condição verificável, e uma visão de uma tela em `/ailfred-status`.

## Problema concreto

Hoje `state.yaml → steps[].tasks[]` guarda `status: pending|active|done`. Não existe
noção de "pronta para pegar", de bloqueio com motivo, nem de teto de trabalho simultâneo.
`/ailfred-status` reconta tudo a cada chamada.

## Escopo — arquivos que você cria

```
templates/ailfred/board.yaml
scripts/ailfred-board.sh          # toda mutação e leitura do board
scripts/ailfred-migrate-state.sh  # sequential->single, worktrees->parallel; cria board a partir de steps[]
```

E **edita**: `commands/ailfred-status.md` (passa a renderizar o board),
`commands/ailfred-execute.md` (move cards em vez de setar status solto),
`skills/ailfred-decomposition/SKILL.md` (seção nova: sizing feeds o board),
`templates/ailfred/state.yaml` (bloco `board:` do contrato).

## Schema

Use exatamente o schema de `board.yaml` da seção 3 do contrato compartilhado. Não invente
campos. Se precisar de um campo novo, adicione-o ao contrato **e** documente no SKILL.

## Contrato de `ailfred-board.sh`

Subcomandos. Todos recebem `--goal <slug>` e operam em `.claude/ailfred/<slug>/board.yaml`.

```bash
ailfred-board.sh init   --goal S --from-plan            # cria cards a partir de tasks/*.md
ailfred-board.sh list   --goal S [--column C] [--format table|yaml]
ailfred-board.sh move   --goal S --card ID --to COLUMN [--reason "..."]
ailfred-board.sh ready  --goal S                        # promove backlog->ready o que destravou
ailfred-board.sh next   --goal S [--count N]            # sugere cards pegáveis respeitando WIP
ailfred-board.sh render --goal S                        # ASCII board pronto p/ colar ao dev
ailfred-board.sh check  --goal S                        # valida invariantes; exit!=0 se quebrado
```

`move` **recusa** transição ilegal com mensagem exata e `exit 2`. Exemplos que precisam
falhar:
- mover para `in_progress` com WIP cheio → `ERR wip-limit 3 reached`
- mover para `ready` com dependência aberta → `ERR blocked-by S01-T01`
- mover para `blocked` sem `--reason` → `ERR reason-required`
- mover para `review` sem `reports/<id>.md` → `ERR report-missing`

Toda mutação anexa entrada em `history[]` e atualiza `moved_at` e `board.updated_at` no
`state.yaml`.

## Saída ao desenvolvedor (`render`)

Uma tela, português, sem cores ANSI (terminal do usuário pode não suportar):

```
ajustes-execute-home · 8 tasks · WIP 2/3

BACKLOG (3)     READY (1)      IN_PROGRESS (2)   BLOCKED (1)   REVIEW (0)   DONE (1)
S02-T01         S01-T04        S01-T02 ⇢wt       S01-T03       —            S01-T01
S02-T02                        S01-T05 ⇢host
S03-T01

BLOQUEIO  S01-T03 — aguarda credencial de staging (developer-action)
PRÓXIMA   S01-T04 (safe, wave 2) — `bash scripts/ailfred-board.sh move --card S01-T04 --to in_progress`
```

Regra: `render` cabe em ≤ 25 linhas mesmo com 40 tasks (agrupa e trunca com `+N mais`).

## Integração

- `/ailfred` após G-G3: host chama `board.sh init --from-plan`. Board nasce do plano, não à mão.
- `/ailfred-execute`: antes de despachar worker, `board.sh next` decide o que pegar; ao
  despachar, `move --to in_progress`; ao receber report, `move --to review`.
- `/ailfred-status`: chama `board.sh render` e **nada mais**. Zero releitura de tasks/*.md.
- Worker que falha devolve handoff com motivo → host faz `move --to blocked --reason "..."`.

## Relação com `state.yaml`

`state.yaml → steps[].tasks[].status` **deixa de ser fonte de verdade** e vira espelho
derivado (ou some — decida e documente). O board é a verdade. Não mantenha dois
escritores de status; isso é a falha clássica desse design.

## Anti-requisitos

- Sem banco de dados, sem SQLite. YAML + `yq`/awk. Se `yq` faltar, degrade para awk/sed e
  documente a dependência opcional.
- Sem UI web. Board é texto.
- Sem WIP ilimitado por default: `wip_limit: 3`, ajustável por config (prompt 06).

## Definição de pronto

- [ ] `board.sh check` detecta os 4 casos de transição ilegal listados acima
- [ ] `board.sh init --from-plan` num goal com 12 tasks gera 12 cards com `depends_on` corretos
- [ ] `board.sh render` com 40 tasks cabe em 25 linhas
- [ ] `migrate-state.sh` roda duas vezes sem alterar nada na segunda
- [ ] `/ailfred-status` não abre nenhum `tasks/*.md`
