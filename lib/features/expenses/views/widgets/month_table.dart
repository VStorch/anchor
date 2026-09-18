import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../core/widgets/fab_clearance.dart';
import '../../../../core/utils/money.dart';
import '../../models/expense_occurrence.dart';

enum MonthTableCell { amount, paid }

class MonthTable extends StatefulWidget {
  const MonthTable({
    super.key,
    required this.occurrences,
    required this.onOpen,
    required this.onAmountChanged,
    required this.onPaidChanged,
  });

  /// What the expense name keeps when the screen is narrow.
  static const double _minNameWidth = 100;

  static const double _remainingWidth = 84;

  final List<ExpenseOccurrence> occurrences;
  final ValueChanged<ExpenseOccurrence> onOpen;
  final void Function(ExpenseOccurrence occurrence, double amount)
  onAmountChanged;
  final void Function(ExpenseOccurrence occurrence, double amount)
  onPaidChanged;

  @override
  State<MonthTable> createState() => _MonthTableState();
}

class _MonthTableState extends State<MonthTable> {
  int? _editingExpenseId;
  MonthTableCell? _editingCell;

  static const EdgeInsets _sidePadding = EdgeInsets.symmetric(horizontal: 12);

  /// Grows with the font, so an amount being typed at a large text size
  /// keeps its first digits inside the cell.
  double _amountColumnWidth(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(88);

  @override
  Widget build(BuildContext context) {
    final amount = _amountColumnWidth(context);
    final columns = <int, TableColumnWidth>{
      0: const FlexColumnWidth(),
      1: FixedColumnWidth(amount),
      2: FixedColumnWidth(amount),
      3: const FixedColumnWidth(MonthTable._remainingWidth),
    };
    final minWidth =
        MonthTable._minNameWidth +
        amount * 2 +
        MonthTable._remainingWidth +
        _sidePadding.horizontal;

    return _layout(context, columns, minWidth);
  }

  /// The total stays on screen as a footer: it scrolls sideways with the
  /// table, being inside the same horizontal scroll, but never vertically.
  Widget _layout(
    BuildContext context,
    Map<int, TableColumnWidth> columns,
    double minWidth,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: max(constraints.maxWidth, minWidth),
          height: constraints.maxHeight,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: _sidePadding.copyWith(top: 4, bottom: 8),
                  child: Table(
                    columnWidths: columns,
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    children: [
                      _headerRow(context),
                      ...widget.occurrences.map((o) => _row(context, o)),
                    ],
                  ),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border(
                    top: BorderSide(color: Theme.of(context).dividerColor),
                  ),
                ),
                child: Padding(
                  padding: _sidePadding,
                  child: Table(
                    columnWidths: columns,
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    children: [_totalsRow(context)],
                  ),
                ),
              ),
              SizedBox(height: fabClearance(context)),
            ],
          ),
        ),
      ),
    );
  }

  TableRow _headerRow(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w700,
    );

    return TableRow(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.6)),
        ),
      ),
      children: [
        _pad(Text('Despesa', style: style)),
        _pad(Text('Valor (R\$)', style: style, textAlign: TextAlign.end)),
        _pad(Text('Pago (R\$)', style: style, textAlign: TextAlign.end)),
        _pad(Text('Falta (R\$)', style: style, textAlign: TextAlign.end)),
      ],
    );
  }

  TableRow _row(BuildContext context, ExpenseOccurrence occurrence) {
    final theme = Theme.of(context);

    return TableRow(
      children: [
        _pad(
          InkWell(
            onTap: () => widget.onOpen(occurrence),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  occurrence.expense.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'dia ${occurrence.dueDate.day}'
                  '${occurrence.installmentLabel != null ? ' · ${occurrence.installmentLabel}' : ''}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        _valueCell(
          context,
          occurrence: occurrence,
          cell: MonthTableCell.amount,
          value: occurrence.amount,
          color: occurrence.hasCustomAmount
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurface,
        ),
        _valueCell(
          context,
          occurrence: occurrence,
          cell: MonthTableCell.paid,
          value: occurrence.paidAmount,
          color: theme.colorScheme.onSurface,
        ),
        _pad(
          Text(
            occurrence.remaining <= 0
                ? '—'
                : formatAmount(occurrence.remaining),
            textAlign: TextAlign.end,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: occurrence.remaining <= 0
                  ? theme.colorScheme.onSurfaceVariant
                  : theme.colorScheme.error,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  TableRow _totalsRow(BuildContext context) {
    final theme = Theme.of(context);
    final occurrences = widget.occurrences;
    final style = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w800,
    );

    return TableRow(
      children: [
        _pad(Text('Total', style: style)),
        _pad(
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(formatAmount(occurrences.totalAmount), style: style),
          ),
        ),
        _pad(
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(formatAmount(occurrences.totalPaid), style: style),
          ),
        ),
        _pad(
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(formatAmount(occurrences.totalRemaining), style: style),
          ),
        ),
      ],
    );
  }

  Widget _valueCell(
    BuildContext context, {
    required ExpenseOccurrence occurrence,
    required MonthTableCell cell,
    required double value,
    required Color color,
  }) {
    final theme = Theme.of(context);
    final isEditing =
        _editingExpenseId == occurrence.expense.id && _editingCell == cell;

    if (isEditing) {
      return _pad(
        _CellField(
          initialValue: value,
          onSubmitted: (amount) {
            setState(() {
              _editingExpenseId = null;
              _editingCell = null;
            });
            if (cell == MonthTableCell.amount) {
              widget.onAmountChanged(occurrence, amount);
            } else {
              widget.onPaidChanged(occurrence, amount);
            }
          },
        ),
      );
    }

    return _pad(
      InkWell(
        onTap: () => _startEditing(occurrence, cell),
        child: Text(
          value <= 0 ? '—' : formatAmount(value),
          textAlign: TextAlign.end,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: value <= 0 ? theme.colorScheme.onSurfaceVariant : color,
          ),
        ),
      ),
    );
  }

  void _startEditing(ExpenseOccurrence occurrence, MonthTableCell cell) {
    if (cell == MonthTableCell.paid && occurrence.payments.length > 1) {
      widget.onOpen(occurrence);
      return;
    }

    setState(() {
      _editingExpenseId = occurrence.expense.id;
      _editingCell = cell;
    });
  }

  Widget _pad(Widget child) =>
      Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: child);
}

class _CellField extends StatefulWidget {
  const _CellField({required this.initialValue, required this.onSubmitted});

  final double initialValue;
  final ValueChanged<double> onSubmitted;

  @override
  State<_CellField> createState() => _CellFieldState();
}

class _CellFieldState extends State<_CellField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue > 0
        ? formatMoneyInput(widget.initialValue, symbol: false)
        : '',
  );
  final FocusNode _focusNode = FocusNode();
  bool _isSubmitted = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) _submit();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final editing = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.6),
    );

    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      autofocus: true,
      textAlign: TextAlign.end,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: const [MoneyInputFormatter(symbol: false)],
      style: theme.textTheme.bodyMedium,
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        border: editing,
        enabledBorder: editing,
        focusedBorder: editing,
      ),
      onSubmitted: (_) => _submit(),
    );
  }

  void _submit() {
    if (_isSubmitted) return;
    _isSubmitted = true;
    widget.onSubmitted(parseMoney(_controller.text));
  }
}
