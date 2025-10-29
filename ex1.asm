# ============================================================
# Universidade Federal Rural de Pernambuco (UFRPE)
# Disciplina: Projetos 1 (PE1) – 1a VA
# Professor: Vitor
# Atividade: Lista de Exercícios – Questão 1 (funções string.h)
# Arquivo: ex1.asm
# Grupo: <nomes completos dos integrantes>
# Semestre letivo: 2025.2
# Descrição: Implementa strcpy, memcpy, strcmp, strncmp, strcat
#            e um main com casos de teste no MARS.
# Convenções:
#   - Parâmetros e retorno conforme enunciado.
#   - $a0..$a3: args | $v0: retorno | $t0..$t9: temporários
#   - Não usa $s* nem chama outras funções -> não precisa salvar $ra.
#   - Todas as funções retornam imediatamente via jr $ra.
# ============================================================

.data
# ---- buffers para testes ----
src_str:        .asciiz "UFRPE"
src_str2:       .asciiz "UFRPa"           # difere no último caractere (e vs a)
dst_buf:        .space 32                 # destino genérico (strcpy/strcat)
dst_buf2:       .space 32                 # outro destino
mem_src:        .byte 1,2,3,4,5,6,7,8     # bytes genéricos p/ memcpy
mem_dst:        .space 8

# ---- mensagens de apoio ----
msg_nl:         .asciiz "\n"
msg_copy:       .asciiz "strcpy -> dst: "
msg_cat:        .asciiz "strcat(dst,\"-PE\") -> dst: "
msg_cmp_eq:     .asciiz "strcmp(\"UFRPE\",\"UFRPE\") = "
msg_cmp_ne:     .asciiz "strcmp(\"UFRPE\",\"UFRPa\") = "
msg_ncmp3:      .asciiz "strncmp(\"UFRPE\",\"UFRPa\",3) = "
msg_memcpy:     .asciiz "memcpy 8 bytes, mem_dst[0..7] = "
sep:            .asciiz " | "

# stringzinha para concatenar
sufixo:         .asciiz "-PE"

.text
.globl main

# ------------------------------------------------------------
# strcpy(a0=dst, a1=src) -> v0 = dst
# Copia bytes de src para dst até (e incluindo) o '\0'.
# ------------------------------------------------------------
strcpy:
    move $t0, $a0              # t0 = cursor em dst
    move $t1, $a1              # t1 = cursor em src
copy_loop:
    lb   $t2, 0($t1)           # t2 = *src
    sb   $t2, 0($t0)           # *dst = *src
    addi $t1, $t1, 1           # avança src
    addi $t0, $t0, 1           # avança dst
    bne  $t2, $zero, copy_loop # se não era '\0', continua
    move $v0, $a0              # retorno = endereço original de dst
    jr   $ra                   # fim

# ------------------------------------------------------------
# memcpy(a0=dst, a1=src, a2=num) -> v0 = dst
# Copia exatamente num bytes (não para em '\0').
# ------------------------------------------------------------
memcpy:
    move $t0, $a0              # t0 = cursor em dst
    move $t1, $a1              # t1 = cursor em src
    move $t3, $a2              # t3 = contador restante
    beq  $t3, $zero, mem_done  # se num==0, nada a fazer
mem_loop:
    lb   $t2, 0($t1)           # lê byte de src
    sb   $t2, 0($t0)           # escreve em dst
    addi $t1, $t1, 1           # avança src
    addi $t0, $t0, 1           # avança dst
    addi $t3, $t3, -1          # decrementa contador
    bgtz $t3, mem_loop         # continua enquanto > 0
mem_done:
    move $v0, $a0              # retorno = dst original
    jr   $ra

# ------------------------------------------------------------
# strcmp(a0=str1, a1=str2) -> v0:
#   <0 se str1 < str2 ; 0 se iguais ; >0 se str1 > str2
# Implementação: retorna (byte1 - byte2) no 1º ponto de diferença.
# ------------------------------------------------------------
strcmp:
    move $t0, $a0              # t0 = p1
    move $t1, $a1              # t1 = p2
strcmp_loop:
    lb   $t2, 0($t0)           # c1
    lb   $t3, 0($t1)           # c2
    beq  $t2, $t3, strcmp_next # se iguais, avança/checa fim
    sub  $v0, $t2, $t3         # v0 = c1 - c2 (negativo/zero/positivo)
    jr   $ra
strcmp_next:
    beq  $t2, $zero, strcmp_eq # chegaram num '\0' (então c1==c2==0)
    addi $t0, $t0, 1           # avança p1
    addi $t1, $t1, 1           # avança p2
    j    strcmp_loop
strcmp_eq:
    move $v0, $zero            # iguais
    jr   $ra

