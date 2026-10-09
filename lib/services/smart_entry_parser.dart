import 'package:budget_buddy/constants/categories.dart';
import 'package:budget_buddy/models/expense_category.dart';
import 'package:budget_buddy/models/transaction.dart';

/// Result of parsing a natural-language expense line.
/// Fields are null/empty when the input didn't mention them.
class ParsedEntry {
  final String title;
  final double? amount;
  final ExpenseCategory? category;
  final DateTime? date;
  final RepeatFrequency repeat;

  const ParsedEntry({
    this.title = '',
    this.amount,
    this.category,
    this.date,
    this.repeat = RepeatFrequency.none,
  });

  bool get isEmpty =>
      title.isEmpty &&
      amount == null &&
      category == null &&
      date == null &&
      repeat == RepeatFrequency.none;
}

/// Turns lines like "coffee 4.50 yesterday" or "netflix 15.99 monthly" into
/// a structured expense. Runs entirely on-device — no network, no cost.
class SmartEntryParser {
  static const _weekdays = {
    'monday': 1, 'mon': 1,
    'tuesday': 2, 'tue': 2, 'tues': 2,
    'wednesday': 3, 'wed': 3,
    'thursday': 4, 'thu': 4, 'thurs': 4,
    'friday': 5, 'fri': 5,
    'saturday': 6, 'sat': 6,
    'sunday': 7, 'sun': 7,
  };

  static const _months = {
    'january': 1, 'jan': 1,
    'february': 2, 'feb': 2,
    'march': 3, 'mar': 3,
    'april': 4, 'apr': 4,
    'may': 5,
    'june': 6, 'jun': 6,
    'july': 7, 'jul': 7,
    'august': 8, 'aug': 8,
    'september': 9, 'sep': 9, 'sept': 9,
    'october': 10, 'oct': 10,
    'november': 11, 'nov': 11,
    'december': 12, 'dec': 12,
  };

  static const _repeatWords = {
    'daily': RepeatFrequency.daily,
    'weekly': RepeatFrequency.weekly,
    'monthly': RepeatFrequency.monthly,
    'yearly': RepeatFrequency.yearly,
    'annually': RepeatFrequency.yearly,
    'subscription': RepeatFrequency.monthly,
  };

  static const _repeatUnits = {
    'day': RepeatFrequency.daily,
    'week': RepeatFrequency.weekly,
    'month': RepeatFrequency.monthly,
    'year': RepeatFrequency.yearly,
  };

  // keyword → category name from kCategories
  static const _categoryKeywords = {
    // Food & Dining
    'coffee': 'Food & Dining', 'cafe': 'Food & Dining',
    'starbucks': 'Food & Dining', 'lunch': 'Food & Dining',
    'dinner': 'Food & Dining', 'breakfast': 'Food & Dining',
    'brunch': 'Food & Dining', 'restaurant': 'Food & Dining',
    'pizza': 'Food & Dining', 'burger': 'Food & Dining',
    'sushi': 'Food & Dining', 'grocery': 'Food & Dining',
    'groceries': 'Food & Dining', 'food': 'Food & Dining',
    'snack': 'Food & Dining', 'takeout': 'Food & Dining',
    'mcdonalds': 'Food & Dining', 'chipotle': 'Food & Dining',
    'doordash': 'Food & Dining', 'ubereats': 'Food & Dining',
    'bar': 'Food & Dining', 'drinks': 'Food & Dining',
    'beer': 'Food & Dining', 'tea': 'Food & Dining',
    // Transport
    'uber': 'Transport', 'lyft': 'Transport', 'taxi': 'Transport',
    'gas': 'Transport', 'fuel': 'Transport', 'petrol': 'Transport',
    'parking': 'Transport', 'bus': 'Transport', 'train': 'Transport',
    'metro': 'Transport', 'subway': 'Transport', 'toll': 'Transport',
    'flight': 'Transport', 'car': 'Transport',
    // Shopping
    'amazon': 'Shopping', 'clothes': 'Shopping', 'clothing': 'Shopping',
    'shoes': 'Shopping', 'shopping': 'Shopping', 'mall': 'Shopping',
    'target': 'Shopping', 'walmart': 'Shopping', 'ikea': 'Shopping',
    'gift': 'Shopping',
    // Entertainment
    'netflix': 'Entertainment', 'spotify': 'Entertainment',
    'hulu': 'Entertainment', 'disney': 'Entertainment',
    'movie': 'Entertainment', 'movies': 'Entertainment',
    'cinema': 'Entertainment', 'game': 'Entertainment',
    'games': 'Entertainment', 'concert': 'Entertainment',
    'tickets': 'Entertainment', 'youtube': 'Entertainment',
    'steam': 'Entertainment',
    // Bills & Utilities
    'rent': 'Bills & Utilities', 'mortgage': 'Bills & Utilities',
    'electricity': 'Bills & Utilities', 'electric': 'Bills & Utilities',
    'water': 'Bills & Utilities', 'internet': 'Bills & Utilities',
    'wifi': 'Bills & Utilities', 'phone': 'Bills & Utilities',
    'bill': 'Bills & Utilities', 'bills': 'Bills & Utilities',
    'utilities': 'Bills & Utilities', 'insurance': 'Bills & Utilities',
    // Health
    'doctor': 'Health', 'dentist': 'Health', 'pharmacy': 'Health',
    'medicine': 'Health', 'gym': 'Health', 'fitness': 'Health',
    'therapy': 'Health', 'hospital': 'Health', 'vitamins': 'Health',
    // Education
    'tuition': 'Education', 'course': 'Education', 'book': 'Education',
    'books': 'Education', 'school': 'Education', 'udemy': 'Education',
    'class': 'Education', 'textbook': 'Education',
  };

