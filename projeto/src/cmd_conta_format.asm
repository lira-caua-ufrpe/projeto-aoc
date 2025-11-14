# ============================================================
# Universidade Federal Rural de Pernambuco (UFRPE)
# Disciplina: Arquitetura e Organização de Computadores — 2025.2
# Avaliação: Projetos 1 (PE1) – 1a VA
# Professor: Vitor Coutinho
# Atividade: Lista de Exercícios – Questão 1 (string.h)
# Arquivo: cmd_conta_format.asm
# Equipe: OPCODE
# Integrantes: Cauã Lira; Sérgio Ricardo; Lucas Emanuel; Vitor Emmanoel
# Data de entrega: 13/11/2025 (horário da aula)
# Apresentação: vídeo no ato da entrega
# Descrição: Implementa strcpy, memcpy, strcmp, strncmp, strcat
#            e um main com casos de teste no MARS (4.5+).
# Convenções:
#   - strcpy(a0=dst, a1=src)              -> v0=dst
#   - memcpy(a0=dst, a1=src, a2=num)      -> v0=dst
#   - strcmp(a0=str1, a1=str2)            -> v0 (<0, 0, >0)
#   - strncmp(a0=str1, a1=str2, a3=num)   -> v0 (<0, 0, >0)
#   - strcat(a0=dst, a1=src)              -> v0=dst
#   - Temporários: $t0..$t9 | PC inicia em 'main'
# Observação: Como em C, o comportamento de strcat com áreas sobrepostas é indefinido.
# ============================================================








# cmd_conta_format.asm — handler para o comando "conta_format-<CONTA6>-<DV>"
# Zera a meta e os 50 valores de transações (débito/crédito) da conta informada.
# Depende de: strcmp, strncmp, print_str, read_line e símbolos definidos em data.asm.

        .text
        .globl handle_conta_format

handle_conta_format:
    # --- salvar registradores e reservar espaço na stack ---
    addiu $sp, $sp, -48
    sw    $ra, 44($sp)   # salvar endereço de retorno
    sw    $s0, 40($sp)   # salvar s0
    sw    $s1, 36($sp)   # salvar s1
    sw    $s2, 32($sp)   # salvar s2
    sw    $s3, 28($sp)   # salvar s3

    move  $s2, $a0                   # $s2 aponta para a linha completa do comando
    la    $a1, str_cmd_conta_format
    li    $a3, 13                    # comprimento da string "conta_format-"
    move  $a0, $s2
    jal   strncmp                    # compara início da linha com "conta_format-"
    nop
    bne   $v0, $zero, cfmt_notmine  # se não bate, comando não é deste handler

    # --- ponteiro para parte "XXXXXX-DV" ---
    addiu $s1, $s2, 13

    # --- copiar 6 dígitos da conta para cc_buf_acc ---
    la    $t4, cc_buf_acc
    li    $t5, 6
cfmt_copy6:
    beq   $t5, $zero, cfmt_after6    # terminou de copiar
    lb    $t0, 0($s1)                # lê caractere
    li    $t1, 48
    blt   $t0, $t1, cfmt_badfmt      # se < '0', formato inválido
    li    $t1, 57
    bgt   $t0, $t1, cfmt_badfmt      # se > '9', formato inválido
    sb    $t0, 0($t4)                # armazena no buffer da conta
    addiu $t4, $t4, 1
    addiu $s1, $s1, 1
    addiu $t5, $t5, -1
    j     cfmt_copy6
cfmt_after6:
    sb    $zero, 0($t4)              # finaliza string

    # --- verifica hífen separando conta e DV ---
    lb    $t0, 0($s1)
    li    $t1, '-'
    bne   $t0, $t1, cfmt_badfmt
    addiu $s1, $s1, 1

    # --- lê DV (1 dígito) ---
    lb    $t0, 0($s1)
    li    $t1, 48
    blt   $t0, $t1, cfmt_badfmt
    li    $t1, 57
    bgt   $t0, $t1, cfmt_badfmt
    la    $t2, cc_buf_dv
    sb    $t0, 0($t2)

    # --- procura cliente correspondente (conta+DV) ---
    move  $s0, $zero
    li    $t7, 50
