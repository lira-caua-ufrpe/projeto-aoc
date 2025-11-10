# ops_conta.asm — handlers de comandos de conta

.text
.globl handle_conta_cadastrar   # esta é definida aqui

# (NÃO declare .globl para funções externas: print_str, read_line, strcmp,
#  strlen, strncmp, etc. Basta chamá-las com JAL.)

# ----------------- helpers locais -----------------
# is_digit(a0=ch) -> v0=1/0
is_digit:
    li   $t0, 48
    li   $t1, 57
    blt  $a0, $t0, ISD_NO
    bgt  $a0, $t1, ISD_NO
    li   $v0, 1
    jr   $ra
ISD_NO:
    move $v0, $zero
    jr   $ra

# copy_n(a0=dst, a1=src, a2=n) — não adiciona '\0'
copy_n:
    beq  $a2, $zero, CPY_END
CPY_LOOP:
    lb   $t0, 0($a1)
    sb   $t0, 0($a0)
    addi $a0, $a0, 1
    addi $a1, $a1, 1
    addi $a2, $a2, -1
    bgtz $a2, CPY_LOOP
CPY_END:
    jr   $ra

# copy_strz(a0=dst, a1=src, a2=max) -> copia até '\0' ou max-1; garante '\0'
copy_strz:
    beq  $a2, $zero, CPZ_DONE
    addi $a2, $a2, -1       # espaço útil
CPZ_LOOP:
    beq  $a2, $zero, CPZ_TERM
    lb   $t0, 0($a1)
    beq  $t0, $zero, CPZ_TERM
    sb   $t0, 0($a0)
    addi $a0, $a0, 1
    addi $a1, $a1, 1
    addi $a2, $a2, -1
    j    CPZ_LOOP
CPZ_TERM:
    sb   $zero, 0($a0)
CPZ_DONE:
    jr   $ra

# all_digits_n(a0=ptr, a1=n) -> v0=1 se os próximos n são todos [0-9]
all_digits_n:
    move $t0, $a0
    move $t1, $a1
    beq  $t1, $zero, ADN_OK
ADN_LOOP:
    lb   $t2, 0($t0)
    move $a0, $t2
    jal  is_digit
    beq  $v0, $zero, ADN_NO
    addi $t0, $t0, 1
    addi $t1, $t1, -1
    bgtz $t1, ADN_LOOP
ADN_OK:
    li   $v0, 1
    jr   $ra
ADN_NO:
    move $v0, $zero
    jr   $ra

# compute_dv(a0=addr 6 dígitos ASCII) -> v0=ASCII do DV ('0'..'9' ou 'X')
compute_dv:
    move $t0, $a0
    li   $t1, 0          # soma
    # pesos: d0*2 + d1*3 + d2*4 + d3*5 + d4*6 + d5*7
    # d0 é o menos significativo = último caractere
    addi $t0, $t0, 5     # aponta p/ último char
    li   $t2, 2          # peso inicial
    li   $t3, 0          # i
CDV_LOOP:
    lb   $t4, 0($t0)     # '0'..'9'
    addi $t4, $t4, -48   # -> 0..9
    mul  $t5, $t4, $t2
    addu $t1, $t1, $t5
    addi $t2, $t2, 1     # próximo peso
    addi $t0, $t0, -1    # retrocede
    addi $t3, $t3, 1
    blt  $t3, 6, CDV_LOOP
    # mod 11
    li   $t6, 11
    divu $t1, $t6
    mfhi $t7             # resto
    li   $t6, 10
    beq  $t7, $t6, CDV_X
    addi $v0, $t7, 48    # '0'+resto
    jr   $ra
CDV_X:
    li   $v0, 88         # 'X'
    jr   $ra

# find_free_slot() -> v0 = idx [0..49] ou -1
find_free_slot:
    la   $t0, clientes_usado
    li   $t1, 0
FFS_LOOP:
    lb   $t2, 0($t0)
    beq  $t2, $zero, FFS_OK
    addi $t0, $t0, 1
    addi $t1, $t1, 1
    blt  $t1, 50, FFS_LOOP
    li   $v0, -1
    jr   $ra
