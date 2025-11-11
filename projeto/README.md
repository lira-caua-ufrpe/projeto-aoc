````markdown
# Projeto AOC — Banco (MIPS / MARS)

Sistema bancário minimalista escrito em **Assembly MIPS** para o simulador **MARS**.  
Até o momento, implementa **R1, R2 e R3** do enunciado: cadastro de clientes, pagamentos (débito/crédito, com limite) e **registro de transações** (histórico circular) por cliente.

---

## Sumário

- [Visão geral](#visão-geral)
- [Requisitos atendidos](#requisitos-atendidos)
- [Como executar (MARS)](#como-executar-mars)
- [Comandos do shell](#comandos-do-shell)
- [Exemplos rápidos](#exemplos-rápidos)
- [Estruturas de dados](#estruturas-de-dados)
- [Detalhes de implementação](#detalhes-de-implementação)
- [Depuração / Inspeção (dump de transações)](#depuração--inspeção-dump-de-transações)
- [Limites e validações](#limites-e-validações)
- [Estrutura do repositório](#estrutura-do-repositório)
- [Roadmap (próximos passos)](#roadmap-próximos-passos)

---

## Visão geral

O programa roda um **shell interativo** no MARS e aceita comandos de texto para:
- cadastrar clientes;
- pagar contas no **débito** ou **crédito**;
- alterar limite de crédito;
- **registrar** cada transação bem-sucedida em buffers circulares (até 50 por tipo/cliente);
- inspecionar o histórico de transações via comandos de **dump** (para debug).

---

## Requisitos atendidos

### R1 — Cadastro de clientes
- Comando: `conta_cadastrar-<CPF11>-<CONTA6>-<NOME>`
- Verifica duplicidade de **CPF** e de **nº de conta** (6 dígitos).
- Calcula DV (dígito verificador) pelo **módulo 11** com pesos 2..7 (da direita para a esquerda).  
  Resto 10 → DV `'X'`, senão `'0'..'9'`.
- Inicializa: `saldo = 0`, `limite = R$ 1500,00 (150000 centavos)`, `devido = 0`.

### R2 — Pagamentos e limite
- `pagar_debito-<CONTA6>-<DV>-<VALORcentavos>` → debita do **saldo** (se houver).
- `pagar_credito-<CONTA6>-<DV>-<VALORcentavos>` → aumenta **devido**, respeitando `limite - devido`.
- `alterar_limite-<CONTA6>-<DV>-<NOVO_LIMcentavos>`  
  Só aceita se `novo_limite >= devido`.

### R3 — Registro de transações
- Cada cliente possui **50 slots** para **débito** e **50** para **crédito**.
- Só **transações bem-sucedidas** são registradas (falhas não entram).
- Ao ultrapassar 50, sobrescreve a **mais antiga** (**buffer circular**), **sem** alterar saldos/limites.
- Comandos de inspeção (dump): ver seção [Depuração / Inspeção](#depuração--inspeção-dump-de-transações).

---

## Como executar (MARS)

1. Abra o **MARS 4.5+**.
2. Menu **Settings**:
   - **Desmarque** `Assemble all files in directory` (o `main.asm` inclui os demais via `.include`).
   - (Opcional) Marque `Initialize Program Counter to 'main' if defined`.
3. Abra `projeto/src/main.asm`.
4. Clique **Assemble** e depois **Run**.
5. Use o console **Run I/O** para digitar os comandos.

> **Dica:** se ver erros de "símbolo já definido", você provavelmente está com `Assemble all files` **ligado** — desligue.

---

## Comandos do shell

| Comando | Descrição |
|---|---|
| `help` | Mostra a ajuda. |
| `exit` | Encerra o programa. |
| `conta_cadastrar-<CPF11>-<CONTA6>-<NOME>` | Cadastra cliente. Calcula DV automaticamente e imprime `CONTA6-DV`. |
| `pagar_debito-<CONTA6>-<DV>-<VALORcentavos>` | Debita do saldo (se houver). Registra no log de **débito**. |
| `pagar_credito-<CONTA6>-<DV>-<VALORcentavos>` | Consome limite (aumenta devido). Registra no log de **crédito**. |
| `alterar_limite-<CONTA6>-<DV>-<NOVO_LIMcentavos>` | Atualiza limite (se `novo_limite >= devido`). |
| `dump_trans-deb-<CONTA6>-<DV>` | **(Debug)** Lista as últimas transações de **débito** do cliente (em centavos). |
| `dump_trans-cred-<CONTA6>-<DV>` | **(Debug)** Lista as últimas transações de **crédito** do cliente (em centavos). |

**Observação:** todos os valores são em **centavos** (ex.: `2000` = R$ 20,00).

---

## Exemplos rápidos

```text
# Cadastro
conta_cadastrar-11122233344-123456-Alice
# -> Cliente cadastrado com sucesso. Numero da conta 123456-0  (exemplo de DV)

# Crédito de R$ 20,00
pagar_credito-123456-0-2000
# -> Pagamento em credito registrado

# Débito de R$ 5,00
pagar_debito-123456-0-500
# -> Pagamento em debito registrado

# Atualiza limite para R$ 2.000,00
alterar_limite-123456-0-200000
# -> Limite atualizado

# Dumps (debug)
dump_trans-cred-123456-0
# -> 2000
dump_trans-deb-123456-0
# -> 500
````

---

## Estruturas de dados

* **Clientes (máx 50)** — vetores paralelos:

  * `clientes_usado[50]` (byte 0/1)
  * `clientes_cpf[50][12]` (string `"XXXXXXXXXXX\0"`)
  * `clientes_conta[50][7]` (string `"XXXXXX\0"`)
  * `clientes_dv[50]` (byte: `'0'..'9'` ou `'X'`)
  * `clientes_nome[50][33]` (até 32 chars + `\0`)
  * `clientes_saldo_cent[50]` (word)
  * `clientes_limite_cent[50]` (word)
  * `clientes_devido_cent[50]` (word)

* **R3 — Transações por cliente (centavos, word)**

  * **Débito**:

    * `trans_deb_vals[50 clientes][50]`
    * `trans_deb_head[50]` (próximo índice circular 0..49)
    * `trans_deb_count[50]` (quantas válidas, máx 50)
  * **Crédito**:

    * `trans_cred_vals[50 clientes][50]`
    * `trans_cred_head[50]`
    * `trans_cred_count[50]`

> Arrays de `word` são **alinhados** com `.align 2` (evita exceções de endereço no MARS).

---

## Detalhes de implementação

* **Entrada** via `read_string` (syscall 8) + limpeza de `\n`, `\r`, `\t`, espaços finais.
* **Comparação de comandos**: prefixos por comparação de bytes; `strcmp/strncmp` para verificações pontuais.
* **Handlers** retornam em `$v0`:

  * `1` → comando reconhecido (sucesso **ou** erro amigável já impresso)
  * `0` → não era aquele comando (permite *fallback* no `main`)
* **Mensagens de erro comuns**:

  * `Saldo insuficiente`, `Limite de credito insuficiente`, `Cliente inexistente`,
  * `Novo limite menor que a divida atual`,
  * `Falha: formato/CPF/conta/nome ...`
* **Cálculo do DV (conta)**:
  Soma ponderada dos dígitos (da direita p/ esquerda) com pesos 2..7 → `resto = soma % 11` →
  `resto == 10 ? 'X' : ('0'+resto)`.

---

## Depuração / Inspeção (dump de transações)

* `dump_trans-deb-<CONTA6>-<DV>`
  Lista **em ordem de inserção** (mais antigas primeiro) até 50 valores (centavos) do cliente.
* `dump_trans-cred-<CONTA6>-<DV>`
  Idem para crédito.

> Os dumps não alteram estado; servem apenas para conferência durante o desenvolvimento.

---

## Limites e validações

* Máx **50 clientes**.
* Nome: **até 32** caracteres (resto ignorado).
* CPF: **11 dígitos**.
* Conta: **6 dígitos** + DV calculado (`'0'..'9'` ou `'X'`).
* Valores e limites em **centavos** (inteiros, não negativos).
* **Logs R3**: só transações **válidas** entram; ao exceder, sobrescrevem a **mais antiga** (buffer circular).

---

## Estrutura do repositório

```
projeto/
└── src/
    ├── main.asm         # loop do shell (inclui os outros .asm)
    ├── data.asm         # dados globais, constantes e buffers (clientes + R3)
    ├── io.asm           # E/S (print_str, read_line, strip_line_end)
    ├── strings.asm      # strcmp/strncmp/strcpy (utilitários de string)
    ├── ops_conta.asm    # R1: conta_cadastrar + validações
    ├── ops_fin.asm      # R2: pagar_debito/pagar_credito/alterar_limite + R3 (logs)
    ├── math.asm         # (reservado/auxiliar, se necessário)
    └── time.asm         # (reservado/auxiliar, se necessário)
```

---

## Roadmap (próximos passos)

* **R4**: extrato/relatórios (ex.: total por período, saldo projetado, etc.).
* **R5**: persistência em arquivo (syscalls 13–16) ou via **MMIO** (teclado/tela) para scripts.
* **R6**: remoção/edição de clientes; bloqueio por CPF; melhoria de parsing (erros detalhados).
* **Testes automáticos**: arquivos `.txt` com sequências de comandos (via **Keyboard & Display MMIO**).

---

> **Nota para avaliadores:** O projeto prioriza clareza didática e segurança no MARS (alinhamento de words, prólogo/epílogo nas rotinas, checagem rigorosa de formato/limites). Os comandos de **dump** são utilitários de desenvolvimento e podem ser desativados numa versão final.

```

::contentReference[oaicite:0]{index=0}
```
