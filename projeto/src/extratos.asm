# ============================================================
# extratos.asm - R5 (MARS 4.5)
# Responsável por exibir extratos detalhados de transações.
# Comandos suportados:
#   - credito_extrato-<CONTA6>-<DV>
#   - debito_extrato-<CONTA6>-<DV>
#
# Dependências:
#   - data.asm
#   - transacoes.asm (função formatar_centavos)
#   - ops_util.asm (função print_datahora)
# ============================================================

.data
str_cmd_extrato_debito:   .asciiz "debito_extrato-"
str_cmd_extrato_credito:  .asciiz "credito_extrato-"

# Cabeçalhos para exibição de extratos
msg_extrato_credito_hdr:  .asciiz "\n=== EXTRATO CREDITO ===\nData/Hora           Tipo        Valor (R$)\n------------------------------------------\n"
msg_extrato_debito_hdr:   .asciiz "\n=== EXTRATO DEBITO ===\nData/Hora           Tipo        Valor (R$)\n------------------------------------------\n"

# Mensagens auxiliares
msg_limite_disp:          .asciiz "Limite disponivel: "
msg_divida_atual:         .asciiz "Divida atual: "
msg_nl:                   .asciiz "\n"

# Rótulos de texto para formatação
lbl_sep_cols:             .asciiz "  "
lbl_tipo_deb:             .asciiz "DEB       "
lbl_tipo_cred:            .asciiz "CRED      "
lbl_sem_mov:              .asciiz "(sem movimentacoes)\n"

.text
.globl handle_extrato_credito
.globl handle_extrato_debito

# ------------------------------------------------------------
# extr_buscar_cliente_conta_dv
# Procura um cliente a partir do número da conta (6 dígitos) + DV.
# Entrada:
#   a0 = ponteiro para cc_buf_acc (conta)
#   a1 = DV (byte)
# Saída:
#   v0 = índice do cliente ou -1 se não encontrado
# ------------------------------------------------------------
extr_buscar_cliente_conta_dv:
    lw    $t9, MAX_CLIENTS
    li    $t0, 0                # contador de clientes
ebc_loop:
    beq   $t0, $t9, ebc_not_found

    # Verifica se o slot de cliente está em uso
    la    $t1, clientes_usado
    addu  $t1, $t1, $t0
    lb    $t2, 0($t1)
    beq   $t2, $zero, ebc_next

    # Pega a conta do cliente atual
    la    $t3, clientes_conta
    li    $t4, 7
    mul   $t4, $t0, $t4
    addu  $t3, $t3, $t4

    # Compara os 6 dígitos da conta
    move  $t5, $a0
    li    $t6, 0
ebc_cmp6:
    lb    $t7, 0($t3)
    lb    $t8, 0($t5)
    bne   $t7, $t8, ebc_next
    addiu $t3, $t3, 1
    addiu $t5, $t5, 1
    addiu $t6, $t6, 1
    blt   $t6, 6, ebc_cmp6

    # Verifica o DV
    la    $t3, clientes_dv
    addu  $t3, $t3, $t0
    lb    $t7, 0($t3)
    bne   $t7, $a1, ebc_next

    move  $v0, $t0              # índice do cliente encontrado
    jr    $ra
    nop
ebc_next:
    addiu $t0, $t0, 1
    j     ebc_loop
    nop
ebc_not_found:
    li    $v0, -1
    jr    $ra
    nop

# ------------------------------------------------------------
# extr_print_linha
# Imprime uma linha do extrato:
#   Data/Hora | Tipo | Valor
# Entrada:
#   a0 = tipo (0=DEB, 1=CRED)
#   a1 = valor em centavos
# ------------------------------------------------------------
extr_print_linha:
    addiu $sp, $sp, -32
    sw    $ra, 28($sp)
    sw    $s2, 16($sp)
    sw    $s3, 12($sp)

    move  $s2, $a0              # tipo
    move  $s3, $a1              # valor

    # Imprime data/hora atual
    jal   print_datahora

    # Separador
    li    $v0, 4
    la    $a0, lbl_sep_cols
    syscall

    # Tipo (CRED/DEB)
    beq   $s2, $zero, epl_deb
    li    $v0, 4
    la    $a0, lbl_tipo_cred
    syscall
    j     epl_tipo_ok
epl_deb:
    li    $v0, 4
    la    $a0, lbl_tipo_deb
    syscall