  static const _stopwords = {
    'for', 'on', 'at', 'in', 'the', 'a', 'an', 'and', 'of', 'my', 'to',
    'from', 'with', 'spent', 'paid', 'bought', 'buy', 'got',
  };

  /// [now] is injectable for tests.
  static ParsedEntry parse(String input, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final today = DateTime(reference.year, reference.month, reference.day);

    final tokens = input
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .map(_cleanToken)
        .where((t) => t.isNotEmpty)
        .toList();
    final consumed = List<bool>.filled(tokens.length, false);

    final repeat = _parseRepeat(tokens, consumed);
    final date = _parseDate(tokens, consumed, today);
    final amount = _parseAmount(tokens, consumed);
    final category = _parseCategory(tokens, consumed);

    final titleWords = <String>[];
    for (var i = 0; i < tokens.length; i++) {
      if (consumed[i] || _stopwords.contains(tokens[i])) continue;
      titleWords.add(_capitalize(tokens[i]));
    }

    return ParsedEntry(
      title: titleWords.join(' '),
      amount: amount,
      category: category,
      date: date,
      repeat: repeat,
    );
  }

  static String _cleanToken(String t) =>
      t.replaceAll(RegExp(r'^[^\w$€£¥₹.\d]+|[!?,;:.]+$'), '');

  static String _capitalize(String w) =>
      w.isEmpty ? w : w[0].toUpperCase() + w.substring(1);

  static RepeatFrequency _parseRepeat(List<String> tokens, List<bool> used) {
    for (var i = 0; i < tokens.length; i++) {
      final single = _repeatWords[tokens[i]];
      if (single != null) {
        used[i] = true;
        return single;
      }
      if ((tokens[i] == 'every' || tokens[i] == 'per' || tokens[i] == 'each') &&
          i + 1 < tokens.length) {
        final unit = _repeatUnits[tokens[i + 1]];
        if (unit != null) {
          used[i] = used[i + 1] = true;
          return unit;
        }
      }
    }
    return RepeatFrequency.none;
  }

