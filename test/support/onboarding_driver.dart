import 'package:anchor/core/widgets/money_field.dart';
import 'package:anchor/features/onboarding/views/widgets/onboarding_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fills the first-run setup as the user from the usability test did, on
/// 15/09/2026: salary on the 5th business day, VR on the 1st, rent already
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
    find.descendant(of: salary, matching: find.text('Escolha o dia')),
    5,
  );
  expect(find.text('Em setembro cai ter, 8/set'), findsOneWidget);
  await answer(tester, 'Recebe VR, VA ou vale mercado?', 'Sim');
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Nome do benefício'),
    'VR',
  );
  await tester.pumpAndSettle();
  final voucher = find.byKey(const ValueKey('income-benefit'));
  await typeMoney(tester, within: voucher, '600');
  await pickDay(
    tester,
    find.descendant(of: voucher, matching: find.text('Escolha o dia')),
    1,
  );
  expect(find.text('Em setembro cai ter, 1/set'), findsOneWidget);
  await filled('renda');
  await tapVisible(tester, find.text('Continuar'));

  expect(find.textContaining('Hoje, 15/set'), findsOneWidget);
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
    find.descendant(of: rent, matching: find.text('Escolha o dia')),
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
    find.descendant(of: internet, matching: find.text('Escolha o dia')),
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
    find.descendant(of: fridge, matching: find.text('Escolha o dia')),
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
  await pickDay(tester, find.text('Escolha o dia').first, 3);
  await pickDay(tester, find.text('Escolha o dia'), 10);
  expect(find.text('Fecha dia 3'), findsOneWidget);
  expect(find.text('Vence dia 10'), findsOneWidget);
  await filled('cartão');
  await tapVisible(tester, find.text('Continuar'));

  expect(find.text('Lembretes'), findsOneWidget);
  await filled('lembretes');
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

Future<void> pickDay(WidgetTester tester, Finder button, int day) async {
  await tapVisible(tester, button);
  await tester.tap(
    find.descendant(of: find.byType(BottomSheet), matching: find.text('$day')),
  );
  await tester.pumpAndSettle();
}

Future<void> answer(WidgetTester tester, String question, String option) =>
    tapVisible(
      tester,
      find.descendant(
        of: find.widgetWithText(YesNoQuestion, question),
        matching: find.text(option),
      ),
    );
