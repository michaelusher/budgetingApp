import 'package:flutter/material.dart';
import 'package:budget_buddy/state/app_state.dart';
import 'package:budget_buddy/models/transaction.dart';
import 'package:budget_buddy/constants/categories.dart';
import 'package:budget_buddy/theme/app_theme.dart';
import 'package:budget_buddy/widgets/responsive.dart';
import 'package:budget_buddy/widgets/advisor_card.dart';
import 'package:budget_buddy/services/budget_advisor.dart';

class DashboardPage extends StatelessWidget {
  final AppState appState;
  const DashboardPage({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final wide = Breakpoints.isWide(context);
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                wide ? 32 : 16,
                wide ? 24 : 12,
                wide ? 32 : 16,
                wide ? 32 : 100,
              ),
              child: ContentMaxWidth(
                child: wide ? _buildWide(context) : _buildNarrow(context),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Narrow (mobile) layout ─────────────────────────────────────────────────
  Widget _buildNarrow(BuildContext context) {
    final theme = Theme.of(context);
    final advice = _getAdvice();
    final showAdvisor =
        advice.isNotEmpty || BudgetAdvisor(appState).tips().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _greeting(context),
        const SizedBox(height: 16),
        _heroBalanceCard(context),
        const SizedBox(height: 16),
        if (showAdvisor) ...[
          AdvisorCard(appState: appState, fallback: advice),
          const SizedBox(height: 16),
        ],
        if (appState.transactions.isNotEmpty) ...[
          _quickStatsCard(context),
          const SizedBox(height: 16),
        ],
        ..._budgetAlerts(context, 16),
        _sectionHeader(context, 'Spending This Month'),
        const SizedBox(height: 8),
        appState.transactions.isEmpty
            ? _emptyState(
                context,
                Icons.receipt_long_rounded,
                'No transactions yet',
                'Tap + to add your first expense',
              )
            : _categoryBreakdown(context),
        if (appState.savingsGoals.isNotEmpty) ...[
          const SizedBox(height: 24),
          _sectionHeader(context, 'Savings Goals'),
          const SizedBox(height: 8),
          SizedBox(
            height: 150,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.zero,
              itemCount: appState.savingsGoals.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, i) => _goalCard(context, appState.savingsGoals[i], 200),
            ),
          ),
        ],
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _sectionHeader(context, 'Recent Transactions'),
            if (appState.transactions.length > 5)
              Text(
                'Showing 5 of ${appState.transactions.length}',
                style: theme.textTheme.bodySmall,
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (appState.transactions.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Your transactions will appear here.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodySmall?.color,
              ),
            ),
          )
        else
          _transactionList(context, appState.transactions.take(5).toList()),
      ],
    );
  }

  // ── Wide (web/desktop) layout ──────────────────────────────────────────────
  Widget _buildWide(BuildContext context) {
    final theme = Theme.of(context);
    final advice = _getAdvice();
    final showAdvisor =
        advice.isNotEmpty || BudgetAdvisor(appState).tips().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _greeting(context),
        const SizedBox(height: 20),
        _heroBalanceCard(context),
        const SizedBox(height: 20),
        if (showAdvisor) ...[
          AdvisorCard(appState: appState, fallback: advice),
          const SizedBox(height: 20),
        ],
        if (appState.transactions.isNotEmpty) ...[
          _quickStatsCard(context),
          const SizedBox(height: 20),
        ],
        ..._budgetAlerts(context, 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left column
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _sectionHeader(context, 'Spending This Month'),
                  const SizedBox(height: 12),
                  appState.transactions.isEmpty
                      ? _emptyState(
                          context,
                          Icons.receipt_long_rounded,
                          'No transactions yet',
                          'Tap + to add your first expense',
                        )
                      : _categoryBreakdown(context),
                ],
              ),
            ),
            const SizedBox(width: 24),
            // Right column
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _sectionHeader(context, 'Recent Transactions'),
                      if (appState.transactions.length > 6)
                        Text(
                          'Showing 6 of ${appState.transactions.length}',
                          style: theme.textTheme.bodySmall,
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (appState.transactions.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          'Your transactions will appear here.',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    )
                  else
                    _transactionList(
                      context,
                      appState.transactions.take(6).toList(),
                    ),
                ],
              ),
            ),
          ],
        ),
        if (appState.savingsGoals.isNotEmpty) ...[
          const SizedBox(height: 28),
          _sectionHeader(context, 'Savings Goals'),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (ctx, constraints) {
              final cols = constraints.maxWidth >= 1100
                  ? 4
                  : constraints.maxWidth >= 800
                      ? 3
                      : 2;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: appState.savingsGoals.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.7,
                ),
                itemBuilder: (_, i) =>
                    _goalCard(context, appState.savingsGoals[i], double.infinity),
              );
            },
          ),
        ],
      ],
    );
  }

  // ── Components ─────────────────────────────────────────────────────────────

  Widget _greeting(BuildContext context) {
    final theme = Theme.of(context);
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 18
            ? 'Good afternoon'
            : 'Good evening';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          greeting,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.textTheme.bodySmall?.color,
            fontSize: 14,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        FitText(
          appState.userName.isEmpty ? 'Welcome back' : appState.userName,
          style: theme.textTheme.headlineMedium?.copyWith(fontSize: 26),
        ),
      ],
    );
  }

  Widget _heroBalanceCard(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final isDark = theme.brightness == Brightness.dark;
    final negative = appState.monthBalance < 0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF0F766E),
                  const Color(0xFF1F2A44),
                ]
              : [
                  primary,
                  Color.lerp(primary, AppColors.accent, 0.55) ?? primary,
                ],
        ),
        borderRadius: BorderRadius.circular(AppTokens.radiusXl),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: isDark ? 0.25 : 0.18),
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
              const Icon(
                Icons.account_balance_wallet_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Left to Spend · ${kMonthAbbr[DateTime.now().month - 1]}',
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
                  negative ? 'Over budget' : 'On track',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: appState.monthBalance),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (_, value, _) => FitText(
              formatCurrency(value),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 40,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.2,
                height: 1,
              ),
            ),
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (_, constraints) {
              final stacked = constraints.maxWidth < 360;
              if (stacked) {
                return Column(
                  children: [
                    _balanceChip(
                        'Income',
                        appState.monthlyIncome,
                        Icons.trending_up_rounded,
                        const Color(0xFF6EE7B7)),
                    const SizedBox(height: 8),
                    _balanceChip(
                        'Spent',
                        appState.spentThisMonth,
                        Icons.trending_down_rounded,
                        const Color(0xFFFCA5A5)),
                    const SizedBox(height: 8),
                    _balanceChip(
                        'Saved',
                        appState.savedThisMonth,
                        Icons.savings_rounded,
                        const Color(0xFFFCD34D)),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(
                    child: _balanceChip(
                        'Income',
                        appState.monthlyIncome,
                        Icons.trending_up_rounded,
                        const Color(0xFF6EE7B7)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _balanceChip(
                        'Spent',
                        appState.spentThisMonth,
                        Icons.trending_down_rounded,
                        const Color(0xFFFCA5A5)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _balanceChip(
                        'Saved',
                        appState.savedThisMonth,
                        Icons.savings_rounded,
                        const Color(0xFFFCD34D)),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _balanceChip(String label, double amount, IconData icon, Color iconColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                FitText(
                  formatCurrency(amount, decimals: 0),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickStatsCard(BuildContext context) {
    final theme = Theme.of(context);
    final dailyAvg = appState.dailyAverageThisMonth;
    final daysLeft = appState.daysLeftInMonth;
    final projected = appState.projectedMonthEndSpend;
    final income = appState.monthlyIncome;
    final overProjection = income > 0 && projected > income;

    final items = [
      _StatItem(
        icon: Icons.today_rounded,
        label: 'Daily avg',
        value: formatCurrency(dailyAvg, decimals: 0),
        color: theme.colorScheme.primary,
      ),
      _StatItem(
        icon: Icons.event_rounded,
        label: 'Days left',
        value: '$daysLeft',
        color: AppColors.accent,
      ),
      _StatItem(
        icon: Icons.trending_up_rounded,
        label: 'Projected',
        value: formatCurrency(projected, decimals: 0),
        color: overProjection ? AppColors.danger : AppColors.success,
        sublabel: overProjection ? 'over income' : 'on track',
      ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            for (int i = 0; i < items.length; i++) ...[
              if (i > 0)
                Container(
                  width: 1,
                  height: 36,
                  color: theme.dividerColor,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                ),
              Expanded(child: _statTile(context, items[i])),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statTile(BuildContext context, _StatItem item) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: item.color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          ),
          child: Icon(item.icon, color: item.color, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                item.label,
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 1),
              FitText(
                item.value,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  letterSpacing: -0.3,
                ),
              ),
              if (item.sublabel != null)
                FitText(
                  item.sublabel!,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: item.color,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// Warning card for categories at ≥90% of their monthly limit.
  /// Returns an empty list when everything is within budget.
  List<Widget> _budgetAlerts(BuildContext context, double gap) {
    final theme = Theme.of(context);
    final alerts = <({String name, IconData icon, Color color, double spent, double limit})>[];
    for (final cat in kCategories) {
      final limit = appState.getBudgetLimit(cat.name) ?? 0;
      if (limit <= 0) continue;
      final spent = appState.spentInCategoryThisMonth(cat.name);
      if (spent / limit >= 0.9) {
        alerts.add((
          name: cat.name,
          icon: cat.icon,
          color: cat.color,
          spent: spent,
          limit: limit,
        ));
      }
    }
    if (alerts.isEmpty) return [];
    alerts.sort((a, b) => (b.spent / b.limit).compareTo(a.spent / a.limit));

    return [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                    ),
                    child: const Icon(Icons.notifications_active_rounded,
                        color: AppColors.warning, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Budget Alerts',
                    style: theme.textTheme.titleMedium?.copyWith(fontSize: 15),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              for (final a in alerts)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Icon(a.icon, size: 18, color: a.color),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          a.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${formatCurrency(a.spent, decimals: 0)} of ${formatCurrency(a.limit, decimals: 0)}',
                        style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (a.spent > a.limit
                                  ? AppColors.danger
                                  : AppColors.warning)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          a.spent > a.limit
                              ? 'Over'
                              : '${(a.spent / a.limit * 100).round()}%',
                          style: TextStyle(
                            color: a.spent > a.limit
                                ? AppColors.danger
                                : AppColors.warning,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      SizedBox(height: gap),
    ];
  }

  Widget _sectionHeader(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Text(
      title,
      style: theme.textTheme.titleMedium?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
    );
  }

  Widget _categoryBreakdown(BuildContext context) {
    final theme = Theme.of(context);
    final spending = appState.spendingByCategoryThisMonth;
    if (spending.isEmpty) {
      return _emptyState(
        context,
        Icons.calendar_today_rounded,
        'Nothing spent this month',
        'Expenses you add this month will break down here',
      );
    }
    final sorted = spending.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = appState.spentThisMonth;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Column(
          children: sorted.map((entry) {
            final cat = kCategories.firstWhere(
              (c) => c.name == entry.key,
              orElse: () => kCategories.last,
            );
            final pct = total > 0 ? entry.value / total : 0.0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: cat.color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                    ),
                    child: Icon(cat.icon, color: cat.color, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                entry.key,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            FitText(
                              formatCurrency(entry.value),
                              alignment: Alignment.centerRight,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: pct,
                                  backgroundColor: theme.dividerColor,
                                  color: cat.color,
                                  minHeight: 6,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '${(pct * 100).toStringAsFixed(0)}%',
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(fontSize: 11),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _goalCard(BuildContext context, dynamic goal, double width) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final card = Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(goal.icon, size: 18, color: primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    goal.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Spacer(),
            FitText(
              '${formatCurrency(goal.saved, decimals: 0)} / ${formatCurrency(goal.target, decimals: 0)}',
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: goal.progress,
                backgroundColor: theme.dividerColor,
                color: goal.progress >= 1.0 ? AppColors.success : primary,
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${(goal.progress * 100).toStringAsFixed(0)}%',
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
            ),
          ],
        ),
      ),
    );
    if (width == double.infinity) return card;
    return SizedBox(width: width, child: card);
  }

  Widget _emptyState(
      BuildContext context, IconData icon, String title, String subtitle) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 30, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _transactionList(BuildContext context, List<Transaction> items) {
    final theme = Theme.of(context);
    return Card(
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0) Divider(height: 1, color: theme.dividerColor, indent: 64),
            _transactionTile(context, items[i]),
          ],
        ],
      ),
    );
  }

  Widget _transactionTile(BuildContext context, Transaction t) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: t.category.color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppTokens.radiusSm),
            ),
            child: Icon(t.category.icon, color: t.category.color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${t.category.name} · ${t.date.month}/${t.date.day}',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FitText(
            '-${formatCurrency(t.amount)}',
            alignment: Alignment.centerRight,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.danger,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  String _getAdvice() {
    final freq = appState.shoppingFrequency;
    final income = appState.monthlyIncome;
    final spent = appState.spentThisMonth;
    final name = appState.userName;
    final enjoys = appState.enjoyShopping;

    if (appState.transactions.isEmpty) {
      return 'Welcome, $name! Add your first expense to start tracking your budget.';
    }
    if ((freq == 'Rarely' || freq == 'Occasionally') && income > spent) {
      return 'Great job, $name! You\'re managing your spending well. Keep it up!';
    }
    if (freq == 'Frequently' && income > spent && enjoys) {
      return 'Even though you love shopping, you\'re doing great managing expenses, $name!';
    }
    if (freq == 'Frequently' && income > spent) {
      return 'Nice work, $name! Your expenses are under control.';
    }
    if (income <= spent && income > 0) {
      return 'Heads up, $name — you\'re spending close to or more than your income. Consider cutting back.';
    }
    return '';
  }
}

class _StatItem {
  final IconData icon;
  final String label;
  final String value;
  final String? sublabel;
  final Color color;
  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.sublabel,
  });
}

