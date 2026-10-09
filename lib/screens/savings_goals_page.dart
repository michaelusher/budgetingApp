import 'package:flutter/material.dart';
import 'package:budget_buddy/state/app_state.dart';
import 'package:budget_buddy/models/savings_goal.dart';
import 'package:budget_buddy/theme/app_theme.dart';
import 'package:budget_buddy/widgets/responsive.dart';
import 'package:budget_buddy/constants/goal_icons.dart';

class SavingsGoalsPage extends StatefulWidget {
  final AppState appState;
  const SavingsGoalsPage({super.key, required this.appState});
  @override
  State<SavingsGoalsPage> createState() => _SavingsGoalsPageState();
}

class _SavingsGoalsPageState extends State<SavingsGoalsPage> {
  final Set<int> _expanded = {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final teal = theme.colorScheme.primary;
    final wide = Breakpoints.isWide(context);

    return ListenableBuilder(
      listenable: widget.appState,
      builder: (context, _) {
        final goals = widget.appState.savingsGoals;
        final totalSaved = widget.appState.totalSaved;

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: AppBar(
            title: const Text('Savings Goals'),
            actions: [
              IconButton(
                icon: const Icon(Icons.add_rounded),
                tooltip: 'New goal',
                onPressed: _addGoal,
              ),
              const SizedBox(width: 8),
            ],
          ),
          floatingActionButton: wide
              ? null
              : FloatingActionButton.extended(
                  onPressed: _addGoal,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('New goal'),
                ),
          body: goals.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: teal.withValues(alpha: 0.10),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.savings_rounded,
                            size: 38, color: teal),
                      ),
                      const SizedBox(height: 16),
                      Text('No savings goals yet',
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text('Tap + to create one',
                          style: theme.textTheme.bodySmall),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    wide ? 32 : 16,
                    16,
                    wide ? 32 : 16,
                    100,
                  ),
                  child: ContentMaxWidth(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _summaryCard(context, teal, totalSaved),
                        const SizedBox(height: 16),
                        ...goals.asMap().entries.map((entry) {
                          final i = entry.key;
                          final goal = entry.value;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _goalCard(context, teal, i, goal),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _summaryCard(BuildContext context, Color teal, double totalSaved) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF0F766E), const Color(0xFF1F2A44)]
              : [teal, Color.lerp(teal, AppColors.accent, 0.55) ?? teal],
        ),
        borderRadius: BorderRadius.circular(AppTokens.radiusXl),
        boxShadow: [
          BoxShadow(
            color: teal.withValues(alpha: 0.2),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            ),
            child: const Icon(Icons.savings_rounded,
                color: Colors.white, size: 28),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Total in Savings',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                FitText(
                  formatCurrency(totalSaved),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _goalCard(BuildContext context, Color teal, int i, SavingsGoal goal) {
    final theme = Theme.of(context);
    final isExpanded = _expanded.contains(i);
    final progress = goal.progress;
    final completed = progress >= 1.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: teal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                  ),
                  child: Icon(goal.icon, color: teal, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FitText(goal.name,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontSize: 16)),
                      const SizedBox(height: 2),
                      FitText(
                        '${formatCurrency(goal.saved)} of ${formatCurrency(goal.target)}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_rounded),
                  color: teal,
                  tooltip: 'Add deposit',
                  onPressed: () => _addToGoal(i),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline_rounded,
                      color: theme.textTheme.bodySmall?.color),
                  tooltip: 'Delete goal',
                  onPressed: () => widget.appState.removeSavingsGoal(i),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: theme.dividerColor,
                color: completed ? AppColors.success : teal,
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 8),
            FitText(
              completed
                  ? 'Goal reached'
                  : '${(progress * 100).toStringAsFixed(1)}% complete · ${formatCurrency(goal.target - goal.saved)} to go',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: completed
                    ? AppColors.success
                    : theme.textTheme.bodySmall?.color,
              ),
            ),
            if (goal.deposits.isNotEmpty) ...[
              const SizedBox(height: 8),
              InkWell(
                onTap: () => setState(() {
                  if (isExpanded) {
                    _expanded.remove(i);
                  } else {
                    _expanded.add(i);
                  }
                }),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: teal,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isExpanded
                            ? 'Hide deposit history'
                            : 'Show deposit history (${goal.deposits.length})',
                        style: TextStyle(
                            fontSize: 13,
                            color: teal,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
              if (isExpanded) ...[
                const SizedBox(height: 8),
                _buildDepositHistory(goal, teal),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDepositHistory(SavingsGoal goal, Color teal) {
    final theme = Theme.of(context);
    final deposits = goal.deposits.reversed.toList();
    return Container(
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? AppColors.darkSurfaceElevated
            : const Color(0xFFF6F8FB),
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
      ),
      child: Column(
        children: deposits.asMap().entries.map((e) {
          final i = e.key;
          final d = e.value;
          final isLast = i == deposits.length - 1;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.arrow_circle_up_rounded, color: teal, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            d.note != null && d.note!.isNotEmpty
                                ? d.note!
                                : 'Deposit',
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            _formatDate(d.date),
                            style: theme.textTheme.bodySmall
                                ?.copyWith(fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    FitText(
                      '+${formatCurrency(d.amount)}',
                      alignment: Alignment.centerRight,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: teal,
                          fontSize: 13),
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Divider(
                    height: 1,
                    indent: 14,
                    endIndent: 14,
                    color: theme.dividerColor),
            ],
          );
        }).toList(),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    if (d == today) return 'Today, ${_time(date)}';
    if (d == today.subtract(const Duration(days: 1))) {
      return 'Yesterday, ${_time(date)}';
    }
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _time(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    final ampm = d.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $ampm';
  }

  void _addGoal() {
    final nameCtrl = TextEditingController();
    final targetCtrl = TextEditingController();
    IconData selectedIcon = Icons.savings_rounded;

    final icons = kGoalIcons;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('New Savings Goal'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Goal name',
                      hintText: 'e.g. Vacation',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: targetCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Target amount',
                      prefixIcon: Icon(Icons.attach_money_rounded),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text('Icon',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: icons.map((ic) {
                      final sel = ic == selectedIcon;
                      final primary = Theme.of(context).colorScheme.primary;
                      return InkWell(
                        onTap: () => setDialogState(() => selectedIcon = ic),
                        borderRadius:
                            BorderRadius.circular(AppTokens.radiusSm),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: sel
                                ? primary.withValues(alpha: 0.14)
                                : (Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? AppColors.darkSurfaceElevated
                                    : const Color(0xFFF1F5F9)),
                            borderRadius:
                                BorderRadius.circular(AppTokens.radiusSm),
                            border: Border.all(
                              color: sel ? primary : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Icon(ic,
                              color: sel
                                  ? primary
                                  : Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.color),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                final target = double.tryParse(targetCtrl.text.trim()) ?? 0;
                if (name.isNotEmpty && target > 0) {
                  widget.appState.addSavingsGoal(
                    SavingsGoal(
                        name: name, target: target, icon: selectedIcon),
                  );
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _addToGoal(int index) {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add to Savings'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixIcon: Icon(Icons.attach_money_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  hintText: 'e.g. Skipped eating out',
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(amountCtrl.text.trim()) ?? 0;
              final note = noteCtrl.text.trim();
              if (val > 0) {
                widget.appState
                    .addToSavings(index, val, note: note.isNotEmpty ? note : null);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
