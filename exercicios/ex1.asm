# ============================================================
# Universidade Federal Rural de Pernambuco (UFRPE)
# Disciplina: Projetos 1 (PE1) – 1a VA
# Professor: Vitor
# Atividade: Lista de Exercícios – Questão 1 (string.h)
# Arquivo: ex01.asm
# Grupo: <nomes dos integrantes>
# Semestre letivo: 2025.2
# Descrição: strcpy, memcpy, strcmp, strncmp, strcat + main com testes.
# Convenções:
#   - strcpy(a0=dst, a1=src)              -> v0=dst
#   - memcpy(a0=dst, a1=src, a2=num)      -> v0=dst
#   - strcmp(a0=str1, a1=str2)            -> v0 (<0, 0, >0)
#   - strncmp(a0=str1, a1=str2, a3=num)   -> v0 (<0, 0, >0)
#   - strcat(a0=dst, a1=src)              -> v0=dst
#   - Temporários: $t0..$t9 (somente)
# ============================================================

.data
# ---- buffers/testes de string ----
origem:         .asciiz "UFRPE"
origem2:        .asciiz "UFRPa"       # difere em 'E'(69) vs 'a'(97)
destino:        .space  32
copia:          .space  32            # para preparar strings iguais
sufixo:         .asciiz "-PE"

# ---- buffers/testes de memcpy ----
mem_src:        .byte 1,2,3,4,5,6,7,8
mem_dst:        .space 8
sep:            .asciiz " | "

# ---- mensagens ----
msg_copy:       .asciiz "strcpy -> dst: "
msg_memcpy:     .asciiz "memcpy 8 bytes, mem_dst = "
msg_cmp_eq:     .asciiz "strcmp(\"UFRPE\",\"UFRPE\") = "
msg_cmp_ne:     .asciiz "strcmp(\"UFRPE\",\"UFRPa\") = "
msg_ncmp3:      .asciiz "strncmp(\"UFRPE\",\"UFRPa\",3) = "
msg_ncmp5:      .asciiz "strncmp(\"UFRPE\",\"UFRPa\",5) = "
msg_cat:        .asciiz "strcat(dst,\"-PE\") -> dst: "
msg_nl:         .asciiz "\n"

.text
.globl main
.globl strcpy
.globl memcpy
.globl strcmp
.globl strncmp
.globl strcat

# ------------------------------------------------------------
# main primeiro, para o MARS iniciar aqui
# ------------------------------------------------------------
main:
    # ---------- Teste strcpy ----------
    la   $a0, destino
    la   $a1, origem
    jal  strcpy

    li   $v0, 4
    la   $a0, msg_copy
    syscall

    li   $v0, 4
    la   $a0, destino
    syscall

    li   $v0, 4
    la   $a0, msg_nl
    syscall

    # ---------- Teste memcpy (8 bytes) ----------
    la   $a0, mem_dst
    la   $a1, mem_src
    li   $a2, 8
    jal  memcpy

    li   $v0, 4
    la   $a0, msg_memcpy
    syscall

    la   $t0, mem_dst
    li   $t1, 8
print_bytes:
    lb   $t2, 0($t0)           # lê byte
    move $a0, $t2
    li   $v0, 1                # print_int
    syscall

    addi $t0, $t0, 1
    addi $t1, $t1, -1
    bgtz $t1, print_sep
    j    end_line

print_sep:
    li   $v0, 4
    la   $a0, sep
    syscall
    bgtz $t1, print_bytes

