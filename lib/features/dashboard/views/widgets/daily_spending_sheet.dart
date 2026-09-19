import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/money.dart';
import '../../../../core/utils/month.dart';
import '../../../../core/widgets/money_field.dart';
import '../../../budget/models/outflow_average.dart';
import '../../../wallets/models/wallet.dart';

/// The reserve the sheet settled on; a null [amount] means no reserve.
class ReserveEdit {
  const ReserveEdit({required this.wallet, required this.amount});

  final Wallet wallet;
  final double? amount;
}

/// "Reserva do dia a dia": the everyday spending a
/// salary sets aside in the forecast.
class DailySpendingSheet extends StatefulWidget {
  const DailySpendingSheet({
    super.key,
    required this.salaries,
    required this.averageOf,
    this.initial,
  });

  static Future<ReserveEdit?> show(
    BuildContext context, {
    required List<Wallet> salaries,
    required OutflowAverage? Function(Wallet) averageOf,
    Wallet? initial,
  }) {
    return showModalBottomSheet<ReserveEdit>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => DailySpendingSheet(
        salaries: salaries,
        averageOf: averageOf,
        initial: initial,
      ),
    );
  }

  final List<Wallet> salaries;
  final OutflowAverage? Function(Wallet) averageOf;
  final Wallet? initial;

  @override
  State<DailySpendingSheet> createState() => _DailySpendingSheetState();
}

class _DailySpendingSheetState extends State<DailySpendingSheet> {
  late Wallet _wallet = widget.initial ?? _firstWithReserve();
  late double _amount = _wallet.monthlyReserve ?? 0;
  int _fieldVersion = 0;

  Wallet _firstWithReserve() => widget.salaries.firstWhere(
    (wallet) => wallet.monthlyReserve != null,
    orElse: () => widget.salaries.first,
  );

  void _pickWallet(Wallet wallet) => setState(() {
    _wallet = wallet;
    _amount = wallet.monthlyReserve ?? 0;
    _fieldVersion++;
  });

  void _useAverage(OutflowAverage average) => setState(() {
    _amount = average.amount;
    _fieldVersion++;
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final average = widget.averageOf(_wallet);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Reserva do dia a dia',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (widget.salaries.length > 1) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<Wallet>(
                value: _wallet,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Sai de'),
                items: [
                  for (final wallet in widget.salaries)
                    DropdownMenuItem<Wallet>(
                      value: wallet,
                      child: Text(wallet.name, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (wallet) {
                  if (wallet != null) _pickWallet(wallet);
                },
              ),
            ],
            const SizedBox(height: 16),
            MoneyField(
              key: ValueKey<int>(_fieldVersion),
              initialValue: _amount,
              label: 'Por mês',
              hint: 'Mercado, transporte, lanche',
              onChanged: (value) => _amount = value,
            ),
            if (average != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: ActionChip(
                  avatar: const Icon(Icons.auto_graph, size: 18),
                  label: Text(
                    'Usar a média: ${formatMoney(average.amount)} '
                    '(${_rangeOf(average)})',
                  ),
                  onPressed: () => _useAverage(average),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(
                      context,
                      ReserveEdit(
                        wallet: _wallet,
                        amount: _amount > 0 ? _amount : null,
                      ),
                    ),
                    child: const Text('Salvar reserva'),
                  ),
                ),
              ],
            ),
            if (_wallet.monthlyReserve != null)
              TextButton(
                onPressed: () => Navigator.pop(
                  context,
                  ReserveEdit(wallet: _wallet, amount: null),
                ),
                child: const Text('Não usar reserva'),
              ),
          ],
        ),
      ),
    );
  }

  static String _rangeOf(OutflowAverage average) {
    String short(Month month) =>
        DateFormat.MMM('pt_BR').format(month.firstDay).replaceAll('.', '');
    if (average.from == average.to) return short(average.to);
    return '${short(average.from)}–${short(average.to)}';
  }
}
