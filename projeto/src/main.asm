# main.asm — laço do shell (R1/R2/R3/R4)
.include "data.asm"
.include "io.asm"
.include "strings.asm"
.include "ops_conta.asm"
.include "ops_fin.asm"
.include "time.asm"

.text
.globl main

main:
main_loop:
    # 1) imprime prompt
    la   $a0, banner
    jal  print_str

    # 2) lê linha (bloqueia aqui enquanto o usuário digita)
    la   $a0, inp_buf
    li   $a1, 255
    jal  read_line

    # 2.1) R4 — agora sim, contabiliza todo o tempo que passou enquanto digitava
    jal  tick_datetime

    # 3) strip
    la   $a0, inp_buf
    jal  strip_line_end
    beq  $v0, $zero, main_loop

    # 4) comandos R1/R2/R3/R4 ...
    la $a0, inp_buf
    jal handle_conta_cadastrar
    bne $v0, $zero, main_loop

    la $a0, inp_buf
    jal handle_pagar_debito
    bne $v0, $zero, main_loop

    la $a0, inp_buf
    jal handle_pagar_credito
    bne $v0, $zero, main_loop

    la $a0, inp_buf
    jal handle_alterar_limite
    bne $v0, $zero, main_loop

    la $a0, inp_buf
    jal handle_dump_trans_debito
    bne $v0, $zero, main_loop

    la $a0, inp_buf
    jal handle_dump_trans_credito
    bne $v0, $zero, main_loop

    la $a0, inp_buf
    jal handle_datetime_set
    bne $v0, $zero, main_loop

    la $a0, inp_buf
    jal handle_datetime_show   # ele mesmo chama tick_datetime antes de imprimir
    bne $v0, $zero, main_loop

    # help / exit ...
    la $a0, inp_buf
    la $a1, str_help
    jal strcmp
    beq $v0, $zero, do_help

    la $a0, inp_buf
    la $a1, str_exit
    jal strcmp
    beq $v0, $zero, do_exit

    la $a0, msg_invalid
    jal print_str
    j  main_loop

do_help:
    la  $a0, help_txt
    jal print_str
    j   main_loop

do_exit:
    la  $a0, msg_bye
    jal print_str
    li  $v0, 10
    syscall
