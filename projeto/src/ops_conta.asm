###############################################
# R2 – PAGAR DÉBITO
###############################################
.text
.globl handle_pagar_debito
handle_pagar_debito:
    # compara prefixo "pagar_debito-"
    move $t0, $a0
    la   $t1, str_cmd_pay_debito
pd_pref:
    lb   $t2, 0($t1)
    beq  $t2, $zero, pd_pref_ok
    lb   $t3, 0($t0)
    bne  $t2, $t3, pd_not_mine
    addi $t0, $t0, 1
    addi $t1, $t1, 1
    j    pd_pref
pd_pref_ok:
    # parse conta: 6 dígitos
    la   $t4, cc_buf_acc
    li   $t5, 0
pd_acc_loop:
    lb   $t6, 0($t0)
    blt  $t6, 48, pd_badfmt      # '0'
    bgt  $t6, 57, pd_badfmt      # '9'
    sb   $t6, 0($t4)
    addi $t4, $t4, 1
    addi $t0, $t0, 1
    addi $t5, $t5, 1
    blt  $t5, 6, pd_acc_loop
    sb   $zero, 0($t4)

    # '-'
    lb   $t6, 0($t0)
    li   $t7, 45                 # '-'
    bne  $t6, $t7, pd_badfmt
    addi $t0, $t0, 1

    # DV: '0'..'9' ou 'X'
    lb   $s1, 0($t0)
    addi $t0, $t0, 1
    li   $t7, 88                 # 'X'
    beq  $s1, $t7, pd_dv_ok
    blt  $s1, 48, pd_badfmt
    bgt  $s1, 57, pd_badfmt
pd_dv_ok:

    # '-'
    lb   $t6, 0($t0)
    li   $t7, 45
    bne  $t6, $t7, pd_badfmt
    addi $t0, $t0, 1

    # parse valor (centavos) -> $t8 (u32)
    move $t8, $zero
pd_val_loop:
    lb   $t6, 0($t0)
    beq  $t6, $zero, pd_val_end
    blt  $t6, 48, pd_badfmt
    bgt  $t6, 57, pd_badfmt
    addi $t6, $t6, -48
    mul  $t8, $t8, 10
    addu $t8, $t8, $t6
    addi $t0, $t0, 1
    j    pd_val_loop
pd_val_end:

    # procurar cliente por conta+DV
    lw   $t9, MAX_CLIENTS        # N
    move $t1, $zero              # i=0
pd_find:
    beq  $t1, $t9, pd_not_found
    # usado?
    la   $a0, clientes_usado
    addu $a0, $a0, $t1
    lb   $a1, 0($a0)
    beq  $a1, $zero, pd_next

    # conta[i]
    la   $a2, clientes_conta
    li   $a3, 7
    mul  $a3, $t1, $a3
    addu $a2, $a2, $a3           # &conta[i]

    # compara 6 chars com cc_buf_acc
    la   $a3, cc_buf_acc
    li   $v1, 0
pd_cmp6:
    lb   $t2, 0($a2)
    lb   $t3, 0($a3)
    bne  $t2, $t3, pd_next
    addi $a2, $a2, 1
    addi $a3, $a3, 1
    addi $v1, $v1, 1
    blt  $v1, 6, pd_cmp6

    # dv
    la   $a2, clientes_dv
    addu $a2, $a2, $t1
    lb   $t2, 0($a2)
    bne  $t2, $s1, pd_next

    # ---- ENCONTROU ---- saldo[i] -= valor (se houver)
    sll  $a1, $t1, 2             # offset = i*4
    la   $a0, clientes_saldo_cent
    addu $a0, $a0, $a1
    lw   $a3, 0($a0)             # saldo
    sltu $v1, $a3, $t8           # saldo < valor ?
    bne  $v1, $zero, pd_saldo_insuf
    subu $a3, $a3, $t8
    sw   $a3, 0($a0)

    li   $v0, 4
    la   $a0, msg_pay_deb_ok
    syscall
    li   $v0, 1
    jr   $ra

pd_saldo_insuf:
    li   $v0, 4
    la   $a0, msg_err_saldo_insuf
    syscall
    li   $v0, 1
    jr   $ra

pd_next:
    addi $t1, $t1, 1
    j    pd_find

pd_not_found:
    li   $v0, 4
    la   $a0, msg_err_cli_inexist
    syscall
    li   $v0, 1
    jr   $ra

