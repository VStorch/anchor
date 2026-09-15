import 'package:flutter/material.dart';

enum ExpenseType {
  recurring(
    'recurring',
    'Todo mês',
    'Repete todo mês, como assinaturas e plano de saúde',
    Icons.all_inclusive,
  ),
  installment(
    'installment',
    'Parcelada',
    'Tem um número definido de parcelas, como prestações',
    Icons.splitscreen_outlined,
  ),
  single(
    'single',
    'Só uma vez',
    'Cobrada apenas no mês escolhido',
    Icons.event_outlined,
  );

  const ExpenseType(this.id, this.label, this.description, this.icon);

  final String id;
  final String label;
  final String description;
  final IconData icon;

  static ExpenseType fromId(String id) =>
      values.firstWhere((type) => type.id == id, orElse: () => single);
}
