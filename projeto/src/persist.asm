# ============================================================
# Universidade Federal Rural de Pernambuco (UFRPE)
# Disciplina: Arquitetura e Organização de Computadores — 2025.2
# Avaliação: Projetos 1 (PE1) – 1a VA
# Professor: Vitor Coutinho
# Atividade: Lista de Exercícios – Questão 1 (string.h)
# Arquivo: persist.asm
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
# persist.asm ? R10: salvar / carregar estado bin?rio (MARS 4.5)
# Usa syscalls 13(open), 14(read), 15(write), 16(close)
# Arquivo: opcode_state.bin (diret?rio atual do MARS)
# ============================================================

.data
# --------- Config ---------
state_filename:      .asciiz "opcode_state.bin"

# header de 16 bytes: "OPCD" + versao(1) + reservado
persist_header:      .byte 'O','P','C','D', 0,0,0,1, 0,0,0,0, 0,0,0,0
hdr_buf:             .space 16

.text
.globl save_state
.globl load_state
.globl write_block
.globl read_block

# ============================================================
# write_block(a0=fd, a1=addr, a2=len) -> v0=1 ok; 0 fail
# ============================================================
write_block:
    addiu $sp, $sp, -24
    sw    $ra, 20($sp)
    sw    $s0, 16($sp)
    sw    $s1, 12($sp)
    sw    $s2,  8($sp)

    move  $s0, $a0
    move  $s1, $a1
    move  $s2, $a2

wb_loop:
    beq   $s2, $zero, wb_ok
    move  $a0, $s0
    move  $a1, $s1
    move  $a2, $s2
    li    $v0, 15          # write
    syscall
    bltz  $v0, wb_fail
    beq   $v0, $zero, wb_fail
    subu  $s2, $s2, $v0
    addu  $s1, $s1, $v0
    j     wb_loop

wb_ok:
    li    $v0, 1
    j     wb_end

wb_fail:
    move  $v0, $zero

wb_end:
    lw    $s2,  8($sp)
    lw    $s1, 12($sp)
    lw    $s0, 16($sp)
    lw    $ra, 20($sp)
    addiu $sp, $sp, 24
    jr    $ra
    nop

# ============================================================
# read_block(a0=fd, a1=addr, a2=len) -> v0=1 ok; 0 fail
# ============================================================
read_block:
    addiu $sp, $sp, -24
    sw    $ra, 20($sp)
    sw    $s0, 16($sp)
    sw    $s1, 12($sp)
    sw    $s2,  8($sp)

    move  $s0, $a0
    move  $s1, $a1
    move  $s2, $a2

rb_loop:
    beq   $s2, $zero, rb_ok
    move  $a0, $s0
    move  $a1, $s1
    move  $a2, $s2
    li    $v0, 14          # read
    syscall
    bltz  $v0, rb_fail
    beq   $v0, $zero, rb_fail
    subu  $s2, $s2, $v0
    addu  $s1, $s1, $v0
    j     rb_loop

rb_ok:
    li    $v0, 1
    j     rb_end

rb_fail:
    move  $v0, $zero

rb_end:
    lw    $s2,  8($sp)
    lw    $s1, 12($sp)
    lw    $s0, 16($sp)
    lw    $ra, 20($sp)
    addiu $sp, $sp, 24
    jr    $ra
    nop

