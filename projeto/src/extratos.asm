# ============================================================
# Universidade Federal Rural de Pernambuco (UFRPE)
# Disciplina: Arquitetura e Organização de Computadores — 2025.2
# Avaliação: Projetos 1 (PE1) – 1a VA
# Professor: Vitor Coutinho
# Atividade: Lista de Exercícios – Questão 1 (string.h)
# Arquivo: extratos.asm
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


# ============================================================
# extratos.asm - R5 com detalhes de transa??es (MARS 4.5)
# comandos:  credito_extrato-<CONTA6>-<DV>
#            debito_extrato-<CONTA6>-<DV>
# Dep.: data.asm, transacoes.asm (formatar_centavos), ops_util.asm (print_datahora)
# ============================================================

.data
str_cmd_extrato_debito:   .asciiz 
str_cmd_extrato_credito:  .asciiz 

msg_extrato_credito_hdr:  .asciiz 
msg_extrato_debito_hdr:   .asciiz 

msg_limite_disp:          .asciiz "Limite disponivel: "
msg_divida_atual:         .asciiz "Divida atual: "
msg_nl:                   .asciiz 

lbl_sep_cols:             .asciiz
lbl_tipo_deb:             .asciiz
lbl_tipo_cred:            .asciiz
lbl_sem_mov:              .asciiz 

.text
.globl handle_extrato_credito
.globl handle_extrato_debito

# ------------------------------------------------------------
# helper: procura cliente por conta de 6 dígitos (em cc_buf_acc) + DV
# Entrada:
#   a0 = ponteiro para cc_buf_acc (6 dígitos da conta)
#   a1 = DV da conta (byte)
# Saída:
#   v0 = índice do cliente encontrado (0..49) ou -1 se não encontrado
# ------------------------------------------------------------
# Percorre a lista de clientes, compara conta e DV, retornando
# o índice correspondente ou -1 caso não exista.

extr_buscar_cliente_conta_dv:
    lw    $t9, MAX_CLIENTS
    li    $t0, 0
ebc_loop:
    beq   $t0, $t9, ebc_not_found

    la    $t1, clientes_usado
    addu  $t1, $t1, $t0
    lb    $t2, 0($t1)
    beq   $t2, $zero, ebc_next

    la    $t3, clientes_conta
    li    $t4, 7
    mul   $t4, $t0, $t4
    addu  $t3, $t3, $t4

    move  $t5, $a0                    # usa o ponteiro recebido
    li    $t6, 0
ebc_cmp6:
    lb    $t7, 0($t3)
    lb    $t8, 0($t5)
    bne   $t7, $t8, ebc_next
    addiu $t3, $t3, 1
    addiu $t5, $t5, 1
    addiu $t6, $t6, 1
    blt   $t6, 6, ebc_cmp6

    la    $t3, clientes_dv
    addu  $t3, $t3, $t0
    lb    $t7, 0($t3)
    bne   $t7, $a1, ebc_next

    move  $v0, $t0
    jr    $ra
    nop
ebc_next:
    addiu $t0, $t0, 1
    j     ebc_loop
    nop
ebc_not_found:
    li    $v0, -1
    jr    $ra
    nop

# ------------------------------------------------------------
# imprime uma linha (Data/Hora atual, Tipo, Valor)
# in: a0=tipoFlag (0=DEB, 1=CRED), a1=valor_centavos
# ------------------------------------------------------------
extr_print_linha:
    addiu $sp, $sp, -32
    sw    $ra, 28($sp)
    sw    $s0, 24($sp)
    sw    $s1, 20($sp)
    sw    $s2, 16($sp)     
    sw    $s3, 12($sp)     

    move  $s2, $a0
    move  $s3, $a1

    # Data/Hora atual (print_datahora usa curr_*)
    jal   print_datahora
    nop

    # separador
    li    $v0, 4
    la    $a0, lbl_sep_cols
    syscall

    # Tipo
    beq   $s2, $zero, epl_deb
    nop
    li    $v0, 4
    la    $a0, lbl_tipo_cred
    syscall
    j     epl_tipo_ok
    nop
epl_deb:
    li    $v0, 4
    la    $a0, lbl_tipo_deb
    syscall
