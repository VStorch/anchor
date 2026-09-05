enum ReceiptStatus {
  predicted('predicted', 'Previsto'),
  confirmed('confirmed', 'Recebido'),
  skipped('skipped', 'Não veio');

  const ReceiptStatus(this.id, this.label);

  static ReceiptStatus fromId(String id) =>
      values.firstWhere((status) => status.id == id, orElse: () => confirmed);

  final String id;
  final String label;
}
