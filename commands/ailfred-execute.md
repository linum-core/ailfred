---
description: Executes an approved plan step by step — dispatches task workers in single mode or in parallel git worktrees, validates each step and closes with a review against the PRD
argument-hint: <goal-slug> [--step SNN] [--task SNN-TNN] [--single|--parallel] [--max-parallel N] [--dry-run]
---

# Goal — execute (`/ailfred-execute`)

**Comando do plugin `ailfred`** — instalado a partir do marketplace
`ailfred-marketplace` (repositório `GgvGomes/ailfred`). Autocontido: comandos, agents,
skills, scripts e templates vivem todos dentro do plugin; o runtime de cada goal fica
no projeto aberto, em `.claude/ailfred/<slug>/`.

Executa o backlog aprovado por `/ailfred`: um step por vez, ondas de tasks dentro do
step, validação a cada fechamento, review final contra o PRD. Retomável — o estado
vive em `.claude/ailfred/<slug>/state.yaml`.

**Read first:** skills `ailfred-decomposition` e `ailfred-worktree-execution`. Goal originado de
lista: skill `ailfred-list-intake` (§ Step 6 — write-back).
**Gates G-G2/G-G3/G-G4:** `${CLAUDE_PLUGIN_ROOT}/commands/ailfred.md § Gate registry`.

**Scripts do kit** — resolva o root do plugin uma vez por sessão e depois use `$AF`:

```bash
AF="${CLAUDE_PLUGIN_ROOT:-./ailfred}"   # instalado → cache do plugin; dev neste repo → ./ailfred
```

## Invariantes

- **Escritor único de `state.yaml`: o host.** Workers e orquestradores devolvem handoff.
- **Um step por vez.** Nunca abrir o step seguinte antes do gate G-S do atual.
- **Host não implementa.** Nenhuma edição de código no host: quem escreve código é `ailfred-task-worker`.
- **Escopo é lei.** Task escreve apenas dentro do seu `scope_allowlist`. Escrita fora = task bloqueada e reportada, não "ajustada".
- **Step fecha verde.** Validação falhando não passa para o próximo step sem token explícito.
- Saída para o desenvolvedor em português; arquivos de instrução em inglês.

## Host action

### Passo 0 — Precondições

1. Ler `.claude/ailfred/<slug>/state.yaml`. Sem slug no argumento: se houver exatamente um goal em `planned|executing|blocked`, usar; se houver vários, `AskUserQuestion`; se nenhum, apontar `/ailfred`.
2. Exigir `ailfred-plan-approve` em `gates`. Sem o token → parar e apontar `/ailfred`.
3. `git status --porcelain` + `git branch --show-current`.
   - Árvore suja → `AskUserQuestion`: commitar antes, seguir mesmo assim (só modo `single`) ou abortar. Worktrees exigem árvore limpa.
   - Branch `main` → oferecer `git checkout -b ailfred/<slug>` e gravar em `work_branch`.
4. `bash "$AF/scripts/ailfred-worktree.sh" list <slug>` — worktrees órfãos de execução anterior. Existindo, reconciliar `state.yaml → worktrees` e resolver (integrar ou remover) **antes** de dispatch novo.
5. Flags sobrepõem `state.yaml` só nesta execução: `--single`, `--parallel`, `--max-parallel N`.
6. `--dry-run` → imprimir a tabela de dispatch (steps, ondas, tasks, modo, branches previstos) e encerrar. Nenhum spawn.

### Passo 1 — Selecionar o step

Primeiro step com `status != done`, respeitando `depends_on`. Com `--step SNN`, usar
esse step (recusar se as dependências não estiverem `done`). Marcar `status: active`
no `state.yaml` e `goal.status: executing`.

Com `--task SNN-TNN`: executar só essa task (retomada pontual), sem fechar o step.

### Passo 2 — Rodar o step (subagent)

