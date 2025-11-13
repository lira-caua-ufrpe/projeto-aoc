# ops_fin.asm —R2 (pagamentos) + R3 (registro de transações) + R7 (juros)
# Este módulo lida com operações financeiras como pagamentos,
# saques, depósitos e registros de transações (débito/crédito).

# Handlers (formatos esperados de comandos):
#  - pagar_debito-<CONTA6>-<DV>-<VALORcentavos>
#  - pagar_credito-<CONTA6>-<DV>-<VALORcentavos>
#  - alterar_limite-<CONTA6>-<DV>-<NOVO_LIMcentavos>
#  - pagar_fatura-<CONTA6>-<DV>-<VALORcentavos>-<METHOD[S|E]>
#  - sacar-<CONTA6>-<DV>-<VALORcentavos>
#  - depositar-<CONTA6>-<DV>-<VALORcentavos>
#
# Regras R3: até 50 transações de débito e 50 de crédito por cliente (ring buffer).

.text
.globl calc_off_i50k
.globl handle_pagar_debito
.globl handle_pagar_credito
.globl handle_alterar_limite
.globl handle_dump_trans_credito
.globl handle_dump_trans_debito
# aliases esperados pelo main.asm
.globl handle_dump_trans_cred
.globl handle_dump_trans_deb
.globl handle_pagar_fatura
.globl handle_sacar
.globl handle_depositar
.globl aplicar_juros_auto

# ------------------------------------------------------------
# Função: calc_off_i50k
# Objetivo: calcular o deslocamento (offset) de 4 * (i*50 + k)
# Parâmetros:
#   a0 = índice do cliente (i)
#   a1 = índice interno da transação (k)
# Retorno:
#   v0 = deslocamento em bytes (múltiplo de 4)
# ------------------------------------------------------------
calc_off_i50k:
    sll  $t0, $a0, 5        # t0 = i * 32
    sll  $t1, $a0, 4        # t1 = i * 16
    addu $t0, $t0, $t1      # t0 = i * 48
    sll  $t1, $a0, 1        # t1 = i * 2
    addu $t0, $t0, $t1      # t0 = i * 50
    addu $t0, $t0, $a1      # t0 = i*50 + k
    sll  $v0, $t0, 2        # v0 = (i*50 + k) * 4
    jr   $ra
    nop

# ------------------------------------------------------------
# Handler: pagar_debito
# Objetivo: processar um comando no formato:
#   pagar_debito-<CONTA6>-<DV>-<VALORcentavos>
# Passos:
#   1. Verifica o prefixo "pagar_debito-"
#   2. Lê a conta (6 dígitos) e o DV
#   3. Lê o valor em centavos
#   4. Localiza o cliente
#   5. Verifica saldo suficiente
#   6. Atualiza saldo e registra transação (R3)
# ------------------------------------------------------------
handle_pagar_debito:
    # Cria espaço na pilha para salvar registradores
    addiu $sp, $sp, -32
    sw    $ra, 28($sp)
    sw    $s0, 24($sp)
    sw    $s1, 20($sp)
    sw    $s2, 16($sp)

    # Verifica se o prefixo do comando é "pagar_debito-"
    move  $t0, $a0                 # ponteiro para string recebida
    la    $t1, str_cmd_pay_debito  # endereço do prefixo esperado
pd_chk_pref_loop:
    lb    $t2, 0($t1)
    beq   $t2, $zero, pd_pref_ok   # chegou ao fim do prefixo ? ok
    lb    $t3, 0($t0)
    bne   $t2, $t3, pd_not_mine    # caractere não confere ? não é este handler
    addi  $t1, $t1, 1
    addi  $t0, $t0, 1
    j     pd_chk_pref_loop
    nop

pd_pref_ok:
    # Lê a parte da conta (6 dígitos)
    la    $t4, cc_buf_acc
    li    $t5, 0
pd_acc_loop:
    lb    $t6, 0($t0)
    blt   $t6, 48, pd_badfmt       # caractere < '0' ? erro
    bgt   $t6, 57, pd_badfmt       # caractere > '9' ? erro
    sb    $t6, 0($t4)              # grava no buffer
    addi  $t4, $t4, 1
    addi  $t0, $t0, 1
    addi  $t5, $t5, 1
    blt   $t5, 6, pd_acc_loop      # repete até 6 dígitos
    sb    $zero, 0($t4)            # termina string com '\0'

    # Verifica o caractere '-'
    lb    $t6, 0($t0)
    li    $t7, 45                  # código ASCII de '-'
    bne   $t6, $t7, pd_badfmt
    addi  $t0, $t0, 1

    # Lê o DV (1 caractere)
    lb    $s1, 0($t0)
    addi  $t0, $t0, 1
    li    $t7, 88                  # 'X' (DV especial)
    beq   $s1, $t7, pd_dv_ok
    blt   $s1, 48, pd_badfmt
    bgt   $s1, 57, pd_badfmt
pd_dv_ok:

    # Verifica o segundo '-'
    lb    $t6, 0($t0)
    li    $t7, 45
    bne   $t6, $t7, pd_badfmt
    addi  $t0, $t0, 1

    # Lê o valor em centavos ? t8
    move  $t8, $zero
pd_val_loop:
    lb    $t6, 0($t0)
    beq   $t6, $zero, pd_val_end   # fim da string
    blt   $t6, 48, pd_badfmt
    bgt   $t6, 57, pd_badfmt
    addi  $t6, $t6, -48
    mul   $t8, $t8, 10
    addu  $t8, $t8, $t6
    addi  $t0, $t0, 1
    j     pd_val_loop
    nop

pd_val_end:
    # Normaliza valor para múltiplo de 100 (centavos)
    li    $t0, 100
    divu  $t8, $t0
    mflo  $t1
    mul   $t8, $t1, 100

    # Procura cliente com a conta e DV correspondentes
    lw    $t9, MAX_CLIENTS
    move  $t1, $zero          # i = 0
pd_find_loop:
    beq   $t1, $t9, pd_not_found   # fim da lista

    # Verifica se o cliente está em uso
    la    $a0, clientes_usado
    addu  $a0, $a0, $t1
    lb    $a1, 0($a0)
    beq   $a1, $zero, pd_next_i    # não usado ? pula

    # Compara número da conta (6 dígitos)
    la    $a2, clientes_conta
    li    $a3, 7
    mul   $a3, $t1, $a3
    addu  $a2, $a2, $a3
    la    $a3, cc_buf_acc
    li    $v1, 0
pd_cmp6:
    lb    $t2, 0($a2)
    lb    $t3, 0($a3)
    bne   $t2, $t3, pd_next_i
    addi  $a2, $a2, 1
    addi  $a3, $a3, 1
    addi  $v1, $v1, 1
    blt   $v1, 6, pd_cmp6

    # Compara o DV
    la    $a2, clientes_dv
    addu  $a2, $a2, $t1
    lb    $t2, 0($a2)
    bne   $t2, $s1, pd_next_i

    # --- Cliente encontrado (índice i) ---
    move  $s0, $t1
    sll   $t0, $s0, 2           # offset em palavras (4 bytes por cliente)

    # Verifica se saldo[i] >= valor
    la    $t2, clientes_saldo_cent
    addu  $t2, $t2, $t0
    lw    $t3, 0($t2)
    sltu  $v1, $t3, $t8
    bne   $v1, $zero, pd_saldo_insuf

    # saldo -= valor
    subu  $t3, $t3, $t8
    sw    $t3, 0($t2)

    # ---- R3: registrar débito ----
    # head = posição atual no ring buffer
    la    $t4, trans_deb_head
    addu  $t4, $t4, $t0
    lw    $t5, 0($t4)           # head (0..49)

    # Calcula posição do slot (i, head)
    move  $a0, $s0
    move  $a1, $t5
    jal   calc_off_i50k
    nop
    move  $t6, $v0              # offset resultante

    # Grava valor no buffer de transações
    la    $t7, trans_deb_vals
    addu  $t7, $t7, $t6
    sw    $t8, 0($t7)

    # Atualiza head = (head + 1) % 50
    addiu $t5, $t5, 1
    li    $t6, 50
    bne   $t5, $t6, pd_head_ok
    move  $t5, $zero
pd_head_ok:
    sw    $t5, 0($t4)

    # Atualiza o ponteiro de escrita (wptr)
    sll   $t0, $s0, 2
    la    $t7, trans_deb_wptr
    addu  $t7, $t7, $t0
    sw    $t5, 0($t7)

    # Sanitiza contador de transações (mantém entre 0 e 50)
    la    $t7, trans_deb_count
    addu  $t7, $t7, $t0
    lw    $t6, 0($t7)           # lê count atual
    bltz  $t6, pd_cnt_zero       # se negativo ? zera
    li    $t9, 50
    sltu  $v1, $t6, $t9
    bne   $v1, $zero, pd_cnt_ok  # se menor que 50 ? ok
    beq   $v1, $zero, pd_cnt_keep # caso contrário, mantém
