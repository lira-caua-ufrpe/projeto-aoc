# ============================================================
# time.asm – data/hora e atualização com syscall 30
# ============================================================

.text
.globl tick_relogio, data_hora_cmd

# Posições fixas na string "DD/MM/AAAA - HH:MM:SS"
.eqv IDX_H1 13
.eqv IDX_H2 14
.eqv IDX_M1 16
.eqv IDX_M2 17
.eqv IDX_S1 19
.eqv IDX_S2 20

# ------------------------------------------------------------
# data_hora_cmd(a0=DDMMAAAA, a1=HHMMSS) -> v0=0 ok, v0=-1 erro
#   - Valida faixas básicas (dia 1..31, mes 1..12, hora 0..23, min/seg 0..59)
#   - Formata datahora como "DD/MM/AAAA - HH:MM:SS"
#   - Zera last_ms e acc_ms
# ------------------------------------------------------------
data_hora_cmd:
    # ---- validar strings (tamanho mínimo e dígitos) ----
    # helper interno: valida N dígitos e converte para inteiro (v0)
    # parse dia (2)
    move $t0,$a0                # ptr DDMMAAAA
    li   $a2,2
    jal  atoi_ndigits           # v0 = dia
    move $s0,$v0
    bltz $s0, dh_err
    # parse mes (2)
    addi $a0,$t0,2
    li   $a2,2
    jal  atoi_ndigits
    move $s1,$v0
    bltz $s1, dh_err
    # parse ano (4)
    addi $a0,$t0,4
    li   $a2,4
    jal  atoi_ndigits
    move $s2,$v0
    bltz $s2, dh_err

    # parse hora (2)
    move $t1,$a1                # ptr HHMMSS
    move $a0,$t1
    li   $a2,2
    jal  atoi_ndigits
    move $s3,$v0
    bltz $s3, dh_err
    # parse minuto (2)
    addi $a0,$t1,2
    li   $a2,2
    jal  atoi_ndigits
    move $s4,$v0
    bltz $s4, dh_err
    # parse segundo (2)
    addi $a0,$t1,4
    li   $a2,2
    jal  atoi_ndigits
    move $s5,$v0
    bltz $s5, dh_err

    # ---- faixas básicas ----
    li $t2,1
    blt $s0,$t2, dh_err       # dia >=1
    li $t2,31
    bgt $s0,$t2, dh_err
    li $t2,1
    blt $s1,$t2, dh_err       # mes >=1
    li $t2,12
    bgt $s1,$t2, dh_err
    li $t2,23
    bgt $s3,$t2, dh_err
    li $t2,59
    bgt $s4,$t2, dh_err
    bgt $s5,$t2, dh_err

    # ---- escrever string "DD/MM/AAAA - HH:MM:SS" ----
    la   $t0, datahora
    # DD
    jal  put2                  # usa $s0 (dia)
    move $a0,$s1               # troca param para put2: mes
    addi $t0,$t0,3             # pula "DD/"
    jal  put2
    # ano (4)
    move $a0,$s2
    addi $t0,$t0,3             # pula "MM/"
    jal  put4
    # " - "
    sb   ' ',0($t0); addi $t0,$t0,1
    sb   '-',0($t0); addi $t0,$t0,1
    sb   ' ',0($t0); addi $t0,$t0,1
    # HH
    move $a0,$s3
    jal  put2
    # :
    sb   ':',0($t0); addi $t0,$t0,1
    # MM
    move $a0,$s4
    jal  put2
    # :
    sb   ':',0($t0); addi $t0,$t0,1
    # SS
    move $a0,$s5
    jal  put2
    sb   $zero,0($t0)          # '\0' final

    # zera contadores
    la  $t3,last_ms; sw $zero,0($t3)
    la  $t4,acc_ms;  sw $zero,0($t4)
    move $v0,$zero
    jr $ra

dh_err:
    li $v0,-1
    jr $ra

# ---- helpers de escrita decimal zero-padded ----
# put2: escreve dois dígitos decimais de a0 em datahora (usa e avança t0)
put2:
    # a0 = valor 0..99, t0 = ptr de escrita
    li  $t5,10
    div $a0,$t5
    mfhi $t6       # unidade
    mflo $t7       # dezena
    addi $t7,$t7,'0'
    addi $t6,$t6,'0'
    sb $t7,0($t0)
    addi $t0,$t0,1
    sb $t6,0($t0)
    addi $t0,$t0,1
    jr $ra

# put4: escreve quatro dígitos decimais de a0 (AAAA)
put4:
    # calcula milhar, centena, dezena, unidade
    move $t8,$a0
    li $t5,1000
    div $t8,$t5; mflo $t7; mfhi $t8   # t7=milhar, t8=resto
    addi $t7,$t7,'0'; sb $t7,0($t0); addi $t0,$t0,1
    li $t5,100
    div $t8,$t5; mflo $t7; mfhi $t8
    addi $t7,$t7,'0'; sb $t7,0($t0); addi $t0,$t0,1
    li $t5,10
    div $t8,$t5; mflo $t7; mfhi $t8
    addi $t7,$t7,'0'; sb $t7,0($t0); addi $t0,$t0,1
    addi $t8,$t8,'0'; sb $t8,0($t0); addi $t0,$t0,1
    jr $ra