pd_badfmt:
    li   $v0, 4
    la   $a0, msg_cc_badfmt
    syscall
    li   $v0, 1
    jr   $ra

pd_not_mine:
    move $v0, $zero
    jr   $ra


###############################################
# R2 – PAGAR CRÉDITO
###############################################
.globl handle_pagar_credito
handle_pagar_credito:
    # prefixo "pagar_credito-"
    move $t0, $a0
    la   $t1, str_cmd_pay_credito
pc_pref:
    lb   $t2, 0($t1)
    beq  $t2, $zero, pc_pref_ok
    lb   $t3, 0($t0)
    bne  $t2, $t3, pc_not_mine
    addi $t0, $t0, 1
    addi $t1, $t1, 1
    j    pc_pref
pc_pref_ok:
    # conta 6 + '-' + DV + '-' + valor
    la   $t4, cc_buf_acc
    li   $t5, 0
pc_acc_loop:
    lb   $t6, 0($t0)
    blt  $t6, 48, pc_badfmt
    bgt  $t6, 57, pc_badfmt
    sb   $t6, 0($t4)
    addi $t4, $t4, 1
    addi $t0, $t0, 1
    addi $t5, $t5, 1
    blt  $t5, 6, pc_acc_loop
    sb   $zero, 0($t4)

    lb   $t6, 0($t0)             # '-'
    li   $t7, 45
    bne  $t6, $t7, pc_badfmt
    addi $t0, $t0, 1

    lb   $s1, 0($t0)             # DV
    addi $t0, $t0, 1
    li   $t7, 88
    beq  $s1, $t7, pc_dv_ok
    blt  $s1, 48, pc_badfmt
    bgt  $s1, 57, pc_badfmt
pc_dv_ok:
    lb   $t6, 0($t0)             # '-'
    li   $t7, 45
    bne  $t6, $t7, pc_badfmt
    addi $t0, $t0, 1

    # valor -> $t8
    move $t8, $zero
pc_val_loop:
    lb   $t6, 0($t0)
    beq  $t6, $zero, pc_val_end
    blt  $t6, 48, pc_badfmt
    bgt  $t6, 57, pc_badfmt
    addi $t6, $t6, -48
    mul  $t8, $t8, 10
    addu $t8, $t8, $t6
    addi $t0, $t0, 1
    j    pc_val_loop
pc_val_end:

    # achar cliente
    lw   $t9, MAX_CLIENTS
    move $t1, $zero
pc_find:
    beq  $t1, $t9, pc_not_found
    la   $a0, clientes_usado
    addu $a0, $a0, $t1
    lb   $a1, 0($a0)
    beq  $a1, $zero, pc_next

    la   $a2, clientes_conta
    li   $a3, 7
    mul  $a3, $t1, $a3
    addu $a2, $a2, $a3
    la   $a3, cc_buf_acc
    li   $v1, 0
pc_cmp6:
    lb   $t2, 0($a2)
    lb   $t3, 0($a3)
    bne  $t2, $t3, pc_next
    addi $a2, $a2, 1
    addi $a3, $a3, 1
    addi $v1, $v1, 1
    blt  $v1, 6, pc_cmp6

    la   $a2, clientes_dv
    addu $a2, $a2, $t1
    lb   $t2, 0($a2)
    bne  $t2, $s1, pc_next

    # ---- ENCONTROU ---- checar limite disponível
    sll  $a1, $t1, 2
    la   $t2, clientes_limite_cent
    la   $t3, clientes_devido_cent
    addu $t2, $t2, $a1          # &limite[i]
    addu $t3, $t3, $a1          # &devido[i]
    lw   $t4, 0($t2)            # limite
    lw   $t5, 0($t3)            # devido
    subu $t6, $t4, $t5          # disponivel = limite - devido
    sltu $v1, $t6, $t8
    bne  $v1, $zero, pc_lim_insuf

    addu $t5, $t5, $t8          # devido += valor
    sw   $t5, 0($t3)

    li   $v0, 4
    la   $a0, msg_pay_cred_ok
    syscall
    li   $v0, 1
    jr   $ra

pc_lim_insuf:
    li   $v0, 4
    la   $a0, msg_err_limite_insuf
    syscall
    li   $v0, 1
    jr   $ra

pc_next:
    addi $t1, $t1, 1
    j    pc_find

pc_not_found:
    li   $v0, 4
    la   $a0, msg_err_cli_inexist
    syscall
    li   $v0, 1
    jr   $ra

