# 10 · Prompt — V2: vários projetos e várias contas num lugar só

> Janela limpa. Cole `01-shared-contracts.md` antes deste arquivo.
> **Não bloqueia o release do v0.2.** Só comece depois de 02–09 entregues e estáveis.

## Missão

Uma visão única sobre **todos** os repositórios em que o Ailfred trabalha — inclusive sob
identidades git / contas de hospedagem diferentes — sem quebrar nenhum invariante do v0.2.

## Pré-condição de design

O v0.2 já isola tudo por `<project-slug>` em `~/.claude/ailfred/project/<slug>/`. O v2 é
essencialmente **um índice sobre essa árvore** + comandos de agregação. Se você precisar
mudar o layout do v0.2 para fazer o v2 funcionar, o v0.2 está errado — corrija lá, não
crie um segundo layout.

## `registry.yaml`

```yaml
version: 1
accounts:
  - id: pessoal
    git_user: "GgvGomes"
    git_email: "ggvgabriel05@gmail.com"
    host: github.com
    remote_match: ["github.com/GgvGomes/*", "github.com/linum-core/*"]
  - id: trabalho
    git_user: "..."
    host: github.com
    remote_match: ["github.com/acme/*"]
projects:
  - slug: ailfred-a1b2c3d4
    path: /Users/x/Documents/softs/linum core/ailfred
    account: pessoal
    remote: git@github.com:linum-core/ailfred.git
    last_seen: 2026-08-19
    active_goals: 1
    memory_notes: 23
```

`account` é **derivado** do remote via `remote_match`, com override manual. Nunca peça a
conta ao dev se der para inferir.

## Escopo — arquivos que você cria

```
commands/ailfred-projects.md    # /ailfred-projects — listar, focar, agregar
scripts/ailfred-registry.sh     # register|list|sync|prune|resolve-account
scripts/ailfred-portfolio.sh    # agrega boards de N projetos numa visão só
docs/multi-project.md
```

## Comandos

```bash
/ailfred-projects                    # tabela: projeto · conta · goals ativos · último uso
/ailfred-projects --board            # board agregado: cards em voo de todos os projetos
/ailfred-projects --account trabalho # filtra
/ailfred-projects --prune            # remove do registry projetos cujo path sumiu
/ailfred-projects --goto <slug>      # imprime o path (o dev faz o cd; o plugin não navega)
```

`ailfred-registry.sh register` roda **automaticamente** no `memory-init` (prompt 02) —
o registry se preenche sozinho conforme o dev usa o Ailfred. Zero cadastro manual.

## Board agregado

Reusa `ailfred-board.sh render` por projeto e compõe:

```
PORTFÓLIO · 4 projetos · 6 cards em voo · 2 bloqueados

pessoal/ailfred          ▓▓░  2 em progresso · 1 bloqueado   goal: kanban-board
pessoal/linum-portfolio  ▓░░  1 em progresso                 goal: home-refactor
trabalho/acme-api        ░░░  ocioso                         —
trabalho/acme-web        ▓▓░  3 em progresso                 goal: checkout-v2

BLOQUEIOS
ailfred/S01-T03   aguarda credencial de staging (há 2 dias)
```

Custo: `portfolio.sh` lê só `board.yaml` e `state.yaml` de cada projeto. Nunca abre task,
nunca abre memória. Meta: ≤ 2k tokens com 20 projetos.

## Isolamento entre contas — não negociável

- Memória de um projeto **nunca** vaza para outro. Sem vault compartilhado, sem índice
  cruzado de conteúdo. O registry guarda metadados, não conhecimento.
- Nada de credencial no registry. Sem token, sem senha, sem chave. Auth continua sendo do
  `git`/`gh`.
- `--account` filtra visão; não troca identidade git. Trocar identidade é ação do dev.
- Escreva uma seção **"limites de privacidade"** em `docs/multi-project.md` afirmando isso.

## Riscos a tratar explicitamente

| Risco | Mitigação |
| --- | --- |
| Registry envelhecido (repo movido/apagado) | `sync` valida paths; `prune` limpa; `list` marca `stale` |
| Dois clones do mesmo repo | slug inclui hash do path → entradas distintas, memórias distintas |
| Vault crescendo sem limite | `docs/memory.md` define política de poda; `registry` mostra `memory_notes` |
| Vazamento entre contas | testes explícitos de isolamento |

## Definição de pronto

- [ ] Registry se preenche sozinho ao usar `/ailfred` num repo novo
- [ ] Conta inferida do remote acerta nos padrões de `remote_match`; override manual funciona
- [ ] `--board` com 20 projetos custa ≤ 2k tokens e cabe em uma tela
- [ ] `prune` remove path inexistente sem tocar na memória de projetos vivos
- [ ] Teste de isolamento: leitura de memória do projeto A não retorna nota do projeto B
- [ ] Nenhum segredo gravado no registry (varredura automatizada no CI)
