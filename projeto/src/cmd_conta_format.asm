# cmd_conta_format.asm — conta_format-<CONTA6>-<DV>
# Zera meta e 50 valores de transações (débito/crédito) da conta informada.
# Depende de: strcmp, strncmp, print_str, read_line e símbolos de data.asm.

        .text
        .globl handle_conta_format

handle_conta_format:
    addiu $sp, $sp, -48
    sw    $ra, 44($sp)
    sw    $s0, 40($sp)
    sw    $s1, 36($sp)
    sw    $s2, 32($sp)
    sw    $s3, 28($sp)

    move  $s2, $a0                   # linha completa
    la    $a1, str_cmd_conta_format
    li    $a3, 13                    # "conta_format-" tem 13 chars
    move  $a0, $s2
    jal   strncmp
    nop
    bne   $v0, $zero, cfmt_notmine

    # ponteiro para XXXXXX-D
    addiu $s1, $s2, 13

    # --- copia 6 dígitos da conta para cc_buf_acc ---
    la    $t4, cc_buf_acc
    li    $t5, 6
cfmt_copy6:
    beq   $t5, $zero, cfmt_after6
    lb    $t0, 0($s1)
    li    $t1, 48
    blt   $t0, $t1, cfmt_badfmt
    li    $t1, 57
    bgt   $t0, $t1, cfmt_badfmt
    sb    $t0, 0($t4)
    addiu $t4, $t4, 1
    addiu $s1, $s1, 1
    addiu $t5, $t5, -1
    j     cfmt_copy6
cfmt_after6:
    sb    $zero, 0($t4)

    # hífen
    lb    $t0, 0($s1)
    li    $t1, '-'
    bne   $t0, $t1, cfmt_badfmt
    addiu $s1, $s1, 1

    # DV (1 dígito)
    lb    $t0, 0($s1)
    li    $t1, 48
    blt   $t0, $t1, cfmt_badfmt
    li    $t1, 57
    bgt   $t0, $t1, cfmt_badfmt
    la    $t2, cc_buf_dv
    sb    $t0, 0($t2)

    # --- procurar cliente por conta+dv ---
    move  $s0, $zero
    li    $t7, 50
cfmt_find_loop:
    beq   $s0, $t7, cfmt_notfound

    # usado?
    la    $t0, clientes_usado
    addu  $t0, $t0, $s0
    lb    $t1, 0($t0)
    beq   $t1, $zero, cfmt_next_i

    # compara conta (i*7)
    la    $t2, clientes_conta
    sll   $t3, $s0, 3
    subu  $t3, $t3, $s0          # i*7
    addu  $a0, $t2, $t3
    la    $a1, cc_buf_acc
    jal   strcmp
    nop
    bne   $v0, $zero, cfmt_next_i

    # compara DV
    la    $t4, clientes_dv
    addu  $t4, $t4, $s0
    lb    $t5, 0($t4)
    la    $t6, cc_buf_dv
    lb    $t6, 0($t6)
    bne   $t5, $t6, cfmt_next_i

    # achou
    j     cfmt_found
cfmt_next_i:
    addiu $s0, $s0, 1
    j     cfmt_find_loop

cfmt_notfound:
    la    $a0, msg_err_cli_inexist
    jal   print_str
    nop
    li    $v0, 1
    j     cfmt_ret

cfmt_badfmt:
    la    $a0, msg_cc_badfmt
    jal   print_str
    nop
    li    $v0, 1
    j     cfmt_ret

# --- confirmação e limpeza ---
cfmt_found:
    la    $a0, msg_fmt_confirm1
    jal   print_str
    nop
    la    $a0, cc_buf_acc
    jal   print_str
    nop
    la    $a0, dash_str
    jal   print_str
    nop
    # imprime DV
    la    $t0, cc_buf_dv
    lb    $t1, 0($t0)
    la    $t2, onechar_buf
    sb    $t1, 0($t2)
    sb    $zero, 1($t2)
    la    $a0, onechar_buf
    jal   print_str
    nop
    la    $a0, msg_fmt_confirm_q
    jal   print_str
    nop

    # lê resposta
    la    $a0, inp_buf
    li    $a1, 256
    jal   read_line
    nop
    la    $t0, inp_buf
    lb    $t1, 0($t0)
    li    $t2, 's'
    beq   $t1, $t2, cfmt_do
    li    $t2, 'S'
    beq   $t1, $t2, cfmt_do

    la    $a0, msg_fmt_cancel
    jal   print_str
    nop
    li    $v0, 1
    j     cfmt_ret

cfmt_do:
    # zera meta (head/count/wptr) débito e crédito
    sll   $t8, $s0, 2

    la    $t0, trans_deb_head
    addu  $t0, $t0, $t8
    sw    $zero, 0($t0)
    la    $t0, trans_deb_count
    addu  $t0, $t0, $t8
    sw    $zero, 0($t0)
    la    $t0, trans_deb_wptr
    addu  $t0, $t0, $t8
    sw    $zero, 0($t0)

    la    $t0, trans_cred_head
    addu  $t0, $t0, $t8
    sw    $zero, 0($t0)
    la    $t0, trans_cred_count
    addu  $t0, $t0, $t8
    sw    $zero, 0($t0)
    la    $t0, trans_cred_wptr
    addu  $t0, $t0, $t8
    sw    $zero, 0($t0)

    # zera 50 words dos valores p/ esse cliente (i*200 bytes)
    sll   $t3, $s0, 5      # i*32
    sll   $t4, $s0, 4      # i*16
    addu  $t3, $t3, $t4    # i*48
    sll   $t4, $s0, 1      # i*2
    addu  $t3, $t3, $t4    # i*50
    sll   $t3, $t3, 2      # *4 -> bytes

    la    $t0, trans_deb_vals
    addu  $t0, $t0, $t3
    li    $t1, 50
cfmt_zero_deb:
    sw    $zero, 0($t0)
    addiu $t0, $t0, 4
    addiu $t1, $t1, -1
    bgtz  $t1, cfmt_zero_deb

    la    $t0, trans_cred_vals
    addu  $t0, $t0, $t3
    li    $t1, 50
cfmt_zero_cred:
    sw    $zero, 0($t0)
    addiu $t0, $t0, 4
    addiu $t1, $t1, -1
    bgtz  $t1, cfmt_zero_cred

    la    $a0, msg_fmt_conta_ok
    jal   print_str
    nop
    li    $v0, 1
    j     cfmt_ret

cfmt_notmine:
    move  $v0, $zero

cfmt_ret:
    lw    $s3, 28($sp)
    lw    $s2, 32($sp)
    lw    $s1, 36($sp)
    lw    $s0, 40($sp)
    lw    $ra, 44($sp)
    addiu $sp, $sp, 48
    jr    $ra
    nop