# ============================================================
# Continuação de pagar_debito
# ============================================================

pd_cnt_zero:
    move  $t6, $zero           # Se o contador for negativo, zera o count

pd_cnt_ok:
    li    $t9, 50
    slt   $v1, $t6, $t9        # Verifica se count < 50
    beq   $v1, $zero, pd_cnt_keep  # Se não for, mantém
    addiu $t6, $t6, 1          # Incrementa contador (count++)
    sw    $t6, 0($t7)          # Atualiza valor de count
pd_cnt_keep:

    # Log detalhado de transação de débito
    # Chama uma função auxiliar para registrar informações extras
    move  $a0, $s0             # Índice do cliente
    li    $a1, 0               # Tipo 0 ? débito
    la    $a2, cc_buf_acc      # Número da conta
    move  $a3, $t8             # Valor
    jal   adicionar_transacao_detalhe
    nop

    # Mensagem de sucesso: pagamento efetuado
    li    $v0, 4
    la    $a0, msg_pay_deb_ok
    syscall
    li    $v0, 1
    j     pd_epilogue
    nop

# Continua busca de cliente (caso o atual não bata)
pd_next_i:
    addiu $t1, $t1, 1
    j     pd_find_loop
    nop

# Cliente não encontrado
pd_not_found:
    li    $v0, 4
    la    $a0, msg_err_cli_inexist
    syscall
    li    $v0, 1
    j     pd_epilogue
    nop

# Saldo insuficiente
pd_saldo_insuf:
    li    $v0, 4
    la    $a0, msg_err_saldo_insuf
    syscall
    li    $v0, 1
    j     pd_epilogue
    nop

# Formato incorreto no comando (erro de parsing)
pd_badfmt:
    li    $v0, 4
    la    $a0, msg_cc_badfmt
    syscall
    li    $v0, 1
    j     pd_epilogue
    nop

# Comando não pertence a este handler (prefixo diferente)
pd_not_mine:
    move  $v0, $zero

# Finalização: restaura registradores e retorna
pd_epilogue:
    lw    $s2, 16($sp)
    lw    $s1, 20($sp)
    lw    $s0, 24($sp)
    lw    $ra, 28($sp)
    addiu $sp, $sp, 32
    jr    $ra
    nop


# ============================================================
# Função: handle_pagar_credito
# Objetivo: processar "pagar_credito-<CONTA6>-<DV>-<VALORcentavos>"
# Lógica parecida com pagar_debito, mas opera sobre limite e dívida
# (em vez de saldo), além de registrar no buffer de crédito.
# ============================================================

handle_pagar_credito:
    # Reserva espaço na pilha e salva registradores
    addiu $sp, $sp, -32
    sw    $ra, 28($sp)
    sw    $s0, 24($sp)    # índice do cliente
    sw    $s1, 20($sp)    # DV
    sw    $s2, 16($sp)    # (livre)

    # Verifica prefixo "pagar_credito-"
    move  $t0, $a0
    la    $t1, str_cmd_pay_credito
pc_pref_loop:
    lb    $t2, 0($t1)
    beq   $t2, $zero, pc_pref_ok     # fim da string prefixo ? ok
    lb    $t3, 0($t0)
    bne   $t2, $t3, pc_not_mine      # caractere diferente ? não é esse comando
    addi  $t1, $t1, 1
    addi  $t0, $t0, 1
    j     pc_pref_loop
    nop

pc_pref_ok:
    # Lê número da conta (6 dígitos)
    la    $t4, cc_buf_acc
    li    $t5, 0
pc_acc_loop:
    lb    $t6, 0($t0)
    blt   $t6, 48, pc_badfmt         # se menor que '0'
    bgt   $t6, 57, pc_badfmt         # se maior que '9'
    sb    $t6, 0($t4)
    addi  $t4, $t4, 1
    addi  $t0, $t0, 1
    addi  $t5, $t5, 1
    blt   $t5, 6, pc_acc_loop
    sb    $zero, 0($t4)              # encerra string da conta

    # Verifica '-'
    lb    $t6, 0($t0)
    li    $t7, 45
    bne   $t6, $t7, pc_badfmt
    addi  $t0, $t0, 1

    # Lê DV (1 caractere)
    lb    $s1, 0($t0)
    addi  $t0, $t0, 1
    li    $t7, 88                   # 'X'
    beq   $s1, $t7, pc_dv_ok
    blt   $s1, 48, pc_badfmt
    bgt   $s1, 57, pc_badfmt
pc_dv_ok:

    # Segundo '-'
    lb    $t6, 0($t0)
    li    $t7, 45
    bne   $t6, $t7, pc_badfmt
    addi  $t0, $t0, 1

    # Lê valor (em centavos)
    move  $t8, $zero
pc_val_loop:
    lb    $t6, 0($t0)
    beq   $t6, $zero, pc_val_end
    blt   $t6, 48, pc_badfmt
    bgt   $t6, 57, pc_badfmt
    addi  $t6, $t6, -48
    mul   $t8, $t8, 10
    addu  $t8, $t8, $t6
    addi  $t0, $t0, 1
    j     pc_val_loop
    nop

pc_val_end:
    # Remove centavos "lixo" (garante múltiplo de 100)
    li    $t0, 100
    divu  $t8, $t0
    mflo  $t1
    mul   $t8, $t1, 100

    # ===== Procura cliente correspondente =====
    lw    $t9, MAX_CLIENTS
    li    $s0, 0
pc_find_loop:
    beq   $s0, $t9, pc_not_found     # fim da lista ? não achou

    # Verifica se o slot está em uso
    la    $t2, clientes_usado
    addu  $t2, $t2, $s0
    lb    $t3, 0($t2)
    beq   $t3, $zero, pc_next_i

    # Compara número da conta (6 dígitos)
    la    $t4, clientes_conta
    li    $t5, 7
    mul   $t5, $s0, $t5
    addu  $t4, $t4, $t5
    la    $t6, cc_buf_acc
    li    $t7, 0
pc_cmp6:
    lb    $t2, 0($t4)
    lb    $t3, 0($t6)
    bne   $t2, $t3, pc_next_i
    addi  $t4, $t4, 1
    addi  $t6, $t6, 1
    addi  $t7, $t7, 1
    blt   $t7, 6, pc_cmp6

    # Compara o DV
    la    $t4, clientes_dv
    addu  $t4, $t4, $s0
    lb    $t2, 0($t4)
    bne   $t2, $s1, pc_next_i

    # ===== Cliente encontrado =====
    sll   $t0, $s0, 2               # offset de índice (4 bytes por cliente)

    # Lê limite e dívida
    la    $t1, clientes_limite_cent
    addu  $t1, $t1, $t0
    lw    $t2, 0($t1)               # limite

    la    $t3, clientes_devido_cent
    addu  $t3, $t3, $t0
    lw    $t4, 0($t3)               # dívida atual

    # Normaliza dívida (múltiplo de 100)
    li    $t5, 100
    divu  $t4, $t5
    mflo  $t6
    mul   $t4, $t6, 100

    # Verifica se há limite disponível: (limite - devido) >= valor ?
    subu  $t6, $t2, $t4
    sltu  $t7, $t6, $t8
    bne   $t7, $zero, pc_lim_insuf  # limite insuficiente ? erro

    # Atualiza dívida: devido += valor
    addu  $t4, $t4, $t8
    sw    $t4, 0($t3)

    # ===== Registra transação de crédito =====
    # Pega o índice head do ring buffer de crédito
    la    $t4, trans_cred_head
    addu  $t4, $t4, $t0
    lw    $t6, 0($t4)               # head (0..49)

    # Calcula posição do slot: (i, head)
    move  $a0, $s0
    move  $a1, $t6
    jal   calc_off_i50k
    nop
    move  $t7, $v0

    # Salva o valor no buffer de crédito
    la    $t1, trans_cred_vals
    addu  $t1, $t1, $t7
    sw    $t8, 0($t1)

    # Atualiza head = (head + 1) % 50
    addiu $t6, $t6, 1
    li    $t7, 50
    bne   $t6, $t7, pc_head_ok
    move  $t6, $zero
