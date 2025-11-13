# opcode-shell (MIPS) — banco em terminal

Sistema bancário em MIPS/MARS com interpretador de comandos (shell), suportando até __50 clientes__ com conta corrente + cartão de crédito, extratos, juros automáticos e persistência em arquivo.

## Requisitos do enunciado atendidos (__R1–R13__):

*   __R1__ – Cadastro de clientes com geração de DV (até 50 clientes).
*   __R2__ – Pagamento em débito/crédito, limite de crédito padrão (R$ 1500,00) e alteração de limite.
*   __R3__ – Registro de transações de débito/crédito por cliente (até 50 por tipo, buffer circular).
*   __R4__ – Configuração e atualização contínua de data/hora usando `syscall 30`.
*   __R5__ – Extratos de débito e crédito, com data, valor e conta destino.
*   __R6__ – Pagamento parcial/total de fatura (via saldo ou externo), com validação de valor.
*   __R7__ – Juros de 1% a cada 60 segundos sobre a dívida do cartão, registrados no extrato.
*   __R8__ – Saques e depósitos na conta corrente.
*   __R9__ – Encerramento de conta com checagem de saldo e dívida zerados.
*   __R10__ – Salvamento automático em arquivo binário e restauração ao iniciar.
*   __R11__ – Comando `salvar` para gravar o estado atual no arquivo externo.
*   __R12__ – Comando `recarregar` para restaurar os dados salvos, descartando alterações não salvas.
*   __R13__ – Comando `formatar` para apagar clientes e transações da execução atual (sem salvar automaticamente).

> Diferenças em relação ao enunciado:  
> \- Os comandos `transferir_debito` e `transferir_credito` __não existem__; o sistema usa `pagar_debito` / `pagar_credito`.  
> \- O comando `data_hora` do enunciado é implementado como `datetime_set-...` e `datetime_show`.

---

## Como executar

*   MARS 4.5+
*   Abra `main.asm` (ele inclui os demais `.asm`).
*   __Run → Assemble__, depois __Run → Go__.

> Relógio (R4), juros (R7) e persistência funcionam em qualquer _Run speed_.

---

## Arquitetura (arquivos)

*   `data.asm`
    *   Constantes (`MAX_CLIENTS = 50`, `TRANS_MAX = 50`, `LIMITE_PADRAO_CENT` etc.).
    *   Estruturas de clientes:
        *   `clientes_usado`, `clientes_cpf`, `clientes_conta`, `clientes_dv`, `clientes_nome`
        *   `clientes_saldo_cent`, `clientes_limite_cent`, `clientes_devido_cent`
    *   Estruturas de transações (ring buffers de débito/crédito).
    *   Variáveis de data/hora (`curr_*`, `ms_last`, `ms_accum`).
    *   Mensagens de erro/sucesso e strings de comandos (`help`, `banner`, etc.).
*   `io.asm`
    *   Entrada/saída básica:
    *   `print_str` – imprime string `\0`.
    *   `read_line` – lê linha (até `\n`).
    *   Funções auxiliares de leitura e limpeza de buffer.
*   `strings.asm`
    *   `strcmp` e utilitários de parsing de strings (usados nos handlers de comando).
*   `time.asm` (__R4__)
    *   `tick_datetime` – consulta `syscall 30` (ms em `$a0`), calcula delta, faz clamp e atualiza `curr_day`, `curr_mon`, `curr_year`, `curr_hour`, `curr_min`, `curr_sec` com rollover e bissexto.
    *   `handle_datetime_set` – comando `datetime_set-DD/MM/AAAA- HH:MM:SS`.
    *   `handle_datetime_show` / `print_datetime` – imprime a data/hora corrente.
*   `ops_conta.asm` (__R1, R9__)
    *   `handle_conta_cadastrar` – comando `conta_cadastrar-<CPF11>-<CONTA6>-<NOME>`:
    *   gera DV via módulo 11 (pesos 2..7, resto 10 → X);
    *   valida CPF, número da conta, nome;
    *   checa CPF/número já em uso.
    *   `handle_conta_fechar` – `conta_fechar-<CONTA6>-<DV>`:
    *   só fecha se saldo corrente = 0 e dívida de crédito = 0;
    *   limpa cliente e suas transações; mensagens conforme enunciado (CPF não cadastrado, saldo devedor, etc.).
