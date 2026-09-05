import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/money.dart';
import '../../../core/utils/month.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/month_switcher.dart';
import '../../budget/models/budget_snapshot.dart';
import '../../wallets/models/wallet.dart';
import '../viewmodels/dashboard_view_model.dart';

class MonthAgendaPage extends StatelessWidget {
  const MonthAgendaPage({super.key});

  static Future<void> open(BuildContext context) {
    final viewModel = context.read<DashboardViewModel>();

    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChangeNotifierProvider.value(
          value: viewModel,
          child: const MonthAgendaPage(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<DashboardViewModel>();
    final days = _AgendaDay.buildMonth(viewModel.month, viewModel.snapshot);

    return Scaffold(
      appBar: AppBar(title: const Text('Agenda do mês')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: MonthSwitcher(
              month: viewModel.month,
              onPrevious: viewModel.goToPreviousMonth,
              onNext: viewModel.goToNextMonth,
              onToday: viewModel.goToCurrentMonth,
            ),
          ),
          Expanded(
            child: days.isEmpty
                ? const EmptyState(
                    icon: Icons.event_note_outlined,
                    title: 'Mês sem movimentos',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    itemCount: days.length,
                    itemBuilder: (context, index) =>
                        _AgendaDayTile(day: days[index]),
                  ),
          ),
        ],
      ),
    );
  }
}

enum _EntryKind { income, expectedIncome, bill, paidBill, spending }

class _AgendaEntry {
  const _AgendaEntry({
    required this.day,
    required this.title,
    required this.amount,
    required this.kind,
    this.wallet,
  });

  final int day;
  final String title;
  final double amount;
  final _EntryKind kind;
  final Wallet? wallet;

  IconData get icon => switch (kind) {
    _EntryKind.income => Icons.arrow_downward,
    _EntryKind.expectedIncome => Icons.schedule,
    _EntryKind.bill => Icons.arrow_upward,
    _EntryKind.paidBill => Icons.check_circle_outline,
    _EntryKind.spending => Icons.shopping_bag_outlined,
  };

  Color colorOf(ColorScheme colors) => switch (kind) {
    _EntryKind.income ||
    _EntryKind.expectedIncome => wallet?.color ?? colors.primary,
    _EntryKind.bill => colors.error,
    _EntryKind.paidBill => colors.primary,
    _EntryKind.spending => colors.onSurfaceVariant,
  };
}

class _AgendaDay {
  const _AgendaDay({required this.date, required this.entries});

  static List<_AgendaDay> buildMonth(Month month, BudgetSnapshot snapshot) {
    final entries = <_AgendaEntry>[
      ..._incomes(month, snapshot),
      for (final occurrence in snapshot.summary.occurrences)
        _AgendaEntry(
          day: occurrence.dueDate.day,
          title: occurrence.expense.name,
          amount: occurrence.amount,
          kind: occurrence.isPaid ? _EntryKind.paidBill : _EntryKind.bill,
        ),
      for (final outflow in snapshot.summary.outflows)
        _AgendaEntry(
          day: outflow.spentAt.day,
          title: outflow.label,
          amount: outflow.amount,
          kind: _EntryKind.spending,
          wallet: snapshot.walletById(outflow.walletId),
        ),
    ];

    final days = <_AgendaDay>[];
    for (var day = 1; day <= month.lengthInDays; day++) {
      final ofDay = entries.where((entry) => entry.day == day).toList();
      if (ofDay.isEmpty) continue;
      days.add(_AgendaDay(date: month.dayOf(day), entries: ofDay));
    }
    return days;
  }

  static List<_AgendaEntry> _incomes(Month month, BudgetSnapshot snapshot) {
    final monthReceipts = snapshot.receipts
        .where((receipt) => receipt.month == month)
        .toList();

    return <_AgendaEntry>[
      for (final receipt in monthReceipts)
        if (receipt.counts && !receipt.isAdjustment)
          _AgendaEntry(
            day: receipt.receivedAt.day,
            title: _incomeTitle(receipt.payoutId, snapshot),
            amount: receipt.amount,
            kind: receipt.isPredicted
                ? _EntryKind.expectedIncome
                : _EntryKind.income,
            wallet: snapshot.walletById(receipt.walletId),
          ),
      for (final wallet in snapshot.wallets)
        for (final payout in wallet.payouts)
          if (!monthReceipts.any((receipt) => receipt.payoutId == payout.id))
            _AgendaEntry(
              day: payout.dateIn(month).day,
              title: payout.label,
              amount: payout.amount,
              kind: _EntryKind.expectedIncome,
              wallet: wallet,
            ),
    ];
  }

  static String _incomeTitle(int? payoutId, BudgetSnapshot snapshot) {
    if (payoutId == null) return 'Entrada';

    for (final wallet in snapshot.wallets) {
      for (final payout in wallet.payouts) {
        if (payout.id == payoutId) return payout.label;
      }
    }
    return 'Entrada';
  }

  final DateTime date;
  final List<_AgendaEntry> entries;
}

class _AgendaDayTile extends StatelessWidget {
  const _AgendaDayTile({required this.day});

  final _AgendaDay day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isToday = DateUtils.isSameDay(day.date, DateTime.now());
    final side = MediaQuery.textScalerOf(context).scale(44).clamp(44.0, 58.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: side,
                height: side,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isToday
                      ? theme.colorScheme.primary
                      : theme.colorScheme.surfaceContainerHighest,
                ),
                child: Text(
                  '${day.date.day}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isToday
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat.E('pt_BR').format(day.date).replaceAll('.', ''),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: day.entries
                      .map((entry) => _AgendaLine(entry: entry))
                      .toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AgendaLine extends StatelessWidget {
  const _AgendaLine({required this.entry});

  final _AgendaEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = entry.colorOf(theme.colorScheme);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(entry.icon, size: 16, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              entry.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Text(
            formatMoney(entry.amount),
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
