# ============================================================
# transacoes.asm — transações detalhadas + utilitários
# Layout (32 bytes por transação):
#   [0]      : 1=ativo, 0=vazio
#   [1..8]   : conta destino (string, até 8, termina em 0)
#   [9..12]  : valor em centavos (4 bytes, big-endian)
#   [13..31] : "DD/MM/AAAA HH:MM:SS" + 0
# 50 trans por cliente -> 1600 bytes por cliente
# ============================================================

        .data
transacoes_detalhe_debito:   .space 80000        # espaço para armazenar transações de débito
transacoes_detalhe_credito:  .space 80000        # espaço para transações de crédito
msg_transferencia:           .asciiz "TRANSF"    # mensagem padrão para tipo de transação

        .text
        .globl mostrar_transacoes_debito
        .globl mostrar_transacoes_credito
        .globl adicionar_transacao_detalhe
        .globl preencher_data_hora_atual
        .globl formatar_centavos

# ------------------------------------------------------------
# mostrar_transacoes_debito(a0 = idx_cliente)
# Mostra todas as transações de débito de um cliente
# ------------------------------------------------------------
mostrar_transacoes_debito:
    addiu $sp, $sp, -24          # reserva espaço na stack
    sw    $ra, 20($sp)           # salva endereço de retorno
    sw    $s0, 16($sp)           # salva registradores usados
    sw    $s1, 12($sp)
    sw    $s2,  8($sp)

    move  $s0, $a0               # guarda índice do cliente

    li    $t0, 1600              # tamanho em bytes de todas as transações de um cliente
    mul   $t1, $s0, $t0          # deslocamento para o cliente específico
    la    $s2, transacoes_detalhe_debito
    addu  $s2, $s2, $t1          # aponta para o início das transações do cliente

    li    $s1, 0                 # contador de transações
mtd_loop:
    li    $t0, 50                # máximo de 50 transações
    beq   $s1, $t0, mtd_fim      # se chegou no máximo, sai do loop

    lb    $t1, 0($s2)            # verifica se a transação está ativa
    beq   $t1, $zero, mtd_next   # se não estiver ativa, pula para próxima

    # exibe data/hora da transação (posição 13)
    addiu $a0, $s2, 13
    li    $v0, 4                 # syscall para imprimir string
    syscall

    # imprime 2 espaços
    li    $v0, 11                # syscall para imprimir caractere
    li    $a0, 32                # ASCII do espaço
    syscall
    syscall                       # repetido para 2 espaços

    # imprime tipo da transação
    li    $v0, 4
    la    $a0, msg_transferencia
    syscall

    # imprime 4 espaços extras
    li    $v0, 11
    li    $a0, 32
    syscall
    syscall
    syscall
    syscall

    # lê valor em centavos (big-endian nos bytes 9..12)
    lbu   $t2, 9($s2)
    lbu   $t3, 10($s2)
    lbu   $t4, 11($s2)
    lbu   $t5, 12($s2)
    sll   $t2, $t2, 24
    sll   $t3, $t3, 16
    sll   $t4, $t4, 8
    or    $a0, $t2, $t3
    or    $a0, $a0, $t4
    or    $a0, $a0, $t5

    jal   formatar_centavos        # chama função para formatar valor
    nop
    move  $a0, $v0
    li    $v0, 4
    syscall                      

    # pula linha
    li    $v0, 11
    li    $a0, 10                # ASCII do \n
    syscall

mtd_next:
    addiu $s2, $s2, 32           # próximo registro de transação
    addiu $s1, $s1, 1            # incrementa contador
    j     mtd_loop

mtd_fim:
    # restaura registradores e stack
    lw    $s2,  8($sp)
    lw    $s1, 12($sp)
    lw    $s0, 16($sp)
    lw    $ra, 20($sp)
    addiu $sp, $sp, 24
    jr    $ra
    nop
