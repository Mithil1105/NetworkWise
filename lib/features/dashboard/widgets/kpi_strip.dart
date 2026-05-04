import 'package:flutter/material.dart';

import 'kpi_card.dart';

/// Responsive horizontal strip of KPI tiles. Wraps onto multiple rows
/// on narrow windows without layout jank.
class KpiStrip extends StatelessWidget {
  final List<KpiCard> cards;
  final double gap;
  final double minCardWidth;

  const KpiStrip({
    super.key,
    required this.cards,
    this.gap = 16,
    this.minCardWidth = 220,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // Max 4 per row, min minCardWidth
        var perRow = (width / minCardWidth).floor();
        if (perRow > cards.length) perRow = cards.length;
        if (perRow < 1) perRow = 1;
        final cardWidth = (width - gap * (perRow - 1)) / perRow;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final c in cards)
              SizedBox(width: cardWidth, child: c),
          ],
        );
      },
    );
  }
}
