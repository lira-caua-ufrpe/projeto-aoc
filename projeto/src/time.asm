# ============================================================
# time.asm — R4: configurar e manter data/hora usando syscall 30
# $a0: recebe o tempo atual em ms da syscall 30
# ============================================================

############################
# Configuração anti-turbo  #
############################
        .data
MS_PER_SEC:       .word 1000      # 1 segundo lógico = 1000 ms
DELTA_CAP_SEC:    .word 5         # limita máximo de 5s por tick para evitar saltos

        .text
        .globl tick_datetime
        .globl handle_datetime_set
        .globl handle_datetime_show
        .globl print_datetime

# ============================================================
# tick_datetime()
# Atualiza a data/hora com base no tempo real
# ============================================================
tick_datetime:
    addiu $sp,$sp,-44           # reserva espaço para salvar registradores
    sw $ra,40($sp)
    sw $s0,36($sp)
    sw $s1,32($sp)
    sw $s2,28($sp)
    sw $s3,24($sp)
    sw $s4,20($sp)
    sw $s5,16($sp)
    sw $s6,12($sp)
    sw $s7,8($sp)

    # now_ms = tempo atual em ms (syscall 30)
    li  $v0,30
    syscall
    move $t0,$a0

    la  $t1,ms_last
    lw  $t2,0($t1)              # recupera último tempo registrado
    beq $t2,$zero, TD_INIT      # primeira chamada: inicializa base

    # delta = now - last (considera wrap se now < last)
    subu $t3,$t0,$t2
    sltu $t4,$t0,$t2
    bne $t4,$zero, TD_SAVE_ONLY # se wrap, só atualiza last

    # Limita delta máximo
    la   $t7,MS_PER_SEC
    lw   $t7,0($t7)
    la   $t8,DELTA_CAP_SEC
    lw   $t8,0($t8)
    mul  $t9,$t7,$t8             # max_delta = 1000*5
    sltu $a2,$t9,$t3
    beq  $a2,$zero, TD_CLAMP_OK
    move $t3,$t9
TD_CLAMP_OK:

    # total_ms = ms_accum + delta
    la  $t5,ms_accum
    lw  $t6,0($t5)
    addu $t6,$t6,$t3

    # converte para segundos: q = total_ms / 1000, r = resto
    divu $t6,$t7
    mflo $s0                 # q: segundos a adicionar
    mfhi $t6                 # resto ms
    sw   $t6,0($t5)          # atualiza ms_accum
    beq  $s0,$zero, TD_SAVE_ONLY

# ---------- adiciona q segundos com rollover ----------
TD_ADD_ONE_SEC:
    beq  $s0,$zero, TD_SAVE_ONLY

    # incrementa segundos
    la  $s1,curr_sec
    lw  $s2,0($s1)
    addiu $s2,$s2,1
    li  $a0,60
    slt  $a1,$s2,$a0
    bne  $a1,$zero, TD_SAVESEC
    move $s2,$zero

    # incrementa minutos se necessário
    la  $s3,curr_min
    lw  $s4,0($s3)
    addiu $s4,$s4,1
    li  $a0,60
    slt  $a1,$s4,$a0
    bne  $a1,$zero, TD_SAVEMIN
    move $s4,$zero

    # incrementa horas se necessário
    la  $s5,curr_hour
    lw  $s6,0($s5)
    addiu $s6,$s6,1
    li  $a0,24
    slt  $a1,$s6,$a0
    bne  $a1,$zero, TD_SAVEHOUR
    move $s6,$zero

    # incrementa dia
    la  $s7,curr_day
    lw  $t8,0($s7)
    addiu $t8,$t8,1

    # verifica dias do mês
    la  $a0,curr_mon
    lw  $a0,0($a0)
    la  $a1,curr_year
    lw  $a1,0($a1)
    jal days_in_month
    nop
    move $t9,$v0

    slt  $a1,$t8,$t9
    bne  $a1,$zero, TD_SAVEDAY
    beq  $t8,$t9, TD_SAVEDAY
    li   $t8,1

    # incrementa mês e possivelmente ano
    la  $t6,curr_mon
    lw  $t7,0($t6)
    addiu $t7,$t7,1
    li   $a0,13
    slt  $a1,$t7,$a0
    bne  $a1,$zero, TD_SAVEMON
    li   $t7,1
    la   $a1,curr_year
    lw   $v1,0($a1)
    addiu $v1,$v1,1
    sw   $v1,0($a1)

