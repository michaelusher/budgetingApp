import 'package:flutter/material.dart';
import 'package:budget_buddy/services/advisor_ai.dart';
import 'package:budget_buddy/services/budget_advisor.dart';
import 'package:budget_buddy/state/app_state.dart';
import 'package:budget_buddy/theme/app_theme.dart';

/// Dashboard card showing the [BudgetAdvisor]'s tips, optionally reworded by
/// Gemini. Shows [fallback] as a plain insight when there are no tips.
class AdvisorCard extends StatefulWidget {
  final AppState appState;
  final String fallback;

  const AdvisorCard({super.key, required this.appState, this.fallback = ''});

  @override
  State<AdvisorCard> createState() => _AdvisorCardState();
}

class _AdvisorCardState extends State<AdvisorCard> {
  String _requestedFor = '';
  List<String>? _aiMessages;
  String _aiFor = '';

  void _maybeRewrite(List<AdvisorTip> tips) {
    final signature = tips.map((t) => t.message).join('\n');
    if (!widget.appState.aiTips || tips.isEmpty) return;
    if (signature == _requestedFor) return;
    _requestedFor = signature;
    AdvisorAi.rewrite(tips, userName: widget.appState.userName).then((out) {
      if (!mounted || out == null || _requestedFor != signature) return;
      setState(() {
        _aiMessages = out;
        _aiFor = signature;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final tips = BudgetAdvisor(widget.appState).tips();
    _maybeRewrite(tips);

    if (tips.isEmpty) {
      if (widget.fallback.isEmpty) return const SizedBox.shrink();
      return _card(context, [
        _tipRow(context, Icons.auto_awesome_rounded,
            Theme.of(context).colorScheme.primary, 'Insight', widget.fallback),
      ]);
    }

    final signature = tips.map((t) => t.message).join('\n');
    final aiReady = widget.appState.aiTips && _aiFor == signature;
    return _card(context, [
      for (var i = 0; i < tips.length; i++) ...[
        if (i > 0) const SizedBox(height: 14),
        _tipRow(
          context,
          switch (tips[i].kind) {
            AdvisorTipKind.overspending => Icons.warning_amber_rounded,
            AdvisorTipKind.prioritizeNecessities => Icons.home_rounded,
            AdvisorTipKind.canSpend => Icons.celebration_rounded,
          },
          tips[i].isWarning ? AppColors.warning : AppColors.success,
          tips[i].title,
          aiReady ? _aiMessages![i] : tips[i].message,
        ),
      ],
    ]);
  }

  Widget _card(BuildContext context, List<Widget> children) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      );

  Widget _tipRow(BuildContext context, IconData icon, Color color,
      String title, String message) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
