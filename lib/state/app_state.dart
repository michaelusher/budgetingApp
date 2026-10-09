import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:budget_buddy/models/expense_category.dart';
import 'package:budget_buddy/models/transaction.dart';
import 'package:budget_buddy/models/budget_limit.dart';
import 'package:budget_buddy/models/savings_goal.dart';
import 'package:budget_buddy/models/savings_deposit.dart';
import 'package:budget_buddy/models/expected_budget.dart';
import 'package:budget_buddy/constants/categories.dart';
import 'package:budget_buddy/constants/currencies.dart';

const _kStorageKey = 'budget_buddy_state_v1';

class AppState extends ChangeNotifier {
  String userName = '';
  double monthlyIncome = 0;
  bool enjoyShopping = false;
  String shoppingFrequency = '';
  bool isOnboarded = false;
  ThemeMode themeMode = ThemeMode.system;
  ExpectedBudget? expectedBudget;
  String currencyCode = 'USD';

  /// Whether the budget advisor reminds the user they have room to spend.
  /// Its overspending warnings have no switch — they're always on.
  bool remindToSpend = true;

  /// Whether the advisor's tips are reworded by Gemini (needs a Gemini key;
  /// sends a short spending summary to Google).
  bool aiTips = false;

  bool isLoaded = false;

  /// Completes when persisted state has been loaded (or load failed cleanly).
  late final Future<void> ready;

  final List<Transaction> _transactions = [];
  final List<BudgetLimit> _budgetLimits = [];
  final List<SavingsGoal> _savingsGoals = [];

  // Memoized derived state — invalidated by [_invalidateDerived].
  Map<String, double>? _spendingCache;
  double? _totalSpentCache;

  Timer? _saveDebounce;

  AppState() {
    ready = _load();
  }

  // ── Getters ────────────────────────────────────────────────────────────────

  List<Transaction> get transactions => List.unmodifiable(_transactions);
  List<BudgetLimit> get budgetLimits => List.unmodifiable(_budgetLimits);
  List<SavingsGoal> get savingsGoals => List.unmodifiable(_savingsGoals);

  double get totalSpent {
    final cached = _totalSpentCache;
    if (cached != null) return cached;
    return _totalSpentCache =
        _transactions.fold<double>(0.0, (sum, t) => sum + t.amount);
  }

  // Savings goals are mutable in-place via deposits, so we don't cache this.
  double get totalSaved =>
      _savingsGoals.fold(0.0, (sum, g) => sum + g.saved);

  Map<String, double> get spendingByCategory {
    if (_spendingCache != null) return _spendingCache!;
    final map = <String, double>{};
    for (final t in _transactions) {
      map[t.category.name] = (map[t.category.name] ?? 0) + t.amount;
    }
    return _spendingCache = map;
  }

  void _invalidateDerived() {
    _spendingCache = null;
    _totalSpentCache = null;
  }

  double spentInCategory(String categoryName) => _transactions
      .where((t) => t.category.name == categoryName)
      .fold(0.0, (sum, t) => sum + t.amount);

  // ── Current-month context ──────────────────────────────────────────────────
  // Income is monthly, so the headline numbers compare against the current
  // month only; all-time totals are kept for history views (charts, profile).

  static bool _isThisMonth(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month;
  }

  double get spentThisMonth => _transactions
      .where((t) => _isThisMonth(t.date))
      .fold(0.0, (sum, t) => sum + t.amount);

  double get savedThisMonth => _savingsGoals.fold(
      0.0,
      (sum, g) =>
          sum +
          g.deposits
              .where((d) => _isThisMonth(d.date))
              .fold(0.0, (s, d) => s + d.amount));

  /// What's left of this month's income after this month's spending and
  /// savings deposits.
  double get monthBalance => monthlyIncome - spentThisMonth - savedThisMonth;

  // Kept for callers that want the all-time view.
  double get balance => monthlyIncome - totalSpent - totalSaved;

  Map<String, double> get spendingByCategoryThisMonth {
    final map = <String, double>{};
    for (final t in _transactions) {
      if (!_isThisMonth(t.date)) continue;
      map[t.category.name] = (map[t.category.name] ?? 0) + t.amount;
    }
    return map;
  }