```text
Agent(subagent_type="ailfred:ailfred-step-runner")
goal_slug: <slug>
step_id: SNN
mode: single | parallel
max_parallel: <n>
base_branch: <work_branch ou base_branch>
plan_path: .claude/ailfred/<slug>/plan.md
tasks: [SNN-T01, SNN-T02, ...]   # apenas IDs; o runner lê os arquivos das tasks
step_validation: [<comandos do plano>]
report_path: .claude/ailfred/<slug>/steps/SNN-report.md
```

O runner: monta as ondas, cria worktrees quando o modo é `worktrees`, dispara
`ailfred-task-worker` (um por task, ondas concorrentes num único turno), integra os
branches em ordem, roda a validação do step e escreve `steps/SNN-report.md`.

Retorno esperado (handoff comprimido): status por task, branches integrados,
conflitos, resultado da validação, desvios, worktrees ainda vivos.

### Passo 3 — Validar o step (subagent)

```text
Agent(subagent_type="ailfred:ailfred-validator")
mode: step
goal_slug: <slug>
step_id: SNN
acceptance_sources: [.claude/ailfred/<slug>/tasks/SNN-T*.md]
step_validation: [<comandos>]
report_path: .claude/ailfred/<slug>/steps/SNN-report.md
```

Falha → no máximo **2 ciclos de remediação** automáticos: o host respawna
`ailfred-step-runner` em `mode: remediate` com os achados (task, arquivo, erro). Na
terceira falha, parar e emitir G-S com `ailfred-step-fix` como recomendação — nunca
insistir em loop.

### Passo 4 — Gate G-S (fechamento do step)

`ailfred-step-accept` → step `done`, atualizar `state.yaml`, e **seguir para o próximo
step no mesmo turno** (volta ao Passo 1). Goal originado de lista: registrar em
`state.yaml → source.items_done` os `item_id` cujas tasks fecharam todas — o write-back
em si só acontece no fechamento do goal, com token. `ailfred-step-fix` → o desenvolvedor diz o
que muda; respawn do runner. `ailfred-stop` → `goal.status: blocked`, resumo do ponto
de retomada, encerrar.

### Passo 5 — Fechamento do goal

Depois do último step:

```text
Agent(subagent_type="ailfred:ailfred-validator")
mode: goal
goal_slug: <slug>
prd_path: .claude/ailfred/<slug>/PRD.md
review_path: .claude/ailfred/<slug>/REVIEW.md
```

Conferir também: nenhum worktree vivo (`ailfred-worktree.sh list <slug>` vazio) e
nenhuma task fora de `done|skipped`. Depois, gate G-G5-deliver.

### Passo 6 — Write-back na lista de origem (só com token `ailfred-accept-sync`)

Aplicável quando `state.yaml → source.writeback` é `true`. Contrato completo na skill
`ailfred-list-intake` § Step 6.

1. Montar a lista de itens elegíveis: `item_id` cujas tasks estão **todas** `done`. Pai
   com filho pendente não entra.
2. Mais de três itens → rodar tudo com `--dry-run` primeiro e mostrar o antes/depois.
3. Uma chamada por item:

   ```bash
   bash "$AF/scripts/ailfred-todo-sync.sh" <source.file> --line <N> --expect "<substring>" --check
   ```

4. Exit `3` (drift — o desenvolvedor editou o arquivo): **re-parsear** com
   `ailfred-todo-parse.sh`, casar por texto, usar a nova linha. Nunca forçar a linha antiga.
5. Fechar reportando: itens marcados, itens deixados em aberto e o motivo de cada um.

`source.writeback: false` (lista colada) → não há arquivo para marcar: entregar a
checklist final na resposta.

## Gate registry

### G-S-step-closure

```
Step SNN — <nome> — encerrado

Tasks: <n done> / <n total>   Modo: <sequencial | worktrees>
Branches integrados: <lista ou n/a>
Conflitos: <n> (<resolução>)
Validação: <comando: ok|falhou> ...
Escopo: <nenhuma escrita fora do allowlist | lista>
Desvios: <lista ou nenhum>
Pendências: <lista ou nenhuma>
Próximo step: <SNN+1 — nome | nenhum>

Aceitar o fechamento deste step?

Opções:
  - id: ailfred-step-accept  label: Aceitar e seguir
  - id: ailfred-step-fix     label: Corrigir antes (digo o que)
  - id: ailfred-stop         label: Parar aqui (retomo depois)
```