TD_SAVEMON:
    sw  $t7,0($t6)
TD_SAVEDAY:
    sw  $t8,0($s7)
TD_SAVEHOUR:
    sw  $s6,0($s5)
TD_SAVEMIN:
    sw  $s4,0($s3)
TD_SAVESEC:
    sw  $s2,0($s1)

    addiu $s0,$s0,-1
    j TD_ADD_ONE_SEC

# Atualiza referência de tempo ms_last
TD_SAVE_ONLY:
    sw  $t0,0($t1)
    j TD_END

TD_INIT:
    sw  $t0,0($t1)
    la  $t5,ms_accum
    sw  $zero,0($t5)

TD_END:
    lw $s7,8($sp)
    lw $s6,12($sp)
    lw $s5,16($sp)
    lw $s4,20($sp)
    lw $s3,24($sp)
    lw $s2,28($sp)
    lw $s1,32($sp)
    lw $s0,36($sp)
    lw $ra,40($sp)
    addiu $sp,$sp,44
    jr $ra
    nop

# ============================================================
# days_in_month(a0=mes 1..12, a1=ano) -> v0=dias do mês
# ============================================================
days_in_month:
    li  $t0,2
    bne $a0,$t0, DIM_NOT_FEB   # não é fevereiro

    # ano bissexto?
    move $t1,$a1
    li   $t2,400
    divu $t1,$t2
    mfhi $t3
    beq   $t3,$zero, DIM_FEB_29
    move $t1,$a1
    li   $t2,4
    divu $t1,$t2
    mfhi $t3
    bne  $t3,$zero, DIM_FEB_28
    move $t1,$a1
    li   $t2,100
    divu $t1,$t2
    mfhi $t3
    beq  $t3,$zero, DIM_FEB_28

DIM_FEB_29:
    li $v0,29
    jr $ra
    nop
DIM_FEB_28:
    li $v0,28
    jr $ra
    nop

DIM_NOT_FEB:
    la  $t0,month_days_norm   # vetor com dias normais do mês
    addiu $a0,$a0,-1
    sll $a0,$a0,2
    addu $t0,$t0,$a0
    lw  $v0,0($t0)
    jr $ra
    nop

# ============================================================
# handle_datetime_set(a0=inp_buf) -> v0=1/0
# Lê string DD/MM/AAAA-HH:MM:SS e atualiza o relógio
# ============================================================
handle_datetime_set:
    addiu $sp,$sp,-40
    sw $ra,36($sp)
    sw $s0,32($sp)
    sw $s1,28($sp)
    sw $s2,24($sp)
    sw $s3,20($sp)
    sw $s4,16($sp)
    sw $s5,12($sp)
    sw $s6,8($sp)
    sw $s7,4($sp)

    # verifica prefixo "datetime_set-" (str_cmd_time_set)
    move $t0,$a0
    la   $t1,str_cmd_time_set
HDS_PREF:
    lb   $t2,0($t1)
    beq  $t2,$zero,HDS_PREF_OK
    lb   $t3,0($t0)
    bne  $t2,$t3,HDS_NOT_MINE
    addiu $t1,$t1,1
    addiu $t0,$t0,1
    j    HDS_PREF

# Lê dia, mês, ano, hora, minuto, segundo
HDS_PREF_OK:
    jal read_2digits
    nop
    move $s0,$v0      # dia
    lb $t2,0($t0)
    li $t3,'/'
    bne $t2,$t3,HDS_BADFMT
    addiu $t0,$t0,1
    jal read_2digits
    nop
    move $s1,$v0      # mês
    lb $t2,0($t0)
    li $t3,'/'
    bne $t2,$t3,HDS_BADFMT
    addiu $t0,$t0,1
    jal read_4digits
    nop
    move $s2,$v0      # ano
    lb $t2,0($t0)
    li $t3,'-'
    bne $t2,$t3,HDS_BADFMT
    addiu $t0,$t0,1
    lb $t2,0($t0)
    li $t3,' '
    bne $t2,$t3,HDS_HH
    addiu $t0,$t0,1

