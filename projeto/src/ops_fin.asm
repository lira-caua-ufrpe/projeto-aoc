# ops_fin.asm — R2 (pagamentos) + R3 (registro de transações)
# Handlers:
#  - pagar_debito-<CONTA6>-<DV>-<VALORcentavos>
#  - pagar_credito-<CONTA6>-<DV>-<VALORcentavos>
#  - alterar_limite-<CONTA6>-<DV>-<NOVO_LIMcentavos>
#
# Regras R3: registrar até 50 trans/debito e 50 trans/credito por cliente,
# sobrescrevendo a mais antiga (buffer circular).

.text
.globl calc_off_i50k
.globl handle_pagar_debito
.globl handle_pagar_credito
.globl handle_alterar_limite
.globl handle_dump_trans_credito
.globl handle_dump_trans_debito
# aliases esperados pelo main.asm:
.globl handle_dump_trans_cred
.globl handle_dump_trans_deb

# ------------------------------------------------------------
# Util: calcula offset 4 * ( i*50 + k )
#   a0 = i (cliente)
#   a1 = k (head/pos)
#   v0 = deslocamento em bytes (multiplo de 4)
# ------------------------------------------------------------
calc_off_i50k:
    # t0 = i*50 = i*32 + i*16 + i*2
    sll  $t0, $a0, 5       # i*32
    sll  $t1, $a0, 4       # i*16
    addu $t0, $t0, $t1     # i*48
    sll  $t1, $a0, 1       # i*2
    addu $t0, $t0, $t1     # i*50
    addu $t0, $t0, $a1     # i*50 + k
    sll  $v0, $t0, 2       # *4 bytes
    jr   $ra

# ------------------------------------------------------------
# pagar_debito
# ------------------------------------------------------------
handle_pagar_debito:
    addiu $sp, $sp, -32
    sw    $ra, 28($sp)
    sw    $s0, 24($sp)
    sw    $s1, 20($sp)
    sw    $s2, 16($sp)

    # checa prefixo "pagar_debito-"
    move  $t0, $a0
    la    $t1, str_cmd_pay_debito
pd_chk_pref_loop:
    lb    $t2, 0($t1)
    beq   $t2, $zero, pd_pref_ok
    lb    $t3, 0($t0)
    bne   $t2, $t3, pd_not_mine
    addi  $t1, $t1, 1
    addi  $t0, $t0, 1
    j     pd_chk_pref_loop

pd_pref_ok:
    # CONTA(6)
    la    $t4, cc_buf_acc
    li    $t5, 0
pd_acc_loop:
    lb    $t6, 0($t0)
    blt   $t6, 48, pd_badfmt
    bgt   $t6, 57, pd_badfmt
    sb    $t6, 0($t4)
    addi  $t4, $t4, 1
    addi  $t0, $t0, 1
    addi  $t5, $t5, 1
    blt   $t5, 6, pd_acc_loop
    sb    $zero, 0($t4)

    # '-'
    lb    $t6, 0($t0)
    li    $t7, 45
    bne   $t6, $t7, pd_badfmt
    addi  $t0, $t0, 1

    # DV
    lb    $s1, 0($t0)
    addi  $t0, $t0, 1
    li    $t7, 88              # 'X'
    beq   $s1, $t7, pd_dv_ok
    blt   $s1, 48, pd_badfmt
    bgt   $s1, 57, pd_badfmt
pd_dv_ok:

    # '-'
    lb    $t6, 0($t0)
    li    $t7, 45
    bne   $t6, $t7, pd_badfmt
    addi  $t0, $t0, 1

    # VALOR -> t8
    move  $t8, $zero
pd_val_loop:
    lb    $t6, 0($t0)
    beq   $t6, $zero, pd_val_end
    blt   $t6, 48, pd_badfmt
    bgt   $t6, 57, pd_badfmt
    addi  $t6, $t6, -48
    mul   $t8, $t8, 10
    addu  $t8, $t8, $t6
    addi  $t0, $t0, 1
    j     pd_val_loop
