import 'package:budget_buddy/models/expense_category.dart';
import 'package:budget_buddy/models/transaction.dart';
import 'package:budget_buddy/state/app_state.dart';
import 'package:budget_buddy/widgets/responsive.dart';

/// Nice-to-have spending the advisor nudges the user to skip when money is
/// tight.
const kDiscretionaryCategories = {'Entertainment', 'Shopping'};

/// Must-pay spending (rent, utilities, medical) the advisor tells the user to
/// cover first.
const kNecessityCategories = {'Bills & Utilities', 'Health'};

enum AdvisorTipKind { overspending, prioritizeNecessities, canSpend }

class AdvisorTip {
  final AdvisorTipKind kind;
  final String title;
  final String message;

  const AdvisorTip({
    required this.kind,
    required this.title,
    required this.message,
  });

  bool get isWarning => kind != AdvisorTipKind.canSpend;
}

/// A recurring necessity whose next occurrence falls later this month and so
/// isn't counted in this month's spending yet.
class UpcomingBill {
  final String title;
  final double amount;
  final DateTime due;
  const UpcomingBill(this.title, this.amount, this.due);
}

/// On-device budget coach. Pure and deterministic: everything is derived from
/// [AppState] and [now], so it works offline and the overspending warnings
/// can't be switched off by a missing API key or network.
class BudgetAdvisor {
  final AppState state;
  final DateTime now;

  BudgetAdvisor(this.state, {DateTime? now}) : now = now ?? DateTime.now();

  /// Below this share of income left (after upcoming bills), the user is
  /// "close to their budget".
  static const closeThreshold = 0.15;

  /// The can-spend reminder only fires once this much of the month is gone,
  /// so a quiet first week doesn't read as "under-spending".
  static const minMonthElapsed = 0.25;

  /// ...and only when spending is under this fraction of the even pace.
  static const underPaceFactor = 0.5;

  bool _inThisMonth(DateTime d) => d.year == now.year && d.month == now.month;

  int get _daysInMonth => DateTime(now.year, now.month + 1, 0).day;

  double get _income => state.monthlyIncome;

  double get spentThisMonth => state.transactions
      .where((t) => _inThisMonth(t.date))
      .fold(0.0, (s, t) => s + t.amount);

  double get savedThisMonth => state.savingsGoals.fold(
      0.0,
      (sum, g) =>
          sum +
          g.deposits
              .where((d) => _inThisMonth(d.date))
              .fold(0.0, (s, d) => s + d.amount));

  double _spentIn(Set<String> categories) => state.transactions
      .where((t) => _inThisMonth(t.date) && categories.contains(t.category.name))
      .fold(0.0, (s, t) => s + t.amount);

  double get discretionaryThisMonth => _spentIn(kDiscretionaryCategories);

  /// Recurring necessities still due later this month, soonest first.
  List<UpcomingBill> get upcomingBills {
    final today = DateTime(now.year, now.month, now.day);
    final latestBySeries = <String, Transaction>{};
    for (final t in state.transactions) {
      if (t.repeat == RepeatFrequency.none ||
          !kNecessityCategories.contains(t.category.name)) {
        continue;
      }
      final cur = latestBySeries[t.seriesId];
      if (cur == null || t.date.isAfter(cur.date)) latestBySeries[t.seriesId] = t;
    }
    final bills = <UpcomingBill>[];
    for (final t in latestBySeries.values) {
      var next = AppState.nextOccurrence(
          DateTime(t.date.year, t.date.month, t.date.day), t.repeat);
      while (_inThisMonth(next)) {
        if (next.isAfter(today)) bills.add(UpcomingBill(t.title, t.amount, next));
        next = AppState.nextOccurrence(next, t.repeat);
      }
    }
    bills.sort((a, b) => a.due.compareTo(b.due));
    return bills;
  }

  double get upcomingBillsTotal =>
      upcomingBills.fold(0.0, (s, b) => s + b.amount);

  /// Income left this month after spending, savings, and bills still due.
  double get safeToSpend =>
      _income - spentThisMonth - savedThisMonth - upcomingBillsTotal;

  bool _isClose(double remaining) =>
      remaining < _income * closeThreshold;

  bool get isCloseToBudget => _income > 0 && _isClose(safeToSpend);

  // ── Purchase-time check (always on) ────────────────────────────────────────

