# ============================================================
# Universidade Federal Rural de Pernambuco (UFRPE)
# Disciplina: Arquitetura e Organização de Computadores — 2025.2
# Avaliação: Projetos 1 (PE1) – 1a VA
# Professor: Vitor Coutinho
# Atividade: Lista de Exercícios – Questão 2 (TODO)
# Arquivo: ex2.asm
# Equipe: OPCODE
# Integrantes: Cauã Lira; Sérgio Ricardo; Lucas Emanuel
# Data de entrega: 13/11/2025 (horário da aula)
# Apresentação: vídeo no ato da entrega
# Descrição: Esqueleto base para a Q2 com funções utilitárias de I/O
#            e template de função + main de testes.
# Convenções:
#   - Parâmetros em $a0..$a3 | retorno em $v0
#   - Temporários: $t0..$t9 | Salvos: $s0..$s7 (salvar/restaurar se usados)
#   - PC inicia em 'main' (Settings → Initialize PC to 'main')
# ============================================================

##############################################################
#  MMIO setup + echo simples (parte 1)
##############################################################

.data                          # seção de dados
msg_start:     .asciiz "MMIO pronto. Digite no Keyboard MMIO (ENTER encerra)\n"

.text                          # seção de código
.globl main
.globl mmio_getc
.globl mmio_putc

##############################################################
# Constantes MMIO (MARS)
#  Keyboard Receiver Control  : 0xFFFF0000 (bit0=1 => tem byte)
#  Keyboard Receiver Data     : 0xFFFF0004 (leia 1 byte)
#  Display Transmitter Control: 0xFFFF0008 (bit0=1 => pode enviar)
#  Display Transmitter Data   : 0xFFFF000C (escreva 1 byte)
##############################################################
# Usaremos $k0/$k1 como temporários de MMIO (convenção “kernel”).
# Em userland real, evitaria, mas no MARS é comum para MMIO.
##############################################################

# ------------------------------------------------------------
# main: imprime mensagem (syscall) e faz eco MMIO até ENTER
# ------------------------------------------------------------
main:
    # (só para informar no console)
    li   $v0, 4                     # print_string
    la   $a0, msg_start
    syscall

eco_loop:
    jal  mmio_getc                  # v0 = caractere lido (bloqueante)
    move $t0, $v0                   # salva char

    # Se ENTER ('\n' = 10), encerra
    li   $t1, 10
    beq  $t0, $t1, fim

    # eco no display
    move $a0, $t0
    jal  mmio_putc
    j    eco_loop

fim:
    li   $v0, 10                    # exit
    syscall

# ------------------------------------------------------------
# mmio_getc -> v0=byte
# Bloqueia até haver um byte no Keyboard MMIO (bit0 do RC=1)
# ------------------------------------------------------------
mmio_getc:
    li   $k0, 0xFFFF0000            # $k0 = addr Receiver Control
mmio_getc_wait:
    lw   $k1, 0($k0)                # lê RC
    andi $k1, $k1, 1                # isReady? (bit0)
    beq  $k1, $zero, mmio_getc_wait # se 0, espera

    li   $k0, 0xFFFF0004            # addr Receiver Data
    lb   $v0, 0($k0)                # lê 1 byte -> v0
    jr   $ra

# ------------------------------------------------------------
# mmio_putc(a0=byte)
# Bloqueia até o Display MMIO estar pronto (bit0 do TC=1)
# ------------------------------------------------------------
mmio_putc:
    li   $k0, 0xFFFF0008            # $k0 = addr Transmitter Control
mmio_putc_wait:
    lw   $k1, 0($k0)                # lê TC
    andi $k1, $k1, 1                # pronto? (bit0)
    beq  $k1, $zero, mmio_putc_wait # se 0, espera

    li   $k0, 0xFFFF000C            # addr Transmitter Data
    sb   $a0, 0($k0)                # escreve 1 byte
    jr   $ra
