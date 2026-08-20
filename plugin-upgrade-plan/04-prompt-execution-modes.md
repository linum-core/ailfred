# 04 · Prompt — Quatro modos de execução

> Janela limpa. Cole `01-shared-contracts.md` antes deste arquivo.
> Pré-requisito: prompts 02, 03 e 06 já entregues (memória, board, config).

## Missão

Substituir o par `sequential | worktrees` por **quatro modos de execução explícitos**,
cada um com gatilho de seleção, runner e critério de parada próprios — escolhidos por
regra determinística, não por intuição do modelo.

## Os quatro modos

| Modo | Quando | Runner | Parada |
| --- | --- | --- | --- |
| `single` | 1 task, escopo fechado, sem dependência | host inline (sem subagent) | task fecha |
| `loop` | mesma transformação repetida sobre N alvos; critério de convergência mensurável | `ailfred-loop-runner` | convergiu OU `max_iterations` OU sem progresso 2x seguidas |
| `parallel` | ≥2 tasks `parallel: safe` com allowlists disjuntas | host + worktrees + N `ailfred-task-worker` | todas as waves fecham |
| `graph` | dependências não-lineares: fan-out/fan-in, task alimentando várias | `ailfred-graph-runner` | todo nó em `done` ou `blocked` |

### `single`
Modo mais barato e o **default para qualquer coisa pequena**. Regra: se o plano tem uma
task `size: S` sem `depends_on`, o host executa direto. Zero worktree, zero subagent.
Ao terminar, o host **sugere paralelismo** se detectar que o mesmo padrão se repete em
outros alvos ("mesma mudança cabe em mais 4 arquivos — quer virar `parallel`?"). Sugerir,
nunca escalar sozinho.

### `loop`
Loop precisa de três coisas ou não é loop:
1. **alvo iterável** — lista de arquivos, testes falhando, itens de checklist;
2. **métrica de progresso** — comando que devolve número que deve cair/subir;
3. **teto** — `max_iterations` (default 5) e `no_progress_limit` (default 2).

`ailfred-loop-runner` roda: medir → agir em UM alvo → medir → registrar delta. Se o delta
for zero duas vezes, para e devolve `stalled` com diagnóstico. Nunca "tenta de novo igual".
Cada iteração vira uma linha em `reports/<step>-loop.md`, não uma task nova no board.

### `parallel`
Reusa `ailfred-worktree-execution` e `ailfred-worktree.sh` já existentes. Novidade: o
escalonamento vem de `ailfred-board.sh next --count <max_parallel>`, respeitando WIP.
Pré-condição dura antes de qualquer spawn: **allowlists dos cards em voo são disjuntas**.
Interseção → recusa e rebaixa para `single` sequencial com aviso nomeando o conflito.

### `graph`
Constrói DAG a partir de `depends_on`. `ailfred-graph-runner`:
- valida aciclicidade (ciclo → erro com o ciclo impresso, sem executar nada);
- calcula waves por ordenação topológica;
- dentro da wave, aplica a regra do `parallel`;
- fan-in: um nó só roda quando **todos** os predecessores estão `done`; predecessor
  `blocked` propaga `blocked` para descendentes com `blocked_by: upstream <id>`.

## Escopo — arquivos que você cria

```
skills/ailfred-execution-modes/SKILL.md
agents/ailfred-loop-runner.md
agents/ailfred-graph-runner.md
scripts/ailfred-mode-select.sh       # decisão determinística; stdout: mode=<m> reason=<...>
scripts/ailfred-graph.sh             # validate | waves | render (mermaid + ascii)
```

E **edita**: `commands/ailfred-execute.md` (dispatcher dos 4 modos),
`commands/ailfred.md` (grava `execution_mode` + `mode_reason` no G-G3),
`templates/ailfred/plan.md` (campo de modo por step),
`templates/ailfred/config.yaml` (chaves de modo — ver abaixo).

## Seleção de modo — determinística

`ailfred-mode-select.sh --goal <slug>` decide **sem modelo**, nesta ordem:

```
1. flag --mode explícita             -> usa e para
2. config execution.force_mode       -> usa e para
3. ciclo no grafo                    -> erro
4. n_tasks == 1                      -> single
5. plano declara loop.metric         -> loop
6. profundidade do DAG > 2  OU  algum nó com >1 predecessor -> graph
7. >=2 tasks safe com allowlists disjuntas -> parallel
8. caso contrário                    -> single (sequencial sobre a fila do board)
```

Saída em uma linha `mode=graph reason=fan-in em S02-T03`. O host escreve isso em
`state.yaml` e mostra ao dev. Se o dev discordar, `--mode` na próxima invocação vence.

## Chaves de config (prompt 06 já criou o resolvedor)

```yaml
execution:
  force_mode: null          # single|loop|parallel|graph — trava a decisão
  max_parallel: 3
  wip_limit: 3
  loop:
    max_iterations: 5
    no_progress_limit: 2
    metric_command: null    # obrigatório para modo loop
  graph:
    max_wave_width: 3
```

## Definição de pronto

- [ ] `mode-select.sh` cobre os 8 ramos, com teste por ramo (fixtures em `tests/fixtures/`)
- [ ] `graph.sh validate` num DAG cíclico imprime o ciclo e sai !=0 sem executar nada
- [ ] `graph.sh render --format mermaid` gera diagrama colável no `/ailfred-status`
- [ ] loop-runner para em `stalled` após 2 iterações sem delta, com diagnóstico
- [ ] `parallel` recusa spawn com allowlists sobrepostas e nomeia o caminho em conflito
- [ ] `single` de task trivial roda sem nenhum spawn de subagent