  /// Returns a warning if adding [amount] in [category] on [date] is a
  /// nice-to-have the user can't comfortably afford right now, else null.
  /// [replacing] is the amount of a transaction being edited, so editing an
  /// existing expense only counts the increase.
  AdvisorTip? checkPurchase(
    ExpenseCategory category,
    double amount,
    DateTime date, {
    double replacing = 0,
  }) {
    if (!kDiscretionaryCategories.contains(category.name)) return null;
    if (!_inThisMonth(date) || _income <= 0) return null;
    final extra = amount - replacing;
    if (extra <= 0) return null;

    final remainingAfter = safeToSpend - extra;
    final limit = state.getBudgetLimit(category.name) ?? 0;
    final categoryAfter =
        _spentIn({category.name}) - replacing + amount;
    final overCategory = limit > 0 && categoryAfter >= limit * 0.9;

    if (!_isClose(remainingAfter) && !overCategory) return null;

    final label = category.name.toLowerCase();
    final buf = StringBuffer();
    if (remainingAfter < 0) {
      buf.write('This ${formatCurrency(amount)} $label purchase would put you '
          '${formatCurrency(-remainingAfter)} over your budget for the month.');
    } else if (_isClose(remainingAfter)) {
      buf.write('This ${formatCurrency(amount)} $label purchase would leave '
          'only ${formatCurrency(remainingAfter)} for the rest of the month.');
    } else {
      buf.write('This would bring $label to '
          '${formatCurrency(categoryAfter, decimals: 0)} of your '
          '${formatCurrency(limit, decimals: 0)} limit.');
    }
    final bills = upcomingBills;
    if (bills.isNotEmpty) {
      buf.write(' You still have ${formatCurrency(upcomingBillsTotal)} in '
          'bills due (${_billNames(bills)}).');
    }
    buf.write(' Consider skipping or postponing it and covering necessities '
        'like rent and utilities first.');
    return AdvisorTip(
      kind: AdvisorTipKind.overspending,
      title: 'Before you buy this…',
      message: buf.toString(),
    );
  }

  // ── Dashboard tips ─────────────────────────────────────────────────────────

  /// Tips for the dashboard, most urgent first. Overspending and necessity
  /// tips are always produced when they apply; the can-spend reminder only
  /// when [AppState.remindToSpend] is on.
  List<AdvisorTip> tips() {
    if (_income <= 0) return const [];
    final tips = <AdvisorTip>[];
    final remaining = safeToSpend;
    final bills = upcomingBills;

    if (_isClose(remaining)) {
      final discretionary = discretionaryThisMonth;
      final head = remaining < 0
          ? 'You\'re on track to overspend by ${formatCurrency(-remaining)} '
              'this month.'
          : 'Only ${formatCurrency(remaining)} is left for the rest of the '
              'month.';
      final tail = discretionary > 0
          ? ' You\'ve spent ${formatCurrency(discretionary)} on entertainment '
              'and shopping so far — hold off on more until next month.'
          : ' Hold off on entertainment and other extras until next month.';
      tips.add(AdvisorTip(
        kind: AdvisorTipKind.overspending,
        title: 'Close to your budget',
        message: head + tail,
      ));
      tips.add(AdvisorTip(
        kind: AdvisorTipKind.prioritizeNecessities,
        title: 'Cover necessities first',
        message: bills.isNotEmpty
            ? 'Set aside ${formatCurrency(upcomingBillsTotal)} for '
                '${_billNames(bills)} before spending on anything else.'
            : 'Make sure rent, utilities, and groceries are covered before '
                'spending on anything else.',
      ));
      return tips;
    }

    if (state.remindToSpend) {
      final elapsed = now.day / _daysInMonth;
      final usedShare = (spentThisMonth + savedThisMonth) / _income;
      final daysLeft = _daysInMonth - now.day + 1;
      if (elapsed >= minMonthElapsed &&
          usedShare < elapsed * underPaceFactor &&
          remaining > 0) {
        final perDay = remaining / daysLeft;
        tips.add(AdvisorTip(
          kind: AdvisorTipKind.canSpend,
          title: 'You have room to enjoy yourself',
          message: 'You\'ve used ${(usedShare * 100).round()}% of your income '
              'with ${(elapsed * 100).round()}% of the month gone. After '
              'bills you could spend about ${formatCurrency(perDay, decimals: 0)} '
              'a day and still stay on budget — it\'s okay to treat yourself.',
        ));
      }
    }
    return tips;
  }

  static String _billNames(List<UpcomingBill> bills) {
    final names = bills.map((b) => b.title).toSet().toList();
    if (names.length <= 3) return names.join(', ');
    return '${names.take(3).join(', ')} and ${names.length - 3} more';
  }
}
