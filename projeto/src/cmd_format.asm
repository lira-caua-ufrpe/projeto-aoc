# ============================================================
# cmd_format.asm — comando: conta_format-<CONTA6>-<DV>
# Limpa meta (head/count/wptr) e zera 50 valores (deb/cred) da conta
# Retorno: v0=1 se tratou (sucesso/erro), v0=0 se não era o comando
# Dependências:
#  - data.asm: clientes_* , trans_* , cc_buf_acc , cc_buf_dv , inp_buf, msg_err_cli_inexist, msg_cc_badfmt
#  - strings.asm: strcmp, strncmp
#  - io.asm: read_line, print_str
# ============================================================

.data
# Prefixo do comando
str_cmd_conta_format: .asciiz "conta_format-"

# Mensagens locais (não dependem de data.asm)
msg_fmt_confirm1:    .asciiz "Confirmar formatacao da conta "
dash_str:            .asciiz "-"
onechar_buf:         .space  2          # Buffer para 1 char + '\0'
msg_fmt_confirm_q:   .asciiz "? (s/N): "
msg_fmt_cancel:      .asciiz "Operacao cancelada.\n"
msg_fmt_conta_ok:    .asciiz "Transacoes e meta zeradas para a conta.\n"

.text
.globl handle_conta_format

# ------------------------------------------------------------
# handle_conta_format(a0=linha) -> v0=1 (tratou) / 0 (não é meu)
# Formato aceito: conta_format-XXXXXX-D
# Confirma com "(s/N)". Ao confirmar, zera meta e 50 valores (deb/cred).
# ------------------------------------------------------------
handle_conta_format:
    # Salva registradores usados
    addiu $sp, $sp, -48
    sw    $ra, 44($sp)       # retorna endereço
    sw    $s0, 40($sp)       # i (índice do cliente)
    sw    $s1, 36($sp)       # ponteiro para XXXXXX-D
    sw    $s2, 32($sp)       # linha inteira

    move  $s2, $a0           # s2 aponta para a linha de entrada

    # Confere prefixo "conta_format-"
    la    $a1, str_cmd_conta_format
    li    $a3, 13            # tamanho do prefixo
    move  $a0, $s2
    jal   strncmp             # compara os primeiros 13 bytes
    nop
    bne   $v0, $zero, hcf_notmine  # se diferente, não é comando

    # Ponteiro para início de XXXXXX-D
    addiu $s1, $s2, 13

    # --- captura 6 dígitos da conta para cc_buf_acc ---
    la    $t4, cc_buf_acc
    li    $t5, 6
hcf_copy6:
    beq   $t5, $zero, hcf_after6
    lb    $t0, 0($s1)        # lê caractere
    li    $t1, 48             # '0'
    blt   $t0, $t1, hcf_badfmt
    li    $t1, 57             # '9'
    bgt   $t0, $t1, hcf_badfmt
    sb    $t0, 0($t4)        # salva no buffer da conta
    addiu $t4, $t4, 1
    addiu $s1, $s1, 1
    addiu $t5, $t5, -1
    j     hcf_copy6
hcf_after6:
    sb    $zero, 0($t4)      # termina string da conta

    # --- verifica hífen ---
    lb    $t0, 0($s1)
    li    $t1, '-'
    bne   $t0, $t1, hcf_badfmt
    addiu $s1, $s1, 1

    # --- captura DV (1 dígito) ---
    lb    $t0, 0($s1)
    li    $t1, 48
    blt   $t0, $t1, hcf_badfmt
    li    $t1, 57
    bgt   $t0, $t1, hcf_badfmt
    la    $t2, cc_buf_dv
    sb    $t0, 0($t2)        # armazena DV

    # --- procura cliente por conta+DV ---
    move  $s0, $zero         # índice i = 0
    li    $t7, 50             # máximo 50 clientes
hcf_find_loop:
    beq   $s0, $t7, hcf_notfound

    # verifica se o cliente está em uso
    la    $t0, clientes_usado
    addu  $t0, $t0, $s0
    lb    $t1, 0($t0)
    beq   $t1, $zero, hcf_next_i

    # compara conta (offset i*7)
    la    $t2, clientes_conta
    sll   $t3, $s0, 3        # i*8
    subu  $t3, $t3, $s0      # i*7
    addu  $a0, $t2, $t3
    la    $a1, cc_buf_acc
    jal   strcmp
    nop
    bne   $v0, $zero, hcf_next_i

    # compara DV
    la    $t4, clientes_dv
    addu  $t4, $t4, $s0
    lb    $t5, 0($t4)
    la    $t6, cc_buf_dv
    lb    $t6, 0($t6)
    bne   $t5, $t6, hcf_next_i

    # achou cliente
    j     hcf_found
