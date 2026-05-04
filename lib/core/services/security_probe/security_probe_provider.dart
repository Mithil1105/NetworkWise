import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'i_security_probe.dart';
import 'windows_security_probe.dart';

/// Singleton probe for the lifetime of the ProviderScope.
///
/// Keeping it a singleton means we don't leak a PowerShell process per
/// widget build — and the probe is stateless anyway, so a singleton is
/// the correct shape.
final securityProbeProvider = Provider<ISecurityProbe>((ref) {
  return WindowsSecurityProbe();
});