HDS_HH:
    jal read_2digits
    nop
    move $s3,$v0      # hora
    lb $t2,0($t0)
    li $t3,':'
    bne $t2,$t3,HDS_BADFMT
    addiu $t0,$t0,1
    jal read_2digits
    nop
    move $s4,$v0      # minuto
    lb $t2,0($t0)
    li $t3,':'
    bne $t2,$t3,HDS_BADFMT
    addiu $t0,$t0,1
    jal read_2digits
    nop
    move $s5,$v0      # segundo

    # valida intervalos
    blez $s0,HDS_RANGE
    blez $s1,HDS_RANGE
    blez $s2,HDS_RANGE
    li   $t2,12
    bgt  $s1,$t2,HDS_RANGE
    li   $t2,23
    bgt  $s3,$t2,HDS_RANGE
    li   $t2,59
    bgt  $s4,$t2,HDS_RANGE
    bgt  $s5,$t2,HDS_RANGE

    # valida dia com days_in_month
    move $a0,$s1
    move $a1,$s2
    jal  days_in_month
    nop
    move $t2,$v0
    bgt  $s0,$t2,HDS_RANGE

    # aplica valores
    la $t2,curr_day
    sw $s0,0($t2)
    la $t2,curr_mon
    sw $s1,0($t2)
    la $t2,curr_year
    sw $s2,0($t2)
    la $t2,curr_hour
    sw $s3,0($t2)
    la $t2,curr_min
    sw $s4,0($t2)
    la $t2,curr_sec
    sw $s5,0($t2)

    # reinicia referência de tempo syscall 30
    li  $v0,30
    syscall
    la  $t2,ms_last
    sw  $a0,0($t2)
    la  $t2,ms_accum
    sw  $zero,0($t2)

    li  $v0,4
    la  $a0,msg_time_set_ok
    syscall
    li  $v0,1
    j   HDS_END

# mensagens de erro
HDS_RANGE:
    li $v0,4
    la $a0,msg_time_range
    syscall
    li $v0,1
    j  HDS_END

HDS_BADFMT:
    li $v0,4
    la $a0,msg_time_badfmt
    syscall
    li $v0,1
    j  HDS_END

HDS_NOT_MINE:
    move $v0,$zero

HDS_END:
    lw $s7,4($sp)
    lw $s6,8($sp)
    lw $s5,12($sp)
    lw $s4,16($sp)
    lw $s3,20($sp)
    lw $s2,24($sp)
    lw $s1,28($sp)
    lw $s0,32($sp)
    lw $ra,36($sp)
    addiu $sp,$sp,40
    jr $ra
    nop

# ============================================================
# handle_datetime_show(a0=inp_buf) -> v0=1 se tratou, 0 caso contrário
# Atualiza a hora chamando tick_datetime() e imprime
# ============================================================
handle_datetime_show:
    addiu $sp,$sp,-16
    sw $ra,12($sp)
    sw $s0,8($sp)
    sw $s1,4($sp)

    # verifica prefixo "datetime_show-" (str_cmd_time_show)
    move $t0,$a0
    la   $t1,str_cmd_time_show
HDSH_PREF:
    lb   $t2,0($t1)
    beq  $t2,$zero,HDSH_GO       # chegou no final do prefixo
    lb   $t3,0($t0)
    bne  $t2,$t3,HDSH_NOT        # não é comando nosso
    addiu $t1,$t1,1
    addiu $t0,$t0,1
    j    HDSH_PREF

HDSH_GO:
    jal  tick_datetime           # atualiza relógio antes de mostrar
    nop
    jal  print_datetime          # imprime data/hora atual
    nop
    li   $v0,1                   # comando tratado com sucesso
    j    HDSH_END

HDSH_NOT:
    move $v0,$zero               # não é o comando

HDSH_END:
    lw $s1,4($sp)
    lw $s0,8($sp)
    lw $ra,12($sp)
    addiu $sp,$sp,16
    jr  $ra
    nop