epl_tipo_ok:

    # Outro separador
    li    $v0, 4
    la    $a0, lbl_sep_cols
    syscall

    # Valor formatado em reais
    move  $a0, $s3
    jal   formatar_centavos
    move  $a0, $v0
    li    $v0, 4
    syscall

    # Nova linha
    li    $v0, 4
    la    $a0, msg_nl
    syscall

    # Restaura pilha
    lw    $ra, 28($sp)
    lw    $s2, 16($sp)
    lw    $s3, 12($sp)
    addiu $sp, $sp, 32
    jr    $ra
    nop

# ------------------------------------------------------------
# extr_print_credito_do_cliente
# Lista todas as transações de crédito de um cliente.
# Entrada:
#   a0 = índice do cliente
# ------------------------------------------------------------
extr_print_credito_do_cliente:
    addiu $sp, $sp, -40
    sw    $ra, 36($sp)
    sw    $s0, 32($sp)

    move  $s0, $a0

    # Obtém o número de transações e o índice da cabeça
    sll   $t0, $s0, 2
    la    $t1, trans_cred_count
    addu  $t1, $t1, $t0
    lw    $s1, 0($t1)           # count

    la    $t2, trans_cred_head
    addu  $t2, $t2, $t0
    lw    $s2, 0($t2)           # head (posição atual)
    lw    $s3, TRANS_MAX        # capacidade total

    # Se não houver movimentos
    beqz  $s1, c_sem_mov

    # Ajuste de limites circulares
    divu  $s2, $s3
    mfhi  $s2

    # Calcula início real (ordem mais antiga)
    subu  $s4, $s2, $s1
    slt   $t4, $s4, $zero
    beq   $t4, $zero, c_start_ok
    addu  $s4, $s4, $s3
c_start_ok:

    move  $s5, $zero            # contador de loop
c_loop:
    beq   $s5, $s1, c_fim

    # Índice circular
    addu  $t0, $s4, $s5
    sltu  $t1, $t0, $s3
    bne   $t1, $zero, c_idx_ok
    subu  $t0, $t0, $s3
c_idx_ok:

    # Cálculo do índice linear: cliente*CAP + idx
    mul   $t2, $s0, $s3
    addu  $t2, $t2, $t0
    sll   $t3, $t2, 2

    la    $t4, trans_cred_vals
    addu  $t4, $t4, $t3
    lw    $t5, 0($t4)           # valor da transação

    li    $a0, 1                # tipo crédito
    move  $a1, $t5
    jal   extr_print_linha

    addiu $s5, $s5, 1
    j     c_loop

c_sem_mov:
    li    $v0, 4
    la    $a0, lbl_sem_mov
    syscall

c_fim:
    lw    $ra, 36($sp)
    lw    $s0, 32($sp)
    addiu $sp, $sp, 40
    jr    $ra
    nop

# ------------------------------------------------------------
# extr_print_debito_do_cliente
# Lista todas as transações de débito do cliente.
# Entrada:
#   a0 = índice do cliente
# ------------------------------------------------------------
extr_print_debito_do_cliente:
    addiu $sp, $sp, -40
    sw    $ra, 36($sp)
    sw    $s0, 32($sp)

    move  $s0, $a0

    sll   $t0, $s0, 2
    la    $t1, trans_deb_count
    addu  $t1, $t1, $t0
    lw    $s1, 0($t1)           # número de transações

    la    $t2, trans_deb_head
    addu  $t2, $t2, $t0
    lw    $s2, 0($t2)           # posição atual
    lw    $s3, TRANS_MAX

    beqz  $s1, d_sem_mov
    divu  $s2, $s3
    mfhi  $s2

    subu  $s4, $s2, $s1
    slt   $t4, $s4, $zero
    beq   $t4, $zero, d_start_ok
    addu  $s4, $s4, $s3
d_start_ok:

    move  $s5, $zero
d_loop:
    beq   $s5, $s1, d_fim

    addu  $t0, $s4, $s5
    sltu  $t1, $t0, $s3
    bne   $t1, $zero, d_idx_ok
    subu  $t0, $t0, $s3
d_idx_ok:
    mul   $t2, $s0, $s3
    addu  $t2, $t2, $t0
    sll   $t3, $t2, 2

    la    $t4, trans_deb_vals
    addu  $t4, $t4, $t3
    lw    $t5, 0($t4)           # valor

    move  $a0, $zero            # tipo = débito
    move  $a1, $t5
    jal   extr_print_linha

    addiu $s5, $s5, 1
    j     d_loop

