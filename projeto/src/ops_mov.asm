# ============================================================
# ops_mov.asm – operações financeiras (depositar/sacar) + helpers
# ============================================================
.data
msg_err_inexist: .asciiz "Falha: cliente inexistente\n"
msg_err_saldo:   .asciiz "Falha: saldo insuficiente\n"
msg_err_valor:   .asciiz "Falha: valor invalido\n"

.text
.globl sacar_cmd, depositar_cmd
.globl atoi_strict, get_cli_ptr_by_idx

# atoi_strict(a0=ptr) -> v0=inteiro >=0; v0=-1 se houver char nao-num.
atoi_strict:
    move $v0,$zero
1:  lb  $t0,0($a0)
    beq $t0,$zero,2f
    blt $t0,'0', fail
    bgt $t0,'9', fail
    addi $t0,$t0,-48
    mul  $v0,$v0,10
    add  $v0,$v0,$t0
    addi $a0,$a0,1
    j 1b
2:  jr $ra
fail:
    li $v0,-1
    jr $ra

# get_cli_ptr_by_idx(v0=idx) -> v0=ptr base cliente
get_cli_ptr_by_idx:
    # entrada em v0 (idx); saída v0=endereço
    bltz $v0, bad
    la  $t0, clientes
    li  $t1, CLI_END
    mul $t2,$v0,$t1
    add $v0,$t0,$t2
    jr  $ra
bad:
    move $v0,$zero
    jr $ra

# depositar_cmd(a0=conta "XXXXXX-X", a1=valor "NNNNNN")
depositar_cmd:
    # achar cliente
    jal  find_by_conta
    move $t7,$v0
    bltz $t7, dep_inexist
    # valor
    move $a0,$a1
    jal  atoi_strict
    bltz $v0, dep_valor
    move $t6,$v0
    # ptr cliente
    move $v0,$t7
    jal  get_cli_ptr_by_idx
    move $t0,$v0
    lw   $t1, CLI_SALDO($t0)
    add  $t1,$t1,$t6
    sw   $t1, CLI_SALDO($t0)
    jr $ra
dep_inexist:
    la $a0, msg_err_inexist
    jal print_str
    jr $ra
dep_valor:
    la $a0, msg_err_valor
    jal print_str
    jr $ra

# sacar_cmd(a0=conta "XXXXXX-X", a1=valor "NNNNNN")
sacar_cmd:
    jal  find_by_conta
    move $t7,$v0
    bltz $t7, sac_inexist
    move $a0,$a1
    jal  atoi_strict
    bltz $v0, sac_valor
    move $t6,$v0
    move $v0,$t7
    jal  get_cli_ptr_by_idx
    move $t0,$v0
    lw   $t1, CLI_SALDO($t0)
    blt  $t1,$t6, sac_insuf
    sub  $t1,$t1,$t6
    sw   $t1, CLI_SALDO($t0)
    jr $ra
sac_inexist:
    la $a0, msg_err_inexist
    jal print_str
    jr $ra
sac_valor:
    la $a0, msg_err_valor
    jal print_str
    jr $ra
sac_insuf:
    la $a0, msg_err_saldo
    jal print_str
    jr $ra
