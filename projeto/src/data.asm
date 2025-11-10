# data.asm — dados globais e constantes do projeto
.data

# ===============================================
# 1. EXPORTAÇÕES GLOBAIS (.globl)
# ===============================================

# --- Constantes ---
.globl MAX_CLIENTS, NAME_MAX, CPF_STR_LEN, ACC_NUM_LEN, ACC_DV_LEN, LIMITE_PADRAO_CENT

# --- Estruturas de Clientes ---
.globl clientes_usado, clientes_cpf, clientes_conta, clientes_dv, clientes_nome
.globl clientes_saldo_cent, clientes_limite_cent, clientes_devido_cent

# --- Buffers ---
.globl inp_buf
.globl cc_buf_cpf, cc_buf_acc, cc_buf_nome

# --- Textos e Comandos (Prefixos) ---
.globl bank_name, banner, help_txt, str_help, str_exit
.globl str_cmd_cc_prefix
.globl str_cmd_pay_debito, str_cmd_pay_credito, str_cmd_alt_limite

# --- Mensagens de Retorno ---
.globl msg_invalid, msg_bye
# Mensagens R1 (Cadastro de Conta)
.globl msg_cc_ok, msg_cc_cpf_exists, msg_cc_acc_exists, msg_cc_full
.globl msg_cc_badfmt, msg_cc_badcpf, msg_cc_badacc, msg_cc_badname
# Mensagens R2 (Operações Financeiras)
.globl msg_pay_deb_ok, msg_pay_cred_ok
.globl msg_err_cli_inexist, msg_err_saldo_insuf, msg_err_limite_insuf
.globl msg_limite_ok, msg_limite_baixo_divida, msg_conta_invalida

# -----------------------------------------------
# 2. CONSTANTES DO SISTEMA (.word)
# -----------------------------------------------
MAX_CLIENTS:        .word 50           # Número máximo de clientes
NAME_MAX:           .word 32           # Tamanho máximo do nome (sem \0)
CPF_STR_LEN:        .word 11           # Tamanho do CPF ("XXXXXXXXXXX")
ACC_NUM_LEN:        .word 6            # Tamanho do número da conta ("XXXXXX")
ACC_DV_LEN:         .word 1            # Tamanho do Dígito Verificador
LIMITE_PADRAO_CENT: .word 150000       # R$1500,00 em centavos

# -----------------------------------------------
# 3. BUFFERS DE TRABALHO TEMPORÁRIO (.space)
# -----------------------------------------------
# Buffers gerais (terminal)
inp_buf:    .space 256               # Buffer de entrada para comandos

# Buffers temporários do handler de cadastro (conta_cadastrar)
cc_buf_cpf:   .space 12             # 11 dígitos + '\0'
cc_buf_acc:   .space 7              # 6 dígitos + '\0'
cc_buf_nome:  .space 33             # até 32 + '\0'

# -----------------------------------------------
# 4. ESTRUTURAS DE DADOS DOS CLIENTES (Arrays)
# -----------------------------------------------
# (50 * X)

# Membros de tamanho byte/char
clientes_usado:        .space 50        # Flag (1 byte) se a posição está em uso
clientes_dv:           .space 50        # Dígito verificador (1 byte)

# Membros de tamanho string
clientes_cpf:          .space 600       # CPF (50 * 12 bytes: 11 + '\0')
clientes_conta:        .space 350       # Conta (50 * 7 bytes: 6 + '\0')
clientes_nome:         .space 1650      # Nome (50 * 33 bytes: 32 + '\0')

# Membros de tamanho word (4 bytes - valores em centavos)
.align 2
clientes_saldo_cent:   .space 200       # Saldo (50 * 4 bytes)
.align 2
clientes_limite_cent:  .space 200       # Limite de crédito (50 * 4 bytes)
.align 2
clientes_devido_cent:  .space 200       # Dívida de crédito (50 * 4 bytes)

# -----------------------------------------------
# 5. TEXTOS, BANNERS E COMANDOS (.asciiz)
# -----------------------------------------------
# Banner / textos do shell
bank_name:  .asciiz "opcode"
banner:     .asciiz "opcode-shell>> "
help_txt:   .asciiz "Comandos:\n- help                : mostra esta ajuda\n- exit                : sai do programa\n(Proximo: conta_cadastrar-<CPF>-<CONTA6>-<NOME>)\n"

# Literais de comparação
str_help:   .asciiz "help"
str_exit:   .asciiz "exit"

# Prefixos dos comandos
str_cmd_cc_prefix:   .asciiz "conta_cadastrar-"
str_cmd_pay_debito:   .asciiz "pagar_debito-"
str_cmd_pay_credito:  .asciiz "pagar_credito-"
str_cmd_alt_limite:   .asciiz "alterar_limite-"

# -----------------------------------------------
# 6. MENSAGENS DE RETORNO (.asciiz)
# -----------------------------------------------

# Mensagens gerais
msg_invalid:.asciiz "Comando invalido\n"
msg_bye:    .asciiz "Encerrando...\n"

# Mensagens R1 (Cadastro de Conta)
msg_cc_ok:          .asciiz "Cliente cadastrado com sucesso. Numero da conta "
msg_cc_cpf_exists:  .asciiz "Ja existe conta neste CPF\n"
msg_cc_acc_exists:  .asciiz "Numero da conta ja em uso\n"
msg_cc_full:        .asciiz "Falha: base de clientes cheia\n"
msg_cc_badfmt:      .asciiz "Falha: formato do comando invalido\n"
msg_cc_badcpf:      .asciiz "Falha: CPF invalido (11 digitos)\n"
msg_cc_badacc:      .asciiz "Falha: numero da conta invalido (6 digitos)\n"
msg_cc_badname:     .asciiz "Falha: nome vazio ou maior que 32\n"

# Mensagens R2 (Operações Financeiras)
msg_pay_deb_ok:          .asciiz "Pagamento em debito realizado com sucesso\n"
msg_pay_cred_ok:         .asciiz "Pagamento em credito realizado com sucesso\n"
msg_err_cli_inexist:     .asciiz "Falha: cliente inexistente\n"
msg_err_saldo_insuf:     .asciiz "Falha: saldo insuficiente\n"
msg_err_limite_insuf:    .asciiz "Falha: limite insuficiente\n"
msg_limite_ok:           .asciiz "Limite atualizado com sucesso\n"
msg_limite_baixo_divida: .asciiz "Falha: novo limite abaixo da divida atual\n"
msg_conta_invalida:      .asciiz "Falha: conta invalida\n"