cfmt_find_loop:
    beq   $s0, $t7, cfmt_notfound    # se chegar ao final, cliente não encontrado

    # verifica se posição está usada
    la    $t0, clientes_usado
    addu  $t0, $t0, $s0
    lb    $t1, 0($t0)
    beq   $t1, $zero, cfmt_next_i    # se não usado, pula para próximo

    # compara conta
    la    $t2, clientes_conta
    sll   $t3, $s0, 3
    subu  $t3, $t3, $s0              # calcula i*7
    addu  $a0, $t2, $t3
    la    $a1, cc_buf_acc
    jal   strcmp
    nop
    bne   $v0, $zero, cfmt_next_i    # se diferente, próxima

    # compara DV
    la    $t4, clientes_dv
    addu  $t4, $t4, $s0
    lb    $t5, 0($t4)
    la    $t6, cc_buf_dv
    lb    $t6, 0($t6)
    bne   $t5, $t6, cfmt_next_i

    # cliente encontrado
    j     cfmt_found
cfmt_next_i:
    addiu $s0, $s0, 1
    j     cfmt_find_loop

cfmt_notfound:
    la    $a0, msg_err_cli_inexist
    jal   print_str
    nop
    li    $v0, 1
    j     cfmt_ret

cfmt_badfmt:
    la    $a0, msg_cc_badfmt
    jal   print_str
    nop
    li    $v0, 1
    j     cfmt_ret

# --- confirmação antes de zerar ---
cfmt_found:
    la    $a0, msg_fmt_confirm1
    jal   print_str
    nop
    la    $a0, cc_buf_acc
    jal   print_str
    nop
    la    $a0, dash_str
    jal   print_str
    nop
    # imprime DV
    la    $t0, cc_buf_dv
    lb    $t1, 0($t0)
    la    $t2, onechar_buf
    sb    $t1, 0($t2)
    sb    $zero, 1($t2)
    la    $a0, onechar_buf
    jal   print_str
    nop
    la    $a0, msg_fmt_confirm_q
    jal   print_str
    nop

    # lê resposta do usuário
    la    $a0, inp_buf
    li    $a1, 256
    jal   read_line
    nop
    la    $t0, inp_buf
    lb    $t1, 0($t0)
    li    $t2, 's'
    beq   $t1, $t2, cfmt_do         # 's' confirma
    li    $t2, 'S'
    beq   $t1, $t2, cfmt_do         # 'S' confirma

    # cancelou
    la    $a0, msg_fmt_cancel
    jal   print_str
    nop
    li    $v0, 1
    j     cfmt_ret

cfmt_do:
    # --- zera metas (head, count, wptr) de débito e crédito ---
    sll   $t8, $s0, 2

    la    $t0, trans_deb_head
    addu  $t0, $t0, $t8
    sw    $zero, 0($t0)
    la    $t0, trans_deb_count
    addu  $t0, $t0, $t8
    sw    $zero, 0($t0)
    la    $t0, trans_deb_wptr
    addu  $t0, $t0, $t8
    sw    $zero, 0($t0)

    la    $t0, trans_cred_head
    addu  $t0, $t0, $t8
    sw    $zero, 0($t0)
    la    $t0, trans_cred_count
    addu  $t0, $t0, $t8
    sw    $zero, 0($t0)
    la    $t0, trans_cred_wptr
    addu  $t0, $t0, $t8
    sw    $zero, 0($t0)

    # --- zera os 50 valores de transações para esse cliente ---
    sll   $t3, $s0, 5      # i*32
    sll   $t4, $s0, 4      # i*16
    addu  $t3, $t3, $t4    # i*48
    sll   $t4, $s0, 1      # i*2
    addu  $t3, $t3, $t4    # i*50
    sll   $t3, $t3, 2      # *4 -> bytes

    # zera valores de débito
    la    $t0, trans_deb_vals
    addu  $t0, $t0, $t3
    li    $t1, 50
cfmt_zero_deb:
    sw    $zero, 0($t0)
    addiu $t0, $t0, 4
    addiu $t1, $t1, -1
    bgtz  $t1, cfmt_zero_deb

    # zera valores de crédito
    la    $t0, trans_cred_vals
    addu  $t0, $t0, $t3
    li    $t1, 50
cfmt_zero_cred:
    sw    $zero, 0($t0)
    addiu $t0, $t0, 4
    addiu $t1, $t1, -1
    bgtz  $t1, cfmt_zero_cred

    # imprime mensagem de sucesso
    la    $a0, msg_fmt_conta_ok
    jal   print_str
    nop
    li    $v0, 1
    j     cfmt_ret

cfmt_notmine:
    move  $v0, $zero                  # comando não é "conta_format"

cfmt_ret:
    # --- restaura registradores e retorna ---
    lw    $s3, 28($sp)
    lw    $s2, 32($sp)
    lw    $s1, 36($sp)
    lw    $s0, 40($sp)
    lw    $ra, 44($sp)
    addiu $sp, $sp, 48
    jr    $ra
    nop
