import 'dart:math';
import 'package:flutter/material.dart';

// ──────────────────────────────────────────────────────────────────────────────
//  3D math helpers
// ──────────────────────────────────────────────────────────────────────────────

class _V3 {
  final double x, y, z;
  const _V3(this.x, this.y, this.z);
}

_V3 _rotate(_V3 p, double rotX, double rotY) {
  // rotateY then rotateX
  final cy = cos(rotY), sy = sin(rotY);
  final x1 = cy * p.x + sy * p.z;
  final z1 = -sy * p.x + cy * p.z;
  final y1 = p.y;

  final cx = cos(rotX), sx = sin(rotX);
  final y2 = cx * y1 - sx * z1;
  final z2 = sx * y1 + cx * z1;
  return _V3(x1, y2, z2);
}

class _Face {
  final List<_V3> world;
  final Color base;
  final _V3 normal;
  final int? hitId; // for tap selection
  const _Face({
    required this.world,
    required this.base,
    required this.normal,
    this.hitId,
  });
}

class _ProjectedFace {
  final List<Offset> points;
  final double depth;
  final Color color;
  final int? hitId;
  const _ProjectedFace(this.points, this.depth, this.color, this.hitId);
}

const _V3 _lightDir = _V3(0.35, 0.85, -0.4); // up-front light

double _len(_V3 v) => sqrt(v.x * v.x + v.y * v.y + v.z * v.z);

_V3 _norm(_V3 v) {
  final l = _len(v);
  if (l == 0) return const _V3(0, 1, 0);
  return _V3(v.x / l, v.y / l, v.z / l);
}

double _dot(_V3 a, _V3 b) => a.x * b.x + a.y * b.y + a.z * b.z;

Color _shade(Color base, double diffuse) {
  // diffuse ∈ [0, 1] roughly. Compress range so faces stay readable.
  final t = (0.55 + diffuse * 0.45).clamp(0.35, 1.0);
  final hsl = HSLColor.fromColor(base);
  return hsl.withLightness((hsl.lightness * t).clamp(0.0, 1.0)).toColor();
}

bool _pointInPolygon(Offset p, List<Offset> poly) {
  bool inside = false;
  for (int i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    final pi = poly[i], pj = poly[j];
    final intersect = ((pi.dy > p.dy) != (pj.dy > p.dy)) &&
        (p.dx <
            (pj.dx - pi.dx) * (p.dy - pi.dy) / (pj.dy - pi.dy + 1e-9) + pi.dx);
    if (intersect) inside = !inside;
  }
  return inside;
}

// ──────────────────────────────────────────────────────────────────────────────
//  Pie chart
// ──────────────────────────────────────────────────────────────────────────────

class PieSegmentData {
  final String label;
  final double value;
  final Color color;
  final double startAngle;
  final double sweepAngle;
  const PieSegmentData({
    required this.label,
    required this.value,
    required this.color,
    required this.startAngle,
    required this.sweepAngle,
  });
}

class Pie3DChart extends StatefulWidget {
  final List<PieSegmentData> segments;
  final int selected;
  final ValueChanged<int> onSelect;
  const Pie3DChart({
    super.key,
    required this.segments,
    required this.selected,
    required this.onSelect,
  });

  @override
  State<Pie3DChart> createState() => _Pie3DChartState();
}

class _Pie3DChartState extends State<Pie3DChart> {
  // Default: tilted forward so we mostly see the top + a bit of edge.
  double _rotX = 1.05;
  double _rotY = 0;

  // Cache hit polygons for tap testing — built each paint.
  final List<_HitRegion> _hitRegions = [];

  void _onPan(DragUpdateDetails d) {
    setState(() {
      _rotY += d.delta.dx * 0.012;
      _rotX -= d.delta.dy * 0.012;
      _rotX = _rotX.clamp(-pi / 2 + 0.1, pi / 2 - 0.1);
    });
  }

  void _onTapUp(TapUpDetails d) {
    // Find front-most segment whose top-face polygon contains the point.
    int? hit;
    double bestDepth = -double.infinity;
    for (final r in _hitRegions) {
      if (_pointInPolygon(d.localPosition, r.points) && r.depth > bestDepth) {
        bestDepth = r.depth;
        hit = r.segIndex;
      }
    }
    if (hit != null) widget.onSelect(hit);
  }

