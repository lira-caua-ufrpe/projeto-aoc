# strings.asm — utilidades de string (MARS-friendly)

.text
.globl strcmp
.globl strncmp
.globl strlen
.globl str_starts_with

# strcmp(a0=s1, a1=s2) -> v0 (<0, 0, >0)
strcmp:
    move $t0, $a0
    move $t1, $a1
STRCMP_LOOP:
    lb   $t2, 0($t0)
    lb   $t3, 0($t1)
    beq  $t2, $t3, STRCMP_NEXT
    sub  $v0, $t2, $t3
    jr   $ra
STRCMP_NEXT:
    beq  $t2, $zero, STRCMP_EQ
    addi $t0, $t0, 1
    addi $t1, $t1, 1
    j    STRCMP_LOOP
STRCMP_EQ:
    move $v0, $zero
    jr   $ra

# strncmp(a0=s1, a1=s2, a2=n) -> v0 (<0, 0, >0)
strncmp:
    move $t0, $a0
    move $t1, $a1
    move $t4, $a2
STRNCMP_CHECK_N:
    beq  $t4, $zero, STRNCMP_RET_EQ
STRNCMP_LOOP:
    lb   $t2, 0($t0)
    lb   $t3, 0($t1)
    bne  $t2, $t3, STRNCMP_RET_DIFF
    beq  $t2, $zero, STRNCMP_RET_EQ
    addi $t0, $t0, 1
    addi $t1, $t1, 1
    addi $t4, $t4, -1
    bgtz $t4, STRNCMP_LOOP
STRNCMP_RET_EQ:
    move $v0, $zero
    jr   $ra
STRNCMP_RET_DIFF:
    sub  $v0, $t2, $t3
    jr   $ra

# strlen(a0=s) -> v0 = tamanho (sem '\0')
strlen:
    move $t0, $a0
    move $v0, $zero
STRLEN_LOOP:
    lb   $t1, 0($t0)
    beq  $t1, $zero, STRLEN_END
    addi $v0, $v0, 1
    addi $t0, $t0, 1
    j    STRLEN_LOOP
STRLEN_END:
    jr   $ra

# str_starts_with(a0=str, a1=prefix) -> v0=1 se str começa com prefix; v1 = ptr após prefix
str_starts_with:
    move $t0, $a0    # p = str
    move $t1, $a1    # q = prefix
SSW_LOOP:
    lb   $t2, 0($t1)     # c = *prefix
    beq  $t2, $zero, SSW_OK   # terminou prefix -> match
    lb   $t3, 0($t0)     # d = *str
    bne  $t2, $t3, SSW_NO
    addi $t0, $t0, 1
    addi $t1, $t1, 1
    j    SSW_LOOP
SSW_OK:
    li   $v0, 1
    move $v1, $t0        # ptr após prefix
    jr   $ra
SSW_NO:
    move $v0, $zero
    move $v1, $a0
    jr   $ra
