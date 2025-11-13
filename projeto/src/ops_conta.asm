# ops_conta.asm — handler de conta_cadastrar-<CPF>-<CONTA6>-<NOME>

        .text
        .globl  handle_conta_cadastrar

# handle_conta_cadastrar(a0=inp_buf) -> v0=1 se tratou (sucesso/erro), 0 se não era esse comando
handle_conta_cadastrar:
    # --- PRÓLOGO ---
    addiu $sp, $sp, -32
    sw    $ra, 28($sp)
    sw    $s0, 24($sp)
    sw    $s1, 20($sp)
    sw    $s2, 16($sp)

    # compara prefixo "conta_cadastrar-"
    move  $t0, $a0
    la    $t1, str_cmd_cc_prefix
cc_pref_loop:
    lb    $t2, 0($t1)
    beq   $t2, $zero, cc_pref_ok
    lb    $t3, 0($t0)
    bne   $t2, $t3, cc_not_mine
    addiu $t1, $t1, 1
    addiu $t0, $t0, 1
    j     cc_pref_loop

cc_pref_ok:
    # -------- CPF (11 dígitos) até '-' --------
    la    $t4, cc_buf_cpf
    li    $t5, 0
cc_cpf_loop:
    lb    $t6, 0($t0)
    beq   $t6, $zero, cc_badfmt
    beq   $t6, 45,   cc_cpf_end          # '-'
    blt   $t6, 48,   cc_badcpf           # < '0'
    bgt   $t6, 57,   cc_badcpf           # > '9'
    sb    $t6, 0($t4)
    addiu $t4, $t4, 1
    addiu $t0, $t0, 1
    addiu $t5, $t5, 1
    blt   $t5, 11,   cc_cpf_loop
    lb    $t6, 0($t0)                     # se tem mais que 11 antes de '-'
    bne   $t6, 45,   cc_badcpf
cc_cpf_end:
    sb    $zero, 0($t4)
    li    $t7, 11
    bne   $t5, $t7,  cc_badcpf
    addiu $t0, $t0, 1                     # pula '-'

    # -------- CONTA (6 dígitos) até '-' --------
    la    $t4, cc_buf_acc
    li    $t5, 0
cc_acc_loop:
    lb    $t6, 0($t0)
    beq   $t6, $zero, cc_badfmt
    beq   $t6, 45,   cc_acc_end
    blt   $t6, 48,   cc_badacc
    bgt   $t6, 57,   cc_badacc
    sb    $t6, 0($t4)
    addiu $t4, $t4, 1
    addiu $t0, $t0, 1
    addiu $t5, $t5, 1
    blt   $t5, 6,    cc_acc_loop
    lb    $t6, 0($t0)
    bne   $t6, 45,   cc_badacc
cc_acc_end:
    sb    $zero, 0($t4)
    li    $t7, 6
    bne   $t5, $t7,  cc_badacc
    addiu $t0, $t0, 1                # pula '-'

    # -------- NOME (trim left; máx 32) --------
cc_name_trim:
    lb    $t6, 0($t0)
    beq   $t6, $zero, cc_badname
    li    $t7, 32
    bne   $t6, $t7,  cc_name_copy
    addiu $t0, $t0, 1
    j     cc_name_trim

cc_name_copy:
    la    $t4, cc_buf_nome
    li    $t5, 0
cc_name_loop:
    lb    $t6, 0($t0)
    beq   $t6, $zero, cc_name_end
    sb    $t6, 0($t4)
    addiu $t4, $t4, 1
    addiu $t0, $t0, 1
    addiu $t5, $t5, 1
    blt   $t5, 32, cc_name_loop
    j     cc_badname                 # estourou 32
cc_name_end:
    sb    $zero, 0($t4)
    beq   $t5, $zero, cc_badname

    # -------- Calcula DV (mod11 pesos 2..7, d0 = menos significativo) --------
    la    $t0, cc_buf_acc
    addiu $t0, $t0, 5        # aponta pro último dígito
    li    $t1, 2             # peso
    move  $t2, $zero         # soma
    li    $t3, 6             # contador
cc_dv_loop:
    lb    $t4, 0($t0)
    addiu $t4, $t4, -48      # ascii -> int
    mul   $t4, $t4, $t1
    addu  $t2, $t2, $t4
    addiu $t1, $t1, 1
    addiu $t0, $t0, -1
    addiu $t3, $t3, -1
    bgtz  $t3, cc_dv_loop
    li    $t5, 11
    divu  $t2, $t5
    mfhi  $t6                 # resto
    li    $t7, 10
    beq   $t6, $t7, cc_dv_x
    addiu $t6, $t6, 48        # '0'..'9'
    j     cc_dv_done
