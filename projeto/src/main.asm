# main.asm — laço do shell (banner, help, exit + conta_cadastrar)

.text
.globl main          # este arquivo define 'main' (ok exportar)

# (não declare .globl para funções/imports vindos de outros .asm no MARS)

# rótulos de dados e funções usados aqui existem em outros arquivos:
# - print_str, read_line, strip_line_end   (io.asm)
# - strcmp                                 (strings.asm)
# - handle_conta_cadastrar                 (ops_conta.asm)
# - banner, inp_buf, help_txt, msg_invalid, msg_bye, str_help, str_exit (data.asm)

main:
main_loop:
    # imprime banner
    la   $a0, banner
    jal  print_str

    # lê linha para inp_buf (até 255)
    la   $a0, inp_buf
    li   $a1, 255
    jal  read_line

    # strip final (remove \n, \r, espaços/tabs à direita)
    la   $a0, inp_buf
    jal  strip_line_end
    # len retornou em v0 (se precisar)

    # tenta tratar conta_cadastrar-...
    la   $a0, inp_buf
    jal  handle_conta_cadastrar
    bne  $v0, $zero, main_loop     # se tratou (ou deu msg), volta pro banner

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
