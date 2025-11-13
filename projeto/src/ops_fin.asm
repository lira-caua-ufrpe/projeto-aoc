# ops_fin.asm — R2 (pagamentos) + R3 (registro de transações)
# Handlers:
#  - pagar_debito-<CONTA6>-<DV>-<VALORcentavos>
#  - pagar_credito-<CONTA6>-<DV>-<VALORcentavos>
#  - alterar_limite-<CONTA6>-<DV>-<NOVO_LIMcentavos>
#
# Regras R3: até 50 trans/debito e 50 trans/credito por cliente (ring buffer).

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
    nop

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
    nop

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
    nop
pd_val_end:
    # normaliza valor para múltiplo de 100
    li    $t0, 100
    divu  $t8, $t0
    mflo  $t1
    mul   $t8, $t1, 100

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
    # head
    la    $t4, trans_deb_head
    addu  $t4, $t4, $t0         # t0 = i*4
    lw    $t5, 0($t4)           # head (0..49)

    # slot
    move  $a0, $t1              # i
    move  $a1, $t5              # head
    jal   calc_off_i50k
    move  $t6, $v0              # offset em t6

    la    $t7, trans_deb_vals
    addu  $t7, $t7, $t6
    sw    $t8, 0($t7)           # grava valor

    # head = (head + 1) % 50
    addiu $t5, $t5, 1
    li    $t6, 50
    bne   $t5, $t6, pd_head_ok
    move  $t5, $zero
pd_head_ok:
    sw    $t5, 0($t4)

    # wptr = head
    la    $t7, trans_deb_wptr
    addu  $t7, $t7, $t0
    sw    $t5, 0($t7)

    # ===== SANITIZE count + min(count+1, 50) =====
    la    $t7, trans_deb_count
    addu  $t7, $t7, $t0
    lw    $t6, 0($t7)              # t6 = count atual (pode estar sujo)
    bltz  $t6, pd_cnt_zero         # se <0 -> zera
    li    $t9, 50
    sltu  $v1, $t6, $t9            # v1=1 se count < 50
    beq   $v1, $zero, pd_cnt_keep  # se >=50, mantém
pd_cnt_zero:
    move  $t6, $zero
pd_cnt_ok:
    # agora count é válido; incrementa até 50
    li    $t9, 50
    slt   $v1, $t6, $t9
    beq   $v1, $zero, pd_cnt_keep
    addiu $t6, $t6, 1
    sw    $t6, 0($t7)
pd_cnt_keep:

    # detalhado (débito)
    move  $a0, $t1          # índice do cliente (i)
    li    $a1, 0            # 0 = débito
    la    $a2, cc_buf_acc   # conta do comando
    move  $a3, $t8          # valor em centavos
    jal   adicionar_transacao_detalhe
    nop

    # ok
    li    $v0, 4
    la    $a0, msg_pay_deb_ok
    syscall
    li    $v0, 1
    j     pd_epilogue
    nop

pd_next_i:
    addiu $t1, $t1, 1
    j     pd_find_loop
    nop

pd_not_found:
    li    $v0, 4
    la    $a0, msg_err_cli_inexist
    syscall
    li    $v0, 1
    j     pd_epilogue
    nop

pd_saldo_insuf:
    li    $v0, 4
    la    $a0, msg_err_saldo_insuf
    syscall
    li    $v0, 1
    j     pd_epilogue
    nop

pd_badfmt:
    li    $v0, 4
    la    $a0, msg_cc_badfmt
    syscall
    li    $v0, 1
    j     pd_epilogue
    nop

pd_not_mine:
    move  $v0, $zero

pd_epilogue:
    lw    $s2, 16($sp)
    lw    $s1, 20($sp)
    lw    $s0, 24($sp)
    lw    $ra, 28($sp)
    addiu $sp, $sp, 32
    jr    $ra
    nop

# ------------------------------------------------------------
# pagar_credito
# ------------------------------------------------------------
handle_pagar_credito:
    addiu $sp, $sp, -32
    sw    $ra, 28($sp)
    sw    $s0, 24($sp)    # índice do cliente
    sw    $s1, 20($sp)    # DV
    sw    $s2, 16($sp)    # (livre)

    # prefixo "pagar_credito-"
    move  $t0, $a0
    la    $t1, str_cmd_pay_credito
pc_pref_loop:
    lb    $t2, 0($t1)
    beq   $t2, $zero, pc_pref_ok
    lb    $t3, 0($t0)
    bne   $t2, $t3, pc_not_mine
    addi  $t1, $t1, 1
    addi  $t0, $t0, 1
    j     pc_pref_loop
    nop

