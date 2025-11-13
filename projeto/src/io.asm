# io.asm — rotinas básicas de E/S via syscalls (terminal MARS)

.text
.globl print_str
.globl read_line
.globl strip_line_end

# ------------------------------------------------------------
# print_str(a0=addr) -> imprime string '\0'-terminada (syscall 4)
# ------------------------------------------------------------
print_str:
    beq  $a0, $zero, print_str_end
    li   $v0, 4          # print_string
    syscall
print_str_end:
    jr   $ra

# ------------------------------------------------------------
# read_line(a0=buf, a1=maxlen) -> v0 = len (sem '\n')
# Usa syscall 8 (read_string), remove '\n' se presente e
# retorna o tamanho (sem contar '\0').
# ------------------------------------------------------------
read_line:
    # salva $ra, $t0-$t3
    addiu $sp, $sp, -20
    sw    $ra, 16($sp)
    sw    $t0, 12($sp)
    sw    $t1, 8($sp)
    sw    $t2, 4($sp)
    sw    $t3, 0($sp)

    # chamada de leitura
    move  $t0, $a0        # t0 = buf
    move  $t1, $a1        # t1 = maxlen
    move  $a0, $t0
    move  $a1, $t1
    li    $v0, 8          # read_string
    syscall               # lê até (maxlen-1), termina com '\0'

    # varre para achar '\n' e contar len
    move  $t2, $t0        # cursor
    move  $v0, $zero      # len
RL_LOOP:
    lb    $t3, 0($t2)
    beq   $t3, $zero, RL_END     # fim da string
    beq   $t3, 10, RL_NEWLINE    # '\n' (ASCII 10)
    addiu $v0, $v0, 1
    addiu $t2, $t2, 1
    j     RL_LOOP

RL_NEWLINE:
    # sobrescreve '\n' com '\0' e encerra
    sb    $zero, 0($t2)
    # v0 já é o len sem '\n'
    j     RL_CLEANUP

RL_END:
    # terminou sem '\n'
    nop

RL_CLEANUP:
    # restaura registradores
    lw    $t3, 0($sp)
    lw    $t2, 4($sp)
    lw    $t1, 8($sp)
    lw    $t0, 12($sp)
    lw    $ra, 16($sp)
    addiu $sp, $sp, 20
    jr    $ra

# ------------------------------------------------------------
# strip_line_end(a0=buf) -> v0=len
# Remove \n \r espaço e \t à direita; retorna novo comprimento.
# ------------------------------------------------------------
strip_line_end:
    beq  $a0, $zero, sle_nullptr       # não tocar memória se ponteiro nulo

    move $t0, $a0              # t0 = ptr = buf

# encontra o '\0'
sle_scan:
    lb   $t1, 0($t0)
    beq  $t1, $zero, sle_at_end
    addiu $t0, $t0, 1
    j    sle_scan

# t0 aponta para o '\0' -> último índice real é t0-1
sle_at_end:
    addiu $t0, $t0, -1
    blt  $t0, $a0, sle_empty

# apaga enquanto for \n \r ' ' \t
sle_trim_loop:
    blt  $t0, $a0, sle_empty
    lb   $t1, 0($t0)
    li   $t2, 10
    beq  $t1, $t2, sle_wipe
    li   $t2, 13
    beq  $t1, $t2, sle_wipe
    li   $t2, 32
    beq  $t1, $t2, sle_wipe
    li   $t2, 9
    bne  $t1, $t2, sle_done
sle_wipe:
    sb   $zero, 0($t0)
    addiu $t0, $t0, -1
    j    sle_trim_loop

sle_done:
    subu $v0, $t0, $a0
    addiu $v0, $v0, 1
    jr   $ra

sle_empty:
    sb   $zero, 0($a0)
    move $v0, $zero
    jr   $ra

sle_nullptr:
    move $v0, $zero
    jr   $ra