*   `ops_fin.asm` (__R2, R3, R6, R7, R8__)
    *   Débito / crédito (__R2__):
    *   `handle_pagar_debito` – `pagar_debito-<CONTA6>-<DV>-<VALORcent>`
        *   debita saldo se houver saldo suficiente;
        *   grava transação de débito no ring (__R3__).
    *   `handle_pagar_credito` – `pagar_credito-<CONTA6>-<DV>-<VALORcent>`
        *   usa limite de crédito, aumenta a dívida, respeitando limite;
        *   grava transação de crédito no ring.
    *   `handle_alterar_limite` – `alterar_limite-<CONTA6>-<DV>-<NOVO_LIMcent>`
    *   Saques e depósitos (__R8__):
    *   `handle_sacar` – `sacar-<CONTA6>-<DV>-<VALORcent>` (reduz saldo, com checagem).
    *   `handle_depositar` – `depositar-<CONTA6>-<DV>-<VALORcent>` (aumenta saldo).
    *   Fatura (__R6__):
    *   `handle_pagar_fatura` – `pagar_fatura-<CONTA6>-<DV>-<VALORcent>-<METHOD>`
        *   `METHOD = S` → paga usando saldo da conta;
        *   `METHOD = E` → pagamento externo (não mexe no saldo);
        *   sempre abate da dívida; se valor > dívida, falha.
    *   Juros (__R7__):
    *   `aplicar_juros_auto` – chamada em cada iteração do loop do shell:
        *   a cada 60 s (controlado pela hora atual), aplica __1%__ da dívida do cartão para cada cliente;
        *   registra a incidência como transação de crédito (tipo “JUROS”) no ring.
    *   Dumps de transações (__R3__):
    *   `handle_dump_trans_credito` – `dump_trans-cred-<CONTA6>-<DV>`
    *   `handle_dump_trans_debito` – `dump_trans-deb-<CONTA6>-<DV>`
*   `transacoes.asm`
    *   Funções de formatação de valores em reais/centavos.
    *   Montagem de strings de data/hora para uso nos extratos.
*   `extratos.asm` (__R3, R5, R6, R7__)
    *   `handle_extrato_debito` – `debito_extrato-<CONTA6>-<DV>`
    *   `handle_extrato_credito` – `credito_extrato-<CONTA6>-<DV>`
    *   Percorre os rings (débito/crédito) do cliente, do mais antigo ao mais novo, imprimindo:
    *   data/hora, tipo (DEB, CRED, JUROS, FATURA etc.), conta destino, valor;
    *   saldos atuais (saldo, limite, dívida, conforme o extrato).
*   `ops_util.asm`
    *   `print_2dig` – imprime inteiros 0..99 com zero à esquerda.
    *   `print_datahora` – imprime `DD/MM/AAAA HH:MM:SS`.
*   `persist.asm` (__R10–R13__)
    *   Usa syscalls 13–16 para ler/escrever o arquivo binário `opcode_state.bin`.
    *   `save_state` – serializa:
        *   clientes (tabelas de CPF, conta, DV, nome, saldos, limites, dívida);
        *   metadados dos rings (head/count/wptr);
        *   conteúdos dos rings de débito/crédito;
        *   data/hora e variáveis de controle de juros.
    *   `load_state` – tenta ler o mesmo arquivo ao iniciar:
        *   confere o header (`"OPCD"` + versão);
        *   se não existir ou for inválido, o sistema sobe “zerado”.
*   `fileio.asm`
    *   _Wrapper_ para comandos de shell de persistência:
    *   `salvar_cmd` – chama `save_state`.
    *   `recarregar_cmd` – chama `load_state` e restaura o estado salvo.
    *   `formatar_cmd` – limpa as estruturas em memória sem salvar (reset de clientes e transações).
    *   Usado pelo `main.asm` nos handlers dos comandos `salvar`, `recarregar`, `formatar`.
