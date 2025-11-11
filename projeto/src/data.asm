# data.asm — dados globais (R1 + R2)

.data
# ---- Exportações ----
.globl MAX_CLIENTS, NAME_MAX, CPF_STR_LEN, ACC_NUM_LEN, ACC_DV_LEN, LIMITE_PADRAO_CENT
.globl inp_buf, bank_name, banner, help_txt, msg_invalid, msg_bye, str_help, str_exit
.globl str_cmd_cc_prefix, str_cmd_pay_debito, str_cmd_pay_credito, str_cmd_alt_limite
.globl msg_cc_ok, msg_cc_cpf_exists, msg_cc_acc_exists, msg_cc_full
.globl msg_cc_badfmt, msg_cc_badcpf, msg_cc_badacc, msg_cc_badname
.globl msg_pay_deb_ok, msg_pay_cred_ok, msg_err_saldo_insuf, msg_err_limite_insuf, msg_err_cli_inexist
.globl msg_limite_ok, msg_limite_baixo_divida
.globl clientes_usado, clientes_cpf, clientes_conta, clientes_dv, clientes_nome
.globl clientes_saldo_cent, clientes_limite_cent, clientes_devido_cent
.globl cc_buf_cpf, cc_buf_acc, cc_buf_nome

# ---- Constantes ----
MAX_CLIENTS:         .word 50
NAME_MAX:            .word 32
CPF_STR_LEN:         .word 11
ACC_NUM_LEN:         .word 6
ACC_DV_LEN:          .word 1
LIMITE_PADRAO_CENT:  .word 150000        # R$ 1500,00 em centavos

# ---- Buffers gerais ----
inp_buf:    .space 256

# ---- Textos do shell ----
bank_name:  .asciiz "opcode"
banner:     .asciiz "opcode-shell>> "
help_txt:   .asciiz "Comandos:\n- help                : mostra esta ajuda\n- exit                : sai do programa\n(Proximo: conta_cadastrar-<CPF>-<CONTA6>-<NOME>)\n"
msg_invalid:.asciiz "Comando invalido\n"
msg_bye:    .asciiz "Encerrando...\n"
str_help:   .asciiz "help"
str_exit:   .asciiz "exit"

# ---- Prefixos de comandos ----
str_cmd_cc_prefix:    .asciiz "conta_cadastrar-"
str_cmd_pay_debito:   .asciiz "pagar_debito-"
str_cmd_pay_credito:  .asciiz "pagar_credito-"
str_cmd_alt_limite:   .asciiz "alterar_limite-"

# ---- Mensagens R1 ----
msg_cc_ok:          .asciiz "Cliente cadastrado com sucesso. Numero da conta "
msg_cc_cpf_exists:  .asciiz "Ja existe conta neste CPF\n"
msg_cc_acc_exists:  .asciiz "Numero da conta ja em uso\n"
msg_cc_full:        .asciiz "Falha: base de clientes cheia\n"
msg_cc_badfmt:      .asciiz "Falha: formato do comando invalido\n"
msg_cc_badcpf:      .asciiz "Falha: CPF invalido (11 digitos)\n"
msg_cc_badacc:      .asciiz "Falha: numero da conta invalido (6 digitos)\n"
msg_cc_badname:     .asciiz "Falha: nome vazio ou maior que 32\n"

# ---- Mensagens R2 ----
msg_pay_deb_ok:          .asciiz "Pagamento em debito efetuado\n"
msg_pay_cred_ok:         .asciiz "Pagamento em credito efetuado\n"
msg_err_saldo_insuf:     .asciiz "Saldo insuficiente\n"
msg_err_limite_insuf:    .asciiz "Limite de credito insuficiente\n"
msg_err_cli_inexist:     .asciiz "Cliente inexistente\n"
msg_limite_ok:           .asciiz "Limite ajustado com sucesso\n"
msg_limite_baixo_divida: .asciiz "Novo limite menor que divida atual\n"

# ==========================
#  Estruturas dos clientes
# ==========================
# bytes
clientes_usado:        .space 50        # 50 * 1
clientes_cpf:          .space 600       # 50 * 12
clientes_conta:        .space 350       # 50 * 7
clientes_dv:           .space 50        # 50 * 1
clientes_nome:         .space 1650      # 50 * 33

# words (alinhados)
.align 2
clientes_saldo_cent:   .space 200       # 50 * 4
.align 2
clientes_limite_cent:  .space 200       # 50 * 4
.align 2
clientes_devido_cent:  .space 200       # 50 * 4

# ---- Buffers temporários para parsers ----
cc_buf_cpf:   .space 12   # 11 + '\0'
cc_buf_acc:   .space 7    # 6 + '\0'
cc_buf_nome:  .space 33   # até 32 + '\0'
