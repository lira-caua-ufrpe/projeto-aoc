# ops_conta.asm — handlers de comandos de conta (conta_cadastrar)
# Depende de:
#   - data.asm: MAX_CLIENTS, buffers/estruturas e mensagens
#   - strings.asm: strcmp, strncmp, is_all_digits_fixed

.text
.globl handle_conta_cadastrar

# ------------------------------------------------------------
# strcpy(a0=src, a1=dst) -> v0=dst
# Copia até e incluindo '\0'. Se src==NULL, grava string vazia.
# ------------------------------------------------------------
strcpy:
    move $v0, $a1
    beq  $a1, $zero, sc_end
    beq  $a0, $zero, sc_zero
sc_loop:
    lb   $t0, 0($a0)
    sb   $t0, 0($a1)
    addi $a0, $a0, 1
    addi $a1, $a1, 1
    bne  $t0, $zero, sc_loop
    jr   $ra
sc_zero:
    sb   $zero, 0($a1)
sc_end:
    jr   $ra

# ============================================================
# handle_conta_cadastrar(a0=inp_buf) -> v0=1 se tratou, 0 se não
# Formato:
#   conta_cadastrar-<CPF11>-<CONTA6>-<NOME...>
# ============================================================
handle_conta_cadastrar:
    # prologue (não-folha: usa $s0..$s2 e chama funções)
    addiu $sp, $sp, -16
    sw    $ra, 12($sp)
    sw    $s0, 8($sp)
    sw    $s1, 4($sp)
    sw    $s2, 0($sp)

    beq  $a0, $zero, cc_not_mine_ret

    # --- compara prefixo "conta_cadastrar-" sem tamanho fixo ---
    move $t0, $a0              # p = buf
    la   $t1, str_cmd_cc_prefix
cc_cmp_pre:
    lb   $t3, 0($t0)           # char da entrada
    lb   $t4, 0($t1)           # char do prefixo
    beq  $t4, $zero, cc_prefix_ok
    bne  $t3, $t4, cc_not_mine_ret
    addi $t0, $t0, 1
    addi $t1, $t1, 1
    j    cc_cmp_pre

cc_prefix_ok:
    # $t0 já aponta para o 1º char após "conta_cadastrar-"
    move $s0, $t0

    # ---------- CPF ----------
    la   $t5, cc_buf_cpf
    li   $t6, 0
cc_cpf_loop:
    lb   $t7, 0($s0)
    beq  $t7, $zero, cc_badfmt_ret
    beq  $t7, '-',   cc_cpf_end
    sb   $t7, 0($t5)
    addi $t5, $t5, 1
    addi $s0, $s0, 1
    addi $t6, $t6, 1
    blt  $t6, 12, cc_cpf_loop
    j    cc_badfmt_ret
cc_cpf_end:
    sb   $zero, 0($t5)
    addi $s0, $s0, 1
    li   $t8, 11
    bne  $t6, $t8, cc_badcpf_ret
    la   $a0, cc_buf_cpf
    li   $a1, 11
    jal  is_all_digits_fixed
    beq  $v0, $zero, cc_badcpf_ret

    # ---------- CONTA (6) ----------
    la   $t5, cc_buf_acc
    li   $t6, 0
cc_acc_loop:
    lb   $t7, 0($s0)
    beq  $t7, $zero, cc_badfmt_ret
    beq  $t7, '-',   cc_acc_end
    sb   $t7, 0($t5)
    addi $t5, $t5, 1
    addi $s0, $s0, 1
    addi $t6, $t6, 1
    blt  $t6, 7, cc_acc_loop
    j    cc_badfmt_ret
cc_acc_end:
    sb   $zero, 0($t5)
    addi $s0, $s0, 1
    li   $t8, 6
    bne  $t6, $t8, cc_badacc_ret
    la   $a0, cc_buf_acc
    li   $a1, 6
    jal  is_all_digits_fixed
    beq  $v0, $zero, cc_badacc_ret

    # ---------- NOME (trim left, máx 32) ----------
cc_name_trim:
    lb   $t7, 0($s0)
    beq  $t7, $zero, cc_badname_ret
    li   $t8, 32
    bne  $t7, $t8, cc_name_copy
    addi $s0, $s0, 1
    j    cc_name_trim
