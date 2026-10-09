import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:budget_buddy/state/app_state.dart';
import 'package:budget_buddy/theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  final AppState appState;
  const OnboardingScreen({super.key, required this.appState});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  final _nameController = TextEditingController();
  final _incomeController = TextEditingController();
  bool _enjoyShopping = false;
  String _frequency = 'Occasionally';

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _incomeController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  void _finishOnboarding() {
    final name = _nameController.text.trim();
    final income = double.tryParse(_incomeController.text.trim()) ?? 0;
    if (name.isEmpty || income <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields with valid values')),
      );
      return;
    }
    widget.appState.completeOnboarding(
      name: name,
      income: income,
      enjoys: _enjoyShopping,
      frequency: _frequency,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final teal = theme.colorScheme.primary;
    final wide = MediaQuery.sizeOf(context).width >= 720;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: wide ? 520 : double.infinity),
            child: Column(
              children: [
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (i) {
                    final active = _currentPage == i;
                    final passed = _currentPage > i;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: active ? 28 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: active || passed
                            ? teal
                            : teal.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
                if (_currentPage > 0)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 0, 0),
                      child: TextButton.icon(
                        onPressed: _previousPage,
                        icon: const Icon(Icons.arrow_back_rounded, size: 18),
                        label: const Text('Back'),
                      ),
                    ),
                  ),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildWelcomePage(theme, teal),
                      _buildProfilePage(theme, teal),
                      _buildHabitsPage(theme, teal),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomePage(ThemeData theme, Color teal) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Container(
            width: 128,
            height: 128,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [teal, AppColors.accent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: teal.withValues(alpha: 0.3),
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: const Icon(Icons.account_balance_wallet_rounded,
                size: 64, color: Colors.white),
          ),
          const SizedBox(height: 36),
          Text(
            'Budget Buddy',
            style: theme.textTheme.displaySmall?.copyWith(fontSize: 36),
          ),
          const SizedBox(height: 12),
          Text(
            'Take control of your finances.\nTrack spending, set budgets, and reach your savings goals.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.textTheme.bodySmall?.color,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 36),
          _featureRow(theme, Icons.insights_rounded, 'Smart insights',
              'Personalized advice based on your habits'),
          _featureRow(theme, Icons.savings_rounded, 'Savings goals',
              'Track multiple goals with deposit history'),
          _featureRow(theme, Icons.bar_chart_rounded, 'Beautiful charts',
              'See where your money goes at a glance'),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _nextPage,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text("Let's Get Started",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _featureRow(ThemeData theme, IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: theme.colorScheme.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                Text(subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfilePage(ThemeData theme, Color teal) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          Text('About You',
              style: theme.textTheme.displaySmall?.copyWith(fontSize: 32)),
          const SizedBox(height: 8),
          Text('Tell us a bit about yourself',
              style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.textTheme.bodySmall?.color, fontSize: 15)),
          const SizedBox(height: 32),
          Text('What\'s your name?', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              hintText: 'Enter your name',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
          ),
          const SizedBox(height: 24),
          Text('Monthly Income', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _incomeController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              hintText: 'Enter your monthly income',
              prefixIcon: Icon(Icons.attach_money_rounded),
            ),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _nextPage,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Continue',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHabitsPage(ThemeData theme, Color teal) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          Text('Your Habits',
              style: theme.textTheme.displaySmall?.copyWith(fontSize: 32)),
          const SizedBox(height: 8),
          Text('Help us understand your spending style',
              style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.textTheme.bodySmall?.color, fontSize: 15)),
          const SizedBox(height: 28),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Do you enjoy shopping?',
                            style: theme.textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text(
                          _enjoyShopping ? 'Yes, I love it!' : 'Not really',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  CupertinoSwitch(
                    value: _enjoyShopping,
                    activeTrackColor: teal,
                    onChanged: (v) => setState(() => _enjoyShopping = v),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('How often do you shop?', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          ...['Rarely', 'Occasionally', 'Frequently'].map((f) {
            final selected = _frequency == f;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                onTap: () => setState(() => _frequency = f),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: selected
                        ? teal.withValues(alpha: 0.1)
                        : Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                    border: Border.all(
                      color: selected ? teal : theme.dividerColor,
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        selected
                            ? Icons.check_circle_rounded
                            : Icons.circle_outlined,
                        color: selected
                            ? teal
                            : theme.textTheme.bodySmall?.color,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        f,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.w500,
                          color: selected
                              ? teal
                              : theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _finishOnboarding,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Start Budgeting',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