d_sem_mov:
    li    $v0, 4
    la    $a0, lbl_sem_mov
    syscall

d_fim:
    lw    $ra, 36($sp)
    lw    $s0, 32($sp)
    addiu $sp, $sp, 40
    jr    $ra
    nop

# ------------------------------------------------------------
# handle_extrato_credito
# Processa o comando: credito_extrato-<CONTA6>-<DV>
# ------------------------------------------------------------
handle_extrato_credito:
    addiu $sp, $sp, -24
    sw    $ra, 20($sp)
    sw    $s0, 16($sp)
    sw    $s1, 12($sp)

    # Verifica prefixo do comando
    move  $t0, $a0
    la    $t1, str_cmd_extrato_credito
hec_pref:
    lb    $t2, 0($t1)
    beq   $t2, $zero, hec_pref_ok
    lb    $t3, 0($t0)
    bne   $t2, $t3, hec_not_mine
    addiu $t1, $t1, 1
    addiu $t0, $t0, 1
    j     hec_pref

# Extrai conta e DV
hec_pref_ok:
    la    $t4, cc_buf_acc
    li    $t5, 0
hec_conta:
    lb    $t6, 0($t0)
    blt   $t6, 48, hec_badfmt
    bgt   $t6, 57, hec_badfmt
    sb    $t6, 0($t4)
    addiu $t4, $t4, 1
    addiu $t0, $t0, 1
    addiu $t5, $t5, 1
    blt   $t5, 6, hec_conta
    sb    $zero, 0($t4)

    # Verifica separador '-'
    lb    $t6, 0($t0)
    li    $t7, 45
    bne   $t6, $t7, hec_badfmt
    addiu $t0, $t0, 1

    lb    $s1, 0($t0)           # DV

    # Busca cliente
    la    $a0, cc_buf_acc
    move  $a1, $s1
    jal   extr_buscar_cliente_conta_dv
    move  $s0, $v0
    bltz  $s0, hec_cli_inexist

    # Cabeçalho
    li    $v0, 4
    la    $a0, msg_extrato_credito_hdr
    syscall

    # Calcula limite e dívida
    sll   $t0, $s0, 2
    la    $t1, clientes_limite_cent
    addu  $t1, $t1, $t0
    lw    $t2, 0($t1)
    la    $t3, clientes_devido_cent
    addu  $t3, $t3, $t0
    lw    $t4, 0($t3)

    # Corrige valores negativos
    bltz  $t2, hec_lim_zero
    li    $t6, 100
    divu  $t2, $t6
    mflo  $t7
    mul   $t2, $t7, 100
    j     hec_lim_ok
hec_lim_zero:
    move  $t2, $zero
hec_lim_ok:
    bltz  $t4, hec_dev_zero
    li    $t6, 100
    divu  $t4, $t6
    mflo  $t7
    mul   $t4, $t7, 100
    j     hec_dev_ok
hec_dev_zero:
    move  $t4, $zero
hec_dev_ok:

    move  $s2, $t4               # dívida

    # disponivel = limite - devido
    subu  $t5, $t2, $t4
    slt   $t6, $t5, $zero
    beq   $t6, $zero, hec_disp_ok
    move  $t5, $zero
hec_disp_ok:

    # Mostra limite disponível
    li    $v0, 4
    la    $a0, msg_limite_disp
    syscall
    move  $a0, $t5
    jal   formatar_centavos
    move  $a0, $v0
    li    $v0, 4
    syscall
    li    $v0, 4
    la    $a0, msg_nl
    syscall

    # Mostra dívida atual
    li    $v0, 4
    la    $a0, msg_divida_atual
    syscall
    move  $a0, $s2
    jal   formatar_centavos
    move  $a0, $v0
    li    $v0, 4
    syscall
    li    $v0, 4
    la    $a0, msg_nl
    syscall

    # Lista as transações de crédito
    move  $a0, $s0
    jal   extr_print_credito_do_cliente

    li    $v0, 1
    j     hec_end

hec_cli_inexist:
    li    $v0, 4
    la    $a0, msg_err_cli_inexist
    syscall
    li    $v0, 1
    j     hec_end

hec_badfmt:
    li    $v0, 4
    la    $a0, msg_cc_badfmt
    syscall
    li    $v0, 1
    j     hec_end

hec_not_mine:
    move  $v0, $zero

hec_end:
    lw    $ra, 20($sp)
    addiu $sp, $sp, 24
    jr    $ra
    nop