# atoi_ndigits(a0=ptr, a2=N) -> v0=int (>=0) ou -1 inválido
atoi_ndigits:
    move $v0,$zero
    move $t9,$a2
1:  beq $t9,$zero, 2f
    lb  $t1,0($a0)
    blt $t1,'0', fail
    bgt $t1,'9', fail
    addi $t1,$t1,-48
    mul $v0,$v0,10
    add $v0,$v0,$t1
    addi $a0,$a0,1
    addi $t9,$t9,-1
    j 1b
2:  jr $ra
fail:
    li $v0,-1
    jr $ra

# ------------------------------------------------------------
# tick_relogio()
# - lê syscall 30 (ms), acumula; a cada >=1000ms incrementa SS
# - faz carry para MM e HH. (dia incrementa quando HH passa 23→00)
# ------------------------------------------------------------
tick_relogio:
    li  $v0,30
    syscall                   # v0 = ms desde start
    la  $t0,last_ms
    lw  $t1,0($t0)
    beq $t1,$zero, init_ms
    sub $t2,$v0,$t1           # delta ms
    la  $t3,acc_ms
    lw  $t4,0($t3)
    add $t4,$t4,$t2
    # enquanto >=1000, incrementa 1s
inc_loop:
    li  $t5,1000
    blt $t4,$t5, store_done
    addi $t4,$t4,-1000
    # incrementa SS
    la  $t6,datahora
    addi $t6,$t6,IDX_S2
    lb  $t7,0($t6)
    addi $t7,$t7,1
    ble $t7,'9', write_s2
    # carry para S1
    li  $t7,'0'
write_s2:
    sb  $t7,0($t6)
    bne $t7,'0', inc_end       # não houve carry
    # S2 voltou a '0' -> precisa incrementar S1
    addi $t6,$t6,-1           # aponta S1
    lb  $t7,0($t6)
    addi $t7,$t7,1
    ble $t7,'5', write_s1
    li  $t7,'0'               # 60 -> zera SS e carrega para MM
write_s1:
    sb  $t7,0($t6)
    bne $t7,'0', inc_end
    # carry para MM
    la  $t8,datahora
    addi $t8,$t8,IDX_M2
    lb  $t9,0($t8)
    addi $t9,$t9,1
    ble $t9,'9', w_m2
    li  $t9,'0'
w_m2:
    sb  $t9,0($t8)
    bne $t9,'0', inc_end
    addi $t8,$t8,-1           # M1
    lb  $t9,0($t8)
    addi $t9,$t9,1
    ble $t9,'5', w_m1
    li  $t9,'0'
w_m1:
    sb  $t9,0($t8)
    bne $t9,'0', inc_end
    # carry para HH
    la  $t8,datahora
    addi $t8,$t8,IDX_H2
    lb  $t9,0($t8)
    addi $t9,$t9,1
    ble $t9,'9', w_h2_maybe
    li  $t9,'0'
w_h2_maybe:
    sb  $t9,0($t8)
    # se H1=='2' e H2 passou de '3', zera HH e incrementa dia
    la  $s7,datahora
    addi $s7,$s7,IDX_H1
    lb  $s6,0($s7)
    beq $s6,'2', chk_24
    bne $t9,'0', inc_end       # sem carry total
    # H2 voltou a zero -> incrementar H1
    addi $s7,$s7,0
    addi $s6,$s6,1
    ble $s6,'2', w_h1_only
    li  $s6,'0'
w_h1_only:
    sb  $s6,0($s7)
    bne $s6,'0', inc_end
    j inc_day
chk_24:
    # se H1==2 e H2>3, volta 00 e incrementa dia
    ble $t9,'3', inc_end
    li  $t9,'0'; sb $t9,0($t8)
    li  $s6,'0'; sb $s6,0($s7)
    j inc_day

inc_day:
    # incrementa DD (não valida mês/ano – simplificação)
    la  $t8,datahora
    lb  $t9,0($t8)            # D1
    lb  $s0,1($t8)            # D2
    addi $s0,$s0,1
    ble $s0,'9', w_d2
    li  $s0,'0'
w_d2:
    sb  $s0,1($t8)
    bne $s0,'0', inc_end
    addi $t9,$t9,1
    ble $t9,'3', w_d1
    li  $t9,'0'
w_d1:
    sb  $t9,0($t8)

inc_end:
    j inc_loop

store_done:
    sw  $t4,0($t3)
    sw  $v0,0($t0)
    jr  $ra

init_ms:
    sw  $v0,0($t0)
    jr  $ra
