# ============================================================
# Universidade Federal Rural de Pernambuco (UFRPE)
# Disciplina: Arquitetura e Organização de Computadores — 2025.2
# Avaliação: Projetos 1 (PE1) – 1a VA
# Professor: Vitor Coutinho
# Atividade: Lista de Exercícios – Questão 1 (string.h)
# Arquivo: cmd_persist.asm
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





# cmd_persist.asm — comandos de persistência: salvar, recarregar e formatar
# Depende de: print_str, strcmp, save_state, load_state
# e dos símbolos definidos em data.asm (clientes_*, trans_*)

.text
.globl handle_cmd_salvar
.globl handle_cmd_recarregar
.globl handle_cmd_formatar
.globl format_state
.globl memclr

# --- memclr(a0=addr, a1=len) -> zera len bytes a partir de addr ---
memclr:
    addiu $sp, $sp, -16
    sw    $ra, 12($sp)
    sw    $s0,  8($sp)
    sw    $s1,  4($sp)

    move  $s0, $a0          # ponteiro base
    move  $s1, $a1          # tamanho
mc_loop:
    blez  $s1, mc_end       # se len <= 0, fim
    sb    $zero, 0($s0)     # zera byte
    addiu $s0, $s0, 1
    addiu $s1, $s1, -1
    j     mc_loop
mc_end:
    lw    $s1,  4($sp)
    lw    $s0,  8($sp)
    lw    $ra, 12($sp)
    addiu $sp, $sp, 16
    jr    $ra
    nop

# --- format_state() -> zera todos os clientes e transações ---
# Não altera data/hora, apenas reinicia buffers e valores
format_state:
    addiu $sp, $sp, -16
    sw    $ra, 12($sp)

    # limpa flags de uso e informações de clientes
    la    $a0, clientes_usado
    li    $a1, 50
    jal   memclr

    la    $a0, clientes_cpf
    li    $a1, 600
    jal   memclr

    la    $a0, clientes_conta
    li    $a1, 350
    jal   memclr

    la    $a0, clientes_dv
    li    $a1, 50
    jal   memclr

    la    $a0, clientes_nome
    li    $a1, 1650
    jal   memclr

    # limpa saldos e limites
    la    $a0, clientes_saldo_cent
    li    $a1, 200
    jal   memclr

    la    $a0, clientes_limite_cent
    li    $a1, 200
    jal   memclr

    la    $a0, clientes_devido_cent
    li    $a1, 200
    jal   memclr

    # limpa rings de débito: metas e valores
    la    $a0, trans_deb_head
    li    $a1, 200
    jal   memclr

    la    $a0, trans_deb_count
    li    $a1, 200
    jal   memclr

    la    $a0, trans_deb_wptr
    li    $a1, 200
    jal   memclr

    la    $a0, trans_deb_vals
    li    $a1, 10000
    jal   memclr

    # limpa rings de crédito: metas e valores
    la    $a0, trans_cred_head
    li    $a1, 200
    jal   memclr

    la    $a0, trans_cred_count
    li    $a1, 200
    jal   memclr

    la    $a0, trans_cred_wptr
    li    $a1, 200
    jal   memclr

    la    $a0, trans_cred_vals
    li    $a1, 10000
    jal   memclr

    lw    $ra, 12($sp)
    addiu $sp, $sp, 16
    jr    $ra
    nop

# --- handle_cmd_salvar(a0=buf) -> v0=1 se tratou ---
handle_cmd_salvar:
    addiu $sp, $sp, -16
    sw    $ra, 12($sp)
    sw    $s0,  8($sp)

    move  $s0, $a0
    la    $a1, str_salvar
    jal   strcmp
    bne   $v0, $zero, hcs_notmine  # comando não é "salvar"

    # comando "salvar"
    jal   save_state
    beq   $v0, $zero, hcs_fail      # falha ao salvar
    la    $a0, msg_salvo_ok
    jal   print_str
    li    $v0, 1
    j     hcs_end
hcs_fail:
    la    $a0, msg_salvo_fail
    jal   print_str
    li    $v0, 1
    j     hcs_end
hcs_notmine:
    move  $v0, $zero                # comando não é tratado
hcs_end:
    lw    $s0,  8($sp)
    lw    $ra, 12($sp)
    addiu $sp, $sp, 16
    jr    $ra
    nop

# --- handle_cmd_recarregar(a0=buf) ---
handle_cmd_recarregar:
    addiu $sp, $sp, -16
    sw    $ra, 12($sp)

    la    $a1, str_recarregar
    jal   strcmp
    bne   $v0, $zero, hcr_notmine  # comando não é "recarregar"

    jal   load_state
    beq   $v0, $zero, hcr_fail      # falha ao carregar
    la    $a0, msg_load_ok
    jal   print_str
    li    $v0, 1
    j     hcr_end
hcr_fail:
    la    $a0, msg_load_fail
    jal   print_str
    li    $v0, 1
    j     hcr_end
hcr_notmine:
    move  $v0, $zero
hcr_end:
    lw    $ra, 12($sp)
    addiu $sp, $sp, 16
    jr    $ra
    nop

# --- handle_cmd_formatar(a0=buf) ---
handle_cmd_formatar:
    addiu $sp, $sp, -16
    sw    $ra, 12($sp)

    la    $a1, str_formatar
    jal   strcmp
    bne   $v0, $zero, hcf_notmine  # comando não é "formatar"

    jal   format_state               # zera todos clientes e transações
    la    $a0, msg_fmt_ok
    jal   print_str
    li    $v0, 1
    j     hcf_end
hcf_notmine:
    move  $v0, $zero
hcf_end:
    lw    $ra, 12($sp)
    addiu $sp, $sp, 16
    jr    $ra
    nop
