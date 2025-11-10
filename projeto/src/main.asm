# main.asm — laço do shell (banner, help, exit, conta_cadastrar + R2)

.text
.globl main 			# Este arquivo define 'main' (ok exportar)

# (não declare .globl para funções/imports vindos de outros .asm no MARS)

# Rótulos de dados e funções importados de outros arquivos:
#
# IO.ASM: print_str, read_line, strip_line_end
# STRINGS.ASM: strcmp
# OPS_CONTA.ASM: handle_conta_cadastrar
# OPS_FINANCEIRO.ASM (ASSUMIDOS): handle_pagar_debito, handle_pagar_credito, handle_alterar_limite
# DATA.ASM: banner, inp_buf, help_txt, msg_invalid, msg_bye, str_help, str_exit

main:
main_loop:
	# 1. IMPRIME PROMPT E LÊ COMANDO
	
	# imprime banner
	la	$a0, banner
	jal	print_str

	# lê linha para inp_buf (até 255)
	la	$a0, inp_buf
	li	$a1, 255
	jal	read_line

	# strip final (remove \n, \r, espaços/tabs à direita)
	la	$a0, inp_buf
	jal	strip_line_end
	# len retornou em v0 (se precisar)

	# ----------------------------------------------------
	# 2. VERIFICAÇÃO DE COMANDOS DE CRIAÇÃO/OPERAÇÃO (R1/R2)
	# ----------------------------------------------------

	# Tenta tratar conta_cadastrar-... (R1)
	la	$a0, inp_buf
	jal	handle_conta_cadastrar
	bne	$v0, $zero, main_loop	# Se tratou (retorno != 0), volta pro banner

	# Tenta tratar pagar_debito-... (R2)
	la	$a0, inp_buf
	jal	handle_pagar_debito
	bne	$v0, $zero, main_loop

	# Tenta tratar pagar_credito-... (R2)
	la	$a0, inp_buf
	jal	handle_pagar_credito
	bne	$v0, $zero, main_loop

	# Tenta tratar alterar_limite-... (R2)
	la	$a0, inp_buf
	jal	handle_alterar_limite
	bne	$v0, $zero, main_loop

	# ----------------------------------------------------
	# 3. VERIFICAÇÃO DE COMANDOS FIXOS (HELP/EXIT)
	# ----------------------------------------------------

	# if (strcmp(inp_buf, "help")==0)
	la	$a0, inp_buf
	la	$a1, str_help
	jal	strcmp
	beq	$v0, $zero, do_help

	# if (strcmp(inp_buf, "exit")==0)
	la	$a0, inp_buf
	la	$a1, str_exit
	jal	strcmp
	beq	$v0, $zero, do_exit

	# ----------------------------------------------------
	# 4. DEFAULT (COMANDO INVÁLIDO)
	# ----------------------------------------------------

	# default: comando inválido
	la	$a0, msg_invalid
	jal	print_str
	j	main_loop

# ----------------------------------------------------
# 5. ROTINAS AUXILIARES
# ----------------------------------------------------

do_help:
	la	$a0, help_txt
	jal	print_str
	j	main_loop

do_exit:
	la	$a0, msg_bye
	jal	print_str
	li	$v0, 10 			# exit
	syscall