import 'package:flutter/material.dart';
import 'package:budget_buddy/state/app_state.dart';
import 'package:budget_buddy/models/transaction.dart';
import 'package:budget_buddy/theme/app_theme.dart';
import 'package:budget_buddy/constants/currencies.dart';
import 'package:budget_buddy/widgets/add_transaction_sheet.dart';

/// Formats a currency amount with thousands separators in the app's active
/// currency (see [AppCurrency]). Pass `decimals: 0` for whole-unit display.
String formatCurrency(num amount, {int decimals = 2, String? symbol}) {
  symbol ??= AppCurrency.symbol;
  final isNegative = amount < 0;
  final abs = amount.abs();
  final fixed = abs.toStringAsFixed(decimals);
  final parts = fixed.split('.');
  final intPart = parts[0];
  final buf = StringBuffer();
  for (int i = 0; i < intPart.length; i++) {
    if (i > 0 && (intPart.length - i) % 3 == 0) buf.write(',');
    buf.write(intPart[i]);
  }
  final result = parts.length > 1 ? '$buf.${parts[1]}' : buf.toString();
  return '${isNegative ? '-' : ''}$symbol$result';
}

const List<String> kMonthAbbr = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Human date like "Today", "Yesterday", "Mar 5" (current year) or
/// "Mar 5, 2025". Set [relative] false to always use the month-day form.
String formatDate(DateTime d, {bool relative = true}) {
  final now = DateTime.now();
  if (relative) {
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    if (day == today) return 'Today';
    if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';
  }
  final base = '${kMonthAbbr[d.month - 1]} ${d.day}';
  return d.year == now.year ? base : '$base, ${d.year}';
}

/// "March 2026"-style label for a month value.
String formatMonth(DateTime month) {
  const names = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  return '${names[month.month - 1]} ${month.year}';
}

/// Constrains content to a readable max width and centers it on wide screens.
class ContentMaxWidth extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;
  const ContentMaxWidth({
    super.key,
    required this.child,
    this.maxWidth = AppTokens.contentMaxWidth,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class Breakpoints {
  /// Phone vs tablet+ — used to give tablets a roomier modal sheet, etc.
  static const double tablet = 600;

  static bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= AppTokens.railBreakpoint;

  static bool isExtended(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= AppTokens.extendedRailBreakpoint;

  static bool isTabletOrLarger(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= tablet;
}

/// Single-line text that scales down to fit the available width — never wraps,
/// never gets clipped. Use for currency, stat values, headlines that must stay
/// on one line.
class FitText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final Alignment alignment;
  final TextWidthBasis textWidthBasis;
  const FitText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.alignment = Alignment.centerLeft,
    this.textWidthBasis = TextWidthBasis.parent,
  });

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: alignment,
      child: Text(
        text,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.visible,
        textAlign: textAlign,
        textWidthBasis: textWidthBasis,
        style: style,
      ),
    );
  }
}

/// Opens the transaction sheet — as a centered Dialog on wide screens
/// and a modal bottom sheet on mobile. Pass [editing] to open in edit mode.
Future<void> openTransactionSheet(
  BuildContext context,
  AppState appState, {
  Transaction? editing,
}) {
  if (Breakpoints.isWide(context)) {
    return showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: AddTransactionSheet(
            appState: appState,
            isDialog: true,
            editing: editing,
          ),
        ),
      ),
    );
  }
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (_) =>
        AddTransactionSheet(appState: appState, editing: editing),
  );
}
