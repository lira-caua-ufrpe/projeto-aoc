# ============================================================
# Universidade Federal Rural de Pernambuco (UFRPE)
# Disciplina: Arquitetura e Organização de Computadores — 2025.2
# Avaliação: Projetos 1 (PE1) – 1a VA
# Professor: Vitor Coutinho
# Atividade: Lista de Exercícios – Questão 1 (string.h)
# Arquivo: transacoes.asm
# Equipe: OPCODE
# Integrantes: Cauã Lira; Sérgio Ricardo; Lucas Emanuel
# Data de entrega: 13/11/2025 (horário da aula)
# Apresentação: vídeo no ato da entrega
# Descrição: Implementa strcpy, memcpy, strcmp, strncmp, strcat
#            e um main com casos de teste no MARS (4.5+).
# Convenções:
#   - strcpy(a0=dst, a1=src)              -> v0=dst
#   - memcpy(a0=dst, a1=src, a2=num)      -> v0=dst
#   - strcmp(a0=str1, a1=str2)            -> v0 (<0, 0, >0)
#   - strncmp(a0=str1, a1=str2, a3=num)   -> v0 (<0, 0, >0)
#   - strcat(a0=dst, a1=src)              -> v0=dst
#   - Temporários: $t0..$t9 | PC inicia em 'main'
# Observação: Como em C, o comportamento de strcat com áreas sobrepostas é indefinido.
# ============================================================

        .data
transacoes_detalhe_debito:   .space 80000
transacoes_detalhe_credito:  .space 80000
msg_transferencia:           .asciiz "TRANSF"

        .text
        .globl mostrar_transacoes_debito
        .globl mostrar_transacoes_credito
        .globl adicionar_transacao_detalhe
        .globl preencher_data_hora_atual
        .globl formatar_centavos

# ------------------------------------------------------------
# mostrar_transacoes_debito(a0 = idx_cliente)
# ------------------------------------------------------------
mostrar_transacoes_debito:
    addiu $sp, $sp, -24
    sw    $ra, 20($sp)
    sw    $s0, 16($sp)
    sw    $s1, 12($sp)
    sw    $s2,  8($sp)

    move  $s0, $a0

    li    $t0, 1600              
    mul   $t1, $s0, $t0
    la    $s2, transacoes_detalhe_debito
    addu  $s2, $s2, $t1

    li    $s1, 0
mtd_loop:
    li    $t0, 50
    beq   $s1, $t0, mtd_fim

    lb    $t1, 0($s2)            
    beq   $t1, $zero, mtd_next

    # data/hora
    addiu $a0, $s2, 13
    li    $v0, 4
    syscall

    # 2 espacos
    li    $v0, 11
    li    $a0, 32
    syscall
    syscall

    # tipo
    li    $v0, 4
    la    $a0, msg_transferencia
    syscall

    # 4 espacos
    li    $v0, 11
    li    $a0, 32
    syscall
    syscall
    syscall
    syscall

    # valor em [9..12] (big-endian -> word)
    lbu   $t2, 9($s2)
    lbu   $t3, 10($s2)
    lbu   $t4, 11($s2)
    lbu   $t5, 12($s2)
    sll   $t2, $t2, 24
    sll   $t3, $t3, 16
    sll   $t4, $t4, 8
    or    $a0, $t2, $t3
    or    $a0, $a0, $t4
    or    $a0, $a0, $t5

    jal   formatar_centavos
    nop
    move  $a0, $v0
    li    $v0, 4
    syscall

    # \n
    li    $v0, 11
    li    $a0, 10
    syscall

mtd_next:
    addiu $s2, $s2, 32
    addiu $s1, $s1, 1
    j     mtd_loop

mtd_fim:
    lw    $s2,  8($sp)
    lw    $s1, 12($sp)
    lw    $s0, 16($sp)
    lw    $ra, 20($sp)
    addiu $sp, $sp, 24
    jr    $ra
    nop

# ------------------------------------------------------------
# mostrar_transacoes_credito(a0 = idx_cliente)
# ------------------------------------------------------------
mostrar_transacoes_credito:
    addiu $sp, $sp, -24
    sw    $ra, 20($sp)
    sw    $s0, 16($sp)
    sw    $s1, 12($sp)
    sw    $s2,  8($sp)

    move  $s0, $a0

    li    $t0, 1600
    mul   $t1, $s0, $t0
    la    $s2, transacoes_detalhe_credito
    addu  $s2, $s2, $t1

    li    $s1, 0
