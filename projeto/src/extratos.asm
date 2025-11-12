# ============================================================
# extratos.asm - R5 com detalhes de transações (MARS 4.5)
# comandos:  credito_extrato-<CONTA6>-<DV>
#            debito_extrato-<CONTA6>-<DV>
#
# Depende de:
#  - data.asm (símbolos globais abaixo)
#  - transacoes.asm: formatar_centavos(a0=centavos) -> v0=ptr string
#  - ops_util.asm: print_2dig / print_datahora (usa curr_* abaixo)
# ============================================================

.data
str_cmd_extrato_debito:   .asciiz "debito_extrato-"
str_cmd_extrato_credito:  .asciiz "credito_extrato-"

msg_extrato_credito_hdr:  .asciiz "\n=== EXTRATO CREDITO ===\nData/Hora           Tipo        Valor (R$)\n------------------------------------------\n"
msg_extrato_debito_hdr:   .asciiz "\n=== EXTRATO DEBITO ===\nData/Hora           Tipo        Valor (R$)\n------------------------------------------\n"

msg_limite_disp:          .asciiz "Limite disponivel: R$ "
msg_divida_atual:         .asciiz "Divida atual: R$ "
msg_nl:                   .asciiz "\n"

lbl_sep_cols:             .asciiz "  "
lbl_tipo_deb:             .asciiz "DEB       "
lbl_tipo_cred:            .asciiz "CRED      "
lbl_sem_mov:              .asciiz "(sem movimentacoes)\n"

.text
.globl handle_extrato_credito
.globl handle_extrato_debito

# Globais vindos de data.asm:
# MAX_CLIENTS, TRANS_MAX
# clientes_usado, clientes_conta, clientes_dv
# clientes_limite_cent, clientes_devido_cent
# trans_deb_head, trans_deb_count, trans_deb_wptr, trans_deb_vals
# trans_cred_head, trans_cred_count, trans_cred_wptr, trans_cred_vals
# curr_day, curr_mon, curr_year, curr_hour, curr_min, curr_sec
# cc_buf_acc, msg_err_cli_inexist, msg_cc_badfmt
# formatar_centavos (em transacoes.asm)

# ------------------------------------------------------------
# helper: procura cliente por conta(6) (em cc_buf_acc) + DV
# a0 = &cc_buf_acc
# a1 = dv (byte)
# v0 = indice ou -1
# ------------------------------------------------------------
extr_buscar_cliente_conta_dv:
    lw    $t9, MAX_CLIENTS
    li    $t0, 0
ebc_loop:
    beq   $t0, $t9, ebc_not_found

    la    $t1, clientes_usado
    addu  $t1, $t1, $t0
    lb    $t2, 0($t1)
    beq   $t2, $zero, ebc_next

    la    $t3, clientes_conta
    li    $t4, 7
    mul   $t4, $t0, $t4
    addu  $t3, $t3, $t4
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

    la    $t3, clientes_dv
    addu  $t3, $t3, $t0
    lb    $t7, 0($t3)
    bne   $t7, $a1, ebc_next

    move  $v0, $t0
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
# imprime uma linha (Data/Hora atual, Tipo, Valor)
# in: a0=tipoFlag (0=DEB, 1=CRED), a1=valor_centavos
# ------------------------------------------------------------
extr_print_linha:
    addiu $sp, $sp, -24
    sw    $ra, 20($sp)
    sw    $s0, 16($sp)
    sw    $s1, 12($sp)

    # Data/Hora atual dos globais
    lw    $a0, curr_day
    lw    $a1, curr_mon
    lw    $a2, curr_year
    lw    $a3, curr_hour
    lw    $s0, curr_min
    lw    $s1, curr_sec
    jal   print_datahora
    nop

    # separador
    li    $v0, 4
    la    $a0, lbl_sep_cols
    syscall

    # Tipo
    beq   $a0, $zero, .p_deb
    nop
    li    $v0, 4
    la    $a0, lbl_tipo_cred
    syscall
    j     .p_tipo_ok
    nop
.p_deb:
    li    $v0, 4
    la    $a0, lbl_tipo_deb
    syscall
.p_tipo_ok:

    # separador
    li    $v0, 4
    la    $a0, lbl_sep_cols
    syscall

    # Valor
    move  $a0, $a1
    jal   formatar_centavos
    nop
    move  $a0, $v0
    li    $v0, 4
    syscall

    # newline
    li    $v0, 4
    la    $a0, msg_nl
    syscall

    lw    $s1, 12($sp)
    lw    $s0, 16($sp)
    lw    $ra, 20($sp)
    addiu $sp, $sp, 24
    jr    $ra
    nop

