import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/money.dart';
import '../../../core/widgets/fab_clearance.dart';
import '../../../core/widgets/month_switcher.dart';
import '../../../core/widgets/scroll_aware_fab.dart';
import '../../../core/widgets/section_header.dart';
import '../viewmodels/wallets_view_model.dart';
import 'wallet_actions.dart';
import 'wallet_form_page.dart';
import 'widgets/movement_tile.dart';
import 'widgets/wallet_action_buttons.dart';
import 'widgets/wallet_balance_header.dart';

/// One wallet: its balance, its actions and the statement of the month on
/// screen — the same month the whole app is showing.
class WalletDetailPage extends StatelessWidget {
  const WalletDetailPage({super.key, required this.walletId});

  static Future<void> open(BuildContext context, {required int walletId}) {
    final viewModel = context.read<WalletsViewModel>();

    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChangeNotifierProvider<WalletsViewModel>.value(
          value: viewModel,
          child: WalletDetailPage(walletId: walletId),
        ),
      ),
    );
  }

  final int walletId;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<WalletsViewModel>();
    final summary = viewModel.summaryFor(walletId);
    if (summary == null) {
      return const _ClosedWallet();
    }

    final wallet = summary.wallet;
    final movements = viewModel.movementsOf(walletId);
    final monthName = DateFormat.MMMM('pt_BR').format(viewModel.month.firstDay);

    return Scaffold(
      appBar: AppBar(
        title: Text(wallet.name),
        actions: [
          IconButton(
            onPressed: () => WalletFormPage.open(context, wallet: wallet),
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Editar carteira',
          ),
        ],
      ),
      body: ScrollAwareFab(
        heroTag: 'wallet-detail-outflow',
        icon: Icons.add,
        label: 'Gasto',
        onPressed: () => WalletActions.registerOutflow(context, wallet),
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 0, 16, fabClearance(context)),
          children: [
            MonthSwitcher(
              month: viewModel.month,
              onPrevious: viewModel.goToPreviousMonth,
              onNext: viewModel.goToNextMonth,
              onToday: viewModel.goToCurrentMonth,
            ),
            const SizedBox(height: 12),
            WalletBalanceHeader(summary: summary, month: viewModel.month),
            if (summary.unconfirmedInMonth > 0) ...[
              const SizedBox(height: 12),
              _ConfirmButton(
                label: summary.unconfirmedInMonth == 1
                    ? 'Confirmar '
                          '${formatMoney(summary.pendingConfirmationInMonth)}'
                    : 'Confirmar (${summary.unconfirmedInMonth})',
                onPressed: WalletActions.confirmFirst(context, wallet),
              ),
            ],
            const SizedBox(height: 16),
            WalletActionButtons(
              summary: summary,
              onOutflow: () => WalletActions.registerOutflow(context, wallet),
              onReceipt: () => WalletActions.registerReceipt(context, wallet),
              onCheck: () => WalletActions.checkBalance(context, summary),
            ),
            const SizedBox(height: 16),
            SectionHeader(title: 'Extrato de $monthName'),
            if (movements.isEmpty)
              Text(
                'Nada lançado em $monthName nesta carteira.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ...movements.map(
              (movement) => MovementTile(
                movement: movement,
                wallet: wallet,
                showsWallet: false,
                onTap: () => WalletActions.openMovement(context, movement),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfirmButton extends StatelessWidget {
  const _ConfirmButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.tonalIcon(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            icon: const Icon(Icons.task_alt, size: 18),
            label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
    );
  }
}

/// The wallet was deleted while its statement was open.
class _ClosedWallet extends StatefulWidget {
  const _ClosedWallet();

  @override
  State<_ClosedWallet> createState() => _ClosedWalletState();
}

class _ClosedWalletState extends State<_ClosedWallet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: SizedBox.shrink());
}