*   `main.asm`
    *   Loop principal do shell:
    *   imprime o `banner` (`opcode-shell>>`);
    *   lê uma linha com `read_line`;
    *   chama `tick_datetime` (R4) e `aplicar_juros_auto` (R7);
    *   faz _dispatch_ do comando (comparando prefixos com as `str_cmd_*`);
    *   ao iniciar, chama `load_state` para restaurar dados salvos.
    *   Comandos de shell básicos:
        *   `help` – mostra todos os comandos;
        *   `exit` – encerra o programa (após salvar, se for o caso).

---

## Comandos do shell

Formato geral:  
Todos os comandos são __strings terminadas em `\n`__, com as opções separadas por `-`.  
Exemplo: `comando-opcao1-opcao2-...`

O banner é impresso a cada linha:

opcode-shell>>

### Comandos básicos:

*   `help` – mostra a ajuda com todos os comandos suportados.
*   `exit` – encerra o programa (e pode salvar o estado, dependendo da implementação).

1.  __Cadastro e fechamento de contas__
    *   `conta_cadastrar-<CPF11>-<CONTA6>-<NOME>`  
        Cadastra um novo cliente.  
        `<CPF11>` – string numérica de 11 dígitos;  
        `<CONTA6>` – string numérica de 6 dígitos;  
        `<NOME>` – nome (até 32 caracteres).  
        Gera o DV de acordo com a regra do enunciado.  
        Mensagens seguem a especificação: CPF já cadastrado, conta em uso, formato inválido etc.  
        Exemplo: `conta_cadastrar-16512329031-765432-Jose Silva`
    *   `conta_fechar-<CONTA6>-<DV>`  
        Fecha a conta apenas se saldo corrente = 0; dívida de crédito = 0.  
        Caso contrário, retorna mensagens de erro informando saldo devedor / limite devido.  
        Em caso de sucesso, apaga o cliente e suas transações.
2.  __Pagamentos em débito/crédito e limite__
    *   `pagar_debito-<CONTA6>-<DV>-<VALORcentavos>`  
        Debita o valor do saldo da conta corrente.  
        Registra transação no ring de débito.  
        Se saldo insuficiente → mensagem de erro.
    *   `pagar_credito-<CONTA6>-<DV>-<VALORcentavos>`  
        Operação no cartão de crédito: aumenta a dívida, respeitando o limite.  
        Registra transação no ring de crédito.  
        Se limite insuficiente → mensagem de erro.
    *   `alterar_limite-<CONTA6>-<DV>-<NOVO_LIMcentavos>`  
        Ajusta o limite de crédito do cliente.  
        Se o novo limite for menor que a dívida atual, operação é negada.
    *   __Observação:__ os comandos transferir\_debito / transferir\_credito do enunciado não foram implementados. O sistema atende aos requisitos de movimentação via pagar\_debito, pagar\_credito, pagar\_fatura, sacar e depositar.
3.  __Pagamento de fatura__
    *   `pagar_fatura-<CONTA6>-<DV>-<VALORcentavos>-<METHOD>`  
        `<METHOD>` = S → paga usando o saldo da conta corrente (abate saldo + dívida).  
        `<METHOD>` = E → pagamento externo (só abate dívida).  
        Regras:  
        Se cliente não existir → mensagem "Falha: cliente inexistente".  
        Se valor > dívida → erro "Falha: valor fornecido maior que a divida do cartao".  
        Se método S e saldo insuficiente → "Falha: saldo insuficiente".
4.  __Saques e depósitos__
    *   `sacar-<CONTA6>-<DV>-<VALORcentavos>`  
        Decrementa o saldo da conta corrente.  
        Se saldo insuficiente ou conta inválida → mensagem de erro.  
        Registra a transação no ring de débito.
    *   `depositar-<CONTA6>-<DV>-<VALORcentavos>`  
        Incrementa o saldo da conta corrente.  
        Se conta não existir → mensagem de erro.  
        Registra a transação no ring de crédito.
