import 'balance_check.dart';
import 'outflow.dart';
import 'receipt.dart';

class WalletMovement {
  const WalletMovement({
    required this.date,
    required this.title,
    required this.walletId,
    required this.amount,
    this.countsInBalance = true,
    this.titleIsWalletName = false,
    this.receipt,
    this.outflow,
    this.check,
  });

  factory WalletMovement.fromReceipt(
    Receipt receipt, {
    required String title,
    required bool countsInBalance,
    bool titleIsWalletName = false,
  }) => WalletMovement(
    date: receipt.receivedAt,
    title: title,
    walletId: receipt.walletId,
    amount: receipt.amount,
    countsInBalance: countsInBalance,
    titleIsWalletName: titleIsWalletName,
    receipt: receipt,
  );

  factory WalletMovement.fromOutflow(
    Outflow outflow, {
    required bool countsInBalance,
  }) => WalletMovement(
    date: outflow.spentAt,
    title: outflow.label,
    walletId: outflow.walletId,
    amount: -outflow.amount,
    countsInBalance: countsInBalance,
    outflow: outflow,
  );

  factory WalletMovement.fromCheck(
    BalanceCheck check, {
    required bool isLatest,
  }) => WalletMovement(
    date: check.checkedAt,
    title: 'Saldo informado',
    walletId: check.walletId,
    amount: check.amount,
    countsInBalance: isLatest,
    check: check,
  );

  final DateTime date;
  final String title;
  final int walletId;
  final double amount;
  final bool countsInBalance;

  /// The title already names the wallet, so the subtitle does not repeat it.
  final bool titleIsWalletName;
  final Receipt? receipt;
  final Outflow? outflow;
  final BalanceCheck? check;

  bool get isIncome => receipt != null;

  bool get isCheck => check != null;

  bool get isEditable => receipt != null || outflow != null || check != null;

  bool get isPredicted => receipt?.isPredicted ?? false;
}
