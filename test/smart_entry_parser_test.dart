import 'package:flutter_test/flutter_test.dart';
import 'package:budget_buddy/models/transaction.dart';
import 'package:budget_buddy/services/smart_entry_parser.dart';

void main() {
  // 2026-08-07 is a Friday.
  final now = DateTime(2026, 8, 7);

  ParsedEntry parse(String input) => SmartEntryParser.parse(input, now: now);

  test('coffee 4.50 yesterday', () {
    final p = parse('coffee 4.50 yesterday');
    expect(p.title, 'Coffee');
    expect(p.amount, 4.50);
    expect(p.category?.name, 'Food & Dining');
    expect(p.date, DateTime(2026, 8, 6));
    expect(p.repeat, RepeatFrequency.none);
  });

  test('dollar sign and category keyword', () {
    final p = parse(r'$12 uber');
    expect(p.amount, 12);
    expect(p.category?.name, 'Transport');
    expect(p.title, 'Uber');
  });

  test('netflix 15.99 monthly sets repeat and category', () {
    final p = parse('netflix 15.99 monthly');
    expect(p.amount, 15.99);
    expect(p.category?.name, 'Entertainment');
    expect(p.repeat, RepeatFrequency.monthly);
    expect(p.title, 'Netflix');
  });

  test('rent 1,200 every month', () {
    final p = parse('rent 1,200 every month');
    expect(p.amount, 1200);
    expect(p.category?.name, 'Bills & Utilities');
    expect(p.repeat, RepeatFrequency.monthly);
    expect(p.title, 'Rent');
  });

  test('slash date in the past keeps current year', () {
    final p = parse('gym 30 on 3/5');
    expect(p.amount, 30);
    expect(p.category?.name, 'Health');
    expect(p.date, DateTime(2026, 3, 5));
  });

  test('slash date in the future rolls back a year', () {
    final p = parse('gift 20 12/25');
    expect(p.date, DateTime(2025, 12, 25));
    expect(p.category?.name, 'Shopping');
  });

  test('month-name date and explicit year', () {
    expect(parse('books 25 mar 5').date, DateTime(2026, 3, 5));
    expect(parse('books 25 5 mar').date, DateTime(2026, 3, 5));
    expect(parse('books 25 mar 5 2025').date, DateTime(2025, 3, 5));
  });

  test('N days ago', () {
    final p = parse('dinner 40 5 days ago');
    expect(p.amount, 40);
    expect(p.date, DateTime(2026, 8, 2));
    expect(p.title, 'Dinner');
  });

  test('weekday resolves to most recent occurrence', () {
    expect(parse('lunch 10 monday').date, DateTime(2026, 8, 3));
    // Same weekday as "now" means today...
    expect(parse('lunch 10 friday').date, DateTime(2026, 8, 7));
    // ...unless prefixed with "last".
    expect(parse('lunch 10 last friday').date, DateTime(2026, 7, 31));
  });

  test('stopwords are dropped from the title', () {
    final p = parse('spent 20 on lunch with sam');
    expect(p.amount, 20);
    expect(p.title, 'Lunch Sam');
    expect(p.category?.name, 'Food & Dining');
  });

  test('amount alone leaves title empty', () {
    final p = parse('12.50');
    expect(p.amount, 12.50);
    expect(p.title, isEmpty);
    expect(p.category, isNull);
  });

  test('empty input parses to empty entry', () {
    expect(parse('').isEmpty, isTrue);
  });

  test('date token is not eaten as the amount', () {
    // "5" belongs to "mar 5", so the amount must be 25.
    final p = parse('books 25 mar 5');
    expect(p.amount, 25);
  });
}
