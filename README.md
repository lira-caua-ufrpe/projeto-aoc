<p align="center">
  <img src="projeto-aoc/docs/ufrpe-logo.png" alt="UFRPE" width="120"/>
</p>

<h1 align="center">opcode-shell — Banco em MIPS/MARS</h1>

<p align="center">
  <strong>Universidade Federal Rural de Pernambuco — Licenciatura em Computação</strong><br/>
  Disciplina: Arquitetura de Computadores (AOC) — Prof. Vitor Coutinho
</p>

> Projeto avaliativo (modelo “projeto”) onde implementamos um sistema bancário em Assembly MIPS, rodando no MARS, com shell de comandos, conta corrente + cartão de crédito, extratos, juros automáticos e persistência em arquivo.

---

## 👥 Equipe
- **Cauã Lira**
- **Lucas Emanuel**
- **Sérgio Ricardo**
- **Vitor Emmanoel**

## 🚀 Como executar (rápido)
1. Abra o **MARS 4.5** que já está no repositório (arquivo `Mars4_5.jar`).
2. Em **File → Open**, carregue `projeto/src/main.asm`.
3. Clique **Run → Assemble** e depois **Run → Go**.
4. O shell aparece como `opcode-shell>>`. Digite `help` para ver os comandos.

> 💡 Para facilitar a persistência (R10), incluímos o `Mars4_5.jar` **dentro da pasta do projeto**. Assim, o arquivo `opcode_state.bin` é criado/atualizado no próprio diretório do código.
>  
> Se você preferir usar um **caminho absoluto**, há também uma versão alternativa de `persist.asm` (V2) com o caminho ajustável.

## 🧩 O que o sistema faz (highlights)
- Cadastro/fechamento de contas com **DV**.
- **Pagamentos** em débito e crédito, **saque/depósito**.
- **Extratos** de débito e crédito (com data/hora e tipo de transação).
- **Juros automáticos** de 1% sobre a dívida do cartão a cada 60s.
- **Persistência (R10–R13)** em `opcode_state.bin`:  
  `salvar`, `recarregar`, `formatar` + carregamento na inicialização.

## 🔤 Exemplos rápidos de comandos
```text
conta_cadastrar-12345678901-123456-Ana
depositar-123456-X-10000
pagar_credito-123456-X-2500
debito_extrato-123456-X
credito_extrato-123456-X
salvar
````

## 📂 Estrutura (resumo)

```
/projeto
  └── /src
      ├── main.asm            # loop do shell e dispatch
      ├── data.asm            # dados globais e mensagens
      ├── io.asm, strings.asm # I/O e utilitários de string
      ├── time.asm            # data/hora
      ├── ops_conta.asm       # cadastro/fechamento
      ├── ops_fin.asm         # débito, crédito, fatura, saque, depósito, juros
      ├── extratos.asm        # extratos R3/R5/R6/R7
      ├── transacoes.asm      # formatação de valores e datas
      ├── persist.asm         # R10–R13 (arquivo opcode_state.bin)
      └── Mars4_5.jar         # MARS incluído para facilitar execução
```

## 📘 Documentação completa

Para requisitos, decisões e todos os comandos detalhados, veja o README técnico em:
`projeto/README.md`

---

### Créditos

Projeto desenvolvido por estudantes da **UFRPE** (Licenciatura em Computação), na disciplina **Arquitetura de Computadores** (Prof. Vitor Coutinho).


