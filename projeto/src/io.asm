# ============================================================
# Universidade Federal Rural de Pernambuco (UFRPE)
# Disciplina: Arquitetura e Organização de Computadores — 2025.2
# Avaliação: Projetos 1 (PE1) – 1a VA
# Professor: Vitor Coutinho
# Atividade: Lista de Exercícios – Questão 1 (string.h)
# Arquivo: io.asm
# Equipe: OPCODE
# Integrantes: Cauã Lira; Sérgio Ricardo; Lucas Emanuel; Vitor Emmanoel
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

# io.asm ? rotinas b?sicas de E/S via syscalls (terminal MARS)
# R11: terminal l? linha at? ENTER e s? ent?o interpreta o comando.

.text
.globl print_str
.globl read_line
.globl strip_line_end

# ------------------------------------------------------------
# print_str(a0=addr) -> imprime string '\0'-terminada (syscall 4)
# ------------------------------------------------------------
print_str:
    beq   $a0, $zero, print_str_end
    li    $v0, 4          # print_string
    syscall
print_str_end:
    jr    $ra
    nop

# ------------------------------------------------------------
# read_line(a0=buf, a1=maxlen) -> v0 = len (sem '\n')
# Usa syscall 8 (read_string), troca '\n' por '\0' se presente
# e retorna o tamanho (sem contar '\0').
# ------------------------------------------------------------
read_line:
    # salva $ra, $t0-$t3
    addiu $sp, $sp, -20
    sw    $ra, 16($sp)
    sw    $t0, 12($sp)
    sw    $t1,  8($sp)
    sw    $t2,  4($sp)
    sw    $t3,  0($sp)

    # chamada de leitura
    move  $t0, $a0        
    move  $t1, $a1        
    move  $a0, $t0
    move  $a1, $t1
    li    $v0, 8          
    syscall               

    # varre para achar '\n' e contar len
    move  $t2, $t0        
    move  $v0, $zero      
RL_LOOP:
    lb    $t3, 0($t2)
    beq   $t3, $zero, RL_END    
    beq   $t3, 10, RL_NEWLINE    
    addiu $v0, $v0, 1
    addiu $t2, $t2, 1
    j     RL_LOOP
    nop

RL_NEWLINE:
   
    sb    $zero, 0($t2)

    j     RL_CLEANUP
    nop

RL_END:
    # terminou sem '\n'
    nop

RL_CLEANUP:
    # restaura registradores
    lw    $t3,  0($sp)
    lw    $t2,  4($sp)
    lw    $t1,  8($sp)
    lw    $t0, 12($sp)
    lw    $ra, 16($sp)
    addiu $sp, $sp, 20
    jr    $ra
    nop

# ------------------------------------------------------------
# strip_line_end(a0=buf) -> v0=len
# Remove \n \r espaço e \t a direita; retorna novo comprimento.
# ------------------------------------------------------------
strip_line_end:
    beq   $a0, $zero, sle_nullptr       # nao tocar mem?ria se ponteiro nulo

    move  $t0, $a0              # t0 = ptr = buf

# encontra o '\0'
sle_scan:
    lb    $t1, 0($t0)
    beq   $t1, $zero, sle_at_end
    addiu $t0, $t0, 1
    j     sle_scan
    nop

# t0 aponta para o '\0' -> ultimo indice real ? t0-1
sle_at_end:
    addiu $t0, $t0, -1
    blt   $t0, $a0, sle_empty

# apaga enquanto for \n \r ' ' \t
sle_trim_loop:
    blt   $t0, $a0, sle_empty
    lb    $t1, 0($t0)
    li    $t2, 10              # '\n'
    beq   $t1, $t2, sle_wipe
    li    $t2, 13              # '\r'
    beq   $t1, $t2, sle_wipe
    li    $t2, 32              # ' '
    beq   $t1, $t2, sle_wipe
    li    $t2, 9               # '\t'
    bne   $t1, $t2, sle_done
sle_wipe:
    sb    $zero, 0($t0)
    addiu $t0, $t0, -1
    j     sle_trim_loop
    nop

sle_done:
    subu  $v0, $t0, $a0
    addiu $v0, $v0, 1
    jr    $ra
    nop

sle_empty:
    sb    $zero, 0($a0)
    move  $v0, $zero
    jr    $ra
    nop

sle_nullptr:
    move  $v0, $zero
    jr    $ra
    nop
