# data.asm — dados globais e constantes do projeto

.data
# ---- Exportações (usadas em outros arquivos) ----
.globl MAX_CLIENTS, NAME_MAX, CPF_STR_LEN, ACC_NUM_LEN, ACC_DV_LEN, LIMITE_PADRAO_CENT
.globl inp_buf, bank_name, banner, help_txt, msg_invalid, msg_bye
.globl str_help, str_exit
.globl clientes_usado, clientes_cpf, clientes_conta, clientes_dv, clientes_nome
.globl clientes_saldo_cent, clientes_limite_cent, clientes_devido_cent
.globl str_cmd_cc_prefix
.globl msg_cc_ok, msg_cc_cpf_exists, msg_cc_acc_exists, msg_cc_full
.globl msg_cc_badfmt, msg_cc_badcpf, msg_cc_badacc, msg_cc_badname
.globl cc_buf_cpf, cc_buf_acc, cc_buf_nome

# ---- Constantes do sistema ----
MAX_CLIENTS:        .word 50
NAME_MAX:           .word 32           # +1 p/ '\0' no armazenamento
CPF_STR_LEN:        .word 11           # "XXXXXXXXXXX" (11 dígitos)
ACC_NUM_LEN:        .word 6            # "XXXXXX"
ACC_DV_LEN:         .word 1            # 1 caractere
LIMITE_PADRAO_CENT: .word 150000       # R$1500,00 em centavos

# ---- Buffers gerais (terminal) ----
inp_buf:    .space 256

# ---- Banner / textos do shell ----
bank_name:  .asciiz "opcode"
banner:     .asciiz "opcode-shell>> "
help_txt:   .asciiz "Comandos:\n- help                : mostra esta ajuda\n- exit                : sai do programa\n(Proximo: conta_cadastrar-<CPF>-<CONTA6>-<NOME>)\n"
msg_invalid:.asciiz "Comando invalido\n"
msg_bye:    .asciiz "Encerrando...\n"

# literais para comparação direta no main
str_help:   .asciiz "help"
str_exit:   .asciiz "exit"

# ---- Prefixo do comando conta_cadastrar ----
str_cmd_cc_prefix: .asciiz "conta_cadastrar-"

# ---- Mensagens específicas de conta_cadastrar ----
msg_cc_ok:          .asciiz "Cliente cadastrado com sucesso. Numero da conta "
msg_cc_cpf_exists:  .asciiz "Ja existe conta neste CPF\n"
msg_cc_acc_exists:  .asciiz "Numero da conta ja em uso\n"
msg_cc_full:        .asciiz "Falha: base de clientes cheia\n"
msg_cc_badfmt:      .asciiz "Falha: formato do comando invalido\n"
msg_cc_badcpf:      .asciiz "Falha: CPF invalido (11 digitos)\n"
msg_cc_badacc:      .asciiz "Falha: numero da conta invalido (6 digitos)\n"
msg_cc_badname:     .asciiz "Falha: nome vazio ou maior que 32\n"

# ==========================
#   Estruturas dos clientes
# ==========================
# bytes
clientes_usado:        .space 50        # 50 * 1
clientes_cpf:          .space 600       # 50 * 12  (11 + '\0')
clientes_conta:        .space 350       # 50 * 7   (6 + '\0')
clientes_dv:           .space 50        # 50 * 1
clientes_nome:         .space 1650      # 50 * 33  (32 + '\0')

# words (alinhados)
.align 2
clientes_saldo_cent:   .space 200       # 50 * 4
.align 2
clientes_limite_cent:  .space 200       # 50 * 4
.align 2
clientes_devido_cent:  .space 200       # 50 * 4

# ---- buffers temporários do handler conta_cadastrar ----
cc_buf_cpf:   .space 12   # 11 dígitos + '\0'
cc_buf_acc:   .space 7    # 6 dígitos + '\0'
cc_buf_nome:  .space 33   # até 32 + '\0'
