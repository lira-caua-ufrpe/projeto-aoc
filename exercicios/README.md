# Exercícios — PE1 (Assembly MIPS | MARS 4.5)

Esta pasta reúne os arquivos das **questões da lista (20%)** da 1ª VA da disciplina **Arquitetura e Organização de Computadores — 2025.2** (UFRPE).
**Equipe:** OPCODE — *Cauã Lira; Sérgio Ricardo; Lucas Emanuel*.

## 📦 Conteúdo

```
exercicios/
├─ ex1.asm             # Questão 1 — funções estilo string.h em MIPS
├─ ex1_expected.txt    # Saída esperada do ex1
├─ ex2.asm             # Questão 2 — Echo/linha via MMIO (Keyboard/Display)
└─ ex2_expected.txt    # Saídas esperadas do ex2 (casos de teste)
```

### Q1 — `ex1.asm` (10%)

Implementação das funções inspiradas em `string.h` (parâmetros e retorno do enunciado):

* `strcpy(a0=dst, a1=src)            -> v0 = dst`
* `memcpy(a0=dst, a1=src, a2=num)    -> v0 = dst`
* `strcmp(a0=str1, a1=str2)          -> v0 <0 | 0 | >0`
* `strncmp(a0=str1, a1=str2, a3=num) -> v0 <0 | 0 | >0`
* `strcat(a0=dst, a1=src)            -> v0 = dst`

Há um **`main` de testes** que imprime os resultados no terminal padrão do MARS (syscalls).
✔️ **Arquivo de referência:** `ex1_expected.txt`.

### Q2 — `ex2.asm` (10%)

Entrada/saída via **MMIO** usando **Tools → Keyboard and Display MMIO Simulator** (polling, sem interrupções):

* **Versão principal (`main`)**

  * Lê uma **linha** do Keyboard MMIO com **Backspace** funcional;
  * **Validação**: aceita **espaço, letras e dígitos**;
  * **Bloqueio de espaço duplo** durante digitação;
  * **Normalização de espaços** após leitura (**ltrim + colapso de múltiplos internos + rtrim**);
  * Converte o texto para **MAIÚSCULAS**;
  * Imprime no Display: a linha normalizada + **Tamanho**, **#Letras** e **#Dígitos**.
* **Versão mínima (`main_echo`)**

  * Loop infinito de **eco**: lê 1 byte do Keyboard e escreve no Display imediatamente.
  * Útil para a **demonstração estrita** do enunciado.

✔️ **Arquivo de referência:** `ex2_expected.txt`.

---

## ▶️ Como executar (MARS 4.5)

### Opção A — Interface do MARS

1. Abra o `Mars4_5.jar`.
2. Marque **Settings → Initialize Program Counter to ‘main’**.

   * Para eco minimalista da Q2, mude para **‘main_echo’**.
3. File → Open → selecione `ex1.asm` ou `ex2.asm`.
4. **Assemble** (F3) e depois **Run → Go** (F5).
5. **Q2 (MMIO):**

   * Abra **Tools → Keyboard and Display MMIO Simulator**;
   * Clique em **Connect to MIPS**;
   * Digite no campo **Keyboard** (ENTER encerra a leitura de linha).

### Opção B — Linha de comando

No diretório raiz do repositório (onde está o `Mars4_5.jar`):

```bash
# Questão 1
java -jar Mars4_5.jar exercicios/ex1.asm

# Questão 2 (abre o simulador; depois use o menu Tools para conectar o MMIO)
java -jar Mars4_5.jar exercicios/ex2.asm
```

> Dica: se o Display não mostrar nada, confirme que o programa está **rodando** e que o **MMIO está conectado**.

---

## ✅ Checklist de atendimento ao enunciado

**Q1 — string.h em MIPS**

* [x] `strcpy`, `memcpy`, `strcmp`, `strncmp`, `strcat` com chamadas e retornos **exatos**;
* [x] **`main` com casos de teste** demonstrando cada função;
* [x] **Comentários linha a linha** e **cabeçalho completo**.

**Q2 — MMIO (polling)**

* [x] Uso de **endereços MMIO** do MARS:

  * Keyboard: `0xFFFF0000` (RC), `0xFFFF0004` (RD)
  * Display:  `0xFFFF0008` (TC), `0xFFFF000C` (TD)
* [x] Comunicação com `lw`/`sb` e **busy-wait** no bit 0 de RC/TC;
* [x] **Echo contínuo** implementado em `main_echo`;
* [x] Versão principal com **linha, backspace, validação e normalização** (bonus pedagógico);
* [x] **Comentários linha a linha** e **cabeçalho completo**.

---

## 🧪 Saídas esperadas

* `ex1_expected.txt` — saída esperada do `ex1.asm`.
* `ex2_expected.txt` — casos de teste (entrada digitada no Keyboard → saída esperada no Display).

---

## 🛠️ Solução de problemas (Q2/MMIO)

* **Nada aparece no Display**

  * Verifique **Run → Go** ativo e **Tools → MMIO → Connect to MIPS**.
  * Em **Settings → Memory Configuration**, use **Default**.
* **Eco minimalista para teste rápido**

  * Marque o PC para **`main_echo`** em *Settings* e rode novamente.
* **Backspace não apaga no Display**

  * O código usa `'\b'`, `' '` e `'\b'` para “apagar”; confira se você está digitando no **campo Keyboard** do simulador.

---