  double spentInCategoryThisMonth(String categoryName) => _transactions
      .where((t) => t.category.name == categoryName && _isThisMonth(t.date))
      .fold(0.0, (sum, t) => sum + t.amount);

  /// Distinct months (as first-of-month dates) that have transactions,
  /// newest first. Used by the history month filter.
  List<DateTime> get transactionMonths {
    final set = <DateTime>{};
    for (final t in _transactions) {
      set.add(DateTime(t.date.year, t.date.month));
    }
    final list = set.toList()..sort((a, b) => b.compareTo(a));
    return list;
  }

  double get dailyAverageThisMonth {
    final now = DateTime.now();
    final dayOfMonth = now.day;
    if (dayOfMonth == 0) return 0;
    return spentThisMonth / dayOfMonth;
  }

  int get daysLeftInMonth {
    final now = DateTime.now();
    final lastDay = DateTime(now.year, now.month + 1, 0).day;
    return lastDay - now.day;
  }

  double get projectedMonthEndSpend {
    final now = DateTime.now();
    final lastDay = DateTime(now.year, now.month + 1, 0).day;
    return dailyAverageThisMonth * lastDay;
  }

  // ── Mutations ──────────────────────────────────────────────────────────────

  static int _byDateDesc(Transaction a, Transaction b) {
    final byDate = b.date.compareTo(a.date);
    if (byDate != 0) return byDate;
    return b.id.compareTo(a.id); // deterministic tie-break for same-day items
  }

  void addTransaction(Transaction t) {
    _transactions.add(t);
    if (t.repeat != RepeatFrequency.none) {
      _postDueRecurring();
    }
    _transactions.sort(_byDateDesc);
    _changed();
  }

  void updateTransaction(Transaction updated) {
    final idx = _transactions.indexWhere((t) => t.id == updated.id);
    if (idx >= 0) {
      _transactions[idx] = updated;
      _transactions.sort(_byDateDesc);
      _changed();
    }
  }

  void removeTransaction(String id) {
    _transactions.removeWhere((t) => t.id == id);
    _changed();
  }

  /// Stops a recurring series without deleting past occurrences.
  void stopRecurring(String seriesId) {
    for (var i = 0; i < _transactions.length; i++) {
      final t = _transactions[i];
      if (t.seriesId == seriesId && t.repeat != RepeatFrequency.none) {
        _transactions[i] = t.copyWith(repeat: RepeatFrequency.none);
      }
    }
    _changed();
  }

  void setBudgetLimit(ExpenseCategory category, double limit) {
    final idx = _budgetLimits.indexWhere((b) => b.category.name == category.name);
    if (idx >= 0) {
      _budgetLimits[idx].limit = limit;
    } else {
      _budgetLimits.add(BudgetLimit(category: category, limit: limit));
    }
    _changed();
  }

  double? getBudgetLimit(String categoryName) {
    final idx = _budgetLimits.indexWhere((b) => b.category.name == categoryName);
    return idx >= 0 ? _budgetLimits[idx].limit : null;
  }

  void addSavingsGoal(SavingsGoal goal) {
    _savingsGoals.add(goal);
    _changed();
  }

  void addToSavings(int index, double amount, {String? note}) {
    if (index < _savingsGoals.length) {
      _savingsGoals[index].deposits.add(
            SavingsDeposit(amount: amount, date: DateTime.now(), note: note),
          );
      _changed();
    }
  }

  void removeSavingsGoal(int index) {
    if (index < _savingsGoals.length) {
      _savingsGoals.removeAt(index);
      _changed();
    }
  }

  void updateProfile({required String name, required double income}) {
    userName = name;
    monthlyIncome = income;
    _changed();
  }

  void setThemeMode(ThemeMode mode) {
    themeMode = mode;
    _changed();
  }

  void setCurrency(String code) {
    currencyCode = code;
    AppCurrency.symbol = currencyForCode(code).symbol;
    _changed();
  }

  void setExpectedBudget(ExpectedBudget? budget) {
    expectedBudget = budget;
    _changed();
  }

  void setRemindToSpend(bool value) {
    remindToSpend = value;
    _changed();
  }

  void setAiTips(bool value) {
    aiTips = value;
    _changed();
  }

