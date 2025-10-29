# ============================================================
# ops_conta.asm – cadastro/consulta/alterações de conta
# ============================================================
.data
tmp_conta_num: .space 8      # 6 digitos + '\0'
tmp_conta_fmt: .space 10     # "XXXXXX-X"

.text
.globl conta_cadastrar, find_by_cpf, find_by_conta, dv_calc

# dv_calc(a0=addr str6) -> v0 = ASCII '0'..'9' ou 'X'
# regra: (d0*2)+(d1*3)+...+(d5*7) mod 11 ; se 10 -> 'X'
dv_calc:
    # t0 = ptr, t1 = i (0..5), soma em t2
    move $t0,$a0
    move $t1,$zero
    move $t2,$zero
1:  lb  $t3,0($t0)           # char
    addi $t3,$t3,-48         # '0'->0
    addi $t4,$t1,2           # peso = i+2
    mul $t5,$t3,$t4
    add $t2,$t2,$t5
    addi $t0,$t0,1
    addi $t1,$t1,1
    blt  $t1,6,1b
    # resto mod 11
    li  $t6,11
    div $t2,$t6
    mfhi $t7                  # resto
    li  $t6,10
    beq $t7,$t6,retX
    addi $v0,$t7,48           # '0'+resto
    jr  $ra
retX:
    li $v0,'X'
    jr $ra

# find_by_cpf(a0=cpf_str) -> v0 = idx (0..MAX-1) ou -1
find_by_cpf:
    la  $t0, clientes
    li  $t1, 0
1:  beq $t1, MAX_CLIENTES, notfound
    lb  $t2, CLI_ATIVO($t0)
    beq $t2,$zero, next
    addiu $a1,$t0,CLI_CPF      # a1 = cpf salvo
    move $a2,$a0               # a2 = cpf buscado
    move $a0,$a2
    move $a1,$a1
    jal strcmp
    bne $v0,$zero,next
    move $v0,$t1
    jr $ra
next:
    addiu $t0,$t0,CLI_END
    addi  $t1,$t1,1
    j 1b
notfound:
    li $v0,-1
    jr $ra

# find_by_conta(a0=conta "XXXXXX-X") -> v0 = idx ou -1
find_by_conta:
    la  $t0, clientes
    li  $t1, 0
1:  beq $t1, MAX_CLIENTES, nf
    lb  $t2, CLI_ATIVO($t0)
    beq $t2,$zero, nx
    addiu $a1,$t0,CLI_CONTA
    move $a2,$a0
    move $a0,$a2
    move $a1,$a1
    jal strcmp
    bne $v0,$zero, nx
    move $v0,$t1
    jr $ra
nx:
    addiu $t0,$t0,CLI_END
    addi  $t1,$t1,1
    j 1b
nf:
    li $v0,-1
    jr $ra

# conta_cadastrar(a0=cpf, a1=conta6, a2=nome) -> imprime msg
# Regras: checa cpf único e conta6 única; gera DV e formata "XXXXXX-X";
# cria cliente com saldo 0, limite 150000 (R$ 1500,00), dívida 0.
.globl conta_cadastrar
conta_cadastrar:
    # checar CPF existente
    move $t8,$a0
    jal  find_by_cpf
    bne  $v0,-1, err_cpf

    # checar número de conta (6 dígitos) não usado
    # formata conta "XXXXXX-X" em tmp_conta_fmt
    move $a0, $a1
    jal  dv_calc               # v0 = ASCII do DV
    move $t7,$v0               # guarda DV
    la   $t0,tmp_conta_fmt
    la   $t1,tmp_conta_num
    # copia a conta6 para tmp_conta_num e para tmp_conta_fmt
    la   $a0,tmp_conta_num
    move $a1,$a1
    jal  strcpy
    # tmp_conta_fmt = conta6 + '-' + DV + '\0'
    la   $a0,tmp_conta_fmt
    la   $a1,tmp_conta_num
    jal  strcpy
    la   $a0,tmp_conta_fmt
    la   $a1,str_hifen
    jal  strcat
    la   $a0,tmp_conta_fmt
    la   $a1,tmp_str
    sb   $t7,0($a1)           # tmp_str[0]=DV
    sb   $zero,1($a1)
    jal  strcat

    # validar unicidade da conta formatada
    la   $a0,tmp_conta_fmt
    jal  find_by_conta
    bne  $v0,-1, err_conta

    # alocar slot de cliente
    la  $t0, clientes
    li  $t1, 0
aloca_loop:
    beq $t1, MAX_CLIENTES, err_conta   # cheio (reaproveitei msg)
    lb  $t2, CLI_ATIVO($t0)
    beq $t2,$zero, achou
    addiu $t0,$t0,CLI_END
    addi  $t1,$t1,1
    j aloca_loop
achou:
    li   $t2,1
    sb   $t2, CLI_ATIVO($t0)
    # cpf
    addiu $a0,$t0,CLI_CPF
    move $a1,$t8
    jal  strcpy
    # conta formatada
    addiu $a0,$t0,CLI_CONTA
    la   $a1,tmp_conta_fmt
    jal  strcpy
    # nome
    addiu $a0,$t0,CLI_NOME
    move $a1,$a2
    jal  strcpy
    # saldos
    sw  $zero, CLI_SALDO($t0)         # saldo = 0
    li  $t3, 150000
    sw  $t3,   CLI_LIMITE($t0)        # limite = 1500,00
    sw  $zero, CLI_DIVCRED($t0)       # dívida crédito = 0
    sw  $zero, CLI_IDX_DEB($t0)
    sw  $zero, CLI_IDX_CRE($t0)

    # Mensagem de sucesso + número da conta
    la  $a0, msg_ok_cad
    jal print_str
    addiu $a0,$t0,CLI_CONTA
    jal print_str
    la  $a0, msg_nl
    jal print_str
    jr  $ra

err_cpf:
    la $a0, msg_err_cpf
    jal print_str
    jr $ra
err_conta:
    la $a0, msg_err_conta
    jal print_str
    jr $ra
