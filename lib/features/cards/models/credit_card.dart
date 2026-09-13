import 'package:flutter/material.dart';

import '../../../core/utils/month.dart';

class CreditCard {
  const CreditCard({
    this.id,
    required this.name,
    required this.closingDay,
    required this.dueDay,
    this.walletId,
    required this.createdAt,
  });

  factory CreditCard.fromMap(Map<String, Object?> map) => CreditCard(
    id: map['id'] as int?,
    name: map['name'] as String,
    closingDay: map['closing_day'] as int,
    dueDay: map['due_day'] as int,
    walletId: map['wallet_id'] as int?,
    createdAt: DateTime.parse(map['created_at'] as String),
  );

  static const IconData icon = Icons.credit_card;

  final int? id;
  final String name;
  final int closingDay;
  final int dueDay;
  final int? walletId;
  final DateTime createdAt;

  DateTime dueDateIn(Month month) => month.dayOf(dueDay);

  /// The month whose invoice charges a purchase made on [date]: after the
  /// closing day it rolls to the next statement, and a due day that comes
  /// before the closing day belongs to the month after the statement closes.
  Month invoiceMonthFor(DateTime date) {
    final purchaseMonth = Month.fromDate(date);
    final closingMonth = date.day <= purchaseMonth.dayOf(closingDay).day
        ? purchaseMonth
        : purchaseMonth.next;
    return dueDay > closingDay ? closingMonth : closingMonth.next;
  }

  Map<String, Object?> toMap() => <String, Object?>{
    if (id != null) 'id': id,
    'name': name,
    'closing_day': closingDay,
    'due_day': dueDay,
    'wallet_id': walletId,
    'created_at': createdAt.toIso8601String(),
  };
}
