import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/dashboard/views/dashboard_page.dart';
import '../features/expenses/views/expenses_page.dart';
import '../features/settings/views/settings_page.dart';
import '../features/wallets/views/wallets_page.dart';

class AppShellController extends ChangeNotifier {
  static const int dashboardTab = 0;
  static const int expensesTab = 1;
  static const int walletsTab = 2;
  static const int settingsTab = 3;

  int _index = dashboardTab;

  int get index => _index;

  void goTo(int index) {
    if (_index == index) return;
    _index = index;
    notifyListeners();
  }
}

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  static const List<Widget> _pages = <Widget>[
    DashboardPage(),
    ExpensesPage(),
    WalletsPage(),
    SettingsPage(),
  ];

  static const List<NavigationDestination> _destinations =
      <NavigationDestination>[
        NavigationDestination(
          icon: Icon(Icons.pie_chart_outline),
          selectedIcon: Icon(Icons.pie_chart),
          label: 'Resumo',
        ),
        NavigationDestination(
          icon: Icon(Icons.receipt_long_outlined),
          selectedIcon: Icon(Icons.receipt_long),
          label: 'Despesas',
        ),
        NavigationDestination(
          icon: Icon(Icons.account_balance_wallet_outlined),
          selectedIcon: Icon(Icons.account_balance_wallet),
          label: 'Carteiras',
        ),
        NavigationDestination(
          icon: Icon(Icons.tune_outlined),
          selectedIcon: Icon(Icons.tune),
          label: 'Ajustes',
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppShellController>();

    return Scaffold(
      body: IndexedStack(index: controller.index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: controller.index,
        onDestinationSelected: controller.goTo,
        destinations: _destinations,
      ),
    );
  }
}