5.  __Extratos e logs de transações__
    *   Dumps (debug dos buffers circulares)
        *   `dump_trans-deb-<CONTA6>-<DV>`
        *   `dump_trans-cred-<CONTA6>-<DV>`Imprimem os valores brutos das transações (em centavos), do mais antigo para o mais novo.
    *   Extratos (relatórios do enunciado)
        
        *   `debito_extrato-<CONTA6>-<DV>`
        *   `credito_extrato-<CONTA6>-<DV>`
        
        Cada extrato:  
        Lista as transações daquele tipo (débito ou crédito), com:  
        número da conta destino,  
        valor formatado em R$ X,YY,  
        data/hora da transação.  
        No extrato de crédito, também aparecem:  
        pagamentos de fatura;  
        incidências de juros (JUROS);  
        saldos atuais (limite, dívida, limite disponível).
6.  __Data e hora__
    *   `datetime_set-DD/MM/AAAA- HH:MM:SS`  
        Configura a data e hora do sistema de acordo com os parâmetros, validando dia/mês/ano/hora/min/seg.
    *   `datetime_show`  
        Mostra a data/hora atual (DD/MM/AAAA HH:MM:SS), após atualizar o relógio com tick\_datetime.
7.  __Juros automáticos__
    *   A cada 60 segundos (com base em curr\_sec), o sistema aplica:  
        juros = floor(divida\_atual / 100) (1%) na dívida do cartão;  
        registra a incidência no ring de crédito como transação do tipo “JUROS”.  
        Essa lógica é transparente ao usuário e aparece apenas no extrato de crédito.
8.  __Persistência e manutenção (salvar, recarregar, formatar)__
    *   Além da restauração automática ao iniciar (R10), o sistema expõe comandos de persistência manual (R11–R13):  
        `salvar`  
        Salva todo o estado atual (clientes, saldos, limites, dívidas, transações, data/hora) em opcode\_state.bin.  
        O arquivo é sobrescrito.  
        Útil para garantir que alterações recentes sejam gravadas explicitamente.
    *   `recarregar`  
        Lê o arquivo opcode\_state.bin e recarrega os dados salvos.  
        Descarta as modificações não salvas da execução atual.  
        Implementa exatamente o comportamento descrito no requisito: “Modificações não salvas serão perdidas e as informações salvas anteriormente recuperadas.”
    *   `formatar`  
        Apaga todas as informações da execução atual:  
        clientes, transações, saldos/dívidas/limites.  
        Não salva automaticamente no arquivo externo.  
        Para que a formatação seja persistida, é necessário chamar salvar depois.

### Roteiro de teste rápido

Cadastrar cliente:
conta\_cadastrar-12345678901-123456-Ana

Configurar data/hora:
datetime\_set-11/11/2025- 23:59:55

Ver relógio avançando:
datetime\_show
datetime\_show
datetime\_show

Testar crédito/débito + extratos:
pagar\_credito-123456-X-2000
pagar\_debito-123456-X-150

debito\_extrato-123456-X
credito\_extrato-123456-X

Testar pagamento de fatura:
pagar\_fatura-123456-X-150-S

Testar saque e depósito:
depositar-123456-X-10000
sacar-123456-X-5000
debito\_extrato-123456-X

Persistência:
salvar
formatar
recarregar   # deve voltar aos dados salvos

Encerrar conta (depois de zerar saldo e dívida):
conta\_fechar-123456-X

### Troubleshooting

*   __“Comando invalido”__  
    Comando digitado errado, DV errado, ou número de opções diferente do esperado.
*   __Relógio não muda__  
    Verifique se datetime\_set foi chamado pelo menos uma vez.
*   __Dados não voltam após recarregar__  
    Confirme se salvar foi chamado antes, e se opcode\_state.bin está no mesmo diretório do MARS.
*   __Não consigo fechar conta__  
    Use os extratos para checar se saldo/dívida estão realmente zerados.
