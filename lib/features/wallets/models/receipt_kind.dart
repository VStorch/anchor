enum ReceiptKind {
  income('income', 'Entrada'),
  adjustment('adjustment', 'Ajuste de saldo');

  const ReceiptKind(this.id, this.label);

  static ReceiptKind fromId(String id) =>
      values.firstWhere((kind) => kind.id == id, orElse: () => income);

  final String id;
  final String label;
}
