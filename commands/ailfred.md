---
description: Breaks one large request — or an entire to-do list — into an approvable PRD plus steps and tasks, ready for sequential or worktree-parallel execution
argument-hint: <objetivo em uma frase | lista de to-dos | --from <arquivo> [--section "<título>"] | --continue | --list>
---

# Goal — plan (`/ailfred`)

**Comando do plugin `ailfred`** — instalado a partir do marketplace
`ailfred-marketplace` (repositório `GgvGomes/ailfred`). Autocontido: comandos, agents,
skills, scripts e templates vivem todos dentro do plugin; o runtime de cada goal fica
no projeto aberto, em `.claude/ailfred/<slug>/`.

Recebe um pedido grande demais para uma passada só — uma frase, um documento ou uma
**lista de to-dos** — e devolve: PRD aprovado, backlog de steps e tasks, e a decisão de
como executar (sequencial ou em git worktrees). Domínio-agnóstico: o pedido define o
domínio, o comando define o método.

**Read first:** skill `ailfred-decomposition`. Entrada em lista: skill `ailfred-list-intake`.
Paralelismo: skill `ailfred-worktree-execution`.
**Execução:** `/ailfred-execute`. **Progresso:** `/ailfred-status`.

**Scripts do kit** — resolva o root do plugin uma vez por sessão e depois use `$AF`:

```bash
AF="${CLAUDE_PLUGIN_ROOT:-./ailfred}"   # instalado → cache do plugin; dev neste repo → ./ailfred
```

## Invariantes

- **Escritor único de `state.yaml`: o host.** Subagents devolvem handoff; o host aplica.
- **Escritor único de PRD/plan/tasks: `ailfred-architect`.** O host não corrige plano inline — rejeita com a violação nomeada e respawna.
- **Nenhum gate é presumido.** Sem token do desenvolvedor no `state.yaml`, o passo seguinte não roda.
- **Descoberta não acontece no host.** No máximo `git status`, `git branch --show-current` e leitura de `CLAUDE.md` / `AGENTS.md`. O resto é do `ailfred-architect`.
- **Saída para o desenvolvedor em português**; arquivos de instrução do plugin em inglês. Se o projeto aberto declarar uma política de idioma própria (`CLAUDE.md`, `AGENTS.md`, skills), ela vence.
- Sem commit, push, branch novo ou PR nesta etapa. Planejar não muda código.

## Host action

### Passo 0 — Resolver a entrada

- `$ARGUMENTS` vazio → perguntar em texto qual é o objetivo (uma frase) e **encerrar o turno**. Não inventar objetivo.
- `--list` → listar `.claude/ailfred/*/state.yaml` com `slug`, `status`, step ativo. Encerrar.
- `--continue` → escolher o goal mais recente com `status` em `planning|planned` (se houver mais de um, `AskUserQuestion` com os slugs) e retomar do último gate registrado em `gates`.
- **Modo lista (intake)** — quando qualquer um destes for verdade:
  - `--from <arquivo>` (aceita `--section "<título>"` e `--pending-only`);
  - `$ARGUMENTS` é caminho de arquivo que contém linhas `- [ ]`;
  - o texto colado tem duas ou mais linhas de checklist.

  Nesse caso siga o **Passo 1L** em vez do Passo 1. Texto colado: gravar verbatim em
  `.claude/ailfred/<slug>/source-list.md` antes de parsear (fixa os números de linha) e
  registrar `source.writeback: false`.
- Caminho de arquivo **sem** checklist → ler o arquivo; ele é a fonte do objetivo (modo frase).
- Caso contrário → o texto é o objetivo.

Derivar `slug`: kebab-case, no máximo 5 palavras, sem data. Em modo lista, derivar do
cluster escolhido (ex.: `ajustes-execute-home`), não do nome do arquivo.

### Passo 1 — Scaffold + scan (mesmo turno, sem texto intermediário)

```bash
bash "$AF/scripts/ailfred-scaffold.sh" <slug> "<título>"
bash "$AF/scripts/ailfred-capability-scan.sh"
```

`EXISTS:` no scaffold significa goal já iniciado → seguir como `--continue`.

### Passo 1L — Intake de lista (só no modo lista, mesmo turno)

**Read first:** skill `ailfred-list-intake` — ela define o contrato do parse, a taxonomia de
triagem e o protocolo de write-back. O host não interpreta a lista a olho.

```bash
bash "$AF/scripts/ailfred-scaffold.sh" <slug> "<título>"
bash "$AF/scripts/ailfred-todo-parse.sh" <arquivo> [--section "<título>"] --pending-only \
  > .claude/ailfred/<slug>/source-items.yaml
bash "$AF/scripts/ailfred-capability-scan.sh"
```

`--pending-only` é o default: item `- [x]` já está feito, entra só no relatório.

Gravar em `state.yaml → source`: `file`, `parsed_at`, `section`, `writeback` (true para
arquivo do repositório, false para lista colada), `items_total`, `items_pending`.

