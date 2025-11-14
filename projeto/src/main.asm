# ============================================================
# Universidade Federal Rural de Pernambuco (UFRPE)
# Disciplina: Arquitetura e Organização de Computadores — 2025.2
# Avaliação: Projetos 1 (PE1) – 1a VA
# Professor: Vitor Coutinho
# Atividade: Lista de Exercícios – Questão 1 (string.h)
# Arquivo: main.asm
# Equipe: OPCODE
# Integrantes: Cauã Lira; Sérgio Ricardo; Lucas Emanuel; Vitor Emmanoel
# Data de entrega: 13/11/2025 (horário da aula)
# Apresentação: vídeo no ato da entrega
# Descrição: Implementa strcpy, memcpy, strcmp, strncmp, strcat
#            e um main com casos de teste no MARS (4.5+).
# Convenções:
#   - strcpy(a0=dst, a1=src)              -> v0=dst
#   - memcpy(a0=dst, a1=src, a2=num)      -> v0=dst
#   - strcmp(a0=str1, a1=str2)            -> v0 (<0, 0, >0)
#   - strncmp(a0=str1, a1=str2, a3=num)   -> v0 (<0, 0, >0)
#   - strcat(a0=dst, a1=src)              -> v0=dst
#   - Temporários: $t0..$t9 | PC inicia em 'main'
# Observação: Como em C, o comportamento de strcat com áreas sobrepostas é indefinido.
# ============================================================

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
.include "persist.asm"        # R10: persist?ncia (save/load)
.include "cmd_persist.asm"   # <? NOVO: cmd_13/14/15
.include "cmd_conta_format.asm"


.text
.globl main

main:
    # carrega estado salvo (se existir) logo no boot
    jal  load_state

    # loop principal
main_loop:
    # mant?m relogio logico ativo
    jal  tick_datetime
    # R7: juros automaticos
    jal  aplicar_juros_auto

    # prompt
    la   $a0, banner
    jal  print_str

   
    la   $a0, inp_buf
    li   $a1, 256
    jal  read_line

   
    la   $a0, inp_buf
    jal  strip_line_end

  
    la   $a0, inp_buf
    la   $a1, str_exit
    jal  strcmp
    beq  $v0, $zero, do_exit

    
    la   $a0, inp_buf
    la   $a1, str_help
    jal  strcmp
    bne  $v0, $zero, dispatch_cmds
    la   $a0, help_txt
    jal  print_str
    j    main_loop

dispatch_cmds:
 # salvar (cmd_13)
    la   $a0, inp_buf
    jal  handle_cmd_salvar
    bne  $v0, $zero, main_loop

   
    la   $a0, inp_buf
    jal  handle_cmd_recarregar
    bne  $v0, $zero, main_loop

    
    la   $a0, inp_buf
    jal  handle_cmd_formatar
    bne  $v0, $zero, main_loop
    
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
    
    # conta_format-<CONTA6>-<DV>
    la   $a0, inp_buf
    jal  handle_conta_format
    bne  $v0, $zero, main_loop

    
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