cc_dv_x:
    li    $t6, 'X'
cc_dv_done:
    move  $s1, $t6            # DV ascii

    # -------- Checa duplicidades e encontra vaga --------
    lw    $t8, MAX_CLIENTS    # N
    li    $s2, -1             # idx livre = -1
    li    $t9, 0              # i = 0

cc_scan_loop:
    beq   $t9, $t8, cc_scan_end

    # usado?
    la    $a0, clientes_usado
    addu  $a0, $a0, $t9
    lb    $a1, 0($a0)
    beq   $a1, $zero, cc_maybe_free

    # compara CPF
    li    $a2, 12
    la    $a0, clientes_cpf
    mul   $a3, $t9, $a2
    addu  $a0, $a0, $a3
    la    $a1, cc_buf_cpf
    jal   strcmp
    # nop
    beq   $v0, $zero, cc_dup_cpf

    # compara CONTA (6 chars)
    li    $a2, 7
    la    $t0, clientes_conta
    mul   $a3, $t9, $a2
    addu  $t0, $t0, $a3
    la    $t1, cc_buf_acc
    li    $t2, 0
cc_cmp6:
    lb    $t3, 0($t0)
    lb    $t4, 0($t1)
    bne   $t3, $t4, cc_next_slot
    addiu $t0, $t0, 1
    addiu $t1, $t1, 1
    addiu $t2, $t2, 1
    blt   $t2, 6, cc_cmp6
    j     cc_dup_acc

cc_maybe_free:
    bltz  $s2, cc_save_free
    j     cc_next_slot
cc_save_free:
    move  $s2, $t9

cc_next_slot:
    addiu $t9, $t9, 1
    j     cc_scan_loop

cc_scan_end:
    bltz  $s2, cc_full

    # -------- Escreve no índice s2 --------
    # ponteiros base
    la    $t0, clientes_usado
    la    $t1, clientes_cpf
    la    $t2, clientes_conta
    la    $t3, clientes_dv
    la    $t4, clientes_nome
    la    $t5, clientes_saldo_cent
    la    $t6, clientes_limite_cent
    la    $t7, clientes_devido_cent

    # offsets
    addu  $t0, $t0, $s2              # usado + s2
    li    $a0, 12
    mul   $a1, $s2, $a0
    addu  $t1, $t1, $a1              # cpf + s2*12
    li    $a0, 7
    mul   $a1, $s2, $a0
    addu  $t2, $t2, $a1              # conta + s2*7
    addu  $t3, $t3, $s2              # dv + s2
    li    $a0, 33
    mul   $a1, $s2, $a0
    addu  $t4, $t4, $a1              # nome + s2*33
    sll   $a1, $s2, 2                # *4
    addu  $t5, $t5, $a1              # saldo + s2*4
    addu  $t6, $t6, $a1              # limite + s2*4
    addu  $t7, $t7, $a1              # devido + s2*4

    # grava
    li    $a0, 1
    sb    $a0, 0($t0)                # usado=1

    la    $a0, cc_buf_cpf
    move  $a1, $t1
    jal   strcpy
    # nop

    la    $a0, cc_buf_acc
    move  $a1, $t2
    jal   strcpy
    # nop

    sb    $s1, 0($t3)                # DV

    la    $a0, cc_buf_nome
    move  $a1, $t4
    jal   strcpy
    # nop

    sw    $zero, 0($t5)              # saldo = 0
    lw    $a0, LIMITE_PADRAO_CENT
    sw    $a0, 0($t6)                # limite = padrão
    sw    $zero, 0($t7)              # devido = 0

    # sucesso
    li    $v0, 4
    la    $a0, msg_cc_ok
    syscall
    li    $v0, 4
    move  $a0, $t2                   # conta (string de 6 dígitos)
    syscall
    li    $v0, 11
    li    $a0, '-'                   # hífen
    syscall
    li    $v0, 11
    move  $a0, $s1                   # DV (char)
    syscall
    li    $v0, 11
    li    $a0, 10                    # '\n'
    syscall

    li    $v0, 1
    j     cc_epilogue