# ============================================================
# save_state() -> v0=1 ok; 0 fail
# ============================================================
save_state:
    addiu $sp, $sp, -32
    sw    $ra, 28($sp)
    sw    $s0, 24($sp)

    # open write (cria/trunca)
    la    $a0, state_filename
    li    $a1, 1           # write
    li    $a2, 0
    li    $v0, 13          # open
    syscall
    bltz  $v0, ss_fail
    move  $s0, $v0

    # header
    move  $a0, $s0
    la    $a1, persist_header
    li    $a2, 16
    jal   write_block
    beq   $v0, $zero, ss_close_fail

    # ---------- Blocos (na mesma ordem para load) ----------
    # Clientes (bytes)
    move  $a0, $s0
    la    $a1, clientes_usado
    li    $a2, 50
    jal   write_block
    beq   $v0, $zero, ss_close_fail

    move  $a0, $s0
    la    $a1, clientes_cpf
    li    $a2, 600
    jal   write_block
    beq   $v0, $zero, ss_close_fail

    move  $a0, $s0
    la    $a1, clientes_conta
    li    $a2, 350
    jal   write_block
    beq   $v0, $zero, ss_close_fail

    move  $a0, $s0
    la    $a1, clientes_dv
    li    $a2, 50
    jal   write_block
    beq   $v0, $zero, ss_close_fail

    move  $a0, $s0
    la    $a1, clientes_nome
    li    $a2, 1650
    jal   write_block
    beq   $v0, $zero, ss_close_fail

    # Clientes (words->bytes)
    move  $a0, $s0
    la    $a1, clientes_saldo_cent
    li    $a2, 200
    jal   write_block
    beq   $v0, $zero, ss_close_fail

    move  $a0, $s0
    la    $a1, clientes_limite_cent
    li    $a2, 200
    jal   write_block
    beq   $v0, $zero, ss_close_fail

    move  $a0, $s0
    la    $a1, clientes_devido_cent
    li    $a2, 200
    jal   write_block
    beq   $v0, $zero, ss_close_fail

    # Ring DEB meta
    move  $a0, $s0
    la    $a1, trans_deb_head
    li    $a2, 200
    jal   write_block
    beq   $v0, $zero, ss_close_fail

    move  $a0, $s0
    la    $a1, trans_deb_count
    li    $a2, 200
    jal   write_block
    beq   $v0, $zero, ss_close_fail

    move  $a0, $s0
    la    $a1, trans_deb_wptr
    li    $a2, 200
    jal   write_block
    beq   $v0, $zero, ss_close_fail

    # Ring CRED meta
    move  $a0, $s0
    la    $a1, trans_cred_head
    li    $a2, 200
    jal   write_block
    beq   $v0, $zero, ss_close_fail

    move  $a0, $s0
    la    $a1, trans_cred_count
    li    $a2, 200
    jal   write_block
    beq   $v0, $zero, ss_close_fail

    move  $a0, $s0
    la    $a1, trans_cred_wptr
    li    $a2, 200
    jal   write_block
    beq   $v0, $zero, ss_close_fail

    # Valores (2500 * 4 = 10000)
    move  $a0, $s0
    la    $a1, trans_deb_vals
    li    $a2, 10000
    jal   write_block
    beq   $v0, $zero, ss_close_fail

    move  $a0, $s0
    la    $a1, trans_cred_vals
    li    $a2, 10000
    jal   write_block
    beq   $v0, $zero, ss_close_fail

    # Data/hora e cronometros
    move  $a0, $s0
    la    $a1, curr_day
    li    $a2, 24
    jal   write_block
    beq   $v0, $zero, ss_close_fail

    move  $a0, $s0
    la    $a1, ms_last
    li    $a2, 8
    jal   write_block
    beq   $v0, $zero, ss_close_fail

    move  $a0, $s0
    la    $a1, curr_abssec
    li    $a2, 4
    jal   write_block
    beq   $v0, $zero, ss_close_fail

    move  $a0, $s0
    la    $a1, juros_last_abssec
    li    $a2, 4
    jal   write_block
    beq   $v0, $zero, ss_close_fail

    move  $a0, $s0
    la    $a1, juros_gate
    li    $a2, 4
    jal   write_block
    beq   $v0, $zero, ss_close_fail

    # close
    move  $a0, $s0
    li    $v0, 16
    syscall

    li    $v0, 1
    j     ss_end

ss_close_fail:
    move  $a0, $s0
    li    $v0, 16
    syscall

ss_fail:
    move  $v0, $zero

ss_end:
    lw    $s0, 24($sp)
    lw    $ra, 28($sp)
    addiu $sp, $sp, 32
    jr    $ra
    nop

