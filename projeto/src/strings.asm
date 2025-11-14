# ============================================================
# Universidade Federal Rural de Pernambuco (UFRPE)
# Disciplina: Arquitetura e Organização de Computadores — 2025.2
# Avaliação: Projetos 1 (PE1) – 1a VA
# Professor: Vitor Coutinho
# Atividade: Lista de Exercícios – Questão 1 (string.h)
# Arquivo: strings.asm
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
.text
.globl strcmp
.globl strncmp
.globl strcpy
.globl is_all_digits_fixed


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
    move $t0, $a0           
    move $t1, $a1           # len
    blez $t1, alldig_yes
alldig_loop:
    lb   $t2, 0($t0)
    blt  $t2, 48, alldig_no     
    bgt  $t2, 57, alldig_no     
    addiu $t0, $t0, 1
    addiu $t1, $t1, -1
    bgtz $t1, alldig_loop
alldig_yes:
    li   $v0, 1
    jr   $ra
alldig_no:
    move $v0, $zero
    jr   $ra