# ------------------------------------------------------------
# mostrar_transacoes_credito(a0 = idx_cliente)
# Mostra todas as transações de crédito de um cliente
# ------------------------------------------------------------
mostrar_transacoes_credito:
    addiu $sp, $sp, -24          # reserva espaço na stack
    sw    $ra, 20($sp)           # salva endereço de retorno
    sw    $s0, 16($sp)           # salva registradores usados
    sw    $s1, 12($sp)
    sw    $s2,  8($sp)

    move  $s0, $a0               # guarda índice do cliente

    li    $t0, 1600              # tamanho em bytes de todas as transações de um cliente
    mul   $t1, $s0, $t0          # deslocamento para o cliente específico
    la    $s2, transacoes_detalhe_credito
    addu  $s2, $s2, $t1          # aponta para início das transações de crédito do cliente

    li    $s1, 0                 # contador de transações
mtc_loop:
    li    $t0, 50                # máximo de 50 transações
    beq   $s1, $t0, mtc_fim      # se chegou no máximo, sai do loop

    lb    $t1, 0($s2)            # verifica se a transação está ativa
    beq   $t1, $zero, mtc_next   # se não estiver ativa, pula para próxima

    # exibe data/hora da transação (posição 13)
    addiu $a0, $s2, 13
    li    $v0, 4                 # syscall para imprimir string
    syscall

    # imprime 2 espaços
    li    $v0, 11
    li    $a0, 32                # ASCII do espaço
    syscall
    syscall                       # repetido para 2 espaços

    # imprime tipo da transação
    li    $v0, 4
    la    $a0, msg_transferencia
    syscall

    # imprime 4 espaços extras
    li    $v0, 11
    li    $a0, 32
    syscall
    syscall
    syscall
    syscall

    # lê valor em centavos (big-endian nos bytes 9..12)
    lbu   $t2, 9($s2)
    lbu   $t3, 10($s2)
    lbu   $t4, 11($s2)
    lbu   $t5, 12($s2)
    sll   $t2, $t2, 24
    sll   $t3, $t3, 16
    sll   $t4, $t4, 8
    or    $a0, $t2, $t3
    or    $a0, $a0, $t4
    or    $a0, $a0, $t5

    jal   formatar_centavos        # chama função para formatar valor
    nop
    move  $a0, $v0
    li    $v0, 4
    syscall                       # imprime valor formatado

    # pula linha
    li    $v0, 11
    li    $a0, 10                # ASCII do \n
    syscall

mtc_next:
    addiu $s2, $s2, 32           # próximo registro de transação
    addiu $s1, $s1, 1            # incrementa contador
    j     mtc_loop

mtc_fim:
    # restaura registradores e stack
    lw    $s2,  8($sp)
    lw    $s1, 12($sp)
    lw    $s0, 16($sp)
    lw    $ra, 20($sp)
    addiu $sp, $sp, 24
    jr    $ra
    nop

# ------------------------------------------------------------
# adicionar_transacao_detalhe
# Adiciona uma transação (débito ou crédito) para um cliente
# a0 = idx_cliente
# a1 = tipo (0 = débito, 1 = crédito)
# a2 = ponteiro pra conta (string)
# a3 = valor em centavos (word)
# Retorna:
#   v0 = 1 se inserido com sucesso
#   v0 = 0 se não houver slot disponível
# ------------------------------------------------------------
adicionar_transacao_detalhe:
    addiu $sp, $sp, -24          # reserva espaço na stack
    sw    $ra, 20($sp)           # salva endereço de retorno
    sw    $s0, 16($sp)           # salva registradores usados
    sw    $s1, 12($sp)
    sw    $s2,  8($sp)

    move  $s0, $a0               # índice do cliente
    move  $s1, $a1               # tipo da transação
    move  $s2, $a2               # ponteiro para conta

    li    $t0, 1600              # tamanho em bytes das transações de um cliente
    mul   $t1, $s0, $t0          # deslocamento para cliente específico
    beq   $s1, $zero, atd_deb    # se tipo = 0, débito
    la    $t2, transacoes_detalhe_credito
    j     atd_base_ok
atd_deb:
    la    $t2, transacoes_detalhe_debito
atd_base_ok:
    addu  $t2, $t2, $t1          # aponta para início das transações do cliente

    # procura slot livre
    li    $t3, 0
atd_find:
    li    $t4, 50
    beq   $t3, $t4, atd_full     # se chegou no máximo, não há slot
    lb    $t5, 0($t2)
    beq   $t5, $zero, atd_slot   # encontrou slot vazio
    addiu $t2, $t2, 32
    addiu $t3, $t3, 1
    j     atd_find

