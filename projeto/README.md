# opcode-shell (MIPS) — banco em terminal

Sistema bancário em MIPS/MARS com interpretador de comandos (shell), suportando até **50 clientes** com conta corrente + cartão de crédito, extratos, juros automáticos e **persistência em arquivo**.

## Requisitos do enunciado atendidos (R1–R13)

* **R1** – Cadastro de clientes com geração de DV (até 50 clientes).
* **R2** – Pagamento em débito/crédito, limite de crédito padrão (R$ 1500,00) e alteração de limite.
* **R3** – Registro de transações de débito/crédito por cliente (até 50 por tipo, buffer circular).
* **R4** – Configuração e atualização contínua de data/hora usando `syscall 30`.
* **R5** – Extratos de débito e crédito, com data, valor e conta destino.
* **R6** – Pagamento parcial/total de fatura (via saldo ou externo), com validação de valor.
* **R7** – Juros de 1% a cada 60 segundos sobre a dívida do cartão, registrados no extrato.
* **R8** – Saques e depósitos na conta corrente.
* **R9** – Encerramento de conta com checagem de saldo e dívida zerados.
* **R10** – **Salvamento em arquivo binário** e restauração automática ao iniciar.
* **R11** – Comando `salvar` para gravar o estado atual no arquivo externo.
* **R12** – Comando `recarregar` para restaurar os dados salvos, descartando alterações não salvas.
* **R13** – Comando `formatar` para apagar clientes e transações da execução atual (sem salvar automático).

> Diferenças em relação ao enunciado:
>
> * Os comandos `transferir_debito` / `transferir_credito` **não existem**; o sistema usa `pagar_debito` / `pagar_credito`.
> * O comando `data_hora` do enunciado é implementado como `datetime_set-...` e `datetime_show`.

---

## Como executar

1. Abra o **MARS 4.5** que já está **dentro do repositório** (colocamos para facilitar a criação/leitura do arquivo de estado).

   * Você pode executar o JAR diretamente: `java -jar mars-4-5.jar`
2. Abra o arquivo `src/main.asm` (ele inclui todos os outros `.asm`).
3. Vá em **Run → Assemble** e depois **Run → Go**.

> **Dica importante (Windows / caminho do arquivo):**
> Por padrão, salvamos em um arquivo chamado `opcode_state.bin` **no mesmo diretório em que o MARS está sendo executado**. Para evitar “open(write) falhou”, rode o MARS **a partir da pasta do projeto** (ou deixe o JAR dentro dela, como fizemos).
> Se ainda assim preferir um caminho **absoluto**, no `persist.asm` há um rótulo `state_filename` onde você pode colocar `C:/…/projeto/src/opcode_state.bin`.

---

## Estrutura (arquivos principais)

* `src/data.asm`
  Constantes (`MAX_CLIENTS = 50`, `TRANS_MAX = 50`, `LIMITE_PADRAO_CENT` etc.), estruturas de clientes e transações, data/hora, mensagens e strings de comandos (`help`, `banner` etc.).
* `src/io.asm`
  E/S básica: `print_str`, `read_line`, limpeza de buffer.
* `src/strings.asm`
  `strcmp`, `strncmp`, `strcpy` e utilitários de parsing.
* `src/time.asm` (**R4**)
  `tick_datetime` (usa `syscall 30`), `handle_datetime_set` / `handle_datetime_show`.
* `src/ops_conta.asm` (**R1, R9**)
  `handle_conta_cadastrar`, `handle_conta_fechar`.
* `src/ops_fin.asm` (**R2, R3, R6, R7, R8**)
  `handle_pagar_debito`, `handle_pagar_credito`, `handle_alterar_limite`, `handle_pagar_fatura`, `handle_sacar`, `handle_depositar`, `aplicar_juros_auto`, dumps de transações (`dump_trans-*`).
* `src/transacoes.asm`
  Formatação de valores (R$ X,YY) e montagem de data/hora para extratos.
* `src/extratos.asm` (**R3, R5, R6, R7**)
  `handle_extrato_debito`, `handle_extrato_credito` (lista do mais antigo para o mais novo).
* `src/ops_util.asm`
  `print_2dig` e `print_datahora`.
* `src/persist.asm` (**R10–R13**)
  Syscalls 13–16; `save_state` / `load_state`. **Arquivo:** `opcode_state.bin`.

  * Versão **padrão** salva no diretório atual do MARS.
  * Alternativa: ajustar `state_filename` para um **caminho absoluto** no Windows, se necessário.
* `src/cmd_persist.asm` (**R11–R13**)
  Handlers de shell: `salvar`, `recarregar`, `formatar`.
* `src/cmd_conta_format.asm`
  Handler do comando por conta: `conta_format-<CONTA6>-<DV>`.
* `src/main.asm`
  Loop do shell: imprime `banner`, lê linha, chama `tick_datetime`/`aplicar_juros_auto`, despacha comandos, **carrega estado no boot** e **salva no `exit`**.

> Também incluímos **`entrada.txt`** (roteiro de testes com muitos casos) e **`saida.txt`** (saída esperada) para facilitar a conferência manual.