cc_name_copy:
    la   $t5, cc_buf_nome
    li   $t6, 0
cc_name_loop:
    lb   $t7, 0($s0)
    beq  $t7, $zero, cc_name_end
    sb   $t7, 0($t5)
    addi $t5, $t5, 1
    addi $s0, $s0, 1
    addi $t6, $t6, 1
    blt  $t6, 33, cc_name_loop
    j    cc_badname_ret
cc_name_end:
    sb   $zero, 0($t5)
    beq  $t6, $zero, cc_badname_ret

    # ---------- DV ----------
    la   $t0, cc_buf_acc
    addi $t0, $t0, 5
    li   $t1, 2
    move $t2, $zero
    li   $t9, 6
cc_dv_loop:
    lb   $t3, 0($t0)
    addi $t3, $t3, -48
    mul  $t4, $t3, $t1
    addu $t2, $t2, $t4
    addi $t1, $t1, 1
    addi $t0, $t0, -1
    addi $t9, $t9, -1
    bgtz $t9, cc_dv_loop
    li   $t5, 11
    divu $t2, $t5
    mfhi $t6
    li   $t7, 10
    beq  $t6, $t7, cc_dv_isx
    addi $t6, $t6, 48
    j    cc_dv_done
cc_dv_isx:
    li   $t6, 'X'
cc_dv_done:
    move $s1, $t6

    # ---------- scan tabela ----------
    la   $s7, MAX_CLIENTS
    lw   $t8, 0($s7)

    la   $t0, clientes_usado
    la   $t1, clientes_cpf
    la   $t2, clientes_conta
    la   $t3, clientes_dv
    la   $t4, clientes_nome
    la   $t5, clientes_saldo_cent
    la   $t6, clientes_limite_cent
    la   $t7, clientes_devido_cent

    li   $s2, -1
    move $t9, $zero
cc_scan_loop:
    beq  $t9, $t8, cc_scan_end

    lb   $a0, 0($t0)
    beq  $a0, $zero, cc_mark_free

    move $a0, $t1
    la   $a1, cc_buf_cpf
    jal  strcmp
    beq  $v0, $zero, cc_dup_cpf_ret

    move $a0, $t2
    la   $a1, cc_buf_acc
    li   $a3, 6
    jal  strncmp
    beq  $v0, $zero, cc_dup_acc_ret

    j    cc_next_slot

cc_mark_free:
    bltz $s2, cc_save_free
    j    cc_next_slot
cc_save_free:
    move $s2, $t9

cc_next_slot:
    addi $t0, $t0, 1
    addi $t1, $t1, 12
    addi $t2, $t2, 7
    addi $t3, $t3, 1
    addi $t4, $t4, 33
    addi $t5, $t5, 4
    addi $t6, $t6, 4
    addi $t7, $t7, 4
    addi $t9, $t9, 1
    j    cc_scan_loop

