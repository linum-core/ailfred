# 05 · Prompt — Política de validação com o desenvolvedor

> Janela limpa. Cole `01-shared-contracts.md` antes deste arquivo. Pré-requisito: prompt 06.

## Missão

Perguntar **uma vez, no começo**, quanta validação humana o goal precisa — e depois honrar
isso: em modo autônomo, o Ailfred não pede aprovação para o que já foi delegado, e só
devolve as perguntas que realmente travam o trabalho.

## Problema concreto

Hoje todo goal atravessa G-G2, G-G3, G-G4 (e triagem, em modo lista). Para "renomeia essa
função em 3 arquivos", isso são quatro paradas para uma mudança de 10 linhas. O custo é
atrito humano, não token.

## Os três níveis

| Nível | Gates que param | Uso |
| --- | --- | --- |
| `full` | todos (G-G0…G-G5) | mudança arriscada, domínio novo, código de produção sensível |
| `checkpoints` | só `G-G3-plan` e `G-G5-deliver` | **default**: dev aprova o plano e a entrega, não o meio |
| `autonomous` | nenhum; só **bloqueios reais** interrompem | tarefa rotineira, escopo fechado, dev ausente |

**Bloqueio real** (interrompe mesmo em `autonomous`, sem exceção):
1. `developer-action` — falta credencial, acesso, decisão de produto que não está no repo;
2. ambiguidade que muda o resultado (duas leituras plausíveis levam a entregas diferentes);
3. operação destrutiva ou irreversível (delete em massa, migração de dados, force-push, deploy);
4. escopo estourando o allowlist aprovado;
5. modo `loop` atingindo `stalled`.

Tudo que não está nessa lista **não pergunta** em `autonomous`. Registra decisão em
`state.yaml` e segue.

## A pergunta única

No `/ailfred`, logo após o scaffold e antes de qualquer subagent, uma `AskUserQuestion`
com três opções (`checkpoints` marcada como recomendada). Nunca perguntar duas vezes no
mesmo goal. Se `validation.default` estiver setada na config, **não perguntar nada** —
usar e informar em uma linha: `Validação: autonomous (config do repo).`

## Regra do "asks agrupados"

Em `checkpoints` e `autonomous`, perguntas do architect/worker **não** viram interrupções
individuais. Elas se acumulam em `state.yaml → open_questions[]` e são apresentadas:
- em `checkpoints`: junto do gate seguinte, em bloco único;
- em `autonomous`: só as que são bloqueio real, imediatamente; o resto vai para
  `followups[]` e aparece no relatório final.

Formato do bloco (português, numerado, cada item com **assumção default** para o dev poder
responder só o que discorda):

```
3 perguntas antes de executar:
1. Migrations rodam no CI ou local?  [assumo: CI]
2. Manter compat com Node 18?        [assumo: sim]
3. Tests E2E entram nesta entrega?   [assumo: não, vira followup]
Responda só os números que quer mudar.
```

## Escopo — arquivos que você cria

```
skills/ailfred-gate-policy/SKILL.md
scripts/ailfred-gate.sh    # check|record|list — decide se um gate para ou passa
```

E **edita**: `commands/ailfred.md` (pergunta única + `gate.sh check` em cada gate),
`commands/ailfred-execute.md` (idem), `templates/ailfred/state.yaml` (campo `validation`,
`open_questions[]`), `agents/ailfred-architect.md` e `agents/ailfred-task-worker.md`
(devolvem `questions[]` classificadas `blocking | assumable | followup`, nunca perguntam direto).

## Contrato de `ailfred-gate.sh`

```bash
ailfred-gate.sh check  --goal S --gate G-G3
    # stdout: STOP  <motivo>            -> host apresenta gate e encerra turno
    #     ou: PASS  policy=checkpoints  -> host segue, registra skipped_by_policy:true
ailfred-gate.sh record --goal S --gate G-G3 --token ailfred-plan-approve
ailfred-gate.sh list   --goal S
```

O host **nunca decide sozinho** se um gate para — sempre chama `check`. Isso mantém a
regra fora da prosa e dentro do script (barato e auditável).

## Config

```yaml
validation:
  default: null            # null = perguntar; full|checkpoints|autonomous = não perguntar
  always_stop_on:          # bloqueios reais; a lista acima é o mínimo, dá pra somar
    - destructive
    - developer-action
    - scope-overflow
  group_questions: true
```

## Anti-requisitos

- `autonomous` **não** significa commit/push/PR automático. Isso continua exigindo pedido
  explícito do dev, em qualquer nível. Documente isso em negrito no SKILL.
- Não silenciar pergunta: o que não foi perguntado aparece no relatório final como
  assumção tomada. Assumção invisível é bug.
- Não reintroduzir gate por dentro de agent: agent classifica, host decide.

## Definição de pronto

- [ ] `validation: autonomous` num goal de 1 task → **zero** interações humanas
- [ ] `validation: autonomous` + task com operação destrutiva → para e pergunta
- [ ] `checkpoints` → exatamente 2 paradas (plano, entrega)
- [ ] Perguntas não-bloqueantes chegam agrupadas com assumção default
- [ ] Relatório final lista toda assumção tomada sem confirmação