  static DateTime? _parseDate(
      List<String> tokens, List<bool> used, DateTime today) {
    for (var i = 0; i < tokens.length; i++) {
      if (used[i]) continue;
      final t = tokens[i];

      if (t == 'today' || t == 'tonight') {
        used[i] = true;
        return today;
      }
      if (t == 'yesterday') {
        used[i] = true;
        return today.subtract(const Duration(days: 1));
      }

      // "last week" / "last month" / "last friday"
      if (t == 'last' && i + 1 < tokens.length) {
        final next = tokens[i + 1];
        if (next == 'week') {
          used[i] = used[i + 1] = true;
          return today.subtract(const Duration(days: 7));
        }
        if (next == 'month') {
          used[i] = used[i + 1] = true;
          return DateTime(today.year, today.month - 1, today.day);
        }
        final weekday = _weekdays[next];
        if (weekday != null) {
          used[i] = used[i + 1] = true;
          var diff = (today.weekday - weekday) % 7;
          if (diff == 0) diff = 7;
          return today.subtract(Duration(days: diff));
        }
      }

      // bare weekday → most recent occurrence (today if it matches)
      final weekday = _weekdays[t];
      if (weekday != null) {
        used[i] = true;
        final diff = (today.weekday - weekday) % 7;
        return today.subtract(Duration(days: diff));
      }

      // "3 days ago"
      if (RegExp(r'^\d{1,3}$').hasMatch(t) &&
          i + 2 < tokens.length &&
          (tokens[i + 1] == 'day' || tokens[i + 1] == 'days') &&
          tokens[i + 2] == 'ago') {
        used[i] = used[i + 1] = used[i + 2] = true;
        return today.subtract(Duration(days: int.parse(t)));
      }

      // "3/5" or "3/5/2026" (month/day[/year])
      final slash =
          RegExp(r'^(\d{1,2})/(\d{1,2})(?:/(\d{2,4}))?$').firstMatch(t);
      if (slash != null) {
        final month = int.parse(slash.group(1)!);
        final day = int.parse(slash.group(2)!);
        if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
          used[i] = true;
          var year = slash.group(3) != null ? int.parse(slash.group(3)!) : today.year;
          if (year < 100) year += 2000;
          return _pastAdjusted(DateTime(year, month, day), today,
              explicitYear: slash.group(3) != null);
        }
      }

      // "mar 5" / "5 mar" (with optional year after). Anchor on the month
      // name and prefer the number AFTER it, so "books 25 mar 5" reads the
      // date as Mar 5 and leaves 25 to be the amount.
      final month = _months[t];
      if (month != null) {
        final isDay = RegExp(r'^\d{1,2}$');
        if (i + 1 < tokens.length &&
            !used[i + 1] &&
            isDay.hasMatch(tokens[i + 1])) {
          used[i] = used[i + 1] = true;
          return _monthDay(
              tokens, used, i + 2, month, int.parse(tokens[i + 1]), today);
        }
        if (i > 0 && !used[i - 1] && isDay.hasMatch(tokens[i - 1])) {
          used[i] = used[i - 1] = true;
          return _monthDay(
              tokens, used, i + 1, month, int.parse(tokens[i - 1]), today);
        }
      }
    }
    return null;
  }

  static DateTime _monthDay(List<String> tokens, List<bool> used,
      int yearIndex, int month, int day, DateTime today) {
    var year = today.year;
    var explicitYear = false;
    if (yearIndex < used.length &&
        RegExp(r'^(19|20)\d{2}$').hasMatch(tokens[yearIndex])) {
      year = int.parse(tokens[yearIndex]);
      used[yearIndex] = true;
      explicitYear = true;
    }
    return _pastAdjusted(DateTime(year, month, day), today,
        explicitYear: explicitYear);
  }

  /// Expenses are in the past — a month/day without a year that lands in the
  /// future means last year (e.g. typing "12/25" in August).
  static DateTime _pastAdjusted(DateTime candidate, DateTime today,
      {required bool explicitYear}) {
    if (!explicitYear && candidate.isAfter(today)) {
      return DateTime(candidate.year - 1, candidate.month, candidate.day);
    }
    return candidate;
  }

  static double? _parseAmount(List<String> tokens, List<bool> used) {
    for (var i = 0; i < tokens.length; i++) {
      if (used[i]) continue;
      var t = tokens[i].replaceAll(RegExp(r'^[$€£¥₹]'), '');
      // thousands separators: 1,200 or 1,200.50
      if (RegExp(r'^\d{1,3}(,\d{3})+(\.\d{1,2})?$').hasMatch(t)) {
        t = t.replaceAll(',', '');
      }
      if (RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(t)) {
        final value = double.parse(t);
        if (value > 0) {
          used[i] = true;
          return value;
        }
      }
    }
    return null;
  }

  static ExpenseCategory? _parseCategory(List<String> tokens, List<bool> used) {
    for (var i = 0; i < tokens.length; i++) {
      if (used[i]) continue;
      final t = tokens[i];
      final name = _categoryKeywords[t] ??
          (t.endsWith('s') ? _categoryKeywords[t.substring(0, t.length - 1)] : null);
      if (name != null) {
        // keyword stays unconsumed — it usually doubles as the title
        for (final cat in kCategories) {
          if (cat.name == name) return cat;
        }
      }
    }
    return null;
  }
}