pc_pref_ok:
    # conta (6 dígitos)
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
    li    $t7, 88           # 'X'
    beq   $s1, $t7, pc_dv_ok
    blt   $s1, 48, pc_badfmt
    bgt   $s1, 57, pc_badfmt
pc_dv_ok:

    # '-'
    lb    $t6, 0($t0)
    li    $t7, 45
    bne   $t6, $t7, pc_badfmt
    addi  $t0, $t0, 1

    # valor -> $t8
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
    nop
pc_val_end:
    # zera centavos lixo
    li    $t0, 100
    divu  $t8, $t0
    mflo  $t1
    mul   $t8, $t1, 100       # agora $t8 é 20000, 50000, etc.

    # ===== procurar cliente =====
    lw    $t9, MAX_CLIENTS
    li    $s0, 0              # s0 = índice
pc_find_loop:
    beq   $s0, $t9, pc_not_found

    # usado?
    la    $t2, clientes_usado
    addu  $t2, $t2, $s0
    lb    $t3, 0($t2)
    beq   $t3, $zero, pc_next_i

    # compara conta(6)
    la    $t4, clientes_conta
    li    $t5, 7
    mul   $t5, $s0, $t5       # s0 * 7
    addu  $t4, $t4, $t5       # &clientes_conta[s0]
    la    $t6, cc_buf_acc
    li    $t7, 0
pc_cmp6:
    lb    $t2, 0($t4)
    lb    $t3, 0($t6)
    bne   $t2, $t3, pc_next_i
    addi  $t4, $t4, 1
    addi  $t6, $t6, 1
    addi  $t7, $t7, 1
    blt   $t7, 6, pc_cmp6

    # compara DV
    la    $t4, clientes_dv
    addu  $t4, $t4, $s0
    lb    $t2, 0($t4)
    bne   $t2, $s1, pc_next_i

    # ======= ACHOU CLIENTE EM s0 =======
    # base word do cliente = s0 * 4
    sll   $t0, $s0, 2

    # limite
    la    $t1, clientes_limite_cent
    addu  $t1, $t1, $t0
    lw    $t2, 0($t1)           # t2 = limite

    # devido
    la    $t3, clientes_devido_cent
    addu  $t3, $t3, $t0
    lw    $t4, 0($t3)           # t4 = devido
    # normaliza dívida já existente
    li    $t5, 100
    divu  $t4, $t5
    mflo  $t6
    mul   $t4, $t6, 100         # múltiplo de 100

    # checa limite: (limite - devido) >= valor ?
    subu  $t6, $t2, $t4
    sltu  $t7, $t6, $t8
    bne   $t7, $zero, pc_lim_insuf

    # devido += valor
    addu  $t4, $t4, $t8
    sw    $t4, 0($t3)

    # ===== registrar transação de crédito =====
    # bloco do cliente (200 bytes = 50*4)
    li    $t1, 200
    mul   $t2, $s0, $t1        # t2 = s0 * 200
    la    $t3, trans_cred_vals
    addu  $t3, $t3, $t2        # base do bloco

    # head desse cliente
    la    $t4, trans_cred_head
    sll   $t5, $s0, 2
    addu  $t4, $t4, $t5
    lw    $t6, 0($t4)          # t6 = head (0..49)

    # endereço do slot
    sll   $t7, $t6, 2          # head * 4
    addu  $t7, $t3, $t7
    sw    $t8, 0($t7)          # grava valor

    # atualiza head = (head+1)%50
    addiu $t6, $t6, 1
    li    $t7, 50
    bne   $t6, $t7, pc_head_ok
    move  $t6, $zero
pc_head_ok:
    sw    $t6, 0($t4)

    # wptr = head
    la    $t7, trans_cred_wptr
    addu  $t7, $t7, $t5
    sw    $t6, 0($t7)

    # ===== SANITIZE count + min(count+1, 50) =====
    la    $t7, trans_cred_count
    addu  $t7, $t7, $t5
    lw    $t9, 0($t7)              # t9 = count atual (pode estar sujo)
    bltz  $t9, pc_cnt_zero         # se <0 -> zera
    li    $s2, 50
    sltu  $v1, $t9, $s2            # v1=1 se count < 50
    beq   $v1, $zero, pc_cnt_keep  # se >=50, mantém
pc_cnt_zero:
    move  $t9, $zero
