# ============================================================
# UFRPE – Projetos 1 (PE1) – 1ª VA
# Professor: Vitor
# Atividade: Lista – Questão 2 (MMIO Echo com polling)
# Arquivo: ex2.asm
# Grupo: <nomes completos>
# Descrição:
#   Lê caracteres do Keyboard MMIO e imprime imediatamente no
#   Display MMIO usando memória mapeada (polling, sem interrupções).
#   Pressione ESC (27) para encerrar.
# Referência: Apêndice A.8 (Hennessy & Patterson)
# Endereços MMIO (MARS):
#   0xFFFF0000  Keyboard control   (bit0 = 1 -> caractere disponível)
#   0xFFFF0004  Keyboard data      (byte baixo = ASCII)
#   0xFFFF0008  Display control    (bit0 = 1 -> pronto p/ transmitir)
#   0xFFFF000C  Display data       (escrever ASCII no byte baixo)
# ============================================================

.data
msg_start: .asciiz "MMIO Echo iniciado (ESC para sair)\n"

.text
.globl main

# Constantes (endereços/máscaras)
# Usamos 'li' para carregar endereços imediatos de 32 bits.
main:
    # Mensagem inicial (via syscall só uma vez, ok para instrução)
    li   $v0, 4
    la   $a0, msg_start
    syscall

    li   $t7, 0x00000001       # MASK bit0 (READY)
    li   $t6, 0x0000001B       # ASCII ESC (27) -> sair

    # Endereços MMIO
    li   $t0, 0xFFFF0000       # KBD_CTRL
    li   $t1, 0xFFFF0004       # KBD_DATA
    li   $t2, 0xFFFF0008       # DSP_CTRL
    li   $t3, 0xFFFF000C       # DSP_DATA

echo_loop:
    # -------- Espera caractere do teclado (polling) --------
kbd_poll:
    lw   $t4, 0($t0)           # lê Keyboard Control
    and  $t4, $t4, $t7         # isola bit0 (ready?)
    beq  $t4, $zero, kbd_poll  # 0 -> ainda não chegou, continua

    # Leu: pegar dado do teclado
    lw   $t5, 0($t1)           # word, ASCII no byte menos significativo
    andi $t5, $t5, 0x00FF      # zera bytes altos -> só o ASCII

    # Sair se ESC
    beq  $t5, $t6, sair

    # -------- Espera display pronto (polling) --------------
dsp_poll:
    lw   $t4, 0($t2)           # lê Display Control
    and  $t4, $t4, $t7         # bit0 pronto?
    beq  $t4, $zero, dsp_poll  # não pronto -> espera

    # Envia caractere para o display
    sw   $t5, 0($t3)           # escreve ASCII (byte baixo considerado)

    j    echo_loop             # volta para próximo caractere

sair:
    li   $v0, 10               # exit
    syscall
