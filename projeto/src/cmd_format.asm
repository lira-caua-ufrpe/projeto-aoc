# ============================================================
# Universidade Federal Rural de Pernambuco (UFRPE)
# Disciplina: Arquitetura e Organização de Computadores — 2025.2
# Avaliação: Projetos 1 (PE1) – 1a VA
# Professor: Vitor Coutinho
# Atividade: Lista de Exercícios – Questão 1 (string.h)
# Arquivo: cmd_format.asm
# Equipe: OPCODE
# Integrantes: Cauã Lira; Sérgio Ricardo; Lucas Emanuel
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



# ============================================================
# cmd_format.asm — comando: conta_format-<CONTA6>-<DV>
# Limpa meta (head/count/wptr) e zera 50 valores (deb/cred) da conta
# Retorno: v0=1 se tratou (sucesso/cancelado/erro), v0=0 se não era o comando
# Dependências (já existentes no projeto):
#  - data.asm: clientes_* , trans_* , cc_buf_acc , cc_buf_dv , inp_buf, msg_err_cli_inexist, msg_cc_badfmt
#  - strings.asm: strcmp, strncmp
#  - io.asm: read_line, print_str
# ============================================================

.data
# prefixo do comando
str_cmd_conta_format: .asciiz "conta_format-"

# Mensagens locais (para não depender de edição em data.asm)
msg_fmt_confirm1:    .asciiz "Confirmar formatacao da conta "
dash_str:            .asciiz "-"
onechar_buf:         .space  2          # 1 char + '\0'
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
    # salva alguns regs
    addiu $sp, $sp, -48
    sw    $ra, 44($sp)
    sw    $s0, 40($sp)     # i (indice cliente)
    sw    $s1, 36($sp)     # ponteiro onde começa XXXXXX-D
    sw    $s2, 32($sp)     # linha inteira

    move  $s2, $a0         # linha

    # confere prefixo "conta_format-"
    la    $a1, str_cmd_conta_format
    li    $a3, 13          # tamanho do prefixo
    move  $a0, $s2
    jal   strncmp
    nop
    bne   $v0, $zero, hcf_notmine

    # ptr para o começo de XXXXXX-D
    addiu $s1, $s2, 13

    # --- captura 6 dígitos da conta para cc_buf_acc ---
    la    $t4, cc_buf_acc
    li    $t5, 6
hcf_copy6:
    beq   $t5, $zero, hcf_after6
    lb    $t0, 0($s1)
    li    $t1, 48          # '0'
    blt   $t0, $t1, hcf_badfmt
    li    $t1, 57          # '9'
    bgt   $t0, $t1, hcf_badfmt
    sb    $t0, 0($t4)
    addiu $t4, $t4, 1
    addiu $s1, $s1, 1
    addiu $t5, $t5, -1
    j     hcf_copy6
hcf_after6:
    sb    $zero, 0($t4)    # termina string conta

    # hífen
    lb    $t0, 0($s1)
    li    $t1, '-'
    bne   $t0, $t1, hcf_badfmt
    addiu $s1, $s1, 1

    # DV (1 dígito) -> cc_buf_dv[0]
    lb    $t0, 0($s1)
    li    $t1, 48
    blt   $t0, $t1, hcf_badfmt
    li    $t1, 57
    bgt   $t0, $t1, hcf_badfmt
    la    $t2, cc_buf_dv
    sb    $t0, 0($t2)

    # --- procura cliente por conta+dv ---
    move  $s0, $zero       # i = 0..49
    li    $t7, 50
hcf_find_loop:
    beq   $s0, $t7, hcf_notfound

    # usado?
    la    $t0, clientes_usado
    addu  $t0, $t0, $s0    # byte por cliente
    lb    $t1, 0($t0)
    beq   $t1, $zero, hcf_next_i

    # compara conta (base + i*7)
    la    $t2, clientes_conta
    sll   $t3, $s0, 3      # i*8
    subu  $t3, $t3, $s0    # i*7
    addu  $a0, $t2, $t3
    la    $a1, cc_buf_acc
    jal   strcmp
    nop
    bne   $v0, $zero, hcf_next_i

    # compara dv (byte ascii)
    la    $t4, clientes_dv
    addu  $t4, $t4, $s0
    lb    $t5, 0($t4)
    la    $t6, cc_buf_dv
    lb    $t6, 0($t6)
    bne   $t5, $t6, hcf_next_i

    # achou
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
    la    $a0, msg_cc_badfmt
    jal   print_str
    nop
    li    $v0, 1
    j     hcf_ret

# --- confirmação e limpeza ---
hcf_found:
    # "Confirmar formatacao da conta "
    la    $a0, msg_fmt_confirm1
    jal   print_str
    nop

    # imprime XXXXXX
    la    $a0, cc_buf_acc
    jal   print_str
    nop

    # "-"
    la    $a0, dash_str
    jal   print_str
    nop

    # DV (como string de 1 char)
    la    $t0, cc_buf_dv
    lb    $t1, 0($t0)
    la    $t2, onechar_buf
    sb    $t1, 0($t2)
    sb    $zero, 1($t2)
    la    $a0, onechar_buf
    jal   print_str
    nop

    # "? (s/N): "
    la    $a0, msg_fmt_confirm_q
    jal   print_str
    nop

    # lê resposta
    la    $a0, inp_buf
    li    $a1, 256
    jal   read_line
    nop

    la    $t0, inp_buf
    lb    $t1, 0($t0)
    li    $t2, 's'
    beq   $t1, $t2, hcf_do_format
    li    $t2, 'S'
    beq   $t1, $t2, hcf_do_format

    la    $a0, msg_fmt_cancel
    jal   print_str
    nop
    li    $v0, 1
    j     hcf_ret

# efetiva a limpeza
hcf_do_format:
    # zera meta débito (head/count/wptr) e crédito (word por cliente)
    sll   $t8, $s0, 2          # i*4 (palavra)

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

    # offset de bytes para os 50 valores do cliente: i*200 = (i*50)<<2
    sll   $t3, $s0, 5         # i*32
    sll   $t4, $s0, 4         # i*16
    addu  $t3, $t3, $t4       # i*48
    sll   $t4, $s0, 1         # i*2
    addu  $t3, $t3, $t4       # i*50
    sll   $t3, $t3, 2         # *4 -> bytes (i*200)

    # zera 50 words em débito
    la    $t0, trans_deb_vals
    addu  $t0, $t0, $t3
    li    $t1, 50
hcf_zero_deb:
    sw    $zero, 0($t0)
    addiu $t0, $t0, 4
    addiu $t1, $t1, -1
    bgtz  $t1, hcf_zero_deb

    # zera 50 words em crédito
    la    $t0, trans_cred_vals
    addu  $t0, $t0, $t3
    li    $t1, 50
hcf_zero_cred:
    sw    $zero, 0($t0)
    addiu $t0, $t0, 4
    addiu $t1, $t1, -1
    bgtz  $t1, hcf_zero_cred

    la    $a0, msg_fmt_conta_ok
    jal   print_str
    nop

    li    $v0, 1
    j     hcf_ret

# não era meu comando
hcf_notmine:
    move  $v0, $zero

hcf_ret:
    lw    $s2, 32($sp)
    lw    $s1, 36($sp)
    lw    $s0, 40($sp)
    lw    $ra, 44($sp)
    addiu $sp, $sp, 48
    jr    $ra
    nop