epl_tipo_ok:

    # separador
    li    $v0, 4
    la    $a0, lbl_sep_cols
    syscall

    # Valor
    move  $a0, $s3
    jal   formatar_centavos
    nop
    move  $a0, $v0
    li    $v0, 4
    syscall

    # newline
    li    $v0, 4
    la    $a0, msg_nl
    syscall

    lw    $s3, 12($sp)
    lw    $s2, 16($sp)
    lw    $s1, 20($sp)
    lw    $s0, 24($sp)
    lw    $ra, 28($sp)
    addiu $sp, $sp, 32
    jr    $ra
    nop

# ------------------------------------------------------------
# extr_print_credito_do_cliente(a0 = idxCliente)  (ordem: antigo -> novo)
# ------------------------------------------------------------
extr_print_credito_do_cliente:
    addiu $sp, $sp, -40
    sw    $ra, 36($sp)
    sw    $s0, 32($sp)
    sw    $s1, 28($sp)
    sw    $s2, 24($sp)
    sw    $s3, 20($sp)
    sw    $s4, 16($sp)
    sw    $s5, 12($sp)

    move  $s0, $a0                 # idxCliente

    # carrega count e head
    sll   $t0, $s0, 2
    la    $t1, trans_cred_count
    addu  $t1, $t1, $t0
    lw    $s1, 0($t1)              # count

    la    $t2, trans_cred_head
    addu  $t2, $t2, $t0
    lw    $s2, 0($t2)              # head (proxima escrita)

    lw    $s3, TRANS_MAX           # CAP
    bltz  $s1, c_sem_mov
    sltu  $t3, $s3, $s1            
    beq   $t3, $zero, c_cnt_ok
    nop
    move  $s1, $s3
c_cnt_ok:
    # head %= CAP
    divu  $s2, $s3
    mfhi  $s2
    beq   $s1, $zero, c_sem_mov
    nop

    # start = (head - count); se <0 soma CAP
    subu  $s4, $s2, $s1
    slt   $t4, $s4, $zero
    beq   $t4, $zero, c_start_ok
    nop
    addu  $s4, $s4, $s3
c_start_ok:

    move  $s5, $zero               # i = 0
c_loop:
    beq   $s5, $s1, c_fim

    # idx = (start + i); se >= CAP subtrai CAP
    addu  $t0, $s4, $s5
    sltu  $t1, $t0, $s3
    bne   $t1, $zero, c_idx_ok
    nop
    subu  $t0, $t0, $s3
c_idx_ok:
    # linear = idxCliente*CAP + idx
    mul   $t2, $s0, $s3
    addu  $t2, $t2, $t0
    sll   $t3, $t2, 2

    la    $t4, trans_cred_vals
    addu  $t4, $t4, $t3
    lw    $t5, 0($t4)              # valor

    li    $a0, 1                   # tipo = CRED
    move  $a1, $t5
    jal   extr_print_linha

    addiu $s5, $s5, 1
    j     c_loop
    nop

c_sem_mov:
    li    $v0, 4
    la    $a0, lbl_sem_mov
    syscall

c_fim:
    lw    $s5, 12($sp)
    lw    $s4, 16($sp)
    lw    $s3, 20($sp)
    lw    $s2, 24($sp)
    lw    $s1, 28($sp)
    lw    $s0, 32($sp)
    lw    $ra, 36($sp)
    addiu $sp, $sp, 40
    jr    $ra
    nop

# ------------------------------------------------------------
# extrato_print_debito_do_cliente(a0 = idxCliente) (ordem: antigo -> novo)
# ------------------------------------------------------------
extr_print_debito_do_cliente:
    addiu $sp, $sp, -40
    sw    $ra, 36($sp)
    sw    $s0, 32($sp)
    sw    $s1, 28($sp)
    sw    $s2, 24($sp)
    sw    $s3, 20($sp)
    sw    $s4, 16($sp)
    sw    $s5, 12($sp)

    move  $s0, $a0

    sll   $t0, $s0, 2
    la    $t1, trans_deb_count
    addu  $t1, $t1, $t0
    lw    $s1, 0($t1)              # count

    la    $t2, trans_deb_head
    addu  $t2, $t2, $t0
    lw    $s2, 0($t2)              # head

    lw    $s3, TRANS_MAX
    bltz  $s1, d_sem_mov
    sltu  $t3, $s3, $s1
    beq   $t3, $zero, d_cnt_ok
    nop
    move  $s1, $s3
