import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/money.dart';
import '../../budget/models/wallet_summary.dart';
import '../models/balance_check.dart';
import '../models/outflow.dart';
import '../models/receipt.dart';
import '../models/wallet.dart';
import '../models/wallet_movement.dart';
import '../viewmodels/wallets_view_model.dart';
import 'widgets/balance_check_sheet.dart';
import 'widgets/outflow_sheet.dart';
import 'widgets/receipt_sheet.dart';

/// The sheets a wallet opens, shared by the Carteiras tab and the statement
/// of a single wallet.
abstract final class WalletActions {
  static Future<void> registerReceipt(
    BuildContext context,
    Wallet wallet,
  ) async {
    final viewModel = context.read<WalletsViewModel>();
    final edit = await ReceiptSheet.show(
      context,
      wallet: wallet,
      month: viewModel.month,
      latestCheckAt: viewModel.latestCheckOf(wallet)?.checkedAt,
    );
    if (edit == null || edit.isDiscarded) return;

    await viewModel.registerReceipt(
      wallet: wallet,
      amount: edit.amount,
      receivedAt: edit.receivedAt,
    );
  }

  static Future<void> registerOutflow(
    BuildContext context,
    Wallet wallet,
  ) async {
    final viewModel = context.read<WalletsViewModel>();
    final edit = await OutflowSheet.show(
      context,
      wallet: wallet,
      month: viewModel.month,
      latestCheckAt: viewModel.latestCheckOf(wallet)?.checkedAt,
    );
    if (edit == null || edit.isDiscarded) return;

    await viewModel.saveOutflow(
      wallet: wallet,
      description: edit.description,
      amount: edit.amount,
      spentAt: edit.spentAt,
    );
  }

  static Future<void> checkBalance(
    BuildContext context,
    WalletSummary summary, {
    BalanceCheck? check,
  }) async {
    final viewModel = context.read<WalletsViewModel>();
    final wallet = summary.wallet;
    final edit = await BalanceCheckSheet.show(
      context,
      wallet: wallet,
      calculatedBalance: summary.balance,
      dueUnconfirmed: (day) => viewModel.dueUnconfirmedOf(
        wallet,
        WalletsViewModel.checkedAtFor(day),
      ),
      check: check,
      latestCheck: viewModel.latestCheckOf(wallet),
    );
    if (edit == null || !context.mounted) return;

    if (edit.isRemoved) {
      await viewModel.deleteBalanceCheck(check!);
      return;
    }

    final sameDay = check == null
        ? viewModel.checkOnDay(wallet, edit.day)
        : null;
    if (sameDay != null && !await confirmReplace(context, sameDay)) return;

    await viewModel.saveBalanceCheck(
      wallet,
      amount: edit.amount,
      day: edit.day,
      editing: check ?? sameDay,
      confirm: edit.confirm,
      leftPending: edit.leftPending,
    );
  }

  /// Opens the first receipt of the month still waiting to be confirmed.
  static VoidCallback? confirmFirst(BuildContext context, Wallet wallet) {
    final receipt = context.read<WalletsViewModel>().firstUnconfirmedOf(wallet);
    if (receipt == null) return null;
    return () => editReceipt(context, receipt);
  }

  static Future<bool> confirmReplace(
    BuildContext context,
    BalanceCheck existing,
  ) async {
    final replace = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(
          'Já existe um saldo informado em '
          '${DateFormat('dd/MM').format(existing.checkedAt)} '
          '(${formatMoney(existing.amount)}). Substituir?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Substituir'),
          ),
        ],
      ),
    );
    return replace ?? false;
  }

  static Future<void> openMovement(
    BuildContext context,
    WalletMovement movement,
  ) async {
    final receipt = movement.receipt;
    final outflow = movement.outflow;
    final check = movement.check;

    if (check != null) {
      final summary = context.read<WalletsViewModel>().summaryFor(
        check.walletId,
      );
      if (summary == null) return;
      return checkBalance(context, summary, check: check);
    }
    if (receipt != null) return editReceipt(context, receipt);
    if (outflow != null) return editOutflow(context, outflow);
  }

  static Future<void> editOutflow(BuildContext context, Outflow outflow) async {
    final viewModel = context.read<WalletsViewModel>();
    final wallet = viewModel.walletById(outflow.walletId);
    if (wallet == null) return;

    final edit = await OutflowSheet.show(
      context,
      wallet: wallet,
      outflow: outflow,
      latestCheckAt: viewModel.latestCheckOf(wallet)?.checkedAt,
    );
    if (edit == null) return;

    if (edit.isDiscarded) {
      await viewModel.deleteOutflow(outflow);
      return;
    }

    await viewModel.saveOutflow(
      wallet: wallet,
      outflow: outflow,
      description: edit.description,
      amount: edit.amount,
      spentAt: edit.spentAt,
    );
  }

  static Future<void> editReceipt(BuildContext context, Receipt receipt) async {
    final viewModel = context.read<WalletsViewModel>();
    final wallet = viewModel.walletById(receipt.walletId);
    if (wallet == null) return;

    final edit = await ReceiptSheet.show(
      context,
      wallet: wallet,
      receipt: receipt,
      latestCheckAt: viewModel.latestCheckOf(wallet)?.checkedAt,
    );
    if (edit == null) return;

    if (edit.isDiscarded) {
      await viewModel.discardReceipt(receipt);
      return;
    }

    await viewModel.confirmReceipt(
      receipt,
      amount: edit.amount,
      receivedAt: edit.receivedAt,
    );
  }
}
