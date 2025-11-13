# data.asm ï¿½ dados globais e constantes do projeto (R1..R4)

        .data

# ---- Exportaï¿½ï¿½es (usadas em outros arquivos) ----
# IMPORTANTE: Nï¿½o declare .globl destes sï¿½mbolos em nenhum outro arquivo.
        .globl  MAX_CLIENTS, NAME_MAX, CPF_STR_LEN, ACC_NUM_LEN, ACC_DV_LEN, LIMITE_PADRAO_CENT, TRANS_MAX
        .globl  inp_buf, bank_name, banner, help_txt, msg_invalid, msg_bye
        .globl  str_help, str_exit
        .globl  clientes_usado, clientes_cpf, clientes_conta, clientes_dv, clientes_nome
        .globl  clientes_saldo_cent, clientes_limite_cent, clientes_devido_cent
        .globl  str_cmd_cc_prefix, str_cmd_pay_debito, str_cmd_pay_credito, str_cmd_alt_limite, str_cmd_pay_fatura
        .globl  msg_cc_ok, msg_cc_cpf_exists, msg_cc_acc_exists, msg_cc_full
        .globl  msg_cc_badfmt, msg_cc_badcpf, msg_cc_badacc, msg_cc_badname
        .globl  msg_pay_deb_ok, msg_pay_cred_ok, msg_err_saldo_insuf, msg_err_limite_insuf
        .globl  msg_err_cli_inexist, msg_limite_ok, msg_limite_baixo_divida
        # R3 ï¿½ transaï¿½ï¿½es
        .globl  trans_deb_vals, trans_cred_vals
        .globl  trans_deb_head, trans_deb_count, trans_deb_wptr
        .globl  trans_cred_head, trans_cred_count, trans_cred_wptr
        # comandos de dump
        .globl  str_cmd_dumpcred, str_cmd_dumpdeb
        # buffers temporï¿½rios
        .globl  cc_buf_cpf, cc_buf_acc, cc_buf_nome
        # R4 ï¿½ data/hora
        .globl  curr_day, curr_mon, curr_year, curr_hour, curr_min, curr_sec
        .globl  ms_last, ms_accum, month_days_norm
        .globl  str_cmd_time_set, str_cmd_time_show, msg_time_set_ok, msg_time_badfmt, msg_time_range
        # buffer usado por formatar_real / formatar_centavos
        .globl  buffer_valor_formatado
        .globl  str_cmd_sacar, str_cmd_depositar



# ---- Constantes ----
MAX_CLIENTS:        .word 50
NAME_MAX:           .word 32
CPF_STR_LEN:        .word 11
ACC_NUM_LEN:        .word 6
ACC_DV_LEN:         .word 1
LIMITE_PADRAO_CENT: .word 150000       # R$ 1500,00
TRANS_MAX:          .word 50           # capacidade do ring buffer por cliente

# ---- Buffers gerais (terminal) ----
inp_buf:                    .space 256
buffer_valor_formatado:     .space 32    # "R$ 1.234.567,89" cabe tranquilo
# Buffer para armazenar o dÃ­gito verificador (DV)
cc_buf_dv:  .space 1   # 1 byte para o DV (um Ãºnico caractere)


# ---- Banner / textos do shell ----
bank_name:  .asciiz "opcode"
banner:     .asciiz "opcode-shell>> "
help_txt:   .asciiz "Comandos:\n- help\n- exit\n- conta_cadastrar-<CPF>-<CONTA6>-<NOME>\n- pagar_debito-<CONTA6>-<DV>-<VALORcent>\n- pagar_credito-<CONTA6>-<DV>-<VALORcent>\n- alterar_limite-<CONTA6>-<DV>-<NOVOLIMcent>\n- dump_trans-cred-<CONTA6>-<DV>\n- dump_trans-deb-<CONTA6>-<DV>\n- datetime_set-DD/MM/AAAA- HH:MM:SS\n- datetime_show\n- debito_extrato-<CONTA6>-<DV>\n- credito_extrato-<CONTA6>-<DV>\n"
msg_invalid:.asciiz "Comando invalido\n"
msg_bye:    .asciiz "Encerrando...\n"

# literais para comparaï¿½ï¿½o direta no main
str_help:   .asciiz "help"
str_exit:   .asciiz "exit"

# ---- Prefixos dos comandos principais ----
str_cmd_cc_prefix:     .asciiz "conta_cadastrar-"
str_cmd_pay_debito:    .asciiz "pagar_debito-"
str_cmd_pay_credito:   .asciiz "pagar_credito-"
str_cmd_alt_limite:    .asciiz "alterar_limite-"
str_cmd_pay_fatura:    .asciiz "pagar_fatura-" 
str_cmd_sacar:         .asciiz "sacar-"
str_cmd_depositar:     .asciiz "depositar-"




# ---- Mensagens gerais ----
msg_cc_ok:              .asciiz "Cliente cadastrado com sucesso. Numero da conta "
msg_cc_cpf_exists:      .asciiz "Ja existe conta neste CPF\n"
msg_cc_acc_exists:      .asciiz "Numero da conta ja em uso\n"
msg_cc_full:            .asciiz "Falha: base de clientes cheia\n"
msg_cc_badfmt:          .asciiz "Falha: formato do comando invalido\n"
msg_cc_badcpf:          .asciiz "Falha: CPF invalido (11 digitos)\n"
msg_cc_badacc:          .asciiz "Falha: numero da conta invalido (6 digitos)\n"
msg_cc_badname:         .asciiz "Falha: nome vazio ou maior que 32\n"

