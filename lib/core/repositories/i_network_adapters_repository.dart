import '../models/network_adapter.dart';

/// Contract for reading + writing the **network_adapters** table.
///
/// Because `report-snapshot` replaces the adapter set for a device atomically
/// (delete-all-then-insert) the repository surfaces a single
/// [replaceAdaptersForDevice] writer. Individual `insert` / `update` are
/// deliberately not exposed to avoid the UI ever partially-updating the
/// table.
abstract class INetworkAdaptersRepository {
  /// Fetch the current adapter set for a device.
  Future<List<NetworkAdapter>> listForDevice(String deviceId);

  /// Replace all adapter rows for a device.
  ///
  /// The Supabase implementation routes this to the `report-snapshot`
  /// Edge Function, which validates the device's registration secret
  /// before executing the delete + insert atomically against the
  /// service-role client.
  Future<void> replaceAdaptersForDevice({
    required String deviceId,
    required String registrationSecret,
    required List<NetworkAdapter> adapters,
  });
}