pd_val_end:

    # procura cliente por conta+DV
    lw    $t9, MAX_CLIENTS
    move  $t1, $zero          # i=0
pd_find_loop:
    beq   $t1, $t9, pd_not_found

    # usado?
    la    $a0, clientes_usado
    addu  $a0, $a0, $t1
    lb    $a1, 0($a0)
    beq   $a1, $zero, pd_next_i

    # compara conta(6)
    la    $a2, clientes_conta
    li    $a3, 7
    mul   $a3, $t1, $a3
    addu  $a2, $a2, $a3
    la    $a3, cc_buf_acc
    li    $v1, 0
pd_cmp6:
    lb    $t2, 0($a2)
    lb    $t3, 0($a3)
    bne   $t2, $t3, pd_next_i
    addi  $a2, $a2, 1
    addi  $a3, $a3, 1
    addi  $v1, $v1, 1
    blt   $v1, 6, pd_cmp6

    # dv confere?
    la    $a2, clientes_dv
    addu  $a2, $a2, $t1
    lb    $t2, 0($a2)
    bne   $t2, $s1, pd_next_i

    # --- ENCONTROU i ---
    # saldo[i] >= valor ?
    sll   $t0, $t1, 2
    la    $t2, clientes_saldo_cent
    addu  $t2, $t2, $t0
    lw    $t3, 0($t2)           # saldo
    sltu  $v1, $t3, $t8
    bne   $v1, $zero, pd_saldo_insuf

    # saldo -= valor
    subu  $t3, $t3, $t8
    sw    $t3, 0($t2)

    # ---- R3: registra débito ----
    # headAddr = trans_deb_head + 4*i
    la    $t4, trans_deb_head
    addu  $t4, $t4, $t0       # t0 = i*4
    lw    $t5, 0($t4)         # head (0..49)

    # slotOffset = 4*(i*50 + head)
    move  $a0, $t1            # i
    move  $a1, $t5            # head
    jal   calc_off_i50k
    move  $t6, $v0            # guarda offset em t6

    la    $t7, trans_deb_vals
    addu  $t7, $t7, $t6
    sw    $t8, 0($t7)         # grava valor

    # head = (head + 1) % 50
    addiu $t5, $t5, 1
    li    $t6, 50
    bne   $t5, $t6, pd_head_ok
    move  $t5, $zero
pd_head_ok:
    sw    $t5, 0($t4)

    # ok
    li    $v0, 4
    la    $a0, msg_pay_deb_ok
    syscall
    li    $v0, 1
    j     pd_done

pd_next_i:
    addiu $t1, $t1, 1
    j     pd_find_loop

pd_not_found:
    li    $v0, 4
    la    $a0, msg_err_cli_inexist
    syscall
    li    $v0, 1
    j     pd_done

pd_saldo_insuf:
    li    $v0, 4
    la    $a0, msg_err_saldo_insuf
    syscall
    li    $v0, 1
    j     pd_done

pd_badfmt:
    li    $v0, 4
    la    $a0, msg_cc_badfmt
    syscall
    li    $v0, 1
    j     pd_done

pd_not_mine:
    move  $v0, $zero

pd_done:
    lw    $s2, 16($sp)
    lw    $s1, 20($sp)
    lw    $s0, 24($sp)
    lw    $ra, 28($sp)
    addiu $sp, $sp, 32
    jr    $ra

# ------------------------------------------------------------
# pagar_credito
# ------------------------------------------------------------
handle_pagar_credito:
    addiu $sp, $sp, -32
    sw    $ra, 28($sp)
    sw    $s0, 24($sp)
    sw    $s1, 20($sp)
    sw    $s2, 16($sp)

    # prefixo "pagar_credito-"
    move  $t0, $a0
    la    $t1, str_cmd_pay_credito
pc_chk_pref_loop:
    lb    $t2, 0($t1)
    beq   $t2, $zero, pc_pref_ok
    lb    $t3, 0($t0)
    bne   $t2, $t3, pc_not_mine
    addi  $t1, $t1, 1
    addi  $t0, $t0, 1
    j     pc_chk_pref_loop

