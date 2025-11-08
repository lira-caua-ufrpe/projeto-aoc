# Exercícios — PE1 (Assembly MIPS | MARS 4.5)

Esta pasta reúne os arquivos das **questões da lista (20%)**.

## 📁 Arquivos
- `ex1.asm` — Implementa as funções da `string.h` em MIPS:
  - `strcpy(a0=dst, a1=src) -> v0=dst`
  - `memcpy(a0=dst, a1=src, a2=num) -> v0=dst`
  - `strcmp(a0=str1, a1=str2) -> v0`  (<0, 0, >0)
  - `strncmp(a0=str1, a1=str2, a3=num) -> v0`  (<0, 0, >0)
  - `strcat(a0=dst, a1=src) -> v0=dst`
  - `main` com casos de teste imprimindo os resultados  
- `ex1_expected.txt` — **Saída esperada** ao executar `ex1.asm`.
- `ex2.asm` — (placeholder) Esqueleto para a questão 2 da lista.

---

## ▶️ Como executar (MARS 4.5)

### Opção A — Interface do MARS
1. Abra o `Mars4_5.jar`.
2. Ative **Settings → Initialize Program Counter to 'main'** (ou deixe o `main` no topo, como já está).
3. Em **File → Open**, escolha `ex1.asm`.
4. Clique em **Assemble** e depois **Run**.

### Opção B — Linha de comando
No diretório raiz do repositório (onde está o `Mars4_5.jar`):
```bash
java -jar Mars4_5.jar exercicios/ex1.asm
