import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/security/data/mock_fleet_security.dart';
import '../services/data_service_provider.dart';
import 'devices_provider.dart';

/// Fleet security posture — keyed off the reactive [devicesProvider]
/// so any fleet mutation propagates, and routed through
/// [IDataService.getDeviceDetail] so the security roll-up uses the
/// same source of truth as the Devices → detail screen.
final fleetSecuritySummaryProvider = Provider<FleetSecuritySummary>((ref) {
  final devices = ref.watch(devicesProvider);
  final service = ref.watch(dataServiceProvider);
  final list = [
    for (final d in devices)
      DeviceCompliance(
        device: d,
        security: service.getDeviceDetail(d.id).security,
      ),
  ];
  return FleetSecuritySummary(list);
});