pc_head_ok:
    sw    $t6, 0($t4)              # Salva o novo valor de "head" no endereço apontado por $t4

    # Atualiza o ponteiro de escrita (wptr = head)
    # Recalcula o índice (idx4) após o retorno de função (jal)
    sll   $t0, $s0, 2              # $t0 = índice * 4 (cada item ocupa 4 bytes)
    la    $t7, trans_cred_wptr     # Carrega o endereço base da tabela de ponteiros de escrita
    addu  $t7, $t7, $t0            # Soma o deslocamento do cliente atual
    sw    $t6, 0($t7)              # Atualiza o wptr do cliente com o valor de head

    # ===== SANITIZAÇÃO do contador =====
    # Corrige "count" garantindo que fique entre 0 e 50
    la    $t7, trans_cred_count     # Base do contador de transações
    addu  $t7, $t7, $t0             # Seleciona o contador do cliente atual
    lw    $t9, 0($t7)               # Carrega o valor atual de count (pode estar corrompido)
    bltz  $t9, pc_cnt_zero          # Se count < 0, zera
    li    $s2, 50                   # Valor máximo permitido
    sltu  $v1, $t9, $s2             # Verifica se count < 50
    bne   $v1, $zero, pc_cnt_ok     # Se sim, ok
    beq   $v1, $zero, pc_cnt_keep   # Se não, mantém
pc_cnt_zero:
    move  $t9, $zero                # Zera count
pc_cnt_ok:
    li    $s2, 50                   # Limite máximo
    slt   $v1, $t9, $s2             # Se count ainda < 50
    beq   $v1, $zero, pc_cnt_keep   # Se já atingiu limite, pula incremento
    addiu $t9, $t9, 1               # Incrementa count
    sw    $t9, 0($t7)               # Atualiza count na memória
pc_cnt_keep:

    # Log detalhado da transação de crédito
    move  $a0, $s0                  # Cliente (índice)
    li    $a1, 1                    # Tipo = crédito
    la    $a2, cc_buf_acc           # Buffer da conta
    move  $a3, $t8                  # Valor da transação
    jal   adicionar_transacao_detalhe  # Chama função para registrar a transação
    nop

    # Mensagem de sucesso (pagamento crédito ok)
    li    $v0, 4
    la    $a0, msg_pay_cred_ok
    syscall
    li    $v0, 1
    j     pc_epilogue
    nop

# ======================================
# Casos de erro / controle de fluxo
# ======================================

pc_next_i:
    addi  $s0, $s0, 1               # Avança para o próximo índice de cliente
    j     pc_find_loop               # Volta ao loop de busca
    nop

pc_not_found:
    li    $v0, 4
    la    $a0, msg_err_cli_inexist   # Cliente inexistente
    syscall
    li    $v0, 1
    j     pc_epilogue
    nop

pc_lim_insuf:
    li    $v0, 4
    la    $a0, msg_err_limite_insuf  # Limite insuficiente
    syscall
    li    $v0, 1
    j     pc_epilogue
    nop

pc_badfmt:
    li    $v0, 4
    la    $a0, msg_cc_badfmt         # Formato inválido
    syscall
    li    $v0, 1
    j     pc_epilogue
    nop

pc_not_mine:
    move  $v0, $zero                 # Comando não pertence a esta rotina

# Encerramento da função (restaura registradores)
pc_epilogue:
    lw    $s2, 16($sp)
    lw    $s1, 20($sp)
    lw    $s0, 24($sp)
    lw    $ra, 28($sp)
    addiu $sp, $sp, 32
    jr    $ra
    nop


# ------------------------------------------------------------
# Função: handle_alterar_limite
# ------------------------------------------------------------
handle_alterar_limite:
    addiu $sp, $sp, -24              # Reserva espaço na pilha
    sw    $ra, 20($sp)
    sw    $s0, 16($sp)
    sw    $s1, 12($sp)

    # Verifica se o comando começa com "alterar_limite-"
    move  $t0, $a0                   # Ponteiro para o comando recebido
    la    $t1, str_cmd_alt_limite    # String de prefixo esperado
al_chk_pref_loop:
    lb    $t2, 0($t1)                # Lê caractere do prefixo
    beq   $t2, $zero, al_pref_ok     # Se chegou ao fim, prefixo ok
    lb    $t3, 0($t0)                # Lê caractere do comando
    bne   $t2, $t3, al_not_mine      # Se diferente, não é este comando
    addi  $t1, $t1, 1
    addi  $t0, $t0, 1
    j     al_chk_pref_loop
    nop

al_pref_ok:
    # Lê número da conta (6 dígitos)
    la    $t4, cc_buf_acc            # Buffer temporário da conta
    li    $t5, 0                     # Contador de dígitos
al_acc_loop:
    lb    $t6, 0($t0)                # Lê caractere atual
    blt   $t6, 48, al_badfmt         # Se menor que '0', formato inválido
    bgt   $t6, 57, al_badfmt         # Se maior que '9', formato inválido
    sb    $t6, 0($t4)                # Armazena caractere no buffer
    addi  $t4, $t4, 1
    addi  $t0, $t0, 1
    addi  $t5, $t5, 1
    blt   $t5, 6, al_acc_loop        # Continua até ler 6 dígitos
    sb    $zero, 0($t4)              # Finaliza string com '\0'

    # Verifica o caractere '-' após a conta
    lb    $t6, 0($t0)
    li    $t7, 45                    # ASCII de '-'
    bne   $t6, $t7, al_badfmt
    addi  $t0, $t0, 1

    # Lê o DV (dígito verificador)
    lb    $s1, 0($t0)
    addi  $t0, $t0, 1
    li    $t7, 88                    # ASCII de 'X' — DV especial
    beq   $s1, $t7, al_dv_ok         # Se DV = 'X', tudo certo
    blt   $s1, 48, al_badfmt         # Se DV menor que '0', erro
    bgt   $s1, 57, al_badfmt         # Se DV maior que '9', erro
al_dv_ok:
    # Verifica o próximo caractere (deve ser '-')
    lb    $t6, 0($t0)
    li    $t7, 45                    # ASCII de '-'
    bne   $t6, $t7, al_badfmt        # Se não for '-', formato inválido
    addi  $t0, $t0, 1                # Avança para o próximo caractere

    # Lê o novo limite informado -> armazena em $t8
    move  $t8, $zero                 # Zera acumulador do limite
al_val_loop:
    lb    $t6, 0($t0)                # Lê caractere atual
    beq   $t6, $zero, al_val_end     # Se chegou ao fim da string, sai
    blt   $t6, 48, al_badfmt         # Se menor que '0', formato inválido
    bgt   $t6, 57, al_badfmt         # Se maior que '9', formato inválido
    addi  $t6, $t6, -48              # Converte ASCII -> número
    mul   $t8, $t8, 10               # Desloca à esquerda (decimal)
    addu  $t8, $t8, $t6              # Soma o dígito
    addi  $t0, $t0, 1                # Avança caractere
    j     al_val_loop                # Continua até o fim
    nop
al_val_end:

    # Procura cliente correspondente na base de dados
    lw    $t9, MAX_CLIENTS           # Total de clientes cadastrados
    move  $t1, $zero                 # Índice de cliente (i = 0)
al_find_loop:
    beq   $t1, $t9, al_not_found     # Se chegou ao fim, não achou
    la    $a0, clientes_usado
    addu  $a0, $a0, $t1
    lb    $a1, 0($a0)
    beq   $a1, $zero, al_next_i      # Se posição livre, pula

    # Compara número da conta (6 dígitos)
    la    $a2, clientes_conta
    li    $a3, 7                     # Cada conta tem 7 bytes (6 + '\0')
    mul   $a3, $t1, $a3              # Offset = i * 7
    addu  $a2, $a2, $a3              # Ponteiro para conta[i]
    la    $a3, cc_buf_acc            # Conta digitada
    li    $v1, 0                     # Contador de caracteres comparados
al_cmp6:
    lb    $t2, 0($a2)
    lb    $t3, 0($a3)
    bne   $t2, $t3, al_next_i        # Se diferente, não é o mesmo cliente
    addi  $a2, $a2, 1
    addi  $a3, $a3, 1
    addi  $v1, $v1, 1
    blt   $v1, 6, al_cmp6            # Continua até comparar os 6 dígitos

    # Verifica se o DV (dígito verificador) bate
    la    $a2, clientes_dv
    addu  $a2, $a2, $t1
    lb    $t2, 0($a2)
    bne   $t2, $s1, al_next_i        # Se DV diferente, pula

    # --- ENCONTROU O CLIENTE ---
    sll   $t0, $t1, 2                # Offset = i * 4 (endereços de 4 bytes)
    la    $t2, clientes_devido_cent
    addu  $t2, $t2, $t0
    lw    $t3, 0($t2)                # Carrega valor devido atual

    # Verifica se novo limite < dívida atual
    sltu  $v1, $t8, $t3
    bne   $v1, $zero, al_baixo       # Se for menor, erro: limite abaixo da dívida

    # Atualiza limite do cliente
    la    $t4, clientes_limite_cent
    addu  $t4, $t4, $t0
    sw    $t8, 0($t4)                # Salva novo limite

    # Mensagem de sucesso
    li    $v0, 4
    la    $a0, msg_limite_ok
    syscall
    li    $v0, 1
    j     al_done
    nop

