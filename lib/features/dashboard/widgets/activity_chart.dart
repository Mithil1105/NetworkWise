import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/section_card.dart';

/// Zero-dependency line chart for the dashboard activity trend.
///
/// Takes two series (online / alerts) of equal length and paints a
/// smooth-ish polyline with gridlines and day labels. Intended as a
/// lightweight placeholder until we bring in `fl_chart` in Phase 12+.
class ActivityChart extends StatelessWidget {
  final List<double> onlineSeries;
  final List<double> alertsSeries;
  final List<String> labels;
  final double height;

  const ActivityChart({
    super.key,
    required this.onlineSeries,
    required this.alertsSeries,
    required this.labels,
    this.height = 220,
  });

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Activity Trend',
      subtitle: 'Online devices vs. alerts — last ${labels.length} days',
      trailing: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LegendDot(color: AppColors.seed, label: 'Online'),
          SizedBox(width: 12),
          _LegendDot(color: AppColors.danger, label: 'Alerts'),
        ],
      ),
      child: SizedBox(
        height: height,
        child: CustomPaint(
          painter: _ChartPainter(
            online: onlineSeries,
            alerts: alertsSeries,
            labels: labels,
          ),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.neutral,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _ChartPainter extends CustomPainter {
  final List<double> online;
  final List<double> alerts;
  final List<String> labels;

  _ChartPainter({
    required this.online,
    required this.alerts,
    required this.labels,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const leftPad = 28.0;
    const rightPad = 8.0;
    const topPad = 8.0;
    const bottomPad = 22.0;

    final plotW = size.width - leftPad - rightPad;
    final plotH = size.height - topPad - bottomPad;

    final allPoints = [...online, ...alerts];
    final maxY = (allPoints.isEmpty
            ? 1.0
            : allPoints.reduce((a, b) => a > b ? a : b)) *
        1.1;
    final safeMax = maxY <= 0 ? 1.0 : maxY;

    // --- Gridlines + Y labels ---
    final gridPaint = Paint()
      ..color = AppColors.divider
      ..strokeWidth = 1;
    final textStyle = const TextStyle(
      color: AppColors.neutral,
      fontSize: 10,
    );

    const gridLines = 4;
    for (var i = 0; i <= gridLines; i++) {
      final y = topPad + plotH * (i / gridLines);
      canvas.drawLine(
        Offset(leftPad, y),
        Offset(size.width - rightPad, y),
        gridPaint,
      );
      final value = safeMax * (1 - i / gridLines);
      final tp = TextPainter(
        text: TextSpan(
            text: value.toStringAsFixed(0), style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(leftPad - tp.width - 4, y - tp.height / 2));
    }

    // --- X labels ---
    if (labels.isNotEmpty) {
      final stride = (labels.length / 6).ceil();
      for (var i = 0; i < labels.length; i += stride) {
        final x = leftPad + plotW * (i / (labels.length - 1).clamp(1, 1000));
        final tp = TextPainter(
          text: TextSpan(text: labels[i], style: textStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas,
            Offset(x - tp.width / 2, size.height - bottomPad + 6));
      }
    }

    // --- Series ---
    void paintSeries(List<double> data, Color color,
        {bool fill = false}) {
      if (data.length < 2) return;
      final path = Path();
      final fillPath = Path();
      for (var i = 0; i < data.length; i++) {
        final x = leftPad + plotW * (i / (data.length - 1));
        final y = topPad + plotH * (1 - data[i] / safeMax);
        if (i == 0) {
          path.moveTo(x, y);
          fillPath.moveTo(x, topPad + plotH);
          fillPath.lineTo(x, y);
        } else {
          path.lineTo(x, y);
          fillPath.lineTo(x, y);
        }
      }
      if (fill) {
        fillPath
          ..lineTo(leftPad + plotW, topPad + plotH)
          ..close();
        canvas.drawPath(
          fillPath,
          Paint()..color = color.withOpacity(0.08),
        );
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );

      // Points
      for (var i = 0; i < data.length; i++) {
        final x = leftPad + plotW * (i / (data.length - 1));
        final y = topPad + plotH * (1 - data[i] / safeMax);
        canvas.drawCircle(
            Offset(x, y), 2.5, Paint()..color = color);
      }
    }

    paintSeries(online, AppColors.seed, fill: true);
    paintSeries(alerts, AppColors.danger);
  }

  @override
  bool shouldRepaint(covariant _ChartPainter old) =>
      old.online != online || old.alerts != alerts || old.labels != labels;
}
