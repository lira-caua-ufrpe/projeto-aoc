# ============================================================
# UFRPE - Projetos 1 (PE1) – 1a VA
# Q1 (string.h) - Parte: strcpy + teste mínimo
# Arquivo: ex01.asm
# ============================================================

.data
origem:     .asciiz "UFRPE"
destino:    .space  32

msg_copy:   .asciiz "strcpy -> dst: "
msg_nl:     .asciiz "\n"

.text
.globl main
.globl strcpy

# ------------------------------------------------------------
# main primeiro, para o MARS iniciar aqui
# ------------------------------------------------------------
main:
    # chama strcpy(destino, origem)
    la   $a0, destino
    la   $a1, origem
    jal  strcpy

    # imprime "strcpy -> dst: "
    li   $v0, 4
    la   $a0, msg_copy
    syscall

    # imprime destino
    li   $v0, 4
    la   $a0, destino
    syscall

    # nova linha
    li   $v0, 4
    la   $a0, msg_nl
    syscall

    # encerra
    li   $v0, 10
    syscall

# ------------------------------------------------------------
# strcpy(a0=dst, a1=src) -> v0 = dst
# Copia bytes até (e incluindo) o '\0'.
# ------------------------------------------------------------
strcpy:
    move $t0, $a0              # cursor dst
    move $t1, $a1              # cursor src
copy_loop:
    lb   $t2, 0($t1)           # lê *src
    sb   $t2, 0($t0)           # grava em dst
    addi $t1, $t1, 1           # avança src
    addi $t0, $t0, 1           # avança dst
    bne  $t2, $zero, copy_loop # continua até copiar '\0'
    move $v0, $a0              # retorno = dst original
    jr   $ra
