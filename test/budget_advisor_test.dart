import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:budget_buddy/constants/categories.dart';
import 'package:budget_buddy/constants/currencies.dart';
import 'package:budget_buddy/models/expense_category.dart';
import 'package:budget_buddy/models/transaction.dart';
import 'package:budget_buddy/services/advisor_ai.dart';
import 'package:budget_buddy/services/budget_advisor.dart';
import 'package:budget_buddy/state/app_state.dart';

ExpenseCategory cat(String name) => kCategories.firstWhere((c) => c.name == name);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Far-future month so recurring series never auto-post during the test.
  final now = DateTime(2099, 3, 15);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppCurrency.symbol = '\$';
  });

  Future<AppState> newState({double income = 3000}) async {
    final s = AppState();
    await s.ready;
    s.monthlyIncome = income;
    return s;
  }

  Transaction tx(String category, double amount, DateTime date,
          {String title = 'Item',
          RepeatFrequency repeat = RepeatFrequency.none}) =>
      Transaction(
        title: title,
        amount: amount,
        category: cat(category),
        date: date,
        repeat: repeat,
      );

  group('checkPurchase', () {
    test('warns on entertainment when it would leave little money', () async {
      final s = await newState();
      s.addTransaction(tx('Food & Dining', 2400, DateTime(2099, 3, 2)));
      final w = BudgetAdvisor(s, now: now)
          .checkPurchase(cat('Entertainment'), 300, now);
      expect(w, isNotNull);
      expect(w!.kind, AdvisorTipKind.overspending);
      expect(w.message, contains('\$300.00'));
      expect(w.message, contains('rent and utilities'));
      s.dispose();
    });

    test('mentions bills still due this month', () async {
      final s = await newState();
      s.addTransaction(tx('Food & Dining', 1200, DateTime(2099, 3, 2)));
      s.addTransaction(tx('Bills & Utilities', 1200, DateTime(2099, 2, 28),
          title: 'Rent', repeat: RepeatFrequency.monthly));
      final a = BudgetAdvisor(s, now: now);
      expect(a.upcomingBillsTotal, 1200);
      final w = a.checkPurchase(cat('Entertainment'), 200, now);
      expect(w, isNotNull);
      expect(w!.message, contains('Rent'));
      s.dispose();
    });

    test('never blocks necessities', () async {
      final s = await newState();
      s.addTransaction(tx('Food & Dining', 2900, DateTime(2099, 3, 2)));
      final a = BudgetAdvisor(s, now: now);
      expect(a.checkPurchase(cat('Bills & Utilities'), 500, now), isNull);
      s.dispose();
    });

    test('stays quiet when there is plenty of room', () async {
      final s = await newState();
      s.addTransaction(tx('Food & Dining', 300, DateTime(2099, 3, 2)));
      final a = BudgetAdvisor(s, now: now);
      expect(a.checkPurchase(cat('Entertainment'), 40, now), isNull);
      s.dispose();
    });

    test('warns when a category limit would be hit', () async {
      final s = await newState();
      s.setBudgetLimit(cat('Entertainment'), 100);
      s.addTransaction(tx('Entertainment', 60, DateTime(2099, 3, 2)));
      final w = BudgetAdvisor(s, now: now)
          .checkPurchase(cat('Entertainment'), 40, now);
      expect(w, isNotNull);
      expect(w!.message, contains('limit'));
      s.dispose();
    });

    test('editing only counts the increase', () async {
      final s = await newState();
      s.addTransaction(tx('Food & Dining', 2300, DateTime(2099, 3, 2)));
      s.addTransaction(tx('Entertainment', 250, DateTime(2099, 3, 3)));
      final a = BudgetAdvisor(s, now: now);
      expect(
          a.checkPurchase(cat('Entertainment'), 250, now, replacing: 250),
          isNull);
      s.dispose();
    });
  });

  group('tips', () {
    test('close to budget gives overspending + necessities tips', () async {
      final s = await newState();
      s.addTransaction(tx('Entertainment', 400, DateTime(2099, 3, 5)));
      s.addTransaction(tx('Food & Dining', 2300, DateTime(2099, 3, 6)));
      final tips = BudgetAdvisor(s, now: now).tips();
      expect(tips.map((t) => t.kind), [
        AdvisorTipKind.overspending,
        AdvisorTipKind.prioritizeNecessities,
      ]);
      expect(tips.first.message, contains('\$400.00'));
      s.dispose();
    });

    test('warnings ignore the remind-to-spend toggle', () async {
      final s = await newState();
      s.setRemindToSpend(false);
      s.addTransaction(tx('Food & Dining', 2900, DateTime(2099, 3, 6)));
      expect(BudgetAdvisor(s, now: now).tips(), isNotEmpty);
      s.dispose();
    });

    test('low spending reminds the user they can spend', () async {
      final s = await newState();
      s.addTransaction(tx('Food & Dining', 200, DateTime(2099, 3, 6)));
      final tips = BudgetAdvisor(s, now: now).tips();
      expect(tips.single.kind, AdvisorTipKind.canSpend);
      s.dispose();
    });

    test('can-spend reminder respects the toggle', () async {
      final s = await newState();
      s.setRemindToSpend(false);
      s.addTransaction(tx('Food & Dining', 200, DateTime(2099, 3, 6)));
      expect(BudgetAdvisor(s, now: now).tips(), isEmpty);
      s.dispose();
    });

    test('no can-spend reminder early in the month', () async {
      final s = await newState();
      s.addTransaction(tx('Food & Dining', 10, DateTime(2099, 3, 2)));
      expect(BudgetAdvisor(s, now: DateTime(2099, 3, 3)).tips(), isEmpty);
      s.dispose();
    });

    test('no tips without an income', () async {
      final s = await newState(income: 0);
      s.addTransaction(tx('Entertainment', 999, DateTime(2099, 3, 2)));
      expect(BudgetAdvisor(s, now: now).tips(), isEmpty);
      s.dispose();
    });
  });

  test('advisor settings survive a backup round-trip', () async {
    final s = await newState();
    s.setRemindToSpend(false);
    s.setAiTips(true);
    final json = s.exportJson();
    final restored = await newState();
    expect(restored.importJson(json), isTrue);
    expect(restored.remindToSpend, isFalse);
    expect(restored.aiTips, isTrue);
    s.dispose();
    restored.dispose();
  });

  group('AdvisorAi.parseResponse', () {
    Map<String, dynamic> reply(Object payload) => {
          'candidates': [
            {
              'content': {
                'parts': [
                  {'text': jsonEncode(payload)},
                ],
              },
            },
          ],
        };

    test('accepts one rewrite per tip', () {
      expect(AdvisorAi.parseResponse(reply(['a', 'b']), 2), ['a', 'b']);
    });

    test('rejects a count mismatch or garbage', () {
      expect(AdvisorAi.parseResponse(reply(['a']), 2), isNull);
      expect(AdvisorAi.parseResponse({'candidates': []}, 1), isNull);
      expect(AdvisorAi.parseResponse(reply({'x': 1}), 1), isNull);
    });
  });
}