# ---- erros/duplicidades ----
cc_dup_cpf:
    li    $v0, 4
    la    $a0, msg_cc_cpf_exists
    syscall
    li    $v0, 1
    j     cc_epilogue

cc_dup_acc:
    li    $v0, 4
    la    $a0, msg_cc_acc_exists
    syscall
    li    $v0, 1
    j     cc_epilogue

cc_full:
    li    $v0, 4
    la    $a0, msg_cc_full
    syscall
    li    $v0, 1
    j     cc_epilogue

cc_badfmt:
    li    $v0, 4
    la    $a0, msg_cc_badfmt
    syscall
    li    $v0, 1
    j     cc_epilogue

cc_badcpf:
    li    $v0, 4
    la    $a0, msg_cc_badcpf
    syscall
    li    $v0, 1
    j     cc_epilogue

cc_badacc:
    li    $v0, 4
    la    $a0, msg_cc_badacc
    syscall
    li    $v0, 1
    j     cc_epilogue

cc_badname:
    li    $v0, 4
    la    $a0, msg_cc_badname
    syscall
    li    $v0, 1
    j     cc_epilogue

cc_not_mine:
    move  $v0, $zero
    j     cc_epilogue

# --- EPÍLOGO COMUM ---
cc_epilogue:
    lw    $s2, 16($sp)
    lw    $s1, 20($sp)
    lw    $s0, 24($sp)
    lw    $ra, 28($sp)
    addiu $sp, $sp, 32
    jr    $ra


# ============================================================
# buscar_cliente_por_conta_completa
# a0 = endereço da string "XXXXXX-D"
# v0 = índice do cliente (0..49) ou -1 se não achar
# ============================================================
        .globl  buscar_cliente_por_conta_completa
buscar_cliente_por_conta_completa:
    addiu $sp, $sp, -32
    sw    $ra, 28($sp)
    sw    $s0, 24($sp)   # i
    sw    $s1, 20($sp)   # ptr conta[i]
    sw    $s2, 16($sp)   # ptr buffer
    sw    $s3, 12($sp)   # dv cliente
    sw    $s4,  8($sp)   # used

    move  $s2, $a0               # buffer "123456-0"

    # max = MAX_CLIENTS
    la    $t0, MAX_CLIENTS
    lw    $t0, 0($t0)            # t0 = 50
    li    $s0, 0                 # i = 0

bccc_loop_i:
    beq   $s0, $t0, bccc_not_found  # acabou

    # usado?
    la    $t1, clientes_usado
    addu  $t1, $t1, $s0
    lb    $s4, 0($t1)
    beq   $s4, $zero, bccc_next_i   # não usado, pula

    # ptr conta[i] = clientes_conta + i*7
    la    $s1, clientes_conta
    li    $t2, 7
    mul   $t3, $s0, $t2
    addu  $s1, $s1, $t3

    # compara 6 dígitos
    li    $t4, 0                  # k = 0
bccc_cmp6:
    li    $t5, 6
    beq   $t4, $t5, bccc_cmp_dash
    lb    $t6, 0($s1)
    lb    $t7, 0($s2)
    bne   $t6, $t7, bccc_next_i
    addiu $s1, $s1, 1
    addiu $s2, $s2, 1
    addiu $t4, $t4, 1
    j     bccc_cmp6

bccc_cmp_dash:
    # buffer está agora no '-', garante que é '-'
    lb    $t6, 0($s2)
    li    $t7, 45           # '-'
    bne   $t6, $t7, bccc_next_reset
    # avança pro DV do buffer
    addiu $s2, $s2, 1

    # DV do cliente
    la    $t8, clientes_dv
    addu  $t8, $t8, $s0
    lb    $s3, 0($t8)

    # compara DV
    lb    $t9, 0($s2)       # dv do buffer
    bne   $s3, $t9, bccc_next_reset

    # achou!
    move  $v0, $s0
    j     bccc_end

# restaurar o ponteiro do buffer antes de ir pro próximo i
bccc_next_reset:
    # buffer original = a0
    move  $s2, $a0

bccc_next_i:
    addiu $s0, $s0, 1
    j     bccc_loop_i

bccc_not_found:
    li    $v0, -1

bccc_end:
    lw    $s4,  8($sp)
    lw    $s3, 12($sp)
    lw    $s2, 16($sp)
    lw    $s1, 20($sp)
    lw    $s0, 24($sp)
    lw    $ra, 28($sp)
    addiu $sp, $sp, 32
    jr    $ra