# ------------------------------------------------------------
# handle_extrato_debito
# Processa o comando: debito_extrato-<CONTA6>-<DV>
# Mostra o extrato das transações de débito de um cliente.
# Entrada:
#   a0 = ponteiro para o buffer de entrada (inp_buf)
# Saída:
#   v0 = 1 se comando foi processado, 0 se não era o comando
# Usa: extr_buscar_cliente_conta_dv e extr_print_debito_do_cliente
# ------------------------------------------------------------
handle_extrato_debito:
    addiu $sp, $sp, -24           # abre espaço na pilha
    sw    $ra, 20($sp)            # salva endereço de retorno
    sw    $s0, 16($sp)            # preserva registradores
    sw    $s1, 12($sp)
    sw    $s2,  8($sp)

    # --------------------------------------------------------
    # Verifica se o comando recebido começa com "debito_extrato-"
    # --------------------------------------------------------
    move  $t0, $a0
    la    $t1, str_cmd_extrato_debito
hedb_pref:
    lb    $t2, 0($t1)
    beq   $t2, $zero, hedb_ok     # chegou ao fim da string padrão
    lb    $t3, 0($t0)
    bne   $t2, $t3, hedb_not_mine # se caractere diferente, não é esse comando
    addiu $t1, $t1, 1             # avança nas duas strings
    addiu $t0, $t0, 1
    j     hedb_pref
    nop

# ------------------------------------------------------------
# Leitura da conta e DV
# ------------------------------------------------------------
hedb_ok:
    la    $t4, cc_buf_acc         # buffer temporário p/ conta (6 dígitos)
    li    $t5, 0
hedb_conta:
    lb    $t6, 0($t0)             # lê caractere
    blt   $t6, 48, hedb_badfmt    # '0' = 48 -> caractere inválido
    bgt   $t6, 57, hedb_badfmt    # '9' = 57 -> caractere inválido
    sb    $t6, 0($t4)             # salva dígito no buffer
    addiu $t4, $t4, 1
    addiu $t0, $t0, 1
    addiu $t5, $t5, 1
    blt   $t5, 6, hedb_conta      # repete até ler 6 dígitos
    sb    $zero, 0($t4)           # termina string com '\0'

    # Verifica o separador '-' antes do DV
    lb    $t6, 0($t0)
    li    $t7, 45                 # caractere '-'
    bne   $t6, $t7, hedb_badfmt
    addiu $t0, $t0, 1             # avança para o DV

    # Lê DV (1 caractere)
    lb    $s1, 0($t0)

    # --------------------------------------------------------
    # Exibe cabeçalho do extrato de débito
    # --------------------------------------------------------
    li    $v0, 4
    la    $a0, msg_extrato_debito_hdr
    syscall

    # --------------------------------------------------------
    # Procura o cliente com base em conta e DV
    # --------------------------------------------------------
    la    $a0, cc_buf_acc
    move  $a1, $s1
    jal   extr_buscar_cliente_conta_dv
    nop
    move  $s0, $v0
    bltz  $s0, hedb_cli_inexist   # se -1, cliente não existe

    # --------------------------------------------------------
    # Exibe todas as transações de débito do cliente
    # --------------------------------------------------------
    move  $a0, $s0
    jal   extr_print_debito_do_cliente
    nop

    li    $v0, 1                  # sucesso
    j     hedb_end
    nop

# ------------------------------------------------------------
# Caso: cliente não encontrado
# ------------------------------------------------------------
hedb_cli_inexist:
    li    $v0, 4
    la    $a0, msg_err_cli_inexist
    syscall
    li    $v0, 1
    j     hedb_end
    nop

# ------------------------------------------------------------
# Caso: formato inválido (conta ou DV malformado)
# ------------------------------------------------------------
hedb_badfmt:
    li    $v0, 4
    la    $a0, msg_cc_badfmt
    syscall
    li    $v0, 1
    j     hedb_end
    nop

# ------------------------------------------------------------
# Caso: comando não corresponde a este handler
# ------------------------------------------------------------
hedb_not_mine:
    move  $v0, $zero              # retorna 0 -> não era esse comando

# ------------------------------------------------------------
# Finalização e restauração de registradores
# ------------------------------------------------------------
hedb_end:
    lw    $s2,  8($sp)
    lw    $s1, 12($sp)
    lw    $s0, 16($sp)
    lw    $ra, 20($sp)
    addiu $sp, $sp, 24
    jr    $ra
    nop


