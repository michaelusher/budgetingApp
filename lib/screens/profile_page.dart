import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:budget_buddy/state/app_state.dart';
import 'package:budget_buddy/constants/currencies.dart';
import 'package:budget_buddy/services/receipt_scanner.dart';
import 'package:budget_buddy/theme/app_theme.dart';
import 'package:budget_buddy/widgets/responsive.dart';

class ProfilePage extends StatefulWidget {
  final AppState appState;
  const ProfilePage({super.key, required this.appState});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late TextEditingController _nameCtrl;
  late TextEditingController _incomeCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.appState.userName);
    _incomeCtrl = TextEditingController(
        text: widget.appState.monthlyIncome.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _incomeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final teal = theme.colorScheme.primary;
    final wide = Breakpoints.isWide(context);

    return ListenableBuilder(
      listenable: widget.appState,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: AppBar(title: const Text('Profile')),
          body: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              wide ? 32 : 16,
              8,
              wide ? 32 : 16,
              100,
            ),
            child: ContentMaxWidth(
              maxWidth: AppTokens.readableMaxWidth + 100,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _profileHeader(context, teal),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: _statCard(
                            context,
                            'Income',
                            formatCurrency(widget.appState.monthlyIncome,
                                decimals: 0),
                            Icons.trending_up_rounded,
                            AppColors.success),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _statCard(
                            context,
                            'This month',
                            formatCurrency(widget.appState.spentThisMonth,
                                decimals: 0),
                            Icons.trending_down_rounded,
                            AppColors.danger),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _statCard(
                            context,
                            'Transactions',
                            '${widget.appState.transactions.length}',
                            Icons.receipt_long_rounded,
                            AppColors.warning),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  _sectionLabel(context, 'Edit Profile'),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          TextField(
                            controller: _nameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Name',
                              prefixIcon: Icon(Icons.person_outline_rounded),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _incomeCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Monthly Income',
                              prefixIcon: Icon(Icons.attach_money_rounded),
                            ),
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _saveProfile,
                              icon: const Icon(Icons.check_rounded, size: 20),
                              label: const Text('Save Changes'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _sectionLabel(context, 'Appearance'),
                  const SizedBox(height: 12),
                  _themePicker(context),
                  const SizedBox(height: 24),
                  _sectionLabel(context, 'Currency'),
                  const SizedBox(height: 12),
                  _currencyPicker(context),
                  const SizedBox(height: 24),
                  _sectionLabel(context, 'Budget Advisor'),
                  const SizedBox(height: 12),
                  _advisorSection(context),
                  const SizedBox(height: 24),
                  _sectionLabel(context, 'Data'),
                  const SizedBox(height: 12),
                  _dataSection(context),
                  const SizedBox(height: 24),
                  _sectionLabel(context, 'Spending Insight'),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: teal.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(
                                      AppTokens.radiusSm),
                                ),
                                child:
                                    Icon(Icons.insights_rounded, color: teal),
                              ),
                              const SizedBox(width: 12),
                              Text('Your Analysis',
                                  style: theme.textTheme.titleMedium),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(
                            _getDetailedAnalysis(),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _saveProfile() {
    final name = _nameCtrl.text.trim();
    final income = double.tryParse(_incomeCtrl.text.trim()) ?? 0;
    if (name.isNotEmpty && income > 0) {
      widget.appState.updateProfile(name: name, income: income);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated')),
      );
    }
  }

  Widget _profileHeader(BuildContext context, Color teal) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1A2237), const Color(0xFF111827)]
              : [
                  teal.withValues(alpha: 0.08),
                  AppColors.accent.withValues(alpha: 0.08),
                ],
        ),
        borderRadius: BorderRadius.circular(AppTokens.radiusXl),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [teal, AppColors.accent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppTokens.radiusLg),
            ),
            child: Center(
              child: Text(
                widget.appState.userName.isNotEmpty
                    ? widget.appState.userName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FitText(
                  widget.appState.userName.isEmpty
                      ? 'You'
                      : widget.appState.userName,
                  style: theme.textTheme.headlineSmall?.copyWith(fontSize: 22),
                ),
                const SizedBox(height: 4),
                FitText(
                  '${widget.appState.enjoyShopping ? "Loves shopping" : "Mindful spender"} · Shops ${widget.appState.shoppingFrequency.toLowerCase()}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _themePicker(BuildContext context) {
    final theme = Theme.of(context);
    final selected = widget.appState.themeMode;
    final options = [
      (mode: ThemeMode.system, label: 'System', icon: Icons.brightness_auto_rounded),
      (mode: ThemeMode.light, label: 'Light', icon: Icons.light_mode_rounded),
      (mode: ThemeMode.dark, label: 'Dark', icon: Icons.dark_mode_rounded),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: options.map((opt) {
            final isSelected = selected == opt.mode;
            return Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                onTap: () => widget.appState.setThemeMode(opt.mode),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding:
                      const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primary.withValues(alpha: 0.10)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        opt.icon,
                        size: 22,
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.textTheme.bodyMedium?.color,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        opt.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.textTheme.bodyMedium?.color,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _currencyPicker(BuildContext context) {
    final theme = Theme.of(context);
    final selected = widget.appState.currencyCode;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: kCurrencies.map((c) {
            final isSelected = c.code == selected;
            return InkWell(
              borderRadius: BorderRadius.circular(AppTokens.radiusMd),
              onTap: () => widget.appState.setCurrency(c.code),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primary.withValues(alpha: 0.10)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                  border: Border.all(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.dividerColor,
                  ),
                ),
                child: Text(
                  '${c.symbol.trim()} ${c.code}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.textTheme.bodyMedium?.color,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _advisorSection(BuildContext context) {
    final theme = Theme.of(context);
    final s = widget.appState;
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.shield_rounded, color: AppColors.warning),
            title: const Text('Overspending warnings',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            subtitle: Text(
              'Always on. Warns before entertainment or shopping purchases '
              'when you\'re close to your budget, and reminds you to cover '
              'rent and utilities first.',
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
            ),
          ),
          Divider(height: 1, indent: 16, endIndent: 16, color: theme.dividerColor),
          SwitchListTile(
            value: s.remindToSpend,
            onChanged: s.setRemindToSpend,
            secondary:
                const Icon(Icons.celebration_rounded, color: AppColors.success),
            title: const Text('Remind me I can spend',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            subtitle: Text(
              'Lets you know when you\'re well under budget and have room to '
              'treat yourself.',
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
            ),
          ),
          Divider(height: 1, indent: 16, endIndent: 16, color: theme.dividerColor),
          SwitchListTile(
            value: s.aiTips,
            onChanged: _setAiTips,
            secondary: Icon(Icons.auto_awesome_rounded,
                color: theme.colorScheme.primary),
            title: const Text('AI-written tips',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            subtitle: Text(
              'Rewords tips with Gemini using your receipt-scanning key. '
              'Sends a short spending summary to Google.',
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _setAiTips(bool value) async {
    if (value && await ReceiptScanner.getApiKey() == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Add a Gemini key first — tap the scan icon when '
            'adding an expense to set one up.'),
      ));
      return;
    }
    widget.appState.setAiTips(value);
  }

  Widget _dataSection(BuildContext context) {
    final theme = Theme.of(context);

    Widget row({
      required IconData icon,
      required String title,
      required String subtitle,
      required VoidCallback onTap,
      Color? color,
    }) {
      final tint = color ?? theme.colorScheme.primary;
      return InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                ),
                child: Icon(icon, color: tint, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: color)),
                    const SizedBox(height: 1),
                    Text(subtitle,
                        style:
                            theme.textTheme.bodySmall?.copyWith(fontSize: 12)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  size: 20, color: theme.textTheme.bodySmall?.color),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Column(
        children: [
          row(
            icon: Icons.table_view_rounded,
            title: 'Export transactions (CSV)',
            subtitle: 'Copies a spreadsheet-ready file to your clipboard',
            onTap: _exportCsv,
          ),
          Divider(height: 1, indent: 66, color: theme.dividerColor),
          row(
            icon: Icons.backup_rounded,
            title: 'Back up all data',
            subtitle: 'Copies a JSON backup to your clipboard',
            onTap: _backupJson,
          ),
          Divider(height: 1, indent: 66, color: theme.dividerColor),
          row(
            icon: Icons.restore_rounded,
            title: 'Restore from backup',
            subtitle: 'Paste a previously created JSON backup',
            onTap: _restoreFromBackup,
          ),
          Divider(height: 1, indent: 66, color: theme.dividerColor),
          row(
            icon: Icons.delete_forever_rounded,
            title: 'Erase all data',
            subtitle: 'Deletes everything and restarts onboarding',
            onTap: _confirmErase,
            color: AppColors.danger,
          ),
        ],
      ),
    );
  }

  Future<void> _exportCsv() async {
    final count = widget.appState.transactions.length;
    await Clipboard.setData(ClipboardData(text: widget.appState.exportCsv()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          'Copied $count transaction${count == 1 ? '' : 's'} as CSV'),
    ));
  }

  Future<void> _backupJson() async {
    await Clipboard.setData(ClipboardData(text: widget.appState.exportJson()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Backup copied to clipboard — save it somewhere safe')),
    );
  }

  Future<void> _restoreFromBackup() async {
    final controller = TextEditingController();
    final raw = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore from backup'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Paste a JSON backup below. This replaces all current data.',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 6,
                autofocus: true,
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                decoration: const InputDecoration(hintText: '{ "isOnboarded": ... }'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (raw == null || raw.trim().isEmpty || !mounted) return;
    final ok = widget.appState.importJson(raw.trim());
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? 'Backup restored'
          : 'That doesn\'t look like a valid backup — nothing was changed'),
    ));
  }

  Future<void> _confirmErase() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Erase all data?'),
        content: const Text(
            'All transactions, budgets, and savings goals will be permanently deleted. Consider making a backup first.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Erase everything'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await widget.appState.resetAll();
    }
  }

  Widget _sectionLabel(BuildContext context, String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
    );
  }

  Widget _statCard(BuildContext context, String label, String value,
      IconData icon, Color color) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 12),
            FitText(
              value,
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  letterSpacing: -0.3),
            ),
            const SizedBox(height: 2),
            FitText(label,
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  String _getDetailedAnalysis() {
    final s = widget.appState;
    final buf = StringBuffer();

    if (s.transactions.isEmpty) {
      return 'Start adding transactions to see personalized spending insights here.';
    }

    final ratio = s.monthlyIncome > 0 ? s.totalSpent / s.monthlyIncome : 0.0;
    if (ratio < 0.5) {
      buf.writeln(
          'Excellent! You\'re only using ${(ratio * 100).toStringAsFixed(0)}% of your income. Great discipline, ${s.userName}.');
    } else if (ratio < 0.8) {
      buf.writeln(
          'You\'re at ${(ratio * 100).toStringAsFixed(0)}% of your income. Healthy range, but keep an eye on it.');
    } else if (ratio < 1.0) {
      buf.writeln(
          'You\'ve spent ${(ratio * 100).toStringAsFixed(0)}% of your income. Consider reducing non-essential spending.');
    } else {
      buf.writeln(
          'You\'ve exceeded your income. Time to review and cut back on spending.');
    }

    final topCategory = s.spendingByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (topCategory.isNotEmpty) {
      buf.writeln(
          '\nTop category: ${topCategory.first.key} (${formatCurrency(topCategory.first.value)}).');
    }

    if (s.shoppingFrequency == 'Frequently' && s.enjoyShopping) {
      buf.writeln(
          '\nSince you love shopping, try setting stricter category limits to stay on track.');
    }

    return buf.toString().trim();
  }
}
