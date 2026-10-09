import 'package:flutter/material.dart';
import 'package:budget_buddy/widgets/responsive.dart';
import 'package:budget_buddy/theme/app_theme.dart';

class ForecastPoint {
  final DateTime date;
  final double cumulativeSavings;
  const ForecastPoint(this.date, this.cumulativeSavings);
}

/// Smooth area-line chart of cumulative savings over time, with a draggable
/// scrubber to read exact values at any point.
class ForecastChart extends StatefulWidget {
  final List<ForecastPoint> points;
  const ForecastChart({super.key, required this.points});

  @override
  State<ForecastChart> createState() => _ForecastChartState();
}

class _ForecastChartState extends State<ForecastChart> {
  double? _scrubX; // local x position 0..1, null when not active

  void _updateScrub(Offset local, Size size) {
    final pad = _ChartPainter.paddingFor(size);
    final left = pad.left;
    final right = size.width - pad.right;
    final t = ((local.dx - left) / (right - left)).clamp(0.0, 1.0);
    setState(() => _scrubX = t);
  }

  void _clearScrub() => setState(() => _scrubX = null);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final positive = widget.points.last.cumulativeSavings >= 0;
    final lineColor =
        positive ? theme.colorScheme.primary : AppColors.danger;

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanDown: (d) => _updateScrub(d.localPosition, size),
          onPanUpdate: (d) => _updateScrub(d.localPosition, size),
          onPanEnd: (_) => _clearScrub(),
          onPanCancel: _clearScrub,
          onTapUp: (d) => _updateScrub(d.localPosition, size),
          child: RepaintBoundary(
            child: CustomPaint(
              size: size,
              painter: _ChartPainter(
                points: widget.points,
                lineColor: lineColor,
                gridColor: theme.dividerColor,
                axisLabelColor:
                    theme.textTheme.bodySmall?.color ?? Colors.grey,
                surfaceColor: theme.colorScheme.surface,
                onSurfaceColor: theme.colorScheme.onSurface,
                scrubX: _scrubX,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ChartPainter extends CustomPainter {
  final List<ForecastPoint> points;
  final Color lineColor;
  final Color gridColor;
  final Color axisLabelColor;
  final Color surfaceColor;
  final Color onSurfaceColor;
  final double? scrubX;

  _ChartPainter({
    required this.points,
    required this.lineColor,
    required this.gridColor,
    required this.axisLabelColor,
    required this.surfaceColor,
    required this.onSurfaceColor,
    required this.scrubX,
  });

  static EdgeInsets paddingFor(Size size) =>
      const EdgeInsets.fromLTRB(54, 18, 16, 28);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty || size.isEmpty) return;
    final pad = paddingFor(size);
    final left = pad.left;
    final right = size.width - pad.right;
    final top = pad.top;
    final bottom = size.height - pad.bottom;
    final w = right - left;
    final h = bottom - top;
    if (w <= 0 || h <= 0) return;

    // Y range: include 0 baseline; pad 8% above/below
    var minY = 0.0;
    var maxY = 0.0;
    for (final p in points) {
      if (p.cumulativeSavings < minY) minY = p.cumulativeSavings;
      if (p.cumulativeSavings > maxY) maxY = p.cumulativeSavings;
    }
    if (minY == maxY) maxY = minY + 1; // avoid div-by-zero
    final span = maxY - minY;
    minY -= span * 0.08;
    maxY += span * 0.08;
    final yScale = h / (maxY - minY);

    double xOf(int i) => left + (i / (points.length - 1)) * w;
    double yOf(double v) => bottom - (v - minY) * yScale;

    // ── Grid + Y axis labels ───────────────────────────────────────────────
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    const yLines = 4;
    for (int i = 0; i <= yLines; i++) {
      final v = minY + (maxY - minY) * (i / yLines);
      final y = yOf(v);
      canvas.drawLine(Offset(left, y), Offset(right, y), gridPaint);
      _drawText(
        canvas,
        _formatCurrencyShort(v),
        Offset(left - 8, y),
        TextStyle(color: axisLabelColor, fontSize: 10),
        alignRight: true,
      );
    }

    // Zero baseline
    if (minY < 0 && maxY > 0) {
      canvas.drawLine(
        Offset(left, yOf(0)),
        Offset(right, yOf(0)),
        Paint()
          ..color = axisLabelColor.withValues(alpha: 0.5)
          ..strokeWidth = 1,
      );
    }

    // ── X axis labels (start, ~25%, ~50%, ~75%, end) ───────────────────────
    final xTickIdxs = [
      0,
      ((points.length - 1) * 0.25).round(),
      ((points.length - 1) * 0.5).round(),
      ((points.length - 1) * 0.75).round(),
      points.length - 1,
    ];
    for (final idx in xTickIdxs) {
      final p = points[idx];
      _drawText(
        canvas,
        _formatDateShort(p.date),
        Offset(xOf(idx), bottom + 6),
        TextStyle(color: axisLabelColor, fontSize: 10),
        alignCenter: true,
      );
    }

    // ── Smooth area path + line ────────────────────────────────────────────
    final linePath = Path();
    for (int i = 0; i < points.length; i++) {
      final x = xOf(i);
      final y = yOf(points[i].cumulativeSavings);
      if (i == 0) {
        linePath.moveTo(x, y);
      } else {
        // Smooth using Catmull-Rom-ish cubic between adjacent samples
        final pPrev = Offset(xOf(i - 1), yOf(points[i - 1].cumulativeSavings));
        final cp1 = Offset(pPrev.dx + (x - pPrev.dx) / 2, pPrev.dy);
        final cp2 = Offset(pPrev.dx + (x - pPrev.dx) / 2, y);
        linePath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, x, y);
      }
    }

    // Area fill underneath
    final areaPath = Path.from(linePath)
      ..lineTo(xOf(points.length - 1), yOf(0).clamp(top, bottom))
      ..lineTo(xOf(0), yOf(0).clamp(top, bottom))
      ..close();

    final areaPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          lineColor.withValues(alpha: 0.30),
          lineColor.withValues(alpha: 0.02),
        ],
      ).createShader(Rect.fromLTRB(left, top, right, bottom));
    canvas.drawPath(areaPath, areaPaint);

