# io.asm — primitivas de E/S via syscall (terminal padrão)

.text
.globl print_str
.globl read_line

# print_str(a0=addr)
print_str:
    li   $v0, 4
    syscall
    jr   $ra

# read_line(a0=buf, a1=max) -> v0 = len (sem '\n')
# Usa syscall 8 e depois troca '\n' por '\0'
read_line:
    # syscall read_string
    move $t0, $a0          # buf
    move $t1, $a1          # max
    move $a0, $t0
    move $a1, $t1
    li   $v0, 8
    syscall

    # varre até '\n' ou '\0'
    move $t2, $t0

RL_SCAN:
    lb   $t3, 0($t2)
    beq  $t3, $zero, RL_DONE
    li   $t4, 10           # '\n'
    beq  $t3, $t4, RL_CUT
    addi $t2, $t2, 1
    j    RL_SCAN

RL_CUT:
    sb   $zero, 0($t2)

RL_DONE:
    subu $v0, $t2, $t0     # len
    jr   $ra
