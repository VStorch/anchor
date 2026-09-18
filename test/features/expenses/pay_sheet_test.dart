import 'package:anchor/core/utils/month.dart';
import 'package:anchor/features/expenses/models/expense.dart';
import 'package:anchor/features/expenses/models/expense_type.dart';
import 'package:anchor/features/expenses/views/widgets/pay_sheet.dart';
import 'package:anchor/features/wallets/models/wallet.dart';
import 'package:anchor/features/wallets/models/wallet_kind.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  const september = Month(2026, 9);
  final salary = Wallet(
    id: 1,
    name: 'Salário',
    kind: WalletKind.salary,
    colorIndex: 0,
    createdAt: DateTime(2026, 9),
  );

  setUpAll(() => initializeDateFormatting('pt_BR'));

  Expense expense({ExpenseType type = ExpenseType.recurring, int? cardId}) =>
      Expense(
        id: 1,
        name: 'Luz',
        type: type,
        amount: 140,
        dueDay: 10,
        startMonth: september,
        totalInstallments: type == ExpenseType.installment ? 5 : null,
        walletId: 1,
        cardId: cardId,
        purchasedAt: cardId == null ? null : DateTime(2026, 8, 20),
        createdAt: DateTime(2026, 9),
      );

  Future<void> payLess(WidgetTester tester, Expense expense) async {
    final occurrence = expense.occurrenceIn(
      september,
      today: DateTime(2026, 9, 16),
    )!;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => PaySheet.show(
                context,
                title: 'Pagar Luz',
                wallets: [salary],
                origin: (walletId: 1, outside: false),
                paidAt: DateTime(2026, 9, 16),
                amount: occurrence.remaining,
                payable: occurrence,
              ),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '137,52');
    await tester.pumpAndSettle();
  }

  final question = find.textContaining('A conta deste mês foi');

  testWidgets('a conta de todo mês paga a menos pergunta se ela foi menor', (
    tester,
  ) async {
    await payLess(tester, expense());
    expect(question, findsOneWidget);
  });

  testWidgets('a compra no cartão paga a menos é só uma parte', (tester) async {
    await payLess(tester, expense(type: ExpenseType.single, cardId: 7));
    expect(question, findsNothing);
  });

  testWidgets('a parcela paga a menos é só uma parte', (tester) async {
    await payLess(tester, expense(type: ExpenseType.installment));
    expect(question, findsNothing);
  });
}