pc_pref_ok:
    # conta(6)
    la    $t4, cc_buf_acc
    li    $t5, 0
pc_acc_loop:
    lb    $t6, 0($t0)
    blt   $t6, 48, pc_badfmt
    bgt   $t6, 57, pc_badfmt
    sb    $t6, 0($t4)
    addi  $t4, $t4, 1
    addi  $t0, $t0, 1
    addi  $t5, $t5, 1
    blt   $t5, 6, pc_acc_loop
    sb    $zero, 0($t4)

    # '-'
    lb    $t6, 0($t0)
    li    $t7, 45
    bne   $t6, $t7, pc_badfmt
    addi  $t0, $t0, 1

    # DV
    lb    $s1, 0($t0)
    addi  $t0, $t0, 1
    li    $t7, 88
    beq   $s1, $t7, pc_dv_ok
    blt   $s1, 48, pc_badfmt
    bgt   $s1, 57, pc_badfmt
pc_dv_ok:
    # '-'
    lb    $t6, 0($t0)
    li    $t7, 45
    bne   $t6, $t7, pc_badfmt
    addi  $t0, $t0, 1

    # valor -> t8
    move  $t8, $zero
pc_val_loop:
    lb    $t6, 0($t0)
    beq   $t6, $zero, pc_val_end
    blt   $t6, 48, pc_badfmt
    bgt   $t6, 57, pc_badfmt
    addi  $t6, $t6, -48
    mul   $t8, $t8, 10
    addu  $t8, $t8, $t6
    addi  $t0, $t0, 1
    j     pc_val_loop
pc_val_end:

    # procura cliente
    lw    $t9, MAX_CLIENTS
    move  $t1, $zero
pc_find_loop:
    beq   $t1, $t9, pc_not_found
    # usado?
    la    $a0, clientes_usado
    addu  $a0, $a0, $t1
    lb    $a1, 0($a0)
    beq   $a1, $zero, pc_next_i

    # conta(6)
    la    $a2, clientes_conta
    li    $a3, 7
    mul   $a3, $t1, $a3
    addu  $a2, $a2, $a3
    la    $a3, cc_buf_acc
    li    $v1, 0
pc_cmp6:
    lb    $t2, 0($a2)
    lb    $t3, 0($a3)
    bne   $t2, $t3, pc_next_i
    addi  $a2, $a2, 1
    addi  $a3, $a3, 1
    addi  $v1, $v1, 1
    blt   $v1, 6, pc_cmp6

    # dv
    la    $a2, clientes_dv
    addu  $a2, $a2, $t1
    lb    $t2, 0($a2)
    bne   $t2, $s1, pc_next_i

    # --- ENCONTROU i ---
    # verifica limite disponível: (limite - devido) >= valor ?
    sll   $t0, $t1, 2
    la    $t2, clientes_limite_cent
    la    $t3, clientes_devido_cent
    addu  $t2, $t2, $t0
    addu  $t3, $t3, $t0
    lw    $t4, 0($t2)          # limite
    lw    $t5, 0($t3)          # devido
    subu  $t6, $t4, $t5        # disponivel
    sltu  $v1, $t6, $t8
    bne   $v1, $zero, pc_lim_insuf

    # devido += valor
    addu  $t5, $t5, $t8
    sw    $t5, 0($t3)

    # ---- R3: registra crédito ----
    la    $t4, trans_cred_head
    addu  $t4, $t4, $t0        # t0 = i*4
    lw    $t5, 0($t4)          # head (0..49)

    move  $a0, $t1             # i
    move  $a1, $t5             # head
    jal   calc_off_i50k
    move  $t6, $v0

    la    $t7, trans_cred_vals
    addu  $t7, $t7, $t6
    sw    $t8, 0($t7)

    addiu $t5, $t5, 1
    li    $t6, 50
    bne   $t5, $t6, pc_head_ok
    move  $t5, $zero