# ============================================================
# load_state() -> v0=1 ok; 0 se nao tinha arquivo / falhou
# ============================================================
load_state:
    addiu $sp, $sp, -32
    sw    $ra, 28($sp)
    sw    $s0, 24($sp)

    # open read
    la    $a0, state_filename
    li    $a1, 0
    li    $a2, 0
    li    $v0, 13
    syscall
    bltz  $v0, ls_fail
    move  $s0, $v0

    # header
    move  $a0, $s0
    la    $a1, hdr_buf
    li    $a2, 16
    jal   read_block
    beq   $v0, $zero, ls_close_fail

    # valida "OPCD"
    la    $t0, hdr_buf
    lb    $t1, 0($t0)
    li    $t2, 'O'
    bne   $t1, $t2, ls_close_fail
    lb    $t1, 1($t0)
    li    $t2, 'P'
    bne   $t1, $t2, ls_close_fail
    lb    $t1, 2($t0)
    li    $t2, 'C'
    bne   $t1, $t2, ls_close_fail
    lb    $t1, 3($t0)
    li    $t2, 'D'
    bne   $t1, $t2, ls_close_fail

    # ---------- Blocos (mesma ordem do save) ----------
    move  $a0, $s0
    la    $a1, clientes_usado
    li    $a2, 50
    jal   read_block
    beq   $v0, $zero, ls_close_fail

    move  $a0, $s0
    la    $a1, clientes_cpf
    li    $a2, 600
    jal   read_block
    beq   $v0, $zero, ls_close_fail

    move  $a0, $s0
    la    $a1, clientes_conta
    li    $a2, 350
    jal   read_block
    beq   $v0, $zero, ls_close_fail

    move  $a0, $s0
    la    $a1, clientes_dv
    li    $a2, 50
    jal   read_block
    beq   $v0, $zero, ls_close_fail

    move  $a0, $s0
    la    $a1, clientes_nome
    li    $a2, 1650
    jal   read_block
    beq   $v0, $zero, ls_close_fail

    move  $a0, $s0
    la    $a1, clientes_saldo_cent
    li    $a2, 200
    jal   read_block
    beq   $v0, $zero, ls_close_fail

    move  $a0, $s0
    la    $a1, clientes_limite_cent
    li    $a2, 200
    jal   read_block
    beq   $v0, $zero, ls_close_fail

    move  $a0, $s0
    la    $a1, clientes_devido_cent
    li    $a2, 200
    jal   read_block
    beq   $v0, $zero, ls_close_fail

    move  $a0, $s0
    la    $a1, trans_deb_head
    li    $a2, 200
    jal   read_block
    beq   $v0, $zero, ls_close_fail

    move  $a0, $s0
    la    $a1, trans_deb_count
    li    $a2, 200
    jal   read_block
    beq   $v0, $zero, ls_close_fail

    move  $a0, $s0
    la    $a1, trans_deb_wptr
    li    $a2, 200
    jal   read_block
    beq   $v0, $zero, ls_close_fail

    move  $a0, $s0
    la    $a1, trans_cred_head
    li    $a2, 200
    jal   read_block
    beq   $v0, $zero, ls_close_fail

    move  $a0, $s0
    la    $a1, trans_cred_count
    li    $a2, 200
    jal   read_block
    beq   $v0, $zero, ls_close_fail

    move  $a0, $s0
    la    $a1, trans_cred_wptr
    li    $a2, 200
    jal   read_block
    beq   $v0, $zero, ls_close_fail

    move  $a0, $s0
    la    $a1, trans_deb_vals
    li    $a2, 10000
    jal   read_block
    beq   $v0, $zero, ls_close_fail

    move  $a0, $s0
    la    $a1, trans_cred_vals
    li    $a2, 10000
    jal   read_block
    beq   $v0, $zero, ls_close_fail

    move  $a0, $s0
    la    $a1, curr_day
    li    $a2, 24
    jal   read_block
    beq   $v0, $zero, ls_close_fail

    move  $a0, $s0
    la    $a1, ms_last
    li    $a2, 8
    jal   read_block
    beq   $v0, $zero, ls_close_fail

    move  $a0, $s0
    la    $a1, curr_abssec
    li    $a2, 4
    jal   read_block
    beq   $v0, $zero, ls_close_fail

    move  $a0, $s0
    la    $a1, juros_last_abssec
    li    $a2, 4
    jal   read_block
    beq   $v0, $zero, ls_close_fail

    move  $a0, $s0
    la    $a1, juros_gate
    li    $a2, 4
    jal   read_block
    beq   $v0, $zero, ls_close_fail

    # close
    move  $a0, $s0
    li    $v0, 16
    syscall

    li    $v0, 1
    j     ls_end

ls_close_fail:
    move  $a0, $s0
    li    $v0, 16
    syscall

ls_fail:
    move  $v0, $zero

ls_end:
    lw    $s0, 24($sp)
    lw    $ra, 28($sp)
    addiu $sp, $sp, 32
    jr    $ra
    nop