pc_cnt_ok:
    # agora count é válido; incrementa até 50
    li    $s2, 50
    slt   $v1, $t9, $s2
    beq   $v1, $zero, pc_cnt_keep
    addiu $t9, $t9, 1
    sw    $t9, 0($t7)
pc_cnt_keep:

    # detalhado (crédito)
    move  $a0, $s0          # índice do cliente
    li    $a1, 1            # 1 = crédito
    la    $a2, cc_buf_acc   # conta do comando
    move  $a3, $t8          # valor em centavos
    jal   adicionar_transacao_detalhe
    nop

    # mensagem ok
    li    $v0, 4
    la    $a0, msg_pay_cred_ok
    syscall
    li    $v0, 1
    j     pc_epilogue
    nop

pc_next_i:
    addi  $s0, $s0, 1
    j     pc_find_loop
    nop

pc_not_found:
    li    $v0, 4
    la    $a0, msg_err_cli_inexist
    syscall
    li    $v0, 1
    j     pc_epilogue
    nop

pc_lim_insuf:
    li    $v0, 4
    la    $a0, msg_err_limite_insuf
    syscall
    li    $v0, 1
    j     pc_epilogue
    nop

pc_badfmt:
    li    $v0, 4
    la    $a0, msg_cc_badfmt
    syscall
    li    $v0, 1
    j     pc_epilogue
    nop

pc_not_mine:
    move  $v0, $zero

pc_epilogue:
    lw    $s2, 16($sp)
    lw    $s1, 20($sp)
    lw    $s0, 24($sp)
    lw    $ra, 28($sp)
    addiu $sp, $sp, 32
    jr    $ra
    nop

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
    nop

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
    nop
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
    nop

al_next_i:
    addiu $t1, $t1, 1
    j     al_find_loop
    nop

al_not_found:
    li    $v0, 4
    la    $a0, msg_err_cli_inexist
    syscall
    li    $v0, 1
    j     al_done
    nop

al_baixo:
    li    $v0, 4
    la    $a0, msg_limite_baixo_divida
    syscall
    li    $v0, 1
    j     al_done
    nop

al_badfmt:
    li    $v0, 4
    la    $a0, msg_cc_badfmt
    syscall
    li    $v0, 1
    j     al_done
    nop

al_not_mine:
    move  $v0, $zero

al_done:
    lw    $s1, 12($sp)
    lw    $s0, 16($sp)
    lw    $ra, 20($sp)
    addiu $sp, $sp, 24
    jr    $ra
    nop

################################################################
# DEBUG R3: Dump de transações (CRÉDITO / DÉBITO)
################################################################

.data
dump_hdr_cred: .asciiz "LOG credito (50 posicoes, mais antigo -> mais novo)\n"
dump_hdr_deb:  .asciiz "LOG debito  (50 posicoes, mais antigo -> mais novo)
"

# Aceita ambos os prefixos (evita mismatch com main/help)
#  - "dump_cred-" e "dump_trans-cred-"
#  - "dump_deb-"  e "dump_trans-deb-"
str_dump_cred_local:       .asciiz "dump_cred-"
str_dump_trans_cred_local: .asciiz "dump_trans-cred-"
str_dump_deb_local:        .asciiz "dump_deb-"
str_dump_trans_deb_local:  .asciiz "dump_trans-deb-"

.text

# --------------------------------------------------------------
# handle_dump_trans_credito(a0=inp_buf) -> v0=1 tratou, 0 nao
# --------------------------------------------------------------
handle_dump_trans_credito:
    addiu $sp, $sp, -40
    sw    $ra, 36($sp)
    sw    $s0, 32($sp)
    sw    $s1, 28($sp)
    sw    $s2, 24($sp)
    sw    $s3, 20($sp)

    move  $t8, $a0                  # salva ptr original
    # tenta 1) dump_cred-  2) dump_trans-cred-
    move  $t0, $a0
    la    $t1, str_dump_cred_local
    move  $t9, $zero                # 0 = estamos no 1o prefixo; 1 = já tentamos o alternativo

dtc_pref:
    lb    $t2, 0($t1)
    beq   $t2, $zero, dtc_pref_ok   # terminou prefixo -> ok
    lb    $t3, 0($t0)
    beq   $t2, $t3, dtc_pref_adv
    # mismatch -> se ainda não tentamos o alternativo, troca prefixo e recomeça
    bne   $t9, $zero, dtc_not_mine
    li    $t9, 1
    move  $t0, $t8
    la    $t1, str_dump_trans_cred_local
    j     dtc_pref
    nop

