import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/supabase_service_provider.dart';
import 'admin_members_service.dart';

final adminMembersServiceProvider = Provider<AdminMembersService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return AdminMembersService(client);
});
