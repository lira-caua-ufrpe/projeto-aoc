# ============================================================
# Universidade Federal Rural de Pernambuco (UFRPE)
# Disciplina: Projetos 1 (PE1) – 1a VA
# Professor: Vitor
# Atividade: Lista de Exercícios – Questão 1 (string.h)
# Arquivo: ex01.asm
# Grupo: <nomes dos integrantes>
# Semestre letivo: 2025.2
# Descrição: strcpy, memcpy e main com casos de teste.
# Convenções:
#   - Parâmetros: strcpy(a0=dst, a1=src) -> v0=dst
#                 memcpy(a0=dst, a1=src, a2=num) -> v0=dst
#   - Temporários: $t0..$t4
#   - Sem chamadas aninhadas -> não precisa salvar $ra.
# ============================================================

.data
# ---- buffers/testes de string ----
origem:         .asciiz "UFRPE"
destino:        .space  32

# ---- buffers/testes de memcpy ----
mem_src:        .byte 1,2,3,4,5,6,7,8
mem_dst:        .space 8
sep:            .asciiz " | "

# ---- mensagens ----
msg_copy:       .asciiz "strcpy -> dst: "
msg_memcpy:     .asciiz "memcpy 8 bytes, mem_dst = "
msg_nl:         .asciiz "\n"

.text
.globl main
.globl strcpy
.globl memcpy

# ------------------------------------------------------------
# main primeiro, para o MARS iniciar aqui
# ------------------------------------------------------------
main:
    # ---------- Teste strcpy ----------
    la   $a0, destino          # $a0 = &destino
    la   $a1, origem           # $a1 = &origem
    jal  strcpy

    # imprime "strcpy -> dst: "
    li   $v0, 4
    la   $a0, msg_copy
    syscall

    # imprime destino (string)
    li   $v0, 4
    la   $a0, destino
    syscall

    # \n
    li   $v0, 4
    la   $a0, msg_nl
    syscall

    # ---------- Teste memcpy (8 bytes) ----------
    la   $a0, mem_dst          # dst
    la   $a1, mem_src          # src
    li   $a2, 8                # num = 8
    jal  memcpy                # copia 8 bytes

    # imprime rótulo
    li   $v0, 4
    la   $a0, msg_memcpy
    syscall

    # imprime bytes de mem_dst como inteiros
    la   $t0, mem_dst          # cursor de leitura
    li   $t1, 8                # contador
print_bytes:
    lb   $t2, 0($t0)           # lê byte (sign-extended; aqui ok pois 1..8)
    move $a0, $t2
    li   $v0, 1                # print_int
    syscall

    addi $t0, $t0, 1           # avança
    addi $t1, $t1, -1          # decrementa

    bgtz $t1, print_sep        # se ainda restam bytes, imprime separador
    j    end_line

print_sep:
    li   $v0, 4
    la   $a0, sep
    syscall
    bgtz $t1, print_bytes      # volta pro próximo byte

end_line:
    li   $v0, 4
    la   $a0, msg_nl
    syscall

    # ---------- encerra ----------
    li   $v0, 10
    syscall

# ------------------------------------------------------------
# strcpy(a0=dst, a1=src) -> v0 = dst
# Copia bytes de src para dst até (e incluindo) o '\0'.
# ------------------------------------------------------------
strcpy:
    move $t0, $a0              # cursor dst
    move $t1, $a1              # cursor src
copy_loop:
    lb   $t2, 0($t1)           # t2 = *src
    sb   $t2, 0($t0)           # *dst = *src
    addi $t1, $t1, 1           # avança src
    addi $t0, $t0, 1           # avança dst
    bne  $t2, $zero, copy_loop # continua até copiar '\0'
    move $v0, $a0              # retorno = dst original
    jr   $ra

# ------------------------------------------------------------
# memcpy(a0=dst, a1=src, a2=num) -> v0 = dst
# Copia exatamente 'num' bytes de src para dst (não para em '\0').
# ------------------------------------------------------------
memcpy:
    move $t0, $a0              # cursor dst
    move $t1, $a1              # cursor src
    move $t3, $a2              # contador
    beq  $t3, $zero, mem_done  # se num==0, nada a fazer
mem_loop:
    lb   $t2, 0($t1)           # lê byte de src
    sb   $t2, 0($t0)           # grava em dst
    addi $t1, $t1, 1           # avança src
    addi $t0, $t0, 1           # avança dst
    addi $t3, $t3, -1          # decrementa contador
    bgtz $t3, mem_loop         # continua enquanto > 0
mem_done:
    move $v0, $a0              # retorno = dst original
    jr   $ra
