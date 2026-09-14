enum InvoiceStatus {
  open('Aberta'),
  closed('Fechada'),
  overdue('Atrasada'),
  paid('Paga');

  const InvoiceStatus(this.label);

  final String label;
}
