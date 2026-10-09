import 'package:flutter/material.dart';
import 'package:budget_buddy/state/app_state.dart';
import 'package:budget_buddy/models/expected_budget.dart';
import 'package:budget_buddy/theme/app_theme.dart';
import 'package:budget_buddy/widgets/responsive.dart';
import 'package:budget_buddy/widgets/forecast_chart.dart';

class _Horizon {
  final String label;
  final int days;
  const _Horizon(this.label, this.days);
}

const _horizons = [
  _Horizon('1 week', 7),
  _Horizon('1 month', 30),
  _Horizon('3 months', 91),
  _Horizon('6 months', 182),
  _Horizon('1 year', 365),
  _Horizon('2 years', 730),
];

class ForecastPage extends StatefulWidget {
  final AppState appState;
  const ForecastPage({super.key, required this.appState});

  @override
  State<ForecastPage> createState() => _ForecastPageState();
}

class _ForecastPageState extends State<ForecastPage> {
  late TextEditingController _amountCtrl;
  BudgetPeriod _period = BudgetPeriod.monthly;
  int _horizonIdx = 3; // default 6 months

  @override
  void initState() {
    super.initState();
    final eb = widget.appState.expectedBudget;
    if (eb != null) {
      _period = eb.period;
      _amountCtrl = TextEditingController(text: eb.amount.toStringAsFixed(0));
    } else {
      // Suggest sum of category budget limits as a starting point.
      final suggested =
          widget.appState.budgetLimits.fold<double>(0, (s, b) => s + b.limit);
      _amountCtrl = TextEditingController(
          text: suggested > 0 ? suggested.toStringAsFixed(0) : '');
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  void _commit() {
    final v = double.tryParse(_amountCtrl.text.trim());
    if (v == null || v <= 0) {
      widget.appState.setExpectedBudget(null);
    } else {
      widget.appState.setExpectedBudget(
          ExpectedBudget(amount: v, period: _period));
    }
  }

  ExpectedBudget? _draftBudget() {
    final v = double.tryParse(_amountCtrl.text.trim());
    if (v == null || v <= 0) return null;
    return ExpectedBudget(amount: v, period: _period);
  }

  List<ForecastPoint> _buildPoints(ExpectedBudget? eb, int days) {
    final pts = <ForecastPoint>[];
    final now = DateTime.now();
    final dailyIncome = widget.appState.dailyIncome;
    final dailySpend = eb?.dailyEquivalent ?? 0;
    final delta = dailyIncome - dailySpend;
    // Sample ~50 points across the horizon for a smooth curve.
    const steps = 50;
    for (int i = 0; i <= steps; i++) {
      final d = (days * i / steps).round();
      final date = now.add(Duration(days: d));
      pts.add(ForecastPoint(date, delta * d));
    }
    return pts;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wide = Breakpoints.isWide(context);

    return ListenableBuilder(
      listenable: widget.appState,
      builder: (context, _) {
        final draft = _draftBudget();
        final horizon = _horizons[_horizonIdx];
        final points = _buildPoints(draft, horizon.days);
        final endValue = points.last.cumulativeSavings;
        final positive = endValue >= 0;

        final dailyIncome = widget.appState.dailyIncome;
        final dailyExpected = draft?.dailyEquivalent ?? 0;

        final incomeOverHorizon = dailyIncome * horizon.days;
        final expectedOverHorizon = dailyExpected * horizon.days;

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: AppBar(title: const Text('Savings Forecast')),
          body: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              wide ? 32 : 16,
              12,
              wide ? 32 : 16,
              100,
            ),
            child: ContentMaxWidth(
              maxWidth: AppTokens.readableMaxWidth + 200,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.appState.monthlyIncome <= 0)
                    _incomeWarning(context),
                  _expectedBudgetCard(context),
                  const SizedBox(height: 16),
                  _horizonCard(context),
                  const SizedBox(height: 16),
                  _heroProjectionCard(context, draft, horizon, endValue, positive),
                  const SizedBox(height: 16),
                  _chartCard(context, points, horizon),
                  const SizedBox(height: 16),
                  _breakdownCard(context, draft, horizon, incomeOverHorizon,
                      expectedOverHorizon, endValue, positive),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Cards ─────────────────────────────────────────────────────────────────

  Widget _incomeWarning(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        color: AppColors.warning.withValues(alpha: 0.10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
          side: BorderSide(color: AppColors.warning.withValues(alpha: 0.4)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: AppColors.warning),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Set your monthly income in Profile to see accurate savings projections.',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _expectedBudgetCard(BuildContext context) {
    final theme = Theme.of(context);
    final draft = _draftBudget();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Expected Spending',
              style: theme.textTheme.titleMedium?.copyWith(fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              'How much you plan to spend per period.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            // Period segmented control
            _periodSelector(context),
            const SizedBox(height: 14),
            TextField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) {
                setState(() {});
                _commit();
              },
              decoration: InputDecoration(
                labelText: '${_period.label} amount',
                hintText: '0.00',
                prefixIcon: const Icon(Icons.attach_money_rounded),
                suffixText: '/ ${_period.label.toLowerCase()}',
              ),
            ),
            if (draft != null) ...[
              const SizedBox(height: 12),
              _equivalents(context, draft),
            ],
          ],
        ),
      ),
    );
  }

