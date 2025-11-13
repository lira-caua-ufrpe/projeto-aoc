# ============================================================
# persist.asm — salvar e carregar estado binário (MARS 4.5)
# Usa syscalls: 13=open, 14=read, 15=write, 16=close
# Arquivo de persistência: "opcode_state.bin" (diretório atual do MARS)
# R10 do projeto é usado para esta funcionalidade
# ============================================================

.data
# --------- Configuração ---------
state_filename:      .asciiz "opcode_state.bin"  # Nome do arquivo de persistência

# Header de 16 bytes: "OPCD" + versão(1) + reservado
persist_header:      .byte 'O','P','C','D', 0,0,0,1, 0,0,0,0, 0,0,0,0
hdr_buf:             .space 16                  # Buffer temporário para o header

.text
.globl save_state
.globl load_state
.globl write_block
.globl read_block

# ============================================================
# write_block(a0=fd, a1=addr, a2=len) -> v0=1 se ok, 0 se fail
# Escreve len bytes do endereço addr no arquivo fd
# ============================================================
write_block:
    # --- prólogo: salva registradores ---
    addiu $sp, $sp, -24
    sw    $ra, 20($sp)
    sw    $s0, 16($sp)
    sw    $s1, 12($sp)
    sw    $s2,  8($sp)

    move  $s0, $a0    # fd
    move  $s1, $a1    # addr
    move  $s2, $a2    # len

wb_loop:
    beq   $s2, $zero, wb_ok       # tudo escrito, sucesso
    move  $a0, $s0
    move  $a1, $s1
    move  $a2, $s2
    li    $v0, 15                  # syscall write
    syscall
    bltz  $v0, wb_fail             # erro na escrita
    beq   $v0, $zero, wb_fail      # nenhum byte escrito -> fail
    subu  $s2, $s2, $v0            # decrementa bytes restantes
    addu  $s1, $s1, $v0            # avança ponteiro do buffer
    j     wb_loop

wb_ok:
    li    $v0, 1
    j     wb_end

wb_fail:
    move  $v0, $zero               # retorna 0 em caso de falha

wb_end:
    # --- epílogo: restaura registradores ---
    lw    $s2,  8($sp)
    lw    $s1, 12($sp)
    lw    $s0, 16($sp)
    lw    $ra, 20($sp)
    addiu $sp, $sp, 24
    jr    $ra
    nop

# ============================================================
# read_block(a0=fd, a1=addr, a2=len) -> v0=1 se ok, 0 se fail
# Lê len bytes do arquivo fd para o endereço addr
# ============================================================
read_block:
    addiu $sp, $sp, -24
    sw    $ra, 20($sp)
    sw    $s0, 16($sp)
    sw    $s1, 12($sp)
    sw    $s2,  8($sp)

    move  $s0, $a0    # fd
    move  $s1, $a1    # addr
    move  $s2, $a2    # len

rb_loop:
    beq   $s2, $zero, rb_ok       # tudo lido, sucesso
    move  $a0, $s0
    move  $a1, $s1
    move  $a2, $s2
    li    $v0, 14                  # syscall read
    syscall
    bltz  $v0, rb_fail             # erro na leitura
    beq   $v0, $zero, rb_fail      # EOF inesperado -> fail
    subu  $s2, $s2, $v0            # decrementa bytes restantes
    addu  $s1, $s1, $v0            # avança ponteiro do buffer
    j     rb_loop

rb_ok:
    li    $v0, 1
    j     rb_end

rb_fail:
    move  $v0, $zero               # retorna 0 em caso de falha

rb_end:
    lw    $s2,  8($sp)
    lw    $s1, 12($sp)
    lw    $s0, 16($sp)
    lw    $ra, 20($sp)
    addiu $sp, $sp, 24
    jr    $ra
    nop

# ============================================================
# save_state() -> v0=1 se ok, 0 se fail
# Salva todo o estado do sistema no arquivo opcode_state.bin
# ============================================================
save_state:
    addiu $sp, $sp, -32
    sw    $ra, 28($sp)
    sw    $s0, 24($sp)

    # --- abre o arquivo (write, cria ou trunca) ---
    la    $a0, state_filename
    li    $a1, 1           # write
    li    $a2, 0
    li    $v0, 13          # syscall open
    syscall
    bltz  $v0, ss_fail
    move  $s0, $v0         # $s0 = fd

    # --- escreve header ---
    move  $a0, $s0
    la    $a1, persist_header
    li    $a2, 16
    jal   write_block
    beq   $v0, $zero, ss_close_fail

    # --- escreve blocos de clientes e transações ---
    # ordem deve ser a mesma para load_state
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

    # Clientes (palavras -> 4 bytes cada)
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

    # Valores (2500 * 4 bytes = 10000)
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

    # Data/hora e cronômetros
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

    # --- fecha arquivo ---
    move  $a0, $s0
    li    $v0, 16
    syscall

    li    $v0, 1
    j     ss_end

ss_close_fail:
    # fecha mesmo em caso de erro
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
# load_state() -> v0=1 se ok, 0 se arquivo não existe ou falhou
# ============================================================
load_state:
    # --- prólogo: salvar registradores ---
    addiu $sp, $sp, -32
    sw    $ra, 28($sp)
    sw    $s0, 24($sp)

    # --- abre arquivo para leitura ---
    la    $a0, state_filename
    li    $a1, 0           # modo read
    li    $a2, 0
    li    $v0, 13          # syscall open
    syscall
    bltz  $v0, ls_fail     # se não abriu, retorna 0
    move  $s0, $v0         # $s0 = fd

    # --- lê header ---
    move  $a0, $s0
    la    $a1, hdr_buf
    li    $a2, 16
    jal   read_block
    beq   $v0, $zero, ls_close_fail

    # --- valida primeiro 4 bytes: "OPCD" ---
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

    # ---------- Blocos de dados (mesma ordem do save_state) ----------
    # Clientes (bytes)
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

    # Clientes (palavras/inteiros)
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

    # Ring DEB meta
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

    # Ring CRED meta
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

    # Valores (2500 * 4 = 10000 bytes)
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

    # Data/hora e cronômetros
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

    # --- fecha arquivo ---
    move  $a0, $s0
    li    $v0, 16
    syscall

    li    $v0, 1               # sucesso
    j     ls_end

ls_close_fail:
    # fecha mesmo em caso de erro
    move  $a0, $s0
    li    $v0, 16
    syscall

ls_fail:
    move  $v0, $zero           # retorna 0

ls_end:
    # --- epílogo ---
    lw    $s0, 24($sp)
    lw    $ra, 28($sp)
    addiu $sp, $sp, 32
    jr    $ra
    nop
