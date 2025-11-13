# io.asm — rotinas básicas de E/S via syscalls (terminal MARS)
# R11: terminal lê linha até ENTER e só então interpreta o comando.

.text
.globl print_str
.globl read_line
.globl strip_line_end

# ------------------------------------------------------------
# print_str(a0=addr) -> imprime string '\0'-terminada (syscall 4)
# ------------------------------------------------------------
print_str:
    beq   $a0, $zero, print_str_end   # se ponteiro nulo, sai da função
    li    $v0, 4                      # código da syscall para print_string
    syscall                           # executa a syscall (imprime string)
print_str_end:
    jr    $ra                         # retorna
    nop                               # atraso de pipeline

# ------------------------------------------------------------
# read_line(a0=buf, a1=maxlen) -> v0 = len (sem '\n')
# Usa syscall 8 (read_string), troca '\n' por '\0' se presente
# e retorna o tamanho (sem contar '\0').
# ------------------------------------------------------------
read_line:
    # salva registradores temporários e endereço de retorno na pilha
    addiu $sp, $sp, -20
    sw    $ra, 16($sp)
    sw    $t0, 12($sp)
    sw    $t1,  8($sp)
    sw    $t2,  4($sp)
    sw    $t3,  0($sp)

    # chamada de leitura
    move  $t0, $a0        # t0 = endereço do buffer
    move  $t1, $a1        # t1 = tamanho máximo da leitura
    move  $a0, $t0        # coloca buffer em a0 para syscall
    move  $a1, $t1        # coloca tamanho em a1
    li    $v0, 8          # código da syscall read_string
    syscall               # lê string até ENTER (ou maxlen - 1)

    # varre para achar '\n' e contar o comprimento
    move  $t2, $t0        # t2 = cursor que percorre o buffer
    move  $v0, $zero      # v0 = contador de caracteres (len)
RL_LOOP:
    lb    $t3, 0($t2)                 # lê byte atual
    beq   $t3, $zero, RL_END          # se '\0', fim da string
    beq   $t3, 10, RL_NEWLINE         # se '\n' (ASCII 10), tratar separadamente
    addiu $v0, $v0, 1                 # incrementa comprimento
    addiu $t2, $t2, 1                 # avança ponteiro
    j     RL_LOOP                     # repete o loop
    nop

RL_NEWLINE:
    # substitui '\n' por '\0' e encerra
    sb    $zero, 0($t2)               # coloca fim de string
    # v0 já contém o comprimento sem o '\n'
    j     RL_CLEANUP
    nop

RL_END:
    # terminou sem encontrar '\n'
    nop

RL_CLEANUP:
    # restaura registradores salvos
    lw    $t3,  0($sp)
    lw    $t2,  4($sp)
    lw    $t1,  8($sp)
    lw    $t0, 12($sp)
    lw    $ra, 16($sp)
    addiu $sp, $sp, 20                # desfaz espaço da pilha
    jr    $ra                         # retorna
    nop

# ------------------------------------------------------------
# strip_line_end(a0=buf) -> v0=len
# Remove \n \r espaço e \t à direita; retorna novo comprimento.
# ------------------------------------------------------------
strip_line_end:
    beq   $a0, $zero, sle_nullptr     # se ponteiro nulo, retorna 0 sem tocar memória

    move  $t0, $a0                    # t0 = ponteiro para início do buffer

# encontra o '\0' (fim da string)
sle_scan:
    lb    $t1, 0($t0)                 # lê byte atual
    beq   $t1, $zero, sle_at_end      # se '\0', achou o fim
    addiu $t0, $t0, 1                 # avança ponteiro
    j     sle_scan                    # continua varrendo
    nop

# t0 aponta para o '\0' -> último caractere real é t0-1
sle_at_end:
    addiu $t0, $t0, -1                # volta uma posição
    blt   $t0, $a0, sle_empty         # se string vazia, pula para sle_empty

# apaga enquanto for \n \r ' ' ou \t
sle_trim_loop:
    blt   $t0, $a0, sle_empty         # se chegou ao início, termina
    lb    $t1, 0($t0)                 # lê caractere atual
    li    $t2, 10                     # '\n'
    beq   $t1, $t2, sle_wipe
    li    $t2, 13                     # '\r'
    beq   $t1, $t2, sle_wipe
    li    $t2, 32                     # ' '
    beq   $t1, $t2, sle_wipe
    li    $t2, 9                      # '\t'
    bne   $t1, $t2, sle_done          # se diferente de \t, termina
sle_wipe:
    sb    $zero, 0($t0)               # substitui caractere por '\0'
    addiu $t0, $t0, -1                # anda uma posição para trás
    j     sle_trim_loop               # repete limpeza
    nop

sle_done:
    subu  $v0, $t0, $a0               # calcula comprimento novo (t0 - início)
    addiu $v0, $v0, 1                 # ajusta comprimento final
    jr    $ra                         # retorna
    nop

sle_empty:
    sb    $zero, 0($a0)               # coloca fim de string no início
    move  $v0, $zero                  # comprimento = 0
    jr    $ra
    nop

sle_nullptr:
    move  $v0, $zero                  # se ponteiro nulo, retorna 0
    jr    $ra
    nop

