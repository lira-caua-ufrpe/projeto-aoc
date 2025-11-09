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
#            + normalização MAIÚSCULAS + Tamanho/Letras/Dígitos
#            + bloqueio de múltiplos espaços consecutivos.
# Convenções:
#   - Parâmetros em $a0..$a3 ; retorno em $v0
#   - Temporários: $t0..$t9 ; $k0/$k1 usados só p/ MMIO
#   - Funções NÃO-folha salvam $ra na pilha
#   - PC inicia em 'main' (Settings → Initialize PC to 'main')
# ============================================================

.data
msg_start:     .asciiz "MMIO pronto. Abra Tools > Keyboard and Display MMIO e clique em 'Connect to MIPS'.\n"
prompt:        .asciiz "Digite uma linha (ENTER para enviar): "
echo_label:    .asciiz "Voce digitou: "
len_label:     .asciiz "\nTamanho: "
letters_label: .asciiz "\nLetras: "
digits_label:  .asciiz "  Digitos: "
nl:            .asciiz "\n"

buf_line:      .space 128            # buffer (máx 127 chars + '\0')
buf_num:       .space 16             # buffer p/ número decimal

# contadores (preenchidos por mmio_readline)
letters_count: .word 0
digits_count:  .word 0

.text
.globl main
.globl mmio_getc
.globl mmio_putc
.globl mmio_writes
.globl mmio_readline
.globl str_to_upper_inplace
.globl u32_to_dec

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
    li   $v0, 4
    la   $a0, msg_start
    syscall

    # Prompt no Display MMIO
    la   $a0, prompt
    jal  mmio_writes

    # Ler linha (até ENTER), guardar em buf_line
    la   $a0, buf_line
    li   $a1, 127
    jal  mmio_readline          # v0 = len
    move $t8, $v0               # guarda len

    # Converte in-place para MAIÚSCULAS
    la   $a0, buf_line
    jal  str_to_upper_inplace

    # \n no Display
    li   $a0, 10
    jal  mmio_putc

    # Eco da linha (agora MAIÚSCULA)
    la   $a0, echo_label
    jal  mmio_writes
    la   $a0, buf_line
    jal  mmio_writes

    # Tamanho
    la   $a0, len_label
    jal  mmio_writes
    move $a0, $t8
    la   $a1, buf_num
    jal  u32_to_dec
    move $a0, $v0
    jal  mmio_writes

    # Letras
    la   $a0, letters_label
    jal  mmio_writes
    lw   $a0, letters_count
    la   $a1, buf_num
    jal  u32_to_dec
    move $a0, $v0
    jal  mmio_writes

    # Dígitos
    la   $a0, digits_label
    jal  mmio_writes
    lw   $a0, digits_count
    la   $a1, buf_num
    jal  u32_to_dec
    move $a0, $v0
    jal  mmio_writes

    # \n final
    li   $a0, 10
    jal  mmio_putc

    # sair
    li   $v0, 10
    syscall

# ========================== mmio_getc (folha) =====================
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
mmio_writes:
    addiu $sp, $sp, -8
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
# Regras:
#  - Backspace (8) funciona (remove do buffer e do Display)
#  - Só aceita: espaço, dígitos, letras
#  - Bloqueia ESPAÇO DUPLO consecutivo
#  - Atualiza contadores (letras/dígitos) e ajusta em Backspace
#  - Grava '\0' ao final
mmio_readline:
    addiu $sp, $sp, -8
    sw    $ra, 4($sp)
    sw    $t0, 0($sp)

    move  $t0, $a0              # início do buffer
    move  $t1, $a0              # cursor
    move  $t2, $a1              # espaço restante

    move  $t8, $zero            # letters_count (em registrador)
    move  $t9, $zero            # digits_count  (em registrador)
    move  $t7, $zero            # last_is_space flag (0/1)

rl_loop:
    jal   mmio_getc
    move  $t3, $v0              # char lido

    # ENTER?
    li    $t4, 10
    beq   $t3, $t4, rl_done

    # BACKSPACE?
    li    $t4, 8
    bne   $t3, $t4, rl_store

    # se backspace e há algo no buffer, ajustar contadores e apagar
    beq   $t1, $t0, rl_loop     # buffer vazio -> ignora
    lb    $t4, -1($t1)          # último char no buffer (antes de apagar)

    # decrementar contadores conforme o char removido
    # dígito?
    li    $t5, 48               # '0'
    blt   $t4, $t5, chk_letter_rm
    li    $t5, 57               # '9'
    ble   $t4, $t5, dec_digit

chk_letter_rm:
    # 'A'..'Z' ?
    li    $t5, 65               # 'A'
    blt   $t4, $t5, chk_lower_rm
    li    $t5, 90               # 'Z'
    ble   $t4, $t5, dec_letter

chk_lower_rm:
    # 'a'..'z' ?
    li    $t5, 97               # 'a'
    blt   $t4, $t5, do_backspace   # não é letra/dígito
    li    $t5, 122              # 'z'
    bgt   $t4, $t5, do_backspace
dec_letter:
    addi  $t8, $t8, -1          # letters--
    j     do_backspace
dec_digit:
    addi  $t9, $t9, -1          # digits--

