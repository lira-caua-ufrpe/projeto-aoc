# Exercícios (20%)

## ex1.asm – Funções de string (strcpy, memcpy, strcmp, strncmp, strcat)
**Como executar**
1. Abra `exercicios/ex1.asm` no MARS.
2. Monte e execute.
3. O console deve exibir testes de cada função (0 para iguais em `strcmp/strncmp`).

**Esperados (resumo)**
- `strcpy` copia `"UFRPE"` para `dst`.
- `strcat(dst,"-PE")` resulta em `"UFRPE-PE"`.
- `strcmp("UFRPE","UFRPE") = 0`.
- `strcmp("UFRPE","UFRPa") < 0` (diferença ASCII no primeiro char que diverge).
- `strncmp("UFRPE","UFRPa",3) = 0` (três primeiros iguais).

## ex2.asm – MMIO Echo (Keyboard → Display)
**Como executar**
1. MARS → Tools → **Keyboard and Display MMIO Simulator** → **Connect to MIPS**.
2. Monte e execute `exercicios/ex2.asm`.
3. Digite no campo **KEYBOARD** → aparece no **DISPLAY** em tempo real.
4. **ESC** encerra.

**Endereços MMIO (MARS)**
- `0xFFFF0000` Keyboard Control (bit0=1 dado disponível)
- `0xFFFF0004` Keyboard Data (ASCII no byte baixo)
- `0xFFFF0008` Display Control (bit0=1 pronto p/ transmitir)
- `0xFFFF000C` Display Data (escrever ASCII no byte baixo)
