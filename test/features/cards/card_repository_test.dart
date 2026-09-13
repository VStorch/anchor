import 'package:anchor/core/database/app_database.dart';
import 'package:anchor/core/state/data_changes.dart';
import 'package:anchor/core/utils/month.dart';
import 'package:anchor/features/cards/models/credit_card.dart';
import 'package:anchor/features/cards/repositories/card_repository.dart';
import 'package:anchor/features/expenses/models/expense.dart';
import 'package:anchor/features/expenses/models/expense_type.dart';
import 'package:anchor/features/expenses/repositories/expense_repository.dart';
import 'package:anchor/features/wallets/models/wallet.dart';
import 'package:anchor/features/wallets/models/wallet_kind.dart';
import 'package:anchor/features/wallets/repositories/wallet_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  late AppDatabase database;
  late CardRepository cards;
  late ExpenseRepository expenses;
  late int salaryId;
  late int voucherId;

  setUp(() async {
    database = createInMemoryDatabase();
    final changes = DataChanges();
    cards = CardRepository(database, changes);
    expenses = ExpenseRepository(database, changes);
    final wallets = WalletRepository(database, changes);
    Future<int> wallet(String name) => wallets.saveWallet(
      Wallet(
        name: name,
        kind: WalletKind.salary,
        colorIndex: 0,
        createdAt: DateTime(2026, 9),
      ),
    );
    salaryId = await wallet('Salário');
    voucherId = await wallet('Extra');
  });

  tearDown(() => database.close());

  Future<int> seedCardWithPurchase() async {
    final cardId = await cards.saveCard(
      CreditCard(
        name: 'Nubank',
        closingDay: 3,
        dueDay: 10,
        walletId: salaryId,
        createdAt: DateTime(2026, 9),
      ),
    );
    await expenses.saveExpense(
      Expense(
        name: 'Geladeira',
        type: ExpenseType.installment,
        amount: 300,
        dueDay: 10,
        startMonth: const Month(2026, 9),
        totalInstallments: 10,
        walletId: salaryId,
        cardId: cardId,
        createdAt: DateTime(2026, 9),
      ),
    );
    return cardId;
  }

  test(
    'mudar o vencimento e a carteira do cartão muda as compras dele',
    () async {
      final cardId = await seedCardWithPurchase();
      final card = (await cards.fetchCards()).single;

      await cards.saveCard(
        CreditCard(
          id: cardId,
          name: card.name,
          closingDay: card.closingDay,
          dueDay: 17,
          walletId: voucherId,
          createdAt: card.createdAt,
        ),
      );

      final purchase = (await expenses.fetchExpenses()).single;
      expect(purchase.dueDay, 17);
      expect(purchase.walletId, voucherId);
    },
  );

  test('excluir o cartão mantém as compras como despesas soltas', () async {
    final cardId = await seedCardWithPurchase();

    await cards.deleteCard(cardId);

    final purchase = (await expenses.fetchExpenses()).single;
    expect(await cards.fetchCards(), isEmpty);
    expect(purchase.name, 'Geladeira');
    expect(purchase.cardId, isNull);
  });
}