mtc_loop:
    li    $t0, 50
    beq   $s1, $t0, mtc_fim

    lb    $t1, 0($s2)
    beq   $t1, $zero, mtc_next

    # data/hora
    addiu $a0, $s2, 13
    li    $v0, 4
    syscall

    # 2 espacos
    li    $v0, 11
    li    $a0, 32
    syscall
    syscall

    # tipo
    li    $v0, 4
    la    $a0, msg_transferencia
    syscall

    # 4 espacos
    li    $v0, 11
    li    $a0, 32
    syscall
    syscall
    syscall
    syscall

    # valor em [9..12] (big-endian -> word)
    lbu   $t2, 9($s2)
    lbu   $t3, 10($s2)
    lbu   $t4, 11($s2)
    lbu   $t5, 12($s2)
    sll   $t2, $t2, 24
    sll   $t3, $t3, 16
    sll   $t4, $t4, 8
    or    $a0, $t2, $t3
    or    $a0, $a0, $t4
    or    $a0, $a0, $t5

    jal   formatar_centavos
    nop
    move  $a0, $v0
    li    $v0, 4
    syscall

    # \n
    li    $v0, 11
    li    $a0, 10
    syscall

mtc_next:
    addiu $s2, $s2, 32
    addiu $s1, $s1, 1
    j     mtc_loop

mtc_fim:
    lw    $s2,  8($sp)
    lw    $s1, 12($sp)
    lw    $s0, 16($sp)
    lw    $ra, 20($sp)
    addiu $sp, $sp, 24
    jr    $ra
    nop

# ------------------------------------------------------------
# adicionar_transacao_detalhe
# a0 = idx_cliente
# a1 = tipo (0 = debito, 1 = cr?dito)
# a2 = ponteiro pra conta (string)
# a3 = valor em centavos (word)
# ------------------------------------------------------------
adicionar_transacao_detalhe:
    addiu $sp, $sp, -24
    sw    $ra, 20($sp)
    sw    $s0, 16($sp)
    sw    $s1, 12($sp)
    sw    $s2,  8($sp)

    move  $s0, $a0
    move  $s1, $a1
    move  $s2, $a2

    li    $t0, 1600
    mul   $t1, $s0, $t0
    beq   $s1, $zero, atd_deb
    la    $t2, transacoes_detalhe_credito
    j     atd_base_ok
atd_deb:
    la    $t2, transacoes_detalhe_debito
atd_base_ok:
    addu  $t2, $t2, $t1

    # achar slot livre
    li    $t3, 0
atd_find:
    li    $t4, 50
    beq   $t3, $t4, atd_full
    lb    $t5, 0($t2)
    beq   $t5, $zero, atd_slot
    addiu $t2, $t2, 32
    addiu $t3, $t3, 1
    j     atd_find

atd_slot:
    li    $t5, 1
    sb    $t5, 0($t2)

    # conta [1..8]
    addiu $t6, $t2, 1
    move  $t7, $s2
cpy_conta:
    lb    $t8, 0($t7)
    sb    $t8, 0($t6)
    beq   $t8, $zero, cpy_conta_done
    addiu $t6, $t6, 1
    addiu $t7, $t7, 1
    j     cpy_conta
cpy_conta_done:

    # valor em [9..12] (big-endian)
    addiu $t9, $t2, 9
    srl   $t0, $a3, 24
    sb    $t0, 0($t9)
    srl   $t0, $a3, 16
    sb    $t0, 1($t9)
    srl   $t0, $a3, 8
    sb    $t0, 2($t9)
    sb    $a3, 3($t9)

    # data/hora
    addiu $a0, $t2, 13
    jal   preencher_data_hora_atual
    nop

    li    $v0, 1
    j     atd_end

atd_full:
    li    $v0, 0

atd_end:
    lw    $s2,  8($sp)
    lw    $s1, 12($sp)
    lw    $s0, 16($sp)
    lw    $ra, 20($sp)
    addiu $sp, $sp, 24
    jr    $ra
    nop

# ------------------------------------------------------------
# preencher_data_hora_atual(a0 = buffer de 20B)
# ------------------------------------------------------------
preencher_data_hora_atual:
    addiu $sp, $sp, -16
    sw    $ra, 12($sp)
    sw    $s0,  8($sp)

    move  $s0, $a0

    jal   tick_datetime
    nop

    # dia
    la    $t0, curr_day
    lw    $a0, 0($t0)
    move  $a1, $s0
    jal   print_two_buffer
    nop
    move  $s0, $v0

    li    $t1, '/'
    sb    $t1, 0($s0)
    addiu $s0, $s0, 1

    
    la    $t0, curr_mon
    lw    $a0, 0($t0)
    move  $a1, $s0
    jal   print_two_buffer
    nop
    move  $s0, $v0

    li    $t1, 
    sb    $t1, 0($s0)
    addiu $s0, $s0, 1

    
    la    $t0, curr_year
    lw    $a0, 0($t0)
    move  $a1, $s0
    jal   print_four_buffer
    nop
    move  $s0, $v0

    li    $t1, ' '
    sb    $t1, 0($s0)
    addiu $s0, $s0, 1

   
    la    $t0, curr_hour
    lw    $a0, 0($t0)
    move  $a1, $s0
    jal   print_two_buffer
    nop
    move  $s0, $v0

    li    $t1, ':'
    sb    $t1, 0($s0)
    addiu $s0, $s0, 1

    
    la    $t0, curr_min
    lw    $a0, 0($t0)
    move  $a1, $s0
    jal   print_two_buffer
    nop
    move  $s0, $v0

    li    $t1, ':'
    sb    $t1, 0($s0)
    addiu $s0, $s0, 1

    
    la    $t0, curr_sec
    lw    $a0, 0($t0)
    move  $a1, $s0
    jal   print_two_buffer
    nop
    move  $s0, $v0

    sb    $zero, 0($s0)

    lw    $s0,  8($sp)
    lw    $ra, 12($sp)
    addiu $sp, $sp, 16
    jr    $ra
    nop