# Continua busca se ainda não achou
al_next_i:
    addiu $t1, $t1, 1
    j     al_find_loop
    nop

# Cliente não encontrado
al_not_found:
    li    $v0, 4
    la    $a0, msg_err_cli_inexist
    syscall
    li    $v0, 1
    j     al_done
    nop

# Novo limite abaixo do valor devido
al_baixo:
    li    $v0, 4
    la    $a0, msg_limite_baixo_divida
    syscall
    li    $v0, 1
    j     al_done
    nop

# Formato inválido do comando
al_badfmt:
    li    $v0, 4
    la    $a0, msg_cc_badfmt
    syscall
    li    $v0, 1
    j     al_done
    nop

# Se o comando não pertence a esta rotina
al_not_mine:
    move  $v0, $zero

# Finalização da função
al_done:
    lw    $s1, 12($sp)
    lw    $s0, 16($sp)
    lw    $ra, 20($sp)
    addiu $sp, $sp, 24
    jr    $ra
    nop
al_dv_ok:
    # Verifica se o primeiro caractere é '-'
    lb    $t6, 0($t0)
    li    $t7, 45                     # 45 = '-'
    bne   $t6, $t7, al_badfmt         # Se não for '-', pára
    addi  $t0, $t0, 1                # Avança ponteiro do buffer

    # Inicializa novo limite em $t8 (valor em centavos)
    move  $t8, $zero
al_val_loop:
    lb    $t6, 0($t0)
    beq   $t6, $zero, al_val_end      # Fim da string: termina leitura
    blt   $t6, 48, al_badfmt          # ASCII < '0'? Erro
    bgt   $t6, 57, al_badfmt          # ASCII > '9'? Erro
    addi  $t6, $t6, -48               # Converte ASCII para inteiro
    mul   $t8, $t8, 10                # Multiplica acumulador por 10
    addu  $t8, $t8, $t6               # Soma o dígito lido
    addi  $t0, $t0, 1                 # Avança caractere
    j     al_val_loop
    nop
al_val_end:

    # Procura pelo cliente correspondente
    lw    $t9, MAX_CLIENTS            # Carrega o número máximo de clientes
    move  $t1, $zero                  # Inicia o índice do cliente
al_find_loop:
    beq   $t1, $t9, al_not_found      # Fora do limite, não achou
    la    $a0, clientes_usado         # Carrega base do array clientes_usado
    addu  $a0, $a0, $t1
    lb    $a1, 0($a0)                 # Lê flag "usado" desse cliente
    beq   $a1, $zero, al_next_i       # Não está em uso? Pula para próximo

    la    $a2, clientes_conta         # Base do array contas
    li    $a3, 7                      # 7 bytes por conta
    mul   $a3, $t1, $a3               # Offset i*7
    addu  $a2, $a2, $a3
    la    $a3, cc_buf_acc             # Ponteiro para conta digitada
    li    $v1, 0                      # Contador de posição
al_cmp6:
    lb    $t2, 0($a2)                 # Byte da conta salva
    lb    $t3, 0($a3)                 # Byte da conta digitada
    bne   $t2, $t3, al_next_i         # Se diferente, pula pra próximo
    addi  $a2, $a2, 1
    addi  $a3, $a3, 1
    addi  $v1, $v1, 1
    blt   $v1, 6, al_cmp6             # Repete 6 vezes

    la    $a2, clientes_dv            # Pega dv do cliente
    addu  $a2, $a2, $t1
    lb    $t2, 0($a2)
    bne   $t2, $s1, al_next_i         # Comparar dv

    # Achou o cliente
    sll   $t0, $t1, 2                 # Multiplica i por 4 (4 bytes p/word)
    la    $t2, clientes_devido_cent
    addu  $t2, $t2, $t0
    lw    $t3, 0($t2)                 # Pega quanto ele deve
    sltu  $v1, $t8, $t3               # Se novo limite < devido, erro
    bne   $v1, $zero, al_baixo

    la    $t4, clientes_limite_cent
    addu  $t4, $t4, $t0
    sw    $t8, 0($t4)                 # Salva novo limite

    li    $v0, 4
    la    $a0, msg_limite_ok
    syscall
    li    $v0, 1
    j     al_done
    nop

al_next_i:
    addiu $t1, $t1, 1                 # Próximo cliente
    j     al_find_loop
    nop

al_not_found:
    li    $v0, 4
    la    $a0, msg_err_cli_inexist     # Mensagem cliente não existe
    syscall
    li    $v0, 1
    j     al_done
    nop

al_baixo:
    li    $v0, 4
    la    $a0, msg_limite_baixo_divida # Mensagem de erro de limite
    syscall
    li    $v0, 1
    j     al_done
    nop

al_badfmt:
    li    $v0, 4
    la    $a0, msg_cc_badfmt           # Mensagem formato incorreto
    syscall
    li    $v0, 1
    j     al_done
    nop

al_not_mine:
    move  $v0, $zero                   # Sinaliza que não era pra essa rotina

al_done:
    lw    $s1, 12($sp)                 # Restaura registradores
    lw    $s0, 16($sp)
    lw    $ra, 20($sp)
    addiu $sp, $sp, 24
    jr    $ra
    nop

################################################################
# DEBUG R3: Dump de transações (CRÉDITO / DÉBITO)
################################################################

.data
# (Bloco de dados omitido para foco nos comentários em código)

.align 2
.text

# --------------------------------------------------------------
# handle_dump_trans_credito(a0=inp_buf) -> v0=1 tratou, 0 nao
# --------------------------------------------------------------
handle_dump_trans_credito:
    addiu $sp, $sp, -40             # Reserva espaço pilha
    sw    $ra, 36($sp)
    sw    $s0, 32($sp)
    sw    $s1, 28($sp)
    sw    $s2, 24($sp)
    sw    $s3, 20($sp)

    move  $t8, $a0                  # Guarda ponteiro base input
    move  $t0, $a0
    la    $t1, str_dump_cred_local  # Prefixo padrão
    move  $t9, $zero                # Flag para tentar segundo prefixo

dtc_pref:
    lb    $t2, 0($t1)
    beq   $t2, $zero, dtc_pref_ok   # Prefixo acabado: confirmou
    lb    $t3, 0($t0)
    beq   $t2, $t3, dtc_pref_adv    # Igual, segue testando
    bne   $t9, $zero, dtc_not_mine  # Já tentou ambos prefixos? Sai
    li    $t9, 1                    # Marca que vai tentar outro prefixo
    move  $t0, $t8                  # Reset buffer input
    la    $t1, str_dump_trans_cred_local # Aponta para segundo prefixo
    j     dtc_pref
    nop

dtc_pref_adv:
    addi  $t1, $t1, 1               # Avança prefixo
    addi  $t0, $t0, 1               # Avança buffer
    j     dtc_pref
    nop

dtc_pref_ok:
    la    $t4, cc_buf_acc           # Para salvar conta lida
    li    $t5, 0
# Lê 6 caracteres da conta
    dtc_acc:
    lb    $t6, 0($t0)
    blt   $t6, 48,  dtc_badfmt
    bgt   $t6, 57,  dtc_badfmt
    sb    $t6, 0($t4)
    addi  $t4, $t4, 1
    addi  $t0, $t0, 1
    addi  $t5, $t5, 1
    blt   $t5, 6,   dtc_acc         # Loop seis vezes
    sb    $zero, 0($t4)             # Marca fim da string
    lb    $t6, 0($t0)
    li    $t7, 45                   # '-'
    bne   $t6, $t7, dtc_badfmt
    addi  $t0, $t0, 1

    lb    $s1, 0($t0)               # Lê dv
    addi  $t0, $t0, 1
    li    $t7, 88                   # 'X'
    beq   $s1, $t7, dtc_dv_ok       # Aceita 'X' como dv
    blt   $s1, 48, dtc_badfmt
    bgt   $s1, 57, dtc_badfmt

dtc_dv_ok:
    lw    $t9, MAX_CLIENTS
    move  $s0, $zero

