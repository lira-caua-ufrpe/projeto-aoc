# cmd_persist.asm — comandos: salvar, recarregar, formatar
# depende de: print_str, strcmp, save_state, load_state
# e dos símbolos de data.asm (clientes_*, trans_*)

.text
.globl handle_cmd_salvar
.globl handle_cmd_recarregar
.globl handle_cmd_formatar
.globl format_state
.globl memclr

# memclr(a0=addr, a1=len) -> zera len bytes
memclr:
    addiu $sp, $sp, -16
    sw    $ra, 12($sp)
    sw    $s0,  8($sp)
    sw    $s1,  4($sp)

    move  $s0, $a0          # ptr
    move  $s1, $a1          # len
mc_loop:
    blez  $s1, mc_end
    sb    $zero, 0($s0)
    addiu $s0, $s0, 1
    addiu $s1, $s1, -1
    j     mc_loop
mc_end:
    lw    $s1,  4($sp)
    lw    $s0,  8($sp)
    lw    $ra, 12($sp)
    addiu $sp, $sp, 16
    jr    $ra
    nop

# format_state() -> zera clientes e transações (não mexe em data/hora)
format_state:
    addiu $sp, $sp, -16
    sw    $ra, 12($sp)

    # blocos de bytes
    la    $a0, clientes_usado
    li    $a1, 50
    jal   memclr

    la    $a0, clientes_cpf
    li    $a1, 600
    jal   memclr

    la    $a0, clientes_conta
    li    $a1, 350
    jal   memclr

    la    $a0, clientes_dv
    li    $a1, 50
    jal   memclr

    la    $a0, clientes_nome
    li    $a1, 1650
    jal   memclr

    # words (pode limpar em bytes sem problema)
    la    $a0, clientes_saldo_cent
    li    $a1, 200
    jal   memclr

    la    $a0, clientes_limite_cent
    li    $a1, 200
    jal   memclr

    la    $a0, clientes_devido_cent
    li    $a1, 200
    jal   memclr

    # rings débito: meta + valores
    la    $a0, trans_deb_head
    li    $a1, 200
    jal   memclr

    la    $a0, trans_deb_count
    li    $a1, 200
    jal   memclr

    la    $a0, trans_deb_wptr
    li    $a1, 200
    jal   memclr

    la    $a0, trans_deb_vals
    li    $a1, 10000
    jal   memclr

    # rings crédito: meta + valores
    la    $a0, trans_cred_head
    li    $a1, 200
    jal   memclr

    la    $a0, trans_cred_count
    li    $a1, 200
    jal   memclr

    la    $a0, trans_cred_wptr
    li    $a1, 200
    jal   memclr

    la    $a0, trans_cred_vals
    li    $a1, 10000
    jal   memclr

    lw    $ra, 12($sp)
    addiu $sp, $sp, 16
    jr    $ra
    nop

# handle_cmd_salvar(a0=buf) -> v0=1 se tratou; 0 se não era
handle_cmd_salvar:
    addiu $sp, $sp, -16
    sw    $ra, 12($sp)
    sw    $s0,  8($sp)

    move  $s0, $a0
    la    $a1, str_salvar
    jal   strcmp
    bne   $v0, $zero, hcs_notmine

    # é "salvar"
    jal   save_state
    beq   $v0, $zero, hcs_fail
    la    $a0, msg_salvo_ok
    jal   print_str
    li    $v0, 1
    j     hcs_end
hcs_fail:
    la    $a0, msg_salvo_fail
    jal   print_str
    li    $v0, 1
    j     hcs_end
hcs_notmine:
    move  $v0, $zero
hcs_end:
    lw    $s0,  8($sp)
    lw    $ra, 12($sp)
    addiu $sp, $sp, 16
    jr    $ra
    nop

# handle_cmd_recarregar(a0=buf)
handle_cmd_recarregar:
    addiu $sp, $sp, -16
    sw    $ra, 12($sp)

    la    $a1, str_recarregar
    jal   strcmp
    bne   $v0, $zero, hcr_notmine

    jal   load_state
    beq   $v0, $zero, hcr_fail
    la    $a0, msg_load_ok
    jal   print_str
    li    $v0, 1
    j     hcr_end
hcr_fail:
    la    $a0, msg_load_fail
    jal   print_str
    li    $v0, 1
    j     hcr_end
hcr_notmine:
    move  $v0, $zero
hcr_end:
    lw    $ra, 12($sp)
    addiu $sp, $sp, 16
    jr    $ra
    nop

# handle_cmd_formatar(a0=buf)
handle_cmd_formatar:
    addiu $sp, $sp, -16
    sw    $ra, 12($sp)

    la    $a1, str_formatar
    jal   strcmp
    bne   $v0, $zero, hcf_notmine

    jal   format_state
    la    $a0, msg_fmt_ok
    jal   print_str
    li    $v0, 1
    j     hcf_end
hcf_notmine:
    move  $v0, $zero
hcf_end:
    lw    $ra, 12($sp)
    addiu $sp, $sp, 16
    jr    $ra
    nop
