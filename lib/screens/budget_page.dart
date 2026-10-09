import 'package:flutter/material.dart';
import 'package:budget_buddy/state/app_state.dart';
import 'package:budget_buddy/models/expense_category.dart';
import 'package:budget_buddy/constants/categories.dart';
import 'package:budget_buddy/screens/savings_goals_page.dart';
import 'package:budget_buddy/screens/forecast_page.dart';
import 'package:budget_buddy/theme/app_theme.dart';
import 'package:budget_buddy/widgets/responsive.dart';

class BudgetPage extends StatelessWidget {
  final AppState appState;
  const BudgetPage({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final teal = theme.colorScheme.primary;
    final wide = Breakpoints.isWide(context);

    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: AppBar(
            title: const Text('Budget'),
            actions: [
              TextButton.icon(
                icon: const Icon(Icons.timeline_rounded, size: 18),
                label: const Text('Forecast'),
                onPressed: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ForecastPage(appState: appState),
                      ));
                },
              ),
              TextButton.icon(
                icon: const Icon(Icons.savings_rounded, size: 18),
                label: const Text('Savings'),
                onPressed: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SavingsGoalsPage(appState: appState),
                      ));
                },
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              wide ? 32 : 16,
              8,
              wide ? 32 : 16,
              100,
            ),
            child: ContentMaxWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _summaryCard(context, teal),
                  const SizedBox(height: 20),
                  Text(
                    'Category Budgets',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (wide)
                    LayoutBuilder(
                      builder: (ctx, constraints) {
                        final cols =
                            constraints.maxWidth >= 1100 ? 3 : 2;
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: kCategories.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: cols,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                            mainAxisExtent: 132,
                          ),
                          itemBuilder: (_, i) =>
                              _categoryTile(context, kCategories[i]),
                        );
                      },
                    )
                  else
                    Column(
                      children: kCategories
                          .map((cat) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _categoryTile(context, cat),
                              ))
                          .toList(),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _summaryCard(BuildContext context, Color teal) {
    final theme = Theme.of(context);
    final spent = appState.spentThisMonth + appState.savedThisMonth;
    final income = appState.monthlyIncome;
    final pct = income > 0 ? (spent / income).clamp(0.0, 1.0) : 0.0;
    final overBudget = spent > income && income > 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'This Month\'s Budget',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      FitText(
                        '${formatCurrency(spent)} of ${formatCurrency(income)} used',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 64,
                  height: 64,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: pct,
                        backgroundColor: theme.dividerColor,
                        color: overBudget ? AppColors.danger : teal,
                        strokeWidth: 6,
                      ),
                      Text(
                        '${(pct * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                backgroundColor: theme.dividerColor,
                color: overBudget ? AppColors.danger : teal,
                minHeight: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryTile(BuildContext context, ExpenseCategory cat) {
    final theme = Theme.of(context);
    final spent = appState.spentInCategoryThisMonth(cat.name);
    final limit = appState.getBudgetLimit(cat.name) ?? 0;
    final progress = limit > 0 ? (spent / limit).clamp(0.0, 1.0) : 0.0;
    final overBudget = spent > limit && limit > 0;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        onTap: () => _editBudget(context, cat, limit),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
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
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FitText(cat.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14)),
                        const SizedBox(height: 2),
                        FitText(
                          '${formatCurrency(spent)} / ${formatCurrency(limit)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: overBudget
                                ? AppColors.danger
                                : theme.textTheme.bodySmall?.color,
                            fontWeight: overBudget
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (overBudget)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('Over',
                          style: TextStyle(
                              color: AppColors.danger,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    )
                  else
                    Icon(Icons.edit_rounded,
                        size: 16, color: theme.textTheme.bodySmall?.color),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: theme.dividerColor,
                  color: overBudget ? AppColors.danger : cat.color,
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _editBudget(BuildContext context, ExpenseCategory cat, double currentLimit) {
    final controller = TextEditingController(
        text: currentLimit > 0 ? currentLimit.toStringAsFixed(0) : '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: cat.color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(AppTokens.radiusSm),
              ),
              child: Icon(cat.icon, color: cat.color, size: 20),
            ),
            const SizedBox(width: 12),
            Text('${cat.name} Budget'),
          ],
        ),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Monthly limit',
            prefixIcon: Icon(Icons.attach_money_rounded),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(controller.text.trim()) ?? 0;
              if (val > 0) appState.setBudgetLimit(cat, val);
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
