# ==========================================================
# data.asm — Dados globais e constantes do projeto (R1..R4)
# ==========================================================
# Arquivo central que define todas as variáveis e constantes
# usadas pelo sistema bancário "opcode-shell". 
# Inclui buffers, mensagens, estruturas de clientes, 
# transações e controle de tempo/juros.
# ==========================================================

        .data

# ----------------------------------------------------------
# Exportações globais (para uso em outros arquivos .asm)
# ----------------------------------------------------------
# IMPORTANTE: não declarar .globl desses símbolos em outros
# arquivos, pois eles são definidos aqui como referência global.
        .globl  MAX_CLIENTS, NAME_MAX, CPF_STR_LEN, ACC_NUM_LEN, ACC_DV_LEN
        .globl  LIMITE_PADRAO_CENT, TRANS_MAX
        .globl  inp_buf, bank_name, banner, help_txt, msg_invalid, msg_bye
        .globl  str_help, str_exit
        .globl  clientes_usado, clientes_cpf, clientes_conta, clientes_dv, clientes_nome
        .globl  clientes_saldo_cent, clientes_limite_cent, clientes_devido_cent
        .globl  str_cmd_cc_prefix, str_cmd_pay_debito, str_cmd_pay_credito
        .globl  str_cmd_alt_limite, str_cmd_pay_fatura
        .globl  msg_cc_ok, msg_cc_cpf_exists, msg_cc_acc_exists, msg_cc_full
        .globl  msg_cc_badfmt, msg_cc_badcpf, msg_cc_badacc, msg_cc_badname
        .globl  msg_pay_deb_ok, msg_pay_cred_ok, msg_err_saldo_insuf, msg_err_limite_insuf
        .globl  msg_err_cli_inexist, msg_limite_ok, msg_limite_baixo_divida
        # R3 – Transações
        .globl  trans_deb_vals, trans_cred_vals
        .globl  trans_deb_head, trans_deb_count, trans_deb_wptr
        .globl  trans_cred_head, trans_cred_count, trans_cred_wptr
        # Comandos de dump
        .globl  str_cmd_dumpcred, str_cmd_dumpdeb
        # Buffers temporários
        .globl  cc_buf_cpf, cc_buf_acc, cc_buf_nome, cc_buf_dv
        # R4 – Data/Hora
        .globl  curr_day, curr_mon, curr_year, curr_hour, curr_min, curr_sec
        .globl  ms_last, ms_accum, month_days_norm
        .globl  str_cmd_time_set, str_cmd_time_show
        .globl  msg_time_set_ok, msg_time_badfmt, msg_time_range
        # Buffer auxiliar de formatação e comandos extras
        .globl  buffer_valor_formatado
        .globl  str_cmd_sacar, str_cmd_depositar

# ----------------------------------------------------------
# Constantes globais do sistema
# ----------------------------------------------------------
MAX_CLIENTS:        .word 50        # Máximo de 50 clientes
NAME_MAX:           .word 32        # Nome com até 32 caracteres
CPF_STR_LEN:        .word 11        # CPF tem 11 dígitos
ACC_NUM_LEN:        .word 6         # Número da conta: 6 dígitos
ACC_DV_LEN:         .word 1         # Dígito verificador (DV)
LIMITE_PADRAO_CENT: .word 150000    # Limite padrão R$ 1.500,00 (em centavos)
TRANS_MAX:          .word 50        # Máximo de 50 transações por cliente

# ----------------------------------------------------------
# Buffers gerais para entrada e formatação
# ----------------------------------------------------------
inp_buf:                    .space 256   # Buffer de entrada do shell
buffer_valor_formatado:     .space 32    # Buffer para valores formatados "R$ 1.234,56"
cc_buf_dv:                  .space 1     # Armazena DV temporário

# ----------------------------------------------------------
# Banner e texto de ajuda
# ----------------------------------------------------------
bank_name:  .asciiz "opcode"                  # Nome do banco
banner:     .asciiz "opcode-shell>> "        # Prompt do shell