# ------------------------------------------------------------
# extr_print_credito_do_cliente(a0 = idxCliente)
# ------------------------------------------------------------
extr_print_credito_do_cliente:
    addiu $sp, $sp, -24
    sw    $ra, 20($sp)
    sw    $s0, 16($sp)
    sw    $s1, 12($sp)
    sw    $s2,  8($sp)

    move  $s0, $a0

    # count / head
    sll   $t0, $s0, 2
    la    $t1, trans_cred_count
    addu  $t1, $t1, $t0
    lw    $s1, 0($t1)                    # count (pode vir sujo)

    la    $t2, trans_cred_head
    addu  $t2, $t2, $t0
    lw    $s2, 0($t2)                    # head

    # ---------- SANITIZAÇÃO ----------
    bltz  $s1, .cred_sem_mov             # count < 0 => nada
    lw    $t9, TRANS_MAX                 # CAP
    sltu  $t3, $t9, $s1                  # 1 se count > CAP
    beq   $t3, $zero, .cred_count_ok
    nop
    move  $s1, $t9                        # count = CAP se maior
.cred_count_ok:
    # head %= CAP
    div   $s2, $t9
    mfhi  $s2
    beq   $s1, $zero, .cred_sem_mov
    nop
    # ----------------------------------

    li    $t7, 0
.cred_loop:
    beq   $t7, $s1, .cred_fim
    nop

    # idx = (head + i) % CAP
    addu  $t0, $s2, $t7
    div   $t0, $t9
    mfhi  $t0

    # linear = idxCliente*CAP + idx
    mul   $t2, $s0, $t9
    addu  $t2, $t2, $t0

    # byte offset = linear * 4
    sll   $t3, $t2, 2

    la    $t4, trans_cred_vals
    addu  $t4, $t4, $t3
    lw    $t5, 0($t4)                     # valor

    li    $a0, 1
    move  $a1, $t5
    jal   extr_print_linha
    nop

    addiu $t7, $t7, 1
    j     .cred_loop
    nop

.cred_sem_mov:
    li    $v0, 4
    la    $a0, lbl_sem_mov
    syscall

.cred_fim:
    lw    $s2,  8($sp)
    lw    $s1, 12($sp)
    lw    $s0, 16($sp)
    lw    $ra, 20($sp)
    addiu $sp, $sp, 24
    jr    $ra
    nop

# ------------------------------------------------------------
# extr_print_debito_do_cliente(a0 = idxCliente)
# ------------------------------------------------------------
extr_print_debito_do_cliente:
    addiu $sp, $sp, -24
    sw    $ra, 20($sp)
    sw    $s0, 16($sp)
    sw    $s1, 12($sp)
    sw    $s2,  8($sp)

    move  $s0, $a0

    sll   $t0, $s0, 2
    la    $t1, trans_deb_count
    addu  $t1, $t1, $t0
    lw    $s1, 0($t1)                    # count

    la    $t2, trans_deb_head
    addu  $t2, $t2, $t0
    lw    $s2, 0($t2)                    # head

    # ---------- SANITIZAÇÃO ----------
    bltz  $s1, .deb_sem_mov
    lw    $t9, TRANS_MAX
    sltu  $t3, $t9, $s1
    beq   $t3, $zero, .deb_count_ok
    nop
    move  $s1, $t9
.deb_count_ok:
    div   $s2, $t9
    mfhi  $s2
    beq   $s1, $zero, .deb_sem_mov
    nop
    # ----------------------------------

    li    $t7, 0
.deb_loop:
    beq   $t7, $s1, .deb_fim
    nop

    addu  $t0, $s2, $t7
    div   $t0, $t9
    mfhi  $t0                             # idx

    mul   $t2, $s0, $t9
    addu  $t2, $t2, $t0
    sll   $t3, $t2, 2

    la    $t4, trans_deb_vals
    addu  $t4, $t4, $t3
    lw    $t5, 0($t4)

    move  $a0, $zero
    move  $a1, $t5
    jal   extr_print_linha
    nop

    addiu $t7, $t7, 1
    j     .deb_loop
    nop

.deb_sem_mov:
    li    $v0, 4
    la    $a0, lbl_sem_mov
    syscall

.deb_fim:
    lw    $s2,  8($sp)
    lw    $s1, 12($sp)
    lw    $s0, 16($sp)
    lw    $ra, 20($sp)
    addiu $sp, $sp, 24
    jr    $ra
    nop