  void _resetView() {
    setState(() {
      _rotX = 1.05;
      _rotY = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanUpdate: _onPan,
            onTapUp: _onTapUp,
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _Pie3DPainter(
                  segments: widget.segments,
                  rotX: _rotX,
                  rotY: _rotY,
                  selected: widget.selected,
                  hitRegionsOut: _hitRegions,
                ),
                size: Size.infinite,
              ),
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: _ResetButton(onReset: _resetView),
        ),
      ],
    );
  }
}

class _HitRegion {
  final int segIndex;
  final List<Offset> points;
  final double depth;
  const _HitRegion(this.segIndex, this.points, this.depth);
}

class _Pie3DPainter extends CustomPainter {
  final List<PieSegmentData> segments;
  final double rotX;
  final double rotY;
  final int selected;
  final List<_HitRegion> hitRegionsOut;

  _Pie3DPainter({
    required this.segments,
    required this.rotX,
    required this.rotY,
    required this.selected,
    required this.hitRegionsOut,
  });

  static const int _arcSteps = 16;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || segments.isEmpty) return;
    hitRegionsOut.clear();

    final cx = size.width / 2;
    final cy = size.height / 2 + 10;
    final R = min(size.width, size.height) * 0.32;
    final H = R * 0.18; // pie thickness
    final scale = 1.0;

    final faces = <_Face>[];

    // Build all faces for all segments
    for (int i = 0; i < segments.length; i++) {
      final seg = segments[i];
      final sweep = seg.sweepAngle;
      if (sweep <= 0) continue;
      final start = seg.startAngle;
      final color = seg.color;
      // Pop selected segment outward along its mid-radius for a satisfying pull.
      final isSel = i == selected;
      final mid = start + sweep / 2;
      final dx = isSel ? cos(mid) * R * 0.10 : 0.0;
      final dz = isSel ? sin(mid) * R * 0.10 : 0.0;

      // Top face — a single n-gon (planar)
      final topPoly = <_V3>[_V3(dx, H / 2, dz)];
      for (int s = 0; s <= _arcSteps; s++) {
        final a = start + sweep * s / _arcSteps;
        topPoly.add(_V3(R * cos(a) + dx, H / 2, R * sin(a) + dz));
      }
      faces.add(_Face(
        world: topPoly,
        base: color,
        normal: const _V3(0, 1, 0),
        hitId: i,
      ));

      // Bottom face (winding reversed for proper culling)
      final botPoly = <_V3>[_V3(dx, -H / 2, dz)];
      for (int s = 0; s <= _arcSteps; s++) {
        final a = start + sweep * s / _arcSteps;
        botPoly.add(_V3(R * cos(a) + dx, -H / 2, R * sin(a) + dz));
      }
      faces.add(_Face(
        world: botPoly.reversed.toList(),
        base: color,
        normal: const _V3(0, -1, 0),
      ));

      // Outer wall — split into strips so each strip has its own normal/depth
      for (int s = 0; s < _arcSteps; s++) {
        final a0 = start + sweep * s / _arcSteps;
        final a1 = start + sweep * (s + 1) / _arcSteps;
        final p0t = _V3(R * cos(a0) + dx, H / 2, R * sin(a0) + dz);
        final p1t = _V3(R * cos(a1) + dx, H / 2, R * sin(a1) + dz);
        final p1b = _V3(R * cos(a1) + dx, -H / 2, R * sin(a1) + dz);
        final p0b = _V3(R * cos(a0) + dx, -H / 2, R * sin(a0) + dz);
        final mAng = (a0 + a1) / 2;
        faces.add(_Face(
          world: [p0t, p1t, p1b, p0b],
          base: color,
          normal: _V3(cos(mAng), 0, sin(mAng)),
        ));
      }

      // Radial walls — only when not a full circle
      if (sweep < 2 * pi - 0.001) {
        final aS = start;
        final c0 = _V3(dx, H / 2, dz);
        final c1 = _V3(R * cos(aS) + dx, H / 2, R * sin(aS) + dz);
        final c2 = _V3(R * cos(aS) + dx, -H / 2, R * sin(aS) + dz);
        final c3 = _V3(dx, -H / 2, dz);
        // Normal perpendicular to radial direction
        faces.add(_Face(
          world: [c0, c1, c2, c3],
          base: color,
          normal: _V3(sin(aS), 0, -cos(aS)),
        ));

        final aE = start + sweep;
        final d0 = _V3(dx, H / 2, dz);
        final d1 = _V3(R * cos(aE) + dx, H / 2, R * sin(aE) + dz);
        final d2 = _V3(R * cos(aE) + dx, -H / 2, R * sin(aE) + dz);
        final d3 = _V3(dx, -H / 2, dz);
        faces.add(_Face(
          world: [d3, d2, d1, d0],
          base: color,
          normal: _V3(-sin(aE), 0, cos(aE)),
        ));
      }
    }

    // Project + cull + light + sort
    final visible = <_ProjectedFace>[];
    final hitCandidates = <_HitRegion>[];

    for (final f in faces) {
      final n = _norm(_rotate(f.normal, rotX, rotY));
      // Camera looks toward -Z (object space after rotation): we want normal.z > 0
      if (n.z <= 0.02) continue;

      final pts = <Offset>[];
      double depthSum = 0;
      for (final v in f.world) {
        final r = _rotate(v, rotX, rotY);
        pts.add(Offset(cx + r.x * scale, cy - r.y * scale));
        depthSum += r.z;
      }
      final depth = depthSum / f.world.length;
      final lightT = max(0.0, _dot(n, _norm(_lightDir)));
      final color = _shade(f.base, lightT);
      visible.add(_ProjectedFace(pts, depth, color, f.hitId));

      if (f.hitId != null) {
        hitCandidates.add(_HitRegion(f.hitId!, pts, depth));
      }
    }

    visible.sort((a, b) => a.depth.compareTo(b.depth));
    hitRegionsOut.addAll(hitCandidates);

    final fill = Paint()..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;

    for (final pf in visible) {
      final path = Path()..moveTo(pf.points.first.dx, pf.points.first.dy);
      for (int i = 1; i < pf.points.length; i++) {
        path.lineTo(pf.points[i].dx, pf.points[i].dy);
      }
      path.close();
      fill.color = pf.color;
      canvas.drawPath(path, fill);
      canvas.drawPath(path, stroke);
    }

    // Selected segment outline overlay (top face) for clarity
    if (selected >= 0 && selected < segments.length) {
      // Recompute top polygon for the selected segment so the highlight
      // matches what's currently drawn.
      final seg = segments[selected];
      final sweep = seg.sweepAngle;
      if (sweep > 0) {
        final start = seg.startAngle;
        final mid = start + sweep / 2;
        final dx = cos(mid) * R * 0.10;
        final dz = sin(mid) * R * 0.10;
        final pts = <Offset>[];
        final centerR = _rotate(_V3(dx, H / 2, dz), rotX, rotY);
        pts.add(Offset(cx + centerR.x * scale, cy - centerR.y * scale));
        for (int s = 0; s <= _arcSteps; s++) {
          final a = start + sweep * s / _arcSteps;
          final r = _rotate(_V3(R * cos(a) + dx, H / 2, R * sin(a) + dz),
              rotX, rotY);
          pts.add(Offset(cx + r.x * scale, cy - r.y * scale));
        }
        final path = Path()..moveTo(pts.first.dx, pts.first.dy);
        for (int i = 1; i < pts.length; i++) {
          path.lineTo(pts[i].dx, pts[i].dy);
        }
        path.close();
        canvas.drawPath(
          path,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_Pie3DPainter old) =>
      old.rotX != rotX ||
      old.rotY != rotY ||
      old.selected != selected ||
      old.segments != segments;
}

// ──────────────────────────────────────────────────────────────────────────────
//  Bar chart
// ──────────────────────────────────────────────────────────────────────────────

class BarData {
  final String label;
  final double value;
  final Color color;
  const BarData(
      {required this.label, required this.value, required this.color});
}

class Bar3DChart extends StatefulWidget {
  final List<BarData> bars;
  final int selected;
  final ValueChanged<int> onSelect;
  const Bar3DChart({
    super.key,
    required this.bars,
    required this.selected,
    required this.onSelect,
  });

  @override
  State<Bar3DChart> createState() => _Bar3DChartState();
}

class _Bar3DChartState extends State<Bar3DChart> {
  double _rotX = 0.35;
  double _rotY = -0.45;
  final List<_HitRegion> _hitRegions = [];

  void _onPan(DragUpdateDetails d) {
    setState(() {
      _rotY += d.delta.dx * 0.012;
      _rotX -= d.delta.dy * 0.012;
      _rotX = _rotX.clamp(-0.2, 1.2);
    });
  }

  void _onTapUp(TapUpDetails d) {
    int? hit;
    double bestDepth = -double.infinity;
    for (final r in _hitRegions) {
      if (_pointInPolygon(d.localPosition, r.points) && r.depth > bestDepth) {
        bestDepth = r.depth;
        hit = r.segIndex;
      }
    }
    if (hit != null) widget.onSelect(hit);
  }

  void _resetView() {
    setState(() {
      _rotX = 0.35;
      _rotY = -0.45;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanUpdate: _onPan,
            onTapUp: _onTapUp,
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _Bar3DPainter(
                  bars: widget.bars,
                  rotX: _rotX,
                  rotY: _rotY,
                  selected: widget.selected,
                  hitRegionsOut: _hitRegions,
                  groundColor: theme.dividerColor,
                ),
                size: Size.infinite,
              ),
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: _ResetButton(onReset: _resetView),
        ),
      ],
    );
  }
}

