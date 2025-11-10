# main.asm — laço do shell (banner, help, exit + conta_cadastrar)

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
    # len está em v0 (se precisar)

    # tenta tratar conta_cadastrar-...
    la   $a0, inp_buf
    jal  handle_conta_cadastrar
    bne  $v0, $zero, main_loop     # se tratou, volta pro banner

    # if (strcmp(inp_buf, "help")==0)
    la   $a0, inp_buf
    la   $a1, str_help
    jal  strcmp
    beq  $v0, $zero, do_help

    # if (strcmp(inp_buf, "exit")==0)
    la   $a0, inp_buf
    la   $a1, str_exit
    jal  strcmp
    beq  $v0, $zero, do_exit

    # default: comando inválido
    la   $a0, msg_invalid
    jal  print_str
    j    main_loop

do_help:
    la   $a0, help_txt
    jal  print_str
    j    main_loop

do_exit:
    la   $a0, msg_bye
    jal  print_str
    li   $v0, 10     # exit
    syscall
