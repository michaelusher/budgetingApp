import 'package:flutter/material.dart';
import 'package:budget_buddy/state/app_state.dart';
import 'package:budget_buddy/theme/app_theme.dart';
import 'package:budget_buddy/widgets/responsive.dart';
import 'package:budget_buddy/screens/dashboard_page.dart';
import 'package:budget_buddy/screens/transactions_page.dart';
import 'package:budget_buddy/screens/charts_page.dart';
import 'package:budget_buddy/screens/budget_page.dart';
import 'package:budget_buddy/screens/profile_page.dart';

class _NavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  const _NavItem(this.icon, this.selectedIcon, this.label);
}

const List<_NavItem> _navItems = [
  _NavItem(Icons.dashboard_outlined, Icons.dashboard_rounded, 'Home'),
  _NavItem(Icons.receipt_long_outlined, Icons.receipt_long_rounded, 'History'),
  _NavItem(Icons.bar_chart_outlined, Icons.bar_chart_rounded, 'Charts'),
  _NavItem(Icons.pie_chart_outline_rounded, Icons.pie_chart_rounded, 'Budget'),
  _NavItem(Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
];

class MainShell extends StatefulWidget {
  final AppState appState;
  const MainShell({super.key, required this.appState});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tabIndex = 0;

  void _showAddTransaction(BuildContext context) {
    openTransactionSheet(context, widget.appState);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardPage(appState: widget.appState),
      TransactionsPage(appState: widget.appState),
      ChartsPage(appState: widget.appState),
      BudgetPage(appState: widget.appState),
      ProfilePage(appState: widget.appState),
    ];

    final wide = Breakpoints.isWide(context);
    final extended = Breakpoints.isExtended(context);

    if (wide) {
      return Scaffold(
        body: SafeArea(
          child: Row(
            children: [
              _SideNav(
                selectedIndex: _tabIndex,
                extended: extended,
                onSelect: (i) => setState(() => _tabIndex = i),
                onAdd: () => _showAddTransaction(context),
                appState: widget.appState,
              ),
              Container(
                width: 1,
                color: Theme.of(context).dividerColor,
              ),
              Expanded(
                child: IndexedStack(index: _tabIndex, children: pages),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: IndexedStack(index: _tabIndex, children: pages),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTransaction(context),
        tooltip: 'Add expense',
        child: const Icon(Icons.add_rounded, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        destinations: _navItems
            .map((it) => NavigationDestination(
                  icon: Icon(it.icon),
                  selectedIcon: Icon(it.selectedIcon),
                  label: it.label,
                ))
            .toList(),
      ),
    );
  }
}

class _SideNav extends StatelessWidget {
  final int selectedIndex;
  final bool extended;
  final ValueChanged<int> onSelect;
  final VoidCallback onAdd;
  final AppState appState;

  const _SideNav({
    required this.selectedIndex,
    required this.extended,
    required this.onSelect,
    required this.onAdd,
    required this.appState,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = extended ? 240.0 : 84.0;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: width,
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Brand
          Padding(
            padding: EdgeInsets.symmetric(horizontal: extended ? 20 : 0),
            child: Row(
              mainAxisAlignment:
                  extended ? MainAxisAlignment.start : MainAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary,
                        theme.colorScheme.primary.withValues(alpha: 0.7),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                if (extended) ...[
                  const SizedBox(width: 12),
                  Text(
                    'Budget Buddy',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                      color: theme.colorScheme.onSurface,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Add button (primary action)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: extended ? 16 : 16),
            child: extended
                ? ElevatedButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: const Text('Add Expense'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      minimumSize: const Size.fromHeight(46),
                    ),
                  )
                : SizedBox(
                    height: 52,
                    child: Tooltip(
                      message: 'Add expense',
                      child: ElevatedButton(
                        onPressed: onAdd,
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppTokens.radiusMd),
                          ),
                        ),
                        child: const Icon(Icons.add_rounded, size: 24),
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 24),

          // Nav items
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: extended ? 12 : 12),
              itemCount: _navItems.length,
              itemBuilder: (context, i) {
                final item = _navItems[i];
                final selected = i == selectedIndex;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: _NavTile(
                    icon: selected ? item.selectedIcon : item.icon,
                    label: item.label,
                    selected: selected,
                    extended: extended,
                    onTap: () => onSelect(i),
                  ),
                );
              },
            ),
          ),

          // Footer profile chip on extended rail
          if (extended)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSurfaceElevated
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor:
                          theme.colorScheme.primary.withValues(alpha: 0.15),
                      child: Text(
                        appState.userName.isNotEmpty
                            ? appState.userName[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FitText(
                            appState.userName.isEmpty ? 'You' : appState.userName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          FitText(
                            formatCurrency(appState.monthlyIncome, decimals: 0),
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.textTheme.bodySmall?.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool extended;
  final VoidCallback onTap;

  const _NavTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.extended,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedColor = theme.colorScheme.primary;
    final unselectedColor = theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(
            horizontal: extended ? 14 : 0,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: selected
                ? selectedColor.withValues(alpha: 0.10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          ),
          child: Row(
            mainAxisAlignment:
                extended ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 22,
                color: selected ? selectedColor : unselectedColor,
              ),
              if (extended) ...[
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.w500,
                      fontSize: 14,
                      color: selected ? selectedColor : unselectedColor,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
