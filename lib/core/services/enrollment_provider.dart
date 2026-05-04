import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'enrollment_service.dart';

/// Single shared [EnrollmentService] instance.
final enrollmentServiceProvider = Provider<EnrollmentService>((ref) {
  return EnrollmentService();
});

/// Current enrollment code on this endpoint.
///
/// `null` means "the operator hasn't enrolled yet — show the first-run
/// screen". The AsyncNotifier loads the value from SharedPreferences on
/// first build; subsequent `set(...)` calls broadcast synchronously
/// through the [state] field.
class EnrollmentCodeNotifier extends AsyncNotifier<String?> {
  @override
  Future<String?> build() async {
    final svc = ref.watch(enrollmentServiceProvider);
    return svc.read();
  }

  Future<void> set(String code) async {
    final svc = ref.read(enrollmentServiceProvider);
    await svc.write(code);
    state = AsyncValue.data(code.trim().toUpperCase());
  }

  Future<void> clear() async {
    final svc = ref.read(enrollmentServiceProvider);
    await svc.clear();
    state = const AsyncValue.data(null);
  }
}

final enrollmentCodeProvider =
    AsyncNotifierProvider<EnrollmentCodeNotifier, String?>(
  EnrollmentCodeNotifier.new,
);
