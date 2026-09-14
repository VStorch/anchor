import '../../../core/utils/month.dart';
import 'expense_occurrence.dart';
import 'expense_type.dart';

class Expense {
  const Expense({
    this.id,
    required this.name,
    required this.type,
    required this.amount,
    required this.dueDay,
    required this.startMonth,
    this.endMonth,
    this.totalInstallments,
    this.settledInstallments = 0,
    this.walletId,
    this.cardId,
    required this.createdAt,
  });

  factory Expense.fromMap(Map<String, Object?> map) => Expense(
    id: map['id'] as int?,
    name: map['name'] as String,
    type: ExpenseType.fromId(map['type'] as String),
    amount: (map['amount'] as num).toDouble(),
    dueDay: map['due_day'] as int,
    startMonth: Month.fromKey(map['start_month'] as String),
    endMonth: map['end_month'] == null
        ? null
        : Month.fromKey(map['end_month'] as String),
    totalInstallments: map['total_installments'] as int?,
    settledInstallments: map['settled_installments'] as int? ?? 0,
    walletId: map['wallet_id'] as int?,
    cardId: map['card_id'] as int?,
    createdAt: DateTime.parse(map['created_at'] as String),
  );

  final int? id;
  final String name;
  final ExpenseType type;
  final double amount;
  final int dueDay;
  final Month startMonth;
  final Month? endMonth;
  final int? totalInstallments;
  final int settledInstallments;
  final int? walletId;
  final int? cardId;
  final DateTime createdAt;

  int get remainingInstallments =>
      type == ExpenseType.installment && totalInstallments != null
      ? totalInstallments! - settledInstallments
      : 0;

  Month? get lastMonth => switch (type) {
    ExpenseType.single => startMonth,
    ExpenseType.recurring => endMonth,
    ExpenseType.installment => startMonth.addMonths(remainingInstallments - 1),
  };

  /// A rule registered today with a start month in the past would otherwise
  /// bill every month before the user started using the app.
  bool projectsBackIntoPast(Month month) =>
      type != ExpenseType.single && month < Month.fromDate(createdAt);

  ExpenseOccurrence? occurrenceIn(Month month) {
    if (month < startMonth) return null;

    return switch (type) {
      ExpenseType.single =>
        month == startMonth
            ? ExpenseOccurrence(expense: this, month: month)
            : null,
      ExpenseType.recurring =>
        endMonth != null && month > endMonth!
            ? null
            : ExpenseOccurrence(expense: this, month: month),
      ExpenseType.installment => _installmentOccurrence(month),
    };
  }

  /// Paid months this rule no longer projects: they stay in the history as
  /// off-rule occurrences instead of vanishing with their payments.
  Set<Month> monthsOffRule(Iterable<Month> paidMonths) => {
    for (final month in paidMonths)
      if (occurrenceIn(month) == null) month,
  };

  ExpenseOccurrence? _installmentOccurrence(Month month) {
    final total = totalInstallments;
    if (total == null) return null;

    final number = settledInstallments + month.monthsSince(startMonth) + 1;
    if (number > total) return null;

    return ExpenseOccurrence(
      expense: this,
      month: month,
      installmentNumber: number,
    );
  }

  Map<String, Object?> toMap() => <String, Object?>{
    if (id != null) 'id': id,
    'name': name,
    'type': type.id,
    'amount': amount,
    'due_day': dueDay,
    'start_month': startMonth.key,
    'end_month': endMonth?.key,
    'total_installments': totalInstallments,
    'settled_installments': settledInstallments,
    'wallet_id': walletId,
    'card_id': cardId,
    'created_at': createdAt.toIso8601String(),
  };

  Expense copyWith({
    int? id,
    String? name,
    ExpenseType? type,
    double? amount,
    int? dueDay,
    Month? startMonth,
    Month? endMonth,
    bool clearEndMonth = false,
    int? totalInstallments,
    int? settledInstallments,
    int? walletId,
    int? cardId,
    DateTime? createdAt,
  }) => Expense(
    id: id ?? this.id,
    name: name ?? this.name,
    type: type ?? this.type,
    amount: amount ?? this.amount,
    dueDay: dueDay ?? this.dueDay,
    startMonth: startMonth ?? this.startMonth,
    endMonth: clearEndMonth ? null : endMonth ?? this.endMonth,
    totalInstallments: totalInstallments ?? this.totalInstallments,
    settledInstallments: settledInstallments ?? this.settledInstallments,
    walletId: walletId ?? this.walletId,
    cardId: cardId ?? this.cardId,
    createdAt: createdAt ?? this.createdAt,
  );
}
