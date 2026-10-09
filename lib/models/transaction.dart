import 'dart:math';
import 'package:budget_buddy/models/expense_category.dart';
import 'package:budget_buddy/constants/categories.dart';

enum RepeatFrequency { none, daily, weekly, monthly, yearly }

extension RepeatFrequencyLabel on RepeatFrequency {
  String get label => switch (this) {
        RepeatFrequency.none => 'One-time',
        RepeatFrequency.daily => 'Daily',
        RepeatFrequency.weekly => 'Weekly',
        RepeatFrequency.monthly => 'Monthly',
        RepeatFrequency.yearly => 'Yearly',
      };
}

class Transaction {
  final String id;

  /// Groups the occurrences of one recurring transaction. Equals [id] for
  /// one-time transactions and for the first occurrence of a series.
  final String seriesId;
  final String title;
  final double amount;
  final ExpenseCategory category;
  final DateTime date;
  final String? note;
  final RepeatFrequency repeat;

  Transaction._({
    required this.id,
    required this.seriesId,
    required this.title,
    required this.amount,
    required this.category,
    required this.date,
    required this.note,
    required this.repeat,
  });

  factory Transaction({
    required String title,
    required double amount,
    required ExpenseCategory category,
    required DateTime date,
    String? note,
    String? id,
    String? seriesId,
    RepeatFrequency repeat = RepeatFrequency.none,
  }) {
    final resolvedId = id ??
        (DateTime.now().millisecondsSinceEpoch.toString() +
            Random().nextInt(9999).toString());
    return Transaction._(
      id: resolvedId,
      seriesId: seriesId ?? resolvedId,
      title: title,
      amount: amount,
      category: category,
      date: date,
      note: note,
      repeat: repeat,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'seriesId': seriesId,
        'title': title,
        'amount': amount,
        'category': category.name,
        'date': date.millisecondsSinceEpoch,
        'note': note,
        'repeat': repeat.name,
      };

  factory Transaction.fromJson(Map<String, dynamic> j) {
    final catName = j['category'] as String;
    final cat = kCategories.firstWhere(
      (c) => c.name == catName,
      orElse: () => kCategories.last,
    );
    final id = j['id'] as String;
    return Transaction(
      id: id,
      seriesId: (j['seriesId'] as String?) ?? id,
      title: j['title'] as String,
      amount: (j['amount'] as num).toDouble(),
      category: cat,
      date: DateTime.fromMillisecondsSinceEpoch(j['date'] as int),
      note: j['note'] as String?,
      repeat: RepeatFrequency.values.firstWhere(
        (r) => r.name == (j['repeat'] as String?),
        orElse: () => RepeatFrequency.none,
      ),
    );
  }

  static const _unset = Object();

  Transaction copyWith({
    String? title,
    double? amount,
    ExpenseCategory? category,
    DateTime? date,
    Object? note = _unset,
    RepeatFrequency? repeat,
  }) =>
      Transaction(
        id: id,
        seriesId: seriesId,
        title: title ?? this.title,
        amount: amount ?? this.amount,
        category: category ?? this.category,
        date: date ?? this.date,
        note: identical(note, _unset) ? this.note : note as String?,
        repeat: repeat ?? this.repeat,
      );
}
