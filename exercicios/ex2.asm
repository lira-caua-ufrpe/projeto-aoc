# ============================================================
# Universidade Federal Rural de Pernambuco (UFRPE)
# Disciplina: Arquitetura e Organização de Computadores — 2025.2
# Avaliação: Projetos 1 (PE1) – 1a VA
# Professor: Vitor Coutinho
# Atividade: Lista de Exercícios – Questão 2 (MMIO)
# Arquivo: ex2.asm
# Equipe: OPCODE
# Integrantes: Cauã Lira; Sérgio Ricardo; Lucas Emanuel
# Data de entrega: 13/11/2025 (horário da aula)
# Apresentação: vídeo no ato da entrega
# Descrição: Echo via MMIO + leitura de linha (Backspace/ENTER)
#            + normalização para MAIÚSCULAS antes do eco.
# Convenções:
#   - Parâmetros em $a0..$a3 ; retorno em $v0
#   - Temporários: $t0..$t9 ; $k0/$k1 usados só p/ MMIO
#   - Funções NÃO-folha salvam $ra na pilha
#   - PC inicia em 'main' (Settings → Initialize PC to 'main')
# ============================================================

.data
msg_start:    .asciiz "MMIO pronto. Abra Tools > Keyboard and Display MMIO e clique em 'Connect to MIPS'.\n"
prompt:       .asciiz "Digite uma linha (ENTER para enviar): "
echo_label:   .asciiz "Voce digitou: "
nl:           .asciiz "\n"
buf_line:     .space 128        # buffer (máx 127 chars + '\0')

.text
.globl main
.globl mmio_getc
.globl mmio_putc
.globl mmio_writes
.globl mmio_readline
.globl str_to_upper_inplace

# ------------------------------------------------------------
# Constantes MMIO (MARS)
# Keyboard RC : 0xFFFF0000 (bit0=1 => há byte)
# Keyboard RD : 0xFFFF0004 (ler 1 byte)
# Display  TC : 0xFFFF0008 (bit0=1 => pronto)
# Display  TD : 0xFFFF000C (escrever 1 byte)
# ------------------------------------------------------------

# ============================== main ==============================
main:
    # Dica no console
    li   $v0, 4                 # print_string
    la   $a0, msg_start
    syscall

    # Prompt no Display MMIO
    la   $a0, prompt
    jal  mmio_writes

    # Ler linha (até ENTER), guardar em buf_line
    la   $a0, buf_line          # &buf
    li   $a1, 127               # maxlen (sem contar '\0')
    jal  mmio_readline          # v0 = len

    # Converte in-place para MAIÚSCULAS
    la   $a0, buf_line
    jal  str_to_upper_inplace

    # \n no Display
    li   $a0, 10                # '\n'
    jal  mmio_putc

    # Eco da linha (agora MAIÚSCULA)
    la   $a0, echo_label
    jal  mmio_writes
    la   $a0, buf_line
    jal  mmio_writes

    # sair
    li   $v0, 10                # exit
    syscall

# ========================== mmio_getc (folha) =====================
# v0=byte (bloqueante)
mmio_getc:
    li   $k0, 0xFFFF0000        # RC
mmio_getc_wait:
    lw   $k1, 0($k0)
    andi $k1, $k1, 1
    beq  $k1, $zero, mmio_getc_wait
    li   $k0, 0xFFFF0004        # RD
    lb   $v0, 0($k0)
    jr   $ra

# ========================== mmio_putc (folha) =====================
# a0=byte
mmio_putc:
    li   $k0, 0xFFFF0008        # TC
mmio_putc_wait:
    lw   $k1, 0($k0)
    andi $k1, $k1, 1
    beq  $k1, $zero, mmio_putc_wait
    li   $k0, 0xFFFF000C        # TD
    sb   $a0, 0($k0)
    jr   $ra

# ========================= mmio_writes (não-folha) ================
# a0=addr da string '\0'-terminada (imprime no Display MMIO)
mmio_writes:
    addiu $sp, $sp, -8          # salva $ra e $t0
    sw    $ra, 4($sp)
    sw    $t0, 0($sp)

    move  $t0, $a0