### G-G5-deliver

```
Goal <slug> — execução concluída

Critérios do PRD atendidos: <n/n>  (detalhe: .claude/ailfred/<slug>/REVIEW.md)
Itens da lista de origem: <n done / n total>   (só quando veio de lista)
Itens que NÃO fecharam: <lista com motivo, ou nenhum>
Steps: <n>   Tasks: <n done, n skipped>
Validação final: <comando: ok|falhou> ...
Achados do review: <n> (<severidades>)
Worktrees vivos: <0 | lista>
Follow-ups registrados: <lista ou nenhum>

Fechar o goal?

Opções:
  - id: ailfred-accept       label: Fechar como concluído
  - id: ailfred-accept-sync  label: Fechar e marcar os checkboxes em <source.file>
  - id: ailfred-followup     label: Fechar e virar follow-ups (digo quais)
  - id: ailfred-reject       label: Não fechar — falta o que eu vou dizer
```

`ailfred-accept-sync` só aparece quando `source.writeback` é `true`. É o único token que
autoriza escrever na lista de origem.

### Passo 7 — Alimentar a memória do repositório (após `ailfred-accept*`)

Fechado o goal, grave o que o próximo goal deste repo pagaria para redescobrir. Contrato
na skill `ailfred-memory`; o host é o escritor.

```bash
AF="${CLAUDE_PLUGIN_ROOT:-./ailfred}"
bash "$AF/scripts/ailfred-memory-write.sh" --type goal --goal-slug <slug> \
  --title "<objetivo em uma frase>" --tags <áreas> --body-file <tmp>
```

- **Uma** nota `goal`: o que entregou, onde vive, o que ficou de follow-up.
- **Uma** nota `decision` por gate cuja escolha não foi óbvia (o porquê e a alternativa
  descartada), e uma `pitfall` por falha que custou uma rodada de correção.
- Atualizar `state.yaml → project.memory_synced_at`.
- Nada de segredo, log bruto ou trecho longo de código. Aponte `caminho:linha`.

## Authorized writes

- `.claude/ailfred/<slug>/state.yaml` (host, escritor único).
- Branch novo `goal/<slug>` quando o desenvolvedor autorizar no Passo 0.
- Código e relatórios: pelos subagents, dentro dos escopos declarados.
- **Uma linha de checkbox** por item concluído na `source.file`, via `ailfred-todo-sync.sh`, somente com token `ailfred-accept-sync`. Nada mais nesse arquivo.
- `~/.claude/ailfred/project/<project-slug>/memory/` via `ailfred-memory-write.sh` (Passo 7).

## Anti-patterns

- Executar sem `ailfred-plan-approve` registrado, ou sem `execution_mode` definido.
- Fechar o goal sem alimentar a memória — o próximo goal paga a descoberta de novo.
- Host editando código, resolvendo conflito ou rodando task "porque é pequena".
- Abrir onda nova com branch da onda anterior sem integrar (ver skill `ailfred-worktree-execution`).
- Merge de tudo no fim, em lote, em vez de integrar e validar por task.
- Loop infinito de remediação: o limite é 2 ciclos, depois é gate.
- Marcar task/step como `done` sem evidência no relatório.
- Ampliar escopo durante a execução em vez de registrar em `state.yaml → followups`.
- Deixar worktree órfão e fechar o goal.
- Commit ou push fora do que o desenvolvedor autorizou (worker commita só no próprio worktree).
- Marcar checkbox de item cuja task ficou `blocked`, de pai com filho pendente, ou sem o token `ailfred-accept-sync`.
- Forçar write-back depois de um drift (exit 3) em vez de re-parsear.
- Reformatar, reordenar ou "limpar" a lista de origem: só a linha do checkbox muda.
