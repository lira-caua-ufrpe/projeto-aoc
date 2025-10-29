# ============================================================
# main.asm – Shell do banco + parser de comandos
# ============================================================
.data
cmd_cadastrar: .asciiz "conta_cadastrar"
# buffers de tokens: tok_ptrs[0] = comando; [1..3] = opções
.text
.globl main

main:
    # laço principal
shell_loop:
    # banner
    la  $a0, banner
    jal print_str

    # lê linha
    la  $a0, linha_in
    li  $a1, 128
    jal read_line

    # atualiza “relógio” (acumula ms; futuramente atualiza string e juros)
    jal tick_relogio

    # tokenizar por '-' e '\n'
    la  $t0, linha_in
    la  $t1, tok_ptrs
    sw  $t0, 0($t1)          # primeiro token começa no início
    li  $t2, 1               # idx próximo token (1..3)
tok_loop:
    lb  $t3, 0($t0)
    beq $t3, $zero, tok_end
    beq $t3, 10, tok_finish  # '\n'
    beq $t3, '-', is_delim
    addi $t0,$t0,1
    j tok_loop
is_delim:
    sb  $zero, 0($t0)        # termina token com '\0'
    addi $t0,$t0,1
    blt  $t2,4, store_ptr
    j tok_loop
store_ptr:
    sll $t4,$t2,2            # *4
    add $t4,$t4,$t1
    sw  $t0, 0($t4)          # salva ponteiro
    addi $t2,$t2,1
    j tok_loop
tok_finish:
    sb  $zero, 0($t0)
tok_end:

    # comparar comando
    la  $a0, tok_ptrs
    lw  $a0, 0($a0)          # a0 = ptr do comando
    la  $a1, cmd_cadastrar
    jal strcmp
    beq $v0, $zero, do_cadastrar

    # (aqui depois encadeia outros comandos usando strcmp)
    la  $a0, msg_inv_cmd
    jal print_str
    j shell_loop

# ----- executar conta_cadastrar -cpf -conta6 -nome -----
do_cadastrar:
    la  $t1, tok_ptrs
    lw  $a0, 4($t1)          # option1 = cpf
    lw  $a1, 8($t1)          # option2 = conta6 (string numérica, 6 dígitos)
    lw  $a2, 12($t1)         # option3 = nome (resto da linha sem '-')
    beq  $a0,$zero, shell_loop
    beq  $a1,$zero, shell_loop
    beq  $a2,$zero, shell_loop
    jal  conta_cadastrar
    j shell_loop
