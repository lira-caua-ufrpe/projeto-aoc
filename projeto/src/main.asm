# main.asm – laço do shell

    .include "data.asm"
    .include "io.asm"
    .include "strings.asm"
    .include "ops_conta.asm"
    .include "ops_fin.asm"
    .include "time.asm"
    .include "transacoes.asm"
    .include "extratos.asm"

.text
.globl main

main:
main_loop:
    # 1) imprime prompt
    la   $a0, banner
    jal  print_str

    # 2) lê linha do usuário
    la   $a0, inp_buf
    li   $a1, 255
    jal  read_line

    # 2.1) atualiza relógio depois da digitação
    jal  tick_datetime

    # 3) strip \n
    la   $a0, inp_buf
    jal  strip_line_end
    beq  $v0, $zero, main_loop   # linha vazia -> volta

    # === R1: conta_cadastrar ===
    la   $a0, inp_buf
    jal  handle_conta_cadastrar
    bne  $v0, $zero, main_loop

    # === R2: pagar_debito ===
    la   $a0, inp_buf
    jal  handle_pagar_debito
    bne  $v0, $zero, main_loop

    # === R2: pagar_credito ===
    la   $a0, inp_buf
    jal  handle_pagar_credito
    bne  $v0, $zero, main_loop

    # === R2: alterar_limite ===
    la   $a0, inp_buf
    jal  handle_alterar_limite
    bne  $v0, $zero, main_loop

    # === R3: dumps de transações (debug) ===
    la   $a0, inp_buf
    jal  handle_dump_trans_debito
    bne  $v0, $zero, main_loop

    la   $a0, inp_buf
    jal  handle_dump_trans_credito
    bne  $v0, $zero, main_loop

    # === R4: datetime_set ===
    la   $a0, inp_buf
    jal  handle_datetime_set
    bne  $v0, $zero, main_loop

    # === R4: datetime_show ===
    la   $a0, inp_buf
    jal  handle_datetime_show
    bne  $v0, $zero, main_loop

    # === Req 5: extratos ===
    la   $a0, inp_buf
    jal  handle_extrato_debito
    bne  $v0, $zero, main_loop

    la   $a0, inp_buf
    jal  handle_extrato_credito
    bne  $v0, $zero, main_loop

    # === help ===
    la   $a0, inp_buf
    la   $a1, str_help
    jal  strcmp
    beq  $v0, $zero, do_help

    # === exit ===
    la   $a0, inp_buf
    la   $a1, str_exit
    jal  strcmp
    beq  $v0, $zero, do_exit

    # comando inválido
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
    li   $v0, 10
    syscall