FFS_OK:
    move $v0, $t1
    jr   $ra

# find_by_cpf(a0=cpf_str) -> v0 = idx ou -1
find_by_cpf:
    la   $t0, clientes_cpf
    li   $t1, 0
FBC_LOOP:
    blt  $t1, 50, FBC_CHECK
    li   $v0, -1
    jr   $ra
FBC_CHECK:
    # pula entradas não usadas
    la   $t4, clientes_usado
    addu $t5, $t4, $t1
    lb   $t6, 0($t5)
    beq  $t6, $zero, FBC_NEXT
    # compara cpf
    move $a0, $a0           # cpf procurado
    move $a1, $t0           # cpf[i]
    jal  strcmp
    beq  $v0, $zero, FBC_FOUND
FBC_NEXT:
    addi $t0, $t0, 12       # próximo cpf
    addi $t1, $t1, 1
    j    FBC_LOOP
FBC_FOUND:
    move $v0, $t1
    jr   $ra

# find_by_conta(a0=conta_str) -> v0 = idx ou -1
find_by_conta:
    la   $t0, clientes_conta
    li   $t1, 0
FBA_LOOP:
    blt  $t1, 50, FBA_CHECK
    li   $v0, -1
    jr   $ra
FBA_CHECK:
    la   $t4, clientes_usado
    addu $t5, $t4, $t1
    lb   $t6, 0($t5)
    beq  $t6, $zero, FBA_NEXT
    move $a0, $a0
    move $a1, $t0
    jal  strcmp
    beq  $v0, $zero, FBA_FOUND
FBA_NEXT:
    addi $t0, $t0, 7
    addi $t1, $t1, 1
    j    FBA_LOOP
FBA_FOUND:
    move $v0, $t1
    jr   $ra

# handle_conta_cadastrar(a0=linha) -> v0=1 se tratou; 0 se não era esse comando
# Formato: conta_cadastrar-<CPF11>-<CONTA6>-<NOME LIVRE>
handle_conta_cadastrar:
    # confere prefixo
    la   $a1, str_cmd_cc_prefix
    jal  str_starts_with
    beq  $v0, $zero, HCC_NOPE
    move $t0, $v1          # ptr após prefixo

    # valida CPF: 11 dígitos
    move $a0, $t0
    li   $a1, 11
    jal  all_digits_n
    beq  $v0, $zero, HCC_INVALID   # cpf malformado
    # salva ponteiro pós-CPF e exige '-'
    addi $t1, $t0, 11
    lb   $t2, 0($t1)
    li   $t3, 45                  # '-'
    bne  $t2, $t3, HCC_INVALID

    # valida CONTA6: próximos 6 dígitos
    addi $t4, $t1, 1             # ptr conta
    move $a0, $t4
    li   $a1, 6
    jal  all_digits_n
    beq  $v0, $zero, HCC_INVALID
    # pós-conta deve ter '-'
    addi $t5, $t4, 6
    lb   $t6, 0($t5)
    li   $t3, 45
    bne  $t6, $t3, HCC_INVALID

    # nome = resto após '-'
    addi $t7, $t5, 1             # ptr nome
    # se vazio => inválido
    lb   $t8, 0($t7)
    beq  $t8, $zero, HCC_INVALID

    # buffers temporários na pilha: cpf[12], conta[7], nome[33]
    addiu $sp, $sp, -52
    move  $s0, $sp              # base temp
    move  $s1, $sp
    addi  $s2, $s1, 12          # conta
    addi  $s3, $s2, 7           # nome

    # copia cpf (11) + '\0'
    move $a0, $s1
    move $a1, $t0
    li   $a2, 11
    jal  copy_n
    sb   $zero, 11($s1)

    # copia conta (6) + '\0'
    move $a0, $s2
    move $a1, $t4
    li   $a2, 6
    jal  copy_n
    sb   $zero, 6($s2)

    # nome até 32 + '\0'
    move $a0, $s3
    move $a1, $t7
    li   $a2, 33
    jal  copy_strz

    # checa duplicidades
    move $a0, $s1
    jal  find_by_cpf
    bne  $v0, $zero, HCC_CPF_USED     # v0 != 0 e != -1 -> existe; mas se -1 também !=0...
    # cuidado com -1: testamos diferente:
    li   $t9, -1
    bne  $v0, $t9, HCC_CPF_USED_OK
