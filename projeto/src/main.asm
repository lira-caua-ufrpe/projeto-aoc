# main.asm — shell principal (MARS 4.5)

# --- includes ---
.include "data.asm"
.include "io.asm"
.include "strings.asm"
.include "time.asm"
.include "ops_conta.asm"
.include "ops_fin.asm"
.include "transacoes.asm"
.include "extratos.asm"
.include "ops_util.asm"
.include "persist.asm"        # R10: persistência (save/load)

.text
.globl main

main:
    # carrega estado salvo (se existir) logo no boot
    jal  load_state

    # loop principal
main_loop:
    # mantém relógio lógico ativo
    jal  tick_datetime
    # R7: juros automáticos
    jal  aplicar_juros_auto

    # prompt
    la   $a0, banner
    jal  print_str

    # lê linha
    la   $a0, inp_buf
    li   $a1, 256
    jal  read_line

    # trim à direita
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

    # pagar_fatura-<CONTA6>-<DV>-<VALOR>-<METHOD>
    la   $a0, inp_buf
    jal  handle_pagar_fatura
    bne  $v0, $zero, main_loop

    # sacar-<CONTA6>-<DV>-<VALORcent>
    la   $a0, inp_buf
    jal  handle_sacar
    bne  $v0, $zero, main_loop

    # depositar-<CONTA6>-<DV>-<VALORcent>
    la   $a0, inp_buf
    jal  handle_depositar
    bne  $v0, $zero, main_loop

    # conta_fechar-<CONTA6>-<DV>
    la   $a0, inp_buf
    jal  handle_conta_fechar
    bne  $v0, $zero, main_loop

    # nada pegou
    la   $a0, msg_invalid
    jal  print_str
    j    main_loop

do_exit:
    # salva estado ANTES de sair
    jal  save_state
    la   $a0, msg_bye
    jal  print_str
    li   $v0, 10        # exit
    syscall
