# strings.asm — utilitários básicos de strings
# strcmp(a0=s1, a1=s2) -> v0: 0 se iguais; <0 se s1<s2; >0 se s1>s2
# strncmp(a0=s1, a1=s2, a3=n) -> idem, até n chars
# strcpy(a0=src, a1=dst) -> v0=dst (copia incluindo '\0')
# is_all_digits_fixed(a0=addr, a1=len) -> v0=1 se todos '0'..'9', senão 0

.text
.globl strcmp
.globl strncmp
.globl strcpy
.globl is_all_digits_fixed

# strcmp ------------------------------------------------------
strcmp:
sc_loop:
    lb   $t0, 0($a0)        # c1
    lb   $t1, 0($a1)        # c2
    bne  $t0, $t1, sc_diff
    beq  $t0, $zero, sc_eq  # c1==c2==0 => iguais
    addiu $a0, $a0, 1
    addiu $a1, $a1, 1
    j    sc_loop
sc_eq:
    move $v0, $zero
    jr   $ra
sc_diff:
    subu $v0, $t0, $t1
    jr   $ra

# strncmp -----------------------------------------------------
strncmp:
    move $t2, $a3           # n
    beq  $t2, $zero, streq0
stn_loop:
    lb   $t0, 0($a0)
    lb   $t1, 0($a1)
    bne  $t0, $t1, stn_diff
    beq  $t0, $zero, streq0
    addiu $a0, $a0, 1
    addiu $a1, $a1, 1
    addiu $t2, $t2, -1
    bgtz $t2, stn_loop
streq0:
    move $v0, $zero
    jr   $ra
stn_diff:
    subu $v0, $t0, $t1
    jr   $ra

# strcpy ------------------------------------------------------
strcpy:
    move $v0, $a1
cpy_loop:
    lb   $t0, 0($a0)
    sb   $t0, 0($a1)
    addiu $a0, $a0, 1
    addiu $a1, $a1, 1
    bne  $t0, $zero, cpy_loop
    jr   $ra

# is_all_digits_fixed ----------------------------------------
is_all_digits_fixed:
    move $t0, $a0           # ptr
    move $t1, $a1           # len
    blez $t1, alldig_yes
alldig_loop:
    lb   $t2, 0($t0)
    blt  $t2, 48, alldig_no     # '0'
    bgt  $t2, 57, alldig_no     # '9'
    addiu $t0, $t0, 1
    addiu $t1, $t1, -1
    bgtz $t1, alldig_loop
alldig_yes:
    li   $v0, 1
    jr   $ra
alldig_no:
    move $v0, $zero
    jr   $ra
