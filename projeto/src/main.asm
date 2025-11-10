# main.asm — laço do shell (banner, help, exit)

.text
.globl main

main:
main_loop:
    # imprime banner
    la   $a0, banner
    jal  print_str

    # lê linha para inp_buf (até 255)
    la   $a0, inp_buf
    li   $a1, 255
    jal  read_line
    # len está em v0 (se precisar depois)

    # --- dispatch básico ---
    # if (strcmp(inp_buf, "help")==0) -> print help
    la   $a0, inp_buf
    la   $a1, str_help
    jal  strcmp
    beq  $v0, $zero, do_help

    # if (strcmp(inp_buf, "exit")==0) -> sair
    la   $a0, inp_buf
    la   $a1, str_exit
    jal  strcmp
    beq  $v0, $zero, do_exit

    # futuro: checar prefixo "conta_cadastrar-"
    la   $a0, inp_buf
    la   $a1, prefix_conta
    li   $a2, 17                 # tamanho de "conta_cadastrar-"
    jal  strncmp
    beq  $v0, $zero, not_implemented

    # caso default
    la   $a0, msg_invalid
    jal  print_str
    j    main_loop

do_help:
    la   $a0, help_txt
    jal  print_str
    j    main_loop

not_implemented:
    la   $a0, msg_stub
    jal  print_str
    j    main_loop

do_exit:
    la   $a0, msg_bye
    jal  print_str
    li   $v0, 10
    syscall

# --- strings internas do main ---
.data
str_help:       .asciiz "help"
str_exit:       .asciiz "exit"
prefix_conta:   .asciiz "conta_cadastrar-"
msg_stub:       .asciiz "Comando reconhecido, implementacao em andamento...\n"
