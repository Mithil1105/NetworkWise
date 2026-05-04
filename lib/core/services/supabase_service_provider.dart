import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

/// Global handle on the initialised [SupabaseService].
///
/// `SupabaseService.initialize()` must have been awaited in `main.dart`
/// before the first read of this provider.
final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  return SupabaseService();
});

/// Convenience accessor for repositories that only need the raw
/// [SupabaseClient] (no wrapper behaviour yet).
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return ref.watch(supabaseServiceProvider).client;
});
