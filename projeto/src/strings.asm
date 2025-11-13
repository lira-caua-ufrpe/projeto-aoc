# ============================================================
# strings.asm — utilitários básicos de strings em MIPS
# ============================================================

# Funções exportadas:
# strcmp(a0=s1, a1=s2)        -> v0: 0 se iguais; <0 se s1<s2; >0 se s1>s2
# strncmp(a0=s1, a1=s2, a3=n) -> idem, até n caracteres
# strcpy(a0=src, a1=dst)       -> v0=dst (copia incluindo '\0')
# is_all_digits_fixed(a0=addr, a1=len) -> v0=1 se todos dígitos '0'..'9', senão 0

.text
.globl strcmp
.globl strncmp
.globl strcpy
.globl is_all_digits_fixed

# ============================================================
# strcmp(a0=s1, a1=s2)
# Compara duas strings terminadas em '\0'
# ============================================================
strcmp:
sc_loop:
    lb   $t0, 0($a0)        # lê caractere da string s1
    lb   $t1, 0($a1)        # lê caractere da string s2
    bne  $t0, $t1, sc_diff  # se diferentes, calcula diferença
    beq  $t0, $zero, sc_eq  # se fim de string e iguais, retorna 0
    addiu $a0, $a0, 1       # avança ponteiro s1
    addiu $a1, $a1, 1       # avança ponteiro s2
    j    sc_loop
sc_eq:
    move $v0, $zero
    jr   $ra
sc_diff:
    subu $v0, $t0, $t1      # retorna diferença dos ASCII
    jr   $ra

# ============================================================
# strncmp(a0=s1, a1=s2, a3=n)
# Compara até n caracteres
# ============================================================
strncmp:
    move $t2, $a3           # contador n
    beq  $t2, $zero, streq0 # se n==0, strings iguais
stn_loop:
    lb   $t0, 0($a0)        # caractere s1
    lb   $t1, 0($a1)        # caractere s2
    bne  $t0, $t1, stn_diff # se diferentes, retorna diferença
    beq  $t0, $zero, streq0 # fim de string, iguais
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

# ============================================================
# strcpy(a0=src, a1=dst)
# Copia string src para dst, incluindo '\0'
# ============================================================
strcpy:
    move $v0, $a1           # retorna ponteiro dst
cpy_loop:
    lb   $t0, 0($a0)        # lê caractere de src
    sb   $t0, 0($a1)        # escreve em dst
    addiu $a0, $a0, 1
    addiu $a1, $a1, 1
    bne  $t0, $zero, cpy_loop # continua até '\0'
    jr   $ra

# ============================================================
# is_all_digits_fixed(a0=addr, a1=len)
# Verifica se todos caracteres são dígitos '0'..'9'
# ============================================================
is_all_digits_fixed:
    move $t0, $a0           # ponteiro atual
    move $t1, $a1           # comprimento
    blez $t1, alldig_yes    # se len <= 0, considera "todos dígitos"
alldig_loop:
    lb   $t2, 0($t0)        # lê caractere
    blt  $t2, 48, alldig_no # se < '0', não é dígito
    bgt  $t2, 57, alldig_no # se > '9', não é dígito
    addiu $t0, $t0, 1
    addiu $t1, $t1, -1
    bgtz $t1, alldig_loop
alldig_yes:
    li   $v0, 1
    jr   $ra
alldig_no:
    move $v0, $zero
    jr   $ra