ws_loop:
    lb    $t1, 0($t0)
    beq   $t1, $zero, ws_end
    move  $a0, $t1
    jal   mmio_putc
    addi  $t0, $t0, 1
    j     ws_loop
ws_end:
    lw    $t0, 0($sp)
    lw    $ra, 4($sp)
    addiu $sp, $sp, 8
    jr    $ra

# ======================== mmio_readline (não-folha) ===============
# a0=buf, a1=maxlen  -> v0=len (sem contar '\n')
# Trata Backspace (8) e finaliza em '\n' (10), gravando '\0'.
mmio_readline:
    addiu $sp, $sp, -8          # salva $ra e $t0
    sw    $ra, 4($sp)
    sw    $t0, 0($sp)

    move  $t0, $a0               # início do buffer
    move  $t1, $a0               # cursor
    move  $t2, $a1               # espaço restante

rl_loop:
    jal   mmio_getc              # v0 = char
    move  $t3, $v0

    # ENTER?
    li    $t4, 10
    beq   $t3, $t4, rl_done

    # BACKSPACE?
    li    $t4, 8
    bne   $t3, $t4, rl_store

    # se backspace e há algo no buffer, apaga
    bne   $t1, $t0, rl_do_back
    j     rl_loop                # buffer vazio: ignora backspace

rl_do_back:
    addi  $t1, $t1, -1           # volta 1
    addi  $t2, $t2, 1            # recupera espaço
    # apaga no display: '\b', ' ', '\b'
    li    $a0, 8                 # '\b'
    jal   mmio_putc
    li    $a0, 32                # ' '
    jal   mmio_putc
    li    $a0, 8                 # '\b'
    jal   mmio_putc
    j     rl_loop

# armazena char normal (se houver espaço) — AGORA com validação
rl_store:
    beq   $t2, $zero, rl_loop    # sem espaço -> ignora char

    # -------- validação: permite [espaco, 0-9, A-Z, a-z] --------
    move  $t5, $t3               # t5 = char

    # espaço?
    li    $t6, 32                # ' '
    beq   $t5, $t6, rl_ok

    # '0'..'9' ?
    li    $t6, 48                # '0'
    blt   $t5, $t6, rl_ignore
    li    $t6, 57                # '9'
    ble   $t5, $t6, rl_ok

    # 'A'..'Z' ?
    li    $t6, 65                # 'A'
    blt   $t5, $t6, rl_check_lower
    li    $t6, 90                # 'Z'
    ble   $t5, $t6, rl_ok

rl_check_lower:
    # 'a'..'z' ?
    li    $t6, 97                # 'a'
    blt   $t5, $t6, rl_ignore
    li    $t6, 122               # 'z'
    bgt   $t5, $t6, rl_ignore

    # passou na validação -> ok
rl_ok:
    sb    $t3, 0($t1)            # grava no buffer
    addi  $t1, $t1, 1            # avança cursor
    addi  $t2, $t2, -1           # consome espaço
    move  $a0, $t3               # eco visual
    jal   mmio_putc
    j     rl_loop

    # não passou -> ignora char
rl_ignore:
    j     rl_loop


# finaliza string e retorna len
rl_done:
    sb    $zero, 0($t1)          # terminador
    subu  $v0, $t1, $t0          # len
    lw    $t0, 0($sp)
    lw    $ra, 4($sp)
    addiu $sp, $sp, 8
    jr    $ra

# ===================== str_to_upper_inplace (folha) ===============
# a0=buf -> converte 'a'..'z' -> 'A'..'Z' até '\0'
str_to_upper_inplace:
    move $t0, $a0                 # t0 = ptr
up_loop:
    lb   $t1, 0($t0)              # lê char
    beq  $t1, $zero, up_end       # fim?
    li   $t2, 97                  # 'a'
    li   $t3, 122                 # 'z'
    blt  $t1, $t2, up_store       # < 'a' => mantém
    bgt  $t1, $t3, up_store       # > 'z' => mantém
    addi $t1, $t1, -32            # 'a'..'z' -> 'A'..'Z'
up_store:
    sb   $t1, 0($t0)              # grava
    addi $t0, $t0, 1              # avança
    j    up_loop
up_end:
    jr   $ra
