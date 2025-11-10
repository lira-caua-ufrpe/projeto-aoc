# data.asm — dados globais e constantes do projeto

.data
.globl MAX_CLIENTS, NAME_MAX, CPF_STR_LEN, ACC_NUM_LEN, ACC_DV_LEN, LIMITO_PADRAO_CENT
.globl inp_buf, bank_name, banner, help_txt, msg_invalid, msg_bye
.globl str_help, str_exit
.globl clientes_usado, clientes_cpf, clientes_conta, clientes_dv, clientes_nome
.globl clientes_saldo_cent, clientes_limite_cent, clientes_devido_cent
.globl str_cmd_cc_prefix
.globl msg_cc_ok, msg_cc_cpf_exists, msg_cc_acc_exists

# --- Constantes do sistema ---
MAX_CLIENTS:        .word 50
NAME_MAX:           .word 32          # +1 p/ '\0' no armazenamento
CPF_STR_LEN:        .word 11          # "XXXXXXXXXXX" (11 digitos)
ACC_NUM_LEN:        .word 6           # "XXXXXX"
ACC_DV_LEN:         .word 1           # 1 caractere
LIMITO_PADRAO_CENT: .word 150000      # R$1500,00 em centavos

# --- Buffers gerais (terminal) ---
inp_buf:    .space 256

# --- Banner / textos do shell ---
bank_name:  .asciiz "opcode"
banner:     .asciiz "opcode-shell>> "
help_txt:   .asciiz "Comandos:\n- help                : mostra esta ajuda\n- exit                : sai do programa\n(Proximo: conta_cadastrar-<CPF>-<CONTA6>-<NOME>)\n"
msg_invalid:.asciiz "Comando invalido\n"
msg_bye:    .asciiz "Encerrando...\n"

# --- literais usados no dispatch ---
str_help:   .asciiz "help"
str_exit:   .asciiz "exit"

# --- Prefixo do comando conta_cadastrar ---
str_cmd_cc_prefix: .asciiz "conta_cadastrar-"

# --- Mensagens especificas de conta_cadastrar ---
msg_cc_ok:          .asciiz "Cliente cadastrado com sucesso. Numero da conta "
msg_cc_cpf_exists:  .asciiz "Ja existe conta neste CPF\n"
msg_cc_acc_exists:  .asciiz "Numero da conta ja em uso\n"

# ==========================
#   Estruturas dos clientes
# ==========================
# Layout: ate 50 clientes.
# - clientes_usado[i]        : 0 livre / 1 ocupado
# - clientes_cpf[i]          : 12 bytes (11 digitos + '\0')
# - clientes_conta[i]        : 7 bytes  (6 digitos + '\0')
# - clientes_dv[i]           : 1 byte   (ASCII do DV: '0'..'9' ou 'X')
# - clientes_nome[i]         : 33 bytes (ate 32 + '\0')
# - clientes_saldo_cent[i]   : .word
# - clientes_limite_cent[i]  : .word
# - clientes_devido_cent[i]  : .word  (divida do cartao)

clientes_usado:        .space 50           # 50 * 1 = 50 bytes

# 50 * 12 = 600 bytes
clientes_cpf:          .space 600

# 50 * 7 = 350 bytes
clientes_conta:        .space 350

# 50 * 1 = 50 bytes
clientes_dv:           .space 50

# 50 * 33 = 1650 bytes
clientes_nome:         .space 1650

# saldos/limites/divida (50 * 4 bytes cada = 200 bytes)
clientes_saldo_cent:   .space 200
clientes_limite_cent:  .space 200
clientes_devido_cent:  .space 200
