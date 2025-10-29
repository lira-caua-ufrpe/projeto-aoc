# ============================================================
# ops_mov.asm – operações financeiras (stubs iniciais)
# ============================================================
.text
.globl sacar_cmd, depositar_cmd, transferir_debito_cmd, transferir_credito_cmd
.globl pagar_fatura_cmd, debito_extrato_cmd, credito_extrato_cmd
.globl conta_format_cmd, conta_fechar_cmd, alterar_limite_cmd

sacar_cmd:               jr $ra
depositar_cmd:           jr $ra
transferir_debito_cmd:   jr $ra
transferir_credito_cmd:  jr $ra
pagar_fatura_cmd:        jr $ra
debito_extrato_cmd:      jr $ra
credito_extrato_cmd:     jr $ra
conta_format_cmd:        jr $ra
conta_fechar_cmd:        jr $ra
alterar_limite_cmd:      jr $ra
