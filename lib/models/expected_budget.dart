enum BudgetPeriod { daily, weekly, monthly }

extension BudgetPeriodLabel on BudgetPeriod {
  String get label => switch (this) {
        BudgetPeriod.daily => 'Daily',
        BudgetPeriod.weekly => 'Weekly',
        BudgetPeriod.monthly => 'Monthly',
      };
}

/// Average days per month over a year (365.25 / 12). Using this avoids the
/// off-by-2-day drift you'd get from "30 days per month".
const double _daysPerMonth = 30.4375;
const double _daysPerWeek = 7;

class ExpectedBudget {
  final double amount;
  final BudgetPeriod period;

  const ExpectedBudget({required this.amount, required this.period});

  double get dailyEquivalent => switch (period) {
        BudgetPeriod.daily => amount,
        BudgetPeriod.weekly => amount / _daysPerWeek,
        BudgetPeriod.monthly => amount / _daysPerMonth,
      };

  double get weeklyEquivalent => dailyEquivalent * _daysPerWeek;
  double get monthlyEquivalent => dailyEquivalent * _daysPerMonth;

  Map<String, dynamic> toJson() => {
        'amount': amount,
        'period': period.name,
      };

  factory ExpectedBudget.fromJson(Map<String, dynamic> j) => ExpectedBudget(
        amount: (j['amount'] as num).toDouble(),
        period: BudgetPeriod.values.firstWhere(
          (p) => p.name == (j['period'] as String?),
          orElse: () => BudgetPeriod.monthly,
        ),
      );
}