dtc_pref_adv:
    addi  $t1, $t1, 1
    addi  $t0, $t0, 1
    j     dtc_pref
    nop

dtc_pref_ok:
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
    lb    $t6, 0($t0)
    li    $t7, 45
    bne   $t6, $t7, dtc_badfmt
    addi  $t0, $t0, 1

    lb    $s1, 0($t0)
    addi  $t0, $t0, 1
    li    $t7, 88
    beq   $s1, $t7, dtc_dv_ok
    blt   $s1, 48, dtc_badfmt
    bgt   $s1, 57, dtc_badfmt
dtc_dv_ok:

    lw    $t9, MAX_CLIENTS
    move  $s0, $zero
dtc_find:
    beq   $s0, $t9, dtc_not_found

    la    $a0, clientes_usado
    addu  $a0, $a0, $s0
    lb    $a1, 0($a0)
    beq   $a1, $zero, dtc_next

    la    $a2, clientes_conta
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

    li    $v0, 4
    la    $a0, dump_hdr_cred
    syscall

    la    $s2, trans_cred_vals
    li    $t0, 200
    mul   $t1, $s0, $t0
    addu  $s2, $s2, $t1

    la    $t2, trans_cred_wptr
    sll   $t3, $s0, 2
    addu  $t2, $t2, $t3
    lw    $s3, 0($t2)

    li    $t4, 0
dtc_loop:
    li    $t5, 50
    beq   $t4, $t5, dtc_done

    addu  $t6, $s3, $t4
    sltiu $t7, $t6, 50
    bne   $t7, $zero, dtc_idx_ok
    addi  $t6, $t6, -50
dtc_idx_ok:
    sll   $t6, $t6, 2
    addu  $t8, $s2, $t6
    lw    $a0, 0($t8)

    li    $v0, 1
    syscall
    li    $v0, 11
    li    $a0, 10
    syscall

    addi  $t4, $t4, 1
    j     dtc_loop
    nop

dtc_done:
    li    $v0, 1
    j     dtc_epilogue
    nop

dtc_next:
    addi  $s0, $s0, 1
    j     dtc_find
    nop

dtc_not_found:
    li    $v0, 4
    la    $a0, msg_err_cli_inexist
    syscall
    li    $v0, 1
    j     dtc_epilogue
    nop

dtc_badfmt:
    li    $v0, 4
    la    $a0, msg_cc_badfmt
    syscall
    li    $v0, 1
    j     dtc_epilogue
    nop

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
    nop

# --------------------------------------------------------------
# handle_dump_trans_debito(a0=inp_buf) -> v0=1 tratou, 0 nao
# --------------------------------------------------------------
handle_dump_trans_debito:
    addiu $sp, $sp, -40
    sw    $ra, 36($sp)
    sw    $s0, 32($sp)
    sw    $s1, 28($sp)
    sw    $s2, 24($sp)
    sw    $s3, 20($sp)

    move  $t8, $a0
    # tenta 1) dump_deb-  2) dump_trans-deb-
    move  $t0, $a0
    la    $t1, str_dump_deb_local
    move  $t9, $zero

dtd_pref:
    lb    $t2, 0($t1)
    beq   $t2, $zero, dtd_pref_ok
    lb    $t3, 0($t0)
    beq   $t2, $t3, dtd_pref_adv
    bne   $t9, $zero, dtd_not_mine
    li    $t9, 1
    move  $t0, $t8
    la    $t1, str_dump_trans_deb_local
    j     dtd_pref
    nop

dtd_pref_adv:
    addi  $t1, $t1, 1
    addi  $t0, $t0, 1
    j     dtd_pref
    nop

dtd_pref_ok:
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
    lb    $t6, 0($t0)
    li    $t7, 45
    bne   $t6, $t7, dtd_badfmt
    addi  $t0, $t0, 1

    lb    $s1, 0($t0)
    addi  $t0, $t0, 1
    li    $t7, 88
    beq   $s1, $t7, dtd_dv_ok
    blt   $s1, 48, dtd_badfmt
    bgt   $s1, 57, dtd_badfmt

dtd_dv_ok:

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
    lw    $s3, 0($t2)

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
    nop

dtd_done:
    li    $v0, 1
    j     dtd_epilogue
    nop

dtd_next:
    addi  $s0, $s0, 1
    j     dtd_find
    nop

dtd_not_found:
    li    $v0, 4
    la    $a0, msg_err_cli_inexist
    syscall
    li    $v0, 1
    j     dtd_epilogue
    nop