msg_pay_deb_ok:         .asciiz "Pagamento em debito registrado\n"
msg_pay_cred_ok:        .asciiz "Pagamento em credito registrado\n"
msg_err_saldo_insuf:    .asciiz "Saldo insuficiente\n"
msg_err_limite_insuf:   .asciiz "Limite de credito insuficiente\n"
msg_err_cli_inexist:    .asciiz "Cliente inexistente\n"
msg_limite_ok:          .asciiz "Limite atualizado\n"
msg_limite_baixo_divida:.asciiz "Novo limite menor que a divida atual\n"
msg_err_valor_maior:     .asciiz "Falha: valor fornecido maior que a dÃ­vida do cartÃ£o\n"
msg_pago_com_sucesso:    .asciiz "Pagamento realizado com sucesso!\n"

msg_saque_ok:          .asciiz "Saque realizado\n"
msg_dep_ok:            .asciiz "Deposito realizado\n"



# ==========================
#   Estruturas dos clientes
# ==========================
clientes_usado:        .space 50        # 50 * 1 (bytes 0/1)
clientes_cpf:          .space 600       # 50 * 12 (11 + '\0')
clientes_conta:        .space 350       # 50 * 7  (6 + '\0')
clientes_dv:           .space 50
clientes_nome:         .space 1650      # 50 * 33 (32 + '\0')

# words alinhados
        .align 2
clientes_saldo_cent:       .word 0:50

        .align 2
clientes_limite_cent:      .word 0:50

        .align 2
clientes_devido_cent:      .word 0:50

# ==========================
#   R3 ï¿½ buffers de transaï¿½ï¿½es (por cliente)
# ==========================
# head/count/wptr como WORDs (inicializados em 0)
        .align 2
trans_deb_head:            .word 0:50
        .align 2
trans_deb_count:           .word 0:50
        .align 2
trans_deb_wptr:            .word 0:50

        .align 2
trans_cred_head:           .word 0:50
        .align 2
trans_cred_count:          .word 0:50
        .align 2
trans_cred_wptr:           .word 0:50

# valores das transaï¿½ï¿½es (centavos) ï¿½ 50 clientes * 50 slots = 2500 words
        .align 2
trans_deb_vals:            .word 0:2500
        .align 2
trans_cred_vals:           .word 0:2500

# comandos de dump
str_cmd_dumpcred:  .asciiz "dump_trans-cred-"
str_cmd_dumpdeb:   .asciiz "dump_trans-deb-"

# buffers temporï¿½rios
cc_buf_cpf:   .space 12   # 11 + '\0'
cc_buf_acc:   .space 7    # 6 + '\0'
cc_buf_nome:  .space 33   # 32 + '\0'

# ==========================
#   R4 ï¿½ Data/Hora
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

month_days_norm:
        .word 31,28,31,30,31,30,31,31,30,31,30,31

str_cmd_time_set:  .asciiz "datetime_set-"
str_cmd_time_show: .asciiz "datetime_show"
msg_time_set_ok:   .asciiz "Data/hora configurada\n"
msg_time_badfmt:   .asciiz "Formato invalido (use DD/MM/AAAA- HH:MM:SS)\n"
msg_time_range:    .asciiz "Valores fora de faixa\n"

# ===================== R7: Juros automáticos =====================
# 1% a cada 60 segundos. Vamos controlar por um relógio absoluto
# em segundos e lembrar o último instante em que aplicamos juros.

.data
    .align 2

    # --- Constantes de juros ---
    .globl JUROS_PERIOD_SEC
    .globl JUROS_RATE_NUM
    .globl JUROS_RATE_DEN
JUROS_PERIOD_SEC:   .word 60       # a cada 60s
JUROS_RATE_NUM:     .word 1        # 1%  -> numerador
JUROS_RATE_DEN:     .word 100      #       denominador

    # --- Relógio absoluto (segundos desde o "boot" do app) ---
    # Será incrementado pelo tick em time.asm
    .globl curr_abssec
curr_abssec:        .word 0

    # --- Último instante em que os juros foram aplicados ---
    # Em segundos absolutos (mesma base do curr_abssec)
    .globl juros_last_abssec
juros_last_abssec:  .word 0

 # --- Gate de reentrada para rotina de juros (usado em ops_fin.asm) ---
    .globl juros_gate
juros_gate:          .word 0      # 0 = liberado; 1 = travado (ops_fin controla)

    # --- Convenção de registro no ring buffer de crédito ---
    # Juros serão inseridos em trans_cred_vals como VALOR NEGATIVO.
    # Isso evita criar novo array de "tipo". O extrato imprimirá "JUROS"
    # quando encontrar valor < 0 (e mostrará |valor|).
    .globl JUROS_USA_VALOR_NEG
JUROS_USA_VALOR_NEG: .word 1
# ================================================================