pc_head_ok:
    sw    $t5, 0($t4)

    li    $v0, 4
    la    $a0, msg_pay_cred_ok
    syscall
    li    $v0, 1
    j     pc_done

pc_next_i:
    addiu $t1, $t1, 1
    j     pc_find_loop

pc_not_found:
    li    $v0, 4
    la    $a0, msg_err_cli_inexist
    syscall
    li    $v0, 1
    j     pc_done

pc_lim_insuf:
    li    $v0, 4
    la    $a0, msg_err_limite_insuf
    syscall
    li    $v0, 1
    j     pc_done

pc_badfmt:
    li    $v0, 4
    la    $a0, msg_cc_badfmt
    syscall
    li    $v0, 1
    j     pc_done

pc_not_mine:
    move  $v0, $zero

pc_done:
    lw    $s2, 16($sp)
    lw    $s1, 20($sp)
    lw    $s0, 24($sp)
    lw    $ra, 28($sp)
    addiu $sp, $sp, 32
    jr    $ra

# ------------------------------------------------------------
# alterar_limite
# ------------------------------------------------------------
handle_alterar_limite:
    addiu $sp, $sp, -24
    sw    $ra, 20($sp)
    sw    $s0, 16($sp)
    sw    $s1, 12($sp)

    # prefixo "alterar_limite-"
    move  $t0, $a0
    la    $t1, str_cmd_alt_limite
al_chk_pref_loop:
    lb    $t2, 0($t1)
    beq   $t2, $zero, al_pref_ok
    lb    $t3, 0($t0)
    bne   $t2, $t3, al_not_mine
    addi  $t1, $t1, 1
    addi  $t0, $t0, 1
    j     al_chk_pref_loop

al_pref_ok:
    # conta(6)
    la    $t4, cc_buf_acc
    li    $t5, 0
al_acc_loop:
    lb    $t6, 0($t0)
    blt   $t6, 48, al_badfmt
    bgt   $t6, 57, al_badfmt
    sb    $t6, 0($t4)
    addi  $t4, $t4, 1
    addi  $t0, $t0, 1
    addi  $t5, $t5, 1
    blt   $t5, 6, al_acc_loop
    sb    $zero, 0($t4)

    # '-'
    lb    $t6, 0($t0)
    li    $t7, 45
    bne   $t6, $t7, al_badfmt
    addi  $t0, $t0, 1

    # DV
    lb    $s1, 0($t0)
    addi  $t0, $t0, 1
    li    $t7, 88
    beq   $s1, $t7, al_dv_ok
    blt   $s1, 48, al_badfmt
    bgt   $s1, 57, al_badfmt
al_dv_ok:
    # '-'
    lb    $t6, 0($t0)
    li    $t7, 45
    bne   $t6, $t7, al_badfmt
    addi  $t0, $t0, 1

    # novo limite -> t8
    move  $t8, $zero
al_val_loop:
    lb    $t6, 0($t0)
    beq   $t6, $zero, al_val_end
    blt   $t6, 48, al_badfmt
    bgt   $t6, 57, al_badfmt
    addi  $t6, $t6, -48
    mul   $t8, $t8, 10
    addu  $t8, $t8, $t6
    addi  $t0, $t0, 1
    j     al_val_loop
al_val_end:

    # procura cliente
    lw    $t9, MAX_CLIENTS
    move  $t1, $zero
al_find_loop:
    beq   $t1, $t9, al_not_found
    la    $a0, clientes_usado
    addu  $a0, $a0, $t1
    lb    $a1, 0($a0)
    beq   $a1, $zero, al_next_i

    la    $a2, clientes_conta
    li    $a3, 7
    mul   $a3, $t1, $a3
    addu  $a2, $a2, $a3
    la    $a3, cc_buf_acc
    li    $v1, 0
