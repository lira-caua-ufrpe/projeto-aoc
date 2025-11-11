# main.asm — laço do shell (banner, help, exit, conta_cadastrar + R2)
# Monte só este arquivo. Os demais são incluídos aqui:
.include "data.asm"
.include "io.asm"
.include "strings.asm"
.include "ops_conta.asm"
.include "ops_fin.asm"

.text
.globl main

main:
main_loop:
    # 1) imprime prompt
    la   $a0, banner
    jal  print_str

    # 2) PREVINE reprocessamento: zera o 1º byte do buffer
    la   $a0, inp_buf
    sb   $zero, 0($a0)

    # 3) lê linha em inp_buf (até 255 chars)
    #    (se nada for digitado, o buffer continua vazio por causa do sb acima)
    la   $a0, inp_buf
    li   $a1, 255
    jal  read_line

    # 4) strip final (\n, \r, espaços/tabs à direita)
    la   $a0, inp_buf
    jal  strip_line_end        # v0 = len
    beq  $v0, $zero, main_loop # linha vazia -> volta pro prompt

    # 5) comandos R1/R2
    # conta_cadastrar-CPF-CONTA6-NOME
    la   $a0, inp_buf
    jal  handle_conta_cadastrar
    bne  $v0, $zero, main_loop

    # pagar_debito-CONTA6-DV-VALORcentavos
    la   $a0, inp_buf
    jal  handle_pagar_debito
    bne  $v0, $zero, main_loop

    # pagar_credito-CONTA6-DV-VALORcentavos
    la   $a0, inp_buf
    jal  handle_pagar_credito
    bne  $v0, $zero, main_loop

    # alterar_limite-CONTA6-DV-NOVOLIMcentavos
    la   $a0, inp_buf
    jal  handle_alterar_limite
    bne  $v0, $zero, main_loop

    # 6) comandos fixos (help/exit)
    la   $a0, inp_buf
    la   $a1, str_help
    jal  strcmp
    beq  $v0, $zero, do_help

    la   $a0, inp_buf
    la   $a1, str_exit
    jal  strcmp
    beq  $v0, $zero, do_exit

    # 7) default -> inválido
    la   $a0, msg_invalid
    jal  print_str
    j    main_loop

# ----------------------------------------------------
# handlers auxiliares
# ----------------------------------------------------
do_help:
    la   $a0, help_txt
    jal  print_str
    j    main_loop

do_exit:
    la   $a0, msg_bye
    jal  print_str
    li   $v0, 10     # syscall exit
    syscall