atd_slot:
    li    $t5, 1
    sb    $t5, 0($t2)            # marca como ativo

    # copia conta para [1..8]
    addiu $t6, $t2, 1
    move  $t7, $s2
cpy_conta:
    lb    $t8, 0($t7)
    sb    $t8, 0($t6)
    beq   $t8, $zero, cpy_conta_done
    addiu $t6, $t6, 1
    addiu $t7, $t7, 1
    j     cpy_conta
cpy_conta_done:

    # valor em [9..12] (big-endian)
    addiu $t9, $t2, 9
    srl   $t0, $a3, 24
    sb    $t0, 0($t9)
    srl   $t0, $a3, 16
    sb    $t0, 1($t9)
    srl   $t0, $a3, 8
    sb    $t0, 2($t9)
    sb    $a3, 3($t9)

    # preenche data/hora atual em [13..31]
    addiu $a0, $t2, 13
    jal   preencher_data_hora_atual
    nop

    li    $v0, 1                 # sucesso
    j     atd_end

atd_full:
    li    $v0, 0                 # não há slot disponível

atd_end:
    # restaura registradores e stack
    lw    $s2,  8($sp)
    lw    $s1, 12($sp)
    lw    $s0, 16($sp)
    lw    $ra, 20($sp)
    addiu $sp, $sp, 24
    jr    $ra
    nop

# ------------------------------------------------------------
# preencher_data_hora_atual(a0 = buffer de 20B)
# Preenche buffer com "DD/MM/AAAA HH:MM:SS"
# ------------------------------------------------------------
preencher_data_hora_atual:
    addiu $sp, $sp, -16
    sw    $ra, 12($sp)
    sw    $s0,  8($sp)

    move  $s0, $a0               # ponteiro para buffer

    jal   tick_datetime           # atualiza variáveis curr_day, curr_mon, etc.
    nop

    # dia
    la    $t0, curr_day
    lw    $a0, 0($t0)
    move  $a1, $s0
    jal   print_two_buffer
    nop
    move  $s0, $v0

    li    $t1, '/'
    sb    $t1, 0($s0)
    addiu $s0, $s0, 1

    # mês
    la    $t0, curr_mon
    lw    $a0, 0($t0)
    move  $a1, $s0
    jal   print_two_buffer
    nop
    move  $s0, $v0

    li    $t1, '/'
    sb    $t1, 0($s0)
    addiu $s0, $s0, 1

    # ano
    la    $t0, curr_year
    lw    $a0, 0($t0)
    move  $a1, $s0
    jal   print_four_buffer
    nop
    move  $s0, $v0

    li    $t1, ' '
    sb    $t1, 0($s0)
    addiu $s0, $s0, 1

    # hora
    la    $t0, curr_hour
    lw    $a0, 0($t0)
    move  $a1, $s0
    jal   print_two_buffer
    nop
    move  $s0, $v0

    li    $t1, ':'
    sb    $t1, 0($s0)
    addiu $s0, $s0, 1

    # minuto
    la    $t0, curr_min
    lw    $a0, 0($t0)
    move  $a1, $s0
    jal   print_two_buffer
    nop
    move  $s0, $v0

    li    $t1, ':'
    sb    $t1, 0($s0)
    addiu $s0, $s0, 1

    # segundo
    la    $t0, curr_sec
    lw    $a0, 0($t0)
    move  $a1, $s0
    jal   print_two_buffer
    nop
    move  $s0, $v0

    sb    $zero, 0($s0)           # termina string com 0

    # restaura registradores e stack
    lw    $s0,  8($sp)
    lw    $ra, 12($sp)
    addiu $sp, $sp, 16
    jr    $ra
    nop