  // ── Recurring transactions ─────────────────────────────────────────────────

  static DateTime nextOccurrence(DateTime from, RepeatFrequency f) {
    switch (f) {
      case RepeatFrequency.daily:
        return DateTime(from.year, from.month, from.day + 1);
      case RepeatFrequency.weekly:
        return DateTime(from.year, from.month, from.day + 7);
      case RepeatFrequency.monthly:
        final lastDay = DateTime(from.year, from.month + 2, 0).day;
        return DateTime(from.year, from.month + 1, math.min(from.day, lastDay));
      case RepeatFrequency.yearly:
        final lastDay = DateTime(from.year + 1, from.month + 1, 0).day;
        return DateTime(from.year + 1, from.month, math.min(from.day, lastDay));
      case RepeatFrequency.none:
        return from;
    }
  }

  /// Creates any occurrences of recurring transactions that have come due,
  /// up to today. Returns how many were posted. Called on launch and when a
  /// recurring transaction is added with a past date.
  int _postDueRecurring() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Only the newest occurrence of each series drives the schedule, so
    // editing/stopping the latest one controls the whole series.
    final latestBySeries = <String, Transaction>{};
    for (final t in _transactions) {
      if (t.repeat == RepeatFrequency.none) continue;
      final cur = latestBySeries[t.seriesId];
      if (cur == null || t.date.isAfter(cur.date)) {
        latestBySeries[t.seriesId] = t;
      }
    }

