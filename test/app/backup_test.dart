import 'dart:io';
import 'dart:typed_data';

import 'package:anchor/app/anchor_app.dart';
import 'package:anchor/core/database/app_database.dart';
import 'package:anchor/core/state/data_changes.dart';
import 'package:anchor/features/settings/services/backup_files.dart';
import 'package:anchor/features/settings/viewmodels/settings_view_model.dart';
import 'package:anchor/features/wallets/models/wallet.dart';
import 'package:anchor/features/wallets/models/wallet_kind.dart';
import 'package:anchor/features/wallets/repositories/wallet_repository.dart';
import 'package:anchor/features/wallets/views/widgets/wallet_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_reminder_notifications.dart';
import '../support/test_database.dart';

class _FakeBackupFiles implements BackupFiles {
  final Map<String, Uint8List> saved = <String, Uint8List>{};
  Uint8List? toOpen;

  @override
  Future<bool> save(String fileName, Uint8List bytes) async {
    saved[fileName] = bytes;
    return true;
  }

  @override
  Future<Uint8List?> open() async => toOpen;
}

void main() {
  late Directory directory;
  late AppDatabase database;
  late _FakeBackupFiles files;

  setUpAll(() => initializeDateFormatting('pt_BR'));

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    directory = Directory.systemTemp.createTempSync('anchor_backup_app');
    database = createFileDatabase('${directory.path}/anchor.db');
    files = _FakeBackupFiles();
  });

  tearDown(() async {
    await database.close();
    directory.deleteSync(recursive: true);
  });

  Future<void> createWallet(String name) =>
      WalletRepository(database, DataChanges()).saveWallet(
        Wallet(
          name: name,
          kind: WalletKind.benefit,
          colorIndex: 0,
          createdAt: DateTime.now(),
        ),
      );

  // Opening a file database checks the disk with async I/O, which only
  // completes outside the fake clock the widget test runs on.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  Future<void> tapTab(WidgetTester tester, IconData icon) async {
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.byIcon(icon),
      ),
    );
    await settle(tester);
  }

  void useTallPhone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
  }

  Finder walletNamed(String name) =>
      find.descendant(of: find.byType(WalletCard), matching: find.text(name));

  testWidgets('salva uma cópia e volta a ela depois de mudar os dados', (
    tester,
  ) async {
    useTallPhone(tester);
    await tester.runAsync(() => createWallet('Vale'));
    final settings = SettingsViewModel();
    await settings.initialize();
    await tester.pumpWidget(
      AnchorApp(
        reminderNotifications: FakeReminderNotifications(),
        settings: settings,
        database: database,
        backupFiles: files,
      ),
    );
    await settle(tester);

    await tapTab(tester, Icons.tune_outlined);
    expect(find.text('Nenhuma ainda'), findsOneWidget);

    await tester.tap(find.text('Salvar cópia'));
    await settle(tester);

    expect(
      files.saved.keys.single,
      matches(RegExp(r'^anchor-\d{4}-\d{2}-\d{2}\.db$')),
    );
    expect(find.textContaining('Última em'), findsOneWidget);

    final appWallets = tester
        .element(find.byType(NavigationBar))
        .read<WalletRepository>();
    await tester.runAsync(
      () => appWallets.saveWallet(
        Wallet(
          name: 'Alimentação',
          kind: WalletKind.benefit,
          colorIndex: 1,
          createdAt: DateTime.now(),
        ),
      ),
    );
    await tapTab(tester, Icons.account_balance_wallet_outlined);
    expect(walletNamed('Alimentação'), findsOneWidget);

    files.toOpen = files.saved.values.single;
    await tapTab(tester, Icons.tune_outlined);
    await tester.tap(find.text('Restaurar cópia'));
    await settle(tester);

    expect(find.textContaining('1 carteira e 0 despesas'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Restaurar'));
    await settle(tester);

    await tapTab(tester, Icons.account_balance_wallet_outlined);
    expect(walletNamed('Vale'), findsOneWidget);
    expect(walletNamed('Alimentação'), findsNothing);
  });

  testWidgets('um arquivo qualquer não apaga nada', (tester) async {
    useTallPhone(tester);
    await tester.runAsync(() => createWallet('Vale'));
    files.toOpen = Uint8List.fromList('nada a ver'.codeUnits);
    final settings = SettingsViewModel();
    await settings.initialize();
    await tester.pumpWidget(
      AnchorApp(
        reminderNotifications: FakeReminderNotifications(),
        settings: settings,
        database: database,
        backupFiles: files,
      ),
    );
    await settle(tester);

    await tapTab(tester, Icons.tune_outlined);
    await tester.tap(find.text('Restaurar cópia'));
    await settle(tester);

    expect(find.text('Esse arquivo não é uma cópia do Anchor'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);

    await tapTab(tester, Icons.account_balance_wallet_outlined);
    expect(walletNamed('Vale'), findsOneWidget);
  });
}