Havendo mais de um cluster candidato (seções diferentes no parse) → gate
**G-G0-backlog-scope** antes de qualquer subagent.

Em seguida, spawn do architect em modo intake:

```text
Agent(subagent_type="ailfred:ailfred-architect")
mode: intake
goal_slug: <slug>
source_items_path: .claude/ailfred/<slug>/source-items.yaml
source_file: <arquivo>
cluster: <seção escolhida ou "todas">
capability_scan: <saída do scan, filtrada pelo host>
repo_contracts: [CLAUDE.md, AGENTS.md, .claude/rules/]
prd_path: .claude/ailfred/<slug>/PRD.md
```

Retorno: tabela de triagem (um `I##` por linha com disposição), clusters, perguntas
agrupadas e bloqueios `developer-action`. Depois vem o gate **G-G0b-backlog-triage** e,
só então, o fluxo normal (PRD → G-G2 → decomposição → G-G3 → G-G4).

### Passo 2 — Discovery + PRD (subagent)

```text
Agent(subagent_type="ailfred:ailfred-architect")
mode: discover+prd
goal_slug: <slug>
goal_statement: <objetivo verbatim do desenvolvedor>
goal_source_path: <caminho, se a entrada foi arquivo>
capability_scan: <saída do scan, filtrada pelo host para o que é plausível>
repo_contracts: [CLAUDE.md, AGENTS.md, .claude/rules/]
prd_path: .claude/ailfred/<slug>/PRD.md
```

Retorno esperado: resumo comprimido (objetivo, critérios, non-goals, superfícies,
riscos, capacidades escolhidas) + `open_questions[]`. Nada de PRD colado no chat.

### Passo 3 — Gate G-G1 (só se houver `open_questions`)

`AskUserQuestion` com até 4 perguntas, cada uma com as opções que o architect propôs
mais a premissa default. Encaminhar as respostas ao `ailfred-architect` (mesmo modo,
`answers:`) para ele atualizar o PRD — o host não edita o PRD.

### Passo 4 — Gate G-G2 (aprovação do PRD)

Emitir o bloco do § Gate registry + `AskUserQuestion`.

- `ailfred-prd-approve` → registrar o token em `state.yaml → gates` e seguir para o Passo 5. A marcação `PRD.md → status: aprovado` vai no briefing do próximo spawn: quem edita o PRD é o `ailfred-architect`.
- `ailfred-prd-revise` → respawn `ailfred-architect` com o ajuste pedido; repetir o gate.
- `ailfred-cancel` → `state.yaml → status: cancelled`. Encerrar.

### Passo 5 — Decomposição (subagent)

```text
Agent(subagent_type="ailfred:ailfred-architect")
mode: decompose
goal_slug: <slug>
prd_path: .claude/ailfred/<slug>/PRD.md
plan_path: .claude/ailfred/<slug>/plan.md
tasks_dir: .claude/ailfred/<slug>/tasks/
project_validation: <comandos reais do projeto: package.json scripts etc.>
source_items_path: .claude/ailfred/<slug>/source-items.yaml   # só no modo lista
```

No modo lista, cada task nasce com `source_ref` no frontmatter e o plano ganha o
rastreio `item → task`. Item sem task, sem bloqueio e sem follow-up é violação —
entra na lista de rejeição do Passo 5.

Retorno: tabela de steps, mapa de ondas com `scope_allowlist` por task, rastreio
PRD §4 → tasks, e tasks de base.

**Conferir a lista de rejeição** da skill `ailfred-decomposition` antes de mostrar
qualquer coisa ao desenvolvedor. Violação → respawn nomeando a violação (máximo 2
tentativas; na terceira, levar ao desenvolvedor as opções de fatiamento).

### Passo 6 — Gate G-G3 (aprovação do plano)

`ailfred-plan-approve` → escrever `steps[]` e `tasks[]` em `state.yaml`, `status: planned`,
registrar o token. `ailfred-plan-revise` → respawn com o ajuste. `ailfred-cancel` → encerrar.

### Passo 7 — Gate G-G4 (modo de execução)

Recomendar o modo com base no plano (existe onda com ≥2 tasks `parallel: safe` e
escopos disjuntos? então `worktrees` é candidato — critérios completos na skill
`ailfred-worktree-execution`).

- `ailfred-exec-sequential` / `ailfred-exec-worktrees` → gravar `execution_mode` e invocar `/ailfred-execute <slug>` **no mesmo turno**.
- `ailfred-exec-later` → gravar `execution_mode` e encerrar informando `/ailfred-execute <slug>`.

Se o branch atual for `main`, oferecer criar `goal/<slug>` como parte deste gate —
execução em `main` só com escolha explícita do desenvolvedor.

## Gate registry

Todos os blocos são emitidos verbatim em português; `option.id` = token; token
aprovado vai para `state.yaml → gates`.

### G-G0-backlog-scope (só no modo lista, quando há mais de um cluster)

