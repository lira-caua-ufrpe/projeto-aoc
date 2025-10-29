# ============================================================
# strings.asm – strcpy / strcmp / strncmp / strcat
# (idênticas às da lista; resumidas aqui)
# ============================================================
.text
.globl strcpy, strcmp, strncmp, strcat

strcpy:
    move $t0, $a0
    move $t1, $a1
1:  lb $t2, 0($t1)
    sb $t2, 0($t0)
    addi $t1,$t1,1
    addi $t0,$t0,1
    bne $t2,$zero,1b
    move $v0,$a0
    jr $ra

strcmp:
    move $t0,$a0
    move $t1,$a1
1:  lb $t2,0($t0)
    lb $t3,0($t1)
    beq $t2,$t3,2f
    sub $v0,$t2,$t3
    jr  $ra
2:  beq $t2,$zero,3f
    addi $t0,$t0,1
    addi $t1,$t1,1
    j 1b
3:  move $v0,$zero
    jr $ra

strncmp:
    move $t0,$a0
    move $t1,$a1
    move $t4,$a3
    beq  $t4,$zero,3f
1:  lb $t2,0($t0)
    lb $t3,0($t1)
    bne $t2,$t3,2f
    beq $t2,$zero,3f
    addi $t0,$t0,1
    addi $t1,$t1,1
    addi $t4,$t4,-1
    bgtz $t4,1b
3:  move $v0,$zero
    jr $ra
2:  sub $v0,$t2,$t3
    jr $ra

strcat:
    move $t0,$a0
    move $t1,$a1
1:  lb $t2,0($t0)
    beq $t2,$zero,2f
    addi $t0,$t0,1
    j 1b
2:  lb $t3,0($t1)
    sb $t3,0($t0)
    addi $t1,$t1,1
    addi $t0,$t0,1
    bne $t3,$zero,2b
    move $v0,$a0
    jr $ra