  Widget _periodSelector(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? AppColors.darkSurfaceElevated
            : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
      ),
      child: Row(
        children: BudgetPeriod.values.map((p) {
          final selected = p == _period;
          return Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(AppTokens.radiusSm),
              onTap: () {
                setState(() => _period = p);
                _commit();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected
                      ? theme.colorScheme.surface
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 6,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    p.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected
                          ? theme.colorScheme.primary
                          : theme.textTheme.bodyMedium?.color,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _equivalents(BuildContext context, ExpectedBudget eb) {
    final theme = Theme.of(context);
    final values = [
      ('Daily', eb.dailyEquivalent),
      ('Weekly', eb.weeklyEquivalent),
      ('Monthly', eb.monthlyEquivalent),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
      ),
      child: Row(
        children: values.map((entry) {
          return Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.$1,
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                ),
                const SizedBox(height: 2),
                FitText(
                  formatCurrency(entry.$2, decimals: 0),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _horizonCard(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Time Horizon',
              style: theme.textTheme.titleMedium?.copyWith(fontSize: 16),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(_horizons.length, (i) {
                final h = _horizons[i];
                final selected = i == _horizonIdx;
                return InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => setState(() => _horizonIdx = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? theme.colorScheme.primary.withValues(alpha: 0.14)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected
                            ? theme.colorScheme.primary
                            : theme.dividerColor,
                      ),
                    ),
                    child: Text(
                      h.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected
                            ? theme.colorScheme.primary
                            : theme.textTheme.bodyMedium?.color,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroProjectionCard(BuildContext context, ExpectedBudget? draft,
      _Horizon horizon, double endValue, bool positive) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final endDate = DateTime.now().add(Duration(days: horizon.days));
    final monthsAvg = endValue / (horizon.days / 30.4375);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: positive
              ? (isDark
                  ? [const Color(0xFF065F46), const Color(0xFF1F2A44)]
                  : [
                      AppColors.success,
                      Color.lerp(AppColors.success,
                              theme.colorScheme.primary, 0.5) ??
                          AppColors.success,
                    ])
              : (isDark
                  ? [const Color(0xFF7F1D1D), const Color(0xFF1F2A44)]
                  : [AppColors.danger, const Color(0xFFB91C1C)]),
        ),
        borderRadius: BorderRadius.circular(AppTokens.radiusXl),
        boxShadow: [
          BoxShadow(
            color: (positive ? AppColors.success : AppColors.danger)
                .withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                positive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                positive ? 'Projected Savings' : 'Projected Shortfall',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  horizon.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FitText(
            formatCurrency(endValue),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 40,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.2,
              height: 1,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            draft == null
                ? 'Set an expected spending amount to see your projection.'
                : 'by ${_formatLong(endDate)}  ·  ${formatCurrency(monthsAvg, decimals: 0)}/month avg',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _chartCard(
      BuildContext context, List<ForecastPoint> points, _Horizon horizon) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Text(
                    'Cumulative Savings',
                    style:
                        theme.textTheme.titleMedium?.copyWith(fontSize: 16),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.dividerColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Drag to scrub',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(fontSize: 10.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 240,
              child: ForecastChart(points: points),
            ),
          ],
        ),
      ),
    );
  }

  Widget _breakdownCard(
    BuildContext context,
    ExpectedBudget? draft,
    _Horizon horizon,
    double incomeOverHorizon,
    double expectedOverHorizon,
    double endValue,
    bool positive,
  ) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Breakdown over ${horizon.label}',
              style: theme.textTheme.titleMedium?.copyWith(fontSize: 16),
            ),
            const SizedBox(height: 12),
            ForecastBreakdownRow(
              label: 'Income',
              value: formatCurrency(incomeOverHorizon),
              valueColor: AppColors.success,
            ),
            ForecastBreakdownRow(
              label: 'Expected expenses',
              value: '−${formatCurrency(expectedOverHorizon)}',
              valueColor: AppColors.danger,
            ),
            Divider(color: theme.dividerColor, height: 24),
            ForecastBreakdownRow(
              label: positive ? 'Projected savings' : 'Projected shortfall',
              value: formatCurrency(endValue),
              valueColor: positive ? AppColors.success : AppColors.danger,
              emphasis: true,
            ),
            if (draft != null) ...[
              const SizedBox(height: 8),
              Text(
                positive
                    ? 'At ${formatCurrency(draft.dailyEquivalent, decimals: 0)}/day in expenses, you\'d save ${formatCurrency(widget.appState.dailySavingsRate ?? 0, decimals: 0)} every day.'
                    : 'You\'re spending ${formatCurrency(-(widget.appState.dailySavingsRate ?? 0), decimals: 0)} more per day than you earn.',
                style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  String _formatLong(DateTime d) =>
      '${_months[d.month - 1]} ${d.day}, ${d.year}';
}
