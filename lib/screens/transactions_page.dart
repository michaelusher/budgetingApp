import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:budget_buddy/state/app_state.dart';
import 'package:budget_buddy/models/transaction.dart';
import 'package:budget_buddy/models/expense_category.dart';
import 'package:budget_buddy/constants/categories.dart';
import 'package:budget_buddy/theme/app_theme.dart';
import 'package:budget_buddy/widgets/responsive.dart';

class TransactionsPage extends StatefulWidget {
  final AppState appState;
  const TransactionsPage({super.key, required this.appState});

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String? _filterCategory; // null = all
  DateTime? _filterMonth; // null = all time

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Transaction> _filtered() {
    final q = _query.trim().toLowerCase();
    final month = _filterMonth;
    return widget.appState.transactions.where((t) {
      if (month != null &&
          (t.date.year != month.year || t.date.month != month.month)) {
        return false;
      }
      if (_filterCategory != null && t.category.name != _filterCategory) {
        return false;
      }
      if (q.isEmpty) return true;
      return t.title.toLowerCase().contains(q) ||
          t.category.name.toLowerCase().contains(q) ||
          (t.note?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  Future<void> _exportCsv() async {
    final filtered = _filtered();
    await Clipboard.setData(
        ClipboardData(text: widget.appState.exportCsv(filtered)));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          'Copied ${filtered.length} transaction${filtered.length == 1 ? '' : 's'} as CSV'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wide = Breakpoints.isWide(context);

    return ListenableBuilder(
      listenable: widget.appState,
      builder: (context, _) {
        final hasAny = widget.appState.transactions.isNotEmpty;
        final filtered = _filtered();

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: AppBar(
            title: const Text('Transactions'),
            actions: [
              if (hasAny)
                IconButton(
                  tooltip: 'Copy as CSV',
                  icon: const Icon(Icons.ios_share_rounded, size: 20),
                  onPressed: _exportCsv,
                ),
              const SizedBox(width: 8),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(0),
              child: Container(height: 1, color: theme.dividerColor),
            ),
          ),
          body: !hasAny
              ? _emptyState(context)
              : SingleChildScrollView(
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
                        _searchAndFilter(context),
                        const SizedBox(height: 12),
                        _summaryRow(context, filtered),
                        const SizedBox(height: 8),
                        if (filtered.isEmpty)
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(28),
                              child: Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.search_off_rounded,
                                        size: 32,
                                        color:
                                            theme.textTheme.bodySmall?.color),
                                    const SizedBox(height: 8),
                                    Text('No matching transactions',
                                        style: theme.textTheme.titleSmall),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Try a different search or filter',
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        else
                          ..._groupedList(context, filtered),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _emptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.receipt_long_rounded,
                size: 38, color: theme.colorScheme.primary),
          ),
          const SizedBox(height: 16),
          Text('No transactions yet', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('Your spending history will show here',
              style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _searchAndFilter(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _searchCtrl,
          onChanged: (v) => setState(() => _query = v),
          decoration: InputDecoration(
            hintText: 'Search by title, note, or category',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _query = '');
                    },
                  ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _filterChip(
                  context, 'All', null, theme.colorScheme.primary, Icons.list_rounded),
              ...kCategories.map((c) =>
                  _filterChip(context, c.name, c, c.color, c.icon)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _summaryRow(BuildContext context, List<Transaction> filtered) {
    final theme = Theme.of(context);
    final total = filtered.fold<double>(0, (sum, t) => sum + t.amount);
    final months = widget.appState.transactionMonths;

    return Row(
      children: [
        _monthDropdown(context, months),
        const Spacer(),
        Text(
          '${filtered.length} transaction${filtered.length == 1 ? '' : 's'} · ',
          style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
        ),
        Text(
          formatCurrency(total),
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _monthDropdown(BuildContext context, List<DateTime> months) {
    final theme = Theme.of(context);
    return PopupMenuButton<int>(
      tooltip: 'Filter by month',
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd)),
      onSelected: (i) =>
          setState(() => _filterMonth = i < 0 ? null : months[i]),
      itemBuilder: (_) => [
        const PopupMenuItem(value: -1, height: 40, child: Text('All time')),
        for (int i = 0; i < months.length; i++)
          PopupMenuItem(
              value: i, height: 40, child: Text(formatMonth(months[i]))),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          border: Border.all(color: theme.dividerColor),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_month_rounded,
                size: 14, color: theme.textTheme.bodySmall?.color),
            const SizedBox(width: 6),
            Text(
              _filterMonth == null ? 'All time' : formatMonth(_filterMonth!),
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down_rounded,
                size: 18, color: theme.textTheme.bodySmall?.color),
          ],
        ),
      ),
    );
  }

  List<Widget> _groupedList(BuildContext context, List<Transaction> filtered) {
    final theme = Theme.of(context);

    // Transactions arrive sorted newest-first; bucket them per calendar day.
    final groups = <DateTime, List<Transaction>>{};
    for (final t in filtered) {
      final day = DateTime(t.date.year, t.date.month, t.date.day);
      groups.putIfAbsent(day, () => []).add(t);
    }

    final widgets = <Widget>[];
    groups.forEach((day, items) {
      final dayTotal = items.fold<double>(0, (sum, t) => sum + t.amount);
      widgets.add(Padding(
        padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
        child: Row(
          children: [
            Text(
              formatDate(day),
              style: theme.textTheme.titleSmall?.copyWith(
                fontSize: 13,
                color: theme.textTheme.bodySmall?.color,
              ),
            ),
            const Spacer(),
            Text(
              '-${formatCurrency(dayTotal)}',
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ));
      widgets.add(Card(
        child: Column(
          children: [
            for (int i = 0; i < items.length; i++) ...[
              if (i > 0)
                Divider(height: 1, indent: 64, color: theme.dividerColor),
              _row(context, items[i]),
            ],
          ],
        ),
      ));
    });
    return widgets;
  }

  Widget _filterChip(BuildContext context, String label,
      ExpenseCategory? cat, Color color, IconData icon) {
    final selected = (cat?.name) == _filterCategory;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => setState(() => _filterCategory = cat?.name),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.14) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? color : theme.dividerColor,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(icon,
                  size: 14,
                  color: selected ? color : theme.textTheme.bodySmall?.color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? color : theme.textTheme.bodyMedium?.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, Transaction t) {
    final theme = Theme.of(context);
    final isRecurring = t.repeat != RepeatFrequency.none;
    return Dismissible(
      key: Key(t.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: AppColors.danger.withValues(alpha: 0.9),
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      onDismissed: (_) => widget.appState.removeTransaction(t.id),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () =>
              openTransactionSheet(context, widget.appState, editing: t),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: t.category.color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                  ),
                  child: Icon(t.category.icon,
                      color: t.category.color, size: 20),
                ),
                const SizedBox(width: 14),
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
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              t.category.name,
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isRecurring) ...[
                            const SizedBox(width: 6),
                            Icon(Icons.repeat_rounded,
                                size: 12,
                                color: theme.colorScheme.primary),
                            const SizedBox(width: 2),
                            Text(
                              t.repeat.label,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (t.note != null && t.note!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            t.note!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontStyle: FontStyle.italic,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                FitText(
                  '-${formatCurrency(t.amount)}',
                  alignment: Alignment.centerRight,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.danger,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded,
                    size: 20, color: theme.textTheme.bodySmall?.color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