    canvas.drawPath(
      linePath,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    // End-of-range value bubble
    final lastIdx = points.length - 1;
    final endP = Offset(xOf(lastIdx), yOf(points[lastIdx].cumulativeSavings));
    canvas.drawCircle(
      endP,
      5,
      Paint()..color = surfaceColor,
    );
    canvas.drawCircle(
      endP,
      4,
      Paint()..color = lineColor,
    );

    // ── Scrubber: vertical line + dot + bubble ─────────────────────────────
    if (scrubX != null) {
      final t = scrubX!;
      // Snap to nearest sample
      final idx = (t * (points.length - 1)).round();
      final sx = xOf(idx);
      final sy = yOf(points[idx].cumulativeSavings);

      canvas.drawLine(
        Offset(sx, top),
        Offset(sx, bottom),
        Paint()
          ..color = onSurfaceColor.withValues(alpha: 0.25)
          ..strokeWidth = 1,
      );
      canvas.drawCircle(Offset(sx, sy), 6, Paint()..color = surfaceColor);
      canvas.drawCircle(Offset(sx, sy), 4, Paint()..color = lineColor);

      final label =
          '${_formatDateShort(points[idx].date)}   ${_formatCurrencyShort(points[idx].cumulativeSavings)}';
      _drawBubble(canvas, label, Offset(sx, top + 4));
    }
  }

  void _drawBubble(Canvas canvas, String text, Offset anchor) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: surfaceColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    const padX = 8.0, padY = 4.0;
    final w = tp.width + padX * 2;
    final h = tp.height + padY * 2;
    var x = anchor.dx - w / 2;
    final y = anchor.dy;
    // Keep inside chart horizontally
    if (x < 8) x = 8;
    final rect = Rect.fromLTWH(x, y, w, h);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(6)),
      Paint()..color = onSurfaceColor.withValues(alpha: 0.85),
    );
    tp.paint(canvas, Offset(x + padX, y + padY));
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset at,
    TextStyle style, {
    bool alignRight = false,
    bool alignCenter = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    var dx = at.dx;
    if (alignRight) dx -= tp.width;
    if (alignCenter) dx -= tp.width / 2;
    tp.paint(canvas, Offset(dx, at.dy - tp.height / 2));
  }

  static String _formatCurrencyShort(double v) {
    final neg = v < 0;
    final abs = v.abs();
    String body;
    if (abs >= 1000000) {
      body = '\$${(abs / 1000000).toStringAsFixed(abs >= 10000000 ? 0 : 1)}M';
    } else if (abs >= 1000) {
      body = '\$${(abs / 1000).toStringAsFixed(abs >= 10000 ? 0 : 1)}k';
    } else {
      body = '\$${abs.toStringAsFixed(0)}';
    }
    return neg ? '-$body' : body;
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String _formatDateShort(DateTime d) {
    final now = DateTime.now();
    if (d.year == now.year) return '${_months[d.month - 1]} ${d.day}';
    return '${_months[d.month - 1]} ${d.year % 100}';
  }

  @override
  bool shouldRepaint(_ChartPainter old) =>
      old.points != points ||
      old.lineColor != lineColor ||
      old.scrubX != scrubX ||
      old.surfaceColor != surfaceColor ||
      old.onSurfaceColor != onSurfaceColor;
}

/// Small badge used in the forecast page next to numeric breakdown rows.
class ForecastBreakdownRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool emphasis;
  const ForecastBreakdownRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.emphasis = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: emphasis ? FontWeight.w700 : FontWeight.w500,
                color: emphasis
                    ? theme.colorScheme.onSurface
                    : theme.textTheme.bodyMedium?.color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          FitText(
            value,
            alignment: Alignment.centerRight,
            style: TextStyle(
              fontSize: emphasis ? 16 : 14,
              fontWeight: emphasis ? FontWeight.w800 : FontWeight.w600,
              color: valueColor ?? theme.colorScheme.onSurface,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}