    var posted = 0;
    const cap = 120; // safety cap against e.g. a daily series years old
    for (final latest in latestBySeries.values) {
      var prev = latest;
      var next = nextOccurrence(
          DateTime(prev.date.year, prev.date.month, prev.date.day),
          prev.repeat);
      while (!next.isAfter(today) && posted < cap) {
        final t = Transaction(
          title: prev.title,
          amount: prev.amount,
          category: prev.category,
          date: next,
          note: prev.note,
          seriesId: prev.seriesId,
          repeat: prev.repeat,
        );
        _transactions.add(t);
        posted++;
        prev = t;
        next = nextOccurrence(next, prev.repeat);
      }
    }
    if (posted > 0) _transactions.sort(_byDateDesc);
    return posted;
  }

  // ── Forecast helpers ───────────────────────────────────────────────────────

  /// Daily income (monthly income spread evenly).
  double get dailyIncome => monthlyIncome / 30.4375;

  /// Daily savings rate implied by [expectedBudget] vs income (can be negative
  /// if expected spend exceeds income). Returns null if no expected budget set.
  double? get dailySavingsRate {
    final eb = expectedBudget;
    if (eb == null) return null;
    return dailyIncome - eb.dailyEquivalent;
  }

  /// Total savings projected over [days] days at the current expected budget.
  /// Negative means the user is projected to spend more than they earn.
  double projectedSavingsOver(int days) {
    final rate = dailySavingsRate;
    if (rate == null) return 0;
    return rate * days;
  }

  void completeOnboarding({
    required String name,
    required double income,
    required bool enjoys,
    required String frequency,
  }) {
    userName = name;
    monthlyIncome = income;
    enjoyShopping = enjoys;
    shoppingFrequency = frequency;
    isOnboarded = true;

    for (final cat in kCategories) {
      setBudgetLimit(cat, income * 0.12);
    }

    _changed();
  }

  // ── Import / export ────────────────────────────────────────────────────────

  static String _csvField(String s) => '"${s.replaceAll('"', '""')}"';

  static String _csvDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Spreadsheet-friendly CSV of [subset] (defaults to all transactions).
  String exportCsv([List<Transaction>? subset]) {
    final buf = StringBuffer('Date,Title,Category,Amount,Note,Repeat\n');
    for (final t in subset ?? _transactions) {
      buf.writeln([
        _csvDate(t.date),
        _csvField(t.title),
        _csvField(t.category.name),
        t.amount.toStringAsFixed(2),
        _csvField(t.note ?? ''),
        t.repeat.name,
      ].join(','));
    }
    return buf.toString();
  }

  /// Full backup of the app state as pretty-printed JSON.
  String exportJson() =>
      const JsonEncoder.withIndent('  ').convert(_toJson());

  /// Restores state from a JSON backup produced by [exportJson].
  /// Returns false (leaving current state untouched) if [raw] isn't valid.
  bool importJson(String raw) {
    try {
      final data = jsonDecode(raw);
      if (data is! Map<String, dynamic> ||
          !(data.containsKey('transactions') || data.containsKey('isOnboarded'))) {
        return false;
      }
      _applyJson(data);
      _changed();
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Persistence ────────────────────────────────────────────────────────────

  void _changed() {
    _invalidateDerived();
    notifyListeners();
    _scheduleSave();
  }

  void _scheduleSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 250), _save);
  }

  Map<String, dynamic> _toJson() => {
        'userName': userName,
        'monthlyIncome': monthlyIncome,
        'enjoyShopping': enjoyShopping,
        'shoppingFrequency': shoppingFrequency,
        'isOnboarded': isOnboarded,
        'themeMode': themeMode.name,
        'currencyCode': currencyCode,
        'expectedBudget': expectedBudget?.toJson(),
        'remindToSpend': remindToSpend,
        'aiTips': aiTips,
        'transactions': _transactions.map((t) => t.toJson()).toList(),
        'budgetLimits': _budgetLimits.map((b) => b.toJson()).toList(),
        'savingsGoals': _savingsGoals.map((g) => g.toJson()).toList(),
      };

  void _applyJson(Map<String, dynamic> data) {
    userName = (data['userName'] as String?) ?? '';
    monthlyIncome = (data['monthlyIncome'] as num?)?.toDouble() ?? 0;
    enjoyShopping = (data['enjoyShopping'] as bool?) ?? false;
    shoppingFrequency = (data['shoppingFrequency'] as String?) ?? '';
    isOnboarded = (data['isOnboarded'] as bool?) ?? false;
    themeMode = ThemeMode.values.firstWhere(
      (m) => m.name == (data['themeMode'] as String?),
      orElse: () => ThemeMode.system,
    );
    currencyCode = (data['currencyCode'] as String?) ?? 'USD';
    AppCurrency.symbol = currencyForCode(currencyCode).symbol;
    final ebJson = data['expectedBudget'];
    expectedBudget = ebJson is Map<String, dynamic>
        ? ExpectedBudget.fromJson(ebJson)
        : null;
    remindToSpend = (data['remindToSpend'] as bool?) ?? true;
    aiTips = (data['aiTips'] as bool?) ?? false;
    _transactions
      ..clear()
      ..addAll(((data['transactions'] as List?) ?? [])
          .map((j) => Transaction.fromJson(j as Map<String, dynamic>)))
      ..sort(_byDateDesc);
    _budgetLimits
      ..clear()
      ..addAll(((data['budgetLimits'] as List?) ?? [])
          .map((j) => BudgetLimit.fromJson(j as Map<String, dynamic>)));
    _savingsGoals
      ..clear()
      ..addAll(((data['savingsGoals'] as List?) ?? [])
          .map((j) => SavingsGoal.fromJson(j as Map<String, dynamic>)));
    _invalidateDerived();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kStorageKey, jsonEncode(_toJson()));
  }

  Future<void> _load() async {
    var postedRecurring = 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kStorageKey);
      if (raw != null) {
        _applyJson(jsonDecode(raw) as Map<String, dynamic>);
        postedRecurring = _postDueRecurring();
      }
    } catch (_) {
      // Corrupted state — start fresh; do not crash the app on launch.
    } finally {
      _invalidateDerived();
      isLoaded = true;
      notifyListeners();
      if (postedRecurring > 0) _scheduleSave();
    }
  }

  Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kStorageKey);
    userName = '';
    monthlyIncome = 0;
    enjoyShopping = false;
    shoppingFrequency = '';
    isOnboarded = false;
    themeMode = ThemeMode.system;
    currencyCode = 'USD';
    AppCurrency.symbol = currencyForCode(currencyCode).symbol;
    expectedBudget = null;
    remindToSpend = true;
    aiTips = false;
    _transactions.clear();
    _budgetLimits.clear();
    _savingsGoals.clear();
    _invalidateDerived();
    notifyListeners();
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    super.dispose();
  }
}
