# ops_util.asm — utilitários de impressão (MARS 4.5)
# Fornece:
#   print_2dig(a0=0..99)
#   print_datahora()        # usa curr_* de data.asm

.text
.globl print_2dig
.globl print_datahora

# ------------------------------------------------------------
# print_2dig(a0=0..99)  -> imprime dois dígitos (00..99)
# ------------------------------------------------------------
print_2dig:
    li   $t0, 10
    divu $a0, $t0
    mflo $t1                 # dezenas
    mfhi $t2                 # unidades
    li   $v0, 11
    addiu $a0, $t1, 48       # '0'+dezenas
    syscall
    li   $v0, 11
    addiu $a0, $t2, 48       # '0'+unidades
    syscall
    jr   $ra

# ------------------------------------------------------------
# print_datahora()
# imprime: DD/MM/AAAA HH:MM:SS   (sem newline)
# Lê globais de data.asm: curr_day, curr_mon, curr_year, curr_hour, curr_min, curr_sec
# ------------------------------------------------------------
print_datahora:
    addiu $sp, $sp, -16
    sw    $ra, 12($sp)
    sw    $t0,  8($sp)
    sw    $t1,  4($sp)
    sw    $t2,  0($sp)

    # DD
    la   $t0, curr_day
    lw   $a0, 0($t0)
    jal  print_2dig

    # '/'
    li   $v0, 11
    li   $a0, '/'
    syscall

    # MM
    la   $t0, curr_mon
    lw   $a0, 0($t0)
    jal  print_2dig

    # '/'
    li   $v0, 11
    li   $a0, '/'
    syscall

    # AAAA (4 dígitos)
    la   $t0, curr_year
    lw   $a0, 0($t0)
    jal  __pu_print4

    # espaço entre data e hora
    li   $v0, 11
    li   $a0, ' '
    syscall

    # HH
    la   $t0, curr_hour
    lw   $a0, 0($t0)
    jal  print_2dig

    # ':'
    li   $v0, 11
    li   $a0, ':'
    syscall

    # MM
    la   $t0, curr_min
    lw   $a0, 0($t0)
    jal  print_2dig

    # ':'
    li   $v0, 11
    li   $a0, ':'
    syscall

    # SS
    la   $t0, curr_sec
    lw   $a0, 0($t0)
    jal  print_2dig

    # epílogo
    lw    $t2,  0($sp)
    lw    $t1,  4($sp)
    lw    $t0,  8($sp)
    lw    $ra, 12($sp)
    addiu $sp, $sp, 16
    jr    $ra

# ------------------------------------------------------------
# __pu_print4(a0=0..9999) -> imprime quatro dígitos (0000..9999)
# (rótulo interno; não exportado)
# ------------------------------------------------------------
__pu_print4:
    # milhar
    li   $t0, 1000
    divu $a0, $t0
    mflo $t1                # milhar
    mfhi $t3                # resto
    li   $v0, 11
    addiu $a0, $t1, 48
    syscall

    # centena
    li   $t0, 100
    divu $t3, $t0
    mflo $t1
    mfhi $t3
    li   $v0, 11
    addiu $a0, $t1, 48
    syscall

    # dezena
    li   $t0, 10
    divu $t3, $t0
    mflo $t1
    mfhi $t2               # unidade
    li   $v0, 11
    addiu $a0, $t1, 48
    syscall

    # unidade
    li   $v0, 11
    addiu $a0, $t2, 48
    syscall

    jr   $ra
