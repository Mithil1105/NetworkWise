import 'package:flutter/material.dart';

import '../../../../core/models/network_adapter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/info_row.dart';
import '../../../../shared/widgets/section_card.dart';

class NetworkInfoTab extends StatelessWidget {
  final List<NetworkAdapter> adapters;

  const NetworkInfoTab({super.key, required this.adapters});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < adapters.length; i++) ...[
            _AdapterCard(adapter: adapters[i]),
            if (i != adapters.length - 1) const SizedBox(height: 16),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _AdapterCard extends StatelessWidget {
  final NetworkAdapter adapter;
  const _AdapterCard({required this.adapter});

  ({IconData icon, Color color, String label}) get _typeStyle {
    switch (adapter.type) {
      case AdapterType.ethernet:
        return (
          icon: Icons.settings_ethernet,
          color: AppColors.info,
          label: 'Ethernet'
        );
      case AdapterType.wifi:
        return (
          icon: Icons.wifi,
          color: AppColors.seed,
          label: 'Wi-Fi'
        );
      case AdapterType.bluetooth:
        return (
          icon: Icons.bluetooth,
          color: AppColors.info,
          label: 'Bluetooth'
        );
      case AdapterType.virtual:
        return (
          icon: Icons.cloud_outlined,
          color: AppColors.neutral,
          label: 'Virtual'
        );
      case AdapterType.loopback:
        return (
          icon: Icons.loop,
          color: AppColors.neutral,
          label: 'Loopback'
        );
      case AdapterType.unknown:
        return (
          icon: Icons.help_outline,
          color: AppColors.neutral,
          label: 'Unknown'
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _typeStyle;
    return SectionCard(
      title: adapter.name,
      subtitle: '${s.label}  •  ${adapter.isConnected ? "Connected" : "Disconnected"}',
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: adapter.isConnected
              ? AppColors.successBg
              : AppColors.neutralBg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(s.icon,
                size: 14,
                color: adapter.isConnected ? AppColors.success : AppColors.neutral),
            const SizedBox(width: 6),
            Text(
              adapter.isConnected ? 'Active' : 'Idle',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: adapter.isConnected ? AppColors.success : AppColors.neutral,
              ),
            ),
          ],
        ),
      ),
      child: InfoGrid(
        rows: [
          InfoRow(label: 'IPv4 address', value: adapter.ipAddress),
          InfoRow(label: 'Subnet mask', value: adapter.subnetMask),
          InfoRow(label: 'Default gateway', value: adapter.gateway),
          InfoRow(label: 'MAC address', value: adapter.macAddress),
          InfoRow(
            label: 'DNS servers',
            value: adapter.dnsServers.join(', '),
          ),
          InfoRow(
            label: 'Link speed',
            value: '${adapter.linkSpeedMbps.toStringAsFixed(0)} Mbps',
          ),
          InfoRow(
            label: 'Data sent',
            value: Formatters.bytes(adapter.bytesSent),
          ),
          InfoRow(
            label: 'Data received',
            value: Formatters.bytes(adapter.bytesReceived),
          ),
        ],
      ),
    );
  }
}