cc_scan_end:
    bltz $s2, cc_full_ret

    # Reposiciona ponteiros base + offset(idx)
    la   $t0, clientes_usado
    la   $t1, clientes_cpf
    la   $t2, clientes_conta
    la   $t3, clientes_dv
    la   $t4, clientes_nome
    la   $t5, clientes_saldo_cent
    la   $t6, clientes_limite_cent
    la   $t7, clientes_devido_cent

    # usado: + idx
    addu $t0, $t0, $s2

    # cpf: + 12*idx
    li   $a0, 12
    mul  $a1, $s2, $a0
    addu $t1, $t1, $a1

    # conta: + 7*idx
    li   $a0, 7
    mul  $a1, $s2, $a0
    addu $t2, $t2, $a1

    # dv: + 1*idx
    addu $t3, $t3, $s2

    # nome: + 33*idx
    li   $a0, 33
    mul  $a1, $s2, $a0
    addu $t4, $t4, $a1

    # saldos/limites/devido: + 4*idx
    li   $a0, 4
    mul  $a1, $s2, $a0
    addu $t5, $t5, $a1
    addu $t6, $t6, $a1
    addu $t7, $t7, $a1

    # escreve registro
    li   $a0, 1
    sb   $a0, 0($t0)            # usado=1

    la   $a0, cc_buf_cpf        # cpf
    move $a1, $t1
    jal  strcpy

    la   $a0, cc_buf_acc        # conta
    move $a1, $t2
    jal  strcpy

    sb   $s1, 0($t3)            # dv

    la   $a0, cc_buf_nome       # nome
    move $a1, $t4
    jal  strcpy

    sw   $zero, 0($t5)          # saldo = 0
    la   $s7, LIMITE_PADRAO_CENT
    lw   $a0, 0($s7)
    sw   $a0, 0($t6)            # limite = padrão
    sw   $zero, 0($t7)          # devido = 0

    # mensagem de sucesso
    li   $v0, 4
    la   $a0, msg_cc_ok
    syscall
    li   $v0, 4
    move $a0, $t2               # conta
    syscall
    li   $v0, 11
    li   $a0, '-'
    syscall
    li   $v0, 11
    move $a0, $s1               # DV ascii
    syscall
    li   $v0, 11
    li   $a0, 10                # '\n'
    syscall

    li   $v0, 1                 # tratou
    # epilogue
    lw   $s2, 0($sp)
    lw   $s1, 4($sp)
    lw   $s0, 8($sp)
    lw   $ra, 12($sp)
    addiu $sp, $sp, 16
    jr   $ra

# ---- duplicidades ----
cc_dup_cpf_ret:
    li   $v0, 4
    la   $a0, msg_cc_cpf_exists
    syscall
    li   $v0, 1
    lw   $s2, 0($sp)
    lw   $s1, 4($sp)
    lw   $s0, 8($sp)
    lw   $ra, 12($sp)
    addiu $sp, $sp, 16
    jr   $ra
cc_dup_acc_ret:
    li   $v0, 4
    la   $a0, msg_cc_acc_exists
    syscall
    li   $v0, 1
    lw   $s2, 0($sp)
    lw   $s1, 4($sp)
    lw   $s0, 8($sp)
    lw   $ra, 12($sp)
    addiu $sp, $sp, 16
    jr   $ra
cc_full_ret:
    li   $v0, 4
    la   $a0, msg_cc_full
    syscall
    li   $v0, 1
    lw   $s2, 0($sp)
    lw   $s1, 4($sp)
    lw   $s0, 8($sp)
    lw   $ra, 12($sp)
    addiu $sp, $sp, 16
    jr   $ra

# ---- erros de parse/validacao ----
cc_badfmt_ret:
    li   $v0, 4
    la   $a0, msg_cc_badfmt
    syscall
    li   $v0, 1
    lw   $s2, 0($sp)
    lw   $s1, 4($sp)
    lw   $s0, 8($sp)
    lw   $ra, 12($sp)
    addiu $sp, $sp, 16
    jr   $ra
cc_badcpf_ret:
    li   $v0, 4
    la   $a0, msg_cc_badcpf
    syscall
    li   $v0, 1
    lw   $s2, 0($sp)
    lw   $s1, 4($sp)
    lw   $s0, 8($sp)
    lw   $ra, 12($sp)
    addiu $sp, $sp, 16
    jr   $ra
cc_badacc_ret:
    li   $v0, 4
    la   $a0, msg_cc_badacc
    syscall
    li   $v0, 1
    lw   $s2, 0($sp)
    lw   $s1, 4($sp)
    lw   $s0, 8($sp)
    lw   $ra, 12($sp)
    addiu $sp, $sp, 16
    jr   $ra
cc_badname_ret:
    li   $v0, 4
    la   $a0, msg_cc_badname
    syscall
    li   $v0, 1
    lw   $s2, 0($sp)
    lw   $s1, 4($sp)
    lw   $s0, 8($sp)
    lw   $ra, 12($sp)
    addiu $sp, $sp, 16
    jr   $ra

# ---- não era esse comando ----
cc_not_mine_ret:
    move $v0, $zero
    lw   $s2, 0($sp)
    lw   $s1, 4($sp)
    lw   $s0, 8($sp)
    lw   $ra, 12($sp)
    addiu $sp, $sp, 16
    jr   $ra