do_backspace:
    addi  $t1, $t1, -1          # volta 1 no buffer
    addi  $t2, $t2, 1           # recupera espaço

    # recalcula last_is_space com base no novo último char
    beq   $t1, $t0, clear_space_flag
    lb    $t6, -1($t1)
    li    $t5, 32               # ' '
    beq   $t6, $t5, set_space_flag
    move  $t7, $zero            # last_is_space = 0
    j     erase_display
set_space_flag:
    li    $t7, 1
    j     erase_display
clear_space_flag:
    move  $t7, $zero

erase_display:
    # apaga visual: '\b', ' ', '\b'
    li    $a0, 8
    jal   mmio_putc
    li    $a0, 32
    jal   mmio_putc
    li    $a0, 8
    jal   mmio_putc
    j     rl_loop

# armazena char normal (se houver espaço) — validação + sem espaço duplo
rl_store:
    beq   $t2, $zero, rl_loop      # sem espaço -> ignora

    move  $t5, $t3                 # t5 = char

    # espaço?
    li    $t6, 32                  # ' '
    beq   $t5, $t6, chk_double_space

    # '0'..'9' ?
    li    $t6, 48                  # '0'
    blt   $t5, $t6, rl_ignore
    li    $t6, 57                  # '9'
    ble   $t5, $t6, accept_digit

    # 'A'..'Z' ?
    li    $t6, 65                  # 'A'
    blt   $t5, $t6, chk_lower
    li    $t6, 90                  # 'Z'
    ble   $t5, $t6, accept_letter

chk_lower:
    # 'a'..'z' ?
    li    $t6, 97                  # 'a'
    blt   $t5, $t6, rl_ignore
    li    $t6, 122                 # 'z'
    bgt   $t5, $t6, rl_ignore
    # é letra minúscula
    j     accept_letter

chk_double_space:
    # bloquear espaço duplo: se last_is_space=1, ignore
    bne   $t7, $zero, rl_ignore
    # aceitar o espaço
    li    $t7, 1                   # marca último como espaço
    j     store_char_no_count

accept_digit:
    addi  $t9, $t9, 1              # digits++
    move  $t7, $zero               # último não é espaço
    j     store_char

accept_letter:
    addi  $t8, $t8, 1              # letters++
    move  $t7, $zero               # último não é espaço
    j     store_char

store_char_no_count:
    # grava espaço (não altera contadores)
    sb    $t3, 0($t1)
    addi  $t1, $t1, 1
    addi  $t2, $t2, -1
    move  $a0, $t3
    jal   mmio_putc
    j     rl_loop

store_char:
    # grava letra/dígito
    sb    $t3, 0($t1)
    addi  $t1, $t1, 1
    addi  $t2, $t2, -1
    move  $a0, $t3
    jal   mmio_putc
    j     rl_loop

# ignorar caractere inválido
rl_ignore:
    # opcional: 'bipe' com BEL (7)
    # li   $a0, 7
    # jal  mmio_putc
    j     rl_loop

# finaliza string e retorna len
rl_done:
    sb    $zero, 0($t1)           # terminador
    subu  $v0, $t1, $t0           # len
    sw    $t8, letters_count
    sw    $t9, digits_count
    lw    $t0, 0($sp)
    lw    $ra, 4($sp)
    addiu $sp, $sp, 8
    jr    $ra

# ===================== str_to_upper_inplace (folha) ===============
str_to_upper_inplace:
    move $t0, $a0
up_loop:
    lb   $t1, 0($t0)
    beq  $t1, $zero, up_end
    li   $t2, 97                  # 'a'
    li   $t3, 122                 # 'z'
    blt  $t1, $t2, up_store
    bgt  $t1, $t3, up_store
    addi $t1, $t1, -32
up_store:
    sb   $t1, 0($t0)
    addi $t0, $t0, 1
    j    up_loop
up_end:
    jr   $ra

# ========================== u32_to_dec (folha) ====================
# a0 = valor >= 0 ; a1 = destino (char*)
# v0 = a1 (addr do destino)
u32_to_dec:
    move $t0, $a0
    move $t1, $a1
    beq  $t0, $zero, u32_zero

    li   $t2, 10
    move $t3, $zero

u32_div_loop:
    divu $t0, $t2
    mfhi $t4
    mflo $t0
    addi $t4, $t4, 48
    sb   $t4, 0($t1)
    addi $t1, $t1, 1
    addi $t3, $t3, 1
    bne  $t0, $zero, u32_div_loop

    addi $t1, $t1, -1             # t1 = dest+(n-1)
    move $t5, $a1                 # i
    addi $t6, $t1, 0              # j

u32_rev_loop:
    subu $t7, $t6, $t5
    blez $t7, u32_rev_done
    lb   $t8, 0($t5)
    lb   $t9, 0($t6)
    sb   $t9, 0($t5)
    sb   $t8, 0($t6)
    addi $t5, $t5, 1
    addi $t6, $t6, -1
    j    u32_rev_loop

u32_rev_done:
    addu $t7, $a1, $t3
    sb   $zero, 0($t7)
    move $v0, $a1
    jr   $ra

u32_zero:
    sb   $zero, 1($t1)
    li   $t4, 48
    sb   $t4, 0($t1)
    move $v0, $a1
    jr   $ra