help_txt:                                   # Texto de ajuda (comandos)
    .ascii "Comandos disponiveis:\n"
    .ascii "  help                    - mostra esta ajuda\n"
    .ascii "  exit                    - encerra o programa\n"
    .ascii "\n"
    .ascii "  conta_cadastrar-<CPF11>-<CONTA6>-<NOME>\n"
    .ascii "  conta_fechar-<CONTA6>-<DV>\n"
    .ascii "\n"
    .ascii "  depositar-<CONTA6>-<DV>-<VALORcent>\n"
    .ascii "  sacar-<CONTA6>-<DV>-<VALORcent>\n"
    .ascii "  pagar_debito-<CONTA6>-<DV>-<VALORcent>\n"
    .ascii "  pagar_credito-<CONTA6>-<DV>-<VALORcent>\n"
    .ascii "  pagar_fatura-<CONTA6>-<DV>-<VALORcent>\n"
    .ascii "  alterar_limite-<CONTA6>-<DV>-<NOVOLIMcent>\n"
    .ascii "\n"
    .ascii "  dump_trans-cred-<CONTA6>-<DV>\n"
    .ascii "  dump_trans-deb-<CONTA6>-<DV>\n"
    .ascii "  credito_extrato-<CONTA6>-<DV>\n"
    .ascii "  debito_extrato-<CONTA6>-<DV>\n"
    .ascii "\n"
    .ascii "  datetime_show\n"
    .ascii "  datetime_set-<DD>/<MM>/<AAAA>- <HH>:<MM>:<SS>\n"
    .ascii "\n"
    .ascii "  salvar, recarregar, formatar\n"
    .byte 0

msg_invalid: .asciiz "Comando invalido\n"       # Feedback de comando inválido
msg_bye:     .asciiz "Encerrando...\n"         # Mensagem de saída

# ----------------------------------------------------------
# Strings básicas para comparação de entrada
# ----------------------------------------------------------
str_help:   .asciiz "help"
str_exit:   .asciiz "exit"

# ----------------------------------------------------------
# Prefixos de comandos (para identificação)
# ----------------------------------------------------------
str_cmd_cc_prefix:     .asciiz "conta_cadastrar-"
str_cmd_pay_debito:    .asciiz "pagar_debito-"
str_cmd_pay_credito:   .asciiz "pagar_credito-"
str_cmd_alt_limite:    .asciiz "alterar_limite-"
str_cmd_pay_fatura:    .asciiz "pagar_fatura-"
str_cmd_sacar:         .asciiz "sacar-"
str_cmd_depositar:     .asciiz "depositar-"

# Comandos de persistência
str_salvar:     .asciiz "salvar"
str_recarregar: .asciiz "recarregar"
str_formatar:   .asciiz "formatar"

# ----------------------------------------------------------
# Mensagens de sistema (feedbacks gerais)
# ----------------------------------------------------------
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
msg_err_valor_maior:    .asciiz "Falha: valor fornecido maior que a divida do cartao\n"
msg_pago_com_sucesso:   .asciiz "Pagamento realizado com sucesso!\n"

msg_saque_ok:           .asciiz "Saque realizado\n"
msg_dep_ok:             .asciiz "Deposito realizado\n"

msg_err_saldo_devedor:   .asciiz "Falha: saldo devedor ainda nao quitado. Saldo da conta corrente: R$ "
msg_err_limite_devido:   .asciiz "Falha: limite de credito devido. Limite de credito: R$ "
msg_err_cpf_nao_cadastrado: .asciiz "Falha: CPF nao possui cadastro.\n"
msg_sucesso_conta_fechada:  .asciiz "Conta fechada com sucesso!\n"

# Mensagens de persistência
msg_salvo_ok:   .asciiz "Dados salvos.\n"
msg_salvo_fail: .asciiz "Falha ao salvar.\n"
msg_load_ok:    .asciiz "Dados recarregados do arquivo.\n"
msg_load_fail:  .asciiz "Nao foi possivel recarregar (arquivo ausente ou erro).\n"
msg_fmt_ok:     .asciiz "Estado limpo (clientes e transacoes apagados).\n"

