import '../../../core/utils/month.dart';
import '../../wallets/models/payout.dart';
import '../../wallets/models/payout_schedule.dart';
import '../../wallets/models/wallet_kind.dart';

/// A money source as the first run asks for it: one payout a month, and
/// optionally what it holds today and whether this month's pay is in it.
class IncomeDraft {
  IncomeDraft({required this.kind, this.name = '', this.key = 0});

  final WalletKind kind;

  /// Tells apart the sources of the same kind on screen.
  final int key;
  String name;
  double amount = 0;
  PayoutSchedule schedule = PayoutSchedule.dayOfMonth;
  int? day;

  /// What the wallet holds today; null when the user did not say.
  double? balanceToday;

  /// Whether this month's pay is already inside [balanceToday]; asked only
  /// when its date has come.
  bool? arrived;

  /// The everyday spending a salary sets aside each month; optional, and
  /// never asked of a benefit.
  double? monthlyReserve;

  String get displayName => name.trim().isEmpty ? kind.label : name.trim();

  int get dayCount => schedule.isBusinessDay ? Payout.maxBusinessDay : 31;

  bool get isComplete => amount > 0 && day != null;

  Payout toPayout({int walletId = 0, required DateTime createdAt}) => Payout(
    walletId: walletId,
    label: '',
    amount: amount,
    day: day!,
    schedule: schedule,
    createdAt: createdAt,
  );

  DateTime? dateIn(Month month) =>
      day == null ? null : toPayout(createdAt: month.firstDay).dateIn(month);

  /// This month's pay is due by [today], so it may already be in the balance.
  bool isDueBy(DateTime today) {
    final date = dateIn(Month.fromDate(today));
    return date != null && !date.isAfter(today);
  }

  void setSchedule(PayoutSchedule value) {
    schedule = value;
    if ((day ?? 0) > dayCount) day = dayCount;
  }
}

/// A bill that repeats every month.
class BillDraft {
  BillDraft({this.name = '', this.isSuggestion = false});

  static const List<String> suggestions = <String>[
    'Aluguel',
    'Luz',
    'Água',
    'Internet',
    'Celular',
    'Academia',
    'Plano de saúde',
    'Streaming',
  ];

  final bool isSuggestion;
  String name;
  double amount = 0;
  int? dueDay;

  /// Only read when this month's bill is already past due.
  bool paidThisMonth = true;

  bool get isComplete => name.trim().isNotEmpty && amount > 0 && dueDay != null;

  bool isPastDueBy(DateTime today) => _isPastDue(dueDay, today);
}

/// A purchase in parcels: which parcel falls due this month and of how many.
class InstallmentDraft {
  InstallmentDraft();

  String name = '';
  double amount = 0;
  int? currentNumber;
  int? total;
  int? dueDay;
  bool paidThisMonth = true;

  bool get isComplete =>
      name.trim().isNotEmpty && amount > 0 && dueDay != null && hasValidNumbers;

  bool get hasValidNumbers =>
      currentNumber != null &&
      total != null &&
      currentNumber! >= 1 &&
      total! >= currentNumber!;

  /// Parcels before this month's are already behind the user.
  int get settledInstallments => currentNumber! - 1;

  bool isPastDueBy(DateTime today) => _isPastDue(dueDay, today);
}

class CardDraft {
  CardDraft({this.payer});

  String name = '';
  int? closingDay;
  int? dueDay;
  IncomeDraft? payer;

  bool get isComplete =>
      name.trim().isNotEmpty && closingDay != null && dueDay != null;
}

/// Everything the first run collected, with the skipped steps left out.
class OnboardingDraft {
  const OnboardingDraft({
    this.incomes = const <IncomeDraft>[],
    this.bills = const <BillDraft>[],
    this.installments = const <InstallmentDraft>[],
    this.card,
  });

  final List<IncomeDraft> incomes;
  final List<BillDraft> bills;
  final List<InstallmentDraft> installments;
  final CardDraft? card;

  /// Bills are charged to the first source, the salary when there is one.
  IncomeDraft? get billPayer => incomes.isEmpty ? null : incomes.first;

  bool get isEmpty =>
      incomes.isEmpty && bills.isEmpty && installments.isEmpty && card == null;
}

bool _isPastDue(int? dueDay, DateTime today) {
  if (dueDay == null) return false;
  final due = Month.fromDate(today).dayOf(dueDay);
  return due.isBefore(DateTime(today.year, today.month, today.day));
}
