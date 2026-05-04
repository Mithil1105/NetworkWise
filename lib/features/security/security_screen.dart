import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/security_provider.dart';
import 'widgets/activation_card.dart';
import 'widgets/antivirus_card.dart';
import 'widgets/compliance_table.dart';
import 'widgets/firewall_card.dart';
import 'widgets/security_kpi_strip.dart';

/// Fleet-wide security posture — consumes [fleetSecuritySummaryProvider]
/// so future fleet mutations automatically refresh every card on screen.
class SecurityScreen extends ConsumerWidget {
  const SecurityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(fleetSecuritySummaryProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SecurityKpiStrip(summary: summary),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth >= 1200;
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: AntivirusCard(summary: summary)),
                    const SizedBox(width: 16),
                    Expanded(child: FirewallCard(summary: summary)),
                    const SizedBox(width: 16),
                    Expanded(child: ActivationCard(summary: summary)),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AntivirusCard(summary: summary),
                  const SizedBox(height: 16),
                  FirewallCard(summary: summary),
                  const SizedBox(height: 16),
                  ActivationCard(summary: summary),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          ComplianceTable(rows: summary.devices),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
