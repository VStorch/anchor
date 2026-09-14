import 'package:anchor/core/database/app_database.dart';
import 'package:anchor/core/state/data_changes.dart';
import 'package:anchor/features/wallets/models/payout.dart';
import 'package:anchor/features/wallets/models/payout_schedule.dart';
import 'package:anchor/features/wallets/models/wallet.dart';
import 'package:anchor/features/wallets/models/wallet_kind.dart';
import 'package:anchor/features/wallets/repositories/wallet_repository.dart';
import 'package:anchor/features/wallets/viewmodels/wallet_form_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  late AppDatabase database;
  late DataChanges changes;
  late WalletRepository repository;

  setUp(() {
    database = createInMemoryDatabase();
    changes = DataChanges();
    repository = WalletRepository(database, changes);
  });

  tearDown(() => database.close());

  Future<Wallet> seedSalaryWithTwoPayouts() async {
    final today = DateTime.now();
    final walletId = await repository.saveWallet(
      Wallet(
        name: 'Salário',
        kind: WalletKind.salary,
        colorIndex: 0,
        createdAt: DateTime(today.year, today.month, 1),
      ),
    );
    for (final label in ['Adiantamento', 'Salário']) {
      await repository.savePayout(
        Payout(
          walletId: walletId,
          label: label,
          amount: 1500,
          day: 1,
          createdAt: DateTime(today.year, today.month, 1),
        ),
      );
    }
    await repository.registerDuePayouts(await repository.fetchWallets());
    return (await repository.fetchWallets()).single;
  }

  test('salvar a carteira editada avisa as outras telas uma vez', () async {
    final wallet = await seedSalaryWithTwoPayouts();
    final form = WalletFormViewModel(repository: repository, wallet: wallet)
      ..removePayoutAt(0)
      ..addPayout(
        label: 'Bônus',
        amount: 400,
        day: 20,
        schedule: PayoutSchedule.dayOfMonth,
      );

    var published = 0;
    changes.addListener(() => published++);
    await form.save();

    expect(published, 1);
    expect(
      (await repository.fetchWallets()).single.payouts.map((p) => p.label),
      ['Salário', 'Bônus'],
    );
  });

  test('recarregar as telas enquanto a carteira é salva não quebra', () async {
    final wallet = await seedSalaryWithTwoPayouts();
    final form = WalletFormViewModel(repository: repository, wallet: wallet)
      ..removePayoutAt(0);

    final errors = <Object>[];
    final reloads = <Future<void>>[];
    changes.addListener(() {
      reloads.add(
        repository
            .fetchWallets()
            .then(repository.registerDuePayouts)
            .catchError((Object error) {
              errors.add(error);
              return 0;
            }),
      );
    });
    await form.save();
    await Future.wait(reloads);

    expect(errors, isEmpty);
  });
}
