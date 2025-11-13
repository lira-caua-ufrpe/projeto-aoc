# main.asm — shell principal (MARS 4.5)

# --- includes ---
# importa módulos com dados, I/O, strings, tempo, operações de conta, finanças, transações,
# extratos, utilitários, persistência e comandos específicos
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
.include "cmd_persist.asm"   # cmd_13/14/15
.include "cmd_conta_format.asm"

.text
.globl main

main:
    # carrega estado salvo (se existir) logo no boot
    jal  load_state

# ============================================================
# loop principal
# ============================================================
main_loop:
    # atualiza relógio lógico
    jal  tick_datetime

    # aplica juros automáticos nas contas
    jal  aplicar_juros_auto

    # imprime banner / prompt
    la   $a0, banner
    jal  print_str

    # lê linha do usuário
    la   $a0, inp_buf
    li   $a1, 256
    jal  read_line

    # remove espaços/fim de linha
    la   $a0, inp_buf
    jal  strip_line_end

    # verifica comando de saída
    la   $a0, inp_buf
    la   $a1, str_exit
    jal  strcmp
    beq  $v0, $zero, do_exit

    # verifica comando help
    la   $a0, inp_buf
    la   $a1, str_help
    jal  strcmp
    bne  $v0, $zero, dispatch_cmds
    la   $a0, help_txt
    jal  print_str
    j    main_loop

# ============================================================
# despacho de comandos
# ============================================================
dispatch_cmds:
    # salvar estado (cmd_13)
    la   $a0, inp_buf
    jal  handle_cmd_salvar
    bne  $v0, $zero, main_loop

    # recarregar estado (cmd_14)
    la   $a0, inp_buf
    jal  handle_cmd_recarregar
    bne  $v0, $zero, main_loop

    # formatar dados (cmd_15)
    la   $a0, inp_buf
    jal  handle_cmd_formatar
    bne  $v0, $zero, main_loop
    
    # operações de conta e transações
    la   $a0, inp_buf
    jal  handle_conta_cadastrar
    bne  $v0, $zero, main_loop

    la   $a0, inp_buf
    jal  handle_pagar_debito
    bne  $v0, $zero, main_loop

    la   $a0, inp_buf
    jal  handle_pagar_credito
    bne  $v0, $zero, main_loop

    la   $a0, inp_buf
    jal  handle_alterar_limite
    bne  $v0, $zero, main_loop

    la   $a0, inp_buf
    jal  handle_dump_trans_cred
    bne  $v0, $zero, main_loop

    la   $a0, inp_buf
    jal  handle_dump_trans_deb
    bne  $v0, $zero, main_loop

    la   $a0, inp_buf
    jal  handle_datetime_set
    bne  $v0, $zero, main_loop

    la   $a0, inp_buf
    jal  handle_datetime_show
    bne  $v0, $zero, main_loop

    la   $a0, inp_buf
    jal  handle_extrato_debito
    bne  $v0, $zero, main_loop

    la   $a0, inp_buf
    jal  handle_extrato_credito
    bne  $v0, $zero, main_loop

    la   $a0, inp_buf
    jal  handle_pagar_fatura
    bne  $v0, $zero, main_loop

    la   $a0, inp_buf
    jal  handle_sacar
    bne  $v0, $zero, main_loop

    la   $a0, inp_buf
    jal  handle_depositar
    bne  $v0, $zero, main_loop

    la   $a0, inp_buf
    jal  handle_conta_fechar
    bne  $v0, $zero, main_loop
    
    la   $a0, inp_buf
    jal  handle_conta_format
    bne  $v0, $zero, main_loop

    # nenhum comando reconhecido
    la   $a0, msg_invalid
    jal  print_str
    j    main_loop

# ============================================================
# finaliza execução
# ============================================================
do_exit:
    # salva estado antes de sair
    jal  save_state
    la   $a0, msg_bye
    jal  print_str
    li   $v0, 10        # exit
    syscall