# ------------------------------------------------------------
# print_two_buffer / print_four_buffer
# ------------------------------------------------------------
print_two_buffer:
    move  $v0, $a1
    li    $t0, 10
    divu  $a0, $t0
    mflo  $t1
    mfhi  $t2
    addiu $t1, $t1, 48
    addiu $t2, $t2, 48
    sb    $t1, 0($v0)
    sb    $t2, 1($v0)
    addiu $v0, $v0, 2
    jr    $ra
    nop

print_four_buffer:
    move  $v0, $a1
    li    $t0, 1000
    divu  $a0, $t0
    mflo  $t1
    mfhi  $t3
    addiu $t1, $t1, 48
    sb    $t1, 0($v0)
    addiu $v0, $v0, 1

    li    $t0, 100
    divu  $t3, $t0
    mflo  $t1
    mfhi  $t3
    addiu $t1, $t1, 48
    sb    $t1, 0($v0)
    addiu $v0, $v0, 1

    li    $t0, 10
    divu  $t3, $t0
    mflo  $t1
    mfhi  $t2
    addiu $t1, $t1, 48
    addiu $t2, $t2, 48
    sb    $t1, 0($v0)
    sb    $t2, 1($v0)
    addiu $v0, $v0, 2
    jr    $ra
    nop

# ------------------------------------------------------------
# formatar_centavos(a0 = valor em centavos) -> v0 = &buffer_valor_formatado
# ------------------------------------------------------------
formatar_centavos:
    addiu $sp, $sp, -32
    sw    $ra, 28($sp)
    sw    $s0, 24($sp)
    sw    $s1, 20($sp)
    sw    $s2, 16($sp)
    sw    $s3, 12($sp)

    la    $s0, buffer_valor_formatado
    li    $t0, 'R'
    sb    $t0, 0($s0)
    li    $t0, '$'
    sb    $t0, 1($s0)
    li    $t0, ' '
    sb    $t0, 2($s0)
    addiu $s1, $s0, 3

    li    $t0, 100
    divu  $a0, $t0
    mflo  $s2            # reais
    mfhi  $t1            # centavos

    addiu $s3, $s0, 24   # pilha de digitos (inversa)
    move  $t2, $s3

    beq   $s2, $zero, fc_write_zero

fc_conv_loop:
    li    $t3, 10
    divu  $s2, $t3
    mflo  $s2
    mfhi  $t4
    addiu $t4, $t4, 48
    sb    $t4, 0($t2)
    addiu $t2, $t2, 1
    bne   $s2, $zero, fc_conv_loop
    j     fc_copy_back

fc_write_zero:
    li    $t4, '0'
    sb    $t4, 0($t2)
    addiu $t2, $t2, 1

fc_copy_back:
    addiu $t2, $t2, -1
fc_copy_loop:
    lb    $t4, 0($t2)
    sb    $t4, 0($s1)
    addiu $s1, $s1, 1
    beq   $t2, $s3, fc_copy_done
    addiu $t2, $t2, -1
    j     fc_copy_loop

fc_copy_done:
    li    $t4, ','
    sb    $t4, 0($s1)
    addiu $s1, $s1, 1

    li    $t3, 10
    divu  $t1, $t3
    mflo  $t4
    mfhi  $t5
    addiu $t4, $t4, 48
    addiu $t5, $t5, 48
    sb    $t4, 0($s1)
    sb    $t5, 1($s1)
    addiu $s1, $s1, 2

    sb    $zero, 0($s1)
    la    $v0, buffer_valor_formatado

    lw    $s3, 12($sp)
    lw    $s2, 16($sp)
    lw    $s1, 20($sp)
    lw    $s0, 24($sp)
    lw    $ra, 28($sp)
    addiu $sp, $sp, 32
    jr    $ra
    nop