d_cnt_ok:
    divu  $s2, $s3
    mfhi  $s2
    beq   $s1, $zero, d_sem_mov
    nop

    subu  $s4, $s2, $s1
    slt   $t4, $s4, $zero
    beq   $t4, $zero, d_start_ok
    nop
    addu  $s4, $s4, $s3
d_start_ok:

    move  $s5, $zero               # i = 0
d_loop:
    beq   $s5, $s1, d_fim

    addu  $t0, $s4, $s5
    sltu  $t1, $t0, $s3
    bne   $t1, $zero, d_idx_ok
    nop
    subu  $t0, $t0, $s3
d_idx_ok:
    mul   $t2, $s0, $s3
    addu  $t2, $t2, $t0
    sll   $t3, $t2, 2

    la    $t4, trans_deb_vals
    addu  $t4, $t4, $t3
    lw    $t5, 0($t4)

    move  $a0, $zero               # tipo = DEB
    move  $a1, $t5
    jal   extr_print_linha

    addiu $s5, $s5, 1
    j     d_loop
    nop

d_sem_mov:
    li    $v0, 4
    la    $a0, lbl_sem_mov
    syscall

d_fim:
    lw    $s5, 12($sp)
    lw    $s4, 16($sp)
    lw    $s3, 20($sp)
    lw    $s2, 24($sp)
    lw    $s1, 28($sp)
    lw    $s0, 32($sp)
    lw    $ra, 36($sp)
    addiu $sp, $sp, 40
    jr    $ra
    nop

# ------------------------------------------------------------
# handle_extrato_credito(a0 = inp_buf)
# ------------------------------------------------------------
handle_extrato_credito:
    addiu $sp, $sp, -24
    sw    $ra, 20($sp)
    sw    $s0, 16($sp)
    sw    $s1, 12($sp)
    sw    $s2,  8($sp)

    move  $t0, $a0
    la    $t1, str_cmd_extrato_credito
hec_pref:
    lb    $t2, 0($t1)
    beq   $t2, $zero, hec_pref_ok
    lb    $t3, 0($t0)
    bne   $t2, $t3, hec_not_mine
    addiu $t1, $t1, 1
    addiu $t0, $t0, 1
    j     hec_pref
    nop

hec_pref_ok:
    la    $t4, cc_buf_acc
    li    $t5, 0
hec_conta:
    lb    $t6, 0($t0)
    blt   $t6, 48, hec_badfmt
    bgt   $t6, 57, hec_badfmt
    sb    $t6, 0($t4)
    addiu $t4, $t4, 1
    addiu $t0, $t0, 1
    addiu $t5, $t5, 1
    blt   $t5, 6, hec_conta
    sb    $zero, 0($t4)

    lb    $t6, 0($t0)
    li    $t7, 45
    bne   $t6, $t7, hec_badfmt
    addiu $t0, $t0, 1

    lb    $s1, 0($t0)

    la    $a0, cc_buf_acc
    move  $a1, $s1
    jal   extr_buscar_cliente_conta_dv
    nop
    move  $s0, $v0
    bltz  $s0, hec_cli_inexist

    li    $v0, 4
    la    $a0, msg_extrato_credito_hdr
    syscall

    sll   $t0, $s0, 2
    la    $t1, clientes_limite_cent
    addu  $t1, $t1, $t0
    lw    $t2, 0($t1)            # limite

    la    $t3, clientes_devido_cent
    addu  $t3, $t3, $t0
    lw    $t4, 0($t3)            # devido

    # saneia (nao-negativo e multiplo de 100)
    bltz  $t2, hec_lim_zero
    nop
    li    $t6, 100
    divu  $t2, $t6
    mflo  $t7
    mul   $t2, $t7, 100
    j     hec_lim_ok
    nop
hec_lim_zero:
    move  $t2, $zero
hec_lim_ok:

    bltz  $t4, hec_dev_zero
    nop
    li    $t6, 100
    divu  $t4, $t6
    mflo  $t7
    mul   $t4, $t7, 100
    j     hec_dev_ok
    nop
