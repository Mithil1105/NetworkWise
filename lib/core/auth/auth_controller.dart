import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../repositories/supabase/supabase_repositories_providers.dart';
import '../services/supabase_service_provider.dart';
import 'admin_member.dart';

/// What the dashboard needs to know about the current admin session.
@immutable
class AdminAuthState {
  const AdminAuthState({
    required this.status,
    this.member,
    this.errorMessage,
  });

  final AdminAuthStatus status;
  final AdminMember? member;
  final String? errorMessage;

  AdminAuthState copyWith({
    AdminAuthStatus? status,
    AdminMember? member,
    String? errorMessage,
  }) {
    return AdminAuthState(
      status: status ?? this.status,
      member: member ?? this.member,
      errorMessage: errorMessage,
    );
  }

  static const AdminAuthState loading =
      AdminAuthState(status: AdminAuthStatus.loading);
  static const AdminAuthState signedOut =
      AdminAuthState(status: AdminAuthStatus.signedOut);
}

enum AdminAuthStatus {
  /// Still restoring a persisted session from disk.
  loading,

  /// No Supabase Auth user is signed in on this machine.
  signedOut,

  /// User is authenticated but lacks a row in `admin_members` — they
  /// should be kicked back to the sign-in screen with an error.
  notAdmin,

  /// Fully signed-in admin — UI can render the dashboard.
  signedIn,
}

/// Orchestrator for the admin session.
///
/// Responsibilities:
///   * Expose `AdminAuthState` to the UI.
///   * Reflect changes from [GoTrueClient.onAuthStateChange] (session
///     refresh, external sign-out).
///   * Call `admin_members` after sign-in to confirm the user actually
///     has dashboard access — raw auth alone isn't enough.
class AdminAuthController extends AsyncNotifier<AdminAuthState> {
  StreamSubscription<AuthState>? _sub;

  @override
  Future<AdminAuthState> build() async {
    final client = ref.watch(supabaseClientProvider);

    // Keep the stream subscription tied to this provider lifecycle.
    _sub?.cancel();
    _sub = client.auth.onAuthStateChange.listen((event) {
      final session = event.session;
      if (session == null) {
        state = const AsyncValue.data(AdminAuthState.signedOut);
        ref.read(orgIdProvider.notifier).state = null;
      } else {
        // ignore: unawaited_futures
        _resolveMembership(session);
      }
    });
    ref.onDispose(() {
      _sub?.cancel();
      _sub = null;
    });

    // Restore any persisted session from local storage on first build.
    final current = client.auth.currentSession;
    if (current == null) return AdminAuthState.signedOut;

    return _buildFromSession(current);
  }

  // ------------------------------------------------------------------
  // Actions
  // ------------------------------------------------------------------

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.data(AdminAuthState.loading);
    final client = ref.read(supabaseClientProvider);
    try {
      final response = await client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      final session = response.session;
      if (session == null) {
        state = const AsyncValue.data(
          AdminAuthState(
            status: AdminAuthStatus.signedOut,
            errorMessage: 'Sign-in failed — no session returned.',
          ),
        );
        return;
      }
      final built = await _buildFromSession(session);
      state = AsyncValue.data(built);
    } on AuthException catch (err) {
      state = AsyncValue.data(
        AdminAuthState(
          status: AdminAuthStatus.signedOut,
          errorMessage: err.message,
        ),
      );
    } catch (err) {
      state = AsyncValue.data(
        AdminAuthState(
          status: AdminAuthStatus.signedOut,
          errorMessage: err.toString(),
        ),
      );
    }
  }

  Future<void> signOut() async {
    final client = ref.read(supabaseClientProvider);
    try {
      await client.auth.signOut();
    } finally {
      state = const AsyncValue.data(AdminAuthState.signedOut);
      ref.read(orgIdProvider.notifier).state = null;
    }
  }

  // ------------------------------------------------------------------
  // Internals
  // ------------------------------------------------------------------

  Future<AdminAuthState> _buildFromSession(Session session) async {
    final client = ref.read(supabaseClientProvider);
    final user = session.user;

    final row = await client
        .from('admin_members')
        .select('user_id, organization_id, role, full_name')
        .eq('user_id', user.id)
        .maybeSingle();

    if (row == null) {
      // Authenticated user with no admin_members row — sign them out
      // defensively so they don't see a broken dashboard.
      await client.auth.signOut();
      return const AdminAuthState(
        status: AdminAuthStatus.notAdmin,
        errorMessage:
            'Your account is valid but has no admin access. Ask your owner to invite you from Settings ▸ Admins.',
      );
    }

    final member = AdminMember.fromRow(
      row: Map<String, dynamic>.from(row),
      email: user.email ?? '',
    );

    // Publish the org id so PostgREST calls stamp the RLS header.
    ref.read(orgIdProvider.notifier).state = member.organizationId;

    return AdminAuthState(
      status: AdminAuthStatus.signedIn,
      member: member,
    );
  }

  Future<void> _resolveMembership(Session session) async {
    final built = await _buildFromSession(session);
    state = AsyncValue.data(built);
  }
}

final adminAuthProvider =
    AsyncNotifierProvider<AdminAuthController, AdminAuthState>(
  AdminAuthController.new,
);
