# data.asm — dados globais e constantes do projeto (R1..R4)

.data
# ---- Exportações (usadas em outros arquivos) ----
.globl MAX_CLIENTS, NAME_MAX, CPF_STR_LEN, ACC_NUM_LEN, ACC_DV_LEN, LIMITE_PADRAO_CENT, TRANS_MAX
.globl inp_buf, bank_name, banner, help_txt, msg_invalid, msg_bye
.globl str_help, str_exit
.globl clientes_usado, clientes_cpf, clientes_conta, clientes_dv, clientes_nome
.globl clientes_saldo_cent, clientes_limite_cent, clientes_devido_cent
.globl str_cmd_cc_prefix, str_cmd_pay_debito, str_cmd_pay_credito, str_cmd_alt_limite
.globl msg_cc_ok, msg_cc_cpf_exists, msg_cc_acc_exists, msg_cc_full
.globl msg_cc_badfmt, msg_cc_badcpf, msg_cc_badacc, msg_cc_badname
.globl msg_pay_deb_ok, msg_pay_cred_ok, msg_err_saldo_insuf, msg_err_limite_insuf, msg_err_cli_inexist, msg_limite_ok, msg_limite_baixo_divida
# R3 – transações (exports usados em ops_fin.asm)
.globl trans_deb_vals, trans_cred_vals
.globl trans_deb_head, trans_deb_count, trans_deb_wptr
.globl trans_cred_head, trans_cred_count, trans_cred_wptr
# R3 – comandos de dump (se usados)
.globl str_cmd_dumpcred, str_cmd_dumpdeb
# buffers temporários do conta_cadastrar
.globl cc_buf_cpf, cc_buf_acc, cc_buf_nome
# R4 – data/hora usados por time.asm
.globl curr_day, curr_mon, curr_year, curr_hour, curr_min, curr_sec
.globl ms_last, ms_accum, month_days_norm
.globl str_cmd_time_set, str_cmd_time_show, msg_time_set_ok, msg_time_badfmt, msg_time_range

# ---- Constantes ----
MAX_CLIENTS:        .word 50
NAME_MAX:           .word 32           # +1 p/ '\0'
CPF_STR_LEN:        .word 11           # "XXXXXXXXXXX"
ACC_NUM_LEN:        .word 6            # "XXXXXX"
ACC_DV_LEN:         .word 1            # 1 caractere
LIMITE_PADRAO_CENT: .word 150000       # R$1500,00
TRANS_MAX:          .word 50           # máx trans por cliente (débito e crédito)

# ---- Buffers gerais (terminal) ----
inp_buf:    .space 256

# ---- Banner / textos do shell ----
bank_name:  .asciiz "opcode"
banner:     .asciiz "opcode-shell>> "
help_txt:   .asciiz "Comandos:\n- help\n- exit\n- conta_cadastrar-<CPF>-<CONTA6>-<NOME>\n- pagar_debito-<CONTA6>-<DV>-<VALORcent>\n- pagar_credito-<CONTA6>-<DV>-<VALORcent>\n- alterar_limite-<CONTA6>-<DV>-<NOVOLIMcent>\n- datetime_set-DD/MM/AAAA- HH:MM:SS\n- datetime_show\n"
msg_invalid:.asciiz "Comando invalido\n"
msg_bye:    .asciiz "Encerrando...\n"

# literais para comparação direta no main
str_help:   .asciiz "help"
str_exit:   .asciiz "exit"

# ---- Prefixos dos comandos principais ----
str_cmd_cc_prefix:     .asciiz "conta_cadastrar-"
str_cmd_pay_debito:    .asciiz "pagar_debito-"
str_cmd_pay_credito:   .asciiz "pagar_credito-"
str_cmd_alt_limite:    .asciiz "alterar_limite-"

# ---- Mensagens gerais ----
msg_cc_ok:          .asciiz "Cliente cadastrado com sucesso. Numero da conta "
msg_cc_cpf_exists:  .asciiz "Ja existe conta neste CPF\n"
msg_cc_acc_exists:  .asciiz "Numero da conta ja em uso\n"
msg_cc_full:        .asciiz "Falha: base de clientes cheia\n"
msg_cc_badfmt:      .asciiz "Falha: formato do comando invalido\n"
msg_cc_badcpf:      .asciiz "Falha: CPF invalido (11 digitos)\n"
msg_cc_badacc:      .asciiz "Falha: numero da conta invalido (6 digitos)\n"
msg_cc_badname:     .asciiz "Falha: nome vazio ou maior que 32\n"

msg_pay_deb_ok:         .asciiz "Pagamento em debito registrado\n"
msg_pay_cred_ok:        .asciiz "Pagamento em credito registrado\n"
msg_err_saldo_insuf:    .asciiz "Saldo insuficiente\n"
msg_err_limite_insuf:   .asciiz "Limite de credito insuficiente\n"
msg_err_cli_inexist:    .asciiz "Cliente inexistente\n"
msg_limite_ok:          .asciiz "Limite atualizado\n"
msg_limite_baixo_divida:.asciiz "Novo limite menor que a divida atual\n"

# ==========================
#   Estruturas dos clientes
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

# ==========================
#   R3 – buffers de transações (por cliente)
#   - Cada cliente tem 50 slots por tipo (débito e crédito)
#   - Cada entrada guarda o valor em centavos (word)
#   - head: próximo slot p/ escrever (circular 0..49)
#   - count: qtde válida (0..50)
#   - wptr: mantido por compatibilidade (se usado em algum lugar)
# ==========================
.align 2
trans_deb_head:   .space 200            # 50 * 4
.align 2
trans_deb_count:  .space 200            # 50 * 4
.align 2
trans_deb_wptr:   .space 200            # 50 * 4 (opcional/compat)

.align 2
trans_cred_head:  .space 200            # 50 * 4
.align 2
trans_cred_count: .space 200            # 50 * 4
.align 2
trans_cred_wptr:  .space 200            # 50 * 4 (opcional/compat)

# valores (50 clientes * 50 slots * 4 bytes = 10000)
.align 2
trans_deb_vals:   .space 10000
.align 2
trans_cred_vals:  .space 10000

# comandos de dump (opcional)
str_cmd_dumpcred: .asciiz "dump_trans-cred-"
str_cmd_dumpdeb:  .asciiz "dump_trans-deb-"

# ---- buffers temporários do handler conta_cadastrar ----
cc_buf_cpf:   .space 12   # 11 dígitos + '\0'
cc_buf_acc:   .space 7    # 6 dígitos + '\0'
cc_buf_nome:  .space 33   # até 32 + '\0'

# ==========================
#   R4 – Data/Hora (time.asm)
# ==========================
.align 2
curr_day:   .word 1
curr_mon:   .word 1
curr_year:  .word 2025
curr_hour:  .word 0
curr_min:   .word 0
curr_sec:   .word 0

.align 2
ms_last:    .word 0
ms_accum:   .word 0

# dias de cada mes (não-bissexto)
month_days_norm:
    .word 31,28,31,30,31,30,31,31,30,31,30,31

# comandos/msgs de time
str_cmd_time_set:  .asciiz "datetime_set-"
str_cmd_time_show: .asciiz "datetime_show"
msg_time_set_ok:   .asciiz "Data/hora configurada\n"
msg_time_badfmt:   .asciiz "Formato invalido (use DD/MM/AAAA- HH:MM:SS)\n"
msg_time_range:    .asciiz "Valores fora de faixa\n"
