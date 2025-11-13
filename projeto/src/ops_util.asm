# ============================================================
# ops_util.asm — utilitários de impressão (MARS 4.5)
# Fornece funções para imprimir números e data/hora:
#   print_2dig(a0=0..99)        -> imprime dois dígitos (00..99)
#   print_datahora()            -> imprime DD/MM/AAAA HH:MM:SS
#                                  lê globais de data.asm: curr_day, curr_mon, curr_year,
#                                  curr_hour, curr_min, curr_sec
# ============================================================

.text
.globl print_2dig
.globl print_datahora

# ------------------------------------------------------------
# print_2dig(a0=0..99)
# Imprime exatamente dois dígitos (00..99)
# ------------------------------------------------------------
print_2dig:
    li   $t0, 10
    divu $a0, $t0               # Divide a0 por 10
    mflo $t1                    # $t1 = dezenas
    mfhi $t2                    # $t2 = unidades

    # Imprime dezenas
    li   $v0, 11                # syscall para print_char
    addiu $a0, $t1, 48          # converte para ASCII ('0' + dezenas)
    syscall

    # Imprime unidades
    li   $v0, 11
    addiu $a0, $t2, 48          # converte para ASCII ('0' + unidades)
    syscall

    jr   $ra                    # retorna

# ------------------------------------------------------------
# print_datahora()
# Imprime data e hora no formato: DD/MM/AAAA HH:MM:SS
# Sem newline no final
# ------------------------------------------------------------
print_datahora:
    # --- salva registradores usados ---
    addiu $sp, $sp, -16
    sw    $ra, 12($sp)
    sw    $t0,  8($sp)
    sw    $t1,  4($sp)
    sw    $t2,  0($sp)

    # --- Imprime dia ---
    la   $t0, curr_day
    lw   $a0, 0($t0)
    jal  print_2dig

    # imprime '/'
    li   $v0, 11
    li   $a0, '/'
    syscall

    # --- Imprime mês ---
    la   $t0, curr_mon
    lw   $a0, 0($t0)
    jal  print_2dig

    # imprime '/'
    li   $v0, 11
    li   $a0, '/'
    syscall

    # --- Imprime ano (AAAA) ---
    la   $t0, curr_year
    lw   $a0, 0($t0)
    jal  __pu_print4              # usa função interna para imprimir 4 dígitos

    # imprime espaço entre data e hora
    li   $v0, 11
    li   $a0, ' '
    syscall

    # --- Imprime hora ---
    la   $t0, curr_hour
    lw   $a0, 0($t0)
    jal  print_2dig

    # imprime ':'
    li   $v0, 11
    li   $a0, ':'
    syscall

    # --- Imprime minutos ---
    la   $t0, curr_min
    lw   $a0, 0($t0)
    jal  print_2dig

    # imprime ':'
    li   $v0, 11
    li   $a0, ':'
    syscall

    # --- Imprime segundos ---
    la   $t0, curr_sec
    lw   $a0, 0($t0)
    jal  print_2dig

    # --- restaura registradores e retorna ---
    lw    $t2,  0($sp)
    lw    $t1,  4($sp)
    lw    $t0,  8($sp)
    lw    $ra, 12($sp)
    addiu $sp, $sp, 16
    jr   $ra

# ------------------------------------------------------------
# __pu_print4(a0=0..9999) — imprime quatro dígitos (0000..9999)
# Função interna (não exportada), usada para imprimir anos ou números de 4 dígitos
# ------------------------------------------------------------
__pu_print4:
    # --- milhar ---
    li   $t0, 1000
    divu $a0, $t0
    mflo $t1                     # t1 = milhar
    mfhi $t3                     # t3 = resto
    li   $v0, 11
    addiu $a0, $t1, 48           # converte milhar para ASCII
    syscall

    # --- centena ---
    li   $t0, 100
    divu $t3, $t0
    mflo $t1                     # t1 = centena
    mfhi $t3                     # t3 = resto
    li   $v0, 11
    addiu $a0, $t1, 48           # converte centena para ASCII
    syscall

    # --- dezena ---
    li   $t0, 10
    divu $t3, $t0
    mflo $t1                     # t1 = dezena
    mfhi $t2                     # t2 = unidade
    li   $v0, 11
    addiu $a0, $t1, 48           # converte dezena para ASCII
    syscall

    # --- unidade ---
    li   $v0, 11
    addiu $a0, $t2, 48           # converte unidade para ASCII
    syscall

    jr   $ra