# ------------------------------------------------------------
# handle_extrato_credito(a0 = inp_buf)
# ------------------------------------------------------------
handle_extrato_credito:
    addiu $sp, $sp, -24
    sw    $ra, 20($sp)
    sw    $s0, 16($sp)
    sw    $s1, 12($sp)
    sw    $s2,  8($sp)

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
    nop

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

    lb    $t6, 0($t0)
    li    $t7, 45
    bne   $t6, $t7, hec_badfmt
    addiu $t0, $t0, 1

    lb    $s1, 0($t0)

    la    $a0, cc_buf_acc
    move  $a1, $s1
    jal   extr_buscar_cliente_conta_dv
    nop
    move  $s0, $v0
    bltz  $s0, hec_cli_inexist

    li    $v0, 4
    la    $a0, msg_extrato_credito_hdr
    syscall

    sll   $t0, $s0, 2
    la    $t1, clientes_limite_cent
    addu  $t1, $t1, $t0
    lw    $t2, 0($t1)            # limite

    la    $t3, clientes_devido_cent
    addu  $t3, $t3, $t0
    lw    $t4, 0($t3)            # devido

    subu  $t5, $t2, $t4          # disponivel

    li    $v0, 4
    la    $a0, msg_limite_disp
    syscall
    move  $a0, $t5
    jal   formatar_centavos
    nop
    move  $a0, $v0
    li    $v0, 4
    syscall
    li    $v0, 4
    la    $a0, msg_nl
    syscall

    li    $v0, 4
    la    $a0, msg_divida_atual
    syscall
    move  $a0, $t4
    jal   formatar_centavos
    nop
    move  $a0, $v0
    li    $v0, 4
    syscall
    li    $v0, 4
    la    $a0, msg_nl
    syscall

    move  $a0, $s0
    jal   extr_print_credito_do_cliente
    nop

    li    $v0, 1
    j     hec_end
    nop

hec_cli_inexist:
    li    $v0, 4
    la    $a0, msg_err_cli_inexist
    syscall
    li    $v0, 1
    j     hec_end
    nop

hec_badfmt:
    li    $v0, 4
    la    $a0, msg_cc_badfmt
    syscall
    li    $v0, 1
    j     hec_end
    nop

hec_not_mine:
    move  $v0, $zero

hec_end:
    lw    $s2,  8($sp)
    lw    $s1, 12($sp)
    lw    $s0, 16($sp)
    lw    $ra, 20($sp)
    addiu $sp, $sp, 24
    jr    $ra
    nop

# ------------------------------------------------------------
# handle_extrato_debito(a0 = inp_buf)
# ------------------------------------------------------------
handle_extrato_debito:
    addiu $sp, $sp, -24
    sw    $ra, 20($sp)
    sw    $s0, 16($sp)
    sw    $s1, 12($sp)
    sw    $s2,  8($sp)

    move  $t0, $a0
    la    $t1, str_cmd_extrato_debito
hedb_pref:
    lb    $t2, 0($t1)
    beq   $t2, $zero, hedb_ok
    lb    $t3, 0($t0)
    bne   $t2, $t3, hedb_not_mine
    addiu $t1, $t1, 1
    addiu $t0, $t0, 1
    j     hedb_pref
    nop

hedb_ok:
    la    $t4, cc_buf_acc
    li    $t5, 0
hedb_conta:
    lb    $t6, 0($t0)
    blt   $t6, 48, hedb_badfmt
    bgt   $t6, 57, hedb_badfmt
    sb    $t6, 0($t4)
    addiu $t4, $t4, 1
    addiu $t0, $t0, 1
    addiu $t5, $t5, 1
    blt   $t5, 6, hedb_conta
    sb    $zero, 0($t4)

    lb    $t6, 0($t0)
    li    $t7, 45
    bne   $t6, $t7, hedb_badfmt
    addiu $t0, $t0, 1

    lb    $s1, 0($t0)

    li    $v0, 4
    la    $a0, msg_extrato_debito_hdr
    syscall

    la    $a0, cc_buf_acc
    move  $a1, $s1
    jal   extr_buscar_cliente_conta_dv
    nop
    move  $s0, $v0
    bltz  $s0, hedb_cli_inexist

    move  $a0, $s0
    jal   extr_print_debito_do_cliente
    nop

    li    $v0, 1
    j     hedb_end
    nop

hedb_cli_inexist:
    li    $v0, 4
    la    $a0, msg_err_cli_inexist
    syscall
    li    $v0, 1
    j     hedb_end
    nop

hedb_badfmt:
    li    $v0, 4
    la    $a0, msg_cc_badfmt
    syscall
    li    $v0, 1
    j     hedb_end
    nop

hedb_not_mine:
    move  $v0, $zero

hedb_end:
    lw    $s2,  8($sp)
    lw    $s1, 12($sp)
    lw    $s0, 16($sp)
    lw    $ra, 20($sp)
    addiu $sp, $sp, 24
    jr    $ra
    nop
