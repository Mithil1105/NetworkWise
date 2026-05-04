import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/section_card.dart';
import '../data/mock_fleet_security.dart';
import 'compliance_pill.dart';

/// Per-device compliance matrix. Four control columns + overall pill.
class ComplianceTable extends StatelessWidget {
  final List<DeviceCompliance> rows;

  const ComplianceTable({super.key, required this.rows});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Device Compliance',
      subtitle: 'Per-device posture across core Windows security controls',
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          const _HeaderRow(),
          const Divider(height: 1, color: AppColors.divider),
          for (var i = 0; i < rows.length; i++) ...[
            _DataRow(row: rows[i]),
            if (i != rows.length - 1)
              const Divider(height: 1, color: AppColors.divider),
          ],
        ],
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF3F4F6),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: const Row(
        children: [
          Expanded(flex: 4, child: _H('Device')),
          Expanded(flex: 2, child: _H('Antivirus')),
          Expanded(flex: 2, child: _H('Firewall')),
          Expanded(flex: 2, child: _H('Activation')),
          Expanded(flex: 2, child: _H('BitLocker')),
          Expanded(flex: 2, child: _H('Status')),
        ],
      ),
    );
  }
}

class _H extends StatelessWidget {
  final String text;
  const _H(this.text);
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 11.5,
          letterSpacing: 0.4,
          fontWeight: FontWeight.w700,
          color: AppColors.neutral,
        ),
      );
}

class _DataRow extends StatelessWidget {
  final DeviceCompliance row;
  const _DataRow({required this.row});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.infoBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.computer,
                      size: 14, color: AppColors.info),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        row.device.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        row.device.assignedUser.isEmpty
                            ? row.device.location
                            : '${row.device.assignedUser} — ${row.device.location}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.neutral,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: _ControlCell(
              ok: row.avOk,
              okLabel: 'Protected',
              failLabel: 'Needs attention',
            ),
          ),
          Expanded(
            flex: 2,
            child: _ControlCell(
              ok: row.firewallOk,
              okLabel: 'All profiles',
              failLabel: 'Profile off',
            ),
          ),
          Expanded(
            flex: 2,
            child: _ControlCell(
              ok: row.activationOk,
              okLabel: 'Activated',
              failLabel: 'Not activated',
            ),
          ),
          Expanded(
            flex: 2,
            child: _ControlCell(
              ok: row.bitLockerOk,
              okLabel: 'Encrypted',
              failLabel: 'Not encrypted',
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: CompliancePill(level: row.level, compact: true),
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlCell extends StatelessWidget {
  final bool ok;
  final String okLabel;
  final String failLabel;

  const _ControlCell({
    required this.ok,
    required this.okLabel,
    required this.failLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = ok ? AppColors.success : AppColors.danger;
    final icon = ok ? Icons.check_circle : Icons.cancel;
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            ok ? okLabel : failLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: ok ? theme.colorScheme.onSurface : AppColors.danger,
            ),
          ),
        ),
      ],
    );
  }
}