dtc_find:
    beq   $s0, $t9, dtc_not_found   # Se passou do fim, não encontrou
    la    $a0, clientes_usado
    addu  $a0, $a0, $s0
    lb    $a1, 0($a0)
    beq   $a1, $zero, dtc_next      # Não usado? pula

    la    $a2, clientes_conta
    li    $a3, 7
    mul   $a3, $s0, $a3
    addu  $a2, $a2, $a3
    la    $a3, cc_buf_acc
    li    $v1, 0
    dtc_cmp6:
    lb    $t2, 0($a2)
    lb    $t3, 0($a3)
    bne   $t2, $t3, dtc_next
    addi  $a2, $a2, 1
    addi  $a3, $a3, 1
    addi  $v1, $v1, 1
    blt   $v1, 6, dtc_cmp6          # Compara 6 dígitos

    la    $a2, clientes_dv
    addu  $a2, $a2, $s0
    lb    $t2, 0($a2)
    bne   $t2, $s1, dtc_next        # DV difere, pula

    li    $v0, 4
    la    $a0, dump_hdr_cred        # Print header
    syscall

    la    $s2, trans_cred_vals
    li    $t0, 200                  # Buffer do cliente tamanho 200 bytes
    mul   $t1, $s0, $t0             # Offset bloco deste cliente
    addu  $s2, $s2, $t1

    la    $t2, trans_cred_wptr
    sll   $t3, $s0, 2
    addu  $t2, $t2, $t3
    lw    $s3, 0($t2)               # Posição do próximo elemento do buffer (ponteiro circular)

    li    $t4, 0
    dtc_loop:
    li    $t5, 50                   # Dump de 50 transações
    beq   $t4, $t5, dtc_done

    addu  $t6, $s3, $t4
    sltiu $t7, $t6, 50
    bne   $t7, $zero, dtc_idx_ok
    addi  $t6, $t6, -50             # Corrige índice do buffer circular
    dtc_idx_ok:
    sll   $t6, $t6, 2               # Offset (cada valor 4 bytes)
    addu  $t8, $s2, $t6
    lw    $a0, 0($t8)               # Pega valor

    li    $v0, 1
    syscall                         # Print número
    li    $v0, 11
    li    $a0, 10                   # Print caractere '\n'
    syscall

    addi  $t4, $t4, 1
    j     dtc_loop
    nop

dtc_done:
    li    $v0, 1
    j     dtc_epilogue
    nop

dtc_next:
    addi  $s0, $s0, 1
    j     dtc_find
    nop

dtc_not_found:
    li    $v0, 4
    la    $a0, msg_err_cli_inexist
    syscall
    li    $v0, 1
    j     dtc_epilogue
    nop

dtc_badfmt:
    li    $v0, 4
    la    $a0, msg_cc_badfmt
    syscall
    li    $v0, 1
    j     dtc_epilogue
    nop

dtc_not_mine:
    move  $v0, $zero

dtc_epilogue:
    lw    $s3, 20($sp)
    lw    $s2, 24($sp)
    lw    $s1, 28($sp)
    lw    $s0, 32($sp)
    lw    $ra, 36($sp)
    addiu $sp, $sp, 40
    jr    $ra
    nop
# --------------------------------------------------------------
# handle_dump_trans_debito(a0=inp_buf) -> v0=1 tratou, 0 nao
# --------------------------------------------------------------
# (Você pode usar uma lógica idêntica para o handler de débito, apenas substituindo os nomes do prefixo,
# buffers e mensagens para as de débito.)
handle_dump_trans_debito:
    addiu $sp, $sp, -40
    sw    $ra, 36($sp)
    sw    $s0, 32($sp)
    sw    $s1, 28($sp)
    sw    $s2, 24($sp)
    sw    $s3, 20($sp)

    move  $t8, $a0
    move  $t0, $a0
    la    $t1, str_dump_deb_local
    move  $t9, $zero

dtd_pref:
    lb    $t2, 0($t1)
    beq   $t2, $zero, dtd_pref_ok
    lb    $t3, 0($t0)
    beq   $t2, $t3, dtd_pref_adv
    bne   $t9, $zero, dtd_not_mine
    li    $t9, 1
    move  $t0, $t8
    la    $t1, str_dump_trans_deb_local
    j     dtd_pref
    nop

dtd_pref_adv:
    addi  $t1, $t1, 1
    addi  $t0, $t0, 1
    j     dtd_pref
    nop

dtd_pref_ok:
    la    $t4, cc_buf_acc
    li    $t5, 0
dtd_acc:
    lb    $t6, 0($t0)
    blt   $t6, 48,  dtd_badfmt
    bgt   $t6, 57,  dtd_badfmt
    sb    $t6, 0($t4)
    addi  $t4, $t4, 1
    addi  $t0, $t0, 1
    addi  $t5, $t5, 1
    blt   $t5, 6,   dtd_acc
    sb    $zero, 0($t4)
    lb    $t6, 0($t0)
    li    $t7, 45
    bne   $t6, $t7, dtd_badfmt
    addi  $t0, $t0, 1

    lb    $s1, 0($t0)
    addi  $t0, $t0, 1
    li    $t7, 88
    beq   $s1, $t7, dtd_dv_ok
    blt   $s1, 48, dtd_badfmt
    bgt   $s1, 57, dtd_badfmt

dtd_dv_ok:

    lw    $t9, MAX_CLIENTS
    move  $s0, $zero
dtd_find:
    beq   $s0, $t9, dtd_not_found

    la    $a0, clientes_usado
    addu  $a0, $a0, $s0
    lb    $a1, 0($a0)
    beq   $a1, $zero, dtd_next

    la    $a2, clientes_conta
    li    $a3, 7
    mul   $a3, $s0, $a3
    addu  $a2, $a2, $a3
    la    $a3, cc_buf_acc
    li    $v1, 0
dtd_cmp6:
    lb    $t2, 0($a2)
    lb    $t3, 0($a3)
    bne   $t2, $t3, dtd_next
    addi  $a2, $a2, 1
    addi  $a3, $a3, 1
    addi  $v1, $v1, 1
    blt   $v1, 6, dtd_cmp6

    la    $a2, clientes_dv
    addu  $a2, $a2, $s0
    lb    $t2, 0($a2)
    bne   $t2, $s1, dtd_next

    li    $v0, 4
    la    $a0, dump_hdr_deb
    syscall

    la    $s2, trans_deb_vals
    li    $t0, 200
    mul   $t1, $s0, $t0
    addu  $s2, $s2, $t1

    la    $t2, trans_deb_wptr
    sll   $t3, $s0, 2
    addu  $t2, $t2, $t3
    lw    $s3, 0($t2)

    li    $t4, 0
dtd_loop:
    li    $t5, 50
    beq   $t4, $t5, dtd_done

    addu  $t6, $s3, $t4
    sltiu $t7, $t6, 50
    bne   $t7, $zero, dtd_idx_ok
    addi  $t6, $t6, -50

dtd_idx_ok:
    sll   $t6, $t6, 2
    addu  $t8, $s2, $t6
    lw    $a0, 0($t8)

    li    $v0, 1
    syscall
    li    $v0, 11
    li    $a0, 10
    syscall

    addi  $t4, $t4, 1
    j     dtd_
    nop

dtd_done:
    li    $v0, 1
    j     dtd_epilogue
    nop

dtd_next:
    addi  $s0, $s0, 1
    j     dtd_find
    nop

dtd_not_found:
    li    $v0, 4
    la    $a0, msg_err_cli_inexist
    syscall
    li    $v0, 1
    j     dtd_epilogue
    nop

dtd_badfmt:
    li    $v0, 4
    la    $a0, msg_cc_badfmt
    syscall
    li    $v0, 1
    j     dtd_epilogue
    nop

dtd_not_mine:
    move  $v0, $zero

dtd_epilogue:
    lw    $s3, 20($sp)
    lw    $s2, 24($sp)
    lw    $s1, 28($sp)
    lw    $s0, 32($sp)
    lw    $ra, 36($sp)
    addiu $sp, $sp, 40
    jr    $ra
    nop

# --------------------------------------------------------------
# Aliases (nomes esperados pelo main.asm)
# --------------------------------------------------------------
handle_dump_trans_cred:
    j handle_dump_trans_credito
    nop

handle_dump_trans_deb:
    j handle_dump_trans_debito
    nop

# =============================================================
# R7 - Juros automáticos (1% a cada 60s) e registro no ring CRED
# =============================================================
.text
aplicar_juros_auto:
    addiu $sp, $sp, -32
    sw    $ra, 28($sp)
    sw    $s0, 24($sp)
    sw    $s1, 20($sp)
    sw    $s2, 16($sp)
    sw    $s3, 12($sp)
    sw    $s4,  8($sp)

    # Verifica se já passou 1 minuto (60s) para aplicar juros
    lw    $t0, curr_sec
    bne   $t0, $zero, .sec_not_zero
    nop

    # Se for o segundo zero, usa a flag juros_gate para não repetir
    lw    $t1, juros_gate
    bne   $t1, $zero, .done
    li    $t1, 1
    sw    $t1, juros_gate
    j     .apply_all
    nop

