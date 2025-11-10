# strings.asm — utilidades de string (MARS-friendly)

.text
.globl strcmp
.globl strncmp

# strcmp(a0=s1, a1=s2) -> v0 (<0, 0, >0)
strcmp:
    move $t0, $a0          # p1
    move $t1, $a1          # p2
STRCMP_LOOP:
    lb   $t2, 0($t0)       # c1
    lb   $t3, 0($t1)       # c2
    beq  $t2, $t3, STRCMP_NEXT
    sub  $v0, $t2, $t3     # dif (neg/zero/pos)
    jr   $ra
STRCMP_NEXT:
    beq  $t2, $zero, STRCMP_EQ   # ambos chegaram em '\0'
    addi $t0, $t0, 1
    addi $t1, $t1, 1
    j    STRCMP_LOOP
STRCMP_EQ:
    move $v0, $zero
    jr   $ra

# strncmp(a0=s1, a1=s2, a2=n) -> v0 (<0, 0, >0)
strncmp:
    move $t0, $a0          # p1
    move $t1, $a1          # p2
    move $t4, $a2          # n restante

# n == 0 ? => iguais
STRNCMP_CHECK_N:
    beq  $t4, $zero, STRNCMP_RET_EQ

STRNCMP_LOOP:
    lb   $t2, 0($t0)       # c1
    lb   $t3, 0($t1)       # c2
    bne  $t2, $t3, STRNCMP_RET_DIFF
    beq  $t2, $zero, STRNCMP_RET_EQ   # iguais e fim de string
    addi $t0, $t0, 1
    addi $t1, $t1, 1
    addi $t4, $t4, -1
    bgtz $t4, STRNCMP_LOOP

# se saiu do loop por n==0, também é igual
STRNCMP_RET_EQ:
    move $v0, $zero
    jr   $ra

STRNCMP_RET_DIFF:
    sub  $v0, $t2, $t3
    jr   $ra
