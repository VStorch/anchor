import 'package:anchor/core/database/app_database.dart';
import 'package:anchor/core/state/data_changes.dart';
import 'package:anchor/core/utils/month.dart';
import 'package:anchor/features/cards/models/credit_card.dart';
import 'package:anchor/features/cards/repositories/card_repository.dart';
import 'package:anchor/features/expenses/models/expense.dart';
import 'package:anchor/features/expenses/models/expense_payment.dart';
import 'package:anchor/features/expenses/models/expense_type.dart';
import 'package:anchor/features/expenses/repositories/expense_repository.dart';
import 'package:anchor/features/expenses/viewmodels/expense_form_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../support/test_database.dart';

void main() {
  late AppDatabase database;
  late ExpenseRepository repository;

  const august = Month(2026, 8);

  final gym = Expense(
    id: 1,
    name: 'Academia',
    type: ExpenseType.recurring,
    amount: 120,
    dueDay: 10,
    startMonth: august,
    endMonth: const Month(2026, 9),
    createdAt: DateTime(2026, 8),
  );

  ExpensePayment paidIn(Month month) => ExpensePayment(
    expenseId: 1,
    month: month,
    amount: 120,
    paidAt: month.dayOf(10),
    settledOutside: true,
  );

  setUpAll(() => initializeDateFormatting('pt_BR'));

  setUp(() {
    database = createInMemoryDatabase();
    repository = ExpenseRepository(database, DataChanges());
  });

  tearDown(() => database.close());

  ExpenseFormViewModel edit(List<ExpensePayment> payments) =>
      ExpenseFormViewModel(
        repository: repository,
        referenceMonth: august,
        expense: gym,
        payments: payments,
      );

  group('prévia da parcela', () {
    ExpenseFormViewModel installment({required Month reference}) =>
        ExpenseFormViewModel(
            repository: repository,
            referenceMonth: reference,
            now: DateTime(2026, 9, 15),
          )
          ..setType(ExpenseType.installment)
          ..setTotalInstallments(10)
          ..setSettledInstallments(3)
          ..setStartMonth(const Month(2026, 9));

    test('diz qual parcela o mês na tela recebe', () {
      final form = installment(reference: const Month(2026, 9));
      expect(
        form.installmentPreview,
        'Setembro de 2026 será a parcela 4 de 10',
      );

      final later = installment(reference: const Month(2026, 11));
      expect(
        later.installmentPreview,
        'Novembro de 2026 será a parcela 6 de 10',
      );
    });

    test('quando começa depois, diz quando vence a próxima', () {
      final form = installment(reference: august);
      expect(
        form.installmentPreview,
        'A parcela 4 de 10 vence em setembro de 2026',
      );
    });

    test('depois da última parcela, diz quando ela vence', () {
      final form = installment(reference: const Month(2027, 6));
      expect(
        form.installmentPreview,
        'A última parcela vence em março de 2027',
      );
    });

    test('só existe para a parcelada', () {
      final form = installment(reference: august)
        ..setType(ExpenseType.recurring);
      expect(form.installmentPreview, isNull);
    });
  });

  test('a despesa nova só salva depois de escolher o dia', () async {
    final form =
        ExpenseFormViewModel(
            repository: repository,
            referenceMonth: august,
            now: DateTime(2026, 8, 3),
          )
          ..setName('Internet')
          ..setAmount(99.9);

    expect(form.dueDay, isNull);
    expect(form.needsDueDay, isTrue);
    expect(form.isValid, isFalse);
    await form.save();
    expect(await repository.fetchExpenses(), isEmpty);

    form.setDueDay(15);
    expect(form.isValid, isTrue);
    await form.save();
    expect((await repository.fetchExpenses()).single.dueDay, 15);
  });

  test('a compra no cartão não pede o dia do vencimento', () {
    final form = ExpenseFormViewModel(
      repository: repository,
      referenceMonth: august,
      cards: [
        CreditCard(
          id: 7,
          name: 'Nubank',
          closingDay: 3,
          dueDay: 10,
          createdAt: DateTime(2026),
        ),
      ],
      now: DateTime(2026, 8, 3),
    )..setSource((walletId: null, cardId: 7));

    expect(form.needsDueDay, isFalse);
  });

  test('o fim antes do início invalida o formulário', () {
    final form = edit(const [])..setStartMonth(const Month(2026, 10));

    expect(form.endsBeforeStart, isTrue);
    expect(form.isValid, isFalse);

    form.setEndMonth(null);
    expect(form.endsBeforeStart, isFalse);
    expect(form.isValid, isTrue);
  });

  test('trocar para outro tipo limpa o mês final', () {
    final form = edit(const [])..setType(ExpenseType.single);

    expect(form.endMonth, isNull);
    expect(form.endsBeforeStart, isFalse);
  });

  test('conta só os meses pagos que a mudança deixa de fora', () {
    final form = edit([
      paidIn(august),
      paidIn(const Month(2026, 9)),
      paidIn(const Month(2026, 10)),
    ]);

    expect(form.monthsLeftOffRule, isEmpty);

    form.setEndMonth(august);
    expect(form.monthsLeftOffRule, {const Month(2026, 9)});
  });

  group('compra no cartão', () {
    const september = Month(2026, 9);
    const october = Month(2026, 10);
    final today = DateTime(2026, 9, 14, 9, 30);

    late CreditCard card;

    setUp(() async {
      final id = await CardRepository(database, DataChanges()).saveCard(
        CreditCard(
          name: 'Nubank',
          closingDay: 3,
          dueDay: 10,
          createdAt: DateTime(2026, 9),
        ),
      );
      card = (await CardRepository(
        database,
        DataChanges(),
      ).fetchCards()).singleWhere((card) => card.id == id);
    });

    ExpenseFormViewModel purchaseFrom(Month invoiceMonth) =>
        ExpenseFormViewModel(
            repository: repository,
            referenceMonth: invoiceMonth,
            cards: [card],
            card: card,
            invoiceMonth: invoiceMonth,
            now: today,
          )
          ..setName('Tênis')
          ..setAmount(200);

    test('a compra nova já vem com a data de hoje', () {
      final form = purchaseFrom(october);

      expect(form.purchasedAt, DateTime(2026, 9, 14));
      expect(form.invoiceMonth, october);
      expect(form.leavesOpenedInvoice, isFalse);
    });

    test(
      'a compra de 13/09 aberta na fatura de setembro vai para outubro',
      () async {
        final form = purchaseFrom(september)
          ..setPurchasedAt(DateTime(2026, 9, 13));

        expect(form.invoiceMonth, october);
        expect(form.startMonth, october);
        expect(form.leavesOpenedInvoice, isTrue);

        await form.save();

        final saved = (await repository.fetchExpenses()).single;
        expect(saved.startMonth, october);
        expect(saved.purchasedAt, DateTime(2026, 9, 13));
        expect(saved.cardId, card.id);
      },
    );

    test('a parcelada começa na fatura da compra mais as parcelas pagas', () {
      final form = purchaseFrom(september)
        ..setType(ExpenseType.installment)
        ..setTotalInstallments(10)
        ..setSettledInstallments(2)
        ..setPurchasedAt(DateTime(2026, 9, 2));

      expect(form.invoiceMonth, september);
      expect(form.startMonth, const Month(2026, 11));
      expect(form.leavesOpenedInvoice, isFalse);
    });

    test('a compra antiga sem data mantém o mês até escolherem uma', () {
      final legacy = Expense(
        id: 9,
        name: 'Fone',
        type: ExpenseType.single,
        amount: 90,
        dueDay: 10,
        startMonth: const Month(2026, 7),
        cardId: card.id,
        createdAt: DateTime(2026, 7),
      );
      final form = ExpenseFormViewModel(
        repository: repository,
        referenceMonth: september,
        expense: legacy,
        cards: [card],
        now: today,
      );

      expect(form.purchasedAt, isNull);
      expect(form.invoiceMonth, isNull);

      form.setStartMonth(const Month(2026, 8));
      expect(form.startMonth, const Month(2026, 8));

      form.setPurchasedAt(DateTime(2026, 7, 20));
      expect(form.startMonth, const Month(2026, 8));
      expect(form.invoiceMonth, const Month(2026, 8));
    });

    test('sem cartão a data da compra não é gravada', () async {
      final form =
          ExpenseFormViewModel(
              repository: repository,
              referenceMonth: september,
              now: today,
            )
            ..setName('Luz')
            ..setAmount(150)
            ..setDueDay(10);

      await form.save();

      expect((await repository.fetchExpenses()).single.purchasedAt, isNull);
    });
  });
}