```
Backlog lido — <arquivo> (<n> itens pendentes, <n> já marcados)

Clusters encontrados:
  - <seção A>: <n> itens (<títulos curtos>)
  - <seção B>: <n> itens

Um goal cobre um cluster coerente. Quais entram NESTE goal?

Opções (multiSelect):
  - id: ailfred-list-scope   label: <nome do cluster>   (uma opção por cluster)
  - id: ailfred-cancel       label: Cancelar
```

### G-G0b-backlog-triage (só no modo lista)

Emitido depois do architect em `mode: intake`. Traz a tabela de triagem inteira e, no
mesmo turno, as perguntas agrupadas (no máximo 4, cada uma com default).

```
Triagem do backlog — <n> itens do cluster <cluster>

| Item | Texto (curto) | Disposição | Vira |
| ---- | ------------- | ---------- | ---- |
| I13  | Ajustes com base no execute… | oversized | step S01 |
| I15  | Ajustar pra seguir os padrões… | vague | pergunta 1 |
| I15n | definições de camadas (nota) | developer-action | bloqueio B1 |

Prontos: <n>   Vagos: <n>   Spikes: <n>   Bloqueios do desenvolvedor: <n>
Fora do cluster: <n>   Já feitos: <n>

Bloqueios que travam itens: <lista ou nenhum>

Aprovar a triagem e seguir para o PRD?

Opções:
  - id: ailfred-triage-approve  label: Aprovar triagem
  - id: ailfred-triage-revise   label: Revisar (digo o que muda)
  - id: ailfred-cancel          label: Cancelar o goal
```

Respostas das perguntas agrupadas voltam ao `ailfred-architect` (mesmo modo, `answers:`)
antes do PRD. Nenhum item `vague` sobrevive como task: ou virou preciso, ou virou spike,
ou saiu do goal.

### G-G2-prd-approval

```
PRD pronto para revisão — .claude/ailfred/<slug>/PRD.md

Objetivo: <uma linha>
Critérios de sucesso: <n> (cada um com verificação)
Fora de escopo: <n itens>
Superfícies afetadas: <n caminhos>
Riscos altos: <lista curta ou nenhum>
Capacidades reutilizadas: <skills/agents escolhidos>
Premissas assumidas: <lista ou nenhuma>
Itens do backlog cobertos: <n/n>   (só no modo lista)

Aprovar o PRD e seguir para a decomposição em steps/tasks?

Opções:
  - id: ailfred-prd-approve   label: Aprovar PRD
  - id: ailfred-prd-revise    label: Revisar (digo o que muda)
  - id: ailfred-cancel        label: Cancelar o goal
```

### G-G3-plan-approval

```
Plano pronto para revisão — .claude/ailfred/<slug>/plan.md

Steps: <n>   Tasks: <n>   Tasks de base: <n>
Ondas paralelizáveis: <lista por step, ou nenhuma>
Cobertura dos critérios do PRD: <n/n>
Validação por step: <comandos>
Maior risco de execução: <uma linha>

Aprovar o plano e liberar a execução?

Opções:
  - id: ailfred-plan-approve  label: Aprovar plano
  - id: ailfred-plan-revise   label: Revisar (digo o que muda)
  - id: ailfred-cancel        label: Cancelar o goal
```

### G-G4-execution-mode

```
Como executar o goal <slug>?

Recomendação: <sequencial | worktrees> — <motivo em uma linha>
Branch atual: <branch>
Ondas paralelizáveis: <lista ou nenhuma>
Limite de paralelismo: <max_parallel>

Opções:
  - id: ailfred-exec-sequential  label: Sequencial na árvore principal
  - id: ailfred-exec-worktrees   label: Paralelo em git worktrees
  - id: ailfred-exec-later       label: Só planejar agora
```

### G-G5-step-closure e G-G6-goal-closure

Emitidos por `/ailfred-execute` — blocos em `${CLAUDE_PLUGIN_ROOT}/commands/ailfred-execute.md § Gate registry`.

## Authorized writes

- `.claude/ailfred/<slug>/state.yaml` (host, escritor único).
- `.claude/ailfred/<slug>/` via `ailfred-scaffold.sh`.
- Nada mais. PRD, plano e tasks são escritos pelo `ailfred-architect`.

## Anti-patterns

- Decompor antes de `ailfred-prd-approve`; executar antes de `ailfred-plan-approve`.
- Host explorando o repositório, lendo módulos ou escrevendo o PRD "porque é rápido".
- Colar PRD, plano ou task inteiros no chat ou em briefing de spawn — passar caminhos e IDs.
- Pular G-G1 e "assumir" respostas sem registrar a premissa no PRD.
- Corrigir plano ruim inline em vez de rejeitar com a violação nomeada.
- Criar branch, commitar ou abrir PR na etapa de planejamento.
- Tratar `--continue` como novo goal (sobrescreve PRD aprovado).
- Marcar gate no `state.yaml` sem o token real do desenvolvedor.
