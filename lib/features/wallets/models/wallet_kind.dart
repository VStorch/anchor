enum WalletKind {
  salary('salary', 'Salário', 'Sua remuneração principal'),
  benefit('benefit', 'Benefício', 'Vale refeição, alimentação, mercado...');

  const WalletKind(this.id, this.label, this.description);

  final String id;
  final String label;
  final String description;

  static WalletKind fromId(String id) =>
      values.firstWhere((kind) => kind.id == id, orElse: () => benefit);
}