---

## Persistência (R10–R13): como funciona

* **Arquivo de estado:** `opcode_state.bin`

  * Contém clientes (CPF, conta, DV, nome, saldos, limites, dívida), metadados e valores dos rings (débito/crédito), além de data/hora e marcadores de juros.
* **Carregamento automático ao iniciar:** `load_state` é chamado no início do `main.asm`.
* **Salvamento automático ao encerrar:** `save_state` é chamado antes do `exit`.
* **Comandos de manutenção:**

  * `salvar` → grava o estado atual no arquivo.
  * `recarregar` → recarrega o último estado salvo (descarta alterações não salvas).
  * `formatar` → zera clientes e transações em memória (não salva automaticamente).
  * `conta_format-<CONTA6>-<DV>` → **zera os rings** (débito/crédito) **somente daquela conta** após confirmação `(s/N)`. Não apaga o cliente.

### Checklist rápido de persistência

1. `conta_cadastrar-12345678901-123456-Ana`
2. `salvar`
3. `exit`
4. Monte e rode de novo → os dados voltam automaticamente (R10).
5. Se quiser resetar a memória sem apagar o arquivo: `formatar` (e depois `recarregar` para voltar ao salvo).

### Soluções para “open(write) falhou”

* Execute o **MARS 4.5 a partir da pasta do projeto** (colocamos o JAR aqui justamente para isso).
* Garanta permissão de escrita na pasta.
* Se preferir, edite `state_filename` em `persist.asm` com um **caminho absoluto** (ex.: `C:/Users/seu_user/projeto/src/opcode_state.bin`).

---

## Comandos do shell

Formato geral: `comando-opcao1-opcao2-...` (strings terminadas em `\n`).
Banner: `opcode-shell>>`

### Básicos

* `help` — mostra ajuda
* `exit` — salva e encerra

### Cadastro e fechamento

* `conta_cadastrar-<CPF11>-<CONTA6>-<NOME>`
* `conta_fechar-<CONTA6>-<DV>`

### Débito / crédito / limite

* `pagar_debito-<CONTA6>-<DV>-<VALORcentavos>`
* `pagar_credito-<CONTA6>-<DV>-<VALORcentavos>`
* `alterar_limite-<CONTA6>-<DV>-<NOVO_LIMcentavos>`

### Fatura

* `pagar_fatura-<CONTA6>-<DV>-<VALORcentavos>-<METHOD>`

  * `METHOD = S` (saldo) ou `E` (externo)

### Saques e depósitos

* `sacar-<CONTA6>-<DV>-<VALORcentavos>`
* `depositar-<CONTA6>-<DV>-<VALORcentavos>`

### Extratos e dumps

* `debito_extrato-<CONTA6>-<DV>`
* `credito_extrato-<CONTA6>-<DV>`
* `dump_trans-deb-<CONTA6>-<DV>`
* `dump_trans-cred-<CONTA6>-<DV>`

### Data/hora

* `datetime_show`
* `datetime_set-<DD>/<MM>/<AAAA>- <HH>:<MM>:<SS>`

### Persistência e manutenção

* `salvar` — grava o arquivo de estado
* `recarregar` — lê o arquivo e restaura
* `formatar` — zera memória (sem salvar)
* `conta_format-<CONTA6>-<DV>` — zera apenas os rings da conta (com confirmação)

---

## Roteiro de Teste Rápido

1. Cadastro

   ```
   conta_cadastrar-12345678901-123456-Ana
   ```
2. Data/hora

   ```
   datetime_set-11/11/2025- 23:59:55
   datetime_show
   ```
3. Movimentos

   ```
   pagar_credito-123456-X-2000
   pagar_debito-123456-X-150
   debito_extrato-123456-X
   credito_extrato-123456-X
   ```
4. Fatura

   ```
   pagar_fatura-123456-X-150-S
   ```
5. Saques/depósitos

   ```
   depositar-123456-X-10000
   sacar-123456-X-5000
   debito_extrato-123456-X
   ```
6. Persistência

   ```
   salvar
   formatar
   recarregar  # deve voltar ao salvo
   ```
7. Encerrar (com tudo zerado)

   ```
   conta_fechar-123456-X
   ```

> Também disponibilizamos **`entrada.txt`** (com uma bateria de comandos) e o **`saida.txt`** correspondente, para comparação manual.

---

## Troubleshooting

* **“Comando invalido”** → verifique DV, número de opções e formatação do comando.
* **Relógio parado** → chame `datetime_set` ao menos uma vez e rode o loop (o `tick_datetime` é chamado a cada iteração).
* **Arquivo não cria / “open(write) falhou”** → execute o MARS a partir da pasta do projeto ou use `state_filename` absoluto no `persist.asm`.
* **Não fecha conta** → confira `debito_extrato` e `credito_extrato` (saldo e dívida precisam estar zerados).

---

## Autores

Equipe: **Cauã Lira**, **Lucas Emanuel**, **Sergio Ricardo**
Nome do banco: **opcode**