# ------------------------------------------------------------
# strncmp(a0=str1, a1=str2, a3=num) -> v0:
# Compara até num caracteres ou até encontrar '\0' em algum lado.
# Retorna (byte1 - byte2) no 1º ponto de diferença, ou 0 se iguais
# nos 'num' caracteres comparados.
# ------------------------------------------------------------
strncmp:
    move $t0, $a0              # t0 = p1
    move $t1, $a1              # t1 = p2
    move $t4, $a3              # t4 = num restante
    beq  $t4, $zero, ncmp_eq   # se num==0, define como iguais
ncmp_loop:
    lb   $t2, 0($t0)           # c1
    lb   $t3, 0($t1)           # c2
    bne  $t2, $t3, ncmp_diff   # se diferentes, retorna diff
    beq  $t2, $zero, ncmp_eq   # se c1==c2==0, terminou iguais
    addi $t0, $t0, 1           # avança p1
    addi $t1, $t1, 1           # avança p2
    addi $t4, $t4, -1          # consome 1 caractere
    bgtz $t4, ncmp_loop        # se ainda resta comparar, segue
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
# acha fim de dst
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

# ============================================================
# main de testes
# ============================================================
main:
    # ---------- Teste strcpy ----------
    la   $a0, dst_buf          # dst
    la   $a1, src_str          # src "UFRPE"
    jal  strcpy                # copia
    # print label
    li   $v0, 4
    la   $a0, msg_copy
    syscall
    # print dst
    li   $v0, 4
    la   $a0, dst_buf
    syscall
    # \n
    li   $v0, 4
    la   $a0, msg_nl
    syscall

    # ---------- Teste strcat (concatena "-PE") ----------
    la   $a0, dst_buf          # dst (já contém "UFRPE")
    la   $a1, sufixo           # src "-PE"
    jal  strcat
    # print label
    li   $v0, 4
    la   $a0, msg_cat
    syscall
    # print dst
    li   $v0, 4
    la   $a0, dst_buf
    syscall
    # \n
    li   $v0, 4
    la   $a0, msg_nl
    syscall

    # ---------- Teste strcmp: iguais ----------
    la   $a0, src_str          # "UFRPE"
    la   $a1, dst_buf2
    jal  strcpy                # prepara dst_buf2="UFRPE"
    la   $a0, src_str          # str1
    la   $a1, dst_buf2         # str2
    jal  strcmp
    # imprime label
    li   $v0, 4
    la   $a0, msg_cmp_eq
    syscall
    # imprime resultado (esperado 0)
    move $a0, $v0
    li   $v0, 1
    syscall
    # \n
    li   $v0, 4
    la   $a0, msg_nl
    syscall

    # ---------- Teste strcmp: diferentes ----------
    la   $a0, src_str          # "UFRPE"
    la   $a1, src_str2         # "UFRPa"
    jal  strcmp                 # espera valor > 0 ( 'E'(69) - 'a'(97) = -28 ) -> negativo
    li   $v0, 4
    la   $a0, msg_cmp_ne
    syscall
    move $a0, $v0               # imprime diff (negativo)
    li   $v0, 1
    syscall
    li   $v0, 4
    la   $a0, msg_nl
    syscall

    # ---------- Teste strncmp (3): iguais nos 3 primeiros ----------
    la   $a0, src_str          # "UFRPE"
    la   $a1, src_str2         # "UFRPa"
    li   $a3, 3                 # compara só 3 chars
    jal  strncmp                # esperado 0 (UFR == UFR)
    li   $v0, 4
    la   $a0, msg_ncmp3
    syscall
    move $a0, $v0
    li   $v0, 1
    syscall
    li   $v0, 4
    la   $a0, msg_nl
    syscall

    # ---------- Teste memcpy (8 bytes) ----------
    la   $a0, mem_dst           # dst
    la   $a1, mem_src           # src
    li   $a2, 8                 # num
    jal  memcpy
    # imprime rótulo
    li   $v0, 4
    la   $a0, msg_memcpy
    syscall
    # printa os 8 bytes como inteiros separados
    la   $t0, mem_dst           # cursor
    li   $t1, 8                 # contador
print_bytes:
    lb   $t2, 0($t0)            # lê byte
    move $a0, $t2               # prepara para print_int
    li   $v0, 1
    syscall
    addi $t0, $t0, 1            # avança
    addi $t1, $t1, -1           # decrementa
    bgtz $t1, print_sep         # se ainda tem, imprime separador
    j    fim_linha
print_sep:
    li   $v0, 4
    la   $a0, sep
    syscall
    bgtz $t1, print_bytes
fim_linha:
    li   $v0, 4
    la   $a0, msg_nl
    syscall

    # ---------- encerra ----------
    li   $v0, 10
    syscall
