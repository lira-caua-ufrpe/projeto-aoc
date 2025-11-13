# main.asm � shell principal (MARS 4.5)

# --- includes (use estes se voc� vai montar s� este arquivo) ---
.include "data.asm"
.include "io.asm"
.include "strings.asm"
.include "time.asm"
.include "ops_conta.asm"
.include "ops_fin.asm"
.include "transacoes.asm"
.include "extratos.asm"
.include "ops_util.asm"   # precisa prover print_datahora/print_2dig




.text
.globl main

main:
    # loop principal
main_loop:
    # mant�m rel�gio l�gico ativo
    jal  tick_datetime

    # prompt
    la   $a0, banner
    jal  print_str

    # l� linha
    la   $a0, inp_buf
    li   $a1, 256
    jal  read_line

# trim à direita (remover \n ou espaços extras)
la   $a0, inp_buf
jal  strip_line_end


    # exit?
    la   $a0, inp_buf
    la   $a1, str_exit
    jal  strcmp
    beq  $v0, $zero, do_exit

    # help?
    la   $a0, inp_buf
    la   $a1, str_help
    jal  strcmp
    bne  $v0, $zero, dispatch_cmds
    la   $a0, help_txt
    jal  print_str
    j    main_loop

dispatch_cmds:
    # conta_cadastrar-<CPF>-<CONTA6>-<NOME>
    la   $a0, inp_buf
    jal  handle_conta_cadastrar
    bne  $v0, $zero, main_loop

    # pagar_debito-<CONTA6>-<DV>-<VALORcent>
    la   $a0, inp_buf
    jal  handle_pagar_debito
    bne  $v0, $zero, main_loop

    # pagar_credito-<CONTA6>-<DV>-<VALORcent>
    la   $a0, inp_buf
    jal  handle_pagar_credito
    bne  $v0, $zero, main_loop

    # alterar_limite-<CONTA6>-<DV>-<NOVOLIMcent>
    la   $a0, inp_buf
    jal  handle_alterar_limite
    bne  $v0, $zero, main_loop

    # dump_trans-cred-<CONTA6>-<DV>
    la   $a0, inp_buf
    jal  handle_dump_trans_cred
    bne  $v0, $zero, main_loop

    # dump_trans-deb-<CONTA6>-<DV>
    la   $a0, inp_buf
    jal  handle_dump_trans_deb
    bne  $v0, $zero, main_loop

    # datetime_set-DD/MM/AAAA- HH:MM:SS
    la   $a0, inp_buf
    jal  handle_datetime_set
    bne  $v0, $zero, main_loop

    # datetime_show
    la   $a0, inp_buf
    jal  handle_datetime_show
    bne  $v0, $zero, main_loop

    # debito_extrato-<CONTA6>-<DV>
    la   $a0, inp_buf
    jal  handle_extrato_debito
    bne  $v0, $zero, main_loop

    # credito_extrato-<CONTA6>-<DV>
    la   $a0, inp_buf
    jal  handle_extrato_credito
    bne  $v0, $zero, main_loop

    la   $a0, inp_buf
    jal  handle_pagar_fatura
    bne  $v0, $zero, main_loop
    # nada pegou
    la   $a0, msg_invalid
    jal  print_str
    j    main_loop
    

do_exit:
    la   $a0, msg_bye
    jal  print_str
    li   $v0, 10        # exit
    syscall
