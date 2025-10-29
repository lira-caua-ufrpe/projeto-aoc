# ============================================================
# data.asm – Estruturas, constantes e armazenamento
# ============================================================

.data
# ---- limites ----
.eqv MAX_CLIENTES 50
.eqv MAX_TX       50          # por tipo (débito e crédito)

# ---- tamanhos e offsets (struct Cliente) ----
.eqv CLI_ATIVO     0          # byte 1=ativo, 0=livre
.eqv CLI_CPF       1          # 11+1 ('\0') = 12 bytes
.eqv CLI_CONTA     13         # 6 dígitos + '-' + DV + '\0' = 9 bytes (ex: 123456-7)
.eqv CLI_NOME      22         # nome 32 bytes
.eqv CLI_SALDO     54         # word (centavos)
.eqv CLI_LIMITE    58         # word (centavos)
.eqv CLI_DIVCRED   62         # word (centavos, dívida atual cartão)
.eqv CLI_IDX_DEB   66         # word índice circular débito
.eqv CLI_IDX_CRE   70         # word índice circular crédito
.eqv CLI_END       74         # tamanho da struct Cliente

# ---- buffers auxiliares ----
banner:    .asciiz "greenbank-shell>> "
linha_in:  .space 128         # linha de comando lida
tok_ptrs:  .space 16          # até 4 tokens (4 * 4 bytes)
tmp_str:   .space 32

# ---- relógio (DD/MM/AAAA - HH:MM:SS) ----
datahora:  .space 20          # 19 + '\0'
last_ms:   .word 0            # p/ atualizar segundos (syscall 30)
acc_ms:    .word 0            # acumulador milissegundos para juros

# ---- armazenamento principal ----
# Clientes: MAX_CLIENTES * CLI_END bytes
clientes:  .space (MAX_CLIENTES * CLI_END)

# ---- transações (por cliente e tipo) ----
# cada registro: conta_dest (9) + valor (word) + datahora (20) = 33 -> alinhar para 36
.eqv TX_CONTA   0     # 9 bytes (string conta destino XXXXXX-X\0)
.eqv TX_VALOR   12    # word (centavos)
.eqv TX_DATA    16    # 20 bytes (datahora)
.eqv TX_SIZE    36
# débito e crédito (circulares)
tx_deb: .space (MAX_CLIENTES * MAX_TX * TX_SIZE)
tx_cre: .space (MAX_CLIENTES * MAX_TX * TX_SIZE)

# ---- literais e mensagens ----
msg_ok_cad:     .asciiz "Cliente cadastrado com sucesso. Numero da conta "
msg_err_cpf:    .asciiz "Ja existe conta neste CPF\n"
msg_err_conta:  .asciiz "Numero da conta ja em uso\n"
msg_inv_cmd:    .asciiz "Comando invalido\n"
msg_nl:         .asciiz "\n"
str_hifen:      .asciiz "-"
str_juros:      .asciiz "JUROS"

.text