.sec_not_zero:
    sw    $zero, juros_gate
    j     .done
    nop

# -------------------------------------------------------------
# Aplica juros a todos os clientes ativos (1% do valor devido)
# -------------------------------------------------------------
.apply_all:
    lw    $t9, MAX_CLIENTS         # Número total de clientes
    lw    $s4, TRANS_MAX           # Capacidade do buffer (50)
    li    $s0, 0                   # Índice do cliente i = 0

._i:
    beq   $s0, $t9, .done          # Fim da lista de clientes

    # Se o cliente não estiver em uso, pula
    la    $t2, clientes_usado
    addu  $t2, $t2, $s0
    lb    $t3, 0($t2)
    beq   $t3, $zero, .next_i

    # Lê valor devido em centavos
    sll   $t0, $s0, 2
    la    $t1, clientes_devido_cent
    addu  $t1, $t1, $t0
    lw    $t4, 0($t1)
    blez  $t4, .next_i             # Se nada devido, ignora

    # Calcula juros = devido / 100 (1%)
    li    $t5, 100
    divu  $t4, $t5
    mflo  $t6                      # t6 = juros
    beq   $t6, $zero, .next_i      # Se 0, ignora

    # Atualiza a dívida (devido += juros)
    addu  $t4, $t4, $t6
    sw    $t4, 0($t1)

    # ---- Registra no ring buffer de CRED ----
    la    $t7, trans_cred_head
    addu  $t7, $t7, $t0
    lw    $s1, 0($t7)              # s1 = posição head atual

    la    $t8, trans_cred_count
    addu  $t8, $t8, $t0
    lw    $s2, 0($t8)              # s2 = contador atual

    # Calcula o endereço dentro do buffer circular
    move  $a0, $s0                 # i = índice do cliente
    move  $a1, $s1                 # head atual
    jal   calc_off_i50k            # Chama função para calcular offset
    nop
    move  $t2, $v0                 # Offset resultante

    # Escreve o valor dos juros positivos no histórico
    la    $a3, trans_cred_vals
    addu  $a3, $a3, $t2
    sw    $t6, 0($a3)

    # Atualiza o head: (head + 1) % CAP
    addiu $s1, $s1, 1
    divu  $s1, $s4
    mfhi  $s1
    sw    $s1, 0($t7)

    # Atualiza o ponteiro de escrita (wptr)
    sll   $t0, $s0, 2
    la    $t2, trans_cred_wptr
    addu  $t2, $t2, $t0
    sw    $s1, 0($t2)

    # Atualiza contador (máximo até CAP)
    sltu  $t5, $s2, $s4
    beq   $t5, $zero, .next_i
    nop
    addiu $s2, $s2, 1
    sw    $s2, 0($t8)

.next_i:
    addiu $s0, $s0, 1
    j     ._i
    nop

.done:
    lw    $s4,  8($sp)
    lw    $s3, 12($sp)
    lw    $s2, 16($sp)
    lw    $s1, 20($sp)
    lw    $s0, 24($sp)
    lw    $ra, 28($sp)
    addiu $sp, $sp, 32
    jr    $ra
    nop

# =============================================================
# handle_pagar_fatura - comando: pagar_fatura-<CONTA6>-<DV>-<VALOR>-<METHOD>
# =============================================================
handle_pagar_fatura:
    addiu $sp, $sp, -32
    sw    $ra, 28($sp)
    sw    $s0, 24($sp)   # índice do cliente
    sw    $s1, 20($sp)   # DV
    sw    $s2, 16($sp)   # METHOD ('S' ou 'E')

    # Verifica prefixo "pagar_fatura-"
    move  $t0, $a0
    la    $t1, str_cmd_pay_fatura
pf_pref_:
    lb    $t2, 0($t1)
    beq   $t2, $zero, pf_pref_ok
    lb    $t3, 0($t0)
    bne   $t2, $t3, pf_not_mine
    addiu $t1, $t1, 1
    addiu $t0, $t0, 1
    j     pf_pref_
    nop

# -------------------------------------------------------------
# Lê número da conta e DV
# -------------------------------------------------------------
pf_pref_ok:
    la    $t4, cc_buf_acc
    li    $t5, 0
pf_acc_:
    lb    $t6, 0($t0)
    blt   $t6, 48, pf_badfmt
    bgt   $t6, 57, pf_badfmt
    sb    $t6, 0($t4)
    addiu $t4, $t4, 1
    addiu $t0, $t0, 1
    addiu $t5, $t5, 1
    blt   $t5, 6, pf_acc_
    sb    $zero, 0($t4)

    # Espera '-'
    lb    $t6, 0($t0)
    li    $t7, 45
    bne   $t6, $t7, pf_badfmt
    addiu $t0, $t0, 1

    # Lê DV
    lb    $s1, 0($t0)
    addiu $t0, $t0, 1
    li    $t7, 88        # 'X'
    beq   $s1, $t7, pf_dv_ok
    blt   $s1, 48, pf_badfmt
    bgt   $s1, 57, pf_badfmt
pf_dv_ok:

    # Outro '-'
    lb    $t6, 0($t0)
    li    $t7, 45
    bne   $t6, $t7, pf_badfmt
    addiu $t0, $t0, 1

# -------------------------------------------------------------
# Lê valor em centavos até o próximo '-'
# -------------------------------------------------------------
    move  $t8, $zero
pf_val_:
    lb    $t6, 0($t0)
    beq   $t6, 45,   pf_val_end
    beq   $t6, $zero, pf_badfmt
    blt   $t6, 48,   pf_badfmt
    bgt   $t6, 57,   pf_badfmt
    addiu $t6, $t6, -48
    mul   $t8, $t8, 10
    addu  $t8, $t8, $t6
    addiu $t0, $t0, 1
    j     pf_val_
    nop
pf_val_end:
    # Normaliza para múltiplo de 100
    li    $t1, 100
    divu  $t8, $t1
    mflo  $t2
    mul   $t8, $t2, 100
    addiu $t0, $t0, 1         # Pula '-'

# -------------------------------------------------------------
# Lê método ('S' = saldo, 'E' = externo)
# -------------------------------------------------------------
    lb    $s2, 0($t0)
    li    $t7, 'S'
    beq   $s2, $t7, pf_meth_ok
    li    $t7, 'E'
    beq   $s2, $t7, pf_meth_ok
    j     pf_badfmt
pf_meth_ok:
    addiu $t0, $t0, 1
    lb    $t6, 0($t0)
    bne   $t6, $zero, pf_badfmt

# -------------------------------------------------------------
# Procura cliente e aplica pagamento
# -------------------------------------------------------------
    lw    $t9, MAX_CLIENTS
    li    $s0, 0
pf_find_loop:
    beq   $s0, $t9, pf_not_found

    # Cliente em uso?
    la    $t2, clientes_usado
    addu  $t2, $t2, $s0
    lb    $t3, 0($t2)
    beq   $t3, $zero, pf_next_i

    # Compara conta (6 dígitos)
    la    $t4, clientes_conta
    li    $t5, 7
    mul   $t5, $s0, $t5
    addu  $t4, $t4, $t5
    la    $t6, cc_buf_acc
    li    $v1, 0
pf_cmp6:
    lb    $t2, 0($t4)
    lb    $t3, 0($t6)
    bne   $t2, $t3, pf_next_i
    addiu $t4, $t4, 1
    addiu $t6, $t6, 1
    addiu $v1, $v1, 1
    blt   $v1, 6, pf_cmp6

    # Compara DV
    la    $t4, clientes_dv
    addu  $t4, $t4, $s0
    lb    $t2, 0($t4)
    bne   $t2, $s1, pf_next_i

# -------------------------------------------------------------
# Cliente encontrado — aplica pagamento
# -------------------------------------------------------------
    sll   $t0, $s0, 2

    # Lê dívida atual
    la    $t1, clientes_devido_cent
    addu  $t1, $t1, $t0
    lw    $t2, 0($t1)
    # Normaliza dívida para múltiplo de 100
    li    $t3, 100
    divu  $t2, $t3
    mflo  $t4
    mul   $t2, $t4, 100

    # Valor não pode ser maior que a dívida
    sltu  $v1, $t2, $t8
    bne   $v1, $zero, pf_val_maior

    # Se for método 'S', precisa ter saldo suficiente
    li    $t7, 'S'
    bne   $s2, $t7, pf_do_debt_only

    la    $t5, clientes_saldo_cent
    addu  $t5, $t5, $t0
    lw    $t6, 0($t5)
    sltu  $v1, $t6, $t8
    bne   $v1, $zero, pf_saldo_insuf

    # saldo -= valor
    subu  $t6, $t6, $t8
    sw    $t6, 0($t5)

