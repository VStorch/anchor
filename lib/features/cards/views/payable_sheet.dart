import 'package:flutter/widgets.dart';

import '../../expenses/models/expense_occurrence.dart';
import '../../expenses/models/payable.dart';
import '../../expenses/views/widgets/expense_ledger_sheet.dart';
import '../models/card_invoice.dart';
import 'card_invoice_sheet.dart';

Future<void> showPayableSheet(BuildContext context, Payable payable) =>
    switch (payable) {
      CardInvoice invoice => CardInvoiceSheet.show(
        context,
        cardId: invoice.card.id!,
        month: invoice.month,
      ),
      ExpenseOccurrence occurrence => ExpenseLedgerSheet.show(
        context,
        occurrence: occurrence,
      ),
      _ => Future<void>.value(),
    };