HCC_CPF_USED_OK:

    move $a0, $s2
    jal  find_by_conta
    li   $t9, -1
    bne  $v0, $t9, HCC_ACC_USED

    # acha slot livre
    jal  find_free_slot
    li   $t9, -1
    beq  $v0, $t9, HCC_INVALID       # sem espaço
    move $t0, $v0                    # idx

    # grava usado=1
    la   $t1, clientes_usado
    addu $t1, $t1, $t0
    li   $t2, 1
    sb   $t2, 0($t1)

    # grava cpf
    la   $t1, clientes_cpf
    li   $t3, 12
    mul  $t4, $t0, $t3
    addu $t1, $t1, $t4
    move $a0, $t1
    move $a1, $s1
    li   $a2, 12
    jal  copy_n

    # grava conta
    la   $t1, clientes_conta
    li   $t3, 7
    mul  $t4, $t0, $t3
    addu $t1, $t1, $t4
    move $a0, $t1
    move $a1, $s2
    li   $a2, 7
    jal  copy_n

    # calcula DV e grava
    move $a0, $s2
    jal  compute_dv
    la   $t1, clientes_dv
    addu $t1, $t1, $t0
    sb   $v0, 0($t1)

    # grava nome
    la   $t1, clientes_nome
    li   $t3, 33
    mul  $t4, $t0, $t3
    addu $t1, $t1, $t4
    move $a0, $t1
    move $a1, $s3
    li   $a2, 33
    jal  copy_strz

    # inicializa saldo/limite/dívida
    la   $t1, clientes_saldo_cent
    li   $t3, 4
    mul  $t4, $t0, $t3
    addu $t1, $t1, $t4
    sw   $zero, 0($t1)

    la   $t1, clientes_limite_cent
    mul  $t4, $t0, $t3
    addu $t1, $t1, $t4
    lw   $t5, LIMITO_PADRAO_CENT
    sw   $t5, 0($t1)

    la   $t1, clientes_devido_cent
    mul  $t4, $t0, $t3
    addu $t1, $t1, $t4
    sw   $zero, 0($t1)

    # imprime sucesso + "Numero da conta XXXXXX-X\n"
    li   $v0, 4
    la   $a0, msg_cc_ok
    syscall

    # imprime conta (6)
    move $a0, $s2
    li   $v0, 4
    syscall

    # imprime '-'
    li   $v0, 11         # print_char
    li   $a0, 45
    syscall

    # imprime DV
    li   $v0, 11
    la   $t1, clientes_dv
    addu $t1, $t1, $t0
    lb   $a0, 0($t1)
    syscall

    # \n
    li   $v0, 11
    li   $a0, 10
    syscall

    addiu $sp, $sp, 52
    li   $v0, 1          # handled
    jr   $ra

HCC_CPF_USED:
    li   $v0, 4
    la   $a0, msg_cc_cpf_exists
    syscall
    addiu $sp, $sp, 52
    li   $v0, 1
    jr   $ra

HCC_ACC_USED:
    li   $v0, 4
    la   $a0, msg_cc_acc_exists
    syscall
    addiu $sp, $sp, 52
    li   $v0, 1
    jr   $ra

HCC_INVALID:
    # apenas não trata; deixa o main mostrar "Comando invalido"
    addiu $sp, $sp, 52
    li   $v0, 1          # ainda considero handled? Melhor NÃO:
    li   $v0, 0          # não tratado -> main decide
    jr   $ra

HCC_NOPE:
    move $v0, $zero      # não era esse comando
    jr   $ra
