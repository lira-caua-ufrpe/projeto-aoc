# strings.asm — rotinas de string: strcmp, strncmp, is_all_digits_fixed

.text
.globl strcmp
.globl strncmp
.globl is_all_digits_fixed

# ------------------------------------------------------------
# strcmp(a0=str1, a1=str2) -> v0:
#   <0 se str1 < str2 ; 0 se iguais ; >0 se str1 > str2
# Null-safe:
#   a0==NULL && a1==NULL -> 0
#   a0==NULL -> -1
#   a1==NULL ->  1
# ------------------------------------------------------------
strcmp:
    beq  $a0, $zero, strcmp_a0_null
    beq  $a1, $zero, strcmp_a1_null
    move $t0, $a0
    move $t1, $a1
strcmp_loop:
    lb   $t2, 0($t0)
    lb   $t3, 0($t1)
    beq  $t2, $t3, strcmp_next
    sub  $v0, $t2, $t3
    jr   $ra
strcmp_next:
    beq  $t2, $zero, strcmp_eq
    addi $t0, $t0, 1
    addi $t1, $t1, 1
    j    strcmp_loop
strcmp_eq:
    move $v0, $zero
    jr   $ra
strcmp_a0_null:
    beq  $a1, $zero, strcmp_eq
    li   $v0, -1
    jr   $ra
strcmp_a1_null:
    li   $v0, 1
    jr   $ra

# ------------------------------------------------------------
# strncmp(a0=str1, a1=str2, a3=num) -> v0:
# Compara até num caracteres ou até '\0' em algum lado.
# Null-safe; n<=0 => 0
# ------------------------------------------------------------
strncmp:
    blez $a3, strncmp_eq
    beq  $a0, $zero, strncmp_a0_null
    beq  $a1, $zero, strncmp_a1_null
    move $t0, $a0
    move $t1, $a1
    move $t4, $a3
strncmp_loop:
    lb   $t2, 0($t0)
    lb   $t3, 0($t1)
    bne  $t2, $t3, strncmp_diff
    beq  $t2, $zero, strncmp_eq
    addi $t0, $t0, 1
    addi $t1, $t1, 1
    addi $t4, $t4, -1
    bgtz $t4, strncmp_loop
strncmp_eq:
    move $v0, $zero
    jr   $ra
strncmp_diff:
    sub  $v0, $t2, $t3
    jr   $ra
strncmp_a0_null:
    beq  $a1, $zero, strncmp_eq
    li   $v0, -1
    jr   $ra
strncmp_a1_null:
    li   $v0, 1
    jr   $ra

# ------------------------------------------------------------
# is_all_digits_fixed(a0=buf, a1=len) -> v0:
#   Retorna 1 se buf[0..len-1] são '0'..'9' e (buf[len]=='\0'), senão 0.
#   Null-safe.
# ------------------------------------------------------------
is_all_digits_fixed:
    beq  $a0, $zero, iadf_no
    blez $a1, iadf_no
    move $t0, $a0
    move $t1, $a1
iadf_loop:
    beq  $t1, $zero, iadf_check_terminator
    lb   $t2, 0($t0)
    blt  $t2, 48, iadf_no       # < '0'
    bgt  $t2, 57, iadf_no       # > '9'
    addi $t0, $t0, 1
    addi $t1, $t1, -1
    j    iadf_loop
iadf_check_terminator:
    lb   $t3, 0($t0)
    bne  $t3, $zero, iadf_no
    li   $v0, 1
    jr   $ra
iadf_no:
    move $v0, $zero
    jr   $ra