hec_dev_zero:
    move  $t4, $zero
hec_dev_ok:

    move  $s2, $t4                # preserva divida p/ impressao

    # disponivel = max(limite - devido, 0)
    subu  $t5, $t2, $t4
    slt   $t6, $t5, $zero
    beq   $t6, $zero, hec_disp_ok
    nop
    move  $t5, $zero
hec_disp_ok:

    # imprime limite disponivel
    li    $v0, 4
    la    $a0, msg_limite_disp
    syscall
    move  $a0, $t5
    jal   formatar_centavos
    nop
    move  $a0, $v0
    li    $v0, 4
    syscall
    li    $v0, 4
    la    $a0, msg_nl
    syscall

    # imprime divida atual
    li    $v0, 4
    la    $a0, msg_divida_atual
    syscall
    move  $a0, $s2
    jal   formatar_centavos
    nop
    move  $a0, $v0
    li    $v0, 4
    syscall
    li    $v0, 4
    la    $a0, msg_nl
    syscall

    # lista transações (todas)
    move  $a0, $s0
    jal   extr_print_credito_do_cliente
    nop

    li    $v0, 1
    j     hec_end
    nop

hec_cli_inexist:
    li    $v0, 4
    la    $a0, msg_err_cli_inexist
    syscall
    li    $v0, 1
    j     hec_end
    nop

hec_badfmt:
    li    $v0, 4
    la    $a0, msg_cc_badfmt
    syscall
    li    $v0, 1
    j     hec_end
    nop

hec_not_mine:
    move  $v0, $zero

hec_end:
    lw    $s2,  8($sp)
    lw    $s1, 12($sp)
    lw    $s0, 16($sp)
    lw    $ra, 20($sp)
    addiu $sp, $sp, 24
    jr    $ra
    nop

# ------------------------------------------------------------
# handle_extrato_debito(a0 = inp_buf)
# ------------------------------------------------------------
handle_extrato_debito:
    addiu $sp, $sp, -24
    sw    $ra, 20($sp)
    sw    $s0, 16($sp)
    sw    $s1, 12($sp)
    sw    $s2,  8($sp)

    move  $t0, $a0
    la    $t1, str_cmd_extrato_debito
hedb_pref:
    lb    $t2, 0($t1)
    beq   $t2, $zero, hedb_ok
    lb    $t3, 0($t0)
    bne   $t2, $t3, hedb_not_mine
    addiu $t1, $t1, 1
    addiu $t0, $t0, 1
    j     hedb_pref
    nop

hedb_ok:
    la    $t4, cc_buf_acc
    li    $t5, 0
hedb_conta:
    lb    $t6, 0($t0)
    blt   $t6, 48, hedb_badfmt
    bgt   $t6, 57, hedb_badfmt
    sb    $t6, 0($t4)
    addiu $t4, $t4, 1
    addiu $t0, $t0, 1
    addiu $t5, $t5, 1
    blt   $t5, 6, hedb_conta
    sb    $zero, 0($t4)

    lb    $t6, 0($t0)
    li    $t7, 45
    bne   $t6, $t7, hedb_badfmt
    addiu $t0, $t0, 1

    lb    $s1, 0($t0)

    li    $v0, 4
    la    $a0, msg_extrato_debito_hdr
    syscall

    la    $a0, cc_buf_acc
    move  $a1, $s1
    jal   extr_buscar_cliente_conta_dv
    nop
    move  $s0, $v0
    bltz  $s0, hedb_cli_inexist

    move  $a0, $s0
    jal   extr_print_debito_do_cliente
    nop

    li    $v0, 1
    j     hedb_end
    nop

hedb_cli_inexist:
    li    $v0, 4
    la    $a0, msg_err_cli_inexist
    syscall
    li    $v0, 1
    j     hedb_end
    nop

hedb_badfmt:
    li    $v0, 4
    la    $a0, msg_cc_badfmt
    syscall
    li    $v0, 1
    j     hedb_end
    nop

hedb_not_mine:
    move  $v0, $zero

hedb_end:
    lw    $s2,  8($sp)
    lw    $s1, 12($sp)
    lw    $s0, 16($sp)
    lw    $ra, 20($sp)
    addiu $sp, $sp, 24
    jr    $ra
    nop