al_cmp6:
    lb    $t2, 0($a2)
    lb    $t3, 0($a3)
    bne   $t2, $t3, al_next_i
    addi  $a2, $a2, 1
    addi  $a3, $a3, 1
    addi  $v1, $v1, 1
    blt   $v1, 6, al_cmp6

    la    $a2, clientes_dv
    addu  $a2, $a2, $t1
    lb    $t2, 0($a2)
    bne   $t2, $s1, al_next_i

    # --- ENCONTROU i ---
    # novo limite >= devido ?
    sll   $t0, $t1, 2
    la    $t2, clientes_devido_cent
    addu  $t2, $t2, $t0
    lw    $t3, 0($t2)          # devido
    sltu  $v1, $t8, $t3
    bne   $v1, $zero, al_baixo

    la    $t4, clientes_limite_cent
    addu  $t4, $t4, $t0
    sw    $t8, 0($t4)

    li    $v0, 4
    la    $a0, msg_limite_ok
    syscall
    li    $v0, 1
    j     al_done

al_next_i:
    addiu $t1, $t1, 1
    j     al_find_loop

al_not_found:
    li    $v0, 4
    la    $a0, msg_err_cli_inexist
    syscall
    li    $v0, 1
    j     al_done

al_baixo:
    li    $v0, 4
    la    $a0, msg_limite_baixo_divida
    syscall
    li    $v0, 1
    j     al_done

al_badfmt:
    li    $v0, 4
    la    $a0, msg_cc_badfmt
    syscall
    li    $v0, 1
    j     al_done

al_not_mine:
    move  $v0, $zero

al_done:
    lw    $s1, 12($sp)
    lw    $s0, 16($sp)
    lw    $ra, 20($sp)
    addiu $sp, $sp, 24
    jr    $ra

################################################################
# DEBUG R3: Dump de transações (CRÉDITO / DÉBITO)
# Comandos:
#   dump_trans-cred-XXXXXX-DV
#   dump_trans-deb- XXXXXX-DV
################################################################

.data
dump_hdr_cred: .asciiz "LOG credito (50 posicoes, mais antigo -> mais novo)\n"
dump_hdr_deb:  .asciiz "LOG debito  (50 posicoes, mais antigo -> mais novo)\n"

.text

# --------------------------------------------------------------
# handle_dump_trans_credito(a0=inp_buf) -> v0=1 tratou, 0 nao
# --------------------------------------------------------------
handle_dump_trans_credito:
    # prólogo
    addiu $sp, $sp, -40
    sw    $ra, 36($sp)
    sw    $s0, 32($sp)
    sw    $s1, 28($sp)
    sw    $s2, 24($sp)
    sw    $s3, 20($sp)

    # prefixo "dump_trans-cred-"
    move  $t0, $a0
    la    $t1, str_cmd_dumpcred
dtc_pref:
    lb    $t2, 0($t1)
    beq   $t2, $zero, dtc_pref_ok
    lb    $t3, 0($t0)
    bne   $t2, $t3, dtc_not_mine
    addi  $t0, $t0, 1
    addi  $t1, $t1, 1
    j     dtc_pref
dtc_pref_ok:
    # conta (6 digitos)
    la    $t4, cc_buf_acc
    li    $t5, 0
dtc_acc:
    lb    $t6, 0($t0)
    blt   $t6, 48,  dtc_badfmt
    bgt   $t6, 57,  dtc_badfmt
    sb    $t6, 0($t4)
    addi  $t4, $t4, 1
    addi  $t0, $t0, 1
    addi  $t5, $t5, 1
    blt   $t5, 6,   dtc_acc
    sb    $zero, 0($t4)
    lb    $t6, 0($t0)          # '-'
    li    $t7, 45
    bne   $t6, $t7, dtc_badfmt
    addi  $t0, $t0, 1

    # DV
    lb    $s1, 0($t0)
    addi  $t0, $t0, 1
    li    $t7, 88              # 'X'
    beq   $s1, $t7, dtc_dv_ok
    blt   $s1, 48, dtc_badfmt
    bgt   $s1, 57, dtc_badfmt
dtc_dv_ok:

    # === localizar cliente por conta+DV ===
    lw    $t9, MAX_CLIENTS
    move  $s0, $zero           # i = 0