hcf_next_i:
    addiu $s0, $s0, 1
    j     hcf_find_loop

hcf_notfound:
    la    $a0, msg_err_cli_inexist
    jal   print_str
    nop
    li    $v0, 1
    j     hcf_ret

hcf_badfmt:
    # Caso o formato do comando esteja incorreto
    la    $a0, msg_cc_badfmt  # carrega mensagem de formato inválido
    jal   print_str           # imprime mensagem
    nop
    li    $v0, 1              # indica que tratou o comando (erro de formato)
    j     hcf_ret             # retorna

# --- confirmação e limpeza ---
hcf_found:
    # Imprime mensagem de confirmação: "Confirmar formatacao da conta "
    la    $a0, msg_fmt_confirm1
    jal   print_str
    nop

    # Imprime número da conta (XXXXXX)
    la    $a0, cc_buf_acc
    jal   print_str
    nop

    # Imprime hífen "-"
    la    $a0, dash_str
    jal   print_str
    nop

    # Imprime DV como string de 1 caractere
    la    $t0, cc_buf_dv
    lb    $t1, 0($t0)
    la    $t2, onechar_buf
    sb    $t1, 0($t2)        # copia DV
    sb    $zero, 1($t2)      # finaliza string
    la    $a0, onechar_buf
    jal   print_str
    nop

    # Pergunta confirmação ao usuário "? (s/N): "
    la    $a0, msg_fmt_confirm_q
    jal   print_str
    nop

    # Lê resposta do usuário no buffer inp_buf
    la    $a0, inp_buf
    li    $a1, 256
    jal   read_line
    nop

    # Verifica se a resposta é 's' ou 'S'
    la    $t0, inp_buf
    lb    $t1, 0($t0)
    li    $t2, 's'
    beq   $t1, $t2, hcf_do_format
    li    $t2, 'S'
    beq   $t1, $t2, hcf_do_format

    # Caso contrário, operação cancelada
    la    $a0, msg_fmt_cancel
    jal   print_str
    nop
    li    $v0, 1
    j     hcf_ret

# --- efetiva a limpeza das transações ---
hcf_do_format:
    # Calcula offset em palavras (i*4) para débito/crédito
    sll   $t8, $s0, 2          # i*4 bytes

    # Zera meta de débito: head, count, wptr
    la    $t0, trans_deb_head
    addu  $t0, $t0, $t8
    sw    $zero, 0($t0)
    la    $t0, trans_deb_count
    addu  $t0, $t0, $t8
    sw    $zero, 0($t0)
    la    $t0, trans_deb_wptr
    addu  $t0, $t0, $t8
    sw    $zero, 0($t0)

    # Zera meta de crédito: head, count, wptr
    la    $t0, trans_cred_head
    addu  $t0, $t0, $t8
    sw    $zero, 0($t0)
    la    $t0, trans_cred_count
    addu  $t0, $t0, $t8
    sw    $zero, 0($t0)
    la    $t0, trans_cred_wptr
    addu  $t0, $t0, $t8
    sw    $zero, 0($t0)

    # Calcula offset em bytes para os 50 valores do cliente (i*200)
    sll   $t3, $s0, 5         # i*32
    sll   $t4, $s0, 4         # i*16
    addu  $t3, $t3, $t4       # i*48
    sll   $t4, $s0, 1         # i*2
    addu  $t3, $t3, $t4       # i*50
    sll   $t3, $t3, 2         # *4 -> bytes (i*200)

    # Zera 50 palavras de débito
    la    $t0, trans_deb_vals
    addu  $t0, $t0, $t3
    li    $t1, 50
hcf_zero_deb:
    sw    $zero, 0($t0)
    addiu $t0, $t0, 4
    addiu $t1, $t1, -1
    bgtz  $t1, hcf_zero_deb

    # Zera 50 palavras de crédito
    la    $t0, trans_cred_vals
    addu  $t0, $t0, $t3
    li    $t1, 50
hcf_zero_cred:
    sw    $zero, 0($t0)
    addiu $t0, $t0, 4
    addiu $t1, $t1, -1
    bgtz  $t1, hcf_zero_cred

    # Mensagem de sucesso
    la    $a0, msg_fmt_conta_ok
    jal   print_str
    nop

    li    $v0, 1              # comando tratado
    j     hcf_ret

# --- não era comando deste handler ---
hcf_notmine:
    move  $v0, $zero

# --- restaura registradores e retorna ---
hcf_ret:
    lw    $s2, 32($sp)
    lw    $s1, 36($sp)
    lw    $s0, 40($sp)
    lw    $ra, 44($sp)
    addiu $sp, $sp, 48
    jr    $ra
    nop