# ============================================================
# print_datetime()
# Imprime curr_day/curr_mon/curr_year - curr_hour:curr_min:curr_sec
# ============================================================
print_datetime:
    addiu $sp,$sp,-8
    sw    $ra,4($sp)
    sw    $t0,0($sp)

    # Dia
    la  $t0,curr_day
    lw  $a0,0($t0)
    jal print_two
    nop
    li  $v0,11; li $a0,'/'; syscall

    # Mês
    la  $t0,curr_mon
    lw  $a0,0($t0)
    jal print_two
    nop
    li  $v0,11; li $a0,'/'; syscall

    # Ano
    la  $t0,curr_year
    lw  $a0,0($t0)
    jal print_four
    nop
    li  $v0,11; li $a0,' '; syscall
    li  $v0,11; li $a0,'-'; syscall
    li  $v0,11; li $a0,' '; syscall

    # Hora
    la  $t0,curr_hour
    lw  $a0,0($t0)
    jal print_two
    nop
    li  $v0,11; li $a0,':'; syscall

    # Minuto
    la  $t0,curr_min
    lw  $a0,0($t0)
    jal print_two
    nop
    li  $v0,11; li $a0,':'; syscall

    # Segundo
    la  $t0,curr_sec
    lw  $a0,0($t0)
    jal print_two
    nop
    li  $v0,11; li $a0,10; syscall       # pula linha

    lw    $t0,0($sp)
    lw    $ra,4($sp)
    addiu $sp,$sp,8
    jr  $ra
    nop

# ============================================================
# print_two(a0=0..99)
# Imprime dois dígitos com zero à esquerda
# ============================================================
print_two:
    li  $t0,10
    divu $a0,$t0
    mflo $t1            # dezena
    mfhi $t2            # unidade
    li  $v0,11
    addiu $a0,$t1,48
    syscall
    li  $v0,11
    addiu $a0,$t2,48
    syscall
    jr  $ra
    nop

# ============================================================
# print_four(a0=0..9999)
# Imprime quatro dígitos
# ============================================================
print_four:
    li  $t0,1000
    divu $a0,$t0
    mflo $t1
    mfhi $t3
    li  $v0,11
    addiu $a0,$t1,48
    syscall

    li  $t0,100
    divu $t3,$t0
    mflo $t1
    mfhi $t3
    li  $v0,11
    addiu $a0,$t1,48
    syscall

    li  $t0,10
    divu $t3,$t0
    mflo $t1
    mfhi $t2
    li  $v0,11
    addiu $a0,$t1,48
    syscall
    li  $v0,11
    addiu $a0,$t2,48
    syscall
    jr  $ra
    nop

# ============================================================
# read_2digits
# Lê dois caracteres '0'..'9' de $t0 e retorna valor em $v0
# ============================================================
read_2digits:
    lb  $t1,0($t0)
    blt $t1,48,R2D_BAD
    bgt $t1,57,R2D_BAD
    addiu $t1,$t1,-48
    addiu $t0,$t0,1
    lb  $t2,0($t0)
    blt $t2,48,R2D_BAD
    bgt $t2,57,R2D_BAD
    addiu $t2,$t2,-48
    addiu $t0,$t0,1
    mul $v0,$t1,10
    addu $v0,$v0,$t2
    jr  $ra
    nop
R2D_BAD:
    li $v0,-1
    jr $ra
    nop

# ============================================================
# read_4digits
# Lê quatro caracteres '0'..'9' de $t0 e retorna valor em $v0
# ============================================================
read_4digits:
    move $v0,$zero
    li   $t3,4
R4D_L:
    lb  $t1,0($t0)
    blt $t1,48,R4D_BAD
    bgt $t1,57,R4D_BAD
    addiu $t1,$t1,-48
    mul $v0,$v0,10
    addu $v0,$v0,$t1
    addiu $t0,$t0,1
    addiu $t3,$t3,-1
    bgtz $t3,R4D_L
    jr  $ra
    nop
R4D_BAD:
    li $v0,-1
    jr $ra
    nop