# ----------------------------------------------------------
# Estruturas de dados dos clientes
# ----------------------------------------------------------
# Cada cliente possui CPF, conta, DV, nome e saldos
clientes_usado:        .space 50        # Flag se cliente está ativo (0/1)
clientes_cpf:          .space 600       # 50 clientes * 12 bytes (11 + '\0')
clientes_conta:        .space 350       # 50 clientes * 7 bytes (6 + '\0')
clientes_dv:           .space 50        # DV por cliente
clientes_nome:         .space 1650      # 50 clientes * 33 bytes (32 + '\0')

        .align 2
clientes_saldo_cent:   .word 0:50       # Saldo em centavos por cliente
        .align 2
clientes_limite_cent:  .word 0:50       # Limite de crédito
        .align 2
clientes_devido_cent:  .word 0:50       # Dívida de crédito

# ----------------------------------------------------------
# R3 – Buffers de transações (por cliente)
# ----------------------------------------------------------
# Cada cliente pode ter até 50 transações de débito e crédito
        .align 2
trans_deb_head:    .word 0:50
        .align 2
trans_deb_count:   .word 0:50
        .align 2
trans_deb_wptr:    .word 0:50

        .align 2
trans_cred_head:   .word 0:50
        .align 2
trans_cred_count:  .word 0:50
        .align 2
trans_cred_wptr:   .word 0:50

# Valores das transações (em centavos)
        .align 2
trans_deb_vals:    .word 0:2500
        .align 2
trans_cred_vals:   .word 0:2500

# Prefixos de comandos de dump
str_cmd_dumpcred:  .asciiz "dump_trans-cred-"
str_cmd_dumpdeb:   .asciiz "dump_trans-deb-"

# Buffers auxiliares temporários
cc_buf_cpf:   .space 12   
cc_buf_acc:   .space 7    
cc_buf_nome:  .space 33   

# ----------------------------------------------------------
# R4 – Controle de Data e Hora
# ----------------------------------------------------------
# Variáveis que armazenam a data e hora atuais do sistema
        .align 2
curr_day:   .word 1       # Dia atual (1-31)
curr_mon:   .word 1       # Mês atual (1-12)
curr_year:  .word 2025    # Ano atual
curr_hour:  .word 0       # Hora atual (0-23)
curr_min:   .word 0       # Minuto atual (0-59)
curr_sec:   .word 0       # Segundo atual (0-59)

        .align 2
ms_last:    .word 0       # Último milissegundo registrado
ms_accum:   .word 0       # Acumulador de milissegundos (para cálculos internos)

month_days_norm:
        .word 31,28,31,30,31,30,31,31,30,31,30,31  # Dias de cada mês em ano não bissexto

# Strings de comando relacionadas à data/hora
str_cmd_time_set:  .asciiz "datetime_set-"   # Comando para setar data/hora
str_cmd_time_show: .asciiz "datetime_show"   # Comando para exibir data/hora

# Mensagens de feedback para o usuário
msg_time_set_ok:   .asciiz "Data/hora configurada\n"
msg_time_badfmt:   .asciiz "Formato invalido (use DD/MM/AAAA- HH:MM:SS)\n"
msg_time_range:    .asciiz "Valores fora de faixa\n"

# ----------------------------------------------------------
# R7 – Controle de Juros Automáticos
# ----------------------------------------------------------
# Juros de 1% aplicados automaticamente a cada 60 segundos.
# Usa um "gate" para evitar reentradas simultâneas
# e mantém um contador absoluto de segundos do sistema.

        .data
        .align 2

        .globl JUROS_PERIOD_SEC, JUROS_RATE_NUM, JUROS_RATE_DEN
JUROS_PERIOD_SEC:   .word 60       # Intervalo de aplicação de juros (segundos)
JUROS_RATE_NUM:     .word 1        # Numerador da taxa de juros (1%)
JUROS_RATE_DEN:     .word 100      # Denominador da taxa de juros (100 -> 1/100 = 1%)

        .globl curr_abssec
curr_abssec:        .word 0        # Contador absoluto de segundos desde o início do sistema

        .globl juros_last_abssec
juros_last_abssec:  .word 0        # Momento em que os juros foram aplicados pela última vez

        .globl juros_gate
juros_gate:         .word 0        # Controle de reentradas: 0 = livre / 1 = travado

        .globl JUROS_USA_VALOR_NEG
JUROS_USA_VALOR_NEG:.word 1        # Define que juros serão registrados como valor negativo




