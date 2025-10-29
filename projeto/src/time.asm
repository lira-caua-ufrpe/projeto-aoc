# ============================================================
# time.asm – data/hora e atualização com syscall 30
# ============================================================
.text
.globl tick_relogio

# tick_relogio()
# - Atualiza datahora a cada ~1s usando syscall 30 (ms since start)
# - Acumula em acc_ms para juros (1% a cada 60s) – aplicar depois.
tick_relogio:
    # lê ms atual
    li  $v0,30
    syscall                  # v0 = ms desde start
    la  $t0,last_ms
    lw  $t1,0($t0)           # last
    beq $t1,$zero, init_ms
    sub $t2,$v0,$t1          # delta
    # acumula
    la  $t3,acc_ms
    lw  $t4,0($t3)
    add $t4,$t4,$t2
    sw  $t4,0($t3)
    # se >=1000, apenas “marca” que passou 1s (simplificado)
    # (para agora não vamos formatar a string; mantemos placeholder)
    sw  $v0,0($t0)
    jr  $ra
init_ms:
    sw  $v0,0($t0)
    jr  $ra
