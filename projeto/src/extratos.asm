# ============================================================
# extratos.asm - versão simples (só limite e dívida)
# comando:  credito_extrato-<CONTA6>-<DV>
#           debito_extrato-<CONTA6>-<DV>   (só mostra cabeçalho)
# depende de:
#   - data.asm  (clientes_*, cc_buf_acc, msgs, MAX_CLIENTS)
#   - transacoes.asm (formatar_centavos)
# ============================================================

.data
str_cmd_extrato_debito:   .asciiz "debito_extrato-"
str_cmd_extrato_credito:  .asciiz "credito_extrato-"

msg_extrato_credito_hdr:  .asciiz "\n=== EXTRATO CREDITO ===\nData/Hora           Tipo        Valor (R$)\n------------------------------------------\n"
msg_extrato_debito_hdr:   .asciiz "\n=== EXTRATO DEBITO ===\nData/Hora           Tipo        Valor (R$)\n------------------------------------------\n"

msg_limite_disp:          .asciiz "Limite disponivel: R$ "
msg_divida_atual:         .asciiz "Divida atual: R$ "
msg_nl:                   .asciiz "\n"

.text
.globl handle_extrato_credito
.globl handle_extrato_debito

# ------------------------------------------------------------
# helper: procura cliente por conta(6) (em cc_buf_acc) + DV
# a0 = &cc_buf_acc
# a1 = dv (byte)
# v0 = indice ou -1
# ------------------------------------------------------------
extr_buscar_cliente_conta_dv:
    lw    $t9, MAX_CLIENTS
    li    $t0, 0                  # i = 0
ebc_loop:
    beq   $t0, $t9, ebc_not_found

    # usado?
    la    $t1, clientes_usado
    addu  $t1, $t1, $t0
    lb    $t2, 0($t1)
    beq   $t2, $zero, ebc_next

    # compara conta(6)
    la    $t3, clientes_conta
    li    $t4, 7
    mul   $t4, $t0, $t4           # i*7
    addu  $t3, $t3, $t4           # &clientes_conta[i]
    move  $t5, $a0                # &cc_buf_acc
    li    $t6, 0
ebc_cmp6:
    lb    $t7, 0($t3)
    lb    $t8, 0($t5)
    bne   $t7, $t8, ebc_next
    addiu $t3, $t3, 1
    addiu $t5, $t5, 1
    addiu $t6, $t6, 1
    blt   $t6, 6, ebc_cmp6

    # compara DV
    la    $t3, clientes_dv
    addu  $t3, $t3, $t0
    lb    $t7, 0($t3)
    bne   $t7, $a1, ebc_next

    move  $v0, $t0
    jr    $ra

ebc_next:
    addiu $t0, $t0, 1
    j     ebc_loop

ebc_not_found:
    li    $v0, -1
    jr    $ra

# ------------------------------------------------------------
# handle_extrato_credito(a0 = inp_buf)
# ------------------------------------------------------------
handle_extrato_credito:
    addiu $sp, $sp, -24
    sw    $ra, 20($sp)
    sw    $s0, 16($sp)
    sw    $s1, 12($sp)
    sw    $s2, 8($sp)

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

hec_pref_ok:
    # conta(6) -> cc_buf_acc
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

    # '-'
    lb    $t6, 0($t0)
    li    $t7, 45
    bne   $t6, $t7, hec_badfmt
    addiu $t0, $t0, 1

    # DV
    lb    $s1, 0($t0)

    # achar cliente
    la    $a0, cc_buf_acc
    move  $a1, $s1
    jal   extr_buscar_cliente_conta_dv
    move  $s0, $v0
    bltz  $s0, hec_cli_inexist

    # imprime cabeçalho
    li    $v0, 4
    la    $a0, msg_extrato_credito_hdr
    syscall

    # pega limite e devido
    sll   $t0, $s0, 2
    la    $t1, clientes_limite_cent
    addu  $t1, $t1, $t0
    lw    $t2, 0($t1)            # limite

    la    $t3, clientes_devido_cent
    addu  $t3, $t3, $t0
    lw    $t4, 0($t3)            # devido

    subu  $t5, $t2, $t4          # disponivel = limite - devido

    # "Limite disponivel: R$ "
    li    $v0, 4
    la    $a0, msg_limite_disp
    syscall

    # imprime valor disponivel
    move  $a0, $t5               # centavos
    jal   formatar_centavos          # v0 = ptr string
    move  $a0, $v0
    li    $v0, 4
    syscall

    # \n
    li    $v0, 4
    la    $a0, msg_nl
    syscall

    # "Divida atual: R$ "
    li    $v0, 4
    la    $a0, msg_divida_atual
    syscall

    # imprime devido
    move  $a0, $t4
    jal   formatar_centavos
    move  $a0, $v0
    li    $v0, 4
    syscall

    # \n
    li    $v0, 4
    la    $a0, msg_nl
    syscall

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
    lw    $s2, 8($sp)
    lw    $s1, 12($sp)
    lw    $s0, 16($sp)
    lw    $ra, 20($sp)
    addiu $sp, $sp, 24
    jr    $ra

# ------------------------------------------------------------
# handle_extrato_debito(a0 = inp_buf) – versão bem simples
# ------------------------------------------------------------
handle_extrato_debito:
    addiu $sp, $sp, -16
    sw    $ra, 12($sp)

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

hedb_ok:
    li    $v0, 4
    la    $a0, msg_extrato_debito_hdr
    syscall
    li    $v0, 1
    j     hedb_end

hedb_not_mine:
    move  $v0, $zero

hedb_end:
    lw    $ra, 12($sp)
    addiu $sp, $sp, 16
    jr    $ra