end_line:
    li   $v0, 4
    la   $a0, msg_nl
    syscall

    # ---------- Teste strcmp: iguais ----------
    # prepara copia = "UFRPE"
    la   $a0, copia
    la   $a1, origem
    jal  strcpy

    la   $a0, origem           # str1
    la   $a1, copia            # str2 (igual)
    jal  strcmp
    move $t4, $v0              # salva retorno

    li   $v0, 4
    la   $a0, msg_cmp_eq
    syscall

    move $a0, $t4              # imprime retorno salvo
    li   $v0, 1
    syscall

    li   $v0, 4
    la   $a0, msg_nl
    syscall

    # ---------- Teste strcmp: diferentes ----------
    la   $a0, origem           # "UFRPE"
    la   $a1, origem2          # "UFRPa"
    jal  strcmp
    move $t5, $v0              # salva retorno

    li   $v0, 4
    la   $a0, msg_cmp_ne
    syscall

    move $a0, $t5
    li   $v0, 1
    syscall

    li   $v0, 4
    la   $a0, msg_nl
    syscall

    # ---------- Teste strncmp ----------
    # Caso 1: n=3 -> "UFR" == "UFR" => 0
    la   $a0, origem
    la   $a1, origem2
    li   $a3, 3                 # n=3
    jal  strncmp
    move $t6, $v0

    li   $v0, 4
    la   $a0, msg_ncmp3
    syscall

    move $a0, $t6
    li   $v0, 1
    syscall

    li   $v0, 4
    la   $a0, msg_nl
    syscall

    # Caso 2: n=5 -> compara até o 5o char (E vs a) => 69-97 = -28
    la   $a0, origem
    la   $a1, origem2
    li   $a3, 5                 # n=5
    jal  strncmp
    move $t7, $v0

    li   $v0, 4
    la   $a0, msg_ncmp5
    syscall

    move $a0, $t7
    li   $v0, 1
    syscall

    li   $v0, 4
    la   $a0, msg_nl
    syscall

    # ---------- Teste strcat ----------
    # destino já contém "UFRPE" do teste do strcpy; vamos concatenar "-PE"
    la   $a0, destino          # dst
    la   $a1, sufixo           # src "-PE"
    jal  strcat

    li   $v0, 4
    la   $a0, msg_cat          # "strcat(dst,\"-PE\") -> dst: "
    syscall

    li   $v0, 4
    la   $a0, destino          # imprime "UFRPE-PE"
    syscall

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
    beq  $t3, $zero, mem_done
mem_loop:
    lb   $t2, 0($t1)
    sb   $t2, 0($t0)
    addi $t1, $t1, 1
    addi $t0, $t0, 1
    addi $t3, $t3, -1
    bgtz $t3, mem_loop
mem_done:
    move $v0, $a0
    jr   $ra

# ------------------------------------------------------------
# strcmp(a0=str1, a1=str2) -> v0:
#   <0 se str1 < str2 ; 0 se iguais ; >0 se str1 > str2
# Retorna (byte1 - byte2) no 1º ponto de diferença.
# ------------------------------------------------------------
strcmp:
    move $t0, $a0              # p1
    move $t1, $a1              # p2
strcmp_loop:
    lb   $t2, 0($t0)           # c1
    lb   $t3, 0($t1)           # c2
    beq  $t2, $t3, strcmp_next # se iguais, avança
    sub  $v0, $t2, $t3         # v0 = c1 - c2
    jr   $ra
strcmp_next:
    beq  $t2, $zero, strcmp_eq # fim de ambas as strings
    addi $t0, $t0, 1
    addi $t1, $t1, 1
    j    strcmp_loop
strcmp_eq:
    move $v0, $zero
    jr   $ra

# ------------------------------------------------------------
# strncmp(a0=str1, a1=str2, a3=num) -> v0:
# Compara até num caracteres ou até encontrar '\0' em algum lado.
# Retorna (byte1 - byte2) no 1º ponto de diferença; 0 se iguais
# nos 'num' caracteres comparados.
# ------------------------------------------------------------
strncmp:
    move $t0, $a0              # p1
    move $t1, $a1              # p2
    move $t4, $a3              # num restante
    beq  $t4, $zero, ncmp_eq   # n==0 => iguais
ncmp_loop:
    lb   $t2, 0($t0)           # c1
    lb   $t3, 0($t1)           # c2
    bne  $t2, $t3, ncmp_diff   # se diferentes, retorna diff
    beq  $t2, $zero, ncmp_eq   # se c1==c2==0, terminou iguais
    addi $t0, $t0, 1           # avança p1
    addi $t1, $t1, 1           # avança p2
    addi $t4, $t4, -1          # consome 1 caractere
    bgtz $t4, ncmp_loop        # se ainda resta, continua
ncmp_eq:
    move $v0, $zero            # iguais (até 'num' ou '\0')
    jr   $ra
ncmp_diff:
    sub  $v0, $t2, $t3         # v0 = c1 - c2
    jr   $ra

# ------------------------------------------------------------
# strcat(a0=dst, a1=src) -> v0 = dst
# Encontra o '\0' de dst e copia src a partir dali, incluindo '\0'.
# ------------------------------------------------------------
strcat:
    move $t0, $a0              # t0 = cursor em dst
    move $t1, $a1              # t1 = cursor em src
# acha o fim de dst
cat_seek:
    lb   $t2, 0($t0)           # lê byte em dst
    beq  $t2, $zero, cat_copy  # parou no '\0'
    addi $t0, $t0, 1           # avança dst
    j    cat_seek
# copia src (inclui '\0')
cat_copy:
    lb   $t3, 0($t1)           # lê de src
    sb   $t3, 0($t0)           # grava em dst
    addi $t1, $t1, 1           # avança src
    addi $t0, $t0, 1           # avança dst
    bne  $t3, $zero, cat_copy  # até copiar o '\0'
    move $v0, $a0              # retorno = dst original
    jr   $ra
