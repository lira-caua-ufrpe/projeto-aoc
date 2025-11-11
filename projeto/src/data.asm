# data.asm — dados globais e constantes do projeto

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

# --- R3: transações (exports) ---
.globl trans_deb_vals, trans_cred_vals
.globl trans_deb_wptr, trans_cred_wptr
.globl trans_deb_head, trans_deb_count
.globl trans_cred_head, trans_cred_count
.globl str_cmd_dumpcred, str_cmd_dumpdeb

# ---- Constantes do sistema ----
MAX_CLIENTS:        .word 50
NAME_MAX:           .word 32           # +1 p/ '\0' no armazenamento
CPF_STR_LEN:        .word 11           # "XXXXXXXXXXX" (11 dígitos)
ACC_NUM_LEN:        .word 6            # "XXXXXX"
ACC_DV_LEN:         .word 1            # 1 caractere
LIMITE_PADRAO_CENT: .word 150000       # R$1500,00 em centavos
TRANS_MAX:          .word 50           # máx transações por cliente (débito e crédito)

# ---- Buffers gerais (terminal) ----
inp_buf:    .space 256

# ---- Banner / textos do shell ----
bank_name:  .asciiz "opcode"
banner:     .asciiz "opcode-shell>> "
help_txt:   .asciiz "Comandos:\n- help                : mostra esta ajuda\n- exit                : sai do programa\n- conta_cadastrar-<CPF>-<CONTA6>-<NOME>\n- pagar_debito-<CONTA6>-<DV>-<VALORcentavos>\n- pagar_credito-<CONTA6>-<DV>-<VALORcentavos>\n- alterar_limite-<CONTA6>-<DV>-<NOVO_LIMcentavos>\n"
msg_invalid:.asciiz "Comando invalido\n"
msg_bye:    .asciiz "Encerrando...\n"

# literais para comparação direta no main
str_help:   .asciiz "help"
str_exit:   .asciiz "exit"

# ---- Prefixos dos comandos ----
str_cmd_cc_prefix:     .asciiz "conta_cadastrar-"
str_cmd_pay_debito:    .asciiz "pagar_debito-"
str_cmd_pay_credito:   .asciiz "pagar_credito-"
str_cmd_alt_limite:    .asciiz "alterar_limite-"

# ---- Mensagens específicas ----
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
# - clientes_usado[i]        : 0 livre / 1 ocupado
# - clientes_cpf[i]          : 12 bytes (11 dígitos + '\0')
# - clientes_conta[i]        : 7 bytes  (6 dígitos + '\0')
# - clientes_dv[i]           : 1 byte   (ASCII do DV: '0'..'9' ou 'X')
# - clientes_nome[i]         : 33 bytes (ate 32 + '\0')
# - clientes_saldo_cent[i]   : .word
# - clientes_limite_cent[i]  : .word
# - clientes_devido_cent[i]  : .word  (divida do cartao)

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

# ---- buffers temporários do handler conta_cadastrar ----
cc_buf_cpf:   .space 12   # 11 dígitos + '\0'
cc_buf_acc:   .space 7    # 6 dígitos + '\0'
cc_buf_nome:  .space 33   # até 32 + '\0'

# ==========================
#   R3 – buffers de transações (por cliente)
#   - Cada cliente tem 50 slots por tipo (débito e crédito)
#   - Cada entrada guarda o valor em centavos (word)
#   - Índice de escrita (wptr/head) é circular [0..49]
#   - Layout linear de vals: base + (i*50 + k)*4
# ==========================

# ponteiros de escrita (wptr) – se seu handler usa esses nomes
.align 2
trans_deb_wptr:   .space 200      # 50 * 4 bytes
.align 2
trans_cred_wptr:  .space 200      # 50 * 4 bytes

# opcional: head/count (seus dumps podem usar)
.align 2
trans_deb_head:   .space 200
.align 2
trans_deb_count:  .space 200
.align 2
trans_cred_head:  .space 200
.align 2
trans_cred_count: .space 200

# valores das transações (centavos) – 50 clientes * 50 slots * 4 bytes
.align 2
trans_deb_vals:   .space 10000    # 50*50*4
.align 2
trans_cred_vals:  .space 10000    # 50*50*4

# --- Prefixos de debug (R3) ---
str_cmd_dumpcred: .asciiz "dump_trans-cred-"
str_cmd_dumpdeb:  .asciiz "dump_trans-deb-"