class _Bar3DPainter extends CustomPainter {
  final List<BarData> bars;
  final double rotX;
  final double rotY;
  final int selected;
  final List<_HitRegion> hitRegionsOut;
  final Color groundColor;

  _Bar3DPainter({
    required this.bars,
    required this.rotX,
    required this.rotY,
    required this.selected,
    required this.hitRegionsOut,
    required this.groundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || bars.isEmpty) return;
    hitRegionsOut.clear();

    final cx = size.width / 2;
    final cy = size.height / 2 + 24;
    final unit = min(size.width, size.height) * 0.6;

    final maxVal = bars.map((b) => b.value).fold(0.0, max);
    if (maxVal <= 0) return;

    // Bar layout: spread along X axis, Z=0 plane
    final n = bars.length;
    const barW = 0.85;
    const barD = 0.85;
    final spacing = 1.05;
    final totalW = n * spacing;
    final originX = -totalW / 2 + spacing / 2;

    // Scale factor so the bars fit
    final scale = unit / max(2.5, totalW + 1.5);
    const maxBarH = 2.0; // world units
    double barScale(double v) => (v / maxVal) * maxBarH;

    final faces = <_Face>[];

    // Ground plane (a slightly larger rectangle)
    final gw = totalW + 1.2;
    final gd = barD + 1.2;
    faces.add(_Face(
      world: [
        _V3(-gw / 2, 0, -gd / 2),
        _V3(gw / 2, 0, -gd / 2),
        _V3(gw / 2, 0, gd / 2),
        _V3(-gw / 2, 0, gd / 2),
      ],
      base: groundColor,
      normal: const _V3(0, 1, 0),
    ));

    for (int i = 0; i < n; i++) {
      final b = bars[i];
      final h = barScale(b.value);
      if (h <= 0.001) continue;
      final x0 = originX + i * spacing - barW / 2;
      final x1 = originX + i * spacing + barW / 2;
      final z0 = -barD / 2;
      final z1 = barD / 2;
      final y0 = 0.0;
      final y1 = h;
      final c = b.color;

      // 6 faces of a box. CCW winding when viewed from outside.
      // Top
      faces.add(_Face(
        world: [_V3(x0, y1, z0), _V3(x1, y1, z0), _V3(x1, y1, z1), _V3(x0, y1, z1)],
        base: c,
        normal: const _V3(0, 1, 0),
        hitId: i,
      ));
      // Front (z = z1, normal +z)
      faces.add(_Face(
        world: [_V3(x0, y0, z1), _V3(x1, y0, z1), _V3(x1, y1, z1), _V3(x0, y1, z1)],
        base: c,
        normal: const _V3(0, 0, 1),
        hitId: i,
      ));
      // Back (z = z0, normal -z)
      faces.add(_Face(
        world: [_V3(x1, y0, z0), _V3(x0, y0, z0), _V3(x0, y1, z0), _V3(x1, y1, z0)],
        base: c,
        normal: const _V3(0, 0, -1),
        hitId: i,
      ));
      // Right (x = x1, normal +x)
      faces.add(_Face(
        world: [_V3(x1, y0, z1), _V3(x1, y0, z0), _V3(x1, y1, z0), _V3(x1, y1, z1)],
        base: c,
        normal: const _V3(1, 0, 0),
        hitId: i,
      ));
      // Left (x = x0, normal -x)
      faces.add(_Face(
        world: [_V3(x0, y0, z0), _V3(x0, y0, z1), _V3(x0, y1, z1), _V3(x0, y1, z0)],
        base: c,
        normal: const _V3(-1, 0, 0),
        hitId: i,
      ));
      // Bottom — usually hidden by ground; skip to save fillrate
    }

    // Project + cull + sort
    final visible = <_ProjectedFace>[];
    final hitCandidates = <_HitRegion>[];

    for (final f in faces) {
      final n = _norm(_rotate(f.normal, rotX, rotY));
      if (n.z <= 0.02) continue;
      final pts = <Offset>[];
      double depthSum = 0;
      for (final v in f.world) {
        final r = _rotate(v, rotX, rotY);
        pts.add(Offset(cx + r.x * scale, cy - r.y * scale));
        depthSum += r.z;
      }
      final depth = depthSum / f.world.length;
      final lightT = max(0.0, _dot(n, _norm(_lightDir)));
      final color = _shade(f.base, lightT);
      visible.add(_ProjectedFace(pts, depth, color, f.hitId));
      if (f.hitId != null) {
        hitCandidates.add(_HitRegion(f.hitId!, pts, depth));
      }
    }

    visible.sort((a, b) => a.depth.compareTo(b.depth));
    hitRegionsOut.addAll(hitCandidates);

    final fill = Paint()..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    for (final pf in visible) {
      final path = Path()..moveTo(pf.points.first.dx, pf.points.first.dy);
      for (int i = 1; i < pf.points.length; i++) {
        path.lineTo(pf.points[i].dx, pf.points[i].dy);
      }
      path.close();
      fill.color = pf.color;
      canvas.drawPath(path, fill);
      if (pf.color.computeLuminance() > 0.05) {
        canvas.drawPath(path, stroke);
      }
    }

    // Highlight selected bar with a stroke around its top face
    if (selected >= 0 && selected < bars.length) {
      final b = bars[selected];
      final h = barScale(b.value);
      if (h > 0.001) {
        final x0 = originX + selected * spacing - barW / 2;
        final x1 = originX + selected * spacing + barW / 2;
        final z0 = -barD / 2;
        final z1 = barD / 2;
        final corners = [
          _V3(x0, h, z0),
          _V3(x1, h, z0),
          _V3(x1, h, z1),
          _V3(x0, h, z1),
        ];
        final pts = corners
            .map((v) => _rotate(v, rotX, rotY))
            .map((r) => Offset(cx + r.x * scale, cy - r.y * scale))
            .toList();
        final path = Path()..moveTo(pts.first.dx, pts.first.dy);
        for (int i = 1; i < pts.length; i++) {
          path.lineTo(pts[i].dx, pts[i].dy);
        }
        path.close();
        canvas.drawPath(
          path,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_Bar3DPainter old) =>
      old.rotX != rotX ||
      old.rotY != rotY ||
      old.selected != selected ||
      old.bars != bars;
}

// ──────────────────────────────────────────────────────────────────────────────
//  UI helpers
// ──────────────────────────────────────────────────────────────────────────────

class _ResetButton extends StatelessWidget {
  final VoidCallback onReset;
  const _ResetButton({required this.onReset});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: 'Reset view',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onReset,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Icon(
              Icons.refresh_rounded,
              size: 16,
              color: theme.textTheme.bodySmall?.color,
            ),
          ),
        ),
      ),
    );
  }
}
