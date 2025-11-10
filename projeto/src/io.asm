# io.asm — rotinas básicas de E/S via syscalls (terminal MARS)

.text
.globl print_str
.globl read_line

# ------------------------------------------------------------
# print_str(a0=addr) -> imprime string '\0'-terminada (syscall 4)
# ------------------------------------------------------------
print_str:
    li   $v0, 4          # print_string
    syscall
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
    addi  $v0, $v0, 1
    addi  $t2, $t2, 1
    j     RL_LOOP

RL_NEWLINE:
    # sobrescreve '\n' com '\0' e encerra
    sb    $zero, 0($t2)
    # v0 já é o len sem '\n'
    j     RL_CLEANUP

RL_END:
    # terminou sem '\n' (buffer pode ter chegado ao limite)
    # v0 já contém o len contado
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
