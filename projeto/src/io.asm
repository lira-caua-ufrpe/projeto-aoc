# ============================================================
# io.asm – wrappers simples de I/O (terminal padrão)
# ============================================================
.text
.globl print_str, print_int, read_line

# print_str(a0=addr)
print_str:
    li $v0,4
    syscall
    jr $ra

# print_int(a0=int)
print_int:
    li $v0,1
    syscall
    jr $ra

# read_line(a0=buffer, a1=maxlen) -> lê até '\n' (usa syscall 8)
read_line:
    li $v0,8
    syscall
    jr $ra
