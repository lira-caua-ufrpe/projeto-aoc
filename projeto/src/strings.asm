# strings.asm — utilitários básicos de strings para o projeto
# Convenções usadas no projeto:
#   strcmp(a0=s1, a1=s2) -> v0: 0 se iguais; <0 se s1<s2; >0 se s1>s2
#   strncmp(a0=s1, a1=s2, a3=n) -> idem, comparando até n chars
#   strcpy(a0=src, a1=dst) -> v0=dst (copia incluindo '\0')
#   is_all_digits_fixed(a0=addr, a1=len) -> v0=1 se todos '0'..'9', senão 0

.text
.globl strcmp
.globl strncmp
.globl strcpy
.globl is_all_digits_fixed

# ------------------------------------------------------------
# strcmp(a0=s1, a1=s2) -> v0
# ------------------------------------------------------------
strcmp:
    # loop: compara char a char
sc_loop:
    lb   $t0, 0($a0)        # c1
    lb   $t1, 0($a1)        # c2
    bne  $t0, $t1, sc_diff
    beq  $t0, $zero, sc_eq  # se c1==c2==0 => iguais
    addi $a0, $a0, 1
    addi $a1, $a1, 1
    j    sc_loop
sc_eq:
    move $v0, $zero
    jr   $ra
sc_diff:
    subu $v0, $t0, $t1      # sinaliza diferença
    jr   $ra

# ------------------------------------------------------------
# strncmp(a0=s1, a1=s2, a3=n) -> v0
# compara até n caracteres (ou até achar '\0' em algum)
# ------------------------------------------------------------
strncmp:
    move $t2, $a3           # t2 = n restante
    beq  $t2, $zero, streq0 # n == 0 => iguais
stn_loop:
    lb   $t0, 0($a0)        # c1
    lb   $t1, 0($a1)        # c2
    bne  $t0, $t1, stn_diff
    beq  $t0, $zero, streq0 # terminou (iguais até aqui)
    addi $a0, $a0, 1
    addi $a1, $a1, 1
    addi $t2, $t2, -1
    bgtz $t2, stn_loop
streq0:
    move $v0, $zero
    jr   $ra
stn_diff:
    subu $v0, $t0, $t1
    jr   $ra

# ------------------------------------------------------------
# strcpy(a0=src, a1=dst) -> v0=dst
# copia incluindo o terminador '\0'
# ------------------------------------------------------------
strcpy:
    move $v0, $a1           # retorno = dst
cpy_loop:
    lb   $t0, 0($a0)        # ch = *src
    sb   $t0, 0($a1)        # *dst = ch
    addi $a0, $a0, 1
    addi $a1, $a1, 1
    bne  $t0, $zero, cpy_loop
    jr   $ra

# ------------------------------------------------------------
# is_all_digits_fixed(a0=addr, a1=len) -> v0
# retorna 1 se addr[i] in ['0'..'9'] para i=0..len-1; senão 0
# ------------------------------------------------------------
is_all_digits_fixed:
    move $t0, $a0           # ptr
    move $t1, $a1           # len restante
    blez $t1, alldig_yes    # len <= 0 -> aceita (1)
alldig_loop:
    lb   $t2, 0($t0)
    blt  $t2, 48, alldig_no     # '0'
    bgt  $t2, 57, alldig_no     # '9'
    addi $t0, $t0, 1
    addi $t1, $t1, -1
    bgtz $t1, alldig_loop
alldig_yes:
    li   $v0, 1
    jr   $ra
alldig_no:
    move $v0, $zero
    jr   $ra