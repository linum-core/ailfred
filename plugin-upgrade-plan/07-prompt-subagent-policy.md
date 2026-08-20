# 07 · Prompt — Subagent só quando necessário

> Janela limpa. Cole `01-shared-contracts.md` antes deste arquivo. Pré-requisitos: 04, 05, 06.

## Missão

Escrever a política que decide **inline vs. subagent**, e aplicá-la nos comandos e agents,
para que o caso comum custe um spawn ou nenhum.

## Problema concreto

O v0.1 spawna `ailfred-architect` sempre — inclusive para "renomeia X em 2 arquivos". Cada
spawn recarrega contexto, relê skill, e devolve handoff que o host reprocessa. Para task
pequena, o subagent custa mais do que a task.

## Regra de decisão (determinística, vira `ailfred-delegate.sh`)

Delegue **apenas** quando pelo menos uma for verdade:

1. **Volume de descoberta** — responder exige varrer > 5 arquivos ou > 2 diretórios desconhecidos;
2. **Isolamento de contexto** — o trabalho produz saída volumosa (logs, scan, dumps) que
   não deve entrar no contexto do host;
3. **Paralelismo real** — ≥ 2 unidades independentes rodando ao mesmo tempo;
4. **Papel escrito** — o artefato exige escritor único designado (`architect` para
   PRD/plan/tasks — invariante, não negociável);
5. **Especialidade instalada** — existe agent especializado no repo/máquina que
   demonstravelmente faz melhor (ex.: revisão de segurança).

Se **nenhuma** valer → host faz inline. Escreva isso como checklist de 5 linhas, não como
ensaio.

## Contra-regras (nunca delegue)

- Task `size: S` tocando < 3 arquivos com allowlist explícito → inline.
- Ler um arquivo conhecido, rodar um comando conhecido → inline.
- "Para conferir" / "para ter uma segunda opinião" sem critério de aceite → não delega, decide.
- Delegar algo cujo resultado o host vai ter que reler inteiro de qualquer jeito → inline.
- Cadeia de delegação: subagent **não** spawna subagent. Profundidade máxima 1.

## Escopo — arquivos que você cria

```
skills/ailfred-delegation/SKILL.md
scripts/ailfred-delegate.sh   # decide inline|delegate para uma task/passo
```

E **edita**: os quatro agents (`architect`, `step-runner`, `task-worker`, `validator`) —
cada um ganha um bloco `## Delegation` dizendo explicitamente **"este agent não spawna
outros agents"**; `commands/ailfred.md` e `ailfred-execute.md` chamam `delegate.sh` antes
de qualquer `Agent(...)`.

## Contrato de `ailfred-delegate.sh`

```bash
ailfred-delegate.sh decide --goal S --card S01-T02
    # stdout: mode=inline  reason=size-S-2-files
    #     ou: mode=delegate agent=ailfred-task-worker reason=parallel-wave-2
ailfred-delegate.sh budget --goal S
    # stdout: agents_active=2 max=3 remaining=1
```

`budget` impõe `delegation.max_concurrent_agents`. Estourar → host enfileira, não spawna.

## Consolidação de agents

Revise se quatro agents ainda se justificam. Avalie e **decida no PR**:
- `ailfred-step-runner` sobrepõe-se ao novo `ailfred-graph-runner` (prompt 04)?
- `ailfred-validator` cabe como modo do `task-worker` em vez de agent próprio?

Menos agents = menos arquivo de instrução carregado = menos token. Se consolidar, entregue
migração e nota de deprecação; se manter, escreva em uma linha por agent **por que** ele
não pode ser absorvido. Não deixe a questão em aberto.

## Handoff enxuto

Todo agent devolve handoff estruturado com **teto de tamanho** (~800 tokens). Formato:

```yaml
status: done | blocked | needs-decision
summary: "uma frase"
changed_files: [caminho, ...]
evidence: [{ cmd: "...", result: pass|fail, excerpt: "≤3 linhas" }]
questions: [{ text: "...", kind: blocking|assumable|followup, default: "..." }]
memory_notes: [{ type: ..., title: ..., body: "≤10 linhas" }]
next: "o que o host deve fazer"
```

Nada de despejar diff, log completo ou arquivo colado. Artefato grande vai para arquivo;
handoff carrega o caminho.

## Definição de pronto

- [ ] `delegate.sh decide` devolve `inline` para task S de 2 arquivos e `delegate` para wave paralela
- [ ] Os 4 agents declaram profundidade de delegação 0 no próprio arquivo
- [ ] `budget` bloqueia o 4º spawn com `max_concurrent_agents: 3`
- [ ] Goal trivial ponta a ponta com **0 spawns**, comprovado em transcript de teste
- [ ] Decisão sobre consolidar `step-runner`/`validator` documentada com justificativa