dtd_badfmt:
    li    $v0, 4
    la    $a0, msg_cc_badfmt
    syscall
    li    $v0, 1
    j     dtd_epilogue
    nop

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
    nop

# --------------------------------------------------------------
# Aliases (nomes esperados pelo main.asm)
# --------------------------------------------------------------
handle_dump_trans_cred:
    j handle_dump_trans_credito
    nop

handle_dump_trans_deb:
    j handle_dump_trans_debito
    nop
    
# =============================================================
# R7 - Juros automáticos (1% a cada 60s) e registro no ring CRED
# Aplica somente quando curr_sec == 0 e uma única vez por minuto.
# - Para cada cliente usado:
#     se devido > 0: juros = devido/100 (1% arred. para baixo)
#     se juros > 0: soma no devido e registra no ring de CRED
# =============================================================
.text
.globl aplicar_juros_auto

aplicar_juros_auto:
    addiu $sp, $sp, -32
    sw    $ra, 28($sp)
    sw    $s0, 24($sp)
    sw    $s1, 20($sp)
    sw    $s2, 16($sp)
    sw    $s3, 12($sp)
    sw    $s4,  8($sp)

    # dispara só no segundo 0 e uma única vez por minuto
    lw    $t0, curr_sec
    bne   $t0, $zero, .sec_not_zero
    nop
    lw    $t1, juros_gate
    bne   $t1, $zero, .done        # já aplicou neste "segundo 0"
    li    $t1, 1
    sw    $t1, juros_gate
    j     .apply_all
    nop

.sec_not_zero:
    sw    $zero, juros_gate        # destrava quando não está no segundo 0
    j     .done
    nop

.apply_all:
    lw    $t9, MAX_CLIENTS         # N clientes
    lw    $s4, TRANS_MAX           # CAP do ring (50)
    li    $s0, 0                   # i = 0

.loop_i:
    beq   $s0, $t9, .done          # fim

    # if (!clientes_usado[i]) goto next
    la    $t2, clientes_usado
    addu  $t2, $t2, $s0
    lb    $t3, 0($t2)
    beq   $t3, $zero, .next_i

    # devido = clientes_devido_cent[i]
    sll   $t0, $s0, 2
    la    $t1, clientes_devido_cent
    addu  $t1, $t1, $t0
    lw    $t4, 0($t1)              # t4 = devido (centavos)
    blez  $t4, .next_i             # sem dívida => pula

    # juros = devido/100 (1%). Se cair em 0, não registra (evita "R$ 0,01" fantasma)
    li    $t5, 100
    divu  $t4, $t5
    mflo  $t6                      # t6 = juros
    beq   $t6, $zero, .next_i

    # devido += juros
    addu  $t4, $t4, $t6
    sw    $t4, 0($t1)

    # ---------- registrar no ring de CRED ----------
    # head,count
    la    $t7, trans_cred_head
    addu  $t7, $t7, $t0
    lw    $s1, 0($t7)              # s1 = head

    la    $t8, trans_cred_count
    addu  $t8, $t8, $t0
    lw    $s2, 0($t8)              # s2 = count

    # tail = (head + count) % CAP
    addu  $t3, $s1, $s2
    divu  $t3, $s4
    mfhi  $t3                      # t3 = tail

    # linear = i*CAP + tail
    mul   $t2, $s0, $s4
    addu  $t2, $t2, $t3
    sll   $t2, $t2, 2              # byte offset

    la    $a3, trans_cred_vals
    addu  $a3, $a3, $t2
    sw    $t6, 0($a3)              # grava "juros" como transação CRED

    # atualizar count/head
    sltu  $t5, $s2, $s4            # count < CAP ?
    beq   $t5, $zero, .buf_full
    nop
    addiu $s2, $s2, 1
    sw    $s2, 0($t8)
    j     .next_i
    nop

.buf_full:
    # overrun: anda o head
    addiu $s1, $s1, 1
    divu  $s1, $s4
    mfhi  $s1
    sw    $s1, 0($t7)
    # count permanece CAP

.next_i:
    addiu $s0, $s0, 1
    j     .loop_i
    nop

.done:
    lw    $s4,  8($sp)
    lw    $s3, 12($sp)
    lw    $s2, 16($sp)
    lw    $s1, 20($sp)
    lw    $s0, 24($sp)
    lw    $ra, 28($sp)
    addiu $sp, $sp, 32
    jr    $ra
    nop

