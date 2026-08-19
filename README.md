# Ailfred

Plugin de [Claude Code](https://code.claude.com) que recebe um pedido grande demais para
uma passada só — uma frase, um documento ou **uma lista de to-dos inteira** — e devolve
PRD aprovado, steps e tasks verificáveis, executados em sequência ou em **git worktrees**
paralelos. Domínio-agnóstico: o pedido define o domínio, o kit define o método.

O que ele resolve: pedido grande sem PRD virou task vaga; task vaga virou "ajustei" sem
evidência; lista de to-dos perdeu item no caminho. Aqui cada item tem disposição, cada
task tem critério de aceite e comando de evidência, e nada fecha sem gate do
desenvolvedor.

```
/ailfred <objetivo>                 → PRD → gates → steps + tasks → modo de execução
/ailfred --from todo.md             → mesma coisa, partindo de uma lista de to-dos
/ailfred-execute <slug>             → executa step por step, valida, fecha com review
/ailfred-status [slug]              → progresso, worktrees vivos, divergências, próximo passo
```

## Instalação

```bash
claude plugin marketplace add linum-core/ailfred
claude plugin install ailfred@ailfred-marketplace
```

Por projeto e versionado no repositório que consome — `.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "ailfred-marketplace": { "source": { "source": "github", "repo": "linum-core/ailfred" } }
  },
  "enabledPlugins": { "ailfred@ailfred-marketplace": true }
}
```

Quem clonar o projeto e confiar na pasta recebe os comandos sem instalar nada à mão.
Para desenvolver o próprio plugin: `claude plugin marketplace add ./ailfred --scope project`
(caminho local), ou `claude --plugin-dir ./ailfred` para carregar direto da pasta.

Conferir: `claude plugin details ailfred` (inventário + custo de tokens),
`claude plugin validate . --strict`.

## Como funciona

```
1  intake      frase, documento, ou lista de to-dos parseada em YAML determinístico
2  triagem     cada item recebe disposição: ready | vague | oversized | spike |
               developer-action | done | duplicate | out-of-cluster        [gate]
3  PRD         objetivo, non-goals, critérios com verificação, riscos,
               capacidades reutilizadas                                    [gate]
4  plano       steps (marcos verificáveis) + tasks (uma unidade provável),
               ondas paralelas, rastreio item → task                       [gate]
5  execução    task worker por task, worktree quando se justifica,
               integração serial, validação a cada merge            [gate por step]
6  fechamento  review contra o PRD, follow-ups, checkbox de volta na lista [gate]
```

Seis gates (`G-G0` a `G-G6`). Nenhum passo roda sem o token do desenvolvedor registrado em
`state.yaml → gates`.

### Divisão de responsabilidade

| Artefato | Escritor único |
| --- | --- |
| `state.yaml` | sessão principal (host) |
| `PRD.md`, `plan.md`, `tasks/*.md` | `ailfred-architect` |
| `steps/SNN-report.md` | `ailfred-step-runner` |
| código da aplicação | `ailfred-task-worker`, dentro do `scope_allowlist` da task |
| `REVIEW.md` | `ailfred-validator` |

O que sustenta o resultado: **`scope_allowlist` por task** (é o que torna paralelismo
seguro e review honesto), **comando de evidência obrigatório** por task, **`size: L`
proibido**, e uma **lista de rejeição** que o host aplica ao plano antes de mostrá-lo.

## Lista de to-dos como entrada

```bash
/ailfred --from todo.md --section "Sprint atual"
```

A lista é parseada por script, não a olho: hierarquia, checkboxes, notas soltas, seções e
número de linha saem em YAML. Cada item vira `I##` rastreável até a task — e, no
fechamento, o checkbox volta marcado no arquivo de origem (com guarda contra drift: se
você editou o arquivo no meio, o kit re-parseia em vez de marcar a linha errada).

Regras que evitam o resultado ruim: um goal cobre **um cluster coerente**; item vago vira
pergunta agrupada (no máximo 4 por gate, sempre com default) ou **spike** com entrega
escrita; item que só você pode fazer vira **bloqueio explícito**, não task; item nenhum
desaparece — o validador reprova o goal se algum `I##` não resolver em task, skip,
bloqueio ou follow-up.

## Estrutura

```
ailfred/
├── .claude-plugin/           marketplace.json + plugin.json (source "./")
├── commands/                 ailfred.md, ailfred-execute.md, ailfred-status.md
├── agents/                   architect, step-runner, task-worker, validator
├── skills/
│   ├── ailfred-decomposition/       barra de qualidade do PRD, tamanho de task, rejeição
│   ├── ailfred-list-intake/         parse, triagem, rastreio, write-back
│   └── ailfred-worktree-execution/  quando isolar, integrar, limpar
├── scripts/                  scaffold, capability-scan, worktree, todo-parse, todo-sync
└── templates/ailfred/        PRD, plan, task, step-report, REVIEW, state.yaml
```

**Runtime fica no projeto, não no plugin:** cada goal escreve em
`<repo>/.claude/ailfred/<slug>/`. Os scripts resolvem os dois roots sozinhos — assets do
kit por `${CLAUDE_PLUGIN_ROOT}` (com fallback pelo próprio caminho do script) e o
repositório por `git rev-parse --git-common-dir`, que acerta até de dentro de um worktree
(override por `AILFRED_REPO_ROOT`).

Worktrees ficam fora do repositório, em `../.ailfred-worktrees/<repo>/<slug>/<task-id>`,
branch `ailfred/<slug>/<task-id>`.

## Reuso do que já existe na máquina

Antes de inventar método, o kit varre o que está instalado — skills do projeto, do usuário
e de plugins, além de `.md` soltos que servem de referência — e o PRD exige veredito
explícito para cada capacidade candidata: usar (e onde) ou descartar (e por quê).

```bash
bash "$CLAUDE_PLUGIN_ROOT/scripts/ailfred-capability-scan.sh"
```

## Ciclo de edição do plugin

Instalar **copia** o plugin para o cache, e o caminho do cache inclui a versão: editar a
pasta não muda o plugin em execução.

- Iterar: `claude --plugin-dir ./ailfred`.
- Fixar: bump em `.claude-plugin/plugin.json` → `version`, então
  `claude plugin marketplace update ailfred-marketplace` e
  `claude plugin update ailfred@ailfred-marketplace`.

Sem o bump, `update` responde "already at the latest version" e o cache continua antigo.

## Convenções

- Arquivos de instrução (comandos, agents, skills) em inglês; artefatos de runtime e toda
  resposta ao desenvolvedor em português. Política de idioma do projeto aberto, quando
  existir, vence.
- `.claude/ailfred/**` é versionado por padrão no projeto que consome — é o histórico de
  decisão. Para não versionar, adicione ao `.gitignore`.
- Sem commit, push ou PR fora do que o desenvolvedor autorizou; o task worker só commita
  dentro do próprio worktree.
