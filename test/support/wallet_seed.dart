import 'package:anchor/features/wallets/models/receipt_status.dart';
import 'package:anchor/features/wallets/repositories/wallet_repository.dart';

/// A predicted receipt is not money yet; seeds that need the salary in the
/// balance confirm it, the way the user would.
Future<void> confirmDuePayouts(WalletRepository wallets) async {
  await wallets.registerDuePayouts(await wallets.fetchWallets());
  for (final receipt in await wallets.fetchReceipts()) {
    if (!receipt.isPredicted) continue;
    await wallets.saveReceipt(
      receipt.copyWith(status: ReceiptStatus.confirmed),
    );
  }
}
