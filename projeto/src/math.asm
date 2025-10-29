# ============================================================
# Arquivo: math.asm
# Descrição: Rotinas matemáticas reutilizáveis.
# ============================================================
.text
.globl sum_two
sum_two:
    add $v0, $a0, $a1
    jr  $ra