pc_badfmt:
    li   $v0, 4
    la   $a0, msg_cc_badfmt
    syscall
    li   $v0, 1
    jr   $ra

pc_not_mine:
    move $v0, $zero
    jr   $ra


###############################################
# R2 – ALTERAR LIMITE
###############################################
.globl handle_alterar_limite
handle_alterar_limite:
    # prefixo "alterar_limite-"
    move $t0, $a0
    la   $t1, str_cmd_alt_limite
al_pref:
    lb   $t2, 0($t1)
    beq  $t2, $zero, al_pref_ok
    lb   $t3, 0($t0)
    bne  $t2, $t3, al_not_mine
    addi $t0, $t0, 1
    addi $t1, $t1, 1
    j    al_pref
al_pref_ok:
    # conta 6 + '-' + DV + '-' + novo_limite
    la   $t4, cc_buf_acc
    li   $t5, 0
al_acc_loop:
    lb   $t6, 0($t0)
    blt  $t6, 48, al_badfmt
    bgt  $t6, 57, al_badfmt
    sb   $t6, 0($t4)
    addi $t4, $t4, 1
    addi $t0, $t0, 1
    addi $t5, $t5, 1
    blt  $t5, 6, al_acc_loop
    sb   $zero, 0($t4)

    lb   $t6, 0($t0)             # '-'
    li   $t7, 45
    bne  $t6, $t7, al_badfmt
    addi $t0, $t0, 1

    lb   $s1, 0($t0)             # DV
    addi $t0, $t0, 1
    li   $t7, 88
    beq  $s1, $t7, al_dv_ok
    blt  $s1, 48, al_badfmt
    bgt  $s1, 57, al_badfmt
al_dv_ok:
    lb   $t6, 0($t0)             # '-'
    li   $t7, 45
    bne  $t6, $t7, al_badfmt
    addi $t0, $t0, 1

    # novo limite -> $t8
    move $t8, $zero
al_val_loop:
    lb   $t6, 0($t0)
    beq  $t6, $zero, al_val_end
    blt  $t6, 48, al_badfmt
    bgt  $t6, 57, al_badfmt
    addi $t6, $t6, -48
    mul  $t8, $t8, 10
    addu $t8, $t8, $t6
    addi $t0, $t0, 1
    j    al_val_loop
al_val_end:

    # achar cliente
    lw   $t9, MAX_CLIENTS
    move $t1, $zero
al_find:
    beq  $t1, $t9, al_not_found
    la   $a0, clientes_usado
    addu $a0, $a0, $t1
    lb   $a1, 0($a0)
    beq  $a1, $zero, al_next

    la   $a2, clientes_conta
    li   $a3, 7
    mul  $a3, $t1, $a3
    addu $a2, $a2, $a3
    la   $a3, cc_buf_acc
    li   $v1, 0
al_cmp6:
    lb   $t2, 0($a2)
    lb   $t3, 0($a3)
    bne  $t2, $t3, al_next
    addi $a2, $a2, 1
    addi $a3, $a3, 1
    addi $v1, $v1, 1
    blt  $v1, 6, al_cmp6

    la   $a2, clientes_dv
    addu $a2, $a2, $t1
    lb   $t2, 0($a2)
    bne  $t2, $s1, al_next

    # ---- ENCONTROU ---- checar se novo limite >= devido
    sll  $a1, $t1, 2
    la   $t2, clientes_devido_cent
    addu $t2, $t2, $a1
    lw   $t3, 0($t2)            # devido
    sltu $v1, $t8, $t3          # novo_limite < devido ?
    bne  $v1, $zero, al_baixo

    la   $t4, clientes_limite_cent
    addu $t4, $t4, $a1
    sw   $t8, 0($t4)

    li   $v0, 4
    la   $a0, msg_limite_ok
    syscall
    li   $v0, 1
    jr   $ra

al_baixo:
    li   $v0, 4
    la   $a0, msg_limite_baixo_divida
    syscall
    li   $v0, 1
    jr   $ra

al_next:
    addi $t1, $t1, 1
    j    al_find

al_not_found:
    li   $v0, 4
    la   $a0, msg_err_cli_inexist
    syscall
    li   $v0, 1
    jr   $ra

al_badfmt:
    li   $v0, 4
    la   $a0, msg_cc_badfmt
    syscall
    li   $v0, 1
    jr   $ra

al_not_mine:
    move $v0, $zero
    jr   $ra
