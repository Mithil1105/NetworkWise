import 'package:flutter/material.dart';

import '../../../../core/models/device.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/info_row.dart';
import '../../../../shared/widgets/section_card.dart';
import '../../data/mock_device_detail.dart';

class GeneralInfoTab extends StatelessWidget {
  final Device device;
  final MockDeviceDetail detail;

  const GeneralInfoTab({
    super.key,
    required this.device,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionCard(
            title: 'Identity',
            subtitle: 'Hostname, domain and enrolment',
            child: InfoGrid(
              rows: [
                if (device.hostnameLabel.trim().isNotEmpty &&
                    device.hostnameLabel.trim() != device.hostname)
                  InfoRow(
                    label: 'Display label',
                    value: device.hostnameLabel.trim(),
                  ),
                InfoRow(label: 'Hostname', value: device.hostname),
                InfoRow(label: 'Device ID', value: device.id),
                InfoRow(label: 'Serial number', value: detail.serialNumber),
                InfoRow(
                  label: 'Domain',
                  value: detail.domain.isEmpty ? 'WORKGROUP' : detail.domain,
                ),
                InfoRow(
                  label: 'IP address',
                  value: device.ipAddress.isEmpty ? '—' : device.ipAddress,
                ),
                InfoRow(
                  label: 'MAC address',
                  value: device.macAddress.isEmpty ? '—' : device.macAddress,
                ),
                InfoRow(
                  label: 'Enrolled on',
                  value: Formatters.dateOnly(detail.enrolledAt),
                ),
                InfoRow(
                  label: 'Last seen',
                  value: Formatters.relative(device.lastSeen),
                ),
                if (device.isArchived)
                  InfoRow(
                    label: 'Archived',
                    value: Formatters.relative(device.archivedAt!),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Hardware',
            subtitle: 'Manufacturer and model details',
            child: InfoGrid(
              rows: [
                InfoRow(label: 'Manufacturer', value: device.manufacturer),
                InfoRow(label: 'Model', value: device.model),
                InfoRow(label: 'Architecture', value: detail.system.architecture),
                InfoRow(
                  label: 'CPU',
                  value:
                      '${detail.system.cpuName} (${detail.system.cpuCores} cores)',
                ),
                InfoRow(
                  label: 'RAM (installed)',
                  value:
                      '${detail.system.totalRamGb.toStringAsFixed(0)} GB',
                ),
                InfoRow(
                  label: 'Storage',
                  value:
                      '${detail.system.diskTotalGb.toStringAsFixed(0)} GB',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Assignment',
            subtitle: 'Owner, location and tags',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InfoGrid(
                  rows: [
                    InfoRow(
                      label: 'Assigned user',
                      value:
                          device.assignedUser.isEmpty ? '—' : device.assignedUser,
                    ),
                    InfoRow(label: 'Location', value: device.location),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final t in detail.tags)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.neutralBg,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          t,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.neutral,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
