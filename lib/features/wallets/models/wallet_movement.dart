import 'outflow.dart';
import 'receipt.dart';

class WalletMovement {
  const WalletMovement({
    required this.date,
    required this.title,
    required this.walletId,
    required this.amount,
    this.receipt,
    this.outflow,
  });

  factory WalletMovement.fromReceipt(
    Receipt receipt, {
    required String title,
  }) => WalletMovement(
    date: receipt.receivedAt,
    title: title,
    walletId: receipt.walletId,
    amount: receipt.amount,
    receipt: receipt,
  );

  factory WalletMovement.fromOutflow(Outflow outflow) => WalletMovement(
    date: outflow.spentAt,
    title: outflow.label,
    walletId: outflow.walletId,
    amount: -outflow.amount,
    outflow: outflow,
  );

  final DateTime date;
  final String title;
  final int walletId;
  final double amount;
  final Receipt? receipt;
  final Outflow? outflow;

  bool get isIncome => receipt != null;

  bool get isEditable => receipt != null || outflow != null;

  bool get isPredicted => receipt?.isPredicted ?? false;

  bool get isAdjustment => receipt?.isAdjustment ?? false;
}