dtc_find:
    beq   $s0, $t9, dtc_not_found

    la    $a0, clientes_usado
    addu  $a0, $a0, $s0
    lb    $a1, 0($a0)
    beq   $a1, $zero, dtc_next

    la    $a2, clientes_conta   # &conta[i]
    li    $a3, 7
    mul   $a3, $s0, $a3
    addu  $a2, $a2, $a3
    la    $a3, cc_buf_acc
    li    $v1, 0
dtc_cmp6:
    lb    $t2, 0($a2)
    lb    $t3, 0($a3)
    bne   $t2, $t3, dtc_next
    addi  $a2, $a2, 1
    addi  $a3, $a3, 1
    addi  $v1, $v1, 1
    blt   $v1, 6, dtc_cmp6

    la    $a2, clientes_dv
    addu  $a2, $a2, $s0
    lb    $t2, 0($a2)
    bne   $t2, $s1, dtc_next

    # === achou: despejar 50 posicoes do anel ===
    li    $v0, 4
    la    $a0, dump_hdr_cred
    syscall

    # base do bloco de 200 bytes (50 * 4) do cliente i
    la    $s2, trans_cred_vals
    li    $t0, 200
    mul   $t1, $s0, $t0
    addu  $s2, $s2, $t1         # s2 = base bloco cliente

    # wptr = trans_cred_wptr[i] (proxima posicao a escrever)
    la    $t2, trans_cred_wptr
    sll   $t3, $s0, 2
    addu  $t2, $t2, $t3
    lw    $s3, 0($t2)           # s3 = wptr (0..49)

    # loop 0..49: idx = (wptr + k) % 50
    li    $t4, 0                # k
dtc_loop:
    li    $t5, 50
    beq   $t4, $t5, dtc_done

    addu  $t6, $s3, $t4         # wptr + k
    sltiu $t7, $t6, 50
    bne   $t7, $zero, dtc_idx_ok
    addi  $t6, $t6, -50
dtc_idx_ok:
    sll   $t6, $t6, 2           # *4
    addu  $t8, $s2, $t6
    lw    $a0, 0($t8)

    li    $v0, 1                # print_int
    syscall
    li    $v0, 11               # '\n'
    li    $a0, 10
    syscall

    addi  $t4, $t4, 1
    j     dtc_loop

dtc_done:
    li    $v0, 1
    j     dtc_epilogue

dtc_next:
    addi  $s0, $s0, 1
    j     dtc_find

dtc_not_found:
    li    $v0, 4
    la    $a0, msg_err_cli_inexist
    syscall
    li    $v0, 1
    j     dtc_epilogue

dtc_badfmt:
    li    $v0, 4
    la    $a0, msg_cc_badfmt
    syscall
    li    $v0, 1
    j     dtc_epilogue

dtc_not_mine:
    move  $v0, $zero

dtc_epilogue:
    lw    $s3, 20($sp)
    lw    $s2, 24($sp)
    lw    $s1, 28($sp)
    lw    $s0, 32($sp)
    lw    $ra, 36($sp)
    addiu $sp, $sp, 40
    jr    $ra


# --------------------------------------------------------------
# handle_dump_trans_debito(a0=inp_buf) -> v0=1 tratou, 0 nao
# --------------------------------------------------------------
handle_dump_trans_debito:
    # prólogo
    addiu $sp, $sp, -40
    sw    $ra, 36($sp)
    sw    $s0, 32($sp)
    sw    $s1, 28($sp)
    sw    $s2, 24($sp)
    sw    $s3, 20($sp)

    # prefixo "dump_trans-deb-"
    move  $t0, $a0
    la    $t1, str_cmd_dumpdeb
dtd_pref:
    lb    $t2, 0($t1)
    beq   $t2, $zero, dtd_pref_ok
    lb    $t3, 0($t0)
    bne   $t2, $t3, dtd_not_mine
    addi  $t0, $t0, 1
    addi  $t1, $t1, 1
    j     dtd_pref
