```markdown
# opcode-shell (MIPS) — banco em terminal

Sistema bancário em MIPS/MARS com interpretador de comandos (shell).  
Requisitos implementados: **R1, R2, R3 e R4**.

## Como executar
- MARS 4.5+
- Abra `src/main.asm` (ele importa os demais `.asm`)
- **Run → Assemble**, depois **Run → Go**.  
  Não precisa ajustar o *Run speed*: o relógio da R4 funciona em qualquer velocidade.

## Arquitetura (arquivos)
- `data.asm` – dados globais, mensagens, buffers, estruturas de clientes e transações, e variáveis do relógio (R4).
- `io.asm` – utilitários de I/O (print/read).
- `strings.asm` – utilitários de string (strcmp, strip etc.).
- `ops_conta.asm` – **R1**: `conta_cadastrar`.
- `ops_fin.asm` – **R2**: `pagar_debito`, `pagar_credito`, `alterar_limite` e **R3** dumps de transações.
- `time.asm` – **R4**: `datetime_set`, `datetime_show` e `tick_datetime` (relógio).
- `main.asm` – laço do shell: imprime prompt, lê linha, chama os handlers e integra **R4** (duas chamadas a `tick_datetime` a cada iteração).

## Comandos (referência)
### R1
- `conta_cadastrar-<CPF11>-<CONTA6>-<NOME>`
  - Ex.: `conta_cadastrar-12345678901-123456-Ana Maria`

### R2
- `pagar_debito-<CONTA6>-<DV>-<VALORcentavos>`
- `pagar_credito-<CONTA6>-<DV>-<VALORcentavos>`
- `alterar_limite-<CONTA6>-<DV>-<NOVO_LIMcentavos>`
  - **DV**: pode ser `X` ou um dígito (`0`..`9`).

### R3 (logs de transações; 50 por tipo/cliente, buffer circular)
- `dump_trans-deb-<CONTA6>-<DV>`
- `dump_trans-cred-<CONTA6>-<DV>`

### R4 (relógio)
- `datetime_set-DD/MM/AAAA- HH:MM:SS`
- `datetime_show`

> Dica: o *help* do programa já inclui os comandos de R4.

## Detalhes de implementação

### R3: buffers circulares
- Para cada cliente existem 50 slots de **débito** e 50 de **crédito** (`.word`).
- Heads independentes; ao atingir 50, sobrescreve do início.
- Dumps imprimem do **mais antigo → mais novo** usando o `wptr`.

### R4: relógio usando `syscall 30`
- O serviço 30 retorna **milissegundos em `$a0`** (não em `$v0`).
- `tick_datetime` acumula `delta_ms` e transforma em segundos; faz *rollover* (00–59, 00–23, dia, mês, ano com bissexto).
- **Anti-turbo:** há *clamp* do delta em **5s por chamada** para evitar “pulos” quando o MARS executa muito rápido.  
  (Ajuste `DELTA_CAP_SEC` no início de `time.asm` se quiser outro valor.)
- Integração no `main.asm`:
  - chama `jal tick_datetime` no **início** da iteração;
  - chama novamente após `read_line`, antes de analisar o comando.

## Roteiro de teste rápido (copy-paste)

1) Cadastrar cliente:
```

conta_cadastrar-12345678901-123456-Ana

```

2) Setar data/hora (perto de minuto seguinte ajuda a ver o avanço):
```

datetime_set-11/11/2025- 23:59:55

```

3) Ver relógio avançando (chame algumas vezes com intervalos de 1–2s):
```

datetime_show
datetime_show
datetime_show

```

4) Testar R2 e R3:
```

pagar_credito-123456-X-2000
pagar_debito-123456-X-150
dump_trans-cred-123456-X
dump_trans-deb-123456-X

```

5) Alterar limite:
```

alterar_limite-123456-X-500000

```

**Resultados esperados (amostras):**
- `datetime_show` mostra segundos/minutos/horas/dias progredindo corretamente.
- Pagamento em débito/crédito retornam mensagens de sucesso e aparecem nos dumps.

## Troubleshooting
- Se `datetime_show` não muda: confira se `main.asm` contém as duas chamadas a `tick_datetime`.
- Certifique-se de que `data.asm` exporta `ms_last`, `ms_accum` e as variáveis `curr_*`.
- MARS 4.5+; montagem de `main.asm` (ele inclui todos os arquivos).

## Changelog
- **R4**: relógio com `syscall 30` + clamp; integração no laço; docs novos.
- **R3**: buffers circulares e comandos de dump.
- **R2**: débito, crédito, alterar limite.
- **R1**: cadastro de clientes.

```
Se topar, eu já preparo também um **R5** opcional: “`extrato` por cliente”, imprimindo os últimos N lançamentos com **timestamp** (aproveitando o relógio da R4). Quer que eu gere o arquivo `ops_extrato.asm` e integre no `main`?
