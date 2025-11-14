# ============================================================
# Universidade Federal Rural de Pernambuco (UFRPE)
# Disciplina: Arquitetura e Organização de Computadores — 2025.2
# Avaliação: Projetos 1 (PE1) – 1a VA
# Professor: Vitor Coutinho
# Atividade: Lista de Exercícios – Questão 1 (string.h)
# Arquivo: ops_util.asm
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
.globl print_2dig
.globl print_datahora

# ------------------------------------------------------------
# print_2dig(a0=0..99)
# Imprime exatamente dois dígitos (00..99)
# ------------------------------------------------------------
print_2dig:
    li   $t0, 10
    divu $a0, $t0
    mflo $t1                
    mfhi $t2                
    li   $v0, 11
    addiu $a0, $t1, 48       
    syscall
    li   $v0, 11
    addiu $a0, $t2, 48       
    syscall
    jr   $ra

# ------------------------------------------------------------
# print_datahora()
# imprime: DD/MM/AAAA HH:MM:SS   (sem newline)
# L? globais de data.asm: curr_day, curr_mon, curr_year, curr_hour, curr_min, curr_sec
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

    # AAAA (4 d?gitos)
    la   $t0, curr_year
    lw   $a0, 0($t0)
    jal  __pu_print4

    # espa?o entre data e hora
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

    # ep?logo
    lw    $t2,  0($sp)
    lw    $t1,  4($sp)
    lw    $t0,  8($sp)
    lw    $ra, 12($sp)
    addiu $sp, $sp, 16
    jr    $ra

# ------------------------------------------------------------
# __pu_print4(a0=0..9999) -> imprime quatro d?gitos (0000..9999)
# (r?tulo interno; n?o exportado)
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