dtd_pref_ok:
    # conta (6)
    la    $t4, cc_buf_acc
    li    $t5, 0
dtd_acc:
    lb    $t6, 0($t0)
    blt   $t6, 48,  dtd_badfmt
    bgt   $t6, 57,  dtd_badfmt
    sb    $t6, 0($t4)
    addi  $t4, $t4, 1
    addi  $t0, $t0, 1
    addi  $t5, $t5, 1
    blt   $t5, 6,   dtd_acc
    sb    $zero, 0($t4)
    lb    $t6, 0($t0)          # '-'
    li    $t7, 45
    bne   $t6, $t7, dtd_badfmt
    addi  $t0, $t0, 1

    # DV
    lb    $s1, 0($t0)
    addi  $t0, $t0, 1
    li    $t7, 88
    beq   $s1, $t7, dtd_dv_ok
    blt   $s1, 48, dtd_badfmt
    bgt   $s1, 57, dtd_badfmt
dtd_dv_ok:

    # localizar cliente
    lw    $t9, MAX_CLIENTS
    move  $s0, $zero
dtd_find:
    beq   $s0, $t9, dtd_not_found

    la    $a0, clientes_usado
    addu  $a0, $a0, $s0
    lb    $a1, 0($a0)
    beq   $a1, $zero, dtd_next

    la    $a2, clientes_conta
    li    $a3, 7
    mul   $a3, $s0, $a3
    addu  $a2, $a2, $a3
    la    $a3, cc_buf_acc
    li    $v1, 0
dtd_cmp6:
    lb    $t2, 0($a2)
    lb    $t3, 0($a3)
    bne   $t2, $t3, dtd_next
    addi  $a2, $a2, 1
    addi  $a3, $a3, 1
    addi  $v1, $v1, 1
    blt   $v1, 6, dtd_cmp6

    la    $a2, clientes_dv
    addu  $a2, $a2, $s0
    lb    $t2, 0($a2)
    bne   $t2, $s1, dtd_next

    # dump
    li    $v0, 4
    la    $a0, dump_hdr_deb
    syscall

    la    $s2, trans_deb_vals
    li    $t0, 200
    mul   $t1, $s0, $t0
    addu  $s2, $s2, $t1

    la    $t2, trans_deb_wptr
    sll   $t3, $s0, 2
    addu  $t2, $t2, $t3
    lw    $s3, 0($t2)           # wptr

    li    $t4, 0
dtd_loop:
    li    $t5, 50
    beq   $t4, $t5, dtd_done

    addu  $t6, $s3, $t4
    sltiu $t7, $t6, 50
    bne   $t7, $zero, dtd_idx_ok
    addi  $t6, $t6, -50
dtd_idx_ok:
    sll   $t6, $t6, 2
    addu  $t8, $s2, $t6
    lw    $a0, 0($t8)

    li    $v0, 1
    syscall
    li    $v0, 11
    li    $a0, 10
    syscall

    addi  $t4, $t4, 1
    j     dtd_loop

dtd_done:
    li    $v0, 1
    j     dtd_epilogue

dtd_next:
    addi  $s0, $s0, 1
    j     dtd_find

dtd_not_found:
    li    $v0, 4
    la    $a0, msg_err_cli_inexist
    syscall
    li    $v0, 1
    j     dtd_epilogue

dtd_badfmt:
    li    $v0, 4
    la    $a0, msg_cc_badfmt
    syscall
    li    $v0, 1
    j     dtd_epilogue

dtd_not_mine:
    move  $v0, $zero

dtd_epilogue:
    lw    $s3, 20($sp)
    lw    $s2, 24($sp)
    lw    $s1, 28($sp)
    lw    $s0, 32($sp)
    lw    $ra, 36($sp)
    addiu $sp, $sp, 40
    jr    $ra

# --------------------------------------------------------------
# Aliases (nomes esperados pelo main.asm)
# --------------------------------------------------------------
handle_dump_trans_cred:
    j handle_dump_trans_credito
    nop

handle_dump_trans_deb:
    j handle_dump_trans_debito
    nop