pf_do_debt_only:
    # dívida -= valor
    subu  $t2, $t2, $t8
    sw    $t2, 0($t1)

    # Mensagem de sucesso
    li    $v0, 4
    la    $a0, msg_pago_com_sucesso
    syscall
    li    $v0, 1
    j     pf_epilogue
    nop

# -------------------------------------------------------------
# Tratamento de erros
# -------------------------------------------------------------
pf_next_i:
    addiu $s0, $s0, 1
    j     pf_find_loop
    nop

pf_not_found:
    li    $v0, 4
    la    $a0, msg_err_cli_inexist
    syscall
    li    $v0, 1
    j     pf_epilogue
    nop

pf_saldo_insuf:
    li    $v0, 4
    la    $a0, msg_err_saldo_insuf
    syscall
    li    $v0, 1
    j     pf_epilogue
    nop

pf_val_maior:
    li    $v0, 4
    la    $a0, msg_err_valor_maior
    syscall
    li    $v0, 1
    j     pf_epilogue
    nop

pf_badfmt:
    li    $v0, 4
    la    $a0, msg_cc_badfmt
    syscall
    li    $v0, 1
    j     pf_epilogue
    nop

pf_not_mine:
    move  $v0, $zero

# -------------------------------------------------------------
# Epílogo — restaura registradores e retorna
# -------------------------------------------------------------
pf_epilogue:
    lw    $s2, 16($sp)
    lw    $s1, 20($sp)
    lw    $s0, 24($sp)
    lw    $ra, 28($sp)
    addiu $sp, $sp, 32
    jr    $ra
    nop
# ------------------------------------------------------------
# R8: sacar-<CONTA6>-<DV>-<VALORcentavos>
# Handler para comando de saque. Formato esperado: "sacar-123456-7-1000"
# Onde CONTA6 = 6 dígitos da conta, DV = dígito verificador (0-9 ou 'X'), VALORcentavos = valor em centavos (ex: 1000 -> R$10,00)
# Convenções de registradores usadas neste trecho:
#  $a0 : ponteiro para string do comando (entrada)
#  $s0 : índice do cliente (quando encontrado)
#  $s1 : DV lido
#  $s2 : preservado (salvo/restaurado na pilha)
#  $t0-$t9 : temporários diversos (uso local)
#  $v0, $v1 : valores de retorno / flags
#  NOTA: rotina preserva $ra, $s0-$s2 na pilha

handle_sacar:
    addiu $sp, $sp, -32           # abre frame de pilha
    sw    $ra, 28($sp)            # salva RA
    sw    $s0, 24($sp)            # salva s0 (índice cliente)
    sw    $s1, 20($sp)            # salva s1 (DV)
    sw    $s2, 16($sp)            # salva s2 (uso geral)

    # prefixo "sacar-"  -> verifica se comando começa com esse prefixo
    move  $t0, $a0                # t0 = ponteiro da string de entrada
    la    $t1, str_cmd_sacar      # t1 = ponteiro para literal "sacar-"
hs_pref:
    lb    $t2, 0($t1)
    beq   $t2, $zero, hs_pref_ok  # fim do prefixo -> ok
    lb    $t3, 0($t0)
    bne   $t2, $t3, hs_not_mine   # se caractere diferente, não é esse handler
    addiu $t1, $t1, 1
    addiu $t0, $t0, 1
    j     hs_pref
    nop

hs_pref_ok:
    # conta (6 dígitos) -> copia para cc_buf_acc
    la    $t4, cc_buf_acc         # t4 aponta para buffer temporário de conta
    li    $t5, 0                  # contador de dígitos lidos
hs_acc:
    lb    $t6, 0($t0)
    blt   $t6, 48, hs_badfmt      # caractere < '0' => formato inválido
    bgt   $t6, 57, hs_badfmt      # caractere > '9' => formato inválido
    sb    $t6, 0($t4)             # armazena dígito no buffer
    addiu $t4, $t4, 1
    addiu $t0, $t0, 1
    addiu $t5, $t5, 1
    blt   $t5, 6, hs_acc          # repete até ler 6 dígitos
    sb    $zero, 0($t4)           # termina string (NULL)

    # espera '-' separador
    lb    $t6, 0($t0)
    li    $t7, 45                 # ascii '-' = 45
    bne   $t6, $t7, hs_badfmt
    addiu $t0, $t0, 1

    # DV (um caractere)
    lb    $s1, 0($t0)             # s1 = DV lido (pode ser 'X' ou '0'-'9')
    addiu $t0, $t0, 1
    li    $t7, 88                 # 'X'
    beq   $s1, $t7, hs_dv_ok      # aceita 'X' como DV válido
    blt   $s1, 48, hs_badfmt
    bgt   $s1, 57, hs_badfmt
hs_dv_ok:

    # espera '-' separador
    lb    $t6, 0($t0)
    li    $t7, 45
    bne   $t6, $t7, hs_badfmt
    addiu $t0, $t0, 1

    # VALOR -> acumula em $t8 (valor em centavos lido como inteiro decimal)
    move  $t8, $zero
hs_val:
    lb    $t6, 0($t0)
    beq   $t6, $zero, hs_val_end  # fim da string -> terminou leitura do valor
    blt   $t6, 48, hs_badfmt
    bgt   $t6, 57, hs_badfmt
    addiu $t6, $t6, -48           # converte ascii -> valor numérico
    mul   $t8, $t8, 10            # valor = valor * 10
    addu  $t8, $t8, $t6           # adiciona novo dígito
    addiu $t0, $t0, 1
    j     hs_val
    nop
hs_val_end:
    # normaliza centavos: converte valor para múltiplos de 100 (arredonda para baixo)
    # Ex: se usuário informou 12345, divide por 100 -> 123 (R$1,23), multiplica por 100 -> 12300
    li    $t0, 100
    divu  $t8, $t0
    mflo  $t1
    mul   $t8, $t1, 100

    # procurar cliente por conta+DV
    lw    $t9, MAX_CLIENTS        # t9 = número máximo de clientes
    li    $s0, 0                  # s0 = índice atual (começa em 0)
hs_find:
    beq   $s0, $t9, hs_not_found  # se percorreu todos -> não encontrou

    la    $t2, clientes_usado     # verifica se slot de cliente está em uso
    addu  $t2, $t2, $s0
    lb    $t3, 0($t2)
    beq   $t3, $zero, hs_next     # se não está em uso, passa para próximo

    # compara os 6 dígitos da conta
    la    $t4, clientes_conta
    li    $t5, 7
    mul   $t5, $s0, $t5           # offset = s0 * 7 (cada conta tem 6 chars + terminador)
    addu  $t4, $t4, $t5
    la    $t6, cc_buf_acc         # buffer com conta lida
    li    $t7, 0
hs_cmp6:
    lb    $t2, 0($t4)
    lb    $t3, 0($t6)
    bne   $t2, $t3, hs_next       # se algum caractere difere -> não é esse cliente
    addiu $t4, $t4, 1
    addiu $t6, $t6, 1
    addiu $t7, $t7, 1
    blt   $t7, 6, hs_cmp6

    # compara DV
    la    $t4, clientes_dv
    addu  $t4, $t4, $s0
    lb    $t2, 0($t4)
    bne   $t2, $s1, hs_next       # DV diferente -> próximo

    # ---- ACHOU: cliente em s0 ----
    sll   $t0, $s0, 2
    la    $t1, clientes_saldo_cent
    addu  $t1, $t1, $t0
    lw    $t2, 0($t1)           # $t2 = saldo atual (em centavos)
    sltu  $v1, $t2, $t8        # v1 = 1 se saldo < valor
    bne   $v1, $zero, hs_saldo_insuf

    subu  $t2, $t2, $t8        # subtrai o valor do saldo
    sw    $t2, 0($t1)          # grava novo saldo

    # grava também no ring DEB (em head) -> anota transação de débito
    la    $t4, trans_deb_head
    addu  $t4, $t4, $t0
    lw    $t5, 0($t4)           # t5 = head (posição de escrita atual)
    move  $a0, $s0              # prepara parâmetros para calc_off_i50k
    move  $a1, $t5
    jal   calc_off_i50k         # calcula offset (index -> endereço em trans_deb_vals)
    nop
    move  $t6, $v0
    la    $t7, trans_deb_vals
    addu  $t7, $t7, $t6
    sw    $t8, 0($t7)           # grava valor no buffer de transações de débito

    addiu $t5, $t5, 1
    li    $t6, 50
    bne   $t5, $t6, hs_head_ok
    move  $t5, $zero            # wrap-around: se head == 50 -> volta a 0