# ------------------------------------------------------------
# print_two_buffer / print_four_buffer
# ------------------------------------------------------------
# print_two_buffer(a0 = valor 0-99, a1 = buffer)
# Converte número de 2 dígitos para caracteres ASCII e grava no buffer
print_two_buffer:
    move  $v0, $a1               # ponteiro do buffer em v0
    li    $t0, 10
    divu  $a0, $t0               # divide a0 por 10
    mflo  $t1                     # quociente (dezena)
    mfhi  $t2                     # resto (unidade)
    addiu $t1, $t1, 48            # converte para ASCII
    addiu $t2, $t2, 48
    sb    $t1, 0($v0)
    sb    $t2, 1($v0)
    addiu $v0, $v0, 2            # avança buffer
    jr    $ra
    nop

# print_four_buffer(a0 = valor 0-9999, a1 = buffer)
# Converte número de 4 dígitos para ASCII e grava no buffer
print_four_buffer:
    move  $v0, $a1
    li    $t0, 1000
    divu  $a0, $t0
    mflo  $t1                     # milhar
    mfhi  $t3                     # resto
    addiu $t1, $t1, 48
    sb    $t1, 0($v0)
    addiu $v0, $v0, 1

    li    $t0, 100
    divu  $t3, $t0
    mflo  $t1                     # centena
    mfhi  $t3                      # resto
    addiu $t1, $t1, 48
    sb    $t1, 0($v0)
    addiu $v0, $v0, 1

    li    $t0, 10
    divu  $t3, $t0
    mflo  $t1                     # dezena
    mfhi  $t2                     # unidade
    addiu $t1, $t1, 48
    addiu $t2, $t2, 48
    sb    $t1, 0($v0)
    sb    $t2, 1($v0)
    addiu $v0, $v0, 2
    jr    $ra
    nop

# ------------------------------------------------------------
# formatar_centavos(a0 = valor em centavos) -> v0 = &buffer_valor_formatado
# Formata valor em centavos para string "R$ XXXX,YY"
# ------------------------------------------------------------
formatar_centavos:
    addiu $sp, $sp, -32           # reserva stack
    sw    $ra, 28($sp)
    sw    $s0, 24($sp)
    sw    $s1, 20($sp)
    sw    $s2, 16($sp)
    sw    $s3, 12($sp)

    la    $s0, buffer_valor_formatado
    li    $t0, 'R'               # "R$ "
    sb    $t0, 0($s0)
    li    $t0, '$'
    sb    $t0, 1($s0)
    li    $t0, ' '
    sb    $t0, 2($s0)
    addiu $s1, $s0, 3            # ponteiro para parte dos reais

    li    $t0, 100
    divu  $a0, $t0
    mflo  $s2                     # reais
    mfhi  $t1                     # centavos

    addiu $s3, $s0, 24            # área temporária para dígitos (inversa)
    move  $t2, $s3

    beq   $s2, $zero, fc_write_zero

fc_conv_loop:
    li    $t3, 10
    divu  $s2, $t3
    mflo  $s2
    mfhi  $t4
    addiu $t4, $t4, 48
    sb    $t4, 0($t2)
    addiu $t2, $t2, 1
    bne   $s2, $zero, fc_conv_loop
    j     fc_copy_back

fc_write_zero:
    li    $t4, '0'
    sb    $t4, 0($t2)
    addiu $t2, $t2, 1

fc_copy_back:
    addiu $t2, $t2, -1
fc_copy_loop:
    lb    $t4, 0($t2)
    sb    $t4, 0($s1)
    addiu $s1, $s1, 1
    beq   $t2, $s3, fc_copy_done
    addiu $t2, $t2, -1
    j     fc_copy_loop

fc_copy_done:
    li    $t4, ','
    sb    $t4, 0($s1)
    addiu $s1, $s1, 1

    li    $t3, 10
    divu  $t1, $t3
    mflo  $t4                     # dezena centavos
    mfhi  $t5                     # unidade centavos
    addiu $t4, $t4, 48
    addiu $t5, $t5, 48
    sb    $t4, 0($s1)
    sb    $t5, 1($s1)
    addiu $s1, $s1, 2

    sb    $zero, 0($s1)           # termina string
    la    $v0, buffer_valor_formatado

    # restaura registradores e stack
    lw    $s3, 12($sp)
    lw    $s2, 16($sp)
    lw    $s1, 20($sp)
    lw    $s0, 24($sp)
    lw    $ra, 28($sp)
    addiu $sp, $sp, 32
    jr    $ra
    nop
