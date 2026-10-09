import 'dart:math';
import 'package:flutter/material.dart';
import 'package:budget_buddy/state/app_state.dart';
import 'package:budget_buddy/constants/categories.dart';
import 'package:budget_buddy/theme/app_theme.dart';
import 'package:budget_buddy/widgets/responsive.dart';
import 'package:budget_buddy/widgets/three_d_charts.dart';

class ChartsPage extends StatefulWidget {
  final AppState appState;
  const ChartsPage({super.key, required this.appState});

  @override
  State<ChartsPage> createState() => _ChartsPageState();
}

class _ChartsPageState extends State<ChartsPage> {
  int _selPie = -1;
  int _selBar = -1;

  static const Color _savingsColor = Color(0xFF10B981);

  List<PieSegmentData> _buildSegments() {
    final spending = widget.appState.spendingByCategory;
    final totalSaved = widget.appState.totalSaved;
    final spendTotal = spending.values.fold(0.0, (a, b) => a + b);
    final total = spendTotal + totalSaved;
    if (total == 0) return [];

    final segs = <PieSegmentData>[];
    double angle = -pi / 2;
    final sorted = spending.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final e in sorted) {
      final sweep = (e.value / total) * 2 * pi;
      final cat = kCategories.firstWhere((c) => c.name == e.key,
          orElse: () => kCategories.last);
      segs.add(PieSegmentData(
        label: e.key,
        value: e.value,
        color: cat.color,
        startAngle: angle,
        sweepAngle: sweep,
      ));
      angle += sweep;
    }
    if (totalSaved > 0) {
      final sweep = (totalSaved / total) * 2 * pi;
      segs.add(PieSegmentData(
        label: 'Savings',
        value: totalSaved,
        color: _savingsColor,
        startAngle: angle,
        sweepAngle: sweep,
      ));
    }
    return segs;
  }

  List<BarData> _buildBars() {
    final spending = widget.appState.spendingByCategory;
    final totalSaved = widget.appState.totalSaved;
    final sorted = spending.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final entries = [
      ...sorted.map((e) {
        final cat = kCategories.firstWhere((c) => c.name == e.key,
            orElse: () => kCategories.last);
        return BarData(label: e.key, value: e.value, color: cat.color);
      }),
      if (totalSaved > 0)
        BarData(label: 'Savings', value: totalSaved, color: _savingsColor),
    ]..sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: widget.appState,
      builder: (context, _) {
        final segs = _buildSegments();
        final bars = _buildBars();
        final wide = Breakpoints.isWide(context);

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: AppBar(title: const Text('Spending Charts')),
          body: segs.isEmpty
              ? _empty(theme)
              : SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    wide ? 32 : 16,
                    16,
                    wide ? 32 : 16,
                    100,
                  ),
                  child: ContentMaxWidth(
                    child: wide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _pieSection(theme, segs)),
                              const SizedBox(width: 24),
                              Expanded(child: _barSection(theme, bars)),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _pieSection(theme, segs),
                              const SizedBox(height: 24),
                              _barSection(theme, bars),
                            ],
                          ),
                  ),
                ),
        );
      },
    );
  }

  Widget _empty(ThemeData theme) => Center(
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
              child: Icon(Icons.bar_chart_rounded,
                  size: 38, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 16),
            Text('No spending data yet', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('Add transactions to see charts',
                style: theme.textTheme.bodySmall),
          ],
        ),
      );

  Widget _sectionHeader(ThemeData theme, String title, String hint) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(title,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: theme.dividerColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.threesixty_rounded,
                    size: 12, color: theme.textTheme.bodySmall?.color),
                const SizedBox(width: 4),
                Text(hint,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(fontSize: 10.5, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pieSection(ThemeData theme, List<PieSegmentData> segs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionHeader(theme, 'Spending Breakdown', 'Drag to rotate'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                SizedBox(
                  height: 280,
                  child: Pie3DChart(
                    segments: segs,
                    selected: _selPie,
                    onSelect: (i) =>
                        setState(() => _selPie = _selPie == i ? -1 : i),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: segs.asMap().entries.map((e) {
                    final sel = _selPie == e.key;
                    return GestureDetector(
                      onTap: () => setState(
                          () => _selPie = _selPie == e.key ? -1 : e.key),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: sel
                              ? e.value.color.withValues(alpha: 0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: sel ? e.value.color : theme.dividerColor,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: e.value.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              e.value.label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight:
                                    sel ? FontWeight.w700 : FontWeight.w500,
                                color: sel
                                    ? e.value.color
                                    : theme.textTheme.bodyMedium?.color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                if (_selPie >= 0 && _selPie < segs.length) ...[
                  const SizedBox(height: 14),
                  _detailRow(
                    color: segs[_selPie].color,
                    leftLabel: segs[_selPie].label,
                    rightLabel:
                        '${formatCurrency(segs[_selPie].value)}  ·  ${(segs[_selPie].sweepAngle / (2 * pi) * 100).toStringAsFixed(1)}%',
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _barSection(ThemeData theme, List<BarData> bars) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionHeader(theme, 'Category Comparison', 'Drag to rotate'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                SizedBox(
                  height: 300,
                  child: Bar3DChart(
                    bars: bars,
                    selected: _selBar,
                    onSelect: (i) =>
                        setState(() => _selBar = _selBar == i ? -1 : i),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: bars.asMap().entries.map((e) {
                    final sel = _selBar == e.key;
                    return GestureDetector(
                      onTap: () => setState(
                          () => _selBar = _selBar == e.key ? -1 : e.key),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: sel
                              ? e.value.color.withValues(alpha: 0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: sel ? e.value.color : theme.dividerColor,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: e.value.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              e.value.label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight:
                                    sel ? FontWeight.w700 : FontWeight.w500,
                                color: sel
                                    ? e.value.color
                                    : theme.textTheme.bodyMedium?.color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                if (_selBar >= 0 && _selBar < bars.length) ...[
                  const SizedBox(height: 14),
                  _detailRow(
                    color: bars[_selBar].color,
                    leftLabel: bars[_selBar].label,
                    rightLabel: formatCurrency(bars[_selBar].value),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _detailRow({
    required Color color,
    required String leftLabel,
    required String rightLabel,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
      ),
      child: Row(
        children: [
          Flexible(
            child: FitText(
              leftLabel,
              style: TextStyle(fontWeight: FontWeight.w700, color: color),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: FitText(
              rightLabel,
              alignment: Alignment.centerRight,
              style: TextStyle(fontWeight: FontWeight.w700, color: color),
            ),
          ),
        ],
      ),
    );
  }
}