hs_head_ok:
    sw    $t5, 0($t4)           # grava novo head

    # (RECALC idx4 após jal)
    sll   $t0, $s0, 2
    la    $t7, trans_deb_wptr
    addu  $t7, $t7, $t0
    sw    $t5, 0($t7)           # grava wptr (write pointer)
    la    $t7, trans_deb_count
    addu  $t7, $t7, $t0
    lw    $t6, 0($t7)           # lê contagem de registros no ring
    bltz  $t6, hs_cnt_zero
    li    $t9, 50
    sltu  $v1, $t6, $t9
    beq   $v1, $zero, hs_log_ok # se count >= 50 -> não incrementa (anel cheio)
    addiu $t6, $t6, 1
    sw    $t6, 0($t7)
    j     hs_log_ok
    nop
hs_cnt_zero:
    li    $t6, 1
    sw    $t6, 0($t7)
hs_log_ok:

    # registra transação detalhada: tipo=0 (débito), conta atual, valor
    move  $a0, $s0
    li    $a1, 0
    la    $a2, cc_buf_acc
    move  $a3, $t8
    jal   adicionar_transacao_detalhe
    nop

    li    $v0, 4
    la    $a0, msg_saque_ok      # mensagem "saque ok"
    syscall
    li    $v0, 1                 # retorna 1 em v0 para indicar que o handler processou o comando
    j     hs_done
    nop

hs_next:
    addiu $s0, $s0, 1
    j     hs_find
    nop

hs_not_found:
    li    $v0, 4
    la    $a0, msg_err_cli_inexist
    syscall
    li    $v0, 1
    j     hs_done
    nop

hs_saldo_insuf:
    li    $v0, 4
    la    $a0, msg_err_saldo_insuf
    syscall
    li    $v0, 1
    j     hs_done
    nop

hs_badfmt:
    li    $v0, 4
    la    $a0, msg_cc_badfmt
    syscall
    li    $v0, 1
    j     hs_done
    nop

hs_not_mine:
    move  $v0, $zero            # se prefixo não é "sacar-", devolve 0 (não processou)

hs_done:
    lw    $s2, 16($sp)          # restaura registradores salvos
    lw    $s1, 20($sp)
    lw    $s0, 24($sp)
    lw    $ra, 28($sp)
    addiu $sp, $sp, 32          # fecha frame de pilha
    jr    $ra
    nop


# ------------------------------------------------------------
# R8: depositar-<CONTA6>-<DV>-<VALORcentavos>
# Handler para comando de depósito. Mesma estrutura do saque, mas incrementa saldo
# e registra no ring de crédito.

handle_depositar:
    addiu $sp, $sp, -32
    sw    $ra, 28($sp)
    sw    $s0, 24($sp)
    sw    $s1, 20($sp)
    sw    $s2, 16($sp)

    # prefixo "depositar-"
    move  $t0, $a0
    la    $t1, str_cmd_depositar
hdp_pref:
    lb    $t2, 0($t1)
    beq   $t2, $zero, hdp_pref_ok
    lb    $t3, 0($t0)
    bne   $t2, $t3, hdp_not_mine
    addiu $t1, $t1, 1
    addiu $t0, $t0, 1
    j     hdp_pref
    nop

hdp_pref_ok:
    # conta (6 dígitos)
    la    $t4, cc_buf_acc
    li    $t5, 0
hdp_acc:
    lb    $t6, 0($t0)
    blt   $t6, 48, hdp_badfmt
    bgt   $t6, 57, hdp_badfmt
    sb    $t6, 0($t4)
    addiu $t4, $t4, 1
    addiu $t0, $t0, 1
    addiu $t5, $t5, 1
    blt   $t5, 6, hdp_acc
    sb    $zero, 0($t4)

    # '-'
    lb    $t6, 0($t0)
    li    $t7, 45
    bne   $t6, $t7, hdp_badfmt
    addiu $t0, $t0, 1

    # DV
    lb    $s1, 0($t0)
    addiu $t0, $t0, 1
    li    $t7, 88           # 'X'
    beq   $s1, $t7, hdp_dv_ok
    blt   $s1, 48, hdp_badfmt
    bgt   $s1, 57, hdp_badfmt
hdp_dv_ok:

    # '-'
    lb    $t6, 0($t0)
    li    $t7, 45
    bne   $t6, $t7, hdp_badfmt
    addiu $t0, $t0, 1

    # VALOR -> t8
    move  $t8, $zero
hdp_val:
    lb    $t6, 0($t0)
    beq   $t6, $zero, hdp_val_end
    blt   $t6, 48, hdp_badfmt
    bgt   $t6, 57, hdp_badfmt
    addiu $t6, $t6, -48
    mul   $t8, $t8, 10
    addu  $t8, $t8, $t6
    addiu $t0, $t0, 1
    j     hdp_val
    nop
hdp_val_end:
    # normaliza centavos
    li    $t0, 100
    divu  $t8, $t0
    mflo  $t1
    mul   $t8, $t1, 100

    # procurar cliente
    lw    $t9, MAX_CLIENTS
    li    $s0, 0
hdp_find:
    beq   $s0, $t9, hdp_not_found

    la    $t2, clientes_usado
    addu  $t2, $t2, $s0
    lb    $t3, 0($t2)
    beq   $t3, $zero, hdp_next

    la    $t4, clientes_conta
    li    $t5, 7
    mul   $t5, $s0, $t5
    addu  $t4, $t4, $t5
    la    $t6, cc_buf_acc
    li    $t7, 0
hdp_cmp6:
    lb    $t2, 0($t4)
    lb    $t3, 0($t6)
    bne   $t2, $t3, hdp_next
    addiu $t4, $t4, 1
    addiu $t6, $t6, 1
    addiu $t7, $t7, 1
    blt   $t7, 6, hdp_cmp6

    la    $t4, clientes_dv
    addu  $t4, $t4, $s0
    lb    $t2, 0($t4)
    bne   $t2, $s1, hdp_next

    # ---- ACHOU s0 ----
    sll   $t0, $s0, 2
    la    $t1, clientes_saldo_cent
    addu  $t1, $t1, $t0
    lw    $t2, 0($t1)           # saldo
    addu  $t2, $t2, $t8          # soma o depósito
    sw    $t2, 0($t1)

    # grava também no ring CRED (em head)
    la    $t4, trans_cred_head
    addu  $t4, $t4, $t0
    lw    $t5, 0($t4)           # head
    move  $a0, $s0
    move  $a1, $t5
    jal   calc_off_i50k
    nop
    move  $t6, $v0
    la    $t7, trans_cred_vals
    addu  $t7, $t7, $t6
    sw    $t8, 0($t7)

    addiu $t5, $t5, 1
    li    $t6, 50
    bne   $t5, $t6, hdp_head_ok
    move  $t5, $zero
hdp_head_ok:
    sw    $t5, 0($t4)

    # (RECALC idx4 após jal)
    sll   $t0, $s0, 2
    la    $t7, trans_cred_wptr
    addu  $t7, $t7, $t0
    sw    $t5, 0($t7)
    la    $t7, trans_cred_count
    addu  $t7, $t7, $t0
    lw    $t6, 0($t7)
    bltz  $t6, hdp_cnt_zero
    li    $t9, 50
    sltu  $v1, $t6, $t9
    beq   $v1, $zero, hdp_log_ok
    addiu $t6, $t6, 1
    sw    $t6, 0($t7)
    j     hdp_log_ok
    nop
hdp_cnt_zero:
    li    $t6, 1
    sw    $t6, 0($t7)
hdp_log_ok:

    # detalhado: tipo=1 (crédito), conta atual, valor
    move  $a0, $s0
    li    $a1, 1
    la    $a2, cc_buf_acc
    move  $a3, $t8
    jal   adicionar_transacao_detalhe
    nop

    li    $v0, 4
    la    $a0, msg_dep_ok
    syscall
    li    $v0, 1
    j     hdp_done
    nop

hdp_next:
    addiu $s0, $s0, 1
    j     hdp_find
    nop

hdp_not_found:
    li    $v0, 4
    la    $a0, msg_err_cli_inexist
    syscall
    li    $v0, 1
    j     hdp_done
    nop

hdp_badfmt:
    li    $v0, 4
    la    $a0, msg_cc_badfmt
    syscall
    li    $v0, 1
    j     hdp_done
    nop

hdp_not_mine:
    move  $v0, $zero

hdp_done:
    lw    $s2, 16($sp)
    lw    $s1, 20($sp)
    lw    $s0, 24($sp)
    lw    $ra, 28($sp)
    addiu $sp, $sp, 32
    jr    $ra
    nop

