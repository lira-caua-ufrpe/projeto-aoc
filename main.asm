# ============================================================
# UFRPE – Projetos 1 (PE1) – 1ª VA
# Professor: Vitor
# Arquivo: main.asm
# Grupo: <nomes completos>
# Descrição: Ponto de entrada do projeto (menu).
# ============================================================

.data
menu:      .asciiz "1) Exemplo de soma\n0) Sair\nOpcao: "
nl:        .asciiz "\n"
promptA:   .asciiz "Digite A: "
promptB:   .asciiz "Digite B: "
saidaSoma: .asciiz "Soma = "

.text
.globl main

main:
    # loop do menu
menu_loop:
    li   $v0, 4         # print_string
    la   $a0, menu
    syscall

    li   $v0, 5         # read_int
    syscall
    move $t0, $v0       # $t0 = opcao

    beq  $t0, $zero, sair    # 0 -> sair
    beq  $t0, 1, opc_soma    # 1 -> soma
    j    menu_loop           # inválida -> volta

opc_soma:
    # ler A
    li   $v0, 4
    la   $a0, promptA
    syscall
    li   $v0, 5
    syscall
    move $a0, $v0            # arg0 = A

    # ler B
    li   $v0, 4
    la   $a0, promptB
    syscall
    li   $v0, 5
    syscall
    move $a1, $v0            # arg1 = B

    jal  sum_two             # chama rotina (em math.asm)

    # imprime resultado
    li   $v0, 4
    la   $a0, saidaSoma
    syscall
    move $a0, $v0            # $v0 tem o retorno de sum_two
    li   $v0, 1              # print_int
    syscall
    li   $v0, 4
    la   $a0, nl
    syscall

    j    menu_loop

sair:
    li   $v0, 10             # exit
    syscall
