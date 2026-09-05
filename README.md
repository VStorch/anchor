# Anchor

Aplicativo de gerenciamento de dinheiro com foco em despesas. Você cadastra de onde o dinheiro vem
(salário e benefícios, cada um com seu calendário de recebimento) e para onde ele vai (despesas
recorrentes, parceladas ou avulsas), e o app mostra quanto entrou, quanto já foi pago e quanto ainda
falta pagar no mês.

## Principais recursos

- **Três tipos de despesa**: recorrente (sem prazo), parcelada e avulsa.
- **Parcelamentos já em andamento**: informe o total de parcelas e quantas já foram quitadas — o app
  continua a contagem de onde você parou.
- **Valor por mês**: a conta de luz ou o mercado podem custar diferente neste mês sem mexer no cadastro.
- **Pagamento dividido**: a mesma despesa pode ser paga em partes, cada uma de uma carteira — R$ 400 no
  vale mercado e R$ 200 no salário, por exemplo.
- **Carteiras**: salário e benefícios (vale refeição, vale mercado...), cada um com um calendário
  próprio de recebimento (por exemplo, uma parte no dia 5 e outra no dia 20).
- **Calendário por dia útil**: o recebimento pode ser marcado como "5º dia útil" em vez de um dia fixo.
- **Gasto avulso**: o dia a dia que consome o vale (mercado, almoço, farmácia) entra direto na
  carteira, sem virar despesa cadastrada — toque em "Gasto" no cartão dela.
- **Saldo ajustável**: toque no saldo da carteira e informe quanto ela tem de verdade — útil para
  começar a usar o app com o dinheiro que você já tinha. Só a diferença é lançada, como ajuste.
- **Entradas previstas**: a cada data que passa o valor entra na carteira sozinho, marcado como
  previsto; você confirma com o dia e o valor que caíram de verdade.
- **Movimentações do mês**: tudo que entrou e saiu de cada carteira numa lista só — entradas,
  pagamentos de contas e gastos avulsos.
- **Resumo do mês**: o saldo que você tem de verdade em destaque e, abaixo, o que entrou, o que saiu
  e o que sobrou no mês — os três medidos pelo que aconteceu, não pelo previsto.
- **Tabela do mês**: as despesas em grade, com valor e pago editáveis na própria célula.
- **Agenda do mês**: entradas e vencimentos organizados por dia.
- **Tema**: claro, escuro ou padrão do sistema, em tons de verde.

## Rodando o projeto

```bash
flutter pub get
flutter run
```

A build Android precisa do JDK 21 (o Gradle 8.12 não aceita o Java 25 que vem com o Android Studio):

```bash
flutter config --jdk-dir=/usr/lib/jvm/java-21-openjdk-amd64
flutter build apk
```

## Testes

```bash
flutter test
```

## Arquitetura

MVVM com organização feature-first. Cada feature em `lib/features/<nome>/` tem `models/`,
`repositories/`, `viewmodels/` e `views/`. A feature `budget/` concentra o cálculo do resumo mensal
consumido por todas as telas, e `core/` guarda banco de dados, estado compartilhado, utilitários e
widgets reaproveitados.
