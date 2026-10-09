import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:budget_buddy/constants/categories.dart';
import 'package:budget_buddy/constants/currencies.dart';
import 'package:budget_buddy/models/savings_goal.dart';
import 'package:budget_buddy/models/transaction.dart';
import 'package:budget_buddy/state/app_state.dart';
import 'package:budget_buddy/widgets/responsive.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppCurrency.symbol = '\$';
  });

  Future<AppState> newState() async {
    final s = AppState();
    await s.ready;
    return s;
  }

  Transaction tx(double amount, DateTime date,
          {String title = 'Coffee',
          RepeatFrequency repeat = RepeatFrequency.none}) =>
      Transaction(
        title: title,
        amount: amount,
        category: kCategories.first,
        date: date,
        repeat: repeat,
      );

  test('month-scoped totals ignore other months', () async {
    final s = await newState();
    s.monthlyIncome = 3000;
    final now = DateTime.now();
    s.addTransaction(tx(100, now));
    s.addTransaction(tx(50, DateTime(now.year, now.month, now.day)));
    s.addTransaction(tx(999, DateTime(now.year, now.month - 2, 15)));

    expect(s.spentThisMonth, 150);
    expect(s.totalSpent, 1149);
    expect(s.monthBalance, 3000 - 150);
    expect(s.spendingByCategoryThisMonth[kCategories.first.name], 150);
    expect(s.spentInCategoryThisMonth(kCategories.first.name), 150);
    s.dispose();
  });

  test('savings deposits this month reduce monthBalance', () async {
    final s = await newState();
    s.monthlyIncome = 2000;
    s.addSavingsGoal(SavingsGoal(name: 'Trip', target: 500, icon: Icons.flight_rounded));
    s.addToSavings(0, 200);
    expect(s.savedThisMonth, 200);
    expect(s.monthBalance, 1800);
    s.dispose();
  });

  test('weekly recurring transaction backfills missed occurrences', () async {
    final s = await newState();
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day - 21);
    s.addTransaction(
        tx(15, start, title: 'Gym', repeat: RepeatFrequency.weekly));

    // Original + 3 backfilled weeks.
    expect(s.transactions.length, 4);
    expect(s.transactions.every((t) => t.title == 'Gym'), isTrue);
    expect(s.transactions.every((t) => t.repeat == RepeatFrequency.weekly),
        isTrue);
    final seriesIds = s.transactions.map((t) => t.seriesId).toSet();
    expect(seriesIds.length, 1, reason: 'all occurrences share one series');
    // Newest first.
    expect(s.transactions.first.date.isAfter(s.transactions.last.date), isTrue);
    s.dispose();
  });

  test('monthly recurring posts one occurrence per month', () async {
    final s = await newState();
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 65));
    s.addTransaction(
        tx(9.99, start, title: 'Streaming', repeat: RepeatFrequency.monthly));
    expect(s.transactions.length, 3); // original + 2 months
    s.dispose();
  });

  test('recurring backfill persists across reload', () async {
    final s = await newState();
    final now = DateTime.now();
    s.addTransaction(tx(15, DateTime(now.year, now.month, now.day - 7),
        title: 'Gym', repeat: RepeatFrequency.weekly));
    expect(s.transactions.length, 2);
    // Flush the debounced save.
    await Future<void>.delayed(const Duration(milliseconds: 400));
    s.dispose();

    final s2 = await newState();
    expect(s2.transactions.length, 2, reason: 'no duplicate backfill');
    s2.dispose();
  });

  test('csv export escapes quotes and commas', () async {
    final s = await newState();
    s.addTransaction(
        tx(12.5, DateTime(2026, 3, 5), title: 'Lunch, "special"'));
    final csv = s.exportCsv();
    expect(csv, contains('Date,Title,Category,Amount,Note,Repeat'));
    expect(csv, contains('"Lunch, ""special"""'));
    expect(csv, contains('2026-03-05'));
    expect(csv, contains('12.50'));
    s.dispose();
  });

  test('json backup roundtrip restores state', () async {
    final s = await newState();
    s.updateProfile(name: 'Sam', income: 4200);
    s.addTransaction(tx(75, DateTime(2026, 6, 1), title: 'Groceries'));
    s.setCurrency('EUR');
    final backup = s.exportJson();
    s.dispose();

    SharedPreferences.setMockInitialValues({});
    final s2 = await newState();
    expect(s2.importJson(backup), isTrue);
    expect(s2.userName, 'Sam');
    expect(s2.monthlyIncome, 4200);
    expect(s2.transactions.single.title, 'Groceries');
    expect(s2.currencyCode, 'EUR');
    s2.dispose();
  });

  test('importJson rejects invalid payloads without touching state', () async {
    final s = await newState();
    s.updateProfile(name: 'Sam', income: 4200);
    expect(s.importJson('not json at all'), isFalse);
    expect(s.importJson('{"unrelated": true}'), isFalse);
    expect(s.userName, 'Sam');
    s.dispose();
  });

  test('setCurrency changes formatCurrency output globally', () async {
    final s = await newState();
    s.setCurrency('GBP');
    expect(formatCurrency(1234.5), '£1,234.50');
    s.setCurrency('USD');
    expect(formatCurrency(1234.5), '\$1,234.50');
    s.dispose();
  });

  test('copyWith can clear the note and change repeat', () {
    final t = tx(10, DateTime(2026, 1, 1)).copyWith(note: 'hello');
    expect(t.note, 'hello');
    final cleared = t.copyWith(note: null, repeat: RepeatFrequency.monthly);
    expect(cleared.note, isNull);
    expect(cleared.repeat, RepeatFrequency.monthly);
    expect(cleared.id, t.id);
    expect(cleared.seriesId, t.seriesId);
  });
}
