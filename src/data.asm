# data.asm — dados globais e constantes do projeto

.data
.globl MAX_CLIENTS, NAME_MAX, CPF_STR_LEN, ACC_NUM_LEN, ACC_DV_LEN, LIMITO_PADRAO_CENT
.globl inp_buf, bank_name, banner, help_txt, msg_invalid, msg_bye

# --- Constantes do sistema ---
MAX_CLIENTS:        .word 50
NAME_MAX:           .word 32
CPF_STR_LEN:        .word 11
ACC_NUM_LEN:        .word 6
ACC_DV_LEN:         .word 1
LIMITO_PADRAO_CENT: .word 150000   # R$1500,00 em centavos

# --- Buffers gerais ---
inp_buf:    .space 256

# --- Banner / textos ---
bank_name:  .asciiz "opcode"
banner:     .asciiz "opcode-shell>> "
help_txt:   .asciiz "Comandos:\n- help                : mostra esta ajuda\n- exit                : sai do programa\n(Proximo: conta_cadastrar-<CPF>-<CONTA6>-<NOME>)\n"

# --- Mensagens ---
msg_invalid: .asciiz "Comando invalido\n"
msg_bye:     .asciiz "Encerrando...\n"
