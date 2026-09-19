import 'package:anchor/core/widgets/money_field.dart';
import 'package:anchor/features/onboarding/views/widgets/onboarding_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fills the first-run setup as the user from the usability test did, on
/// 15/09/2026: salary on the 5th business day, VR on the 1st, VA on the
/// 25th, rent already
/// paid, internet, a fridge in parcels and a card. [onFilled] runs on each
/// step once it is filled, before moving on.
Future<void> fillOnboarding(
  WidgetTester tester, {
  Future<void> Function(String step)? onFilled,
}) async {
  Future<void> filled(String step) async {
    if (onFilled != null) await onFilled(step);
  }

  await filled('boas-vindas');
  await tapVisible(tester, find.text('Começar'));

  final salary = find.byKey(const ValueKey('income-salary'));
  await typeMoney(tester, within: salary, '3200');
  await tapVisible(
    tester,
    find.descendant(of: salary, matching: find.text('Nº dia útil')),
  );
  await pickDay(
    tester,
    find.descendant(of: salary, matching: find.text('Qual dia útil')),
    5,
  );
  expect(find.text('Em setembro cai ter, 8/set'), findsOneWidget);
  await addBenefit(tester, 0, name: 'VR', amount: '600', day: 1);
  expect(find.text('Em setembro cai ter, 1/set'), findsOneWidget);
  await addBenefit(tester, 1, name: 'VA', amount: '400', day: 25);
  expect(find.text('Em setembro cai sex, 25/set'), findsOneWidget);
  await filled('renda');
  await tapVisible(tester, find.text('Continuar'));

  expect(find.text('Quanto tem hoje?'), findsOneWidget);
  await typeMoney(
    tester,
    within: find.widgetWithText(MoneyField, 'Tem em Salário'),
    '850',
  );
  await typeMoney(
    tester,
    within: find.widgetWithText(MoneyField, 'Tem em VR'),
    '210',
  );
  await typeMoney(
    tester,
    within: find.widgetWithText(MoneyField, 'Tem em VA'),
    '90',
  );
  await answer(tester, 'O salário de 8/set já está nesse valor?', 'Sim');
  await answer(tester, 'O VR de 1/set já está nesse valor?', 'Ainda não caiu');
  await filled('saldo');
  await tapVisible(tester, find.text('Continuar'));

  await tapVisible(tester, find.widgetWithText(FilterChip, 'Aluguel'));
  await tapVisible(tester, find.widgetWithText(FilterChip, 'Internet'));
  final rent = cardOf('Aluguel');
  await typeMoney(tester, within: rent, '1100');
  await pickDay(
    tester,
    find.descendant(of: rent, matching: find.text('Dia do vencimento')),
    10,
  );
  expect(
    find.descendant(of: rent, matching: find.text('Já pagou a de setembro?')),
    findsOneWidget,
  );
  final internet = cardOf('Internet');
  await typeMoney(tester, within: internet, '99,90');
  await pickDay(
    tester,
    find.descendant(of: internet, matching: find.text('Dia do vencimento')),
    15,
  );
  expect(find.text('Já pagou a de setembro?'), findsOneWidget);
  await filled('contas');
  await tapVisible(tester, find.text('Continuar'));

  await tapVisible(tester, find.text('Adicionar compra parcelada'));
  await tester.enterText(
    find.widgetWithText(TextFormField, 'O que foi comprado'),
    'Geladeira',
  );
  await tester.pumpAndSettle();
  final fridge = cardOf('Geladeira');
  await typeMoney(tester, within: fridge, '180');
  await tester.enterText(find.widgetWithText(TextFormField, 'Parcela'), '4');
  await tester.enterText(find.widgetWithText(TextFormField, 'Total'), '10');
  await tester.pumpAndSettle();
  await pickDay(
    tester,
    find.descendant(of: fridge, matching: find.text('Dia do vencimento')),
    5,
  );
  await filled('parcelas');
  await tapVisible(tester, find.text('Continuar'));

  await answer(tester, 'Usa cartão de crédito?', 'Sim');
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Nome do cartão'),
    'Nubank',
  );
  await tester.pumpAndSettle();
  expect(find.text('Dia em que a fatura fecha'), findsOneWidget);
  await pickDay(tester, find.text('Dia em que a fatura fecha'), 3);
  await pickDay(tester, find.text('Dia em que a fatura vence'), 10);
  expect(find.text('Fecha dia 3'), findsOneWidget);
  expect(find.text('Vence dia 10'), findsOneWidget);
  await filled('cartão');
  await tapVisible(tester, find.text('Continuar'));

  expect(find.text('Lembretes'), findsOneWidget);
  await filled('lembretes');
}

Future<void> addBenefit(
  WidgetTester tester,
  int key, {
  required String name,
  required String amount,
  required int day,
}) async {
  await tapVisible(tester, find.text('Adicionar benefício (VR, VA, mercado…)'));
  final benefit = find.byKey(ValueKey('income-benefit-$key'));
  final nameField = find.descendant(
    of: benefit,
    matching: find.widgetWithText(TextFormField, 'Nome do benefício'),
  );
  await tester.ensureVisible(nameField);
  await tester.enterText(nameField, name);
  await tester.pumpAndSettle();
  await typeMoney(tester, within: benefit, amount);
  await pickDay(
    tester,
    find.descendant(of: benefit, matching: find.text('Dia em que cai')),
    day,
  );
}

Finder cardOf(String name) =>
    find.ancestor(of: find.text(name), matching: find.byType(Card)).first;

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> typeMoney(
  WidgetTester tester,
  String amount, {
  required Finder within,
}) async {
  final field = find.descendant(
    of: find.descendant(
      of: within,
      matching: find.byType(MoneyField),
      matchRoot: true,
    ),
    matching: find.byType(TextField),
  );
  await tester.ensureVisible(field.first);
  await tester.enterText(field.first, amount);
  await tester.pumpAndSettle();
}

/// Picking a day never hands the focus back to a text field, which would
/// pop the keyboard over the answer.
Future<void> pickDay(WidgetTester tester, Finder button, int day) async {
  await tapVisible(tester, button);
  await tester.tap(
    find.descendant(of: find.byType(BottomSheet), matching: find.text('$day')),
  );
  await tester.pumpAndSettle();
  expect(
    FocusManager.instance.primaryFocus?.context
        ?.findAncestorWidgetOfExactType<EditableText>(),
    isNull,
  );
}

Future<void> answer(WidgetTester tester, String question, String option) =>
    tapVisible(
      tester,
      find.descendant(
        of: find.widgetWithText(YesNoQuestion, question),
        matching: find.text(option),
      ),
    );
