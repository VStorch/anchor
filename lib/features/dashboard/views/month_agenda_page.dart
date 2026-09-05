import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/money.dart';
import '../../../core/utils/month.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/month_switcher.dart';
import '../../budget/models/budget_snapshot.dart';
import '../../expenses/models/expense_occurrence.dart';
import '../../wallets/models/payout.dart';
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

class _AgendaIncome {
  const _AgendaIncome({required this.wallet, required this.payout});

  final Wallet wallet;
  final Payout payout;
}

class _AgendaDay {
  const _AgendaDay({
    required this.date,
    required this.incomes,
    required this.expenses,
  });

  static List<_AgendaDay> buildMonth(Month month, BudgetSnapshot snapshot) {
    final days = <_AgendaDay>[];

    for (var day = 1; day <= month.lengthInDays; day++) {
      final incomes = <_AgendaIncome>[];
      for (final wallet in snapshot.wallets) {
        for (final payout in wallet.payouts) {
          if (payout.day == day) {
            incomes.add(_AgendaIncome(wallet: wallet, payout: payout));
          }
        }
      }

      final expenses = snapshot.summary.occurrences
          .where((occurrence) => occurrence.dueDate.day == day)
          .toList();

      if (incomes.isEmpty && expenses.isEmpty) continue;
      days.add(
        _AgendaDay(
          date: month.dayOf(day),
          incomes: incomes,
          expenses: expenses,
        ),
      );
    }

    return days;
  }

  final DateTime date;
  final List<_AgendaIncome> incomes;
  final List<ExpenseOccurrence> expenses;

  double get totalIn =>
      incomes.fold(0, (total, income) => total + income.payout.amount);

  double get totalOut =>
      expenses.fold(0, (total, expense) => total + expense.amount);
}

class _AgendaDayTile extends StatelessWidget {
  const _AgendaDayTile({required this.day});

  final _AgendaDay day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isToday = DateUtils.isSameDay(day.date, DateTime.now());

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 44,
                height: 44,
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
                  children: [
                    ...day.incomes.map(
                      (income) => _AgendaLine(
                        icon: Icons.arrow_downward,
                        color: income.wallet.color,
                        title: '${income.wallet.name} · ${income.payout.label}',
                        amount: formatMoney(income.payout.amount),
                      ),
                    ),
                    ...day.expenses.map(
                      (occurrence) => _AgendaLine(
                        icon: occurrence.isPaid
                            ? Icons.check_circle_outline
                            : Icons.arrow_upward,
                        color: occurrence.isPaid
                            ? theme.colorScheme.primary
                            : theme.colorScheme.error,
                        title: occurrence.expense.name,
                        amount: formatMoney(occurrence.amount),
                      ),
                    ),
                  ],
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
  const _AgendaLine({
    required this.icon,
    required this.color,
    required this.title,
    required this.amount,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String amount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Text(
            amount,
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
