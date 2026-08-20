# 06 · Prompt — Configuração em vez de prosa (redução de custo)

> Janela limpa. Cole `01-shared-contracts.md` antes deste arquivo. Rode este **cedo**:
> os prompts 04 e 05 dependem do resolvedor de config.

## Missão

Tirar as decisões de fluxo de dentro dos `.md` e colocá-las em **config declarativa lida
por script**. O modelo passa a *consultar* uma resposta em vez de *ler doutrina para
derivar* a resposta. Meta: fluxo simples do Ailfred custando ≤ 8k tokens de host.

## Diagnóstico do custo atual

`commands/ailfred.md` tem 304 linhas; `ailfred-execute.md`, 211; três skills somam 342.
Num goal trivial o host lê boa parte disso para descobrir coisas que são, na prática,
constantes: qual template usar, quantos paralelos, qual gate, qual script chamar.

**Princípio:** `.md` explica *por quê* (para o humano e para o caso difícil). Config
declara *o quê* (para a máquina e para o caso comum). Se um trecho de `.md` só existe para
o modelo escolher entre alternativas fixas → vira chave de config.

## Escopo — arquivos que você cria

```
templates/ailfred/config.yaml       # default do plugin, comentado, completo
scripts/ailfred-config.sh           # resolvedor com precedência
scripts/ailfred-route.sh            # "dado o estado, qual é o próximo passo?" 
docs/config-reference.md            # tabela de todas as chaves (gerada/mantida à mão)
```

E **edita**: os 3 commands e as 3 skills existentes — **encolhendo-os**. Meta explícita:
`commands/ailfred.md` ≤ 150 linhas, `ailfred-execute.md` ≤ 120, cada SKILL ≤ 120.
O que sair vira config ou vai para `docs/`.

## `config.yaml` — chaves canônicas

Consolide aqui tudo que os prompts 02–05 e 07 precisam. Uma chave, um dono.

```yaml
version: 1

project:
  slug: null                 # auto
  language: pt-BR            # idioma da saída ao dev
  memory: true               # prompt 02

execution:                   # prompt 04
  force_mode: null
  max_parallel: 3
  wip_limit: 3
  loop:   { max_iterations: 5, no_progress_limit: 2, metric_command: null }
  graph:  { max_wave_width: 3 }

validation:                  # prompt 05
  default: null
  always_stop_on: [destructive, developer-action, scope-overflow]
  group_questions: true

delegation:                  # prompt 07
  min_task_size_for_subagent: M
  max_concurrent_agents: 3
  prefer_inline_below_files: 3

discovery:                   # prompt 08
  grill: auto                # auto | always | never
  grill_max_questions: 5
  capability_scan_ttl_days: 30

git:
  auto_commit: false
  auto_push: false
  auto_pr: false
  branch_prefix: "ailfred/"
```

**Defaults escolhidos para custo baixo**: `max_parallel: 3`, `grill: auto`,
`min_task_size_for_subagent: M`, todo `auto_*` de git em `false`.

## Contrato de `ailfred-config.sh`

```bash
ailfred-config.sh get <chave.pontuada> [--goal S] [--default V]
    # stdout: valor cru, uma linha. Sem chave e sem --default -> exit 3
ailfred-config.sh dump [--goal S]        # YAML resolvido final, para debug
ailfred-config.sh where <chave>          # qual camada venceu (auditoria)
ailfred-config.sh init  [--repo|--local] # escreve config.yaml comentado no nível pedido
```

Precedência exata: seção 5 do contrato compartilhado. `where` existe para o dev entender
por que algo mudou — sem isso, config em 5 camadas vira mistério.

## `ailfred-route.sh` — o roteador barato

Esta é a peça que mais economiza. Em vez do host ler prosa para saber o próximo passo,
ele pergunta:

```bash
ailfred-route.sh next --goal <slug>
```

Saída: **uma linha** máquina-legível, ex.:

```
step=decompose agent=ailfred-architect gate=G-G3 mode=graph reason=prd-approved
```
```
step=execute-card card=S01-T04 runner=host gate=none reason=single-mode wip=1/3
```
```
step=await-gate gate=G-G2 reason=prd-written-not-approved
```

O host lê a linha, faz **uma** coisa, e volta a perguntar. Fluxo vira máquina de estados
determinística; prosa só é carregada quando o passo é genuinamente difícil (decomposição,
grill).

## Regra de leitura condicional de `.md`

Todo command passa a declarar, no topo, um mapa `passo → skill a carregar`:

| Passo (de `route.sh`) | Skill que o host carrega |
| --- | --- |
| `intake-list` | `ailfred-list-intake` |
| `grill` | `ailfred-grill` |
| `decompose` | `ailfred-decomposition` |
| `execute-parallel` / `execute-graph` | `ailfred-execution-modes` |
| `execute-card` (single) | **nenhuma** |

"Nenhuma" é a linha mais valiosa da tabela. Proteja-a.

## Definição de pronto

- [ ] `config.sh get execution.max_parallel` funciona sem nenhum config presente (default do plugin)
- [ ] `config.sh where` identifica corretamente a camada vencedora nas 5 camadas
- [ ] `route.sh next` cobre todo estado de `state.yaml` e nunca devolve duas linhas
- [ ] `commands/ailfred.md` ≤ 150 linhas e `ailfred-execute.md` ≤ 120 após a poda
- [ ] Goal `single` + `autonomous` roda ponta a ponta sem o host abrir nenhum SKILL
- [ ] `docs/config-reference.md` lista 100% das chaves com default e dono (prompt de origem)
