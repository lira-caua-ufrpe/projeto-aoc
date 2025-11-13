# main.asm — shell principal (MARS 4.5)

# --- includes (use estes se você vai montar só este arquivo) ---
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
    # mantém relógio lógico ativo
    jal  tick_datetime
    nop

    # R7: aplicar juros automáticos (1% a cada 60s)
    jal  aplicar_juros_auto
    nop

    # prompt
    la   $a0, banner
    jal  print_str
    nop

    # lê linha
    la   $a0, inp_buf
    li   $a1, 256
    jal  read_line
    nop

    # trim à direita (remover \n, \r, espaços e \t)
    la   $a0, inp_buf
    jal  strip_line_end
    nop

    # se ficou vazia, volta pro loop
    beq  $v0, $zero, main_loop

    # exit?
    la   $a0, inp_buf
    la   $a1, str_exit
    jal  strcmp
    nop
    beq  $v0, $zero, do_exit

    # help?
    la   $a0, inp_buf
    la   $a1, str_help
    jal  strcmp
    nop
    bne  $v0, $zero, dispatch_cmds
    la   $a0, help_txt
    jal  print_str
    nop
    j    main_loop

dispatch_cmds:
    # conta_cadastrar-<CPF>-<CONTA6>-<NOME>
    la   $a0, inp_buf
    jal  handle_conta_cadastrar
    nop
    bne  $v0, $zero, main_loop

    # pagar_debito-<CONTA6>-<DV>-<VALORcent>
    la   $a0, inp_buf
    jal  handle_pagar_debito
    nop
    bne  $v0, $zero, main_loop

    # pagar_credito-<CONTA6>-<DV>-<VALORcent>
    la   $a0, inp_buf
    jal  handle_pagar_credito
    nop
    bne  $v0, $zero, main_loop

    # alterar_limite-<CONTA6>-<DV>-<NOVOLIMcent>
    la   $a0, inp_buf
    jal  handle_alterar_limite
    nop
    bne  $v0, $zero, main_loop

    # dump_trans-cred-<CONTA6>-<DV>
    la   $a0, inp_buf
    jal  handle_dump_trans_cred
    nop
    bne  $v0, $zero, main_loop

    # dump_trans-deb-<CONTA6>-<DV>
    la   $a0, inp_buf
    jal  handle_dump_trans_deb
    nop
    bne  $v0, $zero, main_loop

    # datetime_set-DD/MM/AAAA- HH:MM:SS
    la   $a0, inp_buf
    jal  handle_datetime_set
    nop
    bne  $v0, $zero, main_loop

    # datetime_show
    la   $a0, inp_buf
    jal  handle_datetime_show
    nop
    bne  $v0, $zero, main_loop

    # debito_extrato-<CONTA6>-<DV>
    la   $a0, inp_buf
    jal  handle_extrato_debito
    nop
    bne  $v0, $zero, main_loop

    # credito_extrato-<CONTA6>-<DV>
    la   $a0, inp_buf
    jal  handle_extrato_credito
    nop
    bne  $v0, $zero, main_loop

    # pagar fatura
    la   $a0, inp_buf
    jal  handle_pagar_fatura
    nop
    bne  $v0, $zero, main_loop

    # sacar-<CONTA6>-<DV>-<VALORcent>
    la   $a0, inp_buf
    jal  handle_sacar
    nop
    bne  $v0, $zero, main_loop

    # depositar-<CONTA6>-<DV>-<VALORcent>
    la   $a0, inp_buf
    jal  handle_depositar
    nop
    bne  $v0, $zero, main_loop

    # conta_fechar-<CONTA6>-<DV>
    la   $a0, inp_buf
    jal  handle_conta_fechar
    nop
    bne  $v0, $zero, main_loop

    # nada pegou
    la   $a0, msg_invalid
    jal  print_str
    nop
    j    main_loop

do_exit:
    la   $a0, msg_bye
    jal  print_str
    nop
    li   $v0, 10        # exit
    syscall
