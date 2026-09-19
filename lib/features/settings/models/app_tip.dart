/// A one-line hint shown once at the top of a tab.
enum AppTip {
  dashboard(
    'dashboard',
    'Aqui você vê quanto tem hoje e quanto vai sobrar no mês.',
  ),
  expenses('expenses', 'Toque numa conta para marcar como paga.'),
  wallets('wallets', 'Use Novo gasto para lançar o que saiu.');

  const AppTip(this.id, this.message);

  final String id;
  final String message;
}
